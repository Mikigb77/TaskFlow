import 'dart:io';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_attachment.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/attachment_files.dart';
import 'package:agenda/services/task_database.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// File transfers have their own durable identities and never advance the
/// task's content version. A failed transfer cannot undo a saved task.
class AttachmentStore {
  AttachmentStore(this.database, this.owner, {AttachmentFiles? files})
      : files = files ?? AttachmentFiles();
  final TaskDatabase database;
  final String owner;
  final AttachmentFiles files;
  static final _running = <(TaskDatabase, String), Future<void>>{};

  Future<List<TaskAttachment>> forTask(int taskId) async {
    final db = await database.database;
    final tasks = await db.query('tasks',
        columns: ['sync_id'],
        where: 'owner_key = ? AND id = ? AND is_deleted = 0',
        whereArgs: [owner, taskId]);
    if (tasks.isEmpty) return [];
    return (await db.query('task_attachments',
            where:
                'owner_key = ? AND task_id = ? AND (is_deleted = 0 OR delete_pending = 1)',
            whereArgs: [owner, tasks.single['sync_id']],
            orderBy: 'rowid'))
        .map(TaskAttachment.fromMap)
        .toList();
  }

  Future<TaskAttachment?> _get(String id) async {
    final rows = await (await database.database).query('task_attachments',
        where: 'owner_key = ? AND id = ?', whereArgs: [owner, id]);
    return rows.isEmpty ? null : TaskAttachment.fromMap(rows.single);
  }

  Future<void> _update(String id, Map<String, Object?> values) async =>
      (await database.database).update('task_attachments', values,
          where: 'owner_key = ? AND id = ?', whereArgs: [owner, id]);

  Future<void> cleanRemovedPaths(Iterable<String> paths) async {
    for (final path in paths.toSet()) {
      await _removeUnreferenced(path);
    }
  }

  /// Explicitly back up an older device-only attachment. The original file is
  /// never modified; the private snapshot is the input for every retry.
  Future<void> enqueue(int taskId, String source) async {
    if (owner == 'local') throw StateError('Sign in to upload attachments.');
    final snapshot = await files.retain(source);
    try {
      final size = await File(snapshot).length();
      final hash = await files.checksum(snapshot);
      await (await database.database).transaction((tx) async {
        final rows = await tx.query('tasks',
            where: 'owner_key = ? AND id = ? AND is_deleted = 0',
            whereArgs: [owner, taskId]);
        if (rows.isEmpty) throw StateError('This task is no longer available.');
        final task = Task.fromMap(rows.single);
        await TaskDatabase.validateList(tx, task, owner);
        if (![...task.filePaths, ...task.imagePaths].contains(source)) {
          throw StateError('This attachment was removed.');
        }
        await tx.rawInsert('''INSERT OR IGNORE INTO task_attachments
        (owner_key,id,task_id,name,size,sha256,local_path,source_path,upload_pending)
        VALUES(?,?,?,?,?,?,?,?,1)''', [
          owner,
          const Uuid().v4(),
          rows.single['sync_id'],
          files.safeName(source),
          size,
          hash,
          snapshot,
          source
        ]);
      });
    } finally {
      await _removeUnreferenced(snapshot);
    }
  }

  Future<void> remove(String id) async {
    await (await database.database).transaction((tx) async {
      final rows = await tx.query('task_attachments',
          where: 'owner_key = ? AND id = ?', whereArgs: [owner, id]);
      if (rows.isEmpty) {
        throw StateError('This attachment is no longer available.');
      }
      final item = TaskAttachment.fromMap(rows.single);
      final tasks = await tx.query('tasks',
          where: 'owner_key = ? AND sync_id = ?',
          whereArgs: [owner, item.taskId]);
      if (tasks.isEmpty) throw StateError('This task is no longer available.');
      await TaskDatabase.validateList(tx, Task.fromMap(tasks.single), owner);
      await tx.update('task_attachments',
          {'is_deleted': 1, 'delete_pending': 1, 'error': null},
          where: 'owner_key = ? AND id = ?', whereArgs: [owner, id]);
      await _forgetSource(tx, item);
      // A removal may make room: the next sync sends refused files again.
      await _releaseRefused(tx);
    });
  }

