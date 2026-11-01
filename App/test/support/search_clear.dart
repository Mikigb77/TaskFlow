import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/widgets/search_clear.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX-2509: what a person sees of a search field's ✕.

/// The search field on screen; [within] narrows it, e.g. to a sheet.
Finder searchField({Finder? within}) => within == null
    ? find.byType(SearchField)
    : find.descendant(of: within, matching: find.byType(SearchField));

/// The ✕ at the end of [field], found by its tooltip.
Finder clearButton(Finder field, AppLocalizations l) => find.descendant(
  of: field,
  matching: find.widgetWithIcon(IconButton, Icons.close_rounded),
);

/// The words in [field] as the person sees them.
String searchText(WidgetTester tester, Finder field) => tester
    .widget<TextField>(find.descendant(of: field, matching: find.byType(TextField)))
    .controller!
    .text;

/// An empty [field] looks as it did before UX-2509: no ✕, no «Borrar búsqueda».
void expectNoClear(Finder field, AppLocalizations l) {
  expect(clearButton(field, l), findsNothing, reason: 'an empty field has no ✕');
  expect(
    find.descendant(of: field, matching: find.byTooltip(l.clearSearch)),
    findsNothing,
  );
}

/// [field] ends with one ✕: at least 48 × 48 dp, at the field's end, inside
/// the screen, tappable, and read by TalkBack as [AppLocalizations.clearSearch].
void expectClear(WidgetTester tester, Finder field, AppLocalizations l) {
  final clear = clearButton(field, l);
  expect(clear, findsOneWidget, reason: 'a field with words ends with a ✕');
  expect(clear.hitTestable(), findsOneWidget, reason: 'the ✕ can be tapped');
  final box = tester.getRect(clear);
  expect(box.width, greaterThanOrEqualTo(48), reason: 'the ✕ is 48 dp wide');
  expect(box.height, greaterThanOrEqualTo(48), reason: 'the ✕ is 48 dp tall');
  final input = tester.getRect(field);
  expect(box.center.dx, greaterThan(input.center.dx),
      reason: 'the ✕ is at the field’s end');
  expect(box.right, lessThanOrEqualTo(input.right + 0.5));
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(box.top, greaterThanOrEqualTo(0), reason: 'the ✕ is in view');
  expect(box.bottom, lessThanOrEqualTo(screen.height), reason: 'the ✕ is in view');
  expect(
    find.descendant(of: field, matching: find.byTooltip(l.clearSearch)),
    findsOneWidget,
  );
  final data = tester.getSemantics(clear).getSemanticsData();
  expect('${data.tooltip} ${data.label}', contains(l.clearSearch),
      reason: 'TalkBack reads «${l.clearSearch}»');
  expect(data.hasAction(SemanticsAction.tap), isTrue,
      reason: 'TalkBack can tap the ✕');
}

/// Taps [field]'s ✕ and settles.
Future<void> tapClear(WidgetTester tester, Finder field, AppLocalizations l) async {
  await tester.tap(clearButton(field, l));
  await tester.pumpAndSettle();
}
