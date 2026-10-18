## UX verify — run 2026-10-18-commands, round 1, area D (P132) — 2026-10-18
**Verdict:** Ship — both findings meet their acceptance checks in code and in ux-tester's tests; no regressions in the changed files. Two staging device checks stay open.
**Evidence level:** code read of the diffs (`git diff HEAD`) plus the tester's widget/unit tests; render `App/artifacts/auth/login-light.png` (19:01 today) shows only the default sign-in state, which this change doesn't alter. No preview covers the error states.

### UX-402 · fixed (device check open)
- `App/lib/services/api_client.dart:22-28` — new `WrongCredentials extends ApiException`, keeping status, message, body and retryAfter.
- `App/lib/services/api_client.dart:245-249` — in `signIn`, `!register && status == 401 && body != null` rethrows as `WrongCredentials`. The app's own "account changed" 401s (`:499`, `:509`) carry no body, so they're excluded; any real server 4xx always gets a body map (`:537-539`), so the server's 401 always qualifies.
- `App/lib/l10n/request_locale.dart:89-91` — `requestProblem` reads `WrongCredentials` first → `credentials`, before the text rules and the generic 401 → `session` rule (`:112`). simplejwt matches kept (`:101-104`).
- `App/lib/screens/login_screen.dart:320-325` (unchanged) — `unknownAccount` now turns true for the server's real 401, so «Crear una cuenta con este correo», or after «Iniciar sesión con este correo» the recovery button (UX-488, `:695`/`:709`), shows. `auth_provider.dart:189-197` stores the error untouched, so the marker reaches the screen.
- Other 401s: a bare `ApiException(401, 'Email or password is incorrect.', {...})` still maps to `session` (test `email_verification_test.dart:1163-1190`).
- Tests: `email_verification_test.dart:1075`, `:1103`, `:1132-1191` drive the real `ApiClient.signIn` through a MockClient with the server's actual body.
- Device: staging sign-in with a wrong password (also unblocks UX-484/UX-488 phone checks).

### UX-1208 · fixed (device check open)
- `App/lib/l10n/request_locale.dart:74-85` — `waitMinutesFor` moved here: whole minutes rounded up, at least 1, from `retryAfter` or DRF's "Expected available in N seconds".
- `App/lib/l10n/request_locale.dart:47-48` — only with `onSignIn: true` and reason `rateLimit` with a known wait → `tooManyTriesWait(minutes)`; else `rateLimit` stays. Callers with `onSignIn: true`: `login_screen.dart:317` (sign-in, «Crea tu cuenta», recovery), `verify_email_screen.dart:119` (Confirmar), `delete_account_screen.dart:717` (local Google error, never a 429). Other screens keep today's line (test `:1290-1294`).
- The server's lock detail «Too many failed attempts. Try again in 15 minutes.» (Backend/core/auth_views.py:168) contains none of the earlier text keys ("password", "sign in", "account changed"…), so it reaches `rateLimit` → «Demasiados intentos. Espera 15 minutos y vuelve a intentarlo.».
- `App/lib/screens/delete_account_screen.dart:224`, `:365` — uses the moved helper and the renamed key; wording unchanged for the person.
- Catalogs: `deleteAccountThrottledWait` gone from all three; `tooManyTriesWait` in all three with the brief's exact text; `@tooManyTriesWait` description accurate, `minutes` typed int (`app_en.arb:2203-2210`).
- Device: five wrong passwords then a sixth on staging → «Espera 15 minutos».

### Regressions
None found in the changed files or the flows they touch (sign-in, create account, email confirmation, delete account).

### Observations (not regressions, already-existing behaviour, for the organizer)
- After the 15-minute lock, the sign-in banner offers no next step; «¿Has olvidado tu contraseña?» stays reachable as the link under the password field, so this isn't a dead end. Not caused by this change.
