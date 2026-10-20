import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// One stop of TalkBack's reading: what it says, and whether it is read out
/// by itself when it appears or changes (a live region).
typedef ReadingStop = ({String label, bool live});

/// What TalkBack moves through, in its order: each node that says something,
/// with the children merged into it folded in. Semantics must be on
/// (`tester.ensureSemantics()`).
List<ReadingStop> readingOrder(WidgetTester tester) {
  final root =
      tester.binding.renderViews.first.owner!.semanticsOwner?.rootSemanticsNode;
  final stops = <ReadingStop>[];
  void visit(SemanticsNode node) {
    if (node.isInvisible) return;
    final data = node.getSemanticsData();
    final label = data.label.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (!node.isMergedIntoParent && label.isNotEmpty) {
      stops.add((label: label, live: data.flagsCollection.isLiveRegion));
    }
    if (node.mergeAllDescendantsIntoThisNode) return;
    for (final child in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    )) {
      visit(child);
    }
  }

  if (root != null) visit(root);
  return stops;
}

/// Where the first stop whose label [matches] is read, or -1.
int readAt(List<ReadingStop> stops, bool Function(String label) matches) =>
    stops.indexWhere((stop) => matches(stop.label));
