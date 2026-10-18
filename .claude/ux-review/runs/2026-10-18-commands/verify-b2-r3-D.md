## UX verify — run 2026-10-18-commands, round 3, area D (P151) — 2026-10-18

**Verdict:** Ship. UX-1220 is fixed and the four round-2 findings still hold. No regressions in the one changed file.
**Scope:** `git diff HEAD -- App/lib/screens/login_screen.dart` (the only file changed this round). I read the code and the Flutter SDK source. I didn't run Flutter. No static preview shows a route transition, so I relied on the code and the tester's acceptance test, not on a render.

| ID | status | evidence |
|---|---|---|
| UX-1220 | fixed | `App/lib/screens/login_screen.dart:23-30`: `_ShownAtOnce` now overrides only `transitionDuration => Duration.zero`. The `reverseTransitionDuration` override is gone, and grep finds no `reverseTransitionDuration` in the file. The doc comment at :23-24 reads exactly as the brief asks. In the SDK, `MaterialRouteTransitionMixin.reverseTransitionDuration` (`flutter/packages/flutter/lib/src/material/page.dart:96-98`) reads the theme builder's `reverseTransitionDuration` on its own, so Back from the reopened screen now plays the same animation as every other Back. Sign-up and sign-in still push a plain `MaterialPageRoute` (:231-233). The acceptance test is in place: `App/test/email_verification_test.dart:2189-2208` compares the reverse duration with a plain route's and checks that the source has no override. The tester reported no failures. The phone check (Back or swipe back after a restart) is still open. |
| UX-1215 | fixed | `verifyEmailWrongPassword` is in `app_en.arb:769`, `app_es.arb:455` and `app_ca.arb:434`. `_showWrongPassword` (`verify_email_screen.dart:353-360`) shows it from the first refusal, with no counter. `errorMaxLines: 12` on the password field is at :576. |
| UX-1216 | fixed | `pending_verification.dart:61-68`: `load()` and `resume()` return `({String email, DateTime sentAt})`. `verify_email_screen.dart:110-116` counts down from `max(0, resendWait − elapsed)`, starting at `widget.sentAt`. |
| UX-1217 | fixed (code); phone check open | `main.dart:95` reads `pendingVerificationLoadProvider` (the memoised `load()`) in `initState`. While signed out, `main.dart:388-398` keeps showing the restoring screen until that load is done. `_ShownAtOnce` opens with zero duration. |
| UX-1218 | fixed | `main.dart:372-375`: `forget()` runs whenever a different account id signs in. `grep "confirmed()" App/lib` returns nothing. |

### Regressions
None. The round removed one getter override and updated one comment. Opening is unchanged (no slide). Closing now uses the theme's reverse duration, which is the same path every other `MaterialPageRoute` uses, so the predictive-back and swipe-back behaviour matches the rest of the app. No copy, layout or what the screen asks and sends changed.
