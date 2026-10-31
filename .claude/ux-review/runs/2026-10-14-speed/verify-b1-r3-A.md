## UX verify — 2026-10-14-speed, round 3, area A — 2026-10-14

Scope: P109 (UX-620). File: App/lib/widgets/capture_review_editor.dart (git diff HEAD, the round-3 block).

### UX-620 · fixed
- Code: `capture_review_editor.dart:593` reads `if (!notesLast) const Divider(height: 1),`, with the requested comment at :591-592.
- `notesLast = showNotes && !belowNotes` (:439). `belowNotes` (:426-438) matches each row the build draws between the notes and Más opciones (:538-590):
  - `...repair` (:539) via `repair.isNotEmpty`;
  - `showAssignment` (:540);
  - deadline row, deadline `_fromWords` (only drawn when a deadline exists), deadline/duration questions and the duration text (:541-557), all gated by `!task.isNote`, as in the build;
  - ChecklistEditor (:558), priority/repeat Wrap (:566), recurrence and details questions (:589-590).
- Open questions use `_openQuestions` (:139-148), the same filter `_questions` uses (:151); `_questions` draws one box per open question, so "open" always means "something drawn". Resolved deadline/duration questions don't count, so the double line can't return there (the reason not to use `showPlanning`).
- `_questions` behaviour is unchanged: the filter body was moved verbatim.
- Tests (ux-tester, pass): the two UX-620 tests at App/test/review_tasks_test.dart:1783-1865 (deadline row: exactly one Divider, its bottom within 0.5 dp of the Más opciones row; priority chip: one Divider directly above the row and none across the notes) plus the two UX-619 tests (:1722, :1753).
- Renders (17:22, newer than the 17:11 code): review-direct-light.png shows only the notes underline between the notes and Más opciones, as in round 2. review-direct-no-notes-dark.png shows one line above Más opciones, as in round 2.

### Regressions
None found. Checked:
- a note (`isNote`) with notes only → no Divider, as in round 2;
- no notes field → Divider always drawn (`notesLast` is false);
- a confirmed draft with stale questions → `_openQuestions` is empty, and nothing is drawn, so this matches;
- the "Añadir notas" row inside Más opciones (`if (!showNotes)`, :609) and the underline styles weren't touched;
- no copy or ARB changes.

No new state is left without a separator, and no double line appears.
