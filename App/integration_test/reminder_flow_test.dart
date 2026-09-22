// Real Android notification plugin and SQLite. No user task is deleted.
// Grant POST_NOTIFICATIONS on the test emulator before running this driver.
import 'dart:convert';
import 'package:agenda/main.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workmanager/workmanager.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Android reminder settings, scheduling, snooze and occurrence navigation',
      (tester) async {
    await TaskReminders.initialize();
    final originalOwner = await TaskReminders.engine.activeOwner();
    final owner = 'notification-test-${DateTime.now().microsecondsSinceEpoch}';
    final database = TaskDatabase();
    final store = ReminderPreferenceStore(database);
    final api = ApiClient();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith((ref) => _Auth(api)),
      taskRepositoryProvider.overrideWithValue(_Repository(database, owner)),
    ]);
    addTearDown(() async {
      await store.write(owner, const ReminderPreferences());
      await TaskReminders.engine.reconcile(owner);
      for (final task in await database.getTasks(ownerKey: owner)) {
        await database.deleteTask(task.id!, ownerKey: owner);
      }
      await TaskReminders.activate(originalOwner ?? 'local');
      container.dispose();
      api.close();
    });
    await TaskReminders.activate(owner);
    final start = DateTime.now().add(const Duration(hours: 2));
    await database.insertTask(
        Task(
            title: 'Runtime repeating task',
            priority: 1,
            dueDate: start,
            recurrence: 'daily',
            repeatUntil: start.add(const Duration(days: 2))),
        ownerKey: owner);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/notifications');
    await tester.pumpAndSettle();
    await _until(tester,
        () async => find.text('Enable reminders').evaluate().isNotEmpty);
    expect((await store.read(owner)).enabled, isFalse);
    await tester.tap(find.byType(SwitchListTile));
    await _until(tester, () async => (await store.read(owner)).enabled);
    await _until(
        tester,
        () async =>
            (await TaskReminders.plugin.pendingNotificationRequests()).length ==
            3);
    await tester.pumpAndSettle();
    expect(find.text('System permission is on'), findsOneWidget);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('reminder-settings');
    final db = await database.database;
    final rows = await db.query('reminder_state',
        where: 'owner_key = ? AND status != ?',
        whereArgs: [owner, 'inactive'],
        orderBy: 'fire_at');
    expect(rows.length, 3);
    final beforeRefresh = (await db
            .query('reminder_meta', where: 'key = ?', whereArgs: ['window']))
        .single['value'];
    await Workmanager()
        .registerOneOffTask('test-refresh-$owner', 'refresh-reminders');
    await _until(tester, () async {
      final current = (await db
              .query('reminder_meta', where: 'key = ?', whereArgs: ['window']))
          .single['value'];
      return current != beforeRefresh;
    });
    final alert = rows.first;
    final id = alert['id'] as int;
    String payload(Map<String, Object?> row) =>
        jsonEncode({'id': row['id'], 'token': row['token']});
    await TaskReminders.respond(NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        id: id,
        actionId: 'snooze',
        payload: payload(alert)));
    final snoozed =
        (await db.query('reminder_state', where: 'id = ?', whereArgs: [id]))
            .single;
    expect(
        DateTime.parse(snoozed['fire_at'] as String)
            .difference(DateTime.now().toUtc())
            .inMinutes,
        inInclusiveRange(9, 10));
    expect(snoozed['token'], isNot(alert['token']));
    await TaskReminders.respond(NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        id: id,
        payload: payload(snoozed)));
    await _until(tester,
        () async => find.byType(TaskDetailScreen).evaluate().isNotEmpty);
    expect(
        tester
            .widget<TaskDetailScreen>(find.byType(TaskDetailScreen))
            .occurrenceDate,
        DateTime(start.year, start.month, start.day, start.hour, start.minute));
    await TaskReminders.respond(NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        id: id,
        actionId: 'complete',
        payload: payload(snoozed)));
    final task = (await database.getTasks(ownerKey: owner)).single;
    expect(task.completedDates, [Task.dateKey(start)]);
    expect(task.occurrenceOn(start.add(const Duration(days: 1)))!.isCompleted,
        isFalse);
    expect(
        (await TaskReminders.plugin.pendingNotificationRequests())
            .any((n) => n.id == id),
        isFalse);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 3)));
}

Future<void> _until(
    WidgetTester tester, Future<bool> Function() condition) async {
  final watch = Stopwatch()..start();
  while (!await condition()) {
    if (watch.elapsed > const Duration(seconds: 20)) {
      fail('Expected reminder state did not arrive.');
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

class _Repository extends TaskRepository {
  final TaskDatabase database;
  @override
  final String ownerKey;
  _Repository(this.database, this.ownerKey) : super(database);
  @override
  Future<List<Task>> getAllTasks() => database.getTasks(ownerKey: ownerKey);
}
