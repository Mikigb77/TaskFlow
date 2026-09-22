"""One access rule for list metadata, tasks, history and private file bytes."""
import uuid
from django.db.models import Q
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from .models import TaskList, Task


def visible_lists(user):
    return TaskList.objects.filter(Q(owner=user) | Q(memberships__user=user), is_deleted=False).distinct()


def visible_tasks(user):
    # Creating a task in a shared list does not bypass later membership removal.
    return Task.objects.filter(Q(task_list__isnull=True, owner=user) | Q(task_list__in=visible_lists(user)))


def list_role(task_list, user):
    if task_list.is_deleted:
        return None
    if task_list.owner_id == user.pk:
        return "owner"
    return task_list.memberships.filter(user=user).values_list("role", flat=True).first()


def require_list(task_list, user, *, write=False, owner=False):
    role = list_role(task_list, user)
    if role is None:
        raise NotFound()
    if (owner and role != "owner") or (write and role == "viewer"):
        raise PermissionDenied("This list is read-only for your account." if role == "viewer" else "Only the list owner can manage sharing and list details.")
    return role


def lock_task(pk, user, *, target_list=None, write=True):
    """Inside atomic(): lists first, then task. Membership changes lock the list.

    Recheck the task after locks: a concurrent personal-list move cannot use a
    stale access decision. Shared-list tasks stay in their list; exports create
    explicit personal copies instead of changing the group's ownership.
    """
    before = Task.objects.filter(pk=pk).first()
    list_ids = {before.task_list_id} if before and before.task_list_id else set()
    if target_list is not None:
        try:
            list_ids.add(uuid.UUID(str(target_list)))
        except (ValueError, TypeError):
            raise ValidationError({"list_id": "Use a valid list identifier."})
    locked = {row.pk: row for row in TaskList.objects.select_for_update().filter(pk__in=list_ids).order_by("id")}
    task = Task.objects.select_for_update().filter(pk=pk).first()
    if task:
        if task.task_list_id:
            if task.task_list_id not in locked:
                raise ValidationError("This task moved while syncing. Retry to refresh access.")
            require_list(locked[task.task_list_id], user, write=write)
        elif task.owner_id != user.pk:
            raise NotFound()
    if target_list is not None:
        target = locked.get(uuid.UUID(str(target_list)))
        if target is None or list_role(target, user) is None:
            raise ValidationError({"list_id": "Choose a list from this account."})
        require_list(target, user, write=write)
    return task, locked
