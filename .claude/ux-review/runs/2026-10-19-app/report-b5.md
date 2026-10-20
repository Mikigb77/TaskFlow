# UX loop report — run 2026-10-19-app, batch b5 — 2026-10-20

**Verdict:** All 22 findings in this batch are fixed.
- 12 are **verified**.
- 10 are **verified in code and by test**, but still need a check on a phone or emulator (`device-check`).
- 0 are open, 0 are escalated, and nothing needs the owner's decision.

The tests passed in every round. Fixes in rounds 1 and 2 caused five regressions (UX-1649 to UX-1653), and all were fixed by round 3.

Evidence: code diffs, the current UX preview renders and AUDIT, and ux-tester's widget and unit tests. None of it comes from a device. The emulator and phone checks are listed below.

## Verified (12)
| ID | Sev | Title | Round / package |
|---|---|---|---|
| UX-1605 | S2 | After allowing reminders, Recordatorios says they're blocked | r1 · P187 |
| UX-1606 | S2 | Late or blocked reminders: a jargon line, three buttons | r1 · P187 |
| UX-1613 | S2 | The Pro screen never says what Pro gives | r1 · P189 |
| UX-1650 | S2 | After turning reminders on, Detalles shows no upcoming alerts (regression R1D-2) | r2 · P216 |
| UX-1651 | S2 | Two look-alike buttons below the phone calendars list (regression R1D-3; «Borrar selección» removed) | r2 · P217 |
| UX-1614 | S1 | Pro's buttons touch; subscribers see Restaurar first | r1 · P189 |
| UX-1615 | S1 | Outlined buttons have a 1.2:1 border | r1 · P189 |
| UX-1616 | S1 | Reminder times open the clock dial; lead time clips | r1 · P187 |
| UX-1618 | S1 | Email addresses break mid-word at 2× | r1 · P189 |
| UX-1619 | S1 | Hora y región: orphan «Madrid», reassurance paragraph, two dropdown styles | r1 · P188 |
| UX-1620 | S1 | Exportar e importar: jargon, a slogan, results said twice | r1 · P188 |
| UX-1622 | S1 | The «Alarmas y recordatorios» sheet has no way out | r1 · P187 |

## Fixed in code; a device check is still owed (10)
| ID | Sev | Title | Round / package |
|---|---|---|---|
| UX-1316 | S2 | Widget and launcher shortcut labels cut at large text | r1 · P186 |
| UX-1319 | S2 | Share messages are cut mid-word | r1 · P186 |
| UX-1607 | S2 | Reminders aren't marked as reminders; Do Not Disturb silences them | r1 · P187 |
| UX-1611 | S2 | Connecting the phone's calendars shows nothing | r1 · P188 |
| UX-1612 | S2 | Cuenta shows a slogan where your name belongs (partly fixed in r1; the heading was added in r2) | r1 P189, r2 P217 |
| UX-1648 | S2 | Unread Activity row likely announced twice while waiting | r1 · P214 |
| UX-1649 | S2 | «Como el teléfono» week start follows the app's language (regression R1D-1) | r2 · P215 |
| UX-1653 | S2 | «Como el teléfono» misses a phone-language change while running (regression R2D-1) | r3 · P218 |
| UX-1621 | S1 | Widget, shortcuts and share messages ignore the app's language | r1 · P186 |
| UX-1652 | S1 | Import result scroll ignores reduced motion (regression R1D-4) | r2 · P217 |

## Still open
None from this batch.

These ledger items are still open, but they belong to later packages, not to b5:
- UX-1623 (P192)
- UX-1515 (P194)
- UX-421 (P196)
- UX-1601 (P190)
- UX-1602 (its server half)
- UX-1603 (P193)
- UX-1608 (P195)

## Escalations
None. UX-1612 failed once (round 1, partly fixed) and passed in round 2.

## Checks for the owner's phone (or the emulator lane)
1. **UX-1316**: the launcher shortcuts and the widget at 1.0 and 2.0 text, in ES, CA and EN. The labels should read whole: Dictar/Escribir, Dicta/Escriu, Dictate/Type.
2. **UX-1319**: the four share toasts read whole.
3. **UX-1621** (Android 13+): set the phone to Spanish and Idioma to Català.
   - The shortcuts, widget and toasts should switch to Catalan without the screen restarting.
   - Then set Idioma back to «Como el teléfono»: they should return to Spanish.
