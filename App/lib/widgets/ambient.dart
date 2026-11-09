import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:agenda/theme/motion.dart';

/// The living details that give TaskFlow the feel of its website and of
/// garbar.tech and Lucid Saga: colour that drifts, light that breathes and
/// crosses, motes that rise, a little burst when something is done. Each is
/// decoration only: excluded from semantics, never in the way of a tap, and
/// still where the phone asks for less motion (AppMotion).

/// TaskFlow's light colours, in each theme: the site's greens and its lime.
class AmbientColors {
  const AmbientColors._(this.a, this.b, this.c, this.mote);
  final Color a;
  final Color b;
  final Color c;
  final Color mote;

  static AmbientColors of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? const AmbientColors._(
            Color(0x3329876A),
            Color(0x26A5D88B),
            Color(0x1F6A9BC3),
            Color(0xFFD4ECA3),
          )
        : const AmbientColors._(
            Color(0x473F9A6E),
            Color(0x66D4ECA3),
            Color(0x2E9CC9B6),
            Color(0xFF3C9A73),
          );
  }
}

/// Slow colour drifting behind a screen, as behind the website's closing
/// card: three soft lights in TaskFlow's greens wander for about half a
/// minute and come back. Paints over [color] (the page's own background).
class AmbientBackdrop extends StatefulWidget {
  const AmbientBackdrop({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;

  /// The background for a Scaffold that may sit on a backdrop: clear on
  /// one, so the colour shows through, and the theme's own elsewhere (the
  /// same screen opened as a page of its own).
  static Color? scaffoldColor(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BackdropScope>() == null
      ? null
      : Colors.transparent;

  @override
  State<AmbientBackdrop> createState() => _AmbientBackdropState();
}

class _BackdropScope extends InheritedWidget {
  const _BackdropScope({required super.child});
  @override
  bool updateShouldNotify(_BackdropScope old) => false;
}

class _AmbientBackdropState extends State<AmbientBackdrop> with AmbientState {
  @override
  void ambientChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colors = AmbientColors.of(context);
    return CustomPaint(
      painter: _AuroraPainter(
        ambient ? AmbientClock.instance : null,
        colors,
        widget.color ?? Theme.of(context).scaffoldBackgroundColor,
      ),
      // Its own layer, so the page above isn't painted again as the colour
      // moves.
      child: RepaintBoundary(child: _BackdropScope(child: widget.child)),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.clock, this.colors, this.background)
    : super(repaint: clock);

  /// Null where nothing moves: the lights rest where they are.
  final AmbientClock? clock;
  final AmbientColors colors;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final v = clock?.breath(const Duration(seconds: 26)) ?? 0.35;
    final w = size.width;
    final h = size.height;
    void blob(Color color, Offset center, double radius) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0, 1],
          ).createShader(rect),
      );
    }

    // Upper start, upper end, and a third low on the page.
    blob(
      colors.a,
      Offset(w * (-0.05 + 0.25 * v), h * (-0.02 + 0.08 * v)),
      w * (0.75 + 0.1 * v),
    );
    blob(
      colors.b,
      Offset(w * (1.05 - 0.3 * v), h * (0.1 + 0.12 * v)),
      w * (0.7 - 0.08 * v),
    );
    blob(
      colors.c,
      Offset(w * (0.3 + 0.35 * v), h * (0.95 - 0.15 * v)),
      w * (0.8 + 0.12 * v),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.colors != colors ||
      old.background != background ||
      old.clock != clock;
}

/// Motes of light rising slowly, like the fireflies around Lucid Saga's
/// gate, in TaskFlow's green. For a few open screens: signing in, an empty
/// day.
class Motes extends StatefulWidget {
  const Motes({super.key, this.count = 18, this.color});
  final int count;
  final Color? color;

  @override
  State<Motes> createState() => _MotesState();
}

class _MotesState extends State<Motes> with AmbientState {
  @override
  void ambientChanged() => setState(() {});

  // Each mote: where it starts across, its own speed, size and phase.
  late final List<(double, double, double, double)> _motes = () {
    final random = math.Random(7);
    return List.generate(
      widget.count,
      (_) => (
        random.nextDouble(),
        0.6 + random.nextDouble() * 1.4,
        1.2 + random.nextDouble() * 2.2,
        random.nextDouble(),
      ),
    );
  }();

  @override
  Widget build(BuildContext context) {
    if (!ambient) return const SizedBox.expand();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _MotesPainter(
              AmbientClock.instance,
              _motes,
              widget.color ?? AmbientColors.of(context).mote,
            ),
          ),
        ),
      ),
    );
  }
}

