# External app handoffs

Android emulator evidence, 22 September 2026. These checks use the product's `NoteText`, `AttachmentPanel` and calendar event sheet, with real platform channels. A synthetic attachment entry and in-memory calendar preferences isolate the test from ordinary TaskFlow tasks/accounts.

## Confirmed

- Tapping a note's explicit HTTP link opens Chrome. The receiving browser displayed the local Docker backend's health response at `http://10.0.2.2:8088/api/health/`. This is an actual browser handoff and rendered page, not merely a successful `launchUrl` result.
- Tapping Open on a local PDF attachment opens the installed viewer in `com.google.android.apps.docs`. The viewer rendered the expected “TaskFlow handoff fixture” text. No upload, Add to Drive or sharing action was performed. This verifies this file type/viewer combination; other types and physical devices need their own checks.
- Returning from both apps preserves the TaskFlow screen. The PDF still existed after viewing and was removed by fixture teardown, along with the temporary acknowledgement file.
- `integration_test/external_handoff_test.dart` passes with `HANDOFF_SKIP_CALENDAR=true`. The host observed each receiving activity, captured its screen, acknowledged that exact phase through a private fixture file and returned to TaskFlow. Screenshots were inspected. Analysis is clean; the ordinary Android x64 debug APK builds and has been restored with `adb install -r`.

## Calendar limitation

The controlled Calendar Provider event was readable and displayed correctly inside TaskFlow. Tapping Open started Google Calendar's event information activity, which returned without displaying the fixture. The host could not confirm the expected event screen. Runtime calendar permission was already granted to Google Calendar. Logs also contained Google-services errors, but they do not establish the cause of the missing event display.

**Calendar handoff is not counted as a pass.** It needs investigation with a configured, supported calendar account/app on a target phone. The source event remained unchanged. No fallback task or calendar write was introduced.

The first harness accepted an activity lifecycle return as success; that proved too weak because an external app can return immediately. The final harness additionally requires the host's phase acknowledgement. The passing browser/file run explicitly excludes calendar. An earlier attachment fixture error came from calling a guarded test assertion during widget construction; the fixture now validates that argument without invoking a nested test API. Neither harness correction changes product behavior.

## Repeating and cleanup

Seed a synthetic local calendar named/account `taskflow-handoff-fixture-20260922`, type `LOCAL`, visible and sync-enabled. Create one current-day event with title `TaskFlow-handoff-fixture` and UID `taskflow-handoff-fixture-20260922`. Read its actual calendar/event IDs; the recorded run used calendar **1**, event **6**, both subsequently removed. Do not reuse arbitrary IDs or change a real calendar.

Temporarily grant TaskFlow `READ_CALENDAR`, preserving its prior state. Run the integration driver with `--keep-app-running`, the normal `test_driver/appearance_test.dart`, and `HANDOFF_CALENDAR_ID` / `HANDOFF_EVENT_ID` Dart defines. Use `HANDOFF_SKIP_CALENDAR=true` only when intentionally verifying browser/file coverage; omitting it includes the unresolved calendar check.

The fixture prints `HANDOFF_ACK_FILE: taskflow-handoff-ack-<number>.txt` and one `HANDOFF_READY` phase at a time. Observe the receiving app and verify its content. Write exactly `browser`, `file` or `calendar` into that printed file in the debug app's `files` directory using `adb run-as`, then return to `com.example.agenda/.MainActivity`. Do not acknowledge an app that immediately exits or fails to display the intended content. A lifecycle return without that acknowledgement cannot pass the final test.

The fixture PDF/acknowledgement files were removed by test teardown. The exact synthetic calendar and event were deleted and their absence queried. TaskFlow calendar permission returned to its original denied state. All five browser tabs created by the repeated fixture runs were verified as the same local health URL and closed; ordinary task/account data was preserved.

Logs/screenshots are ignored artifacts: `handoff-browser-file-final.log`, `handoff-final-analyze.log`, `handoff-main-build.log`, `handoff-browser.png`, `handoff-file.png`. The earlier `handoff-android-final.log` contains a weak lifecycle-only calendar success marker; it must not be treated as external-calendar display evidence.
