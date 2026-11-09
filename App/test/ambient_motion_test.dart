import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/theme/motion.dart';
import 'package:agenda/widgets/ambient.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The app's ambient motion (ambient.dart, motion.dart) plays where the phone
// allows it, stands still where it asks for less motion, and leaves nothing
// running once its page is gone.
void main() {
  tearDown(() => AppMotion.debugForce = null);

  Widget app(Widget child, {bool reduce = false}) => MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Scaffold(
        body: AmbientBackdrop(
          child: Column(
            children: [
              const BrandMark(),
              LivelyButton(
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('Add a task'),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets('stands still under flutter test unless a test asks', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(const EmptyState(title: 'Nothing here', message: 'Say a task')),
    );
    // Nothing loops: the frame settles at once.
    await tester.pumpAndSettle();
    expect(find.text('Nothing here'), findsOneWidget);
    expect(AppMotion.of(tester.element(find.text('Nothing here'))), isFalse);
  });

  testWidgets('moves when allowed, and stops with its page', (tester) async {
    AppMotion.debugForce = true;
    await tester.pumpWidget(
      app(const EmptyState(title: 'Nothing here', message: 'Say a task')),
    );
    expect(AppMotion.of(tester.element(find.text('Nothing here'))), isTrue);
    // The empty state rises in, readable by TalkBack from its first frame.
    final rising = tester.widget<Opacity>(
      find
          .ancestor(of: find.text('Nothing here'), matching: find.byType(Opacity))
          .first,
    );
    expect(rising.opacity, lessThan(1));
    expect(rising.alwaysIncludeSemantics, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.ancestor(
        of: find.text('Nothing here'),
        matching: find.byWidgetPredicate(
          (widget) => widget is Opacity && widget.opacity < 1,
        ),
      ),
      findsNothing,
    );
    // The light crosses the brand mark and the button, the glow breathes.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    // Once the page is gone, no timer or ticker is left behind.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('a phone that asks for less motion gets none', (tester) async {
    AppMotion.debugForce = true;
    await tester.pumpWidget(
      app(
        const EmptyState(title: 'Nothing here', message: 'Say a task'),
        reduce: true,
      ),
      duration: Duration.zero,
    );
    expect(AppMotion.of(tester.element(find.text('Nothing here'))), isFalse);
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.text('Nothing here'),
        matching: find.byWidgetPredicate(
          (widget) => widget is Opacity && widget.opacity < 1,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('ticking a task bursts over the page and cleans up', (
    tester,
  ) async {
    AppMotion.debugForce = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => Checkbox(
                value: false,
                onChanged: (_) => CheckBurst.play(context),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    // It removes itself when it's done.
    await tester.pumpAndSettle();
  });

  testWidgets('ripples follow the voice only while listening', (tester) async {
    AppMotion.debugForce = true;
    Widget ripples(bool active) => MaterialApp(
      home: Center(
        child: SizedBox.square(
          dimension: 72,
          child: VoiceRipples(level: 0.6, active: active, color: Colors.green),
        ),
      ),
    );
    await tester.pumpWidget(ripples(true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.descendant(
        of: find.byType(VoiceRipples),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(ripples(false));
    // Not listening: nothing left moving.
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(VoiceRipples),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });
}
