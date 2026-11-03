# RevenueCat in TaskFlow

Implemented on `dev` with `purchases_flutter` and `purchases_ui_flutter` **11.0.0**. Entry point: **Settings → TaskFlow Pro**. The public Test Store SDK key is used for development and private Android staging. Accounts without Pro get 10 free dictations a month and 100 MB of file space in total; Pro removes both limits. The backend enforces both independently, and typing tasks is never limited (`.claude/ux-review/DECISIONS.md`, free tier).

## 1. Install with Pub

Run inside `App/`:

```sh
flutter pub add purchases_flutter purchases_ui_flutter
flutter pub get
```

The dependencies and lockfile are already updated. Commit the lockfile so collaborators use the tested versions. On Windows, Flutter needs generated plugin symlinks (Developer Mode or equivalent local directory junctions).

Android now uses `FlutterFragmentActivity`, retains `singleTop`, and requires at least API 24 for native paywalls. Existing capture, speech and calendar bridges remain attached. iOS is configured for 15+, with a CocoaPods Podfile and the In-App Purchase capability; run `flutter pub get`, then `pod install` inside `ios/` on a Mac and open `Runner.xcworkspace`. iOS cannot be compiled on this Windows workstation.

Reference: [Flutter installation](https://www.revenuecat.com/docs/getting-started/installation/flutter).

## 2. Configure the RevenueCat catalog

The SDK retrieves this configuration; it cannot create dashboard products or publish a paywall using a public SDK key.

**Verified against your project on 2026-09-29:** the Current `default` offering returns `monthly` at **US$9.99/month**, and its purchase activates `taskflow_pro`. The existing price was used unchanged. Customer Center opens successfully. The branded **TaskFlow Pro — Monthly Test Preview** paywall is now published for `default`, with English/Spanish/Catalan text, light/dark colors, restore and close actions, and dynamic product pricing. [Open the paywall editor](https://app.revenuecat.com/projects/bc7d7cfe/paywalls/wff7b0ee1ada604f1f/builder). It explicitly describes simulated purchases and makes no claims about unreleased paid benefits. Replace its test copy and add real Terms/Privacy links before selling.

| Dashboard item | Value |
| --- | --- |
| App/provider for local testing | Test Store associated with the supplied key |
| Entitlement identifier | `taskflow_pro` (case sensitive) |
| Test Store product identifier | `monthly` |
| Product duration | One month, auto-renewing |
| Offering identifier | `default` (or another offering marked **Current**) |
| Package | Standard **Monthly**, identifier `$rc_monthly` |
| Package's Test Store product | `monthly` |

In **Product catalog → Entitlements**, create `taskflow_pro`. Create or inspect the `monthly` Test Store product under **Products**, choose its test price, and attach it to that entitlement. Under **Offerings**, attach `monthly` to the Monthly package and mark the offering Current. The product ID, package ID and entitlement ID are three different identifiers.

The app uses `offerings.current.monthly`; it also accepts a custom package called `monthly` when the product's duration is `P1M`. A missing offering or incorrect duration disables checkout with a retry message. Prices come from `StoreProduct.priceString`, including the store currency. No production price is hardcoded.

For real stores, create the auto-renewing monthly subscription in Play Console/App Store Connect, connect those apps to the same RevenueCat project, and associate each store product with the same package and entitlement. On Play, configure an active monthly base plan; RevenueCat identifiers may include `subscriptionId:basePlanId`. The app selects the package, so it does not hardcode a Play base-plan identifier. The store package/bundle identifier must match the app; the current development Android identifier is `com.example.agenda`.

References: [Products and offerings](https://www.revenuecat.com/docs/getting-started/displaying-products), [Test Store setup](https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store).

### Staging sandbox access

On 12 October 2026, with the owner's approval, **Project settings → General →
Sandbox testing access** was changed from the six-account allowlist to **Anybody**.
Invited staging testers can now make simulated purchases that grant `taskflow_pro`
without maintaining a second list of RevenueCat IDs. This is a project-wide
sandbox setting; it does not take real payments.

TaskFlow still requires login, staging signup still requires an invitation or
an approved owner address, and the production backend rejects sandbox receipts
even if `REVENUECAT_ALLOW_SANDBOX` is accidentally enabled. Keep staging and
production billing identities isolated. Revisit the project setting when adding
real store apps. [Sandbox access documentation](https://www.revenuecat.com/docs/projects/sandbox-access).

The onboarding item **Create a real app configuration** means connecting Play Console/App Store Connect, not replacing TaskFlow authentication with RevenueCat Auth. This remains incomplete until the developer/store account and store products exist.

## 3. Initialize once and bind account identity

Complete native SDK implementation: [`revenuecat_service.dart`](../lib/services/revenuecat_service.dart).

The native singleton is configured once. This is the underlying setup used by the gateway:

```dart
await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);
await Purchases.configure(
  PurchasesConfiguration(publicSdkKey)
    ..appUserID = billingId // null lets RevenueCat generate an anonymous ID
    ..entitlementVerificationMode = EntitlementVerificationMode.informational
    ..automaticDeviceIdentifierCollectionEnabled = false,
);
```

Do not configure Purchases again inside a widget build or screen navigation. The provider keeps the SDK alive through the app lifecycle and uses `logIn`/`logOut` for identity changes.

`Backend/core/migrations/0013_user_billing_id.py` gives every TaskFlow user a unique, persistent UUID. Login, registration and `/api/auth/me/` return this read-only `billing_id`; it stays the same across email changes and devices. Sequential database IDs and email addresses are not used as RevenueCat customer IDs. Deploy the backend migration before the updated client:

```sh
# From Backend/; the normal container startup applies migrations.
docker compose up -d --build api
# For a non-Docker deployment:
python manage.py migrate
```

Older saved sessions fetch `/auth/me/` once to retrieve their identity. Failure leaves billing unavailable until refresh, while offline tasks and account login continue to work. A signed-in user is never silently treated as a guest if identity resolution fails.

Before login, the SDK can have an anonymous ID, but TaskFlow requires an account before entering the app or purchasing. Signing into TaskFlow calls `Purchases.logIn(billingId)`, using RevenueCat's alias/merge rules. Signing out calls `logOut` only for an identified SDK user; account-to-account switches use `logIn` directly. Purchases therefore follow the authenticated account across devices.

### Private Android release builds

RevenueCat intentionally shows an API-key warning and terminates a release app
using a Test Store key. A Dart `APP_ENV=staging` check alone cannot disable that
native check. The APK from build 4003 uses the Android SDK's documented
`DangerousSettings.forceAllowTestStoreInReleaseBuilds()` opt-in through
`StagingBillingBridge`, because purchases_flutter 11.0.0 does not expose it yet.

The bridge requires all of: the native staging build flag, package
`com.example.agenda.staging`, and the exact public test key compiled from
`config/staging.json`. It uses RevenueCat's standard hybrid configuration and
CustomerInfo mapper/listener. Paywalls, checkout, purchase receipts, restore and
server entitlement checks stay real; only the payment is simulated.

This remains an optimized, non-debuggable release APK with HTTPS, real account
authentication and developer login disabled. The build script verifies its
manifest and rejects private test credentials. Staging Play bundle builds are
blocked. Production retains the normal SDK setup and refuses Test Store keys.
An iOS staging release is also rejected until an equivalent native bridge is
implemented and tested on macOS; do not assume the Android fix covers iOS.

Build a normal installable APK with `./scripts/build-staging.ps1`. Validate real
release-mode checkout with `./scripts/test-staging-billing.ps1 -Device emulator-5556`
after preparing the private staging fixture. The latter embeds only synthetic
credentials in a separate test build and restores the normal APK afterwards.
Never distribute an integration-test APK.

Reference: [RevenueCat's internal-release Test Store opt-in](https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store#allowing-the-test-store-in-a-release-build).

Review **Project settings → Restore behavior** before launch. Decide whether purchases may transfer between TaskFlow accounts or stay with their original owner; do not change this casually after launch. One store account can be associated with multiple TaskFlow logins. Test the chosen policy with real store sandbox accounts. Keep production and development backend user data/projects separate; database clones retain billing UUIDs.

Reference: [Identifying customers](https://www.revenuecat.com/docs/customers/identifying-customers).

## 4. Retrieve customer info and check Pro

Complete state/identity implementation: [`subscription_provider.dart`](../lib/providers/subscription_provider.dart).

```dart
final info = await Purchases.getCustomerInfo();
final pro = info.entitlements.active['taskflow_pro'];
final hasPro = pro?.isActive == true &&
    pro?.verification != VerificationResult.failed &&
    info.entitlements.verification != VerificationResult.failed;
```

In a TaskFlow `ConsumerWidget`, use the existing providers rather than making independent SDK calls:

```dart
final hasPro = ref.watch(hasProProvider);
final subscription = ref.watch(subscriptionProvider);
final customerInfo = subscription.customerInfo;
final entitlement = subscription.pro;
```

`willRenew == false` does **not** mean access has ended: a cancelled subscription may still have an active entitlement. The subscription screen displays renewal/access-until dates from CustomerInfo. No separate permanent `isPro` boolean is persisted.

A CustomerInfo listener refreshes state, is removed on disposal, and does not trust late callback payloads from an old account. The SDK's `originalAppUserId` may be an alias, so it is not used as an identity-equality check. Identity changes and purchase operations are serialized; account switches clear UI access immediately and discard results from earlier accounts.

CustomerInfo updates are not a server push feed. The app also refreshes on resume, subscription-screen entry, purchase, restore and Customer Center dismissal. RevenueCat manages its cache; temporary network errors preserve previously verified access for the same account. An unavailable status remains distinct from an inactive subscription.

## 5. Buy and restore

The current purchase API is `Purchases.purchase(PurchaseParams.package(package))`. The older `purchasePackage` API is not used.

```dart
// Inside a TaskFlow ConsumerWidget callback. Busy, errors and account races are
// handled by the controller. The result is suitable for a localized snackbar.
final billing = ref.read(subscriptionProvider.notifier);
final result = await billing.purchaseMonthly();
// BillingResult.active means CustomerInfo actually contains active taskflow_pro.

final restored = await billing.restorePurchases();
// BillingResult.noPurchases is a successful restore without active Pro access.
```

The complete purchase error handling is in the controller and `purchaseErrorCode`/`billingIssue` helpers:

- User cancellation is benign and leaves the previous state intact.
- Pending payment does not unlock Pro. The SDK updates CustomerInfo after payment confirmation.
- Network/store failures show localized retry messages without throwing into the widget tree.
- Receipt ownership conflicts direct the customer to the original account.
- Repeated taps are blocked while an operation is active.
- A successful purchase or paywall result without `taskflow_pro` does not grant access.
- Restore is always user initiated; login and app resume do not trigger store restore dialogs.

The direct monthly purchase button is shown in Test Store mode for diagnostics. Production checkout opens the RevenueCat paywall, which carries the offer details, benefits and legal links you publish.

Reference: [Making purchases](https://www.revenuecat.com/docs/getting-started/making-purchases).

## 6. Present the RevenueCat paywall

The Test Store paywall is published for the Current offering with the standard Monthly package selected by default. It has no trial, annual option, invented discount, or placeholder legal URLs. Its close control uses **Close paywall** and restore uses **Restore purchases**. English uses the product price and period variables; Spanish and Catalan use the dynamic price with “al mes” for this monthly-only offering. All three localizations explain that the purchase is simulated. Before production, replace test copy with accurate paid benefits and add real Terms and Privacy links. These dashboard localizations are independent of Flutter's UI translations. The app passes its current language to the SDK before opening billing UI; Catalan delivery and dismissal were verified in the normal Android app after publication.

The app calls:

```dart
await Purchases.overridePreferredUILocale(locale); // e.g. es-ES
final result = await RevenueCatUI.presentPaywallIfNeeded(
  'taskflow_pro',
  offering: offering,
  displayCloseButton: true,
);
final updatedInfo = await Purchases.getCustomerInfo();
// Always inspect updatedInfo.entitlements, never grant access from result alone.
```

Inside TaskFlow, use the coordinated wrapper:

```dart
await ref.read(subscriptionProvider.notifier).presentPaywall(
  Localizations.localeOf(context).toLanguageTag(),
);
```

Full Flutter screen, including result/error messages: [`subscription_screen.dart`](../lib/screens/subscription_screen.dart). An active Pro customer is not sent through checkout again. The SDK may supply a default paywall when none is published; publish the branded version before release.

If a development session still shows the pink **RevenueCat Paywalls** fallback after publication, fully stop and relaunch the app so the native SDK reloads its remote configuration. Flutter hot reload and refreshing CustomerInfo/offerings are not evidence that the new paywall has reached the SDK. On 2026-09-29, relaunching the normal Android app resolved this without rebuilding or clearing app data. Verify the actual paywall, its test checkout and dismissal on the device after dashboard changes; if it still falls back, check the SDK logs, published offering association and SDK compatibility.

Reference: [Displaying RevenueCat Paywalls](https://www.revenuecat.com/docs/tools/paywalls/displaying-paywalls).

## 7. Customer Center

**Manage subscription** appears for customers with purchase history. It opens `RevenueCatUI.presentCustomerCenter()` and retrieves CustomerInfo when dismissed. Configure support/contact information and the desired management paths in the RevenueCat dashboard. Availability depends on your RevenueCat plan and dashboard setup; verify it with the configured store. Store cancellation, refunds and promotions need store sandbox validation, even if Test Store checkout works.

```dart
await ref.read(subscriptionProvider.notifier).presentCustomerCenter(
  Localizations.localeOf(context).toLanguageTag(),
);
```

When CustomerInfo supplies a `managementURL`, **Open store subscription settings** provides a separate fallback. It opens the actual SDK-provided HTTPS store URL; the app does not simulate cancellations or refunds.

References: [Customer Center](https://www.revenuecat.com/docs/tools/customer-center), [Flutter integration](https://www.revenuecat.com/docs/tools/customer-center/customer-center-flutter).

## 8. Release configuration and paid features

Use the matching **public platform SDK key** in profile/release builds:

```sh
flutter build appbundle --release --dart-define=REVENUECAT_ANDROID_API_KEY=goog_YOUR_PUBLIC_KEY
flutter build ipa --release --dart-define=REVENUECAT_IOS_API_KEY=appl_YOUR_PUBLIC_KEY
```

Debug builds use the supplied `test_` key unless a platform key is provided. To test a different Test Store, pass `--dart-define=REVENUECAT_TEST_API_KEY=test_YOUR_KEY`. Production profile/release builds reject Test Store keys. The sole release exception is the guarded private Android staging bridge described above. Without a valid configuration, the app shows subscriptions as unavailable instead of calling the SDK's unsafe release configuration. Never put a RevenueCat secret key in Flutter.

Android production signing, final store identifiers, store credentials/notifications, legal copy and the actual paid benefits must be set before selling. TestFlight and Play testing tracks use release builds: use the real platform SDK key and store sandbox there, not a Test Store key.

Voice capture uses `voiceAvailableProvider` for the interface (Pro, complimentary, or free dictations left in the account's cached `free_voice` block), and Django decides independently whether each AI request is Pro or uses a free dictation. The backend retrieves verified RevenueCat entitlement data for the authenticated account's `billing_id`; a mobile `hasPro` claim cannot authorize a request. Complimentary access is also granted by the server. Production rejects sandbox entitlements. Real-store launch still needs renewal, expiry, transfer/refund and offline-policy validation; authenticated, idempotent webhooks can complement the current request-time verification.

Flutter web and desktop show an unsupported-platform message without calling native billing channels. A future Next.js/Flutter web checkout requires RevenueCat Web Billing/provider configuration and web-specific checkout; these native paywall methods should not be called on the web.

## 9. Verification

```sh
# App/
flutter analyze
flutter test test/subscription_test.dart test/subscription_screen_test.dart test/api_client_test.dart
flutter build apk --debug

# Backend/
docker compose exec -T api python manage.py test core --noinput
docker compose exec -T api python manage.py makemigrations --check --dry-run
```

The tests cover exact/expired/failed-verification entitlements, cancellation without premature loss of access, payment pending, missing offerings, incorrect periods, cancellation/error/restore results, concurrent taps, late results across account switches, SDK callbacks, missing account identity, legacy session upgrades, UUID migration uniqueness, and English/Spanish/Catalan small-phone layouts at 170% text.

The debug SDK smoke test is `integration_test/revenuecat_flow_test.dart`. Choose a fresh ID beginning with `taskflow-sdk-smoke-`. An already-active subscription is unsuitable because the test starts by asserting no Pro access. If the project later returns to restricted sandbox access, allowlist that ID **and `<id>-second`** first; the current approved **Anybody** policy does not require this.

```sh
flutter drive --driver=test_driver/appearance_test.dart --target=integration_test/revenuecat_flow_test.dart -d emulator-5554 --dart-define=REVENUECAT_SMOKE_USER_ID=taskflow-sdk-smoke-YOUR_FRESH_UUID --keep-app-running
```

It refuses production keys and missing/non-test-prefixed customer IDs and prints markers for cancelling, simulating failure/success, and closing Customer Center/paywall dialogs. It restores the previously selected RevenueCat identity afterward and does not delete TaskFlow data. Run this with the catalog prepared. Reinstall the normal debug APK afterward using `adb install -r`; do not uninstall or clear app data.

For private staging, prefer `./scripts/test-staging-billing.ps1`: it runs the release-mode Flutter checks with Android instrumentation operating the real native Test Store dialogs, verifies cloud entitlements and paid AI, and restores the normal release APK. The instrumented test receives Flutter's result protocol without bundling the development integration plugin in the distributable app.

Before production, separately test store sandbox checkout, reinstall/restore, signing into another device, the selected account-transfer policy, renewal, expiry, grace/billing-retry states, refunds, and Customer Center's actual store management paths on Android and iOS.

Actual local results are recorded in [RevenueCat validation](REVENUECAT_VALIDATION.md).
