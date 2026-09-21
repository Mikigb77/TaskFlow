import 'package:agenda/models/task.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/task_database.dart';

class CloudTaskRepository extends TaskRepository {
  final TaskDatabase database;
  final ApiClient api;
  final int accountId;
  final String ownerKey;
  Future<void>? _syncing;

  CloudTaskRepository(this.database, this.api, this.accountId)
      : ownerKey = '${api.baseUrl}/users/$accountId',
        super(database);

  @override
  Future<int> addTask(Task task) =>
      database.insertTask(task, ownerKey: ownerKey);
  @override
  Future<void> addTasks(List<Task> tasks) =>
      database.insertTasks(tasks, ownerKey: ownerKey);
  @override
  Future<List<Task>> getAllTasks() => database.getTasks(ownerKey: ownerKey);
  @override
  Future<int> updateTask(Task task) =>
      database.updateTask(task, ownerKey: ownerKey);
  @override
  Future<int> deleteTask(int id) => database.deleteTask(id, ownerKey: ownerKey);
  @override
  Future<int> importLocalTasks() => database.importLocalTasks(ownerKey);

  Map<String, dynamic> _payload(Map<String, dynamic> row) => {
        ...Task.fromMap(row).toApi(),
        'is_deleted': row['is_deleted'] == 1,
        'version': row['remote_version'],
      };

  bool _sameContent(Map<String, dynamic> sent, Map<String, dynamic> remote) =>
      sent['title'] == remote['title'] &&
      sent['notes'] == remote['notes'] &&
      sent['priority'] == remote['priority'] &&
      sent['is_completed'] == remote['is_completed'] &&
      sent['is_deleted'] == remote['is_deleted'] &&
      sent['scheduled_date'] == remote['scheduled_date'] &&
      sent['recurrence'] == (remote['recurrence'] ?? 'none') &&
      sent['repeat_until'] == remote['repeat_until'] &&
      _sameDates(sent['completed_dates'], remote['completed_dates'] ?? []) &&
      (sent['due_date'] == null
          ? remote['due_date'] == null
          : remote['due_date'] != null &&
              DateTime.parse(sent['due_date'] as String).isAtSameMomentAs(
                  DateTime.parse(remote['due_date'] as String)));

  bool _sameDates(List<dynamic> a, List<dynamic> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  @override
  Future<void> sync() =>
      _syncing ??= _synchronize().whenComplete(() => _syncing = null);

  Future<void> _synchronize() async {
    syncError = null;
    try {
      for (final row in await database.pending(ownerKey)) {
        final data = _payload(row);
        try {
          final remote = Map<String, dynamic>.from(await api.request(
              'PUT', 'tasks/${row['sync_id']}/',
              data: data, accountId: accountId) as Map);
          await database.acknowledge(ownerKey, row, remote);
        } on ApiException catch (error) {
          if (error.status != 409 || error.body?['current'] == null) rethrow;
          final remote =
              Map<String, dynamic>.from(error.body!['current'] as Map);
          if (_sameContent(data, remote)) {
            await database.acknowledge(ownerKey, row, remote);
          } else {
            await database.preserveConflict(ownerKey, row, remote);
            syncError =
                'A task changed on another device. Your edit was kept as an offline copy; a conflicting deletion was cancelled.';
          }
        }
      }
      int page = 1;
      while (true) {
        final result = Map<String, dynamic>.from(await api.request(
            'GET', 'tasks/?include_deleted=true&page=$page',
            accountId: accountId) as Map);
        for (final remote in result['results'] as List) {
          await database.mergeRemote(
              ownerKey, Map<String, dynamic>.from(remote as Map));
        }
        if (result['next'] == null) break;
        page++;
      }
    } on ApiException catch (error) {
      syncError = 'Saved on this phone. ${error.message}';
    }
  }
}
