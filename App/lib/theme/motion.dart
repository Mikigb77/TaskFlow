import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// TaskFlow's motion: the one soft curve of the website and garbar.tech, and
/// the rule for when the app moves on its own.
///
/// Two kinds of movement:
/// - **Entrances** play once, when something first appears: it rises a little
///   and fades in (`Rise`), or a tab slides into place.
/// - **Ambient** movement keeps going while it's on screen: the colour
///   drifting behind the tabs, the glow breathing around «Añadir tarea», the
///   light that crosses the brand mark.
///
/// Both stand still when the phone asks for less motion (Android's «Remove
/// animations»), and under `flutter test`, where a loop never settles and
/// an entrance would leave a widget half drawn in a preview. A test that
/// wants to see the motion sets [debugForce].
abstract final class AppMotion {
  /// The site's `cubic-bezier(0.22, 1, 0.36, 1)`: quick to start, long and
  /// soft to land.
  static const ease = Cubic(0.22, 1, 0.36, 1);

  /// Entrances: how long a rise takes, and the gap between staggered items.
  static const rise = Duration(milliseconds: 700);
  static const stagger = Duration(milliseconds: 70);

  /// Overrides the test check, so a test can play the motion.
  static bool? debugForce;

  static final bool _testing = () {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }();

  /// Whether the app moves here: false when the phone asks for less motion.
  static bool of(BuildContext context) {
    if (debugForce case final forced?) {
      return forced && !MediaQuery.disableAnimationsOf(context);
    }
    return !_testing && !MediaQuery.disableAnimationsOf(context);
  }
}

/// Rises [offset] logical pixels and fades in the first time it is built,
/// after [index] staggers. Where the app stands still, [child] is simply
/// there. Its semantics are there from the first frame, so TalkBack never
/// waits for it.
class Rise extends StatefulWidget {
  const Rise({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 18,
    this.duration = AppMotion.rise,
  });
  final Widget child;
  final int index;
  final double offset;
  final Duration duration;

  @override
  State<Rise> createState() => _RiseState();
}

class _RiseState extends State<Rise> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late final bool _animate = AppMotion.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_animate || _controller != null) return;
    final delay = AppMotion.stagger * widget.index;
    final total = delay + widget.duration;
    final controller = _controller = AnimationController(
      vsync: this,
      duration: total,
    );
    _curve = CurvedAnimation(
      parent: controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: AppMotion.ease,
      ),
    );
    controller.forward();
  }

  CurvedAnimation? _curve;

  @override
  void dispose() {
    _curve?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = _curve;
    if (curve == null) return widget.child;
    return AnimatedBuilder(
      animation: curve,
      child: widget.child,
      builder: (context, child) {
        final t = curve.value;
        if (t >= 1) return child!;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          alwaysIncludeSemantics: true,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.offset),
            child: child,
          ),
        );
      },
    );
  }
}

/// The clock behind the ambient details. One timer for the whole app, at
/// 20 frames a second rather than the screen's 60 or 120: the drifting
/// colour, the breathing glow and the floating tiles move slowly, and so a
/// phone left on Calendar barely works for them. It runs only while some
/// detail is on screen and the app is in front.
class AmbientClock extends ChangeNotifier with WidgetsBindingObserver {
  AmbientClock._();
  static final instance = AmbientClock._();

  static const _interval = Duration(milliseconds: 50);
  final _watch = Stopwatch();
  Timer? _timer;
  int _users = 0;
  bool _resumed = true;

  /// Seconds the clock has run.
  double get seconds => _watch.elapsedMicroseconds / 1e6;

  /// Where a cycle of [period] is now, from 0 to 1, shifted by [offset].
  double phase(Duration period, [double offset = 0]) =>
      (seconds / (period.inMicroseconds / 1e6) + offset) % 1;

  /// A breath through a cycle of [period]: 0 to 1 and back, eased.
  double breath(Duration period, [double offset = 0]) =>
      0.5 - 0.5 * math.cos(2 * math.pi * phase(period, offset));

  void attach() {
    if (_users++ == 0) {
      WidgetsBinding.instance.addObserver(this);
      final state = WidgetsBinding.instance.lifecycleState;
      _resumed = state == null || state == AppLifecycleState.resumed;
      _sync();
    }
  }

  void detach() {
    if (--_users == 0) {
      WidgetsBinding.instance.removeObserver(this);
      _sync();
    }
  }

  void _sync() {
    final run = _users > 0 && _resumed;
    if (run && _timer == null) {
      _watch.start();
      _timer = Timer.periodic(_interval, (_) => notifyListeners());
    } else if (!run && _timer != null) {
      _timer!.cancel();
      _timer = null;
      _watch.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _sync();
  }
}

/// For an ambient detail: [ambient] is true while it should move (the app
/// moves, and its page is the one in front), and the shared clock runs for
/// it only then.
mixin AmbientState<T extends StatefulWidget> on State<T> {
  bool ambient = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final on = AppMotion.of(context) && TickerMode.valuesOf(context).enabled;
    if (on == ambient) return;
    ambient = on;
    on ? AmbientClock.instance.attach() : AmbientClock.instance.detach();
    ambientChanged();
  }

  /// Called when [ambient] changes.
  void ambientChanged() {}

  @override
  void dispose() {
    if (ambient) AmbientClock.instance.detach();
    super.dispose();
  }
}
