import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/repositories/cloud_task_repository.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/attachment_files.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/task_list_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const listId = '81111111-1111-4111-8111-111111111111';
const taskId = '82222222-2222-4222-8222-222222222222';
const fileId = '83333333-3333-4333-8333-333333333333';

void main() {
  sqfliteFfiInit();
  late TaskDatabase database;
  late _SharingApi api;
  late CloudTaskRepository repository;
  late TaskListStore store;
  late Directory directory;
  late AttachmentFiles files;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('taskflow-sharing-');
    final sql = await databaseFactoryFfi
        .openDatabase(p.join(directory.path, 'data.db'));
    await sql.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)');
    await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
    database = TaskDatabase.forTesting(sql);
    api = _SharingApi();
    repository = CloudTaskRepository(database, api, 1);
    files =
        AttachmentFiles(directory: Directory(p.join(directory.path, 'owned')));
    store = TaskListStore(database, repository.ownerKey, files: files);
    await repository.sync();
  });
  tearDown(() async {
    await database.close();
    api.close();
    expect(p.isWithin(Directory.systemTemp.path, directory.path), isTrue);
    await directory.delete(recursive: true);
  });

  test(
      'cached viewer rules cover new, edited, completed, moved and deleted tasks',
      () async {
    api.role = 'viewer';
    await repository.sync();
    final task = (await repository.getAllTasks()).single;
    expect((await store.all()).single.canEdit, isFalse);
    await expectLater(
        repository.addTask(Task(title: 'Blocked', priority: 1, listId: listId)),
        throwsStateError);
    await expectLater(repository.updateTask(task.copyWith(isCompleted: true)),
        throwsStateError);
    await expectLater(
        repository.updateTask(task.copyWith(listId: null)), throwsStateError);
    await expectLater(repository.deleteTask(task.id!), throwsStateError);
    expect(await database.pending(repository.ownerKey), isEmpty);
    api.role = 'editor';
    await repository.sync();
    await expectLater(
        repository.updateTask(task.copyWith(listId: null)), throwsStateError);
  });

  test(
      'role downgrade restores shared state and preserves unsent work privately',
      () async {
    var task = (await repository.getAllTasks()).single;
    await repository.updateTask(task.copyWith(title: 'Offline milk choice'));
    await repository
        .addTask(Task(title: 'Unsent bread', priority: 1, listId: listId));
    api.role = 'viewer';
    await repository.sync();
    final rows = await repository.getAllTasks();
    expect(rows.singleWhere((item) => item.listId == listId).title, 'Buy milk');
    expect(rows.where((item) => item.listId == null).map((item) => item.title),
        containsAll(['Offline milk choice (offline copy)', 'Unsent bread']));
    await repository.sync();
    expect(await database.pending(repository.ownerKey), isEmpty);
    expect(api.writes.every((payload) => payload['list_id'] == null), isTrue);
    expect(api.tasks[taskId]!['title'], 'Buy milk');
  });

  test(
      'failed or partial access cannot erase data; revocation scopes cleanup and preserves source files',
      () async {
    final owner = repository.ownerKey;
    final task = (await repository.getAllTasks()).single;
    await repository.updateTask(task.copyWith(title: 'Unsent shared edit'));
    await database.insertTask(Task(title: 'Private task', priority: 1),
        ownerKey: owner);
    await database.insertTask(Task(title: 'Other account', priority: 1),
        ownerKey: 'other');
    final source = File(p.join(directory.path, 'source.txt'));
    await source.writeAsString('Recipe');
    final retained = await files.retain(source.path);
    await (await database.database).insert('task_attachments', {
      'id': fileId,
      'owner_key': owner,
      'task_id': taskId,
      'name': 'Recipe.txt',
      'remote': 1,
      'local_path': retained,
      'source_path': source.path
    });
    api.offline = true;
    await expectLater(
        store.refreshAccess(api, 1), throwsA(isA<ApiException>()));
    api.offline = false;
    api.malformed = true;
    await expectLater(
        store.refreshAccess(api, 1), throwsA(isA<FormatException>()));
    expect((await repository.getAllTasks()).length, 2);
    expect(await File(retained).exists(), isTrue);
    api.malformed = false;
    api.visible = false;
    await store.refreshAccess(api, 1);
    expect((await repository.getAllTasks()).single.title, 'Private task');
    expect((await database.getTasks(ownerKey: 'other')).single.title,
        'Other account');
    expect(await store.all(), isEmpty);
    expect(await File(retained).exists(), isFalse);
    expect(await source.exists(), isTrue);
    expect(
        await (await database.database).query('task_attachments',
            where: 'owner_key = ?', whereArgs: [owner]),
        isEmpty);
    await expectLater(repository.updateTask(task), throwsStateError);
  });

  test('an older in-flight access snapshot cannot resurrect a revoked list',
      () async {
    api.hold = Completer<void>();
    final started = api.started = Completer<void>();
    final old = store.refreshAccess(api, 1);
    await started.future;
    api.visible = false;
    await store.refreshAccess(api, 1);
    api.hold!.complete();
    await old;
    expect(await store.all(), isEmpty);
    expect(await repository.getAllTasks(), isEmpty);
    await database.mergeRemote(repository.ownerKey, api.tasks[taskId]!);
    expect(await repository.getAllTasks(), isEmpty,
        reason: 'A late task page cannot restore revoked shared contents.');
  });

  test(
      'cross-user conflicts keep a personal copy without duplicating the group task',
      () async {
    final task = (await repository.getAllTasks()).single;
    await repository.updateTask(task.copyWith(title: 'My offline edit'));
    api.tasks[taskId] = {
      ...api.tasks[taskId]!,
      'title': 'Someone else edited',
      'version': 2
    };
    await repository.sync();
    await repository.sync();
    final rows = await repository.getAllTasks();
    expect(rows.where((item) => item.listId == listId).single.title,
        'Someone else edited');
    expect(rows.where((item) => item.listId == null).single.title,
        'My offline edit (offline copy)');
    expect(
        api.tasks.values.where((item) => item['list_id'] == listId).length, 1);
  });

  test(
      'schema 13 lists migrate to private owner access without losing identity',
      () async {
    final old = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(old.close);
    await old
        .execute('CREATE TABLE task_lists(id TEXT, name TEXT, owner_key TEXT)');
    await old.insert(
        'task_lists', {'id': listId, 'name': 'Original', 'owner_key': 'local'});
    await TaskDatabase.upgrade(old, 13, 14);
    final row = (await old.query('task_lists')).single;
    expect(row, {
      'id': listId,
      'name': 'Original',
      'owner_key': 'local',
      'role': 'owner',
      'shared': 0
    });
  });

  // ---- 2026-10-28-app · P271 (UX-2032, UX-2403, D9): a reader's own
  // reminders are sent, and nothing a reader does becomes a copy ----

  group('P271 · a reader’s reminders sync', () {
    late _ReaderApi reader;
    setUp(() async {
      // The same server, now answering as D9's does (bc80025).
      api.close();
      api = reader = _ReaderApi();
      // As the real server sends every task: with is_deleted.
      reader.tasks[taskId] = {...reader.tasks[taskId]!, 'is_deleted': false};
      repository = CloudTaskRepository(database, api, 1);
      store = TaskListStore(database, repository.ownerKey, files: files);
      reader.role = 'viewer';
      await repository.sync();
      expect((await store.all()).single.canEdit, isFalse);
      expect(await database.pending(repository.ownerKey), isEmpty);
    });

    Future<List<Task>> tasks() => repository.getAllTasks();

    test(
      'UX-2032: a reader’s reminders-only change is sent with PUT at the server’s version and fields; on 200 it is acknowledged, with no copy and no notice',
      () async {
        final task = (await tasks()).single;
        await repository.updateOwnReminders(task.id!, minutes: 60);
        expect(await database.pending(repository.ownerKey), hasLength(1));
        expect((await tasks()).single.reminderMinutes, 60);

        await repository.sync();
        expect(reader.puts, hasLength(1));
        final sent = reader.puts.single;
        expect(sent['version'], 1, reason: 'the server’s version');
        expect(sent['title'], 'Buy milk');
        expect(sent['list_id'], listId);
        expect(sent['reminder_minutes'], 60);
        expect(reader.answers, [200]);
        expect(reader.own['reminder_minutes'], 60);
        expect(reader.tasks[taskId]!['version'], 1, reason: 'no new version');

        expect(await database.pending(repository.ownerKey), isEmpty);
        final rows = await tasks();
        expect(rows, hasLength(1), reason: 'no personal copy');
        expect(rows.single.listId, listId);
        expect(rows.single.reminderMinutes, 60);
        expect(repository.syncError, isNull, reason: 'no notice');

        // Nothing is left to send.
        await repository.sync();
        expect(reader.puts, hasLength(1));
        expect(repository.syncError, isNull);
      },
    );

    test(
      'UX-2032: when the owner changed the task meanwhile and the server answers 409 with current, the task becomes current with the reader’s reminders kept; no copy, no notice',
      () async {
        final task = (await tasks()).single;
        await repository.updateOwnReminders(task.id!, minutes: 60);
        // The owner renames it between this phone's read and its PUT.
        reader.beforePut = () => reader.tasks[taskId] = {
          ...reader.tasks[taskId]!,
          'title': 'Buy oat milk',
          'version': 2,
        };
        await repository.sync();
        expect(reader.answers, [409]);
        expect(reader.own['reminder_minutes'], 60, reason: 'saved first');

        expect(await database.pending(repository.ownerKey), isEmpty);
        final rows = await tasks();
        expect(rows, hasLength(1), reason: 'no personal copy');
        expect(rows.single.title, 'Buy oat milk');
        expect(rows.single.listId, listId);
        expect(rows.single.reminderMinutes, 60);
        expect(rows.where((t) => t.listId == null), isEmpty);
        expect(repository.syncError, isNull, reason: 'no notice');
        final row = (await (await database.database).query(
          'tasks',
          where: 'id = ?',
          whereArgs: [task.id],
        )).single;
        expect(row['remote_version'], 2);

        await repository.sync();
        expect(reader.puts, hasLength(1), reason: 'nothing is sent again');
        expect(repository.syncError, isNull);
      },
    );

    test(
      'UX-2032: a reader’s pending row equal to the server’s (a reminder set, then Deshacer) is acknowledged with no PUT, no copy and no notice',
      () async {
        final task = (await tasks()).single;
        await repository.updateOwnReminders(task.id!, minutes: 60);
        await repository.updateOwnReminders(
          task.id!,
          minutes: task.reminderMinutes,
          time: task.reminderTime,
          plan: task.reminderPlan,
        );
        expect(await database.pending(repository.ownerKey), hasLength(1));
        await repository.sync();
        expect(reader.puts, isEmpty);
        expect(await database.pending(repository.ownerKey), isEmpty);
        final rows = await tasks();
        expect(rows, hasLength(1));
        expect(rows.single.title, 'Buy milk');
        expect(repository.syncError, isNull);
      },
    );

    test(
      'UX-2403: a pending row equal to the server’s, as an old «Completar» then Deshacer left it, is acknowledged with no copy and no notice',
      () async {
        final task = (await tasks()).single;
        final sql = await database.database;
        await sql.update(
          'tasks',
          {'isCompleted': 1, 'sync_pending': 1, 'revision': 2},
          where: 'id = ?',
          whereArgs: [task.id],
        );
        await sql.update(
          'tasks',
          {'isCompleted': 0, 'revision': 3},
          where: 'id = ?',
          whereArgs: [task.id],
        );
        await repository.sync();
        expect(reader.puts, isEmpty);
        expect(await database.pending(repository.ownerKey), isEmpty);
        final rows = await tasks();
        expect(rows, hasLength(1), reason: 'no «(offline copy)»');
        expect(rows.single.isCompleted, isFalse);
        expect(repository.syncError, isNull);
      },
    );

    test(
      'UX-2032: a reader’s row that changes the title still behaves as today: the shared task is restored, the edit kept as a personal copy, with the notice',
      () async {
        // An edit made while still an editor, sent after becoming a reader.
        reader.role = 'editor';
        await repository.sync();
        final task = (await tasks()).single;
        await repository.updateTask(task.copyWith(title: 'Offline milk'));
        reader.role = 'viewer';
        await repository.sync();
        expect(reader.puts, isEmpty);
        final rows = await tasks();
        expect(rows.singleWhere((t) => t.listId == listId).title, 'Buy milk');
        expect(rows.where((t) => t.listId == null).map((t) => t.title), [
          'Offline milk '
              '${lookupAppLocalizations(const Locale('en')).syncCopySuffix}',
        ]);
        expect(repository.syncError, isNotNull);
        expect(reader.tasks[taskId]!['title'], 'Buy milk');
      },
    );
  });

  // ---- P271 (UX-2403): the copies still kept for an editor's conflict are
  // named in the app's language ----

  group('P271 · a conflict copy’s name', () {
    for (final language in ['es', 'ca', 'en']) {
      test(
        'UX-2403: an editor’s conflict copy is titled «Comprar pan ${lookupAppLocalizations(Locale(language)).syncCopySuffix}» ($language)',
        () async {
          await RegionalPreferenceStore(
            database,
          ).write(RegionalPreferences(language: language));
          final task = (await repository.getAllTasks()).single;
          await repository.updateTask(task.copyWith(title: 'Comprar pan'));
          api.tasks[taskId] = {
            ...api.tasks[taskId]!,
            'title': 'Someone else edited',
            'version': 2,
          };
          await repository.sync();
          final l = lookupAppLocalizations(Locale(language));
          final rows = await repository.getAllTasks();
          expect(
            rows.where((item) => item.listId == null).single.title,
            'Comprar pan ${l.syncCopySuffix}',
          );
          expect(
            rows.where((item) => item.listId == listId).single.title,
            'Someone else edited',
          );
        },
      );
    }

    test('UX-2403: the suffix in the three catalogs', () {
      expect(
        lookupAppLocalizations(const Locale('es')).syncCopySuffix,
        '(copia local)',
      );
      expect(
        lookupAppLocalizations(const Locale('ca')).syncCopySuffix,
        '(còpia local)',
      );
      expect(
        lookupAppLocalizations(const Locale('en')).syncCopySuffix,
        '(offline copy)',
      );
    });
  });
}

