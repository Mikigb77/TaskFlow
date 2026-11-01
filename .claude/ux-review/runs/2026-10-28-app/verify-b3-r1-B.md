## UX verify — run 2026-10-28-app, batch b3, round 1, area B — 2026-11-01

Packages: P293 (UX-2415, UX-2417, UX-2418), P300 (UX-2311). Mode: verify.
Evidence used: diffs (`git diff HEAD`), current renders (all four checked are newer than every file under App/lib and App/assets), AUDIT.md, and the testers' passing tests. No device.

**Verdict:** Ship. All four findings are fixed. One severity-1 side effect (R1B-1) comes from how the new completion times are stamped.

### Findings

**UX-2415 · fixed**
- `App/lib/widgets/checklist_editor.dart:141-198`: each step's checkbox and title now sit in one `MergeSemantics` (`_mergeUnless`, :281-283), and the title `Text` is in `ExcludeSemantics` (:189-193). While the step is being renamed, the merge is off, so the rename field is still its own node. The ⋮ `PopupMenuButton` stays outside the merge.
- AUDIT `form/edit-task · existing`, what TalkBack reads (es.light.1x): #11 checkbox «Meriendas» [checked], #12 button «Editar Meriendas», #13 checkbox «Chaquetas», #14 button «Editar Chaquetas». There is no separate «text Meriendas» node.
- The render `form/edit-task.existing.es.light.1x` (12:09) looks the same as before.
- AUDIT now reports the merged node as 264 dp wide, with a 0 dp gap to ⋮. That is the TalkBack focus rectangle. The title text has no tap handler, so a sighted person still taps only the 48 dp checkbox and the 48 dp ⋮, as before. Whether TalkBack reads the step once still needs a device check.

**UX-2417 · fixed**
- `App/lib/widgets/reminder_ask_sheet.dart:395-397, :425, :484-486, :501, :507`: the day phrase (`weekdayDate` of the planned day, or of the deadline) is bound with U+00A0 before the fit is measured and in the cut title too. The TalkBack label (`full`) keeps the plain text.
- Render `reminders/offer.asked.es.light.1x` (12:08): «Presentar el proyecto de empresa · / dom, 22 de nov», with the day whole on line 2.
- Render `reminders/offer.asked.ca.light.2x`: «Presentar el proy… · / dg., 22 de nov.», whole.
- When the line shows «Hoy» or «Mañana» rather than a date, `replaceFirst` finds nothing to replace and the line is left as it is, which is harmless.

**UX-2418 · fixed**
- `App/lib/l10n/app_es.arb:404, :406`: `fileRemove` «Quitar archivo», `fileRemoveQuestion` «¿Quitar este archivo de la tarea?». EN (`app_en.arb:882, :892`) and CA (`app_ca.arb:383, :385`) are unchanged.
- Render `tasks/detail.remove-file.es.light.1x` (12:09): the title «¿Quitar este archivo de la tarea?», the button «Quitar archivo» in the error colour, and «Cancelar».
- The same key also labels the file's menu entry (`attachment_panel.dart:442`), so the menu and the dialog agree.

**UX-2311 · fixed** (the app side; the round trip through the server needs the device check)
- Model, `App/lib/models/task.dart`:
  - It adds `completedAt`, `completedTimes` and the getter `completedTime` (:32-45).
  - The constructor keeps a time only while its completion holds (:140-154), so reopening, or a date leaving `completedDates`, drops it.
  - `withCompletionTimes` (:554-578) applies the server's rule: a time the write carries wins, else the stored row's time, else now for a new completion.
  - The fields are read leniently (:586-602) and carried through `copyWith`, `toMap`/`fromMap` and `toApi`/`fromApi`.
- Database, `App/lib/services/task_database.dart`:
  - Schema 21, with the two columns in `onCreate` (:68) and in the `< 21` step (:261-269).
  - `updateTask` stamps the times with a clock tests can set (:25-27, :573-574).
  - `_remoteValues` keeps the phone's times when the server sends neither field (:814-821).
- Notification «Completar»: `App/lib/services/reminder_engine.dart:873-887` writes through the same rule with `clock()`. «Deshacer» reopens the task, which clears the time.
- `App/lib/providers/task_provider.dart:227-237`: `setCompleted` carries the time the passed row had, so Deshacer after a reopen keeps the original time.
- `App/lib/models/task_schedule_change.dart:36-40`: `restore` brings back `before`'s times together with `before`'s dates.
- Order:
  - `App/lib/widgets/task_list.dart:41-62` lists timed rows first, newest first, then untimed rows in the old order: latest planned day first, undated last.
  - `App/lib/screens/completed_tasks_screen.dart:39, :102-104, :141` remembers each row's time when it is first seen, so a row reopened on the page keeps its place (UX-2304 holds).
- Sync: `_sameContent` (`cloud_task_repository.dart:47-105`, unchanged) doesn't compare the times, so a different time is never a conflict.
- Render `calendar/completed.list.es.light.1x` and `2x` (12:10): «Comprar pan» (Sin fecha) first, then «Paseo por el parque» (today), then «Subir las notas» (31 Oct). No row shows a time and there is no new line. The help line and the row layout are unchanged.
- Testers: every acceptance check passes as a widget or unit test (sync_test, reminder_engine_test, archive_test, calendar_feedback_test).
- Still a device check: the TaskFlow_Review emulator lane with the local API at migration 0026. Tick a task offline, sync it later, and confirm the server's `completed_at` is the time of the tick.

### Regressions

**R1B-1 · Severity 1 · A re-completed row jumps to the top of Completadas**
- Where:
  - `App/lib/providers/task_provider.dart:227-237`, with `Task.withCompletionTimes` (`App/lib/models/task.dart:554-578`) and `updateTask` (`App/lib/services/task_database.dart:573-574`);
  - screen: Completadas.
- The moment: "I unticked last month's task by mistake, put it back, and now it's at the top as if I did it today."
- What happens, in two cases:
  1. **Ticking the reopened row's checkbox again,** the way a newcomer usually undoes a mistake, rather than with the snackbar's Deshacer. The page passes the reopened row, which has no time, so the database stamps now.
  2. **A completion from before schema 21, with no time, reopened and then undone with Deshacer.** The write can't say "keep no time", so the database stamps now too. The server's rule does the same.
  
  In both cases the row stays in place while the page is open, because `_doneHere` remembers its old time. On the next visit it is listed first, above what the person really did last.
- Why it fails: user control and freedom (Nielsen 1994). Putting back a mistaken reopen should leave things as they were.
- Fix:
  - For case 1, when Completadas re-ticks a row it reopened itself, pass the time it remembered (`_doneHere[_row(task)]`) as that row's `completedAt` (or as the `completedTimes` entry for its date) to `setCompleted`. That time then wins under the existing rule.
  - Case 2 can't be fixed on the phone alone, because the contract has no way to send "no time". Leave it, or raise it with the server contract. It only affects completions from before the update.
  - No copy needed.
- Verify: on Completadas with three timed rows, reopen the middle one, tick it again, leave the page and come back. The row is in its old place.
- Evidence: verified in code. The tests cover Deshacer for a timed row only.

### Notes
- On the remove-file dialog, the help line still says «Se eliminará de la tarea…». The brief kept that string and the finding didn't cover it, so it isn't a regression. A later polish could make it «Se quitará de la tarea…».
