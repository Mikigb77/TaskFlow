import 'package:agenda/providers/subscription_provider.dart';
import 'dart:async';
import 'package:agenda/main.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/services/capture_problem.dart';
import 'package:agenda/l10n/capture_messages.dart';
import 'package:agenda/l10n/generated/app_localizations_en.dart';
import 'package:agenda/l10n/generated/app_localizations_es.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm, Database;
import 'support/design_fixtures.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          (_) async => 'UTC',
        );
  });

  test(
    'capture failures translate recognized failures and hide unknown details',
    () {
      final en = AppLocalizationsEn();
      final es = AppLocalizationsEs();
      final problem = CaptureProblem.from(
        ApiException(503, 'Service unavailable'),
      );
      expect(captureProblemText(en, problem), en.captureUnavailable);
      expect(captureProblemText(es, problem), es.captureUnavailable);
      expect(
        CaptureProblem.from(
          ApiException(
            0,
            'The server took too long to respond. Your local tasks are safe.',
          ),
        ),
        CaptureProblem.timeout,
      );
      expect(
        captureProblemText(
          es,
          'Bad state: No tasks were found. Your capture is kept.',
        ),
        es.captureNoTasks,
      );
      final custom = ApiException(
        400,
        'Original server detail: "Trabajo de José"',
      );
      expect(
        captureProblemText(es, CaptureProblem.from(custom)),
        es.captureFailed,
      );
      expect(
        CaptureProblem.from(PlatformException(code: 'permission')),
        CaptureProblem.microphone,
      );
    },
  );

  testWidgets(
    'capture error changes language without changing retained words',
    (tester) async {
      final store = _Captures();
      final api = _OfflineExtraction();
      final container = await _open(
        tester,
        _Speech(),
        store,
        api,
        listen: false,
      );
      const original = 'Doctor Friday at 17:00 · bring José’s report';
      await tester.tap(find.byTooltip('Type instead'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('capture-words')),
        original,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();
      expect(store.session!.error, CaptureProblem.offline);
      final retained = store.session!.toJson().toString();
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      Future<void> show(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
      }

      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await container.read(themeModeProvider.notifier).setMode(mode);
        for (final language in ['es', 'en']) {
          await container
              .read(regionalProvider.notifier)
              .set(RegionalPreferences(language: language));
          await tester.pumpAndSettle();
          final expected = language == 'es'
              ? AppLocalizationsEs().captureOffline
              : AppLocalizationsEn().captureOffline;
          final error = find.textContaining(expected);
          await show(error);
          expect(error, findsOneWidget);
          expect(store.session!.toJson().toString(), retained);
          await show(find.byKey(const ValueKey('capture-words')));
          expect(
            tester
                .widget<TextField>(find.byKey(const ValueKey('capture-words')))
                .controller!
                .text,
            original,
          );
          expect(api.requests, 1);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets('failed local write never claims the current words were kept', (
    tester,
  ) async {
    final store = _Captures();
    final api = _OfflineExtraction();
    final container = await _open(tester, _Speech(), store, api, listen: false);
    await tester.tap(find.byTooltip('Type instead'));
    await tester.pumpAndSettle();
    final words = find.byKey(const ValueKey('capture-words'));
    await tester.enterText(words, 'Already kept');
    await tester.pumpAndSettle();
    store.failWrites = true;
    await tester.enterText(words, 'New words that could not be kept');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    for (final language in ['en', 'es']) {
      await container
          .read(regionalProvider.notifier)
          .set(RegionalPreferences(language: language));
      await tester.pumpAndSettle();
      final l = language == 'es' ? AppLocalizationsEs() : AppLocalizationsEn();
      final message = find.text(l.captureWriteFailed);
      await tester.ensureVisible(message);
      await tester.pumpAndSettle();
      expect(message, findsOneWidget);
    }
    expect(store.session!.text, 'Already kept');
    expect(api.requests, 0);
    expect(tester.takeException(), isNull);
  });

  for (final interruption in [
    'pause',
    'stop',
    'during-start',
    'stop-during-start',
  ]) {
    final early = interruption.contains('during-start');
    testWidgets(
      early
          ? 'audio $interruption, before any audio, keeps nothing and sends nothing'
          : 'audio $interruption keeps the foreground capture without sending',
      (tester) async {
        final speech = _Speech()..installed = false;
        final recorder = _Recorder()
          ..pauseDuringStart = interruption == 'during-start'
          ..stopDuringStart = interruption == 'stop-during-start';
        final store = _Captures();
        final api = _OfflineExtraction();
        await _open(tester, speech, store, api, recorder: recorder);
        if (early) {
          // Cut off before the first audio: no capture, and its file goes.
          await tester.pumpAndSettle();
          expect(store.session, isNull);
          expect(store.removedAudio, hasLength(1));
          expect(recorder.stops, 1);
          expect(api.requests, 0);
          expect(find.textContaining('Listening ·'), findsNothing);
          expect(tester.takeException(), isNull);
          tester.state<NavigatorState>(find.byType(Navigator)).pop();
          await tester.pumpAndSettle();
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpAndSettle();
          expect(recorder.disposed, isTrue);
          return;
        }
        // Listening alone keeps nothing; the first audio keeps the capture.
        expect(store.session, isNull);
        recorder.amplitudes.add(Amplitude(current: -20, max: 0));
        await tester.pump();
        await tester.pump();
        final id = store.session!.id;
        final capturedAt = store.session!.capturedAt;
        expect(store.session!.status, 'recording');
        await tester.runAsync(() async {
          recorder.states.add(
            interruption == 'pause' ? RecordState.pause : RecordState.stop,
          );
          // Stream cancellation may complete outside the fake frame clock.
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pumpAndSettle();
        expect(tester.binding.lifecycleState, AppLifecycleState.resumed);
        expect(store.session!.status, 'editing');
        expect(store.session!.id, id);
        expect(store.session!.capturedAt, capturedAt);
        expect(store.session!.audioPath, '/synthetic/capture.wav');
        expect(recorder.stops, 1);
        expect(api.requests, 0);
        expect(find.textContaining('Listening ·'), findsNothing);
        final retry = find.widgetWithText(FilledButton, 'Done');
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
      },
    );
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
            'languageInstalled': false,
          },
        );
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
      expect(speech.run, isNotNull);
      speech.emit('partial', text: 'Call the doctor Friday at five');
      await tester.pumpAndSettle();
      expect(store.session!.text, 'Call the doctor Friday at five');
      final originalTime = store.session!.capturedAt;
      speech.controller.add(
        SpeechEvent(speech.run! - 1, 'partial', text: 'Stale words'),
      );
      await tester.pumpAndSettle();
      expect(store.session!.text, 'Call the doctor Friday at five');
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(store.session!.status, 'editing');
      expect(speech.cancelled, isTrue);
      expect(api.requests, 0);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      final id = store.session!.id;
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      unawaited(
        showCaptureSheet(
          tester.element(find.byType(Scaffold).first),
          captureId: id,
          startListening: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Call the doctor Friday at five'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();
      expect(store.session!.status, 'failed');
      expect(store.session!.text, 'Call the doctor Friday at five');
      expect(store.session!.audioPath, isNull);
      expect(store.session!.capturedAt, originalTime);
      expect(api.requests, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a pause commits a segment and listening goes on; the next one appends',
    (tester) async {
      final speech = _Speech();
      final store = _Captures();
      final api = _OfflineExtraction();
      await _open(tester, speech, store, api);
      speech.emit('partial', text: 'Buy');
      speech.emit('segment', text: 'Buy coffee');
      await tester.pumpAndSettle();
      expect(store.session!.text, 'Buy coffee');
      expect(store.session!.status, 'recording');
      expect(api.requests, 0);
      speech.emit('partial', text: 'Pay the');
      await tester.pumpAndSettle();
      expect(store.session!.text, 'Buy coffee Pay the');
      speech.emit('segment', text: 'Pay the bill tomorrow');
      await tester.pumpAndSettle();
      expect(store.session!.text, 'Buy coffee Pay the bill tomorrow');
      expect(store.session!.status, 'recording');
      expect(api.requests, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'microphone denial leaves a working typed capture and no speech session',
    (tester) async {
      final speech = _Speech()..allowed = false;
      final store = _Captures();
      await _open(tester, speech, store, _OfflineExtraction());
      expect(speech.run, isNull);
      await tester.tap(find.byTooltip('Type instead'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('capture-words')),
        'Remember the keys',
      );
      await tester.pumpAndSettle();
      expect(store.session!.text, 'Remember the keys');
      expect(tester.takeException(), isNull);
    },
  );

  group('P33: listening stops only when you say so', () {
    final es = lookupAppLocalizations(const Locale('es'));
    Finder inCapture(Finder finder) =>
        find.descendant(of: find.byType(VoiceTaskScreen), matching: finder);

    testWidgets(
      'U1: segment, pause, segment keep listening; stopping sends both in order',
      (tester) async {
        final bridge = _Bridge(tester);
        final store = _Captures();
        final api = _OfflineExtraction();
        await _open(tester, bridge.speech, store, api, language: 'es');
        expect(bridge.starts, 1);
        bridge.send('ready');
        bridge.send('partial', text: 'Comprar');
        bridge.send('segment', text: 'Comprar pan');
        await tester.pump();
        // A long silent pause: nothing ends, parks or sends the words.
        for (var second = 0; second < 10; second++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(store.session!.text, 'Comprar pan');
        expect(store.session!.status, 'recording');
        expect(find.textContaining(es.listeningSeconds('')), findsOneWidget);
        bridge.send('partial', text: 'y llamar');
        await tester.pump();
        expect(store.session!.text, 'Comprar pan y llamar');
        bridge.send('segment', text: 'y llamar a mamá');
        for (var second = 0; second < 5; second++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(store.session!.text, 'Comprar pan y llamar a mamá');
        expect(store.session!.status, 'recording');
        expect(bridge.stops, 0);
        expect(bridge.cancels, 0);
        expect(api.requests, 0);

        await tester.tap(find.widgetWithText(FilledButton, es.done));
        await tester.pumpAndSettle();
        expect(bridge.stops, 1);
        expect(api.requests, 1);
        expect(store.session!.text, 'Comprar pan y llamar a mamá');
        expect(find.textContaining(es.listeningSeconds('')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-108: the status reads Un momento… until ready, then Escuchando · 00:00',
      (tester) async {
        final bridge = _Bridge(tester);
        await _open(
          tester,
          bridge.speech,
          _Captures(),
          _OfflineExtraction(),
          language: 'es',
        );
        expect(bridge.starts, 1);
        expect(inCapture(find.text(es.captureStarting)), findsOneWidget);
        expect(inCapture(find.byType(LinearProgressIndicator)), findsNothing);
        // The clock doesn't run before the recognizer is ready.
        await tester.pump(const Duration(seconds: 3));
        expect(inCapture(find.text(es.captureStarting)), findsOneWidget);
        expect(find.textContaining(es.listeningSeconds('')), findsNothing);
        bridge.send('ready');
        // A platform event reaches the screen on the next frame.
        await tester.pump();
        await tester.pump();
        expect(
          inCapture(find.text(es.listeningSeconds('00:00'))),
          findsOneWidget,
        );
        expect(inCapture(find.text(es.captureStarting)), findsNothing);
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(
          inCapture(find.text(es.listeningSeconds('00:02'))),
          findsOneWidget,
        );
        // Nothing said yet: Cancelar just closes.
        await tester.tap(find.widgetWithText(TextButton, es.cancel));
        await tester.pumpAndSettle();
        expect(find.byType(VoiceTaskScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'U1: reaching 60 seconds continues to processing instead of parking the words',
      (tester) async {
        final speech = _Speech();
        final store = _Captures();
        final api = _OfflineExtraction();
        await _open(tester, speech, store, api, language: 'es');
        speech.emit('ready');
        speech.emit('segment', text: 'Comprar pan mañana');
        await tester.pump();
        for (var second = 0; second < 59; second++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(store.session!.status, 'recording');
        expect(api.requests, 0);
        expect(
          inCapture(find.text(es.listeningSeconds('00:59'))),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(speech.stops, 1);
        expect(api.requests, 1);
        // Processed (and here failed offline), never parked for editing.
        expect(store.session!.status, isNot('editing'));
        expect(store.session!.text, 'Comprar pan mañana');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-104: inactive while starting and while listening keeps listening; paused keeps the words and shows En pausa',
      (tester) async {
        final speech = _Speech()..permissionGate = Completer<void>();
        final store = _Captures();
        final api = _OfflineExtraction();
        await _open(tester, speech, store, api, language: 'es');
        // The permission dialog covers the app: inactive, then resumed.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        speech.permissionGate!.complete();
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(speech.starts, 1);
        expect(speech.cancelled, isFalse);
        expect(inCapture(find.text(es.captureStarting)), findsOneWidget);
        // Inactive again while starting: still starting, not stopped.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(speech.stops, 0);
        expect(speech.cancelled, isFalse);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        speech.emit('ready');
        speech.emit('segment', text: 'Comprar pan');
        await tester.pump();
        // The notification shade, mid-sentence.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        for (var second = 0; second < 3; second++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(speech.stops, 0);
        expect(speech.cancelled, isFalse);
        expect(store.session!.status, 'recording');
        expect(
          inCapture(find.textContaining(es.listeningSeconds(''))),
          findsOneWidget,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        speech.emit('partial', text: 'y leche');
        await tester.pump();
        // Leaving the app ends listening but keeps every word.
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pumpAndSettle();
        expect(store.session!.status, 'editing');
        expect(store.session!.text, 'Comprar pan y leche');
        expect(api.requests, 0);
        expect(inCapture(find.text(es.capturePaused)), findsOneWidget);
        expect(
          inCapture(find.textContaining(es.listeningSeconds(''))),
          findsNothing,
        );
        for (final state in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pumpAndSettle();
        expect(store.session!.text, 'Comprar pan y leche');
        expect(api.requests, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-107: a blocked microphone shows the Settings banner; back from Settings it listens',
      (tester) async {
        const permissions = MethodChannel(
          'flutter.baseflow.com/permissions/methods',
        );
        final messenger = tester.binding.defaultBinaryMessenger;
        var settingsOpened = 0;
        var micGranted = false;
        messenger.setMockMethodCallHandler(permissions, (call) async {
          if (call.method == 'openAppSettings') {
            settingsOpened++;
            return true;
          }
          if (call.method == 'checkPermissionStatus') {
            return micGranted ? 1 : 4;
          }
          return null;
        });
        addTearDown(
          () => messenger.setMockMethodCallHandler(permissions, null),
        );
        final bridge = _Bridge(tester)..permission = 'blocked';
        final store = _Captures();
        await _open(
          tester,
          bridge.speech,
          store,
          _OfflineExtraction(),
          language: 'es',
        );
        expect(bridge.starts, 0);
        final banner = find.text(es.captureMicrophoneBlocked);
        await tester.ensureVisible(banner);
        await tester.pumpAndSettle();
        expect(banner, findsOneWidget);
        expect(find.textContaining(es.captureMicrophone), findsNothing);
        final open = find.widgetWithText(FilledButton, es.captureOpenSettings);
        await tester.ensureVisible(open);
        await tester.pumpAndSettle();
        expect(open.hitTestable(), findsOneWidget);
        await tester.tap(open);
        await tester.pumpAndSettle();
        expect(settingsOpened, 1);

        // Turned on in Settings: coming back starts listening.
        micGranted = true;
        bridge.permission = 'granted';
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pumpAndSettle();
        expect(bridge.starts, 1);
        expect(find.text(es.captureMicrophoneBlocked), findsNothing);
        expect(find.text(es.captureStarting), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, es.cancel));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-107: a first, ordinary denial keeps the usual microphone message',
      (tester) async {
        final bridge = _Bridge(tester)..permission = 'denied';
        await _open(
          tester,
          bridge.speech,
          _Captures(),
          _OfflineExtraction(),
          language: 'es',
        );
        expect(bridge.starts, 0);
        expect(find.text(es.captureMicrophoneBlocked), findsNothing);
        expect(find.text(es.captureOpenSettings), findsNothing);
        final message = find.textContaining(es.captureMicrophone);
        await tester.ensureVisible(message);
        expect(message, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('UX-101: opening a capture hides an earlier save’s Deshacer', (
      tester,
    ) async {
      const timeout = MethodChannel('taskflow/accessibility');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(timeout, (_) async => 10000);
      addTearDown(() => messenger.setMockMethodCallHandler(timeout, null));
      var undone = false;
      await _open(
        tester,
        _Speech(),
        _Captures(),
        _OfflineExtraction(),
        language: 'es',
        beforeCapture: () async {
          await showFeedback(
            ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)),
            es.captureTasksAdded(1),
            actionLabel: es.undo,
            onAction: () => undone = true,
          );
          await tester.pumpAndSettle();
          expect(find.text(es.undo), findsOneWidget);
        },
      );
      expect(find.byType(VoiceTaskScreen), findsOneWidget);
      expect(find.text(es.undo), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(undone, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  // P49: a recognizer restart (a new `ready`) keeps words the last attempt
  // heard but never finalized.
  group('P49: words heard before a speech restart stay in the field', () {
    final es = lookupAppLocalizations(const Locale('es'));
    String field(WidgetTester tester) {
      final heard = find.byKey(const ValueKey('capture-heard'));
      return heard.evaluate().isEmpty ? '' : tester.widget<Text>(heard).data!;
    }

    Future<_Bridge> listen(WidgetTester tester) async {
      final bridge = _Bridge(tester);
      await _open(
        tester,
        bridge.speech,
        _Captures(),
        _OfflineExtraction(),
        language: 'es',
      );
      expect(bridge.starts, 1);
      return bridge;
    }

    Future<void> deliver(WidgetTester tester) async {
      // A platform event reaches the screen on the next frame.
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
      'UX-437: partial, restart, partial, ended keeps comprar pan y leche',
      (tester) async {
        final bridge = await listen(tester);
        bridge.send('ready');
        bridge.send('partial', text: 'comprar pan');
        await deliver(tester);
        expect(field(tester), 'comprar pan');
        // The attempt ends without a segment and a new one starts.
        bridge.send('ready');
        await deliver(tester);
        bridge.send('partial', text: 'y leche');
        await deliver(tester);
        expect(field(tester), 'comprar pan y leche');
        bridge.send('ended');
        await tester.pumpAndSettle();
        expect(field(tester), 'comprar pan y leche');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-437: after a segment, a restart does not repeat the committed words',
      (tester) async {
        final bridge = await listen(tester);
        bridge.send('ready');
        bridge.send('partial', text: 'comprar pan');
        bridge.send('segment', text: 'comprar pan');
        await deliver(tester);
        bridge.send('ready');
        await deliver(tester);
        bridge.send('partial', text: 'y leche');
        await deliver(tester);
        expect(field(tester), 'comprar pan y leche');
        await tester.tap(find.widgetWithText(FilledButton, es.done));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-437: a first ready on an empty field adds no leading space',
      (tester) async {
        final bridge = await listen(tester);
        expect(field(tester), isEmpty);
        bridge.send('ready');
        await deliver(tester);
        bridge.send('partial', text: 'hola');
        await deliver(tester);
        expect(field(tester), 'hola');
        await tester.tap(find.widgetWithText(FilledButton, es.done));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });

  // P3 / U6, app side: speech hints for the recognizer and the source of the
  // words for the assistant.
  group('U6: speech hints and the source of the words', () {
    final es = lookupAppLocalizations(const Locale('es'));
    final garden = TaskListInfo(
      id: 'garden',
      name: 'Huerto',
      shared: true,
      groupId: 'family',
      groupName: 'Familia',
      people: const [
        ProjectMember(id: 2, name: 'Ana', role: 'editor', voiceName: 'Anita'),
      ],
    );

    test('U6: the es-ES hints hold weekdays, day words and project names', () {
      final hints = speechHints('es-ES', projects: [garden]);
      expect(hints, containsAll(['viernes', 'mañana', 'Huerto', 'Ana']));
      expect(hints, contains('octubre'));
      expect(hints.length, lessThanOrEqualTo(100));
    });

    test('U6: the ca-ES hints hold the Catalan weekdays', () {
      final hints = speechHints('ca-ES', projects: [garden]);
      expect(hints, containsAll(['divendres', 'demà', 'Huerto']));
      expect(hints, isNot(contains('viernes')));
    });

    test('U6: the hints stay about 100 short strings with many projects', () {
      final hints = speechHints(
        'es-ES',
        projects: [
          for (var i = 0; i < 200; i++) TaskListInfo(name: 'Proyecto $i'),
        ],
      );
      expect(hints.length, lessThanOrEqualTo(100));
      expect(hints, contains('viernes'));
      expect(hints.every((hint) => hint.length <= 40), isTrue);
    });

    testWidgets(
      'U6: listening sends the recognizer the speech language’s hints with the user’s projects and people',
      (tester) async {
        final bridge = _Bridge(tester);
        await _open(
          tester,
          bridge.speech,
          _Captures(),
          _OfflineExtraction(),
          language: 'es',
          projects: [garden],
        );
        expect(bridge.starts, 1);
        expect(
          bridge.hints,
          containsAll(['viernes', 'mañana', 'Huerto', 'Ana']),
        );
        await tester.tap(find.widgetWithText(TextButton, es.cancel));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('U6: words from the recognizer go to the assistant as speech', (
      tester,
    ) async {
      final bridge = _Bridge(tester);
      final store = _Captures();
      final api = _OfflineExtraction();
      await _open(tester, bridge.speech, store, api, language: 'es');
      bridge.send('ready');
      bridge.send('segment', text: 'llamar al médico el viernes');
      await tester.pump();
      await tester.pump();
      expect(store.session!.source, 'speech');
      await tester.tap(find.widgetWithText(FilledButton, es.done));
      await tester.pumpAndSettle();
      expect(api.sent.single['source'], 'speech');
      expect(tester.takeException(), isNull);
    });

    testWidgets('U6: typed words go to the assistant as typed', (tester) async {
      final store = _Captures();
      final api = _OfflineExtraction();
      await _open(tester, _Speech(), store, api, language: 'es', listen: false);
      await tester.tap(find.byTooltip(es.captureTypeInstead));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('capture-words')),
        'Comprar pan',
      );
      await tester.pumpAndSettle();
      expect(store.session!.source, 'typed');
      await tester.tap(find.widgetWithText(FilledButton, es.done));
      await tester.pumpAndSettle();
      expect(api.sent.single['source'], 'typed');
      expect(api.sent.single['text'], 'Comprar pan');
      expect(tester.takeException(), isNull);
    });
  });

  // P35: capture is a sheet over the current screen, and Listo always
  // continues.
  group('P35: capture opens as a sheet', () {
    final es = lookupAppLocalizations(const Locale('es'));
    Finder sheet() => find.byType(BottomSheet);
    Finder inSheet(Finder finder) =>
        find.descendant(of: sheet(), matching: finder);
    Future<void> deliver(WidgetTester tester) async {
      // A platform event reaches the screen on the next frame.
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
      'U3: Dictar una tarea on Calendar opens a listening sheet over Calendar with Cancelar, Listo and Escribir, and no mic button',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final bridge = _Bridge(tester);
        await _open(
          tester,
          bridge.speech,
          _Captures(),
          _OfflineExtraction(),
          language: 'es',
          fromButton: true,
        );
        // A sheet over Calendar, not a new page.
        expect(find.byType(CalendarScreen), findsOneWidget);
        expect(sheet(), findsOneWidget);
        expect(inSheet(find.byType(VoiceTaskScreen)), findsOneWidget);
        // Listening at once.
        expect(bridge.starts, 1);
        bridge.send('ready');
        await deliver(tester);
        expect(
          inSheet(find.text(es.listeningSeconds('00:00'))),
          findsOneWidget,
        );
        // No mic button: the only icon button is the keyboard.
        final icons = inSheet(find.byType(IconButton));
        expect(icons, findsOneWidget);
        expect(tester.widget<IconButton>(icons).tooltip, es.captureTypeInstead);
        expect(inSheet(find.byIcon(Icons.keyboard_outlined)), findsOneWidget);
        // The controls, and nothing else to press.
        expect(
          inSheet(find.widgetWithText(TextButton, es.cancel)),
          findsOneWidget,
        );
        expect(
          inSheet(find.widgetWithText(FilledButton, es.done)),
          findsOneWidget,
        );
        expect(
          inSheet(
            find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
          ),
          // Cancelar, Listo and the keyboard (an M3 IconButton).
          findsNWidgets(3),
        );
        // No Task/Note chips, speech options or help from the old page.
        for (final type in [
          ChoiceChip,
          FilterChip,
          ActionChip,
          Switch,
          SwitchListTile,
          DropdownButton<String>,
          PopupMenuButton<String>,
        ]) {
          expect(inSheet(find.byType(type)), findsNothing, reason: '$type');
        }
        // One label per control, the same for TalkBack and the tooltip.
        final keyboard = tester
            .getSemantics(inSheet(find.byTooltip(es.captureTypeInstead)))
            .getSemanticsData();
        expect(keyboard.tooltip, es.captureTypeInstead);
        expect(keyboard.label, anyOf('', es.captureTypeInstead));
        // UX-109 (d): the labelled creation button has no tooltip to read
        // twice.
        expect(
          find.ancestor(
            of: find.text(es.addTask),
            matching: find.byType(Tooltip),
          ),
          findsNothing,
        );
        // While listening, a tap on the scrim doesn't close the sheet.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        expect(sheet(), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, es.cancel));
        await tester.pumpAndSettle();
        expect(sheet(), findsNothing);
        expect(find.byType(CalendarScreen), findsOneWidget);
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'U3: Notas’ Añadir nota opens the same sheet over Notes, and the capture is a note',
      (tester) async {
        final bridge = _Bridge(tester);
        final store = _Captures();
        await _open(
          tester,
          bridge.speech,
          store,
          _OfflineExtraction(),
          language: 'es',
          open: false,
        );
        await tester.tap(find.text(es.notes).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text(es.addNote).hitTestable());
        await tester.pumpAndSettle();
        expect(sheet(), findsOneWidget);
        expect(inSheet(find.byType(VoiceTaskScreen)), findsOneWidget);
        expect(bridge.starts, 1);
        bridge.send('ready');
        bridge.send('segment', text: 'Ideas para el viaje');
        await deliver(tester);
        expect(store.session!.kind, 'note');
        expect(inSheet(find.byIcon(Icons.notes_rounded)), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'U2: Listo is disabled with no words and no audio; with words it stops and processes them',
      (tester) async {
        final bridge = _Bridge(tester);
        final store = _Captures();
        final api = _OfflineExtraction();
        await _open(tester, bridge.speech, store, api, language: 'es');
        bridge.send('ready');
        await deliver(tester);
        final done = find.widgetWithText(FilledButton, es.done);
        expect(done, findsOneWidget);
        expect(tester.widget<FilledButton>(done).onPressed, isNull);
        bridge.send('partial', text: 'Comprar pan');
        await deliver(tester);
        expect(tester.widget<FilledButton>(done).onPressed, isNotNull);
        await tester.tap(done);
        await tester.pumpAndSettle();
        expect(bridge.stops, 1);
        expect(api.requests, 1);
        expect(api.sent.single['text'], 'Comprar pan');
        expect(tester.takeException(), isNull);
      },
    );

    for (final close in ['Cancelar', 'Back', 'swipe down']) {
      testWidgets('U2: with nothing said, $close just closes the sheet', (
        tester,
      ) async {
        final bridge = _Bridge(tester);
        await _open(
          tester,
          bridge.speech,
          _Captures(),
          _OfflineExtraction(),
          language: 'es',
        );
        bridge.send('ready');
        await deliver(tester);
        expect(sheet(), findsOneWidget);
        switch (close) {
          case 'Cancelar':
            await tester.tap(find.widgetWithText(TextButton, es.cancel));
          case 'Back':
            await tester.binding.handlePopRoute();
          default:
            await tester.drag(
              find.text(es.listeningSeconds('00:00')),
              const Offset(0, 300),
            );
        }
        await tester.pumpAndSettle();
        expect(find.text(es.captureKeepQuestion), findsNothing);
        expect(sheet(), findsNothing);
        expect(find.byType(VoiceTaskScreen), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    Future<_Captures> withWords(WidgetTester tester) async {
      final bridge = _Bridge(tester);
      final store = _Captures();
      await _open(
        tester,
        bridge.speech,
        store,
        _OfflineExtraction(),
        language: 'es',
      );
      bridge.send('ready');
      bridge.send('segment', text: 'Comprar pan');
      await deliver(tester);
      expect(store.session!.text, 'Comprar pan');
      return store;
    }

    testWidgets(
      'U2: with words, Cancelar asks ¿Conservar lo que has dicho para más tarde?; Conservar is the filled button and keeps the capture',
      (tester) async {
        final store = await withWords(tester);
        await tester.tap(find.widgetWithText(TextButton, es.cancel));
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget);
        expect(
          find.descendant(
            of: dialog,
            matching: find.text(es.captureKeepQuestion),
          ),
          findsOneWidget,
        );
        // One question, with no second line.
        expect(tester.widget<AlertDialog>(dialog).content, isNull);
        final keep = find.widgetWithText(FilledButton, es.keep);
        final discard = find.widgetWithText(TextButton, es.discard);
        expect(keep, findsOneWidget);
        expect(discard, findsOneWidget);
        // Discarding is never the filled button, and reads as destructive.
        final error = Theme.of(tester.element(dialog)).colorScheme.error;
        expect(
          tester
              .widget<TextButton>(discard)
              .style
              ?.foregroundColor
              ?.resolve({}),
          error,
        );
        await tester.tap(keep);
        await tester.pumpAndSettle();
        expect(sheet(), findsNothing);
        expect(store.discarded, isEmpty);
        expect(store.session!.status, isNot('discarded'));
        expect(store.session!.text, 'Comprar pan');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('U2: with words, Descartar deletes the capture', (
      tester,
    ) async {
      final store = await withWords(tester);
      await tester.tap(find.widgetWithText(TextButton, es.cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, es.discard));
      await tester.pumpAndSettle();
      expect(store.discarded, ['test-capture']);
      expect(sheet(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('U2: with words, Back asks the same question as Cancelar', (
      tester,
    ) async {
      await withWords(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(es.captureKeepQuestion), findsOneWidget);
      expect(sheet(), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, es.keep));
      await tester.pumpAndSettle();
      expect(sheet(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'U2: with words, a swipe down asks the same question as Cancelar',
      (tester) async {
        await withWords(tester);
        await tester.drag(
          find.byKey(const ValueKey('capture-heard')),
          const Offset(0, 300),
        );
        await tester.pumpAndSettle();
        expect(find.text(es.captureKeepQuestion), findsOneWidget);
        expect(sheet(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-126: the sheet has no Descartar captura button; discarding lives only in Cancelar’s question',
      (tester) async {
        await withWords(tester);
        expect(inSheet(find.textContaining(es.discard)), findsNothing);
        expect(
          inSheet(
            find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
          ),
          // Cancelar, Listo and the keyboard (an M3 IconButton).
          findsNWidgets(3),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-109: with TalkBack the sheet waits for Empezar a hablar, then announces Escuchando and Listo',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(accessibleNavigation: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final bridge = _Bridge(tester);
        await _open(
          tester,
          bridge.speech,
          _Captures(),
          _OfflineExtraction(),
          language: 'es',
        );
        await tester.pump(const Duration(seconds: 3));
        expect(bridge.starts, 0);
        final start = find.widgetWithText(FilledButton, es.captureStartTalking);
        expect(start, findsOneWidget);
        expect(tester.widget<FilledButton>(start).autofocus, isTrue);
        tester.takeAnnouncements();
        await tester.tap(start);
        await tester.pump();
        expect(bridge.starts, 1);
        bridge.send('ready');
        await deliver(tester);
        expect(
          tester.takeAnnouncements().map((a) => a.message),
          contains(es.captureListening),
        );
        bridge.send('segment', text: 'Comprar pan');
        await deliver(tester);
        await tester.tap(find.widgetWithText(FilledButton, es.done));
        await tester.pump();
        expect(
          tester.takeAnnouncements().map((a) => a.message),
          contains(es.done),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'P35: after 5 s without new words the silence line shows, and goes when words arrive; at 50 s Quedan 10 segundos',
      (tester) async {
        final speech = _Speech();
        await _open(
          tester,
          speech,
          _Captures(),
          _OfflineExtraction(),
          language: 'es',
        );
        speech.emit('ready');
        await tester.pump();
        for (var second = 0; second < 4; second++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(find.text(es.captureNothingHeardYet), findsNothing);
        await tester.pump(const Duration(seconds: 1));
        // No words yet: nothing heard, not `Toca Listo` (UX-1304).
        expect(inSheet(find.text(es.captureNothingHeardYet)), findsOneWidget);
        speech.emit('partial', text: 'Comprar pan');
        await tester.pump();
        expect(find.text(es.captureNothingHeardYet), findsNothing);
        expect(find.text(es.captureStillListening), findsNothing);
        for (var second = 5; second < 49; second++) {
          await tester.pump(const Duration(seconds: 1));
          speech.emit('partial', text: 'Comprar pan $second');
        }
        await tester.pump();
        expect(find.text(es.captureTimeLeft(10)), findsNothing);
        await tester.pump(const Duration(seconds: 1));
        expect(inSheet(find.text(es.captureTimeLeft(10))), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'P35: leaving the app shows En pausa with Seguir and Listo; Seguir listens again and appends',
      (tester) async {
        final bridge = _Bridge(tester);
        final store = _Captures();
        await _open(
          tester,
          bridge.speech,
          store,
          _OfflineExtraction(),
          language: 'es',
        );
        bridge.send('ready');
        bridge.send('segment', text: 'Comprar pan');
        await deliver(tester);
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pumpAndSettle();
        for (final state in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pumpAndSettle();
        expect(inSheet(find.text(es.capturePaused)), findsOneWidget);
        final resume = find.widgetWithText(FilledButton, es.captureContinue);
        expect(resume, findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, es.done).hitTestable(),
          findsOneWidget,
        );
        expect(bridge.starts, 1);
        await tester.tap(resume);
        await tester.pump();
        expect(bridge.starts, 2);
        bridge.send('ready');
        await deliver(tester);
        bridge.send('partial', text: 'y leche');
        await deliver(tester);
        expect(store.session!.text, 'Comprar pan y leche');
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('capture-heard'))).data,
          'Comprar pan y leche',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-105: at 2x text on 360x740 the newest words and the three controls stay in view while listening',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final bridge = _Bridge(tester);
        await _open(
          tester,
          bridge.speech,
          _Captures(),
          _OfflineExtraction(),
          language: 'es',
          size: const Size(360, 740),
        );
        bridge.send('ready');
        const words =
            'Comprar pan y leche en la tienda de la esquina, llamar al médico '
            'el viernes a las cinco, recoger a los niños del colegio, pagar la '
            'factura de la luz antes del lunes, regar las plantas del balcón, '
            'escribir a la abuela y reservar mesa para el sábado por la noche';
        bridge.send('segment', text: words);
        await deliver(tester);
        const screen = Rect.fromLTWH(0, 0, 360, 740);
        bool onScreen(Rect rect) =>
            screen.contains(rect.topLeft) &&
            screen.contains(rect.bottomRight - const Offset(0.1, 0.1));
        final heard = find.byKey(const ValueKey('capture-heard'));
        expect(heard, findsOneWidget);
        // The words' scroll view sits at its end: the newest words show.
        final scroll = find
            .ancestor(of: heard, matching: find.byType(Scrollable))
            .first;
        final view = tester.getRect(scroll);
        expect(onScreen(view), isTrue);
        expect(
          tester.getRect(heard).bottom,
          lessThanOrEqualTo(view.bottom + 0.5),
        );
        expect(
          tester.state<ScrollableState>(scroll).position.pixels,
          0,
          reason: 'reversed: 0 is the end of the words',
        );
        // The words are the largest text in the sheet.
        final status = find.textContaining(es.listeningSeconds(''));
        expect(
          tester.renderObject<RenderParagraph>(heard).text.style!.fontSize!,
          greaterThan(
            tester.renderObject<RenderParagraph>(status).text.style!.fontSize!,
          ),
        );
        for (final control in [
          find.widgetWithText(TextButton, es.cancel),
          find.widgetWithText(FilledButton, es.done),
          find.byTooltip(es.captureTypeInstead),
        ]) {
          expect(control.hitTestable(), findsOneWidget);
          expect(onScreen(tester.getRect(control)), isTrue, reason: '$control');
        }
        expect(tester.takeException(), isNull);
      },
    );
  });

  // P54: Seguir only where listening stopped; TalkBack hears what happened.
  group('P54: capture sheet regressions', () {
    final es = lookupAppLocalizations(const Locale('es'));
    Finder sheet() => find.byType(BottomSheet);
    Finder inSheet(Finder finder) =>
        find.descendant(of: sheet(), matching: finder);
    Future<void> deliver(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
    }

    Future<void> reopen(
      WidgetTester tester,
      ProviderContainer container,
      _Captures store, {
      required String? source,
    }) async {
      store.session = CaptureSession(
        id: 'reopened',
        ownerKey: container.read(captureOwnerProvider),
        timezone: 'UTC',
        capturedAt: DateTime.now().toUtc(),
        text: 'Comprar pan',
        source: source,
      );
      unawaited(
        showCaptureSheet(
          tester.element(find.byType(Scaffold).first),
          captureId: 'reopened',
          startListening: false,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'UX-440: shared text opened in the sheet without listening shows Listo and Cancelar, and no Seguir',
      (tester) async {
        final speech = _Speech();
        final store = _Captures();
        final container = await _open(
          tester,
          speech,
          store,
          _OfflineExtraction(),
          language: 'es',
          open: false,
        );
        // A share arrives as typed text (CaptureStore.acceptEntry).
        await reopen(tester, container, store, source: 'typed');
        expect(sheet(), findsOneWidget);
        expect(inSheet(find.text('Comprar pan')), findsOneWidget);
        expect(
          inSheet(find.widgetWithText(FilledButton, es.done)).hitTestable(),
          findsOneWidget,
        );
        expect(
          inSheet(find.widgetWithText(TextButton, es.cancel)).hitTestable(),
          findsOneWidget,
        );
        expect(inSheet(find.text(es.captureContinue)), findsNothing);
        expect(inSheet(find.text(es.captureStartTalking)), findsNothing);
        expect(speech.starts, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-440: a voice capture cut off by leaving the app shows En pausa and Seguir; a reopened voice capture shows Seguir too',
      (tester) async {
        final bridge = _Bridge(tester);
        final store = _Captures();
        final container = await _open(
          tester,
          bridge.speech,
          store,
          _OfflineExtraction(),
          language: 'es',
        );
        bridge.send('ready');
        bridge.send('segment', text: 'Comprar pan');
        await deliver(tester);
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pumpAndSettle();
        expect(inSheet(find.text(es.capturePaused)), findsOneWidget);
        expect(
          inSheet(find.widgetWithText(FilledButton, es.captureContinue)),
          findsOneWidget,
        );
        // Closed with its words kept, then reopened from Capturas pendientes.
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
        expect(sheet(), findsNothing);
        await reopen(tester, container, store, source: 'speech');
        expect(inSheet(find.text('Comprar pan')), findsOneWidget);
        expect(
          inSheet(
            find.widgetWithText(FilledButton, es.captureContinue),
          ).hitTestable(),
          findsOneWidget,
        );
        expect(
          inSheet(find.widgetWithText(FilledButton, es.done)).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    Future<_Bridge> listeningWithWords(WidgetTester tester) async {
      final bridge = _Bridge(tester);
      await _open(
        tester,
        bridge.speech,
        _Captures(),
        _OfflineExtraction(),
        language: 'es',
      );
      bridge.send('ready');
      bridge.send('segment', text: 'Comprar pan');
      await deliver(tester);
      tester.takeAnnouncements();
      return bridge;
    }

    List<String> announced(WidgetTester tester) =>
        tester.takeAnnouncements().map((a) => a.message).toList();

    testWidgets(
      'UX-441: with words heard, Cancelar announces nothing before the keep-or-discard question',
      (tester) async {
        await listeningWithWords(tester);
        await tester.tap(find.widgetWithText(TextButton, es.cancel));
        await tester.pumpAndSettle();
        expect(find.text(es.captureKeepQuestion), findsOneWidget);
        final heard = announced(tester);
        expect(heard, isNot(contains(es.done)));
        expect(heard, isNot(contains(es.capturePaused)));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('UX-441: Listo announces Listo exactly once', (tester) async {
      await listeningWithWords(tester);
      await tester.tap(find.widgetWithText(FilledButton, es.done));
      await tester.pumpAndSettle();
      expect(announced(tester).where((m) => m == es.done), hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'UX-441: the keyboard button stops listening without announcing Listo or En pausa',
      (tester) async {
        await listeningWithWords(tester);
        await tester.tap(find.byTooltip(es.captureTypeInstead));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('capture-words')), findsOneWidget);
        final heard = announced(tester);
        expect(heard, isNot(contains(es.done)));
        expect(heard, isNot(contains(es.capturePaused)));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-441: the app going to the background while listening announces En pausa, not Listo',
      (tester) async {
        await listeningWithWords(tester);
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pumpAndSettle();
        final heard = announced(tester);
        expect(heard, contains(es.capturePaused));
        expect(heard, isNot(contains(es.done)));
        for (final state in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });

  // Last in the file: the real fonts stay loaded for the rest of the run, and
  // the tests above were written against the test font.
  group('UX-444: the silence hint with the app’s fonts', () {
    setUpAll(() async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });

    testWidgets(
      'UX-444: in English at 2x text on 360x740, after words and 5 s of silence the hint reads Still listening. Tap Done when finished. in full',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final en = lookupAppLocalizations(const Locale('en'));
        expect(
          en.captureStillListening,
          'Still listening. Tap Done when finished.',
        );
        final speech = _Speech();
        await _open(
          tester,
          speech,
          _Captures(),
          _OfflineExtraction(),
          size: const Size(360, 740),
        );
        speech.emit('ready');
        await tester.pump();
        // Once words are heard (UX-1304); before, it says nothing was heard.
        speech.emit('partial', text: 'Buy bread');
        await tester.pump();
        for (var second = 0; second < 5; second++) {
          await tester.pump(const Duration(seconds: 1));
        }
        final hint = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(en.captureStillListening),
        );
        expect(hint, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(hint);
        expect(paragraph.didExceedMaxLines, isFalse, reason: 'not cut off');
        final rect = tester.getRect(hint);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
        expect(rect.bottom, lessThanOrEqualTo(740));
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- 2026-10-14-speed · P103 (UX-603): capture opens ready ----

  group('P103: capture opens ready', () {
    final es = lookupAppLocalizations(const Locale('es'));
    Finder sheet() => find.byType(BottomSheet);

    /// A few frames, without waiting for anything to settle.
    Future<void> frames(WidgetTester tester, [int count = 4]) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    /// Calendar's `Añadir tarea`.
    Future<void> addTask(WidgetTester tester) async {
      await tester.tap(find.text(es.addTask).hitTestable());
      await frames(tester);
    }

    /// Closes the sheet with nothing said: Back, which asks nothing.
    Future<void> close(WidgetTester tester) async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(sheet(), findsNothing);
    }

    testWidgets(
      'UX-603: with a capability answer that takes 2 s, the first open listens once it answers; the next open listens at once, and capability() was asked only once',
      (tester) async {
        final speech = _OpeningSpeech()..gate = Completer<void>();
        await _open(
          tester,
          speech,
          _Captures(),
          _OfflineExtraction(),
          language: 'es',
          open: false,
        );
        await addTask(tester);
        await tester.pump(const Duration(milliseconds: 1900));
        expect(speech.starts, 0, reason: 'listening waits for the answer');
        // The answer arrives, 2 s after it was asked.
        speech.gate!.complete();
        await frames(tester);
        expect(speech.starts, 1);
        expect(speech.capabilities, 1);
        await close(tester);

        // The next open: the gate would hold a second probe forever.
        speech.gate = Completer<void>();
        await addTask(tester);
        expect(speech.starts, 2, reason: 'listening without waiting');
        expect(speech.capabilities, 1);
        await close(tester);
        speech.gate!.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-603 / UX-1306: after a failed native start, the sheet listens online; the next open starts online without asking capability() again',
      (tester) async {
        final speech = _OpeningSpeech()
          ..startError = PlatformException(code: 'recognizer-busy');
        await _open(
          tester,
          speech,
          _Captures(),
          _OfflineExtraction(),
          recorder: _Recorder(),
          language: 'es',
          open: false,
        );
        expect(speech.capabilities, 1, reason: 'the warm-up asked once');
        await addTask(tester);
        await tester.pumpAndSettle();
        expect(speech.starts, 1);
        expect(speech.capabilities, 1, reason: 'the open used the answer');
        expect(
          find.textContaining(es.listeningSeconds('')),
          findsOneWidget,
          reason: 'listening online, with no tap',
        );
        await close(tester);

        speech.startError = null;
        await addTask(tester);
        await tester.pumpAndSettle();
        expect(speech.capabilities, 1, reason: '«not usable» is remembered');
        expect(speech.starts, 1, reason: 'online without trying on-device');
        await close(tester);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-603 / UX-1306: an error event before the recognizer is ready goes online; the next open starts online without asking capability() again',
      (tester) async {
        final speech = _OpeningSpeech();
        await _open(
          tester,
          speech,
          _Captures(),
          _OfflineExtraction(),
          recorder: _Recorder(),
          language: 'es',
          open: false,
        );
        await addTask(tester);
        await tester.pumpAndSettle();
        expect(speech.capabilities, 1);
        speech.emit('error');
        await tester.pumpAndSettle();
        await close(tester);
        await addTask(tester);
        await tester.pumpAndSettle();
        expect(speech.capabilities, 1);
        expect(speech.starts, 1);
        await close(tester);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-603: an answer from capability()’s error path (it throws) isn’t remembered: every open asks again',
      (tester) async {
        final speech = _OpeningSpeech()
          ..capabilityError = PlatformException(code: 'binder');
        await _open(
          tester,
          speech,
          _Captures(),
          _OfflineExtraction(),
          recorder: _Recorder(),
          language: 'es',
          open: false,
        );
        expect(speech.capabilities, 1, reason: 'the warm-up asked once');
        await addTask(tester);
        await tester.pumpAndSettle();
        expect(speech.capabilities, 2);
        await close(tester);
        await addTask(tester);
        await tester.pumpAndSettle();
        expect(speech.capabilities, 3);
        await close(tester);
        expect(tester.takeException(), isNull);
      },
    );

    for (final timesOut in [false, true]) {
      testWidgets(
        'UX-603: over the real bridge, a capability call that ${timesOut ? 'times out (4 s)' : 'fails on the platform side'} isn’t remembered: the next open asks again',
        (tester) async {
          final bridge = _Bridge(tester)
            ..capability = timesOut
                ? () => Completer<Object?>().future
                : () async => throw PlatformException(code: 'binder');
          await _open(
            tester,
            bridge.speech,
            _Captures(),
            _OfflineExtraction(),
            recorder: _Recorder(),
            language: 'es',
            open: false,
          );
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          final warmed = bridge.capabilities;
          expect(warmed, 1, reason: 'the warm-up asked once');
          await addTask(tester);
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          expect(bridge.capabilities, warmed + 1);
          await close(tester);
          await addTask(tester);
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          expect(bridge.capabilities, warmed + 2);
          await close(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-603: Calendar with Añadir tarea and the mic asks capability() once by itself after its first frame; opening capture then listens with no second call',
      (tester) async {
        final speech = _OpeningSpeech();
        await _open(
          tester,
          speech,
          _Captures(),
          _OfflineExtraction(),
          language: 'es',
          open: false,
        );
        expect(find.text(es.addTask), findsOneWidget);
        expect(speech.capabilities, 1);
        await tester.pump(const Duration(seconds: 2));
        expect(speech.capabilities, 1, reason: 'once, not on every frame');
        expect(speech.starts, 0);
        await addTask(tester);
        expect(speech.starts, 1);
        expect(speech.capabilities, 1);
        await close(tester);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-603: with a time-zone lookup that takes 3 s, listening starts before it answers, and the capture made from the first words stores the zone it returned',
      (tester) async {
        final messenger = tester.binding.defaultBinaryMessenger;
        const zone = MethodChannel('flutter_timezone');
        var answered = false;
        messenger.setMockMethodCallHandler(zone, (_) async {
          await Future<void>.delayed(const Duration(seconds: 3));
          answered = true;
          return 'America/New_York';
        });
        final speech = _OpeningSpeech();
        final store = _Captures();
        await _open(
          tester,
          speech,
          store,
          _OfflineExtraction(),
          language: 'es',
          open: false,
        );
        await addTask(tester);
        expect(speech.starts, 1);
        expect(answered, isFalse, reason: 'started before the zone answered');
        speech.emit('ready');
        speech.emit('segment', text: 'Mañana llamar a Juan');
        await frames(tester);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        expect(answered, isTrue);
        expect(store.session, isNotNull);
        expect(store.session!.timezone, 'America/New_York');
        expect(store.session!.text, 'Mañana llamar a Juan');
        await tester.tap(find.widgetWithText(TextButton, es.cancel));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, es.keep));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    for (final throws in [false, true]) {
      testWidgets(
        'UX-603: with a cleanFinished that ${throws ? 'throws' : 'takes 2 s'}, listening starts first and no error shows',
        (tester) async {
          final log = <String>[];
          final speech = _OpeningSpeech()..log = log;
          final store = _Captures()
            ..log = log
            ..cleanDelay = throws ? null : const Duration(seconds: 2)
            ..cleanError = throws
                ? StateError('Synthetic sweep failure')
                : null;
          await _open(
            tester,
            speech,
            store,
            _OfflineExtraction(),
            language: 'es',
            open: false,
          );
          await addTask(tester);
          expect(speech.starts, 1);
          speech.emit('ready');
          await tester.pump(const Duration(seconds: 3));
          expect(log.first, 'start', reason: '$log');
          expect(log, contains('clean'), reason: 'the sweep still runs');
          expect(find.text(es.listeningSeconds('00:03')), findsOneWidget);
          expect(find.byType(MessageBanner), findsNothing);
          await close(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-603: a recognizer that sends listening and no ready shows Escuchando · 00:00 and announces Escuchando once; a later ready keeps the words and the clock',
      (tester) async {
        final speech = _OpeningSpeech();
        await _open(
          tester,
          speech,
          _Captures(),
          _OfflineExtraction(),
          language: 'es',
          open: false,
        );
        await addTask(tester);
        expect(speech.starts, 1);
        expect(find.text(es.captureStarting), findsOneWidget);
        tester.takeAnnouncements();
        speech.emit('listening');
        await frames(tester, 2);
        expect(find.text(es.listeningSeconds('00:00')), findsOneWidget);
        expect(find.text(es.captureStarting), findsNothing);
        expect(
          tester.takeAnnouncements().where(
            (a) => a.message == es.captureListening,
          ),
          hasLength(1),
        );
        // Words kept by the app's own microphone, before the recognizer is
        // ready.
        speech.emit('partial', text: 'Mañana');
        await tester.pump(const Duration(seconds: 2));
        expect(find.text(es.listeningSeconds('00:02')), findsOneWidget);
        speech.emit('ready');
        await frames(tester, 2);
        expect(
          find.text('Mañana'),
          findsOneWidget,
          reason: 'ready keeps the words shown',
        );
        expect(find.text(es.listeningSeconds('00:02')), findsOneWidget);
        expect(find.text(es.listeningSeconds('00:00')), findsNothing);
        expect(
          tester.takeAnnouncements().where(
            (a) => a.message == es.captureListening,
          ),
          isEmpty,
          reason: 'announced once',
        );
        await tester.pump(const Duration(seconds: 1));
        expect(find.text(es.listeningSeconds('00:03')), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, es.cancel));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, es.keep));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    // ---- P101 (UX-610): the recognizer's last words are measured ----

    testWidgets(
      'UX-610: after Listo on a native capture, one recognizerFinish diagnostics row is recorded with an elapsed time',
      (tester) async {
        final database = _DiagnosticsDatabase();
        final store = _Captures(database: TaskDatabase.forTesting(database));
        final speech = _OpeningSpeech();
        await _open(
          tester,
          speech,
          store,
          _OfflineExtraction(),
          language: 'es',
          open: false,
        );
        await addTask(tester);
        speech.emit('ready');
        speech.emit('segment', text: 'Comprar pan');
        await tester.pumpAndSettle();
        expect(
          database.rows.where((row) => row['event'] == 'recognizerFinish'),
          isEmpty,
        );
        await tester.tap(find.widgetWithText(FilledButton, es.done));
        await tester.pumpAndSettle();
        final rows = database.rows
            .where((row) => row['event'] == 'recognizerFinish')
            .toList();
        expect(rows, hasLength(1));
        expect(rows.single['elapsed_ms'], isA<int>());
        expect(rows.single['elapsed_ms'] as int, greaterThanOrEqualTo(0));
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- UX loop 2026-10-19-app, round 1 · P166 (UX-107, UX-1303, UX-1305,
  // UX-1306): the microphone, and P167 (UX-1304): what listening says ----

  group('P166 / P167: the microphone and listening', () {
    final es = lookupAppLocalizations(const Locale('es'));
    final ca = lookupAppLocalizations(const Locale('ca'));
    const phone = Size(360, 800);
    setUpAll(() async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });

    Finder inSheet(Finder finder) =>
        find.descendant(of: find.byType(VoiceTaskScreen), matching: finder);

    /// The banner holding [text], and whether it shows in the error style.
    void expectNeutralBanner(WidgetTester tester, String text) {
      final line = inSheet(find.text(text));
      expect(line, findsOneWidget, reason: text);
      final banner = find.ancestor(
        of: line,
        matching: find.byType(MessageBanner),
      );
      expect(banner, findsOneWidget);
      expect(tester.widget<MessageBanner>(banner).isError, isFalse);
      final colors = Theme.of(tester.element(line)).colorScheme;
      final surface = tester.widget<AppSurface>(
        find.descendant(of: banner, matching: find.byType(AppSurface)).first,
      );
      expect(surface.color, isNot(colors.errorContainer));
      final style = tester.widget<Text>(line).style;
      expect(style?.color, isNot(colors.onErrorContainer));
    }

    /// The text [finder] is whole: not ellipsized, and inside the area its
    /// scroll view shows.
    void expectWhole(WidgetTester tester, Finder finder) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: finder, matching: find.byType(RichText)).first,
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      final rect = tester.getRect(finder);
      final scroll = find.ancestor(
        of: finder,
        matching: find.byType(Scrollable),
      );
      final area = scroll.evaluate().isEmpty
          ? Offset.zero & tester.view.physicalSize
          : tester.getRect(scroll.first);
      expect(rect.top, greaterThanOrEqualTo(area.top - 0.5), reason: '$rect');
      expect(
        rect.bottom,
        lessThanOrEqualTo(area.bottom + 0.5),
        reason: '$rect in $area',
      );
    }

    /// permission_handler's channel: the microphone's status, and Settings.
    ({int Function() settings}) permissions(
      WidgetTester tester, {
      required bool Function() granted,
    }) {
      const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
      final messenger = tester.binding.defaultBinaryMessenger;
      var opened = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'openAppSettings') {
          opened++;
          return true;
        }
        // 1: granted; 0: denied, so Android can still ask.
        if (call.method == 'checkPermissionStatus') return granted() ? 1 : 0;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      return (settings: () => opened);
    }

    /// The blocked state, in [l]: one full-width filled «Abrir Ajustes» with
    /// the focus, «Escribir» and «Cancelar», and no «Empezar a hablar».
    void expectBlocked(WidgetTester tester, AppLocalizations l) {
      expectNeutralBanner(tester, l.captureMicrophoneBlocked);
      expect(
        find.descendant(
          of: find.ancestor(
            of: inSheet(find.text(l.captureMicrophoneBlocked)),
            matching: find.byType(MessageBanner),
          ),
          matching: find.byIcon(Icons.mic_off_outlined),
        ),
        findsOneWidget,
      );
      final filled = inSheet(find.byType(FilledButton));
      expect(filled, findsOneWidget);
      expect(
        find.descendant(of: filled, matching: find.text(l.captureOpenSettings)),
        findsOneWidget,
      );
      expect(inSheet(find.text(l.captureOpenSettings)), findsOneWidget);
      // The whole width of the sheet's content (24 dp each side).
      final sheet = tester.getRect(find.byType(BottomSheet));
      expect(
        tester.getRect(filled).width,
        moreOrLessEquals(sheet.width - 48, epsilon: 1),
      );
      expect(filled.hitTestable(), findsOneWidget);
      final focused = FocusManager.instance.primaryFocus?.context;
      expect(focused, isNotNull);
      expect(
        find.descendant(
          of: filled,
          matching: find.byElementPredicate((e) => e == focused),
        ),
        findsOneWidget,
        reason: 'the focus starts on ${l.captureOpenSettings}',
      );
      expect(inSheet(find.text(l.captureStartTalking)), findsNothing);
      expect(
        inSheet(find.byTooltip(l.captureTypeInstead)).hitTestable(),
        findsOneWidget,
      );
      expect(
        inSheet(find.widgetWithText(TextButton, l.cancel)).hitTestable(),
        findsOneWidget,
      );
    }

    testWidgets(
      'UX-107 / UX-1303: ES 1x on 360x800, online path (Voz En línea, al terminar), the bridge answers blocked: the neutral Para volver a dictar… banner, one full-width focused filled Abrir Ajustes, Escribir and Cancelar, no Empezar a hablar',
      (tester) async {
        permissions(tester, granted: () => false);
        final bridge = _Bridge(tester)..permission = 'blocked';
        final recorder = _Recorder();
        await _open(
          tester,
          bridge.speech,
          _Captures(),
          _OfflineExtraction(),
          recorder: recorder,
          language: 'es',
          size: phone,
          speechOnline: true,
        );
        expect(bridge.starts, 0);
        expect(recorder.starts, 0);
        expectBlocked(tester, es);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1303: the same blocked state on the on-device path (ES 1x, 360x800)',
      (tester) async {
        permissions(tester, granted: () => false);
        final bridge = _Bridge(tester)..permission = 'blocked';
        await _open(
          tester,
          bridge.speech,
          _Captures(),
          _OfflineExtraction(),
          recorder: _Recorder(),
          language: 'es',
          size: phone,
        );
        expect(bridge.starts, 0);
        expectBlocked(tester, es);
        expect(tester.takeException(), isNull);
      },
    );

    for (final online in [false, true]) {
      testWidgets(
        'UX-1303: CA at 2x on 360x800, ${online ? 'online' : 'on-device'} path, blocked: Obre Configuració is the filled button, no Comença a parlar, and the banner’s text isn’t cut',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          permissions(tester, granted: () => false);
          final bridge = _Bridge(tester)..permission = 'blocked';
          await _open(
            tester,
            bridge.speech,
            _Captures(),
            _OfflineExtraction(),
            recorder: _Recorder(),
            language: 'ca',
            size: phone,
            speechOnline: online,
          );
          expect(ca.captureOpenSettings, 'Obre Configuració');
          expectBlocked(tester, ca);
          expectWhole(tester, inSheet(find.text(ca.captureMicrophoneBlocked)));
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final online in [false, true]) {
      testWidgets(
        'UX-107 / UX-1303: ${online ? 'online' : 'on-device'} path, tapping Abrir Ajustes opens the app’s settings once; back with the microphone allowed, the sheet listens',
        (tester) async {
          var granted = false;
          final opener = permissions(tester, granted: () => granted);
          final bridge = _Bridge(tester)..permission = 'blocked';
          final recorder = _Recorder();
          await _open(
            tester,
            bridge.speech,
            _Captures(),
            _OfflineExtraction(),
            recorder: recorder,
            language: 'es',
            size: phone,
            speechOnline: online,
          );
          await tester.tap(
            inSheet(find.widgetWithText(FilledButton, es.captureOpenSettings)),
          );
          await tester.pumpAndSettle();
          expect(opener.settings(), 1);

          // Allowed in Settings: coming back starts listening.
          granted = true;
          bridge.permission = 'granted';
          for (final state in [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
          await tester.pumpAndSettle();
          expect(opener.settings(), 1);
          expect(inSheet(find.text(es.captureMicrophoneBlocked)), findsNothing);
          if (online) {
            expect(recorder.starts, 1);
            expect(bridge.starts, 0);
            expect(
              inSheet(find.textContaining(es.listeningSeconds(''))),
              findsOneWidget,
            );
          } else {
            expect(bridge.starts, 1);
            expect(recorder.starts, 0);
            expect(inSheet(find.text(es.captureStarting)), findsOneWidget);
          }
          await tester.tap(inSheet(find.widgetWithText(TextButton, es.cancel)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-1305: ES, first start with the microphone not granted and Android’s question open: Permite el micrófono… shows in place of Listo; once allowed it goes',
      (tester) async {
        permissions(tester, granted: () => false);
        final speech = _Speech()..permissionGate = Completer<void>();
        await _open(
          tester,
          speech,
          _Captures(),
          _OfflineExtraction(),
          language: 'es',
          size: phone,
        );
        // P198 (UX-1627): the line waits 300 ms, past a blocked answer.
        await tester.pump(const Duration(milliseconds: 300));
        final why = inSheet(find.text(es.captureMicrophoneWhy));
        expect(why, findsOneWidget);
        expect(inSheet(find.text(es.done)), findsNothing);
        expect(speech.starts, 0);
        speech.permissionGate!.complete();
        await tester.pumpAndSettle();
        expect(inSheet(find.text(es.captureMicrophoneWhy)), findsNothing);
        expect(speech.starts, 1);
        speech.emit('ready');
        await tester.pump();
        await tester.pump();
        expect(
          inSheet(find.widgetWithText(FilledButton, es.done)),
          findsOneWidget,
        );
        await tester.tap(inSheet(find.widgetWithText(TextButton, es.cancel)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1305: ES, with the microphone already granted, no frame of the start shows Permite el micrófono…',
      (tester) async {
        permissions(tester, granted: () => true);
        final speech = _Speech()..permissionGate = Completer<void>();
        await _open(
          tester,
          speech,
          _Captures(),
          _OfflineExtraction(),
          language: 'es',
          size: phone,
          open: false,
        );
        unawaited(
          showCaptureSheet(tester.element(find.byType(Scaffold).first)),
        );
        // Every frame of the opening and the start, the answer held back.
        for (var frame = 0; frame < 40; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            find.text(es.captureMicrophoneWhy),
            findsNothing,
            reason: 'frame $frame',
          );
        }
        speech.permissionGate!.complete();
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            find.text(es.captureMicrophoneWhy),
            findsNothing,
            reason: 'after the answer, frame $frame',
          );
        }
        expect(speech.starts, 1);
        await tester.tap(inSheet(find.widgetWithText(TextButton, es.cancel)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    // ---- round 2 · P198 (UX-1627): the reason only when Android asks ----

    testWidgets(
      'UX-1627: ES, first start, status denied and the request held open: at 200 ms no Permite el micrófono…; at 400 ms it shows in place of Listo; it goes when the request answers',
      (tester) async {
        permissions(tester, granted: () => false);
        final speech = _AskedSpeech()..permissionGate = Completer<void>();
        await _open(
          tester,
          speech,
          _Captures(),
          _OfflineExtraction(),
          language: 'es',
          size: phone,
          open: false,
        );
        unawaited(
          showCaptureSheet(tester.element(find.byType(Scaffold).first)),
        );
        // Up to the request, a frame at a time.
        for (var frame = 0; frame < 200 && !speech.asked; frame++) {
          await tester.pump(const Duration(milliseconds: 5));
        }
        expect(speech.asked, isTrue, reason: 'the start asked for the mic');
        final why = inSheet(find.text(es.captureMicrophoneWhy));
        await tester.pump(const Duration(milliseconds: 200));
        expect(why, findsNothing, reason: '200 ms after the request');
        await tester.pump(const Duration(milliseconds: 200));
        expect(why, findsOneWidget, reason: '400 ms after the request');
        expect(inSheet(find.text(es.done)), findsNothing);
        speech.permissionGate!.complete();
        await tester.pumpAndSettle();
        expect(inSheet(find.text(es.captureMicrophoneWhy)), findsNothing);
        await tester.tap(inSheet(find.widgetWithText(TextButton, es.cancel)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1627: ES, status denied and the bridge answers blocked 100 ms after the request: no frame shows Permite el micrófono…, then the blocked banner and the filled Abrir Ajustes show',
      (tester) async {
        permissions(tester, granted: () => false);
        final speech = _AskedSpeech()
          ..answer = SpeechPermission.blocked
          ..delay = const Duration(milliseconds: 100);
        await _open(
          tester,
          speech,
          _Captures(),
          _OfflineExtraction(),
          language: 'es',
          size: phone,
          open: false,
        );
        unawaited(
          showCaptureSheet(tester.element(find.byType(Scaffold).first)),
        );
        // Every frame from the opening to well past the answer.
        for (var frame = 0; frame < 120; frame++) {
          await tester.pump(const Duration(milliseconds: 8));
          expect(
            find.text(es.captureMicrophoneWhy),
            findsNothing,
            reason: 'frame $frame (${frame * 8} ms)',
          );
        }
        expect(speech.asked, isTrue);
        await tester.pumpAndSettle();
        expect(find.text(es.captureMicrophoneWhy), findsNothing);
        expect(es.captureMicrophoneBlocked, contains('abre Ajustes'));
        expectBlocked(tester, es);
        expect(speech.starts, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1305: ES, after a refusal that isn’t blocked, the neutral banner reads Sin micrófono no puedo escucharte…, and both Empezar a hablar and Escribir show',
      (tester) async {
        final bridge = _Bridge(tester)..permission = 'denied';
        await _open(
          tester,
          bridge.speech,
          _Captures(),
          _OfflineExtraction(),
          language: 'es',
          size: phone,
        );
        expect(bridge.starts, 0);
        expectNeutralBanner(tester, es.captureMicrophone);
        expect(
          inSheet(
            find.widgetWithText(FilledButton, es.captureStartTalking),
          ).hitTestable(),
          findsOneWidget,
        );
        expect(
          inSheet(find.byTooltip(es.captureTypeInstead)).hitTestable(),
          findsOneWidget,
        );
        expect(inSheet(find.text(es.captureMicrophoneBlocked)), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    for (final (name, fail) in <(String, void Function(_OpeningSpeech))>[
      (
        'the language error',
        (speech) => speech.controller.add(
          SpeechEvent(
            speech.run!,
            'error',
            error: CaptureProblem.speechLanguage,
          ),
        ),
      ),
      (
        'speechUnavailable',
        (speech) => speech.controller.add(
          SpeechEvent(
            speech.run!,
            'error',
            error: CaptureProblem.speechUnavailable,
          ),
        ),
      ),
    ]) {
      testWidgets(
        'UX-1306: an on-device start that fails with $name before ready records online at once, with no error line and no tap; a second sheet in the session starts online without trying on-device',
        (tester) async {
          final speech = _OpeningSpeech();
          final recorder = _Recorder();
          final api = _OfflineExtraction();
          await _open(
            tester,
            speech,
            _Captures(),
            api,
            recorder: recorder,
            language: 'es',
            size: phone,
          );
          expect(speech.starts, 1);
          expect(recorder.starts, 0);
          fail(speech);
          await tester.pumpAndSettle();
          expect(recorder.starts, 1, reason: 'online, with no tap');
          expect(
            inSheet(find.textContaining(es.listeningSeconds(''))),
            findsOneWidget,
          );
          expect(inSheet(find.byType(MessageBanner)), findsNothing);
          expect(inSheet(find.text(es.captureCantListen)), findsNothing);
          expect(api.requests, 0, reason: 'nothing sent: no dictation used');
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          if (find.byType(VoiceTaskScreen).evaluate().isNotEmpty) {
            // The recording kept audio: the keep question asks first.
            await tester.tap(find.text(es.discard).last);
            await tester.pumpAndSettle();
          }
          expect(find.byType(VoiceTaskScreen), findsNothing);

          unawaited(
            showCaptureSheet(tester.element(find.byType(Scaffold).first)),
          );
          await tester.pumpAndSettle();
          expect(speech.starts, 1, reason: 'online, not on-device first');
          expect(recorder.starts, 2);
          expect(inSheet(find.byType(MessageBanner)), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-1306: an on-device start that throws before ready goes online too',
      (tester) async {
        final speech = _OpeningSpeech()
          ..startError = PlatformException(code: 'speech_unavailable');
        final recorder = _Recorder();
        await _open(
          tester,
          speech,
          _Captures(),
          _OfflineExtraction(),
          recorder: recorder,
          language: 'es',
          size: phone,
        );
        expect(recorder.starts, 1);
        expect(
          inSheet(find.textContaining(es.listeningSeconds(''))),
          findsOneWidget,
        );
        expect(inSheet(find.byType(MessageBanner)), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1306: with the on-device start and then the online start both failing, one line: Ahora no puedo escucharte en este teléfono. Toca Escribir.',
      (tester) async {
        final speech = _OpeningSpeech();
        final recorder = _Recorder()..startError = StateError('No microphone');
        await _open(
          tester,
          speech,
          _Captures(),
          _OfflineExtraction(),
          recorder: recorder,
          language: 'es',
          size: phone,
        );
        speech.controller.add(
          SpeechEvent(speech.run!, 'error', error: CaptureProblem.speechLanguage),
        );
        await tester.pumpAndSettle();
        expect(recorder.starts, 1);
        expect(inSheet(find.text(es.captureCantListen)), findsOneWidget);
        expect(inSheet(find.byType(MessageBanner)), findsOneWidget);
        expect(
          inSheet(find.byTooltip(es.captureTypeInstead)).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    // ---- P167 · UX-1304 ----

    testWidgets(
      'UX-1304: ES, on-device path, nothing heard for 5 s: Aún no he oído nada…; after words are heard: Sigo escuchando. Toca Listo cuando termines.',
      (tester) async {
        final speech = _Speech();
        await _open(
          tester,
          speech,
          _Captures(),
          _OfflineExtraction(),
          language: 'es',
          size: phone,
        );
        speech.emit('ready');
        await tester.pump();
        for (var second = 0; second < 4; second++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(inSheet(find.text(es.captureNothingHeardYet)), findsNothing);
        await tester.pump(const Duration(seconds: 1));
        expect(inSheet(find.text(es.captureNothingHeardYet)), findsOneWidget);
        expect(inSheet(find.text(es.captureStillListening)), findsNothing);
        speech.emit('segment', text: 'Comprar pan');
        await tester.pump();
        for (var second = 0; second < 5; second++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(inSheet(find.text(es.captureStillListening)), findsOneWidget);
        expect(inSheet(find.text(es.captureNothingHeardYet)), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    /// Every announcement of the countdown, in [l].
    bool countdown(AppLocalizations l, String message) => [
      for (var left = 1; left <= 10; left++) l.captureTimeLeft(left),
    ].contains(message);

    for (final language in ['es', 'ca']) {
      testWidgets(
        'UX-1304: ${language.toUpperCase()}, the countdown counts the seconds left (57 s: 3, 59 s: 1), and TalkBack hears it once between 50 and 60 s',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          final speech = _Speech();
          await _open(
            tester,
            speech,
            _Captures(),
            _OfflineExtraction(),
            language: language,
            size: phone,
          );
          speech.emit('ready');
          speech.emit('segment', text: 'Comprar pan mañana');
          await tester.pump();
          tester.takeAnnouncements();
          final heard = <String>[];
          for (var second = 1; second <= 57; second++) {
            await tester.pump(const Duration(seconds: 1));
            heard.addAll(tester.takeAnnouncements().map((a) => a.message));
          }
          expect(inSheet(find.text(l.captureTimeLeft(3))), findsOneWidget);
          if (language == 'es') {
            expect(l.captureTimeLeft(3), 'Quedan 3 segundos');
          } else {
            expect(l.captureTimeLeft(3), 'Queden 3 segons');
          }
          await tester.pump(const Duration(seconds: 1));
          heard.addAll(tester.takeAnnouncements().map((a) => a.message));
          expect(inSheet(find.text(l.captureTimeLeft(2))), findsOneWidget);
          await tester.pump(const Duration(seconds: 1));
          heard.addAll(tester.takeAnnouncements().map((a) => a.message));
          expect(inSheet(find.text(l.captureTimeLeft(1))), findsOneWidget);
          await tester.pump(const Duration(seconds: 1));
          heard.addAll(tester.takeAnnouncements().map((a) => a.message));
          expect(
            heard.where((message) => countdown(l, message)),
            hasLength(1),
            reason: '$heard',
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-1304: ES, on-device path, 60 s with no words: No te he entendido. Vuelve a intentarlo o escríbelo. shows, and no Listo is announced',
      (tester) async {
        final speech = _Speech();
        final api = _OfflineExtraction();
        await _open(
          tester,
          speech,
          _Captures(),
          api,
          language: 'es',
          size: phone,
        );
        speech.emit('ready');
        await tester.pump();
        tester.takeAnnouncements();
        final heard = <String>[];
        for (var second = 0; second < 60; second++) {
          await tester.pump(const Duration(seconds: 1));
          heard.addAll(tester.takeAnnouncements().map((a) => a.message));
        }
        await tester.pumpAndSettle();
        heard.addAll(tester.takeAnnouncements().map((a) => a.message));
        expect(inSheet(find.text(es.captureNoSpeech)), findsOneWidget);
        expect(heard, isNot(contains(es.done)), reason: '$heard');
        expect(api.requests, 0);
        expect(
          inSheet(find.textContaining(es.listeningSeconds(''))),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1304: ES, online path, while listening: Te escucho. Verás tus palabras al tocar Listo. shows from the start',
      (tester) async {
        final recorder = _Recorder();
        await _open(
          tester,
          _Speech(),
          _Captures(),
          _OfflineExtraction(),
          recorder: recorder,
          language: 'es',
          size: phone,
          speechOnline: true,
        );
        expect(recorder.starts, 1);
        expect(
          inSheet(find.text(es.listeningSeconds('00:00'))),
          findsOneWidget,
        );
        expect(inSheet(find.text(es.captureListeningOnline)), findsOneWidget);
        for (var second = 0; second < 6; second++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(inSheet(find.text(es.captureListeningOnline)), findsOneWidget);
        expect(inSheet(find.text(es.captureNothingHeardYet)), findsNothing);
        expect(inSheet(find.text(es.captureStillListening)), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

/// A recognizer for opening capture: [capabilities] counts the questions,
/// [gate] holds the answer back, [capabilityError] and [startError] fail.
class _OpeningSpeech extends NativeSpeech {
  final controller = StreamController<SpeechEvent>.broadcast(sync: true);
  int capabilities = 0;
  int starts = 0;
  int? run;
  Completer<void>? gate;
  Object? capabilityError;
  Object? startError;

  /// What happened, in order, shared with the store.
  List<String>? log;
  @override
  Future<SpeechCapability> capability({String? language}) async {
    capabilities++;
    await gate?.future;
    final error = capabilityError;
    if (error != null) throw error;
    return const SpeechCapability(
      onDevice: true,
      language: 'es-ES',
      languageInstalled: true,
    );
  }

  @override
  Stream<SpeechEvent> get events => controller.stream;
  @override
  Future<SpeechPermission> permission() async => SpeechPermission.granted;
  @override
  Future<void> start(
    int id,
    String language, {
    List<String> hints = const [],
  }) async {
    starts++;
    run = id;
    log?.add('start');
    final error = startError;
    if (error != null) throw error;
  }

  void emit(String kind, {String? text}) =>
      controller.add(SpeechEvent(run!, kind, text: text));
  @override
  Future<void> stop(int id) async => emit('ended');
  @override
  Future<void> cancel(int id) async {}
}

/// The diagnostics table, in memory: every row recorded.
class _DiagnosticsDatabase extends Fake implements Database {
  final rows = <Map<String, Object?>>[];
  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (table == 'diagnostics') rows.add(values);
    return rows.length;
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async => 0;
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  NativeSpeech speech,
  _Captures store,
  _OfflineExtraction api, {
  _Recorder? recorder,
  String language = 'en',
  bool listen = true,
  Future<void> Function()? beforeCapture,
  List<TaskListInfo>? projects,
  Size size = const Size(390, 844),
  // Opens capture by tapping Calendar's creation button instead.
  bool fromButton = false,
  // Leaves opening capture to the test.
  bool open = true,
  // Voz «En línea, al terminar»: the sheet records and the server listens.
  bool speechOnline = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  final container = ProviderContainer(
    overrides: [
      invitationLinkProvider.overrideWith(
        (ref) => InvitationLinks(listen: false),
      ),
      hasProProvider.overrideWithValue(true),
      authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
      if (recorder != null)
        captureRecorderFactoryProvider.overrideWithValue(() => recorder),
      nativeSpeechProvider.overrideWithValue(speech),
      captureStoreProvider.overrideWithValue(store),
      pendingCapturesProvider.overrideWith((ref) async => []),
      apiClientProvider.overrideWithValue(api),
      taskRepositoryProvider.overrideWithValue(MemoryTasks()),
      taskProvider.overrideWith((ref) => DesignTaskNotifier()),
      if (projects != null)
        taskListsProvider.overrideWith((ref) async => projects),
      themeStoreProvider.overrideWithValue(MemoryThemeStore()),
      regionalStoreProvider.overrideWithValue(
        MemoryRegionalStore(
          RegionalPreferences(
            language: language,
            clock: ClockFormat.twentyFour,
            weekStart: 1,
            speechOnline: speechOnline,
          ),
        ),
      ),
    ],
  );
  addTearDown(() {
    container.dispose();
    api.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
  await tester.pumpAndSettle();
  await beforeCapture?.call();
  if (!open) return container;
  if (fromButton) {
    final l = lookupAppLocalizations(Locale(language));
    await tester.tap(find.text(l.addTask).hitTestable());
  } else {
    unawaited(
      showCaptureSheet(
        tester.element(find.byType(Scaffold).first),
        startListening: listen,
      ),
    );
  }
  await tester.pumpAndSettle();
  return container;
}

class _Speech extends NativeSpeech {
  final controller = StreamController<SpeechEvent>.broadcast(sync: true);
  int? run;
  bool allowed = true;
  bool installed = true;
  bool cancelled = false;
  String? text;

  /// The microphone answer, when it isn't simply [allowed].
  SpeechPermission? answer;

  /// Holds the permission answer back, like the system dialog does.
  Completer<void>? permissionGate;
  int starts = 0;
  int stops = 0;
  @override
  Future<SpeechCapability> capability({String? language}) async =>
      SpeechCapability(
        onDevice: true,
        language: 'en-US',
        languageInstalled: installed,
      );
  @override
  Stream<SpeechEvent> get events => controller.stream;
  @override
  Future<SpeechPermission> permission() async {
    await permissionGate?.future;
    return answer ??
        (allowed ? SpeechPermission.granted : SpeechPermission.denied);
  }

  @override
  Future<void> start(
    int id,
    String language, {
    List<String> hints = const [],
  }) async {
    starts++;
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
    stops++;
    emit('ended');
  }

  @override
  Future<void> cancel(int id) async {
    cancelled = true;
  }
}

class _Captures extends CaptureStore {
  _Captures({TaskDatabase? database}) : super(database ?? TaskDatabase());
  CaptureSession? session;
  bool failWrites = false;

  /// The leftover sweep: how long it takes, or what it throws.
  Duration? cleanDelay;
  Object? cleanError;

  /// What happened, in order, shared with the recognizer.
  List<String>? log;
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
  }) async => session = CaptureSession(
    language: language,
    id: 'test-capture',
    projectId: projectId,
    source: source,
    day: day,
    kind: kind,
    ownerKey: ownerKey,
    timezone: timezone,
    capturedAt: (now ?? DateTime.now()).toUtc(),
    audioPath: audio ? '/synthetic/capture.wav' : null,
    text: text,
  );
  @override
  Future<void> update(CaptureSession value) async {
    if (failWrites) throw StateError('Synthetic storage failure');
    session = value;
  }

  @override
  Future<CaptureSession?> read(String id, String ownerKey) async =>
      session?.id == id && session?.ownerKey == ownerKey ? session : null;
  @override
  Future<void> cleanFinished(String ownerKey) async {
    log?.add('clean');
    final delay = cleanDelay;
    if (delay != null) await Future<void>.delayed(delay);
    final error = cleanError;
    if (error != null) throw error;
  }

  @override
  Future<String> audioPathForId(String id) async => '/synthetic/capture.wav';

  /// Audio files dropped because no audio arrived.
  final removedAudio = <String>[];
  @override
  Future<void> removeAudioFile(String id) async => removedAudio.add(id);

  /// Ids discarded through the store, as Descartar does.
  final discarded = <String>[];
  @override
  Future<void> discard(String id, String ownerKey) async {
    discarded.add(id);
    if (session?.id == id) session = session!.copyWith(status: 'discarded');
  }
}

class _OfflineExtraction extends OfflineApiClient {
  int requests = 0;

  /// The fields of each capture request.
  final sent = <Map<String, dynamic>>[];
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
      sent.add({...?data});
    }
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

  /// Recordings started, and what a start throws, if anything.
  int starts = 0;
  Object? startError;
  @override
  Stream<RecordState> onStateChanged() => states.stream;
  @override
  Future<bool> hasPermission({bool request = true}) async => true;
  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    starts++;
    final error = startError;
    if (error != null) throw error;
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

/// The real [NativeSpeech] over mocked platform channels: the method channel
/// answers like the Android bridge, and events arrive through the event
/// channel as maps, exactly as NativeSpeechBridge.kt sends them.
class _Bridge {
  _Bridge(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_methods, (call) async {
      final arguments = call.arguments;
      switch (call.method) {
        case 'capability':
          capabilities++;
          final answer = capability;
          if (answer != null) return answer();
          return {
            'onDevice': true,
            'language': 'es-ES',
            'languageInstalled': true,
          };
        case 'permission':
          return permission;
        case 'start':
          run = (arguments as Map)['run'] as int;
          hints = List<String>.from(arguments['hints'] as List? ?? const []);
          starts++;
          return null;
        case 'stop':
          stops++;
          send('ended');
          return null;
        case 'cancel':
          cancels++;
          send('ended');
          return null;
      }
      return null;
    });
    messenger.setMockStreamHandler(
      _events,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          _sink = sink;
        },
        onCancel: (arguments) {
          _sink = null;
        },
      ),
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(_methods, null);
      messenger.setMockStreamHandler(_events, null);
    });
  }

  static const _methods = MethodChannel('taskflow/speech-test-bridge');
  static const _events = EventChannel('taskflow/speech-test-bridge/events');
  final speech = NativeSpeech(channel: _methods, eventChannel: _events);
  MockStreamHandlerEventSink? _sink;
  Object permission = 'granted';

  /// Answers `capability` instead of the bridge's usual on-device answer.
  Future<Object?> Function()? capability;
  int capabilities = 0;
  int? run;

  /// The speech hints the last `start` call carried.
  List<String> hints = const [];
  int starts = 0;
  int stops = 0;
  int cancels = 0;

  void send(String kind, {String? text}) => _sink?.success({
    'run': run,
    'kind': kind,
    if (text != null) 'text': text,
  });
}

/// [_Speech] that notes when the start asks for the microphone, and can
/// answer [delay] later, as the bridge does for a blocked microphone.
class _AskedSpeech extends _Speech {
  bool asked = false;
  Duration? delay;
  @override
  Future<SpeechPermission> permission() async {
    asked = true;
    final wait = delay;
    if (wait != null) await Future<void>.delayed(wait);
    return super.permission();
  }
}
