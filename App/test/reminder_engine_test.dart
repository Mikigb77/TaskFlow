import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/occurrence_exception.dart';
import 'package:agenda/services/reminder_engine.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/reminder_copy.dart';
import 'package:agenda/services/app_language.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/notification_service.dart' show TaskReminders;
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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
        'Today at 9:00 AM · in 1 min');
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
      'Hoy a las 10:00 a. m.',
      'Fecha límite: hoy a las 12:00 p. m.',
      'En tu lista para hoy.',
      'Hoy a las 9:00 a. m. · en 1 min',
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
    expect(driver.pending[id]!.body, 'Today at 9:00 AM');
    alert = (await alerts()).single;
    await regional.write(const RegionalPreferences(language: 'es'));
    engine = ReminderEngine(database, driver, clock: () => now);
    await engine.reconcile('local');
    expect(driver.pending[id]!.when, snoozedAt);
    expect(driver.pending[id]!.body, 'Hoy a las 9:00 a. m.');
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
        (await readReminderStrings(database,
                deviceLocales: [const Locale('ca', 'ES')]))
            .notificationComplete,
        'Completa');
    await regional.write(const RegionalPreferences(language: 'ca'));
    expect(
        (await readReminderStrings(database,
                deviceLocales: [const Locale('en', 'US')]))
            .notificationSnooze,
        'Ajorna 10 min');
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

  test('every reminder said for a task rings: 20 and 5 minutes before',
      () async {
    await enable();
    final meeting = DateTime(2026, 9, 22, 10);
    await database.insertTasks([
      Task(
          title: 'Reunión',
          priority: 1,
          dueDate: meeting,
          reminderMinutes: 20,
          reminderExtraMinutes: [5, 0, 20]),
      // Off is off, whatever else was said.
      Task(
          title: 'Off',
          priority: 1,
          dueDate: meeting,
          reminderMinutes: -1,
          reminderExtraMinutes: [5]),
    ]);
    await engine.reconcile('local');
    final rings = driver.pending.values.toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    expect(rings.map((a) => (a.title, a.when)), [
      ('Reunión', DateTime(2026, 9, 22, 9, 40)),
      ('Reunión', DateTime(2026, 9, 22, 9, 55)),
      ('Reunión', meeting),
    ]);
    expect(rings.map((a) => a.identity).toSet(), hasLength(3));
    // Each says how far the meeting is.
    expect(rings.first.body, isNot(rings[1].body));

    // An extra one still ahead after the first rang is still set, and the
    // task's reminder hasn't passed.
    now = DateTime(2026, 9, 22, 9, 45);
    await engine.reconcile('local');
    expect(
        driver.pending.values
            .where((a) => a.when.isAfter(now))
            .map((a) => a.when),
        unorderedEquals([DateTime(2026, 9, 22, 9, 55), meeting]));
    final task = (await database.getTasks())
        .firstWhere((task) => task.title == 'Reunión');
    expect(
        ReminderEngine.alertAhead(task, const ReminderPreferences(), now),
        isTrue);

    // Back to one reminder: the extra ones go.
    await database.updateTask(task.copyWith(reminderExtraMinutes: const []));
    await engine.reconcile('local');
    expect(driver.pending.values.where((a) => a.when.isAfter(now)), isEmpty);
  });

  test('extra reminders survive the phone and the server unchanged', () {
    final task = Task(
        title: 'Reunión',
        priority: 1,
        dueDate: DateTime(2026, 9, 22, 10),
        reminderMinutes: 20,
        reminderExtraMinutes: [5]);
    expect(Task.fromMap(task.toMap()).reminderExtraMinutes, [5]);
    expect(task.toApi()['reminder_extra_minutes'], [5]);
    expect(Task.fromApi(task.toApi()).reminderExtraMinutes, [5]);
    // An older server sends none.
    expect(
        Task.fromApi(task.toApi()..remove('reminder_extra_minutes'))
            .reminderExtraMinutes,
        isEmpty);
    expect(
        () => Task(title: 'Nota', kind: 'note', priority: 1, reminderExtraMinutes: [5]),
        throwsArgumentError);
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

  // UX-409 / P29: the body leads with the clock time, in the alert's
  // language and the stored 12/24-hour choice, so it stays true however late
  // the phone delivers it.
  group('UX-409: reminder bodies say when', () {
    Future<String> bodyOf(Task task, RegionalPreferences regional) async {
      await RegionalPreferenceStore(database).write(regional);
      await enable();
      await database.insertTask(task);
      await engine.reconcile('local');
      return driver.pending.values
          .singleWhere((p) => p.title == task.title)
          .body;
    }

    const es24 =
        RegionalPreferences(language: 'es', clock: ClockFormat.twentyFour);
    const ca24 =
        RegionalPreferences(language: 'ca', clock: ClockFormat.twentyFour);
    const en12 = RegionalPreferences(language: 'en', clock: ClockFormat.twelve);
    Task timed(DateTime due, int lead) =>
        Task(title: 'Cita', priority: 1, dueDate: due, reminderMinutes: lead);
    Task deadline(DateTime due) => Task(
        title: 'Informe',
        priority: 2,
        deadline: due,
        deadlineHasTime: true,
        reminderAnchor: 'deadline',
        reminderMinutes: 60);

    test('UX-409: a timed alert in Spanish reads Hoy a las 17:00 · en 10 min',
        () async {
      expect(await bodyOf(timed(DateTime(2026, 9, 22, 17), 10), es24),
          'Hoy a las 17:00 · en 10 min');
    });

    test(
        'UX-409: a timed alert in English with a 12-hour clock reads Today at 5:00 PM · in 10 min',
        () async {
      expect(await bodyOf(timed(DateTime(2026, 9, 22, 17), 10), en12),
          'Today at 5:00 PM · in 10 min');
    });

    test('UX-409: a timed alert in Catalan reads Avui a les 17:00 · d’aquí a 10 min',
        () async {
      expect(await bodyOf(timed(DateTime(2026, 9, 22, 17), 10), ca24),
          'Avui a les 17:00 · d’aquí a 10 min');
    });

    test('UX-409: the stored clock choice wins over the language default',
        () async {
      expect(
          await bodyOf(
              timed(DateTime(2026, 9, 22, 17), 10),
              const RegionalPreferences(
                  language: 'en', clock: ClockFormat.twentyFour)),
          'Today at 17:00 · in 10 min');
    });

    test('UX-409: the phone’s 24-hour setting is followed when the clock is System',
        () async {
      await RegionalPreferenceStore(database)
          .write(const RegionalPreferences(language: 'es'));
      final copy = await readReminderCopy(database, system24Hour: true);
      final task = timed(DateTime(2026, 9, 22, 17), 10);
      expect(copy.body(task, DateTime(2026, 9, 22, 16, 50), 10),
          'Hoy a las 17:00 · en 10 min');
    });

    test('UX-409: one o’clock uses a la in Spanish and Catalan', () async {
      // Fires at 0:50 on the 23rd, for a task at 1:00 that same day. The
      // 24-hour time is written as the app writes it (HH:mm in Spanish and
      // Catalan); what matters here is the singular article.
      final one = timed(DateTime(2026, 9, 23, 1), 10);
      expect(await bodyOf(one, es24), 'Hoy a la 01:00 · en 10 min');
      await database.deleteTask((await database.getTasks()).single.id!);
      expect(await bodyOf(one, ca24), 'Avui a la 01:00 · d’aquí a 10 min');
      // Other hours keep the plural article.
      await database.deleteTask((await database.getTasks()).single.id!);
      expect(await bodyOf(timed(DateTime(2026, 9, 22, 13), 10), es24),
          'Hoy a las 13:00 · en 10 min');
    });

    test('UX-409: 1:00 p. m. on a 12-hour clock also uses a la', () async {
      final body = await bodyOf(
          timed(DateTime(2026, 9, 22, 13), 10),
          const RegionalPreferences(
              language: 'es', clock: ClockFormat.twelve));
      expect(body, startsWith('Hoy a la 1:00'));
      expect(body, endsWith(' · en 10 min'));
    });

    test('UX-409: an alert the day before says Mañana / Tomorrow / Demà',
        () async {
      // A day ahead: fires on the 22nd for a task on the 23rd.
      final task = timed(DateTime(2026, 9, 23, 17), 1440);
      expect(await bodyOf(task, es24), 'Mañana a las 17:00');
      await database.deleteTask((await database.getTasks()).single.id!);
      expect(await bodyOf(task, en12), 'Tomorrow at 5:00 PM');
      await database.deleteTask((await database.getTasks()).single.id!);
      expect(await bodyOf(task, ca24), 'Demà a les 17:00');
    });

    test('UX-409: an alert further ahead names the weekday date', () async {
      // Fires on the 23rd for Friday the 25th.
      final body =
          await bodyOf(timed(DateTime(2026, 9, 25, 17), 2880), es24);
      // The line starts with the date, so its first letter is upper-case.
      final date = DateFormat.MMMEd('es').format(DateTime(2026, 9, 25));
      expect(body,
          '${date[0].toUpperCase()}${date.substring(1)} a las 17:00');
    });

    test('UX-409: a deadline alert says when the deadline is, in each language',
        () async {
      final task = deadline(DateTime(2026, 9, 22, 17));
      expect(await bodyOf(task, es24), 'Fecha límite: hoy a las 17:00');
      await database.deleteTask((await database.getTasks()).single.id!);
      expect(await bodyOf(task, en12), 'Deadline: today at 5:00 PM');
      await database.deleteTask((await database.getTasks()).single.id!);
      expect(await bodyOf(task, ca24), 'Termini: avui a les 17:00');
    });

    test(
        'UX-409: a snoozed alert says when the task is, without the stale tail.',
        () async {
      final task = timed(DateTime(2026, 9, 22, 17), 10);
      final original = await bodyOf(task, es24);
      expect(original, 'Hoy a las 17:00 · en 10 min');
      final alert = (await alerts()).single;
      final id = alert['id'] as int;
      // Delivered at 16:50; the person taps Posponer 10 min.
      now = DateTime(2026, 9, 22, 16, 51);
      driver.pending.remove(id);
      expect(
          await engine.action(id, 'snooze', token: alert['token'] as String),
          isTrue);
      expect(driver.pending[id]!.when, isNot(DateTime(2026, 9, 22, 16, 50)));
      expect(driver.pending[id]!.body, 'Hoy a las 17:00');
      // A later refresh keeps it.
      await engine.reconcile('local');
      expect(driver.pending[id]!.body, 'Hoy a las 17:00');
      expect(driver.pending[id]!.body, isNot(contains('pospuesta')));
    });

    // ---- Round 2 (b10) · P117: snoozes say only when, dates start capitalised ----

    /// Plans [task], lets the phone deliver its alert, then taps Posponer at
    /// [at]. Returns the alert id.
    Future<int> snoozeAt(
        Task task, RegionalPreferences regional, DateTime at) async {
      await bodyOf(task, regional);
      final alert = (await alerts()).single;
      final id = alert['id'] as int;
      now = at;
      driver.pending.remove(id);
      expect(
          await engine.action(id, 'snooze', token: alert['token'] as String),
          isTrue);
      return id;
    }

    test(
        'UX-409: after Posponer at 16:51 the alert reads exactly Hoy a las 17:00, also after a refresh',
        () async {
      final task = timed(DateTime(2026, 9, 22, 17), 10);
      expect(await bodyOf(task, es24), 'Hoy a las 17:00 · en 10 min');
      await database.deleteTask((await database.getTasks()).single.id!);
      final id =
          await snoozeAt(task, es24, DateTime(2026, 9, 22, 16, 51));
      final snoozed = driver.pending[id]!;
      expect(snoozed.body, 'Hoy a las 17:00');
      expect(snoozed.body, isNot(contains('en 10 min')));
      expect(snoozed.body, isNot(contains('pospuesta')));
      await engine.reconcile('local');
      expect(driver.pending[id]!.body, 'Hoy a las 17:00');
      expect(driver.pending[id]!.body, isNot(contains('en 10 min')));
      expect(driver.pending[id]!.body, isNot(contains('pospuesta')));
    });

    test(
        'UX-409: a snoozed alert in English with a 12-hour clock reads exactly Today at 5:00 PM',
        () async {
      final task = timed(DateTime(2026, 9, 22, 17), 10);
      final id = await snoozeAt(task, en12, DateTime(2026, 9, 22, 16, 51));
      expect(driver.pending[id]!.body, 'Today at 5:00 PM');
      await engine.reconcile('local');
      expect(driver.pending[id]!.body, 'Today at 5:00 PM');
    });

    test(
        'UX-409: a snoozed alert in Catalan with a 24-hour clock reads exactly Avui a les 17:00',
        () async {
      final task = timed(DateTime(2026, 9, 22, 17), 10);
      final id = await snoozeAt(task, ca24, DateTime(2026, 9, 22, 16, 51));
      expect(driver.pending[id]!.body, 'Avui a les 17:00');
      await engine.reconcile('local');
      expect(driver.pending[id]!.body, 'Avui a les 17:00');
    });

    test(
        'UX-409: a snooze that crosses midnight says Hoy for the task’s own day, with no tail',
        () async {
      // 00:05 on the 23rd, 10 minutes ahead: delivered at 23:55 on the 22nd.
      final task = timed(DateTime(2026, 9, 23, 0, 5), 10);
      final id = await snoozeAt(task, es24, DateTime(2026, 9, 22, 23, 56));
      final snoozed = driver.pending[id]!;
      // It comes back after midnight, on the task's own day.
      expect(Task.day(snoozed.when.toLocal()), DateTime(2026, 9, 23));
      expect(snoozed.body, startsWith('Hoy a las'));
      expect(snoozed.body, isNot(startsWith('Mañana')));
      expect(snoozed.body, isNot(contains('· en')));
      expect(snoozed.body, isNot(contains('·')));
    });

    test(
        'UX-632: two days ahead the line starts with the capitalised weekday date (Spanish and Catalan)',
        () async {
      // Planned on Tuesday the 22nd; fires on the 23rd for Friday the 25th.
      final task = timed(DateTime(2026, 9, 25, 17), 2880);
      final es = await bodyOf(task, es24);
      final date = DateFormat.MMMEd('es').format(DateTime(2026, 9, 25));
      expect(es, '${date[0].toUpperCase()}${date.substring(1)} a las 17:00');
      expect(es[0], es[0].toUpperCase());
      expect(es[0], isNot(es[0].toLowerCase()));

      await database.deleteTask((await database.getTasks()).single.id!);
      final ca = await bodyOf(task, ca24);
      expect(ca[0], ca[0].toUpperCase());
      expect(ca[0], isNot(ca[0].toLowerCase()));
      expect(ca, endsWith(' a les 17:00'));
    });

    test(
        'UX-632: a deadline alert keeps the date lowercase after Fecha límite:',
        () async {
      // Planned on Tuesday the 22nd for a deadline on Friday the 25th.
      final body = await bodyOf(
          Task(
              title: 'Informe',
              priority: 2,
              deadline: DateTime(2026, 9, 25, 17),
              deadlineHasTime: true,
              reminderAnchor: 'deadline',
              reminderMinutes: 2880),
          es24);
      final date = DateFormat.MMMEd('es').format(DateTime(2026, 9, 25));
      expect(date[0], date[0].toLowerCase());
      expect(body, 'Fecha límite: $date a las 17:00');
    });
  });

  // UX-411 / P29: Completar from the notification can be undone.
  group('UX-411: Completar from a reminder can be undone', () {
    Future<({int id, String token})> delivered(Task task,
        {String language = 'es'}) async {
      await RegionalPreferenceStore(database).write(RegionalPreferences(
          language: language, clock: ClockFormat.twentyFour));
      await enable();
      await database.insertTask(task);
      await engine.reconcile('local');
      final alert = (await alerts())
          .firstWhere((row) => row['title'] == task.title);
      final id = alert['id'] as int;
      // The phone delivers it.
      now = DateTime.parse(alert['fire_at'] as String)
          .toLocal()
          .add(const Duration(minutes: 1));
      driver.pending.remove(id);
      await engine.reconcile('local');
      final current = (await alerts()).singleWhere((row) => row['id'] == id);
      return (id: id, token: current['token'] as String);
    }

    test('UX-411: the undo copy reads Completed / Completada and Undo / Deshacer / Desfés',
        () {
      final en = lookupAppLocalizations(const Locale('en'));
      final es = lookupAppLocalizations(const Locale('es'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(en.notificationCompleted('Call the doctor'),
          'Completed: Call the doctor');
      expect(es.notificationCompleted('Llamar al médico'),
          'Completada: Llamar al médico');
      expect(ca.notificationCompleted('Trucar al metge'),
          'Completada: Trucar al metge');
      expect(en.undo, 'Undo');
      expect(es.undo, 'Deshacer');
      expect(ca.undo, 'Desfés');
    });

    test('UX-411: the undo line is replaced for about 10 seconds', () {
      expect(TaskReminders.undoWindow, const Duration(seconds: 10));
    });

    test(
        'UX-411: Completar posts Completada: {title} with Undo in the alert’s language',
        () async {
      final alert = await delivered(Task(
          title: 'Llamar al médico',
          priority: 1,
          dueDate: DateTime(2026, 9, 22, 9)));
      expect(await engine.action(alert.id, 'complete', token: alert.token),
          isTrue);
      expect((await database.getTasks()).single.isCompleted, isTrue);
      expect(driver.shown[alert.id], 'Completada: Llamar al médico');
      expect(driver.undoLanguage[alert.id], 'es');
      // The same notification is replaced, and its Undo can act.
      expect(driver.undoToken[alert.id], alert.token);
    });

    test(
        'UX-411: Undo reopens the task and brings back the reminder as it was',
        () async {
      final alert = await delivered(Task(
          title: 'Llamar al médico',
          priority: 1,
          dueDate: DateTime(2026, 9, 22, 9)));
      await engine.action(alert.id, 'complete', token: alert.token);
      expect(
          await engine.action(alert.id, 'undo',
              token: driver.undoToken[alert.id]),
          isTrue);
      expect((await database.getTasks()).single.isCompleted, isFalse);
      final restored = driver.shown[alert.id];
      expect(restored, isA<PlannedReminder>());
      restored as PlannedReminder;
      expect(restored.title, 'Llamar al médico');
      expect(restored.body, 'Hoy a las 09:00 · en 10 min');
      expect(restored.taskId, isNotNull);
      // The restored reminder's own Completar still works.
      expect(await engine.action(alert.id, 'complete', token: alert.token),
          isTrue);
      expect((await database.getTasks()).single.isCompleted, isTrue);
    });

    test('UX-411: Undo on a task that is open again does nothing', () async {
      final alert = await delivered(Task(
          title: 'Llamar al médico',
          priority: 1,
          dueDate: DateTime(2026, 9, 22, 9)));
      await engine.action(alert.id, 'complete', token: alert.token);
      expect(await engine.action(alert.id, 'undo', token: alert.token), isTrue);
      expect(await engine.action(alert.id, 'undo', token: alert.token), isFalse);
      expect((await database.getTasks()).single.isCompleted, isFalse);
    });

    test('UX-411: Undo on a repeating task reopens only that day', () async {
      final alert = await delivered(Task(
          title: 'Pastilla',
          priority: 1,
          dueDate: DateTime(2026, 9, 22, 9),
          recurrence: 'daily',
          repeatUntil: DateTime(2026, 9, 24)));
      await engine.action(alert.id, 'complete', token: alert.token);
      expect((await database.getTasks()).single.completedDates, ['2026-09-22']);
      expect(driver.shown[alert.id], 'Completada: Pastilla');
      expect(await engine.action(alert.id, 'undo', token: alert.token), isTrue);
      final task = (await database.getTasks()).single;
      expect(task.completedDates, isEmpty);
      expect(task.occurrenceByKey('2026-09-22')!.isCompleted, isFalse);
      expect(task.occurrenceByKey('2026-09-23')!.isCompleted, isFalse);
    });

    test('UX-411: in English the undo line reads Completed: {title}', () async {
      final alert = await delivered(
          Task(
              title: 'Call the doctor',
              priority: 1,
              dueDate: DateTime(2026, 9, 22, 9)),
          language: 'en');
      await engine.action(alert.id, 'complete', token: alert.token);
      expect(driver.shown[alert.id], 'Completed: Call the doctor');
      expect(driver.undoLanguage[alert.id], 'en');
    });

    test('UX-411: Posponer stays as it is: no undo line', () async {
      final alert = await delivered(Task(
          title: 'Llamar al médico',
          priority: 1,
          dueDate: DateTime(2026, 9, 22, 9)));
      expect(
          await engine.action(alert.id, 'snooze', token: alert.token), isTrue);
      expect(driver.shown, isEmpty);
      expect(driver.pending[alert.id], isNotNull);
    });
  });

  // ---- Run 2026-10-19-app · P215 (UX-1649): «Como el teléfono» in the background ----

  group('P215', () {
    Future<void> savePhoneLocales(List<String> tags) async =>
        (await database.database).insert(
            'app_preferences', {'scope': 'phone-locales', 'data': jsonEncode(tags)},
            conflictAlgorithm: ConflictAlgorithm.replace);
    setUp(() => AppLanguageBridge.phoneLocales = null);
    tearDown(() => AppLanguageBridge.phoneLocales = null);

    for (final tag in ['es-ES', 'ca-ES']) {
      test(
          'UX-1653: a background reminder with Idioma «Como el teléfono» reads Flutter’s live locales, not a stale saved row ($tag)',
          () async {
        // With no per-app language set, Flutter's locales are the phone's and
        // live, also in a background isolate; the saved row may be stale.
        expect(AppLanguageBridge.phoneLocales, isNull);
        await RegionalPreferenceStore(database)
            .write(const RegionalPreferences());
        await savePhoneLocales([tag]);
        final language = const RegionalPreferences()
            .localeFor(PlatformDispatcher.instance.locales)
            .languageCode;
        expect(language, isNot(tag.split('-').first));
        final copy = await readReminderCopy(database, system24Hour: true);
        final expected = lookupAppLocalizations(Locale(language));
        expect(copy.languageCode, language);
        expect(copy.strings.notificationToday, expected.notificationToday);
        final strings = await readReminderStrings(database);
        expect(strings.localeName, language);
      });
    }

    test(
        'UX-1649: the bridge’s fresh answer wins over the saved row; deviceLocales still wins over both',
        () async {
      await RegionalPreferenceStore(database)
          .write(const RegionalPreferences());
      await savePhoneLocales(['es-ES']);
      AppLanguageBridge.phoneLocales = [const Locale('ca', 'ES')];
      expect((await readReminderCopy(database, system24Hour: true)).languageCode,
          'ca');
      expect(
          (await readReminderCopy(database,
                  deviceLocales: [const Locale('en', 'GB')], system24Hour: true))
              .languageCode,
          'en');
    });

    // ---- Run 2026-10-19-app · P218 (UX-1653): the live locales come first ----

    // A supported language the test runner's live locales are not in, so a
    // reminder that read the saved row would show it.
    String staleLanguage() {
      final live = const RegionalPreferences()
          .localeFor(PlatformDispatcher.instance.locales)
          .languageCode;
      return live == 'ca' ? 'es' : 'ca';
    }

    test(
        'UX-1653: background isolate, Idioma «Como el teléfono», a stale saved phone-locales row: readReminderStrings and readReminderCopy follow Flutter’s live locales',
        () async {
      await RegionalPreferenceStore(database)
          .write(const RegionalPreferences());
      final stale = staleLanguage();
      await savePhoneLocales(['$stale-ES']);
      // A background isolate: the bridge has not answered there.
      expect(AppLanguageBridge.phoneLocales, isNull);
      final live = const RegionalPreferences()
          .localeFor(PlatformDispatcher.instance.locales)
          .languageCode;
      expect(live, isNot(stale));
      final strings = await readReminderStrings(database);
      expect(strings.localeName, live);
      expect(strings.notificationToday,
          lookupAppLocalizations(Locale(live)).notificationToday);
      final copy = await readReminderCopy(database, system24Hour: true);
      expect(copy.languageCode, live);
      expect(copy.languageCode, isNot(stale));
    });

    test(
        'UX-1653: Idioma English, week start «Como el teléfono», the row saved as es-ES and no bridge answer: readReminderCopy still takes the phone’s es-ES as its device locale',
        () async {
      // Off the phone's 24-hour setting, so the clock follows the device
      // locale: Spanish writes 17:00, English 5:00 PM.
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await RegionalPreferenceStore(database)
            .write(const RegionalPreferences(language: 'en'));
        await savePhoneLocales(['es-ES']);
        expect(AppLanguageBridge.phoneLocales, isNull);
        final task = Task(
            title: 'Cita',
            priority: 1,
            dueDate: DateTime(2026, 9, 22, 17),
            reminderMinutes: 10);
        final when = DateTime(2026, 9, 22, 16, 50);
        final copy = await readReminderCopy(database);
        // The app's language stays English.
        expect(copy.languageCode, 'en');
        final asSpanishPhone = await readReminderCopy(database,
            deviceLocales: [const Locale('es', 'ES')]);
        final asEnglishPhone = await readReminderCopy(database,
            deviceLocales: [const Locale('en', 'US')]);
        expect(asSpanishPhone.body(task, when, 10),
            isNot(asEnglishPhone.body(task, when, 10)));
        expect(copy.body(task, when, 10), asSpanishPhone.body(task, when, 10));
        expect(copy.body(task, when, 10), contains('17:00'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  // ---- Run 2026-10-19-app, round 1 · P190 (UX-1601): whether a task's
  // next alert can still ring ----
  group('UX-1601: ReminderEngine.alertAhead', () {
    // Monday 19 October 2026.
    final today = DateTime(2026, 10, 19);
    final at11 = DateTime(2026, 10, 19, 11);
    final at8 = DateTime(2026, 10, 19, 8);
    // Reminders off, as for an account never asked, with no date-only time.
    const off = ReminderPreferences();
    final dateOnlyToday = Task(
      id: 1,
      title: 'Llamar a Marta',
      priority: 1,
      dueDate: today,
      hasTime: false,
    );

    test(
        'UX-1601: a date-only task for today is false at 11:00 with no date-only time set (taken as 9:00), and true at 08:00',
        () {
      expect(ReminderEngine.alertAhead(dateOnlyToday, off, at11), isFalse);
      expect(ReminderEngine.alertAhead(dateOnlyToday, off, at8), isTrue);
    });

    test(
        'UX-1601: a date-only task for tomorrow is true at 11:00',
        () {
      expect(
        ReminderEngine.alertAhead(
          dateOnlyToday.copyWith(dueDate: DateTime(2026, 10, 20)),
          off,
          at11,
        ),
        isTrue,
      );
    });

    test(
        'UX-1601: a 17:00 task with a 10-minute lead is false at 16:55 and true at 16:00',
        () {
      final five = Task(
        id: 2,
        title: 'Recoger a los niños',
        priority: 1,
        dueDate: DateTime(2026, 10, 19, 17),
      );
      const lead = ReminderPreferences(leadMinutes: 10);
      expect(
        ReminderEngine.alertAhead(five, lead, DateTime(2026, 10, 19, 16, 55)),
        isFalse,
      );
      expect(
        ReminderEngine.alertAhead(five, lead, DateTime(2026, 10, 19, 16)),
        isTrue,
      );
    });

    test('UX-1601: a task with its reminder off is false, even early', () {
      expect(
        ReminderEngine.alertAhead(
          dateOnlyToday.copyWith(reminderMinutes: -1),
          off,
          at8,
        ),
        isFalse,
      );
    });

    test(
        'UX-1601: a repeating date-only task whose today alert has passed is true: its next occurrence is ahead',
        () {
      final daily = Task(
        id: 3,
        title: 'Regar las plantas',
        priority: 1,
        dueDate: DateTime(2026, 10, 18),
        hasTime: false,
        recurrence: 'daily',
      );
      expect(ReminderEngine.alertAhead(daily, off, at11), isTrue);
    });

    test(
        'UX-1601: plan() still schedules nothing for a date-only task for today at 11:00, with reminders on at 9:00',
        () {
      final planned = ReminderEngine.plan(
        'local',
        [dateOnlyToday],
        const ReminderPreferences(enabled: true, dateOnlyTime: 540),
        at11,
      );
      expect(planned.where((p) => p.taskId == 1), isEmpty);
      // And at 08:00 the same task is scheduled for 9:00: the helper and
      // the engine agree.
      final early = ReminderEngine.plan(
        'local',
        [dateOnlyToday],
        const ReminderPreferences(enabled: true, dateOnlyTime: 540),
        at8,
      );
      expect(early.where((p) => p.taskId == 1).single.when,
          DateTime(2026, 10, 19, 9));
    });
  });

  // ---- UX loop 2026-10-28-app, round 1 · P300 (UX-2311, D2): the
  // notification's Completar keeps the tick's time ----
  group('P300 · completion times', () {
    Future<({int id, String token})> delivered(Task task) async {
      await RegionalPreferenceStore(database).write(const RegionalPreferences(
          language: 'es', clock: ClockFormat.twentyFour));
      await enable();
      await database.insertTask(task);
      await engine.reconcile('local');
      final alert =
          (await alerts()).firstWhere((row) => row['title'] == task.title);
      final id = alert['id'] as int;
      now = DateTime.parse(alert['fire_at'] as String)
          .toLocal()
          .add(const Duration(minutes: 1));
      driver.pending.remove(id);
      await engine.reconcile('local');
      final current = (await alerts()).singleWhere((row) => row['id'] == id);
      return (id: id, token: current['token'] as String);
    }

    test(
        'UX-2311: «Completar» on a one-off task stores the engine clock’s time, and «Deshacer» on its notice clears it',
        () async {
      final alert = await delivered(Task(
          title: 'Llamar al médico',
          priority: 1,
          dueDate: DateTime(2026, 9, 22, 9)));
      now = DateTime(2026, 9, 22, 9, 3, 30);
      expect(await engine.action(alert.id, 'complete', token: alert.token),
          isTrue);
      var task = (await database.getTasks()).single;
      expect(task.isCompleted, isTrue);
      expect(task.completedAt, DateTime(2026, 9, 22, 9, 3, 30));
      expect(task.completedTimes, isEmpty);
      now = DateTime(2026, 9, 22, 9, 4);
      expect(
          await engine.action(alert.id, 'undo',
              token: driver.undoToken[alert.id]),
          isTrue);
      task = (await database.getTasks()).single;
      expect(task.isCompleted, isFalse);
      expect(task.completedAt, isNull);
      final row = (await (await database.database).query('tasks')).single;
      expect(row['completedAt'], isNull);
    });

    test(
        'UX-2311: «Completar» on a repeating task stores the time under that repetition’s date, and «Deshacer» clears it',
        () async {
      final alert = await delivered(Task(
          title: 'Tomar la pastilla',
          priority: 1,
          dueDate: DateTime(2026, 9, 21, 9),
          recurrence: 'daily',
          completedDates: ['2026-09-21'],
          completedTimes: {'2026-09-21': DateTime(2026, 9, 21, 9, 5)}));
      now = DateTime(2026, 9, 22, 9, 2);
      expect(await engine.action(alert.id, 'complete', token: alert.token),
          isTrue);
      var task = (await database.getTasks()).single;
      expect(task.completedDates, ['2026-09-21', '2026-09-22']);
      expect(task.completedTimes, {
        '2026-09-21': DateTime(2026, 9, 21, 9, 5),
        '2026-09-22': DateTime(2026, 9, 22, 9, 2),
      });
      expect(task.completedAt, isNull);
      expect(
          await engine.action(alert.id, 'undo',
              token: driver.undoToken[alert.id]),
          isTrue);
      task = (await database.getTasks()).single;
      expect(task.completedDates, ['2026-09-21']);
      expect(task.completedTimes, {
        '2026-09-21': DateTime(2026, 9, 21, 9, 5),
      });
    });
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

  /// What the phone shows now, by alert ID: a reminder or an undo line.
  final Map<int, Object> shown = {};
  @override
  Future<void> show(int id, PlannedReminder reminder,
      {required String token}) async {
    shown[id] = reminder;
  }

  @override
  Future<void> showUndo(int id, String text,
      {required String languageCode, required String token}) async {
    shown[id] = text;
    undoLanguage[id] = languageCode;
    undoToken[id] = token;
  }

  /// The language and token each undo line was posted with.
  final Map<int, String> undoLanguage = {};
  final Map<int, String> undoToken = {};
}
