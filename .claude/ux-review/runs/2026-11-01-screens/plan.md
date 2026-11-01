# UX plan — scoped run 2026-11-01-screens (2026-11-01)

All seven findings that run 2026-10-28-app left open are fixes: two regressions in how a widget or shortcut tap lands (UX-2643 S2, UX-2644 S1), and five small S1 items.
There are four packages, P314–P317, no questions for you, and nothing skipped. P314, P315 and P316 run side by side; P317 follows P314, because both change the task form's file.

Evidence: no new review ran. Each finding keeps its ledger ID. The evidence is the reviewer's verify notes from run 2026-10-28-app: code read and widget tests, plus renders for UX-2634 and UX-2635. Nothing comes from a device. `../UX_REVIEW.md` isn't in this container, so I checked DECISIONS.md's open list instead. None of the seven touches U1–U14 or an open decision.

## Decisions for you
None.

## Settled here (each is a line to strike if you disagree)
- **What a tap from outside may close (UX-2643).** A widget or shortcut tap closes a form only if the form is exactly as it opened: nothing typed or picked, and «Más detalles» closed.
  - An open «Más detalles» counts as started. A step typed without Enter, or a file being picked, isn't in the form's own comparison yet.
  - Otherwise the tap opens its own sheet or form over the form, and Cancelar or Back shows the form again with everything in it.
  - A tap of the form's own kind is still taken by it, as before. That loses nothing.
- **One more look after a close (UX-2644).** After closing an empty sheet or form, the app checks once more whether what's now on top takes the tap. It closes at most one thing per tap.
- **The task page keeps Completadas' time (UX-2646).** This covers a task page opened from «Tareas completadas», whether the row was reopened on the list or with «Reabrir» on the page. Pages opened from anywhere else still stamp the current time, as their rows do (P310).
- **The reminder chip (UX-2635)** centres its wrapped lines only when it can be tapped, like a button. With no tap it's plain information, and its lines stay aligned left like the page's text. Either way the chip hugs its longest line, so the bell sits beside the words.
- **«Se quitará» (UX-2645)** changes Spanish only. English and Catalan already say "remove" (“This removes it from the task…”, «Es traurà de la tasca…»). «Tu archivo original no se elimina» keeps «elimina», because the original really isn't deleted.
- **The picker headings (UX-2647)** add no words. «Novedades del proyecto» keeps the project's name as a plain line under the heading.

## Packages, in order (most severe first)
Each line: finding (its severity) — what changes. The full instructions are in `plan.json`.

### Severity 2
**P314 · A · M — From outside the app: a tap closes only a form that's as it opened, and lands in the paused sheet a close uncovers**
- UX-2643 (S2; R3A-1 of P313) — a widget tap no longer closes a form with no title that holds a day, a reminder, steps or files. The tap's own sheet or form opens over it, and Cancelar or Back shows the form with everything in it.
- UX-2644 (S1; R3A-2 of P313) — Pro, online listening: mic, then text, then mic leaves one sheet, the paused one with its recording, instead of a second voice sheet over it.

### Severity 1
**P315 · B · S — The task page: Completar keeps Completadas' time, and the remove-file help says «Se quitará»**
- UX-2646 (S1) — a row reopened on «Tareas completadas» and ticked on its own page keeps its time and its place, instead of jumping to the top.
- UX-2645 (S1) — «Se eliminará de la tarea…» becomes «Se quitará de la tarea y, si lo has subido, de tus otros dispositivos al sincronizar. Tu archivo original no se elimina.»

**P316 · C · S — «¿Quién es responsable?» and «Novedades del proyecto» open with a heading**
- UX-2647 (S1) — both titles become headings, as the project and role sheets already are, so TalkBack says «encabezado». The project's name stays under «Novedades del proyecto». Two new previews show the sheets.

**P317 · D · S — Wrapped labels centre beside their icon · after P314**
- UX-2634 (S1) — at 2×, the form's «Añadir al / calendario» is centred, with its ✓ beside the text, not at the edge.
- UX-2635 (S1) — at 2× in Catalan, the task page's reminder chip centres its four lines, with the bell beside them.

## Skipped
None.

## Checks for your phone
This container has no Android SDK, emulator or phone. Do them on the TaskFlow_Review emulator first, then on a phone.
- **P314, free account with dictations left:** open «Escribir una tarea» from the shortcut and tap «Mañana» with no title. Go Home and tap the widget's mic. The listening sheet opens over the form, and Cancelar shows the form with «Mañana».
- **P314, free account at 0 dictations left:** do the same. A second form opens, saying no dictations are left, and Back shows the first form with «Mañana».
- **P314, Pro, only if online listening can be forced:**
  1. Tap the widget's mic and speak, then go Home.
  2. Tap «Escribir una tarea», then go Home again.
  3. Tap the mic again.
  One sheet shows: the paused one, with «Grabación conservada en este teléfono». Cancelar asks whether to keep or discard.
- **P314:** P313's checks (UX-2110, UX-2641, UX-2642) still hold.
- **P315, with the local API at migration 0026:** on «Tareas completadas», reopen a row that isn't the newest, open it, and tap «Completar».
  - Back on the list, the row sits where it was, and it's still there on the next visit.
  - After a sync, the server keeps the first completion's time.
- **P316, with TalkBack:** «¿Quién es responsable?» and «Novedades del proyecto» are each read as a heading.
- **P317, at Android's largest font in Catalan:** if «Afegeix al calendari» or the reminder chip wraps, the lines are centred and the icon sits beside them.

## For the main session
- No Android file changes in this run, so it needs no native build.
