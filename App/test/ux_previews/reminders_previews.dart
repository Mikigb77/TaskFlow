// Reminder plans (Backend/docs/REMINDER_PLANS.md): the reminder sheet with a
// strength and with «A tu manera» (Pro, free with its badge, and free with a
// rhythm said while dictating), a task due tomorrow with no plans, a task's
// one line, the capture card's line, and the offer after saving a far task.
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/reminder_plan.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/services/feedback_timeout.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/billing_fixtures.dart';
import 'capture_previews.dart' show resume;
import 'support/app.dart';
import 'support/fixtures.dart';
import 'support/preview.dart';

const _planSources = [
  'lib/widgets/reminder_plan_sheet.dart',
  'lib/widgets/reminder_control.dart',
  'lib/l10n/reminder_plan_words.dart',
  'lib/services/reminder_plans.dart',
  'lib/models/reminder_plan.dart',
];

const planSheet = Screen(
  'reminders',
  'sheet',
  'The reminder sheet of a task with a day: the single reminder as before, then, for a day 2 or more days away or a task with a plan, «Hasta la fecha límite» and «A tu manera»',
  sources: [..._planSources, 'lib/screens/subscription_screen.dart'],
);

const planLine = Screen(
  'reminders',
  'task-line',
  'A task with a plan: one line where its reminder shows (`/taskDetails`)',
  sources: ['lib/screens/task_detail_screen.dart', ..._planSources],
);

const planCard = Screen(
  'reminders',
  'capture-card',
  'A dictation with a rhythm said: its «Recordatorio» row on the capture\'s card, or its line in a collapsed row; with no day, a line under the date asking for one',
  sources: [
    'lib/widgets/capture_review_editor.dart',
    'lib/models/task_draft.dart',
    ..._planSources,
  ],
);

const planOffer = Screen(
  'reminders',
  'offer',
  'After saving a task three weeks away: the reminder question offers a plan',
  sources: [
    'lib/widgets/reminder_ask_sheet.dart',
    'lib/l10n/reminder_plan_words.dart',
    'lib/services/reminder_plans.dart',
  ],
);

/// The owner's example, as the assistant reads it.
Map<String, dynamic> _ownWords(String said) => {
  'kind': 'custom',
  'phases': [
    {'from_days': 21, 'to_days': 8, 'every_days': 3},
    {'from_days': 7, 'to_days': 0, 'every_days': 1},
  ],
  'time': null,
  'said': said,
};

/// What a person says to «A tu manera», in the preview's language.
String _said(Preview p) => switch (p.variant.lang) {
  'ca' => 'cada 3 dies les dues primeres setmanes i després cada dia',
  'en' => 'every 3 days the first two weeks, then every day',
  _ => 'cada 3 días las dos primeras semanas y luego cada día',
};

/// A presentation three weeks away, or [days] away, with only a day, or at
/// [hour].
Task _presentation({ReminderPlan? plan, int days = 21, int? hour}) => Task(
  id: 90,
  title: 'Presentar el proyecto de empresa',
  dueDate: day(days, hour ?? 0),
  hasTime: hour != null,
  priority: 2,
  reminderPlan: plan,
);

/// «Terminar la presentación», three weeks away in the shared project
/// «Matemáticas»: for everyone («Todos»), or given to [assigneeName].
Task _sharedTask({int? assigneeId, String? assigneeName}) => Task(
  id: 90,
  title: 'Terminar la presentación',
  dueDate: day(21),
  hasTime: false,
  priority: 1,
  listId: matematicas.id,
  assignment: assigneeId == null ? 'group' : 'member',
  assigneeId: assigneeId,
  assigneeName: assigneeName,
);

