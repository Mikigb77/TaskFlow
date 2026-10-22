## UX review — D · Reminders, notifications and Pro (reminder plans: notices, the offer, the Pro reason line, Recordatorios) — 2026-10-22

**Verdict:** Ship after fixes. The offer is well guarded and the notices are wired correctly, but one «Sí» to "more reminders" silently removes the reminder before a timed task's time (UX-2001). The offer also asks for 13 or more notices without saying which task they're for or how often (UX-2002), and on a shared task it sets them for every member (UX-2003).

**Scope and evidence.**
- **Code:** `git diff refs/ux-review/last` (6a39595..aa2f53a) of `services/notification_service.dart`, `services/reminder_copy.dart`, `services/reminder_engine.dart`, `services/reminder_plans.dart`, `l10n/reminder_plan_words.dart`, `widgets/reminder_ask_sheet.dart`, `screens/subscription_screen.dart`, `main.dart` and the 44 ARB keys. I read `notification_settings_screen.dart` and `settings_screen.dart` in full; they're unchanged, but plans change what they mean.
- **Renders:** `App/build/ux/reminders/offer.asked.*`, `sheet.pro-screen.*`, `sheet.your-way-free.*`, `sheet.strength.*` and `task-line.*`, plus `settings/reminders.*` and `settings/settings-tab.*`. All were rendered at 12:13–12:14 from aa2f53a, and `find -newer` lists no app file changed since. AUDIT.md was read for the same renders.
- **Device:** no capture from today's commit was in `App/build/ux/device/` when I looked. The newest rows are from 2026-10-21, commit 3a35a0d. I used `notification.shade`/`group-open` only to show how Android lays out several TaskFlow notifications. Plan notices are never captured. GUIDELINES.md was present and used.

**Walked:**
1. **Typed save of a task 3 weeks away, reminders on.** Guardar, the save message for 4 s or more, the offer, «Sí», then «Listo…». That's 2 taps. Personas: Newcomer (ES, 2×), Daily user (two far tasks in a row), TalkBack.
2. **One dictation, two tasks** (tomorrow, and in 3 weeks). Añadir tarea, speak, Listo, Añadir. The view lands on tomorrow, and the offer is about the task that's out of view.
3. **A dictated «…y recuérdamelo una hora antes»** for a far timed task. The card shows «Recordatorio: 1 hora antes», then the save, then the offer.
4. **A far task in a shared project** («Todos», the default), then the offer, then «Sí», then what the other members' phones do.
5. **Three weeks of notices.** Tapping one, Completar then Deshacer, Posponer 10 min, never clearing the shade, the day itself for a timed task, and the day after.
6. **Free user.** Task, reminder line, «A tu manera · Pro», the Pro screen, Back: 3 taps.
7. **Ajustes › Recordatorios with plans:** both rows, «Tareas sin hora» off, Detalles.
8. **Offer suppressed or not** (code): reminders off (the first question is unchanged), notifications blocked, someone else's task, reminder off, repeating task, note, a project muted on this phone, an edit save.

**Numbers:**
- **Notices after «Sí»:** Normal at 3 weeks gives 13, plus the conditional last one. At 8 weeks it's 24 + 1; at 6 months, 66 + 1. Intenso at 3 weeks gives 18 + 1, and Suave 7 + 1. I worked these out from `ReminderPlan.strengthPhases`; the 3-week Normal count matches the render's «13 avisos».
- **The offer:** 3 tap targets (Cerrar, Sí, Ahora no), 1 decision, 8 words (ES) → about 20 with the task line and the rhythm (UX-2002).
- **Taps to a plan:** 1 from the offer, 4 from Calendar through the task.
- **Actions on a plan notice:** 2 → 1 (UX-2009).
- **Pro screen from the badge:** one line more (7 words ES). Tap targets unchanged at 3.

### Findings (most severe first)

