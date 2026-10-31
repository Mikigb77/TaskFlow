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

class DeviceCalendars {
  DeviceCalendars({MethodChannel? channel, bool? supported})
      : channel = channel ?? const MethodChannel('taskflow/device_calendars'),
        supported = supported ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
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
