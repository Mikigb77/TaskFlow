## UX review — Area A: voice capture, reminder plans in the capture flow (aa2f53a) — 2026-10-22

**Verdict:** Ship after fixes. Plain dictations read exactly as before, and the owner's own sentence becomes one task with one readable reminder line in 3 taps. Before shipping, fix four things around that line and the save after it:
- a free account that dictated a rhythm can't find it in the sheet, where the matching choice shows «Pro» (UX-1801);
- the line promises «próximo: mañana» when this phone won't ring (UX-1802);
- the offer's «Sí» silently replaces a reminder the person just said (UX-1803);
- a plan that's already past still reads as if a reminder were coming, and the task's usual alert is gone (UX-1804).

One rule needs the owner: a plan replaces a timed task's usual alert before its time (Q1).

**Walked** (newcomer: Spanish, 2× text, one hand; daily user; TalkBack user, from AUDIT.md):
- **The owner's sentence, Pro, reminders on:** «Presentar el proyecto de empresa en tres semanas, recuérdamelo cada 3 días las dos primeras semanas y luego cada día».
  - Añadir tarea → speak → Listo → the card: title, «jue, 12 de nov», 🔔 «Cada 3 días, y a diario la última semana · próximo: mañana» → «Añadir al calendario» → Calendar on 12 Nov, row lit, «Añadida al jue, 12 de nov · Deshacer». No offer, since it has a plan.
  - 3 taps. Render `reminders/capture-card.plan` (es 1×, 2×; ca 2×).
- **Same, new account** (reminders off, never asked): after the message, «¿Quieres un recordatorio antes?» → «Sí, recuérdamelo» → Android's prompt. 5 taps. From the code.
- **Same, reminders declined earlier, or notifications blocked:** nothing is asked, and the plan never rings (UX-1802). From the code.
- **Same, free account, tapping the line to check it:** the sheet has nothing ticked, and «A tu manera · Pro» opens the Pro screen (UX-1801). From the code.
- **A single reminder said:** «Dentista el 12 de noviembre a las 5, avísame una hora antes» → «Más opciones» reads «Recordatorio: 1 hora antes» → save → the offer → «Sí» (UX-1803). From the code.
- **Changing the reminder from the card:** line → sheet → «Elegir hora del aviso», «predeterminado» or «1 hora antes» → the line goes (UX-1805). From the code.
- **Several tasks, a reminder for one:** «Comprar pan mañana y presentar el proyecto el 12 de noviembre, recuérdamelo cada semana» → two collapsed rows, no reminder shown (UX-1809). Without the reminder, the far task gets an offer that doesn't name it while Calendar shows tomorrow (UX-1808). From the code and render `capture/result.several`.
- **A reminder already past:** «Dentista el martes a las 10, recuérdamelo una semana antes», said on Thursday (UX-1804). From the code.
- **Day cleared or repeat added on the card after a plan:** the line goes, but the plan is saved (UX-1811). From the code.
- **Plain dictation, no reminder said:** reads as before, with no new row and nothing new in «Más opciones» (`capture_review_editor.dart:494-505`, `:658`; render `capture/result.one-task`, 12:11). A far plain task gets the offer (D's sheet).
- **Interruptions:** a resumed capture («Sin guardar») and Deshacer after saving bring the plan back, because it's stored with the draft's task (`capture_session.dart:153-186`). Back or the scrim on the reminder sheet leaves the card as it was.

**Numbers:**
- **Taps for the owner's sentence:** 3, as for any one-task dictation (+2 on a new account: the question and Android's prompt). Before this change, a said rhythm was dropped.
- **Tap targets on a one-task result:** 7 plain (unchanged) → 8 with a said plan (AUDIT, `capture/result · one-task` and `reminders/capture-card · plan`).
- **Words on the line:** 11 (es), none of them «recordatorio», and no time.
- **Changing a said reminder on the card:** a plan takes 2 taps (line, choice); a said single reminder takes 3 taps and a scroll («Más opciones», «Recordatorio», choice) → 2 after UX-1805.
- **Free account checking its dictated rhythm:** none of the sheet's rows is ticked; the one that matches opens the Pro screen.
- **Offer after a two-task dictation:** the question names 0 tasks, and the task it means is off screen (Calendar lands on the earliest day).