**UX-2001 · Severity 4 · «Sí» to more reminders drops the one before the time**
- **Where:**
  - `App/lib/services/reminder_engine.dart:284-296`: a task with a plan gets no single reminder.
  - `App/lib/services/reminder_plans.dart:41-42` and `:53-59`: every plan notice rings at `plan.time ?? dateOnlyTime ?? 540` on its day, whatever the task's own time.
  - `App/lib/widgets/reminder_ask_sheet.dart:236-243`: the offer's «Sí» sets Normal with no time.
  - State: a timed task 14 or more days away, with reminders on.
- **The moment:** «Le dije que sí para que me avisara más… y el día del análisis no me avisó antes de las 8.»
- **What happens:**
  - Take «Análisis de sangre», jue 12 nov at 8:00, with Ajustes reading «Tareas con hora · 10 minutos antes». The person answers «Sí» to the offer.
  - The 7:50 reminder is gone. On the day, the only notice is «Es hoy» at 9:00, an hour after the appointment.
  - A 17:00 presentation gets «Es hoy» at 9:00 and nothing at 16:50.
  - Nothing tells the person:
    - the offer shows no time;
    - the sheet's preview shows «09:00» but not that the «10 minutos antes» reminder goes away;
    - Recordatorios still promises «10 minutos antes».
  - No test covers a timed task with a strength. The engine tests' tasks are date-only (`App/test/reminder_plan_engine_test.dart:81`).
- **Why it fails:**
  - TA-6: reminders fire on time, or the app says why not (Wilson 2001: timed reminders are what help).
  - TA-7: a reminder carries the "when".
  - Norman's gulf of evaluation: the loss can't be seen.
  - Recurring problem: a rule that removes something creates silent wrong results.
- **Fix:**
  - On the anchor's day, a timed anchor (a task with a time, or a deadline with a time) rings at its usual reminder time: its own lead (`reminderMinutes`), else Ajustes' «Tareas con hora». It uses the single reminder's text, «Hoy a las 17:00 · en 10 min», instead of the all-day time.
  - Earlier days keep the all-day time. The number of notices doesn't change, and «Tareas con hora» reads true again.
  - This touches `Backend/docs/REMINDER_PLANS.md` («`time` … null: the reminder time for all-day tasks»; «A plan replaces the single reminder»). The main session updates the contract.
  - If the organizer treats this as a product change, it's D4 below, with this as the recommendation.
- **Verify:**
  - Engine test, Normal plan:
    - a task at 17:00 on 12 Nov rings on 12 Nov at 16:50 with «Hoy a las 17:00 · en 10 min», and there's no 9:00 «Es hoy»;
    - at 08:00 it rings at 07:50;
    - with a 60-minute lead it rings at 16:00;
    - a date-only task is unchanged («Es hoy» at 9:00).
  - Preview `reminders/sheet.strength` on a timed task: the count shows the day's time.
- **Evidence:** verified in code. Notifications aren't rendered (INDEX, «Not covered»).

**UX-2002 · Severity 3 · The offer names no task, no rhythm; «Sí» says nothing**
- **Where:**
  - `App/lib/widgets/reminder_ask_sheet.dart:255-288` (`_PlanOfferSheet`) and `App/lib/l10n/reminder_plan_words.dart:131-133`.
  - ARB `reminderPlanOfferWeeks`/`Months`/`Yes`: es:1398-1400, ca:1102-1104, en:3665-3683.
  - Render: `reminders/offer.asked.*`.
- **The moment:** «¿Recordarme qué? ¿Cuántas veces?» After a two-task dictation: «¿Cuál de las dos?»
- **What happens:**
  - The sheet says «Faltan 3 semanas: ¿te lo recuerdo hasta entonces?», with «Sí» and «Ahora no». It names no task, no day and no rhythm.
  - It appears only once the save message has gone: 4 s, or up to 2 min with Android's "time to take action". At 2× it covers half the screen.
  - After a dictation of several tasks, Calendar lands on the earliest day (`App/lib/screens/voice_task_screen.dart:3216-3231`), so «lo» refers to a task out of view. In the render, the sheet sits over today's agenda, whose first row, «Llamar al médico para pedir cita», reads as that «lo».
  - «Sí» means 13 notices at 3 weeks, 24 at 8 weeks, 66 at 6 months.
  - TalkBack reads «Sí, botón» (AUDIT).
  - The first reminder question uses «Sí, recuérdamelo»; this one doesn't.
