import 'dart:convert';
import 'dart:io';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/task_database.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Persisted before any fixture mutation, so cleanup can run after process death.
class ReminderLanguageRecovery {
  ReminderLanguageRecovery._(this.file, this.data);
  final File file;
  final Map<String, dynamic> data;
  String get owner => data['owner'] as String;

  static Future<File> _file() async => File(p.join(
      (await getApplicationSupportDirectory()).path,
      'reminder-language-recovery.json'));

  static Future<void> recoverPending() async {
    final file = await _file();
    if (!await file.exists()) return;
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    await ReminderLanguageRecovery._(file, data).restore();
  }

  static Future<ReminderLanguageRecovery> begin(String owner) async {
    final file = await _file();
    if (await file.exists()) {
      throw StateError('Recover the previous fixture first.');
    }
    final sql = await TaskDatabase().database;
    final data = <String, dynamic>{
      'version': 1,
      'owner': owner,
      'previousOwner': await TaskReminders.engine.activeOwner(),
      'region': await sql.query('app_preferences',
          where: 'scope = ?', whereArgs: ['regional']),
      'tasksHash': await _tasksHash(sql, owner),
    };
    final recovery = ReminderLanguageRecovery._(file, data).._validate();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(data), flush: true);
    await temporary.rename(file.path);
    return recovery;
  }

  void _validate() {
    if (data['version'] != 1 ||
        !RegExp(r'^reminder-language-\d+$').hasMatch(owner) ||
        data['region'] is! List ||
        (data['region'] as List).length > 1 ||
        (data['region'] as List).any((row) => row['scope'] != 'regional') ||
        (data['previousOwner'] != null && data['previousOwner'] is! String)) {
      throw StateError('Invalid reminder-language recovery record.');
    }
  }

  static Future<String> _tasksHash(Database sql, String owner) async => sha256
      .convert(utf8.encode(jsonEncode(await sql.query('tasks',
          where: 'owner_key != ?', whereArgs: [owner], orderBy: 'id'))))
      .toString();

  Future<void> restore() async {
    _validate();
    final sql = await TaskDatabase().database;
    // Native action callbacks finish reconciliation after saving their result.
    // Avoid racing test cleanup with that last transaction.
    final wait = Stopwatch()..start();
    while (true) {
      final lease = await sql
          .query('reminder_meta', where: 'key = ?', whereArgs: ['lease']);
      if (lease.isEmpty ||
          !DateTime.parse(jsonDecode(lease.single['value'] as String)['until'])
              .isAfter(DateTime.now().toUtc())) {
        break;
      }
      if (wait.elapsed > const Duration(seconds: 15)) {
        throw StateError(
            'Reminder worker still active; recovery record retained.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final tasks =
        await sql.query('tasks', where: 'owner_key = ?', whereArgs: [owner]);
    if (tasks.any((row) => !const [
          'TaskFlow idioma · completar',
          'TaskFlow idioma · posponer'
        ].contains(row['title']))) {
      throw StateError(
          'Unexpected data in the reminder-language fixture scope.');
    }
    final reminders = await sql
        .query('reminder_state', where: 'owner_key = ?', whereArgs: [owner]);
    for (final row in reminders) {
      await TaskReminders.plugin.cancel(row['id'] as int);
    }
    await sql.transaction((tx) async {
      for (final table in ['reminder_snoozes', 'reminder_state', 'tasks']) {
        await tx.delete(table, where: 'owner_key = ?', whereArgs: [owner]);
      }
      await tx.delete('app_preferences',
          where: 'scope = ?', whereArgs: ['reminders:$owner']);
      final currentOwner = await tx
          .query('reminder_meta', where: 'key = ?', whereArgs: ['owner']);
      final value = currentOwner.firstOrNull?['value'];
      // A user switching accounts after a crash takes precedence over cleanup.
      if (value == owner || value == data['previousOwner']) {
        final currentRegion = await tx.query('app_preferences',
            where: 'scope = ?', whereArgs: ['regional']);
        final region = currentRegion.isEmpty
            ? null
            : jsonDecode(currentRegion.single['data'] as String) as Map;
        // Restore only the exact defaults the fixture writes. Keep later edits.
        if (region != null &&
            ['en', 'es'].contains(region['language']) &&
            region['clock'] == 'system' &&
            region['weekStart'] == null &&
            region['captureTimezone'] == null) {
          await tx.delete('app_preferences',
              where: 'scope = ?', whereArgs: ['regional']);
          for (final row in data['region'] as List) {
            await tx.insert('app_preferences', Map<String, Object?>.from(row));
          }
        }
        if (value == owner) {
          await tx
              .delete('reminder_meta', where: 'key = ?', whereArgs: ['owner']);
          if (data['previousOwner'] != null) {
            await tx.insert('reminder_meta',
                {'key': 'owner', 'value': data['previousOwner']});
          }
        }
      }
    });
    await TaskReminders.refreshLanguage();
    final unchanged = await _tasksHash(sql, owner) == data['tasksHash'];
    // Cleanup is committed. Do not later overwrite new preferences if a check fails.
    await file.delete();
    if (!unchanged) {
      throw StateError('Non-fixture tasks changed during the run.');
    }
  }
}
