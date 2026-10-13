import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/screens/settings_screen.dart';
import 'package:agenda/screens/notes_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});
  final int initialIndex;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;
  @override
  Widget build(BuildContext context) => Column(
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
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() => _index = index),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.calendar_today_outlined),
              selectedIcon: const Icon(Icons.calendar_month_rounded),
              label: context.l10n.calendar,
            ),
            NavigationDestination(
              icon: const Icon(Icons.checklist_rounded),
              selectedIcon: const Icon(Icons.checklist_rounded),
              label: context.l10n.tasks,
            ),
            NavigationDestination(
              icon: const Icon(Icons.notes_rounded),
              selectedIcon: const Icon(Icons.description_rounded),
              label: context.l10n.notes,
            ),
            NavigationDestination(
              icon: const Icon(Icons.tune_rounded),
              selectedIcon: const Icon(Icons.tune_rounded),
              label: context.l10n.settings,
            ),
          ],
        ),
      ),
    ],
  );
}
