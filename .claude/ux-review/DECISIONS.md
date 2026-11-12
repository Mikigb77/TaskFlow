# Owner decisions

Every agent in the UX loop reads this before reviewing or planning. Only the owner makes these decisions. Agents never add to this file; the main session records what the owner says in chat. Newest first.

## 2026-11-12 — The app icon takes the website's Lagoon mark

- The owner: "we have made a lot of changes in the web, colors and stuff, so maybe we can adapt the app icon and the icon actually to the new style."
- Built as: the launcher icon keeps the white double tick and puts it on the website mark's gradient, teal `#0A7A63` through aqua `#1FB5A6` to mint `#3EF0B0`, top left to bottom right, instead of the flat `#146C5C`. The Android 7 bitmaps are the same tile; the themed (monochrome) icon is unchanged. The website's favicon and link preview mark use the same gradient. This updates D8's colour; D8's shape stands.

## 2026-11-12 — The staging app looks for updates whenever it opens

- The owner: "We have to make the app check for updates more often, or at least once when you open the app, because otherwise it's not picking up the update on its own."
- Built as: TaskFlow Staging asks for the newest build when it opens, each time it comes back to the front (at most once a minute), and every 15 minutes while it stays open, instead of at most once an hour. A check that fails, say with no network yet as the app opens, is tried again at the next chance, and a build that was found but couldn't download is still offered. A build put off with Later is offered again the next time the app comes back to the front.

## 2026-11-11 — Phone calendars by account, and tasks added to the calendar

- The owner: "simply sync everything but based on the calendar account … if I have calendars for a couple of or three Gmail accounts, I just should have to check or uncheck one or two or the three of them … by default, we shouldn't sync holidays … put a little extra button for extra options … the naming … should not be account dash holidays … holidays from ta-ta-ta account." And: "a task that you create within the app, it's also added on your calendar."
- Built as: «Phone calendars» lists one tick per account (its address, or «On this phone»), which shows all of that account's own calendars. Connecting ticks every account; holidays, birthdays, week numbers and calendars the account can only read start off and sit behind «More options», each named as people read it («Holidays», «From ana@gmail.com»), never by its id. This replaces D7's "every calendar shows by default" for those extras. A choice saved per calendar keeps its accounts.
- The owner, next: "it should be like a global setting … I can choose which calendars get synced with the tasks", "we should not micromanage every task", and "don't show both at the same time … put it behind your calendars in the app … and the other one something like from the app to your calendar … when you click on those, you can select the accounts."
- Built as: «Phone calendars» shows two rows. «Your calendar in TaskFlow» opens the account ticks above (and «More options»). «TaskFlow in your calendar» opens the same accounts, none ticked; ticking one asks the phone for write access and then adds every task with a day to that account's main calendar. Changing or deleting the task changes or removes its event; a repeating task gets an event for each day of the next 30. Unticking an account removes the events from today on. Calendar doesn't show those events twice. There is no per-task choice. Android and iOS.

## 2026-11-10 — The listening sheet follows light and dark mode

- The owner, seeing the app's light-mode screenshots on the website: "within the app we should also make the recording part also match whether it's in dark mode or not."
- Built as: the capture sheet keeps its lime-to-mint orb, lit from below, in both modes. In dark mode it stays Lagoon night; in light mode it is the light sheet with a soft mint glow under the orb, teal `Terminar` and teal level ring and live dot. This replaces the 2026-11-09 line "the capture sheet is night … while it listens" for light mode.

## 2026-11-10 — A plan and reminders some minutes before, together

- The owner, on a 3-month project with a rhythm of reminders: "we want to be able to make … both of them at the same time … give the user the illusion that he can say whatever and we are gonna comply with it." Plans stay counted in whole days, one notice a day, with no rhythm of hours ("for the plan, I agree that we shouldn't allow a custom time").
- Built as: on a timed task, the leads said or chosen (`reminder_minutes` and `reminder_extra_minutes`) ring beside the plan on the task's day; the plan's own notice for the day (D1) isn't set twice, and Settings' default lead adds nothing. The plan's line ends with them («… · 1 hora antes, 10 minutos antes»). `Backend/docs/REMINDER_PLANS.md`.

## 2026-11-10 — Several reminders said for one task each ring

- The owner: "schedule a meeting for 10 … remind me 20 minutes before it, and then 5 minutes right before it starts … should translate into me getting two different push notifications", said from the start, in the one capture.
- Built as: a task keeps its single reminder plus `reminder_extra_minutes`, more leads before a timed task (up to 6 in all), each its own notification. Dictation reads every lead said (`Backend/docs/REMINDER_PLANS.md`). Nothing new on the default path: the reminder row reads «20 minutos antes, 5 minutos antes», and its sheet shows that as the chosen row; any other row is one reminder again.

## 2026-11-10 — Every "add" looks the same

