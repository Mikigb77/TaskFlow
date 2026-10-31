import 'package:agenda/models/task.dart';
import 'package:agenda/models/occurrence_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/services/task_database.dart';

void main() {
  test(
      'one-occurrence changes keep progress on its original identity and Undo preserves other edits',
      () async {
    final step = ChecklistItem(title: 'Bring notes');
    final repository = _Tasks(Task(
        id: 1,
        title: 'Review',
        priority: 1,
        dueDate: DateTime(2026, 9, 23, 17),
        recurrence: 'weekly',
        repeatWeekdays: [3, 5],
        checklist: [step]));
    final notifier = TaskNotifier(repository);
    addTearDown(notifier.dispose);
    await notifier.loadTasks();
    final original = repository.task.occurrenceByKey('2026-09-23')!;
    final move = await notifier.changeOccurrence(
        original, DateTime(2026, 9, 25, 9), true);
    expect(repository.task.dueDate, DateTime(2026, 9, 23, 17));
    expect(repository.task.occurrencesOn(DateTime(2026, 9, 25)).length, 2);
    final moved = repository.task.occurrenceByKey('2026-09-23')!;
    await notifier.setChecklistCompleted(moved, step.id, true);
    await notifier.setCompleted(moved, true);
    expect(repository.task.completedDates, ['2026-09-23']);
    expect(repository.task.occurrenceByKey('2026-09-25')!.checklistDone, 0);
    await notifier.changeOccurrence(
        repository.task.occurrenceByKey('2026-09-25')!, null, false,
        skip: true);
    repository.task = repository.task.copyWith(notes: 'Preserved');
    expect(await notifier.undoOccurrence(move), isTrue);
    expect(repository.task.occurrenceByKey('2026-09-23')!.checklistDone, 1);
    expect(repository.task.occurrenceByKey('2026-09-23')!.isCompleted, isTrue);
    expect(repository.task.occurrenceByKey('2026-09-25'), isNull);
    expect(repository.task.notes, 'Preserved');
    final newer =
        await notifier.changeOccurrence(original, DateTime(2026, 9, 26), false);
    await notifier.changeOccurrence(original, DateTime(2026, 9, 27), false);
    expect(await notifier.undoOccurrence(newer), isFalse);
    await notifier.changeOccurrence(original, null, false, reset: true);
    expect(repository.task.occurrenceByKey('2026-09-23')!.displayDate,
        DateTime(2026, 9, 23, 17));
  });

  test('whole series reset and Undo include exceptions and rule fields',
      () async {
    final repository = _Tasks(Task(
        id: 1,
        title: 'Gym',
        priority: 1,
        dueDate: DateTime(2026, 9, 23),
        hasTime: false,
        recurrence: 'weekly',
        repeatInterval: 2,
        repeatWeekdays: [
          3,
          5
        ],
        exceptions: const [
          OccurrenceException(originalDate: '2026-09-23', skipped: true)
        ]));
    final notifier = TaskNotifier(repository);
    addTearDown(notifier.dispose);
    await notifier.loadTasks();
    final change = await notifier.rescheduleTask(1, null, false);
    expect(repository.task.repeatInterval, 1);
    expect(repository.task.repeatWeekdays, isEmpty);
    expect(repository.task.exceptions, isEmpty);
    expect(await notifier.undoSchedule(change), isTrue);
    expect(repository.task.repeatInterval, 2);
    expect(repository.task.exceptions.single.skipped, isTrue);
    final move = await notifier.rescheduleTask(1, DateTime(2026, 9, 30), false);
    repository.task = repository.task.copyWith(repeatInterval: 3);
    expect(await notifier.undoSchedule(move), isFalse);
  });

  test(
      'completed dates remain visible after a pattern change and can be reopened',
      () async {
    final repository = _Tasks(Task(
        id: 1,
        title: 'Gym',
        priority: 1,
        dueDate: DateTime(2026, 9, 23),
        recurrence: 'weekly',
        completedDates: ['2026-09-22']));
    final history = repository.task.completedOccurrence('2026-09-22')!;
    expect(history.isCompleted, isTrue);
    expect(history.hasTime, isFalse);
    final notifier = TaskNotifier(repository);
    addTearDown(notifier.dispose);
    await notifier.loadTasks();
    await notifier.setCompleted(history, false);
    expect(repository.task.completedDates, isEmpty);
  });
  test('every other week and selected weekdays preserve calendar anchors', () {
    final task = Task(
        title: 'Gym',
        priority: 1,
        dueDate: DateTime(2026, 9, 23, 17),
        recurrence: 'weekly',
        repeatInterval: 2,
        repeatWeekdays: [1, 3, 5]);
    expect(task.occurrenceOn(DateTime(2026, 9, 21)), isNull);
    expect(task.nextOpenOccurrence(from: DateTime(2026, 9, 21))!.displayDate,
        DateTime(2026, 9, 23, 17));
    expect(task.occurrenceOn(DateTime(2026, 9, 25))!.displayDate,
        DateTime(2026, 9, 25, 17));
    expect(task.occurrenceOn(DateTime(2026, 9, 30)), isNull);
    expect(task.occurrenceOn(DateTime(2026, 10, 5)), isNotNull);
    expect(task.nextOpenOccurrence(from: DateTime(2026, 9, 26))!.displayDate,
        DateTime(2026, 10, 5, 17));
    final weekdays =
        task.copyWith(repeatInterval: 1, repeatWeekdays: [1, 2, 3, 4, 5]);
    expect(weekdays.occurrenceOn(DateTime(2026, 9, 26)), isNull);
    expect(
        weekdays.nextOpenOccurrence(from: DateTime(2026, 9, 26))!.displayDate,
        DateTime(2026, 9, 28, 17));
  });

  test('intervals retain month-end and leap-day semantics', () {
    final task = Task(
        title: 'Report',
        priority: 1,
        dueDate: DateTime(2027, 1, 31),
        hasTime: false,
        recurrence: 'monthly',
        repeatInterval: 2);
    expect(task.occurrenceOn(DateTime(2027, 2, 28)), isNull);
    expect(task.occurrenceOn(DateTime(2027, 3, 31)), isNotNull);
    expect(task.occurrenceOn(DateTime(2027, 9, 30)), isNotNull);
    final leap =
        task.copyWith(dueDate: DateTime(2024, 2, 29), recurrence: 'yearly');
    expect(leap.occurrenceOn(DateTime(2026, 2, 28)), isNotNull);
    expect(leap.occurrenceOn(DateTime(2028, 2, 29)), isNotNull);
  });

  test(
      'moved and skipped instances preserve origin identity and share target days safely',
      () {
    final task = Task(
        title: 'Review',
        priority: 1,
        dueDate: DateTime(2026, 9, 23, 17),
        recurrence: 'daily',
        repeatUntil: DateTime(2026, 9, 27),
        exceptions: [
          OccurrenceException(
              originalDate: '2026-09-23',
              date: DateTime(2026, 9, 24, 9),
              hasTime: true),
          const OccurrenceException(originalDate: '2026-09-25', skipped: true),
          OccurrenceException(
              originalDate: '2026-09-26',
              date: DateTime(2026, 10, 2),
              hasTime: false),
        ]);
    expect(task.occurrencesOn(DateTime(2026, 9, 23)), isEmpty);
    final thursday = task.occurrencesOn(DateTime(2026, 9, 24));
    expect(thursday.map((occurrence) => occurrence.occurrenceId),
        ['2026-09-23', '2026-09-24']);
    expect(thursday.map((occurrence) => occurrence.displayDate!.hour), [9, 17]);
    expect(task.occurrenceByKey('2026-09-25'), isNull);
    expect(task.nextOpenOccurrence(from: DateTime(2026, 9, 28))!.displayDate,
        DateTime(2026, 10, 2));
    expect(task.occurrenceByKey('2026-09-26')!.hasTime, isFalse);
    expect(task.occurrenceByKey('2026-09-26')!.toApi()['due_date'],
        task.toApi()['due_date']);
    final restored = Task.fromApi(Task.fromMap(task.toMap()).toApi());
    expect(restored.toApi(), task.toApi());
    final completed = task.copyWith(completedDates: ['2026-09-23']);
    expect(completed.occurrencesOn(DateTime(2026, 9, 24)).first.isCompleted,
        isTrue);
    expect(completed.occurrencesOn(DateTime(2026, 9, 24)).last.isCompleted,
        isFalse);
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
