"""Send an explicitly supplied synthetic WAV through the local paid API.

Uses the isolated fixture written by validate_projects.py. No microphone access.
--transcribe-only exercises note transcription independently of task extraction.
"""
import argparse
import json
from pathlib import Path
import uuid
from validate_projects import REFERENCE_TIME, call


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("audio", type=Path)
    parser.add_argument("--fixture", type=Path, default=Path("App/build/project-e2e.json"))
    parser.add_argument("--transcribe-only", action="store_true")
    args = parser.parse_args()
    fixture = json.loads(args.fixture.read_text(encoding="utf-8"))
    base = "http://127.0.0.1:8088/api/"
    account = call(base, "POST", "auth/login/", {"email": fixture["PROJECT_E2E_EMAIL"], "password": fixture["PROJECT_E2E_PASSWORD"]})
    audio = args.audio.read_bytes()
    assert len(audio) <= 6 * 1024 * 1024 and audio.startswith(b"RIFF"), "Supply a bounded synthetic WAV."
    boundary = "TaskFlowFixture" + uuid.uuid4().hex
    parts = []
    fields = {"timezone": "Europe/Madrid", "project_id": fixture["PROJECT_E2E_PROJECT"],
              "reference_time": REFERENCE_TIME,
              "capture_type": "note" if args.transcribe_only else "task"}
    for key, value in fields.items():
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode())
    parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="audio"; filename="synthetic-projects.wav"\r\nContent-Type: audio/wav\r\n\r\n'.encode() + audio + b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode())
    result = call(base, "POST", "ai/drafts/", b"".join(parts), account["access"],
                  headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
    assert "physics" in result["transcript"].casefold(), result
    if args.transcribe_only:
        assert result["tasks"][0]["kind"] == "note", result
    else:
        assert len(result["tasks"]) == 2, result
        assigned = [task for task in result["tasks"] if task["assignment"] == "member"]
        assert len(assigned) == 1 and assigned[0]["assignee_id"] == int(fixture["PROJECT_E2E_MEMBER_ID"]), result
        group = [task for task in result["tasks"] if task["assignment"] == "group"]
        assert len(group) == 1, result
        assert assigned[0]["deadline_date"] == "2026-10-15", result
        assert group[0]["deadline_date"] == "2026-10-16", result
        assert all(not task["due_date"] and not task.get("deadline_at") for task in result["tasks"]), result
        assert all(task["list_id"] == fixture["PROJECT_E2E_PROJECT"] and task["deadline_date"] and not task["assignment_issues"] for task in result["tasks"]), result
    print(json.dumps({"real_paid_audio": "passed", "mode": fields["capture_type"], "draft_count": len(result["tasks"]), "transcript": result["transcript"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
