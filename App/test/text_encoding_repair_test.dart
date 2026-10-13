import 'package:agenda/services/text_encoding_repair.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('old Latin-1 text receives a reversible correction suggestion', () {
    expect(
      suggestTextEncodingRepair('aplicaciÃ³n · estÃ¡ lista'),
      'aplicación · está lista',
    );
    expect(suggestTextEncodingRepair('demÃ '), 'demà');
  });
  test(
    'valid Unicode, intentional characters and undecodable text are untouched',
    () {
      for (final value in [
        'Aplicación · demà 🗓️',
        'Ã',
        'Café',
        'Ãnot an encoding',
      ]) {
        expect(suggestTextEncodingRepair(value), isNull);
      }
      expect(suggestTextEncodingRepair('aplicaciÃ³n · 漢字'), 'aplicación · 漢字');
    },
  );
}
