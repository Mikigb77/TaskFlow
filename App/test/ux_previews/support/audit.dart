// Measured evidence for each preview: Flutter's accessibility guidelines,
// what TalkBack would read, clipped text and layout errors, and every tap
// target with its size and the gap to its neighbour. Widget-test evidence:
// the app's own widgets and fonts in the test engine, not a phone.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1 dp is 1/160 inch.
double dpToMm(double dp) => dp * 25.4 / 160;

/// Android's floor for a tap target, and the gap between two (M3, Android
/// accessibility; GUIDELINES.md RE-2 and §0).
const double minTarget = 48;
const double minGap = 8;

/// Primary actions under this are listed: the guide asks for clearly more
/// than 48 dp for older hands (RE-3).
const double primaryWatch = 56;

typedef Json = Map<String, Object?>;

/// Everything measured on one render. [image] is the render's raw RGBA at
/// [pixelRatio], used for the text-contrast pass.
Future<Json> audit(
  WidgetTester tester, {
  required List<FlutterErrorDetails> errors,
  required Size screen,
  required ByteData image,
  required int imageWidth,
  required int imageHeight,
  required double pixelRatio,
}) async {
  final view = tester.binding.renderViews.first;
  final root = view.owner!.semanticsOwner?.rootSemanticsNode;
  final nodes = <int, _Node>{};
  if (root != null) _collect(root, nodes, view.flutterView.devicePixelRatio);
  final paragraphs = _paragraphs(tester, screen);
  final contrast = _contrast(
    paragraphs,
    nodes,
    image,
    imageWidth,
    imageHeight,
    pixelRatio,
  );
  final guidelines = await _guidelines(tester, nodes, contrast.ratios);
  final targets = _targets(nodes, _primaryRects(tester), _barrierLabels(tester), screen);
  return {
    'guidelines': guidelines,
    'reading': root == null ? <Json>[] : _reading(root, nodes),
    'semanticsFlags': _semanticsFlags(nodes, targets, paragraphs),
    'layoutErrors': _layoutErrors(errors),
    'text': _textCuts(paragraphs, screen),
    'contrast': contrast.failures,
    'targets': [for (final target in targets) target.toJson()],
  };
}

/// The scrims' labels: tapping outside a sheet or dialog closes it. TalkBack
/// offers the scrim, but nobody aims at it, so it isn't counted as a target.
Set<String> _barrierLabels(WidgetTester tester) => {
  for (final element in find.byType(ModalBarrier).evaluate())
    if ((element.widget as ModalBarrier).semanticsLabel case final label?)
      _oneLine(label),
};

// ---------------------------------------------------------------- semantics

class _Node {
  _Node(this.node, this.data, this.rect);
  final SemanticsNode node;
  final SemanticsData data;

  /// In logical pixels (dp), on screen.
  final Rect rect;

  int get id => node.id;
  ui.SemanticsFlags get flags => data.flagsCollection;
  bool get hidden => flags.isHidden;
  bool get merged => node.isMergedIntoParent;
  bool get tappable =>
      data.hasAction(ui.SemanticsAction.tap) ||
      data.hasAction(ui.SemanticsAction.longPress);
  bool get disabled => flags.isEnabled == ui.Tristate.isFalse;

  String get name => _oneLine(
    [
      data.label,
      if (data.tooltip.isNotEmpty && data.tooltip != data.label) data.tooltip,
    ].where((part) => part.trim().isNotEmpty).join(' · '),
  );

  String get role {
    final f = flags;
    if (f.isTextField) return 'text field';
    if (f.isSlider) return 'slider';
    if (f.isLink) return 'link';
    if (f.isChecked != ui.CheckedState.none) {
      return f.isInMutuallyExclusiveGroup ? 'radio' : 'checkbox';
    }
    if (f.isToggled != ui.Tristate.none) return 'switch';
    if (f.isButton) return 'button';
    if (f.isImage) return 'image';
    if (f.isHeader) return 'heading';
    if (tappable) return 'tappable';
    return 'text';
  }

