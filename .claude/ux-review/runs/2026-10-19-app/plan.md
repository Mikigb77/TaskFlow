# UX loop 2026-10-19-app: plan

> **2026-10-20:** approved («go, as recommended»), with D1–D10 answered as recommended. The answers are planned at the end, under «Re-plan after the owner's answers (2026-10-20)», with the batch order for all 31 packages.

**Run:** the whole app (`app`), reviewed against fresh evidence: 327 previews with their measurements (AUDIT.md) and 230 captures from the TaskFlow_Review emulator, all from today's code (3a6ad40). All four reviews say "ship after fixes": nothing blocks a core task.

**Summary.** 81 of the 94 findings are fixes, in 24 packages (P166–P189) that run in five batches; 8 come to you as 10 questions (D1–D10), and none of them holds a package back; 5 are duplicates. The five severity-3 packages go first: the microphone can't be turned back on, «No se encontraron tareas» leads nowhere, an open question's answers hide at large text, a saved task lands under its message, and a Spanish newcomer can't finish a password recovery.

**How to answer.** "go" runs every package; strike any with `skip P1xx`. Answer the questions in any order: an answer that unlocks work becomes a package with `/ux plan 2026-10-19-app`. Full briefs are in `plan.json`.

## Questions for you

### D1 · The reminder question when no reminder can come (UX-1601, S3)
- **What happens:** the one-time «¿Quieres un recordatorio antes?» comes after the first dated save. If that task is for today and saved after 9:00 (tasks without a time remind at 9:00), «Sí, recuérdamelo» ends with «Listo. Recordatorios activados.», the chip reads «Recordatorio: 9:00», and nothing ever rings. The first reminder is where trust is made.
- **Why it's yours:** it changes when D2a asks, and what D2b gives a task saved after its default time.
- **Recommendation:** (a) ask only after a save whose reminder can still fire, otherwise wait for the next dated save; (b) keep one default and no new rule: such a task gets no reminder, and its chip stops promising «9:00». If you'd rather it reminded later that day, say when (an hour after saving, or 18:00). The today-after-9:00 case is inferred from code; it needs a phone check.

### D2 · Sign-in's first screen (UX-1603, S2)
- **What happens:** the only filled button submits email and password; Google, 2 taps to Calendar, is a white outlined button above an «o». 10 tap targets and two choices at once (Google or email; sign in or create).
- **Why it's yours:** it changes the sign-in layout you chose in D8.
- **Recommendation:** yes, fold the email fields behind «Continuar con mi correo» / “Continue with email” / «Continua amb el correu» under «Continuar con Google»: 10 → 5 targets, 2 → 1 decisions; email users tap once more. If you want the fields always visible, the email button becomes tonal instead, so Google is the one filled button. P170 fixes the rest of sign-in now either way.

### D3 · Dates in shared text, and a default day in the form (UX-1623, S2)
- **What happens:** sharing «Comprar pan y leche el viernes» opens the form with no day; Back saves it to Sin fecha with «el viernes» in the title, and no reminder. A task typed from Calendar's today without tapping a day also goes to Sin fecha.
- **Why it's yours:** your 2026-10-18 rules read dictated words for dates (D2) and leave typing as typed; shares fall between the two. It's been with you since 2026-10-18 as «a default day in the form».
- **Recommendation:** read the day and time in shared text, as D2 does for dictated words (they're someone else's words), and keep the form's empty default otherwise (D9). Optional, from review B: with no day chosen, the form's button says «Añadir sin fecha».

### D4 · Should a dictation with nothing found use a free dictation? (UX-1624, S2)
- **What happens:** it counts, because the assistant answered (your 2026-10-13 rule). A newcomer's «Hola, ¿esto funciona?» costs 1 of 10.
- **Why it's yours:** the free tier's counting.
- **Recommendation:** don't count answers with no task and no command. It's a server change (main session). P167 makes that answer offer «Volver a decirlo» either way.

### D5 · A way to change your name (UX-1515, with half of UX-1612; S2)
- **What happens:** a password account is asked its name once. «Ahora no», a typo or an unaccented «Maria» is final: everyone in the project then sees the email prefix or the typo, and nothing in the app shows or changes it. Google accounts can't change Google's name either.
- **Why it's yours:** it adds a control (D8 asks once). Reviews C and D both raise it.
- **Recommendation:** yes, one row in Cuenta: «Nombre · María», or «Añadir tu nombre» without one, opening the existing name sheet. P189 already puts the name where Cuenta's slogan is.

### D6 · Group invitations without a role step (part of UX-1513, S2)
- **What happens:** D15b took the Editor/Viewer choice out of the project invite; the group invite still asks Editor, Lector or Administrador before sending.
- **Why it's yours:** whether D15b covers groups.
- **Recommendation:** yes: everyone joins as editor, and the role changes on the person's row, Administrador included (SH-5). P181 already makes the rest of the group invite match projects.

### D7 · Phone calendars after connecting (the default in UX-1611, S2)
- **What happens:** after «Conectar» and Android's «Permitir», no calendar is ticked, so Calendar shows no event and every day says «Elige calendarios para mostrar tus compromisos existentes.».
- **Why it's yours:** a new default for what the app shows.
- **Recommendation:** show every calendar, with «Conectado. Los eventos se ven en Calendario.» (CO-6). P188 fixes the rest of that screen now.

### D8 · The launcher icon (UX-1608, S2)
- **What happens:** Android draws it small inside a white disc: an «M» on a dark badge, next to Gmail's «M» in the dock. Inside, the app's mark is a teal square with a double tick.
- **Why it's yours:** the brand mark.
- **Recommendation:** an adaptive icon drawn from the in-app mark, with a themed-icon layer, so it's one mark everywhere. Either way it stops being a small disc.

### D9 · The Catalan «Configuració» tab label (UX-421, S1)
- **What happens:** it waits for U13. New: at 1.3× and up it also breaks mid-word on 360 and 393 dp phones («Configuraci / ó»), not only below 360 dp.
- **Why it's yours:** UX-421 is tied to U13.
- **Recommendation:** extend today's below-360 dp stopgap (the label stops growing at 1.2×) to any phone where it doesn't fit, until the two tabs come.

### D10 · Reminder titles on the lock screen (UX-1625, S1)
- **What happens:** reminders show the task's title on the lock screen on most phones.
- **Why it's yours:** privacy (NO-9).
- **Recommendation:** keep it: a reminder is meant to be read at a glance, and Android's own lock-screen setting can hide sensitive content.

## Already with you (new evidence, not asked again)
- **U13, two tabs.** At 2.0 text on the emulator, Calendar shows 2 tasks and Tareas 1. Tareas' «Hoy» and «Sin fecha» repeat Calendar's today and its «Sin fecha · N» (review B). Review B asks whether the Día view stays (P180 makes it usable meanwhile). Review C suggests one more §7 step that needs a list, such as "What do you have with no date?". P176 tidies Tareas until you decide.
- **UX-615**, a result that saves itself: unchanged, after the §7 test.
- **The widget and voice shortcut's wording at 0 dictations left (UX-910):** unchanged; P186 only stops the labels being cut.
- **Deleting one repetition of a repeating task by voice:** unchanged.

## Packages, in order

They run one at a time, in batches of about five. Every package's full brief, acceptance checks and phone checks are in `plan.json`.

### Batch b1 — severity 3

