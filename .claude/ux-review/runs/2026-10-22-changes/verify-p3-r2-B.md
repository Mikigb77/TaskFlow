## UX verify — run 2026-10-22-changes, plan 3 round 2, area B (P264) — 2026-10-23

**Verdict:** Both findings fixed. No regressions in the changed lines or the flows they touch. TalkBack on a device still to be checked.

### UX-2025 · fixed (device check open)
- `App/lib/widgets/capture_review_editor.dart:409-441`: the Semantics now has `button: line.onTap != null` and `enabled: line.onTap == null ? null : widget.enabled`. `onTap`, `excludeSemantics`, the ListTile, its key and the chevron rule are unchanged, and the doc comment (:406-411) says what TalkBack reads.
- A line with no tap (Marta's «Recordatorio para Marta») is plain text with no enabled state, so TalkBack can't say «desactivado». A line with a tap stays a button and reads as disabled while the result saves, like the date line (:381-385, UX-462).
- Tests, group `P264 · UX-2025, UX-2034` (`App/test/reminder_plan_sheet_test.dart:7836`):
  - :8043: Marta's line has `hasEnabledState: false`.
  - :8072-8101: the personal line is enabled, then disabled with no tap while saving; Marta's line is unchanged throughout.
- The tester reports these tests pass.
- Evidence: verified in code and widget test. The emulator or phone TalkBack check is still open.

### UX-2034 · fixed
- `App/lib/widgets/reminder_control.dart:624-652`: a line with no tap now draws a `Chip` with `side: BorderSide.none` and `backgroundColor: Colors.transparent`, inside a `Theme` that clears `canvasColor`. The label is in `onSurface`.
- Kept unchanged: the key, `avatarBoxConstraints`, the bell, and the label's ConstrainedBox with `maxLines: 10`.
- The `ActionChip` branch for lines with a tap is unchanged.
- Renders (12:43, newer than every file under App/lib and App/assets):
  - `reminders/task-line.given-to-someone.es.light.1x`: «Recordatorio para Ana» has a bell, no outline and no fill. «Matemáticas» and «Ana» above keep their outlines.
  - `ca.light.2x`: «Recordatori per / a Ana» wraps onto two lines but is whole, with no outline.
- AUDIT.md, section `reminders/task-line · given-to-someone`:
  - TalkBack reads item 13 as plain text «Recordatorio para Ana», with no tap.
  - Nothing is clipped, and the line isn't in the target table.
- Tests at :7940-7966 check: no fill, label in `onSurface` at alpha 1, one bell, and not a button, no tap, no enabled state.
- The archived-project chip and the unchanged ActionChips (a «Todos» task; a muted project) are covered by the tester's other P264 tests.

### Regressions
None.
- Clearing `canvasColor` is scoped to the no-tap Chip.
- The Chip draws in the same place, so the words stay aligned with where the tappable chip's words sit.
- The capture card's no-tap row loses only its button role. Its look is unchanged.

### For the main session
- Device check (emulator or phone, say which): with TalkBack, the capture card's collapsed row for a draft given to Marta, and that task's page, should read «Recordatorio para Marta» as text, with no «botón» and no «desactivado».
