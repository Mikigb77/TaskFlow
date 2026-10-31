## UX review — B · Calendar, home and tasks: reminder plans on a task (run 2026-10-22-changes) — 2026-10-22

**Verdict:** Ship after fixes. Choosing a strength takes 3 taps and shows what it gives before it's applied. But:
- a free account's own dictated plan shows as a locked Pro option, with nothing chosen;
- the task's plan line never says it's about reminders, or which strength was chosen;
- the line promises a next reminder on a completed task.

**Evidence:**
- **Renders:** the 24 renders in `App/build/ux/reminders/`, plus `tasks/detail.*` and `form/edit-task.*`. All were rendered 2026-10-22 12:10–12:14 from `aa2f53a`. `find App/lib App/assets -newer <png>` lists nothing, so they are current.
- **AUDIT.md:** the `reminders/*` sections. This is widget-test evidence.
- **Device captures:** none cover this change. `device/INDEX.md` is from 2026-10-21, with no rows dated 2026-10-22, so the captures aren't evidence here.
- **Judged from code:** states with no render. These are:
  - the sheet with no plan, for Pro;
  - «A tu manera» offline, unclear or failed;
  - a done task, a task due today and an overdue task;
  - the form's plan line.
- **GUIDELINES.md:** present and used.

**Walked:** the Newcomer (free, Spanish, 1× and 2×), the Daily user (Pro) and a TalkBack user, through these flows:
1. **Set a plan:** task detail → reminder chip → «Hasta la fecha límite» → (Normal is chosen) → Listo → the chip's line. 3 taps from the detail, 4 from Calendario.
2. **Change the strength:** chip (the sheet opens on the current strength) → Intenso → Listo. 3 taps. The line reads the same before and after (UX-1902).
3. **Back to one reminder, or none:** chip → a single-reminder row. 2 taps.
4. **«A tu manera», Pro:**
   - typed: chip → row → field → type → keyboard ✓ → Listo. 4 taps plus typing;
   - said: chip → row → Dictarlo → (the microphone question, once) → Dejar de escuchar → Listo. 4–5 taps.
5. **Free account:** chip → «A tu manera · Pro» → Pro screen → Back. 3 taps.
6. **Free account with a rhythm said while dictating:** chip → a sheet with nothing chosen (UX-1901).
7. **Task form, new or edit:** Más detalles → Recordatorio → sheet → plan → Listo → Guardar. That's 4 taps more than a plain save. With Más detalles closed, the plan shows as one grey line.
8. **Moving a task with a plan** (Cambiar fecha, a swipe, or editing the day): the plan follows the day, and the line updates in place. Taking the day away hides the plan; giving a day back brings it back.
9. **Completar on the detail, then Deshacer:** the engine cancels the reminders and brings them back. The line keeps saying «próximo: …» throughout (UX-1903).
10. **«A tu manera»** offline, unclear and failed, at 1× and 2×, and listening at 2×.

**Numbers:**
- **Rows in the reminder sheet** of a dated task that doesn't repeat:
  - date-only: 3 → 5 (2 → 4 without an all-day reminder time, as in the renders);
  - timed: 6 → 8.

  Opening a strength adds 4 targets: 3 chips and Listo.
- **Words at the sheet's first decision** (Spanish, date-only, sheet closed): 6 before this change → ≈ 23. With a strength open: ≈ 36.
- **Taps:** set a plan, 3; change its strength, 3; remove it, 2.
- **Notices per strength:**

  | Task's day | Suave | Normal | Intenso |
  |---|---|---|---|
  | 3 weeks away | 7 | 13 | 18 |
  | 6 months away | 30 | 66 | 98 |

### Findings (most severe first)

**UX-1901 · Severity 3 · A free account's own dictated plan shows locked, unselected**
- **Where:**
  - `App/lib/widgets/reminder_plan_sheet.dart:464-478`: the «A tu manera» row, whose section is drawn only `if (pro …)` (`:478`);
  - `:425`: the strength row isn't selected for a custom plan;
  - `App/lib/widgets/reminder_control.dart:331`: `current: null` while a plan is active.

  The sheet is reached from the task detail's chip, and from the capture card through `editTaskReminder`. State: a free account, and a task with a `custom` plan read from a dictation. Owner decision 2026-10-22: a rhythm said while dictating is honoured for free accounts.
