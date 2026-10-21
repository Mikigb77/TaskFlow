## UX review — Area A: voice capture, bulk voice commands, app half (dc17ab1) — 2026-10-21

**Verdict:** Ship after fixes. A day's tasks now move, finish or go in 3 taps, and the card reads clearly at 1× and 2× in Spanish and Catalan. Before shipping, fix three things:
- the person can't check the interpretation where it matters most: on a set deletion, done and pending tasks look the same, and shared tasks aren't marked (UX-1701);
- «todas las de hoy» quietly skips the «Atrasadas» that Today lists (UX-1702);
- after a move, nothing says which day the tasks went to (UX-1703).

One rule needs the owner: a task with only a deadline, moved «a mañana», still reads «Fecha límite vencida» in red (Q1).

**Walked** (newcomer: Spanish, 2× text, one hand; daily user; TalkBack user, from AUDIT.md):
- **Move a set to a day:** «Pasa todas las tareas de ayer a mañana». Añadir tarea → speak → Listo → «Mover 4 tareas» → Calendar on Thursday, rows lit, «4 tareas movidas · Deshacer». 3 taps, +1 per untick. Deshacer puts every task back and reopens the result.
- **Move a set by days:** «Pasa lo de esta semana a la semana que viene» → «Mover 3 tareas una semana después». 3 taps. From the code and `bulk_voice_commands_test.dart:1096`; no render.
- **Assign a set:** «Asigna a Paul todo lo del viernes» → «Asignar 2 tareas a Paul», with the left-out line. 3 taps.
- **Other changes to a set:** «Cambiar 2 tareas», with «Hora: 18:00 · Prioridad: Alta». From the code and the test; no render.
- **Mark a set done:** «Marca como hechas todas las de hoy» → «Marcar 4 tareas como hechas»; a repeating class's repetition today is in the list. 3 taps.
- **Delete a set:** «Borra todas las completadas de la semana pasada» → the red card and «Eliminar 3 tareas». 3 taps.
- **Unticking:** the count changes live in the heading and on the button. With every task unticked, «Eliminar 0 tareas» is disabled (test `:1387`).
- **States with nothing to apply:**
  - nothing matched («No hay tareas pendientes de ayer», render);
  - over 200 matches;
  - only view-only tasks;
  - every task already as asked;
  - only repeating tasks matched;
  - a project or a person not found or ambiguous;
  - a change that said nothing to change. That state lists the tasks under «Tareas», like a search. The server drops such commands (contract, «Nothing left to change»), so it shouldn't reach anyone.

  Apart from the render noted above, these come from the code and the tests.
- **One task marked done:** «Ya he ido a la peluquería» → «Marcar como hecha» → «Tarea completada · Deshacer». 3 taps. I also walked it with the task already done, not found, matching several tasks, and taken out with ✕.
- **Single-task cards and plain capture:** they read as before. The diff only touches the commands branch of the button label, and the plain-task path (`_save`) is untouched. Re-checked on current renders: `commands/cards.change`, `cards.mixed`, `applied.change-applied`, `applied.mixed-applied` and `capture/result.one-task` (all 20:31).

**Numbers:**
- **Taps to move a day's tasks to another day:** 3, +1 per untick. Before: one voice command per task (3 taps each, so 12 for 4 tasks), or ≈ 3–4 taps per task by hand.
- **Taps to mark a task done by voice:** 3. This wasn't possible by voice before.
- **Tap targets on a 4-task move result:** 9 (✕, 4 rows, «Ver lo que dije», «Mover 4 tareas», «Cancelar», «Volver a decirlo»). Each row is 286 × 72 dp (AUDIT).
- **Words at the decision point, Spanish, 4 tasks:** ≈ 45 (heading 6, rows ≈ 36, button 3). 1 decision, +1 per untick.
- **At 2× on 360 dp:**
  - the move card shows its heading and 1 of 4 tasks above the pinned button;
  - the delete card opens scrolled past its own heading (UX-1704).

**How I looked:**
- `.claude/ux-review/GUIDELINES.md` is present, and I reviewed against it.
- **Renders:** `App/build/ux/commands/*` and `capture/result.*`, rendered 20:31 from the working tree that became dc17ab1 at 20:33. `find App/lib App/assets -newer <png>` lists nothing, so they're current. I read AUDIT.md with them.
- **Device captures:** none this run (in-app cards only).
- **No render, so judged from the widget code and the tests:** the shift, «Cambiar N tareas», too many, view-only, ambiguous and completion-not-found states. Each finding says which.

