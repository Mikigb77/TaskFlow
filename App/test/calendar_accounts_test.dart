// Phone calendars by account (2026-11-11): one tick per account, holidays,
// birthdays and other extras off and behind «More options» with readable
// names, and «Add my tasks to my calendar».
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/device_calendar_event.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/providers/no_retry.dart';
import 'package:agenda/screens/device_calendars_screen.dart';
import 'package:agenda/services/calendar_export.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/device_calendar_events.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'device_calendar_test.dart'
    show FakeDeviceCalendars, MemoryCalendarPreferences, calendarEvent;

const gmail = 'ana@example.invalid';
const work = 'ana@work.example.invalid';
const primaryCal = DeviceCalendar(
  id: '1',
  name: gmail,
  account: gmail,
  accountType: 'com.google',
  sourceId: gmail,
  primary: true,
);
const family = DeviceCalendar(
  id: '2',
  name: 'Family',
  account: gmail,
  accountType: 'com.google',
  sourceId: 'family@group.calendar.google.com',
);
const holidays = DeviceCalendar(
  id: '3',
  name: 'es.spain#holiday@group.v.calendar.google.com',
  account: gmail,
  accountType: 'com.google',
  sourceId: 'es.spain#holiday@group.v.calendar.google.com',
  writable: false,
);
const birthdays = DeviceCalendar(
  id: '4',
  name: 'Birthdays',
  account: gmail,
  accountType: 'com.google',
  sourceId: 'addressbook#contacts@group.v.calendar.google.com',
  writable: false,
);
const office = DeviceCalendar(
  id: '5',
  name: work,
  account: work,
  accountType: 'com.google',
  sourceId: work,
  primary: true,
);
const team = DeviceCalendar(
  id: '6',
  name: 'Team (read only)',
  account: work,
  accountType: 'com.google',
  sourceId: 'team@group.calendar.google.com',
  writable: false,
);
const phone = DeviceCalendar(
  id: '7',
  name: 'My calendar',
  account: 'My calendar',
  accountType: 'LOCAL',
);

FakeDeviceCalendars phoneWithAccounts() => FakeDeviceCalendars()
  ..access = CalendarAccess.denied
  ..sources = [primaryCal, family, holidays, birthdays, office, team, phone];

Task task(
  int id,
  String title,
  DateTime? day, {
  bool hasTime = true,
  String recurrence = 'none',
  int? duration,
}) => Task(
  id: id,
  title: title,
  dueDate: day,
  hasTime: hasTime,
  recurrence: recurrence,
  durationMinutes: duration,
  priority: 1,
);

class MemoryExportStore extends CalendarExportStore {
  MemoryExportStore() : super('fixture');
  Map<String, CalendarExportEntry> value = {};
  @override
  Future<Map<String, CalendarExportEntry>> read() async => {...value};
  @override
  Future<void> write(Map<String, CalendarExportEntry> entries) async =>
      value = {...entries};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final now = DateTime(2026, 9, 22, 9);

