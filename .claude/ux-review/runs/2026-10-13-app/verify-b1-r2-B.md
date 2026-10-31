## UX verify — run 2026-10-13-app, round 2, area B (P50) — 2026-10-13
**Verdict:** Ship. Both findings fixed; no regressions in the changed files.
**Evidence level:** code + ux-tester widget tests (pass). No preview covers the exact-alarm sheet or the Notificaciones card, so no render applies.

### UX-435 · fixed
- `allowPreciseAlarms` changed by value, key kept: EN `Allow “Alarms & reminders”` (app_en.arb:870), ES `Permitir «Alarmas y recordatorios»` (app_es.arb:614), CA `Permet «Alarmes i recordatoris»` (app_ca.arb:593).
- Both places follow: the sheet button (reminder_control.dart, `turnOnReminders`, FilledButton under `exactAlarmsNeeded`) and Notificaciones (notification_settings_screen.dart:226), where the card title above it is `exactAlarmsNeeded` — sentence and button now name the same system screen.
- Status lines `preciseAlarmsAvailable` / `approximateAlarmsHelp` left untouched as briefed (inside the collapsed Detalles section, notification_settings_screen.dart:267-269).
- Tests: reminder_settings_test.dart:279, :347, :368 pass.

### UX-436 · fixed (device check pending)
- After the sheet, `exact = (await access.capability()).exact;` is re-read; the final message is `exact ? remindersOnConfirmation : exactAlarmsNeeded`, no action button (reminder_control.dart, end of `turnOnReminders`).
- Confirmation value: EN `Done. Reminders are on.` / ES `Listo. Recordatorios activados.` / CA `Fet. Recordatoris activats.` (app_*.arb, `remindersOnConfirmation`) — no longer promises "before each timed task".
- Permission-refused and save-error paths unchanged (early returns).
- iOS / unsupported platforms report `exact: true` (reminder_provider.dart:59, notification_service.dart:335), so they never see the sheet or the "permite" message.
- Tests: reminder_settings_test.dart:279, :322 pass.
- Device: Android 14 — back out of the system "Alarms & reminders" screen without allowing; the last snackbar must ask for «Alarmas y recordatorios», not say Listo. Also confirm the opposite: allow it, come back, and see `Listo. Recordatorios activados.` (this relies on `requestExactAlarmsPermission` resolving only after the user returns).

### Regressions
None found in reminder_control.dart, the three catalogs or the flows they touch (chip → turnOnReminders, ReminderControl → turnOnReminders, Notificaciones exact-alarm card).
