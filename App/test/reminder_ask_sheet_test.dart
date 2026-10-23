import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/edit_task_screen.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/screens/notes_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/feedback_timeout.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/task_editor.dart';
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
    // The time the app reads as now; early today unless a test sets it.
    DateTime Function()? clock,
    // The projects this phone knows; none unless a test sets them.
    List<TaskListInfo>? projects,
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
      projects: projects,
      pro: pro,
      overrides: [
        ...reminderOverrides(store, access),
        // Early today, so a task for today, with or without a time, can
        // still be reminded of and the question comes (UX-1601).
        calendarClockProvider.overrideWithValue(
          clock ??
              () {
                final now = DateTime.now();
                return DateTime(now.year, now.month, now.day, 7);
              },
        ),
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

  /// Without Pro, the task form from Calendar's `Nueva tarea` (2026-10-18
  /// later): [title], on Hoy when [today], then added.
  Future<void> fillForm(
    WidgetTester tester,
    String title, {
    bool today = false,
  }) async {
    final l = strings(tester);
    await tester.tap(find.text(l.newTask).hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('task-title')), title);
    await tester.pumpAndSettle();
    if (today) {
      await tester.tap(find.byKey(const ValueKey('new-task-today')));
      await tester.pumpAndSettle();
    }
    // The task not yet added is never covered by the question.
    expect(question(l), findsNothing);
    await tester.tap(find.byKey(const ValueKey('task-save')));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditor), findsNothing);
  }

  /// Fills in [title] for Hoy in the form from Calendar, and adds it: a
  /// task dated today.
  Future<void> typeDatedTask(WidgetTester tester, String title) =>
      fillForm(tester, title, today: true);

  /// The question waits for the save message to close (UX-439).
  Future<void> letSaveMessageClose(WidgetTester tester) async {
    expect(find.byType(SnackBar), findsOneWidget);
    expect(sheet(), findsNothing);
    await tester.pump(FeedbackTimeout.defaultDuration);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  }

  /// Fills in a task with no date: with no day chosen, it gets none.
  Future<void> typeUndatedTask(WidgetTester tester, String title) =>
      fillForm(tester, title);

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
      // A brand-new account without Pro is told to use Nueva tarea.
      expect(find.text(l.calendarTryForm), findsOneWidget);
      await typeDatedTask(tester, 'Comprar pan');
      expect(find.text(l.calendarTryForm), findsNothing);
      await letSaveMessageClose(tester);
      expect(
        find.descendant(of: sheet(), matching: question(l)),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, l.reminderAskNotNow));
      await tester.pumpAndSettle();
      // Only one question: the instruction never comes back either.
      expect(question(l), findsNothing);
      expect(find.text(l.calendarTryForm), findsNothing);
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
        // A new task's Deshacer only takes it away.
        expect(find.byType(TaskEditor), findsNothing);
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
      'UX-439: opening Nueva tarea before the message closes never covers the form with the sheet; the next dated save asks',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess();
        await openApp(tester, store, access);
        final l = strings(tester);
        await typeDatedTask(tester, 'Comprar pan');
        expect(find.byType(SnackBar), findsOneWidget);
        await tester.tap(find.text(l.newTask).hitTestable());
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditor), findsOneWidget);
        await tester.pump(FeedbackTimeout.defaultDuration * 2);
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditor), findsOneWidget);
        expect(sheet(), findsNothing);
        expect(question(l), findsNothing);
        expect(store.value.asked, isFalse);

        await tester.enterText(
          find.byKey(const ValueKey('task-title')),
          'Llamar a mamá',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('new-task-today')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('task-save')));
        await tester.pumpAndSettle();
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

  // ---- Run 2026-10-19-app, round 1 · P190 (UX-1601): the question waits
  // for a save whose reminder can still ring ----
  group('UX-1601: the question only for a reminder that can come', () {
    // Monday 19 October 2026, at [hour]:[minute].
    DateTime Function() at(int hour, [int minute = 0]) =>
        () => DateTime(2026, 10, 19, hour, minute);

    /// Nueva tarea from Calendar: [title] on the day chip [dayKey], at
    /// [time] when given, then added.
    Future<void> save(
      WidgetTester tester,
      String title, {
      String dayKey = 'new-task-today',
      TimeOfDay? time,
      bool reminderOff = false,
    }) async {
      final l = strings(tester);
      await tester.tap(find.text(l.newTask).hitTestable());
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('task-title')), title);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(dayKey)));
      await tester.pumpAndSettle();
      if (time != null) {
        final add = find.widgetWithText(ActionChip, l.addTime);
        await tester.ensureVisible(add);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pumpAndSettle();
        final dialog = find.byType(TimePickerDialog);
        expect(dialog, findsOneWidget);
        final boxes = find.descendant(
          of: dialog,
          matching: find.byType(TextField),
        );
        final material = MaterialLocalizations.of(tester.element(dialog));
        // A 12-hour picker shows a. m. and p. m.; a 24-hour one takes 17.
        final pm = find.descendant(
          of: dialog,
          matching: find.text(material.postMeridiemAbbreviation),
        );
        final twelve = pm.evaluate().isNotEmpty;
        await tester.enterText(
          boxes.at(0),
          '${twelve ? time.hourOfPeriod : time.hour}',
        );
        await tester.enterText(
          boxes.at(1),
          time.minute.toString().padLeft(2, '0'),
        );
        await tester.pumpAndSettle();
        if (twelve && time.period == DayPeriod.pm) {
          await tester.tap(pm);
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.text(
            MaterialLocalizations.of(tester.element(dialog)).okButtonLabel,
          ),
        );
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
      }
      if (reminderOff) {
        final more = find.byKey(const ValueKey('task-more-details'));
        if (more.evaluate().isNotEmpty) {
          await tester.ensureVisible(more);
          await tester.pumpAndSettle();
          await tester.tap(more);
          await tester.pumpAndSettle();
        }
        final row = find.widgetWithText(ListTile, l.reminder);
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
        final choices = find.byType(BottomSheet);
        expect(choices, findsOneWidget);
        await tester.tap(
          find.descendant(of: choices, matching: find.text(l.off)),
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: row, matching: find.text(l.off)),
          findsOneWidget,
        );
      }
      expect(question(l), findsNothing);
      final add = find.byKey(const ValueKey('task-save'));
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsNothing);
    }

    /// The save message closes, and a little more passes: no question.
    Future<void> noQuestion(
      WidgetTester tester,
      MemoryReminderStore store,
    ) async {
      final l = strings(tester);
      await letSaveMessageClose(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(sheet(), findsNothing);
      expect(question(l), findsNothing);
      // Not marked asked: the next dated save can still ask.
      expect(store.value.asked, isFalse);
    }

    testWidgets(
      'UX-1601: at 11:00, an account never asked with reminders off saves a date-only task for today: no question; one for tomorrow then asks, once',
      (tester) async {
        final store = MemoryReminderStore();
        final access = FakeReminderAccess();
        final container = await openApp(tester, store, access, clock: at(11));
        final l = strings(tester);
        await save(tester, 'Llamar a Marta');
        final saved = container
            .read(taskProvider)
            .requireValue
            .singleWhere((t) => t.title == 'Llamar a Marta');
        expect(Task.day(saved.dueDate!), DateTime(2026, 10, 19));
        expect(saved.hasTime, isFalse);
        await noQuestion(tester, store);

        await save(tester, 'Comprar pan', dayKey: 'new-task-tomorrow');
        await letSaveMessageClose(tester);
        expect(sheet(), findsOneWidget);
        expect(
          find.descendant(of: sheet(), matching: question(l)),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(TextButton, l.reminderAskNotNow));
        await tester.pumpAndSettle();
        expect(store.value.asked, isTrue);

        // Once: another task for tomorrow doesn't ask again.
        await save(tester, 'Pedir cita', dayKey: 'new-task-tomorrow');
        await letSaveMessageClose(tester);
        expect(question(l), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    for (final (hour, minute, asks) in [(16, 55, false), (16, 0, true)]) {
      final clock = '$hour:${minute.toString().padLeft(2, '0')}';
      testWidgets(
        'UX-1601: at $clock, a task for today at 17:00 with the 10-minute default ${asks ? 'brings' : 'brings no'} question',
        (tester) async {
          final store = MemoryReminderStore();
          expect(store.value.leadMinutes, 10);
          final container = await openApp(
            tester,
            store,
            FakeReminderAccess(),
            clock: at(hour, minute),
          );
          final l = strings(tester);
          await save(
            tester,
            'Recoger a los niños',
            time: const TimeOfDay(hour: 17, minute: 0),
          );
          final saved = container
              .read(taskProvider)
              .requireValue
              .singleWhere((t) => t.title == 'Recoger a los niños');
          expect(saved.dueDate, DateTime(2026, 10, 19, 17));
          expect(saved.hasTime, isTrue);
          if (asks) {
            await letSaveMessageClose(tester);
            expect(
              find.descendant(of: sheet(), matching: question(l)),
              findsOneWidget,
            );
          } else {
            await noQuestion(tester, store);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-1601: at 08:00, a date-only task for today brings the question',
      (tester) async {
        final store = MemoryReminderStore();
        await openApp(tester, store, FakeReminderAccess(), clock: at(8));
        final l = strings(tester);
        await save(tester, 'Llamar a Marta');
        await letSaveMessageClose(tester);
        expect(
          find.descendant(of: sheet(), matching: question(l)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1601: a dated task saved with its reminder set to Desactivado brings no question; the next dated save asks',
      (tester) async {
        final store = MemoryReminderStore();
        final container = await openApp(
          tester,
          store,
          FakeReminderAccess(),
          clock: at(7),
        );
        final l = strings(tester);
        await save(
          tester,
          'Comprar pan',
          dayKey: 'new-task-tomorrow',
          reminderOff: true,
        );
        expect(
          container
              .read(taskProvider)
              .requireValue
              .singleWhere((t) => t.title == 'Comprar pan')
              .reminderMinutes,
          -1,
        );
        await noQuestion(tester, store);

        await save(tester, 'Llamar a mamá', dayKey: 'new-task-tomorrow');
        await letSaveMessageClose(tester);
        expect(question(l), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- Run 2026-10-22-changes, round 1 · P263 (UX-2033): the first
  // reminder question only after a save that rings on this phone ----
  group('P263 · the question only for a task that rings here', () {
    const phone = Size(360, 800);
    // Thu 22 Oct 2026, 10:00: tomorrow at 17:00 can still be reminded of.
    DateTime clock() => DateTime(2026, 10, 22, 10);
    const me = ProjectMember(id: 1, name: 'Yo', role: 'owner');
    const marta = ProjectMember(id: 2, name: 'Marta', role: 'editor');
    // A shared project this account owns, with Marta in it.
    final team = TaskListInfo(
      id: 'team',
      name: 'Equipo',
      shared: true,
      ownerId: 1,
      people: const [me, marta],
    );
    // A project of this account's, muted on this phone.
    final quiet = TaskListInfo(
      id: 'quiet',
      name: 'Silencio',
      notifications: 'muted',
    );
    final projects = [team, quiet];

    /// The task form for a new task, opened in [projectId] under
    /// [person]'s chip when given (as the project's page opens it, D7):
    /// [title] for tomorrow at 17:00, then added.
    Future<Task> save(
      WidgetTester tester,
      ProviderContainer container,
      String title, {
      String? projectId,
      ProjectMember? person,
    }) async {
      final l = strings(tester);
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed(
            '/newTask',
            arguments: NewTaskArguments(projectId: projectId, person: person),
          );
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('task-title')), title);
      await tester.pumpAndSettle();
      final tomorrow = find.byKey(const ValueKey('new-task-tomorrow'));
      await tester.ensureVisible(tomorrow);
      await tester.pumpAndSettle();
      await tester.tap(tomorrow);
      await tester.pumpAndSettle();
      final addTime = find.widgetWithText(ActionChip, l.addTime);
      await tester.ensureVisible(addTime);
      await tester.pumpAndSettle();
      await tester.tap(addTime);
      await tester.pumpAndSettle();
      final dialog = find.byType(TimePickerDialog);
      expect(dialog, findsOneWidget);
      final boxes = find.descendant(
        of: dialog,
        matching: find.byType(TextField),
      );
      final material = MaterialLocalizations.of(tester.element(dialog));
      // A 12-hour picker shows a. m. and p. m.; a 24-hour one takes 17.
      final pm = find.descendant(
        of: dialog,
        matching: find.text(material.postMeridiemAbbreviation),
      );
      final twelve = pm.evaluate().isNotEmpty;
      await tester.enterText(boxes.at(0), twelve ? '5' : '17');
      await tester.enterText(boxes.at(1), '00');
      await tester.pumpAndSettle();
      if (twelve) {
        await tester.tap(pm);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(material.okButtonLabel));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(question(l), findsNothing);
      final add = find.byKey(const ValueKey('task-save'));
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsNothing);
      final saved = container
          .read(taskProvider)
          .requireValue
          .singleWhere((t) => t.title == title);
      expect(saved.dueDate, DateTime(2026, 10, 23, 17));
      expect(saved.hasTime, isTrue);
      expect(saved.listId, projectId);
      return saved;
    }

    /// The save message closes, and a little more passes: no question, and
    /// the account is still not asked, with reminders still off.
    Future<void> noQuestion(
      WidgetTester tester,
      MemoryReminderStore store,
    ) async {
      final l = strings(tester);
      await letSaveMessageClose(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(sheet(), findsNothing);
      expect(question(l), findsNothing);
      expect(store.value.asked, isFalse);
      expect(store.value.enabled, isFalse);
    }

    /// The save message closes, then the question shows in its sheet.
    Future<void> asks(WidgetTester tester) async {
      final l = strings(tester);
      await letSaveMessageClose(tester);
      expect(sheet(), findsOneWidget);
      expect(
        find.descendant(of: sheet(), matching: question(l)),
        findsOneWidget,
      );
    }

    testWidgets(
      'UX-2033: a task given to Marta for tomorrow at 17:00 brings no question and leaves the account not asked; a personal one afterwards asks',
      (tester) async {
        final store = MemoryReminderStore();
        expect(store.value.enabled, isFalse);
        expect(store.value.asked, isFalse);
        final container = await openApp(
          tester,
          store,
          FakeReminderAccess(),
          size: phone,
          clock: clock,
          projects: projects,
        );
        final forMarta = await save(
          tester,
          container,
          'Preparar la reunión',
          projectId: 'team',
          person: marta,
        );
        expect(forMarta.assignment, 'member');
        expect(forMarta.assigneeId, 2);
        await noQuestion(tester, store);

        final mine = await save(tester, container, 'Comprar pan');
        expect(mine.assignment, 'personal');
        await asks(tester);
        expect(tester.takeException(), isNull);
      },
    );

    for (final (what, person) in [
      ('a «Todos» task of the shared project', null),
      ('a task of the shared project given to this account', me),
    ]) {
      testWidgets('UX-2033: $what for tomorrow at 17:00 asks, as before', (
        tester,
      ) async {
        final store = MemoryReminderStore();
        final container = await openApp(
          tester,
          store,
          FakeReminderAccess(),
          size: phone,
          clock: clock,
          projects: projects,
        );
        final saved = await save(
          tester,
          container,
          'Preparar la reunión',
          projectId: 'team',
          person: person,
        );
        if (person == null) {
          expect(saved.assignment, 'group');
        } else {
          expect(saved.assignment, 'member');
          expect(saved.assigneeId, 1);
        }
        await asks(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'UX-2033: a task in a project muted on this phone brings no question; a personal one afterwards asks',
      (tester) async {
        final store = MemoryReminderStore();
        final container = await openApp(
          tester,
          store,
          FakeReminderAccess(),
          size: phone,
          clock: clock,
          projects: projects,
        );
        await save(tester, container, 'Regar las plantas', projectId: 'quiet');
        await noQuestion(tester, store);

        await save(tester, container, 'Comprar pan');
        await asks(tester);
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
