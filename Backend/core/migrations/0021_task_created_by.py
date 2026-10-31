import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models
from django.db.models import F


def creators_of_existing_tasks(apps, schema_editor):
    """Until now a task's creator was its owner, so existing tasks get their owner.

    Except when the creator's account was deleted: the task was then handed to the project's
    owner, and its "created" activity lost its actor. Such a task gets no creator, so the
    project's owner is never shown as having created it."""
    Task = apps.get_model("core", "Task")
    TaskEvent = apps.get_model("core", "TaskEvent")
    database = schema_editor.connection.alias
    Task.objects.using(database).update(created_by=F("owner"))
    orphaned = TaskEvent.objects.using(database).filter(action="created", actor__isnull=True).values("task_id")
    Task.objects.using(database).filter(pk__in=orphaned).update(created_by=None)
    if schema_editor.connection.vendor == "postgresql":
        # The updates leave deferred foreign-key checks queued on core_task, and Django creates
        # created_by's index after this function, in the same transaction. PostgreSQL refuses
        # that ("cannot CREATE INDEX ... pending trigger events") on any database with tasks,
        # so run the checks now. The tests use SQLite and an empty table, so they never saw it.
        schema_editor.execute("SET CONSTRAINTS ALL IMMEDIATE")


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0020_email_verification"),
    ]

    operations = [
        migrations.AddField(
            model_name="task",
            name="created_by",
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL,
                                    related_name="created_tasks", to=settings.AUTH_USER_MODEL),
        ),
        # Last. Django still adds created_by's index after it, in the same transaction, which is
        # why creators_of_existing_tasks runs the deferred checks before it returns.
        migrations.RunPython(creators_of_existing_tasks, migrations.RunPython.noop),
    ]
