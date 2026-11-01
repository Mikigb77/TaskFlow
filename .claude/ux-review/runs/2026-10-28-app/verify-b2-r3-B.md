## UX verify — 2026-10-28-app · b2 round 3 · area B — 2026-11-01

**Verdict:** both findings fixed; no regressions in the changed files.

### UX-2632 (P306) · fixed
- Code: `App/lib/widgets/repeat_rule_control.dart:116-128` (`_scroll` owned and disposed, `_overflows`, `_onMetrics` sets state only on change and returns false), `:139-149` (`Flexible > NotificationListener<ScrollMetricsNotification> > Scrollbar(controller: _scroll, thumbVisibility: true) > SingleChildScrollView(controller: _scroll)`), `:216-219` (`Divider(height: 1, key: repeat-sheet-foot-edge, color: _overflows ? null : transparent)` directly above Listo's padding). Everything from P301 is kept: the five `repeat-$value` rows with their ✓, `Divider(height: 24)`, pinned Listo, `Navigator.pop(context, _task)`. No copy changed.
- Renders (09:52 today, nothing in lib/ or assets/ is newer):
  - `form/repeat-sheet.open.ca.light.2x.png`: a thumb along the right edge beside the details, from under the handle to about halfway down, and a drawn line directly above «Fet». The chips «dl. dt. dc. dj.» now end at a visible edge, so the line tells you there's more below.
  - `es.light.2x`: same thumb and line above «Listo»; the chip row cut by the line now reads as "goes on".
  - `es.light.1x`: thumb and line show too, because with no weekday chosen the hint «Usa el día de la semana de la fecha de inicio.» pushes «Sin fecha de fin» 16 dp under the line. That's the intended overflow-driven behaviour. The cue is accurate, and the row stays mostly visible and tappable (AUDIT: 312 × 56 dp, 17 dp above Listo). The acceptance's 1× "nothing scrolls" case holds in the test, where a weekday is set. A task with none still shows the cue, which is honest.
- Tests (tester): the 2× ES/CA thumb and edge checks, the 1× weekly and none checks, scroll to the end with Listo whole, and P301's checks all pass.
- AUDIT `form/repeat-sheet · open`: only the problems the brief already lists (the rows' 0 dp gaps, the 2× chip height). Nothing new.

### UX-2633 (P307) · fixed (the device check with TalkBack is still open for the main session)
- Code: `App/lib/screens/task_detail_screen.dart:243-245` wraps the data branch's `Scaffold` in `AbsorbPointer(absorbing: _closing)`. The loading, error and unavailable Scaffolds (`:183`) aren't wrapped. Completar and «Cambiar fecha» keep `onPressed: null` while `_closing` (`:570`, `:585`). `_toggle` (`:62-86`), after 300 ms: if the route is current, it pops; if it's active (something opened over the page), it sets `_closing = false; _leaving = null` and stays; otherwise (Back already popped it), it does nothing. The doc comments on `_closing` and `_toggle` are updated.
- AbsorbPointer also marks its subtree as blocking user actions in semantics. The tester proved that ✏ offers no tap to TalkBack during the hold (`task_detail_test.dart:2406-2427`). So the isActive branch is now a safety net (a navigator push from elsewhere), not something a user can normally reach.
- Tests (tester, `task_detail_test.dart:2279-2586`) all pass:
  - ✏ at 100 and 400 ms;
  - «Planificado para», the reminder chip and a step at 100 ms;
  - a page or a sheet pushed over the page, then Back: «Reabrir» and «Cambiar fecha» are enabled, the page doesn't pop by itself, and it takes taps again;
  - system Back at 100 ms: one pop, and Calendar is not popped;
  - P302's group still passes.
- No preview, because the hold isn't rendered. Device check still open: on the emulator and then the phone, with TalkBack, Completar and then a quick double-tap on ✏.

### Regressions
None caused by these changes. Checked:
- the sheet's height doesn't jump (the edge stays at 1 dp, transparent);
- the thumb sits in the 24 dp right padding, clear of ✓ and ✏;
- the Scrollbar adds no semantics node;
- the Scaffold-level AbsorbPointer, for other entries to the page (Tasks, Home, a notification), only takes effect while `_closing`;
- a «Deshacer» tap on the page's own copy of the message during the 300 ms is absorbed. It's negligible: the message is still animating in, and the same message stays on Calendar after the pop.
