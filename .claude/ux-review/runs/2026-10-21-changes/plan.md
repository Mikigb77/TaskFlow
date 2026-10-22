# UX plan — 2026-10-21-changes, plan 2 (2026-10-22): your D1–D3, and the Voz privacy line

You answered D1–D3 as recommended, so they become three packages, P231–P233; the website review's note on the app's privacy line becomes a fourth, P234.
One new question, D4, comes out of your D2; nothing waits for it.

**How it runs:** this is a scoped run, so the packages go straight to the implementers. P231 and P234 run side by side. P232 and P233 build on P231 and share the capture sheet's files, so they follow one at a time. Package numbers continue after P230. The full briefs are in `plan.json`, which now holds only P231–P234.

## Your answers, and where they go
- **D1 (UX-1715), a task with only a deadline moved by voice:** P231. It also carries UX-1709's fifth item (a time said for such a task).
- **D2 (UX-1702), «hoy» and the tasks in «Atrasadas»:** P232.
- **D3 (UX-1716), fixing a misheard day by touch:** P233, on the set card and on one task's change card.

## Question for you

### D4 — «Retrasa todo lo de hoy un día»: where do the overdue tasks go? (UX-1721)
- **Where it comes from:** I found it while planning your D2. No reviewer has seen it on screen.
- **What happens:** with your D2, a set «de hoy» also takes the tasks Today lists under «Atrasadas».
  - A move to a day («pasa todo lo de hoy a mañana») sends them all to that day. That's fine.
  - A move by days («retrasa todo lo de hoy un día») moves each task by that many days from its own day, as the contract's shift rule says. So a task overdue since Monday goes to Tuesday. It's still in the past, so it stays under «Atrasadas», right after you said to put today's things off by a day.
- **Options:**
  - (a) keep the contract's rule: each task moves from its own day;
  - (b) the overdue tasks a «hoy» set takes move from today, so «un día» puts them on tomorrow with the rest.
- **Recommendation: (b).**
  - «Hoy» is what Today shows (your D2), and Today shows those tasks as today's, so for them a move by days counts from today.
  - Nothing else changes: other days' sets, one task, and a move to a day stay as they are. A task with only a deadline moves its deadline the same way (D1).
  - The card lists each of them with «Atrasada» before the tap, and «Deshacer» undoes it.
  - Until you answer, P232 builds (a), the contract as written. (b) would be one small package and one line in the contract. Reversible.

## Packages, in run order

**First, side by side: P231 and P234. Then P232. Then P233.**

#### P231 · S2 · A · M · A voice move of a task with only a deadline moves its deadline (D1)
- **UX-1715** (S2): «Pasa todas las tareas de ayer a mañana» moves the deadline of «Pagar la factura del gas», a task with only a deadline, to tomorrow. It no longer sits on tomorrow reading «Fecha límite vencida» in red. One task reads the same: «Cambiar fecha», then «Movida al vie, 23 oct». A time said for such a task («a las 18:00») goes on its deadline, instead of asking «¿Qué día?» or counting it «sin fecha». Calendar's own «Cambiar fecha» keeps its rule.

#### P232 · S2 · A · L · after P231 · «Hoy» takes the overdue tasks Today lists, first and marked «Atrasada» (D2)
- **UX-1702** (S2): with 6 tasks in Today, 2 of them overdue, «Marca como hechas todas las de hoy» now offers «Marcar 6 tareas como hechas», not 4. The overdue ones are listed first, each «… · Atrasada», ticked, and any can be unticked. After the tap Calendar stays on Today, with no «Atrasadas» left. «Pasa todo lo de hoy a mañana» takes them too. Only pending sets for exactly today change.

#### P233 · S2 · A · L · after P231 · The day of a move is a chip that opens «Elegir día» (D3)
- **UX-1716** (S2): «Mover 4 tareas a [mañana, vie 23 ▾]». A tap opens the «Elegir día» you know from the form, with Hoy, Mañana and the calendar, but without «Sin fecha»; the heading, the count and the button follow the day picked. One task's change card gets the same chip on its new day: «lun, 26 oct · 10:00 → [mié, 28 oct · 10:00 ▾]». If the day picked leaves nothing to move, the chip stays, so you can pick again.

