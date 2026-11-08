"""The files of a completed task are deleted 15 days after it was completed (maintain_staging)."""
from datetime import datetime, timedelta, timezone as dt_timezone
from io import StringIO
from tempfile import TemporaryDirectory
import uuid

from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.management import call_command
from django.db import connection
from django.db.migrations.executor import MigrationExecutor
from django.test import TestCase, TransactionTestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from .attachment_views import sweep
from .models import Attachment, Task, TaskList, User


class CompletedTaskFileCleanupTests(TestCase):
    def setUp(self):
        cache.clear()
        self.files = TemporaryDirectory(prefix="taskflow-cleanup-")
        self.addCleanup(self.files.cleanup)
        limits = override_settings(MEDIA_ROOT=self.files.name, FREE_ATTACHMENT_BYTES=100)
        limits.enable()
        self.addCleanup(limits.disable)
        self.user = User.objects.create_user("cleanup@example.invalid", "Fixture-passphrase!2026")
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        self.now = timezone.now()

    def task(self, completed_days_ago=None, **fields):
        done = completed_days_ago is not None
        return Task.objects.create(owner=self.user, title="Paperwork", is_completed=done,
                                   completed_at=self.now - timedelta(days=completed_days_ago) if done else None, **fields)

    def attach(self, task, days_ago=30):
        id = uuid.uuid4()
        response = self.client.put(f"/api/attachments/{id}/", {
            "task_id": str(task.pk), "name": "scan.pdf",
            "file": SimpleUploadedFile("upload", b"x" * 10, content_type="application/octet-stream")}, format="multipart")
        self.assertEqual(response.status_code, 201, response.data)
        Attachment.objects.filter(pk=id).update(created_at=self.now - timedelta(days=days_ago))
        return Attachment.objects.get(pk=id)

    def run_sweep(self):
        with self.captureOnCommitCallbacks(execute=True):
            return sweep(self.now)

    def test_files_go_15_days_after_completion_and_usage_stays(self):
        old, recent, open_task = self.task(16), self.task(14), self.task()
        gone, kept, active = self.attach(old), self.attach(recent), self.attach(open_task)
        self.assertEqual(self.run_sweep(), 1)
        for item, deleted in ((gone, True), (kept, False), (active, False)):
            item.refresh_from_db()
            self.assertIs(item.is_deleted, deleted)
            self.assertIs(item.file.storage.exists(item.file.name), not deleted)
        listed = self.client.get(f"/api/attachments/?include_deleted=true&task_id={old.pk}").data["results"]
        self.assertTrue(listed[0]["is_deleted"])  # Other devices drop their copy on sync.
        self.assertEqual(self.client.get(f"/api/attachments/{gone.pk}/content/").status_code, 404)
        self.assertEqual(self.client.get("/api/auth/me/").json()["storage"]["used_bytes"], 30)
        old.refresh_from_db()
        self.assertFalse(old.is_deleted)  # The task itself stays.
        self.assertEqual(self.run_sweep(), 0)  # Idempotent.

    def test_a_file_added_after_completion_gets_its_own_15_days(self):
        task = self.task(20)
        item = self.attach(task, days_ago=3)
        self.assertEqual(self.run_sweep(), 0)
        item.refresh_from_db()
        self.assertFalse(item.is_deleted)

    def test_a_reopened_task_keeps_its_files(self):
        task = self.task(20)
        item = self.attach(task)
        Task.objects.filter(pk=task.pk).update(is_completed=False, completed_at=None)
        self.assertEqual(self.run_sweep(), 0)
        item.refresh_from_db()
        self.assertFalse(item.is_deleted)

    def test_a_completion_without_a_time_counts_from_the_last_change(self):
        task = self.task(20)
        item = self.attach(task)
        Task.objects.filter(pk=task.pk).update(completed_at=None, updated_at=self.now - timedelta(days=10))
        self.assertEqual(self.run_sweep(), 0)
        Task.objects.filter(pk=task.pk).update(updated_at=self.now - timedelta(days=16))
        self.assertEqual(self.run_sweep(), 1)
        item.refresh_from_db()
        self.assertTrue(item.is_deleted)

    def test_shared_projects_follow_the_same_rule(self):
        project = TaskList.objects.create(owner=self.user, name="Household", shared=True)
        item = self.attach(self.task(16, task_list=project))
        self.assertEqual(self.run_sweep(), 1)
        item.refresh_from_db()
        self.assertTrue(item.is_deleted)

    def test_the_daily_maintenance_job_runs_it(self):
        item = self.attach(self.task(16))
        out = StringIO()
        with self.captureOnCommitCallbacks(execute=True):
            call_command("maintain_staging", stdout=out)
        self.assertIn("1 files of completed tasks deleted", out.getvalue())
        item.refresh_from_db()
        self.assertTrue(item.is_deleted)
        self.assertFalse(item.file.storage.exists(item.file.name))


class UsageMigrationTests(TransactionTestCase):
    """Migration 0028: files uploaded before it count, removed ones too, charged to the quota owner."""
    before = [("core", "0027_meetings")]
    after = [("core", "0028_attachment_usage")]

    def migrate(self, target):
        executor = MigrationExecutor(connection)
        executor.loader.build_graph()
        executor.migrate(target)
        return executor.loader.project_state(target).apps

    def test_existing_uploads_are_counted_by_month_and_owner(self):
        apps = self.migrate(self.before)
        User, Task, TaskList, Attachment = (apps.get_model("core", name) for name in ("User", "Task", "TaskList", "Attachment"))
        ana, marc = (User.objects.create(email=f"{name}-usage@example.invalid") for name in ("ana", "marc"))
        project = TaskList.objects.create(owner=ana, name="Casa", shared=True)
        personal = Task.objects.create(owner=marc, title="Personal")
        shared = Task.objects.create(owner=marc, title="Compartida", task_list=project)
        october = datetime(2026, 10, 5, tzinfo=dt_timezone.utc)
        for task, size, deleted, at in ((personal, 5, False, october), (personal, 7, True, october),
                                        (shared, 11, False, october), (shared, 13, False, october + timedelta(days=30))):
            row = Attachment.objects.create(owner=marc, task=task, name="f", file="x.blob", size=size, sha256="0" * 64,
                                            is_deleted=deleted)
            Attachment.objects.filter(pk=row.pk).update(created_at=at)
        apps = self.migrate(self.after)
        rows = set(apps.get_model("core", "AttachmentUsage").objects.values_list("user__email", "period", "bytes"))
        self.assertEqual(rows, {("marc-usage@example.invalid", "2026-10", 12), ("ana-usage@example.invalid", "2026-10", 11),
                                ("ana-usage@example.invalid", "2026-11", 13)})
        self.migrate(MigrationExecutor(connection).loader.graph.leaf_nodes())
