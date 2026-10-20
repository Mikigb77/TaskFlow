## UX verify — 2026-10-19-app, round 1, area D (P186–P189) — 2026-10-20

**Verdict:** Ship after fixes. All 16 findings meet their acceptance checks: 15 are fixed and UX-1612 is partly fixed, because its name-row half is P194's by design (D5). The changes cause three regressions, all severity 2 or lower.
**Evidence:** code diffs (`git diff HEAD`), current renders (23:22–23:24; no ARB, lib or asset file is newer than them except the regenerated `l10n/generated/`), and ux-tester's passing tests. Native checks (launcher, widget, toasts, per-app language, DND, the notifications page) are device-only.

### Results

| ID | Result | Evidence |
|---|---|---|
| UX-1316 | fixed (device) | `CaptureShortcuts.kt:26-39`: the short labels `capture_*_short` (Dictar/Escribir, Dicta/Escriu, Dictate/Type) plus `setLongLabel`. `capture_widget.xml`: a 24 dp mic, 6 dp padding, and the label at 0 dp/weight 1 with auto-size from 9 to 12 sp and maxLines 2. Translator comments are present. |
| UX-1319 | fixed (device) | `res/values*/strings.xml`: all four toasts carry the agreed copy, ≤50 characters, in EN, ES and CA. |
| UX-1621 | fixed (device) | New `AppLanguageBridge.kt` and `services/app_language.dart`. The language is applied at start (`main.dart:95`) and when Idioma changes (`language_selector.dart:65`). `MainActivity.onConfigurationChanged` republishes the shortcuts and refreshes the widget. The manifest keeps `locale|layoutDirection` in configChanges. See R1D-1. |
| UX-1605 | fixed | `notification_settings_screen.dart`: `_turningOn` shows the switch on and hides the problem block (:190-196, :250); resume re-reads the capability while busy (:55-68); the fix buttons are gated on `_busy`. `reminder_control.dart:189-196` no longer waits for `reconcile`. See R1D-2. |
| UX-1606 | fixed | One line and one FilledButton per state (`:209-231`). «Reintentar» (`tryAgain`) shows only when `_schedulerError != null`. `openNotificationSettings` uses `ACTION_APP_NOTIFICATION_SETTINGS` and falls back to App info. The snackbar after a refusal uses the new copy and action. The Ajustes row shows `remindersOnLate`. The keys `openSystemSettings` and `retryScheduling` are gone. Renders `reminders.blocked.es.2x` and `reminders.exact-alarms-off.es.2x` show one line and one filled button. |
| UX-1607 | fixed (device) | `notification_service.dart:49-72`: `category: AndroidNotificationCategory.reminder` is set on reminders only; `undoNotificationDetails` doesn't set it. |
| UX-1616 | fixed | `_pick` uses `initialEntryMode: input`; «Tareas con hora» is a ListTile that opens `chooseDefaultLead` (no default row); `taskDefaults` is gone. Render `reminders.on.es.2x` shows «10 minutos antes» whole. The 0 dp gap in the AUDIT is between full-width 72 dp list rows, which is a normal list: not an issue. |
| UX-1622 | fixed | `reminder_control.dart:167-180`: the `exactAlarmsNextScreen` line, then «Ahora no», which pops the sheet the way Back does. Render `first-run/reminder-question.exact-alarms.es.2x`. |
| UX-1611 | fixed (device) | `device_calendars_screen.dart:79-86`: one lead line per state (intro, refused, connected). `calendarRefresh` shows only when access is granted and the calendars are enabled; «Ocultar» is a TextButton below the list. `enable()` ticks up to 50 calendars on a first connection. Renders `phone-calendars.not-allowed.es.2x` (button above the fold), `.refused.es.2x` and `.allowed.es.1x`. See R1D-3. |
| UX-1619 | fixed | `regionHelp` is gone; the zone row reads `timeZoneSameAsPhone(city)` with no separate line, and the fallback banner stays. Clock and week start open radio sheets like Idioma's. Renders `region.normal.es.2x` and `region.clock-sheet.es.2x`. |
| UX-1620 | fixed | `keepYourTasks` is gone; the new help has no formats or limits; the snackbar is removed; the result banner is a live region and is scrolled into view. Render `data-transfer.start.es.2x`. |
| UX-1612 | partly | The slogan half is fixed: `account_screen.dart:184-193` shows the first name as the heading, or no heading, and `accountHeading` is gone from the catalogs (render `account.named.es.2x`). The name row and name sheet are P194's (D5), so this is not a defect. The name is drawn in headlineMedium but isn't marked as a heading (AUDIT); a check of P194 can add `Semantics(header: true)`. |
| UX-1613 | fixed | The card's repeated heading and sparkle are gone; `billingIntro` has the new copy; «Ver suscripción» is pinned in `bottomNavigationBar` for free accounts. Render `pro.free.ca.2x` shows the line and the pinned «Mostra la subscripció». The optional Ajustes subtitle wasn't planned. |
| UX-1614 | fixed | «Restaurar compras» stays in the scroll, away from the pinned button; it is hidden while Pro is active (render `pro.active.es.1x` shows only «Gestionar suscripción»). The `store` and `other` cases now read «La tienda no respondió. Vuelve a abrir esta pantalla.». |
| UX-1615 | fixed | `app_theme.dart:113` uses `scheme.outline` for the outlined-button side; the visible borders show in `account.named.es.2x` and `pro.free.es.1x`. |
| UX-1618 | fixed | `breakableAddress` and `withoutAddressBreaks` (`region.dart:100-110`) are used on Cuenta, the delete page (:384, :405, :415, :728 with plain semantics), verify email and recovery. `MessageBanner` speaks the plain text. Render `account.named.es.2x` breaks as «maria.lopez@example. / com». |

