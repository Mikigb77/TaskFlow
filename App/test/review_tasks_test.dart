import 'package:agenda/main.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
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
import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/capture_clarification.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/widgets/capture_review_editor.dart';
import 'package:intl/intl.dart';

TaskDraft draft(String title, {bool ambiguous = false}) => TaskDraft.fromJson({
  'title': title,
  'due_date': null,
  'scheduled_date': title == 'Pay invoice' ? '2026-09-25' : null,
  'priority': 1,
  'notes': '',
  'transcript': 'Buy coffee. Pay invoice Friday.',
  'questions': ambiguous ? ['Morning or afternoon?'] : [],
});

/// Opens the capture sheet on a spoken capture's result, as resuming one does.
Future<ProviderContainer> openReview(
  WidgetTester tester,
  List<TaskDraft> drafts, {
  GlobalKey? preview,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = _SavingStore();
  final container = designContainer(
    overrides: [
      captureStoreProvider.overrideWithValue(store),
      nativeSpeechProvider.overrideWithValue(_PreviewSpeech()),
      captureRecorderFactoryProvider.overrideWithValue(_SilentRecorder.new),
    ],
  );
  store.tasks = container;
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(key: preview, child: const MyApp()),
    ),
  );
  await tester.pumpAndSettle();
  await _openResult(
    tester,
    store,
    CaptureSession(
      id: 'review',
      ownerKey: container.read(captureOwnerProvider),
      timezone: 'Europe/Madrid',
      capturedAt: DateTime.now().toUtc(),
      status: 'ready',
      source: 'speech',
      transcript: 'Buy coffee. Pay invoice Friday.',
      drafts: drafts.map(CaptureDraft.fromAI).toList(),
    ),
  );
  return container;
}

