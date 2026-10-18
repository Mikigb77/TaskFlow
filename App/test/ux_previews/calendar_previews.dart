// Calendar: first use, an ordinary and a busy day, the month, offline, an
// invitation, a task just added and one just completed; the day timeline and
// the completed tasks.
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/device_calendar_event.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/device_calendar_provider.dart';
import 'package:agenda/providers/invitations_provider.dart';
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
  sources: ['lib/screens/completed_tasks_screen.dart', 'lib/widgets/task_tile.dart'],
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
      [es2],
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
      'Three dictated tasks just added: Calendar shows them lit, with the message and Deshacer.',
      [es1, es2, ca2, es1Wide],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
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
      'phone-events',
      'The phone\'s own calendar shown too: its events line after the day\'s tasks, scrolled into view.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          calendarAccess: CalendarAccess.granted,
          phoneCalendars: CalendarPreferences(
            enabled: true,
            selected: {PreviewDeviceCalendars.work.selectionKey},
          ),
          phoneEvents: [
            DeviceCalendarEvent(
              id: 'e1',
              calendarId: '1',
              title: 'Reunión de equipo',
              start: day(0, 11, 30).toUtc(),
              end: day(0, 12, 30).toUtc(),
              allDay: false,
            ),
            DeviceCalendarEvent(
              id: 'e2',
              calendarId: '1',
              title: 'Cena con los Puig',
              start: day(0, 21).toUtc(),
              end: day(0, 23).toUtc(),
              allDay: false,
            ),
          ],
        );
        await p.tester.scrollUntilVisible(
          find.textContaining(p.l.calendarEventCount(2)),
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
      everywhere,
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await app.push('/timeline', arguments: previewToday);
        await p.shoot();
      },
    );

    preview(
      timeline,
      'busy',
      'A busy day hour by hour, with overlaps side by side.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(p, tasks: busyDay(), projects: allProjects);
        await app.push('/timeline', arguments: previewToday);
        await p.shoot();
      },
    );

    // -------------------------------------------------------- completed
    preview(
      completedTasks,
      'list',
      'Tasks already done.',
      everywhere,
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [
            ...normalDay(),
            ...sharedProjectTasks().where((t) => t.isCompleted),
          ],
          projects: allProjects,
        );
        await app.push('/completedTasks');
        await p.shoot();
      },
    );
  });
}
