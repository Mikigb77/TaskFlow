## UX review — A2 · The result (whole-app run 2026-10-28-app) — 2026-10-31

**Verdict:** Ship after fixes. The three-tap path (Añadir tarea → Listo → Añadir al calendario) and every voice command still land in the right place, but set cards hide tasks their button will change or delete, a voice deletion's Deshacer brings the red «Eliminar» card back, and several added tasks never name the day they landed on.

**How I looked** (guidelines.md present):
- **Renders:** `App/build/ux/{capture,commands,reminders,notes,calendar}/` with AUDIT.md, from 6281e3d, rendered 2026-10-28 17:56 to 2026-10-29 08:56. `find App/lib App/assets -newer` lists nothing for every render cited, and there are no uncommitted changes under `App/lib`, `App/assets`, `App/android` or `App/ios`. So they're current: widget-test evidence.
- **Device captures** (emulator, 30c8ce0): they don't show the AI result, because the review account is free and the lane spends no AI calls. Only the landing after a typed save (`capture.result`) is in A2's scope.
- **Code:** everything else, as each finding says. Contracts: `Backend/docs/VOICE_COMMANDS.md` and `REMINDER_PLANS.md`.

**Walked** (newcomer: Spanish at 1×, 1.3× and 2× on 360 dp; daily user, several dictations in a row; TalkBack user):
- **One dated task:** Añadir tarea → speak → Listo → «Añadir al calendario» → Calendar on its day, lit, «Añadida al vie, 30 de oct · Deshacer». 3 taps.
- **Morning or afternoon:** + 1 chip. 4 taps.
- **No day:** «Añadir tarea» → the «Sin fecha» row is lit. 3 taps.
- **Several tasks:** «Añadir 3 tareas» → lit rows, «3 tareas añadidas · también el vie, 30 de oct». 3 taps. The landing day isn't named (UX-2203).
- **Partial save** (one card still asking): «Añadir 2 tareas» → the sheet stays with the asking card, then Deshacer.
- **A reminder said:**
  - with a day, it's the «Recordatorio» row; 3 taps;
  - with no day, «Para recordártelo, ponle un día.» → Mañana → the row appears → «Añadir al calendario». 5 taps;
  - with reminders off on this phone, «Activar recordatorios»;
  - for several tasks, the reminder shows on the collapsed row.
- **Voice note:** Añadir nota → speak → Listo → «Guardar nota» → Notas, lit. 3 taps.
- **Commands:**
  - change: «Cambiar fecha», with the day chip; 3 taps;
  - «¿Cuál quieres cambiar?»: +1 row tap;
  - change with no day: «¿Qué día, a las 18:00?» → a chip;
  - other details;
  - delete → Deshacer → the red card again: 5 taps;
  - complete;
  - projects: new, existing, ambiguous;
  - find: results and none;
  - not found;
  - mixed;
  - sets: move, untick, pick a day, complete «hoy» with overdue tasks, delete, delete beside a new task, left out, none, view only, ambiguous project.
- **Ways out:** Cancelar, Back, the scrim and a swipe → keep or discard. A result with nothing to add just closes (D1).

**Numbers:**

| What | Before | After the fixes |
|---|---|---|
| Taps for one dated spoken task | 3 | 3 |
| Tap targets on a one-task result (AUDIT) | 7 | 7 |
| Words on a one-task result | ≈ 20 | ≈ 20 |
| Taps to undo a voice deletion | 2: Deshacer, then Cancelar on a red «Eliminar» card | 1 |
| Rows of a 6-task set reachable without finding a scroll inside the card, 1× | 4 of 6 | 6 of 6, in the sheet's one scroll |
| Rows of a 4-task set in view at 1.3× | about 3 of 4 (inferred from code) | 4 of 4, in the sheet's one scroll |
| Saves of several tasks whose message names the day | none | all those on one day; B1's landing keeps the heading for the rest |
| A destructive target touching a frequent one on a 3-task result (AUDIT) | 3 (title ↔ ✕) | 0 |
| Controls in an opened «Más opciones», one dated task | about 10 | about 9 |

### Findings (most severe first)

**UX-2201 · Severity 3 · Set cards hide tasks the button will change or delete**
- **Where:**
  - `App/lib/widgets/capture_command_cards.dart:2323-2347` (`BulkCommandCard`, the list under `large`);
  - every set card (move, shift, assign, change, complete, delete) below 1.5× text;
  - render `commands/cards.bulk-today-overdue.es.light.1x`.
