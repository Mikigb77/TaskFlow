## UX verify — run 2026-10-13-app, round 1, area B (P6, P7) — 2026-10-13
**Verdict:** Ship after fixes. 7 of 8 findings are fixed; UX-202 is only partly fixed, because at 1.3x Spanish text the second task is still under the capture bar. There are 4 small regressions.
**Evidence used:** `git diff HEAD` of the listed files; the renders `App/build/calendar-es-1.3x-{light,dark}.png` and `calendar-feedback-{light,dark}.png` (all 19:40 today, newer than the code); ux-tester's results. Flutter was not run.

### Results
| ID | Result | Evidence |
|---|---|---|
| UX-202 | partly | The Tu calendario row and sync button are gone. The scope chip is hidden with no project (`project_scope_control.dart:26-28`). The ring is gone. `Bandeja · N` shows only when N > 0, under the tasks and events (`calendar_screen.dart` `if (inbox > 0)`). There is one `Semana ▾` menu with Semana/Mes/Día, and Hoy appears only on another day. **Still failing:** at 1.3x the month line wraps (`octubre de 2026` / `Semana ▾`, about 30 dp) and TaskActions stacks Dictar over Nueva tarea (`task_actions.dart:52-53`, threshold scale(14) > 18, about 60 dp). The second task's bottom is at 639 against the bar's top at 590 (render calendar-es-1.3x-light.png). |
| UX-217 | fixed | The events line comes after the task list (`calendar_screen.dart`, `DeviceCalendarEvents` after the SliverList). It reads `N eventos · 9:00 · …` with up to 3 times (`device_calendar_events.dart:47-58`) and opens `_CalendarSheet`. The tune action is now in the sheet header (`:209-220`). The access prompts use the same line, and a day with no events shows nothing. |
| UX-218 | fixed (phone check: airplane mode) | ARB `network`, `networkKept` and `otherKept` are in all 3 languages. Login passes `onSignIn: true` (`login_screen.dart:410-414`). On Calendar, a network error shows the grey `cloud_off` line with `calendarOffline`; other errors keep the banner. |
| UX-226 | fixed | The tile shows `… · Fecha límite vencida` (`task_tile.dart:183-185`), and so does the detail (`task_detail_screen.dart:246`). `eventLoader` filters completed tasks, so a day with only completed tasks has no dot (render calendar-feedback-light.png: 13 has no dot). |
| UX-205 | fixed | `addTask` returns the id. TaskEditor sets `calendarFocusProvider` when it was opened from Calendar or the day timeline. Calendar selects the day, scrolls the row clear of the snackbar, and lights it in primaryContainer for 1.5 s, with no animation when animations are off. The snackbar is `Añadida al {weekdayDate}` with Deshacer, which deletes the task. An undated task gets `taskSavedInbox` plus Undo. |
| UX-203 | fixed (phone check: overnight in recent apps) | `_scheduleMidnight` + `_followToday` run at midnight, on resume and in build, and move only a Calendar that was left on today. `currentDay: now`. `_create` and the timeline's FAB never pre-fill a past day. |
| UX-111 | fixed | `taskScheduleLabel` uses `context.dayLabel` → `Hoy` / `Mañana` / `vie, 16 oct`. Its callers include the capture review editor (`capture_review_editor.dart:377,385`). The branch with no context is used only by a test. |
| UX-220 | fixed | `_openOnDay` keeps a task completed while its day is shown in place. The set clears when another day is selected or a route covers Calendar. Completed tasks are listed newest date first (`task_list.dart` `newestFirst`). Switching tabs keeps the row in place; that matches the finding's own wording ("until the user leaves that day") and does no harm. |

### Regressions
**R1B-1 · Severity 2 · First dated save: the reminders question covers the landing**
- Where: `App/lib/widgets/task_editor.dart:418` (`askAboutRemindersAfterSave` after the landing and Undo snackbar); `reminder_ask_sheet.dart:44` waits only for the editor route to finish.
- The moment: "Where did my task go? And what was that Deshacer?" On the newcomer's first save, the modal sheet opens about 300 ms after the pop. Its barrier covers the 1.5 s highlight and the Undo snackbar (rendered in Calendar's Scaffold under the modal route).
- Why it fails: change blindness (Rensink et al. 1997); peak–end rule (Kahneman et al. 1993). The first save is the moment that teaches where tasks go.
- Fix: ask after the landing. Await the save snackbar's `closed` (or the end of the highlight) before `_ask` shows the sheet. Keep the Undo snackbar's time.
- Evidence: inferred from code; check with a widget test on a fresh account.

**R1B-2 · Severity 2 · The events read-error line says "Actualiza" but opens calendar choice**
- Where: `App/lib/widgets/device_calendar_events.dart:35` (`state.error` → `choose`), `:49` (load error → the sheet, which shows the same error again).
- The moment: "It says refresh — I tapped it and it shows a list of calendars."
- Fix: when tapped, the read-error line retries `deviceCalendarProvider.notifier.refresh()`. Shorten the copy to one line: EN `Couldn't read your events. Tap to try again.` / ES `No se pudieron leer los eventos. Toca para reintentar.` / CA `No s’han pogut llegir els esdeveniments. Toca per tornar-ho a provar.`
- Evidence: verified in code.

**R1B-3 · Severity 1 · Tile dates in two formats after UX-111**
- Where: `App/lib/widgets/task_planning_control.dart:11` (`taskDeadlineLabel` uses `shortDate`).
- On one tile, the schedule reads `vie, 16 oct · 17:00` and the deadline reads `12 oct · Fecha límite vencida`.
- Fix: `taskDeadlineLabel` uses `context.dayLabel(date)`.
- Evidence: verified in code.

**R1B-4 · Severity 1 · The view switcher is announced as "Mostrar menú"**
- Where: the `calendar-format` PopupMenuButton in `App/lib/screens/calendar_screen.dart` has no tooltip, so TalkBack falls back to MaterialLocalizations.showMenuTooltip. The buttons it replaced each had a name ("Vista mensual", "Horario del día").
- Fix: `tooltip:` EN `Change view` / ES `Cambiar vista` / CA `Canvia la vista`.
- Evidence: verified in code.

### Fix for what is left of UX-202 (subtract; about 49 dp needed)
- Keep the switcher on the month line: use `DateFormat.MMMM` (`octubre`) when the focused month is in the current year. This saves about 30 dp and also fixes the chevrons, which float between the two lines at 1.3x.
- Cut the top padding of "Agenda de hoy" from 26 to 12 dp (about 14 dp).
- Drop the 8 dp padding under an empty ProjectScopeControl.
- When P38 removes `Nueva tarea` from the bar, the stacked second button (about 60 dp) goes away and the check passes on its own.
- Verify: re-run `UX-202: at 1.3x text in Spanish…` (light and dark).
