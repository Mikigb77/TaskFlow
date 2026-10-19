---
name: ui-patterns
description: How TaskFlow's UI actually behaves as of 2026-10-13 (snackbars/undo, date sheets, task forms, error text, naming, project scope, capture, reminders, search, tabs/icons/theme), with the stale "one shared sheet" and "one shared editor" claims corrected
metadata:
  type: project
---

What the app does today, so a consistency finding can name the standard and the departures from it. Gathered by the 2026-10-13 whole-app run (slices A–D); the load-bearing lines were re-checked in code the same day. The UX loop is changing these, so grep before enforcing. Paths are under `App/lib/` unless shown otherwise.

**Why:** consistency findings need to know which version is the standard and where the app departs from it.
**How to apply:** compare every screen in scope with these. A departure is a finding unless `.claude/ux-review/ISSUES.md` already has it.

## Snackbars and undo
- **The standard** is task completion in `widgets/task_interactions.dart`: `persist: false` plus `duration: FeedbackTimeout.forAction()`, which follows Android's accessibility timeout. On 2026-10-13 it was the only snackbar in `lib/` that did this.
- Flutter 3.44: a snackbar with an action never times out unless `persist: false` is set. Undo bars without it:
  - voice save and "Borrador retirado" (`screens/review_tasks_screen.dart`);
  - move (`task_interactions.dart`);
  - "Sugerencia de fecha aplicada" (`widgets/task_editor.dart`).
- Snackbars use the root messenger: they follow the user onto new screens and queue behind each other.
- They float above the capture bar (asserted in `App/test/calendar_feedback_test.dart`). The exceptions use `SnackBarBehavior.fixed`: `screens/task_lists_screen.dart` and `screens/data_transfer_screen.dart`.
- **Undo exists for:** complete, voice save, removing a draft in review, move, and applying a date suggestion.
- **No undo for:** typed save, delete, archive, moving a task into a shared project, leaving.
- **Undo outside the app (b10, 2026-10-14):** Completar on a notification posts a silent `Completada: {title}` + Deshacer that reopens the task (or that day of a repeat). Its `timeoutAfter` is `TaskReminders.undoTimeout()`: the stored accessibility timeout (`undo_timeout_ms`, saved on foreground/resume) when longer than 10 s, else 10 s. Any new out-of-app undo should follow this, not a fixed 10 s.
- `FeedbackTimeout.forAction({original})` takes a base duration and returns it on every fallback.
- **Destructive actions** use confirmation dialogs where the destructive button is the filled or default-teal one. Nothing uses `colorScheme.error`.

## Date, time and repeat
- **Corrected.** The old memory line "date and time are edited in one shared sheet" is only partly true.
  - `editSchedule()` in `widgets/schedule_editor.dart` (the 12 Oct sheet, with "Sin fecha" and typed hours) serves TaskEditor, voice review and the planning control.
  - "Cambiar fecha" (from a tile, swipe left, long-press or the task detail) still opens its own `_ScheduleSheet` in `task_interactions.dart`: a date dialog, the clock dial, a "Bandeja de entrada" chip and "Guardar programación".
- **Repeat:** a dropdown in TaskEditor's "Más detalles"; a sheet (`widgets/repeat_rule_control.dart`) in voice review.
- **Date labels** (`widgets/task_schedule_label.dart`) have no weekday ("16 oct · 17:00"). Undated tasks read "Bandeja de entrada · Sin fecha".

## Task forms
- **Corrected.** `App/docs/DESIGN.md` says "One shared editor handles new tasks, AI draft review, and edits." That's out of date; there are two forms:
  - **typed create and edit** — TaskEditor (`widgets/task_editor.dart`), the old layout: headline, help line, project row and a Task/Note choice above the title, with extras under "Más detalles";
  - **voice review** — `widgets/capture_review_editor.dart`: a date row, extras under "Más opciones", and Save pinned at the bottom.
- In TaskEditor, a date typed into the title only becomes a "Usar …" chip, and it's applied only if the user taps it.

## Calendar state
- The selected day is private state (`_selectedDay` in `screens/calendar_screen.dart`), set when the screen is created.
  - Since the landing work, `providers/calendar_focus_provider.dart` (CalendarFocus, incl. `undated`) lets a save move the view and light the landed rows (2026-10-14).
  - It doesn't follow midnight.
- Capture buttons get the selected day only when the person picked it (`_picked`, 2026-10-14); a landing does not count as picking.
- The agenda shows only tasks dated on the selected day. The app has no concept of "overdue".

