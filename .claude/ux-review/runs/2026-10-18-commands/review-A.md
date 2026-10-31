## UX review — Area A: voice capture and voice commands (run 2026-10-18-commands) — 2026-10-18

**Verdict:** Ship after fixes. Plain one-task dictation is unchanged in the app, and every command confirms with one tap and one «Deshacer». But three things need fixing first:
- a task said with a command verb can dead-end;
- «para el 12» reads and lands as «Sin fecha»;
- cancelling a deletion is worded as deleting.

**Walked** (newcomer: Spanish, 2× text, 320 dp; daily user; TalkBack user):
- **Plain dictation**, Pro and free with dictations left: Añadir tarea → speak → Listo → Añadir al calendario. 3 taps, unchanged.
- **New project and task:** «Crea un proyecto de matemáticas y añade terminar la presentación para el 12». 3 taps.
- **A project said that doesn't exist:** «…al proyecto de química». 4 taps (one answer).
- **Find:** «Busca la tarea de la introducción de matemáticas», «¿Qué tengo mañana?». 2 taps, plus Cerrar.
- **Change:** «Cambia la cita del médico… a dentro de una semana». 3 taps; +1 when several tasks match, +1 for a time on a task with no day.
- **Delete:** «Borra la tarea del dentista». 3 taps, +1 dialog for a series. Also cancelled through ✕ and through Cancelar.
- **Mixed:** a task, a change and a deletion. 3 taps.
- **Misread tasks:** «Cambia el aceite del coche el sábado», «Busca piso en Valencia».
- **Free with dictations left:** Rellenar a mano → form.
- **Free at 0 left:** Nueva tarea → monthly notice → Crear una tarea → form. Also the mic widget and the voice shortcut at 0 left.
- **Shared text:** Pro (sent asking for commands) and free (Rellenar a mano).

**Numbers:**
- **Taps:**
  - plain dictation: 3 → 3 (`App/test/voice_command_cards_test.dart:1007` locks the path);
  - voice change: 3;
  - voice delete: 3 (4 for a series);
  - voice project + task: 3; a project said that doesn't exist: 4;
  - free at 0 left, to a dated task: 3 plus typing (4 the first time each month);
  - free share, before typing: 2 → 1 with UX-911.
- **Assistant's wait** for a plain dictation now that every request carries `commands: true`: not measured (UX-912).
- **Tap targets:**
  - one change or deletion: 5 (✕, the button, Cancelar, Volver a decirlo, Ver lo que dije);
  - a search with 3 results and a project: 7;
  - the free mic sheet: 3, the same count as Pro.
- **Project question chips:** 2 + every editable project. 10 projects give 12 chips → at most 6 with UX-908.
- **Monthly notice:** about 25 words and 2 buttons.
- **Button label for a task + a change + a deletion:** «Añadir 1 tarea». It names 1 of the 3 things the tap does.

**How I looked:** I didn't run Flutter. I read the current renders. All were rendered 15:49–15:50, after the last code commit at 15:48:52, with no uncommitted changes in `App/lib`:
- `capture-fill-by-hand-es.png`
- `capture-listening-es-2x.png`
- `review-direct-light.png`
- `review-batch-light.png`
- `new-task-form-es.png`

No preview renders the command cards, the monthly notice or «Nueva tarea». I judged those from the widget code (sizes, paddings, constraints).

### Findings (most severe first)

**UX-901 · Severity 3 · A task said with «cambia» or «busca» can dead-end**
- **Where:**
  - `App/lib/widgets/capture_command_cards.dart:702-711` and `:942-951`: a change or deletion that finds nothing;
  - `:487-492`: a search with no results;
  - `App/lib/screens/voice_task_screen.dart:3229-3230`, `:3377`, `:3415`: a read-only result has no filled button, only «Cerrar»;
  - capture result after a plain dictation.
- **The moment:** "I said «Cambiar la cita del dentista el lunes» to add it, and it says «No encuentro ninguna tarea con «cita dentista»». Where's my task?"
- **What happens:**
  - Every dictation now asks the assistant for commands (`App/lib/services/capture_processor.dart:229`). Everyday task titles start with the command verbs: «Cambiar la cita del dentista», «Cambia el aceite del coche el sábado», «Busca piso en Valencia», «Buscar a los niños a las 5», «Borrar las fotos del móvil».
  - When one comes back as a change, deletion or search, nothing matches. The card says so, and the sheet offers only «Cerrar» and «Volver a decirlo». «Volver a decirlo» is gone at 0 dictations, and saying it again tends to get the same reading.
  - The thought is not captured, and a free account has spent a dictation.
  - If an old completed task matches («Cambiar el aceite» from April, `App/lib/services/task_matcher.dart:196-197`), the card proposes moving it. Nothing on the card says it's completed. «Aplicar» then moves a done task, which won't remind.
