from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone as utc_zone
import io
from pathlib import Path
from tempfile import TemporaryDirectory
from threading import Barrier
from unittest.mock import patch
import uuid
import wave

from django.conf import settings
from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.db import close_old_connections, connections
from django.test import TestCase, TransactionTestCase, override_settings, skipUnlessDBFeature
from django.utils import timezone
from rest_framework.test import APIClient

from . import views
from .ai import AIUnavailable
from .billing import BillingUnavailable
from .free_tier import month
from .models import Attachment, FreeDictation, ListMembership, Task, TaskList, User

PASSWORD = "Free-tier-fixture-2026!"
NO_PRO = {"entitlements": {}}


def drafts(count=1):
    return {"transcript": "Words", "tasks": [{"title": f"Task {number}"} for number in range(count)]}


def pro_customer():
    expires = (timezone.now() + timedelta(hours=1)).isoformat()
    return {"entitlements": {"taskflow_pro": {"product_identifier": "monthly", "expires_date": expires,
                                              "grace_period_expires_date": None}},
            "subscriptions": {"monthly": {"is_sandbox": False, "expires_date": expires, "refunded_at": None}}}


def wav():
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as recording:
        recording.setnchannels(1)
        recording.setsampwidth(2)
        recording.setframerate(16000)
        recording.writeframes(b"\0" * 32000)
    return buffer.getvalue()


def without_burst_throttle(test):
    # The 6-per-minute burst throttle is covered elsewhere; these tests send more.
    throttle = patch.object(views.DraftView, "throttle_classes", [])
    throttle.start()
    test.addCleanup(throttle.stop)


