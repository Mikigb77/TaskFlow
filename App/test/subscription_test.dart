import 'dart:async';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/services/revenuecat_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'support/billing_fixtures.dart';

const configuration = BillingConfiguration(
  apiKey: 'test_fixture',
  supported: true,
);

void main() {
  late FakeRevenueCat sdk;
  late SubscriptionController controller;
  setUp(() {
    sdk = FakeRevenueCat();
    controller = SubscriptionController(sdk, configuration);
  });
  tearDown(() => controller.dispose());
  Future<void> start([String? id = 'opaque-account-a']) =>
      controller.setIdentity(id ?? 'guest', () async => id);

  test(
    'server complimentary access requires no store or purchase and clears on switch',
    () async {
      await controller.setIdentity(
        'owner',
        () async => 'owner-id',
        complimentary: true,
      );
      expect(controller.state.hasPro, isTrue);
      expect(controller.state.complimentary, isTrue);
      expect(controller.state.canPurchase, isFalse);
      expect(await controller.purchaseMonthly(), BillingResult.active);
      expect(await controller.presentPaywall('en'), BillingResult.active);
      expect(sdk.configurations + sdk.purchases + sdk.paywalls, 0);
      final switching = start('another-account');
      expect(controller.state.hasPro, isFalse);
      await switching;
      expect(controller.state.hasPro, isFalse);
      expect(controller.state.complimentary, isFalse);
    },
  );

  test(
    'complimentary access works when a native store is unavailable',
    () async {
      final other = SubscriptionController(
        sdk,
        const BillingConfiguration(apiKey: '', supported: false),
      );
      addTearDown(other.dispose);
      await other.setIdentity(
        'owner',
        () async => 'owner-id',
        complimentary: true,
      );
      expect(other.state.hasPro, isTrue);
      expect(other.state.issue, isNull);
      expect(await other.purchaseMonthly(), BillingResult.active);
      other.suspend();
      expect(other.state.hasPro, isFalse);
    },
  );

  test(
    'refresh observes a server grant and its revocation on the same account',
    () async {
      var granted = false;
      late SubscriptionController other;
      other = SubscriptionController(
        sdk,
        configuration,
        refreshAccount: () async {
          await other.setIdentity(
            'owner',
            () async => 'owner-id',
            complimentary: granted,
          );
        },
      );
      addTearDown(other.dispose);
      await other.setIdentity('owner', () async => 'owner-id');
      expect(other.state.hasPro, isFalse);
      granted = true;
      await other.refresh();
      expect(other.state.hasPro, isTrue);
      granted = false;
      await other.refresh();
      expect(other.state.hasPro, isFalse);
      expect(other.state.complimentary, isFalse);
    },
  );

  test(
    'only the exact active entitlement grants Pro; cancellation keeps paid access',
    () async {
      sdk.info = billingInfo(active: true, renews: false);
      await start();
      expect(controller.state.hasPro, isTrue);
      expect(controller.state.pro!.willRenew, isFalse);
      sdk.info = billingInfo(
        active: true,
        entitlement: 'some_other_entitlement',
      );
      await controller.refresh();
      expect(controller.state.hasPro, isFalse);
      sdk.info = billingInfo(purchased: true);
      await controller.refresh();
      expect(controller.state.hasPro, isFalse);
    },
  );
  test('failed entitlement verification never grants access', () async {
    sdk.info = billingInfo(
      active: true,
      verification: VerificationResult.failed,
    );
    await start();
    expect(controller.state.hasPro, isFalse);
  });
  test(
    'monthly purchase gets entitlement from returned customer info',
    () async {
      await start();
      expect(await controller.purchaseMonthly(), BillingResult.active);
      expect(controller.state.hasPro, isTrue);
      await controller.purchaseMonthly();
      expect(sdk.purchases, 1);
    },
  );
  test('purchase success without entitlement does not unlock Pro', () async {
    sdk.purchaseAction = () async => billingInfo(purchased: true);
    await start();
    expect(
      await controller.purchaseMonthly(),
      BillingResult.awaitingEntitlement,
    );
    expect(controller.state.hasPro, isFalse);
  });
  for (final pair in [
    (PurchasesErrorCode.purchaseCancelledError, BillingResult.cancelled),
    (PurchasesErrorCode.paymentPendingError, BillingResult.pending),
    (PurchasesErrorCode.networkError, BillingResult.failed),
  ]) {
    test(
      'handles ${pair.$1.name} without granting Pro or leaving checkout busy',
      () async {
        sdk.purchaseAction = () async =>
            throw PlatformException(code: '${pair.$1.index}');
        await start();
        expect(await controller.purchaseMonthly(), pair.$2);
        expect(controller.state.hasPro, isFalse);
        expect(controller.state.busy, isFalse);
        if (pair.$2 == BillingResult.failed) {
          expect(controller.state.issue, BillingIssue.network);
        } else {
          expect(controller.state.issue, isNull);
        }
      },
    );
  }
  test(
    'unknown nonnumeric platform errors produce a recoverable failure',
    () async {
      sdk.purchaseAction = () async =>
          throw PlatformException(code: 'channel-error');
      await start();
      expect(await controller.purchaseMonthly(), BillingResult.failed);
      expect(controller.state.issue, BillingIssue.unknown);
    },
  );
  test(
    'restore handles an empty account and a valid Pro subscription',
    () async {
      await start();
      expect(await controller.restorePurchases(), BillingResult.noPurchases);
      sdk.info = billingInfo(active: true);
      expect(await controller.restorePurchases(), BillingResult.restored);
      expect(controller.state.hasPro, isTrue);
    },
  );
  test(
    'paywall purchase result alone cannot grant Pro; locale follows app',
    () async {
      sdk.paywallResult = PaywallResult.purchased;
      await start();
      expect(
        await controller.presentPaywall('es-ES'),
        BillingResult.awaitingEntitlement,
      );
      expect(sdk.locale, 'es-ES');
      expect(controller.state.hasPro, isFalse);
    },
  );
  test(
    'paywall cancellation is benign and an active subscriber is not shown it',
    () async {
      await start();
      expect(await controller.presentPaywall('en'), BillingResult.cancelled);
      sdk.info = billingInfo(active: true);
      await controller.refresh();
      expect(await controller.presentPaywall('en'), BillingResult.active);
      expect(sdk.paywalls, 1);
    },
  );
  test('Customer Center refreshes entitlement when dismissed', () async {
    sdk.info = billingInfo(active: true);
    sdk.centerAction = () {
      sdk.info = billingInfo(purchased: true);
    };
    await start();
    expect(await controller.presentCustomerCenter('es'), BillingResult.updated);
    expect(controller.state.hasPro, isFalse);
    expect(sdk.centers, 1);
  });
  test(
    'network failure keeps same-account cached access; SDK expiry clears it',
    () async {
      sdk.info = billingInfo(active: true);
      await start();
      sdk.infoError = PlatformException(
        code: '${PurchasesErrorCode.offlineConnectionError.index}',
      );
      await controller.refresh();
      expect(controller.state.hasPro, isTrue);
      expect(controller.state.issue, BillingIssue.network);
      sdk.infoError = null;
      sdk.info = billingInfo(purchased: true);
      await controller.refresh();
      expect(controller.state.hasPro, isFalse);
    },
  );
  test(
    'missing current offering does not remove Pro or prevent restore',
    () async {
      sdk.info = billingInfo(active: true);
      sdk.catalog = const Offerings({});
      await start();
      expect(controller.state.hasPro, isTrue);
      expect(controller.state.issue, BillingIssue.configuration);
      expect(await controller.restorePurchases(), BillingResult.restored);
    },
  );
  test(
    'incorrect monthly duration cannot be purchased or presented as monthly',
    () async {
      sdk.catalog = billingOfferings(period: 'P1Y');
      await start();
      expect(controller.state.monthly, isNull);
      expect(await controller.purchaseMonthly(), BillingResult.failed);
      expect(await controller.presentPaywall('en'), BillingResult.failed);
      expect(sdk.purchases + sdk.paywalls, 0);
    },
  );
  test(
    'account switches clear Pro immediately and configure only once',
    () async {
      sdk.accountInfo = (id) => billingInfo(active: id == 'opaque-account-a');
      await start();
      expect(controller.state.hasPro, isTrue);
      final switching = start('opaque-account-b');
      expect(controller.state.hasPro, isFalse);
      await switching;
      await start(null);
      expect(sdk.configurations, 1);
      expect(sdk.identities, ['opaque-account-a', 'opaque-account-b', null]);
    },
  );
  test(
    'identity failure cannot use the previous SDK customer for purchases',
    () async {
      sdk.info = billingInfo(active: true);
      await start();
      sdk.identityError = PlatformException(code: '10');
      await start('opaque-account-b');
      expect(controller.state.hasPro, isFalse);
      expect(controller.state.ready, isFalse);
      expect(await controller.restorePurchases(), BillingResult.busy);
      expect(sdk.restores, 0);
      sdk.identityError = null;
      sdk.info = billingInfo();
      await controller.refresh();
      expect(controller.state.ready, isTrue);
    },
  );
  test(
    'account resolution failure never falls back to anonymous purchases',
    () async {
      await controller.setIdentity(
        'legacy-account',
        () async => throw StateError('offline'),
      );
      expect(controller.state.issue, BillingIssue.accountUnavailable);
      expect(sdk.configurations, 0);
    },
  );
  test(
    'in-flight purchase is serialized before identity change and its result is discarded',
    () async {
      final purchase = Completer<CustomerInfo>();
      final started = Completer<void>();
      sdk.purchaseAction = () {
        started.complete();
        return purchase.future;
      };
      sdk.accountInfo = (_) => billingInfo();
      await start();
      final buying = controller.purchaseMonthly();
      await started.future;
      expect(await controller.purchaseMonthly(), BillingResult.busy);
      final switching = start('opaque-account-b');
      expect(controller.state.hasPro, isFalse);
      expect(sdk.identities, ['opaque-account-a']);
      purchase.complete(billingInfo(active: true));
      expect(await buying, BillingResult.accountChanged);
      await switching;
      expect(controller.state.hasPro, isFalse);
      expect(sdk.identities.last, 'opaque-account-b');
      expect(sdk.purchases, 1);
    },
  );
  test(
    'late listener payload from an old alias is never applied to new account',
    () async {
      await start('opaque-account-b');
      sdk.emit(billingInfo(active: true, originalId: 'opaque-account-a'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.hasPro, isFalse);
      sdk.info = billingInfo(active: true);
      sdk.emit(sdk.info);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.hasPro, isTrue);
    },
  );
  test(
    'release Test Store keys and unsupported platforms never invoke native SDK',
    () async {
      for (final config in [
        const BillingConfiguration(
          apiKey: 'test_fixture',
          supported: true,
          release: true,
        ),
        const BillingConfiguration(apiKey: '', supported: true, release: true),
        const BillingConfiguration(apiKey: 'test_fixture', supported: false),
        const BillingConfiguration(apiKey: 'sk_secret', supported: true),
      ]) {
        final billing = SubscriptionController(sdk, config);
        await billing.setIdentity('guest', () async => null);
        expect(billing.state.ready, isFalse);
        expect(billing.state.issue, isNotNull);
        billing.dispose();
      }
      expect(sdk.configurations, 0);
    },
  );
}
