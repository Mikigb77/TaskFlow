## UX verify — run 2026-10-19-app, round 2 (b1), area D — 2026-10-20

Scope: P199 (UX-1629). Changed: `App/lib/screens/login_screen.dart` (recovery code field), `App/test/ux_previews/auth_previews.dart` (recovery-sent now es1, es2, ca2). Renders are from 2026-10-20 07:28; no file under App/lib or App/assets is newer.

### UX-1629 · fixed
- Code: `App/lib/screens/login_screen.dart:623-637` — the code field's InputDecoration now has `floatingLabelBehavior: FloatingLabelBehavior.always`, like email (:565-570) and password (:671-675). The label is a `FittedBox(fit: BoxFit.scaleDown)` around `Text(strings.recoveryCode)`, so at large text it shrinks rather than ellipsizes. No copy change; keyboard, autofill, validator untouched.
- Render `auth/sign-in.recovery-sent.es.light.1x.png`: «Código de recuperación» and «Nueva contraseña» both sit on their borders above empty fields, same size, same inset. The mismatch R1D-1 described is gone.
- Renders `sign-in.recovery-sent.es.light.2x.png` and `.ca.light.2x.png`: «Código de recuperación» / «Codi de recuperació» sit whole on the border; «Nueva contraseña» / «Contrasenya nova» whole on theirs (field runs off the bottom of the 800 dp viewport, which is what AUDIT's «Target under 48 dp» for that field measures, not a real size).
- AUDIT (auth/sign-in · recovery-sent): no cut text in any of the three renders. TalkBack reads «Código de recuperación» as the field's name (item 6), so the widget `label:` didn't lose the accessible name.
- Tests (ux-tester): ES 1×, ES 2×, CA 2× label placement, and the 45-character `uid:token` value still accepted — all pass.

### Regressions
None found in the changed lines or the recovery flow they touch.

### Noted, not a regression
- At linear 2× the FittedBox draws the code label about a fifth smaller than «Nueva contraseña» right below it (ES 2× render). It is whole and legible, and is the deliberate trade against an ellipsis («Código de recupera…»). On Android 14+ the non-linear 2.0 scale grows 16 sp text less than linear 2×, so on a phone the shrink is smaller or none. Device check in the package covers it: on the largest font, every label sits whole on its border.
