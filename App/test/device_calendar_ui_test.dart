import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/device_calendar_event.dart';
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
        calendarEvent,
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
    // The event's row on Calendar opens it.
    await tester.tap(find.textContaining('Calendar appointment · '));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Calendar appointment'), findsOneWidget);
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
      // Four events: the fourth row opens the sheet with every event.
      final bridge = FakeDeviceCalendars()
        ..data = [for (var i = 0; i < 4; i++) calendarEvent(id: '${10 + i}')];
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
      await tester.tap(find.byKey(const ValueKey('calendar-events-all')));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      final row = find.descendant(
          of: sheet, matching: find.widgetWithText(ListTile, 'Calendar appointment'));
      expect(row, findsNWidgets(4));
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
        // By name.
        expect(find.textContaining('Calendar appointment · '), findsOneWidget);
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

  // ---- Run 2026-10-28-app, round 1 · P277 (UX-2306, UX-2310): phone events
  // by name, sheets that end with «Cerrar», read errors you can retry ----

  group('P277 · phone events by name', () {
    final day = DateTime(2026, 9, 22);

    DeviceCalendarEvent event(int i, String title, int hour,
            {bool allDay = false}) =>
        DeviceCalendarEvent(
            id: '${40 + i}',
            calendarId: workCalendar.id,
            title: title,
            start: allDay
                ? DateTime.utc(day.year, day.month, day.day)
                : DateTime(day.year, day.month, day.day, hour),
            end: allDay
                ? DateTime.utc(day.year, day.month, day.day + 1)
                : DateTime(day.year, day.month, day.day, hour, 30),
            allDay: allDay);

    /// [DeviceCalendarEvents] for [day] with [events], on a 360×800 view.
    Future<AppLocalizations> pumpEvents(
        WidgetTester tester, List<DeviceCalendarEvent> events,
        {String language = 'es', double scale = 1}) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final bridge = FakeDeviceCalendars()..data = events;
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
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: Scaffold(
                  body: SingleChildScrollView(
                      child: DeviceCalendarEvents(day: day))))));
      await tester.pumpAndSettle();
      return lookupAppLocalizations(Locale(language));
    }

    final sheet = find.byType(BottomSheet);
    Finder inSheet(Finder finder) =>
        find.descendant(of: sheet, matching: finder);
    final all = find.byKey(const ValueKey('calendar-events-all'));

    const seeAllFive = {
      'es': 'Ver los 5 eventos',
      'en': 'See all 5 events',
      'ca': 'Mostra els 5 esdeveniments',
    };
    for (final language in ['es', 'en', 'ca']) {
      testWidgets(
          'UX-2306: with five events three rows show by name, then «${seeAllFive[language]}», which opens every event ($language)',
          (tester) async {
        final titles = [
          'Reunión de equipo',
          'Cita con el dentista',
          'Clase de yoga',
          'Cena con Ana',
          'Llamada con Pau',
        ];
        final l = await pumpEvents(tester, [
          for (final (i, title) in titles.indexed) event(i, title, 9 + 2 * i),
        ], language: language);
        expect(l.calendarSeeAllEvents(5), seeAllFive[language]);
        final context = tester.element(find.byType(DeviceCalendarEvents));
        for (final (i, title) in titles.indexed) {
          final row = find.text(
              '$title · ${context.clockTime(DateTime(2026, 9, 22, 9 + 2 * i))}');
          expect(row, i < 3 ? findsOneWidget : findsNothing, reason: title);
        }
        // No other trace of the fourth and fifth events.
        expect(find.textContaining('Cena con Ana'), findsNothing);
        expect(find.textContaining('Llamada con Pau'), findsNothing);
        expect(all, findsOneWidget);
        expect(find.descendant(of: all, matching: find.text(seeAllFive[language]!)),
            findsOneWidget);
        // The fourth row comes after the three events.
        final third = find.textContaining('Clase de yoga · ');
        expect(tester.getRect(all).top,
            greaterThanOrEqualTo(tester.getRect(third).bottom));
        expect(tester.getSize(all).height, greaterThanOrEqualTo(48));
        await tester.tap(all);
        await tester.pumpAndSettle();
        expect(sheet, findsOneWidget);
        for (final title in titles) {
          expect(inSheet(find.text(title)), findsOneWidget, reason: title);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'UX-2306: with three events there is no «Ver los N eventos» row and no count line',
        (tester) async {
      await pumpEvents(tester, [
        event(0, 'Reunión de equipo', 10),
        event(1, 'Cita con el dentista', 17),
        event(2, 'Clase de yoga', 19),
      ]);
      expect(find.textContaining(' · '), findsNWidgets(3));
      expect(all, findsNothing);
      expect(find.byKey(const ValueKey('calendar-events-line')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final language in ['es', 'en', 'ca']) {
      testWidgets(
          'UX-2306: an all-day event’s row reads «{title} · ${lookupAppLocalizations(Locale(language)).calendarAllDay}» ($language)',
          (tester) async {
        final l = await pumpEvents(tester, [
          event(0, 'Cumpleaños de Marta', 0, allDay: true),
        ], language: language);
        if (language == 'es') expect(l.calendarAllDay, 'Todo el día');
        final row = find.text('Cumpleaños de Marta · ${l.calendarAllDay}');
        expect(row, findsOneWidget);
        // The row opens the event.
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(inSheet(find.text('Cumpleaños de Marta')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'UX-2306: event rows are events, not tasks: no circle, no checkbox and no swipe',
        (tester) async {
      await pumpEvents(tester, [
        event(0, 'Reunión de equipo', 10),
        event(1, 'Cita con el dentista', 17),
      ]);
      final rows = find.byType(DeviceCalendarEvents);
      for (final type in [Dismissible, Checkbox, Radio<Object?>]) {
        expect(find.descendant(of: rows, matching: find.byType(type)),
            findsNothing,
            reason: '$type');
      }
      expect(
          find.descendant(
              of: rows, matching: find.byIcon(Icons.circle_outlined)),
          findsNothing);
      expect(
          find.descendant(
              of: rows,
              matching: find.byIcon(Icons.radio_button_unchecked_rounded)),
          findsNothing);
      // Swiping a row does nothing: it stays.
      final row = find.textContaining('Reunión de equipo · ');
      await tester.drag(row, const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      expect(sheet, findsNothing);
      expect(tester.takeException(), isNull);
    });

    /// «Cerrar» is the sheet's last thing,
    /// right at its bottom, under everything else in it.
    void expectEndsWithClose(WidgetTester tester, AppLocalizations l) {
      final close = inSheet(find.widgetWithText(TextButton, l.close));
      expect(close, findsOneWidget);
      expect(close.hitTestable(), findsOneWidget, reason: 'on screen');
      final closeRect = tester.getRect(close);
      final sheetRect = tester.getRect(sheet);
      expect(sheetRect.bottom - closeRect.bottom, lessThanOrEqualTo(16.5),
          reason: '«${l.close}» ends the sheet');
      // What scrolls ends above it, so nothing shows under «Cerrar».
      final scroll = inSheet(find.byType(Scrollable)).first;
      expect(tester.getRect(scroll).bottom,
          lessThanOrEqualTo(closeRect.top + 0.5),
          reason: 'the sheet’s content sits above «${l.close}»');
    }

    /// The sheet's own content under its drag handle: never past three
    /// quarters of the 800 dp screen, as before.
    double contentHeight(WidgetTester tester) =>
        tester.getSize(inSheet(find.byType(SafeArea)).first).height;

    /// The sheet's scroll view: whether it has more than it shows.
    ScrollPosition sheetScroll(WidgetTester tester) => tester
        .state<ScrollableState>(inSheet(find.byType(Scrollable)).first)
        .position;

    for (final language in ['es', 'en', 'ca']) {
      testWidgets(
          'UX-2306: an event’s sheet fits its content and ends with «${lookupAppLocalizations(Locale(language)).close}», which closes it ($language)',
          (tester) async {
        final l = await pumpEvents(tester, [
          event(0, 'Reunión de equipo', 10),
          event(1, 'Cita con el dentista', 17),
        ], language: language);
        await tester.tap(find.textContaining('Cita con el dentista · '));
        await tester.pumpAndSettle();
        expect(sheet, findsOneWidget);
        expect(inSheet(find.text('Cita con el dentista')), findsOneWidget);
        expect(inSheet(find.text('Reunión de equipo')), findsNothing);
        expect(inSheet(find.text(l.calendarOpenEvent)), findsOneWidget);
        expectEndsWithClose(tester, l);
        expect(sheetScroll(tester).maxScrollExtent, 0);
        expect(contentHeight(tester), lessThan(800 * .75),
            reason: 'as tall as its content, not three quarters');
        await tester.tap(inSheet(find.widgetWithText(TextButton, l.close)));
        await tester.pumpAndSettle();
        expect(sheet, findsNothing);
        // Calendar's rows are still there.
        expect(find.textContaining('Cita con el dentista · '), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'UX-2306: at ${scale}x the list sheet with four events is no taller than its rows and «Cerrar», which closes it',
          (tester) async {
        final l = await pumpEvents(
            tester,
            [
              for (final (i, title) in [
                'Reunión de equipo',
                'Cita con el dentista',
                'Clase de yoga',
                'Cena con Ana',
              ].indexed)
                event(i, title, 9 + 2 * i),
            ],
            scale: scale);
        await tester.tap(all);
        await tester.pumpAndSettle();
        expect(sheet, findsOneWidget);
        expectEndsWithClose(tester, l);
        expect(contentHeight(tester), lessThanOrEqualTo(800 * .75 + 0.5),
            reason: 'never past three quarters');
        final scroll = sheetScroll(tester);
        if (scroll.maxScrollExtent == 0) {
          // Everything fits: no empty space under the last row.
          final lastRow = inSheet(find.widgetWithText(ListTile, 'Cena con Ana'));
          final close = inSheet(find.widgetWithText(TextButton, l.close));
          expect(
              tester.getRect(close).top - tester.getRect(lastRow).bottom,
              lessThanOrEqualTo(16.5),
              reason: 'the sheet ends right after its rows');
        } else {
          // Capped at three quarters, scrolling, with «Cerrar» still in view.
          expect(contentHeight(tester), closeTo(800 * .75, 0.5));
        }
        await tester.tap(inSheet(find.widgetWithText(TextButton, l.close)));
        await tester.pumpAndSettle();
        expect(sheet, findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'UX-2306: with twelve events the list sheet stops at three quarters of the screen, scrolls, and keeps «Cerrar» in view',
        (tester) async {
      final l = await pumpEvents(tester, [
        for (var i = 0; i < 12; i++) event(i, 'Evento $i', 8 + i),
      ]);
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(contentHeight(tester), lessThanOrEqualTo(800 * .75 + 0.5));
      expect(sheetScroll(tester).maxScrollExtent, greaterThan(0));
      final close = inSheet(find.widgetWithText(TextButton, l.close));
      expect(close.hitTestable(), findsOneWidget);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(tester.takeException(), isNull);
    });

    test(
        'UX-2310: no calendarReadError key in the three catalogs, and calendarSeeAllEvents in all three',
        () {
      const seeAll = {
        'es': 'Ver los {count} eventos',
        'en': 'See all {count} events',
        'ca': 'Mostra els {count} esdeveniments',
      };
      const retry = {
        'es': 'No se pudieron leer los eventos. Toca para reintentar.',
        'en': 'Couldn’t read your events. Tap to try again.',
        'ca':
            'No s’han pogut llegir els esdeveniments. Toca per tornar-ho a provar.',
      };
      for (final language in ['en', 'es', 'ca']) {
        final catalog = jsonDecode(
                File('lib/l10n/app_$language.arb').readAsStringSync())
            as Map<String, dynamic>;
        expect(catalog.containsKey('calendarReadError'), isFalse,
            reason: language);
        expect(catalog.containsKey('@calendarReadError'), isFalse,
            reason: language);
        expect(catalog['calendarSeeAllEvents'], seeAll[language],
            reason: language);
        expect(catalog['calendarReadRetry'], retry[language],
            reason: 'calendarReadRetry unchanged ($language)');
      }
    });
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
