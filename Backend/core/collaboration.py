"""Assignment, activity and notification rules shared by every write surface."""
from .list_access import project_people
from .models import Task, TaskEvent, TaskNotification, ProjectPreference


def record_event(task, actor, action, *, details=None, previous_assignee=None):
    details = dict(details or {})
    if action == "assigned":
        # Who it went to then, for the activity entry: null when it's now everyone's or nobody's.
        # The id, never the name, so a later name shows and account deletion can scrub it.
        details["assignee_id"] = task.assignee_id
    event = TaskEvent.objects.create(task=task, actor=actor, version=task.version,
                                     action=action, details=details)
    project = task.task_list
    if not project or not project.shared:
        return event
    people = project_people(project)
    preferences = dict(ProjectPreference.objects.filter(task_list=project).values_list("user_id", "notifications"))
    # Whoever handed a one-off task to someone hears when that person completes it.
    handed_over_by = assigner(task) if action == "completed" and task.recurrence == "none" else None
    recipients = []
    for person in people:
        user_id = person["user_id"]
        preference = preferences.get(user_id, "assigned")
        if user_id == getattr(actor, "pk", None) or preference == "muted":
            continue
        responsible = (task.assignment == "group" or task.assignee_id == user_id or previous_assignee == user_id
                       or handed_over_by == user_id)
        needs_assignment = task.assignment == "unassigned" and person["role"] in ("owner", "admin")
        if preference == "all" or responsible or needs_assignment:
            recipients.append(TaskNotification(recipient_id=user_id, event=event))
    TaskNotification.objects.bulk_create(recipients)
    return event


def assigner(task):
    """Who gave the task to its assignee: whoever last assigned it to them, else the creator who
    made it already theirs. None when nobody is assigned, or it's the assignee's own doing."""
    if task.assignment != "member" or not task.assignee_id:
        return None
    event = task.events.filter(action="assigned").order_by("-version").first()
    if event is None:
        given_by = task.created_by_id
    elif event.details.get("assignee_id", task.assignee_id) == task.assignee_id:
        given_by = event.actor_id
    else:
        return None
    return given_by if given_by != task.assignee_id else None


def clear_assignments(project_ids, user_id, actor):
    # Call after locking all affected projects, then membership changes cannot
    # race a task save and re-introduce an inaccessible assignee.
    for task in Task.objects.select_for_update().filter(
            task_list_id__in=project_ids, assignee_id=user_id, is_deleted=False).order_by("id"):
        task.assignee = None
        task.assignment = "unassigned"
        task.version += 1
        task.save()
        record_event(task, actor, "unassigned", details={"previous_assignee_id": user_id})


def task_change_details(previous, current):
    keys = ("title", "assignment", "assignee_id", "due_date", "scheduled_date", "deadline_at",
            "deadline_date", "is_completed", "completed_dates", "priority", "notes", "checklist")
    return {"fields": [key for key in keys if previous.get(key) != getattr(current, key)]}
