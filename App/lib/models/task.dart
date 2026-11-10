import 'dart:convert';
import 'dart:math' as math;
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/occurrence_exception.dart';
import 'package:agenda/models/reminder_plan.dart';

const _unchanged = Object();

class Task {
  final int? id;
  final String title;
  final String kind;
  bool get isNote => kind == 'note';

  /// Planned start / first occurrence. The historical dueDate/API due_date
  /// names remain for compatibility; deadline is an independent commitment.
  final DateTime? dueDate;
  final bool _hasTime;
  bool get hasTime => occurrenceHasTime ?? _hasTime;
  bool get seriesHasTime => _hasTime;
  final DateTime? deadline;
  final bool deadlineHasTime;
  final int? durationMinutes;
  final String reminderAnchor;
  final String recurrence;
  final int repeatInterval;
  final List<int> repeatWeekdays;
  final List<OccurrenceException> exceptions;
  final DateTime? repeatUntil;
  final List<String> completedDates;

  /// When this task was completed, if it doesn't repeat; null while it's
  /// open, and for a completion from before the app kept times
  /// (Backend/docs/COMPLETION_TIMES.md). Only Completadas' order uses it.
  final DateTime? completedAt;

  /// When each completed repetition was ticked, by its date's [dateKey], as
  /// [completedDates] has them; a date completed before the app kept times
  /// has none. Empty for a task that doesn't repeat.
  final Map<String, DateTime> completedTimes;

  /// When this row was completed: a repetition's own date's time, else
  /// [completedAt]. Null for an open row or an untimed completion.
  DateTime? get completedTime =>
      occurrenceId != null ? completedTimes[occurrenceId] : completedAt;

  /// A calendar projection, never persisted as the series start date.
  final DateTime? occurrenceDate;
  final String? occurrenceKey;
  final bool? occurrenceHasTime;
  String? get occurrenceId => isRecurring && displayDate != null
      ? occurrenceKey ?? dateKey(displayDate!)
      : null;
  final int priority;

  /// Null follows device defaults; -1 disables; otherwise minutes before.
  final int? reminderMinutes;

  /// More reminders before a timed task, besides [reminderMinutes]: «20
  /// minutos antes y 5 minutos antes» is 20 and `[5]`. Each in minutes
  /// before (0 at its start), largest first, never [reminderMinutes] again.
  /// They ring with the single reminder, and beside a plan: not while it's
  /// off, and not on a task without a time.
  final List<int> reminderExtraMinutes;

  /// Local minute of day for date-only tasks. Null follows device defaults.
  final int? reminderTime;

  /// Nudges counted back from the deadline, else from the task's own day
  /// (Backend/docs/REMINDER_PLANS.md). While set, it takes the single
  /// reminder's notice ([reminderTime] stays as it is, unused); on a timed
  /// task the leads said or chosen still ring beside it
  /// ([ReminderPlans.leadsBesidePlan]). A repeating task, or one with no
  /// day, has none in effect.
  final ReminderPlan? reminderPlan;
  final bool _isCompleted;
  final String? notes;
  final List<String> filePaths;
  final List<String> imagePaths;
  final List<ChecklistItem> checklist;
  final String? listId;
  final String assignment;
  final int? assigneeId;
  final String? assigneeName;
  final int? createdBy;

  /// The name of the account that created the task, as the server sends it;
  /// null for an account that has left the project or been deleted.
  final String? createdByName;
  bool isForAccount(int? id, {bool managesProject = false}) =>
      assignment == 'personal' ||
      assignment == 'group' ||
      (assignment == 'member' && assigneeId == id) ||
      (assignment == 'unassigned' && managesProject);
  final List<String> labels;
  String? get checklistOccurrence => occurrenceId;
  int get checklistDone => checklist
      .where((item) => item.done(occurrence: checklistOccurrence))
      .length;

