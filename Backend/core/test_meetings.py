"""Meeting notes (docs/MEETINGS.md): the four endpoints, the flow in core/meetings.py, the sweep and
account deletion. Vertex is always a fake here: no test makes an AI call."""
import io
import json
import uuid
from datetime import timedelta
from types import SimpleNamespace
from unittest.mock import patch

from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.management import call_command
from django.test import SimpleTestCase, TestCase, override_settings
from django.utils import timezone
from google.genai import errors, types
from rest_framework.test import APIClient

from . import meetings
from .account_deletion import delete_account
from .ai import client as REAL_CLIENT
from .meeting_views import MeetingFinishView, MeetingPieceView, MeetingView
from .meetings import MeetingNotes, last_sentence
from .models import Meeting, MeetingChapter, MeetingPiece, User

PASSWORD = "Meeting-notes-fixture-2026!"
FINAL = {"title": "Pilot pricing with Acme", "summary": "They agreed the pilot. Miki sends the quote.",
         "todos": [{"text": "Send the pilot quote", "who": "Miki", "when": "Friday"},
                   {"text": "Book the room", "who": "", "when": None}],
         "decisions": ["Start the pilot in December", " "], "open_questions": ["Who signs for Acme?"],
         "language": "en-GB"}
RESULT_KEYS = {"title", "summary", "todos", "decisions", "open_questions", "chapters", "start_missing", "language"}


def response(text, finish_reason="STOP"):
    part = SimpleNamespace(text=text, audio_transcription=None)
    candidate = SimpleNamespace(content=SimpleNamespace(parts=[part]), finish_reason=finish_reason)
    return SimpleNamespace(text=text, candidates=[candidate], prompt_feedback=None)


class FakeVertex:
    """Stands in for ai.client: records every call, and answers by what the call asks for."""

    def __init__(self):
        self.calls = []
        self.failures = {}  # stage -> exceptions to raise, one per call
        self.during = {}  # stage -> a function run inside the call, as another request would
        self.answers = {}  # stage -> responses to give instead, one per call
        self.final = FINAL

    def __call__(self, timeout_ms=45000):
        return self

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    @property
    def models(self):
        return self

    def stage(self, contents, config):
        if isinstance(contents, list):
            return "audio"
        return "final" if "summary" in config.response_schema["properties"] else "chapter"

    def count(self, stage):
        return sum(1 for call in self.calls if call["stage"] == stage)

    def generate_content(self, model, contents, config):
        stage = self.stage(contents, config)
        self.calls.append({"stage": stage, "model": model, "contents": contents, "config": config})
        if self.failures.get(stage):
            raise self.failures[stage].pop(0)
        if stage in self.during:
            self.during.pop(stage)()
        if self.answers.get(stage):
            return self.answers[stage].pop(0)
        if stage == "audio":
            audio = contents[1].inline_data
            self.calls[-1]["mime_type"] = audio.mime_type
            words = audio.data.decode()
            return response("" if words.startswith("silence") else f"Words of {words}. Last line of {words}.")
        if stage == "chapter":
            return response(json.dumps({"title": "Pricing for the pilot", "notes": "0:05 Price agreed."}))
        return response(self.final if isinstance(self.final, str) else json.dumps(self.final))


class MeetingTestCase(TestCase):
    def setUp(self):
        cache.clear()
        self.user = User.objects.create_user("meeting-pro@example.invalid", PASSWORD)
        self.api = self.client_for(self.user)
        self.meeting_id = uuid.uuid4()
        self.pro = patch("core.meeting_views.has_pro", return_value=True)
        self.has_pro = self.pro.start()
        self.addCleanup(self.pro.stop)
        self.vertex = FakeVertex()
        fake = patch("core.ai.client", self.vertex)
        fake.start()
        self.addCleanup(fake.stop)
        configured = override_settings(AI_VERTEX_PROJECT="taskflow-test")
        configured.enable()
        self.addCleanup(configured.disable)

    def client_for(self, user):
        client = APIClient()
        client.force_authenticate(user)
        return client

    def url(self, suffix="", meeting_id=None):
        return f"/api/meetings/{meeting_id or self.meeting_id}/{suffix}"

    def put(self, index, audio=None, client=None, meeting_id=None, content_type="audio/ogg", **fields):
        audio = audio if audio is not None else f"piece {index}".encode()
        form = {"audio": SimpleUploadedFile(f"{index}.ogg", audio, content_type=content_type),
                "offset_seconds": index * 300, "duration_seconds": 300, **fields}
        return (client or self.api).put(self.url(f"pieces/{index}/", meeting_id), form, format="multipart")

    def finish(self, last_index, client=None, meeting_id=None):
        return (client or self.api).post(self.url("finish/", meeting_id), {"last_index": last_index}, format="json")

    def get(self, client=None, meeting_id=None):
        return (client or self.api).get(self.url(meeting_id=meeting_id))

    def delete(self, client=None, meeting_id=None):
        return (client or self.api).delete(self.url(meeting_id=meeting_id))

    def counted(self, user=None):
        return cache.get(meetings._allowance_key(user or self.user), 0)


