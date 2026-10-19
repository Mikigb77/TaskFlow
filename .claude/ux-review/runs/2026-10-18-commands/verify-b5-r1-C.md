## UX verify — run 2026-10-18-commands, b5 round 1, area C (P159) — 2026-10-19

**Verdict:** UX-1111 fixed. No regressions in the changed files or the flows they touch.
**Evidence level:** code read (`git diff HEAD`), the ux-tester's widget tests (all pass), and a current render (`App/build/ux/tasks/project.person-form.es.light.2x.png`, 2026-10-19 12:08) with its AUDIT entry. No device check yet; that's left for the owner.

### UX-1111 · S1 · A task added under a person's chip is that person's — **fixed**
- **Ways in carry the person.**
  - `App/lib/screens/home_screen.dart:664-668` passes `_personChip` to `TaskActions`. It does so only on a project page that the user can add to (`addTo == widget.listId`).
  - `App/lib/widgets/task_actions.dart:80,93` passes the person to both `openTaskForm` and `showCaptureSheet`.
  - `App/lib/widgets/task_form_entry.dart` puts the person into `NewTaskArguments`.
  - «Escribir» from the sheet (`App/lib/screens/voice_task_screen.dart:1663-1665`) carries the person only while the sheet's project is still the page's.
- **Form.**
  - `App/lib/screens/edit_task_screen.dart:137-166` makes the task `member` with Ana's id and name, but only when it goes into the page's project.
  - `App/lib/widgets/task_editor.dart:273` keeps a new task's `member` assignment and no longer drops it.
  - The render shows «Matemáticas», then the «Ana ▾» chip directly under it, then «Añadir tarea». TalkBack reads «Matemáticas», then «Ana».
  - One tap opens «¿Quién es responsable?» (test new_task_form_test.dart:859).
  - Choosing another project still resets the person, through `taskWithProject` in `task_assignment_picker.dart:92`. That code is unchanged.
- **Capture sheet.**
  - `_forPerson` (`App/lib/screens/voice_task_screen.dart:1458-1497`) gives Ana each pending draft that meets all of these:
    - it isn't a note;
    - it isn't a new-project draft;
    - it goes into the page's project;
    - its words named nobody: no `member` assignment and no `member` hint.
  - The change is written with `_store.update`, so «Deshacer» restores the card as it was shown (test voice_command_cards_test.dart:5732).
  - It applies on all three paths that produce a result: the assistant's result, «Guardar como tarea» (`asWritten`), and the typed fallback.
  - A person the dictation named wins (tests :5765 and :5788).
  - If the write fails, the result is shown as the assistant gave it, so nothing is lost.
- **Landing.**
  - `_land` (`home_screen.dart:167-223`) is unchanged. Ana's task is still visible under her chip, so the chip stays on and the row is lit.
  - A task changed to «Todos» falls through to the `everyone` step, so the page switches to «Todas» (tests new_task_form_test.dart:811 and :834).
- **Outside a person's chip:** «Todas», «Para mí», Calendar and the Tareas root pass no person (`widget.listId == null`, or `_personChip` is null). A new task stays for everyone (tests :917 and voice :5801). The speed-bar test still passes.

### Regressions
None caused by this change. Checked:
- **Free typed and «Guardar como tarea» saves from the sheet.** These now save as Ana's under her chip. That's consistent with D7, and the person shows on the result before it's kept.
- **«Para mí» opened on a person (P142).** If the person is me, `_person` stays null (`home_screen.dart:78-82`), so no person is passed.
- **Readers.** A reader never gets a chip (`projectPeopleToFilter` keeps only people who can edit), so a task can't be given to someone who can't be its assignee.
- **Assignment for tasks without a person.** `assignment: 'personal'` (`edit_task_screen.dart:163`) is the model's default, and the editor clears it for a new task as before.

Things noted but not new, so not reported as regressions:
- **The caption under the chip.** The form's chip row shows «Ana ▾» above «Visible para todos en Matemáticas» (`task_assignment_picker.dart:183-193`). A newcomer could read the caption as "it's for everyone".
  - The same chip and caption already showed when editing an existing task of Ana's.
  - Now it's what you see by default under Ana's chip.
  - Worth watching on the owner's device check.
- **AUDIT 4 dp gap.** AUDIT flags a 4 dp gap between «Matemáticas» and «Ana». The «Todos» chip sat in the same place before this round, the same pattern as Hoy/Mañana.
- **TalkBack label.** TalkBack reads the chip as just «Ana», with no "who it's for" context. That's the picker's existing label, unchanged here.

### Device check left for the owner
On a phone, open a shared project with two members and turn on a person's chip. Add one task by voice (Pro) and one with the form. Both should be that person's and appear under their chip.
