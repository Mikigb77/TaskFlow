# UX loop run 2026-10-21-changes, batch d: close (2026-10-22)

**Verdict:** Not done. In round 3, P238 fixed UX-1724 and UX-1722, and tests now cover both. UX-1722 still needs a phone check. The other six findings never got a fix attempt. Every package that would have fixed them (P231, P234, P235, P236 and P239) ran in a worktree made from main (50afe7a) instead of dev (1cfc622), so it stopped before editing anything or had its code reverted. Four of the six were escalated during the run. Two more (UX-1723 and UX-1721) have now also failed twice in the same way.

Evidence: code in the main checkout, the reviewer's renders and AUDIT.md (`App/build/ux/commands/`, 2026-10-22), and ux-tester's widget tests. No emulator and no physical device were used.

## Verified
- **UX-1724** · S2 · Catalan day chip at 2× loses the new time (regression R2A-1 from P237). Fixed in round 3 by P238. `DropDownMark` keeps 18 dp of the row at every size (`App/lib/widgets/app_components.dart:114-124`). `_MoveDayChip`'s label may use 3 lines (`App/lib/widgets/capture_command_cards.dart:760-769`). Render `cards.change.ca.light.2x` reads «dj., 29 d’oct.» / «· 10:00».

## Verified in code, phone check left
- **UX-1722** · S1 · The day chip's ▾ stayed 18 dp and barely showed at 2× (regression R1A-1 from P233). P237 built it in round 2 and P238 finished it in round 3. The ▾ is min(28, 18 × text scale) at all three call sites: `_MoveDayChip`, `task_list_picker.dart:301-302` and `task_assignment_picker.dart:127-128`. In the es and ca 2× renders it is clearly larger than at 1×, touches no letter, and the chip's outline holds. The acceptance item "▾ as tall as the lowercase letters" was withdrawn in round 2. The phone check decides it.

## Still open
- **UX-1723** · S1 · An overdue task moved to an earlier day lands on Today (regression R1A-2 from P232).
  - It is not fixed: P239 never ran (worktree on main, code reverted), and `App/lib/screens/voice_task_screen.dart:3656-3666` is unchanged.
  - Effect: «Adelanta todo lo de hoy un día» still lands on Today and can add a false «también».
  - It has failed twice (P235 in round 2, P239 in round 3), both times for the worktree reason. This run's escalation list doesn't include it, so it stays open, but it meets the two-failure rule: take it to the owner with UX-1715.
  - The brief stands: P239 in `plan-d-r3.json`.
- **UX-1721** · S1 · Overdue tasks moved by days from «hoy» stay overdue (D4).
  - Partly done. D4 is built: `bulk_plan.dart:266-278` `_fromToday`, and `command_plan.dart:245-251` moves a deadline-only task's deadline by days.
  - The +1 direction holds when traced through the code, but no test covers it. The −1 direction lands wrong because of UX-1723.
  - It has failed twice (round 2 not fixed, round 3 partly). It closes when P239 runs with its acceptance tests.

## Escalations (to the owner)
None of these four got a fix attempt. Every try stopped because its worktree was made from main (50afe7a), not dev (1cfc622).
- **UX-1715** · S2 · A deadline-only task moved «a mañana» still reads overdue (D1).
  - Tried as P231 (round 1) and P235 (round 2). `App/lib/services/command_plan.dart` has no diff, and `movesDeadline` doesn't exist anywhere.
  - Recommendation: run P235 (in `plan-d-r2.json`, minus its UX-1723 part, which is now P239) in the main checkout. Or make `waves.py` base its worktrees on the main checkout's HEAD.
- **UX-1702** · S2 · «Todas las de hoy» skips the overdue tasks Today lists (D2).
  - D2 itself is built and shows in the renders.
  - Its last check («Pasa todo lo de hoy a mañana» moves B by its deadline) waits on P235's D1 rule. The round 1 test still fails: B gets a planned day.
  - It closes with UX-1715.
