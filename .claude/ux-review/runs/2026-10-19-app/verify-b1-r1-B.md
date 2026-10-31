## UX verify — run 2026-10-19-app, round 1, area B (P169) — 2026-10-20

Renders read (all newer than calendar_screen.dart 04:53, app_es.arb 05:02, app_components.dart 05:29): calendar/agenda.added.es.light.1x, .1x-393, .2x, .ca.light.2x; calendar/agenda.empty-day.es.light.2x; commands/applied.change-applied.es.light.2x; commands/applied.mixed-applied.es.light.1x. Evidence level: widget test and preview renders, no device.

### UX-1309 · partly
- (a) done: every landing waits for the save message and clears its measured height + 8, 88 only as fallback (`calendar_screen.dart:184-195`, `_messageClearance` :349-368).
- (b) done as written: block first..last lit row when `lastEnd <= top`, else the first (:229-235). (c) done: `_watchLit` (:285-323) fades only rows seen whole above the message; a row out of view stays lit; `_scrolled` (:274-282) re-checks after a scroll.
- Renders: 2x added — «Comprar pan y leche» and «Sin hora» above the message; change-applied 2x — «10:00 · Pasos» and the notes line above «Movida al mar, 27 de oct»; mixed-applied 1x — lit row bottom well above the message top. All pass.
- Acceptance 1 fails (tester and render `agenda.added.es.light.1x.png`; also 1x-393): the new «Recoger a los niños del colegio» 17:00 is lit but below the fold, with «Llamar al médico…», «Comer con Ana» and the fixture's own «Recoger» between. Even with the first lit row pinned to the viewport top the block is 82 dp (360) / 6 dp (393) too tall, so no reveal can satisfy (b) and this check together. The code follows the brief; the check assumed a fixture that fits.
- What the newcomer sees: «3 tareas añadidas · también el vie, 23 de oct», one lit row, and nothing telling them a second one sits further down today. That is the original symptom for days where new tasks are far apart. Organizer's call: drop the duplicate «Recoger» from the preview so the fit case renders (the 2x render already shows the no-fit case), and either accept rule (b) as the end state or open a follow-up for a below-the-fold cue (note: the landing copy is "don't touch" in this package).

### UX-1405 · fixed
- `_leftAt ??= _now()` on any non-resumed state; on resume `_comeBack` (:388-399) selects today and clears `_picked` after ≥30 min or on a new day; shorter returns keep the day. Both read `calendarClockProvider`. Tester: 31 min → «Agenda de hoy»; 5 min → Friday kept; picked day still reaches the next capture; after midnight → today.
- An open capture or form keeps its day: `TaskActions` passes the day by value at open (`task_actions.dart:72-97`), so a call during a capture doesn't change where an undated dictation goes (D9).
- Device-only: a real overnight return on a phone.

### UX-1404 · fixed
- Header subtitle only when the day has rows (`calendar_screen.dart:806-816`); after the first run the empty state is one line, no title, no tile (:837-857): `calendarEmpty`, or `noScheduledTasks` with phone calendars on. `EmptyState.title` now optional (`app_components.dart:127-154`).
- Copy: EN “No tasks for this day.” / ES «No hay tareas para este día.» / CA «No hi ha tasques per a aquest dia.»; `breathingRoom` removed from all three; no value contains «tareas de TaskFlow programadas». `rememberPrompt` still used by the first-run state.
- Render `agenda.empty-day.es.light.2x.png`: «Agenda de hoy», then only «Nada previsto para este día.», above «Añadir tarea». First-run tests pass.

### Regressions
**R1B-1 · Severity 2 · Return to today keeps the old scroll position**
- Where: `calendar_screen.dart:388-399` (`_comeBack`), Calendar on resume after ≥30 min or a new day.
- The moment: after a landing scrolled Friday down (at 2x the reveal hides the week strip and half of the header, as in `agenda.added.es.light.2x.png`), the person comes back an hour later: today's rows show, but the week strip and «Agenda de hoy» are above the fold. "Is this still Friday?"
- What happens: `_comeBack` changes the day but never touches `_scroll`; the offset from the landing's reveal stays (clamped to today's extent). The tests check `find.text(todayAgenda)`, which finds a built-but-offscreen header too.
- Why it fails: visibility of system status (Nielsen 1994); the day switch is a change outside where the person looks (Rensink et al. 1997).
- Fix: when `_comeBack` moves to today, jump the list to the top (`_scroll.jumpTo(minScrollExtent)` once it has clients), so the week strip and «Agenda de hoy» show. No copy.
- Verify: widget test at 2x on 360x800 — land on Friday with enough rows to scroll, away 31 min, resume: the «Agenda de hoy» header's rect is inside the viewport.
- Evidence: inferred from code.

No other regression found in the changed parts of calendar_screen.dart, app_components.dart (EmptyState, MessageBanner) or the three catalogs for the Calendar flows.