  List<String> get states {
    final f = flags;
    return [
      if (f.isChecked == ui.CheckedState.isTrue) 'checked',
      if (f.isChecked == ui.CheckedState.isFalse) 'not checked',
      if (f.isChecked == ui.CheckedState.mixed) 'partly checked',
      if (f.isToggled == ui.Tristate.isTrue) 'on',
      if (f.isToggled == ui.Tristate.isFalse) 'off',
      if (f.isSelected == ui.Tristate.isTrue) 'selected',
      if (f.isExpanded == ui.Tristate.isTrue) 'expanded',
      if (f.isExpanded == ui.Tristate.isFalse) 'collapsed',
      if (f.isEnabled == ui.Tristate.isFalse) 'disabled',
      if (f.isFocused == ui.Tristate.isTrue) 'focused',
      if (f.isObscured) 'obscured',
      if (f.isReadOnly) 'read-only',
      if (f.isHeader && role != 'heading') 'heading',
      if (f.isLiveRegion) 'live region',
      if (f.scopesRoute) 'route',
      if (f.namesRoute) 'names route',
      if (hidden) 'off screen',
    ];
  }

  static const _actions = {
    ui.SemanticsAction.tap: 'tap',
    ui.SemanticsAction.longPress: 'long press',
    ui.SemanticsAction.dismiss: 'dismiss',
    ui.SemanticsAction.increase: 'increase',
    ui.SemanticsAction.decrease: 'decrease',
    ui.SemanticsAction.scrollUp: 'scroll up',
    ui.SemanticsAction.scrollDown: 'scroll down',
    ui.SemanticsAction.scrollLeft: 'scroll left',
    ui.SemanticsAction.scrollRight: 'scroll right',
    ui.SemanticsAction.setText: 'set text',
    ui.SemanticsAction.customAction: 'custom actions',
    ui.SemanticsAction.expand: 'expand',
    ui.SemanticsAction.collapse: 'collapse',
  };

  /// Custom actions by name, as TalkBack's actions menu lists them.
  List<String> get actions => [
    for (final entry in _actions.entries)
      if (data.hasAction(entry.key))
        if (entry.key == ui.SemanticsAction.customAction &&
            (data.customSemanticsActionIds?.isNotEmpty ?? false))
          for (final id in data.customSemanticsActionIds!)
            '«${CustomSemanticsAction.getAction(id)?.label ?? '?'}»'
        else
          entry.value,
  ];
}

String _oneLine(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Every node, with its rect on screen in dp.
void _collect(SemanticsNode node, Map<int, _Node> into, double ratio) {
  var rect = node.rect;
  for (SemanticsNode? current = node; current != null; current = current.parent) {
    final transform = current.transform;
    if (transform != null) rect = MatrixUtils.transformRect(transform, rect);
  }
  rect = Rect.fromLTRB(
    rect.left / ratio,
    rect.top / ratio,
    rect.right / ratio,
    rect.bottom / ratio,
  );
  into[node.id] = _Node(node, node.getSemanticsData(), rect);
  node.visitChildren((child) {
    _collect(child, into, ratio);
    return true;
  });
}

/// What TalkBack would move through, in its order: each node that says or
/// does something, with merged children folded into it.
List<Json> _reading(SemanticsNode root, Map<int, _Node> nodes) {
  final out = <Json>[];
  void visit(SemanticsNode node, int depth) {
    if (node.isInvisible) return;
    final info = nodes[node.id];
    var level = depth;
    if (info != null && !info.merged && _speaks(info)) {
      out.add({
        'id': info.id,
        'depth': depth,
        'role': info.role,
        'label': _oneLine(info.data.label),
        if (info.data.value.isNotEmpty) 'value': _oneLine(info.data.value),
        if (info.data.hint.isNotEmpty) 'hint': _oneLine(info.data.hint),
        if (info.data.tooltip.isNotEmpty)
          'tooltip': _oneLine(info.data.tooltip),
        if (info.states.isNotEmpty) 'states': info.states,
        if (info.actions.isNotEmpty) 'actions': info.actions,
      });
      level = depth + 1;
    }
    if (node.mergeAllDescendantsIntoThisNode) return;
    for (final child in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    )) {
      visit(child, level);
    }
  }

  visit(root, 0);
  return out;
}

bool _speaks(_Node node) {
  final data = node.data;
  final f = node.flags;
  return data.label.trim().isNotEmpty ||
      data.value.trim().isNotEmpty ||
      data.hint.trim().isNotEmpty ||
      data.tooltip.trim().isNotEmpty ||
      node.tappable ||
      f.isTextField ||
      f.isImage ||
      f.isButton ||
      f.isLink ||
      f.isChecked != ui.CheckedState.none ||
      f.isToggled != ui.Tristate.none ||
      f.isSlider;
}

