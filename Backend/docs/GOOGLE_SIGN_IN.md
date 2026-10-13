# Google sign in implementation and setup

TaskFlow exchanges a Google ID token for its existing Django JWT session. Flutter uses `google_sign_in` 7.2 with `GoogleSignIn.instance.initialize` and `authenticate`; it requests identity only, without Drive, Calendar or other Google API access. No Google client secret belongs in Flutter, and this ID-token exchange does not need one on the backend.

## Configured development clients

Project: `taskflow-511107`. Google Auth branding is TaskFlow, external audience in testing mode, with `tech.garbar@gmail.com` as support/contact email.

The approved test account `tech.garbar@gmail.com` is saved under Google Auth Platform → Audience. The app has not been published for general OAuth access.

- Web audience client: `TaskFlow API development`, ID `177649734578-cr3scnkukf14a1bbl7bpcj49t9aorft0.apps.googleusercontent.com`.
- Android client: `TaskFlow Android development`, ID `177649734578-23v641569b5v8raijjbj05rpccnm6o7p.apps.googleusercontent.com`.
- Android package: `com.example.agenda` (the existing development application ID).
- Debug certificate SHA-1: `2F:0F:8B:06:6C:7F:E0:ED:1E:F4:AA:4F:02:27:45:78:62:0B:82:BD`.

Client IDs and certificate fingerprints are public configuration, not secrets. The Web client is the ID-token audience even though the app is Android. A native ID-token flow does not require a browser redirect URL. The marketing website URL alone is not a Django API or OAuth callback.

## Run locally

For the deployed private staging build, an additional Android client **TaskFlow
Android staging** is registered: `177649734578-ig4044i79c4u7j55sllgetmi4oinp91a.apps.googleusercontent.com`,
package `com.example.agenda.staging`, SHA-1
`B4:D8:3A:C1:A9:AD:F8:41:C0:70:78:57:4C:94:A9:34:3D:07:29:1D`.
It uses the same Web audience above. Its private signing key is ignored under
`App/.credentials`; never regenerate it to fix a build. The actual account
chooser/login still needs a physical-device check. See [staging](STAGING.md).

In VS Code, choose **TaskFlow (development)** in Run and Debug, select the Android emulator, and press F5. Launch configurations in the repository root and `App` load `App/config/development.json`; the local parent workspace has the equivalent configuration. The normal Run/Debug links in `lib` use that configuration too. After changing compile-time configuration, stop the running debug session completely and start it again; hot reload or hot restart does not supply new `--dart-define` values.

From `Backend`, set `GOOGLE_OAUTH_CLIENT_IDS` to the Web audience client ID (comma-separated if deliberately accepting several), then run:

```powershell
docker compose up -d --build
```

The new migration creates a unique Google subject linked to one TaskFlow user. Local Compose applies migrations on startup; production must move migrations to a controlled deployment job as described in `ARCHITECTURE.md`.

From `App`:

```powershell
flutter run -d emulator-5554 --dart-define-from-file=config/development.json
```

The development file includes the public audience ID and Android emulator API address. A saved Account → Connection settings address overrides the compiled API address; sign out before changing it. For a physical phone, use the development machine's reachable LAN address with matching backend allowed hosts. Production builds require HTTPS.

If the Google button is disabled with “Google sign-in is not available in this build yet,” the running app was compiled without the client ID. Rebuild using the development launch configuration above. Redeploying Django does not change this build-time value.

Open Account and choose Continue with Google. If Google reports that the user is not a tester, add the intended test account in Google Auth Platform → Audience. Device sign-in requires a Google account and Google Play services. OAuth configuration may take time to propagate.

### Local emulator setup

On the development machine, the emulator's automatic ADB detection was replaced with the explicit SDK `platform-tools/adb.exe` path. The user environment also has `ANDROID_HOME` and the SDK tools on `PATH`; restart existing terminals to pick those up.

The original `Medium_Phone_API_36.1` device had insufficient internal storage for an app update. Its apps and data are preserved. A separate `TaskFlow_API_36_1` device now has 12 GiB of internal storage; the configured debug APK is installed and running there. It starts with fresh app data and needs a Google account for the live sign-in check. Select this device in Android Studio or start it with:

