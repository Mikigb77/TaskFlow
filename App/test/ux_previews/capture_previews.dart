// The capture sheet in every phase: listening, understanding (and slow),
// errors, the free account's dictations, and its results.
import 'dart:async';

import 'package:agenda/models/capture_command.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'support/app.dart';
import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/preview.dart';

const sheet = Screen(
  'capture',
  'sheet',
  'The capture sheet, opened from Calendar\'s Añadir tarea',
  sources: [
    'lib/screens/voice_task_screen.dart',
    'lib/widgets/task_actions.dart',
    'lib/widgets/app_components.dart',
    'lib/l10n/capture_messages.dart',
    'lib/services/capture_problem.dart',
  ],
);

const result = Screen(
  'capture',
  'result',
  'The capture sheet\'s result: what was understood, ready to add',
  sources: [
    'lib/screens/voice_task_screen.dart',
    'lib/widgets/capture_review_editor.dart',
    'lib/widgets/app_components.dart',
    'lib/l10n/region.dart',
  ],
);

const usedUp = Screen(
  'capture',
  'used-up-notice',
  'Nueva tarea with no free dictations left: the once-a-month notice',
  sources: [
    'lib/widgets/task_form_entry.dart',
    'lib/widgets/task_actions.dart',
  ],
);

/// Spoken words, long enough to wrap: what a person says in one go.
const said =
    'Comprar pan y leche, llamar al médico el viernes a las diez y recoger '
    'a los niños del colegio a las cinco';

/// Opens the sheet from Calendar's Añadir tarea; with the mic it listens.
Future<void> openSheet(PreviewApp app) async {
  await app.tester.tap(find.text(app.p.l.addTask).hitTestable());
  await app.tester.pumpAndSettle();
}

/// The recognizer is ready and hears [words]; [seconds] of listening pass.
Future<void> hear(PreviewApp app, String words, {int seconds = 3}) async {
  app.speech.send('ready');
  await app.tester.pump();
  if (words.isNotEmpty) {
    app.speech.send('segment', text: words);
    await app.tester.pump();
  }
  for (var i = 0; i < seconds; i++) {
    await app.tester.pump(const Duration(seconds: 1));
  }
}

/// `Listo`: listening stops and the words go to the assistant.
Future<void> sendWords(PreviewApp app) async {
  await app.tester.tap(find.widgetWithText(FilledButton, app.p.l.done).first);
  await app.p.frames();
}

/// Says [words] from Calendar and taps `Listo`; the result is in front.
Future<void> speak(PreviewApp app, String words) async {
  await openSheet(app);
  await hear(app, words);
  await sendWords(app);
  await app.tester.pumpAndSettle();
}

/// Opens the sheet, `Escribir`, types [words]; the keyboard goes down.
Future<void> typeWords(PreviewApp app, String words) async {
  await openSheet(app);
  await app.tester.tap(find.byKey(const ValueKey('capture-type-instead')));
  await app.tester.pumpAndSettle();
  await app.tester.enterText(
    find.byKey(const ValueKey('capture-words')),
    words,
  );
  await app.tester.pumpAndSettle();
}

/// Types [words] and taps `Listo`.
Future<void> typeAndSend(PreviewApp app, String words) async {
  await typeWords(app, words);
  FocusManager.instance.primaryFocus?.unfocus();
  await app.tester.pumpAndSettle();
  await app.tester.tap(find.widgetWithText(FilledButton, app.p.l.done).first);
  await app.p.frames();
  await app.tester.pumpAndSettle();
}

/// Opens the sheet on a result, as resuming a capture does.
Future<void> resume(
  PreviewApp app,
  List<CaptureDraft> drafts, {
  List<CaptureCommand> commands = const [],
  String transcript = said,
  String source = 'speech',
}) async {
  final session = CaptureSession(
    id: const Uuid().v4(),
    ownerKey: app.container.read(captureOwnerProvider),
    timezone: 'Europe/Madrid',
    capturedAt: previewNow.toUtc(),
    status: 'ready',
    source: source,
    text: source == 'speech' ? '' : transcript,
    transcript: transcript,
    drafts: drafts,
    commands: commands,
  );
  app.captures.sessions[session.id] = session;
  unawaited(
    showCaptureSheet(app.context, captureId: session.id, startListening: false),
  );
  await app.tester.pumpAndSettle();
}

