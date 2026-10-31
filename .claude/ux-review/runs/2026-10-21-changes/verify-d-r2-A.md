## UX verify — run 2026-10-21-changes, round 2, area A (P235, P236, P237) — 2026-10-22

**Verdict:** Not done. P235 and P236 never ran (their worktrees were on main 50afe7a), so six of the seven findings are unchanged in the main checkout (HEAD 1cfc622 plus uncommitted round-1 work). P237 is built and helps, but it cuts the time from the Catalan day chip at 2× and doesn't meet its own acceptance 4.

Evidence: code in the main checkout; the tester's test results; the commands/ and form/ renders of 2026-10-22 04:26–04:27. I checked those renders against the code: `find App/lib App/assets -newer cards.change.ca.light.2x.png` lists nothing. No device.

### Results

| ID | Result | Evidence |
|---|---|---|
| UX-1715 | not fixed | `App/lib/services/command_plan.dart` has no diff against HEAD. `planUpdate` :225-244 still builds a planned day from `changes.date` for a task that has only a deadline, and `needsDay` (:239-241) still asks «¿Qué día…?» when only a time is said. Only `shift_days` moves the deadline (:247-254). There is no `movesDeadline` anywhere in lib/, and `_onlyMoved` (`voice_task_screen.dart:378-385`) still counts a move only when there's a `schedule`. |
| UX-1702 | not fixed | Same cause. The tester's test «UX-1702: … moves B, which has only a deadline, by its deadline (P231)» fails: B gets a planned day of 2026-10-23. |
| UX-1716 | not fixed | Same cause. The test «UX-1716: one task with only a deadline … the «Fecha límite» line’s chip» fails: the card has no «Fecha límite: de … a Mañana» line. |
| UX-1721 | not fixed | Same cause: P235 never ran. `_fromToday` (P232) is still there, but with a planned day set from `date`, the rule-(3) deadline path is the only one that works. Not tested. |
| UX-1723 | not fixed | In `voice_task_screen.dart:3663-3666`, `onToday` still sends every overdue id that lands before today to today, whether or not it moved. «Adelanta todo lo de hoy un día» still lands on Today, and the message can still add «también». Not tested. |
| UX-1720 | not fixed | `capturePrivacy` is unchanged: «AI task extraction still needs the internet…» in `app_en.arb:523`, «La extracción de tareas con IA…» in `app_es.arb:306`, «L’extracció de tasques amb IA…» in `app_ca.arb:285`. `app_en.arb` has no `@capturePrivacy`. All 4 tests in `voice_privacy_copy_test.dart` fail. |
| UX-1722 | partly | `DropDownMark` (`app_components.dart:109-123`) sizes the ▾ as `min(28, textScaler.scale(18))` and is used at all three sites, each keeping its condition: `capture_command_cards.dart` `_MoveDayChip`, `task_list_picker.dart:301-302` and `task_assignment_picker.dart:127-128`. **Acceptance 1 passes** (set card: 18 / 23 / 28 dp at 1× / 1.3× / 2×, at most 2 lines, no overflow; tests pass). **Acceptance 3 passes** (project and person chips are 28 dp at 2× and 18 dp at 1×; a long name ends in «…»; the locked and unchangeable chips have no ▾). **Acceptance 2 passes in es and fails in ca**: one task at 2× on 360 dp, the chip reads «dc., 28 / d’oct. · …», so the new time is cut (R2A-1). **Acceptance 4 fails**: in `cards.bulk-move.es.light.2x.png` and `cards.change.es.light.2x.png` (2 px per dp), the visible triangle is about 10 × 5 dp, while the label's lowercase letters are about 17 dp tall. The ▾ is more visible than before, but the glyph fills only about 7.4/24 × 4.6/24 of its box. Meeting acceptance 4 needs a larger box than the 28 dp cap or a different glyph: that's for the organizer to decide (see below). The device check at the largest font is still to do. |

### Regressions (only in the changed files and their flows)

**R2A-1 · Severity 2 · Catalan day chip at 2× loses the new time**
- Where: `capture_command_cards.dart` `_MoveDayChip` (label `maxLines: 2`, ellipsis) with `app_components.dart:117-121` `DropDownMark`. One task's change card, Catalan, 2×, 360 dp.
- The moment: «Ho he canviat a dimecres… però a quina hora?» The chip shows «dc., 28 d’oct. · …» and the new time is gone, so the person can't check what they're confirming.
- What happens: at 2× the mark now takes (18 + 10/2) = 23 dp of the row, against 18 dp before. That's 5 dp less for the label. «dc., 28 d’oct.» no longer fits on the first line, it wraps after «28», and the second line runs out before «10:00». It fails in the tester's ca test. In the render (`cards.change.ca.light.2x.png`, «dj., 29 d’oct.»), the first line only just fits, so it depends on the date.
- Why it fails: Budiu & Laubheimer 2018, show the interpretation (what and when) prominently. WCAG 1.4.4 / Lens L, no loss of content at 200% text.
- Fix (subtract): in `DropDownMark`, reserve the same 18 dp as before at every size. Change `widthFactor` to `18 / size`, so the row gives the label exactly the room it had before P237. At 28 dp the visible triangle is only about 8.6 dp wide, so it still sits inside the 18 dp it reserves and doesn't touch the label. If the organizer also wants a safety net, `_MoveDayChip`'s label can take `maxLines: 3` at 2×. No copy change.
- Verify: the tester's test «UX-1722: ca at 2× on 360 dp, one task…» passes. Re-render `cards.change.ca.light.2x` and check the chip shows «· 10:00».
- Evidence: the tester's failing widget test, plus the current render.

No other regression. The ▾ keeps no semantics of its own (unchanged). Tooltips, avatars and padding are untouched. AUDIT shows no layout errors and no cut text for commands/cards · change and · bulk-move, nor for form/*. No preview shows the project or person chip at 2×; for those I rely on the passing project_ui_test checks.

### For the organizer
- **UX-1722 acceptance 4.** Either relax it to "the ▾ is visibly larger than at 1× and the chip keeps its outline", or let `DropDownMark` set its box from the label's font size, about 2.5 × fontSize, with `Align` width and height factors trimming its layout to the visible triangle. That would make the triangle about as tall as the x-height without taking more room in the row. My read: the chip's outline already says it can be tapped, so a triangle of about 10 × 5 dp at 2× is acceptable. The owner's phone check decides.
- **P235 and P236** need to run again from a worktree on dev (1cfc622), or in the main checkout. The briefs stand as written. P236 is a three-sentence ARB change plus one description.
