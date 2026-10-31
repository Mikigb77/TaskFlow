// The website's hero image: Calendar right after the hero card's example,
// "Tomorrow, call the dentist and buy bread.", was said and added. Rendered
// from the real app so the site shows the app as it is (WD4, decided on
// 2026-10-18). Not UX evidence: it's written to build/web-assets/, outside the
// reviewer's build/ux/, and copied to the website as
// public/images/hero-calendar-<language>-<theme>.png.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_previews.dart' show speak;
import 'support/app.dart';
import 'support/fixtures.dart';
import 'support/preview.dart';

const hero = Screen(
  // Outside build/ux/, so the UX reports never list it.
  '../web-assets',
  'calendar-hero',
  'Calendar after the website hero card\'s example was said and added',
  sources: ['lib/screens/calendar_screen.dart', 'lib/widgets/task_tile.dart'],
);

/// What the hero card says, and the two tasks it becomes, in each language.
const _example = {
  'en': (
    'Tomorrow, call the dentist and buy bread.',
    'Call the dentist',
    'Buy bread',
  ),
  'es': (
    'Mañana, llamar al dentista y comprar pan.',
    'Llamar al dentista',
    'Comprar pan',
  ),
  'ca': (
    'Demà, trucar al dentista i comprar pa.',
    'Trucar al dentista',
    'Comprar pa',
  ),
};

/// 390 × 844 dp at the previews' 2×: 780 × 1688 PNGs, as the site expects.
final _variants = [
  for (final lang in ['en', 'es', 'ca'])
    for (final dark in [false, true])
      Variant(lang, dark, 1, width: 390, height: 844),
];

void websitePreviews() {
  previewArea('../web-assets', 'Website images', () {
    preview(
      hero,
      'done',
      'The two tasks on tomorrow, after the add message has gone.',
      _variants,
      (p) async {
        final (said, dentist, bread) = _example[p.variant.lang]!;
        final app = await PreviewApp.open(p);
        app.api.answer = {
          'transcript': said,
          'tasks': [
            serverTask(dentist, date: day(1)),
            serverTask(bread, date: day(1)),
          ],
          'commands': [],
        };
        await speak(app, said);
        await p.tester.tap(find.byKey(const ValueKey('save-drafts')));
        await p.tester.pumpAndSettle();
        // Let the add message time out, so the picture is Calendar itself.
        await p.tester.pump(const Duration(seconds: 8));
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );
  });
}
