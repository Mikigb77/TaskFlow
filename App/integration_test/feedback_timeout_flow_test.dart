// Set the emulator's Time to take action before running this test, and restore
// it afterwards. This uses the real Android bridge, with no mocked channels.
import 'package:agenda/services/feedback_timeout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native Android action timeout matches the device preference', (
    tester,
  ) async {
    expect(defaultTargetPlatform, TargetPlatform.android);
    const expected = Duration(
      milliseconds: int.fromEnvironment(
        'EXPECTED_ACTION_TIMEOUT_MS',
        defaultValue: 4000,
      ),
    );
    expect(await FeedbackTimeout.forAction(), expected);
  });
}
