## UX verify — run 2026-10-28-app, b1 round 1, area D — 2026-11-01

**Scope:** P272 (UX-2601). Branch `ux-in-progress`, HEAD `b0de7c8`; P272's code is in the working tree (`git diff HEAD`): `App/lib/widgets/reminder_control.dart`, `App/lib/screens/notification_settings_screen.dart`, `App/lib/providers/reminder_provider.dart`, `App/test/ux_previews/settings_previews.dart`, plus the two test files. The delegation's "files changed" list named only the generated l10n and the tests; the source diffs above were read too. P272 adds no copy (the generated l10n diff belongs to other packages). The `Padding` around «Activar recordatorios» in `ReminderControl` (UX-2205) is P275's, not judged here.

**Evidence:** code; widget tests (tester: pass); previews rendered 2026-11-01 02:38, newer than every file in `App/lib` and `App/assets` (`find -newer` lists nothing). No device capture of the new path.

### UX-2601 · fixed (device check pending)

- **Finish on return.** On a refusal, the message's «Permitir avisos» now calls `_finishOnReturn` (`App/lib/widgets/reminder_control.dart:300`, `:324-367`). It records the request for this account in `reminderRequestsProvider` (`App/lib/providers/reminder_provider.dart:19-20`), adds an app-wide `AppLifecycleListener`, and opens Android's page. On resume, if the phone now allows notifications, it runs `_switchOn` (`:373-456`), the same path `turnOnReminders` takes after a grant: `enabled: true`, `dateOnlyTime ?? 540`, `asked: true`, the exact-alarms sheet when needed, the alerts set, and «Listo. Recordatorios activados.». The request is removed in `finally` whether it succeeded or not, so a refusal on return says nothing and a later resume does nothing. A second tap can't stack listeners (`containsKey`, `:331`).
- **Recordatorios waits for it.** On resume with a pending request, the screen shows its progress bar, waits, then re-reads (`notification_settings_screen.dart:59-78`). The switch then turns on with no stale blocked line.
- **One way in while off.** With the switch off and the phone blocking, the line and the filled «Permitir avisos» are gone (`notification_settings_screen.dart:244-255`). Render `settings/reminders.off-blocked.es.light.1x.png`: the switch, Tareas con hora, Tareas sin hora, Detalles; nothing else. Turning the switch on runs `turnOnReminders`, which asks Android or shows the message with «Permitir avisos».
- **On and blocked keeps UX-1606.** `settings/reminders.blocked.es.light.2x.png`: the switch on, «El teléfono no deja que TaskFlow te avise.», «Permitir avisos». No clipping at 2×.
- **First-run refusal unchanged in look.** `first-run/reminder-question.refused.es.light.2x.png`: the message and «Permitir avisos», as before.
- **Tests:** `reminder_ask_sheet_test.dart` group «P272 · allowing notifications…»: 9:00 and a time already chosen, plus the still-refusing case with a later resume. `reminder_settings_test.dart` group «P272 · Recordatorios has one way in…»: the switch alone; the switch's own refusal, then «Permitir avisos», then allowing gives the switch on and «Listo»; on and blocked keeps the line. The tests changed for UX-1605 and UX-1650 now expect the switch alone, with «Permitir avisos» in the message. That is the intended change.
- **Residual, for the device check:**
  - The request lives only in memory. If Android kills TaskFlow's process while the person is in its settings (a low-memory phone), the return is a cold start and reminders stay off. That is the old behaviour, with no wrong message.
  - The brief suggested a stored flag "for example", so this isn't a failed acceptance. The emulator lane should still confirm the normal return: «Sí» → «No permitir» → «Permitir avisos» → switch on → back shows «Listo. Recordatorios activados.», and Ajustes reads «Activados · 10 minutos antes».

### Regressions

None found in the changed files or the flows they touch:
- the task line's «Activar recordatorios» (`reminder_control.dart:709`, `:950`);
- the reminder question (`reminder_ask_sheet.dart:193`);
- the Recordatorios switch.

Checked:
- The snackbar still times out (`persist: false`, `FeedbackTimeout`), as before. In Recordatorios the switch is now the second way back to it.
- The return on another screen opens the exact-alarms sheet on the root navigator, as the brief asks.
- An account change in between is guarded (`ownerKey == owner`).

Note for the organizer, not a finding:
- The `@notificationPermissionOff` description in `app_en.arb:1353` still says "Shown on the Reminders screen". It now shows there only while reminders are on. That's a translator note, not something a user sees.
