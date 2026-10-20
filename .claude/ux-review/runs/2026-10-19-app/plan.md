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
