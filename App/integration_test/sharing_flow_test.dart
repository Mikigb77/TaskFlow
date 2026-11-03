// Real Android UI/SQLite and two JWT accounts on the local Docker backend.
// Credential storage is isolated; there are no AI, microphone or email calls.
import 'dart:io';
import 'package:agenda/providers/no_retry.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/repositories/cloud_task_repository.dart';
import 'package:agenda/screens/list_sharing_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/attachment_store.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/task_list_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../test/support/design_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'household invitations, two-person sync, role changes and file revocation',
      (tester) async {
    await TaskReminders.initialize();
    final originalOwner = await TaskReminders.engine.activeOwner();
    final database = TaskDatabase();
    final sql = await database.database;
    // Explicit recovery for a previously interrupted run, using only the IDs
    // printed by that test. Omitted in ordinary runs; never enumerate accounts.
    for (final id in const String.fromEnvironment('SHARING_CLEANUP_IDS')
        .split(',')
        .where((id) => RegExp(r'^\d+$').hasMatch(id))) {
      const base = String.fromEnvironment('API_BASE_URL',
          defaultValue: 'http://10.0.2.2:8088');
      final owner = '$base/users/$id';
      if (owner == originalOwner) {
        throw StateError('Refusing cleanup of the active reminder owner.');
      }
      final paths = await sql.query('task_attachments',
          columns: ['local_path'], where: 'owner_key = ?', whereArgs: [owner]);
      for (final table in [
        'tasks',
        'task_lists',
        'captures',
        'task_attachments'
      ]) {
        await sql.delete(table, where: 'owner_key = ?', whereArgs: [owner]);
      }
      await AttachmentStore(database, owner).cleanRemovedPaths(
          paths.map((row) => row['local_path']).whereType<String>());
      await sql.delete('app_preferences',
          where: 'scope IN (?, ?, ?)',
          whereArgs: [
            'reminders:$owner',
            'calendars:$owner',
            'sharing:$owner'
          ]);
    }
    const oldStamp = String.fromEnvironment('SHARING_CLEANUP_STAMP');
    if (RegExp(r'^\d+$').hasMatch(oldStamp)) {
      final oldSource = File(p.join(
          (await getTemporaryDirectory()).path, 'sharing-$oldStamp.txt'));
      if (await oldSource.exists()) await oldSource.delete();
    }
    FlutterSecureStorage.setMockInitialValues({});
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final a = ApiClient();
    final b = ApiClient();
    await a.signIn('sharing-android-$stamp-owner@example.invalid',
        'Sharing-fixture-only!2026',
        register: true);
    await b.signIn('sharing-android-$stamp-editor@example.invalid',
        'Sharing-fixture-only!2026',
        register: true);
    debugPrint(
        'SHARING_FIXTURE_ACCOUNTS: ${a.account!.id} ${a.account!.email}; ${b.account!.id} ${b.account!.email}');
    final ra = CloudTaskRepository(database, a, a.account!.id);
    final rb = CloudTaskRepository(database, b, b.account!.id);
    final list = TaskListInfo(name: 'Household fixture');
    final source = File(
        p.join((await getTemporaryDirectory()).path, 'sharing-$stamp.txt'));
    final containers = <ProviderContainer>[];
    ProviderContainer containerFor(
        ApiClient api, CloudTaskRepository repository) {
      final container = ProviderContainer(retry: noRetry, overrides: [
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) => _Auth(api)),
        taskRepositoryProvider.overrideWithValue(repository),
        regionalStoreProvider.overrideWithValue(MemoryRegionalStore()),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      ]);
      containers.add(container);
      return container;
    }

    addTearDown(() async {
      for (final container in containers) {
        container.dispose();
      }
      try {
        final current = await a.request('GET', 'lists/${list.id}/',
            accountId: a.account!.id) as Map;
        await a.request('DELETE', 'lists/${list.id}/',
            data: {'version': current['version']}, accountId: a.account!.id);
      } on ApiException catch (error) {
        if (error.status != 404) rethrow;
      }
      for (final repository in [ra, rb]) {
        final paths = await sql.query('task_attachments',
            columns: ['local_path'],
            where: 'owner_key = ?',
            whereArgs: [repository.ownerKey]);
        for (final table in [
          'tasks',
          'task_lists',
          'captures',
          'task_attachments'
        ]) {
          await sql.delete(table,
              where: 'owner_key = ?', whereArgs: [repository.ownerKey]);
        }
        await repository.attachments.cleanRemovedPaths(
            paths.map((row) => row['local_path']).whereType<String>());
        await sql
            .delete('app_preferences', where: 'scope IN (?, ?, ?)', whereArgs: [
          'reminders:${repository.ownerKey}',
          'calendars:${repository.ownerKey}',
          'sharing:${repository.ownerKey}'
        ]);
      }
      if (await source.exists()) await source.delete();
      await a.signOut();
      await b.signOut();
      a.close();
      b.close();
      await TaskReminders.activate(originalOwner ?? 'local');
    });
    await TaskListStore(database, ra.ownerKey).create(list);
    await ra.addTask(Task(
        title: 'Buy groceries',
        priority: 1,
        listId: list.id,
        checklist: [
          ChecklistItem(title: 'Milk'),
          ChecklistItem(title: 'Bread')
        ]));
    await ra.sync();
    final remoteTask = (await sql
            .query('tasks', where: 'owner_key = ?', whereArgs: [ra.ownerKey]))
        .single;
    await source.writeAsString('Recipe fixture: milk and bread.');
    await a.uploadAttachment(
        id: const Uuid().v4(),
        taskId: remoteTask['sync_id'] as String,
        name: 'Recipe.txt',
        filePath: source.path,
        accountId: a.account!.id);

    final ca = containerFor(a, ra);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: ca, child: const MyApp()));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).push(
        MaterialPageRoute<void>(
            builder: (_) => ListSharingScreen(listId: list.id)));
    await _until(
        tester,
        () async =>
            find.byKey(const ValueKey('invite-person')).evaluate().isNotEmpty);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('invite-person')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invite-person')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('invite-email')));
    await tester.enterText(
        find.byKey(const ValueKey('invite-email')), b.account!.email);
    await tester.tap(find.text('Send invitation'));
    await _until(
        tester,
        () async => find
            .byKey(const ValueKey('invitation-code'))
            .evaluate()
            .isNotEmpty);
    final code = tester
        .widget<SelectableText>(find.byKey(const ValueKey('invitation-code')))
        .data!;
    await tester.tap(find.text('Done'));
    await _until(
        tester,
        () async =>
            find.text(b.account!.email).evaluate().isNotEmpty &&
            find.byType(AlertDialog).evaluate().isEmpty);
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('sharing-owner-light');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final cb = containerFor(b, rb);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: cb, child: const MyApp()));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    // The invitation waits on Calendar; pasting the code joins.
    const invited = 'You’re invited to Household fixture · View';
    await _until(tester, () async => find.text(invited).evaluate().isNotEmpty);
    await tester.tap(find.text(invited));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('accept-invitation-code')), code);
    await tester.tap(find.text('Join'));
    await _until(tester, () async => (await rb.getAllTasks()).isNotEmpty);
    await cb.read(taskProvider.notifier).loadTasks();
    await tester.pumpAndSettle();
    expect((await TaskListStore(database, rb.ownerKey).all()).single.role,
        'editor');
    var shared = (await rb.getAllTasks()).single;
    final attachment = (await rb.attachments.forTask(shared.id!)).single;
    final downloaded =
        await rb.attachments.download(attachment.id, b, b.account!.id);
    expect(await File(downloaded).readAsString(), await source.readAsString());

    // Two edits use the same server version; one must be preserved privately.
    await rb.updateTask(shared.copyWith(notes: 'My unsent choice'));
    final ownerTask = (await ra.getAllTasks()).single;
    await ra.updateTask(ownerTask.copyWith(notes: 'Use the household recipe'));
    await ra.sync();
    await rb.sync();
    await rb.sync();
    final group =
        (await rb.getAllTasks()).where((task) => task.listId == list.id).single;
    expect(group.notes, 'Use the household recipe');
    expect(
        (await rb.getAllTasks())
            .where((task) => task.listId == null)
            .single
            .notes,
        'My unsent choice');
    await a.request('POST', 'lists/${list.id}/member/',
        data: {'user_id': b.account!.id, 'role': 'viewer'},
        accountId: a.account!.id);
    await cb.read(taskProvider.notifier).loadTasks();
    navigator.pushNamed('/taskDetails', arguments: group.id);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit task'), findsNothing);
    expect(find.byTooltip('Delete task'), findsNothing);
    await cb.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('sharing-viewer-dark');
    await a.request('POST', 'lists/${list.id}/member/',
        data: {'user_id': b.account!.id, 'role': 'remove'},
        accountId: a.account!.id);
    await cb.read(taskProvider.notifier).loadTasks();
    await tester.pumpAndSettle();
    expect(
        (await rb.getAllTasks()).every((task) => task.listId == null), isTrue);
    expect(await File(downloaded).exists(), isFalse);
    expect(await TaskListStore(database, rb.ownerKey).all(), isEmpty);
    await expectLater(
        b.downloadAttachment(attachment.id, accountId: b.account!.id),
        throwsA(isA<ApiException>()
            .having((error) => error.status, 'status', 404)));
    expect(find.text('Task unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugPrint(
        'SHARING_NATIVE_VALIDATED: UI invite/accept, two-account sync/conflict, authenticated bytes, viewer controls, revoked cache/files');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(minutes: 8)));
}

Future<void> _until(
    WidgetTester tester, Future<bool> Function() condition) async {
  final watch = Stopwatch()..start();
  while (!await condition()) {
    if (watch.elapsed > const Duration(minutes: 2)) {
      fail('Sharing operation timed out.');
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
