Android integration checks

Private staging release checkout (native paywall, cancel/failure/success,
restore, CustomerInfo callbacks, cloud entitlement and live AI):

```powershell
./scripts/build-staging.ps1
./scripts/test-staging-billing.ps1 -Device emulator-5556
```

This uses Android instrumentation to run Flutter integration tests in an actual
non-debuggable release build. The instrumentation interacts only with the SDK's
Test Store UI. It requires the existing private `build/staging-e2e.json` fixture
and refuses real store keys. The normal distributable APK is preserved under
`build/releases/` and reinstalled without clearing data in a `finally` block.
Test credentials stay in the separate, ignored integration APK.

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


Projects and paid capture (real local Docker and RevenueCat Test Store):

```powershell
./scripts/test-projects.ps1 -Device emulator-5556
```

First create and allowlist the isolated fixture as documented in
`docs/PROJECTS_IMPLEMENTATION.md`. `-SkipAI` omits live extraction explicitly;
it does not constitute a full voice-pipeline pass. The wrapper always uses
`--keep-app-running`. The older account, notes, recognizer-event and process-
recovery drivers use an explicit entitlement fixture to isolate their original
purpose; use `projects_flow_test.dart` for real SDK/server paid-access coverage.

During a known provider outage, `./scripts/test-projects.ps1
-ExpectProviderUnavailable` runs a separate live negative check. It requires a
real Test Store entitlement and verifies that the capture and chosen project
survive, reopening permits retry, and no task reaches the shared project. It
does not count as successful extraction. Do not combine it with `-SkipAI`.

Cloud staging uses `config/staging.json` plus the private `build/staging-e2e.json`
fixture from `Backend/scripts/validate_staging.py`. Use the same driver/target
with both `--dart-define-from-file` arguments. The native RevenueCat account must
have a fresh Test Store purchase (currently about five minutes). The approved
**Anybody** sandbox policy enables invited testers without a RevenueCat allowlist.
Never put these fixture credentials in `config/staging.json` or the
distributable APK.

For the synthetic voice fixture, the staging driver also supports
`--dart-define=PROJECT_E2E_AUDIO_PATH=/data/user/0/com.example.agenda.staging/cache/staging-synthetic.wav`.
Install the staging debug package first, then transfer the known synthetic WAV
into that app's cache using `adb push` to `/data/local/tmp` and `adb shell run-as
com.example.agenda.staging cp`. This removes the host HTTP fixture server from
the test; Android file storage, cloud upload, transcription, task extraction,
review and saving still use their real implementations. The path is only read
by the integration-test entrypoint, never by `lib/main.dart`.

If both development and staging apps are running, Flutter's automatic VM
discovery can connect to the wrong process. Read the staging process's Dart VM
URL from its filtered `adb logcat` diagnostics, forward that observed device
port to a free host port, and run the driver with `--use-existing-app=<forwarded
VM URL> --keep-app-running`. Preserve the URL's authentication token. Only use
the staging process's observed URL; remove your temporary forwarding afterward.
When finished, restore `build/releases/taskflow-staging.apk` with `adb install
-r`, then launch with `flutter run --release --no-resident --no-pub
--use-application-binary=build/releases/taskflow-staging.apk -d emulator-5556`.
`--no-resident` leaves the release app running without a terminal session;
detaching with `d` stops release apps in this Flutter version. Keep all existing
application data.
