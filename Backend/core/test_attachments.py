import hashlib
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch
import uuid

from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.db import IntegrityError
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from .models import Attachment, Task, User


class AttachmentTests(TestCase):
    def setUp(self):
        cache.clear()
        self.directory = TemporaryDirectory(prefix="taskflow-attachment-tests-")
        self.addCleanup(self.directory.cleanup)
        self.settings_override = override_settings(MEDIA_ROOT=self.directory.name)
        self.settings_override.enable()
        self.addCleanup(self.settings_override.disable)
        self.owner = User.objects.create_user("file-owner@example.invalid", "Fixture-passphrase!2026")
        self.other = User.objects.create_user("other-file-owner@example.invalid", "Fixture-passphrase!2026")
        self.task = Task.objects.create(owner=self.owner, title="Appointment")
        self.other_task = Task.objects.create(owner=self.other, title="Other task")
        self.client = APIClient()
        self.client.force_authenticate(self.owner)
        self.other_client = APIClient()
        self.other_client.force_authenticate(self.other)

    def upload(self, id=None, content=b"fixture document", name="Results.pdf", client=None, task=None):
        id = id or uuid.uuid4()
        return (client or self.client).put(f"/api/attachments/{id}/", {
            "task_id": str((task or self.task).pk), "name": name,
            "file": SimpleUploadedFile("upload", content, content_type="application/octet-stream"),
        }, format="multipart")

    def test_upload_retry_download_and_fresh_client_restore_original_bytes(self):
        id = uuid.uuid4()
        data = b"\x00PDF fixture\r\nwith binary \xff"
        response = self.upload(id, data, "Análisis.pdf")
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data["sha256"], hashlib.sha256(data).hexdigest())
        self.assertEqual(response.data["size"], len(data))
        self.assertNotIn("file", response.data)
        self.assertNotIn(self.directory.name, str(response.data))
        self.assertEqual(self.upload(id, data, "Análisis.pdf").status_code, 200)
        self.assertEqual(Attachment.objects.count(), 1)
        self.assertEqual(len(list(Path(self.directory.name).rglob("*.blob"))), 1)
        fresh = APIClient()
        fresh.force_authenticate(self.owner)
        metadata = fresh.get(f"/api/attachments/?task_id={self.task.pk}").data["results"]
        self.assertEqual(metadata[0]["id"], str(id))
        downloaded = fresh.get(f"/api/attachments/{id}/content/")
        self.assertEqual(downloaded.status_code, 200)
        self.assertEqual(b"".join(downloaded.streaming_content), data)
        self.assertEqual(downloaded["Content-Type"], "application/octet-stream")
        self.assertTrue(downloaded["Content-Disposition"].startswith("attachment;"))
        self.assertEqual(downloaded["Cache-Control"], "private, no-store")
        self.assertTrue(downloaded.closed)  # The test client's stream wrapper closes it once.
        self.task.refresh_from_db()
        self.assertEqual(self.task.version, 1)  # File retries cannot conflict with task edits.

    def test_account_ownership_and_immutable_identity_cannot_be_bypassed(self):
        id = uuid.uuid4()
        self.assertEqual(self.upload(id).status_code, 201)
        for method in ("get", "delete"):
            self.assertEqual(getattr(self.other_client, method)(f"/api/attachments/{id}/").status_code, 404)
        self.assertEqual(self.other_client.get(f"/api/attachments/{id}/content/").status_code, 404)
        self.assertEqual(self.other_client.get("/api/attachments/?include_deleted=true").data["count"], 0)
        self.assertEqual(self.upload(id, client=self.other_client, task=self.other_task).status_code, 404)
        self.assertEqual(self.upload(client=self.other_client, task=self.task).status_code, 404)
        self.assertEqual(APIClient().get(f"/api/attachments/{id}/content/").status_code, 401)
        self.assertEqual(self.upload(id, b"changed bytes").status_code, 409)
        self.assertEqual(self.upload(id, name="Renamed.pdf").status_code, 409)
        self.assertEqual(Attachment.objects.count(), 1)

    def test_bounded_files_safe_names_and_storage_quota(self):
        for name in ("../secret", "C:\\secret", "bad\nname", "\u202eevil.pdf", ".."):
            self.assertEqual(self.upload(name=name).status_code, 400)
        self.assertEqual(self.upload(content=b"").status_code, 400)
        with override_settings(ATTACHMENT_MAX_BYTES=3):
            self.assertEqual(self.upload(content=b"four").status_code, 400)
        with override_settings(FREE_ATTACHMENT_BYTES=5):
            self.assertEqual(self.upload(content=b"four").status_code, 201)
            self.assertEqual(self.upload(content=b"two").status_code, 400)
        self.assertEqual(Attachment.objects.count(), 1)

    def test_removal_is_idempotent_and_prevents_old_retry_resurrection(self):
        id = uuid.uuid4()
        self.upload(id)
        item = Attachment.objects.get(pk=id)
        with self.captureOnCommitCallbacks(execute=True):
            self.assertEqual(self.client.delete(f"/api/attachments/{id}/").status_code, 204)
            self.assertEqual(self.client.delete(f"/api/attachments/{id}/").status_code, 204)
        self.assertFalse(item.file.storage.exists(item.file.name))
        self.assertEqual(self.client.get(f"/api/attachments/{id}/content/").status_code, 404)
        self.assertEqual(self.upload(id).status_code, 409)
        self.assertTrue(self.client.get("/api/attachments/?include_deleted=true").data["results"][0]["is_deleted"])

    def test_task_tombstone_revokes_and_removes_attachments_without_changing_other_tasks(self):
        id = uuid.uuid4()
        self.upload(id)
        other_id = uuid.uuid4()
        self.upload(other_id, client=self.other_client, task=self.other_task)
        item = Attachment.objects.get(pk=id)
        with self.captureOnCommitCallbacks(execute=True):
            response = self.client.put(f"/api/tasks/{self.task.pk}/", {"title": self.task.title, "version": 1, "is_deleted": True}, format="json")
            self.assertEqual(response.status_code, 200, response.data)
        self.assertFalse(item.file.storage.exists(item.file.name))
        self.assertEqual(self.client.get(f"/api/attachments/{id}/content/").status_code, 404)
        self.assertEqual(self.upload().status_code, 404)
        self.assertTrue(self.client.get("/api/attachments/?include_deleted=true").data["results"][0]["is_deleted"])
        self.assertFalse(Attachment.objects.get(pk=other_id).is_deleted)

    def test_failed_database_insert_cleans_blob_and_retry_succeeds(self):
        id = uuid.uuid4()
        with patch.object(Attachment, "save", side_effect=IntegrityError("fixture database failure")):
            self.assertEqual(self.upload(id).status_code, 404)
        self.assertFalse(Attachment.objects.exists())
        self.assertFalse(any(path.is_file() for path in Path(self.directory.name).rglob("*")))
        self.assertEqual(self.upload(id).status_code, 201)

    def test_missing_storage_is_visible_and_same_content_retry_repairs_it(self):
        id = uuid.uuid4()
        self.upload(id)
        item = Attachment.objects.get(pk=id)
        item.file.storage.delete(item.file.name)
        self.assertEqual(self.client.get(f"/api/attachments/{id}/content/").status_code, 503)
        self.assertEqual(self.upload(id).status_code, 200)
        item.refresh_from_db()
        self.assertTrue(item.file.storage.exists(item.file.name))
