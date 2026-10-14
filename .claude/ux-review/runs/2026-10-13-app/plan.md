# UX plan — 2026-10-13-app (whole app), revised after your answers

Your answers to D1–D15 turned 20 waiting items into fixes: 124 of the 133 findings now sit in 41 packages, 3 still wait on you, and 6 are duplicates.
Overdue tasks (P31) run first, then the reminder question (P32) and the capture redesign (P33–P41); nothing in the run waits on the questions below.

**How it runs:** you approved the plan, so `/ux fix` runs the packages below in this order, one at a time, without stopping. To hold some back: `/ux fix skip P43`, or `/ux fix only P31 P1`. The plan you approved first is in git (d46f888).

After the last package, ux-tester turns the acceptance checks into tests. Where an older package's check names a screen the redesign replaces (the review page, the typed "Nueva tarea" form), it's tested on the replacement.

## Still open

### Two tabs — U13, with U10 and UX-331
You approved Calendario + Listas, with Ajustes behind the avatar, in principle (D7a), for after the capture fixes and the §7 test with your father. Two items wait on it:
- **U10:** after P6, P18, P25 and P38, a new account's Calendar has 16 tap targets. The goal is 15 or fewer; two tabs bring it to 14.
- **UX-331:** "En Notas: 2" when a search finds nothing isn't built: one Listas search would replace it (D7b).

**Recommend:** run the §7 test after this run, then decide.

### Using TaskFlow before signing in — U14 option 2
**Recommend:** revisit after the §7 test, as you decided (D8). P17 does option 1 now.

### Exact alarms — D2c
Not for now, as you decided: it's a store-policy question for production. P8 asks for "Alarmas y recordatorios" in one sentence when it's needed.

### Free voice captures — D4b, and D4c
Your pricing call; nothing in this run depends on it.
**Still unknown (D4c):** is your father's account Pro? Without Pro, "Añadir tarea" opens typing, not the mic, so check before the §7 test.

### Invitations without the code — D14
Approved, but it needs a Backend change outside the UX loop. P14 keeps the code field. Once the server allows it, a scoped `/ux` run can hide the field for Google accounts.