### Findings (most severe first)

**UX-1701 · Severity 2 · Set rows hide done state, project and person**
- **Where:**
  - `App/lib/widgets/capture_command_cards.dart:1727-1745`: the `row()` of `BulkCommandCard`. Its second line is the day only, «Completada» is dropped when `target.status == 'completed'`, and titles are never struck through;
  - compare `_FoundRow`, `:753-835`: day · project · person · «Completada», with struck done titles;
  - renders `cards.bulk-delete` (es 1×, 2×) and `cards.bulk-left-out` (es 1×, ca 2×).
- **The moment:** «Dije "las completadas"… estas no parecen hechas. ¿Voy a borrar las que tengo pendientes?» And: «¿Estas son de Matemáticas, las que ve todo el grupo?»
- **What happens:**
  - «Borra todas las completadas de la semana pasada» lists three tasks that look exactly like pending ones, under a heading that says only «Eliminar 3 tareas».
  - If «completadas» had been misheard as pending, the card would look the same. So the one word that decides which tasks go can't be checked before the red tap.
  - Rows never show the project or the person. «All my tasks» includes tasks assigned to the person in shared projects (DECISIONS, 2026-10-21), and deleting one of those removes it for everyone in the project.
  - «Asignar 2 tareas a Paul» lists «Preparar el examen del tema 6» without «Matemáticas». So nothing hints why the other two «no se pueden asignar a Paul».
- **Why it fails:**
  - VO-5: show what was understood (Budiu & Laubheimer 2018);
  - VO-8: name the affected tasks before a deletion;
  - SH-6: voice changes to shared tasks say whose they are (EDPB VVA 2021);
  - SC-9: the same task is shown differently on the find card.
- **Fix:** subtract the special case and reuse the find row.
  - Each set row's second line becomes what `_FoundRow` shows: the day, the project, the person when the project is shared, and «Completada».
  - Done titles are struck through, whatever status was asked.
  - No new copy.
- **Verify:**
  - the bulk-delete preview reads «mar, 13 de oct · 17:00 · Completada» with struck titles;
  - bulk-left-out reads «vie, 23 de oct · 10:00 · Matemáticas · Yo»;
  - widget tests for both;
  - ES and CA at 2×: rows wrap and nothing clips.
- **Evidence:** seen in current renders; verified in code.

**UX-1702 · Severity 2 · «Todas las de hoy» skips the overdue tasks Today lists**
- **Where:**
  - `App/lib/services/task_matcher.dart:362`: a set drops every task dated before `from`;
  - `:323`: a one-day completion takes only that day's repetitions;
  - compare Today's «Atrasadas · N» (`App/lib/screens/calendar_screen.dart:437-457`), the Tareas «Hoy» filter (`App/lib/screens/home_screen.dart:135`), and this change's own one-task completion, which takes «the one Today lists as overdue» (`task_matcher.dart:184-192`).
- **The moment:** «Tengo seis en Hoy y me dice "Marcar 4 tareas como hechas". ¿Y las dos de arriba?» The next morning the two «Atrasadas» are still there.
- **What happens:**
  - D1 put unfinished tasks from earlier days into Today. They show under «Atrasadas · N» and count in «pendientes» and in the «Hoy» filter.
  - A set «de hoy» (from = to = today) keeps only tasks dated today.
  - So «Marca como hechas todas las de hoy» and «Pasa todo lo de hoy a mañana» leave the overdue tasks behind, and no line mentions them.
  - A single «Ya he…» does take Today's overdue repetition, so the two new paths disagree.
- **Why it fails:**
  - match with the real world, and consistency (Nielsen 1994): «hoy» is what Today shows (D1);
  - CO-3: the person has to reconcile a count with a list they can't see.
- **Fix:**
  - When a set's period is exactly today, add the open tasks Today lists as overdue (`Task.overdueOn(today)`). A repeating one comes in as its latest missed repetition when marking done, and is left out and counted otherwise, as now.
  - List them first, as Today does, with the existing day line «mar, 20 de oct · Atrasada» (`overdueDate`), ticked, so any can be unticked.
  - No new copy.
  - If the organizer reads this as changing the contract's period rule, it becomes a D#, with this as the recommendation.
