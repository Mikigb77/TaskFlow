// Reminder plans in the app (Backend/docs/REMINDER_PLANS.md, «The sheet and
// the task»; DECISIONS.md «2026-10-22 — Reminder plans»): the reminder
// sheet's plans, «A tu manera» with and without Pro, the task's one line, the
// capture card's line, the form, and the offer after saving a far task.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/reminder_plan_words.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/reminder_plan.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/screens/subscription_screen.dart';
import 'package:agenda/screens/edit_task_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/feedback_timeout.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/reminder_engine.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/revenuecat_service.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/capture_command_cards.dart';
import 'package:agenda/widgets/capture_review_editor.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/widgets/reminder_plan_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/billing_fixtures.dart';
import 'support/capture_fixtures.dart';
import 'support/design_fixtures.dart';
import 'support/never_syncing_tasks.dart';
import 'support/phone_alerts.dart';
import 'support/reading_order.dart';
import 'support/reminder_fixtures.dart';

final es = lookupAppLocalizations(const Locale('es'));
final ca = lookupAppLocalizations(const Locale('ca'));
final en = lookupAppLocalizations(const Locale('en'));

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
          find.text('13 avisos · próximo: sáb\u00a024, 09:00'),
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
          chipText(
            'Recordatorios normales hasta el vie\u00a013 · próximo: sáb\u00a024, 09:00',
          ),
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
      expect(find.text('19 avisos · próximo: mañana, 09:00'), findsOneWidget);
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
          find.text('Con Pro, pide los avisos con tus palabras:'),
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
          find.text('13 avisos · próximo: sáb\u00a024, 09:00'),
          findsOneWidget,
        );
        await tapVisible(
          tester,
          find.byKey(const ValueKey('reminder-plan-apply')),
        );
        expect(app.task(1).reminderPlan, ownersPlan);
        expect(
          chipText(
            'Recordatorios: cada 3 días, y a diario la última semana · próximo: sáb\u00a024, 09:00',
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

        // Closed with words not read yet: they're there when it opens again,
        // «A tu manera» already open on them.
        app.navigator.pop();
        await tester.pumpAndSettle();
        await openSheet(tester);
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
          // The sheet brings what was read, and «Listo», into view itself.
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
          chipText(
            'Recordatorios normales hasta el vie\u00a013 · próximo: sáb\u00a024, 09:00',
          ),
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
          find.text(
            'Recordatorios normales hasta el vie\u00a013 · próximo: sáb\u00a024, 09:00',
          ),
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
          'Recordatorios: cada 3 días, y a diario la última semana · próximo: sáb\u00a024, 09:00',
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
          find.text(
            'Recordatorios normales hasta el vie\u00a013 · próximo: sáb\u00a024, 09:00',
          ),
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

  // P242: a reminder said while dictating is one «Recordatorio» row on the
  // capture's card, honest about this phone, shown in a collapsed row, and
  // never saved where it can't apply.
  group('P242', () {
    const small = Size(360, 800);
    // The test's tester, set by [card], for [top].
    late WidgetTester shown;
    const ownersLine =
        'Recordatorios: cada 3 días, y a diario la última semana · próximo: sáb 24, 09:00';

    /// The capture's result for [tasks], one draft each (`d1`, `d2`, …), on
    /// a 360×800 phone; saving adds them to the app's tasks.
    Future<(_App, MemoryCaptures)> card(
      WidgetTester tester,
      List<Task> tasks, {
      ReminderPreferences reminders = const ReminderPreferences(
        enabled: true,
        dateOnlyTime: 540,
        asked: true,
      ),
      FakeReminderAccess? access,
      String language = 'es',
      double textScale = 1,
    }) async {
      shown = tester;
      final captures = MemoryCaptures();
      final app = await _App.open(
        tester,
        const [],
        captures: captures,
        reminders: reminders,
        access: access,
        language: language,
        textScale: textScale,
        size: small,
      );
      captures.tasks = app.container;
      captures.current = CaptureSession(
        id: 'p242',
        ownerKey: app.container.read(captureOwnerProvider),
        timezone: 'Europe/Madrid',
        capturedAt: now.toUtc(),
        status: 'ready',
        source: 'speech',
        transcript: 'Presentar el proyecto…',
        drafts: [
          for (final (i, task) in tasks.indexed)
            CaptureDraft(id: 'd${i + 1}', task: task),
        ],
      );
      await openCaptureResult(tester, 'p242');
      expect(find.byType(VoiceTaskScreen), findsOneWidget);
      return (app, captures);
    }

    Task said({ReminderPlan? plan, DateTime? day, bool timed = false}) => Task(
      title: 'Presentar el proyecto',
      priority: 1,
      dueDate: day ?? friday13,
      hasTime: timed,
      reminderPlan: plan,
    );

    // The capture's result is itself a bottom sheet: the reminder sheet opens
    // over it, as a second one.
    Finder row([String id = 'd1']) =>
        find.byKey(ValueKey('draft-reminder-$id'));
    Finder options([String id = 'd1']) =>
        find.byKey(ValueKey('draft-options-$id'));
    Finder inRow(Finder finder, [String id = 'd1']) =>
        find.descendant(of: row(id), matching: finder);
    double top(Finder finder) => shown.getTopLeft(finder.first).dy;

    /// «Más opciones» shows its title and nothing under it.
    void noSubtitle() => expect(
      find.descendant(of: options(), matching: find.byType(Text)),
      findsOneWidget,
    );

    testWidgets(
      'UX-1805: a said plan is one «Recordatorio» row under the date, above «Más opciones», never twice',
      (tester) async {
        await card(tester, [said(plan: ownersPlan)]);
        expect(row(), findsOneWidget);
        // P270 (UX-2206): the plan's line names itself, alone in the row.
        expect(inRow(find.text(es.reminder)), findsNothing);
        expect(inRow(find.text(ownersLine)), findsOneWidget);
        expect(
          top(row()),
          greaterThan(top(find.byKey(const ValueKey('draft-schedule-d1')))),
        );
        expect(top(row()), lessThan(top(options())));
        // Reminders on and allowed: nothing to turn on.
        expect(find.text(es.enableReminders), findsNothing);
        noSubtitle();
        await tapVisible(tester, options());
        expect(find.text(es.reminder), findsNothing);
        expect(find.byType(ReminderControl), findsOneWidget);
        expect(find.text(ownersLine), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1805: changing the plan to a time, then to «Desactivado», keeps the row above «Más opciones»',
      (tester) async {
        final (_, captures) = await card(tester, [said(plan: ownersPlan)]);
        await tapVisible(tester, inRow(find.text(ownersLine)));
        await tapVisible(tester, inSheet(find.text(es.chooseAlertTime)));
        final picker = find.byType(TimePickerDialog);
        expect(picker, findsOneWidget);
        final fields = find.descendant(
          of: picker,
          matching: find.byType(TextField),
        );
        await tester.enterText(fields.at(0), '18');
        await tester.enterText(fields.at(1), '00');
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: picker, matching: find.byType(TextButton)).last,
        );
        await tester.pumpAndSettle();
        expect(picker, findsNothing);
        expect(row(), findsOneWidget);
        expect(inRow(find.text('18:00')), findsOneWidget);
        expect(top(row()), lessThan(top(options())));
        noSubtitle();
        expect(captures.current!.drafts.single.task.reminderTime, 18 * 60);
        expect(captures.current!.drafts.single.task.reminderPlan, isNull);

        await tapVisible(tester, inRow(find.text(es.reminder)));
        await tapVisible(tester, inSheet(find.text(es.off)));
        expect(row(), findsOneWidget);
        expect(inRow(find.text(es.off)), findsOneWidget);
        expect(top(row()), lessThan(top(options())));
        noSubtitle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1805: «una hora antes» said is the row «1 hora antes», changed in 2 taps with no scroll',
      (tester) async {
        final (_, captures) = await card(tester, [
          Task(
            title: 'Dentista',
            priority: 1,
            dueDate: DateTime(2026, 11, 12, 17),
            hasTime: true,
            reminderMinutes: 60,
          ),
        ]);
        expect(inRow(find.text(es.reminder)), findsOneWidget);
        expect(inRow(find.text(es.hourBefore)), findsOneWidget);
        expect(top(row()), lessThan(top(options())));
        noSubtitle();
        // Two taps, each on what is already in view.
        final value = inRow(find.text(es.hourBefore)).hitTestable();
        expect(value, findsOneWidget);
        await tester.tap(value);
        await tester.pumpAndSettle();
        final half = inSheet(find.text(es.minutesBefore(30))).hitTestable();
        expect(half, findsOneWidget);
        await tester.tap(half);
        await tester.pumpAndSettle();
        expect(sheet(), findsOneWidget);
        expect(inRow(find.text(es.minutesBefore(30))), findsOneWidget);
        expect(captures.current!.drafts.single.task.reminderMinutes, 30);
        noSubtitle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1805: a plain draft has no «Recordatorio» row; «Más opciones» keeps its reminder',
      (tester) async {
        await card(tester, [said()]);
        expect(row(), findsNothing);
        expect(find.text(es.reminder), findsNothing);
        expect(find.byType(ReminderControl), findsNothing);
        await tapVisible(tester, options());
        expect(find.byType(ReminderControl), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ReminderControl),
            matching: find.text(es.reminder),
          ),
          findsOneWidget,
        );
        expect(top(find.byType(ReminderControl)), greaterThan(top(options())));
        expect(tester.takeException(), isNull);
      },
    );

    for (final (name, reminders, allowed) in [
      (
        'reminders off on this phone',
        const ReminderPreferences(dateOnlyTime: 540, asked: true),
        true,
      ),
      (
        'notifications blocked by the phone',
        const ReminderPreferences(
          enabled: true,
          dateOnlyTime: 540,
          asked: true,
        ),
        false,
      ),
    ]) {
      testWidgets(
        'UX-1802: with $name the row keeps the plan’s line and offers «Activar recordatorios»',
        (tester) async {
          final phone = FakeReminderAccess(allowed: allowed);
          final (app, _) = await card(
            tester,
            [said(plan: ownersPlan)],
            reminders: reminders,
            access: phone,
          );
          expect(inRow(find.text(ownersLine)), findsOneWidget);
          final turnOn = inRow(find.text(es.enableReminders));
          expect(turnOn, findsOneWidget);
          expect(top(turnOn), greaterThan(top(inRow(find.text(ownersLine)))));
          await tapVisible(tester, turnOn);
          expect(phone.permissionRequests, 1);
          expect(app.reminders.value.enabled, isTrue);
          expect(app.reminders.value.asked, isTrue);
          expect(find.text(es.enableReminders), findsNothing);
          expect(inRow(find.text(ownersLine)), findsOneWidget);
          // The card keeps its draft.
          expect(find.byType(VoiceTaskScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-1802: turning reminders on from the row records the question as asked',
      (tester) async {
        final (app, _) = await card(
          tester,
          [said(plan: ownersPlan)],
          // Never asked: the default until the one-time question.
          reminders: const ReminderPreferences(),
          access: FakeReminderAccess(),
        );
        await tapVisible(tester, inRow(find.text(es.enableReminders)));
        expect(app.reminders.value.enabled, isTrue);
        expect(app.reminders.value.asked, isTrue);
        expect(find.text(es.enableReminders), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1805: a plan whose only reminder has passed says so; «10 minutos antes» replaces it',
      (tester) async {
        final passed = ReminderPlan.tryParse({
          'kind': 'custom',
          'phases': [
            {'from_days': 7, 'to_days': 7, 'every_days': 1},
          ],
          'time': null,
          'said': 'una semana antes',
        })!;
        final (_, captures) = await card(tester, [
          said(plan: passed, day: DateTime(2026, 10, 27, 10), timed: true),
        ]);
        expect(inRow(find.text(es.noReminderTimePassed)), findsOneWidget);
        await tapVisible(tester, inRow(find.text(es.noReminderTimePassed)));
        expect(sheet(), findsNWidgets(2));
        // The default lead here is 10 minutes, so its row says so.
        await tapVisible(
          tester,
          inSheet(find.textContaining(es.minutesBefore(10))),
        );
        expect(sheet(), findsOneWidget);
        expect(inRow(find.text(es.noReminderTimePassed)), findsNothing);
        expect(
          inRow(find.textContaining(es.minutesBefore(10))),
          findsOneWidget,
        );
        expect(captures.current!.drafts.single.task.reminderPlan, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1809: in a result of three, only the row with a plan shows its reminder line, which opens the sheet',
      (tester) async {
        final handle = tester.ensureSemantics();
        final weekly = ReminderPlan.tryParse({
          'kind': 'custom',
          'phases': [
            {'from_days': 21, 'to_days': 0, 'every_days': 7},
          ],
          'time': null,
          'said': 'cada semana',
        })!;
        await card(tester, [
          Task(
            title: 'Comprar pan y leche',
            priority: 1,
            dueDate: DateTime(2026, 10, 22),
            hasTime: false,
          ),
          said(plan: weekly),
          Task(
            title: 'Recoger a los niños del colegio',
            priority: 1,
            dueDate: DateTime(2026, 10, 22, 17),
            hasTime: true,
          ),
        ]);
        Finder line(String id) =>
            find.byKey(ValueKey('draft-reminder-line-$id'));
        expect(line('d1'), findsNothing);
        expect(line('d3'), findsNothing);
        expect(line('d2'), findsOneWidget);
        // Collapsed: no «Recordatorio» rows.
        expect(row('d2'), findsNothing);
        final words = find.descendant(
          of: line('d2'),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.data ?? '').startsWith(
                  'Recordatorios: cada semana · próximo:',
                ),
          ),
        );
        expect(words, findsOneWidget);
        final bell = find.descendant(
          of: line('d2'),
          matching: find.byIcon(Icons.notifications_active_outlined),
        );
        expect(bell, findsOneWidget);
        expect(tester.widget<Icon>(bell).size, 18);
        expect(
          find.descendant(
            of: find.byType(VoiceTaskScreen),
            matching: find.byIcon(Icons.notifications_active_outlined),
          ),
          findsOneWidget,
        );
        expect(
          top(line('d2')),
          greaterThan(top(find.byKey(const ValueKey('draft-schedule-d2')))),
        );
        // TalkBack reads its words, as a button.
        final text = tester.widget<Text>(words).data!;
        expect(
          tester.getSemantics(find.bySemanticsLabel(text)),
          isSemantics(label: text, isButton: true, hasTapAction: true),
        );
        await tapVisible(tester, line('d2'));
        expect(sheet(), findsNWidgets(2));
        expect(inSheet(find.text(es.reminderPlanUntilDay)), findsOneWidget);
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    testWidgets(
      'UX-1811: «Sin fecha» asks for the day under the date instead of the row, and the task saves with no plan',
      (tester) async {
        final (app, captures) = await card(tester, [said(plan: ownersPlan)]);
        await tapVisible(
          tester,
          find.byKey(const ValueKey('draft-schedule-d1')),
        );
        await tapVisible(
          tester,
          inSheet(find.widgetWithText(ChoiceChip, es.noDate)),
        );
        expect(row(), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('draft-reminder-needs-day-d1')),
            matching: find.text(es.reminderNeedsDay),
          ),
          findsOneWidget,
        );
        expect(inRow(find.text(ownersLine)), findsNothing);
        await saveCapture(tester);
        final saved = app.container
            .read(taskProvider)
            .requireValue
            .singleWhere((task) => task.title == 'Presentar el proyecto');
        expect(saved.dueDate, isNull);
        expect(saved.reminderPlan, isNull);
        expect(captures.current!.drafts.single.task.reminderPlan, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1811: a weekly repeat given on the card saves the task with no plan',
      (tester) async {
        final (app, _) = await card(tester, [said(plan: ownersPlan)]);
        await tapVisible(tester, options());
        await tapVisible(tester, find.byIcon(Icons.repeat_rounded));
        await tapVisible(
          tester,
          inSheet(find.byType(DropdownButtonFormField<String>)),
        );
        await tapVisible(tester, find.text(es.weekly).last);
        await tapVisible(
          tester,
          inSheet(find.widgetWithText(FilledButton, es.done)),
        );
        expect(sheet(), findsOneWidget);
        await saveCapture(tester);
        final saved = app.container
            .read(taskProvider)
            .requireValue
            .singleWhere((task) => task.title == 'Presentar el proyecto');
        expect(saved.recurrence, 'weekly');
        expect(saved.reminderPlan, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    for (final (language, l) in [('es', es), ('ca', ca)]) {
      testWidgets(
        'UX-1805: at 2× in $language the «Recordatorio» row and its whole line scroll into view, uncut',
        (tester) async {
          await card(
            tester,
            [said(plan: ownersPlan)],
            language: language,
            textScale: 2,
          );
          expect(tester.takeException(), isNull);
          // P270 (UX-2206): no «Recordatorio» over the plan's line.
          expect(inRow(find.text(l.reminder)), findsNothing);
          final texts = find.descendant(
            of: row(),
            matching: find.byType(RichText),
          );
          expect(texts, findsAtLeastNWidgets(2));
          final view = tester.view.physicalSize.height;
          for (final element in texts.evaluate().toList()) {
            final finder = find.byElementPredicate((e) => e == element);
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            final paragraph = tester.renderObject<RenderParagraph>(finder);
            final box = paragraph.localToGlobal(Offset.zero);
            expect(box.dy, greaterThanOrEqualTo(0));
            expect(box.dy + paragraph.size.height, lessThanOrEqualTo(view));
            final words = paragraph.text.toPlainText();
            if (words.isEmpty) continue;
            final last = paragraph
                .getBoxesForSelection(
                  TextSelection(
                    baseOffset: words.length - 1,
                    extentOffset: words.length,
                  ),
                )
                .last;
            expect(last.right, lessThanOrEqualTo(paragraph.size.width + 0.5));
            expect(last.bottom, lessThanOrEqualTo(paragraph.size.height + 0.5));
          }
          // The plan's line is there, in the row.
          expect(
            inRow(
              find.byWidgetPredicate(
                (w) =>
                    w is Text &&
                    (w.data ?? '').contains('·') &&
                    w.data != l.reminder,
              ),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    // P248 (UX-2016): a reminder changed inside «Más opciones» stays inside
    // «Más opciones», where the user changed it.
    Finder control() => find.byType(ReminderControl);
    Finder inControl(Finder finder) =>
        find.descendant(of: control(), matching: finder);

    /// Picks 18:00 in the open time picker.
    Future<void> pick18(WidgetTester tester) async {
      final picker = find.byType(TimePickerDialog);
      expect(picker, findsOneWidget);
      final fields = find.descendant(
        of: picker,
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '18');
      await tester.enterText(fields.at(1), '00');
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: picker, matching: find.byType(TextButton)).last,
      );
      await tester.pumpAndSettle();
      expect(picker, findsNothing);
    }

    /// [finder] lies wholly inside the card's scroll viewport and the screen.
    void inView(WidgetTester tester, Finder finder) {
      final box = tester.getRect(finder.first);
      final scrollable = find.ancestor(
        of: finder.first,
        matching: find.byType(Scrollable),
      );
      final viewport = tester.getRect(scrollable.first);
      expect(box.top, greaterThanOrEqualTo(viewport.top - 0.5));
      expect(box.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
      expect(box.top, greaterThanOrEqualTo(0));
      expect(box.bottom, lessThanOrEqualTo(small.height));
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'UX-2016: at ${scale == 1 ? '1×' : '2×'} a time chosen inside «Más opciones» stays below it, in view, reading «18:00»',
        (tester) async {
          final (_, captures) = await card(tester, [said()], textScale: scale);
          expect(row(), findsNothing);
          await tapVisible(tester, options());
          expect(control(), findsOneWidget);
          await tapVisible(tester, inControl(find.text(es.reminder)));
          await tapVisible(tester, inSheet(find.text(es.chooseAlertTime)));
          await pick18(tester);
          // The reminder sheet has closed: only the card's sheet is left.
          expect(sheet(), findsOneWidget);
          expect(control(), findsOneWidget);
          expect(row(), findsNothing);
          expect(top(control()), greaterThan(top(options())));
          final value = inControl(find.text('18:00'));
          expect(value, findsOneWidget);
          inView(tester, value);
          inView(tester, inControl(find.text(es.reminder)));
          expect(captures.current!.drafts.single.task.reminderTime, 18 * 60);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2016: «Desactivado» chosen inside «Más opciones» stays below it',
      (tester) async {
        await card(tester, [said()]);
        await tapVisible(tester, options());
        await tapVisible(tester, inControl(find.text(es.reminder)));
        await tapVisible(tester, inSheet(find.text(es.off)));
        expect(sheet(), findsOneWidget);
        expect(control(), findsOneWidget);
        expect(row(), findsNothing);
        expect(top(control()), greaterThan(top(options())));
        final value = inControl(find.text(es.off));
        expect(value, findsOneWidget);
        inView(tester, value);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2016: «una hora antes» said keeps its row above «Más opciones» after a change made in it',
      (tester) async {
        final (_, captures) = await card(tester, [
          Task(
            title: 'Dentista',
            priority: 1,
            dueDate: DateTime(2026, 11, 12, 17),
            hasTime: true,
            reminderMinutes: 60,
          ),
        ]);
        expect(top(row()), lessThan(top(options())));
        // A timed task offers leads, not «Elegir hora del aviso».
        await tapVisible(tester, inRow(find.text(es.reminder)));
        expect(inSheet(find.text(es.chooseAlertTime)), findsNothing);
        await tapVisible(tester, inSheet(find.text(es.minutesBefore(30))));
        expect(sheet(), findsOneWidget);
        expect(row(), findsOneWidget);
        expect(inRow(find.text(es.minutesBefore(30))), findsOneWidget);
        expect(top(row()), lessThan(top(options())));
        expect(captures.current!.drafts.single.task.reminderMinutes, 30);
        expect(tester.takeException(), isNull);
      },
    );

    // P250 (UX-2018): a reminder changed inside «Más opciones» still shows
    // once they're closed, at the end of their subtitle, and on a collapsed
    // row; a said reminder keeps UX-1805's empty subtitle.

    /// «Más opciones»' subtitle for draft [id], or null when only its title
    /// shows.
    String? optionsSubtitle([String id = 'd1']) {
      final words = [
        for (final text in shown.widgetList<Text>(
          find.descendant(of: options(id), matching: find.byType(Text)),
        ))
          if (text.data != es.reviewOptions) text.data,
      ];
      expect(words.length, lessThanOrEqualTo(1));
      return words.firstOrNull;
    }

    Finder subtitleText(String words, [String id = 'd1']) =>
        find.descendant(of: options(id), matching: find.text(words));

    /// Opens «Más opciones», chooses 18:00 in its «Recordatorio» and closes
    /// them again.
    Future<void> eighteenInsideOptions(
      WidgetTester tester, [
      String id = 'd1',
    ]) async {
      if (control().evaluate().isEmpty) await tapVisible(tester, options(id));
      expect(control(), findsOneWidget);
      await tapVisible(tester, inControl(find.text(es.reminder)));
      await tapVisible(tester, inSheet(find.text(es.chooseAlertTime)));
      await pick18(tester);
      expect(sheet(), findsOneWidget);
      // Still inside «Más opciones», below it, with no row above.
      expect(row(id), findsNothing);
      expect(top(control()), greaterThan(top(options(id))));
      await tapVisible(tester, options(id));
      expect(control(), findsNothing);
    }

    testWidgets(
      'UX-2018: 18:00 chosen inside «Más opciones» reads «Recordatorio: 18:00» in their subtitle once they are closed',
      (tester) async {
        final (_, captures) = await card(tester, [said()]);
        // Nothing said about reminders: no «Recordatorio» anywhere.
        expect(optionsSubtitle(), isNull);
        expect(row(), findsNothing);
        await eighteenInsideOptions(tester);
        expect(optionsSubtitle(), es.reminderValue('18:00'));
        expect(row(), findsNothing);
        expect(captures.current!.drafts.single.task.reminderTime, 18 * 60);
        // Reopened, the control is still below «Más opciones».
        await tapVisible(tester, options());
        expect(control(), findsOneWidget);
        expect(row(), findsNothing);
        expect(top(control()), greaterThan(top(options())));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2018: «Desactivado» chosen inside «Más opciones» reads «Recordatorio: Desactivado» in their subtitle',
      (tester) async {
        await card(tester, [said()]);
        expect(optionsSubtitle(), isNull);
        await tapVisible(tester, options());
        await tapVisible(tester, inControl(find.text(es.reminder)));
        await tapVisible(tester, inSheet(find.text(es.off)));
        expect(sheet(), findsOneWidget);
        expect(row(), findsNothing);
        await tapVisible(tester, options());
        expect(control(), findsNothing);
        expect(optionsSubtitle(), es.reminderValue(es.off));
        expect(row(), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2018: with priority high and 18:00 chosen, the subtitle reads the priority, then the reminder',
      (tester) async {
        await card(tester, [said()]);
        await tapVisible(tester, options());
        await tapVisible(tester, find.byType(DropdownButtonFormField<int>));
        await tapVisible(tester, find.text(es.high).last);
        expect(optionsSubtitle(), es.priorityValue(es.high));
        await eighteenInsideOptions(tester);
        expect(
          optionsSubtitle(),
          [es.priorityValue(es.high), es.reminderValue('18:00')].join(' · '),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2018: «una hora antes» said keeps its row above «Más opciones» and nothing about it in their subtitle, also after a change',
      (tester) async {
        await card(tester, [
          Task(
            title: 'Dentista',
            priority: 1,
            dueDate: DateTime(2026, 11, 12, 17),
            hasTime: true,
            reminderMinutes: 60,
          ),
        ]);
        expect(top(row()), lessThan(top(options())));
        expect(optionsSubtitle(), isNull);
        await tapVisible(tester, inRow(find.text(es.reminder)));
        await tapVisible(tester, inSheet(find.text(es.minutesBefore(30))));
        expect(inRow(find.text(es.minutesBefore(30))), findsOneWidget);
        expect(optionsSubtitle(), isNull);
        // Opened and closed again, «Más opciones» still says nothing.
        await tapVisible(tester, options());
        await tapVisible(tester, options());
        expect(optionsSubtitle(), isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2018: a said plan changed to 18:00 through its row adds nothing to «Más opciones»’ subtitle',
      (tester) async {
        await card(tester, [said(plan: ownersPlan)]);
        expect(optionsSubtitle(), isNull);
        await tapVisible(tester, inRow(find.text(ownersLine)));
        await tapVisible(tester, inSheet(find.text(es.chooseAlertTime)));
        await pick18(tester);
        expect(inRow(find.text('18:00')), findsOneWidget);
        expect(top(row()), lessThan(top(options())));
        expect(optionsSubtitle(), isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2018: in a result of two, 18:00 chosen inside the second’s «Más opciones» shows on its collapsed row; the first shows none',
      (tester) async {
        await card(tester, [
          Task(
            title: 'Comprar pan y leche',
            priority: 1,
            dueDate: DateTime(2026, 11, 10),
            hasTime: false,
          ),
          said(),
        ]);
        Finder line(String id) =>
            find.byKey(ValueKey('draft-reminder-line-$id'));
        Finder title(String words) => find.widgetWithText(TextButton, words);
        // Both collapsed, nothing said: no reminder lines.
        expect(line('d1'), findsNothing);
        expect(line('d2'), findsNothing);
        await tapVisible(tester, title('Presentar el proyecto'));
        expect(options('d2'), findsOneWidget);
        await eighteenInsideOptions(tester, 'd2');
        // Expanding the first collapses the second.
        await tapVisible(tester, title('Comprar pan y leche'));
        expect(options('d2'), findsNothing);
        expect(line('d2'), findsOneWidget);
        expect(
          find.descendant(
            of: line('d2'),
            matching: find.text(es.reminderValue('18:00')),
          ),
          findsOneWidget,
        );
        expect(
          top(line('d2')),
          greaterThan(top(find.byKey(const ValueKey('draft-schedule-d2')))),
        );
        // The first, unchanged, has no reminder line.
        expect(line('d1'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2018: in a result of three, a collapsed row left untouched shows no reminder line beside one changed inside «Más opciones»',
      (tester) async {
        await card(tester, [
          Task(
            title: 'Comprar pan y leche',
            priority: 1,
            dueDate: DateTime(2026, 11, 10),
            hasTime: false,
          ),
          said(),
          Task(
            title: 'Llamar a Marta',
            priority: 1,
            dueDate: DateTime(2026, 11, 11),
            hasTime: false,
          ),
        ]);
        Finder line(String id) =>
            find.byKey(ValueKey('draft-reminder-line-$id'));
        Finder title(String words) => find.widgetWithText(TextButton, words);
        await tapVisible(tester, title('Presentar el proyecto'));
        await eighteenInsideOptions(tester, 'd2');
        await tapVisible(tester, title('Llamar a Marta'));
        // d1 and d2 are collapsed now; only d2 was changed.
        expect(options('d1'), findsNothing);
        expect(options('d2'), findsNothing);
        expect(line('d1'), findsNothing);
        expect(
          find.descendant(
            of: line('d2'),
            matching: find.text(es.reminderValue('18:00')),
          ),
          findsOneWidget,
        );
        expect(line('d3'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2018: at 2× on 360×800 the subtitle «Recordatorio: 18:00» is whole and in view',
      (tester) async {
        await card(tester, [said()], textScale: 2);
        await eighteenInsideOptions(tester);
        final words = subtitleText(es.reminderValue('18:00'));
        expect(words, findsOneWidget);
        await tester.ensureVisible(words);
        await tester.pumpAndSettle();
        inView(tester, words);
        final paragraph = tester.renderObject<RenderParagraph>(words);
        expect(paragraph.didExceedMaxLines, isFalse);
        final plain = paragraph.text.toPlainText();
        expect(plain, es.reminderValue('18:00'));
        final last = paragraph
            .getBoxesForSelection(
              TextSelection(
                baseOffset: plain.length - 1,
                extentOffset: plain.length,
              ),
            )
            .last;
        expect(last.right, lessThanOrEqualTo(paragraph.size.width + 0.5));
        expect(last.bottom, lessThanOrEqualTo(paragraph.size.height + 0.5));
        expect(tester.takeException(), isNull);
      },
    );
  });

  // P243: a dictated plan shows as chosen for everyone, the chosen plan opens
  // in view, plans only where they help, and TalkBack hears the rows expand.
  group('P243', () {
    final untilDay = find.byKey(const ValueKey('reminder-plan-until-day'));
    final yourWay = find.byKey(const ValueKey('reminder-plan-your-way'));
    final apply = find.byKey(const ValueKey('reminder-plan-apply'));
    const rhythmWords = 'Cada 3 días, y a diario la última semana';

    bool selected(WidgetTester tester, Finder row) =>
        tester.widget<ListTile>(row).selected;

    /// The sheet's rows other than [except], none of which may be chosen.
    void noOtherRowSelected(WidgetTester tester, Finder except) {
      final chosen = tester.widget(except);
      for (final tile in tester.widgetList<ListTile>(
        inSheet(find.byType(ListTile)),
      )) {
        if (identical(tile, chosen)) continue;
        expect(tile.selected, isFalse, reason: '${tile.title}');
      }
    }

    /// A free account's sheet opened on the dictated rhythm: «A tu manera»
    /// chosen and open, the plan's preview and Listo, nothing that calls the
    /// assistant, and no Pro badge.
    void expectDictatedOpen(WidgetTester tester) {
      expect(inSheet(yourWay), findsOneWidget);
      expect(selected(tester, yourWay), isTrue);
      noOtherRowSelected(tester, yourWay);
      final preview = inSheet(
        find.byKey(const ValueKey('reminder-plan-preview')),
      );
      expect(preview, findsOneWidget);
      expect(
        find.descendant(of: preview, matching: find.text(rhythmWords)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: preview, matching: find.byType(PlanStrip)),
        findsOneWidget,
      );
      final count = find.descendant(
        of: preview,
        matching: find.byKey(const ValueKey('reminder-plan-count')),
      );
      expect(count, findsOneWidget);
      expect(tester.widget<Text>(count).data, startsWith('13 '));
      expect(inSheet(apply), findsOneWidget);
      expect(find.text(es.done), findsWidgets);
      expect(find.byKey(const ValueKey('reminder-plan-words')), findsNothing);
      expect(find.byKey(const ValueKey('reminder-plan-speak')), findsNothing);
      expect(inSheet(find.text(es.reminderPlanSpeak)), findsNothing);
      expect(inSheet(find.byType(ProBadge)), findsNothing);
      expect(
        find.descendant(of: yourWay, matching: find.byType(ProBadge)),
        findsNothing,
      );
    }

    testWidgets(
      'UX-1801: a free account opens a dictated rhythm on «A tu manera», chosen and open, with its preview and Listo and nothing that asks the assistant',
      (tester) async {
        final app = await _App.open(
          tester,
          [presentation(plan: ownersPlan)],
          pro: false,
          size: const Size(360, 800),
        );
        await app.detail(1);
        await openSheet(tester);
        expectDictatedOpen(tester);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1801: free, Listo and Back both keep the dictated rhythm; a strength still replaces it',
      (tester) async {
        final app = await _App.open(
          tester,
          [presentation(plan: ownersPlan)],
          pro: false,
          size: const Size(360, 800),
        );
        await app.detail(1);
        await openSheet(tester);
        await tapVisible(tester, inSheet(apply));
        expect(sheet(), findsNothing);
        expect(app.task(1).reminderPlan, ownersPlan);

        await openSheet(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(sheet(), findsNothing);
        expect(app.task(1).reminderPlan, ownersPlan);

        await openSheet(tester);
        await tapVisible(tester, inSheet(find.text(es.reminderPlanUntilDay)));
        await tapVisible(
          tester,
          find.widgetWithText(ChoiceChip, es.reminderPlanNormal),
        );
        await tapVisible(tester, inSheet(apply));
        expect(sheet(), findsNothing);
        expect(
          app.task(1).reminderPlan,
          const ReminderPlan.rhythm(ReminderPlan.normal),
        );
      },
    );

    testWidgets(
      'UX-1801: free, the capture card’s dictated rhythm opens the same sheet',
      (tester) async {
        final captures = MemoryCaptures();
        final app = await _App.open(
          tester,
          const [],
          captures: captures,
          pro: false,
          size: const Size(360, 800),
        );
        captures.current = CaptureSession(
          id: 'free-plan-capture',
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
        await openCaptureResult(tester, 'free-plan-capture');
        await tapVisible(
          tester,
          find.text(
            'Recordatorios: cada 3 días, y a diario la última semana · próximo: sáb\u00a024, 09:00',
          ),
        );
        expectDictatedOpen(tester);
        await tapVisible(tester, inSheet(apply));
        expect(captures.current!.drafts.single.task.reminderPlan, ownersPlan);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1801: free, a task with no plan still shows the Pro badge on «A tu manera», which opens the Pro screen and has no expanded state',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await (await _App.open(tester, [presentation()], pro: false)).detail(1);
        await openSheet(tester);
        expect(
          find.descendant(of: yourWay, matching: find.byType(ProBadge)),
          findsOneWidget,
        );
        expect(selected(tester, yourWay), isFalse);
        expect(
          tester.getSemantics(yourWay),
          isSemantics(hasExpandedState: false),
        );
        await tapVisible(tester, yourWay);
        expect(find.byType(SubscriptionScreen), findsOneWidget);
        semantics.dispose();
      },
    );

    testWidgets(
      'UX-1801: Pro, the dictated rhythm’s section closed by a tap shows ✓ and its rhythm under «A tu manera»',
      (tester) async {
        final app = await _App.open(tester, [presentation(plan: ownersPlan)]);
        await app.detail(1);
        await openSheet(tester);
        // Opened on it.
        expect(
          find.byKey(const ValueKey('reminder-plan-words')),
          findsOneWidget,
        );
        await tapVisible(tester, yourWay);
        expect(find.byKey(const ValueKey('reminder-plan-words')), findsNothing);
        expect(selected(tester, yourWay), isTrue);
        expect(
          find.descendant(
            of: yourWay,
            matching: find.byIcon(Icons.check_rounded),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: yourWay, matching: find.text(rhythmWords)),
          findsOneWidget,
        );
        noOtherRowSelected(tester, yourWay);
      },
    );

    /// A task on Fri 13 Nov at 17:00: six single rows above the plans.
    Task timed(ReminderPlan plan) => Task(
      id: 1,
      title: 'Presentar el proyecto',
      priority: 1,
      dueDate: DateTime(2026, 11, 13, 17),
      hasTime: true,
      reminderPlan: plan,
    );

    /// The sheet's visible area.
    Rect sheetView(WidgetTester tester) =>
        tester.getRect(inSheet(find.byType(Scrollable)).first);

    /// [row] is at the top of the sheet's visible area, or as near it as the
    /// sheet scrolls: scrolled to its end, with [row] wholly in view.
    void expectAtTop(WidgetTester tester, Finder row) {
      final view = sheetView(tester);
      final rect = tester.getRect(row);
      final position = tester
          .state<ScrollableState>(inSheet(find.byType(Scrollable)).first)
          .position;
      expect(rect.top, greaterThanOrEqualTo(view.top - 1), reason: '$rect');
      expect(rect.bottom, lessThanOrEqualTo(view.bottom), reason: '$rect');
      if ((rect.top - view.top).abs() > 1) {
        expect(
          position.pixels,
          moreOrLessEquals(position.maxScrollExtent),
          reason: 'Not at the top ($rect in $view), yet it could scroll on.',
        );
      }
    }

    for (final pro in [true, false]) {
      testWidgets(
        'UX-1810: at 2× on 360 dp, a timed task opens with «A tu manera» at the top and its preview in view (${pro ? 'Pro' : 'free'})',
        (tester) async {
          final app = await _App.open(
            tester,
            [timed(ownersPlan)],
            pro: pro,
            textScale: 2,
            size: const Size(360, 800),
          );
          await app.detail(1);
          // Open the sheet without scrolling inside it.
          await tapVisible(tester, find.byType(ReminderChip));
          final view = sheetView(tester);
          // At the top, or as near it as the sheet scrolls: with Pro, the
          // field's example gives way to the plan read, so all of it fits.
          expectAtTop(tester, yourWay);
          final listo = tester.getRect(apply);
          expect(listo.bottom, lessThanOrEqualTo(view.bottom));
          final words = tester.getRect(
            inSheet(
              find.descendant(
                of: find.byKey(const ValueKey('reminder-plan-preview')),
                matching: find.text(rhythmWords),
              ),
            ),
          );
          expect(words.top, greaterThanOrEqualTo(view.top));
          expect(words.bottom, lessThanOrEqualTo(view.bottom));
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-1810: at 2× on 360 dp, a timed task with Normal opens with «Hasta la fecha límite» at the top and the three strengths in view',
      (tester) async {
        final app = await _App.open(
          tester,
          [timed(const ReminderPlan.rhythm(ReminderPlan.normal))],
          textScale: 2,
          size: const Size(360, 800),
        );
        await app.detail(1);
        await tapVisible(tester, find.byType(ReminderChip));
        final view = sheetView(tester);
        expectAtTop(tester, untilDay);
        for (final strength in [
          es.reminderPlanGentle,
          es.reminderPlanNormal,
          es.reminderPlanIntense,
        ]) {
          final chip = tester.getRect(
            find.widgetWithText(ChoiceChip, strength),
          );
          expect(chip.top, greaterThanOrEqualTo(view.top), reason: strength);
          expect(chip.bottom, lessThanOrEqualTo(view.bottom), reason: strength);
        }
        expect(tester.takeException(), isNull);
      },
    );

    for (final (name, day) in [
      ('today', DateTime(2026, 10, 22)),
      ('tomorrow', DateTime(2026, 10, 23)),
      ('yesterday', DateTime(2026, 10, 21)),
    ]) {
      testWidgets(
        'UX-1904: a task due $name without a plan gets only the title and the single rows',
        (tester) async {
          await (await _App.open(tester, [presentation(day: day)])).detail(1);
          await openSheet(tester);
          expect(inSheet(find.text(es.reminder)), findsOneWidget);
          expect(inSheet(find.text(es.off)), findsOneWidget);
          expect(inSheet(untilDay), findsNothing);
          expect(inSheet(yourWay), findsNothing);
          expect(inSheet(find.text(es.reminderPlanUntilDay)), findsNothing);
          expect(inSheet(find.text(es.reminderPlanYourWay)), findsNothing);
          expect(inSheet(find.byType(Divider)), findsNothing);
          // A date-only task's single rows: default, off, pick a time.
          expect(inSheet(find.byType(ListTile)), findsNWidgets(3));
        },
      );
    }

    testWidgets('UX-1904: a task due in 2 days gets both plans', (
      tester,
    ) async {
      await (await _App.open(tester, [
        presentation(day: DateTime(2026, 10, 24)),
      ])).detail(1);
      await openSheet(tester);
      expect(inSheet(untilDay), findsOneWidget);
      expect(inSheet(yourWay), findsOneWidget);
    });

    testWidgets(
      'UX-1904: a task due tomorrow that has Normal keeps both plans, Normal chosen',
      (tester) async {
        await (await _App.open(tester, [
          presentation(
            day: DateTime(2026, 10, 23),
            plan: const ReminderPlan.rhythm(ReminderPlan.normal),
          ),
        ])).detail(1);
        await openSheet(tester);
        expect(inSheet(untilDay), findsOneWidget);
        expect(inSheet(yourWay), findsOneWidget);
        expect(selected(tester, untilDay), isTrue);
      },
    );

    testWidgets(
      'UX-1907: the plan rows report collapsed and expanded, as ExpansionTile does; the strip’s ends aren’t read',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await (await _App.open(tester, [presentation()])).detail(1);
        await openSheet(tester);
        final strings = MaterialLocalizations.of(tester.element(untilDay));

        void expectState(Finder row, {required bool open}) {
          expect(
            tester.getSemantics(row),
            isSemantics(
              hasExpandedState: true,
              isExpanded: open,
              hint: open ? strings.collapsedHint : strings.expandedHint,
            ),
            reason: '$row open: $open',
          );
          expect(
            tester.getSemantics(row).hintOverrides?.onTapHint,
            open
                ? strings.expansionTileExpandedTapHint
                : strings.expansionTileCollapsedTapHint,
          );
        }

        expectState(untilDay, open: false);
        expectState(yourWay, open: false);
        await tapVisible(tester, untilDay);
        expectState(untilDay, open: true);

        // The count says it in words: «Hoy» and the task's day aren't read.
        expect(find.byType(PlanStrip), findsOneWidget);
        final stops = readingOrder(tester).map((s) => s.label).toList();
        final day = planDay(
          friday13,
          now,
          'es',
        ).replaceAll(RegExp(r'\s+'), ' ');
        final strays = [
          for (final stop in stops)
            if (RegExp('(^| )${es.today}( |\$)').hasMatch(stop) ||
                stop.contains(day))
              stop,
        ];
        // The preview is read: its words and its count.
        expect(
          stops.where((stop) => stop.contains(rhythmWords)),
          isNotEmpty,
          reason: stops.join(' | '),
        );
        expect(
          stops.where((stop) => stop.startsWith('13 ')),
          isNotEmpty,
          reason: stops.join(' | '),
        );
        expect(strays, isEmpty, reason: stops.join(' | '));

        await tapVisible(tester, yourWay);
        expectState(yourWay, open: true);
        expectState(untilDay, open: false);
        semantics.dispose();
      },
    );
  });

  // ---- Run 2026-10-22-changes, round 1 · P247: outside the sheet ----
  group('P247', () {
    /// A free account's Pro screen, opened from «A tu manera · Pro».
    Future<void> openProScreen(
      WidgetTester tester,
      AppLocalizations l, {
      String language = 'es',
      double textScale = 1,
      Size size = const Size(390, 844),
    }) async {
      await (await _App.open(
        tester,
        [presentation()],
        pro: false,
        language: language,
        textScale: textScale,
        size: size,
      )).detail(1);
      await openSheet(tester);
      await tapVisible(tester, inSheet(find.text(l.reminderPlanYourWay)));
      expect(find.byType(SubscriptionScreen), findsOneWidget);
    }

    final reason = find.byKey(const ValueKey('subscription-reason'));
    final example = find.byKey(const ValueKey('subscription-reason-example'));

    String textOf(WidgetTester tester, Finder finder) =>
        tester.widget<Text>(finder).data!;

    testWidgets(
      'UX-2007: the Pro screen says what «A tu manera» does, as a heading, then its example, then the usual line',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await openProScreen(tester, es);
        expect(textOf(tester, reason), es.billingReasonReminderPlans);
        expect(es.billingReasonReminderPlans, endsWith(':'));
        expect(
          es.billingReasonReminderPlans,
          isNot(contains(es.reminderPlanYourWay.toLowerCase())),
          reason: 'It says what it does, not the row’s name again.',
        );
        // The example, in « » and with no final period.
        final words = textOf(tester, example);
        expect(words, es.billingReasonReminderPlansExample);
        expect(words, startsWith('«'));
        expect(words, endsWith('»'));
        // Then the line Pro already had.
        final intro = find.text(es.billingIntro);
        expect(intro, findsOneWidget);
        expect(
          tester.getTopLeft(reason).dy,
          lessThan(tester.getTopLeft(example).dy),
        );
        expect(
          tester.getTopLeft(example).dy,
          lessThan(tester.getTopLeft(intro).dy),
        );
        // TalkBack reads the reason alone, as a heading, not merged into the
        // whole card.
        final heading = tester.getSemantics(reason).getSemanticsData();
        expect(heading.label, es.billingReasonReminderPlans);
        expect(heading.flagsCollection.isHeader, isTrue);
        final said = tester.getSemantics(example).getSemanticsData();
        expect(said.label, es.billingReasonReminderPlansExample);
        expect(said.flagsCollection.isHeader, isFalse);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    for (final (language, l) in [('es', es), ('ca', ca)]) {
      testWidgets(
        'UX-2007: at 2× on 360×800 the reason, its example and «Ver suscripción» are all on screen ($language)',
        (tester) async {
          await openProScreen(
            tester,
            l,
            language: language,
            textScale: 2,
            size: const Size(360, 800),
          );
          expect(tester.takeException(), isNull);
          const screen = Rect.fromLTWH(0, 0, 360, 800);
          final paywall = find.byKey(const ValueKey('subscription-paywall'));
          expect(paywall, findsOneWidget, reason: 'The pinned button shows.');
          for (final (name, finder) in [
            ('reason', reason),
            ('example', example),
            ('Ver suscripción', paywall),
          ]) {
            final rect = tester.getRect(finder);
            expect(
              screen.contains(rect.topLeft) &&
                  screen.contains(rect.bottomRight - const Offset(1, 1)),
              isTrue,
              reason: '$name at $rect is cut off',
            );
          }
          expect(paywall.hitTestable(), findsOneWidget);
          // Nothing on top of the reason or its example.
          expect(reason.hitTestable(), findsOneWidget);
          expect(example.hitTestable(), findsOneWidget);
          expect(
            tester.getRect(example).bottom,
            lessThanOrEqualTo(tester.getRect(paywall).top),
          );
        },
      );
    }

    for (final (language, l, open, close) in [
      ('en', en, '“', '”'),
      ('ca', ca, '«', '»'),
    ]) {
      testWidgets(
        'UX-2007: the reason and its example in ${language == 'en' ? 'English' : 'Catalan'}',
        (tester) async {
          await openProScreen(tester, l, language: language);
          expect(textOf(tester, reason), l.billingReasonReminderPlans);
          expect(l.billingReasonReminderPlans, endsWith(':'));
          final words = textOf(tester, example);
          expect(words, l.billingReasonReminderPlansExample);
          expect(words, startsWith(open));
          expect(words, endsWith(close));
          expect(words, isNot(endsWith('.')));
          expect(
            tester.getTopLeft(reason).dy,
            lessThan(tester.getTopLeft(example).dy),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    // ---- Run 2026-10-22-changes, round 2 · P249 ----

    /// The words inside the outer quotes of «A tu manera»'s helper, quotes
    /// included: «Por ejemplo: «…».» → «…».
    String helperExample(AppLocalizations l, String open, String close) {
      final hint = l.reminderPlanYourWayHint;
      final start = hint.indexOf(open);
      final end = hint.lastIndexOf(close);
      expect(start, greaterThanOrEqualTo(0), reason: 'helper: $hint');
      expect(end, greaterThan(start), reason: 'helper: $hint');
      return hint.substring(start, end + close.length);
    }

    testWidgets(
      'UX-2017: the Pro screen\'s example is «A tu manera»\'s own, between the heading and the usual line (es, 1×)',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await openProScreen(tester, es);
        // The heading, for TalkBack.
        expect(textOf(tester, reason), es.billingReasonReminderPlans);
        final heading = tester.getSemantics(reason).getSemanticsData();
        expect(heading.flagsCollection.isHeader, isTrue);
        // The next line: the field's own example, in « », no final period.
        final words = textOf(tester, example);
        expect(words, helperExample(es, '«', '»'));
        expect(words, startsWith('«'));
        expect(words, endsWith('»'));
        expect(words, isNot(endsWith('.')));
        expect(words, isNot(contains(es.reminderPlanEveryDays(3))));
        expect(words, isNot(contains(es.reminderPlanEveryDays(1))));
        // Then billingIntro.
        final intro = find.text(es.billingIntro);
        expect(intro, findsOneWidget);
        expect(
          tester.getTopLeft(reason).dy,
          lessThan(tester.getTopLeft(example).dy),
        );
        expect(
          tester.getTopLeft(example).dy,
          lessThan(tester.getTopLeft(intro).dy),
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    test(
      'UX-2017: in es, en and ca the Pro example is the helper\'s example, and no free strength\'s rhythm',
      () {
        for (final (language, l, open, close) in [
          ('es', es, '«', '»'),
          ('en', en, '“', '”'),
          ('ca', ca, '«', '»'),
        ]) {
          final words = l.billingReasonReminderPlansExample;
          expect(
            words,
            helperExample(l, open, close),
            reason: '$language: the Pro example is the field’s own',
          );
          expect(words, isNot(endsWith('.')), reason: language);
          expect(
            words.toLowerCase(),
            isNot(contains(l.reminderPlanEveryDays(3).toLowerCase())),
            reason: '$language: Normal’s rhythm is free',
          );
        }
        // The literal forms the acceptance check names.
        expect(
          es.billingReasonReminderPlansExample,
          isNot(contains('cada 3 días')),
        );
        expect(
          en.billingReasonReminderPlansExample,
          isNot(contains('every 3 days')),
        );
        expect(
          ca.billingReasonReminderPlansExample,
          isNot(contains('cada 3 dies')),
        );
      },
    );

    for (final (language, l) in [('es', es), ('ca', ca)]) {
      testWidgets(
        'UX-2017: at 2× on 360×800 the heading, the new example and the pinned button are on screen, unclipped ($language)',
        (tester) async {
          await openProScreen(
            tester,
            l,
            language: language,
            textScale: 2,
            size: const Size(360, 800),
          );
          expect(tester.takeException(), isNull);
          expect(textOf(tester, example), helperExample(l, '«', '»'));
          const screen = Rect.fromLTWH(0, 0, 360, 800);
          final paywall = find.byKey(const ValueKey('subscription-paywall'));
          expect(paywall, findsOneWidget);
          expect(
            find.descendant(
              of: paywall,
              matching: find.text(l.billingViewPlans),
            ),
            findsOneWidget,
            reason:
                'The pinned button says «Ver suscripción» / «Mostra la subscripció».',
          );
          for (final (name, finder) in [
            ('heading', reason),
            ('example', example),
            ('button', paywall),
          ]) {
            final rect = tester.getRect(finder);
            expect(
              screen.contains(rect.topLeft) &&
                  screen.contains(rect.bottomRight - const Offset(1, 1)),
              isTrue,
              reason: '$name at $rect is cut off',
            );
            expect(finder.hitTestable(), findsOneWidget, reason: name);
          }
          // Neither text is cut short or ellipsised.
          for (final finder in [reason, example]) {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: finder, matching: find.byType(RichText)),
            );
            expect(paragraph.didExceedMaxLines, isFalse);
          }
          expect(
            tester.getRect(example).bottom,
            lessThanOrEqualTo(tester.getRect(paywall).top),
          );
        },
      );
    }

    // ---- Run 2026-10-22-changes, round 3 · P251 ----

    test(
      'UX-2019, UX-2020: in es, en and ca the helper and the Pro example keep the time phrase together with no-break spaces',
      () {
        for (final (language, l, open, close, preposition, spaces) in [
          ('es', es, '«', '»', 'a\u00A0las', 2),
          ('en', en, '“', '”', 'at', 1),
          ('ca', ca, '«', '»', 'a\u00A0les', 2),
        ]) {
          for (final (key, value) in [
            ('reminderPlanYourWayHint', l.reminderPlanYourWayHint),
            (
              'billingReasonReminderPlansExample',
              l.billingReasonReminderPlansExample,
            ),
          ]) {
            expect(
              value,
              contains('$preposition 8'),
              reason: '$language $key: «$preposition» and «8» joined',
            );
            expect(
              value,
              isNot(contains('$preposition 8')),
              reason: '$language $key: no plain space before the hour',
            );
            expect(
              ' '.allMatches(value).length,
              spaces,
              reason: '$language $key: only the time phrase’s spaces changed',
            );
          }
          // Still the helper's own example, quotes included.
          expect(
            l.billingReasonReminderPlansExample,
            helperExample(l, open, close),
            reason: '$language: the Pro example is the field’s own',
          );
        }
        // The words are the same as before.
        expect(
          es.billingReasonReminderPlansExample.replaceAll(' ', ' '),
          '«una semana antes y el día antes a las 8»',
        );
        expect(
          en.billingReasonReminderPlansExample.replaceAll(' ', ' '),
          '“a week before, and the day before at 8”',
        );
        expect(
          ca.billingReasonReminderPlansExample.replaceAll(' ', ' '),
          '«una setmana abans i el dia abans a les 8»',
        );
      },
    );

    for (final textScale in [1.0, 2.0]) {
      testWidgets(
        'UX-2019: on the Pro screen at ${textScale.toInt()}× on 360×800 (es), «a las 8»» stays together on the example’s last line',
        (tester) async {
          await openProScreen(
            tester,
            es,
            textScale: textScale,
            size: const Size(360, 800),
          );
          expect(tester.takeException(), isNull);
          expect(textOf(tester, example), es.billingReasonReminderPlansExample);
          final lines = _expectHourKeptWithPreposition(
            tester,
            example,
            'a\u00A0las',
          );
          if (textScale == 2) {
            expect(
              lines,
              greaterThan(1),
              reason: 'At 2× the example wraps, so where it breaks matters.',
            );
          }
        },
      );
    }

    testWidgets(
      'UX-2019: on the Pro screen at 2× on 360×800 (ca), «a les 8»» stays together, and the heading, the example and «Mostra la subscripció» are on screen, unclipped',
      (tester) async {
        await openProScreen(
          tester,
          ca,
          language: 'ca',
          textScale: 2,
          size: const Size(360, 800),
        );
        expect(tester.takeException(), isNull);
        expect(textOf(tester, example), ca.billingReasonReminderPlansExample);
        final lines = _expectHourKeptWithPreposition(
          tester,
          example,
          'a\u00A0les',
        );
        expect(lines, greaterThan(1));

        const screen = Rect.fromLTWH(0, 0, 360, 800);
        final paywall = find.byKey(const ValueKey('subscription-paywall'));
        expect(
          find.descendant(
            of: paywall,
            matching: find.text(ca.billingViewPlans),
          ),
          findsOneWidget,
        );
        for (final (name, finder) in [
          ('heading', reason),
          ('example', example),
          ('button', paywall),
        ]) {
          final rect = tester.getRect(finder);
          expect(
            screen.contains(rect.topLeft) &&
                screen.contains(rect.bottomRight - const Offset(1, 1)),
            isTrue,
            reason: '$name at $rect is cut off',
          );
          expect(finder.hitTestable(), findsOneWidget, reason: name);
        }
        for (final finder in [reason, example]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: finder, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
        }
      },
    );

    testWidgets(
      'UX-2019: on the Pro screen at 1× on 360×800 (en), “at 8”” stays together',
      (tester) async {
        await openProScreen(
          tester,
          en,
          language: 'en',
          size: const Size(360, 800),
        );
        expect(tester.takeException(), isNull);
        expect(textOf(tester, example), en.billingReasonReminderPlansExample);
        _expectHourKeptWithPreposition(tester, example, 'at');
      },
    );

    /// Ajustes › Recordatorios with reminders on, and «Tareas sin hora» at
    /// [dateOnlyTime]; returns the row's subtitle.
    Future<String> dateOnlyRow(
      WidgetTester tester,
      List<Task> tasks, {
      int? dateOnlyTime,
      String language = 'es',
      ClockFormat clock = ClockFormat.twentyFour,
    }) async {
      final app = await _App.open(
        tester,
        tasks,
        language: language,
        clock: clock,
        reminders: ReminderPreferences(
          enabled: true,
          dateOnlyTime: dateOnlyTime,
          asked: true,
        ),
      );
      app.navigator.pushNamed('/notifications');
      await tester.pumpAndSettle();
      final l = lookupAppLocalizations(Locale(language));
      final row = find.widgetWithText(ListTile, l.dateOnlyTasks);
      expect(row, findsOneWidget);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      return (tester.widget<ListTile>(row).subtitle! as Text).data!;
    }

    /// [hour]:00 as the app's clock writes it on the Recordatorios screen.
    String hourOnScreen(WidgetTester tester, String row, int hour) =>
        TimeOfDay(hour: hour, minute: 0).format(tester.element(find.text(row)));

    final normal = presentation(
      plan: const ReminderPlan.rhythm(ReminderPlan.normal),
    );

    testWidgets(
      'UX-2011: «Tareas sin hora» off with an open task on Normal says plans still ring at 9:00',
      (tester) async {
        final subtitle = await dateOnlyRow(tester, [normal]);
        final time = hourOnScreen(tester, es.dateOnlyTasks, 9);
        expect(time, anyOf('9:00', '09:00'));
        expect(subtitle, es.dateOnlyOffPlans(time));
        expect(subtitle, startsWith('${es.off} · '));
        expect(subtitle, contains('«${es.reminderPlanUntilDay}»'));
        expect(subtitle, endsWith(time));
        expect(find.text(subtitle), findsOneWidget);
      },
    );

    testWidgets(
      'UX-2011: in English on a 12-hour clock it reads Off · “Until the deadline”: 9:00 AM',
      (tester) async {
        final subtitle = await dateOnlyRow(
          tester,
          [normal],
          language: 'en',
          clock: ClockFormat.twelve,
        );
        expect(
          // The clock may write a no-break space before AM.
          subtitle.replaceAll(RegExp(r'\s'), ' '),
          'Off · “Until the deadline”: 9:00 AM',
        );
      },
    );

    testWidgets(
      'UX-2011: in Catalan it reads Desactivat · «Fins al termini»: 9:00',
      (tester) async {
        final subtitle = await dateOnlyRow(tester, [normal], language: 'ca');
        expect(subtitle, startsWith('${ca.off} · «'));
        expect(
          subtitle,
          ca.dateOnlyOffPlans(hourOnScreen(tester, ca.dateOnlyTasks, 9)),
        );
        expect(subtitle, contains('9:00'));
      },
    );

    for (final (name, tasks) in [
      ('no task has a plan', [presentation()]),
      (
        'the only planned task is done',
        [
          Task(
            id: 1,
            title: 'Presentar el proyecto',
            priority: 1,
            dueDate: friday13,
            hasTime: false,
            isCompleted: true,
            reminderPlan: const ReminderPlan.rhythm(ReminderPlan.normal),
          ),
        ],
      ),
      (
        'the only plan has its own time',
        [
          presentation(
            plan: const ReminderPlan.rhythm(ReminderPlan.normal, time: 600),
          ),
        ],
      ),
    ]) {
      testWidgets('UX-2011: when $name the row reads «Desactivado» alone', (
        tester,
      ) async {
        expect(await dateOnlyRow(tester, tasks), es.off);
      });
    }

    testWidgets(
      'UX-2011: with «Tareas sin hora» at 8:00 the row reads 8:00, as before',
      (tester) async {
        final subtitle = await dateOnlyRow(tester, [normal], dateOnlyTime: 480);
        expect(subtitle, hourOnScreen(tester, es.dateOnlyTasks, 8));
        expect(subtitle, anyOf('8:00', '08:00'));
        expect(find.textContaining(es.reminderPlanUntilDay), findsNothing);
      },
    );
  });

  group('the offer', () {
    /// An edit save moving task [id] to [to] (Fri 13 Nov) from the day
    /// before: only a save that gives a task its day, or moves it, offers.
    Future<void> saveEdit(
      WidgetTester tester,
      _App app,
      int id, {
      DateTime? to,
    }) async {
      final day = to ?? friday13;
      await app.notifier.updateTask(
        app
            .task(id)
            .copyWith(dueDate: DateTime(day.year, day.month, day.day - 1)),
      );
      await tester.pumpAndSettle();
      app.navigator.pushNamed('/editTask', arguments: id);
      await tester.pumpAndSettle();
      final date = find.byKey(const ValueKey('task-date'));
      await tester.ensureVisible(date);
      await tester.pumpAndSettle();
      await tester.tap(date);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.text('${day.day}'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('task-save')));
      await tester.pumpAndSettle();
      // The question waits for the save message to close.
      expect(find.byType(SnackBar), findsOneWidget);
      await tester.pump(FeedbackTimeout.defaultDuration);
      await tester.pumpAndSettle();
    }

    Finder offer() => find.text(
      'Faltan 3 semanas. ¿Te aviso cada 3 días, y a diario la última semana?',
    );

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
      await saveEdit(tester, app, 1, to: DateTime(2026, 11, 4));
      expect(find.textContaining('¿Te aviso'), findsNothing);
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
  // P244 (UX-1803, UX-1808, UX-2003, UX-2008): the offer after saving comes
  // only when nothing was chosen and the task rings here alone, names the
  // task and what «Sí» gives, and its «Listo» has Deshacer.
  group('P244: the offer names the task and comes only when it should', () {
    const normal = ReminderPlan.rhythm(ReminderPlan.normal);
    const phone = Size(360, 800);
    // The task's title and its day as the app writes a day elsewhere
    // (taskDayLine, `weekdayDate`), read off the open sheet.
    String taskLine(WidgetTester tester) {
      final day = tester
          .element(find.byType(BottomSheet).last)
          .weekdayDate(friday13);
      expect(day, startsWith('vie, 13'));
      return 'Presentar el proyecto · $day';
    }

    const question =
        'Faltan 3 semanas. ¿Te aviso cada 3 días, y a diario la última semana?';

    Finder offerSheet() =>
        find.byKey(const ValueKey('reminder-plan-offer-yes'));
    Finder anyOffer() => find.textContaining('¿Te aviso');

    /// The save message's time, then whatever comes after it.
    Future<void> afterTheMessage(WidgetTester tester) async {
      await tester.pump(FeedbackTimeout.defaultDuration);
      await tester.pumpAndSettle();
    }

    /// A new task [title] on [day] in the form, saved; the offer, if any,
    /// isn't there yet while the save message shows.
    Future<void> createInForm(
      WidgetTester tester,
      _App app, {
      String title = 'Presentar el proyecto',
      DateTime? day,
    }) async {
      app.navigator.pushNamed(
        '/newTask',
        arguments: NewTaskArguments(day: day ?? friday13),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('task-title')), title);
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('task-save'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(offerSheet(), findsNothing);
    }

    /// Edits task [id] in the form: a new [title], or a new day [months]
    /// pages ahead in the date picker, on [dayOfMonth]; then saves.
    Future<void> editInForm(
      WidgetTester tester,
      _App app,
      int id, {
      String? title,
      int? dayOfMonth,
      int months = 0,
    }) async {
      app.navigator.pushNamed('/editTask', arguments: id);
      await tester.pumpAndSettle();
      if (title != null) {
        await tester.enterText(find.byKey(const ValueKey('task-title')), title);
        await tester.pumpAndSettle();
      }
      if (dayOfMonth != null) {
        final date = find.byKey(const ValueKey('task-date'));
        await tester.ensureVisible(date);
        await tester.pumpAndSettle();
        await tester.tap(date);
        await tester.pumpAndSettle();
        final picker = find.byType(CalendarDatePicker);
        final next = MaterialLocalizations.of(
          tester.element(picker),
        ).nextMonthTooltip;
        for (var page = 0; page < months; page++) {
          await tester.tap(
            find.descendant(of: picker, matching: find.byTooltip(next)),
          );
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.descendant(of: picker, matching: find.text('$dayOfMonth')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('schedule-done')));
        await tester.pumpAndSettle();
      }
      final save = find.byKey(const ValueKey('task-save'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
    }

    /// A dictation of [drafts], saved from its result.
    Future<_App> dictate(
      WidgetTester tester,
      String transcript,
      List<Map<String, Object?>> drafts,
    ) async {
      final captures = MemoryCaptures();
      final app = await _App.open(
        tester,
        const [],
        captures: captures,
        size: phone,
      );
      captures.tasks = app.container;
      captures.current = CaptureSession(
        id: 'p244-capture',
        ownerKey: app.container.read(captureOwnerProvider),
        timezone: 'Europe/Madrid',
        capturedAt: now.toUtc(),
        status: 'ready',
        source: 'speech',
        transcript: transcript,
        drafts: [
          for (final draft in drafts)
            CaptureDraft.fromAI(
              TaskDraft.fromJson({
                'priority': 1,
                'notes': '',
                'questions': [],
                'transcript': transcript,
                ...draft,
              }),
            ),
        ],
      );
      await openCaptureResult(tester, 'p244-capture');
      await saveCapture(tester);
      await afterTheMessage(tester);
      return app;
    }

    void expectOnScreen(WidgetTester tester, Finder finder, Size size) {
      expect(finder, findsOneWidget);
      final rect = tester.getRect(finder);
      expect(rect.top, greaterThanOrEqualTo(0), reason: '$finder');
      expect(rect.left, greaterThanOrEqualTo(0), reason: '$finder');
      expect(rect.bottom, lessThanOrEqualTo(size.height), reason: '$finder');
      expect(rect.right, lessThanOrEqualTo(size.width), reason: '$finder');
    }

    testWidgets(
      'UX-1808: after a new far task’s save message, the offer reads the task, '
      'the rhythm, «Sí, recuérdamelo» and «Ahora no», top to bottom',
      (tester) async {
        final app = await _App.open(tester, const [], size: phone);
        await createInForm(tester, app);
        await afterTheMessage(tester);
        final line = inSheet(find.text(taskLine(tester)));
        final asked = inSheet(find.text(question));
        final yes = inSheet(find.text(es.reminderAskYes));
        final notNow = inSheet(find.text(es.reminderAskNotNow));
        for (final finder in [line, asked, yes, notNow]) {
          expect(finder, findsOneWidget);
        }
        expect(es.reminderAskYes, 'Sí, recuérdamelo');
        final tops = [
          for (final finder in [line, asked, yes, notNow])
            tester.getTopLeft(finder).dy,
        ];
        expect(tops, [...tops]..sort());
        expect(tops.toSet(), hasLength(4));
        expect(
          find.byKey(const ValueKey('reminder-plan-offer-yes')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1808: TalkBack reads one header with the task line, then the '
      'question; the filled button says «Sí, recuérdamelo»',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final app = await _App.open(tester, const [], size: phone);
        await createInForm(tester, app);
        await afterTheMessage(tester);
        final stops = readingOrder(tester);
        final heading = stops
            .where((stop) => stop.label.contains(question))
            .toList();
        expect(heading, hasLength(1), reason: '$stops');
        expect(heading.single.label, '${taskLine(tester)} $question');
        expect(heading.single.live, isTrue);
        // Nothing else reads the task line on its own.
        expect(
          stops.where((stop) => stop.label.contains('Presentar el proyecto ·')),
          hasLength(1),
        );
        final node = tester.getSemantics(
          find.bySemanticsLabel(RegExp('^${RegExp.escape(taskLine(tester))}')),
        );
        expect(node.getSemanticsData().flagsCollection.isHeader, isTrue);
        expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
        final yes = tester.getSemantics(
          find.byKey(const ValueKey('reminder-plan-offer-yes')),
        );
        expect(yes.label, es.reminderAskYes);
        expect(yes.getSemanticsData().flagsCollection.isButton, isTrue);
        semantics.dispose();
      },
    );

    testWidgets(
      'UX-2008: «Sí, recuérdamelo» sets Normal; «Listo» offers Deshacer, '
      'which takes the plan off and the single reminder rings again',
      (tester) async {
        final app = await _App.open(tester, const [], size: phone);
        await createInForm(tester, app);
        await afterTheMessage(tester);
        final id = app.container
            .read(taskProvider)
            .requireValue
            .singleWhere((task) => task.title == 'Presentar el proyecto')
            .id!;
        await tester.tap(offerSheet());
        await tester.pumpAndSettle();
        expect(app.task(id).reminderPlan, normal);
        final done = es.reminderPlanOfferDone('vie 13');
        expect(done, 'Listo. Te lo recordaré hasta el vie 13.');
        expect(find.text(done), findsOneWidget);
        final undo = find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(es.undo),
        );
        expect(undo, findsOneWidget);
        await tester.tap(undo);
        await tester.pumpAndSettle();
        expect(app.task(id).reminderPlan, isNull);
        const on = ReminderPreferences(enabled: true, dateOnlyTime: 540);
        final planned = ReminderEngine.plan('owner', [app.task(id)], on, now);
        expect(planned.map((reminder) => reminder.identity), [
          ReminderEngine.identity('owner', app.task(id)),
        ]);
        expect(planned.single.when, DateTime(2026, 11, 13, 9));
        // Undone, it isn't asked again.
        expect(app.reminders.offered, {id});
        await editInForm(tester, app, id, dayOfMonth: 20);
        await afterTheMessage(tester);
        expect(anyOffer(), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2008: Deshacer shows the task without its plan at once, with a '
      'sync that never completes',
      (tester) async {
        final cloud = NeverSyncingTasks();
        final app = await _App.open(
          tester,
          const [],
          size: phone,
          notifier: () => TaskNotifier(cloud),
        );
        await createInForm(tester, app);
        await afterTheMessage(tester);
        final id = cloud.rows.single.id!;
        await tester.tap(offerSheet());
        await tester.pumpAndSettle();
        expect(cloud.byId(id)!.reminderPlan, normal);
        await tester.tap(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(es.undo),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(cloud.finished, 0);
        expect(cloud.byId(id)!.reminderPlan, isNull);
        final shown = app.task(id);
        expect(shown.reminderPlan, isNull);
        expect(shown.dueDate, friday13);
        expect(find.text(es.undoError), findsNothing);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'UX-1803: a far task with a reminder chosen (60 min) or a reminder '
      'time is never offered a plan, and keeps its reminder',
      (tester) async {
        final app = await _App.open(tester, [
          Task(
            id: 1,
            title: 'Dentista',
            priority: 1,
            dueDate: DateTime(2026, 11, 12, 17),
            hasTime: true,
            reminderMinutes: 60,
          ),
          presentation(
            id: 2,
            day: DateTime(2026, 11, 12),
          ).copyWith(reminderTime: 600),
        ], size: phone);
        // Both moved a day later: an edit that would otherwise offer.
        await editInForm(tester, app, 1, dayOfMonth: 13);
        await afterTheMessage(tester);
        expect(anyOffer(), findsNothing);
        expect(app.task(1).reminderMinutes, 60);
        expect(app.task(1).reminderPlan, isNull);
        await editInForm(tester, app, 2, dayOfMonth: 13);
        await afterTheMessage(tester);
        expect(anyOffer(), findsNothing);
        expect(app.task(2).reminderTime, 600);
        expect(app.task(2).reminderPlan, isNull);
        expect(app.reminders.offered, isEmpty);
      },
    );

    testWidgets(
      'UX-1803: «Dentista el 12 de noviembre a las 5, avísame una hora '
      'antes» saved brings no offer, and keeps its hour-before reminder',
      (tester) async {
        const said =
            'Dentista el 12 de noviembre a las 5, avísame una hora antes';
        final app = await dictate(tester, said, [
          {
            'title': 'Dentista',
            'due_date': DateTime(2026, 11, 12, 17).toUtc().toIso8601String(),
            'reminder_minutes': 60,
          },
        ]);
        expect(anyOffer(), findsNothing);
        expect(offerSheet(), findsNothing);
        final saved = app.container.read(taskProvider).requireValue.single;
        expect(saved.reminderMinutes, 60);
        expect(saved.reminderPlan, isNull);
        expect(app.reminders.offered, isEmpty);
      },
    );

    testWidgets(
      'UX-1803: an edit that changes only a far task’s title brings no offer',
      (tester) async {
        final app = await _App.open(tester, [presentation()], size: phone);
        await editInForm(tester, app, 1, title: 'Presentar el proyecto final');
        await afterTheMessage(tester);
        expect(anyOffer(), findsNothing);
        expect(app.task(1).title, 'Presentar el proyecto final');
        expect(app.task(1).reminderPlan, isNull);
        expect(app.reminders.offered, isEmpty);
      },
    );

    testWidgets(
      'UX-1803: an edit moving a task from tomorrow to Fri 13 Nov brings the '
      'offer',
      (tester) async {
        final app = await _App.open(tester, [
          presentation(day: DateTime(2026, 10, 23)),
        ], size: phone);
        await editInForm(tester, app, 1, dayOfMonth: 13, months: 1);
        expect(app.task(1).dueDate, friday13);
        expect(offerSheet(), findsNothing);
        await afterTheMessage(tester);
        expect(inSheet(find.text(taskLine(tester))), findsOneWidget);
        expect(inSheet(find.text(question)), findsOneWidget);
        expect(app.reminders.offered, {1});
      },
    );

    testWidgets(
      'UX-1808: after «Comprar pan mañana y presentar el proyecto el 13 de '
      'noviembre», the offer names «Presentar el proyecto», not the bread',
      (tester) async {
        const said =
            'Comprar pan mañana y presentar el proyecto el 13 de noviembre';
        await dictate(tester, said, [
          {'title': 'Comprar pan', 'scheduled_date': '2026-10-23'},
          {'title': 'Presentar el proyecto', 'scheduled_date': '2026-11-13'},
        ]);
        expect(inSheet(find.text(taskLine(tester))), findsOneWidget);
        expect(inSheet(find.text(question)), findsOneWidget);
        expect(inSheet(find.textContaining('Comprar pan')), findsNothing);
      },
    );

    // D6 (P256): a plan is each person's own, so the offer comes for any
    // task that rings on this phone, shared or not.
    group('UX-2003: only for a task that rings on this phone', () {
      final shared = TaskListInfo(
        id: 'team',
        name: 'Equipo',
        shared: true,
        ownerId: 1,
        people: const [
          ProjectMember(id: 1, name: 'Yo', role: 'owner'),
          ProjectMember(id: 2, name: 'Marta', role: 'editor'),
        ],
      );
      final muted = TaskListInfo(
        id: 'quiet',
        name: 'Silencio',
        notifications: 'muted',
      );
      final archived = TaskListInfo(id: 'old', name: 'Antiguo', archived: true);

      /// Task 1, a day before Fri 13 Nov in [listId] as [assignment], moved
      /// to Fri 13 Nov in the form: whether the offer came.
      Future<bool> offered(
        WidgetTester tester,
        String listId, {
        String assignment = 'personal',
        int? assigneeId,
      }) async {
        final app = await _App.open(
          tester,
          [
            presentation(day: DateTime(2026, 11, 12)).copyWith(
              listId: listId,
              assignment: assignment,
              assigneeId: assigneeId,
            ),
          ],
          size: phone,
          projects: [shared, muted, archived],
        );
        await editInForm(tester, app, 1, dayOfMonth: 13);
        expect(app.task(1).dueDate, friday13);
        await afterTheMessage(tester);
        final shown = find.text(question).evaluate().isNotEmpty;
        expect(app.reminders.offered.isNotEmpty, shown);
        return shown;
      }

      testWidgets('a «Todos» task in a shared project: the offer', (
        tester,
      ) async {
        expect(await offered(tester, 'team', assignment: 'group'), isTrue);
      });

      testWidgets('an unassigned task in a shared project I own: the offer', (
        tester,
      ) async {
        expect(await offered(tester, 'team', assignment: 'unassigned'), isTrue);
      });

      testWidgets('a task given to Marta in a shared project: no offer', (
        tester,
      ) async {
        expect(
          await offered(tester, 'team', assignment: 'member', assigneeId: 2),
          isFalse,
        );
      });

      testWidgets('a task assigned to me in a shared project: the offer', (
        tester,
      ) async {
        expect(
          await offered(tester, 'team', assignment: 'member', assigneeId: 1),
          isTrue,
        );
      });

      testWidgets('a personal task in a project muted here: no offer', (
        tester,
      ) async {
        expect(await offered(tester, 'quiet'), isFalse);
      });

      testWidgets('a personal task in an archived project: no offer', (
        tester,
      ) async {
        expect(await offered(tester, 'old'), isFalse);
      });
    });

    for (final language in ['es', 'ca']) {
      for (final size in const [Size(360, 800), Size(320, 640)]) {
        testWidgets(
          'UX-1808: at 2× on ${size.width.round()}×${size.height.round()} in '
          '$language, the task line, the question and both answers are on '
          'screen without scrolling',
          (tester) async {
            final strings = language == 'es' ? es : ca;
            final app = await _App.open(
              tester,
              const [],
              language: language,
              textScale: 2,
              size: size,
            );
            await createInForm(tester, app);
            await afterTheMessage(tester);
            expect(tester.takeException(), isNull);
            // The line may cut a long title, never the day: TalkBack reads
            // it whole.
            expectOnScreen(
              tester,
              inSheet(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is Text &&
                      (widget.semanticsLabel ?? widget.data ?? '').startsWith(
                        'Presentar el proyecto · ',
                      ),
                ),
              ),
              size,
            );
            expectOnScreen(
              tester,
              inSheet(
                find.textContaining(language == 'es' ? '¿Te aviso' : 'T’aviso'),
              ),
              size,
            );
            expectOnScreen(
              tester,
              inSheet(find.text(strings.reminderAskYes)),
              size,
            );
            expectOnScreen(
              tester,
              inSheet(find.text(strings.reminderAskNotNow)),
              size,
            );
            expect(offerSheet().hitTestable(), findsOneWidget);
            expect(
              inSheet(find.text(strings.reminderAskNotNow)).hitTestable(),
              findsOneWidget,
            );
          },
        );
      }
    }

    testWidgets(
      'UX-1808: in English, “3 weeks to go. Shall I remind you every 3 days, '
      'and daily for the last week?” and “Yes, remind me”',
      (tester) async {
        final app = await _App.open(
          tester,
          const [],
          language: 'en',
          size: phone,
        );
        await createInForm(tester, app);
        await afterTheMessage(tester);
        expect(
          inSheet(
            find.text(
              '3 weeks to go. Shall I remind you every 3 days, and daily for '
              'the last week?',
            ),
          ),
          findsOneWidget,
        );
        expect(en.reminderAskYes, 'Yes, remind me');
        expect(inSheet(find.text(en.reminderAskYes)), findsOneWidget);
      },
    );

    testWidgets(
      'UX-1808: in Catalan, «Falten 3 setmanes. T’aviso cada 3 dies, i cada '
      'dia l’última setmana?» and «Sí, recorda-m’ho»',
      (tester) async {
        final app = await _App.open(
          tester,
          const [],
          language: 'ca',
          size: phone,
        );
        await createInForm(tester, app);
        await afterTheMessage(tester);
        expect(
          inSheet(
            find.text(
              'Falten 3 setmanes. T’aviso cada 3 dies, i cada dia l’última '
              'setmana?',
            ),
          ),
          findsOneWidget,
        );
        expect(ca.reminderAskYes, 'Sí, recorda-m’ho');
        expect(inSheet(find.text(ca.reminderAskYes)), findsOneWidget);
      },
    );

    test('UX-1808: «reminderPlanOfferYes» is gone from the three catalogs', () {
      for (final language in ['en', 'es', 'ca']) {
        final catalog =
            jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
                as Map<String, dynamic>;
        expect(
          catalog.containsKey('reminderPlanOfferYes'),
          isFalse,
          reason: language,
        );
        expect(
          catalog.containsKey('@reminderPlanOfferYes'),
          isFalse,
          reason: language,
        );
      }
    });
  });
  // P241 (UX-1804, UX-1806, UX-1807, UX-1910): the plan's one line names
  // reminders and the strength, gives the next one's day and time, promises
  // only what will ring before the day, and the sheet's count reads as it.
  group('the plan’s line names it and promises only what will come', () {
    const normal = ReminderPlan.rhythm(ReminderPlan.normal);
    const phone = Size(360, 800);
    const normalLine =
        'Recordatorios normales hasta el vie 13 · próximo: sáb 24, 09:00';
    const ownLine =
        'Recordatorios: cada 3 días, y a diario la última semana · próximo: sáb 24, 09:00';

    Finder chipLabel() => find.descendant(
      of: find.byType(ReminderChip),
      matching: find.byType(Text),
    );
    String chipLine(WidgetTester tester) =>
        tester.widget<Text>(chipLabel().first).data!;
    Finder chipIcon(IconData icon) => find.descendant(
      of: find.byType(ReminderChip),
      matching: find.byIcon(icon),
    );

    testWidgets(
      'UX-1806, UX-1807: a Normal plan reads «Recordatorios normales hasta el vie 13 · próximo: sáb 24, 09:00»',
      (tester) async {
        await (await _App.open(tester, [
          presentation(plan: normal),
        ], size: phone)).detail(1);
        expect(chipLine(tester), normalLine);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1806: choosing Intenso, then Suave, shows the strength on the chip',
      (tester) async {
        final app = await _App.open(tester, [
          presentation(plan: normal),
        ], size: phone);
        await app.detail(1);
        for (final (strength, words) in [
          (es.reminderPlanIntense, 'intensos'),
          (es.reminderPlanGentle, 'suaves'),
        ]) {
          await openSheet(tester);
          if (find.widgetWithText(ChoiceChip, strength).evaluate().isEmpty) {
            await tapVisible(
              tester,
              inSheet(find.text(es.reminderPlanUntilDay)),
            );
          }
          await tapVisible(tester, find.widgetWithText(ChoiceChip, strength));
          await tapVisible(
            tester,
            find.byKey(const ValueKey('reminder-plan-apply')),
          );
          expect(sheet(), findsNothing);
          expect(
            chipLine(tester),
            startsWith('Recordatorios $words hasta el vie 13 · próximo: '),
            reason: strength,
          );
        }
        expect(
          app.task(1).reminderPlan,
          const ReminderPlan.rhythm(ReminderPlan.gentle),
        );
      },
    );

    testWidgets(
      'UX-1806, UX-1807: a plan of one’s own reads «Recordatorios: cada 3 días, … · próximo: sáb 24, 09:00»',
      (tester) async {
        await (await _App.open(tester, [
          presentation(plan: ownersPlan),
        ], size: phone)).detail(1);
        expect(chipLine(tester), ownLine);
      },
    );

    testWidgets(
      'UX-1807: in English with a 12-hour clock, the next reminder reads “Sat 24, 9:00 AM”',
      (tester) async {
        await (await _App.open(
          tester,
          [presentation(plan: ownersPlan)],
          size: phone,
          language: 'en',
          clock: ClockFormat.twelve,
        )).detail(1);
        expect(
          chipLine(tester),
          'Reminders: every 3 days, and daily for the last week · next: Sat 24, 9:00 AM',
        );
      },
    );

    testWidgets(
      'UX-1806: in Catalan it starts «Recordatoris: cada 3 dies, …»',
      (tester) async {
        await (await _App.open(
          tester,
          [presentation(plan: ownersPlan)],
          size: phone,
          language: 'ca',
        )).detail(1);
        expect(
          chipLine(tester),
          startsWith(
            'Recordatoris: cada 3 dies, i cada dia l’última setmana · proper: ',
          ),
        );
        expect(chipLine(tester), endsWith('09:00'));
      },
    );

    for (final (name, plan) in [
      ('Normal', normal),
      ('a plan of one’s own', ownersPlan),
    ]) {
      testWidgets(
        'UX-1806: with $name, the chip is one button whose spoken label starts with «Recordatorios»',
        (tester) async {
          final semantics = tester.ensureSemantics();
          await (await _App.open(tester, [
            presentation(plan: plan),
          ], size: phone)).detail(1);
          final spoken = find.descendant(
            of: find.byType(ReminderChip),
            matching: find.bySemanticsLabel(RegExp(r'^Recordatorios')),
            matchRoot: true,
          );
          expect(spoken, findsOneWidget);
          final node = tester.getSemantics(spoken);
          expect(node.label, startsWith('Recordatorios'));
          expect(node.flagsCollection.isButton, isTrue);
          semantics.dispose();
        },
      );
    }

    testWidgets(
      'UX-1804: after Completar the detail stays open and the chip reads the plan alone, with no «próximo»',
      (tester) async {
        final app = await _App.open(tester, [
          presentation(plan: normal),
        ], size: phone);
        await app.detail(1);
        await tapVisible(tester, find.text(es.complete));
        expect(app.task(1).isCompleted, isTrue);
        expect(find.byType(TaskDetailScreen), findsOneWidget);
        expect(chipLine(tester), 'Recordatorios normales hasta el vie 13');
        expect(find.textContaining('próximo'), findsNothing);
        await tester.pump(FeedbackTimeout.defaultDuration);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'UX-1804: on the task’s own day after its 9:00 notice, the chip says the time has passed, with the off bell, and the sheet says none are left',
      (tester) async {
        await (await _App.open(
          tester,
          [presentation(plan: normal)],
          size: phone,
          at: DateTime(2026, 11, 13, 10),
        )).detail(1);
        expect(chipLine(tester), es.noReminderTimePassed);
        expect(chipIcon(Icons.notifications_off_outlined), findsOneWidget);
        expect(find.textContaining('próximo'), findsNothing);
        await openSheet(tester);
        final count = find.byKey(const ValueKey('reminder-plan-count'));
        if (count.evaluate().isEmpty) {
          await tapVisible(tester, inSheet(find.text(es.reminderPlanUntilDay)));
        }
        expect(tester.widget<Text>(count).data, es.reminderPlanNoneLeft);
      },
    );

    testWidgets(
      'UX-1804: a week-before plan already past doesn’t promise the notice after the appointment; a single reminder takes its place',
      (tester) async {
        final weekBefore = ReminderPlan.tryParse({
          'kind': 'custom',
          'phases': [
            {'from_days': 7, 'to_days': 7, 'every_days': 1},
          ],
          'time': null,
          'said': 'recuérdamelo una semana antes',
        })!;
        final app = await _App.open(tester, [
          Task(
            id: 1,
            title: 'Dentista',
            priority: 1,
            dueDate: DateTime(2026, 10, 27, 10),
            reminderPlan: weekBefore,
          ),
        ], size: phone);
        await app.detail(1);
        expect(chipLine(tester), es.noReminderTimePassed);
        expect(chipIcon(Icons.notifications_off_outlined), findsOneWidget);
        expect(find.textContaining('mié 28'), findsNothing);
        await openSheet(tester);
        await tapVisible(
          tester,
          inSheet(find.textContaining(es.minutesBefore(10))),
        );
        expect(sheet(), findsNothing);
        expect(app.task(1).reminderPlan, isNull);
        expect(chipLine(tester), es.reminderValue(es.minutesBefore(10)));
      },
    );

    testWidgets(
      // D6 (P256): a plan is each person's own, so one kept on a task given
      // to Ana rings for nobody and isn't read as hers.
      'UX-1806, UX-1807: a task given to another member reads her name, never the plan',
      (tester) async {
        await (await _App.open(tester, [
          Task(
            id: 1,
            title: 'Presentar el proyecto',
            priority: 1,
            dueDate: friday13,
            hasTime: false,
            reminderPlan: ownersPlan,
            assignment: 'member',
            assigneeId: 2,
            assigneeName: 'Ana',
          ),
        ], size: phone)).detail(1);
        expect(chipLine(tester), es.reminderForPersonOnly('Ana'));
      },
    );

    testWidgets(
      'UX-1806, UX-1807: the form’s «Recordatorio» row and its closed-details line read the same line',
      (tester) async {
        final app = await _App.open(tester, [
          presentation(plan: normal),
        ], size: phone);
        app.navigator.pushNamed('/editTask', arguments: 1);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('task-reminder-plan')))
              .data,
          normalLine,
        );
        await tapVisible(
          tester,
          find.byKey(const ValueKey('task-more-details')),
        );
        final row = find.descendant(
          of: find.byType(ReminderControl),
          matching: find.text(normalLine),
        );
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        expect(row, findsOneWidget);
        // P270 (UX-2206): the plan's line is the row's only text.
        expect(
          find.descendant(
            of: find.byType(ReminderControl),
            matching: find.text(es.reminder),
          ),
          findsNothing,
        );
      },
    );

    Future<String> sheetCount(
      WidgetTester tester, {
      String language = 'es',
      ClockFormat clock = ClockFormat.twentyFour,
      DateTime? at,
    }) async {
      await (await _App.open(
        tester,
        [presentation(plan: normal)],
        size: phone,
        language: language,
        clock: clock,
        at: at,
      )).detail(1);
      await openSheet(tester);
      final count = find.byKey(const ValueKey('reminder-plan-count'));
      await tester.ensureVisible(count);
      await tester.pumpAndSettle();
      return tester.widget<Text>(count).data!;
    }

    testWidgets(
      'UX-1910: the sheet’s count reads «13 avisos · próximo: sáb 24, 09:00»',
      (tester) async {
        expect(await sheetCount(tester), '13 avisos · próximo: sáb 24, 09:00');
      },
    );

    testWidgets(
      'UX-1910: with one notice left, «1 aviso: mañana, 09:00», with no «el»',
      (tester) async {
        expect(
          await sheetCount(tester, at: DateTime(2026, 11, 12, 10)),
          '1 aviso: mañana, 09:00',
        );
      },
    );

    testWidgets('UX-1910: in Catalan, «13 avisos · proper: ds. 24, 09:00»', (
      tester,
    ) async {
      expect(
        await sheetCount(tester, language: 'ca'),
        '13 avisos · proper: ds. 24, 09:00',
      );
    });

    testWidgets(
      'UX-1910: in English with a 12-hour clock, “13 reminders · next: Sat 24, 9:00 AM”',
      (tester) async {
        expect(
          await sheetCount(tester, language: 'en', clock: ClockFormat.twelve),
          '13 reminders · next: Sat 24, 9:00 AM',
        );
      },
    );

    for (final (language, plan, line) in [
      ('es', normal, normalLine),
      ('es', ownersPlan, ownLine),
      (
        'ca',
        normal,
        'Recordatoris normals fins al dv. 13 · proper: ds. 24, 09:00',
      ),
      (
        'ca',
        ownersPlan,
        'Recordatoris: cada 3 dies, i cada dia l’última setmana · proper: ds. 24, 09:00',
      ),
    ]) {
      testWidgets(
        'UX-1806, UX-1807: at 2× on 360×800 in $language, «${line.substring(0, 22)}…» wraps with its time, nothing cut',
        (tester) async {
          await (await _App.open(
            tester,
            [presentation(plan: plan)],
            language: language,
            textScale: 2,
            size: phone,
          )).detail(1);
          final text = chipLabel().first;
          await tester.ensureVisible(text);
          await tester.pumpAndSettle();
          expect(tester.widget<Text>(text).data, line);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: text, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          // Inside the screen, and wrapped onto more than one line.
          final box = tester.getRect(text);
          expect(box.left, greaterThanOrEqualTo(0));
          expect(box.right, lessThanOrEqualTo(phone.width));
          expect(box.top, greaterThanOrEqualTo(0));
          expect(box.bottom, lessThanOrEqualTo(phone.height));
          final lines = paragraph
              .getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: line.length),
              )
              .map((b) => b.top.round())
              .toSet();
          expect(lines.length, greaterThan(1));
          // The time, at the end, is laid out inside the chip's text.
          final last = paragraph
              .getBoxesForSelection(
                TextSelection(
                  baseOffset: line.length - 5,
                  extentOffset: line.length,
                ),
              )
              .last;
          expect(last.right, lessThanOrEqualTo(paragraph.size.width + 0.5));
          expect(last.bottom, lessThanOrEqualTo(paragraph.size.height + 0.5));
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('P245', () {
    final wordsField = find.byKey(const ValueKey('reminder-plan-words'));
    final apply = find.byKey(const ValueKey('reminder-plan-apply'));
    String field(WidgetTester tester) =>
        tester.widget<TextField>(wordsField).controller!.text;

    /// How many lines the words field shows now.
    int fieldLines(WidgetTester tester) {
      final editable = tester
          .state<EditableTextState>(
            find.descendant(
              of: wordsField,
              matching: find.byType(EditableText),
            ),
          )
          .renderEditable;
      return (editable.size.height / editable.preferredLineHeight).round();
    }

    /// The sheet's own scrolling.
    ScrollPosition sheetScroll(WidgetTester tester) => tester
        .state<ScrollableState>(
          find
              .descendant(of: sheet().last, matching: find.byType(Scrollable))
              .first,
        )
        .position;

    /// Fully inside the phone's screen, and the top thing where it is.
    void expectInView(WidgetTester tester, Finder finder, Size phone) {
      expect(finder.hitTestable(), findsOneWidget);
      final box = tester.getRect(finder);
      expect(box.top, greaterThanOrEqualTo(0));
      expect(box.bottom, lessThanOrEqualTo(phone.height));
    }

    /// Opens «A tu manera» on task 1's sheet, scrolled only as far as its
    /// row shows at the bottom edge, as a thumb would: the sheet brings its
    /// section into view itself.
    Future<void> openYourWay(
      WidgetTester tester,
      _App app,
      AppLocalizations l,
    ) async {
      await app.detail(1);
      await openSheet(tester);
      final yourWay = inSheet(find.text(l.reminderPlanYourWay));
      await Scrollable.ensureVisible(
        tester.element(yourWay),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      await tester.pumpAndSettle();
      await tester.tap(yourWay);
      await tester.pumpAndSettle();
      expect(wordsField, findsOneWidget);
    }

    testWidgets(
      'UX-1905: while the words grow to 4 lines at 2×, «Dejar de escuchar» and «Escuchando» stay in view without scrolling',
      (tester) async {
        const phone = Size(360, 800);
        final app = await _App.open(
          tester,
          [presentation()],
          textScale: 2,
          size: phone,
        );
        app.api.answer = {'reminder_plan': ownersPlan.toJson()};
        await openYourWay(tester, app, es);
        final speak = find.byKey(const ValueKey('reminder-plan-speak'));
        expect(speak.hitTestable(), findsOneWidget);
        await tester.tap(speak);
        await tester.pumpAndSettle();
        expect(app.speech.starts, 1);
        // From here on the test doesn't scroll: only the sheet may.
        const said = [
          'cada 3 días',
          'cada 3 días las dos primeras semanas',
          'cada 3 días las dos primeras semanas y luego cada día',
          'cada 3 días las dos primeras semanas y luego cada día, y el último día por la mañana y por la tarde',
        ];
        for (final words in said) {
          app.speech.send('partial', text: words);
          await tester.pumpAndSettle();
          expect(field(tester), words);
          expectInView(
            tester,
            inSheet(find.text(es.reminderPlanStopListening)),
            phone,
          );
          expectInView(tester, inSheet(find.text(es.captureListening)), phone);
        }
        expect(fieldLines(tester), 4, reason: 'The field at its tallest.');
        expect(tester.takeException(), isNull);

        // Stopping still works from where it is.
        await tester.tap(find.byKey(const ValueKey('reminder-plan-speak')));
        await tester.pumpAndSettle();
        expect(app.api.requests.single['text'], said.last);
        expect(tester.takeException(), isNull);
      },
    );

    for (final (language, l) in [('es', es), ('ca', ca)]) {
      testWidgets(
        'UX-1905: at 2× in $language, after the words are read «Listo» is in view without the test scrolling',
        (tester) async {
          const phone = Size(360, 800);
          final app = await _App.open(
            tester,
            [presentation()],
            language: language,
            textScale: 2,
            size: phone,
          );
          app.api.answer = {'reminder_plan': ownersPlan.toJson()};
          await openYourWay(tester, app, l);
          await tester.enterText(wordsField, ownersPlan.said!);
          final before = sheetScroll(tester).pixels;
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          expect(app.api.requests, hasLength(1));
          expect(
            sheetScroll(tester).pixels,
            greaterThan(before),
            reason: 'The sheet scrolled to what was read.',
          );
          expect(
            find.byKey(const ValueKey('reminder-plan-preview')),
            findsOneWidget,
          );
          expectInView(tester, apply, phone);
          await tester.tap(apply);
          await tester.pumpAndSettle();
          expect(app.task(1).reminderPlan, ownersPlan);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-1905: with animations off, the sheet reveals «Listo» at once, with no scrolling animation',
      (tester) async {
        const phone = Size(360, 800);
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final app = await _App.open(
          tester,
          [presentation()],
          textScale: 2,
          size: phone,
        );
        app.api.answer = {'reminder_plan': ownersPlan.toJson()};
        await openYourWay(tester, app, es);
        await tester.enterText(wordsField, ownersPlan.said!);
        final before = sheetScroll(tester).pixels;
        await tester.testTextInput.receiveAction(TextInputAction.done);
        // Frames only: no time passes, so an animated scroll couldn't move.
        for (var i = 0; i < 4; i++) {
          await tester.pump();
        }
        expect(app.api.requests, hasLength(1));
        expectInView(tester, apply, phone);
        // Already where it ends: letting time pass scrolls nothing further.
        final listo = tester.getRect(apply);
        final scroll = sheetScroll(tester);
        final at = scroll.pixels;
        expect(at, greaterThan(before), reason: 'The sheet scrolled to it.');
        await tester.pumpAndSettle();
        expect(scroll.pixels, at);
        expect(tester.getRect(apply), listo);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1906: words read and closed with Back are there on reopening, with their plan and «Listo», and no second request; a single row then clears them',
      (tester) async {
        final app = await _App.open(tester, [presentation()]);
        app.api.answer = {'reminder_plan': ownersPlan.toJson()};
        await openYourWay(tester, app, es);
        await tester.enterText(wordsField, ownersPlan.said!);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(app.api.requests, hasLength(1));
        expect(
          find.byKey(const ValueKey('reminder-plan-preview')),
          findsOneWidget,
        );

        // The phone's Back closes the sheet without a choice.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(sheet(), findsNothing);
        expect(app.task(1).reminderPlan, isNull);

        // Reopened from the task's chip.
        await openSheet(tester);
        expect(wordsField, findsOneWidget);
        expect(field(tester), ownersPlan.said);
        expect(
          find.byKey(const ValueKey('reminder-plan-preview')),
          findsOneWidget,
        );
        expect(apply, findsOneWidget);
        expect(find.text('13 avisos · próximo: sáb 24, 09:00'), findsOneWidget);
        expect(app.api.requests, hasLength(1), reason: 'Nothing asked again.');

        // A single row is a choice: the words go.
        await tapVisible(tester, inSheet(find.text(es.off)));
        expect(sheet(), findsNothing);
        expect(app.task(1).reminderMinutes, -1);
        await openSheet(tester);
        if (wordsField.evaluate().isEmpty) {
          await tapVisible(tester, inSheet(find.text(es.reminderPlanYourWay)));
        }
        expect(field(tester), isEmpty);
        expect(
          find.byKey(const ValueKey('reminder-plan-preview')),
          findsNothing,
        );
        expect(app.api.requests, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );

    for (final (language, l, helper) in [
      (
        'es',
        es,
        'Por ejemplo: «una semana antes y el día antes a\u00A0las\u00A08».',
      ),
      ('en', en, 'For example: “a week before, and the day before at\u00A08”.'),
      (
        'ca',
        ca,
        'Per exemple: «una setmana abans i el dia abans a\u00A0les\u00A08».',
      ),
    ]) {
      testWidgets(
        'UX-1908: in $language the empty field’s helper is an example',
        (tester) async {
          expect(l.reminderPlanYourWayHint, helper);
          final app = await _App.open(tester, [
            presentation(),
          ], language: language);
          await openYourWay(tester, app, l);
          expect(field(tester), isEmpty);
          expect(
            find.descendant(of: wordsField, matching: find.text(helper)),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-1908: after words that aren’t understood, «Dictarlo» starts from an empty field',
      (tester) async {
        expect(
          es.reminderPlanUnclear,
          'No lo he entendido. Prueba a decirlo de otra forma.',
        );
        expect(
          en.reminderPlanUnclear,
          'I didn’t get that. Try saying it another way.',
        );
        expect(
          ca.reminderPlanUnclear,
          'No ho he entès. Prova de dir-ho d’una altra manera.',
        );
        final app = await _App.open(tester, [presentation()]);
        app.api.answer = {'reminder_plan': null, 'issue': 'unclear'};
        await openYourWay(tester, app, es);
        await tester.enterText(wordsField, 'comprar pan');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(
          inSheet(
            find.text('No lo he entendido. Prueba a decirlo de otra forma.'),
          ),
          findsOneWidget,
        );

        app.api.answer = {'reminder_plan': ownersPlan.toJson()};
        await tapVisible(
          tester,
          find.byKey(const ValueKey('reminder-plan-speak')),
        );
        expect(app.speech.starts, 1);
        app.speech.send('partial', text: 'cada día');
        await tester.pump();
        expect(field(tester), 'cada día');
        app.speech.send('segment', text: 'cada día');
        await tester.pump();
        expect(field(tester), 'cada día');
        await tapVisible(
          tester,
          find.byKey(const ValueKey('reminder-plan-speak')),
        );
        expect(field(tester), 'cada día');
        expect(app.api.requests.last['text'], 'cada día');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1909: in Catalan the deadline is «termini» in the row, offline and when a read fails',
      (tester) async {
        expect(ca.reminderPlanUntilDay, 'Fins al termini');
        final app = await _App.open(tester, [presentation()], language: 'ca');
        await app.detail(1);
        await openSheet(tester);
        expect(inSheet(find.text('Fins al termini')), findsOneWidget);
        expect(inSheet(find.textContaining('data límit')), findsNothing);

        await tapVisible(tester, inSheet(find.text(ca.reminderPlanYourWay)));
        app.api.failure = ApiException(0, ApiClient.offlineMessage);
        await tester.enterText(wordsField, 'cada 2 dies');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(
          inSheet(
            find.text(
              'Això necessita connexió. «Fins al termini» funciona sense.',
            ),
          ),
          findsOneWidget,
        );

        app.api.failure = ApiException(
          429,
          'Too many',
          null,
          const Duration(hours: 5),
        );
        await tester.enterText(wordsField, 'cada 4 dies');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(
          inSheet(
            find.text(
              'Ara no ho he pogut llegir. Torna-ho a provar més tard, o tria «Fins al termini».',
            ),
          ),
          findsOneWidget,
        );
        expect(inSheet(find.textContaining('data límit')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    // ---- Run 2026-10-22-changes, round 3 · P251 ----

    for (final textScale in [1.0, 2.0]) {
      testWidgets(
        'UX-2019: «A tu manera»’s empty helper at ${textScale.toInt()}× on 360×800 (es) never puts «8».» alone on a line',
        (tester) async {
          final app = await _App.open(
            tester,
            [presentation()],
            textScale: textScale,
            size: const Size(360, 800),
          );
          await openYourWay(tester, app, es);
          expect(field(tester), isEmpty);
          final helper = find.descendant(
            of: wordsField,
            matching: find.text(es.reminderPlanYourWayHint),
          );
          expect(helper, findsOneWidget);
          final lines = _expectHourKeptWithPreposition(
            tester,
            helper,
            'a\u00A0las',
          );
          if (textScale == 2) {
            expect(
              lines,
              greaterThan(1),
              reason: 'At 2× the helper wraps, so where it breaks matters.',
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('P252 · D1', () {
    const normal = ReminderPlan.rhythm(ReminderPlan.normal);
    const phone = Size(360, 800);

    /// «Presentar el proyecto» on Fri 13 Nov 2026 at 17:00, or with no time.
    Task timed({bool hasTime = true}) => Task(
      id: 1,
      title: 'Presentar el proyecto',
      priority: 1,
      dueDate: hasTime ? DateTime(2026, 11, 13, 17) : friday13,
      hasTime: hasTime,
      reminderPlan: normal,
    );

    String chipLine(WidgetTester tester) => tester
        .widget<Text>(
          find
              .descendant(
                of: find.byType(ReminderChip),
                matching: find.byType(Text),
              )
              .first,
        )
        .data!;

    /// «Recordatorios normales hasta hoy · próximo: hoy, [time]».
    String todayLine(String time) => es.reminderPlanLine(
      es.reminderPlanStrengthLine('normal', 'today', ''),
      'today',
      '',
      time,
    );

    Future<String> sheetCount(WidgetTester tester) async {
      await openSheet(tester);
      final count = find.byKey(const ValueKey('reminder-plan-count'));
      if (count.evaluate().isEmpty) {
        await tapVisible(tester, inSheet(find.text(es.reminderPlanUntilDay)));
      }
      await tester.ensureVisible(count);
      await tester.pumpAndSettle();
      return tester.widget<Text>(count).data!;
    }

    testWidgets(
      'UX-2001: on the day at 10:00, a task at 17:00 with Normal reads «… hasta hoy · próximo: hoy, 16:50», and the sheet «1 aviso: hoy, 16:50»',
      (tester) async {
        await (await _App.open(
          tester,
          [timed()],
          size: phone,
          at: DateTime(2026, 11, 13, 10),
        )).detail(1);
        expect(chipLine(tester), todayLine('16:50'));
        expect(
          chipLine(tester),
          isNot(es.noReminderTimePassed),
          reason: 'The 9:00 notice is no longer the day’s one.',
        );
        expect(
          await sheetCount(tester),
          es.reminderPlanCount(1, 'today', '', '16:50'),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2001: at 17:00 the same day, the chip says the time has passed',
      (tester) async {
        await (await _App.open(
          tester,
          [timed()],
          size: phone,
          at: DateTime(2026, 11, 13, 17),
        )).detail(1);
        expect(chipLine(tester), es.noReminderTimePassed);
      },
    );

    testWidgets(
      'UX-2001: with «Tareas con hora» at 30 minutes, at 10:00 it reads «… próximo: hoy, 16:30»',
      (tester) async {
        await (await _App.open(
          tester,
          [timed()],
          size: phone,
          at: DateTime(2026, 11, 13, 10),
          reminders: const ReminderPreferences(
            enabled: true,
            dateOnlyTime: 540,
            leadMinutes: 30,
            asked: true,
          ),
        )).detail(1);
        expect(chipLine(tester), todayLine('16:30'));
      },
    );

    testWidgets(
      'UX-2001: a date-only task that day at 10:00 still reads «Sin recordatorio: ya ha pasado la hora del aviso»',
      (tester) async {
        await (await _App.open(
          tester,
          [timed(hasTime: false)],
          size: phone,
          at: DateTime(2026, 11, 13, 10),
        )).detail(1);
        expect(chipLine(tester), es.noReminderTimePassed);
      },
    );

    testWidgets(
      'UX-2001: far away nothing changes: «… hasta el vie 13 · próximo: sáb 24, 09:00» and «13 avisos · próximo: sáb 24, 09:00»',
      (tester) async {
        await (await _App.open(tester, [timed()], size: phone)).detail(1);
        expect(
          chipLine(tester),
          es.reminderPlanLine(
            es.reminderPlanStrengthLine('normal', 'other', 'vie 13'),
            'other',
            'sáb 24',
            '09:00',
          ),
        );
        expect(
          await sheetCount(tester),
          es.reminderPlanCount(13, 'other', 'sáb 24', '09:00'),
        );
      },
    );

    testWidgets(
      'UX-2001: at 2× text on 360×800, the timed-today chip reads whole, with no overflow',
      (tester) async {
        await (await _App.open(
          tester,
          [timed()],
          size: phone,
          textScale: 2,
          at: DateTime(2026, 11, 13, 10),
        )).detail(1);
        final line = find.descendant(
          of: find.byType(ReminderChip),
          matching: find.text(todayLine('16:50')),
        );
        expect(line, findsOneWidget);
        await tester.ensureVisible(line);
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: line, matching: find.byType(RichText)).first,
        );
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: 'The whole line shows, not cut off.',
        );
        final box = tester.getRect(line);
        expect(box.left, greaterThanOrEqualTo(0));
        expect(box.right, lessThanOrEqualTo(phone.width));
        expect(tester.takeException(), isNull);
      },
    );
  });

  // P253 (UX-1912, the owner's D2): the strengths start at most 4 weeks
  // before the day, so a task 60 days away gets 8, 15 or 22 reminders.
  group('P253 · UX-1912', () {
    /// Monday 21 December 2026, 60 days away.
    final monday21 = DateTime(2026, 12, 21);
    const phone = Size(360, 800);
    const later =
        'cada 3 días desde 4 semanas antes, y a diario la última semana';

    /// A reminder's day as the preview writes it (planDay, in the open
    /// sheet's locale), with its month this far ahead.
    String day(WidgetTester tester, DateTime date, String weekday) {
      final locale = tester.element(sheet().last).localeName;
      final text = planDay(date, now, locale);
      expect(text, startsWith(weekday));
      expect(text, contains('${date.day}'));
      expect(text, contains('nov'));
      return text;
    }

    testWidgets(
      'UX-1912: on a task 60 days away the sheet says Normal starts 4 weeks '
      'before, with 15 reminders; Suave 8 and Intenso 22',
      (tester) async {
        await (await _App.open(tester, [
          presentation(day: monday21),
        ], size: phone)).detail(1);
        await openSheet(tester);
        await tapVisible(tester, inSheet(find.text(es.reminderPlanUntilDay)));
        expect(
          tester
              .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, es.reminderPlanNormal),
              )
              .selected,
          isTrue,
        );
        expect(
          inSheet(
            find.text(
              'Cada 3 días desde 4 semanas antes, y a diario la última semana',
            ),
          ),
          findsOneWidget,
        );
        expect(
          inSheet(
            find.text(
              es.reminderPlanCount(
                15,
                'other',
                day(tester, DateTime(2026, 11, 25), 'mié'),
                '09:00',
              ),
            ),
          ),
          findsOneWidget,
        );

        await tapVisible(
          tester,
          find.widgetWithText(ChoiceChip, es.reminderPlanGentle),
        );
        expect(
          inSheet(
            find.text(
              es.reminderPlanCount(
                8,
                'other',
                day(tester, DateTime(2026, 11, 26), 'jue'),
                '09:00',
              ),
            ),
          ),
          findsOneWidget,
        );

        await tapVisible(
          tester,
          find.widgetWithText(ChoiceChip, es.reminderPlanIntense),
        );
        expect(
          inSheet(
            find.text(
              es.reminderPlanCount(
                22,
                'other',
                day(tester, DateTime(2026, 11, 24), 'mar'),
                '09:00',
              ),
            ),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1912: moving a task to Mon 21 Dec offers Normal from 4 weeks before',
      (tester) async {
        final app = await _App.open(tester, [
          presentation(day: DateTime(2026, 10, 23)),
        ], size: phone);
        app.navigator.pushNamed('/editTask', arguments: 1);
        await tester.pumpAndSettle();
        final date = find.byKey(const ValueKey('task-date'));
        await tester.ensureVisible(date);
        await tester.pumpAndSettle();
        await tester.tap(date);
        await tester.pumpAndSettle();
        final picker = find.byType(CalendarDatePicker);
        final next = MaterialLocalizations.of(
          tester.element(picker),
        ).nextMonthTooltip;
        for (var page = 0; page < 2; page++) {
          await tester.tap(
            find.descendant(of: picker, matching: find.byTooltip(next)),
          );
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.descendant(of: picker, matching: find.text('21')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('schedule-done')));
        await tester.pumpAndSettle();
        final save = find.byKey(const ValueKey('task-save'));
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(app.task(1).dueDate, monday21);
        expect(find.byType(SnackBar), findsOneWidget);
        // Once the save message has gone.
        await tester.pump(FeedbackTimeout.defaultDuration);
        await tester.pumpAndSettle();
        final question = es.reminderPlanOfferMonths(2, later);
        expect(
          question,
          'Faltan 2 meses. ¿Te aviso cada 3 días desde 4 semanas antes, y a '
          'diario la última semana?',
        );
        expect(inSheet(find.text(question)), findsOneWidget);
        expect(app.reminders.offered, {1});
      },
    );
  });

  // P254 (UX-1812, the owner's D3): a reminder said for a task with no day
  // asks for the day in one line under the date, whose tap opens the date;
  // once the task has a day the reminder applies, and saved without one
  // it's dropped.
  group('P254 · D3', () {
    late WidgetTester shown;

    /// What the server sends for «Llamar a mamá, recuérdamelo cada día»:
    /// no day, the plan said, and `reminder_needs_day`.
    Map<String, dynamic> server(
      String title, {
      Map<String, dynamic> extra = const {},
    }) => {
      'title': title,
      'priority': 1,
      'notes': '',
      'questions': [],
      'transcript': title,
      ...extra,
    };
    const dailyPlan = {
      'kind': 'custom',
      'phases': [
        {'from_days': 366, 'to_days': 0, 'every_days': 1},
      ],
      'time': null,
      'said': 'cada día',
    };
    CaptureDraft draftOf(Map<String, dynamic> json) =>
        CaptureDraft.fromAI(TaskDraft.fromJson(json));
    CaptureDraft dailyNoDay([String title = 'Llamar a mamá']) => draftOf(
      server(
        title,
        extra: {'reminder_plan': dailyPlan, 'reminder_needs_day': true},
      ),
    );

    /// The capture's result for [drafts] on a 360×800 phone, reminders on
    /// and allowed; saving adds them to the app's tasks.
    Future<(_App, MemoryCaptures)> open(
      WidgetTester tester,
      List<CaptureDraft> drafts, {
      String language = 'es',
      double textScale = 1,
      DateTime? at,
    }) async {
      shown = tester;
      final captures = MemoryCaptures();
      final app = await _App.open(
        tester,
        const [],
        captures: captures,
        language: language,
        textScale: textScale,
        size: const Size(360, 800),
        at: at,
      );
      captures.tasks = app.container;
      captures.current = CaptureSession(
        id: 'p254',
        ownerKey: app.container.read(captureOwnerProvider),
        timezone: 'Europe/Madrid',
        capturedAt: (at ?? now).toUtc(),
        status: 'ready',
        source: 'speech',
        transcript: 'Llamar a mamá, recuérdamelo cada día',
        drafts: drafts,
      );
      await openCaptureResult(tester, 'p254');
      expect(find.byType(VoiceTaskScreen), findsOneWidget);
      return (app, captures);
    }

    Finder line(String id) =>
        find.byKey(ValueKey('draft-reminder-needs-day-$id'));
    Finder row(String id) => find.byKey(ValueKey('draft-reminder-$id'));
    Finder date(String id) => find.byKey(ValueKey('draft-schedule-$id'));
    Finder inLine(String id, String text) =>
        find.descendant(of: line(id), matching: find.text(text));
    Finder inRow(String id, Finder finder) =>
        find.descendant(of: row(id), matching: finder);
    double top(Finder finder) => shown.getTopLeft(finder.first).dy;
    double bottom(Finder finder) => shown.getBottomLeft(finder.first).dy;

    /// The line sits under the date line, before anything else of the card.
    void underTheDate(String id) {
      expect(top(line(id)), greaterThanOrEqualTo(bottom(date(id)) - 0.5));
      expect(
        find.descendant(of: date(id), matching: find.text(es.noDate)),
        findsOneWidget,
      );
    }

    Task saved(_App app, String title) => app.container
        .read(taskProvider)
        .requireValue
        .singleWhere((task) => task.title == title);

    test(
      'UX-1812: TaskDraft reads reminder_needs_day, false when absent; CaptureDraft keeps a lead only where it can apply',
      () {
        final without = TaskDraft.fromJson(
          server('Llamar a mamá', extra: {'reminder_minutes': 60}),
        );
        expect(without.reminderNeedsDay, isFalse);
        expect(
          TaskDraft.fromJson(
            server('Llamar a mamá', extra: {'reminder_needs_day': true}),
          ).reminderNeedsDay,
          isTrue,
        );
        expect(
          TaskDraft.fromJson(
            server('Llamar a mamá', extra: {'reminder_needs_day': 'yes'}),
          ).reminderNeedsDay,
          isFalse,
        );
        // No day, the minutes and the flag: kept for the day it gets.
        expect(
          draftOf(
            server(
              'Llamar a mamá',
              extra: {'reminder_minutes': 60, 'reminder_needs_day': true},
            ),
          ).task.reminderMinutes,
          60,
        );
        // The same without the flag (an older server): none.
        expect(CaptureDraft.fromAI(without).task.reminderMinutes, isNull);
        // A day with no time: none, as before.
        expect(
          draftOf(
            server(
              'Llamar a mamá',
              extra: {
                'scheduled_date': '2026-11-13',
                'reminder_minutes': 60,
                'reminder_needs_day': true,
              },
            ),
          ).task.reminderMinutes,
          isNull,
        );
        // At a time: kept, as before.
        expect(
          draftOf(
            server(
              'Llamar a mamá',
              extra: {
                'due_date': '2026-11-13T17:00:00',
                'reminder_minutes': 60,
              },
            ),
          ).task.reminderMinutes,
          60,
        );
        // A note keeps none.
        expect(
          draftOf(
            server(
              'Llamar a mamá',
              extra: {
                'kind': 'note',
                'reminder_minutes': 60,
                'reminder_needs_day': true,
              },
            ),
          ).task.reminderMinutes,
          isNull,
        );
      },
    );

    test(
      'UX-1812: a task saved with neither a day nor a deadline keeps no lead; a dated one keeps it',
      () {
        final noDay = Task(
          title: 'Llamar a mamá',
          priority: 1,
          reminderMinutes: 60,
        );
        expect(CaptureStore.withoutStalePlan(noDay).reminderMinutes, isNull);
        final atTime = Task(
          title: 'Llamar a mamá',
          priority: 1,
          dueDate: DateTime(2026, 11, 13, 17),
          hasTime: true,
          reminderMinutes: 60,
        );
        expect(CaptureStore.withoutStalePlan(atTime).reminderMinutes, 60);
      },
    );

    testWidgets(
      'UX-1812: a plan said for a task with no day is one line under «Sin fecha», read as one button, and nowhere else',
      (tester) async {
        final handle = tester.ensureSemantics();
        final draft = dailyNoDay();
        final id = draft.id;
        await open(tester, [draft]);
        expect(inLine(id, es.reminderNeedsDay), findsOneWidget);
        expect(find.text(es.reminderNeedsDay), findsOneWidget);
        underTheDate(id);
        expect(
          find.descendant(
            of: line(id),
            matching: find.byIcon(Icons.notifications_off_outlined),
          ),
          findsOneWidget,
        );
        // TalkBack reads the line's words, as one button.
        expect(
          tester.getSemantics(line(id)),
          isSemantics(
            label: es.reminderNeedsDay,
            isButton: true,
            hasTapAction: true,
          ),
        );
        expect(row(id), findsNothing);
        expect(find.text(es.dateForReminder), findsNothing);
        await tester.ensureVisible(find.byKey(ValueKey('draft-options-$id')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('draft-options-$id')));
        await tester.pumpAndSettle();
        // «Más opciones» open: still said once.
        expect(find.text(es.dateForReminder), findsNothing);
        expect(find.byType(ReminderControl), findsNothing);
        expect(row(id), findsNothing);
        expect(find.text(es.reminderNeedsDay), findsOneWidget);
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    testWidgets(
      'UX-1812: the line opens the date; «Mañana» applies the plan in its row, «Sin fecha» brings the line back',
      (tester) async {
        // The date sheet's «Mañana» is the phone's tomorrow: the app's clock
        // is today at 10:00, after the day's 09:00 notice.
        final phone = DateTime.now();
        final draft = dailyNoDay();
        final id = draft.id;
        final (_, captures) = await open(tester, [
          draft,
        ], at: DateTime(phone.year, phone.month, phone.day, 10));
        await tester.ensureVisible(line(id));
        await tester.pumpAndSettle();
        await tester.tap(line(id));
        await tester.pumpAndSettle();
        expect(find.byType(CalendarDatePicker), findsOneWidget);
        await tester.tap(find.widgetWithText(ChoiceChip, es.tomorrow).last);
        await tester.pumpAndSettle();
        expect(find.byType(CalendarDatePicker), findsNothing);
        expect(line(id), findsNothing);
        expect(find.text(es.reminderNeedsDay), findsNothing);
        expect(row(id), findsOneWidget);
        expect(inRow(id, find.text(es.reminder)), findsNothing);
        expect(
          inRow(
            id,
            find.text('Recordatorios: a diario · próximo: mañana, 09:00'),
          ),
          findsOneWidget,
        );
        expect(captures.current!.drafts.single.task.reminderPlan, isNotNull);

        await tester.ensureVisible(date(id));
        await tester.pumpAndSettle();
        await tester.tap(date(id));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, es.noDate).last);
        await tester.pumpAndSettle();
        expect(inLine(id, es.reminderNeedsDay), findsOneWidget);
        underTheDate(id);
        expect(row(id), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1812: saved with the line still there, the task has no day, no plan and no lead',
      (tester) async {
        final draft = dailyNoDay();
        final (app, captures) = await open(tester, [draft]);
        expect(line(draft.id), findsOneWidget);
        await saveCapture(tester);
        final task = saved(app, 'Llamar a mamá');
        expect(task.dueDate, isNull);
        expect(task.reminderPlan, isNull);
        expect(task.reminderMinutes, isNull);
        final stored = captures.current!.drafts.single.task;
        expect(stored.dueDate, isNull);
        expect(stored.reminderPlan, isNull);
        expect(stored.reminderMinutes, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1812: «una hora antes» said with no day asks for the day; Fri 13 reads «09:00», at 17:00 «1 hora antes», and saves 60',
      (tester) async {
        final draft = draftOf(
          server(
            'Llamar a mamá',
            extra: {'reminder_minutes': 60, 'reminder_needs_day': true},
          ),
        );
        final id = draft.id;
        final (app, captures) = await open(tester, [draft]);
        expect(inLine(id, es.reminderNeedsDay), findsOneWidget);
        underTheDate(id);
        expect(row(id), findsNothing);

        await tester.ensureVisible(line(id));
        await tester.pumpAndSettle();
        await tester.tap(line(id));
        await tester.pumpAndSettle();
        // Fri 13 Nov in the sheet's calendar, as a tap on that day gives it.
        tester
            .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
            .onDateChanged(friday13);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('schedule-done')));
        await tester.pumpAndSettle();
        expect(line(id), findsNothing);
        expect(row(id), findsOneWidget);
        expect(inRow(id, find.text('09:00')), findsOneWidget);
        expect(captures.current!.drafts.single.task.dueDate, friday13);

        await tester.ensureVisible(date(id));
        await tester.pumpAndSettle();
        await tester.tap(date(id));
        await tester.pumpAndSettle();
        final toggle = find.byKey(const ValueKey('schedule-has-time'));
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('schedule-hour')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('schedule-hour')),
          '17',
        );
        await tester.enterText(
          find.byKey(const ValueKey('schedule-minute')),
          '00',
        );
        await tester.pumpAndSettle();
        final done = find.byKey(const ValueKey('schedule-done'));
        await tester.ensureVisible(done);
        await tester.pumpAndSettle();
        await tester.tap(done);
        await tester.pumpAndSettle();
        expect(line(id), findsNothing);
        expect(inRow(id, find.text(es.hourBefore)), findsOneWidget);

        await saveCapture(tester);
        final task = saved(app, 'Llamar a mamá');
        expect(task.dueDate, DateTime(2026, 11, 13, 17));
        expect(task.hasTime, isTrue);
        expect(task.reminderMinutes, 60);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1811 with UX-1812: a said plan on Fri 13, then «Sin fecha», asks for the day under the date, with no row, and saves no plan',
      (tester) async {
        final draft = draftOf(
          server(
            'Presentar el proyecto',
            extra: {
              'scheduled_date': '2026-11-13',
              'reminder_plan': ownersPlan.toJson(),
            },
          ),
        );
        final id = draft.id;
        final (app, captures) = await open(tester, [draft]);
        expect(row(id), findsOneWidget);
        expect(line(id), findsNothing);
        await tester.ensureVisible(date(id));
        await tester.pumpAndSettle();
        await tester.tap(date(id));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, es.noDate).last);
        await tester.pumpAndSettle();
        expect(inLine(id, es.reminderNeedsDay), findsOneWidget);
        underTheDate(id);
        expect(row(id), findsNothing);
        expect(find.text(es.dateForReminder), findsNothing);
        await saveCapture(tester);
        final task = saved(app, 'Presentar el proyecto');
        expect(task.dueDate, isNull);
        expect(task.reminderPlan, isNull);
        expect(captures.current!.drafts.single.task.reminderPlan, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1812: of two collapsed rows, only the one with no day and a said plan asks for the day, under its date',
      (tester) async {
        final first = draftOf(
          server(
            'Comprar pan y leche',
            extra: {'scheduled_date': '2026-10-22'},
          ),
        );
        final second = dailyNoDay();
        await open(tester, [first, second]);
        expect(find.byType(CaptureReviewEditor), findsNWidgets(2));
        expect(line(first.id), findsNothing);
        expect(inLine(second.id, es.reminderNeedsDay), findsOneWidget);
        expect(find.text(es.reminderNeedsDay), findsOneWidget);
        expect(top(line(second.id)), greaterThan(top(date(second.id))));
        // Collapsed: no «Más opciones» and no «Recordatorio» rows.
        expect(find.byKey(ValueKey('draft-options-${first.id}')), findsNothing);
        expect(
          find.byKey(ValueKey('draft-options-${second.id}')),
          findsNothing,
        );
        expect(row(first.id), findsNothing);
        expect(row(second.id), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1812: a plain dictation with no day has no line and no reminder row',
      (tester) async {
        final draft = draftOf(server('Comprar pan'));
        await open(tester, [draft]);
        expect(line(draft.id), findsNothing);
        expect(find.text(es.reminderNeedsDay), findsNothing);
        expect(row(draft.id), findsNothing);
        expect(find.text(es.reminder), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    for (final (language, words) in [
      ('es', es.reminderNeedsDay),
      ('ca', ca.reminderNeedsDay),
    ]) {
      testWidgets(
        'UX-1812: at 2× on 360×800 in $language the line is whole under the date, with a 48 dp target',
        (tester) async {
          final draft = dailyNoDay();
          final id = draft.id;
          await open(tester, [draft], language: language, textScale: 2);
          expect(tester.takeException(), isNull);
          final text = find.descendant(
            of: line(id),
            matching: find.text(words),
          );
          expect(text, findsOneWidget);
          await tester.ensureVisible(line(id));
          await tester.pumpAndSettle();
          expect(top(line(id)), greaterThanOrEqualTo(bottom(date(id)) - 0.5));
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: text, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          final box = tester.getRect(text);
          expect(box.left, greaterThanOrEqualTo(0));
          expect(box.right, lessThanOrEqualTo(360));
          // The words fit their box: nothing cut off at the end.
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(
              paragraph
                      .getBoxesForSelection(
                        TextSelection(
                          baseOffset: 0,
                          extentOffset: words.length,
                        ),
                      )
                      .map((b) => b.bottom)
                      .reduce((a, b) => a > b ? a : b) -
                  0.5,
            ),
          );
          expect(tester.getSize(line(id)).height, greaterThanOrEqualTo(48));
          final screen = tester.getRect(find.byType(VoiceTaskScreen));
          expect(
            tester.getRect(line(id)).bottom,
            lessThanOrEqualTo(screen.bottom),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  // P255 (UX-2013, the owner's D5): after two «Ahora no» in a row on this
  // phone the offer after saving is no longer asked; «Sí» starts the count
  // again, closing the offer without an answer neither counts nor resets,
  // and «Hasta la fecha límite» stays in every task's reminder sheet.
  group('P255 · UX-2013: two «Ahora no» in a row and the offer stops', () {
    const question =
        'Faltan 3 semanas. ¿Te aviso cada 3 días, y a diario la última semana?';
    const titles = [
      'Presentar el proyecto',
      'Entregar el informe',
      'Preparar el examen',
      'Renovar el pasaporte',
    ];

    /// [count] personal tasks, each on Thu 12 Nov, none with a reminder.
    List<Task> farTasks(int count) => [
      for (var id = 1; id <= count; id++)
        presentation(
          id: id,
          day: DateTime(2026, 11, 12),
        ).copyWith(title: titles[id - 1]),
    ];

    Finder anyOffer() => find.textContaining('¿Te aviso');

    /// Task [id] moved in the form to Fri 13 Nov and saved; then the save
    /// message's time, and whatever comes after it.
    Future<void> moveToFriday13(WidgetTester tester, _App app, int id) async {
      app.navigator.pushNamed('/editTask', arguments: id);
      await tester.pumpAndSettle();
      final date = find.byKey(const ValueKey('task-date'));
      await tester.ensureVisible(date);
      await tester.pumpAndSettle();
      await tester.tap(date);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.text('13'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-done')));
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('task-save'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(app.task(id).dueDate, friday13);
      // The offer, if any, waits for the save message to close.
      expect(anyOffer(), findsNothing);
      await tester.pump(FeedbackTimeout.defaultDuration);
      await tester.pumpAndSettle();
    }

    /// The offer is on screen, naming task [id].
    void expectOffer(WidgetTester tester, int id) {
      expect(inSheet(find.text(question)), findsOneWidget, reason: 'task $id');
      expect(
        inSheet(find.textContaining(titles[id - 1])),
        findsOneWidget,
        reason: 'task $id',
      );
    }

    Future<void> notNow(WidgetTester tester) async {
      await tester.tap(inSheet(find.text(es.reminderAskNotNow)));
      await tester.pumpAndSettle();
      expect(anyOffer(), findsNothing);
    }

    Future<void> yes(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('reminder-plan-offer-yes')));
      await tester.pumpAndSettle();
      expect(anyOffer(), findsNothing);
      // «Listo», with Deshacer, has its own time on screen.
      await tester.pump(FeedbackTimeout.defaultDuration);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    }

    testWidgets(
      'UX-2013: after «Ahora no» on two far tasks in a row, the third gets '
      'no offer once its save message has gone, and isn’t recorded as offered',
      (tester) async {
        final app = await _App.open(tester, farTasks(3));
        expect(es.reminderAskNotNow, 'Ahora no');
        await moveToFriday13(tester, app, 1);
        expectOffer(tester, 1);
        await notNow(tester);
        await moveToFriday13(tester, app, 2);
        expectOffer(tester, 2);
        await notNow(tester);
        await moveToFriday13(tester, app, 3);
        expect(anyOffer(), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        expect(app.reminders.offered, {1, 2});
        expect(app.task(3).reminderPlan, isNull);
        // Still nothing a while later.
        await tester.pump(const Duration(seconds: 30));
        await tester.pumpAndSettle();
        expect(anyOffer(), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2013: after two «Ahora no», the third task’s reminder sheet still '
      'shows «Hasta la fecha límite» and «A tu manera»',
      (tester) async {
        final app = await _App.open(tester, farTasks(3));
        for (final id in [1, 2]) {
          await moveToFriday13(tester, app, id);
          expectOffer(tester, id);
          await notNow(tester);
        }
        await moveToFriday13(tester, app, 3);
        expect(anyOffer(), findsNothing);
        await app.detail(3);
        await openSheet(tester);
        expect(inSheet(find.text(es.reminderPlanUntilDay)), findsOneWidget);
        expect(inSheet(find.text(es.reminderPlanYourWay)), findsOneWidget);
        // And it still sets a plan from there.
        await tapVisible(tester, inSheet(find.text(es.reminderPlanUntilDay)));
        expect(
          find.widgetWithText(ChoiceChip, es.reminderPlanNormal),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2013: «Ahora no», then «Sí, recuérdamelo», then «Ahora no»: the '
      'following far task still gets the offer',
      (tester) async {
        final app = await _App.open(tester, farTasks(4));
        await moveToFriday13(tester, app, 1);
        expectOffer(tester, 1);
        await notNow(tester);
        await moveToFriday13(tester, app, 2);
        expectOffer(tester, 2);
        await yes(tester);
        expect(
          app.task(2).reminderPlan,
          const ReminderPlan.rhythm(ReminderPlan.normal),
        );
        await moveToFriday13(tester, app, 3);
        expectOffer(tester, 3);
        await notNow(tester);
        await moveToFriday13(tester, app, 4);
        expectOffer(tester, 4);
        expect(app.reminders.offered, {1, 2, 3, 4});
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2013: «Ahora no», then the next offer closed with Back without an '
      'answer, then «Ahora no»: the following far task gets no offer',
      (tester) async {
        final app = await _App.open(tester, farTasks(4));
        await moveToFriday13(tester, app, 1);
        expectOffer(tester, 1);
        await notNow(tester);
        await moveToFriday13(tester, app, 2);
        expectOffer(tester, 2);
        // The phone's Back closes the offer without an answer.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(anyOffer(), findsNothing);
        expect(app.task(2).reminderPlan, isNull);
        // Not a reset: the third is asked, and its «Ahora no» is the second.
        await moveToFriday13(tester, app, 3);
        expectOffer(tester, 3);
        await notNow(tester);
        await moveToFriday13(tester, app, 4);
        expect(anyOffer(), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        expect(app.reminders.offered, {1, 2, 3});
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- Run 2026-10-22-changes, round 1 · P257 ----
  group('P257 · UX-2020', () {
    const nbsp = ' ';

    /// The catalog's own value of [key] in app_[language].arb.
    String arb(String language, String key) {
      final catalog =
          jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
              as Map<String, dynamic>;
      return catalog[key] as String;
    }

    test(
      'UX-2020: es and ca join «a», the article and «8» with two no-break spaces, en keeps its one, and every value reads as before',
      () {
        // The words as they were before P251 and P257, plain spaces only.
        const before = {
          'es': (
            'Por ejemplo: «una semana antes y el día antes a las 8».',
            '«una semana antes y el día antes a las 8»',
            'a${nbsp}las${nbsp}8',
            2,
            '«',
            '»',
          ),
          'ca': (
            'Per exemple: «una setmana abans i el dia abans a les 8».',
            '«una setmana abans i el dia abans a les 8»',
            'a${nbsp}les${nbsp}8',
            2,
            '«',
            '»',
          ),
          'en': (
            'For example: “a week before, and the day before at 8”.',
            '“a week before, and the day before at 8”',
            'at${nbsp}8',
            1,
            '“',
            '”',
          ),
        };
        for (final MapEntry(key: language, value: expected) in before.entries) {
          final (hintWords, exampleWords, phrase, spaces, open, close) =
              expected;
          final l = lookupAppLocalizations(Locale(language));
          for (final (key, words, generated) in [
            ('reminderPlanYourWayHint', hintWords, l.reminderPlanYourWayHint),
            (
              'billingReasonReminderPlansExample',
              exampleWords,
              l.billingReasonReminderPlansExample,
            ),
          ]) {
            final value = arb(language, key);
            expect(
              generated,
              value,
              reason: '$language $key: flutter gen-l10n is up to date',
            );
            expect(
              value,
              contains(phrase),
              reason: '$language $key: the time phrase is one unit',
            );
            expect(
              nbsp.allMatches(value).length,
              spaces,
              reason: '$language $key: no-break spaces only in the time phrase',
            );
            expect(
              nbsp.allMatches(value.replaceFirst(phrase, '')).length,
              0,
              reason: '$language $key: no no-break space outside «$phrase»',
            );
            expect(
              value.replaceAll(nbsp, ' '),
              words,
              reason: '$language $key: the words are unchanged',
            );
          }
          // The Pro example is exactly the helper's quoted part.
          final hint = l.reminderPlanYourWayHint;
          final quoted = hint.substring(
            hint.indexOf(open),
            hint.lastIndexOf(close) + close.length,
          );
          expect(
            l.billingReasonReminderPlansExample,
            quoted,
            reason: '$language: the Pro example is the helper’s own',
          );
        }
      },
    );

    final example = find.byKey(const ValueKey('subscription-reason-example'));
    final heading = find.byKey(const ValueKey('subscription-reason'));
    final paywall = find.byKey(const ValueKey('subscription-paywall'));
    final wordsField = find.byKey(const ValueKey('reminder-plan-words'));

    /// A free account's Pro screen, opened from «A tu manera · Pro».
    Future<void> openProScreen(
      WidgetTester tester,
      AppLocalizations l, {
      required String language,
      required double textScale,
    }) async {
      final app = await _App.open(
        tester,
        [presentation()],
        pro: false,
        language: language,
        textScale: textScale,
        size: const Size(360, 800),
      );
      await app.detail(1);
      await openSheet(tester);
      await tapVisible(tester, inSheet(find.text(l.reminderPlanYourWay)));
      expect(find.byType(SubscriptionScreen), findsOneWidget);
    }

    for (final textScale in [1.0, 2.0]) {
      testWidgets(
        'UX-2020: on the Pro screen at ${textScale.toInt()}× on 360×800 (es), «a», «las» and «8»» sit on one line, the example’s last',
        (tester) async {
          await openProScreen(tester, es, language: 'es', textScale: textScale);
          expect(tester.takeException(), isNull);
          expect(
            tester.widget<Text>(example).data,
            es.billingReasonReminderPlansExample,
          );
          final lines = _p257TimePhraseOnLastLine(tester, example, 'a', 'las');
          if (textScale == 2) {
            expect(
              lines,
              greaterThan(1),
              reason: 'At 2× the example wraps, so where it breaks matters.',
            );
          }
        },
      );
    }

    testWidgets(
      'UX-2020: on the Pro screen at 2× on 360×800 (ca), «a les 8»» sits on one line, and the heading, the example and «Mostra la subscripció» are on screen, unclipped',
      (tester) async {
        await openProScreen(tester, ca, language: 'ca', textScale: 2);
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<Text>(example).data,
          ca.billingReasonReminderPlansExample,
        );
        expect(
          _p257TimePhraseOnLastLine(tester, example, 'a', 'les'),
          greaterThan(1),
        );

        final button = find.descendant(
          of: paywall,
          matching: find.text(ca.billingViewPlans),
        );
        expect(button, findsOneWidget);
        const screen = Rect.fromLTWH(0, 0, 360, 800);
        for (final (name, finder) in [
          ('heading', heading),
          ('example', example),
          ('«${ca.billingViewPlans}»', button),
        ]) {
          final rect = tester.getRect(finder);
          expect(
            rect.left >= 0 &&
                rect.top >= 0 &&
                rect.right <= screen.right &&
                rect.bottom <= screen.bottom,
            isTrue,
            reason: '$name at $rect is not wholly on screen',
          );
          expect(finder.hitTestable(), findsOneWidget, reason: name);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: finder, matching: find.byType(RichText)).first,
          );
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: '$name is cut short',
          );
          expect(
            paragraph.size.width,
            lessThanOrEqualTo(rect.width + 0.5),
            reason: '$name is wider than its box',
          );
        }
      },
    );

    for (final textScale in [1.0, 2.0]) {
      testWidgets(
        'UX-2020: «A tu manera»’s empty helper at ${textScale.toInt()}× on 360×800 (es, Pro) never ends a line with «a» before «las 8»',
        (tester) async {
          final app = await _App.open(
            tester,
            [presentation()],
            textScale: textScale,
            size: const Size(360, 800),
          );
          await app.detail(1);
          await openSheet(tester);
          final yourWay = inSheet(find.text(es.reminderPlanYourWay));
          await Scrollable.ensureVisible(
            tester.element(yourWay),
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
          await tester.pumpAndSettle();
          await tester.tap(yourWay);
          await tester.pumpAndSettle();
          expect(wordsField, findsOneWidget);
          expect(
            tester.widget<TextField>(wordsField).controller!.text,
            isEmpty,
          );
          final helper = find.descendant(
            of: wordsField,
            matching: find.text(es.reminderPlanYourWayHint),
          );
          expect(helper, findsOneWidget);
          final lines = _p257TimePhraseOnLastLine(tester, helper, 'a', 'las');
          if (textScale == 2) {
            expect(
              lines,
              greaterThan(1),
              reason: 'At 2× the helper wraps, so where it breaks matters.',
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  // P256 (UX-2014, the owner's D6; UX-2021): a plan is each person's own. It
  // is offered wherever this phone rings for the task, says on a shared task
  // that it's only for you, never reads as someone else's, and the offer may
  // come for any task that rings here. «A tu manera» shows the newest words
  // while listening.
  group('P256 · D6', () {
    const phone = Size(360, 800);
    // A shared project you own, with Marta (member 2) in it.
    final team = TaskListInfo(
      id: 'team',
      name: 'Equipo',
      shared: true,
      ownerId: 1,
      people: const [
        ProjectMember(id: 1, name: 'Yo', role: 'owner'),
        ProjectMember(id: 2, name: 'Marta', role: 'editor'),
      ],
    );
    // A shared project where you're an editor: you don't manage it.
    final club = TaskListInfo(
      id: 'club',
      name: 'Club',
      shared: true,
      ownerId: 2,
      role: 'editor',
      people: const [
        ProjectMember(id: 2, name: 'Marta', role: 'owner'),
        ProjectMember(id: 1, name: 'Yo', role: 'editor'),
      ],
    );
    final muted = TaskListInfo(
      id: 'quiet',
      name: 'Silencio',
      notifications: 'muted',
    );
    final archived = TaskListInfo(id: 'old', name: 'Antiguo', archived: true);
    final projects = [team, club, muted, archived];

    /// «Presentar el proyecto» on Fri 13 Nov in [listId], as [assignment].
    Task shared({
      int? id = 1,
      String? listId = 'team',
      String assignment = 'group',
      int? assigneeId,
      String? assigneeName,
      ReminderPlan? plan,
      DateTime? day,
      bool timed = false,
      int? minutes,
    }) => Task(
      id: id,
      title: 'Presentar el proyecto',
      priority: 1,
      dueDate: day ?? friday13,
      hasTime: timed,
      reminderMinutes: minutes,
      reminderPlan: plan,
      listId: listId,
      assignment: assignment,
      assigneeId: assigneeId,
      assigneeName: assigneeName,
    );
    Task forMarta({
      int? id = 1,
      ReminderPlan? plan,
      bool timed = false,
      int? minutes,
    }) => shared(
      id: id,
      assignment: 'member',
      assigneeId: 2,
      assigneeName: 'Marta',
      plan: plan,
      day: timed ? DateTime(2026, 11, 13, 17) : null,
      timed: timed,
      minutes: minutes,
    );

    final justYou = find.byKey(const ValueKey('reminder-plan-just-you'));
    final listo = find.byKey(const ValueKey('reminder-plan-apply'));
    final untilDay = find.byKey(const ValueKey('reminder-plan-until-day'));
    final yourWay = find.byKey(const ValueKey('reminder-plan-your-way'));

    /// The line reads [l]'s copy, once in the sheet (none above «Listo»),
    /// directly under the sheet's title, which stays above the choices
    /// (UX-2026).
    void expectJustUnderTitle(WidgetTester tester, AppLocalizations l) {
      expect(justYou, findsOneWidget);
      expect(inSheet(justYou), findsOneWidget);
      expect(tester.widget<Text>(justYou).data, l.reminderPlanJustYou);
      final line = tester.getRect(justYou);
      final title = tester.getRect(inSheet(find.text(l.reminder)));
      expect(line.top, greaterThanOrEqualTo(title.bottom - 0.5));
      expect(
        line.top - title.bottom,
        lessThanOrEqualTo(16),
        reason: 'The line sits directly under the title.',
      );
      expect(line.top, greaterThanOrEqualTo(0));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: justYou, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
    }

    test(
      'UX-2014: the line’s copy in the three catalogs, as the brief gives it',
      () {
        expect(es.reminderPlanJustYou, 'Estos avisos son solo para ti.');
        expect(en.reminderPlanJustYou, 'These reminders are only for you.');
        expect(ca.reminderPlanJustYou, 'Aquests avisos són només per a tu.');
      },
    );

    for (final (what, task) in [
      ('a «Todos» task', shared()),
      ('a task given to you', shared(assignment: 'member', assigneeId: 1)),
      (
        'an unassigned task in a project you own',
        shared(assignment: 'unassigned'),
      ),
    ]) {
      testWidgets(
        'UX-2014: on $what in a shared project, the sheet offers the plans, '
        'and says «Estos avisos son solo para ti.» once, under its title, '
        'before and after opening «Hasta la fecha límite»',
        (tester) async {
          final app = await _App.open(
            tester,
            [task],
            size: phone,
            projects: projects,
          );
          await app.detail(1);
          await openSheet(tester);
          expect(inSheet(untilDay), findsOneWidget);
          expect(inSheet(yourWay), findsOneWidget);
          expectJustUnderTitle(tester, es);
          await tapVisible(tester, inSheet(untilDay));
          await tester.ensureVisible(listo);
          await tester.pumpAndSettle();
          expectJustUnderTitle(tester, es);
          // Listo still sets this person's plan.
          await tapVisible(tester, listo);
          expect(
            app.task(1).reminderPlan,
            const ReminderPlan.rhythm(ReminderPlan.normal),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2014: on a «Todos» task, the line stays once, under the title, '
      'while «A tu manera» reads a plan',
      (tester) async {
        final app = await _App.open(
          tester,
          [shared()],
          size: phone,
          projects: projects,
        );
        app.api.answer = {'reminder_plan': ownersPlan.toJson()};
        await app.detail(1);
        await openSheet(tester);
        await tapVisible(tester, inSheet(yourWay));
        expectJustUnderTitle(tester, es);
        await tester.enterText(
          find.byKey(const ValueKey('reminder-plan-words')),
          'cada 3 días y la última semana a diario',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await tester.ensureVisible(listo);
        await tester.pumpAndSettle();
        expectJustUnderTitle(tester, es);
      },
    );

    // P259 (UX-2025, UX-2028): someone else's reminders offer no choices.
    testWidgets(
      'UX-2014: a task given to Marta reads «Recordatorio para Marta», and a '
      'tap opens nothing',
      (tester) async {
        final app = await _App.open(
          tester,
          [shared(assignment: 'member', assigneeId: 2, assigneeName: 'Marta')],
          size: phone,
          projects: projects,
        );
        await app.detail(1);
        expect(chipText(es.reminderForPersonOnly('Marta')), findsOneWidget);
        await tester.tap(find.byType(ReminderChip), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(sheet(), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2014: an unassigned task in a shared project where you’re an editor '
      'shows no reminder',
      (tester) async {
        final app = await _App.open(
          tester,
          [shared(listId: 'club', assignment: 'unassigned')],
          size: phone,
          projects: projects,
        );
        await app.detail(1);
        expect(
          find.descendant(
            of: find.byType(ReminderChip),
            matching: find.byType(Text),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2014: a personal task with no project, Pro: plan rows, and no '
      '«Estos avisos son solo para ti.» in «Hasta la fecha límite» nor in '
      '«A tu manera» once a plan is read',
      (tester) async {
        final app = await _App.open(tester, [presentation()], size: phone);
        app.api.answer = {'reminder_plan': ownersPlan.toJson()};
        await app.detail(1);
        await openSheet(tester);
        expect(inSheet(untilDay), findsOneWidget);
        expect(inSheet(yourWay), findsOneWidget);
        await tapVisible(tester, inSheet(untilDay));
        await tester.ensureVisible(listo);
        await tester.pumpAndSettle();
        expect(listo, findsOneWidget);
        expect(justYou, findsNothing);
        expect(find.text(es.reminderPlanJustYou), findsNothing);
        await tapVisible(tester, inSheet(yourWay));
        await tester.enterText(
          find.byKey(const ValueKey('reminder-plan-words')),
          'cada 3 días y la última semana a diario',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await tester.ensureVisible(listo);
        await tester.pumpAndSettle();
        expect(listo, findsOneWidget);
        expect(justYou, findsNothing);
        expect(find.text(es.reminderPlanJustYou), findsNothing);
      },
    );

    testWidgets(
      'UX-2014: a task given to Marta that carries a plan reads «Recordatorio '
      'para Marta», never the plan, with no plan-line key, and the form’s '
      'closed details show no plan line',
      (tester) async {
        final app = await _App.open(
          tester,
          [forMarta(plan: const ReminderPlan.rhythm(ReminderPlan.normal))],
          size: phone,
          projects: projects,
        );
        await app.detail(1);
        final chip = find.byType(ReminderChip);
        expect(
          find
              .descendant(of: chip, matching: find.byType(Text))
              .evaluate()
              .map((e) => (e.widget as Text).data)
              .toList(),
          [es.reminderForPersonOnly('Marta')],
        );
        expect(find.byKey(const ValueKey('reminder-plan-line')), findsNothing);
        expect(find.textContaining('Recordatorios normales'), findsNothing);
        expect(find.textContaining('próximo'), findsNothing);
        app.navigator.pushNamed('/editTask', arguments: 1);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('task-reminder-plan')), findsNothing);
        expect(find.textContaining('Recordatorios normales'), findsNothing);
      },
    );

    testWidgets(
      'UX-2014: the same with its own lead of 60 reads «Recordatorio para '
      'Marta», and a tap changes nothing',
      (tester) async {
        final app = await _App.open(
          tester,
          [
            forMarta(
              plan: const ReminderPlan.rhythm(ReminderPlan.normal),
              timed: true,
              minutes: 60,
            ),
          ],
          size: phone,
          projects: projects,
        );
        await app.detail(1);
        expect(chipText(es.reminderForPersonOnly('Marta')), findsOneWidget);
        expect(find.byKey(const ValueKey('reminder-plan-line')), findsNothing);
        await tester.tap(find.byType(ReminderChip), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(sheet(), findsNothing);
        expect(
          app.task(1).reminderPlan,
          const ReminderPlan.rhythm(ReminderPlan.normal),
        );
        expect(app.task(1).reminderMinutes, 60);
      },
    );

    testWidgets(
      'UX-2014: the same plan on a «Todos» task of the project still reads as '
      'the plan, on the chip and in the form',
      (tester) async {
        final app = await _App.open(
          tester,
          [shared(plan: const ReminderPlan.rhythm(ReminderPlan.normal))],
          size: phone,
          projects: projects,
        );
        await app.detail(1);
        expect(
          find.byKey(const ValueKey('reminder-plan-line')),
          findsOneWidget,
        );
        expect(find.textContaining('Recordatorios normales'), findsOneWidget);
        app.navigator.pushNamed('/editTask', arguments: 1);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('task-reminder-plan')),
          findsOneWidget,
        );
      },
    );

    /// The form for task 1, «Más detalles» › «Recordatorio».
    Future<void> formReminder(WidgetTester tester, _App app) async {
      app.navigator.pushNamed('/editTask', arguments: 1);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('task-more-details')));
      await tapVisible(
        tester,
        find.descendant(
          of: find.byType(ReminderControl),
          matching: find.text(es.reminder),
        ),
      );
      expect(sheet(), findsOneWidget);
    }

    testWidgets(
      'UX-2014: in the form, a «Todos» task’s sheet shows the line under its '
      'title with «Hasta la fecha límite» open',
      (tester) async {
        final app = await _App.open(
          tester,
          [shared()],
          size: phone,
          projects: projects,
        );
        await formReminder(tester, app);
        await tapVisible(tester, inSheet(untilDay));
        await tester.ensureVisible(listo);
        await tester.pumpAndSettle();
        expectJustUnderTitle(tester, es);
      },
    );

    testWidgets(
      'UX-2014: in the form, the same task given to Marta reads «Recordatorio '
      'para Marta» and opens nothing',
      (tester) async {
        final app = await _App.open(
          tester,
          [forMarta()],
          size: phone,
          projects: projects,
        );
        app.navigator.pushNamed('/editTask', arguments: 1);
        await tester.pumpAndSettle();
        await tapVisible(
          tester,
          find.byKey(const ValueKey('task-more-details')),
        );
        final row = find.descendant(
          of: find.byType(ReminderControl),
          matching: find.text(es.reminderForPersonOnly('Marta')),
        );
        expect(row, findsOneWidget);
        await tapVisible(tester, row);
        expect(sheet(), findsNothing);
      },
    );

    /// The capture's result with one draft, [task].
    Future<_App> card(WidgetTester tester, Task task) async {
      final captures = MemoryCaptures();
      final app = await _App.open(
        tester,
        const [],
        captures: captures,
        size: phone,
        projects: projects,
      );
      captures.tasks = app.container;
      captures.current = CaptureSession(
        id: 'p256',
        ownerKey: app.container.read(captureOwnerProvider),
        timezone: 'Europe/Madrid',
        capturedAt: now.toUtc(),
        status: 'ready',
        source: 'speech',
        transcript: 'Presentar el proyecto…',
        drafts: [CaptureDraft(id: 'd1', task: task)],
      );
      await openCaptureResult(tester, 'p256');
      expect(find.byType(VoiceTaskScreen), findsOneWidget);
      return app;
    }

    Finder cardRow() => find.byKey(const ValueKey('draft-reminder-d1'));

    testWidgets(
      'UX-2014: on the capture card, a draft in the project given to Marta '
      'with a said plan reads «Recordatorio para Marta», and opens nothing',
      (tester) async {
        await card(tester, forMarta(id: null, plan: ownersPlan));
        expect(cardRow(), findsOneWidget);
        expect(
          find.descendant(
            of: cardRow(),
            matching: find.text(es.reminderForPersonOnly('Marta')),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('cada 3 días'), findsNothing);
        // The capture's result may hold a sheet of its own: none opens.
        final sheets = sheet().evaluate().length;
        await tapVisible(
          tester,
          find.descendant(
            of: cardRow(),
            matching: find.text(es.reminderForPersonOnly('Marta')),
          ),
        );
        expect(sheet(), findsNWidgets(sheets));
        expect(find.text(es.chooseAlertTime), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2014: on the capture card, a draft in a project muted here with a '
      'said plan reads «Sin recordatorio: proyecto silenciado»',
      (tester) async {
        await card(
          tester,
          shared(
            id: null,
            listId: 'quiet',
            assignment: 'personal',
            plan: ownersPlan,
          ),
        );
        expect(
          find.descendant(
            of: cardRow(),
            matching: find.text(es.noReminderProjectMuted),
          ),
          findsOneWidget,
        );
      },
    );

    // The offer (UX-2003's flow): task 1 on Thu 12 Nov, moved in the form to
    // Fri 13 Nov, with reminders on and allowed.
    for (final (what, task, expected) in [
      ('a «Todos» task in a shared project', shared(), true),
      (
        'an unassigned task in a shared project you own',
        shared(assignment: 'unassigned'),
        true,
      ),
      (
        'a task given to you',
        shared(assignment: 'member', assigneeId: 1, assigneeName: 'Yo'),
        true,
      ),
      (
        'a task given to Marta',
        shared(assignment: 'member', assigneeId: 2, assigneeName: 'Marta'),
        false,
      ),
      (
        'a personal task in a project muted here',
        shared(listId: 'quiet', assignment: 'personal'),
        false,
      ),
      (
        'a personal task in an archived project',
        shared(listId: 'old', assignment: 'personal'),
        false,
      ),
    ]) {
      testWidgets('UX-2014: the offer after moving $what to Fri 13 Nov: '
          '${expected ? 'it comes' : 'none'}', (tester) async {
        final app = await _App.open(
          tester,
          [task.copyWith(dueDate: DateTime(2026, 11, 12))],
          size: phone,
          projects: projects,
        );
        app.navigator.pushNamed('/editTask', arguments: 1);
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const ValueKey('task-date')));
        await tester.tap(
          find.descendant(
            of: find.byType(CalendarDatePicker),
            matching: find.text('13'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('schedule-done')));
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const ValueKey('task-save')));
        expect(app.task(1).dueDate, friday13);
        expect(find.byType(SnackBar), findsOneWidget);
        await tester.pump(FeedbackTimeout.defaultDuration);
        await tester.pumpAndSettle();
        final offer = find.byKey(const ValueKey('reminder-plan-offer-yes'));
        expect(offer, expected ? findsOneWidget : findsNothing);
        expect(app.reminders.offered, expected ? {1} : isEmpty);
        if (expected) {
          await tapVisible(tester, offer);
          expect(
            app.task(1).reminderPlan,
            const ReminderPlan.rhythm(ReminderPlan.normal),
          );
        }
      });
    }

    testWidgets(
      'UX-2021: while listening at 2× on 360×800, after long words the field '
      'is scrolled to its end, «…por la tarde» on its last line, and «Dejar '
      'de escuchar» and «Escuchando» stay on screen',
      (tester) async {
        final app = await _App.open(
          tester,
          [presentation()],
          textScale: 2,
          size: phone,
        );
        await app.detail(1);
        await openSheet(tester);
        await tapVisible(tester, inSheet(yourWay));
        final words = find.byKey(const ValueKey('reminder-plan-words'));
        expect(words, findsOneWidget);
        await tapVisible(
          tester,
          find.byKey(const ValueKey('reminder-plan-speak')),
        );
        expect(app.speech.starts, 1);
        const said =
            'cada 3 días las dos primeras semanas, luego cada día, y el último '
            'día por la mañana y por la tarde';
        app.speech.send('partial', text: said);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(words).controller!.text, said);
        // Unfocused while listening: no keyboard.
        expect(tester.widget<TextField>(words).focusNode!.hasFocus, isFalse);
        final scroll = tester
            .state<ScrollableState>(
              find.descendant(of: words, matching: find.byType(Scrollable)),
            )
            .position;
        expect(
          scroll.maxScrollExtent,
          greaterThan(0),
          reason: 'More than 4 lines of words.',
        );
        expect(scroll.pixels, moreOrLessEquals(scroll.maxScrollExtent));
        final editable = tester
            .state<EditableTextState>(
              find.descendant(of: words, matching: find.byType(EditableText)),
            )
            .renderEditable;
        final lineHeight = editable.preferredLineHeight;
        expect(
          (editable.size.height / lineHeight).round(),
          4,
          reason: 'The field keeps its 4 lines.',
        );
        final end = editable.getLocalRectForCaret(
          const TextPosition(offset: said.length),
        );
        expect(end.center.dy, greaterThan(editable.size.height - lineHeight));
        expect(end.center.dy, lessThan(editable.size.height));
        final start = editable.getLocalRectForCaret(
          const TextPosition(offset: 0),
        );
        expect(
          start.bottom,
          lessThanOrEqualTo(0),
          reason: 'The oldest words are out of sight above.',
        );
        for (final finder in [
          inSheet(find.text(es.reminderPlanStopListening)),
          inSheet(find.text(es.captureListening)),
        ]) {
          expect(finder.hitTestable(), findsOneWidget);
          final box = tester.getRect(finder);
          expect(box.top, greaterThanOrEqualTo(0));
          expect(box.bottom, lessThanOrEqualTo(phone.height));
        }
        expect(tester.takeException(), isNull);
      },
    );

    for (final (language, l) in [('es', es), ('ca', ca)]) {
      testWidgets(
        'UX-2014: at 2× on 360×800 in $language, a «Todos» task’s open '
        '«${l.reminderPlanUntilDay}» shows «${l.reminderPlanJustYou}» and '
        '«${l.done}» on screen, uncut',
        (tester) async {
          final app = await _App.open(
            tester,
            [shared()],
            language: language,
            textScale: 2,
            size: phone,
            projects: projects,
          );
          await app.detail(1);
          await openSheet(tester);
          await tapVisible(tester, inSheet(find.text(l.reminderPlanUntilDay)));
          await tester.ensureVisible(listo);
          await tester.pumpAndSettle();
          expectJustUnderTitle(tester, l);
          for (final finder in [justYou, listo]) {
            final box = tester.getRect(finder);
            expect(box.top, greaterThanOrEqualTo(0), reason: '$finder');
            expect(
              box.bottom,
              lessThanOrEqualTo(phone.height),
              reason: '$finder',
            );
            expect(box.left, greaterThanOrEqualTo(0), reason: '$finder');
            expect(
              box.right,
              lessThanOrEqualTo(phone.width),
              reason: '$finder',
            );
          }
          expect(listo.hitTestable(), findsOneWidget);
          expect(
            find.descendant(of: listo, matching: find.text(l.done)),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  // P258 (UX-2023): on a draft with no day, a said reminder and an open
  // `schedule` question, the question stays under its date line, and
  // «Para recordártelo, ponle un día.» comes after it.
  group('P258 · UX-2023', () {
    late WidgetTester shown;
    const question = '¿Qué día?';
    const dailyPlan = {
      'kind': 'custom',
      'phases': [
        {'from_days': 366, 'to_days': 0, 'every_days': 1},
      ],
      'time': null,
      'said': 'cada día',
    };

    /// «Llamar a mamá, recuérdamelo cada día» as the server sends it: no
    /// day, the plan said, `reminder_needs_day`, and «¿Qué día?» open.
    CaptureDraft asked({String title = 'Llamar a mamá', bool open = true}) =>
        CaptureDraft.fromAI(
          TaskDraft.fromJson({
            'title': title,
            'priority': 1,
            'notes': '',
            'questions': [],
            'transcript': title,
            'reminder_plan': dailyPlan,
            'reminder_needs_day': true,
            'clarifications': [
              if (open) {'field': 'schedule', 'question': question},
            ],
          }),
        );

    Future<void> open(
      WidgetTester tester,
      List<CaptureDraft> drafts, {
      String language = 'es',
      double textScale = 1,
    }) async {
      shown = tester;
      final captures = MemoryCaptures();
      final app = await _App.open(
        tester,
        const [],
        captures: captures,
        language: language,
        textScale: textScale,
        size: const Size(360, 800),
      );
      captures.tasks = app.container;
      captures.current = CaptureSession(
        id: 'p258',
        ownerKey: app.container.read(captureOwnerProvider),
        timezone: 'Europe/Madrid',
        capturedAt: now.toUtc(),
        status: 'ready',
        source: 'speech',
        transcript: 'Llamar a mamá, recuérdamelo cada día',
        drafts: drafts,
      );
      await openCaptureResult(tester, 'p258');
      expect(find.byType(VoiceTaskScreen), findsOneWidget);
    }

    Finder editor(String id) => find.byKey(ValueKey(id));
    Finder date(String id) => find.byKey(ValueKey('draft-schedule-$id'));
    Finder line(String id) =>
        find.byKey(ValueKey('draft-reminder-needs-day-$id'));
    Finder box(String id) => find.ancestor(
      of: find.descendant(of: editor(id), matching: find.text(question)),
      matching: find.byType(QuestionBox),
    );
    double top(Finder finder) => shown.getTopLeft(finder.first).dy;
    double bottom(Finder finder) => shown.getBottomLeft(finder.first).dy;

    /// Date line, then «¿Qué día?», then the needs-day line.
    void inOrder(String id) {
      expect(date(id), findsOneWidget);
      expect(box(id), findsOneWidget);
      expect(line(id), findsOneWidget);
      expect(top(box(id)), greaterThanOrEqualTo(bottom(date(id)) - 0.5));
      expect(top(line(id)), greaterThanOrEqualTo(bottom(box(id)) - 0.5));
    }

    testWidgets(
      'UX-2023: on the opened card «¿Qué día?» sits between the date line and «Para recordártelo, ponle un día.»',
      (tester) async {
        final draft = asked();
        await open(tester, [draft]);
        expect(find.byType(CaptureReviewEditor), findsOneWidget);
        expect(
          find.descendant(
            of: line(draft.id),
            matching: find.text(es.reminderNeedsDay),
          ),
          findsOneWidget,
        );
        inOrder(draft.id);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2023: in a collapsed second row the order is again date line, «¿Qué día?», then the needs-day line',
      (tester) async {
        final first = CaptureDraft.fromAI(
          TaskDraft.fromJson({
            'title': 'Comprar pan y leche',
            'priority': 1,
            'notes': '',
            'questions': [],
            'transcript': 'Comprar pan y leche',
            'scheduled_date': '2026-10-22',
          }),
        );
        final second = asked();
        await open(tester, [first, second]);
        expect(find.byType(CaptureReviewEditor), findsNWidgets(2));
        // Both collapsed: neither shows «Más opciones».
        expect(find.byKey(ValueKey('draft-options-${first.id}')), findsNothing);
        expect(
          find.byKey(ValueKey('draft-options-${second.id}')),
          findsNothing,
        );
        expect(line(first.id), findsNothing);
        expect(find.text(es.reminderNeedsDay), findsOneWidget);
        inOrder(second.id);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2023: once «¿Qué día?» is confirmed, its box goes and the needs-day line is directly under the date line',
      (tester) async {
        final draft = asked();
        final id = draft.id;
        await open(tester, [draft]);
        inOrder(id);
        final confirm = find.descendant(
          of: box(id),
          matching: find.text(es.reviewConfirmDetail),
        );
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(box(id), findsNothing);
        expect(find.text(question), findsNothing);
        expect(line(id), findsOneWidget);
        // Nothing between them: the line starts where the date line ends.
        expect(top(line(id)) - bottom(date(id)), inInclusiveRange(-0.5, 1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2023: with no open question the needs-day line is directly under the date line on the opened card',
      (tester) async {
        final draft = asked(open: false);
        final id = draft.id;
        await open(tester, [draft]);
        expect(find.byType(QuestionBox), findsNothing);
        expect(top(line(id)) - bottom(date(id)), inInclusiveRange(-0.5, 1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2023: with no open question a collapsed row has the needs-day line directly under its date line',
      (tester) async {
        final first = asked(title: 'Comprar pan', open: false);
        final second = asked(open: false);
        await open(tester, [first, second]);
        expect(
          find.byKey(ValueKey('draft-options-${second.id}')),
          findsNothing,
        );
        expect(find.byType(QuestionBox), findsNothing);
        expect(
          top(line(second.id)) - bottom(date(second.id)),
          inInclusiveRange(-0.5, 1),
        );
        expect(tester.takeException(), isNull);
      },
    );

    for (final language in ['es', 'ca']) {
      testWidgets(
        'UX-2023: at 2× on 360×800 in $language the date line, «¿Qué día?» and the needs-day line are whole, in that order',
        (tester) async {
          final l = language == 'es' ? es : ca;
          final draft = asked();
          final id = draft.id;
          await open(tester, [draft], language: language, textScale: 2);
          expect(tester.takeException(), isNull);
          inOrder(id);
          expect(
            find.descendant(
              of: line(id),
              matching: find.text(l.reminderNeedsDay),
            ),
            findsOneWidget,
          );
          final screen = tester.getRect(find.byType(VoiceTaskScreen));
          for (final part in [date(id), box(id), line(id)]) {
            await tester.ensureVisible(part);
            await tester.pumpAndSettle();
            final rect = tester.getRect(part);
            expect(rect.left, greaterThanOrEqualTo(0), reason: '$part');
            expect(rect.right, lessThanOrEqualTo(360), reason: '$part');
            expect(rect.top, greaterThanOrEqualTo(screen.top), reason: '$part');
            expect(
              rect.bottom,
              lessThanOrEqualTo(screen.bottom),
              reason: '$part',
            );
            // Every text in it is whole: not ellipsized, no line cut off.
            for (final paragraph in tester.renderObjectList<RenderParagraph>(
              find.descendant(of: part, matching: find.byType(RichText)),
            )) {
              expect(paragraph.didExceedMaxLines, isFalse, reason: '$part');
              // It got all the height its lines need: none cut off.
              final text = paragraph.text.toPlainText();
              expect(
                paragraph.size.height,
                greaterThanOrEqualTo(
                  paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.5,
                ),
                reason: '$part: $text',
              );
            }
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  // P259 (UX-2024, UX-2025, UX-2027, UX-2028; DECISIONS.md «D8 of run
  // 2026-10-22-changes, and the single reminder on shared tasks»): every
  // reminder choice is each person's own. A task given to someone else names
  // them and offers nothing; one that isn't this account's and names nobody
  // shows no reminder; on a shared task the one-tap list and «Recordar antes
  // de» say the reminders are only for you.
  group('P259 · personal reminders', () {
    const phone = Size(360, 800);
    // A shared project this account owns, with Marta (member 2) in it.
    final team = TaskListInfo(
      id: 'team',
      name: 'Equipo',
      shared: true,
      ownerId: 1,
      people: const [
        ProjectMember(id: 1, name: 'Yo', role: 'owner'),
        ProjectMember(id: 2, name: 'Marta', role: 'editor'),
      ],
    );
    // A shared project where this account is an editor: it doesn't manage it.
    final club = TaskListInfo(
      id: 'club',
      name: 'Club',
      shared: true,
      ownerId: 2,
      role: 'editor',
      people: const [
        ProjectMember(id: 2, name: 'Marta', role: 'owner'),
        ProjectMember(id: 1, name: 'Yo', role: 'editor'),
      ],
    );
    final muted = TaskListInfo(
      id: 'quiet',
      name: 'Silencio',
      notifications: 'muted',
    );
    final archived = TaskListInfo(id: 'old', name: 'Antiguo', archived: true);
    final projects = [team, club, muted, archived];
    final at17 = DateTime(2026, 11, 13, 17);
    // Monday 26 October 2026 at 17:00, the first of a weekly series.
    final monday17 = DateTime(2026, 10, 26, 17);
    final justYou = find.byKey(const ValueKey('reminder-plan-just-you'));
    final untilDay = find.byKey(const ValueKey('reminder-plan-until-day'));
    const reminderOff = ReminderPreferences(
      enabled: false,
      dateOnlyTime: 540,
      asked: true,
    );

    /// «Presentar el proyecto» on Fri 13 Nov (at 17:00 when [timed]) in
    /// [listId], as [assignment]; with no day at all when [noDay].
    Task task({
      int? id = 1,
      String? listId = 'team',
      String assignment = 'group',
      int? assigneeId,
      String? assigneeName,
      bool timed = false,
      bool noDay = false,
      int? minutes,
      int? time,
      String anchor = 'planned',
      DateTime? deadline,
      ReminderPlan? plan,
      String recurrence = 'none',
      DateTime? day,
      String title = 'Presentar el proyecto',
      List<ChecklistItem> checklist = const [],
    }) => Task(
      id: id,
      title: title,
      priority: 1,
      dueDate: noDay ? null : day ?? (timed ? at17 : friday13),
      hasTime: timed && !noDay,
      reminderMinutes: minutes,
      reminderTime: time,
      reminderAnchor: anchor,
      deadline: deadline,
      reminderPlan: plan,
      recurrence: recurrence,
      listId: listId,
      assignment: assignment,
      assigneeId: assigneeId,
      assigneeName: assigneeName,
      checklist: checklist,
    );
    Task forMarta({
      int? id = 1,
      bool timed = false,
      bool noDay = false,
      int? minutes,
      int? time,
      String anchor = 'planned',
      DateTime? deadline,
      ReminderPlan? plan,
    }) => task(
      id: id,
      assignment: 'member',
      assigneeId: 2,
      assigneeName: 'Marta',
      timed: timed,
      noDay: noDay,
      minutes: minutes,
      time: time,
      anchor: anchor,
      deadline: deadline,
      plan: plan,
    );
    Task inClub({
      int? id = 1,
      int? minutes,
      DateTime? deadline,
      bool noDay = false,
    }) => task(
      id: id,
      listId: 'club',
      assignment: 'unassigned',
      timed: true,
      noDay: noDay,
      minutes: minutes,
      deadline: deadline,
    );

    /// The words on the task's reminder chip, one per Text.
    List<String> chipWords(WidgetTester tester) => [
      for (final text in tester.widgetList<Text>(
        find.descendant(
          of: find.byType(ReminderChip),
          matching: find.byType(Text),
        ),
      ))
        text.data ?? text.textSpan!.toPlainText(),
    ];

    /// The colour the chip's [words] are drawn in.
    Color chipColor(WidgetTester tester, String words) => tester
        .widget<RichText>(
          find.descendant(
            of: find.descendant(
              of: find.byType(ReminderChip),
              matching: find.text(words),
            ),
            matching: find.byType(RichText),
          ),
        )
        .text
        .style!
        .color!;

    /// The edit form of task 1, «Más detalles» open.
    Future<_App> form(
      WidgetTester tester,
      Task task, {
      ReminderPreferences reminders = const ReminderPreferences(
        enabled: true,
        dateOnlyTime: 540,
        asked: true,
      ),
      String language = 'es',
      double textScale = 1,
    }) async {
      final app = await _App.open(
        tester,
        [task],
        size: phone,
        projects: projects,
        reminders: reminders,
        language: language,
        textScale: textScale,
      );
      app.navigator.pushNamed('/editTask', arguments: 1);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('task-more-details')));
      return app;
    }

    /// The form's «Recordatorio» row.
    Finder formRow() => find.descendant(
      of: find.byType(ReminderControl),
      matching: find.byType(ListTile),
    );

    /// The capture's result for [tasks], one draft each (`d1`, `d2`, …).
    Future<(_App, MemoryCaptures)> capture(
      WidgetTester tester,
      List<Task> tasks,
    ) async {
      final captures = MemoryCaptures();
      final app = await _App.open(
        tester,
        const [],
        captures: captures,
        size: phone,
        projects: projects,
      );
      captures.tasks = app.container;
      captures.current = CaptureSession(
        id: 'p259',
        ownerKey: app.container.read(captureOwnerProvider),
        timezone: 'Europe/Madrid',
        capturedAt: now.toUtc(),
        status: 'ready',
        source: 'speech',
        transcript: 'Presentar el proyecto…',
        drafts: [
          for (final (i, task) in tasks.indexed)
            CaptureDraft(id: 'd${i + 1}', task: task),
        ],
      );
      await openCaptureResult(tester, 'p259');
      expect(find.byType(VoiceTaskScreen), findsOneWidget);
      return (app, captures);
    }

    Finder cardRow([String id = 'd1']) =>
        find.byKey(ValueKey('draft-reminder-$id'));
    Finder cardLine([String id = 'd1']) =>
        find.byKey(ValueKey('draft-reminder-line-$id'));
    Finder needsDay([String id = 'd1']) =>
        find.byKey(ValueKey('draft-reminder-needs-day-$id'));
    Finder chevron(Finder of) => find.descendant(
      of: of,
      matching: find.byIcon(Icons.chevron_right_rounded),
    );

    // ---- UX-2024: the chip names Marta, and none of this account's values.

    final martas = <(String, Task)>[
      (
        'at 17:00 with this account’s «1 hora antes»',
        forMarta(timed: true, minutes: 60),
      ),
      ('date-only with this account’s 8:00', forMarta(time: 480)),
      ('with this account’s reminder off', forMarta(minutes: -1)),
      (
        'counted from its deadline',
        forMarta(deadline: DateTime(2026, 11, 20), anchor: 'deadline'),
      ),
      (
        'with this account’s «Normal» plan',
        forMarta(plan: const ReminderPlan.rhythm(ReminderPlan.normal)),
      ),
    ];
    for (final (language, expected) in [
      ('es', 'Recordatorio para Marta'),
      ('en', 'Reminder for Marta'),
      ('ca', 'Recordatori per a Marta'),
    ]) {
      for (final (what, given) in martas) {
        testWidgets(
          'UX-2024: a task given to Marta $what reads exactly «$expected», '
          'with no value after the name ($language)',
          (tester) async {
            final l = lookupAppLocalizations(Locale(language));
            final app = await _App.open(
              tester,
              [given],
              size: phone,
              projects: projects,
              language: language,
            );
            await app.detail(1);
            expect(find.byType(ReminderChip), findsOneWidget);
            final words = chipWords(tester);
            expect(words, [l.reminderForPersonOnly('Marta')]);
            expect(words.single, isNot(contains(':')));
            expect(words.single.trim(), endsWith('Marta'));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    test('UX-2024: the catalogs have no «reminderForPerson», and '
        '«reminderForPersonOnly» carries its new description', () {
      for (final language in ['en', 'es', 'ca']) {
        final arb =
            jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
                as Map<String, dynamic>;
        expect(arb.containsKey('reminderForPerson'), isFalse);
        expect(arb.containsKey('@reminderForPerson'), isFalse);
        expect(arb['reminderForPersonOnly'], isA<String>());
      }
      final en =
          jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;
      expect(
        (en['@reminderForPersonOnly'] as Map<String, dynamic>)['description'],
        'The reminder line on a task given to someone else. Their reminders '
                'are their own and never reach this phone, so none of this '
                'account’s reminder values is shown. {name} is the person’s name.'
            .replaceAll('’', "'"),
      );
    });

    // ---- UX-2025: someone else's reminders offer nothing.

    testWidgets(
      'UX-2025: the chip on Marta’s task opens nothing and changes nothing, '
      'is drawn at full contrast, and TalkBack hears no button',
      (tester) async {
        final handle = tester.ensureSemantics();
        final given = forMarta(timed: true, minutes: 60);
        final app = await _App.open(
          tester,
          [given],
          size: phone,
          projects: projects,
        );
        await app.detail(1);
        final words = es.reminderForPersonOnly('Marta');
        expect(chipText(words), findsOneWidget);
        final color = chipColor(tester, words);
        expect(
          color.a,
          closeTo(1, 0.001),
          reason: 'information, not Material’s 38% disabled label',
        );
        final scheme = Theme.of(
          tester.element(find.byType(ReminderChip)),
        ).colorScheme;
        expect(color, scheme.onSurface);
        expect(
          tester.getSemantics(find.bySemanticsLabel(words)),
          isSemantics(isButton: false, hasTapAction: false),
        );
        await tester.tap(find.byType(ReminderChip), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(sheet(), findsNothing);
        expect(find.byType(Dialog), findsNothing);
        final after = app.task(1);
        expect(after.reminderMinutes, 60);
        expect(after.reminderTime, isNull);
        expect(after.reminderPlan, isNull);
        expect(after.reminderAnchor, 'planned');
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    testWidgets(
      'UX-2025: in the form, Marta’s row reads «Recordatorio para Marta» '
      'with no chevron, and a tap opens nothing',
      (tester) async {
        await form(tester, forMarta(timed: true, minutes: 60));
        expect(formRow(), findsOneWidget);
        final tile = tester.widget<ListTile>(formRow());
        // P270 (UX-2206): the line names itself, alone in the row.
        expect((tile.title! as Text).data, es.reminderForPersonOnly('Marta'));
        expect(tile.subtitle, isNull);
        expect(tile.trailing, isNull);
        expect(tile.onTap, isNull);
        expect(chevron(find.byType(ReminderControl)), findsNothing);
        await tapVisible(tester, formRow());
        expect(sheet(), findsNothing);
        expect(find.text(es.chooseAlertTime), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('UX-2025: with reminders off on this phone, Marta’s row has no '
        '«Activar recordatorios» (and a «Todos» task’s does)', (tester) async {
      await form(
        tester,
        forMarta(timed: true, minutes: 60),
        reminders: reminderOff,
      );
      expect(
        find.descendant(
          of: find.byType(ReminderControl),
          matching: find.text(es.reminderForPersonOnly('Marta')),
        ),
        findsOneWidget,
      );
      expect(find.text(es.enableReminders), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'UX-2025: control: with reminders off, a «Todos» task’s row offers '
      '«Activar recordatorios»',
      (tester) async {
        await form(tester, task(timed: true), reminders: reminderOff);
        expect(
          find.descendant(
            of: find.byType(ReminderControl),
            matching: find.text(es.enableReminders),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'UX-2025: with no day, Marta’s row still reads «Recordatorio para '
      'Marta», not «Añade una fecha para usar un recordatorio»',
      (tester) async {
        await form(tester, forMarta(noDay: true, minutes: 60));
        expect(formRow(), findsOneWidget);
        final tile = tester.widget<ListTile>(formRow());
        // P270 (UX-2206): the line names itself, alone in the row.
        expect((tile.title! as Text).data, es.reminderForPersonOnly('Marta'));
        expect(tile.subtitle, isNull);
        expect(find.text(es.dateForReminder), findsNothing);
        expect(tile.onTap, isNull);
        expect(tile.trailing, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2025: with a deadline, Marta’s form shows «Fecha límite» and no '
      '«Recordar antes de»',
      (tester) async {
        await form(
          tester,
          forMarta(timed: true, deadline: DateTime(2026, 11, 20)),
        );
        final deadline = find.byKey(const ValueKey('task-deadline'));
        await tester.ensureVisible(deadline);
        await tester.pumpAndSettle();
        expect(deadline, findsOneWidget);
        expect(find.text(es.reminderAnchor), findsNothing);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2025: on the capture card, Marta’s draft at 17:00 with «1 hora '
      'antes» reads «Recordatorio para Marta» above «Más opciones», with no '
      'chevron, and a tap opens nothing',
      (tester) async {
        await capture(tester, [forMarta(id: null, timed: true, minutes: 60)]);
        expect(cardRow(), findsOneWidget);
        expect(
          find.descendant(
            of: cardRow(),
            matching: find.text(es.reminderForPersonOnly('Marta')),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: cardRow(), matching: find.text(es.hourBefore)),
          findsNothing,
        );
        expect(chevron(cardRow()), findsNothing);
        final options = find.byKey(const ValueKey('draft-options-d1'));
        expect(
          tester.getTopLeft(cardRow()).dy,
          lessThan(tester.getTopLeft(options).dy),
        );
        // The capture's result is itself a bottom sheet: no other opens.
        final sheets = sheet().evaluate().length;
        await tapVisible(
          tester,
          find.descendant(
            of: cardRow(),
            matching: find.text(es.reminderForPersonOnly('Marta')),
          ),
        );
        expect(sheet(), findsNWidgets(sheets));
        expect(find.text(es.chooseAlertTime), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2025: on the capture card, Marta’s draft with no day and «1 hora '
      'antes» doesn’t ask «Para recordártelo, ponle un día.»',
      (tester) async {
        await capture(tester, [forMarta(id: null, noDay: true, minutes: 60)]);
        expect(needsDay(), findsNothing);
        expect(find.text(es.reminderNeedsDay), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('UX-2025: in a result of three, Marta’s collapsed row shows '
        '«Recordatorio para Marta» under its date line, with no chevron, read '
        'as text', (tester) async {
      final handle = tester.ensureSemantics();
      await capture(tester, [
        Task(
          title: 'Comprar pan y leche',
          priority: 1,
          dueDate: DateTime(2026, 10, 22),
          hasTime: false,
        ),
        forMarta(id: null, timed: true, minutes: 60),
        Task(
          title: 'Recoger a los niños del colegio',
          priority: 1,
          dueDate: DateTime(2026, 10, 22, 17),
          hasTime: true,
        ),
      ]);
      final words = es.reminderForPersonOnly('Marta');
      expect(cardLine('d2'), findsOneWidget);
      expect(
        find.descendant(of: cardLine('d2'), matching: find.text(words)),
        findsOneWidget,
      );
      expect(chevron(cardLine('d2')), findsNothing);
      expect(
        tester.getTopLeft(cardLine('d2')).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(const ValueKey('draft-schedule-d2'))).dy,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(words)),
        isSemantics(label: words, isButton: false, hasTapAction: false),
      );
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    // ---- UX-2028: not this account's, naming nobody: no reminder at all.

    // A task with one step: the details' card, then 28 dp, then the
    // reminder chip and its 16 dp when there is one, then the steps.
    final steps = [ChecklistItem(title: 'Revisar')];
    double stepsBelowCard(WidgetTester tester) =>
        tester.getTopLeft(find.text(es.checklistCount(0, 1).toUpperCase())).dy -
        tester
            .getBottomLeft(
              find.ancestor(
                of: find.byIcon(Icons.schedule_outlined),
                matching: find.byType(AppSurface),
              ),
            )
            .dy;

    testWidgets(
      'UX-2028: an unassigned task in «Club», where you’re an editor, has no '
      'reminder chip and no gap for one',
      (tester) async {
        final app = await _App.open(
          tester,
          [inClub().copyWith(checklist: steps)],
          size: phone,
          projects: projects,
        );
        await app.detail(1);
        expect(find.byType(ReminderChip), findsNothing);
        expect(find.textContaining(es.minutesBefore(10)), findsNothing);
        expect(
          stepsBelowCard(tester),
          moreOrLessEquals(28, epsilon: 0.5),
          reason: 'With no chip, its 16 dp gap goes too.',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2028: the same unassigned task in «Equipo», which you own, reads '
      '«Recordatorio: 10 minutos antes» and opens the reminder sheet',
      (tester) async {
        final app = await _App.open(
          tester,
          [
            task(
              assignment: 'unassigned',
              timed: true,
            ).copyWith(checklist: steps),
          ],
          size: phone,
          projects: projects,
        );
        await app.detail(1);
        expect(chipWords(tester), [es.reminderValue(es.minutesBefore(10))]);
        final chip = tester.getSize(find.byType(ReminderChip)).height;
        expect(
          stepsBelowCard(tester),
          moreOrLessEquals(28 + chip + 16, epsilon: 0.5),
        );
        await openSheet(tester);
        expect(inSheet(untilDay), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2028: a member’s task in «Equipo» with no name shows no reminder',
      (tester) async {
        final app = await _App.open(
          tester,
          [task(assignment: 'member', assigneeId: 3, timed: true, minutes: 60)],
          size: phone,
          projects: projects,
        );
        await app.detail(1);
        expect(find.byType(ReminderChip), findsNothing);
        expect(find.textContaining(es.hourBefore), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2028: the edit form of the unassigned task in «Club» has no '
      '«Recordatorio» row and, with a deadline, no «Recordar antes de»',
      (tester) async {
        await form(tester, inClub(deadline: DateTime(2026, 11, 20)));
        expect(formRow(), findsNothing);
        expect(
          find.descendant(
            of: find.byType(ReminderControl),
            matching: find.text(es.reminder),
          ),
          findsNothing,
        );
        expect(find.text(es.dateForReminder), findsNothing);
        final deadline = find.byKey(const ValueKey('task-deadline'));
        await tester.ensureVisible(deadline);
        await tester.pumpAndSettle();
        expect(deadline, findsOneWidget);
        expect(find.text(es.reminderAnchor), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2028: as a capture draft with «1 hora antes», the unassigned task '
      'in «Club» shows no reminder row, and with no day no needs-day line',
      (tester) async {
        await capture(tester, [
          inClub(id: null, minutes: 60),
          inClub(id: null, minutes: 60, noDay: true),
        ]);
        // Two drafts: each card may be open or collapsed; neither shows any
        // reminder.
        for (final id in ['d1', 'd2']) {
          expect(cardRow(id), findsNothing);
          expect(cardLine(id), findsNothing);
          expect(needsDay(id), findsNothing);
        }
        expect(find.text(es.reminderNeedsDay), findsNothing);
        expect(find.textContaining(es.hourBefore), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2028: a single «Club» draft with «1 hora antes» has no reminder row '
      'and nothing about it in «Más opciones»',
      (tester) async {
        await capture(tester, [inClub(id: null, minutes: 60)]);
        expect(cardRow(), findsNothing);
        expect(cardLine(), findsNothing);
        expect(needsDay(), findsNothing);
        expect(find.textContaining(es.hourBefore), findsNothing);
        expect(find.textContaining(es.reminderValue('')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2028: in a result of three, the «Club» draft’s collapsed row has '
      'no reminder line',
      (tester) async {
        await capture(tester, [
          Task(
            title: 'Comprar pan y leche',
            priority: 1,
            dueDate: DateTime(2026, 10, 22),
            hasTime: false,
          ),
          inClub(id: null, minutes: 60),
          Task(
            title: 'Recoger a los niños del colegio',
            priority: 1,
            dueDate: DateTime(2026, 10, 22, 17),
            hasTime: true,
          ),
        ]);
        expect(find.byKey(const ValueKey('draft-schedule-d2')), findsOneWidget);
        expect(cardLine('d2'), findsNothing);
        expect(needsDay('d2'), findsNothing);
        expect(find.textContaining(es.hourBefore), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    // ---- UX-2027: on a shared task, the one-tap list says «solo para ti».

    final weekly = task(
      timed: true,
      day: monday17,
      recurrence: 'weekly',
      title: 'Sacar la basura',
    );
    for (final (language, textScale) in [('es', 1.0), ('ca', 2.0)]) {
      testWidgets(
        'UX-2027: a «Todos» task repeating every Monday opens the one-tap '
        'list with «solo para ti» under «Recordatorio», whole, and «1 hora '
        'antes» sets 60 ($language ${textScale}x)',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          final app = await _App.open(
            tester,
            [weekly],
            size: phone,
            projects: projects,
            language: language,
            textScale: textScale,
          );
          await app.detail(1);
          await openSheet(tester);
          // The one-tap list, not the plans' sheet.
          expect(inSheet(untilDay), findsNothing);
          final title = inSheet(find.text(l.reminder));
          expect(title, findsOneWidget);
          expect(inSheet(justYou), findsOneWidget);
          expect(tester.widget<Text>(justYou).data, l.reminderPlanJustYou);
          final titleBox = tester.getRect(title);
          final line = tester.getRect(justYou);
          final firstRow = tester.getRect(inSheet(find.byType(ListTile)).first);
          expect(line.top, greaterThanOrEqualTo(titleBox.bottom - 0.5));
          expect(
            line.top - titleBox.bottom,
            lessThanOrEqualTo(8.5),
            reason: 'Directly under the title.',
          );
          expect(line.bottom, lessThanOrEqualTo(firstRow.top + 0.5));
          expect(line.left, moreOrLessEquals(titleBox.left, epsilon: 0.5));
          expect(line.left, greaterThanOrEqualTo(24 - 0.5));
          expect(line.right, lessThanOrEqualTo(phone.width - 24 + 0.5));
          expect(line.top, greaterThanOrEqualTo(0));
          expect(line.bottom, lessThanOrEqualTo(phone.height));
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: justYou, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          final style = tester.widget<Text>(justYou).style!;
          final theme = Theme.of(tester.element(justYou));
          expect(style.color, theme.colorScheme.onSurfaceVariant);
          expect(style.fontSize, theme.textTheme.bodyMedium!.fontSize);
          await tapVisible(tester, inSheet(find.text(l.hourBefore)));
          expect(sheet(), findsNothing);
          expect(app.task(1).reminderMinutes, 60);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2027: a personal task repeating every Monday opens the one-tap list '
      'with no «solo para ti»',
      (tester) async {
        final app = await _App.open(
          tester,
          [
            task(
              listId: null,
              assignment: 'personal',
              timed: true,
              day: monday17,
              recurrence: 'weekly',
              title: 'Sacar la basura',
            ),
          ],
          size: phone,
          projects: projects,
        );
        await app.detail(1);
        await openSheet(tester);
        expect(inSheet(find.text(es.reminder)), findsOneWidget);
        expect(inSheet(find.text(es.hourBefore)), findsOneWidget);
        expect(justYou, findsNothing);
        expect(find.text(es.reminderPlanJustYou), findsNothing);
      },
    );

    testWidgets(
      'UX-2027: Ajustes › Recordatorios › «Tareas con hora» has no «solo para '
      'ti»',
      (tester) async {
        final app = await _App.open(
          tester,
          const [],
          size: phone,
          projects: projects,
        );
        app.navigator.pushNamed('/notifications');
        await tester.pumpAndSettle();
        final timed = find.text(es.timedTasks);
        await tester.scrollUntilVisible(
          timed,
          160,
          scrollable: find
              .descendant(
                of: find.byType(Scaffold).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(timed);
        await tester.pumpAndSettle();
        expect(sheet(), findsOneWidget);
        expect(inSheet(find.text(es.hourBefore)), findsOneWidget);
        expect(justYou, findsNothing);
        expect(find.text(es.reminderPlanJustYou), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    for (final (language, textScale) in [('es', 1.0), ('ca', 2.0)]) {
      testWidgets(
        'UX-2027: a «Todos» task’s «Recordar antes de» says «solo para ti» as '
        'its helper, whole ($language ${textScale}x)',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          await form(
            tester,
            task(timed: true, deadline: DateTime(2026, 11, 20)),
            language: language,
            textScale: textScale,
          );
          final anchor = find.byKey(const ValueKey('reminder-anchor-planned'));
          await tester.ensureVisible(anchor);
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: anchor, matching: find.text(l.reminderAnchor)),
            findsOneWidget,
          );
          final helper = find.descendant(
            of: anchor,
            matching: find.text(l.reminderPlanJustYou),
          );
          expect(helper, findsOneWidget);
          await tester.ensureVisible(helper);
          await tester.pumpAndSettle();
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: helper, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(
            paragraph.getMaxIntrinsicWidth(double.infinity) <=
                    paragraph.size.width + 0.5 ||
                paragraph.size.height >
                    paragraph.getMinIntrinsicHeight(paragraph.size.width) - 0.5,
            isTrue,
            reason: 'one line holds it, or it wraps whole',
          );
          final rect = tester.getRect(helper);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(phone.width));
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2027: a personal task’s «Recordar antes de» has no helper',
      (tester) async {
        await form(
          tester,
          task(
            listId: null,
            assignment: 'personal',
            timed: true,
            deadline: DateTime(2026, 11, 20),
          ),
        );
        final anchor = find.byKey(const ValueKey('reminder-anchor-planned'));
        await tester.ensureVisible(anchor);
        await tester.pumpAndSettle();
        expect(anchor, findsOneWidget);
        expect(find.text(es.reminderPlanJustYou), findsNothing);
        final decoration = tester
            .widget<InputDecorator>(
              find.descendant(
                of: anchor,
                matching: find.byType(InputDecorator),
              ),
            )
            .decoration;
        expect(decoration.helperText, isNull);
      },
    );

    // ---- Unchanged.

    for (final (what, given) in [
      ('a «Todos» task', task(timed: true)),
      (
        'a task given to this account',
        task(
          assignment: 'member',
          assigneeId: 1,
          assigneeName: 'Yo',
          timed: true,
        ),
      ),
    ]) {
      testWidgets(
        'UX-2024: $what still reads «Recordatorio: 10 minutos antes» and '
        'opens the reminder sheet',
        (tester) async {
          final app = await _App.open(
            tester,
            [given],
            size: phone,
            projects: projects,
          );
          await app.detail(1);
          expect(chipWords(tester), [es.reminderValue(es.minutesBefore(10))]);
          await openSheet(tester);
          expect(inSheet(untilDay), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2025: a project muted here still reads «Sin recordatorio: proyecto '
      'silenciado» and opens «Novedades del proyecto»',
      (tester) async {
        final app = await _App.open(
          tester,
          [task(listId: 'quiet', assignment: 'personal', timed: true)],
          size: phone,
          projects: projects,
        );
        await app.detail(1);
        expect(chipWords(tester), [es.noReminderProjectMuted]);
        await tapVisible(tester, find.byType(ReminderChip));
        expect(sheet(), findsOneWidget);
        expect(inSheet(find.text(es.projectNotifications)), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2025: an archived project’s «Sin recordatorio: proyecto archivado» '
      'has no tap and is drawn at full contrast',
      (tester) async {
        final handle = tester.ensureSemantics();
        final app = await _App.open(
          tester,
          [task(listId: 'old', assignment: 'personal', timed: true)],
          size: phone,
          projects: projects,
        );
        await app.detail(1);
        final words = es.noReminderProjectArchived;
        expect(chipWords(tester), [words]);
        expect(chipColor(tester, words).a, closeTo(1, 0.001));
        expect(
          tester.getSemantics(find.bySemanticsLabel(words)),
          isSemantics(isButton: false, hasTapAction: false),
        );
        await tester.tap(find.byType(ReminderChip), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(sheet(), findsNothing);
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );
  });

  // P261: D8 (UX-2022), a plan's own hour stays on the task's day wherever
  // the app shows it; UX-2026, on a shared task the sheet's «solo para ti»
  // sits once under its title, over every choice; UX-2031, the strip's end
  // label keeps its date on one line at 2×.
  group('P261 · D8, UX-2026, UX-2031', () {
    const phone = Size(360, 800);
    const short = Size(360, 740);
    final sameDay = ReminderPlan.custom(
      const [PlanPhase(0, 0, 1)],
      time: 540,
      said: 'el mismo día a las 9',
    );
    final everyDay = ReminderPlan.custom(
      const [PlanPhase(366, 0, 1)],
      time: 480,
      said: 'cada día a las 8',
    );
    final team = TaskListInfo(
      id: 'team',
      name: 'Equipo',
      shared: true,
      ownerId: 1,
      people: const [
        ProjectMember(id: 1, name: 'Yo', role: 'owner'),
        ProjectMember(id: 2, name: 'Marta', role: 'editor'),
      ],
    );

    /// «Presentar el proyecto» on Fri 13 Nov 2026 at 17:00 with [plan].
    Task timed({int? id = 1, ReminderPlan? plan}) => Task(
      id: id,
      title: 'Presentar el proyecto',
      priority: 1,
      dueDate: DateTime(2026, 11, 13, 17),
      hasTime: true,
      reminderPlan: plan,
    );

    /// A «Todos» task in «Equipo», 22 days away.
    Task forAll({ReminderPlan? plan}) => Task(
      id: 1,
      title: 'Presentar el proyecto',
      priority: 1,
      dueDate: friday13,
      hasTime: false,
      reminderPlan: plan,
      listId: 'team',
      assignment: 'group',
    );

    /// «Recordatorios: [rhythm] · próximo: [when] [date], [time]».
    String ownLine(String rhythm, String when, String date, String time) =>
        es.reminderPlanLine(es.reminderPlanOwnLine(rhythm), when, date, time);

    final justYou = find.byKey(const ValueKey('reminder-plan-just-you'));
    final listo = find.byKey(const ValueKey('reminder-plan-apply'));
    final untilDay = find.byKey(const ValueKey('reminder-plan-until-day'));
    final yourWay = find.byKey(const ValueKey('reminder-plan-your-way'));
    final count = find.byKey(const ValueKey('reminder-plan-count'));

    Future<String> countText(WidgetTester tester) async {
      expect(count, findsOneWidget);
      await tester.ensureVisible(count);
      await tester.pumpAndSettle();
      return tester.widget<Text>(count).data!;
    }

    void wholeOnScreen(WidgetTester tester, Finder finder, Size size) {
      final box = tester.getRect(finder);
      expect(box.top, greaterThanOrEqualTo(0), reason: '$finder');
      expect(box.bottom, lessThanOrEqualTo(size.height), reason: '$finder');
      expect(box.left, greaterThanOrEqualTo(0), reason: '$finder');
      expect(box.right, lessThanOrEqualTo(size.width), reason: '$finder');
    }

    RenderParagraph paragraphOf(WidgetTester tester, Finder text) =>
        tester.renderObject<RenderParagraph>(
          find.descendant(of: text, matching: find.byType(RichText)).first,
        );

    int lines(RenderParagraph paragraph) => paragraph
        .getBoxesForSelection(
          TextSelection(
            baseOffset: 0,
            extentOffset: paragraph.text.toPlainText().length,
          ),
        )
        .map((box) => box.top.round())
        .toSet()
        .length;

    // UX-2022: the task's chip.
    for (final scale in [1.0, 2.0]) {
      for (final (what, plan, at, line) in [
        (
          '«el mismo día a las 9», at now',
          sameDay,
          now,
          ownLine(es.reminderPlanOnTheDay, 'other', 'vie 13', '09:00'),
        ),
        (
          '«el mismo día a las 9», at Fri 13 Nov 08:00',
          sameDay,
          DateTime(2026, 11, 13, 8),
          ownLine(es.reminderPlanOnTheDay, 'today', '', '09:00'),
        ),
        (
          '«cada día a las 8», at Fri 13 Nov 07:00',
          everyDay,
          DateTime(2026, 11, 13, 7),
          ownLine(es.reminderPlanEveryDays(1), 'today', '', '08:00'),
        ),
      ]) {
        testWidgets(
          'UX-2022: at $scale× on 360×800, a task at 17:00 with $what reads '
          '«$line», whole',
          (tester) async {
            await (await _App.open(
              tester,
              [timed(plan: plan)],
              size: phone,
              textScale: scale,
              at: at,
            )).detail(1);
            final text = chipText(line);
            expect(text, findsOneWidget);
            expect(find.textContaining('16:50'), findsNothing);
            await tester.ensureVisible(text);
            await tester.pumpAndSettle();
            expect(paragraphOf(tester, text).didExceedMaxLines, isFalse);
            wholeOnScreen(tester, text, phone);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets(
      'UX-2022: Pro at Fri 13 Nov 08:00, the sheet opens on «A tu manera» '
      'with «1 aviso: hoy, 09:00», and Normal on the same sheet reads '
      '«1 aviso: hoy, 16:50»',
      (tester) async {
        await (await _App.open(
          tester,
          [timed(plan: sameDay)],
          size: phone,
          at: DateTime(2026, 11, 13, 8),
        )).detail(1);
        await openSheet(tester);
        expect(
          find.byKey(const ValueKey('reminder-plan-words')),
          findsOneWidget,
          reason: 'Opened on «A tu manera».',
        );
        expect(
          await countText(tester),
          es.reminderPlanCount(1, 'today', '', '09:00'),
        );
        await tapVisible(tester, inSheet(untilDay));
        expect(
          await countText(tester),
          es.reminderPlanCount(1, 'today', '', '16:50'),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('UX-2022: a free account with the same dictated plan sees the '
        'read-only count «1 aviso: hoy, 09:00»', (tester) async {
      await (await _App.open(
        tester,
        [timed(plan: sameDay)],
        pro: false,
        size: phone,
        at: DateTime(2026, 11, 13, 8),
      )).detail(1);
      await openSheet(tester);
      expect(find.byKey(const ValueKey('reminder-plan-words')), findsNothing);
      expect(
        await countText(tester),
        es.reminderPlanCount(1, 'today', '', '09:00'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'UX-2022: «A tu manera» typing «el mismo día a las 9» on the task at '
      '17:00 previews «1 aviso: vie 13, 09:00», not 16:50',
      (tester) async {
        final app = await _App.open(tester, [timed()], size: phone);
        app.api.answer = {'reminder_plan': sameDay.toJson()};
        await app.detail(1);
        await openSheet(tester);
        await tapVisible(tester, inSheet(yourWay));
        await tester.enterText(
          find.byKey(const ValueKey('reminder-plan-words')),
          'el mismo día a las 9',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(app.api.requests, hasLength(1));
        final text = await countText(tester);
        expect(text, es.reminderPlanCount(1, 'other', 'vie 13', '09:00'));
        expect(text, isNot(contains('16:50')));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2022: at Thu 12 Nov 10:00, a dictated draft for Fri 13 Nov at 17:00 '
      'with «el mismo día a las 9» reads «Recordatorios: el mismo día · '
      'próximo: mañana, 09:00» on the capture card',
      (tester) async {
        final at = DateTime(2026, 11, 12, 10);
        final captures = MemoryCaptures();
        final app = await _App.open(
          tester,
          const [],
          captures: captures,
          size: phone,
          at: at,
        );
        captures.tasks = app.container;
        captures.current = CaptureSession(
          id: 'p261',
          ownerKey: app.container.read(captureOwnerProvider),
          timezone: 'Europe/Madrid',
          capturedAt: at.toUtc(),
          status: 'ready',
          source: 'speech',
          transcript: 'Presentar el proyecto el viernes a las 17…',
          drafts: [
            CaptureDraft(
              id: 'd1',
              task: timed(id: null, plan: sameDay),
            ),
          ],
        );
        await openCaptureResult(tester, 'p261');
        expect(find.byType(VoiceTaskScreen), findsOneWidget);
        expect(
          find.text(ownLine(es.reminderPlanOnTheDay, 'tomorrow', '', '09:00')),
          findsOneWidget,
        );
        expect(find.textContaining('16:50'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    // UX-2026: on a shared task, one line under the title.

    /// The line reads [l]'s copy, once in the sheet, directly under the
    /// title and above the choices: the scrolling list of rows and plans
    /// starts under it. Unscrolled ([top]), the first single row is right
    /// under it too.
    void expectUnderTitle(
      WidgetTester tester,
      AppLocalizations l, {
      bool top = false,
    }) {
      expect(justYou, findsOneWidget);
      expect(inSheet(justYou), findsOneWidget);
      expect(tester.widget<Text>(justYou).data, l.reminderPlanJustYou);
      final title = tester.getRect(inSheet(find.text(l.reminder)));
      final line = tester.getRect(justYou);
      expect(line.top, greaterThanOrEqualTo(title.bottom - 0.5));
      expect(line.top - title.bottom, lessThanOrEqualTo(16));
      final choices = tester.getRect(
        find
            .descendant(
              of: sheet().last,
              matching: find.byType(SingleChildScrollView),
            )
            .first,
      );
      expect(
        choices.top,
        greaterThanOrEqualTo(line.bottom - 0.5),
        reason: 'The choices scroll under the line, not over it.',
      );
      if (top) {
        final firstRow = tester.getRect(
          find
              .descendant(of: sheet().last, matching: find.byType(ListTile))
              .first,
        );
        expect(line.bottom, lessThanOrEqualTo(firstRow.top + 0.5));
        expect(firstRow.top - line.bottom, lessThanOrEqualTo(24));
        expect(
          line.bottom,
          lessThanOrEqualTo(tester.getRect(inSheet(find.text(l.off))).top),
        );
      }
    }

    testWidgets(
      'UX-2026: a «Todos» task in «Equipo»: «Recordatorio», then «Estos avisos '
      'son solo para ti.» under it and above the first row, once, before and '
      'after opening «Hasta la fecha límite» and «A tu manera», none above '
      '«Listo»',
      (tester) async {
        final app = await _App.open(
          tester,
          [forAll()],
          size: phone,
          projects: [team],
        );
        app.api.answer = {'reminder_plan': ownersPlan.toJson()};
        await app.detail(1);
        await openSheet(tester);
        expectUnderTitle(tester, es, top: true);
        await tapVisible(tester, inSheet(untilDay));
        expect(listo, findsOneWidget);
        expectUnderTitle(tester, es);
        expect(
          tester.getRect(justYou).bottom,
          lessThan(tester.getRect(untilDay).top),
          reason: 'Not above «Listo»: above the plans.',
        );
        await tapVisible(tester, inSheet(yourWay));
        expectUnderTitle(tester, es);
        await tester.enterText(
          find.byKey(const ValueKey('reminder-plan-words')),
          'cada 3 días y la última semana a diario',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(listo, findsOneWidget);
        expectUnderTitle(tester, es);
        expect(
          tester.getRect(justYou).bottom,
          lessThan(tester.getRect(yourWay).top),
        );
        expect(tester.takeException(), isNull);
      },
    );

    for (final (language, l) in [('es', es), ('ca', ca)]) {
      testWidgets('UX-2026: at 2× on 360×740 in $language, after opening '
          '«${l.reminderPlanUntilDay}» the line and «${l.done}» are on screen, '
          'and scrolling the choices leaves the title and the line in place', (
        tester,
      ) async {
        await (await _App.open(
          tester,
          [forAll()],
          language: language,
          textScale: 2,
          size: short,
          projects: [team],
        )).detail(1);
        await openSheet(tester);
        await tapVisible(tester, inSheet(find.text(l.reminderPlanUntilDay)));
        expectUnderTitle(tester, l);
        wholeOnScreen(tester, justYou, short);
        wholeOnScreen(tester, listo, short);
        expect(listo.hitTestable(), findsOneWidget);
        expect(paragraphOf(tester, justYou).didExceedMaxLines, isFalse);

        final title = inSheet(find.text(l.reminder));
        final titleBefore = tester.getRect(title);
        final lineBefore = tester.getRect(justYou);
        final listoBefore = tester.getRect(listo);
        final choices = find
            .descendant(
              of: sheet().last,
              matching: find.byType(SingleChildScrollView),
            )
            .first;
        await tester.drag(choices, const Offset(0, 300));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(listo).top,
          isNot(moreOrLessEquals(listoBefore.top, epsilon: 1)),
          reason: 'The choices scrolled.',
        );
        expect(tester.getRect(title), titleBefore);
        expect(tester.getRect(justYou), lineBefore);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'UX-2026: at 2× on 360×740 in $language, with Normal set, the sheet '
        'opens scrolled to «${l.reminderPlanUntilDay}» with the line on '
        'screen',
        (tester) async {
          await (await _App.open(
            tester,
            [forAll(plan: const ReminderPlan.rhythm(ReminderPlan.normal))],
            language: language,
            textScale: 2,
            size: short,
            projects: [team],
          )).detail(1);
          await openSheet(tester);
          await tester.pumpAndSettle();
          expectUnderTitle(tester, l);
          wholeOnScreen(tester, justYou, short);
          final line = tester.getRect(justYou);
          final row = tester.getRect(untilDay);
          expect(row.top, greaterThanOrEqualTo(line.bottom - 0.5));
          expect(
            row.top - line.bottom,
            lessThanOrEqualTo(24),
            reason: '«${l.reminderPlanUntilDay}» at the top of the choices.',
          );
          expect(untilDay.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2026: on that task «Desactivado» still turns the reminder off in '
      'one tap and closes the sheet',
      (tester) async {
        final app = await _App.open(
          tester,
          [forAll()],
          size: phone,
          projects: [team],
        );
        await app.detail(1);
        await openSheet(tester);
        await tapVisible(tester, inSheet(find.text(es.off)));
        expect(sheet(), findsNothing);
        expect(app.task(1).reminderMinutes, -1);
        expect(app.task(1).reminderPlan, isNull);
      },
    );

    testWidgets(
      'UX-2026: a personal task’s sheet has no such line, and its title '
      'scrolls with its rows',
      (tester) async {
        await (await _App.open(
          tester,
          [presentation()],
          textScale: 2,
          size: short,
        )).detail(1);
        await openSheet(tester);
        expect(justYou, findsNothing);
        expect(find.text(es.reminderPlanJustYou), findsNothing);
        final title = inSheet(find.text(es.reminder));
        final before = tester.getRect(title);
        final choices = find
            .descendant(
              of: sheet().last,
              matching: find.byType(SingleChildScrollView),
            )
            .first;
        await tester.drag(choices, const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(tester.getRect(title).top, lessThan(before.top - 1));
        await tapVisible(tester, inSheet(untilDay));
        expect(justYou, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    // UX-2031: the strip's end label on one line.
    for (final (language, l) in [('ca', ca), ('es', es), ('en', en)]) {
      testWidgets(
        'UX-2031: at 2× on 360×740 in $language, a task 60 days away: the '
        'strip’s end label is on one line at the row’s end, and '
        '«${l.today}» on one line at its start',
        (tester) async {
          final day = DateTime(2026, 12, 21);
          await (await _App.open(
            tester,
            [presentation(day: day)],
            language: language,
            textScale: 2,
            size: short,
          )).detail(1);
          await openSheet(tester);
          await tapVisible(tester, inSheet(find.text(l.reminderPlanUntilDay)));
          final preview = find.byKey(const ValueKey('reminder-plan-preview'));
          // The day as planDay writes it in the app's own locale.
          final locale = tester.element(preview).localeName;
          final label = find.descendant(
            of: preview,
            matching: find.text(planDay(day, now, locale)),
          );
          final today = find.descendant(
            of: preview,
            matching: find.text(l.today),
          );
          expect(label, findsOneWidget);
          expect(today, findsOneWidget);
          if (language == 'ca') {
            expect(planDay(day, now, 'ca'), 'dl., 21 de des.');
          }
          await tester.ensureVisible(label);
          await tester.pumpAndSettle();
          final strip = tester.getRect(
            find.descendant(of: preview, matching: find.byType(PlanStrip)),
          );
          final end = paragraphOf(tester, label);
          final start = paragraphOf(tester, today);
          for (final (what, paragraph) in [('end', end), ('start', start)]) {
            expect(lines(paragraph), 1, reason: 'The $what label.');
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(
              paragraph.textScaler.scale(10),
              moreOrLessEquals(20),
              reason: 'No smaller text.',
            );
          }
          double glyphs(RenderParagraph paragraph, bool right) {
            final boxes = paragraph.getBoxesForSelection(
              TextSelection(
                baseOffset: 0,
                extentOffset: paragraph.text.toPlainText().length,
              ),
            );
            final x = right
                ? boxes.map((b) => b.right).reduce((a, b) => a > b ? a : b)
                : boxes.map((b) => b.left).reduce((a, b) => a < b ? a : b);
            return paragraph.localToGlobal(Offset(x, 0)).dx;
          }

          expect(
            glyphs(end, true),
            moreOrLessEquals(strip.right, epsilon: 1),
            reason: 'The day ends at the row’s end.',
          );
          expect(
            glyphs(start, false),
            moreOrLessEquals(strip.left, epsilon: 1),
            reason: '«${l.today}» starts at the row’s start.',
          );
          expect(
            find.ancestor(of: label, matching: find.byType(FittedBox)),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    test('UX-2026: @reminderPlanJustYou carries the new description, and its '
        'three values are unchanged', () {
      final catalog =
          jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;
      expect(
        (catalog['@reminderPlanJustYou'] as Map)['description'],
        'On a task in a shared project, says that every reminder choice '
        'there rings only for the person who makes it: shown under the '
        'title of the reminder sheet and of the one-tap reminder list, and '
        'as the helper of “Remind before”.',
      );
      expect(catalog['reminderPlanJustYou'], en.reminderPlanJustYou);
      expect(en.reminderPlanJustYou, 'These reminders are only for you.');
      expect(es.reminderPlanJustYou, 'Estos avisos son solo para ti.');
      expect(ca.reminderPlanJustYou, 'Aquests avisos són només per a tu.');
    });
  });

  group('P262 · UX-2030', () {
    // A shared project you own, with Marta (member 2) in it.
    final team = TaskListInfo(
      id: 'team',
      name: 'Equipo',
      shared: true,
      ownerId: 1,
      people: const [
        ProjectMember(id: 1, name: 'Yo', role: 'owner'),
        ProjectMember(id: 2, name: 'Marta', role: 'editor'),
      ],
    );
    final muted = TaskListInfo(
      id: 'quiet',
      name: 'Silencio',
      notifications: 'muted',
    );
    final archived = TaskListInfo(id: 'old', name: 'Antiguo', archived: true);
    const normal = ReminderPlan.rhythm(ReminderPlan.normal);

    /// «Presentar el proyecto» on Fri 13 Nov, on this account's Normal, in
    /// [listId] as [assignment].
    Task planned({
      String? listId,
      String assignment = 'personal',
      int? assigneeId,
      String? assigneeName,
    }) => Task(
      id: 1,
      title: 'Presentar el proyecto',
      priority: 1,
      dueDate: friday13,
      hasTime: false,
      reminderPlan: normal,
      listId: listId,
      assignment: assignment,
      assigneeId: assigneeId,
      assigneeName: assigneeName,
    );

    /// Ajustes › Recordatorios in Spanish at 1× on 390×844, reminders on and
    /// «Tareas sin hora» off, with [task] the only task; returns the
    /// «Tareas sin hora» row's subtitle as the screen shows it.
    Future<String> dateOnlyRow(WidgetTester tester, Task task) async {
      final app = await _App.open(
        tester,
        [task],
        size: const Size(390, 844),
        projects: [team, muted, archived],
        reminders: const ReminderPreferences(enabled: true, asked: true),
      );
      app.navigator.pushNamed('/notifications');
      await tester.pumpAndSettle();
      final row = find.widgetWithText(ListTile, es.dateOnlyTasks);
      expect(row, findsOneWidget);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final subtitle = (tester.widget<ListTile>(row).subtitle! as Text).data!;
      expect(
        find.descendant(of: row, matching: find.text(subtitle)),
        findsOneWidget,
      );
      return subtitle;
    }

    for (final (what, task) in [
      (
        'given to Marta in a shared project',
        planned(
          listId: 'team',
          assignment: 'member',
          assigneeId: 2,
          assigneeName: 'Marta',
        ),
      ),
      ('in a project muted on this phone', planned(listId: 'quiet')),
      ('in an archived project', planned(listId: 'old')),
    ]) {
      testWidgets(
        'UX-2030: with the only planned task $what, «Tareas sin hora» reads '
        '«Desactivado» alone',
        (tester) async {
          final subtitle = await dateOnlyRow(tester, task);
          expect(subtitle, es.off);
          expect(find.textContaining(es.reminderPlanUntilDay), findsNothing);
        },
      );
    }

    for (final (what, task) in [
      (
        'a «Todos» task of the shared project',
        planned(listId: 'team', assignment: 'group'),
      ),
      ('a personal task', planned()),
    ]) {
      testWidgets(
        'UX-2030: as $what it still reads «Desactivado · «Hasta la fecha '
        'límite»: 9:00»',
        (tester) async {
          final subtitle = await dateOnlyRow(tester, task);
          final time = const TimeOfDay(
            hour: 9,
            minute: 0,
          ).format(tester.element(find.text(es.dateOnlyTasks)));
          expect(time, anyOf('9:00', '09:00'));
          expect(subtitle, es.dateOnlyOffPlans(time));
          expect(subtitle, startsWith('${es.off} · '));
          expect(subtitle, contains('«${es.reminderPlanUntilDay}»'));
        },
      );
    }
  });

  // P264 (UX-2025, UX-2034): a reminder line with no tap is information.
  // TalkBack hears it as plain text, with no enabled state (so never
  // «desactivado»), and the task's chip draws it with no outline and no
  // fill, at full contrast; a line with a tap keeps its button and outline.
  group('P264 · UX-2025, UX-2034', () {
    const phone = Size(360, 800);
    // A shared project this account owns, with Marta (member 2) in it.
    final team = TaskListInfo(
      id: 'team',
      name: 'Equipo',
      shared: true,
      ownerId: 1,
      people: const [
        ProjectMember(id: 1, name: 'Yo', role: 'owner'),
        ProjectMember(id: 2, name: 'Marta', role: 'editor'),
      ],
    );
    final muted = TaskListInfo(
      id: 'quiet',
      name: 'Silencio',
      notifications: 'muted',
    );
    final archived = TaskListInfo(id: 'old', name: 'Antiguo', archived: true);
    final projects = [team, muted, archived];

    /// «Presentar el proyecto» on Fri 13 Nov at 17:00 in [listId].
    Task task({
      int? id = 1,
      String? listId = 'team',
      String assignment = 'group',
      int? assigneeId,
      String? assigneeName,
      int? minutes,
    }) => Task(
      id: id,
      title: 'Presentar el proyecto',
      priority: 1,
      dueDate: DateTime(2026, 11, 13, 17),
      hasTime: true,
      reminderMinutes: minutes,
      listId: listId,
      assignment: assignment,
      assigneeId: assigneeId,
      assigneeName: assigneeName,
    );
    Task forMarta({int? id = 1}) => task(
      id: id,
      assignment: 'member',
      assigneeId: 2,
      assigneeName: 'Marta',
      minutes: 60,
    );

    Finder inChip(Finder finder) =>
        find.descendant(of: find.byType(ReminderChip), matching: finder);

    /// The colour the chip's [words] are drawn in.
    Color wordsColor(WidgetTester tester, String words) => tester
        .widget<RichText>(
          find.descendant(of: chipText(words), matching: find.byType(RichText)),
        )
        .text
        .style!
        .color!;

    /// Every outline the chip paints: its Material's shape and its Ink's.
    List<BorderSide> outlines(WidgetTester tester) => [
      for (final material in tester.widgetList<Material>(
        inChip(find.byType(Material)),
      ))
        if (material.shape case final OutlinedBorder shape) shape.side,
      for (final ink in tester.widgetList<Ink>(inChip(find.byType(Ink))))
        if (ink.decoration case ShapeDecoration(
          shape: final OutlinedBorder shape,
        ))
          shape.side,
    ];

    /// Every fill the chip paints: its Material's colour (the canvas's when
    /// it sets none) and its Ink's.
    List<Color> fills(WidgetTester tester) => [
      for (final element in inChip(find.byType(Material)).evaluate())
        if ((element.widget as Material).type != MaterialType.transparency)
          (element.widget as Material).color ?? Theme.of(element).canvasColor,
      for (final ink in tester.widgetList<Ink>(inChip(find.byType(Ink))))
        if (ink.decoration case ShapeDecoration(color: final color?)) color,
    ];

    /// A chip with no tap: a plain [Chip] with no outline and no fill, its
    /// [words] at full contrast in the theme's onSurface, beside the bell;
    /// TalkBack reads it as text, with no button and no enabled state.
    void expectInformation(WidgetTester tester, String words) {
      expect(inChip(find.byType(ActionChip)), findsNothing);
      expect(inChip(find.byType(Chip)), findsOneWidget);
      final chip = tester.widget<Chip>(inChip(find.byType(Chip)));
      expect(chip.side, BorderSide.none);
      expect(chip.backgroundColor, Colors.transparent);
      final sides = outlines(tester);
      expect(sides, isNotEmpty);
      for (final side in sides) {
        expect(
          side.style == BorderStyle.none || side.width == 0,
          isTrue,
          reason: 'no outline is painted around «$words»: $side',
        );
      }
      final painted = fills(tester);
      expect(painted, isNotEmpty);
      for (final fill in painted) {
        expect(fill.a, 0, reason: 'nothing is filled behind «$words»: $fill');
      }
      final color = wordsColor(tester, words);
      final scheme = Theme.of(
        tester.element(find.byType(ReminderChip)),
      ).colorScheme;
      expect(color, scheme.onSurface);
      expect(color.a, closeTo(1, 0.001));
      final bells = tester
          .widgetList<Icon>(inChip(find.byType(Icon)))
          .map((icon) => icon.icon)
          .toList();
      expect(bells, hasLength(1));
      expect(
        bells.single,
        anyOf(Icons.notifications_outlined, Icons.notifications_off_outlined),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(words)),
        isSemantics(
          label: words,
          isButton: false,
          hasTapAction: false,
          hasEnabledState: false,
        ),
      );
    }

    /// The capture's result for [tasks], one draft each (`d1`, `d2`, …).
    Future<_App> capture(
      WidgetTester tester,
      List<Task> tasks,
      MemoryCaptures captures,
    ) async {
      final app = await _App.open(
        tester,
        const [],
        captures: captures,
        size: phone,
        projects: projects,
      );
      captures.tasks = app.container;
      captures.current = CaptureSession(
        id: 'p264',
        ownerKey: app.container.read(captureOwnerProvider),
        timezone: 'Europe/Madrid',
        capturedAt: now.toUtc(),
        status: 'ready',
        source: 'speech',
        transcript: 'Presentar el proyecto…',
        drafts: [
          for (final (i, task) in tasks.indexed)
            CaptureDraft(id: 'd${i + 1}', task: task),
        ],
      );
      await openCaptureResult(tester, 'p264');
      expect(find.byType(VoiceTaskScreen), findsOneWidget);
      return app;
    }

    Finder cardLine(String id) =>
        find.byKey(ValueKey('draft-reminder-line-$id'));

    /// The three drafts: bread for today; Marta's at 17:00 on Fri 13 Nov
    /// with «1 hora antes»; the children today at 17:00 with «1 hora antes»,
    /// this account's own.
    List<Task> three() => [
      Task(
        title: 'Comprar pan y leche',
        priority: 1,
        dueDate: DateTime(2026, 10, 22),
        hasTime: false,
      ),
      forMarta(id: null),
      Task(
        title: 'Recoger a los niños del colegio',
        priority: 1,
        dueDate: DateTime(2026, 10, 22, 17),
        hasTime: true,
        reminderMinutes: 60,
      ),
    ];

    testWidgets(
      'UX-2025: on a result of three, Marta’s collapsed «Recordatorio para '
      'Marta» is plain text for TalkBack: no button, no tap and no enabled '
      'state, so never «desactivado»',
      (tester) async {
        final handle = tester.ensureSemantics();
        await capture(tester, three(), MemoryCaptures());
        final words = es.reminderForPersonOnly('Marta');
        expect(cardLine('d2'), findsOneWidget);
        expect(
          find.descendant(of: cardLine('d2'), matching: find.text(words)),
          findsOneWidget,
        );
        expect(
          tester.getSemantics(cardLine('d2')),
          isSemantics(
            label: words,
            isButton: false,
            hasTapAction: false,
            hasEnabledState: false,
          ),
        );
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    testWidgets(
      'UX-2025: in the same result, the personal draft’s collapsed reminder '
      'line is an enabled button with a tap; while the result saves it stays '
      'a button, disabled and with no tap, like the date line (UX-462), and '
      'Marta’s line still has no enabled state',
      (tester) async {
        final handle = tester.ensureSemantics();
        final captures = _P264HeldCaptures();
        await capture(tester, three(), captures);
        final own = es.reminderValue(es.hourBefore);
        final marta = es.reminderForPersonOnly('Marta');
        expect(cardLine('d3'), findsOneWidget);
        expect(
          find.descendant(of: cardLine('d3'), matching: find.text(own)),
          findsOneWidget,
        );
        expect(
          tester.getSemantics(cardLine('d3')),
          isSemantics(
            label: own,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );

        captures.hold = Completer<void>();
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(captures.saving, isTrue, reason: 'the result is saving');
        expect(cardLine('d3'), findsOneWidget);
        expect(
          tester.getSemantics(cardLine('d3')),
          isSemantics(
            label: own,
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: false,
          ),
        );
        expect(
          tester.getSemantics(cardLine('d2')),
          isSemantics(
            label: marta,
            isButton: false,
            hasTapAction: false,
            hasEnabledState: false,
          ),
        );

        captures.hold!.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    testWidgets(
      'UX-2034: on the task’s page, Marta’s «Recordatorio para Marta» is a '
      'plain Chip with no outline and no fill, at full contrast beside the '
      'bell, read as text; a tap opens nothing and changes nothing',
      (tester) async {
        final handle = tester.ensureSemantics();
        final app = await _App.open(
          tester,
          [forMarta()],
          size: phone,
          projects: projects,
        );
        await app.detail(1);
        final words = es.reminderForPersonOnly('Marta');
        expect(chipText(words), findsOneWidget);
        expectInformation(tester, words);
        await tester.tap(find.byType(ReminderChip), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(sheet(), findsNothing);
        expect(find.byType(Dialog), findsNothing);
        final after = app.task(1);
        expect(after.reminderMinutes, 60);
        expect(after.reminderTime, isNull);
        expect(after.reminderPlan, isNull);
        expect(after.reminderAnchor, 'planned');
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    testWidgets(
      'UX-2034: at CA 2× on 360×800, «Recordatori per a Marta» is whole and '
      'unclipped beside its bell, with no outline, and nothing overflows',
      (tester) async {
        final handle = tester.ensureSemantics();
        final app = await _App.open(
          tester,
          [forMarta()],
          size: phone,
          projects: projects,
          language: 'ca',
          textScale: 2,
        );
        await app.detail(1);
        final words = ca.reminderForPersonOnly('Marta');
        await tester.ensureVisible(find.byType(ReminderChip));
        await tester.pumpAndSettle();
        expect(chipText(words), findsOneWidget);
        expectInformation(tester, words);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: chipText(words), matching: find.byType(RichText)),
        );
        expect(paragraph.text.toPlainText(), words);
        expect(paragraph.didExceedMaxLines, isFalse);
        // Whole: every character is laid out inside the paragraph's box.
        for (final box in paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: words.length),
        )) {
          expect(box.left, greaterThanOrEqualTo(-0.5));
          expect(box.right, lessThanOrEqualTo(paragraph.size.width + 0.5));
          expect(box.bottom, lessThanOrEqualTo(paragraph.size.height + 0.5));
        }
        final text = tester.getRect(chipText(words));
        final chip = tester.getRect(find.byType(ReminderChip));
        final bell = tester.getRect(inChip(find.byType(Icon)));
        expect(text.left, greaterThanOrEqualTo(chip.left - 0.5));
        expect(text.right, lessThanOrEqualTo(chip.right + 0.5));
        expect(text.top, greaterThanOrEqualTo(chip.top - 0.5));
        expect(text.bottom, lessThanOrEqualTo(chip.bottom + 0.5));
        expect(chip.left, greaterThanOrEqualTo(0));
        expect(chip.right, lessThanOrEqualTo(phone.width));
        expect(text.bottom, lessThanOrEqualTo(phone.height));
        // Beside: the bell sits before the words, level with them.
        expect(bell.right, lessThanOrEqualTo(text.left + 0.5));
        expect(bell.center.dy, greaterThanOrEqualTo(text.top));
        expect(bell.center.dy, lessThanOrEqualTo(text.bottom));
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    testWidgets(
      'UX-2034: an archived project’s «Sin recordatorio: proyecto archivado» '
      'has no outline, no fill and no tap, at full contrast, read as text',
      (tester) async {
        final handle = tester.ensureSemantics();
        final app = await _App.open(
          tester,
          [task(listId: 'old', assignment: 'personal')],
          size: phone,
          projects: projects,
        );
        await app.detail(1);
        final words = es.noReminderProjectArchived;
        expect(chipText(words), findsOneWidget);
        expectInformation(tester, words);
        await tester.tap(find.byType(ReminderChip), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(sheet(), findsNothing);
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    testWidgets(
      'UX-2034: unchanged: a «Todos» task in «Equipo» keeps an ActionChip '
      'with the theme’s outline, and it opens the reminder sheet',
      (tester) async {
        final app = await _App.open(
          tester,
          [task()],
          size: phone,
          projects: projects,
        );
        await app.detail(1);
        expect(inChip(find.byType(ActionChip)), findsOneWidget);
        expect(inChip(find.byType(Chip)), findsNothing);
        final scheme = Theme.of(
          tester.element(find.byType(ReminderChip)),
        ).colorScheme;
        final sides = outlines(tester);
        expect(
          sides.any(
            (side) =>
                side.style == BorderStyle.solid &&
                side.width > 0 &&
                side.color == scheme.outline,
          ),
          isTrue,
          reason: 'the tappable chip keeps its outline: $sides',
        );
        await openSheet(tester);
        expect(
          inSheet(find.byKey(const ValueKey('reminder-plan-until-day'))),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2034: unchanged: a project muted here keeps an ActionChip «Sin '
      'recordatorio: proyecto silenciado» with its outline, and it opens '
      '«Novedades del proyecto»',
      (tester) async {
        final app = await _App.open(
          tester,
          [task(listId: 'quiet', assignment: 'personal')],
          size: phone,
          projects: projects,
        );
        await app.detail(1);
        expect(chipText(es.noReminderProjectMuted), findsOneWidget);
        expect(inChip(find.byType(ActionChip)), findsOneWidget);
        final scheme = Theme.of(
          tester.element(find.byType(ReminderChip)),
        ).colorScheme;
        final sides = outlines(tester);
        expect(
          sides.any(
            (side) =>
                side.style == BorderStyle.solid &&
                side.width > 0 &&
                side.color == scheme.outline,
          ),
          isTrue,
          reason: 'the tappable chip keeps its outline: $sides',
        );
        await tapVisible(tester, find.byType(ReminderChip));
        expect(sheet(), findsOneWidget);
        expect(inSheet(find.text(es.projectNotifications)), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // UX-2035: on a shared task the title and «solo para ti» stay put while
  // the choices scroll under them; a thin line marks that edge, so a sheet
  // opened part-way down its list looks part-way down.
  group('P265 · UX-2035', () {
    const phone = Size(360, 800);
    final team = TaskListInfo(
      id: 'team',
      name: 'Equipo',
      shared: true,
      ownerId: 1,
      people: const [
        ProjectMember(id: 1, name: 'Yo', role: 'owner'),
        ProjectMember(id: 2, name: 'Marta', role: 'editor'),
      ],
    );

    /// A «Todos» task in «Equipo», 22 days away, with [plan].
    Task forAll({ReminderPlan? plan}) => Task(
      id: 1,
      title: 'Presentar el proyecto',
      priority: 1,
      dueDate: friday13,
      hasTime: false,
      reminderPlan: plan,
      listId: 'team',
      assignment: 'group',
    );

    final edge = find.byKey(const ValueKey('reminder-sheet-header-edge'));
    final justYou = find.byKey(const ValueKey('reminder-plan-just-you'));
    final untilDay = find.byKey(const ValueKey('reminder-plan-until-day'));

    Rect rectOf(Element element) {
      final box = element.renderObject! as RenderBox;
      return box.localToGlobal(Offset.zero) & box.size;
    }

    Finder choices() => find
        .descendant(
          of: sheet().last,
          matching: find.byType(SingleChildScrollView),
        )
        .first;

    /// One 1 dp line keyed `reminder-sheet-header-edge`, in the sheet, on
    /// screen, under the note and no more than 8 dp below it.
    Rect expectEdgeUnderNote(WidgetTester tester, AppLocalizations l) {
      expect(edge, findsOneWidget);
      expect(inSheet(edge), findsOneWidget);
      expect(tester.widget(edge), isA<Divider>());
      expect(tester.widget<Divider>(edge).height, 1);
      final line = tester.getRect(edge);
      expect(line.height, moreOrLessEquals(1, epsilon: 0.01));
      expect(line.top, greaterThanOrEqualTo(0));
      expect(line.bottom, lessThanOrEqualTo(phone.height));
      expect(justYou, findsOneWidget);
      expect(tester.widget<Text>(justYou).data, l.reminderPlanJustYou);
      final note = tester.getRect(justYou);
      expect(line.top, greaterThanOrEqualTo(note.bottom - 0.5));
      expect(
        line.top - note.bottom,
        lessThanOrEqualTo(8),
        reason: 'The line sits right under «${l.reminderPlanJustYou}».',
      );
      return line;
    }

    for (final (language, l) in [('es', es), ('ca', ca)]) {
      testWidgets(
        'UX-2035: at 2× on 360×800 in $language, a «Todos» task in «Equipo» '
        'with Normal opens scrolled to «${l.reminderPlanUntilDay}», and a '
        'line under «${l.reminderPlanJustYou}» sits above every row in view',
        (tester) async {
          await (await _App.open(
            tester,
            [forAll(plan: const ReminderPlan.rhythm(ReminderPlan.normal))],
            language: language,
            textScale: 2,
            size: phone,
            projects: [team],
          )).detail(1);
          await openSheet(tester);
          await tester.pumpAndSettle();
          final line = expectEdgeUnderNote(tester, l);

          // Opened scrolled to the plan: the single rows are above it.
          expect(untilDay.hitTestable(), findsOneWidget);
          expect(
            inSheet(find.text(l.off)).hitTestable(),
            findsNothing,
            reason: 'The sheet opened scrolled past «${l.off}».',
          );
          final rows = inSheet(find.byType(ListTile)).hitTestable();
          expect(rows, findsWidgets);
          final hit = rows.evaluate().toList();
          expect(
            hit.map((e) => e.widget.key),
            contains(const ValueKey('reminder-plan-until-day')),
          );
          for (final row in hit) {
            expect(
              rectOf(row).top,
              greaterThanOrEqualTo(line.bottom - 0.5),
              reason: '${row.widget} must start under the line.',
            );
          }
          expect(
            tester.getRect(untilDay).top,
            greaterThanOrEqualTo(line.bottom - 0.5),
          );
          expect(
            tester.getRect(choices()).top,
            greaterThanOrEqualTo(line.bottom - 0.5),
            reason: 'The choices scroll under the line, not over it.',
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'UX-2035: at 2× on 360×800 in $language, scrolling the choices 200 dp '
        'down and up leaves the line, the title and the note in place',
        (tester) async {
          await (await _App.open(
            tester,
            [forAll(plan: const ReminderPlan.rhythm(ReminderPlan.normal))],
            language: language,
            textScale: 2,
            size: phone,
            projects: [team],
          )).detail(1);
          await openSheet(tester);
          await tester.pumpAndSettle();
          expectEdgeUnderNote(tester, l);
          final title = inSheet(find.text(l.reminder));
          final titleBefore = tester.getRect(title);
          final noteBefore = tester.getRect(justYou);
          final lineBefore = tester.getRect(edge);

          for (final dy in [200.0, -200.0, -200.0]) {
            final rowBefore = tester.getRect(untilDay);
            await tester.drag(choices(), Offset(0, dy));
            await tester.pumpAndSettle();
            expect(
              tester.getRect(untilDay).top,
              isNot(moreOrLessEquals(rowBefore.top, epsilon: 1)),
              reason: 'The choices scrolled by $dy.',
            );
            expect(tester.getRect(title), titleBefore);
            expect(tester.getRect(justYou), noteBefore);
            expect(tester.getRect(edge), lineBefore);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2035: a «Todos» task in «Equipo» without a plan opens at its top, '
      'and at 1× on 360×800 reads «Recordatorio», «Estos avisos son solo '
      'para ti.», the line, then «Desactivado»',
      (tester) async {
        await (await _App.open(
          tester,
          [forAll()],
          size: phone,
          projects: [team],
        )).detail(1);
        await openSheet(tester);
        final title = tester.getRect(inSheet(find.text(es.reminder)));
        final note = tester.getRect(justYou);
        final line = expectEdgeUnderNote(tester, es);
        final off = tester.getRect(inSheet(find.text(es.off)));
        expect(note.top, greaterThanOrEqualTo(title.bottom - 0.5));
        expect(line.top, greaterThanOrEqualTo(note.bottom - 0.5));
        expect(off.top, greaterThanOrEqualTo(line.bottom - 0.5));
        expect(inSheet(find.text(es.off)).hitTestable(), findsOneWidget);
        // Opened at its top: the first row starts right under the line.
        final firstRow = tester.getRect(inSheet(find.byType(ListTile)).first);
        expect(firstRow.top, greaterThanOrEqualTo(line.bottom - 0.5));
        expect(firstRow.top - line.bottom, lessThanOrEqualTo(1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2035: a personal task due today, as in UX-1904, has no such line '
      'and no Divider at all',
      (tester) async {
        await (await _App.open(tester, [
          presentation(day: DateTime(2026, 10, 22)),
        ])).detail(1);
        await openSheet(tester);
        expect(inSheet(find.text(es.reminder)), findsOneWidget);
        expect(edge, findsNothing);
        expect(inSheet(find.byType(Divider)), findsNothing);
        expect(justYou, findsNothing);
      },
    );
  });

  group('P270 · the reminder line names itself once', () {
    const small = Size(360, 800);
    const normal = ReminderPlan.rhythm(ReminderPlan.normal);

    /// «Presentar el proyecto» on Fri 13 Nov 2026 at 17:00 with Normal: its
    /// day's notice rings at 16:50.
    Task timed(int id) => Task(
      id: id,
      title: 'Presentar el proyecto',
      priority: 1,
      dueDate: DateTime(2026, 11, 13, 17),
      hasTime: true,
      reminderPlan: normal,
    );

    // What the real engine keeps once that last notice has rung.
    late int timedId;
    late List<Map<String, Object?>> lastRang;
    setUpAll(() async {
      final phone = await PhoneAlerts.open(DateTime(2026, 11, 13, 16));
      timedId = await phone.add(timed(0));
      phone.now = DateTime(2026, 11, 13, 17);
      await phone.refresh();
      lastRang = await phone.of(timedId);
      await phone.close();
    });

    /// The capture's result for one draft [task], on a 360×800 phone.
    Future<void> card(
      WidgetTester tester,
      Task task, {
      String language = 'es',
      double textScale = 1,
    }) async {
      final captures = MemoryCaptures();
      final app = await _App.open(
        tester,
        const [],
        captures: captures,
        language: language,
        textScale: textScale,
        size: small,
      );
      captures.tasks = app.container;
      captures.current = CaptureSession(
        id: 'p270',
        ownerKey: app.container.read(captureOwnerProvider),
        timezone: 'Europe/Madrid',
        capturedAt: now.toUtc(),
        status: 'ready',
        source: 'speech',
        transcript: 'Presentar el proyecto…',
        drafts: [CaptureDraft(id: 'd1', task: task)],
      );
      await openCaptureResult(tester, 'p270');
      expect(find.byType(VoiceTaskScreen), findsOneWidget);
    }

    /// The edit form of [task] (id 1), «Más detalles» open.
    Future<void> form(WidgetTester tester, Task task) async {
      final app = await _App.open(tester, [task], size: small);
      app.navigator.pushNamed('/editTask', arguments: 1);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('task-more-details')));
    }

    /// The reminder row's tile, in [within] (the card's row or the form).
    Finder tile(Finder within) => find.descendant(
      of: find.descendant(
        of: within,
        matching: find.byType(ReminderControl),
        matchRoot: true,
      ),
      matching: find.byType(ListTile),
    );

    /// Every word the row draws.
    String drawn(WidgetTester tester, Finder row) => tester
        .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
        .map((text) => text.data ?? '')
        .join('\n');

    int count(String text, String word) => word.allMatches(text).length;

    /// The plan's line alone in [row]: no «Recordatorio» over it, its words
    /// once, and TalkBack's reading names the reminder once.
    void namedOnce(WidgetTester tester, Finder row, AppLocalizations l) {
      expect(row, findsOneWidget);
      final listTile = tester.widget<ListTile>(row);
      final line = (listTile.title! as Text).data!;
      expect(line, isNot(l.reminder));
      expect(line, contains(' · '));
      expect(listTile.subtitle, isNull);
      expect(
        find.descendant(of: row, matching: find.text(l.reminder)),
        findsNothing,
      );
      expect(
        find.descendant(of: row, matching: find.text(line)),
        findsOneWidget,
      );
      // «Recordatorios: …» holds the word once, and nothing repeats it.
      expect(count(drawn(tester, row), l.reminder), 1);
      final reading = tester.getSemantics(row).label;
      expect(reading, contains(line));
      expect(count(reading, l.reminder), 1);
      expect(count(reading, line), 1);
    }

    for (final (language, l, scale) in [
      ('es', es, 1.0),
      ('es', es, 2.0),
      ('ca', ca, 2.0),
    ]) {
      testWidgets(
        'UX-2206: on the capture’s card, a said plan’s «Recordatorios: cada 3 días…» shows once, with no «Recordatorio» over it ($language ${scale.toInt()}×)',
        (tester) async {
          final semantics = tester.ensureSemantics();
          await card(
            tester,
            Task(
              title: 'Presentar el proyecto',
              priority: 1,
              dueDate: friday13,
              hasTime: false,
              reminderPlan: ownersPlan,
            ),
            language: language,
            textScale: scale,
          );
          final row = tile(find.byKey(const ValueKey('draft-reminder-d1')));
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();
          namedOnce(tester, row, l);
          expect(tester.takeException(), isNull);
          semantics.dispose();
        },
      );
    }

    testWidgets(
      'UX-2206: in the form, a plan’s «Recordatorios: cada 3 días…» row shows once, with no «Recordatorio» over it',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await form(tester, presentation(plan: ownersPlan));
        final row = tile(find.byType(EditTaskScreen));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        namedOnce(tester, row, es);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    testWidgets(
      'UX-2206: in the form, a single reminder’s row still shows «Recordatorio» over «10 minutos antes»',
      (tester) async {
        await form(
          tester,
          Task(
            id: 1,
            title: 'Dentista',
            priority: 1,
            dueDate: DateTime(2026, 10, 27, 10),
            hasTime: true,
            reminderMinutes: 10,
          ),
        );
        final row = tile(find.byType(EditTaskScreen));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        final listTile = tester.widget<ListTile>(row);
        expect((listTile.title! as Text).data, es.reminder);
        expect(
          (listTile.subtitle! as Text).data,
          tester.element(row).reminderLead(10),
        );
        expect(tester.takeException(), isNull);
      },
    );

    test('the engine kept the plan’s last notice, at 16:50', () {
      expect(
        lastRang.map((row) => DateTime.parse(row['fire_at']! as String)),
        contains(DateTime(2026, 11, 13, 16, 50).toUtc()),
      );
    });

    for (final (language, l) in [('es', es), ('en', en), ('ca', ca)]) {
      testWidgets(
        'UX-2401: a plan whose last notice rang at 16:50 today ends «· último: hoy, 16:50», not the passed line ($language)',
        (tester) async {
          final app = await _App.open(
            tester,
            [timed(timedId)],
            language: language,
            size: small,
            at: DateTime(2026, 11, 13, 17),
            access: FakeReminderAccess(allowed: true)..kept = [...lastRang],
          );
          await app.detail(timedId);
          final chip = find.byType(ReminderChip);
          await tester.ensureVisible(chip);
          await tester.pumpAndSettle();
          final line = tester
              .widgetList<Text>(
                find.descendant(of: chip, matching: find.byType(Text)),
              )
              .map((text) => text.data ?? '')
              .join();
          final time = tester
              .element(chip)
              .clockTime(DateTime(2026, 11, 13, 16, 50));
          expect(time, '16:50');
          final last = l.reminderPlanLast('', 'today', '', time);
          expect(line, endsWith(last));
          expect(line.length, greaterThan(last.length));
          expect(line, isNot(contains(l.noReminderTimePassed)));
          expect(
            find.descendant(
              of: chip,
              matching: find.byIcon(Icons.notifications_off_outlined),
            ),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    test('UX-2401: the plan’s last line in EN, ES and CA', () {
      expect(
        en.reminderPlanLast('', 'today', '', '16:50'),
        ' · last: today, 16:50',
      );
      expect(
        es.reminderPlanLast('', 'today', '', '16:50'),
        ' · último: hoy, 16:50',
      );
      expect(
        ca.reminderPlanLast('', 'today', '', '16:50'),
        ' · últim: avui, 16:50',
      );
    });
  });
}

/// UX-2020: in the [text] widget's laid-out paragraph, the time phrase
/// «[preposition] [article] 8» (spaces of either kind) and the text's last
/// character all sit on one line, and that line is the paragraph's last, so
/// no line ends with the lone «[preposition]». Returns how many lines the
/// paragraph has.
int _p257TimePhraseOnLastLine(
  WidgetTester tester,
  Finder text,
  String preposition,
  String article,
) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)).first,
  );
  final plain = paragraph.text.toPlainText();
  final match = RegExp(
    '(?<![\\p{L}])${RegExp.escape(preposition)}[  ]'
    '${RegExp.escape(article)}[  ]8',
    unicode: true,
  ).firstMatch(plain);
  expect(match, isNotNull, reason: '«$preposition $article 8» in «$plain»');
  double top(int index) => paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: index, extentOffset: index + 1),
      )
      .first
      .top;
  final allTops = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: plain.length),
      )
      .map((box) => box.top)
      .toList();
  final lastLine = allTops.reduce((a, b) => a > b ? a : b);
  final start = match!.start;
  final articleStart = start + preposition.length + 1;
  for (final (what, index) in [
    ('«$preposition»', start),
    ('«$article»', articleStart),
    ('the end of «$article»', articleStart + article.length - 1),
    ('«8»', match.end - 1),
    ('the last character', plain.length - 1),
  ]) {
    expect(
      top(index),
      moreOrLessEquals(lastLine, epsilon: 0.5),
      reason: '$what must sit on the last line of «$plain»',
    );
  }
  return allTops.map((t) => t.round()).toSet().length;
}

/// The app on a phone with reminders allowed, on a fixed day, with the
/// assistant's reminder-plan answer and the phone's recognizer stood in for.
class _App {
  _App(
    this.tester,
    this.container,
    this.reminders,
    this.api,
    this.speech,
    this.access,
  );
  final WidgetTester tester;
  final ProviderContainer container;
  final MemoryReminderStore reminders;

  /// The phone's notification permission.
  final FakeReminderAccess access;
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
    DateTime? at,
    ClockFormat clock = ClockFormat.twentyFour,
    FakeReminderAccess? access,
    // The projects this phone knows, and a task list of the test's own
    // (e.g. one whose sync never completes) instead of [tasks] in memory.
    List<TaskListInfo> projects = const [],
    TaskNotifier Function()? notifier,
  }) async {
    final phone = access ?? FakeReminderAccess(allowed: true);
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
          clock: clock,
          captureTimezone: 'Europe/Madrid',
        ),
      ),
      tasks: notifier ?? () => _Tasks(tasks),
      projects: projects,
      pro: pro,
      api: api,
      hadTask: true,
      overrides: [
        ...reminderOverrides(store, phone),
        calendarClockProvider.overrideWithValue(() => at ?? now),
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
    return _App(tester, container, store, api, speech, phone);
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

/// UX-2019: in the [text] widget's laid-out paragraph, the hour said after
/// [preposition] («las», «les», “at”) sits on the same line as the whole
/// preposition and as the text's last character, so the hour never wraps
/// alone onto a line of its own. Returns how many lines the paragraph has.
int _expectHourKeptWithPreposition(
  WidgetTester tester,
  Finder text,
  String preposition, {
  String hour = '8',
}) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)).first,
  );
  final plain = paragraph.text.toPlainText();
  final match = RegExp(
    r'\b'
    '${RegExp.escape(preposition)}[ \u00A0]${RegExp.escape(hour)}',
  ).firstMatch(plain);
  expect(match, isNotNull, reason: '«$preposition $hour» in «$plain»');
  double lineTop(int index) => paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: index, extentOffset: index + 1),
      )
      .first
      .top;
  final hourLine = lineTop(match!.end - 1);
  for (final (what, index) in [
    ('the start of «$preposition»', match.start),
    ('the end of «$preposition»', match.start + preposition.length - 1),
    ('the last character', plain.length - 1),
  ]) {
    expect(
      lineTop(index),
      moreOrLessEquals(hourLine, epsilon: 0.5),
      reason: '«$hour» must sit on the same line as $what in «$plain»',
    );
  }
  final lines = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: plain.length),
      )
      .map((box) => box.top.round())
      .toSet()
      .length;
  return lines;
}

/// P264: a capture store whose `Añadir…` stays saving while [hold] is set,
/// until the test completes it; then it saves as [MemoryCaptures] does.
class _P264HeldCaptures extends MemoryCaptures {
  Completer<void>? hold;
  bool saving = false;
  @override
  Future<CaptureSession> saveReady(
    String id,
    String ownerKey,
    Set<String> draftIds,
  ) async {
    saving = true;
    if (hold case final gate?) await gate.future;
    saving = false;
    return super.saveReady(id, ownerKey, draftIds);
  }
}
