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
      'AI checklist stays within one saved task and can be corrected in review',
      (tester) async {
    final container = await openReview(tester, [
      TaskDraft.fromJson({
        'title': 'Pack',
        'due_date': null,
        'priority': 1,
        'notes': '',
        'transcript': 'Pack passport and charger',
        'questions': [],
        'checklist': [
          {'id': '7dd965fb-212f-4b37-a5dc-9339e2575447', 'title': 'Passport'},
          {'id': '57bb8ccf-0c13-4a06-928c-f4f0587a4f70', 'title': 'Charger'}
        ],
      })
    ]);
    final edit = find.byTooltip('Edit Passport');
    await tester.scrollUntilVisible(edit, 180);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit step'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('checklist-title')), 'Renewed passport');
    await tester.tap(find.text('Keep step'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await tester.pumpAndSettle();
    final saved = container
        .read(taskProvider)
        .requireValue
        .singleWhere((task) => task.title == 'Pack');
    expect(saved.checklist.map((item) => item.title),
        ['Renewed passport', 'Charger']);
    expect(saved.checklist.first.id, '7dd965fb-212f-4b37-a5dc-9339e2575447');
    expect(saved.isCompleted, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'inline review controls fit small screens with large text in both themes',
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
      await tester.ensureVisible(find.byKey(const ValueKey('task-title')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final repeat = find.byTooltip('Change repeat').first;
      await tester.ensureVisible(repeat);
      await tester.tap(repeat);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Keep repeat'), 120,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep repeat'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('guest reviews, edits and saves several tasks together',
      (tester) async {
    final container =
        await openReview(tester, [draft('Buy coffee'), draft('Pay invoice')]);
    expect(find.text('Inbox · No date'), findsOneWidget);
    expect(find.text('Sep 25 · Any time'), findsOneWidget);
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

  testWidgets('ready tasks save while uncertain drafts remain for review',
      (tester) async {
    final container = await openReview(
        tester, [draft('Call', ambiguous: true), draft('Coffee')]);
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await tester.pumpAndSettle();
    expect(container.read(taskProvider).requireValue.length, 5);
    expect(container.read(taskProvider).requireValue.last.title, 'Coffee');
    expect(find.text('Call'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save-drafts')))
            .onPressed,
        isNull);
    final confirm = find.text('Use the details shown');
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await tester.pumpAndSettle();
    expect(container.read(taskProvider).requireValue.length, 6);
    expect(
        container
            .read(taskProvider)
            .requireValue
            .where((t) => t.title == 'Coffee')
            .length,
        1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'removing drafts and changing a title never confirms unrelated ambiguity',
      (tester) async {
    final container = await openReview(
        tester, [draft('Call', ambiguous: true), draft('Remove me')]);
    final remove = find.byTooltip('Remove Remove me');
    await tester.scrollUntilVisible(remove, 200);
    await tester.drag(find.byType(ListView).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Edit Call'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Call'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('task-title')), 'Call Mum');
    await tester.tap(find.text('Keep changes'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save-drafts')))
            .onPressed,
        isNull);
    final confirm = find.text('Use the details shown');
    await tester.scrollUntilVisible(confirm, -200);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await tester.pumpAndSettle();
    expect(container.read(taskProvider).requireValue.length, 5);
    expect(container.read(taskProvider).requireValue.last.title, 'Call Mum');
    expect(tester.takeException(), isNull);
  });
}
