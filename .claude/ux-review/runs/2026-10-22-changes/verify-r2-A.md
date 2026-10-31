## UX verify — 2026-10-22-changes, round 2, area A (P248) — 2026-10-22

**Verdict:** UX-2016 fixed. One polish-level side effect noted (R2A-1).

### UX-2016 · S2 · Reminder changed in «Más opciones» jumps out of view — **fixed**
- `App/lib/widgets/capture_review_editor.dart:66-69`: `_reminderOpen` is now `late final bool`, set once from the arriving task (plan, minutes or time). No `setState(() => _reminderOpen = true)` remains anywhere in the file (grep: only :66 and :537 read it).
- `:542-567` the shared `reminder()` builder keeps each `if (widget.enabled)` guard and its `_change(...)` call unchanged.
- `:725` the row above «Más opciones» only when `showReminder`; `:817` `if (!showReminder) reminder()` inside «Más opciones». On a plain draft the control can no longer move.
- Comment `:62-65` updated as the brief asked.
- `App/lib/widgets/capture_review_editor.dart` state is keyed by draft id at the call site (`App/lib/screens/voice_task_screen.dart:4376`), so a `final` flag can't leak between drafts.
- Tests (pass, per tester and round check): `App/test/reminder_plan_sheet_test.dart:1216-1240` (1× and 2×, 18:00 stays below `draft-options`, in viewport, `reminderTime == 1080`, no `draft-reminder` row), `:1242-1258` («Desactivado» stays below), `:1260-1284` (said «una hora antes» keeps its row above after a change), `:807` (UX-1805 plan→time→off keeps the row), and voice_command_cards_test.dart:1019 (plain dictation unchanged). Fixture `said()` (:759) is a plain draft on Fri 13 Nov with no reminder, matching the acceptance.
- Evidence: verified in code + widget tests. No preview shows this state (brief: none needed).

### Regressions
**R2A-1 · Severity 1 · A reminder set in «Más opciones» leaves no trace once it's closed**
- Where: `App/lib/widgets/capture_review_editor.dart:567-572` (`optionsSummary`) and the collapsed row `:843-846`.
- The moment: "I set it to 18:00 earlier… is it still on?" after closing «Más opciones», or on a collapsed multi-task card.
- What happens: HEAD's summary showed «Recordatorio: 1 hora antes» under «Más opciones» for a changed lead. P242 removed it because any change then moved the control above; with P248 the control now stays inside, so a reminder changed there is summarized nowhere once «Más opciones» closes, and the collapsed compact row shows the reminder line only when `showReminder`.
- Why: recognition over recall (Nielsen 1994); lens B/O. Low frequency, and the user saw the value while setting it — polish.
- Fix: in `optionsSummary`, add the reminder's short value only when `!showReminder && !task.isNote` and the task now carries a reminder (`reminderMinutes`, `reminderTime` or `reminderPlan` non-null — a plain draft has none, so it only appears after a change made there), using the existing `l.reminderValue(...)` words; no new copy. If the organizer prefers UX-1805's «nothing in the subtitle», close this as accepted.
- Evidence: verified in code; inferred UX.
