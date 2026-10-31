# UX plan — 2026-10-15-changes (the first-run line names two tasks; scoped run)

Review B found three things to fix in Calendar's first-run line. They make one package, P119. Nothing waits for you, and nothing was skipped.
After P119, the example's two tasks land on the same day, tomorrow, so after saving both are on screen whatever the day of the week. If the assistant is slow or fails, saving the words as written keeps the date. And at the largest text the whole line shows above Añadir tarea.

**How it runs:** this is a scoped run, so P119 goes straight to an implementer. Package numbers continue after P118 (2026-10-13-app, b10). The full brief is in `plan.json`.

## Before and after (the reviewer's estimates)
- Days of the week on which both saved tasks are on screen: 1 of 7 → 7 of 7.
- What Guardar tal cual makes of the example:
  - before: one task with no date, titled with the whole 12-word sentence;
  - after: one task, «Llamar al dentista y comprar pan», dated tomorrow.
- Words to remember while speaking, in Spanish: 12 → 7.
- Lines at 2× on a 320 dp phone (ES / EN / CA): 5/5/6 → 4/4/5.
- How much of the line shows without scrolling at Android 14's largest font, on a 360×780 phone (ES / EN / CA): none of it → 3 of 3 lines, 3 of 3, and 3 of 4.
- The typed example: asks 10:00 or 22:00 → no question.
- Unchanged: 3 taps add the example's two tasks, and a new account's Calendar has 16 tap targets.

## Questions for you
None hold this run back.

The reviewer asked one conditional question. If you chose «Llamar al dentista el viernes a las 10 y comprar pan mañana» word for word, changing it is your call. Here is why it's planned as a fix:
- **What you decided** on 2026-10-15 was the result: one task for each thing said, and a first-run line that shows it.
- **The words** were written by the main session in 83b4b10.
- **What P119 keeps:** your decision. The spoken example still names two tasks, and the typed one stays one task. Only the words change.

If you did pick those words yourself, tell the main session and it will put them back. On six days of the week only one of the two tasks would then show after saving. At the largest text, the line would again end up under the button: the reviewer modelled it about 8 dp short in Spanish and English at 2×.

## Packages, in run order

#### P119 · The first-run line: both tasks on one day, no hour question, seen above the button · B · M
- **UX-701** (S3) The spoken example becomes «Mañana, llamar al dentista y comprar pan» (EN “Tomorrow, call the dentist and buy bread.”, CA «Demà, trucar al dentista i comprar pa»). It still names two tasks. Both now land on tomorrow and both light up, on any day. If the assistant is slow or fails, Guardar tal cual saves one task dated tomorrow, not one with no date.
- **UX-702** (S2) In a new account's first-run state only, the green icon tile and the «Un momento de calma.» line go. At the largest text, the whole instruction then sits above Añadir tarea without scrolling. No copy changes.
- **UX-703** (S1) The typed example becomes «Mañana, llamar al dentista» (EN “Tomorrow, call the dentist.”, CA «Demà, trucar al dentista»). It's still one task, as decided, and it no longer asks 10:00 or 22:00.

## Skipped
None.

## Notes
- **Checks no agent can do:**
  - **With the real model,** as in 140f5cc, when the free quota allows: each language's new example should come back as two tasks dated tomorrow. Nothing has checked the model on this sentence yet.
  - **On a phone:** UX-617's check, which can now pass on any day, not only Thursdays; and UX-702's check at the largest font.
- **DECISIONS.md still quotes the old example** (2026-10-15, "This answers UX-617"). Agents don't edit that file, so the main session may want to update the quote after P119.
- **The organizer's readings,** for the reviewer to check:
  - In the first-run state, P119 hides the line under «Agenda de hoy» whichever text it holds. So «No hay tareas de TaskFlow programadas», shown when phone calendars are on, goes too. The instruction below already says what to do.
  - The line also stays hidden while a brand-new account's first screen is loading, so it doesn't appear and then vanish.
  - The ARB descriptions of both examples now state the rule: one day, one date word, no bare hour. That way the next edit keeps it.
- **Seen outside area B, not planned.**
  - **What the reviewer noted:** any dictation that names two days and is saved with Guardar tal cual becomes one task with no date, titled with everything said (`quick_schedule_parser.dart:107`).
  - **Why it matters to you:** your own three-task example would end that way whenever the assistant fails, as most free calls did on 2026-10-15. The reviewer didn't report it as a finding, so nothing is planned for it here.
  - **Two ways forward:**
    - the paid fallback (UX-616, already marked urgent in DECISIONS.md) would make those failures rare;
    - an area-A review (`/ux capture sheet`) would look at what the slow and failed states offer when a dictation holds several tasks.
- **Ledger.** UX-617's phone step in ISSUES.md now says "after P119, on any day". U5, U7, U10 and U12 carry review B's status. Regenerate PHONE_CHECKS.md after this run (`python -I -X utf8 .claude/ux-review/phone_checks.py`).
