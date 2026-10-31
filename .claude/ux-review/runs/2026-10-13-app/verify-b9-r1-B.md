## UX verify — 2026-10-13-app, round 1 (b9), area B — 2026-10-14
**Verdict:** Ship. P113 closes both lost-text cases; no regression found in the changed flows.
**Scope:** P113 (UX-624). Diff read: `App/lib/widgets/checklist_editor.dart`, `stepLimit` in the three ARB files. Hosts read: `App/lib/widgets/task_editor.dart:549-677`, `App/lib/widgets/capture_review_editor.dart:561-676`.
**Evidence level:** code plus ux-tester's widget tests (pass). No preview renders the steps editor at the limit or the ⋮ menu, so no render was used. Current renders (2026-10-14 20:46-20:47) don't show this state.

### UX-624 · fixed
- **Case 2: removing the last step through ⋮ in the short form.** Fixed. `checklist_editor.dart:209-225` now starts from `widget.items` (the current list, not the list captured when the row was built) and finds the step by id. Text still in `Añadir paso` is added as a step before `onChanged`, so the text survives even when the host hides the editor (`task_editor.dart:593` shows it only while `_checklist.isNotEmpty`). The guard `changed.length < _maxSteps` stops a 51st step. If the popup's focus change already committed the text through `_addLeft`, then `_add` is empty and nothing is added twice. Test: `task_editor_form_test.dart:593` checks that the text is kept exactly once.
- **Case 1: text typed at the 50-step limit.** Fixed. `checklist_editor.dart:232` keeps the field while it holds text. `:245-248` shows `stepLimit` under the field. `_addStep` (`:70-72`) returns without clearing the text. The editor uses the GlobalKey `_steps` in both TaskEditor positions (`task_editor.dart:595`, `:673`), so its state, including the typed text, survives Más/Menos detalles. Copy: EN `A task can have up to 50 steps. Remove a step to add this one.` / ES `Una tarea puede tener hasta 50 pasos. Elimina uno para añadir este.` / CA `Una tasca pot tenir fins a 50 passos. Treu-ne un per afegir aquest.` All three are plain, don't blame the user, and say what to do. Tests: `checklist_test.dart:139` (es, ca) and `task_editor_form_test.dart:651`.

### Regressions: none
I checked these and found nothing the change broke:
- **Move up/down through ⋮ while text is typed:** the text becomes a step at the end of the list. That's the same result as leaving the field (`_addLeft`), so behaviour is consistent.
- **The capture result card** (`capture_review_editor.dart:562/669`, same GlobalKey `_steps`): after the last step is removed, the typed text becomes a step, so the editor stays where it was. The fix applies here too.
- **At the limit, after the person clears the text,** the field disappears (`:251-253`) and the keyboard closes. That's the same as the old state at the limit, with no field. I'm noting it, not reporting it.
- **The error style at the limit** (red outline, `errorMaxLines: 5`) is used only in this rare state. Five lines is enough for the Catalan text at 2× on a 320 dp screen, judged from code.

### Pre-existing, not caused by this change (not a regression)
- Opening ⋮ takes focus from `Añadir paso`, so `_addLeft` commits the typed text as a step before the person picks anything, even if they then dismiss the menu. This behaviour comes from the P112 rule "leaving the field keeps it".
- At the limit, Save closes the editor and the text still in the field is discarded. The person has already been shown `stepLimit`, so the loss isn't silent. P113's acceptance checks don't cover Save.