- **The moment:** "The button says «Marcar 6 tareas como hechas», but I see four. Which are the other two?" More often, nobody notices and confirms.
- **What happens:**
  - Below 1.5× text the rows sit in a scroll inside the card, capped at 40% of the screen (320 dp on a 360 × 800 phone).
  - In the render, 4 of 6 rows show. AUDIT measures «Recoger a los niños del colegio» as a 286 × 6 dp sliver, and «Clase de yoga» is off screen.
  - The only cue is a thin scrollbar inside the card, while the button acts on all 6.
  - At 1.3×, a usual size for the newcomer, the rows are taller, so a 4-task «Pasa todas las de ayer a mañana» already hides one (inferred from the code; no set is rendered at 1.3×).
  - On a deletion («Borra todo lo de mañana») the hidden tasks are deleted unseen, and Deshacer lasts only the accessibility timeout.
- **Why it fails:**
  - VO-8 (Google Confirmations; Nielsen 2018c): a change or deletion shows every task it affects before the tap.
  - PL-8 and OL-3 (Norman 2010; Kobayashi 2011): a scroll inside a scrolling sheet has no signifier, and the newcomer doesn't explore.
  - Nielsen's error prevention.
- **Fix:**
  - Subtract the inner scroll: the rows always go in the sheet's own scroll, as 1.5× and up already do (the `large` path).
  - Remove `_scroll`, its `Scrollbar` and the `ConstrainedBox`.
  - The button stays pinned. A row cut by the footer is the cue that more follows, as on every other result.
  - No new copy.
- **Verify:**
  - Re-render `commands/cards.bulk-today-overdue` and `cards.bulk-move` at es 1×, and add es 1.3×: no scrollbar inside the card, and scrolling the sheet reaches every row.
  - Set deletions still open with their heading and ✕ at the top (the UX-1704, UX-1718 and UX-1719 tests).
  - Widget test: a 6-task deletion set at 1.0× and 1.3× has every row's checkbox in the sheet's own `Scrollable`.
- **Evidence:** seen in a current render with AUDIT, at 1×; the 1.3× case is inferred from code.

**UX-2202 · Severity 2 · Deshacer after a voice deletion brings the red card back**
- **Where:**
  - `App/lib/screens/voice_task_screen.dart:3911-3923`: Deshacer reopens the result. Its result-saving twin is `:3283-3295`.
  - `:3767-3768`: the message.
  - `:2779`: the reopened result announces its headline.
  - Renders `commands/applied.delete-applied.es.light.1x` and `applied.delete-undone.es.light.1x`.
- **The moment:** "I pressed Deshacer and it asks me to delete it again. Did it undo it or not?" With TalkBack, the first thing heard after Deshacer is «Se eliminará: Ir a la peluquería (sáb, 31 de oct)».
- **What happens:**
  - A voice deletion ends on «Tarea eliminada · Deshacer». It's the only voice action whose message doesn't name the task; completion says «Completada: Ir a la peluquería».
  - Deshacer puts the task back, then reopens the sheet on the same red card «Se eliminará: …» with the red filled «Eliminar» under the thumb.
  - The task comes back on Saturday while Calendar stays on today, under the scrim, so nothing on screen shows that it's back. The only way out is Cancelar.
  - Every result with nothing to add does this: changes, completions and sets.
  - On a task's own page, the same Deshacer just restores the task (`App/lib/screens/task_detail_screen.dart:84-89`).
- **Why it fails:**
  - Norman's gulf of evaluation.
  - UN-2 and UN-3 (Flaherty 2024; Nielsen 2018c; Raskin 2000): undo reverses; it doesn't re-ask.
  - SC-9 and Jakob's law: the same Deshacer behaves differently on Calendar.
  - RE-6 (Harada 2013): the destructive primary is put back in reach.
  - D1 already treats a result with nothing to add as disposable: Cancelar just closes it.
