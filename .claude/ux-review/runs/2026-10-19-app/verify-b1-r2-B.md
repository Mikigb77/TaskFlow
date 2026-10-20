## Verify — 2026-10-19-app, round 2, area B (P197) — 2026-10-20

**Verdict:** both findings fixed; no regressions in the changed files.

### UX-1309 · fixed
- App code unchanged, as the brief settled: `_scrollToLit` (`App/lib/screens/calendar_screen.dart:184-260`) still reveals the block from first to last lit row when `lastEnd <= top`, else the first row.
- Fixture: `App/test/ux_previews/calendar_previews.dart:235-240` opens `agenda.added` with `normalDay()` minus id 4; `normalDay()` and `threeTasks()` untouched.
- Renders (07:27 today, newer than both changed files; `find lib assets -newer` lists nothing):
  - `calendar/agenda.added.es.light.1x-393.png`: «Comprar pan y leche» and the 17:00 «Recoger a los niños del colegio» both lit, both entirely above the message «3 tareas añadidas · también el vie, 23 de oct»; only one «Recoger…» row. Header «Agenda de hoy» and counts still in view.
  - `agenda.added.es.light.1x.png` (360): both lit rows above the message; header scrolled off (case (b), the whole block, as the tester measured: 407 dp block, 509 dp room).
  - `agenda.added.es.light.2x.png`: «Comprar pan y leche» and «Sin hora» whole above the message; header in view.
  - `agenda.added.ca.light.2x.png`: same in Catalan.
- Tests (tester, pass): acceptance 1 at 393×852 with animations on and off, 2× on both fixtures, (b) and (c) kept.
- Device: the largest-font phone check stays with the main session.

### UX-1628 · fixed
- `_comeBack` (`calendar_screen.dart:392-406`): after the early return (under 30 min, same day), it clears `_picked`, selects today and adds a post-frame `_scroll.jumpTo(minScrollExtent)` guarded by `mounted && hasClients`. Jump, not animate. A short return returns before it, so the offset and the picked day (D9) are kept.
- The midnight case: `didChangeAppLifecycleState` calls `_comeBack` (new day → jump) then `_followToday`, so a landing on today followed by a resume after midnight also starts at the top.
- Tests check the header's rect inside the agenda viewport and the offset at its minimum (`App/test/capture_landing_test.dart:1425-1440`), after first asserting the landing left the offset above its minimum, so a kept offset would fail. No render covers a resume; evidence is code plus widget tests. Device check (reopen next morning at the largest font) is the main session's.

### Regressions
None caused by this round. Checked: the jump can't race a landing reveal (no landing is pending on resume; a capture opened from the widget lands after the jump); `_followToday`, the midnight timer, `_scrollToLit`/`_watchLit` and fade timings are untouched; a lit row left below the fold after a 30-minute-plus return on today stays lit until scrolled to, which is P169's (c) rule.

Not this round (already in ISSUES.md): «Configuraci / ó» wrapping in the ca 2× render's tab bar (UX-421).
