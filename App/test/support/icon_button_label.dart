// P304 (UX-2630, UX-2631): a button with an icon, measured as a person sees
// it: the icon beside its label's text, and the two centred in the button.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'button_label.dart';

/// The outlined button that shows [label].
Finder outlinedButtonWithText(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
);

/// [button]'s visible shape, its Material: Flutter's tap target around it
/// may reach a few dp further (48 dp plus the theme's density).
Finder visibleButton(Finder button) =>
    find.descendant(of: button, matching: find.byType(Material)).first;

/// The space from [button]'s icon to the nearest word of its label [label],
/// and how far the icon-and-text pair sits from the button's centre.
({double gap, double offCentre, Rect icon, Rect text, Rect button})
iconAndLabel(WidgetTester tester, Finder button, String label) {
  final icon = tester.getRect(
    find.descendant(of: button, matching: find.byType(Icon)),
  );
  final lines = labelLines(tester, button, label);
  final text = Rect.fromLTRB(
    lines.map((line) => line.left).reduce(math.min),
    lines.first.top,
    lines.map((line) => line.right).reduce(math.max),
    lines.last.bottom,
  );
  final rect = tester.getRect(visibleButton(button));
  final before = icon.left - rect.left;
  final after = rect.right - text.right;
  return (
    gap: text.left - icon.right,
    offCentre: (before - after).abs() / 2,
    icon: icon,
    text: text,
    button: rect,
  );
}

/// [button]'s icon sits just left of its label's longest line, with no more
/// than [maxGap] dp between them (Flutter's own spacing: 8 dp at 1×, down
/// to 4 dp at 2×), and the icon and text together are centred in the
/// button's visible shape, to within [tolerance] dp. Flutter pads a button
/// with an icon a third less on the icon's side (16 and 24 dp at 1×, 8 and
/// 12 at 2×), so the pair sits up to 2 dp towards the icon by design.
void expectIconBesideCentredLabel(
  WidgetTester tester,
  Finder button,
  String label, {
  double maxGap = 10,
  double tolerance = 2.5,
}) {
  expect(button, findsOneWidget, reason: '«$label» is one button');
  final m = iconAndLabel(tester, button, label);
  expect(
    m.gap,
    inInclusiveRange(2, maxGap),
    reason:
        '«$label»: the icon ${m.icon} sits beside the text ${m.text} '
        '(${m.gap} dp between them)',
  );
  expect(
    m.offCentre,
    lessThanOrEqualTo(tolerance),
    reason:
        '«$label»: icon and text centred in the button ${m.button} '
        '(icon from ${m.icon.left - m.button.left} dp, text to '
        '${m.button.right - m.text.right} dp from the right edge)',
  );
}
