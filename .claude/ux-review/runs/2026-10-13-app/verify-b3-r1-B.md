## UX verify — b3 round 1, area B (P58, P9) — 2026-10-13
**Verdict:** All four findings are fixed. Four small regressions came with the shared date sheet. Two are S2: a "Listo" press that seems to do nothing when the a. m./p. m. error is off-screen, and a chip row where two chips apply at once and the third doesn't.
**Evidence level:** code and ux-tester's passing tests. No preview covers the move sheet, the repeat sheet or the 12-hour time row. The fresh renders in `App/build/` (calendar-feedback, calendar-es-1.3x, review-*) don't show these flows, so they aren't evidence here.

### UX-450 · fixed
- `App/lib/widgets/device_calendar_events.dart:126-128`: `Semantics(button: true, enabled: onTap != null, …)`. While a retry runs, `onTap` is null, so TalkBack hears "desactivado". When idle, the button is enabled. There's no visual change and no new string.
- Tests: two UX-450 semantics tests in `calendar_feedback_test.dart:1994`. ux-tester checked the semantics before, during and after a held retry, and checked that the line's rect stays the same.

### UX-206 · fixed
- `App/lib/widgets/task_interactions.dart:49-55` opens `editSchedule(…, moving: task)`.
- `App/lib/widgets/schedule_editor.dart:217-228`: when moving, Hoy and Mañana call `_select` and then `_done()`. The sheet closes at once, and the loaded hour, minutes and a. m./p. m. are kept.
- `task_interactions.dart:60-84`: the message is `movedOccurrenceDate(weekdayDate(date))`, "Movida al mié, 14 oct", with Deshacer, through `showFeedback`. It uses the messenger's context if the row has left the screen. `scheduleUpdated` is gone from all three catalogs.
- Taps to move a task to tomorrow: 4 → 3 (swipe, Mañana; the swipe's own confirm step is unchanged).
- Test: `calendar_feedback_test.dart:527`. It checks that the time is kept, the snackbar starts with "Movida al <weekday>", and Deshacer restores the date.

### UX-212 · fixed
- One date sheet: `_ScheduleSheet` is deleted (task_interactions.dart, −150 lines). A grep finds no `_ScheduleSheet`, `saveSchedule` or `scheduleUpdated` in `lib/` outside `generated/`.
- The move features are carried over into `schedule_editor.dart`:
  - The scope chips Esta repetición / Toda la serie and the help line (:182-206).
  - `_setScope` reloads the series start or the occurrence date (:89-100).
  - Sin fecha is hidden for an occurrence (:215).
  - Omitir esta repetición and Restaurar la fecha original (:233-259).
  - The title uses `rescheduleTask` / `rescheduleRepeating`, and the sheet confirms with `done` (Listo).
- One repeat editor: `App/lib/widgets/task_editor.dart:839-858`. The dropdown, the inline `RepeatRuleControl` and the end-date row are replaced by a "Repetir" row. Its subtitle shows the rule and "hasta …", and tapping it opens `editTaskRepeat` (`repeat_rule_control.dart:101`), the same sheet the capture result uses. `Task.copyWith` uses an `_unchanged` sentinel (`task.dart:517, 556`), so clearing the end date in the sheet carries back correctly.
- Tests: `calendar_feedback_test.dart:614, 672, 720` and `task_creation_test.dart:306`.

### UX-221 · fixed (the P9 part; typed-time chips moved to P38)
- `App/lib/services/quick_schedule_parser.dart:110-123`: a single bare "a las N" with N = 0 or 13–23 becomes N:00, with no ambiguity. 1–12 is still ambiguous. The deadline-marker guard is kept.
- `schedule_editor.dart`:
  - :319-322: empty minutes pass validation.
  - :135: empty minutes save as :00.
  - :59 and :76: `_pm` is null when there was no time, so neither chip is selected (:344, :351).
  - :122-124 and :357-361: if the user presses Listo without choosing, the sheet stays open and shows `chooseAmPm` (EN "Choose AM or PM." / ES "Elige a. m. o p. m." / CA "Tria a. m. o p. m.").
  - An existing time keeps its period.
- Tests: `quick_schedule_parser_test.dart:105` and `schedule_editor_test.dart:214, 233, 281`.

### Regressions

**R1B-1 · Severity 2 · "Listo" seems dead when the a. m./p. m. error is off-screen**
- Where: `App/lib/widgets/schedule_editor.dart:122-124` and :334-361, the 12-hour time row in the shared date sheet. That's every editSchedule caller: move, TaskEditor, the capture result, the deadline.
- The moment: "I typed 5 and pressed Listo. Nothing happened. Is it broken?"
- What happens:
  - With the keyboard up after typing the hour, the scroll area shrinks (`viewInsets` padding, :165-167). The focused hour field is scrolled into view, but the a. m./p. m. chips and the new error line sit below it, in the 85% sheet.
  - Listo, pinned above the keyboard, sets `_missingPeriod`, but nothing scrolls or moves focus.
  - At 1.3–2× text the chips are almost certainly below the fold.
  - TalkBack hears nothing, because the error isn't a live region.
  - Before this round, a. m. was preselected, so Listo always closed the sheet (wrongly). The silent no-op is new.
- Why: gulf of evaluation (Norman 2013); visibility of system status (Nielsen 1994); errors must be seen where the user is looking.
- Fix:
  - When `_missingPeriod` turns true, dismiss the keyboard (`FocusScope.of(context).unfocus()`) and `Scrollable.ensureVisible` the a. m./p. m. chips' row, using a GlobalKey on the Wrap at :337.
  - Wrap the error Text in `Semantics(liveRegion: true)`.
  - No new strings.
- Verify:
  - Widget test: 12-hour clock, 2× text, 360×640, keyboard inset 300. Type "5" in the hour field and tap Listo. `chooseAmPm` must be hit-testable inside the visible viewport, and its semantics must have liveRegion.
  - Device check with TalkBack.
- Evidence: inferred from the code (layout under the keyboard); needs a device check.

**R1B-2 · Severity 2 · Two day chips apply at once; "Sin fecha" doesn't**
- Where: `App/lib/widgets/schedule_editor.dart:212-228`, the move sheet for a task that doesn't repeat, or a whole series.
- The moment: "Mañana closed it straight away. I tapped Sin fecha and… it's still open? Did it take?"
- What happens: in one row of three identical ChoiceChips, Hoy and Mañana save and close, while Sin fecha only selects and needs Listo at the bottom. That's the same component behaving two ways side by side.
- Why: consistency and standards (Nielsen 1994); the same control must behave the same (checklist F/D).
- Fix:
  - Drop `&& entry.$2 != null` at :225, so Sin fecha also applies at once when moving. The result is already undoable: `movedInbox` with Deshacer, at task_interactions.dart:83.
  - No new strings.
  - The editor and the capture result keep select-only for all three chips.
- Verify: widget test. Swipe a dated task that doesn't repeat, tap Sin fecha, and check that the sheet closes, the snackbar reads "Movida a la bandeja de entrada" with Deshacer, and Deshacer restores the date.
- Evidence: verified in code.

**R1B-3 · Severity 1 · The series help line names a control the sheet no longer has**
- Where: `seriesRescheduleHelp`, shown at `schedule_editor.dart:201-205`. ES "…Mover a la bandeja de entrada detiene la repetición." EN "…Inbox stops the repeat." CA "…Moure-la a la safata d’entrada atura la repetició."
- The moment: "Where's the inbox button?" The old sheet had a "Bandeja de entrada" chip. The shared sheet's chip says "Sin fecha".
- Why: one concept, one name (ISO 24495-1); recognition over recall (Nielsen 1994).
- Fix: name the chip the user sees.
  - EN "Changes the start of the series and resets moved or skipped dates. No date stops the repeat."
  - ES "Cambia el inicio de la serie y restablece las fechas movidas u omitidas. «Sin fecha» detiene la repetición."
  - CA "Canvia l’inici de la sèrie i restableix les dates mogudes o omeses. «Sense data» atura la repetició."
- Verify: read the catalogs, plus a widget test where Toda la serie shows text containing `noDate`.
- Evidence: verified in code.

**R1B-4 · Severity 1 · The repeat sheet's button says "Keep repeat" after "Doesn't repeat"**
- Where: `App/lib/widgets/repeat_rule_control.dart:178-180` (`keepRepeat`: EN "Keep repeat" / ES "Guardar repetición" / CA "Conserva la repetició"). TaskEditor's Repetir row now reaches it too (`task_editor.dart:857`).
- The moment (EN and CA): "I chose 'Doesn't repeat' and the button says keep repeating?"
- What happens:
  - The sheet's only confirm reads as the opposite of the choice just made.
  - The date sheet next to it confirms with Listo, so the two sheets differ.
  - Before this round, TaskEditor applied the dropdown inline, with no button.
- Why: buttons name the result (ISO 24495-1); consistency (Nielsen 1994).
- Fix: use `done` (EN "Done" / ES "Listo" / CA "Fet") and remove `keepRepeat` from all three catalogs.
- Verify: grep finds no `keepRepeat`; a widget test sees Listo in the repeat sheet.
- Evidence: verified in code.

### Not regressions (checked)
- In move mode, tapping the chip for the day the task is already on (for example Hoy for today's task) closes the sheet and says "Movida al <same day>". It's harmless and undoable; noted only.
- Omitir esta repetición now sits directly under the day chips (:233), closer to Mañana than before. It's undoable with Deshacer, and the code comment gives the reason (visible without scrolling). Left as is.
- The collapsed editor chip `repeatLabel(_planningTask)` (`task_editor.dart:806`) ignores interval and weekdays. That's from before this round, not caused by this change.
