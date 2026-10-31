import 'package:agenda/services/text_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UX-303: search ignores case and accents', () {
    for (final (query, text) in [
      ('medico', 'Médico'),
      ('collegi', 'col·legi'),
      ('cafe', 'Café'),
      ('jose', 'José'),
      ('reunion', 'reunión'),
    ]) {
      test('UX-303: `$query` finds `$text`', () {
        expect(matchesSearch(text, query), isTrue);
      });
    }

    test('UX-303: matches inside a longer dictated sentence', () {
      expect(matchesSearch('Llamar al Médico el lunes', 'medico'), isTrue);
      expect(matchesSearch('Recollir els nens al Col·legi', 'collegi'), isTrue);
      expect(matchesSearch('Reunión con José', 'reunion con jose'), isTrue);
    });

    test('UX-303: an accented query still finds accented and plain text', () {
      expect(matchesSearch('Médico', 'médico'), isTrue);
      expect(matchesSearch('Medico', 'Médico'), isTrue);
      expect(matchesSearch('col·legi', 'col·legi'), isTrue);
    });

    test('UX-303: the plan’s folded letters all reduce to plain vowels', () {
      expect(matchesSearch('àâä éèêë íìîï óòôö úùûü ñ ç',
          'aaa eeee iiii oooo uuuu n c'), isTrue);
      expect(matchesSearch('ÁÉÍÓÚ ÑÇ', 'aeiou nc'), isTrue);
    });

    test('UX-303: Catalan l.l written with a full stop also folds to ll', () {
      expect(matchesSearch('col.legi', 'collegi'), isTrue);
      expect(matchesSearch('Col·legi', 'col.legi'), isTrue);
    });

    test('UX-303: an empty query matches everything', () {
      expect(matchesSearch('Médico', ''), isTrue);
      expect(matchesSearch('', ''), isTrue);
    });

    test('UX-303: folding does not create false matches', () {
      expect(matchesSearch('Médico', 'dentista'), isFalse);
      expect(matchesSearch('Café', 'cafes'), isFalse);
      expect(matchesSearch('año', 'ano nuevo'), isFalse);
    });
  });

  group('UX-425: a half-typed Catalan l·l keeps matching', () {
    const texts = ['Reunió al col·legi', 'col.legi', 'Coŀlegi'];

    test('UX-425: `col·`, `col.` and `coŀ` find the note being typed', () {
      expect(matchesSearch('Reunió al col·legi', 'col·'), isTrue);
      expect(matchesSearch('col.legi', 'col.'), isTrue);
      expect(matchesSearch('Coŀlegi', 'coŀ'), isTrue);
    });

    for (final word in ['col·legi', 'col.legi', 'coŀlegi']) {
      test('UX-425: every prefix of `$word`, typed one key at a time, finds all three spellings', () {
        final keys = word.runes.map(String.fromCharCode).toList();
        for (var typed = 1; typed <= keys.length; typed++) {
          final query = keys.take(typed).join();
          for (final text in texts) {
            expect(matchesSearch(text, query), isTrue,
                reason: '`$query` should find `$text`');
          }
        }
      });
    }

    test('UX-425: the capital Ŀ folds like ŀ', () {
      expect(matchesSearch('COĿLEGI', 'collegi'), isTrue);
      expect(matchesSearch('col·legi', 'COĿ'), isTrue);
    });

    test('UX-425: a full stop that ends a sentence is not swallowed', () {
      // Only `l.l` folds; a full stop elsewhere still has to match.
      expect(matchesSearch('Ho farem demà. Llavors sí', 'demà.'), isTrue);
      expect(matchesSearch('Ho farem demà Llavors sí', 'demà.'), isFalse);
    });
  });

  group('UX-426: an empty search does no folding', () {
    test('UX-426: an empty query matches every note, long or short', () {
      for (final text in ['', 'Médico', 'Reunió al col·legi. ' * 400]) {
        expect(matchesSearch(text, ''), isTrue);
      }
    });

    test('UX-426: folding a long dictated note keeps every character', () {
      final note = 'Reunió al col·legi amb la Núria. ' * 250;
      final folded = foldForSearch(note);
      expect(folded, 'reunio al collegi amb la nuria. ' * 250);
      expect(matchesSearch(note, 'NURIA. REUNIO'), isTrue);
    });

    test('UX-426: characters outside the accent map pass through unchanged', () {
      expect(foldForSearch('Tarea 😀 日本 ß'), 'tarea 😀 日本 ß');
    });
  });

  group('UX-434: the straight and curly apostrophes match each other', () {
    test("UX-434: `l’escola` finds `Portar l'Anna a l'escola`", () {
      expect(matchesSearch("Portar l'Anna a l'escola", 'l’escola'), isTrue);
    });
    test("UX-434: `l'escola` finds `Portar l’Anna a l’escola`", () {
      expect(matchesSearch('Portar l’Anna a l’escola', "l'escola"), isTrue);
    });
    test('UX-434: each apostrophe still finds its own kind', () {
      expect(matchesSearch("Portar l'Anna a l'escola", "l'escola"), isTrue);
      expect(matchesSearch('Portar l’Anna a l’escola', 'l’escola'), isTrue);
    });
    test('UX-434: an apostrophe is not a wildcard', () {
      expect(matchesSearch('Portar l’Anna a l’escola', "d'escola"), isFalse);
      expect(matchesSearch('lescola', "l'escola"), isFalse);
    });
  });
}
