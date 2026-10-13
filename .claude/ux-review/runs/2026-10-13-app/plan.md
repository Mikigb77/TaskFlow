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