class PieceTests(MeetingTestCase):
    def test_the_first_piece_creates_the_meeting_and_is_transcribed_on_vertex(self):
        response = self.put(0, language="es-ES")
        self.assertEqual((response.status_code, response.data),
                         (200, {"meeting_id": str(self.meeting_id), "index": 0, "saved": True, "status": "recording"}))
        meeting = Meeting.objects.get(pk=self.meeting_id)
        self.assertEqual((meeting.user, meeting.first_index, meeting.start_missing, meeting.language),
                         (self.user, 0, False, "es-ES"))
        piece = meeting.pieces.get()
        self.assertEqual((piece.index, piece.offset_seconds, piece.duration_seconds, piece.text),
                         (0, 0, 300, "Words of piece 0. Last line of piece 0."))
        # The meeting model, and the audio as sent.
        call = self.vertex.calls[0]
        self.assertEqual((call["model"], call["mime_type"]), ("gemini-3.5-flash-lite", "audio/ogg"))
        self.assertIn("es-ES", call["contents"][0].text)
        self.assertEqual(self.counted(), 1)
        self.assertEqual(self.get().data, {"status": "recording", "received": [0]})

    def test_a_repeated_piece_is_not_transcribed_or_counted_again(self):
        self.put(0)
        again = self.put(0, audio=b"different bytes")
        self.assertEqual((again.status_code, again.data["saved"], again.data["status"]), (200, True, "recording"))
        self.assertEqual(self.vertex.count("audio"), 1)
        self.assertEqual(self.counted(), 1)
        self.assertEqual(MeetingPiece.objects.get().text, "Words of piece 0. Last line of piece 0.")

    def test_a_piece_saved_by_a_request_at_the_same_time_counts_once(self):
        def other_request():
            # Another request for the same piece commits while this one is transcribing.
            meeting = Meeting.objects.create(pk=self.meeting_id, user=self.user, last_piece_at=timezone.now())
            MeetingPiece.objects.create(meeting=meeting, index=0, offset_seconds=0, duration_seconds=300, text="First.")
        self.vertex.during["audio"] = other_request
        response = self.put(0)
        self.assertEqual((response.status_code, response.data["saved"]), (200, True))
        self.assertEqual(list(MeetingPiece.objects.values_list("text", flat=True)), ["First."])
        self.assertEqual(self.counted(), 0)  # the other request counts its own; this one gave its reservation back

    def test_the_last_sentence_of_the_piece_before_is_context(self):
        self.put(0)
        self.put(1)
        prompt = self.vertex.calls[1]["contents"][0].text
        self.assertIn(json.dumps("Last line of piece 0."), prompt)
        self.assertNotIn("Words of piece 0", prompt)
        self.assertNotIn("Previous words", self.vertex.calls[0]["contents"][0].text)
        self.assertEqual(last_sentence("Hola. ¿Qué tal? Bien"), "Bien")
        self.assertEqual(last_sentence(""), "")

    def test_pieces_out_of_order_still_make_one_meeting(self):
        self.put(1)
        self.assertTrue(Meeting.objects.get().start_missing)
        self.put(0)
        meeting = Meeting.objects.get()
        self.assertEqual((meeting.first_index, meeting.start_missing), (0, False))
        response = self.finish(1)
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.data["result"]["start_missing"])

    def test_a_silent_piece_saves_empty_text(self):
        self.assertEqual(self.put(0, audio=b"silence").status_code, 200)
        self.assertEqual(MeetingPiece.objects.get().text, "")

    def test_every_accepted_audio_type(self):
        for index, kind in enumerate(sorted(meetings.AUDIO_TYPES)):
            with self.subTest(kind=kind):
                self.assertEqual(self.put(index, content_type=kind).status_code, 200)
                audio = [call for call in self.vertex.calls if call["stage"] == "audio"]
                self.assertEqual(audio[-1]["mime_type"], kind)

    def test_what_a_piece_refuses(self):
        cases = [
            ("not audio", {"content_type": "image/png"}),
            ("over 10 minutes", {"duration_seconds": 601}),
            ("a negative offset", {"offset_seconds": -1}),
            ("an empty file", {"audio": b""}),
        ]
        for name, fields in cases:
            with self.subTest(name):
                self.assertEqual(self.put(0, **fields).status_code, 400)
        form = {"offset_seconds": 0, "duration_seconds": 300}
        self.assertEqual(self.api.put(self.url("pieces/0/"), form, format="multipart").status_code, 400)
        self.assertEqual(self.put(meetings.MAX_INDEX + 1).status_code, 400)
        self.assertEqual(self.vertex.calls, [])
        self.assertFalse(Meeting.objects.exists())
        self.assertEqual(self.counted(), 0)

    def test_a_language_hint_that_isnt_a_tag_is_left_out(self):
        self.assertEqual(self.put(0, language="system default!").status_code, 200)
        self.assertNotIn("system default", self.vertex.calls[0]["contents"][0].text)
        self.assertEqual(Meeting.objects.get().language, "")

    def test_a_piece_stays_in_memory_up_to_8_mb_and_a_larger_one_is_refused(self):
        big = b"piece 0" + b"\0" * (7 * 1024 * 1024)  # above the 6 MB attachment and memory limits
        with patch("django.core.files.uploadedfile.tempfile.NamedTemporaryFile",
                   side_effect=AssertionError("written to disk")):
            self.assertEqual(self.put(0, audio=big).status_code, 200)
            self.assertEqual(len(self.vertex.calls[0]["contents"][1].inline_data.data), len(big))
            too_big = self.put(1, audio=b"piece 1" + b"\0" * (8 * 1024 * 1024))
        self.assertEqual(too_big.status_code, 400)
        self.assertEqual(self.vertex.count("audio"), 1)

    def test_a_failed_transcription_saves_and_counts_nothing(self):
        self.vertex.failures["audio"] = [errors.ServerError(503, {"error": {"message": "busy"}})]
        response = self.put(0)
        self.assertEqual(response.status_code, 503)
        self.assertIn("detail", response.data)
        self.assertFalse(Meeting.objects.exists())
        self.assertEqual(self.counted(), 0)
        self.assertEqual(self.put(0).status_code, 200)  # the phone's retry
        self.assertEqual(self.counted(), 1)

    def test_a_piece_the_model_refused_blocked_or_cut_short_is_not_saved(self):
        # The phone deletes a piece once it is confirmed (MN-8): only a normal answer may confirm it.
        blocked = SimpleNamespace(text=None, candidates=[],
                                  prompt_feedback=SimpleNamespace(block_reason=types.BlockedReason.PROHIBITED_CONTENT))
        cases = [
            ("no candidates", SimpleNamespace(text=None, candidates=None, prompt_feedback=None)),
            ("a blocked prompt", blocked),
            ("safety", response("", finish_reason=types.FinishReason.SAFETY)),
            ("max tokens", response("Words of piece 0, cut", finish_reason=types.FinishReason.MAX_TOKENS)),
            ("recitation", response("Words", finish_reason="RECITATION")),
            ("no reason and no text", response("", finish_reason=None)),
        ]
        for name, answer in cases:
            with self.subTest(name):
                self.vertex.answers["audio"] = [answer]
                refused = self.put(0)
                self.assertEqual(refused.status_code, 502)
                self.assertIn("detail", refused.data)
                self.assertFalse(Meeting.objects.exists())
                self.assertEqual(self.counted(), 0)
        self.assertEqual(self.put(0).status_code, 200)  # the phone kept the piece and retries
        self.assertEqual((MeetingPiece.objects.get().text, self.counted()),
                         ("Words of piece 0. Last line of piece 0.", 1))

    def test_an_answer_with_text_and_no_finish_reason_is_saved(self):
        self.vertex.answers["audio"] = [response("Words said.", finish_reason=None)]
        self.assertEqual(self.put(0).status_code, 200)
        self.assertEqual(MeetingPiece.objects.get().text, "Words said.")

    @override_settings(AI_VERTEX_PROJECT="")
    def test_vertex_not_configured_is_503(self):
        with patch("core.ai.client", REAL_CLIENT):
            response = self.put(0)
            finished = self.finish(0)
        self.assertEqual((response.status_code, response.data),
                         (503, {"detail": "Vertex AI is not configured on the server yet."}))
        self.assertEqual(finished.status_code, 202)  # nothing arrived, so nothing to write yet
        self.assertFalse(Meeting.objects.exists())
        self.assertEqual(self.counted(), 0)


