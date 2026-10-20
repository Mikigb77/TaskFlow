import 'dart:io';
import 'package:flutter/services.dart';
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
    show
        FakeDeviceCalendars,
        MemoryCalendarPreferences,
        homeCalendar,
        workCalendar;
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
        // Connecting ticked both; unticking one keeps the other (D7).
        expect(container.read(deviceCalendarProvider).preferences.selected,
            {homeCalendar.selectionKey});
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
    await tester.tap(find.byKey(const ValueKey('calendar-events-line')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar appointment'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNWidgets(2));
    expect(find.text('Open in calendar app'), findsOneWidget);
    bridge.access = CalendarAccess.denied;
    await container.read(deviceCalendarProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.text('Calendar appointment'), findsNothing);
    expect(find.text('Open in calendar app'), findsNothing);
    expect(
        find.text(
            'This event is no longer available in the selected calendars.'),
        findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // ---- Run 2026-10-19-app, round 1 · P179 (UX-1421) ----

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
        'UX-1421: the phone events sheet’s rows don’t say «Evento del calendario · solo lectura» ($language)',
        (tester) async {
      final l = lookupAppLocalizations(Locale(language));
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
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                  body: DeviceCalendarEvents(day: DateTime(2026, 9, 22))))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('calendar-events-line')));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      final row = find.descendant(
          of: sheet, matching: find.widgetWithText(ListTile, 'Calendar appointment'));
      expect(row, findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.textContaining(l.calendarReadOnly)),
          findsNothing);
      expect(find.textContaining('solo lectura'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // ---- Run 2026-10-19-app · P188 (UX-1611): phone calendars in few words ----

  group('P188', () {
    setUpAll(() async {
      await (FontLoader('Manrope')
            ..addFont(rootBundle.load('assets/fonts/Manrope.ttf')))
          .load();
    });

    test('UX-1611: the three lines read as planned in EN, ES and CA', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final es = lookupAppLocalizations(const Locale('es'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(en.deviceCalendarIntro,
          'You’ll see your phone’s events in Calendar. They’re only read here, never uploaded.');
      expect(es.deviceCalendarIntro,
          'Verás los eventos de tu teléfono en Calendario. Solo se leen aquí; no se suben.');
      expect(ca.deviceCalendarIntro,
          'Veuràs els esdeveniments del telèfon a Calendari. Només es llegeixen aquí; no es pugen.');
      expect(en.calendarRefused,
          'Without permission, TaskFlow can’t see your events.');
      expect(es.calendarRefused,
          'Sin permiso, TaskFlow no puede ver tus eventos.');
      expect(ca.calendarRefused,
          'Sense permís, TaskFlow no pot veure els esdeveniments.');
      expect(en.calendarConnected, 'Connected. Events show in Calendar.');
      expect(es.calendarConnected,
          'Conectado. Los eventos se ven en Calendario.');
      expect(ca.calendarConnected,
          'Connectat. Els esdeveniments es veuen a Calendari.');
    });

    Future<ProviderContainer> openScreen(
      WidgetTester tester,
      DeviceCalendars bridge, {
      String language = 'es',
      bool large = true,
    }) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [
        deviceCalendarsProvider.overrideWithValue(bridge),
        calendarPreferenceStoreProvider
            .overrideWithValue(MemoryCalendarPreferences()),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(large ? 2 : 1)),
                  child: child!),
              home: const DeviceCalendarsScreen())));
      await tester.pumpAndSettle();
      return container;
    }

    Finder inScreen(Finder finder) => find.descendant(
        of: find.byType(ListView), matching: finder, skipOffstage: false);

    testWidgets(
        'UX-1611: ES, 2× on 360×800, before access: Conectar calendarios del teléfono is above the fold, under one line of at most 15 words, with no Actualizar calendarios',
        (tester) async {
      final es = lookupAppLocalizations(const Locale('es'));
      final bridge = FakeDeviceCalendars()..access = CalendarAccess.denied;
      addTearDown(bridge.close);
      await openScreen(tester, bridge);
      final button = find.byKey(const ValueKey('calendar-connect'));
      expect(button, findsOneWidget);
      expect(find.descendant(of: button, matching: find.text(es.calendarEnable)),
          findsOneWidget);
      final rect = tester.getRect(button);
      expect(rect.bottom, lessThanOrEqualTo(800));
      expect(rect.top, greaterThanOrEqualTo(0));
      final above = tester
          .widgetList<Text>(inScreen(find.byType(Text)))
          .where((text) =>
              tester.getRect(find.byWidget(text)).bottom <= rect.top + 0.5)
          .toList();
      expect(above, hasLength(1), reason: 'one line above the button');
      final words = (above.single.data ?? '')
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      expect(words, lessThanOrEqualTo(15));
      expect(above.single.data, es.deviceCalendarIntro);
      expect(find.text(es.calendarRefresh, skipOffstage: false), findsNothing);
      expect(find.text(es.calendarDisable, skipOffstage: false), findsNothing);
      expect(bridge.permissionRequests, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'UX-1611: after a refusal, Sin permiso, TaskFlow no puede ver tus eventos. shows, with the button',
        (tester) async {
      final es = lookupAppLocalizations(const Locale('es'));
      final bridge = _RefusingCalendars();
      addTearDown(bridge.close);
      await openScreen(tester, bridge);
      expect(find.text(es.calendarRefused), findsNothing);
      await tester.tap(find.byKey(const ValueKey('calendar-connect')));
      await tester.pumpAndSettle();
      expect(bridge.permissionRequests, 1);
      expect(find.text(es.calendarRefused), findsOneWidget);
      expect(find.text(es.deviceCalendarIntro), findsNothing);
      expect(find.byKey(const ValueKey('calendar-connect')), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('calendar-connect')),
              matching: find.text(es.calendarEnable)),
          findsOneWidget);
      expect(find.text(es.calendarRefresh, skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final language in ['es', 'en', 'ca']) {
      testWidgets(
          'UX-1611: after allowing ($language): the first line reads Conectado. Los eventos se ven en Calendario., every calendar is ticked, Actualizar calendarios shows, Ocultar eventos del calendario is a TextButton below the list, and Calendar shows the events',
          (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        final bridge = FakeDeviceCalendars()..access = CalendarAccess.denied;
        addTearDown(bridge.close);
        final container =
            await openScreen(tester, bridge, language: language, large: false);
        await tester.tap(find.byKey(const ValueKey('calendar-connect')));
        await tester.pumpAndSettle();
        expect(bridge.permissionRequests, 1);
        // The first thing on the screen is the connected line.
        final texts =
            tester.widgetList<Text>(inScreen(find.byType(Text))).toList();
        final first = texts
            .map((t) => (t, tester.getRect(find.byWidget(t)).top))
            .reduce((a, b) => a.$2 <= b.$2 ? a : b);
        expect(first.$1.data, l.calendarConnected);
        expect(find.byKey(const ValueKey('calendar-connect')), findsNothing);
        // Every listed calendar is ticked.
        for (final calendar in [workCalendar, homeCalendar]) {
          final tile = find.byKey(ValueKey('device-calendar-${calendar.id}'),
              skipOffstage: false);
          expect(tile, findsOneWidget);
          expect(tester.widget<CheckboxListTile>(tile).value, isTrue,
              reason: calendar.name);
        }
        expect(container.read(deviceCalendarProvider).showing, isTrue);
        // Refresh shows once access is granted.
        expect(
            find.text(l.calendarRefresh, skipOffstage: false), findsOneWidget);
        // The off switch is a plain TextButton, below every calendar.
        final disable =
            find.byKey(const ValueKey('calendar-disable'), skipOffstage: false);
        expect(disable, findsOneWidget);
        expect(tester.widget(disable), isA<TextButton>());
        expect(
            find.descendant(
                of: disable, matching: find.text(l.calendarDisable)),
            findsOneWidget);
        final lastCalendar = tester.getRect(find.byKey(
            const ValueKey('device-calendar-2'),
            skipOffstage: false));
        expect(tester.getRect(disable).top,
            greaterThanOrEqualTo(lastCalendar.bottom));
        // It isn't the first control.
        final controls = [
          ...tester.widgetList(inScreen(find.byType(CheckboxListTile))),
          ...tester.widgetList(
              inScreen(find.byWidgetPredicate((w) => w is ButtonStyleButton))),
        ];
        final firstControl = controls
            .map((w) => (w, tester.getRect(find.byWidget(w)).top))
            .reduce((a, b) => a.$2 <= b.$2 ? a : b);
        expect(identical(firstControl.$1, tester.widget(disable)), isFalse);
        expect(tester.takeException(), isNull);

        // Calendar shows the phone's events at once.
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
                locale: Locale(language),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: Scaffold(
                    body: DeviceCalendarEvents(day: DateTime(2026, 9, 22))))));
        await tester.pumpAndSettle();
        final line = find.byKey(const ValueKey('calendar-events-line'));
        expect(line, findsOneWidget);
        expect(
            find.descendant(
                of: line,
                matching: find.textContaining(l.calendarEventCount(1))),
            findsOneWidget);
        expect(find.text(l.calendarNoSelection), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    // ---- Run 2026-10-19-app · P217 (UX-1651): one button under the calendars ----

    test('UX-1651: no catalog contains calendarClear', () {
      for (final language in ['en', 'es', 'ca']) {
        final arb = File('lib/l10n/app_$language.arb').readAsStringSync();
        expect(arb, isNot(contains('"calendarClear"')), reason: language);
        expect(arb, isNot(contains('"@calendarClear"')), reason: language);
      }
      final generated =
          File('lib/l10n/generated/app_localizations.dart').readAsStringSync();
      expect(generated, isNot(contains('calendarClear')));
    });

    for (final large in [false, true]) {
      testWidgets(
          'UX-1651: ES ${large ? '2×' : '1×'} on 360×800, every calendar ticked: below the list only Ocultar eventos del calendario (TextButton) and Actualizar calendarios (outlined); Borrar selección in no state',
          (tester) async {
        final es = lookupAppLocalizations(const Locale('es'));
        const removed = 'Borrar selección';
        final bridge = FakeDeviceCalendars()..access = CalendarAccess.denied;
        addTearDown(bridge.close);
        await openScreen(tester, bridge, large: large);
        expect(find.text(removed, skipOffstage: false), findsNothing,
            reason: 'before access');
        await tester.tap(find.byKey(const ValueKey('calendar-connect')));
        await tester.pumpAndSettle();

        Future<void> expectTwoControlsBelow(String state) async {
          // At 2× the list builds lazily: bring its end in.
          await tester.scrollUntilVisible(
              find.byKey(const ValueKey('calendar-disable')), 200,
              scrollable: find
                  .descendant(
                      of: find.byType(ListView),
                      matching: find.byType(Scrollable))
                  .first);
          await tester.pumpAndSettle();
          final lastCalendar = tester.getRect(find.byKey(
              const ValueKey('device-calendar-2'),
              skipOffstage: false));
          final below = tester
              .widgetList<ButtonStyleButton>(inScreen(
                  find.byWidgetPredicate((w) => w is ButtonStyleButton)))
              .where((button) =>
                  tester.getRect(find.byWidget(button)).top >=
                  lastCalendar.bottom - 0.5)
              .toList();
          expect(below, hasLength(2), reason: state);
          final text = below.whereType<TextButton>().toList();
          expect(text, hasLength(1), reason: state);
          expect(text.single.key, const ValueKey('calendar-disable'),
              reason: state);
          expect(
              find.descendant(
                  of: find.byWidget(text.single),
                  matching: find.text(es.calendarDisable),
                  skipOffstage: false),
              findsOneWidget,
              reason: state);
          final outlined = below.whereType<OutlinedButton>().toList();
          expect(outlined, hasLength(1), reason: state);
          expect(
              find.descendant(
                  of: find.byWidget(outlined.single),
                  matching: find.text(es.calendarRefresh),
                  skipOffstage: false),
              findsOneWidget,
              reason: state);
          expect(find.text(removed, skipOffstage: false), findsNothing,
              reason: state);
        }

        for (final calendar in [workCalendar, homeCalendar]) {
          expect(
              tester
                  .widget<CheckboxListTile>(find.byKey(
                      ValueKey('device-calendar-${calendar.id}'),
                      skipOffstage: false))
                  .value,
              isTrue,
              reason: calendar.name);
        }
        await expectTwoControlsBelow('every calendar ticked');

        // Untick one, then the other: still no Borrar selección.
        for (final calendar in [workCalendar, homeCalendar]) {
          final tile = find.byKey(ValueKey('device-calendar-${calendar.id}'),
              skipOffstage: false);
          await tester.ensureVisible(tile);
          await tester.pumpAndSettle();
          await tester.tap(tile);
          await tester.pumpAndSettle();
          expect(tester.widget<CheckboxListTile>(tile).value, isFalse,
              reason: calendar.name);
          await expectTwoControlsBelow('${calendar.name} unticked');
        }
        expect(tester.takeException(), isNull);
      });
    }

  });
}

/// P188: the phone answers «No permitir».
class _RefusingCalendars extends FakeDeviceCalendars {
  _RefusingCalendars() {
    access = CalendarAccess.denied;
  }
  @override
  Future<CalendarAccess> status({bool request = false}) async {
    if (request) permissionRequests++;
    return access;
  }
}