  static const _refused = 'error IN (?, ?)';
  static const _refusedArgs = [
    TaskAttachment.storageFull,
    TaskAttachment.storageFullShared
  ];

  Future<void> _releaseRefused(DatabaseExecutor tx, [String? id]) =>
      tx.update('task_attachments', {'error': null},
          where: 'owner_key = ? AND $_refused${id == null ? '' : ' AND id = ?'}',
          whereArgs: [owner, ..._refusedArgs, if (id != null) id]);

  /// Sync again an upload the server refused for a full file space: one file
  /// on its Retry, or every one when Pro turns on.
  Future<void> retryRefused([String? id]) async =>
      _releaseRefused(await database.database, id);

  Future<void> removeLocal(int taskId, String path) async {
    await (await database.database).transaction((tx) async {
      final rows = await tx.query('tasks',
          where: 'owner_key = ? AND id = ? AND is_deleted = 0',
          whereArgs: [owner, taskId]);
      if (rows.isEmpty) return;
      final task = Task.fromMap(rows.single);
      final paths = task
          .copyWith(
              filePaths: task.filePaths.where((p) => p != path).toList(),
              imagePaths: task.imagePaths.where((p) => p != path).toList())
          .toMap();
      // These paths are local metadata, not a change to the server's task.
      await tx.update('tasks',
          {'filePaths': paths['filePaths'], 'imagePaths': paths['imagePaths']},
          where: 'owner_key = ? AND id = ?', whereArgs: [owner, taskId]);
    });
    await _removeUnreferenced(path);
  }

  Future<void> _forgetSource(DatabaseExecutor tx, TaskAttachment item) async {
    final source = item.sourcePath;
    if (source == null) return;
    final newer = await tx.query('task_attachments',
        columns: ['id'],
        where:
            'owner_key = ? AND task_id = ? AND source_path = ? AND id != ? AND is_deleted = 0',
        whereArgs: [owner, item.taskId, source, item.id]);
    if (newer.isNotEmpty) return;
    final rows = await tx.query('tasks',
        where: 'owner_key = ? AND sync_id = ?',
        whereArgs: [owner, item.taskId]);
    for (final row in rows) {
      final task = Task.fromMap(row);
      final paths = task
          .copyWith(
              filePaths: task.filePaths.where((p) => p != source).toList(),
              imagePaths: task.imagePaths.where((p) => p != source).toList())
          .toMap();
      await tx.update('tasks',
          {'filePaths': paths['filePaths'], 'imagePaths': paths['imagePaths']},
          where: 'owner_key = ? AND id = ?', whereArgs: [owner, row['id']]);
    }
  }

  Future<void> _removeUnreferenced(String? path) async {
    if (path == null) return;
    final db = await database.database;
    final rows = await db.query('tasks',
        columns: ['filePaths', 'imagePaths'], where: 'is_deleted = 0');
    if (rows.any((row) => ['filePaths', 'imagePaths']
        .any((key) => (row[key] as String? ?? '').split('|').contains(path)))) {
      return;
    }
    final referenced = await db.query('task_attachments',
        columns: ['id'],
        where:
            '(is_deleted = 0 OR delete_pending = 1) AND (local_path = ? OR source_path = ?)',
        whereArgs: [path, path],
        limit: 1);
    if (referenced.isNotEmpty) return;
    try {
      await files.removeOwned(path);
    } on FileSystemException {/* Retry on a later sync. */}
  }

  String _error(Object error) {
    // A full file space is kept as a token, never the server's English text.
    if (_storageFull(error)) {
      final shared = (error as ApiException).body!['shared'] == true;
      return shared
          ? TaskAttachment.storageFullShared
          : TaskAttachment.storageFull;
    }
    return error is ApiException
        ? error.message
        : error is FormatException
            ? error.message
            : 'The file could not be transferred. Your task is saved. Check the file and retry.';
  }

