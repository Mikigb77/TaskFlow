import 'package:flutter/material.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/screens/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});
  final int initialIndex;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
            index: _index,
            children: const [CalendarScreen(), HomeScreen(), SettingsScreen()]),
        bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant))),
            child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (index) =>
                    setState(() => _index = index),
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.calendar_today_outlined),
                      selectedIcon: Icon(Icons.calendar_month_rounded),
                      label: 'Calendar'),
                  NavigationDestination(
                      icon: Icon(Icons.checklist_rounded),
                      selectedIcon: Icon(Icons.checklist_rounded),
                      label: 'Tasks'),
                  NavigationDestination(
                      icon: Icon(Icons.tune_rounded),
                      selectedIcon: Icon(Icons.tune_rounded),
                      label: 'Settings'),
                ])),
      );
}
