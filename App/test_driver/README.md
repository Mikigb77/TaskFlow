Android integration checks

Use a test emulator. Always pass `--keep-app-running` to `flutter drive`: its default cleanup uninstalls the application and removes local data. Do not use split-per-ABI APKs for these runs, because their version-code offsets can also trigger an uninstall during a later normal debug install.

Capture/auth/sync (only AI responses are fixtures):

```powershell
flutter drive --keep-app-running --no-pub --driver=test_driver/appearance_test.dart --target=integration_test/backend_flow_test.dart --dart-define=FIXTURE_AI=true -d emulator-5554
```

Reminder UI, real SQLite and Android plugin scheduling/actions (notifications must already be allowed on the emulator):

```powershell
flutter drive --keep-app-running --no-pub --driver=test_driver/appearance_test.dart --target=integration_test/reminder_flow_test.dart -d emulator-5554
```

The reminder test scopes its synthetic tasks separately and restores the previous notification owner. It exercises callbacks with real scheduled payloads; it does not by itself prove delivery while closed or after reboot. Those require the separate runtime matrix in the implementation status.

After a driver run, install a regular `lib/main.dart` debug build with the same version code using `adb install -r`, so opening TaskFlow starts the normal app. Keep local data; do not uninstall or clear the app to fix a failing test.

Android notification localization and concurrency:

```powershell
flutter drive --keep-app-running --no-pub --driver=test_driver/appearance_test.dart --target=integration_test/reminder_language_test.dart -d emulator-5554
```

This suite includes `database_concurrency_test.dart` and requires notifications and exact-alarm access already allowed for its bounded delivery fixture. Record and restore their prior states. After `REMINDER_LANGUAGE_WAIT_COMPLETE`, inspect the actual Spanish fixture notifications and tap **Completar** on `TaskFlow idioma · completar`, then **Posponer 10 min** on `TaskFlow idioma · posponer`. The test never invokes these action handlers directly. It writes an app-private recovery record before changing preferences; the next run recovers it if the prior process exited. The isolated database test can also run alone without enabling notification permissions. See `docs/REGIONAL_VALIDATION.md` for the test scope and remaining device checks.
