// P60 (UX-456, UX-457, UX-458): the capture result has a visible Cancelar,
// `Volver a decirlo` no longer throws the result away, and TalkBack hears
// which line is the date.
import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
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
import 'package:agenda/widgets/app_components.dart' show MessageBanner;
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/capture_fixtures.dart' show SilentRecorder;
import 'support/design_fixtures.dart';

final es = lookupAppLocalizations(const Locale('es'));
final ca = lookupAppLocalizations(const Locale('ca'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  const timezone = MethodChannel('flutter_timezone');
  setUp(() {
    platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
    platform.setMockMethodCallHandler(timezone, (_) async => 'Europe/Madrid');
  });
  tearDown(() {
    platform.setMockMethodCallHandler(timeoutChannel, null);
    platform.setMockMethodCallHandler(timezone, null);
  });

  Finder title() => find.byKey(const ValueKey('task-title'));
  String titleText(WidgetTester tester) =>
      tester.widget<TextFormField>(title()).controller!.text;
  Finder resultButton(String label) => find.descendant(
    of: find.byType(CaptureResult),
    matching: find.widgetWithText(TextButton, label),
  );

  testWidgets(
    'UX-456: after Volver a decirlo, Cancelar while listening brings back the same result with its edits, asks nothing, and leaves only the original pending',
    (tester) async {
      final app = await _App.open(tester);
      app.api.found = [_found('Comprar pan')];
      await app.speak(tester, 'Comprar pan');
      expect(find.byType(CaptureResult), findsOneWidget);
      final original = app.store.pendingIds.single;
      await tester.enterText(title(), 'Comprar pan integral');
      await tester.pumpAndSettle();

      await tester.tap(resultButton(es.captureSayAgain));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureResult), findsNothing);
      expect(app.speech.starts, 2, reason: 'listening again');
      // Something is heard before changing one's mind.
      app.speech.send('ready');
      app.speech.send('segment', text: 'Comprar leche');
      await tester.pumpAndSettle();
      expect(find.text('Comprar leche'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, es.cancel));
      await tester.pumpAndSettle();
      expect(find.text(es.captureKeepQuestion), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(titleText(tester), 'Comprar pan integral');
      expect(app.store.pendingIds, [original]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-456: after Volver a decirlo, new words that are understood replace the result, and the previous capture leaves the pending list',
    (tester) async {
      final app = await _App.open(tester);
      app.api.found = [_found('Comprar pan')];
      await app.speak(tester, 'Comprar pan');
      final original = app.store.pendingIds.single;
      // Still pending while listening again: a mis-tap loses nothing.
      await tester.tap(resultButton(es.captureSayAgain));
      await tester.pumpAndSettle();
      expect(app.store.pendingIds, contains(original));

      app.api.found = [_found('Comprar leche')];
      app.speech.send('ready');
      app.speech.send('segment', text: 'Comprar leche');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, es.done));
      await tester.pumpAndSettle();

      expect(find.byType(CaptureResult), findsOneWidget);
      expect(titleText(tester), 'Comprar leche');
      expect(app.store.pendingIds, hasLength(1));
      expect(app.store.pendingIds.single, isNot(original));
      expect(app.store.sessions[original]!.status, 'discarded');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-457: the result shows Cancelar; it closes the sheet with no dialog and the capture stays pending',
    (tester) async {
      final app = await _App.open(tester);
      app.api.found = [_found('Comprar pan')];
      await app.speak(tester, 'Comprar pan');
      expect(es.cancel, 'Cancelar');
      final cancel = resultButton(es.cancel);
      expect(cancel.hitTestable(), findsOneWidget);
      final id = app.store.pendingIds.single;
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CaptureResult), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(app.store.pendingIds, [id]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('UX-457: a typed result shows Cancelar and no Volver a decirlo', (
    tester,
  ) async {
    final app = await _App.open(tester);
    app.api.found = [_found('Comprar pan')];
    await app.type(tester, 'Comprar pan');
    expect(find.byType(CaptureResult), findsOneWidget);
    expect(resultButton(es.cancel).hitTestable(), findsOneWidget);
    expect(find.text(es.captureSayAgain), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (language, l) in [('es', es), ('ca', ca)]) {
    testWidgets(
      'UX-456 / UX-457: at 2× text on 360×740 ($language), ${l.cancel} and ${l.captureSayAgain} are both reachable, nothing overflows, and they sit at least 12 dp under the add button',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final app = await _App.open(
          tester,
          language: language,
          size: const Size(360, 740),
        );
        await app.openResult(
          tester,
          _spoken(app, 'Comprar pan', DateTime.now()),
        );
        expect(find.byType(CaptureResult), findsOneWidget);
        expect(l.cancel, language == 'es' ? 'Cancelar' : 'Cancel·la');
        expect(
          l.captureSayAgain,
          language == 'es' ? 'Volver a decirlo' : 'Torna-ho a dir',
        );
        final cancel = resultButton(l.cancel);
        final again = resultButton(l.captureSayAgain);
        expect(cancel.hitTestable(), findsOneWidget);
        expect(again.hitTestable(), findsOneWidget);
        final save = tester.getRect(find.byKey(const ValueKey('save-drafts')));
        final below = [
          tester.getRect(cancel),
          tester.getRect(again),
        ].where((rect) => rect.top >= save.top).toList();
        expect(below, hasLength(2), reason: 'both are under the add button');
        final nearest = below
            .map((rect) => rect.top)
            .reduce((a, b) => a < b ? a : b);
        expect(nearest - save.bottom, greaterThanOrEqualTo(12));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-458: TalkBack reads the result’s date line as Fecha y hora: Hoy, and its tap opens the date sheet',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final app = await _App.open(tester);
      final now = DateTime.now();
      await app.openResult(
        tester,
        _spoken(app, 'Comprar pan', DateTime(now.year, now.month, now.day)),
      );
      expect(es.reviewSchedule, 'Fecha y hora');
      final label = '${es.reviewSchedule}: ${es.today}';
      expect(label, 'Fecha y hora: Hoy');
      final node = find.semantics.byLabel(label);
      expect(node, findsOne);
      expect(
        node.evaluate().single.getSemanticsData().hasAction(
          SemanticsAction.tap,
        ),
        isTrue,
      );
      expect(
        node.evaluate().single.getSemanticsData().flagsCollection.isButton,
        isTrue,
      );
      tester.semantics.tap(node);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-done')), findsOneWidget);
      semantics.dispose();
    },
  );

  // ---- P63 (UX-461, UX-462): Cancel while the words said again are
  // understood brings the result back; the date line is disabled while
  // saving ----

  /// Frames while `Entendiendo…` spins (it never settles).
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// A spoken result edited to `Comprar pan integral`, then `Volver a
  /// decirlo`, `Comprar leche` heard and `Listo`, with understanding held
  /// until the test releases it. Returns the original capture's id.
  Future<(_App, String)> sayAgainHeld(WidgetTester tester) async {
    final app = await _App.open(tester);
    app.api.found = [_found('Comprar pan')];
    await app.speak(tester, 'Comprar pan');
    final original = app.store.pendingIds.single;
    await tester.enterText(title(), 'Comprar pan integral');
    await tester.pumpAndSettle();
    await tester.tap(resultButton(es.captureSayAgain));
    await tester.pumpAndSettle();
    app.api.found = [_found('Comprar leche')];
    app.api.hold = Completer<void>();
    app.speech.send('ready');
    app.speech.send('segment', text: 'Comprar leche');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, es.done));
    await frames(tester);
    expect(es.captureUnderstanding, 'Entendiendo…');
    expect(find.text(es.captureUnderstanding), findsOneWidget);
    expect(find.byType(CaptureResult), findsNothing);
    return (app, original);
  }

  /// The previous result is back, with its edit, and nothing asks.
  void expectPreviousBack(WidgetTester tester) {
    expect(find.text(es.captureKeepQuestion), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(CaptureResult), findsOneWidget);
    expect(find.text(es.captureUnderstanding), findsNothing);
    expect(titleText(tester), 'Comprar pan integral');
  }

  /// Understanding ended: the result is unchanged, no problem shows, and only
  /// the original capture is pending.
  void expectOnlyOriginal(WidgetTester tester, _App app, String original) {
    expect(find.byType(CaptureResult), findsOneWidget);
    expect(titleText(tester), 'Comprar pan integral');
    expect(find.text('Comprar leche'), findsNothing);
    expect(find.byType(MessageBanner), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(app.store.pendingIds, [original]);
    final others = app.store.sessions.values.where((s) => s.id != original);
    expect(others, isNotEmpty, reason: 'the words said again had a capture');
    expect(others.every((s) => s.status == 'discarded'), isTrue);
  }

  testWidgets(
    'UX-461: after Volver a decirlo and Listo, Cancelar during Entendiendo… brings the edited result back at once, asks nothing, and only the original stays pending',
    (tester) async {
      final (app, original) = await sayAgainHeld(tester);
      await tester.tap(find.widgetWithText(TextButton, es.cancel));
      await tester.pump();
      expectPreviousBack(tester);

      app.api.hold!.complete();
      await tester.pumpAndSettle();
      expectOnlyOriginal(tester, app, original);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-461: after Volver a decirlo and Listo, system Back during Entendiendo… keeps the sheet open with the edited result and only the original pending',
    (tester) async {
      final (app, original) = await sayAgainHeld(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expectPreviousBack(tester);

      app.api.hold!.complete();
      await tester.pumpAndSettle();
      expectOnlyOriginal(tester, app, original);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-461: when understanding the words said again fails after Cancelar, the previous result stays with no error and only the original pending',
    (tester) async {
      final (app, original) = await sayAgainHeld(tester);
      await tester.tap(find.widgetWithText(TextButton, es.cancel));
      await tester.pump();
      expectPreviousBack(tester);

      app.api.hold!.completeError(ApiException(503, 'Service unavailable'));
      await tester.pumpAndSettle();
      expectOnlyOriginal(tester, app, original);
      expect(find.textContaining('Service unavailable'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-461: a first capture’s Cancelar during Entendiendo… still closes the sheet, and the capture is pending once understood',
    (tester) async {
      final app = await _App.open(tester);
      app.api.found = [_found('Comprar pan')];
      app.api.hold = Completer<void>();
      await tester.tap(find.text(es.sayTask).hitTestable());
      await tester.pumpAndSettle();
      app.speech.send('ready');
      app.speech.send('segment', text: 'Comprar pan');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, es.done));
      await frames(tester);
      expect(find.text(es.captureUnderstanding), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, es.cancel));
      await tester.pumpAndSettle();
      expect(find.text(es.captureUnderstanding), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CaptureResult), findsNothing);

      app.api.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CaptureResult), findsNothing);
      final id = app.store.pendingIds.single;
      final kept = app.store.sessions[id]!;
      expect(kept.status, 'ready');
      expect(kept.drafts.single.task.title, 'Comprar pan');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-461: after Volver a decirlo and Listo with no Cancelar, the new result shows once understood and only the new capture stays pending',
    (tester) async {
      final (app, original) = await sayAgainHeld(tester);
      app.api.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(titleText(tester), 'Comprar leche');
      expect(find.byType(MessageBanner), findsNothing);
      expect(app.store.pendingIds, hasLength(1));
      expect(app.store.pendingIds.single, isNot(original));
      expect(app.store.sessions[original]!.status, 'discarded');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-462: while saving, the date line reads Fecha y hora: Hoy, is disabled and has no tap; otherwise it is enabled and its tap opens the date sheet',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final app = await _App.open(tester);
      final now = DateTime.now();
      await app.openResult(
        tester,
        _spoken(app, 'Comprar pan', DateTime(now.year, now.month, now.day)),
      );
      final label = '${es.reviewSchedule}: ${es.today}';
      expect(label, 'Fecha y hora: Hoy');
      SemanticsData data() =>
          find.semantics.byLabel(label).evaluate().single.getSemanticsData();

      expect(find.semantics.byLabel(label), findsOne);
      expect(data().flagsCollection.isEnabled, Tristate.isTrue);
      expect(data().hasAction(SemanticsAction.tap), isTrue);

      app.store.holdSave = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await frames(tester);
      expect(find.semantics.byLabel(label), findsOne);
      expect(data().flagsCollection.isButton, isTrue);
      expect(data().flagsCollection.isEnabled, Tristate.isFalse);
      expect(data().hasAction(SemanticsAction.tap), isFalse);

      // Saving ends (here it fails): the line works again.
      app.store.holdSave!.complete();
      await tester.pumpAndSettle();
      expect(data().flagsCollection.isEnabled, Tristate.isTrue);
      expect(data().hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.tap(find.semantics.byLabel(label));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-done')), findsOneWidget);
      semantics.dispose();
    },
  );
}

Map<String, dynamic> _found(String title) => {
  'title': title,
  'due_date': null,
  'scheduled_date': null,
  'priority': 1,
  'notes': '',
  'questions': [],
};

/// A spoken capture of [title] on [day], already understood.
CaptureSession _spoken(_App app, String title, DateTime? day) => CaptureSession(
  id: 'stored',
  ownerKey: app.container.read(captureOwnerProvider),
  timezone: 'Europe/Madrid',
  capturedAt: DateTime.now().toUtc(),
  status: 'ready',
  source: 'speech',
  transcript: title,
  drafts: [
    CaptureDraft(
      id: 'a',
      task: Task(title: title, priority: 1, dueDate: day, hasTime: false),
    ),
  ],
);

/// The app with a 24-hour clock, on Calendar, with capture answered by [api]
/// and every capture kept in [store], as the phone's table does.
class _App {
  _App(this.container, this.store, this.api, this.speech);
  final ProviderContainer container;
  final _Captures store;
  final _Api api;
  final _Speech speech;

  static Future<_App> open(
    WidgetTester tester, {
    String language = 'es',
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = _Captures();
    final api = _Api();
    final speech = _Speech();
    final container = ProviderContainer(
      overrides: [
        invitationLinkProvider.overrideWith(
          (ref) => InvitationLinks(listen: false),
        ),
        hasProProvider.overrideWithValue(true),
        authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
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
        captureRecorderFactoryProvider.overrideWithValue(SilentRecorder.new),
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
    return _App(container, store, api, speech);
  }

  /// `Dictar una tarea`, the recognizer hears [words], then `Listo`.
  Future<void> speak(WidgetTester tester, String words) async {
    await tester.tap(find.text(es.sayTask).hitTestable());
    await tester.pumpAndSettle();
    speech.send('ready');
    speech.send('segment', text: words);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, es.done));
    await tester.pumpAndSettle();
  }

  /// `Dictar una tarea`, `Escribir`, [words], then `Listo`.
  Future<void> type(WidgetTester tester, String words) async {
    await tester.tap(find.text(es.sayTask).hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(es.captureTypeInstead));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('capture-words')), words);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, es.done));
    await tester.pumpAndSettle();
  }

  /// Opens the capture sheet on [session]'s result, as resuming it does.
  Future<void> openResult(WidgetTester tester, CaptureSession session) async {
    store.sessions[session.id] = session;
    unawaited(
      showCaptureSheet(
        tester.element(find.byType(Scaffold).first),
        captureId: session.id,
        startListening: false,
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// The assistant: returns [found] for every capture. While [hold] is set,
/// understanding waits for the test to complete it (or fail it).
class _Api extends OfflineApiClient {
  List<Map<String, dynamic>> found = [];
  Completer<void>? hold;
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
    if (!path.startsWith('ai/')) {
      throw ApiException(0, 'Offline. Retry when connected.');
    }
    final gate = hold;
    if (gate != null) await gate.future;
    return {'transcript': data?['text'] ?? '', 'tasks': found};
  }
}

/// Every capture in memory, by id; the pending list is every one not saved
/// or discarded, as the real table's query is.
class _Captures extends CaptureStore {
  _Captures() : super(TaskDatabase());
  final sessions = <String, CaptureSession>{};
  var _next = 0;

  /// While set, `Añadir…` stays saving until the test completes it.
  Completer<void>? holdSave;

  @override
  Future<CaptureSession> saveReady(
    String id,
    String ownerKey,
    Set<String> draftIds,
  ) async {
    final gate = holdSave;
    if (gate == null) return super.saveReady(id, ownerKey, draftIds);
    await gate.future;
    throw StateError('Not saved in this test.');
  }

  List<String> get pendingIds => [
    for (final session in sessions.values)
      if (!session.terminal) session.id,
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
  }) async {
    final session = CaptureSession(
      id: 'capture-${_next++}',
      ownerKey: ownerKey,
      timezone: timezone,
      capturedAt: (now ?? DateTime.now()).toUtc(),
      text: text,
      kind: kind,
      projectId: projectId,
      source: source,
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
  Future<List<CaptureSession>> pending(String ownerKey) async => [
    for (final session in sessions.values)
      if (!session.terminal) session,
  ];
  @override
  Future<void> cleanFinished(String ownerKey) async {}
  @override
  Future<void> discard(String id, String ownerKey) async {
    final session = sessions[id];
    if (session != null) {
      sessions[id] = session.copyWith(status: 'discarded');
    }
  }
}

/// The phone's recognizer: listening until stopped; the test sends what it
/// hears.
class _Speech extends NativeSpeech {
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  int starts = 0;
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
  }) async {
    starts++;
    _run = id;
  }

  void send(String kind, {String? text}) =>
      _events.add(SpeechEvent(_run!, kind, text: text));
  @override
  Future<void> stop(int id) async {
    if (_run != null) send('ended');
  }

  @override
  Future<void> cancel(int id) async {}
}
