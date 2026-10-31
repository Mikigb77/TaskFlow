from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("core", "0010_shared_lists")]
    operations = [migrations.AddField(model_name="listinvitation", name="code_digest",
        field=models.CharField(max_length=64, default=""), preserve_default=False)]