- **The moment:** "Dije «recuérdamelo cada 3 días» y la tarea lo pone. Aquí no hay nada marcado… ¿y para eso necesito Pro?"
- **What happens:**
  - No row carries a ✓:
    - the single-reminder rows get `current: null`;
    - «Hasta la fecha límite» isn't selected;
    - «A tu manera» shows the Pro badge, unselected, and tapping it opens the Pro screen.
  - The plan's words, dots and count show nowhere.
  - Choosing a strength (and Listo), or any single row, silently replaces the plan the person said.
- **Why it fails:**
  - Nielsen's visibility of system status;
  - SC-9: the chip on the task says one thing, the sheet another;
  - SU-6, interface interference: a paywall over something the person already has (Gray 2018; Mathur 2019).
- **Fix:** when the current plan is `custom` and the account isn't Pro:
  - draw «A tu manera» as the chosen row: its ✓, its rhythm as the subtitle («Cada 3 días, y a diario la última semana»), and no Pro badge;
  - tapping it shows that plan's preview (words, dots, count), read-only: no field, no «Dictarlo», no Listo;
  - choosing a strength or a single row still replaces it.

  No new copy.
- **Verify:**
  - In `App/test/reminder_plan_sheet_test.dart`, with a free account and a task carrying `ownersPlan`:
    - «A tu manera» is selected and shows its words;
    - no `ProBadge`, and no other row selected;
    - tapping it shows `reminder-plan-preview` and no `reminder-plan-words`.
  - Add the preview `reminders/sheet.your-way-free-dictated.es.light.1x`.
- **Evidence:** verified in code; no render of this state.

**UX-1902 · Severity 2 · The plan line doesn't say it's reminders, or which ones**
- **Where:**
  - `App/lib/widgets/reminder_control.dart:494-546`: the chip skips `reminderValue` for a plan;
  - `:81-92`: `reminderPlanText`;
  - `App/lib/l10n/reminder_plan_words.dart:55-64`: `planSummary`;
  - `App/lib/widgets/task_editor.dart:942-951`: the form with Más detalles closed;
  - `App/lib/l10n/app_es.arb:1377`.

  Surfaces: the task detail and the task form.
- **The moment:** "«Cada vez más a menudo hasta el jue 12»… ¿qué viene más a menudo?" Then, after switching from Normal to Intenso: "¿Se ha guardado? Pone lo mismo."
- **What happens:**
  - **Every other chip state starts with the word:** «Recordatorio: 09:00», «Sin recordatorio · Activar», «Sin recordatorio: ya ha pasado la hora del aviso».
  - **The plan line doesn't:** it starts «Cada vez más a menudo…» or «Cada 3 días…». Only a 16 dp bell says it's about reminders, and the bell doesn't grow with the text.
  - **TalkBack** reads «Cada vez más a menudo hasta el jue 12 · próximo: mañana», button (AUDIT, `reminders/task-line · strength`, item 11).
  - **The three strengths read the same.** Suave, Normal and Intenso all read «Cada vez más a menudo hasta el jue 12», so changing the strength changes nothing on the task.
  - **The form shows the same unlabelled text,** as a second grey line under «Prioridad Alta».
- **Why it fails:**
  - SC-1, front-load each line (Nielsen 1997; Pernice 2017);
  - SC-9 and WCAG 3.2.4: the same thing, the same word;
  - SC-6 and OL-4: words with icons (Harley 2014; Kobayashi 2011; Leung 2011);
  - no feedback after a change: a gulf of evaluation (Norman 2013).