- **Fix:**
  - **(1) What Deshacer does:**
    - On a result that added nothing (changes, completions, deletions, sets), Deshacer restores and stops, with no sheet. This follows D1 and the task page's Deshacer.
    - A result that added tasks keeps reopening, so a misheard task can still be fixed and added again.
  - **(2) The message:** one task deleted by voice is named, as completion is:
    - ES «Eliminada: {title}»;
    - EN "Deleted: {title}";
    - CA «Suprimida: {title}».

    Sets keep «3 tareas eliminadas».
  - **Trade-off:** re-picking a set's rows after an undo goes; saying it again does that.
- **Verify:**
  - Widget test: «Borra el dentista» → Eliminar → Deshacer. «Dentista» is back within 1 s, no `CaptureResult` is on screen, and nothing announces «Se eliminará».
  - The UX-1707 checks in `App/test/bulk_voice_commands_test.dart:3236-3290` change from `reopensWithin` to that.
  - The message in ES, EN and CA.
  - Render `applied.delete-undone`: Calendar, with no sheet.
- **Evidence:** seen in current renders, and verified in code.

**UX-2203 · Severity 2 · After several tasks are added, nothing names the day you land on**
- **Where:**
  - `App/lib/screens/voice_task_screen.dart:3186-3206` and `:3721-3739`: the message;
  - `App/lib/screens/calendar_screen.dart:183-260`: the landing scroll, B1's code;
  - render `calendar/agenda.added.es.light.1x`.
- **The moment:** "Two rows are green, and it says «también el vie, 30 de oct». Also, as well as what? Which day am I looking at?"
- **What happens:**
  - One task says «Añadida al vie, 30 de oct», and a moved set says «4 tareas movidas al jue, 29 de oct» (UX-1703).
  - Several added tasks say only «3 tareas añadidas», with «· también el …» for the other days. The day Calendar landed on is never named.
  - At 1×, the landing scroll then pushes the day heading and the week strip off the top; in the render only the strip's dots peek out under the header. So no line on screen names the lit rows' day.
  - The first-run example, «Mañana, llamar al dentista y comprar pan» (UX-701), ends this way too: «2 tareas añadidas».
- **Why it fails:**
  - SC-10 and SC-11 (Rensink 1997; Kahneman 1993): the end shows where the item went.
  - SC-3 (Leiva 2020): the day belongs at the top.
  - CO-3 (Cowan 2001).
  - SC-9: moves name the day, adds don't.
  - VO-15: the first dictation lands "with its day".
- **Fix:**
  - **(1) The message:** when every dated task lands on one day, name it as moves do:
    - ES «{count} tareas añadidas al {date}»;
    - EN "{count} tasks added to {date}";
    - CA «{count} tasques afegides al {date}».

    This is a dated form of `captureTasksAdded`. Saves spread over several days keep «· también …».
  - **(2) The landing:** Calendar keeps its day heading in view whenever it fits with the lit rows above the message, and lets it go only when they don't fit. This is B1's `_scrollToLit`; it's listed here because the landing is A2's ending.
- **Verify:**
  - Widget test: two tasks said for tomorrow → «2 tareas añadidas al jue, 29 de oct», in ES, EN and CA (CA at 2× on 360 dp).
  - Re-render `calendar/agenda.added` at es 1×: the day heading and both lit rows show above the message.
- **Evidence:** seen in a current render, and verified in code.

**UX-2204 · Severity 2 · «¿Cuál quieres cambiar?» answers look like plain text**
- **Where:**
  - `App/lib/widgets/capture_command_cards.dart:1199-1274` (`_Choice`), used for change, delete and complete (`:1363-1376`, `:1759-1772`, `:1845-1858`);
  - render `commands/cards.change-which.es.light.2x`.
- **The moment:** "It asks which one, then lists two lines, and the button is grey. Do I tap a line? Do I say it again?"
- **What happens:**
  - The matches are bare text rows: no outline, no chevron, no radio, and outside any question box. AUDIT measures them 0 dp apart.
  - Every other question on these cards puts its answers as outlined chips in a question box: morning or afternoon, «¿Qué día?», «¿Qué proyecto?», a person.
  - Found tasks get a chevron (UX-913).
  - The main button meanwhile reads «Revisa los datos de arriba», disabled.
- **Why it fails:**
  - VO-9 (Google Confirmations; Nuance Confirm): one plain question, with its answers as buttons.
  - Norman's signifiers.
  - SC-9: one style of question.
  - RE-3 (Jin 2007): gaps between targets.
