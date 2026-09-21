"""Explicit live test of multi-task capture. Uses only synthetic text/audio.

python scripts/flexible_smoke_test.py [--audio /tmp/taskflow-batch.wav]
Calls the configured models; never prints credentials or records a microphone.
"""
import argparse
import json
import requests


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:8000")
    parser.add_argument("--audio")
    args = parser.parse_args()
    data = {"timezone": "Europe/Madrid", "reference_time": "2026-09-21T12:00:00+02:00"}
    url = args.base + "/api/ai/drafts/"
    if args.audio:
        with open(args.audio, "rb") as audio:
            response = requests.post(url, data=data, files={"audio": ("tasks.wav", audio, "audio/wav")}, timeout=110)
    else:
        response = requests.post(url, json={**data, "text":
            "On Friday at 5 p.m. I have a doctor appointment. Bring my blood test results. "
            "Also buy coffee sometime. Water the plants every Sunday at 9 a.m."}, timeout=110)
    assert response.status_code == 200, f"HTTP {response.status_code}: {response.text[:300]}"
    result = response.json()
    tasks = result["tasks"]
    assert len(tasks) == 3, result
    doctor = next(task for task in tasks if "doctor" in task["title"].lower())
    coffee = next(task for task in tasks if "coffee" in task["title"].lower())
    plants = next(task for task in tasks if "plant" in task["title"].lower())
    assert doctor["due_date"] == "2026-09-25T17:00:00+02:00", doctor
    assert "blood" in doctor["notes"].lower(), doctor
    assert coffee["due_date"] is None and coffee["scheduled_date"] is None, coffee
    assert plants["recurrence"] == "weekly" and plants["due_date"] == "2026-09-27T09:00:00+02:00", plants
    assert not any(task["questions"] for task in tasks), tasks
    print("PASS guest multi-task " + ("audio" if args.audio else "text") + ": timed appointment, Inbox task, weekly recurrence")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
