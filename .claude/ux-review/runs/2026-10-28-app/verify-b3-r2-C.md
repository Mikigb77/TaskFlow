## UX verify — run 2026-10-28-app, round 2, area C (P311) — 2026-11-01

**Verdict:** Ship. UX-2639 is fixed. The change caused no regressions.

### UX-2639 · The project sheet shows its last row whole — **fixed**
- **Code:** `App/lib/widgets/task_list_picker.dart:47-60`. The fix matches the brief and the «¿Quién es responsable?» sheet (`task_assignment_picker.dart:135-145`):
  - `showDragHandle: true` and `isScrollControlled: true`;
  - `SafeArea` → `ConstrainedBox(maxHeight: MediaQuery.sizeOf(context).height * .7)` → `ListView(shrinkWrap: true)`.
  - The handle, the «Proyecto» heading (`Semantics(header: true)`), the ✓ rows and the row order are unchanged. No copy changed.
- **Render:** `notes/note.project-sheet.es.light.1x.png`, rendered 2026-11-01 13:25. No app file is newer.
  - All five projects show, and «Nuevo proyecto» is a whole row at the bottom with room below it.
- **AUDIT** (`## notes/note · project-sheet`):
  - «Nuevo proyecto» is a 360 × 56 dp button, with no "Target under 48 dp" flag.
  - The only flags are the 0 dp gaps between list rows, which are standard for Material list rows.
  - TalkBack order: Cerrar, heading «Proyecto», the rows, «Casa» [selected].
- **Tests:** `App/test/project_scope_control_test.dart`, group `P311 · project sheet height`. All three pass:
  - five projects: the row is whole, with no scroll;
  - one project: the sheet is under 400 dp;
  - twelve projects at 2×: the list is ≤ 560 dp and scrolls to «Nuevo proyecto».
- **Wording note on acceptance 3:** at twelve projects and 2×, the list is 560 dp (70%), but the whole sheet with its 48 dp handle is 608 dp (76%), with its top at 192 dp.
  - I judge this met. The brief's fix sets the cap on the list, as the assignment sheet does, and the acceptance's intent holds: the sheet doesn't cover the screen, 192 dp of the dimmed note stays visible above it as a tap-to-close area, and the list scrolls to the last row.
  - Cutting the cap to fit the handle inside 70% would make this sheet differ from the assignment sheet for no visible gain. No action.
- **Evidence:** verified in code, seen in a current render and AUDIT, and widget tests. No device check.

### Regressions (only `task_list_picker.dart` and the flows that open the sheet)
None found.
- **Both callers get the same sheet:**
  - the project chip (`TaskListPicker._choose`, :247) on notes, tasks and the form;
  - the dictation's «Otro proyecto» chip (`capture_command_cards.dart:480`), opened on top of the capture sheet.
  - `isScrollControlled` with a 70% cap leaves the capture sheet visible behind it, and the result is handled as before.
- **The sheet still hugs short content** (`shrinkWrap`): with one project it is under 400 dp (test). Long lists scroll inside the cap, and the row cut at the viewport's edge works as a normal scroll cue.
- **Landscape and short screens:** the cap scales with height (for example, 360 dp tall gives a 252 dp list plus the 48 dp handle). Nothing overflows. This is reasoned from code; no render covers it.
- **Other changes in the HEAD diff:** the `note` flag (`shareNoteConfirm`, `sharedNoteStays`), the ✓ trailing icons and the heading come from earlier packages of this run (P294 and the notes package) and were verified in round 1. P311 didn't change them.

### Memory notes
- The project sheet (`chooseTaskList`) and the assignment sheet now share one sheet shape: a drag handle, `isScrollControlled`, and the list capped at 70% of the screen height with the handle outside the cap (so the sheet is at most about 76% at 800 dp).
- «Novedades del proyecto» (`project_preferences.dart`) wasn't checked here. To confirm the pattern when area C is next touched, check whether it follows the same shape.
