/// Search that ignores case and accents, so `medico` finds `Médico` and
/// `collegi` finds `col·legi`. People typing often leave accents out; the
/// recognizer always writes them.
bool matchesSearch(String text, String query) {
  if (query.isEmpty) return true;
  var folded = foldForSearch(query);
  // A half-typed `col.legi` reads `col.` for one keystroke; search it as `col`.
  if (folded.endsWith('l.')) folded = folded.substring(0, folded.length - 1);
  return foldForSearch(text).contains(folded);
}

/// Lowercases [text] and folds Spanish and Catalan accents to plain letters.
String foldForSearch(String text) {
  final lower = text.toLowerCase().replaceAll(_fullStopL, 'll');
  final folded = StringBuffer();
  for (var i = 0; i < lower.length; i++) {
    final unit = lower.codeUnitAt(i);
    final plain = unit < 0x80 ? null : _plainByCodeUnit[unit];
    if (plain == null) {
      folded.writeCharCode(unit);
    } else {
      folded.write(plain);
    }
  }
  return folded.toString();
}

// Catalan l·l written with a full stop. The middle dot and ŀ fold one
// character at a time in [_plain], so a half-typed `col·` still matches.
final _fullStopL = RegExp(r'l\.l');

const _plain = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ñ': 'n',
  'ç': 'c',
  '·': '',
  'ŀ': 'l',
  // iPhone keyboards type the curly apostrophe, Android ones the straight.
  '’': "'",
};

final _plainByCodeUnit = {
  for (final MapEntry(:key, :value) in _plain.entries)
    key.codeUnitAt(0): value,
};
