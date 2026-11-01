## UX verify — run 2026-10-28-app, batch b2, round 2, area B (P301, P302) — 2026-11-01

**Verdict:** All four fixed. Ship after two small follow-ups, both new problems this round's changes caused (R2B-1, R2B-2). Neither blocks.
**Evidence used:** code (`git diff HEAD`), current renders (`form/repeat-sheet.open.*` and `tasks/detail.*`, rendered 2026-11-01 09:11–09:12; nothing under App/lib changed after them), AUDIT `form/repeat-sheet · open`, and the tester's widget tests. No device evidence. The real second tap on the leaving page (P302 deviceChecks) still needs the emulator, then the phone.

### Findings

**UX-2621 · fixed.**
- `App/lib/widgets/repeat_rule_control.dart`, inside `if (_task.isRecurring) ...[`: `const Divider(height: 24)` now comes before `RepeatRuleControl`.
- Render `form/repeat-sheet.open.es.light.1x`: a full-width line separates «Cada año» from «Cada semana / Intervalo de repetición ✎», with clear space on both sides. AUDIT has no gap flag between them, and the interval row's nearest neighbour is «lun», 21 dp away.
- With «No se repite» ticked there is neither the line nor the interval row: test `UX-2621/UX-2622 (es, 1×)`.

**UX-2622 · fixed.**
- Listo is now pinned: `SafeArea > Column(min, stretch) > [Flexible(SingleChildScrollView(fromLTRB 24,24,24,0)), Padding(fromLTRB 24,16,24,24, FilledButton)]`.
- Renders `es.light.2x` and `ca.light.2x`: «Listo» and «Fet» show whole at the foot of the sheet.
- The sheet still hugs its content at 1× with «No se repite»: tester's test.
- Listo still pops with `_task`. Choosing «Cada mes» returns `monthly`, and the end-date row still opens the date picker: `recurrence_controls_test.dart:255-284`.

**UX-2623 · fixed (widget-test level; the real second tap is a device check).**
- Half 1 is in `App/lib/screens/task_detail_screen.dart`. `_toggle` sets `_leaving` and `_closing`, ticks at once, waits 300 ms, then pops only if the page is still mounted and its route is still current. While `_closing`, Completar (`onPressed: _closing ? null : …`) and «Cambiar fecha» are off. Completar keeps its check icon and the label «Completar», because `_leaving` holds the open task.
- On a completed task, «Reabrir» takes the early return: no hold and no pop.
- Half 2 is in `App/lib/widgets/task_actions.dart` `_add()`. It returns at once when `ModalRoute.of(context)?.secondaryAnimation?.status == AnimationStatus.reverse`.
- Flutter's `PageRoute.canTransitionTo` accepts only PageRoutes (`/opt/sdk/flutter/.../widgets/pages.dart:57`). So closing a bottom sheet or a dialog never drives this guard; only a page leaving does.
- The guard covers Calendar, Tareas (`home_screen.dart:928`) and Día (`day_timeline_screen.dart:336`).
- All six acceptance tests are in `task_detail_test.dart:1905-2140`.
- Residual, not a regression: screens without TaskActions under a leaving page (Activity, the Notes list, Tasks with files) have no guard of their own. Only a tap more than 300 ms after Completar, during the exit transition, could reach them. A double tap usually comes faster.

**UX-2624 · fixed.**
- The date line joins day and time with `' · '`.
- Render `detail.full.es.light.1x`: «domingo, 1 de noviembre» / «· 21:00».
- Render `detail.notes-steps.es.light.2x`: «lunes, 2 de» / «noviembre» / «· 09:00».
- No line ends in «·». The tests cover es and ca at 1× and 2×.

### Regressions

**R2B-1 · Severity 2 · Pinned Listo hides that the repeat details continue**
- Where: `App/lib/widgets/repeat_rule_control.dart`, `_RepeatSheetState.build`, the `Flexible(SingleChildScrollView)` above the pinned Listo. The state is 2× text with «Cada semana» ticked.
- The moment: «Solo hay lunes a jueves. ¿Y el viernes?», and in Catalan «Fet» seems to be all there is.
- What happens: in `form/repeat-sheet.open.ca.light.2x` the scroll area ends exactly under the first row of weekday chips («dl. dt. dc. dj.»). The rest is out of sight: «dv. ds. dg.», «Utilitza el dia de la setmana…» and the end-date row. Nothing shows that it's there: no scrollbar, and no row cut in half. Before this round, people had to scroll to reach Listo, so they passed the end date on the way. Now Listo is in view, and a newcomer taps it without ever finding the hidden details.
- In `es.light.2x` a sliver of the chips peeks out (23 dp tall in AUDIT), so there is some cue there. Even so, that sliver is a tap target 17 dp above Listo.
- Why it fails: recurring problem 36, a pinned bar removes the scroll cue. Under H, controls must not be hidden without a signifier (Pernice & Budiu 2016). Under A, visibility of system status (Nielsen 1994).
- Fix:
  - Give the `SingleChildScrollView` a `ScrollController` and wrap it in `Scrollbar(controller: …, thumbVisibility: true)`. The thumb then shows whenever the details overflow.
  - Draw a 1 dp line (`Divider(height: 1)`) on top of the pinned Listo area only while the content scrolls, as the reminder sheet's fixed header does (UX-2035).
  - No copy.
- Verify: re-render `form/repeat-sheet.open.ca.light.2x` and `es.light.2x`. A scrollbar thumb should show, with an edge above «Fet»/«Listo». At 1×, where everything fits, no thumb shows.
- Evidence: seen in a current render.

**R2B-2 · Severity 2 · Task page stays frozen if another control opens during the hold**
- Where: `App/lib/screens/task_detail_screen.dart`, `_toggle`, after the 300 ms wait. `_closing` and `_leaving` are set there and never cleared.
- The moment: «Le di a Completar y luego al lápiz. Ahora vuelvo y Completar está gris y la tarea sigue ahí».
- What happens: other controls on the page stay live during the 300 ms hold: ✏ (edit), the «Planificado para» row (the reschedule sheet), the other detail rows (the form), the reminder chip and the steps. If one of them opens a route or sheet within those 300 ms, the route isn't current when the wait ends, so `_toggle` returns without popping. `_closing` stays true and `_leaving` stays the old, open copy of the task. Coming back, the person finds the page still there: Completar and «Cambiar fecha» greyed out for good, and the task shown as not done even though it is ticked. Back is the only way out.
- It is rare: it takes a second tap on a different control within 300 ms. Even so, the page then misreports the task's state, so it breaks trust.
- Why it fails: visibility of system status, and user control and freedom (Nielsen 1994); a dead end (lens A).
- Fix:
  - While `_closing`, wrap the page's body and bottom bar in `AbsorbPointer(absorbing: _closing, …)`, so for its 300 ms the whole page is inert, not just its two buttons.
  - In `_toggle`'s not-current branch, if still `mounted`, call `setState(() { _closing = false; _leaving = null; })`. The page then shows the real, ticked task.
  - No copy.
- Verify: a widget test. Tap Completar, tap ✏ at 100 ms and pump 400 ms: either nothing opens, or after Back from the form the page shows «Reabrir», enabled, and no Completar.
- Evidence: verified in code; inferred, not rendered.

### Untouched by this round, checked
- `task_actions.dart` also changed the button's top padding from 10 to 8 dp (UX-2203, round 1). That isn't this round's scope.
- The detail page's other round-1 changes in the same diff (labels as one line, one date row, the deadline line) are already verified in verify-b2-r1-B2.md and weren't re-judged.
