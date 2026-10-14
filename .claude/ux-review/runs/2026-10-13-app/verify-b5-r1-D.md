# Verify — 2026-10-13-app, batch 5, round 1, area D — 2026-10-14

Scope: P17 (UX-402, UX-403, UX-415, U14) and P18 (UX-404, UX-418, UX-422, UX-406, UX-120, UX-431). Evidence comes from the code (`git diff HEAD`), the tester's passing tests, and the re-rendered `App/artifacts/auth/login-light.png` / `login-dark.png` (14 Oct 04:36, newer than the code). No Settings, Otros ajustes or Hora y región render exists, so those screens were judged from the widget code.

## Results

| ID | Result | Evidence |
|---|---|---|
| UX-402 | fixed (phone check) | `login_screen.dart:249-254` detects `credentials` in sign-in mode; `:561-575` shows `createAccountWithEmail` under the banner; `_mode` (`:56-69`) keeps the email, and keeps the password unless recovery is involved. Headings `signInHeading`/`registerHeading`/`recoveryHeading` read Inicia sesión / Crea tu cuenta / Recupera tu contraseña; `requestError.credentials` uses the brief's copy in all three languages. Render: the heading "Sign in" names the mode. Remaining issue, not a regression: the sign-in validator (`:491-494`) still applies the 12-character creation rule. A newcomer whose everyday password is shorter gets "Usa al menos 12 caracteres" and never reaches the error that offers the create button. Suggest that sign-in mode only check that the password isn't empty. |
| UX-403 | fixed | Errors about the email or the password go on the field (`_fieldFor` `:94-101`, `errorText` `:405`, `:466`). Other errors scroll into view: `_reveal` `:111-136`, which honours reduced motion. Before typing, the password helper `passwordHelp` reads "Al menos 12 caracteres, no solo números" in create and recovery modes (`:469-471`). The field error clears as the user types. |
| UX-415 | fixed | PopScope `:263-267`: Back from create or recovery returns to sign-in. Recovery buttons read `sendRecoveryCode` and then `saveNewPassword` (`:255-258`), and `continueRecovery` is gone from the catalogs. On success (`:154-159`) the app returns to sign-in with the email and the new password filled in, and shows `passwordResetComplete`. |
| U14 (option 1) | fixed (phone check) | Google is first in sign-in and create (`:331-371`). `authPitch` sits under the heading (`:321-329`). Recovery has no Google button. Render `login-light.png`: heading, pitch line, then Continuar con Google, all above the fold. Option 2 was left out on purpose. |
| UX-404 | fixed | `settings_screen.dart:22-72` has exactly six rows: Recordatorios, which shows its state (`:28-36`), then Idioma, Apariencia, Cuenta, TaskFlow Pro and Otros ajustes. The eyebrow, headline, section labels and tagline are gone; `welcomeSettings`, `moreClarity` and `notifications` are removed from the catalogs. The Recordatorios screen title is `reminders` (`notification_settings_screen.dart:179`). |
| UX-120 | fixed (phone check) | `other_settings_screen.dart:88-94`: the diagnostics row appears only when `debug` is set. `:95-99` and `:116-147`: on staging, a long-press on the version opens a sheet with Diagnóstico de captura and Detalles de conexión; in production `onLongPress` is null. |
| UX-418 | fixed | The three theme tiles are replaced by the Apariencia row and a sheet of full-width `RadioListTile`s (`settings_screen.dart:41-49`, `:86-152`). |
| UX-406 | fixed (phone check: 320 dp at 2×) | `ThemeToggle` and `showAppearance` are deleted (`custom_app_bar.dart`, `app_components.dart`, `task_editor.dart`), and grep finds none left. The sign-in screen has none (`login_screen.dart:281-290`). ThemeMode.system remains the default. 23 → 1 appearance controls. |
| UX-422 | partly | Done: the title is `regionalFormats` "Hora y región" (`regional_settings_screen.dart:50`); the second language picker is gone; the row reads "Zona horaria" (`:82`); time zones show city names (`:22`, `:86`, `:190`) while the id is still stored (`:191`); "Como el teléfono" is used; the language sheet's paragraph is deleted (`language_selector.dart:111`). Still open: the 25-word help the finding names is still on screen as `timezoneHelp` (`:105`). In Spanish it is now 31 words and says "nuevas capturas" twice. `timezoneFallback` (`:112`) says "Las nuevas capturas usarán…". So "capture" jargon remains on the screen even though "de captura" left the label. Fix: replace `timezoneHelp` with one line — ES "Las tareas nuevas usan esta zona para entender las fechas." / EN "New tasks use this time zone to read dates." / CA "Les tasques noves fan servir aquest fus horari per entendre les dates." — and in `timezoneFallback` replace "Las nuevas capturas" with "Las tareas nuevas" (EN "New tasks", CA "Les tasques noves"). |
| UX-431 | fixed | `:164-166` uses `matchesSearch('${timeZoneName(z)} $z', query)`, so accents fold and both the city and the id are searched. Remaining issue, not a regression: city names are English tz names, so "Londres" or "Nueva York" find nothing. |

