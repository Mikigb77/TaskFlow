# RevenueCat validation

The September checks below are historical. Current staging configuration and
release verification are recorded in the October follow-up at the end.

## Initial verification — 2026-09-29

Branch: `dev`. Flutter 3.44.5 / Dart 3.12.2. `purchases_flutter` and `purchases_ui_flutter` 10.13.2. Android API 36 emulator (`emulator-5554`). Backend Docker/PostgreSQL. Only RevenueCat Test Store transactions were made; no real charge was initiated.

## Passed

- `flutter analyze --no-pub`: no issues.
- Full `flutter test --no-pub`: **219 tests passed**, including new billing tests and existing app regressions.
- Django `manage.py test core --noinput`: **82 tests passed** on PostgreSQL.
- Django `makemigrations --check --dry-run`: no changes detected.
- Backend container rebuilt, migration 0013 applied, service healthy. Existing user billing IDs are distinct UUIDs, stable through login and read-only to clients.
- Android debug APK built with `FlutterFragmentActivity` and native RevenueCat libraries.
- Real SDK integration test: **passed**. The native Test Store dialogs were operated through adb at the test's printed markers, without mocking RevenueCat channels or network responses.
- Normal app restored and opened through Settings → TaskFlow Pro; the real provider, status screen and management controls rendered successfully without Flutter runtime errors.

## Real SDK observations

| Check | Observed outcome |
| --- | --- |
| Supplied Test Store key | Accepted by RevenueCat |
| Current offering | `default` |
| Package | `$rc_monthly` |
| Product | `monthly`, `P1M`, US$9.99 (existing catalog price) |
| Cancel test purchase | `BillingResult.cancelled`, no Pro access |
| Simulate failed purchase | `BillingResult.failed`, no Pro access |
| Simulate successful purchase | Active `taskflow_pro` in CustomerInfo |
| Restore | Existing Pro entitlement recovered |
| Customer Center | Opened, displayed Monthly/Active/Test Store; dismissal returned `updated` |
| Switch to fresh second customer | Pro cleared and remained inactive |
| Native paywall | Opened and dismissed with `cancelled` |
| Return to purchasing customer | Pro recovered from RevenueCat |

During that initial SDK run, `default` had no published paywall and the SDK displayed its default template. The dashboard follow-up below subsequently published a branded test paywall. No catalog price or product was changed by the initial SDK test.

## Dashboard follow-up — 2026-09-29

- Published **TaskFlow Pro — Monthly Test Preview**, paywall `wff7b0ee1ada604f1f`, linked to the Current `default` offering and its preselected `$rc_monthly` package. RevenueCat's published-version selector confirms publication; the editor has no validation issues.
- Applied TaskFlow's forest green/warm light and mint/dark palettes. Reviewed English (US) and Spanish (Spain), including the 360 × 780 Android preview. Confirmed long content scrolls above the purchase footer.
- Verified the close action is **Close paywall**, restore is **Restore purchases**, and prices use the product price variable. Corrected the Spanish period label to “al mes”. Enlarged close/restore touch targets.
- The copy explicitly says this is a simulated subscription, existing features remain available, and paid benefits are still being defined. There is no free-trial promise or fake legal URL. Actual legal links and production benefit copy remain launch requirements.
- Saved **Allowed App User IDs only** for sandbox entitlements. Four entries cover the prior smoke customer, its anonymous alias, the second smoke identity, and the seeded local test account's stable billing UUID. Purchases from unlisted identities can be recorded but cannot grant test Pro.
- Updated the native integration test to require an explicitly supplied, pre-allowlisted test customer ID instead of generating an unlisted random ID. See the setup guide before rerunning it.
- `flutter analyze --no-pub integration_test/revenuecat_flow_test.dart`: no issues after the test identity change.
- The new paywall was reviewed in RevenueCat's browser preview. The earlier native purchase/restore results above predate this paywall and sandbox restriction; this dashboard follow-up does not claim a fresh native checkout run.

## Published paywall on the normal app — 2026-09-29