### Regressions

**R1D-1 · Severity 2 · «Como el teléfono» week start now follows the app language**
- Where: `App/lib/main.dart:436-438` (`RegionalMaterialDelegate`'s `deviceLocale` = `platformDispatcher.locales.firstOrNull`), `App/lib/l10n/region.dart:131-147`, and `readReminderCopy` in `App/lib/services/reminder_copy.dart:35`.
- The moment: "My week always started on Monday. Why does Calendar start on Sunday now?"
- What happens: on Android 13+, with Idioma set to a language other than the phone's, `AppLanguageBridge` makes Flutter's locales the app's (`en-ES` instead of `es-ES`). The implementer's own comment in `language_selector.dart:84` says so. `RegionalMaterialDelegate` loads Material localizations for that `deviceLocale` and takes `firstDayOfWeekIndex` from it. Material's plain `en` is Sunday-first, so a Spanish phone with the app in English goes from Monday to Sunday under «Primer día de la semana: Como el teléfono». A US phone with the app in Spanish goes the other way. The recognizer's region (`native_speech.dart:197`) loses the phone's variant in the same way, which is rarer.
- Why it fails: lens M, the week start must be honoured. «Como el teléfono» no longer matches the phone.
- Fix: where the app means "the phone", read `AppLanguageBridge.phoneLocales` before `platformDispatcher.locales`, and rebuild once it arrives. That covers `main.dart:430/437` and the speech devices. For background reminder copy, persist the phone's first locale when `apply` answers.
- Verify: unit test, phone es-ES with Idioma English: `firstDayOfWeekIndex` stays 1. Emulator check: Calendar's week strip starts on Monday.
- Evidence: inferred from code; needs a device check.

**R1D-2 · Severity 2 · After turning reminders on, Detalles says there are no alerts**
- Where: `App/lib/screens/notification_settings_screen.dart:149-151` (`_load(refresh: false)` after `turnOnReminders`), together with `reminder_control.dart:189-196` (`reconcile` not awaited).
- The moment: "I just turned them on — why does it say there are no upcoming alerts?"
- What happens: the screen reads `upcomingAlerts` and `schedulingInfo` before the unawaited `reconcile` has written them. «Próximos avisos» shows `noUpcomingAlerts`, or the previous list. A `refresh_failed` from that reconcile never reaches the screen's «Reintentar» until the next resume.
- Why it fails: lens B, visibility of system status (Nielsen 1994).
- Fix: after a successful turn-on, call `_load()` with the refresh. `_turningOn` already keeps the switch on and the problem block hidden, so the wait no longer shows stale state, and the confirmation has already shown. Alternatively, reload when the reconcile future completes.
- Verify: widget test with a reconcile that completes after 2 s. Once it completes, Detalles lists the alerts; with a failing reconcile, «Reintentar» appears without a resume.
- Evidence: verified in code.

**R1D-3 · Severity 2 · Two look-alike buttons below the calendars list**
- Where: `App/lib/screens/device_calendars_screen.dart:133-154`, render `first-run/phone-calendars.allowed.es.light.1x.png`.
- The moment: "Borrar selección or Ocultar eventos… what's the difference?"
- What happens: moving «Ocultar eventos del calendario» below the list puts it next to «Borrar selección». Both are centred TextButtons in the same colour, separated only by «Actualizar calendarios», and both end with no events on Calendar. With D7 every calendar starts ticked, so «Borrar selección» is the bulk opposite of the default, and unticking one calendar is done row by row.
- Why it fails: lens D, two different actions must not look alike side by side; lens C, the screen offers two ways to the same outcome (Hick–Hyman).
- Fix: remove «Borrar selección» (`calendarClear`) and its key. Ocultar covers "show none", and each row's checkbox covers one calendar. That leaves three controls below the list: before → after, 3 → 2.
- Verify: re-render `phone-calendars.allowed`; check there is one TextButton below the list.
- Evidence: seen in a current render.

**R1D-4 · Severity 1 · The result banner scroll ignores reduced motion**
- Where: `App/lib/screens/data_transfer_screen.dart:63-71` (`Scrollable.ensureVisible` with 250 ms, called twice).
- What happens: the new reveal animates the scroll even with Android's «Quitar animaciones» on.
- Fix: use `Duration.zero` when `MediaQuery.disableAnimationsOf(context)` is true.
- Evidence: verified in code.

### Not regressions (for the ledger)
- At 2×, the phone-calendars list's account subtitles still break mid-word («maria.lopez@exam / ple.com», render `phone-calendars.allowed.es.light.2x.png`). The Ajustes «Cuenta» row's subtitle isn't wrapped with `breakableAddress` either. Both are outside UX-1618's listed screens and were there before this change; same fix, `breakableAddress` with a plain `semanticsLabel`.
- «Tareas con hora» ends in a chevron and «Tareas sin hora» in «+», both opening choices: an inconsistency that predates this change (UX-1616 only converted the first row).

### Device checks still owed
- Launcher shortcuts and the widget at 1.0 and 2.0, in ES, CA and EN; the four toasts.
- Per-app language: phone in Spanish with Idioma set to Català. The shortcuts, widget and toasts should be in Catalan, without the activity restarting; with «Como el teléfono», Spanish again. Also confirm R1D-1's week start.
- `permission-alarms.allowed` re-captured; «Permitir avisos» opens TaskFlow's notifications page (phone, Android 13–15); DND with the reminder exception lets a reminder through (phone).
- `permission-calendar.*` with a calendar account added.
