## UX verify — 2026-10-13-app, round 2 (b6 r2), area D — 2026-10-14

**Verdict:** Both findings fixed. One polish regression: in the new account-exists state, two controls on the card have the same label.

**Evidence base:** I read `git diff HEAD` for `login_screen.dart`, `regional_settings_screen.dart` and the three ARB files, plus the ux-tester results (all pass). The only auth renders are `App/artifacts/auth/login-{light,dark}.png` (2026-10-14 11:11). They show the default sign-in state and no new control, so they are no evidence for either state that changed. No preview covers the time-zone picker. Flutter wasn't run.

### UX-488 (P83) — fixed
- The button has its own label. `login_screen.dart` (the `sign-in-with-email` OutlinedButton, under the email field, shown only when `emailUsed`) now uses `strings.signInWithEmail`:
  - EN `Sign in with this email`
  - ES `Iniciar sesión con este correo`
  - CA `Inicia la sessió amb aquest correu`

  The key is in all three ARB files, right after `createAccountWithEmail`.
- The loop is broken:
  - `_accountExists` is set only through `_mode(accountExists: true)` from that button.
  - Every other `_mode()` call (the create, sign-in and recovery links, and the recovery button) resets it to false through the default argument.
  - The email field's `onChanged` also resets it.
  - When `unknownAccount && _accountExists`, the screen shows `recover-with-email` with `forgotPassword`, calling `_mode(recover: true)`. Otherwise it shows UX-402's `create-account-with-email`, unchanged.
- Tests cover every check:
  - the Spanish 2× round trip that keeps the email into `Recupera tu contraseña`;
  - an email edit restoring the create button;
  - a direct sign-in still offering create;
  - a mode switch through the links forgetting the known account;
  - the EN and CA labels, and CA at 2× on 320×640 without overflow.
- Still needs a phone and the server: the device check with a Google-made account (does a recovery email arrive for an account that has no password?).

### UX-489 (P86) — fixed
- `_cityAliases` is now `Map<String, List<String>>`, so multi-word names stay whole (`Nueva Delhi`, `Nova Delhi`, `Ciudad del Cabo`, `Ciutat del Cap`). The `America/Toronto` → Montreal entry is gone.
- How the picker matches:
  - First it matches `'${timeZoneName(z)} $z'`. A hit there gives a row with a title only.
  - Otherwise it takes the first alias that `matchesSearch` accepts on its own and shows it as the `ListTile.subtitle`.
  - An empty query matches every city, so the list stays title-only.
- The brief's fallback ("if none does, the first alias") never applies. A zone only gets listed when one alias matches on its own, so this is equivalent.
- Tests: `pekin` → one row, Shanghai / Pekín; `montreal` → one row, no subtitle; `Londres` → London / Londres; `london` → no subtitle; CA at 2× on 360×740, `Nova Delhi` → Kolkata / Nova Delhi, without overflow.

### Regressions (changed files and the flows they touch only)

**R2D-1 · Severity 1 · Two "¿Has olvidado tu contraseña?" controls on one card**
- **Where:** `login_screen.dart`, sign-in mode after the email-in-use path, with wrong credentials (`unknownAccount && _accountExists`).
- **What happens:**
  - The small TextButton `forgotPassword` still sits above `account-submit` (the `if (!_recover && !_register)` link).
  - The new OutlinedButton `recover-with-email` repeats the same label just below the error message.
  - Both do the same thing, so nobody gets lost. But TalkBack reads the same name twice, and the card shows two recovery controls a few dp apart.
- **Why it fails:** Nielsen, minimalist design; one concept, one control.
- **Fix:** hide the small link while the recovery button shows. Its condition becomes `!_recover && !_register && !(unknownAccount && _accountExists)`. That removes one control and adds no copy.
- **Verify:** extend the UX-488 widget test. In that state, `find.text('¿Has olvidado tu contraseña?')` finds exactly one widget, the one keyed `recover-with-email`.
- **Evidence:** verified in code. The package told the implementer to leave the small link alone, so this is a follow-up to that brief, not a mistake in the implementation.

### Other checks — no regression found
- `emailUsed` evaluates `requestProblem(error!)` only after `field == _Field.email`, and that field requires a non-null error. No null crash.
- The email field's new Column wrapper keeps the `_emailField` key on the `KeyedSubtree`, so `_reveal()` still scrolls to it.
- The time-zone rows grow by one subtitle line only when an alias matched. The CA test at 2× shows no overflow.
- I didn't judge the sign-in password validator change (non-empty for sign-in, 12 characters for create and recovery). It belongs to UX-484 from an earlier package.
