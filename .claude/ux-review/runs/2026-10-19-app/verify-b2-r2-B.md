## UX verify — 2026-10-19-app, round 2, area B (P201) — 2026-10-20

### UX-1632 · fixed
- `App/lib/screens/calendar_screen.dart:437-457`: new `_overdueOn(tasks, now)` lists the overdue tasks that aren't among today's own occurrences, completed included (key `id:occurrenceId`), sorted by date as before. Build uses it at :679-680 (`overdue = today ? overdueToday : []`). Today's list is the same as before, because `calendarOccurrencesOn` works by day (`Task.day()`), so `calendarOccurrencesOn(now)` matches the old `events` for the selected day when that day is today.
- `:866` passes `overdueToday.length` to `_weekStrip`. In `markerBuilder` (:579-586), only today adds it (`dayTasks.length + (isToday ? overdueToday : 0)`). It doesn't depend on `_selectedDay`, so the value is the same whichever day is selected.
- The dots still come from `dayTasks.take(3)` (:592), the day's own open tasks. The count line (:906) and the overdue section (:955) are unchanged. No new strings.
- Render: `App/build/ux/calendar/agenda.month.es.light.1x.png`, rendered 10:05, after `calendar_screen.dart` was saved at 09:53. Nothing in `lib/` or `assets/` is newer. Today, the 20th, shows 3 dots (capped), and the count line reads «10 pendientes · 1 completada».
- AUDIT `calendar/agenda.month`: :2836 reads «martes, 20 de octubre de 2026» value «hoy · 10 tareas» [selected], then :2843 «10 pendientes · 1 completada». The 2× section (:3011/:3025) agrees.
- ux-tester: 7 acceptance tests pass. They cover today selected with 0 and with 1 overdue, another day selected, «hoy · 1 tarea», «1 tarea» on another day, and the dots unchanged.
- Evidence: verified in code, seen in a current render and in AUDIT, and widget tests. Still needs a device check: TalkBack on a phone with an overdue task.

### Regressions in the changed file, P201's flow only
None.
- An overdue task is now spoken twice in the strip: on its own past day («1 tarea» on the 18th) and inside today's count. That is what the brief asks for, and it matches the agenda, which also lists it under today. Not a regression.
- `_overdueOn` now runs on every build, not only when today is selected. Nobody would notice the cost.
