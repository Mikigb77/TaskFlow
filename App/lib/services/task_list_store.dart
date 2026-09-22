import 'dart:convert';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/task_database.dart';

/// Lists sync before their tasks, so an offline task never references a list
/// the server has not received. A metadata conflict requires an explicit choice.
class TaskListStore {
  final TaskDatabase database;
  final String owner;
  TaskListStore(this.database, this.owner);

  Future<List<TaskListInfo>> all() async =>
      (await (await database.database).query('task_lists',
              where: 'owner_key = ?',
              whereArgs: [owner],
              orderBy: 'archived, name COLLATE NOCASE, id'))
          .map(TaskListInfo.fromRow)
          .toList();

  Map<String, Object?> _fields(TaskListInfo list) => {
        'name': list.name.trim(),
        'color': list.color,
        'archived': list.archived ? 1 : 0
      };

  void _validate(TaskListInfo list) {
    if (list.name.trim().isEmpty ||
        list.name.trim().length > 80 ||
        !['teal', 'blue', 'violet', 'amber', 'rose'].contains(list.color)) {
      throw ArgumentError(
          'Choose a list name of up to 80 characters and an available color.');
    }
  }

  Future<void> create(TaskListInfo list) async {
    _validate(list);
    await (await database.database).insert('task_lists', {
      'id': list.id,
      'owner_key': owner,
      ..._fields(list),
      'sync_pending': owner == 'local' ? 0 : 1
    });
  }

  Future<void> update(TaskListInfo list) async {
    _validate(list);
    await (await database.database).transaction((tx) async {
      final changed = await tx.update('task_lists',
          {..._fields(list), 'sync_pending': owner == 'local' ? 0 : 1},
          where: 'id = ? AND owner_key = ?', whereArgs: [list.id, owner]);
      if (changed == 0) {
        throw StateError('This list is no longer in this account.');
      }
      await tx.rawUpdate(
          'UPDATE task_lists SET revision = revision + 1 WHERE id = ? AND owner_key = ?',
          [list.id, owner]);
    });
  }

  Future<void> resolve(String id, {required bool keepLocal}) async {
    await (await database.database).transaction((tx) async {
      final rows = await tx.query('task_lists',
          where: 'id = ? AND owner_key = ?', whereArgs: [id, owner]);
      if (rows.isEmpty || rows.single['conflict'] == null) return;
      final remote =
          TaskListInfo.fromApi(jsonDecode(rows.single['conflict'] as String));
      await tx.update(
          'task_lists',
          {
            if (!keepLocal) ..._fields(remote),
            'remote_version': remote.version,
            'conflict': null,
            'sync_pending': keepLocal ? 1 : 0,
            'revision': (rows.single['revision'] as int) + 1,
          },
          where: 'id = ? AND owner_key = ?',
          whereArgs: [id, owner]);
    });
  }

  Future<void> sync(ApiClient api, int accountId) async {
    final db = await database.database;
    final pending = await db.query('task_lists',
        where: 'owner_key = ? AND sync_pending = 1 AND conflict IS NULL',
        whereArgs: [owner]);
    for (final row in pending) {
      final sent = TaskListInfo.fromRow(row);
      Map<String, dynamic> remote;
      try {
        remote = Map<String, dynamic>.from(await api.request(
            'PUT', 'lists/${sent.id}/',
            data: sent.toApi(), accountId: accountId));
      } on ApiException catch (error) {
        if (error.status != 409 || error.body?['current'] == null) rethrow;
        remote = Map<String, dynamic>.from(error.body!['current']);
        if (remote['name'] != sent.name ||
            remote['color'] != sent.color ||
            remote['archived'] != sent.archived) {
          await db.update('task_lists', {'conflict': jsonEncode(remote)},
              where: 'id = ? AND owner_key = ?', whereArgs: [sent.id, owner]);
          continue;
        }
      }
      await db.rawUpdate(
          'UPDATE task_lists SET remote_version = ?, sync_pending = CASE WHEN revision = ? THEN 0 ELSE 1 END WHERE id = ? AND owner_key = ?',
          [remote['version'], row['revision'], sent.id, owner]);
    }
    var page = 1;
    while (true) {
      final data = Map<String, dynamic>.from(
          await api.request('GET', 'lists/?page=$page', accountId: accountId));
      for (final json in data['results'] as List) {
        final list = TaskListInfo.fromApi(Map<String, dynamic>.from(json));
        await db.transaction((tx) async {
          final rows = await tx.query('task_lists',
              where: 'id = ? AND owner_key = ?', whereArgs: [list.id, owner]);
          if (rows.isEmpty) {
            await tx.insert('task_lists', {
              'id': list.id,
              'owner_key': owner,
              ..._fields(list),
              'remote_version': list.version
            });
          } else if (rows.single['sync_pending'] == 0 &&
              (rows.single['remote_version'] as int) <= list.version) {
            await tx.update(
                'task_lists',
                {
                  ..._fields(list),
                  'remote_version': list.version,
                  'conflict': null
                },
                where: 'id = ? AND owner_key = ?',
                whereArgs: [list.id, owner]);
          }
        });
      }
      if (data['next'] == null) break;
      page++;
    }
  }
}
