import 'dart:convert';

/// One stretch of a reminder plan (Backend/docs/REMINDER_PLANS.md): the days
/// from [fromDays] down to [toDays] before the plan's anchor, with a
/// reminder every [everyDays] days counted back from [toDays]: on [toDays],
/// [toDays] + [everyDays], and so on up to [fromDays].
class PlanPhase {
  const PlanPhase(this.fromDays, this.toDays, this.everyDays);
  final int fromDays;
  final int toDays;
  final int everyDays;

  /// 366 means "from now on": only days still to come are scheduled.
  static const longest = 366;

  /// The days before the anchor with a reminder, nearest first.
  Iterable<int> get days sync* {
    for (var day = toDays; day <= fromDays; day += everyDays) {
      yield day;
    }
  }

  Map<String, dynamic> toJson() => {
    'from_days': fromDays,
    'to_days': toDays,
    'every_days': everyDays,
  };

  /// Null for anything but the contract's shape.
  static PlanPhase? tryParse(Object? data) {
    if (data is! Map) return null;
    final from = data['from_days'];
    final to = data['to_days'];
    final every = data['every_days'];
    if (from is! int || to is! int || every is! int) return null;
    if (to < 0 || from < to || from > longest || every < 1 || every > 30) {
      return null;
    }
    return PlanPhase(from, to, every);
  }
}

/// A plan of nudges about one task, more often as its day comes closer: one
/// of the three strengths ([kind] `rhythm`), or phases read from the
/// person's own words (`custom`). Never a copy of the task: it only sends
/// notifications about it.
class ReminderPlan {
  const ReminderPlan.rhythm(String this.strength, {this.time})
    : kind = rhythmKind,
      _phases = const [],
      said = null;

  ReminderPlan.custom(List<PlanPhase> phases, {this.time, String? said})
    : kind = customKind,
      strength = null,
      _phases = List.unmodifiable(phases),
      said = said == null || said.trim().isEmpty
          ? null
          : said.trim().length > saidLimit
          ? said.trim().substring(0, saidLimit)
          : said.trim();

  static const rhythmKind = 'rhythm';
  static const customKind = 'custom';
  static const gentle = 'gentle';
  static const normal = 'normal';
  static const intense = 'intense';
  static const strengths = [gentle, normal, intense];
  static const saidLimit = 200;

  /// The strengths start at most 4 weeks before the day (D2); a rhythm said
  /// or typed is kept as said, up to [PlanPhase.longest].
  static const strengthStart = 28;

  /// The three strengths as phases, each starting at most [strengthStart]
  /// days before the day and with a reminder on the day itself: at most 8
  /// reminders for [gentle], 15 for [normal] and 22 for [intense].
  static const strengthPhases = {
    // Every 7 days from 25 down to 4 days before, then daily the last 3 and
    // the day.
    gentle: [PlanPhase(strengthStart, 4, 7), PlanPhase(3, 0, 1)],
    // Every 3 days from 26 down to 8 days before, then daily the last 7 and
    // the day.
    normal: [PlanPhase(strengthStart, 8, 3), PlanPhase(7, 0, 1)],
    // Every 2 days from 27 down to 15 days before, then daily the last 14 and
    // the day.
    intense: [PlanPhase(strengthStart, 15, 2), PlanPhase(14, 0, 1)],
  };

  final String kind;

  /// `rhythm` only: [gentle], [normal] or [intense].
  final String? strength;
  final List<PlanPhase> _phases;

  /// Local minute of day for every reminder of the plan; null follows the
  /// reminder time for all-day tasks in Settings.
  final int? time;

  /// `custom` only: the words as typed or said.
  final String? said;

  bool get isRhythm => kind == rhythmKind;

  /// The plan's phases: a strength's, or the custom ones.
  List<PlanPhase> get phases =>
      isRhythm ? strengthPhases[strength] ?? const [] : _phases;

  /// Every day before the anchor with a reminder, nearest first, once each.
  List<int> get days =>
      ({for (final phase in phases) ...phase.days}.toList()..sort());

  ReminderPlan withTime(int? value) => isRhythm
      ? ReminderPlan.rhythm(strength!, time: value)
      : ReminderPlan.custom(_phases, time: value, said: said);

  /// The contract's JSON, as the API sends and reads `reminder_plan`.
  Map<String, dynamic> toJson() => isRhythm
      ? {'kind': rhythmKind, 'strength': strength, 'time': _clock(time)}
      : {
          'kind': customKind,
          'phases': [for (final phase in _phases) phase.toJson()],
          'time': _clock(time),
          'said': said,
        };

  /// The plan as the local database keeps it: the same JSON, as text.
  String encode() => jsonEncode(toJson());

  static ReminderPlan? decode(Object? text) {
    if (text is! String || text.isEmpty) return null;
    try {
      return tryParse(jsonDecode(text));
    } on FormatException {
      return null;
    }
  }

  /// Null for anything but the contract's shape, so a plan this app can't
  /// read leaves the task with its single reminder.
  static ReminderPlan? tryParse(Object? data) {
    if (data is! Map) return null;
    final rawTime = data['time'];
    final time = rawTime == null ? null : _minute(rawTime);
    if (rawTime != null && time == null) return null;
    switch (data['kind']) {
      case rhythmKind:
        final strength = data['strength'];
        if (strength is! String || !strengths.contains(strength)) return null;
        return ReminderPlan.rhythm(strength, time: time);
      case customKind:
        final raw = data['phases'];
        if (raw is! List || raw.isEmpty || raw.length > 4) return null;
        final phases = [for (final item in raw) PlanPhase.tryParse(item)];
        if (phases.any((phase) => phase == null)) return null;
        final said = data['said'];
        return ReminderPlan.custom(
          phases.whereType<PlanPhase>().toList(),
          time: time,
          said: said is String ? said : null,
        );
      default:
        return null;
    }
  }

  static String? _clock(int? minute) => minute == null
      ? null
      : '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  static int? _minute(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return null;
    return hour * 60 + minute;
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderPlan && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}
