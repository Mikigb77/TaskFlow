import uuid
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [("core", "0004_task_checklist")]
    operations = [
        migrations.CreateModel(name="TaskList", fields=[
            ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
            ("name", models.CharField(max_length=80)),
            ("color", models.CharField(choices=[(v, v) for v in ("teal", "blue", "violet", "amber", "rose")], default="teal", max_length=8)),
            ("archived", models.BooleanField(default=False)),
            ("version", models.PositiveIntegerField(default=1)),
            ("updated_at", models.DateTimeField(auto_now=True)),
            ("owner", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="task_lists", to=settings.AUTH_USER_MODEL)),
        ], options={"ordering": ["name", "id"]}),
        migrations.AddField(model_name="task", name="task_list", field=models.ForeignKey(blank=True, null=True,
            on_delete=django.db.models.deletion.SET_NULL, related_name="tasks", to="core.tasklist")),
        migrations.AddField(model_name="task", name="labels", field=models.JSONField(default=list, blank=True)),
    ]
