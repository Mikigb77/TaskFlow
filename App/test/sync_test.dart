import 'dart:async';

import 'package:agenda/models/task.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/repositories/cloud_task_repository.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    filePaths: ['/private/report.pdf'],
  );

  setUp(() async {
    final sql = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await sql.execute(
      'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
    );
    await sql.insert(
      'tasks',
      task.toMap()
        ..remove('assignment')
        ..remove('assigneeId')
        ..remove('assigneeName')
        ..remove('createdBy')
        ..remove('createdByName')
        ..remove('kind')
        ..remove('hasTime')
        ..remove('recurrence')
        ..remove('repeatUntil')
        ..remove('completedDates')
        ..remove('reminderMinutes')
        ..remove('deadline')
        ..remove('deadlineHasTime')
        ..remove('durationMinutes')
        ..remove('reminderAnchor')
        ..remove('checklist')
        ..remove('listId')
        ..remove('labels')
        ..remove('repeatInterval')
        ..remove('repeatWeekdays')
        ..remove('exceptions')
        ..remove('reminderTime')
        ..remove('reminderPlan'),
    );
    await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
    database = TaskDatabase.forTesting(sql);
    api = _Api();
    repository = CloudTaskRepository(database, api, 1);
  });
  tearDown(() async {
    await database.close();
    api.close();
  });

  test(
    'migration preserves old tasks locally until explicit one-time import',
    () async {
      expect((await database.getTasks()).single.title, task.title);
      expect(await repository.getAllTasks(), isEmpty);
      expect(await database.pending(repository.ownerKey), isEmpty);
      expect(await repository.importLocalTasks(), 1);
      expect(await repository.importLocalTasks(), 0);
      expect((await repository.getAllTasks()).single.filePaths, task.filePaths);
      expect(await database.getTasks(), isEmpty);
    },
  );

  test(
    'account caches cannot read, update, or delete another account task',
    () async {
      final id = await repository.addTask(task);
      final other = CloudTaskRepository(database, api, 2);
      expect(await other.getAllTasks(), isEmpty);
      expect(() => other.updateTask(task.copyWith(id: id)), throwsStateError);
      expect(await other.deleteTask(id), 0);
      expect((await repository.getAllTasks()).single.id, id);
    },
  );

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
      (await database.pending(repository.ownerKey)).single['is_deleted'],
      1,
    );
  });

  test(
    'successful upload excludes device paths and downloads to a fresh cache',
    () async {
      await repository.addTask(task);
      await repository.sync();
      expect(await database.pending(repository.ownerKey), isEmpty);
      expect(api.lastUpload!.keys, isNot(contains('filePaths')));
      expect(api.lastUpload!.keys, isNot(contains('imagePaths')));
      expect(
        DateTime.parse(api.lastUpload!['due_date']),
        task.dueDate!.toUtc(),
      );
      final rows = await database.database;
      await rows.delete(
        'tasks',
        where: 'owner_key = ?',
        whereArgs: [repository.ownerKey],
      );
      await repository.sync();
      final restored = (await repository.getAllTasks()).single;
      expect(restored.title, task.title);
      expect(restored.dueDate, task.dueDate);
      expect(restored.filePaths, isEmpty);
    },
  );

  test('an edit during upload is not cleared by acknowledgement', () async {
    final id = await repository.addTask(task);
    final sent = (await database.pending(repository.ownerKey)).single;
    await repository.updateTask(task.copyWith(id: id, title: 'Newer edit'));
    await database.acknowledge(repository.ownerKey, sent, {'version': 1});
    final pending = (await database.pending(repository.ownerKey)).single;
    expect(pending['title'], 'Newer edit');
    expect(pending['remote_version'], 1);
  });

  test(
    'Inbox, date-only and repeated completion survive sync and restoration',
    () async {
      await repository.addTasks([
        Task(title: 'Coffee', priority: 1),
        Task(
          title: 'Pay invoice',
          dueDate: DateTime(2026, 9, 25),
          hasTime: false,
          priority: 2,
        ),
        Task(
          title: 'Water plants',
          dueDate: DateTime(2026, 9, 27, 9),
          priority: 1,
          recurrence: 'weekly',
          repeatUntil: DateTime(2027, 1, 31),
          completedDates: ['2026-09-27'],
        ),
      ]);
      await repository.sync();
      expect(repository.syncError, isNull);
      expect(
        api.remote.firstWhere((t) => t['title'] == 'Coffee')['due_date'],
        isNull,
      );
      final invoice = api.remote.firstWhere((t) => t['title'] == 'Pay invoice');
      expect(invoice['scheduled_date'], '2026-09-25');
      expect(invoice['due_date'], isNull);
      final sql = await database.database;
      await sql.delete(
        'tasks',
        where: 'owner_key = ?',
        whereArgs: [repository.ownerKey],
      );
      await repository.sync();
      final restored = (await repository.getAllTasks())
        ..sort((a, b) => a.title.compareTo(b.title));
      expect(restored[0].dueDate, isNull);
      expect(restored[1].hasTime, isFalse);
      expect(restored[1].dueDate, DateTime(2026, 9, 25));
      expect(
        restored[2].occurrenceOn(DateTime(2026, 9, 27))!.isCompleted,
        isTrue,
      );
      expect(
        restored[2]
            .nextOpenOccurrence(from: DateTime(2026, 9, 27))!
            .displayDate,
        DateTime(2026, 10, 4, 9),
      );
    },
  );

  test('batch save rolls back entirely on database failure', () async {
    final sql = await database.database;
    await sql.execute(
      "CREATE TRIGGER reject_task BEFORE INSERT ON tasks WHEN NEW.title = 'Fail' BEGIN SELECT RAISE(ABORT, 'test'); END",
    );
    await expectLater(
      repository.addTasks([
        Task(title: 'First', priority: 1),
        Task(title: 'Fail', priority: 1),
      ]),
      throwsA(isA<DatabaseException>()),
    );
    expect(await repository.getAllTasks(), isEmpty);
  });

  test(
    'offline checklist edits survive sync restoration and conflicting completions',
    () async {
      final passport = ChecklistItem(title: 'Passport');
      final charger = ChecklistItem(title: 'Charger');
      final packing = task.copyWith(
        title: 'Pack',
        checklist: [passport, charger],
      );
      api.offline = true;
      final id = await repository.addTask(packing);
      await repository.updateTask(
        packing.copyWith(
          id: id,
          checklist: [
            charger.setDone(true),
            passport.copyWith(title: 'New passport'),
          ],
        ),
      );
      await repository.sync();
      expect(
        (await repository.getAllTasks()).single.checklist.first.completed,
        isTrue,
      );
      api.offline = false;
      await repository.sync();
      expect(repository.syncError, isNull);
      final sql = await database.database;
      await sql.delete(
        'tasks',
        where: 'owner_key = ?',
        whereArgs: [repository.ownerKey],
      );
      await repository.sync();
      final restored = (await repository.getAllTasks()).single;
      expect(restored.checklist.map((item) => item.id), [
        charger.id,
        passport.id,
      ]);
      expect(restored.checklist.first.completed, isTrue);
      expect(restored.checklist.last.title, 'New passport');
      expect(restored.isCompleted, isFalse);
      api.remote.single['version'] = 2;
      api.remote.single['checklist'] = [
        charger.setDone(false).toJson(),
        passport.toJson(),
      ];
      await repository.updateTask(
        restored.copyWith(
          checklist: [charger.setDone(true), passport.setDone(true)],
        ),
      );
      await repository.sync();
      final all = await repository.getAllTasks();
      expect(all.length, 2);
      expect(
        all
            .singleWhere((task) => task.title.endsWith('(offline copy)'))
            .checklist
            .every((item) => item.completed),
        isTrue,
      );
      expect(
        all
            .singleWhere((task) => task.title == 'Pack')
            .checklist
            .every((item) => !item.completed),
        isTrue,
      );
    },
  );

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
    'planning fields survive lost responses, empty-cache restore and deadline-only conflicts',
    () async {
      final planned = task.copyWith(
        deadline: DateTime(2026, 9, 28, 17),
        deadlineHasTime: true,
        durationMinutes: 75,
        reminderAnchor: 'deadline',
      );
      await repository.addTask(planned);
      api.loseResponse = true;
      await repository.sync();
      api.loseResponse = false;
      await repository.sync();
      expect(await database.pending(repository.ownerKey), isEmpty);
      expect(api.remote, hasLength(1));
      final sql = await database.database;
      await sql.delete(
        'tasks',
        where: 'owner_key = ?',
        whereArgs: [repository.ownerKey],
      );
      await repository.sync();
      final restored = (await repository.getAllTasks()).single;
      expect(restored.toApi(), planned.toApi());
      api.remote.single['version'] = 2;
      api.remote.single['deadline_at'] = DateTime(
        2026,
        9,
        29,
        17,
      ).toUtc().toIso8601String();
      await repository.updateTask(restored.copyWith(durationMinutes: 90));
      await repository.sync();
      final tasks = await repository.getAllTasks();
      expect(tasks, hasLength(2));
      final offline = tasks.singleWhere(
        (task) => task.title.endsWith('(offline copy)'),
      );
      expect(offline.deadline, planned.deadline);
      expect(offline.durationMinutes, 90);
      expect(
        tasks.singleWhere((task) => task.title == planned.title).deadline,
        DateTime(2026, 9, 29, 17),
      );
    },
  );

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
        containsAll([
          'Changed on another phone',
          'Offline edit (offline copy)',
        ]),
      );
      await repository.sync();
      api.remote.first['version'] = 3;
      api.remote.first['is_deleted'] = true;
      await repository.sync();
      expect(
        (await repository.getAllTasks()).single.title,
        'Offline edit (offline copy)',
      );
    },
  );

  test(
    'notes retain type after lost upload, fresh cache and conflict copy',
    () async {
      final note = Task(
        kind: 'note',
        title: 'Reference',
        priority: 1,
        notes: 'Opening on Friday at 17:00',
      );
      await repository.addTask(note);
      api.loseResponse = true;
      await repository.sync();
      api.loseResponse = false;
      await repository.sync();
      expect(await database.pending(repository.ownerKey), isEmpty);
      expect(api.remote, hasLength(1));
      await (await database.database).delete(
        'tasks',
        where: 'owner_key = ?',
        whereArgs: [repository.ownerKey],
      );
      await repository.sync();
      final restored = (await repository.getAllTasks()).single;
      expect(restored.toApi(), note.toApi());
      api.remote.single['version'] = 2;
      api.remote.single['notes'] = 'New remote information';
      await repository.updateTask(restored.copyWith(notes: 'Unsent reference'));
      await repository.sync();
      final both = await repository.getAllTasks();
      expect(both, hasLength(2));
      expect(both.every((item) => item.isNote), isTrue);
      expect(
        both.map((item) => item.notes),
        containsAll(['Unsent reference', 'New remote information']),
      );
    },
  );

  test(
    'an older server cannot silently turn a pending note into a task',
    () async {
      await repository.addTask(
        Task(kind: 'note', title: 'Reference', priority: 1),
      );
      api.supportsNotes = false;
      await repository.sync();
      expect(api.remote, isEmpty);
      expect(
        (await database.pending(repository.ownerKey)).single['kind'],
        'note',
      );
      expect(repository.syncError, contains('Update this server'));
      api.supportsNotes = true;
      await repository.sync();
      expect(api.remote.single['kind'], 'note');
      expect(await database.pending(repository.ownerKey), isEmpty);
    },
  );

  test(
    'UX-208: a soft-deleted task restored before sync goes out as not deleted, at the same id, with its date, reminder and steps',
    () async {
      final full = task.copyWith(
        reminderMinutes: 30,
        checklist: [ChecklistItem(id: 'a', title: 'Llevar la tarjeta')],
      );
      final id = await repository.addTask(full);
      await repository.sync();
      expect(await database.pending(repository.ownerKey), isEmpty);
      final before = (await repository.getAllTasks()).single;

      await repository.deleteTask(id);
      expect(await repository.getAllTasks(), isEmpty);
      expect(
        (await database.pending(repository.ownerKey)).single['is_deleted'],
        1,
      );

      await repository.restoreTask(before);
      final pending = (await database.pending(repository.ownerKey)).single;
      expect(pending['is_deleted'], 0);
      expect(pending['id'], id);
      final back = (await repository.getAllTasks()).single;
      expect(back.id, id);
      expect(back.dueDate, full.dueDate);
      expect(back.reminderMinutes, 30);
      expect(back.checklist.single.title, 'Llevar la tarjeta');

      await repository.sync();
      expect(api.lastUpload!['is_deleted'], isFalse);
      expect(await database.pending(repository.ownerKey), isEmpty);
      expect(api.remote.single['is_deleted'], isFalse);
      expect((await repository.getAllTasks()).single.title, task.title);
    },
  );

  // ---- 2026-10-28-app · P268 (UX-2301): ticks, moves and steps show at
  // once; the server sync runs behind and loses nothing ----

  group('P268 · changes show at once; the sync runs behind', () {
    test(
      'UX-2301: with a sync that takes 5 s and then succeeds, a tick, a move and a step show at once, and afterwards the list matches the server’s, each change sent once',
      () async {
        final slow = _SlowApi();
        addTearDown(slow.close);
        final cloud = CloudTaskRepository(database, slow, 1);
        await cloud.addTasks([
          Task(
            title: 'Comprar pan',
            priority: 1,
            dueDate: DateTime(2026, 10, 20, 9),
          ),
          Task(
            title: 'Llamar a Ana',
            priority: 1,
            dueDate: DateTime(2026, 10, 20, 11),
          ),
          Task(
            title: 'Preparar la maleta',
            priority: 1,
            dueDate: DateTime(2026, 10, 20, 18),
            checklist: [
              ChecklistItem(id: 'charger', title: 'Cargador'),
              ChecklistItem(id: 'passport', title: 'Pasaporte'),
            ],
          ),
          Task(
            title: 'Pagar la luz',
            priority: 1,
            dueDate: DateTime(2026, 10, 22),
            hasTime: false,
          ),
        ]);
        await cloud.sync();
        expect(cloud.syncError, isNull);
        expect(await database.pending(cloud.ownerKey), isEmpty);
        expect(slow.remote, hasLength(4));
        // Meanwhile another device renames one on the server.
        final bill = slow.remote.indexWhere(
          (t) => t['title'] == 'Pagar la luz',
        );
        slow.remote[bill] = {
          ...slow.remote[bill],
          'title': 'Pagar la luz y el agua',
          'version': (slow.remote[bill]['version'] as int) + 1,
        };
        slow.puts.clear();
        slow.holdNextPull = const Duration(seconds: 5);

        // The app opens: its first load starts the slow sync.
        final notifier = TaskNotifier(cloud);
        addTearDown(notifier.dispose);
        var shown = <Task>[];
        notifier.addListener((state) => shown = state.valueOrNull ?? shown);
        await slow.pullHeld.future.timeout(const Duration(seconds: 5));
        Task named(String title) => shown.firstWhere((t) => t.title == title);
        expect(shown, hasLength(4));

        final watch = Stopwatch()..start();
        await notifier.setCompleted(named('Comprar pan'), true);
        await notifier.rescheduleTask(
          named('Llamar a Ana').id!,
          DateTime(2026, 10, 21, 11),
          true,
        );
        await notifier.setChecklistCompleted(
          named('Preparar la maleta'),
          'charger',
          true,
        );
        watch.stop();
        expect(slow.released, isFalse, reason: 'the slow sync still runs');
        expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
        expect(named('Comprar pan').isCompleted, isTrue);
        expect(named('Llamar a Ana').dueDate, DateTime(2026, 10, 21, 11));
        expect(
          named('Preparar la maleta').checklist.map((item) => item.completed),
          [true, false],
        );

        // The slow sync ends, then the one the changes asked for runs.
        await notifier.loadTasks();
        expect(slow.released, isTrue);
        expect(cloud.syncError, isNull);
        expect(await database.pending(cloud.ownerKey), isEmpty);
        final remote = {for (final t in slow.remote) t['title'] as String: t};
        expect(
          remote.keys,
          unorderedEquals([
            'Comprar pan',
            'Llamar a Ana',
            'Preparar la maleta',
            'Pagar la luz y el agua',
          ]),
        );
        // Each change reached the server once, and only the changed tasks.
        expect(slow.puts.length, 3, reason: '${slow.puts}');
        expect(slow.puts.values, everyElement(1), reason: '${slow.puts}');
        for (final title in [
          'Comprar pan',
          'Llamar a Ana',
          'Preparar la maleta',
        ]) {
          expect(remote[title]!['version'], 2, reason: title);
        }
        expect(remote['Pagar la luz y el agua']!['version'], 2);
        expect(remote['Comprar pan']!['is_completed'], isTrue);
        expect(remote['Llamar a Ana']!['is_completed'], isFalse);

        // What the server holds, read into an empty cache, is what the list
        // shows now.
        List<String> describe(List<Task> tasks) => [
          for (final t in [
            ...tasks,
          ]..sort((a, b) => a.title.compareTo(b.title)))
            [
              t.title,
              t.isCompleted,
              t.dueDate?.toUtc(),
              t.hasTime,
              for (final item in t.checklist) '${item.title}:${item.completed}',
            ].join('|'),
        ];
        final onScreen = describe(shown);
        expect(onScreen, hasLength(4));
        expect(
          onScreen.where((t) => t.startsWith('Pagar la luz y el agua|')),
          hasLength(1),
          reason: 'the other device’s change shows too',
        );
        final sql = await database.database;
        await sql.delete(
          'tasks',
          where: 'owner_key = ?',
          whereArgs: [cloud.ownerKey],
        );
        await cloud.sync();
        expect(describe(await cloud.getAllTasks()), onScreen);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}

/// [_Api] whose next pull of the task pages waits [holdNextPull]: a sync
/// that takes that long, then succeeds. Counts the task uploads per task.
class _SlowApi extends _Api {
  Duration? holdNextPull;

  /// Completes when the held pull starts.
  final pullHeld = Completer<void>();

  /// Whether the held pull has answered.
  bool released = false;

  /// Uploads per task id.
  final puts = <String, int>{};

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    final hold = holdNextPull;
    if (method == 'GET' && path.startsWith('tasks/?') && hold != null) {
      holdNextPull = null;
      if (!pullHeld.isCompleted) pullHeld.complete();
      await Future<void>.delayed(hold);
      released = true;
    }
    if (method == 'PUT' && path.startsWith('tasks/')) {
      final id = path.split('/')[1];
      puts[id] = (puts[id] ?? 0) + 1;
    }
    return super.request(
      method,
      path,
      data: data,
      audioPath: audioPath,
      authenticated: authenticated,
      accountId: accountId,
    );
  }
}

class _Api extends ApiClient {
  _Api() : super(url: 'http://localhost:8088');
  bool offline = false;
  bool loseResponse = false;
  bool supportsNotes = true;
  final List<Map<String, dynamic>> remote = [];
  Map<String, dynamic>? lastUpload;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    if (offline) throw ApiException(0, 'Offline');
    if (path == 'health/') {
      return {
        'status': 'ok',
        'features': {'notes': supportsNotes},
      };
    }
    if (path == 'lists/access/') return {'lists': []};
    if (path.startsWith('attachments/')) return {'results': [], 'next': null};
    if (method == 'GET' && path.startsWith('lists/')) {
      return {'results': [], 'next': null};
    }
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
