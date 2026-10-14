// Real Android picker, SQLite, authenticated HTTP and Docker private storage.
// Host automation selects ATTACHMENT_FIXTURE, recreates the API container at the
// printed marker, then creates the printed app-private resume file with run-as.
import 'dart:io';
import 'package:agenda/main.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/repositories/cloud_task_repository.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/attachment_files.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import '../test/support/design_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const fixture = String.fromEnvironment('ATTACHMENT_FIXTURE');
  testWidgets(
      'Android attachment upload and restoration after server recreation',
      (tester) async {
    expect(fixture, isNotEmpty,
        reason: 'Provide a unique text fixture in Android Downloads.');
    await TaskReminders.initialize();
    final originalOwner = await TaskReminders.engine.activeOwner();
    FlutterSecureStorage.setMockInitialValues({});
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = 'attachment-integration-$stamp@example.invalid';
    final api = ApiClient();
    await api.signIn(email, 'Attachment-fixture-only!2026', register: true);
    debugPrint('Attachment fixture account: $email / ${api.account!.id}');
    final database = TaskDatabase();
    final repository = CloudTaskRepository(database, api, api.account!.id);
    final owner = repository.ownerKey;
    final sql = await database.database;
    final resume = File(
        '${(await getApplicationSupportDirectory()).path}/attachment-resume-$stamp');
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
      for (final table in ['tasks', 'task_attachments']) {
        await sql.delete(table, where: 'owner_key = ?', whereArgs: [owner]);
      }
      if (await resume.exists()) await resume.delete();
      await api.signOut();
      api.close();
      await TaskReminders.activate(originalOwner ?? 'local');
    });
    await container.read(regionalProvider.notifier).ready;
    await container.read(taskProvider.notifier).loadTasks();
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    // New tasks come from the capture sheet; the form attaches files to a
    // saved one.
    final created = await container.read(taskProvider.notifier).addTask(
        Task(title: 'Attachment restoration fixture', priority: 1));
    final draft = (await repository.getAllTasks())
        .singleWhere((task) => task.id == created);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute(builder: (_) => TaskEditor(task: draft)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-more-details')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Add attachment'), 240,
        scrollable: find
            .descendant(
                of: find.byType(TaskEditor), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add attachment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attach a file'));
    debugPrint('ATTACHMENT_WAIT_PICK_DIALOG: $fixture');
    await _until(tester, () async => find.text(fixture).evaluate().isNotEmpty);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await _until(tester,
        () async => (await repository.attachments.forTask(created)).isNotEmpty);
    await container.read(taskProvider.notifier).loadTasks();
    final task = (await repository.getAllTasks()).single;
    final saved = (await repository.attachments.forTask(task.id!)).single;
    expect(saved.remote, isTrue, reason: saved.error ?? repository.syncError);
    expect(saved.uploadPending, isFalse);
    final originalBytes = await File(saved.localPath!).readAsBytes();
    expect(sha256.convert(originalBytes).toString(), saved.sha256);
    expect(saved.name, fixture);
    debugPrint('ATTACHMENT_RECREATE_API_THEN_RESUME: ${resume.path}');
    await _until(tester, () => resume.exists());
    // Simulate another device: no task or attachment cache or private file.
    await AttachmentFiles().removeOwned(saved.localPath!);
    await sql.delete('tasks', where: 'owner_key = ?', whereArgs: [owner]);
    await sql
        .delete('task_attachments', where: 'owner_key = ?', whereArgs: [owner]);
    await container.read(taskProvider.notifier).loadTasks();
    final restored = (await repository.getAllTasks()).single;
    expect(restored.filePaths, isEmpty);
    final remote = (await repository.attachments.forTask(restored.id!)).single;
    expect(remote.id, saved.id);
    expect(remote.localPath, isNull);
    navigator.popUntil((route) => route.isFirst);
    navigator.pushNamed('/taskDetails', arguments: restored.id);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Download'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Available to download'), findsOneWidget);
    await tester.tap(find.text('Download'));
    await _until(
        tester,
        () async =>
            (await repository.attachments.forTask(restored.id!))
                .single
                .localPath !=
            null);
    await tester.pumpAndSettle();
    final downloaded =
        (await repository.attachments.forTask(restored.id!)).single;
    expect(await File(downloaded.localPath!).readAsBytes(), originalBytes);
    expect(find.text('Backed up to your account'), findsOneWidget);
    await binding.convertFlutterSurfaceToImage();
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      await container.read(themeModeProvider.notifier).setMode(theme);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('attachments-restored-${theme.name}');
    }
    await tester.tap(find.text('Remove attachment'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Remove attachment')));
    await _until(
        tester,
        () async =>
            (await repository.attachments.forTask(restored.id!)).isEmpty);
    await tester.pumpAndSettle();
    await expectLater(
        api.downloadAttachment(saved.id, accountId: api.account!.id),
        throwsA(isA<ApiException>()
            .having((error) => error.status, 'status', 404)));
    expect(await File(downloaded.localPath!).exists(), isFalse);
    expect(tester.takeException(), isNull);
    debugPrint(
        'Attachment real HTTP/SQLite/file restoration verified: ${saved.size} bytes');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(minutes: 8)));
}

Future<void> _until(
    WidgetTester tester, Future<bool> Function() condition) async {
  final watch = Stopwatch()..start();
  while (!await condition()) {
    if (watch.elapsed > const Duration(minutes: 2)) {
      fail('Attachment operation timed out.');
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
