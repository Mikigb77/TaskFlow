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
    timezone = models.CharField(max_length=64, default="Europe/Madrid")
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
        constraints = [models.CheckConstraint(condition=models.Q(priority__gte=1, priority__lte=3), name="valid_priority")]


class TaskEvent(models.Model):
    task = models.ForeignKey(Task, on_delete=models.CASCADE, related_name="events")
    version = models.PositiveIntegerField()
    action = models.CharField(max_length=16)
    created_at = models.DateTimeField(auto_now_add=True)


class LoginSession(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    expires_at = models.DateTimeField()
    revoked = models.BooleanField(default=False)