  Task({
    this.id,
    required this.title,
    this.kind = 'task',
    this.dueDate,
    bool hasTime = true,
    this.deadline,
    bool deadlineHasTime = false,
    this.durationMinutes,
    this.reminderAnchor = 'planned',
    this.recurrence = 'none',
    this.repeatInterval = 1,
    List<int> repeatWeekdays = const [],
    List<OccurrenceException> exceptions = const [],
    this.repeatUntil,
    List<String>? completedDates,
    DateTime? completedAt,
    Map<String, DateTime>? completedTimes,
    this.occurrenceDate,
    this.occurrenceKey,
    this.occurrenceHasTime,
    required this.priority,
    this.reminderMinutes,
    List<int> reminderExtraMinutes = const [],
    this.reminderTime,
    this.reminderPlan,
    bool isCompleted = false,
    this.notes,
    List<String>? filePaths,
    List<String>? imagePaths,
    List<ChecklistItem>? checklist,
    this.listId,
    this.assignment = 'personal',
    this.assigneeId,
    this.assigneeName,
    this.createdBy,
    this.createdByName,
    List<String>? labels,
  }) : _hasTime = dueDate != null && hasTime,
       deadlineHasTime = deadline != null && deadlineHasTime,
       repeatWeekdays = List.unmodifiable(
         repeatWeekdays.toSet().toList()..sort(),
       ),
       exceptions = List.unmodifiable(
         [...exceptions]
           ..sort((a, b) => a.originalDate.compareTo(b.originalDate)),
       ),
       _isCompleted = isCompleted,
       reminderExtraMinutes = extraLeads(reminderExtraMinutes, reminderMinutes),
       completedDates = List.unmodifiable(completedDates ?? []),
       // Only what the completion says: a task that doesn't repeat has a
       // time while it's completed; a repeating one, for its completed dates.
       // Reopening, or a date leaving completedDates, drops the time.
       completedAt = recurrence == 'none' || dueDate == null
           ? (isCompleted ? completedAt : null)
           : null,
       completedTimes = Map.unmodifiable(
         recurrence == 'none' || dueDate == null
             ? const <String, DateTime>{}
             : {
                 for (final entry in (completedTimes ?? const {}).entries)
                   if (completedDates?.contains(entry.key) == true)
                     entry.key: entry.value,
               },
       ),
       filePaths = filePaths ?? [],
       checklist = List.unmodifiable(checklist ?? []),
       labels = List.unmodifiable(
         (labels ?? [])
             .map((label) => label.trim().toLowerCase())
             .where((label) => label.isNotEmpty)
             .toSet(),
       ),
       imagePaths = imagePaths ?? [] {
    if (!['task', 'note'].contains(kind)) {
      throw ArgumentError('Unsupported content type.');
    }
    if (!['personal', 'member', 'group', 'unassigned'].contains(assignment)) {
      throw ArgumentError('Unsupported task responsibility.');
    }
    if (isNote &&
        (dueDate != null ||
            deadline != null ||
            durationMinutes != null ||
            recurrence != 'none' ||
            repeatUntil != null ||
            repeatInterval != 1 ||
            this.repeatWeekdays.isNotEmpty ||
            this.exceptions.isNotEmpty ||
            this.completedDates.isNotEmpty ||
            priority != 1 ||
            isCompleted ||
            reminderTime != null ||
            reminderPlan != null ||
            reminderExtraMinutes.isNotEmpty ||
            (reminderMinutes != null && reminderMinutes != -1) ||
            reminderAnchor != 'planned' ||
            this.checklist.any((item) => item.completedDates.isNotEmpty))) {
      throw ArgumentError(
        'Notes cannot have task schedules, reminders or completion.',
      );
    }
    if (repeatInterval < 1 ||
        repeatInterval > 99 ||
        repeatWeekdays.any((day) => day < 1 || day > 7)) {
      throw ArgumentError('Invalid repeat interval or weekdays.');
    }
    if (durationMinutes != null &&
        (durationMinutes! < 1 || durationMinutes! > 1440)) {
      throw ArgumentError('Duration must be between 1 and 1440 minutes.');
    }
    if (!['planned', 'deadline'].contains(reminderAnchor)) {
      throw ArgumentError('Invalid reminder anchor.');
    }
  }

  static const repeats = {
    'none': 'Does not repeat',
    'daily': 'Daily',
    'weekly': 'Weekly',
    'monthly': 'Monthly',
    'yearly': 'Yearly',
  };
  bool get isRecurring => recurrence != 'none' && dueDate != null;
  DateTime? get displayDate => occurrenceDate ?? dueDate;

  /// «Sin fecha»: neither a day nor a deadline. A deadline-only task shows on
  /// its deadline's day, so it isn't undated.
  bool get undated => dueDate == null && deadline == null;

