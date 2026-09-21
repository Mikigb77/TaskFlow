from django.db import IntegrityError, transaction
from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.response import Response
from .models import Task, TaskEvent
from .serializers import TaskSerializer


class TaskViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    serializer_class = TaskSerializer
    throttle_scope = "tasks"
    lookup_value_regex = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"

    def get_queryset(self):
        query = Task.objects.filter(owner=self.request.user)
        if self.action == "list" and self.request.query_params.get("include_deleted") != "true":
            query = query.filter(is_deleted=False)
        return query

    def create(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        with transaction.atomic():
            task = serializer.save(owner=request.user, version=1)
            TaskEvent.objects.create(task=task, version=1, action="created")
        return Response(self.get_serializer(task).data, status=201)

    def update(self, request, pk=None):
        # Client-generated UUIDs make offline creation idempotent.
        with transaction.atomic():
            task = Task.objects.select_for_update().filter(pk=pk).first()
            if task and task.owner_id != request.user.pk:
                raise NotFound()
            serializer = self.get_serializer(task, data=request.data)
            serializer.is_valid(raise_exception=True)
            expected = serializer.validated_data.get("version", 0)
            if task and expected != task.version:
                return Response({"detail": "This task changed on another device.", "current": self.get_serializer(task).data}, status=409)
            if not task and expected != 0:
                raise ValidationError({"version": "New tasks must start at version 0."})
            is_new = task is None
            try:
                with transaction.atomic():
                    task = serializer.save(id=pk, owner=request.user, version=(task.version + 1 if task else 1))
            except IntegrityError:
                # Concurrent first uploads cannot overwrite another owner's UUID.
                current = Task.objects.filter(pk=pk, owner=request.user).first()
                if not current:
                    raise NotFound()
                return Response({"detail": "Task was already uploaded.", "current": self.get_serializer(current).data}, status=409)
            TaskEvent.objects.create(task=task, version=task.version, action="deleted" if task.is_deleted else ("created" if is_new else "updated"))
            return Response(self.get_serializer(task).data, status=201 if is_new else 200)

    def destroy(self, request, pk=None):
        with transaction.atomic():
            task = self.get_queryset().select_for_update().filter(pk=pk).first()
            if not task:
                raise NotFound()
            if request.data.get("version") != task.version:
                return Response({"detail": "Supply the current task version.", "current": self.get_serializer(task).data}, status=409)
            task.is_deleted = True
            task.version += 1
            task.save()
            TaskEvent.objects.create(task=task, version=task.version, action="deleted")
        return Response(status=204)

    @action(detail=True, methods=["get"])
    def history(self, request, pk=None):
        task = self.get_object()
        return Response(list(task.events.order_by("version").values("version", "action", "created_at")))