- **Why it fails:**
  - CO-3 (Cowan 2001): nothing to remember.
  - UN-4: buttons name outcomes; no Yes/No.
  - SC-9: the same action keeps the same word.
  - ON-8 (Kendrick 2018): say what will arrive.
  - Plain language (ISO 24495-1).
- **Fix:** keep the step and the two choices; take away the guesswork.
  - **First line:** the task and its day, in `bodyMedium` and `onSurfaceVariant`, at most 2 lines: «Análisis de sangre · jue, 12 nov». For a deadline anchor: «… · Fecha límite: jue, 12 nov».
  - **The question names the rhythm,** built from the sheet's own words (`planRhythm`, not capitalised):

    | | Question |
    |---|---|
    | ES | «Faltan 3 semanas. ¿Te aviso cada 3 días, y a diario la última semana?» |
    | CA | «Falten 3 setmanes. T’aviso cada 3 dies, i cada dia l’última setmana?» |
    | EN | "3 weeks to go. Shall I remind you every 3 days, and daily the last week?" |

  - **«Sí»** reuses `reminderAskYes`: «Sí, recuérdamelo» / «Sí, recorda-m’ho» / "Yes, remind me". «Ahora no» stays.
- **Verify:**
  - Render `reminders/offer.asked` at ES/CA 2× on 360 and 320 dp: the task line, the question and both buttons are in view without scrolling (SC-5). If not, use `titleMedium` for the question.
  - Test: a dictation with one task tomorrow and one in 3 weeks; the offer names the far task.
  - AUDIT: TalkBack reads the task line, then the question, then «Sí, recuérdamelo».
- **Evidence:** seen in a current render (`offer.asked` es 1×/2×, ca 2×) and verified in code.

**UX-2003 · Severity 3 · One «Sí» on a shared task rings every member's phone**
- **Where:**
  - `App/lib/widgets/reminder_ask_sheet.dart:192-201`: the filter is only `task.isForAccount(me)`.
  - `App/lib/models/task.dart:66-70`: `group` counts as the person's own.
  - `App/lib/widgets/task_assignment_picker.dart:13`: new tasks in a shared project default to `group` («Todos»).
  - `App/lib/services/task_database.dart:404-425`: `reminderBlock`, which the offer doesn't consult.
- **The moment:** Ana, a member: «¿Por qué me avisa cada tres días del cumpleaños de la abuela? Yo no he pedido nada.»
- **What happens:**
  - A far task saved into a shared project is «Todos» by default, so the offer comes.
  - «Sí» writes the plan into the task. It syncs ("a task field, synced like the others"), and every member's phone schedules it, because «Todos» tasks ring for all.
  - Each member gets about 13 notices they never chose, with nothing saying who set them. Their only ways out are muting the whole project, or changing the reminder, which also removes María's plan.
  - The same filter offers a plan for a task in a project this phone has muted. «Sí» then promises notices this phone never rings (`reminderTasks` drops muted projects), which is the broken promise UX-1601 removed from the first question.
- **Why it fails:**
  - SH-4 (Brush 2001; Pielot 2018): don't notify other people; say who did what.
  - NO-5 (Stothart 2015; Kushlev 2016): notify only for what the person asked for.
  - UX-1601's rule: ask only when a reminder can ring here.
- **Fix:**
  - Offer only for tasks that ring on this phone alone:
    - the engine's own rule, `TaskDatabase.reminderBlock(...) == null` (muted, archived, not this account);
    - and an assignment that is `personal`, or `member` assigned to this account;
    - never `group`.
  - No new copy.
  - The sheet still lets anyone put a plan on a shared task; that's D3.
- **Verify:**
  - Tests: a task 3 weeks away in a shared project, «Todos», gets no offer; assigned to me, it does; a personal task in a muted project gets no offer.
  - Phone, two accounts: the second member receives no plan notices after the first saves a far shared task.
- **Evidence:** verified in code. The offer render uses a personal task.

