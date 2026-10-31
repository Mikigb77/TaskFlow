Reminder verification — 22 September 2026

Implemented behavior

- Priority expresses importance. Alerts follow an explicit task choice or an editable, account-scoped device default. Notifications start off and request permission when enabled in Settings.
- Date-only tasks need a chosen alert time. Inbox tasks have no alarm. Morning/evening check-ins repeat generic wording that remains valid when tasks change.
- SQLite stores alert identity, schedule, status and snooze. OS schedules are reconciled with stable IDs. Payload tokens prevent an old delivered alert acting on a newly changed schedule.
- Complete affects one notified occurrence; local account edits enter the ordinary sync queue. Account switches cancel old alerts and reject actions from a different account.
- A rolling year is projected, with the earliest 400 Android / 60 iOS alerts queued, including check-ins. Later work is visible as deferred. Android requests hourly WorkManager replenishment; launch/resume/edits also refresh. System restrictions can defer workers and alarms.

Evidence

The Flutter suite has 58 passing tests, including real SQLite failures, permission/scheduling transitions, stable IDs, lost OS schedules, bounded-window replenishment, account isolation, stale payloads, snooze persistence and occurrence completion. Notification settings were checked at 320×568 with 2× text in both themes. Static analysis is clean. The rebuilt backend passes 35 tests; migration 0003 is applied.

On the Medium_Phone_API_36.1 emulator, reminder_flow_test.dart passes with the real Android notification plugin and SQLite, including a WorkManager job. Permission is pre-granted for this test; denial transitions are covered by the engine tests. The integration driver manually passes real scheduled payloads to the response handler to verify navigation and actions.

Separately, reminder_delivery_fixture.dart was installed normally and launched without a connected Flutter driver. After the app went to the background, `am kill` removed its process. Android posted the first notification. Tapping its native Complete action set only its fixture task to completed in SQLite. An actual emulator reboot occurred before the second alert; that alert was due during boot and posted after Android delivered BOOT_COMPLETED. Tapping the native Snooze action persisted a new ten-minute alert. Logs are retained in ignored App/artifacts/reminder-closed-receipt.log and reminder-reboot-receipt.log. This establishes receipt and recovery on that emulator, not a physical-device timing guarantee.

Repeat the native receipt check

1. Use a test emulator with notifications and precise-alarm access allowed. Build `flutter build apk --debug --target-platform=android-x64 --target=integration_test/reminder_delivery_fixture.dart --no-pub` and install with `adb install -r build/app/outputs/flutter-apk/app-debug.apk`.
2. Launch the fixture. Wait until `adb shell run-as com.example.agenda cat files/reminder-delivery-fixture.json` returns its alert IDs/times. Use the emulator's clock, which can differ from the host's clock under load.
3. Send Home and use `adb shell am kill com.example.agenda`. Do not use force-stop for this receipt scenario: Android intentionally suppresses a force-stopped app. Observe the first notification, then reboot and unlock before checking the second. Inspect actual receipt, not just AlarmManager's pending list.
4. Cleanup: rebuild the same fixture with `--dart-define=CLEANUP_REMINDERS=true`, reinstall with `-r` and launch it. It removes only its own scoped test tasks and restores previous notification ownership. Restore any test-only OS permission overrides.
5. Build the regular `lib/main.dart` entry point, reinstall with `-r`, and launch it. See test_driver/README.md for preserving installed app data during integration-driver tests.

Remaining evidence

Physical Android devices (including vendor battery policies), DST/timezone transitions on real hardware, screen-reader use and iOS delivery remain unverified. iOS configuration includes notification action registration and background fetch, with deployment target 14; no Apple build is claimed from this Windows environment. The product UI distinguishes an accepted schedule from actual delivery.

Implementation references: [WorkManager setup and platform limits](https://docs.page/fluttercommunity/flutter_workmanager/quickstart), [Android alarm guidance](https://developer.android.com/develop/background-work/services/alarms).
