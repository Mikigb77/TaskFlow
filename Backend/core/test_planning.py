import uuid
from datetime import date
from django.core.cache import cache
from django.test import TestCase
from pydantic import ValidationError
from rest_framework.test import APIClient
from .ai import ExtractedTask, task_payload
from .models import User, Task
from .capture_evaluation import load_cases, score_output


class PlanningTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.user = User.objects.create_user('planning@example.invalid', 'Planning-test-only!2026')
        self.client.force_authenticate(self.user)
        self.path = f'/api/tasks/{uuid.uuid4()}/'
        self.payload = {'title': 'Report', 'due_date': '2026-09-24T09:00:00+02:00',
                        'deadline_at': '2026-09-25T17:00:00+02:00', 'duration_minutes': 60,
                        'reminder_anchor': 'deadline', 'version': 0}

    def test_independent_start_and_deadline_round_trip_old_client_and_conflict(self):
        created = self.client.put(self.path, self.payload, format='json')
        self.assertEqual(created.status_code, 201, created.data)
        self.assertEqual(created.data['due_date'], '2026-09-24T07:00:00Z')
        self.assertEqual(created.data['deadline_at'], '2026-09-25T15:00:00Z')
        old_client = {'title': 'Moved work slot', 'due_date': '2026-09-26T09:00:00Z', 'version': 1}
        moved = self.client.put(self.path, old_client, format='json')
        self.assertEqual(moved.status_code, 200, moved.data)
        for field in ['deadline_at', 'deadline_date', 'duration_minutes', 'reminder_anchor']:
            self.assertEqual(moved.data[field], created.data[field])
        stale = self.client.put(self.path, old_client, format='json')
        self.assertEqual(stale.status_code, 409)
        self.assertEqual(stale.data['current']['deadline_at'], created.data['deadline_at'])
        self.assertEqual(self.client.get('/api/tasks/').data['results'][0]['duration_minutes'], 60)
        other = User.objects.create_user('planning-other@example.invalid', 'Other-planning-test!2026')
        self.client.force_authenticate(other)
        self.assertEqual(self.client.put(self.path, {**self.payload, 'version': 2}, format='json').status_code, 404)

    def test_date_only_deadline_without_planned_start_and_explicit_clear(self):
        payload = {'title': 'File invoice', 'deadline_date': '2026-09-25', 'reminder_anchor': 'deadline', 'version': 0}
        created = self.client.put(self.path, payload, format='json')
        self.assertEqual(created.status_code, 201, created.data)
        self.assertIsNone(created.data['due_date'])
        self.assertIsNone(created.data['scheduled_date'])
        self.assertEqual(Task.objects.get().deadline_date, date(2026, 9, 25))
        cleared = self.client.put(self.path, {'title': 'Inbox', 'deadline_date': None, 'deadline_at': None,
                                            'duration_minutes': None, 'reminder_anchor': 'planned', 'version': 1}, format='json')
        self.assertEqual(cleared.status_code, 200, cleared.data)
        self.assertIsNone(cleared.data['deadline_date'])

    def test_rejects_invalid_and_conflicting_planning_fields(self):
        for invalid in [
            {'deadline_date': '2026-09-25'}, {'deadline_at': '2026-09-25T17:00:00'},
            {'deadline_at': None}, {'duration_minutes': 0}, {'duration_minutes': 1441},
            {'duration_minutes': 1.5}, {'reminder_anchor': 'both'},
        ]:
            with self.subTest(invalid=invalid):
                response = self.client.put(self.path, {**self.payload, **invalid}, format='json')
                self.assertEqual(response.status_code, 400, response.data)
        self.assertFalse(Task.objects.exists())

    def test_extraction_keeps_planning_deadlines_and_dst_questions_separate(self):
        extracted = ExtractedTask(title='Report', date='2026-09-24', time='09:00', priority=2,
                                  deadline_date='2026-09-25', deadline_time='17:00', duration_minutes=60)
        payload = task_payload(extracted, 'Work Thursday, due Friday', 'Europe/Madrid')
        self.assertEqual(payload['due_date'], '2026-09-24T09:00:00+02:00')
        self.assertEqual(payload['deadline_at'], '2026-09-25T17:00:00+02:00')
        self.assertEqual(payload['duration_minutes'], 60)
        self.assertFalse(payload['questions'])
        case = next(case for case in load_cases() if case['id'] == 'en-plan-and-deadline')
        self.assertTrue(score_output(case, {'tasks': [payload]})['passed'])
        for key in ['deadline_at', 'duration_minutes']:
            wrong = {**payload, key: None}
            self.assertFalse(score_output(case, {'tasks': [wrong]})['passed'])
        for day in ['2026-03-29', '2026-10-25']:
            draft = ExtractedTask(title='File', date=None, time=None, priority=1,
                                  deadline_date=day, deadline_time='02:30')
            result = task_payload(draft, 'Deadline', 'Europe/Madrid')
            self.assertIsNone(result['deadline_at'])
            self.assertEqual(result['deadline_date'], day)
            self.assertTrue(result['questions'])
        for duration in [0, 1441]:
            with self.assertRaises(ValidationError):
                ExtractedTask(title='File', date=None, time=None, priority=1, duration_minutes=duration)
