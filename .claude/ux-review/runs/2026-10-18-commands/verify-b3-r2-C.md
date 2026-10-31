## UX verify — run 2026-10-18-commands, b3 round 2, area C (P161) — 2026-10-19

**Verdict:** both findings fixed; no regressions caused by the change.

### UX-1225 · fixed
- `App/lib/screens/voice_task_screen.dart:2424-2458` `_renameProject`: after trimming, looks up `same` in `editableProjects(taskListsProvider)` with `foldForSearch(p.name.trim()) == foldForSearch(spokenProjectName(name))` — the same fold `_apply` uses at :2937 and :2953. With `same`, every live new-project card matching `from` becomes `copyWith(choice: same.id)` (so `existing` is true, `capture_command.dart:305-310`, and the card renders «Ya tienes «Física»» + «La tarea va ahí.», `capture_command_cards.dart:472-483`), and every pending draft whose `newProject` matches `from` gets `taskWithProject(draft.task, same)` + `clearNewProject: true` — card-less drafts included, since the draft loop doesn't depend on a card. One `setState`, `_error = null`, then `await _write()`. Without `same`, the P141 rename is untouched.
- View-only «Física»: `editableProjects` excludes it, so the rename stays new and the save creates the person's own project — the settled rule.
- Nothing is created before the confirming tap: the rename only rewrites cards and drafts.
- Tester: four P161 UX-1225 tests pass (`App/test/voice_command_cards_test.dart` from :5080).
- Evidence: verified in code, plus widget tests.

### UX-1226 · fixed
- `App/lib/widgets/task_list_picker.dart` `chooseTaskList`: the dictated row has `trailing: Icon(Icons.edit_outlined, size: 20, semanticLabel: context.l10n.commandRenameProject)` only when `onRename != null`. `capture_review_editor.dart:440-445` passes null while saving (`!widget.enabled`), so there is no pencil then.
- Copy: `commandRenameProject` EN “Change the name” / ES «Cambiar el nombre» / CA «Canvia el nom», next to `commandUseName` in all three ARB files, with the @description from the brief. Generated getters are present.
- Render `App/build/commands-project-sheet-rename-es-2x.png` (04:28, newer than every changed source; only the generated l10n is 10 s newer, from the same run): at 2× on 320 dp, the green pencil sits at the right edge of the 3-line «Nuevo proyecto: / Fisica 2» row, wholly inside the sheet, with no overflow.
- Device check still open: what TalkBack reads for the row («Nuevo proyecto: Fisica 2», «Cambiar el nombre», selected).

### Regressions — none
- Considered: after a rename to an existing name, the collapsed task card no longer shows a project chip, because `capture_review_editor.dart:779` shows it only for a new project or an unreviewed assignment. That's the same as tapping an existing project's row in the sheet (`:449-455`, pre-existing), and the project card above now says «Ya tienes «Física» · La tarea va ahí.», so the user can see where the task went. Consistent with the brief ("treat it as tapping that project's row"); not counted.
- Considered: the card turned to «Ya tienes …» has no ✕ and no way back to a new project. Same as the picked-row path, and nothing is created, so it isn't counted.
- The speed-bar test and P141's tests are reported passing by the tester.