**UX-2004 · Severity 2 · Old plan notices pile up with stale counts**
- **Where:**
  - `App/lib/services/reminder_engine.dart:449-468`: a plan notice that has fired stays "still relevant" (`elapsed`) and is never cancelled.
  - `:162-192`: each plan day has its own identity and notification id.
- **The moment:** a week later, pulling down the shade: «¿Faltan 20, 17 o 14 días?»
- **What happens:**
  - Every plan notice is a separate notification that stays until it's swiped away. A Normal plan leaves «Faltan 20 días», «Faltan 17 días», «Faltan 14 días»…, each true only on its own day.
  - In the last week one more arrives every day; Intenso adds one a day for 14 days.
  - Android bundles 4 or more into one TaskFlow group (emulator capture `notification.group-open`, older commit). There, the plan's lines push real «Hoy a las 17:00 · en 10 min» reminders down.
  - The Newcomer doesn't swipe notifications away.
- **Why it fails:**
  - NO-6 (Android Notif group; Kendrick 2018): update one notification rather than posting many.
  - Recurring problem 21: text written for one moment is read at another.
  - NO-5.
- **Fix:**
  - One notice per task's plan in the shade. When a plan notice fires, the refresh a minute later (the `wake` reconcile) cancels that task's earlier plan notices: rows that are `elapsed` with an older `fire_at`.
  - Completing the task already clears them all. No new copy.
- **Verify:**
  - Engine test with the fake driver: after the 24 Oct notice fires and the 27 Oct 9:01 refresh runs, the 24 Oct id is cancelled and only the 27 Oct notice remains.
  - Device check: a «cada día» plan over 3 days without opening the shade shows one TaskFlow line for the task.
- **Evidence:** verified in code. Android's grouping is seen in an emulator capture of an older commit; no plan notice has been captured.

**UX-2005 · Severity 2 · Plan notices never say which day or what time**
- **Where:** `App/lib/l10n/reminder_plan_words.dart:118-127` (`planNotice`), `App/lib/services/reminder_copy.dart:144-145`, and ARB `reminderPlanNotice*` (es:1393-1397, ca:1097-1101, en:3640-3661).
- **The moment:**
  - «Faltan 12 días… ¿y qué día es eso?»
  - «Es hoy… ¿a qué hora era?»
  - On a task planned for Monday but due Thursday: «¿Es hoy? Si lo tengo el lunes.»
- **What happens:**
  - The text is only «Faltan 12 días», «Es mañana» or «Es hoy»: no date, no time, and no "deadline" even when the plan counts to one.
  - The same task's single reminder follows the b10 standard: «Hoy a las 17:00 · en 10 min», «Fecha límite: vie, 25 sept a las 17:00».
  - Until UX-2004 is fixed, a stale «Es mañana» sits next to «Es hoy».
- **Why it fails:**
  - TA-7 (Pielot 2018): a reminder carries what and when, because people rarely open the app from it.
  - SC-9: the same task and day are said two ways.
  - The b10 rule (UX-409): no relative-only alert body.
  - CO-3.
- **Fix:** keep the countdown first. Add the day, and the time for a timed anchor, in the app's weekday date and the stored 12/24-hour clock, as `ReminderCopy.body` does. Bodies stay at 40 characters or fewer where they can (NO-3).

  | | Day only, 2+ days ahead | Timed, tomorrow or today | Deadline anchor |
  |---|---|---|---|
  | ES | «Faltan 12 días · jue, 12 nov» (timed: «Faltan 12 días · jue, 12 nov, 17:00») | «Es mañana a las 17:00», «Es hoy a las 17:00» | «Fecha límite: jue, 12 nov · faltan 12 días»; tomorrow and today reuse `notificationDeadlineAt`/`notificationDeadlineToday` («Fecha límite: hoy») |
  | CA | «Falten 12 dies · dj., 12 de nov.» | «És demà a les 17:00» | «Termini: dj., 12 de nov. · falten 12 dies» |
  | EN | "12 days left · Thu, Nov 12" | "It’s tomorrow at 5:00 PM" | "Deadline: Thu, Nov 12 · 12 days left" |

  - Date-only «Es mañana» and «Es hoy» stay as they are.
  - «Era para ayer» and «Venció ayer» stay too: those are the owner's words.
