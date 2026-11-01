import 'package:agenda/models/task.dart';
import 'package:agenda/services/reminder_engine.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/task_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The real reminder engine on an in-memory database, with a stand-in for
/// the phone's alarms: what the phone keeps for a task after its reminder
/// rings, or after «Posponer 10 min». A widget test feeds [of]'s rows to
/// `FakeReminderAccess.kept`, so the line it shows is read from what the
/// engine really stored, not a hand-made row. Run it outside the widget
/// test's fake clock: in `setUpAll`, or inside `tester.runAsync`.
class PhoneAlerts {
  PhoneAlerts._(this.database, this.engine, this._at);
  final TaskDatabase database;
  final ReminderEngine engine;
  final _Clock _at;

  /// The phone's clock.
  DateTime get now => _at.now;
  set now(DateTime value) => _at.now = value;

  static Future<PhoneAlerts> open(
    DateTime at, {
    ReminderPreferences preferences = const ReminderPreferences(
      enabled: true,
      dateOnlyTime: 540,
    ),
  }) async {
    sqfliteFfiInit();
    final sql = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await sql.execute(
      'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
    );
    await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
    final database = TaskDatabase.forTesting(sql);
    final clock = _Clock(at);
    final engine = ReminderEngine(database, _Alarms(), clock: () => clock.now);
    await engine.activate('local');
    await ReminderPreferenceStore(database).write('local', preferences);
    return PhoneAlerts._(database, engine, clock);
  }

  /// Saves [task] and plans the phone's reminders again; its id.
  Future<int> add(Task task) async {
    final id = await database.insertTask(task);
    await refresh();
    return id;
  }

  /// Plans the phone's reminders again, as the app does when it opens.
  Future<void> refresh() => engine.reconcile('local');

  /// «Posponer 10 min» on task [taskId]'s notice, at [now].
  Future<void> snooze(int taskId) async {
    final rows = await (await database.database).query(
      'reminder_state',
      where: 'task_id = ? AND status != ?',
      whereArgs: [taskId, 'inactive'],
      orderBy: 'fire_at DESC',
    );
    final done = await engine.action(rows.first['id'] as int, 'snooze');
    if (!done) throw StateError('The snooze was refused');
  }

  /// What the phone keeps for task [taskId] (`ReminderEngine.alertsOf`).
  Future<List<Map<String, Object?>>> of(int taskId) async => [
    for (final row in await engine.alertsOf(taskId)) {...row},
  ];

  Future<void> close() => database.close();
}

class _Clock {
  _Clock(this.now);
  DateTime now;
}

/// The phone's alarms: allowed, exact, and kept in memory.
class _Alarms implements ReminderDriver {
  final Map<int, PlannedReminder> pending = {};
  @override
  Future<ReminderCapability> capability() async =>
      const ReminderCapability(allowed: true, exact: true);
  @override
  Future<Set<int>> pendingIds() async => pending.keys.toSet();
  @override
  Future<void> cancel(int id) async {
    pending.remove(id);
  }

  @override
  Future<void> schedule(
    int id,
    PlannedReminder reminder, {
    required bool exact,
    required String token,
  }) async {
    pending[id] = reminder;
  }

  @override
  Future<void> show(
    int id,
    PlannedReminder reminder, {
    required String token,
  }) async {}

  @override
  Future<void> showUndo(
    int id,
    String text, {
    required String languageCode,
    required String token,
  }) async {}
}
