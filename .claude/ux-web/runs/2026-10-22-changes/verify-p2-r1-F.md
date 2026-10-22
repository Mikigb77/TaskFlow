## UX web verify — run 2026-10-22-changes, plan 2, round 1, area F (WP60) — 2026-10-22

**Verdict:** both findings fixed. One polish regression (S1) from the longer calendar paragraph.

### WEB-1103 · fixed
- `src/content/site/en.ts:61`, `es.ts:61`, `ca.ts:61` (run diff): only the last full stop became a comma plus the clause; the first sentence is unchanged; text matches the brief character for character in all three languages. No colon. English 36 words.
- Truth: `Backend/docs/REMINDER_PLANS.md:11` (strengths free and Pro) and `:50-56` (more often towards the day); "can" covers the no-plan cases (`:23` repeating tasks, `:69` reminders off, D6). The clause quotes no app label, number or date. The app's own idea is «Cada vez más a menudo…» (`App/lib/l10n/app_es.arb:1378`, `reminderPlanGrowing`; ca `app_ca.arb:1082` «Cada cop més sovint»), so the site's words match the app's.
- Renders (newer than the code: renders 23:12-23:13, content 22:51): crops of `home.es.mobile.light.full.png` and `home.ca.mobile.light.full.png` screens 4-5 show the new paragraph, drawing below it, card closed cleanly; `home.en.desktop-text200.light.full.png` screens 3-4 shows the English paragraph in 5 lines with the drawing below. Drawing-to-edge rests on the tester's WEB-1004 test (pass).
- Device-only: native Catalan read.

### WEB-1104 · fixed
- `src/content/site/en.ts:94`, `es.ts:94`, `ca.ts:100` (run diff): exactly the three changes the brief sets: the free-reminders sentence after "…next month."; the Pro sentence now ends at WD14's parenthesis; the last clause became its own sentence with "lets you ask for reminders in your own words" / «te deja pedir los recordatorios con tus palabras» / «et deixa demanar els recordatoris amb les teves paraules». The price sentence still ends the answer. Nothing else in the answer changed.
- Truth: `REMINDER_PLANS.md:13` and `:90-105` («A tu manera» is Pro only, 402 otherwise); `App/lib/widgets/reminder_plan_sheet.dart:454-461, 578-579` (without Pro the row opens the Pro screen); the app's Pro screen says the same thing (`App/lib/l10n/app_en.arb:3777` `billingReasonReminderPlans`). "Reminders are free too" is true of the single reminder and the strengths (`REMINDER_PLANS.md:11`). Privacy §4 already covers typed words going to the AI with Pro (`src/content/legal/en.ts:55`).
- Wording note, not a finding: the app's Spanish/Catalan Pro screen says «pide los avisos con tus palabras» / «demana els avisos…» (`app_es.arb:1408`, `app_ca.arb:1112`), while the site says «recordatorios» / «recordatoris». The app itself says «Recordatorios» in the sheet's lines (`app_es.arb:1394-1395`) and the site uses «recordatorios» throughout, so the site's word is the more consistent one; the app's D1-D7 round may still rename the Pro line. Leave as is.
- Not visible in the renders (only the first FAQ answer is rendered open); fit at 320 px and doubled text, 16 px text and axe rest on the tester's WEB-1104 tests (pass).
- Device-only: native Catalan reads of the two new sentences; Pro screen and free reminder sheet on a real phone (D7).

### Code check
- In the three content files only `features.calendar.body` and `faq.items[1].answer` changed (run diff). Hero, voice block, `closing.plans`, `meta` and the other FAQ items untouched. No file under `src/components/` or `src/styles/` changed. `git -C ../TaskFlowWeb status --porcelain` lists only this run's five files.
- The line under the demo (WD2/WD14's short wording) still omits reminders, by decision; not a regression.

### Regressions
**R1F-1 · Severity 1 · Calendar paragraph's last line is one word on phones**
- Where: `src/styles/global.css:583-589` (`.feature-card p`, no `text-wrap`), seen in `home.es.mobile.light.full.png` (screen 4-5: last line «día.») and `home.ca.mobile.light.full.png` (screen 4-5: last line «dia.»), 390 px, light.
- What happens: the longer sentence now wraps so the closing word sits alone on its own line, a widow under a five-line paragraph. Cosmetic; it doesn't block reading.
- Fix: add `text-wrap: pretty;` to `.feature-card p`, as `.closing-card > p` (`global.css:845`) and `.floating-note p` (`:534`) already have. No copy change.
- Verify: re-render `-g "home "`; in the es and ca mobile full renders the calendar card's last line holds at least two words. Re-run WEB-705/WEB-1004 card tests (line count may change by at most one).
- Evidence: seen in current renders (Chromium).