- **Verify:** widget test with 2 overdue and 3 of today's tasks: «Marcar 5 tareas como hechas», two rows read «… · Atrasada», and after the tap Today shows no «Atrasadas».
- **Evidence:** verified in code. No render has a set with overdue tasks.

**UX-1703 · Severity 2 · After a set moves, no day is named**
- **Where:**
  - `App/lib/screens/voice_task_screen.dart:3624-3653`: the message is `commandTasksMoved(n)`, with no day and no «también…»;
  - compare the plain-save path `:3164-3175` (`captureAlsoOn`, `captureAlsoOnDays`) and a single move, «Movida al mié, 28 de oct»;
  - render `applied.bulk-applied.es.light.1x`.
- **The moment:** «Las veo marcadas… pero ¿en qué día estoy? ¿Y las otras, adónde han ido?»
- **What happens:**
  - After «Mover 4 tareas», Calendar scrolls to the 4 lit rows.
  - The day heading «jueves, 22 de octubre» and the week strip are above the fold (AUDIT lists them off screen). The message says only «4 tareas movidas».
  - After a move by days, the tasks land on up to 7 days. Calendar shows the earliest, and nothing says the rest went elsewhere, unlike a spoken save («… · también en otros 2 días»).
- **Why it fails:**
  - SC-10 and SC-11: show the change where the user looks, and end on visible success (Rensink et al. 1997; Kahneman et al. 1993);
  - CO-3;
  - U5;
  - SC-9: the single move and plain saves both name the day.
- **Fix:**
  - **All on one day:** a new ICU string `commandTasksMovedTo`, with `{date}` = `weekdayDate`.
    - ES «{count, plural, =1{Tarea movida al {date}} other{{count} tareas movidas al {date}}}»
    - EN «{count, plural, =1{Task moved to {date}} other{{count} tasks moved to {date}}}»
    - CA «{count, plural, =1{Tasca moguda al {date}} other{{count} tasques mogudes al {date}}}»
  - **Several days:** add the existing `captureAlsoOnDays`, as `_save` does: «5 tareas movidas · también en otros 4 días».
  - Any command result whose landed tasks span several days gets the same «también…».
- **Verify:**
  - the bulk-applied preview reads «4 tareas movidas al jue, 22 de oct»;
  - a shift preview ends «· también en otros N días»;
  - CA at 2×, the message fits in 3 lines.
- **Evidence:** seen in a current render and in AUDIT.md; verified in code.

**UX-1704 · Severity 2 · At large text, a set deletion opens past its heading**
- **Where:**
  - `App/lib/screens/voice_task_screen.dart:2677-2678`: `_firstOpen` reveals «the task the button deletes»;
  - `:2727-2738`: `_reveal` uses `alignment: 1`;
  - render `cards.bulk-delete.es.light.2x`.
- **The moment:** «Veo "biblioteca" cortado y un botón rojo… ¿qué va a borrar?»
- **What happens:**
  - At 2× the sheet opens scrolled to the bottom of the red card. «Eliminar 3 tareas», the ✕ and the first task's title are above the view, and the first text visible is the tail «biblioteca».
  - The rule was made for a one-task deletion card, which fits on screen. A set's card is taller than the view at large text.
  - The move and complete cards open at their heading (their 2× renders), so only the destructive card hides what it's about.
- **Why it fails:**
  - SC-5: key content on the first screen;
  - VO-8: name what will be deleted;
  - AC-3;
  - recurring problem 13 (content off-screen at large text).
- **Fix:** subtract: leave sets out of that reveal (`&& view.bulk == null` at `:2678`). The sheet then opens at the card's heading, like the other set cards.
- **Verify:**
  - the bulk-delete es 2× render shows «Eliminar 3 tareas» and the ✕ at the top;
  - widget test: at 2× the headline is on screen when the result opens.
- **Evidence:** seen in a current render; verified in code.

