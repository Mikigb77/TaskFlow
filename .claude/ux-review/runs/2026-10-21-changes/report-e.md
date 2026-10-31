# UX loop report: run 2026-10-21-changes, batch e (close, 2026-10-22)

**Verdict:** Everything in this batch is fixed. The four findings escalated in batch d (UX-1715, UX-1702, UX-1716, UX-1720) finally ran in the main checkout and all passed review. The two findings about overdue tasks moved by days (UX-1721, UX-1723) are verified. The one regression this batch caused (R1A-1, now UX-1725) was fixed in round 2. Nothing is open or escalated, and no check needs a phone.

## Verified (the reviewer said "fixed", and every test passed)
| ID | Sev | Title | Package · round | Evidence |
|---|---|---|---|---|
| UX-1720 | S1 | Voz privacy line says «extraction» and only tasks | P236 · r1 | The second sentence of `capturePrivacy` is replaced in EN, ES and CA. The render settings/voice.on-phone.es.light.1x shows «Para añadir, buscar o cambiar tareas, tus palabras van por internet a la IA de Google.» |
| UX-1715 | S2 | A deadline-only task moved «a mañana» still reads overdue | P235 · r1 | D1 is built. `planUpdate` in `App/lib/services/command_plan.dart:224-273` moves the deadline and sets no planned day, and `movesDeadline` is set. The card reads «Cambiar fecha» and the confirmation reads «Movida al …». In applied.bulk-applied the task reads «Vence vie, 23 de oct» with no «vencida». This also covers UX-1709's fifth item. |
| UX-1702 | S2 | «Todas las de hoy» skips the overdue tasks Today lists | P235 · r1 | Its last piece (task B moved by its deadline) now works through UX-1715's rule. The batch d test that used to fail now passes. |
| UX-1716 | S2 | A set's target day can't be fixed by touch | P235 · r1 | On a deadline-only one-task card, the chip stays a «Fecha límite» line after you pick a day. Seen in render cards.change-deadline-only. |
| UX-1721 | S1 | Overdue tasks moved by days from «hoy» stay overdue | P239 + P235 · r1 | D4 (`_fromToday`) is tested in both directions, including a deadline-only task that was overdue for 2 days. |
| UX-1723 | S1 | Overdue task moved to an earlier day lands on Today | P239 · r1 | `overdueIds` (`App/lib/screens/voice_task_screen.dart:3662-3668`) skips views that carry `date` or `shift_days`. Changes made in place and completions still land on Today. |
| UX-1725 | S2 | Deadline-only row says «Sin fecha» beside its «Vence» line | P240 · r2 | This is regression R1A-1 from P235. `_dateLine` (`App/lib/widgets/task_tile.dart:47-50`) now shows «Sin fecha» only when the task has no deadline either. In applied.bulk-applied.es.light.1x the gas bill reads only «Vence vie, 23 de oct». TalkBack (AUDIT item 27) no longer says «Sin fecha». The Sin fecha page is unchanged. |

## Locked by tests
Every verified finding in this batch has at least one test:
- **UX-1720:** `App/test/localization_catalog_test.dart:1768`, `:1824`; `App/test/voice_settings_test.dart:1214`, `:1227` (ES and CA at 2× on 320×640).
- **UX-1715:** `App/test/bulk_voice_commands_test.dart:5687-6032`.
- **UX-1702:** `App/test/bulk_voice_commands_test.dart:4544`, `:4634`.
- **UX-1716:** `App/test/bulk_voice_commands_test.dart:5143`, `:5830`, `:5869`.
- **UX-1721:** `App/test/bulk_voice_commands_test.dart:6079` onward.
- **UX-1723:** `App/test/bulk_voice_commands_test.dart:6154`, `:6193`, `:6225`, `:6253`, `:4544`.
- **UX-1725:** `App/test/task_rows_test.dart` and `App/test/bulk_voice_commands_test.dart`. All 8 acceptance checks have tests: ES at 1× and 2×, EN and CA, TalkBack, both cases on the Tareas root, and the unchanged UX-1418 / UX-1512 Sin fecha page test.

## Still open
None from this batch.

## Escalations
None. UX-1715, UX-1702, UX-1716 and UX-1720 had been escalated in batch d after two infrastructure failures (their worktrees were on `main`). This time they ran in the main checkout and are now verified.

## Checks for the owner
No phone check is needed for this batch. Two checks are left that the tests don't cover:
- **UX-1720:** a native speaker should read the Catalan `capturePrivacy` sentence. This doesn't need a phone.
- **UX-1721:** on staging, check that the real model returns `shift_days` +1 / −1 for «pasa / adelanta todo lo de hoy un día». The reviewer left this for the main session.

Existing phone checks related to this work are unchanged: UX-1722 (is the ▾ easy to see at the largest font?) and U4.

## Files changed
- `App/lib/l10n/app_en.arb`, `App/lib/l10n/app_es.arb`, `App/lib/l10n/app_ca.arb` (P236)
- `App/lib/services/command_plan.dart` (P235)
- `App/lib/screens/voice_task_screen.dart` (P235, P239)
- `App/lib/widgets/task_tile.dart` (P240)
- `App/test/localization_catalog_test.dart`, `App/test/voice_settings_test.dart` (P236)
- `App/test/bulk_voice_commands_test.dart` (P235, P239, P240)
- `App/test/ux_previews/commands_previews.dart` (P235's change-deadline-only preview; P240's applied.bulk-applied description)
- `App/test/task_rows_test.dart` (P240)
- `.claude/ux-review/ISSUES.md` (this close)

## Rounds
- **Round 1** (`plan-e.json`): P236, P235 and P239, all done, in waves 2 and 1. **Tests passed.** Tests prove UX-1720, UX-1715, UX-1702, UX-1716, UX-1721 and UX-1723. Review (`verify-e-r1-A.md`): all six fixed. One regression, R1A-1 (S2: a deadline-only task moved by voice lands with a row reading «Sin fecha»), became UX-1725.
- **Round 2** (`plan-e-r2.json`): P240, done, in wave 1. **Tests passed.** Tests prove UX-1725. Review (`verify-e-r2-A.md`): fixed, no regressions. A deadline-only row whose deadline has passed now reads only «Vence … · Fecha límite vencida», which is the intended subtraction.

## Ledger notes
- In `.claude/ux-review/ISSUES.md`, the seven lines moved to **Verified**: UX-1725, UX-1721 and UX-1723 from Open, and UX-1715, UX-1702, UX-1716 and UX-1720 from Escalated. Each line keeps its history after "History:". The Open and Escalated sections are now empty.
- The main path changed for UX-1715 (`command_plan.dart:224`) and UX-1723 (`voice_task_screen.dart:3662`).
- Two lines were not edited because they aren't in this batch, but the main session may want to annotate them:
  - **UX-1709** (already verified): its fifth item, a new time for deadline-only tasks, is now built by P235.
  - **U4** (device check): UX-1716's deadline-only chip is now complete.
