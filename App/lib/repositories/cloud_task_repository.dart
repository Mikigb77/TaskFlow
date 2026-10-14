import 'package:agenda/models/task.dart';
import 'package:collection/collection.dart';
import 'package:agenda/services/task_list_store.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/task_database.dart';

class CloudTaskRepository extends TaskRepository {
  final TaskDatabase database;
  final ApiClient api;
  final int accountId;
  @override
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
  Future<int> restoreTask(Task task) =>
      database.restoreTask(task, ownerKey: ownerKey);
  @override
  Future<int> importLocalTasks() => database.importLocalTasks(ownerKey);
  @override
  Future<int> localTaskCount() async => (await database.getTasks()).length;

  Map<String, dynamic> _payload(Map<String, dynamic> row) => {
    ...Task.fromMap(row).toApi(),
    'is_deleted': row['is_deleted'] == 1,
    'version': row['remote_version'],
  };

  bool _sameContent(Map<String, dynamic> sent, Map<String, dynamic> remote) =>
      sent['title'] == remote['title'] &&
      sent['kind'] == (remote['kind'] ?? 'task') &&
      sent['notes'] == remote['notes'] &&
      sent['list_id'] == remote['list_id'] &&
      sent['assignment'] == (remote['assignment'] ?? 'personal') &&
      sent['assignee_id'] == remote['assignee_id'] &&
      const DeepCollectionEquality().equals(
        sent['labels'],
        remote['labels'] ?? [],
      ) &&
      const DeepCollectionEquality().equals(
        sent['checklist'],
        remote['checklist'] ?? [],
      ) &&
      sent['priority'] == remote['priority'] &&
      sent['reminder_minutes'] == remote['reminder_minutes'] &&
      sent['reminder_time'] == remote['reminder_time'] &&
      sent['is_completed'] == remote['is_completed'] &&
      sent['is_deleted'] == remote['is_deleted'] &&
      sent['scheduled_date'] == remote['scheduled_date'] &&
      sent['deadline_date'] == remote['deadline_date'] &&
      sent['duration_minutes'] == remote['duration_minutes'] &&
      sent['reminder_anchor'] == (remote['reminder_anchor'] ?? 'planned') &&
      (sent['deadline_at'] == null
          ? remote['deadline_at'] == null
          : remote['deadline_at'] != null &&
                DateTime.parse(
                  sent['deadline_at'],
                ).isAtSameMomentAs(DateTime.parse(remote['deadline_at']))) &&
      sent['recurrence'] == (remote['recurrence'] ?? 'none') &&
      sent['repeat_interval'] == (remote['repeat_interval'] ?? 1) &&
      const DeepCollectionEquality().equals(
        sent['repeat_weekdays'],
        remote['repeat_weekdays'] ?? [],
      ) &&
      const DeepCollectionEquality().equals(
        Task.fromApi(sent).exceptions.map((change) => change.toJson()).toList(),
        Task.fromApi(
          remote,
        ).exceptions.map((change) => change.toJson()).toList(),
      ) &&
      sent['repeat_until'] == remote['repeat_until'] &&
      _sameDates(sent['completed_dates'], remote['completed_dates'] ?? []) &&
      (sent['due_date'] == null
          ? remote['due_date'] == null
          : remote['due_date'] != null &&
                DateTime.parse(sent['due_date'] as String).isAtSameMomentAs(
                  DateTime.parse(remote['due_date'] as String),
                ));

  bool _sameDates(List<dynamic> a, List<dynamic> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  @override
  Future<void> sync() =>
      _syncing ??= _synchronize().whenComplete(() => _syncing = null);

  Future<void> _synchronize() async {
    syncError = null;
    try {
      final lists = TaskListStore(database, ownerKey);
      await lists.sync(api, accountId);
      if ((await lists.all()).any((list) => list.conflict != null)) {
        syncError =
            'A list changed on another device. Choose which version to keep in Lists.';
      }
      final pending = await database.pending(ownerKey);
      if (pending.any((row) => row['kind'] == 'note')) {
        final health = await api.request(
          'GET',
          'health/',
          accountId: accountId,
        );
        if (health is! Map ||
            health['features'] is! Map ||
            health['features']['notes'] != true) {
          throw ApiException(
            0,
            'Update this server before syncing notes. Your notes are kept on this phone.',
          );
        }
      }
      for (final row in pending) {
        final data = _payload(row);
        try {
          if (row['listId'] != null) {
            final list = (await lists.all())
                .where((list) => list.id == row['listId'])
                .firstOrNull;
            if (list == null) continue;
            if (list.role == 'viewer') {
              // Keep unsent work as a personal copy after an editor becomes a
              // viewer, then restore the authoritative shared version below.
              if ((row['remote_version'] as int) > 0) {
                final remote = Map<String, dynamic>.from(
                  await api.request(
                    'GET',
                    'tasks/${row['sync_id']}/',
                    accountId: accountId,
                  ),
                );
                await database.preserveConflict(ownerKey, row, remote);
              } else {
                await database.recoverReadOnlyDraft(ownerKey, row['id'] as int);
              }
              syncError =
                  'This list is now read-only. Your unsent task edit was kept as a personal copy.';
              continue;
            }
          }
          final remote = Map<String, dynamic>.from(
            await api.request(
                  'PUT',
                  'tasks/${row['sync_id']}/',
                  data: data,
                  accountId: accountId,
                )
                as Map,
          );
          if ((remote['kind'] ?? 'task') != data['kind']) {
            throw ApiException(
              0,
              'The server did not preserve this content type. Your local copy is kept.',
            );
          }
          await database.acknowledge(ownerKey, row, remote);
        } on ApiException catch (error) {
          if (error.status == 400 &&
              (error.body?.containsKey('assignee_id') == true ||
                  error.body?.containsKey('assignment') == true)) {
            // A member may leave after an offline edit. Keep the user's work
            // privately, then apply the server's shared task and continue sync.
            await lists.refreshAccess(api, accountId);
            if ((row['remote_version'] as int) > 0) {
              final remote = Map<String, dynamic>.from(
                await api.request(
                  'GET',
                  'tasks/${row['sync_id']}/',
                  accountId: accountId,
                ),
              );
              await database.preserveConflict(ownerKey, row, remote);
            } else {
              await database.recoverReadOnlyDraft(
                ownerKey,
                row['id'] as int,
                assignmentChanged: true,
                revision: row['revision'] as int,
              );
            }
            syncError =
                'Task responsibility changed. Your unsent edit was kept as a personal copy.';
            continue;
          }
          if (error.status == 403 || error.status == 404) {
            await lists.refreshAccess(api, accountId);
            syncError =
                'Shared-list access changed. Refresh to finish syncing permitted edits.';
            continue;
          }
          if (error.status != 409 || error.body?['current'] == null) rethrow;
          final remote = Map<String, dynamic>.from(
            error.body!['current'] as Map,
          );
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
        final result = Map<String, dynamic>.from(
          await api.request(
                'GET',
                'tasks/?include_deleted=true&page=$page',
                accountId: accountId,
              )
              as Map,
        );
        for (final remote in result['results'] as List) {
          await database.mergeRemote(
            ownerKey,
            Map<String, dynamic>.from(remote as Map),
          );
        }
        if (result['next'] == null) break;
        page++;
      }
      await attachments.sync(api, accountId);
    } on ApiException catch (error) {
      syncError = 'Saved on this phone. ${error.message}';
    }
  }
}