  /// Repeating deadlines retain their civil-day offset from the ORIGINAL
  /// occurrence. Moving a single planned slot must not move its deadline.
  DateTime? get displayDeadline {
    if (deadline == null || !isRecurring || occurrenceId == null) {
      return deadline;
    }
    final original = DateTime.parse(occurrenceId!);
    return DateTime(
      original.year,
      original.month,
      original.day + _deadlineDayOffset,
      deadlineHasTime ? deadline!.hour : 0,
      deadlineHasTime ? deadline!.minute : 0,
      deadlineHasTime ? deadline!.second : 0,
    );
  }

  int get _deadlineDayOffset =>
      DateTime.utc(deadline!.year, deadline!.month, deadline!.day)
          .difference(DateTime.utc(dueDate!.year, dueDate!.month, dueDate!.day))
          .inDays;
  DateTime? get plannedEnd =>
      hasTime && displayDate != null && durationMinutes != null
      ? displayDate!.add(Duration(minutes: durationMinutes!))
      : null;
  DateTime? get reminderDate =>
      reminderAnchor == 'deadline' ? displayDeadline : displayDate;
  bool get reminderHasTime =>
      reminderAnchor == 'deadline' ? deadlineHasTime : hasTime;
  DateTime? get deadlineCutoff {
    final value = displayDeadline;
    return value == null || deadlineHasTime
        ? value
        : DateTime(value.year, value.month, value.day + 1);
  }

  bool deadlinePassed(DateTime now) =>
      !isCompleted && deadlineCutoff != null && !now.isBefore(deadlineCutoff!);
  bool get plannedAfterDeadline =>
      deadlineCutoff != null &&
      (plannedEnd ?? displayDate)?.isAfter(deadlineCutoff!) == true;

  List<Task> deadlinesOn(DateTime date) {
    if (deadline == null) return [];
    if (!isRecurring) return dateKey(deadline!) == dateKey(date) ? [this] : [];
    final original = DateTime(
      date.year,
      date.month,
      date.day - _deadlineDayOffset,
    );
    final instance = occurrenceByKey(dateKey(original));
    return instance == null ? [] : [instance];
  }

  /// Day agendas include deadline-only tasks and the tail of overnight blocks.
  /// All entries still carry the original recurrence identity for actions.
  List<Task> calendarOccurrencesOn(DateTime date) {
    if (isNote) return [];
    final entries = <String, Task>{};
    void include(Task task) => entries[task.occurrenceId ?? 'once'] = task;
    for (final task in [...occurrencesOn(date), ...deadlinesOn(date)]) {
      include(task);
    }
    if (durationMinutes != null) {
      final start = day(date);
      // A 24-hour block can cross two civil midnights at a DST transition.
      for (var offset = 1; offset <= 2; offset++) {
        for (final task in occurrencesOn(
          DateTime(date.year, date.month, date.day - offset),
        )) {
          if (task.plannedEnd?.isAfter(start) == true) include(task);
        }
      }
    }
    return entries.values.toList()..sort(compareBySchedule);
  }

  bool get isCompleted => isRecurring && occurrenceDate != null
      ? completedDates.contains(occurrenceId)
      : _isCompleted;
  String get repeatLabel {
    final unit = switch (recurrence) {
      'daily' => 'days',
      'weekly' => 'weeks',
      'monthly' => 'months',
      'yearly' => 'years',
      _ => '',
    };
    final frequency = repeatInterval == 1
        ? repeats[recurrence]!
        : 'Every $repeatInterval $unit';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return repeatWeekdays.isEmpty || recurrence != 'weekly'
        ? frequency
        : '$frequency · ${repeatWeekdays.map((day) => names[day - 1]).join(', ')}';
  }

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static DateTime day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  static int compareBySchedule(Task a, Task b) {
    if (a.displayDate == null) return b.displayDate == null ? 0 : 1;
    if (b.displayDate == null) return -1;
    return a.displayDate!.compareTo(b.displayDate!);
  }

  DateTime _dateAt(int index) {
    final start = dueDate!;
    var year = start.year;
    var month = start.month;
    var date = start.day;
    if (recurrence == 'daily') date += index * repeatInterval;
    if (recurrence == 'weekly') {
      if (repeatWeekdays.isEmpty) {
        date += index * 7 * repeatInterval;
      } else {
        date +=
            -(start.weekday - 1) +
            (index ~/ repeatWeekdays.length) * 7 * repeatInterval +
            repeatWeekdays[index % repeatWeekdays.length] -
            1;
      }
    }
    if (recurrence == 'monthly' || recurrence == 'yearly') {
      final target = DateTime(
        year + (recurrence == 'yearly' ? index * repeatInterval : 0),
        month + (recurrence == 'monthly' ? index * repeatInterval : 0),
      );
      year = target.year;
      month = target.month;
      date = math.min(start.day, DateTime(year, month + 1, 0).day);
    }
    return DateTime(
      year,
      month,
      date,
      _hasTime ? start.hour : 0,
      _hasTime ? start.minute : 0,
    );
  }

