// Real Android SQLite, UI and Docker HTTP sync. Only extraction output and
// credential storage are fixtures; the user's persisted session is untouched.
import 'package:agenda/main.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/repositories/cloud_task_repository.dart';
import 'package:agenda/screens/review_tasks_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/task_list_store.dart';
import 'package:agenda/widgets/task_list_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/design_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Android lists, checklist review, occurrence progress and fresh cache restoration',
      (tester) async {
    await TaskReminders.initialize();
    final originalOwner = await TaskReminders.engine.activeOwner();
    FlutterSecureStorage.setMockInitialValues({});
    final api = ApiClient();
    final email =
        'checklist-integration-${DateTime.now().microsecondsSinceEpoch}@example.invalid';
    debugPrint('Checklist fixture account: $email');
    await api.signIn(email, 'Checklist-fixture-only!2026', register: true);
    final database = TaskDatabase();
    final repository = CloudTaskRepository(database, api, api.account!.id);
    final owner = repository.ownerKey;
    final lists = TaskListStore(database, owner);
    final work = TaskListInfo(name: 'Work', color: 'blue');
    final personal = TaskListInfo(name: 'Personal', color: 'violet');
    await lists.create(work);
    await lists.create(personal);
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => _Auth(api)),
      taskRepositoryProvider.overrideWithValue(repository),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
    ]);
    final store = container.read(captureStoreProvider);
    addTearDown(() async {
      for (final task in await repository.getAllTasks()) {
        await repository.deleteTask(task.id!);
      }
      await repository.sync();
      for (final capture in await store.pending(owner)) {
        await store.discard(capture.id, owner);
      }
      container.dispose();
      await (await database.database)
          .delete('tasks', where: 'owner_key = ?', whereArgs: [owner]);
      await (await database.database)
          .delete('task_lists', where: 'owner_key = ?', whereArgs: [owner]);
      await api.signOut();
      api.close();
      await TaskReminders.activate(originalOwner ?? 'local');
    });
    final start = Task.day(DateTime.now()).add(const Duration(days: 1));
    var session = (await store.create(owner, 'Europe/Madrid',
            text: 'Pack passport and charger every week'))
        .copyWith(status: 'ready', drafts: [
      CaptureDraft.fromAI(TaskDraft.fromJson({
        'title': 'Pack for the trip',
        'scheduled_date': Task.dateKey(start),
        'due_date': null,
        'recurrence': 'weekly',
        'priority': 1,
        'notes': 'Keep hand luggage light.',
        'transcript': 'Pack passport and charger every week',
        'questions': [],
        'checklist': [
          {'id': '3fd9a2be-b0e2-4c90-8e2c-845b2c8279fb', 'title': 'Passport'},
          {'id': '2e7c75f2-f1b0-4d63-ad2e-c29ecfe2580c', 'title': 'Charger'},
        ],
      }))
    ]);
    session = session.copyWith(
        drafts: session.drafts
            .map((draft) => draft.copyWith(
                task: draft.task
                    .copyWith(listId: work.id, labels: ['travel', 'packing'])))
            .toList());
    await store.update(session);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).push(
        MaterialPageRoute<void>(
            builder: (_) => ReviewTasksScreen(session: session)));
    await tester.pumpAndSettle();
    final edit = find.byTooltip('Edit Passport');
    await tester.scrollUntilVisible(edit, 200);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit step'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('checklist-title')), 'Renewed passport');
    await tester.tap(find.text('Keep step'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await _until(
        tester,
        () async =>
            (await repository.getAllTasks()).length == 1 &&
            find.byType(ReviewTasksScreen).evaluate().isEmpty);
    await container.read(taskProvider.notifier).loadTasks();
    var task = (await repository.getAllTasks()).single;
    expect(task.checklist.first.title, 'Renewed passport');
    expect(task.listId, work.id);
    expect(task.labels, ['travel', 'packing']);
    expect(await database.pending(owner), isEmpty);
    tester.state<NavigatorState>(find.byType(Navigator)).push(
        MaterialPageRoute<void>(
            builder: (_) =>
                TaskDetailScreen(taskId: task.id!, occurrenceDate: start)));
    await tester.pumpAndSettle();
    final check = find.byKey(
        const ValueKey('check-step-2e7c75f2-f1b0-4d63-ad2e-c29ecfe2580c'));
    await tester.scrollUntilVisible(check, 220);
    await tester.pumpAndSettle();
    await tester.tap(check);
    await _until(
        tester,
        () async =>
            (await repository.getAllTasks())
                .single
                .occurrenceOn(start)!
                .checklistDone ==
            1);
    await container.read(taskProvider.notifier).loadTasks();
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await container.read(themeModeProvider.notifier).setMode(mode);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('checklist-detail-${mode.name}');
      expect(tester.takeException(), isNull);
    }
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).push(
        MaterialPageRoute<void>(
            builder: (_) =>
                TaskDetailScreen(taskId: task.id!, occurrenceDate: start)));
    await tester.pumpAndSettle();
    final picker = find.descendant(
        of: find.byType(TaskListPicker), matching: find.byType(ActionChip));
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal'));
    await _until(
        tester,
        () async =>
            (await repository.getAllTasks()).single.listId == personal.id);
    await container.read(taskProvider.notifier).loadTasks();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/lists');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Manage Personal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive list'));
    await _until(
        tester,
        () async => (await lists.all())
            .singleWhere((list) => list.id == personal.id)
            .archived);
    await container.read(taskProvider.notifier).loadTasks();
    await tester.pumpAndSettle();
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await container.read(themeModeProvider.notifier).setMode(mode);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('personal-lists-${mode.name}');
      expect(tester.takeException(), isNull);
    }
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await (await database.database)
        .delete('tasks', where: 'owner_key = ?', whereArgs: [owner]);
    await (await database.database)
        .delete('task_lists', where: 'owner_key = ?', whereArgs: [owner]);
    await container.read(taskProvider.notifier).loadTasks();
    task = (await repository.getAllTasks()).single;
    expect(task.checklist.first.id, '3fd9a2be-b0e2-4c90-8e2c-845b2c8279fb');
    expect(task.checklist.first.title, 'Renewed passport');
    expect(task.occurrenceOn(start)!.checklistDone, 1);
    expect(task.occurrenceOn(start.add(const Duration(days: 7)))!.checklistDone,
        0);
    expect(task.isCompleted, isFalse);
    expect(task.listId, personal.id);
    expect(task.labels, ['travel', 'packing']);
    expect(
        (await lists.all())
            .singleWhere((list) => list.id == personal.id)
            .archived,
        isTrue);
    expect(await database.pending(owner), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(minutes: 3)));
}

Future<void> _until(
    WidgetTester tester, Future<bool> Function() condition) async {
  final clock = Stopwatch()..start();
  while (!await condition()) {
    if (clock.elapsed > const Duration(seconds: 30)) {
      fail('Checklist state did not arrive.');
    }
    await tester.pump(const Duration(milliseconds: 150));
  }
}

class _Auth extends AuthNotifier {
  _Auth(super.api);
  @override
  Future<void> restore() async {
    state = AuthState(account: api.account);
  }
}
