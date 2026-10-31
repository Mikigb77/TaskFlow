## UX verify — run 2026-10-21-changes, round 3 (d), area A — 2026-10-22

**Verdict:** P238 is fixed: the Catalan time shows again on the day chip, and the ▾ still grows with the text. P239 never ran, so UX-1723 is still in the app and UX-1721 is only half proven.

Evidence levels: code read in the main checkout (dev 1cfc622 plus the working tree), current renders (05:03–05:04, newer than both widget files, which were saved at 05:00:28; `find -newer` lists nothing), AUDIT.md, and the tester's widget tests (all passing, rerun in the main checkout). No device.

### UX-1724 · S2 · fixed
- `App/lib/widgets/app_components.dart:114-124`: `DropDownMark` now uses `widthFactor: 18 / size`, with `heightFactor: 1`, the 28 dp cap and `Icon(arrow_drop_down_rounded, size: size)`. The doc comment says what the brief asked for: it grows to 28 dp but always takes 18 dp beside the label.
- `App/lib/widgets/capture_command_cards.dart:760-769`: `_MoveDayChip`'s label has `maxLines: 3`, and keeps `softWrap`, the ellipsis and `_frame`.
- Render `commands/cards.change.ca.light.2x.png`: the chip reads «dj., 29 d’oct.» / «· 10:00», whole and in 2 lines, with the ▾ clear of the text and the chip's outline intact. AUDIT `commands/cards · change`: 0 cut text, 0 layout errors, no target under 48 dp. The chip is 212 × 48 dp at 1×.
- Tests, `App/test/bulk_voice_commands_test.dart`:
  - `:5517-5572` measures the reserved width: 18 dp at 1×, 1.3× and 2×, while the glyph is 18, 23.4 and 28 dp. The label gets the row minus 18. The triangle is centred inside the reserved box.
  - `:5574-5606`: Catalan, for the 9 months that take «de», shows the whole label with «· 10:00» in at most 3 lines, and nothing overflows.
  - `:5609-5640`: Spanish and English stay within 2 lines.
- Acceptance 1–4: met.

### UX-1722 · S1 · fixed (device check left)
- Acceptance 5, in the renders:
  - In `cards.bulk-move.es.light.2x` and `cards.change.es.light.2x`, the ▾ is clearly larger than in `cards.change.es.light.1x`, where it is about 6 dp wide on screen.
  - It doesn't touch any letter of «mañana, vie 23» or «jue, 29 de oct · 10:00».
  - The outline holds.
  - `bulk-move.ca.light.2x` is the same.
- Acceptance 4 (2 lines, ▾ 28 dp at 2× and 18 dp at 1×): `bulk_voice_commands_test.dart:5331`, `:5375`, `:5423`.
- Acceptance 6 (project and person chips): `App/test/project_ui_test.dart:687-860` passes. The two other call sites, `task_list_picker.dart:301-302` and `task_assignment_picker.dart:127-128`, are untouched and keep their conditions.
- The withdrawn acceptance item (▾ as tall as the lowercase letters) isn't counted.
- Device check (owner): at the largest font, is the ▾ easy enough to see?

### UX-1723 · S1 · not fixed
- `App/lib/screens/voice_task_screen.dart:3656-3666` is unchanged.
  - `overdueIds` still collects every `item.overdue` of every `view.bulk`, with no check of `view.command.changes.has('date') || shiftDays != null`.
  - `onToday` still sends any of these to today when it lands before today.
- So «Adelanta todo lo de hoy un día» (D4, `shift_days: -1`) moves the overdue tasks to yesterday, yet Calendar lands on Today. The message can then add «también el …» for a day where nothing is.
- No test was written. P239 was blocked: its worktree was on main 50afe7a, and the code was reverted.
- Recommendation, the same as for P235: run it in the main checkout.

### UX-1721 · S1 · partly
- D4 is built: `App/lib/services/bulk_plan.dart:266-278` `_fromToday`, and `command_plan.dart:245-251` (a deadline-only task moved by days moves its deadline from `shown.displayDeadline`).
- Traced in code, the `+1` acceptance items should hold:
  - both tasks end on tomorrow;
  - `onToday` doesn't remap tomorrow, so Calendar lands on tomorrow;
  - a deadline-only overdue task gets its deadline on tomorrow and no planned day.
- None of this is tested. The `−1` direction lands wrong through UX-1723.
- It closes when P239 runs with its acceptance tests.

### Regressions (changed files and the flows they touch)
None from this round.
- `DropDownMark`'s glyph now draws up to 5 dp past its 18 dp box at 2×. Its visible triangle stays inside the box (test `:5560-5568`, and the renders). No chip clips it, and AUDIT shows no overflow.
- `maxLines: 3` only adds room: in the renders, the set heading's chip and the one-task chip keep 2 lines in Spanish and Catalan.
- TalkBack is unchanged: AUDIT reads `button «jue, 29 de oct · 10:00» tooltip «Elegir día»`.

Pre-existing, not caused by this round (not counted): in Catalan and Spanish at 2× the chip's label wraps before «·», so the second line starts with «· 10:00». This was already so before P237, at 192 dp.
