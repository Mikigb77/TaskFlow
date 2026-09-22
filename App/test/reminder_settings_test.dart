import 'package:agenda/providers/reminder_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/screens/notification_settings_screen.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'notification defaults persist and settings fit large text in both themes',
      (tester) async {
    final database = TaskDatabase();
    final store = _Preferences(database);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(ProviderScope(
          overrides: [
            reminderPreferenceStoreProvider.overrideWithValue(store),
            taskRepositoryProvider.overrideWithValue(TaskRepository(database)),
          ],
          child: MaterialApp(
              theme: theme,
              builder: (_, child) => MediaQuery(
                  data: const MediaQueryData(
                      size: Size(320, 568), textScaler: TextScaler.linear(2)),
                  child: child!),
              home: const NotificationSettingsScreen())));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.byType(DropdownButtonFormField<int>), 160);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 minutes before').last);
      await tester.pumpAndSettle();
      expect((await store.read('local')).leadMinutes, 30);
      await tester.scrollUntilVisible(
          find.text('Refresh and retry scheduling'), 180);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

class _Preferences extends ReminderPreferenceStore {
  _Preferences(super.database);
  ReminderPreferences value = const ReminderPreferences();
  @override
  Future<ReminderPreferences> read(String owner) async => value;
  @override
  Future<void> write(String owner, ReminderPreferences settings) async {
    value = settings;
  }

  @override
  Future<List<Map<String, Object?>>> upcomingAlerts(String owner) async => [];
  @override
  Future<List<Map<String, Object?>>> schedulingInfo() async => [];
}
