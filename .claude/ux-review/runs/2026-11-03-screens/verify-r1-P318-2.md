## UX verify — P318 («Crear tarea» from a note) — round 1, check 2, re-applied worktree — 2026-11-04

Worktree `.claude/worktrees/wf_ffe605e9-07e-2`. This pass follows the fix for R1-P318-2. The shelved worktree's check 2 is kept below, under "Earlier pass".

**Verdict:** all four findings are still fixed at widget-test level. R1-P318-2 is fixed on the paths it named. The new Deshacer code adds one minor regression, R1-P318-3: it closes the note's own edit form without saving it. Device checks are still owed, and nothing here is phone evidence.
**Read:** `waves.py diff` (the fix is in `App/lib/screens/voice_task_screen.dart`: `_save`, its `notePage`, and the note branch of Deshacer); worktree `voice_task_screen.dart:3395-3445, :3551-3570, :3597-3665`, `task_detail_screen.dart:255-275, :540-600`, `task_editor.dart:327-352, :577-600, :880-884`, `edit_task_screen.dart:137-180`, `main.dart:653-658`, `widgets/app_components.dart:12-32`, `services/feedback_timeout.dart`, and test `meeting_screens_test.dart:3868-3903`. Renders `App/build/ux/meetings/note.*` were made at 01:21, after the last change to `voice_task_screen.dart` (01:13). `find lib assets -newer` lists nothing. Flutter not run.

### Findings
- **UX-2701 · fixed.** The fix leaves this path alone. `_save` (`voice_task_screen.dart:3415-3447`) still saves only the ticked steps, in order, as open `ChecklistItem(id, title)`. `ChecklistEditor` `choosing` is unchanged. Render `note.review.es.light.1x` shows «Pasos que se añaden», three ticked steps and no ⋮. All four UX-2701 tests pass.
- **UX-2702 · fixed.** On a save from a note, the sheet pops, `notePage` is recorded as the route now on top (`popUntil` with an always-true predicate does not pop), and `TaskDetailScreen(id)` is pushed (`:3554-3570`). `calendarFocusProvider` is set only in the `else if`. Deshacer (`:3627-3642`) deletes the task, discards the restored session and pops back to the note. The app has a single navigator (`main.dart:89`), so «Ver tarea» pages, the task's edit form and the sheet all sit on that stack. The test at `meeting_screens_test.dart:3868` still exercises the new `popUntil` branch and checks that the note is the only TaskDetailScreen showing «Crear tarea». Render `note.after-task.es.light.1x` is current.
- **UX-2706 · fixed.** Unchanged: `_leave` discards a note session with no question (`:4483-4487`). `CaptureStore.pending` drops 'note' sessions. All store and widget tests pass.
- **UX-2709 · fixed.** `task_detail_screen.dart` is unchanged since check 1. The filled «Crear tarea» / «Ver tarea» comes first, then «Editar nota» outlined at the same height. Renders `note.create-task.{es 1x, es 2x, ca 2x}` are current.

### Regressions

**R1-P318-2 · fixed** (Deshacer left a «Tarea no disponible» page open)
- `voice_task_screen.dart:3637-3642`: while the note's page is active, Deshacer runs `popUntil(route == note)`. It closes a second task page opened with «Ver tarea» and the task's `/editTask` form, which were the two paths reported. If the note is no longer active, it falls back to closing only the page it pushed.
- Residual, not counted: Back to Notes › open the note again › «Ver tarea» › Deshacer still leaves «Tarea no disponible». Since check 1, I've read that `showFeedback` uses `persist: false` with `FeedbackTimeout.forAction()` (4 s by default; `app_components.dart:17-22`). Check 1 said the bar "stays until used", which was wrong. All those steps fit inside the bar's life only with a long accessibility timeout, or with TalkBack, where an action snackbar does not time out. The fix for R1-P318-3 below can cover this case too.

**R1-P318-3 · Severity 2 · Deshacer throws away an open edit of the note**
- Where: `App/lib/screens/voice_task_screen.dart:3637-3639` (`navigator.popUntil((route) => route == note)`), with `App/lib/widgets/task_editor.dart:880-884, :577-585`.
- The moment: "I went back to the note to fix a line, then tapped Deshacer because I didn't want the task after all, and my changes to the note are gone."
- What happens: after «Añadir tarea», the «Añadida sin fecha · Deshacer» bar shows on the app's messenger, over whatever page is on top. If the person goes Back to the note, taps «Editar nota» and types, Deshacer then pops every route above the note, including the note's own `/editTask` form. That form saves only from its own Back (`_back` › `_save`, called from `onPopInvokedWithResult` when `didPop` is false). `Navigator.pop` skips that path, so the typed edits are dropped with no message. Before this fix, Deshacer removed only the task page, and the note's form stayed open. Closing the edit form of the *task* is fine, because that task is deleted.
- Why it fails: lens I (nothing the user typed is lost); Nielsen's user control and freedom (an undo of one thing must not undo another). Rare: by default it needs Back, «Editar nota» and typing inside the bar's 4 s. With TalkBack or a long accessibility timeout the bar stays up. The note's lost text is the user's own input, so I rate it 2, not 1.
- Fix: on Deshacer, close only what belongs to the deleted task and leave the note's form open. For example, walk the routes above the note and `removeRoute` each one, except an `/editTask` route whose `settings.arguments` isn't the new task's id (that one is the note's form). Give the task pages, both the one the save pushes and «Ver tarea»'s, `RouteSettings(name: '/task', arguments: id)` so they can be recognised. Removing every route that shows the deleted id, even when the note isn't active, also fixes the R1-P318-2 residual. No new copy.
- Verify: a widget test. After «Añadir tarea», Back › «Editar nota» › type a word › Deshacer: the task is gone, the edit form is still open with the word, and Back saves the note with the word.
- Evidence: verified in code (`Navigator.pop` skips the form's save path). Not tested.

### Not UX, for the organizer
- The failing `bulk_voice_commands_test.dart` (P274, UX-2202) depends on the date: it fails on Wednesdays, when the dentist's day 2 is the coming Friday. It is unrelated to P318 and belongs with ux-tester or KNOWN_FAILURES.
- `App/lib/screens/main_shell.dart` is outside P318's file list. It holds the R1-P318-1 fix.

### Device checks still owed (Spanish, phone)
- Note › «Crear tarea» › untick one step › «Añadir tarea»: the task's page opens with the kept steps open. Back shows «Ver tarea». After reopening the app, the note still shows «Ver tarea», with no «Crear tarea» flash first.
- Cancelar asks nothing, and «Sin guardar» stays empty after reopening the app.
- Deshacer from the task's page lands on the note with «Crear tarea».

### Memory notes
- `showFeedback` (`widgets/app_components.dart`) sets `persist: false` and takes its duration from `FeedbackTimeout` (4 s by default). An undo bar does not stay until used, except under TalkBack. Don't claim it does.
- Pattern: an undo that also navigates must close only the pages of what it removed. A blanket `popUntil` drops other open forms, because `Navigator.pop` skips `PopScope`'s save-on-back (R1-P318-3).
- The app has one root navigator (`main.dart:89`). Sheets, task pages and `/editTask` all sit on one stack.

---

# Earlier pass, check 2 (shelved worktree wf_fe15d9eb-d17-2)

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
