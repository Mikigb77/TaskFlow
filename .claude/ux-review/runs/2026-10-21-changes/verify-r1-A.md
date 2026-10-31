# Verify — round 1, area A — 2026-10-21

Scope: P224–P228 (UX-1701, 1703–1714). Evidence: `git diff HEAD` of the listed files, the commands previews rendered 23:11 today (no file in App/lib or App/assets is newer), AUDIT.md for the new states, and ux-tester's passing tests. Widget-test level; no device.

## Verdicts

| ID | Result | Evidence |
|---|---|---|
| UX-1701 | fixed | `_taskDetails` (capture_command_cards.dart ~1059-1083) shared by `_FoundRow` and the set row; the `target.status != 'completed'` special case is gone; set titles struck in onSurfaceVariant when done (~2072-2080). Render cards.bulk-delete es 1×/2×: struck titles, «… · Completada»; cards.bulk-left-out es 1×: «vie, 23 de oct · 10:00 · Matemáticas · Yo». AUDIT bulk-delete: checkbox labels carry «Completada». ca 2× rows wrap in full. |
| UX-1704 | fixed | voice_task_screen.dart `_firstOpen` (~2693): `&& view.bulk == null`. Render cards.bulk-delete.es.light.2x opens at «Eliminar 3 tareas» with its ✕. See R1A-2 for the mixed-result side effect. |
| UX-1706 | fixed | `BulkPlan.repeatingTasks/unassignableTasks/noDayTasks` (bulk_plan.dart), `TaskMatcher.bulk` returns `repeatingTasks`; `_bulkLeftOut` names a lone task. ARB =1 cases match the brief in EN/ES/CA. Render bulk-left-out: «Natación se repite: no cambia · 2 tareas no se pueden asignar a Paul». |
| UX-1712 | fixed | `DateFormat('E d')` in `bulkHeading`. Render bulk-move es 2×: «mañana, / jue 22». |
| UX-1713 | fixed | ARB copy exact in all three (es/ca/en). Tested. |
| UX-1705 | fixed | `asWritten` excludes `complete` and asking cards; `CompleteCommandCard` not-found uses `Icons.search_rounded`. Render cards.complete-not-found: search icon, Cerrar + Volver a decirlo, no Guardar como tarea. |
| UX-1708 | fixed | `CommandTarget.projectCandidates` read/written (capture_command.dart), `find` reads them; `resolveCommand` → `_projectChoices`/`withProject`; `_askingProject` + `_projectQuestion` chips; asking counts as blocking, not notFound. Render bulk-ambiguous-project es 1×/2×: «Tareas de «mates»», «¿Qué proyecto?», two 48 dp chips 8 dp apart, button disabled «Revisa los datos de arriba». Copy exact. |
| UX-1703 | fixed | `commandTasksMovedTo` when all moved tasks land on one day; `otherDays` → `captureAlsoOn`/`captureAlsoOnDays`, skipping named days; `landing()` = displayDate ?? deadline for `days` and `undated`. Renders applied.bulk-applied («4 tareas movidas al jue, 22 de oct», 4 lit rows) and bulk-shift-applied ca 2× (fits). |
| UX-1710 | fixed | `commandTasksAssignedTo` via shared `bulkAssignee` and `_assignsOnly`; `marking` label → `commandBulkComplete(n)`; CA «per fer», EN “tasks to do”, EN “for today”. |
| UX-1711 | fixed | `AppliedCompletion.days` (command_runner.dart), completion ids in the focus and days in landing; one completion reads `notificationCompleted(title)`. Render applied.complete-applied: Sat 24 selected, row ticked and lit, «Completada: Ir a la peluquería · Deshacer». |
| UX-1707 | fixed | task_provider.dart: `restoreTasks`, `undoSchedule`, `undoOccurrence` end with `showLocal()`. Tests over a never-completing sync pass. |
| UX-1714 | fixed | `_frozen` captured at the tap; `_views()` returns it; cleared on failure, when the result stays (`!closing` in finally) and on Deshacer; `_busy` disables cards and buttons while closing. |
| UX-1709 | fixed (item 5 waits on D1, not counted) | `commandBulkNothingToChange(bulk.matched)`; `commandWont*` plurals fed by `view.bulk?.count ?? 1`; `commandBulkViewOnly(project)` (render cards.bulk-view-only); `commandNoDayStays`; `commandAlreadyDone`. Copy exact in EN/ES/CA. |

## Regressions

**R1A-1 · S1 · ✕ on a set still asking which project says it in the singular**
- Where: voice_task_screen.dart `_commandCard` → `remove()` passes `count: view.bulk?.count ?? 1`; a set waiting on «¿Qué proyecto?» has `bulk == null` (resolveCommand returns `CommandView(command, projectChoices: …)`), so ✕ on «Tareas de «mates»» shows «No se cambiará» / «No se eliminará» / «No se completará» about a plural set. Caused by P225's asking state meeting P228's new plurals.
- Fix: when the command is a set (`command.bulk`) and nothing is counted yet, pass a count that takes the plural (e.g. `view.bulk?.count ?? (command.bulk ? 2 : 1)`), so it reads «No se cambiarán» / «No se eliminarán» / «No se completarán» (CA «No es canviaran» / «No se suprimiran» / «No es completaran»). No new copy.
- Verify: widget test — es 1×, the bulk-ambiguous-project state, ✕ tapped: «No se cambiarán».

**R1A-2 · S2 · A set deletion after another card is no longer brought into view**
- Where: voice_task_screen.dart `_firstOpen` (~2690-2697) now skips every set deletion, not only one that is the result's only card. In a mixed result — e.g. «Apunta comprar pan y borra todas las completadas de la semana pasada» — the task card comes first, and at 1.3×–2× the red «Eliminar N tareas» card starts below the fold while the button reads «Añadir y eliminar». Before, the reveal brought at least the red card into view; now nothing does, so the deletion can be applied unseen (inferred from code; no preview covers this mix).
- Fix: instead of skipping a set deletion, reveal it at its heading: for `view.bulk != null`, call `Scrollable.ensureVisible(card, alignment: 0)` (heading at the top of the view) rather than `alignment: 1`; a one-task deletion keeps `alignment: 1`. The lone-set case still opens at «Eliminar 3 tareas».
- Verify: widget test — es 2×, 360 dp, a result with one new task and a 3-task deletion set: after settling, the set's `command-headline` and its ✕ lie inside the sheet's visible scroll area; cards.bulk-delete.es.light.2x unchanged.

## Not regressions (checked)
- Label `marking == 1` with another card still asking: the tap applies only the completion and keeps the rest for review, as «Guardar cambios» did; the label now names it truly.
- Completing an overdue task now lands Calendar on its own (past) day: it's the only day the ticked row shows, per the brief.
- bulk-applied still lists «Pagar la factura del gas · Vence mar, 20 de oct» on tomorrow: D1, pending owner decision.
