from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("core", "0001_initial")]
    operations = [
        migrations.AlterField(model_name="task", name="due_date", field=models.DateTimeField(blank=True, null=True)),
        migrations.AddField(model_name="task", name="scheduled_date", field=models.DateField(blank=True, null=True)),
        migrations.AddField(model_name="task", name="recurrence", field=models.CharField(max_length=8, default="none", choices=[(v, v) for v in ("none", "daily", "weekly", "monthly", "yearly")])),
        migrations.AddField(model_name="task", name="repeat_until", field=models.DateField(blank=True, null=True)),
        migrations.AddField(model_name="task", name="completed_dates", field=models.JSONField(default=list, blank=True)),
    ]
