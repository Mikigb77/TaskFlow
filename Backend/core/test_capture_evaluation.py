import io
import json
import tempfile
from pathlib import Path
from unittest.mock import patch

from django.core.management import call_command, CommandError
from django.test import SimpleTestCase

from .ai import AIUnavailable
from .capture_evaluation import load_cases, score_output, summarize


class CaptureEvaluationTests(SimpleTestCase):
    def setUp(self):
        self.case = {"timezone": "Europe/Madrid", "expected": [
            {"title_any": ["doctor"], "date": "2026-09-25", "time": "17:00", "notes_contain": ["blood"]},
            {"title_any": ["café"], "date": None, "time": None}]}
        self.output = {"tasks": [
            {"title": "Comprar cafe", "due_date": None, "scheduled_date": None},
            {"title": "Doctor appointment", "due_date": "2026-09-25T15:00:00Z", "notes": "Bring blood results"}]}

    def test_matching_ignores_order_accents_and_offset_representation(self):
        self.assertTrue(score_output(self.case, self.output)["passed"])

    def test_wrong_schedule_and_missing_notes_fail(self):
        self.output["tasks"][1].update(due_date="2026-09-26T18:00:00Z", notes="")
        result = score_output(self.case, self.output)
        self.assertFalse(result["passed"])
        self.assertEqual(set(result["errors"]), {"task_0:date", "task_0:time", "task_0:notes"})

    def test_replacement_task_is_both_omission_and_addition(self):
        self.output["tasks"][1]["title"] = "Walk the dog"
        result = score_output(self.case, self.output)
        self.assertEqual((result["omitted_tasks"], result["extra_tasks"]), (1, 1))
        self.assertFalse(result["passed"])

    def test_provider_failures_do_not_improve_latency(self):
        rows = [{"passed": True, "elapsed_ms": 500}, {"passed": False, "elapsed_ms": 1000},
                {"passed": False, "provider_error": 429, "elapsed_ms": 1}]
        result = summarize(rows)
        self.assertEqual((result["p50_ms"], result["p95_ms"]), (500, 1000))
        self.assertEqual((result["passed"], result["provider_failures"]), (1, 1))
        self.assertIsNone(summarize([])["p95_ms"])

    @patch("core.management.commands.evaluate_capture.make_drafts")
    def test_default_command_never_calls_provider(self, provider):
        call_command("evaluate_capture", stdout=io.StringIO())
        provider.assert_not_called()
        cases = load_cases()
        self.assertEqual(len({case["id"] for case in cases}), len(cases))

    @patch("core.management.commands.evaluate_capture.make_drafts", side_effect=AIUnavailable("Quota", 429))
    def test_quota_stops_run_and_keeps_failed_report(self, provider):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "report.json"
            with self.assertRaises(CommandError):
                call_command("evaluate_capture", live=True, output=str(output), stdout=io.StringIO())
            report = json.loads(output.read_text())
        provider.assert_called_once()
        self.assertEqual(report["summary"]["provider_failures"], 1)
        self.assertLess(report["summary"]["cases"], report["scheduled_cases"])