  group('what each calendar is', () {
    test('own calendars come with their account; the rest are extras', () {
      expect(primaryCal.kind, CalendarKind.own);
      expect(family.kind, CalendarKind.own);
      expect(holidays.kind, CalendarKind.holidays);
      expect(birthdays.kind, CalendarKind.birthdays);
      expect(team.kind, CalendarKind.other);
      expect(phone.kind, CalendarKind.own);
      expect(phone.onPhone, isTrue);
      expect(primaryCal.accountKey, family.accountKey);
      expect(primaryCal.accountKey, isNot(office.accountKey));
      // iOS names its own kinds.
      expect(
        const DeviceCalendar(
          id: 'b',
          name: 'Birthdays',
          type: 'birthdays',
        ).kind,
        CalendarKind.birthdays,
      );
      expect(
        const DeviceCalendar(
          id: 's',
          name: 'Spain Holidays',
          type: 'subscription',
        ).kind,
        CalendarKind.other,
      );
    });

    test('a name that is only an id reads as what the calendar holds', () {
      for (final language in ['en', 'es', 'ca']) {
        final l = lookupAppLocalizations(Locale(language));
        expect(calendarName(l, holidays), l.calendarHolidays);
        expect(calendarName(l, birthdays), 'Birthdays');
        expect(calendarName(l, family), 'Family');
        // The primaryCal calendar is named by its account.
        expect(calendarName(l, primaryCal), gmail);
        expect(calendarAccount(l, phone), l.calendarOnPhone);
        expect(
          calendarName(
            l,
            const DeviceCalendar(
              id: '9',
              name: '',
              sourceId:
                  'x#weeknum@group.v'
                  '.calendar.google.com',
              writable: false,
            ),
          ),
          l.calendarWeekNumbers,
        );
      }
      expect(
        lookupAppLocalizations(const Locale('en')).calendarHolidays,
        'Holidays',
      );
    });

    test('a choice saved per calendar keeps its accounts, without extras', () {
      final saved = CalendarPreferences.fromJson({
        'enabled': true,
        'selected': [
          primaryCal.selectionKey,
          holidays.selectionKey,
          office.selectionKey,
        ],
      });
      expect(saved.enabled, isTrue);
      expect(saved.accounts, {primaryCal.accountKey, office.accountKey});
      expect(saved.extras, isEmpty);
      expect(saved.exportAccounts, isEmpty);
      final again = CalendarPreferences.fromJson(
        saved
            .copyWith(
              extras: {holidays.selectionKey},
              exportAccounts: {office.accountKey},
            )
            .toJson(),
      );
      expect(again.accounts, saved.accounts);
      expect(again.extras, {holidays.selectionKey});
      expect(again.exportAccounts, {office.accountKey});
    });
  });

  group('choosing accounts', () {
    test(
      'connecting ticks every account; holidays and birthdays stay off',
      () async {
        final bridge = phoneWithAccounts()
          ..data = [
            calendarEvent(id: '10', calendar: '2'),
            calendarEvent(id: '11', calendar: '3', uid: 'holiday'),
          ];
        final controller = DeviceCalendarController(
          bridge,
          MemoryCalendarPreferences(),
        );
        await controller.ready;
        await controller.enable();
        final state = controller.state;
        expect(state.preferences.accounts, {
          primaryCal.accountKey,
          office.accountKey,
          phone.accountKey,
        });
        expect(state.preferences.extras, isEmpty);
        expect(state.shown.map((c) => c.id), ['1', '2', '5', '7']);
        expect(
          (await controller.events(DateTime(2026, 9, 22))).items
              .map((e) => e.id),
          ['10'],
        );
        await controller.selectExtra(holidays.selectionKey, true);
        expect(controller.state.shown.map((c) => c.id), contains('3'));
        expect(
          (await controller.events(DateTime(2026, 9, 22))).items,
          hasLength(2),
        );
        // Unticking an account hides all of its own calendars at once.
        await controller.selectAccount(primaryCal.accountKey, false);
        expect(controller.state.shown.map((c) => c.id), ['3', '5', '7']);
        await expectLater(
          controller.selectExtra(primaryCal.selectionKey, true),
          throwsStateError,
        );
        controller.dispose();
        bridge.close();
      },
    );

    test('tasks go to each ticked account’s main calendar, after the phone allows it', () async {
      final bridge = phoneWithAccounts();
      final controller = DeviceCalendarController(
        bridge,
        MemoryCalendarPreferences(),
      );
      await controller.ready;
      await controller.enable();
      expect(controller.state.preferences.exportAccounts, isEmpty);
      expect(controller.state.exportCalendars, isEmpty);
      expect(
        await controller.selectExportAccount(primaryCal.accountKey, true),
        isTrue,
      );
      expect(bridge.writeRequests, 1);
      expect(
        await controller.selectExportAccount(office.accountKey, true),
        isTrue,
      );
      expect(controller.state.exportCalendars, [primaryCal, office]);
      // Showing an account's events and adding tasks to it are separate.
      await controller.selectAccount(primaryCal.accountKey, false);
      expect(controller.state.exportCalendars, [primaryCal, office]);
      await controller.selectExportAccount(primaryCal.accountKey, false);
      expect(controller.state.exportCalendars, [office]);
      controller.dispose();
      bridge.close();
    });
  });

