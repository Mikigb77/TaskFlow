from django.db import migrations, models


class Migration(migrations.Migration):
    """More than one reminder before a timed task (docs/REMINDER_PLANS.md, reminder_extra_minutes).
    Every reminder saved so far stays a single one."""

    dependencies = [("core", "0028_attachment_usage")]

    operations = [
        migrations.AddField(
            model_name="taskreminder",
            name="extra_minutes",
            field=models.JSONField(blank=True, default=list),
        ),
    ]