4. **UX-1649** (emulator, Android 13+): with the phone in Spanish and Idioma set to English:
   - Calendar's week should start on Monday;
   - a reminder that fires in the background should read in English.
5. **UX-1653** (emulator): change the phone's language while TaskFlow is in the background, then return to it.
   - The app should be in the new language.
   - A reminder after swiping the app away should also be in the new language.
   - Logcat should show no repeated configuration changes.
   - Also open the app from cold after a language change, and watch for one first frame in the old language. That frame comes from P215 and isn't counted as a defect.
6. **UX-1607** (phone): turn on Do Not Disturb with its reminders exception. A TaskFlow reminder should come through.
7. **UX-1606** (phone, Android 13–15): «Permitir avisos» should open TaskFlow's own notifications page.
8. **UX-1605** (optional): re-capture `permission-alarms.allowed`.
9. **UX-1611**: with a calendar account added, run through `permission-calendar.*`. After connecting, the events should show in Calendario.
10. **UX-1612** (TalkBack): on Cuenta, TalkBack should read «María, encabezado».
11. **UX-1648** (emulator, TalkBack, ES): double-tap an unread Activity row whose task isn't on the phone yet. You should hear «Buscando la tarea…» once, with no second reading of the row.
12. **UX-1652**: with «Quitar animaciones» on, the import result should appear without a scroll animation.

## Files changed
**Native (Android)**
- `App/android/app/src/main/kotlin/com/example/agenda/`:
  - `CaptureShortcuts.kt`
  - `CaptureWidget.kt`
  - `MainActivity.kt`
  - `AppLanguageBridge.kt` (new)
- `App/android/app/src/main/res/layout/capture_widget.xml`
- `App/android/app/src/main/res/values/strings.xml`, `values-es/strings.xml`, `values-ca/strings.xml`

**App**
- `App/lib/main.dart`
- `App/lib/services/`:
  - `app_language.dart` (new)
  - `native_speech.dart`
  - `reminder_copy.dart`
  - `notification_service.dart`
- `App/lib/widgets/`:
  - `language_selector.dart`
  - `reminder_control.dart`
  - `app_components.dart`
- `App/lib/screens/`:
  - `notification_settings_screen.dart`
  - `settings_screen.dart`
  - `device_calendars_screen.dart`
  - `regional_settings_screen.dart`
  - `data_transfer_screen.dart`
  - `account_screen.dart`
  - `subscription_screen.dart`
  - `delete_account_screen.dart`
  - `verify_email_screen.dart`
  - `login_screen.dart`
  - `activity_screen.dart`
- `App/lib/providers/device_calendar_provider.dart`
- `App/lib/theme/app_theme.dart`
- `App/lib/l10n/region.dart`
- `App/lib/l10n/app_en.arb`, `app_es.arb`, `app_ca.arb`
- `App/lib/l10n/generated/*` (regenerated by `flutter gen-l10n`, not edited by hand)

**Tests**
- `App/test/`:
  - `native_resources_test.dart`
  - `language_selector_test.dart`
  - `reminder_settings_test.dart`
  - `settings_screen_test.dart`
  - `reminder_engine_test.dart`
  - `native_speech_test.dart`
  - `phone_language_change_test.dart` (new)
  - `device_calendar_test.dart`
  - `device_calendar_ui_test.dart`
  - `regional_ui_test.dart`
  - `data_transfer_screen_test.dart`
  - `subscription_screen_test.dart`
  - `appearance_test.dart`
  - `account_regional_ui_test.dart`
  - `delete_account_test.dart`
  - `email_verification_test.dart`
  - `auth_gate_test.dart`
  - `activity_screen_test.dart`
- `App/test/support/`:
  - `reminder_fixtures.dart`
  - `shown_text.dart` (new)
  - `address_wrap.dart`
- `App/test/ux_previews/`:
  - `settings_previews.dart`
  - `first_run_previews.dart`
  - `support/fixtures.dart`

**Records**
- `.claude/ux-review/ISSUES.md`

## Findings now protected by a test
All 22 findings are protected by a test.
- UX-1316: `native_resources_test.dart:283`, `:318`, `:345`
- UX-1319: `native_resources_test.dart:369`
- UX-1621:
  - `language_selector_test.dart:240`, `:297`, `:337`
  - `native_resources_test.dart:391`