class _MotesPainter extends CustomPainter {
  _MotesPainter(this.clock, this.motes, this.color) : super(repaint: clock);
  final AmbientClock clock;
  final List<(double, double, double, double)> motes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cycle = clock.phase(const Duration(seconds: 40));
    for (final (x, speed, radius, phase) in motes) {
      // Rises the whole height [speed] times a cycle, wavering sideways.
      final p = (cycle * speed + phase) % 1;
      final y = size.height * (1.05 - p * 1.1);
      final dx = math.sin((p + phase) * math.pi * 4) * 10;
      final flicker =
          0.35 + 0.65 * math.pow(math.sin((p * 9 + phase) * math.pi), 2);
      // Fades in from the bottom and out near the top.
      final fade = math.min(1.0, math.min(p / 0.15, (1 - p) / 0.3));
      final alpha = (flicker * fade).clamp(0.0, 1.0);
      final center = Offset(size.width * x + dx, y);
      final r = radius * 4;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.55 * alpha),
              color.withValues(alpha: 0.18 * alpha),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.35, 1],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_MotesPainter old) => old.color != color;
}

/// A band of light that crosses [child] every [period], like the glint on
/// Lucid Saga's Play badge. Clipped to [radius]; never takes a tap.
class Glint extends StatefulWidget {
  const Glint({
    super.key,
    required this.child,
    this.radius = 18,
    this.period = const Duration(seconds: 7),
    this.opacity = 0.32,
  });
  final Widget child;
  final double radius;
  final Duration period;
  final double opacity;

  @override
  State<Glint> createState() => _GlintState();
}

class _GlintState extends State<Glint>
    with SingleTickerProviderStateMixin, AmbientState {
  late final _cross = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  Timer? _timer;

  @override
  void ambientChanged() {
    _timer?.cancel();
    _timer = null;
    if (!ambient) {
      _cross.value = 0;
      return;
    }
    // The light crosses now and then: first a little after it appears.
    _timer = Timer(widget.period * 0.4, () {
      _sweep();
      _timer = Timer.periodic(widget.period, (_) => _sweep());
    });
  }

  void _sweep() {
    if (mounted && ambient) _cross.forward(from: 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cross.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    // As wide and tall as the child is let be.
    fit: StackFit.passthrough,
    children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: CustomPaint(painter: _GlintPainter(_cross, widget.opacity)),
          ),
        ),
      ),
    ],
  );
}

class _GlintPainter extends CustomPainter {
  _GlintPainter(this.t, this.opacity) : super(repaint: t);
  final Animation<double> t;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (t.value <= 0 || t.value >= 1) return;
    final p = Curves.easeInOutCubic.transform(t.value);
    final band = math.max(size.height * 1.2, 36.0);
    final x = -band * 2 + (size.width + band * 3) * p;
    final rect = Rect.fromLTWH(x, -size.height, band, size.height * 3);
    canvas.save();
    canvas.translate(rect.center.dx, size.height / 2);
    canvas.rotate(0.32);
    canvas.translate(-rect.center.dx, -size.height / 2);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: opacity),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlintPainter old) => old.opacity != opacity;
}

/// The app's main tap, alive: a soft glow breathes around it and a light
/// crosses it now and then, so the one button that adds a task is the one
/// that draws the eye. [child] is the button itself, untouched.
class LivelyButton extends StatefulWidget {
  const LivelyButton({super.key, required this.child, this.radius = 18});
  final Widget child;
  final double radius;

  @override
  State<LivelyButton> createState() => _LivelyButtonState();
}

class _LivelyButtonState extends State<LivelyButton> with AmbientState {
  @override
  void ambientChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glint = Glint(
      radius: widget.radius,
      opacity: dark ? 0.16 : 0.26,
      child: widget.child,
    );
    Widget glow(double v) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(
              alpha: (dark ? 0.18 : 0.22) + 0.14 * v,
            ),
            blurRadius: 18 + 10 * v,
            spreadRadius: -4 + 2 * v,
            offset: const Offset(0, 8),
          ),
        ],
      ),
    );
    // The glow is its own layer under the button, so only it is painted as
    // it breathes.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: ambient
                ? ListenableBuilder(
                    listenable: AmbientClock.instance,
                    builder: (context, _) => glow(
                      AmbientClock.instance.breath(
                        const Duration(milliseconds: 2800),
                      ),
                    ),
                  )
                : glow(0.5),
          ),
        ),
        glint,
      ],
    );
  }
}

