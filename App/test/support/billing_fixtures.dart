import 'package:agenda/services/revenuecat_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

CustomerInfo billingInfo({
  bool active = false,
  bool renews = true,
  String entitlement = proEntitlement,
  bool purchased = false,
  String originalId = 'an-original-alias',
  VerificationResult verification = VerificationResult.notRequested,
}) {
  final pro = EntitlementInfo(
    entitlement,
    active,
    renews,
    '2026-09-29T00:00:00Z',
    '2026-09-29T00:00:00Z',
    'monthly',
    true,
    expirationDate: '2026-10-29T00:00:00Z',
    verification: verification,
  );
  return CustomerInfo(
    EntitlementInfos(
      {if (active || purchased) entitlement: pro},
      {if (active) entitlement: pro},
    ),
    const {},
    [if (active) 'monthly'],
    [if (active || purchased) 'monthly'],
    const [],
    '2026-09-29T00:00:00Z',
    originalId,
    const {},
    '2026-09-29T00:00:00Z',
  );
}

Package monthlyPackage({String period = 'P1M'}) => Package(
  r'$rc_monthly',
  PackageType.monthly,
  StoreProduct(
    'monthly',
    'Monthly subscription',
    'TaskFlow Pro',
    4.99,
    '€4.99',
    'EUR',
    subscriptionPeriod: period,
  ),
  const PresentedOfferingContext('default', null, null),
);

Offerings billingOfferings({String period = 'P1M'}) {
  final package = monthlyPackage(period: period);
  final offering = Offering('default', 'Default offering', const {}, [
    package,
  ], monthly: package);
  return Offerings({'default': offering}, current: offering);
}

class FakeRevenueCat extends RevenueCatGateway {
  CustomerInfo info = billingInfo();
  Offerings catalog = billingOfferings();
  CustomerInfo Function(String?)? accountInfo;
  Future<CustomerInfo> Function()? purchaseAction;
  Object? infoError;
  Object? offeringsError;
  Object? identityError;
  PaywallResult paywallResult = PaywallResult.cancelled;
  void Function()? centerAction;
  final listeners = <CustomerInfoUpdateListener>{};
  final identities = <String?>[];
  int configurations = 0,
      purchases = 0,
      restores = 0,
      paywalls = 0,
      centers = 0;
  String? locale;
  @override
  Future<void> configure(
    BillingConfiguration configuration,
    String? appUserId,
  ) async {
    configurations++;
  }

  @override
  Future<CustomerInfo> identify(String? appUserId) async {
    identities.add(appUserId);
    if (identityError != null) throw identityError!;
    return info = accountInfo?.call(appUserId) ?? info;
  }

  @override
  Future<void> setLocale(String? value) async {
    locale = value;
  }

  @override
  Future<CustomerInfo> customerInfo() async {
    if (infoError != null) throw infoError!;
    return info;
  }

  @override
  Future<Offerings> offerings() async {
    if (offeringsError != null) throw offeringsError!;
    return catalog;
  }

  @override
  Future<CustomerInfo> purchase(Package package) async {
    purchases++;
    return info =
        await (purchaseAction?.call() ??
            Future.value(billingInfo(active: true)));
  }

  @override
  Future<CustomerInfo> restore() async {
    restores++;
    return info;
  }

  @override
  Future<PaywallResult> paywall(Offering offering) async {
    paywalls++;
    return paywallResult;
  }

  @override
  Future<void> customerCenter() async {
    centers++;
    centerAction?.call();
  }

  @override
  void addListener(CustomerInfoUpdateListener listener) {
    listeners.add(listener);
  }

  @override
  void removeListener(CustomerInfoUpdateListener listener) {
    listeners.remove(listener);
  }

  void emit(CustomerInfo value) {
    for (final listener in listeners.toList()) {
      listener(value);
    }
  }
}
