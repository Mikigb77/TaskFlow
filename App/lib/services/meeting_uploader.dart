import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/meeting_api.dart';
import 'package:agenda/services/meeting_note.dart';
import 'package:agenda/services/meeting_store.dart';

/// What one [MeetingUploader.run] did, and when to run again.
class MeetingPass {
  const MeetingPass({
    this.nextDue,
    this.offline = false,
    this.busy = false,
    this.stopped = false,
    this.saved = const [],
  });

  /// When something is due next; null when nothing is left at all.
  final DateTime? nextDue;

  /// The server couldn't be reached: wait for a network.
  final bool offline;

  /// Another uploader (the app or its background worker) is running.
  final bool busy;

  /// The account's login was refused or changed: nothing more runs for it
  /// until it signs in again.
  final bool stopped;

  /// Meetings whose notes this pass saved as notes.
  final List<SavedMeetingNote> saved;

  bool get idle => nextDue == null && !busy;
}

/// The login was refused, or another account signed in: stop this pass.
class _Stop implements Exception {
  const _Stop();
}

/// Sends a meeting's pieces and finishes it (MN-8 to MN-11): pending
/// pieces two at a time ([concurrency], MN-9), but a meeting the server
/// hasn't confirmed a piece of yet sends its lowest waiting piece alone
/// first; each failure tried again after a growing pause; once Stop was
/// pressed, every piece is confirmed and none is uploading, `finish` with
/// the last number, repeated until the notes are
/// ready; then the notes are saved as an ordinary note, `DELETE` tells the
/// server it may forget the meeting (MN-24), and nothing is left here but
/// the "notes ready" until it's seen.
///
/// Only [ownerKey]'s meetings, through [api], which calls with that
/// account's login only (MN-13).
class MeetingUploader {
  MeetingUploader({
    required this.store,
    required this.api,
    required this.ownerKey,
    DateTime Function()? clock,
    this.concurrency = 2,
    String? holder,
  }) : clock = clock ?? DateTime.now,
       holder = holder ?? const Uuid().v4();

  final MeetingStore store;
  final MeetingApi api;
  final String ownerKey;
  final DateTime Function() clock;
  final int concurrency;

  /// This uploader's name on the upload lease.
  final String holder;

  /// The first pause after a failure; each further one doubles, up to
  /// [maxPause] (or the server's `Retry-After`).
  static const firstPause = Duration(seconds: 10);
  static const maxPause = Duration(minutes: 30);

  /// How long Pro or the monthly allowance holds a meeting's pieces back
  /// before they're tried again.
  static const blockedPause = Duration(hours: 6);

  /// A finish that keeps answering `waiting` for pieces this phone no
  /// longer has, this many times, has lost them on the server.
  static const lostAfter = 5;

  /// A piece the server refuses for good ([permanent]) this many times is
  /// never sent again ([MeetingProblem.pieceFailed]).
  static const refusedAfter = 3;

  /// Answers to a piece that sending it again can't change: corrupt or
  /// unreadable (400, 415, 422), too large (413), or not this account's
  /// meeting (404).
  static bool permanent(int status) =>
      const {400, 404, 413, 415, 422}.contains(status);

  static Duration pause(int attempts, {Duration? retryAfter}) {
    final grown = firstPause * math.pow(2, math.max(0, attempts - 1)).toInt();
    final pause = grown > maxPause ? maxPause : grown;
    return retryAfter != null && retryAfter > pause ? retryAfter : pause;
  }

  Future<MeetingPass>? _running;

  /// When the call that found no network may be tried again: nothing else
  /// is either, before then.
  DateTime? _offlineUntil;

  /// Does everything due now; one run at a time.
  Future<MeetingPass> run() => _running ??= _run().whenComplete(() {
    _running = null;
  });

  Future<MeetingPass> _run() async {
    if (!await store.acquireLease(ownerKey, holder, clock())) {
      return MeetingPass(
        nextDue: clock().add(const Duration(minutes: 1)),
        busy: true,
      );
    }
    final saved = <SavedMeetingNote>[];
    var offline = false;
    var stopped = false;
    _offlineUntil = null;
    try {
      offline = await _acknowledge();
      if (!offline) offline = await _uploadPieces();
      if (!offline) offline = await _finish(saved);
    } on _Stop {
      stopped = true;
    } finally {
      await store.releaseLease(ownerKey, holder);
    }
    var next = stopped ? null : await store.nextDue(ownerKey);
    // With no network, a piece or meeting the pass never reached would
    // be due at once: everything waits for the one that found no network.
    final until = _offlineUntil;
    if (offline && next != null && until != null && next.isBefore(until)) {
      next = until;
    }
    return MeetingPass(
      nextDue: next,
      offline: offline,
      stopped: stopped,
      saved: saved,
    );
  }

