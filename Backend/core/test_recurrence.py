import uuid
from django.core.cache import cache
from django.test import TestCase
from rest_framework.test import APIClient
from pydantic import ValidationError
from .models import User
from .ai import ExtractedTask, task_payload
from .capture_evaluation import load_cases, score_output


class RecurrenceTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.client.force_authenticate(User.objects.create_user('repeat@example.invalid', 'Repeat-test-password!2026'))
        self.path = f'/api/tasks/{uuid.uuid4()}/'
        self.payload = {'title': 'Review', 'scheduled_date': '2026-09-23', 'recurrence': 'weekly',
                        'repeat_interval': 2, 'repeat_weekdays': [5, 3, 3], 'version': 0,
                        'exceptions': [{'original_date': '2026-09-23', 'scheduled_date': '2026-09-25'},
                                       {'original_date': '2026-10-07', 'skipped': True}]}

    def test_round_trip_conflict_and_old_client_preserve_individual_changes(self):
        created = self.client.put(self.path, self.payload, format='json')
        self.assertEqual(created.status_code, 201, created.data)
        self.assertEqual(created.data['repeat_weekdays'], [3, 5])
        self.assertEqual(created.data['exceptions'][0]['scheduled_date'], '2026-09-25')
        self.assertTrue(created.data['exceptions'][1]['skipped'])
        older = {key: value for key, value in self.payload.items() if key not in ('repeat_interval', 'repeat_weekdays', 'exceptions')}
        older['version'] = 1
        updated = self.client.put(self.path, older, format='json')
        self.assertEqual(updated.status_code, 200, updated.data)
        for field in ['repeat_interval', 'repeat_weekdays', 'exceptions']:
            self.assertEqual(updated.data[field], created.data[field])
        stale = self.client.put(self.path, older, format='json')
        self.assertEqual(stale.status_code, 409)
        self.assertEqual(stale.data['current']['exceptions'], created.data['exceptions'])

    def test_rule_and_exception_bounds_reject_contradictory_schedules(self):
        invalid = [
            {'repeat_interval': 0}, {'repeat_interval': 100}, {'repeat_weekdays': [0]},
            {'repeat_weekdays': [8]}, {'recurrence': 'daily'}, {'recurrence': 'none'},
            {'exceptions': [{'original_date': '2026-09-23'}]},
            {'exceptions': [{'original_date': '2026-09-23', 'skipped': True, 'scheduled_date': '2026-09-25'}]},
            {'exceptions': [{'original_date': '2026-09-23', 'due_date': '2026-09-25T09:00:00'}]},
            {'exceptions': [{'original_date': '2026-09-23', 'due_date': '2026-09-25T09:00:00Z', 'scheduled_date': '2026-09-25'}]},
            {'exceptions': [self.payload['exceptions'][0]] * 2},
            {'exceptions': [{'original_date': '2026-02-30', 'skipped': True}]},
        ]
        for fields in invalid:
            with self.subTest(fields=fields):
                response = self.client.put(self.path, {**self.payload, **fields}, format='json')
                self.assertEqual(response.status_code, 400, response.data)

    def test_timed_move_uses_offset_and_stopping_repeat_clears_new_rules(self):
        payload = {**self.payload, 'exceptions': [{'original_date': '2026-09-23', 'due_date': '2026-09-25T10:00:00+02:00'}]}
        created = self.client.put(self.path, payload, format='json')
        self.assertEqual(created.status_code, 201, created.data)
        self.assertEqual(created.data['exceptions'][0]['due_date'], '2026-09-25T08:00:00Z')
        updated = self.client.put(self.path, {'title': 'Inbox', 'recurrence': 'none', 'version': 1}, format='json')
        self.assertEqual(updated.status_code, 200, updated.data)
        self.assertEqual(updated.data['exceptions'], [])
        self.assertEqual(updated.data['repeat_interval'], 1)
        self.assertEqual(updated.data['repeat_weekdays'], [])

    def test_ai_rule_normalization_clarification_and_evaluation(self):
        task = ExtractedTask(title='Gym', date='2026-09-23', time=None, priority=1, recurrence='weekly', repeat_interval=2, repeat_weekdays=[5, 3, 3])
        output = task_payload(task, 'Gym every other Wednesday and Friday', 'Europe/Madrid')
        self.assertEqual(output['repeat_interval'], 2)
        self.assertEqual(output['repeat_weekdays'], [3, 5])
        inconsistent = ExtractedTask(title='Gym', date='2026-09-23', time=None, priority=1, recurrence='monthly', repeat_weekdays=[3])
        self.assertTrue(task_payload(inconsistent, 'Gym', 'Europe/Madrid')['questions'])
        for fields in [{'repeat_interval': 0}, {'repeat_interval': 100}, {'repeat_weekdays': [8]}]:
            with self.assertRaises(ValidationError):
                ExtractedTask(title='Gym', date='2026-09-23', time=None, priority=1, **fields)
        case = next(case for case in load_cases() if case['id'] == 'en-alternate-weekdays')
        self.assertTrue(score_output(case, {'tasks': [output]})['passed'])
        output['repeat_interval'] = 1
        self.assertIn('task_0:repeat_interval', score_output(case, {'tasks': [output]})['errors'])
