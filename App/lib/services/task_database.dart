import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:agenda/models/task.dart';

class TaskDatabase {
  static final TaskDatabase _instance = TaskDatabase._internal();
  Database? _database;
  factory TaskDatabase() => _instance;
  TaskDatabase._internal();
  TaskDatabase.forTesting(Database database) : _database = database;

  Future<Database> get database async {
    return _database ??= await openDatabase(
      join(await getDatabasesPath(), 'task_database.db'),
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE tasks(
          id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT,
          priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT,
          imagePaths TEXT, hasTime INTEGER NOT NULL DEFAULT 1,
          recurrence TEXT NOT NULL DEFAULT 'none', repeatUntil TEXT,
          completedDates TEXT NOT NULL DEFAULT '[]',
          owner_key TEXT NOT NULL DEFAULT 'local', sync_id TEXT,
          remote_version INTEGER NOT NULL DEFAULT 0, revision INTEGER NOT NULL DEFAULT 0,
          sync_pending INTEGER NOT NULL DEFAULT 0, is_deleted INTEGER NOT NULL DEFAULT 0
        )''');
        await db.execute(
            'CREATE UNIQUE INDEX task_sync_owner ON tasks(owner_key, sync_id)');
      },
      onUpgrade: upgrade,
    );
  }

  static Future<void> upgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN notes TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tasks ADD COLUMN filePaths TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN imagePaths TEXT');
    }
    if (oldVersion < 4) {
      await db.execute(
          "ALTER TABLE tasks ADD COLUMN owner_key TEXT NOT NULL DEFAULT 'local'");
      await db.execute('ALTER TABLE tasks ADD COLUMN sync_id TEXT');
      await db.execute(
          'ALTER TABLE tasks ADD COLUMN remote_version INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE tasks ADD COLUMN revision INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE tasks ADD COLUMN sync_pending INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE tasks ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'CREATE UNIQUE INDEX task_sync_owner ON tasks(owner_key, sync_id)');
    }
    if (oldVersion < 5 && newVersion >= 5) {
      await db.execute(
          'ALTER TABLE tasks ADD COLUMN hasTime INTEGER NOT NULL DEFAULT 1');
      await db.execute(
          "ALTER TABLE tasks ADD COLUMN recurrence TEXT NOT NULL DEFAULT 'none'");
      await db.execute('ALTER TABLE tasks ADD COLUMN repeatUntil TEXT');
      await db.execute(
          "ALTER TABLE tasks ADD COLUMN completedDates TEXT NOT NULL DEFAULT '[]'");
    }
  }

  Future<int> insertTask(Task task, {String ownerKey = 'local'}) async {
    final values = task.toMap()..remove('id');
    return (await database).insert('tasks', {
      ...values,
      'owner_key': ownerKey,
      'sync_id': const Uuid().v4(),
      'sync_pending': ownerKey == 'local' ? 0 : 1
    });
  }

  Future<List<Task>> getTasks({String ownerKey = 'local'}) async {
    final rows = await (await database).query('tasks',
        where: 'owner_key = ? AND is_deleted = 0', whereArgs: [ownerKey]);
    return rows.map(Task.fromMap).toList();
  }

  Future<void> insertTasks(List<Task> tasks,
      {String ownerKey = 'local'}) async {
    await (await database).transaction((tx) async {
      for (final task in tasks) {
        final values = task.toMap()..remove('id');
        await tx.insert('tasks', {
          ...values,
          'owner_key': ownerKey,
          'sync_id': const Uuid().v4(),
          'sync_pending': ownerKey == 'local' ? 0 : 1
        });
      }
    });
  }

  Future<int> updateTask(Task task, {String ownerKey = 'local'}) async {
    final db = await database;
    return db.transaction((tx) async {
      final values = task.toMap()..remove('id');
      final count = await tx.update(
          'tasks', {...values, 'sync_pending': ownerKey == 'local' ? 0 : 1},
          where: 'id = ? AND owner_key = ? AND is_deleted = 0',
          whereArgs: [task.id, ownerKey]);
      if (count == 0) {
        throw StateError('This task is no longer in the current account.');
      }
      await tx.rawUpdate(
          'UPDATE tasks SET revision = revision + 1 WHERE id = ? AND owner_key = ?',
          [task.id, ownerKey]);
      return count;
    });
  }

  Future<int> deleteTask(int id, {String ownerKey = 'local'}) async {
    final db = await database;
    if (ownerKey == 'local') {
      return db.delete('tasks',
          where: 'id = ? AND owner_key = ?', whereArgs: [id, ownerKey]);
    }
    return db.rawUpdate(
        'UPDATE tasks SET is_deleted = 1, sync_pending = 1, revision = revision + 1 WHERE id = ? AND owner_key = ?',
        [id, ownerKey]);
  }

  Future<List<Map<String, dynamic>>> pending(String ownerKey) async =>
      (await database).query('tasks',
          where: 'owner_key = ? AND sync_pending = 1', whereArgs: [ownerKey]);

  Future<void> acknowledge(String ownerKey, Map<String, dynamic> sent,
      Map<String, dynamic> remote) async {
    // A user may edit while an upload is in flight. Never clear that newer edit.
    await (await database).rawUpdate('''UPDATE tasks SET remote_version = ?,
      sync_pending = CASE WHEN revision = ? THEN 0 ELSE 1 END
      WHERE id = ? AND owner_key = ?''',
        [remote['version'], sent['revision'], sent['id'], ownerKey]);
  }

  Map<String, dynamic> _remoteValues(Map<String, dynamic> remote) => {
        ...(Task.fromApi(remote).toMap()
          ..remove('id')
          ..remove('filePaths')
          ..remove('imagePaths')),
        'is_deleted': remote['is_deleted'] == true ? 1 : 0,
        'remote_version': remote['version'],
        'sync_pending': 0,
      };

  Future<void> mergeRemote(String ownerKey, Map<String, dynamic> remote) async {
    final db = await database;
    await db.transaction((tx) async {
      final rows = await tx.query('tasks',
          where: 'owner_key = ? AND sync_id = ?',
          whereArgs: [ownerKey, remote['id']]);
      if (rows.isEmpty) {
        await tx.insert('tasks', {
          ..._remoteValues(remote),
          'owner_key': ownerKey,
          'sync_id': remote['id']
        });
      } else if (rows.single['sync_pending'] == 0 &&
          (rows.single['remote_version'] as int) <=
              (remote['version'] as int)) {
        // Attachment paths stay on this device and are never copied from the server.
        await tx.update('tasks', _remoteValues(remote),
            where: 'id = ? AND owner_key = ?',
            whereArgs: [rows.single['id'], ownerKey]);
      }
    });
  }

  Future<void> preserveConflict(String ownerKey, Map<String, dynamic> sent,
      Map<String, dynamic> remote) async {
    final db = await database;
    await db.transaction((tx) async {
      final rows = await tx.query('tasks',
          where: 'id = ? AND owner_key = ?', whereArgs: [sent['id'], ownerKey]);
      if (rows.isEmpty) return;
      final local = Map<String, dynamic>.from(rows.single);
      // Keep offline edits as a visible copy instead of overwriting another device.
      if (local['is_deleted'] == 0) {
        final title = '${local['title']} (offline copy)';
        local.remove('id');
        await tx.insert('tasks', {
          ...local,
          'title': title.length > 160 ? title.substring(0, 160) : title,
          'sync_id': const Uuid().v4(),
          'remote_version': 0,
          'revision': 0,
          'sync_pending': 1
        });
      }
      await tx.update('tasks', _remoteValues(remote),
          where: 'id = ? AND owner_key = ?', whereArgs: [sent['id'], ownerKey]);
    });
  }

  Future<int> importLocalTasks(String ownerKey) async {
    final db = await database;
    return db.transaction((tx) async {
      final rows = await tx.query('tasks',
          where: "owner_key = 'local' AND is_deleted = 0");
      for (final row in rows) {
        await tx.update(
            'tasks',
            {
              'owner_key': ownerKey,
              'sync_id': row['sync_id'] ?? const Uuid().v4(),
              'sync_pending': 1
            },
            where: "id = ? AND owner_key = 'local'",
            whereArgs: [row['id']]);
      }
      return rows.length;
    });
  }

  Future<List<Task>> getTasksOverdueByFourMonths() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 120));
    return (await getTasks())
        .where((task) =>
            !task.isRecurring && (task.dueDate?.isBefore(cutoff) ?? false))
        .toList();
  }

  Future<void> deleteTasks(List<int> ids) async {
    for (final id in ids) {
      await deleteTask(id);
    }
  }

  Future<List<Task>> getTasksForNextThreeDays() async {
    final now = DateTime.now();
    return (await getTasks())
        .where((task) =>
            !task.isCompleted &&
            (task.dueDate?.isAfter(now) ?? false) &&
            task.dueDate!.isBefore(now.add(const Duration(days: 3))))
        .toList();
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
