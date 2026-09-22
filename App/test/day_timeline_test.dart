import 'package:agenda/models/day_timeline.dart';
import 'package:agenda/models/device_calendar_event.dart';
import 'package:agenda/models/task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  test(
      'timeline distinguishes work, deadline markers, date-only tasks and source events',
      () {
    final day = DateTime(2026, 9, 22);
    final report = Task(
        id: 1,
        title: 'Report',
        priority: 1,
        dueDate: DateTime(2026, 9, 22, 9),
        durationMinutes: 90,
        deadline: DateTime(2026, 9, 22, 17),
        deadlineHasTime: true);
    final data = DayTimeline.build(day, [
      report,
      Task(id: 2, title: 'Due today', priority: 1, deadline: day),
      Task(id: 3, title: 'Inbox', priority: 1),
    ], [
      DeviceCalendarEvent(
          id: '1',
          calendarId: '1',
          title: 'Meeting',
          start: DateTime(2026, 9, 22, 9, 30).toUtc(),
          end: DateTime(2026, 9, 22, 10).toUtc(),
          allDay: false),
      DeviceCalendarEvent(
          id: '2',
          calendarId: '1',
          title: 'Holiday',
          start: DateTime.utc(2026, 9, 22),
          end: DateTime.utc(2026, 9, 23),
          allDay: true)
    ]);
    expect(data.entries.map((e) => e.kind),
        [TimelineKind.planned, TimelineKind.calendar, TimelineKind.deadline]);
    expect(data.entries.first.end, DateTime(2026, 9, 22, 10, 30));
    expect(data.entries.last.point, isTrue);
    expect(data.unblocked.single.title, 'Due today');
    expect(data.allDayEvents.single.title, 'Holiday');
    final layout = TimelineLayout.place(data.entries, data.window);
    expect(layout.lanes, 2);
    expect(layout.items.first.lane, isNot(layout.items[1].lane));
    expect(layout.items.first.durationHeight, 108);
    expect(layout.items.last.durationHeight, 2);
    expect(layout.items.last.height, 52);
  });
  test('carry-over is clipped and a short label does not invent occupied time',
      () {
    final day = DateTime(2026, 9, 22);
    final overnight = Task(
        id: 1,
        title: 'Night',
        priority: 1,
        dueDate: DateTime(2026, 9, 21, 23, 30),
        durationMinutes: 60);
    final quick = Task(
        id: 2,
        title: 'Quick',
        priority: 1,
        dueDate: DateTime(2026, 9, 22, 0, 10),
        durationMinutes: 5);
    final data = DayTimeline.build(day, [overnight, quick], []);
    final layout = TimelineLayout.place(data.entries, data.window);
    expect(layout.items[0].top, 0);
    expect(layout.items[0].durationHeight, 36);
    expect(layout.items[1].top, 12);
    expect(layout.items[1].durationHeight, 6);
    expect(layout.items[1].height, 52);
    expect(layout.lanes, 2);
    expect(DayTimeline.build(DateTime(2026, 9, 23), [overnight], []).entries,
        isEmpty);
  });
  test(
      'DST geometry has 23/25 hours and repeated labels retain distinct instants',
      () {
    tzdata.initializeTimeZones();
    final zone = tz.getLocation('Europe/Madrid');
    final spring = TimelineWindow(
        tz.TZDateTime(zone, 2026, 3, 29), tz.TZDateTime(zone, 2026, 3, 30));
    final autumn = TimelineWindow(
        tz.TZDateTime(zone, 2026, 10, 25), tz.TZDateTime(zone, 2026, 10, 26));
    expect(spring.minutes, 1380);
    expect(autumn.minutes, 1500);
    expect(spring.hours.any((hour) => hour.hour == 2), isFalse);
    final repeated = autumn.hours.where((hour) => hour.hour == 2).toList();
    expect(repeated, hasLength(2));
    expect(autumn.offset(repeated[1]) - autumn.offset(repeated[0]), 60);
    expect(repeated[0].timeZoneOffset, isNot(repeated[1].timeZoneOffset));
  });
}