/// The task's details, with its reminder line in view. Without [pro], an
/// account with free dictations, and the store answering for the Pro screen.
/// [task] stands in for the presentation; [at] for the preview's clock.
Future<PreviewApp> _detail(
  Preview p, {
  ReminderPlan? plan,
  bool pro = true,
  int days = 21,
  int? hour,
  Task? task,
  DateTime? at,
}) async {
  final app = await PreviewApp.open(
    p,
    pro: pro,
    user: pro ? null : account(freeLeft: 4),
    billing: pro ? null : (FakeRevenueCat()..info = billingInfo()),
    tasks: [
      ...normalDay(),
      task ?? _presentation(plan: plan, days: days, hour: hour),
    ],
    projects: allProjects,
    overrides: [
      if (at != null) calendarClockProvider.overrideWithValue(() => at),
    ],
  );
  await app.push('/taskDetails', arguments: 90);
  await p.tester.ensureVisible(find.byType(ReminderChip));
  await p.tester.pumpAndSettle();
  return app;
}

/// The task's reminder chip, tapped: the reminder sheet.
Future<void> _openSheet(PreviewApp app) async {
  await app.tester.tap(find.byType(ReminderChip));
  await app.tester.pumpAndSettle();
}

/// The owner's sentence, dictated: its result card, with the plan said.
Future<PreviewApp> _planCapture(
  Preview p, {
  ReminderPreferences reminders = const ReminderPreferences(
    enabled: true,
    asked: true,
  ),
}) async {
  final app = await PreviewApp.open(
    p,
    tasks: normalDay(),
    reminders: reminders,
  );
  const transcript =
      'Presentar el proyecto de empresa en tres semanas, recuérdamelo cada 3 días las dos primeras semanas y luego cada día';
  await resume(app, [
    CaptureDraft.fromAI(
      TaskDraft.fromJson({
        ...serverTask('Presentar el proyecto de empresa', date: day(21)),
        'reminder_plan': _ownWords(
          'cada 3 días las dos primeras semanas y luego cada día',
        ),
        'transcript': transcript,
      }),
    ),
  ], transcript: transcript);
  return app;
}

Future<void> _tapKey(PreviewApp app, String key) async {
  final target = find.byKey(ValueKey(key));
  await app.tester.ensureVisible(target);
  await app.tester.pumpAndSettle();
  await app.tester.tap(target);
  await app.tester.pumpAndSettle();
}

