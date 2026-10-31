## UX verify — run 2026-10-13-app, batch b2, round 1, area D (P51) — 2026-10-13

**Verdict:** UX-401 fixed in code and tests; one minor regression in how the sheet's timing meets the new save message and landing highlight.
**Evidence used:** code (`git diff HEAD`), ux-tester's tests in `App/test/reminder_ask_sheet_test.dart`, and current renders `App/build/calendar-es-1.3x-light.png` and `calendar-feedback-light.png` (19:40, newer than the code). No preview covers the sheet itself, so its layout rests on code and the 2x tests.

### UX-401 · fixed (needs a device check)
- Sheet: `App/lib/widgets/reminder_ask_sheet.dart:53-59` is a modal bottom sheet with a drag handle and safe area. The question at `:99-106` is a header and a live region. Below it come `Sí, recuérdamelo` (FilledButton) and `Ahora no` (TextButton).
- When it shows:
  - Only for dated, non-note tasks (`:19-21`).
  - Once per account and phone: `asked` is written whatever the answer, including Back (`:60-76`). Accounts with reminders already on are skipped (`:46`).
  - An in-memory set stops two questions in the same run (`:31`).
  - It waits for the form's route to finish closing (`:44`), so it never covers an unsaved form.
- Callers:
  - Typed save: `App/lib/widgets/task_editor.dart:418`.
  - Voice review, once nothing is left to review: `App/lib/screens/review_tasks_screen.dart:222-224`.
- `Sí` calls `turnOnReminders` (`reminder_control.dart:37`). That asks for the notification permission first. It then switches reminders on with 9:00 for date-only tasks, and runs P8's exact-alarm ask only when that is needed.
- Cleanup: the in-list card is gone from Calendar, Tareas and the empty state. `reminder_ask_card.dart`, `datedTasksProvider` and `TaskList.footer` are deleted, and grep finds no `ReminderAskCard`. The calendar renders show no card.
- Copy: the ES, EN and CA strings match the brief exactly (`app_es.arb:572-574`, `app_en.arb:821-826`, `app_ca.arb:551-553`). The unused key `reminderAskQuestionTasks` is removed.
- Tests: all 8 of ux-tester's tests pass, including 2x text on 320x568 in es and ca.
- Device: check that TalkBack reads the question once (the live region and the sheet's own route announcement may both speak). Check the Android 13+ permission flow and that the reminder arrives on time.

### Regressions
**R1D-1 · Severity 2 · Sheet covers the save message, Undo and landing highlight**
- Where: `App/lib/widgets/reminder_ask_sheet.dart:44,53`. It meets `task_editor.dart:393-417` (the save message is now "Añadido al vie 17 oct" with `Deshacer`, and the calendar focus) and `calendar_screen.dart:110-154` (scroll into view, then a 1.5 s highlight).
- The moment: "¿Quieres un recordatorio antes? ¿Antes de qué? ¿Se guardó?"
- What happens:
  - The sheet opens about 300 ms after the form closes.
  - The 4 s save message, with its Undo, and the 1.5 s landing highlight all play out under the sheet's scrim. The root ScaffoldMessenger's timer keeps running while a route covers it.
  - So on the newcomer's first dated task, the one moment the brief wanted shown first ("saved and shown, after the save confirmation"), they never read where the task went, and Undo is gone when the sheet closes.
- Why it fails: change blindness (Rensink et al. 1997), the peak–end rule (Kahneman et al. 1993), and user control and freedom (Nielsen #3: Undo is unreachable).
- Fix (no new UI):
  - Have `askAboutRemindersAfterSave` also wait for the save SnackBar's `closed` future. `showFeedback` would return its controller.
  - Then show the sheet only if the route that was under the form is still current. If it isn't, release the `_askingProvider` slot so the next dated save asks.
- Verify:
  - In `reminder_ask_sheet_test.dart`, after saving, expect the SnackBar visible and hit-testable with no BottomSheet.
  - After the timeout, expect the sheet.
  - Opening `Nueva tarea` before the timeout must never show the sheet over the form.
- Evidence: verified in code; not seen in a render.

### Noted, not counted
- The voice review asks only when `remaining == 0`. If someone saves some dated drafts and then leaves the review with Back, they aren't asked until their next dated save. This is low impact, and the card it replaced never covered it either.
- Saving an edit to an existing dated task can also trigger the one-time question. "it" still refers to that task, so this is acceptable.