- **Fix:** start the line with the word, and name the chosen strength. The existing today and tomorrow forms stay («… hasta hoy», «… hasta mañana»).

  | | A strength | A plan of the person's own words |
  |---|---|---|
  | ES | «Recordatorios suaves / normales / intensos hasta el jue 12 · próximo: mañana» | «Recordatorios: cada 3 días, y a diario la última semana · próximo: mañana» |
  | EN | «Gentle / Normal / Intense reminders until Thu 12 · next: tomorrow» | «Reminders: every 3 days, and daily for the last week · next: tomorrow» |
  | CA | «Recordatoris suaus / normals / intensos fins al dj. 12 · proper: demà» | «Recordatoris: cada 3 dies, i cada dia l’última setmana · proper: demà» |

  - The rhythm is lowercase after the colon.
  - Use this line on the chip, on the form's closed-details line and on the capture card.
  - Leave out the form's Recordatorio row: its title already says it.
  - The person version keeps its own prefix, with the rhythm lowercase: «Recordatorio para Ana: cada 3 días…».
  - The sheet row's subtitle «Cada vez más a menudo hasta el jue 12» stays as it is.
- **Verify:**
  - The `reminders/task-line.*` renders, and the form with a plan, read «Recordatorios normales hasta…».
  - AUDIT's TalkBack line for the chip starts with «Recordatorios».
  - A widget test switches Normal → Intenso and expects the chip's text to change.
- **Evidence:**
  - seen in current renders (`reminders/task-line.strength.es.light.1x.png`, `.es.light.2x`, `.ca.light.2x`, `task-line.own-words.*`) and in AUDIT;
  - verified in code for the form.

**UX-1903 · Severity 2 · The line promises a next reminder that won't come**
- **Where:**
  - `App/lib/l10n/reminder_plan_words.dart:84`: `planLine` takes «próximo» from `ReminderPlans.alerts(...)`, which includes the last notice and ignores completion;
  - `App/lib/widgets/reminder_control.dart:81-92`;
  - `App/lib/screens/task_detail_screen.dart:369-399`: the chip also shows on done tasks;
  - `:487-500`: Completar keeps the screen open.

  Reached on the detail after Completar, from «Tareas completadas», and on the task's own day.
- **The moment:** "La he completado y aún pone «próximo: mañana». ¿Me va a seguir avisando?" On the day itself, after 9:00: "Es para hoy, ¿por qué el próximo es mañana?"
- **What happens:**
  - **After Completar on the detail:** the screen stays open with «TAREA COMPLETADA» and «Reabrir», and the chip still reads «… · próximo: mañana». Yet the engine has cancelled every reminder: `ReminderPlans.taskAlerts` returns none for a done task.
  - **On the task's own day, after the plan's time:** the line reads «Cada vez más a menudo hasta hoy · próximo: mañana». It counts the conditional «Era para ayer» notice. For the same plan, the sheet's count says «Ya no quedan avisos», because `planCount` uses `late: false` (`:105`).
- **Why it fails:**
  - UN-2 and Nielsen's visibility of system status: the screen contradicts what just happened;
  - SC-9: the sheet and the line disagree;
  - recurring problem 21: text built for one moment, read at another.
- **Fix:**
  - Build the line's «próximo» from `ReminderPlans.taskAlerts(task, …, late: false)`. It returns nothing for a done task and leaves out the conditional last notice, as the count does.
  - A done task, or a plan with nothing ahead, then reads just the plan: «Recordatorios normales hasta el jue 12».

  No new copy.
- **Verify:** widget tests:
  - a task with Normal, completed on the detail: the chip has no «próximo»;
  - the clock on the task's day at 10:00: no «próximo: mañana», and the sheet's count and the chip agree.
- **Evidence:** verified in code; no render of these states.

**UX-1904 · Severity 2 · Plans are offered for tasks due today, tomorrow or overdue**
- **Where:**
  - `App/lib/services/reminder_plans.dart:33-34`: `plannable` accepts any anchor, past or present;
  - `App/lib/widgets/reminder_control.dart:318`.

  The sheet of a task due today, tomorrow or earlier — for example the task in `tasks/detail.alert-passed.*`.
- **The moment:** "Es para hoy a las 5. ¿«Hasta la fecha límite»? ¿Eso qué me da?"
- **What happens:**
  - **Every dated task that doesn't repeat gets the two plan rows:** 2 more options in every sheet (date-only 3 → 5, timed 6 → 8).
  - **A task due today, after 9:00:**
    - the row promises «Cada vez más a menudo hasta hoy», and the open preview says «Ya no quedan avisos»;
    - Listo still applies it;
    - choices are exclusive, so this drops the task's «10 minutos antes» in exchange for one «Era para ayer» notice tomorrow.
  - **An overdue task:** offers «Cada vez más a menudo hasta el mié, 11 nov», a day that's already gone.
  - **A task due tomorrow:** a plan gives at most two 9:00 notices.
