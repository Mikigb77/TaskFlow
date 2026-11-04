## UX verify — P318 («Crear tarea» from a note) — round 1, check 2 — 2026-11-03

**Verdict:** all four findings stay fixed at widget-test level; R1-P318-1 is fixed (reasoned from code, no test drives the unread state). No new regression. Device checks still owed; nothing here is phone evidence.
**Read:** `waves.py diff --worktree .claude/worktrees/wf_fe15d9eb-d17-2` (the fix touches `App/lib/screens/main_shell.dart` and `App/lib/screens/task_detail_screen.dart`); `App/lib/widgets/note_task.dart`; renders `App/build/ux/meetings/note.after-task.es.light.1x.png` and `note.create-task.es.light.2x.png` (2026-11-04 00:00, newer than every changed lib file). Flutter not run.

### Findings

**UX-2701 · fixed** — unchanged since check 1: `note_task.dart:130-133` (steps start ticked, source 'note' :121), ChecklistEditor `choosing` mode, `_save` keeps ticked steps as open. Tests: the four UX-2701 tests in meeting_screens_test.dart pass; render `note.review.*` shows «Pasos que se añaden», all ticked, no ⋮.

**UX-2702 · fixed** — the task page opens over the note; link saved after the sheet closes (`note_task.dart:155-168`) and the note reads it through `noteMadeTask` (`:25-32`). `task_detail_screen.dart` (diff +564-630): «Ver tarea» filled, first, opens that task. Render `note.after-task.es.light.1x`: «Ver tarea» filled + «Editar nota» outlined, same height. Persistence through the real `NoteTaskLinks` is still untested (in-memory stand-in); device check owed.

**UX-2706 · fixed** — unchanged: `_leave` for a 'note' session discards with no question; `CaptureStore.pending` drops 'note' sessions. Tests in meeting_screens_test and capture_recovery_test (sqflite-ffi) pass.

**UX-2709 · fixed** — `task_detail_screen.dart`: «Crear tarea» / «Ver tarea» is the `FilledButton.icon`, first; «Editar nota» an `OutlinedButton.icon` raised to its height (`VisualDensity(vertical: 3)`, min 48). A note with no open steps and no made task keeps the filled «Editar nota» alone. Render `note.create-task.es.light.2x`: stacked, filled «Crear tarea» above outlined «Editar nota». Tests measured ≤1 dp at ES 1×/2×, CA 2×.

### Regressions

**R1-P318-1 · fixed** (Button flips «Crear tarea» → «Ver tarea» on first open)
- `main_shell.dart:88-90`: `ref.listen(noteTasksProvider, …)` starts the local read when the shell builds, before a note can be opened from the Notes tab.
- `task_detail_screen.dart:249-254`: `linksRead = !task.isNote || noteTasksProvider.hasValue`. While unread and the note has open steps, the main button's slot is a `Visibility(visible: false, maintainSize: true)` placeholder: no pointer, no semantics, same size, so the row and the 2× stacking don't move when the real button appears. The button that appears is final: never «Crear tarea» first.
- `note_task.dart:84-93`: a failed read returns `{}`, so the placeholder can never stick (it becomes «Crear tarea»). Riverpod 2 (`flutter_riverpod ^2.5.1`): after `invalidate` the value is kept while reloading, so `hasValue` stays true and the button doesn't blank after a save.
- Evidence: reasoned from code; no test or render shows the unread state. The flash length is a device question.
- Residual, too rare to count: a note that made its task and later had every step done, opened (e.g. from a notification at cold start) before the read finishes, shows the filled «Editar nota» alone, then gains «Ver tarea» before it, shifting «Editar nota» right. Needs both an all-done note with a link and a page open in the first moments of the app; not raised.

No new regressions in the changed files or their flows.

### Not UX, for the organizer
- `App/lib/screens/main_shell.dart` is outside P318's file list (needed for the R1 fix; not shared with another package this run).
- `App/analysis_options.yaml` and `App/pubspec.lock` still differ from HEAD; the implementer says they predate the fix. Keep them out of P318's merge.
- The analyze step's three `unawaited_return_in_try_block` warnings are in files P318 doesn't change.

### Device checks still owed (Spanish, phone)
- Note › «Crear tarea» › untick one › «Añadir tarea»: task page with the kept steps open; Back shows «Ver tarea»; after reopening the app the note still shows «Ver tarea», with no «Crear tarea» flash first.
- Cancelar asks nothing; «Sin guardar» stays empty after reopening the app.

### Memory notes
- Pattern settled for async labels on a primary button: start the read in the shell, and hold the button's slot with an invisible `maintainSize` placeholder until `hasValue`, so the first label shown is final (R1-P318-1 fix).
