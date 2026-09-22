import io
import json
import uuid
import wave
from datetime import datetime, timezone
from unittest.mock import patch

from django.contrib.auth.tokens import default_token_generator
from django.core import mail
from django.core.cache import cache
from django.core.management import call_command
from django.test import TestCase, override_settings
from django.utils.encoding import force_bytes
from django.utils.http import urlsafe_base64_encode
from rest_framework.test import APIClient
from google.genai import types, errors

from .ai import AIUnavailable, extract_task, extract_tasks, transcribe, generate, make_drafts
from .models import User, Task, TaskEvent

PASSWORD = "Strong-example-passphrase!2026"


@override_settings(LOCAL_TEST_ACCOUNT_ENABLED=True,
                   LOCAL_TEST_ACCOUNT_EMAIL="test@taskflow.local",
                   LOCAL_TEST_ACCOUNT_PASSWORD=PASSWORD)
class LocalTestAccountTests(TestCase):
    def seed(self):
        call_command("seed_test_user", stdout=io.StringIO())

    def test_seed_creates_one_regular_user_and_preserves_tasks(self):
        self.seed()
        user = User.objects.get(email="test@taskflow.local")
        original_hash = user.password
        Task.objects.create(owner=user, title="Keep this test task",
                            due_date=datetime(2026, 9, 25, 15, tzinfo=timezone.utc))
        self.seed()
        user.refresh_from_db()
        self.assertEqual(User.objects.count(), 1)
        self.assertEqual(user.password, original_hash)
        self.assertTrue(user.check_password(PASSWORD))
        self.assertFalse(user.is_staff or user.is_superuser)
        self.assertEqual(user.tasks.count(), 1)
        self.assertContains(self.client.get("/"), "Use test account")

    @override_settings(LOCAL_TEST_ACCOUNT_ENABLED=False)
    def test_disabled_setting_does_not_seed_or_expose_credentials(self):
        self.seed()
        self.assertFalse(User.objects.exists())
        page = self.client.get("/")
        self.assertNotContains(page, 'id="test-account-data"')
        self.assertNotContains(page, PASSWORD)

    def test_existing_credentials_and_privileges_are_not_overwritten(self):
        user = User.objects.create_user("test@taskflow.local", "Existing-secret!2026", is_staff=True)
        self.seed()
        user.refresh_from_db()
        self.assertTrue(user.check_password("Existing-secret!2026"))
        self.assertTrue(user.is_staff)
        self.assertNotContains(self.client.get("/"), 'id="test-account-data"')


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

    def test_unauthenticated_tasks_are_blocked_and_drafts_require_valid_input(self):
        other = APIClient()
        self.assertEqual(other.get("/api/tasks/").status_code, 401)
        self.assertEqual(other.post("/api/ai/drafts/", {}, format="json").status_code, 400)

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

    def test_reminder_choices_roundtrip_and_conflict_without_priority_coupling(self):
        path = f"/api/tasks/{uuid.uuid4()}/"
        payload = {**self.task_data, "priority": 1, "reminder_minutes": 30, "reminder_time": 540, "version": 0}
        created = self.client.put(path, payload, format="json")
        self.assertEqual(created.status_code, 201, created.data)
        restored = self.client.get(path).data
        self.assertEqual(restored["reminder_minutes"], 30)
        self.assertEqual(restored["reminder_time"], 540)
        updated = self.client.put(path, {**payload, "reminder_minutes": -1, "version": 1}, format="json")
        self.assertEqual(updated.status_code, 200, updated.data)
        conflict = self.client.put(path, {**payload, "version": 1}, format="json")
        self.assertEqual(conflict.status_code, 409)
        self.assertEqual(conflict.data["current"]["reminder_minutes"], -1)

    def test_reminder_limits_and_defaults(self):
        for field, value in [("reminder_minutes", -2), ("reminder_minutes", 10081),
                             ("reminder_time", -1), ("reminder_time", 1440)]:
            response = self.client.post("/api/tasks/", {**self.task_data, field: value}, format="json")
            self.assertEqual(response.status_code, 400, response.data)
        created = self.client.post("/api/tasks/", self.task_data, format="json")
        self.assertIsNone(created.data["reminder_minutes"])
        self.assertIsNone(created.data["reminder_time"])

    def test_inbox_date_only_and_recurrence_roundtrip(self):
        for schedule in [
            {"due_date": None},
            {"due_date": None, "scheduled_date": "2026-09-25"},
            {"recurrence": "weekly", "repeat_until": "2027-01-31", "completed_dates": ["2026-09-25"]},
        ]:
            response = self.client.post("/api/tasks/", {**self.task_data, **schedule}, format="json")
            self.assertEqual(response.status_code, 201, response.data)
            restored = self.client.get(f'/api/tasks/{response.data["id"]}/').data
            for key, value in schedule.items():
                self.assertEqual(restored[key], value)

    def test_inconsistent_schedules_are_rejected(self):
        for schedule in [
            {"scheduled_date": "2026-09-25"},
            {"due_date": None, "recurrence": "weekly"},
            {"recurrence": "fortnightly"},
            {"completed_dates": ["2026-09-25"]},
            {"recurrence": "weekly", "completed_dates": ["not a date"]},
            {"recurrence": "weekly", "is_completed": True},
            {"due_date": None, "scheduled_date": "2026-09-25", "recurrence": "weekly", "repeat_until": "2026-09-24"},
        ]:
            response = self.client.post("/api/tasks/", {**self.task_data, **schedule}, format="json")
            self.assertEqual(response.status_code, 400, response.data)

    @override_settings(AI_GUEST_REQUESTS_PER_DAY=1)
    @patch("core.views.ai.make_drafts", return_value={"tasks": [{"title": "Coffee"}], "transcript": "Buy coffee"})
    def test_guest_trial_cannot_bypass_budget_with_forwarded_headers(self, mock):
        payload = {"text": "Buy coffee", "timezone": "Europe/Madrid"}
        guest = APIClient()
        self.assertEqual(guest.post("/api/ai/drafts/", payload, format="json").status_code, 200)
        self.assertEqual(guest.post("/api/ai/drafts/", payload, format="json", HTTP_X_FORWARDED_FOR="1.2.3.4").status_code, 429)
        self.assertEqual(self.client.post("/api/ai/drafts/", payload, format="json").status_code, 200)
        self.assertEqual(mock.call_count, 2)
        self.assertEqual(Task.objects.count(), 0)

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

    @override_settings(AI_GUEST_REQUESTS_PER_DAY=1)
    @patch("core.views.ai.make_drafts")
    def test_provider_failure_does_not_spend_guest_trial(self, mock):
        mock.side_effect = [AIUnavailable("Provider busy"), {"tasks": [{"title": "Coffee"}]}]
        guest = APIClient()
        payload = {"text": "Buy coffee", "timezone": "Europe/Madrid"}
        self.assertEqual(guest.post("/api/ai/drafts/", payload, format="json").status_code, 503)
        self.assertEqual(guest.post("/api/ai/drafts/", payload, format="json").status_code, 200)
        self.assertEqual(guest.post("/api/ai/drafts/", payload, format="json").status_code, 429)
        self.assertEqual(mock.call_count, 2)


