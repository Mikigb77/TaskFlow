## UX verify — 2026-10-13-app, batch b6, round 1, area D — 2026-10-14

**Verdict:** both findings fixed in code; one small regression on the new email-in-use button (a possible loop between the two "switch mode" offers), one polish point on alias search.
**Evidence level:** code (`git diff HEAD`), ux-tester's widget tests (all pass), tz data file inspected (`timezone-0.9.4/lib/data/latest.tzf`, which `regional_provider.dart:6` loads). Renders `App/artifacts/auth/login-{light,dark}.png` (10:29, newer than `login_screen.dart` 09:36) show only the default sign-in state, unchanged; no preview covers the email-in-use state or the time-zone picker.

### UX-484 · fixed (device check still open: real server errors)
- `App/lib/screens/login_screen.dart:518-528`: in sign-in mode (`!_register && !_recover`) the validator only refuses an empty password, with the new `enterPassword` ("Introduce tu contraseña" / "Enter your password" / "Introdueix la contrasenya", all three ARBs). Create mode and setting a new password keep `value.length < 12 → passwordTooShort`.
- The helper text "12 caracteres" still shows only in create/recover (`:487-489`), so sign-in no longer mentions length anywhere.
- Mirror of UX-402: `:257-260` `emailUsed` (create mode, error on the email field, `requestProblem == 'emailUsed'`); `:426-439` an OutlinedButton `sign-in-with-email` under the email field calls `_mode()`, which keeps the email and, outside recovery, the typed password (`:56-68`). It sits inside the `_emailField` KeyedSubtree, so `_reveal()` scrolls the error and the button into view together.
- Tests: `auth_gate_test.dart:593` (6-char password reaches the server; credentials error offers `Crear una cuenta con este correo`, email kept), `:638` (create mode still refuses <12), `:660` (es/en/ca, email in use → button → sign-in with email kept, at 2× text 360×740).

### UX-486 · fixed
- `App/lib/screens/regional_settings_screen.dart:170-231`: `_cityAliases`, 55 zones with Spanish and Catalan names; matched through `matchesSearch` (accent folding) together with the tz city and id (`:240-246`). Rows still show the tz city, as the brief asked.
- `:157-164`, `:233`: `_listedZone` hides `US/*`, `Canada/*`, `Brazil/*`, `Chile/*`, `Mexico/*`, `Etc/*` and every slash-less id except `UTC`. Checked in the shipped data: `US/Pacific`, `US/Eastern`, `US/Hawaii`, `US/Arizona`, `Canada/Eastern` exist there; `UTC` exists, so it stays listed; Brazil/Chile/Mexico/Etc aren't in `latest.tzf` at all (harmless).
- A stored legacy zone still shows: the Settings row reads `timeZoneName(p.captureTimezone!)` (`:84-86`) and `CaptureTimezone.valid` checks the full database, not the filtered list. Tests `regional_ui_test.dart:446` (US/Pacific, Canada/Eastern).
- `regionalSettingsHelp` is gone from `lib/` (grep: only the test that asserts its absence, `regional_ui_test.dart:467`).

### Regressions

**R1D-1 · Severity 2 · Email-in-use and wrong-password offers can loop**
- Where: `App/lib/screens/login_screen.dart:426-439` (new button) with `:595-608` (UX-402's button), create → sign-in.
- The moment: "It says I already have an account. I pressed Iniciar sesión, then Iniciar sesión again, and now it tells me to create an account — which I just tried."
- What happens: someone who forgot their old account (or made it with Google, so it has no password) types a new password in create mode → "Ya existe una cuenta…" → taps the new `Iniciar sesión` → the screen switches, keeping the new password → taps `Iniciar sesión` again → wrong credentials → `Crear una cuenta con este correo` → back to create → email in use again. The emailUsed text says "Inicia sesión o recupera tu contraseña", but only sign-in got a button; the one exit (`¿Has olvidado tu contraseña?`) is a small text link. The new button's label is also the same as the submit button's, so tapping it looks like it should sign in, yet it only switches mode (a second tap is needed).
- Why it fails: no dead ends / error recovery (Nielsen heuristics 9 and 3); the newcomer gives up after one or two dead ends.
- Fix: (1) label the new button like UX-402's mirror: `Sign in with this email` / `Iniciar sesión con este correo` / `Inicia la sessió amb aquest correu`. (2) when sign-in follows the email-in-use switch (the app now knows the account exists), a credentials error offers `¿Has olvidado tu contraseña?` as the button (switch to recovery with the email kept) instead of `Crear una cuenta con este correo`. No new screen; one flag and one reused string (`forgotPassword` or the existing recovery-link string).
- Verify: widget test — create mode, email in use → tap the button → submit → credentials error → the button offered is the recovery one, not create; recovery opens with the email kept.
- Evidence: verified in code; inferred flow.

**R1D-2 · Severity 1 · Alias search lists a different city's name**
- Where: `App/lib/screens/regional_settings_screen.dart:170-231` and the row at `:270-273`.
- The moment: "I typed Pekín and it shows Shanghai. I typed Quito and it says Guayaquil. Is that right?"
- What happens: aliases that are other cities (Pekín/Beijing → Shanghai, Quito → Guayaquil, Nueva Delhi/Bombay → Kolkata, Montreal → Toronto, Tel Aviv → Jerusalem, San José → Costa_Rica, Ciudad del Cabo → Johannesburg, Canarias/Tenerife → Canary) return a row whose only text is another place's name. "Montreal" now lists two rows, `Montreal` (the tz link, already listed) and `Toronto`.
- Why it fails: match with the real world, recognition over recall (Nielsen); the user can't tell the row is the right zone.
- Fix: when the query matched only through `_cityAliases`, show the alias as the row's subtitle (e.g. title `Shanghai`, subtitle `Pekín`) — the plain rows stay unchanged. Drop `Montreal Montréal` from the Toronto alias, since accent folding already finds `America/Montreal`.
- Verify: widget test — search `pekin` lists one row whose text includes `Pekín`; search `montreal` lists one row.
- Evidence: verified in code.

### Not regressions (checked)
- Empty sign-in password is refused before the server, in all three languages (`enterPassword` exists in the three ARBs).
- The other ARB additions in the diff (`voiceSettings`, `sameAsApp`, `groupDeleted`, `invitedByTo`, `invitationFrom`) belong to other packages, not P77/P79.
