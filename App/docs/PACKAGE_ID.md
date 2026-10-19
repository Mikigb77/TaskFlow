# Changing the package name before the first Play upload

The app's Android package is still Flutter's placeholder, `com.example.agenda`, with `com.example.agenda.staging` for staging builds.

**Decision (main session, 2026-10-18, while the owner was away; reversible until the first upload):** the new ID is `tech.garbar.taskflow`, from the company's domain garbar.tech, and `tech.garbar.taskflow.staging` for staging.

## Why now, and why it isn't switched yet
- A package name is permanent once uploaded. Play never deletes or reuses one, and a different ID uploads as a different app. Source: `.claude/ux-review/GUIDELINES.md` and `.claude/ux-web/GUIDELINES.md` (AP-6), checked 2026-10-18.
- Since 2026, a package name must also be registered for Android's developer verification. Play removes unregistered apps from 30 September 2026.
- The code can't switch on its own. Google sign-in, RevenueCat and Play each identify the app by its package name and signing certificate, so the switch breaks sign-in and purchases until the owner registers the new name in their consoles.

## Steps outside the code (the owner, in the consoles)
1. **Google Cloud** (the OAuth project in `Backend/docs/GOOGLE_SIGN_IN.md`): add an Android OAuth client for `tech.garbar.taskflow` with the debug SHA-1, and later the Play app-signing SHA-1. Do the same for `tech.garbar.taskflow.staging`.
   - The web client, which is the server's audience (`GOOGLE_OAUTH_CLIENT_IDS`), stays as it is.
2. **Android developer verification:** register `tech.garbar.taskflow` for the developer account.
3. **Play Console:** create the app with `tech.garbar.taskflow`. This is the step that makes the name permanent.
4. **RevenueCat:** point the Play app at `tech.garbar.taskflow`, and re-link the service credentials. See `App/docs/REVENUECAT_SETUP.md`.

## Changes in the code (one commit, after steps 1 and 4)
- `App/android/app/build.gradle`: `namespace` and `applicationId`.
- Move the Kotlin sources from `android/app/src/main/kotlin/com/example/agenda/` to `tech/garbar/taskflow/`, and change their `package` lines. That covers `MainActivity`, the speech, calendar, accessibility and capture bridges, and `CaptureWidget`. Do the same for `androidTest/…/StagingBillingReleaseTest.kt`.
- `android/app/src/main/AndroidManifest.xml`: class names and any intent actions with the old prefix.
- The launcher shortcuts need nothing: since 2026-10-19 they're published from code (`CaptureShortcuts.kt`) with an intent built from the app's own context. Only their action names, `com.example.agenda.CAPTURE_*` in `CaptureEntryBridge.kt`, may change for tidiness. Pinned shortcuts from the old app don't carry over.
- Tests and scripts that name it:
  - `App/test/native_resources_test.dart`;
  - `App/integration_test/projects_flow_test.dart`;
  - `App/scripts/build-staging.ps1` and `test-staging-billing.ps1`, which another session is editing;
  - `App/test_driver/README.md`.
- iOS and macOS bundle IDs (`ios/Runner.xcodeproj/project.pbxproj`, `macos/…`): change them to match if an iPhone version is ever built. Android doesn't need them.
- Docs that name the old ID: `Backend/docs/GOOGLE_SIGN_IN.md`, `Backend/docs/STAGING.md` (another session is editing it), the validation records in `App/docs/`, and the reviewer's paths in `.claude/agents/frontend-ux-reviewer.md`.
- Then:
  - run `flutter analyze --no-pub` and the whole suite;
  - build the debug APK;
  - sign in with Google on a test emulator;
  - check that the launcher shortcuts and the widget open the app.

## What testers notice
An install of `com.example.agenda` doesn't update to `tech.garbar.taskflow`: it's a new app. Before uninstalling the old one, testers should let it sync, because tasks live on the server, then sign in to the new app. Captures that haven't been sent yet stay on the old install.
