# UX loop 2026-10-18-commands: plan

**Run:** what changed since the last UX review (`changes`, refs/ux-review/last 6d41fd3 → 985f060). That covers voice commands (projects, find, change and delete by voice), the form for free accounts, the person filter and «Creada por», and email confirmation. All four reviews (A to D) say ship after fixes. This is a scoped run, so the packages go straight to the implementers.

**Summary.** 45 of the 57 findings are fixes, in 18 packages (P127–P144), run one at a time. The other 12 go to you as 11 questions (D1–D11), and none of them blocks a package. Nothing is skipped.

## Questions for the owner (not blocking)

### D1 · Cancel on a result with nothing to add (UX-917, S2)
- **Findings:** UX-917 (review A's question 1).
- **Why it's yours:** U2 says Cancel asks keep-or-discard. On a result that only changes, deletes or creates projects, «Conservar» leaves a pending deletion waiting in «Sin guardar».
- **Recommendation:** yes, Cancelar just closes, meaning "don't do it". The words can be said again, at the cost of a free dictation on a free account. Results with a task to add keep asking. P128 rewords the question in the meantime.

### D2 · Date words in the form's title (UX-918, S2)
- **Findings:** UX-918 (review A's question 2, and review B's question 2).
- **Why it's yours:** on 2026-10-18 you decided that the phone's parser no longer reads a free account's typing. Today «Médico el viernes a las 5», dictated and then carried into the form, becomes a title with no day, and Back saves it that way (D12).
- **Recommendation:** for dictated words carried into the form by «Escribir», yes: they are a dictation, and «Guardar tal cual» already reads them. For titles typed in the form, no; the first-run line teaches the day chips. Review B's case («Médico el viernes» typed in, then saved to Sin fecha) belongs with your open question about a default day in the form.

### D3 · Rename «Guardar tal cual» (UX-919, S2)
- **Findings:** UX-919 (review A's question 3).
- **Why it's yours:** it changes the wording of D3 and U7.
- **Recommendation:** yes, rename it «Guardar como tarea» / "Save as a task" / «Desa-ho com a tasca». After 8 s it is the filled button, so «Borra la tarea del dentista» is easily saved as a new task. P127 also shows it on command results that find nothing.

### D4 · A search by period, in day order (UX-920, S1)
- **Findings:** UX-920 (review A's question 4).
- **Why it's yours:** the approved plan (item 5) says newest first.
- **Recommendation:** yes. A search with a period («¿qué tengo esta semana?») lists by day and time, soonest first. Other searches stay newest first.

### D5 · The button's name at 0 dictations (UX-921, S1)
- **Findings:** UX-921 (review A's question 5).
- **Why it's yours:** you asked for the button to change once the dictations run out, and the reviewers disagree. A would keep «Añadir tarea» with the + icon, because renaming the one main button each month costs recognition. B likes «Nueva tarea» because it matches the form's page.
- **Recommendation:** keep «Nueva tarea». If you side with A, the Tareas and Sin fecha empty states change too.

### D6 · What Back says on a new task (UX-1010, S1)
- **Findings:** UX-1010 (review B's question 1).
- **Why it's yours:** it changes D12's wording.
- **Recommendation:** keep D12's saving, but for a new task Back shows the button's message («Añadida al lun, 19 oct» or «Añadida sin fecha», with Deshacer), not «Cambios guardados». A newcomer who presses Back to get out shouldn't hear about changes he didn't make.

### D7 · A task added under a person's chip (UX-1111, S1)
- **Findings:** UX-1111 (review C's question 1).
- **Why it's yours:** it sets a new default for who a task is for. Today a task added while «Ana» is selected goes to «Todos», and the page switches back to Todas.
- **Recommendation:** yes, make it Ana's by default, as a picked day already is (D9). It shows on the form and the card, and one tap changes it.

### D8 · Real names instead of email prefixes (UX-1102, UX-1112; S2)
- **Findings:** UX-1102 (review C) and UX-1112 (review C's question 2).
- **Why it's yours:** no account has a name today. Chips, «Creada por» and the person picker read «ana.garcia84», «paulsmith».
- **Recommendation:**
  - Google accounts: take the name from Google at sign-in. This is a server change for the main session (`Backend/core/google_auth.py:77` stores none), not a product question.
  - Password accounts: ask once, when they first share or join a shared project. Prefill it from the email and let them skip it. Don't add a field at sign-up.

### D9 · «Reenviar código» when nothing was sent (UX-1206, S2)
- **Findings:** UX-1206 (review D's question 1).
- **Why it's yours:** past 5 codes an hour, the server sends nothing but still answers 204, so the app says «Te hemos enviado un código nuevo» each time. Saying so instead tells whoever keeps pressing that an unconfirmed sign-up exists for that address.
- **Recommendation:** yes. The server answers 429 with Retry-After, then the app says «Has pedido muchos códigos. Espera {n} minutos para pedir otro.» and keeps Reenviar off. The server goes first (main session); the app half follows in a later run.

### D10 · An «Abrir el correo» button (UX-1211, S1)
- **Findings:** UX-1211 (review D's question 2).
- **Why it's yours:** it adds a control.
- **Recommendation:** not now. The code is in the email's subject, so the phone's notification already shows it. Watch for it in the §7 test, with an email sign-up rather than Google.

### D11 · Does asking for commands slow every dictation? (UX-912, S2)
- **Findings:** UX-912 (review A). It belongs with UX-616, which is open.
- **Why it's yours:** any fix is on the server, and it trades speed against cost.
- **Recommendation:** measure first. On staging (main session), with the same phone and network, do 10+ one-task dictations with the commands flag and 10+ without, and read the p50 and p95 of `extraction_ms` in Diagnóstico de captura. If the flag adds 300 ms or more at p50, decide it together with UX-616: a shorter commands prompt, a faster model, or the paid fallback.

## Already with you (not asked again)
- **Deleting one repetition of a repeating task by voice.** No package touches it.
- **A default day in the form.** D2 adds review B's case: a typed «Médico el viernes» ends up in Sin fecha.
- **The Android launcher shortcut's wording.** UX-910 (P138) adds only an existing line to the form, and leaves the wording alone.

## Packages, in order

They run one at a time. The full briefs are in `plan.json`. Package numbers continue after P126.

### P127 · S3 · A · M · A task that sounds like a command still becomes a task
- **UX-901 (S3):** a result whose changes or deletions found nothing, or whose search found nothing, shows «Guardar tal cual» as the filled button above «Cerrar». It saves the words as a task with the phone's parser, sends nothing more to the assistant, and lands with Deshacer. Change, deletion and pick-list rows mark a completed task «Completada».
- **UX-904 (S2):** shared text is stored as `shared`. It reaches the assistant as typed text, without asking for commands, so a share is always read as tasks.

### P128 · S3 · A · M · Command cards say what each tap does
- **UX-903 (S3):**
  - The ✕ reads «No eliminar / No cambiar / No crear {title}».
  - After it, the message is «No se eliminará / No se cambiará / No se creará».
  - With every card removed, the result says «No se hará ningún cambio.».
  - Cancel asks «¿Conservar lo que has dicho para más tarde?», or «¿Conservar el texto para más tarde?» for typed words.
- **UX-905 (S2):** the button names what the tap does: «Cambiar fecha», «Guardar cambios», «Añadir y cambiar», «Añadir y eliminar», «Cambiar y eliminar», «Añadir, cambiar y eliminar». «Aplicar» goes.

### P129 · S3 · A · L · Deadline-only tasks show and land on their due day; a project made by voice opens
- **UX-902 (S3):** a task with only a deadline shows «Vence jue, 12 nov» on collapsed cards, pick lists and found rows. It lands on that day, and the message says «Añadida · vence el jue, 12 nov».
- **UX-906 (S2):** a tap that creates one project, and puts any tasks into it, opens that project's page with the new tasks lit. Deshacer closes the page and brings the result back.

### P130 · S3 · B · M · A task for someone else lands in view on Calendar and Tareas
- **UX-1001 (S3):** when «Para mí», or the project filter, would hide a task just saved, Calendar and the Tareas root switch to «Todas» or «Todos los proyectos». The task then shows lit.

### P131 · S3 · C · M · A shared project's people filter: every chip in view, one order, named for TalkBack
- **UX-1101 (S3):** the people chips wrap. The ✓ for completed tasks moves into the app bar on project pages and Sin fecha, which frees about 60 dp, so the first task sits no lower than today.
- **UX-1108 (S2):** «Todas · Para mí» is in that order everywhere, Calendar and Tareas included.
- **UX-1110 (S1):** TalkBack hears «Tareas para Ana», not just «Ana».

### P132 · S3 · D · M · Sign-in errors name the problem: a wrong password, and how long to wait
- **UX-402 (S3, reopened):** a 401 from the real sign-in reads as wrong credentials. That brings back «Crear una cuenta con este correo» and the recovery button.
- **UX-1208 (S1):** a 429 on the sign-in screens names the wait: «Demasiados intentos. Espera 15 minutos…». It shares one key with the delete page.

### P133 · S3 · D · L · Confirm your email: the answer in view, the keyboard steady, an honest «expired»
- **UX-1201 (S3):** the keyboard stays up while the code is checked, and every answer scrolls into view. The screen opens without the keyboard, so Reenviar and «Usar otro correo» show.
- **UX-1203 (S3):** «Ese código ha caducado» first tries signing in. An account confirmed meanwhile simply opens.
- **UX-1204 (S2):**
  - Refused digits aren't sent again.
  - A wrong code says to check the newest email.
  - An expired code says whether a new one is on its way, or that Reenviar works when the countdown ends.

### P134 · S3 · D · M · Confirm your email survives the trip to the inbox
- **UX-1202 (S3):** the pending address (never the password) is kept for 30 minutes. A cold start reopens «Confirma tu correo» with its password field. There, a wrong password says «Esa contraseña no es la de esta cuenta.».

### P135 · S2 · A · L · Command-card questions: in the question box, the right question, few chips
- **UX-908 (S2):** the question becomes «¿En qué proyecto la pongo?», with at most 6 chips: create, up to 3 similar projects, «Otro proyecto…» and «Sin proyecto».
- **UX-909 (S2):** «Crea el proyecto Química» next to «Física y Química» asks before choosing, and can create it.
- **UX-915 (S1):** the questions sit in the result's question box. The day question shows the time it heard: «¿Qué día, a las 17:00?». «Elegir día» shows the day picked.

### P136 · S2 · A · M · Every change and deletion can be finished by tapping
- **UX-914 (S2):**
  - «Ver 3 más» opens the rest of a pick list.
  - A view-only match says so.
  - Two Pauls get one chip each.

### P137 · S2 · A · M · Search cards say what they searched; found rows open, not tick; copy slips
- **UX-907 (S2):** a quieter line names the period and status: «Mañana · Completadas», «Del … al … · Pendientes». A search by person and project names both.
- **UX-913 (S2):** found rows lose the tick circle and gain a chevron.
- **UX-916 (S1):**
  - «Tareas para Ana».
  - «La tarea va ahí.» for a single task.
  - English "Which one do you want to change/delete?".
  - The priority line gets the flag icon.

### P138 · S2 · A · L · Free accounts' way into the form: «Escribir», shares straight in, why there's no mic, nothing lost
- **UX-911 (S2):** «Rellenar a mano» becomes «Escribir». For free accounts, shared text and typed captures in «Sin guardar» open straight in the form.
- **UX-910 (S2):** at 0 left, the widget and the voice shortcut open the form with «Sin dictados gratis hasta el …» and «Ver Pro».
- **UX-1005 (S2):** the form keeps its title and notes in «Sin guardar» until the task is saved, so Android closing the app loses nothing.
- **UX-1011 (S2):** a task saved from the widget, a shortcut or a share brings Calendar forward, so it lands in view.

### P139 · S2 · B · M · The new-task form at large text: keyboard down for choices, a title that wraps, one way to add a time
- **UX-1002 (S2):** tapping a day or time chip puts the keyboard down, and it stays down.
- **UX-1003 (S2):** the title wraps to up to 3 lines.
- **UX-1004 (S2):** «Elegir día» opens a day-only sheet that applies on tap. «Añadir hora» opens the time picker in typing mode.

### P140 · S2 · B · M · The form's details and the notice: no stale help, filled details stay, «Creada por ti», «a mano»
- **UX-1006 (S2):** the attach sheet for a new task has no paragraph.
- **UX-1007 (S1):** «Menos detalles» keeps notes, files and a project that are filled in.
- **UX-1008 (S1):** «Creada por ti».
- **UX-1009 (S1):** the notice reads «Puedes seguir creando tareas a mano, sin límite. El {date} tendrás 10 dictados más.».

### P141 · S2 · C · L · A project the dictation creates: its name first, one way to fix it, the next step; the person chip's ▾
- **UX-1104 (S2):** the chip reads «Matemáticas (nuevo)».
- **UX-1105 (S2):** «Paul aún no está en «Matemáticas». Luego, comparte el proyecto con Paul.».
- **UX-1106 (S2):** one «Nuevo proyecto» row, which renames the dictated project with «Usar este nombre».
- **UX-1103 (S2):** the person chip gets ▾.

### P142 · S2 · C · S · A person's view: «Abrir» keeps the person; an empty view says why
- **UX-1107 (S2):** «Abrir «Matemáticas»» opens on Paul's chip, or on Para mí for the account itself.
- **UX-1109 (S1):** «Marta no tiene tareas pendientes aquí» / «Toca Todas para ver todas las tareas.».

### P143 · S2 · D · M · Confirm your email: help when the email doesn't come, a named screen, a readable countdown, unbroken headings
- **UX-1205 (S2):**
  - The address shows in bold.
  - After Reenviar: «Si no lo ves, mira en Spam o en Promociones.».
  - «Usar otro correo» focuses the email field.
- **UX-1207 (S2):** TalkBack names the screen, and the spinner says «Confirmando».
- **UX-1209 (S1):** headings scale at most 1.2×, so no word breaks.
- **UX-1210 (S1):** the countdown is readable and counts from when the code was sent, with 8 dp before «Usar otro correo».

### P144 · S2 · D · S · Chip borders that can be seen
- **UX-1012 (S2):** chip borders use `outline` (3:1 or more) instead of `outlineVariant` (1.2:1).

## Settled between the reports
- **The used-up notice:** review B's copy (UX-1009) wins over review A's English (part of UX-916), because it drops «formulario» and "form" in all three languages.
- **The new project's chip:** review C's «{name} (nuevo)» is used everywhere (UX-1104). Review A had asked for just «Física» next to the project card (part of UX-916).
- **A new project with a deadline-only task:** that case lands on the project's page (UX-906), not on Calendar's 12th (UX-902). The message still says «vence el …».
- **The keep question:** review A's spoken copy, plus «¿Conservar el texto…?» for typed words. This keeps the 2026-10-14 rule (UX-605, UX-612) that one question covers typed words.
- **The expired-code line:** «Pide otro cuando acabe la cuenta atrás» becomes «Toca «Reenviar código» cuando acabe la cuenta atrás». The screen's button has one name (UX-1204).
- **The button's labels:** they reuse `saveChangesSentence`. The title-case `saveChanges` that review A noted is unused, and goes.
- **Review C's note** that a search by person and project drops the person joins UX-907.
- **Two findings come from review B's notes,** and the organizer set their severity:
  - UX-1011: saves from the widget, a shortcut or a share land on a hidden Calendar.
  - UX-1012: chip borders are nearly invisible.

## Skipped
- **Whole findings:** none.
- **Server-side parts, waiting with their decisions:**
  - UX-1102's names for Google accounts (D8);
  - UX-1206's 429 with Retry-After (D9).
- **Needs a staging measurement:** UX-912 (D11).
- **A known server gap:** the code email's footer is still in English (`Backend/docs/EMAIL_VERIFICATION.md`). Review D noted it.

## Notes for the main session
- **Real-model checks on staging:**
  - P127's five phrasings, in ES and CA. If two or more come back as commands, raise UX-901 to S4 and tell the owner.
  - D11's measurement.
- **Catalan to read with a native speaker:**
  - «Correu brossa» and «Promocions» (UX-1205);
  - the Catalan the organizer wrote: `captureKeepTextQuestion`, `commandFindProjectPerson`, `commandFindProjectMine` and `verifyEmailCodeSpentWait`.
- **Previews:** the form previews come from `--dart-define=WRITE_FORM_PREVIEWS=true test/new_task_form_test.dart`, which isn't in CLAUDE.md's list. No preview renders the command cards, the monthly notice or «Confirma tu correo». Review A asks for review-preview shots of a change, a deletion, a search and a project card, in light and dark.
- **Evidence:** so far it is code and renders only. Every phone check is listed in each package's `deviceChecks`.
- **After the run:** regenerate `PHONE_CHECKS.md` with `phone_checks.py`.

## Round 2 (b1)

Round 1 (P127–P132) passed its round check, no test failed, and every finding was fixed. Round 2 fixes the three regressions the reviewers found, in three small packages; nothing is escalated and there's no new owner question.

### P145 · S2 · C · S · The people row marks the chosen chip with ✓ again, and still fits two rows
- **UX-1214 (S2), R1C-1 from P131:** the three `showCheckmark: false` lines go, so the chosen chip shows ✓ as on Calendar and Tareas. To keep «Todas» + «Para mí» on one row at 2× on 320 dp (P131 measured 281 dp against 272 dp with the ✓), the people row's chips and the pair's chips get 4 dp side padding instead of 8.
- **Settled here:** review C asked for the ✓ back; P131's implementer had removed it to keep Paul on screen (UX-1101). Both stand. The ✓ is not traded for layout, and the implementer reports the measured widths in ES and CA.

### P146 · S1 · A · S · Deshacer from a voice-made project's page also closes a task opened from it
- **UX-1212 (S1), R1A-1 from P129:** on Deshacer, pop every route above the project page and then the page itself (instead of `removeRoute`), and then reopen the result.

### P147 · S1 · B · M · Deshacer puts back the filter a landing widened
- **UX-1213 (S1), R1B-1 from P130:** a landing that widened «Para mí» or the project filter records the scope it replaced. The form's, the capture's and the command result's Deshacer put that scope back, but only if the filter is still the one the landing set. No copy change. It runs after P146, because both edit `_apply`'s Deshacer.

### Phone checks added
- P145: at the largest font, the chosen chip shows ✓ and both names show without swiping.
- P147: on Calendar under «Para mí», say «Ana tiene que llamar al médico mañana», save, then tap Deshacer: «Para mí» comes back.

## Round 2 (b2)

Round 1 of b2 (P133–P138) failed its round check on one test: UX-909's confirming button doesn't wait for a chip. Every other finding in it was fixed. Round 2 retries UX-909 and fixes the five regressions in two packages. Nothing is escalated: UX-909 has failed once. There's no new owner question.

### P148 · S2 · A · S · The «Crear el proyecto» question holds its tasks until a chip is tapped; the sheet picks nothing for it
- **UX-909 (S2), second attempt:** P135's question and both answers work. But the server files the dictation's task in «Física y Química» already, so `_draftReady` counted it as ready, and one tap saved it there with the question unanswered. Now `_undecided` also collects the matched project's id of every card that still asks, and a task filed there waits, as with the two-matches card. With only that task, the button reads «Revisa los detalles» until a chip is tapped.
- **UX-1219 (S1), regression R1A-1 from P135:** «Otro proyecto…» opens the project sheet with «Sin proyecto» highlighted. A new `selectedNone: false` from the question's chips means no row is highlighted while it asks.
- **Settled here:** the reviewer's first option. Disabling the whole button while any project card asks would also hold back unrelated tasks.

### P149 · S2 · D · M · Confirm your email, reopened after a restart: a way out of a forgotten password, the real countdown, no flash, no stale address
- **UX-1215 (S2), regression R1D-1 from P134:** the wrong-password line names the way out: «Esa contraseña no es la de esta cuenta. ¿No la recuerdas? Toca «Usar otro correo» y crea la cuenta de nuevo.» (EN and CA in the brief).
- **UX-1216 (S1), regression R1D-2 from P134:** the reopened screen counts from when the code went. `resume()` returns the saved time, and «Reenviar código» waits only what's left of the minute.
- **UX-1217 (S1), regression R1D-3 from P134:** the pending address is read while the session restores, and the screen opens with no slide, so «Inicia sesión» doesn't flash first. The flash is inferred from the code.
- **UX-1218 (S1), regression R1D-4 from P134:** any successful sign-in forgets the pending address, whatever the account.
- **Settled here:** review D left it to the organizer whether the longer line shows after two refusals or from the first. It shows from the first: no counter, and its question form fits a typo too.

### Phone checks added
- P148: with the real model, «Crea el proyecto Química y apunta repasar el tema 3 en él» beside «Física y Química» waits for a chip.
- P149: with «No mantener actividades», come back from Gmail: «Confirma tu correo» shows without «Inicia sesión» sliding away first, and «Reenviar código» is on if more than a minute has passed.

## Round 3 (b2)

Round 2 (P148, P149) passed its round check with no failing test, and both reviewers wrote all six findings `fixed`. The workflow didn't read their statuses (written as headings, not table rows), so round 3 re-confirms them without code changes, and fixes the one new regression. Nothing is escalated, and there's no new owner question.

### P150 · S2 · A · S · Re-confirm the «Crear el proyecto» question fixes (no code change)
- **UX-909 (S2):** re-confirm only. The round-2 reviewer found it fixed (verify-b2-r2-A): a task filed in the matched project waits for a chip. Not a new attempt.
- **UX-1219 (S1):** re-confirm only. Found fixed in round 2: «Otro proyecto…» opens the sheet with no row highlighted.

### P151 · S2 · D · S · Back from the reopened «Confirma tu correo» plays the usual transition; re-confirm P149
- **UX-1220 (S1), regression R2D-1 from P149:** Back from the reopened screen was 150 ms quicker than every other Back. Delete the 300 ms `reverseTransitionDuration` override, so the theme's own duration applies.
- **UX-1215 to UX-1218:** re-confirm only. The round-2 reviewer found all four fixed (verify-b2-r2-D).

### Phone checks added
- P151: after a restart, Back from «Confirma tu correo» closes with the same animation as Back from any other screen.

## Re-plan after decisions (2026-10-19)

**Summary.** The owner is away, so the main session answered D1–D11 with the organizer's recommendations (DECISIONS.md, 2026-10-18 night). It also decided UX-815, two items from the website review and a list of the tasks that hold files. They become 13 fixes in 8 packages (P152–P159), which run after b3 (P139–P144, unchanged). D5, D10 and D11 need no work and are closed, so no owner question is left from this run.

Nothing here slows a capture. A command result with nothing to add closes without a question, a dictation carried into the form keeps its day, and a task added under a person's chip needs no extra tap.

### Decisions
None open. Where each answer went:
- **D1 (UX-917):** Cancelar on a result with nothing to add just closes → P152.
- **D2 (UX-918):** dictated words carried into the form by «Escribir» get their day and time read; typed titles stay as typed → P153.
- **D3 (UX-919):** «Guardar como tarea» / "Save as a task" / «Desa-ho com a tasca» → P152.
- **D4 (UX-920):** a search with a period lists by day and time, soonest first → P152.
- **D5 (UX-921):** the button stays «Nueva tarea» → closed, no work.
- **D6 (UX-1010):** Back on a new task shows the add message → P153.
- **D7 (UX-1111):** a task added under a person's chip is that person's → P159.
- **D8 (UX-1102, UX-1112):** Google names come from the server (41c00f3); password accounts are asked once → P155.
- **D9 (UX-1206):** the resend limit says how long to wait; the server half is d447c5c → P156.
- **D10 (UX-1211):** no «Abrir el correo» → closed, no work.
- **D11 (UX-912):** measured, no slowdown, so the flag stays → closed, no work.

Also decided for the owner the same night, and packaged here:
- **UX-815:** confirm a deletion with Google → P157. It keeps its ID from run 2026-10-15-deletion.
- **UX-1221 (new, website review WD7):** the app says subscriptions come on iOS too → P158.
- **UX-1222 (new, website review WD11):** no link to the Privacy Policy or the Terms → P158.
- **UX-1223 (new, from UX-506):** a full file space gives no way to find the files → P154.

### Packages, in order
b3 runs first: P139–P144, as planned above and unchanged. Then b4 and b5. The full briefs are in `plan.json`.

#### b4

### P152 · S2 · A · M · Command results: Cancelar just closes, «Guardar como tarea», a period's search by day
- **UX-917 (S2, D1):** with no task or note to add, Cancelar, Back and the scrim discard the result at once. Results with a task still ask.
- **UX-919 (S2, D3):** the fallback is renamed «Guardar como tarea» / "Save as a task" / «Desa-ho com a tasca» in the catalogs, comments, previews and tests.
- **UX-920 (S1, D4):** a search with a period lists by day and time, soonest first, as Calendar orders a day. Other searches stay newest first.

### P153 · S2 · A · M · The new-task form: dictated words keep their day; Back says what was added
- **UX-918 (S2, D2):** words dictated before «Escribir» open the form with their day and time read. «a las 5» keeps its words in the title and sets no time. Typed titles, shares and typed captures stay as typed.
- **UX-1010 (S1, D6):** Back on a new task says «Añadida al lun, 19 oct», «Añadida · vence el …» or «Añadida sin fecha», with Deshacer. A deadline-only task lands on its due day.

### P154 · S2 · B · M · A full file space lists the tasks that hold files
- **UX-1223 (S2):** when the account's own space is full, «Ver tareas con archivos» shows beside «Ver Pro» and on the Pro screen's storage line. It opens a list of the account's tasks with files, largest first, and each row opens its task.

### P155 · S2 · C · L · Real names: Google's at sign-in, and a password account asked once
- **UX-1112 (S2, D8):** right after its first invitation or its first join, an account with no first name is asked «¿Cómo te llamas?», once. The name is prefilled from the email, can be skipped, and is sent with `PATCH /api/auth/me/`.
- **UX-1102 (S2, D8):** Google's half is on the server (41c00f3). The package checks that every place shows the server's name.

### P156 · S2 · D · M · «Reenviar código» past the server's limit says how long to wait
- **UX-1206 (S2, D9):** a 429 `resend_limited` of over a minute shows «Has pedido muchos códigos. Espera 30 minutos para pedir otro.». «Reenviar código» stays off and counts minutes, then seconds. It builds on P143's countdown.

#### b5

### P157 · S2 · D · M · Delete my account: confirm with Google instead of a forgotten password
- **UX-815 (S2):** an account with a password and Google linked can confirm with «Confirmar con Google», under the password. A wrong password there names that button.

### P158 · S2 · D · M · Links to the Privacy Policy and Terms; the app says Android only
- **UX-1222 (S2):** «Política de privacidad» and «Términos y condiciones» show under sign-in's card and in Otros ajustes. Each opens the site's page in the app's language.
- **UX-1221 (S1):** the line reads «Las suscripciones están disponibles en la app para Android.», without iOS.

### P159 · S1 · C · L · A task added under a person's chip is that person's
- **UX-1111 (S1, D7):** on a project page with Ana's chip on, the form and the capture card start the task as Ana's, and one tap changes it. A person named in the words wins, and the page keeps Ana's chip.

### Settled here
- **D1 and the keep question:** the question depends on whether a task or a note is still to add. Command cards on their own never ask.
- **D2's bare hour:** «a las 5» keeps its words in the title and sets no time. The form has no morning-or-afternoon question, and the phone doesn't guess.
- **D2's deadlines:** «antes del viernes» becomes the task's deadline. So P153 also makes the form's message and landing handle a deadline-only task, as P129 did for the sheet.
- **D7 in the capture sheet:** it applies there too, for Pro and for free accounts with dictations left. A person named in the words wins.
- **D8's moment:** the name is asked after the first invitation goes out or after the first join, not before. So the first invitation carries the email's first part. No way to change the name later is added.
- **D8's prefill:** the part of the email before the @, cut at the first dot, underscore, hyphen, plus or digit, with a capital first letter («paul.smith84» → «Paul»).
- **D9's short wait:** a refusal of a minute or less (the one-a-minute limit) gets no «Has pedido muchos códigos» line, only the countdown. One early tap isn't many codes.
- **"The Account storage row":** Cuenta has none. The account's storage shows on the Pro screen, so the link goes there.
- **The files list:** it lists only tasks whose files use the account's own space (no project, or a project it owns), because storage is charged to the project's owner.
- **The legal links:** they go on the first screen as well as «Crea tu cuenta», because Google sign-in there creates accounts too. In Ajustes they go in Otros ajustes, not among the six main rows. No consent sentence is added.
- **The packages:** D1, D3 and D4 share one package (the command result). D2 and D6 share another (the form), and WD7 and WD11 a third (what the app says about itself).

### Closed
- **No change, by decision:** UX-921 (D5), UX-1211 (D10) and UX-912 (D11) move to Won't fix.
- **Recorded from the same DECISIONS entry, outside this run's findings:**
  - UX-616: server settings at the next deploy, cause server-side. It moves to Won't fix.
  - UX-812 and UX-814: not now. They move to Won't fix.
  - UX-813: later, with the deferred confirmation email. It moves to Won't fix.
  - UX-615 stays a decision until the §7 test with the owner's father.

### Notes for the main session
- **Batches:** b3 = P139–P144, b4 = P152–P156, b5 = P157–P159, each run with `only`. Set `recordMemory: false` on every batch except b5.
- **Server docs:** `Backend/docs/VOICE_COMMANDS.md:100` still says a search lists newest first. After P152, a search with a period lists soonest first.
- **The old name:** after P152, the phone checks that name «Guardar tal cual» (U7, UX-469, UX-701, UX-901) mean «Guardar como tarea». Regenerate PHONE_CHECKS.md after the run. The reviewer's memory names it too.
- **Deploys the phone checks need:**
  - P156 needs d447c5c on staging;
  - P155's Google names need 41c00f3 on staging;
  - P158's links load only once the site's legal pages are published (WD13).
- **Catalan the organizer wrote, to read with a native speaker:** `tasksWithFiles`, `tasksWithFilesHelp`, `tasksWithFilesRow`, `tasksWithFilesEmpty`, `storageSeeTasks`, `nameAskTitle`, `nameAskBody`, `verifyEmailResendInMinutes`, `deleteAccountGoogleInstead` and `deleteAccountWrongPasswordGoogle`. «Desa-ho com a tasca» comes from the decision.
- **Evidence:** this is a plan only, read from the code at 8993690. Nothing was run.

## Round 2 (b3)

Round 1 of b3 (P139–P144) failed its round check on one test: at 2× on 320 dp, a 40-character title still doesn't show whole in three lines (UX-1003). The reviewers found the other 17 findings fixed, and raised three regressions: one in the new «Elegir día» sheet (P139) and two in the new project rename (P141). Round 2 retries UX-1003 and fixes the regressions in two packages. Nothing is escalated, since UX-1003 has failed once, and there's no new owner question.

### P160 · S2 · B · M · The form's title shows whole once the keyboard is down; a year pick in «Elegir día» applies nothing
- **UX-1003 (S2), second attempt:** P139 capped the title at 3 lines. At 2× on 320 dp a line holds about 13 characters, so the father's «Llamar al médico el viernes por la tarde» needs 4 lines and its first line scrolled away, in the edit form too. Now the cap holds only while the title has the focus (keyboard up, Hoy and Mañana stay in reach). Without the focus the whole title shows. UX-1002 already drops the keyboard on every day and time tap.
- **UX-1224 (S2), regression R1B-1 from P139:** in «Elegir día», picking a year in the calendar's «octubre de 2026 ▾» header closed the sheet on a day nobody chose. Now only a tap in the day grid applies and closes. A year pick just moves the calendar, including a pick of the year already shown.
- **Settled here:** the cap that depends on the focus, over the reviewer's smaller `maxLines: 4`, which would still hide longer titles carried from a dictation. The day sheet's range stays 2000–2101: narrowing it would limit which days can be chosen and wouldn't remove the problem.

### P161 · S2 · C · M · Renaming a dictated project: an existing project's name files the tasks there; a pencil shows the row can be renamed
- **UX-1225 (S2), regression R1C-1 from P141:** renaming a dictated project to «Física», which the person already has, kept «Física (nuevo)», then filed the task into the existing «Física» at save. Now the rename acts like tapping that project's row: the card reads «Ya tienes «Física»» and the chip shows «Física».
- **UX-1226 (S1), regression R1C-2 from P141:** the dictated project's row in the project sheet gets a pencil at its end. TalkBack reads it as new copy: “Change the name” / «Cambiar el nombre» / «Canvia el nom».
- **Settled here:** a name that matches only a project the person can view stays a new project, with «(nuevo)», as when that name is dictated directly. A task can't go into a view-only project.

### Phone checks added
- P160: at the largest font on a 360 dp phone, type the 40-character title and tap Mañana: the whole title shows. In «Elegir día», tap the month header and then 2027: the sheet stays open.
- P161: with TalkBack, the dictated project's row reads its name and «Cambiar el nombre».

### Notes for the main session
- **Catalan the organizer wrote, to read with a native speaker:** `commandRenameProject` («Canvia el nom»).
- **Evidence:** this is a plan only, read from the working tree after b3 round 1 and from Flutter's `calendar_date_picker.dart`. Nothing was run.

## Round 3 (b3)

Round 2 of b3 (P160, P161) passed its round check. The reviewers found every finding fixed, and ux-tester reported no failing tests. One severity-1 regression came from P160, and the reviewer recommends no code change for it, so this round has no packages. It goes to the owner as D12.

### D12 · After a year pick, a day looks chosen but isn't (UX-1227, S1)
- **UX-1227 (S1), regression R2B-1 from P160:** in «Elegir día», after a year pick from the «octubre de 2026 ▾» header, Flutter's `_handleYearChanged` paints the same day number (or day 1) of that year as selected. The sheet rightly ignores the pick (`App/lib/widgets/schedule_editor.dart:321-330`), and the day-only sheet has no «Listo», so the sheet shows a choice nobody made. Nothing is lost: the form's chip shows the real day, and tapping any day applies it. Verified in code (the app and Flutter's source); no render shows it.
- **The two directions:** accept it as known Flutter polish, or build a custom displayed-month path for the calendar. Remounting the calendar with `initialDate: _day` clears the highlight but jumps back to the old month, which undoes the year pick. CalendarDatePicker can't show a month with nothing selected.
- **Recommendation:** accept it for now (subtract first) and check it on the phone. Only if the walk shows a real pause, plan the custom path as a fix.

### Phone checks added
- UX-1227: at the largest font on a 360 dp phone, open «Elegir día», tap the month header, then 2027. The sheet stays open with a day highlighted. Note whether that highlight makes you pause before tapping a day.

### Notes for the main session
- **No packages:** b3 has nothing left to fix. UX-1003, UX-1224, UX-1225 and UX-1226 wait for the close.
- **Evidence:** this is a plan only, read from verify-b3-r2-B.md and `schedule_editor.dart` in the working tree. Nothing was run.
