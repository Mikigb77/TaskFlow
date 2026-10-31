## UX verify — run 2026-10-18-commands, b3 round 1, area B (P139, P140) — 2026-10-19

**Verdict:** 6 of 7 fixed; UX-1003 partly fixed; one regression (R1B-1, severity 2) in the new day-only sheet.
**Evidence used:** `git diff HEAD` of task_editor.dart, schedule_editor.dart, task_detail_screen.dart and the three ARB files; ux-tester's widget tests (Manrope); renders in `App/build/ux/form/` and `App/build/ux/capture/` dated 2026-10-19 03:35–03:36, which are newer than the changes. Flutter SDK source read for the calendar's year picker and the time picker's input mode.

### Findings

| ID | Result | Evidence |
|---|---|---|
| UX-1002 | fixed | `task_editor.dart` `_dropKeyboard()` (FocusManager primaryFocus unfocus) is called from Hoy, Mañana, `_pickDay`, `_pickTime` and the time chip's delete. Unfocusing the node itself leaves the scope nothing to give back when a route closes. Tests pass at 2× on 320×640 with the keyboard: Mañana › keyboard down, «Añadir hora» and «Más detalles» hit-testable; after 17:00 nothing is focused and «17:00» is hit-testable. Phone check still open. |
| UX-1003 | partly | `minLines: 1, maxLines: 3, keyboardType: text`, done action kept (task_editor.dart, title field). 1× one-line check passes; done adds no newline. **Fails:** at 2× on 320 dp the father's own 40-character sentence («Llamar al médico el viernes por la tarde») needs 4 lines, so its first line scrolls out of view. Render `edit-task.long.es.light.2x.png` (360 dp) shows the same thing on the edit form: «Pedir cita en el / ayuntamiento / para renovar el» and the rest is hidden with no sign that there's more. `new-task.long-title.es.light.2x.png` (37 characters on 360 dp) shows whole on 3 lines. |
| UX-1004 | fixed | schedule_editor.dart: new `dayOnly` → title `pickDay`, no `schedule-has-time` switch, no `schedule-done`, chips and calendar day taps call `_done()`. task_editor.dart `_pickDay()` passes `dayOnly: true` and keeps the time through `_setDay`. `_pickTime` opens `showTimePicker(initialEntryMode: input)`. The edit form and the capture result keep the full sheet (tests). In Flutter 3.44 the input mode is scrollable and clamps text scaling, so it fits at 2× with the keyboard (time_picker.dart:2544, :2689). |
| UX-1006 | fixed | task_editor.dart attach sheet: `if (!_creating)` paragraph, else a 12 dp gap. Tests: no help text on a new task; an existing task keeps it. |
| UX-1007 | fixed | task_editor.dart collapsed branch: notes (when they have text and aren't up front), files (`_files(add: false)`) and project (when chosen and not up front) are shown; reminder and repeat are not. The test adds a real file. |
| UX-1008 | fixed | task_detail_screen.dart: `mine` compares `task.createdBy` to `authProvider.account?.id`, and uses `createdByYou`. ARB: “Created by you” / «Creada por ti» / «Creada per tu». Tests in all three languages. |
| UX-1009 | fixed | ARB `freeVoiceNoticeBody` EN/ES/CA as briefed. The date comes first and the Catalan uses «El dia {date}». Render `capture/used-up-notice.notice.es.light.2x.png` shows the whole body with no overflow. Cosmetic: «El 1 / nov» splits across lines at 2×; not worth a finding. |

### UX-1003 — what's left
- **Fix:** cap the title at 3 lines only while it has the focus (keyboard up, so Hoy and Mañana stay reachable). Without the focus, remove the cap (`maxLines: null`), so the whole title shows for checking in both forms. UX-1002 now puts the keyboard down on every day and time tap, so the room is there. Track the focus with the field's FocusNode. Smallest alternative: `maxLines: 4`, which passes the 40-character check but still hides longer titles carried over from a dictation (up to 160 characters).
- **Acceptance to adjust:** at 2× on 320 dp a 40-character title shows whole once the keyboard is down. With the focus, it shows at most 3 lines, scrolling down, never sideways. The edit form's long title shows whole.

### Regressions
**R1B-1 · Severity 2 · Picking a year in «Elegir día» closes the sheet on a day nobody chose**
- Where: `App/lib/widgets/schedule_editor.dart`, the CalendarDatePicker `onDateChanged` in day-only mode (`if (widget.dayOnly) _done();`). The range is 2000–2101 (`region.dart:223-230`), so the calendar's «octubre de 2026 ▾» header opens the year grid.
- What happens: Flutter's `_handleYearChanged` (calendar_date_picker.dart:296-317) calls `onDateChanged` with the same day number in the year tapped. The day-only sheet takes that as a choice: it closes and applies the date. The newcomer, who tapped the header looking for months, lands back on the form with an unexpected day on the third chip (or with Hoy, if they tapped the current year).
- Why it fails: user control and error prevention (Nielsen 1994). An action that only meant to navigate commits a choice.
- Fix: in day-only mode, close only on a tap in the day grid. In `onDateChanged`, apply and close only when the new day is in the month that was showing before the change; a year change only moves the month shown and selects. Or give the day-only calendar a range of this year and next year (`firstDate` today − 1 year, `lastDate` today + 2 years), so the year grid is rarely needed, and still ignore year changes. No copy change.
- Verify: widget test in the day-only sheet: tap the month header, then tap 2027; the sheet stays open on that year's month view, and nothing is applied until a day is tapped.
- Evidence: inferred from the code and Flutter's source; not rendered.
