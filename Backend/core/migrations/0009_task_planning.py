from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("core", "0008_attachments")]
    operations = [
        migrations.AddField(model_name="task", name="deadline_at", field=models.DateTimeField(blank=True, null=True)),
        migrations.AddField(model_name="task", name="deadline_date", field=models.DateField(blank=True, null=True)),
        migrations.AddField(model_name="task", name="duration_minutes", field=models.PositiveSmallIntegerField(blank=True, null=True)),
        migrations.AddField(model_name="task", name="reminder_anchor", field=models.CharField(choices=[("planned", "planned"), ("deadline", "deadline")], default="planned", max_length=8)),
        migrations.AddConstraint(model_name="task", constraint=models.CheckConstraint(condition=models.Q(deadline_at__isnull=True) | models.Q(deadline_date__isnull=True), name="one_task_deadline")),
        migrations.AddConstraint(model_name="task", constraint=models.CheckConstraint(condition=models.Q(duration_minutes__isnull=True) | models.Q(duration_minutes__gte=1, duration_minutes__lte=1440), name="valid_task_duration")),
        migrations.AddConstraint(model_name="task", constraint=models.CheckConstraint(condition=models.Q(reminder_anchor="planned") | (models.Q(reminder_anchor="deadline") & (models.Q(deadline_at__isnull=False) | models.Q(deadline_date__isnull=False))), name="valid_reminder_anchor")),
    ]
