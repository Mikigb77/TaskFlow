import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/widgets/schedule_editor.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' show Tristate;

import 'support/design_fixtures.dart';

/// The app in Spanish with [clock], with TaskEditor open on [task].
Future<void> openEditorEs(
  WidgetTester tester,
  Task task, {
  ClockFormat clock = ClockFormat.twentyFour,
}) async {
  final messenger = tester.binding.defaultBinaryMessenger;
  const timeout = MethodChannel('taskflow/accessibility');
  messenger.setMockMethodCallHandler(timeout, (_) async => null);
  addTearDown(() => messenger.setMockMethodCallHandler(timeout, null));
  final container = designContainer(
    regionalStore: MemoryRegionalStore(
      RegionalPreferences(language: 'es', clock: clock, weekStart: 1),
    ),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
  await tester.pumpAndSettle();
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .push(MaterialPageRoute<void>(builder: (_) => TaskEditor(task: task)));
  await tester.pumpAndSettle();
}

/// TaskEditor's date row opens the shared date sheet.
Future<void> openEditorDate(WidgetTester tester) async {
  final date = find.byKey(const ValueKey('task-date'));
  await tester.ensureVisible(date);
  await tester.pumpAndSettle();
  await tester.tap(date);
  await tester.pumpAndSettle();
}

Future<void> openSchedule(
  WidgetTester tester, {
  DateTime? date,
  bool hasTime = false,
  bool clock24 = true,
  String language = 'en',
  required ValueChanged<ScheduleChoice?> onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: clock24),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => onResult(
              await editSchedule(context, date: date, hasTime: hasTime),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> chooseTime(WidgetTester tester, String hour, String minute) async {
  final toggle = find.byKey(const ValueKey('schedule-has-time'));
  await tester.ensureVisible(toggle);
  await tester.pumpAndSettle();
  if (!tester.widget<SwitchListTile>(toggle).value) {
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.byKey(const ValueKey('schedule-hour')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('schedule-hour')), hour);
  await tester.enterText(find.byKey(const ValueKey('schedule-minute')), minute);
}

void main() {
  testWidgets('No date never presents today as the selected day', (
    tester,
  ) async {
    await openSchedule(tester, onResult: (_) {});
    final today = find.descendant(
      of: find.byType(CalendarDatePicker),
      matching: find.text('${DateTime.now().day}'),
    );
    expect(
      tester.getSemantics(today).flagsCollection.isSelected,
      Tristate.isFalse,
    );
    await tester.tap(today);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(today).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'No date'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(today).flagsCollection.isSelected,
      Tristate.isFalse,
    );
  });

  testWidgets('adding time uses the existing date without a calendar tap', (
    tester,
  ) async {
    ScheduleChoice? result;
    await openSchedule(
      tester,
      date: DateTime(2026, 10, 12),
      onResult: (value) => result = value,
    );
    await chooseTime(tester, '10', '20');
    await tester.tap(find.byKey(const ValueKey('schedule-done')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(result!.date, DateTime(2026, 10, 12, 10, 20));
    expect(result!.hasTime, isTrue);
  });

  testWidgets('an untouched calendar never invents a date or midnight', (
    tester,
  ) async {
    ScheduleChoice? result;
    await openSchedule(tester, onResult: (value) => result = value);
    await tester.tap(find.byKey(const ValueKey('schedule-done')));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.date, isNull);
    expect(result!.hasTime, isFalse);
  });

  testWidgets(
    'time requires a selected day and rejects invalid hours and minutes',
    (tester) async {
      ScheduleChoice? result;
      await openSchedule(tester, onResult: (value) => result = value);
      await chooseTime(tester, '25', '61');
      await tester.tap(find.byKey(const ValueKey('schedule-done')));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.byKey(const ValueKey('schedule-done')), findsOneWidget);
      await tester.ensureVisible(find.text('Tomorrow'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomorrow'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-done')));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await chooseTime(tester, '0', '00');
      await tester.tap(find.byKey(const ValueKey('schedule-done')));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      expect(result!.date, DateTime(now.year, now.month, now.day + 1));
      expect(
        result!.hasTime,
        isTrue,
        reason: 'Explicit midnight is a valid time.',
      );
    },
  );

  for (final hour in ['12', '5']) {
    testWidgets('12-hour clock preserves an explicit $hour PM', (tester) async {
      ScheduleChoice? result;
      await openSchedule(
        tester,
        date: DateTime(2026, 10, 13),
        clock24: false,
        onResult: (value) => result = value,
      );
      await chooseTime(tester, hour, '15');
      await tester.ensureVisible(find.text('PM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PM'));
      await tester.tap(find.byKey(const ValueKey('schedule-done')));
      await tester.pumpAndSettle();
      expect(result!.date, DateTime(2026, 10, 13, hour == '12' ? 12 : 17, 15));
      expect(result!.hasTime, isTrue);
    });
  }

  testWidgets('cancelling discards edits and preserves the existing value', (
    tester,
  ) async {
    var completed = false;
    ScheduleChoice? result;
    await openSchedule(
      tester,
      date: DateTime(2026, 10, 13, 18, 45),
      hasTime: true,
      onResult: (value) {
        completed = true;
        result = value;
      },
    );
    await chooseTime(tester, '9', '10');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(result, isNull);
  });

  for (final language in ['en', 'es', 'ca']) {
    testWidgets(
      '$language date/time remains usable on a small screen with large text and keyboard',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        ScheduleChoice? result;
        await openSchedule(
          tester,
          date: DateTime(2026, 10, 13),
          language: language,
          onResult: (value) => result = value,
        );
        await chooseTime(tester, '18', '45');
        tester.view.viewInsets = const FakeViewPadding(bottom: 200);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('schedule-done')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('schedule-done')));
        await tester.pumpAndSettle();
        expect(result!.date, DateTime(2026, 10, 13, 18, 45));
      },
    );
  }

  testWidgets('UX-221: hour 9 with empty minutes saves 9:00', (tester) async {
    ScheduleChoice? result;
    await openSchedule(
      tester,
      date: DateTime(2026, 10, 13),
      language: 'es',
      onResult: (value) => result = value,
    );
    await chooseTime(tester, '9', '');
    await tester.tap(find.byKey(const ValueKey('schedule-done')));
    await tester.pumpAndSettle();
    final l = lookupAppLocalizations(const Locale('es'));
    expect(find.text(l.reviewInvalidTime), findsNothing);
    expect(result, isNotNull);
    expect(result!.date, DateTime(2026, 10, 13, 9));
    expect(result!.hasTime, isTrue);
  });

  testWidgets(
    'UX-221: with a 12-hour clock and no earlier time, neither a. m. nor p. m. is chosen and Listo asks for one',
    (tester) async {
      ScheduleChoice? result;
      var closed = false;
      await openSchedule(
        tester,
        date: DateTime(2026, 10, 13),
        clock24: false,
        language: 'es',
        onResult: (value) {
          closed = true;
          result = value;
        },
      );
      final l = lookupAppLocalizations(const Locale('es'));
      expect(l.chooseAmPm, 'Elige a. m. o p. m.');
      await chooseTime(tester, '5', '30');
      final material = MaterialLocalizations.of(
        tester.element(find.byKey(const ValueKey('schedule-hour'))),
      );
      final am = find.widgetWithText(
        ChoiceChip,
        material.anteMeridiemAbbreviation,
      );
      final pm = find.widgetWithText(
        ChoiceChip,
        material.postMeridiemAbbreviation,
      );
      await tester.ensureVisible(pm);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(am).selected, isFalse);
      expect(tester.widget<ChoiceChip>(pm).selected, isFalse);
      expect(find.text(l.chooseAmPm), findsNothing);
      await tester.tap(find.byKey(const ValueKey('schedule-done')));
      await tester.pumpAndSettle();
      expect(closed, isFalse);
      expect(find.text(l.chooseAmPm), findsOneWidget);
      await tester.ensureVisible(pm);
      await tester.tap(pm);
      await tester.pumpAndSettle();
      expect(find.text(l.chooseAmPm), findsNothing);
      await tester.tap(find.byKey(const ValueKey('schedule-done')));
      await tester.pumpAndSettle();
      expect(result!.date, DateTime(2026, 10, 13, 17, 30));
    },
  );

  testWidgets(
    'UX-221: a 12-hour clock keeps an existing time’s a. m. / p. m.',
    (tester) async {
      await openSchedule(
        tester,
        date: DateTime(2026, 10, 13, 18, 45),
        hasTime: true,
        clock24: false,
        onResult: (_) {},
      );
      final pm = find.widgetWithText(ChoiceChip, 'PM');
      await tester.ensureVisible(pm);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(pm).selected, isTrue);
    },
  );

  // ---- P61: the date sheet's Listo, Sin fecha and labels ----

  final es = lookupAppLocalizations(const Locale('es'));
  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  testWidgets(
    'UX-452: 12-hour clock, 2× text, 360×640, keyboard up: Listo after typing 5 drops the hour’s focus and shows Elige a. m. o p. m. in view, as a live region',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openEditorEs(
        tester,
        Task(
          id: 1,
          title: 'Llamar al médico',
          priority: 1,
          dueDate: today(),
          hasTime: false,
        ),
        clock: ClockFormat.twelve,
      );
      await openEditorDate(tester);
      final toggle = find.byKey(const ValueKey('schedule-has-time'));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final hour = find.byKey(const ValueKey('schedule-hour'));
      await tester.ensureVisible(hour);
      await tester.pumpAndSettle();
      await tester.enterText(hour, '5');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      bool hourFocused() => tester
          .widget<EditableText>(
            find.descendant(of: hour, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus;
      expect(hourFocused(), isTrue);
      expect(find.text(es.chooseAmPm), findsNothing);

      final done = find.byKey(const ValueKey('schedule-done'));
      expect(done.hitTestable(), findsOneWidget);
      await tester.tap(done);
      await tester.pumpAndSettle();

      expect(done, findsOneWidget, reason: 'the sheet stays open');
      expect(hourFocused(), isFalse);
      expect(es.chooseAmPm, 'Elige a. m. o p. m.');
      final message = find.text(es.chooseAmPm);
      expect(message.hitTestable(), findsOneWidget);
      final viewport = tester.getRect(
        find.ancestor(of: message, matching: find.byType(Scrollable)).first,
      );
      final rect = tester.getRect(message);
      expect(rect.top, greaterThanOrEqualTo(viewport.top));
      expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
      // Above the keyboard.
      expect(rect.bottom, lessThanOrEqualTo(640 - 300));
      final node = find.semantics.byLabel(es.chooseAmPm);
      expect(node, findsOne);
      expect(
        node.evaluate().single.getSemanticsData().flagsCollection.isLiveRegion,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'UX-453: in TaskEditor’s date sheet, Sin fecha only selects; the sheet stays open until Listo',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openEditorEs(
        tester,
        Task(
          id: 1,
          title: 'Llamar al médico',
          priority: 1,
          dueDate: today(),
          hasTime: false,
        ),
      );
      await openEditorDate(tester);
      final noDate = find.widgetWithText(ChoiceChip, es.noDate);
      await tester.tap(noDate);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-done')), findsOneWidget);
      expect(tester.widget<ChoiceChip>(noDate).selected, isTrue);
      await tester.tap(find.byKey(const ValueKey('schedule-done')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-done')), findsNothing);
      expect(find.byType(TaskEditor), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-455: TaskEditor → Repetir opens the repeat sheet with Listo, not Guardar repetición',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openEditorEs(
        tester,
        Task(
          id: 1,
          title: 'Regar las plantas',
          priority: 1,
          dueDate: today(),
          hasTime: false,
        ),
      );
      final more = find.byKey(const ValueKey('task-more-details'));
      if (find.byKey(const ValueKey('task-repeat')).evaluate().isEmpty &&
          more.evaluate().isNotEmpty) {
        await tester.ensureVisible(more);
        await tester.pumpAndSettle();
        await tester.tap(more);
        await tester.pumpAndSettle();
      }
      final repeat = find.byKey(const ValueKey('task-repeat'));
      await tester.ensureVisible(repeat);
      await tester.pumpAndSettle();
      await tester.tap(repeat);
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      expect(es.done, 'Listo');
      expect(
        find.descendant(
          of: sheet,
          matching: find.widgetWithText(FilledButton, es.done),
        ),
        findsOneWidget,
      );
      expect(find.text('Guardar repetición'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
