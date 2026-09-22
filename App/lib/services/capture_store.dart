import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/services/task_database.dart';

final captureOwnerProvider = Provider<String>((ref) {
  final account = ref.watch(authProvider.select((s) => s.account));
  return account == null
      ? 'local'
      : '${ref.watch(apiClientProvider).baseUrl}/users/${account.id}';
});
final captureStoreProvider = Provider((ref) => CaptureStore(TaskDatabase()));
final pendingCapturesProvider = FutureProvider<List<CaptureSession>>((ref) =>
    ref.watch(captureStoreProvider).pending(ref.watch(captureOwnerProvider)));

/// Capture metadata and task insertion share a database transaction. Audio stays
/// in app-private durable storage until a successful save or explicit discard.
class CaptureStore {
  final TaskDatabase database;
  final Directory? directory;
  CaptureStore(this.database, {this.directory});

  Future<Directory> _directory() async {
    final root = directory ??
        Directory(
            p.join((await getApplicationSupportDirectory()).path, 'captures'));
    return root.create(recursive: true);
  }

  Future<CaptureSession> create(String ownerKey, String timezone,
      {String text = '', DateTime? now, bool audio = false}) async {
    final id = const Uuid().v4();
    final session = CaptureSession(
        id: id,
        ownerKey: ownerKey,
        capturedAt: (now ?? DateTime.now()).toUtc(),
        timezone: timezone,
        text: text,
        audioPath: audio ? p.join((await _directory()).path, '$id.wav') : null);
    await (await database.database).insert('captures', {
      'id': id,
      'owner_key': ownerKey,
      'status': session.status,
      'captured_at': session.capturedAt.toIso8601String(),
      'data': jsonEncode(session.toJson())
    });
    return session;
  }

  Future<String> audioPathFor(CaptureSession session) async =>
      p.join((await _directory()).path, '${session.id}.wav');

  Future<CaptureSession?> read(String id, String ownerKey) async {
    final rows = await (await database.database).query('captures',
        where: 'id = ? AND owner_key = ?', whereArgs: [id, ownerKey]);
    return rows.isEmpty ? null : _decode(rows.single);
  }

  CaptureSession _decode(Map<String, Object?> row) =>
      CaptureSession.fromJson(jsonDecode(row['data'] as String));

  Future<List<CaptureSession>> pending(String ownerKey) async {
    final rows = await (await database.database).query('captures',
        where: "owner_key = ? AND status NOT IN ('saved','discarded')",
        whereArgs: [ownerKey],
        orderBy: 'captured_at DESC');
    return rows.map(_decode).toList();
  }

  Future<void> update(CaptureSession session) async {
    if (session.terminal) {
      throw StateError('Use save or discard to finish a capture.');
    }
    final changed = await (await database.database).update('captures',
        {'data': jsonEncode(session.toJson()), 'status': session.status},
        where:
            "id = ? AND owner_key = ? AND status NOT IN ('saved','discarded')",
        whereArgs: [session.id, session.ownerKey]);
    if (changed != 1) throw StateError('This capture is no longer available.');
  }

  /// Saved draft IDs remain in the journal even if a task is later deleted.
  /// Repeating Save after a lost response cannot insert the tasks again.
  Future<CaptureSession> saveReady(
      String id, String ownerKey, Set<String> draftIds) async {
    final result = await (await database.database).transaction((tx) async {
      final rows = await tx.query('captures',
          where: 'id = ? AND owner_key = ?', whereArgs: [id, ownerKey]);
      if (rows.isEmpty) throw StateError('Capture not found in this account.');
      final session = _decode(rows.single);
      if (session.terminal) return session;
      final updated = <CaptureDraft>[];
      for (final draft in session.drafts) {
        if (!draftIds.contains(draft.id) || !draft.pending) {
          updated.add(draft);
          continue;
        }
        if (!draft.confirmed) {
          throw StateError('Confirm the uncertain details first.');
        }
        final values = draft.task.toMap()..remove('id');
        final taskId = await tx.insert('tasks', {
          ...values,
          'owner_key': ownerKey,
          'sync_id': const Uuid().v4(),
          'sync_pending': ownerKey == 'local' ? 0 : 1
        });
        updated.add(draft.copyWith(savedTaskId: taskId));
      }
      final completed = updated.isNotEmpty && updated.every((d) => !d.pending);
      final next = session.copyWith(
          drafts: updated, status: completed ? 'saved' : 'ready');
      // Keep only task identities after completion, not sensitive source words.
      final retained = completed ? _withoutInput(next) : next;
      await tx.update('captures',
          {'data': jsonEncode(retained.toJson()), 'status': retained.status},
          where: 'id = ? AND owner_key = ?', whereArgs: [id, ownerKey]);
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
      audioPath: session.audioPath,
      status: session.status,
      drafts: session.drafts
          .map((d) => CaptureDraft(
              id: d.id,
              task: Task(title: '', priority: 1),
              savedTaskId: d.savedTaskId,
              removed: d.removed))
          .toList());

  Future<void> discard(String id, String ownerKey) async {
    final discarded = await (await database.database).transaction((tx) async {
      final rows = await tx.query('captures',
          where: 'id = ? AND owner_key = ?', whereArgs: [id, ownerKey]);
      if (rows.isEmpty) throw StateError('Capture not found in this account.');
      final session = _decode(rows.single);
      if (session.terminal) return session;
      final next =
          _withoutInput(session.copyWith(status: 'discarded', drafts: []));
      await tx.update('captures',
          {'status': 'discarded', 'data': jsonEncode(next.toJson())},
          where: 'id = ? AND owner_key = ?', whereArgs: [id, ownerKey]);
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
    } on FileSystemException {/* Retried during the next recovery sweep. */}
  }

  Future<void> cleanFinished(String ownerKey) async {
    final rows = await (await database.database).query('captures',
        where: "owner_key = ? AND status IN ('saved','discarded')",
        whereArgs: [ownerKey]);
    for (final row in rows) {
      await _removeAudio(_decode(row));
    }
  }

  /// Finalize a conventional PCM WAV left open by a killed recording process.
  /// Refuse unfamiliar formats; never rewrite or remove the captured samples.
  static Future<void> recoverWav(String path) async {
    final file = File(path);
    if (!await file.exists() || await file.length() < 44) return;
    final handle = await file.open(mode: FileMode.append);
    try {
      final bytes = await file.readAsBytes();
      if (ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) != 'WAVE') {
        return;
      }
      final data = ByteData.sublistView(bytes);
      var offset = 12;
      var pcm = false;
      while (offset + 8 <= bytes.length) {
        final chunk =
            ascii.decode(bytes.sublist(offset, offset + 4), allowInvalid: true);
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
