# TaskFlow

All Flutter source, platform projects, tests, dependencies, and builds live in `App/`. Run Flutter commands from this directory (`cd App` from the repository root).

The Django service, Docker Compose configuration, environment files, and backend documentation live in `Backend/`: [Local backend guide](../Backend/README.md).

**TaskFlow** captures thoughts as tasks and keeps scheduled commitments in a calendar-first agenda. Sign in with Google or email before opening your tasks. The app restores the saved account on launch and keeps its tasks available offline, with synchronization and attachment recovery when connected. See [implementation status](docs/IMPLEMENTATION_STATUS.md) for delivered features, validation evidence and remaining work.

## Features

- Google sign-in on Android, with verified identity tokens exchanged for TaskFlow sessions and explicit linking to existing accounts. iOS configuration is pending. See the [Google sign-in setup and validation guide](../Backend/docs/GOOGLE_SIGN_IN.md).

- RevenueCat subscriptions with `taskflow_pro`, a monthly offering, native paywalls, restore and Customer Center. Voice and AI capture are gated in Flutter and verified independently by Django. Debug builds use Test Store. See the [step-by-step integration and dashboard guide](docs/REVENUECAT_SETUP.md).
- Personal and group projects, role-based membership, member/group task assignment, For me/Team views, reviewed capture destinations and collaboration activity. See [current implementation and test evidence](docs/PROJECTS_IMPLEMENTATION.md).

- Voice and typed capture with retained unfinished input, editable drafts and partial-batch saving. AI processing needs a connection; provider failures keep the input available for retry.
- Unscheduled Inbox, date-only and timed tasks, personal lists, labels and checklists.
- Standalone notes for information and ideas, with an explicit Task/Note choice, selectable text, web links and optional checklists. Signed-in users can write notes offline; recorded notes use transcription without inferring tasks. See [notes validation](docs/NOTES_VALIDATION.md).
- Shared household lists with explicit invitation codes, editor/viewer roles, conflict recovery and membership controls. Files follow list access; cached group content is removed on the next successful access refresh after leaving/removal. See [sharing validation](docs/SHARING_VALIDATION.md).
- Recurrence intervals, selected weekdays and individual occurrence move/skip controls.
- Opt-in reminders with explicit lead times, snooze, notification actions and configurable daily check-ins. Scheduling/delivery limitations are documented in [reminder validation](docs/REMINDER_VALIDATION.md).
- Local task storage with account-isolated sync, conflict preservation and private attachment upload/download. Older device-only files require an explicit Upload.
- English, Spanish and Catalan throughout the app, phone-language detection with English fallback, and a persistent language selector in Settings. Regional clock/week preferences stay independent. See the [translation workflow](docs/LOCALIZATION.md).
- TaskFlow export/import and Todoist CSV preview.
- Light, dark, and device-following appearance, with a one-tap sun/moon switch.
- Calendar and week agenda, visible task times, search, priority filters, and completion undo.
- Independent planned start, deadline and duration, explicit reminder anchor and an hourly day view with overlapping task blocks. See [planning validation](docs/PLANNING_VALIDATION.md).
- Optional read-only display of selected Android phone calendars, with explicit permission and separate event rows. Events stay on the device and do not become tasks or TaskFlow reminders. See [calendar validation](docs/DEVICE_CALENDAR_VALIDATION.md).
- Consistent task editor, voice capture, account screens, and bottom navigation.

The visual system, references, and Android preview workflow are documented in [Design notes](docs/DESIGN.md).

## Getting Started

For a phone build using the deployed Cloud Run/Neon backend, run
`./scripts/build-staging.ps1` from `App`. The private APK appears at
`build/releases/taskflow-staging.apk` as **TaskFlow Staging** and installs beside
the local development app. See the [staging guide](../Backend/docs/STAGING.md) for
invited accounts, Google testers, sandbox purchases and build credentials.

