import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:agenda/models/task.dart';

class TaskDatabase {
  static final TaskDatabase _instance = TaskDatabase._internal();
  static Database? _database;

  factory TaskDatabase() {
    return _instance;
  }

  TaskDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'task_database.db');

    return await openDatabase(
      path,
      version: 2, // Increment the version number
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            dueDate TEXT,
            priority INTEGER,
            isCompleted INTEGER,
            notes TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE tasks ADD COLUMN notes TEXT');
        }
      },
    );
  }

  Future<int> insertTask(Task task) async {
    final db = await database;
    return await db.insert('tasks', task.toMap());
  }

  Future<List<Task>> getTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tasks');

    return List.generate(maps.length, (i) {
      return Task.fromMap(maps[i]);
    });
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    return await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }

  // Method to get tasks overdue by 4 months
  Future<List<Task>> getTasksOverdueByFourMonths() async {
    final db = await database;
    final overdueThreshold =
        DateTime.now().subtract(const Duration(days: 120)); // 4 months ago

    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'dueDate <= ?',
      whereArgs: [overdueThreshold.toIso8601String()],
    );

    return List.generate(maps.length, (i) {
      return Task.fromMap(maps[i]);
    });
  }

  // Method to delete a list of tasks
  Future<void> deleteTasks(List<int> taskIds) async {
    final db = await database;
    for (int id in taskIds) {
      await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
    }
  }

  // Existing method to retrieve tasks due in the next three days
  Future<List<Task>> getTasksForNextThreeDays() async {
    final db = await database;
    final now = DateTime.now();
    final threeDaysFromNow = now.add(const Duration(days: 3));

    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'dueDate >= ? AND dueDate <= ?',
      whereArgs: [now.toIso8601String(), threeDaysFromNow.toIso8601String()],
    );

    return List.generate(maps.length, (i) {
      return Task.fromMap(maps[i]);
    });
  }
}
