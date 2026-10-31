**Android capture entry points**

The launcher exposes Say a task and Capture text shortcuts. TaskFlow accepts `ACTION_SEND` with `text/plain` through the Android share sheet. Settings can request a pinned microphone widget; launchers without that API can use their widget picker. The widget opens the foreground capture screen and its normal microphone permission flow. It never records from a background service.

The native handoff keeps a bounded private pending queue until the app has inserted the capture into SQLite. Retries use the same capture UUID; they preserve edited text and original capture time, do not revive discarded captures, and cannot reassign one to another account. Shared text longer than 4,000 characters is visibly rejected instead of truncated. Account restoration finishes before ownership is assigned. A new entry stops and flushes any active voice capture before opening; existing manual forms remain in the navigation stack.

Platform references: [static shortcuts](https://developer.android.com/develop/ui/compose/system/shortcuts/creating-shortcuts), [Android app widgets](https://developer.android.com/develop/ui/views/appwidgets), [receiving shared text](https://developer.android.com/develop/ui/compose/sharing/receive).

**Observed on Android 36.1 emulator, 22 September 2026**

- A real `ACTION_SEND` cold launch opened its text in capture and durably retained it.
- A second share delivered to the running activity opened separately and retained both captures.
- `dumpsys shortcut` listed both static shortcuts; Android registered the widget provider.
- The native launcher pin dialog accepted the microphone widget. Tapping the pinned widget opened capture and the real Android microphone permission dialog. Denying permission left typing available; synthetic text typed into that capture was retained.
- After force-stopping the app and confirming the process was gone, a cold normal launch succeeded. The Android integration test found all three exact synthetic captures intact, verified UUID retry/owner isolation on real SQLite, and discarded those fixtures.
- The test widget was dragged to the launcher's Remove target and its absence verified. Microphone permission remained denied; test-added user decision flags were cleared to restore the prior prompt state. No task data was removed.
- The 75-test Flutter suite passed before adding the hold-gesture regression; all five focused speech tests then passed, including real pointer down/hold/release. That test caught and fixed a tooltip consuming the hold gesture. Static analysis is clean. The Android integration passes.

Evidence lives in ignored `App/artifacts/entry-*-ui.xml`, `entry-runtime.sqlite`, `entries-all-tests.log`, `native-speech-tests.log`, `entries-analyze.log`, and `entries-android-integration.log`. Native test content is synthetic. This is not recognition accuracy or physical-device evidence.

`capture_entries_flow_test.dart` verifies retry/ownership and cleans only the three documented manual-test UUIDs, never arbitrary user captures. Run with `flutter drive --keep-app-running --no-pub --driver=test_driver/appearance_test.dart --target=integration_test/capture_entries_flow_test.dart -d emulator-5554`. Restore a normal APK afterward with `adb install -r`; for this x64 emulator, use `flutter build apk --debug --no-pub --target-platform android-x64`. This is a normal version-code-preserving APK, not split-per-ABI.
