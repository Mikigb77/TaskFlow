import 'package:agenda/models/archive_diagnostic.dart';
import 'dart:convert';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/occurrence_exception.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_archive.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/services/archive_store.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/task_list_store.dart';
import 'package:agenda/services/todoist_import.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  sqfliteFfiInit();
  late TaskDatabase database;
  setUp(() async {
    final sql = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await sql.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)');
    await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
    database = TaskDatabase.forTesting(sql);
  });
  tearDown(() => database.close());

  test(
      'export and partial retry import preserve supported fields, empty lists and account isolation',
      () async {
    final list = TaskListInfo(name: 'Work', color: 'blue', archived: true);
    final empty = TaskListInfo(name: 'Empty');
    await TaskListStore(database, 'local').create(list);
    await TaskListStore(database, 'local').create(empty);
    final tasks = [
      Task(title: 'Coffee', priority: 1, isCompleted: true),
      Task(
          title: 'Date only',
          priority: 2,
          dueDate: DateTime(2026, 9, 25),
          hasTime: false,
          reminderTime: 600),
      Task(
          title: 'Review',
          priority: 3,
          dueDate: DateTime(2026, 9, 23, 17),
          deadline: DateTime(2026, 9, 24, 12),
          deadlineHasTime: true,
          durationMinutes: 45,
          reminderAnchor: 'deadline',
          recurrence: 'weekly',
          repeatInterval: 2,
          repeatWeekdays: [3, 5],
          repeatUntil: DateTime(2027, 1, 1),
          completedDates: ['2026-09-23'],
          notes: 'Bring results\nAnd a copy.',
          listId: list.id,
          labels: ['work', 'health'],
          reminderMinutes: 30,
          exceptions: [
            OccurrenceException(
                originalDate: '2026-09-23',
                date: DateTime(2026, 9, 25),
                hasTime: false),
            const OccurrenceException(originalDate: '2026-10-07', skipped: true)
          ],
          checklist: [
            ChecklistItem(title: 'Results', completedDates: ['2026-09-23'])
          ],
          filePaths: ['C:\\private\\results.pdf']),
    ];
    await database.insertTasks(tasks);
    await database.insertTask(Task(title: 'Other account secret', priority: 1),
        ownerKey: 'account-A');
    final contents = await ArchiveStore(database, 'local').export();
    expect(contents, isNot(contains('Other account secret')));
    expect(contents, isNot(contains('private')));
    final archive = TaskArchive.parse(contents);
    expect(archive.tasks.every((row) => row.error == null), isTrue);
    expect(archive.tasks.last.warnings.single.code,
        ArchiveCode.attachmentsOmitted);
    expect(archive.tasks.last.warnings.single.count, 1);
    final target = ArchiveStore(database, 'account-B');
    final first = await target.import(archive, {archive.tasks.first.sourceId});
    expect(first.added, 1);
    expect(first.listsAdded, 2);
    final selected = archive.tasks.map((row) => row.sourceId).toSet();
    await Future.wait(
        [target.import(archive, selected), target.import(archive, selected)]);
    final restored = await database.getTasks(ownerKey: 'account-B');
    expect(restored.length, 3);
    final restoredLists = await TaskListStore(database, 'account-B').all();
    expect(restoredLists.length, 2);
    final copiedList =
        restoredLists.singleWhere((value) => value.name == list.name);
    expect(copiedList.archived, isTrue);
    expect(copiedList.id, isNot(list.id));
    for (final original in tasks) {
      final copy = restored.singleWhere((task) => task.title == original.title);
      expect(copy.toApi(), {
        ...original.toApi(),
        'list_id': original.listId == null ? null : copiedList.id
      });
      expect(copy.filePaths, isEmpty);
    }
    expect((await target.imported(archive.id)).length, 3);
    expect((await database.pending('account-B')).length, 3);
    expect((await database.getTasks()).length, 3);
    expect((await database.getTasks(ownerKey: 'account-A')).single.title,
        'Other account secret');
  });

  test('failed imports roll back task, list and receipt writes together',
      () async {
    final list = TaskListInfo(name: 'New');
    final archive = TaskArchive(
        id: const Uuid().v4(),
        source: ArchiveSource.taskflow,
        lists: [
          list
        ],
        tasks: [
          for (final title in ['First', 'Fails'])
            ImportTask(
                sourceId: const Uuid().v4(),
                title: title,
                task: Task(title: title, priority: 1, listId: list.id)),
        ]);
    final sql = await database.database;
    await sql.execute(
        "CREATE TRIGGER fail_import BEFORE INSERT ON tasks WHEN NEW.title = 'Fails' BEGIN SELECT RAISE(ABORT, 'fixture interruption'); END");
    final store = ArchiveStore(database, 'local');
    final selected = archive.tasks.map((row) => row.sourceId).toSet();
    await expectLater(
        store.import(archive, selected), throwsA(isA<DatabaseException>()));
    expect(await database.getTasks(), isEmpty);
    expect(await TaskListStore(database, 'local').all(), isEmpty);
    expect(await store.imported(archive.id), isEmpty);
    await sql.execute('DROP TRIGGER fail_import');
    expect((await store.import(archive, selected)).added, 2);
    expect((await store.import(archive, selected)).added, 0);
  });

  test(
      'invalid rows are previewed without changing data; future versions are rejected',
      () async {
    await database.insertTask(Task(title: 'Keep me', priority: 1));
    final data = jsonDecode(await ArchiveStore(database, 'local').export())
        as Map<String, dynamic>;
    final valid = Map<String, dynamic>.from(data['tasks'][0]);
    data['tasks'] = [
      valid,
      for (final fields in [
        {'priority': 5},
        {'scheduled_date': '2026-02-30'},
        {'due_date': '2026-09-23T25:00:00Z'},
        {'due_date': '2026-09-23T09:00:00'},
        {'due_date': '2026-09-23T09:00:00+25:00'},
        {'repeat_interval': 2},
        {'list_id': const Uuid().v4()},
      ])
        {...valid, ...fields, 'id': const Uuid().v4()}
    ];
    final archive = TaskArchive.parse(jsonEncode(data));
    expect(archive.tasks.where((row) => row.error != null).length, 7);
    expect((await database.getTasks()).single.title, 'Keep me');
    data['version'] = 99;
    expect(() => TaskArchive.parse(jsonEncode(data)), throwsFormatException);
    expect(() => TaskArchive.parse('[]'), throwsFormatException);
  });

  test(
      'Todoist CSV preserves quoted text and comments; warns before unsupported schedules and nesting',
      () {
    const csv = 'TYPE,CONTENT,DESCRIPTION,PRIORITY,INDENT,DATE,DURATION\r\n'
        'section,Work,,,,,\r\n'
        'task,"Call Alex, about the ""report""","Line one\nLine two",1,1,2026-09-25,\r\n'
        'note,Bring results,,,,,\r\n'
        'task,Child,,3,2,every Friday,30\r\n'
        'section,Empty,,,,,\r\n'
        'note,Orphan note,,,,,\r\n';
    final archive = TodoistImport.parse(csv);
    expect(archive.id, TodoistImport.parse(csv).id);
    expect(archive.tasks.length, 2);
    expect(archive.lists.length, 2);
    final first = archive.tasks.first.task!;
    expect(first.title, 'Call Alex, about the "report"');
    expect(first.notes, 'Line one\nLine two\n\nBring results');
    expect(first.priority, 3);
    expect(first.dueDate, DateTime(2026, 9, 25));
    final second = archive.tasks.last;
    expect(second.task!.dueDate, isNull);
    expect(second.task!.notes, contains('every Friday'));
    expect(second.task!.notes, contains('30'));
    expect(second.task!.notes, isNot(contains('Orphan')));
    expect(second.warnings.length, 3);
    expect(archive.warnings.last.code, ArchiveCode.csvOrphanComment);
  });

  test('CSV rejects malformed quoting and preserves explicit timezone offsets',
      () {
    expect(() => TodoistImport.parse('TYPE,CONTENT\ntask,"Unfinished'),
        throwsFormatException);
    expect(() => TodoistImport.parse('TYPE,CONTENT\ntask,"Done"oops'),
        throwsFormatException);
    expect(() => TodoistImport.parse('TYPE,CONTENT\ntask,A,extra'),
        throwsFormatException);
    final archive = TodoistImport.parse(
        'TYPE,CONTENT,DATE,PRIORITY\ntask,Midnight,2026-09-23T00:00:00+02:00,2');
    expect(archive.tasks.single.error, isNull);
    expect(archive.tasks.single.task!.dueDate!.toUtc(),
        DateTime.utc(2026, 9, 22, 22));
    expect(archive.tasks.single.task!.hasTime, isTrue);
  });

  // ---- UX loop 2026-10-28-app, round 1 · P300 (UX-2311, D2): completion
  // times through Exportar e importar ----
  group('P300 · completion times', () {
    test(
        'UX-2311: a task completed with a time keeps that time through Exportar and Importar, a repetition’s too',
        () async {
      final bread = DateTime(2026, 11, 3, 8, 15);
      final plants = DateTime(2026, 11, 2, 20, 30);
      await database.insertTasks([
        Task(
            title: 'Comprar pan',
            priority: 1,
            isCompleted: true,
            completedAt: bread),
        Task(
            title: 'Regar las plantas',
            priority: 1,
            dueDate: DateTime(2026, 11, 1, 9),
            recurrence: 'daily',
            completedDates: ['2026-11-01', '2026-11-02'],
            completedTimes: {'2026-11-02': plants}),
      ]);
      final contents = await ArchiveStore(database, 'local').export();
      final archive = TaskArchive.parse(contents);
      expect(archive.tasks.every((row) => row.error == null), isTrue);
      final target = ArchiveStore(database, 'account-B');
      await target.import(
          archive, archive.tasks.map((row) => row.sourceId).toSet());
      final restored = await database.getTasks(ownerKey: 'account-B');
      final copy = restored.singleWhere((t) => t.title == 'Comprar pan');
      expect(copy.completedAt, bread);
      final daily = restored.singleWhere((t) => t.title == 'Regar las plantas');
      expect(daily.completedDates, ['2026-11-01', '2026-11-02']);
      expect(daily.completedTimes, {'2026-11-02': plants});
      expect(daily.completedAt, isNull);
    });

    test('UX-2311: an archive with no times imports as before', () async {
      await database.insertTasks([
        Task(title: 'Comprar pan', priority: 1, isCompleted: true),
        Task(
            title: 'Regar las plantas',
            priority: 1,
            dueDate: DateTime(2026, 11, 1, 9),
            recurrence: 'daily',
            completedDates: ['2026-11-01']),
      ]);
      final data = jsonDecode(await ArchiveStore(database, 'local').export())
          as Map<String, dynamic>;
      // As an export from before the app kept times.
      for (final task in data['tasks'] as List) {
        (task as Map).remove('completed_at');
        task.remove('completed_times');
      }
      final archive = TaskArchive.parse(jsonEncode(data));
      expect(archive.tasks.every((row) => row.error == null), isTrue);
      final target = ArchiveStore(database, 'account-B');
      final result = await target.import(
          archive, archive.tasks.map((row) => row.sourceId).toSet());
      expect(result.added, 2);
      final restored = await database.getTasks(ownerKey: 'account-B');
      final copy = restored.singleWhere((t) => t.title == 'Comprar pan');
      expect(copy.isCompleted, isTrue);
      expect(copy.completedAt, isNull);
      final daily = restored.singleWhere((t) => t.title == 'Regar las plantas');
      expect(daily.completedDates, ['2026-11-01']);
      expect(daily.completedTimes, isEmpty);
    });

    test('UX-2311: a time that isn’t a date-time, or a key that isn’t a completed date, is left out, never an error', () {
      final task = TaskArchive.validatedTask({
        ...Task(
          title: 'Regar las plantas',
          priority: 1,
          dueDate: DateTime(2026, 11, 1, 9),
          recurrence: 'daily',
          completedDates: ['2026-11-01'],
        ).toApi(),
        'id': const Uuid().v4(),
        'completed_at': 'yesterday',
        'completed_times': {
          '2026-11-01': 'not a time',
          '2026-11-05': '2026-11-05T08:00:00.000Z',
        },
      });
      expect(task.completedAt, isNull);
      expect(task.completedTimes, isEmpty);
    });
  });
}
