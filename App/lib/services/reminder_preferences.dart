import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:agenda/services/task_database.dart';

class ReminderPreferences {
  final bool enabled;
  final int leadMinutes;
  final int? dateOnlyTime;
  final int? morning;
  final int? evening;
  const ReminderPreferences(
      {this.enabled = false,
      this.leadMinutes = 10,
      this.dateOnlyTime,
      this.morning,
      this.evening});

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'lead': leadMinutes,
        'date_only': dateOnlyTime,
        'morning': morning,
        'evening': evening
      };
  factory ReminderPreferences.fromJson(Map<String, dynamic> json) =>
      ReminderPreferences(
          enabled: json['enabled'] == true,
          leadMinutes: (json['lead'] as int? ?? 10).clamp(-1, 10080),
          dateOnlyTime: _minute(json['date_only']),
          morning: _minute(json['morning']),
          evening: _minute(json['evening']));
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
}

String reminderLeadLabel(int? minutes) => switch (minutes) {
      null => 'Use default',
      -1 => 'Off',
      0 => 'At the scheduled time',
      60 => '1 hour before',
      1440 => '1 day before',
      _ => '$minutes minutes before',
    };
