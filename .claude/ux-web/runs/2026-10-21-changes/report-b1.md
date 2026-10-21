# UX web run 2026-10-21-changes — report, batch b1

**Verdict:** All six findings were fixed in one round. The reviewer marked each one fixed, every test passed, and tests now cover all six. None is marked `verified` yet, because each still needs a person or a real device: a native Catalan read, the owner's sign-off on the legal version, a real phone, or TalkBack. All six are now under **Device check** in `.claude/ux-web/ISSUES.md`. There were no regressions and no escalations.

## Fixed (fixed in code, tests pass, waiting on a device check)

| ID | Sev | Area | Title | Package | Evidence |
|---|---|---|---|---|---|
| WEB-1001 | S2 | F | FAQ tells voice changes one task at a time | WP53 | `src/content/site/en.ts:104`, `es.ts:104`, `ca.ts:110`: the voice answer matches the brief word for word. It names moving, changing, completing and deleting, "even all of yesterday's at once". The longest sentence is 24 words. The app does support this (bulk voice commands, `.claude/ux-review/DECISIONS.md` 2026-10-21; `Backend/docs/VOICE_COMMANDS.md:400`). |
| WEB-1003 | S1 | F | Reminder line promises the question at the first dated task | WP53 | `src/content/site/en.ts:61`, `es.ts:61`, `ca.ts:61`: «…it asks you once.» / «te lo pregunta una sola vez.» / «t'ho pregunta una sola vegada.». The phrase "the first time you add one" no longer appears anywhere in `src/`. |
| WEB-1004 | S2 | F | Voice card omits moving or completing many tasks by voice | WP57 | `src/content/site/en.ts:71`, `es.ts:71`, `ca.ts:77`: one sentence added at the end of the card, with no quoted command; the link is unchanged. `src/styles/global.css:596-603` makes the calendar drawing reach the card's bottom edge, so WEB-705's rule still holds. |
| WEB-1005 | S1 | F | Site never names the widget, shortcut or sharing | WP57 | `src/content/site/en.ts:121-125`, `es.ts:121-125`, `ca.ts:127-131`: the FAQ has a new eighth question, using the app's own names. The app does support this (`App/android/app/src/main/res/values{,-es,-ca}/strings.xml`, `App/android/app/src/main/AndroidManifest.xml:46-48`). |
| WEB-1002 | S2 | F | Privacy summary narrows when words go to Google | WP54 | `src/content/legal/{en,es,ca}.ts:10`, `:33`, `:55`, `:56`: summary 02, §2 and §4 now say "add, find or change tasks" and "suggested tasks and changes". The legal version is now 2026-10-21 (`src/content/legal/company.json:10`, `docs/LEGAL_RELEASE.md:3`). |
| WEB-707 | S2 | G | English demo and FAQ marked as Spanish/Catalan | WP55 | `src/components/HomePage.tsx:52`: `<VoiceDemo />` now sits directly inside the home's `<div lang={language}>`. The `lang="en"` wrapper (`display: contents`) and its "until WP26–WP29" comment are gone. `#voice` still carries `lang={language}` (`src/components/VoiceDemo.tsx:738-740`). |

## Still open, and why

None of this run's findings. The other open lines in the ledger (WEB-801, WEB-5) were not part of this batch.

## Escalations

None.

## Checks for a real device or a person

- **Native Catalan read** of the new copy:
  - the last three sentences of the WEB-1001 answer;
  - «t'ho pregunta una sola vegada» (WEB-1003);
  - «A l'aplicació, també pots moure amb la veu totes les tasques d'ahir a demà, o completar-ne moltes alhora.» (WEB-1004);
  - the eighth question and its answer (WEB-1005);
  - privacy summary 02 «…per afegir, cercar o canviar tasques.», §2 «tasques i canvis suggerits», §4 «per retornar tasques i canvis suggerits» (WEB-1002).
- **WEB-1005:** on a real Android phone, the "Dictar una tarea" widget in the widget picker, the launcher shortcut, and sharing a WhatsApp message to TaskFlow from the share sheet.
- **WEB-1002:** the owner signs off on legal version 2026-10-21 (WD3).
- **WEB-707:** TalkBack in Spanish on /es/ reads the live demo with a Spanish voice.