**UX-1705 · Severity 2 · «Ya he…» with no match offers «Guardar como tarea»**
- **Where:**
  - `App/lib/screens/voice_task_screen.dart:4082-4092`: `asWritten` needs every view to be `notFound`, and `notFound` now includes `complete` (`App/lib/widgets/capture_command_cards.dart:78-84`);
  - the card's header is the green done-check (`:1352`, `:1357-1360`).
- **The moment:** «Le he dicho que ya he llamado… ¿y me ofrece guardarlo como tarea? ¿Me va a apuntar "Ya he llamado al dentista" como pendiente?»
- **What happens:**
  - «Ya he llamado al dentista» with no matching task shows «No encuentro ninguna tarea con «dentista»» beside a green check icon.
  - The only filled button is «Guardar como tarea». It saves the sentence as a new, undone task under «Sin fecha».
  - That fallback (UX-901) was for a task misread as a change («Cambia el aceite del coche»). A past-tense "I did it" is never a task to add.
- **Why it fails:**
  - SC-4, the isolation effect (von Restorff): the filled button looks like the next step;
  - error prevention (Nielsen 1994);
  - UN-8: a no-match state's way forward must fit what was asked.
- **Fix:**
  - Leave `complete` out of `asWritten`, so only a change, a deletion or a search that found nothing offers it. This card then offers «Cerrar» and «Volver a decirlo».
  - Head a completion that found nothing with the find card's search icon, not a green tick.
- **Verify:**
  - widget test: a `complete` command with no match has no `result-save-as-written`;
  - add a commands preview for this state.
- **Evidence:** verified in code; no render.

**UX-1706 · Severity 2 · Left-out tasks are counted, never named**
- **Where:**
  - `App/lib/widgets/capture_command_cards.dart:1522-1545` (`_bulkLeftOut`);
  - ARB `commandBulkLeftRepeating`, `commandBulkLeftUnassignable`, `commandBulkLeftNoDay`;
  - render `cards.bulk-left-out.es.light.1x`.
- **The moment:** «¿Cuál se repite? ¿Y qué dos no se pueden asignar a Paul?»
- **What happens:**
  - «1 tarea que se repite no cambia · 2 tareas no se pueden asignar a Paul». Those tasks aren't in the list, so the person can't tell which stayed or deal with them, for example by moving the class by hand.
  - After «pasa todo lo de ayer a mañana», the unnamed daily task comes back in Today as «Atrasada».
- **Why it fails:**
  - recognition over recall (Nielsen 1994);
  - CO-3: nothing to hunt for;
  - UN-7: say what happened in terms the person can act on.
- **Fix:** name the task when exactly one is left out for a reason, and keep the count from two. Only the `=1` case of each plural changes, and `{title}` is added:
  - ES «{title} se repite: no cambia» / «… no se elimina» / «… no se completa»; «{title} no se puede asignar a {name}»; «{title} no tiene fecha: no cambia».
  - EN "{title} repeats: it won’t change" / "won’t be deleted" / "won’t be completed"; "{title} can’t be assigned to {name}"; "{title} has no date: it won’t change".
  - CA «{title} es repeteix: no canvia» / «no se suprimeix» / «no es completa»; «{title} no es pot assignar a {name}»; «{title} no té data: no canvia».
- **Verify:** the bulk-left-out preview reads «Natación se repite: no cambia · 2 tareas no se pueden asignar a Paul».
- **Evidence:** seen in a current render; verified in code.

**UX-1707 · Severity 2 · Deshacer of a deletion waits for the server**
- **Where:**
  - `App/lib/providers/task_provider.dart:274-285`: `restoreTasks` ends with `await loadTasks()`, which awaits `_repository.sync()` (`:54`);
  - it's called from `App/lib/services/command_runner.dart:208-216`;
  - the result reopens only afterwards, in `App/lib/screens/voice_task_screen.dart:3720-3801`.
- **The moment:** on a slow connection: «He dado a Deshacer… no pasa nada.» Then, about 12 s later: «¡Ay! ¿Qué es esto que ha salido?»
- **What happens:**
  - Deshacer after any voice deletion, one task or a set, restores the tasks on the phone. It then waits for a full server sync before `undoSave` and before the result sheet reopens.
  - Calendar shows the tasks back quickly, because the load reads the phone first.
  - The sheet pops up only when the sync ends: up to 12 s per request on a stalled connection (`App/lib/services/api_client.dart:628-637`), longer across several.
  - Undoing a move, a change or a completion doesn't wait: `updateTask` syncs behind.
