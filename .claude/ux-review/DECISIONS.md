# Owner decisions

Every agent in the UX loop reads this before reviewing or planning. Only the owner makes these decisions. Agents never add to this file; the main session records what the owner says in chat. Newest first.

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
- **D11 — does the commands flag slow every dictation?** Staging can't be used without a deploy, so the main session measures it locally with the real model, then decides together with UX-616.

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
- Commit each verified round on `dev`, plus a starting-point commit before a round when needed. Never push, and never touch `main`.

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
    - the website's delete-account page, which still says the app has no deletion option.
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
