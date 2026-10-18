// Images the website uses, rendered from the real app:
//   flutter test --no-pub --dart-define=WRITE_WEB_ASSETS=true test/ux_previews/website_assets_test.dart
// They land in build/web-assets/; copy them to the website's public/images/.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'website_previews.dart';

const writeWebAssets = bool.fromEnvironment('WRITE_WEB_ASSETS');

void main() {
  if (!writeWebAssets) {
    test(
      'Website images (run with --dart-define=WRITE_WEB_ASSETS=true)',
      () {},
      skip: 'Renders only on request: --dart-define=WRITE_WEB_ASSETS=true',
    );
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  websitePreviews();
}
