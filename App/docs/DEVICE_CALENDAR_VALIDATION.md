# B20 — read-only phone calendars

Implemented for Android, 22 September 2026. Settings → Phone calendars explicitly requests access and lets each TaskFlow account choose which calendars to display. The default is off with no permission prompt. Other platforms show an unavailable message; iOS support is not claimed.

## Behavior and boundaries

- Reads calendars already exposed by Android's Calendar Provider. A Google/Exchange account must already be connected and synchronized through the phone's calendar setup; TaskFlow does not perform provider OAuth or cloud calendar synchronization.
- The Android manifest requests `READ_CALENDAR` only. The bridge contains no event insert, update or delete operation. Source events open through the installed calendar application's view intent; third-party calendar-app handoff was not exercised in this run.
- External events have a separate, labeled Calendar events section with source names and a view-only label. They never become task rows, completion controls, TaskFlow reminders or AI input. Up to three events appear in the agenda, with a sheet for the rest.
- Timed instances use real instants and the device's local date/time formatting. All-day dates use UTC calendar boundaries and an exclusive end date. Calendar Provider expands recurrence. Shared UID/time instances merge while retaining their source calendars; distinct UIDs are not merged merely because titles match.
- SQLite stores only enabled/selected calendar preferences scoped to the TaskFlow owner. Selection fingerprints include calendar row ID, account/type and source ID, protecting against provider row-ID reuse. No event titles, locations or times are persisted or sent to the backend.
- Calendar reads run off Android's main thread with bounded ranges/results. Limits (200 available calendars, 50 selected, 1,000 queried instances) are disclosed if reached. Content changes trigger refresh; app resume and pull-to-refresh also recheck access. Backgrounding hides snapshots, and generation checks reject late responses after account/permission changes.
- Permission checks include runtime permission and AppOps. Removing access hides both the agenda and any already-open event sheet. Re-enabling access restores selected sources. Preference-write failures do not pretend a selection was saved.

## Evidence

- All **135 Flutter tests** passed; static analysis reports no issues. Eight focused data/controller tests cover all-day boundaries, actual-instant DST overlap, deduplication, explicit permission requests, persistence/write failure, late-query suppression, permission loss and SQLite account isolation. Two widget checks cover 320 × 568, 2× text, English/Spanish, both themes and live removal of an open event's contents.
- The Android integration APK built and `integration_test/device_calendar_flow_test.dart` passed on the API 36.1 emulator using real permission dialogs, Calendar Provider, platform channel and SQLite. Only account/theme test context was isolated; calendar results and permission responses were not mocked.
- Two synthetic local calendars contained five instances on 22 September: one all-day event, one crossing midnight, a weekly event, and the same UID/time appointment in both calendars. The provider returned both appointment records; the app displayed four events with the appointment's two sources. The weekly instance appeared on 29 September, and the all-day event did not leak into 23 September.
- The first OS permission prompt was denied and the second allowed. TaskFlow did not enable calendars after denial. Selection persisted through a fresh SQLite preference-store read and stayed isolated from another owner. The fixture task's stored row remained byte-for-byte unchanged throughout.
- While an event detail sheet was open, host automation set the UID's `READ_CALENDAR` AppOp to `ignore`. The native bridge refused reads, the sheet removed its event content and Open button, and UI hierarchy inspection confirmed the unavailable message. Restoring the UID AppOp to `allow` restored the event and four-item query.
- Light/dark screenshots were inspected. The two synthetic calendars and their events were removed; fixture task/preference rows were removed by test teardown. Calendar permission and first-request state were returned to their original unrequested/denied state. Existing app/account data was preserved.

The regular `lib/main.dart` x64 debug APK is restored with `adb install -r` after the driver run. Logs/screenshots are under ignored `App/artifacts/device-calendar-*` and `App/artifacts/design/device-calendars-*`.

## Repeating the native check

