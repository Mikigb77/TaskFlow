// UX-1720 (P236): the Voz privacy paragraph says in plain words why your
// words go to Google. Catalog-level checks, read through the generated
// AppLocalizations so the copy is what the app actually shows.
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _second = <String, String>{
  'en':
      'To add, find or change tasks, your words go over the internet to '
      'Google’s AI.',
  'es':
      'Para añadir, buscar o cambiar tareas, tus palabras van por internet a '
      'la IA de Google.',
  'ca':
      'Per afegir, cercar o canviar tasques, les teves paraules van per '
      'internet a la IA de Google.',
};

// The first, third and fourth sentences stay word for word.
const _kept = <String, List<String>>{
  'en': [
    'Live transcription uses on-device speech where available; no audio is '
        'retained in that mode.',
    'Saved audio is transcribed online.',
    'Anything not saved yet stays on this phone until you save or discard it.',
  ],
  'es': [
    'La transcripción en directo usa el reconocimiento local cuando está '
        'disponible; ese modo no conserva audio.',
    'El audio guardado se transcribe en línea.',
    'Lo que aún no has guardado se queda en este teléfono hasta que lo '
        'guardes o lo descartes.',
  ],
  'ca': [
    'La transcripció en directe utilitza el reconeixement local quan està '
        'disponible; en aquest mode no es conserva l’àudio.',
    'L’àudio desat es transcriu en línia.',
    'El que encara no has desat es queda en aquest telèfon fins que ho desis '
        'o ho descartis.',
  ],
};

void main() {
  for (final locale in const ['en', 'es', 'ca']) {
    test(
      'UX-1720: the $locale privacy paragraph says why the words go to '
      'Google, without “extraction”, and keeps its other sentences',
      () {
        final l10n = lookupAppLocalizations(Locale(locale));
        final paragraph = l10n.capturePrivacy;
        final kept = _kept[locale]!;
        expect(
          paragraph,
          '${kept[0]} ${_second[locale]} ${kept[1]} ${kept[2]}',
          reason: 'the second sentence is exactly the new one, the others '
              'unchanged',
        );
        final lower = paragraph.toLowerCase();
        for (final jargon in const ['extracción', 'extracció', 'extraction']) {
          expect(lower.contains(jargon), isFalse, reason: jargon);
        }
      },
    );
  }

  test('UX-1720: app_en.arb describes capturePrivacy', () {
    final catalog = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final meta = catalog['@capturePrivacy'];
    expect(meta, isA<Map<String, dynamic>>());
    final description = (meta as Map<String, dynamic>)['description'];
    expect(description, isA<String>());
    expect((description as String).trim(), isNotEmpty);
  });
}
