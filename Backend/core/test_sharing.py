import uuid
from datetime import timedelta
from pathlib import Path
from tempfile import TemporaryDirectory
from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient
from .models import User, Task, TaskList, ListMembership, ListInvitation, Attachment


class SharingTests(TestCase):
    def setUp(self):
        cache.clear()
        self.files = TemporaryDirectory(prefix='taskflow-sharing-tests-')
        self.addCleanup(self.files.cleanup)
        settings = override_settings(MEDIA_ROOT=self.files.name)
        settings.enable()
        self.addCleanup(settings.disable)
        self.people = [User.objects.create_user(f'sharing-{name}@example.invalid', 'Fixture-only!2026') for name in ['owner', 'editor', 'viewer', 'stranger']]
        self.owner, self.editor, self.viewer, self.stranger = self.people
        self.clients = []
        for user in self.people:
            client = APIClient()
            client.force_authenticate(user)
            self.clients.append(client)
        self.a, self.b, self.c, self.d = self.clients
        self.list = TaskList.objects.create(owner=self.owner, name='Household')
        self.path = f'/api/lists/{self.list.pk}/'
        self.codes = {}

    def invite(self, user, role):
        response = self.a.post(self.path + 'invite/', {'email': user.email.upper(), 'role': role}, format='json')
        self.assertIn(response.status_code, [200, 201], response.data)
        self.codes[response.data['id']] = response.data['code']
        return response.data['id']

    def join(self, user, client, role):
        key = self.invite(user, role)
        response = client.post(f'/api/invitations/{key}/respond/', {'decision': 'accept', 'code': self.codes[key]}, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        return key

    def task(self, client=None):
        key = uuid.uuid4()
        response = (client or self.a).put(f'/api/tasks/{key}/', {'title': 'Buy milk', 'list_id': str(self.list.pk), 'version': 0}, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        return key, response.data

    def upload(self, client, key):
        response = client.put(f'/api/attachments/{uuid.uuid4()}/', {'task_id': str(key), 'name': 'Recipe.txt', 'file': SimpleUploadedFile('file', b'Household recipe')}, format='multipart')
        self.assertEqual(response.status_code, 201, response.data)
        return response.data['id']

    def test_email_bound_invitation_acceptance_is_explicit_idempotent_and_private(self):
        key = self.invite(self.editor, 'editor')
        self.assertEqual(self.b.get('/api/lists/access/').data['lists'], [])
        self.assertEqual(self.d.get('/api/invitations/').data['invitations'], [])
        self.assertEqual(self.d.post(f'/api/invitations/{key}/respond/', {'decision': 'accept'}, format='json').status_code, 404)
        self.assertEqual(self.b.get('/api/invitations/').data['invitations'][0]['list_name'], 'Household')
        self.assertEqual(self.b.get('/api/invitations/').data['invitations'][0]['invited_by_name'], 'sharing-owner')
        self.assertNotIn('code', self.b.get('/api/invitations/').data['invitations'][0])
        self.assertEqual(self.b.post(f'/api/invitations/{key}/respond/', {'decision': 'accept', 'code': 'wrong-code'}, format='json').status_code, 400)
        self.assertFalse(ListMembership.objects.exists())
        for _ in range(2):
            self.assertEqual(self.b.post(f'/api/invitations/{key}/respond/', {'decision': 'accept', 'code': self.codes[key]}, format='json').status_code, 200)
        self.assertEqual(ListMembership.objects.count(), 1)
        access = self.b.get('/api/lists/access/').data['lists'][0]
        self.assertEqual(access['role'], 'editor')
        self.assertTrue(access['shared'])
        self.assertNotIn('members', self.b.get(self.path + 'sharing/').data)
        self.assertEqual(self.a.get(self.path + 'sharing/').data['members'][0]['user__email'], self.editor.email)

    def test_expiration_decline_revocation_and_invalid_roles(self):
        key = self.invite(self.editor, 'editor')
        ListInvitation.objects.filter(pk=key).update(expires_at=timezone.now() - timedelta(seconds=1))
        self.assertEqual(self.b.post(f'/api/invitations/{key}/respond/', {'decision': 'accept'}, format='json').status_code, 400)
        fresh = self.invite(self.editor, 'viewer')
        self.assertNotEqual(key, fresh)
        self.assertEqual(self.b.post(f'/api/invitations/{fresh}/respond/', {'decision': 'decline'}, format='json').status_code, 200)
        self.assertEqual(self.b.get('/api/lists/access/').data['lists'], [])
        key = self.invite(self.editor, 'editor')
        self.assertEqual(self.a.post(self.path + 'revoke_invite/', {'invitation_id': key}, format='json').status_code, 204)
        self.assertEqual(self.b.post(f'/api/invitations/{key}/respond/', {'decision': 'accept'}, format='json').status_code, 400)
        self.assertEqual(self.a.post(self.path + 'invite/', {'email': self.editor.email, 'role': 'owner'}, format='json').status_code, 400)

    def test_viewer_cannot_mutate_any_task_file_or_membership_surface(self):
        self.join(self.viewer, self.c, 'viewer')
        key, data = self.task()
        attachment = self.upload(self.a, key)
        for path in [f'/api/tasks/{key}/', f'/api/tasks/{key}/history/', f'/api/attachments/{attachment}/content/']:
            self.assertEqual(self.c.get(path).status_code, 200, path)
            self.assertEqual(self.d.get(path).status_code, 404, path)
        for method, path, payload in [
            ('put', f'/api/tasks/{key}/', {**data, 'title': 'Changed'}),
            ('delete', f'/api/tasks/{key}/', {'version': 1}),
            ('put', f'/api/tasks/{uuid.uuid4()}/', {'title': 'New', 'list_id': str(self.list.pk)}),
            ('delete', f'/api/attachments/{attachment}/', {}),
            ('put', self.path, {'name': 'Changed', 'version': 1}),
            ('post', self.path + 'invite/', {'email': self.stranger.email, 'role': 'editor'}),
            ('post', self.path + 'member/', {'user_id': self.owner.pk, 'role': 'remove'}),
            ('delete', self.path, {'version': 1})]:
            self.assertEqual(getattr(self.c, method)(path, payload, format='json').status_code, 403, path)
        upload = self.c.put(f'/api/attachments/{uuid.uuid4()}/', {'task_id': str(key), 'name': 'File', 'file': SimpleUploadedFile('file', b'no')}, format='multipart')
        self.assertEqual(upload.status_code, 403)
        self.assertEqual(Task.objects.get(pk=key).title, 'Buy milk')

    def test_two_people_edit_same_version_conflict_keeps_creator_and_list(self):
        self.join(self.editor, self.b, 'editor')
        key, data = self.task(self.b)
        owner_edit = self.a.put(f'/api/tasks/{key}/', {**data, 'title': 'Buy oat milk'}, format='json')
        self.assertEqual(owner_edit.status_code, 200, owner_edit.data)
        editor_edit = self.b.put(f'/api/tasks/{key}/', {**data, 'is_completed': True}, format='json')
        self.assertEqual(editor_edit.status_code, 409)
        self.assertEqual(editor_edit.data['current']['title'], 'Buy oat milk')
        task = Task.objects.get(pk=key)
        self.assertEqual(task.owner, self.editor)
        self.assertFalse(task.is_completed)
        for client in [self.a, self.b]:
            self.assertEqual(client.put(f'/api/tasks/{key}/', {**owner_edit.data, 'list_id': None}, format='json').status_code, 400)
        self.assertEqual(self.b.put(self.path, {'name': 'Wrong', 'version': 1}, format='json').status_code, 403)

    def test_removal_revokes_creator_access_and_file_bytes_and_blocks_replay(self):
        invitation = self.join(self.editor, self.b, 'editor')
        key, data = self.task(self.b)
        attachment = self.upload(self.b, key)
        self.assertEqual(self.a.post(self.path + 'member/', {'user_id': self.editor.pk, 'role': 'remove'}, format='json').status_code, 204)
        for path in [f'/api/tasks/{key}/', f'/api/tasks/{key}/history/', f'/api/attachments/{attachment}/', f'/api/attachments/{attachment}/content/']:
            self.assertEqual(self.b.get(path).status_code, 404, path)
        self.assertEqual(self.b.get('/api/lists/access/').data['lists'], [])
        self.assertEqual(self.b.get('/api/tasks/?include_deleted=true').data['results'], [])
        self.assertEqual(self.b.get('/api/attachments/?include_deleted=true').data['results'], [])
        self.assertEqual(self.b.put(f'/api/tasks/{key}/', data, format='json').status_code, 404)
        self.assertEqual(self.b.post(f'/api/invitations/{invitation}/respond/', {'decision': 'accept'}, format='json').status_code, 400)
        self.assertEqual(self.a.get(f'/api/tasks/{key}/').status_code, 200)

    def test_role_downgrade_leave_and_owner_delete_clean_group_and_files(self):
        self.join(self.editor, self.b, 'editor')
        self.join(self.viewer, self.c, 'viewer')
        key, data = self.task(self.b)
        attachment = self.upload(self.b, key)
        self.assertEqual(self.a.post(self.path + 'member/', {'user_id': self.editor.pk, 'role': 'viewer'}, format='json').status_code, 204)
        self.assertEqual(self.b.put(f'/api/tasks/{key}/', {**data, 'title': 'Changed'}, format='json').status_code, 403)
        self.assertEqual(self.b.get(f'/api/tasks/{key}/').status_code, 200)
        self.assertEqual(self.b.post(self.path + 'leave/').status_code, 204)
        self.assertEqual(self.b.get(f'/api/tasks/{key}/').status_code, 404)
        self.assertEqual(self.a.post(self.path + 'leave/').status_code, 400)
        self.assertEqual(self.a.delete(self.path, {'version': 1}, format='json').status_code, 409)
        version = self.a.get(self.path).data['version']
        with self.captureOnCommitCallbacks(execute=True):
            self.assertEqual(self.a.delete(self.path, {'version': version}, format='json').status_code, 204)
        self.assertTrue(Task.objects.get(pk=key).is_deleted)
        self.assertTrue(Attachment.objects.get(pk=attachment).is_deleted)
        self.assertEqual(list(Path(self.files.name).rglob('*.blob')), [])
        for client in self.clients:
            self.assertEqual(client.get(self.path).status_code, 404)
            self.assertEqual(client.get(f'/api/attachments/{attachment}/content/').status_code, 404)

    @override_settings(FREE_ATTACHMENT_BYTES=20)
    def test_group_files_use_list_owner_quota_and_moves_charge_nobody(self):
        self.join(self.editor, self.b, 'editor')
        key, _ = self.task(self.b)
        attachment = self.upload(self.b, key)
        response = self.a.put(f'/api/attachments/{uuid.uuid4()}/', {'task_id': str(key), 'name': 'Second', 'file': SimpleUploadedFile('file', b'Household recipe')}, format='multipart')
        self.assertEqual(response.status_code, 400)
        personal = uuid.uuid4()
        created = self.b.put(f'/api/tasks/{personal}/', {'title': 'Private', 'version': 0}, format='json')
        self.assertEqual(created.status_code, 201)
        self.upload(self.b, personal)  # The group upload did not consume this member's private quota.
        # A move uploads nothing: its bytes were charged to the member when uploaded.
        moved = self.b.put(f'/api/tasks/{personal}/', {**created.data, 'list_id': str(self.list.pk)}, format='json')
        self.assertEqual(moved.status_code, 200, moved.data)
        with self.captureOnCommitCallbacks(execute=True):
            self.assertEqual(self.a.delete(f'/api/attachments/{attachment}/').status_code, 204)
        # Removing a file keeps what was used.
        again = self.a.put(f'/api/attachments/{uuid.uuid4()}/', {'task_id': str(key), 'name': 'Third', 'file': SimpleUploadedFile('file', b'Household recipe')}, format='multipart')
        self.assertEqual(again.status_code, 400)
