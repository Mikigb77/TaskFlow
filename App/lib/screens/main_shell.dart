import 'dart:math' as math;

import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/screens/settings_screen.dart';
import 'package:agenda/screens/notes_screen.dart';

// Mirrors Flutter's private `_kMaxLabelTextScaleFactor` in
// material/navigation_bar.dart: NavigationBar never scales a label past 1.3x.
const _flutterLabelScaleCap = 1.3;

// Below 360 dp the tab labels stop growing at 1.2x instead.
const _narrowLabelScaleCap = 1.2;

// The theme's tab label size (app_theme.dart).
const _labelFontSize = 12.0;

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});
  final int initialIndex;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;
  @override
  Widget build(BuildContext context) {
    // Below 360 dp four tabs are too narrow for long words such as
    // "Calendario" at Flutter's 1.3x label cap, so only the label stops at
    // 1.2x: its font size shrinks so that Flutter's own cap lands on 1.2x. The
    // bar keeps the phone's text scaling, so the long-press tooltips still
    // follow the phone's text size. Stopgap until the bar has fewer tabs.
    WidgetStateProperty<TextStyle?>? labelTextStyle;
    if (MediaQuery.sizeOf(context).width < 360) {
      final scale =
          MediaQuery.textScalerOf(context).scale(_labelFontSize) /
          _labelFontSize;
      final fontSize =
          _labelFontSize *
          math.min(scale, _narrowLabelScaleCap) /
          math.min(scale, _flutterLabelScaleCap);
      final themed = NavigationBarTheme.of(context).labelTextStyle;
      labelTextStyle = WidgetStateProperty.resolveWith(
        (states) => themed?.resolve(states)?.copyWith(fontSize: fontSize),
      );
    }
    final navigationBar = NavigationBar(
      labelTextStyle: labelTextStyle,
      selectedIndex: _index,
      onDestinationSelected: (index) => setState(() => _index = index),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.calendar_month_outlined),
          selectedIcon: const Icon(Icons.calendar_month),
          label: context.l10n.calendar,
        ),
        NavigationDestination(
          icon: const Icon(Icons.check_box_outlined),
          selectedIcon: const Icon(Icons.check_box),
          label: context.l10n.tasks,
        ),
        NavigationDestination(
          icon: const Icon(Icons.description_outlined),
          selectedIcon: const Icon(Icons.description),
          label: context.l10n.notes,
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: context.l10n.settings,
        ),
      ],
    );
    return Column(
      children: [
        Expanded(
          // Each tab owns its Scaffold so feedback sits above its capture
          // controls. The navigation bar below consumes the bottom safe area.
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
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
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: navigationBar,
        ),
      ],
    );
  }
}
