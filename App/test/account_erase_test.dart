// What deleting the account leaves on the phone: nothing of that account,
// and no request with it afterwards. The screens are in
// delete_account_test.dart.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agenda/providers/no_retry.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/repositories/cloud_task_repository.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/services/account_deletion.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/attachment_files.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/google_sign_in_service.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/meeting_store.dart';
import 'package:agenda/models/meeting.dart';
import 'package:agenda/services/task_database.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final session = {
  'access': 'old-access',
  'refresh': 'old-refresh',
  'user': {'id': 1, 'email': 'ana@example.invalid', 'timezone': 'Europe/Madrid'},
};

/// A database at the current schema, as the attachment tests build it.
Future<TaskDatabase> openDatabase(String path) async {
  final sql = await databaseFactoryFfi.openDatabase(path);
  await sql.execute(
    'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
  );
  await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
  return TaskDatabase.forTesting(sql);
}

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Google extends GoogleSignInService {
  int signOuts = 0;
  @override
  Future<void> signOut() async => signOuts++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('erasing a deleted account from the phone', () {
    const gone = 'http://erase.test/users/1';
    const other = 'http://erase.test/users/2';
    late Directory directory;
    late TaskDatabase database;
    late LocalAccountData local;
    late Directory captures;
    late CaptureStore captureStore;
    late MeetingStore meetingStore;
    String scope(String owner) =>
        sha256.convert(utf8.encode(owner)).toString();

    Future<File> file(String path) async {
      final file = File(p.join(directory.path, path));
      await file.parent.create(recursive: true);
      return file.writeAsBytes([1, 2, 3]);
    }

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('taskflow-erase-');
      database = await openDatabase(p.join(directory.path, 'data.db'));
      captures = Directory(p.join(directory.path, 'captures'));
      captureStore = CaptureStore(database, directory: captures);
      meetingStore = MeetingStore(
        database,
        directory: Directory(p.join(directory.path, 'meetings')),
      );
      local = LocalAccountData(
        database,
        files: AttachmentFiles(
          directory: Directory(p.join(directory.path, 'attachments')),
        ),
        captures: captureStore,
        meetings: meetingStore,
      );
    });
    tearDown(() async {
      await database.close();
      expect(p.isWithin(Directory.systemTemp.path, directory.path), isTrue);
      await directory.delete(recursive: true);
    });

    test(
      'its recorded meetings go with their audio; another account’s stay',
      () async {
        final now = DateTime.utc(2026, 11, 3, 10);
        Future<(Meeting, List<File>)> recorded(String owner) async {
          final meeting = await meetingStore.create(
            owner,
            format: MeetingAudioFormat.opus,
            now: now,
          );
          final files = <File>[];
          for (var i = 0; i < 2; i++) {
            final path = await meetingStore.piecePath(
              meeting.id,
              Duration(minutes: 5 * i),
              meeting.format,
            );
            files.add(await File(path).writeAsBytes(List.filled(2048, 1)));
            if (i == 0) {
              await meetingStore.openPiece(
                meeting,
                index: 0,
                offset: Duration.zero,
                path: path,
                now: now,
              );
            }
          }
          await meetingStore.closePiece(
            meeting,
            index: 0,
            duration: const Duration(minutes: 5),
            hasSound: true,
            now: now,
            nextPath: files[1].path,
          );
          await meetingStore.acquireLease(owner, 'app', now);
          return (meeting, files);
        }

        final (mine, myFiles) = await recorded(gone);
        final (theirs, theirFiles) = await recorded(other);
        await local.erase(gone);

        expect(await meetingStore.meeting(mine.id, gone), isNull);
        expect(await meetingStore.pieces(mine.id, gone), isEmpty);
        expect(await meetingStore.backlog(gone), isA<MeetingBacklog>().having((b) => b.isEmpty, 'isEmpty', isTrue));
        final sql = await database.database;
        expect(await sql.query('meeting_leases', where: 'owner_key = ?', whereArgs: [gone]), isEmpty);
        for (final file in myFiles) {
          expect(file.existsSync(), isFalse);
        }
        expect(myFiles.first.parent.existsSync(), isFalse);
        expect(await meetingStore.meeting(theirs.id, other), isNotNull);
        expect(await meetingStore.pieces(theirs.id, other), hasLength(2));
        for (final file in theirFiles) {
          expect(file.existsSync(), isTrue);
        }
      },
    );

    test(
      'every record of the account goes, with the app’s copies of its files, its downloads and its recordings; other accounts, what was kept before signing in, and the person’s own files stay',
      () async {
        final copy = await file('attachments/local/u-1/receipt.pdf');
        final shared = await file('attachments/local/u-2/plan.pdf');
        final othersCopy = await file('attachments/local/u-3/photo.jpg');
        final download = await file(
          'attachments/cache/${scope(gone)}/att-1/blood-test.pdf',
        );
        final leftover = await file(
          'attachments/cache/${scope(gone)}/att-9/old.pdf.part-1',
        );
        final othersDownload = await file(
          'attachments/cache/${scope(other)}/att-2/menu.pdf',
        );
        final ownFile = await file('person/My scan.pdf');

        await database.insertTask(
          Task(
            title: 'Médico',
            priority: 1,
            filePaths: [copy.path, shared.path, ownFile.path],
          ),
          ownerKey: gone,
        );
        await database.insertTask(
          Task(title: 'Idea', priority: 1, kind: 'note'),
          ownerKey: gone,
        );
        await database.insertTask(
          Task(
            title: 'Compra',
            priority: 1,
            filePaths: [shared.path],
            imagePaths: [othersCopy.path],
          ),
          ownerKey: other,
        );
        await database.insertTask(Task(title: 'Antes de entrar', priority: 1));
        final db = await database.database;
        Future<String> syncId(String owner) async =>
            (await db.query(
                  'tasks',
                  where: 'owner_key = ?',
                  whereArgs: [owner],
                  limit: 1,
                )).single['sync_id']
                as String;
        for (final (owner, id, path) in [
          (gone, 'att-1', download.path),
          (other, 'att-2', othersDownload.path),
        ]) {
          await db.insert('task_attachments', {
            'owner_key': owner,
            'id': id,
            'task_id': await syncId(owner),
            'name': p.basename(path),
            'local_path': path,
            'remote': 1,
          });
        }
        final now = DateTime.utc(2026, 10, 15).toIso8601String();
        for (final owner in [gone, other, 'local']) {
          await db.insert('task_lists', {
            'id': 'list-${owner.hashCode}',
            'owner_key': owner,
            'name': 'Casa',
          });
        }
        for (final owner in [gone, other]) {
          await db.insert('list_imports', {
            'owner_key': owner,
            'source_id': 's',
            'target_id': 't',
          });
          await db.insert('archive_imports', {
            'owner_key': owner,
            'archive_id': 'a',
            'source_id': 's',
            'kind': 'task',
            'target_id': 't',
          });
          await db.insert('reminder_state', {
            'owner_key': owner,
            'identity': '$owner/task/1/once',
            'fire_at': now,
            'title': 'Médico',
            'body': 'In 10 min',
            'status': 'scheduled',
            'updated_at': now,
          });
          await db.insert('reminder_snoozes', {
            'identity': '$owner/task/1/once',
            'owner_key': owner,
            'fire_at': now,
          });
          final capture = await captureStore.create(
            owner,
            'Europe/Madrid',
            text: 'llamar al dentista',
            audio: true,
          );
          await File(capture.audioPath!).writeAsBytes([1, 2, 3]);
        }
        for (final scope in [
          'reminders:$gone',
          'firstTask:$gone',
          'calendars:$gone',
          'groups:$gone',
          'sharing:$gone',
          'freeVoiceNotice:$gone',
          'reminders:$other',
          'regional',
        ]) {
          await db.insert('app_preferences', {'scope': scope, 'data': '{}'});
        }
        final goneAudio = File(
          p.join(
            captures.path,
            '${(await db.query('captures', where: 'owner_key = ?', whereArgs: [gone])).single['id']}.wav',
          ),
        );
        final otherAudio = File(
          p.join(
            captures.path,
            '${(await db.query('captures', where: 'owner_key = ?', whereArgs: [other])).single['id']}.wav',
          ),
        );
        expect(await goneAudio.exists(), isTrue);

        await local.erase(gone);

        for (final table in [
          'tasks',
          'task_attachments',
          'task_lists',
          'list_imports',
          'archive_imports',
          'captures',
          'reminder_state',
          'reminder_snoozes',
        ]) {
          final left = await db.query(
            table,
            where: 'owner_key = ?',
            whereArgs: [gone],
          );
          expect(left, isEmpty, reason: table);
          final kept = await db.query(
            table,
            where: 'owner_key = ?',
            whereArgs: [other],
          );
          expect(kept, isNotEmpty, reason: table);
        }
        expect(await database.getTasks(), hasLength(1), reason: 'guest data');
        expect(
          (await db.query('task_lists', where: "owner_key = 'local'")),
          hasLength(1),
        );
        expect(
          (await db.query('app_preferences')).map((row) => row['scope']),
          unorderedEquals(['reminders:$other', 'regional']),
        );

        expect(await copy.exists(), isFalse);
        expect(await download.exists(), isFalse);
        expect(await leftover.exists(), isFalse);
        expect(
          await Directory(
            p.join(directory.path, 'attachments', 'cache', scope(gone)),
          ).exists(),
          isFalse,
        );
        expect(await goneAudio.exists(), isFalse);
        expect(await shared.exists(), isTrue, reason: 'still used by account 2');
        expect(await othersCopy.exists(), isTrue);
        expect(await othersDownload.exists(), isTrue);
        expect(await otherAudio.exists(), isTrue);
        expect(await ownFile.exists(), isTrue, reason: 'never the person’s own');
      },
    );

    test('only a signed-in account is erased', () async {
      await database.insertTask(Task(title: 'Antes de entrar', priority: 1));
      for (final owner in ['local', 'signed-out']) {
        await expectLater(local.erase(owner), throwsArgumentError);
      }
      expect(await database.getTasks(), hasLength(1));
    });
  });

  group('after the account is deleted, nothing is sent with it', () {
    setUp(
      () => FlutterSecureStorage.setMockInitialValues({
        'taskflow.session': jsonEncode(session),
      }),
    );

    test(
      'forgetting the session asks nothing of the server, and requests for that account are refused before they leave',
      () async {
        final sent = <String>[];
        final api = ApiClient(
          transport: MockClient((request) async {
            sent.add(request.url.path);
            return http.Response('{}', 200);
          }),
        );
        addTearDown(api.close);
        await api.restore();
        expect(api.account!.id, 1);
        await api.forgetSession();
        expect(api.account, isNull);
        expect(
          await const FlutterSecureStorage().read(key: 'taskflow.session'),
          isNull,
        );
        await expectLater(
          api.request('GET', 'tasks/', accountId: 1),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
        );
        await expectLater(
          api.downloadAttachment('att-1', accountId: 1),
          throwsA(isA<ApiException>()),
        );
        await expectLater(api.refreshAccount(), throwsA(isA<ApiException>()));
        expect(sent, isEmpty);
      },
    );

    test(
      'an answer still on its way is refused when it arrives, without trying the old refresh token',
      () async {
        final started = Completer<void>();
        final answer = Completer<http.Response>();
        final sent = <String>[];
        final api = ApiClient(
          transport: MockClient((request) async {
            sent.add(request.url.path);
            if (!started.isCompleted) started.complete();
            return answer.future;
          }),
        );
        addTearDown(api.close);
        await api.restore();
        final refused = expectLater(
          api.request('GET', 'tasks/', accountId: 1),
          throwsA(isA<ApiException>()),
        );
        await started.future;
        await api.forgetSession();
        // The deleted account's token no longer works.
        answer.complete(http.Response('{"detail":"User not found"}', 401));
        await refused;
        expect(sent, ['/api/tasks/']);
        expect(api.account, isNull);
      },
    );

    test('signing out still tells the server first', () async {
      final sent = <String>[];
      final api = ApiClient(
        transport: MockClient((request) async {
          sent.add('${request.method} ${request.url.path}');
          return http.Response('', 204);
        }),
      );
      addTearDown(api.close);
      await api.restore();
      await api.signOut();
      expect(sent, ['POST /api/auth/logout/']);
      expect(api.account, isNull);
      expect(
        await const FlutterSecureStorage().read(key: 'taskflow.session'),
        isNull,
      );
    });

    test(
      'a sync under way ends at its next request, and settled waits for it; a new sync sends nothing',
      () async {
        final database = await openDatabase(inMemoryDatabasePath);
        addTearDown(database.close);
        final asked = Completer<void>();
        final access = Completer<http.Response>();
        final sent = <String>[];
        final api = ApiClient(
          transport: MockClient((request) async {
            sent.add('${request.method} ${request.url.path}');
            if (!asked.isCompleted) asked.complete();
            return access.future;
          }),
        );
        addTearDown(api.close);
        await api.restore();
        final repository = CloudTaskRepository(database, api, 1);
        final sync = repository.sync();
        await asked.future;
        var settled = false;
        final waiting = repository.settled.then((_) => settled = true);
        await api.forgetSession();
        await settle();
        expect(settled, isFalse, reason: 'its answer hasn’t come yet');
        access.complete(http.Response(jsonEncode({'lists': []}), 200));
        await waiting;
        await sync;
        expect(sent, ['GET /api/lists/access/']);
        await repository.sync();
        expect(sent, hasLength(1));
        // Without an account there is never a sync to wait for.
        await TaskRepository(database).settled;
      },
    );

    test(
      'forgetting a deleted account: nothing sent, sign-in says it was deleted, reminders stop, then the erase; the notice goes on the next try',
      () async {
        final sent = <String>[];
        final api = ApiClient(
          transport: MockClient((request) async {
            sent.add(request.url.path);
            return http.Response(jsonEncode(session['user']), 200);
          }),
        );
        addTearDown(api.close);
        final google = _Google();
        final events = <String>[];
        late final AuthNotifier auth;
        auth = AuthNotifier(
          api,
          google: google,
          activateReminders: (owner) async => events.add('reminders $owner'),
          prepareErase: (accountId) {
            // Readied while the account is still signed in.
            events.add('ready $accountId: ${auth.state.account?.id}');
            return () async {
              events.add('erase');
              expect(auth.state.account, isNull, reason: 'sign-in first');
            };
          },
        );
        addTearDown(auth.dispose);
        await settle();
        expect(auth.state.account!.id, 1);
        expect(sent, ['/api/auth/me/'], reason: 'the usual refresh on opening');
        sent.clear();
        events.clear();

        await auth.forgetDeletedAccount();
        expect(events, ['ready 1: 1', 'reminders signed-out', 'erase']);
        // Once: asking again changes nothing.
        await auth.forgetDeletedAccount();
        expect(events, hasLength(3));
        expect(auth.state.account, isNull);
        expect(auth.state.deleted, isTrue);
        expect(api.account, isNull);
        expect(google.signOuts, 1);
        expect(
          await const FlutterSecureStorage().read(key: 'taskflow.session'),
          isNull,
        );
        await auth.refreshAccount();
        expect(sent, isEmpty);

        auth.clearError();
        expect(auth.state.deleted, isFalse);
      },
    );

    test(
      'an erase that fails still leaves the phone signed out of the deleted account',
      () async {
        final api = ApiClient(
          transport: MockClient(
            (_) async => http.Response(jsonEncode(session['user']), 200),
          ),
        );
        addTearDown(api.close);
        final auth = AuthNotifier(
          api,
          activateReminders: (_) async {},
          prepareErase: (_) =>
              () async => throw const FileSystemException('Busy'),
        );
        addTearDown(auth.dispose);
        await settle();
        await expectLater(
          auth.forgetDeletedAccount(),
          throwsA(isA<FileSystemException>()),
        );
        expect(auth.state.account, isNull);
        expect(auth.state.deleted, isTrue);
        expect(api.account, isNull);
      },
    );
  });

  group('when the server says the account no longer exists', () {
    const goneBody = {'detail': 'User not found', 'code': 'user_not_found'};
    const endedBody = {'detail': 'Your session has ended. Please sign in again.'};
    const expiredBody = {
      'detail': 'Given token not valid for any token type',
      'code': 'token_not_valid',
    };
    late Directory directory;
    late TaskDatabase database;
    late ApiClient api;
    late ProviderContainer container;
    late String owner;
    late List<String> sent;
    late List<String> log;
    late Future<http.Response> Function(http.Request request) answer;
    var readied = 0;
    var erased = 0;
    http.Response reply(Object body, [int status = 200]) =>
        http.Response(jsonEncode(body), status);
    AuthNotifier auth() => container.read(authProvider.notifier);

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({
        'taskflow.session': jsonEncode(session),
      });
      directory = await Directory.systemTemp.createTemp('taskflow-gone-');
      database = await openDatabase(p.join(directory.path, 'data.db'));
      sent = [];
      log = [];
      readied = 0;
      erased = 0;
      answer = (_) async => reply(goneBody, 401);
      api = ApiClient(
        transport: MockClient((request) async {
          sent.add('${request.method} ${request.url.path}');
          if (request.url.path == '/api/auth/me/' && sent.length == 1) {
            return reply(session['user']!); // opening the app
          }
          return answer(request);
        }),
      );
      owner = '${api.baseUrl}/users/1';
      container = ProviderContainer(
        retry: noRetry,
        overrides: [
          apiClientProvider.overrideWithValue(api),
          taskRepositoryProvider.overrideWithValue(
            CloudTaskRepository(database, api, 1),
          ),
          localAccountDataProvider.overrideWithValue(
            LocalAccountData(
              database,
              files: AttachmentFiles(
                directory: Directory(p.join(directory.path, 'attachments')),
              ),
              captures: CaptureStore(
                database,
                directory: Directory(p.join(directory.path, 'captures')),
              ),
            ),
          ),
          invitationLinkProvider.overrideWith(
            (ref) => InvitationLinks(listen: false),
          ),
          authProvider.overrideWith(
            (ref) => AuthNotifier(
              api,
              google: _Google(),
              activateReminders: (owner) async => log.add('reminders $owner'),
              prepareErase: (accountId) {
                readied++;
                final erase = prepareAccountErase(ref.read, accountId);
                return () async {
                  erased++;
                  await erase();
                };
              },
            ),
          ),
        ],
      );
      container.read(authProvider);
      await settle();
      expect(container.read(authProvider).account!.id, 1);
      await database.insertTask(
        Task(title: 'Médico', priority: 1),
        ownerKey: owner,
      );
      await database.insertTask(
        Task(title: 'Compra', priority: 1),
        ownerKey: '${api.baseUrl}/users/2',
      );
    });
    tearDown(() async {
      container.dispose();
      api.close();
      await database.close();
      await directory.delete(recursive: true);
    });

    Future<List<Task>> tasks(String key) => database.getTasks(ownerKey: key);

    test(
      'a 401 user_not_found on a sync erases this account’s data, and sign-in says it was deleted; no refresh is tried and nothing more is sent',
      () async {
        await container.read(taskRepositoryProvider).sync();
        await settle();
        await auth().forgetDeletedAccount();
        final state = container.read(authProvider);
        expect(state.account, isNull);
        expect(state.deleted, isTrue, reason: 'Tu cuenta se ha eliminado.');
        expect(state.expired, isFalse);
        expect(await tasks(owner), isEmpty);
        expect(await tasks('${api.baseUrl}/users/2'), hasLength(1));
        expect(log, ['reminders $owner', 'reminders signed-out']);
        expect(readied, 1);
        expect(erased, 1);
        expect(sent, ['GET /api/auth/me/', 'GET /api/lists/access/']);
        expect(
          await const FlutterSecureStorage().read(key: 'taskflow.session'),
          isNull,
        );
        await container.read(taskRepositoryProvider).sync();
        await auth().refreshAccount();
        expect(sent, hasLength(2));
      },
    );

    test('a refresh answered with user_not_found erases too', () async {
      answer = (request) async => request.url.path == '/api/auth/refresh/'
          ? reply(goneBody, 401)
          : reply(expiredBody, 401);
      await container.read(taskRepositoryProvider).sync();
      await settle();
      await auth().forgetDeletedAccount();
      expect(container.read(authProvider).deleted, isTrue);
      expect(container.read(authProvider).expired, isFalse);
      expect(await tasks(owner), isEmpty);
      expect(erased, 1);
      expect(sent.skip(1), [
        'GET /api/lists/access/',
        'POST /api/auth/refresh/',
      ]);
    });

    for (final (name, refreshBody) in [
      ('session ended', endedBody),
      ('token_not_valid', expiredBody),
    ]) {
      test(
        'a plain 401 that the refresh answers with $name keeps today’s “sign in again”, and erases nothing',
        () async {
          answer = (request) async => request.url.path == '/api/auth/refresh/'
              ? reply(refreshBody, 401)
              : reply(endedBody, 401);
          await container.read(taskRepositoryProvider).sync();
          await settle();
          final state = container.read(authProvider);
          expect(state.expired, isTrue);
          expect(state.account!.id, 1, reason: 'sign in again, as before');
          expect(state.deleted, isFalse);
          expect(readied, 0);
          expect(erased, 0);
          expect(await tasks(owner), hasLength(1));
        },
      );
    }

    test(
      'several requests learning it at the same time erase once',
      () async {
        final arrived = Completer<void>();
        var waiting = 0;
        answer = (request) async {
          if (++waiting == 3) arrived.complete();
          await arrived.future;
          return reply(goneBody, 401);
        };
        final announced = <int>[];
        final listening = api.accountDeleted.listen(announced.add);
        addTearDown(listening.cancel);
        final failures = await Future.wait([
          for (final future in [
            api.request('GET', 'tasks/', accountId: 1),
            api.request('GET', 'groups/?page=1', accountId: 1),
            api.downloadAttachment('att-1', accountId: 1),
          ])
            future.then<Object?>((_) => null, onError: (Object error) => error),
        ]);
        expect(failures, everyElement(isA<ApiException>()));
        await settle();
        await auth().forgetDeletedAccount();
        expect(announced, [1]);
        expect(readied, 1);
        expect(erased, 1);
        expect(log.where((line) => line == 'reminders signed-out'), hasLength(1));
        expect(await tasks(owner), isEmpty);
        expect(sent.where((line) => line.contains('refresh')), isEmpty);
      },
    );

    test(
      'an answer for an account that is no longer signed in changes nothing for the one that is',
      () async {
        final held = Completer<http.Response>();
        answer = (request) async {
          if (request.url.path == '/api/auth/login/') {
            return reply({...session, 'user': {
              'id': 2,
              'email': 'luis@example.invalid',
              'timezone': 'Europe/Madrid',
            }});
          }
          if (request.url.path == '/api/tasks/') return held.future;
          return reply(session['user']!);
        };
        final stale = api.request('GET', 'tasks/', accountId: 1);
        final refused = expectLater(stale, throwsA(isA<ApiException>()));
        await settle();
        await auth().signIn('luis@example.invalid', 'synthetic-password');
        expect(container.read(authProvider).account!.id, 2);
        held.complete(reply(goneBody, 401));
        await refused;
        await settle();
        expect(container.read(authProvider).account!.id, 2);
        expect(container.read(authProvider).deleted, isFalse);
        expect(api.account!.id, 2);
        expect(readied, 0);
        expect(erased, 0);
        expect(await tasks(owner), hasLength(1));
      },
    );
  });

  group('the preview', () {
    // As decoded JSON: maps of dynamic values.
    Map<String, dynamic> valid() => {
      'personal': <String, dynamic>{
        'tasks': 12,
        'notes': 3,
        'files': 2,
        'projects': 1,
        'groups': 0,
      },
      'kept_in_shared': 4,
      'handovers': [
        <String, dynamic>{
          'kind': 'project',
          'id': 'p-1',
          'name': 'Casa',
          'to': 'Ana',
        },
        <String, dynamic>{
          'kind': 'group',
          'id': 'g-1',
          'name': 'Matemáticas',
          'to': 'Luis',
        },
      ],
      'pro': true,
      'reauth': 'google',
      'plan': 'plan-1',
    };

    test('is read as the server sends it', () {
      final preview = DeletionPreview.parse(valid());
      expect(
        [
          preview.tasks,
          preview.notes,
          preview.files,
          preview.projects,
          preview.groups,
          preview.keptInShared,
        ],
        [12, 3, 2, 1, 0, 4],
      );
      expect(preview.pro, isTrue);
      expect(preview.google, isTrue);
      expect(preview.plan, 'plan-1');
      expect(
        preview.handovers.map((h) => (h.group, h.name, h.to)).toList(),
        [(false, 'Casa', 'Ana'), (true, 'Matemáticas', 'Luis')],
      );
    });

    test('is refused whole when any part is missing or wrong', () {
      final broken = <String, void Function(Map<String, dynamic>)>{
        'no personal counts': (data) => data.remove('personal'),
        'a negative count': (data) => (data['personal'] as Map)['tasks'] = -1,
        'a count that isn’t a number': (data) =>
            (data['personal'] as Map)['files'] = '2',
        'no kept count': (data) => data.remove('kept_in_shared'),
        'no handover list': (data) => data.remove('handovers'),
        'a handover without who receives it': (data) =>
            ((data['handovers'] as List).first as Map).remove('to'),
        'a handover to no one': (data) =>
            ((data['handovers'] as List).first as Map)['to'] = ' ',
        'a handover of something else': (data) =>
            ((data['handovers'] as List).first as Map)['kind'] = 'task',
        'no Pro answer': (data) => data.remove('pro'),
        'an unknown way to confirm': (data) => data['reauth'] = 'sms',
        'no plan': (data) => data.remove('plan'),
        'an empty plan': (data) => data['plan'] = '',
      };
      for (final entry in broken.entries) {
        final data = valid();
        entry.value(data);
        expect(
          () => DeletionPreview.parse(data),
          throwsFormatException,
          reason: entry.key,
        );
      }
      expect(() => DeletionPreview.parse(null), throwsFormatException);
      expect(() => DeletionPreview.parse([]), throwsFormatException);
    });
  });
}