- **UX-1716** · S2 · A set's target day can't be fixed by touch (D3).
  - The chip is built on both cards: 48 dp, «Elegir día» without «Sin fecha», and a live count.
  - Its last check (the «Fecha límite» chip on a deadline-only task's card) waits on P235. The round 1 test still fails.
  - It closes with UX-1715. Once P235 lands, also recheck the chip on a deadline-only card moved by days.
- **UX-1720** · S1 · The Voz privacy line says «extraction» and mentions only tasks.
  - Tried as P234 and P236. Their worktree on main has no `App/lib/l10n/`.
  - `capturePrivacy` is unchanged in `app_en.arb:523`, `app_es.arb:306` and `app_ca.arb:285`, and all 4 tests in `App/test/voice_privacy_copy_test.dart` fail.
  - Recommendation: run P236 unchanged in the main checkout. It is three ARB sentences and one `@capturePrivacy` description, and it shares no file with P238 or P239.

**Suggested order for the next run:** P236, then P235, then P239, all in the main checkout. They close UX-1720, UX-1715, UX-1702, UX-1716, UX-1723 and UX-1721.

## Checks for the owner's phone
- **UX-1722:** at the largest system font, is the ▾ on the day chip (voice move card and one-task change card) and on the project and person chips easy enough to see? Is it clear the chip can be tapped?
- **Watch, from the round 1 notes:** the one-task chip's label shows the time («jue, 29 de oct · 10:00 ▾»), but the sheet changes only the day. Check whether people tap it to fix a misheard time.

## Files changed
Repeated paths are listed once.
- App/lib/services/task_matcher.dart
- App/lib/services/bulk_plan.dart
- App/lib/models/capture_command.dart
- App/lib/widgets/capture_command_cards.dart
- App/lib/widgets/schedule_editor.dart
- App/lib/widgets/app_components.dart
- App/lib/widgets/task_list_picker.dart
- App/lib/widgets/task_assignment_picker.dart
- App/lib/screens/voice_task_screen.dart
- App/lib/l10n/app_en.arb, app_es.arb, app_ca.arb, and App/lib/l10n/generated/ (regenerated by flutter gen-l10n). `capturePrivacy` itself is unchanged; see UX-1720.
- App/test/bulk_voice_commands_test.dart
- App/test/voice_command_cards_test.dart
- App/test/voice_privacy_copy_test.dart (new; its 4 tests fail until P236 runs)
- App/test/project_ui_test.dart
- App/test/ux_previews/commands_previews.dart

## Verified findings that a test now protects
- **UX-1724:** `App/test/bulk_voice_commands_test.dart:5517-5572` (18 dp kept for the ▾ at 1×, 1.3× and 2×, with the triangle centred), `:5574-5606` (Catalan, all 9 months that take «de»: the whole label with «· 10:00» in at most 3 lines, no overflow) and `:5609-5640` (Spanish and English in at most 2 lines).
- **UX-1722** (device check left): `App/test/bulk_voice_commands_test.dart:5331`, `:5375` and `:5423` (at most 2 lines; the ▾ is 28 dp at 2× and 18 dp at 1×), and `App/test/project_ui_test.dart:687-860` (project and person chips).

## Rounds
- **Round 1** (`plan.json`): P232 and P233 done; P231 and P234 blocked (worktrees on main 50afe7a). Waves 2, 1, 1. Tests failed. Nothing fixed. UX-1715, UX-1720, UX-1702 and UX-1716 not yet fixed. New regressions: R1A-1 (now UX-1722) and R1A-2 (now UX-1723). Verification: `verify-d-r1-A.md`.
- **Round 2** (`plan-d-r2.json`): P237 done; P235 and P236 blocked (worktrees on main). Waves 2, 1. Tests failed. Nothing fixed. UX-1715, UX-1702, UX-1716, UX-1721, UX-1723, UX-1720 and UX-1722 not yet fixed. New regression: R2A-1 (now UX-1724). Verification: `verify-d-r2-A.md`.
- **Round 3** (`plan-d-r3.json`): P238 done; P239 blocked (worktree on main, code reverted). Wave 2. Tests failed, because the UX-1702, UX-1716 and UX-1720 tests still fail; the UX-1724 and UX-1722 tests pass. Fixed: UX-1724 and UX-1722, with UX-1722's phone check left. UX-1723, UX-1721, UX-1702 and UX-1716 not yet fixed. No regressions. Verification: `verify-d-r3-A.md`.

## Ledger
`C:\Users\mikig\Desktop\Custom\MikiHacks\TaskFlow\TaskFlow\.claude\ux-review\ISSUES.md`:
- UX-1724 moved to Verified.
- UX-1722 moved to Device check.
- UX-1723 and UX-1721 stay in Open with round 3 notes.
- UX-1715, UX-1702, UX-1716 and UX-1720 stay in Escalated with a closing note.
