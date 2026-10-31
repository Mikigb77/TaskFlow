## UX verify — b5 round 1 · area B · P72 (UX-475) — 2026-10-14

**Verdict:** UX-475 fixed in code and locked by two widget tests; one phone check remains. No regressions from P72.

### UX-475 · fixed (needs a phone check)
- `App/lib/screens/calendar_screen.dart:56-59` — new `_end` (default 20) replaces the fixed 20 dp tail; `:751` `SizedBox(height: _end)` sits directly after the Bandeja row (`:716-749`), so extra tail is room under exactly the landed row.
- `:131-141` — on a no-date landing, `_reveal` waits up to 60 frames for the save message, grows `_end` to its height + 8 (`_messageClearance`, `:190-211`, same approach as Tareas' P65 in `home_screen.dart:202-222`), then waits a frame so the scroll extent includes it.
- `:159-160` — the reveal target now uses `max(88, _end)`, so a taller message (2× text, long copy) still clears; `:161-165` keeps the row's top in view if row + message exceed the viewport.
- Reset to 20 on a new landing (`:121`), a day change (`:89`) and when Calendar is covered (`:254-259`). Dated landings untouched (they don't set `_landedInbox`).
- Geometry is right for the real shell: `main_shell.dart:94-112` has no outer Scaffold, so the message is built inside Calendar's own Scaffold, above `TaskActions` in `bottomNavigationBar` (`:756`), and the measurement finds it there.
- Tests: `App/test/capture_landing_test.dart:506-599` — full app at 390×844, save with no date, frame by frame for 1.2 s; row bottom ≤ message top, row top under the app bar, both row edges hit-testable, row lit; same with animations off. Tester reports row 509–557 vs message top 565 (was 533–581, under it). Existing dated landings pass.
- Renders: `calendar-feedback-light.png` and `calendar-es-1.3x-light.png` (04:34, newer than the 03:21 code) show idle Calendar unchanged — default tail still 20 dp. No preview covers the no-date landing itself.
- Device check: save a task without a date from Calendar at ~390×844, animations on and off; the lit Bandeja row shows whole above "Guardada sin fecha…".

### Regressions — none
- Considered: the inset stays after the highlight and the message end (until a new landing, a day change or leaving Calendar). The user sees at most a message-high blank space under Bandeja on a page that was already short; removing it when the message closes would make the page jump under the thumb. Not reported.
- Considered: `_end` is reset inside `build` when Calendar is covered; it takes effect in the same build, no visible jump.
- The invitation card and refresh changes in the same diff (`:225-232`, `:588-599`) belong to another package and were not judged here.
