## UX verify — run 2026-10-19-app, round 1, area B (P176–P180) — 2026-10-20

**Verdict:** Ship after fixes. 15 of 17 findings are fixed. UX-1403 and UX-1421 are partly fixed. The Día view's new opening scroll hides the day's «Sin hora» tasks and its error banners (R1B-1, S2).

**Evidence used:** `git diff HEAD` of the changed files; renders from 13:50–13:51 today (only the generated l10n files are newer, from regeneration; the ARB files are older); ux-tester's results. No Flutter run.

### Results

| ID | Result | Evidence |
|---|---|---|
| UX-1403 | partly | Done: `home_screen.dart:535` «Tus tareas» uses titleLarge; :649-653 «Prioridad alta» shows only when it would find something; :617 and :642 hide the search and chips when `quiet` (`tasks-tab.empty.es.light.1x.png` shows only the headline and the empty state); :639-663 the chips sit in one sideways-scrolling row (2× render: «Priori…» cut at the edge). **Not met:** at linear 2×, ES shows about 70 dp of «Renovar el DNI» and no whole row (`tasks-tab.normal.es.light.2x.png`). In CA, «Les teves tasques» wraps (`.ca.light.2x.png`). At 2×, «Proyectos» and «Completadas» take a row each. At 1×, the canonical render (`tasks-tab.normal.es.light.1x.png`) shows **one** whole row; the second is cut at about 606 dp, because the preview fixture's first row has a priority chip and the second a two-line title. The tester's passing 1× test uses `fx.busyDay()`, not this fixture. Still to check: the emulator lane at 393 dp and non-linear 2.0. |
| UX-1502 | fixed | `home_screen.dart:648-660`: FilterChips «Sin fecha», «Hoy», «Prioridad alta», no `allTasks` chip, and a second tap goes back to 0. Tests check the selected state in es, en and ca. |
| UX-1406 | fixed | `home_screen.dart:170-209` keeps rows ticked on this page, struck through, through `_rows`/`_openHere`. The set is cleared on a tab switch (:411), a scope change (:414), when the page is covered (:418), and on search or filter (`_refilter`). Tests cover the root, a project page and Sin fecha. |
| UX-1407 | fixed | Root: a labelled TextButton «Completadas», 8 dp from «Proyectos» (:551-558; 1× render). Project page ✓ → `CompletedTasksScreen(listId, team, person)` (:459-471). Sin fecha has no ✓ (:489; `tasks-tab.inbox.es.light.1x.png`). `progressHeading` is gone (`completed.list.es.light.1x.png`). See R1B-3 and R1B-4 for the scoped page. |
| UX-1505 | fixed (needs device) | `task_database.dart:404-420` has one shared `reminderBlock`. `reminder_control.dart:79-101` `_reasonFor` feeds the chip (:288-341) and the form row (:381-420). Muted opens `showProjectPreferences`; archived has no action. Tests pass in 3 languages. Device: the assignee's phone rings. See R1B-2 on the value shown. |
| UX-1413 | fixed | `reminder_control.dart:197-220` puts the default first as «value · predeterminado» and drops its twin (7 → 6 rows). A date-only task gets a default row only when `defaultTime` is set. :268 opens the picker in `TimePickerEntryMode.input`. :417-419 shows the chevron whenever the row can be tapped. `useDefault` was removed from all 3 catalogs. |
| UX-1416 | fixed (needs device) | `task_tile.dart:203-221`: editable rows carry a CustomSemanticsAction «Cambiar fecha». View-only rows are one button with no circle, title first; the label also lists the row's details («Comer con Ana, Hoy · 13:30, Responsable: Todos»), which I accept. Device: the TalkBack actions menu. See R1B-5. |
| UX-1418 | fixed | `task_tile.dart:46-58` `_dateLine`: Calendar date-only rows have no line (`agenda.added.es.light.1x.png`: «Comprar pan y leche» shows its title only); Sin fecha rows have no «Sin fecha» (`tasks-tab.inbox.es.light.1x.png`). `agendaCounts` has `=0` in all 3 languages. The priority label is 12 sp (:170). |
| UX-1419 | fixed | `task_tile.dart:70-72`: on a lit row (colour ≠ surface) secondary text turns onSurface. AUDIT has no contrast failure on lit rows. |
| UX-1420 | fixed | `task_tile.dart:51-57` with `markOverdue` from `TaskList`; the 1× render reads «dom, 18 de oct · Atrasada». |
| UX-1512 | fixed | `task_tile.dart:124` leaves out the page's own project (`project.shared.es.light.1x.png` has no «Matemáticas»). Person or groups icon before the assignee; `assigneeLabel` and `projectLabel` through `spokenAs` (task_tile, `task_assignment_picker.dart:109-123`, `task_list_picker.dart:261-299`). |
| UX-1414 | fixed (needs device) | `tasks_with_files_screen.dart:98-101` with `AttachmentPanel(reveal:)` brings Archivos into view (`detail.from-files-list.es.light.1x.png`). Refused card: one sentence and 4 buttons; «Eliminar archivo adjunto» comes last, in red, 12 dp below; the confirm button is red; `fileRetry` reads «Volver a subir» (`detail.file-space-full.es.light.1x.png`). The only failing check is EN “transfer” in `groupTransfer` and `archiveCsvPersonalCopies`. Both are about **ownership** transfer, where “transfer” is the right English word and not the file-upload jargon this finding is about. Narrow that check to file strings. |
| UX-1415 | fixed | `task_detail_screen.dart:376-384`: notes right after the date card, before the reminder and steps; `checklistCompletionHelp` is gone from all catalogs. `detail.notes-steps.es.light.1.3x.png` shows NOTAS and its first line above the fold. |
| UX-1417 | fixed | `taskScreenTitle` «Tarea» / “Task” / «Tasca» (:120, :169, :509). A 12 dp gap at :178 (renders show «Tarea» uncut). |
| UX-1421 | partly | Every key the brief named is done: `deadlineRecurringHelp`, `reminderAnchor`, `reminderAnchorHelp` dropped, the split time-range errors (`schedule_editor.dart:368-370`, :397), `scheduleError`, `scheduleChangedAgain`, `viewOnlyTask`, and `calendarReadOnly` dropped from event rows (`device_calendar_events.dart:185`). The finding's own check («no programación / permisos de edición…») still fails on strings in the **same task-form corners**: ES `changeSeriesQuestion` «¿Cambiar la programación recurrente?», `changeSeriesHelp` (task_editor), `schedule` «Programación»; ES/CA `listEditingAccessHelp` «…permisos de edición» (`project.viewer.es.light.1x.png` bottom bar); CA `viewOnlyNote`; EN `retryScheduling`. These need copy from the organizer. |
| UX-1402 | fixed | `day_timeline_screen.dart:73-105`: `_opening`/`_place` scroll to the first timed item, or to the hour before now once it has passed. It jumps when animations are off; arrows glide. «Ir al primer elemento con hora» is removed; TalkBack reads title first (:395-399); copy as written. `timeline.normal` and `timeline.busy` renders now differ (both open at 08:00, with the now line). See R1B-1. |

