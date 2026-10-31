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
  - voice save and "Borrador retirado" (`screens/review_tasks_screen.dart`, gone since U4);
  - move (`task_interactions.dart`);
  - "Sugerencia de fecha aplicada" (`widgets/task_editor.dart`).
- Snackbars use the root messenger: they follow the user onto new screens and queue behind each other.
- They float above the capture bar (asserted in `App/test/calendar_feedback_test.dart`). The exceptions use `SnackBarBehavior.fixed`: `screens/task_lists_screen.dart` and `screens/data_transfer_screen.dart`.
- **Undo exists for:** complete, voice save, removing a draft in review, move, and applying a date suggestion.
- **No undo for:** typed save, delete, archive, moving a task into a shared project, leaving.
- **Undo outside the app (b10, 2026-10-14):** Completar on a notification posts a silent `Completada: {title}` + Deshacer that reopens the task (or that day of a repeat). Its `timeoutAfter` is `TaskReminders.undoTimeout()`: the stored accessibility timeout (`undo_timeout_ms`, saved on foreground/resume) when longer than 10 s, else 10 s. Any new out-of-app undo should follow this, not a fixed 10 s.
- `FeedbackTimeout.forAction({original})` takes a base duration and returns it on every fallback.
- **Undo restores locally first (2026-10-21):** `restoreTasks`, `undoSchedule`, `undoOccurrence` in `providers/task_provider.dart` end with `showLocal()`, so Deshacer shows at once and syncs behind. Any new undo must do the same — never wait for the server.
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
  - Voice privacy line (`capturePrivacy`, Ajustes › Voz, 2026-10-22) covers commands too: «Para añadir, buscar o cambiar tareas, tus palabras van por internet a la IA de Google.» Any new voice feature that sends words out must still fit that sentence.

## Voice command and set cards (2026-10-21)
- One verb per action across card heading, button and landing message (Mover / Asignar / Marcar como hechas / Eliminar). Count words follow the real count (ICU plurals); a set with no count yet uses the plural.
- Destructive set: its heading and ✕ must be in view before the button can be pressed. An ambiguity is a question with chips, never a "not found" error. See [[screens-a-voice-capture]].
- **Drop-down mark ▾ (`DropDownMark`, `widgets/app_components.dart`, 2026-10-22):** the one ▾ for chips that open a picker — the move-day chip, the project chip (`task_list_picker.dart`) and the person chip (`task_assignment_picker.dart`). The glyph scales with text (18 dp at 1×, capped at 28 dp) but always reserves 18 dp of row width (`widthFactor: 18 / size`), so a larger ▾ never takes room from the label. Locked/unchangeable chips show no ▾. New picker chips must use it, not a raw `Icon(arrow_drop_down)`.
- **Day chip on command cards (`_MoveDayChip`):** a 48 dp ActionChip, tooltip «Elegir día», on «move to a day» set headings and the one-task change card; the label may carry the time («jue, 29 de oct · 10:00») but the sheet changes the day only; label `maxLines: 3`; no «Sin fecha» in its sheet; absent on shift-by-days, complete, delete, assign.

## Reminders and notifications
- The reminders master switch defaults to off, per account and per device (`ReminderPreferences.enabled = false`).
- The OS notification permission and exact alarms are requested only from Ajustes › Notificaciones.
- The reminder chip (`widgets/reminder_control.dart`) leads with the timing and ends with the real state ("… · desactivado en el dispositivo"). It checks only the in-app switch, not the OS permission.
- **Notification actions:** Completar (with undo, above) and Posponer 10 min; plan notices get Completar only, except a plan's own-day notice on a timed task (`…/plan/<date>/time`), which gets both. Tapping opens the task, or pushes a second MainShell if the task is gone.
- **Notification body (b10):** absolute time, built in `services/reminder_copy.dart` in the alert's language and the stored 12/24-hour clock: `Hoy a las 17:00 · en 10 min`, `Mañana a las…`, `Vie, 25 sept a las 17:00` (capitalised when it starts with the date), `Fecha límite: vie, 25 sept…` (stays lowercase after the label). ES/CA `a la`/`a las` via `hour` plural. A snoozed alert passes lead 0 — no `· en N min` tail. Never reintroduce relative-only text ("dentro de 10 minutos") in an alert body.

