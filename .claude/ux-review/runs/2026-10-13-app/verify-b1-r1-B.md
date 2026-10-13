## UX verify — run 2026-10-13-app, round 1, area B (P31, P8) — 2026-10-13
**Verdict:** All four findings are fixed in code and covered by passing tests. Two regressions, both severity 1. Still needs the device checks.
**Evidence level:** code plus ux-tester's tests. No current render shows the changed states: `build/calendar-feedback-*.png` (17:16) has no overdue task in its fixture, and nothing renders the reminder chip or Notificaciones.

### Results
- **UX-201: fixed (device check left).** `Task.overdueOn` is in `App/lib/models/task.dart:448-502`: one-off tasks use dueDate or deadline; repeating tasks look back a bounded number of steps, skip and move occurrences, and only the latest counts. In `App/lib/screens/calendar_screen.dart:91-109` the overdue rows are built only for today and use the same project scope (`tasks`, :80-82); they're sorted oldest first and deduplicated against today's rows. The header `overdueCount` and the `TaskTile(showDate: true)` rows are at :478-505, with a divider before today's rows (:506-510). The counts line and ring use `total` (:414-441). The empty state shows only when `total == 0` (:467). The Tareas `Hoy` filter (`App/lib/screens/home_screen.dart:199-222`) adds the overdue occurrences. The ES and CA plurals match the brief.
- **UX-209: fixed (device check left).** `_cannotFire` (`App/lib/widgets/reminder_control.dart:20-33`) combines the switch and the OS permission. When blocked, the chip shows a bell-off icon and `noReminderTurnOn`, and runs `turnOnReminders` (:211-237). The shared action (:37-103) asks for permission. If refused, it shows `notificationPermissionOff` with `openSystemSettings`. If granted, it sets `enabled` to true with 9:00 for date-only tasks (D2b), shows the exact-alarm sheet when needed, then shows the confirmation. The ReminderControl link reads `enableReminders` and runs the same action (:307-318). Searching for `deviceOff`, `useReminder` and `deviceReminderScope` in lib finds nothing.
- **UX-210: fixed.** `_chooseReminder` (:106-183) is one sheet: tap an option and it applies and closes. Date-only tasks get `chooseAlertTime`. Both the chip (:240) and the form's Recordatorio row (:291-303) open it. There's no PopupMenuButton.
- **UX-405: fixed.** In `App/lib/screens/notification_settings_screen.dart:194-226` there is one switch with no subtitle, and turning it on runs `_turnOn`, which calls the shared action. The status line, its actions and `Actualizar y reintentar` show only when there's a `problem` (:160-164). Check-ins, upcoming alerts and the help texts are folded under the `Detalles` ExpansionTile (:248-292). ES check-ins: `Por la mañana` / `Por la tarde`; CA: `Al matí` / `Al vespre`.

### Regressions (only from these changes)
**R1B-1 · Severity 1 · Exact-alarm sheet names the permission two ways**
- Where: `App/lib/widgets/reminder_control.dart:72-92`, the sheet `turnOnReminders` shows.
- What happens: the sentence asks for «Alarmas y recordatorios», but the button reads `Permitir alarmas precisas`. Two names for one permission, in a sheet with no title.
- Fix: label the button with the name of the system screen. EN `Allow “Alarms & reminders”` / ES `Permitir «Alarmas y recordatorios»` / CA `Permet «Alarmes i recordatoris»`. Use the same label on Notificaciones (:220-229).

**R1B-2 · Severity 1 · Turn-on confirmation over-promises**
- Where: `App/lib/widgets/reminder_control.dart:102`.
- What happens: `Listo. Te avisaremos antes de cada tarea con hora.` also shows when the user just closed the exact-alarm sheet (so reminders may arrive late), and when the action started from a date-only task (which reminds at 9:00, not "before").
- Fix: when exact alarms are still off, finish on the exact-alarm sentence instead of the confirmation. Otherwise use ES `Listo. Recordatorios activados.` / EN `Done. Reminders are on.` / CA `Fet. Recordatoris activats.`

### Noted, not a regression
- Calendar Today: completing an overdue row removes it from `total`, so the ring and "hechas" don't go up. "2 pendientes · 0 hechas" becomes "1 pendiente · 0 hechas". It follows from D1's "the row leaves the section" and is worth a look in polish.