```powershell
& "$env:LOCALAPPDATA/Android/Sdk/emulator/emulator.exe" -avd TaskFlow_API_36_1
```

Use `flutter devices` to identify its current device ID before running the app if more than one emulator is open.

## API and security behavior

- `POST /api/auth/google/`: `{ "id_token": "...", "timezone": "Europe/Madrid" }`. Returns the normal TaskFlow `access`, `refresh` and `user` payload. An empty backend audience list disables Google login.
- Google's official Python verifier checks signature, audience, issuer and expiry. The API additionally requires a verified email and a valid subject. Certificate fetches have a five-second timeout. Tokens and passwords must not be logged.
- Google `sub`, not email, identifies returning Google users. A new account has an unusable password. Password recovery can establish a password after proving mailbox access; production recovery email must work before launch.
- A verified Google email matching an existing TaskFlow user returns `409 google_link_required`. It never silently merges accounts.
- To link, sign in with the existing TaskFlow password, choose Link Google account, confirm the current password, and select the Google account with the same email. `POST /api/auth/google/link/` requires an authenticated TaskFlow session, Google ID token and current password. Unique constraints prevent identity reassignment. Tasks, user ID and RevenueCat billing ID remain unchanged.
- `/api/auth/me/` and session responses include read-only `google_linked`. Existing clients tolerate the additional field; Flutter handles old cached accounts without it.
- Normal session revocation, refresh-token rotation and throttling apply. Flutter stores only TaskFlow tokens in secure storage. Canceling Google's chooser does not show an error or submit a backend login.

## Production and other platforms

Before public release, choose the final Android application ID and register its actual release/Google Play signing certificate. Do not ship a debug-signed release or rely on this development client's configuration. Use environment-specific OAuth audiences and API URLs. Configure public branding/privacy information and review the Google Auth publishing status; keep requested scopes restricted to basic identity.

The Flutter service supports Android and iOS native authentication. iOS is not configured or device-tested yet: create an iOS OAuth client for the actual bundle ID, pass `GOOGLE_IOS_CLIENT_ID`, and add its reversed client ID to the iOS URL schemes as required by the plugin. Until that ID is present, the iOS button remains disabled. macOS/Windows/Linux and Flutter web do not expose this native login action; the planned Next.js web app needs its own browser sign-in integration and authorized origins. Do not call native `authenticate()` on web.

## Validation

Verified on 9 October 2026: all 93 backend tests pass against Docker PostgreSQL, all 24 focused Flutter authentication/localization tests pass, `flutter analyze --no-pub` reports no issues, and the Android x64 debug APK builds with the real development client ID. Its signing certificate matches the registered Android SHA-1. Installation and foreground launch succeed on `TaskFlow_API_36_1`, with no Flutter or Android runtime errors in the startup log. The local Docker API is healthy and loads the matching Web client audience.

A subsequent VS Code launch omitted the Dart defines and disabled Google login. The new development launch profiles fix both F5 and the Run/Debug links in `lib`. After rebuilding with the profile's arguments and restarting, querying the active Google service's `configured` getter through the local Dart VM returned `true`. This verifies the running build configuration; it does not replace the live Google account test below.

The backend tests use real RSA-signed fixture tokens and Google's actual verifier; only Google's certificate transport is replaced. They cover valid and returning users, forged signatures, wrong audience/issuer, expiry, unverified email, configuration failures, Google network failures, disabled users, explicit linking, identity-transfer rejection and session revocation. These are automated security tests, not a claim of a completed live Google sign-in.

Flutter tests cover token exchange and secure session persistence, linking, localized errors, and chooser cancellation at enlarged text sizes. Finish the live Android test by selecting a real Google account, confirming the TaskFlow session, restarting the app, and checking task sync and logout. Do not paste or export the Google ID token to perform this test.

References: [Flutter plugin](https://pub.dev/packages/google_sign_in), [Android setup](https://pub.dev/packages/google_sign_in_android), [iOS setup](https://pub.dev/packages/google_sign_in_ios), [Google backend verification](https://developers.google.com/identity/sign-in/web/backend-auth), [Google button branding](https://developers.google.com/identity/branding-guidelines).
