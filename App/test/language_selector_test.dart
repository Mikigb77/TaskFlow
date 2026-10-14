import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_fixtures.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (_) async => 'Europe/Madrid',
    );
  });

  testWidgets(
    'Settings switches the whole app, persists selection and follows later phone changes',
    (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('fr', 'FR')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final store = MemoryRegionalStore(const RegionalPreferences());
      final container = designContainer(regionalStore: store);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Today’s agenda'), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/settings');
      await tester.pumpAndSettle();
      final selector = find.byKey(const ValueKey('settings-language'));
      await tester.scrollUntilVisible(selector, 180,
          scrollable: find
              .descendant(
                  of: find.byType(SettingsScreen),
                  matching: find.byType(Scrollable))
              .first);
      await tester.pumpAndSettle();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('language-system')), findsOneWidget);
      expect(find.byKey(const ValueKey('language-es')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('language-ca')));
      await tester.pumpAndSettle();
      expect(store.value.language, 'ca');
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Idioma'), findsOneWidget);
      tester.platformDispatcher.localesTestValue = [const Locale('es', 'MX')];
      await tester.pumpAndSettle();
      expect(find.text('Català'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('L’agenda d’avui'), findsOneWidget);
      expect(container.read(regionalProvider).language, 'ca');

      navigator.pushNamed('/settings');
      await tester.pumpAndSettle();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-system')));
      await tester.pumpAndSettle();
      expect(store.value.language, 'system');
      expect(find.text('Recordatorios'), findsOneWidget);
      tester.platformDispatcher.localesTestValue = [const Locale('ja', 'JP')];
      await tester.pumpAndSettle();
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('Same as phone · English'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'Catalan language choices stay usable at 2x text on a small phone, $theme',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final store = MemoryRegionalStore(
          const RegionalPreferences(language: 'ca'),
        );
        final container = designContainer(regionalStore: store);
        addTearDown(container.dispose);
        await container.read(themeModeProvider.notifier).setMode(theme);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const MyApp()),
        );
        await tester.pumpAndSettle();
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .pushNamed('/settings');
        await tester.pumpAndSettle();
        final selector = find.byKey(const ValueKey('settings-language'));
        await tester.scrollUntilVisible(selector, 160,
            scrollable: find
                .descendant(
                    of: find.byType(SettingsScreen),
                    matching: find.byType(Scrollable))
                .first);
        await tester.pumpAndSettle();
        await tester.tap(selector);
        await tester.pumpAndSettle();
        final english = find.byKey(const ValueKey('language-en'));
        await tester.scrollUntilVisible(
          english,
          100,
          scrollable: find
              .descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(english);
        await tester.pumpAndSettle();
        expect(store.value.language, 'en');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'failed persistence rolls back the language and keeps the selector open',
    (tester) async {
      final store = _FailingStore();
      final container = designContainer(regionalStore: store);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/settings');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-ca')));
      await tester.pumpAndSettle();
      expect(container.read(regionalProvider).language, 'en');
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.text('Could not save this preference. Please try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'UX-482: in Catalan at 2x text on 320×568 the Idioma sheet opens with no overflow, and every row (Com el telèfon, Español, Català, English) scrolls into view and can be chosen',
    (tester) async {
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(ca.languageAutomatic, 'Com el telèfon');
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = MemoryRegionalStore(
        const RegionalPreferences(language: 'ca'),
      );
      final container = designContainer(regionalStore: store);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/settings');
      await tester.pumpAndSettle();
      final selector = find.byKey(const ValueKey('settings-language'));
      // The first sheet opens in Catalan, before any choice.
      var catalan = true;
      for (final code in ['system', 'es', 'en', 'ca']) {
        await tester.scrollUntilVisible(
          selector,
          160,
          scrollable: find
              .descendant(
                of: find.byType(SettingsScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(selector);
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'opening for $code');
        if (catalan) {
          expect(
            find.descendant(
              of: sheet,
              matching: find.text(ca.languageAutomatic),
            ),
            findsOneWidget,
          );
          catalan = false;
        }
        final row = find.descendant(
          of: sheet,
          matching: find.byKey(ValueKey('language-$code')),
        );
        await tester.scrollUntilVisible(
          row,
          100,
          scrollable: find
              .descendant(of: sheet, matching: find.byType(Scrollable))
              .first,
        );
        await tester.pumpAndSettle();
        expect(row.hitTestable(), findsOneWidget, reason: code);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(store.value.language, code);
        expect(find.byType(BottomSheet), findsNothing, reason: code);
        expect(tester.takeException(), isNull, reason: code);
      }
    },
  );
}

class _FailingStore extends MemoryRegionalStore {
  @override
  Future<void> write(RegionalPreferences value) async =>
      throw StateError('Disk full');
}