class FinishTests(MeetingTestCase):
    def test_finish_before_every_piece_waits_and_the_completing_piece_writes_the_notes(self):
        self.put(0)
        self.put(2)
        waiting = self.finish(3)
        self.assertEqual((waiting.status_code, waiting.data), (202, {"status": "waiting", "missing": [1, 3]}))
        self.assertEqual(self.put(3).data["status"], "waiting")
        self.assertEqual(self.vertex.count("final"), 0)
        completing = self.put(1)
        self.assertEqual((completing.status_code, completing.data["status"]), (200, "ready"))
        self.assertEqual((self.vertex.count("chapter"), self.vertex.count("final")), (1, 1))
        ready = self.get()
        self.assertEqual(ready.data["status"], "ready")
        result = ready.data["result"]
        self.assertEqual(set(result), RESULT_KEYS)
        self.assertEqual(result["title"], "Pilot pricing with Acme")
        self.assertEqual(result["todos"], [{"text": "Send the pilot quote", "who": "Miki", "when": "Friday"},
                                           {"text": "Book the room", "who": None, "when": None}])
        self.assertEqual(result["decisions"], ["Start the pilot in December"])
        self.assertEqual(result["open_questions"], ["Who signs for Acme?"])
        self.assertEqual(result["chapters"], [{"start_minute": 0, "end_minute": 20,
                                               "title": "Pricing for the pilot", "notes": "0:05 Price agreed."}])
        self.assertEqual((result["start_missing"], result["language"]), (False, "en"))
        # The final step read the chapter notes and the whole transcript, in order, with times.
        prompt = self.vertex.calls[-1]["contents"]
        self.assertIn("Pricing for the pilot", prompt)
        self.assertLess(prompt.index("[0:00:00] Words of piece 0"), prompt.index("[0:15:00] Words of piece 3"))
        self.assertEqual(self.finish(3).status_code, 200)
        self.assertEqual(self.vertex.count("final"), 1)

    def test_finish_with_every_piece_in_answers_the_notes_and_repeating_it_is_safe(self):
        for index in range(3):
            self.put(index)
        first = self.finish(2)
        self.assertEqual((first.status_code, first.data["status"]), (200, "ready"))
        again = self.finish(2)
        other = self.finish(7)  # a different last_index after the first one is ignored
        self.assertEqual((again.status_code, again.data), (200, first.data))
        self.assertEqual((other.status_code, other.data), (200, first.data))
        self.assertEqual(self.vertex.count("final"), 1)
        self.assertEqual(Meeting.objects.get().last_index, 2)

    def test_finish_below_a_saved_piece_still_ends_at_the_highest_piece(self):
        # An app mistake must not finish the meeting without pieces the server already holds.
        for index in range(8):
            self.put(index)
        response = self.finish(3)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(Meeting.objects.get().last_index, 7)
        transcript = self.vertex.calls[-1]["contents"]
        self.assertIn("Words of piece 7", transcript)
        self.assertEqual(response.data["result"]["chapters"][-1]["end_minute"], 40)

    def test_finish_below_the_first_piece_received_waits_for_nothing_it_holds(self):
        self.put(10)
        self.put(11)
        response = self.finish(5)
        self.assertEqual((response.status_code, response.data["status"]), (200, "ready"))
        self.assertEqual(Meeting.objects.get().last_index, 11)
        self.assertIn("Words of piece 11", self.vertex.calls[-1]["contents"])

    def test_a_piece_above_the_last_index_while_waiting_joins_the_set(self):
        self.put(0)
        self.put(2)
        self.assertEqual(self.finish(2).data, {"status": "waiting", "missing": [1]})
        self.put(3)  # the app's mistake: a piece after the one it said was last
        self.assertEqual(Meeting.objects.get().last_index, 3)
        response = self.put(1)
        self.assertEqual(response.data["status"], "ready")
        self.assertIn("Words of piece 3", self.vertex.calls[-1]["contents"])

    def test_final_notes_written_while_a_piece_joins_the_set_are_written_again(self):
        self.put(0)
        self.assertEqual(self.finish(1).data, {"status": "waiting", "missing": [1]})

        def piece_2_joins():  # another request saves piece 2 while piece 1's request writes the notes
            self.assertEqual(self.put(2).status_code, 200)
        self.vertex.during["final"] = piece_2_joins
        self.assertEqual(self.put(1).status_code, 200)
        result = self.get().data["result"]
        self.assertEqual(Meeting.objects.get().last_index, 2)
        finals = [call["contents"] for call in self.vertex.calls if call["stage"] == "final"]
        self.assertNotIn("Words of piece 2", finals[0])
        self.assertIn("Words of piece 2", finals[-1])  # the notes kept are the ones with every piece
        self.assertEqual(result["chapters"][0]["end_minute"], 15)

    def test_a_partial_chapter_is_written_again_when_a_piece_joins_it(self):
        for index in range(8):
            self.put(index)
        self.vertex.failures["final"] = [errors.ServerError(503, {"error": {"message": "down"}})]
        self.assertEqual(self.finish(7).status_code, 503)
        self.assertEqual(MeetingChapter.objects.get(index=1).end_minute, 40)  # pieces 6 and 7
        response = self.put(8)  # the app's mistake: a piece after the one it said was last
        self.assertEqual(response.data["status"], "ready")
        chapters = self.get().data["result"]["chapters"]
        self.assertEqual([(c["start_minute"], c["end_minute"]) for c in chapters], [(0, 30), (30, 45)])
        self.assertEqual(self.vertex.count("chapter"), 3)

    def test_chapter_notes_for_a_set_that_changed_meanwhile_are_dropped(self):
        for index in range(8):
            self.put(index)
        MeetingChapter.objects.filter(index=1).delete()
        Meeting.objects.filter(pk=self.meeting_id).update(last_index=7)
        meeting = Meeting.objects.get()
        pieces = list(MeetingPiece.objects.filter(index__in=[6]).order_by("index"))  # the set was 6 alone
        meetings._save_chapter(meeting, 1, pieces, "Stale", "Stale.")
        self.assertFalse(MeetingChapter.objects.filter(index=1).exists())

    def test_a_step_another_request_is_writing_is_not_paid_twice(self):
        self.put(0)
        cache.add(f"meetings:claim:{self.meeting_id}:final", 1, 60)  # another request holds the final step
        waiting = self.finish(0)
        self.assertEqual((waiting.status_code, waiting.data), (202, {"status": "waiting", "missing": []}))
        self.assertEqual(self.vertex.count("final"), 0)
        cache.delete(f"meetings:claim:{self.meeting_id}:final")  # its claim ended without notes
        self.assertEqual(self.get().data["status"], "ready")
        self.assertEqual(self.vertex.count("final"), 1)
        self.assertIsNone(cache.get(f"meetings:claim:{self.meeting_id}:final"))

    def test_a_chapter_another_request_is_writing_holds_the_final_notes_back(self):
        for index in range(6):
            self.put(index, audio=b"silence" if index else b"piece 0")
        MeetingChapter.objects.all().delete()  # as if its notes were still being written
        cache.add(f"meetings:claim:{self.meeting_id}:chapter:0", 1, 60)
        self.assertEqual(self.finish(5).data, {"status": "waiting", "missing": []})
        self.assertEqual(self.vertex.count("final"), 0)
        cache.clear()
        self.assertEqual(self.get().data["status"], "ready")
        self.assertEqual(MeetingChapter.objects.count(), 1)

    def test_finish_with_no_meeting_stores_nothing(self):
        response = self.finish(4)
        self.assertEqual((response.status_code, response.data), (202, {"status": "waiting", "missing": [0, 1, 2, 3, 4]}))
        self.assertFalse(Meeting.objects.exists())
        self.assertEqual(self.get().status_code, 404)
        for body in ({}, {"last_index": -1}, {"last_index": "x"}, {"last_index": meetings.MAX_INDEX + 1}):
            with self.subTest(body=body):
                self.assertEqual(self.api.post(self.url("finish/"), body, format="json").status_code, 400)

    def test_a_meeting_whose_start_expired_is_marked_and_starts_at_its_first_piece(self):
        # The server swept the first hour (MN-28): the phone's next pieces are 12 and 13.
        self.put(13)
        self.put(12)
        response = self.finish(13)
        self.assertEqual(response.status_code, 200)
        result = response.data["result"]
        self.assertTrue(result["start_missing"])
        self.assertEqual(result["chapters"], [{"start_minute": 60, "end_minute": 70,
                                               "title": "Pricing for the pilot", "notes": "0:05 Price agreed."}])
        self.assertEqual(MeetingChapter.objects.get().index, 2)

    def test_a_piece_after_the_final_notes_is_refused_unless_already_saved(self):
        self.put(0)
        self.finish(0)
        calls = len(self.vertex.calls)
        self.assertEqual((self.put(1).status_code, self.put(1).data), (409, {"code": "meeting_finished"}))
        saved = self.put(0)
        self.assertEqual((saved.status_code, saved.data["status"]), (200, "ready"))
        self.assertEqual(len(self.vertex.calls), calls)
        self.assertEqual(self.counted(), 1)

    def test_half_hour_notes_are_written_by_the_piece_that_completes_them(self):
        for index in range(5):
            self.put(index)
        self.assertEqual(self.vertex.count("chapter"), 0)
        self.put(5)
        self.assertEqual(self.vertex.count("chapter"), 1)
        chapter = MeetingChapter.objects.get()
        self.assertEqual((chapter.index, chapter.start_minute, chapter.end_minute), (0, 0, 30))
        self.put(5)
        self.put(6)
        self.assertEqual(self.vertex.count("chapter"), 1)
        response = self.finish(6)
        self.assertEqual([c["start_minute"] for c in response.data["result"]["chapters"]], [0, 30])
        self.assertEqual(self.vertex.count("chapter"), 2)

    def test_a_failed_chapter_is_written_by_the_next_call(self):
        self.vertex.failures["chapter"] = [errors.ServerError(500, {"error": {"message": "down"}})]
        for index in range(6):
            self.assertEqual(self.put(index).status_code, 200)  # the piece is saved all the same
        self.assertFalse(MeetingChapter.objects.exists())
        self.put(6)
        self.assertEqual(MeetingChapter.objects.get().index, 0)

    def test_a_failed_final_step_is_done_again_by_the_next_call(self):
        self.put(0)
        self.finish(1)
        self.vertex.failures["final"] = [errors.ServerError(503, {"error": {"message": "down"}}),
                                         errors.ServerError(503, {"error": {"message": "down"}})]
        completing = self.put(1)
        self.assertEqual((completing.status_code, completing.data["status"]), (200, "waiting"))
        self.assertEqual(self.finish(1).status_code, 503)
        self.assertEqual(self.get().data["status"], "ready")  # GET does the step too
        self.assertEqual(self.vertex.count("final"), 3)

    def test_a_final_answer_that_doesnt_validate_is_502_and_retried(self):
        self.put(0)
        self.vertex.final = "not json"
        self.assertEqual(self.finish(0).status_code, 502)
        self.vertex.final = {**FINAL, "todos": "Send it"}
        self.assertEqual(self.finish(0).status_code, 502)
        self.vertex.final = FINAL
        self.assertEqual(self.finish(0).status_code, 200)

    def test_a_meeting_with_no_speech_has_an_empty_result_without_the_ai(self):
        self.put(0, audio=b"silence 0", language="ca-ES")
        self.put(1, audio=b"silence 1")
        response = self.finish(1)
        self.assertEqual(response.data, {"status": "ready", "result": {
            "title": "", "summary": "", "todos": [], "decisions": [], "open_questions": [], "chapters": [],
            "start_missing": False, "language": "ca"}})
        self.assertEqual(self.vertex.count("final") + self.vertex.count("chapter"), 0)

    def test_the_final_step_is_written_once_when_two_requests_complete_it(self):
        self.put(0)

        def other_request():
            Meeting.objects.filter(pk=self.meeting_id).update(result={"title": "First"}, ready_at=timezone.now())
        self.vertex.during["final"] = other_request
        response = self.finish(0)
        self.assertEqual(response.data, {"status": "ready", "result": {"title": "First"}})


