import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/occurrence_exception.dart';
import 'package:agenda/services/reminder_engine.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/reminder_copy.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late TaskDatabase database;
  late _Driver driver;
  late ReminderEngine engine;
  late DateTime now;
  Future<List<Map<String, Object?>>> alerts() async => (await database.database)
      .query('reminder_state', where: 'status != ?', whereArgs: ['inactive']);
  Future<void> enable(
      {String owner = 'local',
      int? dateOnly,
      int? morning,
      int? evening}) async {
    await ReminderPreferenceStore(database).write(
        owner,
        ReminderPreferences(
            enabled: true,
            dateOnlyTime: dateOnly,
            morning: morning,
            evening: evening));
  }

  setUp(() async {
    final sql = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await sql.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)');
    await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
    database = TaskDatabase.forTesting(sql);
    now = DateTime(2026, 9, 22, 8);
    driver = _Driver();
    engine = ReminderEngine(database, driver, clock: () => now);
    await engine.activate('local');
  });
  tearDown(() => database.close());

  test('a competing refresh includes edits made after the first snapshot',
      () async {
    await enable();
    await database.insertTask(Task(
        title: 'First task',
        priority: 1,
        dueDate: now.add(const Duration(hours: 1))));
    final snapshotRead = Completer<void>();
    final release = Completer<void>();
    driver.beforeCapability = () async {
      driver.beforeCapability = null;
      snapshotRead.complete();
      await release.future;
    };
    final first = engine.reconcile('local');
    await snapshotRead.future;
    await database.insertTask(Task(
        title: 'New task',
        priority: 1,
        dueDate: now.add(const Duration(hours: 2))));
    final other = ReminderEngine(database, driver, clock: () => now);
    final second = other.reconcile('local');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    release.complete();
    await Future.wait([first, second]).timeout(const Duration(seconds: 3));
    expect(driver.pending.values.map((notice) => notice.title).toSet(),
        {'First task', 'New task'});
    expect(
        await (await database.database)
            .query('reminder_meta', where: 'key = ?', whereArgs: ['lease']),
        isEmpty);
  });

  test('a busy reminder lease reports retryable failure without stealing it',
      () async {
    await (await database.database).insert('reminder_meta', {
      'key': 'lease',
      'value': jsonEncode({
        'token': 'other-worker',
        'until': now.toUtc().add(const Duration(minutes: 1)).toIso8601String()
      })
    });
    final waiting = ReminderEngine(database, driver,
        clock: () => now, leaseWait: const Duration(milliseconds: 20));
    await expectLater(
        waiting.reconcile('local'), throwsA(isA<TimeoutException>()));
    final lease = await (await database.database)
        .query('reminder_meta', where: 'key = ?', whereArgs: ['lease']);
    expect(
        jsonDecode(lease.single['value'] as String)['token'], 'other-worker');
    expect(driver.pending, isEmpty);
  });

  test('pending copy changes language without changing tasks, IDs or times',
      () async {
    final regional = RegionalPreferenceStore(database);
    await regional.write(const RegionalPreferences(language: 'en'));
    await enable(dateOnly: 600, morning: 540, evening: 1080);
    await database.insertTasks([
      Task(
          title: 'Original appointment',
          priority: 1,
          dueDate: now.add(const Duration(hours: 2)),
          reminderMinutes: 0,
          notes: 'Keep my words unchanged'),
      Task(
          title: 'Original report',
          priority: 2,
          deadline: now.add(const Duration(hours: 4)),
          deadlineHasTime: true,
          reminderAnchor: 'deadline',
          reminderMinutes: 60),
      Task(
          title: 'Original date-only',
          priority: 1,
          dueDate: Task.day(now),
          hasTime: false),
      Task(
          title: 'Original single minute',
          priority: 1,
          dueDate: now.add(const Duration(hours: 1)),
          reminderMinutes: 1),
    ]);
    final originalTasks = await (await database.database).query('tasks');
    await engine.reconcile('local');
    expect(driver.pending.length, 6);
    expect(
        driver.pending.values
            .singleWhere((p) => p.title == 'Original single minute')
            .body,
        'Scheduled in 1 minute.');
    final times = {
      for (final entry in driver.pending.entries) entry.key: entry.value.when
    };
    final originalRows = await alerts();
    await regional.write(const RegionalPreferences(language: 'es'));
    await engine.reconcile('local');
    expect({
      for (final entry in driver.pending.entries) entry.key: entry.value.when
    }, times);
    expect(driver.pending.values.every((p) => p.languageCode == 'es'), isTrue);
    expect(driver.pending.values.map((p) => p.body).toSet(), {
      'Es hora de tu tarea.',
      'Se acerca la fecha límite de tu tarea.',
      'En tu lista para hoy.',
      'Programada dentro de 1 minuto.',
      'Abre TaskFlow para ver tus tareas actuales y decidir tu próximo paso.',
    });
    expect(
        driver.pending.values.where((p) => p.daily).map((p) => p.title).toSet(),
        {'Organiza tu día', 'Un momento para revisar'});
    expect(await (await database.database).query('tasks'), originalTasks);
    final translatedRows = await alerts();
    for (final row in translatedRows) {
      final old = originalRows.singleWhere((old) => old['id'] == row['id']);
      expect(row['identity'], old['identity']);
      expect(row['fire_at'], old['fire_at']);
      expect(row['due_at'], old['due_at']);
      expect(row['token'], isNot(old['token']));
    }
    final schedules = driver.schedules;
    await engine.reconcile('local');
    expect(driver.schedules, schedules,
        reason: 'Do not reschedule unchanged translated alerts.');
    expect(await alerts(), translatedRows);
  });

  test('a recreated background engine localizes a snooze without moving it',
      () async {
    final regional = RegionalPreferenceStore(database);
    await regional.write(const RegionalPreferences(language: 'en'));
    await enable();
    await database.insertTask(Task(
        title: 'My own title',
        priority: 1,
        dueDate: now.add(const Duration(hours: 1))));
    await engine.reconcile('local');
    var alert = (await alerts()).single;
    final id = alert['id'] as int;
    now = now.add(const Duration(minutes: 50));
    expect(await engine.action(id, 'snooze', token: alert['token'] as String),
        isTrue);
    final snoozedAt = driver.pending[id]!.when;
    expect(driver.pending[id]!.body, 'Your snoozed task.');
    alert = (await alerts()).single;
    await regional.write(const RegionalPreferences(language: 'es'));
    engine = ReminderEngine(database, driver, clock: () => now);
    await engine.reconcile('local');
    expect(driver.pending[id]!.when, snoozedAt);
    expect(driver.pending[id]!.body, 'Tu tarea pospuesta.');
    expect(driver.pending[id]!.title, 'My own title');
    expect(await engine.action(id, 'complete', token: alert['token'] as String),
        isFalse);
    final current = (await alerts()).single;
    expect(
        await engine.action(id, 'complete', token: current['token'] as String),
        isTrue);
    expect((await database.getTasks()).single.isCompleted, isTrue);
    expect(await (await database.database).query('reminder_snoozes'), isEmpty);
  });

  test('an already delivered action remains valid after a language change',
      () async {
    final regional = RegionalPreferenceStore(database);
    await regional.write(const RegionalPreferences(language: 'en'));
    await enable();
    await database.insertTask(Task(
        title: 'Recurring original',
        priority: 1,
        dueDate: now.add(const Duration(hours: 1)),
        recurrence: 'daily',
        repeatUntil: now.add(const Duration(days: 1))));
    await engine.reconcile('local');
    final delivered = (await alerts())
        .singleWhere((row) => row['occurrence'] == '2026-09-22');
    final id = delivered['id'] as int;
    driver.pending.remove(id); // OS has delivered this occurrence.
    now = now.add(const Duration(hours: 1, seconds: 1));
    await regional.write(const RegionalPreferences(language: 'es'));
    await engine.reconcile('local');
    final retained = (await alerts()).singleWhere((row) => row['id'] == id);
    expect(retained['token'], delivered['token']);
    expect(retained['status'], 'elapsed');
    expect(
        await engine.action(id, 'complete',
            token: delivered['token'] as String),
        isTrue);
    final task = (await database.getTasks()).single;
    expect(task.completedDates, ['2026-09-22']);
    expect(task.occurrenceByKey('2026-09-23')!.isCompleted, isFalse);
    expect(driver.pending.values.single.languageCode, 'es');
  });

  test(
      'background language resolution follows the UI preference and device fallback',
      () async {
    final regional = RegionalPreferenceStore(database);
    await regional.write(const RegionalPreferences());
    expect(
        (await readReminderStrings(database, deviceLocales: [
          const Locale('fr', 'FR'),
          const Locale('es', 'ES')
        ]))
            .localeName,
        'es');
    expect(
        (await readReminderStrings(database,
                deviceLocales: [const Locale('de', 'DE')]))
            .localeName,
        'en');
    await regional.write(const RegionalPreferences(language: 'en'));
    expect(
        (await readReminderStrings(database,
                deviceLocales: [const Locale('es', 'ES')]))
            .localeName,
        'en');
    await (await database.database).update(
        'app_preferences', {'data': 'invalid json'},
        where: 'scope = ?', whereArgs: ['regional']);
    expect(
        (await readReminderStrings(database,
                deviceLocales: [const Locale('es', 'ES')]))
            .localeName,
        'es');
  });

  test(
      'deadline snooze survives a planned move and completes the original occurrence',
      () async {
    await enable();
    await database.insertTask(Task(
        title: 'Report',
        priority: 2,
        dueDate: DateTime(2026, 9, 22, 10),
        deadline: DateTime(2026, 9, 22, 17),
        deadlineHasTime: true,
        reminderAnchor: 'deadline',
        reminderMinutes: 60,
        recurrence: 'daily',
        repeatUntil: DateTime(2026, 9, 23)));
    await engine.reconcile('local');
    final original =
        (await alerts()).firstWhere((row) => row['occurrence'] == '2026-09-22');
    final id = original['id'] as int;
    now = DateTime(2026, 9, 22, 16);
    expect(await engine.action(id, 'snooze'), isTrue);
    final snoozed = driver.pending[id]!.when;
    var task = (await database.getTasks()).single;
    await database.updateTask(task.copyWith(exceptions: [
      OccurrenceException(
          originalDate: '2026-09-22',
          date: DateTime(2026, 9, 23, 11),
          hasTime: true)
    ]));
    await engine.reconcile('local');
    expect(driver.pending[id]!.when, snoozed);
    expect((await engine.taskForAlert(id))!.displayDate,
        DateTime(2026, 9, 23, 11));
    expect((await engine.taskForAlert(id))!.displayDeadline,
        DateTime(2026, 9, 22, 17));
    expect(await engine.action(id, 'complete'), isTrue);
    task = (await database.getTasks()).single;
    expect(task.completedDates, ['2026-09-22']);
    final remaining = (await alerts()).single;
    await database
        .updateTask(task.copyWith(deadline: DateTime(2026, 9, 22, 18)));
    expect(
        await engine.action(remaining['id'] as int, 'complete',
            token: remaining['token'] as String),
        isFalse);
    await engine.reconcile('local');
    expect(driver.pending.values.single.due, DateTime(2026, 9, 23, 18));
    expect((await alerts()).single['token'], isNot(remaining['token']));
  });

  test(
      'move collision and skip reconcile only affected identities; notification completes original date',
      () async {
    await enable();
    await database.insertTask(Task(
        title: 'Daily',
        priority: 1,
        dueDate: DateTime(2026, 9, 22, 10),
        recurrence: 'daily',
        repeatUntil: DateTime(2026, 9, 24)));
    await engine.reconcile('local');
    final original =
        (await alerts()).firstWhere((row) => row['occurrence'] == '2026-09-22');
    final unchanged =
        (await alerts()).firstWhere((row) => row['occurrence'] == '2026-09-23');
    var task = (await database.getTasks()).single;
    await database.updateTask(task.copyWith(exceptions: [
      OccurrenceException(
          originalDate: '2026-09-22',
          date: DateTime(2026, 9, 23, 9),
          hasTime: true),
      const OccurrenceException(originalDate: '2026-09-24', skipped: true),
    ]));
    await engine.reconcile('local');
    expect(driver.pending.length, 2);
    final moved =
        (await alerts()).firstWhere((row) => row['occurrence'] == '2026-09-22');
    expect(moved['id'], original['id']);
    expect(moved['token'], isNot(original['token']));
    final remaining =
        (await alerts()).firstWhere((row) => row['occurrence'] == '2026-09-23');
    expect(remaining['id'], unchanged['id']);
    expect(remaining['token'], unchanged['token']);
    expect(
        await engine.action(original['id'] as int, 'complete',
            token: original['token'] as String),
        isFalse);
    expect(
        await engine.action(moved['id'] as int, 'complete',
            token: moved['token'] as String),
        isTrue);
    task = (await database.getTasks()).single;
    expect(task.completedDates, ['2026-09-22']);
    expect(task.occurrenceByKey('2026-09-23')!.isCompleted, isFalse);
    expect(driver.pending.values.single.occurrence, '2026-09-23');
  });

  test('no permission or default alert is implied by task priority', () async {
    await database.insertTasks([
      for (final p in [1, 2, 3])
        Task(
            title: 'Task $p',
            priority: p,
            dueDate: now.add(const Duration(hours: 1)))
    ]);
    await engine.reconcile('local');
    expect(driver.pending, isEmpty);
    await enable();
    await engine.reconcile('local');
    expect(driver.pending.length, 3);
    expect(
        driver.pending.values
            .every((r) => r.when == now.add(const Duration(minutes: 50))),
        isTrue);
  });

  test('off, explicit lead, Inbox and date-only alert time remain independent',
      () async {
    await enable(dateOnly: 600);
    await database.insertTasks([
      Task(
          title: 'Off',
          priority: 3,
          dueDate: now.add(const Duration(hours: 1)),
          reminderMinutes: -1),
      Task(
          title: 'At time',
          priority: 1,
          dueDate: now.add(const Duration(hours: 1)),
          reminderMinutes: 0),
      Task(title: 'Inbox', priority: 3),
      Task(title: 'Day', priority: 1, dueDate: Task.day(now), hasTime: false),
      Task(
          title: 'Day explicit',
          priority: 1,
          dueDate: Task.day(now),
          hasTime: false,
          reminderTime: 660),
    ]);
    await engine.reconcile('local');
    expect(driver.pending.values.map((a) => a.title).toSet(),
        {'At time', 'Day', 'Day explicit'});
    expect(driver.pending.values.firstWhere((a) => a.title == 'Day').when.hour,
        10);
    expect(
        driver.pending.values
            .firstWhere((a) => a.title == 'Day explicit')
            .when
            .hour,
        11);
    final roundTrip = Task.fromApi((await database.getTasks())
        .firstWhere((task) => task.title == 'Day explicit')
        .toApi());
    expect(roundTrip.reminderTime, 660);
  });

  test(
      'stable IDs avoid rescheduling unchanged tasks and surface permission and scheduling failures',
      () async {
    await enable();
    final taskId = await database.insertTask(Task(
        title: 'Low priority',
        priority: 1,
        dueDate: now.add(const Duration(hours: 2))));
    await engine.reconcile('local');
    final id = driver.pending.keys.single;
    expect((await alerts()).single['status'], 'scheduled');
    await engine.reconcile('local');
    expect(driver.schedules, 1);
    driver.allowed = false;
    await engine.reconcile('local');
    expect(driver.pending, isEmpty);
    expect((await alerts()).single['status'], 'blocked');
    driver.allowed = true;
    driver.exact = false;
    await engine.reconcile('local');
    expect(driver.pending.keys.single, id);
    expect((await alerts()).single['status'], 'approximate');
    final task = (await database.getTasks()).single;
    await database.updateTask(task.copyWith(id: taskId, title: 'Edited title'));
    driver.fail = true;
    await engine.reconcile('local');
    expect(driver.pending, isEmpty,
        reason: 'Do not retain the old alert after a failed edit.');
    expect((await alerts()).single['status'], 'failed');
    driver.fail = false;
    await engine.reconcile('local');
    expect(driver.pending[id]!.title, 'Edited title');
  });

  test(
      'snooze survives edits and completion changes only the notified occurrence',
      () async {
    const owner = 'http://server/users/7';
    await engine.activate(owner);
    await enable(owner: owner);
    await database.insertTask(
        Task(
            title: 'Every day',
            priority: 1,
            dueDate: now.add(const Duration(hours: 1)),
            recurrence: 'daily',
            repeatUntil: now.add(const Duration(days: 2))),
        ownerKey: owner);
    await engine.reconcile(owner);
    final id = driver.pending.entries
        .firstWhere((e) => e.value.occurrence == '2026-09-22')
        .key;
    now = now.add(const Duration(minutes: 50));
    expect(await engine.action(id, 'snooze'), isTrue);
    final when = driver.pending[id]!.when;
    var task = (await database.getTasks(ownerKey: owner)).single;
    await database.updateTask(task.copyWith(notes: 'An unrelated edit'),
        ownerKey: owner);
    now = now.add(const Duration(minutes: 1));
    await engine.reconcile(owner);
    expect(driver.pending[id]!.when, when);
    expect((await engine.taskForAlert(id))!.occurrenceDate,
        DateTime(2026, 9, 22, 9));
    expect(await engine.action(id, 'complete'), isTrue);
    task = (await database.getTasks(ownerKey: owner)).single;
    expect(task.completedDates, ['2026-09-22']);
    expect(task.occurrenceOn(now.add(const Duration(days: 1)))!.isCompleted,
        isFalse);
    expect((await database.pending(owner)).single['sync_pending'], 1);
    expect(await engine.action(id, 'complete'), isFalse);
    expect(driver.pending.containsKey(id), isFalse);
  });

  test('stale actions cannot complete moved, deleted or another account tasks',
      () async {
    await enable();
    await database.insertTask(Task(
        title: 'Appointment',
        priority: 2,
        dueDate: now.add(const Duration(hours: 1))));
    await engine.reconcile('local');
    final id = driver.pending.keys.single;
    final originalToken = (await alerts()).single['token'] as String;
    var task = (await database.getTasks()).single;
    await database
        .updateTask(task.copyWith(dueDate: now.add(const Duration(hours: 3))));
    expect(await engine.action(id, 'complete'), isFalse);
    await engine.reconcile('local');
    expect(await engine.action(id, 'complete', token: originalToken), isFalse,
        reason:
            'The old delivered notification must not act on an updated schedule.');
    expect(await engine.taskForAlert(id, token: originalToken), isNull);
    await engine.activate('other');
    expect(driver.pending, isEmpty);
    expect(await engine.action(id, 'complete'), isFalse);
    expect((await database.getTasks()).single.isCompleted, isFalse);
    await engine.activate('local');
    await database.deleteTask(task.id!);
    expect(await engine.action(id, 'snooze'), isFalse);
  });

  test(
      'refresh reconciles OS loss and bounded window replenishes with generic continuing check-ins',
      () async {
    engine = ReminderEngine(database, driver, clock: () => now, capacity: 4);
    await enable(morning: 8 * 60, evening: 20 * 60);
    await database.insertTask(Task(
        title: 'Repeating private title',
        priority: 1,
        dueDate: DateTime(2026, 9, 22, 10),
        recurrence: 'daily',
        repeatUntil: DateTime(2026, 9, 27)));
    await engine.reconcile('local');
    expect(driver.pending.length, 4);
    final checkins = driver.pending.values.where((p) => p.daily).toList();
    expect(checkins.length, 2);
    expect(checkins.every((p) => !p.body.contains('private title')), isTrue);
    final initialIds = driver.pending.keys.toSet();
    driver.pending.clear(); // OS schedules missing after revocation or restore.
    await engine.reconcile('local');
    expect(driver.pending.keys.toSet(), initialIds);
    now = now.add(const Duration(days: 2));
    await engine.reconcile('local');
    expect(
        driver.pending.values
            .where((p) => !p.daily)
            .map((p) => p.occurrence)
            .toSet(),
        {'2026-09-24', '2026-09-25'});
    final rows = await (await database.database)
        .query('reminder_meta', where: 'key = ?', whereArgs: ['window']);
    expect(jsonDecode(rows.single['value'] as String)['deferred'], 2);
  });

  test('preferences are account isolated and disabling clears scheduled alerts',
      () async {
    await enable();
    await database.insertTask(Task(
        title: 'Task',
        priority: 1,
        dueDate: now.add(const Duration(hours: 1))));
    await engine.reconcile('local');
    expect((await ReminderPreferenceStore(database).read('other')).enabled,
        isFalse);
    await ReminderPreferenceStore(database)
        .write('local', const ReminderPreferences());
    await engine.reconcile('local');
    expect(driver.pending, isEmpty);
    expect(await alerts(), isEmpty);
  });
}

class _Driver implements ReminderDriver {
  Future<void> Function()? beforeCapability;
  bool allowed = true;
  bool exact = true;
  bool fail = false;
  int schedules = 0;
  final Map<int, PlannedReminder> pending = {};
  @override
  Future<ReminderCapability> capability() async {
    await beforeCapability?.call();
    return ReminderCapability(allowed: allowed, exact: exact);
  }

  @override
  Future<Set<int>> pendingIds() async => pending.keys.toSet();
  @override
  Future<void> cancel(int id) async {
    pending.remove(id);
  }

  @override
  Future<void> schedule(int id, PlannedReminder reminder,
      {required bool exact, required String token}) async {
    schedules++;
    if (fail) throw StateError('Scheduling rejected');
    pending[id] = reminder;
  }
}
