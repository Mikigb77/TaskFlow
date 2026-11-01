## UX verify — 2026-10-28-app, round 1, area C (P294) — 2026-11-01

**Verdict:** Ship after fixes. All three findings are fixed. One small regression: the project sheet's new drag handle and heading push its last row, «Nuevo proyecto», partly below the sheet's edge.

Evidence: the code (`git diff HEAD`), the renders `notes/note.project-sheet.es.light.1x`, `tasks/detail.created-by.es.light.2x`, `tasks/detail.created-by.ca.light.2x` and `notes/note.with-steps`, all newer than every file under App/lib and App/assets (checked with `find -newer`), and AUDIT.md. This is widget-test level evidence, not a device.

### Findings

**UX-2514 — fixed**
- A trailing `Icons.check_rounded` shows only on the selected row, with the same condition as `selected:`, in all four sheets:
  - the project sheet: `App/lib/widgets/task_list_picker.dart:71-75` (the new-project row), `:95` («Sin proyecto») and `:113` (projects);
  - «Todos los proyectos»: `App/lib/widgets/project_scope_control.dart:175` and `:446`;
  - «Novedades del proyecto»: `App/lib/widgets/project_preferences.dart:35`;
  - «¿Quién es responsable?»: `App/lib/widgets/task_assignment_picker.dart:158` and `:176`.
- The project sheet has `showDragHandle: true` (`task_list_picker.dart:49`). Its «Proyecto» title is `Semantics(header: true)` in `titleMedium`, with the same 24/0/24/8 padding as `_chooseRole` (`:53-62`).
- In the render `notes/note.project-sheet.es.light.1x`, the drag handle shows, then the heading «Proyecto». «Casa» alone carries the ✓, which also holds in grayscale. In AUDIT, TalkBack reads «Cerrar», heading «Proyecto», then «Casa» [selected].
- The tester's four UX-2514 tests pass.

**UX-2510 — fixed**
- The new keys are in all three catalogs with the planned copy, and each has a description in app_en.arb:
  - `shareNoteConfirm`: ES `app_es.arb:1148`, CA `app_ca.arb:852`;
  - `sharedNoteStays`: ES `:1149`, CA `:853`;
  - `moveNoteError`;
  - `deleteNote`: ES «Eliminar nota», EN “Delete note”, CA «Suprimeix la nota».
- `TaskAssignmentPicker` passes `note: task.isNote` to `TaskListPicker` (`task_assignment_picker.dart:91`). This covers every place the chip appears: the task page, the form (`task_editor.dart:1241`) and the capture review editor.
- `TaskListPicker` uses `shareNoteConfirm` (`task_list_picker.dart:258`) and `sharedNoteStays` (`:303`) for a note.
- The task page uses `deleteNote` for the tooltip (`task_detail_screen.dart:262`) and `moveNoteError` (`:322`).
- In AUDIT `notes/note · with-steps`, TalkBack now reads the delete button as «Eliminar nota».
- Tasks keep the task strings, and the tests check both sides.

**UX-2614 — fixed**
- `runSpacing: 8` (`task_assignment_picker.dart:83`).
- In the renders `tasks/detail.created-by.es.light.2x` and `.ca.light.2x`, «Matemáticas» and «Ana» wrap about 8 dp apart.
- The AUDIT for `tasks/detail · created-by` flags no gap between the chips. The only gaps under 8 dp it flags are between the 1× plan rows, which were there before this package.

### Regressions

**R1C-1 · Severity 1 · The project sheet's last row is half hidden below its edge**
- **Where:** `App/lib/widgets/task_list_picker.dart:47-62`, the project sheet opened from a note's or a task's chip. Render `notes/note.project-sheet.es.light.1x`.
- **What happens:**
  - The sheet still isn't `isScrollControlled`, so Flutter caps it at 9/16 of the screen (450 dp on 360×800).
  - The drag handle (48 dp) plus the heading (about 32 dp) replace a 56 dp title row, so the content grows by about 24 dp.
  - With the preview's five projects, the content was about 448 dp and fit. Now «Nuevo proyecto» shows only 34 of its 56 dp.
  - AUDIT flags a new "Target under 48 dp: «Nuevo proyecto» button, 360 × 34 dp".
  - The newcomer sees a cut-off last row and may not realise the list scrolls to create a project.
- **Why:** RE-2/RE-3 (the target size of the visible part). A row cut by the sheet's edge, not by a scroll, is a weak signifier (Norman 2013).
- **Fix:** make the sheet scroll-controlled with a height cap, as the «¿Quién es responsable?» sheet does: `isScrollControlled: true`, with the `ListView` inside `ConstrainedBox(maxHeight: MediaQuery.sizeOf(context).height * .7)` (`task_assignment_picker.dart:137-145`). No copy.
- **Verify:** re-render `notes/note.project-sheet`. «Nuevo proyecto» should be whole, at 360 × 56 dp, with no target flag in AUDIT.

### Notes (not regressions)
- **The new-project row now shows ✓ and the pencil side by side.** This is the creating row in the dictation's project sheet (`task_list_picker.dart:69-81`), and no preview covers it. The row is the selected choice, so the ✓ is consistent with UX-2514. A tap anywhere on the row still opens the rename dialog, as before. A newcomer might read ✓ as a "confirm" button, but nothing is lost: the dialog can be cancelled. Reasoned from code; no action unless a device run shows hesitation.
- **The other two pickers' titles are still plain rows, not headings.** These are the «¿Quién es responsable?» title (`task_assignment_picker.dart:147`, a `ListTile`) and «Novedades del proyecto» (`project_preferences.dart:22`). They were outside this brief. A later consistency pass could give them the same heading treatment.

### Memory notes
- **The selection pattern is now settled across five sheets:** the role sheet and the four in this package mark the selected row with a trailing ✓ (`Icons.check_rounded`, or `Icons.check` in the role sheet), alongside `selected:`.
- **Sheet heights vary in a way that recurs:** a sheet without `isScrollControlled` is capped at 9/16 of the screen. Adding a drag handle or a heading can push its last row below the edge.