class AccessTests(MeetingTestCase):
    def test_delete_removes_everything_and_is_idempotent(self):
        for index in range(6):
            self.put(index)
        self.assertTrue(MeetingChapter.objects.exists())
        self.assertEqual(self.delete().status_code, 204)
        self.assertEqual((Meeting.objects.count(), MeetingPiece.objects.count(), MeetingChapter.objects.count()), (0, 0, 0))
        self.assertEqual(self.delete().status_code, 204)
        self.assertEqual(self.delete(meeting_id=uuid.uuid4()).status_code, 204)
        self.assertEqual(self.get().status_code, 404)

    def assert_discarded(self, response, counted):
        self.assertEqual(response.status_code, 404)
        self.assertEqual((Meeting.objects.count(), MeetingPiece.objects.count(), MeetingChapter.objects.count()), (0, 0, 0))
        self.assertEqual(self.counted(), counted)

    def test_a_delete_while_a_later_piece_is_transcribed_sticks(self):
        self.put(0)
        deleted = []
        self.vertex.during["audio"] = lambda: deleted.append(self.delete().status_code)
        self.assert_discarded(self.put(1), counted=1)
        self.assertEqual(deleted, [204])
        self.assert_discarded(self.put(1), counted=1)  # its retry isn't transcribed or counted either
        self.assertEqual(self.vertex.count("audio"), 2)
        self.assertEqual(self.get().status_code, 404)

    def test_a_delete_while_the_first_piece_is_transcribed_sticks(self):
        deleted = []
        self.vertex.during["audio"] = lambda: deleted.append(self.delete().status_code)
        self.assert_discarded(self.put(0), counted=0)
        self.assertEqual(deleted, [204])
        self.assertEqual(self.finish(0).data, {"status": "waiting", "missing": [0]})  # nothing is stored
        self.assertFalse(Meeting.objects.exists())

    def test_a_delete_between_saving_a_piece_and_answering_removes_it(self):
        save = meetings._save_piece

        def then_deleted(*args):
            outcome = save(*args)
            self.assertEqual(self.delete().status_code, 204)
            return outcome
        with patch("core.meetings._save_piece", then_deleted):
            self.assert_discarded(self.put(0), counted=0)

    def test_someone_elses_meeting_is_404_everywhere(self):
        self.put(0)
        other = User.objects.create_user("meeting-other@example.invalid", PASSWORD)
        theirs = self.client_for(other)
        calls = len(self.vertex.calls)
        self.assertEqual(self.put(1, client=theirs).status_code, 404)
        self.assertEqual(self.put(0, client=theirs).status_code, 404)
        self.assertEqual(self.finish(1, client=theirs).status_code, 404)
        self.assertEqual(self.get(client=theirs).status_code, 404)
        self.assertEqual(self.delete(client=theirs).status_code, 404)
        self.assertEqual(len(self.vertex.calls), calls)
        self.assertEqual(self.counted(other), 0)
        meeting = Meeting.objects.get()
        self.assertEqual((meeting.user, meeting.last_index, meeting.pieces.count()), (self.user, None, 1))

    def test_a_piece_racing_another_accounts_first_piece_is_404(self):
        other = User.objects.create_user("meeting-racer@example.invalid", PASSWORD)
        self.vertex.during["audio"] = lambda: Meeting.objects.create(
            pk=self.meeting_id, user=other, last_piece_at=timezone.now())
        self.assertEqual(self.put(0).status_code, 404)
        self.assertEqual(self.counted(), 0)
        self.assertFalse(MeetingPiece.objects.exists())

    def test_every_endpoint_but_delete_needs_pro(self):
        self.put(0)
        calls = len(self.vertex.calls)
        self.has_pro.return_value = False
        for name, response in self.every_endpoint():
            with self.subTest(name):
                self.assertEqual((response.status_code, response.data), (402, {"code": "pro_required"}))
        self.has_pro.return_value = None  # RevenueCat unreachable: never "not Pro"
        for name, response in self.every_endpoint():
            with self.subTest(name):
                self.assertEqual((response.status_code, response.data["code"]), (503, "billing_unavailable"))
        self.assertEqual(len(self.vertex.calls), calls)
        self.assertTrue(Meeting.objects.exists())

    def every_endpoint(self):
        return [("piece", self.put(1)), ("finish", self.finish(1)), ("get", self.get())]

    def test_delete_needs_only_the_login_and_the_meeting(self):
        # A discard or an acknowledgement deletes at once, whatever Pro says (MN-24, MN-25).
        for pro in (False, None):
            with self.subTest(pro=pro):
                self.has_pro.return_value = True
                self.put(0)
                self.has_pro.return_value = pro
                self.assertEqual(self.delete().status_code, 204)
                self.assertFalse(Meeting.objects.exists())
                self.assertEqual(self.put(0).status_code, 402 if pro is False else 503)
                self.meeting_id = uuid.uuid4()
        self.has_pro.reset_mock()
        self.assertEqual(self.delete().status_code, 204)
        self.has_pro.assert_not_called()
        self.assertEqual(APIClient().delete(self.url()).status_code, 401)

    @override_settings(AI_MEETING_PIECES_PER_MONTH=2)
    def test_the_monthly_allowance_refuses_new_pieces_only(self):
        self.put(0)
        self.put(1)
        refused = self.put(2)
        self.assertEqual((refused.status_code, refused.data), (402, {"code": "meeting_allowance_used"}))
        self.assertEqual(self.put(1).status_code, 200)  # saved already
        self.assertEqual(self.vertex.count("audio"), 2)
        self.assertEqual(self.counted(), 2)
        # Deleting the meeting doesn't give the month back.
        self.delete()
        self.assertEqual(self.put(0, meeting_id=uuid.uuid4()).status_code, 402)
        # Another account has its own.
        other = User.objects.create_user("meeting-allowance@example.invalid", PASSWORD)
        self.assertEqual(self.put(0, client=self.client_for(other), meeting_id=uuid.uuid4()).status_code, 200)

    def test_meetings_have_their_own_throttle_and_need_a_login(self):
        for view in (MeetingView, MeetingFinishView, MeetingPieceView):
            self.assertEqual(view.throttle_scope, "meetings")
        self.assertEqual(APIClient().get(self.url()).status_code, 401)


