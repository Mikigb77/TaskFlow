import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/main.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:agenda/widgets/task_actions.dart';
import 'support/design_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(
    () => platform.setMockMethodCallHandler(timeoutChannel, (_) async => null),
  );
  tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));
  test(
    'appearance restores and keeps the last choice after rapid toggles',
    () async {
      final store = MemoryThemeStore('dark');
      final controller = ThemeController(store);
      await controller.ready;
      expect(controller.state, ThemeMode.dark);
      await Future.wait([
        controller.setMode(ThemeMode.light),
        controller.setMode(ThemeMode.system),
      ]);
      controller.dispose();
      final restored = ThemeController(store);
      await restored.ready;
      expect(restored.state, ThemeMode.system);
      restored.dispose();
    },
  );

  test('a late preference read cannot overwrite a user choice', () async {
    final store = _DelayedStore();
    final controller = ThemeController(store);
    await controller.setMode(ThemeMode.dark);
    store.pending.complete('light');
    await controller.ready;
    expect(controller.state, ThemeMode.dark);
    controller.dispose();
  });

  testWidgets(
    'theme toggle preserves navigation, selected day and editor values',
    (tester) async {
      final store = MemoryThemeStore();
      final container = await _pump(tester, store: store);
      await tester.tap(find.byTooltip('Switch to dark mode'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(CalendarScreen))).brightness,
        Brightness.dark,
      );
      expect(store.value, 'dark');
      await tester.tap(find.byTooltip('Create task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Keep my draft',
      );
      expect(find.byTooltip('Switch to light mode'), findsNothing);
      await container.read(themeModeProvider.notifier).setMode(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(find.text('Keep my draft'), findsOneWidget);
      expect(container.read(themeModeProvider), ThemeMode.light);
    },
  );

  testWidgets('editing completed tasks retains completion and date', (
    tester,
  ) async {
    final container = await _pump(tester);
    final before = container.read(taskProvider).requireValue.first;
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/editTask', arguments: before.id);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-title')),
      'Morning walk',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    final after = container.read(taskProvider).requireValue.first;
    expect(after.isCompleted, isTrue);
    expect(after.dueDate, before.dueDate);
    expect(after.title, 'Morning walk');
  });

  for (final completed in [false, true]) {
    testWidgets(
      'add a time to a saved date without reselecting it (completed: $completed)',
      (tester) async {
        final container = await _pump(tester);
        final notifier = container.read(taskProvider.notifier);
        final before = container
            .read(taskProvider)
            .requireValue
            .first
            .copyWith(
              dueDate: DateTime(2026, 10, 12),
              hasTime: false,
              isCompleted: completed,
            );
        await notifier.updateTask(before);
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .pushNamed('/editTask', arguments: before.id);
        await tester.pumpAndSettle();
        final dateField = find.byKey(const ValueKey('task-date'));
        await tester.ensureVisible(dateField);
        await tester.tap(dateField);
        await tester.pumpAndSettle();
        final time = find.byKey(const ValueKey('schedule-has-time'));
        await tester.ensureVisible(time);
        await tester.tap(time);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('schedule-hour')),
          '10',
        );
        await tester.enterText(
          find.byKey(const ValueKey('schedule-minute')),
          '20',
        );
        await tester.tap(find.byKey(const ValueKey('schedule-done')));
        await tester.pumpAndSettle();
        expect(find.byType(CalendarDatePicker), findsNothing);
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();
        final saved = container.read(taskProvider).requireValue.first;
        expect(saved.dueDate, DateTime(2026, 10, 12, 10, 20));
        expect(saved.hasTime, isTrue);
        expect(saved.isCompleted, completed);
        expect(find.text('Changes saved'), findsOneWidget);
        expect(
          tester.getRect(find.byType(SnackBar)).bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(TaskActions)).top),
        );
        // Save feedback can travel between routes without duplicate snack-bar heroes.
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .pushNamed('/editTask', arguments: before.id);
        await tester.pumpAndSettle();
        await tester.ensureVisible(dateField);
        await tester.tap(dateField);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('schedule-hour')),
              )
              .controller!
              .text,
          '10',
        );
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('schedule-minute')),
              )
              .controller!
              .text,
          '20',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'completion undo works after the task row leaves the active list',
    (tester) async {
      final container = await _pump(tester);
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      final row = find.widgetWithText(TaskTile, 'Review the new designs');
      await tester.tap(
        find.descendant(of: row, matching: find.byType(Checkbox)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Review the new designs'), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(taskProvider)
            .requireValue
            .firstWhere((task) => task.id == 2)
            .isCompleted,
        isFalse,
      );
      expect(find.text('Review the new designs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('calendar feedback leaves capture and navigation reachable', (
    tester,
  ) async {
    final container = await _pump(tester, store: MemoryThemeStore('dark'));
    final row = find.widgetWithText(TaskTile, 'Review the new designs');
    await tester.scrollUntilVisible(
      row,
      160,
      scrollable: find
          .descendant(
            of: find.byType(CalendarScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.descendant(of: row, matching: find.byType(Checkbox)));
    await tester.pumpAndSettle();
    expect(find.text('Task completed'), findsOneWidget);
    expect(
      tester.getRect(find.byType(SnackBar)).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(TaskActions)).top),
    );
    expect(find.text('Undo').hitTestable(), findsOneWidget);
    expect(find.byTooltip('Create task').hitTestable(), findsOneWidget);
    expect(find.text('Say a task').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(taskProvider)
          .requireValue
          .firstWhere((t) => t.id == 2)
          .isCompleted,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('search includes notes and combines with the priority filter', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'blood');
    await tester.pumpAndSettle();
    expect(find.text('Doctor appointment'), findsOneWidget);
    expect(find.text('Review the new designs'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'High priority'));
    await tester.pumpAndSettle();
    expect(find.text('Doctor appointment'), findsOneWidget);
  });

  testWidgets('swipe reschedule and Undo preserve other task fields', (
    tester,
  ) async {
    final container = await _pump(tester);
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.widgetWithText(TaskTile, 'Review the new designs'),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    // Moving: No date applies at once, like Today and Tomorrow.
    await tester.tap(find.widgetWithText(ChoiceChip, 'No date'));
    await tester.pumpAndSettle();
    final moved = container
        .read(taskProvider)
        .requireValue
        .firstWhere((t) => t.id == 2);
    expect(moved.dueDate, isNull);
    expect(moved.notes, 'Bring your ideas for the next release.');
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(taskProvider)
          .requireValue
          .firstWhere((t) => t.id == 2)
          .dueDate,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Calendar starts compact, hides an empty Inbox and opens task actions',
    (tester) async {
      final container = await _pump(tester);
      expect(find.text('Week'), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar-inbox')), findsNothing);
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/inbox');
      await tester.pumpAndSettle();
      expect(find.text('NO DATE NEEDED'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'All tasks'), findsNothing);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      final row = find.widgetWithText(TaskTile, 'Review the new designs');
      await tester.scrollUntilVisible(
        row,
        160,
        scrollable: find
            .descendant(
              of: find.byType(CalendarScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OutlinedButton, 'Reschedule'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(taskProvider)
            .requireValue
            .firstWhere((t) => t.id == 2)
            .isCompleted,
        isTrue,
      );
      expect(find.widgetWithText(FilledButton, 'Reopen'), findsOneWidget);
      expect(find.text('Low priority'), findsNothing);
    },
  );

  testWidgets(
    'UX-303: Tasks search finds accented tasks typed without accents',
    (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final container = await _pump(tester);
      final now = DateTime.now();
      await container.read(taskProvider.notifier).addTasks([
        Task(
          title: 'Llamar al Médico',
          dueDate: DateTime(now.year, now.month, now.day, 16),
          priority: 1,
        ),
        Task(
          title: 'Reunión con José',
          dueDate: DateTime(now.year, now.month, now.day, 17),
          priority: 1,
        ),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.tasks));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'medico');
      await tester.pumpAndSettle();
      expect(find.text('Llamar al Médico'), findsOneWidget);
      expect(find.text('Reunión con José'), findsNothing);
      expect(find.text('Doctor appointment'), findsNothing);
      expect(find.text(l10n.noMatches), findsNothing);
      await tester.enterText(find.byType(TextField), 'reunion con jose');
      await tester.pumpAndSettle();
      expect(find.text('Reunión con José'), findsOneWidget);
      expect(find.text('Llamar al Médico'), findsNothing);
      await tester.enterText(find.byType(TextField), 'dentista');
      await tester.pumpAndSettle();
      expect(find.text(l10n.noMatches), findsOneWidget);
    },
  );

  testWidgets(
    'UX-412: text-field outlines reach 3:1 against the field and the page in both themes',
    (tester) async {
      final container = await _pump(tester);
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await setAppearance(container, mode);
        await tester.pumpAndSettle();
        final field = find.byType(TextField).first;
        final theme = Theme.of(tester.element(field));
        final decoration = tester
            .widget<InputDecorator>(
              find.descendant(of: field, matching: find.byType(InputDecorator)),
            )
            .decoration;
        final border = decoration.enabledBorder!.borderSide.color;
        expect(border, theme.colorScheme.outline, reason: '$mode');
        final fill = decoration.filled == true
            ? decoration.fillColor!
            : theme.colorScheme.surface;
        expect(
          _contrast(border, fill),
          greaterThanOrEqualTo(3),
          reason: '$mode border on the field fill',
        );
        expect(
          _contrast(border, theme.scaffoldBackgroundColor),
          greaterThanOrEqualTo(3),
          reason: '$mode border on the page',
        );
        expect(
          _contrast(border, theme.colorScheme.surface),
          greaterThanOrEqualTo(3),
          reason: '$mode border on a card',
        );
      }
    },
  );

  testWidgets(
    'UX-413 / UX-421: the selected tab label is bolder and darker, 12 sp, in both themes',
    (tester) async {
      final container = await _pump(tester);
      final bar = find.byType(NavigationBar);
      TextStyle label(String text) => tester
          .widget<Text>(
            find.descendant(of: bar, matching: find.text(text)).first,
          )
          .style!;
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await setAppearance(container, mode);
        await tester.pumpAndSettle();
        final scheme = Theme.of(tester.element(bar)).colorScheme;
        for (final (selected, other) in [
          ('Calendar', 'Tasks'),
          ('Tasks', 'Calendar'),
        ]) {
          await tester.tap(
            find.descendant(of: bar, matching: find.text(selected)),
          );
          await tester.pumpAndSettle();
          final on = label(selected);
          final off = label(other);
          final reason = '$mode, $selected selected';
          expect(on.fontWeight, FontWeight.w800, reason: reason);
          expect(off.fontWeight, FontWeight.w500, reason: reason);
          expect(on.color, scheme.onSurface, reason: reason);
          expect(off.color, scheme.onSurfaceVariant, reason: reason);
          expect(on.fontSize, 12, reason: reason);
          expect(off.fontSize, 12, reason: reason);
          for (final style in [on, off]) {
            expect(
              _contrast(style.color!, scheme.surface),
              greaterThanOrEqualTo(4.5),
              reason: '$reason: label text contrast',
            );
          }
        }
      }
    },
  );

  testWidgets('UX-413: every tab swaps to a different icon when selected', (
    tester,
  ) async {
    await _pump(tester);
    final bar = find.byType(NavigationBar);
    final destinations = tester
        .widgetList<NavigationDestination>(
          find.descendant(
            of: bar,
            matching: find.byType(NavigationDestination),
          ),
        )
        .toList();
    expect(destinations, hasLength(4));
    for (final destination in destinations) {
      final icon = (destination.icon as Icon).icon;
      final selectedIcon = (destination.selectedIcon as Icon).icon;
      expect(selectedIcon, isNot(icon), reason: destination.label);
      await tester.tap(
        find.descendant(of: bar, matching: find.text(destination.label)),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.widgetWithText(NavigationDestination, destination.label),
          matching: find.byIcon(selectedIcon!),
        ),
        findsOneWidget,
        reason: '${destination.label} selected',
      );
      for (final other in destinations.where((d) => d != destination)) {
        expect(
          find.descendant(
            of: find.widgetWithText(NavigationDestination, other.label),
            matching: find.byIcon((other.selectedIcon as Icon).icon!),
          ),
          findsNothing,
          reason: '${other.label} while ${destination.label} is selected',
        );
      }
    }
    await tester.tap(find.descendant(of: bar, matching: find.text('Calendar')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(360, 800),
    const Size(320, 568),
    const Size(740, 360),
  ]) {
    testWidgets(
      'primary screens support $size with larger text in both themes',
      (tester) async {
        final container = await _pump(tester, size: size, largeText: true);
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          await setAppearance(container, mode);
          await tester.pumpAndSettle();
          for (final tab in ['Tasks', 'Settings', 'Calendar']) {
            await tester.tap(find.text(tab).last);
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$tab, $size, $mode',
            );
          }
        }
      },
    );
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  MemoryThemeStore? store,
  Size size = const Size(390, 844),
  bool largeText = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  if (largeText) tester.platformDispatcher.textScaleFactorTestValue = 1.6;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final container = designContainer(store: store);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

class _DelayedStore extends MemoryThemeStore {
  final pending = Completer<String?>();
  @override
  Future<String?> read() => pending.future;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}
