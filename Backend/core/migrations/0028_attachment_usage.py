import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


def count_existing_uploads(apps, schema_editor):
    """Every file uploaded so far counts, removed ones included, charged like new uploads:
    to the project's owner, or to the uploader for a personal task, in the month it was added."""
    Attachment = apps.get_model("core", "Attachment")
    AttachmentUsage = apps.get_model("core", "AttachmentUsage")
    totals = {}
    for owner_id, list_owner_id, size, created_at in Attachment.objects.values_list(
            "owner_id", "task__task_list__owner_id", "size", "created_at").iterator():
        key = (list_owner_id or owner_id, created_at.strftime("%Y-%m"))
        totals[key] = totals.get(key, 0) + size
    AttachmentUsage.objects.bulk_create(
        [AttachmentUsage(user_id=user_id, period=period, bytes=size) for (user_id, period), size in totals.items()],
        batch_size=500)


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0027_meetings"),
    ]

    operations = [
        migrations.CreateModel(
            name="AttachmentUsage",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("period", models.CharField(max_length=7)),
                ("bytes", models.BigIntegerField(default=0)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="attachment_usage", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "constraints": [models.UniqueConstraint(fields=("user", "period"), name="attachment_usage_month")],
            },
        ),
        migrations.RunPython(count_existing_uploads, migrations.RunPython.noop),
    ]