### Regressions (only in the changed files and their flows)

**R1B-1 · S2 · Día view opens scrolled past «Sin hora» and its banners**
- Where: `day_timeline_screen.dart:184-192` (`_placing` → `_place`), above the timeline inside the same scroll view at :238-280.
- The moment: "¿Y la factura de la luz que puse para hoy? Aquí no está."
- What happens: the «Sin hora» section (date-only tasks and all-day phone events) sits above the timeline, in the same `SingleChildScrollView`. So do the load-error banner, «calendarReadError», the calendar-access button and the 200-item notice. The new opening scroll moves all of them off the top, with nothing on screen to say they're there. The tester's test (`day_timeline_test.dart:309-337`) checks only their order, not that they're visible.
- Why it fails: change blindness (Rensink 1997); visibility of system status (Nielsen 1994). An error banner you can't see is no feedback.
- Fix: move the banners and the calendar-access button out of the scroll view, under the day header, so they never scroll away. For «Sin hora»: when the day has untimed items, open at the top (offset 0) if the first timed item is still in view from there; otherwise scroll to the first timed item as now. In that case the organizer picks either (a) leave «Sin hora» above and accept it, or (b) put the «Sin hora» rows below the timeline. No new copy either way.
- Verify: a widget test at 1× and 2× on 360×800, with a date-only task plus the 08:30 fixture. On arrival, «Pagar la factura de la luz» or a banner is on screen, or the organizer's chosen rule holds.
- Evidence: verified in code; no render of a timeline day with a date-only task.