- **Fix:**
  - Show the matches as the question's answers, in its question box. The question is the box's line.
  - Make each match an outlined, full-width choice: `outline` colour, at least 48 dp, 8 dp apart.
  - «Ver N más» stays.
  - No new copy.
- **Verify:**
  - Re-render `cards.change-which` at es 1× and 2× and ca 2×: each choice is outlined, and AUDIT finds no gap under 8 dp.
  - The existing tests still pick a task with one tap.
- **Evidence:** seen in a current render with AUDIT, and verified in code.

**UX-2205 · Severity 2 · A batch task's title touches its ✕**
- **Where:**
  - `App/lib/widgets/capture_review_editor.dart:678-701`: a collapsed row's title button and ✕ share one row with no gap;
  - `App/lib/widgets/reminder_control.dart:803-808`: «Activar recordatorios», between the reminder row and «Más opciones».
- **The moment:** "I tapped the name to fix it, and the task disappeared."
- **What happens:**
  - The title's hit area (238 × 48 dp) runs right up to ✕ (48 × 48 dp). AUDIT measures 0.0 dp on every card of all 7 `capture/result · several` renders.
  - A tap aimed at the end of a long title removes the task: «Quitada · Deshacer», gone after the timeout.
  - On a card with reminders off, «Activar recordatorios» is 0 dp below the reminder row and 1 dp above «Más opciones» (AUDIT, `reminders/capture-card · plan-reminders-off`). It raises Android's permission dialog (`turnOnReminders`, `reminder_control.dart:232`).
- **Why it fails:**
  - RE-3 (Kobayashi 2011; Jin 2007).
  - RE-6 (Harada 2013).
  - The loop's own standard, from UX-1311: 8 dp between capture controls.
- **Fix:**
  - 8 dp between a collapsed row's title and its ✕, so the title's hit area ends 8 dp short of ✕.
  - 8 dp above and below «Activar recordatorios».
  - Nothing else changes.
- **Verify:**
  - AUDIT for `capture/result · several` and `reminders/capture-card · plan-reminders-off` has no «gap under 8 dp» between those pairs.
  - Widget test: a tap 2 dp left of ✕ opens the card and doesn't remove it.
- **Evidence:** measured in AUDIT, and verified in code.

**UX-2206 · Severity 1 · The reminder row says «Recordatorio» twice**
- **Where:**
  - `App/lib/widgets/reminder_control.dart:776-798`: title `reminder` at :785, and the plan line as subtitle at :786-793;
  - render `reminders/capture-card.plan.es.light.1x`, and es and ca 2×.
- **The moment:** "«Recordatorio. Recordatorios: cada 3 días…» Yes, I know."
- **What happens:**
  - Since UX-1806 the plan line starts with its noun: «Recordatorios normales hasta…», «Recordatorios: cada 3 días…». The row puts it under a «Recordatorio» title.
  - At 2× the row takes 6 lines, one of them only the repeated word.
  - A task given to someone else reads «Recordatorio / Recordatorio para Ana».
  - The task form uses the same widget.
- **Why it fails:** CO-5 (Sweller 1988); OL-7 (Wallace 2022).
- **Fix:**
  - When the value already names itself (a plan line, or «Recordatorio para …»), show it as the row's only text, with the bell.
  - Single reminders keep «Recordatorio» over «10 minutos antes».
  - One line fewer.
- **Verify:** renders `capture-card.plan` at es 1× and 2× and ca 2×, and the form's line, show «Recordatorios: cada 3 días…» once; TalkBack reads the line once.
- **Evidence:** seen in a current render, and verified in code.

**UX-2207 · Severity 1 · A dictated note's text is labelled «Notas»**
- **Where:**
  - `App/lib/widgets/capture_review_editor.dart:751-753`: `labelText: l.notes`, `hintText: l.addNotes`;
  - render `notes/note-capture.result.es.light.1x`.
- **The moment:** "«Título de la nota» and then «Notas»? Is it a note with notes in it?"
- **What happens:**
  - A voice note's text field borrows the task's «Notas» and «Añadir notas».
  - The form and the note's own page call it «Tu nota» (`noteBody`: `task_editor.dart:845`, `task_detail_screen.dart:593`).
  - TalkBack reads «Notas» (AUDIT).