#### P234 · S1 · A · S · beside P231 · The Voz privacy paragraph says in plain words why your words go to Google
- **UX-1720** (S1, from the website review): in Ajustes › Voz, «La extracción de tareas con IA necesita internet y envía tus palabras a Google.» becomes «Para añadir, buscar o cambiar tareas, tus palabras van por internet a la IA de Google.», with the same verbs as the website's privacy summary. English and Catalan the same way.

## Skipped
None.

## Notes
- **For the main session:**
  - Run the fix as a batch, for example `batch: "b2"`. Then it keeps its own report, round plans and verify notes, and doesn't overwrite plan 1's `report.md`, `plan-r2.json`, `plan-r3.json` or `verify-r1-A.md` to `verify-r3-A.md`. Later rounds of plan 2 are added at the end of this file.
  - Plan 1's briefs (P224–P228) are in git: `git show 399c0d0:.claude/ux-review/runs/2026-10-21-changes/plan.json`.
  - The contract already says D1–D3 (8e4513f). If D4 is answered (b), «Which tasks the set holds», «Hoy», gains one line.
  - **Not planned:** the website plan's second note for the app wasn't passed to this plan. The Spanish help for the widget (`homeCaptureInstructions`, `App/lib/l10n/app_es.arb:228`) calls it «el widget de micrófono». The widget itself says «Dictar una tarea» (`values-es/strings.xml:11`), and the English and Catalan help use that name. It's area D; pass it to the next `/ux` run.
  - Another session's uncommitted work (`Backend/`, `App/pubspec.yaml`, `App/scripts/`, `App/config/`) is out of every package.
- **The organizer's readings, for the reviewer to check:**
  - P232 lands on Today after a «hoy» set's tap. This follows review A's own check, «after the tap Today shows no Atrasadas».
  - P233's «Elegir día» has no «Sin fecha», because a move's day can't be none.
  - P233 keeps the chip under «Ya están así.» / «Ya está así.», so a wrong day picked never dead-ends the card.
  - On P233's set card, TalkBack hears the day twice: in the heading's whole sentence, then as the chip.
  - P234's Catalan is the organizer's: «Per afegir, cercar o canviar tasques, les teves paraules van per internet a la IA de Google.»
