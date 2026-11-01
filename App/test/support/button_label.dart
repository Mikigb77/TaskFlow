// P289 (UX-2108, UX-2608): measuring a filled button as a person sees it,
// its height and where its label's lines sit inside it.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads Manrope, the app's font, so a label wraps as it does on a phone.
Future<void> loadManrope() async => (FontLoader(
  'Manrope',
)..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();

/// The filled button (plain, tonal or with an icon) that shows [label].
Finder filledButtonWithText(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is FilledButton),
);

/// [label]'s paragraph inside [button].
RenderParagraph labelParagraph(
  WidgetTester tester,
  Finder button,
  String label,
) => tester.renderObject<RenderParagraph>(
  find.descendant(
    of: find.descendant(of: button, matching: find.text(label)),
    matching: find.byType(RichText),
  ),
);

/// [label]'s lines inside [button], on screen: each from its first word's
/// left edge to its last word's right edge, spaces left out.
List<Rect> labelLines(WidgetTester tester, Finder button, String label) {
  final paragraph = labelParagraph(tester, button, label);
  final lines = <double, Rect>{};
  for (final word in RegExp(r'\S+').allMatches(label)) {
    for (final box in paragraph.getBoxesForSelection(
      TextSelection(baseOffset: word.start, extentOffset: word.end),
    )) {
      final rect = box.toRect().shift(paragraph.localToGlobal(Offset.zero));
      final key = (rect.top * 2).roundToDouble() / 2;
      lines[key] = lines[key]?.expandToInclude(rect) ?? rect;
    }
  }
  final sorted = lines.values.toList()..sort((a, b) => a.top.compareTo(b.top));
  return sorted;
}

/// [button]'s label [label] is centred, line by line, in the space the label
/// has (unless [centred] is false); with [wraps], it takes two lines or
/// more; and at least [gap] dp lie between the text and the button's top and
/// bottom edges.
void expectCentredPaddedLabel(
  WidgetTester tester,
  Finder button,
  String label, {
  bool wraps = true,
  bool centred = true,
  double gap = 8,
}) {
  expect(button, findsOneWidget, reason: '«$label» is one filled button');
  final paragraph = labelParagraph(tester, button, label);
  expect(paragraph.didExceedMaxLines, isFalse, reason: '«$label» whole');
  final box = paragraph.localToGlobal(Offset.zero) & paragraph.size;
  final lines = labelLines(tester, button, label);
  if (wraps) {
    expect(
      lines.length,
      greaterThanOrEqualTo(2),
      reason: '«$label» wraps here, as the render shows',
    );
  }
  for (final line in centred ? lines : const <Rect>[]) {
    final before = line.left - box.left;
    final after = box.right - line.right;
    expect(
      (before - after).abs(),
      lessThanOrEqualTo(1.5),
      reason:
          '«$label»: the line $line is centred in the label $box '
          '($before dp before it, $after dp after it)',
    );
  }
  final rect = tester.getRect(button);
  final top = lines.first.top;
  final bottom = lines.last.bottom;
  expect(
    top - rect.top,
    greaterThanOrEqualTo(gap),
    reason: '«$label»: room above the text (text $top, button $rect)',
  );
  expect(
    rect.bottom - bottom,
    greaterThanOrEqualTo(gap),
    reason: '«$label»: room below the text (text $bottom, button $rect)',
  );
  expect(box.left, greaterThanOrEqualTo(rect.left - 0.5));
  expect(box.right, lessThanOrEqualTo(rect.right + 0.5));
}
