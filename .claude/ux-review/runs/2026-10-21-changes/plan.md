# UX plan — 2026-10-21-changes (bulk voice commands, the app half; scoped run)

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
