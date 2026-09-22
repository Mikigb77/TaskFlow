import 'dart:convert';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/reminder_engine.dart';
import 'package:agenda/services/reminder_preferences.dart';
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
    await TaskDatabase.upgrade(sql, 3, 7);
    database = TaskDatabase.forTesting(sql);
    now = DateTime(2026, 9, 22, 8);
    driver = _Driver();
    engine = ReminderEngine(database, driver, clock: () => now);
    await engine.activate('local');
  });
  tearDown(() => database.close());

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
  bool allowed = true;
  bool exact = true;
  bool fail = false;
  int schedules = 0;
  final Map<int, PlannedReminder> pending = {};
  @override
  Future<ReminderCapability> capability() async =>
      ReminderCapability(allowed: allowed, exact: exact);
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
