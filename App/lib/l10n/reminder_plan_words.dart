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
/// said; once every reminder has gone by, the whole plan is. Without
/// [capitalized], it reads as it does after a colon: «cada 3 días, …». With
/// a [dayLead], the day's own reminder rings that long before the anchor's
/// time ([ReminderPlans.dayLead]).
String planRhythm(
  AppLocalizations l,
  ReminderPlan plan, {
  required DateTime anchor,
  required DateTime now,
  required int minute,
  bool capitalized = true,
  int? dayLead,
}) {
  final until = math.max(0, ReminderPlans.daysUntil(anchor, now));
  final phases = [...plan.phases]
    ..sort((a, b) => b.fromDays.compareTo(a.fromDays));
  bool ahead(PlanPhase phase) => phase.days.any(
    (day) => ReminderPlans.moment(
      anchor,
      day,
      minute,
      dayLead: dayLead,
    ).isAfter(now),
  );
  final shown = phases.where(ahead).toList();
  final said = shown.isEmpty ? phases : shown;
  final parts = [
    for (var i = 0; i < said.length; i++)
      _phase(l, said[i], last: i == said.length - 1, until: until),
  ];
  final text = _joined(l, parts);
  return capitalized ? _capitalized(text) : text;
}

/// What a plan reads as on its task, named as reminders: a strength
/// «Recordatorios normales hasta el jue 12», a plan of one's own
/// «Recordatorios: cada 3 días, …». [bare] leaves the noun out, lowercase,
/// for a line that already names it («Recordatorio para Ana: …»).
String planSummary(
  AppLocalizations l,
  ReminderPlan plan, {
  required DateTime anchor,
  required DateTime now,
  required int minute,
  required String locale,
  bool bare = false,
  int? dayLead,
}) {
  final when = planWhen(anchor, now);
  final day = planDay(anchor, now, locale);
  if (plan.isRhythm) {
    return bare
        ? _lowercased(l.reminderPlanGrowing(when, day))
        : l.reminderPlanStrengthLine(plan.strength!, when, day);
  }
  final rhythm = planRhythm(
    l,
    plan,
    anchor: anchor,
    now: now,
    minute: minute,
    capitalized: false,
    dayLead: dayLead,
  );
  return bare ? rhythm : l.reminderPlanOwnLine(rhythm);
}

/// The task's one line: the plan, then its next reminder on or before the
/// task's day, with its time («… · próximo: sáb 24, 9:00»). A task that's
/// [done] reads as the plan alone. [clock] writes a time as the app does.
/// [dayLead] as [planRhythm] takes it.
String planLine(
  AppLocalizations l,
  ReminderPlan plan, {
  required DateTime anchor,
  required DateTime now,
  required int minute,
  required String locale,
  required String Function(DateTime time) clock,
  bool done = false,
  bool bare = false,
  int? dayLead,
}) {
  final summary = planSummary(
    l,
    plan,
    anchor: anchor,
    now: now,
    minute: minute,
    locale: locale,
    bare: bare,
    dayLead: dayLead,
  );
  // The last notice, the day after, isn't promised: nothing rings for the
  // task itself then.
  final next = done
      ? null
      : ReminderPlans.alerts(
          plan,
          anchor,
          minute,
          now,
          late: false,
          dayLead: dayLead,
        ).firstOrNull;
  return next == null
      ? summary
      : l.reminderPlanLine(
          summary,
          planWhen(next.when, now),
          planDay(next.when, now, locale),
          clock(next.when),
        );
}

/// The preview's count and next reminder: «13 avisos · próximo: sáb 24,
/// 9:00». [clock] writes a time as the app does. [dayLead] as [planRhythm]
/// takes it.
String planCount(
  AppLocalizations l,
  ReminderPlan plan, {
  required DateTime anchor,
  required DateTime now,
  required int minute,
  required String locale,
  required String Function(DateTime time) clock,
  int? dayLead,
}) {
  final alerts = ReminderPlans.alerts(
    plan,
    anchor,
    minute,
    now,
    late: false,
    dayLead: dayLead,
  );
  if (alerts.isEmpty) return l.reminderPlanNoneLeft;
  final next = alerts.first.when;
  return l.reminderPlanCount(
    alerts.length,
    planWhen(next, now),
    planDay(next, now, locale),
    clock(next),
  );
}

/// The offer after saving a task [days] away, with Normal's [rhythm] in
/// lowercase words: «Faltan 3 semanas. ¿Te aviso cada 3 días, y a diario la
/// última semana?». Weeks up to eight, then months.
String planOffer(AppLocalizations l, int days, String rhythm) => days < 56
    ? l.reminderPlanOfferWeeks(math.max(1, (days / 7).round()), rhythm)
    : l.reminderPlanOfferMonths(math.max(1, (days / 30).round()), rhythm);

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

String _lowercased(String text) =>
    text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);
