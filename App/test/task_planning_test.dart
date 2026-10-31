import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_archive.dart';
import 'package:agenda/models/task_schedule_change.dart';
import 'package:agenda/models/occurrence_exception.dart';
import 'package:agenda/services/reminder_engine.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  sqfliteFfiInit();
  test(
      'deadline-only tasks keep dates, timed offsets and duration through storage and archive validation',
      () {
    final task = Task(
        title: 'Submit report',
        priority: 2,
        deadline: DateTime(2026, 9, 25),
        durationMinutes: 45,
        reminderAnchor: 'deadline');
    final restored =
        TaskArchive.validatedTask(Task.fromMap(task.toMap()).toApi());
    expect(restored.dueDate, isNull);
    expect(restored.deadline, DateTime(2026, 9, 25));
    expect(restored.deadlineHasTime, isFalse);
    expect(restored.durationMinutes, 45);
    expect(restored.calendarOccurrencesOn(DateTime(2026, 9, 25)), hasLength(1));
    expect(restored.deadlinePassed(DateTime(2026, 9, 25, 23, 59)), isFalse);
    expect(restored.deadlinePassed(DateTime(2026, 9, 26)), isTrue);
    final timed = Task.fromApi({
      ...task.toApi(),
      'deadline_date': null,
      'deadline_at': '2026-09-25T17:00:00+02:00'
    });
    expect(timed.deadline!.toUtc(), DateTime.utc(2026, 9, 25, 15));
    expect(Task.fromApi(timed.toApi()).deadline, timed.deadline);
    for (final values in [
      {'duration_minutes': 0},
      {'duration_minutes': 1441},
      {'duration_minutes': 1.5},
      {'deadline_at': '2026-09-25T17:00:00Z'},
      {'deadline_date': null},
      {'reminder_anchor': 'invalid'},
    ]) {
      expect(() => TaskArchive.validatedTask({...task.toApi(), ...values}),
          throwsFormatException);
    }
  });

  test(
      'moving a recurring planned occurrence keeps its original deadline and identity',
      () {
    final task = Task(
        id: 7,
        title: 'Report',
        priority: 2,
        dueDate: DateTime(2026, 9, 23, 9),
        deadline: DateTime(2026, 9, 25, 17),
        deadlineHasTime: true,
        durationMinutes: 60,
        recurrence: 'weekly',
        exceptions: [
          OccurrenceException(
              originalDate: '2026-09-23',
              date: DateTime(2026, 9, 26, 9),
              hasTime: true)
        ]);
    final moved = task.occurrenceByKey('2026-09-23')!;
    expect(moved.displayDate, DateTime(2026, 9, 26, 9));
    expect(moved.displayDeadline, DateTime(2026, 9, 25, 17));
    expect(moved.plannedAfterDeadline, isTrue);
    expect(task.deadlinesOn(DateTime(2026, 9, 25)).single.occurrenceId,
        '2026-09-23');
    expect(task.occurrenceByKey('2026-09-30')!.displayDeadline,
        DateTime(2026, 10, 2, 17));
    final skipped = task.copyWith(exceptions: [
      const OccurrenceException(originalDate: '2026-09-23', skipped: true)
    ]);
    expect(skipped.deadlinesOn(DateTime(2026, 9, 25)), isEmpty);
    final completed = task
        .copyWith(completedDates: ['2026-09-23'])
        .deadlinesOn(DateTime(2026, 9, 25))
        .single;
    expect(completed.isCompleted, isTrue);
    expect(completed.deadlinePassed(DateTime(2026, 9, 28)), isFalse);
  });

  test(
      'overnight blocks appear on each occupied day and deadline rows do not duplicate them',
      () {
    final task = Task(
        title: 'Overnight',
        priority: 1,
        dueDate: DateTime(2026, 9, 22, 23),
        durationMinutes: 120,
        deadline: DateTime(2026, 9, 23, 2),
        deadlineHasTime: true);
    expect(task.plannedEnd, DateTime(2026, 9, 23, 1));
    expect(task.calendarOccurrencesOn(DateTime(2026, 9, 22)), hasLength(1));
    expect(task.calendarOccurrencesOn(DateTime(2026, 9, 23)), hasLength(1));
    expect(task.calendarOccurrencesOn(DateTime(2026, 9, 24)), isEmpty);
    expect(
        task
            .copyWith(durationMinutes: 60, deadline: null)
            .calendarOccurrencesOn(DateTime(2026, 9, 23)),
        isEmpty);
    final moved =
        TaskScheduleChange.apply(task, DateTime(2026, 9, 23, 4), true);
    expect(moved.deadline, task.deadline);
    expect(moved.plannedAfterDeadline, isTrue);
    final change = TaskScheduleChange(task, moved);
    expect(
        change
            .restore(moved.copyWith(deadline: DateTime(2026, 9, 24)))
            .deadline,
        DateTime(2026, 9, 24));
  });

  test('duration means elapsed minutes across both daylight-saving transitions',
      () {
    tzdata.initializeTimeZones();
    final zone = tz.getLocation('Europe/Madrid');
    final spring = Task(
        title: 'Spring',
        priority: 1,
        dueDate: tz.TZDateTime(zone, 2026, 3, 29, 1, 30),
        durationMinutes: 120);
    final autumn = Task(
        title: 'Autumn',
        priority: 1,
        dueDate: tz.TZDateTime(zone, 2026, 10, 25, 1, 30),
        durationMinutes: 120);
    expect(spring.plannedEnd!.hour, 4);
    expect(autumn.plannedEnd!.hour, 2);
    expect(spring.plannedEnd!.difference(spring.dueDate!).inMinutes, 120);
    expect(autumn.plannedEnd!.difference(autumn.dueDate!).inMinutes, 120);
  });

  test(
      'deadline reminders include unfinished past planned slots and date-only unplanned tasks',
      () {
    final now = DateTime(2026, 9, 22, 8);
    final report = Task(
        id: 1,
        title: 'Report',
        priority: 1,
        dueDate: DateTime(2026, 9, 21, 9),
        deadline: DateTime(2026, 9, 22, 17),
        deadlineHasTime: true,
        recurrence: 'weekly',
        reminderAnchor: 'deadline',
        reminderMinutes: 60,
        repeatUntil: DateTime(2026, 9, 21));
    final invoice = Task(
        id: 2,
        title: 'Invoice',
        priority: 1,
        deadline: Task.day(now),
        reminderAnchor: 'deadline',
        reminderTime: 600);
    final alerts = ReminderEngine.plan('local', [report, invoice],
        const ReminderPreferences(enabled: true), now);
    expect(alerts, hasLength(2));
    expect(alerts.singleWhere((a) => a.taskId == 1).when,
        DateTime(2026, 9, 22, 16));
    expect(alerts.singleWhere((a) => a.taskId == 1).occurrence, '2026-09-21');
    expect(alerts.singleWhere((a) => a.taskId == 2).when,
        DateTime(2026, 9, 22, 10));
    expect(
        ReminderEngine.plan(
            'local',
            [report.copyWith(reminderAnchor: 'planned')],
            const ReminderPreferences(enabled: true),
            now),
        isEmpty);
  });

  test(
      'schema 12 upgrade preserves existing schedule and sync identity without inventing planning data',
      () async {
    final sql = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(sql.close);
    await sql.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)');
    await TaskDatabase.upgrade(sql, 3, 12);
    await sql.insert('tasks', {
      'title': 'Existing',
      'dueDate': '2026-09-22T11:00:00.000',
      'priority': 1,
      'owner_key': 'existing-owner',
      'sync_id': 'existing-id',
      'remote_version': 8,
      'revision': 2
    });
    final before = (await sql.query('tasks')).single;
    await TaskDatabase.upgrade(sql, 12, TaskDatabase.schemaVersion);
    final after = (await sql.query('tasks')).single;
    for (final key in before.keys) {
      expect(after[key], before[key], reason: key);
    }
    final task = Task.fromMap(after);
    expect(task.deadline, isNull);
    expect(task.durationMinutes, isNull);
    expect(task.reminderAnchor, 'planned');
    expect(task.reminderDate, task.dueDate);
  });
}