- **Verify:** unit test of `planBody` for day-only, timed and deadline anchors, at 12 days, tomorrow, today and the day after, in es/ca/en, with 24- and 12-hour clocks.
- **Evidence:** verified in code. Notifications aren't rendered.

**UX-2006 · Severity 2 · Offer asks again after the person chose the reminder**
- **Where:**
  - `App/lib/services/reminder_plans.dart:105-110`: `offerable` only checks `reminderMinutes != -1`.
  - `App/lib/widgets/task_editor.dart:563`: every edit save calls the question.
  - `App/lib/models/capture_session.dart:86-89`: a dictated «una hora antes» becomes `reminderMinutes: 60`.
- **The moment:** «Ya le he dicho "una hora antes". ¿Por qué me pregunta otra vez?» Or, after fixing one letter in a task's title, the offer appears.
- **What happens:**
  - The card shows «Recordatorio: 1 hora antes». After the save, the offer still asks, and «Sí» replaces that reminder with Normal. Until UX-2001 is fixed, the hour-before reminder is then gone.
  - A reminder chosen in the form gets the same treatment.
  - Any edit save of a far task that was never offered asks too. The offer's own test triggers it with a title-only edit (`App/test/reminder_plan_sheet_test.dart:688-700`).
- **Why it fails:**
  - CO-6: the person already chose.
  - FO-10 / WCAG 3.3.7: don't ask twice.
  - The Daily user's "never answer the same question twice".
- **Fix:** offer only when both hold. No new copy.
  - The reminder is still the default: `reminderMinutes == null && reminderTime == null`.
  - The save created the task, or moved its day or deadline.
- **Verify:** tests:
  - a far task with `reminderMinutes: 60` gets no offer;
  - a title-only edit of a far task gets no offer;
  - moving a task 3 weeks out gets the offer.
- **Evidence:** verified in code.

**UX-2007 · Severity 2 · Pro screen's reason doesn't say what «A tu manera» does**
- **Where:** `App/lib/screens/subscription_screen.dart:89-99`, ARB `billingReasonReminderPlans` (es:1402, ca:1106, en:3696), and render `reminders/sheet.pro-screen.*`.
- **The moment:** «"A tu manera"… ¿qué manera? ¿Pago para qué?»
- **What happens:**
  - For a free user, this line is the only description of «A tu manera». The sheet's row has no subtitle, just «Pro» (render `sheet.your-way-free`).
  - The line repeats the row's name, «Con Pro, tus recordatorios a tu manera», then the general «Dictados sin límite…».
  - Nothing says you can type or say a rhythm.
  - TalkBack reads it merged into one long text with the whole card, not as a heading (AUDIT).
- **Why it fails:**
  - SU-8 (Rosala 2023): walk every upsell as the most vulnerable user.
  - Plain language: be specific.
  - CO-8: an example is recognised, not recalled.
- **Fix:** say what it does, with the example the sheet already uses in `reminderPlanUnclear`:
  - ES «Con Pro, pide los avisos con tus palabras: «cada 3 días y la última semana a diario».»
  - CA «Amb Pro, demana els avisos amb les teves paraules: «cada 3 dies i l’última setmana cada dia».»
  - EN "With Pro, ask for reminders in your own words: “every 3 days, and daily the last week”."

  Mark it `Semantics(header: true)`. If it runs past 3 lines at 2×, put the example on its own line in body style.
- **Verify:** render `reminders/sheet.pro-screen` at ES/CA 2×: the line and the pinned «Ver suscripción» are both in view. AUDIT lists a heading node.
- **Evidence:** seen in a current render and verified in code.

**UX-2008 · Severity 2 · «Sí» to the offer has no Deshacer**
- **Where:** `App/lib/widgets/reminder_ask_sheet.dart:231-252`: `showFeedback(messenger, done)` has no action.
- **The moment:** the thumb lands on the big «Sí»: «Uy, no quería. ¿Cómo lo quito?»
- **What happens:**
  - «Listo. Te lo recordaré hasta el jue 12.» times out with no way back.
  - Removing the plan means opening the task, then its reminder line, then a single reminder or «Desactivado». The Newcomer won't find that path.
  - Changes elsewhere in the app offer «Deshacer».
