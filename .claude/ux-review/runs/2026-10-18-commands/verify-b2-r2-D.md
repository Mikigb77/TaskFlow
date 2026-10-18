## UX verify — run 2026-10-18-commands, round 2, area D (P149) — 2026-10-18

**Verdict:** all four findings fixed in code; one polish regression (R2D-1). No verify-email preview exists (only `artifacts/auth/login-*.png`, which this package doesn't change), so the judgement rests on code and on the tester's widget tests, which I read but didn't run.

### Findings

**UX-1215 · fixed**
- `verifyEmailWrongPassword` now reads, in all three catalogs: EN `app_en.arb:769`, ES `app_es.arb:455`, CA `app_ca.arb:434`. Each text matches the brief word for word, and each quoted label matches that catalog's `verifyEmailOtherAddress` (EN :761, ES :453, CA :432). The `@` description is updated (`app_en.arb:771`).
- `_showWrongPassword` (`verify_email_screen.dart:350-361`) has no counter, so the line shows from the first refusal.
- «Usar otro correo» calls `forget()`, then pops `otherAddress`. `_confirmEmail` then runs `_mode(register: true)` with the email kept (`login_screen.dart:238-239`).
- `errorMaxLines` is 12, not the 8 the brief asked to keep (`verify_email_screen.dart:573-576`). The comment says the line runs past 8 lines in EN and CA at 2× on 320 dp. That deviation is right: 8 lines would cut the line.
- Tests: `email_verification_test.dart:1919` (ES, first refusal, lands on «Crea tu cuenta» with the address), :1957 (EN and CA text, labels match), :1985 (CA, 2×, 320×640: whole line under the field, no overflow).

**UX-1216 · fixed**
- `resume()` and `load()` return `({String email, DateTime sentAt})` (`pending_verification.dart:61-68`). The login screen passes `sentAt` on through `resumedFrom` (`login_screen.dart:89`, :232-233).
- `VerifyEmailScreen.sentAt` has its doc comment (`verify_email_screen.dart:59-61`). `initState` uses `_sentAt = widget.sentAt ?? _now()` and `max(0, 60 − elapsed)` (:110-116), and `_countDown` returns at once for 0 (:141-142).
- Reopening calls `remember()` nowhere. `_confirmEmail` remembers only when it has a password (`login_screen.dart:228-230`).
- `_codeSpent` gives `sentNew` when the code is 60 s old or more, and its `remember()` then moves the saved time forward.
- Tests: `:2013` (5 min: Reenviar on at once, storage not rewritten, `code_expired` + 403 gives `verifyEmailCodeSpentNew` and empties the field) and `:2037` (20 s: «Reenviar código en 40 segundos»).

**UX-1217 · fixed (needs a phone)**
- `load()` is memoised (`pending_verification.dart:61`), and `remember()` and `forget()` drop the memo (:40, :55). `pendingVerificationLoadProvider` is read in `MyApp.initState` (`main.dart:94-95`), in parallel with the restore.
- While signed out, `restoring` waits for that read (`main.dart:391-398`) and drives '/' and `onGenerateRoute` (:449, :479).
- `resume()` keeps its once-per-process rule (:64-68). `_resumeConfirming` now starts from `initState`, and the memoised Future has already finished, so the push comes after at most one frame.
- `_ShownAtOnce` sets `transitionDuration` to `Duration.zero` (`login_screen.dart:25-33`). Sign-up and sign-in still use `MaterialPageRoute`.
- Test `:2054` counts the frames: at most one of sign-in, none sliding, zero transition, nothing sent.
- The flash is still inferred from code. It needs the phone check with «No mantener actividades».

**UX-1218 · fixed**
- `main.dart:371-375` calls `forget()` whenever a different account id signs in, restored sessions included, with the comment «Signed in, nobody waits for a code.»
- `confirmed()` is gone: a search of lib/ and test/ finds no call.
- Test `:2118` covers password and Google sign-in as B: no entry left, sign-in stays on «Inicia sesión», and a cold start opens plain sign-in.

### Regressions

**R2D-1 · Severity 1 · Closing the reopened screen plays a shorter back animation**
- Where: `login_screen.dart:31-32`, `_ShownAtOnce.reverseTransitionDuration => 300 ms`.
- What happens: on Android, `MaterialPageRoute` takes its reverse duration from the theme's builder. That builder is `PredictiveBackPageTransitionsBuilder`, which runs 450 ms (FadeForwards' `kTransitionMilliseconds`, Flutter `material/page.dart:96`). So Back from the reopened «Confirma tu correo» plays 150 ms faster than every other Back in the app. The brief asked closing to "keep the usual reverse transition".
- Why it matters: consistency (lens F/N, Nielsen #4). It's cosmetic.
- Fix: delete the `reverseTransitionDuration` override. `MaterialRouteTransitionMixin` then supplies the theme's own duration.
- Verify: `(route as TransitionRoute).reverseTransitionDuration` equals that of a `MaterialPageRoute` pushed the same way.
- Evidence: verified in code and in the Flutter SDK source.

Checked, no regression found:
- the SessionLoadingScreen hold applies only when signed out; signed-in starts aren't delayed;
- `_read` catches every error, so the hold can't stick on an error;
- a `forget()` during the first read drops the memo, so a later `resume()` reads storage as it is;
- session-expiry sign-in still never resumes (`login_screen.dart:73-76`);
- sign-up's `signup_replaced` still returns to «Crea tu cuenta» (`verify_email_screen.dart:300-304`).

Out of my scope: `main.dart:206-207` (`showCalendar: true` on capture entries) belongs to another area's package.