## What changed since you approved it
- **New packages from your answers:**
  - P31 overdue tasks (D1);
  - P32 the reminder question and the 9:00 default (D2a, D2b);
  - P33–P41 the capture redesign (D3, D4a, D9, D10, plus U12's first run);
  - P42 delete and Back with Undo (D11, D12);
  - P43 the renames (D6a, D6b);
  - P44 Account and the Pro screen (D13, D4d), split from P18.
- **Folded into the redesign (D3).** P2, P4 and P5 polished the page the sheet replaces. What still applies moved:
  - UX-104, UX-107, UX-108 → P33;
  - UX-105, UX-109, UX-126 → P35;
  - UX-115 → P34;
  - UX-102, UX-106, UX-114 → P39;
  - UX-103 → P40.
- **Changed:**
  - P3 runs right after P33 and adds its hints to P33's new session.
  - P9 leaves the typed-time chips to P38: the typed form's date suggestion goes.
  - P13 drops the Editor/Viewer choice (D15b).
  - P16 hands UX-118 to P38, which gives Notes one button.
  - P17 puts Google first, with one line saying what TaskFlow does (D8).
  - P18 builds the six-row Ajustes with Otros ajustes (D7c), hides the developer screens (D13), and keeps the sun–moon only in Apariencia (D5).
  - P20 builds on P35 and P39 instead of P2 and P5.
  - P21 works on the edit form only.
- **Unchanged:** P1, P6–P8, P10–P12, P14, P15, P19 and P22–P30, word for word.

## How your answers were read
Say if any of these is wrong; only the package named changes.
- **D1:** a repeating task counts as overdue only while its most recent occurrence is still open. Older misses don't come back (P31).
- **D2a:** the question is a small card above the Add button, so it never covers the task that just landed. Accounts that already have dated tasks are asked once too (P32).
- **D3 with D7c:** Ajustes keeps six rows, so Voz is a row inside Otros ajustes (P34).
- **D3 with D9:** typed and spoken words take the same path. With today selected, a task without a date goes to Sin fecha; with a later day selected, it goes on that day (P38).
- **D4a:** "Añadir tarea" shows a mic with Pro and a + without (P38).
- **D10:** applies to typing in the sheet, which replaces the typed form (P38). The local parser also learns Catalan day words, so free typing works in all three languages.
- **Left out of the approved §3 design, to keep it small.** Say if you want any of them:
  - "Guardar como nota" on the result: notes come from Notes' own button;
  - press-and-hold on the Add button as a walkie-talkie: the hold-to-talk switch just goes;
  - keeping a WAV recording alongside the live words;
  - editing "Ver lo que dije" and extracting again.

## Packages, in run order
Severity 4 first, then 3, then 2. A package's prerequisites run before it, even when they're less severe. Sizes: S, M, L.

### P31 · Overdue tasks show on Today · B · M · new
- **UX-201** (S4) yesterday's unfinished task vanishes from Today → "Atrasadas · N" at the top of Today, counted in pendientes and in Tareas' "Hoy".

### P1 · Snackbars time out and never outlive their screen · A · L
- **UX-101** (S3; merged UX-207) "1 tarea guardada · Deshacer" never leaves and follows you into the next capture → every undo bar times out; opening a capture clears it.
- **UX-416** (S2) messages ignore Android's accessibility timeout; widget instructions vanish in 4 s → one helper for every snackbar; the instructions open in a sheet.
- **UX-335** (S1) Projects uses fixed snackbars → they float like the rest.

### P8 · Reminders: an honest chip and a one-tap turn-on · B · L · after P1
- **UX-209** (S3; with UX-401's chip fix) "Recordatorio: 10 minutos antes · desactivado en el dispositivo" → "Sin recordatorio · Activar", which turns reminders on.
- **UX-210** (S3) the timing hides behind ⋮ and an extra button → the chip opens the choices; one tap applies.
- **UX-405** (S3) on-time reminders take 7–8 steps and 135 words → one switch, one sentence for exact alarms, a confirmation; details folded away; "Por la mañana" instead of "Mañana".

### P32 · Ask once to turn reminders on, after the first dated task · D · M · after P1, P8 · new
- **UX-401** (S4) reminders are off and nothing asks → after the first dated task, "¿Quieres un recordatorio antes?" · "Sí, recuérdamelo" / "Ahora no"; once on, tasks without a time remind at 9:00.

### P33 · Listening stops only when you say so · A · L · after P1 · new
- **U1** (P0) the mic stops at the first pause → one continuous session until Listo; pauses never end it.
- **UX-104** (S3) the notification shade stops listening → only leaving the app does, and the words are kept.
- **UX-107** (S3) a microphone blocked for good can't be fixed → "Abrir Ajustes" by the mic; listening starts when you come back.
- **UX-108** (S2) "Preparando tu plan…" before anything is said → "Un momento…", then "Escuchando" once the recognizer is ready.

### P3 · Speech hints for the recognizer and the assistant (U6, app side) · A · M · after P33 · changed
- **U6** (P0, app side) the recognizer is biased towards weekday and month names, day words, and your project and people names; requests say whether the words were spoken or typed. The prompt change is server-side.

### P35 · Capture opens as a sheet; Listo always continues · A · L · after P33 · new
- **U3** (P0) a second mic on a separate page → a sheet over the screen you were on, listening at once, with Cancelar, Listo and Escribir.
- **U2** (P0) "finished" means two things → Listo always continues; Cancelar asks "¿Conservar lo que has dicho?".
- **UX-105** (S3) at large text the live words are off-screen → the words are the biggest thing in the sheet.
- **UX-109** (S2) with TalkBack, listening starts by itself → it waits for "Empezar a hablar"; spoken cues; one label per control.
- **UX-126** (S1) Discard sits under the main button → it lives in Cancelar's question, as the quiet choice.

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

### P12 · Moving a task into a project: safe and findable · C · L
- **UX-302** (S3) one tap shares a private task for good → it asks once; the locked chip explains itself.
- **UX-308** (S3) Projects hides behind an unlabelled folder; the picker dead-ends → a "Proyectos" button; a "Nuevo proyecto" row.
- **UX-324** (S2) the chip doesn't look tappable, and a warning repeats on every shared row → ▾; the group's name only.
- **UX-325** (S2) the assistant's doubt shows as a red error → "¿Es correcto? · Sí".

### P19 · Voice review: fewer, clearer choices · A · L · after P1, P7
- **UX-110** (S2) the AM/PM card has four buttons, and one saves without the time → "5:00 · 17:00 · Sin hora".
- **UX-116** (S2) batch questions and ✕ appear only on expanded cards → on every card.
- **UX-117** (S2) nothing left: a disabled button and a tiny link → "Terminar".
- **UX-113** (S2) a voice note's title is the whole transcript → its first sentence.
- **UX-124** (S1) "Task Title"; "Ver lo que dije" for typed text → "Task title"; "Texto original".
- **UX-127** (S1) "Prioridad Baja · No se repite" on every task → only what's set.

### P36 · The result appears in the sheet, with the date first · A · L · after P7, P12, P19, P35 · new
- **U4** (P0) the result is a separate page, and the date is the 4th row → the same sheet shows the title, then "vie, 17 oct · 17:00" as the main line, then "Añadir al calendario"; the review page goes.

### P37 · After adding, the screen shows the task · A · M · after P7, P36 · new
- **U5** (P0) after saving you aren't shown the task → the calendar moves to its day and highlights it: "Añadida al vie, 17 oct · Deshacer". Tareas and the pending list land too.

### P9 · One date sheet; a moved task names its day · B · L · after P1, P7 · changed
- **UX-206** (S3) a moved task vanishes behind "Programación actualizada" → "Hoy" and "Mañana" apply at once: "Movida al mié, 14 oct · Deshacer".
- **UX-212** (S2) two date sheets and two repeat editors → one of each.
- **UX-221** (S2) "a las 17" is treated as ambiguous, a. m. is preselected, empty minutes are rejected → 13–23 unambiguous, nothing preselected, :00 by default. The chips for typed times are in P38.

### P11 · Search ignores accents · C · S
- **UX-303** (S3) "medico" doesn't find "Médico" → all four searches ignore accents.

### P16 · Notes: newest first, saved where you are · C · M · after P7, P11 · changed
- **UX-304** (S3) notes have no order → newest first; a new note shows at the top.
- **UX-313** (S2) dictating a note inside a project saves it outside → saved in the project.
- **UX-312** (S2) Notes uses task wording → note wording.
- **UX-323** (S2) an unlabelled project dropdown → "Proyecto: Todas las notas".
- **UX-337** (S1) a permanent explanation above the list → only when Notes is empty.

### P38 · One Añadir tarea button, with typing in the same sheet · A · L · after P9, P16, P37 · new
- **U8** (P1) three or four ways to create → one "Añadir tarea" (on Notes, "Añadir nota"); typing moves into the sheet and is free without Pro; the typed form only edits.
- **UX-204** (S3) "Dentista viernes 10:00" saves on today → the date applies at once, with "Dejar como está".
- **UX-112** (S2) a spoken task ignores the selected Thursday → it goes on Thursday.
- **UX-118** (S2) Notes flips the button emphasis → one button.

### P39 · Every way into capture works, with or without Pro · A · L · after P35, P38 · new
- **UX-102** (S3) opening the mic and going back leaves "Capturas pendientes · 1" → empty captures are never kept.
- **UX-106** (S3) without Pro, the widget, shortcuts and share end on a wall → they open typing; the voice ones say voice is Pro, with "Ver Pro".
- **UX-114** (S2) "Captura texto" and shared text open a mic-first page → the keyboard comes up; the shortcut is "Escribir una tarea".

### P40 · When the assistant is slow or fails, save it as written · A · L · after P36, P38 · new
- **U7** (P0) the app waits up to 100 s → after 8 s, and on failure, "Guardar tal cual" saves the phone's own reading of the words.
- **UX-103** (S3) raw English server errors and jargon → plain messages in three languages, under the status line, announced by TalkBack.

### P10 · Task detail: only what's set, tap to change it · B · M · after P9
- **UX-309** (S3) a note can only be edited from the corner pencil → "Editar nota" at the bottom; tap the text to edit.
- **UX-213** (S2) a plain task shows about 45 words of empty sections → about 20.
- **UX-214** (S2) the date rows look tappable but aren't → they open the date sheet; the title opens the form.

### P42 · Delete and Back never lose a task · B · M · after P1, P10 · new
- **UX-208** (S3) delete can't be undone → it's immediate, with "Tarea eliminada · Deshacer"; only a whole repeating series asks, with "Conservar tarea" filled.
- **UX-211** (S3) Back drops what was typed → Back saves the changes: "Cambios guardados · Deshacer".

### P13 · Share from the project page; shorter invitations · C · L · changed
- **UX-305** (S3) no Share on the project; 8 taps and 73 words → "Compartir" on the project page, a one-field invitation with no Editor/Viewer choice (D15b), a one-line code dialog.
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

### P17 · Sign-in: Google first, and every path leads somewhere · D · L · changed
- **UX-402** (S3) a newcomer "signs in" and hits "incorrect password" → the error offers "Crear una cuenta con este correo"; headings name the mode.
- **UX-403** (S3) sign-up errors fall below the fold at 2× → errors on the field; the password rule shown before typing.
- **UX-415** (S2) Back from Create or Recover exits the app; both recovery steps say "Continuar" → Back returns to sign-in; "Enviar código" / "Guardar contraseña nueva".
- **U14** (P2, option 1) Google sits below the email form → Google first, then email, under one line: "Apunta lo que tienes que hacer y TaskFlow lo pone en tu calendario."

### P18 · Settings: six rows, reminders first, one place for appearance · D · L · after P1, P8 · changed
- **UX-404** (S3) 14 entries, with Notificaciones 10th → six rows: Recordatorios (showing its state), Idioma, Apariencia, Cuenta, TaskFlow Pro, Otros ajustes; "Tareas completadas" stays on Tareas.
- **UX-418** (S2) "Sistema" breaks mid-word at 2× → one Apariencia row: Claro / Oscuro / Como el teléfono.
- **UX-406** (S2) the sun–moon is on 23 surfaces → only in Apariencia; the first run follows the phone.
- **UX-120** (S2) "Diagnóstico de captura" for everyone → debug builds only; on staging, a long-press on the version line.
- **UX-422** (S1) "Hora y región" opens "Idioma y región", with a second language picker and raw time-zone ids → fixed.
- **UX-431** (S1; added after trial round 1) the time-zone search ignores accents, so once zones show as cities "Bogotá" finds nothing → it uses the app's accent-free search.

### P20 · Native labels, share messages and shortcut icons · A · M · after P35, P39 · changed
- **UX-121** (S2; merged UX-128, UX-417) "Dicta" versus "Dictar", "…conserva las capturas pendientes" → "Dictar una tarea", "Toca para dictar una tarea."
- **UX-119** (S2) share errors only in English → in Spanish and Catalan too.
- **UX-125** (S1) both shortcuts use the app icon → a mic and a pencil.
- **UX-420** (S1) the iOS microphone prompt says "borrador de tarea" → plain words.

### P34 · Voice options move to Ajustes › Voz · A · M · after P18, P35 · new
- **U9** (P1) technical options on the capture screen → the sheet has none; language and how speech becomes text live in Ajustes › Otros ajustes › Voz; the privacy note shows once.
- **UX-115** (S2) speech follows the phone's language, forgets the choice and shows "es-ES" → the app's language by default, remembered, no code.

### P21 · Task form: the title first, fewer words · B · L · after P8, P9, P10, P19 · changed
- **UX-215** (S2) a headline, a help line and a project row before the title → the edit form opens on the title; the Task/Note choice went with typed creation (P38).
- **UX-216** (S2) "Más detalles" opens 8 things and 4 paragraphs → the common ones first; "Añade una fecha para repetir".
- **UX-222** (S2) one dialog per checklist step → an inline field.
- **UX-227** (S1) polish: "Create task", "up to 32", inert chips, a duplicate "Quitar fecha", Catalan "Canvia la data", reduced motion.

### P22 · Spanish and Catalan copy slips · B · M · after P19, P21
- **UX-225** (S2; merged UX-310) "Proyecto de pasos", "Archivada", "1 completadas", "Cada 1 semanas", an English tooltip → fixed, with a catalog test.
- **UX-122** (S1) Catalan buttons in the infinitive → imperatives.
- **UX-123** (S1) "1 conservades per revisar" → plurals.

### P23 · Back and reminders never strand you · B · M · after P1
- **UX-223** (S2; merged UX-410) Back on a tab closes the app, and a reminder for a deleted task opens a second home → Back goes to Calendario; no second home.
- **UX-224** (S2) the timeline's arrows say "Mes o semana", plus developer copy → "Día anterior / Día siguiente"; the copy goes. P38 already turned its "+" into the Añadir tarea bar.

### P24 · Project pages and Tareas show what's there · C · M · after P12, P13
- **UX-314** (S2) view-only projects keep their create buttons → the read-only line.
- **UX-315** (S2) project pages hide others' tasks through the global "Para mí" → everything by default; the choice stays on that page.
- **UX-219** (S2) an empty filter says "Un nuevo comienzo" → "No hay tareas que coincidan".
- **UX-333** (S1) eyebrow labels and repeated headlines → removed.
- **UX-429** (S2; added after trial round 1) the "Todos los proyectos" sheet leaves no room for the keyboard → it stays above the keyboard while you type.

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
- **UX-430** (S1; added after trial round 1) a search that matches no project shows blank space → "No se han encontrado proyectos".

### P27 · Groups: clear dialogs, errors and lists · C · L · after P13, P14
- **UX-319** (S2) "Guardar" on every step and calendar error text → "Crear grupo", "Siguiente", real errors, titled role sheets.
- **UX-320** (S2) a load failure says something couldn't be saved → "No se ha podido cargar…" with Reintentar.
- **UX-328** (S2) a failed dialog loses what you typed → it stays open with the error.
- **UX-330** (S2) unlabelled pending invitations, a prominent spoken-name button, emails instead of names → a heading, the member's own menu, names first.
- **UX-336** (S1) a group's page is titled "Grupos" → its name.

### P43 · Plain names: Sin fecha, Sin proyecto, Sin guardar · C · M · after P6, P7, P12, P20, P24, P34, P36, P38–P40 · new
- **U11** (P1) "Bandeja de entrada", "Capturas pendientes", "Lista para cuando tú quieras" → "Sin fecha", "Sin guardar", gone; no "captura" left on screen.
- **UX-311** (S2) "Personal" collides three ways → the no-project bucket is "Sin proyecto", the examples are "Casa, Trabajo, Compras", and the "Bandeja personal" chip leaves Tareas.

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

### P41 · A brand-new account is told what to try · D · S · after P32, P37, P38 · new
- **U12** (P1) no learn-by-doing first run → a new account's empty Calendar says "Prueba: toca Añadir tarea y di «Llamar al dentista el viernes a las 10»." (or "escribe", without Pro). P32's question follows the first task.

### P44 · Account and TaskFlow Pro: the state in one line, fewer buttons · D · M · after P1, P18 · new
- **UX-408** (S2) Account's main button is "Sincronizar ahora", and signing out silently stops reminders → one status line; sign-out asks first; "Detalles de conexión" in debug builds only (D13).
- **UX-423** (S1) a 45-word Export intro, and four extra buttons on the Pro screen → one line; Ver suscripción, Restaurar compras and, if you've bought it, Gestionar suscripción; the status refreshes by itself (D4d).

## Merged duplicates
- **UX-207 → UX-101:** undo snackbars that never close (P1).
- **UX-414 → UX-218:** "server address" in network errors (P6).
- **UX-410 → UX-223:** a second home screen after a reminder for a deleted task (P23). The reports differ on the deleted-task case; P23 uses the existing "Es posible que esta tarea se haya eliminado." and adds no copy.
- **UX-310 → UX-225:** "Proyecto de pasos" and the other rename artefacts (P22).
- **UX-128, UX-417 → UX-121:** native strings (P20). The "Captura texto" rename is done in P39 with UX-114, and the sheet's stop control is P35's "Listo".
- **UX-401's chip fix → UX-209** (P8). UX-401 itself — reminders off by default — is P32.
- **UX-404's diagnostics row → UX-120** (P18).
- "Task Title" (UX-124 and UX-227) is fixed once, in P19. "COMPLETADAS" (UX-227) is fixed with UX-213, in P10.

## Skipped (6)
UX-128, UX-207, UX-310, UX-410, UX-414 and UX-417: duplicates, merged as listed above. Nothing was skipped as already fixed or server-side only.

## Not in this plan
- **Server-side (reported, not planned):**
  - U6's speech-aware prompt in `Backend/core/ai.py`;
  - the inviter's name on invitations (UX-326);
  - the English-only invitation web page;
  - owners can't set a spoken name, a deliberate server rule (UX-330);
  - a spoken time without a day (UX-112);
  - joining without the code for Google accounts (D14).
- **Not planned:**
  - Changing which project new tasks are saved to when Calendar is filtered (UX-302): it would change what gets shared, so it's yours to raise.
  - Muting a project also silences your own reminders (UX-301). P15 says so on the label; if you'd rather muting not do that, say so.
  - The reviewer's "later" single task form (UX-215): P36's result card now covers creation.
  - Adding checklist steps from the task detail (UX-222).
  - The iOS local-network text (UX-420).
  - The four parts of the §3 design listed under "How your answers were read".

## Corrections to the reports
- **Renames:** the Lista→Proyecto and "No list"→"Personal inbox" renames were committed in f0da53d before the reviews ran. Report C calls them uncommitted; the problems are real either way.
- **Raw server text:** report D's "Keep" note says no raw server text reaches the screen. Capture errors can (`captureProblemText` falls back to the raw text); UX-103 fixes it in P40.
- **Completed tasks:** report D says "Tareas completadas" is reachable only from Settings. It is also the ✓ on Tareas (reports B and C), which is where P18 leaves it.

## Ledger
`ISSUES.md` lists all 133 items: 124 open, each with its package; 3 waiting on a decision (U10, U13, UX-331); 6 duplicates under Won't fix. The 20 lines your answers unblocked moved from "Decision needed" to "Open", and the lines whose package changed now name the new one.

## Round 2 (trial)

Round 1 of the trial ran P11 and P28: UX-303, UX-412 and UX-413 are verified fixed, the round check passed, and no test failed. UX-421 is only partly fixed, and the two packages caused four small regressions, now UX-425 to UX-428.
Round 2 fixes those regressions in two small packages, P45 and P46. What's left of UX-421 joins the two-tab decision, and nothing is escalated.

The briefs are in `plan-trial-r2.json`.

### UX-421 now waits on the two tabs (U13)
- **Done in P28:** the tab labels are 12 sp.
- **Left:** Catalan "Configuració" still doesn't fit its tab on a 320 dp phone with text at 1.3×. The reviewer measured 103.7 dp selected and 98.1 dp unselected, in an 80 dp tab; at 11 sp it was 93.6 dp.
- **Why it isn't planned again:** four tabs can't hold the word. Renaming it isn't recommended either: it's Android's own Catalan word for Settings, and two Catalan messages send people there. Two tabs give each tab 160 dp.
- **My mistake:** P28's device check asked for this fit, but the finding itself said only U13 clears it, and 12 sp makes the word wider.
- **Where it is now:** under "Decision needed" in `ISSUES.md`, with U13, U10 and UX-331. The recommendation hasn't changed: run the §7 test after this run, then decide.

### Packages, in run order

#### P45 · Tab labels fit at 320 dp; tab icons match their screens · D · S · after P28
- **UX-427** (S2; R1D-1) on phones under about 348 dp with text at 1.2× or more, the start tab reads "Calendari" with "o" on a second line → no inherited letter spacing, and under 360 dp the labels stop growing at 1.2× (14.4 px, no smaller than before P28). U13's two tabs remain the lasting fix.
- **UX-428** (S1; R1D-2) the tabs now show a check box and a page, but Tareas and Notas still show the old list icons → the screens use the tabs' icons.

#### P46 · Search keeps matching while you type; empty search does no work · C · S · after P11
- **UX-425** (S1; R1C-1) typing "col·" shows "No hi ha tasques que coincideixin" for one keystroke → "·" and "ŀ" fold one letter at a time, and "col." searches as "col".
- **UX-426** (S1; R1C-2) with nothing typed, every task change re-folds the text of every task and note → an empty search matches at once, without folding.

### Seen in passing, added to the main batch
Reviewer C noted three older problems that P11 didn't cause. Each is now in `ISSUES.md`, with a severity I set, and in the `plan.json` package that already edits its file:
- **UX-429** (S2) → **P24:** the "Todos los proyectos" sheet is a fixed 70% of the screen and leaves no room for the keyboard; at 2× text the first match is already below the fold → the sheet stays above the keyboard. Inferred; it needs a phone.
- **UX-430** (S1) → **P26:** a Proyectos search that matches nothing shows blank space → "No se han encontrado proyectos".
- **UX-431** (S1) → **P18:** the time-zone search ignores accents, so once zones show as cities, "Bogotá" finds nothing → it uses the same search as the rest of the app.

Say if you'd rather leave any of them out.

### Escalated
None: no finding has failed twice.

## Round 3 (trial)

Round 2 ran P45 and P46: the reviewer found UX-425, UX-426, UX-427 and UX-428 fixed (UX-426 and UX-427 still need their phone checks), the round check passed, and no test failed. P45 caused one small regression, now UX-432.
Round 3 is one small package, P47, and nothing is escalated.

The brief is in `plan-trial-r3.json`.

### Packages, in run order

#### P47 · Tab tooltips follow the phone's text size again · D · S · after P45
- **UX-432** (S1; R2D-1) on phones narrower than 360 dp, long-pressing a tab to read its name bigger shows it at 16.8 px instead of up to 28 px at 2× text → only the label stops growing at 1.2×, and the tooltip follows the phone's text size again. The labels look exactly as they do now; U13's two tabs will remove this stopgap.

### Seen in passing, added to the main batch
The reviewers noted two older problems that round 2 didn't cause. Each is now in `ISSUES.md`, with the reviewer's severity, and in the `plan.json` package that already works on its file:
- **UX-433** (S1) → **P23:** the line meant to separate the tab bar from the screen has never shown, because the bar paints over it; the only edge is a faint change of tint (1.07:1 in light, 1.11:1 in dark) → the line is drawn in front of the bar. The reviewer suggested pairing it with UX-432, but this round only re-plans what failed. Say if you'd rather have no line; then the unused border goes instead.
- **UX-434** (S1) → **P16:** search treats ' and ’ as different, so "l'escola" doesn't find "l’escola", which an iPhone types → both count as the same. Whether saved text really carries ’ needs an iPhone to check.

### Added to P35
- The capture page's "Revisar nota" button still shows the old notes icon (`voice_task_screen.dart:953`), the last one UX-428 left behind; no package named it. P35, which replaces that page, now checks that it's gone, and that anything in the sheet that stands for a note uses the Notas tab's icon.

### Escalated
None: no finding has failed twice.

## Round 2 (b1)

Round 1 of batch 1 ran P31, P1, P8, P32 and P33. The round check failed on one test: the reminder question takes nearly the whole screen on a small phone with large text (UX-401, partly fixed, first failure). The reviewers also found four regressions, now UX-435 to UX-438.
Round 2 has three packages: P48 (S4), P49 (S3) and P50 (S1). There are no new decisions and nothing is escalated.

The briefs are in `plan-b1-r2.json`.

### Packages, in run order

#### P48 · Reminder question moves into the list, with copy for cold start · D · M · after P32
- **UX-401** (S4; partly, failed once) At 320×568 with 2× text, the card in the fixed bottom bar left Calendar's agenda 16 px, and the new task was never on screen. Last attempt: a half-screen cap with scrolling inside the card. Now the card leaves the bottom bar and becomes the last item of the Calendar, Tareas and project lists, below the tasks, so it never takes room from them. Everything else P32 did stays.
- **UX-438** (S2; R1D-1) At launch, an account that already had dated tasks sees "¿Quieres un recordatorio antes?" with nothing to refer to. Now the owner's sentence shows only when a dated task was saved in this session. Otherwise the card reads "¿Quieres recordatorios antes de tus tareas?". This keeps D2a as decided: the general sentence covers only the existing-account case that the plan added.

#### P49 · Words heard before a speech restart stay in the field · A · S · after P33
- **UX-437** (S3; R1A-1; inferred from code, needs a phone) Since P33, when the recognizer restarts after a pause, words it never finalized are dropped ("comprar pan", pause, "y leche" ends as "y leche"). Now the words on screen are kept as soon as the new attempt is ready. The fix is in Dart only, with no native change and no APK build.

#### P50 · One name for exact alarms; an honest turn-on confirmation · B · S · after P8
- **UX-435** (S1; R1B-1) The exact-alarm sheet asks for «Alarmas y recordatorios», but its button says "Permitir alarmas exactas". The button becomes "Permitir «Alarmas y recordatorios»", in the sheet and on Notificaciones.
- **UX-436** (S1; R1B-2) "Listo. Te avisaremos antes de cada tarea con hora." showed even when alarms could arrive late, and it is wrong for tasks without a time. If exact alarms are still off, the last message is now the «Alarmas y recordatorios» sentence. Otherwise it reads "Listo. Recordatorios activados.".

### Escalated
None: no finding has failed twice.

## Round 3 (b1)
No new packages. P49 and P50 passed; the only failure is UX-401, which has now failed twice and goes to the owner.

### Escalated
- **UX-401** (S4, D) Reminders off by default; nothing asks to turn them on. Tried: round 1 (P32) put the one-time question in the bottom bar, which left the agenda 16 px at 320×568 with 2× text. Round 2 (P48) put it as the last item of Calendar, the Tareas list and the empty state. At 390×844 with 1× text it ends under the bottom bar (card y 663–759, bar from y 698), and at 1.3–2× text or with several tasks it is fully below the fold, so a newcomer never sees it. Two tests fail (`reminder_ask_card_test.dart` ~150 and ~347).
  - **Recommendation:** ask once in a modal bottom sheet right after the first dated task is saved and shown, then delete the in-list card. Replace the literal :139–180 test with the tester's looser one (the task can be tapped at launch; both answers can be tapped). This is only a new way to show the D2a question, not a new setting, but it is an interruption, so it needs your approval.
  - Round 1 device checks are still pending.

### Regressions
None.

## Round 2 (b2)

Round 1 of batch 2 ran P51, P3, P35, P6, P7 and P12. The round check failed on 5 new tests: UX-202 at 1.3× Spanish text (light, dark) and UX-308 at 2× text on 320 dp (es, ca, en). Both findings are partly fixed, first failure. The reviewers also found nine regressions; two of them are the same problem (R1D-1, R1B-1), so they become eight lines, UX-439 to UX-446.
Round 2 has four packages: P52 (S3), P53 (S3), P54 (S2) and P55 (S2). There are no new decisions and nothing is escalated.

The briefs are in `plan-b2-r2.json`.

### Packages, in run order

#### P52 · Calendar: room for today's tasks at large text, and three small fixes · B · M · after P6, P7
- **UX-202** (S3; partly, failed once) At 1.3× Spanish text the second task still ends under the buttons (y 639 against 590). Last attempt removed five things but left the month line wrapping (`octubre de 2026` / `Semana ▾`) and a 26 dp gap above "Agenda de hoy". Now the month shows without the year in the current year (`octubre`), the gap becomes 12 dp, and an empty project filter takes no space: about 52 dp for the 49 needed. P38 later removes the second creation button, which frees another 60 dp.
- **UX-446** (S1; R1B-4) TalkBack reads the view switcher as "Mostrar menú". It gets the name "Cambiar vista".
- **UX-442** (S2; R1B-2) The events error line says "Actualiza" but opens calendar choice. Now tapping it tries again, and it reads "No se pudieron leer los eventos. Toca para reintentar.".
- **UX-445** (S1; R1B-3) One tile showed dates in two formats (`vie, 16 oct` and `12 oct`). Deadlines now use the weekday format too.

#### P53 · Tareas heading never overflows; shared projects look shared in the picker · C · S · after P12
- **UX-308** (S3; partly, failed once) The 2× / 320 dp test overflowed. The reviewer showed the test measured a placeholder font (with the app's real font the row fits), but the two buttons sat in a Row that can't wrap. Now they sit in a small Wrap, and the test loads the real font.
- **UX-443** (S2; R1C-1) A project shared person by person looked private in the project sheet. Every shared row now has a subtitle: the group name, or "Compartido".

#### P54 · Capture sheet: Seguir only after a pause; honest TalkBack; shorter hint · A · S · after P35
- **UX-440** (S2; R1A-1) "Seguir" showed next to "Listo" on shared and typed text that never listened. It now shows only after a pause, or on a resumed voice capture.
- **UX-441** (S2; R1A-2) TalkBack said "Listo" when the person cancelled or chose to type. It now says "Listo" only on Listo, "En pausa" on interruptions, and nothing on Cancelar or Escribir.
- **UX-444** (S1; R1A-3) The English silence hint was cut at 2× text. It becomes "Still listening. Tap Done when finished.".

#### P55 · The reminders question waits until the save message is gone · D · M · after P51
- **UX-439** (S2; R1D-1, alias R1B-1) The one-time reminders question opened 300 ms after the first dated save and hid the "Añadida al …" message, its Deshacer and the landing highlight. It now waits for the message to close, and isn't asked if the person tapped Deshacer or opened another screen in the meantime; the next dated save asks instead.

### Escalated
None: no finding has failed twice.

### Skipped
- **R1B-1**: the same problem as R1D-1; both are UX-439 (P55).

### Noted, not planned
- U6's server half (the speech-only instruction in `Backend/core/ai.py`) stays open as server-side.
- UX-401 (P51) was found fixed in code; its line moves at close, with its phone checks.

## Round 3 (b2)

Round 2 of batch 2 ran P52, P53, P54 and P55. The reviewers found all ten findings fixed: UX-202, UX-308, UX-439 to UX-446. Several still need their phone checks. The round check passed and no test failed. P52 and P55 caused three small regressions, now UX-447 to UX-449.
Round 3 has two small packages: P56 (S2) and P57 (S1). There are no new decisions and nothing is escalated.

The briefs are in `plan-b2-r3.json`.

### Packages, in run order

#### P56 · The reminders question skips replaced messages and tab switches · D · S
- **UX-448** (S2; R2D-1, regression from P55) The person ticks or moves a just-saved dated task within about 4 s. Their new message replaces the save message, and the question opens at once over `Tarea completada · Deshacer`. Now the question goes ahead only when the save message timed out or was swiped away. When another message replaced it, the next dated save asks instead.
- **UX-449** (S1; R2D-2, regression from P55; needs a phone) The person saves on Calendario, then switches to Notas within about 4 s. The question opens over Notas, because tabs aren't screens of their own. Now the shell counts tab switches, and a switch since the save skips the question until the next dated save.

#### P57 · Calendar events retry keeps its line and shows progress · B · S
- **UX-447** (S1; R2B-1, regression from P52) Tapping `Toca para reintentar` collapsed the line, so the content jumped, and a quick failure looked like nothing happened. Now the line stays in place with a small spinner instead of its icon until the retry settles. There is no new text.

### Escalated
None: no finding has failed twice.

### Skipped
None.

### Noted, not planned
- UX-202, UX-308, UX-439 to UX-446 were found fixed in code. Their lines move at close, with their phone checks.
- From the D verify note, not counted: with a long Android "Time to take action" the question comes late (accepted in P55). A stray tap on the scrim as the question appears counts as asked. Watch for it on the phone check.

## Round 2 (b3)

Round 1 of batch 3 ran P58, P19, P36, P37, P9 and P16. The round check failed on one test: on Tareas the new task is highlighted but never scrolled into view (U5, partly fixed, first failure). The reviewers also found eight regressions, now UX-452 to UX-459.
Round 2 has four packages: P59 (S3), P60 (S3), P61 (S2) and P62 (S1). There are no new decisions and nothing is escalated.

The briefs are in `plan-b3-r2.json`.

### Packages, in run order

#### P59 · Tareas scrolls the new task into view · A · M
- **U5** (S3 package; partly, failed once) Calendar, the two-day batch and the pending list land correctly. On Tareas the filter switches to `Todas` and the row is highlighted, but it stays below the visible list (y 676–799 against 650). Last attempt called `showOnScreen` inside the NestedScrollView, which moved nothing. Now `_reveal` measures the row against the visible list and moves the header and the list itself, as Calendar does.

#### P60 · Capture result: a visible Cancelar, and a safe Volver a decirlo · A · M
- **UX-456** (S3; R1A-1, regression from P36) `Volver a decirlo` sat flush under `Añadir…` and threw the result away at once. Now the old result is kept until the new words are understood, `Cancelar` while listening again brings it back with its edits, and there is a 12 dp gap.
- **UX-457** (S2; R1A-2, regression from P36) The result had no visible way out. A `Cancelar` button joins `Volver a decirlo` in one row; it closes the sheet and keeps the capture in the pending list.
- **UX-458** (S1; R1A-3, regression from P36) TalkBack read the date line as just `Hoy`. It now reads `Fecha y hora: Hoy`, with no visible change.

#### P61 · Date sheet: Listo shows why it waits; Sin fecha moves at once; honest labels · B · M
- **UX-452** (S2; R1B-1, regression from P9; needs a phone) With the keyboard up, Listo with no a. m./p. m. seemed to do nothing, because the error was off-screen. Now Listo drops the keyboard, scrolls to the chips and the error, and TalkBack reads the error.
- **UX-453** (S2; R1B-2, regression from P9) When moving a task, Hoy and Mañana applied at once but Sin fecha needed Listo. Now Sin fecha applies at once too, with Deshacer.
- **UX-454** (S1; R1B-3, regression from P9) The series help line named an Inbox button that no longer exists. It now names `«Sin fecha»` / `No date` / `«Sense data»`.
- **UX-455** (S1; R1B-4, regression from P9) The repeat sheet confirmed `No se repite` with `Guardar repetición`. It now says `Listo`, like the date sheet, and `keepRepeat` is removed.

#### P62 · Notes: a new note that isn't in view doesn't move the list · C · S
- **UX-459** (S1; R1C-1, regression from P16) When the search or a view-only project hides the new note, the list jumped to the top and showed nothing. Now it stays put. The brief corrects the reviewer's suggested check (whether the row's widget exists), which would also have stopped the normal landing after scrolling down; it decides from the filtered list instead.

### Escalated
None: U5 has failed once.

### Skipped
None.

### Noted, not planned
- UX-450, UX-110, UX-116, UX-117, UX-113, UX-124, UX-127, U4, UX-304, UX-313, UX-312, UX-323, UX-337, UX-434, UX-206, UX-212 and UX-221 (P9's part; its typed-time chips are P38's) were found fixed in code. Their lines move at close, with their phone checks (U4: UX_REVIEW §7 task 1; UX-434: an iPhone apostrophe).
- From the A verify note, not regressions: the title shows twice on an expanded batch card, and `Borrador retirado` / `borradores` is jargon. Both predate this round.
- From P19's implementer: with every draft removed, `reviewKeepDraft` still shows under `Terminar`, and the header still reads `Lista para cuando tú quieras` over `No queda nada por revisar`. The header is U11/D6; not planned this round.
- From the B verify note: tapping the chip for the day a task is already on closes the sheet with "Movida al <same day>"; harmless and undoable.

## Round 3 (b3)

Round 2 of batch 3 ran P59, P60, P61 and P62. The reviewers found UX-452 to UX-459 fixed (UX-452 and UX-456 to UX-458 still need phone checks). U5 is only partly fixed and has now failed twice, so it is escalated. The round check failed on one test, U5's animations-off case. No existing test broke. The reviewers found four regressions, now UX-460 to UX-463. UX-460 is U5's remaining part and is escalated with it.
Round 3 has two small packages: P63 (S2) and P64 (S1). One question goes to the owner: whether to allow a third attempt at U5.

The briefs are in `plan-b3-r3.json`.

### Decision for the owner
- **U5 + UX-460: may the loop try U5 a third time?** On Tareas the new task now scrolls into view: with animations on, at 2× text, and when it's already showing. With Android's "Remove animations" on, it ends with 47 of its 123 px under the `Añadida…` message. Recommendation: allow one narrow attempt in `home_screen.dart` only. The space kept free for the message would be the message's final height (its box height minus 8), not where it sits mid-slide, with still one correction at most. The failing test `U5: with animations off…` stays the acceptance, unchanged. This is a technical fix, not a product change. Until it lands, the round check keeps failing on that one test.

### Packages, in run order

#### P63 · Cancel while understanding said-again words brings the result back · A · M
- **UX-461** (S2; R2A-2, regression from P60) After `Volver a decirlo`, Cancelar or Back during `Entendiendo…` closed the sheet and kept both the old and the new capture pending. Now it brings the previous result back with its edits, as it already does while listening. The new words still being understood are thrown away when that step finishes. Last attempt (P60) checked for the previous result only after the processing branch. The brief also warns that awaiting the stop would wait for the new result.
- **UX-462** (S1; R2A-3, regression from P60) While saving, TalkBack didn't say the date line is disabled. The line's Semantics now carries `enabled`. Nothing changes on screen.

#### P64 · Moving: Sin fecha closes the sheet even with an empty hour · B · S
- **UX-463** (S1; R2B-1, regression from P61) With `Añadir hora` on and the hour empty, `Sin fecha` in `Cambiar fecha` needed two taps, and nothing on screen said why. Now the hour is checked only when a time is kept.

### Escalated
- **U5** (with **UX-460**): failed in P37 (`showOnScreen` moved nothing) and in P59 (measured landing works, except with animations off). See the decision above. Calendar, the two-day batch and the pending list landings are verified.

### Skipped
None.

### Noted, not planned
- UX-452 to UX-459 were found fixed in code. Their lines move at close, with their phone checks (UX-452: the keyboard drops and TalkBack reads the error; UX-456: a one-handed mis-tap; UX-458: real TalkBack speech).
- From the C verify note: on Notas filtered to a view-only project, `Nueva nota` saves to Personal and says only `Nota guardada`. It belongs with P38's `Añadir nota` and UX-314, not this round.
- From P59's implementer: when the row isn't built yet, the build-out loop's first `innerController.jumpTo(0)` collapses the header completely. It goes to the owner with U5.
- From P60's implementer: at 320 dp, with text up to 1.28×, Spanish `Volver a decirlo` may wrap inside its row. The reviewer saw no overflow at 2×.

## Round 2 (b4)

Round 1 of batch 4 ran P65, P66, P38, P39, P40, P10 and P42. The reviewers found 17 of 18 findings fixed in code, several still needing phone checks (U5, UX-460, U8, UX-102, UX-106, UX-114, U7, UX-451, UX-208). UX-103 is partly fixed, first failure. The round check passed and no test failed. The reviewers found nine regressions, now UX-465 to UX-473.
Round 2 has four packages: P67 (S3), P68 (S2), P69 (S2) and P70 (S2). There are no new decisions and nothing is escalated.

The briefs are in `plan-b4-r2.json`.

### Packages, in run order

#### P67 · Capture sheet: messages name what's on screen; slow is spoken · A · M
- **UX-103** (S3; second attempt) Two error messages said `Toca Seguir` where `Seguir` isn't shown. Last attempt (P40) used the copy its brief gave: a 422 on recorded audio left only `Reintentar`, which resends the same silent audio, and a stop with no words shows `Empezar a hablar`. Now: `No te he entendido. Vuelve a intentarlo o escríbelo.` and `Se ha dejado de escuchar. Puedes volver a hablar o escribir.`, which name no button. After a 422 on audio the silent capture is dropped and `Empezar a hablar` shows. A 422 on typed text shows the general `No ha funcionado…` instead.
- **UX-467** (S2; R1A-3, from P40) After 8 s, TalkBack now says `Está tardando más de lo normal.` when `Guardar tal cual` appears.
- **UX-468** (S2; R1A-4, from P39) When typed words are understood on the phone, the hint is a one-task example, `Médico el viernes a las 17:00`. The three-part example stays for voice, where the assistant splits it.
- **UX-469** (S1; R1A-5, from P40) After a failure, `Reintentar` and `Guardar tal cual` are always stacked full width, so the Spanish and Catalan labels don't wrap at 360 dp.
- **UX-470** (S1; R1A-6, from P39) ES `Dictar una tarea es parte de TaskFlow Pro. Puedes escribirla aquí.` / CA `Dictar una tasca forma part de TaskFlow Pro. La pots escriure aquí.` When the free tier's app side is built, this line becomes the "free dictations used up" line.

#### P68 · The phone's time question gets its line · A · S
- **UX-465** (S2; R1A-1, from P38/P40) A result made on the phone with `a las 5` showed `05:00 / 17:00 / Sin hora` with no question and a disabled save button. Now `¿A qué hora?` (`What time?` / `A quina hora?`) sits above the chips, like the assistant's question.

#### P69 · From the timeline, the saved task lands where it can be seen · A · M
- **UX-466** (S2; R1A-2, from P38) A task added from a day's timeline was highlighted on the Calendar hidden underneath. Now, if it's on the timeline's day, the timeline scrolls to it and highlights it. Otherwise the app goes back to Calendar, which selects its day (or `Sin fecha`) and highlights it, as after the pending list. No new strings.

#### P70 · Task detail: every row answers, taps are spoken, Save offers Undo · B · S
- **UX-471** (S2; R1B-1, from P10) Duración, Fecha límite, Repetir and Prioridad now open the edit form, like the date and time rows next to them.
- **UX-472** (S1; R1B-2, from P10) The title and the tappable rows tell TalkBack what a tap does (`Cambiar fecha`, `Editar tarea`, `Editar nota`), using existing strings.
- **UX-473** (S1; R1B-3, from P42) `Guardar` in the edit form now shows `Cambios guardados · Deshacer`, the same as Back.

### Escalated
None.

### Skipped
None.

### Noted, not planned
- P42's implementer: deleting a task on the server (a tombstone) deletes its attachments for good, so Undo can't revive them if the deletion syncs within the undo window. The cause is server-side (`Backend/core/task_views.py` `update()` → `delete_task_attachments`), and it belongs to UX-208's phone check.
- P38's implementer: the free tier (DECISIONS.md, 2026-10-13 late) replaces D4a. Today voice is Pro-only (`_voice`, `local: !_voice`). The free tier changes those two lines outside this loop. P67's hint follows the same flag.
- P40's implementer: without a connectivity package, offline versus unreachable is guessed from the socket error. Check it on the phone with airplane mode (U7's phone check).
- P10's implementer changed `integration_test/notes_flow_test.dart:241` (the ✏ tooltip is gone). It was analyzed but not run.
- P66's implementer: Cancelar in the short native-stop window (up to about 4 s) still waits for the recognizer. That wait is local, not the server.
- Reviewer B: Back with an emptied title stays in the form (D12, as designed); the attachment panel and project chip can appear a moment late; `deleteTaskError` says "tarea" for a note, which it already did before. None is planned this round.

## Round 3 (b4)

Round 2 of batch 4 ran P67, P68, P69 and P70. The reviewers found all ten findings fixed in code: UX-103, UX-465 to UX-473. UX-103, UX-466, UX-467, UX-469 and UX-472 still need phone checks. The round check passed and no test failed. Reviewer B found one regression from P70, now UX-474.
Round 3 has one small package, P71 (S1). There are no new decisions and nothing is escalated.

The briefs are in `plan-b4-r3.json`.

### Packages, in run order

#### P71 · Edit form: Save on an untouched form just closes · B · S
- **UX-474** (S1; R2B-1, regression from P70) With nothing changed, `Guardar cambios` wrote the same task and showed `Cambios guardados · Deshacer`, and Deshacer undid nothing. Back on the same form just closed. Now `_save` checks for an unchanged form right after validation, so both Back and `Guardar cambios` simply close it: nothing is written and no message shows. Last attempt: P70 removed `_save`'s `undo` flag as its brief asked, but the unchanged check stayed only in `_back`. No new copy.

### Escalated
None.

### Skipped
None.

### Noted, not planned
- UX-103 and UX-465 to UX-473 were found fixed in code. Their lines move at close, with their phone checks: real silence gives `No te he entendido…` then `Empezar a hablar` and nothing new in Pendientes (UX-103); TalkBack says `Está tardando más de lo normal.` at about 8 s (UX-467); in Catalan at 360 dp, `Torna-ho a provar` and `Desa-ho tal com està` each fit on one line (UX-469); from a timeline, a task added for another day is lit on Calendar (UX-466); TalkBack reads the date row as a button with `Cambiar fecha` (UX-472).
- P67's implementer: the Catalan typing hint uses `Metge divendres a les 17:00`, the brief's fallback, because the phone's parser leaves a stray `h` in the title for `17 h`. The reviewer accepted it. `examplePlan` keeps `17 h` for voice, which the server understands.
- P67's implementer: when a widget reopens capture with `startListening: voice`, a silent capture is dropped and listening starts at once, which clears the `No te he entendido…` line. The person asked to speak, so it was left.
- Reviewer A, for U5 (not a regression): at 390×844, Calendar's lit `Bandeja · 1` row sits almost entirely under `Tarea guardada en la bandeja de entrada`, because Calendar's content is too short to scroll it clear. It also happens from the pending list, so P69 didn't cause it, but it contradicts U5's "Calendar lands (verified)". Suggested fix: while a landing is active, give Calendar's scroll content a bottom inset of at least the message's height + 8 dp, the same idea UX-460 uses for Tareas. It goes with U5 and UX-460, not this round.
- Reviewer B: the detail rows' ripple is a rectangle inside the rounded card (no `borderRadius`), the same as P10's date rows. Polish only.

## Round 2 (b5)

Round 1 of batch 5 ran P72, P13, P14, P15, P17 and P18. The reviewers found 20 of 22 findings fixed in code. UX-475, UX-305, UX-306, UX-301, UX-402, U14, UX-120 and UX-406 still need phone checks. UX-326 and UX-422 are partly fixed, and each has failed once. The round check passed and no test failed. Reviewers C and D found seven regressions, now UX-476 to UX-482.

Round 2 has three packages: P73 (S3), P74 (S2) and P75 (S2). There are no new decisions and nothing is escalated. UX-326's remaining part is server-side, so it isn't re-planned.

The briefs are in `plan-b5-r2.json`.

### Packages, in run order

#### P73 · Removing a project closes its page; delete and Share say what's true · C · M
- **UX-476** (S3; R1C-1, from P13 and P15) Deleting or leaving a project from its own page's Compartir / Miembros popped only the sharing screen. That left the user on an empty `Proyecto` page that asks them to add a task. Now the sharing screen pops with a result, and the project page closes too. `Proyecto eliminado` or `Has salido de {name}` shows on Projects, the group page or Calendar.
- **UX-477** (S2; R1C-2, from P15) Unshared projects get their own confirmation: `¿Eliminar «{name}» con todas sus tareas, notas y archivos? No se puede deshacer.` On the sharing screen, the button reads `Eliminar proyecto` unless the project is shared.
- **UX-479** (S2; R1C-4, from P13) Projects ⋮ says `Compartir` only to the owner or a group admin. Everyone else sees `Miembros`, the same word as the project page.

#### P74 · Join dialog stays open while joining; a wrong code stays put · C · M
- **UX-478** (S2; R1C-3, from P14) Unirme now shows a spinner inside the dialog until the project is loaded, and the other buttons are disabled. An error appears under the code field, and the code is kept. A wrong code reads `Pide a quien te invitó el código actual.` for projects and groups.
- **UX-480** (S1; R1C-5, from P14) Rechazar's confirmation button is red. The member-limit message says `anula una invitación`, matching `Anular invitación`.

#### P75 · Settings: blocked reminders say so; one sheet style; time help without "capturas" · D · M
- **UX-481** (S2; R1D-1, from P18) When the phone blocks notifications, the Recordatorios row reads `Bloqueados por el teléfono` in red, with an icon. The row checks again when the app comes back and after the Recordatorios screen closes.
- **UX-482** (S1; R1D-2, from P18) The Idioma sheet now uses the same radio rows as Apariencia, with no close X. "Follow the phone" is `Como el teléfono` in both sheets.
- **UX-422** (S1; second attempt) P18's brief named only `regionalFormatsHelp`, so `timezoneHelp` kept its 31 Spanish words and `nuevas capturas`. Now it reads `Las tareas nuevas usan esta zona para entender las fechas.`, and the fallback banner says `Las tareas nuevas usarán {zone}`.

### Escalated
None.

### Skipped
- **UX-326**: the app-side copy and the `Ahora no` link are verified. Showing who sent the invitation needs `invited_by_name` in the invitation payload (Backend/core/list_views.py:33-35, group_views.py:52-54). The cause is server-side. It stays open.

### Noted, not planned
- Reviewer C: after `Ahora no`, the stored link reopens the review on every cold start until the user joins or declines. Watch for it on the phone walkthrough.
- Reviewer C: deleting an empty group closes the group page with no message. This is outside UX-340's scope and pre-existing.
- Reviewer C: in ES and CA, `sharingProblem` still uses feminine pronouns left over from "lista" (`si ya no la necesitas`, `Actualízala antes de eliminarla`). This is pre-existing.
- Reviewer D: the sign-in password validator still applies the 12-character creation rule (login_screen.dart:491-494). A short everyday password never reaches the error that offers the create button. Candidate for the ledger; not a regression.
- Reviewer D: in create mode, the email-in-use error offers no `Iniciar sesión con este correo` button.
- Reviewer D and P18's implementer: legacy time-zone ids (`US/*`, `Canada/*`, a second `Buenos Aires`) appear twice, and city names are English, so `Londres` finds nothing.
- P18's implementer: App/docs/LOCALIZATION.md still says the language picker is also under Hora y región.
- P72's implementer: Tareas' `_messageClearance` (P65) measures the SnackBar box, which grows from height 0 under M3 floating. Calendar measures the inner Dismissible. Tareas was left as it is.
- P13, P14 and P18 changed integration tests that can't be run here (sharing_flow_test, projects_flow_test, regional_flow_test, reminder_language_test). They were checked only by the analyzer.

## Round 3 (b5)

Round 2 of batch 5 ran P73, P74 and P75. The reviewers found all eight findings fixed in code: UX-476, UX-477, UX-478, UX-479, UX-480, UX-481, UX-482 and UX-422. UX-476, UX-478 and UX-481 still need phone checks. The round check passed and no test failed. Reviewer D found one regression from P75, now UX-483.

Round 3 has one small package, P76 (S1). There are no new decisions and nothing is escalated.

The briefs are in `plan-b5-r3.json`.

### Packages, in run order

#### P76 · Tapping the current choice closes the Idioma and Apariencia sheets · D · S
- **UX-483** (S1; R2D-1, from P75) Idioma now uses radio rows and has no close X, so tapping the language already chosen did nothing: RadioListTile ignores taps on the checked row. Apariencia already behaved this way. In both sheets, the rows become `toggleable`. A tap on the current choice closes the sheet and saves nothing. No copy changes.

### Escalated
None.

### Skipped
None.

### Noted, not planned
- Reviewer D: Idioma lists `Como el teléfono` first, while Apariencia lists it last. This was already so before P75. If the owner wants the two sheets fully alike, move `ThemeMode.system` to the top of Apariencia.
- Reviewer D: `regionalSettingsHelp` still says `zona de captura` / `capture timezone`, but no Dart code uses it. Remove the unused key as housekeeping. Users don't see it.
- Reviewer C: a deleted project's sharing button may briefly show the shared wording while the page closes, because `taskListsProvider` is invalidated. Reviewer C and P73's implementer both judged it invisible in practice.
- Reviewer C: `expired` and `accepted` invitation errors now sit under the code field with Unirme still active, as P74's brief asked. Cancelar is visible.
- P74's implementer: the code field's `errorMaxLines` is now 12, so the longest ES/CA errors (`networkKept`) fit at 2× text. The join dialog no longer closes on a tap outside it.

## Queued by the main session after batch b5 (2026-10-14)

From the b5 report's open items and reviewer notes. They go first in b6.
- **P77** (UX-484, S2, D): in sign-in mode, require only a non-empty password; in create mode, an email-in-use error offers sign-in with the email kept.
- **P80** (UX-326, S2, C): invitations name who sent them. The backend half is done (bc93848, `invited_by_name`).
- **P78** (UX-485 and UX-487, S2, C): deleting a group says "Grupo eliminado"; "Ahora no" on an invitation survives a cold start.
- **P79** (UX-486, S1, D): time-zone search knows Spanish and Catalan city names, hides the legacy `US/*` and `Canada/*` duplicates, and drops the unused `regionalSettingsHelp` key.

## Round 2 (b6)

Round 1 of batch 6 ran P77, P80, P78, P79, P20 and P34. The reviewers found 11 of 12 findings fixed in code: UX-484, UX-486, UX-326, UX-485, UX-487, UX-121, UX-119, UX-125, UX-420 and UX-115 (several still need a phone or an iOS build). U9 is only partly fixed, first failure: the first-capture privacy note is the whole four-sentence paragraph, not a small line. The round check passed and no test failed. Reviewers A, C and D found seven regressions, now UX-488 to UX-494. UX-491 is U9's remaining part.

Round 2 has six packages: P81 (S2), P82 (S2), P83 (S2), P84 (S1), P85 (S1) and P86 (S1). There are no new decisions and nothing is escalated. UX-493 has a server half that the implementer can't do (see below).

The briefs are in `plan-b6-r2.json`.

### Packages, in run order

#### P81 · Voice copy: one short privacy line in the sheet; Voz in plain words · A · M
- **U9 / UX-491** (U9 P1, second attempt; UX-491 S2, R1A-1, from P34) The sheet showed the whole `capturePrivacy` paragraph in a scrolling box that took a third of the words area and was cut mid-line. Now a new one-sentence key: `TaskFlow envía tus palabras por internet para convertirlas en tareas. Más en Ajustes.`, as a plain two-line `bodySmall` text. The words lose their `flex: 2`. The paragraph stays on Voz only.
- **UX-492** (S2; R1A-2, from P34) Voz gets a heading over the second group, `Cómo se pasa la voz a texto`, and outcome labels: `En el teléfono, mientras hablas` / `En línea, al terminar`. The unavailable message and a new Voz-only set-up message no longer tell the user to record or type.

#### P82 · The Voz language reaches online transcription · A · M
- **UX-493** (S2; R1A-3, from P34) The app stores the speech language (e.g. `ca-ES`) with each spoken capture and sends it as `language` in the `ai/drafts/` request. The reviewer's fallback, hiding `Idioma de voz` while the online way is selected, isn't needed. It also wouldn't cover the case where on-device speech can't do the language.

#### P83 · Sign-in: the email-in-use button names itself; a known account offers recovery · D · S
- **UX-488** (S2; R1D-1, from P77) The button reads `Iniciar sesión con este correo` instead of the submit button's `Iniciar sesión`. When sign-in was reached through it and fails with wrong credentials, the offered button is `¿Has olvidado tu contraseña?`, not `Crear una cuenta con este correo`. That breaks the create → email in use → sign in → create loop.

#### P84 · An empty share says there's no text · A · S
- **UX-494** (S1; R1A-4, from P20) An empty share shows a new `share_empty`: `No hay texto que añadir. Comparte un texto con TaskFlow.` `share_too_long` is kept for over 4,000 characters.

#### P85 · Catalan: 'Grup suprimit', like the button · C · S
- **UX-490** (S1; R1C-1, from P78) CA `groupDeleted` becomes `Grup suprimit`, matching `Suprimeix` and `Projecte suprimit`. The b6 brief's `Grup eliminat` was the organizer's mistake.

#### P86 · Time-zone search shows which name matched · D · S
- **UX-489** (S1; R1D-2, from P79) When a row matched only through a Spanish or Catalan alias, the alias shows as its subtitle (`Shanghai` / `Pekín`). The aliases become lists, so multi-word names stay whole. Toronto's `Montreal` alias goes, so `montreal` lists one row.

### Server side, for the main session
- **UX-493**: the drafts serializer (`Backend/core/serializers.py`, near :295) should accept an optional `language`. `transcribe` / `_transcribe_once` (`Backend/core/ai.py:88`, :108-112) should tell the model the speaker's chosen language. The finding stays open until both halves are in and a phone confirms Catalan online audio comes back in Catalan.

### Escalated
None.

### Skipped
None.

### Noted, not planned
- Reviewer A: `captureSpeechLanguage` still says "Elige otro idioma" without saying where; the choice now lives in Ajustes › Otros ajustes › Voz. This was already so before P34, and `_load`'s pre-check makes the message rare.
- Organizer: the `capturePrivacy` paragraph that stays on Voz still uses internal terms (`extracción de tareas con IA`, `capturas pendientes`). The new sheet line points there (`Más en Ajustes`). No reviewer flagged it; consider it at the next Voz review.
- P78's implementer: the existing `_Storage` fake in invitation_review_test.dart always reads null; restart tests need a fake that stores.
- P20's implementer: the InfoPlist.strings files are now UTF-8 (accented text and ’). Xcode accepts this.

## Round 3 (b6)

Round 2 of batch 6 ran P81 to P86. The reviewers found U9, UX-488, UX-489, UX-490 and UX-494 fixed in code (U9, UX-488 and UX-494 still need a phone). UX-491 and UX-492 are partly fixed (second failure each). UX-493's app half is done and its server half is open. The round check passed and no test failed. Reviewer D found one regression, now UX-495.

Round 3 has two packages: P87 (S2) and P88 (S1). There are no new decisions and nothing is escalated. A third failure of UX-491 or UX-492 escalates it.

The briefs are in `plan-b6-r3.json`.

### Packages, in run order

#### P87 · Voice copy: a privacy line that fits; no 'type' on Voz · A · S
- **UX-491** (S2; R1A-1, third attempt) P81's two-line line was cut at 2× in Spanish before `Más en Ajustes.` The copy gets shorter: `Tus palabras van por internet. Más en Ajustes.` / `Your words go online. More in Settings.` / `Les paraules van per internet. Més a Configuració.` If Spanish or Catalan still needs a third line at 2× on 360 dp, the line allows 3 lines.
- **UX-492** (S2; R1A-2, third attempt) When Android's speech set-up can't open, Voz still said `Usa audio guardado o escribe.` A new Voz-only message replaces it: `Este teléfono no puede configurarlo, así que TaskFlow lo hace en línea.` The test fake can now fail, so the branch gets tested.

#### P88 · Sign-in: one 'Forgot password?' control, not two · D · S
- **UX-495** (S1; R2D-1, from P83) After email in use → sign in → wrong credentials, the card showed `¿Has olvidado tu contraseña?` twice. The small link hides while the recovery button shows. Nothing is added.

### Server side, for the main session
- **UX-493**: unchanged from round 2. The app now sends `language` with `ai/drafts/` for spoken captures. `Backend/core/serializers.py` (drafts serializer, near :295) and `Backend/core/ai.py` (`transcribe` / `_transcribe_once`, :88, :108-112) still need to use it. Not re-planned for the implementer, and not counted as a second failure.

### Escalated
None.

### Skipped
- **UX-493**: the rest of it is server-side (see above). It stays open.

### Noted, not planned
- Reviewer A: on the first capture, the privacy line stays through typing, processing and error states, and can stack with the 2-line hint under it. That's consistent with "for this capture", and minor.
- Reviewer A: `share_too_long` writes `4000` in Spanish and `4.000` in Catalan. Both are correct for their language.
- Organizer: on Voz, after a failed set-up, the new message repeats the second half of `onDeviceUnavailable` just above it ("…así que TaskFlow lo hace en línea"). It answers the tap, so it stays. Reconsider at the next Voz review.

## The free tier's app half, queued by the main session (2026-10-14)

The owner's free tier (DECISIONS.md, 2026-10-13 late) is done on the server (d40eae7, 8142f79). These packages run as batch b7, before the rest of the polish, because they are the owner's newest requirement. P44 moved up to run before P92.
- **P89** (UX-497, UX-499, S3, A): free accounts get the mic while dictations are left; `capture_id` and the cancel.
- **P90** (UX-498, S3, A): when free dictations run out, the words are kept and the sheet offers typing, with the reset date.
- **P91** (UX-500, S3, B): a file-space line near the cap; a refused file isn't sent again.
- **P44**, then **P92** (UX-501, S2, D): the Pro screen shows the free tier's numbers; Pro-only copy goes.

## Round 2 (b7)

Round 1 of batch 7 ran P89, P90, P91, P44, P92 and P93. The reviewers found all nine findings fixed in code: UX-496, UX-497, UX-498, UX-499, UX-500, UX-408, UX-423 and UX-501 (several still need a phone). The round check passed and no test failed. Reviewers A, B and D found nine regressions, now UX-502 to UX-510.

Round 2 has three packages, all S2: P94 (A), P95 (B) and P96 (D). One owner question is new and doesn't block anything. Nothing is escalated.

The briefs are in `plan-b7-r2.json`.

### Question for the owner
- **Finding files when the space is full** (UX-506). When a free account's file space is full, should the app help people find which tasks hold files, for example a marker on task rows or a list of files? Recommendation: not now. P95 rewords the message to say the files are on other tasks, which needs no new UI. Revisit if free users hit the cap in practice.

### Packages, in run order

#### P94 · Used-up dictations: a kept recording closes with one button; copy fixes · A · M
- **UX-502** (S2; R1A-1, from P90) A recording with no words, refused at 0 left, showed an empty typing field and only `Cancelar`, which asked "¿Conservar lo que has dicho?". Now there's no field, one FilledButton `Cerrar` / `Close` / `Tanca` that closes the sheet with the capture kept, and no dialog. Back does the same.
- **UX-503** (S1; R1A-2, from P90/P92) Catalan dates read `el dia {date}` / `a partir del dia {date}` / `Més el dia {date}`, so the 1st no longer reads "el 1 de nov.".
- **UX-504** (S1; R1A-3, from P89) `freeVoiceLeft` at 0 reads `Ya no te quedan dictados gratis este mes` (EN, CA too).

#### P95 · File space: usage refreshes after uploads; the full message says where · B · M
- **UX-505** (S2; R1B-1, from P91) After a sync where at least one upload succeeds, the account's storage is refreshed once, so the usage line appears as soon as uploads pass 80%. There's no new UI, and it can't loop.
- **UX-506** (S2; R1B-2, from P91) `storageFull` now says `Elimina archivos de otras tareas para hacer sitio…` (EN, CA too).
- **UX-507** (S1; R1B-3, from P91) The `attachments` heading becomes `Files` / `Archivos`, matching the usage line. Catalan `Fitxers adjunts` stays.

#### P96 · Account and Pro: sign-out shows progress; copy points to what exists · D · S
- **UX-508** (S2; R1D-1, from P44) `Cerrar sesión` shows the 18 dp progress indicator inside the button while signing out.
- **UX-509** (S2; R1D-2, from P44) Three billing messages no longer say "refresh". They point to reopening the screen, or to `Restaurar compras`.
- **UX-510** (S2; R1D-3) `fileUploadHelp` drops "64 MiB per account" and says `hasta 6 MB cada uno`. It no longer contradicts the Pro screen's 100 MB.

### Escalated
None.

### Skipped
None.

### Noted, not planned
- P89's implementer: an app left open across the month boundary picks up the reset on its next resume refresh.
- P90's implementer: the reset date is the first of the month in UTC, so west of UTC it can read as the last day of the month.
- P44's implementer: someone who bought Pro before but whose Pro isn't active (a lapsed subscriber) sees `Ver suscripción`, `Restaurar compras` and `Gestionar suscripción` together. That rule wasn't changed, and no reviewer flagged it.
- Reviewer D: the Google-link path's `auth.loading` lost its bottom spinner, but `_Action.google` has its own bar.
- Reviewer B: removing your own file also releases refused files in shared projects. They are re-sent once and refused again, which costs data but nothing the user sees.
- Organizer: `billingResult.updated` ("Estado de la suscripción actualizado") may now be unused, since `Actualizar estado` is gone. Check at the next Pro-screen review.

## Round 3 (b7)

Round 2 of batch 7 ran P94, P95 and P96. The reviewers found eight of nine findings fixed in code: UX-502, UX-504, UX-505, UX-506, UX-507, UX-508, UX-509 and UX-510 (UX-502, UX-505 and UX-508 still need a phone). UX-503 was partly fixed: Catalan now says `el dia {date}`, but the date's own full stop doubles the sentence's (`1 de nov..`), and ux-tester's acceptance test fails. That was the round check's only failure (929 pass, 1 fails). Reviewers B and D found two regressions, now UX-511 and UX-512.

Round 3 has three small packages: P97 (B, S2), P98 (A, S1) and P99 (D, S1). There are no new owner questions, and nothing is escalated: UX-503 has failed once.

The briefs are in `plan-b7-r3.json`.

### Packages, in run order

#### P97 · Usage refresh no longer resets the task screens · B · S
- **UX-511** (S2; R2B-1, from P95) Each upload by a free account refreshed the account, which rebuilt the task repository: task details flashed a spinner and jumped to the top, the calendar briefly showed an empty day. `taskRepositoryProvider` and `captureOwnerProvider` now watch only `account?.id`, so only the usage line repaints and the extra sync goes away. No copy change. Inferred from code; needs a phone.

#### P98 · Catalan free-dictation dates: no doubled full stop · A · S
- **UX-503** (S1; R1A-2, second attempt) Last time: `dia` was added before the date, but `freeVoiceUsedUp` and `freeVoiceStatus` still ended in `{date}.`, giving `1 de nov..`. Now the date sits mid-sentence: `…; el dia {date} en tindràs més.` and `El dia {date} en tindràs més.` Catalan only; the failing test is updated to match.

#### P99 · File size limit says 6 MB everywhere · D · S
- **UX-512** (S1; R2D-1, from P96) `fileLocalHelp`, `fileLimit` and `requestError.fileLimit` still said `6 MiB` next to P96's `6 MB`. All three now say `6 MB` in EN, ES and CA. The internal `6 MiB` text that `request_locale.dart` matches stays.

### Escalated
None.

### Skipped
None.

### Noted, not planned
- P96's implementer: the plan's grep for 'actualiza' / 'actualitza' in `billingError` / `billingResult` can't pass, because the kept `updated` and `other` branches use the verb to mean "update". Reviewer D agreed it isn't a defect. Read that check as "no instruction to refresh".
- P96's implementer: `attachment_files.dart:45` throws `Choose a non-empty file up to 6 MiB.` It never reaches the screen as-is: the task editor shows `fileLimit` for it, and `request_locale.dart:98` maps it to `fileLimit`. P99 leaves it alone.
- P95's implementer: if `_pullRemote` throws (offline) or a 401 comes back mid-upload, the storage refresh is skipped; the next successful sync with an upload refreshes it.
- Reviewer D: the sign-out, Sync and Import spinners have no `semanticsLabel`, so TalkBack hears only "Cerrar sesión, disabled". Not worse than before P96.
- Reviewer B: a code comment at `attachment_panel.dart:196` still says "Attachments section". Not user-facing.

## Round 2 (b8)

Round 1 of batch 8 ran P100, P21, P22, P23 and P30. The reviewers found all fourteen findings fixed in code: UX-513, UX-514, UX-424, UX-419, UX-215, UX-216, UX-222, UX-227, UX-225, UX-122, UX-123, UX-223, UX-224 and UX-433. Several still need a phone. The round check passed and no test failed. Reviewers B and D found three regressions, now UX-621 to UX-623.

Round 2 has two small packages: P110 (B, S3) and P111 (D, S2). There are no new owner questions, and nothing is escalated. The package numbers start at P110 because P101–P109 belong to run 2026-10-14-speed.

The briefs are in `plan-b8-r2.json`.

### Packages, in run order

#### P110 · A typed step is never lost · B · S
- **UX-621** (S3; R1B-1, from P21) In the capture result card, a step typed in `Añadir paso` and saved with `Añadir al calendario` without Enter was dropped. The save now unfocuses and waits one microtask before it reads the drafts, as TaskEditor's save does. A disabled checklist editor no longer clears typed text.
- **UX-622** (S2; R1B-2, from P21) Tapping `Más detalles` / `Menos detalles` while a step was half-typed erased it. Both checklist editors in the task form now share one GlobalKey, as the capture card's already do.

#### P111 · Sign-in again says why, keeps the email, and Back changes nothing · D · S
- **UX-623** (S2; R1D-1, from P30) Sign-in over the open screens looked like the cold-start login, had an empty email field, and pressing Back erased the only explanation. Now the email is filled in. One line replaces the sales pitch: `Tu sesión se ha cerrado. Vuelve a entrar y seguirás donde lo dejaste.` (EN, CA too). It stays on Back and while typing, and replaces the session banner below the button. Back in sign-in mode no longer clears anything.

### Escalated
None.

### Skipped
None.

### Noted, not planned
- Reviewer D (UX-623): signing in on that route with a different email still drops the kept screens without a warning. Prefilling the email makes this unlikely, and a warning would add copy nobody asked for. Revisit if it comes up in use.
- P21's implementer: the "known limit" they reported is UX-621, planned above.
- P22's implementer: the ARB key `sharedListRole` ('{role} · compartida') is unused in `lib/`. Delete it at the next copy cleanup. It was unused before P22.
- P30's implementer: on the sign-in-again route, Android Back now does nothing (before, it left the app and could lose the typed text). That's intended, and P111 keeps it.
- Reviewer B: the project row in the task form can appear one frame late if `taskListsProvider` hasn't loaded yet. In practice it's cached from Tareas, so it isn't a finding.

## Round 3 (b8)

Round 2 of batch 8 ran P110 and P111. The reviewers found UX-621 and UX-623 fixed in code (both still need a phone). UX-622 was partly fixed: the shared GlobalKey keeps a half-typed step across `Más detalles` when the task already has a step, but not on a task with no steps. The round check passed, no test failed, and there were no regressions.

Round 3 has one small package: P112 (B, S2). There are no new owner questions, and nothing is escalated: UX-622 has failed once.

The brief is in `plan-b8-r3.json`.

### Packages, in run order

#### P112 · Menos detalles keeps a first step typed without Enter · B · S
- **UX-622** (S2; R1B-2, second attempt) Last time: both checklist editors in the task form got one GlobalKey, which covers a task that already has a step. On a task with no steps, the short form has no steps section, so a first step typed inside `Más detalles` was still lost on `Menos detalles`. Now `Menos detalles` first leaves the field and waits one microtask, as saving does, so the step is committed and the short form shows it. `Más detalles` still opens at once, without closing the keyboard. No copy change. Inferred from code; needs a phone.

### Escalated
None.

### Skipped
None.

### Noted, not planned
- Reviewer B: in the short form, removing the last step through ⋮ hides the steps section, and any text in `Añadir paso` goes with it. It predates this run and is rare, so it's only noted.
- Reviewer D: on the sign-in-again route, system Back does nothing and gives no feedback. That's P30's intended `PopScope(canPop: false)`; the new reason line explains the screen.

## Round 2 (b9)

Round 1 of batch 9 ran P113, P24, P25, P26, P27 and P43. The reviewers found every finding fixed in code (UX-624 in area B; 21 findings in area C, with UX-429 and UX-321 still needing a phone). No test failed and the round check passed. Reviewer C found four small regressions on the project, group and Activity pages, now UX-625 to UX-628.

Round 2 has two small packages in area C: P114 (S2) and P115 (S1). P114 also takes one older problem that reviewer C noted in the same lines (UX-629). There are no new owner questions, and nothing is escalated.

The briefs are in `plan-b9-r2.json`.

### Packages, in run order

#### P114 · Project page says read-only only when it is, and says it once · C · S
- **UX-626** (S2; R1C-2, from P24) Right after `Nuevo proyecto`, the new page could show `Este proyecto es de solo lectura` until the projects list reloaded, because an unknown project counted as read-only. Now the page says read-only only once the project is known and the user can't edit it. Inferred from code; needs a phone.
- **UX-625** (S2; R1C-1, from P24) An empty view-only project said `Añade una tarea a este proyecto…` above a bar with no button. It now says `Este proyecto aún no tiene tareas.` (EN `No tasks in this project yet.`, CA `Aquest projecte encara no té tasques.`). One new key, `readOnlyListEmpty`.
- **UX-629** (S1; reviewer C's note, older than this run) `Para mí` on a shared project with nothing for you showed `Un nuevo comienzo`, as if the project were empty. It now shows `No hay tareas que coincidan` like any other filter.

#### P115 · Group page drops the lone role word; Activity has one name · C · S
- **UX-627** (S1; R1C-3, from P27) With the group-name headline gone, the group page opened with a lone `Editor` or `Propietario`. The line goes; the user's own row under `Miembros` already shows their role.
- **UX-628** (S1; R1C-4, from P25) The button said `Actividad del grupo` and the screen it opens said `Actividad`. The screen is now titled `Actividad del grupo` (EN `Group activity`, CA `Activitat del grup`, existing key).

### Escalated
None.

### Skipped
None.

### Noted, not planned
- Reviewer C: the sharing screen's pending list uses the uppercase `pendingInvitations` label, while the group page now says `Invitados` / `Pendiente`. Which wording both should use is a choice the reports don't settle; worth aligning in a later pass.
- Reviewer C: the group invite role sheet is titled with the email ("¿Qué puede hacer ana@…?"). The reviewer finds it acceptable.
- P27's implementer: the group invitation code dialog still uses the long version (P13 shortened only the project one), and a group's pending invitation is revoked at once with an X, without the ⋮ menu (`Reenviar` / `Anular invitación`) that project invitations got. No reviewer has reported these; the next review of the group page should look at both.
- P26's implementer: `integration_test/regional_flow_test.dart` was already stale (it looks for `Guardar lista` and `Archivar lista`) and also picks the `Azul` chip that P26 removed. Update it the next time it runs on a device. This is test upkeep, not a UX finding.
- With P114, while a new project is still unknown to the projects list, `Añadir tarea` shows but `TaskActions` gets no project id for that moment (unchanged behaviour). The reload is local and fast, so this isn't planned; the P114 device check would show it if it matters.
- Reviewer B: opening ⋮ in the steps editor commits typed text as a step even if the menu is dismissed (P112's "leaving the field keeps it"), and at the 50-step limit Save discards text still in the field after `stepLimit` has been shown. Both are noted by the reviewer as acceptable.

## Round 3 (b9)

Round 2 of batch 9 ran P114 and P115. Reviewer C found all five findings fixed in code (UX-625, UX-626, UX-629, UX-627, UX-628; verify-b9-r2-C.md). No test failed, and the round check passed. One new edge case came from P114's `readOnly` line: UX-630 (R2C-1, S1).

Round 3 has one small package in area C, P116. It fixes UX-630 in the same line. The workflow reported the five round-2 findings as not checked, so P116 lists them again for the reviewer, with no code change to them. UX-626 needs re-checking anyway, because P116 changes its fix. There are no new owner questions, and nothing is escalated.

The briefs are in `plan-b9-r3.json`.

### Packages, in run order

#### P116 · A project that's gone shows read-only again; round 2 re-checked · C · S
- **UX-630** (S1; R2C-1, from P114) If a project is still missing after the projects list has loaded (you were removed from a shared project, or it was deleted on another device), its page showed `Añadir tarea`, and the task was saved outside the project. Now, once the lists have loaded, a missing project shows the read-only line (`Este proyecto es de solo lectura`) and `Este proyecto aún no tiene tareas.` again. Inferred from code; checking it on a device needs two accounts.
- **UX-626** (S2; R1C-2) Re-checked, and its fix narrows: a project the lists don't hold yet counts as "not known yet" only while the lists are reloading, which covers the moment just after `Nuevo proyecto`. One existing test changes its starting state to match. A phone check is still needed.
- **UX-625** (S2; R1C-1) Re-check only: an empty view-only project says `Este proyecto aún no tiene tareas.`
- **UX-629** (S1) Re-check only: `Para mí` with nothing for you says `No hay tareas que coincidan`.
- **UX-627** (S1; R1C-3) Re-check only: the group page shows no lone role word.
- **UX-628** (S1; R1C-4) Re-check only: the Activity screen is titled `Actividad del grupo`.

### Escalated
None.

### Skipped
None.

### Noted, not planned
- Reviewer C's other option for UX-630 was to close a gone project's page, as the sharing screen does. It isn't planned: going back to the read-only state needs no new behaviour.
- With P116, the projects list reloads whenever tasks reload. On a gone project's page, the bottom bar can show `Añadir tarea` for the moment of each reload. The page is rare, and the reload is local, so this is accepted.
