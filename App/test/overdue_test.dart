import 'package:agenda/models/occurrence_exception.dart';
import 'package:agenda/models/task.dart';
import 'package:flutter_test/flutter_test.dart';

// UX-201 / P31: which unfinished task (or occurrence) Today lists as overdue.
void main() {
  final today = DateTime(2026, 10, 13, 9, 30);
  final yesterday = DateTime(2026, 10, 12);
  final dayBefore = DateTime(2026, 10, 11);
  String key(DateTime day) => Task.dateKey(day);

  group('UX-201: a one-off task', () {
    test('an open task dated yesterday is overdue', () {
      final task = Task(
        id: 1,
        title: 'Comprar pan',
        priority: 1,
        dueDate: DateTime(2026, 10, 12, 10),
      );
      expect(task.overdueOn(today), same(task));
    });

    test('an open date-only task from yesterday is overdue', () {
      final task = Task(
        id: 1,
        title: 'Comprar pan',
        priority: 1,
        dueDate: yesterday,
        hasTime: false,
      );
      expect(task.overdueOn(today), same(task));
    });

    test('a completed task from yesterday is not overdue', () {
      final task = Task(
        id: 1,
        title: 'Comprar pan',
        priority: 1,
        dueDate: DateTime(2026, 10, 12, 10),
        isCompleted: true,
      );
      expect(task.overdueOn(today), isNull);
    });

    test('an undated task is never overdue', () {
      expect(
        Task(id: 1, title: 'Algún día', priority: 1).overdueOn(today),
        isNull,
      );
    });

    test('a task dated today is not overdue, even when its time passed', () {
      final task = Task(
        id: 1,
        title: 'Desayuno',
        priority: 1,
        dueDate: DateTime(2026, 10, 13, 7),
      );
      expect(task.overdueOn(today), isNull);
    });

    test('a note is never overdue', () {
      expect(
        Task(id: 1, title: 'Idea', priority: 1, kind: 'note').overdueOn(today),
        isNull,
      );
    });

    test('a task with only a deadline that passed yesterday is overdue', () {
      final task = Task(
        id: 1,
        title: 'Entregar informe',
        priority: 1,
        deadline: DateTime(2026, 10, 12, 17),
        deadlineHasTime: true,
      );
      expect(task.overdueOn(today), same(task));
    });

    test('a deadline later today is not overdue', () {
      final task = Task(
        id: 1,
        title: 'Entregar informe',
        priority: 1,
        deadline: DateTime(2026, 10, 13, 17),
        deadlineHasTime: true,
      );
      expect(task.overdueOn(today), isNull);
    });
  });

  group('UX-201: a repeating task', () {
    Task daily({
      DateTime? start,
      List<String> done = const [],
      List<OccurrenceException> exceptions = const [],
    }) => Task(
      id: 7,
      title: 'Tomar la pastilla',
      priority: 1,
      dueDate: start ?? DateTime(2026, 10, 1, 8),
      recurrence: 'daily',
      completedDates: done,
      exceptions: exceptions,
    );

    test('a daily task missed yesterday is overdue once, as yesterday', () {
      // Every day since 1 October was missed: only the latest one returns.
      final overdue = daily().overdueOn(today);
      expect(overdue, isNotNull);
      expect(overdue!.occurrenceId, key(yesterday));
      expect(Task.day(overdue.displayDate!), yesterday);
      expect(overdue.isCompleted, isFalse);
    });

    test('yesterday done and the day before missed: not overdue', () {
      expect(daily(done: [key(yesterday)]).overdueOn(today), isNull);
    });

    test('yesterday skipped: not overdue, even with older misses', () {
      final task = daily(
        exceptions: [
          OccurrenceException(originalDate: key(yesterday), skipped: true),
        ],
      );
      expect(task.overdueOn(today), isNull);
    });

    test('a skipped occurrence is never itself the overdue one', () {
      final task = daily(
        start: DateTime(2026, 10, 12, 8),
        exceptions: [
          OccurrenceException(originalDate: key(yesterday), skipped: true),
        ],
      );
      expect(task.overdueOn(today), isNull);
    });

    test('a series that starts today has nothing overdue', () {
      expect(daily(start: DateTime(2026, 10, 13, 8)).overdueOn(today), isNull);
    });

    test('an old daily series stays cheap and returns yesterday', () {
      final task = daily(start: DateTime(2016, 1, 1, 8));
      final watch = Stopwatch()..start();
      final overdue = task.overdueOn(today);
      watch.stop();
      expect(overdue?.occurrenceId, key(yesterday));
      expect(watch.elapsedMilliseconds, lessThan(200));
    });

    test('a missed occurrence moved to yesterday counts on its new day', () {
      final task = daily(
        done: [key(yesterday)],
        exceptions: [
          OccurrenceException(
            originalDate: key(dayBefore),
            date: DateTime(2026, 10, 12, 18),
            hasTime: true,
          ),
        ],
      );
      // Yesterday's own occurrence is done; the moved one is now the latest
      // slot before today, and it is still open.
      final overdue = task.overdueOn(today);
      expect(overdue, isNotNull);
      expect(overdue!.occurrenceId, key(dayBefore));
      expect(Task.day(overdue.displayDate!), yesterday);
    });
  });
}
