## UX verify — 2026-10-28-app, round 2, area B (P310) — 2026-11-01

Evidence used: `git diff HEAD` of the six changed files, the testers' passing P310 group (`App/test/calendar_feedback_test.dart:5218`), and the current Completadas renders (`App/build/ux/calendar/completed.*`, 13:25, newer than the changed files at 12:51). No device.

**Verdict:** Ship. UX-2638 is fixed. No regressions found.

### Findings

**UX-2638 · fixed**
- `App/lib/providers/task_provider.dart:209-239`: `setCompleted(..., {DateTime? at})`. When completing, `at` wins over the row's own time: `at ?? occurrence.completedTimes[key]` for a repetition and `at ?? occurrence.completedAt` otherwise. Reopening still sends no time. Under `Task.withCompletionTimes` (`App/lib/models/task.dart`, "a time this task carries wins"), the remembered time is the one that gets stored. The comment is updated.
- `App/lib/widgets/task_interactions.dart:15-23`: `toggle(..., {DateTime? doneAt})` passes `at` only on a tick (`task.isCompleted ? null : doneAt`). Deshacer is unchanged: it still passes the original completed row, so its own time comes back (P300's UX-2311 test still passes).
- `App/lib/widgets/task_tile.dart:27, :51-53, :212-218`: a new `doneAt` field goes to `toggle`. The checkbox (:298) and the accessible action (:246) both use the same local `toggle()`, so both carry the time.
- `App/lib/widgets/task_list.dart:88`: `doneAt: task.isCompleted ? null : timeOf?.call(task)`. Only Completadas passes `completedTime`, so Calendar, Tareas and the project lists still stamp now (the tester's third case).
- `App/lib/screens/completed_tasks_screen.dart:35-40, :103-105, :142`: `_doneHere` remembers the time each row had when first seen. The comment now says a re-ticked row keeps its place on the next visit too, which is true.
- Tests (tester, all pass): the 09:00/10:00/11:00 rows, with the 10:00 one reopened and re-ticked at 12:00, store 10:00 and keep the order 11:00, 10:00, 09:00 on the next visit; the same holds for a repetition's `completedTimes` entry; a tick on Calendar or Tareas at 12:00 stores 12:00; Deshacer after a reopen restores the time.
- Render `calendar/completed.list.es.light.1x` (13:25) looks the same as before. The change has no visual side.

### Regressions
None in the changed files or the flows they touch.

### Notes (not regressions)
- Opening a reopened row from Completadas and ticking it on its detail page goes through `TaskInteractions.toggle` without `doneAt` (`App/lib/screens/task_detail_screen.dart:64, :71`), so it is still stamped now. This is the old behaviour, through a less common path. The brief only covered the row's own checkbox. If it matters, the detail page could take the remembered time from Completadas. Severity 1 at most.
- Accepted in the brief: a completion from before schema 21, with no time, that is reopened and then re-ticked or undone is stamped now (`_doneHere` holds null for it).
- `App/test/support/design_fixtures.dart`: only the signature changed, to match. It's a test fixture that ignores `at`.
