import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every test file loads Bricolage Grotesque, the titles' face, so titles
/// measure as on the phone. A test that also loads Manrope gets the whole
/// app's type; one that doesn't keeps the test font for the body, as before.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await (FontLoader('Bricolage')
        ..addFont(rootBundle.load('assets/fonts/BricolageGrotesque.ttf')))
      .load();
  await testMain();
}
