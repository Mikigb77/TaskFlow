## UX review — C: a meeting's note and «Crear tareas» — 2026-11-05
**Verdict:** Ship after fixes — the split into one task per goal works and the day is read against the meeting, but after saving, the note doesn't show what became of its lines (and lines left out can never be made), and the review hides the steps this change exists to get right.

**Scope and evidence.** The last commit `a820e97` (`git show HEAD`): `App/lib/screens/task_detail_screen.dart`, `App/lib/widgets/note_task.dart`, `App/lib/services/meeting_note.dart`, `App/lib/screens/voice_task_screen.dart` (save from a note), `App/lib/widgets/capture_review_editor.dart` (unchanged, its collapsed card judged), ARB keys `meetingCreateTask`, `meetingViewTask`, `meetingNoteSteps`, `meetingNoteTaskCount` in EN/ES/CA. Renders: `App/build/ux/meetings/note.{create-task,review}.{es 1×, es 2×, ca 2×, en 2×}` and `note.after-task.es.light.1x`, rendered 2026-11-05 17:10 from `a820e97`; `find App/lib App/assets -newer <png>` lists nothing, so they are current. AUDIT.md read for all three states. Evidence level: widget-test renders plus code; no emulator or phone this run. Not rendered, judged from code: a review card opened (its «Pasos que se añaden»), the moment after saving (the message, «Ver tareas» landing on Calendar), Deshacer, a one-line note, dark mode, 1.3×, `after-task` at 2× or in CA/EN. Note: INDEX.md says the review render shows the quote's "two steps ticked under «Pasos que se añaden»"; the PNG shows three collapsed cards and no step anywhere (see UX-3103). `../UX_REVIEW.md` does not exist; `guidelines.md` was read.

**Walked:** (1) open a meeting's note → «Crear tareas» → review → «Añadir 3 tareas» → note in view with «Ver tareas» → Calendar; (2) the same, removing one card; (3) Deshacer after (1); (4) a line reworded with Editar nota, then «Crear tareas»; (5) tasks made a week after the meeting; (6) TalkBack on the note. Personas: newcomer (ES, 2×), daily user, TalkBack user.

