import 'dart:convert';
import 'dart:io';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/regional_settings_screen.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:agenda/widgets/task_schedule_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_calendar/table_calendar.dart';
import 'support/design_fixtures.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/widgets/language_selector.dart';
import 'package:agenda/widgets/app_components.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          (_) async => 'UTC',
        );
  });
  for (final sample in [
    (
      const Locale('en', 'US'),
      StartingDayOfWeek.sunday,
      TimeOfDayFormat.h_colon_mm_space_a,
      'Today’s agenda',
    ),
    (
      const Locale('en', 'GB'),
      StartingDayOfWeek.monday,
      TimeOfDayFormat.HH_colon_mm,
      'Today’s agenda',
    ),
    (
      const Locale('es', 'ES'),
      StartingDayOfWeek.monday,
      TimeOfDayFormat.H_colon_mm,
      'Agenda de hoy',
    ),
    (
      const Locale('ca', 'ES'),
      StartingDayOfWeek.monday,
      TimeOfDayFormat.HH_colon_mm,
      'L’agenda d’avui',
    ),
  ]) {
    testWidgets('device defaults follow ${sample.$1}', (tester) async {
      tester.platformDispatcher.localesTestValue = [sample.$1];
      tester.platformDispatcher.alwaysUse24HourFormatTestValue =
          sample.$1.countryCode != 'US';
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
      final container = designContainer(
        regionalStore: MemoryRegionalStore(const RegionalPreferences()),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      final calendar = tester.widget<TableCalendar<Task>>(
        find.byType(TableCalendar<Task>),
      );
      expect(calendar.startingDayOfWeek, sample.$2);
      final context = tester.element(find.byType(CalendarScreen));
      expect(MaterialLocalizations.of(context).timeOfDayFormat(), sample.$3);
      expect(find.text(sample.$4), findsOneWidget);
      final dateOnly = Task(
        title: 'Date',
        priority: 1,
        dueDate: DateTime(2026, 9, 25),
        hasTime: false,
      );
      expect(
        taskScheduleLabel(dateOnly, context: context),
        contains(context.l10n.anyTime),
      );
      final midnight = dateOnly.copyWith(hasTime: true);
      expect(
        taskScheduleLabel(midnight, context: context),
        isNot(contains(context.l10n.anyTime)),
      );
      if (sample.$1.countryCode == 'GB') {
        tester.platformDispatcher.alwaysUse24HourFormatTestValue = false;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(
          MaterialLocalizations.of(context).timeOfDayFormat(),
          TimeOfDayFormat.h_colon_mm_space_a,
        );
        expect(container.read(regionalProvider).clock, ClockFormat.system);
        expect(
          context.clockTime(DateTime(2026, 9, 25, 18, 45)),
          contains('6:45'),
        );
      }
    });
  }

  testWidgets(
    'changing UI language and clock keeps the open editor and date, with consistent pickers',
    (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('es', 'ES')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final container = designContainer(
        regionalStore: MemoryRegionalStore(
          const RegionalPreferences(language: 'en'),
        ),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => TaskEditor(
            task: Task(
              id: 99,
              title: 'Do not translate my words',
              priority: 1,
              dueDate: DateTime(2205, 2, 3, 18, 45),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final controller = container.read(regionalProvider.notifier);
      await controller.set(
        const RegionalPreferences(
          language: 'es',
          clock: ClockFormat.twelve,
          weekStart: 0,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Editar tarea'), findsOneWidget);
      expect(find.text('Do not translate my words'), findsOneWidget);
      final context = tester.element(find.byType(TaskEditor));
      expect(context.clockTime(DateTime(2205, 2, 3, 18, 45)), contains('6:45'));
      expect(MaterialLocalizations.of(context).firstDayOfWeekIndex, 0);
      final time = find.byKey(const ValueKey('task-date'));
      await tester.ensureVisible(time);
      await tester.pumpAndSettle();
      await tester.tap(time);
      await tester.pumpAndSettle();
      final picker = find.byKey(const ValueKey('schedule-hour'));
      expect(tester.widget<TextFormField>(picker).controller!.text, '6');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('schedule-minute')),
            )
            .controller!
            .text,
        '45',
      );
      expect(
        MaterialLocalizations.of(tester.element(picker)).timeOfDayFormat(),
        TimeOfDayFormat.h_colon_mm_space_a,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await controller.set(
        const RegionalPreferences(
          language: 'en',
          clock: ClockFormat.twentyFour,
          weekStart: 6,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('18:45'), findsOneWidget);
      expect(find.text('Edit task'), findsOneWidget);
      final date = find.byKey(const ValueKey('task-date'));
      await tester.ensureVisible(date);
      await tester.pumpAndSettle();
      await tester.tap(date);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
            .initialDate,
        DateTime(2205, 2, 3),
      );
      expect(
        MaterialLocalizations.of(
          tester.element(find.byType(CalendarDatePicker)),
        ).firstDayOfWeekIndex,
        6,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'Spanish regional settings at 2x text remain usable in $theme',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final store = MemoryRegionalStore(
          const RegionalPreferences(language: 'es'),
        );
        final container = designContainer(regionalStore: store);
        addTearDown(container.dispose);
        await container.read(themeModeProvider.notifier).setMode(theme);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const MyApp()),
        );
        await tester.pumpAndSettle();
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .pushNamed('/region');
        await tester.pumpAndSettle();
        expect(find.byType(RegionalSettingsScreen), findsOneWidget);
        expect(find.text('Hora y región'), findsOneWidget);
        final clock = find.byKey(const ValueKey('regional-clock'));
        await tester.scrollUntilVisible(
          clock,
          160,
          scrollable: find
              .descendant(
                of: find.byType(RegionalSettingsScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(clock);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reloj de 12 horas').last);
        await tester.pumpAndSettle();
        expect(store.value.clock, ClockFormat.twelve);
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- P18 (UX-422, UX-431): Hora y región ----

  final es = lookupAppLocalizations(const Locale('es'));

  /// Hora y región in Spanish; [zone] is the stored time zone, if any.
  Future<MemoryRegionalStore> openRegion(
    WidgetTester tester, {
    String? zone,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryRegionalStore(
      RegionalPreferences(language: 'es', captureTimezone: zone),
    );
    final container = designContainer(regionalStore: store);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/region');
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> openZones(WidgetTester tester) async {
    final row = find.widgetWithText(ListTile, es.timeZone);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(
      find.widgetWithText(TextField, es.searchTimezone),
      query,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'UX-422: the screen is titled Hora y región, has no language picker, labels Zona horaria and shows a stored zone as its city',
    (tester) async {
      expect(es.timeZone, 'Zona horaria');
      await openRegion(tester, zone: 'America/Argentina/Buenos_Aires');
      final page = find.byType(RegionalSettingsScreen);
      expect(
        find.descendant(
          of: find.descendant(of: page, matching: find.byType(AppBar)),
          matching: find.text(es.regionalFormats),
        ),
        findsOneWidget,
      );
      expect(find.text('Idioma y región'), findsNothing);
      expect(
        find.descendant(of: page, matching: find.byType(LanguageSelector)),
        findsNothing,
      );
      expect(
        find.descendant(of: page, matching: find.text(es.language)),
        findsNothing,
      );
      expect(find.textContaining('de captura'), findsNothing);
      final row = find.widgetWithText(ListTile, es.timeZone);
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('Buenos Aires')),
        findsOneWidget,
      );
      expect(find.text('America/Argentina/Buenos_Aires'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-422: with no zone chosen it reads Como el teléfono; the list shows Buenos Aires for America/Argentina/Buenos_Aires and stores the id',
    (tester) async {
      final store = await openRegion(tester);
      final row = find.widgetWithText(ListTile, es.timeZone);
      expect(
        find.descendant(of: row, matching: find.text(es.deviceDefault)),
        findsOneWidget,
      );
      await openZones(tester);
      await search(tester, 'Buenos');
      final city = find.widgetWithText(ListTile, 'Buenos Aires');
      expect(city, findsWidgets);
      expect(find.textContaining('_'), findsNothing);
      expect(find.textContaining('America/'), findsNothing);
      await tester.tap(city.first);
      await tester.pumpAndSettle();
      expect(store.value.captureTimezone, endsWith('Buenos_Aires'));
      expect(store.value.captureTimezone, startsWith('America/'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-431: in the time-zone list, typing Bogotá lists Bogota and typing mexico city lists Mexico City',
    (tester) async {
      await openRegion(tester);
      await openZones(tester);
      await search(tester, 'Bogotá');
      expect(find.widgetWithText(ListTile, 'Bogota'), findsOneWidget);
      await search(tester, 'mexico city');
      expect(find.widgetWithText(ListTile, 'Mexico City'), findsOneWidget);
      await search(tester, 'México');
      expect(find.widgetWithText(ListTile, 'Mexico City'), findsOneWidget);
      // The continent in the id still finds its cities.
      await search(tester, 'America');
      expect(find.widgetWithText(ListTile, 'Adak'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P79 (UX-486): Spanish and Catalan city names; no legacy duplicates ----

  testWidgets(
    'UX-486: searching Londres, Nueva York and Nova York, with or without accents and capitals, lists the matching zone',
    (tester) async {
      final store = await openRegion(tester);
      await openZones(tester);
      for (final (query, city) in [
        ('Londres', 'London'),
        ('londres', 'London'),
        ('Nueva York', 'New York'),
        ('NUEVA YORK', 'New York'),
        ('Nova York', 'New York'),
        ('nova york', 'New York'),
        // Accent folding on the alias names.
        ('Sídney', 'Sydney'),
        ('sidney', 'Sydney'),
        ('Ciudad de México', 'Mexico City'),
        ('ciutat de mexic', 'Mexico City'),
        ('Moscú', 'Moscow'),
        ('moscu', 'Moscow'),
      ]) {
        await search(tester, query);
        expect(
          find.widgetWithText(ListTile, city),
          findsOneWidget,
          reason: query,
        );
      }
      // The row's title is still the tz city (P86 adds the matched name as
      // its subtitle), and choosing it stores the id.
      await search(tester, 'Londres');
      final london = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'London'),
      );
      expect((london.title! as Text).data, 'London');
      await tester.tap(find.widgetWithText(ListTile, 'London'));
      await tester.pumpAndSettle();
      expect(store.value.captureTimezone, 'Europe/London');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-486: the list has no US/* or Canada/* duplicates: Pacific, Eastern, Central and Mountain aren’t listed, and Los Angeles and Toronto are listed once',
    (tester) async {
      // The tz database does hold the legacy names the list must hide.
      expect(
        CaptureTimezone.identifiers,
        containsAll(['US/Pacific', 'US/Eastern', 'Canada/Eastern']),
      );
      await openRegion(tester);
      await openZones(tester);
      for (final legacy in ['Pacific', 'Eastern', 'Central', 'Mountain']) {
        await search(tester, legacy);
        expect(
          find.widgetWithText(ListTile, legacy),
          findsNothing,
          reason: legacy,
        );
      }
      for (final city in ['Los Angeles', 'Toronto', 'New York']) {
        await search(tester, city);
        expect(
          find.widgetWithText(ListTile, city),
          findsOneWidget,
          reason: city,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final legacy in ['US/Pacific', 'Canada/Eastern']) {
    testWidgets(
      'UX-486: an account whose stored zone is the legacy $legacy still sees it as the current zone',
      (tester) async {
        final city = legacy.split('/').last;
        final store = await openRegion(tester, zone: legacy);
        expect(store.value.captureTimezone, legacy);
        final row = find.widgetWithText(ListTile, es.timeZone);
        expect(
          find.descendant(of: row, matching: find.text(city)),
          findsOneWidget,
        );
        // Not replaced by a fallback warning.
        expect(find.byType(MessageBanner), findsNothing);
        expect(
          find.descendant(of: row, matching: find.text(es.deviceDefault)),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('UX-486: regionalSettingsHelp is gone from the three ARB files', () {
    for (final language in ['en', 'es', 'ca']) {
      final catalog =
          jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
              as Map<String, dynamic>;
      expect(catalog.containsKey('regionalSettingsHelp'), isFalse);
      expect(catalog.containsKey('@regionalSettingsHelp'), isFalse);
    }
  });

  // ---- P75 (UX-422): time-zone help without capture jargon ----

  testWidgets(
    'UX-422: Hora y región says Las tareas nuevas usan esta zona para entender las fechas. and no visible text contains captura',
    (tester) async {
      expect(
        es.timezoneHelp,
        'Las tareas nuevas usan esta zona para entender las fechas.',
      );
      await openRegion(tester);
      final page = find.byType(RegionalSettingsScreen);
      expect(
        find.descendant(of: page, matching: find.text(es.timezoneHelp)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: page,
          matching: find.textContaining(RegExp('captur', caseSensitive: false)),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-422: with the phone’s zone unreadable, the banner reads No se puede obtener la zona del dispositivo. Las tareas nuevas usarán …',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter_timezone'),
            (_) async => 'Not/AZone',
          );
      await openRegion(tester);
      final page = find.byType(RegionalSettingsScreen);
      const start =
          'No se puede obtener la zona del dispositivo. Las tareas nuevas usarán ';
      final banner = find.descendant(
        of: page,
        matching: find.textContaining(start),
      );
      expect(banner, findsOneWidget);
      expect(
        find.descendant(
          of: page,
          matching: find.textContaining(RegExp('captur', caseSensitive: false)),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'UX-422: timezoneHelp and timezoneFallback say no captura / capture in any language',
    () {
      final en = lookupAppLocalizations(const Locale('en'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(en.timezoneHelp, 'New tasks use this time zone to read dates.');
      expect(
        ca.timezoneHelp,
        'Les tasques noves fan servir aquest fus horari per entendre les dates.',
      );
      expect(
        en.timezoneFallback('Madrid'),
        'The device timezone is unavailable. New tasks will use Madrid.',
      );
      expect(
        es.timezoneFallback('Madrid'),
        'No se puede obtener la zona del dispositivo. Las tareas nuevas usarán Madrid.',
      );
      expect(
        ca.timezoneFallback('Madrid'),
        'El fus horari del dispositiu no està disponible. Les tasques noves utilitzaran Madrid.',
      );
      for (final strings in [en, es, ca]) {
        for (final text in [
          strings.timezoneHelp,
          strings.timezoneFallback('Madrid'),
        ]) {
          expect(text.toLowerCase().contains('captur'), isFalse, reason: text);
        }
      }
    },
  );
  testWidgets('UX-422: the language sheet has no explanatory paragraph', (
    tester,
  ) async {
    await openRegion(tester);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(es.settings),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, es.language));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    final words = tester
        .widgetList<Text>(
          find.descendant(of: sheet, matching: find.byType(Text)),
        )
        .map((text) => text.data ?? '')
        .where((text) => text.split(' ').length > 12)
        .toList();
    expect(words, isEmpty, reason: 'long text in the sheet: $words');
    expect(find.textContaining('preferencias del teléfono'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  // ---- P86 (UX-489): the time-zone search shows which name matched ----

  /// The rows the time-zone search lists, as (title, subtitle).
  List<(String, String?)> zoneRows(WidgetTester tester) => [
    for (final tile in tester.widgetList<ListTile>(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(ListTile),
      ),
    ))
      ((tile.title! as Text).data!, (tile.subtitle as Text?)?.data),
  ];

  testWidgets(
    'UX-489: in Spanish, searching pekin lists one row, Shanghai, with the subtitle Pekín',
    (tester) async {
      await openRegion(tester);
      await openZones(tester);
      await search(tester, 'pekin');
      expect(zoneRows(tester), [('Shanghai', 'Pekín')]);
      final row = find.widgetWithText(ListTile, 'Shanghai');
      expect(
        find.descendant(of: row, matching: find.text('Pekín')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-489: searching montreal lists exactly one row, Montreal, with no subtitle',
    (tester) async {
      await openRegion(tester);
      await openZones(tester);
      await search(tester, 'montreal');
      expect(zoneRows(tester), [('Montreal', null)]);
      expect(find.widgetWithText(ListTile, 'Toronto'), findsNothing);
      // Toronto itself is still found by its own name.
      await search(tester, 'toronto');
      expect(zoneRows(tester), [('Toronto', null)]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-489: searching Londres lists London with the subtitle Londres; searching london lists London with no subtitle',
    (tester) async {
      await openRegion(tester);
      await openZones(tester);
      await search(tester, 'Londres');
      expect(zoneRows(tester), contains(('London', 'Londres')));
      expect(zoneRows(tester).where((row) => row.$1 == 'London'), hasLength(1));
      await search(tester, 'london');
      expect(zoneRows(tester), contains(('London', null)));
      expect(zoneRows(tester).where((row) => row.$1 == 'London'), hasLength(1));
      // An empty search lists every zone by its title only.
      await search(tester, '');
      expect(zoneRows(tester), isNotEmpty);
      expect(zoneRows(tester).every((row) => row.$2 == null), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-489: in Catalan at 2× text on 360×740, searching Nova Delhi lists Kolkata with the subtitle Nova Delhi, without overflow',
    (tester) async {
      final ca = lookupAppLocalizations(const Locale('ca'));
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = designContainer(
        regionalStore: MemoryRegionalStore(
          const RegionalPreferences(language: 'ca'),
        ),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/region');
      await tester.pumpAndSettle();
      final zoneRow = find.widgetWithText(ListTile, ca.timeZone);
      await tester.scrollUntilVisible(
        zoneRow,
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(zoneRow);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, ca.searchTimezone),
        'Nova Delhi',
      );
      await tester.pumpAndSettle();
      expect(zoneRows(tester), [('Kolkata', 'Nova Delhi')]);
      final row = find.widgetWithText(ListTile, 'Kolkata');
      final subtitle = find.descendant(
        of: row,
        matching: find.text('Nova Delhi'),
      );
      expect(subtitle, findsOneWidget);
      for (final part in [row, subtitle]) {
        final rect = tester.getRect(part);
        expect(rect.left, greaterThanOrEqualTo(-0.5));
        expect(rect.right, lessThanOrEqualTo(360.5));
        expect(rect.bottom, lessThanOrEqualTo(740.5));
      }
      expect(tester.takeException(), isNull);
    },
  );
}
