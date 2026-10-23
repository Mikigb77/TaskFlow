# UX run 2026-10-22-changes — reminder plans

## Plan 2 — your answers to D1–D7, built (P252–P257)

You answered all seven questions. Five of the answers become P252–P256, and the run's two open findings go in too (UX-2021 in P256, UX-2020 in P257). D4 and D7 need no app change and are recorded as yours. One small new question came up while planning D1: D8, below.

**How it runs:** this is a scoped run, so nothing waits for you. There are two waves, set by the files the packages share: P252, P253, P254, P255 and P257 run side by side, then P256, which builds on three of them. The full briefs are in `plan.json`.

### Your answers, and where each goes
- **D1 → P252.** On a timed task's own day, its plan's notice rings at the task's usual reminder: «Hoy a las 17:00 · en 10 min», with «Posponer 10 min». Earlier days keep the plan's time, and the count stays the same. The task's line and the sheet show the new time.
- **D2 → P253.** The strengths start at most 4 weeks before the day: at most 8 notices for Suave, 15 for Normal and 22 for Intenso. Rhythms that are said or typed stay as said.
- **D3 → P254.** «Para recordártelo, ponle un día.» appears under the date and opens the date sheet. The reminder applies once the task has a day.
- **D4 → no change.** «Hasta la fecha límite» keeps its name, and UX-1911 is closed as your decision.
- **D5 → P255.** After two «Ahora no» in a row on this phone, the offer stops. «Sí» resets the count.
- **D6 → P256.** Plan rows show wherever the task rings on this phone, and never on a task given to someone else. The offer can come for any task that rings here. On shared tasks, the sheet says «Estos avisos son solo para ti.»
- **D7 → your task.** You add «A tu manera» to RevenueCat's paywall. UX-2015 is recorded as yours.

### A new question

#### D8 — A time said for the day itself (UX-2022, S2)
- **What happens with D1 as worded:** on a timed task's own day, the plan's notice moves to the task's usual reminder, whatever time the plan has. Take «Dentista el viernes a las 17:00, recuérdamelo el mismo día a las 9 para llevar el informe»: it rings at 16:50, not at 9:00, even though 9:00 was said. Likewise, «cada día a las 8» rings at 8:00 on the days before and at 16:50 on the day itself.
- **Options:**
  - (a) as D1 is worded: the day's notice always moves;
  - (b) keep a time that was said or typed: only plans without a time of their own move the day's notice to the usual reminder. Those are the strengths, «Sí» to the offer, and a rhythm said without an hour.
- **Recommendation: (b)**, by your own rule for D2, «if you specifically say it». It's one condition in P252's rule plus one line of the contract, and it can be undone. Until you answer, P252 builds (a), as D1 is worded.

### Packages, in run order

#### P252 · S4 · D · L · On a timed task's own day, its plan rings at the task's usual reminder
- **UX-2001** (S4) The day's notice of a task with a time, or a deadline with a time, rings at the task's own lead, else at «Tareas con hora» (10 min). It uses the single reminder's words and carries «Posponer 10 min». The chip, the form, the capture card and the sheet's count then say «próximo: hoy, 16:50».

#### P253 · S3 · B · S · The strengths start at most 4 weeks before the day
- **UX-1912** (S3) At most 8 notices for Suave, 15 for Normal and 22 for Intenso. A far task's sheet reads «Cada 3 días desde 4 semanas antes, y a diario la última semana» and «15 avisos». Custom plans stay as said, up to a year.

#### P254 · S2 · A · M · The capture card asks for a day when a said reminder needs one
- **UX-1812** (S2) «Para recordártelo, ponle un día.» under the date opens the date sheet. Once the task has a day, the «Recordatorio» row shows the plan; a said lead shows once the task also has a time. Saved without a day, the reminder is dropped. A plan whose day is cleared with «Sin fecha» shows the same line (UX-1811).

#### P255 · S2 · D · S · The offer stops after two «Ahora no» in a row
- **UX-2013** (S2) Counted per account on this phone. «Sí» resets the count; closing the sheet without answering neither counts nor resets it. «Hasta la fecha límite» stays in every sheet.

