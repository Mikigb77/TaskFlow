import io
import json
import uuid
import wave
from datetime import datetime, timezone
from unittest.mock import patch

from django.contrib.auth.tokens import default_token_generator
from django.core import mail
from django.core.cache import cache
from django.test import TestCase, override_settings
from django.utils.encoding import force_bytes
from django.utils.http import urlsafe_base64_encode
from rest_framework.test import APIClient
from google.genai import types, errors

from .ai import AIUnavailable, extract_task, transcribe, generate
from .models import User, Task, TaskEvent

PASSWORD = "Strong-example-passphrase!2026"


class APITests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.credentials = {"email": "owner@example.invalid", "password": PASSWORD, "timezone": "Europe/Madrid"}
        self.tokens = self.client.post("/api/auth/register/", self.credentials, format="json").data
        self.client.credentials(HTTP_AUTHORIZATION="Bearer " + self.tokens["access"])
        self.task_data = {"title": "Doctor appointment", "due_date": "2026-09-25T17:00:00+02:00", "priority": 3, "notes": "Bring blood test results."}

    def test_password_is_hashed_and_email_is_case_insensitive(self):
        user = User.objects.get(email=self.credentials["email"])
        self.assertTrue(user.password.startswith("argon2$"))
        other = APIClient()
        response = other.post("/api/auth/login/", {"email": "OWNER@EXAMPLE.INVALID", "password": PASSWORD}, format="json")
        self.assertEqual(response.status_code, 200)
        self.assertNotIn("password", response.data["user"])

    def test_weak_password_and_duplicate_email_rejected(self):
        other = APIClient()
        self.assertEqual(other.post("/api/auth/register/", {"email": "weak@example.invalid", "password": "password"}, format="json").status_code, 400)
        self.assertEqual(other.post("/api/auth/register/", {**self.credentials, "email": "OWNER@EXAMPLE.INVALID"}, format="json").status_code, 400)

    def test_unauthenticated_tasks_and_ai_are_blocked(self):
        other = APIClient()
        self.assertEqual(other.get("/api/tasks/").status_code, 401)
        self.assertEqual(other.post("/api/ai/draft/", {}, format="json").status_code, 401)

    def test_tasks_keep_time_offset_and_are_isolated_by_owner(self):
        response = self.client.post("/api/tasks/", self.task_data, format="json")
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data["due_date"], "2026-09-25T15:00:00Z")
        task_id = response.data["id"]
        second = APIClient()
        tokens = second.post("/api/auth/register/", {**self.credentials, "email": "second@example.invalid"}, format="json").data
        second.credentials(HTTP_AUTHORIZATION="Bearer " + tokens["access"])
        self.assertEqual(second.get("/api/tasks/").data["count"], 0)
        self.assertEqual(second.get(f"/api/tasks/{task_id}/").status_code, 404)
        self.assertEqual(second.put(f"/api/tasks/{task_id}/", self.task_data, format="json").status_code, 404)
        self.assertEqual(second.delete(f"/api/tasks/{task_id}/", {"version": 1}, format="json").status_code, 404)
        self.assertEqual(second.get(f"/api/tasks/{task_id}/history/").status_code, 404)

    def test_client_uuid_upload_conflicts_and_tombstone(self):
        task_id = uuid.uuid4()
        path = f"/api/tasks/{task_id}/"
        self.assertEqual(self.client.put(path, {**self.task_data, "version": 0}, format="json").status_code, 201)
        self.assertEqual(self.client.put(path, {**self.task_data, "version": 0}, format="json").status_code, 409)
        updated = self.client.put(path, {**self.task_data, "notes": "Updated", "version": 1}, format="json")
        self.assertEqual(updated.data["version"], 2)
        self.assertEqual(self.client.delete(path, {"version": 1}, format="json").status_code, 409)
        self.assertEqual(self.client.delete(path, {"version": 2}, format="json").status_code, 204)
        self.assertEqual(self.client.get("/api/tasks/").data["count"], 0)
        self.assertTrue(self.client.get("/api/tasks/?include_deleted=true").data["results"][0]["is_deleted"])
        self.assertEqual(TaskEvent.objects.count(), 3)

    def test_invalid_dates_and_priorities_rejected(self):
        for values in [{"priority": 5}, {"due_date": "2026-09-25T17:00:00"}, {"title": ""}]:
            self.assertEqual(self.client.post("/api/tasks/", {**self.task_data, **values}, format="json").status_code, 400)

    def test_malformed_task_id_returns_not_found(self):
        self.assertEqual(self.client.put("/api/tasks/" + "-" * 36 + "/", self.task_data, format="json").status_code, 404)

    def test_refresh_rotates_and_prevents_replay(self):
        other = APIClient()
        first = other.post("/api/auth/refresh/", {"refresh": self.tokens["refresh"]}, format="json")
        self.assertEqual(first.status_code, 200)
        self.assertNotEqual(first.data["refresh"], self.tokens["refresh"])
        self.assertEqual(other.post("/api/auth/refresh/", {"refresh": self.tokens["refresh"]}, format="json").status_code, 401)
        self.assertEqual(other.post("/api/auth/refresh/", {"refresh": first.data["refresh"]}, format="json").status_code, 200)

    def test_logout_revokes_access_and_refresh_immediately(self):
        self.assertEqual(self.client.post("/api/auth/logout/", {}, format="json").status_code, 204)
        self.assertEqual(self.client.get("/api/auth/me/").status_code, 401)
        self.assertEqual(APIClient().post("/api/auth/refresh/", {"refresh": self.tokens["refresh"]}, format="json").status_code, 401)

    def test_recovery_email_does_not_enumerate_accounts(self):
        other = APIClient()
        known = other.post("/api/auth/password-reset/", {"email": self.credentials["email"]}, format="json")
        unknown = other.post("/api/auth/password-reset/", {"email": "missing@example.invalid"}, format="json")
        self.assertEqual(known.data, unknown.data)
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn("recovery code", mail.outbox[0].body)

    def test_recovery_is_single_use_and_revokes_sessions(self):
        user = User.objects.get(email=self.credentials["email"])
        code = urlsafe_base64_encode(force_bytes(user.pk)) + ":" + default_token_generator.make_token(user)
        other = APIClient()
        payload = {"code": code, "password": "New-strong-passphrase!2026"}
        self.assertEqual(other.post("/api/auth/password-reset/confirm/", payload, format="json").status_code, 200)
        self.assertEqual(other.post("/api/auth/password-reset/confirm/", payload, format="json").status_code, 400)
        self.assertEqual(self.client.get("/api/auth/me/").status_code, 401)
        self.assertEqual(other.post("/api/auth/refresh/", {"refresh": self.tokens["refresh"]}, format="json").status_code, 401)
        self.assertEqual(other.post("/api/auth/login/", {"email": user.email, "password": payload["password"]}, format="json").status_code, 200)

    def test_login_failures_are_limited(self):
        other = APIClient()
        for _ in range(5):
            self.assertEqual(other.post("/api/auth/login/", {**self.credentials, "password": "wrong"}, format="json").status_code, 401)
        self.assertEqual(other.post("/api/auth/login/", self.credentials, format="json").status_code, 429)

    @override_settings(AI_REQUESTS_PER_DAY=1)
    @patch("core.views.ai.make_draft", return_value={"title": "Draft"})
    def test_drafts_do_not_save_tasks_and_daily_budget_is_enforced(self, mock):
        payload = {"text": "Call tomorrow", "timezone": "Europe/Madrid"}
        self.assertEqual(self.client.post("/api/ai/draft/", payload, format="json").status_code, 200)
        self.assertEqual(Task.objects.count(), 0)
        self.assertEqual(self.client.post("/api/ai/draft/", payload, format="json").status_code, 429)
        self.assertEqual(mock.call_count, 1)


