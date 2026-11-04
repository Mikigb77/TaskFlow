import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/disk_space.dart';
import 'package:agenda/services/meeting_note.dart';
import 'package:agenda/services/task_database.dart';

/// What still waits on this phone for one account: what signing out would
/// leave behind (MN-13).
class MeetingBacklog {
  const MeetingBacklog({this.meetings = 0, this.pieces = 0});

  /// Meetings recording, stopped or waiting for their notes.
  final int meetings;

  /// Pieces the server hasn't confirmed yet.
  final int pieces;
  bool get isEmpty => meetings == 0 && pieces == 0;
}

/// Meetings and their pieces, in the app's database, by account
/// (`owner_key`, as [captureOwnerProvider] makes it). Audio lives in the
/// app's support directory, one folder per meeting; a piece's file is
/// deleted only once the server confirmed its text is saved (MN-8).
class MeetingStore {
  MeetingStore(this.database, {this.directory});
  final TaskDatabase database;

  /// Where audio goes; the app's support directory when null.
  final Directory? directory;

  /// A stopped meeting left without an answer this long is finished into
  /// a note (MN-26).
  static const unanswered = Duration(days: 7);

  /// A result the screens never showed is forgotten after this long; the
  /// note stays.
  static const resultKept = Duration(days: 7);

  Future<Database> get _db => database.database;

  Future<Directory> _root() async {
    final root =
        directory ??
        Directory(
          p.join((await getApplicationSupportDirectory()).path, 'meetings'),
        );
    return root.create(recursive: true);
  }

  /// Where piece audio for [meetingId] starting at [offset] goes. Named by
  /// its offset, so a silent piece dropped doesn't clash with the piece
  /// that takes its number.
  Future<String> piecePath(
    String meetingId,
    Duration offset,
    MeetingAudioFormat format,
  ) async {
    final folder = Directory(p.join((await _root()).path, meetingId));
    await folder.create(recursive: true);
    return p.join(folder.path, '${offset.inMilliseconds}.${format.extension}');
  }

  /// The bytes free where the audio goes (MN-6); null when unknown.
  Future<int?> freeBytes() async => diskFreeBytes((await _root()).path);

  // ---- Reading ----

  static const _columns = '''m.*, (SELECT COUNT(*) FROM meeting_pieces x
      WHERE x.meeting_id = m.id AND x.owner_key = m.owner_key
      AND x.state != 'saved') AS waiting''';

