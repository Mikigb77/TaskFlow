// Emulator-only fixture for observing native delivery with the app process gone
// and across a real reboot. It never edits or deletes another owner's tasks.
import 'dart:convert';
import 'dart:io';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
      home: Scaffold(
          body: Center(child: Text('TaskFlow reminder delivery fixture')))));
  await TaskReminders.initialize();
  final database = TaskDatabase();
  const owner = 'reminder-delivery-fixture';
  final file = File(
      '${(await getApplicationSupportDirectory()).path}/reminder-delivery-fixture.json');
  if (const bool.fromEnvironment('CLEANUP_REMINDERS')) {
    if (!await file.exists()) return;
    final saved = jsonDecode(await file.readAsString()) as Map;
    await ReminderPreferenceStore(database)
        .write(owner, const ReminderPreferences());
    await TaskReminders.engine.reconcile(owner);
    for (final id in saved['tasks'] as List) {
      await database.deleteTask(id as int, ownerKey: owner);
    }
    await TaskReminders.activate(saved['previous_owner'] as String? ?? 'local');
    await file.delete();
    return;
  }
  if (await file.exists()) return;
  final previous = await TaskReminders.engine.activeOwner();
  await TaskReminders.activate(owner);
  await ReminderPreferenceStore(database)
      .write(owner, const ReminderPreferences(enabled: true, leadMinutes: 0));
  final now = DateTime.now();
  final taskIds = <int>[];
  for (final entry
      in {'Closed app receipt': 45, 'After reboot receipt': 150}.entries) {
    taskIds.add(await database.insertTask(
        Task(
            title: 'TaskFlow test · ${entry.key}',
            priority: 1,
            dueDate: now.add(Duration(seconds: entry.value)),
            reminderMinutes: 0),
        ownerKey: owner));
  }
  await TaskReminders.engine.reconcile(owner);
  final alerts = await (await database.database).query('reminder_state',
      where: 'owner_key = ? AND status != ?',
      whereArgs: [owner, 'inactive'],
      orderBy: 'fire_at');
  await file.writeAsString(
      jsonEncode({
        'previous_owner': previous,
        'tasks': taskIds,
        'alerts': alerts
            .map((a) => {
                  'id': a['id'],
                  'token': a['token'],
                  'fire_at': a['fire_at'],
                  'status': a['status'],
                  'title': a['title']
                })
            .toList()
      }),
      flush: true);
}
