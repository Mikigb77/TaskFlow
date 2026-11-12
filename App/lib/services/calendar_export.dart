import 'dart:convert';
import 'package:agenda/models/device_calendar_event.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/services/task_database.dart';
import 'package:sqflite/sqflite.dart';

/// An event TaskFlow added to a phone calendar for a task, or for one day of
/// a repeating task.
class CalendarExportEntry {
  const CalendarExportEntry(
      {required this.event,
      required this.calendar,
      required this.fingerprint,
      required this.start,
      required this.task});
  final String event, calendar, fingerprint;

  /// When the event starts, in milliseconds since the epoch.
  final int start;
  final int task;
  Map<String, Object> toJson() => {
        'event': event,
        'calendar': calendar,
        'fingerprint': fingerprint,
        'start': start,
        'task': task,
      };
  static CalendarExportEntry? fromJson(Object? data) {
    if (data is! Map) return null;
    final event = data['event'], calendar = data['calendar'];
    final start = data['start'], task = data['task'];
    if (event is! String || event.isEmpty || calendar is! String) return null;
    if (start is! int || task is! int) return null;
    return CalendarExportEntry(
        event: event,
        calendar: calendar,
        fingerprint: data['fingerprint'] as String? ?? '',
        start: start,
        task: task);
  }
}