// --------------------------------------------------------------- guidelines

/// Flutter's own guidelines, as `meetsGuideline` runs them, recorded instead
/// of failing. Each failure is matched to its node by id.
Future<Json> _guidelines(
  WidgetTester tester,
  Map<int, _Node> nodes,
  Map<String, double> ratios,
) async {
  Future<(bool, String?, String?)> run(AccessibilityGuideline g) async {
    try {
      final result = await g.evaluate(tester);
      return (result.passed, result.reason, null);
    } catch (error) {
      return (false, null, '$error'.split('\n').first);
    }
  }

  final tap = await run(androidTapTargetGuideline);
  final labeled = await run(labeledTapTargetGuideline);
  final contrast = await run(textContrastGuideline);
  return {
    'tapTarget': {
      if (tap.$3 != null) 'error': tap.$3,
      'failures': [
        for (final (id, block) in _blocks(tap.$2))
          {
            'label': nodes[id]?.name ?? '',
            'role': nodes[id]?.role ?? '',
            'size': _found(block),
            'rect': _rectJson(nodes[id]?.rect),
          },
      ],
    },
    'labeled': {
      if (labeled.$3 != null) 'error': labeled.$3,
      'failures': [
        for (final (id, _) in _blocks(labeled.$2))
          {
            'role': nodes[id]?.role ?? '',
            'rect': _rectJson(nodes[id]?.rect),
            'actions': nodes[id]?.actions ?? const <String>[],
          },
      ],
    },
    'contrast': {
      if (contrast.$3 != null) 'error': contrast.$3,
      'failures': [
        for (final (id, block) in _blocks(contrast.$2))
          _contrastFailure(id, block, nodes, ratios),
      ],
    },
  };
}

/// A guideline's reason, split into one block per failing node.
List<(int, String)> _blocks(String? reason) {
  if (reason == null || reason.isEmpty) return const [];
  final marks = RegExp(r'SemanticsNode#(\d+)').allMatches(reason).toList();
  return [
    for (var i = 0; i < marks.length; i++)
      (
        int.parse(marks[i].group(1)!),
        reason.substring(
          marks[i].start,
          i + 1 < marks.length ? marks[i + 1].start : reason.length,
        ),
      ),
  ];
}

String _found(String block) {
  final size = RegExp(
    r'but found Size\(([\d.]+), ([\d.]+)\)',
  ).firstMatch(block);
  if (size == null) return '';
  return '${double.parse(size.group(1)!).toStringAsFixed(1)} × '
      '${double.parse(size.group(2)!).toStringAsFixed(1)}';
}

Json _contrastFailure(
  int id,
  String block,
  Map<int, _Node> nodes,
  Map<String, double> ratios,
) {
  final ratio = RegExp(
    r'at least (\d+(?:\.\d+)?) but found (\d+(?:\.\d+)?) '
    r'for a font size of (\d+(?:\.\d+)?|null)',
  ).firstMatch(block);
  final colors = RegExp(
    r'light - (Color\(.*?\)), dark - (Color\(.*?\))',
  ).firstMatch(block);
  final text = nodes[id]?.name ?? '';
  // The same text measured with its own colour (the full pass): Flutter's
  // histogram can take an anti-aliased edge for the text's colour.
  final ours = ratios[_oneLine(nodes[id]?.data.label ?? '')];
  return {
    'text': text,
    if (ratio != null) 'required': ratio.group(1),
    if (ratio != null) 'found': ratio.group(2),
    if (ratio != null) 'fontSize': ratio.group(3),
    if (colors != null) 'light': _hex(colors.group(1)!),
    if (colors != null) 'dark': _hex(colors.group(2)!),
    if (ours != null) 'ours': double.parse(ours.toStringAsFixed(2)),
  };
}

