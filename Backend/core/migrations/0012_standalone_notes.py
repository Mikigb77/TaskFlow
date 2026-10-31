from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("core", "0011_invitation_codes")]
    operations = [
        migrations.AddField(model_name="task", name="kind", field=models.CharField(max_length=4, default="task", choices=[("task", "task"), ("note", "note")])),
        migrations.AddConstraint(model_name="task", constraint=models.CheckConstraint(
            condition=models.Q(kind="task") | (models.Q(kind="note", due_date__isnull=True, scheduled_date__isnull=True, deadline_at__isnull=True, deadline_date__isnull=True, duration_minutes__isnull=True, recurrence="none", priority=1, is_completed=False, reminder_time__isnull=True, reminder_anchor="planned") & (models.Q(reminder_minutes__isnull=True) | models.Q(reminder_minutes=-1))), name="valid_item_kind")),
    ]
