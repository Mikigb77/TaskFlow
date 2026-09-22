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
