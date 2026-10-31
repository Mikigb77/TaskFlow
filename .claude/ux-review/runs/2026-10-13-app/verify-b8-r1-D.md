## UX verify — 2026-10-13-app, round 1, area D (P100, P30) — 2026-10-14
**Verdict:** All four findings fixed in code and by widget tests. One minor regression is in the new sign-in-again screen (R1D-1).
**Evidence:** I read the code (`git diff HEAD`) and the tester's results. None of the changed screens has a render that shows the change: the spinner labels are semantics only, and the sign-in-again route has no preview. I didn't run Flutter.

### Findings
- **UX-513 · fixed.** `App/lib/screens/account_screen.dart:148-156` adds `progress(label, {color})` with `semanticsLabel`. It's used for Sync (`:232`, `accountSyncing`), Import (`:248`, `accountImporting`) and Sign out (`:292-295`, `accountSigningOut`, error colour kept). The strings exist in all three languages: EN `app_en.arb:615,617,638`, ES `app_es.arb:396,398,405` ("Sincronizando", "Importando tareas y notas", "Cerrando sesión") and CA `app_ca.arb:375,377,384`. The tests check the merged button node. Still needs a phone: TalkBack actually saying it.
- **UX-514 · fixed.** `billingError` accountUnavailable now reads:
  - ES `app_es.arb:1083`: "No se pudo conectar con tu cuenta de TaskFlow. Revisa tu conexión y vuelve a abrir esta pantalla."
  - EN `app_en.arb:1542`: "Could not connect to your TaskFlow account. Check your connection and open this screen again."
  - CA `app_ca.arb:780`: "No s’ha pogut connectar amb el teu compte de TaskFlow. Revisa la connexió i torna a obrir aquesta pantalla."

  None of the three says "server" or "servidor", and the UX-509 "open the screen again" wording is kept.
- **UX-424 · fixed.**
  - `main.dart:61-68`: `TaskReminders.initialize()` now runs in a post-frame callback, unawaited, and records `setup_failed` if it fails.
  - `auth_provider.dart:97-106`: `_remind()` queues `activate` and `handleLaunch` off the UI path.
  - `restore`, `signIn`, `signInWithGoogle` and `signOut` set state before reminder work, so SessionLoadingScreen no longer waits on reconcile.
  - Opening from a reminder still works: `activate()` awaits the shared `_initializing` future (`notification_service.dart:261-266`), and `_launchResponse` is set inside it (`:171`). So `handleLaunch` can't run before the launch details are read.
  - Still needs a phone: cold-start timing.
- **UX-419 · fixed.**
  - `auth_provider.dart:51-61`: when the session is invalidated, the account is kept and `expired` is set.
  - `main.dart:298-324`: `_showSignInAgain` pushes `PopScope(canPop:false, LoginScreen)` over the open screens, and `_closeSignInAgain` pops it when the same account signs back in.
  - A different account changes the `session` key, so `MaterialApp` is rebuilt (`main.dart:373-383`).
  - Entries, invitations and reminders are held back while expired (`:138`, `:224`, `:257`), then resume through the listener once sign-in closes.
  - `refreshAccount` is skipped while expired. `clearError` and failed sign-ins keep `expired`.
  - Still needs a phone: a session expired by the real server.

### Regressions
**R1D-1 · Severity 2 · Sign-in-again doesn't say why; Back erases the reason**
- Where: `App/lib/main.dart:306-311` (the outer `PopScope(canPop:false)`) and `App/lib/screens/login_screen.dart:280-283` (the inner `PopScope`'s `onPopInvokedWithResult` calls `_mode()`, which calls `clearError()`).
- The moment: "I was writing a task and now it wants my password. Did I lose it?" The user presses Back to get their task, and the one line that explained it disappears.
- What happens:
  - The new screen is the ordinary cold-start login. Its heading is the slogan and the email field is empty.
  - The only reason shown is `requestError(session)`: "Vuelve a iniciar sesión para continuar. Tus tareas locales se conservan." It sits in the banner below the submit button, and doesn't say the open screen comes back.
  - Back is blocked by the outer `PopScope`. Because of that, the inner callback runs with `didPop == false` and calls `_mode()`, which clears the auth error. Back looks like it does nothing, but it removes the explanation.
  - Signing in with a different email throws away the kept work, and nothing warns about that.
- Why it fails:
  - Gulf of evaluation, and visibility of system status (Nielsen): the user can't tell that their work is safe or what will happen.
  - Back has a hidden side effect.
  - Recognition over recall: the app knows the email but makes the user type it.
- Fix:
  - On the sign-in-again route, prefill the expired account's email.
  - Show one line at the top (above the form), and keep it on Back and while typing:
    - ES "Tu sesión se ha cerrado. Vuelve a entrar y seguirás donde lo dejaste."
    - EN "You were signed out. Sign in again to pick up where you left off."
    - CA "S’ha tancat la sessió. Torna a entrar i continuaràs on ho havies deixat."
  - In sign-in mode, make Back a no-op that doesn't call `_mode()`/`clearError()`. For example, pass a `signInAgain` flag to LoginScreen, so its own `PopScope` ignores Back unless it is in register or recover mode.
- Verify: widget test. Expire the session, then press Back. The reason line is still visible and the email field holds the account email.
- Evidence: verified in code; there's no render.

### Not regressions, noted
- `main.dart:275-283` (another package's reminder change): a stale reminder now keeps the user where they are and shows `taskRemoved`. It no longer pushes a duplicate MainShell. This looks right.
- The accountUnavailable and network billing messages now read almost the same. That's acceptable, because both lead to the same action.
