## UX verify — round 2, area D (P55 / UX-439) — 2026-10-13
**Verdict:** UX-439 fixed in code and by tests. The phone check is still to do. One new minor regression: another message replacing the save message starts the question early (R2D-1).
**Evidence used:** code (`reminder_ask_sheet.dart`, the diffs of `task_editor.dart` and `review_tasks_screen.dart` against HEAD), ux-tester's widget tests (all pass), and the current render `App/build/calendar-feedback-light.png` (20:19), which shows the message only. No render shows the sheet's timing.

### UX-439 — fixed (device check pending)
- `App/lib/widgets/reminder_ask_sheet.dart:21-25`: `askAboutRemindersAfterSave` takes `feedback:`.
- `:41-45`: it records the route under the form with a `popUntil` that pops nothing.
- `:60-61`: it waits for the form's route and then the save message.
- `:63-65`: it doesn't ask after Deshacer (`SnackBarClosedReason.action`).
- `:67`: it doesn't ask once the person has moved to another screen.
- `:107`: in both cases it releases `_askingProvider`, so the next dated save asks.
- Doc comment: updated at `:14-20`.
- `task_editor.dart` (the save in the diff): the showFeedback future is kept, `unawaited`, then passed as `feedback:`. The message is `Añadida al {weekdayDate}` with `Deshacer`, and the calendar focus is set before the pop.
- `review_tasks_screen.dart` (the save in the diff): asks only when `remaining == 0` and passes `feedback`.
- Copy, layout and `turnOnReminders` are untouched.
- Tests (reminder_ask_sheet_test.dart) cover:
  - the message, `Deshacer` and the lit row with no sheet; there is still no sheet 500 ms before the timeout;
  - no sheet after Deshacer;
  - no sheet after opening `Nueva tarea` or a task before the message closes;
  - the voice review shows the message first;
  - es/ca at 2× text on 320×568.
- Still on a phone: on a fresh account, the row lights up, Deshacer can be tapped first, and TalkBack reads the question once.

### Regressions
**R2D-1 · Severity 2 · A replaced save message makes the question cover the new Undo**
- Where:
  - `App/lib/widgets/reminder_ask_sheet.dart:63-67`;
  - `App/lib/widgets/app_components.dart:13` (`showFeedback` hides the current message first);
  - `App/lib/widgets/task_interactions.dart:25-27` (`Tarea completada · Deshacer`) and `:68` (date changed).
- The moment: "I ticked it to try it, and now a question has come up. Where did Deshacer go?"
- What happens:
  - The newcomer saves their first dated task, then ticks it or moves it within about 4 s.
  - The new message hides the save message with `SnackBarClosedReason.hide`.
  - `_ask` treats any reason other than `action` as "go ahead". The Calendar route is still current, so the sheet opens at once, over `Tarea completada · Deshacer`, and asks for a reminder on a task they just completed.
  - This is the same pattern UX-439 removed, reached by a different path.
- Why it fails: user control and freedom (Nielsen #3), because Undo goes under the scrim; change blindness (Rensink et al. 1997).
- Fix:
  - Ask only when the message closed with `timeout`, `swipe` or `dismiss`.
  - On `hide` or `remove`, return and release the slot. The next dated save asks.
  - No new UI.
- Verify: a widget test. Save a dated task, tick it before the timeout, then expect `Tarea completada` and `Deshacer` hit-testable and no BottomSheet. After that message closes, still no sheet. The next dated save asks.
- Evidence: verified in code.

**R2D-2 · Severity 1 · The question can appear on another tab**
- Where: `reminder_ask_sheet.dart:67`; `main_shell.dart:53,85` (tabs are an IndexedStack inside one route).
- What happens:
  - The person saves on Calendario, then switches to Notas or Ajustes within about 4 s.
  - `under.isCurrent` is still true, because tabs aren't routes, so "¿Quieres un recordatorio antes?" opens over Notas. There, "antes" refers to nothing on screen.
- Fix: in `_ask`, also skip (and release the slot) when the shell's tab changed since the save. Alternatively, rely on R2D-1's rule if switching tabs clears the message.
- Evidence: inferred from code; needs a device check.

### Noted, not counted
- With Android's "Time to take action" set long, the question arrives late. The plan accepted this.
- If the question appears just as a thumb lands, a stray tap on the scrim counts as "asked" for good. This is inherent to any delayed question; watch for it on the phone check.
