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
        expect(inRow(find.text(es.reminder)), findsOneWidget);
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
        expect(find.text(es.reminder), findsOneWidget);
        expect(find.byType(ReminderControl), findsOneWidget);
        expect(find.text(ownersLine), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1805: changing the plan to a time, then to «Desactivado», keeps the row above «Más opciones»',
      (tester) async {
        final (_, captures) = await card(tester, [said(plan: ownersPlan)]);
        await tapVisible(tester, inRow(find.text(es.reminder)));
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
        await tapVisible(tester, inRow(find.text(es.reminder)));
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
      'UX-1811: «Sin fecha» turns the row into «Añade una fecha…», and the task saves with no plan',
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
        expect(row(), findsOneWidget);
        expect(inRow(find.text(es.dateForReminder)), findsOneWidget);
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
          final title = inRow(find.text(l.reminder));
          expect(title, findsOneWidget);
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
        await tapVisible(tester, inRow(find.text(es.reminder)));
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
      'UX-2019: in es, en and ca the helper and the Pro example join the hour to its preposition with a no-break space',
      () {
        for (final (language, l, open, close, preposition) in [
          ('es', es, '«', '»', 'las'),
          ('en', en, '“', '”', 'at'),
          ('ca', ca, '«', '»', 'les'),
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
              1,
              reason: '$language $key: only that one space changed',
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
          final lines = _expectHourKeptWithPreposition(tester, example, 'las');
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
        final lines = _expectHourKeptWithPreposition(tester, example, 'les');
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

    group('UX-2003: only for a task that rings on this phone alone', () {
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

      testWidgets('a «Todos» task in a shared project: no offer', (
        tester,
      ) async {
        expect(await offered(tester, 'team', assignment: 'group'), isFalse);
      });

      testWidgets('an unassigned task in a shared project: no offer', (
        tester,
      ) async {
        expect(
          await offered(tester, 'team', assignment: 'unassigned'),
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
      'UX-1806, UX-1807: after another member’s name, the plan reads lowercase with its next reminder',
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
        expect(
          chipLine(tester),
          'Recordatorio para Ana: cada 3 días, y a diario la última semana · próximo: sáb 24, 09:00',
        );
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
        expect(
          find.descendant(
            of: find.byType(ReminderControl),
            matching: find.text(es.reminder),
          ),
          findsOneWidget,
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
        'Por ejemplo: «una semana antes y el día antes a las\u00A08».',
      ),
      ('en', en, 'For example: “a week before, and the day before at\u00A08”.'),
      (
        'ca',
        ca,
        'Per exemple: «una setmana abans i el dia abans a les\u00A08».',
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
          final lines = _expectHourKeptWithPreposition(tester, helper, 'las');
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