/// `Color(alpha: 1.0000, red: 0.1, …)` or `Color(0xff…)` as `#rrggbb`.
String _hex(String color) {
  final legacy = RegExp(r'0x([0-9a-fA-F]{8})').firstMatch(color);
  if (legacy != null) return '#${legacy.group(1)!.substring(2).toLowerCase()}';
  double channel(String name) =>
      double.tryParse(
        RegExp('$name: ([\\d.]+)').firstMatch(color)?.group(1) ?? '',
      ) ??
      0;
  String part(double value) =>
      (value * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${part(channel('red'))}${part(channel('green'))}${part(channel('blue'))}';
}

List<double>? _rectJson(Rect? rect) => rect == null
    ? null
    : [
        for (final v in [rect.left, rect.top, rect.width, rect.height])
          double.parse(v.toStringAsFixed(1)),
      ];

// ------------------------------------------------------------------ targets

class _Target {
  _Target(this.node, this.primary, this.partlyOff);
  final _Node node;
  final bool primary;
  final bool partlyOff;
  double? gap;
  String? neighbour;

  /// Where the nearest neighbour is: left, right, above, below or diagonal.
  String? side;
  String? inside;
  bool overlaps = false;

  Rect get rect => node.rect;

  Json toJson() => {
    'label': node.name,
    'role': node.role,
    'rect': _rectJson(rect),
    'w': double.parse(rect.width.toStringAsFixed(1)),
    'h': double.parse(rect.height.toStringAsFixed(1)),
    if (primary) 'primary': true,
    if (partlyOff) 'partlyOff': true,
    if (node.disabled) 'disabled': true,
    if (gap != null) 'gap': double.parse(gap!.toStringAsFixed(1)),
    if (neighbour != null) 'neighbour': neighbour,
    if (side != null) 'side': side,
    if (inside != null) 'inside': inside,
    if (overlaps) 'overlaps': true,
  };
}

/// Filled buttons, elevated buttons and FABs: the screen's primary actions.
List<Rect> _primaryRects(WidgetTester tester) {
  final finder = find.byWidgetPredicate(
    (widget) =>
        widget is FilledButton ||
        widget is ElevatedButton ||
        widget is FloatingActionButton,
  );
  final rects = <Rect>[];
  for (final element in finder.evaluate()) {
    final box = element.renderObject;
    if (box is RenderBox && box.hasSize && box.attached) {
      rects.add(
        MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size),
      );
    }
  }
  return rects;
}

bool _close(Rect a, Rect b) =>
    (a.left - b.left).abs() < 1 &&
    (a.top - b.top).abs() < 1 &&
    (a.right - b.right).abs() < 1 &&
    (a.bottom - b.bottom).abs() < 1;

List<_Target> _targets(
  Map<int, _Node> nodes,
  List<Rect> primaries,
  Set<String> barriers,
  Size screen,
) {
  final screenRect = Offset.zero & screen;
  final targets = <_Target>[
    for (final node in nodes.values)
      if (node.tappable &&
          !node.merged &&
          !node.hidden &&
          !node.node.isInvisible &&
          node.rect.overlaps(screenRect) &&
          !node.flags.scopesRoute &&
          !(node.role == 'tappable' && barriers.contains(node.name)))
        _Target(
          node,
          primaries.any((rect) => _close(rect, node.rect)),
          !_contains(screenRect, node.rect),
        ),
  ];
  // Screen-sized nodes (a sheet's scrim, a page that dismisses) aren't
  // targets anyone aims at.
  targets.removeWhere(
    (t) => t.rect.width >= screen.width - 1 && t.rect.height >= screen.height * 0.6,
  );
  String nameOf(_Target t) => t.node.name.isEmpty ? t.node.role : t.node.name;
  for (final target in targets) {
    double? around;
    for (final other in targets) {
      if (identical(other, target)) continue;
      if (_contains(other.rect, target.rect) &&
          !_close(other.rect, target.rect)) {
        // Nested, as a checkbox in a tappable row: named by the smallest
        // target around it, and not measured against it.
        final size = other.rect.width * other.rect.height;
        if (around == null || size < around) {
          around = size;
          target.inside = nameOf(other);
        }
        continue;
      }
      if (_contains(target.rect, other.rect)) continue;
      final gap = _gap(target.rect, other.rect);
      final overlap = target.rect.intersect(other.rect);
      if (overlap.width > 0.5 && overlap.height > 0.5) target.overlaps = true;
      if (target.gap == null || gap < target.gap!) {
        target.gap = gap;
        target.neighbour = nameOf(other);
        target.side = _side(target.rect, other.rect);
      }
    }
  }
  targets.sort((a, b) {
    final top = a.rect.top.compareTo(b.rect.top);
    return top != 0 ? top : a.rect.left.compareTo(b.rect.left);
  });
  return targets;
}

