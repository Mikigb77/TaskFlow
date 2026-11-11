// Calendar: first use, an ordinary and a busy day, the month, offline, an
// invitation, a task just added and one just completed; the day timeline and
// the completed tasks.
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/device_calendar_event.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/providers/invitations_provider.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_previews.dart' show speak, threeTasks, said;
import 'support/app.dart';
import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/preview.dart';

const agenda = Screen(
  'calendar',
  'agenda',
  'Calendar, the first tab: the week strip and the day\'s agenda',
  sources: [
    'lib/screens/calendar_screen.dart',
    'lib/screens/main_shell.dart',
    'lib/widgets/task_tile.dart',
    'lib/widgets/task_list.dart',
    'lib/widgets/task_actions.dart',
    'lib/widgets/task_schedule_label.dart',
    'lib/widgets/project_scope_control.dart',
    'lib/widgets/invitation_cards.dart',
    'lib/widgets/custom_app_bar.dart',
    'lib/widgets/app_components.dart',
    'lib/widgets/device_calendar_events.dart',
  ],
);

const timeline = Screen(
  'calendar',
  'timeline',
  'The day timeline (`/timeline`), from Calendar\'s Día view',
  sources: [
    'lib/screens/day_timeline_screen.dart',
    'lib/models/day_timeline.dart',
    'lib/widgets/device_calendar_events.dart',
  ],
);

const completedTasks = Screen(
  'calendar',
  'completed',
  'Completed tasks (`/completedTasks`)',
  sources: [
    'lib/screens/completed_tasks_screen.dart',
    'lib/screens/home_screen.dart',
    'lib/widgets/task_tile.dart',
  ],
);

/// Tasks on other days only: today is free.
List<Task> _otherDays() => [
  for (final task in normalDay())
    if (task.dueDate != null && !_isToday(task.dueDate!)) task,
];

bool _isToday(DateTime date) =>
    date.year == previewToday.year &&
    date.month == previewToday.month &&
    date.day == previewToday.day;

