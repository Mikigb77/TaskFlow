## UX loop 2026-10-22-changes: plan 2, close (2026-10-22)

**Verdict:** All 8 findings in plan 2 were fixed in 2 rounds, and every test passed.
- **Fully verified (5):** UX-1912, UX-2013, UX-2021, UX-2020, UX-2023.
- **Verified in code, phone check still owed (3):** UX-2001, UX-1812, UX-2014.
- **Escalated:** none.
- **Regressions:** one (R1A-1, now UX-2023). It was found in round 1 and fixed in round 2.
- **Your D8 answer from today:** it's in DECISIONS.md and in the contract (49c8eeb), but the app doesn't do it yet. UX-2022 is back to open.

### Verified
- **UX-1912** · S3 · B · Far tasks no longer get dozens of notices from one strength (P253, verify-p2-r1-B).
  - The strengths now start at most 4 weeks before the day: Suave gives at most 8 notices, Normal 15, Intenso 22. Rhythms you say or type are kept as they are.
- **UX-2013** · S2 · D · The offer stops after two «Ahora no» in a row (P255, verify-p2-r1-D).
  - The count is kept per account. «Sí» resets it. Closing with Back or the scrim leaves it as it was.
- **UX-2021** · S2 · B · While listening, «A tu manera» now shows the newest words (P256, verify-p2-r1-B).
  - The field scrolls to its end as words arrive. Render: es 2×.
- **UX-2020** · S1 · D · Spanish «a» no longer sits alone at the end of a line before «las 8» (P257, verify-p2-r1-D).
  - A non-breaking space in ES and CA. Renders: es 1×, es 2×, ca 2×.
- **UX-2023** · S1 · A · The «ponle un día» line now comes after the date's open question (P258, verify-p2-r2-A).
  - This was regression R1A-1 from P254.

### Verified in code; a phone check is still needed
- **UX-2001** · S4 · D · D1: on a timed task's own day, a plan rings at the task's usual reminder (P252, verify-p2-r1-D).
  - The notice uses the single reminder's words and has «Completar» and «Posponer 10 min».
- **UX-1812** · S2 · A · D3: a reminder said with no day is no longer dropped (P254, verify-p2-r1-A).
  - The card shows «Para recordártelo, ponle un día.» / “To remind you, give it a day.” / «Per recordar-t’ho, posa-li un dia.», and tapping it opens the date.
- **UX-2014** · S2 · D · D6: plans are personal (P256, verify-p2-r1-B).
  - A task given to someone else has no plan rows.
  - Shared tasks show «Estos avisos son solo para ti.» above Listo.
  - The offer comes for any task that rings on this phone.

### Still open
- **UX-2022** · S2 · D · D8 was answered today: a plan with a time of its own keeps that time on the task's own day.
  - The contract has it (49c8eeb), but `reminder_plans.dart:61-90` (`dayLead`) still moves every plan's notice on that day, as D1 was worded. The next run needs a package for it.
- **The single reminder («Una vez») on shared tasks is now personal too**, by your answer today (DECISIONS.md, 2026-10-23).
  - The server half is done (49c8eeb).
  - On the app side, the «Una vez» part of the reminder sheet is still one setting for the whole task. There is no ledger line or package for it yet, so the next `/ux` run should plan it together with UX-2022.
- **Not filed, seen by reviewer B and not caused by this run:** at ca 2×, the strip's end label «dt., 22 de des.» drops its final «.» onto a second line (`reminder_plan_sheet.dart:875-884`). Severity 1.

### Escalated
None.

### Checks for your phone
1. **UX-2001:** a plan on a 17:00 task rings at 16:50 with «Completar» and «Posponer 10 min». Snoozed, it comes back as «Hoy a las 17:00».
2. **UX-1812:** use a server at 0cf3431 or later.
   - Say «Llamar a mamá, recuérdamelo cada día». The card asks for a day.
   - Once the task has a day, the reminder is kept.
3. **UX-2014 / UX-2003:** use two phones on two accounts in one shared project, with a server at 0cf3431 or later.
   - A plan or «Sí» on a «Todos» task rings only the phone that set it.
   - The other member can set a plan of their own.
4. **Carried from verify-p2-r1-B:** at the largest font with a real microphone, check that «A tu manera» follows the newest words (UX-2021). The render and the test already prove this; this is the device check.

### Files changed
- **App code:**
  - `App/lib/l10n/reminder_plan_words.dart`
  - `App/lib/services/notification_service.dart`
  - `App/lib/services/reminder_copy.dart`
  - `App/lib/services/reminder_engine.dart`
  - `App/lib/services/reminder_plans.dart`
  - `App/lib/services/reminder_preferences.dart`
  - `App/lib/services/capture_store.dart`
  - `App/lib/models/reminder_plan.dart`
  - `App/lib/models/capture_session.dart`
  - `App/lib/models/task_draft.dart`
  - `App/lib/widgets/reminder_control.dart`
  - `App/lib/widgets/reminder_plan_sheet.dart`
  - `App/lib/widgets/reminder_ask_sheet.dart`
  - `App/lib/widgets/capture_review_editor.dart`
  - `App/lib/widgets/task_editor.dart`
- **Translations:** `App/lib/l10n/app_en.arb`, `app_es.arb`, `app_ca.arb`, and `App/lib/l10n/generated/` (regenerated).
- **Tests:**
  - `App/test/reminder_plan_engine_test.dart`
  - `App/test/reminder_plan_sheet_test.dart`
  - `App/test/reminder_plans_test.dart`
  - `App/test/support/reminder_fixtures.dart`
  - `App/test/ux_previews/reminders_previews.dart`
- **Records:** `.claude/ux-review/ISSUES.md`

### Which findings a test now protects
| Finding | Tests |
|---|---|
| UX-2001 | `reminder_plan_engine_test.dart:574`; `reminder_plan_sheet_test.dart:4049` (P252 · D1) |
| UX-1912 | `reminder_plans_test.dart:1076`; `reminder_plan_engine_test.dart:945`; `reminder_plan_sheet_test.dart:4216` |
| UX-1812 | `reminder_plan_sheet_test.dart:4367` (P254 · D3) |
| UX-2013 | `reminder_plan_engine_test.dart:977`; `reminder_plan_sheet_test.dart:4864` |
| UX-2014 | `reminder_plan_sheet_test.dart:5291` (P256 · D6) |
| UX-2021 | `reminder_plan_sheet_test.dart:5826` |
| UX-2020 | `reminder_plan_sheet_test.dart:5047` (P257) |
| UX-2023 | `reminder_plan_sheet_test.dart:5951` (P258) |

All test files are under `App/test/`. All 8 verified findings have a test.

### Rounds
| Round | Packages | Tests | Result |
|---|---|---|---|
| 1 (`plan.json`) | P252, P253, P254, P255, P257, P256, in 2 waves | passed | All 7 findings fixed (verify-p2-r1-A, -B, -D). One regression: R1A-1, now UX-2023 |
| 2 (`plan-p2-r2.json`) | P258 | passed | UX-2023 fixed (verify-p2-r2-A). No regressions |

### Ledger changes
- **Moved to Device check:** UX-2001, UX-1812 and UX-2014.
- **Moved to Verified:** UX-1912, UX-2013, UX-2021, UX-2020 and UX-2023.
- **Moved from Decision needed to Open:** UX-2022, as D8 is answered.
- **Updated in place:** UX-2003's phone check, which UX-2014 now sets.