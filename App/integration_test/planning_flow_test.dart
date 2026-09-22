// Real Android UI, SQLite, Docker HTTP sync and notification plugin scheduling.
// Extraction output and secure credential storage are isolated fixtures.
import 'package:agenda/main.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/reminder_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/repositories/cloud_task_repository.dart';
import 'package:agenda/screens/review_tasks_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/design_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Android planning review, deadline reminders and timeline survive fresh-cache sync',
      (tester) async {
    await TaskReminders.initialize();
    final originalOwner = await TaskReminders.engine.activeOwner();
    FlutterSecureStorage.setMockInitialValues({});
    final api = ApiClient();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = 'planning-integration-$stamp@example.invalid';
    await api.signIn(email, 'Planning-fixture-only!2026', register: true);
    debugPrint('PLANNING_FIXTURE_ACCOUNT: $email / ${api.account!.id}');
    final database = TaskDatabase();
    final sql = await database.database;
    final repository = CloudTaskRepository(database, api, api.account!.id);
    final owner = repository.ownerKey;
    final store = CaptureStore(database);
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => _Auth(api)),
      taskRepositoryProvider.overrideWithValue(repository),
      regionalStoreProvider.overrideWithValue(MemoryRegionalStore()),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
    ]);
    addTearDown(() async {
      for (final task in await repository.getAllTasks()) {
        await repository.deleteTask(task.id!);
      }
      await repository.sync();
      container.dispose();
      for (final table in ['tasks', 'captures', 'task_attachments']) {
        await sql.delete(table, where: 'owner_key = ?', whereArgs: [owner]);
      }
      await sql.delete('app_preferences',
          where: 'scope IN (?, ?)',
          whereArgs: ['reminders:$owner', 'calendars:$owner']);
      await api.signOut();
      api.close();
      await TaskReminders.activate(originalOwner ?? 'local');
    });
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day + 1, 9);
    final movedDay = DateTime(now.year, now.month, now.day + 2);
    final deadline = DateTime(first.year, first.month, first.day, 17);
    var session = await store.create(owner, 'UTC',
        text: 'Work on the report for one hour, due at 5 p.m.');
    session = session.copyWith(status: 'ready', drafts: [
      CaptureDraft.fromAI(TaskDraft.fromJson({
        'title': 'Prepare the report',
        'due_date': first.toUtc().toIso8601String(),
        'deadline_at': deadline.toUtc().toIso8601String(),
        'duration_minutes': 60,
        'recurrence': 'weekly',
        'repeat_until':
            Task.dateKey(DateTime(first.year, first.month, first.day + 7)),
        'priority': 2,
        'notes': 'Bring the draft.',
        'questions': [],
        'transcript': session.text,
      })),
      CaptureDraft.fromAI(TaskDraft.fromJson({
        'title': 'Submit the invoice',
        'deadline_date': Task.dateKey(movedDay),
        'priority': 2,
        'notes': '',
        'questions': [],
        'transcript': session.text,
      })),
    ]);
    await store.update(session);
    await container.read(regionalProvider.notifier).ready;
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(
        builder: (_) => ReviewTasksScreen(session: session)));
    await tester.pumpAndSettle();
    final reviewScroll = find
        .descendant(
            of: find.byType(ReviewTasksScreen),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('task-duration')).first, 200,
        scrollable: reviewScroll);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-duration')).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('duration-input')), '90');
    await tester.tap(find.byKey(const ValueKey('duration-save')));
    await tester.pumpAndSettle();
    final anchor = find.byKey(const ValueKey('reminder-anchor-planned'));
    await tester.scrollUntilVisible(anchor, 200, scrollable: reviewScroll);
    await tester.pumpAndSettle();
    await tester.tap(anchor);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deadline').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await _until(
        tester,
        () async =>
            (await repository.getAllTasks()).length == 2 &&
            find.byType(ReviewTasksScreen).evaluate().isEmpty);
    await container.read(taskProvider.notifier).loadTasks();
    var report = (await repository.getAllTasks())
        .singleWhere((task) => task.title == 'Prepare the report');
    expect(report.durationMinutes, 90);
    expect(report.deadline, deadline);
    expect(report.reminderAnchor, 'deadline');
    expect(await database.pending(owner), isEmpty);
    final occurrence = report.occurrenceByKey(Task.dateKey(first))!;
    await container.read(taskProvider.notifier).changeOccurrence(occurrence,
        DateTime(movedDay.year, movedDay.month, movedDay.day, 9), true);
    await container.read(taskProvider.notifier).addTask(Task(
        title: 'Review the sketches',
        priority: 1,
        dueDate: DateTime(movedDay.year, movedDay.month, movedDay.day, 9, 30),
        durationMinutes: 45,
        reminderMinutes: -1));
    await container.read(taskProvider.notifier).loadTasks();
    report = (await repository.getAllTasks())
        .singleWhere((task) => task.title == 'Prepare the report');
    expect(
        report.occurrenceByKey(Task.dateKey(first))!.displayDeadline, deadline);
    expect(report.occurrenceByKey(Task.dateKey(first))!.plannedAfterDeadline,
        isTrue);
    final before = {
      for (final task in await repository.getAllTasks())
        task.title: task.toApi()
    };
    await sql.delete('tasks', where: 'owner_key = ?', whereArgs: [owner]);
    await container.read(taskProvider.notifier).loadTasks();
    final after = {
      for (final task in await repository.getAllTasks())
        task.title: task.toApi()
    };
    expect(after, before);
    expect(await database.pending(owner), isEmpty);
    await ReminderPreferenceStore(database).write(
        owner,
        const ReminderPreferences(
            enabled: true, leadMinutes: 60, dateOnlyTime: 600));
    container.invalidate(reminderPreferencesProvider);
    await container.read(reminderPreferencesProvider.future);
    await TaskReminders.activate(owner);
    await TaskReminders.sync(await repository.getAllTasks(), ownerKey: owner);
    final alerts = await sql.query('reminder_state',
        where: 'owner_key = ? AND status != ?', whereArgs: [owner, 'inactive']);
    report = (await repository.getAllTasks())
        .singleWhere((task) => task.title == 'Prepare the report');
    final alert = alerts.singleWhere((row) =>
        row['task_id'] == report.id &&
        row['occurrence'] == Task.dateKey(first));
    expect(DateTime.parse(alert['due_at'] as String), deadline);
    final target = await TaskReminders.engine.taskForAlert(alert['id'] as int);
    expect(target!.displayDeadline, deadline);
    expect(Task.dateKey(target.displayDate!), Task.dateKey(movedDay));
    navigator.pushNamed('/timeline', arguments: movedDay);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Jump to first timed item'), 200,
        scrollable: find
            .descendant(
                of: find.byKey(const ValueKey('timeline-scroll')),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jump to first timed item'));
    await tester.pumpAndSettle();
    expect(find.text('Prepare the report').hitTestable(), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.text('Prepare the report')))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      await container.read(themeModeProvider.notifier).setMode(theme);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('planning-timeline-${theme.name}');
    }
    await tester.tap(find.text('Prepare the report'));
    await tester.pumpAndSettle();
    expect(find.text('Planned for'), findsOneWidget);
    final late = find.text(
        'This plan finishes after the deadline. Check the start or duration.');
    await tester.scrollUntilVisible(late, 180,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(late, findsOneWidget);
    await binding.takeScreenshot('planning-detail-dark');
    expect(tester.takeException(), isNull);
    debugPrint(
        'PLANNING_NATIVE_VALIDATED: review edits, original occurrence deadline, SQLite/HTTP fresh cache, real reminder schedule, overlapping timeline');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(minutes: 8)));
}

Future<void> _until(
    WidgetTester tester, Future<bool> Function() condition) async {
  final watch = Stopwatch()..start();
  while (!await condition()) {
    if (watch.elapsed > const Duration(minutes: 2)) {
      fail('Planning operation timed out.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _Auth extends AuthNotifier {
  _Auth(super.api);
  @override
  Future<void> restore() async {
    state = AuthState(account: api.account);
  }
}