- **Why it fails:** SC-9 (one name per concept); borrowed copy, recurring problem 9.
- **Fix:** for a note, label the field «Tu nota» / "Your note" / «La teva nota» (`noteBody`), with `noteHint`, as the form does.
- **Verify:** render `note-capture.result` at es 1× and 2× shows «Tu nota», and AUDIT's TalkBack line reads it.
- **Evidence:** seen in a current render, and verified in code.

**UX-2208 · Severity 1 · «Más opciones» repeats «Quitar» and shows a dead «No se repite»**
- **Where:** `App/lib/widgets/capture_review_editor.dart:903-907` («Quitar») and `:873-882` (the repeat row, with no tap when the task has no day).
- **The moment:** "Quitar? Isn't that Cancelar? … I tap «No se repite» and nothing happens."
- **What happens:**
  - Opened, «Más opciones» ends with «Quitar», a second way to drop the task. On one task, Cancelar → Descartar does that; on a batch card, ✕ does.
  - On a task with no day, the repeat row reads «No se repite», with no chevron, and does nothing. The form says «Añade una fecha para repetir» (`task_editor.dart:1322`).
- **Why it fails:**
  - CO-9 (Thompson 2005).
  - CO-5.
  - Recurring problem 3: a default shown as content.
  - SC-9.
- **Fix:**
  - Remove «Quitar» from «Más opciones»; ✕ and Cancelar remain.
  - On a task with no day, the repeat row reads `repeatNeedsDate`: «Añade una fecha para repetir» / "Add a date to repeat" / «Afegeix una data per repetir». No tap, as in the form.
- **Verify:** widget test, with the options open on a one-task and a batch result: no `reviewRemove` button, and a task with no day shows `repeatNeedsDate`.
- **Evidence:** verified in code; no render shows «Más opciones» open.

**UX-2209 · Severity 1 · Change lines name the field only by its icon**
- **Where:**
  - `App/lib/widgets/capture_command_cards.dart:1382-1404` (`line`, «before → after»), with priority at `:1584-1590` and the deadline at `:1564-1583`, both `Icons.flag_outlined`;
  - renders `cards.change-details.es.light.1x` («Media → Alta») and `cards.change-deadline-only.es.light.1x` («mar, 27 de oct → Mañana ▾»).
- **The moment:** "Media → Alta: medium what? And the flag one, is that the day?"
- **What happens:**
  - Each visible line is «before → after», with only an icon to say which field it is.
  - The same flag stands for the priority on one line and for the deadline on another.
  - TalkBack hears the field («Prioridad: de Media a Alta»), but the screen doesn't show it.
  - Set cards do write it out: «Prioridad: Alta», «Fecha límite: …» (`_bulkSets`, `:1963-2013`).
- **Why it fails:** SC-6 (Harley 2014): label the icons on the default path; SC-9.
- **Fix:**
  - Write the field on the priority and deadline lines, as set cards do, in a new visible string `{label}: {before} → {after}` (not concatenated):
    - ES «Prioridad: Media → Alta», «Fecha límite: mar, 27 de oct →» followed by its chip;
    - EN "Priority: Medium → High", "Deadline: …";
    - CA «Prioritat: …», «Termini: …».
  - The day, title and person lines keep their icons.
- **Verify:** renders `cards.change-details` at es 1× and ca 2× and `cards.change-deadline-only` at es 1× and 2× show the field names, with nothing clipped.
- **Evidence:** seen in current renders, and verified in code.

**UX-2210 · Severity 1 · Cards that found nothing keep the pencil or the bin**
- **Where:**
  - `App/lib/widgets/capture_command_cards.dart:1359`: a change with nothing found, `edit_outlined`;
  - `:1752-1755`: a deletion with nothing found, the bin in teal;
  - `:2142-2146`: set cards with nothing to do or view-only, which keep the action's icon.
  - Renders `cards.not-found`, `cards.bulk-none` and `cards.bulk-view-only` (pencil), against `cards.complete-not-found` (search icon).
- **The moment:** "There's a pencil. Can I edit something here?"
- **Why it fails:** SC-9; Norman's signifiers. UX-1705 already set the search icon for «nothing found» on «Ya he…».
- **Fix:**
  - A card that found nothing, or can't act (view-only), uses the search icon, as «Ya he…» does.
  - The action's icon stays only on cards that will act.