## Reviewer observations (no action this run)

1. **WEB-1004, edge case.** At 1440 px with the browser's text doubled, the calendar's white week panel now has about 460 px of empty space under its two events, about a third of the card. Before the fix, the same view showed a mint band of about 17%. This is what WP57's brief chose, and in a week view empty space reads as free time. If the owner finds it odd, the fix is a design change, not a copy change.
2. **Already there before this run.** The terms (`src/content/legal/en.ts:221` and the ES/CA lines) still say "optional dictation that turns what you say into tasks". That isn't false, but it's incomplete now that voice can also find and change tasks. It's a candidate for the next legal edit, which would move the version again (WD3). It's recorded in WEB-1002's line, not as a new finding.

## Files changed

**Website (TaskFlowWeb).** `refs/ux-web/base` has the same tree as HEAD (`406a115`): `git diff --stat HEAD refs/ux-web/base` is empty. So every uncommitted change below belongs to this run, and **none of these files holds another session's uncommitted work**. The main session can commit all of them.
- `src/content/site/en.ts`, `src/content/site/es.ts`, `src/content/site/ca.ts` (WP53, WP57)
- `src/styles/global.css` (WP57)
- `src/components/HomePage.tsx` (WP55)
- `src/content/legal/en.ts`, `src/content/legal/es.ts`, `src/content/legal/ca.ts`, `src/content/legal/company.json`, `docs/LEGAL_RELEASE.md` (WP54)
- Tests: `tests/support/ux-web-copy.ts`, `tests/ux-web-features.spec.ts`, `tests/ux-web-global.spec.ts`, `tests/ux-web-legal.spec.ts`, `tests/legal.spec.ts`

**App repo (the loop's records).**
- `.claude/ux-web/ISSUES.md`: WEB-1001, WEB-1002, WEB-1003, WEB-1004, WEB-1005 and WEB-707 moved from Open to Device check. This file already had other uncommitted edits before this close step.
- `.claude/ux-web/runs/2026-10-21-changes/`: `plan.json`, `plan.md`, `review-F.md`, `verify-b1-r1-F.md`, `verify-b1-r1-G.md`, plus this report once the main session saves it as `report-b1.md`.

## Tests covering each fixed finding

- **WEB-1001:** `tests/ux-web-features.spec.ts:734`, `:783` (axe with the answer open), `:799` (sentence length), `:826` (old wording gone); copy pinned in `tests/support/ux-web-copy.ts`.
- **WEB-1003:** `tests/ux-web-features.spec.ts:749`, `:826`.
- **WEB-1004:** `tests/ux-web-features.spec.ts:761`, `:812`, `:826`, `:861` (the drawing ends on the card's bottom edge at 1440, 1000 and 720 px, and at 1440 px with text doubled).
- **WEB-1005:** `tests/ux-web-features.spec.ts:783`, `:812`, `:839`, `:892`.
- **WEB-1002:** `tests/ux-web-legal.spec.ts:1487`, `:1502`, `:1523`, `:1537`, `:1554`, `:1568`, `:1579`; `tests/legal.spec.ts` (version line).
- **WEB-707:** `tests/ux-web-global.spec.ts:163` (rewritten), `:1301` (new: server HTML, no JavaScript); `tests/ux-web-voice.spec.ts:2176`, `:2201`, `:2240`; axe in `tests/ux-web-home.spec.ts:146`.

## Rounds

- **Round 1** (`.claude/ux-web/runs/2026-10-21-changes/plan.json`): packages WP53, WP57, WP54 and WP55 all done.
  - Tests passed, covering WEB-1001, WEB-1003, WEB-1004, WEB-1005, WEB-1002 and WEB-707. No finding could only be checked on a device, so none was left out of the tests.
  - The reviewer marked all six fixed in `verify-b1-r1-F.md` and `verify-b1-r1-G.md`.
  - No regressions, nothing left unchecked.