- **Why it fails:**
  - UN-1 and PE-2 (Nielsen 1993);
  - recurring problem 18 (background work awaited in the tap path), and the standard set by UX-601: nothing on the network between a tap and its result;
  - a sheet appearing seconds later is an unannounced mode change (OL-4).
- **Fix:**
  - End `restoreTasks` with `showLocal()` instead of `await loadTasks()`: it reads the phone, shows the list, and syncs behind unawaited, as saves and `updateTask` do.
  - `undoSchedule` and `undoOccurrence` share the pattern for a single repeating task. That's not new in this change, but the same fix applies.
- **Verify:**
  - widget test with a sync that never completes (as `App/test/capture_landing_test.dart:610`): Deshacer after a set deletion reopens the result at once;
  - phone: the same on a throttled connection.
- **Evidence:** verified in code; inferred, needs a device check.

**UX-1708 · Severity 2 · Two similar projects read as «No encuentro el proyecto»**
- **Where:**
  - `App/lib/models/capture_command.dart:141-171`: `CommandTarget.fromJson` reads no `project_candidates`;
  - `App/lib/widgets/capture_command_cards.dart:1657-1659`: a set says «No encuentro el proyecto «…»»;
  - one task and a search say the same: `_notFound` `:949-961`, and `:651-655`;
  - the server sends the candidates beside `ambiguous_project`, for one task or a set (`Backend/core/voice_commands.py:285-296`, `:322-330`; contract, «Project candidates»).
- **The moment:** «¿Cómo que no encuentra "mates"? ¡Si tengo Matemáticas y Matemáticas II!»
- **What happens:** «Pasa todo lo de mates a mañana», with two matching projects, comes back as `ambiguous_project` with both candidates. The card says «No encuentro el proyecto «mates»» and offers only Cerrar and Volver a decirlo.
- **Why it fails:**
  - UN-7: the project was found twice, not missing;
  - VO-6: saying it again fixed 35% of recognition errors, against 75–87% by touch or typing (Suhm, Myers & Waibel 2001);
  - SC-9: since UX-1315, a project command offers the candidates as chips.
- **Fix:**
  - Read the target's `project_candidates`. With `ambiguous_project`, ask in a QuestionBox with one chip per candidate, as `ProjectChoices` does. A tap sets the project, and the set is worked out.
  - Copy: ES «¿Qué proyecto?», EN "Which project?", CA «Quin projecte?».
  - Do the same for searches and one-task targets, which share the cause.
  - A person who is ambiguous in a set's filter has no candidates from the server, so it keeps its line (cause server-side).
- **Verify:** widget test: candidates give two chips; tapping «Matemáticas» shows «Mover N tareas a mañana, …».
- **Evidence:** verified in the app and server code; no render.

**UX-1709 · Severity 1 · Single-task words on sets, set words on one task**
- **Where:**
  - `App/lib/widgets/capture_command_cards.dart:1718`, `:1697-1699`, `:1229-1230`, `:1387`;
  - `App/lib/screens/voice_task_screen.dart:3349-3355`;
  - `App/lib/services/bulk_plan.dart:194` with `App/lib/services/command_plan.dart:237-241`.
- **The moment:** «"Ya está así"… ¿el qué?» And: «¿"1 tarea sin fecha"? Si es esta.»
- **What happens and the fix:**
  - **A set already as asked** shows «Ya está así.» (singular). Use ES «Ya están así.», EN "They’re already like that.", CA «Ja són així.».
  - **✕ on a set** shows «No se cambiará» / «No se eliminará» / «No se completará» for several tasks. Make them count-aware:
    - ES «{count, plural, =1{No se cambiará} other{No se cambiarán}}», and likewise «No se eliminarán» and «No se completarán»;
    - CA «No es canviaran», «No se suprimiran», «No es completaran»;
    - EN stays as it is.
  - **A set of view-only tasks** names one task: ««Preparar el examen» es de un proyecto que solo puedes ver.» Name the project instead:
    - ES «Solo puedes ver «{project}»: sus tareas no cambian.»
    - EN "You can only view “{project}”: its tasks stay as they are."
    - CA «Només pots veure «{project}»: les seves tasques no canvien.»
  - **One task moved by days with no date** shows «1 tarea sin fecha no cambia» under its own title. Use ES «No tiene fecha: no se mueve.», EN "It has no date, so it stays.", CA «No té data: no es mou.».
  - **A new time for tasks that have only a deadline** counts them under «sin fecha», though they show «Vence …». Count them apart, or settle it with Q1.
  - **One task already done** shows «Ya está así.» Use ES «Ya estaba hecha.», EN "It was already done.", CA «Ja estava feta.».
