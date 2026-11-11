import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:agenda/models/device_calendar_event.dart';

enum CalendarAccess { checking, denied, blocked, granted, unavailable }

class CalendarRead<T> {
  const CalendarRead(this.items, {this.truncated = false});
  final List<T> items;
  final bool truncated;
}

/// One change to a phone calendar event that TaskFlow added for a task.
class CalendarWrite {
  const CalendarWrite.insert(
      {required this.calendar,
      required this.title,
      required this.start,
      required this.end,
      required this.allDay})
      : op = 'insert',
        event = '';
  const CalendarWrite.update(
      {required this.event,
      required this.calendar,
      required this.title,
      required this.start,
      required this.end,
      required this.allDay})
      : op = 'update';
  const CalendarWrite.delete({required this.event, required this.calendar})
      : op = 'delete',
        title = '',
        start = 0,
        end = 0,
        allDay = false;
  final String op, event, calendar, title;

  /// Milliseconds since the epoch; an all-day event's are UTC midnights.
  final int start, end;
  final bool allDay;
  Map<String, Object> toMap() => {
        'op': op,
        'event': event,
        'calendar': calendar,
        'title': title,
        'start': start,
        'end': end,
        'allDay': allDay,
      };
}

class DeviceCalendars {
  DeviceCalendars({MethodChannel? channel, bool? supported})
      : channel = channel ?? const MethodChannel('taskflow/device_calendars'),
        supported = supported ??
            (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS)) {
    this.channel.setMethodCallHandler((call) async {
      if (call.method == 'changed' && !_changes.isClosed) _changes.add(null);
    });
  }
  final MethodChannel channel;
  final bool supported;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  Future<CalendarAccess> status({bool request = false}) async {
    if (!supported) return CalendarAccess.unavailable;
    try {
      final value = await channel
          .invokeMethod<String>(request ? 'requestPermission' : 'status');
      return CalendarAccess.values
              .where((access) => access.name == value)
              .firstOrNull ??
          CalendarAccess.unavailable;
    } on MissingPluginException {
      return CalendarAccess.unavailable;
    }
  }

  /// Whether TaskFlow may add events, asked for only when the person turns on
  /// «TaskFlow in your calendar». On iOS full access covers both.
  Future<CalendarAccess> writeAccess({bool request = false}) async {
    if (!supported) return CalendarAccess.unavailable;
    try {
      final value = await channel.invokeMethod<String>(
          request ? 'requestWritePermission' : 'writeStatus');
      return CalendarAccess.values
              .where((access) => access.name == value)
              .firstOrNull ??
          CalendarAccess.unavailable;
    } on MissingPluginException {
      return CalendarAccess.unavailable;
    }
  }

  /// Applies [writes] in order and returns one answer for each: an insert's
  /// new event id (empty when it failed), else `ok` or `gone`.
  Future<List<String>> write(List<CalendarWrite> writes) async {
    if (writes.isEmpty) return const [];
    final data = await channel.invokeListMethod<Object?>('write', {
      'writes': [for (final item in writes) item.toMap()],
    }).timeout(const Duration(seconds: 30));
    return [for (final item in data ?? const []) item is String ? item : ''];
  }

  Future<CalendarRead<DeviceCalendar>> calendars() async {
    final data = (await channel
        .invokeMapMethod<String, dynamic>('calendars')
        .timeout(const Duration(seconds: 15)))!;
    return CalendarRead(
        (data['items'] as List)
            .map((item) =>
                DeviceCalendar.fromMap(Map<Object?, Object?>.from(item)))
            .toList(),
        truncated: data['truncated'] == true);
  }

  Future<CalendarRead<DeviceCalendarEvent>> events(
      Set<String> ids, DateTime day) async {
    final data = (await channel.invokeMapMethod<String, dynamic>('events', {
      'calendars': ids.toList()..sort(),
      'start': DateTime(day.year, day.month, day.day).millisecondsSinceEpoch,
      'end': DateTime(day.year, day.month, day.day + 1).millisecondsSinceEpoch,
    }).timeout(const Duration(seconds: 15)))!;
    return CalendarRead(
        (data['items'] as List)
            .map((item) =>
                DeviceCalendarEvent.fromMap(Map<Object?, Object?>.from(item)))
            .toList(),
        truncated: data['truncated'] == true);
  }

  Future<void> settings() => channel.invokeMethod('settings');
  Future<void> open(DeviceCalendarEvent event) => channel.invokeMethod('open', {
        'id': event.id,
        'start': event.start.millisecondsSinceEpoch,
        'end': event.end.millisecondsSinceEpoch,
      });
  void close() {
    channel.setMethodCallHandler(null);
    _changes.close();
  }
}
