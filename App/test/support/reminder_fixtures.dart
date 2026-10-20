import 'package:agenda/providers/reminder_provider.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/reminder_engine.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reminder preferences kept in memory: no database, no real alerts.
class MemoryReminderStore extends ReminderPreferenceStore {
  MemoryReminderStore([this.value = const ReminderPreferences()])
    : super(TaskDatabase());
  ReminderPreferences value;
  List<Map<String, Object?>> alerts = [];
  List<Map<String, Object?>> info = [];
  @override
  Future<ReminderPreferences> read(String owner) async => value;
  @override
  Future<void> write(String owner, ReminderPreferences value) async {
    this.value = value;
  }

  @override
  Future<List<Map<String, Object?>>> upcomingAlerts(String owner) async =>
      alerts;
  @override
  Future<List<Map<String, Object?>>> schedulingInfo() async => info;
}

/// Stands in for the phone: whether notifications and exact alarms are
/// allowed, and what the system dialog answers.
class FakeReminderAccess extends ReminderAccess {
  FakeReminderAccess({
    this.allowed = false,
    this.exact = true,
    this.grant = true,
  });
  bool allowed;
  bool exact;

  /// What the system permission dialog answers.
  bool grant;
  int permissionRequests = 0;
  int exactRequests = 0;

  /// Times TaskFlow's notifications page in the phone's settings was opened.
  int notificationSettingsOpened = 0;
  @override
  bool get supported => true;
  @override
  Future<ReminderCapability> capability() async =>
      ReminderCapability(allowed: allowed, exact: exact);
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (grant) allowed = true;
    return grant;
  }

  @override
  Future<void> requestExactAccess() async {
    exactRequests++;
    exact = true;
  }

  @override
  Future<void> openNotificationSettings() async {
    notificationSettingsOpened++;
  }

  @override
  Future<void> reconcile(String owner) async {}
}

List<Override> reminderOverrides(
  MemoryReminderStore store,
  FakeReminderAccess access,
) => [
  reminderPreferenceStoreProvider.overrideWithValue(store),
  reminderAccessProvider.overrideWithValue(access),
];