- **Why it fails:**
  - recurring problem 9 (copy borrowed from another context);
  - plain language (ISO 24495-1);
  - SC-9.
- **Verify:** widget tests per string; `App/test/localization_catalog_test.dart`.
- **Evidence:** verified in code.

**UX-1710 · Severity 1 · Card, button and message name the action differently**
- **Where:**
  - `App/lib/screens/voice_task_screen.dart:3644-3653` (messages) and `:4133-4144` (button);
  - ARB `commandBulkNone` and `commandBulkPeriod` in ca and en.
- **What happens and the fix:**
  - **Assigning a set.** The card says «Asignar 2 tareas a Paul», but the message says «2 tareas cambiadas». Use:
    - ES «{count, plural, =1{Tarea asignada a {name}} other{{count} tareas asignadas a {name}}}»
    - EN «{count, plural, =1{Task assigned to {name}} other{{count} tasks assigned to {name}}}»
    - CA «{count, plural, =1{Tasca assignada a {name}} other{{count} tasques assignades a {name}}}»
  - **Two or more one-task completions.** The button reads «Guardar cambios». When every actionable command marks tasks done, use `commandBulkComplete(total)` («Marcar 2 tareas como hechas»), as a set does.
  - **Naming the tasks still to do.**
    - Catalan says «No hi ha tasques pendents …», while the rest of the app says «per fer» (agenda, search). Use «No hi ha tasques per fer …».
    - English says «There are no unfinished tasks …», while the app says "to do". Use "There are no tasks to do …", and «for today» instead of «from today».
- **Why it fails:**
  - SC-9;
  - UN-4: buttons name the outcome;
  - recurring problem 2 (messages name the action, not the result).
- **Verify:**
  - widget test: the assignment message names Paul;
  - two completions read «Marcar 2 tareas como hechas»;
  - catalog test for ca and en.
- **Evidence:** verified in code and strings.

**UX-1711 · Severity 1 · A task marked done by voice isn't shown or named**
- **Where:** `App/lib/screens/voice_task_screen.dart:3680-3705`, where the landing ids come only from added and changed tasks, and `:3654-3655`.
- **The moment:** «¿Lo ha marcado? No lo veo.»
- **What happens:**
  - «Ya he ido a la peluquería», a Saturday task, then «Marcar como hecha». The sheet closes on whatever day Calendar showed, with «Tarea completada · Deshacer».
  - The task isn't in view, and the message doesn't name it.
  - A change, by contrast, lands lit on its day.
- **Why it fails:**
  - lens B: after completing, the user sees the item where it is;
  - SC-10;
  - UN-2: a snackbar isn't proof (Flaherty 2024).
- **Fix:**
  - Land completed tasks the way changed ones land: their ids and days go into the `CalendarFocus`, so Calendar shows the ticked row, lit.
  - For one task, say «Completada: {title}», reusing the notification's existing `notificationCompleted`.
- **Verify:** widget test: completing a Saturday task by voice lands on Saturday with the row lit, and the message reads «Completada: Ir a la peluquería».
- **Evidence:** verified in code; no render after a completion.

**UX-1712 · Severity 1 · At 2×, the move heading splits «jue» from «22»**
- **Where:**
  - `App/lib/widgets/capture_command_cards.dart:1431`: `DateFormat('E d')` gives «jue 22» with a normal space;
  - render `cards.bulk-move.es.light.2x`.
- **What happens:** the heading wraps «Mover 4 / tareas a / mañana, jue / 22», leaving «22» alone on the fourth line.
- **Why it fails:** §20.8 (a day split from its date), AC-3, LO-1.
- **Fix:** join the weekday and the number with a no-break space (U+00A0), so «jue 22» wraps as one: «… mañana, / jue 22».
- **Verify:** the es 2× render keeps «jue 22» together.
- **Evidence:** seen in a current render.

