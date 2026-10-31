---
name: screens-b-calendar-tasks
description: Screen and flow map for UX-loop area B (calendar, home and tasks) as of 2026-10-13 — the Calendario layout, Tareas tab, tile gestures, task detail, TaskEditor, completed, timeline, and baseline counts
metadata:
  type: project
---

Current as of 2026-10-13 (whole-app run, slice B). Paths are under `App/lib/`.

**Why:** reviews start faster from a current map, and the baselines supply the "before" numbers.
**How to apply:** start area-B reviews here, and refresh this file whenever these screens change.

## Calendario (`screens/calendar_screen.dart`, tab 1, the first screen)
- **Top to bottom:**
  1. the header: bell (it opens Activity), moon, avatar;
  2. the "Todos los proyectos" chip;
  3. "Tu calendario", with a cloud icon;
  4. "Bandeja · N" → `/inbox` — shown even at 0;
  5. the week/month strip, with 4 px dots;
  6. Hoy / Vista mensual / Horario del día — it wraps to two lines in Spanish; "Horario del día" opens `/timeline`;
  7. the completion ring;
  8. "Agenda de hoy · N pendientes";
  9. phone-calendar events — up to 3 cards and "Ver todos los eventos", or an access prompt;
  10. the tasks;
  11. the bottom bar: "Capturas pendientes · N" when there are any, then Dictar una tarea / Nueva tarea. The two buttons stack from 1.3× text.
- **Empty day (b10):** a never-used account sees the try-it line ("Prueba: toca Añadir tarea y di «…»"); afterwards "Nada previsto para este día." — see [[ui-patterns]] › First-run teaching.
- **The agenda** shows only tasks dated on the selected day. The selected day is fixed when the screen is created.
- **Offline:** a red banner that mentions "la dirección del servidor".
- **A phone event** opens a sheet with "Abrir en la aplicación de calendario".

## Tareas tab (`screens/home_screen.dart`, isRoot)
- An eyebrow label and a headline, then search (accent-insensitive, `matchesSearch`).
- Empty state (shared with Bandeja and project pages) uses `check_box_outlined`, the Tareas tab icon.
- **Filter chips:** Todas / Bandeja de entrada (no date) / Bandeja personal (no project) / Hoy / Prioridad alta.
- **Icons:** the folder opens `/lists` (Projects); ✓ opens `/completedTasks`.
- The same create buttons as Calendario.
- `/inbox` is HomeScreen with the no-date filter.

## Task tile (`widgets/task_tile.dart`)
- The circle completes, with Undo.
- Swipe right completes.
- Swipe left or long-press opens "Cambiar fecha" (`_ScheduleSheet`).
- A tap opens the task detail.
- **Date line (`_dateLine`, 2026-10-22):** «Sin fecha» only when the task has neither a date nor a deadline (and `showUndated`); a deadline-only row reads just «Vence …» (red «· Fecha límite vencida» when passed). `LandedTaskTile` delegates to `TaskTile`. The Sin fecha page passes `showUndated: false`.

## Task detail (`screens/task_detail_screen.dart`, `/taskDetails`)
- **App bar:**
  - ✏ → `/editTask`;
  - 🗑 → a confirmation dialog with a filled "Eliminar"; the screen then closes without a word;
  - 🌙.
- **Body:**
  - "TU PRÓXIMO PASO";
  - the project chip — it opens the picker, and a tap there saves at once;
  - "Solo tú puedes verlo";
  - the "Planificado para" and "Hora" rows, which aren't tappable;
  - the reminder chip, which opens a sheet: the timing sits behind ⋮, then "Usar recordatorio";
  - Prioridad, NOTAS, ADJUNTOS, steps.
- **Bottom:** Completar and Cambiar fecha.
- Notes use a different version of this screen; see [[screens-c-lists-notes-sharing]].

- **Reminder chip with a plan (2026-10-22):** reads the plan line («Recordatorios normales hasta el … · próximo: …») and opens the reminder sheet: single rows, then (task ≥ 2 days away or already planned) «Hasta la fecha límite» (strengths) and «A tu manera» (Pro; dictate or type). See [[ui-patterns]] › Reminder plans. TaskEditor offers a plan only on create or when the anchor day moves.

## TaskEditor (`widgets/task_editor.dart`; `/createTask`, `/editTask`)
- **Above the title:** a headline, a help line, the "Bandeja personal ›" project row, and a Nueva tarea | Nota choice. The title field isn't autofocused.
- **Dates:**
  - date words in the title become a "Usar …" chip, plus "Conservar como título";
  - "Fecha y hora" opens `editSchedule()`.
- **"Más detalles":** duration, deadline, a repeat dropdown, reminder, priority, labels, steps (one dialog per step), attachments.
- **Buttons:** "Crear tarea" / "Guardar cambios". Back discards everything.
- **Pre-fill:** from Calendario, the selected day; from Tareas, nothing.
- **After saving:** the message names no day and offers no Undo.

## Other screens
- **Completed tasks** (`/completedTasks`):
  - reached from the ✓ on Tareas, and from Ajustes › Tareas completadas;
  - oldest first;
  - opened from a project page, it lists every project's completed tasks.
- **Day timeline** (`/timeline`):
  - its own ‹ › arrows, which TalkBack reads as month/week;
  - help paragraphs;
  - a "+" button.
- **A reminder notification** opens the task detail, or a second MainShell if the task is gone.
- **Back on a secondary tab** exits the app; MainShell has no back handling.

## Baselines (2026-10-13)
- **Calendario tap targets:** 25 on a brand-new account (the U10 target is 15 or fewer); 44 on a busy day.
- **First task card**, Spanish, on a 390×844 screen:
  - at 1.0× text it starts ≈597 dp down, and the capture bar starts at ≈650;
  - at 1.3× text no task is visible.
- **Taps:**
  - move to tomorrow: 4 (or a swipe + 2);
  - complete and undo: 2;
  - change reminder timing: 5;
  - set a repeat: 6, plus scrolling;
  - delete: 3, with no undo;
  - a typed task: 3, plus typing.
- **Task detail of a plain task:** about 45 words.

Related: [[ui-patterns]], [[screens-a-voice-capture]].
