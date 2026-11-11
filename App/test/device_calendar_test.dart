import 'dart:async';
import 'package:agenda/models/device_calendar_event.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const workCalendar = DeviceCalendar(
    id: '1', name: 'Work', account: 'work@example.invalid', sourceId: 'work');
const homeCalendar = DeviceCalendar(
    id: '2', name: 'Home', account: 'home@example.invalid', sourceId: 'home');

DeviceCalendarEvent calendarEvent(
        {String id = '10',
        String calendar = '1',
        String uid = '',
        bool allDay = false,
        String start = '2026-09-22T14:00:00Z',
        String end = '2026-09-22T15:00:00Z'}) =>
    DeviceCalendarEvent(
        id: id,
        calendarId: calendar,
        uid: uid,
        title: 'Calendar appointment',
        start: DateTime.parse(start),
        end: DateTime.parse(end),
        allDay: allDay);

class FakeDeviceCalendars extends DeviceCalendars {
  FakeDeviceCalendars() : super(supported: false);
  CalendarAccess access = CalendarAccess.granted;
  List<DeviceCalendar> sources = [workCalendar, homeCalendar];
  List<DeviceCalendarEvent> data = [calendarEvent()];
  Completer<CalendarRead<DeviceCalendarEvent>>? pending;
  Set<String> lastIds = {};
  CalendarAccess writeState = CalendarAccess.denied;
  int writeRequests = 0;

  /// Events written, by id, as the phone would keep them.
  final Map<String, CalendarWrite> written = {};
  int nextEvent = 100;
  @override
  Future<CalendarAccess> writeAccess({bool request = false}) async {
    if (request) {
      writeRequests++;
      writeState = CalendarAccess.granted;
    }
    return writeState;
  }

  @override
  Future<List<String>> write(List<CalendarWrite> writes) async => [
        for (final item in writes)
          switch (item.op) {
            'insert' => () {
                final id = '${nextEvent++}';
                written[id] = item;
                return id;
              }(),
            'update' => written.containsKey(item.event)
                ? (() {
                    written[item.event] = item;
                    return 'ok';
                  })()
                : 'gone',
            _ => (() {
                written.remove(item.event);
                return 'ok';
              })(),
          }
      ];
  int permissionRequests = 0, eventReads = 0;
  bool failRead = false;
  @override
  Future<CalendarAccess> status({bool request = false}) async {
    if (request) {
      permissionRequests++;
      access = CalendarAccess.granted;
    }
    return access;
  }

  @override
  Future<CalendarRead<DeviceCalendar>> calendars() async =>
      CalendarRead(sources);
  @override
  Future<CalendarRead<DeviceCalendarEvent>> events(
      Set<String> ids, DateTime day) async {
    eventReads++;
    lastIds = ids;
    if (failRead) throw PlatformException(code: 'calendar_permission');
    return pending == null ? CalendarRead(data) : pending!.future;
  }
}