- Reproduced the user's reported fallback in the existing process logs: `Displaying default template because paywall is missing for offering 'default'`. The app had retained configuration from before the branded paywall was available; refreshing offerings alone in that process still returned the fallback.
- Force-stopped and relaunched the installed normal debug app on `emulator-5554`, preserving its identity and local data. No code change, rebuild, reinstall or dashboard republish was necessary. No physical phone was connected.
- The new process fetched remote configuration containing workflow `wff7b0ee1ada604f1f`. Opening **Settings → TaskFlow Pro → View subscription** displayed the branded TaskFlow paywall, revision 18, in English/dark mode. Both the screenshot and native impression event confirm this; there was no default-template message in the new process.
- **Try monthly subscription** opened the native **Test Store Purchase** dialog for `monthly`, US$9.99/P1M. Cancel returned to the branded paywall without activating Pro. Its close button then returned to TaskFlow's subscription screen with **No active Pro subscription**. This check did not complete another successful purchase; the earlier purchase/restore results remain separate.
- Reopened the branded paywall for the user. Future dashboard edits should be checked in the native app after a full relaunch, not only in the browser preview or after a Flutter hot reload.

## Catalan localization — 2026-09-29

- Added and published Catalan (`ca`) for all 14 strings in the existing paywall. English/Spanish, product, price, actions and sandbox allowlist were retained.
- Verified the published version in RevenueCat's dashboard. After installing the localized normal debug APK and restarting, selected Catalan in TaskFlow. **Mostra la subscripció** displayed the branded native paywall entirely in Catalan, including its dynamic monthly price, test notice, restore button and footer. Back returned to TaskFlow's Catalan subscription screen.
- This follow-up checked locale delivery and dismissal; it did not make another purchase. Evidence: `artifacts/revenuecat-catalan-published.png` and `artifacts/localization-paywall-ca.png`.

## Test coverage beyond the emulator flow

Deterministic tests verify exact entitlement matching; cancelled-but-still-active access; expiry; failed entitlement verification; pending payment; retryable errors; nonnumeric platform errors; empty restore; missing offerings; monthly-duration validation; duplicate taps; failed account resolution; failed SDK login; late callbacks and results across account switches; release-key/platform guards; legacy session upgrade persistence; and an account refresh arriving after logout. English/light and Spanish/dark subscription screens pass at 360 px width and 170% text size.

## Remaining before production

- Replace the published test paywall's preview copy with the actual Pro benefits, add public Terms/Privacy URLs, and review the intended real-store price. Recheck all three languages and rerun native checkout under the intended production sandbox-access policy.
- Supply public Android/iOS platform SDK keys, configure the real store apps/products, signing and credentials, and validate the account restore/transfer policy.
- Test real Google Play/App Store sandbox renewals, expiration, billing retry, refunds and store management. A Test Store run cannot validate these store-specific paths.
- Test iOS on a device. CI compiles it on macOS (unsigned, `flutter build ios --no-codesign`); the Podfile was removed on 2026-11-11 because every plugin is a Swift Package.
- Voice capture now requires Pro and Django independently verifies access. Validate real-store renewals, refunds, transfers and offline behavior before selling; authenticated webhooks can complement the current request-time verification.

## Local evidence

Logs/screenshots are ignored build artifacts under `App/artifacts/`:

- `revenuecat-analyze.log`, `revenuecat-full-tests.log`, `revenuecat-android-build.log`.
- `revenuecat-emulator.log` includes `RC_SMOKE_PASSED` and the driver success result.
- `revenuecat-center.png` and `revenuecat-paywall.png` show the native SDK screens.
- `revenuecat-subscription.png` shows TaskFlow's normal subscription screen after the test.
- `revenuecat-published-paywall.png` shows the branded published version in the dashboard; `revenuecat-sandbox-access.png` shows the saved allowlist restriction.
- `revenuecat-paywall-fixed-native.png` shows the branded paywall in the normal Android app after relaunch; `revenuecat-branded-test-checkout.png` shows its Test Store dialog. `revenuecat-paywall-relaunch.log` records the workflow, impression, purchase initiation, cancellation and close events.
- `taskflow-revenuecat-debug.apk` is the normal app build, separate from the integration-test APK.
- Backend logs: `Backend/artifacts/revenuecat-backend-full-tests.log` and `revenuecat-docker-build.log`.

The normal app APK is reinstalled with `adb install -r` after the smoke test, preserving TaskFlow accounts and local data. Native SDK test customers can remain in RevenueCat sandbox history.

