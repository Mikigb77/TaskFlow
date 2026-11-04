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
