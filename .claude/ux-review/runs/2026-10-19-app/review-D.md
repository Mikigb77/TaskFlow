## UX review — Area D: first run, sign-in, settings, notifications, native surfaces, theme — 2026-10-19

**Verdict:** Ship after fixes — sign-in, Ajustes and reminders work end to end on the emulator, but the first reminder can be promised and never come (UX-1601), a Spanish newcomer can't finish a password recovery (UX-1602), and eleven S2s weaken the first screen, the reminder set-up, the home-screen entries and Pro.

**Evidence used:** previews `App/build/ux/` rendered 2026-10-19 13:26–13:28 from 3a6ad40, all newer than their sources (`find App/lib App/assets -newer …` lists nothing); AUDIT.md (widget-test measurements); device captures `App/build/ux/device/` 13:30–14:42 from 3a6ad40 plus uncommitted non-UI App changes (TaskFlow_Review emulator, Pixel 4 profile 393 dp, API 36 — emulator evidence, not a phone); uiautomator dumps in `device/a11y/`; code. GUIDELINES.md read (§0, §18, §20 and the CO, SC, PL, RE, ON, TA, NO, UN, FO, AC, OL, SU, LO, PR sections).

**Walked** (N newcomer, D daily user, AT TalkBack / low vision / tremor):
1. Install → first screen: launcher icon → «Abriendo tu espacio…» → sign-in (N, AT). 1 tap to start.
2. Sign-in with Google: 2 taps to Calendar (N). Email sign-in, wrong password, offline, too many, email in use (N, AT).
3. Sign-up with the email code: about 7 actions plus a trip to the inbox (N).
4. Recovery: 6 actions, a trip to the inbox and copying a ~45-character code, or an English web page (N).
5. Privacy and Terms: 1 tap, from sign-in or Otros ajustes (N).
6. First dated save → «¿Quieres un recordatorio antes?» → Android's dialog → «Alarmas y recordatorios» sheet → Android's page → back: 5 actions, 2 system screens (N, Android 14+).
7. Ajustes → Recordatorios: on, blocked, exact alarms off; the message after «No permitir» (N, D).
8. A reminder arrives → expand → Completar / Posponer → tap opens the task (D, emulator).
9. Ajustes → Cuenta: name, Google link, sync, sign out, delete account (N; delete re-walked only for regressions).
10. Ajustes → TaskFlow Pro: free, dictations used up, file space full, active, complimentary, store error (N; SU-8 walkthrough).
11. Otros ajustes → Hora y región, Calendarios del teléfono (allow, deny, blocked), Botón de dictar (widget pin), Exportar e importar, Licencias, Privacidad, Términos (N).
12. Native: launcher icon, shortcuts, widget, share messages at 1.0 and 2.0 in ES, CA, EN (N).
13. Theme: light and dark, 1×/1.3×/2× text, 320/360/393 dp (AT).

**Numbers:**
- Install → Calendar: Google 2 taps; email sign-up ≈ 7 actions + inbox.
- Sign-in first screen: 10 tap targets and 2 decisions (Google or email; sign in or create) → 5 and 1 with UX-1603.
- Turning reminders on from the first dated save, Android 14+: 5 actions, 2 system screens; the confirmation came up to ~8 s after returning (emulator) → at once with UX-1605.
- Reminders with exact alarms off: 3 fix buttons → 1; blocked: 2 → 1 (UX-1606).
- Phone calendars: 63 words above «Conectar» → 15; calendars shown after connecting: 0 → all (UX-1611).
- Recovery code: ≈ 45 characters → 6 digits (UX-1602, server).
- Launcher icon: the mark is ≈ 26 dp of a 61 dp icon, 18% of its area (UX-1608).
- Ajustes tab: 11 targets (6 rows, avatar, 4 tabs), unchanged.
- New findings: S4 0 · S3 2 · S2 11 · S1 9.

### Findings (most severe first)

**UX-1601 · Severity 3 · The reminder question promises a reminder that can't come**
- Where: `App/lib/widgets/reminder_ask_sheet.dart:23-30` (asks after any save with `dueDate` or `deadline`); `App/lib/services/reminder_engine.dart:166-186` and `:203` (an alert whose time has passed is dropped); `App/lib/widgets/reminder_control.dart:105-109` (the confirmation). State: the account's first dated save is a date-only task for today saved after 9:00, or a timed task saved inside its lead time (16:55 for 17:00, 10 min before).
- The moment: "Le dije que sí, me dijo «Listo. Recordatorios activados.»… y nunca me avisó de llamar a Marta."
- What happens: at 11:00 the newcomer adds «Llamar a Marta» for today. The sheet asks «¿Quieres un recordatorio antes?»; «Sí, recuérdamelo» → Android's dialog → «Listo. Recordatorios activados.». Date-only tasks remind at 9:00 (D2b), already past, so `plan()` drops the alert: nothing fires, and the task's chip still reads «Recordatorio: 9:00».
- Why it fails: TA-6 reminders fire on time or the app says why not (Android Alarms); SC-11 end on visible success, peak–end (Kahneman 1993) — the first reminder is where trust is made; ON-8 tie the request to what will arrive (Kendrick 2018); OL-1 older adults blame themselves (Kane 2019).
- Fix: ask only after a save whose alert would still fire once reminders are on: run the saved tasks through the engine's `_firing` with `enabled: true` and `dateOnlyTime ?? 540`, and require `when` after now. Otherwise free the slot (the code already does when the sheet isn't shown) so the next such save asks. No copy change. This reads D2a's "first saved task with a date" as the first one a reminder can still serve (see Questions). Cross-slice B: the chip (`reminder_control.dart:208-215`) shouldn't show «9:00» for an alert time already past.
- Verify: widget test, clock at 11:00: a date-only task for today → no sheet; then one for tomorrow → sheet. At 16:55, a 17:00 task with 10 min → no sheet. Emulator: the same at 11:00.
- Evidence: verified in code. The sheet and Android's dialog were seen in emulator captures (`reminder-ask.sheet.es.light.1.0.png`, `permission-notifications.dialog.es.light.1.0.png`, for a task dated tomorrow). The today-after-9:00 case is inferred; needs a device check.

