import 'dart:async';
import 'dart:convert';
import 'package:agenda/models/device_calendar_event.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/services/calendar_export.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

/// What the person chose on «Phone calendars»: which accounts' events show
/// (each with all of its own calendars), which extra calendars show
/// (holidays, birthdays, calendars only read), and which accounts get the
/// tasks made in TaskFlow.
class CalendarPreferences {
  const CalendarPreferences(
      {this.enabled = false,
      this.accounts = const {},
      this.extras = const {},
      this.exportAccounts = const {}});
  final bool enabled;

  /// [DeviceCalendar.accountKey]s whose events show in Calendar.
  final Set<String> accounts;

  /// [DeviceCalendar.selectionKey]s of extra calendars ticked.
  final Set<String> extras;

  /// [DeviceCalendar.accountKey]s whose main calendar gets every task with a
  /// day. None until the person ticks one.
  final Set<String> exportAccounts;

  static const maxAccounts = 20;
  static const maxExtras = 50;

  bool get chosen => accounts.isNotEmpty || extras.isNotEmpty;
  bool get exporting => exportAccounts.isNotEmpty;
  bool shows(DeviceCalendar calendar) => calendar.isOwn
      ? accounts.contains(calendar.accountKey)
      : extras.contains(calendar.selectionKey);

  CalendarPreferences copyWith(
          {bool? enabled,
          Set<String>? accounts,
          Set<String>? extras,
          Set<String>? exportAccounts}) =>
      CalendarPreferences(
          enabled: enabled ?? this.enabled,
          accounts: accounts ?? this.accounts,
          extras: extras ?? this.extras,
          exportAccounts: exportAccounts ?? this.exportAccounts);

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'accounts': accounts.toList()..sort(),
        'extras': extras.toList()..sort(),
        'exportAccounts': exportAccounts.toList()..sort(),
      };

  static Set<String> _strings(Object? value, int limit) => value is List
      ? value.whereType<String>().where((id) => id.isNotEmpty).take(limit).toSet()
      : {};

  /// A choice saved before accounts (`selected`, one key per calendar) keeps
  /// the accounts it ticked; their holidays and birthdays start off.
  factory CalendarPreferences.fromJson(Map<String, dynamic> data) {
    final accounts = data.containsKey('accounts')
        ? _strings(data['accounts'], maxAccounts)
        : _strings(data['selected'], 200)
            .map(DeviceCalendar.accountKeyOf)
            .whereType<String>()
            .take(maxAccounts)
            .toSet();
    return CalendarPreferences(
        enabled: data['enabled'] == true,
        accounts: accounts,
        extras: _strings(data['extras'], maxExtras),
        exportAccounts: _strings(data['exportAccounts'], maxAccounts));
  }
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
      preferences.chosen &&
      access == CalendarAccess.granted;

  /// The calendars whose events show in Calendar.
  List<DeviceCalendar> get shown =>
      [for (final calendar in calendars) if (preferences.shows(calendar)) calendar];

  /// Calendars TaskFlow can add tasks to: the own ones of each account.
  List<DeviceCalendar> get writable =>
      [for (final calendar in calendars) if (calendar.isOwn) calendar];

  /// The main calendar of [account]: the one the phone calls main, else its
  /// first own calendar. Null when the phone has none for it.
  DeviceCalendar? mainCalendar(String account) {
    final own = [
      for (final c in writable)
        if (c.accountKey == account) c
    ];
    return own.where((c) => c.primary).firstOrNull ?? own.firstOrNull;
  }

  /// Where tasks go: the main calendar of each account ticked under «TaskFlow in
  /// your calendar» that the phone still lists.
  List<DeviceCalendar> get exportCalendars => [
        for (final account in {for (final c in writable) c.accountKey})
          if (preferences.exportAccounts.contains(account))
            ?mainCalendar(account),
      ];
}