class DraftTests(TestCase):
    def setUp(self):
        self.output = {"title": "Doctor appointment", "date": "2026-09-25", "time": "17:00", "priority": 3, "notes": "Bring last month's blood test results.", "questions": []}
        self.reference = datetime(2026, 9, 20, 10, tzinfo=timezone.utc)

    @patch("core.ai.clock.sleep")
    @patch("core.ai._generate_once")
    def test_transient_provider_failure_is_retried_once(self, provider, sleep):
        provider.side_effect = [errors.ServerError(503, {"error": {"message": "Unavailable"}}), "{}"]
        self.assertEqual(generate("Synthetic task"), "{}")
        self.assertEqual(provider.call_count, 2)
        self.assertLessEqual(provider.call_args.args[1], 45000)

    @patch("core.ai._generate_once")
    def test_provider_quota_does_not_trigger_retries(self, provider):
        provider.side_effect = errors.ClientError(429, {"error": {"message": "Quota"}})
        with self.assertRaises(errors.ClientError):
            generate("Synthetic task")
        self.assertEqual(provider.call_count, 1)

    @patch("core.ai.generate")
    def test_extraction_preserves_details_and_timezone(self, generate):
        generate.return_value = json.dumps(self.output)
        draft = extract_task("Friday at 5 pm, doctor, bring blood test results", "Europe/Madrid", self.reference)
        self.assertEqual(draft["due_date"], "2026-09-25T17:00:00+02:00")
        self.assertEqual(draft["priority"], 3)
        self.assertIn("blood test", draft["notes"])
        self.assertIn("Sunday", generate.call_args.args[0])

    @patch("core.ai.generate")
    def test_missing_time_is_not_midnight(self, generate):
        generate.return_value = json.dumps({**self.output, "time": None})
        result = extract_task("Doctor on Friday", "Europe/Madrid", self.reference)
        self.assertIsNone(result["due_date"])
        self.assertTrue(result["questions"])

    @patch("core.ai.generate")
    def test_daylight_saving_gap_is_flagged(self, generate):
        generate.return_value = json.dumps({**self.output, "date": "2027-03-28", "time": "02:30"})
        result = extract_task("March 28 at 02:30", "Europe/Madrid", self.reference)
        self.assertIsNone(result["due_date"])
        self.assertIn("daylight-saving", result["questions"][0])

    @patch("core.ai.generate")
    def test_empty_notes_from_model_are_normalized(self, generate):
        generate.return_value = json.dumps({**self.output, "notes": None, "time": None})
        result = extract_task("Friday at 5, doctor", "Europe/Madrid", self.reference)
        self.assertEqual(result["notes"], "")
        self.assertIsNone(result["due_date"])

    def test_invalid_audio_is_rejected_before_network_call(self):
        audio = io.BytesIO(b"not audio")
        audio.size = 9
        with self.assertRaises(AIUnavailable):
            transcribe(audio)

    @patch("core.ai.client")
    def test_transcription_reads_audio_transcription_parts(self, client):
        audio = io.BytesIO()
        with wave.open(audio, "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(16000)
            wav.writeframes(b"\0" * 32000)
        audio.size = len(audio.getvalue())
        audio.seek(0)
        client.return_value.__enter__.return_value.models.generate_content.return_value = types.GenerateContentResponse(
            candidates=[types.Candidate(content=types.Content(parts=[types.Part(
                audio_transcription=types.Transcription(text="Doctor appointment on Friday at 5 p.m."))]))])
        self.assertEqual(transcribe(audio), "Doctor appointment on Friday at 5 p.m.")

    def test_oversized_duration_is_rejected(self):
        audio = io.BytesIO()
        with wave.open(audio, "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(8000)
            wav.writeframes(b"\0" * (61 * 8000 * 2))
        audio.size = len(audio.getvalue())
        audio.seek(0)
        with self.assertRaises(AIUnavailable):
            transcribe(audio)
