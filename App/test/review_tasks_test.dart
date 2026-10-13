import 'package:agenda/main.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/screens/review_tasks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:record/record.dart';
import 'dart:async';

TaskDraft draft(String title, {bool ambiguous = false}) => TaskDraft.fromJson({
  'title': title,
  'due_date': null,
  'scheduled_date': title == 'Pay invoice' ? '2026-09-25' : null,
  'priority': 1,
  'notes': '',
  'transcript': 'Buy coffee. Pay invoice Friday.',
  'questions': ambiguous ? ['Morning or afternoon?'] : [],
});

Future<ProviderContainer> openReview(
  WidgetTester tester,
  List<TaskDraft> drafts, {
  GlobalKey? preview,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = designContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(key: preview, child: const MyApp()),
    ),
  );
  await tester.pumpAndSettle();
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .push(
        MaterialPageRoute<void>(
          builder: (_) => ReviewTasksScreen(
            drafts: drafts,
            transcript: 'Buy coffee. Pay invoice Friday.',
          ),
        ),
      );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets(
    'single and batch review keep the save action visible in both appearances',
    (tester) async {
      for (final batch in [false, true]) {
        final preview = GlobalKey();
        final container = await openReview(tester, [
          TaskDraft.fromJson({
            'title': 'Comprobar el funcionamiento de la app',
            'scheduled_date': '2026-10-13',
            'notes':
                'Verificar que funciona con las funcionalidades actuales, sin añadir funciones nuevas.',
            'priority': 1,
            'questions': [],
            'transcript': 'Necesito comprobar que la app funcione.',
          }),
          if (batch) draft('Enviar los resultados a José'),
        ], preview: preview);
        await container
            .read(regionalProvider.notifier)
            .set(const RegionalPreferences(language: 'es'));
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          await setAppearance(container, mode);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('save-drafts')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('WRITE_REVIEW_PREVIEWS')) {
            final boundary =
                preview.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              await File(
                'build/review-${batch ? 'batch' : 'direct'}-${mode.name}.png',
              ).writeAsBytes(bytes.buffer.asUint8List());
              image.dispose();
            });
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
  testWidgets(
    'one task has editable title and notes with optional controls folded away',
    (tester) async {
      final container = await openReview(tester, [
        draft('Revisar la aplicación'),
      ]);
      expect(find.byKey(const ValueKey('task-title')), findsOneWidget);
      expect(find.byKey(const ValueKey('draft-notes')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Comprobar la aplicación',
      );
      await tester.enterText(
        find.byKey(const ValueKey('draft-notes')),
        'Probar con José · demà 🗓️',
      );
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      final saved = container.read(taskProvider).requireValue.last;
      expect(saved.title, 'Comprobar la aplicación');
      expect(saved.notes, 'Probar con José · demà 🗓️');
      expect(saved.dueDate, isNull);
    },
  );

  testWidgets(
    'batch cards expand one editor and save title edits without extra dialogs',
    (tester) async {
      final container = await openReview(tester, [
        draft('Buy coffee'),
        draft('Pay invoice'),
      ]);
      expect(find.byKey(const ValueKey('task-title')), findsNothing);
      await tester.tap(find.byTooltip('Edit Buy coffee'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Buy decaf',
      );
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      final tasks = container.read(taskProvider).requireValue;
      expect(tasks.length, 6);
      expect(tasks.singleWhere((t) => t.title == 'Buy decaf').dueDate, isNull);
      expect(
        tasks.singleWhere((t) => t.title == 'Pay invoice').hasTime,
        isFalse,
      );
    },
  );

  testWidgets('identical questions resolve only the chosen field', (
    tester,
  ) async {
    final container = await openReview(tester, [
      TaskDraft.fromJson({
        'title': 'Doctor',
        'scheduled_date': '2026-10-13',
        'priority': 3,
        'notes': 'Bring test results',
        'transcript': 'Doctor tomorrow at five',
        'questions': ['Please check this detail'],
        'clarifications': [
          {
            'field': 'schedule',
            'question': 'Please check this detail',
            'times': ['05:00', '17:00'],
          },
          {
            'field': 'duration',
            'question': 'Please check this detail',
            'times': [],
          },
        ],
      }),
    ]);
    await tester.ensureVisible(find.text('17:00'));
    await tester.tap(find.text('17:00'));
    await tester.pumpAndSettle();
    expect(find.text('Please check this detail'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('save-drafts')))
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Keep this detail as shown'));
    await tester.tap(find.text('Keep this detail as shown'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await tester.pumpAndSettle();
    final saved = container.read(taskProvider).requireValue.last;
    expect(saved.dueDate, DateTime(2026, 10, 13, 17));
    expect(saved.hasTime, true);
    expect(saved.notes, 'Bring test results');
  });

  testWidgets(
    'ready tasks save while uncertain drafts stay without duplicating saved tasks',
    (tester) async {
      final container = await openReview(tester, [
        draft('Call', ambiguous: true),
        draft('Coffee'),
      ]);
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      expect(container.read(taskProvider).requireValue.length, 5);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save-drafts')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Call Mum',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save-drafts')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Keep this detail as shown'));
      await tester.tap(find.text('Keep this detail as shown'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      expect(container.read(taskProvider).requireValue.length, 6);
      expect(
        container
            .read(taskProvider)
            .requireValue
            .where((t) => t.title == 'Coffee'),
        hasLength(1),
      );
    },
  );

  testWidgets('empty titles cannot save and removing a card offers Undo', (
    tester,
  ) async {
    final container = await openReview(tester, [
      draft('First'),
      draft('Second'),
    ]);
    await tester.tap(find.byTooltip('Edit Second'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Remove Second'));
    await tester.tap(find.byTooltip('Remove Second'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit Second'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Edit First'));
    await tester.tap(find.byTooltip('Edit First'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('task-title')), '   ');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await tester.pumpAndSettle();
    expect(container.read(taskProvider).requireValue.last.title, 'Second');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('save-drafts')))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'Spanish and Catalan retain inline edits, large text and theme changes',
    (tester) async {
      final container = await openReview(tester, [
        draft('Coffee'),
        draft('Call', ambiguous: true),
      ]);
      await tester.tap(find.byTooltip('Edit Coffee'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Café de José',
      );
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final language in ['es', 'ca', 'en']) {
        await container
            .read(regionalProvider.notifier)
            .set(RegionalPreferences(language: language));
        for (final theme in [ThemeMode.light, ThemeMode.dark]) {
          await setAppearance(container, theme);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const ValueKey('draft-notes')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester
                .widget<TextFormField>(find.byKey(const ValueKey('task-title')))
                .controller!
                .text,
            'Café de José',
          );
        }
      }
    },
  );

  testWidgets(
    'existing checklists stay visible in direct review and preserve identity',
    (tester) async {
      final container = await openReview(tester, [
        TaskDraft.fromJson({
          'title': 'Pack',
          'priority': 1,
          'notes': '',
          'transcript': 'Passport and charger',
          'questions': [],
          'checklist': [
            {'id': 'passport', 'title': 'Passport'},
            {'id': 'charger', 'title': 'Charger'},
          ],
        }),
      ]);
      await tester.ensureVisible(find.byTooltip('Edit Passport'));
      await tester.tap(find.byTooltip('Edit Passport'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit step'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('checklist-title')),
        'Renewed passport',
      );
      await tester.tap(find.text('Keep step'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      final saved = container.read(taskProvider).requireValue.last;
      expect(saved.checklist.first.id, 'passport');
      expect(saved.checklist.first.title, 'Renewed passport');
    },
  );


  // P35 / UX-105: the listening sheet in Spanish at 2x text on a 360x740
  // phone. Asserted always; written as a preview with WRITE_REVIEW_PREVIEWS.
  testWidgets(
    'UX-105: the Spanish 2x listening sheet keeps the newest words and Cancelar, Listo and Escribir in view',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      const timezone = MethodChannel('flutter_timezone');
      messenger.setMockMethodCallHandler(timezone, (_) async => 'UTC');
      addTearDown(() => messenger.setMockMethodCallHandler(timezone, null));
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final speech = _PreviewSpeech();
      addTearDown(speech.controller.close);
      final preview = GlobalKey();
      final container = designContainer(
        regionalStore: MemoryRegionalStore(
          const RegionalPreferences(
            language: 'es',
            clock: ClockFormat.twentyFour,
            weekStart: 1,
          ),
        ),
        overrides: [
          nativeSpeechProvider.overrideWithValue(speech),
          captureStoreProvider.overrideWithValue(_ListeningStore()),
          // No microphone plugin: the recognizer does the listening.
          captureRecorderFactoryProvider.overrideWithValue(_SilentRecorder.new),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(key: preview, child: const MyApp()),
        ),
      );
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(const Locale('es'));
      await tester.tap(find.text(l.sayTask).hitTestable());
      await tester.pumpAndSettle();
      expect(speech.starts, 1);
      speech.send('ready');
      await tester.pump();
      const newest = 'y reservar mesa para el sábado por la noche';
      speech.send(
        'segment',
        text:
            'Comprar pan y leche en la tienda de la esquina, llamar al médico '
            'el viernes a las cinco, recoger a los niños del colegio, pagar '
            'la factura de la luz antes del lunes, regar las plantas $newest',
      );
      await tester.pump();
      for (var second = 0; second < 3; second++) {
        await tester.pump(const Duration(seconds: 1));
      }
      const screen = Rect.fromLTWH(0, 0, 360, 740);
      bool onScreen(Rect rect) =>
          screen.contains(rect.topLeft) &&
          screen.contains(rect.bottomRight - const Offset(0.1, 0.1));
      final heard = find.byKey(const ValueKey('capture-heard'));
      expect(heard, findsOneWidget);
      final scroll = find
          .ancestor(of: heard, matching: find.byType(Scrollable))
          .first;
      // Reversed: offset 0 shows the end of the words, the newest ones.
      expect(tester.state<ScrollableState>(scroll).position.pixels, 0);
      expect(
        tester.getRect(heard).bottom,
        lessThanOrEqualTo(tester.getRect(scroll).bottom + 0.5),
      );
      expect(onScreen(tester.getRect(scroll)), isTrue);
      for (final control in [
        find.widgetWithText(TextButton, l.cancel),
        find.widgetWithText(FilledButton, l.done),
        find.byTooltip(l.captureTypeInstead),
      ]) {
        expect(control.hitTestable(), findsOneWidget);
        expect(onScreen(tester.getRect(control)), isTrue, reason: '$control');
      }
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('WRITE_REVIEW_PREVIEWS')) {
        final boundary =
            preview.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File(
            'build/capture-listening-es-2x.png',
          ).writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.widgetWithText(TextButton, l.cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, l.keep));
      await tester.pumpAndSettle();
    },
  );
  group('UX-101: the voice save’s Deshacer', () {
    const timeoutChannel = MethodChannel('taskflow/accessibility');
    final platform =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    setUp(
      () =>
          platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000),
    );
    tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));

    Future<(ProviderContainer, _SavingStore)> saveVoiceCapture(
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = _SavingStore();
      final container = designContainer(
        regionalStore: MemoryRegionalStore(
          const RegionalPreferences(language: 'es'),
        ),
        overrides: [captureStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      final session = CaptureSession(
        id: 'voice-1',
        ownerKey: container.read(captureOwnerProvider),
        timezone: 'Europe/Madrid',
        capturedAt: DateTime.now().toUtc(),
        status: 'ready',
        transcript: 'Comprar pan',
        drafts: [
          CaptureDraft(
            id: 'a',
            task: Task(title: 'Comprar pan', priority: 1),
          ),
        ],
      );
      store.current = session;
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => ReviewTasksScreen(session: session),
            ),
          );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      return (container, store);
    }

    testWidgets('UX-101: it is gone after the accessibility timeout', (
      tester,
    ) async {
      await saveVoiceCapture(tester);
      final l = lookupAppLocalizations(const Locale('es'));
      expect(find.byType(ReviewTasksScreen), findsNothing);
      expect(find.text(l.undo), findsOneWidget);
      expect(find.textContaining(l.captureTasksSaved(1)), findsOneWidget);
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.duration, const Duration(seconds: 10));
      expect(bar.behavior, SnackBarBehavior.floating);
      await tester.pump(const Duration(seconds: 9));
      expect(find.text(l.undo), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(l.undo), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('UX-101: a second review opened after a save shows none', (
      tester,
    ) async {
      final (_, store) = await saveVoiceCapture(tester);
      final l = lookupAppLocalizations(const Locale('es'));
      expect(find.text(l.undo), findsOneWidget);
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => ReviewTasksScreen(
                drafts: [draft('Llamar a mamá')],
                transcript: 'Llamar a mamá',
              ),
            ),
          );
      await tester.pumpAndSettle();
      expect(find.byType(ReviewTasksScreen), findsOneWidget);
      expect(find.text(l.undo), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.byKey(const ValueKey('save-drafts')).hitTestable(),
        findsOneWidget,
      );
      // Nothing can undo the earlier save from here any more.
      expect(store.undos, 0);
      expect(tester.takeException(), isNull);
    });
  });
}

/// A capture store in memory: saving marks drafts saved, Undo restores them.
class _SavingStore extends CaptureStore {
  _SavingStore() : super(TaskDatabase());
  CaptureSession? current;
  int undos = 0;
  @override
  Future<void> update(CaptureSession value) async => current = value;
  @override
  Future<CaptureSession?> read(String id, String ownerKey) async =>
      current?.id == id ? current : null;
  @override
  Future<List<CaptureSession>> pending(String ownerKey) async => [];
  @override
  Future<CaptureSession> saveReady(
    String id,
    String ownerKey,
    Set<String> draftIds,
  ) async {
    var next = 100;
    return current = current!.copyWith(
      status: 'saved',
      drafts: [
        for (final draft in current!.drafts)
          draftIds.contains(draft.id)
              ? draft.copyWith(savedTaskId: next++)
              : draft,
      ],
    );
  }

  @override
  Future<CaptureSession?> undoSave(
    CaptureSession before,
    Map<String, int> savedIds,
  ) async {
    undos++;
    return current = before;
  }
}

/// The phone's recognizer: `start` is counted and events are sent by the test.
class _PreviewSpeech extends NativeSpeech {
  final controller = StreamController<SpeechEvent>.broadcast(sync: true);
  int starts = 0;
  int? run;
  @override
  Future<SpeechCapability> capability({String? language}) async =>
      const SpeechCapability(
        onDevice: true,
        language: 'es-ES',
        languageInstalled: true,
      );
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
  }

  void send(String kind, {String? text}) =>
      controller.add(SpeechEvent(run!, kind, text: text));
  @override
  Future<void> stop(int id) async => send('ended');
  @override
  Future<void> cancel(int id) async {}
}

/// A capture kept in memory while it is being said.
class _ListeningStore extends CaptureStore {
  _ListeningStore() : super(TaskDatabase());
  CaptureSession? session;
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
  }) async => session = CaptureSession(
    id: 'preview-capture',
    ownerKey: ownerKey,
    timezone: timezone,
    capturedAt: (now ?? DateTime.now()).toUtc(),
    text: text,
    kind: kind,
    projectId: projectId,
    source: source,
  );
  @override
  Future<void> update(CaptureSession value) async => session = value;
  @override
  Future<CaptureSession?> read(String id, String ownerKey) async =>
      session?.id == id ? session : null;
  @override
  Future<void> cleanFinished(String ownerKey) async {}
  @override
  Future<List<CaptureSession>> pending(String ownerKey) async => [];
}

/// The audio recorder stands by unused while the recognizer listens.
class _SilentRecorder extends Fake implements AudioRecorder {
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