**How I looked:**
- `.claude/ux-review/GUIDELINES.md` is present, and I reviewed against it.
- **Renders:** `App/build/ux/reminders/*` (the card line, the offer, the sheet states reached from the line) and `capture/result.one-task`, `result.several`, `result.several-open`, rendered 12:10–12:14 from aa2f53a with no uncommitted app changes. `find App/lib App/assets -newer <png>` lists nothing, so they're current. I read AUDIT.md with them.
- **Device captures:** `App/build/ux/device/INDEX.md` has no rows from this commit yet, and the lane doesn't set plans, so none apply.
- **No render, so judged from the widget code and the tests:** a free account with a dictated plan in the sheet; reminders off on the card; a said single reminder; changing the reminder from the card; collapsed rows with a plan; the offer after a several-task dictation; the sheet opened from the line on a timed task at 2×; plans with nothing left before their day. Each finding says which.

### Findings (most severe first)

**UX-1801 · Severity 3 · Free accounts: a dictated rhythm hides behind a Pro badge**
- **Where:**
  - `App/lib/widgets/reminder_plan_sheet.dart:87-91`: a custom plan opens the sheet on «A tu manera»;
  - `:464-478`: without Pro, that row is never selected or ticked, shows `ProBadge`, opens `_openPro`, and its section (the words, the preview, «Listo») isn't built;
  - `:397-410`: no single row is ticked while a plan is set;
  - reached from the card's line, `App/lib/widgets/capture_review_editor.dart:664-665` → `editTaskReminder` (`App/lib/widgets/reminder_control.dart:373-403`).
- **The moment:** «Me lo ha entendido, lo pone en la tarjeta… pero aquí no está, y "A tu manera" dice Pro. ¿Tengo que pagar por lo que he dicho?»
- **What happens:**
  - The owner decided that a rhythm said while dictating is honored for free accounts (DECISIONS, 2026-10-22), and the card shows it.
  - Tapping the line opens the sheet with nothing ticked: no single row, not «Hasta la fecha límite», and «A tu manera» shows «Pro» where a tick would be. The rhythm and the words said appear nowhere.
  - The one row that matches opens the Pro screen, headed «Con Pro, tus recordatorios a tu manera».
  - Choosing anything else replaces the dictated plan for good: without Pro, the only way back is dictating the task again.
- **Why it fails:**
  - gulf of evaluation (Norman 2013);
  - VO-5: show what was understood (Budiu & Laubheimer 2018);
  - SU-2 and SU-6: a Pro badge on something the person already has for free is interface interference (Gray 2018; Di Geronimo 2020); SU-8 asks for exactly this walk as the newcomer.
- **Fix:**
  - When the task's plan is a custom one, show «A tu manera» to everyone as a strength is shown: ticked, with its rhythm as the subtitle, opening to the same preview (the words, the dots, «13 avisos · el próximo …») and «Listo».
  - Without Pro, leave out the text field and «Dictarlo» (they call the assistant), and put no badge on that row.
  - The badge and the Pro screen stay for accounts whose task has no custom plan.
  - No new copy.
- **Verify:**
  - Widget test in the «the capture’s card» group of `App/test/reminder_plan_sheet_test.dart`, with `pro: false`: the line opens a sheet where «A tu manera» is selected and shows «Cada 3 días, y a diario la última semana», with no `ProBadge` in that row and no `reminder-plan-words` field. Back keeps the plan.
  - The existing free test (`:266`) still finds the badge on a task with no plan.
  - Preview `reminders/capture-card.plan-free` (es 1×, 2×).
- **Evidence:** verified in code. The free render (`reminders/sheet.your-way-free`, 12:13) shows the badge on a task with no plan; the dictated-plan state isn't rendered.