  static bool _storageFull(Object error) =>
      error is ApiException &&
      error.status == 400 &&
      error.body?['code'] == 'storage_full';

  Future<void> sync(ApiClient api, int accountId) {
    final key = (database, owner);
    return _running[key] ??= _sync(api, accountId).whenComplete(() {
      _running.remove(key);
    });
  }

  Future<void> _sync(ApiClient api, int accountId) async {
    if (owner == 'local') return;
    final db = await database.database;
    await db.rawUpdate(
        '''UPDATE task_attachments SET is_deleted = 1, delete_pending = 1
      WHERE owner_key = ? AND is_deleted = 0 AND task_id IN
      (SELECT sync_id FROM tasks WHERE owner_key = ? AND is_deleted = 1)''',
        [owner, owner]);
    // Removals go first, so the space they free is there for the uploads.
    await _syncRemovals(db, api, accountId);
    // An upload refused for a full file space waits for its Retry, a
    // removal, or Pro, rather than re-sending up to 6 MiB on every sync.
    final queued = await db.query('task_attachments',
        where:
            'owner_key = ? AND upload_pending = 1 AND is_deleted = 0 AND (error IS NULL OR NOT $_refused)',
        whereArgs: [owner, ..._refusedArgs]);
    var uploaded = 0;
    for (final row in queued) {
      var item = await _get(row['id'] as String);
      if (item == null || item.deleted) continue;
      final tasks = await db.query('tasks',
          columns: ['id'],
          where:
              'owner_key = ? AND sync_id = ? AND is_deleted = 0 AND remote_version > 0',
          whereArgs: [owner, item.taskId]);
      if (tasks.isEmpty) continue;
      try {
        final snapshot = await files.retain(item.localPath!);
        final size = await File(snapshot).length();
        final hash = await files.checksum(snapshot);
        if (item.size != 0 && (item.size != size || item.sha256 != hash)) {
          throw const FormatException(
              'This file changed after it was attached. Remove it and attach it again.');
        }
        await _update(item.id, {
          'local_path': snapshot,
          'size': size,
          'sha256': hash,
          'name': files.safeName(item.name)
        });
        item = (await _get(item.id))!;
        if (item.deleted) continue;
        final remote = TaskAttachment.fromApi(await api.uploadAttachment(
            id: item.id,
            taskId: item.taskId,
            name: item.name,
            filePath: snapshot,
            accountId: accountId));
        if (remote.id != item.id ||
            remote.taskId != item.taskId ||
            remote.sha256 != hash ||
            remote.size != size ||
            remote.deleted) {
          throw const FormatException(
              'The server did not confirm this file. Retry the upload.');
        }
        // A removal during upload must survive the acknowledgement.
        await _update(item.id, {
          'remote': 1,
          'name': remote.name,
          'upload_pending': 0,
          'error': null
        });
        uploaded++;
      } catch (error) {
        await _update(row['id'] as String, {'error': _error(error)});
        if (_storageFull(error)) {
          // A refusal of the user's own space carries its usage.
          await api.rememberStorage((error as ApiException).body!['storage'],
              accountId: accountId);
        }
        if (error is ApiException && error.status == 401) rethrow;
      }
    }
    // A file removed while it uploaded is removed from the server too.
    if (queued.isNotEmpty) await _syncRemovals(db, api, accountId);
    await _pullRemote(db, api, accountId);
    // The uploads took space: refresh the usage line once. This can't loop:
    // an account update doesn't rebuild the repository or start a sync.
    final account = api.account;
    if (uploaded > 0 &&
        account?.id == accountId &&
        account!.storage != null &&
        !account.complimentaryPro) {
      try {
        await api.refreshStorage(accountId: accountId);
      } catch (_) {}
    }
  }

