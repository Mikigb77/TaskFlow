# UX web run 2026-10-22-changes: report

**Verdict:** Both findings are fixed in English, Spanish and Catalan, and the reviewer and the tests both confirm the fixes. WEB-1102 is verified. WEB-1101 is fixed in the code and the renders but stays as a device check: the owner still has to sign off legal version 2026-10-22 (WD3), and a native speaker still has to read the Catalan. The run took one round. There were no escalations and no regressions.

## Verified
- **WEB-1102** (S2 · F): the calendar card said the app asks you once, but reminder plans ask again. WP59 removed the clause after the colon and made the colon a full stop in `src/content/site/en.ts:61`, `es.ts:61` and `ca.ts:61`. The card now ends "…TaskFlow can remind you of tasks with a date." / «TaskFlow puede recordarte las tareas con fecha.».
  - A search of `src/` finds no "asks you once", «una sola vez» or «una sola vegada».
  - The renders `home.es.mobile.light.full.png` and `home.en.desktop.light.full.png` show the card closing cleanly. Its drawing still reaches the card's bottom edge.
  - The hero's "can remind you before it" is unchanged.

## Verified in code, still open on device or by a person
- **WEB-1101** (S3 · F): the privacy policy promised the task form never reaches Google's AI. WP58 changed only the last sentence of §4's first paragraph, in `src/content/legal/en.ts:55`, `es.ts:55` and `ca.ts:55`:
  - EN "Without Pro, the task form never sends anything to the AI."
  - ES «Sin Pro, el formulario de tareas nunca envía nada a la IA.»
  - CA «Sense Pro, el formulari de tasques no envia mai res a la IA.»
  - The legal version is now 2026-10-22, in `src/content/legal/company.json:10` and `docs/LEGAL_RELEASE.md:3` ("In force since 22 October 2026"). No "21 October" date is left in `src/` or `docs/`.
  - It is true of the app today. Without Pro, the reminder sheet's own-words row opens the Pro screen (`App/lib/widgets/reminder_plan_sheet.dart:476`). The only AI call, `ai/reminder-plan/` (`:219`), is behind Pro.
  - Its ledger line is `device-check` for the two items listed under checks below.

## Still open
- Nothing from this run. WEB-801 was already open before the run, and this run didn't touch it.

## Escalations
None.

## Checks for a real device or a person
- **The owner signs off legal version 2026-10-22 and §4's narrowed sentence (WD3) (WEB-1101).** This one sign-off replaces the ones still pending for 20 October (WEB-109) and 21 October (WEB-1002).
- **A native speaker reads the new Catalan sentence (WEB-1101):** «Sense Pro, el formulari de tasques no envia mai res a la IA.»

## Ledger note for the main session
WEB-1003 is still `device-check`. The only check it had left was a native Catalan read of «t'ho pregunta una sola vegada», and WP59 removed that clause, so the check no longer applies. Its ledger line already says that once WEB-1102 is verified, the Catalan read is moot. As told, I edited only this run's lines. WEB-1003 can move to `verified` when the main session or the owner agrees.

## Files changed
None of these files holds another session's uncommitted work. TaskFlowWeb was clean at `c7cc3b4` when the run started, and the run's base (`refs/ux-web/base`, `63eb03e`) has the same tree as `HEAD`. So every change since the base is this run's, and every file can be committed whole.

Website (TaskFlowWeb):
- `docs/LEGAL_RELEASE.md`
- `src/content/legal/ca.ts`, `src/content/legal/en.ts`, `src/content/legal/es.ts`
- `src/content/legal/company.json`
- `src/content/site/ca.ts`, `src/content/site/en.ts`, `src/content/site/es.ts`
- `tests/legal.spec.ts`
- `tests/ux-web-legal.spec.ts`
- `tests/ux-web-features.spec.ts`
- `tests/support/ux-web-copy.ts`

App repo:
- `.claude/ux-web/ISSUES.md`: WEB-1101 moved to Device check, and WEB-1102 moved to Verified. This file already had uncommitted changes when the session started, from this run's plan step.
- The run folder `.claude/ux-web/runs/2026-10-22-changes/` (`plan.json`, `plan.md`, `review-F.md`, `verify-r1-F.md`, and this report once it is saved).

## What the tests now protect
- **WEB-1101:**
  - `tests/ux-web-legal.spec.ts:1624`: §4's first paragraph ends with the new sentence and still sends only the words, in each language and theme.
  - `tests/ux-web-legal.spec.ts:1643`: no legal page has a sentence beginning "The task form", «El formulario de tareas» or «El formulari de tasques».
  - `tests/ux-web-legal.spec.ts:1659`: no line in `src/content/legal/` says the task form never sends anything.
  - `tests/ux-web-legal.spec.ts:1675`: §4 still offers manual task entry and still has four paragraphs.
  - `tests/legal.spec.ts` was also updated in this run.
- **WEB-1102:**
  - `tests/ux-web-features.spec.ts:759`: the card's paragraph has no "the first time you add one" and no "it asks you once", in each theme. This test also covers WEB-1003.
  - `tests/ux-web-features.spec.ts:938`: no file under `src/` says the app asks only once.
  - `tests/ux-web-features.spec.ts:955`: the paragraph ends at "with a date." in every language.
  - `tests/ux-web-features.spec.ts:972`: /es/ and /ca/ don't scroll sideways at 320 × 800.
  - `tests/ux-web-features.spec.ts:982`: no home scrolls sideways on the phone with the browser's text doubled.
  - `tests/ux-web-features.spec.ts:998`: axe reports no violations on the three homes.
  - `tests/support/ux-web-copy.ts` was also updated in this run.

## Rounds
- **Round 1** (`plan.json`): two packages, WP58 (WEB-1101) and WP59 (WEB-1102), both done, in two waves.
  - The tests passed, and they prove both WEB-1101 and WEB-1102. No finding was left that only a device can check.
  - Verification (`verify-r1-F.md`): both findings are fixed, with no regressions and nothing left unchecked.

## Decisions still open (from this run's plan)
- WD20: should the calendar card say reminders can come more often as a task's day gets closer?
- WD21: should "reminders in your own words" join the Pro list in the FAQ?

Neither has a ledger line of its own. WEB-1102's fix works whichever way they are answered.
