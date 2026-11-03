// Emulator-only: the host observes each Spanish notification and taps its
// actual Complete/Snooze button. This test never invokes the response handler.
import 'dart:convert';
import 'package:agenda/providers/no_retry.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/regional_settings_screen.dart';
import 'package:agenda/widgets/language_selector.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/design_fixtures.dart';
import 'support/reminder_language_recovery.dart';
import 'database_concurrency_test.dart' as concurrency;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  concurrency.main();
  testWidgets('Spanish native notifications preserve schedules and actions',
      (tester) async {
    await TaskReminders.initialize();
    await ReminderLanguageRecovery.recoverPending();
    final capability = await TaskReminders.engine.driver.capability();
    expect(capability.allowed, isTrue);
    expect(capability.exact, isTrue,
        reason:
            'This bounded delivery fixture requires exact access. Restore its previous app-op afterward.');
    final database = TaskDatabase();
    final sql = await database.database;
    final owner = 'reminder-language-${DateTime.now().microsecondsSinceEpoch}';
    final recovery = await ReminderLanguageRecovery.begin(owner);
    final regional = RegionalPreferenceStore(database);
    final preferences = ReminderPreferenceStore(database);
    final api = OfflineApiClient();
    final container = ProviderContainer(retry: noRetry, overrides: [
      authProvider.overrideWith((ref) => _Auth(api)),
      regionalStoreProvider.overrideWithValue(regional),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
    ]);
    addTearDown(() async {
      container.dispose();
      api.close();
      await recovery.restore();
    });
    await regional.write(const RegionalPreferences(language: 'en'));
    await TaskReminders.activate(owner);
    await TaskReminders.refreshLanguage();
    final android = TaskReminders.plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()!;
    final originalChannel = (await android.getNotificationChannels())!
        .singleWhere((channel) => channel.id == 'taskflow_reminders');
    await preferences.write(
        owner, const ReminderPreferences(enabled: true, leadMinutes: 0));
    final now = DateTime.now();
    final completeId = await database.insertTask(
        Task(
            title: 'TaskFlow idioma · completar',
            priority: 1,
            dueDate: now.add(const Duration(seconds: 70)),
            reminderMinutes: 0),
        ownerKey: owner);
    final snoozeId = await database.insertTask(
        Task(
            title: 'TaskFlow idioma · posponer',
            priority: 1,
            dueDate: now.add(const Duration(seconds: 95)),
            reminderMinutes: 0),
        ownerKey: owner);
    final fixtureTasks = jsonEncode(await sql.query('tasks',
        where: 'owner_key = ?', whereArgs: [owner], orderBy: 'id'));
    await TaskReminders.engine.reconcile(owner);
    final before = await sql.query('reminder_state',
        where: 'owner_key = ?', whereArgs: [owner], orderBy: 'id');
    expect(before, hasLength(2));
    expect(before.every((row) => row['body'] == 'It’s time for your task.'),
        isTrue);
    await container.read(regionalProvider.notifier).ready;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const _Settings()));
    await tester.pumpAndSettle();
    // The language picker lives in Settings; its sheet works the same here.
    showLanguageSelector(tester.element(find.byType(RegionalSettingsScreen)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español').last);
    await tester.pumpAndSettle();
    expect(find.text('Hora y región'), findsOneWidget);
    await _until(tester, () async {
      final rows = await sql
          .query('reminder_state', where: 'owner_key = ?', whereArgs: [owner]);
      return rows.length == 2 &&
          rows.every((row) => row['body'] == 'Es hora de tu tarea.');
    }, seconds: 20);
    final after = await sql.query('reminder_state',
        where: 'owner_key = ?', whereArgs: [owner], orderBy: 'id');
    for (var i = 0; i < before.length; i++) {
      expect(after[i]['id'], before[i]['id']);
      expect(after[i]['fire_at'], before[i]['fire_at']);
      expect(after[i]['due_at'], before[i]['due_at']);
      expect(after[i]['title'], before[i]['title']);
    }
    expect(
        jsonEncode(await sql.query('tasks',
            where: 'owner_key = ?', whereArgs: [owner], orderBy: 'id')),
        fixtureTasks);
    final channel = (await android.getNotificationChannels())!
        .singleWhere((channel) => channel.id == 'taskflow_reminders');
    expect(channel.name, 'Recordatorios de tareas');
    expect(channel.importance, originalChannel.importance);
    expect(channel.playSound, originalChannel.playSound);
    expect(channel.enableVibration, originalChannel.enableVibration);
    expect(channel.showBadge, originalChannel.showBadge);
    final pending = await TaskReminders.plugin.pendingNotificationRequests();
    for (final row in after) {
      expect(pending.singleWhere((notice) => notice.id == row['id']).body,
          'Es hora de tu tarea.');
    }
    debugPrint('REMINDER_LANGUAGE_WAIT_COMPLETE: $completeId');
    await _until(
        tester,
        () async => (await database.getTasks(ownerKey: owner))
            .singleWhere((task) => task.id == completeId)
            .isCompleted);
    debugPrint('REMINDER_LANGUAGE_WAIT_SNOOZE: $snoozeId');
    await _until(
        tester,
        () async => (await sql.query('reminder_snoozes',
                where: 'owner_key = ?', whereArgs: [owner]))
            .isNotEmpty);
    final snoozed = (await sql.query('reminder_state',
            where: 'owner_key = ? AND task_id = ?',
            whereArgs: [owner, snoozeId]))
        .single;
    await _until(
        tester,
        () async => (await TaskReminders.plugin.pendingNotificationRequests())
            .any((notice) =>
                notice.id == snoozed['id'] &&
                notice.body == 'Tu tarea pospuesta.'),
        seconds: 20);
    final newTime = DateTime.parse((await sql.query('reminder_snoozes',
            where: 'owner_key = ?', whereArgs: [owner]))
        .single['fire_at'] as String);
    expect(newTime.difference(DateTime.now().toUtc()).inMinutes,
        inInclusiveRange(9, 10));
    final tasks = await database.getTasks(ownerKey: owner);
    expect(
        tasks.singleWhere((task) => task.id == completeId).isCompleted, isTrue);
    expect(
        tasks.singleWhere((task) => task.id == snoozeId).isCompleted, isFalse);
    expect(
        tasks.singleWhere((task) => task.id == snoozeId).dueDate,
        DateTime.parse(
            before.singleWhere((row) => row['task_id'] == snoozeId)['due_at']
                as String));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugPrint('REMINDER_LANGUAGE_NATIVE_ACTIONS_PASSED');
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Future<void> _until(WidgetTester tester, Future<bool> Function() condition,
    {int seconds = 120}) async {
  final watch = Stopwatch()..start();
  while (!await condition()) {
    if (watch.elapsed > Duration(seconds: seconds)) {
      fail('Expected native reminder state did not arrive.');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

class _Auth extends AuthNotifier {
  _Auth(super.api);
  @override
  Future<void> restore() async {
    state = const AuthState();
  }
}

class _Settings extends ConsumerWidget {
  const _Settings();
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
      locale: ref.watch(regionalProvider).localeFor(const [Locale('en')]),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.light,
      home: const RegionalSettingsScreen());
}
