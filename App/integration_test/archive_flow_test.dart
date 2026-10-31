// Uses the real Android document picker, SQLite and Docker API. ADB/UI automation
// must save and then choose the printed fixture filename when prompted.
import 'package:agenda/main.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/occurrence_exception.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_archive.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/repositories/cloud_task_repository.dart';
import 'package:agenda/screens/data_transfer_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/archive_files.dart';
import 'package:agenda/services/archive_store.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/task_list_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/design_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android file export, preview import and restored cloud copies',
      (tester) async {
    await TaskReminders.initialize();
    final originalOwner = await TaskReminders.engine.activeOwner();
    FlutterSecureStorage.setMockInitialValues({});
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = 'archive-integration-$stamp@example.invalid';
    final files = _NativeFiles('taskflow-integration-$stamp.json');
    debugPrint('Archive fixture account: $email');
    debugPrint('Archive fixture file: ${files.fileName}');
    final api = ApiClient();
    await api.signIn(email, 'Archive-fixture-only!2026', register: true);
    final database = TaskDatabase();
    final repository = CloudTaskRepository(database, api, api.account!.id);
    final owner = repository.ownerKey;
    final store = ArchiveStore(database, owner);
    final lists = TaskListStore(database, owner);
    final work = TaskListInfo(name: 'Archive work', color: 'blue');
    await lists.create(work);
    await lists
        .create(TaskListInfo(name: 'Empty archive list', archived: true));
    final start = Task.day(DateTime.now()).add(const Duration(days: 1));
    final key = Task.dateKey(start);
    final original = Task(
        title: 'Archive weekly review',
        priority: 2,
        dueDate: start,
        hasTime: false,
        recurrence: 'weekly',
        repeatInterval: 2,
        repeatWeekdays: [start.weekday],
        repeatUntil: start.add(const Duration(days: 60)),
        listId: work.id,
        labels: ['archive'],
        notes: 'Bring results.',
        completedDates: [key],
        reminderMinutes: -1,
        checklist: [
          ChecklistItem(title: 'Results', completedDates: [key])
        ],
        exceptions: [
          OccurrenceException(
              originalDate: key,
              date: start.add(const Duration(days: 1)),
              hasTime: false)
        ]);
    await repository.addTasks([
      original,
      Task(title: 'Archive Inbox', priority: 1, isCompleted: true)
    ]);
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => _Auth(api)),
      taskRepositoryProvider.overrideWithValue(repository),
      archiveStoreProvider.overrideWithValue(store),
      archiveFilesProvider.overrideWithValue(files),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
    ]);
    addTearDown(() async {
      for (final task in await repository.getAllTasks()) {
        await repository.deleteTask(task.id!);
      }
      await repository.sync();
      container.dispose();
      final sql = await database.database;
      for (final table in ['tasks', 'task_lists', 'archive_imports']) {
        await sql.delete(table, where: 'owner_key = ?', whereArgs: [owner]);
      }
      await api.signOut();
      api.close();
      await TaskReminders.activate(originalOwner ?? 'local');
    });
    await container.read(taskProvider.notifier).loadTasks();
    expect(await database.pending(owner), isEmpty);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/dataTransfer');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Export TaskFlow file'), 180);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export TaskFlow file'));
    debugPrint('ARCHIVE_WAIT_SAVE_DIALOG');
    await _until(tester, () async => files.saved);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose import file'));
    debugPrint('ARCHIVE_WAIT_PICK_DIALOG');
    await _until(tester, () async => files.chosen != null);
    await tester.pumpAndSettle();
    final archive = TaskArchive.parse(files.chosen!.contents);
    expect(archive.tasks.length, 2);
    expect(archive.tasks.every((row) => row.error == null), isTrue);
    expect((await repository.getAllTasks()).length, 2);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('confirm-import')), 240);
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await container.read(themeModeProvider.notifier).setMode(mode);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('archive-preview-${mode.name}');
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byKey(const ValueKey('confirm-import')));
    await _until(
        tester, () async => (await repository.getAllTasks()).length == 4);
    await container.read(taskProvider.notifier).loadTasks();
    expect(await database.pending(owner), isEmpty);
    expect((await lists.all()).length, 4);
    expect(
        (await store.import(
                archive, archive.tasks.map((row) => row.sourceId).toSet()))
            .added,
        0);
    await (await database.database)
        .delete('tasks', where: 'owner_key = ?', whereArgs: [owner]);
    await (await database.database)
        .delete('task_lists', where: 'owner_key = ?', whereArgs: [owner]);
    await container.read(taskProvider.notifier).loadTasks();
    final restored = await repository.getAllTasks();
    expect(restored.length, 4);
    for (final task in restored.where((task) => task.title == original.title)) {
      expect(task.toApi(), {...original.toApi(), 'list_id': task.listId});
      expect(task.occurrenceByKey(key)!.checklistDone, 1);
      expect(task.occurrenceByKey(key)!.isCompleted, isTrue);
    }
    expect(
        restored
            .where((task) => task.title == original.title)
            .map((task) => task.listId)
            .toSet()
            .length,
        2);
    expect((await lists.all()).length, 4);
    expect(await database.pending(owner), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(minutes: 7)));
}

Future<void> _until(
    WidgetTester tester, Future<bool> Function() condition) async {
  final watch = Stopwatch()..start();
  while (!await condition()) {
    if (watch.elapsed > const Duration(minutes: 2)) {
      fail('Archive operation timed out.');
    }
    await tester.pump(const Duration(milliseconds: 150));
  }
}

class _NativeFiles extends ArchiveFiles {
  _NativeFiles(String name) : super(fileName: name);
  bool saved = false;
  ArchiveFile? chosen;
  @override
  Future<bool> save(String contents) async =>
      saved = await super.save(contents);
  @override
  Future<ArchiveFile?> choose() async => chosen = await super.choose();
}

class _Auth extends AuthNotifier {
  _Auth(super.api);
  @override
  Future<void> restore() async {
    state = AuthState(account: api.account);
  }
}
