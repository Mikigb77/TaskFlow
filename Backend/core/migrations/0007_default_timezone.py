from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("core", "0006_recurrence_rules")]
    operations = [
        migrations.AlterField(
            model_name="user", name="timezone",
            field=models.CharField(max_length=64, default="UTC"),
        ),
    ]
