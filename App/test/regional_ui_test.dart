import 'package:agenda/l10n/region.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/regional_settings_screen.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:agenda/widgets/task_schedule_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_calendar/table_calendar.dart';
import 'support/design_fixtures.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter_timezone'), (_) async => 'UTC');
  });
  for (final sample in [
    (
      const Locale('en', 'US'),
      StartingDayOfWeek.sunday,
      TimeOfDayFormat.h_colon_mm_space_a,
      'Your calendar'
    ),
    (
      const Locale('en', 'GB'),
      StartingDayOfWeek.monday,
      TimeOfDayFormat.HH_colon_mm,
      'Your calendar'
    ),
    (
      const Locale('es', 'ES'),
      StartingDayOfWeek.monday,
      TimeOfDayFormat.H_colon_mm,
      'Tu calendario'
    ),
  ]) {
    testWidgets('device defaults follow ${sample.$1}', (tester) async {
      tester.platformDispatcher.localesTestValue = [sample.$1];
      tester.platformDispatcher.alwaysUse24HourFormatTestValue =
          sample.$1.countryCode != 'US';
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
      final container = designContainer(
          regionalStore: MemoryRegionalStore(const RegionalPreferences()));
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: const MyApp()));
      await tester.pumpAndSettle();
      final calendar =
          tester.widget<TableCalendar<Task>>(find.byType(TableCalendar<Task>));
      expect(calendar.startingDayOfWeek, sample.$2);
      final context = tester.element(find.byType(CalendarScreen));
      expect(MaterialLocalizations.of(context).timeOfDayFormat(), sample.$3);
      expect(find.text(sample.$4), findsOneWidget);
      final dateOnly = Task(
          title: 'Date',
          priority: 1,
          dueDate: DateTime(2026, 9, 25),
          hasTime: false);
      expect(taskScheduleLabel(dateOnly, context: context),
          contains(context.l10n.anyTime));
      final midnight = dateOnly.copyWith(hasTime: true);
      expect(taskScheduleLabel(midnight, context: context),
          isNot(contains(context.l10n.anyTime)));
      if (sample.$1.countryCode == 'GB') {
        tester.platformDispatcher.alwaysUse24HourFormatTestValue = false;
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();
        expect(MaterialLocalizations.of(context).timeOfDayFormat(),
            TimeOfDayFormat.h_colon_mm_space_a);
        expect(container.read(regionalProvider).clock, ClockFormat.system);
        expect(
            context.clockTime(DateTime(2026, 9, 25, 18, 45)), contains('6:45'));
      }
    });
  }

  testWidgets(
      'changing UI language and clock keeps the open editor and date, with consistent pickers',
      (tester) async {
    tester.platformDispatcher.localesTestValue = [const Locale('es', 'ES')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final container = designContainer(
        regionalStore:
            MemoryRegionalStore(const RegionalPreferences(language: 'en')));
    addTearDown(container.dispose);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(
        builder: (_) => TaskEditor(
            task: Task(
                id: 99,
                title: 'Do not translate my words',
                priority: 1,
                dueDate: DateTime(2205, 2, 3, 18, 45)))));
    await tester.pumpAndSettle();
    final controller = container.read(regionalProvider.notifier);
    await controller.set(const RegionalPreferences(
        language: 'es', clock: ClockFormat.twelve, weekStart: 0));
    await tester.pumpAndSettle();
    expect(find.text('Editar tarea'), findsOneWidget);
    expect(find.text('Do not translate my words'), findsOneWidget);
    final context = tester.element(find.byType(TaskEditor));
    expect(context.clockTime(DateTime(2205, 2, 3, 18, 45)), contains('6:45'));
    expect(MaterialLocalizations.of(context).firstDayOfWeekIndex, 0);
    final time = find.byKey(const ValueKey('task-time'));
    await tester.ensureVisible(time);
    await tester.pumpAndSettle();
    await tester.tap(time);
    await tester.pumpAndSettle();
    final picker = find.byType(TimePickerDialog);
    expect(tester.widget<TimePickerDialog>(picker).initialTime,
        const TimeOfDay(hour: 18, minute: 45));
    expect(MaterialLocalizations.of(tester.element(picker)).timeOfDayFormat(),
        TimeOfDayFormat.h_colon_mm_space_a);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await controller.set(const RegionalPreferences(
        language: 'en', clock: ClockFormat.twentyFour, weekStart: 6));
    await tester.pumpAndSettle();
    expect(find.text('18:45'), findsOneWidget);
    expect(find.text('Edit task'), findsOneWidget);
    final date = find.byKey(const ValueKey('task-date'));
    await tester.ensureVisible(date);
    await tester.pumpAndSettle();
    await tester.tap(date);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DatePickerDialog>(find.byType(DatePickerDialog))
            .initialDate,
        DateTime(2205, 2, 3));
    expect(
        MaterialLocalizations.of(tester.element(find.byType(DatePickerDialog)))
            .firstDayOfWeekIndex,
        6);
    expect(tester.takeException(), isNull);
  });

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('Spanish regional settings at 2x text remain usable in $theme',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store =
          MemoryRegionalStore(const RegionalPreferences(language: 'es'));
      final container = designContainer(regionalStore: store);
      addTearDown(container.dispose);
      await container.read(themeModeProvider.notifier).setMode(theme);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: const MyApp()));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/region');
      await tester.pumpAndSettle();
      expect(find.byType(RegionalSettingsScreen), findsOneWidget);
      expect(find.text('Idioma y región'), findsOneWidget);
      final clock = find.byKey(const ValueKey('regional-clock'));
      await tester.scrollUntilVisible(clock, 160,
          scrollable: find
              .descendant(
                  of: find.byType(RegionalSettingsScreen),
                  matching: find.byType(Scrollable))
              .first);
      await tester.pumpAndSettle();
      await tester.tap(clock);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reloj de 12 horas').last);
      await tester.pumpAndSettle();
      expect(store.value.clock, ClockFormat.twelve);
      expect(tester.takeException(), isNull);
    });
  }
}
