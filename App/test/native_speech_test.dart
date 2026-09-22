import 'dart:async';
import 'package:agenda/main.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'support/design_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter_timezone'), (_) async => 'UTC');
  });

  for (final interruption in [
    'pause',
    'stop',
    'during-start',
    'stop-during-start'
  ]) {
    testWidgets(
        'audio $interruption keeps the foreground capture without sending',
        (tester) async {
      final speech = _Speech()..installed = false;
      final recorder = _Recorder()
        ..pauseDuringStart = interruption == 'during-start'
        ..stopDuringStart = interruption == 'stop-during-start';
      final store = _Captures();
      final api = _OfflineExtraction();
      await _open(tester, speech, store, api, recorder: recorder);
      await tester.tap(find.byTooltip('Record tasks'));
      await tester.pumpAndSettle();
      final id = store.session!.id;
      final capturedAt = store.session!.capturedAt;
      if (!interruption.contains('during-start')) {
        expect(store.session!.status, 'recording');
        await tester.runAsync(() async {
          recorder.states.add(
              interruption == 'pause' ? RecordState.pause : RecordState.stop);
          // Stream cancellation may complete outside the fake frame clock.
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pumpAndSettle();
      }
      expect(tester.binding.lifecycleState, AppLifecycleState.resumed);
      expect(store.session!.status, 'editing');
      expect(store.session!.id, id);
      expect(store.session!.capturedAt, capturedAt);
      expect(store.session!.audioPath, '/synthetic/capture.wav');
      expect(recorder.stops, 1);
      expect(api.requests, 0);
      expect(find.textContaining('Listening ·'), findsNothing);
      final retry = find.widgetWithText(FilledButton, 'Try this recording');
      await tester.scrollUntilVisible(retry, 180,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(retry).onPressed, isNotNull);
      // Late platform events and the former time limit cannot send or reopen it.
      recorder.states.add(RecordState.record);
      recorder.states.add(RecordState.pause);
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(store.session!.status, 'editing');
      expect(recorder.stops, 1);
      expect(api.requests, 0);
      expect(tester.takeException(), isNull);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(recorder.disposed, isTrue);
    });
  }
  test('capability handles absent bridges and unsupported languages', () async {
    const channel = MethodChannel('taskflow/speech-test');
    final speech = NativeSpeech(channel: channel);
    expect((await speech.capability()).usable, isFalse);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            channel,
            (_) async => {
                  'onDevice': true,
                  'language': 'es-ES',
                  'languageInstalled': false
                });
    expect((await speech.capability(language: 'es-ES')).usable, isFalse);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets(
      'partial words survive interruption, stale events and failed offline extraction',
      (tester) async {
    final speech = _Speech();
    final store = _Captures();
    final api = _OfflineExtraction();
    await _open(tester, speech, store, api);
    await tester.tap(find.byTooltip('Record tasks'));
    await tester.pumpAndSettle();
    expect(speech.run, isNotNull);
    speech.emit('partial', text: 'Call the doctor Friday at five');
    await tester.pumpAndSettle();
    expect(store.session!.text, 'Call the doctor Friday at five');
    final originalTime = store.session!.capturedAt;
    speech.controller
        .add(SpeechEvent(speech.run! - 1, 'partial', text: 'Stale words'));
    await tester.pumpAndSettle();
    expect(store.session!.text, 'Call the doctor Friday at five');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(store.session!.status, 'editing');
    expect(speech.cancelled, isTrue);
    expect(api.requests, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final id = store.session!.id;
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).push(
        MaterialPageRoute<void>(
            builder: (_) => VoiceTaskScreen(captureId: id)));
    await tester.pumpAndSettle();
    expect(find.text('Call the doctor Friday at five'), findsOneWidget);
    final review = find.text('Review tasks from text');
    await tester.scrollUntilVisible(review, 180,
        scrollable: find
            .descendant(
                of: find.byType(VoiceTaskScreen),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(review);
    await tester.pumpAndSettle();
    expect(store.session!.status, 'failed');
    expect(store.session!.text, 'Call the doctor Friday at five');
    expect(store.session!.audioPath, isNull);
    expect(store.session!.capturedAt, originalTime);
    expect(api.requests, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'automatic endpointing retains final text without sending it; another utterance appends',
      (tester) async {
    final speech = _Speech();
    final store = _Captures();
    final api = _OfflineExtraction();
    await _open(tester, speech, store, api);
    await tester.tap(find.byTooltip('Record tasks'));
    await tester.pumpAndSettle();
    speech.emit('partial', text: 'Buy');
    speech.emit('final', text: 'Buy coffee');
    await tester.pumpAndSettle();
    expect(store.session!.text, 'Buy coffee');
    expect(api.requests, 0);
    await tester.tap(find.byTooltip('Record tasks'));
    await tester.pumpAndSettle();
    speech.emit('final', text: 'Pay the bill tomorrow');
    await tester.pumpAndSettle();
    expect(store.session!.text, 'Buy coffee Pay the bill tomorrow');
    expect(api.requests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'microphone denial leaves a working typed capture and no speech session',
      (tester) async {
    final speech = _Speech()..allowed = false;
    final store = _Captures();
    await _open(tester, speech, store, _OfflineExtraction());
    await tester.tap(find.byTooltip('Record tasks'));
    await tester.pumpAndSettle();
    expect(speech.run, isNull);
    await tester.enterText(find.byType(TextField).first, 'Remember the keys');
    await tester.pumpAndSettle();
    expect(store.session!.text, 'Remember the keys');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'hold to talk releases the mic and retains input when extraction is offline',
      (tester) async {
    final speech = _Speech();
    final store = _Captures();
    final api = _OfflineExtraction();
    await _open(tester, speech, store, api);
    await tester.tap(find.text('Speech options'));
    await tester.pumpAndSettle();
    final hold = find.byType(SwitchListTile);
    await tester.ensureVisible(hold);
    await tester.pumpAndSettle();
    await tester.tap(hold);
    await tester.pumpAndSettle();
    final mic = find.byKey(const ValueKey('capture-mic'));
    await tester.scrollUntilVisible(mic, -180,
        scrollable: find
            .descendant(
                of: find.byType(VoiceTaskScreen),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(mic));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(speech.run, isNotNull);
    speech.emit('partial', text: 'Bring the keys');
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(speech.cancelled, isTrue);
    expect(store.session!.text, 'Bring the keys');
    expect(api.requests, 1);
    expect(store.session!.status, 'failed');
  });
}

Future<void> _open(WidgetTester tester, _Speech speech, _Captures store,
    _OfflineExtraction api,
    {_Recorder? recorder}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  final container = ProviderContainer(overrides: [
    if (recorder != null)
      captureRecorderFactoryProvider.overrideWithValue(() => recorder),
    nativeSpeechProvider.overrideWithValue(speech),
    captureStoreProvider.overrideWithValue(store),
    pendingCapturesProvider.overrideWith((ref) async => []),
    apiClientProvider.overrideWithValue(api),
    taskRepositoryProvider.overrideWithValue(MemoryTasks()),
    taskProvider.overrideWith((ref) => DesignTaskNotifier()),
    themeStoreProvider.overrideWithValue(MemoryThemeStore()),
  ]);
  addTearDown(() {
    container.dispose();
    api.close();
  });
  await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()));
  await tester.pumpAndSettle();
  tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/voiceTask');
  await tester.pumpAndSettle();
}

class _Speech extends NativeSpeech {
  final controller = StreamController<SpeechEvent>.broadcast(sync: true);
  int? run;
  bool allowed = true;
  bool installed = true;
  bool cancelled = false;
  String? text;
  @override
  Future<SpeechCapability> capability({String? language}) async =>
      SpeechCapability(
          onDevice: true, language: 'en-US', languageInstalled: installed);
  @override
  Stream<SpeechEvent> get events => controller.stream;
  @override
  Future<bool> permission() async => allowed;
  @override
  Future<void> start(int id, String language) async {
    run = id;
    text = null;
    cancelled = false;
  }

  void emit(String kind, {String? text}) {
    this.text = text ?? this.text;
    controller.add(SpeechEvent(run!, kind, text: text));
  }

  @override
  Future<void> stop(int id) async {
    emit('final', text: text);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled = true;
  }
}

class _Captures extends CaptureStore {
  _Captures() : super(TaskDatabase());
  CaptureSession? session;
  @override
  Future<CaptureSession> create(String ownerKey, String timezone,
          {String text = '',
          DateTime? now,
          bool audio = false,
          String kind = 'task'}) async =>
      session = CaptureSession(
          id: 'test-capture',
          kind: kind,
          ownerKey: ownerKey,
          timezone: timezone,
          capturedAt: (now ?? DateTime.now()).toUtc(),
          audioPath: audio ? '/synthetic/capture.wav' : null,
          text: text);
  @override
  Future<void> update(CaptureSession value) async {
    session = value;
  }

  @override
  Future<CaptureSession?> read(String id, String ownerKey) async =>
      session?.id == id && session?.ownerKey == ownerKey ? session : null;
  @override
  Future<void> cleanFinished(String ownerKey) async {}
}

class _OfflineExtraction extends OfflineApiClient {
  int requests = 0;
  @override
  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? data,
      String? audioPath,
      bool authenticated = true,
      int? accountId,
      bool retry = true}) async {
    requests++;
    throw ApiException(0, 'Offline. Retry when connected.');
  }
}

class _Recorder extends Fake implements AudioRecorder {
  final states = StreamController<RecordState>.broadcast(sync: true);
  final amplitudes = StreamController<Amplitude>.broadcast();
  bool pauseDuringStart = false;
  bool stopDuringStart = false;
  bool disposed = false;
  int stops = 0;
  @override
  Stream<RecordState> onStateChanged() => states.stream;
  @override
  Future<bool> hasPermission({bool request = true}) async => true;
  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    if (pauseDuringStart) states.add(RecordState.pause);
    if (stopDuringStart) states.add(RecordState.stop);
  }

  @override
  Future<bool> isPaused() async => pauseDuringStart;
  @override
  Future<bool> isRecording() async => !stopDuringStart;
  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) => amplitudes.stream;
  @override
  Future<String?> stop() async {
    stops++;
    states.add(RecordState.stop);
    return '/synthetic/capture.wav';
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await amplitudes.close();
    await states.close();
  }
}