@override_settings(FREE_VOICE_CAPTURES_PER_MONTH=10)
class FreeVoiceTests(TestCase):
    def setUp(self):
        cache.clear()
        without_burst_throttle(self)
        self.user = User.objects.create_user("free-voice@example.invalid", PASSWORD)
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def dictate(self, text="Call the dentist on Friday", capture_id=None, path="/api/ai/drafts/", **fields):
        if capture_id is not None:
            fields["capture_id"] = str(capture_id)
        return self.client.post(path, {"text": text, "timezone": "Europe/Madrid", **fields}, format="json")

    def counted(self):
        return FreeDictation.objects.filter(user=self.user, counted=True).count()

    def use_up(self, count):
        now = timezone.now()
        FreeDictation.objects.bulk_create(FreeDictation(user=self.user, period=month(now)[0], digest="used",
                                                        counted=True, created_at=now) for _ in range(count))

    @patch("core.views.consume_budget")
    @patch("core.views.ai.make_drafts", return_value=drafts())
    def test_ten_dictations_then_used_up_without_touching_ai_or_budgets(self, ai, budget):
        for number in range(10):
            response = self.dictate(f"Dictation number {number}")
            self.assertEqual(response.status_code, 200, response.data)
            self.assertEqual(response.data["free_voice"]["left"], 9 - number)
        ai.reset_mock()
        budget.reset_mock()
        response = self.dictate("One dictation too many")
        self.assertEqual(response.status_code, 402)
        body = response.json()
        self.assertEqual(body["code"], "free_voice_used_up")
        resets_at = month(timezone.now())[1].isoformat().replace("+00:00", "Z")
        self.assertEqual(body["free_voice"], {"limit": 10, "left": 0, "resets_at": resets_at})
        ai.assert_not_called()
        budget.assert_not_called()
        self.assertEqual(FreeDictation.objects.count(), 10)

    @patch("core.views.ai.make_draft", return_value={"title": "One task"})
    @patch("core.views.ai.make_drafts", return_value=drafts(5))
    def test_one_dictation_counts_once_whatever_the_number_of_tasks(self, batch, single):
        response = self.dictate("Five things to do this week")
        self.assertEqual(len(response.data["tasks"]), 5)
        self.assertEqual(response.data["free_voice"]["left"], 9)
        response = self.dictate("Only one thing", path="/api/ai/draft/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["title"], "One task")
        self.assertEqual(response.data["free_voice"]["left"], 8)
        self.assertEqual(self.counted(), 2)

    @patch("core.views.ai.make_drafts")
    def test_failures_and_budget_limits_do_not_count(self, ai):
        ai.side_effect = [AIUnavailable("Bad recording", 400), AIUnavailable("No speech", 422),
                          AIUnavailable("Invalid answer", 502), AIUnavailable("Provider down", 503), drafts()]
        for status in (400, 422, 502, 503):
            self.assertEqual(self.dictate().status_code, status)
        with override_settings(AI_REQUESTS_PER_DAY=0):
            self.assertEqual(self.dictate().status_code, 429)
        with override_settings(AI_GLOBAL_REQUESTS_PER_DAY=0):
            self.assertEqual(self.dictate().status_code, 429)
        self.assertFalse(FreeDictation.objects.exists())
        response = self.dictate()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["free_voice"]["left"], 9)
        self.assertEqual(FreeDictation.objects.count(), 1)
        self.assertEqual(self.counted(), 1)

    @override_settings(FREE_VOICE_CAPTURES_PER_MONTH=2)
    @patch("core.views.ai.make_drafts", return_value=drafts())
    def test_a_retry_is_free_but_new_words_are_a_new_dictation(self, ai):
        capture = uuid.uuid4()
        self.assertEqual(self.dictate("Buy bread", capture).data["free_voice"]["left"], 1)
        # The response was lost, so the app sends the same capture again.
        self.assertEqual(self.dictate("Buy bread", capture).data["free_voice"]["left"], 1)
        # Saying it again with new words is a new dictation, even with the same ID.
        self.assertEqual(self.dictate("Buy bread and milk", capture).data["free_voice"]["left"], 0)
        retry = self.dictate("Buy bread", capture)
        self.assertEqual(retry.status_code, 200)
        self.assertEqual(retry.data["free_voice"]["left"], 0)
        self.assertEqual(self.dictate("Something else", capture).status_code, 402)
        # Without the app's capture ID, the same words can't be told apart from a new dictation.
        self.assertEqual(self.dictate("Buy bread").status_code, 402)
        self.assertEqual(ai.call_count, 4)
        self.assertEqual(self.counted(), 2)

    @patch("core.views.ai.make_drafts")
    def test_a_duplicate_in_flight_is_refused_without_calling_the_ai(self, ai):
        capture = uuid.uuid4()
        duplicates = []

        def understand(data):
            duplicates.append(self.dictate("Plan the trip", capture))
            return drafts()
        ai.side_effect = understand
        self.assertEqual(self.dictate("Plan the trip", capture).status_code, 200)
        self.assertEqual(duplicates[0].status_code, 409)
        self.assertEqual(duplicates[0].data["code"], "capture_in_progress")
        ai.assert_called_once()
        self.assertEqual(self.counted(), 1)

    @override_settings(FREE_VOICE_CAPTURES_PER_MONTH=1)
    @patch("core.views.ai.make_drafts", return_value=drafts())
    def test_a_pending_dictation_holds_a_slot_until_it_is_five_minutes_old(self, ai):
        now = timezone.now()
        crashed = FreeDictation.objects.create(user=self.user, period=month(now)[0], capture_id=uuid.uuid4(),
                                               digest="crashed", created_at=now - timedelta(minutes=4))
        self.assertEqual(self.client.get("/api/auth/me/").data["free_voice"]["left"], 0)
        self.assertEqual(self.dictate().status_code, 402)
        FreeDictation.objects.filter(pk=crashed.pk).update(created_at=now - timedelta(minutes=6))
        self.assertEqual(self.client.get("/api/auth/me/").data["free_voice"]["left"], 1)
        self.assertEqual(self.dictate().status_code, 200)
        self.assertFalse(FreeDictation.objects.filter(pk=crashed.pk).exists())
        self.assertEqual(self.counted(), 1)

    @patch("core.views.ai.make_drafts")
    def test_cancelling_while_understanding_discards_the_result_and_never_counts(self, ai):
        capture = uuid.uuid4()

        def understand(data):
            self.assertEqual(self.client.delete(f"/api/ai/drafts/{capture}/").status_code, 204)
            return drafts()
        ai.side_effect = understand
        response = self.dictate(capture_id=capture)
        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.data["code"], "capture_cancelled")
        self.assertNotIn("tasks", response.data)
        self.assertFalse(FreeDictation.objects.exists())
        self.assertEqual(self.client.delete(f"/api/ai/drafts/{capture}/").status_code, 204)
        self.assertEqual(self.client.get("/api/auth/me/").data["free_voice"]["left"], 10)

    @patch("core.views.ai.make_drafts", return_value=drafts())
    def test_cancelling_after_success_refunds_nothing(self, ai):
        capture = uuid.uuid4()
        self.assertEqual(self.dictate(capture_id=capture).status_code, 200)
        self.assertEqual(self.client.delete(f"/api/ai/drafts/{capture}/").status_code, 204)
        self.assertEqual(self.counted(), 1)

    @patch("core.views.ai.make_drafts")
    def test_an_account_cannot_cancel_another_accounts_dictation(self, ai):
        intruder = APIClient()
        intruder.force_authenticate(User.objects.create_user("intruder@example.invalid", PASSWORD))
        capture = uuid.uuid4()

        def understand(data):
            self.assertEqual(intruder.delete(f"/api/ai/drafts/{capture}/").status_code, 204)
            return drafts()
        ai.side_effect = understand
        self.assertEqual(self.dictate(capture_id=capture).status_code, 200)
        self.assertEqual(self.counted(), 1)
        self.assertEqual(APIClient().delete(f"/api/ai/drafts/{capture}/").status_code, 401)

    @override_settings(FREE_VOICE_CAPTURES_PER_MONTH=1)
    @patch("core.views.ai.make_drafts", return_value=drafts())
    def test_the_count_resets_with_the_utc_calendar_month(self, ai):
        with patch("core.free_tier.timezone.now", return_value=datetime(2026, 10, 31, 23, 59, 59, tzinfo=utc_zone.utc)):
            self.assertEqual(self.dictate("October words").status_code, 200)
            refused = self.dictate("More October words")
            self.assertEqual(refused.status_code, 402)
            self.assertEqual(refused.data["free_voice"]["resets_at"], "2026-11-01T00:00:00Z")
        with patch("core.free_tier.timezone.now", return_value=datetime(2026, 11, 1, tzinfo=utc_zone.utc)):
            self.assertEqual(self.client.get("/api/auth/me/").json()["free_voice"],
                             {"limit": 1, "left": 1, "resets_at": "2026-12-01T00:00:00Z"})
            self.assertEqual(self.dictate("November words").status_code, 200)
        with patch("core.free_tier.timezone.now", return_value=datetime(2026, 12, 15, 9, 30, tzinfo=utc_zone.utc)):
            self.assertEqual(self.client.get("/api/auth/me/").data["free_voice"]["resets_at"], "2027-01-01T00:00:00Z")
        self.assertEqual(sorted(FreeDictation.objects.values_list("period", flat=True)), ["2026-10", "2026-11"])

    @override_settings(REVENUECAT_API_KEY="goog_fixture")
    @patch("core.billing._customer")
    @patch("core.views.ai.make_drafts", return_value=drafts())
    def test_pro_dictations_are_unlimited_and_not_recorded(self, ai, customer):
        customer.return_value = pro_customer()
        self.use_up(10)
        for number in range(3):
            response = self.dictate(f"Pro dictation {number}")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.data["free_voice"]["left"], 0)
        self.assertEqual(FreeDictation.objects.count(), 10)
        customer.assert_called_once_with(self.user.billing_id)

    @override_settings(COMPLIMENTARY_PRO_EMAILS={"free-voice@example.invalid"})
    @patch("core.billing._customer")
    @patch("core.views.ai.make_drafts", return_value=drafts())
    def test_complimentary_accounts_are_unlimited_without_revenuecat(self, ai, customer):
        self.use_up(10)
        with override_settings(COMPLIMENTARY_PRO_BILLING_IDS={str(self.user.billing_id)}):
            for key in ("", "goog_fixture"):  # With and without billing configured.
                with override_settings(REVENUECAT_API_KEY=key):
                    self.assertEqual(self.dictate(f"Owner dictation {key}").status_code, 200)
        self.assertEqual(FreeDictation.objects.count(), 10)
        customer.assert_not_called()

    @override_settings(FREE_VOICE_CAPTURES_PER_MONTH=1)
    @patch("core.views.ai.make_drafts", return_value=drafts())
    def test_forged_fields_and_a_typed_source_change_nothing(self, ai):
        forged = {"has_pro": True, "complimentary_pro": True, "free_voice": {"limit": 99, "left": 99},
                  "billing_id": str(uuid.uuid4()), "source": "typed"}
        response = self.dictate("Typed words for the assistant", **forged)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["free_voice"]["left"], 0)
        self.assertEqual(self.counted(), 1)
        self.assertEqual(self.dictate("More typed words", **forged).status_code, 402)

    @patch("core.ai.extract_tasks")
    @patch("core.ai.transcribe")
    def test_a_recorded_note_counts_once_and_its_audio_reaches_the_ai_whole(self, transcribe, extract):
        recording = wav()

        def heard(audio):
            self.assertEqual(audio.read(), recording)  # Hashing rewound the upload.
            return "Gate code 4512"
        transcribe.side_effect = heard
        capture = uuid.uuid4()

        def send():
            return self.client.post("/api/ai/drafts/", {
                "audio": SimpleUploadedFile("note.wav", recording, content_type="audio/wav"),
                "timezone": "UTC", "capture_type": "note", "capture_id": str(capture)}, format="multipart")
        response = send()
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data["tasks"][0]["notes"], "Gate code 4512")
        self.assertEqual(response.data["free_voice"]["left"], 9)
        self.assertEqual(send().data["free_voice"]["left"], 9)  # The same recording again is a retry.
        self.assertEqual(transcribe.call_count, 2)
        self.assertEqual(self.counted(), 1)
        extract.assert_not_called()

    def test_register_login_and_me_include_both_blocks(self):
        voice = {"limit": 10, "left": 10, "resets_at": month(timezone.now())[1].isoformat().replace("+00:00", "Z")}
        storage = {"used_bytes": 0, "limit_bytes": settings.FREE_ATTACHMENT_BYTES}
        credentials = {"email": "blocks@example.invalid", "password": "Unique-blocks-passphrase-2026!"}
        client = APIClient()
        registered = client.post("/api/auth/register/", credentials, format="json")
        self.assertEqual(registered.status_code, 201)
        logged_in = client.post("/api/auth/login/", credentials, format="json")
        self.assertEqual(logged_in.status_code, 200)
        client.credentials(HTTP_AUTHORIZATION="Bearer " + logged_in.data["access"])
        me = client.get("/api/auth/me/")
        for data in (registered.json()["user"], logged_in.json()["user"], me.json()):
            self.assertEqual(data["free_voice"], voice)
            self.assertEqual(data["storage"], storage)


