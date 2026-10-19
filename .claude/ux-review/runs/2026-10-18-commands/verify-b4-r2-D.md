## UX verify — run 2026-10-18-commands, b4 round 2, area D — 2026-10-19

Scope: P162 (UX-1231). File changed: `App/lib/screens/verify_email_screen.dart` (diff HEAD also holds P156, uncommitted; only the `_problem` branch is P162).

### UX-1231 · fixed (needs a device check)
- `_problem` (`verify_email_screen.dart:226-233`): for a `resend_limited` error it now returns `l.verifyEmailResendLimited(_minutes(_wait))`, the time left that the button counts (`:715-723` uses the same `_wait` and `_minutes`). It returns null when `_limitedUntil` is null or `_wait <= 60`, explicitly, so neither `_refusal` nor `requestProblemText` prints a second 429 line. The comment is the one the brief asked for.
- `errorText: _problem(l)` (`:602`) is rebuilt by `_countDown`'s per-tick `setState` (`:162-168`), which takes the time left from the clock (`_secondsUntil(_readyAt, _now())`), so on return from the mail app the line and the button jump to the same number together.
- The resend catch (`:480-499`) sets `_limitedUntil` and calls `_countDown(limit.inSeconds)` before `_problem(l)`, so the first line and its announcement still read «Espera 30 minutos»; `_show` is now skipped when `_problem` is null (a refusal of 60 s or less), so there is no `!` crash.
- Tests (ux-tester, all pass): 0 min → «30 minutos» line and button; 8 min → «22 minutos» on both, button off, «123» kept; 28:30 → «2 minutos» on both; 29:00 → no line, nothing reads «Has pedido» or «Demasiad», button «Reenviar código en 60 segundos», off, digits kept (`App/test/email_verification_test.dart:2769-2844`). The five UX-1206 tests pass unchanged.
- Render: `App/build/ux/auth/verify-email.resend-limited.es.light.2x.png` (2026-10-19 09:40, no newer file in `App/lib`) shows the line at 30 minutes under the field with «4829» kept, at 2× text. The render only shows the moment of refusal; the countdown is proven by the tests, not by a render.
- Walkthrough (newcomer, Spanish, 2×): taps Reenviar → reads «Has pedido muchos códigos. Espera 30 minutos para pedir otro.» → goes to the mail app → comes back 8 minutes later → the line and the button both say 22 minutes. The two numbers no longer disagree. In the last minute only the button counts the seconds, as P156 decided for a 60 s refusal.

### Regressions in the changed file and its flows
None found.
- Other `_show(_problem(l)!)` calls (`:319, :372, :406, :447`) would throw if `_error` were a `resend_limited` error with `_limitedUntil` null. Checked: only `ResendVerificationView` sends `resend_limited` (`Backend/core/auth_views.py:159`), and only `_resend` handles that answer, after setting `_limitedUntil`. So that can't happen today.
- The field keeps its red outline only while the line shows. In the last minute both go, and typing a digit still clears `_error` (`_changed`, `:283-290`).

### Device check (not a finding)
On Android the field's error line is a live region (Flutter `input_decorator.dart` `_buildError`: `liveRegion: !MediaQuery.supportsAnnounceOf(context)`). Its text now changes once a minute. Whether TalkBack reads it out again each minute, up to about 28 times, depends on the engine's Android bridge and can't be seen in a widget test. Check it on a phone with TalkBack, as the package's device check says. If it is read each minute, keep the line's spoken text fixed after the first announcement, or let only the button say the time left.

Evidence level: code, widget tests and one current render. Neither the staging server (d447c5c) nor TalkBack has been tried on a device.
