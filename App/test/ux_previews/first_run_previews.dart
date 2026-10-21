// First run, and the explanations the app draws around Android's permission
// prompts: the reminder question after the first dated task, what happens
// when the phone refuses, exact alarms, and the phone's calendars. The
// empty first Calendar is in the calendar area; the microphone's message
// and the privacy line are in the capture area.
import 'package:agenda/services/device_calendars.dart';
import 'package:agenda/services/feedback_timeout.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app.dart';
import 'support/fixtures.dart';
import 'support/preview.dart';

const reminderQuestion = Screen(
  'first-run',
  'reminder-question',
  'The one-time reminder question, after the first task with a date',
  sources: [
    'lib/widgets/reminder_ask_sheet.dart',
    'lib/widgets/reminder_control.dart',
    'lib/services/reminder_engine.dart',
    'lib/widgets/task_editor.dart',
  ],
);

const phoneCalendars = Screen(
  'first-run',
  'phone-calendars',
  'The phone\'s calendars (`/deviceCalendars`), before and after Android\'s permission',
  sources: [
    'lib/screens/device_calendars_screen.dart',
    'lib/providers/device_calendar_provider.dart',
  ],
);

/// A new account adds its first task with a date, in the form, and the save
/// message closes: the question comes up. Mañana, since at the previews'
/// 09:41 a task for today without a time is past its 9:00 reminder.
Future<PreviewApp> _firstDatedTask(
  Preview p, {
  bool allowed = false,
}) async {
  final app = await PreviewApp.open(
    p,
    pro: false,
    hadTask: false,
    reminders: const ReminderPreferences(),
    notificationsAllowed: allowed,
  );
  await app.tap(p.l.newTask);
  await p.tester.enterText(
    find.byKey(const ValueKey('task-title')),
    'Llamar al médico',
  );
  await p.tester.pumpAndSettle();
  await p.tester.tap(find.byKey(const ValueKey('new-task-tomorrow')));
  await p.tester.pumpAndSettle();
  await p.tester.tap(find.byKey(const ValueKey('task-save')));
  await p.tester.pumpAndSettle();
  await p.tester.pump(FeedbackTimeout.defaultDuration);
  await p.tester.pumpAndSettle();
  return app;
}

void firstRunPreviews() {
  previewArea('first-run', 'First run and permissions', () {
    preview(
      reminderQuestion,
      'asked',
      'After the first task with a date: «¿Quieres un recordatorio antes?», asked once, before Android\'s own prompt.',
      [es1, es2, ca2],
      (p) async {
        await _firstDatedTask(p);
        await p.shoot();
      },
    );

    preview(
      reminderQuestion,
      'refused',
      'Sí tapped, and Android\'s prompt refused: the message and Permitir avisos.',
      [es2],
      (p) async {
        final app = await _firstDatedTask(p);
        app.reminderAccess.grant = false;
        await app.tap(p.l.reminderAskYes);
        await p.shoot();
      },
    );

    preview(
      reminderQuestion,
      'exact-alarms',
      'Sí tapped with notifications allowed but exact alarms off: why to allow «Alarmas y recordatorios», what to do next, and Ahora no.',
      [es2, ca2],
      (p) async {
        final app = await _firstDatedTask(p, allowed: true);
        app.reminderAccess.exact = false;
        await app.tap(p.l.reminderAskYes);
        await p.shoot();
      },
    );

    preview(
      phoneCalendars,
      'not-allowed',
      'Not allowed yet: what showing the phone\'s calendars does, and Conectar.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await app.push('/deviceCalendars');
        await p.shoot();
      },
    );

    preview(
      phoneCalendars,
      'refused',
      'Conectar, then «No permitir» in Android\'s dialog: what that means, and Conectar again.',
      [es1, es2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        await app.push('/deviceCalendars');
        await app.tap(p.l.calendarEnable);
        await p.shoot();
      },
    );

    preview(
      phoneCalendars,
      'blocked',
      'Refused for good: only the phone\'s settings can allow it.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          calendarAccess: CalendarAccess.blocked,
        );
        await app.push('/deviceCalendars');
        await p.shoot();
      },
    );

    preview(
      phoneCalendars,
      'allowed',
      'Conectar, then allowed: connected, every calendar ticked, any can be unticked.',
      [es1, es2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          calendarAccess: CalendarAccess.granted,
        );
        await app.push('/deviceCalendars');
        await app.tap(p.l.calendarEnable);
        await p.shoot();
      },
    );
  });
}