  /// Keeps the lease while a long pass goes on.
  Future<void> _renew() => store.acquireLease(ownerKey, holder, clock());

  bool _due(Meeting meeting) =>
      meeting.retryAt == null || !meeting.retryAt!.isAfter(clock().toUtc());

  /// Tells the server about saved and discarded meetings. True when the
  /// server couldn't be reached.
  Future<bool> _acknowledge() async {
    for (final meeting in await store.meetings(
      ownerKey,
      phases: {MeetingPhase.saved, MeetingPhase.discarding},
    )) {
      if (!_due(meeting)) continue;
      try {
        await _delete(meeting.id);
      } on ApiException catch (error) {
        if (await _failed(meeting, error)) return true;
      }
    }
    return false;
  }

  /// `DELETE`, and the meeting forgotten here. It needs no Pro
  /// (MEETINGS.md), but an older server answers 402 to it without Pro:
  /// sending it again can't help, and the server's 30-day sweep deletes
  /// the meeting (MN-27), so that answer ends it here too.
  Future<void> _delete(String id) async {
    try {
      await api.delete(id);
    } on ApiException catch (error) {
      if (error.status != 402) rethrow;
    }
    await store.acknowledged(id, ownerKey);
  }

  /// Records a failed meeting call: tried again later. True when offline.
  Future<bool> _failed(Meeting meeting, ApiException error) async {
    if (error.status == 401) throw const _Stop();
    final attempts = meeting.attempts + 1;
    final offline = error.status == 0;
    final retryAt = clock().add(pause(attempts, retryAfter: error.retryAfter));
    await store.setProblem(
      meeting.id,
      ownerKey,
      offline ? MeetingProblem.offline : MeetingProblem.server,
      retryAt: retryAt,
      attempts: attempts,
    );
    if (offline) _wentOffline(retryAt);
    return offline;
  }

  void _wentOffline(DateTime retryAt) {
    final until = _offlineUntil;
    if (until == null || retryAt.isBefore(until)) _offlineUntil = retryAt;
  }

  /// Sends due pieces, [concurrency] at a time, until none is due. True
  /// when the server couldn't be reached.
  Future<bool> _uploadPieces() async {
    var offline = false;
    var stop = false;
    final held = <String>{};
    final cleared = <String>{};
    while (!offline && !stop) {
      // A meeting the server hasn't heard of yet gets its first piece
      // alone: the first piece to arrive creates it, and one numbered
      // above its first would mark its start as missing (MEETINGS.md).
      final starts = await store.unconfirmedStarts(ownerKey);
      final due = (await store.duePieces(ownerKey, clock()))
          .where(
            (piece) =>
                !held.contains(piece.meetingId) &&
                (starts[piece.meetingId] ?? piece.index) == piece.index,
          )
          .toList();
      if (due.isEmpty) break;
      final meetings = {
        for (final meeting in await store.meetings(ownerKey))
          meeting.id: meeting,
      };
      final queue = Queue.of(due);
      Future<void> worker() async {
        while (queue.isNotEmpty && !offline && !stop) {
          final piece = queue.removeFirst();
          final meeting = meetings[piece.meetingId];
          if (meeting == null || held.contains(piece.meetingId)) continue;
          try {
            await _uploadOne(piece, meeting, held, cleared);
          } on _Offline {
            offline = true;
          } on _Stop {
            stop = true;
          }
          await _renew();
        }
      }

      await Future.wait([
        for (var i = 0; i < math.max(1, concurrency); i++) worker(),
      ]);
    }
    if (stop) throw const _Stop();
    return offline;
  }

