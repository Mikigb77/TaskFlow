## UX verify — P318 («Crear tarea» from a note) — round 1, re-applied worktree — 2026-11-04

P318 was shelved at the L2 merge (merges-L2.jsonl, `unmerged-P318.patch`) and re-applied on top of the run's earlier work in `.claude/worktrees/wf_ffe605e9-07e-2`. This pass judges that worktree. The notes of the shelved worktree's two checks are kept below ("Earlier pass") and in `verify-r1-P318-2.md`.

**Verdict:** all four findings fixed at widget-test level; R1-P318-1 (the earlier pass's label flash) stays fixed; one new polish regression, R1-P318-2. Device checks still owed; nothing here is phone evidence.
**Read:** `waves.py diff --worktree .claude/worktrees/wf_ffe605e9-07e-2` (14 files: 3 ARB, main_shell, task_detail_screen, voice_task_screen, capture_store, capture_review_editor, checklist_editor, note_task, 3 tests and a test helper, meeting_previews; `analysis_options.yaml` and `pubspec.lock` no longer in it); worktree sources; renders `App/build/ux/meetings/note.{review.es.1x, create-task.es.1x, create-task.ca.2x, after-task.es.1x}.png` (2026-11-04 01:06; `find lib -newer` lists nothing, so current). Flutter not run.

### Findings

**UX-2701 · fixed**
- `App/lib/widgets/note_task.dart` (create, `source: 'note'`; open steps `ChecklistItem(title:, completed: true)`).
- `App/lib/widgets/checklist_editor.dart`: `choosing` — `meetingStepsToAdd` heading replaces «Pasos · n/N» and the progress bar; `if (!choosing)` drops the ⋮; `_addStep` makes a typed step start ticked; the repeat lock is off while choosing; `semanticLabel: items[index].title` unchanged; no strikethrough on ticked rows.
- `App/lib/widgets/capture_review_editor.dart` (both ChecklistEditors get `choosing: widget.choosingSteps`); only `voice_task_screen.dart:4857` sets it (`_fromNote`). task_editor.dart untouched.
- `App/lib/screens/voice_task_screen.dart:3417-3445`: from a note, `_save` keeps only ticked steps, in order, as `ChecklistItem(id, title)` (open), written to the store before `saveReady`.
- Render `note.review.es.light.1x`: «Pasos que se añaden», three ticked rows, no ⋮, «Añadir tarea» / «Cancelar».
- Tests: four UX-2701 tests in meeting_screens_test.dart pass (incl. a dictated review still showing «Pasos · n/N», ⋮ and done-ticks).

**UX-2702 · fixed**
- `voice_task_screen.dart:3552-3562`: from a note, the sheet pops and `TaskDetailScreen(taskId)` is pushed on the navigator under it; the `calendarFocusProvider` branch is the `else if`, so focus isn't set.
- Deshacer (`:3621-3630`): `undoSave`, then the restored session is discarded (nothing waits) and the pushed page is popped or removed.
- `note_task.dart`: `NoteTaskLinks` in `app_preferences` scope `noteTasks:<owner>` (cleared by account deletion's `<kind>:<owner>` rule, account_deletion.dart:232-237); link written after the sheet closes, only for a session with status 'saved'. `noteMadeTask` requires the task in `taskProvider`.
- `task_detail_screen.dart:572-584`: filled «Ver tarea» (`note-view-task`) opens that task; no «Crear tarea» then. Render `note.after-task.es.light.1x`: «Ver tarea» filled + «Editar nota» outlined, same height.
- Tests: four UX-2702 tests pass (landing, one Back to the note, «Ver tarea» opens the same task with no new task, Deshacer and page-delete bring «Crear tarea» back). Gap: the real `NoteTaskLinks` persistence across a restart is faked in memory; device check owed.

**UX-2706 · fixed**
- `voice_task_screen.dart:4471-4475`: `_leave` for a note session goes straight to `_discard` (`:4500`: session discarded, sheet pops, no snackbar, no `captureKeepTextQuestion`). Cancel (`Navigator.maybePop`), Back, scrim and swipe all reach `_leave` through the sheet's `PopScope(canPop: false)` (`:4803-4807`). Other captures: code below unchanged.
- `App/lib/services/capture_store.dart:173-195`: `pending` never returns a 'note' session and deletes one not opened in this run of the app. No other store reader lists sessions (only `read`, `pending`, `cleanFinished`); no code compares `source` with 'typed', so 'note' behaves as typed elsewhere.
- Tests: meeting_screens_test (Cancelar and Back, no dialog, session gone, `pendingCapturesProvider` unchanged) and three capture_recovery_test store tests on sqflite-ffi pass. Swipe and scrim untested; same `PopScope` path.

**UX-2709 · fixed**
- `task_detail_screen.dart:536-596`: «Crear tarea» / «Ver tarea» is the `FilledButton.icon`, first; «Editar nota» an `OutlinedButton.icon` raised to the filled height (`minimumSize 48`, `VisualDensity(vertical: 3)`); a note with no open steps and no made task keeps the filled «Editar nota» alone.
- Renders: `note.create-task.es.light.1x` side by side, equal heights; `ca.light.2x` stacked, filled «Crea una tasca» above outlined «Edita la nota». The stacking at 2× is the same `Wrap` as before the change (two buttons then too), so it is not new. Tests: ≤1 dp at ES 1×/2×, CA 2×, Manrope loaded.

### Regressions

**R1-P318-1 · fixed** (from the earlier pass: «Crear tarea» flips to «Ver tarea» on first open)
- `App/lib/screens/main_shell.dart:88-90` starts the links read in the shell; `task_detail_screen.dart:264-269, :539-553` holds the main button's slot with an invisible, untappable `Visibility(maintainSize)` until `noteTasksProvider.hasValue`. Reasoned from code; no test drives the unread state.

**R1-P318-2 · Severity 1 · Deshacer leaves a «Tarea no disponible» page open**
- Where: `App/lib/screens/voice_task_screen.dart:3627-3630` (Deshacer closes only the `taskPage` route the save pushed); `task_detail_screen.dart:205-230` (the missing-task state).
- The moment: "I went back to the note, tapped «Ver tarea», then pressed Deshacer — now it says «Es posible que esta tarea se haya eliminado»? Did I break it?"
- What happens: the save's «Añadida sin fecha · Deshacer» bar has an action, so it stays until used. If the person goes Back to the note and opens the task again with «Ver tarea» (a new route), or opens «Editar» on the task page, Deshacer deletes the task but leaves that page on top showing the empty state «Tarea no disponible · Es posible que esta tarea se haya eliminado», or the edit form of a deleted task. The acceptance ("closes its page if on top") holds only for the first page.
- Why it fails: B/O (the person's own undo ends on a vague "maybe deleted" page), Nielsen's visibility of system status.
- Fix: on Deshacer from a note, pop every route above the note (e.g. `navigator.popUntil` the route under the first pushed task page, or remove any route showing that task id), so the person always ends on the note with «Crear tarea». No new copy.
- Evidence: inferred from code; not tested.

### Not UX, for the organizer
- `App/lib/screens/main_shell.dart` is outside P318's file list (the R1-P318-1 fix; one `ref.listen` and an import).
- Failing `bulk_voice_commands_test.dart` (P274, UX-2202) is date-dependent (fails on Wednesdays) and unrelated to P318's code.

### Device checks still owed (Spanish, phone)
- Note › «Crear tarea» › untick one › «Añadir tarea»: task page with the kept steps open; Back shows «Ver tarea»; after reopening the app the note still shows «Ver tarea», with no «Crear tarea» flash first.
- Cancelar asks nothing; «Sin guardar» stays empty after reopening the app.

### Memory notes
- Area C map unchanged from the earlier pass: a note's bottom bar is filled «Crear tarea» / «Ver tarea» first + outlined «Editar nota»; its review uses ChecklistEditor `choosing`; 'note' sessions never reach «Sin guardar» and leave with no question; a save from a note opens the new task's page over the note.
- Pattern: an undo that deletes something a pushed page shows must close every page of it, not only the route it pushed (R1-P318-2); action snackbars outlive navigation.

---

# Earlier pass (shelved worktree wf_fe15d9eb-d17-2)

## UX verify — P318 («Crear tarea» from a note) — round 1 — 2026-11-03

**Verdict:** all four findings fixed at widget-test level; one polish regression (R1-P318-1). Device checks still owed (none here is phone evidence).
**Read:** `waves.py diff --worktree .claude/worktrees/wf_fe15d9eb-d17-2`; worktree sources; renders `App/build/ux/meetings/note.{review,create-task,after-task}.*.png` (23:41, after the code) and their AUDIT.md sections. Flutter not run.

### Findings

**UX-2701 · fixed**
- `App/lib/widgets/note_task.dart:130-133`: the note's open steps start ticked (`completed: true`); session `source: 'note'` (:121).
- `App/lib/widgets/checklist_editor.dart`: `choosing` mode — heading `meetingStepsToAdd` replaces «Pasos · n/N» and the progress bar (:131-149); ⋮ hidden (`if (!choosing)`, :219); a typed step starts ticked (`_addStep`, :81-84); the repeat lock is off while choosing (:123); checkbox `semanticLabel` stays the title. No strikethrough on ticked rows, so ticked reads as "in", not "done".
- `App/lib/widgets/capture_review_editor.dart:820, :938`: passes `choosingSteps`; only `voice_task_screen.dart:4843` sets it (`_fromNote`). The task form's two `ChecklistEditor`s (task_editor.dart:1097, :1462) are untouched.
- `App/lib/screens/voice_task_screen.dart:3401-3431`: on save from a note, unticked steps are dropped and the rest saved in order as open (`ChecklistItem(id, title)`).
- Render `meetings/note.review.es.light.1x.png`: «Pasos que se añaden», three ticked rows, no ⋮; CA 2× «Passos que s’afegeixen» fits. AUDIT TalkBack: «Pasos que se añaden», then each checkbox «<title>» [checked].
- Tests: the four UX-2701 tests in meeting_screens_test.dart; checklist/capture/notes/task_detail suites rerun unchanged.

**UX-2702 · fixed**
- `voice_task_screen.dart:3538-3549`: from a note, the sheet pops and `TaskDetailScreen(taskId)` is pushed on the navigator under it; `calendarFocusProvider` isn't set (the focus branch is the `else if`).
- Deshacer (`:3607-3616`): deletes the task (`undoSave`), discards the restored session so nothing waits, and pops/removes the task page.
- `note_task.dart:24-31, :36-80, :155-168`: phone-local link in `app_preferences` (scope `noteTasks:<owner>`, PRIMARY KEY on scope so `replace` works; account deletion clears `*:<owner>` scopes, account_deletion.dart:234). Task ids are AUTOINCREMENT and delete-undo restores the same id (task_database.dart:62, :705), so the link can't point at an unrelated or orphaned task.
- `App/lib/screens/task_detail_screen.dart:250, :571-585`: while the made task exists, a filled «Ver tarea» opens it; «Crear tarea» is gone. Render `note.after-task.es.light.1x.png`: «Ver tarea» 128×60 filled + «Editar nota» 142×60 outlined (AUDIT).
- Gap: persistence through the real `NoteTaskLinks` isn't tested (in-memory stand-in); the code reads right. Device check owed.

**UX-2706 · fixed**
- `voice_task_screen.dart:4457-4461`: `_leave` for a note session goes straight to `_discard` (session discarded, sheet pops), no `captureKeepTextQuestion`. Cancel, Back, scrim tap and swipe all reach `_leave` through the sheet's `PopScope` (:4789-4793). Other captures keep the question (unchanged code below).
- `App/lib/services/capture_store.dart:35-38, :176-194`: `pending` never returns a 'note' session and deletes one not opened in this run of the app (left by a killed app). `pendingCapturesProvider` invalidation in note_task.dart removed (nothing to refresh).
- Tests: meeting_screens_test (no dialog, session discarded) and capture_recovery_test (sqflite-ffi: open now not pending; left-over deleted). Swipe/scrim not tested; same path.

**UX-2709 · fixed**
- `task_detail_screen.dart:571-610`: «Crear tarea» / «Ver tarea» is the `FilledButton.icon`, first; «Editar nota» an `OutlinedButton.icon` after it, raised to the filled height (`VisualDensity(vertical: 3)`); a note with no open steps and no made task keeps the filled «Editar nota» alone.
- Renders: `note.create-task.es.light.1x` side by side, equal heights; ES 2× and CA 2× stack, filled first, equal heights. Tests measured ≤1 dp at ES 1×/2×, CA 2×.

### Regressions

**R1-P318-1 · Severity 1 · Button flips «Crear tarea» → «Ver tarea» on first open**
- Where: `App/lib/widgets/note_task.dart:24-31, :91-101` (`noteTasksProvider`, a FutureProvider first read by the note page, `task_detail_screen.dart:250`).
- What happens: the first note page opened after the app starts builds while the links are still loading, so a note that already made its task shows the filled «Crear tarea» for a frame or more, then «Ver tarea» under the finger. A quick tap there makes a second identical task — the duplicate UX-2702 removes (recurring problem: screen changing under the finger).
- Fix: read `noteTasksProvider` before any note page can open (e.g. watch it where the Notes tab or the shell builds), and on the note page build the task button only once it has a value (`hasValue`), so the label never changes after it appears.
- Evidence: inferred from code (async read on first build); the flash length needs a device.

### Not UX, for the organizer
- The diff also changes `App/analysis_options.yaml` (analyzer excludes) and `App/pubspec.lock` (intl 0.20.2→0.20.3, matcher, meta, test_api, vector_math bumps), neither in P318's file list; the lock bump looks like a `flutter pub get` side effect. Outside my lane; flagging for scope.

### Device checks still owed (Spanish, phone)
- Note › «Crear tarea» › untick one › «Añadir tarea»: task page with the kept steps open; Back shows «Ver tarea»; after reopening the app the note still shows «Ver tarea» (real `app_preferences`).
- Cancelar asks nothing; «Sin guardar» stays empty after reopening the app.

### Memory notes
- Area C map: a note's bottom bar is now filled «Crear tarea» / «Ver tarea» first + outlined «Editar nota» (same height); a note's review uses ChecklistEditor `choosing` (ticked = goes in, «Pasos que se añaden», no ⋮); capture `source: 'note'` sessions never reach «Sin guardar» and leave with no question; save from a note opens the new task's page over the note.
- Pattern: phone-local per-account links live in `app_preferences` scope `<kind>:<owner>`; async FutureProvider reads on a page's first build can flip a primary button's label (R1-P318-1).