class MemoryCalendarPreferences extends CalendarPreferenceStore {
  MemoryCalendarPreferences([this.value = const CalendarPreferences()])
      : super('fixture');
  CalendarPreferences value;
  bool fail = false;
  @override
  Future<CalendarPreferences> read() async => value;
  @override
  Future<void> write(CalendarPreferences preferences) async {
    if (fail) throw StateError('Storage unavailable');
    value = preferences;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final day = DateTime(2026, 9, 22);

  test('all-day dates stay fixed and their end is exclusive', () {
    final event = calendarEvent(
        allDay: true,
        start: '2026-09-22T00:00:00Z',
        end: '2026-09-24T00:00:00Z');
    expect(event.occursOn(DateTime(2026, 9, 21)), isFalse);
    expect(event.occursOn(day), isTrue);
    expect(event.occursOn(DateTime(2026, 9, 23)), isTrue);
    expect(event.occursOn(DateTime(2026, 9, 24)), isFalse);
  });
  test('timed events overlap real instants across offsets and short DST days',
      () {
    final event = calendarEvent(
        start: '2026-03-28T23:30:00Z', end: '2026-03-29T01:30:00Z');
    final from = DateTime.parse('2026-03-29T00:00:00+01:00');
    final until = DateTime.parse('2026-03-30T00:00:00+02:00');
    expect(until.difference(from).inHours, 23);
    expect(event.overlaps(from, until), isTrue);
    expect(
        event.overlaps(DateTime.parse('2026-03-29T00:00:00-05:00'),
            DateTime.parse('2026-03-30T00:00:00-05:00')),
        isFalse);
    expect(
        calendarEvent(
                start: '2026-09-22T00:00:00Z', end: '2026-09-22T00:00:00Z')
            .overlaps(DateTime.utc(2026, 9, 22), DateTime.utc(2026, 9, 23)),
        isTrue);
  });
  test(
      'duplicate UIDs and repeated responses merge sources without hiding separate appointments',
      () {
    final appointment = calendarEvent(uid: 'stable-uid');
    final result = DeviceCalendarEvent.forDay([
      appointment,
      appointment,
      calendarEvent(id: '20', calendar: '2', uid: 'stable-uid'),
      calendarEvent(id: '30', uid: 'different-uid'),
      calendarEvent(id: '40', calendar: 'unselected')
    ], [
      workCalendar,
      homeCalendar
    ], {
      '1',
      '2'
    }, day);
    expect(result.length, 2);
    expect(
        result
            .singleWhere((e) => e.uid == 'stable-uid')
            .sources
            .map((c) => c.id),
        ['1', '2']);
    expect(DeviceCalendarEvent.forDay([appointment], [workCalendar], {}, day),
        isEmpty);
  });
  test(
      'permission requests are explicit, and selection survives a controller restart',
      () async {
    final bridge = FakeDeviceCalendars()..access = CalendarAccess.denied;
    final store = MemoryCalendarPreferences();
    var controller = DeviceCalendarController(bridge, store);
    await controller.ready;
    expect(bridge.permissionRequests, 0);
    expect(controller.state.showing, isFalse);
    await controller.enable();
    expect(bridge.permissionRequests, 1);
    // A first connection ticks every calendar (D7).
    expect(controller.state.preferences.accounts.length, 2);
    expect((await controller.events(day)).items.length, 1);
    controller.dispose();
    controller = DeviceCalendarController(bridge, store);
    await controller.ready;
    expect(controller.state.preferences.accounts.length, 2);
    expect(bridge.permissionRequests, 1);
    await controller.disable();
    final reads = bridge.eventReads;
    expect((await controller.events(day)).items, isEmpty);
    expect(bridge.eventReads, reads);
    controller.dispose();
    bridge.close();
  });
  test(
      'revocation clears events and late reads cannot restore a stale snapshot',
      () async {
    final bridge = FakeDeviceCalendars();
    final controller = DeviceCalendarController(
        bridge,
        MemoryCalendarPreferences(CalendarPreferences(
            enabled: true, accounts: {workCalendar.accountKey})));
    await controller.ready;
    bridge.pending = Completer<CalendarRead<DeviceCalendarEvent>>();
    final oldRead = controller.events(day);
    controller.suspend();
    expect(controller.state.calendars, isEmpty);
    bridge.access = CalendarAccess.denied;
    await controller.refresh();
    bridge.pending!.complete(CalendarRead([calendarEvent()]));
    expect((await oldRead).items, isEmpty);
    expect((await controller.events(day)).items, isEmpty);
    expect(controller.state.access, CalendarAccess.denied);
    controller.dispose();
    bridge.close();
  });
  test(
      'permission lost inside a query is rechecked and reused IDs do not select another source',
      () async {
    final bridge = FakeDeviceCalendars();
    final controller = DeviceCalendarController(
        bridge,
        MemoryCalendarPreferences(CalendarPreferences(
            enabled: true, accounts: {workCalendar.accountKey})));
    await controller.ready;
    bridge.access = CalendarAccess.denied;
    bridge.failRead = true;
    expect((await controller.events(day)).items, isEmpty);
    expect(controller.state.access, CalendarAccess.denied);
    bridge.access = CalendarAccess.granted;
    bridge.failRead = false;
    bridge.sources = [
      const DeviceCalendar(
          id: '1',
          name: 'Unrelated account',
          account: 'different@example.invalid')
    ];
    await controller.refresh();
    final reads = bridge.eventReads;
    expect((await controller.events(day)).items, isEmpty);
    expect(bridge.eventReads, reads);
    controller.dispose();
    bridge.close();
  });
  test('failed preference writes preserve the last saved selection', () async {
    final bridge = FakeDeviceCalendars();
    final store = MemoryCalendarPreferences(CalendarPreferences(
        enabled: true, accounts: {workCalendar.accountKey}));
    final controller = DeviceCalendarController(bridge, store);
    await controller.ready;
    store.fail = true;
    await expectLater(
        controller.selectAccount(homeCalendar.accountKey, true), throwsStateError);
    expect(controller.state.preferences.accounts, {workCalendar.accountKey});
    expect(store.value.accounts, {workCalendar.accountKey});
    store.fail = false;
    await controller.clearSelection();
    expect((await controller.events(day)).items, isEmpty);
    controller.dispose();
    bridge.close();
  });
  test(
      'real SQLite preferences are account-scoped and contain no event content',
      () async {
    final sql = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await TaskDatabase.createReminderTables(sql);
    final database = TaskDatabase.forTesting(sql);
    final first = CalendarPreferenceStore('account-1', database);
    final second = CalendarPreferenceStore('account-2', database);
    await first.write(CalendarPreferences(
        enabled: true, accounts: {workCalendar.accountKey}));
    expect(
        (await CalendarPreferenceStore('account-1', database).read()).enabled,
        isTrue);
    expect((await second.read()).enabled, isFalse);
    final data = (await sql.query('app_preferences')).single['data'] as String;
    expect(data, isNot(contains('Calendar appointment')));
    expect(data, isNot(contains('2026-09-22')));
    await database.close();
  });

  // ---- Run 2026-10-19-app · P188 (UX-1611 e, D7): connecting shows every
  // phone calendar ----

  test(
      'UX-1611: with two phone calendars and nothing selected, allowing access selects both and the events show',
      () async {
    final bridge = FakeDeviceCalendars()..access = CalendarAccess.denied;
    final store = MemoryCalendarPreferences();
    final controller = DeviceCalendarController(bridge, store);
    await controller.ready;
    expect(controller.state.showing, isFalse);
    await controller.enable();
    expect(controller.state.preferences.enabled, isTrue);
    expect(controller.state.preferences.accounts,
        {workCalendar.accountKey, homeCalendar.accountKey});
    expect(store.value.accounts,
        {workCalendar.accountKey, homeCalendar.accountKey});
    expect(controller.state.showing, isTrue);
    expect((await controller.events(day)).items, hasLength(1));
    controller.dispose();
    bridge.close();
  });

  test(
      'with one account of 60 calendars, connecting ticks the account, and events are asked for 50 at a time',
      () async {
    final calendars = [
      for (var i = 0; i < 60; i++)
        DeviceCalendar(
            id: '$i', name: 'Calendar $i', account: 'a@example.invalid'),
    ];
    final bridge = FakeDeviceCalendars()
      ..access = CalendarAccess.denied
      ..sources = calendars;
    final store = MemoryCalendarPreferences();
    final controller = DeviceCalendarController(bridge, store);
    await controller.ready;
    await controller.enable();
    expect(controller.state.preferences.accounts,
        {calendars.first.accountKey});
    expect(controller.state.showing, isTrue);
    final result = await controller.events(day);
    expect(bridge.lastIds, hasLength(50));
    expect(result.truncated, isTrue);
    controller.dispose();
    bridge.close();
  });

  test(
      'UX-1611: reconnecting after Ocultar eventos del calendario keeps an earlier selection of one',
      () async {
    final bridge = FakeDeviceCalendars()..access = CalendarAccess.denied;
    final store = MemoryCalendarPreferences();
    final controller = DeviceCalendarController(bridge, store);
    await controller.ready;
    await controller.enable();
    await controller.selectAccount(homeCalendar.accountKey, false);
    expect(controller.state.preferences.accounts, {workCalendar.accountKey});
    await controller.disable();
    expect(controller.state.showing, isFalse);
    await controller.enable();
    expect(controller.state.preferences.accounts, {workCalendar.accountKey});
    expect(controller.state.showing, isTrue);
    controller.dispose();
    bridge.close();
  });

  test(
      'UX-1611: a selection of one saved before connecting is kept as it is',
      () async {
    final bridge = FakeDeviceCalendars()..access = CalendarAccess.denied;
    final store = MemoryCalendarPreferences(
        CalendarPreferences(accounts: {homeCalendar.accountKey}));
    final controller = DeviceCalendarController(bridge, store);
    await controller.ready;
    await controller.enable();
    expect(controller.state.preferences.accounts, {homeCalendar.accountKey});
    expect(controller.state.showing, isTrue);
    controller.dispose();
    bridge.close();
  });
}
