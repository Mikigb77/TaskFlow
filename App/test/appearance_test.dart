import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/main.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'support/design_fixtures.dart';

void main() {
  test('appearance restores and keeps the last choice after rapid toggles',
      () async {
    final store = MemoryThemeStore('dark');
    final controller = ThemeController(store);
    await controller.ready;
    expect(controller.state, ThemeMode.dark);
    await Future.wait([
      controller.setMode(ThemeMode.light),
      controller.setMode(ThemeMode.system)
    ]);
    controller.dispose();
    final restored = ThemeController(store);
    await restored.ready;
    expect(restored.state, ThemeMode.system);
    restored.dispose();
  });

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
    expect(Theme.of(tester.element(find.byType(CalendarScreen))).brightness,
        Brightness.dark);
    expect(store.value, 'dark');
    await tester.tap(find.byTooltip('Create task'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('task-title')), 'Keep my draft');
    await tester.tap(find.byTooltip('Switch to light mode'));
    await tester.pumpAndSettle();
    expect(find.text('Keep my draft'), findsOneWidget);
    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  testWidgets('editing completed tasks retains completion and date',
      (tester) async {
    final container = await _pump(tester);
    final before = container.read(taskProvider).requireValue.first;
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/editTask', arguments: before.id);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('task-title')), 'Morning walk');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    final after = container.read(taskProvider).requireValue.first;
    expect(after.isCompleted, isTrue);
    expect(after.dueDate, before.dueDate);
    expect(after.title, 'Morning walk');
  });

  testWidgets('completion undo works after the task row leaves the active list',
      (tester) async {
    final container = await _pump(tester);
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    final row = find.widgetWithText(TaskTile, 'Review the new designs');
    await tester.tap(find.descendant(of: row, matching: find.byType(Checkbox)));
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
        isFalse);
    expect(find.text('Review the new designs'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search includes notes and combines with the priority filter',
      (tester) async {
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

  testWidgets('swipe reschedule and Undo preserve other task fields',
      (tester) async {
    final container = await _pump(tester);
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    await tester.drag(find.widgetWithText(TaskTile, 'Review the new designs'),
        const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Inbox'));
    await tester.tap(find.text('Save schedule'));
    await tester.pumpAndSettle();
    final moved =
        container.read(taskProvider).requireValue.firstWhere((t) => t.id == 2);
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
        isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Calendar starts compact, keeps empty Inbox visible and opens task actions',
      (tester) async {
    final container = await _pump(tester);
    expect(find.text('Month view'), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-inbox')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('calendar-inbox')));
    await tester.pumpAndSettle();
    expect(find.text('NO DATE NEEDED'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'All tasks'), findsNothing);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    final row = find.widgetWithText(TaskTile, 'Review the new designs');
    await tester.scrollUntilVisible(row, 160,
        scrollable: find
            .descendant(
                of: find.byType(CalendarScreen),
                matching: find.byType(Scrollable))
            .first);
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
        isTrue);
    expect(find.widgetWithText(FilledButton, 'Reopen'), findsOneWidget);
    expect(find.text('Low priority'), findsNothing);
  });

  for (final size in [
    const Size(360, 800),
    const Size(320, 568),
    const Size(740, 360)
  ]) {
    testWidgets('primary screens support $size with larger text in both themes',
        (tester) async {
      final container = await _pump(tester, size: size, largeText: true);
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await setAppearance(container, mode);
        await tester.pumpAndSettle();
        for (final tab in ['Tasks', 'Settings', 'Calendar']) {
          await tester.tap(find.text(tab).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$tab, $size, $mode');
        }
      }
    });
  }
}

Future<ProviderContainer> _pump(WidgetTester tester,
    {MemoryThemeStore? store,
    Size size = const Size(390, 844),
    bool largeText = false}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  if (largeText) tester.platformDispatcher.textScaleFactorTestValue = 1.6;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final container = designContainer(store: store);
  addTearDown(container.dispose);
  await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()));
  await tester.pumpAndSettle();
  return container;
}

class _DelayedStore extends MemoryThemeStore {
  final pending = Completer<String?>();
  @override
  Future<String?> read() => pending.future;
}
