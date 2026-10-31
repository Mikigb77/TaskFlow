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

  // ---- Round 2 (b10) · P117 (UX-631): Undo after Completar waits as long
  // as the phone's accessibility timeout asks ----

  test(
    'UX-631: forAction(original: 10 s) asks with 10000 ms and never returns less than 10 s',
    () async {
      Object? answer = 30000;
      final sent = <Object?>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'recommendedActionTimeout');
        sent.add(call.arguments);
        return answer;
      });
      const ten = Duration(seconds: 10);
      expect(
        await FeedbackTimeout.forAction(original: ten),
        const Duration(seconds: 30),
      );
      answer = 10000;
      expect(await FeedbackTimeout.forAction(original: ten), ten);
      answer = 4000;
      expect(await FeedbackTimeout.forAction(original: ten), ten);
      expect(sent, [
        for (var i = 0; i < 3; i++) {'originalTimeoutMillis': 10000},
      ]);
    },
  );

  test(
    'UX-631: forAction(original: 10 s) falls back to 10 s when no handler is set',
    () async {
      expect(
        await FeedbackTimeout.forAction(original: const Duration(seconds: 10)),
        const Duration(seconds: 10),
      );
    },
  );

  test(
    'UX-631: forAction() with no argument still asks with 4000 ms and falls back to 4 s',
    () async {
      Object? sent;
      messenger.setMockMethodCallHandler(channel, (call) async {
        sent = call.arguments;
        return null;
      });
      expect(await FeedbackTimeout.forAction(), const Duration(seconds: 4));
      expect(sent, {'originalTimeoutMillis': 4000});
      messenger.setMockMethodCallHandler(channel, null);
      expect(await FeedbackTimeout.forAction(), const Duration(seconds: 4));
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
