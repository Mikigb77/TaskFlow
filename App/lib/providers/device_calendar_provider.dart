import 'dart:async';
import 'dart:convert';
import 'package:agenda/models/device_calendar_event.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class CalendarPreferences {
  const CalendarPreferences({this.enabled = false, this.selected = const {}});
  final bool enabled;
  final Set<String> selected;
  Map<String, dynamic> toJson() =>
      {'enabled': enabled, 'selected': selected.toList()..sort()};
  factory CalendarPreferences.fromJson(Map<String, dynamic> data) =>
      CalendarPreferences(
          enabled: data['enabled'] == true,
          selected: data['selected'] is List
              ? (data['selected'] as List)
                  .whereType<String>()
                  .where((id) => id.isNotEmpty)
                  .take(50)
                  .toSet()
              : {});
}

class CalendarPreferenceStore {
  CalendarPreferenceStore(this.owner, [TaskDatabase? database])
      : database = database ?? TaskDatabase();
  final String owner;
  final TaskDatabase database;
  Future<CalendarPreferences> read() async {
    final rows = await (await database.database).query('app_preferences',
        where: 'scope = ?', whereArgs: ['calendars:$owner']);
    if (rows.isEmpty) return const CalendarPreferences();
    try {
      return CalendarPreferences.fromJson(
          Map<String, dynamic>.from(jsonDecode(rows.single['data'] as String)));
    } on FormatException {
      return const CalendarPreferences();
    } on TypeError {
      return const CalendarPreferences();
    }
  }

