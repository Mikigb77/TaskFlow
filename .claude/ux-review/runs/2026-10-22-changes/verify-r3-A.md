## UX verify — round 3, area A (P250) — 2026-10-22

**Verdict:** UX-2018 fixed. No regressions.

### UX-2018 · S1 · A reminder changed in «Más opciones» leaves no trace once it's closed: **fixed**
- `App/lib/widgets/capture_review_editor.dart:538-546`: new `reminderInOptions` = `!showReminder && !task.isNote && (plan || minutes || time set) && (reminderDate != null || ReminderPlans.active(task) != null)`, as briefed. `showReminder`, `_reminderOpen` (:66-69) and the `reminder()` builder (:547-576) are untouched by this round.
- `:779-790` «Más opciones»' subtitle: when the flag is set, a `Consumer` builds `[...optionsSummary, reminderLine(context, ref, task).text].join(' · ')`, so the reminder comes last, after priority and repeat. Otherwise the subtitle is the old one, or null. No ARB change: the words come from `reminderLine` (`App/lib/widgets/reminder_control.dart:449-540`, which uses `reminderValue`, `off`, the plan line and the blocked or passed lines).
- `:857-866` collapsed row: `_reminderLine()` shows when `(showReminder && (reminderDate || active plan)) || reminderInOptions`. A collapsed row has no «Más opciones», so nothing shows twice.
- Acceptance tests in `App/test/reminder_plan_sheet_test.dart:1286-1530` cover every check:
  - 18:00 → «Recordatorio: 18:00», and the control is still below «Más opciones» (:1325);
  - «Desactivado» (:1345);
  - priority, then the reminder (:1363);
  - a said «una hora antes» row, and a said plan row, add nothing to the subtitle (:1380, :1406);
  - two-task and three-task collapsed rows: only the changed row shows a line (:1421, :1463);
  - 2× on 360×800: the subtitle is whole and in view (:1503).

  Testers reported no failures.
- Renders from 15:35 postdate the code change at 15:31. `capture/result.one-task.es.light.1x.png` still shows «Más opciones» with no subtitle and no reminder row, and `reminders/capture-card.several-plan.es.light.1x.png` is unchanged: only the said-plan row has a bell line. The INDEX descriptions are still true.
- Evidence: verified in code, the widget tests listed above, and current renders of the unchanged states. No preview shows the changed-inside state, and the brief says none is needed.

### Regressions
None.

Note, not counted. On a phone where reminders can't ring, a reminder changed inside «Más opciones» makes the subtitle read the line's own words, «Sin recordatorio · Activar». Tapping the subtitle opens «Más opciones», where the control has its own way to turn reminders on, so it isn't a dead end. The brief chose this on purpose: "it also says why it won't ring here, as the line does".
