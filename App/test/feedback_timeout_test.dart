import 'dart:async';
import 'package:agenda/services/feedback_timeout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('taskflow/accessibility');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'reads Android recommendation for each notice without shortening it',
    () async {
      var recommended = 10000;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'recommendedActionTimeout');
        expect(call.arguments, {'originalTimeoutMillis': 4000});
        return recommended;
      });
      expect(await FeedbackTimeout.forAction(), const Duration(seconds: 10));
      recommended = 60000;
      expect(await FeedbackTimeout.forAction(), const Duration(minutes: 1));
      recommended = 4000;
      expect(await FeedbackTimeout.forAction(), const Duration(seconds: 4));
    },
  );

  for (final value in [null, '10000', -1, 0, 3999]) {
    test(
      'unavailable or invalid timeout $value falls back to four seconds',
      () async {
        messenger.setMockMethodCallHandler(channel, (_) async => value);
        expect(await FeedbackTimeout.forAction(), const Duration(seconds: 4));
      },
    );
  }

  test('missing native plugin falls back to four seconds', () async {
    expect(await FeedbackTimeout.forAction(), const Duration(seconds: 4));
  });

  test(
    'native failure falls back without surfacing an error to the task',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'timeout_unavailable');
      });
      expect(await FeedbackTimeout.forAction(), const Duration(seconds: 4));
    },
  );

  test(
    'unresponsive native lookup falls back; a late reply is harmless',
    () async {
      final reply = Completer<Object?>();
      messenger.setMockMethodCallHandler(channel, (_) => reply.future);
      expect(await FeedbackTimeout.forAction(), const Duration(seconds: 4));
      reply.complete(10000);
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('iOS uses four seconds without calling an Android-only API', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
      return 10000;
    });
    expect(await FeedbackTimeout.forAction(), const Duration(seconds: 4));
    expect(calls, 0);
  });
}
