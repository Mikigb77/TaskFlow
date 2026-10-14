## UX verify — 2026-10-13-app, b6 round 3, area D — 2026-10-14
**Verdict:** Ship. P88 removes the duplicate "¿Has olvidado tu contraseña?" and adds nothing.
**Scope:** P88 (UX-495). Changed file: `App/lib/screens/login_screen.dart`. I checked the code, ux-tester's widget tests and the current renders (`App/artifacts/auth/login-light.png`, re-rendered 2026-10-14 11:33, after the code changed at 11:22). The previews cover only plain sign-in, so the wrong-credentials state rests on code and widget tests. It has no render.

### UX-495 — fixed
- `login_screen.dart:549-567`: the small TextButton link now shows only under `!_recover && !_register && !(unknownAccount && _accountExists)`. When it's hidden, the existing `else const SizedBox(height: 20)` takes its place. This matches the brief exactly.
- `login_screen.dart:617-630`: when sign-in was reached through "Iniciar sesión con este correo" and the credentials are wrong, the `recover-with-email` OutlinedButton is the only recovery control. The direct wrong-credentials path (`:631-645`) still shows "Crear una cuenta con este correo", and the small link stays there.
- Tests (pass, as ux-tester reports): `auth_gate_test.dart:936-971` covers Spanish at 2× text on 360×740. The label appears once with `skipOffstage: false`, it sits inside `recover-with-email`, and there is exactly one semantics node with that label, so TalkBack reads it once. `:973-1003`: on a direct wrong-credentials sign-in, the link appears once as a TextButton, the create button is there, and the link opens recovery. `:1005-1018`: plain sign-in still shows the link.
- Render `login-light.png`: plain sign-in still shows "Forgot password?" above "Sign in". The layout there is unchanged.
- All three acceptance checks are met. Count in the wrong-credentials state after email-in-use: 2 recovery controls before, 1 after.

### Regressions
None.
- Something I looked at and didn't count: when the wrong-credentials banner appears in the email-in-use path, the 48 dp link (taller at 2×) gives way to a 20 dp spacer, so the submit button moves up a little. That happens in the same frame as the banner appears, and `Scrollable.ensureVisible` on `_outcome` (`:125-137`) scrolls the banner into view, so the user isn't reaching for anything that moves. Not a regression.
- If the user edits the email, `_accountExists` resets (`onChanged`, diff around `:418`). The screen then shows the direct-sign-in layout: the small link plus "Crear una cuenta con este correo". That is consistent, and still only one recovery control.