**P166 · S3 · A · L · Microphone permission: a reason first, «blocked» on both paths, one way to Settings**
- UX-107 (S3, reopened): on the online path a second «No permitir» is never seen as blocked, so nothing leads to Settings; ask through the app's own check on both paths.
- UX-1303 (S2): while blocked, «Abrir Ajustes» is the one filled button and the banner names the steps: «Para volver a dictar, abre Ajustes y toca Permisos › Micrófono › Permitir.».
- UX-1305 (S2): one line under Android's question, «Permite el micrófono para dictar tus tareas. Solo escucha mientras dictas.»; after a refusal, «Sin micrófono no puedo escucharte…», naming the two buttons there.
- UX-1306 (S2): when on-device speech can't start, the sheet switches to online listening at once, as Voz promises, instead of looping on jargon.

**P167 · S3 · A · M · Nothing found: «Volver a decirlo» with an example; listening says what's true**
- UX-1301 (S3): «No he encontrado ninguna tarea. Di qué y cuándo, por ejemplo: «Mañana, llamar al dentista».», with «Volver a decirlo» filled and no «Reintentar» that repeats the same answer.
- UX-1304 (S2): «Aún no he oído nada…» before any words, a real countdown («Quedan 3 segundos»), «No te he entendido…» at a silent 60 s, and «Te escucho. Verás tus palabras al tocar Listo.» online.
- UX-1322 (S1): while «Entendiendo…», no microphone.

**P168 · S3 · A · M · The result at large text**
- UX-1302 (S3): at 2× the sheet scrolls to the open question, so «05:00 · 17:00 · Sin hora» are in view; «Ver lo que dije» leaves the pinned footer.
- UX-1312 (S2): several-task cards' day lines become 48 dp, with a chevron.
- UX-1308 (S2): TalkBack hears the result once: «Llamar al médico, vie, 23 de oct · 10:00».

**P169 · S3 · B · M · Calendar after a save, and on the way back**
- UX-1309 (S3, with UX-1401): saved rows land clear of the save message at any text size, and a second task saved for the same day is in view too, still lit.
- UX-1405 (S2): after 30 minutes away or a new day, Calendar opens on today, not on a day a landing chose.
- UX-1404 (S2): an empty day says «Nada previsto para este día.» once (12 words and a tile → 5).

**P170 · S3 · D · L · Sign-in**
- UX-1602 (S3, app half): «Si {email} tiene cuenta, te llegará un correo con un código. Escríbelo aquí.» above the code field, and the request says the app's language. The Spanish 6-digit email is the server's half.
- UX-1604 (S2): TalkBack reads «Inicia sesión» first, and an error alone, not the pitch and «o» before it.
- UX-1617 (S1): «Correo» whole at 2×, «Este correo ya tiene una cuenta.», links 8 dp apart, one «Crear una cuenta» button.
- UX-1507 (S2): signed out with an invitation waiting: «Tienes una invitación. Entra con el correo en el que la recibiste.».

### Batch b2

**P171 · S2 · A · L · Capture controls: one labelled layout, 8 dp apart**
- UX-1310 (S2): Pro gets the free layout: full-width «Listo», then «Cancelar» and «⌨ Escribir» (no unlabelled icon).
- UX-1311 (S2): 8–12 dp between controls that touch today, «Descartar» and «Conservar» included.
- UX-1313 (S2): typing at 2× starts at the first line (a hidden example no longer sizes the field).
- UX-1321 (S1): TalkBack names the words field, the found rows and the ✕ («No cambiar ninguna»).

**P172 · S2 · A · S · The project question**
- UX-1314 (S2): chips no longer cut at 2× («Crear «Mat…»).
- UX-1315 (S2): «Mates» offers «Matemáticas» and «Matemáticas II».

**P173 · S2 · A · M · Capture errors say what's true**
- UX-1307 (S2): six dictations in a minute say «Espera un minuto y toca Reintentar», not «inténtalo mañana».
- UX-1318 (S1): rare errors in plain words with a next step; the time-zone notice says «Madrid», not «Europe/Madrid».

**P174 · S2 · A · S · «Sin guardar» rows**
- UX-1317 (S2): each row says when it was kept («Hoy, 9:41»), not 8 fixed words.

**P175 · S2 · B · L · The week strip and TalkBack names**
- UX-1408 (S2): whole weekdays and numbers at large text («do» for «dom», «2» for «20»), 48 dp days.
- UX-1409 (S2): next month's days in the normal colour (2.22:1 today).
- UX-1410 (S2): TalkBack hears the chosen day, «hoy · 3 tareas», and arrows named «Semana anterior».
- UX-1411 (S2): each tab announces its name, not «taskflow».
- UX-1412 (S2): a day tapped in Mes shows its tasks (the strip returns to Semana on that day).

### Batch b3

