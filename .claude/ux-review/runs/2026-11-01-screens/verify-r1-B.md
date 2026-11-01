## UX verify — run 2026-11-01-screens, round 1, area B (P315) — 2026-11-01
**Verdict:** Ship. Both findings are fixed; no regression in the changed files or the flows they touch.
**Evidence level:** code (diff vs HEAD), the testers' widget tests (read, not run), and a current render. No device.

### UX-2646 · fixed
- `App/lib/screens/task_detail_screen.dart:38-40` adds `final DateTime? doneAt`, documented as Completadas' remembered time; `:76-78` the tick passes `doneAt: widget.doneAt`. The reopen path (`:68-71`) is unchanged.
- `App/lib/widgets/task_tile.dart:200-210` `open()` passes `doneAt: doneAt` to the page; doc at `:51-53` updated.
- `App/lib/widgets/task_list.dart:89` now passes `timeOf?.call(task)` for every row, done or open, so a done row's page carries its time (Reabrir then Completar keeps its place).
- The row's own checkbox on a done row now receives `doneAt` too, but `TaskInteractions.toggle` (`App/lib/widgets/task_interactions.dart:22-23`) passes `at: task.isCompleted ? null : doneAt`, so a reopen ignores it: no change in behaviour.
- Only `CompletedTasksScreen` (`completed_tasks_screen.dart:142`) gives `TaskList` a `completedTime`, so every other way to a task's page still passes nothing and stamps now.
- Covering Completadas clears `_doneHere` (`completed_tasks_screen.dart:66-67`); the page holds the time itself, and on return `_doneHere.putIfAbsent` re-reads the stored 10:00, so the order holds on this visit and the next.
- Tests: `App/test/calendar_feedback_test.dart` group 'P315 · the task page' (4 tests) check stored 10:00 and the order 11:00, 10:00, 09:00 on this visit and the next, for reopen-on-list-then-page, Reabrir-then-Completar on the page, a repetition, and that Calendar/Tareas still store 12:00. Reported passing.

### UX-2645 · fixed
- `App/lib/l10n/app_es.arb:407` `fileRemoveHelp` now reads «Se quitará de la tarea y, si lo has subido, de tus otros dispositivos al sincronizar. Tu archivo original no se elimina.»; generated `app_localizations_es.dart:1471-1472` matches (gen-l10n ran). EN and CA untouched.
- Render `App/build/ux/tasks/detail.remove-file.es.light.1x.png` (2026-11-01 15:26; no app file newer): «¿Quitar este archivo de la tarea?», «Billetes de avión.pdf», the new help line, «Cancelar», «Quitar archivo». No «Se eliminará» in the dialog; the INDEX description stays true.
- Tests: `App/test/attachment_panel_test.dart` group 'P315 · the task page' (3 tests). Reported passing.

### Regressions
None. Checked: the done-row checkbox (reopen ignores `doneAt`); Undo after Completar on the page (`setCompleted(task, false)`, unchanged); pages opened from anywhere but Completadas (no `doneAt`); a pre-schema-21 completion (null time, stamps now, as P310 accepted); the remove-file dialog's layout at 1× (four lines, no clipping).
