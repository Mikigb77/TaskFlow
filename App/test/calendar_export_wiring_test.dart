// The app's own wiring of «TaskFlow in your calendar» (2026-11-12): a task
// deleted in TaskFlow loses its event in the phone's calendar, through the
// providers the app's shell listens to.
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/providers/no_retry.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/services/calendar_export.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'calendar_accounts_test.dart'
    show MemoryExportStore, phoneWithAccounts, primaryCal;
import 'device_calendar_test.dart'
    show FakeDeviceCalendars, MemoryCalendarPreferences;
import 'support/design_fixtures.dart' show MemoryTasks;

/// Tasks set by the test, as the app's list shows them.
class _Tasks extends TaskNotifier {
  _Tasks(List<Task> tasks) : super(MemoryTasks()) {
    state = AsyncData(tasks);
  }
  @override
  Future<void> loadTasks() async {}
  void show(List<Task> tasks) => state = AsyncData(tasks);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'a task deleted in TaskFlow loses its event in the phone’s calendar',
    () async {
      final today = DateTime.now();
      final dentist = Task(
        id: 1,
        title: 'Dentist',
        dueDate: DateTime(today.year, today.month, today.day + 1, 10),
        hasTime: true,
        priority: 2,
      );
      final bread = Task(
        id: 2,
        title: 'Bread',
        dueDate: DateTime(today.year, today.month, today.day + 2, 10),
        hasTime: true,
        priority: 2,
      );
      final bridge = phoneWithAccounts()..access = CalendarAccess.granted;
      final tasks = _Tasks([dentist, bread]);
      final container = ProviderContainer(
        retry: noRetry,
        overrides: [
          deviceCalendarsProvider.overrideWithValue(bridge),
          calendarPreferenceStoreProvider.overrideWithValue(
            MemoryCalendarPreferences(),
          ),
          calendarExportStoreProvider.overrideWithValue(MemoryExportStore()),
          taskProvider.overrideWith((ref) => tasks),
        ],
      );
      addTearDown(container.dispose);
      container.listen(calendarExportProvider, (_, _) {});
      final calendars = container.read(deviceCalendarProvider.notifier);
      await calendars.ready;
      await calendars.enable();
      expect(
        await calendars.selectExportAccount(primaryCal.accountKey, true),
        isTrue,
      );
      Future<void> settle() => Future<void>.delayed(const Duration(seconds: 2));
      await settle();
      expect(
        bridge.written.values.map((e) => e.title),
        unorderedEquals(['Dentist', 'Bread']),
      );

      tasks.show([bread]);
      await settle();
      expect(bridge.written.values.map((e) => e.title), ['Bread']);
    },
  );

  test(
    'a delete the phone refuses is kept, and tried again on the next change',
    () async {
      final today = DateTime.now();
      Task day(int id, String title) => Task(
        id: id,
        title: title,
        dueDate: DateTime(today.year, today.month, today.day + 1, 9 + id),
        hasTime: true,
        priority: 2,
      );
      final bridge = _RefusingDeletes()
        ..access = CalendarAccess.granted
        ..sources = [primaryCal];
      final store = MemoryExportStore();
      final exporter = CalendarExporter(bridge, store);
      await exporter.sync(
        [day(1, 'Dentist'), day(2, 'Bread')],
        [primaryCal],
        now: today,
      );
      expect(bridge.written, hasLength(2));
      bridge.refuse = true;
      final added = await exporter.sync(
        [day(2, 'Bread')],
        [primaryCal],
        now: today,
      );
      // Still on the phone, so still TaskFlow's, and Calendar still hides it.
      expect(bridge.written, hasLength(2));
      expect(added, hasLength(2));
      expect(store.value, hasLength(2));
      bridge.refuse = false;
      await exporter.sync([day(2, 'Bread')], [primaryCal], now: today);
      expect(bridge.written.values.map((e) => e.title), ['Bread']);
      expect(store.value, hasLength(1));
    },
  );
}

/// A phone that answers «gone» to deletes while [refuse] is set.
class _RefusingDeletes extends FakeDeviceCalendars {
  bool refuse = false;
  @override
  Future<List<String>> write(List<CalendarWrite> writes) async {
    if (!refuse) return super.write(writes);
    return [for (final item in writes) item.op == 'delete' ? 'gone' : 'ok'];
  }
}
