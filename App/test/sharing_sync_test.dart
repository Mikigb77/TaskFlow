import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:agenda/models/task.dart';
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
