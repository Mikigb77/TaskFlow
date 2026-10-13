# Known failures

These checks already failed before the UX loop started, so the gate doesn't hold them against a round. Remove an entry once it's fixed. Add one only when you're sure the loop didn't cause it.

- **Sign-in preview command:** `flutter test --no-pub --dart-define=WRITE_AUTH_PREVIEWS=true test/auth_gate_test.dart`
  - Two tests fail on `MissingPluginException` for the `app_links` channel, after the preview has been written. The PNGs in `App/artifacts/auth/` are still valid.
  - Without the preview flag, the test file passes.
  - Recorded 2026-10-13.

Baseline on 2026-10-13: `flutter test --no-pub` passes all 325 tests.