**UX-1802 · Severity 3 · The card promises reminders this phone won't give**
- **Where:**
  - `App/lib/widgets/capture_review_editor.dart:658-667` (the plan row) and `:499-504` (a said single reminder in «Más opciones»' subtitle): neither checks whether reminders can ring on this phone;
  - compare the chip, `App/lib/widgets/reminder_control.dart:474-483` and `:536-537` («Sin recordatorio · Activar»), and the form's control, `:709-714` («Activar recordatorios»);
  - after saving, the question is skipped once it was asked: `App/lib/widgets/reminder_ask_sheet.dart:124-126`.
- **The moment:** «Le dije que me lo recordara cada 3 días y ponía "próximo: mañana". No me ha avisado nunca.»
- **What happens:**
  - Reminders are off by default, per account and phone (`ReminderPreferences.enabled = false`). With them off, or with notifications blocked, the card still reads «Cada 3 días, y a diario la última semana · próximo: mañana», or «Recordatorio: 1 hora antes».
  - A new account is asked once, after saving. An account that answered «Ahora no» before, or a phone that blocks notifications, is asked nothing: the plan is saved and never rings.
  - The task's own page then reads «Sin recordatorio · Activar» (tested at `reminder_plan_sheet_test.dart:587`), so the card and the task disagree.
- **Why it fails:**
  - TA-6: reminders fire on time, or the app says why not, where reminders are set (Android Alarms; Wilson 2001);
  - visibility of system status (Nielsen 1994);
  - recurring problem: a reminder line promising what can't come (UX-209, UX-1505, UX-1601).
- **Fix:**
  - On the card, when this phone won't ring (reminders off here, or notifications not allowed: `_cannotFire` with `planned`), keep the line's words and add the existing «Activar recordatorios» button under it, running `turnOnReminders`, as the form's reminder control does.
  - Copy exists: «Activar recordatorios» / "Enable reminders" / «Activa els recordatoris».
  - For this task it replaces the question after saving, since turning reminders on records that they were asked.
  - UX-1805's fix brings this with it: the reminder control already does it.
- **Verify:**
  - Widget test: a capture card with a plan and `ReminderPreferences(asked: true)` (off) shows the plan and «Activar recordatorios»; tapping it asks for the permission, and the button goes once reminders are on.
  - The same with notifications blocked. With reminders on and allowed, there's no button.
  - Preview `reminders/capture-card.plan-reminders-off` (es 2×).
- **Evidence:** verified in code.

**UX-1803 · Severity 3 · The offer's «Sí» replaces the reminder just said**
- **Where:**
  - `App/lib/models/capture_session.dart:88-90`: the minutes said go on the task;
  - `App/lib/services/reminder_plans.dart:105-110`: `offerable` skips only a reminder turned off;
  - `App/lib/widgets/reminder_ask_sheet.dart:192-201` and `:236-243`: «Sí» sets Normal;
  - `App/lib/services/reminder_engine.dart:287`: a plan replaces the single reminder.
- **The moment:** «Le dije "avísame una hora antes". Luego me preguntó si me lo recordaba hasta entonces, le dije que sí… y a las cuatro no sonó nada.»
- **What happens:**
  - «Dentista el 12 de noviembre a las 5, avísame una hora antes» → the card shows «Recordatorio: 1 hora antes» → saved.
  - When the save message goes: «Faltan 3 semanas: ¿te lo recuerdo hasta entonces?». The filled «Sí» sets Normal, which replaces the single reminder: notices at 9:00 on the way and on the day, nothing at 16:00.
  - The confirmation «Listo. Te lo recordaré hasta el jue 12.» doesn't say the hour-before reminder is gone.
- **Why it fails:**
  - the daily user should never answer the same question twice;
  - error prevention (Nielsen 1994);
  - UN-9: never lose input (COGA 2021);
  - recurring problem 11: the app acts silently.
- **Fix:** don't offer a plan for a task with a reminder of its own. `offerable` also requires `reminderMinutes == null && reminderTime == null` (the default), next to the existing `!= -1`. One interruption fewer, and the said reminder stays.
- **Verify:**
  - Widget test: a dictation with `'reminder_minutes': 60` on a timed task three weeks away, reminders on → save → after the message, no offer. The task keeps 60 and has no plan.
  - «after a dictation is added, a far task with no plan gets the offer» (`reminder_plan_sheet_test.dart:768`) still passes.
- **Evidence:** verified in code.

**UX-1804 · Severity 3 · A plan already past promises «próximo» after the day**
- **Where:**
  - `App/lib/l10n/reminder_plan_words.dart:84-91`: «próximo» counts the last notice, the day after;
  - `App/lib/services/reminder_plans.dart:64-81`;
  - `App/lib/widgets/reminder_control.dart:64-76`: a plan is never «passed» while that last notice is still to come;
  - `App/lib/services/reminder_engine.dart:255-262` and `:287`.
- **The moment:** «Le dije que me lo recordara una semana antes. Ponía "próximo: mié 28"… y la cita era el martes.»
- **What happens:**
  - Said on Thursday 22: «Dentista el martes a las 10, recuérdamelo una semana antes». The week-before reminder (Tuesday 20) is already past.
  - The card reads «Una semana antes · próximo: mié 28». That "next" is the late notice, «Era para ayer», the day after the appointment.
  - Once saved, the plan replaces the usual alert before 10:00, so nothing rings before the dentist.
  - Likewise «recuérdamelo cada día» for a timed task today after 9:00 reads «A diario · próximo: mañana», and nothing rings today.
- **Why it fails:**
  - VO-5 and VO-9: show the interpretation, and uncertainty as a question (Budiu & Laubheimer 2018);
  - recurring problems 19 (a past time saved silently) and 21 (copy computed for another moment).
- **Fix:**
  - Count only reminders on or before the task's day as "ahead".
  - When none is left, the line says what a passed single reminder already says: «Sin recordatorio: ya ha pasado la hora del aviso» / "No reminder: the alert time has passed" / «Sense recordatori: l’hora de l’avís ja ha passat» (existing `noReminderTimePassed`). Tapping it opens the sheet, to choose another.
  - Whether such a task should keep its usual alert is Q1.
- **Verify:** widget test with the clock at Thursday 22 Oct, 09:41: a draft for Tuesday 27 Oct at 10:00 with the plan `{7,7,1}` → the line reads the passed text, not «próximo: mié 28»; tap → the sheet; «10 minutos antes» → the line shows it.
- **Evidence:** verified in code, worked through `alerts` and `planLine`; no render.

**UX-1805 · Severity 2 · Said reminders have two homes; the line vanishes when changed**
- **Where:**
  - `App/lib/widgets/capture_review_editor.dart:658-667`: a plan gets its own row;
  - `:494-505`: minutes said («una hora antes») go into «Más opciones»' subtitle, and only on a task with a time;
  - `:758-786`: the same reminder again, inside «Más opciones»;
  - `App/lib/widgets/reminder_control.dart:352-367`: choosing a single reminder clears the plan.
- **The moment:** «He tocado la línea de los recordatorios, he elegido las 18:00… y la línea ha desaparecido. ¿Se ha guardado?»
- **What happens:**
  - A plan said gets a row with a bell; «una hora antes» said ends up as grey text under «Más opciones». One thing, two forms, two places.
  - From the plan's row, choosing «Elegir hora del aviso» (a task with a day only), «predeterminado» or «Desactivado» removes the row, and nothing on the card shows the choice. «1 hora antes» (a task with a time) reappears further down, as «Más opciones»' subtitle. The line just tapped is gone.
  - Changing a said single reminder takes «Más opciones», a scroll to its sixth item, «Recordatorio», then a choice: 3 taps and a scroll, against 2 taps for a plan.
  - With «Más opciones» open and a plan set, the plan shows twice: the row, and «Recordatorio / Cada 3 días…» inside.
- **Why it fails:**
  - SC-9: one thing, one name, one place (WCAG 3.2.4; COGA 2021);
  - SC-10: a change outside the focus is missed (Rensink, O'Regan & Clark 1997);
  - recurring problem 8: duplicates.
- **Fix:**
  - One reminder row. When the dictation set a reminder (a plan, or minutes, including «Desactivado» when the words turned it off), or once the person changed it on the card, show the card's existing `ReminderControl` above «Más opciones», instead of the bespoke row and the subtitle entry. It has the title «Recordatorio», the plan's line or «1 hora antes» as its value, and the same sheet. The contract's «one line» stays one row.
  - Once shown, it stays for the card, as the notes field does (`_notesOpen`), and reads whatever is chosen («10 minutos antes · predeterminado», «18:00», «Desactivado»).
  - While it shows above, «Más opciones» doesn't build a second one, as it already does for notes and the project.
  - It brings UX-1802's «Activar recordatorios» and UX-1806's name with it. No new copy.
- **Verify:**
  - Widget tests: a draft with `reminder_minutes: 60` shows «Recordatorio / 1 hora antes» above «Más opciones», and nothing in its subtitle.
  - From a plan, «Elegir hora del aviso» → 18:00 keeps the row, reading 18:00.
  - «Más opciones» opened with a plan has no second reminder row.
  - A plain draft shows no reminder row (render `capture/result.one-task` unchanged).
  - Taps to change a said single reminder: 3 and a scroll → 2.
- **Evidence:** verified in code; the render shows only the plan state.

**UX-1806 · Severity 2 · The line never says it's about reminders**
- **Where:**
  - `App/lib/widgets/capture_review_editor.dart:660-666`: `_row` gives the line no name;
  - AUDIT, `reminders/capture-card · plan`: TalkBack reads button «Cada 3 días, y a diario la última semana · próximo: mañana»;
  - `App/lib/l10n/app_es.arb:320` (`repeatEvery`, «Cada {interval} días»), `:1378` and `:1392`.
- **The moment:** «"Cada 3 días"… ¿se repite cada 3 días? ¿Próximo qué?»
- **What happens:**
  - The line starts with the app's own words for a repeat: «Cada 3 días» is exactly what this card shows for a task that repeats every 3 days (the repeat chip). Only the bell tells them apart, and «próximo:» has no noun.
  - TalkBack has no bell: «Cada 3 días, y a diario la última semana · próximo: mañana, botón». The date line above it is named («Fecha y hora: jue, 12 de nov», since UX-458); this one isn't.
  - If the assistant took «recuérdamelo cada 3 días» as a repeat, or «riega las plantas cada 3 días» as reminders, the card would read the same either way. That's the mix-up the owner ruled out: reminders "never as copies of the task".
- **Why it fails:**
  - AC-6: name, role and value (WCAG 4.1.2);
  - SC-9: different concepts, different names (ISO 24495-1);
  - SC-6: icons need words (Harley 2014);
  - VO-5.
- **Fix:**
  - It comes with UX-1805: the row's title «Recordatorio» / "Reminder" / «Recordatori» names it, and TalkBack reads «Recordatorio, Cada 3 días…».
  - If UX-1805 isn't taken: give the row the semantics label «Recordatorio: …» (existing `reminderValue`) and show «Recordatorio» as its title.
- **Verify:** AUDIT for `reminders/capture-card · plan` reads «Recordatorio» with the plan, and the render shows the word above the line.
- **Evidence:** seen in a current render and in AUDIT.md (12:13).

**UX-1807 · Severity 2 · The line doesn't say when the reminders ring**
- **Where:**
  - `App/lib/l10n/reminder_plan_words.dart:68-92`: `planLine` has no time;
  - `reminderPlanLine`: `App/lib/l10n/app_es.arb:1392`, `app_ca.arb:1096`, `app_en.arb:3625`;
  - the sheet's count already gives it (`reminderPlanCount`, `app_es.arb:1375`: «el próximo mañana, 09:00»).
- **The moment:** «"Recuérdamelo el día antes a las 8"… pone "El día antes · próximo: mié 11". ¿A las 8 o a las 9?»
- **What happens:**
  - The card shows the rhythm and the next day, never the time.
  - A time said («a las 8») can't be checked.
  - A plan with no time said rings at Settings' time for tasks without a time (9:00), even for a 17:00 appointment, and nothing on the card says so.
- **Why it fails:** VO-5: show what and when (Budiu & Laubheimer 2018; Luger 2016); TA-4: the time is part of "when".
- **Fix:**
  - Add the time to the next reminder: «{plan} · próximo: {when}, {time}» → «Cada 3 días, y a diario la última semana · próximo: mañana, 09:00»; EN «{plan} · next: {when}, {time}»; CA «{plan} · proper: {when}, {time}».
  - Format `time` with `context.clockTime`, as `reminderPlanCount` does, so the 12/24-hour setting holds.
  - It's the same line on the task's page (D).
- **Verify:**
  - The card test for `ownersPlan` reads «… · próximo: sáb 24, 09:00»; with a 12-hour clock, "9:00 AM".
  - Spanish and Catalan at 2× wrap without cutting the time (preview `reminders/capture-card.plan`, re-rendered).
- **Evidence:** verified in code and in the current render, which has no time.

**UX-1808 · Severity 2 · After a dictation, the offer doesn't say which task**
- **Where:**
  - `App/lib/widgets/reminder_ask_sheet.dart:192-201`: the first far task is offered;
  - `:255-289`: `_PlanOfferSheet` says only «Faltan 3 semanas: …»;
  - `App/lib/screens/voice_task_screen.dart:3178-3233`: Calendar lands on the earliest saved day.
- **The moment:** «"¿Te lo recuerdo hasta entonces?"… ¿El qué? ¿Lo del pan?»
- **What happens:**
  - «Comprar pan mañana y presentar el proyecto el 12 de noviembre» → «2 tareas añadidas · también el jue, 12 de nov» → Calendar on tomorrow, the bread lit.
  - When the message goes, the sheet asks «Faltan 3 semanas: ¿te lo recuerdo hasta entonces?». The task it means isn't on screen and isn't named, and «lo» could be the bread in view.
  - With one task at 2×, the sheet covers the lit row too (render `reminders/offer.asked.es.light.2x`).
- **Why it fails:** CO-3: nothing to remember (Cowan 2001); recognition over recall (Nielsen 1994).
- **Fix:** name the task. Put its title on the sheet's first line (titleMedium, wrapping, read with the heading), then the question, unchanged. The title is data, so there's no new string.
- **Verify:**
  - Widget test: the two-task dictation above, reminders on → after the message, the offer shows «Presentar el proyecto» above «Faltan 3 semanas: …».
  - Preview `reminders/offer.asked`, re-rendered (es 1×, 2×; ca 2×).
- **Evidence:** verified in code; the current render names no task.

**UX-1809 · Severity 2 · Several tasks: a said reminder isn't shown**
- **Where:** `App/lib/widgets/capture_review_editor.dart:803-815`: a collapsed row shows its title, date line, ✕ and open questions.
- **The moment:** «Dije que lo del proyecto me lo recordara cada semana… aquí no sale. ¿Lo ha oído?»
- **What happens:** in a result of several tasks, each row shows its title and date. A rhythm said for one of them shows only once that row is opened, and «Añadir 2 tareas» saves without it ever having appeared.
- **Why it fails:** VO-5 (show the interpretation) and VO-7 (one row per task, with what belongs to it) (Budiu & Laubheimer 2018); gulf of evaluation.
- **Fix:** in a collapsed row whose dictation set a reminder, show the reminder line under the date line, in the collapsed date line's small style (bodyMedium, an 18 dp bell). Rows with no reminder said stay as they are.
- **Verify:** widget test: in a three-task result where one draft has a plan, that collapsed row shows «Cada semana · próximo: …» and the others don't. Render `capture/result.several` unchanged.
- **Evidence:** verified in code; render `capture/result.several` (12:11) shows the collapsed layout.

**UX-1810 · Severity 2 · Tapping the line opens the sheet with the plan unseen**
- **Where:** `App/lib/widgets/reminder_plan_sheet.dart:87-91` opens the plan's section, but `:169-187` scrolls a section into view only when it's toggled, never on opening.
- **The moment:** «Toco "cada 3 días"… y salen "10 minutos antes, 30 minutos antes, 1 hora antes"… ninguna marcada. ¿Dónde está lo mío?»
- **What happens:** for a task with a time, the sheet lists six single-reminder rows first, none ticked while a plan is set. At 2× on 360 dp they fill the screen, and «Hasta la fecha límite» and «A tu manera», with the person's words, start below it.
- **Why it fails:** SC-5: what the user came for shows without scrolling (Fessenden 2018); recurring problem 25: name what must be visible, and reveal that.
- **Fix:** when the sheet opens on a plan, bring that plan's row to the top of the sheet after the first frame (`Scrollable.ensureVisible` on the row, alignment 0, with no animation when animations are off): the ticked row, then its chips or words. The same holds from the task's page (D).
- **Verify:** widget test at 2× on 360 dp: a timed draft with a custom plan, opened from the card, shows «A tu manera» at the top with the words; with Normal, «Hasta la fecha límite» and its chips show.
- **Evidence:** inferred from the code and the rows' heights; no render of this opening.

**UX-1811 · Severity 1 · A plan hidden by «Sin fecha» or a repeat is saved**
- **Where:**
  - `App/lib/widgets/capture_review_editor.dart:128-141`: clearing the day clears the repeat, not the plan;
  - `App/lib/services/capture_store.dart:223-237`: the task is saved as it is;
  - compare the form, `App/lib/widgets/task_editor.dart:426-431`, which drops a plan that doesn't apply.
- **The moment, later:** «Esta tarea no tenía recordatorios… ¿por qué me avisa cada 3 días?»
- **What happens:** after a plan is read, «Sin fecha» or a repeat on the card makes the line disappear, but the plan is saved with the task. Giving the task a day later (Cambiar fecha, or by voice) turns the plan back on, unseen.
- **Why it fails:** recurring problem 11, the app acts without the user; SC-9, the form does the opposite.
- **Fix:** at save, drop a plan the task can't keep (`!ReminderPlans.plannable(task)`), as the form does. With UX-1805's row, clearing the day reads «Añade una fecha para usar un recordatorio» there (existing `dateForReminder`) instead of the line vanishing.
- **Verify:** widget test: a draft with a plan → «Sin fecha» → save → the saved task has no plan.
- **Evidence:** verified in code.

### Keep
- The date stays the result's main line, with the reminder under it like the other details (render `reminders/capture-card.plan`, 1× and 2×). U4 holds.
- Plain dictations are unchanged: no reminder row, nothing new under «Más opciones», 7 tap targets (render `capture/result.one-task`).
- A said reminder survives everything capture already protects: the journal, «Sin guardar» and Deshacer.
- The offer waits for the save message, never covers a screen or tab opened meanwhile, and so doesn't interrupt a second dictation started right away (`reminder_ask_sheet.dart:96-111`).
- Minutes said («una hora antes») are kept only for a task with a time (`capture_session.dart:105-108`), so no lead is set with nothing to count from. The Voz privacy line («Para añadir, buscar o cambiar tareas…») still covers «A tu manera», whose words change a task.

### Progress against UX_REVIEW.md (U1–U14)
- **U4 holds:** the plan line sits under the date, which stays the largest line.
- **U5 holds:** the landing is unchanged, and the offer comes only after the save message.
- **U12 holds for new accounts:** the question after the first dated save still turns reminders on. Accounts that declined it get nothing when they dictate a reminder (UX-1802).
- **U3, a tension, not a finding:** the reminder sheet's «Dictarlo» (Pro) is a second microphone reachable from the result. It follows the owner's «typed or said» decision; watch it in the §7 test.
- **U7:** «Guardar como tarea» keeps «recuérdamelo cada 3 días…» in the title and sets no reminder, because the phone's parser doesn't read reminders. Expected.
- **Untouched:** U1, U2, U6, U8–U11, U13, U14.

### Questions for the owner
**Q1. A plan replaces a timed task's usual alert before its time.**
- **Evidence:**
  - The contract says «A plan replaces the single reminder» (`Backend/docs/REMINDER_PLANS.md`), and the engine does so (`reminder_engine.dart:287`). A plan's notices ring at its own time, or at Settings' time for tasks without a time (9:00).
  - So «Dentista el 12 a las 17:00, recuérdamelo cada semana» rings at 9:00 on the way and on the day, but never at 16:50.
  - «Sí» on the offer does the same to any far task with a time. UX-1803 is the case where the person had even said the hour; with UX-1804's past plan, nothing rings at all.
- **Options:**
  - (a) as built;
  - (b) on the task's own day, a timed task's plan notice rings at its usual lead before the time instead of at the plan's time;
  - (c) keep the single reminder alongside the plan.
- **Recommendation: (b).** One notice on the day, at the moment it's useful, and nothing extra. The lead before a timed task is the default people keep (TA-5; Haraty 2016), and reminders on the days before plus the day did better than one (TA-12; Steiner 2018). Reversible.

**Q2. A reminder said that a plan can't keep is dropped without a word.**
- **Evidence:**
  - With no day or deadline, the server sets neither key (contract, «The dictation»).
  - «Una hora antes» on a task with no time is dropped (`capture_session.dart:88-90`), and a repeating task gets no plan.
  - So «Llamar a mamá, recuérdamelo cada día» saves with no reminder, and nothing on the card says so.
- **Recommendation:** the server flags a reminder it heard but couldn't keep, and the card shows one line under the date, which opens the date sheet: «Para recordártelo, ponle un día.» / "To remind you, give it a day." (needs Catalan translation). Or accept it as is until the §7 test. It adds a server field and a card state, so it's your call.

### Cross-slice notes
- **D:** the offer's «Sí» doesn't name its outcome (PL-5, UN-4), while the reminder question says «Sí, recuérdamelo».
- **D:** UX-1801's sheet state is also what a free account sees from the task's page after saving its dictation.
- **D:** UX-1810 applies from the task page's reminder chip too.
- **D/B:** UX-1804's «próximo: <the day after>» and UX-1806's missing «Recordatorio» show on the task's chip as well.
- **B:** one plan line has three looks: a row on the card, a chip on the task's page, plain grey text with no tap in the form (`task_editor.dart:942-951`).
- **D:** the reminder sheet has no visible close; leaving without a change takes the scrim, the drag handle or Back (PL-4, OL-5; Harada 2013).
- **D:** «Hasta la fecha límite» is the owner's label, but on a task with only a day the card shows no deadline; watch it in the §7 test.

### Phone checks (device only)
- TalkBack on the card's reminder row and on the offer.
- The notification permission asked from the card (UX-1802's fix), over the capture sheet, on Android 13+.
- Plan notifications themselves: the emulator lane doesn't set plans.
- The owner's sentence and «avísame una hora antes» said aloud on a phone.

### Memory notes
- **Screen map A, new section «Reminder plans on the result card» (aa2f53a, 2026-10-22):**
  - a plan read from the dictation is a bell row under the date line that opens `editTaskReminder` → `showReminderPlanSheet` (`capture_review_editor.dart:658-667`);
  - a said lead («una hora antes», only on tasks with a time) shows as «Recordatorio: …» in «Más opciones»' subtitle (`:494-505`); «Más opciones» also holds the `ReminderControl`, which shows the plan again;
  - the collapsed rows of a several-task result show neither;
  - drafts take `reminderPlan` and `reminderMinutes` from `TaskDraft` (`capture_session.dart:83-108`), and plans are stored with the draft (resume, Deshacer);
  - after saving, `askAboutRemindersAfterSave` gets the saved tasks with their ids. With reminders off, it asks the one-time question as before. With them on, it offers a plan («Faltan N semanas…», «Sí» = Normal) for the first task at least 14 days away with no plan, a reminder not turned off, the person's own, and a phone that allows notifications, once per task (`reminder_ask_sheet.dart:176-253`);
  - free accounts get dictated rhythms as custom plans; the sheet hides «A tu manera»'s section from them and shows a Pro badge that opens `/subscription` with `ProReason.reminderPlans`;
  - previews: `App/build/ux/reminders/capture-card.plan` (es 1×, 2×; ca 2×) and `offer.asked`.
- **Plan rules to check against:**
  - `ReminderPlans.active` holds only for a task with a day or a deadline that isn't repeating or a note;
  - a plan replaces the single reminder in the engine (`reminder_engine.dart:287`);
  - the line's «próximo» counts the last notice, the day after;
  - the form drops a plan that doesn't apply when saving (`task_editor.dart:426-431`); capture doesn't.
- **UI pattern on the result card:** a detail shown above «Más opciones» leaves it (notes, project, steps), and once shown it stays for the card (`_notesOpen`).
- **New recurring types:**
  - a choice that removes the row it was made from (the reminder line vanishes when changed to a single reminder or the default);
  - a "next" that counts an after-the-day notice reads as a reminder before the day;
  - a feature honored for free (dictated rhythms) shown only through a Pro-gated control.
- **Doc vs decision:** the plan line's words in `Backend/docs/REMINDER_PLANS.md` («Cada 3 días… · próximo: sáb 25») and the offer's bare «Sí» are the main session's spec. The owner's decisions are DECISIONS.md, 2026-10-22: the anchor, the three strengths, dictated rhythms free, «A tu manera» for Pro, the offer, one last notice.
