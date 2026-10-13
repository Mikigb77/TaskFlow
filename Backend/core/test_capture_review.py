import json
from copy import deepcopy
from datetime import datetime, timezone
from unittest.mock import patch

from django.test import SimpleTestCase
from pydantic import ValidationError

from .ai import _generate_reviewable_once, extract_tasks, validate_draft, title_needs_shortening


class CaptureReviewTests(SimpleTestCase):
    def task(self, **changes):
        return dict(title="Revisar la aplicación", date="2026-10-13", time=None,
                    priority=1, notes="Sin añadir nuevas funciones.", **changes)

    def test_title_polish_preserves_schedule_and_all_existing_details(self):
        source = self.task()
        source.update(title="Tener la aplicación que esté funcionando y que no tenga que utilizar otra funcionalidad que no esté ya programada",
                      deadline_date="2026-10-16", deadline_time="17:00", project_name="Física", member_name="Ana")
        candidate = deepcopy(source)
        candidate.update(title="Comprobar el funcionamiento de la app", date="2030-01-01",
                         notes="Dropped notes", member_name="Someone else", priority=3)
        with patch('core.ai._generate_once', side_effect=[json.dumps({'tasks': [source]}), json.dumps({'tasks': [candidate]})]) as provider:
            result = validate_draft(_generate_reviewable_once('Original words', 10000)).tasks[0]
        self.assertEqual(provider.call_count, 2)
        self.assertLessEqual(provider.call_args.args[1], 10000)
        self.assertEqual(result.title, candidate['title'])
        self.assertEqual(str(result.date), source['date'])
        self.assertEqual(result.member_name, 'Ana')
        self.assertEqual(result.priority, 1)
        self.assertIn(source['notes'], result.notes)
        self.assertIn(source['title'], result.notes)
        self.assertEqual(str(result.deadline_time), '17:00:00')

    def test_acceptable_titles_do_not_add_provider_calls(self):
        raw = json.dumps({'tasks': [self.task()]})
        with patch('core.ai._generate_once', return_value=raw) as provider:
            self.assertEqual(_generate_reviewable_once('Words', 10000), raw)
        provider.assert_called_once()

    def test_polish_failure_keeps_valid_input_and_does_not_loop(self):
        item = self.task()
        item['title'] = 'Comprobar que la aplicación funciona con las características que están programadas actualmente'
        raw = json.dumps({'tasks': [item]})
        for response in [RuntimeError('Unavailable'), '{"tasks": []}', raw]:
            with self.subTest(response=type(response).__name__):
                with patch('core.ai._generate_once', side_effect=[raw, response]) as provider:
                    result = validate_draft(_generate_reviewable_once('Words', 10000)).tasks[0]
                    self.assertEqual(result.title, item['title'])
                    self.assertEqual(provider.call_count, 2)

    def test_explicit_time_choices_survive_localized_payload(self):
        item = self.task()
        item['clarifications'] = [{'field': 'schedule', 'question': '¿A las cinco de la mañana o de la tarde?', 'times': ['05:00', '17:00']}]
        with patch('core.ai.generate', return_value=json.dumps({'tasks': [item]})):
            result = extract_tasks('Mañana a las cinco reviso la aplicación', 'Europe/Madrid', datetime(2026, 10, 12, tzinfo=timezone.utc))['tasks'][0]
        self.assertEqual(result['scheduled_date'], '2026-10-13')
        self.assertIsNone(result['due_date'])
        self.assertEqual(result['clarifications'], item['clarifications'])
        self.assertIn(item['clarifications'][0]['question'], result['questions'])

    def test_question_choices_cannot_smuggle_arbitrary_actions(self):
        item = self.task()
        item['clarifications'] = [{'field': 'schedule', 'question': 'When?', 'times': ['delete-account']}]
        with self.assertRaises(ValidationError):
            validate_draft(json.dumps({'tasks': [item]}))

    def test_titles_are_not_shortened_by_cutting_words(self):
        self.assertTrue(title_needs_shortening('one two three four five six seven eight nine ten eleven twelve thirteen'))
        self.assertFalse(title_needs_shortening('Doctor appointment'))
