from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("core", "0003_task_reminders")]
    operations = [migrations.AddField(model_name="task", name="checklist",
                                     field=models.JSONField(default=list, blank=True))]