- **Why it fails:**
  - TA-11: about 80% of 576,080 assistant reminders were due within a day (Graus 2016), so the extra rows sit on the most common case, where they do least;
  - CO-2 and CO-9 (Hick 1952; Cockburn 2007; Thompson 2005);
  - CO-7, progressive disclosure (Nielsen 2006).
- **Fix:**
  - Show «Hasta la fecha límite» and «A tu manera» only when the anchor is 2 or more days away, or when the task already has a plan, so it can still be changed or removed.
  - Tasks due today, tomorrow or earlier get the single-reminder list exactly as before (`_pickFrom`).

  This removes 2 rows from the common case. No new copy.
- **Verify:** widget tests:
  - anchor today, tomorrow and yesterday: no `reminder-plan-until-day`;
  - anchor in 2 days: present;
  - a task due tomorrow that already has a plan: present, and selected.
- **Evidence:** verified in code; no render of the sheet on a near or overdue task.

**UX-1905 · Severity 2 · «A tu manera» at 2×: stop and Listo end up off-screen**
- **Where:**
  - `App/lib/widgets/reminder_plan_sheet.dart:314-338`: `_hear` fills the field and reveals nothing;
  - `:201-268`: `_read`, which reveals nothing either;
  - `:505-536`: the «Dictarlo / Dejar de escuchar» row, under the field.

  `_toggle`, by contrast, does reveal the section (`:169-187`). State: Pro, 2× text, a 360 dp phone.
- **The moment:** "Estoy hablando y el botón ha desaparecido. ¿Cómo paro?" Then: "Se ha puesto gris un momento… ¿y ahora qué?"
- **What happens:**
  - **While listening:**
    - the field grows to 4 lines as words arrive;
    - the field isn't focused, so nothing scrolls, and «Dejar de escuchar» and «Escuchando» move below the fold;
    - in `reminders/sheet.your-way-listening.es.light.2x.png` the field fills the bottom of the screen and neither shows;
    - the only way out left is the 30-second cap.
  - **After the words are read:**
    - the plan sentence and the dots appear at the bottom edge;
    - the count and «Listo» land roughly 30–170 dp below a 776 dp viewport. That's an estimate from the 2× render's layout, with the field ending just above where the keyboard was.
  - **The tests don't show it:** the preview (`App/test/ux_previews/reminders_previews.dart:163`) and the 2× widget test (`App/test/reminder_plan_sheet_test.dart:548`) scroll to «Listo» themselves.
- **Why it fails:**
  - VO-1 and OL-4: listening must be unmistakable, in words (Yankelovich 1995; Kobayashi 2011);
  - VO-2: only the person ends listening;
  - SC-5: the action that completes the task in view at 2×;
  - recurring problem 25.
- **Fix:** reveal the end of the «A tu manera» section, with the same `Scrollable.ensureVisible(…, keepVisibleAtEnd)` call `_toggle` uses:
  - after each update of the field while listening;
  - after a read.

  Jump without animation when `MediaQuery.disableAnimationsOf` is set. No new controls.
- **Verify:**
  - Remove the tests' own scrolling after the read (`reminder_plan_sheet_test.dart:548`, `reminders_previews.dart:163`), and expect `reminder-plan-apply` to be hit-testable.
  - Add a 2× listening preview: with 4 lines of words in, «Dejar de escuchar» is hit-testable.
- **Evidence:**
  - the listening part: seen in a current render;
  - the part after reading: inferred from the code and the 2× layout.

**UX-1906 · Severity 2 · Words already read are thrown away when the sheet closes**
- **Where:**
  - `App/lib/widgets/reminder_plan_sheet.dart:141-150`: `dispose` keeps only words not yet read;
  - `:96-98`.

  State: Pro, «A tu manera», after the words were read, with the sheet closed without Listo (Back, a swipe, or a tap above the sheet).
