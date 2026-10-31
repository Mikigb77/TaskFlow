## UX verify — run 2026-10-21-changes, round 3, area A (P230) — 2026-10-21
**Verdict:** Ship. UX-1719 is fixed in code, with a test that pins the failing state; UX-1717 and UX-1718 are untouched and still fixed. No regressions.
**Evidence level:** code, plus the tester's renders from 2026-10-22 00:56 (newer than `voice_task_screen.dart`, 00:33). No preview covers the answered state, so UX-1719 rests on code and its widget test. I didn't run Flutter; the tester reported no results.

### Results
**UX-1719 · fixed**
- `App/lib/screens/voice_task_screen.dart:2754-2756`: `_reveal` now calls `Scrollable.ensureVisible(open.heading ? card : (_questionIn(card) ?? card), alignment: open.heading ? 0 : 1, …)`. A deletion set (`heading: view.bulk != null`, `:2696`) is revealed by its card, so the heading «Eliminar N tareas» and its ✕ come to the top even though the answered QuestionBox stays under the heading. The duration, the curve and `Duration.zero` under reduced motion are unchanged (`:2757-2758`). The doc comment (`:2743-2747`) says so.
- Everything with `heading: false` behaves as before: open questions and blocking cards still go to `alignment: 1`, and so does a one-task deletion.
- `_revealAfter` (`:2764`) still runs only when `_openCount` drops. Answering the chip clears `view.blocking`, so the reveal fires exactly in this case.
- Test: `App/test/bulk_voice_commands_test.dart:4064-4107`. Spanish, 2×, 360 × 800, five completed Matemáticas tasks plus one in Matemáticas II. It asserts the card is taller than the view (`:4080`) and the QuestionBox sits below the heading (`:4083-4093`), then checks the heading and the ✕ (tooltip «No eliminar ninguna») are inside the view. Without the fix, the QuestionBox would sit at the top and the heading above it, so the test fails. The before-answer test (`:4033-4062`) checks that «¿Qué proyecto?», both chips and the disabled button are in view.
- Device check still open (main session): largest font, «Borra todas las completadas de mates», tap «Matemáticas».

**UX-1718 · fixed (re-checked)**
- `_firstOpen` (`:2679-2700`) is unchanged: same pick order, and `heading` is true only for an actionable deletion set.
- Renders: `cards.bulk-delete-mixed.es.light.2x` opens at «Eliminar 3 tareas» with its ✕ at the top and «Añadir y eliminar» below. `cards.bulk-delete.es.light.2x` matches. Both are the same as in round 2.
- `cards.bulk-ambiguous-project` (es 1× and 2×): «Tareas de «mates»», «¿Qué proyecto?», two chips and the disabled «Revisa los datos de arriba». Unchanged.

**UX-1717 · fixed (re-checked)**
- The ✕ count `view.bulk?.count ?? (command.bulk ? 2 : 1)` (`:4080`) is untouched.
- The diff's only change to `ensureVisible`'s target is the one line above, and `_announce` (`:2815-2816`) is unchanged.

### Regressions
None. I walked these flows:
- **A set answered at 1×:** a short card goes to the top; the scroll is clamped at its end, so nothing jumps.
- **A new task plus an answered set:** the task scrolls up above the set. This is the layout P229 settled for the mixed set.
- **A set still asking when the sheet opens:** `heading: false`, so the question box is revealed as before.
- **Move and complete sets:** they still aren't revealed.
- **TalkBack announcement:** unchanged.

The chip just tapped moves down by the scroll distance but stays in view under the heading, which is expected.
