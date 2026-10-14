## UX verify — 2026-10-13-app, b10 round 2, area D — 2026-10-14
**Verdict:** Ship. All four findings are fixed in code and by unit or widget tests. What's left needs a phone: a real Posponer, a late delivery, and the background-isolate Undo timeout. I found no regressions in the changed files.

Evidence: I read the code (`git diff HEAD`) and the tester's test names and results. The re-rendered calendar previews (`App/build/calendar-*.png`, 23:00) show a day that has tasks. No preview renders the empty state, so P118 rests on the widget tests. I didn't run Flutter.

### P117
**UX-409 · fixed (phone check still open)**
- `App/lib/services/reminder_engine.dart:323-333`: the snooze branch now builds the body with `copy.body(task, when.toLocal(), 0)`, where `when` comes from `reminder_snoozes.fire_at`. Lead 0 means no `· en N min` tail. `.toLocal()` makes today/tomorrow follow the snooze's own day. The `firing` local is gone, and the comment matches the brief.
- `App/lib/services/reminder_copy.dart`: the doc comment on `body` now says "A snoozed alert passes lead 0…".
- Tests: `reminder_engine_test.dart:718-808`. A snooze at 16:51 reads exactly `Hoy a las 17:00` before and after `reconcile`. EN 12-hour reads `Today at 5:00 PM`. CA reads `Avui a les 17:00`. A snooze that crosses midnight reads `Hoy a las…` with no `·`.
- Still needs a phone: a real Posponer about 10 minutes later, and a late delivery while the phone is idle.

**UX-632 · fixed**
- `reminder_copy.dart` `body`: after `notificationAt`, when `day == 'other'`, the first character is upper-cased. This happens before the lead tail is added. The deadline branch returns earlier, so `Fecha límite: vie, 25 sept…` stays lowercase.
- Tests: `reminder_engine_test.dart:698-706`, `810-844`. ES reads `Vie, 25 sept a las 17:00`. CA starts upper-case and ends with ` a les 17:00`. The deadline test keeps the lowercase date.
- No ARB file was touched this round: the ARB files date from 22:05, and the round-2 plan from 22:31. `notificationSnoozed` no longer appears anywhere.

**UX-631 · fixed in code (the background-isolate path needs a phone)**
- `App/lib/services/feedback_timeout.dart:12-37`: `forAction({Duration original = defaultDuration})` sends `original` and returns `original` in every fallback. The 9 existing callers behave as before.
- `App/lib/services/notification_service.dart:100-121`: `showUndo` is async and sets `timeoutAfter: (await TaskReminders.undoTimeout()).inMilliseconds`.
- `notification_service.dart:237-261`: `rememberUndoTimeout()` stores `undo_timeout_ms` in `reminder_meta` and swallows errors. `undoTimeout()` returns the saved value only when it is longer than 10 s, otherwise `undoWindow`.
- `rememberUndoTimeout()` is called, unawaited, inside `if (!background)` (`:231`) and on `resumed` (`App/lib/main.dart:130`).
- `undoWindow` is still 10 s, with the new comment. Nothing changed under `App/android` or `App/ios`.
- Tests: `feedback_timeout_test.dart` and `reminder_undo_timeout_test.dart` (10 s, 4000 → 10 s, 30000 → 30 s, unreadable value → 10 s).
- Still needs a phone: with Tiempo para actuar set to 1 minute, `Completada:` with Deshacer stays about a minute.

### P118
**U12 · fixed (the §7 newcomer check still needs a phone)**
- `App/lib/providers/first_task_provider.dart`: `FirstTaskStore` uses the `app_preferences` scope `firstTask:<owner>`.
- `hadTaskProvider` watches `taskRepositoryProvider.ownerKey`. That provider rebuilds when the account changes (`task_provider.dart:13-19`), so each account has its own flag. It listens to `taskProvider` with `fireImmediately`.
- `sawTask()` sets `true` at once and stores it, swallowing write errors. A read error counts as `false`. A load that finishes after `sawTask` never overwrites `true`.
- Notes count too: they live in `taskProvider` (`Task.isNote`).
- `App/lib/screens/calendar_screen.dart:688-702`:
  - The day shows `calendarEmpty` when the list has anything or the flag is `true`.
  - The try-it instruction (say or type, chosen by `voiceAvailableProvider` as before) shows only when the list is empty and the flag is `false`.
  - While the flag is loading, an empty account sees the same spinner as the list's loading state. The comment matches the brief.
- `design_fixtures.dart`: `MemoryFirstTaskStore` is the default override, with `hadTask: false` unless a test sets it.
- Tests: delete-then-empty shows `Nada previsto para este día.`; so does a restart with a stored flag; the spinner shows while the flag loads; the flag is per account; nothing overflows at 2× text, 320 dp, in Catalan; P41's say/type checks still pass.
- Accepted on purpose: an account that existed before this build and already has no tasks sees the instruction until its first task. Undoing the very first save doesn't bring the instruction back.

### Regressions
None found in the changed files or the flows they touch: the reminder body, snooze, Completar/Deshacer, the snackbar timeouts (the default path is unchanged), and Calendar's empty and loading states.

One edge, not a regression: a snooze that crosses midnight for a task on the previous day, such as 23:55 snoozed to 00:05, now reads `Mar, 22 sept a las 23:55`. That is an absolute date and true. Round 1's text there was false.
