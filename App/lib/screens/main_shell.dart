import 'dart:async';
import 'dart:math' as math;

import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/app_update_provider.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/shell_tab_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/screens/settings_screen.dart';
import 'package:agenda/screens/notes_screen.dart';
import 'package:agenda/services/app_update.dart';
import 'package:agenda/services/meeting_controller.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/theme/motion.dart';
import 'package:agenda/widgets/ambient.dart';
import 'package:agenda/widgets/app_update_dialog.dart';
import 'package:agenda/widgets/note_task.dart';

// Mirrors Flutter's private `_kMaxLabelTextScaleFactor` in
// material/navigation_bar.dart: NavigationBar never scales a label past 1.3x.
const _flutterLabelScaleCap = 1.3;

// Below 360 dp the tab labels stop growing at 1.2x instead.
const _narrowLabelScaleCap = 1.2;

// The theme's tab label size (app_theme.dart).
const _labelFontSize = 12.0;

// The largest label scale, from [cap] down to 1.0x, at which the widest of
// [labels] in [styles] fits on one line in [width]. Below 1.0x it never goes.
double _fittingLabelScale({
  required List<String> labels,
  required List<TextStyle> styles,
  required double width,
  required double cap,
  required TextDirection textDirection,
  required Locale locale,
}) {
  double widest(double scale) {
    var result = 0.0;
    for (final style in styles) {
      for (final label in labels) {
        final painter = TextPainter(
          text: TextSpan(
            text: label,
            style: style.copyWith(fontSize: _labelFontSize * scale),
          ),
          textDirection: textDirection,
          locale: locale,
          maxLines: 1,
        )..layout();
        result = math.max(result, painter.width);
        painter.dispose();
      }
    }
    return result;
  }

  var scale = cap;
  final measured = widest(scale);
  if (scale <= 1 || measured <= width) return scale;
  // Glyph widths grow about linearly with the font size: start there, then
  // step down until the widest label fits.
  scale = math.max(1, (scale * width / measured * 100).floorToDouble() / 100);
  while (scale > 1 && widest(scale) > width) {
    scale = math.max(1, scale - 0.01);
  }
  return scale;
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});
  final int initialIndex;
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  late int _index = widget.initialIndex;

  /// A tab that comes forward rises a little into place and fades in, on
  /// the website's curve (AppMotion). It starts settled.
  late final AnimationController _arrive = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );
  late final CurvedAnimation _arriving = CurvedAnimation(
    parent: _arrive,
    curve: AppMotion.ease,
  );

  /// Only the private staging app updates itself (app_update.dart).
  late final bool _updates = ref.read(appUpdaterProvider) != null;
  AppLifecycleListener? _lifecycle;
  StreamSubscription<AppInstallResult>? _installs;
  final _offered = <int>{};
  bool _offering = false;

  @override
  void initState() {
    super.initState();
    if (!_updates) return;
    _lifecycle = AppLifecycleListener(onResume: _checkUpdate);
    // An install that didn't go through is offered again.
    _installs = ref
        .read(appUpdaterProvider)!
        .installResults
        .listen((_) => _offered.clear());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  @override
  void dispose() {
    _arriving.dispose();
    _arrive.dispose();
    _lifecycle?.dispose();
    _installs?.cancel();
    super.dispose();
  }

  void _checkUpdate() {
    if (!mounted) return;
    unawaited(ref.read(appUpdateProvider.notifier).check());
    unawaited(_offerUpdate());
  }

  /// Offers a newer build once per build, on these tabs and never while a
  /// meeting is recording: installing closes the app.
  Future<void> _offerUpdate() async {
    final update = ref.read(appUpdateProvider);
    if (!mounted ||
        _offering ||
        update == null ||
        _offered.contains(update.versionCode) ||
        ref.read(meetingRecordingProvider) != null ||
        !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    _offering = true;
    _offered.add(update.versionCode);
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => AppUpdateDialog(update: update),
      );
    } finally {
      _offering = false;
    }
  }

  void _select(int index) {
    if (index != _index) {
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(shellTabSwitchesProvider.notifier).state++;
    }
    if (index != _index && AppMotion.of(context)) _arrive.forward(from: 0);
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    // Read the notes' «Crear tarea» links and this phone's meeting notes
    // before any note's page opens, so its main button shows the right
    // label from the start (R1-P318-1, UX-2903).
    ref.listen(noteTasksProvider, (_, _) {});
    ref.listen(meetingNotesProvider, (_, _) {});
    // Tasks go to the phone's calendar while «Add my tasks to my calendar»
    // is on.
    ref.listen(calendarExportProvider, (_, _) {});
    if (_updates) {
      ref.listen(appUpdateProvider, (_, _) => _offerUpdate());
      ref.listen(meetingRecordingProvider, (_, recording) {
        if (recording == null) _offerUpdate();
      });
    }
    // Tasks saved from the pending list land on Calendar.
    ref.listen<CalendarFocus?>(calendarFocusProvider, (_, focus) {
      if (focus?.showCalendar == true && _index != 0) {
        setState(() => _index = 0);
      }
    });
    // Four tabs are too narrow for long words at Flutter's 1.3x label cap:
    // «Calendario» below 360 dp, and the Catalan «Configuració» even at 360
    // and 393 dp. So only the label stops growing: at 1.2x below 360 dp, and
    // at any width at the largest scale at which the widest label still fits
    // on one line, never below 1.0x. Its font size shrinks so that Flutter's
    // own cap lands there. The bar keeps the phone's text scaling, so the
    // long-press tooltips still follow the phone's text size. Stopgap until
    // the bar has fewer tabs (U13).
    final labels = [
      context.l10n.calendar,
      context.l10n.tasks,
      context.l10n.notes,
      context.l10n.settings,
    ];
    WidgetStateProperty<TextStyle?>? labelTextStyle;
    final themed = NavigationBarTheme.of(context).labelTextStyle;
    final selectedStyle = themed?.resolve({WidgetState.selected});
    final unselectedStyle = themed?.resolve(<WidgetState>{});
    if (selectedStyle != null && unselectedStyle != null) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      final padding = MediaQuery.paddingOf(context);
      final scale =
          MediaQuery.textScalerOf(context).scale(_labelFontSize) /
          _labelFontSize;
      final flutterScale = math.min(scale, _flutterLabelScaleCap);
      // The bar's Material draws its labels over bodyMedium.
      final base = Theme.of(context).textTheme.bodyMedium;
      final labelScale = _fittingLabelScale(
        labels: labels,
        styles: [
          base?.merge(selectedStyle) ?? selectedStyle,
          base?.merge(unselectedStyle) ?? unselectedStyle,
        ],
        width: (screenWidth - padding.left - padding.right) / labels.length,
        cap: screenWidth < 360
            ? math.min(scale, _narrowLabelScaleCap)
            : flutterScale,
        textDirection: Directionality.of(context),
        locale: Localizations.localeOf(context),
      );
      if (labelScale < flutterScale) {
        final fontSize = _labelFontSize * labelScale / flutterScale;
        labelTextStyle = WidgetStateProperty.resolveWith(
          (states) => themed?.resolve(states)?.copyWith(fontSize: fontSize),
        );
      }
    }
    final navigationBar = NavigationBar(
      labelTextStyle: labelTextStyle,
      selectedIndex: _index,
      onDestinationSelected: _select,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.calendar_month_outlined),
          selectedIcon: const Icon(Icons.calendar_month),
          label: labels[0],
        ),
        NavigationDestination(
          icon: const Icon(Icons.check_box_outlined),
          selectedIcon: const Icon(Icons.check_box),
          label: labels[1],
        ),
        NavigationDestination(
          icon: const Icon(Icons.description_outlined),
          selectedIcon: const Icon(Icons.description),
          label: labels[2],
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: labels[3],
        ),
      ],
    );
    // Back on another tab returns to Calendar; Back on Calendar leaves.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      // The tabs sit on slow drifting colour (ambient.dart), which also
      // shows round the bar's top corners.
      child: AmbientBackdrop(
        child: Column(
          children: [
            Expanded(
              // Each tab owns its Scaffold so feedback sits above its capture
              // controls. The navigation bar below consumes the bottom safe
              // area.
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: AnimatedBuilder(
                  animation: _arriving,
                  builder: (context, child) {
                    final t = _arriving.value;
                    if (t >= 1) return child!;
                    return Opacity(
                      opacity: 0.4 + 0.6 * t,
                      alwaysIncludeSemantics: true,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - t)),
                        child: child,
                      ),
                    );
                  },
                  child: IndexedStack(
                    index: _index,
                    children: [
                      for (final (index, screen) in const [
                        CalendarScreen(),
                        HomeScreen(),
                        NotesScreen(),
                        SettingsScreen(),
                      ].indexed)
                        HeroMode(enabled: index == _index, child: screen),
                    ],
                  ),
                ),
              ),
            ),
            _RoundedBar(child: navigationBar),
          ],
        ),
      ),
    );
  }
}

/// The tab bar as the page's base: full width, its top corners rounded like
/// the capture sheet's, lifted by a soft shadow rather than a ruled line, so
/// it stays a base and Añadir tarea above stays the one pill.
class _RoundedBar extends StatelessWidget {
  const _RoundedBar({required this.child});
  final Widget child;

  static const radius = BorderRadius.vertical(top: Radius.circular(28));

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.35)
                : Lagoon.accent.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }
}
