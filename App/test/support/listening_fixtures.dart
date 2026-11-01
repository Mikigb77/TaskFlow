// The capture sheet's listening states on both speech paths (P266): the app
// on Calendar, a recognizer that can be on-device or not, an audio recorder
// whose levels the test sends, captures kept in memory with their pending
// list, and an account with or without Pro.
import 'dart:async';

import 'package:agenda/main.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

import 'design_fixtures.dart';

/// The phone's recognizer. With [onDevice] false the capability probe isn't
/// usable, so the sheet records and the words are understood online.
class PathSpeech extends NativeSpeech {
  PathSpeech({required this.onDevice, this.log});
  final bool onDevice;
  final List<String>? log;
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  SpeechPermission answer = SpeechPermission.granted;
  int starts = 0;
  int? _run;

  @override
  Future<SpeechCapability> capability({String? language}) async =>
      SpeechCapability(
        onDevice: onDevice,
        language: 'es-ES',
        languageInstalled: onDevice,
      );
  @override
  Stream<SpeechEvent> get events => _events.stream;
  @override
  Future<SpeechPermission> permission() async => answer;
  @override
  Future<void> start(
    int id,
    String language, {
    List<String> hints = const [],
  }) async {
    starts++;
    _run = id;
    log?.add('speech.start');
  }

  void send(String kind, {String? text}) =>
      _events.add(SpeechEvent(_run!, kind, text: text));
  @override
  Future<void> stop(int id) async {
    log?.add('speech.stop');
    if (_run != null) send('ended');
  }

  @override
  Future<void> cancel(int id) async {}
}

/// The app's own recorder: recording from `start` until `stop`, with the
/// levels the test sends through [level].
class LevelRecorder extends Fake implements AudioRecorder {
  LevelRecorder({this.log});
  final List<String>? log;
  final _states = StreamController<RecordState>.broadcast(sync: true);
  final _amplitudes = StreamController<Amplitude>.broadcast();
  int starts = 0;
  int stops = 0;

  /// Runs as the recorder stops, before it returns.
  void Function()? onStop;

  /// One amplitude event, in dBFS: about -60 is a quiet room, -20 speech.
  void level(double dbfs) =>
      _amplitudes.add(Amplitude(current: dbfs, max: dbfs));

  @override
  Stream<RecordState> onStateChanged() => _states.stream;
  @override
  Future<bool> hasPermission({bool request = true}) async => true;
  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    starts++;
    log?.add('recorder.start');
  }

  @override
  Future<bool> isPaused() async => false;
  @override
  Future<bool> isRecording() async => true;
  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) => _amplitudes.stream;
  @override
  Future<String?> stop() async {
    stops++;
    log?.add('recorder.stop');
    onStop?.call();
    _states.add(RecordState.stop);
    return '/synthetic/capture.wav';
  }

  @override
  Future<void> dispose() async {
    await _amplitudes.close();
    await _states.close();
  }
}

/// Every capture in memory, by id; the pending list (Calendar's «Sin
/// guardar») is every one not saved or discarded.
class MemoryCaptures extends CaptureStore {
  MemoryCaptures() : super(TaskDatabase());
  final sessions = <String, CaptureSession>{};
  final removedAudio = <String>[];
  var _next = 0;

  List<CaptureSession> get waiting => [
    for (final session in sessions.values)
      if (!session.terminal) session,
  ];

  @override
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
    final session = CaptureSession(
      language: language,
      id: id ?? 'capture-${_next++}',
      ownerKey: ownerKey,
      timezone: timezone,
      capturedAt: (now ?? DateTime.now()).toUtc(),
      audioPath: audio ? '/synthetic/capture.wav' : null,
      text: text,
      kind: kind,
      projectId: projectId,
      source: source,
      day: day,
    );
    return sessions[session.id] = session;
  }

  @override
  Future<void> update(CaptureSession value) async {
    if (sessions[value.id]?.terminal ?? false) {
      throw StateError('This capture is no longer available.');
    }
    sessions[value.id] = value;
  }

  @override
  Future<CaptureSession?> read(String id, String ownerKey) async =>
      sessions[id];
  @override
  Future<List<CaptureSession>> pending(String ownerKey) async => waiting;
  @override
  Future<void> cleanFinished(String ownerKey) async {}
  @override
  Future<String> audioPathForId(String id) async => '/synthetic/capture.wav';
  @override
  Future<String> audioPathFor(CaptureSession session) async =>
      '/synthetic/capture.wav';
  @override
  Future<void> removeAudioFile(String id) async => removedAudio.add(id);
  @override
  Future<void> discard(String id, String ownerKey) async {
    final session = sessions[id];
    if (session != null) sessions[id] = session.copyWith(status: 'discarded');
  }
}

