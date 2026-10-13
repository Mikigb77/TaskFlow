import 'package:agenda/main.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/settings_screen.dart';
import 'package:agenda/screens/regional_settings_screen.dart';
import 'package:agenda/widgets/language_selector.dart';
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
      expect(find.text('Your calendar'), findsOneWidget);
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
      expect(find.text('El teu calendari'), findsOneWidget);
      expect(container.read(regionalProvider).language, 'ca');

      navigator.pushNamed('/region');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(LanguageSelector));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-system')));
      await tester.pumpAndSettle();
      expect(store.value.language, 'system');
      expect(find.text('Idioma y región'), findsOneWidget);
      tester.platformDispatcher.localesTestValue = [const Locale('ja', 'JP')];
      await tester.pumpAndSettle();
      expect(find.text('Language & region'), findsOneWidget);
      expect(find.text('Follow phone · English'), findsOneWidget);
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
            .pushNamed('/region');
        await tester.pumpAndSettle();
        final selector = find.byType(LanguageSelector);
        await tester.scrollUntilVisible(selector, 160,
            scrollable: find
                .descendant(
                    of: find.byType(RegionalSettingsScreen),
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
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/region');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(LanguageSelector));
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
}

class _FailingStore extends MemoryRegionalStore {
  @override
  Future<void> write(RegionalPreferences value) async =>
      throw StateError('Disk full');
}
