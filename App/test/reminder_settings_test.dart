import 'package:agenda/l10n/generated/app_localizations.dart';
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
  for (final lang in ['en', 'es']) {
    testWidgets(
        '$lang notification defaults and diagnostics fit large text in both themes',
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
              taskRepositoryProvider
                  .overrideWithValue(TaskRepository(database)),
            ],
            child: MaterialApp(
                locale: Locale(lang),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
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
        await tester.tap(find
            .text(lang == 'es' ? '30 minutos antes' : '30 minutes before')
            .last);
        await tester.pumpAndSettle();
        expect((await store.read('local')).leadMinutes, 30);
        await tester.scrollUntilVisible(find.text('Original task title'), 180);
        await tester.pumpAndSettle();
        expect(
            find.textContaining(lang == 'es' ? ' · bloqueado' : ' · blocked'),
            findsOneWidget);
        expect(
            find.textContaining(lang == 'es'
                ? 'Las notificaciones están desactivadas'
                : 'Notifications are disabled'),
            findsOneWidget);
        expect(store.alerts.single['status'], 'blocked');
        expect(store.alerts.single['error'],
            'Notifications are disabled in system settings.');
        await tester.scrollUntilVisible(
            find.text(lang == 'es'
                ? 'Actualizar y reintentar'
                : 'Refresh and retry scheduling'),
            180);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}

class _Preferences extends ReminderPreferenceStore {
  _Preferences(super.database);
  ReminderPreferences value = const ReminderPreferences();
  final alerts = <Map<String, Object?>>[
    {
      'identity': 'local/task/1/once',
      'title': 'Original task title',
      'fire_at': '2030-09-23T12:00:00Z',
      'status': 'blocked',
      'daily': 0,
      'error': 'Notifications are disabled in system settings.',
    }
  ];
  @override
  Future<ReminderPreferences> read(String owner) async => value;
  @override
  Future<void> write(String owner, ReminderPreferences settings) async {
    value = settings;
  }

  @override
  Future<List<Map<String, Object?>>> upcomingAlerts(String owner) async =>
      alerts;
  @override
  Future<List<Map<String, Object?>>> schedulingInfo() async => [
        {'key': 'error', 'value': 'background_failed'},
        {'key': 'window', 'value': '{"owner":"local","deferred":2}'},
      ];
}
