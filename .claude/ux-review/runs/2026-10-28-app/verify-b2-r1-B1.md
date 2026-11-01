## UX verify — run 2026-10-28-app, batch b2, round 1, area B (P278, P279, P281, P282) — 2026-11-01

**Verdict:** Ship after fixes. All 14 findings are fixed. The new repeat sheet has 2 minor regressions (R1B1-1, R1B1-2).
**Evidence:** I read the code (`git diff HEAD`). I read the renders from 07:45–07:47 today, which are newer than every changed file in App/lib (`find -newer` lists none), and AUDIT.md. I used the testers' results as given. I didn't run Flutter. There's no device evidence: the device checks for UX-2406 (process death) and UX-1416 (TalkBack moving through a long agenda) are still for a phone.

### Findings

| ID | Result | Evidence |
|---|---|---|
| UX-2309 | fixed | `day_timeline_screen.dart:420-455`: the hour column is as wide as its widest label + 8. One lane fills the space beside the hours. Two or more lanes share that space down to 120 dp × scale (≤2), and below that they scroll sideways with `Scrollbar(thumbVisibility: true)` (:393-401). Titles end with an ellipsis at maxLines 1 (:598-600). The block's Semantics/Tooltip label keeps the whole title (:545-549, :565-569). Renders `calendar/timeline.busy.es.light.1x` (both lanes inside, «Reunión con el …»), `.busy.es.light.2x` (scrollbar along the bottom), `.untimed.es.light.2x` and `.normal.ca.light.2x` (every block inside, with an ellipsis). |
| UX-2314 | fixed | `region.dart:20-26` `dayHeading` drops the current year. The timeline uses it (:237), and calendar_screen.dart's heading is untouched. A block with `entry.point` has no bar (:588). The bar is a ColoredBox clipped by the Material's `Clip.antiAlias` (:580-581). The hour rows are wrapped in `ExcludeSemantics` (:469). Render: «domingo, 1 de noviembre» on one line at 1×. AUDIT `calendar/timeline · busy`: 17 stops, none of them an hour. |
| UX-2305 | fixed | `task_tile.dart:303`: `maxLines`/ellipsis are gone from the title. The notes line is still cut at 1 line (AUDIT «Preguntar por los resultados…» — ellipsis at 1 line). `calendar/agenda.normal.es.light.2x` shows «Llamar al médico para pedir cita» whole. |
| UX-1416 | fixed (code + test) | `task_tile.dart:234`: `direction: editable && !MediaQuery.accessibleNavigationOf(context) ? horizontal : none`. «Cambiar fecha» stays as a custom action (:227). The preview suite runs with accessible navigation off, so AUDIT still lists the scroll actions, as expected. The TalkBack walk through a long agenda is still a phone check. |
| UX-2313 | fixed | `region.dart:70-77` `deadlinePassedLine` → «Venció el {date}». The row (`task_tile.dart:113-114, :148`) has no error colour. The task page (`task_detail_screen.dart:359-361`) has no error colour and no «· Fecha límite vencida». The Día view's deadline blocks use `colors.tertiary` (:531). `deadlineOverdue` is gone from the three catalogs. Render `tasks/tasks-tab.deadline-passed.es.light.2x`: «Venció el jue, 29 de oct» in grey, once. |
| UX-2312 | fixed | `priorityValue` is an ICU select (es :320, ca :299, en :647). `priorityPhrase` is used on the row (:139), the capture card (:635, :827) and the form (:1041). The standalone `priorityName` stays on the task page and the command cards. `agendaCounts` has U+00A0 between each number and its word (ES 12, CA 10, EN 6), and its `=0` branch shows only the done half. `completedTaskSummary` ES uses «Toca». Renders: «Prioridad media»/«Prioritat mitjana»; at 2× «4 pendientes ·» on one line and «1 completada» on the next. The `calendar/completed.list` render (06:18) is older than the ARB change, so I judged the «Toca» string from the ARB. |
| UX-2616 | fixed | `task_tile.dart`: `textColor: unassigned ? colors.error` is removed. Render `tasks/project.many-people.ca.light.2x`: «Cal un responsable» in the row's grey. |
| UX-2406 | fixed (code + test) | `task_editor.dart:72-73`: WidgetsBindingObserver. `_saveInBackground` (:515-537) runs on `paused` for a changed, valid, saved task. It skips a new task, an empty title, labels that don't fit, and a rule change on a series with its own days. Saves are queued on `_holding` and compared with `_held`, so it doesn't save twice. `_save` waits for `_holding` (:565). Deshacer uses `_opened`, the task as the form opened (:577). An edit undone back to the original after a background save restores silently (:568-586). The test that kills the process with «No conservar actividades» is still for a phone. |
| UX-2407 | fixed | `repeat_rule_control.dart:127-145`: five ListTiles with a ✓ on the chosen one, `selected` styling, and Listo applies. The interval dialog button is `done` (:70). `keepChanges` is gone from the catalogs. Renders `form/repeat-sheet.open.{es,ca}.light.2x`: every row whole. See R1B1-1 and R1B1-2. |
| UX-2413 | fixed | `runSpacing: 8` in task_editor.dart:1313 and schedule_editor.dart:264. The weekday chips use `spacing: 8, runSpacing: 8` (repeat_rule_control.dart:76). AUDIT `form/new-task · filled` lists no gap problem. The repeat sheet's chips are 8 dp apart. |
| UX-2414 | fixed | `task_editor.dart:906-909`: `onFieldSubmitted` is removed. The title's Done key only closes the keyboard, in both forms. |
| UX-2419 | fixed | `task_editor.dart:743-762` `_hasPhoneOnlyFile` makes one local DB query plus `File.exists`, with no network. The paragraph shows only when an entry has no attachment record and exists on the phone (:785). `fileLocalHelp` is gone from the catalogs. |
| UX-2405 | fixed | `reminder_plan_sheet.dart:264-278` `_showPrivacyOnce` checks Pro and `reminderPrivacyShown` (regional_provider.dart), and sets the flag after the frame. The line shows under the field (:702-712) on the first opening, from `_toggle` or from opening on a plan. `capturePrivacy`'s second sentence is widened in ES/EN/CA, and the other sentences are unchanged. `@capturePrivacyLine` names both places. Render `reminders/sheet.your-way.es.light.2x`: the line is whole and «Listo» is in view. |
| UX-2412 | fixed | `reminder_plan_sheet.dart:785-804`: on every task the title is fixed above the choices, with `reminder-sheet-header-edge`. `_JustYou` shows on shared tasks only. Render `reminders/sheet.strength.es.light.2x`: «Recordatorio» is the first line, with the 1 dp edge under it. `sheet.shared.es.light.1x` is unchanged in substance. |

