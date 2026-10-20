## UX verify — run 2026-10-19-app, round 1, area D (P170) — 2026-10-20

Evidence: code diff (`git diff HEAD`), renders in `App/build/ux/auth/` and `App/build/ux/delete/` (06:16, newer than every file under App/lib and App/assets), and `App/build/ux/AUDIT.md` (06:17). Widget-test level; no device.

### Results

**UX-1602 · fixed (app half)**
- `App/lib/screens/login_screen.dart:268-282`: `auth/password-reset/` now sends `language` from `Localizations.localeOf(context).languageCode`, the same source `_signIn` uses (:201).
- :291-294 sets `_sentTo`; :605-614 shows `recoveryEmailRequested(sentTo)` as a MessageBanner above «Código de recuperación»; `_reveal` scrolls to it (:169-173). The old line under «Guardar contraseña nueva» is gone (`_message` no longer set there).
- Code field unchanged (:615-632): no formatter, no length cap, no one-time-code autofill.
- Copy matches the brief in EN/ES/CA, typed `email` placeholder with description.
- Render `auth/sign-in.recovery-sent.es.light.1x.png`: the line names maria.lopez@example.com, sits above the code field. AUDIT TalkBack order: heading → help → sent line → code field.
- Still for the main session: 6-digit code, number pad, Spanish email (staging).

**UX-1604 · fixed**
- Pitch in `Semantics(container: true)` (:454-468); «o» row in `ExcludeSemantics` (:499-519); `MessageBanner` is now `Semantics(container: true, liveRegion: liveRegion ?? isError)` (`App/lib/widgets/app_components.dart:163-178`); the two callers that wrapped it in their own `Semantics(liveRegion)` now pass `liveRegion: true` (:432-436, :772-777).
- AUDIT sign-in es.light.1x: heading «Inicia sesión» (3) → pitch (4) → «Continuar con Google» (5); «o» not read. Wrong-password: the live-region node is exactly «No encontramos esa cuenta o la contraseña no es correcta.».
- Delete page: `App/lib/screens/delete_account_screen.dart:656-665` gives «La copia no incluye los archivos.» its own container; AUDIT delete-account · preview reads 17 «Guardar antes una copia de tus tareas» → 18 the note.
- Device-only: real TalkBack speech.

**UX-1617 · fixed**
- (a) `email` → ES «Correo» / CA «Correu»; `floatingLabelBehavior: always` on email (:568-572) and password (:663-664). Renders sign-in es/ca 2× show «Correo», «Correu», «Contraseña», «Contrasenya» whole above the fields; AUDIT lists no cut text for them.
- (b) `emailUsed` → «Este correo ya tiene una cuenta.» / “This email already has an account.” / «Aquest correu ja té un compte.»; render email-in-use es 2× shows it whole on two lines.
- (c) 8 dp vertical padding around «¿Has olvidado tu contraseña?» (:708-724); AUDIT 1×: 8 dp from «Contraseña», 8 dp to «Iniciar sesión».
- (d) Bottom «Crear una cuenta» hidden while «Crear una cuenta con este correo» shows (:833); render wrong-password es 1× and ca 2× show one create button.

**UX-1507 · fixed**
- `login_screen.dart:362-364` watches `invitationLinkProvider`, not on sign-in-again; :470-477 shows `invitationWaitingSignIn` above Google (not in recovery). Account deletion forgets the link (`App/lib/services/account_deletion.dart:131-138`), so it never stacks with «Cuenta eliminada».
- Renders invitation es 1×, ca 2×, en 2×: line above Google, Google still the first control. AUDIT order: pitch → invitation line → Google.
- Device-only: tapping a real invitation link while signed out.

### Regressions

**R1D-1 · Severity 1 · Recovery form mixes label positions**
- Where: `App/lib/screens/login_screen.dart:615-626` (code field) vs :663-664 (new password), recovery-sent state.
- What: render `auth/sign-in.recovery-sent.es.light.1x.png` — «Código de recuperación» sits inside its empty field while «Nueva contraseña» sits on the border above its empty field, one under the other. Two identical controls now look different (lens F, consistency). At 2× the code label (22 characters, inside the field at body size) is the longest label on the card and the one UX-1617 left exposed to the cut it fixed for «Correo electrónico» (inferred from the Manrope width model; no recovery-sent 2× render).
- Fix: add `floatingLabelBehavior: FloatingLabelBehavior.always` to the recovery code field's `InputDecoration`, as on email and password. No copy change.
- Verify: re-render recovery-sent at es 1× and add es 2×; all three labels sit on the border; AUDIT lists no cut text for «Código de recuperación».

No other regression found in the changed parts: MessageBanner's new container doesn't sit inside any MergeSemantics (all 38 call sites checked by search); `_reveal` falls back to `_outcome` whenever an error or message exists; the invitation line hides in recovery and sign-in-again.

### Not regressions, noted
- AUDIT «under 48 dp» for «¿Has olvidado…» at 2× and «Crear una cuenta» in the invitation render are viewport-clipped measurements at the render's bottom edge, not real target sizes.
