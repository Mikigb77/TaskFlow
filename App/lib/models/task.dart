import 'dart:convert';
import 'dart:math' as math;

const _unchanged = Object();

class Task {
  final int? id;
  final String title;

  /// First occurrence. Null means Inbox; hasTime=false is a calendar date.
  final DateTime? dueDate;
  final bool hasTime;
  final String recurrence;
  final DateTime? repeatUntil;
  final List<String> completedDates;

  /// A calendar projection, never persisted as the series start date.
  final DateTime? occurrenceDate;
  final int priority;

  /// Null follows device defaults; -1 disables; otherwise minutes before.
  final int? reminderMinutes;

  /// Local minute of day for date-only tasks. Null follows device defaults.
  final int? reminderTime;
  final bool _isCompleted;
  final String? notes;
  final List<String> filePaths;
  final List<String> imagePaths;

  Task(
      {this.id,
      required this.title,
      this.dueDate,
      bool hasTime = true,
      this.recurrence = 'none',
      this.repeatUntil,
      List<String>? completedDates,
      this.occurrenceDate,
      required this.priority,
      this.reminderMinutes,
      this.reminderTime,
      bool isCompleted = false,
      this.notes,
      List<String>? filePaths,
      List<String>? imagePaths})
      : hasTime = dueDate != null && hasTime,
        _isCompleted = isCompleted,
        completedDates = List.unmodifiable(completedDates ?? []),
        filePaths = filePaths ?? [],
        imagePaths = imagePaths ?? [];

  static const repeats = {
    'none': 'Does not repeat',
    'daily': 'Daily',
    'weekly': 'Weekly',
    'monthly': 'Monthly',
    'yearly': 'Yearly'
  };
  bool get isRecurring => recurrence != 'none' && dueDate != null;
  DateTime? get displayDate => occurrenceDate ?? dueDate;
  bool get isCompleted => isRecurring && occurrenceDate != null
      ? completedDates.contains(dateKey(occurrenceDate!))
      : _isCompleted;
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
    if (recurrence == 'daily') date += index;
    if (recurrence == 'weekly') date += index * 7;
    if (recurrence == 'monthly' || recurrence == 'yearly') {
      final target = DateTime(year + (recurrence == 'yearly' ? index : 0),
          month + (recurrence == 'monthly' ? index : 0));
      year = target.year;
      month = target.month;
      date = math.min(start.day, DateTime(year, month + 1, 0).day);
    }
    return DateTime(year, month, date, hasTime ? start.hour : 0,
        hasTime ? start.minute : 0);
  }

  int _indexNear(DateTime date) {
    final start = dueDate!;
    final days = DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(start.year, start.month, start.day))
        .inDays;
    return math.max(
        0,
        switch (recurrence) {
          'daily' => days,
          'weekly' => days ~/ 7,
          'monthly' => (date.year - start.year) * 12 + date.month - start.month,
          'yearly' => date.year - start.year,
          _ => 0,
        });
  }

  Task? occurrenceOn(DateTime date) {
    if (dueDate == null) return null;
    if (!isRecurring) return dateKey(dueDate!) == dateKey(date) ? this : null;
    if (day(date).isBefore(day(dueDate!)) ||
        (repeatUntil != null && day(date).isAfter(day(repeatUntil!)))) {
      return null;
    }
    final occurrence = _dateAt(_indexNear(date));
    return dateKey(occurrence) == dateKey(date)
        ? copyWith(occurrenceDate: occurrence)
        : null;
  }

  /// Show the next open occurrence from today; past occurrences stay in Calendar.
  Task? nextOpenOccurrence({DateTime? from}) {
    if (!isRecurring) return isCompleted ? null : this;
    final first = day(from ?? DateTime.now());
    var index = _indexNear(first);
    for (var attempts = 0;
        attempts <= completedDates.length + 2;
        attempts++, index++) {
      final date = _dateAt(index);
      if (repeatUntil != null && day(date).isAfter(day(repeatUntil!))) {
        return null;
      }
      if (!day(date).isBefore(first) &&
          !completedDates.contains(dateKey(date))) {
        return copyWith(occurrenceDate: date);
      }
    }
    return null;
  }

  Task copyWith(
          {int? id,
          String? title,
          Object? dueDate = _unchanged,
          bool? hasTime,
          String? recurrence,
          Object? repeatUntil = _unchanged,
          List<String>? completedDates,
          Object? occurrenceDate = _unchanged,
          int? priority,
          Object? reminderMinutes = _unchanged,
          Object? reminderTime = _unchanged,
          bool? isCompleted,
          String? notes,
          List<String>? filePaths,
          List<String>? imagePaths}) =>
      Task(
          id: id ?? this.id,
          title: title ?? this.title,
          dueDate: identical(dueDate, _unchanged)
              ? this.dueDate
              : dueDate as DateTime?,
          hasTime: hasTime ?? this.hasTime,
          recurrence: recurrence ?? this.recurrence,
          repeatUntil: identical(repeatUntil, _unchanged)
              ? this.repeatUntil
              : repeatUntil as DateTime?,
          completedDates: completedDates ?? this.completedDates,
          occurrenceDate: identical(occurrenceDate, _unchanged)
              ? this.occurrenceDate
              : occurrenceDate as DateTime?,
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
          imagePaths: imagePaths ?? this.imagePaths);

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'dueDate': dueDate == null
            ? null
            : hasTime
                ? dueDate!.toIso8601String()
                : dateKey(dueDate!),
        'hasTime': hasTime ? 1 : 0,
        'recurrence': recurrence,
        'repeatUntil': repeatUntil == null ? null : dateKey(repeatUntil!),
        'completedDates': jsonEncode(completedDates),
        'priority': priority,
        'reminderMinutes': reminderMinutes,
        'reminderTime': reminderTime,
        'isCompleted': _isCompleted ? 1 : 0,
        'notes': notes,
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
      recurrence: map['recurrence'] ?? 'none',
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
        'due_date': hasTime ? dueDate?.toUtc().toIso8601String() : null,
        'scheduled_date':
            !hasTime && dueDate != null ? dateKey(dueDate!) : null,
        'recurrence': recurrence,
        'repeat_until': repeatUntil == null ? null : dateKey(repeatUntil!),
        'completed_dates': completedDates,
        'priority': priority,
        'reminder_minutes': reminderMinutes,
        'reminder_time': reminderTime,
        'notes': notes ?? '',
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
      recurrence: data['recurrence'] ?? 'none',
      repeatUntil: data['repeat_until'] == null
          ? null
          : DateTime.parse(data['repeat_until']),
      completedDates: List<String>.from(data['completed_dates'] ?? []),
      priority: data['priority'],
      reminderMinutes: data['reminder_minutes'],
      reminderTime: data['reminder_time'],
      notes: data['notes'],
      isCompleted: data['is_completed'] == true);
}