/// Opens the capture sheet on a result of [drafts] in [language], with a
/// 24-hour clock, as resuming a capture does. [source] is `speech` for words
/// that were said, `typed` or `shared` otherwise.
Future<(ProviderContainer, _SavingStore)> openResultIn(
  WidgetTester tester,
  List<CaptureDraft> drafts, {
  String language = 'es',
  String source = 'speech',
  String transcript = 'Lo que dije',
  List<TaskListInfo>? projects,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = _SavingStore();
  final container = designContainer(
    regionalStore: MemoryRegionalStore(
      RegionalPreferences(
        language: language,
        clock: ClockFormat.twentyFour,
        weekStart: 1,
      ),
    ),
    projects: projects,
    overrides: [
      captureStoreProvider.overrideWithValue(store),
      nativeSpeechProvider.overrideWithValue(_PreviewSpeech()),
      captureRecorderFactoryProvider.overrideWithValue(_SilentRecorder.new),
    ],
  );
  store.tasks = container;
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
  await tester.pumpAndSettle();
  await _openResult(
    tester,
    store,
    CaptureSession(
      id: 'result',
      ownerKey: container.read(captureOwnerProvider),
      timezone: 'Europe/Madrid',
      capturedAt: DateTime.now().toUtc(),
      status: 'ready',
      source: source,
      text: source == 'speech' ? '' : transcript,
      transcript: transcript,
      drafts: drafts,
    ),
  );
  return (container, store);
}

/// The first day at least two days away that falls on [weekday], so its
/// label is never `Hoy` or `Mañana`.
DateTime nextWeekday(int weekday) {
  final now = DateTime.now();
  var day = DateTime(now.year, now.month, now.day + 2);
  while (day.weekday != weekday) {
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return day;
}

/// Opens the capture sheet straight on [session]'s result.
Future<void> _openResult(
  WidgetTester tester,
  _SavingStore store,
  CaptureSession session,
) async {
  store.current = session;
  final messenger = tester.binding.defaultBinaryMessenger;
  const timezone = MethodChannel('flutter_timezone');
  messenger.setMockMethodCallHandler(timezone, (_) async => 'Europe/Madrid');
  addTearDown(() => messenger.setMockMethodCallHandler(timezone, null));
  // Messages read the phone's timeout; none is set here.
  const timeout = MethodChannel('taskflow/accessibility');
  if (messenger.checkMockMessageHandler(timeout.name, null)) {
    messenger.setMockMethodCallHandler(timeout, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(timeout, null));
  }
  unawaited(
    showCaptureSheet(
      tester.element(find.byType(Scaffold).first),
      captureId: session.id,
      startListening: false,
    ),
  );
  await tester.pumpAndSettle();
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
      await tester.tap(find.text('Buy coffee'));
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
    await tester.ensureVisible(find.text('That’s right'));
    await tester.tap(find.text('That’s right'));
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
      await tester.ensureVisible(find.text('That’s right'));
      await tester.tap(find.text('That’s right'));
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
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Remove Second'));
    await tester.tap(find.byTooltip('Remove Second'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove Second'), findsOneWidget);
    await tester.ensureVisible(find.text('First'));
    await tester.tap(find.text('First'));
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
      await tester.tap(find.text('Coffee'));
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
        overrides: [
          captureStoreProvider.overrideWithValue(store),
          nativeSpeechProvider.overrideWithValue(_PreviewSpeech()),
          captureRecorderFactoryProvider.overrideWithValue(_SilentRecorder.new),
        ],
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
      await _openResult(tester, store, session);
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      await tester.pumpAndSettle();
      return (container, store);
    }

    testWidgets('UX-101: it is gone after the accessibility timeout', (
      tester,
    ) async {
      await saveVoiceCapture(tester);
      final l = lookupAppLocalizations(const Locale('es'));
      expect(find.byType(CaptureResult), findsNothing);
      expect(find.text(l.undo), findsOneWidget);
      expect(find.text(l.taskSavedInbox), findsOneWidget);
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
      final (container, store) = await saveVoiceCapture(tester);
      final l = lookupAppLocalizations(const Locale('es'));
      expect(find.text(l.undo), findsOneWidget);
      await _openResult(
        tester,
        store,
        CaptureSession(
          id: 'voice-2',
          ownerKey: container.read(captureOwnerProvider),
          timezone: 'Europe/Madrid',
          capturedAt: DateTime.now().toUtc(),
          status: 'ready',
          transcript: 'Llamar a mamá',
          drafts: [CaptureDraft.fromAI(draft('Llamar a mamá'))],
        ),
      );
      expect(find.byType(CaptureResult), findsOneWidget);
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

  // ---- P19: voice review, fewer and clearer choices ----

  final es = lookupAppLocalizations(const Locale('es'));
  Finder button() => find.byKey(const ValueKey('save-drafts'));
  FilledButton saveButton(WidgetTester tester) =>
      tester.widget<FilledButton>(button());
  Finder inQuestion(String question, Finder finder) => find.descendant(
    of: find
        .ancestor(of: find.text(question), matching: find.byType(DecoratedBox))
        .first,
    matching: finder,
  );

  testWidgets(
    'UX-110 / U4: an AM/PM question shows only 5:00, 17:00 and Sin hora, right under the date line, with no Cambiar este dato and no confirm',
    (tester) async {
      final day = nextWeekday(DateTime.friday);
      const question = '¿A las 5 de la mañana o de la tarde?';
      await openResultIn(tester, [
        CaptureDraft(
          id: 'doctor',
          task: Task(title: 'Médico', priority: 1, dueDate: day),
          confirmed: false,
          clarifications: const [
            CaptureClarification(
              question: question,
              field: 'schedule',
              times: ['05:00', '17:00'],
            ),
          ],
        ),
      ]);
      expect(find.text(question), findsOneWidget);
      final chips = tester
          .widgetList<ActionChip>(inQuestion(question, find.byType(ActionChip)))
          .map((chip) => (chip.label as Text).data)
          .toList();
      // The times read as every other time in the app does with a 24-hour
      // clock (`05:00`), the way the plan's `5:00` means.
      final sheet = tester.element(find.byType(CaptureResult));
      expect(chips, [
        sheet.clockTime(DateTime(2026, 1, 1, 5)),
        sheet.clockTime(DateTime(2026, 1, 1, 17)),
        es.reviewNoTime,
      ]);
      expect(chips.first, anyOf('5:00', '05:00'));
      expect(es.reviewNoTime, 'Sin hora');
      // Nothing else to press inside the question.
      expect(inQuestion(question, find.byType(TextButton)), findsNothing);
      expect(find.text(es.reviewEditDetail), findsNothing);
      expect(find.text(es.reviewConfirmDetail), findsNothing);
      // Right under the date line, above the notes.
      final dateLine = tester.getRect(
        find.byKey(const ValueKey('draft-schedule-doctor')),
      );
      final chip = tester.getRect(find.widgetWithText(ActionChip, '17:00'));
      expect(chip.top, greaterThanOrEqualTo(dateLine.bottom));
      expect(
        chip.bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const ValueKey('draft-notes'))).top,
        ),
      );
      // Until a time is picked, nothing can be saved without it.
      expect(saveButton(tester).onPressed, isNull);
      expect(find.text(es.captureCheckDetails), findsOneWidget);
      await tester.tap(find.widgetWithText(ActionChip, '17:00'));
      await tester.pumpAndSettle();
      expect(find.text(question), findsNothing);
      expect(saveButton(tester).onPressed, isNotNull);
      final line = find.byKey(const ValueKey('draft-schedule-doctor'));
      expect(
        find.descendant(of: line, matching: find.textContaining('17:00')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-110: Sin hora answers the question and keeps the day without a time',
    (tester) async {
      final day = nextWeekday(DateTime.friday);
      const question = '¿A las 5 de la mañana o de la tarde?';
      final (container, _) = await openResultIn(tester, [
        CaptureDraft(
          id: 'doctor',
          task: Task(title: 'Médico', priority: 1, dueDate: day),
          confirmed: false,
          clarifications: const [
            CaptureClarification(
              question: question,
              field: 'schedule',
              times: ['05:00', '17:00'],
            ),
          ],
        ),
      ]);
      await tester.tap(find.widgetWithText(ActionChip, es.reviewNoTime));
      await tester.pumpAndSettle();
      expect(find.text(question), findsNothing);
      await tester.tap(button());
      await tester.pumpAndSettle();
      final saved = container
          .read(taskProvider)
          .requireValue
          .singleWhere((task) => task.title == 'Médico');
      expect(saved.dueDate, day);
      expect(saved.hasTime, isFalse);
    },
  );

  for (final language in ['es', 'ca', 'en']) {
    testWidgets(
      'UX-110: a question without times confirms with That’s right / Así está bien / Així està bé ($language)',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        expect(
          l.reviewConfirmDetail,
          {
            'es': 'Así está bien',
            'ca': 'Així està bé',
            'en': 'That’s right',
          }[language],
        );
        const question = 'Is this the right person?';
        await openResultIn(language: language, tester, [
          CaptureDraft(
            id: 'call',
            task: Task(title: 'Call Ana', priority: 1),
            confirmed: false,
            questions: const [question],
          ),
        ]);
        final confirm = inQuestion(question, find.text(l.reviewConfirmDetail));
        expect(confirm, findsOneWidget);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(find.text(question), findsNothing);
        expect(saveButton(tester).onPressed, isNotNull);
      },
    );
  }

  testWidgets(
    'UX-116: a title question shows on its collapsed card; every collapsed card has ✕ and no pencil',
    (tester) async {
      const question = '¿Cómo se llama la tienda?';
      await openResultIn(tester, [
        CaptureDraft(
          id: 'shop',
          task: Task(title: 'Comprar en la tienda', priority: 1),
          confirmed: false,
          clarifications: const [
            CaptureClarification(question: question, field: 'title'),
          ],
        ),
        CaptureDraft(
          id: 'bread',
          task: Task(title: 'Comprar pan', priority: 1),
        ),
        CaptureDraft(
          id: 'call',
          task: Task(title: 'Llamar a mamá', priority: 1),
        ),
      ]);
      // Collapsed: no editor is open.
      expect(find.byKey(const ValueKey('task-title')), findsNothing);
      final card = find.byKey(const ValueKey('shop'));
      expect(
        find.descendant(of: card, matching: find.text(question)),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text(question));
      await tester.pumpAndSettle();
      expect(find.text(question).hitTestable(), findsOneWidget);
      for (final title in [
        'Comprar en la tienda',
        'Comprar pan',
        'Llamar a mamá',
      ]) {
        expect(find.byTooltip(es.removeCaptureItem(title)), findsOneWidget);
      }
      for (final pencil in [
        Icons.edit,
        Icons.edit_outlined,
        Icons.edit_rounded,
        Icons.edit_note_rounded,
      ]) {
        expect(
          find.descendant(
            of: find.byType(CaptureReviewEditor),
            matching: find.byIcon(pencil),
          ),
          findsNothing,
        );
      }
      expect(
        find.descendant(
          of: find.byType(CaptureReviewEditor),
          matching: find.byTooltip(es.editTask),
        ),
        findsNothing,
      );
      // Tapping the title expands the card in place.
      await tester.tap(find.text('Comprar pan'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('task-title')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-117: removing every draft leaves an enabled Terminar bottom button and no link',
    (tester) async {
      final (_, store) = await openResultIn(tester, [
        CaptureDraft(
          id: 'a',
          task: Task(title: 'Comprar pan', priority: 1),
        ),
        CaptureDraft(
          id: 'b',
          task: Task(title: 'Llamar a mamá', priority: 1),
        ),
      ]);
      void hideMessage() => ScaffoldMessenger.of(
        tester.element(find.byType(CaptureResult)),
      ).removeCurrentSnackBar();
      await tester.tap(find.byTooltip(es.removeCaptureItem('Comprar pan')));
      await tester.pumpAndSettle();
      hideMessage();
      await tester.pumpAndSettle();
      // The last one is a single result: it is removed from Más opciones.
      final options = find.byKey(const ValueKey('draft-options-b'));
      await tester.ensureVisible(options);
      await tester.tap(options);
      await tester.pumpAndSettle();
      final remove = find.text(es.reviewRemove);
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      hideMessage();
      await tester.pumpAndSettle();
      expect(es.captureFinish, 'Terminar');
      expect(
        find.descendant(of: button(), matching: find.text(es.captureFinish)),
        findsOneWidget,
      );
      expect(saveButton(tester).onPressed, isNotNull);
      // The only Terminar is the button: no small link.
      expect(find.text(es.captureFinish), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text(es.captureFinish),
          matching: find.byType(TextButton),
        ),
        findsNothing,
      );
      expect(button().hitTestable(), findsOneWidget);
      await tester.tap(button());
      await tester.pumpAndSettle();
      expect(find.byType(CaptureResult), findsNothing);
      expect(store.current!.status, 'discarded');
      expect(tester.takeException(), isNull);
    },
  );

  for (final (source, spoken) in [
    ('speech', true),
    ('typed', false),
    ('shared', false),
  ]) {
    testWidgets(
      'UX-124: $source words show ${spoken ? 'Ver lo que dije' : 'Texto original'}${spoken ? ' and Volver a decirlo' : ', not Volver a decirlo'}',
      (tester) async {
        await openResultIn(tester, source: source, [
          CaptureDraft(
            id: 'a',
            task: Task(title: 'Comprar pan', priority: 1),
          ),
        ]);
        expect(es.reviewOriginalText, 'Texto original');
        expect(
          find.text(es.reviewOriginal),
          spoken ? findsOneWidget : findsNothing,
        );
        expect(
          find.text(es.reviewOriginalText),
          spoken ? findsNothing : findsOneWidget,
        );
        expect(
          find.text(es.captureSayAgain),
          spoken ? findsOneWidget : findsNothing,
        );
      },
    );
  }

  testWidgets('UX-124: the English title field reads Task title', (
    tester,
  ) async {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.taskTitle, 'Task title');
    await openResultIn(tester, language: 'en', [
      CaptureDraft(
        id: 'a',
        task: Task(title: 'Buy bread', priority: 1),
      ),
    ]);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('task-title')),
        matching: find.text('Task title'),
      ),
      findsOneWidget,
    );
    expect(find.text('Task Title'), findsNothing);
  });

  testWidgets(
    'UX-127: Más opciones has no summary at the defaults and lists only what differs',
    (tester) async {
      final day = nextWeekday(DateTime.friday);
      await openResultIn(tester, [
        CaptureDraft(
          id: 'plain',
          task: Task(title: 'Comprar pan', priority: 1, dueDate: day),
        ),
        CaptureDraft(
          id: 'set',
          task: Task(
            title: 'Regar las plantas',
            priority: 3,
            dueDate: day,
            recurrence: 'weekly',
          ),
        ),
      ]);
      Future<ListTile> options(String id, String title) async {
        await tester.ensureVisible(find.text(title));
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        final tile = find.byKey(ValueKey('draft-options-$id'));
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        return tester.widget<ListTile>(tile);
      }

      final plain = await options('plain', 'Comprar pan');
      expect((plain.title as Text).data, es.reviewOptions);
      expect(plain.subtitle, isNull);
      expect(
        find.text('${es.priorityValue(es.low)} · ${es.neverRepeat}'),
        findsNothing,
      );
      final set = await options('set', 'Regar las plantas');
      final summary = (set.subtitle! as Text).data!;
      expect(summary, contains(es.priorityValue(es.high)));
      expect(summary, contains(es.weekly));
      expect(summary, isNot(contains(es.low)));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('UX-113: a voice note offers no “Usa un título breve” hint', (
    tester,
  ) async {
    await openResultIn(tester, [
      CaptureDraft(
        id: 'note',
        task: Task(
          kind: 'note',
          title: 'La clave del wifi de casa',
          priority: 1,
          notes: 'La clave del wifi de casa es la de la caja del router',
        ),
      ),
    ]);
    expect(find.textContaining('título breve'), findsNothing);
    expect(find.text(es.saveNote), findsOneWidget);
  });

  // ---- P36 / U4: the result in the sheet, with the date first ----

  testWidgets(
    'U4: one task dated Friday at 17:00 shows its title, then the date as the largest line, and Añadir al calendario; no Bandeja personal, Prioridad or Lista para cuando tú quieras',
    (tester) async {
      final friday = nextWeekday(DateTime.friday);
      await openResultIn(tester, [
        CaptureDraft(
          id: 'car',
          task: Task(
            title: 'Llevar el coche al taller',
            priority: 1,
            dueDate: DateTime(friday.year, friday.month, friday.day, 17),
            hasTime: true,
          ),
        ),
      ]);
      final context = tester.element(find.byType(CaptureResult));
      final date = '${context.weekdayDate(friday)} · 17:00';
      expect(date, startsWith(DateFormat.E('es').format(friday)));
      final title = find.byKey(const ValueKey('task-title'));
      expect(
        tester.widget<TextFormField>(title).controller!.text,
        'Llevar el coche al taller',
      );
      final line = find.descendant(
        of: find.byKey(const ValueKey('draft-schedule-car')),
        matching: find.text(date),
      );
      expect(line, findsOneWidget);
      expect(
        tester.getRect(line).top,
        greaterThanOrEqualTo(tester.getRect(title).bottom),
      );
      // The largest text after the title.
      double size(Finder text) => tester
          .renderObject<RenderParagraph>(
            find.descendant(of: text, matching: find.byType(RichText)),
          )
          .text
          .style!
          .fontSize!;
      final dateSize = size(line);
      final below = tester.getRect(line).bottom;
      for (final element
          in find
              .descendant(
                of: find.byType(CaptureResult),
                matching: find.byType(RichText),
              )
              .evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        final style = paragraph.text.style;
        if (style?.fontFamily == 'MaterialIcons') continue;
        if (!paragraph.attached || !paragraph.hasSize) continue;
        final top = paragraph.localToGlobal(Offset.zero).dy;
        if (top < below) continue;
        expect(
          style?.fontSize ?? 14,
          lessThanOrEqualTo(dateSize),
          reason: paragraph.text.toPlainText(),
        );
      }
      expect(
        find.descendant(
          of: button(),
          matching: find.text(es.captureAddToCalendar),
        ),
        findsOneWidget,
      );
      expect(es.captureAddToCalendar, 'Añadir al calendario');
      Finder inSheet(Finder finder) =>
          find.descendant(of: find.byType(CaptureResult), matching: finder);
      expect(inSheet(find.text(es.noList)), findsNothing);
      expect(inSheet(find.textContaining(es.priority)), findsNothing);
      expect(find.text('Lista para cuando tú quieras'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('U4: one task without a date says Añadir tarea', (tester) async {
    await openResultIn(tester, [
      CaptureDraft(
        id: 'a',
        task: Task(title: 'Comprar pan', priority: 1),
      ),
    ]);
    expect(
      find.descendant(of: button(), matching: find.text(es.captureAddTask)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('draft-schedule-a')),
        matching: find.text(es.noDate),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'U4: a batch of three shows 3 cosas para añadir, three rows with ✕, and Añadir 3 tareas',
    (tester) async {
      final titles = ['Comprar pan', 'Llamar a mamá', 'Pagar la luz'];
      await openResultIn(tester, [
        for (final (i, title) in titles.indexed)
          CaptureDraft(
            id: 'd$i',
            task: Task(title: title, priority: 1),
          ),
      ]);
      expect(es.captureThingsToAdd(3), '3 cosas para añadir');
      expect(find.text(es.captureThingsToAdd(3)), findsOneWidget);
      expect(find.byType(CaptureReviewEditor), findsNWidgets(3));
      for (final title in titles) {
        expect(find.byTooltip(es.removeCaptureItem(title)), findsOneWidget);
      }
      expect(
        find.descendant(
          of: button(),
          matching: find.text(es.captureAddTasks(3)),
        ),
        findsOneWidget,
      );
      expect(es.captureAddTasks(3), 'Añadir 3 tareas');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('U4: a capture into a shared project shows the audience line', (
    tester,
  ) async {
    final family = TaskListInfo(
      id: 'family',
      name: 'Casa',
      shared: true,
      role: 'owner',
    );
    await openResultIn(
      tester,
      [
        CaptureDraft(
          id: 'a',
          task: Task(
            title: 'Comprar pan',
            priority: 1,
            listId: 'family',
            assignment: 'group',
          ),
        ),
      ],
      projects: [family],
    );
    await tester.pumpAndSettle();
    expect(find.text(es.audienceShared('Casa')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CaptureResult),
        matching: find.text(es.noList),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'U4: Deshacer after a save restores the drafts and reopens the sheet on the result',
    (tester) async {
      final (container, store) = await openResultIn(tester, [
        CaptureDraft(
          id: 'a',
          task: Task(title: 'Comprar pan', priority: 1),
        ),
      ]);
      await tester.tap(button());
      await tester.pumpAndSettle();
      expect(find.byType(CaptureResult), findsNothing);
      expect(
        container.read(taskProvider).requireValue.map((t) => t.title),
        contains('Comprar pan'),
      );
      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      expect(store.undos, 1);
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('task-title')))
            .controller!
            .text,
        'Comprar pan',
      );
      expect(saveButton(tester).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}

/// A capture store in memory: saving marks drafts saved and, given [tasks],
/// adds them to its task list the way the real store's table does; Undo
/// restores them.
class _SavingStore extends CaptureStore {
  _SavingStore() : super(TaskDatabase());
  CaptureSession? current;
  ProviderContainer? tasks;
  int undos = 0;
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
  Future<void> discard(String id, String ownerKey) async {
    if (current?.id == id) current = current!.copyWith(status: 'discarded');
  }

  @override
  Future<CaptureSession> saveReady(
    String id,
    String ownerKey,
    Set<String> draftIds,
  ) async {
    await tasks?.read(taskProvider.notifier).addTasks([
      for (final draft in current!.drafts)
        if (draftIds.contains(draft.id)) draft.task,
    ]);
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
