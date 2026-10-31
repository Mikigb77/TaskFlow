from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("core", "0002_flexible_schedules")]
    operations = [
        migrations.AddField(model_name="task", name="reminder_minutes",
                            field=models.SmallIntegerField(null=True, blank=True)),
        migrations.AddField(model_name="task", name="reminder_time",
                            field=models.PositiveSmallIntegerField(null=True, blank=True)),
    ]
