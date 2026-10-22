## UX verify — run 2026-10-21-changes, round 1, area A (P231–P234) — 2026-10-22
**Verdict:** Don't ship this round as is — P231 (D1) and P234 never landed (worktree based on 50afe7a), so UX-1715 and UX-1720 are untouched and UX-1702 / UX-1716 are each one check short. P232 and P233 themselves are sound.
**Evidence level:** code (`git diff HEAD`), current renders in `App/build/ux/commands/` (03:48, 2026-10-22, newer than every changed lib file), AUDIT.md, and the testers' widget results. No device.

### Results
- **UX-1715 · not fixed.** `App/lib/services/command_plan.dart` has no diff; `movesDeadline` exists nowhere in App/lib or App/test. A voice «a mañana» on a deadline-only task still gives it a planned day and leaves the deadline overdue.
- **UX-1720 · not fixed.** `capturePrivacy` still reads «La extracción de tareas con IA necesita internet y envía tus palabras a Google.» (`App/lib/l10n/app_es.arb:306`; EN `app_en.arb:523`, CA `app_ca.arb:285`). There is no `@capturePrivacy` description.
- **UX-1702 · partly.** The «hoy» rule is built as D2 asks:
  - `TaskMatcher.bulk` checks `hoy` (status open, not undated, from = to = today, `now` from Calendar's clock) at `task_matcher.dart:353-357`. It takes `overdueOn(today)` tasks first, oldest first (`:443-451`). A missed repetition joins only when completing (`:389-392`). Otherwise the series is counted once in `repeatingTasks` (`:393`).
  - The rows read «mar, 20 de oct · Atrasada» and «Vence mié, 21 de oct · Atrasada», ticked (`capture_command_cards.dart` `_taskDetails`; render `cards.bulk-today-overdue.es.light.1x`). ES and CA at 2× wrap whole.
  - After the tap, the app lands on Today with no «Atrasadas» and shows «6 tareas completadas» (`voice_task_screen.dart` `onToday`; render `applied.bulk-today-overdue-applied.es.light.1x`).
  - D4 (answered 2026-10-22) is built: `_fromToday` in `bulk_plan.dart`.
  - Missing: «B by its deadline» on «Pasa todo lo de hoy a mañana». It depends on P231 and fails the test.
- **UX-1716 · partly.** The chip is in place on both cards:
  - It is an ActionChip with tooltip «Elegir día», 48 dp tall, and is disabled while the card applies.
  - The sheet passes `noDate: false`, so «Sin fecha» is gone (render `cards.bulk-move-pick-day`).
  - The live count, «Ya están así.» with the chip under it, and no chip on move by days, completion, delete, assignment or other changes all pass.
  - TalkBack reads «Mover 4 tareas a mañana, vie 23», then the button «mañana, vie 23» (AUDIT, `commands/cards · bulk-move`).
  - The one-task card reads «Fecha y hora: de … a …», then the chip (AUDIT, `commands/cards · change`).
  - The Catalog check passes: the lead plus the day equals `commandBulkMoveTo`.
  - Missing: the deadline-only one-task check. It needs P231.
  - Related, until P231 merges: on a deadline-only task moved *by days*, the chip sits on the «Fecha límite» line. Picking a day there turns the change into `date`, which today gives the task a planned day, so the card flips to «Fecha y hora: Sin fecha → …». This resolves with P231. Recheck it after the merge.

### Regressions (only in the changed files)
- **R1A-1 · S1 · The ▾ on the heading chip barely shows at 2×.**
  - Where: `capture_command_cards.dart` `_MoveDayChip`, `Icon(Icons.arrow_drop_down_rounded, size: 18)`.
  - What happens: the label uses titleMedium (set card) or bodyLarge (one-task card) and scales to 2×, but the ▾ stays 18 dp. In `cards.bulk-move.es.light.2x` and `cards.change.es.light.2x`, it is a speck beside the two-line label. That ▾ is the chip's main cue that it can be tapped (Norman, signifiers).
  - Fix: size the icon with the text, e.g. `MediaQuery.textScalerOf(context).scale(18)`, capped at about 28. Apply the same to the project and person chips for consistency.
  - Verify: in the es 2× renders, the ▾ is about as tall as the label's x-height.
- **R1A-2 · S1 · An overdue task moved to a past day lands on Today.**
  - Where: `voice_task_screen.dart` `onToday`, applied to `landed`.
  - What happens: any marked item whose landing day is before today is mapped to today, even when it was *moved* there. Take «adelanta todo lo de hoy un día»: the overdue items now count from today (D4), so they go to yesterday, yet landing treats them as today. Calendar then lands on yesterday and the message adds «también en otro día» for a day where nothing is. The brief: «One moved to a day lands there, as now.» This is rare.
  - Fix: map to today only when the item's day did not change (completed, or changed in place). That is, apply `onToday` only when `landing(after) == landing(before)`.
  - Verify: a widget test of a «hoy» set with one overdue task, shifted −1 day, lands on yesterday with no «también».

### Notes, not regressions
- The one-task chip's label carries the time («jue, 29 de oct · 10:00 ▾»), but the sheet changes only the day. This follows the brief. The sheet's title «Elegir día» says so. Watch on the phone whether people tap it to fix a misheard time.
- `_moveDay` still reads `DateTime.now()`, not Calendar's clock, as before. The two only differ in tests.

### For the main session
Recreate the P231 and P234 worktrees from `dev` and re-dispatch them. Then re-run UX-1702's «B by its deadline» check and UX-1716's deadline-only check, and recheck the chip on a deadline-only shift-by-days card.
