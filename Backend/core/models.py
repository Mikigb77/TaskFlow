import uuid
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.db.models.functions import Lower
from django.utils import timezone


class RuntimeState(models.Model):
    key = models.CharField(primary_key=True, max_length=100)
    value = models.JSONField()
    expires_at = models.DateTimeField(db_index=True)


class EmailDelivery(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    recipient = models.EmailField()
    subject = models.CharField(max_length=200)
    body = models.TextField()
    # Deleting/reissuing an invitation also cancels any unsent email for it.
    group_invitation = models.ForeignKey("GroupInvitation", null=True, on_delete=models.CASCADE)
    list_invitation = models.ForeignKey("ListInvitation", null=True, on_delete=models.CASCADE)
    state = models.CharField(max_length=10, default="pending")
    attempts = models.PositiveIntegerField(default=0)
    next_attempt_at = models.DateTimeField(default=timezone.now)
    expires_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)


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
    # Stable, opaque RevenueCat App User ID, shared across this account's devices.
    billing_id = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []
    objects = UserManager()

    class Meta:
        constraints = [models.UniqueConstraint(Lower("email"), name="unique_email_case_insensitive")]


class GoogleIdentity(models.Model):
    # Google's stable subject, never email, is the external account identifier.
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="google_identity")
    subject = models.CharField(max_length=255, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)


class TaskGroup(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(User, on_delete=models.PROTECT, related_name="owned_groups")
    name = models.CharField(max_length=80)
    archived = models.BooleanField(default=False)
    is_deleted = models.BooleanField(default=False)
    version = models.PositiveIntegerField(default=1)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name", "id"]


class GroupMembership(models.Model):
    group = models.ForeignKey(TaskGroup, on_delete=models.CASCADE, related_name="memberships")
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="group_memberships")
    role = models.CharField(max_length=8, choices=[(v, v) for v in ("admin", "editor", "viewer")])
    voice_name = models.CharField(max_length=60, blank=True, default="")

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["group", "user"], name="unique_group_member"),
            models.CheckConstraint(condition=models.Q(role__in=["admin", "editor", "viewer"]), name="valid_group_role"),
        ]


class GroupInvitation(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    group = models.ForeignKey(TaskGroup, on_delete=models.CASCADE, related_name="invitations")
    email = models.EmailField()
    role = models.CharField(max_length=8, choices=[(v, v) for v in ("admin", "editor", "viewer")])
    expires_at = models.DateTimeField()
    code_digest = models.CharField(max_length=64)
    state = models.CharField(max_length=8, default="pending", choices=[(v, v) for v in ("pending", "accepted", "declined", "revoked")])

    class Meta:
        constraints = [models.UniqueConstraint(fields=["group", "email"], name="unique_group_invitation")]


class TaskList(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name="task_lists")
    group = models.ForeignKey(TaskGroup, on_delete=models.PROTECT, null=True, blank=True, related_name="projects")
    name = models.CharField(max_length=80)
    color = models.CharField(max_length=8, default="teal", choices=[
        (value, value) for value in ("teal", "blue", "violet", "amber", "rose")])
    archived = models.BooleanField(default=False)
    shared = models.BooleanField(default=False)
    is_deleted = models.BooleanField(default=False)
    version = models.PositiveIntegerField(default=1)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name", "id"]


class ListMembership(models.Model):
    task_list = models.ForeignKey(TaskList, on_delete=models.CASCADE, related_name="memberships")
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="list_memberships")
    role = models.CharField(max_length=8, choices=[("editor", "editor"), ("viewer", "viewer")])

    class Meta:
        constraints = [models.UniqueConstraint(fields=["task_list", "user"], name="unique_list_member"),
                       models.CheckConstraint(condition=models.Q(role__in=["editor", "viewer"]), name="valid_list_role")]


class ListInvitation(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    task_list = models.ForeignKey(TaskList, on_delete=models.CASCADE, related_name="invitations")
    email = models.EmailField()
    role = models.CharField(max_length=8, choices=[("editor", "editor"), ("viewer", "viewer")])
    expires_at = models.DateTimeField()
    code_digest = models.CharField(max_length=64)
    state = models.CharField(max_length=8, default="pending", choices=[(v, v) for v in ("pending", "accepted", "declined", "revoked")])

    class Meta:
        constraints = [models.UniqueConstraint(fields=["task_list", "email"], name="unique_list_invitation")]


class ProjectPreference(models.Model):
    task_list = models.ForeignKey(TaskList, on_delete=models.CASCADE, related_name="preferences")
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="project_preferences")
    pinned = models.BooleanField(default=False)
    notifications = models.CharField(max_length=8, default="assigned", choices=[(v, v) for v in ("all", "assigned", "muted")])

    class Meta:
        constraints = [models.UniqueConstraint(fields=["task_list", "user"], name="unique_project_preference")]


class Task(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name="tasks")
    assignment = models.CharField(max_length=10, default="personal", choices=[(v, v) for v in ("personal", "member", "group", "unassigned")])
    assignee = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name="assigned_tasks")
    title = models.CharField(max_length=160)
    kind = models.CharField(max_length=4, default="task", choices=[("task", "task"), ("note", "note")])
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
            models.CheckConstraint(condition=models.Q(kind="task") | (models.Q(kind="note", due_date__isnull=True, scheduled_date__isnull=True, deadline_at__isnull=True, deadline_date__isnull=True, duration_minutes__isnull=True, recurrence="none", priority=1, is_completed=False, reminder_time__isnull=True, reminder_anchor="planned") & (models.Q(reminder_minutes__isnull=True) | models.Q(reminder_minutes=-1))), name="valid_item_kind"),
            models.CheckConstraint(condition=models.Q(priority__gte=1, priority__lte=3), name="valid_priority"),
            models.CheckConstraint(condition=models.Q(deadline_at__isnull=True) | models.Q(deadline_date__isnull=True), name="one_task_deadline"),
            models.CheckConstraint(condition=models.Q(duration_minutes__isnull=True) | models.Q(duration_minutes__gte=1, duration_minutes__lte=1440), name="valid_task_duration"),
            models.CheckConstraint(condition=models.Q(reminder_anchor="planned") | (models.Q(reminder_anchor="deadline") & (models.Q(deadline_at__isnull=False) | models.Q(deadline_date__isnull=False))), name="valid_reminder_anchor"),
        ]


class TaskEvent(models.Model):
    task = models.ForeignKey(Task, on_delete=models.CASCADE, related_name="events")
    version = models.PositiveIntegerField()
    action = models.CharField(max_length=16)
    actor = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name="task_events")
    details = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)


class TaskNotification(models.Model):
    recipient = models.ForeignKey(User, on_delete=models.CASCADE, related_name="task_notifications")
    event = models.ForeignKey(TaskEvent, on_delete=models.CASCADE, related_name="notifications")
    read_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-id"]
        constraints = [models.UniqueConstraint(fields=["recipient", "event"], name="unique_task_notification")]


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


class FreeDictation(models.Model):
    # One AI dictation by an account without Pro. Pro dictations are not recorded.
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="free_dictations")
    period = models.CharField(max_length=7)  # "2026-10", the UTC calendar month
    capture_id = models.UUIDField(null=True)  # the app's capture UUID, so it can be cancelled
    digest = models.CharField(max_length=64)  # sha256 of the capture type and the words or WAV bytes
    counted = models.BooleanField(default=False)  # False while the AI is still working
    created_at = models.DateTimeField()  # set from the same clock as period

    class Meta:
        indexes = [models.Index(fields=["user", "period"], name="free_dictation_month")]
