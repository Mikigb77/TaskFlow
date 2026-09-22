import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/day_timeline_screen.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/task_planning_control.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';

void main() {
  testWidgets('deadline reminder label wraps inside the chip at 2x text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = designContainer();
    addTearDown(container.dispose);
    for (final language in ['en', 'es']) {
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!),
              home: Scaffold(
                  body: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ReminderChip(
                          task: Task(
                              title: 'Report',
                              priority: 1,
                              deadline: DateTime(2026, 9, 23, 17),
                              deadlineHasTime: true,
                              reminderAnchor: 'deadline',
                              reminderMinutes: 60),
                          onChanged: (_) {}))))));
      await tester.pumpAndSettle();
      final chip = find.byType(ActionChip);
      final label = find.descendant(of: chip, matching: find.byType(Text));
      expect(tester.getSize(label).height, greaterThan(60));
      expect(tester.getRect(label).bottom,
          lessThanOrEqualTo(tester.getRect(chip).bottom));
      expect(tester.getRect(chip).right, lessThanOrEqualTo(296));
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
      'planning controls validate duration and fit both languages/themes at 2x text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final language in ['en', 'es']) {
      for (final dark in [false, true]) {
        var task = Task(
            id: 1,
            title: 'Report',
            priority: 1,
            dueDate: DateTime(2026, 9, 22, 9),
            deadline: DateTime(2026, 9, 23),
            durationMinutes: 30,
            reminderAnchor: 'deadline');
        final originalStart = task.dueDate;
        await tester.pumpWidget(MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: dark ? AppTheme.dark : AppTheme.light,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!),
            home: Scaffold(
                body: StatefulBuilder(
                    builder: (context, update) =>
                        ListView(padding: const EdgeInsets.all(16), children: [
                          TaskPlanningControl(
                              task: task,
                              onChanged: (value) => update(() => task = value))
                        ])))));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('task-duration')));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.byKey(const ValueKey('duration-input')), '0');
        await tester.tap(find.byKey(const ValueKey('duration-save')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(task.durationMinutes, 30);
        await tester.enterText(
            find.byKey(const ValueKey('duration-input')), '75');
        await tester.tap(find.byKey(const ValueKey('duration-save')));
        await tester.pumpAndSettle();
        expect(task.durationMinutes, 75);
        final remove = find.byTooltip(
            language == 'en' ? 'Remove deadline' : 'Quitar fecha límite');
        await tester.scrollUntilVisible(remove, 150);
        await tester.pumpAndSettle();
        await tester.tap(remove);
        await tester.pumpAndSettle();
        expect(task.deadline, isNull);
        expect(task.reminderAnchor, 'planned');
        expect(task.dueDate, originalStart);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
  testWidgets(
      'hourly timeline is scrollable and tappable at large text in light/dark',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final dark in [false, true]) {
      final container =
          designContainer(store: MemoryThemeStore(dark ? 'dark' : 'light'));
      await container.read(taskProvider.notifier).loadTasks();
      final now = DateTime.now();
      await container.read(taskProvider.notifier).addTask(Task(
          title: 'Timed block',
          priority: 1,
          dueDate: DateTime(now.year, now.month, now.day, 7, 30),
          durationMinutes: 90,
          deadline: DateTime(now.year, now.month, now.day, 17),
          deadlineHasTime: true));
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: dark ? AppTheme.dark : AppTheme.light,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!),
              home: DayTimelineScreen(day: now))));
      await tester.pumpAndSettle();
      final jump = find.text('Jump to first timed item');
      await tester.scrollUntilVisible(jump, 150,
          scrollable: find
              .descendant(
                  of: find.byKey(const ValueKey('timeline-scroll')),
                  matching: find.byType(Scrollable))
              .first);
      await tester.pumpAndSettle();
      await tester.tap(jump);
      await tester.pumpAndSettle();
      expect(find.text('Timed block').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Timed block'));
      await tester.pumpAndSettle();
      expect(find.text('Task details'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    }
  });
}
