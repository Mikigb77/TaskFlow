// Run only via scripts/test-staging-billing.ps1. The Android test drives the
// real native Test Store dialogs; no SDK, HTTP or entitlement mocks are used.
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/revenuecat_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'release Test Store checkout and cloud Pro access',
    (tester) async {
      expect(kReleaseMode, isTrue);
      const email = String.fromEnvironment('PROJECT_E2E_EMAIL');
      expect(email.startsWith('delivered+tf-owner-'), isTrue);
      final config = BillingConfiguration.environment();
      expect(
        config.staging && config.isTestStore && config.usesStagingBridge,
        isTrue,
      );
      expect(config.issue, isNull);
      // Isolate login storage; never overwrite the tester's real app session.
      FlutterSecureStorage.setMockInitialValues({});
      final api = ApiClient();
      expect(
        api.baseUrl,
        'https://taskflow-api-staging-177649734578.europe-west3.run.app',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Staging release verification')),
          ),
        ),
      );
      const channel = MethodChannel('taskflow/staging-billing');
      await expectLater(
        channel.invokeMethod('configure', {'apiKey': 'test_invalid'}),
        throwsA(isA<PlatformException>()),
      );
      final gateway = NativeRevenueCatGateway();
      await gateway.configure(config, null);
      final previousId = await Purchases.appUserID;
      final native = await channel.invokeMapMethod<String, dynamic>(
        'configure',
        {'apiKey': config.apiKey},
      );
      expect(native?['internalTestStore'], isTrue);
      expect(native?['debuggable'], isFalse);
      final controller = SubscriptionController(gateway, config);
      var updates = 0;
      void listener(CustomerInfo _) => updates++;
      gateway.addListener(listener);
      Future<void> waitForBillingIdle() async {
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (controller.state.busy && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(
          controller.state.busy,
          isFalse,
          reason: 'The CustomerInfo listener must finish refreshing.',
        );
      }

      Future<void> refreshBilling() async {
        // Raw native calls intentionally bypass the UI controller so repeat
        // runs can exercise checkout with an already-active test subscription.
        // Its CustomerInfo listener can start a refresh before purchase returns.
        await waitForBillingIdle();
        await controller.refresh();
        await waitForBillingIdle();
      }

      try {
        await api.signIn(
          email,
          const String.fromEnvironment('PROJECT_E2E_PASSWORD'),
        );
        expect(api.account!.complimentaryPro, isFalse);
        await controller.setIdentity(
          'staging-check',
          () async => api.account!.billingId,
        );
        expect(controller.state.ready, isTrue);
        expect(controller.state.monthly?.storeProduct.identifier, 'monthly');
        final wasPro = controller.state.hasPro;
        final before = await api.request('POST', 'billing/access/', data: {});
        expect(before['active'], wasPro);
        await gateway.setLocale('en');
        expect(
          await RevenueCatUI.presentPaywall(
            offering: controller.state.offering,
            displayCloseButton: true,
          ),
          PaywallResult.cancelled,
        );
        debugPrint(
          'STAGING_RELEASE: release initialization, login and real paywall passed',
        );

        // Call the same native purchase boundary even on a repeat run when an
        // earlier test subscription has not expired yet.
        Future<void> choiceError(PurchasesErrorCode expected) async {
          await Future<void>.delayed(const Duration(milliseconds: 800));
          try {
            await gateway.purchase(controller.state.monthly!);
            fail('Expected the native checkout result ${expected.name}');
          } on PlatformException catch (error) {
            expect(purchaseErrorCode(error), expected);
          }
          await refreshBilling();
          expect(controller.state.hasPro, wasPro);
        }

        await choiceError(PurchasesErrorCode.purchaseCancelledError);
        await choiceError(PurchasesErrorCode.testStoreSimulatedPurchaseError);
        await Future<void>.delayed(const Duration(milliseconds: 800));
        final purchased = await gateway.purchase(controller.state.monthly!);
        expect(purchased.entitlements.active[proEntitlement]?.isActive, isTrue);
        await refreshBilling();
        expect(
          controller.state.hasPro,
          isTrue,
          reason:
              'Receipt active=${controller.state.pro?.isActive}, '
              'verification=${controller.state.pro?.verification}, '
              'infoVerification=${controller.state.customerInfo?.entitlements.verification}, '
              'issue=${controller.state.issue}',
        );
        expect(await controller.restorePurchases(), BillingResult.restored);
        expect(
          updates,
          greaterThan(0),
          reason: 'Native CustomerInfo must reach Flutter.',
        );
        final access = await api.request('POST', 'billing/access/', data: {});
        expect(access['active'], isTrue);
        expect(access['sandbox'], isTrue);
        expect(access['complimentary'], isNot(true));
        debugPrint(
          'STAGING_RELEASE: cancel, failed purchase, purchase, restore and server entitlement passed',
        );
        final drafts = await api.request(
          'POST',
          'ai/drafts/',
          data: {
            'text':
                'Ana needs to finish exercise three in Physics by Thursday. '
                'We all need to prepare the final presentation in Physics by Friday.',
            'timezone': 'Europe/Madrid',
            'reference_time': '2026-10-11T12:00:00+02:00',
            'project_id': const String.fromEnvironment('PROJECT_E2E_PROJECT'),
          },
        );
        final tasks = drafts['tasks'] as List;
        expect(tasks, hasLength(2));
        expect(
          tasks.where((task) => task['assignment'] == 'member'),
          hasLength(1),
        );
        expect(
          tasks.where((task) => task['assignment'] == 'group'),
          hasLength(1),
        );
        debugPrint(
          'STAGING_RELEASE: live paid AI and project assignment passed',
        );
      } finally {
        gateway.removeListener(listener);
        controller.dispose();
        await gateway.identify(previousId);
        await api.signOut();
        api.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 7)),
  );
}
