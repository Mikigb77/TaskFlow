## UX verify — run 2026-10-13-app, round 2, area B (P52) — 2026-10-13

**Verdict:** All four findings fixed in code and in current renders; two device checks remain (1.3x phone, TalkBack). One polish-level regression.

Renders read: App/build/calendar-es-1.3x-light.png, calendar-es-1.3x-dark.png, calendar-feedback-light.png (all 20:19, newer than the 19:55 code).

### UX-202 · fixed (device check pending)
- Month line: App/lib/screens/calendar_screen.dart:327-337 uses `DateFormat.LLLL` when `_focusedDay.year == _now().year`, else `yMMMM`. Wrap kept (:323), so 2x / 320 dp still wraps instead of overflowing.
- Heading padding 26 -> 12: calendar_screen.dart:527.
- ProjectScopeControl: returns `SizedBox.shrink()` when it draws nothing (project_scope_control.dart:29-32); padding applied only when drawn (:33-34); Calendar passes the padding (calendar_screen.dart:276-280). Home's use (home_screen.dart:71) unchanged.
- Render calendar-es-1.3x-light/dark (2x pixel ratio): `octubre  Semana ▾` on one line with the chevrons; second task bottom ≈ y 585 dp, `Dictar una tarea` top ≈ y 600 dp, so both tasks are fully above the bar with ~15 dp to spare. Round 1's measurement was 639 vs 590.
- Tester: 1.3x light/dark, month-without-year (ES/CA/EN), 2027 form, zero-height scope: all pass.
- Device: Spanish 1.3x on a 390x844 phone still to do.

### UX-446 · fixed (TalkBack check pending)
- calendar_screen.dart:341 `tooltip: context.l10n.changeView`; keys app_en.arb:156 `Change view`, app_es.arb:121 `Cambiar vista`, app_ca.arb:100 `Canvia la vista`. Tests pass in three languages.

### UX-442 · fixed
- device_calendar_events.dart:35-38: `state.error` line reads `calendarReadRetry`, tap calls `deviceCalendarProvider.notifier.refresh()`.
- :52-54: per-day load error reads `calendarReadRetry`, tap invalidates `deviceEventsProvider(day)`; no sheet, no /deviceCalendars.
- Access prompts (`calendarDenied`, `calendarNoSelection`) still open /deviceCalendars (:42-47).
- Copy: EN `Couldn’t read your events. Tap to try again.` / ES `No se pudieron leer los eventos. Toca para reintentar.` / CA `No s’han pogut llegir els esdeveniments. Toca per tornar-ho a provar.` (arb en:155, es:120, ca:99). `calendarReadError` kept for the no-tap places.

### UX-445 · fixed
- task_planning_control.dart:7-13 `taskDeadlineLabel` now uses `context.weekdayDate` (MMMEd, region.dart:22-23), the same format as the tile's date (`vie, 16 oct`). Tile: `Vence dom, 12 oct · Fecha límite vencida` (task_tile.dart:182-186). CA reads `Termini: dg., 12 d’oct.`; EN `Due Sun, Oct 12`.
- Plan said `dom, 12 de oct`; intl's es MMMEd gives `dom, 12 oct`, which matches UX-111's schedule label, so this is consistent.
- Also changes the detail (task_detail_screen.dart:246), form (task_editor.dart:769), planning control (:142) and capture review (capture_review_editor.dart:408), as intended.

### Regressions
**R2B-1 · Severity 1 · Retry tap gives no sign it tried**
- Where: App/lib/widgets/device_calendar_events.dart:39-41 and :49-54 (`loading: SizedBox.shrink()`, `skipLoadingOnRefresh: false`); provider refresh resets access to `checking` (device_calendar_provider.dart:133-135).
- The moment: "I tapped 'Toca para reintentar'... the line blinked and it's the same. Did it do anything?"
- What happens: on tap the line collapses (48 dp, so the content below jumps up), then comes back with identical text if the read fails again. A fast failure looks like nothing happened.
- Why: visibility of system status (Nielsen 1994); gulf of evaluation (Norman 2013).
- Fix: while retrying, keep the line in place and swap its icon for a small progress indicator (no new string); remove the collapse. If it fails again, the same line is fine.
- Verify: widget test where the fake fails twice: the line keeps its height during the retry and shows a progress indicator.
- Evidence: inferred from code; rare state (phone calendar read failure).

No other regressions in the changed files: the month Wrap still wraps at 2x/320 dp, home's ProjectScopeControl is unchanged in practice, and the deadline line wraps rather than clips.
