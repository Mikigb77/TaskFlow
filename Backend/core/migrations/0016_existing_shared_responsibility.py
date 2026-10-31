from django.db import migrations
from django.db.models import F
from django.utils import timezone


def shared_responsibility(apps, schema_editor):
    # Preserve identities, content and memberships. Only make the previously
    # implicit shared responsibility explicit and advance sync versions.
    Task = apps.get_model("core", "Task")
    Task.objects.filter(kind="task", task_list__shared=True).update(
        assignment="group", version=F("version") + 1, updated_at=timezone.now())


class Migration(migrations.Migration):
    dependencies = [("core", "0015_task_assignee_task_assignment_taskevent_actor_and_more")]
    operations = [migrations.RunPython(shared_responsibility, migrations.RunPython.noop)]
