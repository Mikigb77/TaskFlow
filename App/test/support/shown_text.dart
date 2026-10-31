import 'package:agenda/l10n/region.dart';
import 'package:flutter_test/flutter_test.dart';

final _address = RegExp(r'[\w.+-]+@[\w-]+(?:\.[\w-]+)+');

/// [text] as the screen draws it: an email address in it may wrap only after
/// «@» and «.» (UX-1618, [breakableAddress]). TalkBack still reads [text].
String shown(String text) =>
    text.replaceAllMapped(_address, (m) => breakableAddress(m[0]!));

/// Finds [text] as the screen draws it; see [shown].
Finder findShown(String text) => find.text(shown(text));
