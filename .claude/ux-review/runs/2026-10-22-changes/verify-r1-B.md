## UX verify — run 2026-10-22-changes, round 1, area B — 2026-10-22
**Verdict:** P241, P243 and P245 have all landed. All 12 findings are fixed. I found no regressions in the changed files.
**Evidence:** I read the code in the working tree (`git diff HEAD`). I looked at the renders in `App/build/ux/reminders/`, made at 14:49–14:50. No file in App/lib or App/assets is newer than them, so they're current. I read the AUDIT sections for reminders/sheet · strength, task-line · strength and task-line · own-words. Every acceptance test named in the delegation exists in `App/test/reminder_plan_sheet_test.dart` (lines 1239–1534, 2633–2954 and 3059–3304). The testers report that they all pass.

### P241
- **UX-1806 · fixed.** `planSummary` (`App/lib/l10n/reminder_plan_words.dart:57-84`) now builds the line from `reminderPlanStrengthLine` and `reminderPlanOwnLine` (es:1394-1395; ca:1098-1099; en:3652, 3667). The rhythm is lowercased after the colon, through the new `capitalized:` option on `planRhythm`. After a person's name the line uses the bare, lowercase form (`reminder_control.dart`, `reminderLine` and ReminderControl's `bare: true`).
  - Render task-line.strength.ca.light.2x reads «Recordatoris normals fins al dj. 12 · proper: demà, 09:00».
  - Render task-line.own-words.es.light.2x reads «Recordatorios: cada 3 días, y a diario la última semana · próximo: mañana, 09:00».
  - Both wrap with nothing cut.
  - In AUDIT, TalkBack reads one button whose label starts with «Recordatorios».
- **UX-1807 · fixed.** `reminderPlanLine` now ends `, {time}` in all three languages. `planLine` takes `clock`, and `reminderPlanText` passes `context.clockTime` to it (`reminder_control.dart:~100`). A test covers the 12-hour clock in English.
- **UX-1804 · fixed.**
  - «próximo» now comes from `ReminderPlans.alerts(..., late: false)`, and a done task gets no «próximo» (`reminder_plan_words.dart:110-120`).
  - `_alertPassed` treats a plan as passed when `taskAlerts(late: false)` is empty (`reminder_control.dart:62-73`).
  - The chip and the form row then show `noReminderTimePassed` with the off bell. ReminderControl now draws the off bell too.
  - `ReminderEngine.alertAhead` is unchanged, as the brief asked.
- **UX-1910 · fixed.** `reminderPlanCount` reads «N avisos · próximo: …» and «1 aviso: …» in es, ca and en, with no «el». Seen in renders sheet.strength, sheet.your-way and your-way-free-dictated: «13 avisos · próximo: mañana, 09:00» and «13 avisos · proper: demà, 09:00».

### P243
- **UX-1801 · fixed.** In `reminder_plan_sheet.dart:459-461` and the rows block:
  - `dictated` / `yourWay` draw «A tu manera» for a free account whose task has a custom plan: selected, ✓ when closed and the expander when open, its rhythm as the subtitle, and no ProBadge.
  - The free account's section is PlanPreview plus `_Apply`, with no field and no «Dictarlo».
  - A free account with no custom plan keeps the badge and `_openPro`.
  - Render sheet.your-way-free-dictated.es.light.2x shows the row selected and open, the preview, «13 avisos · próximo: mañana, 09:00» and Listo.
- **UX-1810 · fixed.** A post-frame callback in `initState` calls `Scrollable.ensureVisible` on the GlobalKey of the chosen plan's row («Hasta la fecha límite» or «A tu manera»). The duration is `Duration.zero` when animations are off. The free-dictated 2× render opens with the plan's section in view.
- **UX-1904 · fixed.** `plans = current != null || daysUntil(_anchor, now) >= 2` gates the divider and both plan rows with their sections. Render sheet.tomorrow.es.light.1x shows the title and the single rows only.
- **UX-1907 · fixed (in code and AUDIT; what TalkBack says needs a device check).**
  - `expandable()` wraps each expandable row in `Semantics(expanded, hint, onTapHint)`.
  - The strip's «Hoy» and the day under it now sit inside the ExcludeSemantics.
  - In AUDIT for sheet · strength, TalkBack reads «Hasta la fecha límite» with hint «Desplegado» [expanded] and «A tu manera» with hint «Contraído» [collapsed], and the strip's ends are gone from its list.
  - Device check: on Android, TalkBack also announces the expanded state itself, so check that the hint isn't read twice («desplegado … desplegado»).

### P245
- **UX-1905 · fixed (a real microphone needs a device check).** `_reveal()` (`keepVisibleAtEnd`, with `Duration.zero` when animations are off) runs when listening starts, on each partial in `_hear`, and in `_read`'s `finally`.
  - Render sheet.your-way-listening-long.es.light.2x shows «Dejar de escuchar» and «Escuchando» in view.
  - Render sheet.your-way.es.light.2x shows Listo in view.
  - Neither the test nor the preview scrolls to Listo.
- **UX-1906 · fixed.** `_unsentProvider` now keeps `(words, plan)`.
  - `dispose` keeps them unless a choice was applied (`_chosen`, set by `_choose`) or they are the plan's own `said`.
  - On reopening, `_kept` sets `_open`, `_words`, `_custom` and `_readWords`, so no second request is sent.
  - Only Pro accounts and saved tasks keep anything.
- **UX-1908 · fixed.**
  - The helper is now the example, in es, en and ca.
  - `reminderPlanUnclear` is shortened as briefed.
  - `_unclear` makes «Dictarlo» clear the field when it still holds the misunderstood words.
  - The helper is now hidden once a plan has been read. The brief didn't ask for this. I don't count it as a regression: the preview takes its place.
- **UX-1909 · fixed.** `app_ca.arb` uses «Fins al termini» in `reminderPlanUntilDay`, `reminderPlanOffline` and `reminderPlanFailed`. «data límit» appears nowhere in app_ca.arb any more.

### Regressions
None caused by these packages.

### Notes for the organizer (not counted as regressions)
- **The chip says «Sin recordatorio» before a final notice.** On the task's day, once the plan's time has gone by, the chip reads «Sin recordatorio: ya ha pasado la hora del aviso». The engine still sends one last notice the day after («Era para ayer»), because `alertAhead` was deliberately left unchanged. P241 settled this on purpose. If anyone finds it confusing, raise it with D1/D2 rather than reopen UX-1804.
- **A problem that was already there: «A tu manera»'s field hides the newest words.** While the phone listens, the field is unfocused and capped at 4 lines. Long words show their beginning, not the newest words. Render sheet.your-way-listening-long.es.light.2x ends at «…luego cada día, y el», and the heard «último día por la mañana y por la tarde» is out of sight. This change didn't cause it: `maxLines: 4` and the unfocus both predate it. It works against lens J («shows live words»). It's worth a new ledger entry, either in the next review or by the organizer.
- **Kept words win over a strength.** A Pro account with kept words whose task now has a strength opens on «A tu manera», while «Hasta la fecha límite» carries the ✓. This is the brief's rule («kept words win»). It's rare, and I'm noting it only.