## Error text and copy
- **Request errors** go through `requestProblemText` (`l10n/request_locale.dart`) and are translated. The network message still mentions "la dirección del servidor".
- **Capture errors** go through `captureProblemText` (`l10n/capture_messages.dart`), which ends with `_ => value`. So any unmapped server text (400/404/422) is shown raw, in English. Every new capture error needs a mapped string.
- `MessageBanner` (`widgets/app_components.dart`) isn't a live region; the login error banner is.
- **Translations:** en, es and ca each had 898 keys on 2026-10-13. Hard-coded English remains in:
  - the share toasts in `App/android/app/src/main/kotlin/com/example/agenda/CaptureEntryBridge.kt`;
  - the "Remove {file}" tooltip in `task_editor.dart`.
- **Borrowed copy:** notes reuse task strings. Generic dialogs carry the wrong text:
  - `groupTextDialog` is used for the name, the email and the code;
  - `groupActionError` is also used for load failures.
- **Names in use:**
  - lists are "projects" (the 2026-10-11 direction);
  - no project = "Personal inbox" / "Bandeja personal";
  - no date = "Inbox" / "Bandeja de entrada";
  - a checklist is "Proyecto de pasos" in Spanish (a rename artefact);
  - other people are called Team / Everyone (ES "Todo el grupo") / Members / People.

## Project scope and sharing
- One global `projectScopeProvider` (the "Todos los proyectos" chip) filters Calendar, Tasks, `/inbox` and project pages. It also decides where new typed and spoken tasks are saved.
- The "For me / Team" chips appear only when a shared project exists. The "All projects" chip is always there.
- `lockShared`: once a task is in a shared project, it can't leave, and its project chip is disabled.
- Archiving a project or group, or muting a project, hides its tasks from Calendar and Tasks and stops their reminders. Notes from archived projects stay in Notes.

## Person chips on a project page (b5, 2026-10-19)
- On a shared project page, a person's chip (`_personChip`, `screens/home_screen.dart`) is also the default assignee: every way in (Añadir tarea form, capture sheet, «Escribir» from the sheet) carries that person, but only while the task goes into the page's project.
- Capture: drafts that named nobody become that person's (`_forPerson` in `voice_task_screen.dart`, via `_store.update` so Deshacer restores it); a person named in the dictation wins. Notes and new-project drafts are untouched.
- «Todas», «Para mí», Calendar and the Tareas root pass no person. Changing project resets the person (`taskWithProject`).
- Watch: the form shows «Ana ▾» above «Visible para todos en {proyecto}», which a newcomer may read as "for everyone"; TalkBack reads the chip as just «Ana».

## Links to the website (b5, 2026-10-19)
- Every link to the site goes through `services/site_links.dart`: one base URL, localized paths (`/es/`, `/ca/`, English otherwise), and `openWebPage`, which shows `webPageOpenError` when nothing opens. A new hard-coded site URL is a departure.
- Privacy and Terms appear in two places: quiet TextButtons under the sign-in card (hidden in recovery and sign-in-again), and two rows in Otros ajustes after Licencias. Names match the site's page titles in EN/ES/CA.
- Billing copy says "the Android app" only — no value in the ARBs names iOS, iPhone or Apple.

## Capture
- **Pro gate.** Every way into capture (button, widget, shortcuts, share) goes through `hasProProvider`.
  - Without Pro, a full-page Pro wall replaces voice, typing and shared text alike.
  - Billing that hasn't loaded yet counts as not Pro.
- **Capture records** are written when listening starts, before any words. Widget and shortcut taps write one up front. Leftover records show as "Capturas pendientes · N".
- `_busy` in `screens/voice_task_screen.dart` means both "loading" and "processing", so both show "Preparando tu plan…".
- **Listening stops** on any lifecycle state other than `resumed`, including `inactive` (pulling down the shade, system dialogs).
- **The pattern to keep:** the microphone permission is asked at the first capture, and typing stays available if it's refused.
- **Standards since the 2026-10-14 speed run:**
  - A save shows the phone's copy at once and syncs behind (`taskProvider.showLocal()`); nothing awaited sits between a tap and its visible result (no network, no diagnostics write). A new save/undo path that awaits `loadTasks()` is a departure.
  - Leaving any capture state with content (listening, typing, result) asks the same `_askToKeep` question: Descartar / Conservar. Save is the only exit that doesn't ask.
  - Calendar passes a day to capture only when the person picked it (`_picked`), never because a landing moved the view.
  - On the result card, day chips (Hoy, Mañana, Sin fecha) apply and close in one tap, as when moving a task; empty optional fields (notes) stay inside Más opciones until asked for.
  - Editable text on the result has a visible underline; don't ship borderless editable titles.
  - Capture copy never says "borrador/draft"; leftovers are "sin añadir" / «Quitada».

