## UX verify — 2026-10-28-app, b1 round 2, area A (P297, P298) — 2026-11-01

**Verdict:** All four findings are fixed. No regressions in the changed files or the flows they touch.
**Evidence level:** code (`git diff HEAD`), the renders the tester made at 2026-11-01 03:37 (newer than the code), AUDIT.md, and the tester's passing widget tests. No device.

### Findings

**UX-2203 · fixed**
- Save path: `App/lib/screens/voice_task_screen.dart:3370-3387` (`first`): this applies when there are several tasks, all dated and on two or more days, `allOn` is null and `remaining == 0`. `added` then names `days.first` (the day Calendar lands on, `:3438-3440`) with its own count: `captureTasksAddedOn(n, …)`, or `taskAddedOn` / `taskAddedDue` when one task. `otherDays = days.skip(1)` (`:3411`) never repeats it. A mix with an undated task, or a save with tasks kept for review, keeps `captureTasksAdded` as before.
- Command path: `:3937-3963` (`addedDays`, `allOn`, `firstAdded`, `firstTasks`). `firstAdded` is added to `named` (`:3968`), so «· también el …» leaves it out. The new-tasks part is at `:3976-3984`.
- Render `calendar/agenda.added.es.light.1x` (360×800): «2 tareas añadidas al dom, 1 de nov · también el vie, 6 de nov» with Deshacer, and both lit rows («Comprar pan y leche», «Recoger a los niños del colegio») above the message. The heading has scrolled away; the organizer's round-2 decision allows that. `agenda.added.ca.light.2x`: «2 tasques afegides al dg., 1 de nov. · també el dv., 6 de nov.» is whole, on three lines, with no ellipsis.
- Tests: the P297 group in `capture_landing_test.dart:1942` and in `voice_command_cards_test.dart:7615`; P274's 393×852 case is unchanged. All pass, per the tester.

**UX-2619 · fixed**
- `voice_task_screen.dart:4148-4188`: in the `takesBackOnly` branch, when the undo is whole, `narrowAfterUndo` runs first. Then `calendarFocusProvider` is set from what came back, with each task's day from `landing()` and `onToday()`, earliest first:
  - deleted tasks: their own day;
  - changed tasks: the day in `before`;
  - completed tasks: their `days`.

  It uses those tasks' ids and keeps `page` and `showCalendar` from `origin`; `undated` is set only when a task has no day. When the undo is not whole, `undoError` shows and nothing moves.
- Renders: `commands/applied.delete-applied.es.light.1x` shows today with «Eliminada: Ir a la peluquería» and Deshacer. After Deshacer, `applied.delete-undone.es.light.1x` shows Calendar on «miércoles, 4 de noviembre», with «Ir a la peluquería» lit, «Hoy» offered in the header, and no sheet. The two renders now differ visibly, and the user sees where the task came back.
- Tests: the P297 group in `voice_command_cards_test.dart`, for a deletion on another day, a change, and a deletion on the same day; the UX-2202 checks in `bulk_voice_commands_test.dart` still pass. All pass, per the tester.

**UX-2618 · fixed**
- `App/lib/widgets/capture_command_cards.dart:1245`: `_QuestionPanel` has `key: ValueKey('command-choice')`, with `super.key` added at `:363`. In `voice_task_screen.dart:2919-2934`, `_reveal` treats a card that holds this key as a set's heading: `ensureVisible(card, alignment: 0)`. Other cards are revealed as before. `_Choice` is drawn only while `view.choosing` (`capture_command_cards.dart:1407`, `:1821`, `:1907`), so a card that has been answered goes back to its question reveal.
- Renders:
  - `commands/cards.change-which.es.light.2x` and `.ca.light.2x`: the card's top edge, the pencil, «¿Cuál quieres cambiar?» / «Quina vols canviar?» and the ✕ are all in view, and both choices are whole.
  - `es.light.1x` is unchanged.
  - AUDIT `commands/cards · change-which`: no ✕ under 48 dp, and the ✕ is 48 × 48 dp at 1×. The «Mostra què he dit» entry, 312 × 5 dp at ca 2×, is the transcript row cut off at the bottom of the scroll view, not a real target.

**UX-2620 · fixed**
- `App/lib/widgets/capture_review_editor.dart:907-919`: with no day, the repeat row reads `repeatNeedsDate` and its tap is `widget.enabled ? _schedule : null`, the same as `_needsDayLine`. `_row` draws the chevron. With a day, the row still opens `editTaskRepeat`. The comment above the row has been updated.
- Renders: in `capture/result.more-no-day.es.light.1x`, «Añade una fecha para repetir» has a chevron and is fully in view. In `.ca.light.2x`, «Afegeix una data per repetir» wraps to three lines, with its chevron, and nothing is clipped.
- AUDIT TalkBack: «Añade una fecha para repetir» → button → tap.
- Tests: the P298 group in `review_tasks_test.dart:2904`. The two P275 checks were updated by the implementer because the fix rightly broke them. All pass, per the tester.

### Regressions
None found.

The speed bar holds:
- A one-task save still takes `day`/`due` (`first` needs `ready.length > 1`).
- The test 'a plain single-task dictation looks and saves exactly as before, with no new tap' passes, per the tester.

### Notes for the organizer: not regressions, so no IDs
- **Command path, rare mix.** When a voice change or completion lands on an earlier day than every new task, Calendar lands on that earlier day, but the message names the earliest *added* day, as the brief asks (`:3955-3961`). The landing day was never named in that mix before either, so this isn't a regression. If it matters, the fix is to name `days.first` only when it is in `addedDays`.
- **Two "add a date" rows behave differently.** In «Más opciones» with no day, the reminder line just below the repeat row, «Añade una fecha para usar un recordatorio» (`dateForReminder`), is still text with no tap. That was decided and verified under UX-1811. Next to the repeat row, which now taps through to the date sheet, a newcomer may tap it and get nothing. It has no chevron and its icon is grey, so it reads as text. Severity 1 at most; for the organizer to weigh.
- **CA 2× landing, from P274.** In `calendar/agenda.added.ca.light.2x`, the heading «L'agenda d'avui» and one lit row show, and the message covers the second lit row. This is P274's landing in `calendar_screen.dart`, which this package was told not to touch; the message now at least names the day.