- **Why it fails:** UN-3 (Nielsen 2018c), ON-10 (make safety visible), and the undo standard (restore locally first).
- **Fix:** add «Deshacer» (`undo`) to that message. It restores the task without the plan, locally first (`showLocal()`), like the other undos. Copy unchanged.
- **Verify:** widget test: «Sí», then «Deshacer»; the task is back to `reminderPlan == null`, and the engine has its single reminder again.
- **Evidence:** verified in code.

**UX-2009 · Severity 2 · «Posponer 10 min» on a nudge days away**
- **Where:**
  - `App/lib/services/notification_service.dart:60-65`: every task notice gets «Completar» and «Posponer 10 min».
  - `App/lib/services/reminder_engine.dart:410-438`: a snoozed plan notice comes back with the same text.
- **The moment:** «¿Posponer 10 minutos… el qué? ¿Me mueve la presentación?»
- **What happens:**
  - «Presentar el proyecto · Faltan 12 días» offers «Posponer 10 min», and ten minutes later the same «Faltan 12 días» comes back.
  - On «Era para ayer» it turns the owner's "one last notice" into two.
- **Why it fails:**
  - TA-8 (Weber 2018): postpone to times of day, not by durations.
  - CO-5: cut what the moment doesn't need.
  - DECISIONS: "one last notice, then silence".
- **Fix:**
  - A plan's notices carry only «Completar»: the plan's next notice is the follow-up.
  - The day-of notice of a timed task (from UX-2001) keeps «Posponer 10 min», like any single reminder.
  - The engine test «a snoozed plan reminder keeps saying how far the day is» changes with this.
- **Verify:** test of `reminderNotificationDetails`: a plan notice before the day, and the last notice, each have one action.
- **Evidence:** verified in code.

**UX-2010 · Severity 2 · The last days' notices depend on background work**
- **Where:**
  - `App/lib/services/reminder_plans.dart:20`: `window = 4`.
  - `App/lib/services/reminder_engine.dart:174-191`: `take(window)`.
  - `App/lib/services/notification_service.dart:179-190`: the refill is a WorkManager job.