- **Why it fails:**
  - No dead ends (lens A).
  - Correcting by saying it again repeats the error; correcting by touch is faster (Karat et al. 1999; Suhm, Myers & Waibel 2001).
  - Doubt should become a choice, not an end (Budiu & Laubheimer 2018).
- **Fix** (no new strings):
  1. When every card is a change or deletion that found nothing, or a search that found nothing, show the existing «Guardar tal cual» as the filled button, above «Cerrar». It does what it does after a slow answer (U7): the phone's parser saves the transcript as a task, with Deshacer. That is allowed for free accounts, because it is a dictation's fallback.
  2. On change and deletion cards, and on pick-list rows, add the existing «Completada» (`commandCompleted`) to a completed task's line, as found rows do.
- **Verify:**
  - Widget test: a result holding one `update` that matches nothing shows «Guardar tal cual». Tapping it saves «Cambia el aceite del coche» on Saturday and lands on it.
  - Real-model check on staging, in ES and CA: say the five phrasings above as plain dictations, and count how many come back as commands. If two or more do, raise this to severity 4.
- **Evidence:** the dead end is verified in code. How often the model reads a task as a command is inferred and needs a real-model check.

**UX-902 · Severity 3 · «Para el 12» shows and lands as «Sin fecha»**
- **Where:**
  - `App/lib/widgets/capture_review_editor.dart:774`: a collapsed card's day line;
  - `App/lib/widgets/task_schedule_label.dart:8-13`: `taskDayLine` returns «Sin fecha» for a task with only a deadline;
  - `App/lib/screens/voice_task_screen.dart:2897-2900`, `:2927-2936` (`_apply`) and `:2443-2448`, `:2476-2482` (`_save`): «Añadida sin fecha», then the Sin fecha row is lit;
  - any result with a project card or several tasks.
- **The moment:** "I said «para el 12» and it says «Sin fecha». Did it lose the day?"
- **What happens:**
  - The plan's own example, «Crea un proyecto de matemáticas y añade terminar la presentación para el 12», returns the task with only a deadline (12 Nov).
  - The project card makes the result compact (`voice_task_screen.dart:3213-3214`). A collapsed card shows only «📅 Sin fecha»; «Vence jue, 12 nov» appears only once the card is opened.
  - After the tap, the message reads «Proyecto creado · Añadida sin fecha», and Calendar lights the Sin fecha row. Calendar does also list the task on 12 Nov (`Task.calendarOccurrencesOn` includes deadlines).
  - The same happens to any deadline task in a dictation of several, including the owner's 2026-10-15 example ("…by Thursday at 5").
- **Why it fails:**
  - Show what was understood (Budiu & Laubheimer 2018).
  - Gulf of evaluation (Norman 2013).
  - The last line read contradicts what was said (peak–end, Kahneman et al. 1993).
- **Fix:**
  1. Where a card shows only the day line and the task has no day but a deadline, show `taskDeadlineLabel` with the flag icon instead: «Vence jue, 12 nov» / "Due Thu, 12 Nov" / «Termini: dj., 12 de nov.». Apply it to:
     - the collapsed card (`capture_review_editor.dart:774`);
     - pick-list rows (`capture_command_cards.dart:637`);
     - found rows (`:536-539`), which today show the deadline's date bare, as if it were the day.

     The opened card keeps its «Sin fecha» line, with the deadline row under it.
  2. A saved task with only a deadline lands on the deadline's day, and the message names it. New key `taskAddedDue`: ES «Añadida · vence el {date}» / EN "Added · due {date}" / CA «Afegida · venç el {date}». It is used instead of «Añadida sin fecha» only when there is a deadline.
- **Verify:** widget test: a project command plus a deadline-only draft shows «Vence jue, 12 nov» on the collapsed card. After the tap, Calendar selects 12 Nov with the row lit, and the message reads «Proyecto creado · Añadida · vence el jue, 12 nov».
- **Evidence:** verified in code.

**UX-903 · Severity 3 · Not deleting a task is worded as deleting it**
- **Where:**
  - `App/lib/widgets/capture_command_cards.dart:303-308` with `:784`, `:959`, `:984`: the ✕ is named «Quitar {title}»;
  - `App/lib/screens/voice_task_screen.dart:2624-2628`: «Quitada»;
  - `:3360-3364`: «No queda nada por revisar · No se añadirá nada.»;
  - `:251-270` with `:3085-3094`: Cancelar asks «¿Quieres conservarlo para más tarde?», with a red «Descartar»;
  - deletion and change cards.