  group('adding tasks to the calendar', () {
    test('the plan: a task with a day from today, each day of a repeat for 30 days', () {
      final planned = CalendarExporter.plan(
        [
          task(1, 'Dentist', DateTime(2026, 9, 23, 10), duration: 45),
          task(2, 'Bread', DateTime(2026, 9, 22), hasTime: false),
          task(3, 'Yesterday', DateTime(2026, 9, 21, 10)),
          task(4, 'Someday', null),
          task(5, 'Walk', DateTime(2026, 9, 1, 8), recurrence: 'daily'),
          Task(id: 6, title: 'A note', kind: 'note', priority: 1),
          Task(
            id: 7,
            title: 'Someone else’s',
            dueDate: DateTime(2026, 9, 24, 9),
            assignment: 'member',
            assigneeId: 99,
            priority: 1,
          ),
        ],
        now,
        accountId: 1,
      );
      expect(
        planned.keys.where((k) => !k.contains('@')),
        unorderedEquals(['t:1', 't:2']),
      );
      final dentist = planned['t:1']!;
      expect(dentist.allDay, isFalse);
      expect(
        DateTime.fromMillisecondsSinceEpoch(dentist.start),
        DateTime(2026, 9, 23, 10),
      );
      expect(
        DateTime.fromMillisecondsSinceEpoch(dentist.end),
        DateTime(2026, 9, 23, 10, 45),
      );
      final bread = planned['t:2']!;
      expect(bread.allDay, isTrue);
      expect(bread.start, DateTime.utc(2026, 9, 22).millisecondsSinceEpoch);
      expect(bread.end, DateTime.utc(2026, 9, 23).millisecondsSinceEpoch);
      final walks = planned.keys.where((k) => k.startsWith('t:5@')).toList();
      expect(walks, hasLength(30));
      expect(walks, contains('t:5@2026-09-22'));
      expect(walks, isNot(contains('t:5@2026-09-21')));
      // A past task keeps the event it already has.
      expect(
        CalendarExporter.plan(
          [task(3, 'Yesterday', DateTime(2026, 9, 21, 10))],
          now,
          mapped: {'t:3'},
        ).keys,
        ['t:3'],
      );
    });

    test('with an account ticked, a new task is added, a change changes it, and deleting removes it; Calendar doesn’t show it twice', () async {
      final bridge = phoneWithAccounts();
      final exports = MemoryExportStore();
      final controller = DeviceCalendarController(
        bridge,
        MemoryCalendarPreferences(),
        exporter: CalendarExporter(bridge, exports),
      );
      await controller.ready;
      await controller.enable();
      final tasks = [task(1, 'Dentist', DateTime(2026, 9, 22, 10))];
      // None ticked: nothing is written.
      await controller.exportTasks(tasks, now: now);
      expect(bridge.written, isEmpty);
      expect(
        await controller.selectExportAccount(primaryCal.accountKey, true),
        isTrue,
      );
      await controller.exportTasks(tasks, now: now);
      expect(bridge.written, hasLength(1));
      final id = bridge.written.keys.single;
      expect(bridge.written[id]!.calendar, primaryCal.id);
      expect(bridge.written[id]!.title, 'Dentist');
      // The phone lists the event TaskFlow added beside a real one.
      bridge.data = [
        calendarEvent(id: id, calendar: '1'),
        calendarEvent(id: '50', calendar: '1', uid: 'real'),
      ];
      expect(
        (await controller.events(DateTime(2026, 9, 22))).items.map((e) => e.id),
        ['50'],
      );
      // Renamed and moved: the same event changes.
      await controller.exportTasks([
        task(1, 'Dentist at 11', DateTime(2026, 9, 23, 11)),
      ], now: now);
      expect(bridge.written.keys, [id]);
      expect(bridge.written[id]!.title, 'Dentist at 11');
      // Nothing changed: nothing is written.
      final before = Map.of(bridge.written);
      await controller.exportTasks([
        task(1, 'Dentist at 11', DateTime(2026, 9, 23, 11)),
      ], now: now);
      expect(bridge.written, before);
      // A second account gets its own copy.
      await controller.selectExportAccount(office.accountKey, true);
      await controller.exportTasks([
        task(1, 'Dentist at 11', DateTime(2026, 9, 23, 11)),
      ], now: now);
      expect(
        bridge.written.values.map((w) => w.calendar),
        unorderedEquals([primaryCal.id, office.id]),
      );
      // Unticking every account takes TaskFlow's events away again.
      await controller.selectExportAccount(primaryCal.accountKey, false);
      await controller.selectExportAccount(office.accountKey, false);
      await controller.exportTasks([
        task(1, 'Dentist at 11', DateTime(2026, 9, 23, 11)),
      ], now: now);
      expect(bridge.written, isEmpty);
      // Deleted in the app: removed from the calendar.
      await controller.selectExportAccount(primaryCal.accountKey, true);
      await controller.exportTasks(tasks, now: now);
      expect(bridge.written, hasLength(1));
      await controller.exportTasks([], now: now);
      expect(bridge.written, isEmpty);
      expect(exports.value, isEmpty);
      controller.dispose();
      bridge.close();
    });

    test(
      'an event deleted in the calendar app comes back when its task changes',
      () async {
        final bridge = phoneWithAccounts()..writeState = CalendarAccess.granted;
        final exports = MemoryExportStore();
        final exporter = CalendarExporter(bridge, exports);
        await exporter.sync(
          [task(1, 'Call', DateTime(2026, 9, 25, 9))],
          [primaryCal],
          now: now,
        );
        bridge.written.clear();
        await exporter.sync(
          [task(1, 'Call Ana', DateTime(2026, 9, 25, 9))],
          [primaryCal],
          now: now,
        );
        expect(bridge.written.values.single.title, 'Call Ana');
        expect(exports.value.keys, ['1|t:1']);
      },
    );

    test('an account unticked keeps the events of days gone by', () async {
      final bridge = phoneWithAccounts()..writeState = CalendarAccess.granted;
      final exports = MemoryExportStore();
      final exporter = CalendarExporter(bridge, exports);
      final tasks = [
        task(1, 'Call', DateTime(2026, 9, 25, 9)),
        task(2, 'Walk', DateTime(2026, 9, 1, 8), recurrence: 'daily'),
      ];
      await exporter.sync(tasks, [primaryCal], now: now);
      expect(bridge.written, hasLength(31));
      // Two days later, the account is unticked.
      await exporter.sync(tasks, [], now: DateTime(2026, 9, 24, 9));
      expect(
        bridge.written.values.map(
          (w) => DateTime.fromMillisecondsSinceEpoch(w.start),
        ),
        everyElement(isA<DateTime>().having((d) => d.day, 'day', lessThan(24))),
      );
      expect(bridge.written, hasLength(2));
    });

    test('a refusal leaves the account unticked', () async {
      final bridge = _RefusingWrites()..access = CalendarAccess.denied;
      final controller = DeviceCalendarController(
        bridge,
        MemoryCalendarPreferences(),
      );
      await controller.ready;
      await controller.enable();
      expect(
        await controller.selectExportAccount(primaryCal.accountKey, true),
        isFalse,
      );
      expect(controller.state.preferences.exportAccounts, isEmpty);
      controller.dispose();
      bridge.close();
    });

    test(
      'the record of added events is kept per account, without task words',
      () async {
        final sql = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
        await TaskDatabase.createReminderTables(sql);
        final database = TaskDatabase.forTesting(sql);
        final first = CalendarExportStore('account-1', database);
        await first.write({
          't:1': const CalendarExportEntry(
            event: '100',
            calendar: '1',
            fingerprint: 'f',
            start: 1,
            task: 1,
          ),
        });
        expect((await CalendarExportStore('account-1', database).read()).keys, [
          't:1',
        ]);
        expect(
          await CalendarExportStore('account-2', database).read(),
          isEmpty,
        );
        await database.close();
      },
    );
  });

