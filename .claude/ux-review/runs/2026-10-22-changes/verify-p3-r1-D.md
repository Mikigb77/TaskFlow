# Verify — run 2026-10-22-changes, plan 3 round 1, area D — 2026-10-23

Scope: P261 (UX-2022, UX-2026, UX-2031), P262 (UX-2030), P263 (UX-2033). Evidence is the code diff against HEAD 845ba2f, the testers' passing widget and engine tests, and renders dated 2026-10-23 11:53–12:02. All of them are newer than the code they show (source mtimes 11:44). Nothing here was checked on a device.

## Results

| ID | Result | Evidence |
|---|---|---|
| UX-2022 | fixed | `App/lib/services/reminder_plans.dart:83-84`: `dayLead(..., {ReminderPlan? plan})` returns null when `(plan ?? task.reminderPlan)?.time != null`. Engine `reminder_engine.dart:195` and `taskAlerts` (:139) pass the task carrying the plan, so they follow. The sheet now works out a lead for each plan shown: `reminder_plan_sheet.dart:478-482`, used at :585 (Normal), :619 and :640 (dictated) and :732 («A tu manera»). The doc comments at `reminder_engine.dart:159-162, 182-185` now name D1 and D8. Render `reminders/task-line.own-time-today.es.light.{1x,2x}` shows «Recordatorios: el mismo día · próximo: hoy, 09:00», whole at 2×. The engine tests prove 09:00 and 08:00, the `/plan/<date>` identity and nothing at 16:50. Still needs a device: the notice actually arriving at 09:00. |
| UX-2026 | fixed | `reminder_plan_sheet.dart` build: on `widget.shared`, a fixed `Column` holds the title, then `_JustYou` (padding 24/0/24/8, key unchanged), then `Flexible(choices(withTitle:false))`. All three copies above «Listo» are gone. A personal task keeps its title inside the scroll. Renders: `sheet.shared.es.light.1x` shows «Recordatorio», then «Estos avisos son solo para ti.» above «Desactivado». In `es.light.2x` and `ca.light.2x`, the sheet opens scrolled to the plan with the title and line still on screen and «Listo»/«Fet» visible. Still needs a device: TalkBack order. The column order gives title, line, rows. |
| UX-2031 | fixed | `reminder_plan_sheet.dart` PlanPreview row: `Text(today)`, an 8 dp gap, then `Expanded(Text(day, textAlign.end))`. Render `sheet.strength-far.ca.light.2x` shows «Avui» and «dt., 22 de des.» each on one line, with the end label at the row's end. |
| UX-2030 | fixed | `notification_settings_screen.dart:368-375`: `_plansWithoutTime()` adds `reminderRingsHere(ref, task)`. That function watches `taskListsProvider` (`reminder_control.dart:173-177`), so the row updates when projects load. Render `settings/reminders.all-day-off-plans.es.light.1x` (personal task) still reads «Desactivado · «Hasta la fecha límite»: 09:00». |
| UX-2033 | fixed | `reminder_ask_sheet.dart`: `_ringsHere(container)` is hoisted and shared with `_offer`. `_ask` asks only when a saved task both rings here and has `alertAhead`, and otherwise returns before `_askingProvider.add` and the `asked` write, so the next save of a task that rings here asks. After the await it checks `navigator.mounted`, the owner and `_askingProvider` again. `taskListsProvider` reads the local database, so the extra await adds no noticeable wait. |

## Regressions

**R1D-1 · Severity 1 · Fixed sheet header has no edge over scrolled rows**
- Where: `App/lib/widgets/reminder_plan_sheet.dart`, at the end of build, in the `widget.shared` branch (title, `_JustYou`, `Flexible`). Shown on a shared task when the sheet opens scrolled to a plan (UX-1810), most visibly at 2× text.
- The moment: "Recordatorio, solo para ti, Hasta la fecha límite… where is 'Desactivado'?"
- What happens: before this change, the title scrolled away with the rows, so a sheet that opened mid-list showed it was mid-list. Now the title and the line stay fixed, and the scrolled-away rows («Desactivado», «Elegir hora del aviso») and the divider slide under them with no edge. In the render `sheet.shared.es.light.2x`, «Hasta la fecha límite» sits right under «para ti.». The sheet looks like it starts at its top, and nothing hints that rows above exist.
- Why it fails: Norman's signifiers and Nielsen's "visibility of system status": a scroll position must be visible. Hidden content is discovered less often (Pernice & Budiu 2016).
- Fix: put a 1 dp `Divider(height: 1)` under `_JustYou` in the shared branch only, shown while the choices aren't at their top (for example from the `ScrollController`'s offset > 0). Alternatively, show it always. No new copy.
- Verify: re-render `sheet.shared.es.light.2x` and `sheet.shared.ca.light.2x`. A line must sit between «solo para ti.» and «Hasta la fecha límite» / «Fins al termini». The 1× render, which opens at the top, is unchanged if the divider is conditional.
- Evidence: seen in a current render (`sheet.shared.es.light.2x`, 11:54) and verified in code.

## Notes (not regressions)
- The two "rings here" rules differ for a project this phone doesn't know yet. `reminderRingsHere` (`reminder_control.dart:196`) treats it as ringing; `_ringsHere` (`reminder_ask_sheet.dart`) treats it as not ringing. That matches each brief (the offer's rule for the question), and the user can't notice it today.
- Not covered by any preview: a shared task in «A tu manera» with the keyboard open at 2×. There, the fixed header (title plus the two-line note, about 160 dp) takes room above the keyboard. Reasoning from the code, the field and «Listo» still scroll into view through `ensureVisible`. Worth one device look.
- For the contract, nothing to change: the brief says Backend/docs/REMINDER_PLANS.md already states D8.
