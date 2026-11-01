# Completion times

Decided by the owner on 2026-10-31 (D2 of run 2026-10-28-app, `.claude/ux-review/DECISIONS.md`): Completadas lists what was just ticked first. So the server keeps when each completion happened. Nothing shows the time; only that page's order uses it.

## The fields

The task API (`GET` and `PUT /api/tasks/{id}/`) has two more fields:

| Field | Type | Meaning |
|---|---|---|
| `completed_at` | ISO date-time or `null` | When a task that doesn't repeat was completed. `null` while it's open, and for completions from before 2026-10-31. |
| `completed_times` | object | A repeating task's completions: each date of `completed_dates` that has a time, mapped to when it was ticked. Dates completed before 2026-10-31 have none. Always `{}` for a task that doesn't repeat. |

## How the server sets them

On every `PUT`:
- **A time the app sends wins,** clamped to the server's now. The app sends the moment of the tick, so a tick made offline keeps its own time.
- **Else the time kept** for that completion.
- **Else, for a completion new in this save,** the server's now. That covers older apps, which send neither field.
- **Reopening** clears the time: `completed_at` becomes `null`, and an unticked date leaves `completed_times`.
- A completion that was already there without a time stays without one.

## How the app orders Completadas

Newest first by these times. Completions without a time follow, in the order the page used before: by planned date, with undated tasks last.

Code: `TaskSerializer.validate_completion_times` in `core/serializers.py`, migration `0026_completion_times`. Tests: `core/test_completion_times.py`.