- **The moment:** "Lo escribí, vi los puntos, cerré sin querer… y al volver el cuadro está vacío."
- **What happens:**
  - Words not yet read are kept for each task.
  - Words already read are dropped (`_unsent.remove`), together with the plan read from them.
  - Reopening shows an empty field, and getting the plan back costs another AI call.
  - Combined with UX-1905, «Listo» may not even be in view at 2× when people leave.
- **Why it fails:**
  - UN-9, never lose input (COGA 2021; WCAG 2.2.6);
  - ON-10, make safety visible (Leung 2012).
- **Fix:**
  - Keep the words, and the plan read from them, until a choice is applied, whether they were read or not.
  - Reopening then shows the words with their preview and Listo, with no new request.
  - Drop them only when a choice is applied.
- **Verify:** a widget test: type → read → Back → reopen. The field holds the words, `reminder-plan-preview` shows, and the API got one request.
- **Evidence:** verified in code.

**UX-1907 · Severity 2 · TalkBack isn't told the plan rows expand**
- **Where:**
  - `App/lib/widgets/reminder_plan_sheet.dart:412-430` and `:464-477`: ListTiles whose only sign of expanding is the chevron;
  - `:648-670`: «Hoy» and the task's day under the dots.
- **The moment** (with TalkBack): "«Hasta la fecha límite, botón». Lo toco… y no dice nada."
- **What happens:**
  - AUDIT (`reminders/sheet · strength`) reads «button «Hasta la fecha límite» → tap» and «button «A tu manera» → tap», with no expanded or collapsed state and no hint.
  - After a tap, chips and a button appear below without being announced; only the count's live region may speak.
  - «Hoy» and «jue 12» are read as two loose texts between the plan sentence and the count, which already says the same in words.
- **Why it fails:**
  - AC-6: name, role and value (WCAG 4.1.2);
  - AC-7: announce what changes;
  - Flutter's own ExpansionTile gives its header the expanded and collapsed hints these rows lack.