RevenueCat aliases an anonymous ID when it first logs into the smoke-test customer. On this first SDK run the newly created anonymous test profile therefore also displays the temporary test Pro subscription after returning to the normal app. No paid feature restrictions are enabled. Use a dedicated Test Store installation when repeating this test so anonymous test subscriptions do not mix with another development session.

## Private Android release verification — 2026-10-12

**APK 1.0.1 (4003)** fixes the Test Store API-key warning followed by termination
on physical phones. RevenueCat deliberately rejects Test Store keys in ordinary
release builds. `StagingBillingBridge` now uses the documented native
`forceAllowTestStoreInReleaseBuilds()` setting, restricted to the compiled staging
flag, staging package and exact configured public test key. The app remains an
optimized, non-debuggable release build. Production and unsupported iOS release
configurations continue to reject Test Store keys.

With explicit owner approval, the RevenueCat project's sandbox access was saved
as **Anybody** so invited staging testers can unlock Pro through simulated
purchases. A separate invited test account was verified against the real backend:
inactive before purchase, active sandbox access afterwards, no complimentary grant.
Staging authentication/invitation rules remain enforced. Backend tests verify that
production rejects sandbox access even if its sandbox-allow flag is enabled.

### Passed checks

- 36 Flutter billing/provider/screen tests, including English, Spanish and Catalan.
- 18 backend billing and complimentary-access tests on local PostgreSQL.
- Full Flutter analysis before the release build: no issues.
- Native Android instrumentation on `emulator-5556`: **1 test passed** in 24.7
  seconds, with both embedded Flutter results passing. The test asserts Dart
  release mode and Android's non-debuggable application flag.
- Rejected an incorrect native bridge key; configured the actual staging SDK;
  signed in to the real Cloud Run backend with an isolated synthetic account;
  loaded the real monthly product and published branded paywall.
- Cancelled the native paywall; cancelled a Test Store purchase; simulated a failed
  purchase; completed a successful purchase with active `taskflow_pro`; restored
  the entitlement; received native CustomerInfo updates in Flutter.
- The live backend independently accepted the purchased sandbox entitlement.
  Paid AI returned two reviewed drafts with the expected member/group assignments.
- Restored and launched the normal `lib/main.dart` APK after testing with
  `adb install -r`, preserving existing account and app data.

The release test has narrowly scoped R8 keep rules for the instrumentation
runner's Kotlin/tracing dependencies and its access to Flutter's result channel.
They apply only to `staging_billing_release_test.dart`, never the distributable
`lib/main.dart` build. SDK calls, HTTP requests, receipts and entitlement responses
are real; only session storage is isolated in memory. No actual payment was made.
This validates an Android emulator release build, not a physical-phone or real
Google Play/App Store purchase.

### Deliverable and evidence

- Normal signed APK: `build/releases/taskflow-staging.apk`, also copied as
  `build/releases/taskflow-staging-1.0.1.apk`.
- Package: `com.example.agenda.staging`; version code: `4003`; version: `1.0.1`.
- SHA-256: `43F2453E8C4F1F25D82F59562F946DFAB6F63CA681798DE99203450564E854FA`.
- Signing certificate SHA-1 remains
  `B4:D8:3A:C1:A9:AD:F8:41:C0:70:78:57:4C:94:A9:34:3D:07:29:1D`, permitting
  installation over the previous staging APK. The distributable contains none of
  the private fixture's email/password/token values.
- `build/staging-release-native-test.log` and
  `build/staging-release-flutter-test.log`: actual native/Flutter success results.
- `artifacts/staging-release-paywall.png`: the branded paywall captured by the
  instrumentation test and visually reviewed.
- `artifacts/staging-sandbox-access-enabled.png`: saved RevenueCat access policy.
- `Backend/artifacts/staging-invited-test-purchase.json`: separate tester receipt
  and backend-entitlement result.

Reproduce with `./scripts/build-staging.ps1`, then
`./scripts/test-staging-billing.ps1 -Device emulator-5556` after preparing the
private fixture. Use an idle dedicated emulator without blocking system dialogs.
Never distribute the integration APK under `build/app/outputs/`: it contains the
synthetic fixture credentials. The build script explicitly targets `lib/main.dart`
and rejects private credential names in the distributable configuration.
