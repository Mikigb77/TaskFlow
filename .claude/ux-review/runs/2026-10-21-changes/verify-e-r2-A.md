# Verify — run 2026-10-21-changes, round 2 (e), area A — 2026-10-22

Scope: P240 (UX-1725). Changed files: App/lib/widgets/task_tile.dart, App/test/ux_previews/commands_previews.dart (diff against HEAD; the `change-deadline-only` preview in that diff is round 1's P235 work, not P240).

## UX-1725 · fixed

- Code: `App/lib/widgets/task_tile.dart:47-50` now reads `if (date == null) { return showUndated && task.deadline == null ? context.l10n.noDate : null; }`, exactly the brief's change. The deadline line (`:104-109`, `taskDeadlineLabel`) is untouched and is shown whenever `task.deadline != null`, so every row that loses «Sin fecha» shows «Vence …» instead. `LandedTaskTile` (`:364-398`) delegates to `TaskTile`, so the lit rows after a voice move get the same rule. The only `showUndated: false` caller is still the Sin fecha page (`App/lib/screens/home_screen.dart:771`). Doc comment at `:39` updated as briefed.
- Render (fresh: 2026-10-22 06:02; no file under App/lib is newer): `App/build/ux/commands/applied.bulk-applied.es.light.1x.png` shows «Pagar la factura del gas» reading only «Vence vie, 23 de oct» + «Prioridad Media», no clock line and no «Sin fecha», right above «4 tareas movidas al vie, 23 de oct · Deshacer». The first words of the row's detail line now agree with the confirmation.
- INDEX.md line 287 describes it accurately («reading only «Vence <tomorrow>», with no «Sin fecha» …»).
- TalkBack (AUDIT.md, «commands/applied · bulk-applied», item 27): «Pagar la factura del gas Vence vie, 23 de oct Prioridad Media» — no «Sin fecha».
- Tests (tester's report): the 8 acceptance checks pass, including ES 1×/2×, EN/CA, TalkBack, Tareas root (deadline-only loses «Sin fecha», no-date-no-deadline keeps it) and the unchanged UX-1418 / UX-1512 Sin fecha page test.

## Regressions

None found in the changed files or the flows they touch (Calendar day list, lit landing rows, Tareas root, project pages, timeline rows via TaskTile).
- A deadline-only row with a passed deadline now reads only «Vence … · Fecha límite vencida» in the error colour; before it also carried «Sin fecha». That's the intended subtraction, not a loss.
- A row with neither date nor deadline still says «Sin fecha» everywhere it did; the Sin fecha page still shows none.
- `applied.bulk-shift-applied.ca.light.2x.png` (fresh) doesn't show the deadline-only row on its landing day, so it neither confirms nor contradicts; code and tests cover CA.

Evidence level: code + current widget-test renders + AUDIT semantics. No device check was asked for.
