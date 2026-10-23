import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


def rang_for(task):
    """Whose phone a task's reminder rang on while reminders belonged to the task, as in 0024: the
    person it's given to, else its creator, else its owner (docs/REMINDER_PLANS.md)."""
    if task.assignment == "member" and task.assignee_id:
        return task.assignee_id
    return task.created_by_id or task.owner_id


def personal_single_reminders(apps, schema_editor):
    """Every single reminder chosen on a task goes to the person it rang for; the others keep their
    defaults from Settings (the owner, 2026-10-23: one person's change mustn't reach everyone)."""
    Task = apps.get_model("core", "Task")
    TaskReminder = apps.get_model("core", "TaskReminder")
    database = schema_editor.connection.alias
    chosen = Task.objects.using(database).filter(kind="task").filter(
        models.Q(reminder_minutes__isnull=False) | models.Q(reminder_time__isnull=False)
        | ~models.Q(reminder_anchor="planned"))
    for task in chosen.only("pk", "assignment", "assignee_id", "created_by_id", "owner_id",
                            "reminder_minutes", "reminder_time", "reminder_anchor"):
        TaskReminder.objects.using(database).update_or_create(
            task_id=task.pk, user_id=rang_for(task),
            defaults={"minutes": task.reminder_minutes, "time": task.reminder_time, "anchor": task.reminder_anchor})
    if schema_editor.connection.vendor == "postgresql":
        # As in 0021 and 0024: run the deferred foreign-key checks before core_task is altered.
        schema_editor.execute("SET CONSTRAINTS ALL IMMEDIATE")


def task_single_reminders(apps, schema_editor):
    """Back to one single reminder per task: the one of the person it rang for, else any member's.
    Rows that hold no plan go, as 0024's rows each hold one."""
    Task = apps.get_model("core", "Task")
    TaskReminder = apps.get_model("core", "TaskReminder")
    database = schema_editor.connection.alias
    chosen = {}
    for row in TaskReminder.objects.using(database).select_related("task").order_by("pk"):
        if row.task_id not in chosen or row.user_id == rang_for(row.task):
            chosen[row.task_id] = row
    for task_id, row in chosen.items():
        has_deadline = row.task.deadline_at is not None or row.task.deadline_date is not None
        Task.objects.using(database).filter(pk=task_id).update(
            reminder_minutes=row.minutes, reminder_time=row.time,
            reminder_anchor=row.anchor if has_deadline else "planned")
    TaskReminder.objects.using(database).filter(plan__isnull=True).delete()
    if schema_editor.connection.vendor == "postgresql":
        schema_editor.execute("SET CONSTRAINTS ALL IMMEDIATE")


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0024_personal_reminder_plans"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.RenameModel(old_name="TaskReminderPlan", new_name="TaskReminder"),
        migrations.RemoveConstraint(model_name="taskreminder", name="one_reminder_plan_per_person"),
        migrations.AddConstraint(
            model_name="taskreminder",
            constraint=models.UniqueConstraint(fields=("task", "user"), name="one_reminder_per_person"),
        ),
        migrations.AlterField(
            model_name="taskreminder",
            name="task",
            field=models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="reminders",
                                    to="core.task"),
        ),
        migrations.AlterField(
            model_name="taskreminder",
            name="user",
            field=models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="reminders",
                                    to=settings.AUTH_USER_MODEL),
        ),
        migrations.AlterField(
            model_name="taskreminder",
            name="plan",
            field=models.JSONField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="taskreminder",
            name="minutes",
            field=models.SmallIntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="taskreminder",
            name="time",
            field=models.PositiveSmallIntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="taskreminder",
            name="anchor",
            field=models.CharField(choices=[("planned", "planned"), ("deadline", "deadline")], default="planned",
                                   max_length=8),
        ),
        migrations.RunPython(personal_single_reminders, task_single_reminders),
        migrations.RemoveConstraint(model_name="task", name="valid_item_kind"),
        migrations.RemoveConstraint(model_name="task", name="valid_reminder_anchor"),
        migrations.RemoveField(model_name="task", name="reminder_anchor"),
        migrations.RemoveField(model_name="task", name="reminder_minutes"),
        migrations.RemoveField(model_name="task", name="reminder_time"),
        migrations.AddConstraint(
            model_name="task",
            constraint=models.CheckConstraint(condition=models.Q(("kind", "task"), models.Q(("deadline_at__isnull", True), ("deadline_date__isnull", True), ("due_date__isnull", True), ("duration_minutes__isnull", True), ("is_completed", False), ("kind", "note"), ("priority", 1), ("recurrence", "none"), ("scheduled_date__isnull", True)), _connector="OR"), name="valid_item_kind"),
        ),
    ]