class DraftTests(TestCase):
    @patch("core.ai.clock.monotonic", side_effect=[10.0, 10.5, 12.0])
    @patch("core.ai.extract_tasks", return_value={"tasks": [], "transcript": "Synthetic words"})
    @patch("core.ai.transcribe", return_value="Synthetic words")
    def test_capture_stage_timings_are_numeric_without_input_in_metadata(self, transcription, extraction, clock):
        result = make_drafts({"audio": object(), "timezone": "UTC", "reference_time": datetime.now(timezone.utc)})
        self.assertEqual(result["timings"], {"transcription_ms": 500, "extraction_ms": 1500})
        transcription.assert_called_once()
        extraction.assert_called_once()

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
        self.assertEqual(result["scheduled_date"], "2026-09-25")
        self.assertEqual(result["questions"], [])

    @patch("core.ai.generate")
    def test_multiple_tasks_keep_independent_schedules_and_notes(self, provider):
        provider.return_value = json.dumps({"tasks": [self.output,
            {"title": "Coffee", "date": None, "time": None, "priority": 1},
            {"title": "Water plants", "date": "2026-09-27", "time": None, "priority": 1, "recurrence": "weekly"}]})
        result = extract_tasks("Doctor Friday at 5pm. Buy coffee. Water plants every Sunday.", "Europe/Madrid", self.reference)
        self.assertEqual(len(result["tasks"]), 3)
        self.assertEqual(result["tasks"][0]["due_date"], "2026-09-25T17:00:00+02:00")
        self.assertIsNone(result["tasks"][1]["due_date"])
        self.assertIsNone(result["tasks"][1]["scheduled_date"])
        self.assertEqual(result["tasks"][1]["questions"], [])
        self.assertEqual(result["tasks"][2]["recurrence"], "weekly")
        self.assertEqual(result["tasks"][2]["scheduled_date"], "2026-09-27")

    @patch("core.ai.generate")
    def test_ambiguous_time_keeps_date_and_question(self, provider):
        provider.return_value = json.dumps({**self.output, "time": None, "questions": ["5 a.m. or 5 p.m.?"]})
        draft = extract_task("Doctor Friday at 5", "Europe/Madrid", self.reference)
        self.assertEqual(draft["scheduled_date"], "2026-09-25")
        self.assertTrue(draft["questions"])

    @patch("core.ai.generate")
    def test_oversized_batch_is_rejected_instead_of_truncated(self, provider):
        from pydantic import ValidationError
        provider.return_value = json.dumps({"tasks": [self.output] * 13})
        with self.assertRaises(ValidationError):
            extract_tasks("Many tasks", "Europe/Madrid", self.reference)

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
