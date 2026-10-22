// Reminder plans in the app (Backend/docs/REMINDER_PLANS.md, «The sheet and
// the task»; DECISIONS.md «2026-10-22 — Reminder plans»): the reminder
// sheet's plans, «A tu manera» with and without Pro, the task's one line, the
// capture card's line, the form, and the offer after saving a far task.
import 'dart:async';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/reminder_plan.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/subscription_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/feedback_timeout.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/revenuecat_service.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/widgets/reminder_plan_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/billing_fixtures.dart';
import 'support/capture_fixtures.dart';
import 'support/design_fixtures.dart';
import 'support/reminder_fixtures.dart';

final es = lookupAppLocalizations(const Locale('es'));
final ca = lookupAppLocalizations(const Locale('ca'));

/// Thursday 22 October 2026, 10:00.
final now = DateTime(2026, 10, 22, 10);

/// Friday 13 November, 22 days away.
final friday13 = DateTime(2026, 11, 13);

final ownersPlan = ReminderPlan.tryParse({
  'kind': 'custom',
  'phases': [
    {'from_days': 21, 'to_days': 8, 'every_days': 3},
    {'from_days': 7, 'to_days': 0, 'every_days': 1},
  ],
  'time': null,
  'said': 'cada 3 días las dos primeras semanas y luego cada día',
})!;

