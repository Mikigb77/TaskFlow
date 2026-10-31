import 'package:agenda/models/task.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/widgets/task_schedule_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'recurring checklist completion is occurrence-specific and preserves concurrent edits',
      () async {
    final passport = ChecklistItem(title: 'Passport');
    final charger = ChecklistItem(title: 'Charger');
    final task = Task(
        id: 1,
        title: 'Pack',
        priority: 1,
        recurrence: 'weekly',
        dueDate: DateTime(2026, 9, 25),
        hasTime: false,
        checklist: [passport, charger]);
    final repository = _Tasks(task);
    final notifier = TaskNotifier(repository);
    addTearDown(notifier.dispose);
    await notifier.loadTasks();
    final friday = task.occurrenceOn(DateTime(2026, 9, 25))!;
    await Future.wait([
      notifier.setChecklistCompleted(friday, passport.id, true),
      notifier.setChecklistCompleted(friday, charger.id, true),
    ]);
    expect(
        repository.task.occurrenceOn(DateTime(2026, 9, 25))!.checklistDone, 2);
    expect(
        repository.task.occurrenceOn(DateTime(2026, 10, 2))!.checklistDone, 0);
    expect(repository.task.isCompleted, isFalse);
    repository.task = repository.task.copyWith(title: 'Edited meanwhile');
    await notifier.setChecklistCompleted(friday, charger.id, false);
    expect(repository.task.title, 'Edited meanwhile');
    expect(
        repository.task.occurrenceOn(DateTime(2026, 9, 25))!.checklistDone, 1);
    final restored =
        Task.fromApi(Task.fromMap(repository.task.toMap()).toApi());
    expect(restored.occurrenceOn(DateTime(2026, 9, 25))!.checklistDone, 1);
    expect(restored.checklist.first.id, passport.id);
  });

  test('date-only API storage is independent of timezone offsets', () {
    final date = Task(
        title: 'Invoice',
        dueDate: DateTime(2026, 9, 25),
        hasTime: false,
        priority: 1);
    expect(date.toApi()['due_date'], isNull);
    expect(date.toApi()['scheduled_date'], '2026-09-25');
    expect(Task.fromApi(date.toApi()).dueDate, DateTime(2026, 9, 25));
    expect(Task.fromMap(date.toMap()).hasTime, isFalse);
    expect(taskScheduleLabel(date), '25 Sep · Any time');
    final midnight = date.copyWith(hasTime: true);
    expect(taskScheduleLabel(midnight), contains('00:00'));
    expect(date.copyWith(dueDate: null).dueDate, isNull);
  });

  test('monthly repetitions preserve the 31st after short months', () {
    final task = Task(
        title: 'Rent',
        dueDate: DateTime(2027, 1, 31, 9),
        recurrence: 'monthly',
        priority: 2);
    expect(task.occurrenceOn(DateTime(2027, 2, 28))!.displayDate,
        DateTime(2027, 2, 28, 9));
    expect(task.occurrenceOn(DateTime(2027, 3, 31))!.displayDate,
        DateTime(2027, 3, 31, 9));
    expect(task.occurrenceOn(DateTime(2027, 3, 28)), isNull);
    expect(task.occurrenceOn(DateTime(2026, 12, 31)), isNull);
  });

  test('yearly leap-day repetitions restore February 29 in leap years', () {
    final task = Task(
        title: 'Anniversary',
        dueDate: DateTime(2024, 2, 29),
        hasTime: false,
        recurrence: 'yearly',
        priority: 1);
    expect(task.occurrenceOn(DateTime(2025, 2, 28)), isNotNull);
    expect(task.occurrenceOn(DateTime(2028, 2, 29)), isNotNull);
    expect(task.occurrenceOn(DateTime(2028, 2, 28)), isNull);
  });

  test(
      'weekly completion advances one occurrence and respects an inclusive end',
      () {
    final task = Task(
        title: 'Plants',
        dueDate: DateTime(2026, 9, 27),
        hasTime: false,
        recurrence: 'weekly',
        repeatUntil: DateTime(2026, 10, 4),
        completedDates: ['2026-09-27'],
        priority: 1);
    expect(task.occurrenceOn(DateTime(2026, 9, 27))!.isCompleted, isTrue);
    expect(task.nextOpenOccurrence(from: DateTime(2026, 9, 27))!.displayDate,
        DateTime(2026, 10, 4));
    expect(task.occurrenceOn(DateTime(2026, 10, 11)), isNull);
    expect(
        task.copyWith(completedDates: [
          '2026-09-27',
          '2026-10-04'
        ]).nextOpenOccurrence(from: DateTime(2026, 9, 27)),
        isNull);
  });

  test(
      'completing and undoing two occurrences never overwrites the series anchor',
      () async {
    final task = Task(
        id: 1,
        title: 'Plants',
        dueDate: DateTime(2026, 9, 27, 9),
        recurrence: 'weekly',
        priority: 1);
    final repository = _Tasks(task);
    final notifier = TaskNotifier(repository);
    addTearDown(notifier.dispose);
    await notifier.loadTasks();
    await Future.wait([
      notifier.setCompleted(task.occurrenceOn(DateTime(2026, 9, 27))!, true),
      notifier.setCompleted(task.occurrenceOn(DateTime(2026, 10, 4))!, true),
    ]);
    expect(repository.task.completedDates, ['2026-09-27', '2026-10-04']);
    expect(repository.task.dueDate, task.dueDate);
    repository.task = repository.task.copyWith(title: 'Edited meanwhile');
    await notifier.setCompleted(
        task.occurrenceOn(DateTime(2026, 9, 27))!, false);
    expect(repository.task.completedDates, ['2026-10-04']);
    expect(repository.task.title, 'Edited meanwhile');
    expect(repository.task.dueDate, task.dueDate);
  });

  test(
      'reminders omit Inbox and completed occurrences; date-only has no alarm time',
      () {
    final result = TaskReminders.upcoming([
      Task(title: 'Coffee', priority: 3),
      Task(
          title: 'Invoice',
          dueDate: DateTime(2026, 9, 21),
          hasTime: false,
          priority: 3),
      Task(
          title: 'Medicine',
          dueDate: DateTime(2026, 9, 21, 15),
          recurrence: 'daily',
          repeatUntil: DateTime(2026, 9, 23),
          completedDates: ['2026-09-21'],
          priority: 3),
    ], DateTime(2026, 9, 21, 10));
    expect(result.map((t) => t.title), ['Invoice', 'Medicine', 'Medicine']);
    expect(result.where((t) => t.hasTime).map((t) => t.displayDate),
        [DateTime(2026, 9, 22, 15), DateTime(2026, 9, 23, 15)]);
  });

  test('a date-only AI draft retains its date without inventing midnight', () {
    final draft = TaskDraft.fromJson({
      'title': 'Invoice',
      'due_date': null,
      'scheduled_date': '2026-09-25',
      'priority': 1,
      'notes': '',
      'transcript': 'Pay Friday',
      'questions': []
    });
    expect(draft.dueDate, DateTime(2026, 9, 25));
    expect(draft.hasTime, isFalse);
  });

  test(
      'reschedule Undo preserves intervening edits and refuses a newer schedule',
      () async {
    final repository = _Tasks(Task(
        id: 1,
        title: 'Call',
        priority: 2,
        dueDate: DateTime(2026, 9, 22, 14, 35),
        reminderMinutes: 30));
    final notifier = TaskNotifier(repository);
    addTearDown(notifier.dispose);
    await notifier.loadTasks();
    final change = await notifier.rescheduleTask(1, null, false);
    expect(repository.task.dueDate, isNull);
    repository.task = repository.task.copyWith(
        title: 'Call the clinic',
        notes: 'Updated on another device',
        isCompleted: true);
    expect(await notifier.undoSchedule(change), isTrue);
    expect(repository.task.dueDate, DateTime(2026, 9, 22, 14, 35));
    expect(repository.task.title, 'Call the clinic');
    expect(repository.task.isCompleted, isTrue);
    expect(repository.task.reminderMinutes, 30);
    final second =
        await notifier.rescheduleTask(1, DateTime(2026, 10, 1), false);
    repository.task = repository.task.copyWith(dueDate: DateTime(2026, 10, 2));
    expect(await notifier.undoSchedule(second), isFalse);
    expect(repository.task.dueDate, DateTime(2026, 10, 2));
  });

  test(
      'series reschedule keeps anchor time and clears an invalid end; Undo restores it',
      () async {
    final before = Task(
        id: 1,
        title: 'Plants',
        priority: 1,
        dueDate: DateTime(2026, 9, 22, 9),
        recurrence: 'weekly',
        repeatUntil: DateTime(2026, 10, 22));
    final repository = _Tasks(before);
    final notifier = TaskNotifier(repository);
    addTearDown(notifier.dispose);
    await notifier.loadTasks();
    final change =
        await notifier.rescheduleTask(1, DateTime(2026, 11, 1, 9), true);
    expect(repository.task.repeatUntil, isNull);
    expect(repository.task.recurrence, 'weekly');
    expect(
        repository.task.occurrenceOn(DateTime(2026, 11, 8))!.displayDate!.hour,
        9);
    expect(await notifier.undoSchedule(change), isTrue);
    expect(repository.task.repeatUntil, before.repeatUntil);
    expect(repository.task.dueDate, before.dueDate);
    repository.task = repository.task.copyWith(completedDates: ['2026-09-22']);
    final inbox = await notifier.rescheduleTask(1, null, false);
    expect(repository.task.completedDates, isEmpty);
    expect(repository.task.toApi()['recurrence'], 'none');
    expect(await notifier.undoSchedule(inbox), isTrue);
    expect(repository.task.completedDates, ['2026-09-22']);
    final newer = await notifier.rescheduleTask(1, null, false);
    repository.task = repository.task.copyWith(isCompleted: true);
    expect(await notifier.undoSchedule(newer), isFalse);
  });
}

class _Tasks extends TaskRepository {
  _Tasks(this.task) : super(TaskDatabase());
  Task task;
  @override
  Future<List<Task>> getAllTasks() async => [task];
  @override
  Future<int> updateTask(Task value) async {
    task = value;
    return 1;
  }
}
