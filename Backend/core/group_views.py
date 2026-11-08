"""Reusable people groups. All membership writes lock group, projects, then tasks."""
from datetime import timedelta
import secrets
import uuid

from django.db import IntegrityError, transaction
from django.utils import timezone
from django.utils.crypto import constant_time_compare, salted_hmac
from rest_framework import mixins, serializers, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from rest_framework.response import Response

from .attachment_views import files_allowed, quota_files
from .collaboration import clear_assignments
from .list_access import visible_groups, require_group, group_role, group_people, visible_tasks, display_name
from .models import TaskGroup, GroupMembership, GroupInvitation, TaskList, User, TaskNotification
from .email_delivery import queue_invitation, deliver_email
from .invitation_email import invitation_language


class GroupSerializer(serializers.ModelSerializer):
    version = serializers.IntegerField(min_value=0, default=0)
    role = serializers.SerializerMethodField()
    people = serializers.SerializerMethodField()
    project_count = serializers.SerializerMethodField()

    def get_role(self, value):
        return group_role(value, self.context["request"].user)

    def get_people(self, value):
        return group_people(value)

    def get_project_count(self, value):
        return value.projects.filter(is_deleted=False).count()

    class Meta:
        model = TaskGroup
        fields = ["id", "name", "owner_id", "archived", "version", "role", "people", "project_count", "updated_at"]
        read_only_fields = ["id", "owner_id", "updated_at"]


class GroupInviteSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=254)
    role = serializers.ChoiceField(choices=["admin", "editor", "viewer"], default="editor")
    # As for projects (list_views.InviteSerializer): "es", "ca" or "en", else Accept-Language.
    language = serializers.CharField(max_length=35, required=False, allow_blank=True, allow_null=True)

    def validate_email(self, value):
        return value.strip().casefold()


def invitation_data(invite):
    return {"id": str(invite.pk), "group_id": str(invite.group_id), "group_name": invite.group.name,
            "invited_by_name": display_name(invite.invited_by) if invite.invited_by_id else None,
            "email": invite.email, "role": invite.role, "expires_at": invite.expires_at, "state": invite.state}


def bump_group(group, projects):
    group.version += 1
    group.save()
    for project in projects:
        project.version += 1
        project.save()


class TaskGroupViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    serializer_class = GroupSerializer
    throttle_scope = "tasks"
    lookup_value_regex = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"

    def get_queryset(self):
        return visible_groups(self.request.user).select_related("owner")

    def _locked(self, pk, *, manage=False, owner=False):
        group = TaskGroup.objects.select_for_update().filter(pk=pk).first()
        if group is None:
            raise NotFound()
        require_group(group, self.request.user, manage=manage, owner=owner)
        projects = list(TaskList.objects.select_for_update().filter(group=group).order_by("id"))
        return group, projects

    def _conflict(self, group, version):
        if version != group.version:
            return Response({"detail": "This group changed. Refresh before trying again.",
                             "current": self.get_serializer(group).data}, status=409)
        return None

    def create(self, request):
        return self.update(request, pk=str(uuid.uuid4()))

    def update(self, request, pk=None):
        with transaction.atomic():
            group = TaskGroup.objects.select_for_update().filter(pk=pk).first()
            if group:
                require_group(group, request.user, manage=True)
            serializer = self.get_serializer(group, data=request.data)
            serializer.is_valid(raise_exception=True)
            expected = serializer.validated_data["version"]
            if group:
                conflict = self._conflict(group, expected)
                if conflict is not None:
                    return conflict
            elif expected != 0:
                raise ValidationError({"version": "New groups must start at version 0."})
            is_new = group is None
            try:
                with transaction.atomic():
                    group = serializer.save(id=pk, owner=group.owner if group else request.user,
                                            version=group.version + 1 if group else 1)
            except IntegrityError:
                current = self.get_queryset().filter(pk=pk).first()
                if current is None:
                    raise NotFound()
                return Response({"detail": "This group already exists.", "current": self.get_serializer(current).data}, status=409)
            if not is_new:
                for project in TaskList.objects.select_for_update().filter(group=group).order_by("id"):
                    project.version += 1
                    project.save()
            return Response(self.get_serializer(group).data, status=201 if is_new else 200)

    @action(detail=True, methods=["get"])
    def sharing(self, request, pk=None):
        group = self.get_object()
        data = {"group": self.get_serializer(group).data}
        if group_role(group, request.user) in ("owner", "admin"):
            data["invitations"] = [invitation_data(row) for row in group.invitations.filter(
                state="pending", expires_at__gt=timezone.now()).order_by("email")]
        return Response(data)

    @action(detail=True, methods=["post"], throttle_scope="invitations")
    def invite(self, request, pk=None):
        serializer = GroupInviteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        language = invitation_language(data.pop("language", None), request.META.get("HTTP_ACCEPT_LANGUAGE"))
        with transaction.atomic():
            group, projects = self._locked(pk, manage=True)
            if data["role"] == "admin" and group.owner_id != request.user.pk:
                raise PermissionDenied("Only the group owner can appoint administrators.")
            if group.owner.email == data["email"] or group.memberships.filter(user__email=data["email"]).exists():
                raise ValidationError("This person already belongs to the group.")
            group.invitations.filter(email=data["email"]).delete()
            code = secrets.token_urlsafe(18)
            invitation = GroupInvitation.objects.create(group=group, invited_by=request.user, **data,
                code_digest=salted_hmac("group-invite", code, algorithm="sha256").hexdigest(),
                expires_at=timezone.now() + timedelta(days=7))
            bump_group(group, projects)
            delivery = queue_invitation(invitation, code, kind="group", sender=display_name(request.user),
                                        language=language)
        email_status = deliver_email(delivery.pk)
        return Response({**invitation_data(invitation), "code": code, "email_status": email_status}, status=201)

    @action(detail=True, methods=["post"])
    def revoke_invite(self, request, pk=None):
        key = serializers.UUIDField().run_validation(request.data.get("invitation_id"))
        with transaction.atomic():
            group, projects = self._locked(pk, manage=True)
            invitation = group.invitations.filter(pk=key).first()
            if invitation is None:
                raise NotFound()
            if invitation.role == "admin" and group.owner_id != request.user.pk:
                raise PermissionDenied("Only the group owner can manage administrator invitations.")
            if invitation.state == "accepted":
                raise ValidationError("Remove the person's membership instead.")
            invitation.state = "revoked"
            invitation.save(update_fields=["state"])
            bump_group(group, projects)
            return Response(status=204)

    @action(detail=True, methods=["post"])
    def member(self, request, pk=None):
        user_id = serializers.IntegerField(min_value=1).run_validation(request.data.get("user_id"))
        role = serializers.ChoiceField(choices=["admin", "editor", "viewer", "remove"]).run_validation(request.data.get("role"))
        with transaction.atomic():
            group, projects = self._locked(pk, manage=True)
            membership = group.memberships.select_related("user").filter(user_id=user_id).first()
            if membership is None:
                raise NotFound()
            if group.owner_id != request.user.pk and (membership.role == "admin" or role == "admin"):
                raise PermissionDenied("Only the group owner can manage administrators.")
            if role == "remove":
                group.invitations.filter(email=membership.user.email).update(state="revoked")
                membership.delete()
            else:
                membership.role = role
                membership.save(update_fields=["role"])
            if role in ("remove", "viewer"):
                clear_assignments([project.pk for project in projects], user_id, request.user)
            bump_group(group, projects)
            return Response(self.get_serializer(group).data)

    @action(detail=True, methods=["post"])
    def profile(self, request, pk=None):
        name = serializers.CharField(max_length=60, allow_blank=True).run_validation(request.data.get("voice_name"))
        with transaction.atomic():
            group, projects = self._locked(pk)
            if group.owner_id == request.user.pk:
                raise ValidationError("The group owner uses their account name for voice assignments.")
            group.memberships.filter(user=request.user).update(voice_name=name)
            bump_group(group, projects)
            return Response(self.get_serializer(group).data)

    @action(detail=True, methods=["post"])
    def leave(self, request, pk=None):
        with transaction.atomic():
            group, projects = self._locked(pk)
            if group.owner_id == request.user.pk:
                raise ValidationError("Transfer ownership before leaving this group.")
            group.memberships.filter(user=request.user).delete()
            group.invitations.filter(email=request.user.email).update(state="revoked")
            clear_assignments([project.pk for project in projects], request.user.pk, request.user)
            bump_group(group, projects)
            return Response(status=204)

    @action(detail=True, methods=["post"])
    def transfer(self, request, pk=None):
        user_id = serializers.IntegerField(min_value=1).run_validation(request.data.get("user_id"))
        with transaction.atomic():
            group, projects = self._locked(pk, owner=True)
            conflict = self._conflict(group, request.data.get("version"))
            if conflict is not None:
                return conflict
            if not group.memberships.filter(user_id=user_id, user__is_active=True).exists():
                raise ValidationError({"user_id": "Choose a current group member."})
            # Uploads lock project then quota owner. Keep that order here as well.
            list(User.objects.select_for_update().filter(pk__in=[group.owner_id, user_id]).order_by("pk"))
            from .models import Attachment
            # A transfer charges no allowance (the bytes were counted when uploaded); only the file bound.
            moving = Attachment.objects.filter(task__task_list__group=group, task__is_deleted=False, is_deleted=False)
            if not files_allowed(moving.count() + quota_files(user_id).exclude(task__task_list__group=group).count()):
                raise ValidationError("The new owner already holds as many files as they can.")
            GroupMembership.objects.update_or_create(group=group, user_id=group.owner_id, defaults={"role": "admin"})
            group.memberships.filter(user_id=user_id).delete()
            group.owner_id = user_id
            for project in projects:
                project.owner_id = user_id
            bump_group(group, projects)
            return Response(self.get_serializer(group).data)

    def destroy(self, request, pk=None):
        with transaction.atomic():
            group, projects = self._locked(pk, owner=True)
            conflict = self._conflict(group, request.data.get("version"))
            if conflict is not None:
                return conflict
            if any(not project.is_deleted for project in projects):
                raise ValidationError("Archive this group, or remove its projects before deleting it.")
            group.is_deleted = True
            group.invitations.update(state="revoked")
            bump_group(group, projects)
            return Response(status=204)


