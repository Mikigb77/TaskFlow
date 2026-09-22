import 'dart:convert';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/repositories/cloud_task_repository.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/task_list_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late TaskDatabase database;
  late _ListApi api;
  late CloudTaskRepository repository;
  late TaskListStore store;
  setUp(() async {
    final sql = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await sql.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)');
    await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
    database = TaskDatabase.forTesting(sql);
    api = _ListApi();
    repository = CloudTaskRepository(database, api, 1);
    store = TaskListStore(database, repository.ownerKey);
  });
  tearDown(() async {
    await database.close();
    api.close();
  });

  test(
      'offline lists upload before tasks and moving preserves details and sync identity',
      () async {
    final work = TaskListInfo(name: 'Work', color: 'blue');
    final personal = TaskListInfo(name: 'Personal');
    api.offline = true;
    await store.create(work);
    await store.create(personal);
    final task = Task(
        title: 'Doctor',
        priority: 3,
        dueDate: DateTime(2026, 9, 25, 17),
        reminderMinutes: 30,
        listId: work.id,
        labels: ['Health', 'health', 'Calls'],
        notes: 'Bring results',
        checklist: [ChecklistItem(title: 'Results')]);
    final id = await repository.addTask(task);
    final syncId =
        (await database.pending(repository.ownerKey)).single['sync_id'];
    await repository.sync();
    expect((await store.all()).length, 2);
    api.offline = false;
    final notifier = TaskNotifier(repository);
    addTearDown(notifier.dispose);
    await notifier.loadTasks();
    expect(
        api.writes.take(2).every((path) => path.startsWith('lists/')), isTrue);
    await notifier.moveToList(id, personal.id);
    final moved = (await repository.getAllTasks()).single;
    expect(moved.toApi(), {...task.toApi(), 'list_id': personal.id});
    expect(api.tasks.keys.single, syncId);
    await store.update(personal.copyWith(archived: true));
    await notifier.loadTasks();
    expect((await repository.getAllTasks()).single.listId, personal.id);
    final sql = await database.database;
    await sql.delete('tasks',
        where: 'owner_key = ?', whereArgs: [repository.ownerKey]);
    await sql.delete('task_lists',
        where: 'owner_key = ?', whereArgs: [repository.ownerKey]);
    await notifier.loadTasks();
    expect((await repository.getAllTasks()).single.toApi(), moved.toApi());
    expect(
        (await store.all())
            .singleWhere((list) => list.id == personal.id)
            .archived,
        isTrue);
  });

  test('list conflicts require a choice and do not move or duplicate tasks',
      () async {
    final list = TaskListInfo(name: 'Work');
    await store.create(list);
    await store.sync(api, 1);
    final taskId = await repository
        .addTask(Task(title: 'Report', priority: 1, listId: list.id));
    await repository.sync();
    api.lists[list.id] = {...api.lists[list.id]!, 'version': 2, 'name': 'Team'};
    await store.update(list.copyWith(name: 'Office'));
    await repository.sync();
    expect(repository.syncError, contains('Choose'));
    expect((await store.all()).single.name, 'Office');
    expect((await store.all()).single.conflict!['name'], 'Team');
    expect((await repository.getAllTasks()).single.id, taskId);
    await store.resolve(list.id, keepLocal: false);
    await repository.sync();
    expect((await store.all()).single.name, 'Team');
    api.lists[list.id] = {
      ...api.lists[list.id]!,
      'version': 3,
      'name': 'Remote edit'
    };
    await store.update((await store.all()).single.copyWith(name: 'Keep phone'));
    await repository.sync();
    await store.resolve(list.id, keepLocal: true);
    await repository.sync();
    expect(api.lists[list.id]!['name'], 'Keep phone');
    expect((await store.all()).single.conflict, isNull);
    expect(api.tasks.length, 1);
  });

  test(
      'lost list response is idempotent and an edit during upload stays pending',
      () async {
    final list = TaskListInfo(name: 'Shopping');
    await store.create(list);
    api.loseResponse = true;
    await expectLater(store.sync(api, 1), throwsA(isA<ApiException>()));
    await store.sync(api, 1);
    expect((await store.all()).single.conflict, isNull);
    expect(api.lists.length, 1);
    await store.update(list.copyWith(name: 'Before upload'));
    api.beforeReply =
        () => store.update(list.copyWith(name: 'Edited during upload'));
    await store.sync(api, 1);
    expect((await store.all()).single.name, 'Edited during upload');
    await store.sync(api, 1);
    expect(api.lists[list.id]!['name'], 'Edited during upload');
  });

  test(
      'guest import keeps local list references and reuses its account mapping',
      () async {
    final guest = TaskListStore(database, 'local');
    final list = TaskListInfo(name: 'Personal');
    await guest.create(list);
    await database
        .insertTask(Task(title: 'First', priority: 1, listId: list.id));
    expect(await repository.importLocalTasks(), 1);
    final imported = (await store.all()).single;
    expect(imported.id, isNot(list.id));
    expect((await guest.all()).single.id, list.id);
    expect((await repository.getAllTasks()).single.listId, imported.id);
    await database
        .insertTask(Task(title: 'Second', priority: 1, listId: list.id));
    expect(await repository.importLocalTasks(), 1);
    expect((await store.all()).length, 1);
    expect(
        (await repository.getAllTasks())
            .every((task) => task.listId == imported.id),
        isTrue);
    expect(await repository.importLocalTasks(), 0);
    final other = TaskListStore(database, 'other-account');
    expect(await other.all(), isEmpty);
    await expectLater(other.update(imported.copyWith(name: 'Unauthorized')),
        throwsStateError);
    await expectLater(
        database.insertTask(
            Task(title: 'Wrong owner', priority: 1, listId: imported.id)),
        throwsStateError);
    await repository.sync();
    expect(repository.syncError, isNull);
  });
}

class _ListApi extends ApiClient {
  _ListApi() : super(url: 'http://localhost:8088');
  final lists = <String, Map<String, dynamic>>{};
  final tasks = <String, Map<String, dynamic>>{};
  final writes = <String>[];
  bool offline = false;
  bool loseResponse = false;
  Future<void> Function()? beforeReply;
  Map<String, dynamic> _clone(Map<String, dynamic> data) =>
      jsonDecode(jsonEncode(data));
  @override
  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? data,
      String? audioPath,
      bool authenticated = true,
      int? accountId}) async {
    if (offline) throw ApiException(0, 'Offline');
    if (path.startsWith('attachments/')) return {'results': [], 'next': null};
    final values = path.startsWith('lists/') ? lists : tasks;
    if (method == 'GET') {
      return {'results': values.values.map(_clone).toList(), 'next': null};
    }
    writes.add(path);
    final id = path.split('/')[1];
    if (values.containsKey(id) && values[id]!['version'] != data!['version']) {
      throw ApiException(409, 'Conflict', {'current': _clone(values[id]!)});
    }
    final next = {...data!, 'id': id, 'version': (data['version'] as int) + 1};
    values[id] = _clone(next);
    if (beforeReply != null) {
      final callback = beforeReply!;
      beforeReply = null;
      await callback();
    }
    if (loseResponse) {
      loseResponse = false;
      throw ApiException(0, 'Connection lost');
    }
    return _clone(next);
  }
}