class _SharingApi extends ApiClient {
  _SharingApi() : super(url: 'http://sharing.test');
  String role = 'editor';
  bool visible = true, offline = false, malformed = false;
  Completer<void>? hold, started;
  final writes = <Map<String, dynamic>>[];
  final tasks = <String, Map<String, dynamic>>{
    taskId: {
      ...Task(title: 'Buy milk', priority: 1, listId: listId).toApi(),
      'id': taskId,
      'version': 1
    }
  };
  dynamic clone(dynamic data) => jsonDecode(jsonEncode(data));
  @override
  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? data,
      String? audioPath,
      bool authenticated = true,
      int? accountId}) async {
    if (offline) throw ApiException(0, 'Offline');
    if (path == 'lists/access/') {
      if (malformed) return {'results': [], 'next': '/page2'};
      final result = {
        'lists': visible
            ? [
                {
                  'id': listId,
                  'name': 'Household',
                  'color': 'teal',
                  'archived': false,
                  'version': 1,
                  'role': role,
                  'shared': true
                }
              ]
            : []
      };
      if (started?.isCompleted == false) {
        started!.complete();
        await hold!.future;
      }
      return result;
    }
    if (path.startsWith('attachments/')) return {'results': [], 'next': null};
    if (method == 'GET' && path.startsWith('tasks/?')) {
      return {
        'results': clone(tasks.values
            .where((item) => visible || item['list_id'] == null)
            .toList()),
        'next': null
      };
    }
    final id = path.split('/')[1];
    if (method == 'GET') return clone(tasks[id]);
    if (!visible && data?['list_id'] != null) {
      throw ApiException(404, 'Revoked');
    }
    if (role == 'viewer' && data?['list_id'] != null) {
      throw ApiException(403, 'Read-only');
    }
    if (tasks.containsKey(id) && tasks[id]!['version'] != data!['version']) {
      throw ApiException(409, 'Conflict', {'current': clone(tasks[id])});
    }
    writes.add(clone(data));
    final next = {...data!, 'id': id, 'version': (data['version'] as int) + 1};
    tasks[id] = clone(next);
    return next;
  }
}
/// The server as D9 has it (bc80025, Backend/docs/REMINDER_PLANS.md): a
/// reader's `PUT` whose other fields leave the task as it is saves their own
/// reminders, with no new version, and answers 200 with the task; with a
/// stale version it saves them first, then answers 409 with `current`; any
/// other change from a reader is refused with 403. Every answer carries this
/// account's own reminders.
class _ReaderApi extends _SharingApi {
  static const reminderKeys = {
    'reminder_minutes',
    'reminder_time',
    'reminder_anchor',
    'reminder_plan',
  };

