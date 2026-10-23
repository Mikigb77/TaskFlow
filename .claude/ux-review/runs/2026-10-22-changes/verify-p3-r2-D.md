## UX verify — run 2026-10-22-changes, plan 3 round 2, area D (P265) — 2026-10-23
**Verdict:** Ship. UX-2035 is fixed; no regressions from this change.
**Walked:** shared «Todos» task → detail → reminder chip → sheet, opened scrolled to a plan (ES 2×, CA 2×) and at its top (ES 1×); personal task sheet (UX-1904). Newcomer and TalkBack lenses.

### UX-2035 · fixed
- Code: `App/lib/widgets/reminder_plan_sheet.dart`, end of `build`, `widget.shared` branch: `title`, `const _JustYou()`, then `const Divider(height: 1, key: ValueKey('reminder-sheet-header-edge'))`, then `Flexible(child: choices(withTitle: false))`. The comment above the branch names UX-2035. The personal branch is `choices(withTitle: true)` alone, no new line. The plan section's `Divider(height: 17)`, `_JustYou`'s padding and key, and the `ensureVisible` logic are unchanged. No ARB change.
- Renders (12:43, newer than the code at 12:36):
  - `App/build/ux/reminders/sheet.shared.es.light.2x.png`: a thin line sits right under «para ti.», and «Hasta la fecha límite» starts directly under it. The cut is now visible as an edge: the list reads as scrolled.
  - `sheet.shared.es.light.1x.png`: «Recordatorio», «Estos avisos son solo para ti.», the line, then «Desactivado». At the top it reads as the header's edge.
  - `sheet.shared.ca.light.2x.png`: the line under «només per a tu.», then «Fins al termini».
- Tests: group 'P265 · UX-2035' (`App/test/reminder_plan_sheet_test.dart:8291`) covers all five acceptance checks (ES/CA 2× edge within 8 dp of the note and above every hit-testable row; 200 dp scroll leaves header in place; 1× order; personal task has no Divider). Tester reports pass. I didn't run Flutter or analyze.
- TalkBack (AUDIT, es 1×): order unchanged — title, note, then the rows; a Divider isn't read.

### Regressions
None.

### Notes (not regressions)
- CA 2×, the tester's point: the sheet opens with the header edge and, about 22 dp lower, the plan section's own `Divider(height: 17)`. Two thin lines with a blank strip between them. Judged acceptable, severity below 1: the lower line is the list's own divider between the single reminder and the plans, and seeing it just under the edge actually helps show that rows sit above. Making it go away would need `ensureVisible` to align past the divider (more logic for a cosmetic gain). Subtract first: leave it.
- Pre-existing since P261 (round 1), not caused by this change: in that same CA 2× state, the 22 dp strip between the two lines is the visible bottom of «Tria l'hora de l'avís», so AUDIT measures it as a 360 × 14 dp target. A tap on what looks like blank space opens the time picker (cancellable). Low frequency; worth folding into any later pass on how `ensureVisible` aligns the plan row under the fixed header.
- Contract (Backend/docs/REMINDER_PLANS.md): nothing to change for this package.
