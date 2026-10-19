## UX verify — run 2026-10-18-commands, b3 round 2, area B (P160) — 2026-10-19

**Verdict:** Ship. Both findings are fixed; one polish-level side effect of the year-pick fix.
**Evidence level:** code (git diff HEAD), widget tests reported by ux-tester, and current renders (form/*.png rendered 2026-10-19 04:30–04:31; no app file is newer). Flutter's own `calendar_date_picker.dart` read to confirm the year-pick path. No device.

### UX-1003 · fixed
- `App/lib/widgets/task_editor.dart:76` adds `_titleFocus`; listener at :261/:340 rebuilds on focus change; disposed at :304.
- Title field :772-777: `focusNode: _titleFocus`, `minLines: 1`, `maxLines: _titleFocus.hasFocus ? 3 : null`, `keyboardType: TextInputType.text`, `textInputAction` done (task) / next (note), `maxLength: 160`, `counterText: ''` kept. Comment matches the brief.
- `_dropKeyboard()` (:344) is called on Hoy, Mañana (:1187, :1198), «Elegir día» (:325), time (:377) and removing the time (:1222), so the cap lifts exactly when the keyboard goes down.
- Tests (tester: pass): new_task_form_test.dart:1431 (≤3 lines while focused, scroll axis down, maxLines 3, not multiline keyboard, no newline on done; after Mañana maxLines null, 4 lines, whole, top ≥ 0), :1490 (maxScrollExtent 0, «Llamar» inside field and screen), :1543 (edit form 360×740, «DNI» shown, no scroll), :1475 (1× one line, unchanged).
- Renders: `App/build/ux/form/new-task.long-title.es.light.2x.png` shows the whole 8-line title «…el contrato del piso» with Hoy / Mañana / Elegir día and «Añadir al calendario» still on screen; `form/edit-task.long.es.light.2x.png` shows the whole title down to «piso» (round 1 cut it after «para renovar el»).
- Device: largest font, 360 dp, real keyboard going down after Mañana.

### UX-1224 · fixed
- `App/lib/widgets/schedule_editor.dart:131-146` `_yearGridShown()` walks `_calendarBox` for a mounted `YearPicker`; :312-331 the calendar is wrapped in `KeyedSubtree(key: _calendarBox)` keeping `ValueKey('schedule-calendar-$_day')`; in day-only mode a year pick returns without `_select`/`_done`, a day tap does `_select(day); _done();`; the full sheet keeps `_select(day)` for every change.
- Confirmed against Flutter `calendar_date_picker.dart` `_handleYearChanged`: it calls `onDateChanged` inside `setState` before the rebuild, so the `YearPicker` is still mounted; `_handleDayChanged` only runs from the day grid. A tap on the year already shown takes the same path, so it is also ignored.
- Tests (tester: pass): :1771 (next year: sheet open, day grid on that year's month, nothing applied, Hoy still selected; day 15 closes it, chip shows weekdayDate, time kept, saved dueDate correct), :1843 (same year: nothing applied), :1865 (edit form's full sheet: year pick only selects, «Añadir hora» and «Listo» present). P139's 9-days-ahead test and capture_result_exits_test still pass.
- Device: the year tap on a phone.

### Regressions (changed files only)
**R2B-1 · Severity 1 · After a year pick, a day looks chosen but isn't**
- Where: `App/lib/widgets/schedule_editor.dart:322-327`, «Elegir día» (day-only sheet), after picking a year.
- The moment: "It's marked the 19th of 2027 — is that set? Where's the OK?"
- What happens: Flutter's `_handleYearChanged` sets its internal `_selectedDate` to the same day number (or day 1 when no day was set) in the year tapped and paints it as selected. The sheet now ignores that change (correctly), but the filled circle stays, and the day-only sheet has no «Listo». If the person then closes the sheet (Cancelar or swipe), the form keeps its old day; the chip on the form shows that honestly, so nothing is lost.
- Why it fails: visibility of system status (Nielsen 1994): the sheet shows a selection that hasn't been made. It's rare (year picks are uncommon in a task app), and tapping any day, the highlighted one included, applies it, so the cost is a moment's hesitation.
- Fix: none recommended now. CalendarDatePicker has no "show this month with nothing selected" option: remounting it with `initialDate: _day` would clear the highlight but jump back to the old month, undoing the year pick. Subtract first: accept Flutter's highlight as known polish and recheck on the phone. Only if the device walk shows a real pause, consider passing `selectableDayPredicate`-free `initialDate: null` plus a remount keyed on the picked month, which needs a custom displayed-month path. No copy change.
- Verify: walkthrough on a phone; «Elegir día» → month header → 2027: check whether the highlighted day causes a pause.
- Evidence: verified in code (app and Flutter source); not visible in any render.

No other regressions found. Checked: the note editor's title (next action moves focus, the title then shows whole: intended by the brief); the edit form (no autofocus, whole title unfocused; tapping in caps it to 3 lines and keeps the caret in view, unchanged from round 1); TalkBack year selection takes the same YearPicker path; no new strings; no ARB changes in this package.

### Memory notes
- Day-only «Elegir día» sheet ignores year picks by detecting a mounted `YearPicker` under `_calendarBox`; Flutter still highlights the carried-over day after a year pick (polish, R2B-1).
- Task title: capped at 3 lines only while focused; whole when unfocused. Every new-task day/time chip drops the keyboard first.
