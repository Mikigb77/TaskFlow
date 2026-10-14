## UX verify — 2026-10-13-app, round 1, area B (P21, P22, P23) — 2026-10-14
**Verdict:** Ship after fixes. All ten findings are fixed in code. One regression drops a typed step in the capture sheet (R1B-1, severity 3), and needs fixing first.
**Evidence used:** `git diff HEAD` of the changed files, the current code, and the renders re-made at 18:33 (newer than main_shell.dart 18:02 and calendar_screen.dart 17:45): `App/build/calendar-feedback-light.png`, `calendar-es-1.3x-dark.png`. No preview covers TaskEditor or the timeline, so those verdicts rest on the code and the tester's widget tests.

### Results
| ID | Result | Evidence |
|---|---|---|
| UX-215 | fixed | `task_editor.dart:432-459`: the headline and help line are gone, `seriesEdits` shows only when `widget.task.isRecurring`, and the project row shows only when the task has a project or a project exists. The title field is now the first thing in the form. Autofocus doesn't apply: the form only edits now (P38). |
| UX-216 | fixed | `task_editor.dart:591-781`. The order is Recordatorio (595), Repetir (605), Pasos (661), then duration and deadline (669), priority, labels and files. Gone: `durationEstimateHelp` and `deadlineHelp` (`task_planning_control.dart:122,139`), `fileLocal/UploadHelp` and `fileManageHelp` in the form, and the `planning`/`theDetails` section labels. Without a date, Repetir is a disabled ListTile reading `repeatNeedsDate` (608, 613). No `MiB` is left in any catalog. My count is about 30 words with a date, against about 100 before. The upload sentence still appears in the attach sheet (`:350-356`), where it is relevant. |
| UX-222 | fixed | `checklist_editor.dart:215-232`: an inline `Añadir paso` field. Enter adds the step and keeps focus (`onEditingComplete: (){}`, `_addStep` → `requestFocus`). The dialog and its strings (`addStepDialog`, `step`, `shortStep`, `keepStep`) are deleted. Renaming is now inline too (156-170). One new loss path, though — see R1B-1 and R1B-2. |
| UX-227 | fixed | Summary chips → one `onSurfaceVariant` text line (`task_editor.dart:562-582`). `Quitar fecha` is removed; `_pickDate` still clears the repeat when the sheet returns no date (`:166-170`). EN `labelLimit` reads `up to 32`. CA `reschedule*` reads `Canvia la data…`. The calendar arrows `jumpToPage` and `pageAnimationEnabled: !instant` follow `disableAnimationsOf` (`calendar_screen.dart:199-215, 331, 499-526`). `createTask` no longer exists (P38), so it's n/a. |
| UX-225 | fixed (TalkBack device check open) | ES/CA `checklist`/`checklistSemantics` read `Lista de pasos`/`Llista de passos`, and `notesEmptyHelp` says `lista de pasos`. `archived` is masculine and only labels projects (`task_lists_screen.dart:146,282`, `task_list_picker.dart:68`). Other fixes: `Actualízalo`, `si ya no lo necesitas`, `proyecto compartido`, CA `Actualitza’l … suprimir-lo`, `compartit`, `Modificat`. `removeFileNamed` is in all three catalogs (`task_editor.dart:761`). `agendaCounts` takes plurals; the render reads `0 pendientes · 1 completada` and `3 pendientes · 1 completada`. `repeatEvery` is now select+plural on the frequency (`region.dart:75`, `repeat_rule_control.dart:33`). |
| UX-122 | fixed | CA `reviewRepair` reads `Corregeix el text`, `reviewEditDetail` `Canvia aquesta dada` and `reviewOriginal` `Mostra què he dit`; `reviewRemove` was already `Treu`. A grep found no leading infinitive left on the CA review keys. |
| UX-123 | fixed | `captureKeptForReview` takes ICU plurals in EN and CA (`app_ca.arb:720`, `app_en.arb:1369`). |
| UX-223 | fixed (device check open) | `main_shell.dart:97-102`: `PopScope(canPop: _index == 0)` selects Calendario on the other tabs. No other in-tab PopScope competes; the editor, the login screen and the capture sheet are their own routes. Reminders: `main.dart:275-283`. A missing task no longer pushes MainShell; it shows `taskRemoved` through `showFeedback`. |
| UX-224 | fixed | The timeline arrows use `previousDay`/`nextDay` (`day_timeline_screen.dart:162,170`), and `timelineHelp`/`timelineShortBlocks` are removed from the code and the ARBs. The `+` part is n/a: no add button is left in the file. |
| UX-433 | fixed | `main_shell.dart:126-138`: `DecorationPosition.foreground`. In the 18:33 light render a 1 px line shows along the bar's top edge, and the tester decoded the pixels in both themes. |