/// TaskFlow's mark: the double tick on a green tile that shades into the
/// site's lime, with the light crossing it now and then.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 30});
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = size / 3;
    return Glint(
      radius: radius,
      period: const Duration(seconds: 9),
      opacity: dark ? 0.35 : 0.45,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [colors.primary, const Color(0xFFD4ECA3)]
                : [colors.primary, const Color(0xFF2E9A78)],
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: dark ? 0.18 : 0.22),
              blurRadius: 12,
              spreadRadius: -3,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.done_all_rounded,
          size: size * 0.66,
          color: colors.onPrimary,
        ),
      ),
    );
  }
}

/// Floats [child] gently up and down, like the website's phone and note.
class Floating extends StatefulWidget {
  const Floating({super.key, required this.child, this.distance = 5});
  final Widget child;
  final double distance;

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating> with AmbientState {
  @override
  void ambientChanged() => setState(() {});

  // Each tile floats on its own beat.
  late final double _offset = identityHashCode(this) % 100 / 100;

  @override
  Widget build(BuildContext context) {
    if (!ambient) return widget.child;
    return ListenableBuilder(
      listenable: AmbientClock.instance,
      child: widget.child,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          (AmbientClock.instance.breath(
                    const Duration(milliseconds: 3400),
                    _offset,
                  ) -
                  0.5) *
              2 *
              widget.distance,
        ),
        child: child,
      ),
    );
  }
}

/// Rings rippling out from behind the microphone while it listens, wider
/// as the voice gets louder; a slow breath while it waits.
class VoiceRipples extends StatefulWidget {
  const VoiceRipples({
    super.key,
    required this.level,
    required this.active,
    required this.color,
  });

  /// The voice's loudness, 0 to 1.
  final double level;
  final bool active;
  final Color color;

  @override
  State<VoiceRipples> createState() => _VoiceRipplesState();
}

class _VoiceRipplesState extends State<VoiceRipples>
    with SingleTickerProviderStateMixin {
  late final _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(VoiceRipples old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final on = widget.active && AppMotion.of(context);
    if (on && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!on && _loop.isAnimating) {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active || !AppMotion.of(context)) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.level),
        duration: const Duration(milliseconds: 180),
        builder: (context, level, _) =>
            CustomPaint(painter: _RipplePainter(_loop, level, widget.color)),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.t, this.level, this.color) : super(repaint: t);
  final Animation<double> t;
  final double level;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.shortestSide / 2;
    // A halo that swells with the voice.
    canvas.drawCircle(
      center,
      base * (1.05 + 0.35 * level),
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.16 + 0.18 * level),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: base * 1.6)),
    );
    // Three rings, a third of a cycle apart.
    for (var i = 0; i < 3; i++) {
      final p = (t.value + i / 3) % 1;
      final radius = base * (1 + p * (0.55 + 0.6 * level));
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: (1 - p) * (0.25 + 0.35 * level)),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.level != level || old.color != color;
}

/// A small burst where a task is ticked: a ring and a few sparks in the
/// app's green and lime, drawn over everything so it shows even when the
/// row leaves the list at once.
abstract final class CheckBurst {
  static void play(BuildContext context) {
    if (!AppMotion.of(context)) return;
    final box = context.findRenderObject();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (box is! RenderBox || !box.hasSize || overlay == null) return;
    final overlayBox = overlay.context.findRenderObject();
    if (overlayBox is! RenderBox) return;
    final center = box.localToGlobal(
      box.size.center(Offset.zero),
      ancestor: overlayBox,
    );
    final colors = Theme.of(context).colorScheme;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Burst(
        center: center,
        primary: colors.primary,
        accent: const Color(0xFFA9D66F),
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _Burst extends StatefulWidget {
  const _Burst({
    required this.center,
    required this.primary,
    required this.accent,
    required this.onDone,
  });
  final Offset center;
  final Color primary;
  final Color accent;
  final VoidCallback onDone;

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: Size.infinite,
      painter: _BurstPainter(
        _controller,
        widget.center,
        widget.primary,
        widget.accent,
      ),
    ),
  );
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.center, this.primary, this.accent)
    : super(repaint: t);
  final Animation<double> t;
  final Offset center;
  final Color primary;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final p = AppMotion.ease.transform(t.value);
    final fade = 1 - Curves.easeIn.transform(t.value);
    canvas.drawCircle(
      center,
      12 + 18 * p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * fade + 0.5
        ..color = primary.withValues(alpha: 0.55 * fade),
    );
    const sparks = 8;
    for (var i = 0; i < sparks; i++) {
      final angle = i * 2 * math.pi / sparks + 0.3;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final from = center + direction * (14 + 10 * p);
      final to = center + direction * (18 + 20 * p);
      canvas.drawLine(
        from,
        to,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.5
          ..color = (i.isEven ? primary : accent).withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => false;
}
