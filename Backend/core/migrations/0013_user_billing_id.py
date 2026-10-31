import uuid
from django.db import migrations, models


def populate_billing_ids(apps, schema_editor):
    User = apps.get_model("core", "User")
    users = User.objects.using(schema_editor.connection.alias)
    for user in users.filter(billing_id__isnull=True).iterator():
        users.filter(pk=user.pk).update(billing_id=uuid.uuid4())


class Migration(migrations.Migration):
    dependencies = [("core", "0012_standalone_notes")]
    operations = [
        migrations.AddField(
            model_name="user", name="billing_id",
            field=models.UUIDField(null=True, editable=False),
        ),
        migrations.RunPython(populate_billing_ids, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="user", name="billing_id",
            field=models.UUIDField(default=uuid.uuid4, unique=True, editable=False),
        ),
    ]
