# TaskFlow

All Flutter source, platform projects, tests, dependencies, and builds live in `App/`. Run Flutter commands from this directory (`cd App` from the repository root).

The Django service, Docker Compose configuration, environment files, and backend documentation live in `Backend/`: [Local backend guide](../Backend/README.md).

**TaskFlow** captures thoughts as tasks and keeps scheduled commitments in a calendar-first agenda. Tasks work locally; signed-in accounts add synchronization and attachment recovery. See [implementation status](docs/IMPLEMENTATION_STATUS.md) for delivered features, validation evidence and remaining work.

## Features

- Voice and typed capture with retained unfinished input, editable drafts and partial-batch saving. AI processing needs a connection; provider failures keep the input available for retry.
- Unscheduled Inbox, date-only and timed tasks, personal lists, labels and checklists.
- Recurrence intervals, selected weekdays and individual occurrence move/skip controls.
- Opt-in reminders with explicit lead times, snooze, notification actions and configurable daily check-ins. Scheduling/delivery limitations are documented in [reminder validation](docs/REMINDER_VALIDATION.md).
- Local task storage with account-isolated sync, conflict preservation and private attachment upload/download. Older device-only files require an explicit Upload.
- TaskFlow export/import, Todoist CSV preview, English/Spanish core UI and regional clock/week preferences.
- Light, dark, and device-following appearance, with a one-tap sun/moon switch.
- Calendar and week agenda, visible task times, search, priority filters, and completion undo.
- Consistent task editor, voice capture, account screens, and bottom navigation.

The visual system, references, and Android preview workflow are documented in [Design notes](docs/DESIGN.md).

## Getting Started

This project is built using **Flutter**. To compile the app, follow these steps:

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
