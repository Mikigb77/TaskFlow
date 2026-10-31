## UX verify — run 2026-10-18-commands, round 2, area A (P148) — 2026-10-18

**Verdict:** both findings fixed; no regressions in the changed files.
**Evidence:** code read in the working tree, plus the acceptance tests ux-tester wrote (App/test/voice_command_cards_test.dart:4210-4405, reported with no failures). No preview covers the command cards or the project sheet in this state, and P148 changes no copy or layout, so no render was needed. Flutter not run.

### UX-909 · S2 · fixed
- `_undecided` (App/lib/screens/voice_task_screen.dart:2423-2440) now returns `({names, lists})`: the folded names of every blocking project view, and, kept apart, the `existingListId` of each one.
- `_draftReady` (:2442-2451): a draft with no `newProject` is held when its `task.listId` is in `lists`; a draft with `newProject` is held by name as before. `contains(null)` is false, so tasks with no project are unaffected.
- Both callers use the same record: `_save` (:2852-2853) and `build` (:3420-3421), so the button and the save agree.
- With only «Repasar el tema 3» (fyq): `ready == 0`, the asking view isn't `actionable` (capture_command_cards.dart:77-80), so the label is `captureCheckDetails` «Revisa los detalles» (:3477-3478) and `onSave` is null (:3513-3514). After «Crear «Química»» or «Física y Química» the view stops blocking and the task is ready.
- Mixed case («Comprar pan» too): button on, only «Comprar pan» saves; `remaining` (:3017-3019) counts the held task and the open command, so the sheet stays with the question card.
- Tests: :4250-4275 (off, a tap saves nothing, chip turns it on), :4278-4296 (Física y Química keeps fyq, no project created), :4298-4320 (mixed), :4322-4346 («Ya tienes «Matemáticas»» still saves at the first tap). Original failing test at :3439 is the same scenario.

### UX-1219 · S1 · fixed
- `chooseTaskList` (App/lib/widgets/task_list_picker.dart:28-35) has `selectedNone` (default true), documented at :26-27; the «Sin proyecto» row is `selected: selectedNone && listId == null && newName == null` (:59).
- `ProjectChoices`' «Otro proyecto…» passes `selectedNone: false` (capture_command_cards.dart:293-298): no row is highlighted while the question is open. Tapping «Sin proyecto» still returns `(project: null)` → `onNone` (:300-304).
- `TaskListPicker._choose` (task_list_picker.dart:121-126) keeps the default, so a task with no project still shows «Sin proyecto» chosen.
- Test: :4349-4404 (no row selected; «Sin proyecto» clears the question and saves with no project).

### Regressions
None found in voice_task_screen.dart, task_list_picker.dart or capture_command_cards.dart for the flows they touch (result card save, project question, project sheet from the card and from the chip).

Note, not a regression: a task the user explicitly said for «Física y Química» in the same dictation as «crea el proyecto Química» is now held too. That matches what «Crear «Química»» does to it (`_changeCommand` moves every pending draft in the matched project, P135), so holding it is consistent.