- **Phone checks** (in each package's `deviceChecks`):
  - with the real model, the main session: a deadline-only task «a mañana» and «a las 18:00» (P231); «Marca como hechas todas las de hoy» comes back with today as its period (P232);
  - on your phone: a task left over from yesterday, then «Marca como hechas todas las de hoy» at the largest font (P232); TalkBack and the largest font on the day chip (P233);
  - a native Catalan read (P234).
- **Progress against UX_REVIEW.md:**
  - U4: P233 brings the result's fix-by-touch to command cards, and helps §7 task 5, «Move the doctor to Saturday».
  - D1 and D2 make «mañana» and «hoy» in a command mean what Calendar shows.
- **Ledger:** UX-1715, UX-1702 and UX-1716 move from Decision needed to Open. UX-1720 is new and open. UX-1721 is new, as a decision (D4). U4 and UX-1709 get a note.

---

# Plan 1 (2026-10-21): P224–P230, done and committed in 399c0d0

From here down, the first plan of this run and its rounds, as written then.

Review A found 14 problems in the bulk voice commands (dc17ab1) and asked you 2 questions. 13 problems become five packages, P224–P228, which go straight to the implementers; 3 questions wait for you (D1–D3), and nothing was skipped.

**How it runs:** this is a scoped run, so the packages go to the implementers one at a time, in the order below, without waiting for you. Package numbers continue after P223 (2026-10-19-app, b7). The full briefs are in `plan.json`.

## What the reviewer measured
- **Verdict:** ship after fixes.
- **Moving a day's tasks to another day:** 3 taps, plus 1 per task unticked. Before, it took 3 taps per task by voice (12 for 4 tasks), or about 3–4 per task by hand.
- **Marking a task done by voice:** 3 taps. This wasn't possible by voice before.
- **At 2× on a 360 dp phone:** the move card shows its heading and 1 of 4 tasks above the button; the delete card opens scrolled past its own heading (UX-1704, P224).

## Questions for you

### D1 — A task with only a deadline, moved «a mañana», still reads overdue (UX-1715; also UX-1709's fifth item)
- **What happens:** «Pasa todas las tareas de ayer a mañana» listed «Pagar la factura del gas · Vence mar, 20 de oct» among the tasks to move. After the tap it sits on Thursday, still reading «Vence mar, 20 de oct · Fecha límite vencida», in red. Said as «retrásalo todo un día», the same task's deadline would move instead.
- **Why:** this is the rule as designed, which you were told about. A move to a day sets the planned day and keeps the deadline, as the app's own move does; a move by days moves a deadline-only task's deadline (the contract).
- **Options:**
  - (a) a voice move to a day moves the deadline of a task that has only a deadline, as a move by days does. One rule for both;
  - (b) keep the rule, and say «· no cambia» on that row before the tap, so the red line isn't a surprise.
- **It also settles** UX-1709's fifth item: a new time said for such tasks («a las 18:00») counts them under «sin fecha», though they show «Vence …».
- **Recommendation: (a).**
  - For that task, the deadline is the only date the card and Calendar show, so it's what the person's words point at, and it matches the move-by-days rule. The form still edits both dates.
  - With (a), a time said for those tasks would go on their deadline too.
  - It covers voice moves only, for one task or a set. Calendar's own «Cambiar fecha» keeps its rule unless you say otherwise.
  - Reversible. The main session updates the contract.

### D2 — Does «hoy» include the overdue tasks Today lists? (UX-1702)
- **What happens:** since your D1 of 2026-10-13, Today lists unfinished tasks from earlier days under «Atrasadas · N». But a set «de hoy» takes only tasks dated today. With 6 tasks in Today, 2 of them overdue, «Marca como hechas todas las de hoy» offers «Marcar 4 tareas como hechas», and tomorrow the 2 are still «Atrasadas». «Pasa todo lo de hoy a mañana» leaves them behind too, and nothing mentions them. Yet a single «Ya he…» does take a task Today lists as overdue.
- **Why it's yours:** the fix changes the contract's period rule, which decides which tasks a command changes or deletes.
- **Options:**
  - (a) a set for exactly today also takes the open tasks Today lists as overdue: listed first, as Today lists them, with «Atrasada», ticked so any can be unticked;
  - (b) keep «hoy» as the tasks dated today; «lo atrasado» reaches the others.
- **Recommendation: (a).** «Hoy» is what Today shows, and the one-task path already works this way. Every task is listed and ticked before the tap, so nothing is deleted or completed unseen, and «Deshacer» undoes all of it. No new copy. Reversible.

### D3 — Should a set's day be fixable by touch? (UX-1716)
- **What happens:** if «a mañana» was misheard, the set card's only fix is «Volver a decirlo»: a whole new dictation, which without Pro is one of the 10 free a month. The one-task change card has the same gap. Saying it again fixes about a third of recognition errors; a tap or typing fixes most of them (VO-6). U4 made a new task's date a tappable row for this reason.
- **Recommendation: yes.** The day in a move's heading becomes a chip («mañana, jue 22 ▾») that opens the existing «Elegir día» sheet, with Hoy and Mañana; the count stays live. It adds one control to the card you specified, so it's your call. Say too whether a one-task change's new day should get the same.

## Packages, in run order

#### P224 · The set card reads right · A · M
- **UX-1701** (S2) Each row says what the search card's row says: the day, the project, the person in a shared project, and «Completada», with done titles struck through. So «borra las completadas» can be checked before the red tap.
- **UX-1704** (S2) At large text, a set deletion opens at «Eliminar N tareas» and its ✕, instead of scrolled past them.
- **UX-1706** (S2) When exactly one task is left out, the line names it: «Natación se repite: no cambia». From two on, it still counts.
- **UX-1712** (S1) «jue 22» stays on one line in the heading at 2×.
- **UX-1713** (S1) Over 200 matches: «Son 230 tareas, demasiadas. Vuelve a decirlo con un día o un proyecto.»

#### P225 · When a command's task or project isn't settled · A · L
- **UX-1705** (S2) «Ya he llamado al dentista» with no such task no longer offers to save the sentence as a new task. It offers Cerrar and Volver a decirlo, under a search icon instead of a green tick.
- **UX-1708** (S2) «Pasa todo lo de mates a mañana», with Matemáticas and Matemáticas II, asks «¿Qué proyecto?» with a chip for each, instead of «No encuentro el proyecto «mates»». The same for searches and one-task commands.

#### P226 · After the tap, the message names the day, the person and the task · A · M
- **UX-1703** (S2) «4 tareas movidas al jue, 22 oct». When tasks land on several days, the message adds «· también en otros 4 días», as a spoken save does.
- **UX-1710** (S1) «2 tareas asignadas a Paul» instead of «2 tareas cambiadas»; two completions read «Marcar 2 tareas como hechas» instead of «Guardar cambios»; Catalan says «per fer» and English “to do”, as the rest of the app does.
- **UX-1711** (S1) A task marked done by voice lands on its day, ticked and lit, with «Completada: Ir a la peluquería».

#### P227 · The tap and Deshacer don't wait or flicker · A · M
- **UX-1707** (S2) «Deshacer» after a voice deletion brings the result back at once, without waiting for the server.
- **UX-1714** (S1) The card holds still while it applies and closes: no recount, and no «No queda nada por revisar» on the way out.

#### P228 · Words that fit how many tasks · A · M · after P224
- **UX-1709** (S1) «Ya están así.», «No se eliminarán», «Solo puedes ver «Matemáticas»: sus tareas no cambian.», «No tiene fecha: no se mueve.» and «Ya estaba hecha.» Its fifth item waits on D1.

## Skipped
None.

## Notes
- **For the main session.** Backend/ is outside this run while another session works there.
  - After P224, update the contract's quote of the too-many line (`Backend/docs/VOICE_COMMANDS.md`, «More than 200 matches»).
  - After P226, its «After the tap» example («5 tareas movidas · Deshacer») names the day when the tasks land on one day.
  - An ambiguous person in a set's filter gets no candidates from the server, so the card keeps «Hay varias personas que se llaman …». That cause is server-side, and nothing is planned for it.
  - D1 and D2, once answered, change the contract's text.
- **IDs.** Review A's Q1 and Q2 had no IDs. They are UX-1715 (D1) and UX-1716 (D3) in `ISSUES.md`, and the organizer set their severities.
- **The organizer's readings, for the reviewer to check:**
  - P226 counts a deadline-only task's deadline day as its landing day, as a plain save has done since UX-902;
  - P225's question chips stay after a tap, with the tapped one selected, as the change card's chips for two people with one name do; and the asking card's first line reuses «Tareas con «…»» or «Tareas de «…»»;
  - P228 writes the Catalan singular «No se suprimirà», not «No es suprimirà», as the catalog writes «se» before s- elsewhere; a native read is welcome;
  - UX-1709's fifth item waits on D1.
- **Progress against UX_REVIEW.md** (from review A):
  - §7 task 4, «Mark "buy bread" as done», now works by voice in 3 taps, and moving a day's tasks takes 3 taps for all of them.
  - U5 advanced for sets (a move lands lit on its day), and stays open for UX-1703 and UX-1711.
  - U4's fix-by-touch doesn't reach command cards (D3).
  - U7 regressed slightly (UX-1705).
  - U1–U3, U6 and U8–U14 are untouched by dc17ab1, so their ledger lines are unchanged.
- **Phone checks** (in each package's `deviceChecks`):
  - TalkBack on a set card;
  - a real microphone for «Pasa todas las tareas de ayer a mañana», «Marca como hechas todas las de hoy» and «Ya he llamado al dentista»;
  - the landing after a set move at 1.3× and 2×;
  - Deshacer after a set deletion on a throttled connection;
  - a screen recording of the sheet closing after «Mover 4 tareas»;
  - and, for the main session with the real model, «Pasa todo lo de mates a mañana».
- **Ledger.** UX-1701 to UX-1714 are filed as open (UX-1702 as a decision), and UX-1715 and UX-1716 as decisions. U4, U5 and U7 carry review A's status. After the run, regenerate `PHONE_CHECKS.md` (`python -I -X utf8 .claude/ux-review/phone_checks.py`).

## Round 2

Round 1 (P224–P228) passed its round check, no test failed, and review A found every finding fixed. Round 2 fixes the two regressions review A found, in one small package. Nothing is escalated, and there's no new owner question. Full brief: `plan-r2.json`.

### P229 · S2 · A · S · A set's ✕ says it in the plural while it asks its project, and a set deletion after another card is brought into view at its heading
- **UX-1718 (S2), regression R1A-2 from P224:** P224 stopped the sheet scrolling to a set deletion so that a lone one opens at its heading, but that skips every set deletion. After «Apunta comprar pan y borra todas las completadas de la semana pasada», the red card sits below the fold at large text while the button reads «Añadir y eliminar». Now a set deletion is revealed again, with its heading at the top of the view (`alignment: 0`). A one-task deletion keeps its old reveal. A lone set is already at the top, so it still opens at «Eliminar 3 tareas». Inferred from the code; no preview covers this mix.
- **UX-1717 (S1), regression R1A-1 from P225 and P228:** ✕ on a set that still asks «¿Qué proyecto?» says «No se cambiarán» / «No se eliminarán» / «No se completarán» (CA «No es canviaran» / «No se suprimiran» / «No es completaran»), not the singular. No new copy.
- **Settled here:** in a mixed result, the new task's card scrolls up out of view, so the deletion is the part shown. The button names both actions, and the task card is one scroll up.

### Phone checks added
- P229: at Android's largest font, «Apunta comprar pan y borra todas las completadas de la semana pasada» opens with «Eliminar N tareas» and its ✕ at the top of the sheet.

### Notes for the main session (from round 1's implementers)
- `Backend/docs/VOICE_COMMANDS.md` needs its quotes updated:
  - the too-many line becomes «Son {count} tareas, demasiadas. Vuelve a decirlo con un día o un proyecto.» (P224);
  - the «After the tap» example becomes «N tareas movidas al <weekdayDate>», «… · también en otros N días», «N tareas asignadas a Paul» and «Completada: <title>» (P226);
  - the card spec could add «¿Qué proyecto?» (P225).
- P228: a native Catalan read of «No se suprimirà» / «No se suprimiran» is still welcome.
- Known edge, not a regression (P227): if Deshacer is tapped in the ~300 ms while the closing sheet is still mounted, the result is restored into the closing sheet. It is left open: nobody has reported it as a finding.

## Round 3

Round 2 (P229) passed its round check, no test failed, and review A found UX-1717 and UX-1718 fixed (`verify-r2-A.md`). Round 3 fixes the one regression that review found, in one small package. Nothing is escalated, and there's no new owner question. Full brief: `plan-r3.json`.

### P230 · S2 · A · S · Answering a deletion set's project keeps its heading and ✕ in view
- **UX-1719 (S2), regression R2A-1 from P229:** on a deletion set that asked «¿Qué proyecto?», tapping «Matemáticas» scrolls the question box, not the card, to the top of the view. At large text, «Eliminar N tareas» and its ✕ go out of view just as the delete button becomes active. Now `_reveal` brings the card itself to the top for a set deletion. Verified in code; no preview covers this state.
- **UX-1718 and UX-1717:** fixed in round 2. They are listed again only so the reviewer re-checks them, because this change touches UX-1718's reveal. The workflow passed them as "not checked by the reviewer", but `verify-r2-A.md` marks both fixed.

### Phone checks added
- P230: at Android's largest font, with «Matemáticas» and «Matemáticas II» both holding completed tasks, say «Borra todas las completadas de mates» and tap «Matemáticas». «Eliminar N tareas» and its ✕ stay at the top of the sheet. This needs the real model, so it's for the main session.

### Notes for the main session
- P229's implementer saw `App/test/capture_landing_test.dart`'s UX-1628 test fail (resuming 31 minutes after a Friday landing; Expected 0.0, Actual 50.0), with and without its change, on the real clock near midnight. The round check passed later. That test starts from `DateTime.now()`, so 31 minutes can cross midnight. Re-run it in the daytime:
  - if it passes, the test needs a fixed clock;
  - if it fails only across midnight, it may be a real edge of UX-1628's new-day return, and needs a Calendar (area B) review.
  No package plans it; it is outside this run's changes.

---

## Round 2 (d) — plan 2, 2026-10-22

Round 1 of plan 2 built P232 (D2, with your D4) and P233 (the day chip), and review A found both sound. P231 (D1) and P234 (the Voz privacy line) never ran: their worktrees were made from `main` (50afe7a), not `dev`. Round 2 runs them again as P235 and P236 and fixes round 1's two small regressions. Nothing is escalated, and there's no new question for you. Full briefs: `plan-d-r2.json`.

**Order:** P235 and P236 side by side, then P237.

### P235 · S2 · A · M · A voice move of a task with only a deadline moves its deadline (D1), and an overdue task moved earlier lands where it went
- **UX-1715** (S2, failed once, not attempted): P231 again. «Pasa la factura del gas a mañana» moves the deadline of a task with only a deadline, the button reads «Cambiar fecha», and the message reads «Movida al …». A time said for it goes on its deadline. Last time: the worktree was on 50afe7a, without `command_plan.dart`, so nothing was changed. This time the brief starts with a check of the worktree.
- **UX-1702** (S2, partly): D2 is built. The one check left, «Pasa todo lo de hoy a mañana» moving B by its deadline, passes once D1 lands. The test is already written.
- **UX-1716** (S2, partly): the chip is built on both cards. The one check left, the chip on the «Fecha límite» line of a task with only a deadline, passes once D1 lands. A day picked there then stays a «Fecha límite» change, instead of flipping to «Fecha y hora: Sin fecha → …».
- **UX-1721** (S1, your D4, built by P232): re-checked with this round, since the landing fix below finishes it.
- **UX-1723** (S1, new, regression R1A-2 from P232): «Adelanta todo lo de hoy un día» sends the overdue tasks to yesterday, but Calendar landed as if they were on Today. Now a task lands on Today only when its day didn't change.

### P236 · S1 · A · S · beside P235 · The Voz privacy paragraph says in plain words why your words go to Google
- **UX-1720** (S1, failed once, not attempted): P234 again, with the same copy: «Para añadir, buscar o cambiar tareas, tus palabras van por internet a la IA de Google.» Last time: the worktree was on 50afe7a, with no `App/lib/l10n/`.

### P237 · S1 · A · S · after P235 · The ▾ on the day, project and person chips grows with the text
- **UX-1722** (S1, new, regression R1A-1 from P233): at 2× the ▾ on the day chip stayed 18 dp, a speck beside a two-line label. One small `DropDownMark` grows it with the text, up to 28 dp, on the day chip and on the project and person chips, so all three look the same.

### Phone checks added
- Main session, real model: «Adelanta todo lo de hoy un día» comes back as a «hoy» set with `shift_days: -1` (P235).
- Your phone at the largest font: the ▾ on the day chip is easy to see, and the form's project and person chips match it (P237).

### Notes for the main session
- **Worktrees:** create each one from the commit the main checkout has checked out (dev, 1cfc622), not `main`, and seed the uncommitted P232/P233 work into it. Both blocked implementers suggest that `waves.py seed` check the worktree's HEAD against the main checkout's HEAD before it copies anything. Discard round 1's P231 and P234 worktrees.
- **Failure count:** UX-1715 and UX-1720 count one failure each, though no fix was tried. A second failure escalates them to you.
- **D4:** the contract already says it (`Backend/docs/VOICE_COMMANDS.md:208`). P232's implementer asked about this; nothing is left to do.
- **From ux-tester:** a `Task` can't be a note with a date, so the acceptance item «a note dated yesterday» used a note with no day. H, in a view-only shared project, enters a set only when it is assigned to the person.
- **From P232/P233's implementers:** `dart format` on all of `lib` was undone file by file, and the diff holds only the packages' changes. Some files in the repo aren't `dart format` clean (`task_matcher.dart`'s `_completed`, five spots in `commands_previews.dart`). Those were left as they were.

## Round 3 (d) — plan 2, 2026-10-22

Round 2 built P237 (the ▾ grows with the text) but it cut the time from the Catalan day chip at 2×. P235 and P236 never ran, again: both worktrees were made from `main` (50afe7a). Round 3 fixes P237's regression and splits out the one piece of P235 that doesn't wait on D1. The rest goes to you as escalations. Full briefs: `plan-d-r3.json`.

**Order:** P238 and P239 side by side. They share no file. Run them in the main checkout, or in worktrees on its HEAD.

### P238 · S2 · A · S · The day chip's ▾ takes no more room than before, so the Catalan time shows again
- **UX-1724** (S2, new, regression R2A-1 from P237): in Catalan at 2×, one task's chip read «dc., 28 / d’oct. · …» and the time was cut off. The larger ▾ took 23 dp of the row, where the old one took 18. Now `DropDownMark` reserves 18 dp at every size; the visible triangle fits inside that space. As a safety net, the chip's label can take 3 lines, because Catalan's «de febr.» and «de set.» are longer than «d’oct.».
- **UX-1722** (S1, partly, failed once): the size steps and the project and person chips already pass. I've withdrawn P237's acceptance 4 («as tall as the lowercase letters»). The glyph and the 28 dp cap stay: a bigger ▾ would take space from the label, and that's exactly what broke the Catalan chip. Your phone check at the largest font decides whether it's visible enough.

### P239 · S1 · A · S · beside P238 · Overdue tasks moved by a «hoy» set land where they went; D4's move by days is tested
- **UX-1723** (S1, failed once, not attempted): «Adelanta todo lo de hoy un día» now lands on yesterday, where the tasks went, without «también». Round 2's rule (compare the task's day before and after) had a gap: a task overdue since yesterday, moved back a day, would still land on Today. The new rule: the overdue tasks of a set that moves them to a day, or by days, land where they went. Those changed in place or marked done land on Today.
- **UX-1721** (S1, your D4, built by P232): no code. The tests check «Retrasa todo lo de hoy un día», including a task with only a deadline.

