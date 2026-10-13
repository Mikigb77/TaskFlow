from django.db import IntegrityError, transaction
from django.utils import timezone
from datetime import timedelta
import secrets
from django.utils.crypto import constant_time_compare, salted_hmac
from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.response import Response
from .models import TaskList, ListMembership, ListInvitation, TaskGroup, ProjectPreference, User, Attachment
from .serializers import TaskListSerializer
from .list_access import visible_lists, require_list, require_group
from .attachment_views import delete_task_attachments, quota_files
from .collaboration import clear_assignments, record_event
from django.conf import settings
from django.db.models import Sum
from rest_framework import serializers


class InviteSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=254)
    role = serializers.ChoiceField(choices=["editor", "viewer"])

    def validate_email(self, value):
        return value.strip().casefold()


def bump(task_list):
    task_list.version += 1
    task_list.save()


def invitation_data(invite):
    return {"id": str(invite.pk), "list_id": str(invite.task_list_id), "list_name": invite.task_list.name,
            "email": invite.email, "role": invite.role, "expires_at": invite.expires_at, "state": invite.state}


class TaskListViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    serializer_class = TaskListSerializer
    throttle_scope = "tasks"
    lookup_value_regex = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"

    def get_queryset(self):
        return visible_lists(self.request.user)

    def _locked(self, pk, *, owner=False):
        item = TaskList.objects.select_for_update().filter(pk=pk).first()
        if item is None:
            raise NotFound()
        require_list(item, self.request.user, owner=owner)
        return item

    @action(detail=False, methods=["get"])
    def access(self, request):
        # One complete snapshot: pagination must never look like revocation.
        return Response({"lists": self.get_serializer(self.get_queryset(), many=True).data})

    def update(self, request, pk=None):
        with transaction.atomic():
            before = TaskList.objects.filter(pk=pk).first()
            group_ids = {before.group_id} if before and before.group_id else set()
            requested_group = request.data.get("group_id")
            if requested_group is not None:
                group_ids.add(serializers.UUIDField().run_validation(requested_group))
            groups = {row.pk: row for row in TaskGroup.objects.select_for_update().filter(pk__in=group_ids).order_by("id")}
            task_list = TaskList.objects.select_for_update().filter(pk=pk).first()
            if task_list:
                if task_list.group_id and task_list.group_id not in groups:
                    raise ValidationError("This project moved while saving. Refresh and retry.")
                require_list(task_list, request.user, owner=True)
            serializer = self.get_serializer(task_list, data=request.data)
            serializer.is_valid(raise_exception=True)
            group = serializer.validated_data.get("group", task_list.group if task_list else None)
            if group:
                group = groups.get(group.pk)
                if group is None:
                    raise ValidationError({"group_id": "Choose an available group."})
                require_group(group, request.user, manage=True)
            moved = task_list is not None and task_list.group_id != (group.pk if group else None)
            if moved and task_list.shared:
                raise ValidationError({"group_id": "Shared projects stay with their current people. Create a new project to use a different group."})
            if moved and request.data.get("confirm_share") is not True:
                raise ValidationError({"confirm_share": "Confirm that all existing tasks, notes and files will be shared with this group."})
            expected = serializer.validated_data["version"]
            if task_list and expected != task_list.version:
                return Response({"detail": "This list changed on another device.",
                                 "current": self.get_serializer(task_list).data}, status=409)
            if not task_list and expected != 0:
                raise ValidationError({"version": "New lists must start at version 0."})
            is_new = task_list is None
            owner = group.owner if group else (task_list.owner if task_list else request.user)
            if moved:
                list(User.objects.select_for_update().filter(pk__in=[task_list.owner_id, owner.pk]).order_by("pk"))
                moving = Attachment.objects.filter(task__task_list=task_list, task__is_deleted=False, is_deleted=False)
                existing = quota_files(owner.pk).exclude(task__task_list=task_list)
                total = (moving.aggregate(n=Sum("size"))["n"] or 0) + (existing.aggregate(n=Sum("size"))["n"] or 0)
                if total > settings.ATTACHMENT_ACCOUNT_BYTES or moving.count() + existing.count() > 1000:
                    raise ValidationError("The group owner needs enough storage for this project's files.")
            try:
                with transaction.atomic():
                    task_list = serializer.save(id=pk, owner=owner, shared=bool(group) or bool(task_list and task_list.shared),
                                                version=1 if is_new else task_list.version + 1)
            except IntegrityError:
                current = self.get_queryset().filter(pk=pk).first()
                if not current:
                    raise NotFound()
                return Response({"detail": "List was already uploaded.", "current": self.get_serializer(current).data}, status=409)
            if moved:
                for task in task_list.tasks.select_for_update().filter(is_deleted=False).order_by("id"):
                    task.assignment = "group" if task.kind == "task" else "personal"
                    task.version += 1
                    task.save()
                    record_event(task, request.user, "shared")
            return Response(self.get_serializer(task_list).data, status=201 if is_new else 200)

    @action(detail=True, methods=["post"])
    def preferences(self, request, pk=None):
        class PreferenceSerializer(serializers.Serializer):
            pinned = serializers.BooleanField(required=False)
            notifications = serializers.ChoiceField(choices=["all", "assigned", "muted"], required=False)
        serializer = PreferenceSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        with transaction.atomic():
            item = self._locked(pk)
            ProjectPreference.objects.update_or_create(task_list=item, user=request.user, defaults=serializer.validated_data)
            return Response(self.get_serializer(item).data)

    def _legacy(self, item):
        if item.group_id:
            raise ValidationError("Manage people through this project's group.")

    @action(detail=True, methods=["get"])
    def sharing(self, request, pk=None):
        item = self.get_object()
        role = require_list(item, request.user)
        data = {"list": self.get_serializer(item).data}
        if role == "owner":
            data["members"] = list(item.memberships.order_by("user_id").values("user_id", "user__email", "role"))
            data["invitations"] = [invitation_data(i) for i in item.invitations.filter(state="pending", expires_at__gt=timezone.now()).order_by("email")]
        return Response(data)

    @action(detail=True, methods=["post"], throttle_scope="invitations")
    def invite(self, request, pk=None):
        serializer = InviteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        with transaction.atomic():
            item = self._locked(pk, owner=True)
            self._legacy(item)
            if data["email"] == request.user.email or item.memberships.filter(user__email__iexact=data["email"]).exists():
                raise ValidationError("This person already has access. Manage their role instead.")
            previous = item.invitations.filter(email=data["email"]).first()
            pending = item.invitations.filter(state="pending", expires_at__gt=timezone.now())
            if previous:
                pending = pending.exclude(pk=previous.pk)
            if item.memberships.count() >= 20 or pending.count() >= 20:
                raise ValidationError("Use at most 20 members and 20 pending invitations per list.")
            if previous:
                previous.delete()
            code = secrets.token_urlsafe(18)
            invitation = ListInvitation.objects.create(task_list=item, **data, code_digest=salted_hmac('list-invite', code, algorithm='sha256').hexdigest(), expires_at=timezone.now() + timedelta(days=7))
            was_shared = item.shared
            item.shared = True
            bump(item)
            if not was_shared:
                for task in item.tasks.select_for_update().filter(kind="task", is_deleted=False).order_by("id"):
                    task.assignment = "group"
                    task.version += 1
                    task.save()
                    record_event(task, request.user, "shared")
            from .email_delivery import queue_invitation
            delivery = queue_invitation(invitation, code, kind="list", sender=request.user.email)
        from .email_delivery import deliver_email
        email_status = deliver_email(delivery.pk)
        return Response({**invitation_data(invitation), 'code': code, 'email_status': email_status}, status=201)

    @action(detail=True, methods=["post"])
    def revoke_invite(self, request, pk=None):
        with transaction.atomic():
            item = self._locked(pk, owner=True)
            self._legacy(item)
            key = serializers.UUIDField().run_validation(request.data.get("invitation_id"))
            invitation = item.invitations.filter(pk=key).first()
            if not invitation:
                raise NotFound()
            if invitation.state == "accepted":
                raise ValidationError("This invitation was already accepted. Remove the person's access in People instead.")
            invitation.state = "revoked"
            invitation.save(update_fields=["state"])
            return Response(status=204)

    @action(detail=True, methods=["post"])
    def member(self, request, pk=None):
        member_id = serializers.IntegerField(min_value=1).run_validation(request.data.get("user_id"))
        role = serializers.ChoiceField(choices=["editor", "viewer", "remove"]).run_validation(request.data.get("role"))
        with transaction.atomic():
            item = self._locked(pk, owner=True)
            self._legacy(item)
            member = item.memberships.filter(user_id=member_id).first()
            if not member:
                raise NotFound()
            if role == "remove":
                item.invitations.filter(email=member.user.email).update(state="revoked")
                member.delete()
            else:
                member.role = role
                member.save(update_fields=["role"])
            if role in ("remove", "viewer"):
                clear_assignments([item.pk], member_id, request.user)
            bump(item)
            return Response(status=204)

    @action(detail=True, methods=["post"])
    def leave(self, request, pk=None):
        with transaction.atomic():
            item = self._locked(pk)
            self._legacy(item)
            if item.owner_id == request.user.pk:
                raise ValidationError("The owner cannot leave. Delete the shared list if it is no longer needed.")
            item.memberships.filter(user=request.user).delete()
            clear_assignments([item.pk], request.user.pk, request.user)
            item.invitations.filter(email=request.user.email).update(state="revoked")
            bump(item)
            return Response(status=204)

    def destroy(self, request, pk=None):
        with transaction.atomic():
            item = self._locked(pk, owner=True)
            if request.data.get("version") != item.version:
                return Response({"detail": "This list changed. Refresh before deleting.", "current": self.get_serializer(item).data}, status=409)
            for task in item.tasks.select_for_update().filter(is_deleted=False).order_by("id"):
                task.is_deleted = True
                task.version += 1
                task.save()
                record_event(task, request.user, "deleted")
                delete_task_attachments(task)
            item.is_deleted = True
            bump(item)
            item.invitations.update(state="revoked")
        return Response(status=204)


