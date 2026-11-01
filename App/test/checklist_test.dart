import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/checklist_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'dart:ui' show CheckedState;
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
    // Steps are typed in place: Enter on an empty field adds nothing.
    final add = find.byKey(const ValueKey('add-checklist-item'));
    await tester.tap(add);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(items.length, 2);
    await tester.enterText(add, 'Coat');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(items.length, 3);
    await tester.tap(find.byTooltip('Edit Passport'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit step'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('checklist-title')), 'New passport');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(items.first.title, 'New passport');
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

  // ---- Round 2 (b8) · P110 (UX-621): a disabled editor keeps typed text ----

  testWidgets(
    'UX-621: a ChecklistEditor with onChanged null keeps the typed step in the field when the field loses focus',
    (tester) async {
      var items = [ChecklistItem(title: 'Charger')];
      var enabled = true;
      late StateSetter rebuild;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: StatefulBuilder(builder: (context, setState) {
        rebuild = setState;
        return SingleChildScrollView(
            child: ChecklistEditor(
                items: items,
                onChanged: enabled
                    ? (next) => setState(() => items = next)
                    : null));
      }))));
      final add = find.byKey(const ValueKey('add-checklist-item'));
      String fieldText() => tester
          .widget<EditableText>(
              find.descendant(of: add, matching: find.byType(EditableText)))
          .controller
          .text;
      await tester.enterText(add, 'Passport');
      await tester.pump();
      expect(fieldText(), 'Passport');

      // The card is disabled (as while saving), then the field loses focus.
      rebuild(() => enabled = false);
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
                find.descendant(of: add, matching: find.byType(EditableText)))
            .focusNode
            .hasFocus,
        isFalse,
      );
      expect(fieldText(), 'Passport', reason: 'the typed step is kept');
      expect(items.map((item) => item.title), ['Charger']);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Round 1 (b9) · P113 (UX-624): at 50 steps typed text stays ----

  for (final language in ['es', 'ca']) {
    testWidgets(
      'UX-624: with 50 steps, text typed in Añadir paso stays in the field when it loses focus (as Menos detalles does), and the field says the limit ($language)',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var items = [
          for (var i = 1; i <= 49; i++) ChecklistItem(title: 'Caja $i'),
        ];
        late StateSetter rebuild;
        await tester.pumpWidget(MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
                body: StatefulBuilder(builder: (context, setState) {
              rebuild = setState;
              return SingleChildScrollView(
                  child: ChecklistEditor(
                      items: items,
                      onChanged: (next) => setState(() => items = next)));
            }))));
        final add = find.byKey(const ValueKey('add-checklist-item'));
        String fieldText() => tester
            .widget<EditableText>(
                find.descendant(of: add, matching: find.byType(EditableText)))
            .controller
            .text;
        await tester.ensureVisible(add);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.enterText(add, 'Abrigo');
        await tester.pump();

        // The 50th step arrives while the person types (from the same task
        // on another device): the task is now at the limit.
        rebuild(() => items = [...items, ChecklistItem(title: 'Caja 50')]);
        await tester.pump();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        expect(items.length, 50, reason: 'no 51st step');
        expect(add, findsOneWidget, reason: 'the field stays while it has text');
        expect(fieldText(), 'Abrigo', reason: 'the typed text is kept');
        await tester.ensureVisible(add);
        await tester.pumpAndSettle();
        expect(find.text(l.stepLimit), findsOneWidget,
            reason: 'the person sees why it was not added');

        // Enter at the limit adds nothing and still keeps the text.
        await tester.tap(add);
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(items.length, 50);
        expect(fieldText(), 'Abrigo');
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- UX loop 2026-10-28-app, round 1 · P293 (UX-2415): each step reads
  // once ----
  group('P293 · steps read once', () {
    /// Every node TalkBack can reach, as (label, is a checkbox, is a button).
    List<({String label, bool checkbox, bool button})> nodes(
      WidgetTester tester,
    ) {
      final found = <({String label, bool checkbox, bool button})>[];
      void visit(SemanticsNode node) {
        final data = node.getSemanticsData();
        if (data.label.isNotEmpty || data.tooltip.isNotEmpty) {
          found.add((
            label: [data.label, data.tooltip]
                .where((part) => part.isNotEmpty)
                .join(' '),
            checkbox: data.flagsCollection.isChecked != CheckedState.none,
            button: data.flagsCollection.isButton,
          ));
        }
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(tester
          .renderObject(find.byType(ChecklistEditor))
          .owner!
          .semanticsOwner!
          .rootSemanticsNode!);
      return found;
    }

    for (final language in ['es', 'ca', 'en']) {
      testWidgets(
        'UX-2415: in the form ($language), each step is read once, as its checkbox labelled with its title, plus its ⋮; no separate text node for the title',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final l = lookupAppLocalizations(Locale(language));
          var items = [
            ChecklistItem(title: 'Meriendas'),
            ChecklistItem(title: 'Cuadernos').setDone(true),
          ];
          await tester.pumpWidget(MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                  body: StatefulBuilder(
                      builder: (context, setState) => SingleChildScrollView(
                          child: ChecklistEditor(
                              items: items,
                              onChanged: (next) =>
                                  setState(() => items = next)))))));
          await tester.pumpAndSettle();
          final all = nodes(tester);
          for (final title in ['Meriendas', 'Cuadernos']) {
            final reading = all
                .where((node) => node.label.contains(title))
                .toList();
            final checkbox = reading.where((node) => node.checkbox).toList();
            expect(checkbox, hasLength(1), reason: '$title: $reading');
            expect(checkbox.single.label, title, reason: '$title: $reading');
            final menu = reading.where(
              (node) => node.label == l.editCaptureItem(title),
            );
            expect(menu, hasLength(1), reason: '$title’s ⋮: $reading');
            expect(menu.single.button, isTrue);
            expect(menu.single.checkbox, isFalse);
            expect(
              reading,
              hasLength(2),
              reason: 'the checkbox and the ⋮, nothing else: $reading',
            );
          }
          // The merged step still ticks.
          await tester.tap(find.byType(Checkbox).first);
          await tester.pumpAndSettle();
          expect(items.first.completed, isTrue);
          semantics.dispose();
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
