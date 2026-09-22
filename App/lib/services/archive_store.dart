import 'package:agenda/models/archive_diagnostic.dart';
import 'package:agenda/models/task_archive.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/services/task_database.dart';
import 'package:uuid/uuid.dart';

class ImportResult {
  final int added;
  final int alreadyImported;
  final int listsAdded;
  const ImportResult(this.added, this.alreadyImported, [this.listsAdded = 0]);
}

/// Import receipts and task/list writes share a transaction: retries after a
/// process interruption cannot create a second copy of this file's records.
class ArchiveStore {
  final TaskDatabase database;
  final String owner;
  ArchiveStore(this.database, this.owner);

  Future<String> export() async =>
      (await database.database).transaction((tx) async {
        final rows = await tx.query('tasks',
            where: 'owner_key = ? AND is_deleted = 0',
            whereArgs: [owner],
            orderBy: 'id');
        final lists = await tx.query('task_lists',
            where: 'owner_key = ?', whereArgs: [owner], orderBy: 'id');
        final attachments = await tx.query('task_attachments',
            columns: ['task_id', 'name', 'source_path'],
            where: 'owner_key = ? AND is_deleted = 0',
            whereArgs: [owner]);
        final names = <int, List<String>>{};
        for (final row in rows) {
          final linked = attachments
              .where((file) => file['task_id'] == row['sync_id'])
              .toList();
          final sources = linked.map((file) => file['source_path']).toSet();
          names[row['id'] as int] = [
            for (final field in ['filePaths', 'imagePaths'])
              for (final path in (row[field] as String? ?? '').split('|'))
                if (path.isNotEmpty && !sources.contains(path))
                  path.replaceAll('\\', '/').split('/').last,
            ...linked.map((file) => file['name'] as String),
          ];
        }
        return TaskArchive.encode(
            rows, lists.map(TaskListInfo.fromRow).toList(),
            attachmentNames: names);
      });

  Future<Set<String>> imported(String archiveId) async =>
      (await (await database.database).query('archive_imports',
              columns: ['source_id'],
              where: 'owner_key = ? AND archive_id = ? AND kind = ?',
              whereArgs: [owner, archiveId, 'task']))
          .map((row) => row['source_id'] as String)
          .toSet();

  Future<ImportResult> import(TaskArchive archive, Set<String> selected) async {
    final candidates = archive.tasks
        .where((row) =>
            selected.contains(row.sourceId) &&
            row.error == null &&
            row.task != null)
        .toList();
    if (candidates.map((row) => row.sourceId).toSet().length !=
        selected.length) {
      throw ArgumentError('Choose valid tasks from this preview.');
    }
    // Validate before opening the write transaction, so malformed records never
    // leave a partially imported list or task behind.
    for (final row in candidates) {
      TaskArchive.validatedTask(row.task!.toApi());
      if (row.task!.listId != null &&
          !archive.lists.any((list) => list.id == row.task!.listId)) {
        throw const ArchiveDiagnostic(ArchiveCode.missingList);
      }
    }
    return (await database.database).transaction((tx) async {
      final receipts = await tx.query('archive_imports',
          where: 'owner_key = ? AND archive_id = ?',
          whereArgs: [owner, archive.id]);
      final done = receipts
          .where((row) => row['kind'] == 'task')
          .map((row) => row['source_id'] as String)
          .toSet();
      final mappings = {
        for (final row in receipts.where((row) => row['kind'] == 'list'))
          row['source_id'] as String: row['target_id'] as String
      };
      final pending =
          candidates.where((row) => !done.contains(row.sourceId)).toList();
      final needed = archive.lists.map((list) => list.id).toSet();
      var listsAdded = 0;
      for (final sourceId in needed) {
        if (mappings.containsKey(sourceId)) {
          final exists = await tx.query('task_lists',
              columns: ['id'],
              where: 'owner_key = ? AND id = ?',
              whereArgs: [owner, mappings[sourceId]]);
          if (exists.isNotEmpty) continue;
        }
        final source =
            archive.lists.where((list) => list.id == sourceId).firstOrNull;
        if (source == null) {
          throw const ArchiveDiagnostic(ArchiveCode.missingList);
        }
        final targetId = mappings[sourceId] ?? const Uuid().v4();
        mappings[sourceId] = targetId;
        await tx.insert('task_lists', {
          'owner_key': owner,
          'id': targetId,
          'name': source.name,
          'color': source.color,
          'archived': source.archived ? 1 : 0,
          'sync_pending': owner == 'local' ? 0 : 1
        });
        listsAdded++;
        await tx.rawInsert(
            'INSERT OR REPLACE INTO archive_imports(owner_key, archive_id, source_id, kind, target_id) VALUES(?,?,?,?,?)',
            [owner, archive.id, sourceId, 'list', targetId]);
      }
      for (final row in pending) {
        final task = row.task!.copyWith(
            listId:
                row.task!.listId == null ? null : mappings[row.task!.listId]);
        final values = task.toMap()..remove('id');
        final target = const Uuid().v4();
        await tx.insert('tasks', {
          ...values,
          'owner_key': owner,
          'sync_id': target,
          'sync_pending': owner == 'local' ? 0 : 1
        });
        await tx.insert('archive_imports', {
          'owner_key': owner,
          'archive_id': archive.id,
          'source_id': row.sourceId,
          'kind': 'task',
          'target_id': target
        });
      }
      return ImportResult(
          pending.length, candidates.length - pending.length, listsAdded);
    });
  }
}
