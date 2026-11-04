import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:agenda/services/task_database.dart';

class ReminderPreferences {
  final bool enabled;
  final int leadMinutes;
  final int? dateOnlyTime;
  final int? morning;
  final int? evening;

  /// Whether this account on this phone has been asked the one-time
  /// ‘Want a reminder before it?’ question, whatever the answer.
  final bool asked;
  const ReminderPreferences(
      {this.enabled = false,
      this.leadMinutes = 10,
      this.dateOnlyTime,
      this.morning,
      this.evening,
      this.asked = false});

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'lead': leadMinutes,
        'date_only': dateOnlyTime,
        'morning': morning,
        'evening': evening,
        'asked': asked
      };
  factory ReminderPreferences.fromJson(Map<String, dynamic> json) =>
      ReminderPreferences(
          enabled: json['enabled'] == true,
          leadMinutes: (json['lead'] as int? ?? 10).clamp(-1, 10080),
          dateOnlyTime: _minute(json['date_only']),
          morning: _minute(json['morning']),
          evening: _minute(json['evening']),
          asked: json['asked'] == true);
  static int? _minute(Object? value) =>
      value is int && value >= 0 && value < 1440 ? value : null;
}

class ReminderPreferenceStore {
  final TaskDatabase database;
  ReminderPreferenceStore(this.database);
  Future<List<Map<String, Object?>>> upcomingAlerts(String owner) async =>
      (await database.database).query('reminder_state',
          where: 'owner_key = ? AND status NOT IN (?, ?)',
          whereArgs: [owner, 'inactive', 'elapsed'],
          orderBy: 'fire_at');
  Future<List<Map<String, Object?>>> schedulingInfo() async =>
      (await database.database).query('reminder_meta');
  Future<ReminderPreferences> read(String owner) async {
    final rows = await (await database.database).query('app_preferences',
        where: 'scope = ?', whereArgs: ['reminders:$owner']);
    return rows.isEmpty
        ? const ReminderPreferences()
        : ReminderPreferences.fromJson(
            jsonDecode(rows.single['data'] as String));
  }

  Future<void> write(String owner, ReminderPreferences value) async =>
      (await database.database).insert('app_preferences',
          {'scope': 'reminders:$owner', 'data': jsonEncode(value.toJson())},
          conflictAlgorithm: ConflictAlgorithm.replace);

  /// The tasks the reminder question has offered a plan for, on this phone:
  /// it's asked at most once per task.
  Future<Set<int>> planOffers(String owner) async {
    final rows = await (await database.database).query('app_preferences',
        where: 'scope = ?', whereArgs: ['plan-offers:$owner']);
    if (rows.isEmpty) return {};
    final data = jsonDecode(rows.single['data'] as String);
    return data is List ? {...data.whereType<int>()} : {};
  }

  /// Remembers that [taskId] was offered a plan. The newest 500 are kept.
  Future<void> addPlanOffer(String owner, int taskId) async {
    final offered = [...await planOffers(owner), taskId];
    final kept = offered.length > 500
        ? offered.sublist(offered.length - 500)
        : offered;
    await (await database.database).insert('app_preferences',
        {'scope': 'plan-offers:$owner', 'data': jsonEncode(kept)},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// How many times in a row this account answered «Ahora no» to the plan
  /// offer on this phone: at two it's no longer asked. 0 when unknown.
  Future<int> planOfferDeclines(String owner) async {
    final rows = await (await database.database).query('app_preferences',
        where: 'scope = ?', whereArgs: ['plan-offer-declines:$owner']);
    if (rows.isEmpty) return 0;
    final data = jsonDecode(rows.single['data'] as String);
    return data is int && data > 0 ? data : 0;
  }

  /// Whether a meeting recording asked, on this phone, for TaskFlow's
  /// notifications (D3 of 2026-11-04), whatever the answer: it asks once.
  Future<bool> meetingNotificationsAsked() async {
    final rows = await (await database.database).query('app_preferences',
        where: 'scope = ?', whereArgs: [_meetingAsked]);
    return rows.isNotEmpty;
  }

  Future<void> setMeetingNotificationsAsked() async =>
      (await database.database).insert('app_preferences',
          {'scope': _meetingAsked, 'data': jsonEncode(true)},
          conflictAlgorithm: ConflictAlgorithm.replace);

  static const _meetingAsked = 'meeting-notifications-asked';

  /// Sets how many «Ahora no» in a row: one more after «Ahora no», 0 after
  /// «Sí, recuérdamelo».
  Future<void> setPlanOfferDeclines(String owner, int count) async =>
      (await database.database).insert('app_preferences',
          {'scope': 'plan-offer-declines:$owner', 'data': jsonEncode(count)},
          conflictAlgorithm: ConflictAlgorithm.replace);
}

String reminderLeadLabel(int? minutes) => switch (minutes) {
      null => 'Use default',
      -1 => 'Off',
      0 => 'At the scheduled time',
      60 => '1 hour before',
      1440 => '1 day before',
      _ => '$minutes minutes before',
    };