**P176 · S2 · B · L · Tareas shows tasks at large text**
- UX-1403 (S2, with UX-1501): a smaller «Tus tareas», «Prioridad alta» only when used, no search or chips on an empty list, chips in one row: a task in view at 2×.
- UX-1502 (S2): «Todas las tareas» goes; «Sin fecha», «Hoy», «Prioridad alta» toggle.
- UX-1406 (S2): a ticked task stays struck in place, as on Calendar, until you leave.
- UX-1407 (S2, with UX-1511): «Completadas» labelled on Tareas; a project's ✓ lists that project's (and person's) completed tasks.

**P177 · S2 · B · M · The reminder chip and its choices**
- UX-1505 (S2): «Recordatorio para Ana: …», «Sin recordatorio: proyecto silenciado / archivado» where this phone won't ring.
- UX-1413 (S2): «10 minutos antes · predeterminado» instead of «Usar valor predeterminado» (7 → 6 choices), typed times, a › on the form's row.

**P178 · S2 · B · L · Task rows**
- UX-1416 (S2): TalkBack names «Cambiar fecha»; view-only rows lose the dead circle.
- UX-1418 (S1): no «🕐 Sin hora» or «Sin fecha» filler lines, no «· 0 completadas», 12 sp priority.
- UX-1419 (S1): lit rows keep readable grey text.
- UX-1420 (S1): late tasks in lists say «· Atrasada».
- UX-1512 (S2): a project's page stops repeating its own name on every row; the assignee gets an icon and «Responsable: Ana» for TalkBack.

**P179 · S2 · B · L · A task's page**
- UX-1414 (S2): from «Tareas con archivos» the files are in view; a full-space file says one sentence and shows 4 buttons, delete last and red; «Volver a subir», not «Reintentar transferencia».
- UX-1415 (S2): notes right after the date, as in the form.
- UX-1417 (S1): the title reads «Tarea» (not «Detalles de la tar…»); ✏ and 🗑 apart.
- UX-1421 (S1): plain words in rare corners («instancia», «programación», «Revisa este valor» go).

**P180 · S2 · B · M · The Día view**
- UX-1402 (S2): it opens on the day's first task (not on an empty 00:00–06:00), without «Ir al primer elemento con hora», in plain words.

### Batch b4

**P181 · S2 · C · L · Inviting people**
- UX-1503 (S2): «¿A quién invitas a Matemáticas?» with a «Correo» field, not «Su correo»; your own address is caught before sending.
- UX-1513 (S2, parts 2–4): groups get the projects' code dialog (42 → 14 words) and ⋮ menus; the role step waits for D6.
- UX-1506 (S2): «Miembros · 3» opens «Miembros» and lists all three, «María (tú)» included.

**P182 · S2 · C · M · Invitations**
- UX-1509 (S2): an invitation that's gone offers «Cerrar», not a «Reintentar» that can't work; «Acceso · Editor» only when it isn't Editor.
- UX-1508 (S2): after joining, «Te has unido a…» shows before the name question.

**P183 · S2 · C · M · Activity and deletes answer at once**
- UX-1510 (S2): an Activity tap, a project deletion and an invitation answer at once; the sync runs behind.
- UX-1514 (S2, app half): «Paul te ha asignado: …» / «Paul ha asignado a Ana: …», once the server sends who.
- UX-1524 (S1): «Novedades» for Activity, no «colaborad», Catalan sharing words.

**P184 · S2 · C · L · A project's page and Proyectos**
- UX-1504 (S2): an archived project's page says «Proyecto archivado. Restáuralo para añadir tareas.» instead of offering «Añadir tarea» for tasks that would never show.
- UX-1516 (S2): «Nuevo proyecto» always in the project sheet.
- UX-1519 (S1): «Lo ven todos los miembros.» instead of «Visible para todos» under «Ana ▾».
- UX-1522 (S1): «Grupos» after projects, «Crear proyecto», no stray retry, «Compartido · 5 tareas y notas».
- UX-1523 (S1): «Miembros» and «Notas» side by side, apart.

**P185 · S2 · C · M · Notes**
- UX-1320 (S1): a voice note's title ends at a whole phrase («Para la reunión del cole»).
- UX-1517 (S2): the list's preview doesn't repeat the title.
- UX-1518 (S2): at 0 dictations, a typed note opens without the limit line.
- UX-1520 (S1): an empty Notas has one help text and no search.
- UX-1521 (S1): TalkBack reads a note as «Tu nota», button, «Editar nota».

### Batch b5

**P186 · S2 · D · M · Home-screen entries**
- UX-1316 (S2, with UX-1609): shortcuts «Dictar» / «Escribir» when space is short, and a widget label that stays whole at large text.
- UX-1319 (S2, with UX-1610): share messages of 50 characters or fewer, so they aren't cut.
- UX-1621 (S1): the widget, shortcuts and share messages follow the app's language, not the phone's.

**P187 · S2 · D · L · Reminders set up and stay true**
- UX-1605 (S2): after allowing, Recordatorios shows «on» at once, not «Permiso del sistema desactivado» for 8 s.
- UX-1606 (S2): «El teléfono no deja que TaskFlow te avise.» with one «Permitir avisos» button (to the notifications page, not App info); one button for exact alarms; Ajustes says «Activados · pueden llegar tarde».
- UX-1607 (S2): reminders are marked as reminders, so «No molestar» lets them through when allowed.
- UX-1616 (S1): typed reminder times; «10 minutos antes» whole at 2×.
- UX-1622 (S1): the «Alarmas y recordatorios» sheet gets «Ahora no» and «activa el interruptor y vuelve».

**P188 · S2 · D · M · Phone calendars, Hora y región, Exportar e importar**
- UX-1611 (S2, all but D7): one line before «Conectar» (63 words → 15), a line after a refusal, «Ocultar eventos» moved below the list.
- UX-1619 (S1): «Como el teléfono (Madrid)», no reassurance paragraph, sheets like Idioma.
- UX-1620 (S1): no «JSON», «CSV» or slogan; each result said once.

**P189 · S2 · D · L · Cuenta and Pro**
- UX-1612 (S2, the slogan): your name instead of «Tu propio espacio.» (the name row is D5).
- UX-1613 (S2): Pro says what it gives, «Dictados sin límite y espacio para todos tus archivos.», with «Ver suscripción» in view.
- UX-1614 (S1): Pro's buttons apart; subscribers don't see «Restaurar compras»; a store error says what to do.
- UX-1615 (S1): outlined buttons get a visible border (1.2:1 today).
- UX-1618 (S1): email addresses break only at «@» or «.».

## Settled between the reports
- **Same problem, two reports** (the first ID kept): UX-1309 + UX-1401 (landing; S3 from B), UX-1403 + UX-1501 (Tareas at large text; C's subtractions plus B's smaller headline), UX-1407 + UX-1511 (completed tasks; scoped by project and person), UX-1316 + UX-1609 (labels), UX-1319 + UX-1610 (toasts; S2 from D).
- **Completed tasks on a project page:** review B wanted a «Completadas» button beside «Notas»; review C kept the app-bar ✓, scoped. The app bar wins: a third button beside «Miembros · N» and «Notas» would wrap to a second row and push the first task down.
- **The widget at 2.0:** review A's text auto-size with review D's smaller mic. D's mic beside the label leaves too little width in a 1×1 cell; A's 14 sp maximum would have changed the widget at normal size.
- **Share messages:** A's «Texto demasiado largo. Comparte uno más corto.» (says what to do) over D's «máximo 4000 caracteres»; D's copy for the empty share; the Spanish «ya has compartido» keeps today's tense. They stay toasts.
- **«Volver a intentarlo» on Recordatorios** becomes the app's usual «Reintentar».
- **The time-zone notice in capture** names the city instead of disappearing: it warns that dates will be read in another zone.
- **The microphone check** uses the app's own bridge on both paths, rather than adding a second permission library.
- **Mes, tapping a day** switches to Semana on that day (review B's first option).
- **Catalan the organizer wrote:** «No en canviïs cap» / «No en suprimeixis cap», «Setmana següent» / «Mes següent», and «comparteix amb elles» in `groupHelp`.

## Skipped
- UX-1401, UX-1501, UX-1511, UX-1609, UX-1610: duplicates, merged as above.

## Noted, not planned
- The task row's «Prioridad Media» is in title case while the filter says «Prioridad alta» (review C's note to B, not filed; the same helper labels the form's choice chips).
- A note's result card shows the same words as title and notes (review C; UX-1517 fixes the list only).
- Tareas' search hint is cut at 2× («Buscar una ta…»); no reviewer gave copy.
- Review D's optional Ajustes subtitle «Dictados gratis: 4 de 10»: an addition nobody asked for.
- Review A's idea of showing share errors inside the app: it would add a surface.

## Notes for the main session
- **Server halves** (the loop never touches Backend/): UX-1602's recovery email in the app's language with a 6-digit code; UX-1514's `assignee_name` and `assignee_is_you` on activity items (contract in P183); UX-1307's Retry-After on the daily and quota refusals; UX-1315's matched project ids; D4 if you say yes. D14 (joining without the code for Google accounts) is still not built (review C).
- **Catalan for a native read:** «Recordatori per a {name}» (P177), «{actor} ha assignat {name}» and «Com funciona compartir» (P183), plus the organizer's Catalan above.
- **Preview suite:** the group fixtures use the role 'member', which renders English «member»; linear 2× renders overstate headline wrapping on Android 14+; INDEX.md's `listening-free` line still says «Rellenar a mano».
- **Emulator lane:** re-capture after each batch what its packages' phone checks name.
- **Phone checks not tied to a package:** SEEN #2 (a server-added task's reminder minutes late; review D suggests the reminder lease after a killed refresh), SEEN #14 (the text shortcut with launcher flags), UX-424's cold start from a reminder, and a 360 dp phone for UX-702.
- After the run, regenerate `PHONE_CHECKS.md` with `phone_checks.py`.

## Re-plan after the owner's answers (2026-10-20)

**Summary.** The owner approved this plan («go, as recommended») and answered D1–D10 as recommended (DECISIONS.md, 2026-10-20). Seven new packages (P190–P196) build six answers and the rest of UX-1602; P172, P181 and P188 take in what touches their own screen; D4 and D10 need no app change. P166–P189 still run first. The run is now 87 fixes in 31 packages and 7 batches, with no question left open.

### The answers, and where they go
- **D1 · UX-1601 (S3) → P190.** The reminder question comes only after a save whose reminder can still fire; its copy doesn't change. A date-only task for today saved after 9:00 gets no reminder, and its chip reads «Sin recordatorio: ya ha pasado la hora del aviso» instead of «Recordatorio: 9:00». That wording is the organizer's, in the chooser's own words. It also covers a timed task saved inside its lead time.
- **D2 · UX-1603 (S2) → P193.** Sign-in shows «Continuar con Google» with «Continuar con mi correo» under it, and the email form opens in place. Tap targets: 10 → 5.
- **D3 · UX-1623 (S2) → P192.** Shared text opens the form with its day and time read, as dictated words are; typed words stay as typed. Review B's optional «Añadir sin fecha» isn't part of the answer, so it isn't planned.
- **D4 · UX-1624 → no app package.** The main session changes the server. The app takes the free-dictation count from every answer the server sends, empty ones included, and never counts on the phone, so its line follows on its own.
- **D5 · UX-1515 (S2) → P194.** A row in Cuenta, «Nombre · María» or «Añadir tu nombre», opens the existing name sheet. A changed name survives Google sign-in, because the server only fills an empty name.
- **D6 · UX-1513, part 1 → folded into P181.** Group invites send «editor» with no role sheet, and the button reads «Enviar invitación». The role still changes on the person's row, Administrador included.
- **D7 · UX-1611's default → folded into P188.** A first connection ticks every phone calendar (up to 50) and says «Conectado. Los eventos se ven en Calendario.».
- **D8 · UX-1608 (S2) → P195.** An adaptive icon drawn from the in-app mark, with a monochrome layer. The status-bar icon becomes the same tick, and the «M» artwork goes.
- **D9 · UX-421 (S1) → P196.** Where a tab label doesn't fit, it stops growing at the largest size that fits, never below normal. A fixed 1.2× wouldn't have done it: «Configuració» needs about 1.16× on a 360 dp phone.
- **D10 · UX-1625 → closed as decided.** Reminder titles stay on the lock screen.

### Server contracts (main session, being built now)
- **UX-1602, recovery:** a 6-digit code in the app's language, a confirm that takes the address with the code, and `code_invalid` or `code_expired` for a wrong or old code. **P191** builds on it: the number pad, autofill, the address sent, plain answers. It stops if the server half isn't committed yet.
- **UX-1315, similar projects:** `project_candidates`. **Folded into P172**: the chips show the projects the server matched, with the 4-letter match as the fallback.
- **UX-1514, who was assigned:** `assignee_name` and `assignee_is_you`, the fields P183 already reads. No change.
- **UX-1307, Retry-After:** the real time until the daily limit resets, and none for Google's quota. P173's mapping holds. No change.
- A package that relies on one of these reads the committed names in Backend/docs/ first (a new convention in plan.json).

### Packages that change
- **P172 · S2 · A · S → M**: adds UX-1315's server half (the server's candidates, best first).
- **P181 · S2 · C · L**: adds D6, so UX-1513 is whole here.
- **P188 · S2 · D · M → L**: adds D7, so UX-1611 is whole here.

The other briefs still call D1–D10 «the owner's question», and their «don't touch» lines stand: the new packages build those answers after them.

### New packages, in order

**P190 · S3 · D · M · The reminder question waits for a reminder that can come; a passed alert time says so**
- UX-1601 (S3): no question after a save whose alert time has already passed (11:00 for a task with the 9:00 default; 16:55 for 17:00 minus 10 minutes), so the next dated save asks. The chip and the form's row read «Sin recordatorio: ya ha pasado la hora del aviso».

**P191 · S3 · D · M · Password recovery with the 6-digit code**
- UX-1602 (S3, the rest of the app half): the number pad and one-time-code autofill, at most 6 digits. The address goes with the code; after «Ya tengo un código» it's typed in. A wrong code says «Ese código no es correcto…». An expired one brings a new code at once, with «Ese código ya no sirve. Si {email} tiene cuenta, te llegará uno nuevo.». It needs the server half committed.

**P192 · S2 · A · S · Shared text: the form reads its day and time**
- UX-1623 (S2): «Comprar pan y leche el viernes» opens on Friday, titled «Comprar pan y leche». The day counts from when it was shared.

**P193 · S2 · D · M · Sign-in: Google first, the email form behind «Continuar con mi correo»**
- UX-1603 (S2): folded on a fresh sign-in. It opens by itself on sign-in-again, after create or recovery, while an error shows, or when Google isn't available.

**P194 · S2 · D · S · Cuenta: a name row**
- UX-1515 (S2): «Nombre · María», or «Añadir tu nombre», opens the name sheet, filled in.

**P195 · S2 · D · M · The launcher icon: the in-app mark, adaptive, themed**
- UX-1608 (S2): a teal background, the white double tick inside the safe zone, and a monochrome layer. The same mark on Android 7, in the status bar and on the splash; the «M» files go.

**P196 · S1 · D · S · Tab labels stay whole where they don't fit**
- UX-421 (S1): the Catalan «Configuració» stays whole at 1.3× and up on 320, 360 and 393 dp phones. Spanish sizes don't change.

### Batch order, all packages
They run one at a time, P166–P189 first, as planned.
- **b1**: P166, P167, P168, P169, P170 (S3)
- **b2**: P171, P172, P173, P174, P175 (S2)
- **b3**: P176, P177, P178, P179, P180 (S2)
- **b4**: P181, P182, P183, P184, P185 (S2)
- **b5**: P186, P187, P188, P189 (S2)
- **b6**: P190, P191 (S3); P192, P193, P194 (S2)
- **b7**: P195 (S2); P196 (S1)

### Ledger
- **Open now, with their packages:** UX-1601 (P190), UX-1602 (P170, then P191), UX-1623 (P192), UX-1603 (P193), UX-1515 (P194), UX-1608 (P195) and UX-421 (P196). UX-1513 and UX-1611 are now whole in P181 and P188.
- **Won't fix:** UX-1624 (cause server-side, D4) and UX-1625 (decided, D10).
- **Still with the owner:** U13 (with U10 and UX-331) and UX-615.
- No new ID was needed.

### Not planned
- «Añadir sin fecha» on the form's button (review B, optional; not in D3's answer).
- A phone with no calendar account still shows Calendar's «Elige calendarios para mostrar tus compromisos existentes.» after connecting (review B's cross-slice note). D7 fixes phones that have calendars, and no reviewer gave copy for this case.

