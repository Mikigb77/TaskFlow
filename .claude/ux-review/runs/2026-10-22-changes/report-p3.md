# UX loop 2026-10-22-changes: plan 3 (batch p3) report, 2026-10-23

**Verdict:** Plan 3 is closed. All 12 findings were confirmed fixed and every one has a passing widget or unit test. 9 are verified. 3 are verified in code and renders but still need a phone check: UX-2022, UX-2025 and UX-2026. Nothing was escalated. Round 1 caused two regressions (R1B-1 became UX-2034, R1D-1 became UX-2035), and round 2 fixed both. The only open item is the owner's decision D9 (UX-2032). The ledger's Open section is now empty.

Evidence: code diffs, widget and unit tests (the tester reports them passing), and renders newer than the code. The reviewers did not run Flutter themselves. Nothing was checked on a device.

## Verified (the reviewer said fixed and no test failed)

| ID | Title | Package | Verify note | Locked by test |
|---|---|---|---|---|
| UX-2024 | «Recordatorio para Ana: …» showed your own reminder as Ana's | P259 (r1) | verify-p3-r1-B | `App/test/reminder_plan_sheet_test.dart:6199` (P259); `App/test/reminder_settings_test.dart:1002`, `:1040` |
| UX-2027 | Shared task: choices outside the sheet lacked «solo para ti» | P259 (r1) | verify-p3-r1-B | `App/test/reminder_plan_sheet_test.dart:6877-7060` |
| UX-2028 | An unassigned task that isn't yours showed your reminder as working | P259 (r1) | verify-p3-r1-B | `App/test/reminder_plan_sheet_test.dart:6710-6875` |
| UX-2029 | Sharing help said reminder choices are shared | P260 (r1) | verify-p3-r1-C | `App/test/sharing_ui_test.dart:1244` (P260) |
| UX-2030 | Recordatorios counted plans that don't ring on this phone | P262 (r1) | verify-p3-r1-D | `App/test/reminder_plan_sheet_test.dart:7717` (P262) |
| UX-2031 | Catalan 2×: the strip's end date wrapped its final «.» | P261 (r1) | verify-p3-r1-D | `App/test/reminder_plan_sheet_test.dart:7617` |
| UX-2033 | The first reminder question followed a task that never rings here | P263 (r1) | verify-p3-r1-D | `App/test/reminder_ask_sheet_test.dart:1109` (P263) |
| UX-2034 | Reminder chip with no tap looked like the tappable chips (R1B-1) | P264 (r2) | verify-p3-r2-B | `App/test/reminder_plan_sheet_test.dart:7836` (P264, `:8113`-`:8253`) |
| UX-2035 | The fixed sheet header had no edge over scrolled rows (R1D-1) | P265 (r2) | verify-p3-r2-D | `App/test/reminder_plan_sheet_test.dart:8291` (P265) |

## Verified in code, still needs a device (device-check)

