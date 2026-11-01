// UX-2505 (P285): a dialog's text field shows no character counter, on
// screen or read out, and its limit still stops typing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a default counter looks like: «0/80» on screen.
final counterText = RegExp(r'\d+\s*/\s*\d+');

/// What a default counter reads out: «Quedan 80 caracteres», in any of the
/// app's languages.
final counterSpeech = RegExp('caracteres|characters|caràcters');

/// The open dialog's one text field has no counter, shown or announced;
/// typing [maxLength] + 20 characters keeps [maxLength]. Needs semantics on
/// (`tester.ensureSemantics()`).
Future<void> expectNoCounter(WidgetTester tester, int maxLength) async {
  final dialog = find.byType(AlertDialog);
  expect(dialog, findsOneWidget);
  final field = find.descendant(of: dialog, matching: find.byType(EditableText));
  expect(field, findsOneWidget);
  final counter = find.descendant(
    of: dialog,
    matching: find.textContaining(counterText),
  );
  expect(counter, findsNothing, reason: 'no «0/$maxLength» on screen');
  expect(
    find.bySemanticsLabel(counterSpeech),
    findsNothing,
    reason: 'no «Quedan $maxLength caracteres» read out',
  );
  await tester.enterText(field, 'a' * (maxLength + 20));
  await tester.pump();
  expect(
    tester.widget<EditableText>(field).controller.text.length,
    maxLength,
    reason: 'typing past the limit is still stopped',
  );
  expect(counter, findsNothing, reason: 'no «$maxLength/$maxLength»');
  expect(find.bySemanticsLabel(counterSpeech), findsNothing);
}
