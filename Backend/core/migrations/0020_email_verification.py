import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


def existing_accounts_are_confirmed(apps, schema_editor):
    # Every account made before email verification existed counts as confirmed.
    User = apps.get_model("core", "User")
    User.objects.using(schema_editor.connection.alias).update(email_verified=True)


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0019_groupinvitation_invited_by"),
    ]

    operations = [
        migrations.AddField(
            model_name="user",
            name="email_verified",
            field=models.BooleanField(default=False),
        ),
        migrations.CreateModel(
            name="EmailVerification",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("code_digest", models.CharField(max_length=64)),
                ("expires_at", models.DateTimeField()),
                ("attempts", models.PositiveSmallIntegerField(default=0)),
                ("sent_at", models.DateTimeField()),
                ("hour_started_at", models.DateTimeField()),
                ("sent_this_hour", models.PositiveSmallIntegerField(default=0)),
                ("language", models.CharField(default="en", max_length=2)),
                ("delivery_id", models.UUIDField(blank=True, null=True)),
                ("user", models.OneToOneField(on_delete=django.db.models.deletion.CASCADE,
                                              related_name="email_verification",
                                              to=settings.AUTH_USER_MODEL)),
            ],
        ),
        # Last, so no schema change follows the update in the same transaction.
        migrations.RunPython(existing_accounts_are_confirmed, migrations.RunPython.noop),
    ]
