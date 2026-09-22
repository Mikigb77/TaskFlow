import 'dart:convert';
import 'dart:math' as math;
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/occurrence_exception.dart';

const _unchanged = Object();

class Task {
  final int? id;
  final String title;

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

  /// Local minute of day for date-only tasks. Null follows device defaults.
  final int? reminderTime;
  final bool _isCompleted;
  final String? notes;
  final List<String> filePaths;
  final List<String> imagePaths;
  final List<ChecklistItem> checklist;
  final String? listId;
  final List<String> labels;
  String? get checklistOccurrence => occurrenceId;
  int get checklistDone => checklist
      .where((item) => item.done(occurrence: checklistOccurrence))
      .length;

  Task(
      {this.id,
      required this.title,
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
      this.occurrenceDate,
      this.occurrenceKey,
      this.occurrenceHasTime,
      required this.priority,
      this.reminderMinutes,
      this.reminderTime,
      bool isCompleted = false,
      this.notes,
      List<String>? filePaths,
      List<String>? imagePaths,
      List<ChecklistItem>? checklist,
      this.listId,
      List<String>? labels})
      : _hasTime = dueDate != null && hasTime,
        deadlineHasTime = deadline != null && deadlineHasTime,
        repeatWeekdays =
            List.unmodifiable(repeatWeekdays.toSet().toList()..sort()),
        exceptions = List.unmodifiable([...exceptions]
          ..sort((a, b) => a.originalDate.compareTo(b.originalDate))),
        _isCompleted = isCompleted,
        completedDates = List.unmodifiable(completedDates ?? []),
        filePaths = filePaths ?? [],
        checklist = List.unmodifiable(checklist ?? []),
        labels = List.unmodifiable((labels ?? [])
            .map((label) => label.trim().toLowerCase())
            .where((label) => label.isNotEmpty)
            .toSet()),
        imagePaths = imagePaths ?? [] {
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
    'yearly': 'Yearly'
  };
  bool get isRecurring => recurrence != 'none' && dueDate != null;
  DateTime? get displayDate => occurrenceDate ?? dueDate;

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
        deadlineHasTime ? deadline!.second : 0);
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
    final original =
        DateTime(date.year, date.month, date.day - _deadlineDayOffset);
    final instance = occurrenceByKey(dateKey(original));
    return instance == null ? [] : [instance];
  }

  /// Day agendas include deadline-only tasks and the tail of overnight blocks.
  /// All entries still carry the original recurrence identity for actions.
  List<Task> calendarOccurrencesOn(DateTime date) {
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
            DateTime(date.year, date.month, date.day - offset))) {
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
      _ => ''
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
        date += -(start.weekday - 1) +
            (index ~/ repeatWeekdays.length) * 7 * repeatInterval +
            repeatWeekdays[index % repeatWeekdays.length] -
            1;
      }
    }
    if (recurrence == 'monthly' || recurrence == 'yearly') {
      final target = DateTime(
          year + (recurrence == 'yearly' ? index * repeatInterval : 0),
          month + (recurrence == 'monthly' ? index * repeatInterval : 0));
      year = target.year;
      month = target.month;
      date = math.min(start.day, DateTime(year, month + 1, 0).day);
    }
    return DateTime(year, month, date, _hasTime ? start.hour : 0,
        _hasTime ? start.minute : 0);
  }

  int _indexNear(DateTime date) {
    final start = dueDate!;
    final days = DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(start.year, start.month, start.day))
        .inDays;
    return math.max(
        0,
        switch (recurrence) {
          'daily' => days ~/ repeatInterval,
          'weekly' => repeatWeekdays.isEmpty
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
    return List.generate(length, (offset) => _dateAt(index + offset))
        .any((value) => dateKey(value) == dateKey(date));
  }

  /// Lookup by the original date, which stays stable after a one-off move.
  Task? occurrenceByKey(String key) {
    final original = DateTime.tryParse(key);
    if (original == null || !isBaseOccurrence(original)) return null;
    final change =
        exceptions.where((item) => item.originalDate == key).firstOrNull;
    if (change?.skipped == true) return null;
    final date = change?.date ??
        DateTime(original.year, original.month, original.day,
            _hasTime ? dueDate!.hour : 0, _hasTime ? dueDate!.minute : 0);
    return copyWith(
        occurrenceDate: date,
        occurrenceKey: key,
        occurrenceHasTime: change?.hasTime ?? _hasTime);
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
              occurrenceHasTime: false);

  /// Show the next open occurrence from today; past occurrences stay in Calendar.
  Task? nextOpenOccurrence({DateTime? from}) {
    if (!isRecurring) return isCompleted ? null : this;
    final first = day(from ?? DateTime.now());
    final moved = exceptions
        .map((change) => occurrenceByKey(change.originalDate))
        .whereType<Task>()
        .where((task) =>
            !task.isCompleted && !day(task.displayDate!).isBefore(first))
        .toList()
      ..sort(compareBySchedule);
    Task? best = moved.firstOrNull;
    var index = _indexNear(first);
    for (var attempts = 0;
        attempts <=
            completedDates.length +
                exceptions.length +
                repeatWeekdays.length +
                2;
        attempts++, index++) {
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

  Task copyWith(
          {int? id,
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
          Object? occurrenceDate = _unchanged,
          Object? occurrenceKey = _unchanged,
          Object? occurrenceHasTime = _unchanged,
          int? priority,
          Object? reminderMinutes = _unchanged,
          Object? reminderTime = _unchanged,
          bool? isCompleted,
          String? notes,
          List<String>? filePaths,
          List<String>? imagePaths,
          List<ChecklistItem>? checklist,
          Object? listId = _unchanged,
          List<String>? labels}) =>
      Task(
          id: id ?? this.id,
          title: title ?? this.title,
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
          reminderTime: identical(reminderTime, _unchanged)
              ? this.reminderTime
              : reminderTime as int?,
          isCompleted: isCompleted ?? _isCompleted,
          notes: notes ?? this.notes,
          filePaths: filePaths ?? this.filePaths,
          checklist: checklist ?? this.checklist,
          listId:
              identical(listId, _unchanged) ? this.listId : listId as String?,
          labels: labels ?? this.labels,
          imagePaths: imagePaths ?? this.imagePaths);

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
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
        'exceptions':
            jsonEncode(exceptions.map((change) => change.toJson()).toList()),
        'repeatUntil': repeatUntil == null ? null : dateKey(repeatUntil!),
        'completedDates': jsonEncode(completedDates),
        'priority': priority,
        'reminderMinutes': reminderMinutes,
        'reminderTime': reminderTime,
        'isCompleted': _isCompleted ? 1 : 0,
        'notes': notes,
        'listId': listId,
        'labels': jsonEncode(labels),
        'checklist':
            jsonEncode(checklist.map((item) => item.toJson()).toList()),
        'filePaths': filePaths.isEmpty ? null : filePaths.join('|'),
        'imagePaths': imagePaths.isEmpty ? null : imagePaths.join('|'),
      };

  static Task fromMap(Map<String, dynamic> map) => Task(
      id: map['id'],
      title: map['title'],
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
          .map((value) =>
              OccurrenceException.fromJson(Map<String, dynamic>.from(value)))
          .toList(),
      repeatUntil: map['repeatUntil'] == null
          ? null
          : DateTime.parse(map['repeatUntil']),
      completedDates:
          List<String>.from(jsonDecode(map['completedDates'] ?? '[]')),
      priority: map['priority'],
      reminderMinutes: map['reminderMinutes'],
      reminderTime: map['reminderTime'],
      isCompleted: map['isCompleted'] == 1,
      notes: map['notes'],
      listId: map['listId'],
      labels: List<String>.from(jsonDecode(map['labels'] ?? '[]')),
      checklist: (jsonDecode(map['checklist'] ?? '[]') as List)
          .map(
              (item) => ChecklistItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      filePaths: (map['filePaths'] as String?)
          ?.split('|')
          .where((p) => p.isNotEmpty)
          .toList(),
      imagePaths: (map['imagePaths'] as String?)
          ?.split('|')
          .where((p) => p.isNotEmpty)
          .toList());

  Map<String, dynamic> toApi() => {
        'title': title,
        'due_date': _hasTime ? dueDate?.toUtc().toIso8601String() : null,
        'scheduled_date':
            !_hasTime && dueDate != null ? dateKey(dueDate!) : null,
        'deadline_at':
            deadlineHasTime ? deadline?.toUtc().toIso8601String() : null,
        'deadline_date':
            !deadlineHasTime && deadline != null ? dateKey(deadline!) : null,
        'duration_minutes': durationMinutes,
        'reminder_anchor': reminderAnchor,
        'recurrence': recurrence,
        'repeat_interval': repeatInterval,
        'repeat_weekdays': repeatWeekdays,
        'exceptions': exceptions.map((change) => change.toJson()).toList(),
        'repeat_until': repeatUntil == null ? null : dateKey(repeatUntil!),
        'completed_dates': completedDates,
        'priority': priority,
        'reminder_minutes': reminderMinutes,
        'reminder_time': reminderTime,
        'notes': notes ?? '',
        'list_id': listId,
        'labels': labels,
        'checklist': checklist.map((item) => item.toJson()).toList(),
        'is_completed': _isCompleted,
      };

  static Task fromApi(Map<String, dynamic> data) => Task(
      title: data['title'],
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
          .map((value) =>
              OccurrenceException.fromJson(Map<String, dynamic>.from(value)))
          .toList(),
      repeatUntil: data['repeat_until'] == null
          ? null
          : DateTime.parse(data['repeat_until']),
      completedDates: List<String>.from(data['completed_dates'] ?? []),
      priority: data['priority'],
      reminderMinutes: data['reminder_minutes'],
      reminderTime: data['reminder_time'],
      notes: data['notes'],
      listId: data['list_id'],
      labels: List<String>.from(data['labels'] ?? []),
      checklist: (data['checklist'] as List? ?? [])
          .map(
              (item) => ChecklistItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      isCompleted: data['is_completed'] == true);
}
