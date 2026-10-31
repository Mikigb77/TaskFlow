import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_attachment.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/archive_store.dart';
import 'package:agenda/services/attachment_files.dart';
import 'package:agenda/services/attachment_store.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/design_fixtures.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late TaskDatabase database;
  late AttachmentFiles files;
  late AttachmentStore store;
  late _FilesApi api;
  const owner = 'http://files.test/users/1';
  Future<int> task(String path) async {
    final id = await database.insertTask(
        Task(title: 'Doctor', priority: 3, filePaths: [path]),
        ownerKey: owner);
    await (await database.database).update(
        'tasks', {'remote_version': 1, 'sync_pending': 0},
        where: 'id = ?', whereArgs: [id]);
    return id;
  }

  setUp(() async {
    directory =
        await Directory.systemTemp.createTemp('taskflow-attachment-store-');
    final sql = await databaseFactoryFfi
        .openDatabase(p.join(directory.path, 'data.db'));
    await sql.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)');
    await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
    database = TaskDatabase.forTesting(sql);
    files =
        AttachmentFiles(directory: Directory(p.join(directory.path, 'owned')));
    store = AttachmentStore(database, owner, files: files);
    api = _FilesApi();
  });
  tearDown(() async {
    await database.close();
    api.close();
    expect(p.isWithin(Directory.systemTemp.path, directory.path), isTrue);
    await directory.delete(recursive: true);
  });

  test(
      'saved queue survives restart and response loss without duplicate uploads',
      () async {
    final source = File(p.join(directory.path, 're\u0301sults.pdf'));
    await source.writeAsBytes([1, 2, 255, 4]);
    final id = await task(source.path);
    final queuedId = (await store.forTask(id)).single.id;
    api.loseResponse = true;
    api.failList = true;
    await expectLater(store.sync(api, 1), throwsA(isA<ApiException>()));
    expect(api.records.length, 1);
    expect((await store.forTask(id)).single.uploadPending, isTrue);
    await database.close();
    database = TaskDatabase.forTesting(await databaseFactoryFfi
        .openDatabase(p.join(directory.path, 'data.db')));
    store = AttachmentStore(database, owner, files: files);
    api.failList = false;
    await store.sync(api, 1);
    final saved = (await store.forTask(id)).single;
    expect(saved.id, queuedId);
    expect(saved.name, 'résults.pdf');
    expect(saved.remote, isTrue);
    expect(saved.uploadPending, isFalse);
    expect(saved.error, isNull);
    expect(api.uploadIds, [queuedId, queuedId]);
    expect(api.records.length, 1);
    expect(await File(saved.localPath!).readAsBytes(), [1, 2, 255, 4]);
    expect(await source.exists(), isTrue);
    final row = (await (await database.database)
            .query('tasks', where: 'id = ?', whereArgs: [id]))
        .single;
    expect(row['remote_version'], 1);
    expect(row['revision'], 0);
  });

  test(
      'fresh cache restores metadata, validates download and exports names only',
      () async {
    final source = File(p.join(directory.path, 'results.pdf'));
    await source.writeAsBytes([0, 8, 255, 11]);
    final id = await task(source.path);
    await store.sync(api, 1);
    final saved = (await store.forTask(id)).single;
    await files.removeOwned(saved.localPath!);
    final db = await database.database;
    await db
        .delete('task_attachments', where: 'owner_key = ?', whereArgs: [owner]);
    await db.update('tasks', {'filePaths': null},
        where: 'id = ?', whereArgs: [id]);
    await store.sync(api, 1);
    var restored = (await store.forTask(id)).single;
    expect(restored.localPath, isNull);
    expect(restored.remote, isTrue);
    api.corrupt = true;
    await expectLater(
        store.download(restored.id, api, 1), throwsFormatException);
    expect((await store.forTask(id)).single.localPath, isNull);
    api.corrupt = false;
    final downloaded = await store.download(restored.id, api, 1);
    expect(await File(downloaded).readAsBytes(), [0, 8, 255, 11]);
    restored = (await store.forTask(id)).single;
    expect(restored.error, isNull);
    final archive = await ArchiveStore(database, owner).export();
    expect(archive, contains('results.pdf'));
    expect(archive, isNot(contains(directory.path.replaceAll('\\', '\\\\'))));
    expect(
        await AttachmentStore(database, 'http://files.test/users/2',
                files: files)
            .forTask(id),
        isEmpty);
    await expectLater(
        AttachmentStore(database, 'http://files.test/users/2', files: files)
            .download(saved.id, api, 2),
        throwsStateError);
  });

  test(
      'deletion during upload cannot resurrect the file and never deletes originals',
      () async {
    final source = File(p.join(directory.path, 'appointment.txt'));
    await source.writeAsString('bring results');
    final id = await task(source.path);
    api.uploadWait = Completer<void>();
    final syncing = store.sync(api, 1);
    await api.uploadStarted.future;
    final item = (await store.forTask(id)).single;
    await store.remove(item.id);
    expect((await store.forTask(id)).single.deletePending, isTrue);
    api.uploadWait!.complete();
    await syncing;
    expect(await store.forTask(id), isEmpty);
    expect(api.records[item.id]!['is_deleted'], isTrue);
    expect(
        (await database.getTasks(ownerKey: owner)).single.filePaths, isEmpty);
    expect(await source.readAsString(), 'bring results');
    expect(await File(item.localPath!).exists(), isFalse);
  });

  test('failed removal is visible and retries without uploading again',
      () async {
    final source = File(p.join(directory.path, 'receipt.txt'));
    await source.writeAsString('receipt');
    final id = await task(source.path);
    await store.sync(api, 1);
    final item = (await store.forTask(id)).single;
    await store.remove(item.id);
    api.failDelete = true;
    await store.sync(api, 1);
    final pending = (await store.forTask(id)).single;
    expect(pending.deleted, isTrue);
    expect(pending.deletePending, isTrue);
    expect(pending.error, isNotNull);
    expect(api.uploadIds.length, 1);
    api.failDelete = false;
    await store.sync(api, 1);
    expect(await store.forTask(id), isEmpty);
    expect(api.uploadIds.length, 1);
  });

  test(
      'guest imports stay device-only until explicit backup and missing files remain errors',
      () async {
    final source = File(p.join(directory.path, 'legacy.txt'));
    await source.writeAsString('legacy');
    final id = await database.insertTask(
        Task(title: 'Old task', priority: 1, filePaths: [source.path]));
    await database.importLocalTasks(owner);
    await (await database.database).update('tasks', {'remote_version': 1},
        where: 'id = ?', whereArgs: [id]);
    await store.sync(api, 1);
    expect(api.records, isEmpty);
    await Future.wait(
        [store.enqueue(id, source.path), store.enqueue(id, source.path)]);
    expect((await store.forTask(id)).length, 1);
    await store.sync(api, 1);
    expect(api.records.length, 1);
    final missing = await task(p.join(directory.path, 'missing.pdf'));
    await store.sync(api, 1);
    expect((await store.forTask(missing)).single.uploadPending, isTrue);
    expect((await store.forTask(missing)).single.error, isNotNull);
    expect((await database.getTasks(ownerKey: owner)).length, 2);
  });

  test(
      'export keeps separate same-name files without counting local paths twice',
      () async {
    final paths = <String>[];
    for (final folder in ['first', 'second']) {
      final file = File(p.join(directory.path, folder, 'results.txt'));
      await file.parent.create();
      await file.writeAsString(folder);
      paths.add(file.path);
    }
    final id = await database.insertTask(
        Task(title: 'Results', priority: 2, filePaths: paths),
        ownerKey: owner);
    await (await database.database).update('tasks', {'remote_version': 1},
        where: 'id = ?', whereArgs: [id]);
    await store.sync(api, 1);
    expect((await store.forTask(id)).length, 2);
    final archive = jsonDecode(await ArchiveStore(database, owner).export());
    expect(
        archive['tasks'].single['attachments'], ['results.txt', 'results.txt']);
  });

  test('remote removal revokes cached references without changing task version',
      () async {
    final source = File(p.join(directory.path, 'owned-original.txt'));
    await source.writeAsString('original');
    final retained = await files.retain(source.path);
    final id = await task(retained);
    await store.sync(api, 1);
    final saved = (await store.forTask(id)).single;
    api.records[saved.id]!['is_deleted'] = true;
    await store.sync(api, 1);
    expect(await store.forTask(id), isEmpty);
    expect(
        (await database.getTasks(ownerKey: owner)).single.filePaths, isEmpty);
    expect(await File(retained).exists(), isFalse);
    expect(await source.exists(), isTrue);
    final row = (await (await database.database)
            .query('tasks', where: 'id = ?', whereArgs: [id]))
        .single;
    expect(row['remote_version'], 1);
    expect(row['revision'], 0);
  });

  test(
      'file retention is bounded and unsafe download identities cannot escape storage',
      () async {
    final empty = File(p.join(directory.path, 'empty.txt'));
    await empty.writeAsBytes([]);
    await expectLater(files.retain(empty.path), throwsFormatException);
    final large = File(p.join(directory.path, 'large.txt'));
    final handle = await large.open(mode: FileMode.write);
    await handle.truncate(TaskAttachment.maxBytes + 1);
    await handle.close();
    await expectLater(files.retain(large.path), throwsFormatException);
    expect(await files.owns(empty.path), isFalse);
    await files.removeOwned(empty.path);
    expect(await empty.exists(), isTrue);
    await expectLater(
        files.downloaded(
            owner,
            TaskAttachment(
                id: '../../escape',
                taskId: 'bad',
                name: 'bad.txt',
                size: 1,
                sha256: sha256.convert([0]).toString()),
            Uint8List.fromList([0])),
        throwsFormatException);
  });

  // ---- P91 · UX-500: a file refused for a full file space ----

  const megabyte = 1024 * 1024;
  Map<String, dynamic> full({bool shared = false}) => {
        'code': 'storage_full',
        'shared': shared,
        if (!shared)
          'storage': {
            'used_bytes': 100 * 1024 * 1024,
            'limit_bytes': 100 * 1024 * 1024
          },
      };

  for (final shared in [false, true]) {
    test(
        'UX-500: a storage_full answer (shared: $shared) marks the file refused with the ${shared ? 'shared' : 'own'} token, not the server’s text; the next sync doesn’t re-send it; its Retry does',
        () async {
      final source = File(p.join(directory.path, 'scan.pdf'));
      await source.writeAsBytes([1, 2, 3]);
      final id = await task(source.path);
      api.storageFull = full(shared: shared);
      await store.sync(api, 1);
      var item = (await store.forTask(id)).single;
      expect(api.uploadIds, hasLength(1));
      expect(item.refused, isTrue);
      expect(
          item.error,
          shared
              ? TaskAttachment.storageFullShared
              : TaskAttachment.storageFull);
      expect(item.error, isNot(contains('full.')));
      expect(item.uploadPending, isTrue);

      // A task change syncs again: the refused file is not sent.
      await store.sync(api, 1);
      await store.sync(api, 1);
      expect(api.uploadIds, hasLength(1));

      // Its Retry sends it again.
      api.storageFull = null;
      await store.retryRefused(item.id);
      await store.sync(api, 1);
      expect(api.uploadIds, hasLength(2));
      item = (await store.forTask(id)).single;
      expect(item.refused, isFalse);
      expect(item.error, isNull);
      expect(item.remote, isTrue);
      expect(item.uploadPending, isFalse);
    });
  }

  test(
      'UX-500: removing a file re-sends the refused ones on the next sync, after the removal',
      () async {
    final kept = File(p.join(directory.path, 'kept.pdf'));
    await kept.writeAsBytes([1]);
    final keptTask = await task(kept.path);
    await store.sync(api, 1);
    final uploaded = (await store.forTask(keptTask)).single;
    expect(uploaded.remote, isTrue);

    final big = File(p.join(directory.path, 'big.pdf'));
    await big.writeAsBytes([2, 2]);
    final bigTask = await task(big.path);
    api.storageFull = full();
    await store.sync(api, 1);
    expect((await store.forTask(bigTask)).single.refused, isTrue);
    expect(api.uploadIds, hasLength(2));
    await store.sync(api, 1);
    expect(api.uploadIds, hasLength(2));

    api.storageFull = null;
    await store.remove(uploaded.id);
    await store.sync(api, 1);
    expect(api.records[uploaded.id]!['is_deleted'], isTrue);
    expect(api.uploadIds, hasLength(3));
    final sent = (await store.forTask(bigTask)).single;
    expect(sent.refused, isFalse);
    expect(sent.remote, isTrue);
  });

  test('UX-500: when Pro turns on, every refused file is sent again',
      () async {
    final ids = <int>[];
    for (final name in ['one.pdf', 'two.pdf']) {
      final source = File(p.join(directory.path, name));
      await source.writeAsBytes([3]);
      ids.add(await task(source.path));
    }
    api.storageFull = full();
    await store.sync(api, 1);
    expect(api.uploadIds, hasLength(2));
    await store.sync(api, 1);
    expect(api.uploadIds, hasLength(2));
    api.storageFull = null;
    // What the app runs when hasPro turns on (main.dart).
    await store.retryRefused();
    await store.sync(api, 1);
    expect(api.uploadIds, hasLength(4));
    for (final id in ids) {
      expect((await store.forTask(id)).single.remote, isTrue);
    }
  });

  // ---- Round 2 · P95 · UX-505: the usage refreshes after an upload ----

  Map<String, dynamic> usage(int usedMb) =>
      {'used_bytes': usedMb * megabyte, 'limit_bytes': 100 * megabyte};

  /// A free account saved on the phone at [usedMb] of 100 MB.
  Future<void> saveAccount(int usedMb) async {
    FlutterSecureStorage.setMockInitialValues({
      'taskflow.session': jsonEncode({
        'access': 'fixture-access',
        'refresh': 'fixture-refresh',
        'user': {
          'id': 1,
          'email': 'files@example.invalid',
          'timezone': 'UTC',
          'storage': usage(usedMb),
        },
      }),
    });
    api.saved = true;
    await api.restore();
    expect(api.account!.storage!.usedBytes, usedMb * megabyte);
  }

  test(
      'UX-505: a sync with a successful upload asks auth/me/ once and saves its storage; the sync that follows the account update asks nothing',
      () async {
    await saveAccount(78);
    var updates = 0;
    final listening = api.accountUpdated.listen((_) => updates++);
    addTearDown(listening.cancel);
    api.me = usage(82);
    final source = File(p.join(directory.path, 'photo.jpg'));
    await source.writeAsBytes([1, 2, 3]);
    final id = await task(source.path);
    await store.sync(api, 1);
    expect((await store.forTask(id)).single.remote, isTrue);
    expect(api.meRequests, 1);
    expect(api.account!.storage!.usedBytes, 82 * megabyte);
    await Future<void>.delayed(Duration.zero);
    expect(updates, greaterThanOrEqualTo(1), reason: 'the app hears of it');

    // An account update no longer rebuilds the repository or starts a sync;
    // a later sync that uploads nothing asks auth/me/ nothing.
    await store.sync(api, 1);
    expect(api.meRequests, 1);
  });

  test(
      'UX-505: a sync where nothing uploads — nothing queued, or the only file refused — asks auth/me/ nothing',
      () async {
    await saveAccount(78);
    api.me = usage(82);
    await store.sync(api, 1);
    expect(api.meRequests, 0, reason: 'nothing queued');

    final source = File(p.join(directory.path, 'big.pdf'));
    await source.writeAsBytes([4, 5]);
    final id = await task(source.path);
    api.storageFull = full();
    await store.sync(api, 1);
    expect((await store.forTask(id)).single.refused, isTrue);
    expect(api.meRequests, 0, reason: 'the only file was refused');
    await store.sync(api, 1);
    expect(api.meRequests, 0);
  });

  testWidgets(
      'UX-505: after an upload, the attachment panel shows Files: 82 of 100 MB used without reopening the task, from one auth/me/ request',
      (tester) async {
    final en = lookupAppLocalizations(const Locale('en'));
    await tester.runAsync(() => saveAccount(78));
    api.me = usage(82);
    final source = File(p.join(directory.path, 'scan.pdf'));
    final id = (await tester.runAsync(() async {
      await source.writeAsBytes([7, 8, 9]);
      return task(source.path);
    }))!;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authProvider.overrideWith((ref) => _SavedAuth(api)),
          hasProProvider.overrideWithValue(false),
          taskRepositoryProvider.overrideWithValue(MemoryTasks()),
          taskProvider.overrideWith((ref) => DesignTaskNotifier()),
          attachmentEntriesProvider.overrideWith((ref, taskId) async =>
              [AttachmentEntry('scan.pdf', source.path, true)]),
        ],
        child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: AttachmentPanel(
                        task: Task(
                            id: id, title: 'Doctor', priority: 3)))))));
    await tester.pumpAndSettle();
    expect(find.text('scan.pdf'), findsOneWidget);
    // 78% is under the line's 80%.
    expect(find.text(en.storageUsage(78, 100)), findsNothing);
    expect(find.text(en.storageUsage(82, 100)), findsNothing);

    await tester.runAsync(() => store.sync(api, 1));
    await tester.pumpAndSettle();
    expect(find.text(en.storageUsage(82, 100)), findsOneWidget);
    expect(find.text('Files: 82 of 100 MB used'), findsOneWidget);
    expect(api.meRequests, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// The account restored from the session saved on the phone.
class _SavedAuth extends AuthNotifier {
  _SavedAuth(super.api);
  @override
  Future<void> restore() async {
    if (mounted) state = AuthState(account: api.account);
  }
}

class _FilesApi extends ApiClient {
  _FilesApi() : super(url: 'http://files.test');

  /// When true, the account is the session saved on the phone (restored
  /// through the mocked secure storage), as in the app.
  bool saved = false;
  @override
  Account? get account => saved
      ? super.account
      : Account.fromJson(
          {'id': 1, 'email': 'files@example.invalid', 'timezone': 'UTC'});

  /// Every `GET auth/me/`; it answers [me] as the account's file space.
  int meRequests = 0;
  Map<String, dynamic>? me;
  final records = <String, Map<String, dynamic>>{};
  final bytes = <String, Uint8List>{};
  final uploadIds = <String>[];
  bool loseResponse = false,
      failList = false,
      corrupt = false,
      failDelete = false;
  Completer<void>? uploadWait;
  final uploadStarted = Completer<void>();

  /// When set, every upload is refused with this 400 body.
  Map<String, dynamic>? storageFull;

  @override
  Future<Map<String, dynamic>> uploadAttachment(
      {required String id,
      required String taskId,
      required String name,
      required String filePath,
      required int accountId}) async {
    expect(accountId, 1);
    uploadIds.add(id);
    final full = storageFull;
    if (full != null) {
      throw ApiException(400, 'Your file space is full.', full);
    }
    bytes[id] = await File(filePath).readAsBytes();
    records[id] = {
      'id': id,
      'task_id': taskId,
      'name': name.replaceAll('e\u0301', 'é'),
      'size': bytes[id]!.length,
      'sha256': sha256.convert(bytes[id]!).toString(),
      'is_deleted': false
    };
    if (!uploadStarted.isCompleted) uploadStarted.complete();
    if (uploadWait != null) await uploadWait!.future;
    if (loseResponse) {
      loseResponse = false;
      throw ApiException(503, 'Response lost.');
    }
    return records[id]!;
  }

  @override
  Future<Uint8List> downloadAttachment(String id,
      {required int accountId}) async {
    expect(accountId, 1);
    return corrupt ? Uint8List.fromList([9]) : bytes[id]!;
  }

  @override
  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? data,
      String? audioPath,
      bool authenticated = true,
      int? accountId}) async {
    expect(accountId, 1);
    if (method == 'GET' && path == 'auth/me/') {
      meRequests++;
      return {
        'id': 1,
        'email': 'files@example.invalid',
        'timezone': 'UTC',
        if (me != null) 'storage': me,
      };
    }
    if (method == 'GET') {
      if (failList) throw ApiException(503, 'Metadata unavailable.');
      return {'results': records.values.toList(), 'next': null};
    }
    if (method == 'DELETE') {
      if (failDelete) throw ApiException(503, 'Removal unavailable.');
      final id = path.split('/')[1];
      records[id]?['is_deleted'] = true;
      return null;
    }
    throw StateError('Unexpected request $method $path');
  }
}
