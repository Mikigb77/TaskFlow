import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/screens/settings_screen.dart';
import 'package:agenda/services/capture_entries.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';

/// The launcher's answer to "pin the capture widget".
class _Launcher extends CaptureEntries {
  _Launcher({this.fails = false})
    : super(channel: const MethodChannel('taskflow/capture-entries-test'));
  final bool fails;
  @override
  Future<bool> pinWidget() async {
    if (fails) throw PlatformException(code: 'unavailable');
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    platform.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (_) async => 'Europe/Madrid',
    );
    platform.setMockMethodCallHandler(
      const MethodChannel('taskflow/accessibility'),
      (_) async => null,
    );
  });
  tearDown(() {
    platform.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      null,
    );
    platform.setMockMethodCallHandler(
      const MethodChannel('taskflow/accessibility'),
      null,
    );
  });

  Future<void> openWidgetHelp(
    WidgetTester tester,
    String language, {
    required bool fails,
  }) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = designContainer(
      regionalStore: MemoryRegionalStore(
        RegionalPreferences(language: language),
      ),
      overrides: [
        captureEntriesProvider.overrideWithValue(_Launcher(fails: fails)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/settings');
    await tester.pumpAndSettle();
    final l = lookupAppLocalizations(Locale(language));
    final row = find.text(l.homeCapture);
    await tester.scrollUntilVisible(
      row,
      160,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  for (final language in ['es', 'ca']) {
    for (final fails in [false, true]) {
      testWidgets(
        'UX-416: home-screen widget instructions stay in a sheet until closed '
        '(${fails ? 'picker fails' : 'pinning unsupported'}, $language, 2x text)',
        (tester) async {
          await openWidgetHelp(tester, language, fails: fails);
          final l = lookupAppLocalizations(Locale(language));
          final text = fails ? l.widgetPickerHelp : l.homeCaptureInstructions;
          final sheet = find.byType(BottomSheet);
          expect(sheet, findsOneWidget);
          expect(
            find.descendant(of: sheet, matching: find.text(text)),
            findsOneWidget,
          );
          expect(find.byType(SnackBar), findsNothing);
          // Long past any snackbar timeout, it is still there to read.
          await tester.pump(const Duration(minutes: 1));
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: sheet, matching: find.text(text)),
            findsOneWidget,
          );
          final done = find.descendant(
            of: sheet,
            matching: find.widgetWithText(FilledButton, l.done),
          );
          await tester.ensureVisible(done);
          await tester.pumpAndSettle();
          expect(done.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(done);
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
          expect(find.text(text), findsNothing);
          expect(find.byType(SettingsScreen), findsOneWidget);
        },
      );
    }
  }
}