bool _contains(Rect outer, Rect inner) =>
    inner.left >= outer.left - 0.5 &&
    inner.top >= outer.top - 0.5 &&
    inner.right <= outer.right + 0.5 &&
    inner.bottom <= outer.bottom + 0.5;

/// Where [other] is from [target]: beside it, above or below it, or neither.
String _side(Rect target, Rect other) {
  final columns = math.min(target.right, other.right) - math.max(target.left, other.left);
  final rows = math.min(target.bottom, other.bottom) - math.max(target.top, other.top);
  if (columns > 0.5 && rows <= 0.5) {
    return other.center.dy < target.center.dy ? 'above' : 'below';
  }
  if (rows > 0.5 && columns <= 0.5) {
    return other.center.dx < target.center.dx ? 'left' : 'right';
  }
  if (rows > 0.5 && columns > 0.5) return 'overlapping';
  return 'diagonal';
}

/// The empty space between two rects' edges: 0 when they touch or overlap.
double _gap(Rect a, Rect b) {
  final dx = math.max(0.0, math.max(a.left - b.right, b.left - a.right));
  final dy = math.max(0.0, math.max(a.top - b.bottom, b.top - a.bottom));
  return math.sqrt(dx * dx + dy * dy);
}

// --------------------------------------------------------------- paragraphs

class _Paragraph {
  _Paragraph(this.box, this.text, this.rect, this.drawn, this.visible)
    : speaker = _speakerOf(box)?.id;
  final RenderParagraph box;
  final String text;

  /// The semantics node TalkBack reads this text in, if any.
  final int? speaker;

  /// Its whole box; the part its scroll views and clips draw, which can run
  /// past the screen's edge; and the part on screen.
  final Rect rect;
  final Rect drawn;
  final Rect visible;
}

/// The node TalkBack reads [box]'s text in: the nearest semantics node above
/// it in the render tree, or the node that one is merged into.
SemanticsNode? _speakerOf(RenderObject box) {
  for (RenderObject? current = box; current != null; current = current.parent) {
    final node = current.debugSemantics;
    if (node == null) continue;
    var speaker = node;
    while (speaker.isMergedIntoParent && speaker.parent != null) {
      speaker = speaker.parent!;
    }
    return speaker;
  }
  return null;
}

/// The part of [box] its ancestors paint: its rect cut by every clip above
/// it (scroll views, clipped containers). Null when none of it shows.
Rect? _visibleRect(RenderBox box) {
  var rect = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
  RenderObject child = box;
  var parent = box.parent;
  while (parent != null) {
    if (!parent.paintsChild(child)) return null;
    final clip = parent.describeApproximatePaintClip(child);
    if (clip != null) {
      rect = rect.intersect(
        MatrixUtils.transformRect(parent.getTransformTo(null), clip),
      );
      if (rect.width <= 0.5 || rect.height <= 0.5) return null;
    }
    child = parent;
    parent = parent.parent;
  }
  return rect;
}

/// Private-use code points: Material icons drawn as text.
bool _isIcon(String text) =>
    text.runes.isNotEmpty &&
    text.runes.every((r) => (r >= 0xE000 && r <= 0xF8FF) || r >= 0xF0000);

/// Every line of text in front: on stage (not in a hidden tab or a list item
/// scrolled out of the cache) and in the route in front, so a page dimmed
/// under a sheet or a dialog isn't measured. With its rect on screen.
List<_Paragraph> _paragraphs(WidgetTester tester, Size screen) {
  final out = <_Paragraph>[];
  final seen = <RenderParagraph>{};
  for (final element in find.byType(RichText).evaluate()) {
    final box = element.renderObject;
    if (box is! RenderParagraph || !box.attached || !box.hasSize) continue;
    if (!seen.add(box)) continue;
    if (ModalRoute.of(element)?.isCurrent != true) continue;
    final text = box.text.toPlainText(includeSemanticsLabels: false);
    if (text.trim().isEmpty || _isIcon(text.trim())) continue;
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    final drawn = _visibleRect(box);
    final visible = drawn?.intersect(Offset.zero & screen);
    if (drawn == null ||
        visible == null ||
        visible.width <= 0.5 ||
        visible.height <= 0.5) {
      continue;
    }
    out.add(_Paragraph(box, text, rect, drawn, visible));
  }
  return out;
}