- UX-1605: `reminder_settings_test.dart:1434`, `:1499`, `:1534`, `:1558`
- UX-1606:
  - `reminder_settings_test.dart:568`, `:1580`, `:1633`, `:1662`, `:1689`, `:1708`, `:1756`
  - `settings_screen_test.dart:1033`
  - `localization_catalog_test.dart:1387`
- UX-1607: `reminder_settings_test.dart:1784`
- UX-1616: `reminder_settings_test.dart:1825`, `:1887`
- UX-1622: `reminder_settings_test.dart:1947`, `:2010`
- UX-1611:
  - `device_calendar_test.dart:251`, `:270`, `:292`, `:311`
  - `device_calendar_ui_test.dart:156`, `:223`, `:255`, `:279`
- UX-1619: `regional_ui_test.dart:339`, `:717`, `:735`, `:796`
- UX-1620: `data_transfer_screen_test.dart:234`, `:255`, `:281`
- UX-1612: `account_regional_ui_test.dart:486`, `:495`, `:516`, `:540`, `:560`, `:581`
- UX-1613: `subscription_screen_test.dart:519`, `:530`, `:551`
- UX-1614: `subscription_screen_test.dart:199`, `:606`, `:656`, `:683`
- UX-1615: `appearance_test.dart:604`, `:617`
- UX-1618:
  - `account_regional_ui_test.dart:526`
  - `delete_account_test.dart:3901`, `:3912`, `:3930`
  - `email_verification_test.dart:2270`, `:2854`
- UX-1648: `activity_screen_test.dart:1136`, `:1202`
- UX-1649:
  - `language_selector_test.dart:365`, `:436`, `:465`, `:497`, `:519`, `:547`, `:595`
  - `native_speech_test.dart:2757`
  - `reminder_engine_test.dart:985`, `:1019`
- UX-1650: `reminder_settings_test.dart:2025`, `:2049`, `:2124`
- UX-1651: `device_calendar_ui_test.dart:358`, `:373`
- UX-1652: `data_transfer_screen_test.dart:357`
- UX-1653:
  - `phone_language_change_test.dart:107`, `:141`, `:171`, `:203`, `:245`
  - `reminder_engine_test.dart:1034`, `:1046`, `:1068`

## Rounds
**Round 1** (`plan.json`): P186, P187, P188, P189 and P214. Tests passed. Verify notes: `verify-b5-r1-D.md` and `verify-b5-r1-C.md`.
- 16 findings fixed.
- UX-1612 was partly fixed: the slogan was gone, but the name wasn't marked as a heading.
- Four regressions were raised: R1D-1 became UX-1649, R1D-2 became UX-1650, R1D-3 became UX-1651, and R1D-4 became UX-1652.

**Round 2** (`plan-b5-r2.json`): P215, P216 and P217. Tests passed. Verify note: `verify-b5-r2-D.md`.
- UX-1649, UX-1650, UX-1651, UX-1612 and UX-1652 were fixed.
- One regression was raised: R2D-1, which became UX-1653.

**Round 3** (`plan-b5-r3.json`): P218. Tests passed. Verify note: `verify-b5-r3-D.md`. UX-1653 was fixed, with no regressions.

## Noted by the reviewers, not raised (for the next `/ux` review)
None of these were caused by this batch.
- At 2× text, two email addresses still break mid-word:
  - the account subtitles in the phone-calendars list («maria.lopez@exam / ple.com»);
  - the subtitle of the Ajustes «Cuenta» row.
  The fix is the same as UX-1618's.
- On Recordatorios, «Tareas con hora» ends in a chevron, while «Tareas sin hora» ends in «+».
- At 2× text, the AUDIT for `settings/account · named` measures «Eliminar cuenta» at 27 dp tall.
- In Activity, «Marcar todo como leído» disappears when the last unread item comes back read mid-wait, which shifts the rows up. This has happened since P213.
- On a cold start after the phone's language changed, one first frame may show the old language (from P215's start-up seed). The emulator check in item 5 covers it.

## Ledger
`.claude/ux-review/ISSUES.md`: 22 lines moved, none deleted.
- 10 went to **Device check**: UX-1316, 1319, 1621, 1607, 1611, 1612, 1648, 1649, 1652 and 1653.
- 12 went to **Verified**: UX-1605, 1606, 1616, 1622, 1619, 1620, 1613, 1614, 1615, 1618, 1650 and 1651.
- Each moved line now carries:
  - its round and package;
  - its verify note;
  - its test references;
  - the phone check it still needs, where there is one.