### Escalated to you
These failed twice, but no fix was ever tried. Each time the worktree was on `main` and the implementer stopped before editing anything. The briefs stand as written in `plan-d-r2.json`.
- **UX-1715** (S2, D1): a voice move of a task with only a deadline moves its deadline. Tried as P231 and P235; neither ran. `command_plan.dart` is unchanged.
- **UX-1702** (S2): D2 is built. Its last check, «Pasa todo lo de hoy a mañana» moving B by its deadline, waits on UX-1715.
- **UX-1716** (S2): the chip is built on both cards. Its last check, the «Fecha límite» chip on a task with only a deadline, waits on UX-1715.
- **UX-1720** (S1): the Voz privacy sentence. Tried as P234 and P236; neither ran. It's three ARB sentences and one description.
- **My recommendation:** run P235 once more in the main checkout, as P237 was, after P238 and P239. Drop its UX-1723 paragraph and acceptance item, which are now P239. Run P236 unchanged; it shares no file with this round. Better still, first make `waves.py` base new worktrees on the main checkout's HEAD.

### Phone checks added
- Your phone, in Catalan at the largest font: one task's change card shows the whole day and time on the day chip (P238).
- Carried over: the ▾ is easy to see at the largest font (P238); the real model returns «Adelanta…» and «Retrasa todo lo de hoy un día» as a «hoy» set with `shift_days` −1 and 1 (P239).

