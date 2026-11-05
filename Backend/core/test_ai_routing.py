import io
import wave
from datetime import datetime, timezone
from unittest.mock import Mock, patch

from django.test import SimpleTestCase, override_settings
from google.genai import errors, types

from .ai import AIUnavailable, client, generate, make_drafts, transcribe
from .ai_routing import route, TRANSPORT_ERRORS


def provider_error(code):
    cls = errors.ServerError if code >= 500 else errors.ClientError
    return cls(code, {"error": {"message": "Synthetic provider failure"}})


class RoutingTests(SimpleTestCase):
    """Vertex only: one 45 s budget per stage, one retry after a transient failure."""

    def setUp(self):
        self.now = 100.0
        self.clock = patch("core.ai_routing.time").start()
        self.addCleanup(patch.stopall)
        self.clock.monotonic.side_effect = lambda: self.now
        self.clock.sleep.side_effect = self.advance
        self.vertex = Mock(return_value="draft")

    def advance(self, seconds):
        self.now += seconds

    def test_success_is_one_call_with_the_whole_budget(self):
        self.assertEqual(route("text", self.vertex), "draft")
        self.vertex.assert_called_once_with(45000)

    def test_transient_failure_is_retried_once_with_the_remaining_budget(self):
        calls = []

        def provider(milliseconds):
            calls.append(milliseconds)
            if len(calls) == 1:
                self.advance(20)
                raise provider_error(503)
            return "recovered"

        self.assertEqual(route("text", provider), "recovered")
        self.assertEqual(calls, [45000, 24500])

    def test_a_second_transient_failure_is_raised(self):
        self.vertex.side_effect = provider_error(503)
        with self.assertRaises(errors.ServerError):
            route("text", self.vertex)
        self.assertEqual(self.vertex.call_count, 2)

    def test_a_retry_never_gets_less_than_the_providers_10_s_minimum(self):
        # Google refuses a deadline under 10 s with a 400, so a slow first failure isn't retried.
        def provider(milliseconds):
            self.advance(38)
            raise provider_error(500)

        self.vertex.side_effect = provider
        with self.assertRaises(errors.ServerError):
            route("text", self.vertex)
        self.vertex.assert_called_once_with(45000)

    def test_both_http_clients_timeout_within_shared_budget(self):
        for transport in TRANSPORT_ERRORS:
            with self.subTest(transport=transport):
                self.now = 100.0
                calls = []

                def provider(milliseconds):
                    calls.append(milliseconds)
                    if len(calls) == 1:
                        self.advance(20)
                        raise transport("Synthetic timeout")
                    return "recovered"

                self.assertEqual(route("text", provider), "recovered")
                self.assertEqual(calls, [45000, 24500])

    def test_quota_and_permanent_errors_are_not_retried(self):
        for code in (400, 401, 403, 404, 429):
            with self.subTest(code=code):
                self.vertex.reset_mock()
                self.vertex.side_effect = provider_error(code)
                with self.assertRaises(errors.APIError):
                    route("text", self.vertex)
                self.vertex.assert_called_once()

    def test_validation_error_does_not_call_the_model_again(self):
        with patch("core.ai._generate_once", return_value="invalid json") as provider:
            with self.assertRaises(AIUnavailable) as result:
                make_drafts({"text": "Synthetic", "timezone": "UTC",
                             "reference_time": datetime.now(timezone.utc)})
            self.assertEqual(result.exception.status, 502)
            provider.assert_called_once()


@override_settings(AI_VERTEX_PROJECT="synthetic-project",
                   AI_VERTEX_LOCATION="global", AI_VERTEX_AUDIO_MODEL="vertex-audio",
                   AI_VERTEX_TEXT_MODEL="vertex-text")
class VertexAdapterTests(SimpleTestCase):
    @patch("core.ai.genai.Client")
    @patch("core.ai.google.auth.default")
    def test_vertex_uses_adc_and_never_an_api_key(self, auth, sdk):
        credentials = object()
        auth.return_value = (credentials, "ignored")
        client(1234)
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
            client()
        sdk.assert_not_called()

    @patch("core.ai.client")
    def test_text_uses_vertex_model_and_json(self, sdk):
        api = sdk.return_value.__enter__.return_value
        api.models.generate_content.return_value = types.GenerateContentResponse(
            candidates=[types.Candidate(content=types.Content(parts=[types.Part(text='{"tasks":[]}')]))])
        self.assertEqual(generate("Synthetic input"), '{"tasks":[]}')
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
