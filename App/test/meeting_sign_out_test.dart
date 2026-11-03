// Signing out with meetings (MN-13, MN-24, MN-25), with the real meeting
// core: a discarded or saved meeting's DELETE reaches the server before the
// account's token goes. The server is FakeMeetingApi; no microphone or
// WorkManager.
import 'dart:io';

import 'package:agenda/models/meeting.dart';
import 'package:agenda/services/meeting_controller.dart';
import 'package:agenda/services/meeting_note.dart';
import 'package:agenda/services/meeting_recorder.dart';
import 'package:agenda/services/meeting_store.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/meeting_banners.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/meeting_fakes.dart';

const owner = 'https://api.example.invalid/users/7';
const notice = MeetingNotice(title: 'Recording');

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late Database sql;
  late MeetingStore store;
  late FakeClock clock;
  late FakeMeetingAudio audio;
  late FakeMeetingApi api;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('taskflow-sign-out-');
    sql = await databaseFactoryFfi.openDatabase(p.join(directory.path, 'm.db'));
    await sql.execute(
      'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
    );
    await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
    store = MeetingStore(
      TaskDatabase.forTesting(sql),
      directory: Directory(p.join(directory.path, 'audio')),
    );
    clock = FakeClock();
    audio = FakeMeetingAudio();
    api = FakeMeetingApi();
    MeetingHooks.labels = (_) => MeetingNoteLabels.none;
    MeetingHooks.notesReady = (_) async {};
  });

  tearDown(() async {
    await sql.close();
    await directory.delete(recursive: true);
  });

  /// A meeting stopped with one piece, which the server hasn't received.
  Future<Meeting> stopped() async {
    final recorder = MeetingRecorder(
      store: store,
      engine: audio,
      clock: clock.call,
      rules: const MeetingPieceRules(
        target: Duration(seconds: 10),
        cap: Duration(seconds: 12),
      ),
    );
    final meeting = await recorder.start(owner, notice: notice);
    for (var i = 0; i < 12; i++) {
      clock.advance(const Duration(seconds: 1));
      audio.hear(-20);
      await Future<void>.delayed(Duration.zero);
      await recorder.settle();
    }
    await recorder.stop();
    return (await store.meeting(meeting.id, owner))!;
  }

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

  test(
    'discard and sign out: the DELETE is answered before signing out',
    () async {
      // No signal at first: the piece waits, so the meeting is still here.
      api.onPiece = (_) async => throw offline();
      final meeting = await stopped();
      final meetings = controller();
      await meetings.ready;
      expect((await meetings.backlog()).meetings, 1);

      final order = <String>[];
      api.onPiece = null;
      // The server takes a moment to answer, as a real one does.
      api.onDelete = (id) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        order.add('deleted $id');
      };
      await meetings.discardAll();
      await tellServerBeforeSignOut(meetings);
      order.add('signOut');

      expect(order, ['deleted ${meeting.id}', 'signOut']);
      expect(await store.meeting(meeting.id, owner), isNull);
    },
  );

  test(
    'a server out of reach doesn’t keep the account from signing out',
    () async {
      api.onPiece = (_) async => throw offline();
      final meeting = await stopped();
      final meetings = controller();
      await meetings.ready;
      api.onDelete = (_) async => throw offline();
      await meetings.discardAll();
      final waited = Stopwatch()..start();
      await tellServerBeforeSignOut(
        meetings,
        limit: const Duration(seconds: 2),
      );
      expect(waited.elapsed, lessThan(const Duration(seconds: 3)));
      // Kept to tell the server on this account's next sign-in here.
      expect(
        (await store.meeting(meeting.id, owner))!.phase,
        MeetingPhase.discarding,
      );
    },
  );
}
