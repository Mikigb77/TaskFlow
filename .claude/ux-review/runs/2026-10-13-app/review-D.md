## UX review — Slice D: first run, sign-in, settings, notifications, native surfaces, theme — 2026-10-13

All paths are relative to `C:\Users\mikig\Desktop\Custom\MikiHacks\TaskFlow\TaskFlow\`.

**Verdict:** Ship after fixes. There is one blocker: a dated task shows "Recordatorio: 10 minutos antes", but reminders are off by default and nothing ever turns them on. Sign-up also has two dead ends that would stop the newcomer.

**Walked** — the newcomer (Spanish, text at 2×, one hand) did every flow:
1. Install → Calendar. By email: 5 actions, plus a likely wrong turn into *Iniciar sesión*. With Google: 3 actions, plus a scroll at 2×.
2. A failed sign-in → create an account → the server's password rules.
3. Password recovery (about 11 steps).
4. Turning reminders on from zero (7–8 steps on Android 14+).
5. A reminder fires → tap it, or *Completar*, or *Posponer*.
6. The Settings tab and each of its sub-screens.
7. The theme and language switches.
8. Signing out.

The daily user did flows 5–7. TalkBack and low-vision checks covered flows 1, 2 and 6.

**Evidence:**
- **Current renders used:**
  - `App/artifacts/auth/login-{light,dark}.png` (10:32);
  - `App/build/calendar-feedback-*.png` (10:31) for the header and tab bar;
  - `App/build/review-direct-light.png` (10:23) for the save screen.
- **Stale renders not used:** the Settings and Account renders from 22 Sep predate most of today's rows.
- **Everything else is from code.**
  - Contrast was computed from the hex values in `app_theme.dart`.
  - Text widths were estimated from the bundled Manrope font metrics.
  - I ran no Flutter.
- **Not a finding:** the Google "G" is missing from `login-light.png` only because of render timing; the dark render has it.

**Numbers:**

| What | Today | Proposed |
|---|---|---|
| Install → first screen that can add something | 5 actions by email, 3 with Google | — |
| Settings tab | 14 tap targets in the body (21 with the header and tabs), about 150 words; *Notificaciones* is 10th | 6 rows, about 40 words |
| Reminders on a new account | 0 alerts by default; 7–8 steps and 2 system screens to get them on time | 1 tap plus the system dialog(s) |
| Theme toggle | on 23 surfaces | 1 |
| Notification settings | 8 controls, about 135 words | — |

### Findings (most severe first)

**UX-401 · Severity 4 · Tasks promise a reminder that never fires**
- **Where:**
  - `App/lib/services/reminder_preferences.dart:12` — the reminders master switch defaults to off, per account and device.
  - `App/lib/services/reminder_engine.dart:163` — nothing is planned while it's off.
  - `App/lib/screens/notification_settings_screen.dart:105` — the only call that ever requests the OS permission.
  - `App/lib/widgets/reminder_control.dart:28-34,49` — the chip on task details.
  - The reminder control is folded inside *Más opciones* / *Más detalles* (`capture_review_editor.dart:505`, `task_editor.dart:886`).
  - This affects every new account.
- **The moment:** Friday, 17:05. "It said 'Recordatorio: 10 minutos antes'. Why didn't my phone ring?"
- **What happens:**
  - A newcomer saves "Llamar al médico el viernes a las 5". Nothing will ever notify:
    - the in-app switch is off;
    - on Android 13+, the notification permission has never been asked;
    - on Android 14+, exact alarms are denied by default.
  - The save screen shows no reminder state. Its summary reads "Más opciones · Prioridad Baja · No se repite" (current render).
  - Task details then shows "Recordatorio: 10 minutos antes · desactivado en el dispositivo" — the claim first, the truth last.
  - If reminders are on but the permission is later revoked, the chip just says "Recordatorio: 10 minutos antes", with no warning.
  - Date-only tasks never notify at all, because there's no default time.
- **Why it fails:**
  - People keep defaults (Johnson & Goldstein 2003), and the newcomer never opens Settings › Notificaciones.
  - Jakob's law: phone calendars notify timed items by default.
  - Front-loading (Nielsen 2006): "desactivado" sits where nobody reads.
  - Visibility of system status (Nielsen heuristic #1).
  - The failure is only discovered after the appointment is missed, and trust goes with it.
- **Fix** (this completes U12's moment; nothing new to learn):
  1. At U12's moment — the first saved task with a date — ask once. "Sí" turns reminders on and requests the OS permission in the same tap.
     - ES: "¿Quieres un recordatorio antes?" — **Sí, recuérdamelo** / Ahora no
     - EN: "Want a reminder before it?" — **Yes, remind me** / Not now
     - CA: "Vols un recordatori abans?" — **Sí, recorda-m'ho** / Ara no
  2. Make the chip honest, with the state first. Compute it from both the in-app switch and the OS permission. Its action does the same one-tap enable. Delete `deviceOff`, and give the `remindersDisabled` link the same verb.
     - ES: "Sin recordatorio · Activar"
     - EN: "No reminder · Turn on"
     - CA: "Sense recordatori · Activa"
  3. Once reminders are on, date-only tasks remind at 9:00. This is an editable default, not a new setting.
- **Verify:**
  - Android 14 emulator, fresh install. Create a task for tomorrow at 10:00. The question appears once. After "Sí", Notificaciones › Próximos avisos lists the task as *programado*.
  - Revoke the permission: the chip reads "Sin recordatorio · Activar".
  - Unit test: after consent, `ReminderEngine.plan` returns the reminder for a fresh account.
- **Evidence:** verified in code. The missing reminder state at save is visible in a current render. Delivery timing needs a device check.

**UX-402 · Severity 3 · Signing in without an account is a dead end**
- **Where:** `App/lib/screens/login_screen.dart`:
  - line 28 — the screen opens in sign-in mode;
  - lines 230-239 — the headings are slogans ("Tu día, más claro." / "Un espacio para tus planes.");
  - lines 434-444 — *Crear una cuenta* is a text link below the button;
  - line 56 — switching modes clears the typed password.
  - Also `requestError.credentials` in the ARB files.
- **The moment:** "I typed my email and a password and it says they're wrong. I've never been here — what password?"
- **What happens:**
  - A fresh install opens with *Iniciar sesión* as the only dominant button, under a heading that doesn't name the mode.
  - The newcomer types an email and an everyday password, and gets "El correo o la contraseña son incorrectos. Inténtalo de nuevo."
  - Retrying repeats the same error.
  - The only way out is the text link, and taking it wipes the password they typed.
- **Why it fails:**
  - An error message must say how to fix the problem (Nielsen 2001); error recovery (heuristic #9).
  - At decision points, use plain labels, not slogans (UX_REVIEW §5.4).
  - The newcomer gives up after one or two dead ends.
- **Fix:**
  1. The credentials error carries its own fix: a message plus a button that keeps both fields and switches to create mode. The wording doesn't reveal whether the account exists.
     - ES: "No encontramos esa cuenta o la contraseña no es correcta." + **Crear una cuenta con este correo**
     - EN: "We couldn't find that account, or the password is wrong." + **Create an account with this email**
     - CA: "No trobem aquest compte o la contrasenya no és correcta." + **Crea un compte amb aquest correu**
  2. Headings name the mode:

     | | Sign in | Create | Recover |
     |---|---|---|---|
     | ES | Inicia sesión | Crea tu cuenta | Recupera tu contraseña |
     | EN | Sign in | Create your account | Reset your password |
     | CA | Inicia la sessió | Crea el teu compte | Recupera la contrasenya |

  3. Keep the password when switching between sign-in and create.
- **Verify:** a widget test where unknown credentials show the button, and tapping it lands in create mode with both fields filled. Then a newcomer walkthrough: the account is created on the first attempt.
- **Evidence:** verified in code; the layout is from the current 1× render.

**UX-403 · Severity 3 · Sign-up errors land below the fold at large text**
- **Where:**
  - `App/lib/screens/login_screen.dart:403-414` — the error banner sits under the submit button inside a ListView, and nothing scrolls it into view.
  - Lines 327-329 — the helper shows only "Al menos 12 caracteres". The other password rules appear only in `requestError.password`.
- **The moment:** "I pressed *Crear cuenta*, it spun, and nothing happened."
- **What happens:**
  - At 1.5–2× text, the slogan heading wraps to 3–4 lines and pushes the submit button to the bottom of the screen.
  - The server's answers appear below that button, off-screen: a password that's too common, all numbers, or too close to the email; an email already in use; no connection.
  - TalkBack announces them (the banner is a live region), but sighted users with large text see nothing change.
  - The password rules are only revealed after a failure.
- **Why it fails:** gulf of evaluation (Norman); change blindness — the change happens outside where the user is looking (Rensink et al. 1997); error prevention (Nielsen heuristic #5).
- **Fix:**
  - Show field errors on the field itself (`errorText` under *Contraseña* / *Correo*).
  - Scroll any other error into view.
  - State the rule before the user types:
    - ES: "Al menos 12 caracteres, no solo números"
    - EN: "At least 12 characters, not only numbers"
    - CA: "Com a mínim 12 caràcters, no només números"
  - UX-402's short headings also remove 2–3 wrapped lines.
- **Verify:** add a case to `App/test/auth_gate_test.dart` — Spanish, text at 2×, 360×740, with a mocked password error. The error must be visible without scrolling.
- **Evidence:** inferred from the layout code. Needs a 2× Spanish render; the current auth renders are English at 1×.

**UX-404 · Severity 3 · Settings has 14 entries; a newcomer needs three**
- **Where:** `App/lib/screens/settings_screen.dart:23-287`, the Settings tab while signed in.
- **The moment:** "I want it to remind me. Which one is it? What's 'Diagnóstico de captura'?"
- **What happens:**
  - **Order.** TaskFlow Pro comes first. *Notificaciones* — the entry most people need — is 10th of 14, below the fold even at 1× (inferred). It's named after the mechanism, not the goal.
  - **Grouping.** *Idioma*, *Hora y región* and *Calendarios del teléfono* sit under the "APARIENCIA" label. Entries are a mix of cards, bare rows and a centred text button. *Captura desde la pantalla de inicio* is the only row without a chevron, and it opens a system dialog instead of a page.
  - **Duplicates.** Appearance appears twice (the tiles and the header moon). Account appears twice (a row and the header icon). Language appears twice (here, and again inside *Hora y región*, whose screen is titled "Idioma y región").
  - **Developer terms and jargon.** *Diagnóstico de captura*, "CSV de Todoist", "zona horaria de captura", "widget".
  - **Content parked in Settings.** *Tareas completadas*.
- **Why it fails:** Hick–Hyman law — unfamiliar options are read one by one; progressive disclosure (Nielsen 2006); plain language with one name per concept (ISO 24495-1); common region (Palmer 1992).
- **Fix** (subtract):
  1. Show *Diagnóstico de captura* only in debug builds. For staging, it could sit behind a long-press on the version line.
  2. Cut Settings to six rows, ordered by need. The Reminders row shows its state as its subtitle.

     | | ES | EN | CA |
     |---|---|---|---|
     | 1 | **Recordatorios** — "Activados · 10 min antes" / "Desactivados" | **Reminders** — "On · 10 min before" / "Off" | **Recordatoris** — "Activats · 10 min abans" / "Desactivats" |
     | 2 | Idioma | Language | Idioma |
     | 3 | Apariencia | Appearance | Aparença |
     | 4 | Cuenta | Account | Compte |
     | 5 | TaskFlow Pro | TaskFlow Pro | TaskFlow Pro |
     | 6 | **Otros ajustes** | **Other settings** | **Altres opcions** |

     *Otros ajustes* holds: Hora y región, Calendarios del teléfono, the home-screen mic button, Exportar e importar, and Licencias. Rename the mic-button row to "Botón de dictar en la pantalla de inicio" / "Mic button on your home screen" / "Botó de dictar a la pantalla d'inici".
  3. Delete the "A TU GUSTO" eyebrow and the footer tagline.
  4. Remove Language from *Hora y región*, and title that screen "Hora y región".
  5. Move *Tareas completadas* to Tasks/Lists (UX_REVIEW §5.5) — move it, don't remove it.
- **Numbers:** 14 → 6 tap targets in the body; about 150 → 40 words; Reminders moves from 10th to 1st.
- **Verify:** a widget test that counts the tappable rows in SettingsScreen (6 or fewer). A walkthrough: turn on reminders from the Settings tab in 2 taps or fewer, without scrolling.
- **Evidence:** verified in code. The 22 Sep renders predate 8 of these rows.

**UX-405 · Severity 3 · On-time reminders take 7–8 steps and two system screens**
- **Where:** `App/lib/screens/notification_settings_screen.dart:166-262`, plus the strings `deviceReminderScope`, `approximateAlarmsHelp`, `scheduledAlertHelp`, `androidAlertRefreshHelp`, `deferredAlerts`, `retryScheduling`, `morningCheckIn` and `eveningCheckIn`.
- **The moment:** "Permiso del sistema… alarmas exactas… segundo plano… what do I press?"
- **What happens:**
  - From Calendar: Ajustes → scroll → Notificaciones → the switch → the system *Permitir* dialog.
  - Android 14 denies exact alarms to new installs (developer.android.com). So on 14+, the user must also go through *Permitir alarmas exactas* → the system list → the toggle → Back. Until then, "10 minutos antes" may arrive late.
  - The switch's subtitle explains account, device and sync scope.
  - The screen has 8 controls and about 135 words of diagnostics, such as "restricciones de batería… cierre forzado" and "una tarea cada hora en segundo plano".
  - *Actualizar y reintentar* is always showing, and nothing ever confirms success.
  - In Spanish, the morning check-in label "Mañana" reads as "Tomorrow", both in its row and in the alert list.
- **Why it fails:** conservation of complexity (Tesler) — the user ends up carrying the phone's alarm mechanics; progressive disclosure; plain language; the peak–end rule (Kahneman et al. 1993), since the flow has no ending.
- **Fix:**
  1. Keep one switch, *Activar recordatorios*, and drop its subtitle.
  2. When it's turned on, request notifications, then exact alarms only if needed, with one sentence:
     - ES: "Para que el aviso llegue a su hora, permite «Alarmas y recordatorios»."
     - EN: "To get reminders on time, allow “Alarms & reminders”."
     - CA: "Perquè l'avís arribi a l'hora, permet «Alarmes i recordatoris»."
  3. End with a confirmation:
     - ES: "Listo. Te avisaremos 10 minutos antes de cada tarea con hora."
     - EN: "Done. You'll get a reminder 10 minutes before each timed task."
     - CA: "Fet. T'avisarem 10 minuts abans de cada tasca amb hora."
  4. Show the status line and *Actualizar y reintentar* only when something is wrong.
  5. Fold the check-ins, upcoming alerts and explanations under "Detalles" / "Details" / "Detalls".
  6. Rename the check-ins to "Por la mañana" / "Por la tarde" (ES) and "Al matí" / "Al vespre" (CA).
- **Numbers:** 7–8 steps → 2 (the switch plus the dialog) if exact alarms come pre-granted (see Questions); about 135 → 30 words.
- **Verify:** Android 14 emulator, fresh install. Reminders turn on, and the next alert is listed as *programado* (not *aproximado*) within 4 taps, including the system screens. Also check a Spanish render at 2×.
- **Evidence:** verified in code. The Android 14 default comes from the official docs. Delivery timing needs a device check.

**Severity 2**

- **UX-406 · 2 · `App/lib/widgets/custom_app_bar.dart:11,54`, `App/lib/screens/login_screen.dart:208`.** The sun–moon toggle is on 22 screens plus sign-in:
  - in the top-right cluster, between the bell and Account — the hardest one-handed reach and the least accurate taps (Hoober). Reaching for Account turns the app dark ("I broke it");
  - right after *Eliminar* on task details;
  - on *Notificaciones*, where a moon reads as Do Not Disturb (the iPhone symbol);
  - on Settings, as a second appearance control.

  → Default `showAppearance` to `false` and keep a single instance (see Questions). 23 → 1.
- **UX-407 · 2 · `App/lib/screens/activity_screen.dart:27-33`.** The header bell means "Actividad" (group activity), while a bell means reminders in Settings (`settings_screen.dart:219-226`) and on tasks (`reminder_control.dart:37`). Someone looking for reminders lands on an empty Activity screen. → Give Activity a people icon (`Icons.groups_outlined`, tooltip "Actividad del grupo") and keep the bell for reminders. U10 already hides the bell for people with no groups.
- **UX-408 · 2 · `App/lib/screens/account_screen.dart:140-260`, `App/lib/providers/auth_provider.dart:112-117`.** On the Account screen:
  - the only filled button is *Sincronizar ahora*, which implies sync is manual;
  - there's a 40-word paragraph;
  - *Importar tareas y notas locales* is always shown, and leads to "No hay tareas ni notas locales que importar";
  - *Detalles de conexión* shows the server URL;
  - a failed sync shows the same error twice (lines 209-216 and 249-260), and the spinner sits at the bottom of the list;
  - *Cerrar sesión* sits in the thumb zone with no confirmation, and silently cancels every reminder on the phone.

  The fix:
  - Replace the card with one status line — "Guardado en tu cuenta" / "Saved to your account" / "Desat al teu compte" — plus a text button *Sincronizar ahora*.
  - Show Import only when there are local items.
  - Show connection details only in debug builds.
  - Show the error once, and put the progress in the button.
  - Confirm sign-out:
    - ES: "¿Cerrar sesión? Dejarás de recibir recordatorios en este teléfono hasta que vuelvas a entrar."
    - EN: "Sign out? Reminders on this phone stop until you sign in again."
    - CA: "Vols tancar la sessió? Deixaràs de rebre recordatoris en aquest telèfon fins que tornis a entrar."
- **UX-409 · 2 · `App/lib/services/reminder_engine.dart:189-196,314`.** Notification bodies are relative and go stale:
  - "Programada dentro de 10 minutos." is wrong 20 minutes later, and never gives the clock time;
  - the deadline text doesn't say when;
  - after a snooze, the body becomes "Tu tarea pospuesta."

  → Lead with the absolute time, and follow the stored 12/24-hour choice:

  | | ES | EN | CA |
  |---|---|---|---|
  | Timed | "Hoy a las 17:00 · en 10 min" | "Today at 5:00 PM · in 10 min" | "Avui a les 17:00 · d'aquí a 10 min" |
  | Deadline | "Fecha límite: hoy a las 17:00" | "Deadline: today at 5:00 PM" | "Termini: avui a les 17:00" |

  After a snooze, repeat the original line.
- **UX-410 · 2 · `App/lib/main.dart:245-255`.** Tapping a reminder whose task has since been completed, deleted or rescheduled pushes a second `MainShell`: an identical Calendar on which Back seems to do nothing. → Never push a second shell. If the task still exists, open it. If it was deleted, stay on the current screen and say "Esta tarea se ha eliminado." / "This task was deleted." / "Aquesta tasca s'ha eliminat."
- **UX-411 · 2 · `App/lib/services/notification_service.dart:82-89`, `App/lib/services/reminder_engine.dart:524-547`.** One mis-tap on *Completar* (it sits next to *Posponer 10 min*) completes the task silently. There's no undo, and the snooze the user meant never comes. → Replace the notification for a few seconds with "Completada: Llamar al médico" + **Deshacer**, the way Gmail does after archiving. EN: "Completed: Call the doctor" + Undo. CA: "Completada: Trucar al metge" + Desfés.
- **UX-412 · 2 · `App/lib/theme/app_theme.dart:85-90`.** Text-field outlines use `outlineVariant`: 1.28:1 on the white card (1.51:1 in dark), and the fill matches the card. The sign-in fields barely show, below the 3:1 that WCAG 1.4.11 asks for. → Use `outline` for the enabled border: 3.79:1 in light, 4.85:1 in dark.
- **UX-413 · 2 · `App/lib/theme/app_theme.dart:118-126`.** The selected tab is hard to tell apart (visible in the current calendar renders):
  - selected and unselected labels use the same style;
  - the selection pill is 1.20:1 against the bar (1.41:1 in dark);
  - the Tareas and Ajustes tabs keep the same icon when selected (`main_shell.dart:57-71`).

  → Style the labels by state (selected: w800, `onSurface`; unselected: w500, `onSurfaceVariant`), and use outlined/filled icon pairs (slice B).
- **UX-414 · 2 · the ARB strings `requestError.network` and `requestError.other`.** The error tells people to check "…la dirección del servidor", which release builds don't expose (`login_screen.dart:518`), and it says "datos locales". → Rewrite:
  - ES: "No hay conexión. Revisa el wifi o los datos móviles e inténtalo de nuevo."
  - EN: "No connection. Check Wi-Fi or mobile data and try again."
  - CA: "No hi ha connexió. Revisa la wifi o les dades mòbils i torna-ho a provar."

  Outside sign-in, add "Tus tareas siguen guardadas en este teléfono." / "Your tasks are still saved on this phone." / "Les tasques continuen desades en aquest telèfon."
- **UX-415 · 2 · `App/lib/screens/login_screen.dart:50-62,87-105,182-183`.** The sign-in modes don't behave like screens:
  - Back from *Crear cuenta* or *Recuperar* leaves the app instead of returning to sign-in, because there's no PopScope;
  - both recovery steps say *Continuar recuperación*;
  - after success, the filled code form stays on screen.

  → Add a PopScope that returns to sign-in. Label the steps "Enviar código" / "Guardar contraseña nueva" (EN: "Send code" / "Save new password"; CA: "Envia el codi" / "Desa la contrasenya nova"). On success, return to sign-in with the new password filled in.
- **UX-416 · 2 · `App/lib/screens/settings_screen.dart:184-198`** (also `data_transfer_screen.dart:51`, `subscription_screen.dart:28` and `main.dart:187`). Only `widgets/task_interactions.dart:19` honours Android's accessibility timeout through `FeedbackTimeout`. The home-screen widget instructions (26–29 words) vanish after 4 s. → Use `FeedbackTimeout` for every snackbar, and show the widget fallback as a sheet that stays until the user closes it.
- **UX-417 · 2 · `App/android/app/src/main/res/values*/strings.xml:2-4`.** Native labels:
  - the widget-picker description is developer text ("…retained capture flow" / "…conserva las capturas pendientes");
  - the long-press shortcut says "Captura texto";
  - Spanish "Dicta una tarea" doesn't match the in-app "Dictar una tarea".

  → Use "Toca para dictar una tarea." / "Tap to say a task." / "Toca per dictar una tasca." for the widget description. The Spanish shortcuts become "Dictar una tarea" and "Escribir una tarea" (EN "Type a task", CA "Escriu una tasca"). This falls under U11.
- **UX-418 · 2 · `App/lib/screens/settings_screen.dart:52-76`.** The three theme tiles are about 72 dp wide on a 320 dp phone. At 2×, "Sistema" is about 106–113 px, so it breaks mid-word on 320–360 dp phones and is borderline on bigger ones. "Sistema" is also jargon. → Use one *Apariencia* row that opens a sheet with full-width radio rows: "Claro / Oscuro / Como el teléfono" (EN "Light / Dark / Same as phone"; CA "Clar / Fosc / Com el telèfon"). Inferred from the font metrics.
- **UX-419 · 2 · `App/lib/main.dart:293-315`.** When the session is invalidated (`auth_provider.dart:39-43`), the whole navigator is rebuilt and anything being typed is lost. It's rare, but it loses input. → Show sign-in over the current screen, and only rebuild if a different account signs in. Inferred.

**Severity 1**

- **UX-420 · 1 · `App/ios/Runner/*.lproj/InfoPlist.strings:1-2`.** The iOS microphone prompt says "…crear un borrador de tarea", and the local-network text is meant for developers. → Replace the microphone text:
  - ES: "TaskFlow solo escucha mientras usas el micrófono, para que puedas dictar una tarea en lugar de escribirla."
  - EN: "TaskFlow listens only while you use the microphone, so you can say a task instead of typing it."
  - CA: "TaskFlow només escolta mentre fas servir el micròfon, perquè puguis dictar una tasca en lloc d'escriure-la."
- **UX-421 · 1 · `App/lib/theme/app_theme.dart:122-126`.** Tab labels are 11 sp, below Material 3's 12 sp, and Flutter caps their scaling at 1.3× (14.3 px). In Catalan, "Configuració" is about 90 px at 1.3×, wider than one 80 dp tab on a 320 dp phone. → Use 12 sp. The Catalan overflow disappears if U13 removes the Settings tab.
- **UX-422 · 1 · `App/lib/screens/regional_settings_screen.dart:47-108,144-188`, `App/lib/widgets/language_selector.dart:110-113`.** Time, region and language:
  - the row says "Hora y región", but the screen it opens is titled "Idioma y región";
  - the language picker appears a second time on that screen;
  - "Zona horaria de captura" comes with 25 words of help;
  - the time-zone list shows raw IDs such as "America/Argentina/Buenos_Aires";
  - the Spanish says "Usar el dispositivo";
  - the language sheet opens with a 30-word paragraph.

  → Retitle the screen, remove the second picker, move the time zone to *Otros ajustes* with city names, use "Como el teléfono" / "Same as phone" / "Com el telèfon", and delete the paragraph.
- **UX-423 · 1 · `App/lib/screens/data_transfer_screen.dart:152-168`, `App/lib/screens/subscription_screen.dart:176-213`.**
  - Export opens with a 45-word inventory, and the Spanish puts "proyectos de pasos" (checklists) next to "proyectos personales". → Replace it with one line: "Guarda una copia de tus tareas en un archivo o trae tareas de Todoist." / "Save a copy of your tasks to a file, or bring tasks from Todoist." / "Desa una còpia de les tasques en un fitxer o porta tasques de Todoist."
  - TaskFlow Pro shows four secondary buttons. → Keep *Ver suscripción* and *Restaurar compras*.
- **UX-424 · 1 · `App/lib/main.dart:46-53`, `App/lib/providers/auth_provider.dart:61-70`.** Startup waits for reminder setup before drawing the first frame. It waits again before showing the signed-in app: reconciling reminders can wait up to 10 s for a background job (`reminder_engine.dart:265-274`), behind a spinner with no text. → Run reminder setup after the first frame. Inferred; needs timing on a device.

### Keep
- Nothing is asked at cold start. Calendar permission is requested only from *Conectar calendarios del teléfono* (`device_calendar_provider.dart:164-172`).
- No raw server or English text reaches the screen (`l10n/request_locale.dart`). English, Spanish and Catalan each have all 898 keys, checked today.
- Tapping a reminder opens that exact task. The notification itself offers one-tap *Completar* and *Posponer 10 min*, in each alert's language.
- The language picker works before sign-in, shows each language's own name, and follows the phone by default.
- In dark mode every text pair is at least 5.7:1; in light mode the primary text is 5.9–6.3:1. Keep the palette and fix only the field borders (UX-412).

### Progress against UX_REVIEW.md (U1–U14)
- **U12 — still open.**
  - `App/lib/` has no first-run code.
  - `calendarEmpty` still explains both buttons.
  - `notification_settings_screen.dart:105` is the only permission request. UX-401 shows the consequence.
- **U14 — open, owner decision.** The login order is unchanged (`login_screen.dart:353-485`), and `App/test/auth_gate_test.dart:163-178` asserts that Google stays below the email form.
- **U13 — open, owner decision.** Settings is still tab 4 (`main_shell.dart:33,67-71`). UX-404 supports putting it behind the avatar.
- **U10 (header part) — still open.** `custom_app_bar.dart:53-60` shows the bell, moon and account icons on every root screen (current renders).
- **U11 (in my files) — still open.** "Captura" is still in the Settings rows, `strings.xml` and the time-zone help.
- **U9 (Settings side) — still open.** There's no Settings › Voz section.
- No regressions found. U1–U8 weren't assessed here.

### Questions for the owner
1. **U14: option 1 or 2?** Evidence:
   - The app opens in sign-in mode under a slogan heading.
   - Google comes last, below "o": about 70% down the screen at 1×, and likely below the fold at 2×. A test locks that order.
   - Email takes 5 actions and a 12-plus character password with partly hidden rules; Google takes 3.
   - Nothing on the screen says what the app does.
   - Option 2 has groundwork already: a `'local'` owner (`reminder_engine.dart:537`) and *Importar tareas y notas locales*.

   UX-402 and UX-403 apply either way.
2. **Voice behind Pro.** A free user's first tap on the dominant *Dictar una tarea* shows "La captura por voz está incluida en TaskFlow Pro." (`voice_task_screen.dart:45-90`). Once U8 makes the mic the only Add button, should typing inside the same sheet stay free? And should the first few voice captures be free?
3. **Reminders on after one consent?** Should a single "Sí, recuérdamelo" turn reminders on for every dated task — 10 minutes before for timed tasks, 9:00 for date-only ones?
4. **Exact alarms.** `USE_EXACT_ALARM` is granted at install, and Google Play allows it for calendar apps. Should TaskFlow apply for it as a calendar-first app, or keep asking for "Alarmas y recordatorios" (UX-405)?
5. **Where should the sun–moon switch live?** It's on 23 surfaces today. The options:
   - (a) Settings › Apariencia only — recommended, because it's already labelled and includes Sistema;
   - (b) the Calendar header only;
   - (c) inside the avatar menu (UX_REVIEW §5.2).

### Cross-slice notes
- **A:** `subscription_provider.dart:82-83` treats "billing not ready yet" as "not Pro". A paying or complimentary user who opens capture offline, or from the widget at cold start, can hit the Pro wall.
- **A:** The Spanish label in the app is "Dictar una tarea", but the shortcut and widget say "Dicta una tarea".
- **A/B:** The save screen never shows the reminder state — see the *Más opciones* summary in `build/review-direct-light.png`.
- **B:** The task details app bar reads [Editar][Eliminar][moon], with Delete in the middle (`task_detail_screen.dart:123-147`). A confirmation exists.
- **B:** *Tareas completadas* is reachable only from Settings (`settings_screen.dart:247-257`).
- **B:** The Tareas and Ajustes tabs keep the same icon when selected (`main_shell.dart:57-71`).
- **B/C:** In Spanish, `checklist` is "Proyecto de pasos" while `addChecklist` is "Añadir lista de pasos". "Proyecto" collides with group projects, and Catalan has the same problem.

### Memory notes
- **Issues (OPEN, 2026-10-13):**
  - UX-401 (4) Reminders off by default, while the chip claims "10 min antes" — `reminder_preferences.dart:12`, `reminder_control.dart:49`.
  - UX-402 (3) Sign-in with no account is a dead end; slogan headings.
  - UX-403 (3) Server errors fall below the fold at 2×; password rules hidden.
  - UX-404 (3) Settings 14 → 6 rows; diagnostics hidden in release builds.
  - UX-405 (3) On-time reminders take 7–8 steps; exact alarms; Spanish "Mañana".
  - UX-406 (2) Theme toggle on 23 surfaces.
  - UX-407 (2) The bell means Activity in the header and reminders elsewhere.
  - UX-408 (2) Account screen: manual sync is the primary button; sign-out is unconfirmed and cancels reminders.
  - UX-409 (2) Notification body is relative and goes stale.
  - UX-410 (2) Tapping a reminder pushes a duplicate MainShell.
  - UX-411 (2) *Completar* from the notification has no undo.
  - UX-412 (2) Field outline 1.28:1.
  - UX-413 (2) Selected tab can't be told apart.
  - UX-414 (2) Network error mentions the server address.
  - UX-415 (2) Login modes: Back exits the app; recovery button labels.
  - UX-416 (2) Snackbars ignore `FeedbackTimeout`.
  - UX-417 (2) Jargon in `strings.xml`.
  - UX-418 (2) Theme tiles split mid-word at 2×.
  - UX-419 (2) Session expiry wipes in-progress typing.
  - UX-420–424 (1) iOS mic text; tab labels at 11 sp; language and region; Export and Pro load; cold start.
- **U-status as of 2026-10-13:** U9 (Settings side), U10 (header), U11, U12, U13 and U14 are all still open. Google-below-email is enforced by `auth_gate_test.dart:163-178`.
- **Patterns:**
  - `CustomAppBar.showAppearance` defaults to `true`.
  - The reminders master switch is OFF per account and device, and the OS permission and exact alarms are requested only from Settings › Notificaciones.
  - `FeedbackTimeout` is used only in `task_interactions`.
  - All errors go through `requestProblemText`.
  - The ARB files are at parity with 898 keys.
  - Flutter caps NavigationBar label scaling at 1.3×.
- **Screen map:**
  - **Login:** opens in sign-in mode; *Crear una cuenta* is a link; Google comes last; recovery has 2 steps.
  - **Settings (14 entries):** Pro, 3 theme tiles, Idioma, Hora y región, Calendarios del teléfono, Captura desde la pantalla de inicio, Exportar e importar, Notificaciones, Cuenta y copia, Tareas completadas, Diagnóstico de captura, Licencias.
  - **Account:** Vincular Google, Sincronizar ahora, Importar locales, Detalles de conexión, Cerrar sesión.
  - **Notificaciones:** the switch, permission status, exact alarms, defaults, check-ins, upcoming alerts, retry.
  - **Hora y región:** the row opens a screen titled "Idioma y región".
  - **Reminder tap:** opens TaskDetailScreen, or pushes a second MainShell.
  - **Notification actions:** Completar / Posponer 10 min.
- **Recurring problems:** developer text on user-facing screens; the state placed at the end of labels; duplicated controls (theme, language, account); slogans where the user has to decide.
- **Owner decisions:** none new.