/// Friday at ten, a weekday away.
DateTime get friday10 => next(DateTime.friday).add(const Duration(hours: 10));

/// Three things said at once, as the assistant returns them.
Map<String, dynamic> threeTasks() => {
  'transcript': said,
  'tasks': [
    serverTask('Comprar pan y leche', date: day(0)),
    serverTask('Llamar al médico', date: friday10, time: true),
    serverTask('Recoger a los niños del colegio', date: day(0, 17), time: true),
  ],
  'commands': [],
};

/// The app's own recorder, listening: the online path's microphone.
class _ListeningRecorder extends Fake implements AudioRecorder {
  final _states = StreamController<RecordState>.broadcast();
  final levels = StreamController<Amplitude>.broadcast();
  var _recording = false;
  @override
  Stream<RecordState> onStateChanged() => _states.stream;
  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) => levels.stream;
  @override
  Future<bool> hasPermission({bool request = true}) async => true;
  @override
  Future<void> start(RecordConfig config, {required String path}) async =>
      _recording = true;
  @override
  Future<bool> isRecording() async => _recording;
  @override
  Future<bool> isPaused() async => false;
  @override
  Future<String?> stop() async {
    _recording = false;
    return null;
  }

  @override
  Future<void> dispose() async {
    await _states.close();
    await levels.close();
  }
}

/// Captures whose recordings go nowhere: no files in a preview.
class _RecordingCaptures extends PreviewCaptures {
  _RecordingCaptures() : super(PreviewTasks(normalDay()));
  @override
  Future<String> audioPathForId(String id) async => 'preview-$id.wav';
  @override
  Future<void> removeAudioFile(String id) async {}
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
    final session = await super.create(
      ownerKey,
      timezone,
      text: text,
      now: now,
      kind: kind,
      projectId: projectId,
      source: source,
      day: day,
      id: id,
      language: language,
    );
    if (!audio) return session;
    return sessions[session.id] = session.copyWith(
      audioPath: await audioPathForId(session.id),
    );
  }
}