| ID | Title | Package | Locked by test | What still needs a phone |
|---|---|---|---|---|
| UX-2022 | D1 moved a time said for the day itself (owner's D8: keep it) | P261 (r1) | `App/test/reminder_plan_engine_test.dart:1002`; `App/test/reminder_plan_sheet_test.dart:7160` | The notice actually arrives at 09:00 on the task's day |
| UX-2025 | On someone else's task, reminder choices changed nothing | P259 (r1, partly fixed), P264 (r2, fixed) | `App/test/reminder_plan_sheet_test.dart:6199`, `:7836` (`:8025`, `:8052`) | TalkBack reads Marta's line as text, with no «botón» and no «desactivado» |
| UX-2026 | Shared task: «solo para ti» missed the single reminder's rows | P261 (r1); header edge from P265 | `App/test/reminder_plan_sheet_test.dart:7405-7615`, `:7698` | TalkBack order; «A tu manera» with the keyboard open at 2× |

## Still open
- Nothing from this batch.
- **UX-2032** (S1 · C, «A reader can't choose reminders of their own») is still a decision (D9 of plan 3). It is not part of this fix run.

## Escalations
None.

## Checks for the owner's phone
Say which kind of evidence each check is: emulator or physical phone.
1. **UX-2022.** A task at 17:00 with «recuérdamelo el mismo día a las 9»: the notice rings at 09:00 on the task's day, and nothing rings at 16:50. A plan with no time of its own (Normal, or «Sí» to the offer) still rings at the task's usual reminder.
2. **UX-2025 (and UX-2034's chip).** With TalkBack on:
   - in a capture result of three, the collapsed row of a draft given to Marta;
   - that task's page.

   Both should read «Recordatorio para Marta» as plain text, with no «botón» and no «desactivado».
3. **UX-2026.** On a shared «Todos» task, open the reminder sheet:
   - TalkBack should read the title, then «Estos avisos son solo para ti.», then the rows.
   - In «A tu manera» at 2× text with the keyboard open, the field and «Listo» should still scroll into view under the fixed header (about 160 dp). No preview covers this state.

## Files changed
- App/lib/l10n/app_en.arb, app_es.arb, app_ca.arb (and the generated localizations)
- App/lib/screens/task_detail_screen.dart
- App/lib/screens/notification_settings_screen.dart
- App/lib/services/reminder_engine.dart
- App/lib/services/reminder_plans.dart
- App/lib/widgets/capture_review_editor.dart
- App/lib/widgets/reminder_control.dart
- App/lib/widgets/reminder_plan_sheet.dart
- App/lib/widgets/reminder_ask_sheet.dart
- App/lib/widgets/task_editor.dart
- App/lib/widgets/task_planning_control.dart
- App/test/reminder_plan_sheet_test.dart
- App/test/reminder_plan_engine_test.dart
- App/test/reminder_settings_test.dart
- App/test/reminder_ask_sheet_test.dart
- App/test/sharing_ui_test.dart
- App/test/ux_previews/reminders_previews.dart
- App/test/ux_previews/sharing_previews.dart
- .claude/ux-review/ISSUES.md (this close)

The file list also includes `.claude/worktrees/wf_66a46c9f-966-18/App/test/reminder_plan_sheet_test.dart`. That is a copy in a workflow worktree, not part of the change; leave it out of the commit.

## Rounds

**Round 1** (`plan.json`): P259, P260, P261, P262 and P263, run in one wave. Tests passed.
- Fixed: UX-2022, UX-2024, UX-2026, UX-2027, UX-2028, UX-2029, UX-2030, UX-2031, UX-2033.
- Partly fixed: UX-2025. Everything on screen was right, but TalkBack would still have read Marta's collapsed row as «desactivado».
- Regressions:
  - **R1B-1** became UX-2034: the chip with no tap was drawn like the tappable chips.
  - **R1D-1** became UX-2035: the fixed sheet header had no edge over the rows scrolling under it.
- Verify notes: verify-p3-r1-B, verify-p3-r1-C, verify-p3-r1-D.

**Round 2** (`plan-p3-r2.json`): P264 and P265, run in one wave. Tests passed.
- Fixed: UX-2025, UX-2034, UX-2035.
- No regressions.
- Verify notes: verify-p3-r2-B, verify-p3-r2-D.

## Notes from the reviewers (not filed)
- **Two thin lines in the sheet (UX-2035's state, CA 2×).** The new header edge and the list's own divider sit about 22 dp apart. Reviewer D judged this acceptable, below severity 1.
- **A hidden tap target in the same state (since P261).** That 22 dp strip is the visible bottom of «Tria l'hora de l'avís». AUDIT measures it as a 360×14 dp tap target, so a tap on what looks like blank space opens the time picker, which can be cancelled. It is rare. Reviewer D suggested handling it in any later pass on how `ensureVisible` places the plan row under the fixed header.
- **Muted projects behave as before.** On a project muted on this phone, a task given to someone else, or an unassigned one, still reads «Sin recordatorio: proyecto silenciado» and still has its tap. That is how it worked before P259.
- **Two "rings here" rules.** The sheet's rule and the question's rule treat a project this phone doesn't know yet differently. Each matches its brief, and a user can't notice the difference today.
- **Contract.** Backend/docs/REMINDER_PLANS.md needs no change from this batch.