  int _indexNear(DateTime date) {
    final start = dueDate!;
    final days = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    return math.max(0, switch (recurrence) {
      'daily' => days ~/ repeatInterval,
      'weekly' =>
        repeatWeekdays.isEmpty
            ? days ~/ (7 * repeatInterval)
            : ((days + start.weekday - 1) ~/ (7 * repeatInterval)) *
                  repeatWeekdays.length,
      'monthly' =>
        ((date.year - start.year) * 12 + date.month - start.month) ~/
            repeatInterval,
      'yearly' => (date.year - start.year) ~/ repeatInterval,
      _ => 0,
    });
  }

  bool isBaseOccurrence(DateTime date) {
    if (!isRecurring) return false;
    if (day(date).isBefore(day(dueDate!)) ||
        (repeatUntil != null && day(date).isAfter(day(repeatUntil!)))) {
      return false;
    }
    final index = _indexNear(date);
    final length = recurrence == 'weekly' && repeatWeekdays.isNotEmpty
        ? repeatWeekdays.length
        : 1;
    return List.generate(
      length,
      (offset) => _dateAt(index + offset),
    ).any((value) => dateKey(value) == dateKey(date));
  }

  /// Lookup by the original date, which stays stable after a one-off move.
  Task? occurrenceByKey(String key) {
    final original = DateTime.tryParse(key);
    if (original == null || !isBaseOccurrence(original)) return null;
    final change = exceptions
        .where((item) => item.originalDate == key)
        .firstOrNull;
    if (change?.skipped == true) return null;
    final date =
        change?.date ??
        DateTime(
          original.year,
          original.month,
          original.day,
          _hasTime ? dueDate!.hour : 0,
          _hasTime ? dueDate!.minute : 0,
        );
    return copyWith(
      occurrenceDate: date,
      occurrenceKey: key,
      occurrenceHasTime: change?.hasTime ?? _hasTime,
    );
  }

  /// A moved instance can share its new day with a normal occurrence.
  List<Task> occurrencesOn(DateTime date) {
    if (!isRecurring) {
      return dueDate != null && dateKey(dueDate!) == dateKey(date)
          ? [this]
          : [];
    }
    final key = dateKey(date);
    final original = occurrenceByKey(key);
    final result = <Task>[
      if (original != null && dateKey(original.displayDate!) == key) original,
      for (final change in exceptions)
        if (!change.skipped &&
            change.originalDate != key &&
            change.date != null &&
            dateKey(change.date!) == key)
          ...[occurrenceByKey(change.originalDate)].whereType<Task>(),
    ];
    return result..sort(compareBySchedule);
  }

  Task? occurrenceOn(DateTime date) => occurrencesOn(date).firstOrNull;

  /// Keep completion history visible after the repeating pattern changes.
  Task? completedOccurrence(String key) => !completedDates.contains(key)
      ? null
      : occurrenceByKey(key) ??
            copyWith(
              occurrenceDate: DateTime.parse(key),
              occurrenceKey: key,
              occurrenceHasTime: false,
            );

  /// Show the next open occurrence from today; past occurrences stay in Calendar.
  Task? nextOpenOccurrence({DateTime? from}) {
    if (isNote) return null;
    if (!isRecurring) return isCompleted ? null : this;
    final first = day(from ?? DateTime.now());
    final moved =
        exceptions
            .map((change) => occurrenceByKey(change.originalDate))
            .whereType<Task>()
            .where(
              (task) =>
                  !task.isCompleted && !day(task.displayDate!).isBefore(first),
            )
            .toList()
          ..sort(compareBySchedule);
    Task? best = moved.firstOrNull;
    var index = _indexNear(first);
    for (
      var attempts = 0;
      attempts <=
          completedDates.length + exceptions.length + repeatWeekdays.length + 2;
      attempts++, index++
    ) {
      final date = _dateAt(index);
      if (repeatUntil != null && day(date).isAfter(day(repeatUntil!))) {
        break;
      }
      if (!day(date).isBefore(first) &&
          !completedDates.contains(dateKey(date)) &&
          !exceptions.any((change) => change.originalDate == dateKey(date))) {
        final candidate = occurrenceByKey(dateKey(date));
        if (candidate != null) {
          if (best == null || compareBySchedule(candidate, best) < 0) {
            best = candidate;
          }
          break;
        }
      }
    }
    return best;
  }

