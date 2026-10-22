import 'package:agenda/models/reminder_plan.dart';
import 'package:agenda/models/task.dart';

/// One reminder of a plan: when it rings, and how many days before the
/// anchor it is. -1 is the one last notice, the day after.
class PlanAlert {
  const PlanAlert(this.when, this.daysBefore);
  final DateTime when;
  final int daysBefore;
  bool get late => daysBefore < 0;
}

/// The plan logic, the phone's own (Backend/docs/REMINDER_PLANS.md): what a
/// plan counts back from, the reminders still to come, and when to offer one.
abstract final class ReminderPlans {
  /// The reminders of each plan scheduled ahead: the next few, never the
  /// whole plan, so a long plan never fills Android's alarm limit. They are
  /// planned again when the app starts, when the task changes and when one
  /// fires.
  static const window = 4;

  /// When the plan has no time and Settings has no time for all-day tasks.
  static const defaultMinute = 540;

  /// The offer comes for a task whose anchor is at least this far away.
  static const offerDays = 14;

  /// The deadline when there is one, otherwise the task's own day.
  static DateTime? anchor(Task task) => task.deadline ?? task.dueDate;

  /// Plans are for tasks with a deadline or a day; a repeating task has none
  /// in this first version.
  static bool plannable(Task task) =>
      !task.isNote && !task.isRecurring && anchor(task) != null;

  /// [task]'s plan while it applies, which replaces its single reminder.
  static ReminderPlan? active(Task task) =>
      plannable(task) ? task.reminderPlan : null;

  /// The plan's time of day: its own, else Settings' for all-day tasks.
  static int minute(ReminderPlan plan, int? dateOnlyTime) =>
      plan.time ?? dateOnlyTime ?? defaultMinute;

  /// Calendar days from [now]'s day to [date]'s: 0 today, 1 tomorrow, -1
  /// yesterday.
  static int daysUntil(DateTime date, DateTime now) => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;

  /// [daysBefore] the day of [anchor], at [minute].
  static DateTime at(DateTime anchor, int daysBefore, int minute) => DateTime(
    anchor.year,
    anchor.month,
    anchor.day - daysBefore,
    minute ~/ 60,
    minute % 60,
  );

  /// Every reminder of [plan] still to come after [now], earliest first,
  /// counted back from [anchor]'s day at [minute]; then, with [late], the
  /// one last notice the day after.
  static List<PlanAlert> alerts(
    ReminderPlan plan,
    DateTime anchor,
    int minute,
    DateTime now, {
    bool late = true,
  }) {
    final result = <PlanAlert>[];
    for (final day in plan.days.reversed) {
      final when = at(anchor, day, minute);
      if (when.isAfter(now)) result.add(PlanAlert(when, day));
    }
    if (late) {
      final when = at(anchor, -1, minute);
      if (when.isAfter(now)) result.add(PlanAlert(when, -1));
    }
    return result;
  }

  /// [task]'s reminders still to come, with its plan in effect and
  /// [dateOnlyTime] from Settings. None for a task that's done.
  static List<PlanAlert> taskAlerts(
    Task task,
    int? dateOnlyTime,
    DateTime now, {
    bool late = true,
  }) {
    final plan = active(task);
    if (plan == null || task.isCompleted) return const [];
    return alerts(
      plan,
      anchor(task)!,
      minute(plan, dateOnlyTime),
      now,
      late: late,
    );
  }

  /// After saving [task], the reminder question offers a plan: its anchor is
  /// [offerDays] or more days away and it has none. Only while its reminder
  /// is still the default: a reminder chosen or said (or turned off) is kept,
  /// as a plan would replace it.
  static bool offerable(Task task, DateTime now) =>
      plannable(task) &&
      task.reminderPlan == null &&
      !task.isCompleted &&
      task.reminderMinutes == null &&
      task.reminderTime == null &&
      daysUntil(anchor(task)!, now) >= offerDays;
}