void capturePreviews() {
  previewArea('capture', 'Capture sheet', () {
    // ---------------------------------------------------------- listening
    preview(
      sheet,
      'listening',
      'Listening with live words, 3 s in; Pro account.',
      [...mainScreen, ...longText, es1Wide],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await openSheet(app);
        await hear(app, said);
        await p.shoot();
      },
    );

    preview(
      sheet,
      'listening-first-use',
      'The first time the microphone is used on this phone: the privacy line under the words.',
      [es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          privacyShown: false,
        );
        await openSheet(app);
        await hear(app, 'Comprar pan mañana por la mañana');
        await p.shoot();
      },
    );

    preview(
      sheet,
      'listening-quiet',
      'Listening, nothing heard for 6 s: the nothing-heard-yet hint, naming Escribir; Listo is off until there are words.',
      [es2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await openSheet(app);
        await hear(app, '', seconds: 6);
        await p.shoot();
      },
    );

    preview(
      sheet,
      'listening-time-left',
      'Listening 51 s in: the countdown reads 9 seconds left before it stops by itself.',
      [es2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await openSheet(app);
        await hear(app, said, seconds: 51);
        await p.shoot();
      },
    );

    preview(
      sheet,
      'paused',
      'Listening interrupted by leaving the app: the words are kept, with Seguir.',
      [es2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await openSheet(app);
        await hear(app, said);
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          p.tester.binding.handleAppLifecycleStateChanged(state);
        }
        await p.tester.pumpAndSettle();
        for (final state in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          p.tester.binding.handleAppLifecycleStateChanged(state);
        }
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      sheet,
      'listening-free',
      'A free account with 5 dictations left: listening, with Rellenar a mano instead of the keyboard.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(
          p,
          pro: false,
          freeLeft: 5,
          tasks: normalDay(),
        );
        await openSheet(app);
        await hear(app, 'Llamar a la farmacia');
        await p.shoot();
      },
    );

    preview(
      sheet,
      'listening-online',
      'Listening online (the phone has no speech for the language), 7 s in, after speech-level sound: no words show, the hint says what Listo brings, and Escribir is still there.',
      [es1, ca2],
      (p) async {
        final recorder = _ListeningRecorder();
        await PreviewApp.open(
          p,
          tasks: normalDay(),
          speechInstalled: false,
          overrides: [
            captureRecorderFactoryProvider.overrideWithValue(() => recorder),
            captureStoreProvider.overrideWithValue(_RecordingCaptures()),
          ],
        );
        await p.tester.tap(find.text(p.l.addTask).hitTestable());
        await p.frames();
        for (var i = 0; i < 7; i++) {
          recorder.levels.add(Amplitude(current: -20, max: 0));
          await p.tester.pump(const Duration(seconds: 1));
        }
        await p.shoot();
      },
    );

    preview(
      sheet,
      'keep-question',
      'Cancelar with words heard: keep them for later, or discard.',
      [es2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await openSheet(app);
        await hear(app, said);
        await p.tester.tap(find.widgetWithText(TextButton, p.l.cancel));
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      sheet,
      'mic-asking',
      'The first start, Android’s microphone question open (drawn by Android over the sheet, not here): why it asks, in place of Listo.',
      [es1, es2, ca1, ca2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        // Not allowed yet, as permission_handler reads it.
        const permissions = MethodChannel(
          'flutter.baseflow.com/permissions/methods',
        );
        final messenger = p.tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          permissions,
          (call) async => call.method == 'checkPermissionStatus' ? 0 : null,
        );
        final question = app.speech.asking = Completer<SpeechPermission>();
        p.onTearDown(() async {
          if (!question.isCompleted) question.complete(SpeechPermission.denied);
          messenger.setMockMethodCallHandler(permissions, null);
        });
        await openSheet(app);
        // The line waits 300 ms, so a blocked answer never flashes it.
        await p.tester.pump(const Duration(milliseconds: 350));
        await p.shoot();
      },
    );

    preview(
      sheet,
      'mic-denied',
      'The microphone refused once (Android can still ask): the neutral message, Empezar a hablar and Escribir.',
      [es1, es2, ca1, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          mic: SpeechPermission.denied,
        );
        await openSheet(app);
        await p.shoot();
      },
    );

    preview(
      sheet,
      'mic-blocked',
      'The microphone permission is blocked, on-device speech: the steps in Settings, Abrir Ajustes filled, and typing still possible.',
      [es1, es2, ca1, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          mic: SpeechPermission.blocked,
        );
        await openSheet(app);
        await p.shoot();
      },
    );

    preview(
      sheet,
      'mic-blocked-online',
      'The microphone permission is blocked, listening online (the phone has no speech for the language): the same steps and Abrir Ajustes.',
      [es1, es2, ca1, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          mic: SpeechPermission.blocked,
          speechInstalled: false,
        );
        await openSheet(app);
        await p.shoot();
      },
    );

    preview(
      sheet,
      'typing',
      'Escribir: typed words, with the keyboard up.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await typeWords(app, 'Llamar al médico el viernes a las diez');
        await p.showKeyboard();
        await p.shoot();
      },
    );

    // ------------------------------------------------------ understanding
    preview(
      sheet,
      'understanding',
      'Listo tapped: the assistant is working on the words (2 s in).',
      [es1, es2, esDark, es1Wide],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        app.api.hold = Completer<void>();
        await openSheet(app);
        await hear(app, said);
        await sendWords(app);
        await p.frames(20, const Duration(milliseconds: 100));
        await p.shoot();
      },
    );

    preview(
      sheet,
      'understanding-slow',
      'The assistant has taken 10 s: the slow line, with Guardar como tarea as a text button under it and no filled button.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        app.api.hold = Completer<void>();
        await openSheet(app);
        await hear(app, said);
        await sendWords(app);
        for (var i = 0; i < 10; i++) {
          await p.tester.pump(const Duration(seconds: 1));
        }
        await p.shoot();
      },
    );

    // ------------------------------------------------------------- errors
    preview(
      sheet,
      'error-offline',
      'Typed words sent with no connection: the reason, naming Guardar como tarea, whole above the words; Reintentar and Guardar como tarea.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        app.api.failure = ApiException(0, 'Offline. Retry when connected.');
        await typeAndSend(app, 'Llamar al médico el viernes a las diez');
        await p.shoot();
      },
    );

    preview(
      sheet,
      'error-unavailable',
      'Spoken words, and the server that understands them fails (503): they can\'t become tasks now, and are kept.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        app.api.failure = ApiException(503, 'Service unavailable');
        await speak(app, said);
        await p.shoot();
      },
    );

    preview(
      sheet,
      'error-limit-recording',
      'A recording with no words (online speech) refused by today\'s dictation limit (429, Retry-After 3600): the recording is kept, and Cerrar is the only button.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        final session = CaptureSession(
          id: const Uuid().v4(),
          ownerKey: app.container.read(captureOwnerProvider),
          timezone: 'Europe/Madrid',
          capturedAt: previewNow.toUtc(),
          audioPath: 'preview-recording.wav',
          status: 'editing',
          source: 'speech',
        );
        app.captures.sessions[session.id] = session;
        app.api.failure = ApiException(
          429,
          'Daily limit reached.',
          null,
          const Duration(seconds: 3600),
        );
        unawaited(
          showCaptureSheet(
            app.context,
            captureId: session.id,
            startListening: false,
          ),
        );
        await p.tester.pumpAndSettle();
        await sendWords(app);
        // Sending a recording reads its file: real time passes for it.
        for (var i = 0; i < 10 && app.api.asked.isEmpty; i++) {
          await p.tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await p.tester.pump();
        }
        await p.tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      sheet,
      'error-offline-recording',
      'A recording with no words (online speech) sent with no connection: the recording is kept, and the reason names no Guardar como tarea.',
      [es2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        final session = CaptureSession(
          id: const Uuid().v4(),
          ownerKey: app.container.read(captureOwnerProvider),
          timezone: 'Europe/Madrid',
          capturedAt: previewNow.toUtc(),
          audioPath: 'preview-recording.wav',
          status: 'editing',
          source: 'speech',
        );
        app.captures.sessions[session.id] = session;
        app.api.failure = ApiException(0, 'Offline. Retry when connected.');
        unawaited(
          showCaptureSheet(
            app.context,
            captureId: session.id,
            startListening: false,
          ),
        );
        await p.tester.pumpAndSettle();
        await sendWords(app);
        // Sending a recording reads its file: real time passes for it.
        for (var i = 0; i < 10 && app.api.asked.isEmpty; i++) {
          await p.tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await p.tester.pump();
        }
        await p.tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      sheet,
      'error-limit-typed',
      'Typed words refused by today\'s dictation limit (429, Retry-After 3600): the reason, naming Guardar como tarea, whole above the words, which scroll alone; Reintentar and Guardar como tarea.',
      [ca2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        app.api.failure = ApiException(
          429,
          'Daily limit reached.',
          null,
          const Duration(seconds: 3600),
        );
        await typeAndSend(app, 'Llamar al médico el viernes a las diez');
        await p.shoot();
      },
    );

    preview(
      sheet,
      'error-nothing-understood',
      'The assistant found no task in the spoken words: the example, Volver a decirlo filled, Guardar como tarea under it, no Reintentar.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        app.api.answer = {
          'transcript': 'Bueno, a ver, no sé',
          'tasks': [],
          'commands': [],
        };
        await speak(app, 'Bueno, a ver, no sé');
        await p.shoot();
      },
    );

    // ------------------------------------------------------------- result
    preview(
      result,
      'one-task',
      'One task said with a day and a time: Añadir al calendario.',
      [es1, es2, esDark, es1Wide],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        app.api.answer = {
          'transcript': 'Llamar al médico el viernes a las diez',
          'tasks': [serverTask('Llamar al médico', date: friday10, time: true)],
          'commands': [],
        };
        await speak(app, 'Llamar al médico el viernes a las diez');
        await p.shoot();
      },
    );

    preview(
      result,
      'several',
      'Three things said at once, each with its day; one button adds them.',
      [...mainScreen, ...longText, es1Wide],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        app.api.answer = threeTasks();
        await speak(app, said);
        await p.shoot();
      },
    );

    preview(
      result,
      'several-open',
      'Three things, the first one opened to edit its title and day.',
      [es2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        app.api.answer = threeTasks();
        await speak(app, said);
        await p.tester.tap(find.text('Comprar pan y leche'));
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      result,
      'question',
      'The assistant asks: five in the morning or in the afternoon? Nothing is added until it\'s answered.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        // The assistant asks in the person's language.
        final question = switch (p.variant.lang) {
          'ca' => 'A les 5 del matí o de la tarda?',
          'en' => 'At 5 in the morning or in the afternoon?',
          _ => '¿A las 5 de la mañana o de la tarde?',
        };
        app.api.answer = {
          'transcript': 'Recoger el coche del taller el jueves a las cinco',
          'tasks': [
            // The server sends the day and no time when it asks which.
            serverTask(
              'Recoger el coche del taller',
              date: next(DateTime.thursday),
              questions: [question],
              clarifications: [
                {
                  'field': 'schedule',
                  'question': question,
                  'times': ['05:00', '17:00'],
                },
              ],
            ),
          ],
          'commands': [],
        };
        await speak(app, 'Recoger el coche del taller el jueves a las cinco');
        await p.shoot();
      },
    );

    preview(
      result,
      'no-date',
      'One task said without a day: it goes in with no date.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        app.api.answer = {
          'transcript': 'Comprar pilas para el mando',
          'tasks': [serverTask('Comprar pilas para el mando')],
          'commands': [],
        };
        await speak(app, 'Comprar pilas para el mando');
        await p.shoot();
      },
    );

    preview(
      result,
      'more-no-day',
      'One task said without a day, Más opciones open: the repeat row asks for a day, with a chevron; it opens the date sheet.',
      [es1, ca2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        app.api.answer = {
          'transcript': 'Comprar pilas para el mando',
          'tasks': [serverTask('Comprar pilas para el mando')],
          'commands': [],
        };
        await speak(app, 'Comprar pilas para el mando');
        await p.tester.tap(find.text(p.l.reviewOptions).hitTestable());
        await p.tester.pumpAndSettle();
        // «Más opciones» at the top, then just enough to show the row.
        await p.tester.ensureVisible(find.text(p.l.reviewOptions));
        await p.tester.pumpAndSettle();
        await Scrollable.ensureVisible(
          p.tester.element(find.text(p.l.repeatNeedsDate)),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      result,
      'free-3-left',
      'A free account\'s dictation: the result says 3 free dictations are left this month.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(
          p,
          pro: false,
          freeLeft: 3,
          tasks: normalDay(),
        );
        app.api.answer = {
          'transcript': 'Llamar al médico el viernes a las diez',
          'tasks': [serverTask('Llamar al médico', date: friday10, time: true)],
          'commands': [],
        };
        await speak(app, 'Llamar al médico el viernes a las diez');
        await p.shoot();
      },
    );

    preview(
      result,
      'free-1-left',
      'A free account with one dictation left after this one.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          pro: false,
          freeLeft: 1,
          tasks: normalDay(),
        );
        app.api.answer = {
          'transcript': 'Comprar pan mañana',
          'tasks': [serverTask('Comprar pan', date: day(1))],
          'commands': [],
        };
        await speak(app, 'Comprar pan mañana');
        await p.shoot();
      },
    );

    preview(
      result,
      'free-0-left',
      'A free account\'s last dictation of the month: none left, so no Volver a decirlo.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(
          p,
          pro: false,
          freeLeft: 0,
          tasks: normalDay(),
        );
        await resume(app, [
          draft('Llamar al médico', date: friday10, time: true),
        ], transcript: 'Llamar al médico el viernes a las diez');
        await p.shoot();
      },
    );

    // ------------------------------------------------- free dictations used
    preview(
      usedUp,
      'notice',
      'No free dictations left this month: Nueva tarea first says why, once, and offers the form or Pro.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          pro: false,
          freeLeft: 0,
          tasks: normalDay(),
        );
        await app.tap(p.l.newTask);
        await p.shoot();
      },
    );
  });
}
