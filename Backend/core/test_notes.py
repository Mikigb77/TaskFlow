import io
import uuid
import wave
from tempfile import TemporaryDirectory
from unittest.mock import patch
from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from rest_framework.test import APIClient
from .models import User, TaskList, ListMembership


class NoteTests(TestCase):
    def setUp(self):
        cache.clear()
        self.owner = User.objects.create_user('note-owner@example.invalid', 'Synthetic-note-2026!')
        self.member = User.objects.create_user('note-member@example.invalid', 'Synthetic-note-2026!')
        self.a, self.b = APIClient(), APIClient()
        self.a.force_authenticate(self.owner)
        self.b.force_authenticate(self.member)

    def create(self, **fields):
        key = uuid.uuid4()
        result = self.a.put(f'/api/tasks/{key}/', {
            'kind': 'note', 'title': 'Appointment reference',
            'notes': 'Opening hours: Friday 17:00. https://example.org/info',
            'version': 0, **fields}, format='json')
        self.assertEqual(result.status_code, 201, result.data)
        return key, result.data

    def test_note_type_survives_legacy_updates_conflicts_and_isolation(self):
        self.assertTrue(self.a.get('/api/health/').json()['features']['notes'])
        key, note = self.create()
        self.assertEqual(note['kind'], 'note')
        self.assertIsNone(note['due_date'])
        self.assertIsNone(note['reminder_minutes'])
        update = self.a.put(f'/api/tasks/{key}/', {'title': 'Retained type', 'notes': note['notes'], 'version': 1}, format='json')
        self.assertEqual(update.status_code, 200, update.data)
        self.assertEqual(update.data['kind'], 'note')
        stale = self.a.put(f'/api/tasks/{key}/', {**note, 'title': 'Stale'}, format='json')
        self.assertEqual(stale.status_code, 409)
        self.assertEqual(stale.data['current']['kind'], 'note')
        self.assertEqual(self.b.get(f'/api/tasks/{key}/').status_code, 404)
        self.assertEqual(self.b.get('/api/tasks/').data['results'], [])

    def test_notes_reject_schedules_completion_and_silent_type_changes(self):
        for field, value in [('due_date', '2026-09-25T17:00:00Z'), ('scheduled_date', '2026-09-25'),
                             ('deadline_at', '2026-09-25T17:00:00Z'), ('duration_minutes', 30),
                             ('priority', 3), ('reminder_minutes', 10), ('reminder_time', 540),
                             ('is_completed', True), ('repeat_interval', 2), ('kind', 'memo')]:
            with self.subTest(field=field):
                result = self.a.put(f'/api/tasks/{uuid.uuid4()}/', {'kind': 'note', 'title': 'Reference', field: value}, format='json')
                self.assertEqual(result.status_code, 400, result.data)
        key, note = self.create()
        self.assertEqual(self.a.put(f'/api/tasks/{key}/', {**note, 'kind': 'task'}, format='json').status_code, 400)
        task = self.a.post('/api/tasks/', {'title': 'Normal task'}, format='json')
        self.assertEqual(task.data['kind'], 'task')
        self.assertEqual(self.a.put(f"/api/tasks/{task.data['id']}/", {**task.data, 'kind': 'note'}, format='json').status_code, 400)

    def test_shared_note_checklist_file_and_revocation_use_the_same_access_rules(self):
        group = TaskList.objects.create(owner=self.owner, name='Household', shared=True)
        membership = ListMembership.objects.create(task_list=group, user=self.member, role='editor')
        step = {'id': str(uuid.uuid4()), 'title': 'Reference checked', 'completed': True, 'completed_dates': []}
        key, note = self.create(list_id=str(group.id), checklist=[step])
        changed = self.b.put(f'/api/tasks/{key}/', {**note, 'notes': 'Updated reference'}, format='json')
        self.assertEqual(changed.status_code, 200, changed.data)
        self.assertTrue(changed.data['checklist'][0]['completed'])
        with TemporaryDirectory(prefix='taskflow-note-test-') as directory, override_settings(MEDIA_ROOT=directory):
            fid = uuid.uuid4()
            upload = self.b.put(f'/api/attachments/{fid}/', {'task_id': str(key), 'name': 'Reference.txt', 'file': SimpleUploadedFile('file', b'Reference only')}, format='multipart')
            self.assertEqual(upload.status_code, 201, upload.data)
            self.assertEqual(self.a.get(f'/api/attachments/{fid}/content/').status_code, 200)
            membership.role = 'viewer'
            membership.save()
            self.assertEqual(self.b.put(f'/api/tasks/{key}/', changed.data, format='json').status_code, 403)
            membership.delete()
            self.assertEqual(self.b.get(f'/api/tasks/{key}/').status_code, 404)
            self.assertEqual(self.b.get(f'/api/attachments/{fid}/content/').status_code, 404)

    @patch('core.ai.extract_tasks')
    @patch('core.ai.transcribe')
    @patch("core.views.require_pro", new=lambda user: None)
    def test_note_capture_keeps_words_and_never_extracts_commitments(self, transcribe, extract):
        words = 'Ideas for Friday at 17:00\nBring up the reference next month.'
        text = self.a.post('/api/ai/drafts/', {'text': words, 'timezone': 'Europe/Madrid', 'capture_type': 'note'}, format='json')
        self.assertEqual(text.status_code, 200, text.data)
        self.assertEqual(text.data['tasks'][0]['notes'], words)
        self.assertEqual(text.data['tasks'][0]['kind'], 'note')
        self.assertIsNone(text.data['tasks'][0]['due_date'])
        transcribe.assert_not_called()
        extract.assert_not_called()
        wav = io.BytesIO()
        with wave.open(wav, 'wb') as recording:
            recording.setnchannels(1)
            recording.setsampwidth(2)
            recording.setframerate(16000)
            recording.writeframes(b'\0' * 32000)
        transcribe.return_value = words
        voice = self.a.post('/api/ai/drafts/', {'audio': SimpleUploadedFile('note.wav', wav.getvalue(), content_type='audio/wav'), 'timezone': 'UTC', 'capture_type': 'note'}, format='multipart')
        self.assertEqual(voice.status_code, 200, voice.data)
        self.assertEqual(voice.data['tasks'][0]['notes'], words)
        transcribe.assert_called_once()
        extract.assert_not_called()

    @patch('core.ai.transcribe')
    def test_invalid_note_input_cannot_be_silently_truncated(self, transcribe):
        transcribe.return_value = 'x' * 8001
        from .ai import make_drafts, AIUnavailable
        with self.assertRaises(AIUnavailable):
            make_drafts({'audio': object(), 'capture_type': 'note'})
        self.assertEqual(self.a.post('/api/ai/drafts/', {'text': 'Reference', 'timezone': 'UTC', 'capture_type': 'other'}, format='json').status_code, 400)