- **The moment** (TalkBack): "«Quitar Ir al dentista, botón» — that's how I remove it." Double-tap. "«Quitada». Good, it's gone." It isn't.
- **What happens:**
  - On a deletion card, the ✕ means "don't delete", but TalkBack names it «Quitar Ir al dentista» (EN "Remove Ir al dentista"), which is the deletion's own name.
  - After ✕, the message says «Quitada», the button becomes «Terminar» and the empty state says «No se añadirá nada.». The task looks deleted and survives.
  - Cancelar asks «¿Quieres conservarlo…?». The «lo» reads as the task, and the red «Descartar» reads as "delete it", yet Descartar is the choice that keeps the task.
- **Why it fails:**
  - A control's name must match its purpose (WCAG 2.2, 2.4.6 and 4.1.2).
  - Status says what happened (Nielsen 2001).
  - One concept, one name (ISO 24495-1).
- **Fix:** on command cards only, name the outcome.
  - **✕ tooltip and label:**
    - deletion: ES «No eliminar {title}» / EN "Don’t delete {title}" / CA «No suprimeixis {title}»;
    - change: ES «No cambiar {title}» / EN "Don’t change {title}" / CA «No canviïs {title}»;
    - new project: ES «No crear {name}» / EN "Don’t create {name}" / CA «No creïs {name}».
  - **Message after ✕:** ES «No se eliminará» / «No se cambiará» / «No se creará»; EN "Won’t be deleted" / "Won’t be changed" / "Won’t be created"; CA «No es suprimirà» / «No es canviarà» / «No es crearà». Deshacer stays.
  - **`captureRemovedDraftsHelp`:** ES «No se hará ningún cambio.» / EN "Nothing will change." / CA «No es farà cap canvi.». This is true for removed tasks too.
  - **`captureKeepQuestion`:** ES «¿Conservar lo que has dicho para más tarde?» / EN "Keep what you said for later?" / CA «Vols conservar el que has dit per a més tard?». It names the words, not the task. Whether Cancel should ask here at all is question 1.
- **Verify:**
  - Widget test (ES, semantics): the deletion card's ✕ reads «No eliminar Dentista». After it, «No se eliminará» shows and the task still exists.
  - The keep question reads the new text.
  - Phone with TalkBack: on a deletion card, «Se eliminará: …» is read, then «No eliminar …».
- **Evidence:** verified in code.

**UX-904 · Severity 2 · Shared text is read for commands, not as a task**
- **Where:**
  - `App/lib/services/capture_store.dart:129`: shared text gets `source: 'typed'`;
  - `App/lib/services/capture_processor.dart:229`: `commands: true` on every request;
  - with Pro: Share → capture sheet → Listo.
- **The moment:** "I shared my boss's message «Cambia la reunión al jueves y busca el informe» to remember it, and it shows a search."
- **What happens:**
  - A share is someone else's words, full of imperatives. With Pro it goes to the assistant with commands on.
  - So «cambia…», «busca…» and «borra…» can come back as a change, a search or a deletion of the person's own tasks, instead of tasks.
  - It is the same dead end as UX-901. At worst, «Cambia la reunión al jueves» moves the person's own «Reunión».
- **Why it fails:**
  - Match the real world: sharing to a task app means "remember this" (Nielsen 1994).
  - Error prevention.
- **Fix:**
  - `acceptEntry` marks shares `source: 'shared'` on the phone; the server still receives `typed`.
  - `CaptureProcessor` sends `commands` only for dictations and words the person typed. Decision 7 (typed commands with Pro) stays.
- **Verify:**
  - Unit test: a shared capture's request has no `commands`; a typed one does.
  - Phone (Pro): share «Busca el informe de ventas» to TaskFlow; the result is a task.
- **Evidence:** the flag and the source are verified in code; the model's reading is inferred.

**UX-905 · Severity 2 · The confirming button doesn't name what the tap does**
- **Where:**
  - `App/lib/screens/voice_task_screen.dart:3250-3267`: the label;
  - `App/lib/l10n/app_es.arb:1246`: `commandApply` «Aplicar»;
  - tests `App/test/voice_command_cards_test.dart:943` and `:1255`.
- **The moment:** "«Aplicar»… apply what?" And: "It said «Añadir 1 tarea». I didn't know it would also delete the dentist."
- **What happens:**
  - One change reads «Aplicar» / "Apply".
  - When tasks are mixed with changes or deletions, the button keeps the add label:
    - «Añadir al calendario» also moves «Ir al médico» and deletes «Dentista» (test `:943`);
    - at 2× on 320 dp, «Añadir 1 tarea» also moves one task, deletes another and creates a project, and the deletion card sits below the fold (test `:1255`).
  - Only a deletion on its own gets the red «Eliminar».
- **Why it fails:**
  - Buttons are verbs that name the result (ISO 24495-1).
  - Error prevention for destructive actions (Nielsen 1994).
  - People scan the button, not every card (Nielsen 1997).