/// Text cut by its line limit, its box or the screen's edge.
List<Json> _textCuts(List<_Paragraph> paragraphs, Size screen) {
  final out = <Json>[];
  final letter = RegExp(r'\p{L}', unicode: true);
  // Letters that reach below the baseline: cutting the descent shows on them.
  final descender = RegExp(r'[gjpqyQ,;()\[\]{}|/@çÇ]');
  for (final p in paragraphs) {
    final box = p.box;
    final reasons = <String>[];
    if (box.didExceedMaxLines) {
      final limit = box.maxLines;
      reasons.add(
        limit == null
            ? 'cut short (${box.overflow.name}): its box is too small for it'
            : '${box.overflow.name} at $limit line${limit == 1 ? '' : 's'}',
      );
    }
    final plain = box.text.toPlainText(includeSemanticsLabels: false);
    final painter = TextPainter(
      text: box.text,
      textDirection: box.textDirection,
      textAlign: box.textAlign,
      textScaler: box.textScaler,
      maxLines: box.maxLines,
      locale: box.locale,
      strutStyle: box.strutStyle,
      textWidthBasis: box.textWidthBasis,
      textHeightBehavior: box.textHeightBehavior,
    );
    try {
      if (!box.softWrap) {
        painter.layout();
        if (painter.width > box.size.width + 0.5) {
          reasons.add(
            'wider than its box by ${(painter.width - box.size.width).toStringAsFixed(0)} dp (${box.overflow.name})',
          );
        }
      } else {
        painter.layout(maxWidth: box.size.width);
        final lines = painter.computeLineMetrics();
        TextRange rangeOf(LineMetrics line) => painter.getLineBoundary(
          painter.getPositionForOffset(
            Offset(line.left + line.width / 2, line.baseline - line.ascent / 2),
          ),
        );
        String textOf(LineMetrics line) {
          final range = rangeOf(line);
          return range.isValid && range.end <= plain.length
              ? plain.substring(range.start, range.end)
              : '';
        }

        // A line is cut when its letters pass the box's bottom. Line spacing
        // alone, or descender room on a line with no descenders, can
        // overhang without cutting anything visible.
        var cut = 0;
        for (final line in lines) {
          final bottom = box.size.height + 1;
          if (line.baseline + line.descent <= bottom) continue;
          if (line.baseline > bottom || descender.hasMatch(textOf(line))) cut++;
        }
        if (cut > 0) {
          reasons.add(
            '$cut of ${lines.length} line${lines.length == 1 ? '' : 's'} cut '
            'at the bottom of its box (${box.overflow.name})',
          );
        }
        // A word too long for the width breaks between two letters.
        for (var i = 0; i + 1 < lines.length; i++) {
          final range = rangeOf(lines[i]);
          final at = range.end;
          if (!range.isValid || at <= 0 || at >= plain.length) continue;
          if (!letter.hasMatch(plain[at - 1]) || !letter.hasMatch(plain[at])) {
            continue;
          }
          var from = at - 1, to = at;
          while (from > 0 && letter.hasMatch(plain[from - 1])) {
            from--;
          }
          while (to < plain.length && letter.hasMatch(plain[to])) {
            to++;
          }
          reasons.add(
            'the word «${plain.substring(from, to)}» splits across lines '
            '(«${plain.substring(from, at)}» / «${plain.substring(at, to)}»)',
          );
        }
      }
    } finally {
      painter.dispose();
    }
    // Drawn past the edge, with no scroll view clipping it first.
    if (p.drawn.left < -0.5 || p.drawn.right > screen.width + 0.5) {
      reasons.add('runs past the screen edge');
    }
    if (reasons.isEmpty) continue;
    out.add({
      'text': _oneLine(p.text),
      'why': reasons.join('; '),
      'rect': _rectJson(p.visible),
    });
  }
  return out;
}

// ----------------------------------------------------------- contrast pass

