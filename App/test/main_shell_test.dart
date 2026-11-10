import 'package:agenda/widgets/ambient.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_fixtures.dart';

// Tab-bar layout depends on real glyph widths, so this file loads Manrope and
// the Material icon font the way calendar_feedback_test.dart does.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(
    () => platform.setMockMethodCallHandler(timeoutChannel, (_) async => null),
  );
  tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<AppLocalizations> pumpShell(
    WidgetTester tester, {
    required String language,
    required Size size,
    required double scale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = designContainer(
      regionalStore: MemoryRegionalStore(
        RegionalPreferences(
          language: language,
          clock: ClockFormat.twentyFour,
          weekStart: 1,
        ),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    return lookupAppLocalizations(Locale(language));
  }

  final bar = find.byType(NavigationBar);

  List<RenderParagraph> labelParagraphs(WidgetTester tester, String label) {
    final found = find.descendant(of: bar, matching: find.text(label));
    expect(found, findsWidgets, reason: '`$label` is in the tab bar');
    return [
      for (final element in found.evaluate())
        element.renderObject! as RenderParagraph,
    ];
  }

  // A label is on one line when its painted height equals the height of the
  // same text, style and scale laid out with no width limit.
  void expectOneLine(WidgetTester tester, String label, String reason) {
    for (final paragraph in labelParagraphs(tester, label)) {
      final oneLine = TextPainter(
        text: paragraph.text,
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
        locale: paragraph.locale,
        strutStyle: paragraph.strutStyle,
        textHeightBehavior: paragraph.textHeightBehavior,
      )..layout();
      expect(
        paragraph.size.height,
        moreOrLessEquals(oneLine.height, epsilon: 0.01),
        reason:
            '$reason: `$label` wraps (one line is ${oneLine.height} '
            'high, the label is ${paragraph.size.height}, its one-line width '
            'is ${oneLine.width} in ${paragraph.size.width})',
      );
      oneLine.dispose();
    }
  }

  void expectInsideBar(WidgetTester tester, String reason) {
    final barRect = tester.getRect(bar);
    for (final element
        in find
            .descendant(of: bar, matching: find.byType(NavigationIndicator))
            .evaluate()) {
      final pill = tester.getRect(find.byWidget(element.widget));
      expect(
        pill.top,
        greaterThanOrEqualTo(barRect.top),
        reason: '$reason: an icon pill rises over the bar’s top border',
      );
    }
  }

  Future<void> select(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: bar, matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  for (final (language, scale) in [('es', 1.3), ('es', 2.0), ('en', 1.3)]) {
    testWidgets(
      'UX-427: every tab label stays on one line at 320×640, $language, $scale× text',
      (tester) async {
        final l = await pumpShell(
          tester,
          language: language,
          size: const Size(320, 640),
          scale: scale,
        );
        final labels = [l.calendar, l.tasks, l.notes, l.settings];
        for (final selected in [l.calendar, l.tasks]) {
          await select(tester, selected);
          final reason = '$language, $scale×, $selected selected';
          for (final label in labels) {
            expectOneLine(tester, label, reason);
          }
          expectInsideBar(tester, reason);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-427: the tab label ignores the inherited 0.25 letter spacing',
    (tester) async {
      final l = await pumpShell(
        tester,
        language: 'es',
        size: const Size(320, 640),
        scale: 1.3,
      );
      for (final label in [l.calendar, l.tasks, l.notes, l.settings]) {
        for (final paragraph in labelParagraphs(tester, label)) {
          expect(paragraph.text.style!.letterSpacing, 0, reason: label);
          expect(paragraph.text.style!.fontFamily, 'Manrope', reason: label);
        }
      }
    },
  );

  for (final (size, scale, drawn) in [
    (const Size(320, 640), 2.0, 14.4),
    (const Size(320, 640), 1.0, 12.0),
    (const Size(390, 844), 1.3, 15.6),
    (const Size(360, 800), 1.3, 15.6),
  ]) {
    testWidgets(
      'UX-427: at ${size.width.toInt()} dp and $scale× text the tab labels are drawn at $drawn px',
      (tester) async {
        final l = await pumpShell(
          tester,
          language: 'es',
          size: size,
          scale: scale,
        );
        for (final label in [l.calendar, l.tasks, l.notes, l.settings]) {
          for (final paragraph in labelParagraphs(tester, label)) {
            final fontSize = paragraph.text.style!.fontSize!;
            // Below 360 dp the style shrinks so Flutter's 1.3× cap draws 1.2×.
            if (size.width >= 360) expect(fontSize, 12, reason: label);
            expect(
              paragraph.textScaler.scale(fontSize),
              moreOrLessEquals(drawn, epsilon: 0.001),
              reason: '$label at ${size.width} dp, $scale× text',
            );
          }
        }
      },
    );
  }

  // UX-432: below 360 dp only the tab label stops at 1.2×; the long-press
  // tooltip, Flutter's full-size path for tab names, keeps the phone's scale.
  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    testWidgets(
      'UX-432: at ${size.width.toInt()} dp and 2.0× text the Calendario tooltip is drawn at 28 px',
      (tester) async {
        final l = await pumpShell(
          tester,
          language: 'es',
          size: size,
          scale: 2.0,
        );
        await select(tester, l.calendar);
        final labels = labelParagraphs(tester, l.calendar).toSet();
        final anywhere = find.text(l.calendar, skipOffstage: false);
        final before = anywhere.evaluate().length;

        final gesture = await tester.startGesture(
          tester.getCenter(
            find.descendant(of: bar, matching: find.text(l.calendar)).first,
          ),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          anywhere.evaluate().length,
          greaterThan(before),
          reason: 'a long press on `${l.calendar}` shows its tooltip',
        );
        final tooltips = [
          for (final element in anywhere.evaluate())
            if (element.renderObject case final RenderParagraph paragraph
                when !labels.contains(paragraph))
              paragraph,
        ];
        expect(tooltips, hasLength(1));
        final tooltip = tooltips.single;
        final drawn = tooltip.textScaler.scale(
          tooltip.text.style?.fontSize ?? 14,
        );
        expect(
          drawn,
          moreOrLessEquals(28, epsilon: 0.001),
          reason:
              'the tooltip follows 2.0× text (14 sp × 2), '
              'not the label’s 1.2× stop (16.8 px)',
        );
        final screen = Offset.zero & size;
        final tooltipRect = MatrixUtils.transformRect(
          tooltip.getTransformTo(null),
          Offset.zero & tooltip.size,
        );
        expect(
          screen.contains(tooltipRect.topLeft) &&
              screen.contains(tooltipRect.bottomRight - const Offset(1, 1)),
          isTrue,
          reason: 'the tooltip ($tooltipRect) is inside the screen',
        );
        // The tab label itself is unchanged by the long press.
        for (final paragraph in labelParagraphs(
          tester,
          l.calendar,
        ).where(labels.contains)) {
          expect(
            paragraph.textScaler.scale(paragraph.text.style!.fontSize!),
            moreOrLessEquals(size.width < 360 ? 14.4 : 15.6, epsilon: 0.001),
          );
        }

        await gesture.up();
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- Run 2026-10-19-app · P196 · UX-421: the Catalan «Configuració» stays
  // whole wherever four tabs are too narrow for it ----

  /// Checks that every label is drawn whole on one line inside its own tab,
  /// at [minDrawn] px or more, and returns the widest one-line width seen.
  double expectWholeLabels(
    WidgetTester tester,
    List<String> labels,
    String reason, {
    double minDrawn = 12,
  }) {
    final tabWidth = tester.getSize(bar).width / labels.length;
    var widest = 0.0;
    for (final label in labels) {
      expectOneLine(tester, label, reason);
      for (final paragraph in labelParagraphs(tester, label)) {
        final drawn = paragraph.textScaler.scale(
          paragraph.text.style!.fontSize!,
        );
        expect(
          drawn,
          greaterThanOrEqualTo(minDrawn - 0.001),
          reason: '$reason: `$label` is drawn at $drawn px',
        );
        final oneLine = TextPainter(
          text: paragraph.text,
          textDirection: paragraph.textDirection,
          textScaler: paragraph.textScaler,
          locale: paragraph.locale,
        )..layout();
        widest = oneLine.width > widest ? oneLine.width : widest;
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: '$reason: `$label` is cut',
        );
        expect(
          oneLine.width,
          lessThanOrEqualTo(paragraph.size.width + 0.01),
          reason:
              '$reason: `$label` needs ${oneLine.width} dp, its box is '
              '${paragraph.size.width}',
        );
        expect(
          oneLine.width,
          lessThanOrEqualTo(tabWidth + 0.01),
          reason:
              '$reason: `$label` needs ${oneLine.width} dp in a $tabWidth dp tab',
        );
        final rect = MatrixUtils.transformRect(
          paragraph.getTransformTo(null),
          Offset.zero & paragraph.size,
        );
        final barRect = tester.getRect(bar);
        expect(
          rect.left >= barRect.left - 0.01 &&
              rect.right <= barRect.right + 0.01,
          isTrue,
          reason: '$reason: `$label` ($rect) is inside the bar ($barRect)',
        );
        oneLine.dispose();
      }
    }
    return widest;
  }

  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    for (final scale in [1.3, 2.0]) {
      testWidgets(
        'UX-421: at ${size.width.toInt()} dp and $scale× text the Catalan tab labels lay out on one line, Configuració whole',
        (tester) async {
          final l = await pumpShell(
            tester,
            language: 'ca',
            size: size,
            scale: scale,
          );
          final labels = [l.calendar, l.tasks, l.notes, l.settings];
          // The selected label's style may be the wider one.
          for (final selected in [l.calendar, l.settings]) {
            await select(tester, selected);
            final reason =
                'ca, ${size.width.toInt()} dp, $scale×, $selected selected';
            expectWholeLabels(tester, labels, reason);
            expectInsideBar(tester, reason);
          }
          expect(
            find.descendant(of: bar, matching: find.text(l.settings)),
            findsWidgets,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'UX-421: at 320×640 and 2.0× text the Catalan tab labels are drawn at 12 px or more, on one line',
    (tester) async {
      final l = await pumpShell(
        tester,
        language: 'ca',
        size: const Size(320, 640),
        scale: 2.0,
      );
      final labels = [l.calendar, l.tasks, l.notes, l.settings];
      for (final selected in [l.calendar, l.settings]) {
        await select(tester, selected);
        final reason = 'ca, 320 dp, 2.0×, $selected selected';
        final widest = expectWholeLabels(tester, labels, reason);
        final drawn = labelParagraphs(tester, l.settings)
            .map((p) => p.textScaler.scale(p.text.style!.fontSize!))
            .reduce((a, b) => a > b ? a : b);
        // Reported for the round: what «Configuració» measures here.
        debugPrint(
          'UX-421 measure ($reason): `${l.settings}` drawn at '
          '${drawn.toStringAsFixed(2)} px; widest label '
          '${widest.toStringAsFixed(1)} dp in an 80 dp tab',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Round 1 · P23 · UX-223: Back never strands you ----

  /// Records whether system Back asked the platform to leave the app.
  List<String> watchExits(WidgetTester tester) {
    final exits = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') exits.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return exits;
  }

  int selectedTab(WidgetTester tester) =>
      tester.widget<NavigationBar>(bar).selectedIndex;

  for (final tab in ['tasks', 'notes', 'settings']) {
    testWidgets(
      'UX-223: system Back on ${tab == 'tasks'
          ? 'Tareas'
          : tab == 'notes'
          ? 'Notas'
          : 'Ajustes'} selects Calendario and stays in the app',
      (tester) async {
        final l = await pumpShell(
          tester,
          language: 'es',
          size: const Size(390, 844),
          scale: 1,
        );
        final exits = watchExits(tester);
        final label = switch (tab) {
          'tasks' => l.tasks,
          'notes' => l.notes,
          _ => l.settings,
        };
        await select(tester, label);
        expect(selectedTab(tester), isNot(0));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(selectedTab(tester), 0, reason: 'Calendario is selected');
        expect(exits, isEmpty, reason: 'Back did not leave the app');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('UX-223: system Back on Calendario leaves the app, as today', (
    tester,
  ) async {
    await pumpShell(
      tester,
      language: 'es',
      size: const Size(390, 844),
      scale: 1,
    );
    final exits = watchExits(tester);
    expect(selectedTab(tester), 0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(exits, ['SystemNavigator.pop']);
    expect(tester.takeException(), isNull);
  });

  // ---- Round 1 · P23 · UX-433: the tab bar stands off the page. Since
  // 2026-11-10 (the owner's pick) by rounded top corners and a soft shadow,
  // not a ruled line ----

  for (final dark in [false, true]) {
    testWidgets(
      'UX-433: the tab bar is a full-width base with 28 px rounded top corners and a soft shadow, over the drifting backdrop (${dark ? 'dark' : 'light'})',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final container = designContainer(
          store: MemoryThemeStore(dark ? 'dark' : 'light'),
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const MyApp()),
        );
        await tester.pumpAndSettle();
        final colors = Theme.of(tester.element(bar)).colorScheme;
        expect(colors.brightness, dark ? Brightness.dark : Brightness.light);
        const top = BorderRadius.vertical(top: Radius.circular(28));
        final clip = find.byWidgetPredicate(
          (widget) => widget is ClipRRect && widget.child is NavigationBar,
        );
        expect(clip, findsOneWidget);
        expect(tester.widget<ClipRRect>(clip).borderRadius, top);
        final frame = find.ancestor(
          of: clip,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                (widget.decoration as BoxDecoration?)?.boxShadow?.isNotEmpty ==
                    true,
          ),
        );
        expect(frame, findsOneWidget);
        final decoration =
            tester.widget<DecoratedBox>(frame).decoration as BoxDecoration;
        expect(decoration.borderRadius, top);
        expect(decoration.border, isNull);
        // The shadow rises above the bar, not below it.
        expect(decoration.boxShadow!.single.offset.dy, lessThan(0));
        // The bar runs the full width along the bottom, as before.
        expect(tester.getRect(frame).top, tester.getRect(bar).top);
        expect(tester.getRect(frame).width, 390);
        expect(tester.getRect(frame).bottom, 844);
        // The corners show the page's drifting colour, not a blank strip.
        expect(
          find.ancestor(of: bar, matching: find.byType(AmbientBackdrop)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- UX loop 2026-10-19-app, round 1 · P175 · UX-1411: each root tab is
  // announced by its own name ----

  for (final language in ['es', 'ca']) {
    testWidgets(
      'UX-1411 ($language): each root tab has a heading that names the route (Calendario, Tareas, Notas, Ajustes); the logo still shows and isn’t read',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final l = await pumpShell(
          tester,
          language: language,
          size: const Size(360, 800),
          scale: 1,
        );
        List<SemanticsData> nodes() {
          final found = <SemanticsData>[];
          bool visit(SemanticsNode node) {
            found.add(node.getSemanticsData());
            node.visitChildren(visit);
            return true;
          }

          visit(
            tester
                .binding
                .renderViews
                .first
                .owner!
                .semanticsOwner!
                .rootSemanticsNode!,
          );
          return found;
        }

        for (final tab in [l.calendar, l.tasks, l.notes, l.settings]) {
          if (tab != l.calendar) await select(tester, tab);
          final headings = [
            for (final data in nodes())
              if (data.flagsCollection.isHeader &&
                  data.flagsCollection.namesRoute &&
                  data.label == tab)
                data,
          ];
          expect(headings, hasLength(1), reason: '$tab names its route');
          expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.text('taskflow'),
            ),
            findsOneWidget,
            reason: '$tab: the logo still shows',
          );
          expect(
            nodes().where((data) => data.label.contains('taskflow')),
            isEmpty,
            reason: '$tab: the brand isn’t read',
          );
        }
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