In VS Code, select **TaskFlow (development)** in Run and Debug and press F5. The launch configuration automatically uses the dedicated `TaskFlow_API_36_1` emulator (12 GB internal storage), regardless of the device selected in the status bar. Its pre-launch task starts/reuses that AVD and checks for at least 1 GB free space before Flutter installs anything. This avoids the smaller general-purpose emulator's `INSTALL_FAILED_INSUFFICIENT_STORAGE` error and Flutter's automatic uninstall/reinstall fallback. The task may reclaim disposable Android caches; it never wipes an emulator or clears application data. It requires `pwsh`, Android SDK `adb` on PATH, and the existing named AVD.

The launch configuration loads `config/development.json`, including the public Google sign-in client ID. It works when opening `App` or the repository root, including the Run/Debug links in `lib/main.dart`; the parent workspace has a matching local configuration. Stop and start the session after changing build configuration; hot reload does not add missing Dart defines. See the [Google login guide](../Backend/docs/GOOGLE_SIGN_IN.md) for local backend startup and command-line use.

For fast local testing, the development login screen has **Use test account** below the normal sign-in options. It signs in to the Docker backend as `app-test@taskflow.local` through the normal password/JWT endpoint. The account starts empty; tasks you add are kept between sessions. `config/development.json` explicitly enables the shortcut and supplies fixture credentials matching `Backend/.env`. Start the backend with `docker compose up -d api` from `Backend/`. The shortcut and its credentials are disabled in profile/release builds even if this development file is passed, and debug builds without the opt-in do not show it. These credentials belong only to the local testing database.

This project requires **Flutter 3.44 or newer** and **Dart 3.12 or newer**. The SQLite dependency includes the Android WAL mutation-result fix. Run `flutter pub get` before building; on Windows, Developer Mode enables Flutter's generated plugin links.

The Android build uses **Gradle 9.7.1**, **Android Gradle Plugin 9.4.1**, **Kotlin 2.4.20**, and **JDK 26**. Install a JDK 26 distribution and set `JAVA_HOME` to its installation directory. The checked-in `android/gradle/gradle-daemon-jvm.properties` selects Java 26 for the build, including when Flutter starts Gradle through Android Studio's bundled Java. Gradle's distribution is pinned with its SHA-256 checksum.

For VS Code, set `java.import.gradle.java.home` and `java.jdt.ls.java.home` in your active workspace settings to that same JDK directory, then reload the window. When opening the parent folder containing both repositories, use that folder's settings; VS Code does not inherit settings from `App/.vscode/`. CMake auto-configuration is disabled in the app settings because Flutter prepares the generated Windows files before native builds.

Java 26 is the newest runtime supported by Gradle 9.7.1. Android Java/Kotlin bytecode still targets Java 17 for device compatibility. Flutter's `android.builtInKotlin=false` and `android.newDsl=false` compatibility settings remain required by the current Flutter SDK and plugins.

Verified on 2026-09-21 with Temurin 26.0.2.1: Gradle configuration and build-task discovery succeed, and `flutter build apk --debug --target-platform=android-x64 --no-pub` builds the APK. Existing Flutter/plugin deprecation warnings remain; the unsupported Java class-version error is resolved.

1. Run the following command in your terminal to build the APK in release mode:
   ```
   flutter build apk --release
   ```
2. After building, the APK will be located in:
   ```
   build/app/outputs/flutter-apk/
   ```
   Historical APK archives are available in the `releses` folder; these are older versions. For local backend testing on a current phone, build with `flutter build apk --debug --target-platform=android-arm64`. See the backend guide for the server connection settings.

### Useful Resources

If you're new to Flutter or want to learn more, here are some helpful resources:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For comprehensive Flutter documentation, including tutorials and the full API reference, visit the [official Flutter documentation](https://docs.flutter.dev/).

## Contributing

You are welcome to use and modify the source code to create your custom app. If you find this code helpful and decide to share or distribute your version, I kindly ask that you provide credit for the original source.

## Final Notes

Thank you for using **TaskFlow**! If you encounter any issues or have suggestions for improvement, feel free to contribute or open an issue in the repository.
