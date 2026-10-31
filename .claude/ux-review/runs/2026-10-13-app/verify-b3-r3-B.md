# Verify — b3 round 3, area B — 2026-10-13

Scope: P64 (UX-463). Changed file: `App/lib/widgets/schedule_editor.dart`. Evidence: code + ux-tester widget tests. No preview covers the move sheet with the time on; I didn't run Flutter.

## UX-463 · fixed
- `App/lib/widgets/schedule_editor.dart:124` now reads `final valid = !_hasTime || _form.currentState!.validate();`, which is the exact fix the brief asked for.
- `_select` (:111-115) sets `_hasTime = false` inside `setState` for `Sin fecha`, so by the time `_done()` runs (:238-241), `valid` is true and the sheet pops with `ScheduleChoice(null, false, …)` on the first tap.
- `Hoy`/`Mañana` keep `_hasTime` true, so validation still runs and the hour error shows (unchanged).
- Tests: `App/test/calendar_feedback_test.dart:915` (one tap on Sin fecha → sheet gone, `Movida a la bandeja de entrada`, dueDate null, hasTime false) and `:930` (Hoy → sheet stays, `Revisa este valor` under the hour, date unchanged). Both pass, per ux-tester.
- Kept as the brief asked: `_missingDate` guard (:118-121), the `missingPeriod` unfocus+scroll, `_select`, the chips, the live-region a. m./p. m. error.

## Regressions
None. The form holds only the hour and minute fields (:302, :325), and both sit inside `if (_hasTime)`. So skipping `validate()` when `_hasTime` is false can't skip any check that was visible before. The other callers of `editSchedule` (TaskEditor, capture result, `moving == null`) only reach `_done` through `Listo`. With the time off, the result there is the same as before.