### Regressions
**R1B-1 · Severity 3 · Capture sheet drops a step typed without Enter**
- Where: `App/lib/widgets/checklist_editor.dart:53-72` and `App/lib/screens/voice_task_screen.dart:2121-2134` (`enabled: !_saving` at `:2503`). The capture sheet's result card, with a step typed in `Añadir paso`.
- The moment: "I wrote 'llevar pasaporte' as a step and pressed Guardar, and it isn't there."
- What happens: the old dialog made a step explicit. The inline field doesn't. On Android a touch outside the field doesn't move focus, so tapping `Guardar` leaves the text sitting in the field. `_save` then sets `_saving`, the editor is disabled (`onChanged: null`), and the field loses focus. `_addLeft` → `_addStep` clears the text and calls `widget.onChanged?.call(...)`, which is now null. The step is thrown away silently, and the saved draft list was read before that anyway. TaskEditor guards against this (`task_editor.dart:257-263`); the sheet doesn't.
- Why it fails: input is lost without notice (Nielsen 2001: always keep what the user typed). The newcomer doesn't know Enter is required, because the field has no visible add button.
- Fix: in `_addStep`, return without clearing when `widget.onChanged == null`. In the sheet's `_save` (and `_saveAsWritten` if it can see a card), unfocus and await one microtask before reading `_items`, as `TaskEditor._save` does.
- Verify: a widget test in review_tasks_test. Type `Passport` in `add-checklist-item` on a card, tap `save-drafts` without Enter, and check that the saved task's checklist holds `Passport`.
- Evidence: verified in code (control flow). The behaviour of a touch outside the field should be confirmed by that widget test.

**R1B-2 · Severity 2 · Toggling Más detalles erases a half-typed step**
- Where: `App/lib/widgets/task_editor.dart:583-589` (collapsed) and `:661-666` (expanded). Editing a task that already has steps.
- The moment: "I was writing a step, opened Más detalles to add a reminder, and what I wrote vanished."
- What happens: the two `ChecklistEditor`s carry no key and sit at different places in the Column. Toggling disposes one and builds the other, which loses the field's text and focus. The disposed field's listener is removed first, so `_addLeft` never commits the text. `capture_review_editor.dart:45-47` already fixes the same move with a shared `GlobalKey`.
- Why it fails: the typed input is lost (Nielsen 2001).
- Fix: give both `ChecklistEditor`s in TaskEditor one `GlobalKey`, as the capture card does.
- Verify: a widget test. On a task with one step, type `Coat` in `add-checklist-item`, tap `task-more-details`, and check that the field still reads `Coat` (or that the step was added).
- Evidence: verified in code (keyless element reconciliation).

### Notes (not regressions)
- `task_editor.dart:442-444`: the project row waits for `taskListsProvider` (a FutureProvider). If it hasn't loaded yet, the row can pop in above the title one frame later. In practice the provider is cached from the Tareas tab, so this doesn't count as a finding.
- The disabled Repetir hint draws at the disabled opacity. WCAG exempts inactive controls, and the tile still reads as "Repetir, Añade una fecha para repetir, disabled".

### Memory notes
- The checklist pattern is now: an inline `Añadir paso` field (Enter adds and keeps focus; leaving the field commits), inline rename, and a ⋮ menu to edit, move or remove. A host that moves the editor between branches must share a GlobalKey, and a host save must unfocus before it reads the steps.
- MainShell owns Back: other tabs → Calendario. A stale reminder → `taskRemoved` snackbar, with no second shell.
- `repeatEvery(interval, frequency)` is now select+plural; the `days`/`weeks`/… unit words survive only for `repeatEveryPrompt`.