Use a disposable test calendar account on an emulator; do not change a user's real calendars. The fixture account is `taskflow-calendar-fixture`, type `LOCAL`, with calendar names `taskflow-calendar-fixture-20260922` and `taskflow-calendar-mirror-20260922`. Both must be visible and sync-enabled. Android shell `content` can seed these fixtures without granting the app calendar-write access.

| Calendar | Event title | UTC schedule | UID / recurrence |
|---|---|---|---|
| First | Fixture-all-day | Sep 22 00:00 → Sep 23 00:00, allDay=1 | taskflow-fixture-all-day |
| First | Fixture-overnight | Sep 21 23:30 → Sep 22 00:30 | taskflow-fixture-overnight |
| Both | Fixture-appointment | Sep 22 15:00 → 16:00 | taskflow-fixture-appointment, identical on both |
| First | Fixture-weekly | Sep 22 09:00, duration PT30M | taskflow-fixture-weekly; FREQ=WEEKLY;BYDAY=TU |

Dates above are in 2026; use `eventTimezone=UTC`, confirmed status and the indicated `uid2445`. Start with no TaskFlow calendar permission. Run:

```powershell
flutter drive --keep-app-running --no-pub --driver=test_driver/appearance_test.dart --target=integration_test/device_calendar_flow_test.dart -d emulator-5554
```

Follow the printed `CALENDAR_HOST_*` markers. Deny then allow the actual permission dialogs. For the revoke marker use `adb shell appops set --uid com.example.agenda READ_CALENDAR ignore`; for restore use the same command with `allow`. Package-level/default AppOp changes did not reliably alter the effective runtime operation on this emulator. After completion, restore the original permission/first-request state, remove only these exact fixture calendars, and reinstall the regular APK without clearing data. Preserve an existing `calendar_access.xml` if repeating on an installation which had already requested calendar access.

Primary references: [Calendar Provider](https://developer.android.com/identity/providers/calendar-provider), [Instances](https://developer.android.com/reference/android/provider/CalendarContract.Instances), [permission requests](https://developer.android.com/training/permissions/requesting), [PermissionChecker](https://developer.android.com/reference/androidx/core/content/PermissionChecker).

This is Android emulator evidence. An additional [handoff check](HANDOFF_VALIDATION.md) started Google Calendar, which returned without displaying the synthetic event; external calendar display remains unverified. Physical-device provider variations and Apple platforms also need validation. This does not establish two-way calendar sync or a free/busy scheduling guarantee.

## 2026-11-11 — By account, and tasks added to the calendar

- **By account.** The screen lists one tick per account (`DeviceCalendar.accountKey`, type and name), and a tick shows every calendar of that account the account can write to (Android access level contributor or above; iOS `allowsContentModifications`). Holidays (`#holiday@`), birthdays (`#contacts@`, iOS birthday calendars), week numbers (`#weeknum@`), subscriptions and read-only calendars are extras: off by default and behind «More options», named by kind when the phone gives only an id. Preferences are `{enabled, accounts, extras, export, exportTarget}`; an older `selected` list becomes its accounts, with extras off. Events are asked for up to 50 calendars at once.
- **Tasks added to the calendar.** Off by default. Turning it on asks for `WRITE_CALENDAR` (Android) or full access (iOS). Each task with a day that's yours gets one event (an all-day one without a time, else its time and length, 30 minutes by default); a repeating task gets one per day for the next 30 days. The app keeps only event ids, times and a fingerprint per account (`app_preferences`, scope `calendar-export:<owner>`), so a change updates the event and a deletion removes it; days already past are left alone. The bridge only changes events in that record. Calendar hides those events, so a task doesn't show twice. The title goes into the phone's calendar, and so to that calendar's account (for example Google) when it syncs.
- **iOS.** `ios/Runner/DeviceCalendarBridge.swift` implements the same channel on EventKit, with usage strings in all three languages. It has not been compiled or run: that needs macOS.
- **Evidence.** Widget and unit tests (`test/calendar_accounts_test.dart`, `test/device_calendar_test.dart`, `test/device_calendar_ui_test.dart`) with a fake bridge.
