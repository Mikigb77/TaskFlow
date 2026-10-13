import 'package:agenda/models/task.dart';
import 'package:agenda/widgets/repeat_rule_control.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('repeat controls remain usable at 2x text in $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = designContainer();
      addTearDown(container.dispose);
      final task = Task(
          id: 1,
          title: 'Gym',
          priority: 1,
          dueDate: DateTime(2026, 9, 23),
          hasTime: false,
          recurrence: 'weekly',
          repeatWeekdays: [1, 3, 5]);
      Task? result;
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!),
              home: Builder(
                  builder: (context) => Scaffold(
                          body: ListView(children: [
                        TaskTile(task: task),
                        FilledButton(
                            onPressed: () async {
                              result = await editTaskRepeat(context, task);
                            },
                            child: const Text('Repeat settings')),
                      ]))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Repeat settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every 1 weeks'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('repeat-interval')), '2');
      await tester.tap(find.text('Keep changes'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Tue'), 160,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tue'));
      await tester.scrollUntilVisible(find.widgetWithText(FilledButton, 'Done'), 160,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();
      expect(result!.repeatInterval, 2);
      expect(result!.repeatWeekdays, [1, 2, 3, 5]);
    });
  }
}
