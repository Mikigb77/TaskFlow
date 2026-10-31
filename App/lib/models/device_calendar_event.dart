import 'dart:convert';

class DeviceCalendar {
  const DeviceCalendar(
      {required this.id,
      required this.name,
      this.account = '',
      this.accountType = '',
      this.sourceId = '',
      this.color = 0});
  final String id, name, account, accountType, sourceId;
  final int color;
  // A reused provider row ID must not select a different account's calendar.
  String get selectionKey => jsonEncode([id, accountType, account, sourceId]);
  factory DeviceCalendar.fromMap(Map<Object?, Object?> map) => DeviceCalendar(
      id: map['id'] as String,
      name: map['name'] as String,
      account: map['account'] as String? ?? '',
      color: map['color'] as int? ?? 0,
      accountType: map['accountType'] as String? ?? '',
      sourceId: map['sourceId'] as String? ?? '');
}

/// Read-only event instances never become Task rows or participate in sync,
/// reminders, completion or AI. All-day ends are exclusive calendar dates.
class DeviceCalendarEvent {
  const DeviceCalendarEvent(
      {required this.id,
      required this.calendarId,
      required this.title,
      required this.start,
      required this.end,
      required this.allDay,
      this.location = '',
      this.timezone = '',
      this.uid = '',
      this.sources = const []});
  final String id, calendarId, title, location, timezone, uid;
  final DateTime start, end;
  final bool allDay;
  final List<DeviceCalendar> sources;
  String get identity =>
      '${uid.isEmpty ? '$calendarId/$id' : 'uid:$uid'}/${start.millisecondsSinceEpoch}/${end.millisecondsSinceEpoch}/$allDay';
  factory DeviceCalendarEvent.fromMap(Map<Object?, Object?> map) {
    final start =
        DateTime.fromMillisecondsSinceEpoch(map['start'] as int, isUtc: true);
    final end =
        DateTime.fromMillisecondsSinceEpoch(map['end'] as int, isUtc: true);
    if (end.isBefore(start)) {
      throw const FormatException(
          'The calendar returned an invalid event range.');
    }
    return DeviceCalendarEvent(
        id: map['id'] as String,
        calendarId: map['calendarId'] as String,
        title: map['title'] as String? ?? '',
        location: map['location'] as String? ?? '',
        timezone: map['timezone'] as String? ?? '',
        start: start,
        end: end,
        allDay: map['allDay'] == true,
        uid: map['uid'] as String? ?? '');
  }

  bool occursOn(DateTime day) {
    final from = allDay
        ? DateTime.utc(day.year, day.month, day.day)
        : DateTime(day.year, day.month, day.day);
    final until = allDay
        ? DateTime.utc(day.year, day.month, day.day + 1)
        : DateTime(day.year, day.month, day.day + 1);
    return overlaps(from, until);
  }

  bool overlaps(DateTime from, DateTime until) =>
      start.isBefore(until) &&
      (start.isAtSameMomentAs(end) ? !start.isBefore(from) : end.isAfter(from));

  DeviceCalendarEvent withSources(List<DeviceCalendar> value) =>
      DeviceCalendarEvent(
          id: id,
          calendarId: calendarId,
          title: title,
          start: start,
          end: end,
          allDay: allDay,
          location: location,
          timezone: timezone,
          uid: uid,
          sources: value);

  static List<DeviceCalendarEvent> forDay(List<DeviceCalendarEvent> events,
      List<DeviceCalendar> calendars, Set<String> selected, DateTime day) {
    final known = {for (final calendar in calendars) calendar.id: calendar};
    final unique = <String, DeviceCalendarEvent>{};
    for (final event in events) {
      final calendar = known[event.calendarId];
      if (!selected.contains(event.calendarId) ||
          calendar == null ||
          !event.occursOn(day)) {
        continue;
      }
      final before = unique[event.identity];
      unique[event.identity] = (before ?? event).withSources([
        ...?before?.sources,
        if (before == null ||
            !before.sources.any((source) => source.id == calendar.id))
          calendar,
      ]);
    }
    return unique.values.toList()
      ..sort((a, b) {
        if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
        final order = a.start.compareTo(b.start);
        return order == 0 ? a.identity.compareTo(b.identity) : order;
      });
  }
}
