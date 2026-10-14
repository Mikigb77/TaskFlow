## UX verify — run 2026-10-13-app, round 2, area C (P85) — 2026-10-14

**Verdict:** Ship. UX-490 is fixed; no regressions in the changed files.

### UX-490 · fixed
- `App/lib/l10n/app_ca.arb:511` now reads `"groupDeleted": "Grup suprimit"`, matching the button just tapped (`delete` = `Suprimeix`, :157) and the sibling `projectDeleted` = `Projecte suprimit` (:510). Generated `app_localizations_ca.dart` carries the same string (regenerated, not hand-edited).
- EN `Group deleted` (app_en.arb:847) and ES `Grupo eliminado` (app_es.arb:532) unchanged, as the brief asked.
- Used once: `App/lib/screens/groups_screen.dart:674`, captured before the confirm dialog and passed as `done:` to the DELETE run, so the snackbar shows on the screen underneath.
- Test proof: `App/test/groups_screen_test.dart` — "UX-490: deleting a group in Catalan with Suprimeix…" walks Delete → dialog Suprimeix → asserts DELETE call, GroupScreen gone, underlying screen visible, SnackBar with `Grup suprimit`, no `eliminat` on screen. ux-tester reports pass. The per-language UX-485 check also asserts CA `Grup suprimit`.
- Evidence: verified in code + widget test. No preview covers the groups screen; nothing rendered to read.

### Regressions — none
- ARB files parse with no duplicate keys (ca/en/es).
- The only other `eliminat` in the CA catalog is `captureRemovedDraftsHelp` ("Els esborranys eliminats…", :733) — drafts removed from a capture, a different concept from deleting; pre-existing and outside this change.
- The test helper `_open` gained `language`/`projectCount` defaults that keep the earlier tests on Spanish with one project; the launcher button now uses a key instead of the text `Abrir`. Test-only, no user-facing effect.
- Other hunks in `git diff HEAD` for app_ca.arb belong to earlier packages in this run (voice settings, sign-in, invitations) and are not part of P85's change.
