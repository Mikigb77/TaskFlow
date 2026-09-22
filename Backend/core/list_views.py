from django.db import IntegrityError, transaction
from rest_framework import mixins, viewsets
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.response import Response
from .models import TaskList
from .serializers import TaskListSerializer


class TaskListViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    serializer_class = TaskListSerializer
    throttle_scope = "tasks"
    lookup_value_regex = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"

    def get_queryset(self):
        return TaskList.objects.filter(owner=self.request.user)

    def update(self, request, pk=None):
        with transaction.atomic():
            task_list = TaskList.objects.select_for_update().filter(pk=pk).first()
            if task_list and task_list.owner_id != request.user.pk:
                raise NotFound()
            serializer = self.get_serializer(task_list, data=request.data)
            serializer.is_valid(raise_exception=True)
            expected = serializer.validated_data["version"]
            if task_list and expected != task_list.version:
                return Response({"detail": "This list changed on another device.",
                                 "current": self.get_serializer(task_list).data}, status=409)
            if not task_list and expected != 0:
                raise ValidationError({"version": "New lists must start at version 0."})
            is_new = task_list is None
            try:
                with transaction.atomic():
                    task_list = serializer.save(id=pk, owner=request.user,
                                                version=1 if is_new else task_list.version + 1)
            except IntegrityError:
                current = self.get_queryset().filter(pk=pk).first()
                if not current:
                    raise NotFound()
                return Response({"detail": "List was already uploaded.", "current": self.get_serializer(current).data}, status=409)
            return Response(self.get_serializer(task_list).data, status=201 if is_new else 200)
