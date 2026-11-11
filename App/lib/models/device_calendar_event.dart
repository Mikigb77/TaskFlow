import 'dart:convert';

/// What a phone calendar holds, for the account-first picker: an account's
/// own calendars come with its one tick; holidays, birthdays, week numbers
/// and calendars it can only read wait in «More options», off by default.
enum CalendarKind { own, holidays, birthdays, weekNumbers, other }

class DeviceCalendar {
  const DeviceCalendar(
      {required this.id,
      required this.name,
      this.account = '',
      this.accountType = '',
      this.sourceId = '',
      this.color = 0,
      this.writable = true,
      this.primary = false,
      this.type = ''});
  final String id, name, account, accountType, sourceId;
  final int color;

  /// The phone lets apps add events here: Android's access level is at least
  /// contributor; iOS allows content modifications.
  final bool writable;

  /// The account's main calendar, where new tasks go by default.
  final bool primary;

  /// The platform's own word for a special calendar, when it has one:
  /// `birthdays`, `holidays` or `subscription` (iOS). Empty otherwise.
  final String type;

  // A reused provider row ID must not select a different account's calendar.
  String get selectionKey => jsonEncode([id, accountType, account, sourceId]);

  /// The account this calendar belongs to, as one tick on the picker.
  String get accountKey => jsonEncode([accountType, account]);

  /// The account a [selectionKey] names, without the calendar's list.
  static String? accountKeyOf(String selectionKey) {
    try {
      final parts = jsonDecode(selectionKey);
      if (parts is List && parts.length == 4) {
        return jsonEncode([parts[1], parts[2]]);
      }
    } on FormatException {
      // Not a key this app wrote.
    }
    return null;
  }

  /// A calendar kept on the phone only, with no account behind it.
  bool get onPhone {
    final value = accountType.toLowerCase();
    return account.isEmpty || value == 'local' || value.endsWith('.local');
  }

  CalendarKind get kind {
    final source = '$sourceId $name'.toLowerCase();
    if (type == 'holidays' || source.contains('#holiday@')) {
      return CalendarKind.holidays;
    }
    if (type == 'birthdays' || source.contains('#contacts@')) {
      return CalendarKind.birthdays;
    }
    if (source.contains('#weeknum@')) return CalendarKind.weekNumbers;
    if (writable && type != 'subscription') return CalendarKind.own;
    return CalendarKind.other;
  }

  bool get isOwn => kind == CalendarKind.own;

  /// The calendar's name as people read it, or empty when the phone gives
  /// only an address or an id («es.spain#holiday@group.v.calendar.google.com»);
  /// the picker then names it by its [kind].
  String get readableName {
    final value = name.trim();
    if (value.isEmpty || value.contains('#') || value.contains('@')) return '';
    return value;
  }

  factory DeviceCalendar.fromMap(Map<Object?, Object?> map) => DeviceCalendar(
      id: map['id'] as String,
      name: map['name'] as String,
      account: map['account'] as String? ?? '',
      color: map['color'] as int? ?? 0,
      accountType: map['accountType'] as String? ?? '',
      sourceId: map['sourceId'] as String? ?? '',
      writable: map['writable'] as bool? ?? true,
      primary: map['primary'] as bool? ?? false,
      type: map['type'] as String? ?? '');
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
