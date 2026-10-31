import 'dart:async';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

/// The phone's side of the capture sheet when a test opens it on a result:
/// no recognizer to wait for and no microphone.
List<Override> captureSheetOverrides() => [
  nativeSpeechProvider.overrideWithValue(QuietSpeech()),
  captureRecorderFactoryProvider.overrideWithValue(SilentRecorder.new),
];

/// A phone without on-device recognition, answering at once.
class QuietSpeech extends NativeSpeech {
  @override
  Future<SpeechCapability> capability({String? language}) async =>
      const SpeechCapability();
}

/// A phone whose on-device recognizer is ready and allowed: it listens until
/// it is stopped, and hears nothing.
class ListeningSpeech extends NativeSpeech {
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  int? _run;
  @override
  Future<SpeechCapability> capability({String? language}) async =>
      const SpeechCapability(
        onDevice: true,
        language: 'es-ES',
        languageInstalled: true,
      );
  @override
  Stream<SpeechEvent> get events => _events.stream;
  @override
  Future<SpeechPermission> permission() async => SpeechPermission.granted;
  @override
  Future<void> start(
    int id,
    String language, {
    List<String> hints = const [],
  }) async => _run = id;
  @override
  Future<void> stop(int id) async {
    if (_run != null) _events.add(SpeechEvent(_run!, 'ended'));
  }

  @override
  Future<void> cancel(int id) async {}
}

/// The audio recorder stands by unused.
class SilentRecorder extends Fake implements AudioRecorder {
  final _states = StreamController<RecordState>.broadcast();
  @override
  Stream<RecordState> onStateChanged() => _states.stream;
  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      const Stream.empty();
  @override
  Future<bool> hasPermission({bool request = true}) async => true;
  @override
  Future<bool> isRecording() async => false;
  @override
  Future<bool> isPaused() async => false;
  @override
  Future<String?> stop() async => null;
  @override
  Future<void> dispose() => _states.close();
}

/// Opens capture with the button labelled [button] on the screen in front and
/// types [words]: without Pro the sheet starts typing, with Pro `Escribir`
/// comes first. Then `Listo`, which shows the result in the sheet.
Future<void> typeCapture(
  WidgetTester tester,
  String button,
  String words,
) async {
  final messenger = tester.binding.defaultBinaryMessenger;
  const timezone = MethodChannel('flutter_timezone');
  messenger.setMockMethodCallHandler(timezone, (_) async => 'Europe/Madrid');
  addTearDown(() => messenger.setMockMethodCallHandler(timezone, null));
  await tester.tap(find.text(button).hitTestable());
  await tester.pumpAndSettle();
  final keyboard = find.byIcon(Icons.keyboard_outlined);
  if (keyboard.evaluate().isNotEmpty) {
    await tester.tap(keyboard);
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byKey(const ValueKey('capture-words')), words);
  await tester.pumpAndSettle();
  await tester.tap(
    find
        .descendant(
          of: find.byType(VoiceTaskScreen),
          matching: find.byType(FilledButton),
        )
        .last,
  );
  await tester.pumpAndSettle();
}

/// The result's `Añadir…` button: saves and closes the sheet.
Future<void> saveCapture(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('save-drafts')));
  await tester.pumpAndSettle();
}

/// Opens the capture sheet straight on the result of [captureId], the way
/// resuming a capture does. The capture store must be able to read it.
Future<void> openCaptureResult(WidgetTester tester, String captureId) async {
  final messenger = tester.binding.defaultBinaryMessenger;
  const timezone = MethodChannel('flutter_timezone');
  messenger.setMockMethodCallHandler(timezone, (_) async => 'Europe/Madrid');
  addTearDown(() => messenger.setMockMethodCallHandler(timezone, null));
  unawaited(
    showCaptureSheet(
      tester.element(find.byType(Scaffold).first),
      captureId: captureId,
      startListening: false,
    ),
  );
  await tester.pumpAndSettle();
}

/// A capture store in memory. Saving marks the drafts saved and adds them to
/// [tasks]' task list, the way the real store writes them to its table, and
/// Undo takes them out again.
class MemoryCaptures extends CaptureStore {
  MemoryCaptures() : super(TaskDatabase());
  CaptureSession? current;
  ProviderContainer? tasks;

  /// A new capture is kept in memory, as [current].
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
  }) async => current = CaptureSession(
    language: language,
    id: 'memory-capture',
    ownerKey: ownerKey,
    timezone: timezone,
    capturedAt: (now ?? DateTime.now()).toUtc(),
    text: text,
    kind: kind,
    projectId: projectId,
    source: source,
    day: day,
  );
  @override
  Future<void> discard(String id, String ownerKey) async {
    if (current?.id == id) current = current!.copyWith(status: 'discarded');
  }

  @override
  Future<void> update(CaptureSession value) async => current = value;
  @override
  Future<CaptureSession?> read(String id, String ownerKey) async =>
      current?.id == id ? current : null;
  @override
  Future<List<CaptureSession>> pending(String ownerKey) async => [];
  @override
  Future<void> cleanFinished(String ownerKey) async {}
  @override
  Future<CaptureSession> saveReady(
    String id,
    String ownerKey,
    Set<String> draftIds,
  ) async {
    // Saved as the real store saves them: without a plan that can't apply.
    final drafts = [
      for (final draft in current!.drafts)
        draftIds.contains(draft.id)
            ? draft.copyWith(task: CaptureStore.withoutStalePlan(draft.task))
            : draft,
    ];
    final known = {
      for (final task in tasks?.read(taskProvider).valueOrNull ?? <Task>[])
        task.id,
    };
    await tasks?.read(taskProvider.notifier).addTasks([
      for (final draft in drafts)
        if (draftIds.contains(draft.id)) draft.task,
    ]);
    // The ids the task list gave them, in the order they were added.
    final added =
        (tasks?.read(taskProvider).valueOrNull ?? <Task>[])
            .map((task) => task.id)
            .whereType<int>()
            .where((id) => !known.contains(id))
            .toList()
          ..sort();
    var next = 0;
    int saved() => next < added.length ? added[next++] : 300 + next++;
    return current = current!.copyWith(
      status: 'saved',
      drafts: [
        for (final draft in drafts)
          draftIds.contains(draft.id)
              ? draft.copyWith(savedTaskId: saved())
              : draft,
      ],
    );
  }

  @override
  Future<CaptureSession?> undoSave(
    CaptureSession before,
    Map<String, int> savedIds,
  ) async {
    for (final id in savedIds.values) {
      await tasks?.read(taskProvider.notifier).deleteTask(id);
    }
    return current = before;
  }
}