- **Fix:** label the button by what the tap does.
  - **A change to one task's day or time only:** the existing `reschedule`: «Cambiar fecha» / "Reschedule" / «Canvia la data».
  - **Other changes only:** the existing `saveChanges`: «Guardar cambios» / "Save changes" / «Desa els canvis».
  - **Unchanged:** deletions only (red «Eliminar»), projects only («Crear proyecto»), and tasks with or without their new project (the add labels).
  - **Mixes:** new keys replacing `commandApply`:
    - «Añadir y cambiar» / "Add and change" / «Afegeix i canvia»;
    - «Añadir y eliminar» / "Add and delete" / «Afegeix i suprimeix»;
    - «Cambiar y eliminar» / "Change and delete" / «Canvia i suprimeix»;
    - «Añadir, cambiar y eliminar» / "Add, change and delete" / «Afegeix, canvia i suprimeix».

    A project is named only when it is all the tap does.
- **Verify:**
  - Tests `:943` and `:1255` expect «Añadir, cambiar y eliminar».
  - One change of day reads «Cambiar fecha».
  - The CA mixed label wraps to two lines at most at 2× on 320 dp.
- **Evidence:** verified in code and in the existing tests.

**UX-906 · Severity 2 · A project created by voice is never shown**
- **Where:**
  - `App/lib/screens/voice_task_screen.dart:2921-2937`: it lands only for tasks and changes;
  - `:2893-2895`: «Proyecto creado»;
  - compare the manual `createProject`, which opens the new page (UX-327).
- **The moment:** "It says «Proyecto creado». Where is it?"
- **What happens:**
  - «Crea el proyecto Física» closes the sheet onto Calendar with «Proyecto creado · Deshacer». Nothing shows the project.
  - When the dictation also adds tasks to it, Calendar lights them, but only if its project filter includes the new project (`calendar_screen.dart:296-301`).
  - Creating a project by hand opens its page.
- **Why it fails:**
  - Show where a new thing went (change blindness, Rensink et al. 1997).
  - Consistency with manual creation (Nielsen 1994).
- **Fix:** when the tap creates exactly one project, and every task it adds goes into that project (or it adds none):
  - open that project's page, as UX-327 does;
  - light its new tasks there, through the `page` landing that project pages already use;
  - show the message there.

  Other results land on Calendar, as now.
- **Verify:** widget test:
  - «Nuevo proyecto: Física» alone opens the Física page with «Proyecto creado»;
  - with «Estudiar el tema 2», the row is lit there;
  - Deshacer removes both and reopens the result.
- **Evidence:** verified in code.

**UX-907 · Severity 2 · A search hides the day or status it used**
- **Where:** `App/lib/widgets/capture_command_cards.dart:463-471` (the heading) and `:487-492` (no results).
- **The moment:** "I asked «¿Qué tengo mañana?» and it says «Tareas». Are these tomorrow's?"
- **What happens:**
  - The heading names the words, the project or the person. It never names the status (pending, done) or the period (tomorrow, this week) that filtered the list.
  - Without words, a project or a person, it is just «Tareas».
  - An empty result says «No hay ninguna tarea» without saying for when.
- **Why it fails:**
  - Show the interpretation, so a misheard filter can be caught (Budiu & Laubheimer 2018).
  - Put the distinguishing words first (Nielsen 2006).
- **Fix:** one quieter line under the heading, only when the search has a period or a status, joined with « · ».
  - **Period:** `dayLabel` for one day («Mañana»), otherwise new key `commandFindPeriod`: ES «Del {from} al {to}» / EN "{from} to {to}" / CA «Del {from} al {to}».
  - **Status:** new keys `commandFindOpen`: ES «Pendientes» / EN "To do" / CA «Per fer»; and `commandFindDone`: ES «Completadas» / EN "Completed" / CA «Completades». These match `agendaCounts`.
- **Verify:** widget test: a search from tomorrow to tomorrow shows «Tareas», then «Mañana». Status completed adds «Completadas».
- **Evidence:** verified in code.

**UX-908 · Severity 2 · Project question asks yes/no, then lists every project**
- **Where:**
  - `App/lib/widgets/capture_command_cards.dart:192-227` (`ProjectChoices`) and `App/lib/widgets/capture_review_editor.dart:293-330`: every editable project is passed in;
  - «…al proyecto de química» when no such project exists;
  - the «Nuevo proyecto» card when two projects match.
- **The moment:** "«¿Crear el proyecto «Química»?» — so where's «sí»? And what do «Casa», «Trabajo», «Compras» mean here?"
- **What happens:**
  - The question is yes/no, but the answers are «Crear «Química»», then one chip per editable project (similar ones first), then «Sin proyecto». Nothing says those chips mean "put it there instead".
  - 10 projects give 12 chips.
  - In the «Nuevo proyecto» card, at 2× on 320 dp, the chips get about 204 dp, so names are cut («Crear «Física y Quím…»»).