### Notes for the main session
- **P191 needs the server half first.** Until P191 lands, the app (after P170) still sends `{code, password}` for a 45-character code. Commit the server half next to P191, or keep the server accepting today's body until P191 lands, so recovery on `dev` never breaks in between.
- **D4:** the empty answer's `free_voice` block must already leave the count as it was, because the app saves that block as sent (`App/lib/services/capture_processor.dart:250`). Staging check: «Hola, ¿esto funciona?» leaves the free-dictation count unchanged.
- **Google names:** P194 relies on the server filling a Google name only when the account has none (`Backend/core/google_auth.py:73-77`).
- **Catalan for a native read:**
  - the organizer's: «Sense recordatori: l’hora de l’avís ja ha passat» (P190) and «Aquest codi ja no serveix. Si {email} té compte, te n’arribarà un de nou.» (P191);
  - the reviewers': «Continua amb el correu» (P193), «Connectat. Els esdeveniments es veuen a Calendari.» (P188) and «Afegeix el teu nom» (P194).
- **Emulator lane:**
  - after b6: `reminder-ask.*` after 9:00, `share.landing` and `share.after-back`, `first-run.sign-in.*` folded and open, and Cuenta;
  - after b7: `launcher.home-icon.*` with themed icons, `notification.shade.*`, the launch splash, and `screen-settings.list.ca.light.2.0` with a 360 dp variant;
  - the review emulator has no calendar account: add one before re-capturing P188's `permission-calendar.allowed`.