**UX-1713 · Severity 1 · «Dilo con menos» doesn't say what to do**
- **Where:** ARB `commandBulkTooMany` in es and ca; `App/lib/widgets/capture_command_cards.dart:1663-1664`.
- **The moment:** «¿Con menos qué?»
- **What happens:** «Son 230 tareas. Dilo con menos, por ejemplo un día o un proyecto.» It's telegraphic, and the Catalan copies it word for word.
- **Why it fails:** plain language (ISO 24495-1: the reader can act on it); UN-7.
- **Fix:** name the button below and what to add:
  - ES «Son {count} tareas, demasiadas. Vuelve a decirlo con un día o un proyecto.»
  - CA «Són {count} tasques, massa. Torna-ho a dir amb un dia o un projecte.»
  - EN "That’s {count} tasks, too many. Say it again with one day or one project."

  The contract quotes the current Spanish wording; this keeps its meaning.
- **Verify:** `App/test/bulk_voice_commands_test.dart:1343` with the new text.
- **Evidence:** verified in code and strings.

**UX-1714 · Severity 1 · The result redraws from the changing list while closing**
- **Where:**
  - `App/lib/screens/voice_task_screen.dart:3054-3071`: `_views(watch: true)` re-resolves against the live task list;
  - `:344-374` (`_applySet`);
  - `:3546-3548` and `:3596`: the commands are marked done, then `showLocal()`;
  - `:3676-3679`: the sheet is popped.
- **What happens:**
  - During the writes, each `updateTask` reloads the list. So, under «Guardando…», the set card can recount («Mover 3 tareas…») and drop rows that have already moved.
  - Then the commands are marked done and the list refreshed, so the sheet slides away showing the empty result: «No queda nada por revisar · No se hará ningún cambio.»
  - The recount is new with sets; the empty result while closing affects every result.
- **Why it fails:**
  - VO-1: states never contradict each other;
  - the gulf of evaluation (Norman 2013): «no se hará ningún cambio» right after the tap.
- **Fix:** freeze the result once the confirming tap starts. Build from the views and drafts captured at the tap until the sheet is gone.
- **Verify:**
  - widget test: pump frames through the apply and the close, and assert the headline stays «Mover 4 tareas…» and `captureNothingToReview` never shows;
  - a screen recording on a phone.
- **Evidence:** inferred from code; needs a device check.

### Keep
- **The heading and the button agree.** The heading gives the action, the live count and the day; the button repeats the count («Mover 3 tareas»), and is disabled when every task is unticked. That's VO-8's named confirmation.
- **Deletion has one style everywhere.**
  - The edge, the heading, the ticks and the button are red, and nothing changes before the tap.
  - One Deshacer brings every task back, notes included (`App/test/bulk_voice_commands_test.dart:1239`).
- **Whole rows are the tick targets** (286 × 72 dp). The list scrolls inside the card at normal text and in the sheet at large text, so there's no cramped window at 2×.
- **What was left out is one quiet line after the list,** not a second list.
- **«Marcar como hecha» reads like a change card:** the title, the day, one verb button, and ✕ «No completar …». A repeating task completes today's repetition, as ticking it does.

### Progress against UX_REVIEW.md (U1–U14)
- **Advanced:**
  - §7 task 4 («Mark "buy bread" as done») now works by voice in 3 taps;
  - moving a day's tasks takes 3 taps for all of them;
  - U5 for sets: a move lands lit on its day.
- **Still open:**
  - U5: the landing day isn't named, other days aren't mentioned, and completions don't land (UX-1703, UX-1711);
  - U4's fix-by-touch doesn't reach command cards (Q2).
- **Regressed, slightly:** U7's «Guardar como tarea» now also offers itself for a completion that found nothing (UX-1705).
- **Untouched:** U1–U3, U6 and U8–U14.