  /// This account's own reminders on [taskId].
  final own = <String, dynamic>{};

  /// What a reader sent with `PUT`, and the status each one got.
  final puts = <Map<String, dynamic>>[];
  final answers = <int>[];

  /// Runs just before a `PUT` is answered, e.g. the owner's own change.
  void Function()? beforePut;

  Map<String, dynamic> _view(Map<String, dynamic> task) =>
      task['id'] == taskId ? {...task, ...clone(own)} : task;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    if (method == 'PUT' &&
        path.startsWith('tasks/') &&
        role == 'viewer' &&
        data?['list_id'] != null) {
      puts.add(clone(data));
      final id = path.split('/')[1];
      beforePut?.call();
      beforePut = null;
      final task = tasks[id];
      final stale = task == null || task['version'] != data!['version'];
      final unchanged =
          task != null &&
          data!.keys
              .where((key) => !reminderKeys.contains(key) && key != 'version')
              .every((key) => jsonEncode(data[key]) == jsonEncode(task[key]));
      if (task == null || (!stale && !unchanged)) {
        answers.add(403);
        throw ApiException(403, 'This list is read-only for your account.');
      }
      for (final key in reminderKeys) {
        if (data!.containsKey(key)) own[key] = clone(data[key]);
      }
      if (stale) {
        answers.add(409);
        throw ApiException(409, 'Conflict', {'current': _view(clone(task))});
      }
      answers.add(200);
      return _view(clone(task));
    }
    final answer = await super.request(
      method,
      path,
      data: data,
      audioPath: audioPath,
      authenticated: authenticated,
      accountId: accountId,
    );
    if (method == 'GET' && path.startsWith('tasks/')) {
      if (answer is Map && answer['results'] is List) {
        return {
          ...answer,
          'results': [
            for (final item in answer['results'] as List)
              _view(Map<String, dynamic>.from(item as Map)),
          ],
        };
      }
      if (answer is Map) return _view(Map<String, dynamic>.from(answer));
    }
    return answer;
  }
}