## Reminder plans (aa2f53a + run 2026-10-22-changes plans 1–3, closed 2026-10-23; widget-test level, phone checks still owed)
- **Concepts:** a plan replaces a task's single reminder. Strengths (Suave/Normal/Intenso) in the row «Hasta la fecha límite» (CA «Fins al termini»; name under owner decision D4); «A tu manera» = rhythm in the user's own words, Pro. Normal's rhythm «cada 3 días, y a diario la última semana» is FREE — never use it as a Pro example. The Pro example everywhere is the helper's «una semana antes y el día antes a las 8» (U+00A0 binds the hour to its preposition).
- **One line, one builder:** `reminderLine()` in `widgets/reminder_control.dart` drives ReminderChip, the capture card's collapsed-row line and «Más opciones»' subtitle. Line starts with the word and names the strength: «Recordatorios normales hasta el vie 13 · próximo: sáb 24, 09:00» / «Recordatorios: cada 3 días… · próximo: …»; lowercase rhythm after a colon or a person's name (`bare`); next time uses `context.clockTime`. «próximo» counts only notices before/at the day (`alerts(late: false)`); none left → «Sin recordatorio: ya ha pasado la hora del aviso» + off bell; done task → no «próximo». Sheet count «13 avisos · próximo: …» / «1 aviso: …».
- **Reminder sheet** (`widgets/reminder_plan_sheet.dart`): plan rows only when the task already has a plan or is ≥ 2 days away; expandable rows carry `Semantics(expanded)`; opens scrolled to the chosen plan row; «A tu manera» listening keeps «Dejar de escuchar»/Listo in view (`_reveal`), kept unsent words reopen without a new request (Pro, saved tasks). Free account with a custom plan sees it selected with preview + Listo, no field/badge.
- **Capture card reminder:** `_reminderOpen` is a `late final` set once from the arriving task (said plan/lead/time) → row above «Más opciones»; otherwise the control lives inside «Más opciones» and never moves on change. A reminder changed inside shows last in «Más opciones»' subtitle and on the collapsed row (`reminderInOptions`). Reminders can't ring → «Activar recordatorios» under the kept plan line.
- **Offer sheet** (`widgets/reminder_ask_sheet.dart` `_PlanOfferSheet`): asked after saving a far task only if it has no reminder of its own and rings on this phone (`reminderBlock` null; unknown project not asked); names the task («{title} · {day}»), «Sí, recuérdamelo»/«Ahora no»; «Sí» ends on «Listo. Te lo recordaré hasta el …» + Deshacer (FeedbackTimeout).
- **Plan notices:** body from `ReminderCopy.planBody` (absolute date/time, shared clock); only «Completar» (no snooze; iOS `plan_<lang>` category); elapsed ones collapse to the newest; scheduling window = next four + day before/day/day after.
- **Own-day notice on a timed task (D1, plan 2):** rings at the task's lead, else Settings' «Tareas con hora», while that stays on the anchor's day (`reminder_plans.dart` `dayLead`); words = the single reminder's (`ReminderCopy.planDayBody`, «Hoy a las 17:00 · en 10 min»), Completar + Posponer 10 min, snoozes back as «Hoy a las 17:00». Every plan line/summary/count must pass `dayLead` (chip «… · próximo: hoy, 16:50»). **D8 built (plan 3):** `dayLead(..., {plan})` returns null when the plan has its own said time, so that time wins (render `task-line.own-time-today`); the sheet computes a lead per plan shown (Normal, dictated, «A tu manera»), not the task's current plan.
- **Plans are per account (D6, plan 2):** `reminderRingsHere` in `reminder_control.dart` (same rule as the engine's `reminderBlock`) gates plan rows, chip, form line and capture card; a task given to someone else shows no plan anywhere (sheet: «Desactivado» + «Elegir hora del aviso» only). «Una vez» is still one shared setting in the app until its package lands.
- **Every reminder is personal (plan 3):** the help panel «Cómo funciona…» says «Los recordatorios no se comparten: cada persona tiene los suyos.» (`sharedDataHelp`).
  - **Shared task:** «Estos avisos son solo para ti.» (`reminderPlanJustYou`) appears once, in a fixed header under the sheet title (`_JustYou`, key `reminder-plan-just-you`), then a 1 dp edge `Divider` (key `reminder-sheet-header-edge`), then the scrolling choices; no copies above Listo. Personal tasks keep the title inside the scroll, no edge. Same note under the single-reminder picker (`_pickFrom` note) and as helperText of «Recordar antes de» — never in Settings.
  - **Task given to someone else:** one line «Recordatorio para {persona}» (`reminderForPersonOnly`, no timing value) everywhere `reminderLine` reaches; no tap, no chevron, no «Activar recordatorios», no loading/error; «Recordar antes de» hidden (`showReminderAnchor: !reminderSomeoneElses`); no needs-day line.
  - **Not this account's, nobody named** (`_Reason.hidden`): nothing at all — no chip, row, subtitle, needs-day line, and the detail drops the chip's gap.
  - **A line with no tap is information, not a control:** transparent `Chip`, `BorderSide.none`, `onSurface` text, bell kept; Semantics not a button and **no enabled state** (`enabled: onTap == null ? null : …`), or TalkBack says «desactivado». Muted/archived lines keep their words and taps (muted wins over owner).
- **Strengths start at most 28 days out** (`strengthStart`; Suave 8 avisos, Normal 15, Intenso 22 from 4 weeks); custom/said rhythms reach 366.
- **Offer stops after 2 «Ahora no»** per account (`planOfferDeclines`); only an answer counts (Back/scrim leaves it); «Sí» resets to 0. Offered for any task that rings here, «Todos» included.
- **«A tu manera» listening field** follows the newest words (`_wordsScroll` jumps to end per partial), 4 lines, unfocused — same live-words rule as capture.
- **Said reminder, no day (D3, plan 2):** the capture card shows one button line «Para recordártelo, ponle un día.» (`_needsDayLine`, opens the date sheet) after the date line and its open `schedule` question, on the opened card and collapsed rows; no «Recordatorio» row meanwhile; saved without a day/deadline the lead is dropped.

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
  - Label size (b7 2026-10-21, UX-421): `main_shell.dart` `_fittingLabelScale` measures all four labels (bold and regular) against `(width − padding) / 4` and steps the label scale down until they fit, never below 1.0×; caps stay 1.3× (≥ 360 dp) and 1.2× (< 360 dp). Only the label's fontSize changes, via `NavigationBar.labelTextStyle`. Stopgap until U13. `_labelFontSize = 12` mirrors the theme's 12 sp — they must move together.
  - The fit has no margin: CA «Configuració» at 360 dp/2× uses ≈ 89 of 90 dp. If a device capture shows «Configuraci / ó», the fix is measuring against tab width minus a few dp, not a new concept.
  - Long-press tooltips follow the phone's text size (14 sp, 28 px at 2×).
  - The `outlineVariant` hairline above the bar is painted behind the opaque bar, so it never shows; the edge is only a tint change.
- **Rule to enforce:** never shrink text by wrapping a NavigationBar (or anything with tooltips/menus) in a MediaQuery — OverlayPortal content inherits it. Shrink the style instead.
- **One icon per concept:** Tareas = `check_box(_outlined)` (tab and the Tareas/Bandeja/project empty state); Notas = `description(_outlined)` (tab, Notas empty state, note rows, a project page's Notas button). Tasks complete with a round Checkbox, steps with square ones. `notes_rounded` remains at `voice_task_screen.dart` ("Revisar nota", should become `description_outlined`) and `captures_screen.dart` (means "typed, no audio" — fine).
- **Contrast:** enabled text-field borders now use `outline` (3.79:1 light, 4.85:1 dark on the field fill). Disabled/error/focus borders are M3 defaults. Text contrast is fine in both themes.
- Pushed screens repeat the app-bar title as a headline, with an uppercase eyebrow label above it.

Related: [[recurring-problems]], [[screens-b-calendar-tasks]], [[decisions-in-docs]].