**UX-1602 · Severity 3 · Password recovery hands a Spanish newcomer an English code to copy**
- Where: `App/lib/screens/login_screen.dart:264-287` (the request sends only the email, no language); `:576-594` (code field: text keyboard, no one-time-code autofill); `:718-743` (the sent line sits under «Guardar contraseña nueva»); `Backend/core/auth_views.py:263-264` (subject «Reset your TaskFlow password», English body with a link and `{uid}:{token}`). Render `auth/sign-in.recovery-sent.es.light.1x.png`.
- The moment: "Me ha llegado un correo en inglés con un código larguísimo… ¿qué copio y dónde lo pego?"
- What happens: after «Enviar código» the card shows «Código de recuperación» and «Nueva contraseña» first. The only explanation, «Si la cuenta existe, se ha enviado un correo de recuperación.», sits under the button and never names the address. The email is English only (sign-up's code email and invitations are localized), and its code is about 45 characters to copy from the mail app and paste; the alternative link opens an English web page. Sign-up, by contrast, uses 6 digits in the app's language with the number pad (`verify_email_screen.dart:580-597`).
- Why it fails: FO-9 codes paste and autofill (WCAG 3.3.8) and FO-5 the right keyboard (Baymard 2015k); CO-3 nothing to remember (Cowan 2001); SC-9 one word, one thing — two kinds of «código»; SC-1 the instruction comes last; UN-7 / OL-2 (Neusesser & Sunwall 2023).
- Fix: cause likely server-side — send the recovery email in the app's language with a 6-digit code valid 30 minutes, as sign-up does. App side:
  - send `language` with `auth/password-reset/`, as `_signIn` does;
  - put the sent line above the code field, naming the address and keeping the privacy wording: ES «Si {email} tiene cuenta, te llegará un correo con un código. Escríbelo aquí.» / EN "If {email} has an account, an email with a code is on its way. Type it here." / CA «Si {email} té compte, t’arribarà un correu amb un codi. Escriu-lo aquí.»;
  - once the code is 6 digits, give the field the verify screen's number pad, `AutofillHints.oneTimeCode` and digits-only formatter.
- Verify: preview recovery-sent ES and CA at 2×: the line with the address sits above the field. Widget test: the reset request carries `language`. Staging: a Spanish account gets a Spanish email with 6 digits.
- Evidence: verified in code (app and server); seen in a current render; the email itself not seen.

**UX-1603 · Severity 2 · The first screen's filled button is the long email path**
- Where: `App/lib/screens/login_screen.dart:458-498` (Google, outlined white, then «o»), `:499-713` (email, password, forgot link, filled «Iniciar sesión»), `:795-805` («Crear una cuenta»); `App/lib/widgets/google_login_button.dart:13-27`. Renders `auth/sign-in.sign-in.es.light.{1x,1.3x,2x}`, `es.dark.1x`; emulator `first-run.sign-in.es.light.1.0.png`.
- The moment: "Pone «Inicia sesión» y el botón verde dice «Iniciar sesión»… así que escribo mi correo y una contraseña."
- What happens: the first screen offers two ways in and two modes at once: 10 tap targets. The only filled, saturated button (light teal in dark) submits email and password. Google — 2 taps to Calendar — is a white outlined button above an «o». The email path for a new person is ≈ 7 actions plus the inbox (create, a 12-character password, a 6-digit code): the path a newcomer is least likely to finish.
- Why it fails: SC-4 one primary action, set apart (M3 Buttons; von Restorff 1933); CO-2 few options per decision (Hick 1952; Cockburn 2007); CO-7 progressive disclosure (Nielsen 2006); ON-9 justify every step before the first task (Budiu 2014). D8 put Google first; emphasis and load should say the same.
- Fix (subtract): show «Continuar con Google» and, under it, one text button «Continuar con mi correo» / "Continue with email" / «Continua amb el correu», which reveals today's email form in place (Back folds it, as create and recovery return to sign-in). Keep the form open for sign-in-again, after returning from create or recovery, and while one of its errors shows. No «o» divider in the folded view. If the owner wants the fields always visible: at least make the email submit `FilledButton.tonal`. Update `auth_gate_test.dart`'s order test.
- Numbers: targets 10 → 5; decisions before acting 2 → 1.
- Verify: previews sign-in ES 1× and 2×, light and dark: one button-shaped control above the fold. `auth_gate_test`: Google first, email fields hidden until «Continuar con mi correo».
- Evidence: seen in current renders and an emulator capture. Which path newcomers take is inferred (§7 test).

**UX-1604 · Severity 2 · TalkBack reads the pitch and «o» before the heading, and errors last**
- Where: `login_screen.dart:446-456` (pitch `Text` with no node of its own); `:479-496` (the «o» divider); `:740-743` with `App/lib/widgets/app_components.dart:170-171` (`MessageBanner` is `Semantics(liveRegion: isError)` without `container`). Same merge on the delete page: «La copia no incluye los archivos.» is read before «Guardar antes una copia de tus tareas» (AUDIT `delete/delete-account · preview`).
- The moment (TalkBack): "«Apunta lo que tienes que hacer y TaskFlow lo pone en tu calendario. o»… ¿«o» qué? Y cuando me equivoco, oigo toda la frase otra vez antes del error."
- What happens: the pitch, the divider's «o» and any error banner merge into one node that contains the heading and the controls, so TalkBack reads it first: the emulator dump `a11y/first-run.sign-in.es.light.1.0.xml` has `content-desc="Apunta lo que… calendario.&#10;o"` before «Inicia sesión». In wrong-password, offline and too-many (AUDIT), the error joins that node, and it is the live region: the announcement is 12 words of pitch, «o», then «No encontramos esa cuenta o la contraseña no es correcta.»
- Why it fails: AC-6 name, role and a sensible order; AC-7 announce what changes (Android A11y testing); SC-1 front-load. The verify screen already fixed the same merge (`verify_email_screen.dart:562-575`).
- Fix: `Semantics(container: true)` around the pitch, as on the verify screen; `ExcludeSemantics` around the «o» row; `MessageBanner`: `Semantics(container: true, liveRegion: isError, …)`, so each banner is its own node and only its line is announced (sign-up's replaced banner already does this, `login_screen.dart:729-737`). The same container for the delete page's copy note.
- Verify: semantics test — order: heading → pitch → Google; the live-region node's label is the error alone. Emulator dump: no node ends in «o».
- Evidence: widget-test semantics (AUDIT) and an emulator uiautomator dump; TalkBack's speech needs a device.

**UX-1605 · Severity 2 · After allowing reminders, Recordatorios says they're blocked**
- Where: `App/lib/screens/notification_settings_screen.dart:50-60` (resume calls `_load`, which returns while `_busy`), `:115-124` (`_turnOn` holds `_busy` through the whole flow), `:214-217` («Abrir ajustes del sistema» isn't gated by `_busy`); `reminder_control.dart:98` (the confirmation waits for `access.reconcile`). Emulator `permission-alarms.allowed.es.light.1.0.png` (0.6 s after allowing) vs `permission-notifications.settings-on.es.light.1.0.png`.
- The moment: "Acabo de darle a permitir y pone «Permiso del sistema desactivado» con el interruptor apagado. ¿Lo hago otra vez?"
- What happens: from the switch through Android's dialog, the «Alarmas y recordatorios» sheet, Android's page and back, the screen keeps the values read before the tap: switch off and grey, «Permiso del sistema desactivado», and «Abrir ajustes del sistema» the only enabled button — which leads out of the app again. It settles only when the reminder refresh ends (by 8 s on the emulator), with «Listo. Recordatorios activados.».
- Why it fails: visibility of system status, gulf of evaluation (Norman 2013); UN-1 answer every tap; SC-11 end on visible success; recurring problem 18 (background work awaited in the tap path). Confirms SEEN #11.
- Fix: on resume, re-read the phone's permission even while busy (split a cheap capability read out of `_load`); while turning on, show the switch on and hide the problem block, restoring them if the person refuses; disable «Abrir ajustes del sistema» while busy; in `turnOnReminders`, show the confirmation once permission and exact access are read, and run `reconcile` unawaited.
- Verify: widget test with a fake access that grants during the flow: on every frame after the grant, the switch reads on and «Permiso del sistema desactivado» is absent. Emulator: recapture `permission-alarms.allowed`.
- Evidence: seen in an emulator capture; cause verified in code.

**UX-1606 · Severity 2 · When reminders can't arrive on time: a jargon line and three buttons**
- Where: `notification_settings_screen.dart:161-229`; `app_es.arb:583` `notificationPermissionOff` «Permiso del sistema desactivado», `:586` `openSystemSettings`, `:601` `retryScheduling` «Actualizar y reintentar»; the same line after «No permitir» (`reminder_control.dart:44-51`); the Ajustes row (`settings_screen.dart:42-49`, `:69-94`, reads `allowed` only). Renders `settings/reminders.blocked`, `settings/reminders.exact-alarms-off`, `first-run/reminder-question.refused.es.light.2x`; emulator `permission-notifications.settings-off`, `permission-notifications.denied-after-4s`.
- The moment: "«Permiso del sistema desactivado»… ¿qué sistema? ¿Abro ajustes, permito alarmas o actualizo y reintento?"
- What happens:
  - Blocked: «Permiso del sistema desactivado», «Abrir ajustes del sistema» (Android's App info, one more screen from the switch) and «Actualizar y reintentar».
  - Exact alarms off, Android 14's default for new installs: three buttons, and the right one, «Permitir «Alarmas y recordatorios»», is the plain text button between two outlined ones.
  - «Actualizar y reintentar» only helps after a failed set-up.
  - Right after «No permitir», the same jargon returns as a message with «Abrir ajustes del sistema»; at 2× it covers the task just saved.
  - Ajustes says «Activados · 10 minutos antes» while exact alarms are off, though reminders may then arrive up to an hour late (§0, Android Alarms).
- Why it fails: TA-6 say why, with one tap to the right setting; ON-7 a denial is not a dead end (Android Permissions); plain language (ISO 24495-1); CO-2; SC-4; SC-9 — Ajustes calls the same state «Bloqueados por el teléfono».
- Fix: one line in the person's words and one button per state:
  - blocked: ES «El teléfono no deja que TaskFlow te avise.» / EN "Your phone isn't letting TaskFlow notify you." / CA «El telèfon no deixa que TaskFlow t’avisi.», and one filled button «Permitir avisos» / "Allow notifications" / «Permet els avisos» that opens TaskFlow's notification page (`Settings.ACTION_APP_NOTIFICATION_SETTINGS`), not App info;
  - exact alarms off: keep the `exactAlarmsNeeded` line; «Permitir «Alarmas y recordatorios»» becomes the one filled button; no «Abrir ajustes del sistema»;
  - «Actualizar y reintentar» only when `_schedulerError != null`, renamed «Volver a intentarlo» / "Try again" / «Torna-ho a provar»;
  - the message after «No permitir» uses the new line;
  - Ajustes row, on but not exact: ES «Activados · pueden llegar tarde» / EN "On · may arrive late" / CA «Activats · poden arribar tard».
- Numbers: fix buttons with exact alarms off 3 → 1; blocked 2 → 1.
- Verify: renders reminders.blocked and exact-alarms-off, ES and CA at 2×: one filled button each. settings-tab with exact alarms off shows the new subtitle. A test that the blocked button opens the notification page.
- Evidence: seen in current renders and emulator captures; verified in code.

**UX-1607 · Severity 2 · Reminders aren't marked as reminders, so Do Not Disturb silences them**
- Where: `App/lib/services/notification_service.dart:72-84` — `AndroidNotificationDetails` has no `category`; the plugin (17.2.2) offers `AndroidNotificationCategory.reminder`.
- The moment: "Tengo «No molestar» por la noche con los recordatorios permitidos, y el aviso de las 7:30 no sonó."
- What happens: with Do Not Disturb on and its «Recordatorios» exception allowed, Android lets through notifications in the reminder category. TaskFlow's have no category, so they're held like any other app's, and nothing in the app says so.
- Why it fails: NO-2 mark reminders as reminders (Android Notifications); TA-6.
- Fix: `category: AndroidNotificationCategory.reminder` on the reminder notifications, not on the silent «Completada» line. No copy.
- Verify: unit test of `_details`. Device: Do Not Disturb on with Recordatorios allowed; a TaskFlow reminder sounds.
- Evidence: verified in code; delivery needs a device check.

**UX-1608 · Severity 2 · The launcher icon is a tiny «M» in a white disc**
- Where: `App/android/app/src/main/AndroidManifest.xml:15` (`android:icon="@drawable/app_icon"`, a 1024 px PNG in `res/drawable`); no `mipmap-anydpi-v26` adaptive icon; `res/mipmap-*/ic_launcher.png` are Flutter's default logo, unused. Emulator `launcher.home-icon.es.light.1.0.png`, `notification.shade.es.light.1.0.png`, `permission-alarms.system-page.es.light.1.0.png`.
- The moment: "¿Cuál es la de las tareas? ¿La «M»? Esa es la de Gmail…" — in the dock, where icons have no labels.
- What happens: Android draws a non-adaptive icon shrunk inside a white disc: the dark neon badge is ≈ 26 dp of a 61 dp icon, and its letter is an «M», like Gmail's beside it. Inside, the app's mark is a teal square with a white double tick and «taskflow»: the home screen, the splash and Android's own pages show one mark, the app another.
- Why it fails: SC-6 icons older adults recognize (Harley 2014; Leung 2011); SC-9 same thing, same look; PL-1 Android conventions. Confirms SEEN #13.
- Fix: an adaptive icon — `mipmap-anydpi-v26/ic_launcher.xml` with a solid background layer, a foreground filling the 66 dp safe zone and a monochrome layer for Android 13 themed icons — with density fallbacks; point `android:icon` at it and delete the unused Flutter PNGs. Draw it from the in-app mark unless the owner picks another (Questions).
- Verify: emulator recapture `launcher.home-icon`, light and dark, plus themed icons: the mark fills the icon, no white disc.
- Evidence: seen in emulator captures; verified in the manifest and resources.

**UX-1609 · Severity 2 · At large text the widget's label and both shortcuts are cut**
- Where: `res/layout/capture_widget.xml:1-8` (vertical: 32 dp mic over a 12 sp label, `maxLines 2`, 8 dp padding); `kotlin/com/example/agenda/CaptureShortcuts.kt:29-34` (`setShortLabel` with the full 16–18-character label, no long label). Emulator `widget.home.{es,ca}.light.2.0.png`, `launcher.shortcuts.{es,ca,en}.light.2.0.png`.
- The moment: "En el botón de la pantalla pone «Dictar una» y lo demás está cortado. Y al mantener pulsado: «Dictar un…», «Escribir u…»."
- What happens: at 2.0 the widget's second line is clipped in Spanish («Dictar una / tare…») and Catalan («Dicta una / tasca» cut): 8 + 32 + two 24 dp lines + 8 exceed the cell's ≈ 87 dp. The launcher menu shows the short label, which is the full name, so at 2.0 about 8 characters fit: «Dictar un…», «Escribir u…», «Dicta un…», «Escriu u…», "Say a ta…", "Type a t…".
- Why it fails: AC-3 works at 200% text (WCAG 1.4.4); PL-9 short label ≈ 10 characters (Android Shortcuts); PL-10 widget quality. Confirms SEEN #12, and it's wider: Spanish and English too.
- Fix:
  - shortcuts: a short label of 8 characters or fewer, and the full name as the long label (the launcher uses it when it fits): ES «Dictar» / «Escribir» (long «Dictar una tarea» / «Escribir una tarea»); CA «Dicta» / «Escriu» (long «Dicta una tasca» / «Escriu una tasca»); EN "Dictate" / "Type" (long "Say a task" / "Type a task"); new resources `capture_voice_short`, `capture_text_short`;
  - widget: put a 24 dp mic beside the label instead of above it, so two lines fit one cell's height at 2.0.
- Verify: emulator recapture launcher.shortcuts and widget.home at 1.0 and 2.0 in ES, CA, EN: whole words.
- Evidence: seen in emulator captures; verified in code.

**UX-1610 · Severity 2 · Share messages are cut mid-word**
- Where: `res/values*/strings.xml` `share_too_long`, `share_empty`, `share_queue_full`, `share_not_saved`, shown as toasts (`CaptureEntryBridge.kt:66-86`). Emulator `share.too-long-toast.es.light.1.0.png`.
- The moment: "«…Comparte un texto más co…» ¿más qué?"
- What happens: Android shows two lines of a toast. At 1.0 the Spanish too-long message stops at «más co…»; `share_queue_full` (71–73 characters) and `share_not_saved` (67) don't fit two lines either; at 2.0 every one is cut. A toast can't be read again.
- Why it fails: AC-3; UN-7 say what happened and what to do, never only as a toast (Neusesser & Sunwall 2023; Flaherty 2024); SC-1 front-load. Confirms SEEN #8.
- Fix: front-loaded copy that fits two lines:
  - too long: ES «Texto demasiado largo: máximo 4000 caracteres.» / EN "Text too long: 4,000 characters at most." / CA «Text massa llarg: màxim 4.000 caràcters.»;
  - empty: ES «No hay texto que añadir.» / EN "No text to add." / CA «No hi ha cap text per afegir.»;
  - queue full: ES «Abre TaskFlow y termina lo que compartiste.» / EN "Open TaskFlow and finish what you shared." / CA «Obre TaskFlow i acaba el que has compartit.»;
  - not saved: ES «No se ha guardado. Vuelve a compartirlo.» / EN "Not saved. Share it again." / CA «No s’ha desat. Torna-ho a compartir.»
  Area A may prefer showing these inside the app instead.
- Verify: emulator recapture of the four toasts at 1.0 and 2.0 in ES, CA, EN; `native_resources_test.dart` caps their length.
- Evidence: seen in an emulator capture (ES, 1.0); the others inferred from Android's two-line toast and the string lengths.

**UX-1611 · Severity 2 · Connecting the phone's calendars shows nothing**
- Where: `App/lib/screens/device_calendars_screen.dart:69-73`, `:88-100`, `:134-139`; `App/lib/providers/device_calendar_provider.dart:71-74` (events show only with a ticked calendar) and `:164-173` (`enable` keeps the empty selection). Emulator `permission-calendar.explanation.es.light.2.0.png`, `permission-calendar.denied.es.light.1.0.png`, `permission-calendar.allowed.es.light.1.0.png`.
- The moment: "Le di a conectar y a permitir… y en el calendario no sale nada. ¿Y ahora pone «Ocultar»?"
- What happens:
  - before asking, 63 words (a 14-word heading, a 34-word paragraph, a 15-word line) sit above «Conectar calendarios del teléfono»; at 2.0 the button is below the fold;
  - after «No permitir» the screen is unchanged; nothing mentions the refusal;
  - after «Permitir», the first control, where «Conectar» was, is «Ocultar eventos del calendario»; under «ELEGIR CALENDARIOS» the calendars are unticked, and Calendar shows no event until one is ticked;
  - «Actualizar calendarios» shows in every state, before access too.
- Why it fails: CO-6 defaults decide (Johnson & Goldstein 2003); SC-11 end on visible success; RE-6 keep the off switch out of the primary place; SC-5 the key action on the first screen at 2×; ON-7 say what a refusal means. Confirms SEEN #9.
- Fix:
  - after «Conectar» and allowing, tick every visible calendar (up to 50) and say: ES «Conectado. Los eventos se ven en Calendario.» / EN "Connected. Events show in Calendar." / CA «Connectat. Els esdeveniments es veuen a Calendari.»;
  - move «Ocultar eventos del calendario» below the list, as a plain text button;
  - before access, one line and the button: ES «Verás los eventos de tu teléfono en Calendario. Solo se leen aquí; no se suben.» / EN "You'll see your phone's events in Calendar. They're only read here, never uploaded." / CA «Veuràs els esdeveniments del telèfon a Calendari. Només es llegeixen aquí; no es pugen.»;
  - after a refusal: ES «Sin permiso, TaskFlow no puede ver tus eventos.» / EN "Without permission, TaskFlow can't see your events." / CA «Sense permís, TaskFlow no pot veure els esdeveniments.»;
  - hide «Actualizar calendarios» until access is granted.
- Numbers: words above the button 63 → 15; buttons before access 2 → 1; calendars shown after connecting 0 → all.
- Verify: provider test: allowing selects every calendar and `showing` is true. Preview phone-calendars ES 2×: the button above the fold. Emulator recapture.
- Evidence: seen in emulator captures and current renders; verified in code.

**UX-1612 · Severity 2 · Cuenta shows a slogan where your name belongs, and the name can't be changed**
- Where: `App/lib/screens/account_screen.dart:182-190` (`accountHeading` «Tu propio espacio.» above the email); `App/lib/widgets/name_ask_sheet.dart:41-86` (asked once per account and phone; «Ahora no», Back or a swipe count as asked); no other caller of `setFirstName` (`App/lib/providers/auth_provider.dart:162`). Render `settings/account.email.es.light.1x.png`.
- The moment: "Mi hija me ve como «maria.lopez84»… ¿dónde pongo mi nombre?" — or: "Escribí «Mria» y no hay forma de cambiarlo."
- What happens: the name others see in shared projects (D8) is asked once, at the first share or join. After «Ahora no» or a typo, nothing in the app shows or changes it. Cuenta, where people look, shows a slogan and the email.
- Why it fails: OL-1 every step can be undone or retried (Kane 2019); error recovery (Nielsen 1994h); CO-5 cut decoration; SH-2 awareness relies on names.
- Fix: replace «Tu propio espacio.» with the person's name as the heading, and add one row under the email: ES «Tu nombre: María · Cambiar» / EN "Your name: María · Change" / CA «El teu nom: María · Canvia», opening the existing name sheet prefilled; with no name, «Añadir tu nombre» / "Add your name" / «Afegeix el teu nom». Google accounts too.
- Numbers: Cuenta targets 5 → 6; the row replaces a slogan.
- Verify: widget test: Cuenta shows the server's first name, the row opens the sheet, and saving updates the chips (as UX-1102's test).
- Evidence: verified in code; seen in a current render.

**UX-1613 · Severity 2 · The Pro screen never says what Pro gives**
- Where: `App/lib/screens/subscription_screen.dart:74-145` (card: sparkle, «TaskFlow Pro» again, `billingIntro` «Tu suscripción, en un solo lugar.»), `:176-191` (price and «Ver suscripción» after the card). Renders `settings/pro.free.es.light.1x.png`, `settings/pro.free.ca.light.2x.png`.
- The moment: "Se me han acabado los dictados y me trae aquí… ¿qué me da Pro?"
- What happens: a free person arrives from «Ver Pro». The card repeats the app bar's title and says «Tu suscripción, en un solo lugar.»; nothing names what Pro adds before the price and «Ver suscripción» (the benefits live in RevenueCat's paywall, a tap further). At 2× in Catalan the card fills the first screen; the price and the button are below the fold, about half a screen further down, after a 6-line renewal paragraph.
- Why it fails: CO-1 one job a newcomer can name; SU-7 explain a limit when it bites; SU-8 walk upsells as the most vulnerable user (Rosala 2023); SC-5 the key action without scrolling, or pinned; CO-5.
- Fix: drop the card's repeated heading and icon; replace `billingIntro` with what Pro adds, within the 2026-10-13 decision: ES «Dictados sin límite y espacio para todos tus archivos.» / EN "Unlimited dictations, and room for all your files." / CA «Dictats sense límit i espai per a tots els fitxers.»; for free accounts, pin «Ver suscripción» at the bottom, as the task form pins its button. Optional, no new control: Ajustes' Pro row subtitle for free accounts reads «Dictados gratis: 4 de 10».
- Verify: preview pro.free ES and CA at 2×: the value line and «Ver suscripción» visible without scrolling.
- Evidence: seen in current renders; verified in code.

**UX-1614 · Severity 1 · Pro's buttons touch, subscribers see Restaurar first, and a retry has nothing to tap**
- Where: `subscription_screen.dart:184-222`; AUDIT `settings/pro · free`: 0 dp between «Ver suscripción» and «Restaurar compras»; render `pro.active` (Restaurar above Gestionar); `pro.store-error` («La tienda no pudo completar la solicitud. Inténtalo de nuevo.» with only «Restaurar compras» below).
- Why it fails: RE-3 / RE-6 spacing (Jin 2007); SU-4 cancelling as easy as subscribing; UN-7 a next step.
- Fix: 8 dp between the two buttons; while Pro is active, hide «Restaurar compras» and its help so «Gestionar suscripción» stands alone; `billingError` `store` and `other` end like UX-509's network line: ES «La tienda no respondió. Vuelve a abrir esta pantalla.» / EN "The store didn't answer. Open this screen again." / CA «La botiga no ha respost. Torna a obrir aquesta pantalla.»
- Verify: AUDIT gap ≥ 8 dp; subscription_screen_test for the active state.
- Evidence: current renders and AUDIT.

**UX-1615 · Severity 1 · Outlined buttons have a 1.2:1 border**
- Where: `App/lib/theme/app_theme.dart:109-113` (`side: scheme.outlineVariant`). It affects every OutlinedButton: «Restaurar compras», «Abrir ajustes del sistema», «Actualizar calendarios», «Elegir archivo para importar», «Crear una cuenta con este correo».
- What happens: #DFE5DC on #F7F8F2 is 1.20:1 (dark: #34413A on #121816, 1.68:1), so the button's shape barely shows and it reads as a link. M3's outlined button uses `outline`: 3.55:1 light, 5.40:1 dark here. Chips and fields already moved to `outline` (UX-1012, UX-412).
- Why it fails: AC-2 (WCAG 1.4.11; M3 Color roles); recurring problem 14.
- Fix: `side: BorderSide(color: scheme.outline)`.
- Verify: `appearance_test.dart` asserts the outlined theme's side is `outline`, as for chips.
- Evidence: verified in code; ratios computed from the theme's colours.

**UX-1616 · Severity 1 · Reminder times open the clock dial, and the lead time clips at 2×**
- Where: `notification_settings_screen.dart:147-153` and `reminder_control.dart:179-182` (`showTimePicker` without `initialEntryMode`), unlike `task_editor.dart:382-384` (typing, UX-1004); `notification_settings_screen.dart:231-244` (eyebrow «OPCIONES PREDETERMINADAS» and a `DropdownButtonFormField`). AUDIT `settings/reminders · on` at 2×: «10 minutos antes» clipped to «10 minutos».
- Why it fails: FO-4 typing as well as the dial (Kane 2019); SC-9; AC-3.
- Fix: `initialEntryMode: TimePickerEntryMode.input` in both pickers; «Tareas con hora» becomes a list row like «Tareas sin hora», opening the reminder chip's one-tap list, so its value wraps; drop the eyebrow.
- Verify: render reminders.on ES 2×: «10 minutos antes» whole; a test that both pickers open in input mode.
- Evidence: verified in code; AUDIT.

**UX-1617 · Severity 1 · Sign-in at 2× and after an error: cut labels, a cut error, touching links, two identical buttons**
- Where: `login_screen.dart:543-547` (email `labelText`) and `:621-624`; `:546` (`errorMaxLines: 4`); `:665-681` (forgot link, 0 dp from the field and from «Iniciar sesión»); `:758-771` with `:795-805` (wrong password shows «Crear una cuenta con este correo» and «Crear una cuenta», 8 dp apart, both `_mode(register: true)`). AUDIT `auth/sign-in · sign-in` ES 2× «Correo elect…», CA 2× «Correu elect…» and «Contrasen…»; `email-in-use` ES 2× «…Inicia sesión o recupera…»; render `sign-in.wrong-password.es.light.1x.png`.
- Why it fails: AC-3; RE-3 / RE-6; SC-9 and CO-2 — two controls for one action (UX-495 fixed the same for «¿Has olvidado…?»).
- Fix: email label «Correo» / "Email" / «Correu» (if Catalan «Contrasenya» still cuts at 2× on 360 dp, `floatingLabelBehavior: always` on these fields); email-in-use error ES «Este correo ya tiene una cuenta.» / EN "This email already has an account." / CA «Aquest correu ja té un compte.» (the button under it says what to do); 8 dp above and below «¿Has olvidado tu contraseña?»; hide the bottom «Crear una cuenta» while «Crear una cuenta con este correo» shows.
- Verify: AUDIT re-render: no cut text in auth/sign-in at 2× ES and CA; gaps ≥ 8 dp; one create control in wrong-password.
- Evidence: current renders and AUDIT; verified in code.

**UX-1618 · Severity 1 · Email addresses break mid-word at 2×**
- Where: `account_screen.dart:187-190` («maria.lopez@example.c / om»); `delete_account_screen.dart:384` and the strings built at `:404`, `:414`, `:723` («maria.lopez@ex / ample.com»); `verify_email_screen.dart:505-523` (CA «exam / ple»). AUDIT `settings/account · email` 2×, `delete/delete-account · preview` 2×, `auth/verify-email · code-entry` CA 2×.
- Why it fails: AC-3; SC-1 readability.
- Fix: one display helper that lets an address break only after «@» and «.» (zero-width spaces in the shown text; TalkBack keeps the plain address).
- Evidence: AUDIT and current renders.

**UX-1619 · Severity 1 · Hora y región: an orphan «Madrid», a reassurance paragraph, two dropdown styles**
- Where: `App/lib/screens/regional_settings_screen.dart:56` (`regionHelp`), `:101-117` (the resolved zone as a bare line under the help), `:125-140` (underlined `DropdownButton`s, unlike every other picker). Render `settings/region.normal.es.light.1x.png`.
- Why it fails: CO-5; SC-9 (Idioma and Apariencia use a sheet of radio rows); Gestalt proximity (Palmer 1992).
- Fix: drop `regionHelp`; put the zone in its row, ES «Como el teléfono (Madrid)» / EN "Same as phone (Madrid)" / CA «Com el telèfon (Madrid)», and delete the separate line; make the clock and week-start rows open sheets of radio rows, like Idioma.
- Evidence: current render; code.

**UX-1620 · Severity 1 · Exportar e importar: jargon, a slogan, and every result said twice**
- Where: `App/lib/screens/data_transfer_screen.dart:148-164` («Llévate tus tareas.»; `chooseImportFileHelp` with «JSON», «CSV», «32 MB», «5.000»), `:48-53` (each result shown as a banner and also as a snackbar). Render `settings/data-transfer.start.es.light.1x.png`.
- Why it fails: plain language (ISO 24495-1); recurring problem 7; CO-5.
- Fix: drop the headline; ES «Elige un archivo de TaskFlow o un proyecto exportado de Todoist. Podrás revisarlo antes de importar.» / EN "Choose a TaskFlow file or a project exported from Todoist. You'll review it before importing." / CA «Tria un fitxer de TaskFlow o un projecte exportat de Todoist. El podràs revisar abans d’importar-lo.» (limits only when a file exceeds them); show each result once, in the banner.
- Evidence: current render; code.

**UX-1621 · Severity 1 · The widget, shortcuts and share messages ignore the app's language**
- Where: `CaptureShortcuts.kt:31` and `CaptureEntryBridge.kt:66-86` (`getString`), `res/layout/capture_widget.xml`: Android resources follow the phone's language; the app and its reminders follow Ajustes › Idioma (`App/lib/services/reminder_copy.dart:22-28`).
- What happens: with the phone in Spanish and TaskFlow set to Català, the app and its reminders speak Catalan; the widget, the shortcuts and share messages speak Spanish.
- Why it fails: LO-11 one language setting for app and native strings (Android App languages); SC-9.
- Fix: on Android 13+, apply the app's language as the per-app language (`LocaleManager.setApplicationLocales`) at start and when Idioma changes, then republish the shortcuts and refresh the widget.
- Evidence: verified in code; needs a device check.

**UX-1622 · Severity 1 · The «Alarmas y recordatorios» sheet has no visible way out or next step**
- Where: `reminder_control.dart:73-94` (one filled button; leaving takes Back, a swipe or a tap outside). Emulator `permission-alarms.app-sheet.es.light.1.0.png`, `permission-alarms.system-page.es.light.1.0.png`.
- Why it fails: OL-5 an explicit way out (Harada 2013); PL-4; ON-2 teach at the moment of need (Laubheimer 2023) — Android's page has a switch and no "done".
- Fix: «Ahora no» under the button (the reminder question's `reminderAskNotNow`), and a second line on this sheet only: ES «En la siguiente pantalla, activa el interruptor y vuelve.» / EN "On the next screen, turn on the switch, then come back." / CA «A la pantalla següent, activa l’interruptor i torna.»
- Evidence: seen in emulator captures; code.

### Keep
- Reminder notifications: task first, absolute time, short — ES «Hoy a las 14:13 · en 10 min», CA «Avui a les 14:50 · d’aquí a 10 min» — with «Completar» and «Posponer 10 min» (emulator).
- Tapping a reminder opens that task's «Detalles de la tarea» (emulator, app running; SEEN #10 not reproduced).
- The reminder question waits for the save message, and Android's prompt follows «Sí, recuérdamelo» at once (emulator).
- Ajustes: six rows, Recordatorios first with its real state; the email-code screen (number pad, one-time-code autofill, honest resend waits).
- Delete account: what goes and what stays, named; the red button last, apart from sign-out.

### Progress against UX_REVIEW.md (U1–U14)
- **U12** advanced: the one-time question → Android's dialog → «Alarmas y recordatorios» → «Listo» runs end to end on the emulator. Regressed at the edges: it can promise a reminder that can't fire (UX-1601), and its ending shows the opposite state for seconds (UX-1605).
- **U14** holds: Google first, one line on what TaskFlow does, no Google button in recovery. Its emphasis and load don't match the order yet (UX-1603).
- **U13** still open. New evidence for UX-421: Catalan «Configuració» breaks mid-word at 393 dp (emulator `screen-settings.list.ca.light.2.0.png`, «Configuraci / ó») and at 360 dp (preview `settings-tab.normal.ca.light.2x`, «Configurac / ió»), not only below 360 dp.
- **U11** holds in area D (no «Bandeja», «captura» or «Bandeja personal» on the default path). New jargon: «Permiso del sistema desactivado» (UX-1606).
- **U10** (area B): the Ajustes tab has 11 targets; the avatar duplicates the «Cuenta» row there, left for U13.

### Questions for the owner
1. **Lock screen (NO-9).** Reminders set no visibility, so on most phones the task title shows on the lock screen. Keep that, or private by default (title hidden until unlocked)?
2. **D2a / D2b (UX-1601).** (a) Is it OK that the one-time reminder question waits for the first dated task a reminder can still serve? (b) A date-only task for today saved after 9:00 gets no reminder at all. Keep that, or remind it at a later default (an hour after saving, or 18:00)? TA-5.
3. **D8 (UX-1603).** OK to fold the email fields behind «Continuar con mi correo»? Google stays first; people who sign in by email tap once more.
4. **Launcher mark (UX-1608).** Redraw the adaptive icon from the in-app mark (teal square, double tick; recommended, since that's what people see inside), or keep the «M» artwork as an adaptive icon?
5. **UX-421 / U13.** The Catalan tab label breaks mid-word on 360 and 393 dp phones at 1.3× and above. Extend the below-360 dp label stopgap to any width where the label doesn't fit, or wait for U13?
6. **Phone calendars (UX-1611).** Show every calendar by default after connecting (recommended), or keep "choose first"?
7. **Name on Cuenta (UX-1612).** A «Tu nombre» row adds one control; without it, a skipped or mistyped name can't be fixed (D8 asks once). OK?

### Emulator evidence for existing issues and SEEN-2026-10-19
- **SEEN #1** fixed: both shortcuts open the right place (`shortcut-voice.after-tap` listening, `shortcut-text.after-tap` the form).
- **SEEN #2** (a server-added task's reminder late by minutes) not reproduced in this run. A possible app-side cause for the phone check: a process killed mid-refresh leaves the 2-minute reminder lease (`reminder_engine.dart:255-277`); refreshes in that window wait `leaseWait` 10 s (`:98`), fail with `refresh_failed`, and the new alert waits for a later refresh.
- **SEEN #8, #9, #11, #12, #13** confirmed on 3a6ad40: UX-1610, UX-1611, UX-1605, UX-1609 (week strip part to B), UX-1608.
- **SEEN #10** not reproduced with the app running (`notification.tap-landing` opens «Pagar la luz»'s details). A cold start from a reminder wasn't captured; UX-424's phone check stands.
- **SEEN #3–#7, #14**: areas A and B (see Cross-slice notes).
- **UX-121** passes on the emulator: «Dictar una tarea», «Escribir una tarea», and «Toca para dictar una tarea.» in the widget picker.
- **UX-125** passes: two different shortcut icons, not clipped.
- **UX-409** passes: absolute bodies in ES and CA. A re-fired snooze wasn't captured.
- **UX-411**: the dump after Completar shows «Completada: Llamar al dentista». The screenshot taken just after the tap shows the reminder gone and the line not yet posted, so the background latency is visible; Deshacer itself wasn't opened.
- **UX-401, UX-439** pass: the question after the save message, Android's dialog after «Sí».
- **UX-436** passes («Listo. Recordatorios activados.» after allowing), but see UX-1605.
- **UX-119** half: the share toast is in Spanish, but cut (UX-1610).
- **UX-406, UX-427** pass at 360 dp, 2.0 (`screen-settings.list-360dp`); below 360 dp not captured.

### Cross-slice notes
- **A:** SEEN #3 — on the recording path a second microphone denial isn't detected (`permission-mic.blocked.ca` keeps the first banner, no way to Settings).
- **A:** SEEN #4 (countdown frozen at «Quedan 10 segundos») and #5 (60 s with nothing heard resets silently).
- **A:** SEEN #6 — «escribe abajo» with no field below; «Abrir Ajustes» lands on App info.
- **A:** SEEN #14 — the text shortcut started with the launcher's flags lands on Calendar with «Sin guardar · 4».
- **A:** share errors could show inside the app instead of a toast; UX-1610 changes only the words.
- **A / B:** SEEN #7 — Back from a shared task's form saves it undated, with no message.
- **B:** the week strip at 2× on 360 dp shows «do» for «dom» and «2» for «20» (SEEN #12; `first-run/reminder-question.refused.es.light.2x.png`).
- **B:** the reminder chip reads «Recordatorio: 9:00» for an alert time already past (with UX-1601).
- **C:** UX-1612 opens C's name sheet (`name_ask_sheet.dart`) from Cuenta.

### Memory notes
- **Area D map (2026-10-19):**
  - sign-in: Google first, outlined white; the email form always open, with the filled submit; Privacy and Terms under the card;
  - recovery: English `uid:token` email from `Backend/core/auth_views.py:263`;
  - Recordatorios: one switch; problem rows: blocked → Abrir ajustes + Actualizar y reintentar; exact off → 3 buttons;
  - the turn-on flow: question → Android dialog → exact sheet → Android page → «Listo» after an awaited reconcile;
  - Cuenta: slogan headline, no name row; Pro card: no value line;
  - phone calendars: connecting selects nothing;
  - native: launcher `@drawable/app_icon` (non-adaptive «M»); shortcuts published from code with a short label only (`CaptureShortcuts.kt`); widget vertical layout, 12 sp, 2 lines; share errors as toasts.
- **New recurring problems:**
  - loose `Text` and non-container banners merge into the parent semantics node — read before headings, and live regions announce their siblings (login, delete page);
  - native surfaces (widget, shortcut labels, toasts) clip at 2.0 — check them in every native-string change;
  - a screen keeps stale state while a flow it started runs elsewhere (Recordatorios during `turnOnReminders`);
  - a one-time question asked when it can't deliver (the reminder sheet for an alert time already past).
- **Patterns:**
  - time pickers: the task form types (`TimePickerEntryMode.input`); reminder pickers use the dial — a departure;
  - OutlinedButton borders use `outlineVariant`, a departure from M3 and from the chip and field fix;
  - Android's per-app language isn't set, so native strings follow the phone.
- **Evidence:** the device lane (`App/build/ux/device/`, Pixel 4 393 dp, API 36) shows Android's own surfaces at 1.0 and 2.0, and its `a11y/*.xml` dumps confirm merged TalkBack nodes. Captures can be taken a moment apart from their dumps: after-complete's PNG and XML differ.
