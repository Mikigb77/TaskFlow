// Entitlement is a fixture here; real paid access is covered by projects_flow_test.
import 'package:agenda/providers/subscription_provider.dart';
// Real Android capability query + SQLite/UI retention with synthetic recognizer
// events. This does not measure recognition accuracy or record a microphone.
import 'dart:async';
import 'package:agenda/main.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/design_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android speech capability and retained partial transcript', (
    tester,
  ) async {
    final native = NativeSpeech();
    for (final language in ['en-US', 'es-ES']) {
      final capability = await native.capability(language: language);
      debugPrint(
        'Speech capability: $language service=${capability.onDevice} installed=${capability.languageInstalled}',
      );
      expect(capability.language, language);
    }
    final speech = _SpeechFixture();
    const owner = 'native-speech-integration-fixture';
    final container = ProviderContainer(
      overrides: [
        hasProProvider.overrideWithValue(true),
        authProvider.overrideWith(
          (ref) => SignedInFixtureAuth(ref.read(apiClientProvider)),
        ),
        nativeSpeechProvider.overrideWithValue(speech),
        captureOwnerProvider.overrideWithValue(owner),
        apiClientProvider.overrideWith((ref) => OfflineApiClient()),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => DesignTaskNotifier()),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      ],
    );
    final store = container.read(captureStoreProvider);
    addTearDown(() async {
      for (final session in await store.pending(owner)) {
        await store.discard(session.id, owner);
      }
      container.read(apiClientProvider).close();
      container.dispose();
      await speech.controller.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/voiceTask');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Record tasks'));
    await _wait(tester, () async => speech.run != null);
    speech.emit('partial', 'Call the doctor Friday at five');
    await _wait(
      tester,
      () async => (await store.pending(
        owner,
      )).any((s) => s.text == 'Call the doctor Friday at five'),
    );
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('speech-live-transcript');
    speech.emit('ended', null);
    await _wait(
      tester,
      () async =>
          (await store.pending(owner)).any((s) => s.status == 'editing'),
    );
    final retained = (await store.pending(owner)).single;
    expect(retained.audioPath, isNull);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => VoiceTaskScreen(captureId: retained.id),
          ),
        );
    await _wait(
      tester,
      () async =>
          find.text('Call the doctor Friday at five').evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    expect(
      (await store.read(retained.id, owner))!.capturedAt,
      retained.capturedAt,
    );
    expect(await store.read(retained.id, 'another-owner'), isNull);
    await binding.takeScreenshot('speech-retained-transcript');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _wait(WidgetTester tester, Future<bool> Function() ready) async {
  final clock = Stopwatch()..start();
  while (!await ready()) {
    if (clock.elapsed > const Duration(seconds: 15)) {
      fail('Speech capture did not reach the expected state.');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

class _SpeechFixture extends NativeSpeech {
  final controller = StreamController<SpeechEvent>.broadcast();
  int? run;
  @override
  Future<SpeechCapability> capability({String? language}) async =>
      const SpeechCapability(
        onDevice: true,
        language: 'en-US',
        languageInstalled: true,
      );
  @override
  Stream<SpeechEvent> get events => controller.stream;
  @override
  Future<SpeechPermission> permission() async => SpeechPermission.granted;
  @override
  Future<void> start(int id, String language) async {
    run = id;
  }

  void emit(String kind, String? text) =>
      controller.add(SpeechEvent(run!, kind, text: text));
  @override
  Future<void> stop(int id) async {
    emit('ended', null);
  }

  @override
  Future<void> cancel(int id) async {}
}