## Reminders and notifications
- The reminders master switch defaults to off, per account and per device (`ReminderPreferences.enabled = false`).
- The OS notification permission and exact alarms are requested only from Ajustes › Notificaciones.
- The reminder chip (`widgets/reminder_control.dart`) leads with the timing and ends with the real state ("… · desactivado en el dispositivo"). It checks only the in-app switch, not the OS permission.
- **Notification actions:** Completar (with undo, above) and Posponer 10 min. Tapping opens the task, or pushes a second MainShell if the task is gone.
- **Notification body (b10):** absolute time, built in `services/reminder_copy.dart` in the alert's language and the stored 12/24-hour clock: `Hoy a las 17:00 · en 10 min`, `Mañana a las…`, `Vie, 25 sept a las 17:00` (capitalised when it starts with the date), `Fecha límite: vie, 25 sept…` (stays lowercase after the label). ES/CA `a la`/`a las` via `hour` plural. A snoozed alert passes lead 0 — no `· en N min` tail. Never reintroduce relative-only text ("dentro de 10 minutos") in an alert body.

## First-run teaching
- Calendar's empty day (`calendar_screen.dart`, b10): the try-it line `Prueba: toca Añadir tarea y di «…»` (or `escribe «…»` without voice) shows only while the account has never had a task or note; after that it's `calendarEmpty` "Nada previsto para este día.". The flag is per account and persisted (`providers/first_task_provider.dart`, `hadTaskProvider`); a loading flag shows the list's spinner. One-time teaching must hang off a persisted flag like this, never off the live list.

## Search
- **The standard (P11/P46, 2026-10-13):** every search over tasks, notes and projects calls `matchesSearch` in `services/text_search.dart`. Callers: Tareas/project pages (`home_screen.dart`), Notas, Proyectos (`task_lists_screen.dart`), the "Todos los proyectos" sheet (`project_scope_control.dart`). Fields pass the trimmed query.
  - Ignores case and accents on both sides; folds one character at a time (`·` → nothing, `ŀ` → l, `l.l` → ll, trailing `l.` searches as `l`), so every prefix of a word matches.
  - An empty query returns true before folding anything.
- **Departures:** the time-zone list (`regional_settings_screen.dart`) still uses plain lowercase. `'` and `’` are not folded together (iOS smart quotes; the date parser does treat them as one).
- **No-match states:** Tareas, Notas and the sheet show a message; Proyectos shows blank space.
- Search never crosses between tasks and notes.
- Tareas and Notas stay built behind the other tabs (IndexedStack in `main_shell.dart`) and watch the task list, so any per-item work in their filters runs on every save made anywhere.

## Header, tabs and theme
- `CustomAppBar.showAppearance` defaults to true, so the sun–moon toggle appears on about 23 surfaces.
- Every root tab shows a bell (it opens Activity), the moon, and the avatar (it opens Account).
- **Tabs (after P28/P45/P47):** Calendario, Tareas, Notas, Ajustes, each outlined when unselected and filled when selected: `calendar_month`, `check_box`, `description`, `settings`.
  - Labels (`theme/app_theme.dart`): 12 sp, `letterSpacing: 0`; selected w800 `onSurface`, unselected w500 `onSurfaceVariant`. State is carried by weight + filled icon, not the pill (dark pill 1.41:1).
  - Bar is a fixed 72 dp; Flutter caps labels at 1.3× and long single words wrap mid-word.
  - Below 360 dp, `main_shell.dart` passes `NavigationBar.labelTextStyle` with a reduced fontSize so labels draw at ≤ 1.2× (14.4 px). Stopgap until U13. `_labelFontSize = 12` there mirrors the theme's 12 sp — they must move together.
  - Long-press tooltips follow the phone's text size (14 sp, 28 px at 2×).
  - Catalan "Configuració" still wraps at 320 dp; only U13's two tabs fix it.
  - The `outlineVariant` hairline above the bar is painted behind the opaque bar, so it never shows; the edge is only a tint change.
- **Rule to enforce:** never shrink text by wrapping a NavigationBar (or anything with tooltips/menus) in a MediaQuery — OverlayPortal content inherits it. Shrink the style instead.
- **One icon per concept:** Tareas = `check_box(_outlined)` (tab and the Tareas/Bandeja/project empty state); Notas = `description(_outlined)` (tab, Notas empty state, note rows, a project page's Notas button). Tasks complete with a round Checkbox, steps with square ones. `notes_rounded` remains at `voice_task_screen.dart` ("Revisar nota", should become `description_outlined`) and `captures_screen.dart` (means "typed, no audio" — fine).
- **Contrast:** enabled text-field borders now use `outline` (3.79:1 light, 4.85:1 dark on the field fill). Disabled/error/focus borders are M3 defaults. Text contrast is fine in both themes.
- Pushed screens repeat the app-bar title as a headline, with an uppercase eyebrow label above it.

Related: [[recurring-problems]], [[screens-b-calendar-tasks]], [[decisions-in-docs]].
