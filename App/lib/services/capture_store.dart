import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:collection/collection.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/services/task_database.dart';

final captureOwnerProvider = Provider<String>((ref) {
  final accountId = ref.watch(authProvider.select((s) => s.account?.id));
  return accountId == null
      ? 'local'
      : '${ref.watch(apiClientProvider).baseUrl}/users/$accountId';
});
final captureStoreProvider = Provider((ref) => CaptureStore(TaskDatabase()));
final pendingCapturesProvider = FutureProvider<List<CaptureSession>>(
  (ref) =>
      ref.watch(captureStoreProvider).pending(ref.watch(captureOwnerProvider)),
);

/// Capture metadata and task insertion share a database transaction. Audio stays
/// in app-private durable storage until a successful save or explicit discard.
class CaptureStore {
  final TaskDatabase database;
  final Directory? directory;
  CaptureStore(this.database, {this.directory});

  Future<Directory> _directory() async {
    final root =
        directory ??
        Directory(
          p.join((await getApplicationSupportDirectory()).path, 'captures'),
        );
    return root.create(recursive: true);
  }

  Future<CaptureSession> create(
    String ownerKey,
    String timezone, {
    String text = '',
    DateTime? now,
    bool audio = false,
    String kind = 'task',
    String? projectId,
    String? source,
    DateTime? day,
    String? id,
    String? language,
  }) async {
    if (!['task', 'note'].contains(kind)) {
      throw ArgumentError('Invalid capture type.');
    }
    id ??= const Uuid().v4();
    final session = CaptureSession(
      id: id,
      ownerKey: ownerKey,
      capturedAt: (now ?? DateTime.now()).toUtc(),
      timezone: timezone,
      kind: kind,
      projectId: projectId,
      text: text,
      audioPath: audio ? p.join((await _directory()).path, '$id.wav') : null,
      source: source,
      day: day,
      language: language,
    );
    await (await database.database).insert('captures', {
      'id': id,
      'owner_key': ownerKey,
      'status': session.status,
      'captured_at': session.capturedAt.toIso8601String(),
      'data': jsonEncode(session.toJson()),
    });
    return session;
  }

  Future<String> audioPathFor(CaptureSession session) =>
      audioPathForId(session.id);

  /// Where a capture's audio goes. The recorder writes there before the
  /// capture exists: [create] with the same id once audio has arrived.
  Future<String> audioPathForId(String id) async =>
      p.join((await _directory()).path, '$id.wav');