**R1B-2 · S2 · «Recordatorio para Ana: …» states this phone's default**
- Where: `reminder_control.dart:296-306` (chip `value` from `preferences.leadMinutes`) and :384-388 (form row adds «· predeterminado»).
- The moment: María reads «Recordatorio para Ana: 10 minutos antes». But Ana's phone uses Ana's own default (`reminder_engine.dart:172`, `task.reminderMinutes ?? preferences.leadMinutes`), which may be 1 hour.
- Why it fails: the line now makes an explicit claim about another person that the app can't know (trust; Budiu & Laubheimer 2018: show what the system actually knows).
- Fix: when the task follows the default (`reminderMinutes == null`, or a date-only task with no `reminderTime`), say only EN “Reminder for {name}” / ES «Recordatorio para {name}» / CA «Recordatori per a {name}» (new key). Keep `reminderForPerson` with the value when the task carries its own.
- Verify: in the reminder_settings tests, Ana's task with `reminderMinutes: null` reads «Recordatorio para Ana», and with 30 reads «Recordatorio para Ana: 30 minutos antes».
- Evidence: verified in code.

**R1B-3 · S2 · Scoped Completed page hides the person filter**
- Where: `completed_tasks_screen.dart:41-43`, :81-84; from `home_screen.dart:459-471`.
- The moment: with «Ana» or «Para mí» on in Matemáticas, the person taps ✓ and sees «Matemáticas · 1 tarea completada». "¿Solo una? Si hicimos cinco."
- Why it fails: recognition over recall (Nielsen 1994). The filter carried over from the previous screen is invisible here (working memory, Cowan 2001).
- Fix: under the title, name the filter with existing strings: «Matemáticas · Ana», or «Matemáticas · Para mí» (`forMe`). Show only «Matemáticas» when «Todas» is on.
- Verify: `completed.project` preview with Ana on reads «Matemáticas · Ana».
- Evidence: verified in code; `completed.project.es.light.1x.png` shows only «Matemáticas».

**R1B-4 · S1 · Scoped Completed rows repeat «Matemáticas»**
- Where: `completed_tasks_screen.dart:89` builds `TaskList(tasks:, newestFirst: true)` with no `project:`.
- What happens: the heading says «Matemáticas» and each row says «Matemáticas» again (`completed.project.es.light.1x.png`), against UX-1512's rule.
- Fix: pass `project: listId`.
- Evidence: seen in a current render.

**R1B-5 · S1 · View-only rows no longer line up with the others**
- Where: `task_tile.dart:264` (`viewOnly ? 16 : 8`) and the removed circle (:271-288).
- What happens: in mixed lists, a view-only title starts about 44 dp left of the other titles. On Calendar, «Comer con Ana» starts at about 36 dp while the rest start at about 80 dp (`agenda.added.es.light.1x.png`).
- Fix: keep the 48 dp leading slot as an empty box, excluded from semantics, so titles line up. Add no icon.
- Evidence: seen in a current render.

**R1B-6 · S1 · «(100 MB)» breaks across lines**
- Where: `storageFull` in all three catalogs; `detail.file-space-full.es.light.1x.png` reads «…lleno (100 / MB).».
- Fix: use a non-breaking space: `({limit} MB)` in EN, ES and CA.
- Evidence: seen in a current render.

### Device checks still open
- Emulator lane, `screen-tasks.list.es.light.2.0` at 393 dp: does a task row show, and is «Tus tareas» / «Les teves tasques» on one line (UX-1403)?
- Two accounts: the assignee's phone rings (UX-1505).
- TalkBack: the actions menu offers «Cambiar fecha» (UX-1416).
- Free account with full storage: removing one file uploads the refused one (UX-1414).

### Memory notes
- The ticked-row rule now applies on Tareas, project pages and Sin fecha (`_openHere`). It clears on a tab switch, a scope change, the page being covered, and on search or filter.
- The Completed page is now scoped from a project page (`CompletedTasksScreen(listId, team, person)`); the root has a labelled «Completadas».
- Rows: view-only rows have no circle and are one TalkBack button; editable rows carry a «Cambiar fecha» custom action; `markOverdue` and `project` come from `TaskList`.
- New recurring problem type: a scroll-on-open placement that hides content above the target (Día view).
