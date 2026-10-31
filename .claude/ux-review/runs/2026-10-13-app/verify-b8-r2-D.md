## UX verify — 2026-10-13-app, b8 round 2, area D (P111) — 2026-10-14

**Verdict:** Ship. UX-623 is fixed in code and in widget tests; only the server-side expiry on a phone remains.

### UX-623 · fixed (device check pending)
- Reason line: `App/lib/screens/login_screen.dart:349-354` shows `signInAgainReason` when `widget.signInAgain`, in sign-in and create modes; recovery keeps `recoveryHelp`. Driven by the widget flag only, so typing, a failed attempt or Back can't hide it.
- Route: `App/lib/main.dart:306-310` pushes `PopScope(canPop: false, child: LoginScreen(signInAgain: true))`; cold start still uses `LoginScreen()`.
- Prefill: `login_screen.dart:53-55` fills `_email` from `authProvider.account?.email`; `auth_provider.dart:52-58` keeps the account on expiry, so the email is there.
- No double message: `login_screen.dart:257-264` hides only the expiry's own `session` error; errors from the user's own attempt go through `_error` and still show.
- Back: `login_screen.dart:294` now calls `_mode()` only in create/recovery. On the sign-in-again route Back changes nothing; on cold start sign-in mode can pop as before (`canPop` unchanged).
- Copy: EN/ES/CA in the three ARBs match the brief exactly, with the typographic apostrophe in Catalan and a description in app_en.arb.
- Tests: `App/test/session_resume_test.dart:251-383` cover all seven acceptance checks (ux-tester: pass), including Catalan at 2× on 320×640 with no overflow.
- Still needs a phone: the session expiring from the server while the user types a task.

### Regressions
None found in login_screen.dart, main.dart (sign-in-again wiring) or the ARB keys. The cold-start sign-in's heading, pitch, empty email and create-mode Back are unchanged (tested).

### Noted, not a regression
- On the sign-in-again route, system Back does nothing and gives no feedback. That comes from P30's outer `PopScope(canPop: false)`, which was meant to work this way. The reason line now explains the screen, so the newcomer isn't left guessing.
- In create mode on this route, the reason line sits under "Crear cuenta". The brief asked for this, and it still reads correctly.