class DeviceCalendarController extends StateNotifier<DeviceCalendarState> {
  DeviceCalendarController(this.bridge, this.store, {this.exporter})
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
  final CalendarExporter? exporter;
  late final Future<void> ready;

  /// Events TaskFlow added for tasks: Calendar shows the task, not these.
  Set<String> _added = const {};

  /// Whether TaskFlow still has events of its own on the phone.
  bool get hasAddedEvents => _added.isNotEmpty;
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
      try {
        _added = await exporter?.added() ?? const {};
      } catch (_) {
        // Nothing to hide yet; the next export reads them again.
      }
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
              (browse ||
                  state.preferences.enabled ||
                  state.preferences.exporting)
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

  /// A first connection (nothing chosen yet) ticks every account the phone
  /// lists, so Calendar shows their own calendars at once (D7); holidays,
  /// birthdays and other extras stay off. A choice made before is kept.
  Future<void> enable() async {
    await ready;
    final access = await bridge.status(request: true);
    if (!mounted) return;
    if (access == CalendarAccess.granted) {
      var listed = const <DeviceCalendar>[];
      if (!state.preferences.chosen) {
        try {
          listed = (await bridge.calendars()).items;
        } catch (_) {
          // The refresh below reports the read error.
        }
        if (!mounted) return;
      }
      await _change((before) => before.copyWith(
          enabled: true,
          accounts: before.chosen
              ? before.accounts
              : listed
                  .where((c) => c.isOwn)
                  .map((c) => c.accountKey)
                  .take(CalendarPreferences.maxAccounts)
                  .toSet()));
    }
    if (mounted) await _refresh(browse: true);
  }

  Future<void> disable() => _change((before) => before.copyWith(enabled: false));
  Future<void> clearSelection() =>
      _change((before) => before.copyWith(accounts: {}, extras: {}));

  /// Ticks or unticks an account: all of its own calendars at once.
  Future<void> selectAccount(String account, bool selected) =>
      _change((before) {
        final keys = {...before.accounts};
        if (selected) {
          if (!state.calendars.any((c) => c.isOwn && c.accountKey == account)) {
            throw StateError('This account is no longer available.');
          }
          keys.add(account);
        } else {
          keys.remove(account);
        }
        if (keys.length > CalendarPreferences.maxAccounts) {
          throw const FormatException('Choose up to 20 accounts.');
        }
        return before.copyWith(accounts: keys);
      });

  /// Ticks or unticks one extra calendar: holidays, birthdays and the like.
  Future<void> selectExtra(String id, bool selected) => _change((before) {
        final ids = {...before.extras};
        if (selected) {
          if (!state.calendars.any((c) => !c.isOwn && c.selectionKey == id)) {
            throw StateError('This calendar is no longer available.');
          }
          ids.add(id);
        } else {
          ids.remove(id);
        }
        if (ids.length > CalendarPreferences.maxExtras) {
          throw const FormatException('Choose up to 50 calendars.');
        }
        return before.copyWith(extras: ids);
      });

  /// Ticks or unticks an account under «TaskFlow in your calendar». The first tick
  /// asks the phone for permission to add events; false when it said no.
  Future<bool> selectExportAccount(String account, bool selected) async {
    await ready;
    if (selected) {
      final access = await bridge.writeAccess(request: true);
      if (!mounted || access != CalendarAccess.granted) return false;
    }
    await _change((before) {
      final keys = {...before.exportAccounts};
      if (selected) {
        if (state.mainCalendar(account) == null) {
          throw StateError('This account is no longer available.');
        }
        keys.add(account);
      } else {
        keys.remove(account);
      }
      return before.copyWith(exportAccounts: keys);
    });
    return true;
  }

  Future<void> _exporting = Future.value();

