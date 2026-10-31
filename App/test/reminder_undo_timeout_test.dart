import 'dart:io';
import 'package:agenda/services/notification_service.dart' show TaskReminders;
import 'package:agenda/services/task_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// UX-631 / P117: `Completada: …` and its Deshacer stay for the longer of
/// 10 seconds and the accessibility timeout the app saved while it was open.
/// Notification actions run in a background isolate, so `showUndo` reads the
/// saved value from `reminder_meta` through `TaskReminders.undoTimeout()`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;

  setUpAll(() async {
    // The app's own database, on disk in a temporary folder.
    directory = await Directory.systemTemp.createTemp('taskflow-undo-');
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
  });

  tearDownAll(() async {
    await TaskDatabase().close();
    try {
      await directory.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> saved(String? milliseconds) async {
    final db = await TaskDatabase().database;
    await db.delete('reminder_meta',
        where: 'key = ?', whereArgs: ['undo_timeout_ms']);
    if (milliseconds != null) {
      await db.insert('reminder_meta',
          {'key': 'undo_timeout_ms', 'value': milliseconds});
    }
  }

  test('UX-631: with nothing saved, Undo stays 10 s', () async {
    await saved(null);
    expect(await TaskReminders.undoTimeout(), const Duration(seconds: 10));
  });

  test('UX-631: a saved 4000 ms never shortens Undo below 10 s', () async {
    await saved('4000');
    expect(await TaskReminders.undoTimeout(), const Duration(seconds: 10));
  });

  test('UX-631: a saved 30000 ms keeps Undo for 30 s', () async {
    await saved('30000');
    expect(await TaskReminders.undoTimeout(), const Duration(seconds: 30));
  });

  for (final value in ['', 'not a number', '-5', '0']) {
    test('UX-631: an unreadable saved value "$value" falls back to 10 s',
        () async {
      await saved(value);
      expect(await TaskReminders.undoTimeout(), const Duration(seconds: 10));
    });
  }
}
