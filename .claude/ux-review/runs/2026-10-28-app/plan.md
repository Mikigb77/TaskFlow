# UX plan — the whole app, run 2026-10-28-app (2026-10-31)

Six reviews (A1, A2, B1, B2, C, D) filed 90 new findings, none at severity 4: nothing stops a core task, but a tick waits for the server, a reminder that just rang says «Sin recordatorio», and a reader's «Completar» makes an English «(offline copy)».
This plan fixes 89 findings in 30 packages (P266–P295), D9 and WD34 included. Two questions are yours (D1, D2). As you asked on 2026-10-31 («do everything»), the run goes straight to `ux fix`, and nothing waits for your answers.

Evidence: the UX preview suite at 6281e3d (486 renders with AUDIT.md: widget-test evidence), the calendar previews of 2026-10-29, and 238 captures from the TaskFlow_Review emulator (emulator evidence, not a phone). The app code hasn't changed since.

## Decisions for you

### D1 · Should «Guardar como tarea» show its one task before saving? (UX-2612)
- **Today:** it saves the phone's own reading at once, unseen: after the 8 s wait, after a failure, and on «No se encontraron tareas». UX_REVIEW §3.5 says "instantly", and your D3 approved that section.
- **The problem:** that reading is always one task. «Mañana, llamar al dentista y comprar pan» becomes one task with both things in its title. Every other result keeps a confirming tap (UX-615).
- **Already in this plan:** P273 makes the button a quiet text button while the assistant still works (UX-2103), so it gets pressed less by mistake.
- **Options:** (a) show it as a normal result card with «Añadir al calendario»: one more tap, on a rare fallback path, and the person sees the day it read and that it's one task; (b) keep it instant.
- **Recommendation: (a)**, as review A1 recommends. One small package after this run; reversible.

### D2 · Keep the time each task is completed, so Completadas lists the newest first? (UX-2311)
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
4. D2, if the owner says yes: a completion time per task and per repeat, server first.
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