double _luminance(int r, int g, int b) {
  double channel(int value) {
    final c = value / 255;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
}

double _ratio(double a, double b) =>
    (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);

String _rgb(int r, int g, int b) =>
    '#${[r, g, b].map((v) => v.toRadixString(16).padLeft(2, '0')).join()}';

/// The text colour a paragraph paints most: its root style's colour.
Color? _textColor(InlineSpan span) {
  Color? found;
  span.visitChildren((child) {
    final color = child.style?.color ?? child.style?.foreground?.color;
    if (color != null) {
      found = color;
      return false;
    }
    return true;
  });
  return span.style?.color ?? found;
}

/// Every visible line against the pixels behind it: the text's colour from
/// its style, the background as the commonest colour around it. Covers the
/// lines Flutter's guideline skips (merged labels such as list rows).
/// [ratios] has every line's ratio, by its text.
({List<Json> failures, Map<String, double> ratios}) _contrast(
  List<_Paragraph> paragraphs,
  Map<int, _Node> nodes,
  ByteData image,
  int width,
  int height,
  double ratio,
) {
  final out = <Json>[];
  final ratios = <String, double>{};
  // Text in a disabled control, or inside one, is exempt (WCAG 1.4.3).
  bool inDisabled(int? id) {
    for (SemanticsNode? node = nodes[id]?.node; node != null; node = node.parent) {
      if (node.getSemanticsData().flagsCollection.isEnabled == ui.Tristate.isFalse) {
        return true;
      }
    }
    return false;
  }

  /// Every colour in [area] of the render, with how often it appears.
  Map<int, int> colours(Rect area) {
    final left = (area.left * ratio).floor().clamp(0, width - 1);
    final top = (area.top * ratio).floor().clamp(0, height - 1);
    final right = (area.right * ratio).ceil().clamp(0, width);
    final bottom = (area.bottom * ratio).ceil().clamp(0, height);
    final counts = <int, int>{};
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final offset = (y * width + x) * 4;
        final rgb =
            (image.getUint8(offset) << 16) |
            (image.getUint8(offset + 1) << 8) |
            image.getUint8(offset + 2);
        counts[rgb] = (counts[rgb] ?? 0) + 1;
      }
    }
    return counts;
  }

  for (final p in paragraphs) {
    final color = _textColor(p.box.text);
    if (color == null) continue;
    // The background is the commonest colour inside the text's own box once
    // the text's colour is set aside; if little is left (the text fills its
    // box, or the background is close to the text's colour), the commonest
    // colour within 3 dp around it.
    final cr = (color.r * 255).round(), cg = (color.g * 255).round(), cb = (color.b * 255).round();
    bool nearText(int rgb) {
      final dr = ((rgb >> 16) & 0xff) - cr, dg = ((rgb >> 8) & 0xff) - cg, db = (rgb & 0xff) - cb;
      return dr * dr + dg * dg + db * db < 40 * 40;
    }

    final inside = colours(p.visible);
    final total = inside.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) continue;
    final others = {
      for (final entry in inside.entries)
        if (!nearText(entry.key)) entry.key: entry.value,
    };
    final rest = others.values.fold<int>(0, (a, b) => a + b);
    final counts = rest >= total * 0.15 ? others : colours(p.visible.inflate(3));
    if (counts.isEmpty) continue;
    final background = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final br = (background >> 16) & 0xff, bg = (background >> 8) & 0xff, bb = background & 0xff;
    // A translucent text colour is painted over the background.
    final a = color.a;
    final tr = (color.r * 255 * a + br * (1 - a)).round();
    final tg = (color.g * 255 * a + bg * (1 - a)).round();
    final tb = (color.b * 255 * a + bb * (1 - a)).round();
    final contrast = _ratio(_luminance(tr, tg, tb), _luminance(br, bg, bb));
    final style = p.box.text.style;
    final size = p.box.textScaler.scale(style?.fontSize ?? 14);
    final bold = (style?.fontWeight?.value ?? 400) >= 700;
    // WCAG large text: 18 pt (24 px), or 14 pt (18.67 px) bold.
    final large = size >= 24 || (bold && size >= 18.66);
    final required = large ? 3.0 : 4.5;
    final text = _oneLine(p.text);
    ratios[text] = math.min(ratios[text] ?? double.infinity, contrast);
    if (contrast >= required - 0.01) continue;
    final exempt = inDisabled(p.speaker);
    out.add({
      'text': text,
      'ratio': double.parse(contrast.toStringAsFixed(2)),
      'required': required,
      'size': double.parse(size.toStringAsFixed(1)),
      if (bold) 'bold': true,
      'textColor': _rgb(tr, tg, tb),
      'background': _rgb(br, bg, bb),
      if (exempt) 'disabled': true,
    });
  }
  return (failures: out, ratios: ratios);
}