#### P256 · S2 · B · L · Plans on shared tasks are personal; «A tu manera» shows the newest words · after P252, P254 and P255
- **UX-2014** (S2) Plan rows show only where the task rings here. A task given to someone else gets the single reminder's rows, and never shows a plan as theirs. Shared tasks get «Estos avisos son solo para ti.» above Listo. The offer now comes for «Todos» tasks, tasks given to you, and unassigned tasks in projects you manage.
- **UX-2021** (S2) While the phone listens, the field scrolls so its last line shows the newest words.

#### P257 · S1 · D · S · «a las 8» stays together in the example
- **UX-2020** (S1) A no-break space now also sits between «a» and «las» (ES) and between «a» and «les» (CA), in the helper and in the Pro screen's example.

### Recorded, no package
- **UX-1911**: your decision (D4). The name stays, and Catalan keeps «Fins al termini».
- **UX-2015**: your task (D7), in RevenueCat.

### Notes
- **Evidence:** the three reviews (from aa2f53a), plan 1's verifications and report, and the code as it is now: e9b2e76, plus your server half in 0cf3431. The previews and device captures predate plan 1's fixes, so the reviews and the code are the evidence.
- **Where I settled things** (for the verifiers):
  - **D1, the lead:** when the task's own lead reaches into the day before («1 día antes»), «Tareas con hora» is used instead. With neither, the day keeps the plan's time. The moved notice gets «Posponer 10 min», as plan 1's recommendation and review D's UX-2009 said.
  - **D3, what the card reads:** the card reads the task's state rather than the server's key. So a plan whose day was cleared with «Sin fecha» shows the same line under the date, instead of «Añade una fecha para usar un recordatorio» in its row. UX-1811's look changes; its rule doesn't.
  - **D3, a heard lead:** a heard «una hora antes» is kept on a task with no day. Once the task has a day but no time, the row shows that day's usual reminder, because the lead needs a time, as decided. Saved with no day, the lead is dropped.
  - **D5:** only the «Ahora no» button counts.
  - **D6, where a plan shows:** on a task that doesn't ring here, the chip, the form and the card show no plan. Any plan there belongs to the person on this phone and rings for nobody.
  - **D6, the sheet's line:** it sits above Listo, so it's in view when a plan is applied. The copy is mine: «Estos avisos son solo para ti.» / “These reminders are only for you.” / «Aquests avisos són només per a tu.»
  - **UX-2021:** the field scrolls to its end rather than growing.
- **For the main session, once verified:**
  - The contract still has plan 1's stale quotes.
  - Plan 2 adds four things to it: P252's «Posponer 10 min»; P254's line after «Sin fecha» and the lead dropped when saved with no day; and P256's line in the sheet.
  - UX-2003's phone check changes with P256; the ledger says how.

