## UX verify — 2026-10-13-app, round 1, area D (P29, P41) — 2026-10-14

Evidence: code (`git diff HEAD`) plus the ux-tester results. No current render covers Calendar's empty state or a notification, so nothing here rests on a render. Flutter not run.

### UX-409 · partly fixed
- `App/lib/services/reminder_copy.dart:85-114` builds the body from the absolute time, in the alert's language and the stored 12/24-hour clock (`readReminderCopy`, :32-61). ARB `notificationAt` / `notificationDeadlineAt` use `hour` plural for `a la` / `a las` in ES and CA. Timed, tomorrow, weekday-date and deadline lines match the brief; tests pass.
- Snooze: `App/lib/services/reminder_engine.dart:323-339` rebuilds the original line with the original lead, so the snoozed alert (firing at ~17:01 for a 17:00 task) reads `Hoy a las 17:00 · en 10 min`. The test asserts exactly that (`reminder_engine_test.dart:721,731`). The ` · en 10 min` tail is false when it is shown — the same staleness UX-409 was about. Fix: for a snoozed alert pass lead 0 (`copy.body(task, firing.when, 0)`), so it reads `Hoy a las 17:00` / `Today at 5:00 PM` / `Avui a les 17:00`.
- Device: 20-min-late delivery still leads with `Hoy a las 17:00` (tail stale by design of the brief).

### UX-411 · fixed (needs device)
- `reminder_engine.dart:595-622`: after `complete`, `driver.showUndo` posts `Completada: {title}` with `Deshacer`; `undo` reopens the task (or that day of a repeating task) and reposts the alert silently with its token. `notification_service.dart:96-120` uses `timeoutAfter` = `TaskReminders.undoWindow` (10 s), silent. iOS `undo_<lang>` category registered (:197-205). Posponer unchanged.
- Device: real replacement in the shade, timeoutAfter, background-isolate latency between tap and the undo line.

### U12 · partly fixed
- `App/lib/screens/calendar_screen.dart:684-696`: with no tasks/notes at all the empty state reads `Prueba: toca Añadir tarea y di «…»` (voice available) or `… escribe «…»`; otherwise `Nada previsto para este día.` Button names match `addTask` in all three ARBs. Loading shows a spinner first, so no flash. 2x/320 fit tests pass.
- Not met: "the instruction never comes back". The condition is the live task list, so deleting the account's only task brings the instruction back (tester: fail). Fix: persist a per-account "has had a task" flag the first time the task list is non-empty, and show `calendarEmpty` once it is set.

### Regressions
- R1D-1 · Sev 2 · Undo after Completar ignores the accessibility timeout. `notification_service.dart:113` fixes 10 s; in-app undo bars use `FeedbackTimeout.forAction()` (Android recommended timeout). A TalkBack or tremor user with a longer timeout loses Deshacer. Fix: `timeoutAfter: max(10 s, FeedbackTimeout.forAction())` when the channel is reachable (foreground), else 10 s.
- R1D-2 · Sev 1 · Weekday-date reminder lines start lowercase in ES/CA: `vie, 25 sept a las 17:00` (`reminder_copy.dart:107`, test :703). Fix: capitalise the first letter of the body when it starts with the date (`Vie, 25 sept a las 17:00`).
