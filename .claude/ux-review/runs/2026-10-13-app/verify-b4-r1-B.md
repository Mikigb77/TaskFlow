## UX verify — run 2026-10-13-app, round 1, area B (P10, P42) — 2026-10-14

**Evidence level:** I checked the code (`git diff HEAD`) and the tester's tests. No current render covers the task or note detail, or the edit form: `artifacts/design/notes-detail-dark.png` and `planning-detail-dark.png` date from 09-22 and are older than the code, so they don't count as evidence. The `build/*.png` renders from 10-14 01:54 don't show these screens.

### Results

| ID | Result | Evidence |
|---|---|---|
| UX-213 | fixed | `task_detail_screen.dart:177-178`: there's no more uppercase label above the title. A completed task shows `taskCompleted` (rendered as "TAREA COMPLETADA" through SectionLabel's uppercase), not "COMPLETADAS". `:195`: the project chip and "Solo tú puedes verlo." only show when `listId != null` or a project exists. `:292-305`: priority only shows above 1 (Low). `:340, :398`: notes only show when they have text. `attachment_panel.dart:156-163`: the panel disappears when there are no files and there's no error. The `fileEmpty`, `fileNone`, `noteEmptyBody`, `nextStep` and `completed` keys were removed. A plain task now reads about 15 words plus its title: Detalles de la tarea · Planificado para / Sin fecha · Bandeja de entrada · Hora / Sin hora · Completar · Reprogramar. That was about 45. Tests: task_detail_test.dart:65, :87, :103. |
| UX-214 | fixed | `:245` and `:255`: the date and time rows get `onTap: reschedule`, the same `TaskInteractions.reschedule` as the bottom Reprogramar button. `:179-186`: tapping the title opens `/editTask`. `:504`: rows are wrapped in an InkWell only when they can be tapped. ✏ stays for tasks (`:155`). Tests: task_detail_test.dart:116, :128. See R1B-1 and R1B-2 for what's left over. |
| UX-309 | fixed | `:404-418`: a note's bottom slot has one centred `FilledButton.icon` labelled `editNote` ("Editar nota" / "Edita la nota"). `:155`: ✏ is gone from the app bar for notes, and Delete stays there on its own (`:161-171`). `:341` and `:507-525`: tapping the body card opens the editor through the InkWell, and `note_text.dart:36` passes `onTap` to SelectableText, so a tap on the words opens it too, while long-press still selects. Link buttons keep their own handlers. Nothing can be tapped when the user can only view. Tests: notes_ui_test.dart:659, :674. |
| UX-208 | fixed (device check open) | `:31-93`: deleting no longer asks first, unless the task repeats. The detail closes, and P1's helper shows `taskDeleted` or `noteDeleted` ("Tarea eliminada" / "Nota eliminada"; CA "Tasca suprimida" / "Nota suprimida") with `undo`. The repeating-task dialog (`:34-53`) has `keepTask` as the FilledButton and `delete` as a TextButton in `colorScheme.error`. On Undo, `restoreTask` puts back the task as it was stored (the series, not the occurrence). For an account it flips the same row back (`is_deleted = 0`, revision + 1, pending) and stages the files again; for the local owner it inserts the row again with the same id (`task_database.dart:546-601`). `deleteTask(sync: false)` holds the deletion back until the snackbar closes (`task_provider.dart:222-236`), and the reminders are re-synced on load. The `deleteTaskQuestion`, `deleteNoteQuestion`, `deleteItemHelp` and `keepNote` keys were removed. Tests: task_detail_test.dart:147, :183, :225; sync_test.dart:428. **Device:** on a signed-in account, Undo has to survive the next sync and show up on a second device. |
| UX-211 | fixed | `task_editor.dart:427-431`: a `PopScope(canPop: false)` calls `_back()`. `:269-276`: if nothing changed, the form just closes, comparing against the `_unchanged` snapshot taken at `:145`. With changes, `_save(undo: true)` runs the form validation, so an emptied title shows the field's error and the form stays open. Then it shows `changesSaved` with Deshacer, and Deshacer calls `updateTask(before)` (`:312-334`). The app bar's back arrow is the default BackButton (maybePop), so it goes through the same PopScope. Nothing creates tasks through TaskEditor any more (`main.dart:399-404` only edits). Tests: task_detail_test.dart:265, :294, :309. |

### Regressions (only in the changed files and their flows)

**R1B-1 · Severity 2 · Some detail rows answer a tap, look-alike rows don't**
- Where: `task_detail_screen.dart:257-305`. The Duración, Fecha límite, Repetir and Prioridad rows have no `onTap`, but they sit in the same card and look exactly like the date and time rows above them, which now do respond.
- The moment: "Tapping the date changed the date, so I tap Repetir… and nothing happens?"
- Why it fails: consistency (Nielsen 1994): the same component should behave the same way. Before this change, none of the rows responded, so it was at least consistent. The change created the mismatch.
- Fix: give those four rows `onTap: canEdit ? edit : null`, which opens the edit form where they're set. Then every row in the card responds.
- Verify: widget test — tapping the Repetir row and the Fecha límite row opens `/editTask`.

**R1B-2 · Severity 1 · The new tap targets have no spoken action**
- Where: `task_detail_screen.dart:179-186` (title) and `:504` (date and time rows). Each is a bare InkWell, so TalkBack says "double-tap to activate" without saying what the tap does.
- Fix: wrap them in `Semantics(button: true, onTapHint: …)`, using the existing strings: `reschedule` for the rows, `editTask` or `editNote` for the title. This adds no new copy.
- Verify: semantics test — the date row has a tap action with the hint "Reprogramar".

**R1B-3 · Severity 1 · "Cambios guardados" has Deshacer after Back but not after Guardar**
- Where: `task_editor.dart:278` and `:315`. The Save button calls `_save()` (no Undo), while Back calls `_save(undo: true)`. The message and the result are the same, but the action offered differs.
- Fix: remove the `undo` parameter so every save offers Deshacer.
- Verify: widget test — edit the title, tap Guardar, and "Cambios guardados · Deshacer" shows.

### Notes, not counted as regressions
- When the title has been emptied, Back stays in the form with no way to discard the edit. That's what the brief (D12) asked for, so this is only something to watch in the 10-minute session.
- The attachment panel and the project chip can appear a moment after the detail opens, once their providers load. That's a small layout jump and doesn't affect what the user can do.
- `deleteTaskError` says "tarea" for a note too. That was already the case before this change.
