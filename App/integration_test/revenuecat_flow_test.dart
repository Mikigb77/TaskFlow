// Real Test Store network + native dialogs, no mocked purchase channels.
// The host chooses Cancel, Test Failed Purchase, and Test Valid Purchase at
// the printed markers. This deliberately refuses platform/production keys.
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/services/revenuecat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'RevenueCat Test Store purchase, restore, paywall and account isolation',
      (tester) async {
    final configuration = BillingConfiguration.environment();
    expect(configuration.isTestStore, isTrue,
        reason: 'Never run this flow against a real store.');
    expect(configuration.issue, isNull);
    const id = String.fromEnvironment('REVENUECAT_SMOKE_USER_ID');
    expect(id.startsWith('taskflow-sdk-smoke-'), isTrue,
        reason: 'Provide a fresh test-only REVENUECAT_SMOKE_USER_ID beginning '
            'with taskflow-sdk-smoke-. Add it and its -second identity to the '
            'RevenueCat sandbox allowlist before running this test.');
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Center(
                child: Text('TaskFlow — RevenueCat Test Store validation')))));
    final gateway = NativeRevenueCatGateway();
    await gateway.configure(configuration, null);
    final originalId = await Purchases.appUserID;
    final controller = SubscriptionController(gateway, configuration);
    try {
      await controller.setIdentity(id, () async => id);
      expect(controller.state.ready, isTrue);
      expect(controller.state.monthly, isNotNull,
          reason:
              'Set a current offering with a one-month package in RevenueCat.');
      expect(controller.state.monthly!.storeProduct.identifier, 'monthly');
      expect(controller.state.hasPro, isFalse);
      debugPrint('RC_SMOKE_CANCEL');
      expect(await controller.purchaseMonthly(), BillingResult.cancelled);
      expect(controller.state.hasPro, isFalse);
      debugPrint('RC_SMOKE_FAIL');
      expect(await controller.purchaseMonthly(), BillingResult.failed);
      expect(controller.state.hasPro, isFalse);
      debugPrint('RC_SMOKE_BUY');
      expect(await controller.purchaseMonthly(), BillingResult.active);
      expect(controller.state.hasPro, isTrue);
      expect(await controller.restorePurchases(), BillingResult.restored);
      debugPrint('RC_SMOKE_CENTER');
      // Close the native Customer Center. Its availability depends on dashboard setup.
      final center = await controller.presentCustomerCenter('en');
      debugPrint('RC_SMOKE_CENTER_RESULT=${center.name}');
      await controller.setIdentity('$id-second', () async => '$id-second');
      expect(controller.state.hasPro, isFalse);
      debugPrint('RC_SMOKE_PAYWALL');
      final paywall = await controller.presentPaywall('en');
      expect(paywall, BillingResult.cancelled);
      await controller.setIdentity(id, () async => id);
      expect(controller.state.hasPro, isTrue);
      debugPrint('RC_SMOKE_PASSED');
    } finally {
      controller.dispose();
      await Purchases.logIn(originalId);
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
