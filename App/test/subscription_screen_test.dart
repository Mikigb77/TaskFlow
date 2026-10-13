import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/screens/subscription_screen.dart';
import 'package:agenda/services/revenuecat_service.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/billing_fixtures.dart';
import 'support/design_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(
    () => platform.setMockMethodCallHandler(timeoutChannel, (_) async => null),
  );
  tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));
  for (final language in ['en', 'es', 'ca']) {
    testWidgets('complimentary Pro hides checkout and restore in $language', (
      tester,
    ) async {
      final sdk = FakeRevenueCat();
      final controller = SubscriptionController(
        sdk,
        const BillingConfiguration(apiKey: 'test_fixture', supported: true),
      );
      await controller.setIdentity(
        'owner',
        () async => 'owner-id',
        complimentary: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(OfflineApiClient()),
            authProvider.overrideWith(
              (ref) => SignedInFixtureAuth(ref.read(apiClientProvider)),
            ),
            subscriptionProvider.overrideWith((_) => controller),
            billingConfigurationProvider.overrideWithValue(
              controller.configuration,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SubscriptionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(SubscriptionScreen));
        final l10n = AppLocalizations.of(context);
      expect(find.text(l10n.billingStatus('active')), findsOneWidget);
      expect(find.text(l10n.billingComplimentary), findsOneWidget);
      for (final key in [
        'subscription-paywall',
        'subscription-purchase',
        'subscription-restore',
        'subscription-manage',
      ]) {
        expect(find.byKey(ValueKey(key)), findsNothing);
      }
      expect(sdk.configurations + sdk.purchases + sdk.paywalls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'subscription controls fit a small phone in $language with large text',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = SubscriptionController(
          FakeRevenueCat(),
          const BillingConfiguration(apiKey: 'test_fixture', supported: true),
        );
        await controller.setIdentity('guest', () async => null);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(OfflineApiClient()),
              subscriptionProvider.overrideWith((_) => controller),
              billingConfigurationProvider.overrideWithValue(
                controller.configuration,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: language == 'en' ? ThemeMode.light : ThemeMode.dark,
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.7)),
                child: child!,
              ),
              home: const SubscriptionScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final purchase = find.byKey(const ValueKey('subscription-purchase'));
        await tester.scrollUntilVisible(purchase, 250);
        await tester.pumpAndSettle();
        await tester.tap(purchase);
        await tester.pumpAndSettle();
        expect(controller.state.hasPro, isTrue);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('subscription-manage')),
          200,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