  /// Deletes audio that arrived for no capture.
  Future<void> removeAudioFile(String id) async {
    final file = File(await audioPathForId(id));
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      /* Nothing refers to it. */
    }
  }

  /// A capture with no words, no audio and no drafts holds nothing to keep.
  static bool isEmpty(CaptureSession session) =>
      session.text.trim().isEmpty &&
      session.transcript.trim().isEmpty &&
      session.audioPath == null &&
      session.drafts.isEmpty;

  /// Shared text only: it brings words. Android acknowledges a share only
  /// after this idempotent write. A lost acknowledgement cannot duplicate a
  /// capture or move it to another account.
  Future<CaptureSession?> acceptEntry(
    String id,
    String ownerKey,
    String timezone, {
    required String text,
    required DateTime capturedAt,
  }) async {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id) ||
        text.trim().isEmpty ||
        text.length > 4000) {
      throw ArgumentError('Invalid external capture');
    }
    final session = CaptureSession(
      id: id,
      ownerKey: ownerKey,
      timezone: timezone,
      text: text,
      capturedAt: capturedAt.toUtc(),
      source: 'typed',
    );
    return (await database.database).transaction((tx) async {
      await tx.insert('captures', {
        'id': id,
        'owner_key': ownerKey,
        'status': session.status,
        'captured_at': session.capturedAt.toIso8601String(),
        'data': jsonEncode(session.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final rows = await tx.query(
        'captures',
        where: 'id = ? AND owner_key = ?',
        whereArgs: [id, ownerKey],
      );
      return rows.isEmpty ? null : _decode(rows.single);
    });
  }

  Future<CaptureSession?> read(String id, String ownerKey) async {
    final rows = await (await database.database).query(
      'captures',
      where: 'id = ? AND owner_key = ?',
      whereArgs: [id, ownerKey],
    );
    return rows.isEmpty ? null : _decode(rows.single);
  }

  CaptureSession _decode(Map<String, Object?> row) =>
      CaptureSession.fromJson(jsonDecode(row['data'] as String));

  Future<List<CaptureSession>> pending(String ownerKey) async {
    final rows = await (await database.database).query(
      'captures',
      where: "owner_key = ? AND status NOT IN ('saved','discarded')",
      whereArgs: [ownerKey],
      orderBy: 'captured_at DESC',
    );
    final sessions = rows.map(_decode).toList();
    // Opened and left without a word: nothing to come back to.
    final empty = sessions.where(isEmpty).map((s) => s.id).toList();
    if (empty.isNotEmpty) {
      await (await database.database).delete(
        'captures',
        where:
            "owner_key = ? AND status NOT IN ('saved','discarded') AND id IN (${List.filled(empty.length, '?').join(',')})",
        whereArgs: [ownerKey, ...empty],
      );
    }
    return sessions.where((s) => !isEmpty(s)).toList();
  }

  Future<void> update(CaptureSession session) async {
    if (session.terminal) {
      throw StateError('Use save or discard to finish a capture.');
    }
    final changed = await (await database.database).update(
      'captures',
      {'data': jsonEncode(session.toJson()), 'status': session.status},
      where: "id = ? AND owner_key = ? AND status NOT IN ('saved','discarded')",
      whereArgs: [session.id, session.ownerKey],
    );
    if (changed != 1) throw StateError('This capture is no longer available.');
  }

  /// Saved draft IDs remain in the journal even if a task is later deleted.
  /// Repeating Save after a lost response cannot insert the tasks again.
  Future<CaptureSession> saveReady(
    String id,
    String ownerKey,
    Set<String> draftIds,
  ) async {
    final result = await (await database.database).transaction((tx) async {
      final rows = await tx.query(
        'captures',
        where: 'id = ? AND owner_key = ?',
        whereArgs: [id, ownerKey],
      );
      if (rows.isEmpty) throw StateError('Capture not found in this account.');
      final session = _decode(rows.single);
      if (session.terminal) return session;
      final updated = <CaptureDraft>[];
      for (final draft in session.drafts) {
        if (!draftIds.contains(draft.id) || !draft.pending) {
          updated.add(draft);
          continue;
        }
        if (!draft.ready) {
          throw StateError('Confirm the uncertain details first.');
        }
        final task = await TaskDatabase.normalizeResponsibility(
          tx,
          draft.task,
          ownerKey,
        );
        final values = task.toMap()..remove('id');
        final syncId = const Uuid().v4();
        final taskId = await tx.insert('tasks', {
          ...values,
          'owner_key': ownerKey,
          'sync_id': syncId,
          'sync_pending': ownerKey == 'local' ? 0 : 1,
        });
        await TaskDatabase.stageAttachments(tx, ownerKey, syncId, task);
        updated.add(draft.copyWith(task: task, savedTaskId: taskId));
      }
      final completed = updated.isNotEmpty && updated.every((d) => !d.pending);
      final next = session.copyWith(
        drafts: updated,
        status: completed ? 'saved' : 'ready',
      );
      // Keep only task identities after completion, not sensitive source words.
      final retained = completed ? _withoutInput(next) : next;
      await tx.update(
        'captures',
        {'data': jsonEncode(retained.toJson()), 'status': retained.status},
        where: 'id = ? AND owner_key = ?',
        whereArgs: [id, ownerKey],
      );
      return retained;
    });
    if (result.terminal) await _removeAudio(result);
    return result;
  }

  CaptureSession _withoutInput(CaptureSession session) => CaptureSession(
    id: session.id,
    ownerKey: session.ownerKey,
    capturedAt: session.capturedAt,
    timezone: session.timezone,
    kind: session.kind,
    audioPath: session.audioPath,
    audioFormat: session.audioFormat,
    status: session.status,
    drafts: session.drafts
        .map(
          (d) => CaptureDraft(
            id: d.id,
            task: Task(title: '', priority: 1),
            savedTaskId: d.savedTaskId,
            removed: d.removed,
          ),
        )
        .toList(),
  );

  /// Undo only this save, atomically, without deleting a task changed since it
  /// was created. Cloud deletions remain queued for the ordinary sync protocol.
  Future<CaptureSession?> undoSave(
    CaptureSession before,
    Map<String, int> savedIds,
  ) async => (await database.database).transaction((tx) async {
    final rows = await tx.query(
      'captures',
      where: 'id = ? AND owner_key = ?',
      whereArgs: [before.id, before.ownerKey],
    );
    if (rows.isEmpty || savedIds.isEmpty) return null;
    final current = _decode(rows.single);
    for (final entry in savedIds.entries) {
      if (!current.drafts.any(
        (d) => d.id == entry.key && d.savedTaskId == entry.value,
      )) {
        return null;
      }
      final tasks = await tx.query(
        'tasks',
        where: 'id = ? AND owner_key = ? AND is_deleted = 0',
        whereArgs: [entry.value, before.ownerKey],
      );
      if (tasks.length != 1 || tasks.single['revision'] != 0) return null;
      final prior = before.drafts.firstWhere((d) => d.id == entry.key);
      final expected =
          (await TaskDatabase.normalizeResponsibility(
              tx,
              prior.task,
              before.ownerKey,
            )).toMap()
            ..remove('id')
            ..remove('createdBy')
            ..remove('createdByName');
      final actual = Task.fromMap(tasks.single).toMap()
        ..remove('id')
        ..remove('createdBy')
        ..remove('createdByName');
      if (!const DeepCollectionEquality().equals(expected, actual)) return null;
      await TaskDatabase.validateList(
        tx,
        Task.fromMap(tasks.single),
        before.ownerKey,
      );
    }
    for (final id in savedIds.values) {
      if (before.ownerKey == 'local') {
        await tx.delete(
          'tasks',
          where: 'id = ? AND owner_key = ?',
          whereArgs: [id, before.ownerKey],
        );
      } else {
        await tx.rawUpdate(
          'UPDATE tasks SET is_deleted = 1, sync_pending = 1, revision = revision + 1 WHERE id = ? AND owner_key = ?',
          [id, before.ownerKey],
        );
      }
    }
    final restored = CaptureSession(
      id: before.id,
      ownerKey: before.ownerKey,
      capturedAt: before.capturedAt,
      timezone: before.timezone,
      projectId: before.projectId,
      kind: before.kind,
      text: before.text,
      transcript: before.transcript,
      source: before.source,
      day: before.day,
      language: before.language,
      status: 'ready',
      drafts: [
        for (final draft in current.drafts)
          if (savedIds.containsKey(draft.id))
            before.drafts
                .firstWhere((d) => d.id == draft.id)
                .copyWith(clearSavedTaskId: true)
          else
            draft,
      ],
    );
    await tx.update(
      'captures',
      {'data': jsonEncode(restored.toJson()), 'status': restored.status},
      where: 'id = ? AND owner_key = ?',
      whereArgs: [before.id, before.ownerKey],
    );
    return restored;
  });

  Future<void> discard(String id, String ownerKey) async {
    final discarded = await (await database.database).transaction((tx) async {
      final rows = await tx.query(
        'captures',
        where: 'id = ? AND owner_key = ?',
        whereArgs: [id, ownerKey],
      );
      if (rows.isEmpty) throw StateError('Capture not found in this account.');
      final session = _decode(rows.single);
      if (session.terminal) return session;
      final next = _withoutInput(
        session.copyWith(status: 'discarded', drafts: []),
      );
      await tx.update(
        'captures',
        {'status': 'discarded', 'data': jsonEncode(next.toJson())},
        where: 'id = ? AND owner_key = ?',
        whereArgs: [id, ownerKey],
      );
      return next;
    });
    await _removeAudio(discarded);
  }

  Future<void> _removeAudio(CaptureSession session) async {
    if (session.audioPath == null) return;
    final expected = p.join((await _directory()).path, '${session.id}.wav');
    if (p.normalize(session.audioPath!) != p.normalize(expected)) return;
    try {
      final file = File(expected);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      /* Retried during the next recovery sweep. */
    }
  }

  Future<void> cleanFinished(String ownerKey) async {
    final rows = await (await database.database).query(
      'captures',
      where: "owner_key = ? AND status IN ('saved','discarded')",
      whereArgs: [ownerKey],
    );
    for (final row in rows) {
      await _removeAudio(_decode(row));
    }
  }

  /// Finalize retained PCM audio without rewriting its samples. Android's WAV
  /// writer leaves 44 zero bytes until normal Stop: reconstruct those only when
  /// the capture journal identifies our exact recorder format. Unknown formats
  /// and old journals without that evidence are left intact.
  static Future<void> recoverWav(String path, {String? audioFormat}) async {
    final file = File(path);
    if (!await file.exists() || await file.length() < 44) return;
    final handle = await file.open(mode: FileMode.append);
    try {
      final bytes = await file.readAsBytes();
      if (audioFormat == CaptureSession.androidPcmWav &&
          bytes.length > 44 &&
          bytes.take(44).every((value) => value == 0)) {
        if ((bytes.length - 44).isOdd) {
          throw const FormatException('The retained PCM frame is incomplete.');
        }
        final header = Uint8List(44);
        header.setRange(0, 4, ascii.encode('RIFF'));
        header.setRange(8, 12, ascii.encode('WAVE'));
        header.setRange(12, 16, ascii.encode('fmt '));
        header.setRange(36, 40, ascii.encode('data'));
        ByteData.sublistView(header)
          ..setUint32(4, bytes.length - 8, Endian.little)
          ..setUint32(16, 16, Endian.little)
          ..setUint16(20, 1, Endian.little)
          ..setUint16(22, 1, Endian.little)
          ..setUint32(24, 16000, Endian.little)
          ..setUint32(28, 32000, Endian.little)
          ..setUint16(32, 2, Endian.little)
          ..setUint16(34, 16, Endian.little)
          ..setUint32(40, bytes.length - 44, Endian.little);
        await handle.setPosition(0);
        await handle.writeFrom(header);
        await handle.flush();
        return;
      }
      if (ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) != 'WAVE') {
        return;
      }
      final data = ByteData.sublistView(bytes);
      var offset = 12;
      var pcm = false;
      while (offset + 8 <= bytes.length) {
        final chunk = ascii.decode(
          bytes.sublist(offset, offset + 4),
          allowInvalid: true,
        );
        final size = data.getUint32(offset + 4, Endian.little);
        if (chunk == 'fmt ' && offset + 24 <= bytes.length) {
          pcm = data.getUint16(offset + 8, Endian.little) == 1;
        }
        if (chunk == 'data' && pcm) {
          final actual = bytes.length - offset - 8;
          if (size >= actual &&
              data.getUint32(4, Endian.little) == bytes.length - 8) {
            return;
          }
          final length = ByteData(4)
            ..setUint32(0, bytes.length - 8, Endian.little);
          await handle.setPosition(4);
          await handle.writeFrom(length.buffer.asUint8List());
          length.setUint32(0, actual, Endian.little);
          await handle.setPosition(offset + 4);
          await handle.writeFrom(length.buffer.asUint8List());
          await handle.flush();
          return;
        }
        offset += 8 + size + (size.isOdd ? 1 : 0);
      }
    } finally {
      await handle.close();
    }
  }
}