- **Verify:** re-render those three; the icon is `search_rounded`.
- **Evidence:** seen in current renders, and verified in code.

**UX-2211 · Severity 1 · TalkBack isn't told «Más opciones» or a batch card opened**
- **Where:**
  - `App/lib/widgets/capture_review_editor.dart:825-847`: the «Más opciones» ListTile;
  - `:683-694`: a collapsed row's title, which opens the card;
  - AUDIT `capture/result · one-task` and `· several`.
- **What happens:**
  - Both open content in place. TalkBack hears only «Más opciones, botón» and «Comprar pan y leche, botón».
  - There's no collapsed or expanded state, and no hint that the title opens the task to edit.
  - Nothing is announced after the tap.
  - The reminder sheet's expandable rows carry `Semantics(expanded)` since UX-1907.
- **Why it fails:** AC-6 (WCAG 2.2, 4.1.2); AC-7.
- **Fix:** wrap both in `Semantics(expanded: …)`, as UX-1907 did. The title's tap hint is `editTask` («Editar tarea»).
- **Verify:** AUDIT's TalkBack lines read «Contraído» or «Desplegado» on both; a widget test toggles the state.
- **Evidence:** measured in AUDIT, and verified in code.

**UX-2212 · Severity 1 · An open time question's guess already shows as the time**
- **Where:**
  - `App/lib/widgets/capture_review_editor.dart:376-404` (`_dateLine` prints the day and the time) and `:735-737`;
  - render `capture/result.question.es.light.1x`: «jue, 5 de nov · 17:00» above «¿A las 5 de la mañana o de la tarde?».
- **The moment:** "It already says 17:00. Why does it ask?"
- **What happens:**
  - A draft that arrives with a time and a question about that time shows the guess as fact on the main line, while the box asks.
  - TalkBack's announcement on arrival reads «…, jue, 5 de nov · 17:00. ¿A las 5 de la mañana o de la tarde?».
  - The server is told to send no time when it asks (`Backend/core/ai.py:341-344`), and the phone's parser sends none (`App/lib/services/local_capture.dart:131-140`).
  - So this shows when the model slips (cause likely server-side), and in the preview fixture (`App/test/ux_previews/capture_previews.dart:556-559`).
- **Why it fails:** VO-5 and VO-9 (Budiu 2018ia; Google Confirmations): show uncertainty as a question, not as the result.
- **Fix:**
  - While a time question with times is open, the date line shows the day only («jue, 5 de nov»); after the answer, the day and the time.
  - The fixture can then send no time, as the server does.
- **Verify:** widget test with a time and an open question: «jue, 5 de nov»; after tapping «17:00», «jue, 5 de nov · 17:00».
- **Evidence:** seen in a current render; verified in code and in the server prompt.

**UX-2213 · Severity 1 · «Han vuelto aquí» is plural for one task**
- **Where:**
  - `App/lib/l10n/app_es.arb:13` `reviewUndoSaved` (EN `app_en.arb:22`, CA `app_ca.arb:13`);
  - shown by Deshacer while the sheet stays open: `voice_task_screen.dart:3274-3281` and `:3902-3909`.
- **What happens:** after a partial save (one card still asking), Deshacer brings the saved tasks back with «Han vuelto aquí, sin guardar.» / "They're back here, not saved yet." / «Tornen a ser aquí, sense desar.». It's plural even when one task came back.
- **Why it fails:** LO-2 (CLDR plurals).
- **Fix:** an ICU plural on the count restored:
  - ES «{count, plural, =1{Ha vuelto aquí, sin guardar.} other{Han vuelto aquí, sin guardar.}}»;
  - EN "{count, plural, =1{It's back here, not saved yet.} other{They're back here, not saved yet.}}";
  - CA «{count, plural, =1{Torna a ser aquí, sense desar.} other{Tornen a ser aquí, sense desar.}}».
- **Verify:** a catalog test with 1 and with 2.
- **Evidence:** verified in code.

### Keep
- **One sheet from the words to the landing.** A dated task takes 3 taps, its date is the largest line, and Hoy or Mañana fixes a day in one tap.
- **One verb from card to message.** Commands use it on the card, the button and the message («Mover 4 tareas», «4 tareas movidas al jue, 29 de oct»), and one Deshacer takes back all of it.
- **Questions sit in a box with tappable answers,** right under what they ask about (morning or afternoon, «¿Qué día?», «¿Qué proyecto?»), and the button waits.
- **A reminder said while dictating is one line to tap.** «Para recordártelo, ponle un día.» sits after the date's own question and opens the date.
- **Every way out asks once, and nothing said is lost:** Back, the scrim, a swipe, a killed app → «Sin guardar».