// ------------------------------------------------------------ flags & errors

/// Unlabeled controls and images, duplicate labels among controls, and
/// controls whose spoken label doesn't contain the words they show (WCAG
/// 2.5.3 Label in Name).
Json _semanticsFlags(
  Map<int, _Node> nodes,
  List<_Target> targets,
  List<_Paragraph> paragraphs,
) {
  final unlabeled = <Json>[];
  for (final node in nodes.values) {
    if (node.merged || node.hidden || node.node.isInvisible) continue;
    final data = node.data;
    final empty =
        data.label.trim().isEmpty &&
        data.tooltip.trim().isEmpty &&
        data.value.trim().isEmpty;
    if (node.flags.isTextField) {
      if (empty && data.hint.trim().isEmpty) {
        unlabeled.add({'role': 'text field', 'rect': _rectJson(node.rect)});
      }
    } else if ((node.tappable || node.flags.isButton) && empty) {
      unlabeled.add({
        'role': node.role,
        'rect': _rectJson(node.rect),
        'actions': node.actions,
      });
    } else if (node.flags.isImage && data.label.trim().isEmpty) {
      unlabeled.add({'role': 'image', 'rect': _rectJson(node.rect)});
    }
  }
  final byLabel = <String, int>{};
  for (final target in targets) {
    final key = target.node.name.toLowerCase();
    if (key.isEmpty) continue;
    byLabel[key] = (byLabel[key] ?? 0) + 1;
  }
  final duplicates = [
    for (final entry in byLabel.entries)
      if (entry.value > 1)
        {
          'label': targets
              .firstWhere((t) => t.node.name.toLowerCase() == entry.key)
              .node
              .name,
          'count': entry.value,
        },
  ];
  String norm(String text) => _oneLine(text).toLowerCase();
  // Each line of text belongs to the node TalkBack reads it in (a message or
  // a sheet drawn over a row has its own). That node should say the words it
  // shows; a node that says none of them leaves the text unread.
  final byNode = <int, List<_Paragraph>>{};
  for (final p in paragraphs) {
    final speaker = p.speaker;
    if (speaker != null) byNode.putIfAbsent(speaker, () => []).add(p);
  }
  // Compared word by word, so punctuation, bullets and arrows drawn for the
  // eye («X → Y», read «de X a Y») don't count as differences.
  final wordPattern = RegExp(r'[\p{L}\p{N}]+', unicode: true);
  Set<String> words(String text) => {
    for (final match in wordPattern.allMatches(norm(text))) match.group(0)!,
  };
  final mismatches = <Json>[];
  for (final entry in byNode.entries) {
    final node = nodes[entry.key];
    if (node == null || node.hidden) continue;
    final data = node.data;
    final spoken = words(
      '${data.label} ${data.value} ${data.hint} ${data.tooltip}',
    );
    final shown = [
      for (final p in entry.value)
        if (words(p.text).isNotEmpty && !spoken.containsAll(words(p.text)))
          _oneLine(p.text),
    ];
    if (shown.isEmpty) continue;
    mismatches.add({
      'label': node.name,
      'shows': shown,
      'role': node.role,
      if (spoken.isEmpty) 'unread': true,
    });
  }
  return {
    'unlabeled': unlabeled,
    'duplicates': duplicates,
    'mismatches': mismatches,
  };
}

/// Overflow and other layout or build errors reported while rendering, with
/// the app widget that caused them.
List<Json> _layoutErrors(List<FlutterErrorDetails> errors) {
  final out = <Json>[];
  final seen = <String>{};
  for (final details in errors) {
    final message = _oneLine(details.exceptionAsString().split('\n').first);
    final full = details.toString();
    final where = RegExp(
      r'file:///[^\s]*?/(lib/[^\s:]+\.dart:\d+:\d+)',
    ).firstMatch(full)?.group(1);
    final key = '$message|$where';
    if (!seen.add(key)) continue;
    out.add({
      'message': message,
      if (where != null) 'where': where,
      'library': details.library ?? '',
    });
  }
  return out;
}
