## UX review — B2 · One task (whole-app run 2026-10-28-app) — 2026-10-31

**Verdict:** Ship after fixes. Nothing blocks a task, but this area's most common moments answer wrongly:
- a reminder that has just rung shows as «Sin recordatorio»;
- ticking and moving a task wait for a full server sync;
- a reader's «Completar» on a reminder creates an English «(offline copy)».

D9 (UX-2032) and WD34 are decided by the owner, and are specified below as packages.

**Walked:** Newcomer (es, 1×/1.3×/2×), Daily user, TalkBack user (from AUDIT.md and uiautomator trees), and a «lector» (from code).
1. **Open a task:** from a row (1 tap), from a reminder notification (1 tap; emulator `notification.tap-landing`), or from Activity or «Tareas con archivos» (1 tap).
2. **Complete and undo:** Completar (1), then Back (2). Deshacer is in the message.
3. **Move:**
   - Cambiar fecha → Mañana (2), or a day + Listo (3).
   - Repeating task: «Esta repetición» / «Toda la serie», and «Omitir esta repetición».
4. **Edit:** ✏ or the title → change → Guardar cambios or Back (3), then «Cambios guardados · Deshacer».
5. **Reminders:**
   - single: chip → row (2);
   - plan: chip → «Hasta la fecha límite» → strength → Listo (4);
   - «A tu manera» (Pro): 4 or more taps;
   - a shared task («solo para ti»), a task given to someone else, a reader's task (nothing possible today), and a task whose reminder has just rung (emulator).
6. **Repeat:** ✏ → Más detalles → Repetir → dropdown → choice → Listo → Guardar cambios (7).
7. **Steps:** tick on the task's screen (1 each). Add one: ✏ → [Más detalles] → field → Enter → Guardar cambios (4–5).
8. **Files:**
   - open (1);
   - remove (2, with a confirmation);
   - add to a saved task: ✏ → Más detalles → scroll → Añadir adjunto → Elegir una foto → pick → Guardar cambios (6, plus scrolling).
