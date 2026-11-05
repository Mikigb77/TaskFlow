"""Paid live Vertex probe, separate from the automated test suite.

Run inside the configured backend container. Google credentials, Vertex
inference and task validation are real. The context/input are synthetic and
this script creates no tasks or accounts.
"""
import argparse
import io
import json
import os
from pathlib import Path
import sys
from datetime import datetime

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
import django
django.setup()

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
    result = ai.make_drafts(data)
    tasks = result["tasks"]
    assert len(tasks) == 2, "Expected both independent commitments."
    assert all(task["list_id"] == project and not task["assignment_issues"] for task in tasks), tasks
    member = next(task for task in tasks if task["assignment"] == "member")
    group = next(task for task in tasks if task["assignment"] == "group")
    assert member["assignee_id"] == 2 and member["deadline_date"] == "2026-10-15", member
    assert group["deadline_date"] == "2026-10-16", group
    assert all(not task["due_date"] and not task.get("deadline_at") for task in tasks), tasks
    print(json.dumps({"live_vertex": "passed", "stages": 2 if args.audio else 1,
                      "draft_count": len(tasks), "timings": result["timings"]}))


if __name__ == "__main__":
    main()