- **Why it fails:**
  - Hick–Hyman law (Hick 1952); choice overload when the options are unfamiliar (Scheibehenne et al. 2010).
  - The question and its answers must match (Budiu & Laubheimer 2018).
- **Fix:**
  - On the task's card, ask where it goes: ES «¿En qué proyecto la pongo?» / EN "Which project should it go in?" / CA «A quin projecte la poso?». The «Nuevo proyecto» card keeps «¿Crear el proyecto…?», because there the person asked to create one.
  - Chips, in both places:
    - «Crear «Química»» first;
    - at most 3 projects like the name;
    - «Otro proyecto…» / "Another project…" / «Un altre projecte…», which opens the existing project picker, shown only when more projects exist;
    - «Sin proyecto», on the task's card.

    That is at most 6 chips.
- **Verify:** widget test with 10 projects: at most 6 chips. «Otro proyecto…» opens the picker, and a pick there answers the question.
- **Evidence:** verified in code.

**UX-909 · Severity 2 · «Crea el proyecto Química» can't create it beside similar names**
- **Where:**
  - `App/lib/widgets/capture_command_cards.dart:387-399`: an existing match only says «Ya tienes «…»», with no ✕ and no choice;
  - `Backend/docs/VOICE_COMMANDS.md:246`: tier 2 matches «química» to «Física y Química».
- **The moment:** "I said «crea el proyecto Química». It says I already have «Física y Química». That's not what I asked."
- **What happens:**
  - A `project` command matched leniently arrives with `existing_list_id`. The card states «Ya tienes «Física y Química»» and «Las tareas van ahí.», and offers nothing else.
  - The person asked to create; the app decided otherwise.
  - The match is the server's design; the fix is on the card.
- **Why it fails:**
  - User control and freedom (Nielsen 1994).
  - The contract's own rule: never guess between two candidates.
- **Fix:**
  - When the existing project's name differs from the name said (ignoring case and accents), show the two-matches card: «¿Crear el proyecto «Química»?» with [Crear «Química»] [Física y Química]. The tasks follow the choice, as `_changeCommand` already does.
  - Equal names keep «Ya tienes «Matemáticas»».
- **Verify:** widget test: a `project` «Química» with the `existing_list_id` of «Física y Química» shows both chips. «Crear «Química»» creates it on the tap, and its tasks go there.
- **Evidence:** verified in code; the match itself is the server's documented behaviour.

**UX-910 · Severity 2 · At 0 left, the mic widget opens a form unexplained**
- **Where:**
  - `App/lib/screens/voice_task_screen.dart:76-87`: `askedToSpeak` is dropped when the form opens;
  - `App/lib/main.dart:197-203`: the widget and the voice shortcut;
  - `App/lib/widgets/task_form_entry.dart:27-47`: the notice shows once a month;
  - a free account with 0 dictations left.
- **The moment:** "I tapped the microphone. Why is there a form? Is the mic broken?"
- **What happens:**
  - The widget («Toca para dictar una tarea») and the «Dictar una tarea» shortcut open the task form.
  - The first time in a month, the notice explains it. Every later time the form opens with no word about dictations.
  - Until this change, the sheet said «Sin dictados gratis hasta el {date}.» with «Ver Pro» on these entries (UX-498, UX-106; the code is still at `:1859-1879`).
- **Why it fails:**
  - Visibility of system status (Nielsen 1994).
  - Gulf of evaluation (Norman 2013).