  Future<void> _uploadOne(
    MeetingPiece piece,
    Meeting meeting,
    Set<String> held,
    Set<String> cleared,
  ) async {
    if (!await File(piece.path).exists()) {
      // Nothing to send, and nothing that can be sent again: say so, and
      // don't try this piece again and again.
      await store.pieceFailed(piece);
      held.add(meeting.id);
      return;
    }
    try {
      final answer = await api.uploadPiece(
        piece,
        format: meeting.format,
        language: meeting.language,
      );
      if (!answer.saved) {
        await store.pieceRetry(piece, clock().add(pause(piece.attempts + 1)));
        return;
      }
      await store.pieceSaved(piece);
      // The server answers again: no longer «Waiting for signal».
      if (meeting.problem != null && cleared.add(meeting.id)) {
        await store.setProblem(meeting.id, ownerKey, null);
      }
    } on ApiException catch (error) {
      final code = error.body?['code'];
      if (error.status == 401) throw const _Stop();
      if (error.status == 402) {
        held.add(meeting.id);
        await store.setProblem(
          meeting.id,
          ownerKey,
          code == MeetingProblem.allowanceUsed
              ? MeetingProblem.allowanceUsed
              : MeetingProblem.proRequired,
          retryAt: clock().add(blockedPause),
        );
        return;
      }
      if (error.status == 409 && code == 'meeting_finished') {
        // The notes exist without it: nothing more to send.
        await store.pieceSaved(piece);
        return;
      }
      if (permanent(error.status) && piece.attempts + 1 >= refusedAfter) {
        await store.pieceFailed(piece);
        held.add(meeting.id);
        return;
      }
      final retryAt = clock().add(
        pause(piece.attempts + 1, retryAfter: error.retryAfter),
      );
      await store.pieceRetry(piece, retryAt);
      if (error.status == 0) {
        await store.setProblem(meeting.id, ownerKey, MeetingProblem.offline);
        _wentOffline(retryAt);
        throw const _Offline();
      }
      await store.setProblem(meeting.id, ownerKey, MeetingProblem.server);
    }
  }

  /// Finishes stopped meetings whose every piece is confirmed, and saves
  /// the notes of those ready. True when the server couldn't be reached.
  Future<bool> _finish(List<SavedMeetingNote> saved) async {
    for (final meeting in await store.finishable(ownerKey, clock())) {
      final MeetingAnswer answer;
      try {
        answer = await api.finish(meeting.id, meeting.lastIndex!);
      } on ApiException catch (error) {
        if (error.status == 402) {
          await store.setProblem(
            meeting.id,
            ownerKey,
            error.body?['code'] == MeetingProblem.allowanceUsed
                ? MeetingProblem.allowanceUsed
                : MeetingProblem.proRequired,
            retryAt: clock().add(blockedPause),
          );
          continue;
        }
        if (await _failed(meeting, error)) return true;
        continue;
      }
      await _renew();
      if (!answer.ready && answer.missing.isEmpty) {
        // Every piece is in and the notes are being written (MEETINGS.md):
        // progress, never counted toward [lostAfter]. Asked again after a
        // growing pause.
        final attempts = meeting.attempts + 1;
        await store.setProblem(
          meeting.id,
          ownerKey,
          null,
          retryAt: clock().add(pause(attempts)),
          attempts: attempts,
        );
        continue;
      }
      if (!answer.ready) {
        // Every piece here is confirmed, so the server lacks only pieces
        // this phone no longer has: it deleted them (MN-27). Ask again,
        // and after [lostAfter] answers say they're lost. Failed calls
        // before don't count: the server answered this one.
        final waits = meeting.waits + 1;
        await store.setProblem(
          meeting.id,
          ownerKey,
          waits >= lostAfter ? MeetingProblem.expired : null,
          retryAt: clock().add(pause(waits)),
          attempts: 0,
          waits: waits,
        );
        continue;
      }
      final language = answer.result!.language ?? meeting.language;
      final noteId = await store.saveNote(
        meeting,
        answer.result!,
        labels: MeetingHooks.labels(language),
      );
      if (noteId == null) continue;
      final current = await store.meeting(meeting.id, ownerKey);
      final note = SavedMeetingNote(
        meetingId: meeting.id,
        ownerKey: ownerKey,
        noteId: noteId,
        title: current?.title ?? answer.result!.title,
        language: language,
      );
      saved.add(note);
      try {
        await MeetingHooks.notesReady(note);
      } catch (_) {
        /* The note is saved; only the notification failed. */
      }
      try {
        await _delete(meeting.id);
      } on ApiException catch (error) {
        final current = await store.meeting(meeting.id, ownerKey);
        if (current != null && await _failed(current, error)) return true;
      }
    }
    return false;
  }
}

class _Offline implements Exception {
  const _Offline();
}