  /// The occurrence Today lists as overdue, or null. A repeating task looks
  /// only at its most recent occurrence before [today]: once that one is
  /// completed or skipped, older misses stay in the past.
  Task? overdueOn(DateTime today) {
    if (isNote) return null;
    final first = day(today);
    if (!isRecurring) {
      final date = dueDate ?? deadline;
      return !isCompleted && date != null && day(date).isBefore(first)
          ? this
          : null;
    }
    DateTime? latestDate;
    Task? latest;
    void consider(DateTime date, Task? occurrence) {
      if (day(date).isBefore(first) &&
          (latestDate == null || date.isAfter(latestDate!))) {
        latestDate = date;
        latest = occurrence;
      }
    }

    // A moved occurrence counts on its new day; a skipped one settles its day.
    for (final change in exceptions) {
      final original = DateTime.tryParse(change.originalDate);
      if (original == null || !isBaseOccurrence(original)) continue;
      final occurrence = change.skipped
          ? null
          : occurrenceByKey(change.originalDate);
      consider(occurrence?.displayDate ?? original, occurrence);
    }
    final limit = repeatUntil != null && day(repeatUntil!).isBefore(first)
        ? DateTime(repeatUntil!.year, repeatUntil!.month, repeatUntil!.day + 1)
        : first;
    final width = recurrence == 'weekly' && repeatWeekdays.isNotEmpty
        ? repeatWeekdays.length
        : 1;
    // Walk back from the slot nearest today; only exceptions can be passed over.
    var index = _indexNear(limit) + width;
    for (
      var attempts = 0;
      index >= 0 && attempts <= exceptions.length + 2 * width + 2;
      attempts++, index--
    ) {
      final date = _dateAt(index);
      if (!day(date).isBefore(limit)) continue;
      if (day(date).isBefore(day(dueDate!))) break;
      final key = dateKey(date);
      if (exceptions.any((change) => change.originalDate == key)) continue;
      consider(date, occurrenceByKey(key));
      break;
    }
    final occurrence = latest;
    return occurrence == null || occurrence.isCompleted ? null : occurrence;
  }

  /// This task as a write stores it, with each completion's time set by the
  /// server's rule (Backend/docs/COMPLETION_TIMES.md), so phone and server
  /// agree: a time this task carries wins; else the time [before], the row
  /// as stored, had for that completion; else [now], for a completion new in
  /// this write. One that was already there without a time stays without.
  Task withCompletionTimes(Task? before, DateTime now) {
    if (!isRecurring) {
      if (!_isCompleted || completedAt != null) return this;
      return copyWith(
        completedAt: before?._isCompleted == true ? before!.completedAt : now,
      );
    }
    final kept = before?.completedTimes ?? const <String, DateTime>{};
    final already = before?.completedDates.toSet() ?? const <String>{};
    return copyWith(
      completedTimes: {
        for (final date in completedDates)
          date: ?completedTimes[date] ?? kept[date] ?? (already.contains(date) ? null : now),
      },
    );
  }

  Map<String, String> get _timesJson => {
    for (final entry in completedTimes.entries)
      entry.key: entry.value.toUtc().toIso8601String(),
  };

