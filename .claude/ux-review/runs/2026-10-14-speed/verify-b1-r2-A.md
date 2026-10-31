## UX verify — 2026-10-14-speed, round 2, area A (P107, P108) — 2026-10-14
**Verdict:** Both fixed. One polish regression (R2A-1) in a state the brief didn't cover.
**Evidence used:** `git diff HEAD` of the two files, code reading, ux-tester's unit and widget tests (as reported), renders `App/build/review-direct-light.png` and `review-direct-no-notes-dark.png` (17:07, newer than the code at 16:55 / 16:59).

### UX-618 · fixed
- `App/lib/services/quick_schedule_parser.dart:218-227`: after both time branches, `if (hasTime && match == null && day == null && date.isBefore(<reference to the minute>))` moves the date to `DateTime(y, m, d + 1, hour, minute)`. Covers H:MM, a.m./p.m., 24-hour bare hours and part-of-day settled hours; same minute stays today (`isBefore` is strict).
- Date words win (`match != null` skips it); a picked day wins (`day != null`); the ambiguous path never sets `hasTime`, so 'a las 10' keeps today and its question. Deadlines need a date word (`deadlineMarker` is null when `match` is null), so they are untouched.
- Doc comment on `parse` updated (:90-93). Only caller is `local_capture.dart:97`, which passes `day` only from `_laterDay` (a later day the person picked), so the rule reaches both 'Guardar tal cual' and typed free-tier captures.
- Tester: 7 unit cases + the Spanish widget test with the clock fixed at Wed 10:00 → saved Thu 15 Oct 09:00, 'Llamar a Juan'. The review card shows the shifted day (`Mañana`), so the interpretation stays visible.
- Out of lane: the `localDrafts` doc comment ('A time alone goes on [defaultDay], or on [reference]'s day') is now stale; internal only, not user-facing.

### UX-619 · fixed
- `App/lib/widgets/capture_review_editor.dart:573-574`: `if (!showNotes) const Divider(height: 1),`.
- Render review-direct-light.png: the notes underline (y≈1179) is the only line above 'Más opciones'. review-direct-no-notes-dark.png: one divider (y≈1195) above 'Más opciones', as before.

### Regressions
**R2A-1 · Severity 1 · Más opciones loses its separator below other rows**
- Where: `App/lib/widgets/capture_review_editor.dart:520-574`, review card, notes shown **and** something drawn between notes and Más opciones: `repair`, the assignment line, the deadline `_row` (flag icon + chevron), duration text, `ChecklistEditor`, the priority/repeat chips, or a recurrence/details question.
- What happens: the condition only asks whether notes show, not whether the notes field is the last thing above the row. In those states nothing separates, e.g., the deadline `_row` (icon + text + chevron, a ListTile) from the Más opciones ListTile (icon + text + chevron); they read as two fields of the same list, and the card loses the line that said "the rest is optional" (Gestalt common region / proximity).
- Fix: draw the Divider unless the notes field is directly above it, e.g. compute `final notesLast = showNotes && repair.isEmpty && !showAssignment && task.deadline == null && task.durationMinutes == null && task.checklist.isEmpty && task.priority <= 1 && !task.isRecurring && <no deadline/duration/recurrence/details questions>` and use `if (!notesLast) const Divider(height: 1)`. No copy change.
- Verify: widget test, Spanish 360×740, a result with notes and a deadline → exactly one Divider directly above `draft-options-<id>`; the two UX-619 tests still pass.
- Evidence: verified in code; no preview covers this state.