  group('the screen', () {
    Future<ProviderContainer> open(
      WidgetTester tester,
      FakeDeviceCalendars bridge, {
      String language = 'en',
    }) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        retry: noRetry,
        overrides: [
          deviceCalendarsProvider.overrideWithValue(bridge),
          calendarPreferenceStoreProvider.overrideWithValue(
            MemoryCalendarPreferences(),
          ),
          calendarExportStoreProvider.overrideWithValue(MemoryExportStore()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const DeviceCalendarsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('calendar-connect')));
      await tester.pumpAndSettle();
      return container;
    }

    Future<void> openWay(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }

    for (final language in ['en', 'es', 'ca']) {
      testWidgets(
        '($language) two rows, one per way; the first lists one tick per account, holidays wait in More options, named «Holidays» from their account',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          final bridge = phoneWithAccounts();
          addTearDown(bridge.close);
          await open(tester, bridge, language: language);
          // No list on the first page: two rows saying how many are ticked.
          expect(find.byType(CheckboxListTile), findsNothing);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('calendar-into-app')),
              matching: find.text(l.calendarAccountsOn(3)),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('calendar-into-phone')),
              matching: find.text(l.calendarAccountsOn(0)),
            ),
            findsOneWidget,
          );
          await openWay(tester, 'calendar-into-app');
          expect(find.text(l.calendarIntoAppLead), findsOneWidget);
          expect(find.byType(CheckboxListTile), findsNWidgets(3));
          expect(find.text(l.calendarOnPhone), findsOneWidget);
          expect(find.text(l.calendarAccountCalendars(2)), findsOneWidget);
          expect(find.text(l.calendarHolidays), findsNothing);
          expect(find.textContaining('#holiday'), findsNothing);
          await tester.tap(find.byKey(const ValueKey('calendar-more')));
          await tester.pumpAndSettle();
          final tile = find.byKey(const ValueKey('device-calendar-3'));
          await tester.scrollUntilVisible(tile, 200);
          expect(
            find.descendant(of: tile, matching: find.text(l.calendarHolidays)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: tile,
              matching: find.textContaining(l.calendarFromAccount('').trim()),
            ),
            findsOneWidget,
          );
          expect(tester.widget<CheckboxListTile>(tile).value, isFalse);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'TaskFlow in your calendar: none ticked; the first tick asks the phone, then the row counts it',
      (tester) async {
        final l = lookupAppLocalizations(const Locale('en'));
        final bridge = phoneWithAccounts();
        addTearDown(bridge.close);
        final container = await open(tester, bridge);
        await openWay(tester, 'calendar-into-phone');
        expect(find.text(l.calendarIntoPhoneLead), findsOneWidget);
        expect(find.byKey(const ValueKey('calendar-more')), findsNothing);
        final work = find.byKey(
          ValueKey('export-account-${office.accountKey}'),
        );
        expect(tester.widget<CheckboxListTile>(work).value, isFalse);
        await tester.tap(work);
        await tester.pumpAndSettle();
        expect(bridge.writeRequests, 1);
        expect(tester.widget<CheckboxListTile>(work).value, isTrue);
        expect(container.read(deviceCalendarProvider).exportCalendars, [
          office,
        ]);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('calendar-into-phone')),
            matching: find.text(l.calendarAccountsOn(1)),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _RefusingWrites extends FakeDeviceCalendars {
  @override
  Future<CalendarAccess> writeAccess({bool request = false}) async {
    if (request) writeRequests++;
    return CalendarAccess.denied;
  }
}
