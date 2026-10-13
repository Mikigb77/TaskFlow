import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/capture_clarification.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_diagnostics.dart';
import 'package:agenda/services/capture_processor.dart';
import 'package:agenda/services/capture_problem.dart';
import 'package:agenda/l10n/capture_messages.dart';
import 'package:agenda/l10n/generated/app_localizations_en.dart';
import 'package:agenda/l10n/generated/app_localizations_es.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late TaskDatabase database;
  late CaptureStore store;
  late String databasePath;

  Future<void> reopen() async {
    database = TaskDatabase.forTesting(
      await databaseFactoryFfi.openDatabase(databasePath),
    );
    store = CaptureStore(database, directory: directory);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('taskflow-capture-test-');
    databasePath = p.join(directory.path, 'test.db');
    final sql = await databaseFactoryFfi.openDatabase(databasePath);
    await sql.execute(
      'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
    );
    await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
    database = TaskDatabase.forTesting(sql);
    store = CaptureStore(database, directory: directory);
  });

  tearDown(() async {
    await database.close();
    expect(
      p.isWithin(Directory.systemTemp.absolute.path, directory.absolute.path),
      isTrue,
    );
    await directory.delete(recursive: true);
  });

  test(
    'restart retains interrupted audio, original timezone/time and typed input',
    () async {
      final time = DateTime.utc(2026, 9, 22, 22, 59);
      var session = await store.create(
        'local',
        'Europe/Madrid',
        now: time,
        audio: true,
        text: 'Tomorrow doctor',
      );
      final bytes = _wav();
      await File(session.audioPath!).writeAsBytes(bytes);
      session = session.copyWith(status: 'recording');
      await store.update(session);
      await database.close();
      await reopen();
      final restored = (await store.pending('local')).single;
      expect(restored.capturedAt, time);
      expect(restored.timezone, 'Europe/Madrid');
      expect(restored.text, 'Tomorrow doctor');
      expect(await File(restored.audioPath!).readAsBytes(), bytes);
      expect(restored.status, 'recording');
    },
  );

  for (final owner in ['local', 'https://test.invalid/api/users/3']) {
    test('save Undo is durable, scoped and idempotent for $owner', () async {
      final before =
          (await store.create(
            owner,
            'Europe/Madrid',
            text: 'Mañana revisar la aplicación',
          )).copyWith(
            status: 'ready',
            transcript: 'Mañana revisar la aplicación',
            drafts: [
              CaptureDraft(
                id: 'a',
                task: Task(
                  title: 'Revisar la aplicación',
                  priority: 1,
                  dueDate: DateTime(2026, 10, 13),
                  hasTime: false,
                  notes: 'Con José · demà 🗓️',
                ),
              ),
            ],
          );
      await store.update(before);
      final saved = await store.saveReady(before.id, owner, {'a'});
      final ids = {'a': saved.drafts.single.savedTaskId!};
      final restored = await store.undoSave(before, ids);
      expect(restored!.transcript, before.transcript);
      expect(restored.drafts.single.ready, true);
      expect((await database.getTasks(ownerKey: owner)), isEmpty);
      if (owner != 'local') {
        final pending = await database.pending(owner);
        expect(pending.single['is_deleted'], 1);
      }
      expect(await store.undoSave(before, ids), isNull);
      await database.close();
      await reopen();
      final reopened = await store.read(before.id, owner);
      expect(reopened!.drafts.single.task.notes, 'Con José · demà 🗓️');
      await store.saveReady(before.id, owner, {'a'});
      expect(await database.getTasks(ownerKey: owner), hasLength(1));
    });
  }

  test('restart retains separately resolved clarification fields', () async {
    const schedule = CaptureClarification(
      field: 'schedule',
      question: 'Please check this detail',
      times: ['05:00', '17:00'],
    );
    const duration = CaptureClarification(
      field: 'duration',
      question: 'Please check this detail',
    );
    final session = (await store.create('local', 'Europe/Madrid')).copyWith(
      status: 'ready',
      drafts: [
        CaptureDraft(
          id: 'clarified',
          task: Task(
            title: 'Cita médica',
            priority: 3,
            dueDate: DateTime(2026, 10, 13, 17),
          ),
          clarifications: const [schedule, duration],
          resolvedQuestions: [schedule.id],
          confirmed: false,
        ),
      ],
    );
    await store.update(session);
    await database.close();
    await reopen();
    final restored = (await store.pending('local')).single.drafts.single;
    expect(restored.ready, isFalse);
    expect(restored.task.dueDate, DateTime(2026, 10, 13, 17));
    expect(restored.clarifications.first.times, ['05:00', '17:00']);
    expect(restored.resolvedQuestions, [schedule.id]);
    expect(restored.resolvedQuestions.contains(duration.id), isFalse);
  });

  test(
    'Undo never deletes newer edits and rejects a whole batch atomically',
    () async {
      final before = (await store.create('local', 'UTC')).copyWith(
        status: 'ready',
        drafts: [
          CaptureDraft(
            id: 'a',
            task: Task(title: 'First', priority: 1),
          ),
          CaptureDraft(
            id: 'b',
            task: Task(title: 'Second', priority: 1),
          ),
        ],
      );
      await store.update(before);
      final saved = await store.saveReady(before.id, 'local', {'a', 'b'});
      final ids = {for (final d in saved.drafts) d.id: d.savedTaskId!};
      final tasks = await database.getTasks();
      await database.updateTask(tasks.first.copyWith(title: 'Already edited'));
      expect(await store.undoSave(before, ids), isNull);
      expect(await database.getTasks(), hasLength(2));
      expect((await store.read(before.id, 'local'))!.terminal, true);
    },
  );

  test(
    'external capture acknowledgement retries are idempotent and account-isolated',
    () async {
      const id = '3b9d0032-1fe0-41fa-a1b8-fb71fba4e84a';
      final time = DateTime.utc(2026, 9, 22, 22, 59);
      final original = await store.acceptEntry(
        id,
        'local',
        'UTC',
        text: 'Shared tomorrow',
        capturedAt: time,
      );
      await store.update(original!.copyWith(text: 'Edited shared words'));
      await database.close();
      await reopen();
      final again = await store.acceptEntry(
        id,
        'local',
        'UTC',
        text: 'Shared tomorrow',
        capturedAt: time.add(const Duration(days: 1)),
      );
      expect(again!.text, 'Edited shared words');
      expect(again.capturedAt, time);
      expect((await store.pending('local')).length, 1);
      expect(
        await store.acceptEntry(
          id,
          'other-account',
          'UTC',
          text: 'Attempt',
          capturedAt: time,
        ),
        isNull,
      );
      await store.discard(id, 'local');
      expect(
        (await store.acceptEntry(
          id,
          'local',
          'UTC',
          text: 'Shared tomorrow',
          capturedAt: time,
        ))!.terminal,
        isTrue,
      );
      expect(await store.pending('local'), isEmpty);
    },
  );

  test(
    'failed processing preserves input and retries with the original reference time',
    () async {
      final session = await store.create(
        'local',
        'Europe/Madrid',
        now: DateTime.utc(2026, 9, 20),
        audio: true,
      );
      await File(session.audioPath!).writeAsBytes(_wav());
      final api = _CaptureApi()..failure = ApiException(503, 'Unavailable');
      addTearDown(api.close);
      final processor = CaptureProcessor(store, api);
      await expectLater(
        processor.process(session),
        throwsA(isA<ApiException>()),
      );
      expect((await store.read(session.id, 'local'))!.status, 'failed');
      expect(
        (await store.read(session.id, 'local'))!.error,
        CaptureProblem.unavailable,
      );
      expect(await File(session.audioPath!).exists(), isTrue);
      await database.close();
      await reopen();
      final failed = (await store.read(session.id, 'local'))!;
      final beforeLanguage = jsonEncode(failed.toJson());
      expect(
        captureProblemText(AppLocalizationsEn(), failed.error!),
        contains('unavailable'),
      );
      expect(
        captureProblemText(AppLocalizationsEs(), failed.error!),
        contains('no está disponible'),
      );
      expect(
        jsonEncode((await store.read(session.id, 'local'))!.toJson()),
        beforeLanguage,
      );
      api.failure = null;
      final result = await CaptureProcessor(store, api).process(failed);
      expect(result.remaining.length, 2);
      expect(result.transcript, 'Coffee. Call tomorrow.');
      expect(api.requests.map((r) => r['reference_time']).toSet(), {
        '2026-09-20T00:00:00.000Z',
      });
      expect(
        await File(session.audioPath!).exists(),
        isTrue,
        reason: 'Review is not a durable task save.',
      );
    },
  );

  test(
    'ready tasks save once while uncertain drafts survive restart and other accounts cannot access them',
    () async {
      const owner = 'http://test/users/7';
      var session = await store.create(
        owner,
        'UTC',
        text: 'Coffee and call at five',
        audio: true,
      );
      await File(session.audioPath!).writeAsBytes(_wav());
      session = session.copyWith(
        status: 'ready',
        transcript: 'Keep my words',
        drafts: [
          CaptureDraft(
            id: 'coffee',
            task: Task(title: 'Coffee', priority: 1),
          ),
          CaptureDraft(
            id: 'call',
            task: Task(title: 'Call', priority: 2),
            questions: ['Morning or afternoon?'],
            confirmed: false,
          ),
        ],
      );
      await store.update(session);
      expect(await store.read(session.id, 'http://test/users/8'), isNull);
      await expectLater(
        store.saveReady(session.id, 'http://test/users/8', {'coffee'}),
        throwsStateError,
      );
      final partial = await store.saveReady(session.id, owner, {'coffee'});
      expect(partial.remaining.single.task.title, 'Call');
      expect(await File(session.audioPath!).exists(), isTrue);
      await database.close();
      await reopen();
      final recovered = (await store.pending(owner)).single;
      expect(recovered.transcript, 'Keep my words');
      await store.saveReady(session.id, owner, {'coffee'});
      expect((await database.getTasks(ownerKey: owner)).length, 1);
      expect(await database.getTasks(), isEmpty);
      expect((await database.pending(owner)).length, 1);
      final confirmed = recovered.copyWith(
        drafts: recovered.drafts
            .map((d) => d.copyWith(confirmed: true))
            .toList(),
      );
      await store.update(confirmed);
      await Future.wait([
        store.saveReady(session.id, owner, {'call'}),
        store.saveReady(session.id, owner, {'call'}),
      ]);
      expect((await database.getTasks(ownerKey: owner)).length, 2);
      expect(await store.pending(owner), isEmpty);
      expect(await File(session.audioPath!).exists(), isFalse);
      final journal = (await store.read(session.id, owner))!;
      expect(journal.transcript, isEmpty);
      expect(journal.text, isEmpty);
      expect(
        journal.drafts.every(
          (d) => d.task.title.isEmpty && d.questions.isEmpty,
        ),
        isTrue,
      );
    },
  );

  test(
    'task insertion and marking drafts saved roll back together on storage failure',
    () async {
      var session = await store.create('local', 'UTC', text: 'Two tasks');
      session = session.copyWith(
        status: 'ready',
        drafts: [
          CaptureDraft(
            id: 'a',
            task: Task(title: 'First', priority: 1),
          ),
          CaptureDraft(
            id: 'b',
            task: Task(title: 'Fail', priority: 1),
          ),
        ],
      );
      await store.update(session);
      await (await database.database).execute(
        "CREATE TRIGGER fail_insert BEFORE INSERT ON tasks WHEN NEW.title = 'Fail' BEGIN SELECT RAISE(ABORT, 'disk fault'); END",
      );
      await expectLater(
        store.saveReady(session.id, 'local', {'a', 'b'}),
        throwsA(isA<DatabaseException>()),
      );
      expect(await database.getTasks(), isEmpty);
      expect((await store.read(session.id, 'local'))!.remaining.length, 2);
      await (await database.database).execute('DROP TRIGGER fail_insert');
      await store.saveReady(session.id, 'local', {'a', 'b'});
      expect((await database.getTasks()).length, 2);
    },
  );

  test(
    'discard cannot remove another capture or revive from a late response',
    () async {
      final session = await store.create(
        'local',
        'UTC',
        text: 'Private words',
        audio: true,
      );
      await File(session.audioPath!).writeAsBytes(_wav());
      final api = _CaptureApi()..gate = Completer<void>();
      addTearDown(api.close);
      final result = CaptureProcessor(store, api).process(session);
      final expectedFailure = expectLater(result, throwsStateError);
      await api.started.future;
      await expectLater(
        store.discard(session.id, 'wrong-owner'),
        throwsStateError,
      );
      expect(await File(session.audioPath!).exists(), isTrue);
      await store.discard(session.id, 'local');
      api.gate!.complete();
      await expectedFailure;
      expect((await store.read(session.id, 'local'))!.status, 'discarded');
      expect(await store.pending('local'), isEmpty);
      expect(await File(session.audioPath!).exists(), isFalse);
      expect(await database.getTasks(), isEmpty);
    },
  );

  test('concurrent resume shares one AI request', () async {
    final session = await store.create('local', 'UTC', text: 'Two tasks');
    final api = _CaptureApi()..gate = Completer<void>();
    addTearDown(api.close);
    final a = CaptureProcessor(store, api).process(session);
    await api.started.future;
    final b = CaptureProcessor(store, api).process(session);
    api.gate!.complete();
    final results = await Future.wait([a, b]);
    expect(api.requests.length, 1);
    expect(results[0].drafts.first.id, results[1].drafts.first.id);
  });

  test(
    'recovering a killed PCM recording fixes lengths without changing samples',
    () async {
      final file = File(p.join(directory.path, 'interrupted.wav'));
      final bytes = _wav();
      ByteData.sublistView(bytes).setUint32(4, 0, Endian.little);
      ByteData.sublistView(bytes).setUint32(40, 0, Endian.little);
      await file.writeAsBytes(bytes);
      await CaptureStore.recoverWav(file.path);
      final repaired = await file.readAsBytes();
      expect(repaired.length, bytes.length);
      expect(
        ByteData.sublistView(repaired).getUint32(4, Endian.little),
        bytes.length - 8,
      );
      expect(
        ByteData.sublistView(repaired).getUint32(40, Endian.little),
        bytes.length - 44,
      );
      expect(repaired.sublist(44), bytes.sublist(44));
      await CaptureStore.recoverWav(file.path);
      expect(await file.readAsBytes(), repaired);
    },
  );

  test(
    'Android blank-header audio survives restart and processing retry',
    () async {
      var session = await store.create('local', 'Europe/Madrid', audio: true);
      session = session.copyWith(
        status: 'recording',
        audioFormat: CaptureSession.androidPcmWav,
      );
      await store.update(session);
      final bytes = Uint8List(3244);
      for (var i = 44; i < bytes.length; i++) {
        bytes[i] = i % 251;
      }
      await File(session.audioPath!).writeAsBytes(bytes);
      await database.close();
      await reopen();
      final restored = (await store.read(session.id, 'local'))!;
      expect(restored.audioFormat, CaptureSession.androidPcmWav);
      final ready = await CaptureProcessor(
        store,
        _CaptureApi(),
      ).process(restored);
      expect(ready.status, 'ready');
      final repaired = await File(session.audioPath!).readAsBytes();
      final header = ByteData.sublistView(repaired);
      expect(repaired.length, bytes.length);
      expect(ascii.decode(repaired.sublist(0, 4)), 'RIFF');
      expect(header.getUint32(4, Endian.little), bytes.length - 8);
      expect(header.getUint32(24, Endian.little), 16000);
      expect(header.getUint16(22, Endian.little), 1);
      expect(header.getUint16(34, Endian.little), 16);
      expect(header.getUint32(40, Endian.little), bytes.length - 44);
      expect(repaired.sublist(44), bytes.sublist(44));
      await CaptureStore.recoverWav(
        session.audioPath!,
        audioFormat: restored.audioFormat,
      );
      expect(await File(session.audioPath!).readAsBytes(), repaired);
    },
  );

  test(
    'blank headers without a known format and partial frames stay intact',
    () async {
      final file = File(p.join(directory.path, 'unknown.wav'));
      final bytes = Uint8List(60)..[44] = 12;
      await file.writeAsBytes(bytes);
      for (final format in [null, 'unknown-codec']) {
        await CaptureStore.recoverWav(file.path, audioFormat: format);
        expect(await file.readAsBytes(), bytes);
      }
      final partial = Uint8List(61)..[44] = 12;
      await file.writeAsBytes(partial);
      await expectLater(
        CaptureStore.recoverWav(
          file.path,
          audioFormat: CaptureSession.androidPcmWav,
        ),
        throwsFormatException,
      );
      expect(await file.readAsBytes(), partial);
      final malformed = Uint8List(60)..[0] = 12;
      await file.writeAsBytes(malformed);
      await CaptureStore.recoverWav(
        file.path,
        audioFormat: CaptureSession.androidPcmWav,
      );
      expect(await file.readAsBytes(), malformed);
    },
  );

  test(
    'typed extraction never contributes fake audio transcription timings',
    () async {
      final session = await store.create('local', 'UTC', text: 'Buy coffee');
      await CaptureProcessor(store, _CaptureApi()).process(session);
      final rows = await CaptureDiagnostics(database).summary();
      expect(
        rows.singleWhere((r) => r['event'] == 'transcription')['samples'],
        0,
      );
      expect(rows.singleWhere((r) => r['event'] == 'extraction')['samples'], 1);
    },
  );

  test(
    'diagnostics retain only bounded counters and timing percentiles',
    () async {
      final diagnostics = CaptureDiagnostics(database);
      for (final elapsed in [100, 200, 300, 400, 500]) {
        await diagnostics.record(CaptureEvent.processing, elapsedMs: elapsed);
      }
      final summary = (await diagnostics.summary()).firstWhere(
        (r) => r['event'] == 'processing',
      );
      expect(summary, containsPair('samples', 5));
      expect(summary, containsPair('timed_samples', 5));
      expect(summary, containsPair('p50_ms', 300));
      expect(summary, containsPair('p95_ms', 500));
      final row = (await (await database.database).query('diagnostics')).first;
      expect(row.keys.toSet(), {
        'id',
        'event',
        'elapsed_ms',
        'count',
        'created_at',
      });
      await diagnostics.clear();
      expect(
        (await diagnostics.summary()).every((r) => r['samples'] == 0),
        isTrue,
      );
    },
  );
}

Uint8List _wav() {
  final bytes = Uint8List(32044);
  final data = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, ascii.encode('RIFF'));
  bytes.setRange(8, 12, ascii.encode('WAVE'));
  bytes.setRange(12, 16, ascii.encode('fmt '));
  data.setUint32(4, bytes.length - 8, Endian.little);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, ascii.encode('data'));
  data.setUint32(40, bytes.length - 44, Endian.little);
  return bytes;
}

class _CaptureApi extends ApiClient {
  Object? failure;
  Completer<void>? gate;
  final started = Completer<void>();
  final requests = <Map<String, dynamic>>[];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    requests.add({...?data});
    if (!started.isCompleted) started.complete();
    await gate?.future;
    if (failure != null) throw failure!;
    return {
      'transcript': 'Coffee. Call tomorrow.',
      'tasks': [
        {
          'title': 'Coffee',
          'due_date': null,
          'scheduled_date': null,
          'priority': 1,
          'notes': '',
          'questions': [],
        },
        {
          'title': 'Call',
          'due_date': null,
          'scheduled_date': '2026-09-21',
          'priority': 2,
          'notes': '',
          'questions': [],
        },
      ],
      'timings': {'transcription_ms': 100, 'extraction_ms': 200},
    };
  }
}