### Phone checks added
- **P252:** the day's notice of a timed task with a plan.
- **P254:** «Llamar a mamá, recuérdamelo cada día», said aloud, with the server at 0cf3431.
- **P256:**
  - two phones in one shared project (this replaces UX-2003's check);
  - «A tu manera» with the real microphone at the largest font.

### Round 2 (p2)

Round 1 (P252–P257) passed its round check, no test failed, and reviews A, B and D found nothing still open. Round 2 fixes the one severity-1 regression review A found, in one small package. Nothing is escalated, and there's no new owner question. Full brief: `plan-p2-r2.json`.

#### P258 · S1 · A · S · The capture card: a date's open question stays next to its date line
- **UX-2023 (S1), regression R1A-1 from P254:** on a draft with no day, a said reminder and an open «¿Qué día?» question, P254's «Para recordártelo, ponle un día.» sat between the date line and its question, so the card asked for the day twice and split the question from its date. The line moves after `_questions('schedule')` on the opened card and on a collapsed row (`capture_review_editor.dart:724-727`, `:899-903`). No copy change. Inferred from code; no preview shows this state, so a widget test proves it.
- **Settled:** I moved the line rather than hiding it while a question is open, since a date question can be about the time, and hiding the line would then drop the reminder's reason.

#### Phone checks added
- None.

#### Notes for the main session (from round 1's implementers)
- **P256:** reported that the line-by-line merge of wave 1's tests had cut the closing lines of the groups 'P252 · D1', 'P253 · UX-1912', 'P254 · D3' and 'P255 · UX-2013…' in `App/test/reminder_plan_sheet_test.dart`, and of 'P253 · UX-1912' in `App/test/reminder_plan_engine_test.dart`. The round check has since passed, so those closers are back. Keep an eye on this merge step.
- **`Backend/docs/REMINDER_PLANS.md`**, beyond what Plan 2's notes already list:
  - **P252:** the day's notice of a timed task carries «Posponer 10 min» (iOS category `task_<lang>`), and a snooze brings it back 10 minutes later in the single reminder's snoozed words. A plan with a time of its own is moved on that day too, pending D8 (UX-2022).
  - **P254:** the app honours `reminder_needs_day` for `reminder_minutes` too. The card shows the line for any task with no day and no deadline that has a plan or a lead, whether or not the server sent the flag. A lead or plan still waiting for a day is dropped on save.
  - **P255:** closing the offer without an answer neither counts nor resets the count, and «Sí» starts it again.
  - **P256:** the offer now comes for any task that rings on this phone, shared ones included. The sheet on a shared task says «Estos avisos son solo para ti.» above Listo. A plan kept on a task given to someone else is neither shown nor offered on this phone.
- **P252, beyond its brief (for the verifiers):** `ReminderEngine.alertAhead` ignores the late notice for plans, and `reminder_control.dart`'s `_chooseReminder` passes the sheet the schedule with its current minutes. Both were needed for its acceptance checks.
- **P253:** the far next day reads «mié, 25 de nov» (with «de»), as `planDay` writes a date in another month. Tests read it through `planDay`.
- The modified plugin registrant files under `App/linux`, `App/macos` and `App/windows` come from a seed's `flutter pub get`. Leave them out of the commit.

---

## Plan 1 — reminder plans (P241–P251, done and committed in e9b2e76)

Three reviewers (A capture, B tasks, D reminders and Pro) found 33 problems in reminder plans (aa2f53a) and asked 10 questions. 27 problems become seven packages, P241–P247, which go straight to the implementers, and 5 were duplicates merged into them. The most severe problem (UX-2001) and the questions come to you as 7 decisions, D1–D7, most urgent first; no package waits for them.

**How it runs:** this is a scoped run, so nothing waits for you. The packages run in three waves, by the files they share: P241, P243 and P247 side by side; then P242, P244 and P245; then P246. Package numbers continue after P240. The full briefs were in `plan.json`; plan 2 replaced that file, so plan 1's version is in git at e9b2e76.

### What the reviewers measured
- **Verdicts:** all three, ship after fixes.
- **Your sentence, dictated:** 3 taps, as for any one-task dictation (+2 on a new account: the reminder question and Android's dialog). Before this change, a said rhythm was dropped.
- **Choosing a strength on a task:** 3 taps to set, 3 to change, 2 to remove.
- **The reminder sheet:** a dated task's rows go from 3 to 5 (date only) or 6 to 8 (timed). P243 takes the 2 new rows off tasks due today, tomorrow or earlier.
- **Notices after one «Sí» to the offer (Normal):** 13 at 3 weeks (your example), 24 at 8 weeks, 66 at 6 months (D2).
- **The offer:** 3 tap targets and 8 words; it names no task, so after a two-task dictation it asks about one out of view (P244).

### Questions for you

#### D1 — A plan replaces a timed task's own reminder, so its day rings at 9:00 (UX-2001, S4)
- **What happens:** the contract says «A plan replaces the single reminder», and every plan notice, the day's included, rings at the plan's time or the all-day time (9:00). «Análisis de sangre» on Thu 12 Nov at 8:00, «Sí» to the offer: the 7:50 reminder is gone, and the day's only notice, «Es hoy», comes at 9:00, an hour after. A 17:00 presentation gets 9:00 and nothing at 16:50, while Ajustes › Recordatorios still promises «10 minutos antes».
- **Options:**
  - (a) as built;
  - (b) on the task's own day, a timed task (or a deadline with a time) rings at its usual reminder — its own lead, else «Tareas con hora», 10 minutes by default — with the usual text («Hoy a las 17:00 · en 10 min»); earlier days keep the plan's time, and the count doesn't change;
  - (c) keep the single reminder alongside the plan.
- **Recommendation: (b)**, as all three reviewers recommend: one notice on the day, when it's useful, and nothing extra. One small package and one line of the contract; reversible. Meanwhile P244 stops the offer for a task with a reminder of its own, so «avísame una hora antes» is kept; «Sí» on other timed tasks still moves their day's reminder to 9:00 until you answer.

#### D2 — How far back should a strength start? (UX-1912, S3)
- **What happens:** each strength starts "from now on", so the count grows with distance. Normal: 13 notices at 3 weeks, 24 at 8 weeks, 66 at 6 months, about 127 at a year; at 6 months Suave gives 30 and Intenso 98. The offer's one-tap «Sí» sets Normal for any task 14 or more days away.
- **Options:** (a) as built; (b) start at most 6 weeks before the day (review B): Normal at most 20, Suave 10, Intenso 29; (c) at most 4 weeks before (review D): Normal at most 15, Suave 8, Intenso 22. Your 3-week example stays 13 in every option.
- **Recommendation: (c), 4 weeks.** It's the closest to your example, so «Sí» never means more than about 15 notices, and Intenso stays clearly stronger. The sheet's words and dots show the later start by themselves («Cada 3 días desde 4 semanas antes, y a diario la última semana»). Three numbers and the contract's table; reversible.

#### D3 — A reminder said for a task with no day is dropped without a word (UX-1812, S2)
- **What happens:** with no day or deadline the server sets no plan, and «una hora antes» on a task with no time is dropped. So «Llamar a mamá, recuérdamelo cada día» saves with no reminder, and nothing on the card says so.
- **Options:** (a) the server flags a reminder it heard but couldn't keep, and the card shows one line under the date that opens the date sheet: «Para recordártelo, ponle un día.» / "To remind you, give it a day." / «Per recordar-t’ho, posa-li un dia.» (my Catalan); (b) leave it until the §7 test.
- **Recommendation: (a).** The assistant heard «recuérdamelo»; the card should say what it needs instead of dropping it. One server field (the main session's) and one card line; reversible.

#### D4 — «Hasta la fecha límite» on tasks that only have a day (UX-1911, S2)
- **What happens:** it's your name for the row. Most tasks only have a day, and everywhere else «Fecha límite» names a separate field («Fecha límite» on the task, «Quitar fecha límite», «Fecha límite: …» in notifications). So on a day-only task the row names something the task doesn't have; its subtitle, «Cada vez más a menudo hasta el jue 12», is what says what it does.
- **Options:** (a) keep it; (b) make the subtitle the title: «Cada vez más a menudo», with «hasta el jue 12» under it, for a deadline and a day alike; (c) keep «Hasta la fecha límite» on tasks with a deadline and say «Hasta el día» on the others.
- **Recommendation: (b).** It says what the choice does, the same on any task, with no new concept. A strings package; reversible. Until you answer, P245 makes the Catalan say «Fins al termini», the word the rest of the Catalan app uses.

#### D5 — Should the offer stop for someone who keeps saying «Ahora no»? (UX-2013, S2)
- **What happens:** every far task saved brings it, once per task, with no way to say "stop asking".
- **Recommendation:** after two «Ahora no» in a row on this phone, stop offering. «Hasta la fecha límite» stays in every task's reminder sheet. Small; reversible.

#### D6 — Plans on shared tasks (UX-2014, S2)
- **What happens:** a plan is part of the task, synced like the rest. Set on a «Todos» task, it rings on every member's phone, about 13 notices each, with nothing saying who set them; set on Ana's task, it rings on Ana's. P244 already keeps the offer to tasks that ring on this phone alone; this is about the reminder sheet.
- **Options:** (a) as built; (b) plans only on tasks that ring on this phone alone (personal, or assigned to you): the sheet doesn't show them on «Todos» tasks or other people's.
- **Recommendation: (b).** Don't notify other people without their say. Small; reversible. If plans for a whole project are wanted later, they need a line saying who set them.

#### D7 — RevenueCat's paywall doesn't mention «A tu manera» (UX-2015, S1)
- **What happens:** «Ver suscripción» opens RevenueCat's paywall, whose Pro benefits come from its dashboard, so it says less than the screen before it.
- **Recommendation:** add «A tu manera» to the paywall's benefits, in P247's words («Pide los avisos con tus palabras»). It's your task: agents don't touch external services.

### Packages, in run order

##### P241 · The plan's line names reminders and the strength, gives the next one's time, and promises only what will come · B · M
- **UX-1804** (S3; with UX-1903) «próximo» no longer points at the after-the-day notice or at a completed task: a plan with nothing left before the day reads «Sin recordatorio: ya ha pasado la hora del aviso», and a completed task reads the plan alone.
- **UX-1806** (S2; with UX-1902) The line starts with the word and names the strength: «Recordatorios normales hasta el vie 13 · …», «Recordatorios: cada 3 días, y a diario la última semana · …», on the task, the form and the card.
- **UX-1807** (S2) The next reminder gets its time: «· próximo: sáb 24, 09:00».
- **UX-1910** (S1) The sheet's count reads «13 avisos · próximo: mañana, 09:00» and «1 aviso: mañana, 09:00».

##### P242 · The capture card: one «Recordatorio» row for a said reminder, honest about this phone, shown in collapsed rows, and never saved when it can't apply · A · L · after P241
- **UX-1802** (S3) When this phone won't ring (reminders off, or notifications blocked), the row keeps its words and shows «Activar recordatorios» under it.
- **UX-1805** (S2) A said reminder, plan or «una hora antes», is one «Recordatorio» row above «Más opciones» that stays when it's changed; 2 taps to change instead of 3 and a scroll; never twice.
- **UX-1809** (S2) In a result of several tasks, a collapsed row with a said reminder shows it under its date.
- **UX-1811** (S1) A plan that no longer applies («Sin fecha», or a repeat added) isn't saved; the row says «Añade una fecha para usar un recordatorio».

##### P243 · The reminder sheet: a dictated plan shows as chosen for everyone, opens in view, appears only where it helps, and TalkBack hears the rows expand · B · M
- **UX-1801** (S3; with UX-1901) A free account that dictated a rhythm sees «A tu manera» chosen, with its rhythm, preview and «Listo», and no Pro badge; the badge stays for tasks without such a plan.
- **UX-1810** (S2) The sheet opens with the task's plan at the top, not under six single rows.
- **UX-1904** (S2) Tasks due today, tomorrow or earlier get the single reminders only, unless they already have a plan: 2 rows fewer in the common case.
- **UX-1907** (S2) TalkBack hears «Hasta la fecha límite» and «A tu manera» as collapsed or expanded, and no longer reads «Hoy» and the date under the dots.

##### P244 · The offer after saving: only when nothing was chosen, only for tasks that ring here alone, naming the task and what «Sí» gives, with Deshacer · D · L · after P241
- **UX-1803** (S3; with UX-2006) No offer for a task with a reminder of its own («avísame una hora antes» is kept), and none after an edit that doesn't move the day.
- **UX-1808** (S3; with UX-2002) The offer names the task and its day, then asks «Faltan 3 semanas. ¿Te aviso cada 3 días, y a diario la última semana?», with «Sí, recuérdamelo».
- **UX-2003** (S3) No offer on «Todos» tasks, other people's, or in projects muted on this phone, so one «Sí» never rings other members' phones.
- **UX-2008** (S2) «Listo. Te lo recordaré hasta el vie 13.» comes with «Deshacer».

##### P245 · «A tu manera»: stop and Listo stay in view, read words survive closing, an example up front, and Catalan says «termini» · B · M
- **UX-1905** (S2) At 2×, «Dejar de escuchar» stays in view while words arrive, and «Listo» comes into view after the reading.
- **UX-1906** (S2) Words already read, and their plan, survive closing the sheet by accident: no second AI call.
- **UX-1908** (S2) The empty field shows an example, «Por ejemplo: «una semana antes y el día antes a las 8».»; «No lo he entendido. Prueba a decirlo de otra forma.»; after that, «Dictarlo» starts from an empty field.
- **UX-1909** (S1) Catalan: «Fins al termini», as the rest of the Catalan app names a deadline.

##### P246 · Plan notices: the day and time in words, one per task in the shade, no snooze, and the last days always set · D · L
- **UX-2004** (S2) One plan notice per task in the shade: a new one replaces the stale «Faltan 20 días».
- **UX-2005** (S2) Notices say the day and time: «Faltan 12 días · jue, 12 nov», «Es mañana a las 17:00», «Fecha límite: jue, 12 nov · faltan 12 días».
- **UX-2009** (S2) A plan's notices carry only «Completar», so «Posponer 10 min» no longer repeats a countdown or turns the last notice into two.
- **UX-2010** (S2) The day-before, day-of and last notices are always set, so they don't depend on Android running background work.
- **UX-2012** (S1) English: "It was planned for yesterday".

##### P247 · Outside the sheet: the Pro screen says what «A tu manera» does, and Recordatorios says when plans ring · D · S
- **UX-2007** (S2) The Pro screen's reason: «Con Pro, pide los avisos con tus palabras:» with the example «cada 3 días y la última semana a diario» under it, read as a heading.
- **UX-2011** (S1) With «Tareas sin hora» off and a plan set, the row reads «Desactivado · «Hasta la fecha límite»: 9:00».

### Skipped
- **UX-1901**: duplicate of UX-1801, merged into P243.
- **UX-1902**: duplicate of UX-1806, merged into P241.
- **UX-1903**: duplicate of UX-1804, merged into P241.
- **UX-2002**: duplicate of UX-1808, merged into P244, with its S3.
- **UX-2006**: duplicate of UX-1803, merged into P244.

### Notes
- **Evidence:** renders and AUDIT from aa2f53a (widget tests), and code. The emulator captures from this commit arrived after the reviews (the first-run reminder question, Android's dialog, Ajustes › Recordatorios); none shows a plan, the offer or a plan notice, so nothing changes. Plan notices have never been captured; they're phone checks.
- **For the main session, once verified:** `Backend/docs/REMINDER_PLANS.md` quotes the old line and count (P241), the old offer and its conditions (P244), «A tu manera»'s helper (P245) and the notices (P246). D1, D2 and D4 would change it too, and D3 needs a server field.
- **Where I settled the reports** (for the verifiers):
  - P241 puts the word «Recordatorios» in the line everywhere, titled rows included: leaving it out there, as review B asked, would leave the three strengths reading alike. A plan with nothing ahead uses review A's «ya ha pasado» text; review B's plan-alone is kept for a completed task.
  - P243 shows «Listo» in a free account's read-only section (review A); review B left it out. It applies UX-1904 inside the sheet, not at `reminder_control.dart:318`: the same result, and it keeps packages apart.
  - P244 shows the task's title in titleMedium (review A), with review D's rule that everything fits at 2× on a 320 dp phone. It names the day with the app's existing labels («vie, 13 nov», «Vence jue, 12 nov») rather than new «Fecha límite:» copy. The months version of the question is mine, in all three languages.
  - P246's Catalan beyond review D's examples, and «Fecha límite: mañana», are mine.
  - P247 splits the Pro reason in two, by review D's own rule for a line longer than 3 lines at 2×. Its Catalan uses «Fins al termini» (UX-1909).

### Round 2

Round 1 (P241–P247) passed its round check, no test failed, and reviews A, B and D found every finding fixed. Round 2 fixes the two regressions they found, in two small packages that share no file, so they can run side by side. Nothing is escalated, and there's no new owner question. Full briefs: `plan-r2.json`.

#### P248 · S2 · A · S · The capture card: a reminder changed inside «Más opciones» stays where it was changed
- **UX-2016 (S2), regression R1A-1 from P242:** on a plain draft, changing the reminder inside «Más opciones» set `_reminderOpen`, so the control jumped above the «Más opciones» header, off screen at 2×, right after the change. The three `setState(() => _reminderOpen = true)` calls are removed (`capture_review_editor.dart:547, 553, 559`); a said reminder's row above «Más opciones» is unchanged, since the flag is already true there. No new copy. Verified in code; no preview shows this state.
- **For the verifier:** with «Más opciones» closed again after such a change, its subtitle doesn't mention the reminder, because P242 (UX-1805) took the reminder out of `optionsSummary`. The package leaves that as it is; say if it should be a finding.

#### P249 · S2 · D · S · The Pro screen's example is one no free strength gives
- **UX-2017 (S2), regression R1D-1 from P247:** the Pro screen's example «cada 3 días y la última semana a diario» is the rhythm P244's offer gives every free user (Normal). It becomes the field's own example, with no final period: ES «una semana antes y el día antes a las 8», EN “a week before, and the day before at 8”, CA «una setmana abans i el dia abans a les 8». Only the three ARB values and the preview description change; P247's tests read the copy through AppLocalizations.

#### Phone checks added
- None.

#### Notes for the main session (from round 1's implementers)
- `Backend/docs/REMINDER_PLANS.md` needs its quotes updated, as plan 1's notes expected:
  - «The sheet and the task»: the line becomes «Recordatorios normales hasta el jue 12 · próximo: sáb 24, 9:00» and «Recordatorios: cada 3 días, … · próximo: …, <time>»; the count «N avisos · próximo: …, <time>» / «1 aviso: …, <time>» (P241);
  - «The offer»: the new question, and its new conditions: the reminder is still the default; the save creates the task or moves its day; the task rings on this phone alone (personal or assigned to me, project not muted or archived); «Deshacer» is offered (P244);
  - «A tu manera»'s helper: «Por ejemplo: «una semana antes y el día antes a las 8».» (P245);
  - «The notifications»: the day and time are in the text, one notice per task stays in the shade, plan notices carry «Completar» only, and the day before, the day and the day after are always set (P246).
- The modified plugin registrant files under `App/linux`, `App/macos` and `App/windows` come from a seed's `flutter pub get`, not from any package. Leave them out of the commit.
- P245: the «A tu manera» helper now shows only until a plan has been read from the words; the plan's preview then replaces it (it kept «Listo» in view at 2×). Review B found UX-1908 fixed with this.
- P242: the said-reminder row uses ReminderControl unchanged, so its icon has the default tint, not the primary tint of the old bespoke row.
- P244: the Spanish offer line reads «Presentar el proyecto · vie, 13 de nov» (the existing `taskDayLine`, with «de»), not plan 1's «vie, 13 nov».

### Round 3

Round 2 (P248, P249) passed its round check, no test failed, and reviews A and D found UX-2016 and UX-2017 fixed. Round 3 fixes the two severity-1 regressions they found, in two small packages that share no file, so they can run side by side. Nothing is escalated, and there's no new owner question. Full briefs: `plan-r3.json`.

#### P250 · S1 · A · S · The capture card: a reminder changed inside «Más opciones» still shows once they're closed
- **UX-2018 (S1), regression R2A-1 from P248:** with the control now staying inside «Más opciones», a reminder changed there showed nowhere once they were closed, and a collapsed row didn't show it either. Only when the draft carries a reminder and has no row above «Más opciones», the subtitle ends with the task's existing reminder line («Recordatorio: 18:00», «Recordatorio: Desactivado», or a plan's line), and a collapsed row shows its reminder line. No new copy. A said reminder keeps UX-1805's rule: its row, and nothing in the subtitle. A plain dictation is unchanged.
- **Settled:** I kept it as a fix rather than accepting it. UX-1805's «nothing in the subtitle» was about a said reminder, which has its own row; this covers only a reminder changed inside, which has none, and follows the subtitle's rule for priority and repeat: what differs from the default.

#### P251 · S1 · D · S · The «A tu manera» example keeps «a las 8» on one line
- **UX-2019 (S1), regression R2D-1 from P249:** the Pro screen's example wrapped «…a las» / «8»» in Spanish at 1× and 2×. A no-break space goes between the preposition and the hour in `reminderPlanYourWayHint` and `billingReasonReminderPlansExample`, in ES («a las 8»), CA («a les 8») and EN (“at 8”). The words are the same; UX-1908's helper test gets the same three literals.

#### Phone checks added
- None.
