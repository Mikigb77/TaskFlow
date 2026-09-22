from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from tempfile import TemporaryDirectory
from threading import Barrier
import uuid

from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.db import close_old_connections, connections
from django.test import TransactionTestCase, override_settings, skipUnlessDBFeature
from rest_framework.test import APIClient

from .models import Attachment, Task, User, TaskList, ListMembership


@skipUnlessDBFeature("has_select_for_update")
class AttachmentConcurrencyTests(TransactionTestCase):
    def setUp(self):
        cache.clear()
        self.directory = TemporaryDirectory(prefix="taskflow-concurrent-files-")
        self.addCleanup(self.directory.cleanup)
        settings = override_settings(MEDIA_ROOT=self.directory.name, ATTACHMENT_ACCOUNT_BYTES=5)
        settings.enable()
        self.addCleanup(settings.disable)
        self.owner = User.objects.create_user("concurrent-file@example.invalid", "Fixture-passphrase!2026")
        self.task = Task.objects.create(owner=self.owner, title="Concurrent upload")

    def upload_pair(self, ids):
        barrier = Barrier(2)
        def upload(id):
            close_old_connections()
            try:
                client = APIClient()
                client.force_authenticate(self.owner)
                barrier.wait(timeout=10)
                response = client.put(f"/api/attachments/{id}/", {
                    "task_id": str(self.task.pk), "name": "file.txt",
                    "file": SimpleUploadedFile("file.txt", b"four"),
                }, format="multipart")
                return response.status_code
            finally:
                connections.close_all()
        with ThreadPoolExecutor(max_workers=2) as pool:
            return sorted(pool.map(upload, ids))

    def test_simultaneous_uploads_cannot_exceed_account_quota(self):
        self.assertEqual(self.upload_pair([uuid.uuid4(), uuid.uuid4()]), [201, 400])
        self.assertEqual(Attachment.objects.count(), 1)
        self.assertEqual(sum(item.size for item in Attachment.objects.all()), 4)
        self.assertEqual(len(list(Path(self.directory.name).rglob("*.blob"))), 1)

    def test_simultaneous_retries_produce_one_file_and_identity(self):
        id = uuid.uuid4()
        self.assertEqual(self.upload_pair([id, id]), [200, 201])
        self.assertEqual(Attachment.objects.count(), 1)
        self.assertEqual(len(list(Path(self.directory.name).rglob("*.blob"))), 1)

    def test_different_members_and_lists_share_the_list_owners_quota(self):
        inputs = []
        for number in range(2):
            member = User.objects.create_user(f'member-{number}@example.invalid', 'Fixture-passphrase!2026')
            task_list = TaskList.objects.create(owner=self.owner, name=f'Household {number}', shared=True)
            ListMembership.objects.create(task_list=task_list, user=member, role='editor')
            task = Task.objects.create(owner=member, task_list=task_list, title='Recipe')
            inputs.append((member, task))
        barrier = Barrier(2)
        def upload(pair):
            close_old_connections()
            try:
                member, task = pair
                client = APIClient()
                client.force_authenticate(member)
                barrier.wait(timeout=10)
                return client.put(f'/api/attachments/{uuid.uuid4()}/', {
                    'task_id': str(task.pk), 'name': 'file.txt',
                    'file': SimpleUploadedFile('file.txt', b'four'),
                }, format='multipart').status_code
            finally:
                connections.close_all()
        with ThreadPoolExecutor(max_workers=2) as pool:
            self.assertEqual(sorted(pool.map(upload, inputs)), [201, 400])
        self.assertEqual(Attachment.objects.count(), 1)
