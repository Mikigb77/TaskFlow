# UX web loop: run 2026-10-22-changes, batch p2: report

**Verdict:** All three findings are fixed. The reviewer said "fixed" in the last round that checked each one, and no test for them failed. Each still needs a person or a real phone, so all three are now under **device-check** in `.claude/ux-web/ISSUES.md`. Nothing is escalated or still open. The batch had 3 rounds (WP60, WP61, WP62), and each round's tests passed.

## Verified (now under Device check, with tests that protect them)
- **WEB-1103** · S2 · F: the calendar card now says reminders grow as the day nears.
  - **Change:** WP60 (WD20) adds this ending to the card's sentence in `src/content/site/{en,es,ca}.ts:61`:
    - EN: "…with a date, more and more often as the day gets closer."
    - ES: «…con fecha, cada vez más a menudo según se acerca el día.»
    - CA: «…amb data, cada cop més sovint a mesura que s’acosta el dia.»
  - **Why it's fixed:** verify-p2-r1-F.md says "fixed". The text matches the brief character for character. It's true of the app (`Backend/docs/REMINDER_PLANS.md:11, 50-56`) and uses the same idea as the app's own words («Cada vez más a menudo», `App/lib/l10n/app_es.arb:1378`).
  - **Still passing after the CSS change:** the card tests passed again in round 3, after WP61's CSS change.
- **WEB-1104** · S1 · F: the Pro list now includes reminders asked for in your own words.
  - **Change:** WP60 (WD21) changes the answer to "Is TaskFlow free?" (`en.ts:94`, `es.ts:94`, `ca.ts:100`):
    - it adds "Reminders are free too, even the ones that come more and more often as the day gets closer.";
    - it splits the Pro sentence and adds "…and lets you ask for reminders in your own words."
  - **Why it's fixed:** verify-p2-r1-F.md says "fixed". These are exactly the three changes the brief asked for, and they're true of the app (`REMINDER_PLANS.md:13, 90-105`; `App/lib/widgets/reminder_plan_sheet.dart:454-461`).
  - **Wording note, not a finding:** the app's Spanish and Catalan Pro screen says «avisos», while the site says «recordatorios» / «recordatoris». The site uses that word throughout, so it stays.
- **WEB-1105** · S1 · F: on phones, the calendar paragraph's last line is no longer a single word.
  - **Origin:** regression R1F-1, caused by WP60's longer sentence.
  - **Change:** WP61 adds `text-wrap: pretty;` to `.feature-card p` (`src/styles/global.css:583-584`). No copy changed.
  - **Round 2:** verify-p2-r2-F.md read it as fixed from the renders, but the tester reported no results. The workflow therefore listed it as unchecked.
  - **Round 3:** WP62 re-checked it without changing any code. verify-p2-r3-F.md says "fixed":
    - in Spanish and Catalan at 390 px, light and dark, the paragraph ends on «el día.» / «el dia.», two words;
    - the English desktop paragraph ends on a full line;
    - the drawing still reaches the card's bottom edge.
  - **Tests:** the tester's round-3 run passed this block and all the earlier tests.

## Still open
None.

## Escalations
None.

## Checks for a real device or a person
- WEB-1103: a native Catalan speaker reads «…amb data, cada cop més sovint a mesura que s’acosta el dia.»
- WEB-1104: a native Catalan speaker reads the two new sentences in the FAQ answer ("Reminders are free too…" and "…lets you ask for reminders in your own words").
- WEB-1104: on a real phone, check the Pro screen and the free reminder sheet once the owner updates RevenueCat (D7).
- WEB-1105: check the calendar card on /es/ and /ca/ with Safari on a real iPhone and Chrome on a real Android. An older Safari doesn't support `text-wrap: pretty` and falls back to normal wrapping, so the lone word may come back there. Nothing else breaks.

## Files changed
**Website (TaskFlowWeb):**
- `src/content/site/en.ts`
- `src/content/site/es.ts`
- `src/content/site/ca.ts`
- `src/styles/global.css`
- `tests/support/ux-web-copy.ts`
- `tests/ux-web-features.spec.ts`

None of these files holds another session's uncommitted work. `git status --porcelain` lists only these six files, and the uncommitted diff (since 883d4d1) contains only this batch's changes. In `global.css` that is the one added line. The main session can commit all six.

**App repo:**
- `.claude/ux-web/ISSUES.md`: WEB-1103, WEB-1104 and WEB-1105 moved from Open to Device check.
- `.claude/ux-web/runs/2026-10-22-changes/plan.json`, `plan.md`, `plan-p2-r2.json`, `plan-p2-r3.json`: this run's plan files.
- `.claude/ux-web/runs/2026-10-22-changes/verify-p2-r1-F.md`, `verify-p2-r2-F.md`, `verify-p2-r3-F.md`: this run's verify notes.

The app repo also has uncommitted changes under `App/`, `Backend/` and `.claude/ux-review/`. They belong to another session's work, not this run, so don't commit them with this batch.

## Findings protected by tests
- **WEB-1103:** `tests/ux-web-features.spec.ts:759`, `:955`, the WP60 block from `:1010`, `:1139`, and `tests/support/ux-web-copy.ts`. The WEB-705 (`:304`, `:335`, `:358`) and WEB-1004 (`:871`) card tests also cover the card.
- **WEB-1104:** `tests/ux-web-features.spec.ts:1076`, `:1106` (axe), `:1122`, `:1139`, `:1173` (320 px), `:1184` (text doubled).
- **WEB-1105:** `tests/ux-web-features.spec.ts:1199` block:
  - `:1231`: the last line has two words or more, light and dark, desktop and mobile;
  - `:1258`: `text-wrap: pretty`, 16 px, line height 1.7, widths unchanged.

## Rounds
| Round | Plan | Package | Result | Tests |
|---|---|---|---|---|
| 1 | plan.json | WP60 (WEB-1103, WEB-1104) | both fixed (verify-p2-r1-F.md); regression R1F-1 became WEB-1105 | passed; tests cover WEB-1103 and WEB-1104 |
| 2 | plan-p2-r2.json | WP61 (WEB-1105) | fixed from the renders (verify-p2-r2-F.md); unchecked, because the tester reported no results | passed, per the round summary |
| 3 | plan-p2-r3.json | WP62 (WEB-1105, re-check, no code change) | fixed (verify-p2-r3-F.md); no regressions | passed: WP61's block, WEB-705, WEB-1004, `:759`, `:955` and the WP60 block |
