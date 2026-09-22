import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/device_calendars_screen.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:agenda/widgets/device_calendar_events.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'device_calendar_test.dart'
    show FakeDeviceCalendars, MemoryCalendarPreferences, workCalendar;
import 'support/design_fixtures.dart';

void main() {
  testWidgets(
      'calendar permission and selection controls fit small screens and large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final language in ['en', 'es']) {
      for (final dark in [false, true]) {
        final bridge = FakeDeviceCalendars()..access = CalendarAccess.denied;
        final container = ProviderContainer(overrides: [
          deviceCalendarsProvider.overrideWithValue(bridge),
          calendarPreferenceStoreProvider
              .overrideWithValue(MemoryCalendarPreferences()),
          themeStoreProvider
              .overrideWithValue(MemoryThemeStore(dark ? 'dark' : 'light')),
        ]);
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
                locale: Locale(language),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                theme: dark ? AppTheme.dark : AppTheme.light,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!),
                home: const DeviceCalendarsScreen())));
        await tester.pumpAndSettle();
        expect(bridge.permissionRequests, 0);
        await tester.scrollUntilVisible(
            find.byKey(const ValueKey('calendar-connect')), 220);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('calendar-connect')));
        await tester.pumpAndSettle();
        expect(bridge.permissionRequests, 1);
        await tester.scrollUntilVisible(
            find.byKey(const ValueKey('device-calendar-1')), 220);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('device-calendar-1')));
        await tester.pumpAndSettle();
        expect(container.read(deviceCalendarProvider).preferences.selected,
            {workCalendar.selectionKey});
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        bridge.close();
      }
    }
  });

  testWidgets(
      'a visible event sheet loses its contents when calendar access is revoked',
      (tester) async {
    final bridge = FakeDeviceCalendars();
    final container = ProviderContainer(overrides: [
      deviceCalendarsProvider.overrideWithValue(bridge),
      calendarPreferenceStoreProvider.overrideWithValue(
          MemoryCalendarPreferences(CalendarPreferences(
              enabled: true, selected: {workCalendar.selectionKey}))),
    ]);
    addTearDown(() {
      container.dispose();
      bridge.close();
    });
    await container.read(deviceCalendarProvider.notifier).ready;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            home: Scaffold(
                body: DeviceCalendarEvents(day: DateTime(2026, 9, 22))))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar appointment'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Open in calendar app'), findsOneWidget);
    bridge.access = CalendarAccess.denied;
    await container.read(deviceCalendarProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.text('Calendar appointment'), findsNothing);
    expect(find.text('Open in calendar app'), findsNothing);
    expect(
        find.text(
            'This event is no longer available in the selected calendars.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
