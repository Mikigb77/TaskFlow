## UX verify — run 2026-10-28-app, b1 round 1, area B (P268, P269, P270, P276) — 2026-11-01

**Verdict:** all nine findings are fixed. No regressions in the changed files or the flows they touch. There is one polish caveat on UX-2401 (the first frame while the alerts are read), and it needs a device check.
**Evidence levels:**
- Code read at `8064257..working tree`: the packages are in b0de7c8, and this round's own edit is `git diff HEAD -- App/lib/screens/calendar_screen.dart`.
- The testers' acceptance groups (listed in the delegation), all passing.
- Renders from 2026-11-01 02:34–02:39, with AUDIT. `find App/lib App/assets -newer` against `calendar/agenda.busy.es.light.1x.png` and `tasks/detail.alert-rang.es.light.1x.png` returns nothing, so the renders are current.
- No device evidence.

### Findings

**UX-2301 · fixed** (P268)
- `App/lib/providers/task_provider.dart` now ends each of these with `if (mounted) await showLocal();` instead of awaiting `loadTasks()`: `moveToList` :124, `rescheduleTask` :143, `changeOccurrence` :195, `setCompleted` :232, `setChecklistCompleted` :257 and `restoreTask` :279.
- `showLocal` (:76-87) reads the phone's database, sets the state, and starts `loadTasks()` unawaited. `_mutate` (:126-131) still serializes the writes, and none of them waits on the network. The repository writes are local (`cloud_task_repository.dart:27-35`).
- `TaskInteractions.toggle` (`task_interactions.dart:21-31`) gets the haptic and «Tarea completada · Deshacer» right after the local write.
- `showFeedback` returns its controller without waiting for the bar to close (`app_components.dart:11-35`). So `confirmDismiss` lets a swiped row spring back at once.
- A background failure still only sets `syncError` (:64-68).
- Tests: `calendar_feedback_test` (4), `task_detail_test` and `sync_test`, all with a hanging sync.

**UX-2302 · fixed** (P269)
- `calendar_screen.dart:1018-1049`: the day's own rows come first. The divider (:1050-1054) sits between them and «Atrasadas · N» with its rows (:1055-1085), then the phone's events and «Sin fecha · N».
- Render `calendar/agenda.busy.es.light.1x.png`: «Reunión con el tutor de Lucía…» shows whole under «Agenda de hoy», and «Llamar al médico…» starts above «Añadir tarea».
- AUDIT's TalkBack order lists today's rows first.
- Test: three overdue tasks and two of today's.

**UX-2303 · fixed** (P269, WD34)
- `calendar_screen.dart:743-744`: `lastOpen = total - completed == 1`, where `total` and `completed` include today's overdue rows. It is passed to the day's rows (:1038-1045) and to the overdue rows (:1078-1079), open rows only.
- `task_tile.dart:215-220`: the circle (:297) and a swipe right (:245) both use `toggle()` with `doneMessage: dayAllClear`. Every other caller keeps «Tarea completada», and reopening keeps «Tarea reabierta».
- ARB: ES «Todo listo. Respira.», EN “All clear. Take a breath.”, CA «Tot fet. Respira.», with the @description.
- Renders `calendar/agenda.all-clear` (es 1×, es 2×, ca 2×): the line is whole with Deshacer / Desfés, and the struck-through rows are in place. At 1× the count line reads «0 pendientes · 2 completadas», which P279 changes later.

