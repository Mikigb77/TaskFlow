---
name: ui-patterns
description: How TaskFlow's UI actually behaves as of 2026-10-13 (snackbars/undo, date sheets, task forms, error text, naming, project scope, capture, reminders, header/theme), with the stale "one shared sheet" and "one shared editor" claims corrected
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
- **No undo for:** typed save, delete, archive, moving a task into a shared project, leaving, and Completar on a notification.
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
  - Nothing outside can tell the calendar which day or task to show.
  - It doesn't follow midnight.
- "Nueva tarea" pre-fills the selected day, past days included. "Dictar una tarea" ignores it.
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

## Capture
- **Pro gate.** Every way into capture (button, widget, shortcuts, share) goes through `hasProProvider`.
  - Without Pro, a full-page Pro wall replaces voice, typing and shared text alike.
  - Billing that hasn't loaded yet counts as not Pro.
- **Capture records** are written when listening starts, before any words. Widget and shortcut taps write one up front. Leftover records show as "Capturas pendientes · N".
- `_busy` in `screens/voice_task_screen.dart` means both "loading" and "processing", so both show "Preparando tu plan…".
- **Listening stops** on any lifecycle state other than `resumed`, including `inactive` (pulling down the shade, system dialogs).
- **The pattern to keep:** the microphone permission is asked at the first capture, and typing stays available if it's refused.

## Reminders and notifications
- The reminders master switch defaults to off, per account and per device (`ReminderPreferences.enabled = false`).
- The OS notification permission and exact alarms are requested only from Ajustes › Notificaciones.
- The reminder chip (`widgets/reminder_control.dart`) leads with the timing and ends with the real state ("… · desactivado en el dispositivo"). It checks only the in-app switch, not the OS permission.
- **Notification actions:** Completar and Posponer 10 min. Tapping opens the task, or pushes a second MainShell if the task is gone.

## Header, tabs and theme
- `CustomAppBar.showAppearance` defaults to true, so the sun–moon toggle appears on about 23 surfaces.
- Every root tab shows a bell (it opens Activity), the moon, and the avatar (it opens Account).
- **Tabs:** Calendario, Tareas, Notas, Ajustes.
  - Tareas and Ajustes show the same icon selected and unselected.
  - Labels are 11 sp, and Flutter caps their scaling at 1.3×.
- **Contrast:** text-field borders use `outlineVariant` (1.28:1 in light). Otherwise the palette's text contrast is fine in both themes.
- Pushed screens repeat the app-bar title as a headline, with an uppercase eyebrow label above it.

Related: [[recurring-problems]], [[screens-b-calendar-tasks]], [[decisions-in-docs]].
