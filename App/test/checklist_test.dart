import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/checklist_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'steps can be added edited reordered checked and removed without changing their IDs',
      (tester) async {
    var items = [
      ChecklistItem(title: 'Passport'),
      ChecklistItem(title: 'Charger')
    ];
    final passportId = items.first.id;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, setState) => SingleChildScrollView(
                    child: ChecklistEditor(
                        items: items,
                        onChanged: (next) => setState(() => items = next)))))));
    await tester.tap(find.byKey(const ValueKey('add-checklist-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep step'));
    await tester.pumpAndSettle();
    expect(find.text('Add a short step.'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('checklist-title')), 'Coat');
    await tester.tap(find.text('Keep step'));
    await tester.pumpAndSettle();
    expect(items.length, 3);
    await tester.tap(find.byTooltip('Edit Passport'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit step'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('checklist-title')), 'New passport');
    await tester.tap(find.text('Keep step'));
    await tester.pumpAndSettle();
    expect(items.first.id, passportId);
    await tester.tap(find.byTooltip('Edit New passport'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move down'));
    await tester.pumpAndSettle();
    expect(items[1].id, passportId);
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    expect(items[1].completed, isTrue);
    expect(find.text('Checklist · 1/3'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit Coat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove step'));
    await tester.pumpAndSettle();
    expect(items.length, 2);
    expect(items[1].id, passportId);
  });

  testWidgets(
      'recurring template explains occurrence completion and fits large text in both themes',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(MaterialApp(
          theme:
              brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
          home: Scaffold(
              body: SingleChildScrollView(
                  child: ChecklistEditor(items: [
            ChecklistItem(
                title: 'Bring a longer description of the blood test results')
          ], recurring: true, onChanged: (_) {})))));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
      expect(find.textContaining('steps repeat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
