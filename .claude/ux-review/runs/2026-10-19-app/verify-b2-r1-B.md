## UX verify — run 2026-10-19-app, round 1, area B (P175) — 2026-10-20
**Verdict:** Ship after one small fix: all five findings meet their acceptance checks; one new mismatch in what TalkBack hears for today (R1B-1).
**Evidence:** code (`git diff HEAD`), the renders in `App/build/ux/calendar/` (09:05 on 2026-10-20, newer than every changed file in App/lib except the regenerated `l10n/generated/*`, which only adds keys), and `App/build/ux/AUDIT.md`. Widget-test level; no device or emulator evidence.

### Results
- **UX-1408 · fixed.** `calendar_screen.dart` `_weekStrip`: `rowHeight` = max(48, the measured selected number + 16), `daysOfWeekHeight` = max(30, the measured weekday + 8); narrow weekdays only when a short one is wider than its cell; day number in a `FittedBox(scaleDown)` inside a 4 dp-margin pill; card side padding 8 + 4 = 12 dp, so cells are 336/7 = 48 dp at 360. AUDIT: no week-strip text is cut in any `calendar/agenda` state; day targets 48 × 48 dp. Renders: `agenda.normal.es.light.2x.png` («L M M J V S D», «20» whole in its pill), `agenda.normal.ca.light.2x.png` («dl. … dg.» whole), `agenda.normal.en.light.2x.png`; `agenda.normal.es.light.1x.png` keeps «lun … dom».
  - Note, not a finding: the ES 2× render shows «L M M J V S D» rather than the brief's «L M X J V S D» because the preview's device region is US, so the locale is `es_US` (CLDR narrow form M M). On a Spanish phone (`es_ES`, falling back to `es`), Flutter's date data gives «X». Device check still open: emulator lane at 360 dp and 2.0 (non-linear text).
- **UX-1409 · fixed.** `outsideBuilder` draws another month's days with the plain or weekend style (`plain(day)`). Renders `agenda.month-boundary-week.es.light.1x.png` / `.es.dark.1x.png`: «1» (Sunday) matches «31», in light and dark. AUDIT month-boundary-week: no contrast failure on the strip; only the known count-line false positive.
- **UX-1410 · fixed.** (a) `markerBuilder` returns `Semantics(selected:, value:)` for every day; AUDIT TalkBack: «martes, 20 de octubre de 2026» value «hoy · 4 tareas» [selected], «jueves, 22 …» value «1 tarea». New keys `dayTaskCount`, `previousWeek`/`nextWeek`/`previousMonth`/`nextMonth` in all three ARBs; `previousPeriod`/`nextPeriod` removed, no users left. (b) month view uses the default `outsideDaysVisible: true`; AUDIT month lists 28–30 Sep and 1 Nov as labelled tappables, 0 unlabelled. (c) `onDayLongPressed: _pickDay`. (d) AUDIT reads «Semana anterior/siguiente» in Semana and «Mes anterior/siguiente» in Mes. Device check open: `selected=true` in the uiautomator tree.
- **UX-1411 · fixed.** `custom_app_bar.dart`: the root title is `Semantics(header, namesRoute, label: title, excludeSemantics)` around the unchanged logo row. AUDIT: first TalkBack line is heading «Calendario» / «Tareas» / «Notas» / «Ajustes» [names route]; «Cuenta» is now second. The «Label ≠ text … shows «taskflow»» line is expected by the brief. Device check open: TalkBack on a phone.
- **UX-1412 · fixed.** `_pickDay` sets `_format = CalendarFormat.week`. Render `agenda.month-day-tapped.es.light.1x.png`: Semana, 22 selected, «jueves, 22 de octubre», «Pagar la factura de la luz» well above «Añadir tarea»; «Semana ▾» still offers Mes.

### Regressions
**R1B-1 · Severity 2 · TalkBack hears a different count for today than the agenda**
- Where: `App/lib/screens/calendar_screen.dart` `markerBuilder` (value from `dayTasks.length`) vs the agenda count line (`agendaCounts(total - completed, …)`, where `total` adds today's overdue tasks).
- The moment: "It just said 9 tasks today; now it says 10 pending — which is it?"
- What happens: AUDIT calendar/agenda · month (es 1×): «martes, 20 de octubre de 2026» value «hoy · 9 tareas», then «Agenda de hoy», «10 pendientes · 1 completada» (render `agenda.month.es.light.1x.png`). The marker counts only the day's own open occurrences; today's agenda also lists carried-over overdue tasks.
- Why it fails: consistency (Nielsen 1994, heuristic 4); one concept, one number.
- Fix: for today, build the value from the same open count the agenda shows (the day's open tasks plus the overdue ones it lists), so the two numbers always match. No copy change.
- Verify: in the month fixture with one overdue task, today's value reads «hoy · 10 tareas» and the count line «10 pendientes · 1 completada».
- Evidence: verified in code and in AUDIT's TalkBack lines; widget-test level.

### Checked, no regression
- Header row inset 4 + 12 = 16 dp keeps «octubre» at 24 dp, aligned with «Agenda de hoy». The card now sits 8 dp from the screen edge while the agenda cards sit 20 dp in; that follows from the brief's 12 dp per side, not reported.
- In Mes, the adjacent month's days now look like the month's own; the brief asks for that.
- `AnimatedContainer` uses `Duration.zero` when animations are off (reduced motion kept).
- The non-selected days carry `selected: false`; AUDIT reads no «not selected» on them.

### Memory notes
- Week strip (`_weekStrip`, calendar_screen.dart): sizes from the text scaler, narrow weekdays only when the short form doesn't fit, 48 dp cells at 360 dp from a 12 dp side inset, other-month days styled like the month's own, every day's marker carries `selected` plus a «hoy · N tareas» value, tap or long-press in Mes goes back to Semana on that day.
- Root tabs: the logo stays, but TalkBack hears the tab name as the route heading (CustomAppBar). AUDIT's «Label ≠ text … taskflow» on root renders is expected now.
- Preview locale is `es_US` / `ca_US` / `en_US` (device region US), so CLDR regional forms show (e.g. ES narrow weekdays «M M», not «M X»). Don't report locale-data differences from previews as bugs without checking the `es` data.
- Recurring problem type: a new spoken or visible count that's computed differently from an existing count on the same screen (here, overdue tasks counted in the agenda but not in the day's marker).