9. **Delete and undo:** 🗑 (1) → the list with «Tarea eliminada · Deshacer». A repeating series asks first (2).
10. **Typed creation (the free accounts' form):**
    - Añadir tarea → [once a month, the used-up notice: «Crear una tarea»] → title → Mañana → Añadir al calendario (3–4 taps, plus typing);
    - it lands lit on Calendar with Deshacer;
    - then the first-dated question, or the plan offer.

**Evidence used:**
- **Previews:** rendered at 6281e3d. `find App/lib App/assets -newer <png>` finds no newer app file, so they are current.
- **AUDIT.md.**
- **Emulator captures:** at 30c8ce0, which has the app code of 6281e3d.
- **Not rendered:** the Cambiar fecha sheet, the repeat sheet, the step ⋮ menu, the series-delete dialog, the edit form with Más detalles open, and a reader's task screen. For these I reasoned from the code.
- **Text scale:** the preview suite scales 2× linearly. On the emulator's 2.0, Android 14 scales titles non-linearly, so the title grows much less (compare `screen-task-detail.timed-task.es.light.2.0` with `tasks/detail.notes-steps.es.light.2x`).

**Numbers:**
- **A plain task's screen (emulator):** 9 tap targets and 16 words besides the title → 8 and 13 with UX-2410.
- **Completing from the task's screen:** 2 taps (Completar, Back) → 1 with UX-2404.
- **Ticking 3 tasks in a row:** today the 2nd and 3rd ticks wait for the previous full sync, a pull of every task page plus files → each answers at once with UX-2402.
- **Changing a reminder:** 2 taps (it was 5 on 2026-10-13). A reader can't today → 2 taps with UX-2032.
- **Setting «Cada día»:** on a saved task 7 taps → 6 with UX-2407; from the new form's Más detalles 4 → 3.
- **A typed task:** 3 taps plus typing (unchanged).

### Findings (most severe first)

**UX-2401 · Severity 3 · Tapping a reminder lands on «Sin recordatorio»**
- **Where:**
  - `App/lib/widgets/reminder_control.dart:57-82` (`_alertPassed`), `:538-541` and `:564` (the chip), `:727-740` and `:791` (the form's row);
  - `App/lib/services/reminder_engine.dart:282-307` (`alertAhead`).
  - Task screen, the state after the reminder's time.
- **The moment:** «Me acaba de avisar y, al abrirla, pone "Sin recordatorio" con la campanita tachada. ¿Se ha borrado? ¿Lo he roto?»
- **What happens:**
  - The emulator capture `device/notification.tap-landing.es.light.1.0.png` (09:42, 30c8ce0) shows the case: «Pagar la luz» at 9:50 rang at 9:40, «Hoy a las 9:50 · en 10 min». Tapping the notification opens the task, whose chip reads «Sin recordatorio: ya ha pasado la hora del aviso» with the crossed-out bell.
  - The same line stays all day. It also stays after «Posponer 10 min», while the snoozed notice is still to come.
  - `alertAhead` only asks whether an alert is still ahead. It can't tell "it rang" (or "it's snoozed") from D1's case, "saved too late to ring".
- **Why it fails:**
  - Visibility of system status (Nielsen 1994), and the gulf of evaluation (Norman 2013): the screen contradicts what just happened.
  - TA-6: the reminder fired, but the app says there is none.
  - ON-10 / OL-2: the newcomer reads it as something broken.
- **Fix:** keep D1's line («Sin recordatorio: ya ha pasado la hora del aviso») only for a reminder that was never set to ring, such as a task saved after its 9:00. When the reminder was set and its time has come (the engine's `reminder_state` row for that alert, not blocked), the chip and the form's row say so, with the normal bell and the same tap:
  - ES «Recordatorio enviado: hoy, 09:40»; EN "Reminder sent: today, 09:40"; CA «Recordatori enviat: avui, 09:40».
  - With a snooze pending: ES «Recordatorio pospuesto: hoy, 09:52»; EN "Reminder snoozed: today, 09:52"; CA «Recordatori ajornat: avui, 09:52».
  - A plan's last notice, once it has rung: «… · último: hoy, 16:50» (EN "· last: today, 16:50", CA «· últim: avui, 16:50») instead of the passed line.
  - Use `context.clockTime` and the plan lines' «hoy, 16:50» format.
- **Verify:**
  - Widget tests: a rang alert gives «Recordatorio enviado: hoy, 09:40»; a snooze gives «pospuesto»; D1's saved-after-9:00 task still gives «Sin recordatorio…»; in ES, EN and CA.
  - Emulator: reminder → tap → the chip reads «Recordatorio enviado: …»; Posponer → «Recordatorio pospuesto: …».
- **Evidence:** seen in an emulator capture, and verified in code. The render `tasks/detail.alert-passed` shows the same line.

**UX-2402 · Severity 3 · Ticking and moving wait for a full server sync**
- **Where:**
  - In `App/lib/providers/task_provider.dart`, the methods `setCompleted` (`:221`), `rescheduleTask` (`:132`), `changeOccurrence` (`:184`), `setChecklistCompleted` (`:246`) and `restoreTask` (`:268`) each end with `await loadTasks()` inside the serialized `_mutate` chain. `loadTasks` → `_repository.sync()` refreshes the lists, sends pending changes, pulls every task page (`cloud_task_repository.dart:237-254`) and syncs files.
  - The callers: `App/lib/widgets/task_interactions.dart:19-25` (toggle), `:68-76` (reschedule), `task_detail_screen.dart:89` and `:437`.
- **The moment:** «Marco tres cosas seguidas y la segunda no se marca… ¿no lo he tocado bien?» / «Le cambié la fecha y la tarea desapareció; luego, al rato, salió "Movida al jueves".»
- **What happens:**
  - The phone shows the tick at once, because `loadTasks` sets the local list first. But the call returns only after the network sync.
  - So «Tarea completada · Deshacer» and its haptic click wait for the network, and so does «Movida al …», while the moved row has already vanished from the day.
  - Because `_mutate` runs one change at a time, the next tick, move or step waits behind the previous sync: on a slow connection the 2nd tick doesn't appear for a second or more.
  - A swiped row stays slid out until the sync ends: the swipe's `confirmDismiss` awaits the toggle (`task_tile.dart:232-238`).
  - UX-601 and UX-1707 fixed saving and undoing deletions with `showLocal()`. These paths were missed.
- **Why it fails:**
  - UN-1 / PE-1: every tap answers within 0.1 s (Nielsen 1993; Forch 2017).
  - UN-10: saved on the phone first (Android Offline-first).
  - UN-5: Deshacer is missing while the user may need it.
  - The owner's speed bar (DECISIONS 2026-10-13). Recurring problem #18.
- **Fix:** in those five methods, replace `if (mounted) await loadTasks();` with `if (mounted) await showLocal();` (show the phone's list, then sync behind), as UX-601 and UX-1707 did. No UI change.
- **Verify:**
  - Widget tests with a repository whose sync takes 5 s:
    - the completion message appears within one frame;
    - a second task ticked 300 ms later ticks at once;
    - a swiped row springs back at once;
    - «Movida al …» shows as the sheet closes;
    - Deshacer works during the sync.
  - Phone on mobile data: tick three tasks in a row.
- **Evidence:** verified in code. The delay is inferred: the emulator's local Docker server is fast. It needs a phone on mobile data.

**UX-2403 · Severity 3 · A reader's «Completar» on a reminder makes an «(offline copy)»**
- **Where:**
  - `App/lib/services/notification_service.dart:66-69` (actions offered regardless of role);
  - `App/lib/services/reminder_engine.dart:749-768` (writes the completion past `validateList`);
  - `App/lib/repositories/cloud_task_repository.dart:154-166` (a pending row on a «lector» project becomes a copy);
  - `App/lib/services/task_database.dart:735-786`, and `:770` (hard-coded English «(offline copy)»);
  - `App/lib/screens/calendar_screen.dart:723-750` (the red banner).
- **The moment:** «Me avisó de "Comer con Ana", le di a Completar… y ahora sale en rojo que el proyecto "ahora es de solo lectura", la comida sigue sin hacer y tengo otra "Comer con Ana (offline copy)". ¿Qué he roto?»
- **What happens:**
  - A «lector» gets their own reminders for «Todos» tasks and tasks given to them (DECISIONS 2026-10-23), with «Completar» and «Posponer 10 min».
  - «Completar» writes the completion straight into the phone's database and shows «Completada: …» with Deshacer.
  - At the next sync, the viewer branch:
    - turns the pending row into a personal task «Comer con Ana (offline copy)» (completed, English suffix), which is uploaded as a new task;
    - restores the shared task;
    - makes Calendar show the red «Este proyecto ahora es de solo lectura. Tu cambio pendiente se ha conservado como copia personal.», although the project was always read-only for them.
  - Deshacer doesn't avoid it: the undone row is still pending, so it's copied too.
  - In the app a reader has no circle and no Completar (`task_tile.dart:275`, `task_detail_screen.dart:463`).
- **Why it fails:**
  - It offers an action that can't succeed: a false signifier (Norman 2013).
  - UN-10: honest about sync.
  - UN-7 / OL-2: the banner is untrue and reads as the user's fault.
  - SH-1: viewers need no training.
  - Lens M: English in a Spanish task title.
- **Fix:**
  1. A reminder for a task in a project where this account is «lector» is posted without «Completar». The single reminder keeps only «Posponer 10 min». A plan notice has no button; its tap opens the task.
  2. `ReminderEngine.action('complete')` refuses such a task, with no local write, for notices already in the shade.
  3. A pending row equal to the server's (for example after Deshacer) is acknowledged, never copied.
  4. The copy suffix used for editors' conflicts is translated, matching the sync message's noun: ES «(copia local)», CA «(còpia local)», EN "(offline copy)".

  Build it with UX-2032 (D9), which makes readers' reminders more common.
- **Verify:**
  - Engine tests: for a reader's task, no 'complete' action is built, and `action('complete')` returns false and writes nothing.
  - Repository test: a «lector» row equal to the server's makes no copy.
  - Emulator, with a «lector» account on the local Docker server: the reader's reminder shows only «Posponer 10 min»; after a sync there is no copy and no red banner.
- **Evidence:** verified in code. Not reproduced: the emulator lane has no reader account.

**UX-2404 · Severity 2 · Completar keeps the task open, its main button now «Reabrir»**
- **Where:**
  - `App/lib/screens/task_detail_screen.dart:489-502` (bottom bar), `:203-204` (the «TAREA COMPLETADA» label), `:108-118` (which occurrence it shows);
  - `App/lib/widgets/task_interactions.dart:12-41`;
  - the ways in without an occurrence: `App/lib/screens/activity_screen.dart:157`, `App/lib/screens/tasks_with_files_screen.dart:98`.
- **The moment:** «Le di a Completar y sigo aquí; ahora el botón grande dice "Reabrir". ¿Se ha hecho o no? ¿Qué toco ahora?»
- **What happens:**
  - Completar ticks the task and shows «Tarea completada · Deshacer», but the screen stays.
  - A small grey «TAREA COMPLETADA» appears above the title, and the filled button under the finger becomes «Reabrir». A hesitant second tap reopens the task.
  - To see the day, the person must find Back.
  - Opened from Activity or «Tareas con archivos» (no occurrence), a repeating task's screen re-picks the next open occurrence after the tick. The date jumps to tomorrow and the button still says «Completar», so the "it didn't work" second tap completes tomorrow's too.
- **Why it fails:**
  - SC-11: end on visible success, the row ticked in its day (Kahneman 1993).
  - UN-2: confirm in place.
  - RE-6: the opposite action sits under the same finger.
  - Two undos are offered at once (Deshacer and Reabrir), and there is no next step (lens A).
- **Fix:**
  - Completar on a task's screen closes it, as Back does, and leaves the existing «Tarea completada · Deshacer» over the list, where the row shows ticked. Deshacer reopens it.
  - «Reabrir» on a task that was already completed when opened keeps the screen.
  - While open, the screen keeps the occurrence it opened with: pin its key at the first build.
  - No new copy.
- **Verify:**
  - Widget tests: Calendar row → task → Completar → Calendar, with the row ticked and the message.
  - Activity → daily task → Completar never shows tomorrow's occurrence.
- **Evidence:** verified in code. The emulator capture `screen-task-detail.timed-task` shows the state before; there is no render of the state after.

**UX-2405 · Severity 2 · «A tu manera» never says the words go to Google's AI**
- **Where:**
  - `App/lib/widgets/reminder_plan_sheet.dart:646-676` (the field, typed or dictated), `:286-316` (the `ai/reminder-plan/` request);
  - `capturePrivacy` (es `app_es.arb:307`, en `app_en.arb:527`, ca `app_ca.arb:286`).
- **The moment:** a Pro user types «una semana antes y el día antes a las 8» without knowing it leaves the phone.
- **What happens:**
  - Typed or dictated rhythms go to the server's AI, and nothing in the sheet says so.
  - Ajustes › Voz's sentence covers only «Para añadir, buscar o cambiar tareas».
  - The site's privacy policy now says these words go to Google's AI (website review 2026-10-28-site).
- **Why it fails:**
  - PR-1: explain at the moment of use (GDPR arts. 12–13; WP260 2018).
  - Recurring rule: any new feature that sends words out must fit the Voz sentence.
- **Fix:**
  - The first time «A tu manera» is used on this phone, show the existing `capturePrivacyLine` under its field (ES «Tus palabras van por internet. Más en Ajustes.», with its EN and CA).
  - Widen `capturePrivacy`'s second sentence: ES «Para añadir, buscar o cambiar tareas, o pedir recordatorios a tu manera, tus palabras van por internet a la IA de Google.»; EN "To add, find or change tasks, or to ask for reminders your way, your words go over the internet to Google's AI."; CA «Per afegir, cercar o canviar tasques, o demanar recordatoris a la teva manera, les teves paraules van per internet a la IA de Google.»
- **Verify:**
  - Widget test: the first opening of «A tu manera» shows the line, the second doesn't.
  - Voz shows the new sentence in three languages.
  - Re-render `reminders/sheet.your-way` es 2× and ca 2×.
- **Evidence:** verified in code and strings.

**UX-2406 · Severity 2 · Edits to a saved task are lost if Android closes the app**
- **Where:** `App/lib/widgets/task_editor.dart:299-307` (words are kept only while `_creating`) and `:486-494` (`_back`). There is no app-lifecycle handling.
- **The moment:** «Estaba escribiendo la nota del médico, me llamaron, y al volver no estaba lo que escribí.»
- **What happens:**
  - A new task's words are kept from the first letter (UX-1005).
  - A saved task being edited lives only in the form's memory. If Android closes the app in the background (a call, the camera, low memory, common on cheaper phones), the edits are gone and the app reopens on Calendar.
- **Why it fails:** UN-9, never lose input (WCAG 2.2 2.2.6; COGA 2021); OL-1.
- **Fix:**
  - When the app goes to the background with a changed, valid edit form, save the changes as Back does (D12), without closing the form or showing a message.
  - The later Guardar cambios or Back shows «Cambios guardados · Deshacer», whose Deshacer restores the task as it was when the form opened.
  - An untouched form, or one with an emptied title, saves nothing.
- **Verify:**
  - Widget test: lifecycle `paused` with a changed title → the task is updated; `resumed` → the form is still open; Back → the message, and Deshacer restores the original.
  - Device check with «No conservar actividades».
- **Evidence:** verified in code; needs a device check.

**UX-2407 · Severity 2 · The repeat sheet hides its choices in a dropdown**
- **Where:**
  - `App/lib/widgets/repeat_rule_control.dart:127-142` (dropdown), `:64-70` (the interval dialog's `keepChanges`);
  - opened from `task_editor.dart:1314-1333` and from the capture card.
- **The moment:** «Quiero que se repita cada día; pone "No se repite"… ¿dónde lo cambio?», then in the interval dialog: «Le di a "Guardar cambios" y aún tengo que darle a Listo y otra vez a Guardar cambios.»
- **What happens:**
  - The sheet's only choice is «No se repite ▾»: two taps to see and pick «Cada día», then Listo, then the form's own button.
  - The interval dialog's filled «Guardar cambios» only sets a number in the sheet, so there are three confirmations, two of them with the same words.
  - EN says "Keep changes" and CA «Conserva els canvis».
- **Why it fails:**
  - CO-8 (recognition over recall; Nielsen 1994h).
  - CO-2 / CO-10 (Hick 1952; Card 1980: about 1.1 s per extra tap).
  - UN-4: buttons name their outcome. SC-9.
- **Fix:**
  - Replace the dropdown with five one-tap rows (No se repite, Cada día, Cada semana, Cada mes, Cada año), the chosen one ticked, as the reminder sheet's rows are. The weekday chips and the end date stay under them, and Listo applies.
  - The interval dialog's button becomes `done`: ES «Listo», EN "Done", CA «Fet».
- **Verify:**
  - Widget test: Más detalles → Repetir → «Cada día» → Listo (3 taps after Más detalles, from 4).
  - The dialog's button reads Listo in three languages.
  - Add the repeat sheet to the preview suite (es 2×, ca 2×).
- **Evidence:** verified in code; there is no render of the repeat sheet.

**UX-2408 · Severity 1 · WD34: the day's last tick in Calendar says «Todo listo. Respira.»**

Decided by the owner (DECISIONS 2026-10-31, WD34 / WEB-1317).
- **Where:** `App/lib/widgets/task_interactions.dart:25-27` (the completion message). Calendar's agenda (area B1) knows whether the shown day still has an open task.
- **The moment:** ticking off the day should end the day: «¡Ya está todo!»
- **What happens:** the last tick says «Tarea completada», like any other.
- **Why it fails:** SC-11, the peak–end rule (Kahneman 1993).
- **Fix:**
  - When a tick on Calendar leaves the shown day with no open task (today's «Atrasadas» included), the completion message reads ES «Todo listo. Respira.», EN «All clear. Take a breath.», CA «Tot fet. Respira.», with the same Deshacer and timeout.
  - A tick on Calendar means a row's circle or a swipe, or Completar on a task's screen opened from Calendar once UX-2404 returns there.
  - Everywhere else (Tareas, notifications, voice) it stays «Tarea completada».
  - Light: no new element, no animation.
- **Verify:**
  - Widget test: Calendar with two open tasks today; ticking the second gives «Todo listo. Respira.»; Deshacer reopens it; with one still open it stays «Tarea completada»; ES, EN and CA.
  - With UX-2402 the line appears at once.
- **Evidence:** owner decision; the code location is verified.

**UX-2409 · Severity 1 · TalkBack reads a task's notes as an unnamed text field**
- **Where:** `App/lib/screens/task_detail_screen.dart:575-609`; `App/lib/widgets/note_text.dart:37-41`.
- **The moment:** TalkBack says «Ir en ayunas…, cuadro de edición». The user wonders: «¿Tengo que escribir aquí?»
- **What happens:**
  - AUDIT `tasks/detail · full` #13 and `notes-steps` #11 read: «text field (no label) value "…" [read-only] → long press».
  - The notes are an unnamed `SelectableText`. Only a tappable note's body got a name (UX-1521).
- **Why it fails:** AC-6 (WCAG 2.2 4.1.2).
- **Fix:**
  - Read-only notes read as one node, labelled «Notas» with the notes as its value and no field role. Links stay their own buttons.
  - A reader's note (UX-1521's leftover) gets the same.
- **Verify:** re-render and AUDIT: `tasks/detail · full` reads «Notas, Después de cenar…», with no "text field".
- **Evidence:** AUDIT (widget-test semantics) and code.

**UX-2410 · Severity 1 · Date and time take two rows; «Sin hora» and the year add words**
- **Where:** `App/lib/screens/task_detail_screen.dart:281-331`.
- **The moment:** «Planificado para… jueves, 29 de octubre de 2026. Hora: Sin hora.»: two rows to say "Thursday".
- **What happens:**
  - Two rows, both opening Cambiar fecha:
    - the date with its year, which takes 3 lines at 2× in Catalan (`tasks/detail.alert-passed.ca.light.2x`);
    - «Hora · Sin hora», even when there's no time.
  - A deadline-only task adds «Planificado para · Sin fecha» and «Hora · Sin hora» above «Vence … / Antes de que termine el día».
- **Why it fails:** CO-5 (Sweller 1988); SC-1 / SC-2; recurring problem #3 (defaults shown as content).
- **Fix:**
  - One row: «Planificado para» over «jueves, 29 de octubre · 12:00». Show the time only when set, and the year only when it isn't this year.
  - No row for «Sin hora». No «Sin fecha» row on a deadline-only task; Cambiar fecha still adds a day.
  - The deadline row drops «Antes de que termine el día».
  - Result: a timed task goes from 9 to 8 targets and 16 to 13 words on screen; an untimed one goes from 11 to 6 words in the card.
- **Verify:**
  - Re-render `tasks/detail.*` es and ca at 1× and 2×.
  - Tests for four shapes: timed, untimed, deadline-only, and another year.
- **Evidence:** current renders, and the emulator capture.

**UX-2411 · Severity 1 · With a deadline, the chip reads «Recordatorio: Planificado para · 1 hora antes»**
- **Where:** `App/lib/widgets/reminder_control.dart:550-552`.
- **The moment:** «¿Planificado para qué?»
- **What happens:** on any task with a deadline, the chip's value starts with the anchor's field name. The form's row, for the same reminder, says just «1 hora antes».
- **Why it fails:** SC-1, front-load the information (Nielsen 2006f); SC-9.
- **Fix:**
  - Anchored to the day (the default): «Recordatorio: 1 hora antes».
  - Anchored to the deadline: ES «Recordatorio: 1 hora antes · fecha límite»; EN "Reminder: 1 hour before · deadline"; CA «Recordatori: 1 hora abans · termini».
- **Verify:** widget test of `reminderLine` for both anchors, in three languages.
- **Evidence:** verified in code.

**UX-2412 · Severity 1 · At 2×, a personal task's reminder sheet starts with «Elegir hora del aviso»**
- **Where:** `App/lib/widgets/reminder_plan_sheet.dart:743-770` (the title scrolls away unless the task is shared), `:176-190` (the sheet opens scrolled to the plan).
- **The moment:** «"Elegir hora del aviso"… ¿es el título? Yo quería ver mis recordatorios.»
- **What happens:**
  - Render `reminders/sheet.strength.es.light.2x`: opened on a plan, the first visible line is the tappable row «Elegir hora del aviso», which reads as the sheet's heading.
  - «Recordatorio» and the ticked row are above the edge.
  - On shared tasks the title stays fixed, with an edge (UX-2035).
- **Why it fails:** SC-3 (Leiva 2020); SC-9, one sheet with one behaviour; recurring problem #36.
- **Fix:** keep «Recordatorio» fixed above the choices on every task, with the same 1 dp edge. Only the «solo para ti» line stays shared-only.
- **Verify:** re-render `reminders/sheet.strength` es 2× and ca 2×: the title at the top, with the edge under it.
- **Evidence:** current render.

**UX-2413 · Severity 1 · Day chips sit 4 dp apart at large text; weekday chips touch**
- **Where:**
  - `App/lib/widgets/task_editor.dart:1229-1231` (Hoy / Mañana / Elegir día, `runSpacing: 4`);
  - `App/lib/widgets/schedule_editor.dart:262-264` (`runSpacing: 4`);
  - `App/lib/widgets/repeat_rule_control.dart:76` (no `runSpacing`).
- **The moment** (a tremor, at 2×): «Quería "Elegir día" y se puso "Mañana".»
- **What happens:**
  - AUDIT `form/new-task · filled` (1.3×, 2×, ca 2×): «Hoy» and «Mañana» are 4 dp above «Elegir día».
  - «Mañana» applies at once, while «Elegir día» opens a sheet.
  - The weekday chips wrap with no gap.
- **Why it fails:** RE-3 (Kobayashi 2011; Jin 2007).
- **Fix:** `runSpacing: 8` in the three Wraps, and `spacing: 8` for the weekday chips.
- **Verify:** AUDIT re-render: no gap under 8 dp between these chips.
- **Evidence:** AUDIT and code.

**UX-2414 · Severity 1 · In the edit form, the keyboard's ✓ saves and closes the form**
- **Where:** `App/lib/widgets/task_editor.dart:810-815`.
- **The moment:** «Le di al ✓ del teclado para quitarlo y se cerró la pantalla.»
- **What happens:** the title's keyboard action saves and pops the edit form. In the new form the same key only closes the keyboard.
- **Why it fails:** SC-9, the same action behaves the same; user control and freedom (Nielsen 1994).
- **Fix:** the edit form's title key closes the keyboard, as in the new form. Saving stays on Guardar cambios and Back.
- **Verify:** widget test: submitting the title leaves the edit form open with the keyboard down.
- **Evidence:** verified in code.

**UX-2415 · Severity 1 · TalkBack reads each step twice in the form**
- **Where:** `App/lib/widgets/checklist_editor.dart:141-180`.
- **What happens:** AUDIT `form/edit-task · existing` #11–#13 reads «checkbox Meriendas», then «text Meriendas», then «button Editar Meriendas».
- **Why it fails:** AC-6.
- **Fix:** merge each step's checkbox and title into one node, or exclude the `Text` from semantics; the checkbox keeps its label.
- **Verify:** AUDIT re-render: one read per step, plus its ⋮.
- **Evidence:** AUDIT.

**UX-2416 · Severity 1 · Labels look like chips but do nothing**
- **Where:** `App/lib/screens/task_detail_screen.dart:264-271`.
- **What happens:** labels render as outlined Material chips («#casa»), the look of the screen's tappable chips, and do nothing when tapped.
- **Why it fails:** recurring problem #35 (a no-tap element keeps the look of a control); signifiers (Norman 2013).
- **Fix:** show them as one line of text, «#casa · #recados», in `onSurfaceVariant`, without the chip outline.
- **Verify:** widget test: no outline and no tappable node. Add a preview with labels; none exists today.
- **Evidence:** verified in code.

**UX-2417 · Severity 1 · The plan offer splits «mié, 18 de nov» across two lines**
- **Where:** `App/lib/widgets/reminder_ask_sheet.dart:466-511` (`_TaskLine`), `:392-394`.
- **What happens:** render `reminders/offer.asked.es.light.1x` shows «Presentar el proyecto de empresa · mié, / 18 de nov».
- **Why it fails:** guidelines §20.8, a day split from its date; recurring problem #32.
- **Fix:** bind the day phrase with U+00A0 («mié, 18 de nov») before measuring.
- **Verify:** re-render es 1× and ca 2×.
- **Evidence:** current render.

**UX-2418 · Severity 1 · Files: «Eliminar» says the file isn't deleted**
- **Where:**
  - `App/lib/l10n/app_es.arb:402` and `:404` (`fileRemove`, `fileRemoveQuestion`), used at `App/lib/widgets/attachment_panel.dart:140-153` and `:442`;
  - the form's ✕ tooltip `removeFileNamed` («Quitar {file}», `task_editor.dart:1378`).
- **What happens:** Spanish says «Eliminar archivo adjunto» and «¿Eliminar este archivo adjunto?», then «Tu archivo original no se elimina.» The form's ✕ says «Quitar». EN and CA use remove / «treu» throughout.
- **Why it fails:** SC-9; UN-4.
- **Fix:** ES «Quitar archivo» and «¿Quitar este archivo de la tarea?». EN and CA stay as they are.
- **Verify:** string check, and a render of the dialog.
- **Evidence:** strings.

**UX-2419 · Severity 1 · The attach sheet explains phone-only files to every saved task**
- **Where:** `App/lib/widgets/task_editor.dart:684-696`; `fileUploadHelp` (es `:568`, en `:1233`, ca `:547`).
- **What happens:**
  - The «Añadir adjunto» sheet of a saved task opens with 31 words about "older local files" and «Subir en los detalles de la tarea».
  - Since sign-in is required, almost no task has such a file.
  - The 6 MB limit is already said when a file is too big (`fileLimit`).
- **Why it fails:** CO-5; SC-2. It's what UX-1006 left behind (that fix covered new tasks only).
- **Fix:** show the sheet's paragraph only when this task still has a file kept only on the phone (one that shows «Subir»). Otherwise the sheet is the two rows.
- **Verify:** widget test: a saved task with no phone-only file gets two rows and no text.
- **Evidence:** verified in code.

### Decided by the owner, to build as a package

**UX-2032 (existing ID; was "decision", now D9 = (b), DECISIONS 2026-10-31) · A reader chooses their own reminders.** Today `App/lib/screens/task_detail_screen.dart:379` gives the line no tap without edit rights. The app half:

1. **What the reader can do.** On a task that rings for the reader (`reminderRingsHere`: «Todos», or given to them) in a project where they are «lector»:
   - the reminder line becomes the tappable chip: outlined, button role, no "desactivado";
   - it opens the usual sheet, with «Estos avisos son solo para ti.» fixed under the title;
   - a choice shows in the chip at once.
2. **How a choice is saved.** Save it on the phone, and sync it as the reminder-only change the server now accepts. Today two paths block or garble it:
   - `App/lib/services/task_database.dart:326` (`validateList`) throws «This shared list is read-only.», so every save would end in «No se pudo actualizar el recordatorio».
   - `App/lib/repositories/cloud_task_repository.dart:154-166` would turn it into «… (offline copy)» with the red «Este proyecto ahora es de solo lectura…».

   The change must survive a restart, a sync, offline use, and a change the owner makes to the task meanwhile, with no copy and no banner. How it's sent is the implementer's; the server contract is "a reader's PUT that touches only their own reminders".
3. **Nothing else opens.** Title, rows, chips, steps and files stay read-only; there is no ✏, no 🗑 and no bottom bar.
4. **The banner.** On such tasks it changes from «Solo puedes ver esta tarea.» to ES «Solo puedes ver esta tarea y elegir tus recordatorios.»; EN "You can only view this task and choose your reminders."; CA «Només pots veure aquesta tasca i triar els teus recordatoris.» Other read-only tasks keep the old line.
5. **Tasks that don't ring for the reader** stay as they are: «Recordatorio para Ana», or an unassigned task.
6. **Ship it with UX-2403.**

**Verify:**
- Widget test: a reader's task screen → chip → sheet → choice → chip.
- Repository test: a «lector» project accepts a reminder-only change; the sync sends it; no copy.
- Emulator: a «lector» account on the local Docker server, which has migration 0025 and the main session's server change.

**Evidence:** verified in code. No render of a reader's task screen exists; the preview suite should add one, before and after.

WD34 is UX-2408 above.

### Keep
- **The new-task form:** the title first, then Hoy / Mañana / Elegir día. One button names where the task goes. Back keeps the task, and the words are kept until saved. It lands lit, with Deshacer.
- **The plan offer:** it names the task and its day, asks one question with two answers, and offers Deshacer after «Sí».
- **Delete:** at once, with Deshacer. Only a whole series asks first.
- **The reminder sheet:**
  - single choices apply in one tap;
  - a plan shows its words, dots, count and next notice;
  - shared tasks keep «solo para ti» fixed;
  - «Recordatorio para Ana» is drawn as information, not as a control.
- **Every Deshacer in this area** goes through `showFeedback`, with `persist: false` and FeedbackTimeout.

### Progress against UX_REVIEW.md (U1–U14)
- **Advanced:** U5, landing on the task. A typed task lands lit on its day with Deshacer (`task_editor.dart:595-665`).
- **Held:**
  - U11, the names: «Sin fecha», and no «Bandeja», across B2's screens.
  - U12, the reminder question after the first dated save, now with the plan offer. UX-2401 undercuts it: the reminder that then comes is shown as «Sin recordatorio».
- **Still open:** U10 and U13, which are B1's and the owner's. Nothing in B2 regressed.

### Questions for the owner
None new. D9 and WD34 are decided and planned above. UX-2403's "no «Completar» on a reader's reminders" follows D9: "nothing else a reader sends changes".

### Cross-slice notes
- **B1:**
  - WD34 (UX-2408) is a change to the completion message; any change to the agenda itself (header, ring) is B1's.
  - Calendar and Tareas rows stay slid out after a swipe for the whole sync (UX-2402).
- **C:**
  - On every shared task's screen, `TaskActivity` (`activity_screen.dart:325`, an ExpansionTile) reads «Contraído» as a separate live-region stop before «Actividad» (AUDIT `tasks/detail · created-by` #10–11). The reminder sheet's `Semantics(expanded:)` pattern avoids it.
  - At 2× the project and person chips wrap 4 dp apart (AUDIT `detail.created-by` es and ca 2×; `task_assignment_picker.dart`).
- **A:** voice commands still treat a reader's task as view-only. It's A's call whether «recuérdamelo…» by voice should change a reader's own reminders under D9.
- **D:**
  - UX-2405 widens Voz's `capturePrivacy`.
  - The Pro screen's first line (`billingIntro`, «Dictados sin límite y espacio para todos tus archivos.») names 2 of the site's 3 Pro benefits. It leaves out typed sentences turned into tasks, and reminders in your own words.
- **Main session (server; real in code):** the invitation email links the bare https://taskflow.garbar.tech/ (`Backend/core/invitation_email.py:18`, `:130`, `:250`) instead of the invitee's language page (/es/, /ca/), which the app's `site_links.dart` uses.

### Memory notes
- **D9 traps (UX-2032 and UX-2403):**
  - `TaskDatabase.validateList` refuses every local write on a «lector» project (`task_database.dart:326`).
  - The sync's viewer branch turns any pending row there into a personal "(offline copy)" (`cloud_task_repository.dart:154`). The suffix is hard-coded English at `task_database.dart:770`, for editors' conflicts too.
  - A notification's «Completar» writes past both checks (`reminder_engine.dart:749`).
- **After its alert time, the chip and the form's row say «Sin recordatorio: ya ha pasado la hora del aviso»**, whether the reminder rang, was snoozed, or was saved too late: `alertAhead` sees none of them. The emulator capture `notification.tap-landing` proves it.
- **Recurring problem #18 is still in TaskNotifier:** `setCompleted`, `rescheduleTask`, `changeOccurrence`, `setChecklistCompleted` and `restoreTask` end with `await loadTasks()` inside `_mutate`. That is a full sync: lists, pending PUTs, every task page, files. `showLocal()` is the fix pattern.
- **The task screen stays open after Completar.** Opened without an occurrence (Activity, «Tareas con archivos»), it re-picks the next open occurrence on every rebuild.
- **The preview suite has no render** of the Cambiar fecha sheet, the repeat sheet, the step ⋮ menu, the series-delete dialog, the edit form with Más detalles open, or a reader's task screen. Its 2× is linear, while the emulator's 2.0 is Android 14's non-linear scaling, where titles barely grow. Weigh "below the fold at 2×" claims about headline text accordingly.
- **Baselines (2026-10-31):**
  - plain task's screen: 9 targets and 16 words (emulator);
  - complete from the task's screen: 2 taps;
  - change a reminder: 2;
  - set a repeat on a saved task: 7;
  - typed task: 3 plus typing;
  - attach a file to a saved task: 6 plus scrolling;
  - a reader choosing a reminder: impossible.
