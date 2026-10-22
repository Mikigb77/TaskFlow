## Verify — run 2026-10-22-changes, round 1, area A (P242) — 2026-10-22

Evidence: code (`git diff HEAD`), the P242 tests named by the tester, and current renders
(`App/build/ux/reminders/capture-card.*`, 14:50; no app file is newer). Widget-test level, no device.

### Results

- **UX-1805 · fixed.** `capture_review_editor.dart:65-68` `_reminderOpen` (plan, minutes incl. -1, or time);
  `:536-569` one `reminder()` builder; `:727-728` the row keyed `draft-reminder-<id>` above «Más opciones»;
  `:819` `if (!showReminder) reminder()` so never twice; reminder removed from `optionsSummary` (`:570-574`);
  `belowNotes` counts `showReminder` (`:596`). Bespoke row and `editTaskReminder` removed. Render
  `capture-card.plan.es.light.1x`: «Recordatorio» / plan line under the date, «Más opciones» with no subtitle.
  `capture/result.one-task` still 7 targets in AUDIT. 2× es/ca: row scrolls into view, AUDIT shows no clipping.
- **UX-1802 · fixed.** The card's row is the ReminderControl, whose `_cannotFire(planned:)` shows
  «Activar recordatorios» under the kept plan line (`reminder_control.dart:717-722`); `turnOnReminders` saves
  `asked: true` (`:213-222`). Render `capture-card.plan-reminders-off.es.light.2x` shows exactly that.
- **UX-1809 · fixed.** `_reminderLine()` (`capture_review_editor.dart:404-437`) built like the small date line
  (18 dp primary bell, bodyMedium, chevron, Semantics button with its text); shown in collapsed rows only when
  `showReminder` and a date or active plan (`:845-848`). Shared helper `reminderLine()` (`reminder_control.dart:449-536`)
  now drives both ReminderChip and the line. Render `capture-card.several-plan.es.light.1x`: only row 2 shows
  «Recordatorios: cada semana · próximo: jue 29, 09:00»; TalkBack reads it as a button (AUDIT #9).
- **UX-1811 · fixed.** `CaptureStore.withoutStalePlan` (`capture_store.dart:196-200`) applied after
  `normalizeResponsibility` (`:230-235`), and the same task stored in the draft (`:245`). On the card, «Sin fecha»
  makes ReminderControl's `dated` false → «Añade una fecha para usar un recordatorio», no tap (`reminder_control.dart:688-689`).

### Regressions

**R1A-1 · Severity 2 · A reminder set in «Más opciones» jumps out of view**
- Where: `App/lib/widgets/capture_review_editor.dart:546-567` (the three `setState(() => _reminderOpen = true)`), with `:819`.
- The moment: "I set the reminder to 18:00… where did it go? Did it take?"
- What happens: on a plain draft the ReminderControl sits inside «Más opciones», below notes, person, priority,
  repeat and planning. Any change made there sets `_reminderOpen`, so on rebuild the control is removed from
  «Más opciones» and re-inserted above its header (after the date, before steps and chips). The spot the user was
  looking at now holds the steps editor; at 2× the moved row is several screens up and off screen. Not covered by
  the P242 tests (the plain-draft test only opens «Más opciones»).
- Why it fails: change blindness (Rensink, O'Regan & Clark 1997); Nielsen's visibility of system status — lens B/O.
- Fix: subtract the three `setState(() => _reminderOpen = true)` calls. The row above only shows when
  `_reminderOpen` is already true and it never resets, so they matter only for the control in «Más opciones»,
  where they cause the jump. A reminder changed in «Más opciones» stays there.
- Verify: widget test — plain draft, open «Más opciones», tap «Recordatorio» → «Elegir hora del aviso» → 18:00:
  the ReminderControl is still below `draft-options-<id>` and visible, reading «18:00».
- Evidence: verified in code; no render of this state.

### Notes (not regressions)
- A collapsed row with reminders off reads «Sin recordatorio · Activar» (the chip's reading, as the brief asked),
  while the opened card keeps the plan's line with «Activar recordatorios». Per brief; same as the task page chip.
