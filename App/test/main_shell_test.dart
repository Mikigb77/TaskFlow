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
}
