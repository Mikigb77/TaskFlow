import 'dart:convert';
import 'dart:io';
import 'package:agenda/providers/no_retry.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/screens/captures_screen.dart';
import 'package:agenda/services/android_database_factory.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_problem.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/task_list_store.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../test/support/design_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture language preserves real SQLite input and partial saves',
      (tester) async {
    final cache = await getTemporaryDirectory();
    final directory = await Directory(p.join(cache.path,
            'capture-language-${DateTime.now().microsecondsSinceEpoch}'))
        .create();
    final factory = AndroidDatabaseFactory();
    final path = p.join(directory.path, 'fixture.db');
    final sql = await factory.openDatabase(path,
        options: OpenDatabaseOptions(
            singleInstance: false,
            onConfigure: (db) => db.rawQuery('PRAGMA busy_timeout = 0')));
    await sql.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)');
    await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
    final database = TaskDatabase.forTesting(sql);
    final store = CaptureStore(database, directory: directory);
    final regional = RegionalPreferenceStore(database);
    await regional.write(const RegionalPreferences(language: 'en'));
    final api = _UnavailableApi();
    final container = ProviderContainer(retry: noRetry, overrides: [
      authProvider.overrideWith((ref) => _Guest(api)),
      apiClientProvider.overrideWithValue(api),
      captureOwnerProvider.overrideWithValue('local'),
      captureStoreProvider.overrideWithValue(store),
      regionalStoreProvider.overrideWithValue(regional),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      taskProvider.overrideWith((ref) => _Tasks(database)),
      taskRepositoryProvider.overrideWithValue(TaskRepository(database)),
      taskListStoreProvider.overrideWithValue(TaskListStore(database, 'local')),
    ]);
    addTearDown(() async {
      container.dispose();
      api.close();
      await database.close();
      if (!p.isWithin(cache.absolute.path, directory.absolute.path)) {
        throw StateError('Fixture directory escaped app cache.');
      }
      await directory.delete(recursive: true);
    });
    const words = 'Doctor Friday at 17:00 · bring José’s report';
    final failed = await store.create('local', 'Europe/Madrid',
        text: words, now: DateTime.utc(2026, 9, 23, 10));
    final batch = await store.create('local', 'Europe/Madrid',
        text: 'Original batch words');
    expect(await store.read(batch.id, 'local'), isNotNull);
    final changed = await sql.update('captures', {'status': 'editing'},
        where: 'id = ?', whereArgs: [batch.id]);
    expect(changed, 1,
        reason: 'A standalone Android WAL update must report its changed row.');
    await store.update(batch
        .copyWith(status: 'ready', transcript: 'Original batch words', drafts: [
      CaptureDraft(
          id: 'ticket',
          task: Task(
              title: 'Book the tickets',
              priority: 1,
              dueDate: DateTime(2026, 9, 25),
              hasTime: false)),
      CaptureDraft(
          id: 'report',
          task: Task(
              title: 'Informe de José',
              priority: 2,
              dueDate: DateTime(2026, 9, 25, 17),
              notes: 'Keep original notes')),
      CaptureDraft(
          id: 'call',
          task: Task(title: 'Call Mum', priority: 1),
          questions: ['Morning or afternoon?'],
          confirmed: false),
    ]));
    await container.read(regionalProvider.notifier).ready;
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const _App()));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.tap(find.text(words));
    await tester.pumpAndSettle();
    final request = find.widgetWithText(FilledButton, 'Done');
    await tester.ensureVisible(request);
    await tester.pumpAndSettle();
    await tester.tap(request);
    await tester.pumpAndSettle();
    final afterFailure = (await store.read(failed.id, 'local'))!;
    expect(afterFailure.error, CaptureProblem.unavailable);
    expect(afterFailure.text, words);
    expect(afterFailure.capturedAt, failed.capturedAt);
    expect(afterFailure.timezone, 'Europe/Madrid');
    final snapshot = jsonEncode(afterFailure.toJson());
    await container
        .read(regionalProvider.notifier)
        .set(const RegionalPreferences(language: 'es'));
    await tester.pumpAndSettle();
    final error =
        find.textContaining('El servicio de procesamiento no está disponible.');
    await tester.ensureVisible(error);
    await tester.pumpAndSettle();
    expect(error, findsOneWidget);
    expect(
        jsonEncode((await store.read(failed.id, 'local'))!.toJson()), snapshot);
    await binding.takeScreenshot('capture-l10n-error-spanish');
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.textContaining('3 borradores · 2 listos'), findsOneWidget);
    await tester.tap(find.text('Book the tickets'));
    await tester.pumpAndSettle();
    final beforeReview =
        jsonEncode((await store.read(batch.id, 'local'))!.toJson());
    for (final language in ['en', 'es']) {
      await container
          .read(regionalProvider.notifier)
          .set(RegionalPreferences(language: language));
      await tester.pumpAndSettle();
      expect(jsonEncode((await store.read(batch.id, 'local'))!.toJson()),
          beforeReview);
    }
    expect(find.text('Guardar 2 tareas'), findsOneWidget);
    await binding.takeScreenshot('capture-l10n-review-spanish-light');
    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('capture-l10n-review-spanish-dark');
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await tester.pumpAndSettle();
    expect(await database.getTasks(), hasLength(2));
    expect((await store.read(batch.id, 'local'))!.remaining, hasLength(1));
    expect(find.text('Revisa los datos de arriba'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    final confirm = find.text('Usar los datos mostrados');
    await tester.scrollUntilVisible(confirm, 150,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await tester.pumpAndSettle();
    final saved = await database.getTasks();
    expect(saved, hasLength(3));
    final timed = saved.singleWhere((task) => task.title == 'Informe de José');
    expect(timed.dueDate, DateTime(2026, 9, 25, 17));
    expect(timed.notes, 'Keep original notes');
    expect(
        saved.singleWhere((task) => task.title == 'Book the tickets').hasTime,
        isFalse);
    expect(api.requests, 1);
    expect((await store.pending('local')).single.id, failed.id);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    // A fresh connection reads the same retained failure and saved tasks.
    final reopened = await factory.openDatabase(path,
        options: OpenDatabaseOptions(singleInstance: false));
    try {
      final recovered =
          CaptureStore(TaskDatabase.forTesting(reopened), directory: directory);
      expect(jsonEncode((await recovered.read(failed.id, 'local'))!.toJson()),
          snapshot);
      expect(await reopened.query('tasks'), hasLength(3));
    } finally {
      await reopened.close();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

class _Guest extends AuthNotifier {
  _Guest(super.api);
  @override
  Future<void> restore() async {
    state = const AuthState();
  }
}

class _Tasks extends TaskNotifier {
  _Tasks(this.db) : super(TaskRepository(db));
  final TaskDatabase db;
  @override
  Future<void> loadTasks() async {
    state = AsyncValue.data(await db.getTasks());
  }
}

class _UnavailableApi extends OfflineApiClient {
  int requests = 0;
  @override
  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? data,
      String? audioPath,
      bool authenticated = true,
      int? accountId,
      bool retry = true}) async {
    if (path != 'ai/drafts/') throw StateError('Unexpected fixture request.');
    requests++;
    throw ApiException(503, 'Synthetic service failure');
  }
}

class _App extends ConsumerWidget {
  const _App();
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
      locale: ref.watch(regionalProvider).localeFor(const [Locale('en')]),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      home: const CapturesScreen());
}
