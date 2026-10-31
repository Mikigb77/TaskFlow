import 'package:flutter/foundation.dart';

/// Explicitly opt in through config/development.json. These fixture credentials
/// and the shortcut are unavailable in profile/release builds, even if a
/// development config is accidentally passed to the build command.
abstract final class DevelopmentLogin {
  static const email = kDebugMode
      ? String.fromEnvironment('DEV_LOGIN_EMAIL')
      : '';
  static const password = kDebugMode
      ? String.fromEnvironment('DEV_LOGIN_PASSWORD')
      : '';
  static const enabled =
      kDebugMode &&
      bool.fromEnvironment('DEV_LOGIN_ENABLED') &&
      email != '' &&
      password != '';
}