### Questions for the owner
**Q1. A task with only a deadline, moved «a mañana», still reads overdue.**
This is the rule as designed; you've been told about it but haven't answered.
- **Evidence:**
  - «Pasa todas las tareas de ayer a mañana» listed «Pagar la factura del gas · Vence mar, 20 de oct» under «Mover 4 tareas a mañana, jue 22» (`cards.bulk-move`).
  - After the tap it sits on Thursday reading «Vence mar, 20 de oct · Fecha límite vencida», in red (`applied.bulk-applied`).
  - «Retrásalo todo un día» moves the same task's deadline instead (`App/lib/services/command_plan.dart:246-254`). So two ways of saying "move it" give two results.
  - The moment: «Le he dicho que la pase a mañana… ¿por qué sigue en rojo, vencida?» That's a gulf of evaluation at the end of the flow.
- **Options:**
  - (a) For a task whose only date is a deadline, a move to a day moves the deadline, as a move by days already does. One rule for both.
  - (b) Keep the rule, but say it on that row before the tap («Vence mar, 20 de oct · no cambia»), so the red line isn't a surprise.
- **Recommendation: (a).** For that task, the deadline is the only date the card and Calendar show, so it's what the person's words point at, and (a) matches the move-by-days rule. People who need both dates still have them in the form. The answer also settles UX-1709's "a new time for tasks with only a deadline". Reversible.

**Q2. Should a set's target day be fixable by touch?**
- **Evidence:**
  - If «a mañana» was misheard, the card's only fix is «Volver a decirlo»: a whole new dictation, and without Pro one of the 10 a month. The one-task change card has the same gap.
  - VO-6: saying it again fixed 35% of recognition errors, against 75–87% by touch or typing (Suhm, Myers & Waibel 2001). U4 made the result's date a tappable row for this reason.
- **Recommendation:** make the day in a move's heading a chip («mañana, jue 22 ▾») that opens the existing «Elegir día» sheet, with Hoy and Mañana. The count stays live. It adds one control to the card you specified, so it's your call.

### Phone checks (device only)
- TalkBack on a set card: each row is read as a checkbox («marcada» / «no marcada»). The new count is heard only on the button.
- A real microphone saying «Pasa todas las tareas de ayer a mañana», «Marca como hechas todas las de hoy» and «Ya he llamado al dentista».
- The landing after a set move at 1.3× and 2× (UX-1703).
- Deshacer after a set deletion on a throttled connection (UX-1707).
- A screen recording of the sheet closing after «Mover 4 tareas» (UX-1714).

### Memory notes
- **Screen map A, new section «Bulk commands» (dc17ab1, 2026-10-21):**
  - `BulkCommandCard` and `CompleteCommandCard` (`App/lib/widgets/capture_command_cards.dart`);
  - `planBulk` and `BulkPlan` (`App/lib/services/bulk_plan.dart`), and `TaskMatcher.bulk`;
  - `_applySet` and the message parts in `App/lib/screens/voice_task_screen.dart`;
  - `restoreTasks` (`App/lib/providers/task_provider.dart`);
  - the preview states in `App/build/ux/commands/cards.bulk-*` and `applied.bulk-applied`;
  - shift, change, too-many, view-only and ambiguous states have no render.
- **UI pattern, the set card:**
  - the heading is the action, the live count and the day (move);
  - the rows are ticked `CheckboxListTile`s with the title and the day;
  - one left-out line after the list;
  - the filled button carries the live count;
  - the list scrolls inside the card below 1.5× text and in the sheet from 1.5×;
  - the delete style is a red edge, heading, ticks and button;
  - afterwards: «N tareas movidas / cambiadas / completadas / eliminadas · Deshacer», and Deshacer reopens the result;
  - one completion: «Marcar como hecha» → «Tarea completada».
- **Set rules:**
  - pending by default;
  - the person's own tasks plus those assigned to them; other people's only with a project or person named;
  - repeating tasks are left out and counted, except when marking one day done;
  - view-only tasks, notes, and put-away projects not named are left out;
  - more than 200 matches gives no list.
- **New recurring types:**
  - a rule built for a small one-task card (`_reveal`, «Ya está así», ✕ messages) misbehaves on a tall set card or on many tasks;
  - the result re-resolves its views from the live list during apply and close.
- **Update recurring problem 18 with:** `restoreTasks` awaits `loadTasks()` and so the sync. `undoSchedule` and `undoOccurrence` do the same.
- **Doc vs decision:** the card copy in `Backend/docs/VOICE_COMMANDS.md` («Dilo con menos…», «Eliminar 6 tareas») is the main session's spec text, not an owner decision.
