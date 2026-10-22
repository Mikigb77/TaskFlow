import 'dart:math' as math;

import 'package:intl/intl.dart';

import 'package:agenda/models/reminder_plan.dart';
import 'package:agenda/services/reminder_plans.dart';
import 'generated/app_localizations.dart';

/// A plan's days as people say them: «jue 12» within four weeks, with its
/// month further on («jue, 12 nov»). Its parts stay on one line at large
/// text: they're joined by no-break spaces.
String planDay(DateTime date, DateTime now, String locale) {
  final days = ReminderPlans.daysUntil(date, now);
  return (days >= 0 && days < 28
          ? DateFormat('EEE d', locale).format(date)
          : DateFormat.MMMEd(locale).format(date))
      .replaceAll(' ', ' ');
}

/// `today`, `tomorrow` or `other`, for the messages' selects.
String planWhen(DateTime date, DateTime now) =>
    switch (ReminderPlans.daysUntil(date, now)) {
      0 => 'today',
      1 => 'tomorrow',
      _ => 'other',
    };

/// The plan's rhythm in words, from the phases with reminders still to come:
/// «Cada 3 días, y a diario la última semana». A phase already over isn't
/// said; once every reminder has gone by, the whole plan is.
String planRhythm(
  AppLocalizations l,
  ReminderPlan plan, {
  required DateTime anchor,
  required DateTime now,
  required int minute,
}) {
  final until = math.max(0, ReminderPlans.daysUntil(anchor, now));
  final phases = [...plan.phases]
    ..sort((a, b) => b.fromDays.compareTo(a.fromDays));
  bool ahead(PlanPhase phase) => phase.days.any(
    (day) => ReminderPlans.at(anchor, day, minute).isAfter(now),
  );
  final shown = phases.where(ahead).toList();
  final said = shown.isEmpty ? phases : shown;
  final parts = [
    for (var i = 0; i < said.length; i++)
      _phase(l, said[i], last: i == said.length - 1, until: until),
  ];
  return _capitalized(_joined(l, parts));
}

/// What a plan reads as on its task: a strength «Cada vez más a menudo
/// hasta el jue 12», a plan of one's own its rhythm.
String planSummary(
  AppLocalizations l,
  ReminderPlan plan, {
  required DateTime anchor,
  required DateTime now,
  required int minute,
  required String locale,
}) => plan.isRhythm
    ? l.reminderPlanGrowing(planWhen(anchor, now), planDay(anchor, now, locale))
    : planRhythm(l, plan, anchor: anchor, now: now, minute: minute);

/// The task's one line: the plan, then its next reminder, the last notice
/// included («… · próximo: sáb 25»).
String planLine(
  AppLocalizations l,
  ReminderPlan plan, {
  required DateTime anchor,
  required DateTime now,
  required int minute,
  required String locale,
}) {
  final summary = planSummary(
    l,
    plan,
    anchor: anchor,
    now: now,
    minute: minute,
    locale: locale,
  );
  final next = ReminderPlans.alerts(plan, anchor, minute, now).firstOrNull;
  return next == null
      ? summary
      : l.reminderPlanLine(
          summary,
          planWhen(next.when, now),
          planDay(next.when, now, locale),
        );
}

/// The preview's count and next reminder: «8 avisos · el próximo sáb 25,
/// 9:00». [clock] writes a time as the app does.
String planCount(
  AppLocalizations l,
  ReminderPlan plan, {
  required DateTime anchor,
  required DateTime now,
  required int minute,
  required String locale,
  required String Function(DateTime time) clock,
}) {
  final alerts = ReminderPlans.alerts(plan, anchor, minute, now, late: false);
  if (alerts.isEmpty) return l.reminderPlanNoneLeft;
  final next = alerts.first.when;
  return l.reminderPlanCount(
    alerts.length,
    planWhen(next, now),
    planDay(next, now, locale),
    clock(next),
  );
}

/// A plan's notification text, under the task's title: how far its day is,
/// or, the day after, that it was for yesterday.
String planNotice(
  AppLocalizations l,
  int daysBefore, {
  required bool deadline,
}) => switch (daysBefore) {
  < 0 => deadline ? l.reminderPlanNoticeDue : l.reminderPlanNoticeWas,
  0 => l.reminderPlanNoticeToday,
  1 => l.reminderPlanNoticeTomorrow,
  _ => l.reminderPlanNoticeDays(daysBefore),
};

/// The offer after saving a task [days] away: «Faltan 3 semanas: ¿te lo
/// recuerdo hasta entonces?». Weeks up to eight, then months.
String planOffer(AppLocalizations l, int days) => days < 56
    ? l.reminderPlanOfferWeeks(math.max(1, (days / 7).round()))
    : l.reminderPlanOfferMonths(math.max(1, (days / 30).round()));

String _phase(
  AppLocalizations l,
  PlanPhase phase, {
  required bool last,
  required int until,
}) {
  final days = phase.days.toList();
  // One reminder: «el día antes», «una semana antes», «el mismo día».
  if (days.length == 1) return _before(l, days.single);
  final rhythm = phase.everyDays % 7 == 0
      ? l.reminderPlanEveryWeeks(phase.everyDays ~/ 7)
      : l.reminderPlanEveryDays(phase.everyDays);
  // Starts later than its own rhythm would from today: worth saying. 366,
  // «from now on», never does; a phase starting tomorrow needn't say so.
  final startsLater =
      phase.fromDays < PlanPhase.longest &&
      until - phase.fromDays > phase.everyDays;
  if (phase.toDays == 0) {
    if (!startsLater) return rhythm;
    return l.reminderPlanPhase(
      rhythm,
      phase.fromDays % 7 == 0
          ? l.reminderPlanLastWeeks(phase.fromDays ~/ 7)
          : l.reminderPlanLastDays(phase.fromDays),
    );
  }
  var text = rhythm;
  if (startsLater) {
    text = l.reminderPlanPhase(
      text,
      phase.fromDays % 7 == 0
          ? l.reminderPlanFromWeeks(phase.fromDays ~/ 7)
          : l.reminderPlanFromDays(phase.fromDays),
    );
  }
  // The next phase says when this one stops; the last one says it here.
  if (last) {
    text = l.reminderPlanPhase(
      text,
      phase.toDays % 7 == 0
          ? l.reminderPlanUntilWeeks(phase.toDays ~/ 7)
          : l.reminderPlanUntilDays(phase.toDays),
    );
  }
  return text;
}

String _before(AppLocalizations l, int day) => day == 0
    ? l.reminderPlanOnTheDay
    : day % 7 == 0
    ? l.reminderPlanWeeksBefore(day ~/ 7)
    : l.reminderPlanDaysBefore(day);

String _joined(AppLocalizations l, List<String> parts) => switch (parts) {
  [] => '',
  [final one] => one,
  [final first, final last] => l.reminderPlanAnd(first, last),
  [final first, ...final rest] => l.reminderPlanList(first, _joined(l, rest)),
};

String _capitalized(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
