import 'dart:math' as math;
import 'package:agenda/models/device_calendar_event.dart';
import 'package:agenda/models/task.dart';

enum TimelineKind { planned, deadline, calendar }

class TimelineEntry {
  const TimelineEntry(
      {required this.kind,
      required this.start,
      required this.end,
      this.task,
      this.event});
  final TimelineKind kind;
  final DateTime start, end;
  final Task? task;
  final DeviceCalendarEvent? event;
  String get title => task?.title ?? event!.title;
  String get id =>
      '${kind.name}/${task == null ? event!.identity : '${task!.id}/${task!.occurrenceId ?? 'once'}'}';
  bool get point => start.isAtSameMomentAs(end);
}

/// Uses elapsed time between LOCAL midnights, so DST days can contain 23/25
/// hours. A caller can supply zoned boundaries for deterministic DST tests.
class TimelineWindow {
  TimelineWindow(this.start, this.end) {
    if (!end.isAfter(start)) {
      throw ArgumentError('A timeline needs a positive range.');
    }
  }
  factory TimelineWindow.day(DateTime day) => TimelineWindow(
      DateTime(day.year, day.month, day.day),
      DateTime(day.year, day.month, day.day + 1));
  final DateTime start, end;
  double get minutes =>
      end.difference(start).inMicroseconds / Duration.microsecondsPerMinute;
  bool contains(DateTime value) =>
      !value.isBefore(start) && value.isBefore(end);
  bool overlaps(TimelineEntry entry) => entry.point
      ? contains(entry.start)
      : entry.start.isBefore(end) && entry.end.isAfter(start);
  double offset(DateTime value) =>
      value.difference(start).inMicroseconds / Duration.microsecondsPerMinute;
  List<DateTime> get hours =>
      [for (var i = 0; i * 60 <= minutes; i++) start.add(Duration(hours: i))];
}

class DayTimeline {
  const DayTimeline(
      {required this.window,
      required this.entries,
      required this.unblocked,
      required this.allDayEvents});
  final TimelineWindow window;
  final List<TimelineEntry> entries;
  final List<Task> unblocked;
  final List<DeviceCalendarEvent> allDayEvents;
  factory DayTimeline.build(
      DateTime day, List<Task> tasks, List<DeviceCalendarEvent> events,
      {TimelineWindow? window}) {
    final range = window ?? TimelineWindow.day(day);
    final entries = <TimelineEntry>[];
    final unblocked = <Task>[];
    for (final series in tasks) {
      for (final task in series.calendarOccurrencesOn(day)) {
        var hasBlock = false;
        if (task.hasTime && task.displayDate != null) {
          final entry = TimelineEntry(
              kind: TimelineKind.planned,
              start: task.displayDate!,
              end: task.plannedEnd ?? task.displayDate!,
              task: task);
          if (range.overlaps(entry)) {
            entries.add(entry);
            hasBlock = true;
          }
        }
        final deadline = task.displayDeadline;
        if (task.deadlineHasTime &&
            deadline != null &&
            range.contains(deadline)) {
          entries.add(TimelineEntry(
              kind: TimelineKind.deadline,
              start: deadline,
              end: deadline,
              task: task));
          hasBlock = true;
        }
        final dateOnlyDeadline = deadline != null &&
            !task.deadlineHasTime &&
            Task.dateKey(deadline) == Task.dateKey(day);
        if (!hasBlock || dateOnlyDeadline) unblocked.add(task);
      }
    }
    final allDay = <DeviceCalendarEvent>[];
    for (final event in events) {
      if (!event.occursOn(day)) continue;
      if (event.allDay) {
        allDay.add(event);
        continue;
      }
      final entry = TimelineEntry(
          kind: TimelineKind.calendar,
          start: event.start,
          end: event.end,
          event: event);
      if (range.overlaps(entry)) entries.add(entry);
    }
    entries.sort((a, b) {
      final order = a.start.compareTo(b.start);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return DayTimeline(
        window: range,
        entries: entries,
        unblocked: unblocked,
        allDayEvents: allDay);
  }
}

class TimelinePlacement {
  const TimelinePlacement(
      this.entry, this.lane, this.top, this.height, this.durationHeight);
  final TimelineEntry entry;
  final int lane;
  final double top, height, durationHeight;
}

class TimelineLayout {
  const TimelineLayout(this.items, this.lanes);
  final List<TimelinePlacement> items;
  final int lanes;
  factory TimelineLayout.place(
      List<TimelineEntry> entries, TimelineWindow window,
      {double pixelsPerMinute = 1.2, double minimumHeight = 52}) {
    final laneEnds = <double>[];
    final items = <TimelinePlacement>[];
    final ordered = [...entries]..sort((a, b) => a.start.compareTo(b.start));
    for (final entry in ordered.where(window.overlaps)) {
      final top = math.max(0.0, window.offset(entry.start)) * pixelsPerMinute;
      final bottom =
          math.min(window.minutes, window.offset(entry.end)) * pixelsPerMinute;
      final duration = math.max(2.0, bottom - top);
      final height = math.max(minimumHeight, duration);
      var lane = laneEnds.indexWhere((end) => end <= top);
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(0);
      }
      laneEnds[lane] = top + height + 4;
      items.add(TimelinePlacement(entry, lane, top, height, duration));
    }
    return TimelineLayout(items, math.max(1, laneEnds.length));
  }
}
