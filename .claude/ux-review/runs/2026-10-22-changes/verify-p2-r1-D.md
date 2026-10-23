# Verify — run 2026-10-22-changes, plan 2, round 1, area D — 2026-10-22

Scope: P252 (UX-2001), P255 (UX-2013), P257 (UX-2020). Evidence: code (`git diff HEAD`), the testers' passing groups, and renders from 2026-10-23 00:56–00:57 (after the code). No device.

## Results

**UX-2001 · fixed (device check still owed)**
- `App/lib/services/reminder_plans.dart:61-90`: `moment()` and `dayLead(task, defaultLead)`: the task's own lead, then Settings' «Tareas con hora», only while it still falls on the anchor's day; null for a date-only anchor. `alerts()` takes `dayLead` (:102-106); `taskAlerts` takes a required `defaultLead` (:119-135).
- `App/lib/services/reminder_engine.dart:191-219`: the day's notice gets identity `…/plan/<date>/time` and `ReminderCopy.planDayBody` (`reminder_copy.dart:136-146`, the single reminder's text: «Hoy a las 17:00 · en 10 min», «Fecha límite: hoy a las 17:00»). Snooze path (:463-467) rebuilds it with lead 0 («Hoy a las 17:00»). `_planDaysBefore` parses only the date part (:166-176). It stays a plan alert for UX-2004's one-per-task rule (:514) and for `_currentTask` (:667).
- `App/lib/services/notification_service.dart:55-56`: the `/time` notice gets «Completar» + «Posponer 10 min» and `task_<lang>`; other plan notices keep `complete` and `plan_<lang>`. «Deshacer» re-shows from the stored identity, so it keeps the snooze.
- Words: `reminder_plan_words.dart` (`planRhythm`, `planSummary`, `planLine`, `planCount` take `dayLead`); every caller passes it: `reminder_control.dart:67-72, 96-110`, `reminder_plan_sheet.dart:474-478` and the 3 PlanPreviews + dictated row. `_chooseReminder` hands the sheet the task with its current minutes (`reminder_control.dart:371-372`).
- `alertAhead` now uses `late: false` and Settings' lead (`reminder_engine.dart:286-292`), as acceptance asks (false at 17:00).
- Render `reminders/task-line.timed-today.es.light.1x/2x`: chip «Recordatorios normales hasta hoy · próximo: hoy, 16:50», whole at 2×.
- Tests: P252 · D1 groups pass (engine 11, sheet 6).
- Still for a device: the notice at HH:MM−10 with «Completar» and «Posponer 10 min», and snooze back as «Hoy a las HH:MM».

**UX-2013 · fixed**
- `App/lib/services/reminder_preferences.dart:88-103`: `planOfferDeclines` and `setPlanOfferDeclines` under scope `plan-offer-declines:<owner>`.
- `App/lib/widgets/reminder_ask_sheet.dart:213-220`: reads the count first (a failed read counts as 0) and returns at 2 or more, before choosing a task or recording an offer. :289-296 writes only on an answer (true → 0, false → +1), as best effort; null (Back, scrim, drag) leaves the count as it was. Doc comments updated (:47-48, :201-203). The first reminder question is untouched.
- `App/test/support/reminder_fixtures.dart:37-44`: the in-memory count.
- Tests: P255 groups pass (widget flow and real SQLite).

**UX-2020 · fixed**
- `app_es.arb`: both values now have «a las 8». `app_ca.arb`: «a les 8». `app_en.arb`: values unchanged, both @descriptions reworded. The generated files match (`app_localizations_es.dart:4682, 5003`; `app_localizations_ca.dart:4660, 4981`).
- Renders `reminders/sheet.pro-screen`:
  - es 1×: «a las 8»» on one line, the example's last.
  - es 2×: «a las 8»» on its own last line.
  - ca 2×: «a les 8»» on one line; the heading, the example and «Mostra la subscripció» are on screen and unclipped.
- Tests: P257 · UX-2020 passes. UX-2019's character count, UX-1908's helper literals and the `_expectHourKeptWithPreposition('a las'/'a les')` checks were updated (test :2236-2238, :2298-2329, :3888-3894, :4030).

## Regressions

None found in the changed files or the flows they touch:
- the plan line, chip and sheet count;
- the plan notices: scheduled, snoozed and re-shown by «Deshacer»;
- the offer and its count;
- the Pro example and the «A tu manera» helper.

Side note, not caused by these packages: INDEX.md describes `sheet.pro-screen.ca.light.2x` with the Spanish heading and example. The render itself is Catalan.

## Notes for the main session
- Contract (Backend/docs/REMINDER_PLANS.md): D1's day notice carries «Posponer 10 min» and reads as the single reminder («Hoy a las 17:00 · en 10 min»). P252 asked for this note.
- `alertAhead` no longer counts the last notice (the day after) as a reminder ahead. So once a task's own day has passed its last pre-task notice, the first reminder question isn't asked for a task with a plan. This is as acceptance requires.
