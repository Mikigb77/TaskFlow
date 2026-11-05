import json
import time
from datetime import datetime, timezone
from pathlib import Path
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from core.ai import AIUnavailable, make_drafts
from core.capture_evaluation import load_cases, score_output, summarize


class Command(BaseCommand):
    help = "Evaluate the configured extraction model on synthetic English/Spanish capture cases."

    def add_arguments(self, parser):
        parser.add_argument("--live", action="store_true", help="Call the configured provider; consumes its quota.")
        parser.add_argument("--case", action="append", default=[], help="Run one or more case IDs.")
        parser.add_argument("--output", help="Write a JSON report (synthetic responses only).")

    def handle(self, *args, **options):
        cases = load_cases()
        if options["case"]:
            unknown = set(options["case"]) - {case["id"] for case in cases}
            if unknown:
                raise CommandError("Unknown cases: " + ", ".join(sorted(unknown)))
            cases = [case for case in cases if case["id"] in options["case"]]
        if not options["live"]:
            self.stdout.write(f"{len(cases)} synthetic cases. Use --live to call the configured provider.")
            return
        results = []
        for case in cases:
            started = time.monotonic()
            try:
                output = make_drafts({"text": case["text"], "timezone": case["timezone"],
                    "reference_time": datetime.fromisoformat(case["reference_time"])})
                score = score_output(case, output)
                row = {"id": case["id"], **score, "output": output}
            except AIUnavailable as error:
                row = {"id": case["id"], "passed": False, "provider_error": error.status}
            row["elapsed_ms"] = round((time.monotonic() - started) * 1000)
            results.append(row)
            self.stdout.write(f"{case['id']}: {'PASS' if row['passed'] else 'FAIL'} ({row['elapsed_ms']}ms) "
                              + ",".join(row.get("errors", [])))
            if row.get("provider_error") == 429:
                self.stdout.write("Stopped after quota refusal; remaining cases are unmeasured.")
                break
        report = {"schema_version": 1, "evaluated_at": datetime.now(timezone.utc).isoformat(),
                  "model": settings.AI_VERTEX_TEXT_MODEL, "mode": "synthetic_text", "scheduled_cases": len(cases),
                  "summary": summarize(results), "results": results}
        if options["output"]:
            path = Path(options["output"])
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
        self.stdout.write(json.dumps(report["summary"]))
        if not results or not all(row["passed"] for row in results) or len(results) != len(cases):
            raise CommandError("Capture evaluation did not pass completely. Inspect the report; failed or unmeasured cases remain.")
