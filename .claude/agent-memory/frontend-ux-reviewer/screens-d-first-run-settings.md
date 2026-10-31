---
name: screens-d-first-run-settings
description: Screen and flow map for UX-loop area D (first run, sign-in, Settings, Account, Notificaciones and reminders, native surfaces, header and theme) as of 2026-10-13, with baseline counts
metadata:
  type: project
---

Current as of 2026-10-13 (whole-app run, slice D). Paths are under `App/`.

**Why:** reviews start faster from a current map, and the baselines supply the "before" numbers.
**How to apply:** start area-D reviews here, and refresh this file whenever these screens change.

## First run and sign-in
- **Cold start** asks for nothing, but startup waits for reminder setup before the first frame.
- **Sign-in is required** — the login wall, which U14 still has open. Shared and widget entries wait until there's an account.
- **Login** (`lib/screens/login_screen.dart`):
  - opens in sign-in mode, under slogan headings ("Tu día, más claro." / "Un espacio para tus planes.");
  - email and password, a filled "Iniciar sesión", and the error banner below that button (a live region);
  - "Crear una cuenta" is a text link, and switching modes clears the password;
  - recovery takes 2 steps, both labelled "Continuar recuperación";
  - Google comes last, below "o" — `test/auth_gate_test.dart` enforces that order;
  - it has a language picker, which works before sign-in, and the sun–moon toggle;
  - Privacidad · Términos links sit under the card (b5; see [[ui-patterns]] › Links to the website);
  - Back from create or recovery exits the app.
- **Install → Calendar:** 5 actions by email, 3 with Google.
- **First run:** Calendar's empty day carries a one-time try-it line until the account's first task (b10, U12). The notification permission is only ever asked from Settings.

## Settings tab (`lib/screens/settings_screen.dart`, tab 4)
- **14 entries in the body, in order:**
  1. TaskFlow Pro;
  2–4. the theme tiles Claro / Oscuro / Sistema;
  5. Idioma;
  6. "Hora y región" — the screen it opens is titled "Idioma y región", repeats the language picker, and has a capture time zone listed by raw IDs;
  7. Calendarios del teléfono;
  8. Captura desde la pantalla de inicio — it opens a system dialog and has no chevron;
  9. Exportar e importar (`/dataTransfer`);
  10. Notificaciones;
  11. Cuenta y copia (`/account`);
  12. Tareas completadas;
  13. Diagnóstico de captura;
  14. Licencias.
- Also on the tab: the eyebrow "A TU GUSTO" and a footer tagline. About 150 words in all.
- **Account:**
  - "Vincular Google";
  - a card with a filled "Sincronizar ahora" and a 40-word paragraph;
  - "Importar tareas y notas locales", always shown;
  - "Detalles de conexión", which shows the server URL;
  - "Cerrar sesión" — no confirmation, and it cancels this phone's reminders.
- **Notificaciones** (`lib/screens/notification_settings_screen.dart`):
  - the master switch, off by default — the only place that asks for the OS permission;
  - permission status, exact alarms (Android 14+), the default timing;
  - check-ins labelled "Mañana" / "Tarde", the list of upcoming alerts, and "Actualizar y reintentar" (always shown);
  - about 8 controls and 135 words.
- **Subscription** (`/subscription`): four secondary buttons.
- **Otros ajustes** (`lib/screens/other_settings_screen.dart`): ends with Licencias, Privacidad, Términos (open_in_new trailing), then the version line (b5).
- **Delete account** (`lib/screens/delete_account_screen.dart`), as of b5 (2026-10-19):
  - consequences → copy link → confirmation → the red «Eliminar mi cuenta», enabled only once confirmed (`_ready`);
  - Google-only account: «Confirmar con Google» with its help line in every state;
  - password account with Google linked: password field, then «O confirma con Google…» + Confirmar con Google; once Google confirms, the password section and the «O…» line go, leaving «Confirmado con Google» alone. A refused Google confirmation brings both back;
  - a wrong password names the Google button below when Google is linked;
  - no way back from a Google confirmation to the password without leaving the page (accepted, rare).

