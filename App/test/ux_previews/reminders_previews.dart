// Reminder plans (Backend/docs/REMINDER_PLANS.md): the reminder sheet with a
// strength and with «A tu manera» (Pro, and free with its badge), a task's
// one line, the capture card's line, and the offer after saving a far task.
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/reminder_plan.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/services/feedback_timeout.dart';
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
  'The reminder sheet of a task with a day: the single reminder as before, then «Hasta la fecha límite» and «A tu manera»',
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
  'A dictation with a rhythm said: its line on the capture\'s card',
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

/// A presentation three weeks away, with only a day.
Task _presentation({ReminderPlan? plan}) => Task(
  id: 90,
  title: 'Presentar el proyecto de empresa',
  dueDate: day(21),
  hasTime: false,
  priority: 2,
  reminderPlan: plan,
);

/// The task's details, with its reminder line in view. Without [pro], an
/// account with free dictations, and the store answering for the Pro screen.
Future<PreviewApp> _detail(
  Preview p, {
  ReminderPlan? plan,
  bool pro = true,
}) async {
  final app = await PreviewApp.open(
    p,
    pro: pro,
    user: pro ? null : account(freeLeft: 4),
    billing: pro ? null : (FakeRevenueCat()..info = billingInfo()),
    tasks: [
      ...normalDay(),
      _presentation(plan: plan),
    ],
    projects: allProjects,
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
      '«Hasta la fecha límite» tapped: Suave · Normal · Intenso with Normal chosen, the plan in words, the strip of dots from today to the day, the count and the next reminder, and Listo.',
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
      'your-way',
      '«A tu manera» with Pro: the words typed, as the assistant read them, with what the plan gives and Listo.',
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
        await p.tester.ensureVisible(
          find.byKey(const ValueKey('reminder-plan-apply')),
        );
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );

    preview(
      planSheet,
      'your-way-listening',
      '«A tu manera» with Pro, while the phone listens: the words heard fill the field, «Dejar de escuchar» and «Escuchando».',
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
            'The badge tapped: the Pro screen says first «Con Pro, tus recordatorios a tu manera».',
      },
    );

    // -------------------------------------------------------- task line
    preview(
      planLine,
      'strength',
      'A task with Normal: «Cada vez más a menudo hasta el … · próximo: …» where its reminder shows.',
      [es1, es2, ca2],
      (p) async {
        await _detail(p, plan: const ReminderPlan.rhythm(ReminderPlan.normal));
        await p.shoot();
      },
    );

    preview(
      planLine,
      'own-words',
      'A task with a plan of its own words: its rhythm in words, and the next reminder.',
      [es1, es2],
      (p) async {
        await _detail(p, plan: ReminderPlan.tryParse(_ownWords(_said(p))));
        await p.shoot();
      },
    );

    // ----------------------------------------------------- capture card
    preview(
      planCard,
      'plan',
      'Said: «Presentar el proyecto de empresa en tres semanas, recuérdamelo cada 3 días las dos primeras semanas y luego cada día». The plan shows as one line, like the other details; tapping it opens the reminder sheet.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(p, tasks: normalDay());
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
        await p.shoot();
      },
    );

    // ------------------------------------------------------------- offer
    preview(
      planOffer,
      'asked',
      'A task three weeks away saved without a plan, with reminders on: once its save message has gone, «Faltan 3 semanas: ¿te lo recuerdo hasta entonces?», Sí (Normal) and Ahora no.',
      [es1, es2, ca2],
      (p) async {
        final app = await PreviewApp.open(
          p,
          tasks: [...normalDay(), _presentation()],
          projects: allProjects,
        );
        await app.push('/editTask', arguments: 90);
        await p.tester.enterText(
          find.byKey(const ValueKey('task-title')),
          'Presentar el proyecto a la junta',
        );
        await p.tester.tap(find.byKey(const ValueKey('task-save')));
        await p.tester.pumpAndSettle();
        await p.tester.pump(FeedbackTimeout.defaultDuration);
        await p.tester.pumpAndSettle();
        await p.shoot();
      },
    );
  });
}
