import 'dart:convert';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/attachment_store.dart';
import 'package:agenda/services/attachment_files.dart';

/// Lists sync before their tasks, so an offline task never references a list
/// the server has not received. A metadata conflict requires an explicit choice.
class TaskListStore {
  final TaskDatabase database;
  final String owner;
  final AttachmentFiles? files;
  TaskListStore(this.database, this.owner, {this.files});

  Future<List<TaskListInfo>> all() async =>
      (await (await database.database).query(
        'task_lists',
        where: 'owner_key = ?',
        whereArgs: [owner],
        orderBy: 'archived, pinned DESC, name COLLATE NOCASE, id',
      )).map(TaskListInfo.fromRow).toList();

  Map<String, Object?> _fields(TaskListInfo list) => {
    'name': list.name.trim(),
    'color': list.color,
    'archived': list.archived ? 1 : 0,
  };

  Map<String, Object?> _metadata(TaskListInfo list) => {
    'group_id': list.groupId,
    'group_name': list.groupName,
    'group_archived': list.groupArchived ? 1 : 0,
    'owner_id': list.ownerId,
    'people': jsonEncode(list.people.map((person) => person.toJson()).toList()),
  };

  Future<void> preferences(
    String id, {
    bool? pinned,
    String? notifications,
  }) async {
    if (notifications != null &&
        !['all', 'assigned', 'muted'].contains(notifications)) {
      throw ArgumentError('Invalid notification preference.');
    }
    await (await database.database).transaction((tx) async {
      final count = await tx.update(
        'task_lists',
        {
          if (pinned != null) 'pinned': pinned ? 1 : 0,
          if (notifications != null) 'notifications': notifications,
          'preference_pending': owner == 'local' ? 0 : 1,
        },
        where: 'id = ? AND owner_key = ?',
        whereArgs: [id, owner],
      );
      if (count == 0) throw StateError('This project is no longer available.');
      await tx.rawUpdate(
        'UPDATE task_lists SET preference_revision = preference_revision + 1 WHERE id = ? AND owner_key = ?',
        [id, owner],
      );
    });
  }

  void _validate(TaskListInfo list) {
    if (list.name.trim().isEmpty ||
        list.name.trim().length > 80 ||
        !['teal', 'blue', 'violet', 'amber', 'rose'].contains(list.color)) {
      throw ArgumentError(
        'Choose a list name of up to 80 characters and an available color.',
      );
    }
  }

  Future<void> create(TaskListInfo list) async {
    _validate(list);
    await (await database.database).insert('task_lists', {
      'id': list.id,
      'owner_key': owner,
      ..._fields(list),
      ..._metadata(list),
      'role': list.role,
      'shared': list.shared ? 1 : 0,
      'pinned': list.pinned ? 1 : 0,
      'notifications': list.notifications,
      'sync_pending': owner == 'local' ? 0 : 1,
    });
  }

  Future<void> update(TaskListInfo list) async {
    _validate(list);
    await (await database.database).transaction((tx) async {
      final current = await tx.query(
        'task_lists',
        where: 'id = ? AND owner_key = ?',
        whereArgs: [list.id, owner],
      );
      if (current.isEmpty || !TaskListInfo.fromRow(current.single).canManage) {
        throw StateError('Only the list owner can change list details.');
      }
      final changed = await tx.update(
        'task_lists',
        {..._fields(list), 'sync_pending': owner == 'local' ? 0 : 1},
        where: 'id = ? AND owner_key = ?',
        whereArgs: [list.id, owner],
      );
      if (changed == 0) {
        throw StateError('This list is no longer in this account.');
      }
      await tx.rawUpdate(
        'UPDATE task_lists SET revision = revision + 1 WHERE id = ? AND owner_key = ?',
        [list.id, owner],
      );
    });
  }

  Future<void> resolve(String id, {required bool keepLocal}) async {
    await (await database.database).transaction((tx) async {
      final rows = await tx.query(
        'task_lists',
        where: 'id = ? AND owner_key = ?',
        whereArgs: [id, owner],
      );
      if (rows.isEmpty || rows.single['conflict'] == null) return;
      final remote = TaskListInfo.fromApi(
        jsonDecode(rows.single['conflict'] as String),
      );
      await tx.update(
        'task_lists',
        {
          if (!keepLocal) ..._fields(remote),
          ..._metadata(remote),
          'role': remote.role,
          'shared': remote.shared ? 1 : 0,
          'remote_version': remote.version,
          'conflict': null,
          'sync_pending': keepLocal ? 1 : 0,
          'revision': (rows.single['revision'] as int) + 1,
        },
        where: 'id = ? AND owner_key = ?',
        whereArgs: [id, owner],
      );
    });
  }

