## UX verify — round 3, area B (P57) — 2026-10-13
**Verdict:** Fixed. A tapped retry now keeps its 48 dp line, with a spinner, until the read settles, on both failure paths. One new polish point for TalkBack.
**Evidence level:** code only. ux-tester reported no proof, and the fresh calendar renders (App/build/calendar-es-1.3x-*.png, 20:39, newer than the code at 20:30) don't show the events line because the preview has phone calendars turned off.

### UX-447 · fixed
- `App/lib/widgets/device_calendar_events.dart:23-51`: the widget is now a `ConsumerStatefulWidget` with `_retrying`. Only the two retry taps set it, through `_retry` (:42-50). `_retry` awaits the read, swallows the error, and clears the flag with `setState` if the widget is still mounted.
- Path a, the phone-calendar read (:65-74): `state.error` → if retrying, `busy`. `refresh()` resets to `checking` (provider :134-137) → `_retrying ? busy : shrink`. `refresh()` awaits `_refresh`, so the flag clears only after the read has settled. On a second failure, `error` comes back and the normal retry line with its event icon returns.
- Path b, the day's events read (:79-90): `loading` and `error` both show `busy` while retrying. The retry calls `ref.invalidate`, then awaits `deviceEventsProvider(key).future`, and catches the error.
- `_EventsLine` (:114-151): `busy` swaps `Icons.event_outlined` for a 20×20 `CircularProgressIndicator(strokeWidth: 2)` in `onSurfaceVariant`. `onTap: null` blocks a second read. The 48 dp minimum height and the padding are unchanged. The text is unchanged.
- Unchanged, as briefed: the first load and every other refresh still return `SizedBox.shrink()` while loading, because `_retrying` is false then. No new ARB keys. `device_calendar_provider.dart` is untouched in this round.
- `didUpdateWidget` (:35-40) clears `_retrying` when the day changes, so another day never inherits a spinner.
- Leftover, not a regression (the success path collapsed before this change too): after a successful path-a retry, `refresh()` resolves as soon as the calendars are read. The flag clears while the day's events are still loading, so the line disappears briefly and then returns as the count line. The failure case the finding was about is covered. To close it, path a could also await `deviceEventsProvider(key).future` when access is granted and calendars are selected.
- Worst case: `status()` has no timeout, and `calendars()` and `events()` time out after 15 s (`App/lib/services/device_calendars.dart:44,59`). A hung read leaves a spinner that can't be tapped for 15 s or more. Before this change, the line simply vanished. This is rare, and the spinner is the better state.

### Regressions
**R3B-1 · Severity 1 · TalkBack hears a dead "button" while retrying**
- Where: `App/lib/widgets/device_calendar_events.dart:126-129` (`Semantics(button: true, ...)` around `InkWell(onTap: null)`) and :139-144 (spinner with no semantics).
- The moment (TalkBack): "It says 'No se pudieron leer los eventos. Toca para reintentar, botón'. I double-tap and nothing happens. Is it broken?"
- What happens: while busy, the line is still announced as an enabled button with the same "Toca para reintentar" text, and the spinner says nothing. A double-tap does nothing, and no announcement says a read is under way.
- Why: name, role and value must match the state (WCAG 2.2, 4.1.2); visibility of system status (Nielsen 1994).
- Fix: `Semantics(button: true, enabled: onTap != null, ...)`. TalkBack then says "desactivado" while the read runs, and needs no new string.
- Verify: semantics test. While a retry is pending, `calendar-events-line` has the button flag with `isEnabled: false`. After it settles, `isEnabled: true`.
- Evidence: verified in code.

No other regressions: the access lines (`calendarDenied`, `calendarNoSelection`) still open `/deviceCalendars`, the count line still opens the sheet, and the line keeps its key, height and padding.