  /// A stored or sent date-time; anything else is no time, never an error.
  static DateTime? _instant(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  /// The most extra reminders a task keeps, as the server takes them.
  static const maxExtraLeads = 5;

  /// [values] as [reminderExtraMinutes] keeps them: each lead from 0 to a
  /// week once, largest first, without the single reminder's [main] lead.
  static List<int> extraLeads(Iterable<int> values, [int? main]) {
    final leads =
        (values.where((value) => value >= 0 && value <= 10080).toSet()
              ..remove(main))
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return List.unmodifiable(leads.take(maxExtraLeads));
  }

  /// Extra leads as stored or sent: a list of whole numbers. Anything else,
  /// or nothing, is none.
  static List<int> readExtraLeads(Object? Function() read) {
    try {
      final value = read();
      if (value is! List) return const [];
      return [
        for (final item in value)
          if (item is int)
            item
          else if (item is num && item == item.roundToDouble())
            item.toInt(),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Map<String, DateTime> _times(Object? Function() read) {
    Object? value;
    try {
      value = read();
    } catch (_) {
      return const {};
    }
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        if (entry.key is String)
          entry.key as String: ?_instant(entry.value),
    };
  }

  Task copyWith({
    int? id,
    String? title,
    Object? dueDate = _unchanged,
    bool? hasTime,
    Object? deadline = _unchanged,
    bool? deadlineHasTime,
    Object? durationMinutes = _unchanged,
    String? reminderAnchor,
    String? recurrence,
    int? repeatInterval,
    List<int>? repeatWeekdays,
    List<OccurrenceException>? exceptions,
    Object? repeatUntil = _unchanged,
    List<String>? completedDates,
    Object? completedAt = _unchanged,
    Map<String, DateTime>? completedTimes,
    Object? occurrenceDate = _unchanged,
    Object? occurrenceKey = _unchanged,
    Object? occurrenceHasTime = _unchanged,
    int? priority,
    Object? reminderMinutes = _unchanged,
    List<int>? reminderExtraMinutes,
    Object? reminderTime = _unchanged,
    Object? reminderPlan = _unchanged,
    bool? isCompleted,
    String? notes,
    List<String>? filePaths,
    List<String>? imagePaths,
    List<ChecklistItem>? checklist,
    Object? listId = _unchanged,
    String? assignment,
    Object? assigneeId = _unchanged,
    Object? assigneeName = _unchanged,
    Object? createdBy = _unchanged,
    Object? createdByName = _unchanged,
    List<String>? labels,
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    kind: kind,
    dueDate: identical(dueDate, _unchanged)
        ? this.dueDate
        : dueDate as DateTime?,
    hasTime: hasTime ?? _hasTime,
    deadline: identical(deadline, _unchanged)
        ? this.deadline
        : deadline as DateTime?,
    deadlineHasTime: deadlineHasTime ?? this.deadlineHasTime,
    durationMinutes: identical(durationMinutes, _unchanged)
        ? this.durationMinutes
        : durationMinutes as int?,
    reminderAnchor: reminderAnchor ?? this.reminderAnchor,
    recurrence: recurrence ?? this.recurrence,
    repeatInterval: repeatInterval ?? this.repeatInterval,
    repeatWeekdays: repeatWeekdays ?? this.repeatWeekdays,
    exceptions: exceptions ?? this.exceptions,
    repeatUntil: identical(repeatUntil, _unchanged)
        ? this.repeatUntil
        : repeatUntil as DateTime?,
    completedDates: completedDates ?? this.completedDates,
    completedAt: identical(completedAt, _unchanged)
        ? this.completedAt
        : completedAt as DateTime?,
    completedTimes: completedTimes ?? this.completedTimes,
    occurrenceDate: identical(occurrenceDate, _unchanged)
        ? this.occurrenceDate
        : occurrenceDate as DateTime?,
    occurrenceKey: identical(occurrenceKey, _unchanged)
        ? this.occurrenceKey
        : occurrenceKey as String?,
    occurrenceHasTime: identical(occurrenceHasTime, _unchanged)
        ? this.occurrenceHasTime
        : occurrenceHasTime as bool?,
    priority: priority ?? this.priority,
    reminderMinutes: identical(reminderMinutes, _unchanged)
        ? this.reminderMinutes
        : reminderMinutes as int?,
    reminderExtraMinutes: reminderExtraMinutes ?? this.reminderExtraMinutes,
    reminderTime: identical(reminderTime, _unchanged)
        ? this.reminderTime
        : reminderTime as int?,
    reminderPlan: identical(reminderPlan, _unchanged)
        ? this.reminderPlan
        : reminderPlan as ReminderPlan?,
    isCompleted: isCompleted ?? _isCompleted,
    notes: notes ?? this.notes,
    filePaths: filePaths ?? this.filePaths,
    checklist: checklist ?? this.checklist,
    listId: identical(listId, _unchanged) ? this.listId : listId as String?,
    assignment: assignment ?? this.assignment,
    assigneeId: identical(assigneeId, _unchanged)
        ? this.assigneeId
        : assigneeId as int?,
    assigneeName: identical(assigneeName, _unchanged)
        ? this.assigneeName
        : assigneeName as String?,
    createdBy: identical(createdBy, _unchanged)
        ? this.createdBy
        : createdBy as int?,
    createdByName: identical(createdByName, _unchanged)
        ? this.createdByName
        : createdByName as String?,
    labels: labels ?? this.labels,
    imagePaths: imagePaths ?? this.imagePaths,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'kind': kind,
    'dueDate': dueDate == null
        ? null
        : _hasTime
        ? dueDate!.toIso8601String()
        : dateKey(dueDate!),
    'hasTime': _hasTime ? 1 : 0,
    'deadline': deadline == null
        ? null
        : deadlineHasTime
        ? deadline!.toIso8601String()
        : dateKey(deadline!),
    'deadlineHasTime': deadlineHasTime ? 1 : 0,
    'durationMinutes': durationMinutes,
    'reminderAnchor': reminderAnchor,
    'recurrence': recurrence,
    'repeatInterval': repeatInterval,
    'repeatWeekdays': jsonEncode(repeatWeekdays),
    'exceptions': jsonEncode(
      exceptions.map((change) => change.toJson()).toList(),
    ),
    'repeatUntil': repeatUntil == null ? null : dateKey(repeatUntil!),
    'completedDates': jsonEncode(completedDates),
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'completedTimes': jsonEncode(_timesJson),
    'priority': priority,
    'reminderMinutes': reminderMinutes,
    'reminderExtraMinutes': jsonEncode(reminderExtraMinutes),
    'reminderTime': reminderTime,
    'reminderPlan': reminderPlan?.encode(),
    'isCompleted': _isCompleted ? 1 : 0,
    'notes': notes,
    'listId': listId,
    'assignment': assignment,
    'assigneeId': assigneeId,
    'assigneeName': assigneeName,
    'createdBy': createdBy,
    'createdByName': createdByName,
    'labels': jsonEncode(labels),
    'checklist': jsonEncode(checklist.map((item) => item.toJson()).toList()),
    'filePaths': filePaths.isEmpty ? null : filePaths.join('|'),
    'imagePaths': imagePaths.isEmpty ? null : imagePaths.join('|'),
  };

  static Task fromMap(Map<String, dynamic> map) => Task(
    id: map['id'],
    title: map['title'],
    kind: map['kind'] ?? 'task',
    dueDate: map['dueDate'] == null
        ? null
        : DateTime.parse(map['dueDate']).toLocal(),
    hasTime: (map['hasTime'] ?? 1) == 1,
    deadline: map['deadline'] == null
        ? null
        : DateTime.parse(map['deadline']).toLocal(),
    deadlineHasTime: map['deadlineHasTime'] == 1,
    durationMinutes: map['durationMinutes'],
    reminderAnchor: map['reminderAnchor'] ?? 'planned',
    recurrence: map['recurrence'] ?? 'none',
    repeatInterval: map['repeatInterval'] ?? 1,
    repeatWeekdays: List<int>.from(jsonDecode(map['repeatWeekdays'] ?? '[]')),
    exceptions: (jsonDecode(map['exceptions'] ?? '[]') as List)
        .map(
          (value) =>
              OccurrenceException.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList(),
    repeatUntil: map['repeatUntil'] == null
        ? null
        : DateTime.parse(map['repeatUntil']),
    completedDates: List<String>.from(
      jsonDecode(map['completedDates'] ?? '[]'),
    ),
    completedAt: _instant(map['completedAt']),
    completedTimes: _times(() => jsonDecode(map['completedTimes'] ?? '{}')),
    priority: map['priority'],
    reminderMinutes: map['reminderMinutes'],
    reminderExtraMinutes: (map['kind'] ?? 'task') == 'note'
        ? const []
        : readExtraLeads(() => jsonDecode(map['reminderExtraMinutes'] ?? '[]')),
    reminderTime: map['reminderTime'],
    // Notes take no reminders; a plan this app can't read is left out.
    reminderPlan: (map['kind'] ?? 'task') == 'note'
        ? null
        : ReminderPlan.decode(map['reminderPlan']),
    isCompleted: map['isCompleted'] == 1,
    notes: map['notes'],
    listId: map['listId'],
    assignment: map['assignment'] ?? 'personal',
    assigneeId: map['assigneeId'],
    assigneeName: map['assigneeName'],
    createdBy: map['createdBy'],
    createdByName: map['createdByName'],
    labels: List<String>.from(jsonDecode(map['labels'] ?? '[]')),
    checklist: (jsonDecode(map['checklist'] ?? '[]') as List)
        .map((item) => ChecklistItem.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    filePaths: (map['filePaths'] as String?)
        ?.split('|')
        .where((p) => p.isNotEmpty)
        .toList(),
    imagePaths: (map['imagePaths'] as String?)
        ?.split('|')
        .where((p) => p.isNotEmpty)
        .toList(),
  );

  Map<String, dynamic> toApi() => {
    'title': title,
    'kind': kind,
    'due_date': _hasTime ? dueDate?.toUtc().toIso8601String() : null,
    'scheduled_date': !_hasTime && dueDate != null ? dateKey(dueDate!) : null,
    'deadline_at': deadlineHasTime ? deadline?.toUtc().toIso8601String() : null,
    'deadline_date': !deadlineHasTime && deadline != null
        ? dateKey(deadline!)
        : null,
    'duration_minutes': durationMinutes,
    'reminder_anchor': reminderAnchor,
    'recurrence': recurrence,
    'repeat_interval': repeatInterval,
    'repeat_weekdays': repeatWeekdays,
    'exceptions': exceptions.map((change) => change.toJson()).toList(),
    'repeat_until': repeatUntil == null ? null : dateKey(repeatUntil!),
    'completed_dates': completedDates,
    'completed_at': completedAt?.toUtc().toIso8601String(),
    'completed_times': _timesJson,
    'priority': priority,
    'reminder_minutes': reminderMinutes,
    'reminder_extra_minutes': reminderExtraMinutes,
    'reminder_time': reminderTime,
    'reminder_plan': reminderPlan?.toJson(),
    'notes': notes ?? '',
    'list_id': listId,
    'assignment': assignment,
    'assignee_id': assigneeId,
    'labels': labels,
    'checklist': checklist.map((item) => item.toJson()).toList(),
    'is_completed': _isCompleted,
  };

  static Task fromApi(Map<String, dynamic> data) => Task(
    title: data['title'],
    kind: data['kind'] ?? 'task',
    dueDate: data['due_date'] != null
        ? DateTime.parse(data['due_date']).toLocal()
        : data['scheduled_date'] != null
        ? DateTime.parse(data['scheduled_date'])
        : null,
    hasTime: data['due_date'] != null,
    deadline: data['deadline_at'] != null
        ? DateTime.parse(data['deadline_at']).toLocal()
        : data['deadline_date'] != null
        ? DateTime.parse(data['deadline_date'])
        : null,
    deadlineHasTime: data['deadline_at'] != null,
    durationMinutes: data['duration_minutes'],
    reminderAnchor: data['reminder_anchor'] ?? 'planned',
    recurrence: data['recurrence'] ?? 'none',
    repeatInterval: data['repeat_interval'] ?? 1,
    repeatWeekdays: List<int>.from(data['repeat_weekdays'] ?? []),
    exceptions: (data['exceptions'] as List? ?? [])
        .map(
          (value) =>
              OccurrenceException.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList(),
    repeatUntil: data['repeat_until'] == null
        ? null
        : DateTime.parse(data['repeat_until']),
    completedDates: List<String>.from(data['completed_dates'] ?? []),
    // Missing on an older server, or not a date-time: no time.
    completedAt: _instant(data['completed_at']),
    completedTimes: _times(() => data['completed_times']),
    priority: data['priority'],
    reminderMinutes: data['reminder_minutes'],
    // Missing on an older server: none.
    reminderExtraMinutes: (data['kind'] ?? 'task') == 'note'
        ? const []
        : readExtraLeads(() => data['reminder_extra_minutes']),
    reminderTime: data['reminder_time'],
    // Missing on an older server, or a shape this app can't read: none.
    reminderPlan: (data['kind'] ?? 'task') == 'note'
        ? null
        : ReminderPlan.tryParse(data['reminder_plan']),
    notes: data['notes'],
    listId: data['list_id'],
    assignment: data['assignment'] ?? 'personal',
    assigneeId: data['assignee_id'],
    assigneeName: data['assignee_name'],
    createdBy: data['created_by'],
    // Null, or missing on an older server: the name isn't shown.
    createdByName: data['created_by_name'] is String
        ? data['created_by_name']
        : null,
    labels: List<String>.from(data['labels'] ?? []),
    checklist: (data['checklist'] as List? ?? [])
        .map((item) => ChecklistItem.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    isCompleted: data['is_completed'] == true,
  );
}
