# UX loop run 2026-11-01-screens: report

**Verdict:** All done in one round. The 4 packages (P314–P317) fixed all 7 findings, the reviewer found each one fixed, and all tests passed. There were no regressions and no escalations. One finding is verified outright (UX-2645). The other six are verified in code, and their device checks still need the emulator and then the phone. I filed one new polish finding from a reviewer note (UX-2648).

## Verified
- **UX-2645** · S1 · B · The remove-file dialog's help line now says «Se quitará» instead of «Se eliminará». The ES `fileRemoveHelp` reads «Se quitará de la tarea y, si lo has subido, de tus otros dispositivos al sincronizar. Tu archivo original no se elimina.» The render `tasks/detail.remove-file.es.light.1x` shows it. EN and CA are unchanged. (P315, verify-r1-B)

## Verified in code, device check pending (ledger: Device check)
- **UX-2643** · S2 · A · An entry from outside the app no longer closes a titleless form that holds a date or a photo.
  - A blank entry form now records whether it is still as it opened (`NewTaskRoute.untouched`, kept current by `_markRoute`).
  - An entry closes such a form only when nothing in it changed (`main.dart:226`). An open «Más detalles» or a file pick in progress counts as changed.
  - (P314, verify-r1-A)
- **UX-2644** · S1 · A · Voice, then text, then voice no longer stacks two voice sheets. When closing the top form or sheet uncovers a voice sheet, the app checks again and lands in that paused sheet instead of opening a second one (`main.dart:206-232`). (P314, verify-r1-A)
- **UX-2646** · S1 · B · Ticking a reopened task on its own page now keeps its old completion time. Completadas' rows pass their remembered time to the task page, and «Completar» there uses it. Task pages opened from anywhere else still record the current time. (P315, verify-r1-B)
- **UX-2647** · S1 · C · «¿Quién es responsable?» and «Novedades del proyecto» are now real headings (titleMedium, 24 dp inset). The project name is read separately, after the heading. The updates sheet now has the same 70% height cap as the assignee sheet. The renders and AUDIT confirm the heading is read first. (P316, verify-r1-C)
- **UX-2634** · S1 · D · The form's «Añadir al calendario» / «Afegeix al calendari» button now centres its wrapped label at 2×, with the ✓ beside it. (P317, verify-r1-D)
- **UX-2635** · S1 · B · The task page's reminder chip now fits its width to its longest line and centres the label when the chip can be tapped. A chip that can't be tapped stays left-aligned. (P317, verify-r1-D)

## Still open
- **UX-2648** (new) · S1 · B · Reminder chip wraps to two lines at ES 1×. On a 360 dp screen, «Sin recordatorio: ya ha pasado la hora del aviso» wraps because the label is capped at the screen width less 80 dp (about 232 dp). P317 didn't cause it; it was already true. There are two possible fixes: shorten the ES copy, or loosen the 80 dp cap now that the bell's box is a fixed 20 dp. Filed from verify-r1-D note 1. A future run plans it.

## Escalations
None.

## Checks for the owner's phone (the TaskFlow_Review emulator first, then the phone)
1. **UX-2643**, free account with dictations left:
   - Open «Escribir una tarea» from the launcher shortcut, tap «Mañana» without typing a title, go Home, then tap the widget's mic.
   - The listening sheet should open over the form. «Cancelar» should show the form with «Mañana» still chosen.
2. **UX-2643**, free account with 0 dictations left:
   - Same steps: the shortcut's form, «Mañana», Home, then the widget's mic.
   - A second form should open saying no dictations are left. Back should show the first form with «Mañana».
3. **UX-2644**, Pro account, only if online listening can be forced:
   - Tap the widget's mic and say a few words, go Home, tap «Escribir una tarea», go Home, then tap the mic again.
   - One sheet should show, with «Grabación conservada en este teléfono». «Cancelar» should ask whether to keep or discard the recording.
4. **UX-2646**, emulator with the local API at migration 0026:
   - On Completadas, reopen a row that isn't the newest, open its page, then tap «Completar».
   - The row should keep its place on this visit and the next. After a sync, the server's `completed_at` should still be the first completion's time.
5. **UX-2647**, with TalkBack on: TalkBack should read «¿Quién es responsable?» and «Novedades del proyecto» as headings («encabezado»), and moving by headings should land on them.
6. **UX-2634 and UX-2635**, at Android's largest font (2.0, non-linear), on a 360 dp screen, in Catalan:
   - Check the form's «Afegeix al calendari» button and a task page's reminder chip.
   - If either wraps, its lines should be centred with the icon beside them. If non-linear scaling keeps them on one line, that also passes.
7. The P313 checks for UX-2110, UX-2641 and UX-2642 still hold.

## Files changed
- App/lib/main.dart
- App/lib/screens/edit_task_screen.dart
- App/lib/screens/task_detail_screen.dart
- App/lib/widgets/task_editor.dart
- App/lib/widgets/task_list.dart
- App/lib/widgets/task_tile.dart
- App/lib/widgets/project_preferences.dart
- App/lib/widgets/task_assignment_picker.dart
- App/lib/widgets/reminder_control.dart
- App/lib/l10n/app_es.arb
- App/lib/l10n/generated/app_localizations_es.dart (regenerated)
- App/test/capture_free_dictations_test.dart
- App/test/capture_sheet_test.dart
- App/test/attachment_panel_test.dart
- App/test/calendar_feedback_test.dart
- App/test/project_scope_control_test.dart
- App/test/reminder_plan_sheet_test.dart
- App/test/new_task_form_test.dart
- App/test/task_detail_test.dart
- App/test/ux_previews/sharing_previews.dart
- App/test/ux_previews/tasks_previews.dart
- .claude/ux-review/ISSUES.md

## Tests that now protect the verified findings
All 7 findings have a widget test.
- **UX-2643**: `App/test/capture_free_dictations_test.dart`, group P314 (5 tests).
- **UX-2644**: `App/test/capture_sheet_test.dart`, group P314.
- **UX-2646**: `App/test/calendar_feedback_test.dart`, group 'P315 · the task page' (4 tests).
- **UX-2645**: `App/test/attachment_panel_test.dart`, group 'P315 · the task page' (3 tests).
- **UX-2647**: `App/test/project_scope_control_test.dart`, group 'P316 · picker headings' (8 tests).
- **UX-2634**: `App/test/new_task_form_test.dart`. The check allows the label to sit within 2.5 dp of centre, because the rest is Flutter's own padding.
- **UX-2635**: `App/test/reminder_plan_sheet_test.dart` and `App/test/task_detail_test.dart`. reminder_plan_sheet_test was fairly updated so it checks only visible characters.

## Rounds
- **Round 1:** P314, P315, P316 and P317 all done, in 2 waves (3 packages, then 1). Tests passed. The reviewer found all 7 findings fixed, with no regressions and nothing left unchecked (verify-r1-A, verify-r1-B, verify-r1-C and verify-r1-D). No acceptance check was device-only.

## Notes
- The ledger lines for UX-2110, UX-2641 and UX-2642 said their regressions UX-2643 and UX-2644 were still open. I updated them to "closed in code (P314), device check pending".
- verify-r1-D note 2 is not filed. At linear 2× the ✓ and the bell stay 16–18 dp while the text doubles. It predates P317, the task page's buttons do the same, and the reviewer didn't call it a finding.
- verify-r1-C has a nit that isn't a UX finding: project_scope_control_test.dart has a double blank line before the P316 group.
