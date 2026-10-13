import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Display time for brief feedback containing text and an action such as Undo.
class FeedbackTimeout {
  static const defaultDuration = Duration(seconds: 4);
  static const _channel = MethodChannel('taskflow/accessibility');

  static Future<Duration> forAction() async {
    // iOS has no public equivalent of Android's recommended UI timeout.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return defaultDuration;
    }
    try {
      // Read each time so changes in the phone's accessibility settings apply
      // to the next notice. An unavailable platform must not hold up feedback.
      final milliseconds = await _channel
          .invokeMethod<Object?>('recommendedActionTimeout', {
            'originalTimeoutMillis': defaultDuration.inMilliseconds,
          })
          .timeout(const Duration(milliseconds: 500));
      if (milliseconds is int &&
          milliseconds >= defaultDuration.inMilliseconds) {
        return Duration(milliseconds: milliseconds);
      }
    } on MissingPluginException {
      return defaultDuration;
    } on PlatformException {
      return defaultDuration;
    } on TimeoutException {
      return defaultDuration;
    }
    return defaultDuration;
  }
}
