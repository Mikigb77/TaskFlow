import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/screens/notes_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/feedback_timeout.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/capture_fixtures.dart';
import 'support/design_fixtures.dart';
import 'support/reminder_fixtures.dart';

// UX-401 / P51: ask once, in a sheet, after the first task with a date is
// saved and its save message has closed (UX-439). Replaces the in-list card
// that reminder_ask_card_test.dart tested.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Real fonts: the square test font makes Spanish copy far wider than it is.
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(
    () => platform.setMockMethodCallHandler(timeoutChannel, (_) async => null),
  );
  tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));

  Future<ProviderContainer> openApp(
    WidgetTester tester,
    MemoryReminderStore store,
    FakeReminderAccess access, {
    List<Task> tasks = const [],
    String language = 'es',
    Size size = const Size(390, 844),
    double textScale = 1,
    List<Override> overrides = const [],
    // Captures are typed without Pro and saved in memory, unless a test
    // brings its own store.
    CaptureStore? captureStore,
    bool pro = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final captures = MemoryCaptures();
    final container = designContainer(
      regionalStore: MemoryRegionalStore(
        RegionalPreferences(language: language),
      ),
      tasks: () => _GivenTasks(tasks),
      pro: pro,
      overrides: [
        ...reminderOverrides(store, access),
        captureStoreProvider.overrideWithValue(captureStore ?? captures),
        ...overrides,
      ],
    );
    captures.tasks = container;
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  AppLocalizations strings(WidgetTester tester) => lookupAppLocalizations(
    Localizations.localeOf(tester.element(find.byType(CalendarScreen))),
  );

  // The reminder question's sheet. Capture opens as a bottom sheet too.
  Finder sheet() {
    final capture = find
        .ancestor(
          of: find.byType(VoiceTaskScreen),
          matching: find.byType(BottomSheet),
        )
        .evaluate()
        .map((element) => element.widget)
        .toSet();
    return find.byWidgetPredicate(
      (widget) => widget is BottomSheet && !capture.contains(widget),
    );
  }

  Finder question(AppLocalizations l) => find.text(l.reminderAskQuestion);

  /// Types [title] and today's word in the capture sheet from Calendar's
  /// `Añadir tarea`, and adds it: a task dated today.
  Future<void> typeDatedTask(WidgetTester tester, String title) async {
    final l = strings(tester);
    final today = {'es': 'hoy', 'ca': 'avui'}[l.localeName] ?? 'today';
    await typeCapture(tester, l.addTask, '$title $today');
    // The result not yet added is never covered by the question.
    expect(question(l), findsNothing);
    await saveCapture(tester);
  }

  /// The question waits for the save message to close (UX-439).
  Future<void> letSaveMessageClose(WidgetTester tester) async {
    expect(find.byType(SnackBar), findsOneWidget);
    expect(sheet(), findsNothing);
    await tester.pump(FeedbackTimeout.defaultDuration);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  }

  /// Types a task with no date: with today selected, it gets none.
  Future<void> typeUndatedTask(WidgetTester tester, String title) async {
    await typeCapture(tester, strings(tester).addTask, title);
    await saveCapture(tester);
  }

  testWidgets(
    'UX-401: the first typed task with a date shows the sheet once, after the save message; Ahora no leaves reminders off',
    (tester) async {
      final store = MemoryReminderStore();
      final access = FakeReminderAccess();
      final container = await openApp(tester, store, access);
      final l = strings(tester);
      await typeDatedTask(tester, 'Comprar pan');
      // Saved and shown first: the sheet is gone and the save message is up.
      expect(find.byType(VoiceTaskScreen), findsNothing);
      expect(
        container.read(taskProvider).requireValue.map((t) => t.title),
        contains('Comprar pan'),
      );
      await letSaveMessageClose(tester);
      expect(sheet(), findsOneWidget);
      expect(
        find.descendant(of: sheet(), matching: question(l)),
        findsOneWidget,
      );
      final yes = find.widgetWithText(FilledButton, l.reminderAskYes);
      final notNow = find.widgetWithText(TextButton, l.reminderAskNotNow);
      expect(yes.hitTestable(), findsOneWidget);
      expect(notNow.hitTestable(), findsOneWidget);
      // Material 3: a drag handle.
      expect(tester.widget<BottomSheet>(sheet()).showDragHandle, isTrue);

      await tester.tap(notNow);
      await tester.pumpAndSettle();
      expect(sheet(), findsNothing);
      expect(store.value.asked, isTrue);
      expect(store.value.enabled, isFalse);
      expect(access.permissionRequests, 0);

      // A second dated task: never asked again.
      await typeDatedTask(tester, 'Llamar a mamá');
      expect(
        container.read(taskProvider).requireValue.map((t) => t.title),
        contains('Llamar a mamá'),
      );
      expect(question(l), findsNothing);
      expect(sheet(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-401: Sí, recuérdamelo turns reminders on and asks for the notification permission in the same tap',
    (tester) async {
      final store = MemoryReminderStore();
      final access = FakeReminderAccess();
      await openApp(tester, store, access);
      final l = strings(tester);
      await typeDatedTask(tester, 'Comprar pan');
      await letSaveMessageClose(tester);
      expect(question(l), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, l.reminderAskYes));
      await tester.pumpAndSettle();
      expect(sheet(), findsNothing);
      expect(question(l), findsNothing);
      expect(access.permissionRequests, 1);
      expect(store.value.enabled, isTrue);
      expect(store.value.asked, isTrue);

      await typeDatedTask(tester, 'Llamar a mamá');
      expect(question(l), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-401: closing the sheet with Back counts as asked; it never returns',
    (tester) async {
      final store = MemoryReminderStore();
      final access = FakeReminderAccess();
      await openApp(tester, store, access);
      final l = strings(tester);
      await typeDatedTask(tester, 'Comprar pan');
      await letSaveMessageClose(tester);
      expect(question(l), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(sheet(), findsNothing);
      expect(store.value.asked, isTrue);
      expect(store.value.enabled, isFalse);
      expect(access.permissionRequests, 0);
      await typeDatedTask(tester, 'Llamar a mamá');
      expect(question(l), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U12: after the first dated task is saved, the try-it instruction is gone and the reminder question shows',
    (tester) async {
      final store = MemoryReminderStore();
      final access = FakeReminderAccess();
      await openApp(tester, store, access);
      final l = strings(tester);
      // A brand-new account without Pro is told to type.
      expect(find.text(l.calendarTryTyping), findsOneWidget);
      await typeDatedTask(tester, 'Comprar pan');
      expect(find.text(l.calendarTryTyping), findsNothing);
      await letSaveMessageClose(tester);
      expect(
        find.descendant(of: sheet(), matching: question(l)),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, l.reminderAskNotNow));
      await tester.pumpAndSettle();
      // Only one question: the instruction never comes back either.
      expect(question(l), findsNothing);
      expect(find.text(l.calendarTryTyping), findsNothing);
      expect(find.text(l.calendarTrySaying), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('UX-401: saving a task without a date never shows the sheet', (
    tester,
  ) async {
    final store = MemoryReminderStore();
    final access = FakeReminderAccess();
    final container = await openApp(tester, store, access);
    final l = strings(tester);
    await typeUndatedTask(tester, 'Algún día');
    expect(
      container.read(taskProvider).requireValue.map((t) => t.title),
      contains('Algún día'),
    );
    expect(question(l), findsNothing);
    expect(sheet(), findsNothing);
    expect(store.value.asked, isFalse);
    // The first dated task still asks.
    await typeDatedTask(tester, 'Comprar pan');
    await letSaveMessageClose(tester);
    expect(question(l), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'UX-401: saving a dated task from the voice review shows the sheet once',
    (tester) async {
      final store = MemoryReminderStore();
      final access = FakeReminderAccess();
      final captures = _SavingCaptures();
      final container = await openApp(
        tester,
        store,
        access,
        captureStore: captures,
        pro: true,
        overrides: captureSheetOverrides(),
      );
      final l = strings(tester);
      final now = DateTime.now();
      Future<void> review(String id, String title) async {
        final session = CaptureSession(
          id: id,
          ownerKey: container.read(captureOwnerProvider),
          timezone: 'Europe/Madrid',
          capturedAt: now.toUtc(),
          status: 'ready',
          transcript: title,
          drafts: [
            CaptureDraft(
              id: 'a',
              task: Task(
                title: title,
                priority: 1,
                dueDate: DateTime(now.year, now.month, now.day + 1),
              ),
            ),
          ],
        );
        captures.current = session;
        await openCaptureResult(tester, session.id);
        // Not on top of the review that is still open.
        expect(question(l), findsNothing);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
      }

      await review('voice-1', 'Comprar pan');
      expect(find.byType(CaptureResult), findsNothing);
      expect(
        find.text(
          l.taskAddedOn(
            tester
                .element(find.byType(CalendarScreen))
                .weekdayDate(DateTime(now.year, now.month, now.day + 1)),
          ),
        ),
        findsOneWidget,
      );
      await letSaveMessageClose(tester);
      expect(question(l), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, l.reminderAskNotNow));
      await tester.pumpAndSettle();
      expect(store.value.asked, isTrue);

      await review('voice-2', 'Llamar a mamá');
      expect(find.byType(CaptureResult), findsNothing);
      expect(question(l), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['es', 'ca']) {
    testWidgets(
      'UX-401: at 2x text on 320x568 ($language) the question and both buttons are visible without scrolling',
      (tester) async {
        await openApp(
          tester,
          MemoryReminderStore(),
          FakeReminderAccess(),
          language: language,
          size: const Size(320, 568),
          textScale: 2,
        );
        final l = strings(tester);
        expect(l.localeName, language);
        await typeDatedTask(tester, 'Comprar pan');
        await letSaveMessageClose(tester);
        expect(sheet(), findsOneWidget);
        const screen = Rect.fromLTWH(0, 0, 320, 568);
        for (final finder in [
          question(l),
          find.widgetWithText(FilledButton, l.reminderAskYes),
          find.widgetWithText(TextButton, l.reminderAskNotNow),
        ]) {
          expect(finder.hitTestable(), findsOneWidget);
          final rect = tester.getRect(finder);
          expect(
            screen.contains(rect.topLeft) && screen.contains(rect.bottomRight),
            isTrue,
            reason: '$finder at $rect is off the 320x568 screen',
          );
        }
        // Nothing had to scroll to show them.
        final scrollable = find.descendant(
          of: sheet(),
          matching: find.byType(Scrollable),
        );
        if (scrollable.evaluate().isNotEmpty) {
          expect(
            tester.state<ScrollableState>(scrollable.first).position.pixels,
            0,
          );
        }
        // TalkBack reads the question as the sheet opens.
        final node = tester.getSemantics(question(l));
        expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-401: no reminder card in the Calendar list, the Tareas list or its empty state',
    (tester) async {
      final now = DateTime.now();
      final container = await openApp(
        tester,
        MemoryReminderStore(),
        FakeReminderAccess(),
        tasks: [
          Task(
            id: 1,
            title: 'Comprar pan',
            priority: 1,
            dueDate: DateTime(now.year, now.month, now.day, 10),
          ),
        ],
      );
      final l = strings(tester);
      Future<void> noCard() async {
        // Every list scrolled to its end: the card used to be the last item.
        for (final scrollable in find.byType(Scrollable).evaluate().toList()) {
          final state = (scrollable as StatefulElement).state;
          if (state is ScrollableState && state.position.hasContentDimensions) {
            state.position.jumpTo(state.position.maxScrollExtent);
          }
        }
        await tester.pumpAndSettle();
        expect(question(l), findsNothing);
        expect(find.text(l.reminderAskYes), findsNothing);
        expect(find.text(l.reminderAskNotNow), findsNothing);
      }

      expect(find.byType(CalendarScreen), findsOneWidget);
      await noCard();
      // The Tareas tab, with a dated task in its list.
      await tester.tap(find.text(l.tasks).last);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Comprar pan'), findsWidgets);
      await noCard();
      // And its empty state.
      await container.read(taskProvider.notifier).deleteTask(1);
      await tester.pumpAndSettle();
      await noCard();
      expect(tester.takeException(), isNull);
    },
  );

  // UX-439 / P55: the question waits until the save message is gone, so the
  // newcomer sees where the task went and can still undo it.
  group('UX-439: the question waits for the save message', () {
    Finder row(String title) => find.widgetWithText(TaskTile, title);

    testWidgets(
      'UX-439: right after a dated save, Añadida al …, Deshacer and the lit row show with no sheet; the sheet comes after the message’s timeout',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess();
        await openApp(tester, store, access);
        final l = strings(tester);
        await typeDatedTask(tester, 'Comprar pan');
        expect(find.byType(VoiceTaskScreen), findsNothing);
        final calendar = tester.element(find.byType(CalendarScreen));
        final message = find.text(
          l.taskAddedOn(calendar.weekdayDate(DateTime.now())),
        );
        expect(message.hitTestable(), findsOneWidget);
        expect(find.text(l.undo).hitTestable(), findsOneWidget);
        expect(row('Comprar pan').hitTestable(), findsOneWidget);
        expect(
          tester.widget<TaskTile>(row('Comprar pan')).color,
          Theme.of(calendar).colorScheme.primaryContainer,
        );
        expect(sheet(), findsNothing);
        expect(question(l), findsNothing);

        // Still up just before its timeout: still no question.
        await tester.pump(
          FeedbackTimeout.defaultDuration - const Duration(milliseconds: 500),
        );
        expect(find.text(l.undo).hitTestable(), findsOneWidget);
        expect(sheet(), findsNothing);

        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(sheet(), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, l.reminderAskYes).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextButton, l.reminderAskNotNow).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-439: Deshacer on the save message shows no sheet; the next dated save asks after its own message closes',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess();
        final container = await openApp(tester, store, access);
        final l = strings(tester);
        await typeDatedTask(tester, 'Comprar pan');
        await tester.tap(find.text(l.undo));
        await tester.pumpAndSettle();
        expect(
          container.read(taskProvider).requireValue.map((t) => t.title),
          isNot(contains('Comprar pan')),
        );
        // Deshacer reopens the capture on its result; leave it for later.
        expect(find.byType(CaptureResult), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, l.cancel));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, l.keep));
        await tester.pumpAndSettle();
        expect(find.byType(VoiceTaskScreen), findsNothing);
        await tester.pump(FeedbackTimeout.defaultDuration * 2);
        await tester.pumpAndSettle();
        expect(sheet(), findsNothing);
        expect(question(l), findsNothing);
        expect(store.value.asked, isFalse);

        await typeDatedTask(tester, 'Llamar a mamá');
        await letSaveMessageClose(tester);
        expect(question(l), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-439: opening Añadir tarea before the message closes never covers it with the sheet; the next dated save asks',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess();
        await openApp(tester, store, access);
        final l = strings(tester);
        await typeDatedTask(tester, 'Comprar pan');
        expect(find.byType(SnackBar), findsOneWidget);
        await tester.tap(find.text(l.addTask).hitTestable());
        await tester.pumpAndSettle();
        expect(find.byType(VoiceTaskScreen), findsOneWidget);
        await tester.pump(FeedbackTimeout.defaultDuration * 2);
        await tester.pumpAndSettle();
        expect(find.byType(VoiceTaskScreen), findsOneWidget);
        expect(sheet(), findsNothing);
        expect(question(l), findsNothing);
        expect(store.value.asked, isFalse);

        await tester.enterText(
          find.byKey(const ValueKey('capture-words')),
          'Llamar a mamá hoy',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, l.done));
        await tester.pumpAndSettle();
        await saveCapture(tester);
        await letSaveMessageClose(tester);
        expect(question(l), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-439: opening a task before the message closes never shows the sheet, there or on the way back; the next dated save asks',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess();
        await openApp(tester, store, access);
        final l = strings(tester);
        await typeDatedTask(tester, 'Comprar pan');
        await tester.tap(
          find
              .descendant(
                of: row('Comprar pan'),
                matching: find.text('Comprar pan'),
              )
              .hitTestable(),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CalendarScreen).hitTestable(), findsNothing);
        await tester.pump(FeedbackTimeout.defaultDuration * 2);
        await tester.pumpAndSettle();
        expect(sheet(), findsNothing);
        expect(question(l), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(CalendarScreen).hitTestable(), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(question(l), findsNothing);
        expect(store.value.asked, isFalse);

        await typeDatedTask(tester, 'Llamar a mamá');
        await letSaveMessageClose(tester);
        expect(question(l), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-439: the voice review saving its last dated draft shows the save message first, and the sheet only after it closes',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess();
        final captures = _SavingCaptures();
        final container = await openApp(
          tester,
          store,
          access,
          captureStore: captures,
          pro: true,
          overrides: captureSheetOverrides(),
        );
        final l = strings(tester);
        final now = DateTime.now();
        final session = CaptureSession(
          id: 'voice-1',
          ownerKey: container.read(captureOwnerProvider),
          timezone: 'Europe/Madrid',
          capturedAt: now.toUtc(),
          status: 'ready',
          transcript: 'Comprar pan mañana',
          drafts: [
            CaptureDraft(
              id: 'a',
              task: Task(
                title: 'Comprar pan',
                priority: 1,
                dueDate: DateTime(now.year, now.month, now.day + 1),
              ),
            ),
          ],
        );
        captures.current = session;
        await openCaptureResult(tester, session.id);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(find.byType(CaptureResult), findsNothing);
        final message = find.text(
          l.taskAddedOn(
            tester
                .element(find.byType(CalendarScreen))
                .weekdayDate(DateTime(now.year, now.month, now.day + 1)),
          ),
        );
        expect(message.hitTestable(), findsOneWidget);
        expect(sheet(), findsNothing);
        await tester.pump(
          FeedbackTimeout.defaultDuration - const Duration(milliseconds: 500),
        );
        expect(message.hitTestable(), findsOneWidget);
        expect(sheet(), findsNothing);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(sheet(), findsOneWidget);
        expect(question(l), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // UX-448 / UX-449 (P56): the question goes ahead only when the save message
  // was seen (timed out, swiped or dismissed) and the person stayed on the
  // same tab.
  group('UX-448 / UX-449: replaced messages and tab switches', () {
    Finder row(String title) => find.widgetWithText(TaskTile, title);
    Finder tab(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

    /// The next dated save asks once its own message has closed.
    Future<void> nextSaveAsks(WidgetTester tester, AppLocalizations l) async {
      await typeDatedTask(tester, 'Llamar a mamá');
      await letSaveMessageClose(tester);
      expect(sheet(), findsOneWidget);
      expect(question(l), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, l.reminderAskYes).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextButton, l.reminderAskNotNow).hitTestable(),
        findsOneWidget,
      );
    }

    testWidgets(
      'UX-448: ticking the just-saved task keeps Tarea completada and Deshacer free of the sheet; the next dated save asks',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess();
        final container = await openApp(tester, store, access);
        final l = strings(tester);
        await typeDatedTask(tester, 'Comprar pan');
        expect(find.byType(SnackBar), findsOneWidget);
        final checkbox = find.descendant(
          of: row('Comprar pan'),
          matching: find.byType(Checkbox),
        );
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        expect(
          container
              .read(taskProvider)
              .requireValue
              .firstWhere((t) => t.title == 'Comprar pan')
              .isCompleted,
          isTrue,
        );
        expect(find.text(l.taskCompleted).hitTestable(), findsOneWidget);
        expect(find.text(l.undo).hitTestable(), findsOneWidget);
        expect(sheet(), findsNothing);
        expect(question(l), findsNothing);

        // After the completion message times out: still no question.
        await tester.pump(FeedbackTimeout.defaultDuration * 2);
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(sheet(), findsNothing);
        expect(question(l), findsNothing);
        expect(store.value.asked, isFalse);

        await nextSaveAsks(tester, l);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-448: moving the just-saved task to another day shows the date message with no sheet, then or after it closes',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess();
        await openApp(tester, store, access);
        final l = strings(tester);
        await typeDatedTask(tester, 'Comprar pan');
        expect(find.byType(SnackBar), findsOneWidget);
        final title = find.descendant(
          of: row('Comprar pan'),
          matching: find.text('Comprar pan'),
        );
        await tester.ensureVisible(title);
        await tester.longPress(title);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('schedule-done')), findsOneWidget);
        final now = DateTime.now();
        final moved = l.movedOccurrenceDate(
          tester
              .element(title)
              .weekdayDate(DateTime(now.year, now.month, now.day + 1)),
        );
        await tester.tap(find.widgetWithText(ChoiceChip, l.tomorrow));
        await tester.pumpAndSettle();
        expect(find.text(moved).hitTestable(), findsOneWidget);
        expect(find.text(l.undo).hitTestable(), findsOneWidget);
        expect(sheet(), findsNothing);
        expect(question(l), findsNothing);

        await tester.pump(FeedbackTimeout.defaultDuration * 2);
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(sheet(), findsNothing);
        expect(question(l), findsNothing);
        expect(store.value.asked, isFalse);

        await nextSaveAsks(tester, l);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-448: swiping the save message away counts as seen; the sheet appears',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess();
        await openApp(tester, store, access);
        final l = strings(tester);
        await typeDatedTask(tester, 'Comprar pan');
        expect(find.byType(SnackBar), findsOneWidget);
        expect(sheet(), findsNothing);
        await tester.fling(find.byType(SnackBar), const Offset(0, 300), 1000);
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(sheet(), findsOneWidget);
        expect(question(l), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-449: switching to Notas before the save message closes shows no sheet on Notas; back on Calendario the next dated save asks',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess();
        await openApp(tester, store, access);
        final l = strings(tester);
        await typeDatedTask(tester, 'Comprar pan');
        expect(find.byType(SnackBar), findsOneWidget);
        await tester.tap(tab(l.notes));
        await tester.pumpAndSettle();
        expect(find.byType(NotesScreen).hitTestable(), findsOneWidget);

        await tester.pump(FeedbackTimeout.defaultDuration * 2);
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(sheet(), findsNothing);
        expect(question(l), findsNothing);
        expect(store.value.asked, isFalse);

        await tester.tap(tab(l.calendar));
        await tester.pumpAndSettle();
        expect(find.byType(CalendarScreen).hitTestable(), findsOneWidget);
        // Coming back doesn't bring the old question either.
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(sheet(), findsNothing);

        await nextSaveAsks(tester, l);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-449: tapping the Calendario tab already selected doesn’t stop the question',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess();
        await openApp(tester, store, access);
        final l = strings(tester);
        await typeDatedTask(tester, 'Comprar pan');
        expect(find.byType(SnackBar), findsOneWidget);
        await tester.tap(tab(l.calendar));
        await tester.pumpAndSettle();
        expect(find.byType(CalendarScreen).hitTestable(), findsOneWidget);
        await letSaveMessageClose(tester);
        expect(sheet(), findsOneWidget);
        expect(question(l), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _GivenTasks extends DesignTaskNotifier {
  _GivenTasks(this.initial);
  final List<Task> initial;
  var _next = 100;
  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = AsyncData(initial);
  }

  @override
  Future<int> addTask(Task task) async {
    final id = _next++;
    state = AsyncData([...state.requireValue, task.copyWith(id: id)]);
    return id;
  }
}

/// A capture store in memory: saving marks drafts saved.
class _SavingCaptures extends CaptureStore {
  _SavingCaptures() : super(TaskDatabase());
  CaptureSession? current;
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
    var next = 200;
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
}