- **Fix:**
  - Give both rows their expanded state (`Semantics(expanded: …)`, with `MaterialLocalizations`' `expandedHint`/`collapsedHint`), as ExpansionTile's header does.
  - Exclude «Hoy» and the day under the dots from semantics, inside the dots' `ExcludeSemantics`.

  Nothing changes on screen.
- **Verify:** AUDIT's TalkBack lines read both rows with their state, and no longer list «Hoy» and «jue 12».
- **Evidence:** from AUDIT (widget-test semantics) and the code; not checked with TalkBack on a device.

**UX-1908 · Severity 2 · «A tu manera» shows no example until it fails**
- **Where:**
  - `App/lib/l10n/app_es.arb:1365` (`reminderPlanYourWayHint`) and `:1370` (`reminderPlanUnclear`);
  - `App/lib/widgets/reminder_plan_sheet.dart:297-298`: `_prefix`, so «Dictarlo» appends;
  - `:497-500`.
- **The moment:** "«Como se lo dirías a alguien»… ¿y qué le digo?" After «No lo he entendido»: "Lo digo otra vez… y se pega a lo de antes."
- **What happens:**
  - The empty field's only help is «Escríbelo o dilo como se lo dirías a alguien.»
  - The first example appears only in the failure message.
  - After «No lo he entendido. Dilo de otra forma…», «Dictarlo» adds the new words after the misunderstood ones, and sends both.
- **Why it fails:**
  - VO-4: show what to say on the first screen (Yankelovich 1995; Myers 2018);
  - VO-6: re-speaking on top of an error compounds it (Suhm 2001);
  - CO-5.
- **Fix:**
  - **Replace the helper with an example** of a shape the strengths can't give:
    - ES «Por ejemplo: «una semana antes y el día antes a las 8».»;
    - EN «For example: “a week before, and the day before at 8”.»;
    - CA «Per exemple: «una setmana abans i el dia abans a les 8».»
  - **Shorten the unclear message:**
    - ES «No lo he entendido. Prueba a decirlo de otra forma.»;
    - EN «I didn’t get that. Try saying it another way.»;
    - CA «No ho he entès. Prova de dir-ho d’una altra manera.»
  - **After an unclear read,** «Dictarlo» starts from an empty field.
- **Verify:**
  - The preview `reminders/sheet.your-way` with an empty field shows the example.
  - A widget test: unclear → «Dictarlo» → the segment «cada día» → the field reads «cada día».
- **Evidence:** seen in a current render (`reminders/sheet.your-way.es.light.1x.png`); verified in code.

**UX-1909 · Severity 1 · Only here does the Catalan app call the deadline «data límit»**
- **Where:**
  - `App/lib/l10n/app_ca.arb:1064`: `reminderPlanUntilDay`, «Fins a la data límit»;
  - `:1075` and `:1076`.

  Everywhere else the Catalan word is «Termini» (`:59`): the detail's row, «Treu el termini», «Termini vençut», and the notifications' «Termini: …».
- **The moment:** "A la tasca diu «Termini»; aquí, «data límit». És el mateix?"
- **What happens:** the Catalan sheet names the deadline differently from every other Catalan screen.
- **Why it fails:** SC-9, one name per concept in each language (WCAG 3.2.4; COGA 2021).
- **Fix:** Catalan:
  - «Fins al termini»;
  - «Ara no ho he pogut llegir. Torna-ho a provar més tard, o tria «Fins al termini».»;
  - «Això necessita connexió. «Fins al termini» funciona sense.»

  If the owner renames the row (question B-Q1), Catalan follows that instead.
- **Verify:** `reminders/sheet.strength.ca.light.2x` and `sheet.your-way-free.ca.light.2x` read «Fins al termini».
- **Evidence:** seen in current renders.

**UX-1910 · Severity 1 · «el próximo mañana» reads as one phrase**
- **Where:** `App/lib/l10n/app_es.arb:1375` (`reminderPlanCount`), `app_ca.arb:1079` and `app_en.arb:3461`. This is the count in the sheet's preview.
- **The moment:** "«13 avisos · el próximo mañana, 09:00»… ¿el próximo qué?"
- **What happens:**
  - The count runs «el próximo» into the day: «el próximo mañana», «el próximo hoy», Catalan «el proper demà».
  - The task's line writes the same thing as «próximo: mañana».
- **Why it fails:** plain language (ISO 24495-1); SC-9: the same "next" written two ways.
- **Fix:** write it as the task's line does. Dates keep their form, «sáb 25».

  | | Several notices | One notice |
  |---|---|---|
  | ES | «13 avisos · próximo: mañana, 09:00» | «1 aviso: mañana, 09:00» |
  | CA | «13 avisos · proper: demà, 09:00» | «1 avís: demà, 09:00» |
  | EN | «13 reminders · next: tomorrow, 09:00» | «1 reminder: tomorrow, 09:00» |
- **Verify:** the `reminders/sheet.strength.*` renders.
- **Evidence:** seen in current renders.

### Keep
- **The preview before applying.** The plan in words, the dots to the day, «N avisos» and the next one show what the system understood, before one tap applies it (Budiu & Laubheimer 2018).
- **One-tap single reminders.** Those rows still apply in one tap, and the choices are visibly exclusive: one ✓ at a time.
- **Offline.** The strengths work without a connection. When «A tu manera» is offline or fails, it keeps the words and points to «Hasta la fecha límite» (UN-7).
- **Voice.** The microphone is asked for at «Dictarlo», live words fill the field, and typing stays available if the microphone is refused (ON-5, VO-3, VO-16).
- **TalkBack.** The count is a live region, and the strip of dots is hidden from TalkBack.

### Progress against UX_REVIEW.md (U1–U14)
- No U item is advanced or regressed by area B's part of this change.
- U10 is still open: Calendario and Tareas are untouched. The two extra rows land in a sheet, not on home (see UX-1904).

### Questions for the owner (product decisions only)
- **B-Q1 — «Hasta la fecha límite» on tasks that only have a day.**
  - Most tasks only have a day; the owner said so himself: "the deadline … will be the same as the task".
  - Everywhere else in the app, «Fecha límite» names a separate field: the detail's «Fecha límite» row, «Quitar fecha límite», and the notifications' «Fecha límite: …».
  - So on a day-only task the row names something the task doesn't have. Its subtitle («Cada vez más a menudo hasta el jue 12») is what tells people what it does (SC-1, SC-9).
  - **Recommendation:** make the subtitle the row's title: «Cada vez más a menudo», with «hasta el jue 12» under it, for a deadline and a day alike. The error copy then says «o elige «Cada vez más a menudo»».
  - **Alternative:** keep «Hasta la fecha límite» on tasks with a deadline, and say «Hasta el día» on the others.
- **B-Q2 — A timed task loses its reminder just before the moment.**
  - With a plan, a timed task loses its single reminder: `Backend/docs/REMINDER_PLANS.md` makes the choices exclusive.
  - Every notice of the plan, including the day's own, rings at the all-day reminder time, 9:00 by default.
  - Example: «Dentista» at 8:30, three weeks away, with Normal. It gets 13 notices at 9:00, the last one 30 minutes *after* the appointment, and none before it. Today it would get one at 8:20.
  - The sheet doesn't say that «10 minutos antes» goes away (TA-5, TA-12).
  - **Recommendation:** on the task's own day, a timed task's notice rings at its own reminder — its lead, 10 minutes before by default — rather than at the plan's time. Other days keep the plan's time. No new control.
- **B-Q3 — Tasks far away get dozens of notices.**
  - The strengths start "from now on" (366 days), so the count grows with distance:

    | Task's day | Suave | Normal | Intenso |
    |---|---|---|---|
    | 6 months away | 30 | 66 | 98 |
    | A year away | — | ≈ 127 | — |

  - The offer's «Sí» sets Normal for any task 14 or more days away, without showing that count.
  - Every notification costs attention (NO-5; Stothart 2015; Pielot 2018).
  - **Recommendation:** start each strength at most 6 weeks before the day.
    - Normal then gives at most 20 notices, Suave 10 and Intenso 29.
    - The owner's 3-week example is unchanged (13).

### Cross-slice notes
- **A — the capture card.**
  - Its plan row uses the same `reminderPlanText`, so the fixes for UX-1902 and UX-1903 reach it too.
  - A free account opening that row meets UX-1901.
- **D — the offer.**
  - Its «Sí» names no result (UN-4); the first reminder question uses «Sí, recuérdamelo».
  - It sets Normal in one tap without showing how many notices that means (see B-Q3).
- **D — privacy.** If a Pro account first uses the microphone in «A tu manera», it never sees capture's one-time privacy line (`_showPrivacyOnce`). The words still fit `capturePrivacy`'s «… cambiar tareas …».

### Memory notes
- **The plan sheet** (`widgets/reminder_plan_sheet.dart`):
  - single-reminder rows apply on a tap;
  - «Hasta la fecha límite» and «A tu manera» expand in place, with a chevron, and apply with «Listo»;
  - the preview is the rhythm sentence, a strip of dots (hidden from TalkBack) and a count in a live region;
  - `ProBadge` marks Pro choices for free accounts.
- **«Listo»** is the app's standard label for applying a sheet: the schedule editor, the repeat sheet and the plan sheet all use it. Don't flag it.
- **One line, three surfaces.** `reminderPlanText` → `planLine` feeds the detail's chip, the form's closed-details line and the capture card. Unlike every other chip state, it has no «Recordatorio» prefix (pending UX-1902).
- **Plan rules:**
  - the anchor is the deadline, otherwise the day;
  - a plan is exclusive with the single reminder;
  - every notice, the day's own included, rings at the plan's time or the all-day time (9:00 by default);
  - no plans on repeating tasks, notes, or tasks with no day.
- **Area B map additions:**
  - the detail's reminder chip shows the plan line below the notes;
  - the TaskEditor shows a plan line under Más detalles' summary;
  - the ReminderControl row opens the plan sheet only when `onChanged` is passed.
- **Recurring-problem candidates:**
  - content that grows inside a scrolled sheet (live words, an async result) isn't brought into view. `_toggle` reveals it; `_hear` and `_read` don't. This generalises #25.
  - text derived from a model ignores the task's state: `planLine` uses `alerts`, not `taskAlerts`, so a done task still promises «próximo».
- **Review technique:** tests and previews that call `ensureVisible` themselves before shooting hide reveal bugs. When a render shows a reveal, read the test that drove it.