## Regressions (only in the changed files)

**R1D-1 · Severity 2 · Recordatorios says "Activados" when the phone blocks alerts**
- Where: `App/lib/screens/settings_screen.dart:28-36`, the new subtitle on the Recordatorios row.
- The moment: "It says reminders are on, so why didn't it ring?"
- What happens: the subtitle reads only `reminders.enabled` and `leadMinutes`. If notification permission is revoked, or was never granted on Android 13+, Settings still says "Activados · 10 minutos antes". Only the Recordatorios screen shows `notificationPermissionOff` (`notification_settings_screen.dart:203-211`).
- Why it fails: visibility of system status (Nielsen #1); gulf of evaluation (Norman). The status line now promises something the phone won't deliver.
- Fix: when reminders are enabled but `reminderAccessProvider.capability()` reports `allowed == false`, the subtitle reads ES "Bloqueados por el teléfono" / EN "Blocked by your phone" / CA "Bloquejats pel telèfon", in the error colour, with an icon so colour isn't the only signal.
- Verify: a widget test with a fake ReminderAccess where `allowed: false` and the preferences on shows the blocked line. On a phone, revoke the notification permission and return to Ajustes.
- Evidence: verified in code; the real permission state needs a device check.

**R1D-2 · Severity 1 · Two side-by-side sheets use two selection styles**
- Where: `App/lib/screens/settings_screen.dart:95-152` (Apariencia: radio rows, no close button, "Como el teléfono") next to `App/lib/widgets/language_selector.dart:96-151` (Idioma: tinted cards with a check, a close X, "Usar idioma del teléfono" / "Idioma del teléfono · …").
- The moment: rows 2 and 3 of Ajustes open sheets that look and close differently, and "follow the phone" has two names.
- Why it fails: consistency and standards (Nielsen #4); one concept, one name (ISO 24495-1).
- Fix: use one pattern for both sheets. Give the Language sheet the Apariencia radio rows and remove its close X; the drag handle and the scrim already close it. Rename `languageAutomatic` to ES "Como el teléfono" / EN "Same as phone" / CA "Com el telèfon", and `languageFollowing` to ES "Como el teléfono · {language}" / EN "Same as phone · {language}" / CA "Com el telèfon · {language}".
- Verify: widget test — both sheets contain `RadioListTile`s and the text "Como el teléfono".
- Evidence: verified in code.

## Notes (not regressions)
- In create mode, the email-in-use error (`requestError.emailUsed`) now sits on the email field. It tells people to sign in but offers no button. This mirrors UX-402. If it shows up in testing, a "Iniciar sesión con este correo" button would close the loop.
- The time-zone list keeps the legacy `US/*` and `Canada/*` ids, so "Pacific", "Eastern", "Central" and "Mountain" each appear twice with no country. Their offsets match, so the harm is minimal.
