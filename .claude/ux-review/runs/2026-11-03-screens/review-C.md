## UX review — C · Meeting notes: recording, after Stop, the note and its task — 2026-11-03

**Verdict:** Ship after fixes. Recording itself is clear and calm. Four things would stop the newcomer: the to-do list in «Crear tarea» ticks things as done instead of choosing them; the saved task can't be seen while «Crear tarea» invites a second one; the stopped-recording card asks three questions that look the same; and dictation can still reach for the microphone while a meeting is recording.

**Context and evidence.**
- Branch `claude/project-thread-xqvgpc`, commit `3efed60`. There is no `refs/ux-review/last`, and every file in scope is new in that commit, so I read each one in full.
- The renders in `App/build/ux/meetings/` and `App/build/ux/notes/` (22:28–22:32) are newer than every file under `App/lib` and `App/assets` (`find -newer` lists none), so they are current evidence.
- Evidence levels are widget-test renders, AUDIT.md measurements and code. There are no device captures this run.
- `../UX_REVIEW.md` doesn't exist in this checkout, so I can't report progress against U1–U14.

**Walked** (Newcomer, Daily user, TalkBack user; ES 1×/2×, CA 2×, EN 2×, dark):
1. **Pro, Notes tab to a task:** Notas → «Grabar una reunión» → (first time: Android's microphone dialog) → «Parar» → «Preparando tus notas…» → the note opens in place → «Crear tarea» → review → «Añadir tarea». That's 5 taps, plus the permission and the review.
2. **Free account:** Notas → «Grabar una reunión» → Pro screen (reason box). 1 tap to a paywall.
3. **Recording states:** listening, low space (can't start), space low (records on), microphone refused, start failed, and Descartar → question → «Seguir grabando» or «Descartar».
4. **After Stop:** preparing, waiting for connection, out of space, microphone failed, can't make notes, expired, Pro required, allowance used, nothing heard.
5. **Notes tab lines:** recording (Abrir), stopped (Continuar / Terminar / Descartar), waiting, preparing, held back.
6. **The note:** reading it, «Crear tarea», the review, Cancel, «Añadir tarea», and what follows.

**Numbers**
- **Notes tab, list:** tap targets 11 → 12 (+«Grabar una reunión», 186 × 48 dp). Words above the first note: 2 → 5.
- **Notes tab, empty:** the first content is now «Grabar una reunión» (3 words), above the 15-word teaching line.
- **Recording screen:** 3 targets (Atrás, Parar 312 × 84 dp, Descartar 92 × 48 dp, 8 dp apart) and 11 words.
- **Stopped card:** 10 words and 3 look-alike choices with no primary. At ES 1× they already stack (280 dp inner width). At 2× the card is about 395 dp tall.
- **Meeting note:** the to-dos (the reason for «Crear tarea») start below the whole body, all chapters included. Even with the short test meeting, TalkBack reaches them after 6 nodes, off screen.
- **Crear tarea review:** removing a to-do takes 2 taps behind ⋮ («Quitar paso»). Ticking takes 1 tap and marks it done.

### Findings (most severe first)

**UX-2701 · Severity 3 · Review ticks to-dos as done, not as "keep"**
- Where: `App/lib/widgets/note_task.dart:43-56` (open steps go into the checklist unticked); `App/lib/widgets/checklist_editor.dart:149-167` (the checkbox sets done), `:200-221` (remove sits behind ⋮). Render `meetings/note.review.es.light.1x.png` shows «Pasos · 0/3» with empty boxes.
- The moment: "Which of these do I want in my task? I'll tick the two that are mine."
- What happens: each tick marks that to-do **done**, so the task is saved with the chosen steps already completed and the unwanted ones still open. To leave a to-do out, the person has to find ⋮ → «Quitar paso».
- Why it fails:
  - MN-22 asks for "untick what they don't want before saving", a select model. The build uses a done model that looks the same.
  - A list of checkboxes under a "choose what to bring" step reads as selection (Jakob's law, PL-1).
  - The real control is hidden (H; OL-3 A visible control for everything; recurring problem 6).
- Fix, as MN-22 describes it:
  - In this review only, show the to-dos already ticked, under the heading ES «Pasos que se añaden» / EN "Steps to add" / CA «Passos que s'afegeixen».
  - Unticking leaves a to-do out. The saved task gets the ticked ones as **open** steps.
  - Don't show ⋮ there.
  - If a separate mode is too much, the smaller fix is to keep the editor but replace ⋮ with a visible ✕ («Quitar paso») on each row of this review, and add nothing else.
- Verify: a widget test where ticking or unticking two of three to-dos and saving gives a task with exactly the kept ones, all open. Check the render at ES 2×.
- Evidence: verified in code, seen in a current render.

**UX-2702 · Severity 3 · Task saved out of sight; «Crear tarea» invites a duplicate**
- Where: `App/lib/widgets/note_task.dart:69-74` (sheet opened over the note, `useScope: false`); `App/lib/screens/voice_task_screen.dart:4140-4170` (after saving, the sheet pops back to the note, and Calendar's focus is set where nobody is looking); `App/lib/screens/task_detail_screen.dart:572` (`noteMakesTask` still true, because the note's steps are still open).
- The moment: "It said «Añadida sin fecha»… where? The button's still there. Maybe it didn't work. I'll tap it again."
- What happens:
  - «Añadir tarea» closes the sheet. The person is back on the note with a snackbar at the edge, ES «Añadida sin fecha · Deshacer».
  - The task is in Tareas under «Sin fecha», out of sight.
  - The note still shows «Crear tarea», and a second tap makes a second identical task.
- Why it fails:
  - UN-2 Confirm in place, not only in a snackbar; SC-11 End on visible success.
  - Change blindness (Rensink et al. 1997).
  - The severity scale's own example ("a saved task they can't see, so they add it twice").
  - Peak–end: this is the ending the owner asked for.
- Fix:
  - After «Añadir tarea» from a note, open the new task's page (`TaskDetailScreen`) over the note, so Back returns to the note.
  - The note remembers the task it made (a local link). While that task exists, the button reads ES «Ver tarea» / EN "View task" / CA «Mostra la tasca» and opens it.
  - Keep «Deshacer» in the snackbar.
- Verify: a widget test where Crear tarea → Añadir tarea lands on the task page, and back on the note there is no «Crear tarea» but «Ver tarea». Add a render of the note after a task was made.
- Evidence: verified in code (the test at `App/test/meeting_screens_test.dart:857-920` stops before saving).

**UX-2703 · Severity 3 · Stopped card: three look-alike choices, unclear «Terminar»**
- Where: `App/lib/widgets/meeting_banners.dart:254-285` (three `TextButton`s, `_action` at `:226`); `App/lib/l10n/app_es.arb:1440-1442`. Renders `meetings/notes-lines.stopped-and-waiting.es.light.1x.png` and `after-stop.microphone-failed.es.light.1x.png`.
- The moment, after the phone died mid-meeting: "Which recording is this? Do I want «Terminar»… does that end it, delete it? I just want my notes."
- What happens:
  - «Continuar», «Terminar» and «Descartar» are identical teal text buttons with no primary. They stack even at ES 1×.
  - The question repeats the three button labels instead of saying what each does.
  - Nothing says which meeting it is (no day or start time). With two stopped meetings, the cards differ only by «1:42:00».
  - «Terminar» doesn't name its result (notes), and in the capture sheet «Terminar» means "Done, close" (`captureFinish`).
  - After a microphone failure the screen says "stopped" twice: the banner, then «Tu grabación se detuvo…».
- Why it fails:
  - SC-4 One primary action.
  - Plain language: buttons name the result (ISO 24495-1). SC-9 Same word, same thing.
  - CO-2 Few options per decision; Hick–Hyman (unfamiliar options are read one by one).
  - SC-1 Front-load the line.
- Fix (`startedAt` is already on `Meeting`):
  - Card line: ES «Grabación de hoy, 10:15 · 1 h 42 min. Se cortó antes de que pulsaras Parar.» / EN "Recording from today, 10:15 · 1 h 42 min. It stopped before you pressed Stop." / CA «Enregistrament d'avui, 10:15 · 1 h 42 min. S'ha tallat abans que premessis Atura.»
  - Buttons: filled «Hacer las notas» / "Make the notes" / «Fes les notes» first; then «Seguir grabando» / "Keep recording" / «Continua enregistrant»; then «Descartar» in the error colour, set apart.
  - Drop the question sentence.
  - On the meeting screen after a microphone failure, keep only the banner's cause and use the same card without its "it stopped" sentence.
- Verify: renders of notes-lines stopped-and-waiting (ES 1×/2×, CA 2×) and after-stop microphone-failed. TalkBack names keep the time.
- Evidence: verified in code, seen in current renders.

**UX-2704 · Severity 3 · Dictation can reach for the mic during a meeting recording**
- Where:
  - `App/lib/screens/notes_screen.dart:303-317`: «Añadir nota» keeps its mic while `recording` is true. Render `meetings/notes-lines.recording.es.light.1x.png` shows «Grabando una reunión · 12:03» above a mic «Añadir nota».
  - Calendar's and Tareas' «Añadir tarea», the widget and the shortcuts go through `showCaptureSheet` (`App/lib/screens/voice_task_screen.dart:77`). Nothing outside the meeting files reads `meetingsProvider` except `notes_screen.dart:159`, `main.dart` and `account_screen.dart`.
- The moment, mid-meeting: "Let me quickly dictate a reminder" → taps «Añadir nota» or «Añadir tarea».
- What happens: the capture sheet starts listening (its own recorder, or the phone's recognizer) while the meeting recorder holds the microphone. Depending on Android's concurrent-capture rules, either the dictation hears silence or the meeting's audio stream ends. The second case reaches "El micrófono dejó de funcionar" and loses the rest of the meeting.
- Why it fails:
  - VO-13 Detect a silent microphone ("another app records — say so plainly and offer typing").
  - I Interruptions: nothing the user said is lost.
  - The app acts against the user without saying so (recurring problem 11).
- Fix: while a meeting records, every capture entry opens for typing (as on a free account with no dictations left), with one line: ES «Se está grabando una reunión: escribe aquí.» / EN "A meeting is recording: type here." / CA «S'està enregistrant una reunió: escriu aquí.» Never start a second capture of the microphone.
- Verify: a widget test where, with `meetingsProvider.recording != null`, «Añadir nota» and Calendar's «Añadir tarea» open typing and the recorder isn't touched. Phone check: record a meeting, then try a dictation from the widget.
- Evidence: verified in code. The outcome on Android is inferred and needs a device check (phone list).

**UX-2705 · Severity 2 · Durations shown as clock times**
- Where:
  - `meetingElapsed` in `App/lib/l10n/meeting_copy.dart:41-48`, used in the prose of `meetingStoppedAt` (`app_es.arb:1440`), `meetingRecordingNow` (`:1443`) and the TalkBack names (`:1473-1475`).
  - `meetingClock` in the note's chapters (`App/lib/services/meeting_note.dart:66-69`, `:103`).
- The moment: "«Se detuvo en 1:42:00» — at 1:42 at night?" In Catalan it literally says so: «es va aturar **a** 1:42:00» (render `notes-lines.stopped-and-waiting.ca.light.2x.png`). Chapters read «0:00–0:30 Presentaciones», «0:30–0:52 Precio del piloto»: after midnight? «Grabando una reunión · 12:03» reads as noon.
- Why it fails: match with the real world (Nielsen 1994); LO-3 Dates and times through locale formats. A length isn't a time of day.
- Fix:
  - Keep the stopwatch only on the recording screen's big counter.
  - In prose and TalkBack, write lengths in words: ES «1 h 42 min», «12 min» / EN "1 h 42 min", "12 min" / CA «1 h 42 min», «12 min».
  - Chapters: ES «Minutos 0–30 · Presentaciones y alcance», «Minutos 30–52 · Precio del piloto», «1 h 30 min – 2 h · …» / EN "Minutes 0–30 · …" / CA «Minuts 0–30 · …».
- Verify: unit tests for the length formatter in three languages; renders of notes-lines and note create-task at ES/CA 2×.
- Evidence: verified in code, seen in current renders.

**UX-2706 · Severity 2 · Leaving Crear tarea asks about "the text" and can park it**
- Where: `App/lib/widgets/note_task.dart:36-66` (a capture session is written before the review opens); `App/lib/screens/voice_task_screen.dart:4402-4425` and `:377-389` (`_leave` → `captureKeepTextQuestion`).
- The moment: the person opens «Crear tarea», changes their mind and taps «Cancelar». The question «¿Conservar el texto para más tarde?» appears, with red «Descartar» and filled «Conservar». "What text? Will Descartar delete my meeting notes?" They pick «Conservar» to be safe.
- What happens: a "kept" capture of the note's title and to-dos goes to «Sin guardar» and shows up later as pending captures. Nothing was at risk: the note still holds everything.
- Why it fails:
  - Copy borrowed from another context (recurring problem 9).
  - PL-5 Dialogs only for decisions worth an interruption; UN-3.
  - The newcomer fears breaking something (OL-2), and «Descartar» next to a meeting reads as deleting it.
- Fix: for a review opened by «Crear tarea», Cancel, Back and swipe close it at once with no question, and the draft capture is deleted. If the app is killed, the draft never surfaces in «Sin guardar». The capture store can mark these sessions, for example `source: 'note'`.
- Verify: update `App/test/meeting_screens_test.dart:906-919`: Back closes with no dialog, the session is gone, and the pending captures count is unchanged.
- Evidence: verified in code (the existing test asserts the dialog).

**UX-2707 · Severity 2 · «Grabar una reunión» tops the Notes tab, above its teaching**
- Where: `App/lib/screens/notes_screen.dart:189-206` (above search, the project filter, the list and the empty state). Renders `notes/notes-tab.empty.es.light.2x.png` and `notes/notes-tab.list.es.light.1x.png`.
- The moment, newcomer opening Notas for the first time: the first thing they read is «Grabar una reunión», then «Un lugar para tus ideas». A free account taps it and lands on a paywall.
- Why it fails:
  - Product rule "Show advanced things only when relevant"; CO-7 Progressive disclosure; ON-4 Empty states teach the next step.
  - SC-5: what the user came for (their notes) moves down.
  - The code's own intent ("Second to Añadir nota, and quieter") isn't met.
  - At 2× the icon stays 18 dp beside 28 dp text (render).
- Fix:
  - Move the row to the end of the list content: after the last note, and after the empty state's line when there are none. It then sits just above «Añadir nota», which is the related action.
  - Let the icon scale with the text, capped as the other list icons are.
  - Whether free accounts see it at all is a question for the owner (below).
- Verify: notes-tab empty and list renders at ES 1×/2×, where «Un lugar para tus ideas» or the first note comes first.
- Evidence: verified in code, seen in current renders.

**UX-2708 · Severity 2 · Meeting note: to-dos last, sections not headings**
- Where: `App/lib/services/meeting_note.dart:78-131` (one plain body: summary, «Decisiones», «Preguntas abiertas», «Partes de la reunión» and every chapter, then the to-dos as steps). Renders `meetings/note.create-task.es.light.1x.png` and `.2x.png`. AUDIT: TalkBack reads the whole body as one «Tu nota» button value, with «PASOS · 0/3» off screen.
- The moment: "What do I have to do after this meeting?" They have to scroll past every chapter of a long meeting to reach the to-dos. «Decisiones» looks like a sentence, not a heading.
- Why it fails:
  - SC-1 and SC-5: the action items are the reason for the note.
  - Gestalt grouping: headings in the body style are invisible.
  - AC-6: TalkBack can't move by heading through one giant node.
- Fix:
  - In the meeting note, put the to-dos (steps) right after the summary and before «Decisiones». The app builds this note, so it can order it.
  - Render the section labels as headings (bold, with semantics headers). Keep the chapters last.
  - If the note body can't carry headings, put the summary and to-dos first and leave the chapters at the end.
- Verify: render note create-task at ES 1×: the first step is visible without scrolling. AUDIT shows the headings as `heading`.
- Evidence: verified in code, seen in current renders.

**UX-2709 · Severity 2 · «Crear tarea» is secondary to «Editar nota»**
- Where: `App/lib/screens/task_detail_screen.dart:563-580`. AUDIT note·create-task: «Editar nota» filled 142 × 60 dp, «Crear tarea» outlined 144 × 56 dp, side by side at different heights.
- The moment: "One tap to a task" (the owner's words). The filled button says «Editar nota», and editing is rare.
- Why it fails: SC-4 One primary action, set apart by label, position and isolation; the von Restorff effect. Two same-row buttons of different heights (F).
- Fix: on a note that offers «Crear tarea», make «Crear tarea» the filled button and «Editar nota» outlined. Both at the same height. Other notes keep the filled «Editar nota».
- Verify: render note create-task ES 1×/2×, CA 2×.
- Evidence: seen in current render, AUDIT measured.

**UX-2710 · Severity 2 · Relative "when" with no meeting date anywhere**
- Where: `App/lib/services/meeting_note.dart:73-76` («Enviar el presupuesto · Miki · el viernes»); the note's body and page show no date for the meeting (render note create-task). The text goes on into the task's checklist (`note_task.dart:50-53`; render note.review).
- The moment, a week later: "«el viernes»… which Friday?" The task shows «Sin fecha» beside a step that says Friday.
- Why it fails: copy written for one moment, read later (recurring problem 21); VO-5 Show the interpretation, date first.
- Fix:
  - App: open the note's body with the meeting's own line, in the meeting's language, built from `startedAt` and its length: ES «Reunión del mar, 3 nov, 10:15 · 52 min» / EN "Meeting on Tue, 3 Nov, 10:15 · 52 min" / CA «Reunió del dt., 3 de nov., 10:15 · 52 min».
  - Cause partly server-side: ask the final step to give "when" as an absolute day ("viernes 6 nov") relative to the meeting's date.
- Verify: a unit test for `meetingNote` with the date line in three languages; render note create-task.
- Evidence: verified in code; the server's output is inferred.

**UX-2711 · Severity 2 · Pro lapsed or month used up is learned only after Stop**
- Where: `App/lib/services/meeting_controller.dart:224-237` (`_canRecord` checks space, permission and busy, but not Pro or the allowance). The recording screen (`App/lib/screens/meeting_screen.dart:455-531`) shows no upload problem while it records. `allowanceUsed` and `proRequired` are set by the uploader as pieces are refused (`meeting_uploader.dart:296`, `:338`).
- The moment: they record a two-hour client meeting, press Parar and read «Has usado el tiempo de reuniones de este mes. Tu grabación espera en el teléfono hasta el mes que viene.»
- Why it fails: SU-7 Explain a limit when it bites; visibility of system status (Nielsen 1994).
- Fix:
  - While recording, once a piece comes back refused, show the same line on the recording screen under the time, in the warning style of `meetingSpaceLowWarning`. Recording goes on.
  - When the app already knows the allowance is used at start (from an earlier refusal this month), say so on the screen before recording: ES «Has usado el tiempo de reuniones de este mes: puedes grabar, y las notas llegarán el mes que viene.» / EN "You've used this month's meeting time: you can record, and the notes come next month." / CA «Has fet servir el temps de reunions d'aquest mes: pots enregistrar, i les notes arribaran el mes que ve.»
- Verify: a widget test with scripted 402 refusals during recording; a render of recording with allowance used.
- Evidence: verified in code.

**UX-2712 · Severity 2 · Refused or failed start: no retry, no re-check**
- Where: `App/lib/screens/meeting_screen.dart:533-561` (`_Refused`: one message, «Abrir Ajustes» for permission, nothing else). Renders `recording.microphone-refused.es.light.1x.png` and `recording.start-failed.es.light.2x.png`.
- The moment:
  - After «No permitir» once, they're told to go to Ajustes › Permisos, although Android would still ask again.
  - Back from Ajustes with the mic allowed, the screen still says it's refused.
  - «No se pudo empezar a grabar. Inténtalo de nuevo.» offers no button to try again, only «Cerrar».
- Why it fails: ON-7 A denial is not a dead end (Settings only after the system stops asking); UN-7 Errors say what to do, and the "what" should be one tap; A No dead ends.
- Fix:
  - Permission refused but still askable: filled ES «Permitir el micrófono» / EN "Allow the microphone" / CA «Permet el micròfon», which asks again. Settings only when blocked, as the capture sheet does (`mic-denied` vs `mic-blocked`).
  - Re-check when the app resumes and start on its own once allowed.
  - Start failed: filled ES «Reintentar» / EN "Try again" / CA «Torna-ho a provar».
- Verify: widget tests for denied → allow, blocked → resume → starts, and failed → retry; renders.
- Evidence: verified in code, seen in current renders; the system dialog is a device check.

**UX-2713 · Severity 2 · A failed Stop says "couldn't start recording"**
- Where: `App/lib/screens/meeting_screen.dart:253-258` (`showFeedback(messenger, l.meetingStartFailed)`).
- The moment: they press «Parar» and read «No se pudo empezar a grabar» while it is still recording. "Did it even record? Is it recording now?"
- Why it fails: UN-7 Errors say what happened; copy borrowed from another context (recurring problem 9).
- Fix: a string of its own: ES «No se pudo parar. Sigue grabando: vuelve a pulsar Parar.» / EN "Couldn't stop. It's still recording: press Stop again." / CA «No s'ha pogut aturar. Continua enregistrant: torna a prémer Atura.»
- Verify: a widget test where a throwing `stop()` shows the new string and the recording screen stays.
- Evidence: verified in code.

**UX-2714 · Severity 2 · Descartar: only action on a healthy card; inconsistent look**
- Where: `App/lib/widgets/meeting_banners.dart:287-325` («Preparando tus notas…» and «Esperando conexión» cards have «Descartar» as their only button, in teal). `App/lib/screens/meeting_screen.dart:403-409`, `:678-690` and `meeting_banners.dart:41-46` (red «Descartar» elsewhere). `meeting_screen.dart:650` (allowance used has no Descartar on the screen, but does in Notes). Renders `notes-lines.stopped-and-waiting.es.light.1x.png`, `notes-lines.held-back.es.light.1x.png` and `after-stop.pro-required.es.light.1x.png` («Ver Pro» 60 dp and «Descartar» 48 dp, top-aligned, 8 dp apart).
- The moment: "There's a box with one button, «Descartar»; I'll tap it to get rid of the box." The dialog saves them, but the healthy card's only action is the one that destroys.
- Why it fails: RE-6 Keep destructive actions apart; SC-9 Same thing, same look; CO-9 Subtract.
- Fix:
  - Remove «Descartar» from the «Preparando tus notas…» card. It lasts seconds, and the meeting screen and sign-out still offer it.
  - On every surface, «Descartar» uses the error colour.
  - The meeting screen's allowance-used state gets the same «Descartar» as its Notes card.
  - In `_AfterActions`, align the two buttons on their centre line.
- Verify: renders of notes-lines and after-stop pro-required and allowance-used.
- Evidence: verified in code, seen in current renders.

**UX-2715 · Severity 2 · «Grabar una reunión» can wait 5 s silently**
- Where: `App/lib/screens/meeting_screen.dart:34-47` (waits for `billingLoadingProvider` up to 5 s before pushing anything); `App/lib/screens/notes_screen.dart:202-204` (no guard against a second tap).
- The moment, just after opening the app or with poor signal: they tap and nothing happens, tap again, and get two recording screens (or two Pro screens) stacked.
- Why it fails: UN-1 and PE-1 Answer every tap within 0.1 s; PE-2.
- Fix: push the meeting screen at once and resolve Pro on it, with its existing «starting» spinner. Send a free account on to the Pro screen from there with `pushReplacement`. Ignore taps while one is opening.
- Verify: a widget test with billing loading, where a tap shows the screen in the first frame and two taps open one screen.
- Evidence: verified in code.

**UX-2716 · Severity 2 · Recording screen doesn't say leaving keeps recording**
- Where: `App/lib/screens/meeting_screen.dart:522-527` (`meetingListeningHelp`: «Puedes bloquear el teléfono: sigue grabando.»). The ← in the app bar leaves the recording on, with no word about it.
- The moment: "I'm done, I'll go back" → taps ←, thinking it ends the recording. It records on, possibly for hours. The only signs are a Notes card and the ongoing notification.
- Why it fails: visibility of system status; PR-6 The microphone is on only while listening, which here means only while the person knows it is.
- Fix: the help line names both: ES «Puedes salir o bloquear el teléfono: sigue grabando hasta que pulses Parar.» / EN "You can leave or lock the phone: it keeps recording until you press Stop." / CA «Pots sortir o bloquejar el telèfon: continua enregistrant fins que premis Atura.»
- Verify: recording renders ES/CA 2×, where the line fits above «Parar» without scrolling.
- Evidence: verified in code, seen in current renders.

**UX-2717 · Severity 2 · An "all silence" recording is deleted at Stop without asking**
- Where: `App/lib/screens/meeting_screen.dart:261-266` and `:305-316` (snackbar «No se oyó nada…», screen closes, nothing kept); rules at `App/lib/services/meeting_recorder.dart:63-64` (−42 dBFS, 3 loud samples per piece).
- The moment: a quiet meeting with the phone far down the table. They press «Parar» and read «No se oyó nada, así que no hay nada que guardar.» The meeting is gone.
- Why it fails: MN-26 says "a real meeting is never thrown away silently"; UN-9 Never lose input. The decision rests on a level threshold that has never met a real room.
- Fix: for a recording longer than about a minute that's judged silent, ask on the screen instead of deleting: ES «Casi no se oyó nada. ¿Hacer notas igualmente?» with «Hacer las notas» and «Descartar» / EN "Almost nothing was heard. Make notes anyway?" / CA «Gairebé no s'ha sentit res. Vols fer notes igualment?». Keep the silent drop for short ones.
- Verify: a widget test where a 10-minute recording with only quiet levels asks. Phone check: record a quiet conversation at 2–3 m.
- Evidence: verified in code; the real-room outcome is inferred and needs a device check.

**UX-2718 · Severity 1 · TalkBack: clock-like time, unnamed «Abrir»**
- Where:
  - `App/lib/screens/meeting_screen.dart:505-512`: the elapsed time is read as «12:03».
  - `App/lib/widgets/meeting_banners.dart:243-246`: «Abrir» has no named label, unlike the other line buttons.
- The moment: TalkBack says "doce cero tres" or "12:03 p. m."; on Notes, "Abrir, botón". Open what?
- Why it fails: AC-6 Every control has a name, role and value.
- Fix:
  - Semantics label for the elapsed time: ES «12 minutos y 3 segundos grabados» / EN "12 minutes 3 seconds recorded" / CA «12 minuts i 3 segons enregistrats».
  - «Abrir» named ES «Abrir la grabación» / EN "Open the recording" / CA «Obre l'enregistrament».
- Verify: AUDIT's TalkBack list for recording · listening and notes-lines · recording.
- Evidence: AUDIT measured; verified in code.

### Keep (5 bullets at most)
- **The recording screen.** One 84 dp «Parar» low and central, a level ring that respects «Quitar animaciones», the time large, and dark mode holding contrast (render `recording.listening.es.dark.1x.png`).
- **Discard asks with named outcomes.** «Descartar» vs «Seguir grabando», with the safe one filled. It stays as a confirmation because discarding can't be undone (UN-3, UN-4).
- **The note takes the meeting screen's place.** `pushReplacement`, so Back returns to Notes. A good ending once UX-2702 lands too.
- **Waiting is explained, never an error.** «Esperando conexión» plus "safe on this phone, we'll let you know" (MN-11). Live regions only on change.
- **TalkBack names on the lines' buttons carry the recording's length,** so several cards' «Descartar» can be told apart.

### Progress against UX_REVIEW.md (U1–U14)
- `../UX_REVIEW.md` isn't in this checkout, so I can't judge.
- Relevant patterns: the Notes tab moves away from U10 (controls that only matter later shown from day one) through UX-2707. «Crear tarea» keeps the single-primary rule only once UX-2709 lands.

### Questions for the owner (product decisions only)
1. **Should free accounts see «Grabar una reunión»?** Today it shows to everyone and a free account's tap lands on the Pro screen (SU-6 nagging, SU-8). Options:
   - (a) show it to Pro only;
   - (b) show it to everyone, as now;
   - (c) show it to free accounts only after they've used dictation.

   Recommended: (a) while meeting notes are Pro-only; the Pro screen can still list it.
2. **The monthly meeting time (about 20 hours) is never shown before it runs out.** Should the Pro screen or the recording screen say there's a monthly amount? SU-7 says to explain a limit when it bites; UX-2711 covers the moment it bites.
3. **Consent reminder (still open):** with no reminder, the flow also never says that the audio is sent for notes and then deleted (PR-5 Say plainly whether audio is kept). One line on the recording screen could do both. Owner's call.
4. **«Crear tarea» on every note with open steps** (already open from the owner context). The croquetas recipe note now shows it (render `notes/note.with-steps.es.light.1x.png`), which turns a shopping list into a task titled «Receta de la abuela: croquetas de jamón».

### Cross-slice notes
- D: the Pro screen render `meetings/pro.reason.es.light.1x.png` shows only the store-error state. Its example «un resumen, las decisiones y las tareas» promises "tasks" where the notes give to-dos that become one task's steps; ES «las cosas por hacer» would be truer.
- D: after buying Pro from «Grabar una reunión», the person comes back to Notes and must tap again. Consider going straight on to the recording screen.
- A: the review sheet `Texto original` contrast flag in AUDIT is a histogram artefact (text measures 5.26:1); not filed.

### Phone checks owed (no device this run)
- Mic conflict: start a meeting, then dictate from the widget and from «Añadir nota» (UX-2704).
- A quiet real room at 2–3 m: is it judged silent? (UX-2717)
- The system microphone dialog, a first denial and a second denial, and returning from Ajustes (UX-2712).

### Memory notes
- New area to map: **Meeting notes.**
  - Entry: «Grabar una reunión» in Notes, `notes_screen.dart:189`. MeetingScreen stages: starting / recording / refused / after.
  - Notes-tab lines (`MeetingBanners`): recording · stopped (MN-12) · waiting (`problem`: offline, proRequired, allowanceUsed, pieceFailed, expired).
  - The note is built by `meetingNote()` in `services/meeting_note.dart`: plain body plus to-dos as steps.
  - «Crear tarea» = `createTaskFromNote` → a capture session (`source: 'typed'`, `status: 'ready'`) → `showCaptureSheet(captureId, useScope: false)`, so it inherits the capture sheet's leave question and landing rules.
  - `noteMakesTask` = any note with an open step.
- Recurring type to add, **reused review editor semantics:** the checklist editor's checkbox means "done", but in a "choose what to bring over" flow it reads as "select" (UX-2701). Check any flow that reuses the capture review for a different purpose: leave question, landing, checkbox meaning.
- Recurring type to add, **durations formatted as clock times** («1:42:00», «0:30–0:52», «12:03» in prose). Catalan «a 1:42:00» makes the clock reading explicit (UX-2705).
- Recurring type 9 again: `meetingStartFailed` reused for a failed Stop (UX-2713); the capture's `captureKeepTextQuestion` reused for Crear tarea (UX-2706).
- Mic ownership: nothing in the capture entries knows a meeting is recording (UX-2704). Any future recorder needs a single "who holds the mic" check.
- `../UX_REVIEW.md` is absent in the cloud checkout (2026-11-03).