void calendarPreviews() {
  previewArea('calendar', 'Calendar', () {
    preview(
      agenda,
      'first-use',
      'A new account\'s first look: no tasks yet, and what to do first.',
      [...mainScreen, ...longText, es1Wide],
      (p) async {
        await PreviewApp.open(
          p,
          hadTask: false,
          reminders: const ReminderPreferences(),
        );
        await p.shoot();
      },
    );

    preview(
      agenda,
      'first-use-free',
      'First look for an account without Pro or dictations: Nueva tarea opens the form.',
      [es2],
      (p) async {
        await PreviewApp.open(
          p,
          hadTask: false,
          pro: false,
          reminders: const ReminderPreferences(),
        );
        await p.shoot();
      },
    );

    preview(
      agenda,
      'empty-day',
      'Nothing today, tasks on other days.',
      [es2],
      (p) async {
        await PreviewApp.open(p, tasks: _otherDays());
        await p.shoot();
      },
    );

    preview(
      agenda,
      'normal',
      'An ordinary day: five appointments, one done, one with no date.',
      [...mainScreen, ...longText, ...wider],
      (p) async {
        await PreviewApp.open(p, tasks: normalDay());
        await p.shoot();
      },
    );

    preview(
      agenda,
      'busy',
      'A busy day with shared projects: long titles, overlaps, steps, people, an overdue task.',
      [es1, es2, esDark, es1Wide],
      (p) async {
        await PreviewApp.open(p, tasks: busyDay(), projects: allProjects);
        await p.shoot();
      },
    );

    preview(
      agenda,
      'view-menu',
      'The view menu open: Semana, Mes, Día.',
      [es2],
      (p) async {
        await PreviewApp.open(p, tasks: normalDay());
        await p.tester.tap(find.byKey(const ValueKey('calendar-format')));
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      agenda,
      'month',
      'The month view.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(p, tasks: busyDay(), projects: allProjects);
        await p.tester.tap(find.byKey(const ValueKey('calendar-format')));
        await p.tester.pumpAndSettle();
        await app.tap(p.l.month);
        await p.shoot();
      },
    );

    preview(
      agenda,
      'month-day-tapped',
      'Mes, then a day with tasks tapped: back to Semana on that day, its first tasks in view.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await p.tester.tap(find.byKey(const ValueKey('calendar-format')));
        await p.tester.pumpAndSettle();
        await app.tap(p.l.month);
        // «Pagar la factura de la luz», in two days.
        final picked = day(2);
        final cell = find.byKey(
          ValueKey('CellContent-${picked.year}-${picked.month}-${picked.day}'),
        );
        if (cell.evaluate().isEmpty) {
          // Past the grid's last row: it's next month's.
          await p.tester.tap(find.byTooltip(p.l.nextMonth));
          await p.tester.pumpAndSettle();
        }
        await p.tester.tap(cell);
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      agenda,
      'month-boundary-week',
      'A week that runs into the next month: the next month\'s days look like any other.',
      [es1, esDark],
      (p) async {
        await PreviewApp.open(p, tasks: normalDay());
        // The first week ahead whose days fall in two months.
        final monday = day(1 - previewToday.weekday);
        var weeks = 0;
        while (DateTime(monday.year, monday.month, monday.day + 7 * weeks)
                .month ==
            DateTime(monday.year, monday.month, monday.day + 7 * weeks + 6)
                .month) {
          weeks++;
        }
        for (var i = 0; i < weeks; i++) {
          await p.tester.tap(find.byTooltip(p.l.nextWeek));
          await p.tester.pumpAndSettle();
        }
        await p.shoot();
      },
    );

    preview(
      agenda,
      'offline',
      'The last sync couldn\'t reach the server: the calm offline line.',
      [es1],
      (p) async {
        await PreviewApp.open(
          p,
          tasks: normalDay(),
          syncError: ApiException(
            0,
            'Cannot reach the server. Check the connection.',
          ).toString(),
        );
        await p.shoot();
      },
    );

    preview(
      agenda,
      'invitation',
      'Ana invited you to a project: the invitation card on Calendar.',
      [es1, ca2],
      (p) async {
        await PreviewApp.open(
          p,
          tasks: normalDay(),
          invitations: const [
            PendingInvitation(
              kind: 'list',
              id: 'inv-1',
              name: 'Excursión de fin de curso',
              targetId: 'excursion',
              role: 'editor',
              sender: 'Ana',
            ),
          ],
        );
        await p.shoot();
      },
    );

    preview(
      agenda,
      'pending-captures',
      'Words kept for later: the link to the pending captures above Añadir tarea.',
      [es1, es2],
      (p) async {
        await PreviewApp.open(
          p,
          tasks: normalDay(),
          captures: [
            CaptureSession(
              id: 'kept-1',
              ownerKey: 'http://10.0.2.2:8088/users/$me',
              timezone: 'Europe/Madrid',
              capturedAt: previewNow.subtract(const Duration(hours: 2)).toUtc(),
              status: 'editing',
              source: 'speech',
              text: 'Pedir hora para la ITV del coche',
            ),
          ],
        );
        await p.shoot();
      },
    );

    preview(
      agenda,
      'added',
      'Three dictated tasks just added, two today and one on Friday: today\'s two lit, and «2 tareas añadidas al … · también el vie, …» with Deshacer. The day\'s heading shows above them when it fits with both above the message; at 1× on 360×800 it scrolls away, and the message names the day.',
      [es1, es2, ca2, es1Wide, esDark],
      (p) async {
        // A day doesn't hold the same task twice at the same time: leave out
        // the day's own 17:00 «Recoger…», which the answer adds again.
        final app = await PreviewApp.open(
          p,
          tasks: normalDay().where((task) => task.id != 4).toList(),
        );
        app.api.answer = threeTasks();
        await speak(app, said);
        await p.tester.tap(find.byKey(const ValueKey('save-drafts')));
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      agenda,
      'completed',
      'A task ticked off: the message with Deshacer.',
      [es2],
      (p) async {
        await PreviewApp.open(p, tasks: normalDay());
        final checkbox = find.descendant(
          of: find.widgetWithText(TaskTile, 'Llamar al médico para pedir cita'),
          matching: find.byType(Checkbox),
        );
        await p.tester.ensureVisible(checkbox);
        await p.tester.pumpAndSettle();
        await p.tester.tap(checkbox);
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      agenda,
      'all-clear',
      'Today\'s last open task just ticked: «Todo listo. Respira.» with Deshacer.',
      [es1, es2, ca2],
      (p) async {
        // Today: the walk, already done, and the call to the doctor.
        await PreviewApp.open(
          p,
          tasks: [
            for (final task in normalDay())
              if (task.id! < 3 || task.id! > 5) task,
          ],
        );
        final checkbox = find.descendant(
          of: find.widgetWithText(TaskTile, 'Llamar al médico para pedir cita'),
          matching: find.byType(Checkbox),
        );
        await p.tester.ensureVisible(checkbox);
        await p.tester.pumpAndSettle();
        await p.tester.tap(checkbox);
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      agenda,
      'phone-events',
      'The phone\'s own calendar shown too: its two events by name, «Reunión de equipo · 10:00» and «Cita con el dentista · 17:00», after the day\'s tasks and above «Sin fecha · 1», scrolled into view.',
      [es1, es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          calendarAccess: CalendarAccess.granted,
          phoneCalendars: CalendarPreferences(
            enabled: true,
            accounts: {PreviewDeviceCalendars.work.accountKey},
          ),
          phoneEvents: [
            DeviceCalendarEvent(
              id: 'e1',
              calendarId: '1',
              title: 'Reunión de equipo',
              start: day(0, 10).toUtc(),
              end: day(0, 11).toUtc(),
              allDay: false,
            ),
            DeviceCalendarEvent(
              id: 'e2',
              calendarId: '1',
              title: 'Cita con el dentista',
              start: day(0, 17).toUtc(),
              end: day(0, 18).toUtc(),
              allDay: false,
            ),
          ],
        );
        await p.tester.scrollUntilVisible(
          find.byKey(const ValueKey('calendar-inbox')),
          200,
          scrollable: app.mainScroll(),
        );
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      agenda,
      'phone-events-many',
      'Five phone events on the day: the first three by name, the all-day one first, then «Ver los 5 eventos», which opens them all.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          calendarAccess: CalendarAccess.granted,
          phoneCalendars: CalendarPreferences(
            enabled: true,
            accounts: {PreviewDeviceCalendars.work.accountKey},
          ),
          phoneEvents: [
            DeviceCalendarEvent(
              id: 'm0',
              calendarId: '1',
              title: 'Vacaciones de Laura',
              start: DateTime.utc(
                previewToday.year,
                previewToday.month,
                previewToday.day,
              ),
              end: DateTime.utc(
                previewToday.year,
                previewToday.month,
                previewToday.day + 1,
              ),
              allDay: true,
            ),
            for (final (i, (title, hour)) in [
              ('Reunión de equipo', 10),
              ('Cita con el dentista', 17),
              ('Cumpleaños de Marta', 19),
              ('Llamada con Londres', 21),
            ].indexed)
              DeviceCalendarEvent(
                id: 'm${i + 1}',
                calendarId: '1',
                title: title,
                start: day(0, hour).toUtc(),
                end: day(0, hour + 1).toUtc(),
                allDay: false,
              ),
          ],
        );
        await p.tester.scrollUntilVisible(
          find.byKey(const ValueKey('calendar-inbox')),
          200,
          scrollable: app.mainScroll(),
        );
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      agenda,
      'no-dictations',
      'A free account with no dictations left this month: the one button reads Nueva tarea.',
      [es1],
      (p) async {
        await PreviewApp.open(p, tasks: normalDay(), pro: false, freeLeft: 0);
        await p.shoot();
      },
    );

    // --------------------------------------------------------- timeline
    preview(
      timeline,
      'normal',
      'Today hour by hour.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await app.push('/timeline', arguments: previewToday);
        await p.shoot();
      },
    );

    preview(
      timeline,
      'untimed',
      'Today with a task that has no time: «Sin hora» stays above the hours, with the first timed task.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            Task(
              id: 30,
              title: 'Pagar la factura de la luz',
              dueDate: day(0),
              hasTime: false,
              priority: 2,
            ),
          ],
        );
        await app.push('/timeline', arguments: previewToday);
        await p.shoot();
      },
    );

    preview(
      timeline,
      'busy',
      'A busy day hour by hour, with overlaps side by side: at 1× both lanes share the space beside the hours; at 2× each keeps 240 dp and they scroll sideways, with the bar showing along the bottom of the hours.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: busyDay(), projects: allProjects);
        await app.push('/timeline', arguments: previewToday);
        await p.shoot();
      },
    );

    preview(
      timeline,
      'events-error',
      'Today hour by hour when the phone\'s events can\'t be read: «No se pudieron leer los eventos. Toca para reintentar.» above the hours; a tap reads them again.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          calendarAccess: CalendarAccess.granted,
          phoneCalendars: CalendarPreferences(
            enabled: true,
            accounts: {PreviewDeviceCalendars.work.accountKey},
          ),
        );
        (app.container.read(deviceCalendarsProvider) as PreviewDeviceCalendars)
            .failEvents = true;
        app.container.invalidate(
          deviceEventsProvider(Task.dateKey(previewToday)),
        );
        await app.push('/timeline', arguments: previewToday);
        await p.shoot();
      },
    );

    // -------------------------------------------------------- completed
    preview(
      completedTasks,
      'list',
      'Tasks already done, the last one ticked first: «Comprar pan», with no day, ticked a moment ago, above today’s walk and yesterday’s marks.',
      everywhere,
      (p) async {
        // When each was ticked (D2): the order follows these, not the days.
        final ticked = {1: day(0, 8, 45), 34: day(-1, 18, 10)};
        final app = await PreviewApp.open(
          p,
          tasks: [
            for (final task in [
              ...normalDay(),
              ...sharedProjectTasks().where((t) => t.isCompleted),
            ])
              task.isCompleted
                  ? task.copyWith(completedAt: ticked[task.id])
                  : task,
            Task(
              id: 40,
              title: 'Comprar pan',
              priority: 1,
              isCompleted: true,
              completedAt: day(0, 9, 30),
            ),
          ],
          projects: allProjects,
        );
        await app.push('/completedTasks');
        await p.shoot();
      },
    );

    preview(
      completedTasks,
      'project',
      'From the ✓ on «Matemáticas»: only its completed tasks, its name under the title.',
      [es1, es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            ...sharedProjectTasks().where((t) => t.isCompleted),
          ],
          projects: allProjects,
        );
        await app.tab(p.l.tasks);
        await app.pushPage(
          const HomeScreen(isRoot: false, listId: 'matematicas'),
        );
        await p.tester.tap(find.byTooltip(p.l.completedTasks));
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      completedTasks,
      'project-person',
      'From the ✓ on «Matemáticas» with «Ana» on: only what Ana finished there, «Matemáticas · Ana» under the title.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            ...sharedProjectTasks(),
            Task(
              id: 35,
              title: 'Corregir el examen del tema 3',
              dueDate: day(-2),
              hasTime: false,
              priority: 2,
              listId: 'matematicas',
              assignment: 'member',
              assigneeId: ana,
              assigneeName: 'Ana',
              createdBy: paul,
              createdByName: 'Paul',
              isCompleted: true,
            ),
          ],
          projects: allProjects,
        );
        await app.tab(p.l.tasks);
        await app.pushPage(
          const HomeScreen(isRoot: false, listId: 'matematicas'),
        );
        await p.tester.tap(find.widgetWithText(ChoiceChip, 'Ana').first);
        await p.tester.pumpAndSettle();
        await p.tester.tap(find.byTooltip(p.l.completedTasks));
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );
  });
}
