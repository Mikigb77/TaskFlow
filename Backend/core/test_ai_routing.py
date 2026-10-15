import io
import wave
from datetime import datetime, timezone
from unittest.mock import Mock, patch

import httpx
from django.core.cache import cache
from django.core.exceptions import ImproperlyConfigured
from django.test import SimpleTestCase, override_settings
from google.genai import errors, types

from .ai import AIUnavailable, client, generate, make_drafts, transcribe
from .ai_routing import _cooldown_key, route, TRANSPORT_ERRORS


def provider_error(code):
    cls = errors.ServerError if code >= 500 else errors.ClientError
    return cls(code, {"error": {"message": "Synthetic provider failure"}})


@override_settings(AI_ROUTE="auto", AI_FREE_ATTEMPT_SECONDS=10,
                   AI_TEXT_MODEL="free-text", AI_AUDIO_MODEL="free-audio",
                   CACHES={"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}})
class RoutingTests(SimpleTestCase):
    def setUp(self):
        cache.clear()
        self.now = 100.0
        self.clock = patch("core.ai_routing.time").start()
        self.addCleanup(patch.stopall)
        self.clock.monotonic.side_effect = lambda: self.now
        self.clock.sleep.side_effect = self.advance
        self.free = Mock(return_value="free draft")
        self.paid = Mock(return_value="paid draft")

    def advance(self, seconds):
        self.now += seconds

    def test_free_success_never_uses_paid(self):
        self.assertEqual(route("text", self.free, self.paid), "free draft")
        self.free.assert_called_once_with(10000)
        self.paid.assert_not_called()

    def test_free_transient_recovery_never_uses_paid(self):
        self.free.side_effect = [provider_error(503), "recovered"]
        self.assertEqual(route("text", self.free, self.paid), "recovered")
        self.assertEqual(self.free.call_count, 2)
        self.paid.assert_not_called()

    def test_quota_falls_back_immediately_and_cools_down(self):
        self.free.side_effect = provider_error(429)
        self.assertEqual(route("text", self.free, self.paid), "paid draft")
        self.free.assert_called_once()
        self.paid.assert_called_once_with(45000)
        route("text", self.free, self.paid)
        self.assertEqual(self.free.call_count, 1)
        self.assertEqual(self.paid.call_count, 2)
        # Audio has its own provider quota/circuit, so still tries the free model.
        self.free.side_effect = None
        self.assertEqual(route("audio", self.free, self.paid), "free draft")
        cache.delete(_cooldown_key("text"))
        self.assertEqual(route("text", self.free, self.paid), "free draft")

    def test_a_retry_never_gets_less_than_the_providers_10_s_minimum(self):
        # A slow first failure used to leave 1-4 s, and Google refuses that with a 400 that has no fallback.
        calls = []

        def provider(milliseconds):
            calls.append(milliseconds)
            self.advance(38)
            raise provider_error(500)

        with override_settings(AI_ROUTE="ai_studio"):
            with self.assertRaises(errors.ServerError):
                route("text", provider, self.paid)
        self.assertEqual(calls, [45000])
        self.paid.assert_not_called()
        # In auto mode, the paid fallback isn't called with a doomed deadline either.
        cache.clear()
        calls.clear()

        def overloaded_then_slow(milliseconds):
            calls.append(milliseconds)
            if len(calls) == 2:
                self.advance(38)
            raise provider_error(503)

        with self.assertRaises(errors.ServerError):
            route("text", overloaded_then_slow, self.paid)
        self.assertEqual(len(calls), 2)
        self.paid.assert_not_called()

    @override_settings(AI_FREE_ATTEMPT_SECONDS=4)
    def test_a_free_attempt_is_never_shorter_than_10_s(self):
        self.assertEqual(route("text", self.free, self.paid), "free draft")
        self.free.assert_called_once_with(10000)

    def test_overload_has_two_free_attempts_then_one_paid(self):
        self.free.side_effect = provider_error(503)
        self.assertEqual(route("text", self.free, self.paid), "paid draft")
        self.assertEqual(self.free.call_count, 2)
        self.paid.assert_called_once_with(44500)
        self.assertTrue(cache.get(_cooldown_key("text")))

    def test_both_http_clients_timeout_within_shared_budget(self):
        for transport in TRANSPORT_ERRORS:
            with self.subTest(transport=transport):
                cache.clear()
                self.paid.reset_mock()

                def timeout(milliseconds):
                    self.advance(milliseconds / 1000)
                    raise transport("Synthetic timeout")

                self.free.side_effect = timeout
                self.assertEqual(route("text", self.free, self.paid), "paid draft")
                self.paid.assert_called_once_with(24500)

    def test_permanent_provider_errors_do_not_spend_on_fallback(self):
        for code in (400, 401, 403, 404):
            with self.subTest(code=code):
                self.free.reset_mock()
                self.free.side_effect = provider_error(code)
                with self.assertRaises(errors.APIError):
                    route("text", self.free, self.paid)
                self.free.assert_called_once()
                self.paid.assert_not_called()

    def test_validation_error_does_not_trigger_another_provider(self):
        with patch("core.ai._generate_once", return_value="invalid json") as provider:
            with self.assertRaises(AIUnavailable) as result:
                make_drafts({"text": "Synthetic", "timezone": "UTC",
                             "reference_time": datetime.now(timezone.utc)})
            self.assertEqual(result.exception.status, 502)
            provider.assert_called_once()
            self.assertNotIn("vertex", provider.call_args.kwargs)

    def test_paid_failure_is_not_retried(self):
        self.free.side_effect = provider_error(429)
        self.paid.side_effect = provider_error(503)
        with self.assertRaises(errors.ServerError):
            route("text", self.free, self.paid)
        self.free.assert_called_once()
        self.paid.assert_called_once()

    @override_settings(AI_ROUTE="vertex")
    def test_direct_vertex_bypasses_free(self):
        self.assertEqual(route("text", self.free, self.paid), "paid draft")
        self.free.assert_not_called()
        self.paid.assert_called_once_with(45000)

    @override_settings(AI_ROUTE="ai_studio")
    def test_free_only_mode_cannot_spend_even_with_cooldown(self):
        cache.set(_cooldown_key("text"), True)
        self.free.side_effect = provider_error(429)
        with self.assertRaises(errors.ClientError):
            route("text", self.free, self.paid)
        self.free.assert_called_once_with(45000)
        self.paid.assert_not_called()

    @override_settings(AI_ROUTE="ai_studio")
    def test_free_only_retry_uses_remaining_budget(self):
        calls = []

        def provider(milliseconds):
            calls.append(milliseconds)
            if len(calls) == 1:
                self.advance(20)
                raise provider_error(503)
            return "recovered"

        with override_settings(AI_ROUTE="ai_studio"):
            self.assertEqual(route("text", provider, self.paid), "recovered")
        self.assertEqual(calls, [45000, 24500])
        self.paid.assert_not_called()

    def test_retry_after_is_honored_but_bounded(self):
        error = errors.ClientError(429, {"error": {"message": "Quota"}},
                                   response=httpx.Response(429, headers={"retry-after": "900"}))
        self.free.side_effect = error
        with patch("core.ai_routing.cache.set") as write:
            route("text", self.free, self.paid)
        write.assert_called_once_with(_cooldown_key("text"), True, timeout=300)

    def test_cache_failure_preserves_bounded_fallback(self):
        self.free.side_effect = provider_error(429)
        with patch("core.ai_routing.cache.get", side_effect=ConnectionError), \
                patch("core.ai_routing.cache.set", side_effect=ConnectionError):
            self.assertEqual(route("text", self.free, self.paid), "paid draft")
        self.free.assert_called_once()
        self.paid.assert_called_once()

    @override_settings(AI_ROUTE="typo")
    def test_invalid_mode_fails_before_calling_either_provider(self):
        with self.assertRaises(ImproperlyConfigured):
            route("text", self.free, self.paid)
        self.free.assert_not_called()
        self.paid.assert_not_called()


@override_settings(AI_ROUTE="vertex", AI_VERTEX_PROJECT="synthetic-project",
                   AI_VERTEX_LOCATION="global", AI_VERTEX_AUDIO_MODEL="vertex-audio",
                   AI_VERTEX_TEXT_MODEL="vertex-text", GEMINI_API_KEY="studio-only")
class VertexAdapterTests(SimpleTestCase):
    @patch("core.ai.genai.Client")
    @patch("core.ai.google.auth.default")
    def test_vertex_uses_adc_and_never_studio_key(self, auth, sdk):
        credentials = object()
        auth.return_value = (credentials, "ignored")
        client(1234, vertex=True)
        auth.assert_called_once_with(scopes=["https://www.googleapis.com/auth/cloud-platform"],
                                     quota_project_id="synthetic-project")
        self.assertIs(sdk.call_args.kwargs["credentials"], credentials)
        self.assertTrue(sdk.call_args.kwargs["vertexai"])
        self.assertNotIn("api_key", sdk.call_args.kwargs)
        self.assertEqual(sdk.call_args.kwargs["http_options"].timeout, 1234)
        self.assertEqual(sdk.call_args.kwargs["http_options"].retry_options.attempts, 1)

    @override_settings(AI_VERTEX_PROJECT="")
    @patch("core.ai.genai.Client")
    def test_missing_project_fails_closed(self, sdk):
        with self.assertRaises(AIUnavailable):
            client(vertex=True)
        sdk.assert_not_called()

    @patch("core.ai.client")
    def test_text_uses_vertex_model_and_json(self, sdk):
        api = sdk.return_value.__enter__.return_value
        api.models.generate_content.return_value = types.GenerateContentResponse(
            candidates=[types.Candidate(content=types.Content(parts=[types.Part(text='{"tasks":[]}')]))])
        self.assertEqual(generate("Synthetic input"), '{"tasks":[]}')
        self.assertTrue(sdk.call_args.kwargs["vertex"])
        args = api.models.generate_content.call_args.kwargs
        self.assertEqual(args["model"], "vertex-text")
        self.assertEqual(args["config"].response_mime_type, "application/json")
        schema = args["config"].response_schema
        assignment = schema["$defs"]["ExtractedTask"]["properties"]["assignment_request"]
        self.assertEqual(assignment["anyOf"][0]["enum"], ["me", "member", "group"])
        self.assertNotIn("enum", schema["$defs"]["ExtractedTask"]["properties"]["priority"])
        self.assertIn("title", schema["$defs"]["ExtractedTask"]["properties"])

    @patch("core.ai.client")
    def test_audio_transcription_accepts_vertex_text_parts(self, sdk):
        audio = io.BytesIO()
        with wave.open(audio, "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(16000)
            wav.writeframes(b"\0" * 32000)
        audio.size = len(audio.getvalue())
        audio.seek(0)
        api = sdk.return_value.__enter__.return_value
        api.models.generate_content.return_value = types.GenerateContentResponse(
            candidates=[types.Candidate(content=types.Content(parts=[types.Part(text="Synthetic transcript")]))])
        self.assertEqual(transcribe(audio), "Synthetic transcript")
        args = api.models.generate_content.call_args.kwargs
        self.assertEqual(args["model"], "vertex-audio")
        self.assertEqual(args["contents"][1].inline_data.data, audio.getvalue())
        self.assertIn("verbatim", args["contents"][0].text)
        audio.seek(0)
        transcribe(audio, "ca-ES")
        args = api.models.generate_content.call_args.kwargs
        self.assertIn("ca-ES", args["contents"][0].text)
        self.assertIsNone(args["config"].audio_transcription_config)
