## UX verify — run 2026-10-18-commands, round 1, area A (P135–P138) — 2026-10-18

Evidence: code (`git diff HEAD`), ux-tester's widget tests, and current renders
`build/capture-fill-by-hand-es.png`, `build/capture-listening-es-2x.png`, `build/review-direct-light.png`
(all 22:03–22:05 today, newer than the code). I didn't run Flutter.

### Results

| ID | Result | Evidence |
|---|---|---|
| UX-908 | fixed | `capture_review_editor.dart:285` puts «¿En qué proyecto la pongo?» in `QuestionBox` (`capture_command_cards.dart:200`). `ProjectChoices` shows Crear, then at most 3 similar projects (`similar = 3`), then «Otro proyecto…» only when other editable projects exist (`:265`), opening the shared `chooseTaskList` sheet (`task_list_picker.dart:26`), then «Sin proyecto». That's at most 6 chips. Tests pass. Phone check with the real model is still open. |
| UX-909 | partly | The question, the chips and both answers work (`capture_command_cards.dart:108-119`, `capture_command.dart:303-318`, `voice_task_screen.dart:2366-2415`). **But the confirming button doesn't wait.** The server filed the dictation's task in «Física y Química», so the task has no `newProject`, `_draftReady` (`voice_task_screen.dart:2429`) counts it as ready, and `onSave` (`:3501`) checks only `ready`/`actionable`, never `blocking`. One tap on «Añadir tarea» files the task in Física y Química while the question is still unanswered, and the question is left waiting under «Sin guardar». The tester's test fails. |
| UX-915 | fixed | The day question now sits in `QuestionBox` (`capture_command_cards.dart:968-1015`) and reads «¿Qué día, a las 17:00?» / «a la 01:00» (`_whichDay`, `:834`, with the hour as shown, 12- or 24-hour). The «Elegir día» chip shows `weekdayDate` and is selected for a day other than today or tomorrow. On a 24-hour phone, 1:00 is written «01:00», as the app writes every time. |
| UX-914 | fixed | Three dead ends are gone: «Ver N más» is a `TextButton` that lists every match (`:779-793`); the view-only line comes from `viewOnly` (`:136-146`, `:823`); same-name people get one `ChoiceChip` each in a `QuestionBox`, the tap is stored in `memberId`, and the plan resolves it (`command_plan.dart:257-280`). The search card's «Y N más» is unchanged. |
| UX-907 | fixed | `_findScope` (`:616-632`) adds the line under the heading: «Mañana», «Del … al … · Pendientes». It's null when the search has neither a period nor a status. The headings `commandFindProjectMine` and `commandFindProjectPerson` come before the project-only heading (`:552-565`). |
| UX-913 | fixed | `_FoundRow` no longer has the circle or tick. It has a 34 dp indent and a trailing `chevron_right_rounded` at size 20 (`:675-707`). Done tasks still show strikethrough and «Completada». |
| UX-916 | fixed (within P137) | ES «Tareas para», EN “Tasks for”; `commandExistingProjectTasks` is a plural driven by `taskCount`; the EN «Which one do you want…» strings are in; the priority line uses `flag_outlined` (`:1025`). The notice body (P140) and the new-project chip (P141) are left to their own packages. |
| UX-911 | fixed | The free account's keyboard button reads `captureTypeInstead` with `keyboard_outlined` (`voice_task_screen.dart:2157-2161`); render `capture-fill-by-hand-es.png` shows «Escribir». «Listo» always reads `done`. `captureFillByHand` is gone from all three ARB files. A free account's shared or typed capture is routed to the form through `_typedWords` (`:78-108`, `:141-164`). |
| UX-910 | fixed | `askedToSpeak` goes through `openTaskForm` → `NewTaskArguments` → `TaskEditor`. `_noMic` (`task_editor.dart:1062`) shows the used-up line or `captureSpeakingIsPro`, plus «Ver Pro», above the title, every time (`:727-730`). Phone check with the real widget is still open. |
| UX-1005 | fixed | The form keeps the title and notes in the capture store: a capture is created at the first character typed and updated as the person types (`task_editor.dart:180-230`). It's discarded on save (`:552`) and on Back with an empty title (`:443`). «Escribir» hands its capture over (`voice_task_screen.dart:1565-1582`, `_toForm`). Phone check for «No mantener actividades» is still open. |
| UX-1011 | fixed | `main.dart:204` passes `showCalendar: true` for the widget, shortcut and share entries. |

### Regressions

**Not a regression: the fix for UX-909's open half** (I report it under UX-909, not as a regression).
Fix: count the dictation's tasks that sit in the matched project of an asking `project` card as undecided. In `_undecided`, also collect the `existingListId` of every `view.kind == project && view.blocking`. In `_draftReady`, a draft with no `newProject` whose `task.listId` is in that set isn't ready. The button then reads «Revisa los detalles» and stays disabled until a chip is tapped. Another way: make `onSave` null while any project view is `blocking`.

**R1A-1 · Severity 1 · «Otro proyecto…» sheet highlights «Sin proyecto» as chosen**
`task_list_picker.dart:56`. Called from the task card's «Otro proyecto…» (`capture_command_cards.dart:295-299`) with no `listId` and no `newName`, so the sheet marks «Sin proyecto» as the current choice. But the task is still waiting for an answer, which reads as "it's already in no project". Fix: add a `selectedNone` parameter (default true) to `chooseTaskList`, and pass false from `ProjectChoices`. Then nothing in the sheet is selected while the question is open.

### Checked, no new problem
- The plain one-task capture is unchanged (`review-direct-light.png`).
- The Pro sheet keeps its icon-only keyboard (`capture-listening-es-2x.png`).
- `flag_outlined` on both the deadline and priority lines matches the task-detail screen (`task_detail_screen.dart:296, 327`), and each line is labelled.
- A free account's share or «Sin guardar» capture can still show the monthly used-up notice before the form. That notice already appears at every way into the form, so it isn't new to this change.
