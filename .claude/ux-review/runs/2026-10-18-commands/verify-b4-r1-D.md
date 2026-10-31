## UX verify — run 2026-10-18-commands, b4 round 1, area D (P156) — 2026-10-19

**Verdict:** UX-1206 fixed in the app; one small regression in the new line (its minutes don't follow the countdown).
**Evidence levels:** code (`git diff HEAD`), the ux-tester's widget tests (all pass), and the current renders `App/build/ux/auth/verify-email.resend-limited.{es,ca}.light.2x.png` (06:56, newer than every file in `App/lib` and `App/assets`). No device.

### UX-1206 · fixed (device check pending)
- `App/lib/screens/verify_email_screen.dart:182-197` `_resendLimit`: only a 429 whose body `code` is `resend_limited` counts. The wait comes from `retry_after` (a number or a string), or else the `Retry-After` header.
- `:474-496` (resend catch):
  - `_limitedUntil` is set to an end time on the clock, and `_countDown(limit)` keeps «Reenviar código» off. `_countDown` (`:148-172`) never ends before `_limitedUntil`, so `_codeSpent`'s shorter countdown can't cut it short.
  - Past 60 s, the error line is set. At 60 s or less there's no line, only the seconds countdown.
  - `_resent` stays false, so «Te hemos enviado un código nuevo» never shows, and `_code` isn't cleared, so the digits stay.
  - Any other 429 keeps today's handling (`:490-492`).
- `:226-229`: the line is `verifyEmailResendLimited(minutes)`, rounded up, at least 1 (`_minutes`, `:197`).
- `:711-719`: the button reads `verifyEmailResendInMinutes` while more than 60 s are left, then `verifyEmailResendIn`.
- `:168`: the line clears when the wait ends, and `_changed` (`:278`) clears it when a digit is typed, as the brief allows.
- Copy: in all three ARBs, exactly as the brief gives it, with ICU plurals and @descriptions (`app_en.arb` `verifyEmailResendInMinutes`, `verifyEmailResendLimited`).
- Renders, ES and CA at 2×:
  - the line sits whole under the field;
  - «4829» stays;
  - AUDIT.md lists button 7 as «Reenviar código en 30 minutos» [disabled].
- AUDIT: the CA render splits «example» across lines in the intro sentence. That was there before (the address), not from this change.
- Tests: the five P156 tests in `App/test/email_verification_test.dart:2563-2760` cover every acceptance check, including Confirmar's own 429 (UX-1208), which is unchanged.
- Left for the device, on staging: that no email arrives, and that TalkBack reads the line once.

### Regressions
**R1D-1 · Severity 2 · Wait line keeps saying 30 minutes while the button counts down**
- Where: `verify_email_screen.dart:226-229`. The line uses `_minutes(limit.inSeconds)`, the wait the server first named; the button uses `_wait` (`:711-719`).
- The moment: «Pone espera 30 minutos, pero el botón dice 22 minutos. ¿Cuál es?» This happens after the person leaves to check the mail app and comes back, the likeliest thing to do while waiting.
- What happens: the line stays at 30 until the wait ends or a digit is typed, while the button shows the real time left.
- Why it fails: the status shown must be true and consistent (Nielsen 1994: visibility of system status, consistency).
- Fix: while `_limitedUntil` is set, build the line from the time left: `verifyEmailResendLimited(_minutes(_wait))`. Drop the line once `_wait` reaches 60 s or less, since the button's seconds already say it. No new copy.
- Verify: after the 30-minute refusal, move `calendarClockProvider` 8 minutes ahead and pump one tick. The line reads «Espera 22 minutos…» and the button reads «Reenviar código en 22 minutos».

### Observations (not regressions; pre-existing or decided in the brief)
- The limit line is an `errorText`, so the code field outlines red around a code that's still valid. A newcomer may think «4829» is wrong and clear it. Every 429 here was already shown this way, so this isn't new. A neutral helper line, like `verifyEmailResent`'s, would be truer. Raise it with UX-1208 if the screen is revisited.
- A 429 of 60 s or less announces nothing (as the brief decides): a TalkBack user hears no answer to the tap, only the button's changed label, if TalkBack re-reads it. This is for the device check.
- The error line is read twice in AUDIT's TalkBack order: once as the field's hint and once as text. This was already so for every error on this field (see wrong-code).