- **Fix:**
  - Pass `askedToSpeak` to `openTaskForm`.
  - When there is no mic, the form shows the existing `freeVoiceUsedUp` line, with «Ver Pro», above the title, as the sheet did: «Sin dictados gratis hasta el 1 nov.» / "No free dictations until 1 Nov." / «Fins al dia 1 de nov. no tens dictats gratuïts.».
  - Only for these two entries; «Nueva tarea» stays clean. No new strings. (The shortcut's wording is an open owner question, not part of this fix.)
- **Verify:**
  - Widget test: a `voice` entry at 0 left, after the notice was seen, opens the form showing `free-voice-used-up`; «Nueva tarea» opens it without.
  - Phone: tap the widget twice in one month at 0 left.
- **Evidence:** verified in code.

**UX-911 · Severity 2 · «Rellenar a mano» names a form nobody has seen yet**
- **Where:**
  - `App/lib/screens/voice_task_screen.dart:2057-2062`: the button;
  - `:1767-1772` and `:1820`: «Listo» becomes «Rellenar a mano» on typed words;
  - `App/lib/main.dart:197-203`: shared text opens the sheet;
  - `App/lib/l10n/app_es.arb:1191`;
  - render `App/build/capture-fill-by-hand-es.png`.
- **The moment:**
  - In the mic sheet: "Rellenar… what? There's nothing to fill in."
  - After sharing a message: "The text is already here. Why «Rellenar a mano»?"
- **What happens:**
  1. The keyboard became «✏ Rellenar a mano» / "Fill in by hand" / «Emplena-la a mà». The thing to fill in isn't on screen. For the person it does what Pro's «Escribir» does: type instead.
  2. A free account's shared text opens the sheet with the words in the field and «Rellenar a mano» as the filled button. That is a second screen whose only forward action leads to the form.
- **Why it fails:**
  - Use the person's words (Nielsen 1994).
  - One goal, one name (ISO 24495-1).
  - The app should absorb the extra step (Tesler).
- **Fix:**
  1. Label this button with the existing «Escribir» / "Type instead" / «Escriu» (`captureTypeInstead`), with the keyboard icon. Delete `captureFillByHand`.
  2. For an account without Pro, open shared text, and a typed capture resumed from «Sin guardar», straight in the form, with the words as title and notes. Remove the capture once the form saves.

  «Listo» then never needs the «Rellenar a mano» label.
- **Verify:**
  - Widget test: on a free account, shared «Pedir cita en el dentista» opens NewTaskScreen with that title, and no capture sheet.
  - The mic sheet's button reads «Escribir» (CA «Escriu») at 2× on 320 dp.
- **Evidence:** verified in code; seen in the current render.

**UX-912 · Severity 2 · Plain dictation's wait with commands on is unmeasured**
- **Where:** `App/lib/services/capture_processor.dart:229`; the «Entendiendo…» wait after Listo.
- **The moment** (daily user): "It used to be quicker."
- **What happens:**
  - Every dictation, including a plain one-task one, now asks for commands. The server sends the model its commands section, with examples in three languages, and the answer always carries `commands`.
  - The app's own path is unchanged (test `:1007`).
  - The assistant's wait, already the longest step of capture (UX-616: 1.3–20.5 s on staging), hasn't been measured with the flag.
- **Why it fails:**
  - The speed bar (DECISIONS, 2026-10-13).
  - Past 1 s, every added second is felt (Miller 1968; Nielsen 1993).
- **Fix:**
  - Before shipping, measure 10+ one-task dictations with the flag and 10+ without, on the same phone and network. Read `extraction_ms` p50 and p95 in Diagnóstico de captura.
  - If the flag adds 300 ms or more at p50, the cause is server-side (a longer prompt). Decide it together with UX-616.
- **Verify:** both sets of numbers, recorded in this run's report.
- **Evidence:** inferred; needs a staging measurement. The cause is likely server-side.

**UX-913 · Severity 2 · Found tasks show the tick circle but open instead**
- **Where:** `App/lib/widgets/capture_command_cards.dart:564-572` (the found row's icon), compared with `App/lib/widgets/task_tile.dart:91-97` (the round checkbox that completes a task everywhere else).
- **The moment:** "There's the dentist. I'll tick it off." The task opens instead.
- **What happens:**
  - Each found task starts with an empty circle, or a ticked one when done: the shape of the completion checkbox in every list.
  - Here the whole row opens the task.
  - Nothing else signals that the row opens.
- **Why it fails:**
  - The same look must behave the same (Nielsen 1994).
  - Visible signifiers (Norman 2013).
- **Fix:**
  - Remove the circle and the check from found rows. The strikethrough and «Completada» already mark done ones.
  - Add a trailing `chevron_right`, like the result's other rows that open something (`capture_review_editor.dart:284-286`).
- **Verify:** widget test: a found row has no circle and has a chevron; a tap opens TaskDetailScreen.
- **Evidence:** verified in code.

**UX-914 · Severity 2 · Three ways a change can't be finished by tapping**
- **Where:**
  - `App/lib/widgets/capture_command_cards.dart:613` and `:646`: the pick list shows 5 matches, and «Y 4 más» is plain text;
  - `App/lib/services/task_matcher.dart:189` with `capture_command_cards.dart:672-680`: a task in a view-only project is skipped, then the card says «No encuentro…»;
  - `capture_command_cards.dart:772-775` with `App/lib/services/command_plan.dart:244-249`: two people with the same name get a statement, not a choice.
- **The moment:**
  - "My «Llamar a Ana» isn't among the five, and «Y 4 más» does nothing."
  - "It can't find «Informe», but it's right there in my calendar."
  - "There are two Pauls — let me pick one."
- **What happens:**
  1. Only 5 matches can be picked. «Llamar…» tasks easily pass five.
  2. A match in a view-only project gets «No encuentro ninguna tarea con «informe»», which is untrue.
  3. «Asigna el informe a Paul», with two Pauls, shows «Hay varias personas que se llaman Paul.» and nothing to tap. The change can't be applied.
- **Why it fails:**
  - No dead ends.
  - Doubt becomes a choice (Budiu & Laubheimer 2018).
  - Messages say what happened (Nielsen 2001).
- **Fix:**
  1. «Y 4 más» becomes a TextButton, new key `commandShowMore` (plural): ES «Ver {count} más» / EN "Show {count} more" / CA «Mostra’n {count} més». It lists the rest in the card.
  2. When the only matches are view-only, a new key `commandViewOnly`: ES ««{title}» es de un proyecto que solo puedes ver.» / EN "“{title}” is in a project you can only view." / CA ««{title}» és d’un projecte que només pots veure.».
  3. Under the two-people line, one chip per member whose name starts with the name said (ignoring case and accents), one tap each. The before → after line then shows the person chosen.
- **Verify:** widget tests:
  - 8 matches: «Ver 3 más» shows them all, and the 7th can be picked;
  - a view-only match shows the new line;
  - two Pauls: two chips, and a tap makes the change ready.
- **Evidence:** verified in code.

**UX-915 · Severity 1 · Command cards' questions look like footnotes; time hidden**
- **Where:**
  - `App/lib/widgets/capture_command_cards.dart:796-837`: «¿Qué día?» is a grey `_Note`, and «Elegir día» never shows the day;
  - `:192-198`: the project question is plain text;
  - compare the result's question box at `App/lib/widgets/capture_review_editor.dart:166-176`;
  - `App/lib/services/command_plan.dart:207-211`: the time isn't shown until a day is picked.
- **The moment:** "«¿Qué día?» — small grey text. And did it get «a las 5»?"
- **What happens:**
  - The result's other questions sit in a tinted box; these sit in the style of footnotes.
  - «Pon el médico a las 5», on a task with no day, shows only «¿Qué día?». The 17:00 it understood stays hidden until a day is tapped.
  - After «Elegir día», the chip still reads «Elegir día». The form's same chip shows the day picked (`task_editor.dart:979`).
- **Why it fails:**
  - Consistency (Nielsen 1994).
  - Show what was understood (Budiu & Laubheimer 2018).
- **Fix:**
  - Put both questions in the existing question box.
  - `commandWhichDay` takes `{hour}` and `{time}`, as `notificationAt` does: ES «{hour, plural, one{¿Qué día, a la {time}?} other{¿Qué día, a las {time}?}}» / EN "Which day, at {time}?" / CA «{hour, plural, one{Quin dia, a la {time}?} other{Quin dia, a les {time}?}}».
  - The «Elegir día» chip shows the day picked, as it does in the form.
- **Verify:** widget test: «17:00» on a task with no day shows «¿Qué día, a las 17:00?» in the box. After picking Thursday, the chip reads «jue, 22 oct».
- **Evidence:** verified in code.

**UX-916 · Severity 1 · Copy slips in command cards and the monthly notice**
- **Where and fix:**
  - **`commandFindPerson`** (`app_es.arb:1249`, `app_en.arb:2298`): «Tareas de {name}» / "{name}’s tasks" now also reads as "created by", since tasks show «Creada por». The project filter says «Para mí» and the person's name. → ES «Tareas para {name}» / EN "Tasks for {name}". CA «Tasques assignades a {name}» is already clear.
  - **`commandExistingProjectTasks`** (`app_es.arb:1242`): «Las tareas van ahí.» shows for a single task too. → ES «{count, plural, =1{La tarea va ahí.} other{Las tareas van ahí.}}» / EN "{count, plural, =1{The task goes there.} other{The tasks go there.}}" / CA «{count, plural, =1{La tasca hi va.} other{Les tasques hi van.}}».
  - **EN `commandWhichToChange` and `commandWhichToDelete`** (`app_en.arb:2377`, `:2381`): "Which one should change?" / "Which one should be deleted?" → "Which one do you want to change?" / "Which one do you want to delete?", as in ES and CA.
  - **EN `freeVoiceNoticeBody`** (`app_en.arb:1959`): "…with the form, with no limit." → "You can keep creating tasks with the form, as many as you like. …".
  - **Priority icon:** the priority line on a change card uses the "low priority" glyph, even when raising to Alta (`capture_command_cards.dart:847`). The app's priority icon is the flag (`task_editor.dart:831`, `task_detail_screen.dart:327`) → `Icons.flag_outlined`.
  - **New-project chip:** when the «Nuevo proyecto: Física» card is shown, the task's chip repeats «Nuevo proyecto: Física» (`task_list_picker.dart:136`), which reads like two projects. → In that case the chip shows just «Física», with the new-folder icon.
- **Verify:** catalog test for the strings; widget test for the chip label.
- **Evidence:** verified in code.

### Keep
- **One tap and one «Deshacer»:** one sheet, one confirming tap and one «Deshacer» for everything a dictation holds. A deletion syncs only once «Deshacer» has gone.
- **Before → after:** «mié, 21 oct → dom, 25 oct», read by TalkBack as «Fecha y hora: de … a …».
- **Deletion:** the deletion card leads with «Se eliminará:» in the error colour, never colour alone. The red «Eliminar» button appears only when deleting is all the tap does.
- **Nothing silent:** nothing is created without the tap. A project that doesn't exist becomes a question, and its tasks wait for the answer.
- **Plain dictation:** its path looks and saves exactly as before (`voice_command_cards_test.dart:1007`).

### Progress against UX_REVIEW.md (U1–U14)
- **U4** (result in the sheet, date as the hero): **advanced**. Every command uses the same sheet, cards and button. It **regressed** for deadline-only tasks in compact cards (UX-902).
- **U5** (land on the task): **advanced**. A changed task lands lit on its new day. **Still open** for a project made by voice (UX-906) and deadline-only tasks (UX-902).
- **U7** (Guardar tal cual): **still open** on command results that find nothing (UX-901).
- **U2** (Cancel asks): **holds**, but its question misleads on deletions (UX-903).
- **U8** (one creation control): **holds**. One button, whose label becomes «Nueva tarea» at 0 left (question 5).
- **U9** (sheet controls): **holds**. Free accounts get a labelled button in the keyboard's place (UX-911).
- **U1, U3, U6, U10–U14:** unchanged by this scope.

### Questions for the owner
1. **Cancel on a result with no task to add.** When a result only changes, deletes or creates projects, should Cancelar just close, meaning "don't do it"? Today it asks keep-or-discard, as U2 does for spoken words. Recommendation: yes. The words can be said again, but at the cost of a free dictation.
2. **Dictated words in the form.** When dictated words go to the form through «Rellenar a mano», may the phone's parser fill in the day and time, as «Guardar tal cual» does for a dictation? Today «Médico el viernes a las 5» becomes a title with no day, and Back saves it that way (D12).
3. **«Guardar tal cual».** Rename it «Guardar como tarea» / "Save as a task" / «Desa-ho com a tasca», now that a dictation can be a command? After 8 s it is the filled button, so it is easy to tap on «Borra la tarea del dentista», which then becomes a new task. This changes D3/U7's wording.
4. **Order of a search by period.** Should a search by period («¿qué tengo esta semana?») list by day, not newest first (plan item 5)?
5. **The button at 0 left.** Keep «Añadir tarea» with the + icon instead of «Nueva tarea»? The icon already shows the change, and renaming the one primary button each month costs recognition. It also needs `tasksEmptyForm` and `inboxEmptyForm`.

### Cross-slice notes
- B: EN `saveChanges` reads "Save Changes" (title case). UX-905 reuses it, so make it "Save changes".
- B: the form opened from the sheet gets dictated date words in its title and no day (question 2).
- B: `taskDayLine` and `taskDeadlineLabel` are shared with B's screens; agree there on UX-902's deadline fallback.
- B/C: a Calendar filtered to one project hides tasks a dictation files elsewhere (UX-302's open question). UX-906 sidesteps this only for new projects.
- C: «Ya tienes «…»» comes from the server's lenient match (`existing_list_id`); UX-909 changes only the card.
- D: the widget and shortcut wording at 0 left is an open owner question; UX-910 only adds an existing line to the form.

### Memory notes
- **Command cards' look.** The cards (`capture_command_cards.dart`) share one frame: surfaceContainerLow, 22 dp corners, an outlineVariant edge, and a 1.5 dp error edge for deletions. Each starts with an icon, a titleMedium line and ✕, and has muted notes inset by 34 dp.
- **Command results' behaviour.**
  - Order: new projects, then tasks, then find, change and delete, in the order said.
  - One filled button and one «Deshacer» cover everything.
  - A deletion alone gets a red «Eliminar».
  - Read-only results (a search, or nothing found) have no filled button, only «Cerrar».
- **Free accounts:**
  - with dictations left, the sheet's keyboard is «Rellenar a mano» and opens the form;
  - at 0 left, the button reads «Nueva tarea» and opens the form;
  - the used-up notice shows once per account per month (`free_voice_notice_provider.dart`);
  - `openTaskForm` (`task_form_entry.dart`) is the form's one entry point, and `showCaptureSheet` sends free typing entries there.
- **Recurring problems this run:**
  - what was understood is hidden in compact cards (deadline-only shows «Sin fecha»);
  - one generic label when a tap does several kinds of thing;
  - «Quitar» / «Quitada» / «Descartar» wording on destructive cards;
  - choice lists that list every project;
  - a new entry path that drops an earlier explanation (`askedToSpeak`).
- **Previews:** none render command cards or the monthly notice. Next time, ask for `WRITE_REVIEW_PREVIEWS` shots of a change, a deletion, a search and a project card, light and dark.