**UX-2304 · fixed** (P269)
- `_overdueSeen` (:57-59) and `_withTicked` (:473-510) keep a ticked overdue row under «Atrasadas», struck through, sorted as before.
- `completed` counts the day's rows and the overdue ones (:737-740), and the heading counts the rows it lists: `overdueCount(overdue.length)` (:1066).
- The sets are cleared on a day change (:103-107) and when Calendar is covered or another tab is shown (:680-685, this round's `Visibility.of`). That last case meets "switch tabs and back: it's gone": inside the shell's IndexedStack, tickers keep running.
- Completadas: `_doneHere` (`completed_tasks_screen.dart:35-56, :98-100`) keeps a reopened row, unticked, until the page is left or covered. The count line hides when every row was reopened.
- Tests: 4, plus the merged-checkout pass the delegation reports.

**UX-2307 · fixed** (P276)
- `home_screen.dart:238-264`: `_land` tries the page as it is, then each wider step. When none of them lists the task, `_landOnCalendar` (:296-317) pops to the first route and sets `CalendarFocus(day, ids, showCalendar: true, undated: …)`, as the Día view does, and carries a scope widening over for Deshacer.
- Both save paths publish the focus after the task is in state: the form calls `await notifier.showLocal()` (`task_editor.dart:614`), and capture does the same (`voice_task_screen.dart:3330`). So a page that can list the task never wrongly jumps.
- Notes never reach `_land` (`voice_task_screen.dart:3338`).
- Tests: `capture_landing_test` (2) and `new_task_form_test` (1).

**UX-2308 · fixed** (P276)
- `Task.undated` (`models/task.dart:183-185`) means neither a day nor a deadline. Calendar's count uses it (`calendar_screen.dart:710-712`), and so do the Sin fecha page and Tareas' chip (`home_screen.dart:151`).
- The landing keeps its own, equal rule (`voice_task_screen.dart:3409`) and `CalendarFocus.undated`.
- No copy changed. Tests: 2.

**UX-2401 · fixed** (P270)
- `ReminderEngine.alertsOf` and `lastAlert` (`reminder_engine.dart:319-387`) read `reminder_state` joined with `reminder_snoozes`. They count only a row that was set (scheduled, approximate or elapsed, with no error) for the task's current anchor and firing. So D1's "saved too late" still gets null.
- `reminder_control.dart`: `rang` (:675, :876) is read only when the alert has passed. The chip (:690-701) and the form's row (:909-917) show `reminderSent` or `reminderSnoozed` with the normal bell; a rung plan shows `reminderPlanLast`. The tap is unchanged.
- Renders:
  - `tasks/detail.alert-rang.es.light.1x`: «Recordatorio enviado: hoy, 09:40» with the plain bell.
  - `tasks/detail.alert-snoozed.ca.light.2x`: «Recordatori ajornat: avui, 09:51».
  - `tasks/detail.alert-passed` keeps D1's line.
- Caveat (polish, not a regression): `_alertsProvider` is a `FutureProvider`. While it reads (`valueOrNull == null`, :101-103), the chip shows D1's «Sin recordatorio: ya ha pasado la hora del aviso» with the crossed-out bell for the first frame or two after the page opens from the notice. A database read takes milliseconds, so this may not be visible.
- Device check: the emulator lane's "reminder rings → tap the notice" capture, which the package already lists, also confirms there's no visible flash.

**UX-2411 · fixed** (P270)
- `reminder_control.dart:684-688`: the chip's value counting from the task's day is the plain lead. Counting from the deadline, it reads `reminderBeforeDeadline`: ES «{lead} · fecha límite», EN “{lead} · deadline”, CA «{lead} · termini». It isn't concatenated.
- The «Planificado para ·» prefix is gone. `plannedFor` is now used only by the details card and the planning control.
- No render. Tests: 3.

**UX-2206 · fixed** (P270)
- `reminder_control.dart:918-935`: `named` covers a reason, a passed line, a rung line or a plan, and shows that line as the row's only text, with `subtitle: null`. A single reminder keeps «Recordatorio» over its value.
- Render `reminders/capture-card.plan.es.light.2x`: «Recordatorios: cada 3 días, y a diario la última semana…» beside the bell, with no title above it.
- AUDIT `reminders/capture-card · plan`: TalkBack reads the button once.
- `form/new-task.details.es.light.1x` still shows «Recordatorio / Desactivado».

### Regressions
None.
- This round's `calendar_screen.dart` edit:
  - The `Visibility.of` clear defaults to true outside the shell.
  - `_end` is still reset only when Calendar is covered.
  - `_dayHeading` only narrows the landing scroll target, `upTo`, when the heading fits.
- The new page-to-Calendar landing can't trigger on root Tareas for a listable task, because both save paths call `showLocal` first.
