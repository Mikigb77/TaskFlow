## UX verify — run 2026-10-18-commands, batch b5, round 1, area D — 2026-10-19

Packages: P157 (UX-815), P158 (UX-1222, UX-1221). Evidence: code (`git diff HEAD`), renders re-made by ux-tester at 12:06–12:07 today, AUDIT.md, and the tester's widget tests (not re-run). No device.

### Results

**UX-815 · fixed**
- `App/lib/screens/delete_account_screen.dart:59-61` reads `googleLinked`; `:401-416` shows, for a password account with Google linked, the password section, 16 dp, then `_googleConfirmation(context, deleteAccountGoogleInstead(email))`; the password section goes once `_googleToken` is set.
- `_ready` `:123-128` is true with a Google token or a typed password; the request `:198-206` sends `google_id_token` when there is one, else the password.
- A wrong password names the button below (`:688-692`, `deleteAccountWrongPasswordGoogle`); accounts without Google keep UX-801's line. `google_reauth_failed`/`reauth_required` clear the token (`:224-229`), so the password field returns.
- Google-only accounts: `preview.google` branch unchanged except the help text is now passed in (same `deleteAccountGoogleHelp`).
- Copy in all three ARBs matches the brief exactly; the CA quoted button name matches `deleteAccountConfirmGoogle` («Confirma amb Google»).
- Renders: `build/ux/delete/delete-account.password-or-google.es.light.2x.png` and `.ca.light.2x.png` show help, field, «O confirma…», Confirmar con Google, then the disabled red button; `delete-account.google-instead-confirmed.es.light.2x.png` shows «Confirmado con Google» and the enabled red button. Only cut text: the example email breaking mid-word at 2×, which is a long unbroken address, not a layout fault.
- Leaves R1D-1 (below).

**UX-1222 · fixed**
- `App/lib/services/site_links.dart` (new): one base `https://taskflow.garbar.tech`, `/privacy/`, `/terms/`, `/es/…`, `/ca/…`, English for any other language; `openWebPageProvider` moved here; `openWebPage` shows `webPageOpenError` when nothing opens. The delete page's Google Play link uses it (`delete_account_screen.dart:342`).
- Sign-in: `login_screen.dart:810-843` — a centred, wrapping row of two quiet TextButtons (onSurfaceVariant, bodySmall) under the card, hidden in recovery and sign-in-again. Render `sign-in.sign-in.es.light.1x.png`: both links on one line under the card, Google still first. AUDIT: 141×48 and 154×48 dp, 8 dp apart; the 21 dp and 3 dp readings are in scrolled renders where the link is partly off screen (the same renders give «Idioma» 48×18). Contrast flags are AA-edge histogram artefacts; the text colour itself measures 4.92:1.
- Otros ajustes: `other_settings_screen.dart:101-112` — two rows after Licencias with privacy_tip / gavel icons in primary and open_in_new trailing. Render `settings/other.release.es.light.1x.png` shows them in order before the version line. Main Ajustes untouched.
- Names match the site's titles in EN/ES/CA.

**UX-1221 · fixed**
- `billingError`'s `unsupportedPlatform` now says the Android app only in EN/ES/CA; a search of the three ARBs finds no value naming iOS, iPhone or Apple. The message shows only where billing is unsupported (RevenueCat platform check, unchanged).

### Regressions

**R1D-1 · Severity 2 · After confirming with Google, «O confirma con Google…» still shows**
- Where: `App/lib/screens/delete_account_screen.dart:408-413` with `_googleConfirmation` `:729`; delete page, password account with Google linked, after Confirmar con Google succeeds. Render `delete-account.google-instead-confirmed.es.light.2x.png`.
- The moment: "It says «O confirma con Google y elige…» — or what? I already did. Do I still have to do something?"
- What happens: the password section disappears, but the help line that begins with «O» (an alternative to the password) stays above «Confirmado con Google». It now offers an alternative to nothing and asks for an action already done.
- Why it fails: visibility of system status / match between text and state (Nielsen 1994); the gulf of evaluation (Norman 2013) on the one irreversible action in the app.
- Fix (subtract): in the Google-instead path, hide the help line once `_googleToken != null` (e.g. pass `help` only while no token; the confirmed row stays alone). No new copy. Google-only accounts untouched.
- Verify: in the google-instead-confirmed state (ES), «O confirma con Google y elige ana@example.com…» is absent and «Confirmado con Google» and the enabled «Eliminar mi cuenta» show; re-render the preview.
- Evidence: seen in a current render and verified in code.

### Not regressions, noted
- Once confirmed with Google, there's no way back to the password without leaving the page. Rare and harmless (the Google confirmation is enough); not a change-caused problem worth fixing.
- Device checks (a real Google confirmation deleting a password+Google account on staging; the browser opening the site's localized pages once published) stay with the owner.
