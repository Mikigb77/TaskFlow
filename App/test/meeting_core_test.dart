import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/meeting_api.dart';
import 'package:agenda/services/meeting_controller.dart';
import 'package:agenda/services/meeting_note.dart';
import 'package:agenda/services/meeting_recorder.dart';
import 'package:agenda/services/meeting_store.dart';
import 'package:agenda/services/meeting_uploader.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/note_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/meeting_fakes.dart';

const owner = 'https://api.example.invalid/users/7';
const other = 'https://api.example.invalid/users/8';
const notice = MeetingNotice(title: 'Recording');

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late Database sql;
  late TaskDatabase database;
  late MeetingStore store;
  late FakeClock clock;
  late FakeMeetingAudio audio;
  late FakeMeetingApi api;
  late MeetingRecorder recorder;

  /// The recorder's cap timers, which the test fires.
  late List<FakeTimer> timers;

  MeetingRecorder newRecorder({MeetingPieceRules? rules, Future<int?> Function()? free}) =>
      MeetingRecorder(
        store: store,
        engine: audio,
        clock: clock.call,
        rules: rules ?? const MeetingPieceRules(),
        freeBytes: free,
        timer: (after, then) {
          final timer = FakeTimer(after, then);
          timers.add(timer);
          return timer;
        },
      );

  MeetingUploader uploader([String key = owner, String? holder]) =>
      MeetingUploader(
        store: store,
        api: api,
        ownerKey: key,
        clock: clock.call,
        holder: holder,
      );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('taskflow-meetings-');
    sql = await databaseFactoryFfi.openDatabase(p.join(directory.path, 'm.db'));
    await sql.execute(
      'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
    );
    await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
    database = TaskDatabase.forTesting(sql);
    store = MeetingStore(database, directory: Directory(p.join(directory.path, 'audio')));
    clock = FakeClock();
    audio = FakeMeetingAudio();
    api = FakeMeetingApi();
    timers = [];
    recorder = newRecorder();
    MeetingHooks.labels = (_) => MeetingNoteLabels.none;
    MeetingHooks.notesReady = (_) async {};
  });

  tearDown(() async {
    await sql.close();
    await directory.delete(recursive: true);
  });

  /// [length] of the level [db], one level a second.
  Future<void> hear(
    MeetingRecorder recorder,
    double db,
    Duration length, {
    Duration step = const Duration(seconds: 1),
  }) async {
    for (var t = Duration.zero; t < length; t += step) {
      clock.advance(step);
      audio.hear(db);
      await Future<void>.delayed(Duration.zero);
      await recorder.settle();
    }
  }

  const speech = -20.0;
  const silence = -80.0;

  Future<List<MeetingPiece>> piecesOf(String id, [String key = owner]) =>
      store.pieces(id, key);

  /// A stopped meeting of [count] pieces, each 5 minutes, ready to upload.
  Future<Meeting> stoppedMeeting({int count = 1, String key = owner}) async {
    final recorder = newRecorder(
      rules: const MeetingPieceRules(
        target: Duration(seconds: 10),
        cap: Duration(seconds: 12),
      ),
    );
    final meeting = await recorder.start(key, notice: notice);
    for (var i = 0; i < count; i++) {
      await hear(recorder, speech, const Duration(seconds: 12));
    }
    await recorder.stop();
    final stopped = (await store.meeting(meeting.id, key))!;
    expect(stopped.phase, MeetingPhase.finishing);
    return stopped;
  }

  group('recording into pieces (MN-1 to MN-5)', () {
    test('a piece is cut at the first pause after 5 minutes, with its offset and duration', () async {
      final meeting = await recorder.start(owner, notice: notice, language: 'es');
      expect(meeting.format, MeetingAudioFormat.opus);
      expect(audio.notices.single.title, 'Recording');
      await hear(recorder, speech, const Duration(minutes: 5, seconds: 10));
      // Still talking: not cut mid-word.
      expect((await piecesOf(meeting.id)).single.state, MeetingPiece.recording);
      await hear(recorder, silence, const Duration(seconds: 2));
      final pieces = await piecesOf(meeting.id);
      expect(pieces, hasLength(2));
      expect(pieces[0].state, MeetingPiece.pending);
      expect(pieces[0].index, 0);
      expect(pieces[0].offset, Duration.zero);
      expect(pieces[0].duration, const Duration(minutes: 5, seconds: 12));
      expect(pieces[1].state, MeetingPiece.recording);
      expect(pieces[1].index, 1);
      expect(pieces[1].offset, const Duration(minutes: 5, seconds: 12));
      expect(audio.files, hasLength(2));
      expect(p.extension(audio.files.last), '.ogg');
      expect(recorder.current!.elapsed, const Duration(minutes: 5, seconds: 12));
      await recorder.stop();
    });

    test('a piece is cut at 6 minutes whatever is said', () async {
      final meeting = await recorder.start(owner, notice: notice);
      await hear(recorder, speech, const Duration(minutes: 6, seconds: 1));
      final pieces = await piecesOf(meeting.id);
      expect(pieces.first.duration, const Duration(minutes: 6));
      expect(pieces.last.offset, const Duration(minutes: 6));
    });

    test('a timer cuts the piece at 6 minutes too, when no level comes to do it', () async {
      final meeting = await recorder.start(owner, notice: notice);
      expect(timers.single.after, const Duration(minutes: 6));
      await hear(recorder, speech, const Duration(seconds: 30));
      // The levels stop coming; the timer still ends the piece at the cap,
      // so it never passes the server's 600 seconds.
      clock.advance(const Duration(minutes: 5, seconds: 30));
      timers.single.fire();
      await recorder.settle();
      final pieces = await piecesOf(meeting.id);
      expect(pieces, hasLength(2));
      expect(pieces[0].state, MeetingPiece.pending);
      expect(pieces[0].duration, const Duration(minutes: 6));
      expect(pieces[1].offset, const Duration(minutes: 6));
      expect(audio.files, hasLength(2));
      // The next piece has its own timer; the old one does nothing more.
      expect(timers, hasLength(2));
      expect(timers.first.isActive, isFalse);
      expect(timers.last.after, const Duration(minutes: 6));
      timers.first.fire();
      await recorder.settle();
      expect(await piecesOf(meeting.id), hasLength(2));
      await recorder.stop();
      expect(timers.last.isActive, isFalse, reason: 'cancelled at Stop');
    });

    test('a piece cut at a pause re-arms the timer from the new piece', () async {
      await recorder.start(owner, notice: notice);
      await hear(recorder, speech, const Duration(minutes: 5, seconds: 10));
      await hear(recorder, silence, const Duration(seconds: 2));
      expect(timers, hasLength(2));
      expect(timers.first.isActive, isFalse);
      expect(timers.last.after, const Duration(minutes: 6));
      await recorder.stop();
    });

    test('a piece of only silence is left out, and the next takes its number', () async {
      final meeting = await recorder.start(owner, notice: notice);
      await hear(recorder, silence, const Duration(minutes: 5, seconds: 2));
      var pieces = await piecesOf(meeting.id);
      // Held on the phone, never sent, until a piece with sound (UX-2717).
      expect(pieces, hasLength(2));
      expect(pieces.first.state, MeetingPiece.held);
      expect(pieces.last.index, 0);
      expect(pieces.last.offset, const Duration(minutes: 5));
      expect(File(audio.files.first).existsSync(), isTrue, reason: 'held');
      await hear(recorder, speech, const Duration(seconds: 30));
      final stopped = await recorder.stop();
      expect(stopped!.phase, MeetingPhase.finishing);
      expect(stopped.lastIndex, 0);
      pieces = await piecesOf(meeting.id);
      expect(pieces.single.state, MeetingPiece.pending);
      expect(pieces.single.offset, const Duration(minutes: 5));
      expect(pieces.single.duration, const Duration(seconds: 32));
      expect(File(audio.files.first).existsSync(), isFalse, reason: 'left out');
    });

    test('a meeting of only silence keeps nothing at Stop', () async {
      final meeting = await recorder.start(owner, notice: notice);
      await hear(recorder, silence, const Duration(seconds: 20));
      expect(await recorder.stop(), isNull);
      expect((await store.meeting(meeting.id, owner))!.phase, MeetingPhase.discarding);
      expect(await piecesOf(meeting.id), isEmpty);
      expect(audio.files.every((path) => !File(path).existsSync()), isTrue);
    });

    test('the level and elapsed time are published while recording, and cleared at Stop', () async {
      final statuses = <MeetingRecordingStatus?>[];
      final sub = recorder.status.listen(statuses.add);
      await recorder.start(owner, notice: notice);
      await hear(recorder, -30, const Duration(seconds: 3));
      await recorder.stop();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(statuses.whereType<MeetingRecordingStatus>().last.elapsed, const Duration(seconds: 3));
      expect(statuses.whereType<MeetingRecordingStatus>().last.level, closeTo(0.5, 0.01));
      expect(statuses.last, isNull);
    });

    test('low space stops the recording safely, keeping what was recorded (MN-6)', () async {
      var free = 500 * 1024 * 1024;
      final ended = <MeetingRecorderEnd>[];
      final recorder = MeetingRecorder(
        store: store,
        engine: audio,
        clock: clock.call,
        rules: const MeetingPieceRules(target: Duration(seconds: 10), cap: Duration(seconds: 12)),
        freeBytes: () async => free,
        onEnded: (_, end) => ended.add(end),
      );
      expect(await recorder.hasRoom(), isTrue);
      final meeting = await recorder.start(owner, notice: notice);
      free = 50 * 1024 * 1024;
      await hear(recorder, speech, const Duration(seconds: 13));
      await pumpEventQueue();
      for (var i = 0; i < 20 && recorder.recording; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      for (var i = 0; i < 20 && ended.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(ended, [MeetingRecorderEnd.lowSpace]);
      expect(recorder.recording, isFalse);
      final stopped = (await store.meeting(meeting.id, owner))!;
      expect(stopped.phase, MeetingPhase.finishing);
      expect((await piecesOf(meeting.id)).single.state, MeetingPiece.pending);
    });

    test('low space with only silence recorded keeps nothing, and says so', () async {
      final ended = <MeetingRecorderEnd>[];
      final recorder = MeetingRecorder(
        store: store,
        engine: audio,
        clock: clock.call,
        rules: const MeetingPieceRules(target: Duration(seconds: 10), cap: Duration(seconds: 12)),
        freeBytes: () async => 50 * 1024 * 1024,
        onEnded: (_, end) => ended.add(end),
        timer: (after, then) => FakeTimer(after, then),
      );
      final meeting = await recorder.start(owner, notice: notice);
      await hear(recorder, silence, const Duration(seconds: 13));
      for (var i = 0; i < 20 && ended.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(ended, [MeetingRecorderEnd.empty]);
      expect(recorder.recording, isFalse);
      expect(await store.finishable(owner, clock.now), isEmpty);
      expect(await piecesOf(meeting.id), isEmpty);
    });

    test('Discard deletes the pieces on the phone at once (MN-25)', () async {
      final meeting = await stoppedMeeting(count: 2);
      expect(await piecesOf(meeting.id), hasLength(2));
      await store.discard(meeting.id, owner);
      expect(await piecesOf(meeting.id), isEmpty);
      expect(Directory(p.join(directory.path, 'audio', meeting.id)).existsSync(), isFalse);
      await uploader().run();
      expect(api.kinds(), ['delete']);
      expect(await store.meeting(meeting.id, owner), isNull);
    });
  });

  group('uploading (MN-8 to MN-11)', () {
    test('a piece is deleted only after the server confirmed it saved', () async {
      final meeting = await stoppedMeeting();
      final piece = (await piecesOf(meeting.id)).single;
      api.onPiece = (_) async => const MeetingPieceAnswer(saved: false, status: 'recording');
      await uploader().run();
      expect(File(piece.path).existsSync(), isTrue, reason: 'not confirmed');
      expect((await piecesOf(meeting.id)).single.state, MeetingPiece.pending);
      api.onPiece = (_) async => throw offline();
      clock.advance(const Duration(hours: 1));
      final pass = await uploader().run();
      expect(pass.offline, isTrue);
      expect(File(piece.path).existsSync(), isTrue, reason: 'no signal');
      expect((await store.meeting(meeting.id, owner))!.waitingForSignal, isTrue);
      api.onPiece = null;
      clock.advance(const Duration(hours: 1));
      await uploader().run();
      expect(File(piece.path).existsSync(), isFalse);
    });

    test('failures are tried again after growing pauses, or the server’s Retry-After', () async {
      final meeting = await stoppedMeeting();
      api.onPiece = (_) async => throw ApiException(503, 'busy');
      final waits = <Duration>[];
      for (var i = 0; i < 4; i++) {
        await uploader().run();
        final piece = (await piecesOf(meeting.id)).single;
        waits.add(piece.retryAt!.difference(clock.now));
        // Not due yet: nothing is sent.
        final calls = api.calls.length;
        await uploader().run();
        expect(api.calls.length, calls);
        clock.now = piece.retryAt!;
      }
      expect(waits, const [
        Duration(seconds: 10),
        Duration(seconds: 20),
        Duration(seconds: 40),
        Duration(seconds: 80),
      ]);
      expect(MeetingUploader.pause(20), MeetingUploader.maxPause);
      api.onPiece = (_) async =>
          throw ApiException(429, 'slow down', {}, const Duration(minutes: 3));
      await uploader().run();
      final piece = (await piecesOf(meeting.id)).single;
      expect(piece.retryAt!.difference(clock.now), const Duration(minutes: 3));
      expect((await store.meeting(meeting.id, owner))!.problem, MeetingProblem.server);
    });

    test('a backlog uploads two pieces at a time (MN-9)', () async {
      final meeting = await stoppedMeeting(count: 6);
      expect(await piecesOf(meeting.id), hasLength(6));
      final gates = <Completer<void>>[];
      api.onPiece = (_) async {
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        return const MeetingPieceAnswer(saved: true, status: 'waiting');
      };
      final run = uploader().run();
      for (var opened = 0; opened < 6; opened++) {
        while (gates.length <= opened) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        if (opened == 0) {
          // The server hasn't heard of the meeting: its first piece goes
          // alone, so the server never takes piece 1 for its start.
          await Future<void>.delayed(const Duration(milliseconds: 50));
          expect(api.inFlight, 1);
          expect(api.calls.single.index, 0);
        }
        expect(api.inFlight, lessThanOrEqualTo(2));
        gates[opened].complete();
      }
      await run;
      expect(api.maxInFlight, 2);
      expect(api.received[meeting.id], {0, 1, 2, 3, 4, 5});
      expect(api.calls.last.kind, 'delete');
    });

    test('until the server confirms a piece, only the lowest waiting piece goes, alone (MN-9)', () async {
      final meeting = await stoppedMeeting(count: 3);
      api.onPiece = (_) async => throw ApiException(503, 'busy');
      final pass = await uploader().run();
      // The first piece failed: the others wait for it, not beside it.
      expect(api.calls.map((call) => '${call.kind} ${call.index}'), ['piece 0']);
      clock.now = pass.nextDue!;
      api.calls.clear();
      final gates = <int, Completer<void>>{};
      api.onPiece = (piece) async {
        final gate = gates[piece.index] = Completer<void>();
        await gate.future;
        return const MeetingPieceAnswer(saved: true, status: 'recording');
      };
      final run = uploader().run();
      while (gates.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(gates.keys, [0]);
      expect(api.inFlight, 1);
      gates[0]!.complete();
      // Confirmed: the rest go two at a time.
      while (gates.length < 3) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(api.inFlight, 2);
      gates[1]!.complete();
      gates[2]!.complete();
      await run;
      expect(api.received[meeting.id], {0, 1, 2});
      expect(api.kinds().last, 'delete');
    });

    test('finish goes only once no piece of the meeting is uploading', () async {
      await stoppedMeeting(count: 3);
      final uploading = <int>[];
      api.onFinish = (id, last) async {
        uploading.add(api.inFlight);
        return MeetingAnswer(status: 'ready', result: api.result);
      };
      // The last piece is the slowest to answer.
      api.onPiece = (piece) async {
        await Future<void>.delayed(Duration(milliseconds: 20 * piece.index));
        return const MeetingPieceAnswer(saved: true, status: 'recording');
      };
      await uploader().run();
      expect(uploading, [0]);
      expect(api.kinds(), ['piece', 'piece', 'piece', 'finish', 'delete']);
    });

    test('while the app uploads a piece, the background worker never finishes the meeting', () async {
      final meeting = await stoppedMeeting(count: 2);
      api.received[meeting.id] = {0};
      await store.pieceSaved((await piecesOf(meeting.id)).first);
      final gate = Completer<void>();
      api.onPiece = (_) async {
        await gate.future;
        return const MeetingPieceAnswer(saved: true, status: 'waiting');
      };
      final app = uploader(owner, 'app').run();
      while (api.inFlight == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final background = await uploader(owner, 'background').run();
      expect(background.busy, isTrue);
      expect(api.kinds(), ['piece']);
      gate.complete();
      await app;
      expect(api.kinds(), ['piece', 'finish', 'delete']);
    });

    test('finish waits, is repeated, and the ready notes become an ordinary note; then DELETE', () async {
      final meeting = await stoppedMeeting(count: 2);
      final ready = <SavedMeetingNote>[];
      MeetingHooks.notesReady = (saved) async => ready.add(saved);
      var finishes = 0;
      api.onFinish = (id, last) async {
        finishes++;
        return finishes == 1
            ? const MeetingAnswer(status: 'waiting', missing: [1])
            : MeetingAnswer(status: 'ready', result: api.result);
      };
      var pass = await uploader().run();
      expect(api.kinds(), ['piece', 'piece', 'finish']);
      expect(api.calls.last.lastIndex, 1);
      expect(pass.saved, isEmpty);
      expect((await store.meeting(meeting.id, owner))!.phase, MeetingPhase.finishing);
      expect(pass.nextDue, clock.now.add(const Duration(seconds: 10)));
      clock.advance(const Duration(seconds: 10));
      pass = await uploader().run();
      expect(api.kinds(), ['piece', 'piece', 'finish', 'finish', 'delete']);
      expect(pass.saved, hasLength(1));
      expect(ready.single.title, 'Pilot pricing with Acme');
      final tasks = await database.getTasks(ownerKey: owner);
      final note = tasks.single;
      expect(note.id, pass.saved.single.noteId);
      expect(note.kind, 'note');
      expect(note.title, 'Pilot pricing with Acme');
      expect(note.notes, contains('We agreed the pilot. Pricing comes next.'));
      expect(note.notes, contains('• Start the pilot in December'));
      expect(note.notes, contains('• Who signs for Acme?'));
      expect(note.notes, contains('Introductions and scope\nScope is the warehouse.'));
      expect(note.checklist.map((item) => item.title), [
        'Send the pilot quote · Miki · Friday',
        'Book the room',
      ]);
      final rows = await sql.query('tasks', where: 'id = ?', whereArgs: [note.id]);
      expect(rows.single['sync_pending'], 1, reason: 'synced like any note');
      final done = (await store.meeting(meeting.id, owner))!;
      expect(done.phase, MeetingPhase.done);
      expect(done.noteId, note.id);
      expect(await piecesOf(meeting.id), isEmpty);
      expect(Directory(p.join(directory.path, 'audio', meeting.id)).existsSync(), isFalse);
      expect(pass.nextDue, isNull);
      await store.markSeen(meeting.id, owner);
      expect(await store.meeting(meeting.id, owner), isNull);
    });

    test('a lost DELETE is sent again, and the note is never saved twice', () async {
      final meeting = await stoppedMeeting();
      api.onDelete = (_) async => throw offline();
      final pass = await uploader().run();
      expect(pass.saved, hasLength(1));
      expect(pass.offline, isTrue);
      expect((await store.meeting(meeting.id, owner))!.phase, MeetingPhase.saved);
      expect(await store.saveNote(meeting, api.result), pass.saved.single.noteId);
      api.onDelete = null;
      clock.advance(const Duration(minutes: 1));
      final again = await uploader().run();
      expect(again.saved, isEmpty);
      expect(api.kinds().where((kind) => kind == 'delete'), hasLength(2));
      expect((await store.meeting(meeting.id, owner))!.phase, MeetingPhase.done);
      expect(await database.getTasks(ownerKey: owner), hasLength(1));
    });

    test('a DELETE refused without Pro (402) ends at once: no retries, nothing kept here', () async {
      final saved = await stoppedMeeting();
      final discarded = await stoppedMeeting();
      await store.discard(discarded.id, owner);
      api.onDelete = (_) async => throw ApiException(402, 'pro', {'code': 'pro_required'});
      final pass = await uploader().run();
      expect(pass.saved.single.meetingId, saved.id);
      expect(pass.offline, isFalse);
      expect(api.kinds().where((kind) => kind == 'delete'), hasLength(2));
      // The discarded meeting is gone; the saved one waits only to be seen.
      expect(await store.meeting(discarded.id, owner), isNull);
      expect((await store.meeting(saved.id, owner))!.phase, MeetingPhase.done);
      expect(pass.nextDue, isNull);
      clock.advance(MeetingUploader.maxPause * 2);
      await uploader().run();
      expect(api.kinds().where((kind) => kind == 'delete'), hasLength(2));
    });

    test('Pro bought or restored sends a meeting held for Pro at once', () async {
      final meeting = await stoppedMeeting(count: 2);
      final allowance = await stoppedMeeting();
      api.onPiece = (piece) async => throw ApiException(
        402,
        'pro',
        {'code': piece.meetingId == allowance.id ? 'meeting_allowance_used' : 'pro_required'},
      );
      await uploader().run();
      expect((await store.meeting(meeting.id, owner))!.problem, MeetingProblem.proRequired);
      api.onPiece = null;
      api.calls.clear();
      await store.retryNow(owner, proGained: true);
      expect((await store.meeting(meeting.id, owner))!.problem, isNull);
      final pass = await uploader().run();
      expect(pass.saved.map((note) => note.meetingId), [meeting.id]);
      // Pro doesn't give back the month's time: that one still waits.
      expect((await store.meeting(allowance.id, owner))!.problem, MeetingProblem.allowanceUsed);
    });

    test('402 holds a meeting back without losing a piece; 409 meeting_finished counts as sent', () async {
      final meeting = await stoppedMeeting(count: 4);
      api.onPiece = (_) async => throw ApiException(402, 'allowance', {'code': 'meeting_allowance_used'});
      await uploader().run();
      var stored = (await store.meeting(meeting.id, owner))!;
      expect(stored.problem, MeetingProblem.allowanceUsed);
      // Its other pieces wait too.
      expect(api.kinds(), ['piece']);
      expect((await piecesOf(meeting.id)).every((piece) => File(piece.path).existsSync()), isTrue);
      clock.advance(const Duration(hours: 1));
      await uploader().run();
      expect(api.kinds(), ['piece']);
      clock.advance(MeetingUploader.blockedPause);
      var first = true;
      api.onPiece = (_) async {
        if (first) {
          first = false;
          return const MeetingPieceAnswer(saved: true, status: 'waiting');
        }
        throw ApiException(409, 'finished', {'code': 'meeting_finished'});
      };
      await uploader().run();
      stored = (await store.meeting(meeting.id, owner))!;
      expect(stored.waitingPieces, 0);
      expect(stored.problem, isNot(MeetingProblem.allowanceUsed));
    });

    test('pieces the server lost can’t become notes: the meeting says so and stops asking', () async {
      final meeting = await stoppedMeeting();
      api.onFinish = (id, last) async => const MeetingAnswer(status: 'waiting', missing: [0]);
      MeetingPass? pass;
      for (var i = 0; i < MeetingUploader.lostAfter; i++) {
        pass = await uploader().run();
        clock.now = pass.nextDue ?? clock.now;
      }
      final stored = (await store.meeting(meeting.id, owner))!;
      expect(stored.problem, MeetingProblem.expired);
      expect(pass!.nextDue, isNull);
      expect(api.kinds().where((kind) => kind == 'finish'), hasLength(MeetingUploader.lostAfter));
    });

    test('waiting with nothing missing is the notes being written: asked again, never lost', () async {
      final meeting = await stoppedMeeting();
      var answers = 0;
      api.onFinish = (id, last) async => ++answers <= MeetingUploader.lostAfter + 2
          ? const MeetingAnswer(status: 'waiting')
          : MeetingAnswer(status: 'ready', result: api.result);
      MeetingPass? pass;
      for (var i = 0; i < MeetingUploader.lostAfter + 3; i++) {
        pass = await uploader().run();
        final stored = (await store.meeting(meeting.id, owner))!;
        expect(stored.problem, isNot(MeetingProblem.expired));
        expect(stored.waits, 0);
        if (pass.nextDue == null) break;
        clock.now = pass.nextDue!;
      }
      expect(answers, MeetingUploader.lostAfter + 3);
      expect(pass!.saved, hasLength(1));
    });

    test('a 401 stops the pass for this account', () async {
      await stoppedMeeting(count: 2);
      api.onPiece = (_) async => throw ApiException(401, 'Sign in to this account to transfer files.');
      final pass = await uploader().run();
      expect(pass.stopped, isTrue);
      expect(pass.idle, isTrue);
    });

    test('only one uploader sends at a time: the app or its background worker', () async {
      await stoppedMeeting();
      expect(await store.acquireLease(owner, 'background', clock.now), isTrue);
      final pass = await uploader(owner, 'app').run();
      expect(pass.busy, isTrue);
      expect(api.calls, isEmpty);
      clock.advance(const Duration(minutes: 6));
      expect((await uploader(owner, 'app').run()).saved, hasLength(1));
    });
  });

  group('recovery (MN-12, MN-13, MN-26)', () {
    test('a recording killed mid-piece is found on start, kept to its last heartbeat, and continues', () async {
      final meeting = await recorder.start(owner, notice: notice);
      await hear(recorder, speech, const Duration(minutes: 5, seconds: 20));
      await hear(recorder, silence, const Duration(seconds: 2));
      await hear(recorder, speech, const Duration(minutes: 1, seconds: 42));
      // The process dies: no Stop, nothing closes the piece.
      audio.reset();
      clock.advance(const Duration(hours: 3));
      final restarted = newRecorder();
      final found = await store.recoverInterrupted(owner, active: restarted.meetingId);
      expect(found.single.id, meeting.id);
      final stopped = found.single;
      expect(stopped.phase, MeetingPhase.interrupted);
      final pieces = await piecesOf(meeting.id);
      expect(pieces.map((piece) => piece.state), [MeetingPiece.pending, MeetingPiece.pending]);
      expect(pieces[1].offset, const Duration(minutes: 5, seconds: 22));
      // The last heartbeat was at 1:40 into the second piece.
      expect(pieces[1].duration, const Duration(minutes: 1, seconds: 40));
      expect(stopped.recorded, const Duration(minutes: 7, seconds: 2));
      expect(stopped.stoppedAt, clock.now.subtract(const Duration(hours: 3, seconds: 2)));
      expect(stopped.nextIndex, 2);
      // Its pieces still upload while it waits for an answer.
      expect(await store.duePieces(owner, clock.now), hasLength(2));

      await restarted.resume(meeting.id, owner, notice: notice);
      expect(restarted.current!.elapsed, const Duration(minutes: 7, seconds: 2));
      await hear(restarted, speech, const Duration(seconds: 30));
      final finished = (await restarted.stop())!;
      final after = await piecesOf(meeting.id);
      expect(after.last.index, 2);
      expect(after.last.offset, const Duration(minutes: 7, seconds: 2));
      expect(after.last.duration, const Duration(seconds: 30));
      expect(finished.lastIndex, 2);
      expect(finished.phase, MeetingPhase.finishing);
    });

    test('a recording killed before any heartbeat keeps nothing it can’t send', () async {
      final meeting = await recorder.start(owner, notice: notice);
      await hear(recorder, speech, const Duration(seconds: 3));
      audio.reset();
      final found = await store.recoverInterrupted(owner);
      expect(found.single.phase, MeetingPhase.interrupted);
      expect(await piecesOf(meeting.id), isEmpty);
      expect(found.single.empty, isTrue);
      expect(await store.finish(meeting.id, owner, clock.now), isNull, reason: 'nothing to finish');
    });

    test('the meeting being recorded is not taken for an interrupted one', () async {
      final meeting = await recorder.start(owner, notice: notice);
      expect(await store.recoverInterrupted(owner, active: meeting.id), isEmpty);
      expect((await store.meeting(meeting.id, owner))!.phase, MeetingPhase.recording);
    });

    test('a microphone failure leaves the meeting stopped unexpectedly', () async {
      final ended = <MeetingRecorderEnd>[];
      final recorder = MeetingRecorder(
        store: store,
        engine: audio,
        clock: clock.call,
        onEnded: (_, end) => ended.add(end),
      );
      final meeting = await recorder.start(owner, notice: notice);
      await hear(recorder, speech, const Duration(seconds: 8));
      audio.fail();
      for (var i = 0; i < 50 && ended.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(ended, [MeetingRecorderEnd.failed]);
      final stopped = (await store.meeting(meeting.id, owner))!;
      expect(stopped.phase, MeetingPhase.interrupted);
      expect((await piecesOf(meeting.id)).single.duration, const Duration(seconds: 8));
    });

    test('Finish and Discard answer a stopped recording', () async {
      final first = await recorder.start(owner, notice: notice);
      await hear(recorder, speech, const Duration(seconds: 12));
      await recorder.suspend();
      expect((await store.meeting(first.id, owner))!.phase, MeetingPhase.interrupted);
      final finished = (await store.finish(first.id, owner, clock.now))!;
      expect(finished.phase, MeetingPhase.finishing);
      expect(finished.lastIndex, 0);

      final second = await recorder.start(owner, notice: notice);
      await hear(recorder, speech, const Duration(seconds: 12));
      await recorder.suspend();
      await store.discard(second.id, owner);
      await uploader().run();
      expect(await store.meeting(second.id, owner), isNull);
      expect(api.calls.where((call) => call.meetingId == second.id).map((call) => call.kind), ['delete']);
      expect((await store.meeting(first.id, owner))!.phase, MeetingPhase.done);
    });

    test('a stopped recording left 7 days without an answer is finished into a note', () async {
      final meeting = await recorder.start(owner, notice: notice);
      await hear(recorder, speech, const Duration(seconds: 12));
      await recorder.suspend();
      // Never asked about yet: it waits, however long.
      clock.advance(const Duration(days: 30));
      expect(await store.autoFinishStale(owner, clock.now), isEmpty);
      // The app shows it: the 7 days start.
      await store.markAsked(owner, clock.now);
      clock.advance(const Duration(days: 6, hours: 23));
      expect(await store.autoFinishStale(owner, clock.now), isEmpty);
      expect((await store.meeting(meeting.id, owner))!.phase, MeetingPhase.interrupted);
      clock.advance(const Duration(hours: 2));
      expect((await store.autoFinishStale(owner, clock.now)).single.id, meeting.id);
      final pass = await uploader().run();
      expect(pass.saved.single.meetingId, meeting.id);
      expect((await database.getTasks(ownerKey: owner)).single.isNote, isTrue);
    });

    test('pieces belong to one account and upload only with its login', () async {
      final mine = await stoppedMeeting(key: owner);
      final theirs = await stoppedMeeting(key: other);
      expect(await store.meeting(theirs.id, owner), isNull);
      expect(await store.duePieces(owner, clock.now), hasLength(1));
      await uploader(owner).run();
      expect(api.calls.map((call) => call.meetingId).toSet(), {mine.id});
      expect((await store.meeting(theirs.id, other))!.waitingPieces, 1);
      expect(await database.getTasks(ownerKey: other), isEmpty);
      expect((await database.getTasks(ownerKey: owner)).single.title, 'Pilot pricing with Acme');
    });

    test('signing out sees the pieces still waiting for this account, and can discard them', () async {
      await stoppedMeeting(count: 2);
      final interrupted = await recorder.start(owner, notice: notice);
      await hear(recorder, speech, const Duration(seconds: 12));
      await recorder.suspend();
      await stoppedMeeting(key: other);
      var backlog = await store.backlog(owner);
      expect(backlog.meetings, 2);
      expect(backlog.pieces, 3);
      await store.discardAll(owner);
      backlog = await store.backlog(owner);
      expect(backlog.isEmpty, isTrue);
      expect((await store.backlog(other)).pieces, 1, reason: 'another account’s stay');
      expect((await store.meeting(interrupted.id, owner))!.phase, MeetingPhase.discarding);
    });
  });

  group('the note (MN-21, MN-28)', () {
    test('labels from the screens head the sections; a start that expired is said first', () {
      final note = meetingNote(
        const MeetingResult(
          title: '',
          summary: 'Short. Then more.',
          decisions: ['Yes'],
          openQuestions: ['Who?'],
          chapters: [MeetingChapter(startMinute: 30, endMinute: 60, title: 'Pricing')],
          startMissing: true,
        ),
        labels: const MeetingNoteLabels(
          decisions: 'Decisions',
          openQuestions: 'Open questions',
          chapters: 'Chapters',
          startMissing: 'The start of this recording expired.',
          untitled: 'Meeting',
        ),
        projectId: 'p1',
      );
      expect(note.title, 'Meeting');
      expect(note.listId, 'p1');
      expect(
        note.notes,
        'The start of this recording expired.\n\nShort. Then more.\n\n'
        'Decisions\n• Yes\n\nOpen questions\n• Who?\n\nChapters\n\nPricing',
      );
      expect(note.checklist, isEmpty);
      final bare = meetingNote(const MeetingResult(summary: 'Short. Then more.'), labels: MeetingNoteLabels.none);
      expect(bare.title, 'Short.');
      expect(bare.notes, 'Short. Then more.');
    });

    test('D1: a saved meeting note is marked as a meeting\'s on this phone, for its account only', () async {
      final meeting = await store.create(owner, format: MeetingAudioFormat.opus, now: clock.now);
      final path = await store.piecePath(meeting.id, Duration.zero, meeting.format);
      await store.openPiece(meeting, index: 0, offset: Duration.zero, path: path, now: clock.now);
      await store.closePiece(meeting, index: 0, duration: const Duration(seconds: 30), hasSound: true, now: clock.now);
      final stopped = (await store.finish(meeting.id, owner, clock.now))!;
      expect(await MeetingNoteMarks.read(database, owner), isEmpty);
      final id = await store.saveNote(stopped, api.result);
      expect(await MeetingNoteMarks.read(database, owner), {id});
      expect(await MeetingNoteMarks.read(database, 'someone-else'), isEmpty);
      // Saving again keeps one mark.
      await store.saveNote(stopped, api.result);
      expect(await MeetingNoteMarks.read(database, owner), {id});
    });

    test('a note for a project that went is saved outside it', () async {
      final meeting = await store.create(owner, format: MeetingAudioFormat.opus, now: clock.now, projectId: 'gone');
      final path = await store.piecePath(meeting.id, Duration.zero, meeting.format);
      await store.openPiece(meeting, index: 0, offset: Duration.zero, path: path, now: clock.now);
      await store.closePiece(meeting, index: 0, duration: const Duration(seconds: 30), hasSound: true, now: clock.now);
      final stopped = (await store.finish(meeting.id, owner, clock.now))!;
      final id = await store.saveNote(stopped, api.result);
      final note = (await database.getTasks(ownerKey: owner)).single;
      expect(note.id, id);
      expect(note.listId, isNull);
    });

    test('the result is read leniently', () {
      final result = MeetingResult.fromJson({
        'title': 'T',
        'summary': null,
        'todos': [
          {'text': 'Do it', 'who': null, 'when': ' '},
          {'text': ''},
          'junk',
        ],
        'decisions': ['A', 3, ''],
        'chapters': [
          {'start_minute': 0, 'end_minute': 30.0, 'title': 'X'},
        ],
        'start_missing': true,
        'language': 'ca',
      });
      // A server from before tasks had steps: one task per to-do.
      expect(result.tasks.single.title, 'Do it');
      expect(result.tasks.single.when, isNull);
      expect(result.tasks.single.steps, isEmpty);
      expect(result.decisions, ['A']);
      expect(result.openQuestions, isEmpty);
      expect(result.chapters.single.endMinute, 30);
      expect(result.startMissing, isTrue);
      expect(result.language, 'ca');
      expect(MeetingAnswer.fromJson({'status': 'waiting', 'missing': [7, 8]}).missing, [7, 8]);
    });

    test('tasks come with their own steps, and win over the to-dos', () {
      final result = MeetingResult.fromJson({
        'tasks': [
          {'title': ' Acabar el front-end ', 'who': null, 'when': 'dilluns', 'steps': ['El bàner', ' ', 3, 'El backlog']},
          {'title': 'Trucar al client', 'who': 'jo', 'when': 'dilluns', 'steps': null},
          {'title': ''},
        ],
        'todos': [
          {'text': 'Acabar el front-end', 'who': null, 'when': 'dilluns'},
          {'text': 'Trucar al client', 'who': 'jo', 'when': 'dilluns'},
        ],
      });
      expect(result.tasks.map((task) => task.title), ['Acabar el front-end', 'Trucar al client']);
      expect(result.tasks.first.steps, ['El bàner', 'El backlog']);
      expect(result.tasks.last.steps, isEmpty);
      expect(result.tasks.last.who, 'jo');
    });

    test('one line per task, and each task\'s steps under its name in the body', () {
      final note = meetingNote(
        const MeetingResult(
          title: 'Setmana',
          summary: 'Parlem de la setmana.',
          tasks: [
            MeetingTask(title: 'Acabar el front-end', when: 'dilluns', steps: ['El bàner', 'El backlog']),
            MeetingTask(title: 'Trucar al client', who: 'jo', when: 'dilluns'),
          ],
          decisions: ['Endarrerir el lliurament'],
        ),
        labels: const MeetingNoteLabels(steps: 'Passos de cada tasca', decisions: 'Decisions'),
      );
      expect(note.checklist.map((line) => line.title), [
        'Acabar el front-end · dilluns',
        'Trucar al client · jo · dilluns',
      ]);
      expect(
        note.notes,
        'Parlem de la setmana.\n\n'
        'Passos de cada tasca\n\nAcabar el front-end\n• El bàner\n• El backlog\n\n'
        'Decisions\n• Endarrerir el lliurament',
      );
      final tasks = MeetingNoteTasks.of(
        note,
        const MeetingResult(tasks: [
          MeetingTask(title: 'Acabar el front-end', when: 'dilluns', steps: ['El bàner', 'El backlog']),
          MeetingTask(title: 'Trucar al client', who: 'jo', when: 'dilluns'),
        ]),
        startedAt: DateTime(2026, 11, 5, 16, 19),
      );
      final read = MeetingNoteTasks.fromJson(jsonDecode(jsonEncode(tasks.toJson())))!;
      expect(read.day, DateTime(2026, 11, 5));
      expect(read.tasks.keys, note.checklist.map((line) => line.id));
      expect(read.tasks[note.checklist.first.id]!.steps, ['El bàner', 'El backlog']);
    });

    test('«Crear tareas»: a line becomes its task, its steps and the day its words say, from the meeting\'s day', () {
      // Thursday 5 November 2026, the meeting's day and today.
      final day = DateTime(2026, 11, 5);
      Task make(ChecklistItem line, MeetingTask? task, {DateTime? today}) =>
          noteLineTask(line, task, day: day, today: today ?? day);
      const front = MeetingTask(title: 'Acabar el front-end', when: 'dilluns', steps: ['El bàner', 'El backlog']);
      final made = noteLineTask(ChecklistItem(id: 'a', title: meetingTaskLine(front)), front, day: day, today: day, projectId: 'p1');
      expect(made.title, 'Acabar el front-end');
      expect(made.dueDate, DateTime(2026, 11, 9));
      expect(made.hasTime, isFalse);
      expect(made.listId, 'p1');
      expect(made.checklist.map((step) => step.title), ['El bàner', 'El backlog']);
      // Ticked: chosen to go in.
      expect(made.checklist.every((step) => step.completed), isTrue);
      // Who stays in the title; the words of a day read whole leave it.
      const call = MeetingTask(title: 'Trucar al client', who: 'jo', when: 'el dimarts');
      final called = make(ChecklistItem(title: meetingTaskLine(call)), call);
      expect(called.title, 'Trucar al client · jo');
      expect(called.dueDate, DateTime(2026, 11, 10));
      // Words beyond the day stay, and the day still applies.
      const buy = MeetingTask(title: 'Comprar coixins', when: 'dissabte al matí');
      final bought = make(ChecklistItem(title: meetingTaskLine(buy)), buy);
      expect(bought.title, 'Comprar coixins · al matí');
      expect(bought.dueDate, DateTime(2026, 11, 7));
      // Words that aren't a day give none.
      const later = MeetingTask(title: 'Revisar-ho', when: 'la setmana que ve');
      expect(make(ChecklistItem(title: meetingTaskLine(later)), later).dueDate, isNull);
      // A day with a bare hour keeps the day, and the hour as words
      // (UX-3104).
      const five = MeetingTask(title: 'Trucar', when: 'demà a les 5');
      final called5 = make(ChecklistItem(title: meetingTaskLine(five)), five);
      expect(called5.dueDate, DateTime(2026, 11, 6));
      // A line the person reworded keeps their words and its steps; its
      // own words give the day (UX-3106).
      final reworded = make(ChecklistItem(title: 'Acabar la web'), front);
      expect((reworded.title, reworded.dueDate, reworded.checklist.length), ('Acabar la web', null, 2));
      // A note from before tasks had steps: its line's words still give the
      // day.
      final old = make(ChecklistItem(title: 'Send the quote · Friday'), null);
      expect((old.title, old.dueDate, old.checklist.length), ('Send the quote', DateTime(2026, 11, 6), 0));
      // Made a week later, a day already past isn't set (UX-3105).
      final late = make(ChecklistItem(title: meetingTaskLine(call)), call, today: DateTime(2026, 11, 12));
      expect((late.title, late.dueDate), ('Trucar al client · jo · el dimarts', null));
    });

    test('a saved meeting note keeps its tasks\' steps on this phone, by line', () async {
      final meeting = await store.create(owner, format: MeetingAudioFormat.opus, now: clock.now);
      final path = await store.piecePath(meeting.id, Duration.zero, meeting.format);
      await store.openPiece(meeting, index: 0, offset: Duration.zero, path: path, now: clock.now);
      await store.closePiece(meeting, index: 0, duration: const Duration(seconds: 30), hasSound: true, now: clock.now);
      final stopped = (await store.finish(meeting.id, owner, clock.now))!;
      final id = (await store.saveNote(stopped, api.result))!;
      final note = (await database.getTasks(ownerKey: owner)).single;
      final tasks = (await MeetingNoteMarks.tasks(database, owner, id))!;
      expect(tasks.tasks.keys, note.checklist.map((line) => line.id));
      expect(tasks.tasks.values.map((task) => task.steps), [
        ['Price for 20 seats', 'Start date'],
        <String>[],
      ]);
      expect(tasks.day, Task.day(stopped.startedAt.toLocal()));
      expect(await MeetingNoteMarks.tasks(database, 'someone-else', id), isNull);
    });
  });

  group('the app’s controller', () {
    test('on start it recovers an interrupted recording; Continue, Stop and the uploads follow', () async {
      final meeting = await recorder.start(owner, notice: notice);
      await hear(recorder, speech, const Duration(seconds: 20));
      audio.reset();
      final scheduler = FakeMeetingScheduler();
      final saved = <SavedMeetingNote>[];
      final controller = MeetingController(
        store: store,
        engine: audio,
        ownerKey: owner,
        api: api,
        scheduler: scheduler,
        clock: clock.call,
        onNotesSaved: saved.addAll,
        rules: const MeetingPieceRules(target: Duration(seconds: 10), cap: Duration(seconds: 12)),
      );
      addTearDown(controller.dispose);
      await controller.ready;
      expect(controller.state.stopped.single.id, meeting.id);
      expect(controller.state.stopped.single.recorded, const Duration(seconds: 20));

      await controller.continueMeeting(meeting.id, notice: notice);
      expect(controller.state.stopped, isEmpty);
      await hear(controller.recorder, speech, const Duration(seconds: 5));
      expect(controller.state.recording!.elapsed, const Duration(seconds: 25));
      await controller.stop();
      expect(controller.state.recording, isNull);
      expect(scheduler.scheduled, greaterThan(0));
      for (var i = 0; i < 100 && saved.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(saved.single.meetingId, meeting.id);
      await controller.refresh();
      expect(controller.state.ready.single.noteId, saved.single.noteId);
      await controller.markSeen(meeting.id);
      expect(controller.state.ready, isEmpty);
    });

    test('the screens watch providers: a stopped recording shows, and its pieces upload meanwhile', () async {
      final meeting = await recorder.start(owner, notice: notice);
      await hear(recorder, speech, const Duration(seconds: 6));
      audio.reset();
      final container = ProviderContainer(
        overrides: [
          meetingStoreProvider.overrideWithValue(store),
          meetingAudioEngineProvider.overrideWithValue(audio),
          meetingApiProvider.overrideWithValue(api),
          meetingSchedulerProvider.overrideWithValue(FakeMeetingScheduler()),
          meetingClockProvider.overrideWithValue(clock.call),
          captureOwnerProvider.overrideWithValue(owner),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(meetingRecordingProvider), isNull);
      await container.read(meetingControllerProvider.notifier).ready;
      expect(container.read(stoppedMeetingsProvider).single.id, meeting.id);
      expect(container.read(waitingMeetingsProvider), isEmpty);
      expect(container.read(meetingResultsProvider), isEmpty);
      for (var i = 0; i < 100 && api.calls.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(api.kinds(), ['piece']);
    });

    test('Pro bought: the controller sends the meetings held for Pro at once', () async {
      final meeting = await stoppedMeeting();
      api.onPiece = (_) async => throw ApiException(402, 'pro', {'code': 'pro_required'});
      await uploader().run();
      api.onPiece = null;
      final saved = <SavedMeetingNote>[];
      final controller = MeetingController(
        store: store,
        engine: audio,
        ownerKey: owner,
        api: api,
        scheduler: FakeMeetingScheduler(),
        clock: clock.call,
        onNotesSaved: saved.addAll,
      );
      addTearDown(controller.dispose);
      await controller.ready;
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(saved, isEmpty, reason: 'held for 6 hours');
      expect(controller.state.waiting.single.problem, MeetingProblem.proRequired);
      await controller.proGained();
      for (var i = 0; i < 100 && saved.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(saved.single.meetingId, meeting.id);
    });

    test('recording needs an account, the microphone and room', () async {
      final signedOut = MeetingController(
        store: store,
        engine: audio,
        ownerKey: 'local',
        scheduler: FakeMeetingScheduler(),
        clock: clock.call,
      );
      addTearDown(signedOut.dispose);
      await expectLater(
        signedOut.start(notice: notice),
        throwsA(isA<MeetingStartRefused>().having((e) => e.problem, 'problem', MeetingStartProblem.signedOut)),
      );
      audio.permitted = false;
      final controller = MeetingController(
        store: store,
        engine: audio,
        ownerKey: owner,
        api: api,
        scheduler: FakeMeetingScheduler(),
        clock: clock.call,
      );
      addTearDown(controller.dispose);
      await expectLater(
        controller.start(notice: notice),
        throwsA(isA<MeetingStartRefused>().having((e) => e.problem, 'problem', MeetingStartProblem.permission)),
      );
      final low = MeetingController(
        store: store,
        engine: audio,
        ownerKey: owner,
        api: api,
        scheduler: FakeMeetingScheduler(),
        clock: clock.call,
        freeBytes: () async => 10 * 1024 * 1024,
      );
      addTearDown(low.dispose);
      await expectLater(
        low.start(notice: notice),
        throwsA(isA<MeetingStartRefused>().having((e) => e.problem, 'problem', MeetingStartProblem.lowSpace)),
      );
    });

    test('sign-out: upload first sends everything waiting; offline it says what is left', () async {
      await stoppedMeeting(count: 2);
      final controller = MeetingController(
        store: store,
        engine: audio,
        ownerKey: owner,
        api: api,
        scheduler: FakeMeetingScheduler(),
        clock: clock.call,
      );
      addTearDown(controller.dispose);
      api.onPiece = (_) async => throw offline();
      await controller.ready;
      expect(await controller.uploadNow(), MeetingSendResult.offline);
      expect((await controller.backlog()).pieces, 2);
      api.onPiece = null;
      clock.advance(const Duration(hours: 1));
      expect(await controller.uploadNow(), MeetingSendResult.done);
      expect((await database.getTasks(ownerKey: owner)), hasLength(1));
    });
  });

  group('fix round 1', () {
    test('a pass that sends nothing is never due again at once: offline, a server error, or a backlog behind an unconfirmed start', () async {
      final meeting = await stoppedMeeting(count: 3);
      // Another meeting whose pieces the pass never reaches.
      await stoppedMeeting(count: 2);
      api.onPiece = (_) async => throw offline();
      var pass = await uploader().run();
      expect(pass.offline, isTrue);
      expect(pass.nextDue!.isAfter(clock.now), isTrue);
      // The two first pieces were in flight together.
      expect(api.calls.length, lessThanOrEqualTo(2));
      // Again when due: still nothing sent before then.
      for (var i = 0; i < 3; i++) {
        final calls = api.calls.length;
        expect((await uploader().run()).nextDue!.isAfter(clock.now), isTrue);
        expect(api.calls.length, calls);
        clock.now = pass.nextDue!;
        pass = await uploader().run();
        expect(pass.nextDue!.isAfter(clock.now), isTrue);
      }
      // A server error on the first piece: the others wait for its retry.
      api.onPiece = (_) async => throw ApiException(503, 'busy');
      clock.now = pass.nextDue!;
      pass = await uploader().run();
      expect(pass.offline, isFalse);
      expect(pass.nextDue!.isAfter(clock.now), isTrue);
      expect(await store.nextDue(owner), pass.nextDue);
      // Once it's confirmed, the rest go.
      api.onPiece = null;
      clock.now = pass.nextDue!;
      await uploader().run();
      expect((await store.meeting(meeting.id, owner)), isNotNull);
      expect(api.received[meeting.id], {0, 1, 2});
    });

    test('a controller that finds no signal waits for the retry, not the 2-second floor', () async {
      await stoppedMeeting(count: 3);
      api.onPiece = (_) async => throw offline();
      final scheduler = FakeMeetingScheduler();
      final controller = MeetingController(
        store: store,
        engine: audio,
        ownerKey: owner,
        api: api,
        scheduler: scheduler,
        clock: clock.call,
        retryFloor: const Duration(milliseconds: 1),
      );
      addTearDown(controller.dispose);
      await controller.ready;
      for (var i = 0; i < 50 && api.calls.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // The clock stands still: the first retry isn't due, so no further
      // pass runs (each would schedule the background task again).
      expect(api.calls, hasLength(1));
      expect(scheduler.scheduled, 1);
    });

    test('a piece whose file is gone, or which the server refuses for good, is no longer sent; the meeting says so', () async {
      final gone = await stoppedMeeting(count: 2);
      final first = (await piecesOf(gone.id)).first;
      File(first.path).deleteSync();
      var pass = await uploader().run();
      expect(api.calls.where((call) => call.meetingId == gone.id), isEmpty);
      final stored = (await store.meeting(gone.id, owner))!;
      expect(stored.problem, MeetingProblem.pieceFailed);
      expect((await piecesOf(gone.id)).first.state, MeetingPiece.failed);
      expect(pass.nextDue, isNull);
      expect((await store.backlog(owner)).pieces, 2, reason: 'still on the phone until discarded');
      await store.discard(gone.id, owner);
      await uploader().run();
      expect(await store.meeting(gone.id, owner), isNull);

      final refused = await stoppedMeeting();
      api.calls.clear();
      api.onPiece = (_) async => throw ApiException(400, 'audio: corrupt');
      for (var i = 0; i < MeetingUploader.refusedAfter; i++) {
        pass = await uploader().run();
        clock.now = pass.nextDue ?? clock.now;
      }
      expect((await store.meeting(refused.id, owner))!.problem, MeetingProblem.pieceFailed);
      expect(pass.nextDue, isNull);
      clock.advance(const Duration(days: 1));
      await store.retryNow(owner);
      await uploader().run();
      expect(api.kinds(), List.filled(MeetingUploader.refusedAfter, 'piece'));
      // A server error is never taken as final.
      api.onPiece = (_) async => throw ApiException(500, 'oops');
      final busy = await stoppedMeeting();
      for (var i = 0; i < 6; i++) {
        pass = await uploader().run();
        clock.now = pass.nextDue!;
      }
      expect((await piecesOf(busy.id)).single.state, MeetingPiece.pending);
    });

    test('failed finish calls don’t count toward the pieces the server lost', () async {
      final meeting = await stoppedMeeting();
      var fail = true;
      api.onFinish = (id, last) async {
        if (fail) throw ApiException(503, 'busy');
        return const MeetingAnswer(status: 'waiting', missing: [0]);
      };
      MeetingPass pass;
      for (var i = 0; i < MeetingUploader.lostAfter; i++) {
        pass = await uploader().run();
        clock.now = pass.nextDue!;
      }
      fail = false;
      pass = await uploader().run();
      final stored = (await store.meeting(meeting.id, owner))!;
      expect(stored.problem, isNot(MeetingProblem.expired));
      expect(stored.waits, 1);
      expect(stored.attempts, 0);
      expect(pass.nextDue, isNotNull);
    });

    test('a recording found stopped after a week with the phone off still asks first', () async {
      final meeting = await recorder.start(owner, notice: notice);
      await hear(recorder, speech, const Duration(seconds: 12));
      audio.reset();
      clock.advance(const Duration(days: 10));
      final controller = MeetingController(
        store: store,
        engine: audio,
        ownerKey: owner,
        scheduler: FakeMeetingScheduler(),
        clock: clock.call,
      );
      addTearDown(controller.dispose);
      await controller.ready;
      expect(controller.state.stopped.single.id, meeting.id);
      final asked = (await store.meeting(meeting.id, owner))!;
      expect(asked.askedAt, clock.now);
      clock.advance(const Duration(days: 6));
      expect(await store.autoFinishStale(owner, clock.now), isEmpty);
      clock.advance(const Duration(days: 1, minutes: 1));
      expect((await store.autoFinishStale(owner, clock.now)).single.id, meeting.id);
    });

    test('Stop pressed while the microphone failure is ending the recording finishes it, once', () async {
      final meeting = await recorder.start(owner, notice: notice);
      await hear(recorder, speech, const Duration(seconds: 8));
      audio.fail();
      await Future<void>.delayed(Duration.zero);
      await recorder.settle();
      final stopped = await recorder.stop();
      expect(stopped!.id, meeting.id);
      expect(stopped.phase, MeetingPhase.finishing);
      expect(audio.stops, 1);
      expect((await piecesOf(meeting.id)).single.state, MeetingPiece.pending);
      expect(recorder.recording, isFalse);
    });

    test('start cleans audio no piece uses, but never a meeting still recording', () async {
      final meeting = await recorder.start(owner, notice: notice);
      await hear(recorder, speech, const Duration(seconds: 8));
      audio.reset();
      final kept = (await piecesOf(meeting.id)).single.path;
      // A file the recorder began just before the app was killed.
      final orphan = File(p.join(File(kept).parent.path, '999999.ogg'))..writeAsBytesSync([1, 2, 3]);
      final strayFolder = Directory(p.join(directory.path, 'audio', '11111111-2222-4333-8444-555555555555'))
        ..createSync(recursive: true);
      File(p.join(strayFolder.path, '0.ogg')).writeAsBytesSync([1]);
      final notOurs = Directory(p.join(directory.path, 'audio', 'keep-me'))..createSync();

      // Still recording (as the store sees it): nothing of it goes.
      await store.clean(owner, clock.now);
      expect(orphan.existsSync(), isTrue);
      expect(strayFolder.existsSync(), isFalse);
      expect(notOurs.existsSync(), isTrue);

      await store.recoverInterrupted(owner);
      await store.clean(owner, clock.now);
      expect(orphan.existsSync(), isFalse);
      expect(File(kept).existsSync(), isTrue);
    });

    test('free space is read from the disk that holds the audio', () async {
      final free = await store.freeBytes();
      if (Platform.isLinux || Platform.isAndroid) {
        expect(free, greaterThan(0));
      } else {
        expect(free, isNull);
      }
    });
  });

  test('schema 21 upgrades to 22 with the meeting tables and every task kept', () async {
    final old = await databaseFactoryFfi.openDatabase(p.join(directory.path, 'old.db'));
    addTearDown(old.close);
    await old.execute(
      'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
    );
    await TaskDatabase.upgrade(old, 3, 21);
    await old.insert('tasks', {
      ...(Task(title: 'Kept', priority: 1).toMap()..remove('id')),
      'owner_key': owner,
      'sync_id': 'kept',
    });
    final tables = await old.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
    expect(tables.map((row) => row['name']), isNot(contains('meetings')));
    await TaskDatabase.upgrade(old, 21, 22);
    final after = await old.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
    expect(after.map((row) => row['name']), containsAll(['meetings', 'meeting_pieces', 'meeting_leases']));
    expect((await old.query('tasks')).single['title'], 'Kept');
    expect(TaskDatabase.schemaVersion, greaterThanOrEqualTo(22));
  });

  group('P329 · meeting notes saved before the marks (UX-2905)', () {
    /// A database as the released build (schema 22) left it, at [path].
    Future<Database> version22(String path) async {
      final db = await databaseFactoryFfi.openDatabase(path);
      await db.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
      );
      await TaskDatabase.upgrade(db, 3, 22);
      await db.execute('PRAGMA user_version = 22');
      return db;
    }

    Task meetingNoteWithSteps(String title) => Task(
      title: title,
      kind: 'note',
      priority: 1,
      checklist: [ChecklistItem(title: 'Send the budget'), ChecklistItem(title: 'Book the room')],
    );

    Future<void> meetingRow(Database db, String id, String key, int? noteId) => db.insert('meetings', {
      'id': id,
      'owner_key': key,
      'phase': 'done',
      'started_at': clock.now.toIso8601String(),
      'format': 'opus',
      'note_id': noteId,
    });

    Future<void> openRealDatabase(String folder) async {
      databaseFactory = databaseFactoryFfi;
      await databaseFactory.setDatabasesPath(folder);
      addTearDown(() => TaskDatabase().close());
    }

    test('UX-2905: upgrading a version-22 database marks the note a meeting row still links, '
        'and that note offers «Crear tarea»', () async {
      final folder = p.join(directory.path, 'real');
      await Directory(folder).create();
      final old = await version22(p.join(folder, 'task_database.db'));
      final released = TaskDatabase.forTesting(old);
      final linked = await released.insertTask(meetingNoteWithSteps('Weekly meeting'), ownerKey: owner);
      final unlinked = await released.insertTask(meetingNoteWithSteps('Croquetas'), ownerKey: owner);
      await meetingRow(old, 'm-linked', owner, linked);
      await meetingRow(old, 'm-gone', owner, 9999);
      await meetingRow(old, 'm-no-note', owner, null);
      // Another account's meeting row never marks this account's note.
      await meetingRow(old, 'm-other', other, unlinked);
      expect(await MeetingNoteMarks.read(released, owner), isEmpty);
      await old.close();

      // The app opens it as this build does: schema 22 to the current one.
      await openRealDatabase(folder);
      final upgraded = TaskDatabase();
      final version = await (await upgraded.database).rawQuery('PRAGMA user_version');
      expect(version.single.values.single, TaskDatabase.schemaVersion);

      final marks = await MeetingNoteMarks.read(upgraded, owner);
      expect(marks, {linked});
      expect(await MeetingNoteMarks.read(upgraded, other), isEmpty);

      final notes = {for (final note in await upgraded.getTasks(ownerKey: owner)) note.id: note};
      expect(noteMakesTask(notes[linked]!, marks), isTrue);
      // Not linked from a meeting row: never guessed from its text or steps.
      expect(noteMakesTask(notes[unlinked]!, marks), isFalse);
    });

    test('UX-2905: a meeting row whose note no longer exists adds no mark, and marks already there are kept', () async {
      final old = await version22(p.join(directory.path, 'marked.db'));
      addTearDown(old.close);
      final released = TaskDatabase.forTesting(old);
      final kept = await released.insertTask(meetingNoteWithSteps('Saved after D1'), ownerKey: owner);
      final linked = await released.insertTask(meetingNoteWithSteps('Saved before D1'), ownerKey: owner);
      await MeetingNoteMarks.add(old, owner, kept);
      await meetingRow(old, 'm-linked', owner, linked);
      await meetingRow(old, 'm-linked-again', owner, linked);
      await meetingRow(old, 'm-gone', owner, 4242);

      await TaskDatabase.upgrade(old, 22, 23);
      expect(await MeetingNoteMarks.read(released, owner), {kept, linked});
      expect(await MeetingNoteMarks.read(released, owner), isNot(contains(4242)));
    });

    test('UX-2905: a fresh database at the current version has no marks', () async {
      // The suite's own database, built from scratch.
      expect(await MeetingNoteMarks.read(database, owner), isEmpty);

      // And a fresh install, as the app creates it.
      final folder = p.join(directory.path, 'fresh');
      await Directory(folder).create();
      await openRealDatabase(folder);
      final fresh = TaskDatabase();
      final version = await (await fresh.database).rawQuery('PRAGMA user_version');
      expect(TaskDatabase.schemaVersion, 23);
      expect(version.single.values.single, 23);
      expect(await MeetingNoteMarks.read(fresh, owner), isEmpty);
      expect(await MeetingNoteMarks.read(fresh, other), isEmpty);
    });
  });

  group('P325 · meeting notifications', () {
    test('UX-2810: the recording’s clock starts as it starts, and keeps time through a cut', () async {
      final started = clock.now;
      await recorder.start(owner, notice: notice);
      expect(audio.notices.single.since, started);
      expect(audio.notices.single.title, notice.title);
      // 5 minutes and more, then a pause: the piece is cut.
      await hear(recorder, speech, const Duration(minutes: 5, seconds: 10));
      await hear(recorder, silence, const Duration(seconds: 2));
      final cut = audio.nextNotices.single;
      expect(cut.since, started);
      expect(cut.title, notice.title);
      final android = meetingRecordingNotificationDetails(cut).android!;
      expect(android.usesChronometer, isTrue);
      expect(android.showWhen, isTrue);
      expect(android.when, started.millisecondsSinceEpoch);
      await recorder.stop();
    });

    test('UX-2810: «Seguir grabando» counts on from the 42 minutes already recorded', () async {
      final meeting = await recorder.start(owner, notice: notice);
      await hear(recorder, speech, const Duration(minutes: 42), step: const Duration(seconds: 10));
      // The process dies; the meeting is found stopped later.
      audio.reset();
      clock.advance(const Duration(hours: 1));
      final restarted = newRecorder();
      final stopped = (await store.recoverInterrupted(owner, active: restarted.meetingId)).single;
      expect(stopped.recorded, const Duration(minutes: 42));

      await restarted.resume(meeting.id, owner, notice: notice);
      final resumedAt = clock.now;
      final continued = audio.notices.last;
      expect(continued.since, resumedAt.subtract(const Duration(minutes: 42)));
      final android = meetingRecordingNotificationDetails(continued).android!;
      expect(android.usesChronometer, isTrue);
      expect(android.showWhen, isTrue);
      expect(
        android.when,
        resumedAt.millisecondsSinceEpoch - const Duration(minutes: 42).inMilliseconds,
      );
      // And through the next cut, at 6 minutes, the same start.
      await hear(restarted, speech, const Duration(minutes: 6, seconds: 1));
      expect(audio.nextNotices.last.since, continued.since);
      await restarted.stop();
    });

    test('UX-2811: markSeen removes that meeting’s "notes ready"', () async {
      final seen = <String>[];
      final hook = MeetingHooks.notesSeen;
      MeetingHooks.notesSeen = (id) async => seen.add(id);
      addTearDown(() => MeetingHooks.notesSeen = hook);
      final meeting = await stoppedMeeting();
      final controller = MeetingController(
        store: store,
        engine: audio,
        ownerKey: owner,
        api: api,
        scheduler: FakeMeetingScheduler(),
        clock: clock.call,
      );
      addTearDown(controller.dispose);
      await controller.ready;
      await controller.markSeen(meeting.id);
      expect(seen, [meeting.id]);
    });
  });

  group('P320 · Save notes and sign out says how it ended', () {
    MeetingController controller() {
      final controller = MeetingController(
        store: store,
        engine: audio,
        ownerKey: owner,
        api: api,
        scheduler: FakeMeetingScheduler(),
        clock: clock.call,
        retryFloor: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);
      return controller;
    }

    test('UX-2806, MN-13: no connection: offline, and the recording stays', () async {
      final meeting = await stoppedMeeting();
      api.onPiece = (_) async => throw offline();
      final meetings = controller();
      await meetings.ready;
      expect(await meetings.uploadNow(), MeetingSendResult.offline);
      expect(await store.meeting(meeting.id, owner), isNotNull);
      expect((await meetings.backlog()).meetings, 1);
    });

    test('UX-2806, MN-13: online but not done within the 2-minute cap: slow, and the recording stays', () async {
      final meeting = await stoppedMeeting();
      // The server is busy and asks for 3 minutes: past the cap.
      api.onPiece = (_) async =>
          throw ApiException(503, 'busy', null, const Duration(minutes: 3));
      final meetings = controller();
      await meetings.ready;
      final waited = Stopwatch()..start();
      expect(await meetings.uploadNow(), MeetingSendResult.slow);
      expect(waited.elapsed, lessThan(const Duration(seconds: 30)));
      expect(await store.meeting(meeting.id, owner), isNotNull);
      expect((await meetings.backlog()).meetings, 1);
    });

    test('UX-2806, MN-13: held back for Pro: blocked, and the recording stays', () async {
      final meeting = await stoppedMeeting();
      api.onPiece = (_) async =>
          throw ApiException(402, 'pro', {'code': MeetingProblem.proRequired});
      final meetings = controller();
      await meetings.ready;
      expect(await meetings.uploadNow(), MeetingSendResult.blocked);
      expect(await store.meeting(meeting.id, owner), isNotNull);
    });

    test('UX-2806: everything sent: done', () async {
      await stoppedMeeting();
      final meetings = controller();
      await meetings.ready;
      expect(await meetings.uploadNow(), MeetingSendResult.done);
      expect((await meetings.backlog()).isEmpty, isTrue);
    });
  });

  group('P323 · starting a recording: the microphone, and what keeps the notes waiting', () {
    MeetingController controllerFor({MeetingApi? withApi, FakeClock? at}) {
      final controller = MeetingController(
        store: store,
        engine: audio,
        ownerKey: owner,
        api: withApi,
        scheduler: FakeMeetingScheduler(),
        clock: (at ?? clock).call,
        rules: const MeetingPieceRules(target: Duration(seconds: 10), cap: Duration(seconds: 12)),
      );
      addTearDown(controller.dispose);
      return controller;
    }

    Matcher refused(MeetingStartProblem problem) =>
        throwsA(isA<MeetingStartRefused>().having((e) => e.problem, 'problem', problem));

    test('UX-2712: refused but Android still asks, refused for good, and allowed: each says which', () async {
      final controller = controllerFor(withApi: api);
      await controller.ready;
      audio.permitted = false;
      await expectLater(controller.start(notice: notice), refused(MeetingStartProblem.permission));
      expect(audio.asks, 1, reason: 'starting asks Android');
      await expectLater(controller.start(notice: notice), refused(MeetingStartProblem.permission));
      expect(audio.asks, 2, reason: '«Permitir el micrófono» asks again');
      // Back from Settings: only read, never asked.
      expect(await controller.microphoneAllowed(), isFalse);
      expect(audio.asks, 2);
      audio.blocked = true;
      await expectLater(controller.start(notice: notice), refused(MeetingStartProblem.microphoneBlocked));
      expect(controller.state.recording, isNull);
      audio.permitted = true;
      expect(await controller.microphoneAllowed(), isTrue);
      final meeting = await controller.start(notice: notice);
      expect(controller.state.recording?.meetingId, meeting.id);
      await controller.discardRecording();
    });

    test('UX-2711: a piece refused for the month’s time while recording: the state says so, and recording goes on', () async {
      api.onPiece = (_) async => throw ApiException(402, 'allowance', {'code': 'meeting_allowance_used'});
      final controller = controllerFor(withApi: api);
      await controller.ready;
      expect(controller.state.recordingProblem, isNull);
      expect(controller.state.allowanceUsed, isFalse);
      final meeting = await controller.start(notice: notice);
      await hear(controller.recorder, speech, const Duration(seconds: 12));
      for (var i = 0; i < 100 && controller.state.recordingProblem == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(api.kinds(), contains('piece'));
      expect(controller.state.recordingProblem, MeetingProblem.allowanceUsed);
      expect(controller.state.recording?.meetingId, meeting.id);
      await hear(controller.recorder, speech, const Duration(seconds: 3));
      expect(controller.state.recording?.meetingId, meeting.id);
      expect(controller.state.recording!.elapsed, greaterThanOrEqualTo(const Duration(seconds: 15)));
      await controller.stop();
    });

    test('UX-2711: a piece refused for Pro while recording: the state says so', () async {
      api.onPiece = (_) async => throw ApiException(402, 'pro', {'code': 'pro_required'});
      final controller = controllerFor(withApi: api);
      await controller.ready;
      final meeting = await controller.start(notice: notice);
      await hear(controller.recorder, speech, const Duration(seconds: 12));
      for (var i = 0; i < 100 && controller.state.recordingProblem == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(controller.state.recordingProblem, MeetingProblem.proRequired);
      expect(controller.state.recording?.meetingId, meeting.id);
      await controller.stop();
    });

    test('UX-2711: a meeting refused for the month’s time this month says so before the next starts; next month it doesn’t', () async {
      final earlier = await stoppedMeeting();
      api.onPiece = (_) async => throw ApiException(402, 'allowance', {'code': 'meeting_allowance_used'});
      await uploader().run();
      expect((await store.meeting(earlier.id, owner))!.problem, MeetingProblem.allowanceUsed);
      api.onPiece = null;

      // No uploader: the refusal stays as the server left it.
      final now = controllerFor();
      await now.ready;
      expect(now.state.allowanceUsed, isTrue);
      expect(now.state.recordingProblem, isNull, reason: 'nothing records yet');

      final nextMonth = controllerFor(at: FakeClock(DateTime.utc(2026, 12, 2, 10)));
      await nextMonth.ready;
      expect(nextMonth.state.allowanceUsed, isFalse);
    });
  });

  group('P324 · Stop: a quiet recording, and a Stop that fails', () {
    // Under −42 dBFS all along: never a loud sample.
    const quiet = -60.0;

    MeetingController controllerFor() {
      final controller = MeetingController(
        store: store,
        engine: audio,
        ownerKey: owner,
        api: api,
        scheduler: FakeMeetingScheduler(),
        clock: clock.call,
      );
      addTearDown(controller.dispose);
      return controller;
    }

    /// Lets the controller's uploads run on real time for a moment.
    Future<void> letUploadsRun([bool Function()? until]) async {
      for (var i = 0; i < 100 && !(until?.call() ?? false); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    Iterable<MeetingCall> piecesSent(String id) =>
        api.calls.where((call) => call.kind == 'piece' && call.meetingId == id);

    group('a quiet recording (UX-2717)', () {
      test('UX-2717: ten minutes that never pass −42 dBFS are kept at Stop, '
          'stopped, with their pieces on the phone: nothing is deleted or sent '
          'before the answer', () async {
        final controller = controllerFor();
        await controller.ready;
        final started = await controller.start(notice: notice);
        await hear(controller.recorder, quiet, const Duration(minutes: 10));
        final stopped = await controller.stop();
        await letUploadsRun();

        expect(stopped, isNotNull, reason: 'not dropped as silence');
        expect(stopped!.id, started.id);
        expect(stopped.phase, MeetingPhase.interrupted);
        expect(stopped.recorded, const Duration(minutes: 10));
        // The screen's choices: it's a stopped meeting, as in Notes.
        expect(controller.state.recording, isNull);
        expect(controller.state.stopped.single.id, started.id);
        final pieces = await piecesOf(started.id);
        expect(pieces, isNotEmpty);
        expect(pieces.every((piece) => piece.state == MeetingPiece.held), isTrue);
        expect(audio.files, isNotEmpty);
        expect(
          audio.files.every((path) => File(path).existsSync()),
          isTrue,
          reason: 'every recorded file is still on the phone',
        );
        expect(piecesSent(started.id), isEmpty, reason: 'held, never sent');
        expect(api.kinds(), isNot(contains('finish')));
        expect(api.kinds(), isNot(contains('delete')));
      });

      test('UX-2717: «Hacer las notas» sends the held pieces like any '
          'recording and asks for the notes', () async {
        final controller = controllerFor();
        await controller.ready;
        final meeting = await controller.start(notice: notice);
        await hear(controller.recorder, quiet, const Duration(minutes: 10));
        await controller.stop();
        final held = (await piecesOf(meeting.id)).length;

        await controller.finishMeeting(meeting.id);
        await letUploadsRun(() => api.kinds().contains('finish'));
        expect(
          [for (final call in piecesSent(meeting.id)) call.index],
          unorderedEquals([for (var i = 0; i < held; i++) i]),
          reason: 'every held piece reaches the server, numbered from 0',
        );
        final finish = api.calls.firstWhere((call) => call.kind == 'finish');
        expect(finish.meetingId, meeting.id);
        expect(finish.lastIndex, held - 1);
        expect(controller.state.stopped, isEmpty);
      });

      test('UX-2717: «Descartar» deletes the held pieces and their files '
          '(MN-25), and sends none', () async {
        final controller = controllerFor();
        await controller.ready;
        final meeting = await controller.start(notice: notice);
        await hear(controller.recorder, quiet, const Duration(minutes: 10));
        await controller.stop();
        expect(await piecesOf(meeting.id), isNotEmpty);

        await controller.discardMeeting(meeting.id);
        await letUploadsRun();
        expect(await piecesOf(meeting.id), isEmpty);
        expect(audio.files.every((path) => !File(path).existsSync()), isTrue);
        expect(piecesSent(meeting.id), isEmpty);
        expect(controller.state.stopped, isEmpty);
        expect(controller.state.waiting, isEmpty);
      });

      test('UX-2717: thirty silent seconds are still dropped at Stop, as '
          'before', () async {
        final recorder = newRecorder();
        final meeting = await recorder.start(owner, notice: notice);
        await hear(recorder, quiet, const Duration(seconds: 30));
        expect(await recorder.stop(), isNull);
        expect(await piecesOf(meeting.id), isEmpty);
        expect(audio.files.every((path) => !File(path).existsSync()), isTrue);
        expect(
          (await store.meeting(meeting.id, owner))?.phase,
          anyOf(isNull, MeetingPhase.discarding),
        );
      });

      test('UX-2717: sound in the third piece keeps that piece and the later '
          'ones, and leaves out the silent pieces before it (MN-4)', () async {
        final recorder = newRecorder(
          rules: const MeetingPieceRules(
            target: Duration(seconds: 10),
            cap: Duration(seconds: 12),
          ),
        );
        final meeting = await recorder.start(owner, notice: notice);
        // Two silent pieces, held while nothing with sound is kept.
        await hear(recorder, quiet, const Duration(seconds: 12));
        await hear(recorder, quiet, const Duration(seconds: 12));
        var pieces = await piecesOf(meeting.id);
        expect(pieces, hasLength(3));
        expect(pieces[0].state, MeetingPiece.held);
        expect(pieces[1].state, MeetingPiece.held);
        expect(pieces[2].state, MeetingPiece.recording);
        final silentFiles = [pieces[0].path, pieces[1].path];
        final third = pieces[2];

        // The third piece has sound, and so does the fourth.
        await hear(recorder, speech, const Duration(seconds: 12));
        await hear(recorder, speech, const Duration(seconds: 5));
        final stopped = await recorder.stop();
        expect(stopped!.phase, MeetingPhase.finishing);
        pieces = await piecesOf(meeting.id);
        expect(pieces, hasLength(2));
        expect([for (final piece in pieces) piece.index], [0, 1]);
        expect(
          pieces.every((piece) => piece.state == MeetingPiece.pending),
          isTrue,
        );
        expect(pieces.first.path, third.path);
        expect(pieces.first.offset, third.offset);
        expect(stopped.lastIndex, 1);
        expect(File(pieces.first.path).existsSync(), isTrue);
        expect(File(pieces.last.path).existsSync(), isTrue);
        for (final path in silentFiles) {
          expect(File(path).existsSync(), isFalse, reason: 'left out');
        }
      });
    });

    group('a Stop that fails in the store (UX-2713)', () {
      test('UX-2713: the microphone has stopped and what was recorded is '
          'kept; its time stays where it stopped; the next Stop finishes it '
          'and nothing is on show as recording', () async {
        store = _P324FailingLastPiece(
          database,
          directory: Directory(p.join(directory.path, 'audio')),
        )..failures = 2;
        final controller = controllerFor();
        await controller.ready;
        final meeting = await controller.start(notice: notice);
        await hear(controller.recorder, speech, const Duration(seconds: 30));

        await expectLater(controller.stop(), throwsA(isA<StateError>()));
        await Future<void>.delayed(Duration.zero);
        // Stop had stopped the microphone before the store failed: nothing
        // is being recorded, and nothing recorded was lost.
        expect(audio.running, isFalse);
        expect(audio.stops, 1);
        expect(audio.files.every((path) => File(path).existsSync()), isTrue);
        final status = controller.state.recording;
        expect(status?.meetingId, meeting.id, reason: 'Stop again, on screen');
        expect(status?.elapsed, const Duration(seconds: 30));
        expect(status?.level, 0);

        // A minute on, a Stop that fails again doesn't move the time on.
        clock.advance(const Duration(minutes: 1));
        await expectLater(controller.stop(), throwsA(isA<StateError>()));
        await Future<void>.delayed(Duration.zero);
        expect(controller.state.recording?.elapsed, const Duration(seconds: 30));

        final stopped = await controller.stop();
        await Future<void>.delayed(Duration.zero);
        expect(stopped?.id, meeting.id);
        expect(stopped?.phase, MeetingPhase.finishing);
        expect(stopped?.lastIndex, 0);
        expect(controller.recorder.recording, isFalse);
        expect(controller.recorder.current, isNull);
        expect(controller.state.recording, isNull);
        expect(audio.stops, 1, reason: 'the microphone was stopped once');
        final pieces = await piecesOf(meeting.id);
        expect(pieces.single.state, MeetingPiece.pending);
        // It ends where the microphone stopped, not at the Stop that worked.
        expect(pieces.single.duration, const Duration(seconds: 30));
        expect(stopped?.recorded, const Duration(seconds: 30));
      });
    });
  });
}

/// A store whose closing of the last piece (at Stop) fails [failures]
/// times, as a full disk or a busy database might.
class _P324FailingLastPiece extends MeetingStore {
  _P324FailingLastPiece(super.database, {super.directory});
  int failures = 0;

  @override
  Future<bool> closePiece(
    Meeting meeting, {
    required int index,
    required Duration duration,
    required bool hasSound,
    required DateTime now,
    String? nextPath,
    bool hold = false,
  }) async {
    if (nextPath == null && failures > 0) {
      failures--;
      throw StateError('The database is busy.');
    }
    return super.closePiece(
      meeting,
      index: index,
      duration: duration,
      hasSound: hasSound,
      now: now,
      nextPath: nextPath,
      hold: hold,
    );
  }
}