class InvitationViewSet(viewsets.GenericViewSet):
    throttle_scope = "tasks"
    lookup_value_regex = TaskListViewSet.lookup_value_regex

    def list(self, request):
        invitations = ListInvitation.objects.filter(email=request.user.email, state="pending", expires_at__gt=timezone.now(), task_list__is_deleted=False).select_related("task_list").order_by("expires_at")
        return Response({"invitations": [invitation_data(item) for item in invitations]})

    @action(detail=True, methods=["post"])
    def respond(self, request, pk=None):
        choice = serializers.ChoiceField(choices=["accept", "decline"]).run_validation(request.data.get("decision"))
        with transaction.atomic():
            invitation = ListInvitation.objects.filter(pk=pk, email=request.user.email).first()
            if not invitation:
                raise NotFound()
            item = TaskList.objects.select_for_update().get(pk=invitation.task_list_id)
            invitation = ListInvitation.objects.filter(pk=pk, email=request.user.email).first()
            if not invitation:
                raise NotFound()
            if invitation.state == "accepted" and choice == "accept" and item.memberships.filter(user=request.user).exists() and not item.is_deleted:
                return Response({"list_id": str(item.pk)})
            if item.is_deleted or invitation.state != "pending" or invitation.expires_at <= timezone.now():
                raise ValidationError("This invitation is no longer available.")
            if choice == "accept":
                code = serializers.CharField(max_length=128).run_validation(request.data.get('code'))
                if not constant_time_compare(invitation.code_digest, salted_hmac('list-invite', code, algorithm='sha256').hexdigest()):
                    raise ValidationError("Ask the list owner for the current invitation code.")
                if item.memberships.count() >= 20:
                    raise ValidationError("The membership limit has been reached.")
                ListMembership.objects.update_or_create(task_list=item, user=request.user, defaults={"role": invitation.role})
                bump(item)
            invitation.state = "accepted" if choice == "accept" else "declined"
            invitation.save(update_fields=["state"])
            return Response({"list_id": str(item.pk)})
