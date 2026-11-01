"""One access rule for list metadata, tasks, history and private file bytes."""
import uuid
from django.db.models import Q
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from .models import TaskList, Task, TaskGroup


def visible_groups(user):
    return TaskGroup.objects.filter(Q(owner=user) | Q(memberships__user=user), is_deleted=False).distinct()


def group_role(group, user):
    if group.is_deleted:
        return None
    if group.owner_id == user.pk:
        return "owner"
    return group.memberships.filter(user=user).values_list("role", flat=True).first()


def require_group(group, user, *, manage=False, owner=False):
    role = group_role(group, user)
    if role is None:
        raise NotFound()
    if (owner and role != "owner") or (manage and role not in ("owner", "admin")):
        raise PermissionDenied("Only group administrators can manage this group.")
    return role


def display_name(user):
    return user.get_full_name().strip() or user.email.split("@")[0]


def group_people(group):
    people = [{"user_id": group.owner_id, "name": display_name(group.owner), "role": "owner", "voice_name": ""}]
    people.extend({"user_id": row.user_id, "name": display_name(row.user), "role": row.role,
                   "voice_name": row.voice_name} for row in group.memberships.select_related("user").order_by("user_id"))
    return people


def project_people(project):
    if project.group_id:
        return group_people(project.group)
    people = [{"user_id": project.owner_id, "name": display_name(project.owner), "role": "owner", "voice_name": ""}]
    people.extend({"user_id": row.user_id, "name": display_name(row.user), "role": row.role,
                   "voice_name": ""} for row in project.memberships.select_related("user").order_by("user_id"))
    return people


def visible_lists(user):
    return TaskList.objects.filter(
        Q(group__isnull=True) & (Q(owner=user) | Q(memberships__user=user)) |
        Q(group__in=visible_groups(user)), is_deleted=False).select_related("group").distinct()


def visible_tasks(user):
    # Creating a task in a shared list does not bypass later membership removal.
    return Task.objects.filter(Q(task_list__isnull=True, owner=user) | Q(task_list__in=visible_lists(user)))


def list_role(task_list, user):
    if task_list.is_deleted:
        return None
    if task_list.group_id:
        return group_role(task_list.group, user)
    if task_list.owner_id == user.pk:
        return "owner"
    return task_list.memberships.filter(user=user).values_list("role", flat=True).first()


def require_list(task_list, user, *, write=False, owner=False):
    role = list_role(task_list, user)
    if role is None:
        raise NotFound()
    managers = ("owner", "admin") if task_list.group_id else ("owner",)
    if (owner and role not in managers) or (write and role == "viewer"):
        raise PermissionDenied("This list is read-only for your account." if role == "viewer" else "Only the list owner can manage sharing and list details.")
    return role


def lock_task(pk, user, *, target_list=None, write=True, reader_ok=False):
    """Inside atomic(): lists first, then task. Membership changes lock the list.

    Recheck the task after locks: a concurrent personal-list move cannot use a
    stale access decision. Shared-list tasks stay in their list; exports create
    explicit personal copies instead of changing the group's ownership.

    reader_ok lets a viewer through for a task already in their list, so the
    caller can save their own reminders (D9); the caller refuses the rest.
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
            require_list(locked[task.task_list_id], user, write=write and not reader_ok)
        elif task.owner_id != user.pk:
            raise NotFound()
    if target_list is not None:
        target = locked.get(uuid.UUID(str(target_list)))
        if target is None or list_role(target, user) is None:
            raise ValidationError({"list_id": "Choose a list from this account."})
        stays = task is not None and target.pk == task.task_list_id
        require_list(target, user, write=write and not (reader_ok and stays))
    return task, locked
