import uuid
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [("core", "0009_task_planning")]
    operations = [
        migrations.AddField(model_name="tasklist", name="shared", field=models.BooleanField(default=False)),
        migrations.AddField(model_name="tasklist", name="is_deleted", field=models.BooleanField(default=False)),
        migrations.CreateModel(name="ListMembership", fields=[
            ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
            ("role", models.CharField(max_length=8, choices=[("editor", "editor"), ("viewer", "viewer")])),
            ("task_list", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="memberships", to="core.tasklist")),
            ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="list_memberships", to=settings.AUTH_USER_MODEL)),
        ], options={"constraints": [models.UniqueConstraint(fields=("task_list", "user"), name="unique_list_member"),
                                     models.CheckConstraint(condition=models.Q(role__in=["editor", "viewer"]), name="valid_list_role")]}),
        migrations.CreateModel(name="ListInvitation", fields=[
            ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
            ("email", models.EmailField(max_length=254)),
            ("role", models.CharField(max_length=8, choices=[("editor", "editor"), ("viewer", "viewer")])),
            ("expires_at", models.DateTimeField()),
            ("state", models.CharField(default="pending", max_length=8, choices=[(v, v) for v in ("pending", "accepted", "declined", "revoked")])),
            ("task_list", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="invitations", to="core.tasklist")),
        ], options={"constraints": [models.UniqueConstraint(fields=("task_list", "email"), name="unique_list_invitation")]}),
    ]