- The owner: «Añadir nota» "has a different look and feel than the button to add tasks. Wouldn't it be better if all the buttons had the same look and feel?"
- Built as: one style, `AppTheme.mainTap` (night on mint, Bricolage, inside `LivelyButton`'s breathing halo), used by `Añadir tarea` and `Añadir nota`. «Reunión» beside it stays outlined, 12 dp away so the halo doesn't touch it.

## 2026-11-10 — A rounder tab bar

- The owner asked whether the bottom tab bar could be "a little bit more round", without competing with `Añadir tarea` above it. Shown three renders (today's flat bar, rounded top corners, a floating pill), they picked rounded top corners.
- Built as: the bar stays full width at the bottom; its top corners round at 28 px, like the capture sheet, and a soft shadow replaces the 1 px line (UX-433). The page's drifting colour shows round the corners. Not a floating pill: two pills stacked would compete with `Añadir tarea`, which stays the one pill on the page.

## 2026-11-09 — The Lagoon look, shared with the website

- The owner picked the website's Nova design in its green "Lagoon" palette, and asked: "Make sure to also re-design the app accordingly."
- Built as: the `Lagoon` palette in `App/lib/theme/app_theme.dart` (night `#032229`, mint `#3EF0B0` with night text for the main taps, teal `#0A7A63` on the light page, aqua `#DAF4EF` tint, lime `#D9FF6B` spark), Bricolage Grotesque for titles and Manrope for everything read. `Añadir tarea` is a mint pill with a glow; the chosen day is a night pill (mint in dark mode); phone events are aqua cards with a teal edge; the capture sheet is night with a lime-to-mint orb while it listens, and turns light for the result; the `2 tareas añadidas · Deshacer` message is a night toast.
- Reviewers: judge new screens against this look, not the earlier greens. The site's record: `../TaskFlowWeb/.claude/ux-web/DECISIONS.md`, 2026-11-09.

## 2026-11-08 — Attachment allowances, and completed tasks' files go after 15 days

- The owner: "Every user: attachment files on a task are deleted 15 days after the task is completed […] but we will still keep the count on how many megabytes you have used." Free accounts: 200 MB per account, for life: "once across all your history, you have expended those 200 megabytes, then you can no longer attach files." Paying users: 500 MB per month.
- Built as: `AttachmentUsage`, bytes uploaded per UTC month, never lowered (removing a file gives nothing back); 200 MiB in all without Pro, 500 MiB this month with Pro; uploads made with Pro count towards the free 200 too. A move between projects charges nobody. The daily `maintain_staging` job deletes the files (the task stays); a file added after completion gets 15 days from when it was added.
- In the app: a completed task's backed-up files say «Estos archivos se eliminarán el …»; a refused file says the free 200 MB are used (with «Ver Pro») or this month's 500 MB (with «Reintentar» and the date more come). «Tareas con archivos» and «Ver tareas con archivos» are gone: removing files no longer makes room. The Pro benefit reads «Dictados sin límite y 500 MB de archivos al mes».

## 2026-11-06 — Reopen a task by voice

- The owner: a task marked done by mistake («complete all the tasks for today», then «the doctor one isn't done, uncheck it») must be reopenable by voice. The app's tick already reopens by touch, so no new button: only the voice command.
- Built as a new command kind, `reopen` (`Backend/docs/VOICE_COMMANDS.md`): one task or a set («desmarca todas las de hoy»), with the same card, «Marcar como pendiente», and Deshacer, as `complete`.

## 2026-11-06 — Meeting recording: more visible, speakers, minutes, suggested tasks, two plans
The owner: "we need to make more important the part of meeting recording … but most of the time the user would want to have simple note recording". He then said "let's do that" to the plan in the doc «Better meeting recordings: options for discussion» (https://claude.ai/artifact/DSsSR3FvvgRL1D5FyqRR1k), so its recommendations are his decisions:
- **Entry point:** on Notes, a smaller outlined «Reunión» button beside the filled «Añadir nota» replaces the quiet «Grabar una reunión» line under the notes. «Añadir nota» stays the main action. Notes only, not Calendar or Tareas. A third launcher shortcut, «Grabar una reunión», joins «Dictar» and «Escribir». Later: offering to record when the phone's calendar has an event happening now.
- **Speakers:** each 5-minute piece is transcribed with speaker labels and word timings (Gemini 3.5 Transcribe), and the server matches voices across pieces with its own voiceprints, so «Persona 1» stays the same person all meeting and a new voice becomes a new speaker. Voiceprints live only as long as the meeting and are deleted with it; voices are never remembered across meetings. A speaker can be renamed in the note; the notes may suggest a name heard in the meeting. The privacy page must say so before it ships, with the owner's sign-off. Built only after a trial on three real recordings (Spanish, English, Catalan; one over an hour) shows it works; this also settles MN-32.
- **Minutes:** a meeting's note gains a timeline by topic, with times and who spoke («0:00–1:10 Persona 1 plantea la idea principal»). Long meetings keep their half-hour chapters. No choice to make before recording. The speaker-labelled transcript is kept in the note on the phone, folded behind «Ver la transcripción completa»; the server still deletes it.
- **Suggested tasks:** when a meeting's notes are ready, «Tareas sugeridas» lists the drafted tasks with a box each, «Añadir todas» and «Añadir (n)». Tasks said as a to-do start ticked; maybes and tasks for someone else start unticked. The note is saved first, so skipping the list loses nothing; what wasn't added stays on the note, as in PR #23.
- **Later the same morning the owner narrowed it:** "even with what we have right now, it's enough for the first version … if you don't sell it, there is no point in making it." So the first version is the entry point and «Tareas sugeridas» only. Speakers, the timeline and the transcript (above) are parked until there's a signal people would pay for them: how many Pro users record meetings and how long, and the five-person test. No speaker trial now. If a second plan comes, it is sold by the person and the job ("the minutes write themselves, with who said what"), never by transcript quality, so Pro's notes never read as the lesser version.
- **Plans and prices (direction, not final):** Pro at US$7.99 a month keeps meeting notes as they are (summary, decisions, tasks) with the 20 hours a month. A second plan, «Pro Reuniones» (about US$14.99), adds speakers, the timeline and the transcript, sold as a meeting recorder in your pocket, never as "better transcripts". It waits for the speaker trial and a product in RevenueCat. Prices stay unpublished until the owner fixes them.

## 2026-11-05 — Dictation sends the recording online by default
The owner: "The recording for the phone most of the time is bad, so we should start by defaulting to sending the record to the backend. I think it's more expensive, but it's way better … way less prone to error."
- Voz's «Cómo se pasa la voz a texto» defaults to «En línea, al terminar», also where the phone's own recognizer works. «En el teléfono, mientras hablas» stays, as the person's choice.
- Phones that saved the old default move too: only a choice made after this change keeps on-device speech (`speechOnDevice` in the regional preferences).
- The privacy policy's voice paragraph says so; its wording waits on the owner's sign-off (TaskFlowWeb, `docs/LEGAL_RELEASE.md`).

## 2026-11-03 — Meeting notes from a recording (built 2026-11-04; device checks owed)
The owner asked for notes from a recorded conversation, then a task with a checklist in one tap. Requirements: `App/docs/MEETING_NOTES.md`.
- Record on the phone and send pieces of about 5 minutes while recording; no live streaming. "As cheap as we can while maintaining some quality", in any common language.
- All AI on Vertex AI: "I wouldn't turn credits on AI Studio. I would rather use simply the Vertex AI, since we're already paying for it anyway."
- Nothing unnecessary is kept: once the final notes exist, the pieces' text and chapter notes are deleted.
- Abandoned recordings ("zombies") are cleaned up, but a few weeks without signal must not lose a real meeting.
- 2026-11-04: dictations on staging move to Vertex only too (`AI_ROUTE=vertex`), off the free AI Studio tier; the owner chose it on a decision card.
- 2026-11-04, the owner: "let's go with all the recommendations that you have" (run 2026-11-03-screens, D1–D7; the 7- and 30-day limits stay):
  - D1 (UX-2722): «Crear tarea» only on notes made from a meeting, by a phone-local mark; a recipe note with a checklist doesn't offer it.
  - D2 (UX-2719): meeting notes stay Pro only; free accounts still see «Grabar una reunión», which opens the Pro screen.
  - D3 (UX-2813): the first time a meeting records with notifications off, one sentence and «Continuar», then Android's dialog; asked once per phone, never after a refusal.
  - D4 (UX-2720): the Pro screen states "up to 20 hours a month" (`meetingHoursPerMonth`, the server's 240 pieces). The owner asked what that costs: about US$0.08 a meeting hour on Flash-Lite, so at most about US$1.60 a user a month at the cap.
  - D5 (UX-2721): one quiet line on the recording screen, «El audio se envía para hacer las notas y después se borra.»; no consent reminder. The website's privacy page must say the same (MN-34).
  - D6 (UX-2814): the "notes ready" notification is private on the lock screen (Android hides its text where the phone hides private content); the title shows once unlocked.
  - D7 (UX-2815): the owner adds «Notas de las reuniones que grabas» to the RevenueCat paywall in its dashboard.
- 2026-11-05, after a Catalan meeting came back as one note whose three steps were really three tasks: "we need to allow for more than one task creation at a time … the banner and the backlog are steps towards the first task, but if the conversation then moves on to … call the client … That's another task." So a meeting gives one task per goal, each with its own steps; something with its own goal is its own task, even said right after another or on the same day. The note has one line per task (heading «Tareas · n/N»), each task's steps in its text, and «Crear tareas» opens the review with one card per open line, its steps ticked and its day read from the words said, against the meeting's day. One task made opens over the note as before; several leave the note in view, which then offers «Ver tareas» (Calendar, with them lit).
- 2026-11-05, the owner chose "Fix them while writing the notes" on a decision card: the chapter and final notes are told the transcript comes from speech recognition and write the word meant where the context makes a misheard one clear («paga general» where «vaga general» was meant), never changing a name, figure, date or time on a guess. No separate correction pass (it would cost about 30% more a meeting); the transcript itself isn't corrected or shown.
- 2026-11-06, the owner chose "Name first" on a decision card (UX-3109): a meeting task said for someone named shows the name first, «Ana: Pedir el contacto de compras · el viernes», in the note's line and the task's title, so it can't read as asking Ana. The task still lands on the recorder's calendar. When the server's «who» is the speaker («yo», «jo», «I», «me», «we»…), no name is shown.
- 2026-11-05, the owner chose "Keep as built" on a decision card (UX-3004, run 2026-11-04-screens): the notes-ready notification stays `private` and keeps the meeting's title. It shows on the lock screen unless the phone hides sensitive content; no title-free lock-screen version, and not secret.

## 2026-11-01 — The UX loop as fast as the machine allows
After the 2026-10-28-app plan took about 19 hours, the owner: "it cannot be that we are running for 19 hours … We should deploy all the agents that can be possibly deployed at the same time, if needed." What the main session put in place for it, reported to the owner (`.claude/skills/ux/references/speed-2026-11-01.md`):
- Every package of a fix run flows through on its own, as many at once as the machine allows, and is checked and fixed in its own worktree before it's merged. No waves, and no batches.
- A finding still short after its package's one fix has failed twice: it goes to the owner, as before. What fails across packages gets one more round, not two.
- The whole suite runs once per run, after every package is in.
- On a machine where a workflow gets few agents (a 4-CPU cloud session gets 2), the plan runs in lanes, several workflows at once.

## 2026-10-31 (later) — D1 and D2 of run 2026-10-28-app
The owner: "D1 and D2 both yes, as recommended".
- **D1 (UX-2612), «Guardar como tarea»:** (a). The phone's own reading shows as a normal result card with «Añadir al calendario» before it's saved, after the 8 s wait, after a failure and on «No se encontraron tareas». One more tap on a rare path; the person sees the day it read, and that it's one task.
- **D2 (UX-2311), Completadas newest first:** (a). Each completion's time is kept, per task and per repeat, on the phone and on the server, and Completadas lists by it, newest first; older completions without a time keep today's order after them. Nothing shows the time; only the order uses it. Server first, then one small app package.

## 2026-10-31 — "do everything": D9, WD34, the stopped whole-app review
The owner answered the list of what waited on him with "do everything", then: "after everything finishes, make a pr and merge it onto main". Each item below is the recommendation he was given.
- **D9 of run 2026-10-22-changes (UX-2032), a reader's own reminders:** (b). A «lector» can choose their own reminders on the tasks that ring for them. The server accepts a reader's change that touches only their own reminders, with no version, activity or notification, as for anyone; nothing else a reader sends changes. Server first, then one small app package.
- **WD34 of the website run 2026-10-28-site (WEB-1317):** yes, through /ux. When the day's last task is ticked in Calendar, the app shows the demo's line: "All clear. Take a breath." (ES «Todo listo. Respira.», CA «Tot fet. Respira.», the site's own words).
- **The whole-app review 2026-10-28-app** is rerun, and its plan is carried through `ux fix` without a stop for approval, since he asked for everything to be done. Its product questions still go to him.

## 2026-10-23 — D8 of run 2026-10-22-changes, and the single reminder on shared tasks
- **D8 (UX-2022), a time said for the day itself:** (b), as recommended: "yeah, absolutely, it should be kept". A plan with a time of its own, said or typed («recuérdamelo el mismo día a las 9», «cada día a las 8»), keeps that time on the task's own day too. Only plans without a time of their own (the strengths, «Sí» to the offer, a rhythm said without an hour) move the day's notice to the task's usual reminder, as D1 says.
- **«Una vez» on shared tasks is personal, like plans:** "one person change affects everyone's phone. That shouldn't happen. So it should become personal, like plans. Absolutely." Every reminder choice for a task (none, once and its lead or time, a plan) is each person's own: it rings only for them, and changing it changes nobody else's. Someone who hasn't chosen gets their own defaults from Settings. This closes the Open item of 2026-10-22.

## 2026-10-22 (evening) — D1–D7 of run 2026-10-22-changes: reminder plans
The owner answered the run's seven questions. The contract, `Backend/docs/REMINDER_PLANS.md`, says how each works.
- **D1 (UX-2001), a plan on a timed task:** "let's go with your recommendation". On the anchor's own day, a timed task (or a deadline with a time) rings at its usual reminder: its own lead, else «Tareas con hora» (10 minutes by default), with the single reminder's words («Hoy a las 17:00 · en 10 min»), not at 9:00. Earlier days keep the plan's time, and the count doesn't change.
- **D2 (UX-1912), how far back a plan starts:** the strengths (Suave, Normal and Intenso, and «Sí» to the offer) start at most 4 weeks before the day: Normal gives at most 15 notices, Suave 8 and Intenso 22. A rhythm the person says or types is kept as said, however far back it reaches: "let's say that you have a super big project that you will not finish in four weeks. So in this case, I think it's okay to, if you specifically say it, get [reminders] every … time that you specify … if you don't have [one], sure, I would go with your recommendation."
- **D3 (UX-1812), a reminder said for a task with no day:** "let's go with your recommendation". The server flags a reminder it heard for a task with no day and no deadline, and the card says «Para recordártelo, ponle un día.» under the date; tapping it opens the date. Once the task has a day, the reminder said applies.
- **D4 (UX-1911), «Hasta la fecha límite» on tasks with only a day:** the name stays. A task without a deadline treats its own day, and its time, as the deadline: "if there is no specified deadline, then that means … the time of this task is the deadline itself … 90% of the customers are going to just state the task, click on save, and never set a deadline." So «recuérdamelo hasta la fecha límite», said for a task that only has a day, means until that day. The separate deadline field stays: "I wouldn't use it, but we have it … we can leave it since we have it."
- **D5 (UX-2013), the offer after «Ahora no»:** "go with your suggestion". After two «Ahora no» in a row on this phone, the offer stops; «Hasta la fecha límite» stays in every task's reminder sheet.
- **D6 (UX-2014), plans on shared tasks are personal.** A plan rings only for the person who set it, and every member can set their own on the same task: "the rest of the people that are in that group should not receive a ring on their phone, but they should be able to also set reminders for that task … everyone should be able to set their own pattern for reminder frequency." His example: a math group's «Terminar la presentación» for next Thursday, where one member asks for a reminder every day. On a task given to someone else there are no plan rows, as recommended. The single reminder («Una vez») is unchanged: still one setting for the whole task (see Open).
- **D7 (UX-2015), RevenueCat's paywall:** the owner adds «A tu manera» to the paywall's Pro benefits in the RevenueCat dashboard himself: "Absolutely". Agents don't touch external services.

## 2026-10-22 — Reminder plans: nudges that come more often as a task's day approaches
**What he asked for:** "present the company project in 3 weeks from now, and I would like reminders every 3 days for the first 2 weeks, and later on the last week, I want a reminder every day", without making a manual task "too much", and never as copies of the task. The contract: `Backend/docs/REMINDER_PLANS.md`.
- **One task, one plan:** reminders are notifications about the one task, never tasks of their own.
- **The anchor:** the plan counts back from the deadline when there is one, otherwise from the task's own day. "Most of the time the user is not going to bother setting a deadline … the deadline … will be the same as the task."
- **For everyone, no AI:** «Hasta la fecha límite» with three strengths, Suave, Normal and Intenso ("Suave, Normal, Intenso (Recommended)"), and the same preview: the plan in words, dots to the day, the next reminder.
- **Said while dictating:** a rhythm said in a dictation is honored for free users too, since it's the same AI call ("Honor it for free users too").
- **Pro:** «A tu manera» in the reminder sheet, typed or said, read by the AI: "we will not use llm calls for the non paying users … reserve the «a tu manera» for pro users". Free users see it with a Pro badge that opens the Pro screen.
- **The offer:** after saving a task whose day is far away, the reminder question offers the plan ("Yes, in the reminder question").
- **After the day:** one last notice, then silence ("One last notice, then stop").
- **Order:** "All of it, then the UX review".

## 2026-10-22 — D4 of run 2026-10-21-changes (UX-1721)
**«Retrasa todo lo de hoy un día», and the overdue tasks a «hoy» set takes (D2):** "From today: to tomorrow", as recommended. Moved by days, the overdue tasks in a «hoy» set count from today, like the rest, so «un día» puts them all on tomorrow. They're listed with «Atrasada» before the tap, and Deshacer undoes it. Other sets, one task and moves to a day are unchanged. P232 builds it in the same round; the main session updates the contract.

## 2026-10-21 (evening) — Bulk commands: D1–D3 of run 2026-10-21-changes
The owner answered the run's three questions, each as recommended:
- **D1 (UX-1715), a task with only a deadline, moved to a day by voice:** "Move the deadline".
  - A voice move to a day, for a set («pasa todo lo de ayer a mañana») or for one task, moves the deadline of a task that has only a deadline, as a move by days already does.
  - A time said for such a task goes on its deadline too (UX-1709's fifth item).
  - Voice only: Calendar's own «Cambiar fecha» keeps its rule.
- **D2 (UX-1702), «hoy»:** "Yes, include overdue". A set for exactly today also takes the open tasks Today lists under «Atrasadas», listed first with «Atrasada» and ticked, so any can be unticked.
- **D3 (UX-1716), fixing a misheard day by touch:** "Yes, on both cards". The day in a move's heading becomes a chip («mañana, jue 22 ▾») that opens the existing «Elegir día» sheet, on the set card and on one task's change card. The count stays live.
- They are carried out in a round of their own (`/ux plan 2026-10-21-changes`, then a fix round), not by P224–P228, which were already running. The main session updates the contract (`Backend/docs/VOICE_COMMANDS.md`) for D1 and D2.

## 2026-10-21 (later) — Bulk voice commands
**The owner is back**, and the normal flow applies again: new product questions go to him.

**What he asked for:** "get all my tasks from yesterday and put them on tomorrow… in addition to searching the tasks, you can sort of rearrange them". He answered two questions.
- **Which bulk actions (all four):**
  - move, to a day («pasa todo lo de ayer a mañana») or by a stretch of time («pasa lo de esta semana a la semana que viene»);
  - the other changes a single task already takes, applied to all of them: time, priority, person, deadline;
  - mark done;
  - delete, always confirmed first and undoable.
- **Which tasks «all my tasks» means (recommended):**
  - the person's own pending tasks, and the tasks assigned to them in shared projects;
  - completed tasks stay where they are, unless the person says «completadas»;
  - other people's tasks only when the person names the project or the person;
  - repeating tasks aren't moved or deleted, and the card says how many were left out. Marking done completes that day's occurrence.
- **How it works:** one card names the action and the count («Mover 5 tareas a mañana»), lists the tasks, and lets you untick any. One tap applies it, then «Deshacer» undoes all of it.
- **The contract:** `Backend/docs/VOICE_COMMANDS.md`, section «Bulk commands».

## 2026-10-21 — The owner is away again: "do not ask me anything for now"
Until he checks in:
- Any product question gets decided by the main session, using the plan's recommendation.
- Each decision is recorded in this file, under this entry, with its recommendation. All of them stay reversible.
- The normal flow returns when he's back.
- Agents keep writing new questions into their plans as D# with a recommendation. No package waits for an answer.

Decided while he's away:
- **English launcher shortcuts and widget wording (UX-1656, UX-1657; batch b7, P221-P223):**
  - At Android's 2.0 the launcher cut «Say a task» to «Say a ta…», found on the emulator lane. So the English long labels became «Dictate a new task» and «Type a new task». They're long enough that the launcher falls back to the one-word «Dictate» and «Type» at large text, as it already does in Spanish and Catalan.
  - The reviewer then asked for one name per action, so the English widget and its help now say «Dictate a task» instead of «Say a task».
  - Spanish and Catalan are unchanged.
  - Recommendation and decision: as built. Reversible with a strings change, if «Say a task» matters more than one name.
- **D12 (UX-1403), Tareas at large text:** closed by its own measure-first rule, not by a choice. On the emulator at Android's 2.0, Tareas shows its title on one line and a whole task (`runs/2026-10-19-app/device-b3.md`). A shared project's filter rows stay with U13's evidence.

## 2026-10-20 (later) — D11 of run 2026-10-19-app: no cue
**The owner:** "no cue for D11, as recommended".
- **D11 (UX-1309), a second new task far down the same day:** no cue for a lit row below the fold, and no new element or copy. The save message already counts every saved task, and a lit row stays lit until it's scrolled into view. UX-1309 stands as P169 and P197 built it.

## 2026-10-20 — The owner approves the whole-app plan 2026-10-19-app, with D1–D10 as recommended
**The owner:** "go, as recommended". He is back, so the normal flow applies again: new product questions go to him.

The plan's packages P166–P189 run as planned. The answers below, from that run's `plan.md`, become fixes:
- **D1 (UX-1601), the reminder question:**
  - ask it only after a save whose reminder can still fire, with no new copy;
  - a date-only task for today saved after 9:00 gets no reminder, and its chip stops promising «9:00»;
  - one default, no new rule (TA-5).
- **D2 (UX-1603), sign-in's first screen:** the email fields fold behind «Continuar con mi correo», under «Continuar con Google». That's 5 tap targets instead of 10, and one decision instead of two.
- **D3 (UX-1623), shared text:** the day and time in shared text are read, as D2 of 2026-10-18 does for dictated words. Otherwise the form opens with no day, as before.
- **D4 (UX-1624), empty dictations:** a dictation with no task and no command doesn't use a free dictation. This is a server change, made by the main session.
- **D5 (UX-1515), changing your name:** one row in Cuenta, «Nombre · María» or «Añadir tu nombre», opening the existing name sheet.
- **D6 (UX-1513), group invitations:** no role step. Everyone joins as editor, and the role, Administrador included, changes on the person's row (SH-5).
- **D7 (UX-1611), phone calendars:** every calendar shows by default after connecting, with «Conectado. Los eventos se ven en Calendario.» (CO-6).
- **D8 (UX-1608), the launcher icon:** redrawn from the in-app mark (the teal square with the double tick) as an adaptive icon, with a monochrome layer for Android 13's themed icons.
- **D9 (UX-421), the Catalan «Configuració» tab label:** the stopgap for narrow phones is extended to any width where the label doesn't fit, until U13.
- **D10 (UX-1625), the lock screen:** reminder titles stay visible on it; Android's own setting can hide them.

## 2026-10-18 (night) — The owner is away: the main session decides, records and moves on
**The owner, before leaving:** "whatever question you have for me, whatever decisions, even if it concerns the product, just for now, record what decision you made, what was your recommendation, and you move forward with your recommendation… you are on your own… prioritize completing everything to the best degree possible." Earlier the same evening: "if you have to do something, don't ask me for permission, just go ahead and do it."

How the loop runs until he's back:
- Organizers still keep decisions apart from fixes. The main session answers each decision here, using the recommendation unless it says otherwise, and the loop then builds it like any fix.
- Whole-app and whole-site runs don't stop for approval.
- Everything decided below is reversible. He reviews it all afterwards; the summary is `.claude/AWAY-2026-10-18.md`.
- These rules don't change: no push, no deploy, never `main`, never his phone or his own emulators (the separate `TaskFlow_Review` test emulator is the main session's), never `Backend/.env`.

**Run 2026-10-18-commands, D1–D11 (details in its `plan.md`):**
- **D1 — Cancelar on a result with nothing to add:** it just closes ("don't do it"). Results with a task to add keep asking whether to keep or discard.
- **D2 — date words carried into the form:** dictated words carried into the form by «Escribir» have their day and time read, as «Guardar como tarea» does. Titles typed into the form are left as typed.
- **D3 — rename «Guardar tal cual»:** «Guardar como tarea» / "Save as a task" / «Desa-ho com a tasca».
- **D4 — a search with a period** («¿qué tengo esta semana?»): listed by day and time, soonest first. Other searches stay newest first.
- **D5 — the button at 0 dictations:** stays «Nueva tarea».
- **D6 — Back on a new task:** shows the add message («Añadida al lun, 19 oct» or «Añadida sin fecha», with Deshacer), not «Cambios guardados».
- **D7 — a task added under a person's chip:** it's that person's by default, shown on the form and the card, and one tap changes it.
- **D8 — real names:**
  - the Google half is done on the server (41c00f3);
  - password accounts are asked for a first name once, when they first share a project or join one. The field is prefilled from the email and can be skipped. There's no field at sign-up;
  - the server gets a way to set the name (`PATCH /api/auth/me/` with `first_name`).
- **D9 — «Reenviar código» when nothing was sent:**
  - past the limit, the server answers 429 with Retry-After;
  - the app says «Has pedido muchos códigos. Espera {n} minutos para pedir otro.» and keeps Reenviar off.

  The server goes first.
- **D10 — «Abrir el correo»:** not now.
- **D11 — does the commands flag slow every dictation?** No. The flag stays on for every dictation.
  - Measured locally on 2026-10-18, because staging would need a deploy: the real free model (`gemma-4-26b-a4b-it` on AI Studio), 12 one-task Spanish dictations each way, alternated, with no failures. This is the server's extraction time only, without transcription or the phone's network.
  - With commands: median 3.5 s, p95 3.8 s. Without: median 4.3 s, p95 4.6 s.
  - All 24 gave one task and no false commands.

- **D12 (UX-1227, from b3's round 2):** in «Elegir día», after a year pick Flutter keeps the same day of the new year highlighted, though nothing was applied. Accepted as Flutter's own behaviour; no custom month display.
  - Why: nothing is lost, the form's chip shows the real day, and a custom calendar adds code and risk.
  - Revisit if the phone check (report-b3.md, check 4) shows people pausing on it.

**Other open items, decided:**
- **Cleaning up completed tasks** (the owner floated 1 month on free, 3 months on Pro): **none for now**, so nothing is ever deleted on its own.
  - Why: it deletes people's history irreversibly, voice search now finds completed tasks (decided earlier today), the privacy page he approved promises the opposite, and a free plan shouldn't lose data.
  - Nothing is built, so it's easy to revisit. If it's ever wanted, the app must say so before it happens.
- **UX-815:** an account with Google linked can confirm the deletion with Google on the delete page.
- **UX-813:** later, with the confirmation email he deferred.
- **UX-814 and UX-812:** not now.
- **Deleting the RevenueCat customer:** yes, best effort after the deletion commits, when the server has the RevenueCat secret key. A failure is logged and never blocks the deletion.
- **Free dictations after deleting and re-creating an account:** accepted for now. No hash of the email is kept, which keeps the privacy page simple.
- **UX-615 (a result that saves itself):** no. The confirming tap stays until the test with his father.
- **UX-616 (the assistant's wait on the server):** on staging and production, `AI_ROUTE=auto` with `AI_FREE_ATTEMPT_SECONDS=10`, so a slow free call falls back to the paid model sooner.
  - Settings only; it applies at the next deploy, which stays his call.
  - Local Docker has no Vertex configuration, so nothing changes locally.
- **Finding the tasks that hold files:** yes, the smallest version. When storage is full, the message and the Account storage row link to «Ver tareas con archivos», a list of tasks with files, largest first.
  - Why: today the message asks people to remove files from other tasks, with no way to find them, which is a dead end.
- **U13 (two tabs), and UX-331, UX-421 and U10 which follow from it:** still waiting for his test with his father; only he can run it.
- **The package name `com.example.agenda`:** the new ID will be `tech.garbar.taskflow`, from garbar.tech. The code doesn't change yet, because Google sign-in, RevenueCat and Play must register it first. `App/docs/PACKAGE_ID.md` lists the steps.
- **From the website review** (WD7 and WD11 in `.claude/ux-web/runs/2026-10-18-site/plan.md`):
  - the app no longer says it's available on iOS (`app_en.arb` "available in the Android and iOS app");
  - the app links to the website's Privacy and Terms, at sign-up and in Ajustes, in the app's language.

## 2026-10-18 (later) — A form for free accounts, and voice commands for projects and tasks
- **The owner approved all seven recommendations** in `.claude/ux-review/voice-commands-plan.md`:
  1. «Proyecto» in the app, with «grupo», «proyecto» and «lista» understood in dictations;
  2. a project named in a dictation is created only on the confirming tap;
  3. no inviting by voice;
  4. everyone in a project sees all of its tasks, plus a filter by person;
  5. changing and deleting by voice always show the before and after, need a tap, and offer «Deshacer»;
  6. search includes completed tasks, and tasks show «Creada por»;
  7. free typing creates tasks only.
- **The owner:** "I want everything fully tested, fully implemented, all the things on the list… and make sure that we are passing the UX review."
- **Free accounts don't create tasks from free text. They get a form** (this replaces the 2026-10-18 «Escribir tarea» typing).
  - The owner: "they are gonna just fill in the… form, like… title, notes, side notes, attachments, hour, day". Turning free text or speech into tasks is the paid capability.
  - The 10 free dictations a month stay; the owner offered "give them 10 tries" earlier the same day.
  - With dictations left, «Añadir tarea» opens the capture sheet as today. The sheet's keyboard option opens the form for free accounts, instead of free typing.
  - At 0 left, the button opens the form directly. The once-a-month pop-up explains it.
  - The phone's parser no longer turns a free account's typed text into tasks. It stays only as the fallback for a dictation («Guardar tal cual»).
  - The form is the existing task form in create mode:
    - title first, then day and time;
    - notes, files, repeat, project and the rest under «Más detalles»;
    - simple enough for the owner's father.
  - Pro is unchanged: dictation, and typed words read by the assistant.

## 2026-10-18 — Manual tasks for free accounts, open sign-up on staging, and email verification
The owner asked for these before going away, saying "don't ask me any questions". The main session filled in the details; each is reversible.
- **Free accounts get a clear manual way to create tasks once their 10 dictations run out.** The owner: "keep the button, give them 10 tries, and then change it to a button to manually create the tasks… maybe a pop-up". He likes the current layout.
  - While dictations are left, nothing changes.
  - At 0 left, the Añadir tarea button becomes «Escribir tarea» with a pencil icon. It opens the capture sheet in typing mode: the phone's own parser, no AI, no limit.
  - A pop-up explains it once per month, the first time a free account is out of dictations. It names the reset date and offers «Escribir una tarea» and «Ver Pro».
  - Context: free typing already never uses the AI (2026-10-13). The owner most likely saw typed words go to the AI on a Pro or complimentary account, where that is intended.
- **Staging lets anyone create an account.**
  - The invited-testers-only gate (`Backend/core/staging.py`) is off by default.
  - It can come back with `STAGING_INVITE_ONLY`.
  - Nothing was deployed: deploying is still the owner's call.
- **New accounts must confirm their email.**
  - A password sign-up gets a 6-digit code by email, from `taskflow.noreply@garbar.tech`. It's valid for 30 minutes.
  - The person can't sign in until they confirm it.
  - Google sign-in accounts are confirmed by Google.
  - Accounts that already exist count as confirmed.
  - Re-registering an address that was never confirmed replaces that placeholder, so someone who typed another person's address can't block them.
  - Completing a password reset also confirms the address.

## 2026-10-15 — Several tasks in one dictation is a must
- **The owner:** saying a few things at once must create one task per thing, and that's "absolutely a must". His example: "go to the doctor on Friday at 5 and bring my blood test, and also finish the front-end design with mock-ups by Thursday at 5, and buy groceries, like tomatoes, potatoes, carrots, by tomorrow" gives three tasks:
  - the doctor on Friday at 17:00, with the blood test as a note;
  - the design, with a deadline of Thursday at 17:00;
  - groceries tomorrow, with a checklist of tomatoes, potatoes and carrots.
- **This answers UX-617.** The first-run line's spoken example now names two tasks («Llamar al dentista el viernes a las 10 y comprar pan mañana»).
  - The typed example stays one task, because a free account's typed words are parsed on the phone, and that can't split one line into several tasks.
  - Typed words go to the assistant only with Pro.
- **Decided by the main session (reversible):**
  - A bare hour in a dictation is read from context. Appointments, work and errands at 1 to 7 are in the afternoon, so «el médico el viernes a las 5» is 17:00 with no question.
  - The assistant asks only when both readings are plausible, such as waking up, or a flight at 5.
  - Why: the owner's example says "at 5" twice, and each question costs a tap (the speed bar).
- **What the main session found (backend commit 140f5cc):**
  - The free model understood the example. The server then threw the whole dictation away for two format slips: an extra array around the answer, and the AM/PM question written into the wrong field. Both are fixed.
  - The free model also failed most calls on 2026-10-15, with 500/504 errors and then quota exhaustion (429). With `AI_ROUTE=ai_studio` there is no fallback, so those dictations fail. This makes the UX-616 decision (below) urgent: configure the paid Vertex fallback.

## 2026-10-14 — Decided by the main session while the owner was away (reversible; tell the owner)
- **UX-609, the Catalan used-up line.** At 2× text on 320 dp, «Fins al dia {date} no tens dictats gratuïts.» takes 3 lines, where Spanish and English take 2. Accepted as it is: Catalan runs longer, and the typing field stays above a 300 dp keyboard in all three languages. The test allows 3 lines in Catalan and 2 in the others. Rejected: a shorter Catalan line that no native speaker has read.

## 2026-10-13 (late) — The product bar, the login wall, and the free tier

- **The selling point is speed, and it's the bar for every capture review.**
  - Creating a task must be super quick: as little interaction as possible beyond the time spent speaking.
  - About 5 seconds is a guide, not a hard number. The owner: "it does not specifically need to be 5s, but the idea is to make it super quick."
  - Creating several tasks in a row (2, 3, 4, 5) must stay just as fast.
  - Owner: "you create tasks super quick… that's where we have the advantage."
  - Capture must feel clearly faster than typing.
- **The login stays a hard wall** (U14 option 2 rejected).
  - No use of the app before signing in.
  - Owner's reasons: anonymous free use costs money, many such users never register, and it makes it harder to track who does what. Google sign-in makes the wall nearly effortless.
  - Option 1 (Google first, one line saying what TaskFlow does) stands.
- **Free tier** (replaces "D4b: not decided"):
  - **Voice:** users without Pro get **10 free voice captures a month**.
    - Counted per dictation, not per task (main session's default; the owner said "10 tasks a month with voice"). One dictation that yields several tasks counts once, because one dictation is one AI call. It also lets newcomers feel the several-tasks-at-once speed.
    - After the 10, they type, and typing is never capped.
  - **Attachments:** free users get a **total** attachment storage cap; Pro has none.
    - The owner was unsure of the size ("2 MB or 500 MB").
    - Main session's default: **100 MB in total**, a single backend setting so it's easy to change.
    - 2 MB would block even one phone photo.
  - Enforcement must be on the server; the app shows what's left.
  - This needs backend work, so it's built outside the front-end-only UX loop, then reviewed with `/ux`.
- **How the free tier works.** The main session decided these while the owner was away; each is reversible, so tell the owner if he disagrees. Full design: `.claude/ux-review/free-tier-plan.md`.
  - **This replaces D4a's "voice and AI stay Pro".**
    - The mic is available with Pro, or while free dictations are left.
    - Understanding typed words with the assistant stays Pro; free typing uses the phone's own date parser and never counts.
    - So a free user with dictations left seeing the mic is correct, not a regression.
  - **The month** is the calendar month in UTC; the app shows the reset date in local time.
  - **What counts:**
    - A dictation counts only if the assistant actually answered.
    - Failed, cancelled and offline dictations don't count.
    - A retry of the same dictation is free.
  - **Storage** is charged to the project's owner. Over the cap, files stay readable and removable; only new uploads are refused.
  - **Pro is unlimited for dictations and total storage.** The technical safeguards stay as they are: 50 AI calls a day, 6 per minute, 6 MB per file, 20 files per task, 1,000 files. So the copy avoids promising "unlimited" for anything else.
  - **The global AI budget** (200 calls a day) becomes a setting, because free dictation will use it sooner.
  - **For the owner later:** update the paywall's benefit text in the RevenueCat dashboard; agents don't touch external services.
- **Two tabs** (U13): wait until the UX loop has finished. Then the owner tests with his father and other testers (family and friends), and decides after that.

## 2026-10-13 — Answers to the whole-app plan (D1–D15 in `runs/2026-10-13-app/plan.md`)

The owner said: "from D1 to D15 go with your recommendations". In more detail:

- **D1 — overdue tasks** (UX-201). Unfinished tasks from earlier days move into Today, under "Atrasadas · N".
  - They keep their date and count in "pendientes" and in the Tareas "Hoy" filter.
  - A repeating task shows only its latest missed occurrence.
- **D2 — reminders for new accounts** (UX-401, U12).
  - (a) At the first saved task with a date, ask once: "¿Quieres un recordatorio antes?"
    - "Sí, recuérdamelo" turns reminders on and asks Android for permission in the same tap.
    - "Ahora no" leaves them off.
  - (b) Once reminders are on, date-only tasks remind at 9:00. This is an editable default.
  - (c) No `USE_EXACT_ALARM` for now: store policy is a production concern. P8's one-sentence ask covers it.
  - How "ask once" is shown (main session's reading of D2a, 2026-10-13): a one-time bottom sheet, right after the first dated task is saved. An in-list card failed twice (UX-401, batch b1), so P51 replaces it. The owner said to decide without asking; tell them if they'd prefer no interruption.
- **D3 — the capture direction in UX_REVIEW §3 is approved** (U1–U5, U7, U9). This also unblocks U8 and U12.
  - Listening ends only on Done.
  - Capture opens as a sheet with one mic.
  - The result shows in that sheet, with the date as its main line.
  - The calendar lands on the saved task.
  - "Guardar tal cual" appears when the AI is slow or fails.
  - Capture options move to Ajustes › Voz, and the Task/Note choice goes.
- **D4 — Pro.**
  - (a) Without Pro, the single "Añadir tarea" opens free typing with the local date parser. Voice and AI stay Pro.
  - (b) Free voice captures: not decided (a pricing call), so no change.
  - (c) Whether the owner's father's account is Pro is still unknown.
  - (d) The Pro screen keeps "Ver suscripción", "Restaurar compras" and, for paying users, "Gestionar suscripción".
    - "Abrir suscripciones de la tienda" goes.
    - The status refreshes by itself instead of through "Actualizar estado".
- **D5 — the sun–moon switch** (UX-406). It lives only in Ajustes › Apariencia. On first run, the theme follows the phone.
- **D6 — names** (U11, UX-311).
  - (a) The renames in §5.4 are approved:
    - "Bandeja de entrada" (no date) becomes "Sin fecha";
    - "Capturas pendientes" becomes "Sin guardar";
    - "Lista para cuando tú quieras" goes.
  - (b) The no-project bucket is "Sin proyecto".
    - The examples become "Casa, Trabajo, Compras".
    - The "Bandeja personal" chip leaves Tareas.
  - (c) Keep "Proyectos".
- **D7 — tabs and settings** (U13, part of UX-404).
  - (c) Ajustes has six rows, ordered by need:
    - the rare items move to a new "Otros ajustes" screen;
    - "Tareas completadas" moves to Tareas.
  - (a) Two tabs (Calendario + Listas, with Ajustes behind the avatar) are approved in principle. They come only after the capture fixes and the §7 test with the owner's father, not before.
- **D8 — sign-in order** (U14). Option 1 now: Google first, then email, plus one line saying what TaskFlow does. Option 2 (using the app before signing in) will be revisited after the §7 test.
- **D9 — spoken tasks without a date** (UX-112). They go on the selected calendar day when that day isn't today.
- **D10 — typed dates** (UX-204). A typed date is applied straight away, with "Dejar como está" one tap away.
- **D11 — delete** (UX-208).
  - Deleting happens at once, followed by "Tarea eliminada · Deshacer".
  - Only deleting a whole repeating series asks first, with "Conservar tarea" as the filled button.
- **D12 — Back in the task form** (UX-211).
  - Back saves a new task that has a title, or an edit with changes, then shows "Cambios guardados · Deshacer".
  - An empty form just closes.
- **D13 — developer screens** (UX-120, part of UX-408). "Diagnóstico de captura" and "Detalles de conexión" appear only in debug builds. A long-press on the version line opens them on staging.
- **D14 — invitations without the code.** An invitee signed in with Google, whose email matches, joins without the code. Password accounts keep it. This needs a backend change, which is outside the UX loop.
- **D15 — sharing** (part of UX-305).
  - (a) No single sharing door for now.
  - (b) The invite dialog drops the Editor/Viewer choice. Everyone joins as an editor, and the role can be changed on the person's row.

## 2026-10-13 — How the UX loop runs
- Fix everything the reviewer finds **except product decisions**, at every severity, 1 to 4.
  - The owner confirmed it: "I want also the severities 1 and 2 to be in the loop and autofix them without asking me."
- Stop for the owner's approval only on whole-app runs (`/ux app`). Scoped runs fix straight away.
  - The owner approved the 2026-10-13 whole-app plan through the answers above.
- The reviewer and organizer run at max effort, implementers at high. All use Opus.
- Commit each verified round on `dev`, plus a starting-point commit before a round when needed. Never push, and never touch `main`. (Since 2026-11-01 a fix run commits once, when its final check passes.)

## Standing decisions
- Calendar is the first screen (`App/docs/DESIGN.md`).
- The light/dark sun–moon switch stays, in Ajustes › Apariencia (D5).
- Projects (2026-10-11, `App/docs/PROJECTS_IMPLEMENTATION.md`):
  - the interface calls lists "projects";
  - groups hold people;
  - a project belongs to one group or is personal;
  - existing direct shares are kept;
  - an invitation is bound to an email address and needs a separately shared code (D14 relaxes this for Google accounts, once the backend allows it);
  - archived groups drop out of the daily view, capture and reminders.

## Open — not decided; anything that depends on these is a decision, not a fix
- **2026-10-18 (night):** most items below were decided by the main session while the owner was away; see that entry at the top. Still open: U13 and what follows from it.
- **Account deletion (2026-10-15).** The design is `Backend/docs/ACCOUNT_DELETION.md`; the review is run `2026-10-15-deletion`. Each item below gives the organizer's recommendation:
  - **Cleaning up completed tasks.** The owner described completed tasks being removed after 1 month (free) or 3 months (Pro). That job doesn't exist, and the privacy page says completed tasks are not deleted after 30 or 90 days. Choose one, and the website must match:
    - for everyone;
    - only for what a deleted account left in shared projects;
    - none.
  - **UX-815: a password account that forgot its password.** Let accounts with Google linked confirm with Google instead. The server already accepts that; the app only needs to offer it. Recovery inside the delete page can come later.
  - **UX-813: telling the person who receives a project or group.** Yes, later, together with the confirmation email.
  - **UX-814: files in "save a copy".** Not for now. It needs a new export format.
  - **UX-812: choosing the heir.** Not now. Heirs are named before confirming, and a group can be transferred first.
  - **Also for later:**
    - deleting the RevenueCat customer;
    - stopping someone who signs up again from getting new free dictations (which needs a hashed email);
    - (done: the website's delete-account page now gives the in-app option, WEB-202 and WEB-204.)
- **From the capture-speed review (run 2026-10-14-speed; details in its `plan.md`):**
  - **UX-615: should a spoken result with nothing to ask save itself, with Deshacer?** It would cut a capture to 2 taps (Añadir tarea, Listo) and save about 1–2 s, but it removes D3/U4's confirming tap, so a misheard date would be saved without a look. Recommendation: keep the tap until the §7 test with the owner's father, then decide.
  - **UX-616: should the assistant's wait be cut on the server,** with a faster model, or by understanding while the person is still speaking? Staging took 1.3, 4.8, 4.8, 4.8 and once 20.5 s. Recommendation: measure first (P101 adds the phone's share to Diagnóstico de captura). Then, if the server is most of the wait, try a faster extraction model on staging and compare cost and accuracy.
    - What the server does today (main session, read from `Backend/config/settings.py` and `core/ai_routing.py`; no calls made, and `.env` not read): task extraction uses the free AI Studio model (`AI_TEXT_MODEL`, `gemma-4-26b-a4b-it`). Under `AI_ROUTE=auto`, each free attempt gets up to `AI_FREE_ATTEMPT_SECONDS` (10 s), with up to two attempts before falling back to paid Vertex (`gemini-3.1-flash-lite`, minimal thinking). Under `ai_studio`, the code default, there is no paid fallback, and one capture can take up to the 45 s stage budget. Either way, a slow free call explains the 20.5 s seen on staging.
    - Settings-only options, with no code change:
      - under `auto`, lower `AI_FREE_ATTEMPT_SECONDS` to 10 (the minimum, because Google refuses a request deadline under 10 s; since 140f5cc the code raises lower values to 10), so slow free calls fall back sooner;
      - set `AI_ROUTE=vertex` to always use the paid model, which is the fastest and most predictable but costs money on every dictation.
      Both trade money for speed, so they are the owner's call.
  - ~~UX-617~~: answered by the owner on 2026-10-15 (see above).
- **Finding the tasks that hold files** (from UX-506, b7). When a free account's file space is full, the message asks people to remove files from other tasks, but nothing lists which tasks have files. Whether to add a way to find them is the owner's call: it adds a feature, so the loop doesn't.
- **The two-tab layout** (U13, D7a): after the UX loop and the owner's tests with his father, family and friends.
- ~~The single reminder on shared tasks (2026-10-22, after D6)~~: answered by the owner on 2026-10-23: personal, like plans (see above).
