# UX plan — the whole app, run 2026-10-28-app (2026-10-31)

> **2026-11-01:** batch b1 is done and committed (P266–P277, with round 2's P296–P298; 5bcd6d9; `report-b1.md`): all 39 of its findings are closed, 31 verified and 8 waiting for a phone or the emulator. You answered D1 and D2 «both yes, as recommended». They are now P299 and P300, under «Re-plan after your answers (2026-11-01)» at the end, and run in batch b3 with P290–P295.

Six reviews (A1, A2, B1, B2, C, D) filed 90 new findings, none at severity 4: nothing stops a core task, but a tick waits for the server, a reminder that just rang says «Sin recordatorio», and a reader's «Completar» makes an English «(offline copy)».
This plan fixes 89 findings in 30 packages (P266–P295), D9 and WD34 included. Two questions are yours (D1, D2). As you asked on 2026-10-31 («do everything»), the run goes straight to `ux fix`, and nothing waits for your answers.

Evidence: the UX preview suite at 6281e3d (486 renders with AUDIT.md: widget-test evidence), the calendar previews of 2026-10-29, and 238 captures from the TaskFlow_Review emulator (emulator evidence, not a phone). The app code hasn't changed since.

## Decisions for you (both answered 2026-11-01)

### D1 · Should «Guardar como tarea» show its one task before saving? (UX-2612)
- **Answered 2026-11-01: (a), as recommended** (DECISIONS.md, 2026-10-31 (later)). Planned as P299, in batch b3.
- **Today:** it saves the phone's own reading at once, unseen: after the 8 s wait, after a failure, and on «No se encontraron tareas». UX_REVIEW §3.5 says "instantly", and your D3 approved that section.
- **The problem:** that reading is always one task. «Mañana, llamar al dentista y comprar pan» becomes one task with both things in its title. Every other result keeps a confirming tap (UX-615).
- **Already in this plan:** P273 makes the button a quiet text button while the assistant still works (UX-2103), so it gets pressed less by mistake.
- **Options:** (a) show it as a normal result card with «Añadir al calendario»: one more tap, on a rare fallback path, and the person sees the day it read and that it's one task; (b) keep it instant.
- **Recommendation: (a)**, as review A1 recommends. One small package after this run; reversible.

### D2 · Keep the time each task is completed, so Completadas lists the newest first? (UX-2311)
- **Answered 2026-11-01: (a), as recommended** (DECISIONS.md, 2026-10-31 (later)). The server half is done (8064257); the app half is P300, in batch b3.
- **Today:** Completadas follows the planned date, with undated tasks last. «Comprar pan» ticked by mistake this morning sits after months of dated history. A task due next month and done today sits at the top.
- **Why it's yours:** neither the app nor the server keeps a completion time (the server has only `updated_at`). Ordering by when each task, or each repeat, was done means storing that time with every tick, on the phone and on the server.
- **Already in this plan:** P269 keeps a reopened row in place until the page is left.
- **Options:** (a) yes: save each completion's time, and list Completadas by it, newest first; older completions keep today's order after them; (b) no: keep the planned-date order.
- **Recommendation: (a).** It's the smallest change that lets the page do its job, getting back what was just ticked. Nothing shows the time; only the order uses it. Server first, then one small app package.

## Settled here (each is a line to strike if you disagree)
- **WD34's reach (P269):** «Todo listo. Respira.» shows when a tick on a Calendar row leaves the day with nothing open. That covers today's overdue tasks too. You said "ticked in Calendar". So Completar on a task's own page and the voice «marca como hechas todas las de hoy» keep «Tarea completada», though reviews B2 and A2 asked for them. Either is a one-line extension.
- **D9's banner (P271):** on a task where a reader can now choose reminders, «Solo puedes ver esta tarea.» becomes «Solo puedes ver esta tarea y elegir tus recordatorios.» (review B2). Reviews C and D wanted no new copy. The old line would contradict a chip that now opens.
- **Button height (P289):** every filled button grows from 52 to 60 dp (review A1, for older hands). Review A2 suggested 56.
- **«A tu manera» and Google's AI (P282):** the privacy line shows the first time «A tu manera» is opened, under its field, in the capture sheet's new words: «Tus palabras van a la IA de Google. Más en Otros ajustes › Voz.»
- **Things removed:**
  - the grey microphone while nothing listens (UX-2106);
  - the scroll inside set cards (UX-2201);
  - «Quitar» inside «Más opciones» (UX-2208);
  - «Permitir avisos» next to Recordatorios' off switch (UX-2601);
  - the caveats paragraph on Calendarios del teléfono (UX-2610);
  - the character counters (UX-2505);
  - the search box on an empty new project (UX-2517);
  - «Grupos» on Proyectos until you have a group, a shared project or a group invitation (UX-2516).
- **Thing moved:** «Eliminar proyecto» leaves the «Compartir proyecto» page. It now sits in the project page's new ⋮, with rename and archive (UX-2503).

## Packages, in order (most severe first)
Each line: finding (its severity) — what changes. The packages' full instructions are in `plan.json`.

### Severity 3
**P266 · A · L — The listening sheet: «Escribir» on the online path, no microphone while nothing listens, TalkBack silent while recording**
- UX-2101 (S3) — on the online path (Catalan on the emulator, older phones), «Escribir» stays in every state; a tap stops the recorder and asks keep or discard only if something was heard.
- UX-2106 (S2) — the grey mic ring shows only while starting, listening or understanding; seven states lose it.
- UX-2107 (S2) — with TalkBack, «Escuchando» is said before the mic opens, nothing is said while recording, and 50 s is a pulse.
- UX-2111 (S1) — the first-use line: «Tus palabras van a la IA de Google. Más en Otros ajustes › Voz.»
- UX-2113 (S1) — the online hint: «Te escucho. Al tocar Listo verás lo que he entendido.»

**P267 · A · M — Command cards show every task they change**
- UX-2201 (S3) — set cards lose their inner scroll; every row is in the sheet's own scroll, and the button acts on what you can reach.
- UX-2204 (S2) — «¿Cuál quieres cambiar?» answers become outlined choices in the question box.
- UX-2209 (S1) — change lines name their field: «Prioridad: Media → Alta», «Fecha límite: …».
- UX-2210 (S1) — cards that found nothing show the search icon, not a pencil or a bin.

**P268 · B · S — Ticks, moves and steps show at once**
- UX-2301 (S3; with UX-2402) — six provider methods show the phone's list at once and sync behind, as saves already do.

**P269 · B · L — Today: its own tasks first, ticked rows stay, the day's last tick says «Todo listo. Respira.»** (after P268)
- UX-2302 (S3) — today's own rows come before «Atrasadas · N»; three overdue tasks no longer hide the day.
- UX-2304 (S2) — a ticked overdue row stays, struck through, and counts in «completadas»; a row reopened in Completadas stays too.
- UX-2303 (S2; with UX-2408) — WD34: «Todo listo. Respira.» / “All clear. Take a breath.” / «Tot fet. Respira.», with Deshacer.

**P270 · B · M — A reminder that rang says so**
- UX-2401 (S3) — «Recordatorio enviado: hoy, 09:40», or «Recordatorio pospuesto: hoy, 09:52», instead of «Sin recordatorio» (seen on the emulator).
- UX-2411 (S1) — «Recordatorio: 1 hora antes», plus «· fecha límite» only when it counts from the deadline.
- UX-2206 (S1) — a line that names itself («Recordatorios: cada 3 días…») shows once, without a «Recordatorio» title over it.

**P271 · B · L — D9: a reader chooses their own reminders; no «Completar» on a reader's reminders**
- UX-2032 (S1, decided) — a reader's reminder line opens the choices; the change syncs as the server now accepts, never as a copy; the banner says «…y elegir tus recordatorios».
- UX-2403 (S3; with UX-2602) — a reader's reminders offer only «Posponer 10 min»; the engine refuses an old «Completar»; the leftover copies say «(copia local)».

**P272 · D · M — Allowing notifications finishes turning reminders on**
- UX-2601 (S3) — after «No permitir» → «Permitir avisos» → Android's switch → back, reminders turn on with «Listo. Recordatorios activados.»; with the switch off, Recordatorios shows the switch alone.

### Severity 2
**P273 · A · L — Understanding and failing**
- UX-2102 (S2) — Cancelar, Back or a swipe during «Entendiendo…» ask keep or discard; Descartar cancels and costs no dictation.
- UX-2103 (S2) — at 8 s «Guardar como tarea» is a quiet text button; it's filled again after a failure.
- UX-2104 (S2) — offline: «Sin conexión. Toca Guardar como tarea o reinténtalo cuando tengas internet.»; unreachable: «Ahora no puedo convertir tus palabras en tareas; se conservan.»
- UX-2109 (S1) — at 2× the error banner shows whole; only the words scroll.
- UX-2105 (S1) — kept words are «conservadas», never «guardadas».

**P274 · A · M — After the tap** (after P269)
- UX-2202 (S2) — Deshacer after a voice change, completion or deletion just restores, with no red card again; «Eliminada: Dentista».
- UX-2203 (S2) — «2 tareas añadidas al jue, 29 de oct», and the landing keeps the day's heading in view.
- UX-2213 (S1) — «Ha vuelto aquí, sin guardar.» for one task.

**P275 · A · M — The result card** (after P270)
- UX-2205 (S2) — 8 dp between a row's title and its ✕, and around «Activar recordatorios».
- UX-2207 (S1) — a dictated note's field is «Tu nota».
- UX-2208 (S1) — «Más opciones» loses «Quitar»; an undated task's repeat row says «Añade una fecha para repetir».
- UX-2211 (S1) — TalkBack hears «Contraído» / «Desplegado» on «Más opciones» and on a batch row.
- UX-2212 (S1) — while «¿mañana o tarde?» is open, the date line shows the day only.

**P276 · B · M — «Sin fecha» means no day and no deadline**
- UX-2308 (S2) — one rule for Calendar's count, the Sin fecha page and Tareas' chip.
- UX-2307 (S2) — a dated save made from Sin fecha lands on Calendar, lit, with Deshacer.

**P277 · B · M — Phone events by name**
- UX-2306 (S2) — up to three event rows («Cita con el dentista · 17:00»), then «Ver los 5 eventos»; both sheets get «Cerrar».
- UX-2310 (S2) — event read errors use Calendar's «Toca para reintentar» line, in the Día view and the sheet.

**P278 · B · M — The Día view fits the screen**
- UX-2309 (S2) — one lane always fits beside the hours; titles end with an ellipsis.
- UX-2314 (S1) — no year in this year's header, no stray dash, TalkBack skips the hour labels (42 stops → 17).

**P279 · B · L — Task rows read whole and calm**
- UX-2305 (S2) — titles wrap in full.
- UX-1416 (S2, reopened) — with TalkBack, rows offer «Cambiar fecha» and no unnamed swipe actions.
- UX-2313 (S1) — «Venció el lun, 26 de oct», in grey, once.
- UX-2312 (S1; with UX-2512) — «Prioridad alta», «1 completada» when the day is done, «Toca» instead of «Pulsa».
- UX-2616 (S1) — «Necesita responsable» in grey, not red.

**P280 · B · M — A task's page** (after P279)
- UX-2404 (S2) — Completar returns to the list with «Tarea completada · Deshacer»; the page keeps the occurrence it opened.
- UX-2409 (S2; with UX-2507) — TalkBack reads «Notas» with the text, not an unnamed field.
- UX-2410 (S1) — one date row, «jueves, 29 de octubre · 12:00»; no «Sin hora».
- UX-2416 (S1) — labels as plain text, «#casa · #recados».

**P281 · B · L — The task form**
- UX-2406 (S2) — edits are saved if Android closes the app in the background.
- UX-2407 (S2) — the repeat sheet shows five one-tap rows; its dialog button says «Listo».
- UX-2413 (S1) — date and weekday chips 8 dp apart.
- UX-2414 (S1) — the keyboard's ✓ in the edit form only closes the keyboard.
- UX-2419 (S1) — the attach sheet explains phone-only files only when there is one.

**P282 · B · M — «A tu manera» and the reminder sheet's title** (after P266)
- UX-2405 (S2; with UX-2604) — the first «A tu manera» shows that its words go to Google's AI; Voz's note names reminders too.
- UX-2412 (S1) — «Recordatorio» stays fixed at the top on every task.

**P283 · C · M — Notas**
- UX-2501 (S2) — no «Añadir nota» in a project you only view; a note goes where Notas shows, never to another screen's filter.
- UX-2515 (S1) — «Todos los proyectos», and no filter before the first note.

**P284 · C · L — Sharing and group pages answer where you tapped**
- UX-2502 (S2) — rows change when the server answers; progress under the app bar; errors as a message; a failed rename keeps its text.
- UX-2511 (S1) — plain copy instead of «la próxima sincronización correcta» and «Mis asignaciones» (Catalan wants a native read).
- UX-2513 (S1) — addresses break after «@» and «.».
- UX-2518 (S1) — 8 dp between «Aceptar invitación» and «Ahora no», and between stacked dialog buttons.

**P285 · C · M — The group page** (after P284)
- UX-2504 (S2) — «¿Eliminar «Familia»? Sus miembros dejarán de verlo. No se puede deshacer.»; «Transferir a Ana» (Catalan wants a native read).
- UX-2505 (S2) — no «0/254» counters in seven dialogs.
- UX-2519 (S1) — section titles are headings for TalkBack.
- UX-2520 (S1) — «Invitar a una persona» filled and first.

**P286 · C · M — A project's own page**
- UX-2503 (S2) — a ⋮ on the page with rename, archive and delete; delete leaves the sharing page.
- UX-2516 (S1) — «Grupos» only once it matters.
- UX-2517 (S1) — no search on an empty project.

**P287 · C · M — Novedades**
- UX-2506 (S2) — its own icon (a news page), not the people icon.
- UX-2508 (S2) — «Ana ha movido: Recoger a los niños»; the server half is a note below.
- UX-2615 (S1) — «Actividad» is one TalkBack stop.

**P288 · C · M — Searches clear in one tap**
- UX-2509 (S2) — a ✕ in the four search fields, «Borrar búsqueda».

**P289 · D · M — Bigger primary taps**
- UX-2108 (S2) — filled buttons 60 dp tall (from 52).
- UX-2608 (S1) — two-line labels padded and centred.

**P290 · D · M — Pro and its row in Ajustes**
- UX-2603 (S2) — three lines, in the site's words: «Dictados y espacio para archivos sin límite» · «Tus frases escritas se convierten en tareas» · «Pide los recordatorios con tus palabras».
- UX-2605 (S2) — Ajustes' Pro row shows «Te quedan 4 dictados gratis este mes» or «Pro está activo».
- UX-2607 (S1) — «El 1 nov tendrás más.», «100 MB» kept whole, «las condiciones de cualquier prueba».

**P291 · D · S — Sign-in**
- UX-2606 (S2) — the first screen's heading: «Entra o crea tu cuenta».
- UX-2611 (S1) — recovery's two links 8 dp apart.

### Severity 1
**P292 · A · S — From outside the app**
- UX-2110 (S1) — a double tap on the widget opens one sheet.
- UX-2112 (S1) — adaptive shortcut icons, so the glyph reads at about 16 dp instead of 5.

**P293 · B · S — Small task fixes**
- UX-2415 (S1) — each step read once.
- UX-2417 (S1) — «mié, 18 de nov» never splits.
- UX-2418 (S1) — «Quitar archivo» in Spanish.

**P294 · C · M — Pickers and notes**
- UX-2514 (S1) — a ✓ on the current choice in four sheets.
- UX-2510 (S1) — a note is «esta nota», not «esta tarea».
- UX-2614 (S1) — the task page's chips 8 dp apart.

**P295 · D · S — Settings odds and ends**
- UX-2610 (S1) — no caveats paragraph on Calendarios del teléfono; whole addresses.
- UX-2609 (S1) — the language sheet closes at once.
- UX-2613 (S1) — the Spanish widget help names «Dictar una tarea» and «pantalla de inicio».

## Skipped
- UX-2402, UX-2408, UX-2507, UX-2512, UX-2602, UX-2604: duplicates, merged into UX-2301, UX-2303, UX-2409, UX-2312, UX-2403 and UX-2405.
- UX-2617: the invitation email links the bare website instead of the invitee's language. Cause server-side: a note for the main session, below.

## For the main session
1. UX-2508's server half: each Novedades item carries its changed `fields` (`Backend/core/group_views.py:325`). P287 reads them when present.
2. UX-2617: link `/es/` or `/ca/` by the email's language in `Backend/core/invitation_email.py:18`, as the app's `site_links.dart` does.
3. D14 (2026-10-13), Google invitees join without the code: decided, still not built (review C).
4. D2, if the owner says yes: a completion time per task and per repeat, server first. **Done:** the owner said yes; the server half is 8064257 (migration 0026), and the app half is P300.
5. Previews: render each area within one day, or have `dayLabel` read the clock seam (reviews B1, C). P269 fixes the calendar fixtures' «Comer con Ana».

## Noted in the reviews, not planned
- Snackbars look like task cards (review B1). The look comes from the 2026-09-21 design refresh, so it's a design call.
- «Para mí» alone on a second chip row at 1× in Spanish (review B1). There are two ways to fix it, and no reviewer chose.
- Voz's long privacy paragraph (review A1). No copy was proposed; P282 changes one sentence.
- «Mediana 0.18 s» in Diagnóstico de captura: a debug screen.
- The same flag icon for deadline and priority on a task's page (review A2). Not filed.

## Waves
Six, as the fix workflow will plan them:
1. P266, P267, P268, P270, P276, P278, P281, P284, P287, P290, P291, P292
2. P269, P271, P273, P282, P285, P293, P295
3. P272, P274, P279, P286
4. P275, P277, P280, P283
5. P288, P289
6. P294

## Round 2 (b1)

Round 1 of batch 1 ran P266–P277. The reviewers found 2 findings only partly fixed: UX-2203 and UX-2032, each failing for the first time. They also found three regressions, now UX-2618 to UX-2620. The round check failed on one app test: UX-2203 at ES 1× on 360×800. The other failure was the date-dependent UX-1405 test, which fails only on Sundays and is already fixed.
Round 2 has three packages, P296 (S3), P297 (S2) and P298 (S2). They share no app file, so they can run side by side. There are no new decisions and nothing is escalated. D1's and D2's packages from the re-plan now start at P299.

The briefs are in `plan-b1-r2.json`.

### Settled here
- **UX-2203's 360×800 check changes.** At 360×800 the day heading and both lit rows need 474 px, and only about 429 px sit above the message. P274's brief already let the heading scroll away when it doesn't fit. So the day is now named in the message instead, using the reviewer's fix with no new copy. The tester's 360×800 heading assertion becomes a message assertion. 393×852 keeps the heading check.

### Packages, in run order

#### P296 · D9: a reader's reminder choice is sent, never copied, even when the owner changed the task first · B · M · after P271
- **UX-2032** (S1; the gap is S3; partly fixed, failed once). Round 1 is verified for the reader's page, the banner and the chip, and for the 200 path and the 409-between-GET-and-PUT path. The problem is the stale case. A reader's row is sent only when everything except its reminders still equals the server's copy. So when the owner changed the task before this phone pulled the change, the reader got a «(copia local)» task and the red notice. Now a persisted marker set by `updateOwnReminders` (and cleared by any other write) sends a reminders-only row with `_sendReminders` whatever else differs. On 200 the row takes the server's task and keeps the reader's reminders (`acceptKeepingReminders`, not `acknowledge`, which would have kept the old title under the new version). A demoted editor's real edit keeps today's copy-and-notice path.

#### P297 · After a voice save or Deshacer: the message names the landing day, Deshacer lands on what came back, and «¿Cuál…?» opens at its top · A · M · after P274, P267
- **UX-2203** (S2; partly fixed, failed once). Part 1 holds. At 360×800 the heading still scrolls away, and «3 tareas añadidas · también el vie, …» names no day for the lit rows. Now a save across several days starts with the landing day: «2 tareas añadidas al dom, 1 de nov · también el vie, 6 de nov» (`captureTasksAddedOn` / `taskAddedOn` plus `captureAlsoOn`). The same applies on the command path. The landing scroll is unchanged.
- **UX-2619** (S2; R1A1-2). Deshacer on a voice deletion or change of a task on another day changed nothing on screen. Now Deshacer sets `CalendarFocus` on the earliest day of what came back, so Calendar lands on those tasks, lit, as a save does.
- **UX-2618** (S1; R1A1-1). At 2×, «¿Cuál…?» opened past its top, with the ✕ at 48 × 32 dp. Now a `_Choice` card is revealed at its top (`alignment: 0`), as a set's heading is.

#### P298 · «Añade una fecha para repetir» opens the date sheet · A · S · after P275
- **UX-2620** (S2; R1A2-1). With no day, the repeat row in «Más opciones» gave an instruction but had no tap. Now it opens the date sheet, with a chevron, as «Para recordártelo, ponle un día.» does.

### Escalated
None: no finding has failed twice.

### For the main session (noted by the implementers, not by a reviewer, so not planned)
- P269's implementer: Tareas' `_openHere` (`home_screen.dart:446`) checks only TickerMode, so a row ticked on Tareas stays in place across a switch to Calendar and back. The same `Visibility.of` check would fix it.
- P275's implementer: AUDIT still counts 0 dp vertical gaps between a collapsed row's title and its «Fecha y hora» line in `capture/result · several`. The reviewer judged this outside UX-2205.

## Re-plan after your answers (2026-11-01)

You answered D1 and D2 «both yes, as recommended» (DECISIONS.md, 2026-10-31 (later)). Two new packages build them: P299 for D1, and P300 for D2's app half. They run in batch b3 with P290–P295, and P266–P298 are unchanged. With these two, the plan fixes 91 of the reviews' findings in 32 packages (P266–P295, P299, P300); round 2 of b1 added P296–P298 for three regressions.

### Where the run is
- **Batch b1 is done:** P266–P277, and round 2's P296–P298 (`plan-b1-r2.json`). All 39 of its findings are closed: 31 verified, and 8 waiting for a phone or the emulator. Nothing was escalated. It's committed in 5bcd6d9, and the report is `report-b1.md`.
- **Batch b2 is next:** P278–P289, as planned.
- **Batch b3 is last:** P290–P295, then P299 and P300. None of these eight packages shares a file, so they all run side by side.

### The answers, and where they go
- **D1 · UX-2612 (S2) → P299.** «Guardar como tarea» now shows the phone's reading on a normal result card, and only «Añadir al calendario» saves it. That covers every place the button appears: after the 8 s wait, after a failure or the dictation limit, on «No he encontrado ninguna tarea…», and on a command result that found nothing.
- **D2 · UX-2311 (S2) → P300.** Each tick keeps its own time on the phone, and the next sync sends it, even after time offline. Completadas lists the newest first, and completions without a time follow in today's order. The server half is already done (8064257: migration 0026, `Backend/docs/COMPLETION_TIMES.md`), so no server work is planned.

### Settled here (each is a line to strike if you disagree)
- **«Guardar como tarea» keeps its name and its places** (D3 of 2026-10-18; P273's quiet button while the assistant works). The card's button is the one any one-task result shows: «Añadir al calendario» with a day, «Añadir tarea» without one.
- **Deshacer gives a completion back its own time.** After «Reabrir» and then «Deshacer», a task goes back to its old place in Completadas, not to the top.
- **Exportar e importar keeps the times**, as it already keeps completion dates. An older app opening such a file warns about fields it doesn't know.
- **No time shows anywhere.** Only the order uses it, as D2 says.

### New packages, in order
**P299 · S2 · A · M — «Guardar como tarea» shows its task first** (after P273)
- UX-2612 (S2) — «Mañana, llamar al dentista y comprar pan» shows as one card, «Llamar al dentista y comprar pan», for tomorrow, and only «Añadir al calendario» saves it. A late answer from the assistant still changes nothing.

**P300 · S2 · B · L — Completadas lists the last thing done first** (after P269)
- UX-2311 (S2) — each tick's time is stored on the phone (schema 21) and sent as `completed_at` or `completed_times`, a notification's «Completar» included. «Comprar pan», ticked this morning, comes first. A row reopened on the page keeps its place until you leave.

### Ledger
- UX-2612 and UX-2311 move from «Decision needed» to «Open», planned in P299 and P300.
- Still yours: U13 (with U10 and UX-331), and UX-615 (the confirming tap stays until the §7 test; D1 adds no tap anywhere else).
- No new IDs, and nothing skipped.

### For the main session
1. Before P300's device check, the local Docker API needs migration 0026 (RESUME.md: `docker compose up -d --build`, then `migrate`).
2. D2 stores a new piece of data on the server: when each task was completed. The website's privacy text already lists «completion history» (`../TaskFlowWeb/src/content/legal/en.ts:30`); the `/ux-web` changes run in RESUME.md should confirm that covers it.
3. U7's phone check gains a tap: in airplane mode, «Guardar como tarea» now shows the card, and «Añadir al calendario» saves it.
4. plan.json's shared conventions, written 2026-10-31, still call D1 and D2 open. P299's and P300's briefs say they're answered, and no other package touches either one.

## Round 2 (b2)

Round 1 of batch 2 ran P278–P289. The reviewers found one finding only partly fixed: UX-2108, failing for the first time (the form's primary is still 54 dp). They also found 11 regressions, now UX-2621 to UX-2631. The round check failed on one app test, UX-1628's 31-minute return at ES 2×, which the tester bisected to P289's taller button; that failure is UX-2629. Its two other failures were tests P280 rightly broke, already updated.
Round 2 has five packages, P301–P305, all S2 at most. They share no app file, so they can run side by side. There are no new decisions and nothing is escalated.

The briefs are in `plan-b2-r2.json`.

### Settled here
- **Completar holds the page for 300 ms, and «Añadir tarea» ignores taps while a page above it is leaving** (UX-2623). The reviewer offered either; the page's hold alone can't cover a tap at 400 ms, because the page's exit transition that follows still lets taps through. The second half is one check in TaskActions, with no timer and no new state, and it covers Calendar, Tareas and the Día view.
- **The three icon buttons keep their icons** (UX-2630). The reviewer's subtract-first alternative was to drop them. Download and upload name the two directions on Exportar e importar, so `textWidthBasis: longestLine` centres icon and label instead.
- **The form's ElevatedButton stays an ElevatedButton** (UX-2108). Only its theme gets the filled theme's 60 dp, so its tests and look don't move.
- **Pinning stays on Proyectos only** (UX-2628). It's removed from the project page's ⋮, where nothing visible happened.

### Packages, in run order

#### P301 · The repeat sheet: the choices set apart from their details, and Listo always in view · B · S · after P281
- **UX-2621** (S2; R1B1-1). The interval row «Cada semana / Intervalo de repetición» read as a sixth choice. Now a divider separates the five choices from the ticked one's details.
- **UX-2622** (S2; R1B1-2). At 2× with «Cada semana», Listo was about 200 dp below the screen. Now Listo is pinned under the scrolling part.

#### P302 · A task's page: a second tap on Completar lands on nothing, and the time wraps with its dot · B · M · after P280
- **UX-2623** (S2; R1B2-1). A second tap on Completar landed on Calendar's «Añadir tarea» and started listening. Now the button stays disabled as «✓ Completar» for 300 ms before the page closes, and «Añadir tarea» ignores taps while a page above it is still leaving.
- **UX-2624** (S1; R1B2-2). «domingo, 1 de noviembre ·» / «21:00». Now a no-break space after the dot wraps «· 21:00» as one piece.

#### P303 · Novedades gets an icon of its own; a gone project, an offline refresh and pinning on a project's page say what happened · C · M · after P283, P284, P286, P287
- **UX-2625** (S2; R1C1-1). `feed_outlined` looked like the Notas tab's icon. Now it's `campaign_outlined`, a megaphone the app doesn't use anywhere else.
- **UX-2626** (S1; R1C1-2). Notas called a project that's gone «solo lectura». Now the bar shows only for a project the account sees but can't edit, and «Añadir nota» saves with no project.
- **UX-2627** (S1; R1C1-3). The group page's pull-to-refresh failed silently offline. Now it shows the network message and keeps the page.
- **UX-2628** (S1; R1C2-1). «Fijar proyecto» on a project's page changed nothing visible. Now it's left out of the page's ⋮ and stays on Proyectos.

#### P304 · Every primary is 60 dp, and wrapped button labels centre with their icon and clear their edges · D · M · after P289
- **UX-2108** (S2; partly fixed, failed once). Round 1 made every FilledButton 60 dp. The form's primary is an ElevatedButton and was still 54 dp, flagged in form/* and tasks/project.person-form. Now its theme is 60 dp too.
- **UX-2630** (S1; R1D-2). At 2× the icon of three centred labels sat at the left edge. Now each label hugs its longest line, so icon and label centre together.
- **UX-2631** (S1; R1D-3). «Elegir archivo para importar» touched its edges at 2×. Now outlined buttons get 8 dp above and below a wrapped label, still 52 dp at one line, and that label is centred.

#### P305 · Return to today lands at the top again, whatever the bottom bar's height · D · S · after P289
- **UX-2629** (S2; R1D-1; it breaks UX-1628). After a Friday landing, a return 31 minutes later left today's agenda at 321 dp at 2×. Now `_comeBack` cancels any landing reveal and is the last thing to set the offset. The 60 dp button stays.

### Escalated
None. UX-2108 has failed once.

### For the main session (noted by the implementers, not by a reviewer, so not planned)
- P289's implementer: two FilledButtons wrap their label in their own `Padding(vertical: 12)` (delete_account_screen.dart:440, device_calendar_events.dart:354), so they're now about 69 dp. That inner padding could go.
- P289's implementer: `App/test/support/button_label.dart` is untracked, as are P285's `App/test/support/no_counter.dart`. Both go in the round's commit.
- P287's implementer: Novedades reads «ha movido» only once the server sends `fields` on 'updated' items (Backend/core/group_views.py ~:325). RESUME.md says UX-2508's server half is committed in 85d7408, so check that before the device check.
- P284's implementer: on the sharing page, the owner's own row (`_personRow`) falls back to the account email, and that email doesn't go through `breakableAddress`.
- P282's implementer: words said or typed in «A tu manera» go to the server's AI (ai/reminder-plan/). The app now says so. The website's privacy text should agree (the `/ux-web` changes run).
- P279's and P285's implementers: worktrees wf_85968df4-719-2 to -8 and -25 are still under .claude/worktrees/. Every b2 package was found in the main checkout, so they can probably be cleaned up.
- Catalan native reads still pending: UX-2504's and UX-2511's new strings (P284, P285).

## Round 3 (b2)

Round 2 of batch 2 ran P301–P305. The reviewers found all its findings fixed, and the round check passed. Two new problems came from this round's changes, both in area B: UX-2632 and UX-2633.
Round 3 has two packages, P306 and P307, both S2 and size S. They share no file, so they can run side by side. There are no new decisions, and nothing is escalated.

The briefs are in `plan-b2-r3.json`.

### Settled here
- **The repeat sheet's foot edge tracks overflow, not position** (UX-2632). The reviewer marked the 1 dp line as optional. It's in, because the reviewer's verify step looks for it. It shows whenever the details can scroll and is transparent otherwise, so the sheet never jumps by 1 dp.
- **The whole task page is inert during the hold, app bar included** (UX-2633). The reviewer named the body and the bottom bar, but ✏ is in the app bar. One `AbsorbPointer` round the page's Scaffold covers all three. After the wait, the page pops if its route is current. If something opened over it (TalkBack can still reach it), the page clears the hold and shows the ticked task. If Back already popped it, it does nothing.

### Packages, in run order

#### P306 · The repeat sheet shows that its details go on under Listo · B · S · after P301
- **UX-2632** (S2; R2B-1). At CA 2× the sheet's scroll ends under «dl. dt. dc. dj.», and nothing shows that more follows. Now a scrollbar thumb shows while the details overflow, with a 1 dp line above Listo. At 1×, where everything fits, neither shows.

#### P307 · A task's page is inert while Completar closes it, and never stays frozen · B · S · after P302
- **UX-2633** (S2; R2B-2). If ✏ or a row opened something during the 300 ms hold, the page stayed frozen with Completar greyed out. Now the whole page ignores taps for those 300 ms, and if something did open over it, the page clears the hold and shows «Reabrir».

### Escalated
None.

### For the main session (noted by the implementers, not by a reviewer, so not planned)
- P302's implementer: `App/test/capture_landing_test.dart` UX-1628 failed on the seed code too, probably because of today's date. P305 has since fixed its cause (the round check passed), but it's worth re-running it on another day.
- P305's implementer: if someone leaves the app during a landing's reveal and comes back 30 minutes or more later, the reveal's paused loop could resume and jump down a screen at a time. A guard of a line or two in `_scrollToLit` would close it (for example, return when `_landedIds` is empty and no inbox row landed). It isn't a reviewer finding, so it isn't planned.
- P304's implementer: the form's wrapped primary label at 2× is left-aligned with its icon, not centred like the filled buttons. If centring is wanted, it's the same two-property pairing on its label. Also, `task_editor.dart`'s form body bottom padding went from 32 to 16 dp (outside P304's file list) to keep UX-1003's 2× fit.
- P304's implementer: the inner `Padding(vertical: 12)` on two FilledButtons (delete_account_screen.dart:440, device_calendar_events.dart:354) is still there, as noted in round 2.
- P301's implementer: AUDIT still flags 0 dp gaps between the repeat sheet's five rows, and weekday chips under 48 dp at 2×. Both predate P301.
- The verify note (B, round 2): screens without TaskActions under a leaving task page (Activity, the Notas list, Tasks with files) have no leaving guard. Only a tap more than 300 ms after Completar could reach them. Not a regression.

## Round 2 (b3)

Round 1 of batch 3 ran P290–P295, P299 and P300. The reviewers found every finding fixed except UX-2110, which is only partly fixed and has failed once. They also found five regressions, now UX-2636 to UX-2640. The round check passed. The debug APK build couldn't run here because this environment has no Android SDK, so this round's Android resource changes haven't been compiled.
Round 2 has five packages, P308–P312: two S2 and three S1. P308 and P309 share one test file. Otherwise no two packages share a file. There are no new decisions, and nothing is escalated.

The briefs are in `plan-b3-r2.json`.

### Settled here
- **An entry from outside the app is absorbed only by an empty sheet or form of its own kind** (UX-2110, UX-2637). A voice entry is absorbed by an empty voice sheet, and a text entry by an empty typing sheet. An entry that would open the form is absorbed by an empty new-task form, or by the month's used-up notice. An empty sheet of the other kind is closed first, so one sheet shows, in the mode the entry asked for. The reviewer let a text entry be absorbed by any empty sheet. That would leave the mic listening when the person asked to type, so it's out.
- **The words' card uses one wording for typed and spoken words** (UX-2636). It now says «Según tus palabras» / “From your words” / «Segons les teves paraules», and the button says “Keep my words” in EN. The reviewer's spoken-only variant would add strings, so it isn't used.
- **The Pro screen shows your plan first, for every account** (UX-2640). The reviewer offered this as the fallback. Fixing the icon size alone doesn't bring «Dictados gratis» into view at ES 2×: the three benefits still take about 9 lines. If the first benefit line no longer fits at CA 2× (UX-1613's test), only the file-space line goes back below the benefits.
- **A completion from before the update that is reopened and then undone gets today's time.** This is the second case of UX-2638. The contract can't send "no time", so the case is accepted.

### Packages, in run order

#### P308 · From outside the app: a second tap never stacks a second form, and the mic never lands on the keyboard · A · M · after P292
- **UX-2110** (S1; partly fixed, failed once). Round 1 covered the capture sheet. A free account's entry opens the task form instead, and a double tap there still stacked two forms. Now an empty new-task form absorbs it, and so does the used-up notice.
- **UX-2637** (S2; R1A-2). The widget's mic was absorbed by an empty typing sheet, which left the keyboard showing. Now the empty typing sheet closes, and a listening sheet opens in its place.

#### P309 · The words' card says «Según tus palabras», whether they were typed or spoken · A · S · after P299
- **UX-2636** (S2; R1A-1). Every spoken «Guardar como tarea» card said «Según lo que has escrito». Now it says «Según tus palabras» / «Segons les teves paraules». In EN, “Keep as typed” becomes “Keep my words”. No new key.

#### P310 · Completadas: ticking a row you just reopened puts it back where it was · B · S · after P300
- **UX-2638** (S1; R1B-1). When a row was re-ticked with its checkbox, it got today's time, so on the next visit it was listed first. Now Completadas passes back the time it remembered for the row.

#### P311 · The project sheet shows its last row whole · C · S · after P294
- **UX-2639** (S1; R1C-1). The handle and the heading pushed «Nuevo proyecto» half below the sheet's edge. Now the sheet is scroll-controlled, capped at 70% of the screen, like «¿Quién es responsable?».

#### P312 · The Pro screen shows your plan first, and its benefit checks stay small at large text · D · S · after P290
- **UX-2640** (S1; R1D-1). At 2× the benefit list hid «No hay una suscripción Pro activa» and the dictation count. Now the check icons stay 20 dp, and the status block comes before the benefits.

### Escalated
None. UX-2110 has failed once.

### For the main session (noted by the tester and the implementers, not by a reviewer, so not planned)
- **The debug APK build didn't run.** The tester's `flutter build apk --debug --no-pub --target-platform android-x64` stopped with «No Android SDK found», and the proxy refused dl.google.com, so the SDK couldn't be installed. Run the build on the Windows PC before the round's commit and the device checks. It's the only compile of P292's adaptive shortcut icons (`res/drawable-anydpi-v26/`, the new foreground vectors, `CaptureShortcuts.kt`) and of this round's Android resource changes.
- From P294's implementer: the ca 2× render of `tasks/detail.created-by` cuts «Ho veuen tots els membres.» behind the Completa / Canvia la data buttons, and the es 1× AUDIT has «Planificado para…» and «Prioridad Media» 1 dp apart. Not filed by a reviewer. Worth a look at close.
- From P293's implementer: ES `fileRemoveHelp` still says «Se eliminará de la tarea…» next to «Quitar archivo». «Se quitará de la tarea…» would match it. The reviewer noted the same.
- From P299's implementer: the result card shows the title above the date line, while D3's flow says the date comes first. The card's widgets were outside P299, and every result card shows the same order.
- From P300's implementer: Deshacer after a repeating task lost its repeat stamps restored dates that never had a time. The server applies the same rule.
- From P290's implementer: at ES 2× on Ajustes, «Otros ajustes» sits below the fold in `settings-tab.free`. Nothing is clipped.

## Round 3 (b3)

Round 2 of batch 3 ran P308–P312. The reviewers found every finding fixed (UX-2110, UX-2636, UX-2637, UX-2638, UX-2639, UX-2640; P308's device checks are still to do). They found two regressions, both from P308, now UX-2641 and UX-2642. The round check passed and no test failed.
Round 3 has one package, P313 (S2), for both regressions. They sit in the same check in `_openEntries`. There are no new decisions, and nothing is escalated: each regression is new, so neither has failed before.

The brief is in `plan-b3-r3.json`.

### Settled here
- **Absorbing and closing use different tests** (UX-2641). An entry absorbed by an empty sheet of its own mode loses nothing, so that test stays "no words, no result". Closing an empty sheet of the other mode needs the sheet's own test, "nothing said or typed", which counts a kept recording. The reviewer's one-word fix (`_hasInput` for both) would make an online-listening sheet non-empty within 120 ms, and a double tap would stack two listening sheets again (UX-2110), so it isn't used.
- **An entry lands only in a form an entry would open** (UX-2642): no day, project, person, words or capture. A voice entry also needs the form to have been opened to speak, so the used-up line shows. A text entry may land in either kind. An empty entry form that doesn't take the entry closes first, as an empty sheet of the other mode does (Back on a form with no title just closes, D12). This also covers the reviewer's note that a voice entry with dictations left opened its sheet over an empty text-entry form. In-app forms (with a day, project or person) are never closed or used: the entry's own form opens over them, as before P308.
- **The used-up notice** takes either kind of entry when an entry opened it: the notice itself says the dictations are used up. It's never closed.

### Packages, in run order

#### P313 · From outside the app: an entry never closes a sheet holding a recording, and lands only in a form it would open itself · A · M · after P308
- **UX-2641** (S2; R2A-1). In online listening, a paused voice sheet with a recording counted as empty, and a text tap closed it without asking. Now a sheet that keeps a recording is never closed: the typing sheet opens over it, and Cancelar shows it again.
- **UX-2642** (S2; R2A-2). Any empty form took an outside tap: the mic landed in a text form without the used-up line, and the widget landed in a form set to a picked day, list or person. Now only an empty form an entry would open takes it; an empty entry form of the wrong kind closes first; in-app forms get the entry's own form over them.

### Escalated
None.

### For the main session (noted by the implementers, not by a reviewer, so not planned)
- From P309's implementer: a code comment, `App/lib/models/capture_session.dart:21`, still names the old button `Keep as typed`. It isn't user-facing; it could say `Keep my words`.
- From P309's implementer: the Catalan «Segons les teves paraules» was written by the reviewer; a native read is welcome.
- From P312's implementer: the `settings/pro` file-space-full CA 2× render scrolls the button into view and drags back 200 dp, so the last benefit line sits cut at the list's top edge. Only the scroll position; AUDIT reports no cut text.
- The debug APK build is still owed from round 2 (no Android SDK here): run it on the Windows PC before the round's commit and the device checks.