class CleanupTests(MeetingTestCase):
    def meeting(self, user=None, **fields):
        meeting = Meeting.objects.create(pk=uuid.uuid4(), user=user or self.user,
                                         last_piece_at=fields.pop("last_piece_at", timezone.now()), **fields)
        MeetingPiece.objects.create(meeting=meeting, index=0, offset_seconds=0, duration_seconds=300, text="Hi.")
        MeetingChapter.objects.create(meeting=meeting, index=0, start_minute=0, end_minute=5, title="Hi", notes="Hi.")
        return meeting

    def test_maintenance_deletes_meetings_30_days_after_their_last_piece(self):
        now = timezone.now()
        old = self.meeting(last_piece_at=now - timedelta(days=30, minutes=1))
        old_ready = self.meeting(last_piece_at=now - timedelta(days=31), result={"title": "x"},
                                 ready_at=now - timedelta(days=30, minutes=1))
        recent = self.meeting(last_piece_at=now - timedelta(days=29))
        recent_ready = self.meeting(result={"title": "x"}, ready_at=now - timedelta(days=1))
        output = io.StringIO()
        call_command("maintain_staging", stdout=output)
        self.assertEqual(set(Meeting.objects.values_list("pk", flat=True)), {recent.pk, recent_ready.pk})
        self.assertEqual(MeetingPiece.objects.count(), 2)
        self.assertEqual(MeetingChapter.objects.count(), 2)
        self.assertIn("2 old meetings deleted", output.getvalue())
        del old, old_ready

    def test_deleting_the_account_deletes_its_meetings(self):
        self.put(0)
        mine = self.meeting()
        other = User.objects.create_user("meeting-stays@example.invalid", PASSWORD)
        theirs = self.meeting(user=other)
        self.assertTrue(delete_account(self.user))
        self.assertEqual(list(Meeting.objects.values_list("pk", flat=True)), [theirs.pk])
        self.assertEqual(MeetingPiece.objects.filter(meeting=theirs).count(), MeetingPiece.objects.count())
        self.assertEqual(MeetingChapter.objects.filter(meeting=theirs).count(), MeetingChapter.objects.count())
        del mine


class NotesValidationTests(SimpleTestCase):
    def test_the_final_answer_is_normalized(self):
        notes = MeetingNotes.model_validate({
            "title": "  Kickoff ", "summary": "Short.", "language": "es_ES",
            "todos": [{"text": " Call Ana ", "who": " ", "when": "null"}, {"text": "", "who": None, "when": None}],
            "decisions": ["Yes", "yes", ""], "open_questions": None})
        self.assertEqual(notes.model_dump(), {
            "title": "Kickoff", "summary": "Short.", "language": "es",
            "todos": [{"text": "Call Ana", "who": None, "when": None}], "decisions": ["Yes"], "open_questions": []})
        self.assertEqual(MeetingNotes.model_validate({**FINAL, "language": "Spanish!"}).language, "")

    def test_the_schema_requires_every_field(self):
        from .ai import _vertex_schema
        schema = _vertex_schema(MeetingNotes)
        self.assertEqual(set(schema["required"]),
                         {"title", "summary", "todos", "decisions", "open_questions", "language"})
        self.assertNotIn("chapters", schema["properties"])  # the server adds them
