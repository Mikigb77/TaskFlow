"""A dictation with no task and no command uses no free dictation (D4, 2026-10-20; UX-1624)."""
import json
import uuid
from unittest.mock import patch

from django.core.cache import cache
from django.test import SimpleTestCase, TestCase, override_settings
from pydantic import ValidationError
from rest_framework.test import APIClient

from . import views
from .ai import validate_draft
from .models import FreeDictation, User

NOTHING = {"tasks": [], "commands": []}


class EmptyAnswerValidationTests(SimpleTestCase):
    def test_an_app_with_commands_gets_an_empty_answer_as_one(self):
        for answer in (NOTHING, [], {"tasks": []}, {"commands": []}):
            with self.subTest(answer=answer):
                result = validate_draft(json.dumps(answer), commands=True)
                self.assertEqual((result.tasks, result.commands), ([], []))

    def test_without_commands_an_answer_still_needs_a_task(self):
        for answer in (NOTHING, [], {"tasks": []}):
            with self.subTest(answer=answer), self.assertRaises(ValidationError):
                validate_draft(json.dumps(answer))


@override_settings(FREE_VOICE_CAPTURES_PER_MONTH=10)
class EmptyDictationTests(TestCase):
    def setUp(self):
        cache.clear()
        throttle = patch.object(views.DraftView, "throttle_classes", [])
        throttle.start()
        self.addCleanup(throttle.stop)
        self.user = User.objects.create_user("empty-dictation@example.invalid", "Empty-dictation-passphrase!2026")
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def dictate(self, answer, capture_id=None, **fields):
        data = {"text": "Hola, ¿me oyes?", "timezone": "Europe/Madrid", "commands": True, **fields}
        if capture_id is not None:
            data["capture_id"] = str(capture_id)
        with patch("core.ai.generate", return_value=json.dumps(answer, ensure_ascii=False)) as provider:
            response = self.client.post("/api/ai/drafts/", data, format="json")
        self.provider = provider
        return response

    def test_nothing_found_is_an_answer_that_uses_no_free_dictation(self):
        response = self.dictate(NOTHING)
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual((response.data["tasks"], response.data["commands"]), ([], []))
        self.assertEqual(response.data["transcript"], "Hola, ¿me oyes?")
        self.assertEqual(response.data["free_voice"]["left"], 10)
        self.assertFalse(FreeDictation.objects.exists())
        self.assertEqual(self.client.get("/api/auth/me/").data["free_voice"]["left"], 10)
        # A dictation with a task in it still counts.
        found = self.dictate({"tasks": [{"title": "Llamar al dentista", "date": None, "time": None, "priority": 1}]})
        self.assertEqual(found.data["free_voice"]["left"], 9)
        self.assertEqual(FreeDictation.objects.filter(counted=True).count(), 1)

    def test_a_command_that_comes_to_nothing_leaves_the_answer_empty_too(self):
        # A project named only with quotes is dropped, so nothing is left to review.
        response = self.dictate({"tasks": [], "commands": [{"kind": "project", "name": "«»"}]})
        self.assertEqual((response.status_code, response.data["commands"]), (200, []))
        self.assertEqual(response.data["free_voice"]["left"], 10)
        self.assertFalse(FreeDictation.objects.exists())

    def test_a_search_alone_still_counts(self):
        response = self.dictate({"tasks": [], "commands": [{"kind": "find", "words": ["examen"]}]})
        self.assertEqual(response.data["free_voice"]["left"], 9)

    def test_saying_it_again_asks_the_assistant_again_and_still_costs_nothing_if_empty(self):
        capture = uuid.uuid4()
        self.assertEqual(self.dictate(NOTHING, capture).data["free_voice"]["left"], 10)
        again = self.dictate(NOTHING, capture)
        self.assertEqual((again.status_code, again.data["free_voice"]["left"]), (200, 10))
        self.provider.assert_called_once()  # this second request reached the assistant too
        self.assertFalse(FreeDictation.objects.exists())

    @override_settings(FREE_VOICE_CAPTURES_PER_MONTH=1)
    def test_an_empty_answer_with_the_last_dictation_left_keeps_it(self):
        self.assertEqual(self.dictate(NOTHING).data["free_voice"]["left"], 1)
        found = self.dictate({"tasks": [{"title": "Comprar pan", "date": None, "time": None, "priority": 1}]})
        self.assertEqual((found.status_code, found.data["free_voice"]["left"]), (200, 0))

    def test_cancelled_while_understanding_is_still_cancelled(self):
        capture = uuid.uuid4()

        def understand(prompt, commands=False):
            self.assertEqual(self.client.delete(f"/api/ai/drafts/{capture}/").status_code, 204)
            return json.dumps(NOTHING)
        with patch("core.ai.generate", side_effect=understand):
            response = self.client.post("/api/ai/drafts/", {"text": "Hola", "timezone": "UTC", "commands": True,
                                                            "capture_id": str(capture)}, format="json")
        self.assertEqual((response.status_code, response.data["code"]), (409, "capture_cancelled"))
        self.assertFalse(FreeDictation.objects.exists())

    def test_failures_still_never_count(self):
        invalid = self.dictate({"commands": [{"kind": "answer", "text": "Sí, te oigo"}]})
        self.assertEqual(invalid.status_code, 502)
        without_the_flag = self.dictate(NOTHING, commands=False)  # an older app's answer must hold a task
        self.assertEqual(without_the_flag.status_code, 502)
        self.assertFalse(FreeDictation.objects.exists())
        self.assertEqual(self.client.get("/api/auth/me/").data["free_voice"]["left"], 10)

    @override_settings(AI_REQUESTS_PER_DAY=1)
    def test_an_empty_answer_still_counts_toward_the_daily_ai_limit(self):
        # The assistant did the work: the daily safeguard still bounds dictations that find nothing.
        self.assertEqual(self.dictate(NOTHING).status_code, 200)
        self.assertEqual(self.dictate(NOTHING).status_code, 429)
