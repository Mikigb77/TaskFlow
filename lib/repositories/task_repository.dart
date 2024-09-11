import 'package:agenda/models/task.dart';
import 'package:agenda/services/task_database.dart';

class TaskRepository {
  final TaskDatabase _database;

  TaskRepository(this._database);

  Future<int> addTask(Task task) async {
    return await _database.insertTask(task);
  }

  Future<List<Task>> getAllTasks() async {
    return await _database.getTasks();
  }

  Future<int> updateTask(Task task) async {
    return await _database.updateTask(task);
  }

  Future<int> deleteTask(int id) async {
    return await _database.deleteTask(id);
  }

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
