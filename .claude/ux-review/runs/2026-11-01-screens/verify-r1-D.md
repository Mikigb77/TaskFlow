# Verify, round 1, area D: P317 (2026-11-01)

Scope: P317's findings UX-2634 and UX-2635. Diffs: `git diff HEAD --` App/lib/widgets/task_editor.dart (only P317's label hunk; the `_markRoute` hunks are P314's, not judged here), App/lib/widgets/reminder_control.dart and App/test/reminder_plan_sheet_test.dart. Renders: form/new-task.keyboard.* (15:25) and tasks/detail.alert-passed.* (15:26), both newer than the code (15:10), so they count as evidence. Evidence level: widget tests and preview renders (linear 2×), no device.

## UX-2634: fixed
- Code: `App/lib/widgets/task_editor.dart` (~:1266-1269): the `task-save` button's label `Text` gets `textAlign: TextAlign.center` and `textWidthBasis: TextWidthBasis.longestLine`, the same pattern as UX-2608 and UX-2630. The key, icon, 60 dp height and keyboard padding are unchanged.
- Render `form/new-task.keyboard.es.light.2x`: «Añadir al / calendario» on two centred lines, with the ✓ beside them. Measured from the PNG: about 68 dp before the ✓ and about 70 dp after the longer line, the M3 icon-button padding asymmetry P304 accepted. The title field and button are above the keyboard. `.ca.light.2x`: «Afegeix al / calendari» the same.
- Tester: 4 tests pass (ES and CA at 2× with the keyboard up; ES 1× «Añadir tarea», «Añadir al calendario» and «Guardar cambios» on one line in a 60 dp button). The plan's "within 2 dp" became "the group within 2.5 dp of centre". That's acceptable, because the remainder is Flutter's own padding.

## UX-2635: fixed
- Code: `App/lib/widgets/reminder_control.dart:764-770`: the label gets `textWidthBasis: longestLine` and is centred only when `line.onTap != null` (the ActionChip). The plain information Chip stays start-aligned. The avatar box, `maxLines: 10`, the 80 dp cap, the keys and the colours are kept.
- Render `tasks/detail.alert-passed.ca.light.2x`: four centred lines, «Sense / recordatori: / l’hora de l’avís ja / ha passat». The bell sits beside the text, about 12 dp of padding follows the longest line, and the chip stays at the page's left. `.es.light.2x`: three centred lines, hugging. `.es.light.1x`: two centred lines (see note 1).
- Tester: 4 tests pass, including the no-tap chip staying start-aligned while it hugs, and a tap still opening the sheet.

## Regressions: none
- `reminder_plan_sheet_test.dart`: the change is a fair update. Since `longestLine`, the trailing space where a line wraps may hang past the box, and the test now checks only visible characters. The assertions about the chip's size are kept.
- No other screen uses ReminderChip (the task page only). The edit form's «Guardar cambios» and «Guardando…» share the button `Text`, and they stay on one line at 1× (tested). AUDIT.md flags no clipping or overflow for these renders.

## Notes for the organizer (not regressions)
1. At ES 1× on 360 dp, the reminder chip «Sin recordatorio: ya ha pasado la hora del aviso» wraps to two lines: the label is capped at the width less 80 dp, which comes to about 232 dp. That was already true before P317, so the acceptance check's premise ("one line at 1×") was wrong. "As before" holds, and the lines are now centred. The organizer could open a polish finding for this: shorten the copy, or loosen the 80 dp cap now that the avatar box is fixed at 20 dp.
2. At linear 2×, the ✓ on the form button and the bell on the chip stay at 16-18 dp while the text doubles, so the icon reads small beside the large text. This predates P317, and the task page's Completar and Cambiar fecha buttons do the same. Not a regression.
3. Device check for the owner (TaskFlow_Review emulator, Android 2.0 non-linear font, CA): the form's «Afegeix al calendari» and the reminder chip.
