import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/meeting_api.dart';
import 'package:agenda/services/meeting_background.dart';
import 'package:agenda/services/meeting_store.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/meeting_fakes.dart';

const server = 'https://api.example.invalid';
const meetingId = '0b3f7d8e-1c2a-4f5b-9e6d-7a8b9c0d1e2f';

Map<String, dynamic> session({
  String access = 'old-access',
  String refresh = 'old-refresh',
  int id = 7,
}) => {
  'access': access,
  'refresh': refresh,
  'user': {'id': id, 'email': 'm@example.invalid', 'timezone': 'Europe/Madrid'},
};

Future<Map<String, dynamic>> saved() async => jsonDecode(
  (await const FlutterSecureStorage().read(key: 'taskflow.session'))!,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(
    () => FlutterSecureStorage.setMockInitialValues({
      'taskflow.session': jsonEncode(session()),
      'taskflow.server': server,
    }),
  );

  group('the four calls of MEETINGS.md, through the app’s login', () {
    late Directory directory;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('taskflow-meeting-api-');
    });
    tearDown(() => directory.delete(recursive: true));

    test('a piece is a multipart PUT with its audio type, offset, duration and language', () async {
      final requests = <http.Request>[];
      final client = ApiClient(
        transport: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({'meeting_id': meetingId, 'index': 3, 'saved': true, 'status': 'recording'}),
            200,
          );
        }),
      );
      addTearDown(client.close);
      await client.restore();
      final file = File(p.join(directory.path, 'piece.ogg'))..writeAsBytesSync([1, 2, 3]);
      final answer = await ApiMeetingApi(client, 7).uploadPiece(
        MeetingPiece(
          meetingId: meetingId,
          ownerKey: '$server/users/7',
          index: 3,
          offset: const Duration(minutes: 15, milliseconds: 250),
          duration: const Duration(minutes: 5, seconds: 2),
          path: file.path,
          state: MeetingPiece.pending,
        ),
        format: MeetingAudioFormat.opus,
        language: 'es-ES',
      );
      expect(answer.saved, isTrue);
      final request = requests.single;
      expect(request.method, 'PUT');
      expect(request.url.toString(), '$server/api/meetings/$meetingId/pieces/3/');
      expect(request.headers['Authorization'], 'Bearer old-access');
      final body = utf8.decode(request.bodyBytes, allowMalformed: true);
      expect(body, contains('name="offset_seconds"\r\n\r\n900.250'));
      expect(body, contains('name="duration_seconds"\r\n\r\n302.000'));
      expect(body, contains('name="language"\r\n\r\nes-ES'));
      expect(body, contains('name="audio"; filename="piece-3.ogg"'));
      expect(body, contains('content-type: audio/ogg'));
    });

    test('a refused piece carries the server’s Retry-After', () async {
      final client = ApiClient(
        transport: MockClient(
          (request) async => http.Response(
            '{"detail":"Busy."}',
            503,
            headers: {'retry-after': '120'},
          ),
        ),
      );
      addTearDown(client.close);
      await client.restore();
      final file = File(p.join(directory.path, 'piece.ogg'))..writeAsBytesSync([1, 2, 3]);
      await expectLater(
        ApiMeetingApi(client, 7).uploadPiece(
          MeetingPiece(
            meetingId: meetingId,
            ownerKey: '$server/users/7',
            index: 0,
            offset: Duration.zero,
            duration: const Duration(minutes: 5),
            path: file.path,
            state: MeetingPiece.pending,
          ),
          format: MeetingAudioFormat.opus,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 503)
              .having((e) => e.retryAfter, 'retryAfter', const Duration(minutes: 2)),
        ),
      );
    });

    test('finish, GET and DELETE are JSON calls; waiting and 404 read as such', () async {
      final requests = <http.Request>[];
      final client = ApiClient(
        transport: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/finish/')) {
            return http.Response(jsonEncode({'status': 'waiting', 'missing': [7, 8]}), 202);
          }
          if (request.method == 'DELETE') return http.Response('', 204);
          return http.Response('{"detail":"Not found."}', 404);
        }),
      );
      addTearDown(client.close);
      await client.restore();
      final api = ApiMeetingApi(client, 7);
      final answer = await api.finish(meetingId, 49);
      expect(answer.ready, isFalse);
      expect(answer.missing, [7, 8]);
      expect(jsonDecode(requests.last.body), {'last_index': 49});
      expect(await api.status(meetingId), isNull);
      await api.delete(meetingId);
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'POST /api/meetings/$meetingId/finish/',
        'GET /api/meetings/$meetingId/',
        'DELETE /api/meetings/$meetingId/',
      ]);
    });

    test('another account’s login never sends a piece (MN-13)', () async {
      var sent = false;
      final client = ApiClient(
        transport: MockClient((_) async {
          sent = true;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(client.close);
      await client.restore();
      await expectLater(
        ApiMeetingApi(client, 8).finish(meetingId, 0),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
      expect(sent, isFalse);
    });

    test('the background task uploads, finishes and saves the note with the app closed', () async {
      final sql = await databaseFactoryFfi.openDatabase(p.join(directory.path, 'bg.db'));
      addTearDown(sql.close);
      await sql.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
      );
      await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
      final database = TaskDatabase.forTesting(sql);
      final store = MeetingStore(database, directory: Directory(p.join(directory.path, 'audio')));
      final clock = FakeClock();
      const owner = '$server/users/7';
      final meeting = await store.create(owner, format: MeetingAudioFormat.aac, now: clock.now, id: meetingId);
      final path = await store.piecePath(meetingId, Duration.zero, meeting.format);
      File(path).writeAsBytesSync(List.filled(2048, 1));
      await store.openPiece(meeting, index: 0, offset: Duration.zero, path: path, now: clock.now);
      await store.closePiece(meeting, index: 0, duration: const Duration(minutes: 4), hasSound: true, now: clock.now);
      await store.finish(meetingId, owner, clock.now);

      final calls = <String>[];
      final client = ApiClient(
        transport: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          if (request.method == 'PUT') {
            expect(utf8.decode(request.bodyBytes, allowMalformed: true), contains('content-type: audio/aac'));
            return http.Response(jsonEncode({'saved': true, 'status': 'ready'}), 200);
          }
          if (request.method == 'POST') {
            return http.Response.bytes(
              utf8.encode(jsonEncode({
                'status': 'ready',
                'result': {
                  'title': 'Reunión del piloto',
                  'summary': 'Acordamos el piloto.',
                  'todos': [{'text': 'Enviar la oferta', 'who': null, 'when': 'el viernes'}],
                  'decisions': [],
                  'open_questions': [],
                  'chapters': [],
                  'start_missing': false,
                  'language': 'es',
                },
              })),
              200,
            );
          }
          return http.Response('', 204);
        }),
      );
      addTearDown(client.close);
      await client.restore();
      expect(await runMeetingUploads(api: client, store: store, clock: clock.call), isTrue);
      expect(calls, [
        'PUT /api/meetings/$meetingId/pieces/0/',
        'POST /api/meetings/$meetingId/finish/',
        'DELETE /api/meetings/$meetingId/',
      ]);
      final note = (await database.getTasks(ownerKey: owner)).single;
      expect(note.title, 'Reunión del piloto');
      expect(note.checklist.single.title, 'Enviar la oferta · el viernes');
      expect(File(path).existsSync(), isFalse);
      expect((await store.meeting(meetingId, owner))!.phase, MeetingPhase.done);
    });

    test('the background task asks to run again when offline, and does nothing signed out', () async {
      final sql = await databaseFactoryFfi.openDatabase(p.join(directory.path, 'bg2.db'));
      addTearDown(sql.close);
      await sql.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
      );
      await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
      final store = MeetingStore(TaskDatabase.forTesting(sql), directory: Directory(p.join(directory.path, 'audio')));
      final clock = FakeClock();
      const owner = '$server/users/7';
      final meeting = await store.create(owner, format: MeetingAudioFormat.opus, now: clock.now, id: meetingId);
      final path = await store.piecePath(meetingId, Duration.zero, meeting.format);
      File(path).writeAsBytesSync(List.filled(2048, 1));
      await store.openPiece(meeting, index: 0, offset: Duration.zero, path: path, now: clock.now);
      await store.closePiece(meeting, index: 0, duration: const Duration(minutes: 4), hasSound: true, now: clock.now);
      final client = ApiClient(
        transport: MockClient((_) async => throw const SocketException('Failed host lookup')),
      );
      addTearDown(client.close);
      await client.restore();
      expect(await runMeetingUploads(api: client, store: store, clock: clock.call), isFalse);
      expect(File(path).existsSync(), isTrue);
      FlutterSecureStorage.setMockInitialValues({});
      final signedOut = ApiClient(transport: MockClient((_) async => http.Response('{}', 200)));
      addTearDown(signedOut.close);
      expect(await runMeetingUploads(api: signedOut, store: store, clock: clock.call), isTrue);
    });
  });

  group('two engines of the app share one login', () {
    test('a refresh uses the tokens the background worker saved, not the ones it replaced', () async {
      final refreshedWith = <String>[];
      final client = ApiClient(
        transport: MockClient((request) async {
          if (request.url.path.endsWith('/refresh/')) {
            final token = jsonDecode(request.body)['refresh'] as String;
            refreshedWith.add(token);
            if (token != 'bg-refresh') return http.Response('{"detail":"Token is blacklisted"}', 401);
            return http.Response(jsonEncode({'access': 'new-access', 'refresh': 'new-refresh'}), 200);
          }
          if (request.headers['Authorization'] != 'Bearer new-access') {
            return http.Response('{"detail":"Expired"}', 401);
          }
          return http.Response('{"results":[]}', 200);
        }),
      );
      addTearDown(client.close);
      await client.restore();
      // The worker refreshed meanwhile, in its own engine.
      await const FlutterSecureStorage().write(
        key: 'taskflow.session',
        value: jsonEncode(session(access: 'bg-access', refresh: 'bg-refresh')),
      );
      var invalidated = false;
      client.sessionInvalidated.listen((_) => invalidated = true);
      await client.request('GET', 'tasks/');
      expect(refreshedWith, ['bg-refresh']);
      expect(invalidated, isFalse);
      expect(client.account?.id, 7);
      expect((await saved())['refresh'], 'new-refresh');
    });

    test('a refresh refused because the worker refreshed at the same moment takes the worker’s', () async {
      final refreshedWith = <String>[];
      final client = ApiClient(
        transport: MockClient((request) async {
          if (request.url.path.endsWith('/refresh/')) {
            final token = jsonDecode(request.body)['refresh'] as String;
            refreshedWith.add(token);
            if (token == 'old-refresh') {
              // The worker won the race and saved its new session first.
              await const FlutterSecureStorage().write(
                key: 'taskflow.session',
                value: jsonEncode(session(access: 'bg-access', refresh: 'bg-refresh')),
              );
              return http.Response('{"detail":"Token is blacklisted"}', 401);
            }
            return http.Response(jsonEncode({'access': 'new-access', 'refresh': 'new-refresh'}), 200);
          }
          if (request.headers['Authorization'] != 'Bearer new-access') {
            return http.Response('{"detail":"Expired"}', 401);
          }
          return http.Response('{"results":[]}', 200);
        }),
      );
      addTearDown(client.close);
      await client.restore();
      await client.request('GET', 'tasks/');
      expect(refreshedWith, ['old-refresh', 'bg-refresh']);
      expect((await saved())['refresh'], 'new-refresh');
    });

    test('a refused refresh with nothing newer saved still signs out', () async {
      final client = ApiClient(
        transport: MockClient((request) async => http.Response('{"detail":"no"}', 401)),
      );
      addTearDown(client.close);
      await client.restore();
      await expectLater(client.request('GET', 'tasks/'), throwsA(isA<ApiException>()));
      expect(client.account, isNull);
      expect(await const FlutterSecureStorage().read(key: 'taskflow.session'), isNull);
    });

    test('a refusal while the other engine is still saving its new session waits for it', () async {
      final refreshedWith = <String>[];
      final client = ApiClient(
        sessionRaceWait: const Duration(milliseconds: 100),
        transport: MockClient((request) async {
          if (request.url.path.endsWith('/refresh/')) {
            final token = jsonDecode(request.body)['refresh'] as String;
            refreshedWith.add(token);
            if (token == 'old-refresh') {
              // The worker won, but saves its session only a moment later.
              unawaited(
                Future<void>.delayed(const Duration(milliseconds: 150), () async {
                  await const FlutterSecureStorage().write(
                    key: 'taskflow.session',
                    value: jsonEncode(session(access: 'bg-access', refresh: 'bg-refresh')),
                  );
                }),
              );
              return http.Response('{"detail":"Token is blacklisted"}', 401);
            }
            return http.Response(jsonEncode({'access': 'new-access', 'refresh': 'new-refresh'}), 200);
          }
          if (request.headers['Authorization'] != 'Bearer new-access') {
            return http.Response('{"detail":"Expired"}', 401);
          }
          return http.Response('{"results":[]}', 200);
        }),
      );
      addTearDown(client.close);
      await client.restore();
      var invalidated = false;
      client.sessionInvalidated.listen((_) => invalidated = true);
      await client.request('GET', 'tasks/');
      expect(refreshedWith, ['old-refresh', 'bg-refresh']);
      expect(invalidated, isFalse);
      expect((await saved())['refresh'], 'new-refresh');
    });

    test('the background engine never removes the saved session on a refusal', () async {
      final client = ApiClient(
        background: true,
        transport: MockClient((request) async => http.Response('{"detail":"no"}', 401)),
      );
      addTearDown(client.close);
      await client.restore();
      await expectLater(client.request('GET', 'tasks/'), throwsA(isA<ApiException>()));
      // This engine stops; the app decides.
      expect(client.account, isNull);
      expect((await saved())['refresh'], 'old-refresh');
    });

    test('saving account details keeps tokens the worker saved', () async {
      final client = ApiClient(transport: MockClient((_) async => http.Response('{}', 200)));
      addTearDown(client.close);
      await client.restore();
      await const FlutterSecureStorage().write(
        key: 'taskflow.session',
        value: jsonEncode(session(access: 'bg-access', refresh: 'bg-refresh')),
      );
      await client.rememberFreeVoice({
        'limit': 5,
        'left': 3,
        'resets_at': '2026-12-01T00:00:00Z',
      }, accountId: 7);
      final value = await saved();
      expect(value['refresh'], 'bg-refresh');
      expect(value['user']['free_voice']['left'], 3);
    });
  });
}
