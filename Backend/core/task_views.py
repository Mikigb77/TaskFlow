from django.db import IntegrityError, transaction
from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.response import Response
from .models import Task
from .collaboration import record_event, task_change_details
from .serializers import TaskSerializer
from .attachment_views import delete_task_attachments, check_list_transfer
from .list_access import visible_tasks, lock_task, display_name


class TaskViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    serializer_class = TaskSerializer
    throttle_scope = "tasks"
    lookup_value_regex = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"

    def get_queryset(self):
        query = visible_tasks(self.request.user).select_related("created_by", "assignee")
        if self.action == "list" and self.request.query_params.get("include_deleted") != "true":
            query = query.filter(is_deleted=False)
        return query

    def create(self, request):
        import uuid
        return self.update(request, pk=str(uuid.uuid4()))

    def update(self, request, pk=None):
        # Client-generated UUIDs make offline creation idempotent.
        with transaction.atomic():
            task, locked = lock_task(pk, request.user, target_list=request.data.get("list_id"))
            previous = dict(task.__dict__) if task else {}
            serializer = self.get_serializer(task, data=request.data)
            serializer.is_valid(raise_exception=True)
            destination = serializer.validated_data.get("task_list", task.task_list if task else None)
            if task and task.task_list_id and locked[task.task_list_id].shared and (destination is None or destination.pk != task.task_list_id):
                raise ValidationError({"list_id": "Shared tasks stay in their list. Export and import a personal copy if needed."})
            expected = serializer.validated_data.get("version", 0)
            if task and expected != task.version:
                return Response({"detail": "This task changed on another device.", "current": self.get_serializer(task).data}, status=409)
            if not task and expected != 0:
                raise ValidationError({"version": "New tasks must start at version 0."})
            check_list_transfer(task, destination)
            is_new = task is None
            # Typed, dictated and imported tasks all arrive here; the creator never changes after.
            creator = {"created_by": request.user} if is_new else {}
            try:
                with transaction.atomic():
                    task = serializer.save(id=pk, owner=task.owner if task else request.user, version=(task.version + 1 if task else 1),
                                           **creator)
            except IntegrityError:
                # Concurrent first uploads cannot overwrite another owner's UUID.
                current = visible_tasks(request.user).filter(pk=pk).first()
                if not current:
                    raise NotFound()
                return Response({"detail": "Task was already uploaded.", "current": self.get_serializer(current).data}, status=409)
            details = task_change_details(previous, task)
            action = "deleted" if task.is_deleted else ("created" if is_new else "updated")
            if not is_new and not task.is_deleted:
                if "assignment" in details["fields"] or "assignee_id" in details["fields"]:
                    action = "assigned"
                elif "is_completed" in details["fields"] or "completed_dates" in details["fields"]:
                    action = "completed" if task.is_completed or len(task.completed_dates) > len(previous.get("completed_dates", [])) else "reopened"
            record_event(task, request.user, action, details=details, previous_assignee=previous.get("assignee_id"))
            if task.is_deleted:
                delete_task_attachments(task)
            return Response(self.get_serializer(task).data, status=201 if is_new else 200)

    def destroy(self, request, pk=None):
        with transaction.atomic():
            task, _ = lock_task(pk, request.user)
            if not task:
                raise NotFound()
            if request.data.get("version") != task.version:
                return Response({"detail": "Supply the current task version.", "current": self.get_serializer(task).data}, status=409)
            task.is_deleted = True
            task.version += 1
            task.save()
            delete_task_attachments(task)
            record_event(task, request.user, "deleted")
        return Response(status=204)

    @action(detail=True, methods=["get"])
    def history(self, request, pk=None):
        task = self.get_object()
        return Response([{"version": row.version, "action": row.action, "created_at": row.created_at,
                          "actor_id": row.actor_id, "actor_name": display_name(row.actor) if row.actor_id else None,
                          "details": row.details} for row in task.events.select_related("actor").order_by("version")])
