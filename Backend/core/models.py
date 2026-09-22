import uuid
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.db.models.functions import Lower


class UserManager(BaseUserManager):
    use_in_migrations = True

    def create_user(self, email, password=None, **extra):
        user = self.model(email=email.strip().casefold(), **extra)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password, **extra):
        return self.create_user(email, password, is_staff=True, is_superuser=True, **extra)


class User(AbstractUser):
    username = None
    email = models.EmailField(unique=True)
    timezone = models.CharField(max_length=64, default="UTC")
    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []
    objects = UserManager()

    class Meta:
        constraints = [models.UniqueConstraint(Lower("email"), name="unique_email_case_insensitive")]


class TaskList(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name="task_lists")
    name = models.CharField(max_length=80)
    color = models.CharField(max_length=8, default="teal", choices=[
        (value, value) for value in ("teal", "blue", "violet", "amber", "rose")])
    archived = models.BooleanField(default=False)
    version = models.PositiveIntegerField(default=1)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name", "id"]


class Task(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name="tasks")
    title = models.CharField(max_length=160)
    due_date = models.DateTimeField(null=True, blank=True)
    scheduled_date = models.DateField(null=True, blank=True)
    # due_date/scheduled_date are the legacy API names for the planned start.
    deadline_at = models.DateTimeField(null=True, blank=True)
    deadline_date = models.DateField(null=True, blank=True)
    duration_minutes = models.PositiveSmallIntegerField(null=True, blank=True)
    reminder_anchor = models.CharField(max_length=8, default="planned", choices=[("planned", "planned"), ("deadline", "deadline")])
    recurrence = models.CharField(max_length=8, default="none", choices=[
        (value, value) for value in ("none", "daily", "weekly", "monthly", "yearly")])
    repeat_until = models.DateField(null=True, blank=True)
    repeat_interval = models.PositiveSmallIntegerField(default=1)
    repeat_weekdays = models.JSONField(default=list, blank=True)
    exceptions = models.JSONField(default=list, blank=True)
    completed_dates = models.JSONField(default=list, blank=True)
    priority = models.PositiveSmallIntegerField(default=1)
    reminder_minutes = models.SmallIntegerField(null=True, blank=True)
    reminder_time = models.PositiveSmallIntegerField(null=True, blank=True)
    notes = models.TextField(blank=True, default="", max_length=8000)
    checklist = models.JSONField(default=list, blank=True)
    task_list = models.ForeignKey(TaskList, on_delete=models.SET_NULL, null=True, blank=True, related_name="tasks")
    labels = models.JSONField(default=list, blank=True)
    is_completed = models.BooleanField(default=False)
    is_deleted = models.BooleanField(default=False)
    version = models.PositiveIntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["created_at", "id"]
        indexes = [models.Index(fields=["owner", "updated_at"])]
        constraints = [
            models.CheckConstraint(condition=models.Q(priority__gte=1, priority__lte=3), name="valid_priority"),
            models.CheckConstraint(condition=models.Q(deadline_at__isnull=True) | models.Q(deadline_date__isnull=True), name="one_task_deadline"),
            models.CheckConstraint(condition=models.Q(duration_minutes__isnull=True) | models.Q(duration_minutes__gte=1, duration_minutes__lte=1440), name="valid_task_duration"),
            models.CheckConstraint(condition=models.Q(reminder_anchor="planned") | (models.Q(reminder_anchor="deadline") & (models.Q(deadline_at__isnull=False) | models.Q(deadline_date__isnull=False))), name="valid_reminder_anchor"),
        ]


class TaskEvent(models.Model):
    task = models.ForeignKey(Task, on_delete=models.CASCADE, related_name="events")
    version = models.PositiveIntegerField()
    action = models.CharField(max_length=16)
    created_at = models.DateTimeField(auto_now_add=True)


def attachment_path(instance, _filename):
    # Original names are metadata, never part of the storage path.
    return f"attachments/{instance.owner_id}/{instance.pk}.blob"


class Attachment(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name="attachments")
    task = models.ForeignKey(Task, on_delete=models.CASCADE, related_name="attachments")
    name = models.CharField(max_length=180)
    file = models.FileField(upload_to=attachment_path, max_length=240)
    size = models.PositiveIntegerField()
    sha256 = models.CharField(max_length=64)
    is_deleted = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["created_at", "id"]
        indexes = [models.Index(fields=["owner", "updated_at"], name="attachment_owner_updated")]


class LoginSession(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    expires_at = models.DateTimeField()
    revoked = models.BooleanField(default=False)
