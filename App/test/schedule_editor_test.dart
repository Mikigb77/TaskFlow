import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/widgets/schedule_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' show Tristate;

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
}