  /// Adds [tasks] with a day to the main calendar of each account ticked
  /// under «TaskFlow in your calendar», and keeps their events in step; an account
  /// unticked loses the events TaskFlow added there from today on. Nothing
  /// happens without access, or before the phone has listed its calendars.
  Future<void> exportTasks(List<Task> tasks, {int? accountId, DateTime? now}) {
    final run = _exporting.then((_) async {
      await ready;
      final exporter = this.exporter;
      final snapshot = state;
      final targets = snapshot.exportCalendars;
      if (!mounted ||
          exporter == null ||
          _suspended ||
          snapshot.access != CalendarAccess.granted ||
          // Ticked accounts the phone hasn't listed yet aren't unticked.
          (snapshot.preferences.exporting && targets.isEmpty) ||
          (!snapshot.preferences.exporting && _added.isEmpty)) {
        return;
      }
      if (await bridge.writeAccess() != CalendarAccess.granted) return;
      final added = await exporter.sync(tasks, targets,
          now: now ?? DateTime.now(), accountId: accountId);
      if (!mounted) return;
      if (added.length != _added.length || !added.containsAll(_added)) {
        _added = added;
        state = DeviceCalendarState(
            preferences: state.preferences,
            access: state.access,
            calendars: state.calendars,
            truncated: state.truncated,
            error: state.error,
            revision: state.revision + 1);
      }
    });
    _exporting = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }

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
    final shown = snapshot.shown;
    // The phone answers for up to 50 calendars at once.
    final ids = shown.take(50).map((c) => c.id).toSet();
    if (ids.isEmpty) return const CalendarRead([]);
    final added = _added;
    try {
      final result = await bridge.events(ids, day);
      if (!mounted || generation != _generation) return const CalendarRead([]);
      return CalendarRead(
          DeviceCalendarEvent.forDay(
              [for (final e in result.items) if (!added.contains(e.id)) e],
              snapshot.calendars,
              ids,
              day),
          truncated: result.truncated || shown.length > ids.length);
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
final calendarExportStoreProvider = Provider<CalendarExportStore>((ref) =>
    CalendarExportStore(ref.watch(taskRepositoryProvider).ownerKey));
final deviceCalendarProvider =
    StateNotifierProvider<DeviceCalendarController, DeviceCalendarState>(
        (ref) {
  final bridge = ref.watch(deviceCalendarsProvider);
  return DeviceCalendarController(
      bridge, ref.watch(calendarPreferenceStoreProvider),
      exporter: CalendarExporter(bridge, ref.watch(calendarExportStoreProvider)));
});

/// Adds tasks to the phone's calendars ticked under «TaskFlow in your calendar»: after
/// each change to the tasks, and when the ticked accounts change. Listened
/// to by the app's shell.
final calendarExportProvider = Provider<void>((ref) {
  Timer? timer;
  void schedule() {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 800), () {
      final tasks = ref.read(taskProvider).value;
      if (tasks == null) return;
      unawaited(ref
          .read(deviceCalendarProvider.notifier)
          .exportTasks(tasks, accountId: ref.read(authProvider).account?.id)
          .catchError((Object _) {}));
    });
  }

  ref.onDispose(() => timer?.cancel());
  ref.listen(
      deviceCalendarProvider.select((state) => (
            state.access,
            state.exportCalendars.map((c) => c.selectionKey).join(' '),
          )), (previous, next) {
    // Something ticked, just unticked, or events left to remove.
    if (next.$1 == CalendarAccess.granted &&
        (next.$2.isNotEmpty ||
            (previous?.$2.isNotEmpty ?? false) ||
            ref.read(deviceCalendarProvider.notifier).hasAddedEvents)) {
      schedule();
    }
  }, fireImmediately: true);
  ref.listen(taskProvider, (_, next) {
    if (next.hasValue &&
        ref.read(deviceCalendarProvider).preferences.exporting) {
      schedule();
    }
  });
});
final deviceEventsProvider = FutureProvider.autoDispose
    .family<CalendarRead<DeviceCalendarEvent>, String>((ref, date) {
  ref.watch(deviceCalendarProvider);
  return ref.read(deviceCalendarProvider.notifier).events(DateTime.parse(date));
});