void remindersPreviews() {
  previewArea('reminders', 'Reminder plans', () {
    // ------------------------------------------------------------ sheet
    preview(
      planSheet,
      'strength',
      '«Hasta la fecha límite» tapped: Suave · Normal · Intenso with Normal chosen, the plan in words, the strip of dots from today to the day, the count and the next reminder («13 avisos · próximo: mañana, 09:00»), and Listo.',
      [es1, es2, esDark, ca2, en2],
      (p) async {
        final app = await _detail(p);
        await _openSheet(app);
        await _tapKey(app, 'reminder-plan-until-day');
        await p.shoot();
      },
    );

    preview(
      planSheet,
      'strength-far',
      'The same as strength on a task 60 days away: Normal starts at most 4 weeks before the day, so the plan reads «Cada 3 días desde 4 semanas antes, y a diario la última semana», the dots run from that start to the day, and the count is «15 avisos · próximo: …» with the first reminder\'s day, 26 days before the task\'s. Under the strip, «Hoy» takes its own width and the task\'s day the rest of the row, right-aligned, each on one line (in Catalan at 2× too).',
      [es1, es2, ca2],
      (p) async {
        final app = await _detail(p, days: 60);
        await _openSheet(app);
        await _tapKey(app, 'reminder-plan-until-day');
        await p.shoot();
      },
    );

    preview(
      planSheet,
      'your-way',
      '«A tu manera» with Pro: the words typed, as the assistant read them (the field\'s example, «Por ejemplo: …», gives way to the plan), with what the plan gives and Listo, brought into view by the sheet itself.',
      [es1, es2, ca2],
      (p) async {
        final app = await _detail(p);
        app.api.handlers['POST ai/reminder-plan/'] = (data) => {
          'reminder_plan': _ownWords(data!['text'] as String),
        };
        await _openSheet(app);
        await _tapKey(app, 'reminder-plan-your-way');
        await p.tester.enterText(
          find.byKey(const ValueKey('reminder-plan-words')),
          _said(p),
        );
        await p.tester.testTextInput.receiveAction(TextInputAction.done);
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      planSheet,
      'your-way-listening',
      '«A tu manera» with Pro, while the phone listens: the words heard fill the field, with «Dejar de escuchar» and «Escuchando» kept in view under it.',
      [es1, es2],
      (p) async {
        final app = await _detail(p);
        await _openSheet(app);
        await _tapKey(app, 'reminder-plan-your-way');
        await _tapKey(app, 'reminder-plan-speak');
        app.speech.send('ready');
        app.speech.send('segment', text: _said(p));
        await p.tester.pump();
        await p.frames();
        await p.shoot();
      },
    );

    preview(
      planSheet,
      'your-way-listening-long',
      '«A tu manera» with Pro at 2×, while the phone listens to a long rhythm: the field grown to four lines and scrolled to its end, so it shows the newest words, «…por la mañana y por la tarde», on its last line; «Dejar de escuchar» and «Escuchando» still in view under it, with no scrolling of the sheet.',
      [es2],
      (p) async {
        final app = await _detail(p);
        await _openSheet(app);
        await _tapKey(app, 'reminder-plan-your-way');
        await _tapKey(app, 'reminder-plan-speak');
        app.speech.send('ready');
        app.speech.send('partial', text: 'cada 3 días las dos primeras');
        await p.tester.pump();
        app.speech.send(
          'partial',
          text:
              'cada 3 días las dos primeras semanas, luego cada día, y el '
              'último día por la mañana y por la tarde',
        );
        await p.tester.pump();
        await p.frames();
        await p.shoot();
      },
    );

    preview(
      planSheet,
      'your-way-free',
      'Without Pro: «A tu manera» with its Pro badge, under the single reminder and «Hasta la fecha límite».',
      [es1, es2, ca2],
      (p) async {
        final app = await _detail(p, pro: false);
        await _openSheet(app);
        await p.tester.ensureVisible(
          find.byKey(const ValueKey('reminder-plan-your-way')),
        );
        await p.tester.pumpAndSettle();
        await p.shoot();
        await _tapKey(app, 'reminder-plan-your-way');
        await p.shoot('pro-screen');
      },
      then: {
        'pro-screen':
            'The badge tapped: the Pro screen says first, as a heading, «Con Pro, pide los avisos con tus palabras:», then the example «una semana antes y el día antes a las 8».',
      },
    );

    preview(
      planSheet,
      'your-way-free-dictated',
      'Without Pro, a task whose rhythm was said while dictating, opened from its chip: «A tu manera» at the top, selected and open, with no badge: the plan in words, the dots, the count and Listo, and no field or «Dictarlo».',
      [es1, es2],
      (p) async {
        final app = await _detail(
          p,
          pro: false,
          plan: ReminderPlan.tryParse(_ownWords(_said(p))),
        );
        await _openSheet(app);
        await p.shoot();
      },
    );

    preview(
      planSheet,
      'tomorrow',
      'A task due tomorrow, without a plan: the title and the single reminder\'s rows only, with no «Hasta la fecha límite» or «A tu manera».',
      [es1],
      (p) async {
        final app = await _detail(p, days: 1);
        await _openSheet(app);
        await p.shoot();
      },
    );

    preview(
      planSheet,
      'shared',
      'A «Todos» task in the shared project «Matemáticas», «Terminar la presentación», three weeks away, «Hasta la fecha límite» open: under the title «Recordatorio», over every choice (the single reminder\'s rows and the plans), «Estos avisos son solo para ti.», since every reminder choice is each person\'s own. The title and the line stay put while the choices scroll under them; there is no line above Listo.',
      [es1, es2, ca2],
      (p) async {
        final app = await _detail(p, task: _sharedTask());
        await _openSheet(app);
        await _tapKey(app, 'reminder-plan-until-day');
        await p.shoot();
      },
    );

    preview(
      planLine,
      'given-to-someone',
      'The same task given to Ana, carrying this account\'s own «1 hora antes»: its reminders are Ana\'s, so the chip reads only «Recordatorio para Ana», at full contrast and with no outline, with no value and no tap.',
      [es1, ca2],
      (p) async {
        await _detail(
          p,
          task: _sharedTask(
            assigneeId: ana,
            assigneeName: 'Ana',
          ).copyWith(reminderMinutes: 60),
        );
        await p.shoot();
      },
    );

    preview(
      planSheet,
      'shared-repeating',
      'A «Todos» task in «Matemáticas», «Sacar la basura», every Monday at 17:00, opened from its chip: a repeating task gets the one-tap list, with «Estos avisos son solo para ti.» under «Recordatorio» and above its first row.',
      [es1, ca2],
      (p) async {
        final app = await _detail(
          p,
          task: Task(
            id: 90,
            title: 'Sacar la basura',
            dueDate: next(DateTime.monday).add(const Duration(hours: 17)),
            hasTime: true,
            priority: 1,
            recurrence: 'weekly',
            listId: matematicas.id,
            assignment: 'group',
          ),
        );
        await _openSheet(app);
        await p.shoot();
      },
    );

    // -------------------------------------------------------- task line
    preview(
      planLine,
      'strength',
      'A task with Normal: «Recordatorios normales hasta el jue 12 · próximo: mañana, 09:00» where its reminder shows: the strength named, and the next reminder\'s day and time.',
      [es1, es2, ca2],
      (p) async {
        await _detail(p, plan: const ReminderPlan.rhythm(ReminderPlan.normal));
        await p.shoot();
      },
    );

    preview(
      planLine,
      'own-words',
      'A task with a plan of its own words: «Recordatorios: cada 3 días, y a diario la última semana · próximo: mañana, 09:00», its rhythm in words and the next reminder\'s day and time.',
      [es1, es2],
      (p) async {
        await _detail(p, plan: ReminderPlan.tryParse(_ownWords(_said(p))));
        await p.shoot();
      },
    );

    preview(
      planLine,
      'timed-today',
      'A task today at 17:00 with Normal, at 9:41: «Recordatorios normales hasta hoy · próximo: hoy, 16:50». On a timed task\'s own day its plan rings at the task\'s usual reminder, 10 minutes before, not at the plan\'s 09:00.',
      [es1, es2],
      (p) async {
        await _detail(
          p,
          plan: const ReminderPlan.rhythm(ReminderPlan.normal),
          days: 0,
          hour: 17,
        );
        await p.shoot();
      },
    );

    preview(
      planLine,
      'own-time-today',
      '«Presentar el proyecto» today at 17:00 with the plan said «el mismo día a las 9», at 8:00: «Recordatorios: el mismo día · próximo: hoy, 09:00». A plan with a time of its own keeps it on the task\'s own day (D8), rather than ringing at the task\'s usual reminder, 16:50.',
      [es1, es2],
      (p) async {
        await _detail(
          p,
          task: Task(
            id: 90,
            title: 'Presentar el proyecto',
            dueDate: day(0, 17),
            hasTime: true,
            priority: 2,
            reminderPlan: ReminderPlan.custom(
              const [PlanPhase(0, 0, 1)],
              time: 540,
              said: 'el mismo día a las 9',
            ),
          ),
          at: day(0, 8),
        );
        await p.shoot();
      },
    );

    // ----------------------------------------------------- capture card
    preview(
      planCard,
      'plan',
      'Said: «Presentar el proyecto de empresa en tres semanas, recuérdamelo cada 3 días las dos primeras semanas y luego cada día». The plan shows in one «Recordatorio» row under the date, above «Más opciones», which has no subtitle; tapping it opens the reminder sheet.',
      [es1, es2, ca2],
      (p) async {
        await _planCapture(p);
        await p.shoot();
      },
    );

    preview(
      planCard,
      'needs-day',
      'Said: «Llamar a mamá, recuérdamelo cada día», with no day. The date line reads «Sin fecha», with «Para recordártelo, ponle un día.» under it, whose tap opens the date; there is no «Recordatorio» row.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: normalDay(),
          reminders: const ReminderPreferences(enabled: true, asked: true),
        );
        const transcript = 'Llamar a mamá, recuérdamelo cada día';
        await resume(app, [
          CaptureDraft.fromAI(
            TaskDraft.fromJson({
              ...serverTask('Llamar a mamá'),
              'reminder_plan': {
                'kind': 'custom',
                'phases': [
                  {'from_days': 366, 'to_days': 0, 'every_days': 1},
                ],
                'time': null,
                'said': 'cada día',
              },
              'reminder_needs_day': true,
              'transcript': transcript,
            }),
          ),
        ], transcript: transcript);
        await p.shoot();
      },
    );

    preview(
      planCard,
      'plan-reminders-off',
      'The same dictation with reminders off on this phone: the «Recordatorio» row keeps the plan\'s line, and «Activar recordatorios» shows under it.',
      [es2],
      (p) async {
        await _planCapture(
          p,
          reminders: const ReminderPreferences(asked: true),
        );
        final button = find.text(p.l.enableReminders);
        await p.tester.ensureVisible(button);
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      planCard,
      'several-plan',
      'Three things said at once, a weekly reminder said for the second: its collapsed row shows «Recordatorios: cada semana · próximo: …» with a bell under its date line; the other two rows show only their date.',
      [es1],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
        const transcript =
            'Comprar pan y leche hoy, presentar el proyecto de empresa en tres semanas, recuérdamelo cada semana, y recoger a los niños a las cinco';
        await resume(app, [
          for (final task in [
            serverTask('Comprar pan y leche', date: day(0)),
            {
              ...serverTask('Presentar el proyecto de empresa', date: day(21)),
              'reminder_plan': {
                'kind': 'custom',
                'phases': [
                  {'from_days': 21, 'to_days': 0, 'every_days': 7},
                ],
                'time': null,
                'said': 'cada semana',
              },
            },
            serverTask(
              'Recoger a los niños del colegio',
              date: day(0, 17),
              time: true,
            ),
          ])
            CaptureDraft.fromAI(
              TaskDraft.fromJson({...task, 'transcript': transcript}),
            ),
        ], transcript: transcript);
        await p.shoot();
      },
    );

    // ------------------------------------------------------------- offer
    preview(
      planOffer,
      'asked',
      'A task moved to three weeks away, with no plan and its reminder the default, reminders on: once its save message has gone, the task and its day («Presentar el proyecto de empresa · …»; at 2× the title is cut so the day stays, and TalkBack reads it whole), «Faltan 3 semanas. ¿Te aviso cada 3 días, y a diario la última semana?», «Sí, recuérdamelo» (Normal) and «Ahora no».',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), _presentation(days: 20)],
          projects: allProjects,
        );
        await app.push('/editTask', arguments: 90);
        // Only a save that moves the task's day offers a plan.
        final date = find.byKey(const ValueKey('task-date'));
        await p.tester.ensureVisible(date);
        await p.tester.pumpAndSettle();
        await p.tester.tap(date);
        await p.tester.pumpAndSettle();
        final calendar = find.byType(CalendarDatePicker);
        if (day(21).month != day(20).month) {
          await p.tester.tap(
            find.descendant(
              of: calendar,
              matching: find.byTooltip(
                MaterialLocalizations.of(
                  p.tester.element(calendar),
                ).nextMonthTooltip,
              ),
            ),
          );
          await p.tester.pumpAndSettle();
        }
        final target = find.descendant(
          of: calendar,
          matching: find.text('${day(21).day}'),
        );
        await p.tester.ensureVisible(target);
        await p.tester.pumpAndSettle();
        await p.tester.tap(target);
        await p.tester.pumpAndSettle();
        await p.tester.tap(find.byKey(const ValueKey('schedule-done')));
        await p.tester.pumpAndSettle();
        await p.tester.tap(find.byKey(const ValueKey('task-save')));
        await p.tester.pumpAndSettle();
        await p.tester.pump(FeedbackTimeout.defaultDuration);
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );
  });
}