**Numbers:**
- Taps from the note to three tasks on the calendar: 2 («Crear tareas», «Añadir 3 tareas»), the same as one task with steps before. Good.
- Note page: 9 tap targets; the review: 12 (AUDIT).
- Checking which steps go with which task in the review: 1 tap per card, and each opened card closes the last one (`_expandedId`). With 3 cards: 3 taps, never all in view. Today the collapsed cards show 0 steps out of 2.
- A day the words name but the app can't read («el viernes a las 5», «el 12 de noviembre»): 2–3 more taps per card (date line → day → OK).
- After saving, what changes on the note: 1 thing (the button's label); the lines and «Tareas · 0/3» stay the same.

### Findings (most severe first)

**UX-3101 · Severity 3 · Made tasks leave the note's lines unchanged**
- Where: `App/lib/screens/task_detail_screen.dart:743-790` (`_steps`: every line stays a checkbox), `:596-620`; `App/lib/widgets/note_task.dart:65`, `:126` (links are kept per note, not per line); render `note.after-task.es.light.1x.png`.
- The moment: "Le he dado a añadir… ¿se han creado? Sigue poniendo Tareas 0/3 con todo sin marcar." Two days later: "Ya mandé el presupuesto" → ticks the line in the meeting's note → the task on Calendar is still open and its reminder still rings.
- What happens: after «Añadir 3 tareas» the sheet closes onto the note. The only change is the button label («Crear tareas» → «Ver tareas»), plus a message at the screen's edge, «3 tareas añadidas», that doesn't say where they went (two have no day). Every line is still an open checkbox under «Tareas · 0/3». From then on, the same task has two independent checkboxes: ticking the note's line does nothing to the task, and completing the task doesn't tick the line.
- Why it fails: SC-10 and UN-2 (Rensink 1997; Flaherty 2024): the result has to show where the person is looking, and a snackbar isn't the proof. SC-11, the ending (Kahneman 1993). SC-9 / Norman 2013: one thing with two controls that disagree breaks the person's model of the app, and on the daily path it leaves a reminder for something already done.
- Fix: remember which line made which task: line id → task id, in the existing `NoteTaskLinks` (old links without a line id keep today's note-level list). On the note, a line whose task still exists is no longer a checkbox:
  - it shows the task's state (`Icons.task_alt_rounded` when the task is done, the calendar icon otherwise), the line's words, and, under them, the task's day as Calendar puts it (`taskDayLine`: «vie, 6 nov», «Sin fecha»);
  - a tap opens that task's page over the note (Back returns), as «Ver tarea» does;
  - TalkBack reads it as a button: «Enviar el presupuesto · Miki · el viernes, vie, 6 nov».

  «Tareas · n/N» counts done tasks, plus the lines ticked on the note itself. Lines that made no task stay checkboxes. No new strings.
- Verify: the `after-task` preview shows lines 1–2 with their days and line 3 still a checkbox. A widget test where completing task 121 makes the heading read «Tareas · 1/3». After a save from the `review` state, the lines change in the same frame the sheet closes.
- Evidence: seen in a current render (`after-task`); the rest verified in code.

**UX-3102 · Severity 2 · Lines left out can never become tasks**
- Where: `App/lib/screens/task_detail_screen.dart:596-620` (`made.isNotEmpty` is checked before `makesTask`); render `note.after-task.es.light.1x.png` (two of three made, so «Ver tareas» only).
- The moment: "Quité lo de Ana porque no era mío… ahora sí lo necesito. ¿Cómo lo creo?" A task deleted later can't be made again either.
- What happens: as soon as one task exists, the main button is «Ver tarea(s)» for good. The open lines that made nothing have no way to become a task: a dead end, in a flow that has no other way in.
- Why it fails: A (no dead ends); Nielsen 1994, user control and freedom.
- Fix (with UX-3101): the main button counts the open lines that made no task (or whose task was deleted since). From 1 up, it says «Crear tarea» / «Crear tareas» (`meetingCreateTask(count)`) and opens the review with only those lines. When none are left, it says «Ver tarea» / «Ver tareas» as now. The made tasks stay one tap away on their own lines (UX-3101).
- Verify: `after-task` shows «Crear tarea» (1) for «Pedir el contacto de compras · Ana»; tapping it opens a review with one card, and the other two are untouched.
- Evidence: seen in a current render; verified in code.

**UX-3103 · Severity 2 · Collapsed review cards hide each task's steps**
- Where: `App/lib/widgets/capture_review_editor.dart:949-972` (the collapsed card: title, date line, questions, nothing about steps); renders `note.review.*` (no step on any card, in any language or size).
- Does it matter here: yes. This change exists so that the banner and the backlog go under «terminar el front end» and «llamar al cliente» stands alone. The review is the only moment before saving to check that split. With every card collapsed, a task with five steps looks exactly like a task with none. To check, the person opens the cards one at a time (each one closes the last), and the steps are "ticked to go in" without the person ever seeing them. The note's «Pasos de cada tarea» is under the sheet, at the end of «Tu nota». Before this change, the single card was open and its steps were in view.
- The moment: "¿Y lo del banner y el backlog? No lo veo en ninguna."
- Why it fails: VO-5 (Budiu 2018ia): show what was understood. VO-7: details that belong to one task attach visibly to it. CO-8: recognition over recall (Nielsen 1994).
- Fix: on a collapsed card whose task has ticked steps, add one quiet line under the date line, styled like the collapsed reminder line: `Icons.checklist_rounded` and the count of ticked steps (what goes in). It is part of the card's TalkBack node, and a tap opens the card. A card with none shows nothing. New key `reviewStepCount`:
  - es «{count, plural, =1{1 paso} other{{count} pasos}}»
  - en «{count, plural, =1{1 step} other{{count} steps}}»
  - ca «{count, plural, =1{1 pas} other{{count} passos}}»

  Use it on every collapsed card, not only those from a note (SC-9).
- Verify: the `review` render shows «2 pasos» under «Mañana» on the first card only, at es 2× and ca 2× without clipping. Correct the INDEX prose of `note.review` (`App/test/ux_previews/meeting_previews.dart`), which claims the steps are shown.
- Evidence: seen in current renders; verified in code.

**UX-3104 · Severity 2 · Common «when» words give «Sin fecha»**
- Where: `App/lib/widgets/note_task.dart:258-266` (`dated` requires `ambiguousHour == null`); `App/lib/services/quick_schedule_parser.dart` (`_dayOfMonth` rejects a day followed by «de {mes}», and `_date` has no month names). The server writes `when` "exactly as said" (`Backend/core/meetings.py:287-289`).
- The moment: "Dijimos el viernes a las 5. ¿Por qué pone Sin fecha?" The card's title still ends «· el viernes a las 5» next to «Sin fecha».
- What happens: these phrases, normal in meetings, set no day:
  - «el viernes a las 5»: Friday is certain, but the whole day is dropped because 5 could be morning or afternoon;
  - «el 12 de noviembre» and «antes del 15 de diciembre»: the parser refuses a day with a month.

  Only bare weekdays, «mañana» and similar, and «el 12» are read. Each such card then needs 2–3 taps to set by hand.
- Why it fails: VO-5 and VO-6 (Suhm 2001): the day is the part that must come through, and a fix costs taps. TA-11: near-term days are the common case.
- Fix (app): parse with `keepAmbiguousHour: true`, which the task form already uses. «el viernes a las 5» then sets Friday with no time and keeps «a las 5» in the title. On this path, also read «{día} de {mes}» (es/ca, «12 de novembre») and «{month} {d}» / «{d} {month}» (en) as the next such date on or after the meeting's day. Or (cause partly server-side, the open server half of UX-2710): the final notes also return the task's day as `YYYY-MM-DD`, resolved against the meeting's day, which the parser already reads, while `when` keeps the words. Either removes the hand-set day.
- Verify: unit tests of `noteLineTask` with day 2026-11-03 for «el viernes a las 5» (6 Nov, no time, «a las 5» kept), «el 12 de noviembre» (12 Nov), «antes del 15 de diciembre» (deadline 15 Dec), «el 12 de novembre» (ca).
- Evidence: verified in code; inferred for real meetings, needs one on a phone.

**UX-3105 · Severity 2 · A day already past is set silently**
- Where: `App/lib/widgets/note_task.dart:260-262` (read against the meeting's day, never against today); the review's date line `App/lib/widgets/capture_review_editor.dart:383` → `dayLabel` (`App/lib/l10n/region.dart:34`) shows «vie, 6 nov» with nothing that says it has passed.
- The moment: the notes came on Tuesday 3 Nov, and the person makes the tasks on Wednesday 11 Nov. «el viernes» becomes Fri 6 Nov, the task is saved already overdue, its reminder never rings, and Calendar opens on last week.
- Why it fails: VO-5 (Baymard 2015f): "this Friday" is exactly the date people misread. TA-6: a reminder fires on time, or the app says why not.
- Fix: a day read from the words that falls before today isn't set. The card says «Sin fecha» and keeps the words in its title, as for words not understood, so the person picks the day. This adds no copy (subtract). If the owner would rather keep them overdue: the date line reads «vie, 6 nov · ya pasó» (en «Fri, 6 Nov · already passed», ca «dv., 6 de nov. · ja ha passat»).
- Verify: unit test of `noteLineTask` with meeting day 3 Nov and the clock on 11 Nov: no `dueDate`, title keeps «· el viernes».
- Evidence: verified in code.

**UX-3106 · Severity 2 · Rewording a line silently drops its steps and day**
- Where: `App/lib/widgets/note_task.dart:258` (`asSaved` needs the line's words to match the server's exactly); renaming a step keeps its id (`App/lib/widgets/checklist_editor.dart`).
- The moment: misheard words aren't corrected on screen, so the person fixes «Mikel» to «Miki» in the line with Editar nota. Later, «Crear tareas»: that task arrives with no steps and no day. Collapsed, the card looks the same as before (UX-3103), so nothing tells them.
- What happens: any change to a line's words, even one letter, drops the steps the server gave it and the day read from «when». The steps survive only in the note's text.
- Why it fails: UN-9: never lose input. VO-7: details that belong to a task stay with it.
- Fix: the steps go with the line by its id, whatever its words. They arrive ticked, as now, so they can be unticked. The day is read from the line's current words against the meeting's day (parse `line.title`, which carries the «when»), so an edited day is honoured and a deleted one gives none. The title is the line's words minus a day read whole, as now. (Steps changed in «Tu nota»'s text aren't what goes in. With UX-3103's count, the review is where that is seen; no further change asked.)
- Verify: unit test where a line renamed from «Enviar el presupuesto · Mikel · el viernes» to «… · Miki · el viernes» still gives 2 ticked steps and 6 Nov.
- Evidence: verified in code.

**UX-3107 · Severity 2 · TalkBack calls the meeting's tasks «pasos»**
- Where: `App/lib/screens/task_detail_screen.dart:764` (`checklistSemantics`); AUDIT `meetings/note · create-task`, items 5–6: heading «TAREAS · 0/3», then «Lista de pasos, 0 de 3 completados».
- The moment (TalkBack): "¿Son tareas o pasos? Y luego en la nota pone «Pasos de cada tarea»…"
- Why it fails: SC-9 / ISO 24495-1: one concept, one name. The meeting's note now uses both words for different things.
- Fix: on a meeting's note (the same test that picks `meetingNoteTaskCount`), the progress bar's label is a new key `meetingNoteTaskSemantics`:
  - es «Tareas: {done} de {total} hechas»
  - en «Tasks: {done} of {total} done»
  - ca «Tasques: {done} de {total} fetes»
- Verify: AUDIT for `create-task` reads «Tareas: 0 de 3 hechas»; other notes and tasks keep «Lista de pasos…».
- Evidence: measured in AUDIT (widget test).

**UX-3108 · Severity 1 · Deshacer of several tasks gives no sign**
- Where: `App/lib/screens/voice_task_screen.dart:3620-3640` (the `_fromNote` branch of Deshacer: no message).
- What happens: after one task, Deshacer closes the task page that opened over the note, which is visible. After several, the note was already in view: the message goes and only the button label flips back to «Crear tareas» (and, after UX-3101, the lines go back to checkboxes).
- Why it fails: B: after acting, the person sees that it worked (Norman 2013, gulf of evaluation).
- Fix: in that branch, when more than one task was taken back, show `commandTasksDeleted(count)`, which exists in all three languages: «3 tareas eliminadas», «3 tasks deleted», «3 tasques suprimides». It is a plain message with no action.
- Verify: widget test: save 3 from the note, Deshacer, the message shows and the note offers «Crear tareas».
- Evidence: verified in code.

### Keep (5 bullets at most)
- One card per task, with the day read against the meeting's day: «el viernes» from Tuesday 3 Nov correctly becomes Friday 6 Nov («Mañana» on the run day), and «Añadir 3 tareas» names the count (VO-7, VO-8).
- Two taps from the note to all the meeting's tasks; leaving the review asks nothing and parks nothing (UX-2706 holds).
- «Crear tareas» / «Crear tarea» follows the open lines' count, with whole ICU plurals in EN/ES/CA; CA imperatives («Crea les tasques», «Mostra les tasques») stay consistent with UX-122.
- Who and when stay on the note's line, and a day read whole leaves the card's title («Enviar el presupuesto · Miki» + «Mañana»).
- Deshacer stays on the save message, and a removed card has its own Deshacer.

### Progress against UX_REVIEW.md (U1–U14)
`../UX_REVIEW.md` is not present in this checkout, so I couldn't check it. Against the ledger: UX-2710 advanced. The app now reads a relative «when» against the meeting's day, which the note's first line states. The server half, an absolute date, stays open, and would also fix most of UX-3104. UX-2701, UX-2702, UX-2706 and UX-2709 hold for several tasks (UX-2702: with one task its page opens; with several, see UX-3101).

### Questions for the owner (product decisions only)
1. **Tasks said for someone else.** «Pedir el contacto de compras · Ana» becomes a task on the recorder's calendar, titled with «· Ana». On Calendar, «· Ana» reads either way: Ana asks, or ask Ana. Options:
   - (a) keep as built; ✕ in the review takes it out;
   - (b) keep, but put the name first, in words: «Ana: pedir el contacto de compras»;
   - (c) cards for tasks that name someone else start removed, with Deshacer.

   Recommended: (b). It's the smallest change, and it front-loads who (SC-1). It concerns whose calendar a meeting's tasks land on, so it's the owner's call.

### Memory notes
- A meeting's note (2026-11-05): one checklist line per task, with heading «Tareas · n/N» only where the phone-local meeting mark exists. Each task's server data (title, who, when, steps) is kept phone-local in `app_preferences` scope `meetingTasks:<owner>` by line id (`MeetingNoteMarks.tasks`). Steps and day reach the review only while the line's words are unchanged (`noteLineTask`, `asSaved`).
- `NoteTaskLinks` now holds a list of task ids per note (old links: one int). «Ver tarea» with one task pushes its page over the note; «Ver tareas» with several pops to Calendar with them lit (`showNoteTasks`). Any made task hides «Crear tareas».
- The review's collapsed card (`capture_review_editor.dart` collapsed branch) shows title, date line, reminder line and questions only: steps, priority and repeat are invisible until opened. Watch for it whenever multi-card reviews carry details.
- The meeting path's day parsing is `QuickScheduleParser` (typed-text grammar): no month names, and an ambiguous bare hour drops the day unless `keepAmbiguousHour`.
- Recurring problem type: a confirmation that rests only on a snackbar plus a button label change (SC-10/UN-2), here and in UX-2702 before it.
- The preview INDEX prose can claim things the PNG doesn't show (the `note.review` steps). Check each claim against the image.
