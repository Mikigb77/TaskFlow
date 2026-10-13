import 'dart:convert';

/// Suggests a reversible correction for text saved by the old Latin-1 JSON
/// decoder. Never apply automatically: these characters can be intentional.
String? suggestTextEncodingRepair(String text) {
  final suspicious = RegExp(r'[\u00c2\u00c3\u00e2\u00f0][\u0080-\u00bf]');
  if (!suspicious.hasMatch(text)) return null;
  var result = text;
  final runs = RegExp(
    r'(?:[\u00c2-\u00df][\u0080-\u00bf]|[\u00e0-\u00ef][\u0080-\u00bf]{2}|[\u00f0-\u00f4][\u0080-\u00bf]{3})+',
  );
  for (var pass = 0; pass < 2; pass++) {
    try {
      final next = result.replaceAllMapped(runs, (match) {
        try {
          return utf8.decode(latin1.encode(match[0]!));
        } on FormatException {
          return match[0]!;
        }
      });
      if (next == result ||
          suspicious.allMatches(next).length >=
              suspicious.allMatches(result).length) {
        break;
      }
      result = next;
    } on FormatException {
      break;
    } on ArgumentError {
      break;
    }
  }
  return result == text ? null : result;
}
