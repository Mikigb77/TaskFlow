---
name: review-techniques
description: Evidence techniques that worked in TaskFlow verify rounds without running Flutter — Manrope text-width model, render cropping, prefix tracing for search, Flutter 3.44.5 NavigationBar/tooltip facts
metadata:
  type: reference
---

Ways to turn "needs a device check" into measured evidence, proven in the 2026-10-13-app run (areas C and D).

**Why:** inside the UX loop I can't run Flutter, and most "does it fit / does it match" questions can still be answered precisely.
**How to apply:** use these before writing "inferred, needs a device check".

## Does this label fit at 320 dp?
- `App/assets/fonts/Manrope.ttf` is a variable font (weight axis 200–800, default 200).
- In a scratchpad Python script: Pillow `ImageFont.truetype(...)`, `set_variation_by_axes([weight])`, `getlength(text)` at the drawn px size, plus letterSpacing × character count. Matched renders within ~1 dp (e.g. "Calendario" w800 at 390 dp, 1.0×: 64.9 modelled vs 64.0 ink).
- Drawn px = sp × min(text scale, cap). A 4-tab bar at 320 dp gives 80 dp per tab.
- Preview tests that load Manrope via `FontLoader` (as `App/test/calendar_feedback_test.dart` does) can assert real label sizes; the default flutter_test font can't. So text-fit checks are usually testable — say so in "Verify".

## Renders
- Crop and enlarge the region in question from `App/build/*.png` and measure ink width and pixel colours (tint edges, contrast).
- `calendar-feedback-*.png` is the only current render showing the tab bar; nothing current shows Tareas, Notas or search (as of 2026-10-13).

## Verify rounds
- First check each fix's files actually have a diff in the main checkout (`git diff HEAD -- <file>`, grep for the new symbol). In run 2026-10-21-changes, five fixer worktrees were made from main instead of dev, so their fixes never landed; testers' failing tests were the first sign.
- The tester's whole-suite log is `App/build/round-check/suite.log`: read failures there instead of re-running Flutter.
- Entry-flow fixes (widget, shortcuts, share) have no preview render; they rest on code + widget tests. Walk the stack rules as sequences (VOICE→TEXT→VOICE, recorded vs empty, free 0 left vs Pro) — regressions there came from state combinations, not single taps.
- Check an acceptance check's premise against a render before judging: P317 assumed the reminder chip fits one line at ES 1×; the render showed it already wraps (→ UX-2648).
- AUDIT.md contrast flags on list rows can be histogram artefacts (avatars, ✓ icons): crop and measure the text ink itself before reporting (P316: «Paul» measured 14.46:1).
- With `textWidthBasis: longestLine`, a wrapped line's trailing space may hang past the box; tests comparing text width to the box must check visible characters only.
- Resume-to-today scroll (UX-1628) breaks on Calendar bottom-bar height changes: rerun `capture_landing_test.dart` UX-1628 when that height changes.

## Search changes
- Re-implement the matcher as a script and run every prefix of real words (Catalan l·l words in all three spellings, accented Spanish) against stored forms; diff old vs new matcher over all pairs to prove "no lost matches".

## Flutter 3.44.5 facts worth remembering
- NavigationBar: fixed-height row of `Expanded` tabs; labels laid out with loose constraints (single long words wrap mid-word); labels capped at 1.3×; the bar's own `labelTextStyle` beats the theme; tooltips wrap each destination and follow the full text scale (docs say so).
- Tooltips are 14 sp on Android, kept 10 dp from screen edges, excluded from semantics in NavigationBar.
- OverlayPortal children inherit the MediaQuery from the portal's place in the tree.
- A snackbar with an action never times out unless `persist: false` (see [[ui-patterns]]).
- iOS text fields default to smart quotes (`'` → `’`).

Related: [[recurring-problems]], [[ui-patterns]].

## Workflow quirks (run 2026-11-04-screens)
- A verify step can be re-dispatched after its worktree was merged and removed: check the run's `merges.jsonl` and `git worktree list`, then verify read-only against the main checkout (`git diff HEAD -- <file>`). The tester's "infrastructure" n/a there is the missing worktree, not a failed fix.
- Run paths in the task text may carry the repo root twice (`/home/claude/TaskFlow//home/claude/TaskFlow/...`); use the single root.
- Riverpod 3: a `ref.listen` in the shell's build keeps a keep-alive provider live under pushed pages; a `ref.watch` in a hidden (offstage) widget is paused.
