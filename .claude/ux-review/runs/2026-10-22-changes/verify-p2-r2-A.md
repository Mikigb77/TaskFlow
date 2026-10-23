# Verify — run 2026-10-22-changes, plan 2, round 2, area A — 2026-10-23

Scope: P258 (UX-2023). File changed: `App/lib/widgets/capture_review_editor.dart`.

## UX-2023 — fixed

- Opened card: the order is now `_dateLine(main: true)` → `_fromWords()` (only when there's a due date) → `_questions('schedule')` → `if (needsDay) _needsDayLine()` (`App/lib/widgets/capture_review_editor.dart:724-729`). The comment at :722-723 now says the date's open question sits right under it and the needs-day line comes after both.
- Collapsed row: `_dateLine(main: false)` → the existing comment → `_questions('schedule')` → `if (needsDay) _needsDayLine()` → the `_reminderLine()` condition, unchanged (:900-908).
- `_fromWords()` needs `task.dueDate != null` and `needsDay` needs `task.dueDate == null`, so the two never show together. With no open `schedule` question, `_questions('schedule')` is an empty Column, so the line still sits directly under the date line, as P254 had it.
- `_needsDayLine()`, the `needsDay` rule, `showReminder`, `reminderInOptions` and `_questions()` are untouched. No ARB changes.
- Tests: the `P258 · UX-2023` group (`App/test/reminder_plan_sheet_test.dart:5951`) covers every acceptance check: the opened card, a collapsed second row, the resolved case, no open question on the opened card and on a collapsed row, and 2× es and ca at 360×800. All pass. `P254 · D3` passes unchanged.
- Renders: `reminders/capture-card.needs-day.{es.light.1x, es.light.2x, ca.light.2x}` (2026-10-23 09:54) are newer than the code (01:06). I read the es 1× and ca 2× renders. «Sin fecha» / «Sense data», with «Para recordártelo, ponle un día.» / «Per recordar-t’ho, posa-li un dia.» under it, is unchanged; nothing is clipped. AUDIT matches the previous round: the 0 dp gaps between the title, the date and the needs-day line are the existing stacked-ListTile pattern, each row 56 dp tall, and not caused by this change.
- Evidence: verified in code, the widget tests and current renders (no preview shows the open-question state; the widget test proves its order and 2× fit).

## Regressions

None. The change only reorders two children in two places. No other field's questions, the reminder line or the assignment rows moved.

## Notes for the main session

None. No contract change.
