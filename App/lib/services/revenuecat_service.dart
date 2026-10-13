import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

const proEntitlement = 'taskflow_pro';

enum BillingIssue {
  unsupportedPlatform,
  configuration,
  accountUnavailable,
  network,
  notAllowed,
  otherAccount,
  store,
  unknown,
}

/// These are public, app-specific SDK keys, never RevenueCat secret API keys.
class BillingConfiguration {
  const BillingConfiguration({
    required this.apiKey,
    required this.supported,
    this.release = false,
    this.staging = false,
    this.supportsStagingTestStore = false,
  });

  factory BillingConfiguration.environment() {
    final mobile =
        !kIsWeb &&
        [
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform);
    final platformKey = defaultTargetPlatform == TargetPlatform.iOS
        ? const String.fromEnvironment('REVENUECAT_IOS_API_KEY')
        : const String.fromEnvironment('REVENUECAT_ANDROID_API_KEY');
    const testKey = String.fromEnvironment(
      'REVENUECAT_TEST_API_KEY',
      defaultValue: 'test_EklrUiqxOvqXwTyiioVgnTwnBif',
    );
    const staging = String.fromEnvironment('APP_ENV') == 'staging';
    return BillingConfiguration(
      apiKey: platformKey.isNotEmpty
          ? platformKey
          : (kDebugMode || staging ? testKey : ''),
      supported: mobile,
      staging: staging,
      supportsStagingTestStore: defaultTargetPlatform == TargetPlatform.android,
      release: !kDebugMode,
    );
  }

  final String apiKey;
  final bool supported;
  final bool release;
  final bool staging;
  final bool supportsStagingTestStore;
  bool get isTestStore => apiKey.startsWith('test_');
  bool get usesStagingBridge =>
      staging && isTestStore && supportsStagingTestStore;
  BillingIssue? get issue {
    if (!supported) return BillingIssue.unsupportedPlatform;
    if (apiKey.isEmpty ||
        apiKey.startsWith('sk_') ||
        (release && isTestStore && !usesStagingBridge)) {
      return BillingIssue.configuration;
    }
    return null;
  }
}

PurchasesErrorCode? purchaseErrorCode(Object error) {
  if (error is! PlatformException) return null;
  // Some platform/plugin errors use textual codes. The SDK helper parses int.
  final code = int.tryParse(error.code);
  if (code == null || code < 0 || code >= PurchasesErrorCode.values.length) {
    return null;
  }
  return PurchasesErrorHelper.getErrorCode(error);
}

BillingIssue billingIssue(Object error) => switch (purchaseErrorCode(error)) {
  PurchasesErrorCode.networkError ||
  PurchasesErrorCode.offlineConnectionError ||
  PurchasesErrorCode.apiEndpointBlocked ||
  PurchasesErrorCode.productRequestTimeout => BillingIssue.network,
  PurchasesErrorCode.invalidCredentialsError ||
  PurchasesErrorCode.configurationError ||
  PurchasesErrorCode.productNotAvailableForPurchaseError =>
    BillingIssue.configuration,
  PurchasesErrorCode.purchaseNotAllowedError ||
  PurchasesErrorCode.insufficientPermissionsError => BillingIssue.notAllowed,
  PurchasesErrorCode.receiptAlreadyInUseError ||
  PurchasesErrorCode.receiptInUseByOtherSubscriberError ||
  PurchasesErrorCode.purchaseBelongsToOtherUser => BillingIssue.otherAccount,
  PurchasesErrorCode.storeProblemError => BillingIssue.store,
  _ => BillingIssue.unknown,
};

/// A small boundary for native SDK calls, also used by deterministic tests.
abstract class RevenueCatGateway {
  Future<void> configure(BillingConfiguration configuration, String? appUserId);
  Future<CustomerInfo> identify(String? appUserId);
  Future<void> setLocale(String? locale);
  Future<CustomerInfo> customerInfo();
  Future<Offerings> offerings();
  Future<CustomerInfo> purchase(Package package);
  Future<CustomerInfo> restore();
  Future<PaywallResult> paywall(Offering offering);
  Future<void> customerCenter();
  void addListener(CustomerInfoUpdateListener listener);
  void removeListener(CustomerInfoUpdateListener listener);
}

class NativeRevenueCatGateway implements RevenueCatGateway {
  static const _stagingChannel = MethodChannel('taskflow/staging-billing');
  @override
  Future<void> configure(
    BillingConfiguration configuration,
    String? appUserId,
  ) async {
    if (configuration.issue != null) {
      throw PlatformException(
        code: '${PurchasesErrorCode.configurationError.index}',
        message: 'Purchases are not configured for this build.',
      );
    }
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);
    if (configuration.usesStagingBridge) {
      // Never fall back to standard configure on failure: the native SDK
      // intentionally exits physical-device release builds using a test key.
      final result = await _stagingChannel.invokeMapMethod<String, dynamic>(
        'configure',
        {'apiKey': configuration.apiKey, 'appUserId': appUserId},
      );
      if (result?['configured'] != true ||
          result?['internalTestStore'] != true) {
        throw PlatformException(
          code: '${PurchasesErrorCode.configurationError.index}',
          message: 'The private staging purchase configuration is unavailable.',
        );
      }
      return;
    }
    // The native singleton survives widget rebuilds and Dart hot restarts.
    if (await Purchases.isConfigured) return;
    await Purchases.configure(
      PurchasesConfiguration(configuration.apiKey)
        ..appUserID = appUserId
        ..entitlementVerificationMode =
            EntitlementVerificationMode.informational
        ..automaticDeviceIdentifierCollectionEnabled = false,
    );
  }

  @override
  Future<CustomerInfo> identify(String? appUserId) async {
    if (appUserId == null) {
      if (!await Purchases.isAnonymous) return Purchases.logOut();
    } else if (await Purchases.appUserID != appUserId) {
      return (await Purchases.logIn(appUserId)).customerInfo;
    }
    return Purchases.getCustomerInfo();
  }

  @override
  Future<void> setLocale(String? locale) =>
      Purchases.overridePreferredUILocale(locale);
  @override
  Future<CustomerInfo> customerInfo() => Purchases.getCustomerInfo();
  @override
  Future<Offerings> offerings() => Purchases.getOfferings();
  @override
  Future<CustomerInfo> purchase(Package package) async =>
      (await Purchases.purchase(PurchaseParams.package(package))).customerInfo;
  @override
  Future<CustomerInfo> restore() => Purchases.restorePurchases();
  @override
  Future<PaywallResult> paywall(Offering offering) =>
      RevenueCatUI.presentPaywallIfNeeded(
        proEntitlement,
        offering: offering,
        displayCloseButton: true,
      );
  @override
  Future<void> customerCenter() => RevenueCatUI.presentCustomerCenter();
  @override
  void addListener(CustomerInfoUpdateListener listener) =>
      Purchases.addCustomerInfoUpdateListener(listener);
  @override
  void removeListener(CustomerInfoUpdateListener listener) =>
      Purchases.removeCustomerInfoUpdateListener(listener);
}
