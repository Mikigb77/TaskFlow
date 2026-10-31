from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("core", "0005_personal_lists")]
    operations = [
        migrations.AddField(model_name="task", name="repeat_interval", field=models.PositiveSmallIntegerField(default=1)),
        migrations.AddField(model_name="task", name="repeat_weekdays", field=models.JSONField(default=list, blank=True)),
        migrations.AddField(model_name="task", name="exceptions", field=models.JSONField(default=list, blank=True)),
    ]