### Regressions

**R1B1-1 · Severity 2 · The repeat sheet shows «Cada semana» twice, as one list**
- Where: `App/lib/widgets/repeat_rule_control.dart:127-152` (`_RepeatSheet`). Renders `form/repeat-sheet.open.es.light.2x` and `.ca.light.2x`.
- The moment: "There are two «Cada semana». Which one do I press?"
- What happens: right under the five new rows, at the same type size and with 0 dp between them (AUDIT: «Cada semana Intervalo de repetición» 0.0 dp below «Cada año»), comes the interval row «Cada semana / Intervalo de repetición ✎». It reads as a sixth choice that repeats the ticked one. Tapping it opens a number dialog. With the old dropdown, the interval row sat under a field and read as a detail. As part of a list of rows, it reads as another option.
- Why it fails: lens D/F. Two different actions look alike side by side. Gestalt proximity and common region (Palmer 1992): the choices and the details of the chosen one aren't separated.
- Fix: put a `Divider(height: 24)` between the five choices and the details under them (interval, weekdays, end date), so the details read as belonging to the ticked row. Copy unchanged.
- Verify: the `form/repeat-sheet.open` render shows a rule between «Cada año» and the interval row. AUDIT puts at least 8 dp between them.
- Evidence: seen in a current render and in AUDIT.

**R1B1-2 · Severity 2 · At 2× with «Cada semana», Listo drops below the fold**
- Where: `App/lib/widgets/repeat_rule_control.dart:117-199`. Listo is the last child of the one `SingleChildScrollView`. AUDIT `form/repeat-sheet · open` (es 2×) marks «Sin fecha de fin» and «Listo» as off screen.
- The moment: "I picked «Cada semana». Now what? There's no button." They press Back or swipe the sheet down.
- What happens: the five rows add about 240 dp at 2× compared with the dropdown. With the weekday chips, the hint and the end date, Listo sits about 200 dp below the screen, and no scrollbar shows. Closing the sheet any other way drops the choice without a word.
- Why it fails: lens A/E. The primary action must be visible without scrolling (Fessenden 2018, direction only). There's a gulf of execution (Norman 2013), and the choice is lost silently (I).
- Fix: pin Listo under the scrolling choices: `Column(mainAxisSize: min, [Flexible(SingleChildScrollView(title, rows, details)), Padding(Listo)])`. That's the same pattern as the reminder sheet's fixed header, at the other end. No copy change.
- Verify: the `form/repeat-sheet.open` es 2× and ca 2× renders («Cada semana» ticked) show «Listo» on screen. AUDIT doesn't mark «Listo» off screen.
- Evidence: AUDIT for the current render (Listo off screen). I estimated from the code what it was before; there's no older render.

### Not regressions (checked)
- On the Día view at 2× with overlapping lanes, the hour column scrolls sideways with the lanes. That was already so before; the change doesn't cause it.
- In the Tareas render the AUDIT target «Clase de yoga» is 320 × 32 dp. That's a row cut by the screen edge, not a real target.
- The Día view's deadline blocks in tertiary: the timeline previews have no deadline block, so I didn't see it. The colour is the seed scheme's tertiary (tone 40 light / 80 dark) on surfaceContainer, so it is likely above 4.5:1. I inferred that; it isn't measured.

### Memory notes
- The repeat sheet is now five ListTile rows with ✓ (as the reminder sheet's rows), then the interval tile, weekday chips, end date and Listo, all in one scroll view.
- The reminder sheet has a fixed header on every task. The privacy line in «A tu manera» shows once per phone (`reminderPrivacyShown`).
- `dayHeading(date, now)` in region.dart is the Día view's and the task page's rule for leaving out the current year. `priorityPhrase` is for rows, the capture card and the form; `priorityName` is for the task page and command cards. `deadlinePassedLine` → «Venció el …», in grey.
- The edit form saves on `paused` (`_saveInBackground`); Deshacer goes back to `_opened`.
- Recurring problem: switching a dropdown to one-tap rows can push the sheet's primary action below the fold at 2×. Check where the confirm button sits whenever rows replace a compact control.
