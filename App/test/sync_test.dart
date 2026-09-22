import 'package:agenda/models/task.dart';
import 'package:agenda/repositories/cloud_task_repository.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late TaskDatabase database;
  late _Api api;
  late CloudTaskRepository repository;
  final task = Task(
      title: 'Doctor appointment',
      dueDate: DateTime(2026, 9, 25, 17),
      priority: 3,
      notes: 'Bring blood test results',
      filePaths: ['/private/report.pdf']);

  setUp(() async {
    final sql = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await sql.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)');
    await sql.insert(
        'tasks',
        task.toMap()
          ..remove('hasTime')
          ..remove('recurrence')
          ..remove('repeatUntil')
          ..remove('completedDates')
          ..remove('reminderMinutes')
          ..remove('reminderTime'));
    await TaskDatabase.upgrade(sql, 3, 7);
    database = TaskDatabase.forTesting(sql);
    api = _Api();
    repository = CloudTaskRepository(database, api, 1);
  });
  tearDown(() async {
    await database.close();
    api.close();
  });

  test('migration preserves old tasks locally until explicit one-time import',
      () async {
    expect((await database.getTasks()).single.title, task.title);
    expect(await repository.getAllTasks(), isEmpty);
    expect(await database.pending(repository.ownerKey), isEmpty);
    expect(await repository.importLocalTasks(), 1);
    expect(await repository.importLocalTasks(), 0);
    expect((await repository.getAllTasks()).single.filePaths, task.filePaths);
    expect(await database.getTasks(), isEmpty);
  });

  test('account caches cannot read, update, or delete another account task',
      () async {
    final id = await repository.addTask(task);
    final other = CloudTaskRepository(database, api, 2);
    expect(await other.getAllTasks(), isEmpty);
    expect(() => other.updateTask(task.copyWith(id: id)), throwsStateError);
    expect(await other.deleteTask(id), 0);
    expect((await repository.getAllTasks()).single.id, id);
  });

  test('offline writes remain available and deletion remains queued', () async {
    api.offline = true;
    final id = await repository.addTask(task);
    await repository.sync();
    expect((await repository.getAllTasks()).single.dueDate, task.dueDate);
    expect(repository.syncError, contains('Saved on this phone'));
    expect((await database.pending(repository.ownerKey)).length, 1);
    await repository.deleteTask(id);
    expect(await repository.getAllTasks(), isEmpty);
    expect(
        (await database.pending(repository.ownerKey)).single['is_deleted'], 1);
  });

  test('successful upload excludes device paths and downloads to a fresh cache',
      () async {
    await repository.addTask(task);
    await repository.sync();
    expect(await database.pending(repository.ownerKey), isEmpty);
    expect(api.lastUpload!.keys, isNot(contains('filePaths')));
    expect(api.lastUpload!.keys, isNot(contains('imagePaths')));
    expect(DateTime.parse(api.lastUpload!['due_date']), task.dueDate!.toUtc());
    final rows = await database.database;
    await rows.delete('tasks',
        where: 'owner_key = ?', whereArgs: [repository.ownerKey]);
    await repository.sync();
    final restored = (await repository.getAllTasks()).single;
    expect(restored.title, task.title);
    expect(restored.dueDate, task.dueDate);
    expect(restored.filePaths, isEmpty);
  });

  test('an edit during upload is not cleared by acknowledgement', () async {
    final id = await repository.addTask(task);
    final sent = (await database.pending(repository.ownerKey)).single;
    await repository.updateTask(task.copyWith(id: id, title: 'Newer edit'));
    await database.acknowledge(repository.ownerKey, sent, {'version': 1});
    final pending = (await database.pending(repository.ownerKey)).single;
    expect(pending['title'], 'Newer edit');
    expect(pending['remote_version'], 1);
  });

  test('Inbox, date-only and repeated completion survive sync and restoration',
      () async {
    await repository.addTasks([
      Task(title: 'Coffee', priority: 1),
      Task(
          title: 'Pay invoice',
          dueDate: DateTime(2026, 9, 25),
          hasTime: false,
          priority: 2),
      Task(
          title: 'Water plants',
          dueDate: DateTime(2026, 9, 27, 9),
          priority: 1,
          recurrence: 'weekly',
          repeatUntil: DateTime(2027, 1, 31),
          completedDates: ['2026-09-27']),
    ]);
    await repository.sync();
    expect(repository.syncError, isNull);
    expect(api.remote.firstWhere((t) => t['title'] == 'Coffee')['due_date'],
        isNull);
    final invoice = api.remote.firstWhere((t) => t['title'] == 'Pay invoice');
    expect(invoice['scheduled_date'], '2026-09-25');
    expect(invoice['due_date'], isNull);
    final sql = await database.database;
    await sql.delete('tasks',
        where: 'owner_key = ?', whereArgs: [repository.ownerKey]);
    await repository.sync();
    final restored = (await repository.getAllTasks())
      ..sort((a, b) => a.title.compareTo(b.title));
    expect(restored[0].dueDate, isNull);
    expect(restored[1].hasTime, isFalse);
    expect(restored[1].dueDate, DateTime(2026, 9, 25));
    expect(
        restored[2].occurrenceOn(DateTime(2026, 9, 27))!.isCompleted, isTrue);
    expect(
        restored[2]
            .nextOpenOccurrence(from: DateTime(2026, 9, 27))!
            .displayDate,
        DateTime(2026, 10, 4, 9));
  });

  test('batch save rolls back entirely on database failure', () async {
    final sql = await database.database;
    await sql.execute(
        "CREATE TRIGGER reject_task BEFORE INSERT ON tasks WHEN NEW.title = 'Fail' BEGIN SELECT RAISE(ABORT, 'test'); END");
    await expectLater(
        repository.addTasks([
          Task(title: 'First', priority: 1),
          Task(title: 'Fail', priority: 1)
        ]),
        throwsA(isA<DatabaseException>()));
    expect(await repository.getAllTasks(), isEmpty);
  });

  test('retry after lost upload response is idempotent', () async {
    await repository.addTask(task);
    api.loseResponse = true;
    await repository.sync();
    expect((await database.pending(repository.ownerKey)).length, 1);
    api.loseResponse = false;
    await repository.sync();
    expect(await database.pending(repository.ownerKey), isEmpty);
    expect((await repository.getAllTasks()).length, 1);
    expect(api.remote.length, 1);
  });

  test(
      'conflicting edits preserve an offline copy and remote deletion propagates',
      () async {
    final id = await repository.addTask(task);
    await repository.sync();
    api.remote.single['version'] = 2;
    api.remote.single['title'] = 'Changed on another phone';
    await repository.updateTask(task.copyWith(id: id, title: 'Offline edit'));
    await repository.sync();
    final titles = (await repository.getAllTasks()).map((task) => task.title);
    expect(
        titles,
        containsAll(
            ['Changed on another phone', 'Offline edit (offline copy)']));
    await repository.sync();
    api.remote.first['version'] = 3;
    api.remote.first['is_deleted'] = true;
    await repository.sync();
    expect((await repository.getAllTasks()).single.title,
        'Offline edit (offline copy)');
  });
}

class _Api extends ApiClient {
  _Api() : super(url: 'http://localhost:8088');
  bool offline = false;
  bool loseResponse = false;
  final List<Map<String, dynamic>> remote = [];
  Map<String, dynamic>? lastUpload;

  @override
  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? data,
      String? audioPath,
      bool authenticated = true,
      int? accountId}) async {
    if (offline) throw ApiException(0, 'Offline');
    if (method == 'GET') return {'results': remote, 'next': null};
    lastUpload = data;
    final id = path.split('/')[1];
    final index = remote.indexWhere((task) => task['id'] == id);
    if (index >= 0 && remote[index]['version'] != data!['version']) {
      throw ApiException(409, 'Conflict', {'current': remote[index]});
    }
    final next = {...data!, 'id': id, 'version': (data['version'] as int) + 1};
    if (index < 0) {
      remote.add(next);
    } else {
      remote[index] = next;
    }
    if (loseResponse) throw ApiException(0, 'Connection lost');
    return next;
  }
}
