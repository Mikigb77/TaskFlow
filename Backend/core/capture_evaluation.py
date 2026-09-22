"""Synthetic, repeatable extraction evaluation; never reads account/task data."""
import json
import math
import unicodedata
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo


def load_cases():
    return json.loads((Path(__file__).parent / "evaluation" / "capture_cases.json").read_text(encoding="utf-8"))


def normalize(value):
    return "".join(c for c in unicodedata.normalize("NFKD", value.casefold()) if not unicodedata.combining(c))


def score_output(case, output):
    actual = list(output.get("tasks", []))
    expected = case["expected"]
    errors = []
    if len(actual) != len(expected):
        errors.append(f"task_count:{len(actual)}!=expected:{len(expected)}")
    remaining = list(range(len(actual)))
    omitted = 0
    for index, want in enumerate(expected):
        words = [normalize(word) for word in want["title_any"]]
        # Distinct title concepts make these fixtures order-independent. A
        # replacement task is both an omission and an unwanted addition.
        matching = [i for i in remaining if any(word in normalize(actual[i].get("title", "")) for word in words)]
        if not matching:
            errors.append(f"task_{index}:missing")
            omitted += 1
            continue
        selected = matching[0]
        remaining.remove(selected)
        task = actual[selected]
        due = task.get("due_date")
        local = datetime.fromisoformat(due.replace("Z", "+00:00")).astimezone(ZoneInfo(case["timezone"])) if due else None
        values = {
            "date": local.date().isoformat() if local else task.get("scheduled_date"),
            "time": local.strftime("%H:%M") if local else None,
            "priority": task.get("priority"),
            "recurrence": task.get("recurrence", "none"),
            "repeat_until": task.get("repeat_until"),
            "questions": bool(task.get("questions")),
        }
        for key in values:
            if key in want and values[key] != want[key]:
                errors.append(f"task_{index}:{key}")
        for word in want.get("notes_contain", []):
            if normalize(word) not in normalize(task.get("notes", "")):
                errors.append(f"task_{index}:notes")
                break
        if "checklist" in want:
            steps = [normalize(item["title"]) for item in task.get("checklist", [])]
            if len(steps) != len(want["checklist"]) or any(
                not any(normalize(word) in step for step in steps) for word in want["checklist"]
            ):
                errors.append(f"task_{index}:checklist")
    if remaining:
        errors.append(f"extra_tasks:{len(remaining)}")
    return {"passed": not errors, "errors": errors,
            "omitted_tasks": omitted, "extra_tasks": len(remaining)}


def summarize(results):
    times = sorted(row["elapsed_ms"] for row in results if not row.get("provider_error"))
    percentile = lambda fraction: times[max(0, math.ceil(len(times) * fraction) - 1)] if times else None
    return {"cases": len(results), "passed": sum(row.get("passed", False) for row in results),
            "provider_failures": sum(bool(row.get("provider_error")) for row in results),
            "omitted_tasks": sum(row.get("omitted_tasks", 0) for row in results),
            "extra_tasks": sum(row.get("extra_tasks", 0) for row in results),
            "p50_ms": percentile(.5), "p95_ms": percentile(.95)}