/// Which events TaskFlow added, per TaskFlow account, so a later change to a
/// task changes its event instead of adding another. Only ids, times and a
/// fingerprint are kept, never a task's words.
class CalendarExportStore {
  CalendarExportStore(this.owner, [TaskDatabase? database])
      : database = database ?? TaskDatabase();
  final String owner;
  final TaskDatabase database;
  Future<Map<String, CalendarExportEntry>> read() async {
    final rows = await (await database.database).query('app_preferences',
        where: 'scope = ?', whereArgs: ['calendar-export:$owner']);
    if (rows.isEmpty) return {};
    try {
      final data = jsonDecode(rows.single['data'] as String);
      if (data is! Map) return {};
      return {
        for (final entry in data.entries)
          if (entry.key is String &&
              CalendarExportEntry.fromJson(entry.value) != null)
            entry.key as String: CalendarExportEntry.fromJson(entry.value)!,
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> write(Map<String, CalendarExportEntry> entries) async =>
      (await database.database).insert(
          'app_preferences',
          {
            'scope': 'calendar-export:$owner',
            'data': jsonEncode(
                {for (final e in entries.entries) e.key: e.value.toJson()}),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
}

/// The event a task should have on the phone's calendar.
class PlannedEvent {
  const PlannedEvent(
      {required this.task,
      required this.title,
      required this.start,
      required this.end,
      required this.allDay});
  final int task;
  final String title;
  final int start, end;
  final bool allDay;
  String fingerprint(String calendar) =>
      jsonEncode([calendar, title, start, end, allDay]);
}

/// Keeps the phone calendar in step with TaskFlow's tasks: one event for each
/// task with a day, and one for each day of a repeating task in the next
/// [repeatDays] days. Moving, renaming or deleting a task changes or removes
/// its event, and completing it marks its title «✓»; events for days already
/// past are left as they were.
class CalendarExporter {
  CalendarExporter(this.bridge, this.store);
  final DeviceCalendars bridge;
  final CalendarExportStore store;

  static const repeatDays = 30;
  static const maxEvents = 500;
  static const batch = 100;

  /// A task with no length still blocks a short slot on the calendar.
  static const defaultMinutes = 30;

  /// The events [tasks] should have from [now] on. A task that doesn't
  /// repeat keeps its event once it has one ([mapped]), even after its day.
  static Map<String, PlannedEvent> plan(List<Task> tasks, DateTime now,
      {int? accountId, Set<String> mapped = const {}}) {
    final today = Task.day(now);
    final planned = <String, PlannedEvent>{};
    PlannedEvent event(Task task) {
      final date = task.displayDate!;
      // A calendar has no «done», so a completed task keeps its event,
      // marked as done.
      final title = task.isCompleted ? '✓ ${task.title}' : task.title;
      if (!task.hasTime) {
        return PlannedEvent(
            task: task.id!,
            title: title,
            start: DateTime.utc(date.year, date.month, date.day)
                .millisecondsSinceEpoch,
            end: DateTime.utc(date.year, date.month, date.day + 1)
                .millisecondsSinceEpoch,
            allDay: true);
      }
      final end =
          task.plannedEnd ?? date.add(const Duration(minutes: defaultMinutes));
      return PlannedEvent(
          task: task.id!,
          title: title,
          start: date.millisecondsSinceEpoch,
          end: end.millisecondsSinceEpoch,
          allDay: false);
    }

    for (final task in tasks) {
      if (task.id == null ||
          task.isNote ||
          task.dueDate == null ||
          task.title.trim().isEmpty ||
          !task.isForAccount(accountId)) {
        continue;
      }
      if (!task.isRecurring) {
        final key = 't:${task.id}';
        if (mapped.contains(key) ||
            !Task.day(task.dueDate!).isBefore(today)) {
          planned[key] = event(task);
        }
        continue;
      }
      for (var offset = 0; offset < repeatDays; offset++) {
        final day = DateTime(today.year, today.month, today.day + offset);
        for (final occurrence in task.occurrencesOn(day)) {
          planned['t:${task.id}@${occurrence.occurrenceId}'] =
              event(occurrence);
        }
      }
    }
    if (planned.length <= maxEvents) return planned;
    final first = planned.entries.toList()
      ..sort((a, b) => a.value.start.compareTo(b.value.start));
    return Map.fromEntries(first.take(maxEvents));
  }

  /// Brings [targets]' events in step with [tasks]; a calendar no longer
  /// among them loses the events TaskFlow added there from today on. Returns
  /// the event ids TaskFlow now has on the phone, so Calendar doesn't show a
  /// task twice.
  Future<Set<String>> sync(List<Task> tasks, List<DeviceCalendar> targets,
      {required DateTime now, int? accountId}) async {
    final entries = await store.read();
    for (var pass = 0; pass < 2; pass++) {
      final gone = await _pass(entries, tasks, targets, now, accountId);
      if (!gone) break;
    }
    return {for (final entry in entries.values) entry.event};
  }

  /// Keys are the calendar's id, `|`, then the task's key from [plan].
  Future<bool> _pass(Map<String, CalendarExportEntry> entries, List<Task> tasks,
      List<DeviceCalendar> targets, DateTime now, int? accountId) async {
    final today = Task.day(now).millisecondsSinceEpoch;
    final ids = {for (final task in tasks) ?task.id};
    final planned = <String, (String, PlannedEvent)>{};
    for (final target in {for (final t in targets) t.id}) {
      final prefix = '$target|';
      final mapped = {
        for (final key in entries.keys)
          if (key.startsWith(prefix)) key.substring(prefix.length)
      };
      for (final MapEntry(:key, :value)
          in plan(tasks, now, accountId: accountId, mapped: mapped).entries) {
        planned['$prefix$key'] = (target, value);
      }
    }
    final writes = <(String, CalendarWrite, (String, PlannedEvent)?)>[];
    final handled = <String>{};
    for (final MapEntry(:key, value: entry) in entries.entries) {
      final want = planned[key];
      final repeating = key.contains('@');
      final past = entry.start < today;
      final target = targets.any((t) => t.id == entry.calendar);
      if (!ids.contains(entry.task)) {
        writes.add((key, _delete(entry), null));
      } else if (want != null) {
        handled.add(key);
        if (want.$2.fingerprint(want.$1) != entry.fingerprint) {
          writes.add((
            key,
            CalendarWrite.update(
                event: entry.event,
                calendar: want.$1,
                title: want.$2.title,
                start: want.$2.start,
                end: want.$2.end,
                allDay: want.$2.allDay),
            want
          ));
        }
      } else if (past && (repeating || !target)) {
        // Days gone by keep their events.
        handled.add(key);
      } else {
        writes.add((key, _delete(entry), null));
      }
    }
    for (final MapEntry(:key, value: want) in planned.entries) {
      if (handled.contains(key)) continue;
      writes.add((
        key,
        CalendarWrite.insert(
            calendar: want.$1,
            title: want.$2.title,
            start: want.$2.start,
            end: want.$2.end,
            allDay: want.$2.allDay),
        want
      ));
    }
    if (writes.isEmpty) return false;
    var gone = false;
    for (var from = 0; from < writes.length; from += batch) {
      final chunk = writes.skip(from).take(batch).toList();
      final answers = await bridge.write([for (final w in chunk) w.$2]);
      for (var i = 0; i < chunk.length; i++) {
        final (key, write, want) = chunk[i];
        final answer = i < answers.length ? answers[i] : '';
        CalendarExportEntry entry(String event) => CalendarExportEntry(
            event: event,
            calendar: want!.$1,
            fingerprint: want.$2.fingerprint(want.$1),
            start: want.$2.start,
            task: want.$2.task);
        switch (write.op) {
          case 'delete':
            // Kept when the phone couldn't delete it, to try again.
            if (answer == 'ok') entries.remove(key);
          case 'update':
            if (answer == 'ok') {
              entries[key] = entry(write.event);
            } else {
              // Deleted in the calendar app: the next pass adds it again.
              entries.remove(key);
              gone = true;
            }
          case 'insert':
            if (answer.isNotEmpty) entries[key] = entry(answer);
        }
      }
      await store.write(entries);
    }
    return gone;
  }

  CalendarWrite _delete(CalendarExportEntry entry) =>
      CalendarWrite.delete(event: entry.event, calendar: entry.calendar);

  /// The event ids TaskFlow added, for hiding them among the phone's events.
  Future<Set<String>> added() async =>
      {for (final entry in (await store.read()).values) entry.event};
}
