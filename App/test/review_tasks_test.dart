import 'package:agenda/main.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/review_tasks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';

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
    WidgetTester tester, List<TaskDraft> drafts) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = designContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()));
  await tester.pumpAndSettle();
  tester.state<NavigatorState>(find.byType(Navigator)).push(
      MaterialPageRoute<void>(
          builder: (_) => ReviewTasksScreen(
              drafts: drafts, transcript: 'Buy coffee. Pay invoice Friday.')));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
      'review and schedule editor fit small screens with large text in both themes',
      (tester) async {
    final container = await openReview(tester, [
      draft('Pay invoice'),
      draft('A longer task title that needs room to wrap safely')
    ]);
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await setAppearance(container, mode);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final edit = find.byTooltip('Edit Pay invoice');
      await tester.scrollUntilVisible(edit, 160);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      final repeat = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(repeat);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('guest reviews, edits and saves several tasks together',
      (tester) async {
    final container =
        await openReview(tester, [draft('Buy coffee'), draft('Pay invoice')]);
    expect(find.text('Inbox · No date'), findsOneWidget);
    expect(find.text('25 Sep · Any time'), findsOneWidget);
    expect(container.read(taskProvider).requireValue.length, 4);
    await tester.tap(find.byTooltip('Edit Buy coffee'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('task-title')), 'Buy decaf');
    await tester.tap(find.text('Keep changes'));
    await tester.pumpAndSettle();
    expect(container.read(taskProvider).requireValue.length, 4);
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await tester.pumpAndSettle();
    final tasks = container.read(taskProvider).requireValue;
    expect(tasks.length, 6);
    expect(tasks.firstWhere((t) => t.title == 'Buy decaf').dueDate, isNull);
    expect(tasks.firstWhere((t) => t.title == 'Pay invoice').hasTime, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ambiguity requires review and removed drafts are not saved',
      (tester) async {
    final container = await openReview(
        tester, [draft('Call', ambiguous: true), draft('Remove me')]);
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await tester.pumpAndSettle();
    expect(container.read(taskProvider).requireValue.length, 4);
    final remove = find.byTooltip('Remove Remove me');
    await tester.scrollUntilVisible(remove, 200);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    final confirm = find.text('Use the details shown');
    await tester.scrollUntilVisible(confirm, -200);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await tester.pumpAndSettle();
    expect(container.read(taskProvider).requireValue.length, 5);
    expect(container.read(taskProvider).requireValue.last.title, 'Call');
    expect(tester.takeException(), isNull);
  });
}
