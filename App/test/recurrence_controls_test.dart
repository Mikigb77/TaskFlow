import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/repeat_rule_control.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      // Listo is pinned under the choices (UX-2622), so the interval row
      // scrolls into view above it first.
      await tester.scrollUntilVisible(find.text('Every week'), 160,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every week'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('repeat-interval')), '2');
      await tester.tap(find.widgetWithText(FilledButton, 'Done').last);
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

  // Last in this file: it loads Manrope, which the tests after it would
  // otherwise draw with.
  group('P301 · repeat sheet', () {
    // Opens the repeat sheet for [task] in [language] on a 360×[height]
    // phone at [scale], the app's own theme and fonts; returns what Listo
    // hands back, once it is tapped.
    Future<Task? Function()> openSheet(
      WidgetTester tester,
      Task task, {
      required String language,
      double scale = 1,
      double height = 800,
    }) async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      tester.view.physicalSize = Size(360, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Task? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async =>
                      result = await editTaskRepeat(context, task),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      return () => result;
    }

    Task gym(String recurrence) => Task(
      id: 1,
      title: 'Gimnasio',
      priority: 1,
      dueDate: DateTime(2026, 11, 4),
      hasTime: false,
      recurrence: recurrence,
      repeatWeekdays: recurrence == 'weekly' ? [3] : [],
    );

    Finder inSheet(Finder finder) =>
        find.descendant(of: find.byType(BottomSheet), matching: finder);
    Finder listo(AppLocalizations l) =>
        inSheet(find.widgetWithText(FilledButton, l.done));
    // The line above the details, not P306's edge above Listo.
    Finder detailsLine() => inSheet(
      find.byWidgetPredicate(
        (w) =>
            w is Divider && w.key != const ValueKey('repeat-sheet-foot-edge'),
      ),
    );

    for (final language in ['es', 'ca']) {
      testWidgets(
        'UX-2622 ($language, 2× on 360×800): with «Cada semana» ticked, Listo is whole on screen without scrolling, and stays there as the details scroll',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          final result = await openSheet(
            tester,
            gym('weekly'),
            language: language,
            scale: 2,
          );
          final screen = Offset.zero & const Size(360, 800);
          final button = listo(l);
          expect(button, findsOneWidget);
          final before = tester.getRect(button);
          expect(before.top, greaterThanOrEqualTo(screen.top));
          expect(
            before.bottom,
            lessThanOrEqualTo(screen.bottom),
            reason: 'Listo at $before must be whole inside $screen',
          );
          expect(before.left, greaterThanOrEqualTo(screen.left));
          expect(before.right, lessThanOrEqualTo(screen.right));
          // The details reach past the screen at 2×, so they scroll; Listo
          // stays put under them.
          final details = inSheet(find.text(l.noEndDate));
          await tester.scrollUntilVisible(
            details,
            120,
            scrollable: inSheet(find.byType(Scrollable)).first,
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(button), before);
          expect(tester.getRect(details).bottom, lessThanOrEqualTo(before.top));
          // Listo takes the tap where it stands and hands back the weekly repeat.
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
          expect(result()!.recurrence, 'weekly');
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2621 (es, 1×): a line sits between «Cada año» and the ticked repeat’s interval row, at least 8 dp apart',
      (tester) async {
        final l = lookupAppLocalizations(const Locale('es'));
        await openSheet(tester, gym('weekly'), language: 'es');
        final yearly = tester.getRect(
          find.byKey(const ValueKey('repeat-yearly')),
        );
        final intervalRow = inSheet(
          find.ancestor(
            of: find.text(l.repeatInterval),
            matching: find.byType(ListTile),
          ),
        );
        expect(intervalRow, findsOneWidget);
        expect(
          find.descendant(
            of: intervalRow,
            matching: find.text(l.repeatEvery(1, 'weekly')),
          ),
          findsOneWidget,
        );
        final interval = tester.getRect(intervalRow);
        final divider = detailsLine();
        expect(divider, findsOneWidget);
        final line = tester.getRect(divider);
        expect(line.top, greaterThanOrEqualTo(yearly.bottom));
        expect(line.bottom, lessThanOrEqualTo(interval.top));
        expect(interval.top - yearly.bottom, greaterThanOrEqualTo(8));
      },
    );

    testWidgets(
      'UX-2621/UX-2622 (es, 1×): with «No se repite» ticked there is no line and no interval row, and the sheet hugs its rows and Listo',
      (tester) async {
        final l = lookupAppLocalizations(const Locale('es'));
        await openSheet(tester, gym('none'), language: 'es');
        expect(detailsLine(), findsNothing);
        expect(inSheet(find.text(l.repeatInterval)), findsNothing);
        expect(inSheet(find.byType(RepeatRuleControl)), findsNothing);
        expect(inSheet(find.text(l.noEndDate)), findsNothing);
        final sheet = tester.getRect(find.byType(BottomSheet));
        final title = tester.getRect(inSheet(find.text(l.repeat)));
        final yearly = tester.getRect(
          find.byKey(const ValueKey('repeat-yearly')),
        );
        final button = tester.getRect(listo(l));
        expect(
          sheet.height,
          lessThan(800 * 0.75),
          reason: 'the sheet should hug its content, not fill the screen',
        );
        // The theme's drag handle (48 dp), then the sheet's 24 dp padding.
        expect(title.top - sheet.top, lessThanOrEqualTo(48 + 24 + 1));
        expect(
          button.top - yearly.bottom,
          lessThanOrEqualTo(24),
          reason: 'no empty space between the last row and Listo',
        );
        expect(sheet.bottom - button.bottom, lessThanOrEqualTo(24 + 1));
      },
    );

    testWidgets(
      'P301 (es): ticking «Cada mes» then Listo returns a monthly repeat, and the end-date row still opens the date picker',
      (tester) async {
        final l = lookupAppLocalizations(const Locale('es'));
        final result = await openSheet(tester, gym('none'), language: 'es');
        await tester.tap(find.byKey(const ValueKey('repeat-monthly')));
        await tester.pumpAndSettle();
        final endDate = inSheet(find.text(l.noEndDate));
        expect(endDate, findsOneWidget);
        await tester.tap(endDate);
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        // Leave the picker without a date; the sheet is still open.
        await tester.tap(
          find.descendant(
            of: find.byType(DatePickerDialog),
            matching: find.widgetWithText(
              TextButton,
              MaterialLocalizations.of(
                tester.element(endDate),
              ).cancelButtonLabel,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsNothing);
        expect(endDate, findsOneWidget);
        await tester.tap(listo(l));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(result()!.recurrence, 'monthly');
        expect(result()!.repeatUntil, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  });


  // Also loads Manrope, so it stays at the end with P301's group.
  group('P306 · repeat sheet foot', () {
    const edgeKey = ValueKey('repeat-sheet-foot-edge');

    // Opens the repeat sheet for [task] in [language] on a 360×800 phone at
    // [scale], the app's own theme and fonts.
    Future<void> openSheet(
      WidgetTester tester,
      Task task, {
      required String language,
      double scale = 1,
    }) async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => editTaskRepeat(context, task),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Task gym(String recurrence) => Task(
      id: 1,
      title: 'Gimnasio',
      priority: 1,
      dueDate: DateTime(2026, 11, 4),
      hasTime: false,
      recurrence: recurrence,
      repeatWeekdays: recurrence == 'weekly' ? [3] : [],
    );

    Finder inSheet(Finder finder) =>
        find.descendant(of: find.byType(BottomSheet), matching: finder);
    Finder listo(AppLocalizations l) =>
        inSheet(find.widgetWithText(FilledButton, l.done));

    // The sheet's scrolling part: its Scrollbar and the position it tracks.
    Scrollbar scrollbar(WidgetTester tester) =>
        tester.widget<Scrollbar>(inSheet(find.byType(Scrollbar)));
    ScrollPosition position(WidgetTester tester) {
      final view = tester.widget<SingleChildScrollView>(
        inSheet(find.byType(SingleChildScrollView)),
      );
      expect(view.controller, isNotNull);
      expect(scrollbar(tester).controller, same(view.controller));
      return view.controller!.position;
    }

    // What the Scrollbar's own painter draws now: nothing when no thumb shows.
    List<RecordedInvocation> thumbStrokes(WidgetTester tester) {
      final paint = find.descendant(
        of: inSheet(find.byType(Scrollbar)),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.foregroundPainter is ScrollbarPainter,
        ),
      );
      expect(paint, findsOneWidget);
      final canvas = TestRecordingCanvas();
      tester
          .widget<CustomPaint>(paint)
          .foregroundPainter!
          .paint(canvas, tester.getSize(paint));
      return canvas.invocations;
    }

    // The colour the edge is actually drawn in, after the theme.
    Color edgeColor(WidgetTester tester) {
      final edge = find.byKey(edgeKey);
      return Divider.createBorderSide(
        tester.element(edge),
        color: tester.widget<Divider>(edge).color,
      ).color;
    }

    for (final language in ['es', 'ca']) {
      testWidgets(
        'UX-2632 ($language, 2× on 360×800): with «Cada semana» ticked, the sheet scrolls, a scrollbar thumb is painted and a drawn line sits directly above Listo',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          await openSheet(tester, gym('weekly'), language: language, scale: 2);
          expect(scrollbar(tester).thumbVisibility, isTrue);
          expect(position(tester).maxScrollExtent, greaterThan(0));
          expect(
            thumbStrokes(tester),
            isNotEmpty,
            reason: 'a thumb should show the details go on',
          );
          final edge = find.byKey(edgeKey);
          expect(inSheet(edge), findsOneWidget);
          expect(edgeColor(tester).a, greaterThan(0));
          final line = tester.getRect(edge);
          final button = tester.getRect(listo(l));
          final sheet = tester.getRect(find.byType(BottomSheet));
          expect(line.bottom, lessThanOrEqualTo(button.top));
          expect(
            button.top - line.bottom,
            lessThanOrEqualTo(16 + 1),
            reason: 'the line belongs right above Listo, nothing between',
          );
          expect(line.left, lessThanOrEqualTo(sheet.left + 1));
          expect(line.right, greaterThanOrEqualTo(sheet.right - 1));
          expect(button.bottom, lessThanOrEqualTo(800));
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final recurrence in ['weekly', 'none']) {
      testWidgets(
        'UX-2632 (es, 1× on 360×800, $recurrence): nothing scrolls, so no thumb is painted, the line above Listo is transparent and the sheet hugs its content',
        (tester) async {
          final l = lookupAppLocalizations(const Locale('es'));
          await openSheet(tester, gym(recurrence), language: 'es');
          expect(position(tester).maxScrollExtent, 0);
          expect(thumbStrokes(tester), isEmpty);
          expect(inSheet(find.byKey(edgeKey)), findsOneWidget);
          expect(edgeColor(tester).a, 0);
          final sheet = tester.getRect(find.byType(BottomSheet));
          final title = tester.getRect(inSheet(find.text(l.repeat)));
          final button = tester.getRect(listo(l));
          final last = recurrence == 'none'
              ? tester.getRect(find.byKey(const ValueKey('repeat-yearly')))
              : tester.getRect(
                  inSheet(
                    find.ancestor(
                      of: find.text(l.noEndDate),
                      matching: find.byType(ListTile),
                    ),
                  ),
                );
          expect(sheet.top, greaterThan(0));
          // The theme's drag handle (48 dp), then the sheet's 24 dp padding.
          expect(title.top - sheet.top, lessThanOrEqualTo(48 + 24 + 1));
          expect(
            button.top - last.bottom,
            lessThanOrEqualTo(24 + 1),
            reason: 'no empty space between the last row and Listo',
          );
          expect(sheet.bottom - button.bottom, lessThanOrEqualTo(24 + 1));
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2632 (es, 2× on 360×800): scrolling the sheet to its end brings «Sin fecha de fin» into view, Listo stays whole where it was, and the line stays drawn',
      (tester) async {
        final l = lookupAppLocalizations(const Locale('es'));
        await openSheet(tester, gym('weekly'), language: 'es', scale: 2);
        final button = listo(l);
        final before = tester.getRect(button);
        final end = inSheet(find.text(l.noEndDate));
        await tester.drag(
          inSheet(find.byType(SingleChildScrollView)),
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
        final pos = position(tester);
        expect(pos.pixels, closeTo(pos.maxScrollExtent, 0.5));
        expect(end, findsOneWidget);
        final shown = tester.getRect(end);
        final line = tester.getRect(find.byKey(edgeKey));
        final sheet = tester.getRect(find.byType(BottomSheet));
        expect(shown.top, greaterThanOrEqualTo(sheet.top));
        expect(
          shown.bottom,
          lessThanOrEqualTo(line.top),
          reason: '«Sin fecha de fin» at $shown must be above the line at $line',
        );
        expect(tester.getRect(button), before);
        expect(before.top, greaterThanOrEqualTo(0));
        expect(before.bottom, lessThanOrEqualTo(800));
        expect(before.left, greaterThanOrEqualTo(0));
        expect(before.right, lessThanOrEqualTo(360));
        // It tracks overflow, not position: still drawn at the end.
        expect(edgeColor(tester).a, greaterThan(0));
        expect(thumbStrokes(tester), isNotEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