### Progress against UX_REVIEW.md (U1–U14)
- **U4 (the result in the same sheet, the date as the hero):** holds.
  - Plans 1–3 added the «Recordatorio» row under the date and the needs-day line after the date's question; the date stays the largest line.
  - A time guessed while asking can sit on that line (UX-2212).
- **U5 (land on the task):** holds for one task, moves and completions.
  - Several added tasks don't name their day, and at 1× the day heading scrolls away (UX-2203).
- **U7 (save as written):** holds in A2. Command results that found nothing offer «Guardar como tarea» (UX-901, device check).
- **U11 (renames):** holds in A2's copy: «Sin fecha», «Sin guardar»; no «Bandeja» or «captura» on the default path.
- **U1–U3, U6, U8–U10, U12–U14:** other areas.

### Questions for the owner
None new from A2. UX-615 (a result with nothing to ask saving itself) stays open until the §7 test, as decided.

### Cross-slice notes
- **B1 (the landing):** at 1×, Calendar's landing scroll hides the day heading and the week strip (`calendar/agenda.added.es.light.1x`, `calendar_screen.dart:183-260`). Its fix is part (2) of UX-2203; plan it once.
- **B1 (WD34):** a voice «Marca como hechas todas las de hoy» also empties the day it lands on: `commands/applied.bulk-today-overdue-applied` shows «0 pendientes». The «Todo listo. Respira.» line should show there too, not only after a tick in Calendar.
- **B2, the reminder sheet (website review):**
  - «A tu manera» (`reminder_plan_sheet.dart:669`) shows only its example. Nothing says its words go to Google's AI.
  - Voz's `capturePrivacy` names only «añadir, buscar o cambiar tareas».
  - So the site's point is real.
- **B2:** UX-2206's doubled «Recordatorio» also shows in the task form, which uses the same widget. On the task's page the flag stands for both the deadline and the priority (`task_detail_screen.dart:317`, `:348`).
- **D (theme):** AUDIT flags every primary button on a result at 312 × 52 dp (the 48–56 dp band). A theme minimum of 56 dp would cover all of them at once.
- **D9 (a reader's own reminders):** nothing in A2. Voice changes never touch reminders (`VOICE_COMMANDS.md:150`), so a reader's set card «Solo puedes ver «…»: sus tareas no cambian.» stays true.
- **Not A2:** the Pro screen's first line against the site's FAQ (D); the invitation email's bare website address (server, for the main session).

### Memory notes
- **Set cards** (`BulkCommandCard`): below 1.5× text the rows scroll inside the card (max(160 dp, 40% of the height)); from 1.5× they go in the sheet's scroll. UX-2201 asks for the sheet's scroll at every size.
- **Deshacer after any capture result** reopens the sheet on the restored result. That's U4's design, tested by UX-1707's `reopensWithin`. UX-2202 limits it to results that added tasks.
- **Landing messages:** one task names its day, and a moved set names its day; several added tasks don't (UX-2203).
- **Questions on cards:** morning or afternoon, the day, the project and a person are chips in a `QuestionBox`. The «¿Cuál…?» rows (`_Choice`) are bare (UX-2204).
- **`ReminderControl`** puts the «Recordatorio» title over a plan line that already starts with «Recordatorios» (UX-2206). The capture card and the form share it.
- **A voice note's text** is labelled «Notas» on the card and «Tu nota» (`noteBody`) everywhere else (UX-2207). That the body repeats the title is UX-113's design ("the full text stays in the note"); the Notas list hides it.
- **The `result.question` preview fixture** sends 17:00 with the morning-or-afternoon question, though the server sends no time when it asks.
- **Settled, don't re-raise:**
  - «Guardar como tarea» filled on a search that found nothing (UX-901's design);
  - the add-and-delete button staying teal (UX-905);
  - a mixed result at 2× opening at the red card (accepted trade-off).
- **The device lane** never shows the AI result (free review account, no AI calls), so A2's evidence is renders, AUDIT and code.