/// The server, out of reach: every request fails as offline, after [hold]
/// when it is set. The assistant (`ai/…`) may instead answer [answer], or
/// fail with [failure].
class UnreachableApi extends OfflineApiClient {
  Completer<void>? hold;
  int requests = 0;
  Map<String, dynamic>? answer;
  Object? failure;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
    bool retry = true,
  }) async {
    if (path.startsWith('ai/')) {
      requests++;
      final gate = hold;
      if (gate != null) await gate.future;
      final error = failure;
      if (error != null) throw error;
      final reply = answer;
      if (reply != null) return reply;
    }
    throw ApiException(0, 'Offline. Retry when connected.');
  }
}

/// The fixture's account with [left] free dictations this month.
class FreeVoiceAuth extends AuthNotifier {
  FreeVoiceAuth(super.api, this.left);
  final int left;
  @override
  Future<void> restore() async {
    final now = DateTime.now().toUtc();
    state = AuthState(
      account: Account.fromJson({
        'id': 1,
        'email': 'design@example.invalid',
        'timezone': 'Europe/Madrid',
        'free_voice': {
          'limit': 10,
          'left': left,
          'resets_at': DateTime.utc(now.year, now.month + 1).toIso8601String(),
        },
      }),
    );
  }
}

/// The app on Calendar, for one capture test.
class ListeningApp {
  ListeningApp._(this.container, this.store, this.api, this.speech, this.log);
  final ProviderContainer container;
  final MemoryCaptures store;
  final UnreachableApi api;
  final PathSpeech speech;

  /// Recognizer and recorder calls, in order.
  final List<String> log;
  final recorders = <LevelRecorder>[];

  /// The recorder of the sheet open last.
  LevelRecorder get recorder => recorders.last;

  /// [online]: the capability probe isn't usable. Without [pro] the account
  /// has [freeLeft] free dictations left.
  static Future<ListeningApp> open(
    WidgetTester tester, {
    required bool online,
    bool pro = true,
    int freeLeft = 5,
    String language = 'es',
    Size size = const Size(360, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final messenger = tester.binding.defaultBinaryMessenger;
    const timezone = MethodChannel('flutter_timezone');
    messenger.setMockMethodCallHandler(timezone, (_) async => 'Europe/Madrid');
    addTearDown(() => messenger.setMockMethodCallHandler(timezone, null));
    final log = <String>[];
    final store = MemoryCaptures();
    final api = UnreachableApi();
    final speech = PathSpeech(onDevice: !online, log: log);
    late final ListeningApp app;
    final container = ProviderContainer(
      overrides: [
        invitationLinkProvider.overrideWith(
          (ref) => InvitationLinks(listen: false),
        ),
        hasProProvider.overrideWithValue(pro),
        billingLoadingProvider.overrideWithValue(false),
        authProvider.overrideWith(
          (ref) =>
              pro ? SignedInFixtureAuth(api) : FreeVoiceAuth(api, freeLeft),
        ),
        attachmentEntriesProvider.overrideWith((ref, taskId) async => []),
        regionalStoreProvider.overrideWithValue(
          MemoryRegionalStore(
            RegionalPreferences(
              language: language,
              clock: ClockFormat.twentyFour,
              weekStart: 1,
            ),
          ),
        ),
        taskListsProvider.overrideWith((ref) async => []),
        apiClientProvider.overrideWithValue(api),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => DesignTaskNotifier()),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        captureStoreProvider.overrideWithValue(store),
        nativeSpeechProvider.overrideWithValue(speech),
        captureRecorderFactoryProvider.overrideWithValue(() {
          final recorder = LevelRecorder(log: log);
          app.recorders.add(recorder);
          return recorder;
        }),
      ],
    );
    app = ListeningApp._(container, store, api, speech, log);
    addTearDown(() {
      container.dispose();
      api.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    return app;
  }
}