@skipUnlessDBFeature("has_select_for_update")
class FreeVoiceConcurrencyTests(TransactionTestCase):
    def setUp(self):
        cache.clear()
        without_burst_throttle(self)
        self.user = User.objects.create_user("concurrent-voice@example.invalid", PASSWORD)

    @override_settings(FREE_VOICE_CAPTURES_PER_MONTH=1)
    @patch("core.views.ai.make_drafts", return_value=drafts())
    def test_two_simultaneous_dictations_with_one_left(self, ai):
        barrier = Barrier(2)

        def dictate(words):
            close_old_connections()
            try:
                client = APIClient()
                client.force_authenticate(self.user)
                barrier.wait(timeout=10)
                return client.post("/api/ai/drafts/", {"text": words, "timezone": "UTC",
                                                       "capture_id": str(uuid.uuid4())}, format="json").status_code
            finally:
                connections.close_all()
        with ThreadPoolExecutor(max_workers=2) as pool:
            self.assertEqual(sorted(pool.map(dictate, ["First words", "Second words"])), [200, 402])
        self.assertEqual(FreeDictation.objects.count(), 1)
        self.assertEqual(FreeDictation.objects.filter(counted=True).count(), 1)
        ai.assert_called_once()


class FreeStorageTests(TestCase):
    def setUp(self):
        cache.clear()
        self.files = TemporaryDirectory(prefix="taskflow-free-storage-")
        self.addCleanup(self.files.cleanup)
        limits = override_settings(MEDIA_ROOT=self.files.name, FREE_ATTACHMENT_BYTES=10)
        limits.enable()
        self.addCleanup(limits.disable)
        self.owner = User.objects.create_user("storage-owner@example.invalid", PASSWORD)
        self.member = User.objects.create_user("storage-member@example.invalid", PASSWORD)
        self.a, self.b = APIClient(), APIClient()
        self.a.force_authenticate(self.owner)
        self.b.force_authenticate(self.member)
        self.task = Task.objects.create(owner=self.owner, title="Paperwork")

    def upload(self, content, client=None, task=None, id=None):
        return (client or self.a).put(f"/api/attachments/{id or uuid.uuid4()}/", {
            "task_id": str((task or self.task).pk), "name": "scan.pdf",
            "file": SimpleUploadedFile("upload", content, content_type="application/octet-stream"),
        }, format="multipart")

    def shared_task(self):
        project = TaskList.objects.create(owner=self.owner, name="Household", shared=True)
        ListMembership.objects.create(task_list=project, user=self.member, role="editor")
        return Task.objects.create(owner=self.member, task_list=project, title="Recipes")

    def pro_only(self, user):
        return lambda billing_id: pro_customer() if billing_id == user.billing_id else NO_PRO

    def test_a_free_owner_over_the_cap_gets_storage_full_with_numbers(self):
        self.assertEqual(self.upload(b"x" * 8).status_code, 201)
        refused = self.upload(b"x" * 3)
        self.assertEqual(refused.status_code, 400)
        body = refused.json()
        self.assertEqual(body["code"], "storage_full")
        self.assertIs(body["shared"], False)
        self.assertEqual(body["storage"], {"used_bytes": 8, "limit_bytes": 10})
        self.assertIsInstance(body["detail"], str)
        self.assertEqual(Attachment.objects.count(), 1)
        self.assertEqual(len(list(Path(self.files.name).rglob("*.blob"))), 1)
        self.assertEqual(self.a.get("/api/auth/me/").json()["storage"], {"used_bytes": 8, "limit_bytes": 10})
        self.assertEqual(self.upload(b"x" * 2).status_code, 201)  # Exactly at the cap is allowed.

    @override_settings(REVENUECAT_API_KEY="goog_fixture")
    @patch("core.billing._customer")
    def test_a_pro_owner_has_no_cap_and_billing_is_asked_only_above_it(self, customer):
        customer.return_value = pro_customer()
        self.assertEqual(self.upload(b"x" * 8).status_code, 201)
        customer.assert_not_called()
        self.assertEqual(self.upload(b"x" * 8).status_code, 201)
        customer.assert_called_once_with(self.owner.billing_id)
        self.assertEqual(Attachment.objects.count(), 2)

    @override_settings(REVENUECAT_API_KEY="goog_fixture")
    @patch("core.billing._customer")
    def test_a_shared_project_uses_its_owners_space(self, customer):
        task = self.shared_task()
        customer.side_effect = self.pro_only(self.member)  # A Pro member can't lift a free owner's cap.
        self.assertEqual(self.upload(b"x" * 8, self.b, task).status_code, 201)
        refused = self.upload(b"x" * 3, self.b, task)
        self.assertEqual(refused.status_code, 400)
        self.assertEqual(refused.json()["code"], "storage_full")
        self.assertIs(refused.json()["shared"], True)
        self.assertNotIn("storage", refused.json())
        cache.clear()
        customer.side_effect = self.pro_only(self.owner)  # A Pro owner accepts a free member's file.
        self.assertEqual(self.upload(b"x" * 3, self.b, task).status_code, 201)

    def test_removing_a_file_or_a_task_frees_space_immediately(self):
        first = uuid.uuid4()
        self.assertEqual(self.upload(b"x" * 8, id=first).status_code, 201)
        self.assertEqual(self.upload(b"x" * 8).status_code, 400)
        self.assertEqual(self.a.delete(f"/api/attachments/{first}/").status_code, 204)
        self.assertEqual(self.upload(b"x" * 8).status_code, 201)
        other = Task.objects.create(owner=self.owner, title="Other paperwork")
        self.assertEqual(self.upload(b"x" * 8, task=other).status_code, 400)
        self.assertEqual(self.a.delete(f"/api/tasks/{self.task.pk}/", {"version": self.task.version}, format="json").status_code, 204)
        self.assertEqual(self.upload(b"x" * 8, task=other).status_code, 201)
        self.assertEqual(self.a.get("/api/auth/me/").json()["storage"]["used_bytes"], 8)

    @override_settings(REVENUECAT_API_KEY="goog_fixture")
    @patch("core.billing._customer")
    def test_after_pro_ends_files_stay_readable_and_removable_but_uploads_over_the_cap_are_refused(self, customer):
        customer.return_value = pro_customer()
        first, second = uuid.uuid4(), uuid.uuid4()
        self.assertEqual(self.upload(b"a" * 8, id=first).status_code, 201)
        self.assertEqual(self.upload(b"b" * 8, id=second).status_code, 201)
        customer.return_value = NO_PRO
        cache.clear()  # The cached grant has lapsed.
        download = self.a.get(f"/api/attachments/{first}/content/")
        self.assertEqual(download.status_code, 200)
        self.assertEqual(b"".join(download.streaming_content), b"a" * 8)
        refused = self.upload(b"c")
        self.assertEqual(refused.status_code, 400)
        self.assertEqual(refused.json()["storage"], {"used_bytes": 16, "limit_bytes": 10})
        self.assertEqual(self.a.delete(f"/api/attachments/{second}/").status_code, 204)
        self.assertEqual(self.upload(b"c").status_code, 201)

    @override_settings(REVENUECAT_API_KEY="goog_fixture")
    @patch("core.billing._customer")
    def test_a_task_can_move_into_a_pro_owners_space(self, customer):
        customer.return_value = NO_PRO
        shared = self.shared_task()
        self.assertEqual(self.upload(b"x" * 8, self.b, shared).status_code, 201)
        personal = self.b.put(f"/api/tasks/{uuid.uuid4()}/", {"title": "Private", "version": 0}, format="json")
        self.assertEqual(personal.status_code, 201)
        self.assertEqual(self.upload(b"y" * 8, self.b, Task.objects.get(pk=personal.data["id"])).status_code, 201)
        move = {**personal.data, "list_id": str(shared.task_list_id)}
        refused = self.b.put(f"/api/tasks/{personal.data['id']}/", move, format="json")
        self.assertEqual(refused.status_code, 400)
        self.assertIn("list_id", refused.data)  # The free owner's space is full.
        cache.clear()
        customer.side_effect = self.pro_only(self.owner)
        moved = self.b.put(f"/api/tasks/{personal.data['id']}/", move, format="json")
        self.assertEqual(moved.status_code, 200, moved.data)

    @override_settings(REVENUECAT_API_KEY="goog_fixture")
    @patch("core.billing._customer", side_effect=BillingUnavailable())
    def test_unknown_billing_above_the_cap_asks_to_try_again(self, customer):
        self.assertEqual(self.upload(b"x" * 8).status_code, 201)
        customer.assert_not_called()
        response = self.upload(b"x" * 3)
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json()["code"], "billing_unavailable")
        self.assertNotIn("goog_fixture", str(response.json()))
        self.assertEqual(Attachment.objects.count(), 1)
        self.assertEqual(len(list(Path(self.files.name).rglob("*.blob"))), 1)
