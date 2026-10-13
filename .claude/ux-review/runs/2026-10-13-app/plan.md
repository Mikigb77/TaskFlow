# UX plan — 2026-10-13-app (whole app)

The four reviews found 119 problems. After merging 6 duplicates, 103 are fixes in 30 packages (P3 also carries U6's app side), and 10 need your answer, as do 13 of the earlier plan items U1–U14.
Both severity-4 problems need you first: unfinished tasks vanish from Today (D1), and reminders are off by default (D2). Until you answer, P8 makes the reminder chip honest and lets one tap turn reminders on.

**How to answer**
- **Decisions:** reply by number ("D1 yes, D6b Personal, D9 no") or "all recommendations". The main session records them in DECISIONS.md; then `/ux plan 2026-10-13-app` turns what they unblock into packages.
- **Packages:** "go" runs P1 → P30 in order, one at a time. Strike some with `/ux fix skip P5 P18`, or run a few with `/ux fix only P1 P2`. No package depends on an unanswered decision; where a finding has a part that needs you, the package does the rest and says so.

## Decisions

### D1 · Unfinished tasks from earlier days — UX-201 (S4)
An open task appears only on its own date. Yesterday's "Llamar al banco" isn't on Today, the counts say "0 pendientes", and only a 4 px dot is left. People add it again.
- (a) Carry them into Today under "Atrasadas · N", with their date, counted in "pendientes" and in the Tareas "Hoy" filter; a repeating task shows only its latest missed occurrence.
- (b) Leave them on their date, with one link: "N sin hacer de días anteriores ›".

**Recommend (a):** it's what other task apps do, and it needs no extra tap.

### D2 · Reminders for new accounts — UX-401 (S4), U12
Reminders are off for every new account, and only Ajustes › Notificaciones asks for Android's permission, so "Recordatorio: 10 minutos antes" never rings.
- (a) At the first saved task with a date, ask once: "¿Quieres un recordatorio antes?" "Sí, recuérdamelo" turns reminders on and asks Android in the same tap; "Ahora no" leaves them off.
- (b) Once on, date-only tasks remind at 9:00 (an editable default).
- (c) Apply for Google Play's USE_EXACT_ALARM, which calendar apps may use, so on-time reminders skip the "Alarmas y recordatorios" screen?

**Recommend** yes to (a) and (b). For (c): yes if the Play listing presents TaskFlow as a calendar app; otherwise P8's one-sentence ask covers it. P8 ships without any of these.

### D3 · The capture direction (UX_REVIEW §3) — U1, U2, U3, U4, U5, U7, U9
- Listening ends only on Done (U1, U2).
- Capture opens as a sheet with one mic (U3).
- The result shows in that sheet, with the date as its main line (U4).
- The calendar lands on the saved task (U5).
- "Guardar tal cual" when the AI is slow or fails (U7).
- Capture options leave the screen and the Task/Note choice goes, with a new Ajustes › Voz (U9).

**Recommend** approving it. At the very least approve U1 — the pause that stopped your father — and U5, which can reuse the landing P7 builds for typed saves. Approving also unblocks U8, U12, the timeline's "+" (UX-224) and folding Discard into Cancel (UX-126).

### D4 · Pro and the single Add button — U8, part of UX-423
- (a) Once U8 leaves one "Añadir tarea" button, should users without Pro get free typing in that sheet (with the local date parser), or the paywall?
- (b) Should the first few voice captures be free?
- (c) Is your father's account Pro or complimentary? If it is, the 10-minute test won't show the wall other newcomers meet.
- (d) The Pro screen shows four secondary buttons. Keep only "Ver suscripción" and "Restaurar compras"?

**Recommend:** (a) free typing; voice and AI stay Pro. (b) Your pricing call. (d) Keep "Gestionar suscripción" for paying users too, drop "Abrir suscripciones de la tienda", and refresh the status automatically instead of "Actualizar estado". P5 already lets today's Pro wall open the free typed editor ("Escribir la tarea"); typing is already free from "Nueva tarea", so nothing paid changes.

### D5 · Where the sun–moon switch lives — UX-406, U10
It's on 23 surfaces: next to the avatar (reaching for Account turns the app dark), beside Delete on a task, and on Notificaciones, where a moon reads as Do Not Disturb. (a) Ajustes › Apariencia only, with first run following the phone; (b) the Calendar header only; (c) the avatar menu.

**Recommend (a).** P18 already turns the theme tiles into one Apariencia row (Claro / Oscuro / Como el teléfono), which works with any answer. U10's limit of 15 tap targets on Calendar also needs this and U8; P6 and P25 remove 6 targets in the meantime.

### D6 · Names — U11, UX-311
- (a) Approve UX_REVIEW §5.4's renames: "Bandeja de entrada" (no date) → "Sin fecha"; "Capturas pendientes" → "Sin guardar"; drop "Lista para cuando tú quieras".
- (b) Call the no-project bucket "Personal" (§5.4) or "Sin proyecto" (UX-311)? "Personal" would sit next to the "Proyectos personales" section and the example project name "Personal".
- (c) Keep "Proyectos" (decided 2026-10-11), or call personal containers "Listas"? Report C notes nobody calls the shopping list "un proyecto".

**Recommend:** (a) yes; (b) "Sin proyecto", with UX-311's new examples ("Casa, Trabajo, Compras") and the "Bandeja personal" chip dropped from Tareas; (c) keep "Proyectos" unless your father stumbles on it.

### D7 · Tabs and Settings — U13, UX-331, part of UX-404
- (a) Two tabs, Calendario and Listas (search, Sin fecha, projects, Notes, Completed), with Ajustes behind the avatar — or does Notes keep its own tab?
- (b) If Notes stays a tab: when a search finds nothing, show "En Notas: 2" (UX-331)?
- (c) Settings in six rows by need, with the rare ones (Hora y región, Calendarios del teléfono, the home-screen mic button, Exportar e importar, Licencias) in a new "Otros ajustes" screen, and "Tareas completadas" moved to Tareas/Listas?

**Recommend:** (a) two tabs, after the capture fixes and the §7 test; (b) only if Notes stays; (c) yes. P18 already puts Recordatorios first and removes the noise.

### D8 · Sign-in order — U14
Option 1: Google first, email second, and one line saying what TaskFlow does. Option 2: use the app before signing in.

**Recommend option 1 now**, and revisit option 2 after the §7 test. P17's sign-in fixes apply either way. `App/test/auth_gate_test.dart`, which locks Google below the email form, changes with option 1.

### D9 · Spoken tasks without a date — UX-112
With Thursday selected, "Nueva tarea" pre-fills Thursday, but a spoken "comprar pan" goes to the inbox with no date. Use the selected day (when it isn't today) for spoken tasks without a date?

**Recommend yes.** A spoken time without a day needs the server.

### D10 · Typed dates — UX-204
"Dentista viernes 10:00" saves on today unless the small "Usar vie, 17 oct · 10:00" chip is tapped. Apply the understood date straight away, with "Dejar como está" one tap away? A code comment says suggestions are never applied automatically, but it isn't a recorded decision.

**Recommend yes.**

### D11 · Delete — UX-208
Replace the "¿Eliminar?" confirmation, whose filled button is Eliminar, with an immediate delete and "Tarea eliminada · Deshacer"?

**Recommend yes.** Keep one confirmation only for deleting a whole repeating series, with "Conservar tarea" as the filled button.

### D12 · Back in the task form — UX-211
Back throws away what was typed. (a) Save it — a new task with a title, or an edit with changes — and show "Cambios guardados · Deshacer"; an empty form just closes. Or (b) ask "¿Guardar esta tarea?"

**Recommend (a)**, like the voice path.

### D13 · Developer tools in release builds — UX-120, part of UX-408
"Diagnóstico de captura" (P50/P95) is a Settings row every user sees, and "Detalles de conexión" shows the server URL on Account. Hide both from release builds?

**Recommend** debug builds only, plus a long-press on the version line so you keep them on staging.

### D14 · Invitations without the code for Google accounts — report C (nothing waits on it)
Invitations need a separately shared code because password sign-up doesn't verify the email (2026-10-11). Google sign-in does. Let an invitee signed in with Google, whose email matches, join without the code?

**Recommend yes**, keeping the code for password accounts. It needs a server change; P14 works either way.

### D15 · One way to share — report C, part of UX-305
- (a) Should "Compartir" on a project be the only door, creating or reusing a group behind the scenes, with Grupos as an advanced view?
- (b) Drop the Editor/Viewer choice from the invite dialog? Everyone would join as an editor; the role can still be changed on the person's row.

**Recommend:** (a) not now — P13 already puts "Compartir" on the project page; (b) yes.

## Packages, in order

Severity-3 packages first, then severity 2. Each runs alone, after the packages it builds on. Sizes: S, M, L.

### P1 · Snackbars time out and never outlive their screen · A · L
- **UX-101** (S3; merged UX-207) "1 tarea guardada · Deshacer" never leaves and follows you into the next capture → every undo bar times out; opening a capture clears it.
- **UX-416** (S2) messages ignore Android's accessibility timeout; widget instructions vanish in 4 s → one helper for every snackbar; the instructions open in a sheet.
- **UX-335** (S1) Projects uses fixed snackbars → they float like the rest.

### P2 · Capture: listening the user controls · A · L · after P1
- **UX-104** (S3) pulling down the notification shade stops listening → only leaving the app does.
- **UX-107** (S3) a microphone blocked for good can't be fixed → a banner by the mic with "Abrir Ajustes".
- **UX-108** (S2) "Preparando tu plan…" before anything is said → "Un momento…", then "Escuchando" once the recognizer is ready.
- **UX-109** (S2) TalkBack: listening starts by itself; the stop control has three names → no auto-start, spoken cues, one label per state ("Empezar a hablar" / "Parar").
- **UX-115** (S2) speech follows the phone's language, forgets the choice and shows "es-ES" → the app's language, remembered, no code.

### P3 · Speech hints for the recognizer and the assistant · A · M · after P2
- **U6** (P0, app side) the recognizer is biased towards weekday and month names, day words, and your project and people names; requests say whether the words were spoken or typed. The prompt change is server-side.

### P4 · Capture screen: words and errors in view, in plain words · A · L · after P2
- **UX-105** (S3) at large text the live words are off-screen → while listening, only the status and big words show.
- **UX-103** (S3) raw English server errors and jargon, below the fold → plain messages in three languages, under the status, announced by TalkBack.
- **UX-126** (S1) "Descartar captura" sits under the main button, and its dialog favours it → a quiet text button.

### P5 · Capture: every way in leads somewhere · A · L · after P4
- **UX-102** (S3) opening the mic and going back leaves "Capturas pendientes · 1" → empty captures are never kept.
- **UX-106** (S3) without Pro, every way in ends on the wall → "Escribir la tarea" opens the free editor with the words; no wall flash while billing loads.
- **UX-114** (S2) "Captura texto" and shared text open a mic-first page → keyboard first; the shortcut is renamed "Escribir una tarea".

### P6 · Calendar: today's tasks first, and offline is calm · B · L
- **UX-202** (S3) today's tasks start below the fold → remove "Tu calendario", "Bandeja · 0", the project chip until there are projects, the completion ring, and two of the three view buttons (one switcher).
- **UX-217** (S2) phone events sit above the tasks → one line under them.
- **UX-218** (S2; merged UX-414) offline shows a red box about the "server address" → a calm grey line; network errors mention Wi-Fi and mobile data.
- **UX-226** (S2) overdue deadlines and calendar dots rely on colour → "Fecha límite vencida"; dots only for open tasks.

### P7 · Calendar shows where your task went, and follows today · B · L · after P1, P6
- **UX-205** (S3) a typed task saves with no sign of where it went → the calendar selects its day and highlights it: "Añadida al vie, 17 oct · Deshacer".
- **UX-203** (S3) after midnight the calendar still shows, and pre-fills, yesterday → it follows today and never pre-fills a past day.
- **UX-111** (S2) dates have no weekday → "Hoy", "Mañana", "vie, 17 oct".
- **UX-220** (S2) a completed task jumps away; Completed lists the oldest first → it stays put until you leave the day; newest first.

### P8 · Reminders: an honest chip and a one-tap turn-on · B · L · after P1
- **UX-209** (S3; with UX-401's chip fix) "Recordatorio: 10 minutos antes · desactivado en el dispositivo" → "Sin recordatorio · Activar", which turns reminders on.
- **UX-210** (S3) the timing hides behind ⋮ and an extra button → the chip opens the choices; one tap applies.
- **UX-405** (S3) on-time reminders take 7–8 steps and 135 words → one switch, one sentence for exact alarms, a confirmation; details folded away; "Por la mañana" instead of "Mañana".

### P9 · One date sheet; a moved task names its day · B · L · after P1, P7
- **UX-206** (S3) a moved task vanishes behind "Programación actualizada" → "Hoy" and "Mañana" apply at once: "Movida al mié, 14 oct · Deshacer".
- **UX-212** (S2) two date sheets and two repeat editors → one of each.
- **UX-221** (S2) "a las 17" is treated as ambiguous, a. m. is preselected, empty minutes are rejected → time chips, 13–23 unambiguous, :00 by default.

### P10 · Task detail: only what's set, tap to change it · B · M · after P9
- **UX-309** (S3) a note can only be edited from the corner pencil → "Editar nota" at the bottom; tap the text to edit.
- **UX-213** (S2) a plain task shows about 45 words of empty sections → about 20.
- **UX-214** (S2) the date rows look tappable but aren't → they open the date sheet; the title opens the form.

### P11 · Search ignores accents · C · S
- **UX-303** (S3) "medico" doesn't find "Médico" → all four searches ignore accents.

### P12 · Moving a task into a project: safe and findable · C · L
- **UX-302** (S3) one tap shares a private task for good → it asks once; the locked chip explains itself.
- **UX-308** (S3) Projects hides behind an unlabelled folder; the picker dead-ends → a "Proyectos" button; a "Nuevo proyecto" row.
- **UX-324** (S2) the chip doesn't look tappable, and a warning repeats on every shared row → ▾; the group's name only.
- **UX-325** (S2) the assistant's doubt shows as a red error → "¿Es correcto? · Sí".

### P13 · Share from the project page; shorter invitations · C · L
- **UX-305** (S3) no Share on the project; 8 taps and 73 words → "Compartir" on the project page, a one-field invitation, a one-line code dialog.
- **UX-318** (S2) tapping a pending invitation silently re-sends it → a menu with Reenviar and Anular.
- **UX-316** (S2) five words for the other people → "Todas", "Todos", "Miembros".
- **UX-339** (S1) owner noise and empty headings → removed.

### P14 · Invitations: find them, join, and land on what you joined · C · L · after P1, P6, P13
- **UX-306** (S3) invitations hide two levels deep and ask for an unexplained code → a card on Calendar, one join dialog, and Decline asks first.
- **UX-307** (S3) after joining, nothing shows what you joined → you land on it: "Te has unido a Compras".
- **UX-326** (S2) the review screen promises details that aren't there, and "Cancelar" reads like reject → plain copy; "Ahora no". Who sent the invitation needs the server.

### P15 · Archive, delete and leave say what happens · C · M · after P1
- **UX-301** (S3) archiving or muting silently stops reminders → the message says so, with Undo; "Silenciado: sin novedades ni recordatorios".
- **UX-317** (S2) deleting a personal project hides under Compartir; destructive buttons look normal → "Eliminar proyecto" in the menu; the error colour.
- **UX-340** (S1) leaving or deleting closes the screen silently → "Has salido de Física" / "Proyecto eliminado".

### P16 · Notes: newest first, saved where you are · C · M · after P7, P11
- **UX-304** (S3) notes have no order → newest first; a new note shows at the top.
- **UX-313** (S2) dictating a note inside a project saves it outside → saved in the project.
- **UX-312** (S2) Notes uses task wording → note wording.
- **UX-323** (S2) an unlabelled project dropdown → "Proyecto: Todas las notas".
- **UX-118** (S2) typing is the filled button on Notes → voice is, as on Calendar.
- **UX-337** (S1) a permanent explanation above the list → only when Notes is empty.

### P17 · Sign-in that leads somewhere · D · L
- **UX-402** (S3) a newcomer "signs in" and hits "incorrect password" → the error offers "Crear una cuenta con este correo"; headings name the mode.
- **UX-403** (S3) sign-up errors fall below the fold at 2× → errors on the field; the password rule shown before typing.
- **UX-415** (S2) Back from Create or Recover exits the app; both recovery steps say "Continuar" → Back returns to sign-in; "Enviar código" / "Guardar contraseña nueva".

### P18 · Settings: reminders first, fewer words · D · L · after P1, P8
- **UX-404** (S3) 14 entries, with Notificaciones 10th → "Recordatorios" first, showing its state; no eyebrow, tagline or misleading section labels. The six-row version waits on D7, diagnostics on D13.
- **UX-408** (S2) Account's main button is "Sincronizar ahora", and signing out silently stops reminders → one status line; sign-out asks first.
- **UX-418** (S2) "Sistema" breaks mid-word at 2× → one Apariencia row: Claro / Oscuro / Como el teléfono.
- **UX-422** (S1) "Hora y región" opens "Idioma y región", with a second language picker and raw time-zone ids → fixed.
- **UX-423** (S1) a 45-word Export intro → one line. The Pro screen's buttons wait on D4.

### P19 · Voice review: fewer, clearer choices · A · L · after P1, P7
- **UX-110** (S2) the AM/PM card has four buttons, and one saves without the time → "5:00 · 17:00 · Sin hora".
- **UX-116** (S2) batch questions and ✕ appear only on expanded cards → on every card.
- **UX-117** (S2) nothing left: a disabled button and a tiny link → "Terminar".
- **UX-113** (S2) a voice note's title is the whole transcript → its first sentence.
- **UX-124** (S1) "Task Title"; "Ver lo que dije" for typed text → "Task title"; "Texto original".
- **UX-127** (S1) "Prioridad Baja · No se repite" on every task → only what's set.

### P20 · Native labels, share messages and shortcut icons · A · M · after P2, P5
- **UX-121** (S2; merged UX-128, UX-417) "Dicta" versus "Dictar", "…conserva las capturas pendientes" → "Dictar una tarea", "Toca para dictar una tarea."
- **UX-119** (S2) share errors only in English → in Spanish and Catalan too.
- **UX-125** (S1) both shortcuts use the app icon → a mic and a pencil.
- **UX-420** (S1) the iOS microphone prompt says "borrador de tarea" → plain words.

### P21 · Task form: the title first, fewer words · B · L · after P8, P9, P10, P19
- **UX-215** (S2) a headline, a help line, a project row and a Task/Note choice before the title → the title first, focused.
- **UX-216** (S2) "Más detalles" opens 8 things and 4 paragraphs → the common ones first; "Añade una fecha para repetir".
- **UX-222** (S2) one dialog per checklist step → an inline field.
- **UX-227** (S1) polish: "Create task", "up to 32", inert chips, a duplicate "Quitar fecha", Catalan "Canvia la data", reduced motion.

### P22 · Spanish and Catalan copy slips · B · M · after P19, P21
- **UX-225** (S2; merged UX-310) "Proyecto de pasos", "Archivada", "1 completadas", "Cada 1 semanas", an English tooltip → fixed, with a catalog test.
- **UX-122** (S1) Catalan buttons in the infinitive → imperatives.
- **UX-123** (S1) "1 conservades per revisar" → plurals.

### P23 · Back and reminders never strand you · B · M · after P1
- **UX-223** (S2; merged UX-410) Back on a tab closes the app, and a reminder for a deleted task opens a second home → Back goes to Calendario; no second home.
- **UX-224** (S2) the timeline's arrows say "Mes o semana", plus developer copy → "Día anterior / Día siguiente"; the copy goes. Its "+" waits on U8.

### P24 · Project pages and Tareas show what's there · C · M · after P12, P13
- **UX-314** (S2) view-only projects keep their create buttons → the read-only line.
- **UX-315** (S2) project pages hide others' tasks through the global "Para mí" → everything by default; the choice stays on that page.
- **UX-219** (S2) an empty filter says "Un nuevo comienzo" → "No hay tareas que coincidan".
- **UX-333** (S1) eyebrow labels and repeated headlines → removed.

### P25 · One meaning per bell; readable Activity · C · M · after P13, P15
- **UX-407** (S2) the header bell opens Activity → a people icon, shown only with groups or shared projects.
- **UX-322** (S2) a second bell on project pages → a labelled row on the sharing screen.
- **UX-321** (S2) Activity rows bury who did what → "Ana ha completado: Comprar pan"; unread rows in bold.

### P26 · Projects list: less noise; land on the new project · C · M · after P15
- **UX-327** (S2) after creating a project you stay on the list → its page opens.
- **UX-329** (S2) a repeated headline, a help line, a refresh button, search with 0 projects, two retry buttons → removed or merged.
- **UX-332** (S1) a colour choice to start a project → teal by default.
- **UX-334** (S1) "black star", "Proyectos compartidos · Editor", counts that include done items → fixed.
- **UX-338** (S1) choosing a group gives no hint → "Todos en Máster lo verán."

### P27 · Groups: clear dialogs, errors and lists · C · L · after P13, P14
- **UX-319** (S2) "Guardar" on every step and calendar error text → "Crear grupo", "Siguiente", real errors, titled role sheets.
- **UX-320** (S2) a load failure says something couldn't be saved → "No se ha podido cargar…" with Reintentar.
- **UX-328** (S2) a failed dialog loses what you typed → it stays open with the error.
- **UX-330** (S2) unlabelled pending invitations, a prominent spoken-name button, emails instead of names → a heading, the member's own menu, names first.
- **UX-336** (S1) a group's page is titled "Grupos" → its name.

### P28 · Text fields and tabs you can see · D · S
- **UX-412** (S2) field outlines at 1.28:1 → about 3.8:1.
- **UX-413** (S2) the selected tab is hard to tell → a bolder label and a filled icon.
- **UX-421** (S1) tab labels at 11 sp → 12 sp.

### P29 · Reminder notifications say when, and can be undone · D · M · after P7
- **UX-409** (S2) "Programada dentro de 10 minutos" goes stale → "Hoy a las 17:00 · en 10 min".
- **UX-411** (S2) "Completar" on a notification can't be undone → "Completada: … · Deshacer" for a few seconds.

### P30 · Start fast; keep what you typed when the session ends · D · M
- **UX-419** (S2) an expired session rebuilds the app and loses typing → sign-in on top, then back where you were.
- **UX-424** (S1) startup waits for reminder setup → it runs after the first frame.

## Merged duplicates
- **UX-207 → UX-101:** undo snackbars that never close (P1).
- **UX-414 → UX-218:** "server address" in network errors (P6).
- **UX-410 → UX-223:** a second home screen after a reminder for a deleted task (P23). The reports differ on the deleted-task case; P23 uses the existing "Es posible que esta tarea se haya eliminado." and adds no copy.
- **UX-310 → UX-225:** "Proyecto de pasos" and the other rename artefacts (P22).
- **UX-128, UX-417 → UX-121:** native strings (P20). The "Captura texto" rename is done in P5 with UX-114, and the in-app stop label in P2 with UX-109.
- **UX-401's chip fix → UX-209** (P8). UX-401 itself — reminders off by default — stays as decision D2.
- **UX-404's diagnostics row → UX-120** (D13).
- "Task Title" (UX-124 and UX-227) is fixed once, in P19. "COMPLETADAS" (UX-227) is fixed with UX-213, in P10.

## Skipped (6)
UX-128, UX-207, UX-310, UX-410, UX-414 and UX-417: duplicates, merged as listed above. Nothing was skipped as already fixed or server-side only.

## Waiting, or not in this plan
- **Waiting on decisions:** the parts named in each decision above, and the U-items they cover.
- **Server-side (reported, not planned):** U6's speech-aware prompt in `Backend/core/ai.py`; the inviter's name on invitations (UX-326); the English-only invitation web page; owners can't set a spoken name (a deliberate server rule, UX-330); a spoken time without a day (UX-112).
- **Not planned:**
  - Changing which project new tasks are saved to when Calendar is filtered (UX-302): it would change what gets shared, so it's yours to raise.
  - Muting a project also silences your own reminders (UX-301). P15 says so on the label; if you'd rather muting not do that, say so.
  - The reviewer's "later" single task form (UX-215): it overlaps U4.
  - Adding checklist steps from the task detail (UX-222).
  - The iOS local-network text (UX-420).

## Corrections to the reports
- **Renames:** the Lista→Proyecto and "No list"→"Personal inbox" renames were committed in f0da53d before the reviews ran. Report C calls them uncommitted; the problems are real either way.
- **Raw server text:** report D's "Keep" note says no raw server text reaches the screen. Capture errors can (`captureProblemText` falls back to the raw text); UX-103 fixes it in P4.
- **Completed tasks:** report D says "Tareas completadas" is reachable only from Settings. It is also the ✓ on Tareas (reports B and C).

## Ledger
`ISSUES.md` now lists all 119 findings and U1–U14: 104 open (each with its package), 23 waiting on a decision, and 6 duplicates under Won't fix. U1–U5 and U7–U12 moved to "Decision needed", because they depend on decisions still open in DECISIONS.md; U6 stays open, in P3.
