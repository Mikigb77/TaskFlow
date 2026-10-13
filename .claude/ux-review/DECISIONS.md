# Owner decisions

Every agent in the UX loop reads this before reviewing or planning. Only the owner makes these decisions. Agents never add to this file; the main session records what the owner says in chat. Newest first.

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
- **Free voice captures** for users without Pro (D4b), a pricing call.
- **Timing of the two-tab layout** (U13, D7a): after the capture fixes and the §7 test.
- **Using the app before signing in** (U14 option 2, D8): revisit after the §7 test.
