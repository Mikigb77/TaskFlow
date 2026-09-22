// Real Android SQLite, HTTP/PostgreSQL and note capture. Typed notes use no AI.
// Credentials use the same isolated secure-storage fixture as other drivers.
import 'package:agenda/main.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_archive.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/repositories/cloud_task_repository.dart';
import 'package:agenda/screens/review_tasks_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/archive_store.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/note_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/design_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Android notes retain capture type, sync, checklist and archive without creating tasks',
      (tester) async {
    await TaskReminders.initialize();
    final originalOwner = await TaskReminders.engine.activeOwner();
    FlutterSecureStorage.setMockInitialValues({});
    final api = ApiClient();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = 'notes-integration-$stamp@example.invalid';
    await api.signIn(email, 'Notes-fixture-only!2026', register: true);
    debugPrint('NOTES_FIXTURE_ACCOUNT: $email / ${api.account!.id}');
    final database = TaskDatabase();
    final sql = await database.database;
    final repository = CloudTaskRepository(database, api, api.account!.id);
    final owner = repository.ownerKey;
    final importedOwner = 'notes-import-fixture-$stamp';
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
      for (final scope in [owner, importedOwner]) {
        for (final table in [
          'tasks',
          'captures',
          'task_attachments',
          'archive_imports',
          'task_lists'
        ]) {
          await sql.delete(table, where: 'owner_key = ?', whereArgs: [scope]);
        }
        await sql.delete('app_preferences',
            where: 'scope IN (?, ?, ?, ?)',
            whereArgs: [
              'reminders:$scope',
              'calendars:$scope',
              'sharing:$scope',
              'regional:$scope'
            ]);
      }
      await api.signOut();
      api.close();
      await TaskReminders.activate(originalOwner ?? 'local');
    });
    await container.read(regionalProvider.notifier).ready;
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(
        builder: (_) => const VoiceTaskScreen(kind: 'note')));
    await tester.pumpAndSettle();
    const words =
        'Trip reference\nOpening hours are Friday at 17:00.\nhttps://example.org/visit';
    final field = find.byKey(const ValueKey('capture-words'));
    await tester.scrollUntilVisible(field, 180,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.enterText(field, words);
    await _until(
        tester,
        () async => (await store.pending(owner))
            .any((session) => session.text == words));
    final capture = (await store.pending(owner)).single;
    expect(capture.kind, 'note');
    FocusManager.instance.primaryFocus?.unfocus();
    navigator.pop();
    await tester.pumpAndSettle();
    // Resume from Notes' unfinished-capture entry, using the persisted type.
    await tester.tap(find.widgetWithText(NavigationDestination, 'Notes'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('resume-notes')), 160,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('resume-notes')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(words));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Note'))
            .selected,
        isTrue);
    await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Review note'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Review note'));
    await _until(tester,
        () async => find.byType(ReviewTasksScreen).evaluate().isNotEmpty);
    await tester.pumpAndSettle();
    expect(find.text('Planning'), findsNothing);
    final ready = (await store.read(capture.id, owner))!;
    expect(ready.drafts.single.task.notes, words);
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await _until(
        tester,
        () async =>
            (await repository.getAllTasks()).length == 1 &&
            find.byType(ReviewTasksScreen).evaluate().isEmpty);
    await store.saveReady(
        capture.id, owner, ready.drafts.map((item) => item.id).toSet());
    navigator.pop(); // Return from the now-empty unfinished-captures screen.
    await tester.pumpAndSettle();
    var note = (await repository.getAllTasks()).single;
    expect(note.isNote, isTrue);
    expect(note.notes, words);
    expect(note.nextOpenOccurrence(), isNull);
    expect(note.reminderDate, isNull);
    final step = ChecklistItem(title: 'Check the reference');
    await repository
        .updateTask(note.copyWith(checklist: [step], labels: ['travel']));
    await repository.addTask(Task(title: 'Bring tickets', priority: 1));
    await container.read(taskProvider.notifier).loadTasks();
    expect(await database.pending(owner), isEmpty);
    final before = {
      for (final item in await repository.getAllTasks())
        item.title: item.toApi()
    };
    await sql.delete('tasks', where: 'owner_key = ?', whereArgs: [owner]);
    await container.read(taskProvider.notifier).loadTasks();
    expect({
      for (final item in await repository.getAllTasks())
        item.title: item.toApi()
    }, before);
    note = (await repository.getAllTasks()).singleWhere((item) => item.isNote);
    await container
        .read(taskProvider.notifier)
        .setChecklistCompleted(note, step.id, true);
    note = (await repository.getAllTasks()).singleWhere((item) => item.isNote);
    expect(note.checklistDone, 1);
    expect(note.isCompleted, isFalse);
    final archive =
        TaskArchive.parse(await ArchiveStore(database, owner).export());
    final ids = archive.tasks.map((item) => item.sourceId).toSet();
    expect(
        (await ArchiveStore(database, importedOwner).import(archive, ids))
            .added,
        2);
    expect(
        (await ArchiveStore(database, importedOwner).import(archive, ids))
            .alreadyImported,
        2);
    expect(
        (await database.getTasks(ownerKey: importedOwner))
            .singleWhere((item) => item.isNote)
            .toApi(),
        note.toApi());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Trip reference'), findsNothing);
    expect(find.text('Bring tickets'), findsOneWidget);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Notes'));
    await tester.pumpAndSettle();
    expect(find.text('Trip reference'), findsOneWidget);
    expect(find.text('Bring tickets'), findsNothing);
    ScaffoldMessenger.of(tester.element(find.text('Trip reference')))
        .removeCurrentSnackBar();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await container.read(themeModeProvider.notifier).setMode(mode);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('notes-list-${mode.name}');
    }
    await tester.tap(find.text('Trip reference'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Complete'), findsNothing);
    await tester.scrollUntilVisible(find.byType(NoteText), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('notes-detail-dark');
    await tester.tap(find.byTooltip('Edit note'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('task-date')), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('task-title')), 'Trip reference updated');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    await container.read(taskProvider.notifier).loadTasks();
    final edited =
        (await repository.getAllTasks()).singleWhere((item) => item.isNote);
    expect(edited.id, note.id);
    expect(edited.title, 'Trip reference updated');
    expect(edited.checklistDone, 1);
    expect(await database.pending(owner), isEmpty);
    expect(tester.takeException(), isNull);
    debugPrint(
        'NOTES_NATIVE_VALIDATED: retained explicit capture, local note processing, SQLite/HTTP restoration, checklist, archive, task separation and editing');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(minutes: 6)));
}

Future<void> _until(
    WidgetTester tester, Future<bool> Function() condition) async {
  final watch = Stopwatch()..start();
  while (!await condition()) {
    if (watch.elapsed > const Duration(minutes: 1)) {
      fail('Note operation timed out.');
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