## Round 2 (b1)

Round 1 (P166–P170) fixed 15 of its 17 findings. The round check failed only on the two UX-1309 1× landing tests, which fail on purpose: the fixture can't meet the check. Round 2 re-plans the two partial fixes and the four regressions, in three small packages, written to `plan-b1-r2.json`. Nothing has failed twice, so nothing is escalated. One new owner question, D11, holds no package back.

### Question for you
- **D11 · UX-1309, a second new task far down the same day.** When two tasks saved for one day are far apart in it, only the first can be shown above the save message. The second stays lit lower down, with nothing pointing to it. Should a lit row below the fold get a cue, which would be a new element with new copy? **Recommendation:** no cue. The message already counts every saved task, the lit row stays lit until it's scrolled into view, and most dictations hold one task. P197 doesn't wait for this answer.

### P197 · S3 · B · S · Calendar: the landing preview without its duplicate task, and a return to today starts at the top
- **UX-1309 (S3), partly, failed once:** P169's rules (a)–(c) stand as built. The failing check came from the fixture: the preview day already holds its own «Recoger a los niños del colegio» at 17:00, so the two lit rows can't fit together at 1×. The `calendar/agenda.added` preview drops that duplicate, and the fit check moves to 393×852. The 2× no-fit check stays.
- **UX-1628 (S2), R1B-1 from P169:** after 30 minutes or more away, or on a new day, Calendar jumps its list to the top, so the week strip and «Agenda de hoy» show. A short return keeps the scroll.
- **Settled here:** review B left a choice between changing the fixture and changing the check. The organizer drops the duplicate, which no real day holds, and keeps rule (b). Whether to add a cue is D11.

### P198 · S2 · A · M · Capture result: every result spoken once, «Ver lo que dije» set apart; the microphone reason only when Android asks
- **UX-1308 (S2), partly, failed once:** some results were still silent: a single change, delete or project card, a search, and a mixed result. Now one command card speaks its headline as shown, followed by the button's label when the headline is only the task's title. A mixed result speaks the filled button's label («Añadir, cambiar y eliminar»). No new strings.
- **UX-1626 (S1), R1A-1 from P168:** «Ver lo que dije» becomes bodySmall in onSurfaceVariant, 16 dp below the cards, so it no longer copies the «Más opciones» row. P171 keeps these 16 dp instead of its 8 dp.
- **UX-1627 (S1), R1A-2 from P166:** the microphone reason line waits 300 ms with the request unanswered, so a blocked answer never flashes it. Inferred from code; the emulator lane confirms.

### P199 · S1 · D · S · Recovery: the code field's label sits on the border like the other fields
- **UX-1629 (S1), R1D-1 from P170:** `floatingLabelBehavior: always` on «Código de recuperación», as on the email and password fields. The recovery-sent preview gains es 2× and ca 2×.

### Order
P197, P198, P199, one at a time, before b2. P171 (b2) builds on P198: it keeps the 16 dp above «Ver lo que dije».

### Skipped
Nothing.

### Noted, not planned (review A's notes, not regressions)
- At 2× the result's reveal cuts the task title's first line under the drag handle. Review A judged this acceptable; a top-edge fade would be an addition.
- The «nothing found» banner keeps the red error style. Review A called it a candidate for the neutral style but didn't raise a finding; the next review of the capture sheet can rate it.
- Pro accounts see an unlabelled keyboard icon while three lines name «Escribir». P171 (UX-1310) labels it.

### Phone checks added
- P197: with the largest font, reopen the app the morning after saving a task for Friday: the week strip and «Agenda de hoy» are at the top.
- P198: on the emulator lane, `permission-mic.blocked` (ES and CA, both paths) shows no frame of «Permite el micrófono…» before the banner, and `permission-mic.dialog.es` still shows the line under Android's dialog. With TalkBack, a deletion-only dictation and a mixed one are each spoken once.
- P199: at the largest font, the recovery form's labels sit whole on their borders.

## Round 2 (b2)

Round 1 of b2 (P171–P175) fixed all 14 of its findings, and the round check passed. Round 2 plans only the three regressions the reviewers found, in two small packages written to `plan-b2-r2.json`. Nothing has failed twice, so nothing is escalated, and there's no new owner question.

### P200 · S2 · A · M · Capture errors: a refused recording waits with «Cerrar»; a failed save says it couldn't add
- **UX-1630 (S2), R1A-1 from P173:** when the daily limit refuses a recording with no words, the sheet says «Has llegado al límite de dictados de hoy. Tu grabación se conserva; inténtalo mañana.» and shows only «Cerrar», like a recording that waits for free dictations. «Reintentar» and «Cancelar» are hidden. The organizer added one thing, inferred from the code: a recording reopened later drops the stored limit error, so it can be retried instead of being stuck with «Cerrar». One new string, in EN, ES and CA.
- **UX-1631 (S1), R1A-2 from P173:** a failed save says «Sin conexión…» only when the phone is offline. Every other failure, timeouts included, reads «No se ha podido añadir. Tus palabras siguen aquí; vuelve a intentarlo.»

### P201 · S2 · B · S · Calendar: TalkBack's count for today matches the agenda's
- **UX-1632 (S2), R1B-1 from P175:** the number TalkBack hears for today («hoy · N tareas») now includes the overdue tasks the agenda lists, so it matches «N pendientes». One helper computes the overdue list for both. The dots don't change, and there are no new strings.

### Order
P200, then P201, one at a time.

### Skipped
Nothing.