### Notes for the main session
- Six tests will keep failing until P235 and P236 run: the two round 1 P231 tests (UX-1702's B, UX-1716's deadline-only chip) and the four UX-1720 tests in `voice_privacy_copy_test.dart`. You could list them in `KNOWN_FAILURES.md`, pointing to these escalations, so round 3's check only judges P238 and P239.
- P235's other edits to `voice_task_screen.dart` (`_onlyMoved` and `moving`, :378-385 and :3682) are well away from P239's lines (:3655-3666).

## Round 2 (e) — 2026-10-22

Round 1 (e) built P235 (D1: a voice move of a task with only a deadline moves its deadline), P236 (the Voz privacy sentence) and P239 (overdue tasks moved by a «hoy» set land where they went). The check passed, no test failed, and the reviewer found nothing left unfixed. One regression: with D1 built, a moved deadline-only task ends on a Calendar row that starts with «Sin fecha». Full brief: `plan-e-r2.json`.

### P240 · S2 · A · S · after P235 · A row with a deadline doesn't say «Sin fecha»
- **UX-1725** (S2, new, regression R1A-1 from P235): after «Pasa todas las tareas de ayer a mañana», the gas bill's row read «Sin fecha   Vence vie, 23 de oct» right above «4 tareas movidas al vie, 23 de oct». The fix removes words: a row whose task has a deadline no longer says «Sin fecha», because its «Vence …» line already says when it's due. One condition in `task_tile.dart:48`, no new copy. This also applies on Tareas and project pages. A task with no date and no deadline still says «Sin fecha».

### Phone checks added
- None.

### Notes for the main session
- P240 shares only `App/test/ux_previews/commands_previews.dart` (one description) with round 1's work, so it builds on the uncommitted working tree.
- Round 1's implementers said the seed's `flutter pub get` regenerated the plugin registrants under `App/linux`, `App/macos` and `App/windows`, and that `App/pubspec.yaml`, `App/scripts/build-staging.ps1` and `plan-e.json` came in already staged from another session. None of those belong to this run's commit.
