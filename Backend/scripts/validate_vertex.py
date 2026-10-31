"""Paid live fallback probe, separate from the automated test suite.

Run inside the configured backend container. Only the free-provider outage is
simulated; Google credentials, Vertex inference and task validation are real.
The context/input are synthetic and this script creates no tasks or accounts.
"""
import argparse
import io
import json
import os
from pathlib import Path
import sys
from unittest.mock import patch
from datetime import datetime

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
import django
django.setup()

from django.test import override_settings
from google.genai import errors
from core import ai


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audio", type=Path, help="Optional synthetic WAV; otherwise use synthetic text.")
    args = parser.parse_args()
    project = "10000000-0000-4000-8000-000000000001"
    context = {"user_id": 1, "default_project_id": project, "projects": [
        {"id": project, "name": "Physics", "group_name": "Master", "shared": True,
         "people": [{"user_id": 1, "name": "Project owner", "voice_name": ""},
                    {"user_id": 2, "name": "Ana", "voice_name": "Ana"}]}]}
    data = {"text": "Ana needs to finish exercise three in Physics by Thursday. We all need to prepare the final presentation in Physics by Friday.",
            "reference_time": datetime.fromisoformat("2026-10-11T12:00:00+02:00"),
            "timezone": "Europe/Madrid", "collaboration_context": context}
    if args.audio:
        audio = io.BytesIO(args.audio.read_bytes())
        audio.size = len(audio.getvalue())
        data["audio"] = audio
    actual_text, actual_audio = ai._generate_once, ai._transcribe_once
    calls = {"free": 0, "vertex": 0}

    def quota_then_vertex(actual):
        def invoke(*args, vertex=False):
            if not vertex:
                calls["free"] += 1
                raise errors.ClientError(429, {"error": {"message": "Synthetic quota for fallback verification"}})
            calls["vertex"] += 1
            return actual(*args, vertex=True)
        return invoke

    # Local cache prevents this probe from changing the live API's cooldown.
    with override_settings(AI_ROUTE="auto", CACHES={"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}}), \
            patch.object(ai, "_generate_once", side_effect=quota_then_vertex(actual_text)), \
            patch.object(ai, "_transcribe_once", side_effect=quota_then_vertex(actual_audio)):
        result = ai.make_drafts(data)
    tasks = result["tasks"]
    assert len(tasks) == 2, "Expected both independent commitments."
    assert all(task["list_id"] == project and not task["assignment_issues"] for task in tasks), tasks
    member = next(task for task in tasks if task["assignment"] == "member")
    group = next(task for task in tasks if task["assignment"] == "group")
    assert member["assignee_id"] == 2 and member["deadline_date"] == "2026-10-15", member
    assert group["deadline_date"] == "2026-10-16", group
    assert all(not task["due_date"] and not task.get("deadline_at") for task in tasks), tasks
    expected = 2 if args.audio else 1
    assert calls == {"free": expected, "vertex": expected}, calls
    print(json.dumps({"live_vertex_fallback": "passed", "stages": expected,
                      "draft_count": len(tasks), "calls": calls, "timings": result["timings"]}))


if __name__ == "__main__":
    main()
