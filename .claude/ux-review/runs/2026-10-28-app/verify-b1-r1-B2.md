## UX verify — 2026-10-28-app, b1 round 1, area B (P271, P277) — 2026-11-01

**Verdict:** Ship after one fix. P277 is done. P271's notices, the reader's task page and the translated suffix are done. One sync gap is left: a reader's reminder change still becomes a copy, with the red notice, when the owner changed the task before this phone's sync read it.

**Where the code is:** P271's app code is in the WIP commit b0de7c8 (diffed against 8064257). P277's is uncommitted (`git diff HEAD`).
**Renders read (all newer than every file in App/lib and App/assets):**
- `calendar/agenda.phone-events.es.light.{1x,2x}`
- `calendar/agenda.phone-events-many.es.light.1x`
- `calendar/timeline.events-error.es.light.1x`
- `tasks/detail.reader.{es.light.1x,ca.light.2x}`
- `tasks/detail.reader-chip.{es.light.1x,ca.light.2x}`
- AUDIT for each.

No render shows the two event sheets, so I judged their «Cerrar» and height from the code and tests.

### Results

**UX-2306 · fixed** (render + AUDIT + code)
- **The rows on Calendar.** `calendar/agenda.phone-events.es.light.1x` shows «Reunión de equipo · 10:00» and «Cita con el dentista · 17:00» as rows, after the tasks. At 2× they wrap whole. Code: `App/lib/widgets/device_calendar_events.dart:90-101` and `_EventRow` at `:153-208`, 48 dp tall, button role, with no circle and no swipe.
- **The gap to «Sin fecha · 1».** AUDIT puts «Sin fecha · 1» 8 dp below the last event (the widget's bottom padding, `:52-54`).
- **More than three events.** `phone-events-many` shows three rows, the all-day one reading «Vacaciones de Laura · Todo el día», then «Ver los 5 eventos», which opens the list (`:96-99`, `:171`).
- **Catalogs.** `calendarSeeAllEvents` is in all three: ES «Ver los {count} eventos», EN “See all {count} events”, CA «Mostra els {count} esdeveniments». `calendarEventCount` is gone.
- **The sheets.** Both now fit their content up to 75% (`ConstrainedBox(maxHeight)` with `Column(min)`) and end with «Cerrar» (`:385-405`). This rests on the code and the device_calendar_ui tests; no render shows it.
- **Still to do:** the emulator check, `permission-calendar.calendar-after` at ES 1.0 and 2.0.

**UX-2310 · fixed** (render + code)
- **Día view.** `timeline.events-error.es.light.1x` shows Calendar's grey line, «No se pudieron leer los eventos. Toca para reintentar.», under the day's arrows. TalkBack reads it as a button. The red 19-word banner is gone. Code: `App/lib/screens/day_timeline_screen.dart:264-278`, with `_readEventsAgain` at `:163-167`, which reads the calendars or the day's events again. Its busy state comes from the shared `CalendarReadRetry` mixin.
- **Events sheet.** The same line shows, with a spinner while it reads again (`device_calendar_events.dart` in the sheet's `when(error:)`).
- **Catalogs.** `calendarReadError` is in none of the three catalogs and none of the generated files.

**UX-2403 · fixed** (code + tests; the notification shade itself still needs a device)
- **(a) No «Completar» on a reader's notice.** A reader's single reminder gets only `snooze`. A reader's plan notice has no button (`App/lib/services/notification_service.dart:59, 68-74`). iOS gets a new `snooze_<lang>` category without «complete» (`:246-249`, `_category(complete:)`). The role reaches the notice through `TaskDatabase.readOnlyProjects` and `PlannedReminder.readOnly`. `readOnly` is part of the reminder's signature, so when the role changes, the reminders are scheduled again.
- **(b) Old notices still in the shade.** `ReminderEngine.action` returns before writing anything for a task in a «lector» project (reminder_engine.dart, the `readOnlyProjects(tx, owner)` check).
- **(c) A row equal to the server's.** It's acknowledged (`cloud_task_repository.dart`, `_sameContent(data, remote)` first). The stale case is the gap described under UX-2032.
- **(d) The copy suffix.** It's translated: `syncCopySuffix` is «(copia local)» / “(offline copy)” / «(còpia local)», read through `readReminderStrings`, with English as the fallback (`task_database.dart`, `preserveConflict`).

**UX-2032 · partly** (render + code + tests)

What's done:
- **The page.** `tasks/detail.reader.es.light.1x` shows «Solo puedes ver esta tarea y elegir tus recordatorios.», with no ✏, no 🗑 and no bottom bar. The chip «Recordatorio: 10 minutos antes» is outlined. AUDIT: a button, 269 × 48, not disabled.
- **At CA 2×.** The page fits; the banner wraps to four lines.
- **The code.** `App/lib/screens/task_detail_screen.dart:166-172` (`ownReminders`), `:231-233` (the banner) and `:388-409` (`setOwnReminders`). The save goes through `TaskDatabase.updateOwnReminders`, which skips `validateList` and marks the row pending. `showLocal` then shows the choice at once.
- **The sync.** The 200 path and the 409-between-GET-and-PUT path are both covered (`cloud_task_repository.dart:212-221`, `_sendReminders`, `acceptKeepingReminders`).

**What's left: a reader's reminders become a copy when the owner changed the task first (Severity 3).**
- **Where:** `App/lib/repositories/cloud_task_repository.dart:217-222`.
- **The gate.** A reader's row is sent only when `_sameContent({...data, ..._reminders(remote)}, remote)`, so only when the phone's copy of everything except the reminders still equals what the server holds right now.
- **When it fails.** The reader chose a reminder after the owner had changed the task but before this phone pulled the change: they were offline, the change came while the app was closed, or the app synced only after they tapped. The phone's row then still has the old title, time or completed dates, and the gate fails.
- **What happens.** The row goes to `preserveConflict`, so «Ensayo del coro (copia local)» appears as a new personal task, and `syncError` sets «This list is now read-only…», shown in red on Calendar. That is the failure UX-2032 and UX-2403 were meant to end, and the brief named this case ("a change the owner makes to the task meanwhile").
- **The test misses it.** The 409 test (`App/test/sharing_sync_test.dart:252`) changes the task only between the GET and the PUT (`beforePut`), the one window the code handles.
- **Fix:** remember that a row's pending change is reminders-only. For example, `updateOwnReminders` sets a flag that any other write clears. In a «lector» project, send such a row with `_sendReminders` whatever else differs from the server. The PUT already carries only the server's fields and version, so nothing but the reminders can go out. On 200, `acknowledge` takes the server's task; on 409, `acceptKeepingReminders` does, keeping the reader's reminders. Rows without the flag (a demoted editor's real edit) keep today's copy-and-notice path.
- **Verify:** a repository test. The reader sets «1 hora antes». The server's task is then renamed and versioned **before** the sync's GET. After the sync there is one task, with the new title and `reminderMinutes` 60, no copy, a null `syncError`, and no pending row.
- **Evidence:** verified in code; no test covers this case.

### Regressions (only in the changed files and the flows they touch)
None. I checked these and left them out:
- **Event rows 0 dp apart.** AUDIT counts it, but they are consecutive 48 dp rows of one list, the Material list convention, not two different actions.
- **«Projecte: Coro» 133 × 19 dp** in `tasks/detail.reader-chip.ca.light.2x`. The chip is cropped under the app bar by the scroll; it isn't small.
- **Contrast flags** on the reader page and the Día view. These are Flutter histogram edges; AUDIT itself measures the text colours as passing.
- **«Completar» on an old notice now does nothing.** It's a one-time transition on notices posted before the update. I'm not reporting it.

### Device checks still open
- P271: two accounts on the emulator lane. The reader's notice shows only «Posponer 10 min», and no duplicate appears after a sync. Include the stale case above once it's fixed.
- P277: `permission-calendar.calendar-after` at ES 1.0 and 2.0 shows both event names.
