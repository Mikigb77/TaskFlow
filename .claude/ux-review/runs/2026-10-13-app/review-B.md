## UX review — Slice B: Calendar, home and tasks — 2026-10-13

**Verdict:** Don't ship. A task you didn't finish yesterday silently disappears from Today (UX-201), and at the newcomer's text size none of today's tasks are on screen when the app opens (UX-202). Almost every fix below removes something rather than adding it.

**Paths:** relative to `C:\Users\mikig\Desktop\Custom\MikiHacks\TaskFlow\TaskFlow\App\`.

**Evidence:**
- Findings rest on the code unless marked otherwise.
- Current renders used: `build\calendar-feedback-{light,dark}.png` and `build\review-direct-light.png`.
- I didn't run any preview tests, because the slices share the build directory.

**States checked:**
- empty, error, offline, and permission denied (calendar and notifications);
- many items and long titles;
- 1.3×/2× text and 320 dp, worked out from the layout code;
- Spanish and Catalan strings;
- dark mode: no contrast problems in the current render.

**Walked:** as the newcomer (Spanish, 1.3–2× text, one hand), the daily user and a TalkBack/low-vision user.

| Flow | Steps today |
|---|---|
| Open the app and understand today | 0 taps. But the tasks are below the fold (UX-202), overdue tasks are missing (UX-201), and the calendar can still be on yesterday after midnight (UX-203). |
| Find a task on another day | › → tap the day → scroll = 3. Month view adds 1. |
| Complete a task, then undo | 2 taps. Works. |
| Move a task to tomorrow | tile → Cambiar fecha → Mañana → Guardar programación = 4. Or swipe + 2. |
| Edit the title | tile → ✏ → tap field → type → Guardar cambios = 4 + typing. Changing the time takes 6–8. |
| Change when a reminder fires | tile → chip → ⋮ → choice → Usar recordatorio = 5. Reminders are off by default, so add a detour to Settings. |
| Set a repeat | tile → ✏ → Más detalles → Repetir → choice → Guardar cambios = 6 + scrolling. Impossible without a date, and nothing says why. |
| Add 3 checklist steps | 12 taps + typing |
| Add an attachment | 7 taps + scrolling |
| Delete a task, then undo | 3 taps. Undo is impossible. |
| Add a task by typing | Nueva tarea → tap the title (it isn't focused) → type → Crear tarea = 3 + typing |
| View completed tasks | Tareas → unlabelled ✓ icon = 2 |
| Overdue tasks | No path from Today |
| No-date tasks | "Bandeja · N" = 1 |
| Phone-calendar events | Shown above the tasks; tap → sheet → "Abrir en la aplicación de calendario" |

**Numbers:**
- **Tap targets on Calendar, brand-new account:** 25 including the tab bar (26 with one unsaved capture) → ≤15 (the U10 target); about 12 with the UX-202 changes.
- **Tap targets on Calendar, busy day** (one shared project, 4 phone events, 6 tasks, 1 unsaved capture): 44.
- **Where the first task starts** on a 390×844 dp phone in Spanish:
  - at 1.0× text it starts ≈597 dp down; the capture bar starts at ≈650, so one title line shows. After UX-202: ≈310.
  - at 1.3× text it starts ≈620–640 dp down; the screen ends at ≈590, so nothing shows. After UX-202: ≈330.
- **Move a task to tomorrow:** 4 → 3 taps (swipe + 2 → swipe + 1).
- **Complete and undo:** 2 → 2.
- **Change reminder timing:** 5 → 3 taps.
- **Delete and undo:** impossible today → 2 taps + Undo.
- **Typed "Nueva tarea", everything above the title field:** 10 targets, 2 decisions, ~23 words → 6 targets, 0 decisions, ~5 words.
- **Detail screen of a plain task:** ~45 words, including 4 empty or default sections → ~20 words.

### Findings (most severe first)

**UX-201 · Severity 4 · Unfinished tasks from earlier days vanish from Today**
- **Where:** `lib/screens/calendar_screen.dart:83-90` (the agenda is only `calendarOccurrencesOn(_selectedDay)`), `lib/models/task.dart:225-244`, and the Tareas "Hoy" filter at `lib/screens/home_screen.dart:210-211`. Happens on any day after a missed task.
- **The moment:** "Yesterday I had 'Llamar al banco'. Today it says 'Un momento de calma'. Did I do it? Was it deleted?"
- **What happens:**
  - An open task appears only on its own date.
  - Today's list, its counts ("0 pendientes") and the Tareas "Hoy" filter all leave it out.
  - The only trace on Today is a 4 px dot under yesterday, the same shape as a completed task's dot (UX-226).
  - No string anywhere describes an overdue task.
  - Users who can't find it will add it again.
- **Why it fails:**
  - Visibility of system status, and recognition over recall (Nielsen 1994): the user has to remember to look back.
  - Jakob's law (Nielsen 2000): other task apps show past-due items in Today.
  - It matches the definition of severity 4 almost word for word: "a saved task they can't see, so they add it twice".
- **Fix:**
  - On Today only, and only when there are some, show earlier open tasks at the top of the agenda under one header: EN "Overdue · {n}", ES "Atrasadas · {n}", CA "Endarrerides · {n}".
  - Use the existing tile with its date shown ("12 oct · Sin hora"). For a repeating task, show only its latest missed occurrence.
  - Count these tasks in "pendientes" and in the Tareas "Hoy" filter.
  - No new screen; this replaces browsing back day by day.
- **Verify:**
  - Widget test: an open task dated yesterday is listed first on Today with its date, and completing it there gives the usual Undo.
  - Walkthrough: run step 4 of UX_REVIEW §7 the day after step 2.
- **Evidence:** verified in code.

**UX-202 · Severity 3 · Today's tasks start below the fold**
- **Where:**
  - `lib/screens/calendar_screen.dart:107-176`: the "Todos los proyectos" chip, the "Tu calendario" row with its cloud icon, and the "Bandeja · 0" row.
  - `:322-369`: the Hoy / Vista mensual / Horario del día row, which wraps to two lines in Spanish.
  - `:411-424`: the completion ring.
  - `lib/widgets/task_actions.dart:63-70`: from 1.3× text the two buttons stack.
  - Render: `build/calendar-feedback-light.png`.
- **The moment:** "It says 'Agenda de hoy · 2 pendientes'… where are they?"
- **What happens:**
  - On a 390×844 dp phone in Spanish at 1.0× text, the first task card starts ≈597 dp down and the capture bar at ≈650 dp. Only the first line of the first title shows. (The current render had to be scrolled to its maximum, 107 dp, to bring the task up.)
  - At 1.3× text the bar grows to 134 dp and the header gets taller. The first task starts at ≈620–640 dp while the screen ends at ≈590 dp, so no task is visible.
  - Month view pushes the tasks a further ~190–240 dp down. Phone events push them ~300–400 dp (UX-217).
- **Why it fails:**
  - What people came for must be visible without scrolling; attention sits at the top of the screen (Fessenden 2018).
  - Newcomers don't explore (Carroll & Rosson 1987).
  - U5's "land and highlight" is wasted on a row below the fold (change blindness, Rensink et al. 1997).
- **Fix** (recovers ≈290 dp in Spanish and adds no controls):
  - Delete the "Tu calendario" row and its cloud icon. Pull-to-refresh stays, and a real sync problem still shows its banner.
  - Hide "Todos los proyectos" until a project exists (U10).
  - Show "Bandeja · N" only when N > 0, as one row inside the agenda (U10/U11).
  - Replace the Hoy / Vista mensual / Horario del día row with one switcher on the month line ("octubre de 2026 · Semana ▾"). Show "Hoy" only when another day is selected.
  - Delete the completion ring; the counts line already says the same thing.
  - U8's single Add button saves another ~60 dp at 1.3× text and above.
- **Verify:** re-render `calendar-feedback` at 1.0× and 1.3× text without `ensureVisible`. In Spanish at 1.3×, the first two tasks should be fully above the capture bar.
- **Evidence:** 1.0× seen in a current render. 1.3× inferred from the layout code; needs a render or a device check.

**UX-203 · Severity 3 · The calendar stays on yesterday after midnight**
- **Where:**
  - `lib/screens/calendar_screen.dart:29-30`: the selected day is set once, when the screen is created.
  - `:47-55`: returning to the app only reloads data.
  - `:69-70`: "Nueva tarea" pre-fills the selected day.
  - The same pre-fill in `lib/screens/day_timeline_screen.dart:244-245`.
- **The moment:** Tuesday 8:00, opened from recent apps: "'Lunes, 12 de octubre'… is that today?" Then "Nueva tarea · Comprar pan" is saved on Monday.
- **What happens:**
  - The calendar stays alive in the tab stack, and nothing moves its selected day when the date changes.
  - After midnight the header shows yesterday's date instead of "Agenda de hoy", and the list shows yesterday's tasks.
  - Typed tasks are pre-dated to yesterday, and then (because of UX-201) they vanish from Today.
  - Separately, browsing to a past day and tapping Nueva tarea creates a task that is already late.
- **Why it fails:**
  - Visibility of system status (Nielsen 1994).
  - Defaults are rarely changed (Johnson & Goldstein 2003), so the pre-filled date gets accepted as it is.
- **Fix:**
  - When the app comes back, and at midnight: if the selected day was "today" when last shown, move the selection and the week strip to the new today.
  - Never pre-fill a past day; Nueva tarea uses today instead.
  - No new UI.
- **Verify:**
  - Widget test: a fake clock crosses midnight, then a resume event; the header reads "Agenda de hoy".
  - Device check: leave the app in recent apps overnight.
- **Evidence:** verified in code. Whether the app survives overnight in memory needs a device check.

**UX-204 · Severity 3 · Typed dates are ignored unless a small chip is tapped**
- **Where:**
  - `lib/widgets/task_editor.dart:119-123`: the date is pre-filled from the calendar's selected day.
  - `:462-469` and `:606-639`: the "Usar …" chip and "Conservar como título".
  - `:588`: the keyboard's ✓ saves immediately.
  - `lib/services/quick_schedule_parser.dart:1-2`: the comment "Suggestions are never applied until the user accepts one". That is a code comment, not a recorded owner decision.
- **The moment:** types "Dentista viernes 10:00", taps "Crear tarea": "Done, it's on Friday."
- **What happens:**
  - Unless the small "Usar vie, 17 oct · 10:00" chip is tapped, the task is saved on the pre-filled day (today, when started from Calendario).
  - "viernes 10:00" stays in the title, and there's no time set, so no timed reminder.
  - While typing, the screen shows two different dates: the chip, and the date row "Fecha y hora · 13 oct · Sin hora".
- **Why it fails:**
  - Defaults (Johnson & Goldstein 2003): with opt-in, the default outcome is the wrong day.
  - Consistency (Nielsen 1994): two dates that contradict each other on one screen.
- **Fix:**
  - When the parser finds a date, put it in the date row straight away and keep the original words one tap away.
  - Replace the chip and "Conservar como título" with one line under the date row: EN "From your words · Keep as typed", ES "Según lo que has escrito · Dejar como está", CA "Segons el que has escrit · Deixa-ho com està".
  - Ambiguous times are covered in UX-221.
- **Verify:** widget test: type "Dentista viernes 10:00", press the keyboard ✓ → the task is "Dentista" on Friday at 10:00. "Dejar como está" restores the words and the previous date.
- **Evidence:** verified in code.

**UX-205 · Severity 3 · After typing a task, nothing shows where it went**
- **Where:**
  - `lib/widgets/task_editor.dart:358-372`: the form closes with "Tarea añadida al calendario" or "Tarea guardada en la bandeja de entrada" — no day, no Undo.
  - The calendar has no way to be told which day or task to show (`lib/screens/calendar_screen.dart:29`).
- **The moment:** "'Tarea añadida al calendario'… where? I can't see it."
- **What happens:**
  - The calendar comes back exactly as it was before.
  - If the task is on another day, it's off screen. If it's on the selected day, it's usually below the fold (UX-202).
  - Voice saves offer Undo (`lib/screens/review_tasks_screen.dart:154-160`); typed saves don't.
- **Why it fails:**
  - Change blindness (Rensink, O'Regan & Clark 1997).
  - Peak–end rule (Kahneman et al. 1993): how "add a task" ends is what people remember.
  - Consistency between the voice and typed paths.
- **Fix:**
  - Use one landing for every save, typed or spoken (the same mechanism as U5):
    - select the task's day;
    - scroll its row into view;
    - highlight it for about 1.5 s;
    - show a snackbar that leads with the day and offers Undo: EN "Added to {date}", ES "Añadida al {date}", CA "Afegida al {date}", with {date} from the locale date helper.
  - For undated tasks: "Added to No date", once U11 lands.
- **Verify:** widget test: create a Friday task from Calendario → Friday is selected, the row is visible and highlighted, and Undo removes it.
- **Evidence:** verified in code.

**UX-206 · Severity 3 · A moved task vanishes; the message names no day**
- **Where:**
  - `lib/widgets/task_interactions.dart:80-86`: the message "Programación actualizada".
  - `:188-202`: the Hoy/Mañana chips only set the date.
  - `:243-248`: the "Guardar programación" button.
  - Entry points: `lib/widgets/task_tile.dart:32-37, 71-73` and `lib/screens/task_detail_screen.dart:406-414`.
- **The moment:** "I said tomorrow… it's gone. 'Programación actualizada' — did it move, or did I delete it?"
- **What happens:**
  - After tapping "Mañana", the user still has to find "Guardar programación".
  - Then the row disappears from today, and the message doesn't say which day it moved to. "Programación" also reads as "programming".
  - That's 4 taps.
- **Why it fails:**
  - Gulf of evaluation (Norman 2013).
  - Change blindness.
  - Plain language (ISO 24495-1): say the result first.
- **Fix:**
  - Make Hoy and Mañana apply and close the sheet at once. Keep a save button only for when the calendar or the time row was used.
  - For the message, reuse the existing string `movedOccurrenceDate`: EN "Moved to {date}", ES "Movida al {date}", CA "Moguda al {date}", with Undo.
  - Rename the button: EN "Save date", ES "Guardar fecha", CA "Desa la data".
  - Taps go from 4 to 3.
- **Verify:** widget test: swipe left → Mañana → the sheet closes and the snackbar says "Movida al mié, 14 oct" with Undo.
- **Evidence:** verified in code.

**UX-207 · Severity 3 · Undo bars never go away, and one Undo does nothing**
- **Where:**
  - The move snackbar at `lib/widgets/task_interactions.dart:79-105` and the "suggestion applied" snackbar at `lib/widgets/task_editor.dart:242-263`.
  - Both have an action but no `persist: false`, so in Flutter 3.44 they never time out (SDK: `material/snack_bar.dart:303`, `material/scaffold.dart:622`).
  - The completion snackbar does it right (`task_interactions.dart:28-31`).
- **The moment:**
  - (a) "I tapped 'Nueva tarea'… why is the dentist back on today?"
  - (b) "I pressed Deshacer and it's still on Friday."
- **What happens:**
  - (a) "Programación actualizada · Deshacer" stays above the capture bar until someone dismisses it. Its Undo sits right above "Nueva tarea"; a slip of the thumb silently undoes the move.
  - (b) "Sugerencia de fecha aplicada · Deshacer" follows the user back to the calendar after saving.
    - Once the form has closed, its Undo does nothing.
    - The save message waits in the queue behind it, because `_save` doesn't clear the current snackbar.
- **Why it fails:**
  - Snackbars are brief, temporary feedback (Jakob's law, Material).
  - Feedback has to be truthful (Norman 2013).
  - It breaks the app's own pattern for Undo.
- **Fix:**
  - Every Undo snackbar uses the completion pattern: `persist: false` plus `FeedbackTimeout.forAction()`.
  - Clear the current snackbar before showing a save message.
  - No new copy.
- **Verify:**
  - Widget test: after a move, the snackbar disappears after the accessibility timeout.
  - Widget test: saving after accepting a suggestion shows "Tarea añadida…" immediately, with no stale bar.
- **Evidence:** verified in code and in the SDK source. The queue order needs a widget test.

**UX-208 · Severity 3 · Delete can't be undone, and Delete is the dominant button**
- **Where:**
  - `lib/screens/task_detail_screen.dart:30-69`: the confirmation dialog. The filled "Eliminar" button is at `:51-54`, and the screen closes without a word at `:61`.
  - `:124-146`: ✏ and 🗑 side by side in the top-right corner, next to 🌙.
- **The moment:** "I hit the bin by mistake, pressed the green button… it's gone. How do I get it back?"
- **What happens:**
  - The dialog's filled, eye-catching button is "Eliminar"; "Conservar tarea" is plain text.
  - After deleting, the screen closes with no message and no Undo.
  - 3 taps, and undo is impossible.
- **Why it fails:**
  - Habituation (Raskin 2000): people tap through confirmations, on the dominant button.
  - User control and freedom (Nielsen 1994).
  - Destructive actions should sit away from frequent ones (Clark 2015).
- **Fix:**
  - Drop the dialog: delete, close the screen, and show EN "Task deleted · Undo", ES "Tarea eliminada · Deshacer", CA "Tasca suprimida · Desfés", timed like the completion snackbar.
  - If a guard is wanted for deleting a whole repeating series, make "Conservar tarea" the filled button there.
- **Verify:** widget test: delete → snackbar → Undo brings the task back with its date, reminder and steps.
- **Evidence:** verified in code.

**UX-209 · Severity 3 · The reminder chip promises a reminder that can't fire**
- **Where:**
  - `lib/widgets/reminder_control.dart:24-50`: the chip text ends with "· desactivado en el dispositivo" (`:49`).
  - The chip checks only the in-app switch, not Android's notification permission (unlike `:201-205`).
  - It's shown at `lib/screens/task_detail_screen.dart:281-312`.
  - Root cause, in slice D: `lib/services/reminder_preferences.dart:12` (reminders are off by default).
- **The moment:** "'Recordatorio: 10 minutos antes'. Good, it'll remind me." It never does.
- **What happens:**
  - Until reminders are switched on in Ajustes → Notificaciones, every timed task reads "Recordatorio: 10 minutos antes · desactivado en el dispositivo". The real state is in the last words.
  - Date-only tasks read "Recordatorio: Desactivado · desactivado en el dispositivo".
  - If the switch is on but Android's permission was revoked, the chip gives no warning at all.
- **Why it fails:**
  - Front-load what matters; people read the first words of a line (Nielsen 2006).
  - Visibility of system status.
  - Ask for permission in context (Android guidelines).
- **Fix:**
  - When a reminder can't fire (switch off or permission missing), the chip shows only the fix.
  - Reuse the existing string `enableReminders`: EN "Enable reminders", ES "Activar recordatorios", CA "Activa els recordatoris", with a bell-off icon.
  - Tapping it asks for permission right there, turns the switch on, and the chip then reads normally.
  - Delete the "· desactivado en el dispositivo" suffix.
- **Verify:** widget tests with the switch off, and with permission denied → the chip says "Activar recordatorios". After granting, it shows the normal text.
- **Evidence:** verified in code. The old render `artifacts/design/checklist-detail-light.png` shows "Reminder: Off · device off" (context only).

**UX-210 · Severity 3 · Reminder timing can only be changed through a ⋮ icon**
- **Where:**
  - `lib/widgets/reminder_control.dart:136-171`: the "Recordatorio" row ignores taps; its only control is a trailing ⋮ menu.
  - `:86-89`: the "Usar recordatorio" button.
  - The same control is in the form at `lib/widgets/task_editor.dart:886-895`.
- **The moment:** "I want an hour before. I tap 'Recordatorio'… nothing. What are the three dots?"
- **What happens:**
  - The row looks like the tappable "Fecha y hora" row, but tapping it does nothing.
  - The choices are hidden behind ⋮, which Android users read as "more options".
  - Then "Usar recordatorio" has to be pressed. It reads as "turn the reminder on", even after choosing "Desactivado".
  - 5 taps.
- **Why it fails:**
  - Signifiers (Norman 2013).
  - Icon usability (Harley 2014).
  - Hidden UI (Pernice & Budiu 2016).
- **Fix:**
  - The chip opens the list of choices directly, and a choice applies and closes it. Remove the ⋮ and "Usar recordatorio".
  - In the form, tapping the row opens the same list.
  - 5 → 3 taps.
- **Verify:** widget test: chip → "1 hora antes" → the chip reads "Recordatorio: 1 hora antes" and the sheet is closed.
- **Evidence:** verified in code.

**UX-211 · Severity 3 · Back in the task form drops what was typed**
- **Where:**
  - `lib/widgets/task_editor.dart` has no back handling (compare `lib/screens/review_tasks_screen.dart:269`).
  - `lib/main.dart:312-398` has no state restoration.
- **The moment:** types a long note and presses back, as they would in WhatsApp: "Where did my text go?"
- **What happens:**
  - Back closes "Nueva tarea" or "Editar tarea" and silently throws away the title, notes, date, steps and attachments.
  - If Android kills the app during a phone call, the form is lost too (inferred).
- **Why it fails:**
  - Error prevention, and user control and freedom (Nielsen 1994).
  - The voice path keeps every word; typing should be no worse.
- **Fix:**
  - Back keeps the work:
    - a new task with a title is saved and lands as in UX-205;
    - an edit with changes is saved with ES "Cambios guardados · Deshacer" (EN "Changes saved · Undo", CA "Canvis desats · Desfés");
    - an empty form just closes.
  - If the owner prefers to ask instead: one sheet, "¿Guardar esta tarea?", with "Guardar" as the dominant button.
- **Verify:**
  - Widget test: type a title, press back → the task exists, with Undo.
  - Device check with "Don't keep activities" turned on.
- **Evidence:** back behaviour verified in code. Loss after the app is killed is inferred.

**Severity 2**
- **UX-212 · 2 · Two date pickers and two repeat editors.** `lib/widgets/task_interactions.dart:118-262` vs `lib/widgets/schedule_editor.dart`; for repeat, `lib/widgets/task_editor.dart:772-883` vs `lib/widgets/repeat_rule_control.dart:101-182`.
  - "Cambiar fecha" has its own sheet: a date dialog, the clock dial, and a "Bandeja de entrada" chip.
  - Editing uses the 12 Oct sheet, with "Sin fecha" and typed hours.
  - Repeat is a dropdown in the form but a sheet in voice review.
  - → Open `editSchedule()` from Cambiar fecha, with "Esta repetición / Toda la serie" above it for repeating tasks, and delete `_ScheduleSheet`. Use the repeat sheet in both places. [code]
- **UX-213 · 2 · A plain task's detail is mostly empty or default sections.** `lib/screens/task_detail_screen.dart:152-158, 171-194, 266-276, 377-378`, `lib/widgets/attachment_panel.dart:159-186`.
  - It shows "TU PRÓXIMO PASO", a "Bandeja personal" chip plus "Solo tú puedes verlo.", and "Prioridad: Baja" on every task (the default is labelled Low).
  - It also shows "NOTAS — Sin texto añadido." and "ADJUNTOS — No hay archivos adjuntos. Añade un archivo al editar."
  - That's about 45 words.
  - → Delete the label; hide the project chip and the "only you" line until a project exists; show priority only when it's above the default; hide empty Notes and Attachments. About 20 words. [code]
- **UX-214 · 2 · The date rows on the detail look tappable but aren't.** `lib/screens/task_detail_screen.dart:433-471, 124-146`.
  - "Planificado para" and "Hora" look like the form's tappable rows but do nothing.
  - Editing hides behind an unlabelled ✏ in the top corner, the hardest spot to reach one-handed, next to 🗑.
  - → Tapping the date or time row opens the same sheet as "Cambiar fecha"; tapping the title opens the form. [code]
- **UX-215 · 2 · The typed task form asks questions before the title.** `lib/widgets/task_editor.dart:497-558, 582-605`.
  - Above the title field: a 28 sp headline, a help line, a "Bandeja personal ›" row, and a "Nueva tarea | Nota" choice.
  - The title field isn't focused.
  - In edit mode the help line still says "Ponle un nombre…".
  - → Delete the headline and the help line; hide the project row until a project exists; drop the task/note choice (UX_REVIEW §5.1); autofocus the title. 10 → 6 targets, 2 → 0 decisions.
  - Later: give typed create and edit the 12 Oct review layout, so there is one task form. `docs/DESIGN.md` still says "one shared editor", which is no longer true. [code]
- **UX-216 · 2 · "Más detalles" opens eight things at once.** `lib/widgets/task_editor.dart:759-1019`, `lib/widgets/task_planning_control.dart:116-186`.
  - It reveals duration, deadline, repeat, reminder, priority, labels, steps and attachments together, plus four help paragraphs (two of them use "MiB").
  - Recordatorio sits in the middle of the list.
  - Repetir disappears entirely when there's no date, with no hint.
  - → Order by how often each is used: Recordatorio, Repetir, Pasos first. Delete the paragraphs and write "MB" instead of "MiB". When there's no date, show Repetir greyed out with EN "Add a date to repeat", ES "Añade una fecha para repetir", CA "Afegeix una data per repetir". Words go from ~100 to ~30. [code]
- **UX-217 · 2 · Phone-calendar events sit above the day's tasks.** `lib/screens/calendar_screen.dart:429`, `lib/widgets/device_calendar_events.dart:26-77`.
  - Above the tasks: up to three event cards of three lines each, "Ver todos los eventos", and, if access was denied, a two-sentence access prompt. That's ~300–400 dp, and it's not in time order with the tasks.
  - → Put the tasks first. Under them, one line — "📅 3 eventos · 9:00 · 11:30 · 16:00 ›" — that opens the existing sheet. Move the access prompt onto that line. [code]
- **UX-218 · 2 · Being offline shows a red error about a "server address".** `lib/screens/calendar_screen.dart:149-155`, fed by `lib/repositories/cloud_task_repository.dart:236-237` and `lib/l10n/request_locale.dart:92-93`.
  - When offline, the home screen shows a red box: "No se ha podido conectar con el servidor. Revisa la conexión y la dirección del servidor…"
  - The server address is a developer setting, and being offline is a normal state, not an error.
  - → Show one neutral line, not red: EN "Offline — your tasks are saved on this phone.", ES "Sin conexión: tus tareas están guardadas en este teléfono.", CA "Sense connexió: les tasques estan desades en aquest telèfon." [code]
- **UX-219 · 2 · An empty filter looks like all tasks are gone.** `lib/screens/home_screen.dart:217-233`.
  - On Tareas, a filter with no results (for example "Prioridad alta") shows "Un nuevo comienzo — Usa Dictar una tarea…", as if every task had disappeared.
  - → When any filter is on, reuse "No hay tareas que coincidan · Prueba otra palabra o filtro." [code]
- **UX-220 · 2 · Completed tasks are hard to find right after completing them.** `lib/screens/calendar_screen.dart:87-89`; Completed screen sorted by `lib/widgets/task_list.dart:10`.
  - A completed task jumps to the bottom of the day instantly; on a busy day that's off screen.
  - "Tareas completadas" lists the oldest first.
  - → Leave the completed row where it is until the user leaves that day. Sort completed tasks newest date first. [code]
- **UX-221 · 2 · Typed and picked times have traps.** `lib/widgets/task_editor.dart:637-638`, `lib/services/quick_schedule_parser.dart:108-110`, `lib/widgets/schedule_editor.dart:40, 180-210`.
  - Typing "a las 5" — or "a las 17", which isn't ambiguous at all — shows "Elige a. m./p. m. o añade la hora…" with no control to do it, and 24-hour sheets have no a. m./p. m. option.
  - The 12-hour sheet preselects a. m., so "5" becomes 5:00 a. m.
  - An empty minutes box fails with "Revisa este valor".
  - → Replace the paragraph with two time chips, "[5:00] [17:00]" (12-hour: "[5:00 AM] [5:00 PM]"). Treat 13–23 as unambiguous. Treat empty minutes as 00. Don't preselect a. m. [code]
- **UX-222 · 2 · Each checklist step needs its own dialog.** `lib/widgets/checklist_editor.dart:18-55, 136-143`.
  - Three steps take 9 taps plus typing, and steps can't be added from the detail screen.
  - → An inline "Añadir paso" field that stays focused after Enter (about 6 taps for 3 steps). Delete the dialog. [code]
- **UX-223 · 2 · Back on a secondary tab closes the app.** `lib/screens/main_shell.dart:18-76` (no back handling), `lib/main.dart:245-254`.
  - Back on Tareas, Notas or Ajustes closes the app instead of returning to Calendario. Android's guidance is that the start screen is the last one before leaving (developer.android.com, Principles of navigation).
  - Tapping a reminder whose task was deleted opens a second copy of the home screen.
  - → Back on a secondary tab selects Calendario. For a missing task, show the detail's existing "Tarea no disponible" state instead. [code]
- **UX-224 · 2 · The day timeline has wrong labels, developer copy and an extra create button.** `lib/screens/day_timeline_screen.dart:94-105, 116, 171-172, 242-246`.
  - TalkBack reads the day arrows as "Mes o semana anterior/siguiente".
  - Two help paragraphs, one of them developer-speak ("Los eventos cortos tienen una zona táctil más grande…").
  - A "+" button adds a fourth way to create a task.
  - → Label the arrows EN "Previous day / Next day", ES "Día anterior / Día siguiente", CA "Dia anterior / Dia següent". Delete `timelineShortBlocks` and `timelineHelp`. Use the shared create control once U8 lands. [code]
- **UX-225 · 2 · Translation slips.** `lib/widgets/task_editor.dart:986`; `lib/l10n/app_es.arb:444`, `app_ca.arb:423`; `app_es.arb:364`, `app_ca.arb:343`; `lib/l10n/region.dart:64`.
  - The tooltip "Remove {file}" is hard-coded in English.
  - TalkBack calls a checklist "Proyecto de pasos" / "Projecte de passos".
  - Plurals are missing: "0 pendientes · 1 completadas" (visible in the current render) and "Cada 1 semanas · lun, mié".
  - → Translate the tooltip; use "Lista de pasos" / "Llista de passos"; use ICU plural forms. [code + render]
- **UX-226 · 2 · Some states rely on colour alone.** `lib/widgets/task_tile.dart:173-182`, `lib/screens/task_detail_screen.dart:240-250`, `lib/screens/calendar_screen.dart:287-317`.
  - A passed deadline only turns red; the words stay the same. The string `deadlineOverdue` exists but is never used.
  - The 4 px dots in the week strip tell done from open only by colour.
  - → Append "· Fecha límite vencida" (existing string). Draw dots only for open tasks. [code]

**Severity 1**
- **UX-227 · 1 · Polish:**
  - English "Create Task" and "Task Title" should be sentence case.
  - The label "COMPLETADAS" appears above a single completed task (`lib/screens/task_detail_screen.dart:156`).
  - English `labelLimit` says "under 33 characters"; make it "up to 32".
  - The summary chips under "Más detalles" look tappable but aren't (`lib/widgets/task_editor.dart:726-749`).
  - "Quitar fecha" duplicates the sheet's "Sin fecha" (`:683-687`).
  - Catalan "Reprograma" should be "Canvia la data".
  - Calendar paging animations ignore the reduced-motion setting (`lib/screens/calendar_screen.dart:199-211`).

### Keep
- The completion Undo reads Android's accessibility timeout on every toggle (`lib/widgets/task_interactions.dart:19-31`). Make it the model for every Undo.
- Every gesture has a visible alternative: the circle completes a task, and "Cambiar fecha" on the detail moves it.
- On the detail screen, "Completar" and "Cambiar fecha" are labelled and sit low, in thumb reach.
- The 12 Oct date sheet (`lib/widgets/schedule_editor.dart`) should become the only date picker.
- Snackbars float above the capture bar, and the bar never covers task cards (asserted at `test/calendar_feedback_test.dart:170-173`).

### Progress against UX_REVIEW.md (U1–U14): nothing advanced or regressed
- **U10 (this slice): still open.** A brand-new account sees 25 tap targets on Calendario; the target is 15 or fewer.
  - The bell, moon and avatar are always there (`lib/widgets/custom_app_bar.dart:53-60`).
  - "Todos los proyectos" is always shown (`lib/widgets/project_scope_control.dart:25-41`). "Para mí" and "Equipo" are already conditional (`:107`).
  - "Bandeja · 0" is always shown (`calendar_screen.dart:156-172`).
  - There are three view buttons (`:328-366`).
  - The empty state is unchanged (`:448-457`).
  - "Unfinished captures" already appears only when there are some (`task_actions.dart:21-22`).
- **U5 (slice A): still open.** The same gap exists after typed saves (UX-205) and after moves (UX-206).
- **U8 (slice A): still open.** There's also a third create button on the empty calendar ("Escribir una tarea", `calendar_screen.dart:451-456`) and a fourth on the timeline (`day_timeline_screen.dart:242-246`).
- **U11: still open.** On my screens:
  - "Bandeja de entrada" and "Bandeja personal" are adjacent filter chips (`home_screen.dart:158-159`);
  - every undated task says "Bandeja de entrada · Sin fecha" (`task_schedule_label.dart:10`);
  - "Bandeja · N" on Calendario (`calendar_screen.dart:161`);
  - the move sheet's "Bandeja de entrada" chip (`task_interactions.dart:200`) versus the edit sheet's "Sin fecha" (`schedule_editor.dart:130`);
  - "Movida a la bandeja de entrada" (`task_interactions.dart:85`).
- **U12: still open.** The empty calendar still explains the buttons (`calendar_screen.dart:449-457`).
- **U13: undecided.** Still four tabs (`main_shell.dart:51-72`).

### Questions for the owner
1. **Overdue tasks:** should unfinished tasks carry over into Today (UX-201 assumes yes), or stay on their own date with only a "{n} sin hacer de días anteriores ›" link?
2. **Delete:** is it OK to replace the confirmation dialog with Undo (UX-208)?
3. **Typed dates:** should the app apply the date it understood by default, with "Dejar como está" one tap away (UX-204)? The code comment treats "never apply automatically" as deliberate.
4. **Back in the task form:** save with Undo, or ask "¿Guardar esta tarea?" (UX-211)?
5. **Sun–moon switch:** it's on every secondary screen's top bar; on the task detail it sits right beside ✏ and 🗑. Keep it there, or show it only on Calendario and Ajustes? (Its placement is still open, per §5.1.)

### Cross-slice notes
- **A:** the Undo snackbars at `lib/screens/review_tasks_screen.dart:154-160, 233-236` lack `persist: false`. Their 8 s duration is ignored, and after a voice save they stay on the calendar.
- **A:** in `build/review-direct-light.png`, "Más opciones · Prioridad Baja · No se repite" lists default values. Show only what's actually set.
- **C:** `lib/screens/notes_screen.dart:180` uses the string `checklist`, which reads "Proyecto de pasos" / "Projecte de passos". `lib/widgets/task_list_picker.dart:82` uses "Archivada" (feminine) for a project.
- **D:** reminders are off by default (`lib/services/reminder_preferences.dart:12`) and can only be switched on in Ajustes. That's the cause behind UX-209 and U12's permission timing.
- **D:** the offline text mentioning "dirección del servidor" also appears on Account (`lib/screens/account_screen.dart:209-213`).

### Memory notes
**New issues — all OPEN, logged 2026-10-13 from slice B:**
- UX-201 (4) Unfinished past tasks vanish from Today; the app has no concept of overdue.
- UX-202 (3) Today's tasks are below the fold. Spanish 1.0×: first task ≈597 dp vs bar ≈650; none visible at 1.3×.
- UX-203 (3) Selected day stays on yesterday after midnight; Nueva tarea pre-fills past days.
- UX-204 (3) Typed date words are ignored unless the "Usar…" chip is tapped → saved on the wrong day.
- UX-205 (3) Typed save: no landing, no day in the message, no Undo (typed twin of U5).
- UX-206 (3) A moved row vanishes; "Programación actualizada" names no day; Hoy/Mañana need an extra Save.
- UX-207 (3) Move and suggestion Undo snackbars never dismiss; the form's Undo goes dead and blocks the save message.
- UX-208 (3) Delete has no undo; "Eliminar" is the filled button; ✏ 🗑 🌙 are adjacent.
- UX-209 (3) Reminder chip says "10 minutos antes · desactivado…" when reminders can't fire.
- UX-210 (3) Reminder timing is changed only via ⋮, plus an extra "Usar recordatorio" step.
- UX-211 (3) Back in TaskEditor silently drops input.
- UX-212 (2) Two date sheets and two repeat editors.
- UX-213 (2) Task detail shows empty or default sections (Prioridad Baja, empty notes and attachments, "Solo tú puedes verlo").
- UX-214 (2) Detail rows aren't tappable; edit is an unlabelled ✏ in the top-right corner.
- UX-215 (2) New-task form has a headline, help line, project row and task/note choice before the title; no autofocus.
- UX-216 (2) Más detalles shows 8 concepts and 4 paragraphs; Repetir is hidden without a date.
- UX-217 (2) Phone events sit above tasks, not in time order with them.
- UX-218 (2) Offline shows a red banner mentioning the server address.
- UX-219 (2) An empty filter says "Un nuevo comienzo".
- UX-220 (2) A completed task jumps to the bottom; the Completed list is oldest first.
- UX-221 (2) Time traps: a. m./p. m. paragraph, "a las 17" treated as ambiguous, a. m. preselected, empty-minutes error.
- UX-222 (2) One dialog per checklist step.
- UX-223 (2) Back on a secondary tab exits; a reminder for a deleted task opens a second MainShell.
- UX-224 (2) Timeline: wrong arrow labels, developer copy, extra + button.
- UX-225 (2) Translation: hard-coded tooltip, "Proyecto de pasos", missing plurals.
- UX-226 (2) Colour-only states: passed deadline, calendar dots.
- UX-227 (1) Polish bundle.

**U1–U14 status, 2026-10-13:** U10 recounted at 25 targets on a brand-new account (the For me/Team chips and unsaved captures are already conditional). U5, U8 (now with 3rd and 4th create entries), U11 and U12 are open; U13 is undecided. No change.

**Patterns:**
- The Undo standard is `persist: false` plus `FeedbackTimeout.forAction()` (`task_interactions.dart:28-31`). In Flutter 3.44, any snackbar with an action never dismisses unless `persist: false` is set.
- Snackbars use the root messenger: they follow the user across screens and queue behind one another.
- The target date picker is `schedule_editor.dart`, but "Cambiar fecha" still uses its own `_ScheduleSheet`. The memory line "one shared sheet" is only partly true.
- Typed create and edit use `TaskEditor` (the old layout); voice review uses `capture_review_editor.dart`. DESIGN.md's "one shared editor" is out of date.
- The calendar's selected day is private state (`_selectedDay`); nothing outside can tell it which day or task to show. U5, UX-205 and UX-206 all need that.
- Reminders are off by default (`ReminderPreferences.enabled = false`).

**Recurring problem types:**
- confirmations that name the action but not the result;
- the state placed at the end of a label;
- empty sections rendered as text;
- default values shown as if chosen ("Prioridad Baja", "No se repite").

**Screen map (slice B):**
- **Calendario** (`calendar_screen.dart`), top to bottom:
  - project chip;
  - "Tu calendario" + cloud icon;
  - "Bandeja · N";
  - week/month strip;
  - Hoy / Vista mensual / Horario del día;
  - agenda, with phone events above the tasks;
  - Dictar / Nueva tarea bar.
- **Tareas** (`home_screen.dart`): filters Todas / Bandeja de entrada / Bandeja personal / Hoy / Prioridad alta. 📁 opens /lists; ✓ opens /completedTasks. `/inbox` is HomeScreen with the "no date" filter.
- **Task tap** opens TaskDetailScreen:
  - ✏ opens /editTask (TaskEditor);
  - 🗑 opens a confirmation dialog;
  - Completar and Cambiar fecha sit at the bottom;
  - the reminder chip opens a sheet.
- **Nueva tarea** opens /createTask (TaskEditor). From Calendario it pre-fills the selected day; from Tareas it pre-fills nothing.
- **Gestures:** swipe right completes; swipe left or long-press opens the move sheet.
- **Timeline:** /timeline, with its own ‹ › and a + button.
- **Reminder notification:** opens TaskDetailScreen, or a second MainShell if the task is gone.