### Noted, not planned
- When typed words hit the daily limit, «Reintentar» still shows, though it can't work until tomorrow. The reviewer didn't raise this; the next review of the capture sheet can rate it.
- `captureTooLarge` and `captureIncompleteAudio` say «Descártala», but the button is «Cancelar», which then asks with «Descartar». Review A noted this and didn't count it: it takes two taps, and it's the plan's copy.
- `CaptureProblem.setupRequested` and `setupUnavailable` seem to have no setter left (P173's notes). A later package could remove them.
- The ES week strip shows «L M M J V S D» in previews because the preview locale is `es_US`; `es_ES` gives «X». This isn't a bug. The emulator lane checks it.

### Phone checks added
- P200: on staging, with an account at its daily limit and online speech on, a refused recording shows only «Cerrar» and stays in Capturas pendientes. Reopened the next day, «Reintentar» works.
- P201: with TalkBack and an overdue task, today's day and the count line say the same number.

## Round 2 (b3)

Round 1 of b3 (P176–P180) fixed 15 of its 17 findings. UX-1403 and UX-1421 came back partly fixed. UX-1414's code was right, but its catalog check also caught two ownership strings. Round 2 plans those, plus the six regressions review B found, in five small packages written to `plan-b3-r2.json`. Nothing has failed twice, so nothing is escalated. One new owner question, D12, takes what's left of UX-1403, and no package waits for it.

### Question for you
- **D12 · UX-1403, Tareas at large text.** Round 1 made every change the reviewers asked for. At the preview's 2× on a 360 dp phone with a shared project, the header still fills the screen: the project filter (two rows), «Tus tareas», «Proyectos» and «Completadas» (a row each), the search and the chips. Only part of the first task shows above «Añadir tarea». Fitting a whole task means moving or hiding something you built: (a) wait for the two tabs (U13); (b) move «Completadas» to the end of the list; (c) put the search behind an icon; (d) make the project filter one control. **Recommendation:** (a), after one measurement. The main session captures the emulator at Android's real 2.0 on 393 dp first. If a whole task shows and «Tus tareas» / «Les teves tasques» is on one line, UX-1403 closes as fixed. If not, it joins U13's evidence for the test with your father. The header scrolls away, so the tasks are one swipe up.

### P202 · S2 · B · M · Día view: the banners and «Sin hora» stay above the hours, in view on arrival
- **UX-1633 (S2), R1B-1 from P180:** the error banners, the calendar-access button and the limit notices move out of the scroll, under the day's header, so they never scroll away. «Sin hora» (date-only tasks, all-day events) sits pinned above the hours, as in the phone's own calendar. It takes at most a third of the screen and scrolls by itself past that. The opening scroll stays as P180 built it. No new copy. New preview `calendar/timeline.untimed`.
- **Settled here:** review B offered two places for «Sin hora»: above the timeline, where it scrolls away, or below it, where nobody reaches it. The organizer pinned it above the hours instead.

### P203 · S2 · B · S · Someone else's reminder: the time only when the task sets its own
- **UX-1634 (S2), R1B-2 from P177:** a task given to Ana that follows the default reads «Recordatorio para Ana», because Ana's phone uses Ana's default, which this phone doesn't know. With its own value it keeps «Recordatorio para Ana: 30 minutos antes». One new string, in EN, ES and CA.

### P204 · S2 · B · S · Scoped Completed page: names the person filter; rows leave out the project
- **UX-1635 (S2), R1B-3 from P176:** under the title, «Matemáticas · Ana» or «Matemáticas · Para mí», using existing strings. With «Todas» on, only «Matemáticas».
- **UX-1636 (S1), R1B-4 from P176:** its rows no longer repeat «Matemáticas».

### P205 · S2 · B · S · Catalog: plain words in the task's rarer corners; «(100 MB)» on one line; the transfer check covers files only
- **UX-1414 (S2), partly, failed once:** no app change. The check now exempts “Transfer ownership” and the CSV import's ownership line, where “transfer” is the right word, as review B asked.
- **UX-1421 (S1), partly, failed once:** the organizer's copy for the keys round 1 had none for: the repeat-change dialog («¿Cambiar cómo se repite?»), the read-only project line («Si quieres hacer cambios, pídeselo al propietario del proyecto.»), the view-only note, and the three Recordatorios › Detalles lines («Los próximos avisos se actualizan al abrir la app…»). It also removes the unused `schedule` key («Programación»). `retryScheduling` is left for P187, which replaces it with «Reintentar». The Catalan is the organizer's, so a native read is noted.
- **UX-1638 (S1), R1B-6 from P179:** «(100 MB)» with a non-breaking space, in all three languages.

### P206 · S1 · B · S · View-only rows line up with the others
- **UX-1637 (S1), R1B-5 from P178:** a view-only row keeps an empty space where the circle was, so its title lines up with the rest. No icon.

### Order
P202, P203, P204, P205, P206, one at a time.

### Skipped
Nothing.

### Notes for the main session
- The two UX-1403 tests at linear 2× (`home_screen_test.dart`, es and ca) will keep failing until D12 is answered. Have ux-tester mark them `skip: 'D12 (UX-1403): judged on the emulator lane at non-linear 2.0'` so the round check reads clean, and run the emulator capture D12 asks for.
- ux-tester's catalog checks for UX-1414 and UX-1421 change to P205's acceptance: two EN keys exempt for “transfer”, and `retryScheduling` exempt for “scheduling” until P187.
- P177's follow-up from its implementer, `task: task` on the dictation review's `ReminderControl` (`capture_review_editor.dart`), isn't planned. No reviewer raised it; the next review of the capture sheet can rate it.

### Phone checks added
- P202: on the emulator lane at 2.0, the Día view of today with one date-only task shows «Sin hora», that task and the first timed task together on arrival.
- P203: with two accounts and Ana's default at 1 hour, María's phone reads «Recordatorio para Ana», and Ana's phone rings an hour before.
- D12: `screen-tasks.list.es.light.2.0` and its CA twin, on the emulator lane at 393 dp.

## Round 3 (b3)

Round 2 of b3 (P202–P206) fixed all eight of its findings, according to review B's notes (`verify-b3-r2-B.md`), and the round check passed. One regression came back: at 2× the only «Sin hora» row is cut (R2B-1, now UX-1639). Round 3 fixes it in one small package and adds a re-check with no code change, both written to `plan-b3-r3.json`. Nothing has failed twice, so nothing is escalated. There's no new question for you.

### P207 · S2 · B · S · Día view: the one «Sin hora» row fits whole at 2×, with a line under the area
- **UX-1639 (S1), R2B-1 from P202:** a row under «Sin hora» whose day is the one on screen loses its «Hoy» line, which the day header already says. The row then fits in the pinned third at 2×. A thin line under the area means a cut row reads as an edge. A row listed there for another day's task keeps its date. No new copy.
- **UX-1633 (S2), fixed in round 2:** re-checked here, because P207 changes its pinned area. The banners, the third cap, the scrollbar and the opening scroll stay as P202 built them.

### P208 · S2 · B · S · Re-check only: round 2's reminder, Completed, catalog and row fixes (no code change)
- **UX-1634, UX-1635, UX-1636, UX-1414, UX-1421, UX-1638, UX-1637:** the workflow listed these as not checked, but review B's round 2 notes record each one as fixed, with evidence. The implementer changes nothing. The reviewer confirms each one against P203–P206's acceptance, so the result reaches the record.

### Order
P207, then P208.

### Skipped
Nothing.

### Noted, not planned
- Review B's note: the banners above the hours have no height cap. At 2×, with «No se pudieron cargar tus tareas», the calendar-access button and a full «Sin hora» third all showing, little room may be left for the hours. It's inferred from code only, the reviewer didn't count it, and the brief asked for the banners to be pinned. P202's implementer raised the same risk for short screens.
- P202's implementer measured "a third" from the header's bottom to the screen's bottom, using `extendBody`, and added the app's first `Scrollbar`. Review B accepted both, and P207 keeps them.

### Notes for the main session
- P208 exists only because the round 2 results in `verify-b3-r2-B.md` didn't reach the workflow. If the workflow can take those results from that file, P208 can be dropped and its seven findings closed as verified from round 2.
- Round 2's implementers each reported two failing UX-1403 tests in `home_screen_test.dart` (es and ca). Round 2's notes said to skip them for D12. The round check passed, so they appear to be skipped already. D12 is still open.

### Phone checks added
- P207: on the emulator lane at 2.0 on 393 dp, the Día view of today with one date-only task at priority Media shows «Sin hora», the whole row, a line under it, then the first timed task.

## Round 2 (b4)

Round 1 of b4 (P181–P185) fixed all 18 of its findings, according to review C's notes (`verify-b4-r1-C.md`), and the round check passed. Six regressions came back: one major (Activity), one minor (the archived project bar) and four polish items, now UX-1640 to UX-1645. Round 2 fixes them in three small packages, written to `plan-b4-r2.json`. Nothing has failed twice, so nothing is escalated. There's no new question for you.

### P210 · S3 · C · S · Activity: a task not on the phone yet waits for the sync before saying it may be deleted
- **UX-1640 (S3), R1C-1 from P183:** a task the phone already has still opens at once. When the phone doesn't have it yet, the row shows a spinner while the sync it already started finishes, and then opens the task. Only a task still missing after that sync gets «Es posible que esta tarea se haya eliminado.». A «ha eliminado» entry says so at once. If the person has meanwhile opened something else or left Activity, the late result is dropped quietly. No new copy.

### P211 · S2 · C · S · Archived project bar: say «Restáuralo» only to someone who has the button
- **UX-1641 (S2), R1C-2 from P184:** a reader of an archived project, or anyone on a project archived with its group, reads «Proyecto archivado.» (new key `archivedListNoAdd`; EN “Archived project.”, CA «Projecte arxivat.»). «Proyecto archivado. Restáuralo para añadir tareas.» shows only above the «Restaurar proyecto» button. This corrects the round 1 brief, which gave the group case the line without the button.

### P212 · S1 · C · S · Sharing polish: «Miembros» named once and the same everywhere, «(tú)» on the group, one invite wording
- **UX-1642 (S1), R1C-3 from P181:** the Proyectos ⋮ item reads «Miembros» for any shared project, and «Compartir» only for an unshared project of your own, as the project page's button does.
- **UX-1643 (S1), R1C-4:** the owner's members page drops the «MIEMBROS» section label when the app bar already reads «Miembros». It keeps the label under «Compartir proyecto».
- **UX-1644 (S1), R1C-5:** the group's members list marks your own row «María (tú)», as the project's list does. The group preview fixture stops using the role 'member', which the server never sends.
- **UX-1645 (S1), R1C-6:** the group invite help becomes «Esa persona verá todos los proyectos de este grupo. Le enviaremos una invitación por correo.» (EN “They’ll see every project in this group. We’ll email them an invitation.”; CA «Aquesta persona veurà tots els projectes d’aquest grup. Li enviarem una invitació per correu.»).

### Order
P210, then P211, then P212. None depends on another. P211 and P212 both edit the three ARB files.

### Skipped
Nothing.

### Noted, not planned
Review C noted these and didn't count them. Each was there before round 1, or lies outside its brief:
- The archived project page still offers «Compartir» (P184's implementer said the same).
- On the unavailable-invitation screen, the app bar's and the system Back still postpone the dead link instead of clearing it (`main.dart:254`).
- A read-only note (viewer) still reads in TalkBack as an unnamed SelectableText.
- The preview audit records no tap hints (`test/ux_previews/support/audit.dart:203`), so «Editar nota» can't be seen in AUDIT.md (P185's note).
- AUDIT.md shows a 0 dp gap between «Aceptar invitación» / «Reintentar» and «Ahora no» (P182's note).
- Deleting a project from its own sharing page still waits for the sync before closing (P183's note).

The next review of area C can raise any of these as findings.

### Notes for the main session
- UX-1514's server half (`assignee_name`, `assignee_is_you`) and its staging check stay with you.
- Catalan still needing a native read: «{actor} ha assignat {name}: {title}» and «Com funciona compartir» (UX-1524).

### Phone checks added
- P210: on a phone with two accounts, Lucía creates a task in a shared project. On the other phone, open Activity before any other sync and tap «Lucía ha creado…»: a spinner shows on the row, then the task opens.

## Round 3 (b4)

Round 2 of b4 (P210–P212) fixed all 6 of its findings, according to review C (`verify-b4-r2-C.md`), and the tests and the round check passed. Two small regressions came back, both on P210's new waiting row in Activity. They are now UX-1646 and UX-1647. Round 3 fixes them in one small package, written to `plan-b4-r3.json`. Nothing has failed twice, so nothing is escalated, and there's no new question for you.

### P213 · S2 · C · S · Activity waiting row: TalkBack hears «Buscando la tarea…», and the text stays where it was
- **UX-1646 (S2), R2C-1 from P210:** while a tapped entry waits for its task, TalkBack says «Buscando la tarea…» once, and the row reads that way. New key `activityFindingTask`: EN “Finding the task…” / ES «Buscando la tarea…» / CA «S’està cercant la tasca…». It doesn't reuse «Sincronizando».
- **UX-1647 (S1), R2C-2 from P210:** the spinner at the row's end goes. A 2 dp bar along the row's bottom edge shows the wait instead, so the entry's words keep their width and nothing below moves under the finger. A second tap still does nothing.

### Skipped
Nothing.

### Noted, not planned
Review C noted these and didn't count them:
- If the tasks sync itself fails (the connection drops after Activity loaded), the waiting row still ends with «Es posible que esta tarea se haya eliminado.» rather than «No se ha podido cargar. Revisa la conexión.». It's rare, because Activity needs the network to list entries, and the check needs care, because the repository's sync error is also set for list conflicts.
- The Projects delete spinner (`task_lists_screen.dart:365-374`) has the same TalkBack gap as UX-1646.
- The group invite dialog at 2× scrolls its title out of view, cuts «0/254» and wraps «Enviar invitación» to two lines (there before P212; P212's implementer saw it too). AUDIT.md also gives the counter 4.3:1 contrast. Emails still break mid-word at 2× on the group and project members pages, and «Transferir propiedad» measures 15 dp tall.

The next review of area C can raise any of these as findings.

### Phone checks added
- P213 (emulator lane with TalkBack, then the phone): double-tap an entry whose task the phone hasn't synced yet. TalkBack says «Buscando la tarea…» once, then the task opens. At the largest text, the entry's words don't move when the bar appears.

## Round 2 (b5)

Round 1 of b5 (P186–P189 and P214) fixed 16 of its 17 findings, according to reviews C and D (`verify-b5-r1-C.md`, `verify-b5-r1-D.md`), and the tests and the round check passed. UX-1612 came back partly fixed: the slogan is gone and the name is the heading, but TalkBack doesn't hear it as one. Four regressions came back, three minor and one polish item, now UX-1649 to UX-1652. Round 2 fixes all five in three packages, written to `plan-b5-r2.json`. Nothing has failed twice, so nothing is escalated, and there's no new question for you.

### P215 · S2 · D · M · «Como el teléfono» reads the phone again, not the app's language
- **UX-1649 (S2), R1D-1 from P186:** with the phone in Spanish and Idioma in English, «Primer día de la semana: Como el teléfono» starts the week on Sunday, because on Android 13+ the app now sees the app's language where it asks for the phone's. The week start, the recognizer's region and background reminders read the phone's languages that P186's bridge already returns. A copy is kept on the phone, so the first screen and background reminders have them too. Inferred from code; the emulator confirms it.

### P216 · S2 · D · S · Recordatorios: after turning on, Detalles waits for the alerts and shows a failed refresh
- **UX-1650 (S2), R1D-2 from P187:** after turning reminders on, Detalles said «No hay próximos avisos» because it read the list before the alerts were set. The screen now waits for that same setting-up, with the progress bar and the switch on, and then lists the alerts. If the setting-up fails, «Reintentar» shows at once. «Listo. Recordatorios activados.» still comes right away.

### P217 · S2 · D · S · Follow-ups on three settings screens
- **UX-1651 (S2), R1D-3 from P188:** «Borrar selección» goes from Calendarios del teléfono. It looked like «Ocultar eventos del calendario» right under it and did the same thing; each calendar's tick box still turns one off. That leaves 2 controls below the list instead of 3.
- **UX-1612 (S2), second attempt:** Cuenta's name is announced as a heading. The name row stays UX-1515's (P194, D5).
- **UX-1652 (S1), R1D-4 from P188:** with Android's «Quitar animaciones» on, the import result jumps into view instead of scrolling.

### Skipped
Nothing.

### Noted, not planned
Review D noted these as already there before this round, outside the findings it checked:
- At 2× the account under each phone calendar still breaks mid-word («maria.lopez@exam / ple.com», `phone-calendars.allowed.es.light.2x`), and so does the Ajustes «Cuenta» row's address. The fix is the same as UX-1618's: `breakableAddress` with a plain `semanticsLabel`. Together with round 3 of b4's group and project member pages, they are the last places an address breaks mid-word.
- On Recordatorios, «Tareas con hora» ends in a chevron and «Tareas sin hora» in «+», though both open a list of choices. UX-1616 only converted the first row.

The next review of area D can raise any of these as findings.

### Phone checks added
- P215 (emulator lane, Android 13+): phone in Spanish (Spain), Idioma English, week start «Como el teléfono»: Calendar's week starts on Monday. A background reminder reads in English, with its time as the app shows it.
- P216 (emulator lane): after allowing reminders, Detalles lists the upcoming alerts once the bar ends.
- P217 (emulator lane): with TalkBack, Cuenta announces the name as a heading. With «Quitar animaciones» on, the import result jumps into view.

## Round 3 (b5)

Round 2 of b5 (P215–P217) fixed all five of its findings, according to review D (`verify-b5-r2-D.md`), and the tests and the round check passed. One regression came back from P215, now UX-1653. Round 3 fixes it in one small package, written to `plan-b5-r3.json`. Nothing has failed twice, so nothing is escalated, and there's no new question for you.

### P218 · S2 · D · S · «Como el teléfono» follows a phone-language change while the app runs
- **UX-1653 (S2), R2D-1 from P215:** with Idioma «Como el teléfono» (the default), if the phone's language changes while TaskFlow is still running in the background, the app, and its reminders, stay in the old language until it is closed for good. The app now asks Android for the phone's languages again on every language change, and only then rewrites the reminders; background reminders read the phone's language directly. Last round avoided this for fear of a loop; Android only changes the app's language when it differs, so there's none. Verified in code; whether Android keeps the app running across a language change needs the emulator.

### Skipped
Nothing.

### Note for the main session
- P215's implementer saw `capture_landing_test.dart` UX-1628 ('resuming 31 minutes later') fail near midnight with and without its change; it reads `DateTime.now()`. Re-run it at another time of day before treating it as a regression.

### Phone checks added
- P218 (emulator lane, Android 13+): Idioma «Como el teléfono», app in the background, phone switched to Català: back in TaskFlow, it's in Catalan without a restart, and a reminder fired after swiping it away is in Catalan. Idioma English with the phone's region changed: the app stays English, the week start follows the phone, and the screen settles at once.

## Round 2 (b6)

Round 1 of b6 (P190 to P194) fixed all five of its findings, according to reviews A and D (`verify-b6-r1-A.md`, `verify-b6-r1-D.md`), and the tests and the round check passed. Two small regressions came back, now UX-1654 and UX-1655. Round 2 fixes them in two small packages, written to `plan-b6-r2.json`. Nothing has failed twice, so nothing is escalated, and there's no new question for you.

### P219 · S2 · A · S · A stale share or dictation opens with no day, not a past one
- **UX-1654 (S2), R1A-1 from P192:** P192 made a share's day words count from the moment of the share. A share «Llamar a Marta mañana» left in Sin guardar on Monday and resumed on Thursday would open on Tuesday, a day already gone, and one Back would save it there. Now, when the day read has already passed, the form opens as it did before: no day (or the day the person was looking at) and the words as written. This is the same rule the form already has for a day passed in. It also covers a dictation resumed days later. Verified in code; the behaviour is inferred, so the package adds a widget test, and the emulator check is in the phone checks.

### P220 · S2 · D · S · Cuenta: the name row ends in a chevron
- **UX-1655 (S2), R1D-1 from P194:** the new «Nombre · María» row in Cuenta looked like the read-only rows below it («Cuenta de Google vinculada», «Guardado en tu cuenta»). It now ends in the same chevron as the Settings rows, so it reads as something to tap. No new copy.

### Skipped
Nothing.

### Phone checks added
- P219 (emulator lane, free account): share «Llamar a Marta mañana», kill TaskFlow with the form open, move the date forward three days, resume from Sin guardar: no day is selected and the title reads «Llamar a Marta mañana».

## Round 2 (b7)

Round 1 of b7 (P195, P196, P221) fixed two of its three findings in code, according to review D (`verify-b7-r1-D.md`): UX-1608 (the launcher icon is the in-app mark) and UX-421 (the Catalan tab bar fits on one line). UX-1656 came back partly fixed, and the round check failed on its test. No regressions. Round 2 finishes UX-1656 in one small package, written to `plan-b7-r2.json`. It has failed once, so it isn't escalated, and there's no new question for you.

### P222 · S2 · D · S · The widget gets its own label; the English voice shortcut reads «Dictate a new task»
- **UX-1656 (S2), partly fixed in round 1:** P221 renamed the English text shortcut to “Type a new task”, long enough that the launcher shows «Type» whole at large text. It couldn't rename the voice shortcut, “Say a task”, because the home-screen widget uses the same string for its label, its TalkBack name and its name in the widget picker, and the brief said not to change the widget. So at large text the English voice shortcut still shows «Say a ta…», and at normal size the pair reads “Say a task” / “Type a new task”. Now the widget gets its own string with exactly today's text in all three languages, so it looks and sounds the same, and the English voice shortcut becomes “Dictate a new task”, which falls back to «Dictate» at large text. Spanish and Catalan don't change. This widens round 1's scope, but it isn't a product decision: nothing the user sees on the widget changes.

### Skipped
Nothing.

### Phone checks added
- P222 (emulator lane): English at 2.0, the shortcuts read «Dictate» and «Type», whole; at 1.0 «Dictate a new task» and «Type a new task». The widget in EN, ES and CA at 1.0 and 2.0 reads «Say a task» / «Dictar una tarea» / «Dicta una tasca», whole, with the same TalkBack and picker name. On Android 13+, phone in Spanish and TaskFlow in English, the widget reads «Say a task».
- Carried from round 1 (review D's observation on UX-421, not a regression): at 360 dp and Android's 2.0 in Catalan, «Configuració» fits the tab bar with about 1 dp to spare. The re-capture at 393 and 360 dp should confirm the device doesn't wrap it to «Configuraci / ó».

## Round 3 (b7)

Round 2 of b7 (P222) fixed UX-1656 in code, according to review D (`verify-b7-r2-D.md`): the English voice shortcut now reads “Dictate a new task”, and the widget has its own string. The tests and the round check passed. One small regression came back, now UX-1657: in English only, the widget still says “Say a task” while the voice shortcut and the app say “dictate”. Round 3 fixes it in one small package, written to `plan-b7-r3.json`. Nothing has failed twice, so nothing is escalated, and there's no new question for you.

### P223 · S1 · D · S · The English widget reads “Dictate a task”, like the voice shortcut and the app
- **UX-1657 (S1), R2D-1 from P222:** the English widget now says “Dictate a task” (14 characters, which fits the widget's two short lines), the widget picker says “Tap to dictate a task.”, and the English line in Settings › Other names “the Dictate a task widget”. Spanish and Catalan already use one word for both and don't change. It keeps a voice wording on the widget, as today, so your open question about the wording at 0 dictations left (UX-910) stays where it was.

### Skipped
Nothing.

### Phone checks added
- P223 (emulator lane): in English at 1.0 and 2.0, the widget reads «Dictate a task», whole, on at most two lines; TalkBack and the widget picker use the same name, with «Tap to dictate a task.» in the picker. On Android 13+, phone in Spanish and TaskFlow in English, an already placed widget reads «Dictate a task». Spanish and Catalan unchanged.
