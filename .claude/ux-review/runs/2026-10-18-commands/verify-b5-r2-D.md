## UX verify — 2026-10-18-commands, b5 round 2, area D — 2026-10-19

Scope: P165 (UX-1232). Files: App/lib/screens/delete_account_screen.dart, App/test/ux_previews/delete_previews.dart, App/test/delete_account_test.dart.

### UX-1232 · fixed
- `_googleConfirmation(BuildContext, String? help)` (delete_account_screen.dart:717-732) renders `Text(help)` and its 12 dp gap only when `help != null`; doc comment updated as briefed.
- Password-with-Google call (:409-418) passes `_googleToken == null ? deleteAccountGoogleInstead(_email) : null`; the password section is also hidden once the token exists (:410). Google-only call (:402-405) still passes `deleteAccountGoogleHelp(_email)` in every state (unchanged, per brief).
- Refused confirmation (`google_reauth_failed` / `reauth_required`) still clears `_googleToken` (:224-228), so the password section and «O confirma con Google…» return together, with `deleteAccountOtherGoogle` under the button.
- Render `App/build/ux/delete/delete-account.google-instead-confirmed.es.light.2x.png` (12:55:15, no app file newer): «Confirmado con Google» stands alone above the enabled red «Eliminar mi cuenta»; no «O confirma…» line. AUDIT.md: no problems measured; TalkBack order sensible. Before-state render `password-or-google.es.light.2x` unchanged (help, field, «O confirma…», Google button, disabled red button).
- Tests: four new UX-1232 tests (delete_account_test.dart:1030-1160) cover acceptance 1–4; acceptance 5 by the existing UX-815 2× ES/CA test. Tester reports all pass.
- Device check (staging phone, throwaway password account with Google linked) not run.

### Regressions
None found in the changed files or the delete flow. The confirmed state reads: consequences → copy link → «Confirmado con Google» → red button; nothing asks for an action already done. The Google-only account keeping its help line after confirming is the brief's explicit choice, not a regression.