  Future<void> write(CalendarPreferences preferences) async =>
      (await database.database).insert(
          'app_preferences',
          {
            'scope': 'calendars:$owner',
            'data': jsonEncode(preferences.toJson())
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
}

class DeviceCalendarState {
  const DeviceCalendarState(
      {this.preferences = const CalendarPreferences(),
      this.access = CalendarAccess.checking,
      this.calendars = const [],
      this.truncated = false,
      this.error = false,
      this.revision = 0});
  final CalendarPreferences preferences;
  final CalendarAccess access;
  final List<DeviceCalendar> calendars;
  final bool truncated, error;
  final int revision;
  bool get showing =>
      preferences.enabled &&
      preferences.selected.isNotEmpty &&
      access == CalendarAccess.granted;
}

class DeviceCalendarController extends StateNotifier<DeviceCalendarState> {
  DeviceCalendarController(this.bridge, this.store)
      : super(const DeviceCalendarState()) {
    ready = _initialize();
    _subscription = bridge.changes.listen((_) {
      if (_suspended || !state.preferences.enabled) return;
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () => refresh());
    });
  }
  final DeviceCalendars bridge;
  final CalendarPreferenceStore store;
  late final Future<void> ready;
  late final StreamSubscription<void> _subscription;
  Timer? _debounce;
  int _generation = 0;
  bool _suspended = false;
  Future<void> _writing = Future.value();

  Future<void> _initialize() async {
    try {
      final access = await bridge.status();
      if (!mounted) return;
      if (access == CalendarAccess.unavailable) {
        state = const DeviceCalendarState(access: CalendarAccess.unavailable);
        return;
      }
      final preferences = await store.read();
      if (!mounted) return;
      state = DeviceCalendarState(preferences: preferences, access: access);
      await _refresh();
    } catch (_) {
      if (mounted) {
        state = const DeviceCalendarState(
            access: CalendarAccess.denied, error: true);
      }
    }
  }

  /// Hide event content immediately when leaving the foreground or switching
  /// accounts. A late provider response cannot restore the previous snapshot.
  void suspend() {
    _suspended = true;
    _debounce?.cancel();
    _generation++;
    if (mounted) {
      state = DeviceCalendarState(
          preferences: state.preferences, revision: state.revision + 1);
    }
  }

  Future<void> refresh({bool browse = false}) async {
    await ready;
    _suspended = false;
    if (mounted) await _refresh(browse: browse);
  }

  Future<void> _refresh({bool browse = false}) async {
    if (_suspended || !mounted) return;
    final generation = ++_generation;
    state = DeviceCalendarState(
        preferences: state.preferences, revision: state.revision + 1);
    try {
      final access = await bridge.status();
      if (!mounted || generation != _generation) return;
      final result = access == CalendarAccess.granted &&
              (browse || state.preferences.enabled)
          ? await bridge.calendars()
          : const CalendarRead<DeviceCalendar>([]);
      if (!mounted || generation != _generation) return;
      state = DeviceCalendarState(
          preferences: state.preferences,
          access: access,
          calendars: result.items,
          truncated: result.truncated,
          revision: state.revision + 1);
    } catch (_) {
      if (mounted && generation == _generation) {
        state = DeviceCalendarState(
            preferences: state.preferences,
            access: CalendarAccess.denied,
            error: true,
            revision: state.revision + 1);
      }
    }
  }

  /// A first connection (nothing selected yet) ticks every calendar the phone
  /// lists, up to 50, so Calendar shows their events at once (D7). A selection
  /// the person made before is kept as it is.
  Future<void> enable() async {
    await ready;
    final access = await bridge.status(request: true);
    if (!mounted) return;
    if (access == CalendarAccess.granted) {
      var listed = const <DeviceCalendar>[];
      if (state.preferences.selected.isEmpty) {
        try {
          listed = (await bridge.calendars()).items;
        } catch (_) {
          // The refresh below reports the read error.
        }
        if (!mounted) return;
      }
      await _change((before) => CalendarPreferences(
          enabled: true,
          selected: before.selected.isNotEmpty
              ? before.selected
              : listed.take(50).map((c) => c.selectionKey).toSet()));
    }
    if (mounted) await _refresh(browse: true);
  }

  Future<void> disable() =>
      _change((before) => CalendarPreferences(selected: before.selected));
  Future<void> clearSelection() =>
      _change((before) => CalendarPreferences(enabled: before.enabled));
  Future<void> select(String id, bool selected) => _change((before) {
        final ids = {...before.selected};
        if (selected) {
          if (!state.calendars.any((calendar) => calendar.selectionKey == id)) {
            throw StateError('This calendar is no longer available.');
          }
          ids.add(id);
        } else {
          ids.remove(id);
        }
        if (ids.length > 50) {
          throw const FormatException('Choose up to 50 calendars.');
        }
        return CalendarPreferences(enabled: before.enabled, selected: ids);
      });
  Future<void> _change(
      CalendarPreferences Function(CalendarPreferences) update) {
    final result = _writing.then((_) async {
      await ready;
      if (!mounted) return;
      final next = update(state.preferences);
      await store.write(next);
      if (!mounted) return;
      _generation++;
      state = DeviceCalendarState(
          preferences: next,
          access: state.access,
          calendars: state.calendars,
          truncated: state.truncated,
          revision: state.revision + 1);
      if (state.access == CalendarAccess.checking && !_suspended) {
        await _refresh(browse: next.enabled);
      }
    });
    _writing = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<CalendarRead<DeviceCalendarEvent>> events(DateTime day) async {
    final snapshot = state;
    final generation = _generation;
    if (!snapshot.showing) return const CalendarRead([]);
    final ids = snapshot.calendars
        .where((c) => snapshot.preferences.selected.contains(c.selectionKey))
        .map((c) => c.id)
        .toSet();
    if (ids.isEmpty) return const CalendarRead([]);
    try {
      final result = await bridge.events(ids, day);
      if (!mounted || generation != _generation) return const CalendarRead([]);
      return CalendarRead(
          DeviceCalendarEvent.forDay(
              result.items, snapshot.calendars, ids, day),
          truncated: result.truncated);
    } on PlatformException catch (error) {
      if (error.code != 'calendar_permission') rethrow;
      if (mounted && generation == _generation) await _refresh();
      return const CalendarRead([]);
    }
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _subscription.cancel();
    super.dispose();
  }
}

final deviceCalendarsProvider = Provider<DeviceCalendars>((ref) {
  final bridge = DeviceCalendars();
  ref.onDispose(bridge.close);
  return bridge;
});
final calendarPreferenceStoreProvider = Provider<CalendarPreferenceStore>(
    (ref) =>
        CalendarPreferenceStore(ref.watch(taskRepositoryProvider).ownerKey));
final deviceCalendarProvider =
    StateNotifierProvider<DeviceCalendarController, DeviceCalendarState>(
        (ref) => DeviceCalendarController(ref.watch(deviceCalendarsProvider),
            ref.watch(calendarPreferenceStoreProvider)));
final deviceEventsProvider = FutureProvider.autoDispose
    .family<CalendarRead<DeviceCalendarEvent>, String>((ref, date) {
  ref.watch(deviceCalendarProvider);
  return ref.read(deviceCalendarProvider.notifier).events(DateTime.parse(date));
});