  static DateTime? _time(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  static Meeting _meeting(Map<String, Object?> row) => Meeting(
    id: row['id'] as String,
    ownerKey: row['owner_key'] as String,
    phase: MeetingPhase.parse(row['phase']),
    startedAt: _time(row['started_at'])!,
    stoppedAt: _time(row['stopped_at']),
    heartbeatAt: _time(row['heartbeat_at']),
    recorded: Duration(milliseconds: row['recorded_ms'] as int? ?? 0),
    nextIndex: row['next_index'] as int? ?? 0,
    lastIndex: row['last_index'] as int?,
    language: row['language'] as String?,
    format: MeetingAudioFormat.parse(row['format']),
    projectId: row['project_id'] as String?,
    problem: row['problem'] as String?,
    attempts: row['attempts'] as int? ?? 0,
    retryAt: _time(row['retry_at']),
    waits: row['waits'] as int? ?? 0,
    askedAt: _time(row['asked_at']),
    noteId: row['note_id'] as int?,
    title: row['title'] as String?,
    seen: row['seen'] == 1,
    waitingPieces: row['waiting'] as int? ?? 0,
  );

  static MeetingPiece _piece(Map<String, Object?> row) =>
      MeetingPiece(
        meetingId: row['meeting_id'] as String,
        ownerKey: row['owner_key'] as String,
        index: row['idx'] as int,
        offset: Duration(milliseconds: row['offset_ms'] as int),
        duration: Duration(milliseconds: row['duration_ms'] as int),
        path: row['path'] as String,
        state: row['state'] as String,
        hasSound: row['has_sound'] == 1,
        attempts: row['attempts'] as int? ?? 0,
        retryAt: _time(row['retry_at']),
      );

  Future<Meeting?> meeting(String id, String ownerKey) async {
    final rows = await (await _db).rawQuery(
      'SELECT $_columns FROM meetings m WHERE m.id = ? AND m.owner_key = ?',
      [id, ownerKey],
    );
    return rows.isEmpty ? null : _meeting(rows.single);
  }

  /// This account's meetings, oldest first.
  Future<List<Meeting>> meetings(
    String ownerKey, {
    Set<MeetingPhase>? phases,
  }) async {
    final rows = await (await _db).rawQuery(
      'SELECT $_columns FROM meetings m WHERE m.owner_key = ?'
      '${phases == null ? '' : ' AND m.phase IN (${List.filled(phases.length, '?').join(',')})'}'
      ' ORDER BY m.started_at, m.id',
      [ownerKey, ...?phases?.map((phase) => phase.name)],
    );
    return rows.map(_meeting).toList();
  }

  Future<List<MeetingPiece>> pieces(
    String meetingId,
    String ownerKey,
  ) async {
    final rows = await (await _db).query(
      'meeting_pieces',
      where: 'meeting_id = ? AND owner_key = ?',
      whereArgs: [meetingId, ownerKey],
      orderBy: 'idx',
    );
    return rows.map(_piece).toList();
  }

  /// Pieces due to upload now, oldest meeting first: of a meeting that
  /// isn't discarded, held back for Pro or the allowance, or left with a
  /// piece that can never be sent.
  Future<List<MeetingPiece>> duePieces(
    String ownerKey,
    DateTime now,
  ) async {
    final at = now.toUtc().toIso8601String();
    final rows = await (await _db).rawQuery(
      '''SELECT x.* FROM meeting_pieces x JOIN meetings m
      ON m.id = x.meeting_id AND m.owner_key = x.owner_key
      WHERE x.owner_key = ? AND x.state = 'pending'
      AND m.phase IN ('recording','interrupted','finishing')
      AND (x.retry_at IS NULL OR x.retry_at <= ?)
      AND NOT (m.problem IN ('pro_required','meeting_allowance_used')
        AND m.retry_at IS NOT NULL AND m.retry_at > ?)
      AND COALESCE(m.problem, '') != 'piece_failed'
      ORDER BY m.started_at, m.id, x.idx''',
      [ownerKey, at, at],
    );
    return rows.map(_piece).toList();
  }

  /// For each meeting of [ownerKey] with pieces waiting and none confirmed
  /// yet, the number of its first waiting piece.
  Future<Map<String, int>> unconfirmedStarts(String ownerKey) async {
    final rows = await (await _db).rawQuery(
      '''SELECT meeting_id, MIN(idx) AS first FROM meeting_pieces x
      WHERE owner_key = ? AND state = 'pending' AND NOT EXISTS (
        SELECT 1 FROM meeting_pieces y WHERE y.meeting_id = x.meeting_id
        AND y.owner_key = x.owner_key AND y.state = 'saved')
      GROUP BY meeting_id''',
      [ownerKey],
    );
    return {
      for (final row in rows) row['meeting_id'] as String: row['first'] as int,
    };
  }

  /// When the next piece, finish or acknowledgement of this account is due,
  /// if anything is left at all.
  Future<DateTime?> nextDue(String ownerKey) async {
    final db = await _db;
    // As [duePieces], [unconfirmedStarts] and [finishable] choose: a piece
    // waits for its own retry, and for its meeting's while Pro or the
    // allowance holds it. Of a meeting the server hasn't confirmed a piece
    // of yet, only the first waiting piece is sent, so only its retry
    // counts: the others wait for it, not for nothing.
    final pieces = await db.rawQuery(
      '''SELECT MAX(COALESCE(x.retry_at, ''),
        CASE WHEN m.problem IN ('pro_required','meeting_allowance_used')
        THEN COALESCE(m.retry_at, '') ELSE '' END) AS due
      FROM meeting_pieces x
      JOIN meetings m ON m.id = x.meeting_id AND m.owner_key = x.owner_key
      WHERE x.owner_key = ? AND x.state = 'pending'
      AND m.phase IN ('recording','interrupted','finishing')
      AND COALESCE(m.problem, '') != 'piece_failed'
      AND (EXISTS (SELECT 1 FROM meeting_pieces y
          WHERE y.meeting_id = x.meeting_id AND y.owner_key = x.owner_key
          AND y.state = 'saved')
        OR x.idx = (SELECT MIN(z.idx) FROM meeting_pieces z
          WHERE z.meeting_id = x.meeting_id AND z.owner_key = x.owner_key
          AND z.state = 'pending'))''',
      [ownerKey],
    );
    final meetings = await db.rawQuery(
      '''SELECT COALESCE(m.retry_at, '') AS due FROM meetings m
      WHERE m.owner_key = ? AND (m.phase IN ('saved','discarding')
        OR (m.phase = 'finishing' AND COALESCE(m.problem, '') != 'expired'
          AND NOT EXISTS (SELECT 1 FROM meeting_pieces x
            WHERE x.meeting_id = m.id AND x.owner_key = m.owner_key
            AND x.state != 'saved')))''',
      [ownerKey],
    );
    final times = [
      for (final row in [...pieces, ...meetings])
        if (row['due'] is String) row['due'] as String,
    ]..sort();
    if (times.isEmpty) return null;
    return times.first.isEmpty
        ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : DateTime.parse(times.first).toUtc();
  }

  /// Pieces and meetings still waiting for [ownerKey] (MN-13).
  Future<MeetingBacklog> backlog(String ownerKey) async {
    final db = await _db;
    final meetings = Sqflite.firstIntValue(
      await db.rawQuery(
        '''SELECT COUNT(*) FROM meetings WHERE owner_key = ?
        AND phase IN ('recording','interrupted','finishing')''',
        [ownerKey],
      ),
    );
    final pieces = Sqflite.firstIntValue(
      await db.rawQuery(
        '''SELECT COUNT(*) FROM meeting_pieces x JOIN meetings m
        ON m.id = x.meeting_id AND m.owner_key = x.owner_key
        WHERE x.owner_key = ? AND x.state != 'saved'
        AND m.phase IN ('recording','interrupted','finishing')''',
        [ownerKey],
      ),
    );
    return MeetingBacklog(meetings: meetings ?? 0, pieces: pieces ?? 0);
  }

  // ---- Recording ----

  /// A new meeting, recording, with its id made here (MN-5).
  Future<Meeting> create(
    String ownerKey, {
    required MeetingAudioFormat format,
    required DateTime now,
    String? language,
    String? projectId,
    String? id,
  }) async {
    final meeting = Meeting(
      id: id ?? const Uuid().v4(),
      ownerKey: ownerKey,
      phase: MeetingPhase.recording,
      startedAt: now.toUtc(),
      heartbeatAt: now.toUtc(),
      format: format,
      language: language,
      projectId: projectId,
    );
    await (await _db).insert('meetings', {
      'id': meeting.id,
      'owner_key': ownerKey,
      'phase': meeting.phase.name,
      'started_at': meeting.startedAt.toIso8601String(),
      'heartbeat_at': meeting.startedAt.toIso8601String(),
      'format': format.name,
      'language': language,
      'project_id': projectId,
    });
    return meeting;
  }

  /// The piece the recorder starts writing now: number [index], at
  /// [offset] into the meeting. A recording meeting only.
  Future<void> openPiece(
    Meeting meeting, {
    required int index,
    required Duration offset,
    required String path,
    required DateTime now,
  }) => (_db).then(
    (db) => db.transaction((tx) async {
      await _requirePhase(tx, meeting, {MeetingPhase.recording});
      await _insertPiece(tx, meeting, index, offset, path);
      await tx.update(
        'meetings',
        {'heartbeat_at': now.toUtc().toIso8601String()},
        where: 'id = ? AND owner_key = ?',
        whereArgs: [meeting.id, meeting.ownerKey],
      );
    }),
  );

  Future<void> _insertPiece(
    DatabaseExecutor tx,
    Meeting meeting,
    int index,
    Duration offset,
    String path,
  ) => tx.insert('meeting_pieces', {
    'meeting_id': meeting.id,
    'owner_key': meeting.ownerKey,
    'idx': index,
    'offset_ms': offset.inMilliseconds,
    'duration_ms': 0,
    'path': path,
    'state': MeetingPiece.recording,
    'has_sound': 0,
  });

  Future<void> _requirePhase(
    DatabaseExecutor tx,
    Meeting meeting,
    Set<MeetingPhase> phases,
  ) async {
    final rows = await tx.query(
      'meetings',
      columns: ['phase'],
      where: 'id = ? AND owner_key = ?',
      whereArgs: [meeting.id, meeting.ownerKey],
    );
    if (rows.isEmpty || !phases.contains(MeetingPhase.parse(rows.single['phase']))) {
      throw StateError('This meeting is no longer recording.');
    }
  }

  /// Ends the piece being written: kept as waiting to upload when it
  /// [hasSound], else dropped with its file (MN-4). Then, with [next],
  /// starts the next one at the number that follows the last kept piece.
  /// Returns whether the piece was kept.
  Future<bool> closePiece(
    Meeting meeting, {
    required int index,
    required Duration duration,
    required bool hasSound,
    required DateTime now,
    String? nextPath,
    bool hold = false,
  }) async {
    final db = await _db;
    String? dropped;
    final leftOut = <String>[];
    final kept = await db.transaction((tx) async {
      await _requirePhase(tx, meeting, {MeetingPhase.recording});
      final rows = await tx.query(
        'meeting_pieces',
        where: 'meeting_id = ? AND owner_key = ? AND idx = ? AND state = ?',
        whereArgs: [
          meeting.id,
          meeting.ownerKey,
          index,
          MeetingPiece.recording,
        ],
      );
      if (rows.isEmpty) throw StateError('No piece is being recorded.');
      final piece = _piece(rows.single);
      final end = piece.offset + duration;
      if (hasSound) {
        await tx.update(
          'meeting_pieces',
          {
            'state': MeetingPiece.pending,
            'duration_ms': duration.inMilliseconds,
            'has_sound': 1,
          },
          where: 'meeting_id = ? AND owner_key = ? AND idx = ?',
          whereArgs: [meeting.id, meeting.ownerKey, index],
        );
        leftOut.addAll(await _dropHeld(tx, meeting.id, meeting.ownerKey));
      } else if (hold) {
        // Held under a number below 0, out of the way of the pieces sent.
        final lowest = Sqflite.firstIntValue(
          await tx.rawQuery(
            'SELECT MIN(idx) FROM meeting_pieces '
            'WHERE meeting_id = ? AND owner_key = ?',
            [meeting.id, meeting.ownerKey],
          ),
        );
        await tx.update(
          'meeting_pieces',
          {
            'idx': (lowest == null || lowest > 0 ? 0 : lowest) - 1,
            'state': MeetingPiece.held,
            'duration_ms': duration.inMilliseconds,
            'has_sound': 0,
          },
          where: 'meeting_id = ? AND owner_key = ? AND idx = ?',
          whereArgs: [meeting.id, meeting.ownerKey, index],
        );
      } else {
        dropped = piece.path;
        await tx.delete(
          'meeting_pieces',
          where: 'meeting_id = ? AND owner_key = ? AND idx = ?',
          whereArgs: [meeting.id, meeting.ownerKey, index],
        );
      }
      final nextIndex = hasSound ? index + 1 : index;
      await tx.update(
        'meetings',
        {
          'next_index': nextIndex,
          'recorded_ms': end.inMilliseconds,
          'heartbeat_at': now.toUtc().toIso8601String(),
        },
        where: 'id = ? AND owner_key = ?',
        whereArgs: [meeting.id, meeting.ownerKey],
      );
      if (nextPath != null) {
        await _insertPiece(tx, meeting, nextIndex, end, nextPath);
      }
      return hasSound;
    });
    if (dropped != null) await _deleteFile(dropped!);
    for (final path in leftOut) {
      await _deleteFile(path);
    }
    return kept;
  }

  /// Leaves out [id]'s held silent pieces (MN-4): a piece with sound was
  /// kept. Returns their files, to delete once
  /// the transaction is done.
  Future<List<String>> _dropHeld(
    DatabaseExecutor tx,
    String id,
    String ownerKey,
  ) async {
    final rows = await tx.query(
      'meeting_pieces',
      columns: ['path'],
      where: 'meeting_id = ? AND owner_key = ? AND state = ?',
      whereArgs: [id, ownerKey, MeetingPiece.held],
    );
    if (rows.isEmpty) return const [];
    await tx.delete(
      'meeting_pieces',
      where: 'meeting_id = ? AND owner_key = ? AND state = ?',
      whereArgs: [id, ownerKey, MeetingPiece.held],
    );
    return [for (final row in rows) row['path'] as String];
  }

  /// Whether [id] holds silent pieces on the phone ([MeetingPiece.held]).
  Future<bool> hasHeld(String id, String ownerKey) async {
    final count = Sqflite.firstIntValue(
      await (await _db).rawQuery(
        'SELECT COUNT(*) FROM meeting_pieces '
        'WHERE meeting_id = ? AND owner_key = ? AND state = ?',
        [id, ownerKey, MeetingPiece.held],
      ),
    );
    return (count ?? 0) > 0;
  }

  /// Saved every few seconds while recording, so an interrupted recording
  /// knows how long its last piece ran (MN-12).
  Future<void> heartbeat(
    Meeting meeting, {
    required int index,
    required Duration pieceDuration,
    required bool hasSound,
    required DateTime now,
  }) async {
    final db = await _db;
    await db.transaction((tx) async {
      final changed = await tx.update(
        'meeting_pieces',
        {
          'duration_ms': pieceDuration.inMilliseconds,
          'has_sound': hasSound ? 1 : 0,
        },
        where: 'meeting_id = ? AND owner_key = ? AND idx = ? AND state = ?',
        whereArgs: [
          meeting.id,
          meeting.ownerKey,
          index,
          MeetingPiece.recording,
        ],
      );
      if (changed == 0) return;
      await tx.update(
        'meetings',
        {'heartbeat_at': now.toUtc().toIso8601String()},
        where: 'id = ? AND owner_key = ? AND phase = ?',
        whereArgs: [meeting.id, meeting.ownerKey, MeetingPhase.recording.name],
      );
    });
  }

  /// Meetings of [ownerKey] still marked recording that this app isn't
  /// recording ([active] is the one it is): the app or phone stopped
  /// under them (MN-12). Their last piece is kept as far as the last
  /// heartbeat, and they wait for Continue, Finish or Discard.
  Future<List<Meeting>> recoverInterrupted(
    String ownerKey, {
    String? active,
  }) async {
    final db = await _db;
    final stuck = (await meetings(
      ownerKey,
      phases: {MeetingPhase.recording},
    )).where((meeting) => meeting.id != active).toList();
    final drop = <String>[];
    for (final meeting in stuck) {
      final open = (await pieces(meeting.id, ownerKey))
          .where((piece) => piece.state == MeetingPiece.recording)
          .toList();
      await db.transaction((tx) async {
        var next = meeting.nextIndex;
        var recorded = meeting.recorded;
        for (final piece in open) {
          final file = File(piece.path);
          final usable =
              piece.hasSound &&
              piece.duration > const Duration(seconds: 1) &&
              await file.exists() &&
              await file.length() > 1024;
          if (usable) {
            await tx.update(
              'meeting_pieces',
              {'state': MeetingPiece.pending},
              where: 'meeting_id = ? AND owner_key = ? AND idx = ?',
              whereArgs: [meeting.id, ownerKey, piece.index],
            );
            next = piece.index + 1;
            recorded = piece.offset + piece.duration;
          } else {
            drop.add(piece.path);
            await tx.delete(
              'meeting_pieces',
              where: 'meeting_id = ? AND owner_key = ? AND idx = ?',
              whereArgs: [meeting.id, ownerKey, piece.index],
            );
            if (piece.offset + piece.duration > recorded) {
              recorded = piece.offset + piece.duration;
            }
          }
        }
        await tx.update(
          'meetings',
          {
            'phase': MeetingPhase.interrupted.name,
            'next_index': next,
            'recorded_ms': recorded.inMilliseconds,
            'stopped_at': (meeting.heartbeatAt ?? meeting.startedAt)
                .toIso8601String(),
          },
          where: 'id = ? AND owner_key = ? AND phase = ?',
          whereArgs: [meeting.id, ownerKey, MeetingPhase.recording.name],
        );
      });
    }
    for (final path in drop) {
      await _deleteFile(path);
    }
    return [
      for (final meeting in stuck)
        if (await this.meeting(meeting.id, ownerKey) case final recovered?)
          recovered,
    ];
  }

  /// Continue: an interrupted meeting records again, its new pieces
  /// numbered after the last one (MN-12).
  Future<Meeting> resume(String id, String ownerKey, DateTime now) async {
    final db = await _db;
    // A piece that can never be sent stays said: the meeting still can't
    // become notes.
    final changed = await db.rawUpdate(
      '''UPDATE meetings SET phase = ?, stopped_at = NULL, heartbeat_at = ?,
      asked_at = NULL, retry_at = NULL, last_index = NULL,
      problem = CASE WHEN problem = ? THEN problem ELSE NULL END
      WHERE id = ? AND owner_key = ? AND phase = ?''',
      [
        MeetingPhase.recording.name,
        now.toUtc().toIso8601String(),
        MeetingProblem.pieceFailed,
        id,
        ownerKey,
        MeetingPhase.interrupted.name,
      ],
    );
    if (changed != 1) throw StateError('This meeting can no longer continue.');
    return (await meeting(id, ownerKey))!;
  }

  /// Stop or Finish: the meeting waits for its notes, its last piece
  /// being the last one kept. A meeting that kept no piece with sound is
  /// made from its held silent pieces (UX-2717), sent like any piece;
  /// without them, or with [keepHeld] false, it holds nothing to make
  /// notes from and is discarded; null then.
  Future<Meeting?> finish(
    String id,
    String ownerKey,
    DateTime now, {
    bool keepHeld = true,
  }) async {
    final current = await meeting(id, ownerKey);
    if (current == null) return null;
    if (![
      MeetingPhase.recording,
      MeetingPhase.interrupted,
    ].contains(current.phase)) {
      return current;
    }
    final held = [
      for (final piece in await pieces(id, ownerKey))
        if (piece.state == MeetingPiece.held) piece,
    ]..sort((a, b) => a.offset.compareTo(b.offset));
    if (current.empty && (!keepHeld || held.isEmpty)) {
      await discard(id, ownerKey);
      return null;
    }
    final db = await _db;
    final leftOut = <String>[];
    await db.transaction((tx) async {
      var next = current.nextIndex;
      if (current.empty) {
        // Numbered 0, 1, 2… in the order they were recorded.
        for (final (i, piece) in held.indexed) {
          await tx.update(
            'meeting_pieces',
            {'idx': i, 'state': MeetingPiece.pending},
            where: 'meeting_id = ? AND owner_key = ? AND idx = ?',
            whereArgs: [id, ownerKey, piece.index],
          );
        }
        next = held.length;
      } else {
        leftOut.addAll(await _dropHeld(tx, id, ownerKey));
      }
      await tx.update(
        'meetings',
        {
          'phase': MeetingPhase.finishing.name,
          'next_index': next,
          'last_index': next - 1,
          'stopped_at': (current.stoppedAt ?? now).toUtc().toIso8601String(),
          'retry_at': null,
          'attempts': 0,
          'waits': 0,
        },
        where: 'id = ? AND owner_key = ? AND phase = ?',
        whereArgs: [id, ownerKey, current.phase.name],
      );
    });
    for (final path in leftOut) {
      await _deleteFile(path);
    }
    return meeting(id, ownerKey);
  }

  /// Stop on a recording judged all silence (UX-2717): kept, as a stopped
  /// meeting with its held pieces, until the person says whether to make
  /// notes from it or discard it.
  Future<Meeting?> stopQuiet(String id, String ownerKey, DateTime now) async {
    await (await _db).update(
      'meetings',
      {
        'phase': MeetingPhase.interrupted.name,
        'stopped_at': now.toUtc().toIso8601String(),
      },
      where: 'id = ? AND owner_key = ? AND phase = ?',
      whereArgs: [id, ownerKey, MeetingPhase.recording.name],
    );
    return meeting(id, ownerKey);
  }

  /// The app has [ownerKey]'s stopped recordings on show now (MN-12):
  /// those not asked about before count their 7 days from [now] (MN-26).
  Future<void> markAsked(String ownerKey, DateTime now) async {
    await (await _db).update(
      'meetings',
      {'asked_at': now.toUtc().toIso8601String()},
      where: 'owner_key = ? AND phase = ? AND asked_at IS NULL',
      whereArgs: [ownerKey, MeetingPhase.interrupted.name],
    );
  }

  /// Stopped meetings left unanswered for [unanswered] since the app first
  /// asked about them ([markAsked]) are finished into a note, never thrown
  /// away (MN-26). One never asked about waits: a phone left off for a
  /// week still asks first. Returns those finished.
  Future<List<Meeting>> autoFinishStale(String ownerKey, DateTime now) async {
    final finished = <Meeting>[];
    for (final meeting in await meetings(
      ownerKey,
      phases: {MeetingPhase.interrupted},
    )) {
      final since = meeting.askedAt;
      if (since == null || now.toUtc().difference(since) < unanswered) continue;
      final result = await finish(meeting.id, ownerKey, now);
      if (result != null) finished.add(result);
    }
    return finished;
  }

  /// Discard (MN-25): the audio goes at once; the meeting waits only to
  /// tell the server.
  Future<void> discard(String id, String ownerKey) async {
    final db = await _db;
    final files = (await pieces(id, ownerKey)).map((piece) => piece.path);
    await db.transaction((tx) async {
      await tx.delete(
        'meeting_pieces',
        where: 'meeting_id = ? AND owner_key = ?',
        whereArgs: [id, ownerKey],
      );
      await tx.update(
        'meetings',
        {
          'phase': MeetingPhase.discarding.name,
          'problem': null,
          'retry_at': null,
          'attempts': 0,
        },
        where: 'id = ? AND owner_key = ?',
        whereArgs: [id, ownerKey],
      );
    });
    for (final path in files) {
      await _deleteFile(path);
    }
    await _deleteFolder(id);
  }

  /// Discards every meeting still waiting for [ownerKey]: signing out
  /// without uploading them (MN-13).
  Future<void> discardAll(String ownerKey) async {
    for (final meeting in await meetings(
      ownerKey,
      phases: {
        MeetingPhase.recording,
        MeetingPhase.interrupted,
        MeetingPhase.finishing,
      },
    )) {
      await discard(meeting.id, ownerKey);
    }
  }

  // ---- Uploading ----

  /// The server confirmed piece [piece] is saved: only now its file goes.
  Future<void> pieceSaved(MeetingPiece piece) async {
    final changed = await (await _db).update(
      'meeting_pieces',
      {'state': MeetingPiece.saved, 'retry_at': null},
      where: 'meeting_id = ? AND owner_key = ? AND idx = ? AND state = ?',
      whereArgs: [
        piece.meetingId,
        piece.ownerKey,
        piece.index,
        MeetingPiece.pending,
      ],
    );
    if (changed == 1) await _deleteFile(piece.path);
  }

  /// An upload failed: try [piece] again at [retryAt].
  Future<void> pieceRetry(MeetingPiece piece, DateTime retryAt) async {
    await (await _db).update(
      'meeting_pieces',
      {
        'attempts': piece.attempts + 1,
        'retry_at': retryAt.toUtc().toIso8601String(),
      },
      where: 'meeting_id = ? AND owner_key = ? AND idx = ? AND state = ?',
      whereArgs: [
        piece.meetingId,
        piece.ownerKey,
        piece.index,
        MeetingPiece.pending,
      ],
    );
  }

  /// [piece] can never be sent: its file is gone, or the server refuses it
  /// for good. It stays, no longer sent, and its meeting says so
  /// ([MeetingProblem.pieceFailed]) until it's discarded.
  Future<void> pieceFailed(MeetingPiece piece) async {
    final db = await _db;
    await db.transaction((tx) async {
      final changed = await tx.update(
        'meeting_pieces',
        {'state': MeetingPiece.failed, 'retry_at': null},
        where: 'meeting_id = ? AND owner_key = ? AND idx = ? AND state = ?',
        whereArgs: [
          piece.meetingId,
          piece.ownerKey,
          piece.index,
          MeetingPiece.pending,
        ],
      );
      if (changed == 0) return;
      await tx.update(
        'meetings',
        {'problem': MeetingProblem.pieceFailed, 'retry_at': null},
        where: 'id = ? AND owner_key = ?',
        whereArgs: [piece.meetingId, piece.ownerKey],
      );
    });
  }

  /// Makes every waiting piece and finish of [ownerKey] due now, except
  /// those held back for Pro or the allowance. With [proGained] (the
  /// account has just bought or restored Pro), those held back for Pro are
  /// due now too; the month's allowance still holds its own.
  Future<void> retryNow(String ownerKey, {bool proGained = false}) async {
    final db = await _db;
    await db.transaction((tx) async {
      if (proGained) {
        await tx.rawUpdate(
          '''UPDATE meetings SET problem = NULL, retry_at = NULL, attempts = 0
          WHERE owner_key = ? AND problem = 'pro_required' ''',
          [ownerKey],
        );
      }
      await tx.rawUpdate(
        '''UPDATE meeting_pieces SET retry_at = NULL WHERE owner_key = ?
        AND state = 'pending' AND meeting_id NOT IN (SELECT id FROM meetings
          WHERE owner_key = ? AND problem IN ('pro_required','meeting_allowance_used'))''',
        [ownerKey, ownerKey],
      );
      await tx.rawUpdate(
        '''UPDATE meetings SET retry_at = NULL WHERE owner_key = ?
        AND phase IN ('finishing','saved','discarding')
        AND COALESCE(problem, '') NOT IN ('pro_required','meeting_allowance_used','expired')''',
        [ownerKey],
      );
    });
  }

  /// Says why [id]'s uploads wait ([MeetingProblem]), or clears it; its
  /// finish or acknowledgement, if any, is tried again at [retryAt]. A
  /// piece that can never be sent stays said ([pieceFailed]).
  Future<void> setProblem(
    String id,
    String ownerKey,
    String? problem, {
    DateTime? retryAt,
    int? attempts,
    int? waits,
  }) async {
    await (await _db).rawUpdate(
      '''UPDATE meetings SET
      problem = CASE WHEN problem = ? THEN problem ELSE ? END, retry_at = ?
      ${attempts == null ? '' : ', attempts = $attempts'}
      ${waits == null ? '' : ', waits = $waits'}
      WHERE id = ? AND owner_key = ?''',
      [
        MeetingProblem.pieceFailed,
        problem,
        retryAt?.toUtc().toIso8601String(),
        id,
        ownerKey,
      ],
    );
  }

  /// Finishing meetings whose every piece the server confirmed, and whose
  /// `finish` is due now.
  Future<List<Meeting>> finishable(String ownerKey, DateTime now) async {
    final at = now.toUtc();
    return (await meetings(ownerKey, phases: {MeetingPhase.finishing}))
        .where(
          (meeting) =>
              meeting.waitingPieces == 0 &&
              meeting.problem != MeetingProblem.expired &&
              (meeting.retryAt == null || !meeting.retryAt!.isAfter(at)),
        )
        .toList();
  }

  /// Saves [result] as an ordinary note of [meeting]'s account, in the
  /// same transaction that marks the meeting saved, so two uploaders (the
  /// app and its background worker) can't save it twice. Returns the
  /// note's id, also when it was already saved.
  Future<int?> saveNote(
    Meeting meeting,
    MeetingResult result, {
    MeetingNoteLabels labels = MeetingNoteLabels.none,
  }) async {
    final db = await _db;
    final saved = await db.transaction((tx) async {
      final rows = await tx.query(
        'meetings',
        where: 'id = ? AND owner_key = ?',
        whereArgs: [meeting.id, meeting.ownerKey],
      );
      if (rows.isEmpty) return null;
      final current = _meeting(rows.single);
      if (current.noteId != null) return current.noteId;
      if (current.phase != MeetingPhase.finishing) return null;
      var note = meetingNote(
        result,
        labels: labels,
        projectId: current.projectId,
        startedAt: current.startedAt.toLocal(),
        length: current.recorded,
      );
      Task normalized;
      try {
        normalized = await TaskDatabase.normalizeResponsibility(
          tx,
          note,
          meeting.ownerKey,
        );
      } on StateError {
        // The project went, or became read-only, while it recorded: the
        // notes still arrive, outside it.
        note = note.copyWith(listId: null);
        normalized = await TaskDatabase.normalizeResponsibility(
          tx,
          note,
          meeting.ownerKey,
        );
      }
      final values = normalized.toMap()..remove('id');
      final syncId = const Uuid().v4();
      final noteId = await tx.insert('tasks', {
        ...values,
        'owner_key': meeting.ownerKey,
        'sync_id': syncId,
        'sync_pending': meeting.ownerKey == 'local' ? 0 : 1,
      });
      await TaskDatabase.stageAttachments(
        tx,
        meeting.ownerKey,
        syncId,
        normalized,
      );
      await tx.update(
        'meetings',
        {
          'phase': MeetingPhase.saved.name,
          'note_id': noteId,
          'title': normalized.title,
          'problem': null,
          'retry_at': null,
          'attempts': 0,
          'waits': 0,
        },
        where: 'id = ? AND owner_key = ?',
        whereArgs: [meeting.id, meeting.ownerKey],
      );
      await tx.delete(
        'meeting_pieces',
        where: 'meeting_id = ? AND owner_key = ?',
        whereArgs: [meeting.id, meeting.ownerKey],
      );
      return noteId;
    });
    if (saved != null) await _deleteFolder(meeting.id);
    return saved;
  }

  /// The server deleted [id] (DELETE answered): a saved meeting keeps
  /// only its "notes ready" until seen; a discarded one is gone.
  Future<void> acknowledged(String id, String ownerKey) async {
    final db = await _db;
    await db.transaction((tx) async {
      await tx.delete(
        'meetings',
        where: 'id = ? AND owner_key = ? AND (phase = ? OR (phase = ? AND seen = 1))',
        whereArgs: [
          id,
          ownerKey,
          MeetingPhase.discarding.name,
          MeetingPhase.saved.name,
        ],
      );
      await tx.update(
        'meetings',
        {'phase': MeetingPhase.done.name, 'retry_at': null, 'problem': null},
        where: 'id = ? AND owner_key = ? AND phase = ?',
        whereArgs: [id, ownerKey, MeetingPhase.saved.name],
      );
    });
  }

  /// The screens showed that [id]'s notes are ready.
  Future<void> markSeen(String id, String ownerKey) async {
    final db = await _db;
    await db.update(
      'meetings',
      {'seen': 1},
      where: 'id = ? AND owner_key = ?',
      whereArgs: [id, ownerKey],
    );
    await db.delete(
      'meetings',
      where: 'id = ? AND owner_key = ? AND phase = ?',
      whereArgs: [id, ownerKey, MeetingPhase.done.name],
    );
  }

  /// Forgets results shown long ago or never, and removes audio no piece
  /// uses: the folder of a meeting that's gone, and a file the recorder
  /// began just before the app was killed. A meeting still recording is
  /// left alone, since the recorder may be starting a file there. Run on
  /// start, after [recoverInterrupted] and before anything records.
  Future<void> clean(String ownerKey, DateTime now) async {
    final db = await _db;
    await db.delete(
      'meetings',
      where: 'owner_key = ? AND phase = ? AND stopped_at < ?',
      whereArgs: [
        ownerKey,
        MeetingPhase.done.name,
        now.toUtc().subtract(resultKept).toIso8601String(),
      ],
    );
    await _removeUnused();
  }

  Future<void> _removeUnused() async {
    final db = await _db;
    // Every account's: the folders aren't kept by account.
    final phases = {
      for (final row in await db.query('meetings', columns: ['id', 'phase']))
        row['id'] as String: row['phase'] as String,
    };
    final used = <String, Set<String>>{};
    for (final row in await db.query(
      'meeting_pieces',
      columns: ['meeting_id', 'path'],
    )) {
      (used[row['meeting_id'] as String] ??= {}).add(
        p.normalize(File(row['path'] as String).absolute.path),
      );
    }
    try {
      final root = await _root();
      await for (final entry in root.list(followLinks: false)) {
        final id = p.basename(entry.path);
        if (entry is! Directory || !_id.hasMatch(id)) continue;
        final phase = phases[id];
        if (phase == MeetingPhase.recording.name) continue;
        final files = used[id];
        if (files == null) {
          await _deleteFolder(id);
          continue;
        }
        await for (final file in entry.list(followLinks: false)) {
          if (file is File &&
              !files.contains(p.normalize(file.absolute.path))) {
            await _deleteFile(file.path);
          }
        }
      }
    } on FileSystemException {
      /* Tried again on the next start. */
    }
  }

  /// Deletes the audio folder of each meeting in [ids], whatever its rows
  /// say: an erased account's (`LocalAccountData.erase`).
  Future<void> removeFolders(Iterable<String> ids) async {
    for (final id in ids) {
      await _deleteFolder(id);
    }
  }

  // ---- One uploader at a time ----

  /// Takes the upload lease of [ownerKey] for [holder] until [ttl] after
  /// [now], unless another uploader (the app or its background worker)
  /// holds it. Both may then never send at once: their calls are safe to
  /// repeat, but each would refresh the login on its own.
  Future<bool> acquireLease(
    String ownerKey,
    String holder,
    DateTime now, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    final db = await _db;
    return db.transaction((tx) async {
      final rows = await tx.query(
        'meeting_leases',
        where: 'owner_key = ?',
        whereArgs: [ownerKey],
      );
      if (rows.isNotEmpty &&
          rows.single['holder'] != holder &&
          DateTime.parse(rows.single['expires_at'] as String).isAfter(now.toUtc())) {
        return false;
      }
      await tx.insert('meeting_leases', {
        'owner_key': ownerKey,
        'holder': holder,
        'expires_at': now.toUtc().add(ttl).toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
  }

  Future<void> releaseLease(String ownerKey, String holder) async {
    await (await _db).delete(
      'meeting_leases',
      where: 'owner_key = ? AND holder = ?',
      whereArgs: [ownerKey, holder],
    );
  }

  // ---- Files ----

  Future<void> _deleteFile(String path) async {
    final root = (await _root()).absolute.path;
    if (!p.isWithin(root, File(path).absolute.path)) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      /* Gone with its folder later. */
    }
  }

  /// A meeting id as the phone makes it, and its folder's name.
  static final _id = RegExp(r'^[0-9a-fA-F-]{36}$');

  Future<void> _deleteFolder(String meetingId) async {
    if (!_id.hasMatch(meetingId)) return;
    final folder = Directory(p.join((await _root()).path, meetingId));
    try {
      if (await folder.exists()) await folder.delete(recursive: true);
    } on FileSystemException {
      /* Tried again with the next discard. */
    }
  }
}
