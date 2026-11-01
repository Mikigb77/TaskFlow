import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'dart:ui' show Locale;
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/reminder_plan.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/android_database_factory.dart';
import 'package:agenda/services/reminder_copy.dart';

/// Why this phone gives no reminder for a task ([TaskDatabase.reminderBlock]).
enum ReminderBlock { archived, muted, notForAccount }

class TaskDatabase {
  static const schemaVersion = 20;
  static final TaskDatabase _instance = TaskDatabase._internal();
  Database? _database;
  Future<Database>? _opening;
  factory TaskDatabase() => _instance;
  TaskDatabase._internal();
  TaskDatabase.forTesting(Database database) : _database = database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    return _opening ??= _open()
        .then((db) {
          _database = db;
          return db;
        })
        .whenComplete(() {
          _opening = null;
        });
  }

  Future<Database> _open() async {
    final factory = Platform.isAndroid
        ? AndroidDatabaseFactory()
        : databaseFactory;
    return factory.openDatabase(
      join(await getDatabasesPath(), 'task_database.db'),
      // Each background engine owns its connection; transactions must never
      // share an Android connection with a different Dart isolate.
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: schemaVersion,
        onConfigure: (db) async {
          // Android's worker is shared by foreground/background connections.
          // Return a contended write to Dart so the lock owner can commit;
          // AndroidDatabaseFactory yields and retries the rejected statement.
          await db.rawQuery(
            'PRAGMA busy_timeout = ${Platform.isAndroid ? 0 : 5000}',
          );
        },
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE tasks(
          id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT,
          kind TEXT NOT NULL DEFAULT 'task',
          priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT,
          imagePaths TEXT, hasTime INTEGER NOT NULL DEFAULT 1,
          recurrence TEXT NOT NULL DEFAULT 'none', repeatUntil TEXT,
          completedDates TEXT NOT NULL DEFAULT '[]',
          reminderMinutes INTEGER, reminderTime INTEGER, reminderPlan TEXT,
          deadline TEXT, deadlineHasTime INTEGER NOT NULL DEFAULT 0,
          durationMinutes INTEGER, reminderAnchor TEXT NOT NULL DEFAULT 'planned',
          checklist TEXT NOT NULL DEFAULT '[]',
          listId TEXT, labels TEXT NOT NULL DEFAULT '[]',
          assignment TEXT NOT NULL DEFAULT 'personal', assigneeId INTEGER,
          assigneeName TEXT, createdBy INTEGER, createdByName TEXT,
          repeatInterval INTEGER NOT NULL DEFAULT 1,
          repeatWeekdays TEXT NOT NULL DEFAULT '[]', exceptions TEXT NOT NULL DEFAULT '[]',
          owner_key TEXT NOT NULL DEFAULT 'local', sync_id TEXT,
          remote_version INTEGER NOT NULL DEFAULT 0, revision INTEGER NOT NULL DEFAULT 0,
          sync_pending INTEGER NOT NULL DEFAULT 0, is_deleted INTEGER NOT NULL DEFAULT 0,
          own_reminders_pending INTEGER NOT NULL DEFAULT 0
        )''');
          await db.execute(
            'CREATE UNIQUE INDEX task_sync_owner ON tasks(owner_key, sync_id)',
          );
          await createCaptureTables(db);
          await createReminderTables(db);
          await createListTables(db);
          await createImportTables(db);
          await createAttachmentTables(db);
        },
        onUpgrade: upgrade,
      ),
    );
  }

  static Future<void> upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 15 && newVersion >= 15) {
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN kind TEXT NOT NULL DEFAULT 'task'",
      );
    }
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN notes TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tasks ADD COLUMN filePaths TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN imagePaths TEXT');
    }
    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN owner_key TEXT NOT NULL DEFAULT 'local'",
      );
      await db.execute('ALTER TABLE tasks ADD COLUMN sync_id TEXT');
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN remote_version INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN revision INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN sync_pending INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'CREATE UNIQUE INDEX task_sync_owner ON tasks(owner_key, sync_id)',
      );
    }
    if (oldVersion < 5 && newVersion >= 5) {
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN hasTime INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN recurrence TEXT NOT NULL DEFAULT 'none'",
      );
      await db.execute('ALTER TABLE tasks ADD COLUMN repeatUntil TEXT');
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN completedDates TEXT NOT NULL DEFAULT '[]'",
      );
    }
    if (oldVersion < 6 && newVersion >= 6) await createCaptureTables(db);
    if (oldVersion < 7 && newVersion >= 7) {
      await db.execute('ALTER TABLE tasks ADD COLUMN reminderMinutes INTEGER');
      await db.execute('ALTER TABLE tasks ADD COLUMN reminderTime INTEGER');
      await createReminderTables(db);
    }
    if (oldVersion < 8 && newVersion >= 8) {
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN checklist TEXT NOT NULL DEFAULT '[]'",
      );
    }
    if (oldVersion < 9 && newVersion >= 9) {
      await db.execute('ALTER TABLE tasks ADD COLUMN listId TEXT');
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN labels TEXT NOT NULL DEFAULT '[]'",
      );
      await createListTables(db);
    }
    if (oldVersion < 10 && newVersion >= 10) {
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN repeatInterval INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN repeatWeekdays TEXT NOT NULL DEFAULT '[]'",
      );
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN exceptions TEXT NOT NULL DEFAULT '[]'",
      );
    }
    if (oldVersion < 11 && newVersion >= 11) await createImportTables(db);
    if (oldVersion < 12 && newVersion >= 12) await createAttachmentTables(db);
    if (oldVersion < 13 && newVersion >= 13) {
      await db.execute('ALTER TABLE tasks ADD COLUMN deadline TEXT');
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN deadlineHasTime INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE tasks ADD COLUMN durationMinutes INTEGER');
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN reminderAnchor TEXT NOT NULL DEFAULT 'planned'",
      );
    }
    if (oldVersion < 14 && newVersion >= 14) {
      // Some older migrations create list tables using the current definition.
      final columns = (await db.rawQuery(
        'PRAGMA table_info(task_lists)',
      )).map((row) => row['name']).toSet();
      if (!columns.contains('role')) {
        await db.execute(
          "ALTER TABLE task_lists ADD COLUMN role TEXT NOT NULL DEFAULT 'owner'",
        );
      }
      if (!columns.contains('shared')) {
        await db.execute(
          'ALTER TABLE task_lists ADD COLUMN shared INTEGER NOT NULL DEFAULT 0',
        );
      }
    }
    if (oldVersion < 16 && newVersion >= 16) {
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN assignment TEXT NOT NULL DEFAULT 'personal'",
      );
      await db.execute('ALTER TABLE tasks ADD COLUMN assigneeId INTEGER');
      await db.execute('ALTER TABLE tasks ADD COLUMN assigneeName TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN createdBy INTEGER');
      final columns = (await db.rawQuery(
        'PRAGMA table_info(task_lists)',
      )).map((row) => row['name']).toSet();
      for (final entry in {
        'group_id': 'TEXT',
        'group_name': 'TEXT',
        'owner_id': 'INTEGER',
        'people': "TEXT NOT NULL DEFAULT '[]'",
        'pinned': 'INTEGER NOT NULL DEFAULT 0',
        'notifications': "TEXT NOT NULL DEFAULT 'assigned'",
        'preference_pending': 'INTEGER NOT NULL DEFAULT 0',
        'preference_revision': 'INTEGER NOT NULL DEFAULT 0',
      }.entries) {
        if (!columns.contains(entry.key)) {
          await db.execute(
            'ALTER TABLE task_lists ADD COLUMN ${entry.key} ${entry.value}',
          );
        }
      }
      await db.rawUpdate(
        "UPDATE tasks SET assignment = 'group' WHERE kind = 'task' AND EXISTS (SELECT 1 FROM task_lists WHERE task_lists.id = tasks.listId AND task_lists.owner_key = tasks.owner_key AND task_lists.shared = 1)",
      );
    }
    if (oldVersion < 17 && newVersion >= 17) {
      final columns = (await db.rawQuery(
        'PRAGMA table_info(task_lists)',
      )).map((row) => row['name']).toSet();
      if (!columns.contains('group_archived')) {
        await db.execute(
          'ALTER TABLE task_lists ADD COLUMN group_archived INTEGER NOT NULL DEFAULT 0',
        );
      }
    }
    if (oldVersion < 18 && newVersion >= 18) {
      // Who created a shared task, by name; filled in by the next sync.
      await db.execute('ALTER TABLE tasks ADD COLUMN createdByName TEXT');
    }
    if (oldVersion < 19 && newVersion >= 19) {
      // A reminder plan, as its JSON (Backend/docs/REMINDER_PLANS.md).
      // Every task keeps its single reminder: none has a plan yet.
      await db.execute('ALTER TABLE tasks ADD COLUMN reminderPlan TEXT');
    }
    if (oldVersion < 20 && newVersion >= 20) {
      // Whether a row's unsent change is only this account's own reminders
      // ([updateOwnReminders]), which a «lector» sends whatever else the
      // owner changed meanwhile (D9). Rows pending today keep their change.
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN own_reminders_pending INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  static Future<void> createAttachmentTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS task_attachments(
      owner_key TEXT NOT NULL, id TEXT NOT NULL, task_id TEXT NOT NULL,
      name TEXT NOT NULL, size INTEGER NOT NULL DEFAULT 0, sha256 TEXT NOT NULL DEFAULT '',
      local_path TEXT, source_path TEXT, remote INTEGER NOT NULL DEFAULT 0,
      upload_pending INTEGER NOT NULL DEFAULT 0, delete_pending INTEGER NOT NULL DEFAULT 0,
      is_deleted INTEGER NOT NULL DEFAULT 0, error TEXT,
      PRIMARY KEY(owner_key, id))''');
    await db.execute('''CREATE UNIQUE INDEX IF NOT EXISTS attachment_source
      ON task_attachments(owner_key, task_id, source_path)
      WHERE is_deleted = 0 AND source_path IS NOT NULL''');
    await db.execute('''CREATE INDEX IF NOT EXISTS attachment_task
      ON task_attachments(owner_key, task_id)''');
  }

  /// Queue only newly added signed-in files, in the same transaction as the
  /// task. Legacy files and guest imports require an explicit upload choice.
  static Future<void> stageAttachments(
    DatabaseExecutor tx,
    String owner,
    String taskId,
    Task task, {
    Task? before,
  }) async {
    if (owner == 'local') return;
    final previous = {...?before?.filePaths, ...?before?.imagePaths};
    final current = {...task.filePaths, ...task.imagePaths};
    for (final source in previous.difference(current)) {
      await tx.update(
        'task_attachments',
        {'is_deleted': 1, 'delete_pending': 1, 'error': null},
        where:
            'owner_key = ? AND task_id = ? AND source_path = ? AND is_deleted = 0',
        whereArgs: [owner, taskId, source],
      );
    }
    for (final source in current.difference(previous)) {
      await tx.rawInsert(
        '''INSERT OR IGNORE INTO task_attachments
        (owner_key, id, task_id, name, local_path, source_path, upload_pending)
        VALUES(?,?,?,?,?,?,1)''',
        [owner, const Uuid().v4(), taskId, basename(source), source, source],
      );
    }
  }

  static Future<void> createImportTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS archive_imports(
      owner_key TEXT NOT NULL, archive_id TEXT NOT NULL, source_id TEXT NOT NULL,
      kind TEXT NOT NULL, target_id TEXT NOT NULL,
      PRIMARY KEY(owner_key, archive_id, kind, source_id))''');
  }

  static Future<void> createListTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS task_lists(
      id TEXT NOT NULL, owner_key TEXT NOT NULL, name TEXT NOT NULL, color TEXT NOT NULL DEFAULT 'teal',
      archived INTEGER NOT NULL DEFAULT 0, remote_version INTEGER NOT NULL DEFAULT 0,
      revision INTEGER NOT NULL DEFAULT 0, sync_pending INTEGER NOT NULL DEFAULT 0, conflict TEXT,
      role TEXT NOT NULL DEFAULT 'owner', shared INTEGER NOT NULL DEFAULT 0,
      group_id TEXT, group_name TEXT, group_archived INTEGER NOT NULL DEFAULT 0, owner_id INTEGER, people TEXT NOT NULL DEFAULT '[]',
      pinned INTEGER NOT NULL DEFAULT 0, notifications TEXT NOT NULL DEFAULT 'assigned',
      preference_pending INTEGER NOT NULL DEFAULT 0, preference_revision INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(owner_key, id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS list_imports(
      owner_key TEXT NOT NULL, source_id TEXT NOT NULL, target_id TEXT NOT NULL,
      PRIMARY KEY(owner_key, source_id))''');
  }

  static Future<void> validateList(
    DatabaseExecutor db,
    Task task,
    String owner,
  ) async {
    if (task.listId == null) return;
    final rows = await db.query(
      'task_lists',
      columns: ['id', 'role'],
      where: 'id = ? AND owner_key = ?',
      whereArgs: [task.listId, owner],
    );
    if (rows.isEmpty) throw StateError('Choose a list from this account.');
    if (rows.single['role'] == 'viewer') {
      throw StateError('This shared list is read-only.');
    }
  }

  static Future<Task> normalizeResponsibility(
    DatabaseExecutor db,
    Task task,
    String owner,
  ) async {
    await validateList(db, task, owner);
    final projects = task.listId == null
        ? <Map<String, Object?>>[]
        : await db.query(
            'task_lists',
            where: 'id = ? AND owner_key = ?',
            whereArgs: [task.listId, owner],
          );
    final shared = projects.isNotEmpty && projects.single['shared'] == 1;
    if (task.isNote || !shared) {
      if (!task.isNote && task.assignment != 'personal') {
        throw StateError('Choose a shared project for this assignment.');
      }
      return task.copyWith(
        assignment: 'personal',
        assigneeId: null,
        assigneeName: null,
      );
    }
    if (task.assignment == 'member') {
      final people =
          jsonDecode(projects.single['people'] as String? ?? '[]') as List;
      final person = people
          .where(
            (p) =>
                p['user_id'] == task.assigneeId &&
                ['owner', 'admin', 'editor'].contains(p['role']),
          )
          .firstOrNull;
      if (person == null) throw StateError('Choose a current project member.');
      return task.copyWith(assigneeName: person['name'] as String);
    }
    return task.copyWith(
      assignment: task.assignment == 'personal' ? 'group' : task.assignment,
      assigneeId: null,
      assigneeName: null,
    );
  }

  /// Also used by background notification workers: team assignments must not
  /// become personal reminders simply because the app is not open.
  static Future<List<Task>> reminderTasks(
    DatabaseExecutor db,
    String owner,
    Iterable<Task> tasks,
  ) async {
    final id = int.tryParse(
      RegExp(r'/users/(\d+)$').firstMatch(owner)?.group(1) ?? '',
    );
    final projects = await db.query(
      'task_lists',
      where: 'owner_key = ?',
      whereArgs: [owner],
    );
    return tasks.where((task) {
      final project = projects.where((p) => p['id'] == task.listId).firstOrNull;
      return reminderBlock(
            task,
            id,
            archived:
                project?['archived'] == 1 || project?['group_archived'] == 1,
            muted: project?['notifications'] == 'muted',
            role: project?['role'] as String?,
          ) ==
          null;
    }).toList();
  }

  /// The projects where account [owner] is «lector»: their tasks' reminders
  /// ring for a reader, who can't complete them (D9), so their notices offer
  /// no «Completar».
  static Future<Set<String>> readOnlyProjects(
    DatabaseExecutor db,
    String owner,
  ) async => {
    for (final row in await db.query(
      'task_lists',
      columns: ['id'],
      where: "owner_key = ? AND role = 'viewer'",
      whereArgs: [owner],
    ))
      row['id'] as String,
  };

  /// Why this phone won't remind about [task], or null when it will: its
  /// project, or the project's group, is [archived]; the project is [muted];
  /// or the task isn't for account [accountId], whose [role] in the project
  /// decides whether an unassigned task is. The reminder engine
  /// ([reminderTasks]) and the reminder chip both apply this rule.
  static ReminderBlock? reminderBlock(
    Task task,
    int? accountId, {
    bool archived = false,
    bool muted = false,
    String? role,
  }) {
    if (archived) return ReminderBlock.archived;
    if (muted) return ReminderBlock.muted;
    if (!task.isForAccount(
      accountId,
      managesProject: ['owner', 'admin'].contains(role),
    )) {
      return ReminderBlock.notForAccount;
    }
    return null;
  }

  static Future<void> createReminderTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS app_preferences(
      scope TEXT PRIMARY KEY, data TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS reminder_meta(
      key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS reminder_state(
      id INTEGER PRIMARY KEY AUTOINCREMENT, owner_key TEXT NOT NULL,
      identity TEXT NOT NULL UNIQUE, task_id INTEGER, occurrence TEXT,
      due_at TEXT, fire_at TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL,
      daily INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL,
      error TEXT, signature TEXT, token TEXT, updated_at TEXT NOT NULL)''');
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS reminder_snoozes(
      identity TEXT PRIMARY KEY, owner_key TEXT NOT NULL, fire_at TEXT NOT NULL)''',
    );
  }

  static Future<void> createCaptureTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS captures(
      id TEXT PRIMARY KEY, owner_key TEXT NOT NULL, status TEXT NOT NULL,
      captured_at TEXT NOT NULL, data TEXT NOT NULL)''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS capture_owner ON captures(owner_key, status)',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS diagnostics(
      id INTEGER PRIMARY KEY AUTOINCREMENT, event TEXT NOT NULL,
      elapsed_ms INTEGER, count INTEGER, created_at TEXT NOT NULL)''');
  }

  Future<int> insertTask(Task task, {String ownerKey = 'local'}) async {
    return (await database).transaction((tx) async {
      task = await normalizeResponsibility(tx, task, ownerKey);
      final values = task.toMap()..remove('id');
      final syncId = const Uuid().v4();
      final id = await tx.insert('tasks', {
        ...values,
        'owner_key': ownerKey,
        'sync_id': syncId,
        'sync_pending': ownerKey == 'local' ? 0 : 1,
      });
      await stageAttachments(tx, ownerKey, syncId, task);
      return id;
    });
  }

  Future<List<Task>> getTasks({String ownerKey = 'local'}) async {
    final rows = await (await database).query(
      'tasks',
      where: 'owner_key = ? AND is_deleted = 0',
      whereArgs: [ownerKey],
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<void> insertTasks(
    List<Task> tasks, {
    String ownerKey = 'local',
  }) async {
    await (await database).transaction((tx) async {
      for (final input in tasks) {
        final task = await normalizeResponsibility(tx, input, ownerKey);
        final values = task.toMap()..remove('id');
        final syncId = const Uuid().v4();
        await tx.insert('tasks', {
          ...values,
          'owner_key': ownerKey,
          'sync_id': syncId,
          'sync_pending': ownerKey == 'local' ? 0 : 1,
        });
        await stageAttachments(tx, ownerKey, syncId, task);
      }
    });
  }

  Future<int> updateTask(Task task, {String ownerKey = 'local'}) async {
    final db = await database;
    return db.transaction((tx) async {
      task = await normalizeResponsibility(tx, task, ownerKey);
      final previous = await tx.query(
        'tasks',
        where: 'id = ? AND owner_key = ? AND is_deleted = 0',
        whereArgs: [task.id, ownerKey],
      );
      if (previous.isEmpty) {
        throw StateError('This task is no longer in the current account.');
      }
      await validateList(tx, Task.fromMap(previous.single), ownerKey);
      if ((previous.single['kind'] ?? 'task') != task.kind) {
        throw StateError('Create a separate task or note to change its type.');
      }
      if (previous.single['listId'] != task.listId &&
          previous.single['listId'] != null) {
        final lists = await tx.query(
          'task_lists',
          where: 'id = ? AND owner_key = ? AND shared = 1',
          whereArgs: [previous.single['listId'], ownerKey],
        );
        if (lists.isNotEmpty) {
          throw StateError(
            'Shared tasks stay in their list. Export a personal copy if needed.',
          );
        }
      }
      final values = task.toMap()..remove('id');
      final count = await tx.update(
        'tasks',
        {
          ...values,
          'sync_pending': ownerKey == 'local' ? 0 : 1,
          'own_reminders_pending': 0,
        },
        where: 'id = ? AND owner_key = ? AND is_deleted = 0',
        whereArgs: [task.id, ownerKey],
      );
      if (count == 0) {
        throw StateError('This task is no longer in the current account.');
      }
      await tx.rawUpdate(
        'UPDATE tasks SET revision = revision + 1 WHERE id = ? AND owner_key = ?',
        [task.id, ownerKey],
      );
      if (ownerKey != 'local') {
        await stageAttachments(
          tx,
          ownerKey,
          previous.single['sync_id'] as String,
          task,
          before: Task.fromMap(previous.single),
        );
      }
      return count;
    });
  }

  /// Sets only this account's own reminders on task [taskId]: the single
  /// reminder's [minutes] and [time], and the [plan]. The one write a
  /// «lector» project takes from a reader (D9), so it skips [validateList]'s
  /// read-only refusal; nothing else of the task changes. The row goes
  /// pending, and the sync sends it as a change to these reminders alone.
  /// When nothing else was waiting to be sent, the row is marked
  /// `own_reminders_pending`, so the sync sends these reminders even after
  /// the owner changed the task first; a row already pending with another
  /// change stays unmarked, and every other write clears the mark.
  Future<int> updateOwnReminders(
    int taskId, {
    String ownerKey = 'local',
    int? minutes,
    int? time,
    ReminderPlan? plan,
  }) async {
    final count = await (await database).rawUpdate(
      '''UPDATE tasks SET reminderMinutes = ?, reminderTime = ?, reminderPlan = ?,
      sync_pending = ?, revision = revision + 1,
      own_reminders_pending = CASE WHEN ? = 1
        AND (sync_pending = 0 OR own_reminders_pending = 1) THEN 1 ELSE 0 END
      WHERE id = ? AND owner_key = ? AND is_deleted = 0
        AND (kind IS NULL OR kind != 'note')''',
      [
        minutes,
        time,
        plan?.encode(),
        ownerKey == 'local' ? 0 : 1,
        ownerKey == 'local' ? 0 : 1,
        taskId,
        ownerKey,
      ],
    );
    if (count == 0) {
      throw StateError('This task is no longer in the current account.');
    }
    return count;
  }

  Future<int> deleteTask(int id, {String ownerKey = 'local'}) async {
    final db = await database;
    if (ownerKey == 'local') {
      return db.delete(
        'tasks',
        where: 'id = ? AND owner_key = ?',
        whereArgs: [id, ownerKey],
      );
    }
    return db.transaction((tx) async {
      final rows = await tx.query(
        'tasks',
        where: 'id = ? AND owner_key = ?',
        whereArgs: [id, ownerKey],
      );
      if (rows.isEmpty) return 0;
      await validateList(tx, Task.fromMap(rows.single), ownerKey);
      return tx.rawUpdate(
        'UPDATE tasks SET is_deleted = 1, sync_pending = 1, own_reminders_pending = 0, revision = revision + 1 WHERE id = ? AND owner_key = ?',
        [id, ownerKey],
      );
    });
  }

  /// Undoes [deleteTask] with [task] as it was before. An account's row comes
  /// back as the same task, sent as not deleted on the next sync (the server
  /// accepts it at the current version). The local owner's row was removed,
  /// so it is inserted again, keeping its id when it is still free.
  Future<int> restoreTask(Task task, {String ownerKey = 'local'}) async {
    return (await database).transaction((tx) async {
      final rows = await tx.query(
        'tasks',
        where: 'id = ? AND owner_key = ? AND is_deleted = 1',
        whereArgs: [task.id, ownerKey],
      );
      if (rows.isNotEmpty) {
        final paths = task.toMap();
        await tx.rawUpdate(
          '''UPDATE tasks SET is_deleted = 0, sync_pending = ?, revision = revision + 1,
          own_reminders_pending = 0, filePaths = ?, imagePaths = ? WHERE id = ? AND owner_key = ?''',
          [
            ownerKey == 'local' ? 0 : 1,
            paths['filePaths'],
            paths['imagePaths'],
            task.id,
            ownerKey,
          ],
        );
        // Files the deletion already let go of are uploaded again.
        await stageAttachments(
          tx,
          ownerKey,
          rows.single['sync_id'] as String,
          task,
          before: Task.fromMap(rows.single),
        );
        return task.id!;
      }
      task = await normalizeResponsibility(tx, task, ownerKey);
      final values = task.toMap();
      final taken =
          task.id == null ||
          (await tx.query(
            'tasks',
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [task.id],
          )).isNotEmpty;
      if (taken) values.remove('id');
      final syncId = const Uuid().v4();
      final id = await tx.insert('tasks', {
        ...values,
        'owner_key': ownerKey,
        'sync_id': syncId,
        'sync_pending': ownerKey == 'local' ? 0 : 1,
      });
      await stageAttachments(tx, ownerKey, syncId, task);
      return id;
    });
  }

  Future<List<Map<String, dynamic>>> pending(String ownerKey) async =>
      (await database).query(
        'tasks',
        where: 'owner_key = ? AND sync_pending = 1',
        whereArgs: [ownerKey],
      );

  Future<void> recoverReadOnlyDraft(
    String ownerKey,
    int id, {
    bool assignmentChanged = false,
    int? revision,
  }) async {
    await (await database).rawUpdate(
      '''UPDATE tasks SET listId = NULL, assignment = 'personal', assigneeId = NULL,
        assigneeName = NULL, createdBy = NULL, createdByName = NULL,
        own_reminders_pending = 0, revision = revision + 1
      WHERE owner_key = ? AND id = ? AND remote_version = 0 AND sync_pending = 1
      ${revision == null ? '' : 'AND revision = ?'}
      ${assignmentChanged ? '' : "AND listId IN (SELECT id FROM task_lists WHERE owner_key = ? AND role = 'viewer')"}''',
      [
        ownerKey,
        id,
        if (revision != null) revision,
        if (!assignmentChanged) ownerKey,
      ],
    );
  }

  Future<void> acknowledge(
    String ownerKey,
    Map<String, dynamic> sent,
    Map<String, dynamic> remote,
  ) async {
    // A user may edit while an upload is in flight. Never clear that newer edit.
    await (await database).rawUpdate(
      '''UPDATE tasks SET remote_version = ?,
      sync_pending = CASE WHEN revision = ? THEN 0 ELSE 1 END,
      own_reminders_pending = CASE WHEN revision = ? THEN 0
        ELSE own_reminders_pending END
      WHERE id = ? AND owner_key = ?''',
      [
        remote['version'],
        sent['revision'],
        sent['revision'],
        sent['id'],
        ownerKey,
      ],
    );
  }

  /// Takes [remote] as task [sent]'s server copy, keeping the reminders this
  /// account chose on the phone ([updateOwnReminders]): a reader's were saved
  /// on the server, which answered with the task as it is, or with 409 when
  /// it had changed meanwhile (D9). The anchor is the server's, which a
  /// reader never sets. A choice made since [sent] went out stays pending.
  Future<void> acceptKeepingReminders(
    String ownerKey,
    Map<String, dynamic> sent,
    Map<String, dynamic> remote,
  ) async {
    await (await database).transaction((tx) async {
      await tx.update(
        'tasks',
        _remoteValues(remote)
          ..remove('reminderMinutes')
          ..remove('reminderTime')
          ..remove('reminderPlan')
          ..remove('sync_pending')
          ..remove('own_reminders_pending'),
        where: 'id = ? AND owner_key = ?',
        whereArgs: [sent['id'], ownerKey],
      );
      await tx.rawUpdate(
        '''UPDATE tasks SET sync_pending = CASE WHEN revision = ? THEN 0 ELSE 1 END,
        own_reminders_pending = CASE WHEN revision = ? THEN 0
          ELSE own_reminders_pending END
        WHERE id = ? AND owner_key = ?''',
        [sent['revision'], sent['revision'], sent['id'], ownerKey],
      );
    });
  }

  Map<String, dynamic> _remoteValues(Map<String, dynamic> remote) => {
    ...(Task.fromApi(remote).toMap()
      ..remove('id')
      ..remove('filePaths')
      ..remove('imagePaths')
      // A server that doesn't send plans yet leaves this phone's as it is.
      ..removeWhere(
        (key, _) =>
            key == 'reminderPlan' && !remote.containsKey('reminder_plan'),
      )),
    'is_deleted': remote['is_deleted'] == true ? 1 : 0,
    'remote_version': remote['version'],
    'sync_pending': 0,
    'own_reminders_pending': 0,
  };

  Future<void> mergeRemote(String ownerKey, Map<String, dynamic> remote) async {
    final db = await database;
    await db.transaction((tx) async {
      if (remote['list_id'] != null) {
        final access = await tx.query(
          'task_lists',
          columns: ['id'],
          where: 'owner_key = ? AND id = ?',
          whereArgs: [ownerKey, remote['list_id']],
        );
        // A late page from another sync isolate must not reinsert group data
        // after a newer access snapshot has removed the cached membership.
        if (access.isEmpty) return;
      }
      final rows = await tx.query(
        'tasks',
        where: 'owner_key = ? AND sync_id = ?',
        whereArgs: [ownerKey, remote['id']],
      );
      if (rows.isEmpty) {
        await tx.insert('tasks', {
          ..._remoteValues(remote),
          'owner_key': ownerKey,
          'sync_id': remote['id'],
        });
      } else if (rows.single['sync_pending'] == 0 &&
          (rows.single['remote_version'] as int) <=
              (remote['version'] as int)) {
        // Attachment paths stay on this device and are never copied from the server.
        await tx.update(
          'tasks',
          _remoteValues(remote),
          where: 'id = ? AND owner_key = ?',
          whereArgs: [rows.single['id'], ownerKey],
        );
      }
    });
  }

  Future<void> preserveConflict(
    String ownerKey,
    Map<String, dynamic> sent,
    Map<String, dynamic> remote,
  ) async {
    // The copy's title says what it is in the app's language: «(copia local)».
    String suffix;
    try {
      suffix = (await readReminderStrings(this)).syncCopySuffix;
    } catch (_) {
      suffix = lookupAppLocalizations(const Locale('en')).syncCopySuffix;
    }
    final db = await database;
    await db.transaction((tx) async {
      final rows = await tx.query(
        'tasks',
        where: 'id = ? AND owner_key = ?',
        whereArgs: [sent['id'], ownerKey],
      );
      if (rows.isEmpty) return;
      final local = Map<String, dynamic>.from(rows.single);
      // Keep offline edits as a visible copy instead of overwriting another device.
      if (local['is_deleted'] == 0) {
        final lists = local['listId'] == null
            ? []
            : await tx.query(
                'task_lists',
                where: 'id = ? AND owner_key = ? AND shared = 1',
                whereArgs: [local['listId'], ownerKey],
              );
        // A conflicting group edit becomes a personal copy, not a duplicate
        // sent back to everyone else's shared list.
        if (lists.isNotEmpty) {
          local.addAll({
            'listId': null,
            'assignment': 'personal',
            'assigneeId': null,
            'assigneeName': null,
            'createdBy': null,
            'createdByName': null,
          });
        }
        final title = '${local['title']} $suffix';
        local.remove('id');
        await tx.insert('tasks', {
          ...local,
          'title': title.length > 160 ? title.substring(0, 160) : title,
          'sync_id': const Uuid().v4(),
          'remote_version': 0,
          'revision': 0,
          'sync_pending': 1,
          'own_reminders_pending': 0,
        });
      }
      await tx.update(
        'tasks',
        _remoteValues(remote),
        where: 'id = ? AND owner_key = ?',
        whereArgs: [sent['id'], ownerKey],
      );
    });
  }

  Future<int> importLocalTasks(String ownerKey) async {
    final db = await database;
    return db.transaction((tx) async {
      final rows = await tx.query(
        'tasks',
        where: "owner_key = 'local' AND is_deleted = 0",
      );
      final importedLists = <String, String>{};
      for (final sourceId
          in rows.map((row) => row['listId']).whereType<String>().toSet()) {
        final mapping = await tx.query(
          'list_imports',
          where: 'owner_key = ? AND source_id = ?',
          whereArgs: [ownerKey, sourceId],
        );
        if (mapping.isNotEmpty) {
          importedLists[sourceId] = mapping.single['target_id'] as String;
          continue;
        }
        final localLists = await tx.query(
          'task_lists',
          where: "owner_key = 'local' AND id = ?",
          whereArgs: [sourceId],
        );
        if (localLists.isEmpty) continue;
        final newId = const Uuid().v4();
        await tx.insert('task_lists', {
          ...localLists.single,
          'id': newId,
          'owner_key': ownerKey,
          'sync_pending': 1,
          'remote_version': 0,
          'revision': 0,
          'conflict': null,
        });
        await tx.insert('list_imports', {
          'owner_key': ownerKey,
          'source_id': sourceId,
          'target_id': newId,
        });
        importedLists[sourceId] = newId;
      }
      for (final row in rows) {
        await tx.update(
          'tasks',
          {
            'owner_key': ownerKey,
            'listId': importedLists[row['listId']],
            'sync_id': row['sync_id'] ?? const Uuid().v4(),
            'sync_pending': 1,
          },
          where: "id = ? AND owner_key = 'local'",
          whereArgs: [row['id']],
        );
      }
      return rows.length;
    });
  }

  Future<List<Task>> getTasksOverdueByFourMonths() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 120));
    return (await getTasks())
        .where(
          (task) =>
              !task.isRecurring && (task.dueDate?.isBefore(cutoff) ?? false),
        )
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
        .where(
          (task) =>
              !task.isCompleted &&
              (task.dueDate?.isAfter(now) ?? false) &&
              task.dueDate!.isBefore(now.add(const Duration(days: 3))),
        )
        .toList();
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