## Reminders and notifications
- **Turning reminders on from Calendar:** Ajustes → scroll → Notificaciones → the switch → the system dialog, plus exact alarms on Android 14+. That's 7–8 steps.
- **Notification body:** absolute time ("Hoy a las 17:00 · en 10 min"); snoozed alerts drop the tail (b10, UX-409/632).
- **Notification actions:** Completar, then a silent Deshacer notification that follows the accessibility timeout (UX-411/631); Posponer 10 min. Phone checks for these are in `.claude/ux-review/PHONE_CHECKS.md`.
- **Tapping a notification** opens the task detail, or a second MainShell if the task is gone.
- **Reminder plans (2026-10-22):** after saving a task ≥ 14 days away with no reminder of its own, the offer sheet asks «¿Te aviso cada 3 días…?» (Normal). «Sí» → undo bar; after 2 «Ahora no» it's never asked again. Plan notices have only «Completar», except the own-day notice of a timed task (also «Posponer 10 min»). Shared tasks: every reminder is personal; the sheet's fixed header says «Estos avisos son solo para ti.»; a task given to someone else reads only «Recordatorio para {persona}» (no tap); a task not this account's naming nobody shows no reminder at all. Ajustes › Recordatorios' plan line counts only tasks that ring here (`reminderRingsHere`). Ajustes › Recordatorios' all-day line names plans with no time («Desactivado · «Hasta la fecha límite»: 09:00»). Pro screen (`subscription_screen.dart`) with a reason shows a header + example, «Ver suscripción» pinned; RevenueCat's paywall text is external. Renders: `App/build/ux/reminders/` (sheet.*, task-line.*, capture-card.*, offer.*, sheet.pro-screen.*). Details in [[ui-patterns]] › Reminder plans.
- The task-detail reminder chip and the off-by-default switch are described in [[ui-patterns]].

## Native surfaces
- **Android** (`android/app/src/main/res/values*/strings.xml`; the launcher shortcuts come from code, `CaptureShortcuts.kt`, since 3a6ad40 removed `res/xml/capture_shortcuts.xml`):
  - launcher icon (b7, UX-1608): adaptive `mipmap-anydpi-v26/ic_launcher.xml`, teal #146C5C background + white double-tick (`done_all_rounded`) foreground and monochrome (themed icons); legacy PNGs are the same mark. Notification small icon `drawable/app_notifications_icon.xml`, the same tick; the old `app_icon` is gone;
  - the widget's label has its own string `capture_widget_label` (layout text, TalkBack name, 13+ label, picker name): EN "Dictate a task", ES «Dictar una tarea», CA «Dicta una tasca»; description "Tap to dictate a task." / «Toca para dictar una tarea.»;
  - launcher shortcuts `capture_voice`/`capture_text` with short labels (Android shows the short one at 2.0 when the long one is ~15+ chars): EN "Dictate a new task"/"Type a new task" → "Dictate"/"Type"; ES «Dictar una tarea»/«Escribir una tarea» → «Dictar»/«Escribir»; CA «Dicta una tasca»/«Escriu una tasca» → «Dicta»/«Escriu»;
  - Settings › Otros ajustes help (`homeCaptureInstructions`) names the widget by its label in EN; the row title (EN "Mic button on your home screen") and ES help («widget de micrófono») still describe it by icon;
  - the share entry, whose error toasts are hard-coded in English.
- **iOS:**
  - the microphone text says "…crear un borrador de tarea"; EN `Info.plist` / `en.lproj` still say "say a task" (app is Android-only, so low priority);
  - the local-network text is written for developers.

## Header and theme
- **Header on every root tab:** a bell (Activity), the moon (theme) and the avatar (Account).
- **The theme toggle** appears on about 23 surfaces: every `CustomAppBar`, plus login.
- **Contrast:**
  - text is fine — at least 5.7:1 in dark, 5.9–6.3:1 for primary text in light;
  - field borders now `outline` (3.79:1 light / 4.85:1 dark); the selected tab is shown by w800 label + filled icon, so the faint pill no longer carries state.
- **Tab bar** details (icons, 12 sp labels, < 360 dp label shrink, tooltips, hidden hairline) are in [[ui-patterns]] › Header, tabs and theme.

## Baselines (2026-10-13)
- **Settings:** 14 tap targets in the body (21 with the header and tabs), about 150 words. Notificaciones is 10th.
- **Reminders on a new account:** 0 alerts by default, and 7–8 steps to get them on time.
- **Theme toggle:** on 23 surfaces.
- **Tab labels at the 1.3× cap, 320 dp (80 dp tab):** ES "Calendario" selected 77.9 dp after P45 (fits, 2.1 dp spare); CA "Configuració" 92.9 dp (wraps until U13).
- **Notificaciones:** 8 controls, about 135 words.

Related: [[ui-patterns]], [[screens-a-voice-capture]].
