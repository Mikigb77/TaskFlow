## UX verify — run 2026-10-19-app, round 2, area A — 2026-10-21

Scope: P219 (UX-1654). Changed file: `App/lib/screens/edit_task_screen.dart`.

### UX-1654 · fixed
- `App/lib/screens/edit_task_screen.dart:133-145`: the parser result is now `read`; a new line discards it when `Task.day(read.date).isBefore(today)`, with `today` from `calendarClockProvider` (:124-125). The comment line is there (:142). `ScheduleSuggestion.date` is non-nullable, so the check covers both a planned day and a deadline (the deadline's date is `found.date`, :160-163).
- Below it, everything falls back to the pre-P192 path: title and notes from `arguments.words` (:151-154), `dueDate: later` (:158), `hasTime` false, no deadline. Only the day is checked, so a read day of today stays, even when its hour has gone by (the overnight UX-1623 case stays: Tuesday read, Tuesday today).
- Walkthrough (newcomer, Spanish): a share «Llamar a Marta mañana» left on Monday 19 and resumed on Thursday 22 now opens titled as written with no day chip lit, so one Back saves it to Sin fecha, where they can see it. Before this fix it went silently onto Tuesday 20, a day already gone. With a D9 day it opens on that day. «el viernes» read on Monday is still Friday 23 and is kept.
- Tests (ux-tester, widget level): five UX-1654 cases in `App/test/capture_free_dictations_test.dart:3077-3212`, covering the acceptance checks plus a past deadline; all pass. On Thursday 22, Friday 23 is Mañana, so asserting `new-task-tomorrow` is the correct reading of "Friday 23 on the chip".
- No preview renders a stale share. Code and widget tests are the evidence. Still device-only: the emulator lane step (share, kill, move the date forward, resume).
- `voice_task_screen.dart`, `task_form_entry.dart` and the ARBs are untouched this round, as the brief asked.

### Regressions
None found.
- The rest of the diff in `EditTaskScreen.build` (:28-55) is formatting only: the same widgets and strings.
- D2 fill-by-hand (`heardAt` = the session's capture time) still reads normally for a fresh dictation, whose read day is today or later.
- Side effect, not a regression: a fresh dictation whose only date is in the past (for example «ayer») no longer files the task on yesterday; it keeps the words in the title with no day. That is consistent with the form's "a day gone by adds nothing" rule.
