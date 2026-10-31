## UX verify — 2026-10-19-app b5 r2, area D (P215, P216, P217) — 2026-10-20

**Verdict:** all five findings fixed in code and by test; one regression from P215 (S2): with Idioma «Como el teléfono» (the default), the app no longer follows a phone-language change while it is running.

### Results

| Finding | Result | Evidence |
|---|---|---|
| UX-1649 | fixed | `App/lib/services/app_language.dart:23-31` (`phone` ValueNotifier, `phoneLocales` getter/setter, `phoneOr`), `:51-59` saves the tags only for a non-empty answer, `:64-80` `readSavedPhoneLocales`. `App/lib/main.dart:56-58` seeds from the saved row in the same `Future.wait`; `:99` listens, `:124` removes, `:130-132` rebuilds; `:435-437`, `:445`, `:451` pass `phoneOr(...)` to `locale:` and to `RegionalMaterialDelegate`; `localeListResolutionCallback` untouched. `native_speech.dart:198-200` and `reminder_copy.dart:14-17`, `:34`, `:43` as briefed; `deviceLocales` parameter kept. Tester's widget and unit tests pass. Device-only: week strip on an Android 13+ Spanish phone with Idioma English; background reminder text. |
| UX-1650 | fixed | `reminder_control.dart:122-125` `onScheduling`, `:195-199` hands over the same `reconcile(...).catchError(recordError)` future; other callers (`reminder_ask_sheet.dart:116`, `reminder_control.dart:407`, `:511`) unchanged. `notification_settings_screen.dart:131-166`: waits for it with `_busy`/`_turningOn` true, then `_load(refresh: false)` (no second reconcile, `:81`); a refusal (`on` false) clears `_turningOn` at once (`:159`). Resume during the wait only re-reads capability (`:58`). Switch shows `settings.enabled || _turningOn` (`:264`); problem hidden while `_turningOn` (`:205`); bar at `:259`. Tests pass. |
| UX-1651 | fixed | `device_calendars_screen.dart:134-150`: below the list only the outlined «Actualizar calendarios» and the TextButton «Ocultar eventos del calendario»; no `calendarClear` anywhere in `App/lib` or the ARBs. Renders `first-run/phone-calendars.allowed.es.light.1x.png` and `.2x.png` (2026-10-21 00:40, newer than every App/lib file) show exactly these two. `clearSelection` stays in the provider. |
| UX-1612 | fixed | `account_screen.dart:185-191`: the name `Text` inside `Semantics(header: true)`, only when the name isn't empty; email line unchanged. AUDIT `settings/account · named` TalkBack order: 2 heading «Tu cuenta», 3 heading «María», 4 text email. Device-only: «María, encabezado» on TalkBack. |
| UX-1652 | fixed | `data_transfer_screen.dart:66-71`: `MediaQuery.disableAnimationsOf(banner) ? Duration.zero : 250 ms`; the two alignment policies and the `jumpTo` steps kept. Tests pass. Device-only: «Quitar animaciones». |

### Regressions

**R2D-1 · Severity 2 · «Como el teléfono» stops following a phone-language change**
- Where: `App/lib/main.dart:136-139` (`didChangeLocales`), `:435-437`, `:445`; `App/lib/services/app_language.dart:31`; `App/lib/services/reminder_copy.dart:14-17`; also `language_selector.dart:84-90` and `native_speech.dart:198-200`.
- What happens: `phoneLocales` is only set by `apply`, which runs at start and when Idioma changes. The activity declares `locale` in `configChanges` (`AndroidManifest.xml:28`), so a phone-language change while the process is alive arrives as `didChangeLocales` only. With Idioma «Como el teléfono» no per-app language is set, so Flutter's new locales *are* the phone's, but `locale: regional.localeFor(phone)` now reads the stale bridge list: the app stays in the old language until the process dies, and `TaskReminders.refreshLanguage()` (`:138`), whose job is exactly this case, rewrites the reminders in the old language too. Background reminders with «Como el teléfono» read the saved row before `PlatformDispatcher.instance.locales`, so they stay stale until the app is next opened. Before P215 all of these followed the phone at once.
- The moment: "I switched my phone to Catalan and TaskFlow is still in Spanish; even its reminders are."
- Why it fails: consistency and visibility of system status (Nielsen 1994); the default setting no longer means what it says.
- Fix: in `didChangeLocales`, ask the bridge again before refreshing the reminders: `unawaited(AppLanguageBridge.apply(ref.read(regionalProvider).language).then((_) => TaskReminders.refreshLanguage()))`. `AppLanguageBridge.kt:39` only sets `applicationLocales` when they differ, so the change this may cause (Idioma English with a new phone region) comes back once, finds them equal and stops: no loop. In `reminder_copy.dart`'s `_phoneLocales`, when the saved Idioma is «Como el teléfono», use `PlatformDispatcher.instance.locales` (live, and the phone's, since no per-app language is set) before the saved row. No copy changes.
- Verify: widget test, Android target, Idioma «Como el teléfono», bridge answering `['es-ES']` then `['ca-ES']`: after a `didChangeLocales` with `ca-ES`, `Localizations.localeOf` is `ca` and the reminder refresh reads Catalan; emulator lane: change the phone language with the app in the background, return: the app speaks the new language.
- Evidence: verified in code; whether Android keeps the process alive across a system-language change needs a device check.

### Not regressions (checked)
- `main()` reads the saved row from the same database `regional.ready` opens: no extra cold-start wait worth noting; a read error returns null.
- During P216's wait the whole Recordatorios screen is disabled with the bar; before round 1 `turnOnReminders` awaited the same reconcile, so this is not new.
- AUDIT `settings/account · named` 2× «Eliminar cuenta» 27 dp tall: not caused by this change.