  Future<void> sync(ApiClient api, int accountId) async {
    final db = await database.database;
    await refreshAccess(api, accountId);
    final pending = await db.query(
      'task_lists',
      where: 'owner_key = ? AND sync_pending = 1 AND conflict IS NULL',
      whereArgs: [owner],
    );
    for (final row in pending) {
      final sent = TaskListInfo.fromRow(row);
      Map<String, dynamic> remote;
      try {
        remote = Map<String, dynamic>.from(
          await api.request(
            'PUT',
            'lists/${sent.id}/',
            data: sent.toApi(),
            accountId: accountId,
          ),
        );
      } on ApiException catch (error) {
        if (error.status != 409 || error.body?['current'] == null) rethrow;
        remote = Map<String, dynamic>.from(error.body!['current']);
        if (remote['name'] != sent.name ||
            remote['group_id'] != sent.groupId ||
            remote['color'] != sent.color ||
            remote['archived'] != sent.archived) {
          await db.update(
            'task_lists',
            {'conflict': jsonEncode(remote)},
            where: 'id = ? AND owner_key = ?',
            whereArgs: [sent.id, owner],
          );
          continue;
        }
      }
      await db.rawUpdate(
        'UPDATE task_lists SET remote_version = ?, sync_pending = CASE WHEN revision = ? THEN 0 ELSE 1 END WHERE id = ? AND owner_key = ?',
        [remote['version'], row['revision'], sent.id, owner],
      );
    }
    await refreshAccess(api, accountId);
    final preferences = await db.query(
      'task_lists',
      where: 'owner_key = ? AND preference_pending = 1 AND remote_version > 0',
      whereArgs: [owner],
    );
    for (final row in preferences) {
      await api.request(
        'POST',
        'lists/${row['id']}/preferences/',
        accountId: accountId,
        data: {
          'pinned': row['pinned'] == 1,
          'notifications': row['notifications'],
        },
      );
      await db.rawUpdate(
        'UPDATE task_lists SET preference_pending = CASE WHEN preference_revision = ? THEN 0 ELSE 1 END WHERE id = ? AND owner_key = ?',
        [row['preference_revision'], row['id'], owner],
      );
    }
  }

  /// Apply only an explicit complete access snapshot. Network errors or a
  /// partial/malformed response must never delete offline data.
  Future<List<String>> refreshAccess(ApiClient api, int accountId) async {
    final db = await database.database;
    final generation = await db.transaction((tx) async {
      final rows = await tx.query(
        'app_preferences',
        where: 'scope = ?',
        whereArgs: ['sharing:$owner'],
      );
      final next = rows.isEmpty
          ? 1
          : int.parse(rows.single['data'] as String) + 1;
      await tx.rawInsert(
        'INSERT OR REPLACE INTO app_preferences(scope,data) VALUES(?,?)',
        ['sharing:$owner', '$next'],
      );
      return next;
    });
    final result = Map<String, dynamic>.from(
      await api.request('GET', 'lists/access/', accountId: accountId),
    );
    if (result['lists'] is! List) {
      throw const FormatException('Could not confirm shared-list access.');
    }
    final visible = (result['lists'] as List)
        .map((value) => TaskListInfo.fromApi(Map<String, dynamic>.from(value)))
        .toList();
    if (visible.any(
      (list) => !['owner', 'admin', 'editor', 'viewer'].contains(list.role),
    )) {
      throw const FormatException('Invalid list access.');
    }
    final ids = visible.map((list) => list.id).toSet();
    final removedFiles = <String>[];
    await db.transaction((tx) async {
      final latest = await tx.query(
        'app_preferences',
        where: 'scope = ?',
        whereArgs: ['sharing:$owner'],
      );
      if (latest.single['data'] != '$generation') return;
      final cached = await tx.query(
        'task_lists',
        where: 'owner_key = ?',
        whereArgs: [owner],
      );
      for (final row in cached) {
        if (row['remote_version'] == 0 || ids.contains(row['id'])) continue;
        final tasks = await tx.query(
          'tasks',
          where: 'owner_key = ? AND listId = ?',
          whereArgs: [owner, row['id']],
        );
        for (final task in tasks) {
          final files = await tx.query(
            'task_attachments',
            where: 'owner_key = ? AND task_id = ?',
            whereArgs: [owner, task['sync_id']],
          );
          removedFiles.addAll(
            files.map((file) => file['local_path']).whereType<String>(),
          );
          await tx.delete(
            'task_attachments',
            where: 'owner_key = ? AND task_id = ?',
            whereArgs: [owner, task['sync_id']],
          );
          await tx.delete(
            'tasks',
            where: 'owner_key = ? AND id = ?',
            whereArgs: [owner, task['id']],
          );
        }
        await tx.delete(
          'task_lists',
          where: 'owner_key = ? AND id = ?',
          whereArgs: [owner, row['id']],
        );
      }
      for (final list in visible) {
        final rows = await tx.query(
          'task_lists',
          where: 'owner_key = ? AND id = ?',
          whereArgs: [owner, list.id],
        );
        if (rows.isEmpty) {
          await tx.insert('task_lists', {
            'owner_key': owner,
            'id': list.id,
            ..._fields(list),
            ..._metadata(list),
            'pinned': list.pinned ? 1 : 0,
            'notifications': list.notifications,
            'remote_version': list.version,
            'role': list.role,
            'shared': list.shared ? 1 : 0,
          });
        } else {
          await tx.update(
            'task_lists',
            {
              'role': list.role,
              'shared': list.shared ? 1 : 0,
              ..._metadata(list),
              if (rows.single['preference_pending'] != 1) ...{
                'pinned': list.pinned ? 1 : 0,
                'notifications': list.notifications,
              },
              if (!list.canManage ||
                  (rows.single['sync_pending'] == 0 &&
                      (rows.single['remote_version'] as int) <=
                          list.version)) ...{
                ..._fields(list),
                'remote_version': list.version,
                'sync_pending': 0,
                'conflict': null,
              },
            },
            where: 'owner_key = ? AND id = ?',
            whereArgs: [owner, list.id],
          );
        }
      }
    });
    await AttachmentStore(
      database,
      owner,
      files: files,
    ).cleanRemovedPaths(removedFiles);
    return removedFiles;
  }
}
