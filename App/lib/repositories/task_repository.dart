import 'package:agenda/models/task.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/attachment_store.dart';

class TaskRepository {
  final TaskDatabase _database;

  TaskRepository(this._database);

  String? syncError;
  String get ownerKey => 'local';
  AttachmentStore get attachments => AttachmentStore(_database, ownerKey);
  Future<void> sync() async {}
  Future<int> importLocalTasks() async => 0;

  /// Tasks and notes saved on this phone before signing in.
  Future<int> localTaskCount() async => 0;

  Future<int> addTask(Task task) async {
    return await _database.insertTask(task);
  }

  Future<List<Task>> getAllTasks() async {
    return await _database.getTasks();
  }

  Future<void> addTasks(List<Task> tasks) => _database.insertTasks(tasks);

  Future<int> updateTask(Task task) async {
    return await _database.updateTask(task);
  }

  Future<int> deleteTask(int id) async {
    return await _database.deleteTask(id);
  }

  /// Brings back a task deleted with [deleteTask], as it was.
  Future<int> restoreTask(Task task) => _database.restoreTask(task);

  // Method to get tasks overdue by 4 months
  Future<List<Task>> getTasksOverdueByFourMonths() async {
    return await _database.getTasksOverdueByFourMonths();
  }

  // Method to delete a list of overdue tasks
  Future<void> deleteTasks(List<int> taskIds) async {
    return await _database.deleteTasks(taskIds);
  }

  // Existing method to get tasks for the next three days
  Future<List<Task>> getTasksForNextThreeDays() async {
    return await _database.getTasksForNextThreeDays();
  }
}
