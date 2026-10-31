# UX plan — 2026-10-14-speed (capture speed, scoped run)

The capture-speed review found 15 things to fix, now six packages (P101–P106); three questions wait for you (UX-615 to UX-617), and nothing was skipped.
After the fixes, saving won't wait for the server, a landing won't re-date the next dictation, the mic will start before the housekeeping, and typed dates will understand «por la mañana» and «pasado mañana».

**How it runs:** this is a scoped run, so the packages go straight to the implementers, one at a time, in the order below. Numbering continues after the 2026-10-13-app run (P1–P100), so "P30" there and "P101" here can't be confused. Full briefs: `plan.json`.

## Before and after (the reviewer's estimates)
- Taps for one spoken task with a date: 3 → 3 (U4's target, unchanged).
- Avoidable waits on every capture: 2 → 0 (the save's server sync, UX-601; the per-open speech check and capture sweep, UX-603).
- Taps to change a day to Hoy, Mañana or Sin fecha: 3 → 2, plus the save.
- Undated tasks given the wrong day in a burst of three dictations: up to 2 → 0.
- Tap targets on a single spoken result: 8 → 7.
- Words in the used-up line (ES): 17 → 7.
- Capture strings that say "borrador", "esborrany" or "draft": 6 → 0, plus "Quitar de esta captura".

## Questions for you

### UX-615 — Should a result with nothing to ask save itself?
- With no open question, the result could save on its own, with Deshacer in the message: 2 taps (Añadir tarea, Listo) instead of 3, saving about 1–2 s per task.
- It changes the confirming tap that D3/U4 approved. The risk is a misheard date saved without a look; the safety net would be the landing, Deshacer and the date in the message.
- **Recommend:** not now. Keep the tap until the §7 test with your father, then decide (the reviewer's recommendation).

### UX-616 — Should the assistant's wait be cut on the server?
- On staging it took 1.3, 4.8, 4.8, 4.8 and once 20.5 s: now the longest single wait in capture. Only server work can cut it (a faster model, or understanding while the person is still speaking), so it's a cost decision.
- **Recommend:** measure first. P101 adds the phone's own share to Diagnóstico de captura, and its phone check splits phone, network and server. If the server is still most of the wait, try a faster model for task extraction on staging and compare cost and accuracy. Understanding while speaking is a much larger change.

### UX-617 — Should the app teach that one dictation can hold several tasks?
- One dictation gives three tasks in 3 taps; three dictations take 9. The first-run line (U12, P41 in the 2026-10-13-app run, not yet built) could say so, or people could find it themselves.
- **Recommend:** not in the first-run line yet. P41 keeps one task, as UX_REVIEW §5.6 has it, because a newcomer's first try should be one thing. §7 task 3 shows whether your father says two things in one go when asked; decide after that test.

## Packages, in run order

#### P101 · Saving and Listo never wait on the network or on diagnostics · A · M
- **UX-601** (S3) After "Añadir al calendario", the sheet waits for a full server sync, with Back blocked, although the task is already on the phone. It now reads the phone's tasks, closes and lands at once, and syncs behind; Deshacer does the same. No awaited diagnostics write remains between a tap and what it shows.
- **UX-610** (S2, phone check) Between Listo and the result, the diagnostics writes no longer hold the request. A new debug-only timing, "Last words after Done", measures the recognizer's finish. The 4 s wait for the last words stays until a phone measures it.

#### P102 · A landing shows the task without re-dating the next one; a batch shows every place · A · M · after P101
- **UX-602** (S3) Calendar passes a day to capture only when you picked it in the week strip or the month. After "médico el viernes" lands on Friday, "comprar pan" reads "Sin fecha" instead of Friday. D9 still applies to days you pick.
- **U5** (S2, reopened for one case) A save that mixes a dated task and an undated one lights both rows. When the tasks fall on more than one day, the message names the others: "2 tareas añadidas · también el sáb, 17 oct", or "· también en otros 2 días".

#### P103 · Capture opens ready: the microphone first, and typing without a spinner · A · L
- **UX-603** (S3) The speech check runs once per app session instead of on every open, and it's warmed when Añadir tarea first shows. The time-zone lookup and the sweep of old captures no longer hold the mic. On Android 13+, "Escuchando" shows as soon as the app's own microphone is keeping your words.
- **UX-611** (S2, phone check) A free account at 0 left opening "Escribir una tarea" gets the keyboard at once, without the unlabelled spinner. The cold-start waits are UX-424, which is P30 in the 2026-10-13-app run (see Notes).

#### P104 · Typed dates understand parts of the day and «pasado mañana» · A · M
- **UX-604** (S3) «mañana por la mañana» means tomorrow, and «por la mañana» on its own no longer means tomorrow. «pasado mañana», «demà passat» and "the day after tomorrow" mean two days from now. «a las 5 de la tarde» is 17:00 with no question. A part of the day with no hour stays in the title. This is the everyday path for free accounts after their 10 dictations, and for «Guardar tal cual».

#### P105 · The result card: notes only when there are some, a title that looks editable, one-tap day fixes · A · M
- **UX-606** (S2) The empty Notas field goes; "Añadir notas" is the first row of Más opciones and opens the field with the keyboard.
- **UX-607** (S2) The title and notes fields get an underline, so it's clear that a misheard word can be fixed by tapping.
- **UX-608** (S2) On the result, Hoy, Mañana and Sin fecha apply and close at once, keeping the time, as they already do when moving a task.
- **UX-613** (S1) An opened batch card no longer shows its title twice.

#### P106 · Leaving a result asks first; fewer words at 0 left; no «borrador» · A · M
- **UX-605** (S2) Cancelar, Back and the dimmed area on a result ask «¿Quieres conservarlo para más tarde?» with Descartar / Conservar, the same question as while listening and typing. "Podrás terminarlo más tarde." goes.
- **UX-609** (S2) At 0 left, the line above typing becomes «Sin dictados gratis hasta el {date}.», with Ver Pro kept.
- **UX-612** (S2) "Borrador", "esborrany" and "draft" leave the capture copy: «Quitada», «Han vuelto aquí, sin guardar.», «Tareas · 3 sin añadir», «Quitar», and so on.
- **UX-614** (S1) With no Pro and no free dictation left, "Volver a decirlo" no longer shows on a result; it used to open typing.

## Skipped
None.

## Notes
- **Run P30 next.** UX-611's other causes are UX-424, planned as P30 in the 2026-10-13-app run and not yet run: start-up waits for the reminder setup, and session restore waits for every reminder to be reconciled before Calendar shows. The widget's and shortcuts' cold path needs both P30 and P103.
- **Catalan to check.** P102's «també el {date}» and «també en {count} dies més» are the organizer's wording; the reviewer asked for a Catalan check. A Catalan speaker should read them after "2 tasques afegides".
- **The organizer's additions,** so the reviewer can check them:
  - P103 warms the speech check once when Añadir tarea first shows, so the first capture of a session doesn't wait for it.
  - P104 also reads «passat demà» and «a las 5:30 de la tarde» (today 05:30, silently).
  - P105's one-tap day chips also apply to the result's deadline row, so the result behaves one way.
  - P106 removes the unused `captureReviewRetainedHelp`, which still said «borradores».
  - P102 says «también en otros {n} días»; the report had «también otros {n} días».
- **A verified behaviour changes on purpose.** P106 makes Cancelar on a result ask, which reverses UX-457's "closes with no dialog" (b3). It follows U2's approved rule, "Cancel asks: keep or discard". P102 narrows the day Calendar passes for D9 (UX-112) to a day you picked.
- **Still out of reach for a batch.** A dictation across several days still can't show every task at once. P102 lights the no-date row and names the other days in the message instead of adding a "Ver" link, because the message's one button is Deshacer.
- **Dates.** The report's examples ("vie, 17 oct", "sáb, 18 oct") match 2025's calendar. The checks use 2026's: Friday is 16 Oct and Saturday 17 Oct.
- **Not in this run:** U11's names (P43: "Sin fecha", "Sin guardar"; an undated save still says «bandeja de entrada» and «Bandeja · N»), U12's first-run line (P41), and the two tabs (U13).

## Round 2 (b1)

Round 1 fixed 15 of 16 findings in code. Round 2 fixes the two regressions it caused (P107, P108). UX-609 is now a question for you, about Catalan only; nothing is escalated.

### Question for you

#### UX-609 — Catalan line at 0 free dictations: accept 3 lines, or shorten it?
- **What round 1 did (P106):** the line above typing is now 7 words. Spanish «Sin dictados gratis hasta el {date}.» and English "No free dictations until {date}." take 2 lines at 2× text on a 320 dp phone. Catalan «Fins al dia 1 de nov. no tens dictats gratuïts.» takes 3. In all three languages the typing field stays above the keyboard, which was the point of the check.
- **The options (from the reviewer):** (a) accept 3 lines in Catalan only; (b) a shorter Catalan line without "gratuïts", such as «Més dictats el dia {date}.», which needs a native read; (c) keep the wording and check only that the field stays visible.
- **Recommendation:** (a) with (c): keep the Catalan wording and allow 3 lines in Catalan. Spanish, your father's language, fits in 2. If you agree, ux-tester changes the Catalan check to "at most 3 lines, and the field above a 300 dp keyboard". Until you answer, that Catalan test is the only failing test in the suite.

### Packages, in run order

#### P107 · A time with no date word that has already passed goes on the next day · A · S
- **UX-618** (S2, regression R1A-1 from P104) At 10:00, «Llamar a Juan a las 9 de la mañana» was saved today at 09:00, already past and with no reminder. Now any time said with no date word that has already passed goes on the next day: Thursday 09:00. «a las 5 de la tarde» at 10:00 stays today at 17:00. A date word («hoy») or a day you picked still wins.

#### P108 · One line, not two, between the notes and Más opciones · A · S
- **UX-619** (S1, regression R1A-2 from P105) The line above Más opciones shows only when the notes field is hidden, because the field's own underline already separates them.

### Skipped
None.

### Notes
- **P107 is the organizer's wider reading** of the reviewer's fix: the reviewer asked for it at least where a part of the day settled the time, and ideally for every no-date time; P107 does the latter, because «a las 17» at 18:00 had the same problem. A past «esta noche a las 9» also moves to tomorrow, which is better than a silent past save.

## Round 3 (b1)

Round 2 fixed both of its findings (UX-618, UX-619) in code. Round 3 fixes the one small regression P108 caused (P109). Nothing is escalated. UX-609 is still your question about Catalan; its Catalan test still fails, and rounds 2 and 3 don't touch that sheet.

### Question for you (unchanged)

#### UX-609: the Catalan line at 0 free dictations. Accept 3 lines, or shorten it?
- Same question and recommendation as in Round 2: keep «Fins al dia {date} no tens dictats gratuïts.» and allow 3 lines in Catalan only. Spanish and English fit in 2. In all three languages the typing field stays above the keyboard.

### Packages, in run order

#### P109 · The line above Más opciones returns when other rows sit below the notes · A · S
- **UX-620** (S1, regression R2A-1 from P108) P108 removed the line above Más opciones whenever notes showed. Now it's removed only when the notes field sits directly above Más opciones. With a deadline, the priority chip, a checklist or an open question in between, the line comes back, so the deadline row and Más opciones no longer read as one list. P108 tried to show the line only when notes were hidden; that missed rows drawn between the two.

### Skipped
None.

### Notes
- P109 checks for open questions (unanswered, result not confirmed) rather than reusing `showPlanning`. `showPlanning` also counts answered questions, so reusing it would bring back the double line in a rare state.
- Out of lane, internal only: since P107, the `localDrafts` doc comment ("A time alone goes on [defaultDay], or on [reference]'s day") is out of date. No user sees it, so no package is planned. It can be fixed whenever that file is next touched.