- **The moment:** after a week without opening TaskFlow: «Me avisaba cada día y de repente dejó de avisar, justo el día antes.»
- **What happens:**
  - Only the next 4 notices of each plan are set. The rest wait for one of three things:
    - the job a minute after a notice rings;
    - the hourly job;
    - opening the app.
  - In the daily stretch, 4 notices cover 4 days. If the phone defers background work (battery savers, Android's restricted bucket) and the app isn't opened, «Es mañana» and «Es hoy» — the ones that matter — are never set.
  - Single reminders don't have this weakness, because they're all set ahead.
- **Why it fails:** TA-6 (Android Standby: restricted apps get deferred work and few alarms). The notices that matter most must not depend on background work.
- **Fix:** always set a plan's day-before, day-of and last notices alongside the next four. That's at most 3 more alarms per plan, well within the 400 capacity. No copy.
- **Verify:**
  - Engine test: Normal plan on a day 10 days away; the pending notices include days 8, 7, 6, 5 and also 1 and 0.
  - Device check on a phone with battery restrictions: a «cada día» plan for 6 days, with the app closed; «Es mañana» and «Es hoy» still arrive.
- **Evidence:** inferred from code; needs a device check.

**UX-2011 · Severity 1 · Recordatorios hides that «Tareas sin hora» sets plans' hour**
- **Where:** `App/lib/screens/notification_settings_screen.dart:186-188` and `:296-297`, and `App/lib/services/reminder_plans.dart:41-42`. Render: `settings/reminders.on.*`, which shows «Tareas sin hora · Desactivado».
- **The moment:** «Lo de "Tareas sin hora" lo quité… ¿por qué me avisa a las 9?»
- **What happens:**
  - «Tareas sin hora» now also sets the hour of every plan's notices.
  - Set to «Desactivado», the plans still ring at 9:00.
  - Recordatorios says neither. The only place the hour appears is the plan sheet's count («el próximo mañana, 09:00»), where it can't be changed.
- **Why it fails:** NO-8 (Kendrick 2018): the controls say what will arrive. CO-8.
- **Fix:** only when the row is off and some task has a plan, its subtitle reads:
  - ES «Desactivado · «Hasta la fecha límite»: 9:00»
  - CA «Desactivat · «Fins a la data límit»: 9:00»
  - EN "Off · “Until the deadline”: 9:00 AM"

  Otherwise it's unchanged.
- **Verify:** render `settings/reminders` with all-day reminders off and one planned task (the subtitle shows); without plans it shows «Desactivado» alone.
- **Evidence:** verified in code and in a current render (the off state).

**UX-2012 · Severity 1 · English last notice reads as a literal translation**
- **Where:** `App/lib/l10n/app_en.arb:3657`, `reminderPlanNoticeWas`: "It was for yesterday".
- **The moment:** "It was for yesterday? What was?"
- **What happens:** it's «Era para ayer» word for word. English doesn't say a task "was for" a day.
- **Why it fails:** G lens: each language reads naturally, not as a literal translation.
- **Fix:** EN "It was planned for yesterday", which parallels "It was due yesterday". ES and CA are unchanged: they're the owner's words.
- **Verify:** ARB diff, and an English `planNotice` test.
- **Evidence:** verified in code.

### Keep
- **The offer's guards:**
  - only with reminders on;
  - never for a task that's someone else's;
  - never when the phone blocks notifications;
  - never when the task's reminder is off;
  - at most once per task, stored on the phone;
  - only after the save message, so the landing and «Deshacer» come first (UX-439/448/449's guards reused).
- **The plan's lifecycle:** completing from any notice clears the rest («Completada… · Deshacer» brings them back). Moving the day moves the plan. The last notice is single and conditional: the owner's "one last notice, then silence".
- **`ReminderEngine.alertAhead` counts a plan's notices,** so the first reminder question and the engine can't disagree (UX-1601 holds).
- **The Pro reason line** comes first in the existing card, with no new screen. Back returns to the open sheet, with any typed words kept.
- **Plan notices share the reminders' channel, category and language** (UX-1607's reminder category, the app's language).

### Progress against UX_REVIEW.md (U1–U14)
- **U12, first run:** unchanged. The question still asks once, after the first dated save that can ring. The offer is a second, per-task question, shown only to people who said yes.
- **U5, land on the task:** not regressed. The offer waits for the save message, after the landing, as the first question does. After a multi-day dictation, though, the task it asks about isn't the one in view (UX-2002).
- **U10:** unaffected, because no new home targets. Every other U item is untouched by this change.

### Questions for the owner (product decisions)
- **D1 — How far back should «Hasta la fecha límite» start?**
  - Each strength starts "from now on". «Sí» on a task 6 months away means about 66 notices (Normal, every 3 days); 8 weeks means 24; 3 weeks means 13, plus one. Your own example is 3 weeks.
  - **Recommendation:** start each strength's first stretch at most 4 weeks before the day. Normal would then be about 14 notices whatever the distance.
  - Basis: NO-5 (median 56 notifications a day, Pielot 2018) and TA-12 (Steiner 2018: two well-placed reminders already help); `App/lib/models/reminder_plan.dart:74-79`.
- **D2 — Should the offer stop for someone who keeps saying «Ahora no»?** Every far task brings it, with no way to say "stop asking".
  - **Recommendation:** after two «Ahora no» in a row on this phone, stop offering. «Hasta la fecha límite» stays in every task's reminder sheet.
  - Basis: NO-5; SU-6's "no repeated nagging", by analogy; the Daily user.
- **D3 — Plans on shared tasks.** A plan is a synced task field. Set on a «Todos» task, it rings on every member's phone; set on Ana's task, it rings on Ana's.
  - **Recommendation:** plans only on tasks that ring on this phone alone (personal, or assigned to you). The sheet hides them elsewhere. UX-2003 already does this for the offer.
  - Basis: SH-4.
- **D4 — only if the organizer routes UX-2001 as a contract change:** on a timed task, the day itself rings at the usual "N minutes before", not at the all-day time.
  - **Recommendation:** yes, as in UX-2001.
- **D5 — RevenueCat's paywall** («Ver suscripción») lists Pro's benefits from the dashboard.
  - **Recommendation:** add «A tu manera» there. Otherwise the paywall says less than the screen before it. This is the owner's task; agents don't touch external services.

### Cross-slice notes
- **B · task line:**
  - On the anchor's day, after its last regular notice, it reads «Cada vez más a menudo hasta hoy · próximo: mañana».
  - That's because `planLine` counts the conditional last notice as «próximo» (`reminder_plan_words.dart:84`), while the sheet's count leaves it out (`:105`).
- **B · sheet:**
  - The plan's hour («09:00» in the preview) can't be changed there; it follows «Tareas sin hora» (UX-2011).
  - A date-only task's own reminder time (say 8:00) is lost when a strength is chosen.
- **B · sheet:** «Hasta la fecha límite» names a deadline on tasks that only have a day. The owner named it in DECISIONS, so this is a question only if B agrees it confuses.
- **B/C · sheet:** plans can be set on «Todos» tasks, and on tasks assigned to someone else. They ring on those people's phones (D3; UX-2003 covers only the offer).
- **B · sheet:** free users see «A tu manera · Pro» with no subtitle; only the Pro screen explains it (UX-2007).
- **A · card:** a dictated «recuérdamelo una hora antes» on a far task is then offered a plan after saving (UX-2006).
- **A/B · privacy:** «A tu manera» sends words to the AI, with no line in the sheet (the implementer's choice). Check that Ajustes › Voz's «Para añadir, buscar o cambiar tareas…» covers reminder rhythms.

### Memory notes
- **Area D map, reminder plans (aa2f53a):**
  - **Notices:**
    - Text comes from `planNotice` (`l10n/reminder_plan_words.dart:118`) through `ReminderCopy.planBody`.
    - Each plan day is its own notification, identity `…/plan/<date>`.
    - Only `ReminderPlans.window` (4) are set ahead, plus a WorkManager one-off job a minute after the earliest.
    - A plan replaces the single reminder (engine `plan()`).
    - Their hour is `plan.time ?? «Tareas sin hora» ?? 9:00`.
  - **The offer** (`_offer` in `widgets/reminder_ask_sheet.dart`):
    - shown when reminders are on, `isForAccount`, `ReminderPlans.offerable` (14 or more days, no plan, reminder not off) and the phone allows notifications;
    - at most once per task, per phone (scope `plan-offers:<owner>`);
    - after the save message;
    - «Sí» sets Normal, followed by «Listo. Te lo recordaré hasta el …».
  - **Pro reason:** `ProReason.reminderPlans` is passed as the `/subscription` route's arguments (`main.dart`), and the line sits first in the card.
- **Standards these departed from:**
  - the b10 notification-body standard (absolute time, «Fecha límite:» label): plan notices are relative-only (UX-2005);
  - the reminder question's «Sí, recuérdamelo»: the offer uses a bare «Sí» (UX-2002).
- **New recurring problem types:**
  - **30:** a per-task setting stored as a synced task field acts on every member's phone. Shared projects default new tasks to «Todos» (`task_assignment_picker.dart:13`). Check every new task field that leads to notifications.
  - **31:** a "X replaces Y" rule drops the instance that mattered most: the plan replaced the reminder before the time.
  - **32:** notifications posted once per occurrence, without replacement, stack in the shade with stale relative text.
- **Technique:** count a plan's notices from `ReminderPlan.strengthPhases`: days from `toDays` to `fromDays`, stepping by `everyDays`; drop days already past; add 1 conditional. Normal: 3 weeks → 13 + 1, 8 weeks → 24 + 1, 6 months → 66 + 1. Intenso at 3 weeks → 18 + 1; Suave → 7 + 1.
- **Evidence gap:** the emulator lane doesn't set plans, so plan notices have never been captured. Today's device captures were not yet in `App/build/ux/device/` when this review ran.
