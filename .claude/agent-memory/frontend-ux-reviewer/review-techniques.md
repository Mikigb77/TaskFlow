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

## Search changes
- Re-implement the matcher as a script and run every prefix of real words (Catalan l·l words in all three spellings, accented Spanish) against stored forms; diff old vs new matcher over all pairs to prove "no lost matches".

## Flutter 3.44.5 facts worth remembering
- NavigationBar: fixed-height row of `Expanded` tabs; labels laid out with loose constraints (single long words wrap mid-word); labels capped at 1.3×; the bar's own `labelTextStyle` beats the theme; tooltips wrap each destination and follow the full text scale (docs say so).
- Tooltips are 14 sp on Android, kept 10 dp from screen edges, excluded from semantics in NavigationBar.
- OverlayPortal children inherit the MediaQuery from the portal's place in the tree.
- A snackbar with an action never times out unless `persist: false` (see [[ui-patterns]]).
- iOS text fields default to smart quotes (`'` → `’`).

Related: [[recurring-problems]], [[ui-patterns]].