  Future<void> _syncRemovals(
      Database db, ApiClient api, int accountId) async {
    final deleted = await db.query('task_attachments',
        where: 'owner_key = ? AND delete_pending = 1', whereArgs: [owner]);
    for (final row in deleted) {
      final item = TaskAttachment.fromMap(row);
      try {
        try {
          await api.request('DELETE', 'attachments/${item.id}/',
              accountId: accountId);
        } on ApiException catch (error) {
          if (error.status != 404) rethrow;
        }
        await db.transaction((tx) async {
          await tx.update('task_attachments',
              {'delete_pending': 0, 'upload_pending': 0, 'error': null},
              where: 'owner_key = ? AND id = ?', whereArgs: [owner, item.id]);
          await _forgetSource(tx, item);
        });
      } catch (error) {
        await _update(item.id, {'error': _error(error)});
        if (error is ApiException && error.status == 401) rethrow;
      }
    }
  }

  Future<void> _pullRemote(Database db, ApiClient api, int accountId) async {
    var page = 1;
    while (true) {
      final result = Map<String, dynamic>.from(await api.request(
          'GET', 'attachments/?include_deleted=true&page=$page',
          accountId: accountId));
      for (final data in result['results'] as List) {
        final remote = TaskAttachment.fromApi(Map<String, dynamic>.from(data));
        await db.transaction((tx) async {
          final task = await tx.query('tasks',
              columns: ['id'],
              where: 'owner_key = ? AND sync_id = ?',
              whereArgs: [owner, remote.taskId]);
          if (task.isEmpty) return;
          final rows = await tx.query('task_attachments',
              where: 'owner_key = ? AND id = ?', whereArgs: [owner, remote.id]);
          if (rows.isEmpty) {
            await tx.insert(
                'task_attachments', {'owner_key': owner, ...remote.toMap()});
            return;
          }
          final local = TaskAttachment.fromMap(rows.single);
          if (remote.deleted) {
            await tx.update(
                'task_attachments',
                {
                  'is_deleted': 1,
                  'remote': 1,
                  'upload_pending': 0,
                  'delete_pending': 0,
                  'error': null
                },
                where: 'owner_key = ? AND id = ?',
                whereArgs: [owner, local.id]);
            await _forgetSource(tx, local);
          } else if (!local.deleted &&
              local.taskId == remote.taskId &&
              local.size == remote.size &&
              local.sha256 == remote.sha256) {
            await tx.update(
                'task_attachments',
                {
                  'remote': 1,
                  'name': remote.name,
                  'upload_pending': 0,
                  'error': null
                },
                where: 'owner_key = ? AND id = ?',
                whereArgs: [owner, local.id]);
          }
        });
      }
      if (result['next'] == null) break;
      page++;
    }
    for (final row in await db.query('task_attachments',
        where: 'owner_key = ? AND is_deleted = 1 AND delete_pending = 0',
        whereArgs: [owner])) {
      await _removeUnreferenced(row['local_path'] as String?);
      await _removeUnreferenced(row['source_path'] as String?);
    }
  }

  Future<String> download(String id, ApiClient api, int accountId) async {
    final item = await _get(id);
    if (item == null || item.deleted || !item.remote) {
      throw StateError('This attachment is no longer available.');
    }
    try {
      final bytes = await api.downloadAttachment(id, accountId: accountId);
      final path = await files.downloaded(owner, item, bytes);
      if (api.account?.id != accountId ||
          owner != '${api.baseUrl}/users/$accountId') {
        await _removeUnreferenced(path);
        throw ApiException(
            401, 'Your account changed. Open the attachment again.');
      }
      final changed = await (await database.database).update(
          'task_attachments', {'local_path': path, 'error': null},
          where: 'owner_key = ? AND id = ? AND is_deleted = 0',
          whereArgs: [owner, id]);
      if (changed == 0) {
        await _removeUnreferenced(path);
        throw StateError('This attachment was removed while downloading.');
      }
      return path;
    } catch (error) {
      await _update(id, {'error': _error(error)});
      rethrow;
    }
  }
}
