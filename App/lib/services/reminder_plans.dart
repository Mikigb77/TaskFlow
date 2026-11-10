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

  /// [task]'s plan while it applies. On a timed task the reminders some
  /// minutes before ring beside it ([leadsBesidePlan]).
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

  /// When a plan's reminder [daysBefore] [anchor]'s day rings: at [minute],
  /// except on the day itself with a [dayLead], [dayLead] minutes before the
  /// anchor's time.
  static DateTime moment(
    DateTime anchor,
    int daysBefore,
    int minute, {
    int? dayLead,
  }) => daysBefore == 0 && dayLead != null
      ? anchor.subtract(Duration(minutes: dayLead))
      : at(anchor, daysBefore, minute);

  /// How long before its time the day's own reminder of [task]'s plan rings
  /// when the anchor has a time (D1): as the task's single reminder would,
  /// with its own lead, else [defaultLead] (Settings' «Tareas con hora», -1
  /// when off). Only a lead that still rings on the anchor's own day counts.
  /// Null when the anchor has no time or no lead does: the day's reminder
  /// then rings at the plan's time, as the others do. Null too when [plan]
  /// (by default [task]'s own) has a time of its own, said or typed (D8):
  /// that time stays on the task's own day, as on its other days. Only a
  /// plan without one (the strengths, «Sí» to the offer, a rhythm said
  /// without an hour) moves the day's notice to the task's usual reminder.
  static int? dayLead(Task task, int defaultLead, {ReminderPlan? plan}) {
    if ((plan ?? task.reminderPlan)?.time != null) return null;
    final day = anchor(task);
    final timed = task.deadline != null ? task.deadlineHasTime : task.hasTime;
    if (day == null || !timed) return null;
    for (final lead in [task.reminderMinutes, defaultLead]) {
      if (lead == null || lead < 0) continue;
      if (Task.day(day.subtract(Duration(minutes: lead))) == Task.day(day)) {
        return lead;
      }
    }
    return null;
  }

  /// The reminders some minutes before a timed [task] that ring beside its
  /// plan, largest lead first: «recuérdamelo cada día la última semana, y 20
  /// y 5 minutos antes» rings both. Only leads said or chosen, never
  /// Settings' default, and never the one the plan's own notice for the day
  /// already rings at (D1, [dayLead]). None while the single reminder is off
  /// or without a plan in effect.
  static List<int> leadsBesidePlan(Task task, int defaultLead) {
    final date = task.reminderDate;
    if (active(task) == null ||
        date == null ||
        !task.reminderHasTime ||
        task.reminderMinutes == -1) {
      return const [];
    }
    final leads = <int>{?task.reminderMinutes, ...task.reminderExtraMinutes};
    final day = dayLead(task, defaultLead);
    if (day != null && anchor(task) == date) leads.remove(day);
    return leads.toList()..sort((a, b) => b.compareTo(a));
  }

  /// Every reminder of [plan] still to come after [now], earliest first,
  /// counted back from [anchor]'s day at [minute], the day's own [dayLead]
  /// minutes before the anchor's time when it's set; then, with [late], the
  /// one last notice the day after.
  static List<PlanAlert> alerts(
    ReminderPlan plan,
    DateTime anchor,
    int minute,
    DateTime now, {
    bool late = true,
    int? dayLead,
  }) {
    final result = <PlanAlert>[];
    for (final day in plan.days.reversed) {
      final when = moment(anchor, day, minute, dayLead: dayLead);
      if (when.isAfter(now)) result.add(PlanAlert(when, day));
    }
    if (late) {
      final when = at(anchor, -1, minute);
      if (when.isAfter(now)) result.add(PlanAlert(when, -1));
    }
    return result;
  }

  /// [task]'s reminders still to come, with its plan in effect and
  /// [dateOnlyTime] and [defaultLead] («Tareas sin hora» and «Tareas con
  /// hora») from Settings. None for a task that's done.
  static List<PlanAlert> taskAlerts(
    Task task,
    int? dateOnlyTime,
    DateTime now, {
    required int defaultLead,
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
      dayLead: dayLead(task, defaultLead),
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
