# Verify — run 2026-10-18-commands, round 3 (b2), area A — 2026-10-18

Package: P150 (re-confirm only; no code change).

**Evidence:** code read in the working tree. App/lib/screens/voice_task_screen.dart (22:20), App/lib/widgets/capture_command_cards.dart (22:18), App/lib/widgets/task_list_picker.dart (22:17) and App/test/voice_command_cards_test.dart (23:03) were all last modified before round 2's verify note (verify-b2-r2-A.md, 23:42), so they are the same files round 2 checked and its tester passed. ux-tester reported nothing new this round. Flutter not run (UX loop rule). No preview covers the command cards or the project sheet in this state; P150 changes no copy or layout, so no render was needed.

| ID | status | evidence |
|---|---|---|
| UX-909 | fixed | `_undecided` returns `({names, lists})`, collecting `existingListId` of every blocking project view (voice_task_screen.dart:2423-2440). `_draftReady` holds a draft with no `newProject` whose `task.listId` is in `lists`, and one with `newProject` by folded name (:2442-2451). `_save` (:2852-2853) and `build` (:3420-3426) use the same record, so the button label («Revisa los detalles», `captureCheckDetails`) and the save agree. Tests present: :3439 (original scenario), :4253 (button off, a tap saves nothing, «Crear «Química»» turns it on), :4278 («Física y Química» keeps fyq, no project created), :4298 (mixed with «Comprar pan»), :4320 («Ya tienes «Matemáticas»» saves at first tap). |
| UX-1219 | fixed | `chooseTaskList` has `selectedNone = true` (task_list_picker.dart:26-35); the «Sin proyecto» row is `selected: selectedNone && listId == null && newName == null` (:59). «Otro proyecto…» passes `selectedNone: false` (capture_command_cards.dart:293-298) and maps a «Sin proyecto» pick to `onNone` (:299-304). `TaskListPicker._choose` (task_list_picker.dart:115-126) keeps the default, so a task's own chip with no project still shows «Sin proyecto» chosen. Test at :4350 asserts no row selected, «Sin proyecto» clears the question, the task saves with `listId == null` and no project is created. |

## Regressions
None. P150 changed no file; the three source files are unchanged since round 2's verify, which found no regressions in the result card save, the project question card, or the project sheet from the card and from the chip.

## Note
The test line numbers drifted by one to three lines from the brief (:4250 → :4253, :4349 → :4350) because of test edits made before round 2's verify; the tests are the same ones.
