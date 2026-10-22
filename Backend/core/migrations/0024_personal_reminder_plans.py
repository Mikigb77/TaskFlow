import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


def rang_for(task):
    """Whose phone a task's plan rang on while plans belonged to the task: the person it's given
    to, else its creator, else its owner (docs/REMINDER_PLANS.md, D6)."""
    if task.assignment == "member" and task.assignee_id:
        return task.assignee_id
    return task.created_by_id or task.owner_id


def personal_plans(apps, schema_editor):
    Task = apps.get_model("core", "Task")
    TaskReminderPlan = apps.get_model("core", "TaskReminderPlan")
    database = schema_editor.connection.alias
    tasks = Task.objects.using(database).filter(reminder_plan__isnull=False).only(
        "pk", "assignment", "assignee_id", "created_by_id", "owner_id", "reminder_plan")
    TaskReminderPlan.objects.using(database).bulk_create(
        [TaskReminderPlan(task_id=task.pk, user_id=rang_for(task), plan=task.reminder_plan) for task in tasks])
    if schema_editor.connection.vendor == "postgresql":
        # As in 0021: the inserts leave deferred foreign-key checks queued, and PostgreSQL refuses
        # to alter core_task after this function ("pending trigger events"). Run them now.
        schema_editor.execute("SET CONSTRAINTS ALL IMMEDIATE")


def task_plans(apps, schema_editor):
    """Back to one plan per task: the plan of the person it rang for, else any member's."""
    Task = apps.get_model("core", "Task")
    TaskReminderPlan = apps.get_model("core", "TaskReminderPlan")
    database = schema_editor.connection.alias
    chosen = {}
    for row in TaskReminderPlan.objects.using(database).select_related("task").order_by("pk"):
        if row.task_id not in chosen or row.user_id == rang_for(row.task):
            chosen[row.task_id] = row.plan
    for task_id, plan in chosen.items():
        Task.objects.using(database).filter(pk=task_id).update(reminder_plan=plan)
    if schema_editor.connection.vendor == "postgresql":
        schema_editor.execute("SET CONSTRAINTS ALL IMMEDIATE")


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0023_task_reminder_plan"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="TaskReminderPlan",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("plan", models.JSONField()),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("task", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="reminder_plans",
                                           to="core.task")),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="reminder_plans",
                                           to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "constraints": [models.UniqueConstraint(fields=("task", "user"), name="one_reminder_plan_per_person")],
            },
        ),
        migrations.RunPython(personal_plans, task_plans),
        migrations.RemoveConstraint(
            model_name="task",
            name="valid_item_kind",
        ),
        migrations.RemoveField(
            model_name="task",
            name="reminder_plan",
        ),
        migrations.AddConstraint(
            model_name="task",
            constraint=models.CheckConstraint(condition=models.Q(("kind", "task"), models.Q(("deadline_at__isnull", True), ("deadline_date__isnull", True), ("due_date__isnull", True), ("duration_minutes__isnull", True), ("is_completed", False), ("kind", "note"), ("priority", 1), ("recurrence", "none"), ("reminder_anchor", "planned"), ("reminder_time__isnull", True), ("scheduled_date__isnull", True), models.Q(("reminder_minutes__isnull", True), ("reminder_minutes", -1), _connector="OR")), _connector="OR"), name="valid_item_kind"),
        ),
    ]
