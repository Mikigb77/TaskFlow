import 'package:agenda/l10n/region.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _break = '​';

/// UX-1618: [address], as the paragraph [text] draws it, wraps only after
/// «@» or «.», never mid-word. Returns the number of lines the address is
/// drawn on, so a caller can tell a wrapped address from one that fit.
int expectAddressWrapsWhole(
  WidgetTester tester,
  Finder text,
  String address,
) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)).first,
  );
  final drawn = paragraph.text.toPlainText(includeSemanticsLabels: false);
  final shownAddress = breakableAddress(address);
  final start = drawn.indexOf(shownAddress);
  expect(
    start,
    greaterThanOrEqualTo(0),
    reason: 'the address is drawn with its break points: «$drawn»',
  );
  final end = start + shownAddress.length;
  double? lastTop;
  int? lastIndex;
  var lines = 1;
  for (var i = start; i < end; i++) {
    if (drawn[i] == _break) continue;
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
    );
    if (boxes.isEmpty) continue;
    final top = boxes.first.top;
    if (lastTop != null && (top - lastTop).abs() > 1) {
      lines++;
      expect(
        drawn.substring(lastIndex! + 1, i),
        contains(_break),
        reason:
            'the address breaks mid-word, between «${drawn.substring(start, lastIndex + 1)}» and «${drawn.substring(i, end)}»',
      );
      expect(
        drawn[lastIndex],
        anyOf('@', '.'),
        reason: 'a line of the address ends in «${drawn[lastIndex]}»',
      );
    }
    lastTop = top;
    lastIndex = i;
  }
  return lines;
}

/// What TalkBack reads for [text]: its label, with no zero-width spaces.
String spokenLabel(WidgetTester tester, Finder text) {
  final label = tester.getSemantics(text).label;
  expect(label, isNot(contains(_break)), reason: 'read without break points');
  return label;
}
