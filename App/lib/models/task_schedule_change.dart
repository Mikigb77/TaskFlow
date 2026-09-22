import 'package:agenda/models/task.dart';
import 'package:collection/collection.dart';

/// Undo changes only scheduling fields and refuses to overwrite a newer schedule.
class TaskScheduleChange {
  final Task before;
  final Task after;
  const TaskScheduleChange(this.before, this.after);

  bool canUndo(Task current) =>
      current.id == after.id &&
      current.dueDate == after.dueDate &&
      current.hasTime == after.hasTime &&
      current.recurrence == after.recurrence &&
      current.repeatInterval == after.repeatInterval &&
      const ListEquality<int>()
          .equals(current.repeatWeekdays, after.repeatWeekdays) &&
      const DeepCollectionEquality().equals(
          current.exceptions.map((e) => e.toJson()).toList(),
          after.exceptions.map((e) => e.toJson()).toList()) &&
      current.repeatUntil == after.repeatUntil &&
      (before.recurrence == after.recurrence ||
          (current.isCompleted == after.isCompleted &&
              current.completedDates.isEmpty));

  Task restore(Task current) => current.copyWith(
      dueDate: before.dueDate,
      hasTime: before.hasTime,
      recurrence: before.recurrence,
      repeatInterval: before.repeatInterval,
      repeatWeekdays: before.repeatWeekdays,
      exceptions: before.exceptions,
      repeatUntil: before.repeatUntil,
      completedDates: before.recurrence == after.recurrence
          ? current.completedDates
          : before.completedDates);

  static Task apply(Task current, DateTime? date, bool hasTime) =>
      current.dueDate == date && current.hasTime == (date != null && hasTime)
          ? current
          : current.copyWith(
              dueDate: date == null
                  ? null
                  : hasTime
                      ? date
                      : Task.day(date),
              hasTime: date != null && hasTime,
              recurrence: date == null ? 'none' : current.recurrence,
              repeatInterval: date == null ? 1 : current.repeatInterval,
              repeatWeekdays: date == null ? [] : current.repeatWeekdays,
              exceptions: [],
              completedDates: date == null ? [] : current.completedDates,
              repeatUntil: date == null ||
                      (current.repeatUntil != null &&
                          Task.day(date).isAfter(current.repeatUntil!))
                  ? null
                  : current.repeatUntil);
}
