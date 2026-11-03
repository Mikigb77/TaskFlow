// UX loop 2026-10-13-app, batch b7 round 3 · P97 (UX-511): an account update
// that changes only the file space used or the free dictations left must not
// rebuild the task repository, reset the task screens or start another sync.
// Sign-in, sign-out and a switch to another account still do.
//
// These tests use the real taskRepositoryProvider, taskProvider and
// captureOwnerProvider over a real (temporary, FFI) task database, and a fake
// server.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agenda/providers/no_retry.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/repositories/cloud_task_repository.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/design_fixtures.dart';

const _megabyte = 1024 * 1024;
const _server = 'http://account.test';

Map<String, dynamic> _usage(int usedMb) =>
    {'used_bytes': usedMb * _megabyte, 'limit_bytes': 100 * _megabyte};

Map<String, dynamic> _freeVoice(int left) => {
      'limit': 10,
      'left': left,
      'resets_at': DateTime.now()
          .toUtc()
          .add(const Duration(days: 20))
          .toIso8601String(),
    };

Map<String, dynamic> _user(int id, {int usedMb = 78, int voiceLeft = 6}) => {
      'id': id,
      'email': 'account$id@example.invalid',
      'timezone': 'UTC',
      'storage': _usage(usedMb),
      'free_voice': _freeVoice(voiceLeft),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late _Api api;
  // The app's files live under the temporary directory, as the phone's
  // application-support folder.
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('taskflow-account-');
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(directory.path);
    messenger.setMockMethodCallHandler(
        pathProvider, (_) async => p.join(directory.path, 'support'));
    // A free account saved on the phone at 78 of 100 MB.
    FlutterSecureStorage.setMockInitialValues({
      'taskflow.session': jsonEncode({
        'access': 'fixture-access',
        'refresh': 'fixture-refresh',
        'user': _user(1),
      }),
    });
    api = _Api();
    await api.restore();
    expect(api.account!.id, 1);
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(pathProvider, null);
    api.close();
    await TaskDatabase().close();
    expect(p.isWithin(Directory.systemTemp.path, directory.path), isTrue);
    await directory.delete(recursive: true);
  });

  ProviderContainer container({List<Override> extra = const []}) {
    final container = ProviderContainer(retry: noRetry, overrides: [
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => _Auth(api)),
      ...extra,
    ]);
    addTearDown(container.dispose);
    return container;
  }

  /// Real time passes until [done], for the database and the fake server.
  Future<void> until(bool Function() done, {String? reason}) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(done(), isTrue, reason: reason);
  }

  Future<void> settleUpdate() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  for (final (field, update) in [
    ('storage', (_Api api) => api.rememberStorage(_usage(82), accountId: 1)),
    (
      'free_voice',
      (_Api api) => api.rememberFreeVoice(_freeVoice(2), accountId: 1)
    ),
  ]) {
    test(
        'UX-511: an account update that changes only $field keeps the same task repository; the task list never goes back to loading and no second sync runs',
        () async {
      final c = container();
      final repository = c.read(taskRepositoryProvider);
      expect(repository, isA<CloudTaskRepository>());
      final states = <AsyncValue<List<Task>>>[];
      c.listen(taskProvider, (_, next) => states.add(next),
          fireImmediately: true);
      final notifier = c.read(taskProvider.notifier);
      // The first load, with its one sync.
      await until(() => api.syncs == 1 && c.read(taskProvider).hasValue,
          reason: 'the first sync finishes');
      await settleUpdate();
      expect(repository.syncError, isNull, reason: 'the fake server answers');
      final before = c.read(authProvider).account!;
      states.clear();

      await update(api);
      await settleUpdate();

      final after = c.read(authProvider).account!;
      expect(identical(after, before), isFalse,
          reason: 'the account update reached the app');
      if (field == 'storage') {
        expect(after.storage!.usedBytes, 82 * _megabyte);
      } else {
        expect(after.freeVoice!.left, 2);
      }
      expect(c.read(taskRepositoryProvider), same(repository));
      expect(c.read(taskProvider.notifier), same(notifier));
      expect(states.where((state) => state.isLoading), isEmpty,
          reason: 'the task list never goes back to loading');
      expect(c.read(taskProvider).hasValue, isTrue);
      expect(api.syncs, 1, reason: 'no second sync');
    });
  }

  test(
      'UX-511: signing out and signing in as another account still gives a new repository whose owner key names the new account',
      () async {
    final c = container();
    final first = c.read(taskRepositoryProvider);
    expect(first.ownerKey, '$_server/users/1');
    expect(c.read(captureOwnerProvider), '$_server/users/1');
    c.listen(taskProvider, (_, _) {}, fireImmediately: true);
    await until(() => api.syncs == 1, reason: 'the first sync finishes');

    await c.read(authProvider.notifier).signOut();
    expect(c.read(authProvider).account, isNull);
    final signedOut = c.read(taskRepositoryProvider);
    expect(signedOut, isNot(same(first)));
    expect(signedOut, isNot(isA<CloudTaskRepository>()));
    expect(signedOut, isA<TaskRepository>());
    expect(signedOut.ownerKey, 'local');
    expect(c.read(captureOwnerProvider), 'local');

    api.signInAs = 2;
    await c
        .read(authProvider.notifier)
        .signIn('account2@example.invalid', 'a long fixture password');
    expect(c.read(authProvider).account!.id, 2);
    final second = c.read(taskRepositoryProvider);
    expect(second, isA<CloudTaskRepository>());
    expect(second, isNot(same(first)));
    expect(second, isNot(same(signedOut)));
    expect(second.ownerKey, '$_server/users/2');
    expect(c.read(captureOwnerProvider), '$_server/users/2');
    await until(() => api.syncs == 2,
        reason: 'the new account’s tasks load and sync');
    await settleUpdate();
  });

  for (final (field, update) in [
    ('storage', (_Api api) => api.rememberStorage(_usage(82), accountId: 1)),
    (
      'free_voice',
      (_Api api) => api.rememberFreeVoice(_freeVoice(2), accountId: 1)
    ),
  ]) {
    test(
        'UX-511: captureOwnerProvider keeps its value and pendingCapturesProvider does not reload after an account update that changes only $field',
        () async {
      final captures = _CountingCaptures();
      final c = container(
          extra: [captureStoreProvider.overrideWithValue(captures)]);
      final owner = c.read(captureOwnerProvider);
      expect(owner, '$_server/users/1');
      var ownerChanges = 0;
      c.listen(captureOwnerProvider, (_, _) => ownerChanges++);
      c.listen(pendingCapturesProvider, (_, _) {});
      await c.read(pendingCapturesProvider.future);
      expect(captures.reads, [owner]);
      final before = c.read(authProvider).account;

      await update(api);
      await settleUpdate();

      expect(identical(c.read(authProvider).account, before), isFalse,
          reason: 'the account update reached the app');
      expect(c.read(captureOwnerProvider), owner);
      expect(ownerChanges, 0);
      await c.read(pendingCapturesProvider.future);
      expect(captures.reads, [owner],
          reason: 'the pending captures are not read again');
    });
  }

  final en = lookupAppLocalizations(const Locale('en'));

  /// Task details of a long task with one queued file, for a free account at
  /// 78 of 100 MB, in English, over the real task providers, scrolled down to
  /// the files section. The first sync holds at the upload.
  Future<_Scrolled> openScrolledToFiles(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const owner = '$_server/users/1';
    final source = File(p.join(directory.path, 'scan.pdf'));
    final id = (await tester.runAsync(() async {
      await source.writeAsBytes([7, 8, 9]);
      final database = TaskDatabase();
      final id = await database.insertTask(
          Task(
            title: 'Doctor',
            priority: 3,
            notes: List.filled(
                    40, 'Bring the blood test results and the referral.')
                .join('\n'),
            filePaths: [source.path],
          ),
          ownerKey: owner);
      await (await database.database).update(
          'tasks', {'remote_version': 1, 'sync_pending': 0},
          where: 'id = ?', whereArgs: [id]);
      return id;
    }))!;
    api.me = _usage(82);
    api.uploadWait = Completer<void>();

    final c = container(extra: [
      hasProProvider.overrideWithValue(false),
      billingLoadingProvider.overrideWithValue(false),
      regionalStoreProvider.overrideWithValue(MemoryRegionalStore(
          const RegionalPreferences(
              language: 'en', clock: ClockFormat.twentyFour, weekStart: 1))),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
    ]);
    final states = <AsyncValue<List<Task>>>[];
    c.listen(taskProvider, (_, next) => states.add(next),
        fireImmediately: true);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: TaskDetailScreen(taskId: id))));

    Future<void> realTime(bool Function() done) async {
      for (var i = 0; i < 100 && !done(); i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
    }

    // The first sync holds at the upload; the local tasks already show.
    await realTime(() => api.uploadStarted.isCompleted);
    expect(api.uploadStarted.isCompleted, isTrue);
    expect(find.text('Doctor'), findsOneWidget);
    expect(find.text(en.storageUsage(78, 100)), findsNothing,
        reason: '78% is under the line’s 80%');

    // The screen's own list, the outermost one.
    final scrollable = find
        .descendant(
            of: find.byType(SingleChildScrollView).first,
            matching: find.byType(Scrollable))
        .first;
    expect(find.descendant(of: scrollable, matching: find.text('Doctor')),
        findsOneWidget);
    // Down to the files section, at the end of the long task; its files
    // load from the database once it is built.
    await tester.drag(scrollable, const Offset(0, -6000));
    await tester.pump();
    await realTime(() => find.text('scan.pdf').evaluate().isNotEmpty);
    await tester.scrollUntilVisible(find.text('scan.pdf'), 100,
        scrollable: scrollable);
    await tester.pump();
    expect(find.text('scan.pdf').hitTestable(), findsOneWidget);
    final offset = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(offset, greaterThan(0), reason: 'scrolled down to the files');
    return _Scrolled(c, scrollable, offset, states, states.length);
  }

  /// The held upload finishes and auth/me/ answers 82 MB; [frame] runs after
  /// every frame until the sync is over and the usage line shows.
  Future<void> finishUpload(
      WidgetTester tester, void Function(String when) frame) async {
    api.uploadWait!.complete();
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      frame('during the sync (frame $i)');
      if (api.meRequests == 1 &&
          find.text(en.storageUsage(82, 100)).evaluate().isNotEmpty &&
          i > 20) {
        break;
      }
    }
    await tester.pump(const Duration(milliseconds: 300));
    frame('after the sync');
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
  }

  testWidgets(
      'UX-511: after an upload, Task details keeps its app bar — no spinner replaces it, the task list never reloads, no second sync — and shows Files: 82 of 100 MB used',
      (tester) async {
    final screen = await openScrolledToFiles(tester);
    final repository = screen.container.read(taskRepositoryProvider);
    await finishUpload(tester, (when) {
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'no spinner replaces the screen $when');
      expect(find.byType(CustomAppBar), findsOneWidget,
          reason: 'the app bar stays $when');
      expect(find.text(en.taskScreenTitle), findsOneWidget, reason: when);
    });
    final c = screen.container;
    expect(api.meRequests, 1);
    expect(c.read(authProvider).account!.storage!.usedBytes, 82 * _megabyte);
    expect(c.read(taskRepositoryProvider), same(repository));
    expect(find.text('Files: 82 of 100 MB used'), findsOneWidget);
    expect(find.text(en.storageUsage(82, 100)).hitTestable(), findsOneWidget,
        reason: 'the usage line shows where the user is');
    expect(
        screen.states.skip(screen.loaded).where((state) => state.isLoading),
        isEmpty,
        reason: 'the task list never goes back to loading');
    expect(api.syncs, 1, reason: 'no second sync after the account update');
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets(
      'UX-511: after an upload, Task details stays where the user scrolled — the scroll offset is unchanged and the file stays on screen',
      (tester) async {
    final screen = await openScrolledToFiles(tester);
    await finishUpload(tester, (when) {
      // Unchanged; or, where the file's card got shorter under the end of
      // the page (one button fewer), resting at the new end.
      final position =
          tester.state<ScrollableState>(screen.scrollable).position;
      expect(
          position.pixels == screen.offset ||
              (position.pixels == position.maxScrollExtent &&
                  position.pixels > screen.offset - 48),
          isTrue,
          reason: 'the scroll offset is unchanged $when '
              '(${position.pixels}, was ${screen.offset})');
      expect(find.text('scan.pdf'), findsOneWidget,
          reason: 'the file stays on screen $when');
    });
    expect(find.text(en.storageUsage(82, 100)).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}

class _Scrolled {
  _Scrolled(
      this.container, this.scrollable, this.offset, this.states, this.loaded);
  final ProviderContainer container;
  final Finder scrollable;
  final double offset;

  /// Every state of the task list, and how many there were once scrolled.
  final List<AsyncValue<List<Task>>> states;
  final int loaded;
}

/// The account restored from the session saved on the phone.
class _Auth extends AuthNotifier {
  _Auth(super.api);
  @override
  Future<void> restore() async {
    if (mounted) state = AuthState(account: api.account);
  }
}

/// Counts every read of the pending captures.
class _CountingCaptures extends CaptureStore {
  _CountingCaptures() : super(TaskDatabase());
  final reads = <String>[];
  @override
  Future<List<CaptureSession>> pending(String ownerKey) async {
    reads.add(ownerKey);
    return [];
  }
}

/// The server: no lists, no remote tasks, the account's files. Every task
/// sync asks for the first page of tasks once, so [syncs] counts them.
class _Api extends ApiClient {
  _Api() : super(url: _server);

  int syncs = 0;
  int meRequests = 0;
  Map<String, dynamic>? me;
  int signInAs = 1;
  final records = <String, Map<String, dynamic>>{};
  Completer<void>? uploadWait;
  final uploadStarted = Completer<void>();

  @override
  Future<Map<String, dynamic>> uploadAttachment(
      {required String id,
      required String taskId,
      required String name,
      required String filePath,
      required int accountId}) async {
    final bytes = await File(filePath).readAsBytes();
    records[id] = {
      'id': id,
      'task_id': taskId,
      'name': name,
      'size': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
      'is_deleted': false,
    };
    if (!uploadStarted.isCompleted) uploadStarted.complete();
    if (uploadWait != null) await uploadWait!.future;
    return records[id]!;
  }

  @override
  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? data,
      String? audioPath,
      bool authenticated = true,
      int? accountId}) async {
    if (method == 'GET' && path == 'auth/me/') {
      meRequests++;
      return {
        ..._user(accountId ?? 1),
        if (me != null) 'storage': me,
      };
    }
    if (method == 'POST' && path == 'auth/logout/') return {};
    if (method == 'POST' && path == 'auth/login/') {
      return {
        'access': 'fixture-access-$signInAs',
        'refresh': 'fixture-refresh-$signInAs',
        'user': _user(signInAs),
      };
    }
    if (method == 'GET' && path == 'lists/access/') return {'lists': []};
    if (method == 'GET' && path.startsWith('tasks/?')) {
      if (path.endsWith('page=1')) syncs++;
      return {'results': [], 'next': null};
    }
    if (method == 'GET' && path.startsWith('attachments/?')) {
      return {'results': records.values.toList(), 'next': null};
    }
    throw StateError('Unexpected request $method $path');
  }
}
