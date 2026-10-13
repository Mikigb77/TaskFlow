import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:agenda/services/task_database.dart';
import 'package:agenda/l10n/app_languages.dart';

enum ClockFormat { system, twelve, twentyFour }

class RegionalPreferences {
  const RegionalPreferences({
    this.language = 'system',
    this.clock = ClockFormat.system,
    this.weekStart,
    this.captureTimezone,
  });
  final String language;
  final ClockFormat clock;

  /// Sunday = 0, matching MaterialLocalizations, not DateTime.weekday.
  final int? weekStart;
  final String? captureTimezone;
  Map<String, dynamic> toJson() => {
        'language': language,
        'clock': clock.name,
        'weekStart': weekStart,
        'captureTimezone': captureTimezone,
      };
  factory RegionalPreferences.fromJson(Map<String, dynamic> json) =>
      RegionalPreferences(
        language: json['language'] == AppLanguages.system ||
                (json['language'] is String &&
                    AppLanguages.supports(json['language'] as String))
            ? json['language'] as String
            : 'system',
        clock: ClockFormat.values
                .where((v) => v.name == json['clock'])
                .firstOrNull ??
            ClockFormat.system,
        weekStart: [0, 1, 6].contains(json['weekStart'])
            ? json['weekStart'] as int
            : null,
        captureTimezone: CaptureTimezone.valid(json['captureTimezone'])
            ? json['captureTimezone'] as String
            : null,
      );
  RegionalPreferences withLanguage(String value) => RegionalPreferences(
        language: value,
        clock: clock,
        weekStart: weekStart,
        captureTimezone: captureTimezone,
      );
  RegionalPreferences withClock(ClockFormat value) => RegionalPreferences(
        language: language,
        clock: value,
        weekStart: weekStart,
        captureTimezone: captureTimezone,
      );
  RegionalPreferences withWeekStart(int? value) => RegionalPreferences(
        language: language,
        clock: clock,
        weekStart: value,
        captureTimezone: captureTimezone,
      );
  RegionalPreferences withTimezone(String? value) => RegionalPreferences(
        language: language,
        clock: clock,
        weekStart: weekStart,
        captureTimezone: value,
      );
  Locale localeFor(List<Locale>? devices) =>
      AppLanguages.resolve(language, devices);
}

class RegionalPreferenceStore {
  RegionalPreferenceStore([TaskDatabase? database])
      : database = database ?? TaskDatabase();
  final TaskDatabase database;
  Future<RegionalPreferences> read() async {
    final rows = await (await database.database).query(
      'app_preferences',
      where: 'scope = ?',
      whereArgs: ['regional'],
    );
    return rows.isEmpty
        ? const RegionalPreferences()
        : RegionalPreferences.fromJson(
            jsonDecode(rows.single['data'] as String) as Map<String, dynamic>,
          );
  }

  Future<void> write(RegionalPreferences value) async {
    await (await database.database).insert(
        'app_preferences',
        {
          'scope': 'regional',
          'data': jsonEncode(value.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

final regionalStoreProvider = Provider((ref) => RegionalPreferenceStore());
final regionalProvider =
    StateNotifierProvider<RegionalController, RegionalPreferences>(
  (ref) => RegionalController(ref.read(regionalStoreProvider)),
);

class RegionalController extends StateNotifier<RegionalPreferences> {
  RegionalController(this.store) : super(const RegionalPreferences()) {
    ready = _restore();
    _writes = ready;
  }
  final RegionalPreferenceStore store;
  late final Future<void> ready;
  Future<void> _writes = Future.value();
  bool _chosen = false;
  RegionalPreferences _persisted = const RegionalPreferences();
  Future<void> _restore() async {
    try {
      final saved = await store.read();
      _persisted = saved;
      if (mounted && !_chosen) state = saved;
    } catch (_) {
      /* Device defaults remain usable if preference storage fails. */
    }
  }

  Future<void> set(RegionalPreferences value) {
    _chosen = true;
    state = value;
    return _writes = _writes.catchError((Object _) {}).then((_) async {
      try {
        await store.write(value);
        _persisted = value;
      } catch (_) {
        if (mounted && identical(state, value)) state = _persisted;
        rethrow;
      }
    });
  }
}

class CaptureTimezone {
  const CaptureTimezone(this.identifier, {this.fallback = false});
  final String identifier;
  final bool fallback;
  static bool _initialized = false;
  static void initialize() {
    if (_initialized) return;
    // Another service may already have initialized the database and selected
    // tz.local for reminders. Reinitializing would silently reset it to UTC.
    if (tz.timeZoneDatabase.locations.isEmpty) tzdata.initializeTimeZones();
    _initialized = true;
  }

  static bool valid(Object? value) {
    if (value is! String || value.isEmpty) return false;
    initialize();
    return tz.timeZoneDatabase.locations.containsKey(value);
  }

  static List<String> get identifiers {
    initialize();
    return tz.timeZoneDatabase.locations.keys.toList()..sort();
  }

  static Future<CaptureTimezone> resolve(
    RegionalPreferences preferences, {
    String? accountTimezone,
    Future<String> Function()? readDevice,
  }) async {
    if (valid(preferences.captureTimezone)) {
      return CaptureTimezone(preferences.captureTimezone!);
    }
    try {
      final device = await (readDevice?.call() ??
              FlutterTimezone.getLocalTimezone().then((v) => v.identifier))
          .timeout(const Duration(seconds: 5));
      if (valid(device)) return CaptureTimezone(device);
    } catch (_) {
      /* An explicit fallback is shown in the capture/settings UI. */
    }
    return CaptureTimezone(
      valid(accountTimezone) ? accountTimezone! : 'UTC',
      fallback: true,
    );
  }
}
