# UX loop report: 2026-10-13-app, batch b10 (closed 2026-10-14)

**Verdict:** All 5 findings in this batch are fixed in code, and each one is locked by a unit or widget test. UX-632 is fully verified. UX-409, UX-411, UX-631 and U12 still need a check on the owner's phone. The round-2 reviewer found no regressions. Nothing is escalated.

This is code and test evidence only. Flutter wasn't run during verification. No rendered preview shows Calendar's empty state or a notification, so nothing here rests on a render, an emulator or a physical device.

## Verified
- **UX-632**: reminder text that starts with a weekday date began lowercase in Spanish and Catalan. Fixed in P117. It was regression R1D-2, caused by P29 in round 1.
  - It now reads `Vie, 25 sept a las 17:00`. Catalan is capitalised the same way.
  - The deadline form keeps its lowercase date: `Fecha límite: vie, 25 sept…`.

## Verified in code; still needs a phone (ledger status `device-check`)
- **UX-409**: notification text gave relative times that went stale. Round 1 (P29) only partly fixed it: a snoozed alert kept the out-of-date ` · en 10 min` ending. Round 2 (P117) passes no lead time for a snoozed alert, so it reads:
  - `Hoy a las 17:00` (Spanish);
  - `Today at 5:00 PM` (English);
  - `Avui a les 17:00` (Catalan).
- **UX-411**: tapping "Completar" on a notification couldn't be undone. Fixed in round 1 (P29).
  - The alert becomes `Completada: {title}` with a Deshacer button, and makes no sound.
  - Deshacer reopens the task, or that day of a repeating task, and puts the alert back.
  - The reviewer didn't re-check it in round 2, but round 2's tests passed.
- **UX-631**: the Undo on a notification ignored Android's accessibility timeout. It was regression R1D-1, caused by P29. Fixed in P117.
  - While the app is open, it stores Android's recommended timeout.
  - Undo now stays for the longer of that timeout and 10 seconds.
- **U12**: there was no learn-by-doing first run. Round 1 (P41) only partly fixed it: deleting the only task brought the first-run instruction back. Round 2 (P118) added a flag per account:
  - `Prueba: toca Añadir tarea y di «…»` (or `escribe «…»`) shows only until the account's first task or note;
  - after that, an empty day reads `Nada previsto para este día.`, including after a restart.
  - Accepted on purpose: an account from before this build that already has no tasks sees the instruction until its first task.
  - Related items handled elsewhere: the reminder question at the first dated task is P32, and whether the instruction should teach several tasks in one dictation is the owner's question UX-617.

## Still open
None.

## Escalated
None.

## Checks for the owner's phone
1. **UX-409:** tap Posponer on a real reminder. About 10 minutes later the alert should read `Hoy a las 17:00` with no ` · en N min` ending.
2. **UX-409:** let a reminder arrive late while the phone is idle. Its text should still be true.
3. **UX-411:** tap Completar on a notification. `Completada: {title}` with Deshacer should replace the alert in the notification shade. Check how long it takes the Undo line to appear when the app is closed, then tap Deshacer: the task should reopen.
4. **UX-631:** set Android's "Tiempo para actuar" to 1 minute. After Completar, `Completada:` with Deshacer should stay for about a minute.
5. **U12:** the §7 newcomer check, with a new account in Spanish:
   - an empty Calendar shows the try-it instruction;
   - after adding one task and deleting it, the empty day shows `Nada previsto para este día.`

## Files changed
- `App/lib/services/reminder_copy.dart`
- `App/lib/services/reminder_engine.dart`
- `App/lib/services/notification_service.dart`
- `App/lib/services/feedback_timeout.dart`
- `App/lib/providers/first_task_provider.dart` (new)
- `App/lib/screens/calendar_screen.dart`
- `App/lib/main.dart`
- `App/lib/l10n/app_en.arb`, `app_es.arb`, `app_ca.arb`
- `App/lib/l10n/generated/*` (regenerated with `flutter gen-l10n`, not edited by hand)
- `App/test/reminder_engine_test.dart`
- `App/test/calendar_feedback_test.dart`
- `App/test/capture_sheet_test.dart`
- `App/test/reminder_ask_sheet_test.dart`
- `App/test/feedback_timeout_test.dart`
- `App/test/reminder_undo_timeout_test.dart` (new)
- `App/test/support/design_fixtures.dart`

## Locked by tests
- **UX-409**: `reminder_engine_test.dart:718-808`. Covers a snooze in Spanish, English with a 12-hour clock, Catalan, and a snooze that crosses midnight.
- **UX-411**: `reminder_engine_test.dart` (Completar, then Deshacer).
- **UX-631**: `feedback_timeout_test.dart` and `reminder_undo_timeout_test.dart`. Covers 10 s, 4000 ms giving 10 s, 30000 ms giving 30 s, and an unreadable stored value giving 10 s.
- **UX-632**: `reminder_engine_test.dart:698-706` and `810-844`. Covers Spanish, Catalan, and the deadline form keeping its lowercase date.
- **U12**: `calendar_feedback_test.dart` and `capture_sheet_test.dart`. Covers:
  - after deleting the last task, the day shows `Nada previsto para este día.`;
  - after a restart with the flag stored, it does too;
  - a spinner shows while the flag loads;
  - each account has its own flag;
  - no overflow at 2× text, 320 dp, in Catalan;
  - P41's say and type versions of the instruction.

## Rounds
- **Round 1** (`plan.json`; P29 and P41 done; tests **failed**). The failing test was U12's: deleting the only task brought the instruction back.
  - Reviewer (`verify-b10-r1-D.md`): UX-411 fixed; UX-409 and U12 partly fixed.
  - Regressions: R1D-1 (became UX-631) and R1D-2 (became UX-632).
- **Round 2** (`plan-b10-r2.json`; P117 and P118 done; tests **passed**).
  - Reviewer (`verify-b10-r2-D.md`): UX-409, UX-631, UX-632 and U12 fixed. No regressions.
  - An edge the reviewer noted, not a regression: a snooze that crosses midnight for a task on the previous day now shows that day's absolute date, which is true (`Mar, 22 sept a las 23:55`). Round 1's text there was false.