class GroupInvitationViewSet(viewsets.GenericViewSet):
    throttle_scope = "tasks"
    lookup_value_regex = TaskGroupViewSet.lookup_value_regex

    def list(self, request):
        invitations = GroupInvitation.objects.filter(email=request.user.email, state="pending",
            expires_at__gt=timezone.now(), group__is_deleted=False).select_related("group").order_by("expires_at")
        return Response({"invitations": [invitation_data(row) for row in invitations]})

    @action(detail=True, methods=["post"])
    def respond(self, request, pk=None):
        decision = serializers.ChoiceField(choices=["accept", "decline"]).run_validation(request.data.get("decision"))
        with transaction.atomic():
            invitation = GroupInvitation.objects.filter(pk=pk, email=request.user.email).first()
            if invitation is None:
                raise NotFound()
            group = TaskGroup.objects.select_for_update().get(pk=invitation.group_id)
            projects = list(TaskList.objects.select_for_update().filter(group=group).order_by("id"))
            invitation = GroupInvitation.objects.filter(pk=pk, email=request.user.email).first()
            if invitation is None:
                raise NotFound()
            if invitation.state == "accepted" and decision == "accept" and not group.is_deleted and group.memberships.filter(user=request.user).exists():
                return Response({"group_id": str(group.pk)})
            if group.is_deleted or invitation.state != "pending" or invitation.expires_at <= timezone.now():
                raise ValidationError("This invitation is no longer available.")
            if decision == "accept":
                code = serializers.CharField(max_length=128).run_validation(request.data.get("code"))
                if not constant_time_compare(invitation.code_digest, salted_hmac("group-invite", code, algorithm="sha256").hexdigest()):
                    raise ValidationError("Ask a group administrator for the current invitation code.")
                GroupMembership.objects.update_or_create(group=group, user=request.user, defaults={"role": invitation.role})
                bump_group(group, projects)
            invitation.state = "accepted" if decision == "accept" else "declined"
            invitation.save(update_fields=["state"])
            return Response({"group_id": str(group.pk)})


class NotificationSerializer(serializers.ModelSerializer):
    task_id = serializers.UUIDField(source="event.task_id", read_only=True)
    task_title = serializers.CharField(source="event.task.title", read_only=True)
    project_id = serializers.UUIDField(source="event.task.task_list_id", read_only=True)
    project_name = serializers.CharField(source="event.task.task_list.name", read_only=True)
    action = serializers.CharField(source="event.action", read_only=True)
    actor_name = serializers.SerializerMethodField()

    def get_actor_name(self, value):
        return display_name(value.event.actor) if value.event.actor_id else None

    def to_representation(self, value):
        data = super().to_representation(value)
        details = value.event.details if isinstance(value.event.details, dict) else {}
        # Who an assignment went to (docs/VOICE_COMMANDS.md, "Activity"). Entries from before the
        # server recorded it have neither field, so the app keeps its older sentence for them.
        if value.event.action == "assigned" and "assignee_id" in details:
            assignee_id = details["assignee_id"]
            data["assignee_name"] = self._name(assignee_id) if assignee_id else None
            data["assignee_is_you"] = assignee_id is not None and assignee_id == self.context["request"].user.pk
        # What an update changed (UX-2508), so the app can say «ha movido» for a moved task.
        if value.event.action == "updated" and isinstance(details.get("fields"), list):
            data["fields"] = details["fields"]
        return data

    def _name(self, user_id):
        # The name as it is now, like actor_name. Looked up once per person for the whole page.
        names = self.context.setdefault("assignee_names", {})
        if user_id not in names:
            user = User.objects.filter(pk=user_id).first()
            names[user_id] = display_name(user) if user else None
        return names[user_id]

    class Meta:
        model = TaskNotification
        fields = ["id", "task_id", "task_title", "project_id", "project_name", "action", "actor_name", "read_at", "created_at"]
        read_only_fields = fields


class NotificationViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    serializer_class = NotificationSerializer
    throttle_scope = "tasks"

    def get_queryset(self):
        return TaskNotification.objects.filter(recipient=self.request.user,
            event__task__in=visible_tasks(self.request.user)).select_related("event__actor", "event__task__task_list")

    @action(detail=False, methods=["get"])
    def unread(self, request):
        return Response({"count": self.get_queryset().filter(read_at__isnull=True).count()})

    @action(detail=True, methods=["post"])
    def read(self, request, pk=None):
        row = self.get_object()
        if row.read_at is None:
            row.read_at = timezone.now()
            row.save(update_fields=["read_at"])
        return Response(self.get_serializer(row).data)

    @action(detail=False, methods=["post"])
    def read_all(self, request):
        self.get_queryset().filter(read_at__isnull=True).update(read_at=timezone.now())
        return Response(status=204)