Task presentation({
  int id = 1,
  ReminderPlan? plan,
  DateTime? day,
  String recurrence = 'none',
}) => Task(
  id: id,
  title: 'Presentar el proyecto',
  priority: 1,
  dueDate: day ?? friday13,
  hasTime: false,
  recurrence: recurrence,
  reminderPlan: plan,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Real fonts: the square test font makes Spanish copy far wider than it is.
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(
    () => platform.setMockMethodCallHandler(timeoutChannel, (_) async => null),
  );
  tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));

  Finder sheet() => find.byType(BottomSheet);
  Finder inSheet(Finder finder) =>
      find.descendant(of: sheet().last, matching: finder);
  Finder chipText(String text) =>
      find.descendant(of: find.byType(ReminderChip), matching: find.text(text));

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  /// The task's reminder chip opens the reminder sheet.
  Future<void> openSheet(WidgetTester tester) async {
    await tapVisible(tester, find.byType(ReminderChip));
    expect(sheet(), findsOneWidget);
  }

  group('the reminder sheet', () {
    testWidgets(
      '«Hasta la fecha límite» opens Suave · Normal · Intenso with Normal chosen, and shows what it gives before Listo applies it',
      (tester) async {
        final app = await _App.open(tester, [presentation()]);
        await app.detail(1);
        await openSheet(tester);
        // Today's single reminder is still one tap each.
        expect(inSheet(find.text(es.off)), findsOneWidget);
        expect(inSheet(find.text(es.chooseAlertTime)), findsOneWidget);
        // The plans, closed: a strength reads as it grows.
        expect(inSheet(find.text(es.reminderPlanUntilDay)), findsOneWidget);
        expect(
          inSheet(find.text('Cada vez más a menudo hasta el vie\u00a013')),
          findsOneWidget,
        );
        expect(inSheet(find.text(es.reminderPlanYourWay)), findsOneWidget);
        expect(find.byType(ChoiceChip), findsNothing);

        await tapVisible(tester, inSheet(find.text(es.reminderPlanUntilDay)));
        for (final strength in [
          es.reminderPlanGentle,
          es.reminderPlanNormal,
          es.reminderPlanIntense,
        ]) {
          expect(
            find.widgetWithText(ChoiceChip, strength),
            findsOneWidget,
            reason: strength,
          );
        }
        expect(
          tester
              .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, es.reminderPlanNormal),
              )
              .selected,
          isTrue,
        );
        expect(
          find.text('Cada 3 días, y a diario la última semana'),
          findsOneWidget,
        );
        expect(find.byType(PlanStrip), findsOneWidget);
        expect(
          find.text('13 avisos · el próximo sáb\u00a024, 09:00'),
          findsOneWidget,
        );
        // Nothing changes until Listo.
        expect(app.task(1).reminderPlan, isNull);

        await tapVisible(
          tester,
          find.byKey(const ValueKey('reminder-plan-apply')),
        );
        expect(sheet(), findsNothing);
        expect(
          app.task(1).reminderPlan,
          const ReminderPlan.rhythm(ReminderPlan.normal),
        );
        // The task's one line, where its reminder was.
        expect(
          chipText('Cada vez más a menudo hasta el vie\u00a013 · próximo: sáb\u00a024'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(ReminderChip),
            matching: find.byIcon(Icons.notifications_active_outlined),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('each strength shows its own rhythm and count', (tester) async {
      final app = await _App.open(tester, [presentation()]);
      await app.detail(1);
      await openSheet(tester);
      await tapVisible(tester, inSheet(find.text(es.reminderPlanUntilDay)));
      await tapVisible(
        tester,
        find.widgetWithText(ChoiceChip, es.reminderPlanIntense),
      );
      expect(
        find.text('Cada 2 días, y a diario las últimas 2 semanas'),
        findsOneWidget,
      );
      expect(find.text('19 avisos · el próximo mañana, 09:00'), findsOneWidget);
      await tapVisible(
        tester,
        find.widgetWithText(ChoiceChip, es.reminderPlanGentle),
      );
      expect(
        find.text('Cada semana, y a diario los últimos 3 días'),
        findsOneWidget,
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('reminder-plan-apply')),
      );
      expect(
        app.task(1).reminderPlan,
        const ReminderPlan.rhythm(ReminderPlan.gentle),
      );
    });

    testWidgets(
      'the choices are exclusive: a task with a plan opens on it, and a single reminder takes its place',
      (tester) async {
        final app = await _App.open(tester, [
          presentation(plan: const ReminderPlan.rhythm(ReminderPlan.intense)),
        ]);
        await app.detail(1);
        await openSheet(tester);
        // Opened on the plan in use, with its strength.
        expect(
          tester
              .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, es.reminderPlanIntense),
              )
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<ListTile>(
                find.byKey(const ValueKey('reminder-plan-until-day')),
              )
              .selected,
          isTrue,
        );
        // No single row is ticked while a plan is set.
        expect(inSheet(find.byIcon(Icons.check_rounded)), findsNothing);
        await tapVisible(tester, inSheet(find.text(es.off)));
        expect(sheet(), findsNothing);
        expect(app.task(1).reminderPlan, isNull);
        expect(app.task(1).reminderMinutes, -1);
      },
    );

    testWidgets('a repeating task gets only the list it has always had', (
      tester,
    ) async {
      await (await _App.open(tester, [
        presentation(day: DateTime(2026, 10, 23), recurrence: 'weekly'),
      ])).detail(1);
      await openSheet(tester);
      expect(inSheet(find.text(es.off)), findsOneWidget);
      expect(inSheet(find.text(es.reminderPlanUntilDay)), findsNothing);
      expect(inSheet(find.text(es.reminderPlanYourWay)), findsNothing);
    });
  });

  group('«A tu manera»', () {
    testWidgets(
      'without Pro it shows a Pro badge, and opens the Pro screen with what Pro gives here',
      (tester) async {
        await (await _App.open(tester, [presentation()], pro: false)).detail(1);
        await openSheet(tester);
        expect(inSheet(find.byType(ProBadge)), findsOneWidget);
        expect(inSheet(find.text(es.proBadge)), findsOneWidget);
        await tapVisible(tester, inSheet(find.text(es.reminderPlanYourWay)));
        expect(find.byType(SubscriptionScreen), findsOneWidget);
        expect(
          find.text('Con Pro, tus recordatorios a tu manera'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('reminder-plan-words')),
          findsNothing,
          reason: 'No field without Pro.',
        );
        // Back: the sheet is where it was.
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
        expect(sheet(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'with Pro, the words typed go to the assistant, and the plan it reads shows before Listo applies it',
      (tester) async {
        final app = await _App.open(tester, [presentation()]);
        app.api.answer = {'reminder_plan': ownersPlan.toJson()};
        await app.detail(1);
        await openSheet(tester);
        await tapVisible(tester, inSheet(find.text(es.reminderPlanYourWay)));
        expect(find.text(es.reminderPlanYourWayHint), findsOneWidget);
        expect(find.text(es.reminderPlanSpeak), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('reminder-plan-words')),
          '  cada 3 días y la última semana a diario ',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(app.api.requests.single, {
          'text': 'cada 3 días y la última semana a diario',
          'timezone': 'Europe/Madrid',
          'reference_time': now.toUtc().toIso8601String(),
          'anchor_date': '2026-11-13',
          'language': 'es',
        });
        expect(
          find.text('Cada 3 días, y a diario la última semana'),
          findsOneWidget,
        );
        expect(
          find.text('13 avisos · el próximo sáb\u00a024, 09:00'),
          findsOneWidget,
        );
        await tapVisible(
          tester,
          find.byKey(const ValueKey('reminder-plan-apply')),
        );
        expect(app.task(1).reminderPlan, ownersPlan);
        expect(
          chipText(
            'Cada 3 días, y a diario la última semana · próximo: sáb\u00a024',
          ),
          findsOneWidget,
        );
        // Opened again: the words and the plan are there.
        await openSheet(tester);
        expect(find.text(ownersPlan.said!), findsOneWidget);
        expect(
          find.byKey(const ValueKey('reminder-plan-apply')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'words that aren’t about reminders are asked for again; offline says it needs a connection while the strengths still work',
      (tester) async {
        final app = await _App.open(tester, [presentation()]);
        app.api.answer = {'reminder_plan': null, 'issue': 'unclear'};
        await app.detail(1);
        await openSheet(tester);
        await tapVisible(tester, inSheet(find.text(es.reminderPlanYourWay)));
        await tester.enterText(
          find.byKey(const ValueKey('reminder-plan-words')),
          'comprar pan',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.text(es.reminderPlanUnclear), findsOneWidget);
        expect(find.byKey(const ValueKey('reminder-plan-apply')), findsNothing);

        app.api.failure = ApiException(0, ApiClient.offlineMessage);
        await tester.enterText(
          find.byKey(const ValueKey('reminder-plan-words')),
          'cada 2 días',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.text(es.reminderPlanOffline), findsOneWidget);

        app.api.failure = ApiException(
          429,
          'Too many',
          null,
          const Duration(hours: 5),
        );
        await tester.enterText(
          find.byKey(const ValueKey('reminder-plan-words')),
          'cada 4 días',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.text(es.reminderPlanFailed), findsOneWidget);

        // Closed with words not read yet: they're there when it opens again.
        app.navigator.pop();
        await tester.pumpAndSettle();
        await openSheet(tester);
        await tapVisible(tester, inSheet(find.text(es.reminderPlanYourWay)));
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('reminder-plan-words')),
              )
              .controller!
              .text,
          'cada 4 días',
        );

        // The strengths need no connection.
        await tapVisible(tester, inSheet(find.text(es.reminderPlanUntilDay)));
        await tapVisible(
          tester,
          find.byKey(const ValueKey('reminder-plan-apply')),
        );
        expect(
          app.task(1).reminderPlan,
          const ReminderPlan.rhythm(ReminderPlan.normal),
        );
      },
    );

    testWidgets(
      'the microphone fills the field with the phone’s own recognizer, and stopping reads the words',
      (tester) async {
        final app = await _App.open(tester, [presentation()]);
        app.api.answer = {'reminder_plan': ownersPlan.toJson()};
        await app.detail(1);
        await openSheet(tester);
        await tapVisible(tester, inSheet(find.text(es.reminderPlanYourWay)));
        await tapVisible(
          tester,
          find.byKey(const ValueKey('reminder-plan-speak')),
        );
        expect(app.speech.starts, 1);
        expect(find.text(es.reminderPlanStopListening), findsOneWidget);
        expect(find.text(es.captureListening), findsOneWidget);
        String field() => tester
            .widget<TextField>(
              find.byKey(const ValueKey('reminder-plan-words')),
            )
            .controller!
            .text;
        app.speech.send('partial', text: 'cada 3 días');
        await tester.pump();
        expect(field(), 'cada 3 días');
        app.speech.send(
          'segment',
          text: 'cada 3 días las dos primeras semanas y luego cada día',
        );
        await tester.pump();
        expect(app.api.requests, isEmpty, reason: 'Not while listening.');
        expect(
          field(),
          'cada 3 días las dos primeras semanas y luego cada día',
        );
        await tapVisible(
          tester,
          find.byKey(const ValueKey('reminder-plan-speak')),
        );
        expect(
          app.api.requests.single['text'],
          'cada 3 días las dos primeras semanas y luego cada día',
        );
        expect(find.text(es.reminderPlanSpeak), findsOneWidget);
        expect(
          find.byKey(const ValueKey('reminder-plan-apply')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('without the microphone it says so, and typing still works', (
      tester,
    ) async {
      final app = await _App.open(tester, [presentation()]);
      app.speech.access = SpeechPermission.denied;
      await app.detail(1);
      await openSheet(tester);
      await tapVisible(tester, inSheet(find.text(es.reminderPlanYourWay)));
      await tapVisible(
        tester,
        find.byKey(const ValueKey('reminder-plan-speak')),
      );
      expect(find.text(es.reminderPlanMicOff), findsOneWidget);
      expect(app.speech.starts, 0);
      app.speech
        ..access = SpeechPermission.granted
        ..usable = false;
      await tapVisible(
        tester,
        find.byKey(const ValueKey('reminder-plan-speak')),
      );
      expect(find.text(es.reminderPlanCantListen), findsOneWidget);
      expect(find.byKey(const ValueKey('reminder-plan-words')), findsOneWidget);
    });

    testWidgets('a server that says Pro is needed opens the Pro screen', (
      tester,
    ) async {
      final app = await _App.open(tester, [presentation()]);
      app.api.failure = ApiException(402, 'Pro', {'code': 'pro_required'});
      await app.detail(1);
      await openSheet(tester);
      await tapVisible(tester, inSheet(find.text(es.reminderPlanYourWay)));
      await tester.enterText(
        find.byKey(const ValueKey('reminder-plan-words')),
        'cada día',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(SubscriptionScreen), findsOneWidget);
      expect(find.text(es.billingReasonReminderPlans), findsOneWidget);
    });
  });

  group('at 2× text', () {
    for (final (language, l) in [('es', es), ('ca', ca)]) {
      testWidgets(
        'the sheet with a strength, and with «A tu manera», fits a small phone in $language',
        (tester) async {
          final app = await _App.open(
            tester,
            [presentation()],
            language: language,
            textScale: 2,
            size: const Size(360, 800),
          );
          app.api.answer = {'reminder_plan': ownersPlan.toJson()};
          await app.detail(1);
          await openSheet(tester);
          await tapVisible(tester, inSheet(find.text(l.reminderPlanUntilDay)));
          expect(tester.takeException(), isNull);
          for (final strength in [
            l.reminderPlanGentle,
            l.reminderPlanNormal,
            l.reminderPlanIntense,
          ]) {
            expect(find.widgetWithText(ChoiceChip, strength), findsOneWidget);
          }
          final apply = find.byKey(const ValueKey('reminder-plan-apply'));
          await tester.ensureVisible(apply);
          await tester.pumpAndSettle();
          expect(apply.hitTestable(), findsOneWidget);
          expect(
            find.byKey(const ValueKey('reminder-plan-count')),
            findsOneWidget,
          );

          await tapVisible(tester, inSheet(find.text(l.reminderPlanYourWay)));
          await tester.enterText(
            find.byKey(const ValueKey('reminder-plan-words')),
            ownersPlan.said!,
          );
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(apply);
          await tester.pumpAndSettle();
          expect(apply.hitTestable(), findsOneWidget);
          await tester.tap(apply);
          await tester.pumpAndSettle();
          expect(app.task(1).reminderPlan, ownersPlan);
          // The task's line wraps; nothing is cut.
          expect(
            find.byKey(const ValueKey('reminder-plan-line')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('on the task', () {
    testWidgets(
      'one line only with a plan; reminders off says so, as for a single reminder',
      (tester) async {
        final app = await _App.open(tester, [
          presentation(plan: const ReminderPlan.rhythm(ReminderPlan.normal)),
          presentation(id: 2),
        ]);
        await app.detail(1);
        expect(
          chipText('Cada vez más a menudo hasta el vie\u00a013 · próximo: sáb\u00a024'),
          findsOneWidget,
        );
        app.navigator.pop();
        await tester.pumpAndSettle();
        await app.detail(2);
        expect(find.byKey(const ValueKey('reminder-plan-line')), findsNothing);
        // The 24-hour clock, as chosen.
        expect(chipText(es.reminderValue('09:00')), findsOneWidget);
      },
    );

    testWidgets(
      'with reminders off in Settings, a plan reads Sin recordatorio · Activar',
      (tester) async {
        await (await _App.open(
          tester,
          [presentation(plan: const ReminderPlan.rhythm(ReminderPlan.normal))],
          reminders: const ReminderPreferences(dateOnlyTime: 540, asked: true),
        )).detail(1);
        expect(chipText(es.noReminderTurnOn), findsOneWidget);
      },
    );

    testWidgets(
      'the form keeps the plan when saving other changes, and shows its line',
      (tester) async {
        final app = await _App.open(tester, [
          presentation(plan: const ReminderPlan.rhythm(ReminderPlan.normal)),
        ]);
        app.navigator.pushNamed('/editTask', arguments: 1);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('task-reminder-plan')),
          findsOneWidget,
        );
        expect(
          find.text('Cada vez más a menudo hasta el vie\u00a013 · próximo: sáb\u00a024'),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('task-title')),
          'Presentar el proyecto final',
        );
        await tester.tap(find.byKey(const ValueKey('task-save')));
        await tester.pumpAndSettle();
        expect(app.task(1).title, 'Presentar el proyecto final');
        expect(
          app.task(1).reminderPlan,
          const ReminderPlan.rhythm(ReminderPlan.normal),
        );
      },
    );
  });

  group('the capture’s card', () {
    testWidgets(
      'a plan read from a dictation shows as one line, and opens the same sheet',
      (tester) async {
        final captures = MemoryCaptures();
        final app = await _App.open(tester, const [], captures: captures);
        captures.current = CaptureSession(
          id: 'plan-capture',
          ownerKey: app.container.read(captureOwnerProvider),
          timezone: 'Europe/Madrid',
          capturedAt: now.toUtc(),
          status: 'ready',
          source: 'speech',
          transcript: 'Presentar el proyecto el 13…',
          drafts: [
            CaptureDraft.fromAI(
              TaskDraft.fromJson({
                'title': 'Presentar el proyecto',
                'scheduled_date': '2026-11-13',
                'priority': 1,
                'notes': '',
                'questions': [],
                'transcript': 'Presentar el proyecto el 13…',
                'reminder_plan': ownersPlan.toJson(),
              }),
            ),
          ],
        );
        await openCaptureResult(tester, 'plan-capture');
        expect(find.byType(VoiceTaskScreen), findsOneWidget);
        final line = find.text(
          'Cada 3 días, y a diario la última semana · próximo: sáb\u00a024',
        );
        expect(line, findsOneWidget);
        await tapVisible(tester, line);
        expect(find.text(es.reminderPlanUntilDay), findsOneWidget);
        // The plan of one's own is open, with its words.
        expect(find.text(ownersPlan.said!), findsOneWidget);
        await tapVisible(tester, find.text(es.reminderPlanUntilDay));
        await tapVisible(
          tester,
          find.byKey(const ValueKey('reminder-plan-apply')),
        );
        expect(
          find.text('Cada vez más a menudo hasta el vie\u00a013 · próximo: sáb\u00a024'),
          findsOneWidget,
        );
        expect(
          captures.current!.drafts.single.task.reminderPlan,
          const ReminderPlan.rhythm(ReminderPlan.normal),
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('the offer', () {
    var edits = 0;
    Future<void> saveEdit(WidgetTester tester, _App app, int id) async {
      app.navigator.pushNamed('/editTask', arguments: id);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Presentar el proyecto (${++edits})',
      );
      await tester.tap(find.byKey(const ValueKey('task-save')));
      await tester.pumpAndSettle();
      // The question waits for the save message to close.
      expect(find.byType(SnackBar), findsOneWidget);
      await tester.pump(FeedbackTimeout.defaultDuration);
      await tester.pumpAndSettle();
    }

    Finder offer() =>
        find.text('Faltan 3 semanas: ¿te lo recuerdo hasta entonces?');

    testWidgets(
      'after saving a task three weeks away, Sí sets Normal; it’s asked once per task',
      (tester) async {
        final app = await _App.open(tester, [presentation()]);
        await saveEdit(tester, app, 1);
        expect(offer(), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('reminder-plan-offer-yes')));
        await tester.pumpAndSettle();
        expect(
          app.task(1).reminderPlan,
          const ReminderPlan.rhythm(ReminderPlan.normal),
        );
        expect(
          find.text('Listo. Te lo recordaré hasta el vie\u00a013.'),
          findsOneWidget,
        );
        expect(app.reminders.offered, {1});
        // Its plan taken away and saved again: never asked again.
        await app.notifier.updateTask(app.task(1).copyWith(reminderPlan: null));
        await tester.pump(FeedbackTimeout.defaultDuration);
        await tester.pumpAndSettle();
        await saveEdit(tester, app, 1);
        expect(offer(), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Ahora no leaves the task as it was, and isn’t asked again', (
      tester,
    ) async {
      final app = await _App.open(tester, [presentation()]);
      await saveEdit(tester, app, 1);
      await tester.tap(find.text(es.reminderAskNotNow));
      await tester.pumpAndSettle();
      expect(app.task(1).reminderPlan, isNull);
      await saveEdit(tester, app, 1);
      expect(offer(), findsNothing);
    });

    testWidgets(
      'never when reminders are off, nor for a day under two weeks away',
      (tester) async {
        final off = await _App.open(
          tester,
          [presentation()],
          reminders: const ReminderPreferences(dateOnlyTime: 540, asked: true),
        );
        await saveEdit(tester, off, 1);
        expect(offer(), findsNothing);
        expect(off.reminders.offered, isEmpty);
      },
    );

    testWidgets('not for a day under two weeks away', (tester) async {
      final app = await _App.open(tester, [
        presentation(day: DateTime(2026, 11, 4)),
      ]);
      await saveEdit(tester, app, 1);
      expect(find.textContaining('¿te lo recuerdo'), findsNothing);
      expect(app.reminders.offered, isEmpty);
    });

    testWidgets(
      'after a dictation is added, a far task with no plan gets the offer',
      (tester) async {
        final captures = MemoryCaptures();
        final app = await _App.open(tester, const [], captures: captures);
        captures.tasks = app.container;
        captures.current = CaptureSession(
          id: 'far-capture',
          ownerKey: app.container.read(captureOwnerProvider),
          timezone: 'Europe/Madrid',
          capturedAt: now.toUtc(),
          status: 'ready',
          source: 'speech',
          transcript: 'Presentar el proyecto el 13 de noviembre',
          drafts: [
            CaptureDraft.fromAI(
              TaskDraft.fromJson({
                'title': 'Presentar el proyecto',
                'scheduled_date': '2026-11-13',
                'priority': 1,
                'notes': '',
                'questions': [],
                'transcript': 'Presentar el proyecto el 13 de noviembre',
              }),
            ),
          ],
        );
        await openCaptureResult(tester, 'far-capture');
        await saveCapture(tester);
        await tester.pump(FeedbackTimeout.defaultDuration);
        await tester.pumpAndSettle();
        expect(offer(), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('reminder-plan-offer-yes')));
        await tester.pumpAndSettle();
        final saved = app.container.read(taskProvider).requireValue.single;
        expect(
          saved.reminderPlan,
          const ReminderPlan.rhythm(ReminderPlan.normal),
        );
      },
    );
  });
}

/// The app on a phone with reminders allowed, on a fixed day, with the
/// assistant's reminder-plan answer and the phone's recognizer stood in for.
class _App {
  _App(this.tester, this.container, this.reminders, this.api, this.speech);
  final WidgetTester tester;
  final ProviderContainer container;
  final MemoryReminderStore reminders;
  final _PlanApi api;
  final _Speech speech;

  TaskNotifier get notifier => container.read(taskProvider.notifier);
  Task task(int id) =>
      container.read(taskProvider).requireValue.singleWhere((t) => t.id == id);
  NavigatorState get navigator =>
      tester.state<NavigatorState>(find.byType(Navigator).first);

  static Future<_App> open(
    WidgetTester tester,
    List<Task> tasks, {
    bool pro = true,
    String language = 'es',
    double textScale = 1,
    Size size = const Size(390, 844),
    ReminderPreferences reminders = const ReminderPreferences(
      enabled: true,
      dateOnlyTime: 540,
      asked: true,
    ),
    MemoryCaptures? captures,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = MemoryReminderStore(reminders);
    final api = _PlanApi();
    final speech = _Speech();
    final billing = SubscriptionController(
      FakeRevenueCat(),
      const BillingConfiguration(apiKey: 'test_fixture', supported: true),
    );
    await billing.setIdentity('owner', () async => 'owner-id');
    final container = designContainer(
      regionalStore: MemoryRegionalStore(
        RegionalPreferences(
          language: language,
          clock: ClockFormat.twentyFour,
          captureTimezone: 'Europe/Madrid',
        ),
      ),
      tasks: () => _Tasks(tasks),
      pro: pro,
      api: api,
      hadTask: true,
      overrides: [
        ...reminderOverrides(store, FakeReminderAccess(allowed: true)),
        calendarClockProvider.overrideWithValue(() => now),
        nativeSpeechProvider.overrideWithValue(speech),
        captureRecorderFactoryProvider.overrideWithValue(SilentRecorder.new),
        subscriptionProvider.overrideWith((_) => billing),
        billingConfigurationProvider.overrideWithValue(billing.configuration),
        if (captures != null) captureStoreProvider.overrideWithValue(captures),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    return _App(tester, container, store, api, speech);
  }

  /// Opens task [id]'s details.
  Future<void> detail(int id) async {
    navigator.pushNamed('/taskDetails', arguments: id);
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailScreen), findsOneWidget);
  }
}

/// Tasks in memory: a change shows at once.
class _Tasks extends DesignTaskNotifier {
  _Tasks(this.initial);
  final List<Task> initial;
  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = AsyncData([...initial]);
  }

  @override
  Future<void> showLocal() async {}
}

/// The assistant's `ai/reminder-plan/`: [answer], or [failure].
class _PlanApi extends OfflineApiClient {
  Object? answer;
  Object? failure;
  final requests = <Map<String, dynamic>>[];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    if (method == 'POST' && path == 'ai/reminder-plan/') {
      requests.add({...?data});
      if (failure case final error?) throw error;
      return answer;
    }
    throw ApiException(0, ApiClient.offlineMessage);
  }
}

/// The phone's own recognizer: allowed and ready unless a test says not;
/// [send] is what it hears.
class _Speech extends NativeSpeech {
  SpeechPermission access = SpeechPermission.granted;
  bool usable = true;
  int starts = 0;
  int? _run;
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);

  @override
  Future<SpeechCapability> capability({String? language}) async =>
      SpeechCapability(
        onDevice: true,
        language: language ?? 'es-ES',
        languageInstalled: usable,
      );
  @override
  Future<SpeechCapability> knownCapability(String language) =>
      capability(language: language);
  @override
  Stream<SpeechEvent> get events => _events.stream;
  @override
  Future<SpeechPermission> permission() async => access;
  @override
  Future<void> start(
    int id,
    String language, {
    List<String> hints = const [],
  }) async {
    starts++;
    _run = id;
  }

  void send(String kind, {String? text}) =>
      _events.add(SpeechEvent(_run!, kind, text: text));

  @override
  Future<void> stop(int id) async => send('ended');
  @override
  Future<void> cancel(int id) async {}
}
