import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final file = File('artifacts/design/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
        return true;
      },
      responseDataCallback: (_) async {});
}
