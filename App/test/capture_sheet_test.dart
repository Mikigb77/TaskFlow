// UX loop 2026-10-13-app, round 1: the capture sheet.
// P38 (U8, UX-204, UX-112): one `Añadir tarea` button, typing in the sheet
// without Pro, understood on the phone, and the selected day.
// P39 (UX-102, UX-106, UX-114): every way in works, with or without Pro, and
// keeps nothing until something is said or typed.
// P40 (U7, UX-103, UX-451): `Guardar como tarea` when the assistant is slow or
// fails, and errors in plain words, read out by TalkBack.
// Round 2: P67 (UX-103, UX-467–UX-470) messages that name what's on screen,
// slow spoken, the typing hint, the failed pair stacked; P68 (UX-465) the
// phone's time question; P69 (UX-466) saving from the day timeline.
// 2026-10-18 later: without Pro, tasks are typed only in the form; the
// sheet types, read on the phone, only while billing hasn't answered.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agenda/l10n/capture_messages.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/day_timeline_screen.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_entries.dart';
import 'package:agenda/services/capture_problem.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/widgets/task_actions.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable, RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'support/capture_fixtures.dart' show SilentRecorder;
import 'support/design_fixtures.dart';

final en = lookupAppLocalizations(const Locale('en'));
final es = lookupAppLocalizations(const Locale('es'));
final ca = lookupAppLocalizations(const Locale('ca'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  const timezone = MethodChannel('flutter_timezone');
  setUp(() {
    platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
    platform.setMockMethodCallHandler(timezone, (_) async => 'Europe/Madrid');
  });
  tearDown(() {
    platform.setMockMethodCallHandler(timeoutChannel, null);
    platform.setMockMethodCallHandler(timezone, null);
  });

  /// A Monday at 09:00, a week or more ahead, so the week's Thursday and
  /// Friday are never Hoy or Mañana on the phone's own clock.
  DateTime monday() {
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day + 7);
    while (day.weekday != DateTime.monday) {
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return DateTime(day.year, day.month, day.day, 9);
  }

  DateTime plus(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(BottomSheet), matching: finder);
  Finder words() => find.byKey(const ValueKey('capture-words'));
  String titleText(WidgetTester tester) => tester
      .widget<TextFormField>(find.byKey(const ValueKey('task-title')))
      .controller!
      .text;

  /// The result's main date line.
  String dateLine(WidgetTester tester) {
    final line = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('draft-schedule-'),
    );
    final tile = tester.widget<ListTile>(line.first);
    return (tile.title! as Text).data!;
  }

  Future<void> tapDay(WidgetTester tester, DateTime day) async {
    await tester.tap(
      find
          .descendant(
            of: find.byType(CalendarScreen),
            matching: find.text('${day.day}'),
          )
          .hitTestable()
          .first,
    );
    await tester.pumpAndSettle();
  }

  /// Frames while something spins (it never settles).
  Future<void> frames(WidgetTester tester, [int count = 6]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  // ---- P38 · U8: one creation button ----

  for (final pro in [true, false]) {
    // Without Pro (and here no free dictations), the one button reads
    // Nueva tarea and opens the form (2026-10-18 later).
    final label = pro ? es.addTask : es.newTask;
    testWidgets(
      'U8: ${pro ? 'with' : 'without'} Pro, Calendar, Tareas, a project page and the day timeline each show one $label (${pro ? 'mic' : 'add'} icon) and no Escribir una tarea or +',
      (tester) async {
        final app = await _App.open(
          tester,
          pro: pro,
          projects: [TaskListInfo(id: 'casa', name: 'Casa')],
        );
        void expectOneButton(String where) {
          expect(find.text(label).hitTestable(), findsOneWidget, reason: where);
          expect(
            find.descendant(
              of: find.byType(TaskActions).hitTestable(),
              matching: find.byIcon(
                pro ? Icons.mic_none_rounded : Icons.add_rounded,
              ),
            ),
            findsOneWidget,
            reason: where,
          );
          for (final old in [
            pro ? es.newTask : es.addTask,
            'Escribir una tarea',
            'Escribir tarea',
          ]) {
            expect(find.text(old), findsNothing, reason: '$where: $old');
          }
          expect(find.byType(FloatingActionButton), findsNothing);
          expect(
            find.widgetWithIcon(IconButton, Icons.add).hitTestable(),
            findsNothing,
            reason: where,
          );
          expect(
            find.widgetWithIcon(IconButton, Icons.add_rounded).hitTestable(),
            findsNothing,
            reason: where,
          );
        }

        expectOneButton('Calendario');

        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(es.tasks),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expectOneButton('Tareas');

        unawaited(
          Navigator.of(tester.element(find.byType(HomeScreen))).push(
            MaterialPageRoute<void>(
              builder: (_) => const HomeScreen(isRoot: false, listId: 'casa'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expectOneButton('Casa');
        // It adds to the project the page shows.
        await tester.tap(find.text(label).hitTestable());
        await tester.pumpAndSettle();
        if (pro) {
          expect(
            tester
                .widget<VoiceTaskScreen>(find.byType(VoiceTaskScreen))
                .projectId,
            'casa',
          );
          await tester.tap(inSheet(find.widgetWithText(TextButton, es.cancel)));
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
        } else {
          expect(
            tester.widget<TaskEditor>(find.byType(TaskEditor)).task.listId,
            'casa',
          );
          // An empty form: Back just closes it.
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(TaskEditor), findsNothing);
        }

        unawaited(
          Navigator.of(
            tester.element(find.byType(HomeScreen).last),
          ).pushNamed('/timeline', arguments: DateTime.now()),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DayTimelineScreen), findsOneWidget);
        expectOneButton('Día');
        expect(app.store.sessions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'U8: the empty Calendar reads Nada previsto para este día. and its empty state has no button',
    (tester) async {
      final app = await _App.open(tester, pro: false);
      // The account has something, so an empty day isn't the first run.
      app.tasks.add(
        Task(
          title: 'Comprar pan',
          priority: 1,
          dueDate: DateTime.now().add(const Duration(days: 30)),
        ),
      );
      await tester.pumpAndSettle();
      expect(es.calendarEmpty, 'Nada previsto para este día.');
      final empty = find.descendant(
        of: find.byType(CalendarScreen),
        matching: find.byType(EmptyState),
      );
      expect(empty, findsOneWidget);
      expect(
        find.descendant(of: empty, matching: find.text(es.calendarEmpty)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: empty, matching: find.byType(ButtonStyleButton)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'U8: the empty-state texts name only Añadir tarea, in English, Spanish and Catalan',
    () {
      expect(en.calendarEmpty, 'Nothing planned for this day.');
      expect(ca.calendarEmpty, 'Res previst per a aquest dia.');
      expect(en.tasksEmpty, 'Tap Add a task to add one. A date is optional.');
      expect(
        es.tasksEmpty,
        'Toca Añadir tarea para añadir una. La fecha es opcional.',
      );
      expect(
        ca.tasksEmpty,
        'Toca Afegeix una tasca per afegir-ne una. La data és opcional.',
      );
      expect(en.inboxEmpty, endsWith('Start with Add a task.'));
      expect(es.inboxEmpty, endsWith('Empieza con Añadir tarea.'));
      expect(ca.inboxEmpty, endsWith('Comença amb Afegeix una tasca.'));
      expect(
        [en.addTask, es.addTask, ca.addTask],
        ['Add a task', 'Añadir tarea', 'Afegeix una tasca'],
      );
    },
  );

  test(
    'U8: the old create screen stays gone: no CreateTaskScreen, /createTask or useSchedule in App/lib (accounts without Pro create in the task form, /newTask, since 2026-10-18 later)',
    () {
      expect(File('lib/screens/create_task_screen.dart').existsSync(), isFalse);
      final hits = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File) continue;
        if (!file.path.endsWith('.dart') && !file.path.endsWith('.arb')) {
          continue;
        }
        final text = file.readAsStringSync();
        for (final word in ['CreateTaskScreen', '/createTask', 'useSchedule']) {
          if (text.contains(word)) hits.add('${file.path}: $word');
        }
      }
      expect(hits, isEmpty);
    },
  );

  // ---- P38 · UX-204: typing without Pro, understood on the phone ----
  // Since 2026-10-18 (later) an account without Pro types tasks only in the
  // form. The sheet still types, read on the phone, while billing hasn't
  // said yet whether the account has Pro: these tests open it so.

  /// Without Pro, before billing has answered, with no free dictation left:
  /// Añadir tarea opens the sheet typing, read on the phone.
  Future<_App> openTyping(
    WidgetTester tester, {
    DateTime? clock,
    String language = 'es',
    ClockFormat clockFormat = ClockFormat.twentyFour,
  }) => _App.open(
    tester,
    pro: false,
    billingLoading: true,
    freeLeft: 0,
    clock: clock,
    language: language,
    clockFormat: clockFormat,
  );

  testWidgets(
    'U8 / UX-204: without Pro, while billing hasn’t answered, Añadir tarea opens typing; Dentista viernes 10:00 → Listo shows Dentista on vie, … · 10:00 with Según lo que has escrito · Dejar como está and no network call; Dejar como está restores the words and no date',
    (tester) async {
      final start = monday();
      final friday = plus(start, 4);
      final app = await openTyping(tester, clock: start);
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      // Typing, with the keyboard up, and no microphone.
      expect(words(), findsOneWidget);
      expect(
        tester.widget<TextField>(words()).focusNode!.hasFocus,
        isTrue,
        reason: 'the field is focused',
      );
      expect(app.speech.starts, 0);
      expect(find.byKey(const ValueKey('capture-type-instead')), findsNothing);

      await tester.enterText(words(), 'Dentista viernes 10:00');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, es.done));
      await tester.pumpAndSettle();

      expect(find.byType(CaptureResult), findsOneWidget);
      expect(titleText(tester), 'Dentista');
      final line = dateLine(tester);
      // The app's weekday-first date (`vie, 17 oct`), and the time.
      final calendar = tester.element(find.byType(CalendarScreen));
      expect(line, '${calendar.weekdayDate(friday)} · 10:00');
      expect(line, startsWith('vie, '));
      expect(find.text(es.fromYourWords), findsOneWidget);
      expect(es.fromYourWords, 'Según lo que has escrito');
      final keep = find.widgetWithText(TextButton, es.keepAsTyped);
      expect(keep, findsOneWidget);
      expect(es.keepAsTyped, 'Dejar como está');
      expect(app.api.requests, 0, reason: 'nothing went to the assistant');

      await tester.tap(keep);
      await tester.pumpAndSettle();
      expect(titleText(tester), 'Dentista viernes 10:00');
      expect(dateLine(tester), es.noDate);
      expect(find.text(es.fromYourWords), findsNothing);
      expect(app.api.requests, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (language, clock, first, second) in [
    ('es', ClockFormat.twentyFour, '5:00', '17:00'),
    ('en', ClockFormat.twelve, '5:00 AM', '5:00 PM'),
  ]) {
    testWidgets(
      'UX-204: typing an ambiguous time (a las 5) offers $first · $second · ${language == 'es' ? es.reviewNoTime : en.reviewNoTime} under the date line ($language, ${clock.name}); picking $second sets it',
      (tester) async {
        final l = language == 'es' ? es : en;
        final start = monday();
        final app = await openTyping(
          tester,
          clock: start,
          language: language,
          clockFormat: clock,
        );
        await tester.tap(find.text(l.addTask).hitTestable());
        await tester.pumpAndSettle();
        await tester.enterText(
          words(),
          language == 'es'
              ? 'Llamar al médico el viernes a las 5'
              : 'Call the doctor Friday at 5',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, l.done));
        await tester.pumpAndSettle();
        final chips = find.descendant(
          of: find.byType(CaptureResult),
          matching: find.byType(ActionChip),
        );
        final labels = [
          for (final chip in tester.widgetList<ActionChip>(chips))
            (chip.label as Text).data,
        ];
        // 5 in the morning and 5 in the afternoon, in the phone's clock
        // format (`05:00` / `17:00`, `5:00 AM` / `5:00 PM`), then no time.
        final result = tester.element(find.byType(CaptureResult));
        final day = DateTime(2030, 1, 1);
        expect(labels, [
          result.clockTime(day.add(const Duration(hours: 5))),
          result.clockTime(day.add(const Duration(hours: 17))),
          l.reviewNoTime,
        ]);
        expect(labels.first, endsWith(first));
        expect(labels[1], second);
        // Under the date line, which has no time yet.
        expect(dateLine(tester), isNot(contains(second)));
        expect(
          tester.getRect(chips.first).top,
          greaterThan(
            tester
                .getRect(
                  find.byWidgetPredicate(
                    (w) =>
                        w.key is ValueKey<String> &&
                        (w.key! as ValueKey<String>).value.startsWith(
                          'draft-schedule-',
                        ),
                  ),
                )
                .top,
          ),
        );
        await tester.tap(find.widgetWithText(ActionChip, second));
        await tester.pumpAndSettle();
        expect(dateLine(tester), endsWith(' · $second'));
        expect(app.api.requests, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- P38 · UX-112: the selected day ----

  for (final pro in [true, false]) {
    testWidgets(
      'UX-112: ${pro ? 'said to the assistant' : 'typed without Pro, before billing has answered'}, a task with no date gets the Thursday selected on Calendar, without a time, and the capture keeps the day; with today selected it has no date',
      (tester) async {
        final start = monday();
        final thursday = plus(start, 3);
        final app = pro
            ? await _App.open(tester, pro: true, clock: start)
            : await openTyping(tester, clock: start);
        app.api.found = [_found('Comprar pan')];

        Future<void> capture() async {
          await tester.tap(find.text(es.addTask).hitTestable());
          await tester.pumpAndSettle();
          if (pro) {
            await tester.tap(
              find.byKey(const ValueKey('capture-type-instead')),
            );
            await tester.pumpAndSettle();
          }
          await tester.enterText(words(), 'Comprar pan');
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, es.done));
          await tester.pumpAndSettle();
          expect(find.byType(CaptureResult), findsOneWidget);
          expect(titleText(tester), 'Comprar pan');
        }

        await tapDay(tester, thursday);
        expect(
          find.text(DateFormat.MMMMEEEEd('es').format(thursday)),
          findsOneWidget,
        );
        await capture();
        expect(
          dateLine(tester),
          tester.element(find.byType(CalendarScreen)).weekdayDate(thursday),
        );
        final kept = app.store.sessions.values.last;
        expect(kept.day, thursday);
        final draft = kept.drafts.single.task;
        expect(Task.day(draft.dueDate!), thursday);
        expect(draft.hasTime, isFalse);
        expect(app.api.requests, pro ? 1 : 0);
        await tester.tap(
          inSheet(find.widgetWithText(TextButton, es.cancel)).first,
        );
        await tester.pumpAndSettle();
        // Kept for later, as before the question.
        await tester.tap(find.widgetWithText(FilledButton, es.keep));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);

        await tapDay(tester, start);
        expect(find.text(es.todayAgenda), findsOneWidget);
        await capture();
        expect(dateLine(tester), es.noDate);
        expect(app.store.sessions.values.last.day, isNull);
        expect(
          app.store.sessions.values.last.drafts.single.task.dueDate,
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- P39 · UX-102: nothing said, nothing kept ----

  for (final close in ['Cancelar', 'Back']) {
    testWidgets(
      'UX-102: the sheet opened listening, with nothing said, $close → no pending capture and no record written',
      (tester) async {
        final app = await _App.open(tester, pro: true);
        await tester.tap(find.text(es.addTask).hitTestable());
        await tester.pumpAndSettle();
        expect(app.speech.starts, 1);
        app.speech.send('ready');
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(VoiceTaskScreen), findsOneWidget);
        if (close == 'Cancelar') {
          await tester.tap(inSheet(find.widgetWithText(TextButton, es.cancel)));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(find.byType(VoiceTaskScreen), findsNothing);
        expect(app.store.sessions, isEmpty, reason: 'no record was created');
        expect(
          await app.container.read(pendingCapturesProvider.future),
          isEmpty,
        );
        expect(find.textContaining('pendiente'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-102: widget and shortcut entries write no capture up front; shared text keeps its record',
    (tester) async {
      final app = await _App.open(
        tester,
        pro: true,
        entries: [_entry('voice')],
      );
      // The widget's entry opens the sheet listening, with no record.
      expect(find.byType(VoiceTaskScreen), findsOneWidget);
      expect(app.store.sessions, isEmpty);
      expect(app.store.accepted, isEmpty);
      await tester.tap(inSheet(find.widgetWithText(TextButton, es.cancel)));
      await tester.pumpAndSettle();
      expect(find.byType(VoiceTaskScreen), findsNothing);
      // The text shortcut's entry: typing, still no record.
      app.entries.queue.add(_entry('text'));
      app.entries.changed();
      await tester.pumpAndSettle();
      expect(find.byType(VoiceTaskScreen), findsOneWidget);
      expect(words(), findsOneWidget);
      expect(app.store.sessions, isEmpty);
      await tester.tap(inSheet(find.widgetWithText(TextButton, es.cancel)));
      await tester.pumpAndSettle();
      expect(find.byType(VoiceTaskScreen), findsNothing);
      expect(app.store.sessions, isEmpty);
      expect(app.entries.acknowledged, hasLength(2));

      app.entries.queue.add(_entry('share', text: 'Comprar pilas'));
      app.entries.changed();
      await tester.pumpAndSettle();
      expect(app.store.accepted, hasLength(1));
      expect(app.store.sessions.values.single.text, 'Comprar pilas');
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P39 · UX-106 and UX-114: every way in, with or without Pro ----

  testWidgets(
    'UX-106 / 2026-10-18 (later): without Pro and with no dictation to use, the widget and the text shortcut open the form; shared text opens straight in the form, its day read out of the title (UX-1623, D3 of 2026-10-20), with no request to the server; no Actualizar estado anywhere',
    (tester) async {
      final app = await _App.open(
        tester,
        pro: false,
        entries: [_entry('voice')],
      );
      expect(find.byType(TaskEditor), findsOneWidget);
      expect(find.byType(VoiceTaskScreen), findsNothing);
      expect(app.speech.starts, 0);
      expect(find.text('Actualizar estado'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsNothing);

      app.entries.queue.add(_entry('text'));
      app.entries.changed();
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      app.entries.queue.add(_entry('share', text: 'Comprar pilas el viernes'));
      app.entries.changed();
      await tester.pumpAndSettle();
      expect(find.byType(VoiceTaskScreen), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(TaskEditor), findsOneWidget);
      expect(find.text(es.captureSpeakingIsPro), findsNothing);
      expect(find.text('Actualizar estado'), findsNothing);
      expect(app.speech.starts, 0);
      expect(titleText(tester), 'Comprar pilas');
      expect(app.api.requests, 0);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'UX-106: the Pro line reads Dictar una tarea es parte de TaskFlow Pro. Puedes escribirla aquí.',
    () {
      expect(
        es.captureSpeakingIsPro,
        'Dictar una tarea es parte de TaskFlow Pro. Puedes escribirla aquí.',
      );
      expect(es.voiceProAction, 'Ver Pro');
    },
  );

  test('UX-106: the Pro line reads the same in English and Catalan', () {
    expect(
      en.captureSpeakingIsPro,
      'Speaking a task is part of TaskFlow Pro. You can type it here.',
    );
    expect(
      ca.captureSpeakingIsPro,
      'Dictar una tasca forma part de TaskFlow Pro. La pots escriure aquí.',
    );
  });

  for (final way in ['Añadir tarea', 'the widget']) {
    testWidgets(
      'UX-106: while billing is loading, capture from $way shows a spinner and no Pro text, no microphone and no field',
      (tester) async {
        final app = await _App.open(
          tester,
          pro: false,
          billingLoading: true,
          entries: way == 'the widget' ? [_entry('voice')] : const [],
          settle: false,
        );
        if (way == 'Añadir tarea') {
          await tester.tap(find.text(es.addTask).hitTestable());
        }
        await frames(tester, 10);
        expect(find.byType(VoiceTaskScreen), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(VoiceTaskScreen),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        expect(find.text(es.captureSpeakingIsPro), findsNothing);
        expect(find.text(es.voiceProAction), findsNothing);
        expect(find.byKey(const ValueKey('free-voice-used-up')), findsNothing);
        expect(words(), findsNothing);
        expect(app.speech.starts, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final kind in ['text', 'share']) {
    testWidgets(
      'UX-114: with Pro, ${kind == 'text' ? 'the Escribir una tarea shortcut' : 'shared text'} opens typing with the field focused and nothing listening',
      (tester) async {
        final app = await _App.open(
          tester,
          pro: true,
          entries: [_entry(kind, text: kind == 'share' ? 'Comprar pilas' : '')],
        );
        expect(find.byType(VoiceTaskScreen), findsOneWidget);
        expect(words(), findsOneWidget);
        final field = tester.widget<TextField>(words());
        expect(field.focusNode!.hasFocus, isTrue);
        expect(field.readOnly, isFalse);
        expect(field.controller!.text, kind == 'share' ? 'Comprar pilas' : '');
        expect(app.speech.starts, 0, reason: 'nothing listens');
        expect(find.textContaining('Escuchando'), findsNothing);
        expect(find.text(es.captureSpeakingIsPro), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'UX-114: the text shortcut is named Type a new task (UX-1656) / Escribir una tarea / Escriu una tasca',
    () {
      String label(String folder) {
        final xml = File(
          'android/app/src/main/res/$folder/strings.xml',
        ).readAsStringSync();
        return RegExp(
          r'<string name="capture_text">([^<]*)</string>',
        ).firstMatch(xml)!.group(1)!;
      }

      expect(label('values'), 'Type a new task');
      expect(label('values-es'), 'Escribir una tarea');
      expect(label('values-ca'), 'Escriu una tasca');
    },
  );

  // ---- P40 · U7: the assistant slow or failing ----

  testWidgets(
    'U7: with an assistant that never answers, after 8 s the sheet says Está tardando más de lo normal. with Guardar como tarea; it saves Llamar al médico on Friday, lands with Deshacer, and the late answer changes nothing',
    (tester) async {
      final start = monday();
      final friday = plus(start, 4);
      final app = await _App.open(tester, pro: true, clock: start);
      app.api.hold = Completer<void>();
      app.api.found = [_found('Otra cosa')];
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('capture-type-instead')));
      await tester.pumpAndSettle();
      await tester.enterText(words(), 'llamar al médico el viernes');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, es.done));
      await frames(tester);
      expect(find.text(es.captureUnderstanding), findsOneWidget);
      expect(find.text(es.captureSlow), findsNothing);
      expect(find.text(es.captureSaveAsWritten), findsNothing);
      await tester.pump(const Duration(seconds: 7));
      expect(find.text(es.captureSlow), findsNothing);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(es.captureSlow, 'Está tardando más de lo normal.');
      expect(find.text(es.captureSlow), findsOneWidget);
      final save = find.widgetWithText(FilledButton, es.captureSaveAsWritten);
      expect(save, findsOneWidget);
      expect(es.captureSaveAsWritten, 'Guardar como tarea');

      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(app.tasks.titles(), ['Llamar al médico']);
      final saved = app.tasks.state.requireValue.single;
      expect(Task.day(saved.dueDate!), friday);
      // Calendar lands on Friday, with the row lit and Deshacer.
      expect(
        find.text(DateFormat.MMMMEEEEd('es').format(friday)),
        findsOneWidget,
      );
      final row = find.widgetWithText(TaskTile, 'Llamar al médico');
      expect(row.hitTestable(), findsOneWidget);
      final calendar = tester.element(find.byType(CalendarScreen));
      expect(
        find.text(es.taskAddedOn(calendar.weekdayDate(friday))),
        findsOneWidget,
      );
      expect(find.text(es.undo), findsOneWidget);

      // The assistant answers at last: nothing changes.
      app.api.hold!.complete();
      await tester.pumpAndSettle();
      expect(app.tasks.titles(), ['Llamar al médico']);
      expect(find.text('Otra cosa'), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(MessageBanner), findsNothing);
      expect(app.store.sessions.values.single.status, 'saved');
      expect(tester.takeException(), isNull);
    },
  );

  for (final (what, failure, reason) in [
    (
      'a server error',
      ApiException(503, 'Service unavailable'),
      es.captureUnavailable,
    ),
    (
      'no internet',
      ApiException(0, 'Offline. Retry when connected.'),
      es.captureOffline,
    ),
    (
      'a 400 with field text',
      ApiException(400, 'text: This field may not be blank.'),
      es.captureFailed,
    ),
  ]) {
    testWidgets(
      'U7 / UX-103: after $what the sheet shows the words, the reason in plain words under the status line as a live region, with Reintentar and Guardar como tarea; no Tu captura se conserva',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final app = await _App.open(tester, pro: true);
        app.api.failure = failure;
        await tester.tap(find.text(es.addTask).hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('capture-type-instead')));
        await tester.pumpAndSettle();
        await tester.enterText(words(), 'Comprar pan');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, es.done));
        await tester.pumpAndSettle();

        final banner = find.byType(MessageBanner);
        expect(banner, findsOneWidget);
        expect(
          find.descendant(of: banner, matching: find.text(reason)),
          findsOneWidget,
        );
        expect(find.textContaining('Service unavailable'), findsNothing);
        expect(find.textContaining('This field'), findsNothing);
        expect(find.textContaining('text:'), findsNothing);
        expect(
          find.textContaining('Tu captura se conserva en este teléfono.'),
          findsNothing,
        );
        expect(
          reason,
          isNot(endsWith('Tu captura se conserva en este teléfono.')),
        );
        // The words are still there, under the reason.
        expect(
          tester.widget<TextField>(words()).controller!.text,
          'Comprar pan',
        );
        expect(
          tester.getRect(banner).bottom,
          lessThanOrEqualTo(tester.getRect(words()).top),
        );
        final status = find.text(es.captureUnderstanding);
        if (status.evaluate().isNotEmpty) {
          expect(
            tester.getRect(status).bottom,
            lessThanOrEqualTo(tester.getRect(banner).top),
          );
        }
        expect(
          tester
              .getSemantics(banner)
              .getSemanticsData()
              .flagsCollection
              .isLiveRegion,
          isTrue,
        );
        final retry = find.widgetWithText(FilledButton, es.tryAgain);
        expect(retry, findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, es.captureSaveAsWritten),
          findsOneWidget,
        );
        expect(es.tryAgain, 'Reintentar');
        // Reintentar asks again.
        app.api.failure = null;
        app.api.found = [_found('Comprar pan')];
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(app.api.requests, 2);
        expect(find.byType(CaptureResult), findsOneWidget);
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'U7: saved audio with no words that failed offers Reintentar but not Guardar como tarea',
    (tester) async {
      final app = await _App.open(tester, pro: true);
      app.store.sessions['audio'] = CaptureSession(
        id: 'audio',
        ownerKey: app.container.read(captureOwnerProvider),
        timezone: 'Europe/Madrid',
        capturedAt: DateTime.now().toUtc(),
        audioPath: '${Directory.systemTemp.path}/taskflow-missing.wav',
        status: 'failed',
        source: 'speech',
        error: CaptureProblem.unavailable,
      );
      unawaited(
        showCaptureSheet(
          tester.element(find.byType(CalendarScreen)),
          captureId: 'audio',
          startListening: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(es.captureUnavailable), findsOneWidget);
      expect(find.widgetWithText(FilledButton, es.tryAgain), findsOneWidget);
      expect(find.text(es.captureSaveAsWritten), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-451: when the recognizer reports an error, it shows in plain words in a live-region banner above the words',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final app = await _App.open(tester, pro: true);
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      app.speech.send('ready');
      app.speech.send('segment', text: 'Comprar pan');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      app.speech.send('error', error: CaptureProblem.speechStopped);
      await tester.pumpAndSettle();
      final banner = find.byType(MessageBanner);
      expect(banner, findsOneWidget);
      expect(
        find.descendant(
          of: banner,
          matching: find.text(es.captureSpeechStopped),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(banner)
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      final heard = find.text('Comprar pan');
      expect(heard, findsOneWidget);
      expect(
        tester.getRect(banner).bottom,
        lessThanOrEqualTo(tester.getRect(heard).top),
      );
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P40 · UX-103: captureProblemText never shows a server's words ----

  group('UX-103: captureProblemText', () {
    final inputs = <String, Object>{
      'an unknown string': 'Something unexpected happened on the server',
      'ApiException 400': ApiException(400, 'Bad request'),
      'ApiException 404': ApiException(404, 'Not found.'),
      'ApiException 422': ApiException(422, 'Audio too short'),
      'a field: message text': 'text: This field may not be blank.',
      'ApiException 400 with field: message': ApiException(
        400,
        'project_id: Invalid pk "7" - object does not exist.',
      ),
    };
    for (final MapEntry(key: what, value: input) in inputs.entries) {
      test(
        'UX-103: $what produces no English and no field: in Spanish or Catalan',
        () {
          final value = input is String ? input : CaptureProblem.from(input);
          for (final l in [es, ca]) {
            final text = captureProblemText(l, value);
            expect(
              text,
              isNot(contains(':')),
              reason: '${l.localeName}: $text',
            );
            expect(text, isNot(contains('field')));
            expect(text, isNot(contains('server')));
            expect(text, isNot(contains('Not found')));
            expect(text, isNot(contains('Bad request')));
            expect(text, isNot(contains('Audio too short')));
            expect(text, isNot(captureProblemText(en, value)));
          }
        },
      );
    }

    test('UX-103: unknown input gives the generic message in each language', () {
      for (final input in [
        'Something unexpected happened on the server',
        'text: This field may not be blank.',
        CaptureProblem.from(ApiException(400, 'Bad request')),
        CaptureProblem.from(ApiException(404, 'Not found.')),
      ]) {
        expect(captureProblemText(es, input), es.captureFailed);
        expect(captureProblemText(ca, input), ca.captureFailed);
        expect(captureProblemText(en, input), en.captureFailed);
      }
      expect(
        es.captureFailed,
        'No ha funcionado. Tus palabras siguen aquí; inténtalo de nuevo.',
      );
      expect(
        ca.captureFailed,
        'No ha funcionat. Les teves paraules continuen aquí; torna-ho a provar.',
      );
      expect(
        en.captureFailed,
        'That didn’t work. Your words are saved here — try again.',
      );
    });

    test('UX-103: each known problem has its plain message, in EN / ES / CA', () {
      String text(AppLocalizations l, Object error) =>
          captureProblemText(l, CaptureProblem.from(error));
      final unreachable = ApiException(0, ApiClient.unreachableMessage);
      final timeout = ApiException(0, ApiClient.timeoutMessage);
      final offline = ApiException(0, 'Offline. Retry when connected.');
      for (final error in [unreachable, timeout, ApiException(502, 'x')]) {
        expect(
          text(es, error),
          'No he podido contactar con el asistente; tus palabras se conservan.',
        );
        expect(
          text(ca, error),
          'No he pogut contactar amb l’assistent; les teves paraules es conserven.',
        );
        expect(
          text(en, error),
          'Couldn’t reach the assistant — your words are kept.',
        );
      }
      expect(
        text(es, offline),
        'Sin conexión. Tus palabras están guardadas; inténtalo cuando tengas internet.',
      );
      expect(
        text(ca, offline),
        'Sense connexió. Les teves paraules estan desades; torna-ho a provar quan tinguis internet.',
      );
      expect(
        text(en, offline),
        'No internet. Your words are saved — try again when you’re online.',
      );
      final short = ApiException(422, 'Audio too short');
      expect(
        text(es, short),
        'No te he entendido. Vuelve a intentarlo o escríbelo.',
      );
      expect(text(ca, short), 'No t’he entès. Torna-ho a provar o escriu-ho.');
      expect(text(en, short), 'I didn’t catch that. Try again, or type it.');
      expect(captureProblemText(es, CaptureProblem.noSpeech), text(es, short));
      expect(
        captureProblemText(es, CaptureProblem.speechStopped),
        'Se ha dejado de escuchar. Puedes volver a hablar o escribir.',
      );
      expect(
        captureProblemText(ca, CaptureProblem.speechStopped),
        'S’ha deixat d’escoltar. Pots tornar a parlar o escriure.',
      );
      expect(
        captureProblemText(en, CaptureProblem.speechStopped),
        'Listening stopped. You can talk again, or type.',
      );
      // Today's limit: the server says to wait longer than a minute or two.
      final limit = ApiException(
        429,
        'Too many requests',
        null,
        const Duration(hours: 1),
      );
      expect(
        text(es, limit),
        'Has llegado al límite de dictados de hoy. Toca Guardar como tarea o inténtalo mañana.',
      );
      expect(
        text(ca, limit),
        'Has arribat al límit de dictats d’avui. Toca Desa-ho com a tasca o torna-ho a provar demà.',
      );
      expect(
        text(en, limit),
        'You’ve reached today’s dictation limit. Tap Save as a task, or try again tomorrow.',
      );
    });
  });
  // ---- Round 2 · P67 · UX-103: messages name what's on screen ----

  Finder button(String label) => find.widgetWithText(FilledButton, label);

  /// No message on screen tells the user to tap `Seguir`.
  void expectNoTapSeguir() {
    expect(find.textContaining('Toca Seguir'), findsNothing);
    expect(find.textContaining('Seguir'), findsNothing);
  }

  CaptureSession recorded(
    _App app, {
    String? error,
    String status = 'editing',
  }) => CaptureSession(
    id: 'silent',
    ownerKey: app.container.read(captureOwnerProvider),
    timezone: 'Europe/Madrid',
    capturedAt: DateTime.now().toUtc(),
    audioPath: '${Directory.systemTemp.path}/taskflow-silent.wav',
    status: status,
    source: 'speech',
    error: error,
  );

  testWidgets(
    'UX-103: at 360×740, a recorded capture with no words that the assistant answers with 422 says No te he entendido. Vuelve a intentarlo o escríbelo., offers Empezar a hablar and no Reintentar, keeps no pending capture, and Empezar a hablar listens again',
    (tester) async {
      final app = await _App.open(
        tester,
        pro: true,
        size: const Size(360, 740),
      );
      app.store.sessions['silent'] = recorded(app);
      app.api.failure = ApiException(422, 'Audio too short');
      unawaited(
        showCaptureSheet(
          tester.element(find.byType(CalendarScreen)),
          captureId: 'silent',
          startListening: false,
        ),
      );
      await tester.pumpAndSettle();
      // The kept recording, sent with Listo.
      expect(button(es.done), findsOneWidget);
      await tester.tap(button(es.done));
      // The processor checks the audio file on disk: real I/O, outside the
      // fake clock.
      for (var i = 0; i < 10 && app.api.requests == 0; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(app.api.requests, 1);

      expect(
        es.captureNoSpeech,
        'No te he entendido. Vuelve a intentarlo o escríbelo.',
      );
      expect(
        find.descendant(
          of: find.byType(MessageBanner),
          matching: find.text(es.captureNoSpeech),
        ),
        findsOneWidget,
      );
      expectNoTapSeguir();
      expect(es.captureStartTalking, 'Empezar a hablar');
      expect(button(es.captureStartTalking).hitTestable(), findsOneWidget);
      expect(find.text(es.tryAgain), findsNothing);
      expect(find.text(es.captureSaveAsWritten), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget, reason: 'stays open');
      // Nothing kept for that audio.
      expect(app.store.sessions['silent']!.status, 'discarded');
      expect(await app.container.read(pendingCapturesProvider.future), isEmpty);

      await tester.tap(button(es.captureStartTalking));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(app.speech.starts, 1, reason: 'a new recording starts');
      expect(app.api.requests, 1, reason: 'the silent audio is not resent');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-103: a recorded capture reopened from the pending list after the server found no speech shows No te he entendido…, offers Empezar a hablar and no Reintentar, and is dropped',
    (tester) async {
      final app = await _App.open(tester, pro: true);
      app.store.sessions['silent'] = recorded(
        app,
        error: CaptureProblem.noSpeech,
        status: 'failed',
      );
      unawaited(
        showCaptureSheet(
          tester.element(find.byType(CalendarScreen)),
          captureId: 'silent',
          startListening: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(es.captureNoSpeech), findsOneWidget);
      expectNoTapSeguir();
      expect(button(es.captureStartTalking), findsOneWidget);
      expect(find.text(es.tryAgain), findsNothing);
      expect(app.store.sessions['silent']!.status, 'discarded');
      expect(await app.container.read(pendingCapturesProvider.future), isEmpty);
      expect(app.api.requests, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-103: when the phone stops listening before any words, the sheet says Se ha dejado de escuchar. Puedes volver a hablar o escribir. with Empezar a hablar, and nothing says Toca Seguir',
    (tester) async {
      final app = await _App.open(tester, pro: true);
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      expect(app.speech.starts, 1);
      app.speech.send('ready');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      app.speech.send('error', error: CaptureProblem.speechStopped);
      await tester.pumpAndSettle();
      expect(
        es.captureSpeechStopped,
        'Se ha dejado de escuchar. Puedes volver a hablar o escribir.',
      );
      expect(
        find.descendant(
          of: find.byType(MessageBanner),
          matching: find.text(es.captureSpeechStopped),
        ),
        findsOneWidget,
      );
      expect(button(es.captureStartTalking), findsOneWidget);
      expect(find.text(es.captureContinue), findsNothing);
      expectNoTapSeguir();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-103: typed words the assistant answers with 422 show No ha funcionado. Tus palabras siguen aquí; inténtalo de nuevo., not the no-speech message, and the words stay',
    (tester) async {
      final app = await _App.open(tester, pro: true);
      app.api.failure = ApiException(422, 'Update the app to continue.');
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('capture-type-instead')));
      await tester.pumpAndSettle();
      await tester.enterText(words(), 'Comprar pan');
      await tester.pumpAndSettle();
      await tester.tap(button(es.done));
      await tester.pumpAndSettle();
      expect(app.api.requests, 1);
      expect(
        es.captureFailed,
        'No ha funcionado. Tus palabras siguen aquí; inténtalo de nuevo.',
      );
      expect(
        find.descendant(
          of: find.byType(MessageBanner),
          matching: find.text(es.captureFailed),
        ),
        findsOneWidget,
      );
      expect(find.text(es.captureNoSpeech), findsNothing);
      expect(tester.widget<TextField>(words()).controller!.text, 'Comprar pan');
      expect(find.textContaining('Update the app'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Round 2 · P67 · UX-467: slow is spoken ----

  testWidgets(
    'UX-467: with an assistant that never answers, at 8 s TalkBack is told Está tardando más de lo normal., once',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final app = await _App.open(tester, pro: true);
      app.api.hold = Completer<void>();
      app.api.found = [_found('Comprar pan')];
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('capture-type-instead')));
      await tester.pumpAndSettle();
      await tester.enterText(words(), 'Comprar pan');
      await tester.pumpAndSettle();
      tester.takeAnnouncements();
      await tester.tap(button(es.done));
      await frames(tester);
      List<String> slow() => [
        for (final a in tester.takeAnnouncements())
          if (a.message == es.captureSlow) a.message,
      ];
      expect(slow(), isEmpty);
      await tester.pump(const Duration(seconds: 7));
      expect(slow(), isEmpty, reason: 'not before 8 s');
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text(es.captureSlow), findsOneWidget);
      expect(slow(), [es.captureSlow]);
      expect(es.captureSlow, 'Está tardando más de lo normal.');
      // Still waiting: said once, not again.
      await tester.pump(const Duration(seconds: 10));
      expect(slow(), isEmpty);
      app.api.hold!.complete();
      await tester.pumpAndSettle();
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Round 2 · P67 · UX-468: the typing hint is what typing makes ----

  for (final language in ['es', 'en']) {
    testWidgets(
      'UX-468: without Pro, before billing has answered, the empty typing field reads ${language == 'es' ? 'Médico el viernes a las 17:00' : 'Doctor Friday at 5 p.m.'} ($language)',
      (tester) async {
        final l = language == 'es' ? es : en;
        await openTyping(tester, language: language);
        await tester.tap(find.text(l.addTask).hitTestable());
        await tester.pumpAndSettle();
        final hint = tester.widget<TextField>(words()).decoration!.hintText;
        expect(
          hint,
          language == 'es'
              ? 'Médico el viernes a las 17:00'
              : 'Doctor Friday at 5 p.m.',
        );
        expect(hint, l.exampleTask);
        expect(inSheet(find.text(l.exampleTask)), findsOneWidget);
        expect(find.text(l.examplePlan), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-468: with Pro, Escribir shows the existing examplePlan hint',
    (tester) async {
      await _App.open(tester, pro: true);
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('capture-type-instead')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(words()).decoration!.hintText,
        es.examplePlan,
      );
      expect(find.text(es.exampleTask), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Round 2 · P67 · UX-469: the failed pair stacked ----

  testWidgets(
    'UX-469: Catalan, 1.0× text, 360×740: after a failure with words, Torna-ho a provar sits above Desa-ho com a tasca, each as wide as the controls',
    (tester) async {
      final app = await _App.open(
        tester,
        pro: true,
        language: 'ca',
        size: const Size(360, 740),
      );
      app.api.failure = ApiException(503, 'Service unavailable');
      await tester.tap(find.text(ca.addTask).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('capture-type-instead')));
      await tester.pumpAndSettle();
      await tester.enterText(words(), 'Comprar pa');
      await tester.pumpAndSettle();
      await tester.tap(button(ca.done));
      await tester.pumpAndSettle();
      expect(ca.tryAgain, 'Torna-ho a provar');
      expect(ca.captureSaveAsWritten, 'Desa-ho com a tasca');
      final retry = tester.getRect(button(ca.tryAgain));
      final save = tester.getRect(button(ca.captureSaveAsWritten));
      expect(retry.bottom, lessThanOrEqualTo(save.top), reason: '$retry $save');
      // As wide as the controls area: the sheet's column, the field's width.
      final area = tester.getRect(words());
      for (final rect in [retry, save]) {
        expect(rect.left, moreOrLessEquals(area.left, epsilon: 0.5));
        expect(rect.width, moreOrLessEquals(area.width, epsilon: 0.5));
      }
      // Whether each label reads on one line depends on the real font; the
      // test font draws every letter a full em wide, so that is checked on a
      // phone. Here: each label gets the whole width, not half of it.
      for (final label in [ca.tryAgain, ca.captureSaveAsWritten]) {
        expect(
          tester.getRect(find.text(label)).width,
          greaterThan(area.width / 2),
          reason: label,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Round 2 · P67 · UX-470: the Pro line names the task ----

  test(
    'UX-470: app_es.arb and app_ca.arb captureSpeakingIsPro name the task they mean',
    () {
      String value(String language) =>
          (jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
                  as Map<String, dynamic>)['captureSpeakingIsPro']
              as String;
      expect(
        value('es'),
        'Dictar una tarea es parte de TaskFlow Pro. Puedes escribirla aquí.',
      );
      expect(
        value('ca'),
        'Dictar una tasca forma part de TaskFlow Pro. La pots escriure aquí.',
      );
      expect(
        value('en'),
        'Speaking a task is part of TaskFlow Pro. You can type it here.',
      );
    },
  );

  // ---- Round 2 · P68 · UX-465: the phone's time question has its line ----

  for (final language in ['es', 'en']) {
    testWidgets(
      'UX-465: without Pro, before billing has answered, typing an ambiguous hour shows ${language == 'es' ? '¿A qué hora?' : 'What time?'} above the morning and evening chips ($language)',
      (tester) async {
        final l = language == 'es' ? es : en;
        await openTyping(tester, clock: monday(), language: language);
        await tester.tap(find.text(l.addTask).hitTestable());
        await tester.pumpAndSettle();
        await tester.enterText(
          words(),
          language == 'es'
              ? 'llamar al médico el viernes a las 5'
              : 'Call the doctor Friday at 5',
        );
        await tester.pumpAndSettle();
        await tester.tap(button(l.done));
        await tester.pumpAndSettle();
        expect(
          l.captureWhatTime,
          language == 'es' ? '¿A qué hora?' : 'What time?',
        );
        final question = find.descendant(
          of: find.byType(CaptureResult),
          matching: find.text(l.captureWhatTime),
        );
        expect(question, findsOneWidget);
        final chips = find.descendant(
          of: find.byType(CaptureResult),
          matching: find.byType(ActionChip),
        );
        expect(chips, findsNWidgets(3));
        final result = tester.element(find.byType(CaptureResult));
        final day = DateTime(2030, 1, 1);
        for (final hour in [5, 17]) {
          final chip = find.widgetWithText(
            ActionChip,
            result.clockTime(day.add(Duration(hours: hour))),
          );
          expect(chip, findsOneWidget);
          expect(
            tester.getRect(question).bottom,
            lessThanOrEqualTo(tester.getRect(chip).top),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- Round 2 · P69 · UX-466: saved from the day timeline ----

  Future<void> openTimeline(WidgetTester tester, DateTime day) async {
    unawaited(
      Navigator.of(
        tester.element(find.byType(CalendarScreen)),
      ).pushNamed('/timeline', arguments: day),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DayTimelineScreen), findsOneWidget);
  }

  Future<void> typeAndSave(WidgetTester tester, String text) async {
    await tester.tap(find.text(es.addTask).hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(words(), text);
    await tester.pumpAndSettle();
    await tester.tap(button(es.done));
    await tester.pumpAndSettle();
    expect(find.byType(CaptureResult), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  }

  /// The highlight a just-saved row is drawn with.
  Color litColor(WidgetTester tester) => Theme.of(
    tester.element(find.byType(Scaffold).hitTestable().first),
  ).colorScheme.primaryContainer;

  testWidgets(
    'UX-466: without Pro, before billing has answered, from today’s timeline, comprar pan saved returns to Calendar with the Sin fecha row highlighted, and the timeline is gone',
    (tester) async {
      final start = monday();
      final app = await openTyping(tester, clock: start);
      await openTimeline(tester, start);
      await typeAndSave(tester, 'comprar pan');
      expect(app.tasks.titles(), ['Comprar pan']);
      expect(app.tasks.state.requireValue.single.dueDate, isNull);
      expect(find.byType(DayTimelineScreen), findsNothing);
      expect(find.byType(CalendarScreen).hitTestable(), findsWidgets);
      final inbox = find.byKey(const ValueKey('calendar-inbox'));
      // On screen, above the save message that covers the bottom of the
      // page (Calendar's layout, unchanged by P69).
      final rect = tester.getRect(inbox);
      final view = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(view.height));
      expect(
        rect.top,
        lessThan(tester.getRect(find.byType(SnackBar)).top),
        reason: 'the row shows above the message',
      );
      final box = tester.widget<DecoratedBox>(
        find.ancestor(of: inbox, matching: find.byType(DecoratedBox)).first,
      );
      expect((box.decoration as BoxDecoration).color, litColor(tester));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-466: on Thursday’s timeline, comprar pan saved keeps the timeline open with the new row on screen in the unblocked list, highlighted',
    (tester) async {
      final start = monday();
      final thursday = plus(start, 3);
      final app = await openTyping(tester, clock: start);
      await openTimeline(tester, thursday);
      await typeAndSave(tester, 'comprar pan');
      expect(Task.day(app.tasks.state.requireValue.single.dueDate!), thursday);
      expect(find.byType(DayTimelineScreen).hitTestable(), findsWidgets);
      final row = find.descendant(
        of: find.byType(DayTimelineScreen),
        matching: find.widgetWithText(TaskTile, 'Comprar pan'),
      );
      expect(row.hitTestable(), findsOneWidget);
      final section = find.descendant(
        of: find.byType(DayTimelineScreen),
        matching: find.text(es.timelineUnblocked.toUpperCase()),
      );
      expect(section, findsOneWidget);
      expect(
        tester.getRect(row).top,
        greaterThanOrEqualTo(tester.getRect(section).bottom),
      );
      expect(tester.widget<TaskTile>(row).color, litColor(tester));
      // The highlight fades after 1.5 s.
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
      expect(tester.widget<TaskTile>(row).color, isNot(litColor(tester)));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1633: on Thursday’s timeline with a full «Sin hora» area and a task at 08:30, comprar pan saved lights its row inside the pinned «Sin hora» area, wholly on screen',
    (tester) async {
      final start = monday();
      final thursday = plus(start, 3);
      final app = await openTyping(tester, clock: start);
      app.tasks.add(
        Task(
          title: 'Paseo por el parque',
          priority: 1,
          dueDate: DateTime(thursday.year, thursday.month, thursday.day, 8, 30),
        ),
      );
      for (final title in [
        'Pagar la factura de la luz',
        'Llamar a la abuela',
        'Devolver el libro',
        'Regar las plantas',
        'Sacar la basura',
        'Escribir a Paul',
      ]) {
        app.tasks.add(
          Task(title: title, priority: 1, dueDate: thursday, hasTime: false),
        );
      }
      await tester.pumpAndSettle();
      await openTimeline(tester, thursday);
      await typeAndSave(tester, 'comprar pan');
      final saved = app.tasks.state.requireValue.firstWhere(
        (task) => task.title == 'Comprar pan',
      );
      expect(Task.day(saved.dueDate!), thursday);
      expect(saved.hasTime, isFalse);
      final timeline = find.byType(DayTimelineScreen);
      final area = find.descendant(
        of: timeline,
        matching: find.byKey(const ValueKey('timeline-untimed')),
      );
      expect(area, findsOneWidget);
      // The area is full: it scrolls by itself.
      final scroll = tester
          .state<ScrollableState>(
            find.descendant(of: area, matching: find.byType(Scrollable)).first,
          )
          .position;
      expect(scroll.maxScrollExtent, greaterThan(0));
      final row = find.descendant(
        of: area,
        matching: find.widgetWithText(TaskTile, 'Comprar pan'),
      );
      expect(row, findsOneWidget, reason: 'in the «Sin hora» area');
      final rect = tester.getRect(row);
      final view = tester.getRect(area);
      expect(rect.top, greaterThanOrEqualTo(view.top - 0.5));
      expect(rect.bottom, lessThanOrEqualTo(view.bottom + 0.5));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(
        rect.bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height),
      );
      expect(row.hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(row).color, litColor(tester));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1639: on Thursday’s timeline, comprar pan saved still lights its row inside «Sin hora», on screen, and the row leaves out the day the header names',
    (tester) async {
      final start = monday();
      final thursday = plus(start, 3);
      final app = await openTyping(tester, clock: start);
      await openTimeline(tester, thursday);
      await typeAndSave(tester, 'comprar pan');
      final saved = app.tasks.state.requireValue.single;
      expect(Task.day(saved.dueDate!), thursday);
      expect(saved.hasTime, isFalse);
      final area = find.descendant(
        of: find.byType(DayTimelineScreen),
        matching: find.byKey(const ValueKey('timeline-untimed')),
      );
      final row = find.descendant(
        of: area,
        matching: find.widgetWithText(TaskTile, 'Comprar pan'),
      );
      expect(row, findsOneWidget, reason: 'in the «Sin hora» area');
      final rect = tester.getRect(row);
      final view = tester.getRect(area);
      expect(rect.top, greaterThanOrEqualTo(view.top - 0.5));
      expect(rect.bottom, lessThanOrEqualTo(view.bottom + 0.5));
      expect(row.hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(row).color, litColor(tester));
      final day = tester.element(row).dayLabel(thursday);
      expect(
        find.descendant(of: row, matching: find.textContaining(day)),
        findsNothing,
        reason: 'the header already names «$day»',
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.schedule_rounded)),
        findsNothing,
        reason: 'no date line',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-466: on Thursday’s timeline, comprar pan el viernes saved returns to Calendar with Friday selected and the new row highlighted',
    (tester) async {
      final start = monday();
      final thursday = plus(start, 3);
      final friday = plus(start, 4);
      final app = await openTyping(tester, clock: start);
      await openTimeline(tester, thursday);
      await typeAndSave(tester, 'comprar pan el viernes');
      expect(Task.day(app.tasks.state.requireValue.single.dueDate!), friday);
      expect(find.byType(DayTimelineScreen), findsNothing);
      expect(
        find.text(DateFormat.MMMMEEEEd('es').format(friday)),
        findsOneWidget,
      );
      final row = find.descendant(
        of: find.byType(CalendarScreen),
        matching: find.widgetWithText(TaskTile, 'Comprar pan'),
      );
      expect(row.hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(row).color, litColor(tester));
      expect(tester.takeException(), isNull);
    },
  );

  // ---- 2026-10-14-speed · P104 (UX-604): parts of the day on the phone ----

  testWidgets(
    'UX-604: without Pro, before billing has answered, typed “Llamar a mamá mañana por la mañana” shows the date line Mañana and the title Llamar a mamá por la mañana',
    (tester) async {
      final app = await openTyping(tester);
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      await tester.enterText(words(), 'Llamar a mamá mañana por la mañana');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, es.done));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(titleText(tester), 'Llamar a mamá por la mañana');
      expect(dateLine(tester), es.tomorrow);
      expect(es.tomorrow, 'Mañana');
      expect(app.api.requests, 0, reason: 'understood on the phone');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-604: with the assistant offline, a spoken “Médico el viernes a las 5 de la tarde” saved with Guardar como tarea is saved at once on Friday at 17:00, titled Médico',
    (tester) async {
      final start = monday();
      final friday = plus(start, 4);
      final app = await _App.open(tester, pro: true, clock: start);
      app.api.failure = ApiException(0, 'Offline. Retry when connected.');
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      expect(app.speech.starts, 1);
      app.speech.send('ready');
      app.speech.send('segment', text: 'Médico el viernes a las 5 de la tarde');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, es.done));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, es.captureSaveAsWritten);
      expect(save, findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();
      // Saved at once: no result to check, no time question.
      expect(find.byType(CaptureResult), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(app.tasks.titles(), ['Médico']);
      final saved = app.tasks.state.requireValue.single;
      expect(
        saved.dueDate,
        DateTime(friday.year, friday.month, friday.day, 17),
      );
      expect(saved.hasTime, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- 2026-10-14-speed round 2 · P107 (UX-618): a passed time goes on the
  // next day ----

  testWidgets(
    'UX-618: at 10:00 with the assistant offline, a spoken “Llamar a Juan a las 9 de la mañana” saved with Guardar como tarea is saved on the next day at 09:00, titled Llamar a Juan',
    (tester) async {
      final wednesday = plus(monday(), 2);
      final start = DateTime(
        wednesday.year,
        wednesday.month,
        wednesday.day,
        10,
      );
      final thursday = plus(start, 1);
      final app = await _App.open(tester, pro: true, clock: start);
      app.api.failure = ApiException(0, 'Offline. Retry when connected.');
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      expect(app.speech.starts, 1);
      app.speech.send('ready');
      app.speech.send('segment', text: 'Llamar a Juan a las 9 de la mañana');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, es.done));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, es.captureSaveAsWritten);
      expect(save, findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();
      // Saved at once, with no question, and not in the past.
      expect(find.byType(CaptureResult), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(app.tasks.titles(), ['Llamar a Juan']);
      final saved = app.tasks.state.requireValue.single;
      expect(
        saved.dueDate,
        DateTime(thursday.year, thursday.month, thursday.day, 9),
      );
      expect(saved.hasTime, isTrue);
      expect(saved.dueDate!.isAfter(start), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- 2026-10-14-speed · P102 (UX-602): a landing doesn't date the next ----

  /// `Añadir tarea`, the words (typed, or to the assistant with Pro through
  /// Escribir), `Listo`: the result shows.
  Future<void> captureWords(
    WidgetTester tester,
    String said, {
    required bool pro,
  }) async {
    await tester.tap(find.text(es.addTask).hitTestable());
    await tester.pumpAndSettle();
    if (pro) {
      await tester.tap(find.byKey(const ValueKey('capture-type-instead')));
      await tester.pumpAndSettle();
    }
    await tester.enterText(words(), said);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, es.done));
    await tester.pumpAndSettle();
    expect(find.byType(CaptureResult), findsOneWidget);
  }

  Future<void> saveResult(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('save-drafts')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  }

  /// Leaves the result pending (Cancelar, Conservar).
  Future<void> keepResult(WidgetTester tester) async {
    await tester.tap(inSheet(find.widgetWithText(TextButton, es.cancel)).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, es.keep));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  }

  Map<String, dynamic> dated(String title, DateTime at) => {
    ..._found(title),
    'due_date': at.toIso8601String(),
  };

  String selectedHeader(DateTime day) => DateFormat.MMMMEEEEd('es').format(day);

  for (final pro in [true, false]) {
    testWidgets(
      'UX-602: ${pro ? 'with the assistant' : 'typed without Pro, before billing has answered'}, from Calendar on today, a result for Friday lands on Friday; the next result with no date reads Sin fecha; after tapping Friday, it reads Friday’s date (D9)',
      (tester) async {
        final start = monday();
        final friday = plus(start, 4);
        final app = pro
            ? await _App.open(tester, pro: true, clock: start)
            : await openTyping(tester, clock: start);
        expect(find.text(es.todayAgenda), findsOneWidget);

        app.api.found = [
          dated('Médico', DateTime(friday.year, friday.month, friday.day, 17)),
        ];
        await captureWords(tester, 'Médico el viernes a las 17', pro: pro);
        await saveResult(tester);
        expect(find.text(selectedHeader(friday)), findsOneWidget);
        expect(
          tester
              .widget<TaskTile>(find.widgetWithText(TaskTile, 'Médico'))
              .color,
          Theme.of(
            tester.element(find.byType(NavigationBar)),
          ).colorScheme.primaryContainer,
        );

        // The next thing said has no date: no day is guessed for it.
        app.api.found = [_found('Comprar pan')];
        await captureWords(tester, 'comprar pan', pro: pro);
        expect(titleText(tester), 'Comprar pan');
        expect(dateLine(tester), es.noDate);
        expect(app.store.sessions.values.last.day, isNull);
        await keepResult(tester);

        // D9: a Friday the person taps is the day for undated words.
        await tapDay(tester, friday);
        expect(find.text(selectedHeader(friday)), findsOneWidget);
        app.api.found = [_found('Llamar a Juan')];
        await captureWords(tester, 'llamar a Juan', pro: pro);
        final calendar = tester.element(find.byType(CalendarScreen));
        expect(dateLine(tester), calendar.weekdayDate(friday));
        expect(app.store.sessions.values.last.day, friday);
        // A landing on the day already chosen keeps it chosen.
        await saveResult(tester);
        expect(find.text(selectedHeader(friday)), findsOneWidget);
        app.api.found = [_found('Regar las plantas')];
        await captureWords(tester, 'regar las plantas', pro: pro);
        expect(dateLine(tester), calendar.weekdayDate(friday));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-602: after picking Wednesday in the week strip, a result dated Friday lands on Friday; the next result with no date reads Sin fecha',
    (tester) async {
      final start = monday();
      final wednesday = plus(start, 2);
      final friday = plus(start, 4);
      final app = await _App.open(tester, pro: true, clock: start);
      await tapDay(tester, wednesday);
      expect(find.text(selectedHeader(wednesday)), findsOneWidget);
      app.api.found = [
        dated('Médico', DateTime(friday.year, friday.month, friday.day, 17)),
      ];
      await captureWords(tester, 'Médico el viernes a las 17', pro: true);
      await saveResult(tester);
      expect(find.text(selectedHeader(friday)), findsOneWidget);
      app.api.found = [_found('Comprar pan')];
      await captureWords(tester, 'comprar pan', pro: true);
      expect(dateLine(tester), es.noDate);
      expect(app.store.sessions.values.last.day, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-602: in the month view, a later day tapped there is the day a result with no date takes',
    (tester) async {
      final start = monday();
      // A later day in the same month as the Monday Calendar opens on.
      var later = plus(start, 9);
      if (later.month != start.month) later = plus(start, 2);
      final app = await _App.open(tester, pro: true, clock: start);
      await tester.tap(find.byKey(const ValueKey('calendar-format')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(es.month).last);
      await tester.pumpAndSettle();
      await tapDay(tester, later);
      expect(find.text(selectedHeader(later)), findsOneWidget);
      app.api.found = [_found('Comprar pan')];
      await captureWords(tester, 'comprar pan', pro: true);
      final calendar = tester.element(find.byType(CalendarScreen));
      expect(dateLine(tester), calendar.weekdayDate(later));
      expect(app.store.sessions.values.last.day, later);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Run 2026-10-18-commands, round 2 (P138: UX-911, UX-910, UX-1005,
  // UX-1011): entries from outside the app, for free accounts and Pro ----

  /// The captures still waiting under «Sin guardar».
  List<CaptureSession> waiting(_App app) => [
    for (final session in app.store.sessions.values)
      if (!session.terminal) session,
  ];

  testWidgets(
    'UX-911: a free account’s shared «Pedir cita en el dentista» opens «Nueva tarea» with that title and no capture sheet; the share’s capture waits until «Añadir tarea», and none after it',
    (tester) async {
      final share = _entry('share', text: 'Pedir cita en el dentista');
      final app = await _App.open(
        tester,
        pro: false,
        freeLeft: 5,
        entries: [share],
      );
      expect(find.byType(VoiceTaskScreen), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(TaskEditor), findsOneWidget);
      expect(find.text(es.newTask), findsWidgets);
      expect(titleText(tester), 'Pedir cita en el dentista');
      expect(app.api.requests, 0);
      expect(waiting(app), hasLength(1));
      expect(waiting(app).single.id, share['id']);
      expect(waiting(app).single.text, 'Pedir cita en el dentista');
      final save = find.byKey(const ValueKey('task-save'));
      expect(
        find.descendant(of: save, matching: find.text(es.addTask)),
        findsOneWidget,
      );
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsNothing);
      expect(app.tasks.titles(), ['Pedir cita en el dentista']);
      expect(waiting(app), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-910: with no free count from the server, the widget’s entry opens the form with «Dictar una tarea es parte de TaskFlow Pro…» and «Ver Pro» above the title; the text shortcut opens it without them',
    (tester) async {
      final app = await _App.open(
        tester,
        pro: false,
        entries: [_entry('voice')],
      );
      expect(find.byType(TaskEditor), findsOneWidget);
      final line = find.text(es.captureSpeakingIsPro);
      expect(line, findsOneWidget);
      final pro = find.widgetWithText(TextButton, es.voiceProAction);
      expect(pro, findsOneWidget);
      final title = find.byKey(const ValueKey('task-title'));
      expect(
        tester.getRect(line).bottom,
        lessThanOrEqualTo(tester.getRect(title).top),
      );
      expect(
        tester.getRect(pro).bottom,
        lessThanOrEqualTo(tester.getRect(title).top),
      );
      expect(app.speech.starts, 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsNothing);

      app.entries.queue.add(_entry('text'));
      app.entries.changed();
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsOneWidget);
      expect(find.text(es.captureSpeakingIsPro), findsNothing);
      expect(find.text(es.voiceProAction), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1011: with Pro and the app on Tareas, a task said from the widget’s entry and saved from the sheet switches to Calendario, with its day selected and its row lit',
    (tester) async {
      final app = await _App.open(tester, pro: true);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(es.tasks),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen).hitTestable(), findsWidgets);
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      app.api.found = [
        dated(
          'Llamar al médico',
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 17),
        ),
      ];
      app.entries.queue.add(_entry('voice'));
      app.entries.changed();
      await tester.pumpAndSettle();
      expect(find.byType(VoiceTaskScreen), findsOneWidget);
      expect(app.speech.starts, 1);
      app.speech.send('ready');
      app.speech.send('segment', text: 'Llamar al médico mañana a las 5');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(inSheet(find.widgetWithText(FilledButton, es.done)));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureResult), findsOneWidget);
      await saveResult(tester);
      expect(find.byType(CalendarScreen).hitTestable(), findsOneWidget);
      expect(find.text(selectedHeader(tomorrow)), findsOneWidget);
      final row = find.widgetWithText(TaskTile, 'Llamar al médico');
      expect(row.hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(row).color, litColor(tester));
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Run 2026-10-18-commands, b4 · P152 (UX-919, D3): «Guardar tal
  // cual» becomes «Guardar como tarea» ----

  AppLocalizations lang(String language) =>
      lookupAppLocalizations(Locale(language));
  const saveAsATask = {
    'es': 'Guardar como tarea',
    'en': 'Save as a task',
    'ca': 'Desa-ho com a tasca',
  };

  /// Pro, typing [text] in the sheet in [language], then Listo.
  Future<_App> typeAndSend(
    WidgetTester tester,
    String language,
    String text, {
    Size size = const Size(390, 844),
    Completer<void>? hold,
    Object? failure,
  }) async {
    final l = lang(language);
    final app = await _App.open(
      tester,
      pro: true,
      language: language,
      size: size,
    );
    app.api.hold = hold;
    app.api.failure = failure;
    await tester.tap(find.text(l.addTask).hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('capture-type-instead')));
    await tester.pumpAndSettle();
    await tester.enterText(words(), text);
    await tester.pumpAndSettle();
    final done = find.widgetWithText(FilledButton, l.done);
    await tester.ensureVisible(done);
    await tester.pump();
    await tester.tap(done);
    return app;
  }

  for (final language in ['es', 'en', 'ca']) {
    testWidgets(
      'UX-919 ($language): after 8 s of waiting the filled button reads «${saveAsATask[language]}», and after a failure the same label shows below Reintentar',
      (tester) async {
        final l = lang(language);
        expect(l.captureSaveAsWritten, saveAsATask[language]);
        final hold = Completer<void>();
        await typeAndSend(tester, language, 'llamar al médico', hold: hold);
        await frames(tester);
        expect(find.text(l.captureSaveAsWritten), findsNothing);
        await tester.pump(const Duration(milliseconds: 8200));
        expect(find.text(l.captureSlow), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, l.captureSaveAsWritten),
          findsOneWidget,
        );
        hold.complete();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();

        await typeAndSend(
          tester,
          language,
          'llamar al médico',
          failure: ApiException(503, 'Service unavailable'),
        );
        await tester.pumpAndSettle();
        final retry = find.widgetWithText(FilledButton, l.tryAgain);
        final save = find.widgetWithText(FilledButton, l.captureSaveAsWritten);
        expect(retry, findsOneWidget);
        expect(save, findsOneWidget);
        expect(
          tester.getRect(retry).bottom,
          lessThanOrEqualTo(tester.getRect(save).top),
          reason: 'below Reintentar',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'UX-919: no value in app_en.arb, app_es.arb or app_ca.arb says «tal cual», “as written” or «tal com està»',
    () {
      for (final language in ['en', 'es', 'ca']) {
        final arb =
            jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
                as Map<String, dynamic>;
        for (final MapEntry(:key, :value) in arb.entries) {
          if (key.startsWith('@') || value is! String) continue;
          final text = value.toLowerCase();
          for (final gone in ['tal cual', 'as written', 'tal com està']) {
            expect(text, isNot(contains(gone)), reason: '$language: $key');
          }
        }
      }
    },
  );

  // ---- UX loop 2026-10-19-app, round 1 · P167 (UX-1301, UX-1322): nothing
  // found, and the ring while understanding ----

  /// Pro, `Añadir tarea` listening, the recognizer hears [said], `Listo`.
  Future<_App> dictateTo(
    WidgetTester tester,
    String said, {
    List<Map<String, dynamic>> found = const [],
    Object? failure,
    Completer<void>? hold,
    bool settle = true,
  }) async {
    final app = await _App.open(tester, pro: true, size: const Size(360, 800));
    app.api.found = found;
    app.api.failure = failure;
    app.api.hold = hold;
    await tester.tap(find.text(es.addTask).hitTestable());
    await tester.pumpAndSettle();
    app.speech.send('ready');
    app.speech.send('segment', text: said);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(inSheet(find.widgetWithText(FilledButton, es.done)));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await frames(tester);
    }
    return app;
  }

  Finder sheetText(String text) => find.descendant(
    of: find.byType(VoiceTaskScreen),
    matching: find.text(text),
  );

  testWidgets(
    'UX-1301: ES 1x on 360x800, a dictation answered with no task and no command shows No he encontrado ninguna tarea…, one filled Volver a decirlo, Guardar como tarea as a text button under it, and no Reintentar',
    (tester) async {
      await dictateTo(tester, 'Bueno, a ver, no sé');
      expect(find.byType(CaptureResult), findsNothing);
      expect(sheetText(es.captureNoTasks), findsOneWidget);
      final filled = find.descendant(
        of: find.byType(VoiceTaskScreen),
        matching: find.byType(FilledButton),
      );
      expect(filled, findsOneWidget);
      expect(
        find.descendant(of: filled, matching: find.text(es.captureSayAgain)),
        findsOneWidget,
      );
      final save = find.descendant(
        of: find.byType(VoiceTaskScreen),
        matching: find.widgetWithText(TextButton, es.captureSaveAsWritten),
      );
      expect(save, findsOneWidget);
      expect(
        tester.getRect(save).top,
        greaterThanOrEqualTo(tester.getRect(filled).bottom),
      );
      expect(sheetText(es.tryAgain), findsNothing);
      expect(filled.hitTestable(), findsOneWidget);
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1301: that Volver a decirlo clears the words, starts listening on a new capture, and sends nothing until Listo',
    (tester) async {
      final app = await dictateTo(tester, 'Bueno, a ver, no sé');
      expect(app.api.requests, 1);
      expect(app.speech.starts, 1);
      final first = app.store.sessions.keys.single;
      await tester.tap(
        find.descendant(
          of: find.byType(VoiceTaskScreen),
          matching: find.widgetWithText(FilledButton, es.captureSayAgain),
        ),
      );
      await tester.pumpAndSettle();
      expect(sheetText('Bueno, a ver, no sé'), findsNothing);
      expect(sheetText(es.captureNoTasks), findsNothing);
      expect(app.speech.starts, 2, reason: 'listening again');
      expect(app.api.requests, 1, reason: 'nothing sent yet');
      app.speech.send('ready');
      app.speech.send('segment', text: 'Mañana, llamar al dentista');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(app.api.requests, 1, reason: 'still nothing sent before Listo');
      final fresh = app.store.sessions.keys.where((id) => id != first);
      expect(fresh, hasLength(1), reason: 'a new capture id');
      expect(app.store.sessions[first]!.terminal, isTrue);
      app.api.found = [_found('Llamar al dentista')];
      await tester.tap(inSheet(find.widgetWithText(FilledButton, es.done)));
      await tester.pumpAndSettle();
      expect(app.api.requests, 2);
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1301: Pro, typed words answered with nothing found keep the editable field and Listo, and no Volver a decirlo',
    (tester) async {
      final app = await _App.open(
        tester,
        pro: true,
        size: const Size(360, 800),
      );
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('capture-type-instead')));
      await tester.pumpAndSettle();
      await tester.enterText(words(), 'Bueno, a ver');
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.widgetWithText(FilledButton, es.done)));
      await tester.pumpAndSettle();
      expect(app.api.requests, 1);
      expect(sheetText(es.captureNoTasks), findsOneWidget);
      expect(words(), findsOneWidget);
      expect(tester.widget<TextField>(words()).readOnly, isFalse);
      expect(
        inSheet(find.widgetWithText(FilledButton, es.done)),
        findsOneWidget,
      );
      expect(sheetText(es.captureSayAgain), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (name, failure, line) in [
    (
      'offline',
      ApiException(0, 'Offline. Retry when connected.'),
      es.captureOffline,
    ),
    (
      'unavailable',
      ApiException(503, 'Service unavailable'),
      es.captureUnavailable,
    ),
  ]) {
    testWidgets(
      'UX-1301: an $name failure still shows Reintentar above Guardar como tarea, and no Volver a decirlo',
      (tester) async {
        await dictateTo(tester, 'Llamar al médico mañana', failure: failure);
        expect(
          find.descendant(
            of: find.byType(VoiceTaskScreen),
            matching: find.textContaining(line),
          ),
          findsOneWidget,
        );
        final retry = inSheet(find.widgetWithText(FilledButton, es.tryAgain));
        final save = inSheet(
          find.widgetWithText(FilledButton, es.captureSaveAsWritten),
        );
        expect(retry, findsOneWidget);
        expect(save, findsOneWidget);
        expect(
          tester.getRect(retry).bottom,
          lessThanOrEqualTo(tester.getRect(save).top),
        );
        expect(sheetText(es.captureSayAgain), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-1322: while Entendiendo…, the ring shows the spinner and no microphone; while listening it shows the microphone',
    (tester) async {
      final hold = Completer<void>();
      final app = await _App.open(
        tester,
        pro: true,
        size: const Size(360, 800),
      );
      app.api.hold = hold;
      app.api.found = [_found('Comprar pan')];
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      app.speech.send('ready');
      app.speech.send('segment', text: 'Comprar pan');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final mic = find.descendant(
        of: find.byType(VoiceTaskScreen),
        matching: find.byIcon(Icons.mic_none_rounded),
      );
      expect(mic, findsOneWidget, reason: 'listening shows the microphone');
      await tester.tap(inSheet(find.widgetWithText(FilledButton, es.done)));
      await frames(tester);
      expect(sheetText(es.captureUnderstanding), findsOneWidget);
      final spinner = find.descendant(
        of: find.byType(VoiceTaskScreen),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is CircularProgressIndicator && widget.value == null,
        ),
      );
      expect(spinner, findsOneWidget);
      expect(mic, findsNothing);
      hold.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- UX loop 2026-10-19-app, round 1 · P171 (UX-1310, UX-1313, UX-1321)
  // and P173 (UX-1307, UX-1318): one labelled layout for the controls, the
  // words field, and errors that say what to do ----

  /// The controls under the words while listening, in the sheet.
  ({Rect done, Rect cancel, Rect type, Finder typeButton}) listeningControls(
    WidgetTester tester, {
    required bool pro,
  }) {
    final done = inSheet(find.widgetWithText(FilledButton, es.done));
    expect(done, findsOneWidget, reason: 'one filled Listo');
    final cancel = inSheet(find.widgetWithText(TextButton, es.cancel));
    expect(cancel, findsOneWidget);
    final type = inSheet(
      find.byKey(
        ValueKey(pro ? 'capture-type-instead' : 'capture-fill-by-hand'),
      ),
    );
    expect(type, findsOneWidget, reason: 'Escribir, named');
    return (
      done: tester.getRect(done),
      cancel: tester.getRect(cancel),
      type: tester.getRect(type),
      typeButton: type,
    );
  }

  for (final pro in [true, false]) {
    testWidgets(
      'UX-1310: ES 1× on 360×800, ${pro ? 'a Pro account' : 'a free account with dictations left'} listening: one full-width Listo at least 312 dp wide; under it Cancelar at the start and Escribir with the keyboard icon at the end; no icon-only keyboard button',
      (tester) async {
        final app = await _App.open(
          tester,
          pro: pro,
          freeLeft: pro ? null : 5,
          size: const Size(360, 800),
        );
        await tester.tap(find.text(es.addTask).hitTestable());
        await tester.pumpAndSettle();
        expect(app.speech.starts, 1, reason: 'it opens on the mic');
        app.speech.send('ready');
        app.speech.send('segment', text: 'Comprar pan');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final c = listeningControls(tester, pro: pro);
        expect(c.done.width, greaterThanOrEqualTo(312));
        // Under Listo, on one row: Cancelar at the start, Escribir at the end.
        expect(c.cancel.top, greaterThanOrEqualTo(c.done.bottom));
        expect(c.type.top, greaterThanOrEqualTo(c.done.bottom));
        expect(
          c.cancel.top - c.done.bottom,
          greaterThanOrEqualTo(8),
          reason: 'UX-1311: not touching Listo',
        );
        expect(
          c.cancel.center.dy,
          moreOrLessEquals(c.type.center.dy, epsilon: 1),
        );
        expect(c.cancel.left, moreOrLessEquals(c.done.left, epsilon: 1));
        expect(c.type.right, moreOrLessEquals(c.done.right, epsilon: 1));
        expect(
          find.descendant(
            of: c.typeButton,
            matching: find.text(es.captureTypeInstead),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: c.typeButton,
            matching: find.byIcon(Icons.keyboard_outlined),
          ),
          findsOneWidget,
        );
        expect(
          inSheet(find.widgetWithIcon(IconButton, Icons.keyboard_outlined)),
          findsNothing,
        );
        expect(inSheet(find.byTooltip(es.captureTypeInstead)), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('UX-1310: Pro, Escribir under Listo still types in the sheet', (
    tester,
  ) async {
    await _App.open(tester, pro: true, size: const Size(360, 800));
    await tester.tap(find.text(es.addTask).hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('capture-type-instead')));
    await tester.pumpAndSettle();
    expect(words(), findsOneWidget, reason: 'Pro types in the sheet');
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'UX-1321: after typing, TalkBack names the words field «Tus palabras»; while empty, the example hint still shows',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _App.open(tester, pro: true, size: const Size(360, 800));
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('capture-type-instead')));
      await tester.pumpAndSettle();
      // Empty: the example shows (UX-1313 keeps it).
      final hint = inSheet(find.text(es.examplePlan));
      expect(hint, findsOneWidget);
      expect(tester.getSize(hint).height, greaterThan(0));
      await tester.enterText(words(), 'Comprar pan');
      await tester.pumpAndSettle();
      expect(es.captureYourWords, 'Tus palabras');
      final field = tester
          .getSemantics(find.byType(EditableText))
          .getSemanticsData();
      expect(field.flagsCollection.isTextField, isTrue);
      expect(field.label, contains(es.captureYourWords));
      expect(field.value, 'Comprar pan');
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'UX-1307: a 429 with Retry-After 30 is tooFast, Retry-After 3600 is allowance, no Retry-After is unavailable',
    () {
      expect(
        CaptureProblem.from(
          ApiException(429, 'Too many', null, const Duration(seconds: 30)),
        ),
        CaptureProblem.tooFast,
      );
      expect(
        CaptureProblem.from(
          ApiException(429, 'Too many', null, const Duration(seconds: 120)),
        ),
        CaptureProblem.tooFast,
        reason: '120 s or less',
      );
      expect(
        CaptureProblem.from(
          ApiException(429, 'Too many', null, const Duration(seconds: 3600)),
        ),
        CaptureProblem.allowance,
      );
      expect(
        CaptureProblem.from(ApiException(429, 'Too many')),
        CaptureProblem.unavailable,
      );
      // A 402 (free dictations used up) is unchanged.
      expect(
        CaptureProblem.from(ApiException(402, 'Payment required')),
        isNot(anyOf(CaptureProblem.tooFast, CaptureProblem.allowance)),
      );
    },
  );

  for (final (name, wait, expected, filled) in [
    (
      'Retry-After 30',
      const Duration(seconds: 30),
      'Has dictado muchas veces seguidas. Espera un minuto y toca Reintentar.',
      es.tryAgain,
    ),
    (
      'Retry-After 3600',
      const Duration(seconds: 3600),
      'Has llegado al límite de dictados de hoy. Toca Guardar como tarea o inténtalo mañana.',
      es.captureSaveAsWritten,
    ),
  ]) {
    testWidgets(
      'UX-1307: after a 429 with $name the sheet says «$expected», and the button it names is there',
      (tester) async {
        final app = await typeAndSend(
          tester,
          'es',
          'Comprar pan',
          failure: ApiException(429, 'Too many requests', null, wait),
        );
        await tester.pumpAndSettle();
        final banner = find.byType(MessageBanner);
        expect(banner, findsOneWidget);
        expect(
          find.descendant(of: banner, matching: find.text(expected)),
          findsOneWidget,
        );
        expect(
          inSheet(find.widgetWithText(FilledButton, filled)),
          findsOneWidget,
        );
        if (filled == es.tryAgain) {
          // Reintentar works once the minute has passed.
          app.api.failure = null;
          app.api.found = [_found('Comprar pan')];
          await tester.tap(
            inSheet(find.widgetWithText(FilledButton, es.tryAgain)),
          );
          await tester.pumpAndSettle();
          expect(find.byType(CaptureResult), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'UX-1307: after a 429 with no Retry-After (the assistant’s own quota) the sheet says the assistant is unavailable, not the daily limit',
    (tester) async {
      await typeAndSend(
        tester,
        'es',
        'Comprar pan',
        failure: ApiException(429, 'Too many requests'),
      );
      await tester.pumpAndSettle();
      expect(find.text(es.captureUnavailable), findsOneWidget);
      expect(find.text(es.captureAllowance), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // UX loop 2026-10-19-app, batch b2 round 2 · P200 (UX-1630): with words,
  // today's limit is unchanged; only a recording with no words reads the
  // recording's line.
  testWidgets(
    'UX-1630: typed words refused by today’s limit (Retry-After 3600) still read «Toca Guardar como tarea…», with Guardar como tarea and Reintentar',
    (tester) async {
      await typeAndSend(
        tester,
        'es',
        'Comprar pan',
        failure: ApiException(
          429,
          'Too many requests',
          null,
          const Duration(seconds: 3600),
        ),
      );
      await tester.pumpAndSettle();
      final banner = find.byType(MessageBanner);
      expect(
        find.descendant(
          of: banner,
          matching: find.text(
            'Has llegado al límite de dictados de hoy. Toca Guardar como tarea o inténtalo mañana.',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(es.captureAllowanceRecording), findsNothing);
      expect(
        inSheet(find.widgetWithText(FilledButton, es.captureSaveAsWritten)),
        findsOneWidget,
      );
      expect(inSheet(find.text(es.tryAgain)), findsOneWidget);
      expect(
        inSheet(find.byKey(const ValueKey('capture-close'))),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'UX-1318: rare errors say what to do; a choice the server can’t take and a busy microphone read the generic message',
    () {
      for (final l in [en, es, ca]) {
        for (final problem in [
          CaptureProblem.unsupportedKind,
          CaptureProblem.speechBusy,
        ]) {
          expect(
            captureProblemText(l, problem),
            l.captureFailed,
            reason: '${l.localeName}: $problem',
          );
        }
        expect(
          captureProblemText(l, CaptureProblem.saveFailed),
          l.captureSaveFailed,
        );
        expect(
          captureProblemText(l, CaptureProblem.stopFailed),
          l.captureStopFailed,
        );
        expect(
          captureProblemText(l, CaptureProblem.incompleteAudio),
          l.captureIncompleteAudio,
        );
        expect(
          captureProblemText(l, CaptureProblem.tooLarge),
          l.captureTooLarge,
        );
        expect(captureProblemText(l, CaptureProblem.tooFast), l.captureTooFast);
      }
      expect(
        es.captureSaveFailed,
        'No se ha podido añadir. Tus palabras siguen aquí; vuelve a intentarlo.',
      );
      expect(
        es.captureStopFailed,
        'No he podido terminar de escuchar. Lo que dijiste antes se conserva.',
      );
      expect(
        es.captureIncompleteAudio,
        'Esta grabación no se puede usar. Descártala y vuelve a dictarla.',
      );
      expect(
        es.captureTooLarge,
        'Esta grabación es demasiado larga. Descártala y dicta algo más corto.',
      );
    },
  );

  testWidgets(
    'UX-1318: ES, with the phone’s zone unavailable, the sheet’s banner ends «… Las tareas nuevas usarán Madrid.», not «Europe/Madrid»',
    (tester) async {
      platform.setMockMethodCallHandler(
        timezone,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      await _App.open(tester, pro: true, size: const Size(360, 800));
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      final banner = inSheet(find.text(es.timezoneFallback('Madrid')));
      expect(banner, findsOneWidget);
      expect(
        es.timezoneFallback('Madrid'),
        endsWith('Las tareas nuevas usarán Madrid.'),
      );
      expect(inSheet(find.textContaining('Europe/Madrid')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // Last in this file: it loads Manrope, which the tests after it would
  // otherwise draw with.
  for (final language in ['es', 'ca']) {
    testWidgets(
      'UX-919 ($language, 2× on 320×640): the slow state’s «${saveAsATask[language]}» shows whole, on screen, with no clipped text',
      (tester) async {
        await (FontLoader(
          'Manrope',
        )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final l = lang(language);
        final hold = Completer<void>();
        await typeAndSend(
          tester,
          language,
          'llamar al médico',
          size: const Size(320, 640),
          hold: hold,
        );
        await frames(tester);
        await tester.pump(const Duration(milliseconds: 8200));
        final save = find.widgetWithText(FilledButton, l.captureSaveAsWritten);
        expect(save, findsOneWidget);
        await tester.ensureVisible(save);
        await tester.pump(const Duration(milliseconds: 400));
        final rect = tester.getRect(save);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320.5));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(640.5));
        expect(save.hitTestable(), findsOneWidget);
        final label = find.descendant(
          of: save,
          matching: find.text(l.captureSaveAsWritten),
        );
        expect(label, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: label, matching: find.byType(RichText)),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        final text = tester.getRect(label);
        expect(text.left, greaterThanOrEqualTo(rect.left - 0.5));
        expect(text.right, lessThanOrEqualTo(rect.right + 0.5));
        expect(tester.takeException(), isNull, reason: 'no overflow');
        hold.complete();
        await tester.pumpAndSettle();
      },
    );
  }

  // ---- UX loop 2026-10-19-app, round 1 · P171, with Manrope (loaded above)

  /// [paragraph] is on one line: as high as its text laid out unbounded.
  void expectOneLine(RenderParagraph paragraph, String reason) {
    final oneLine = TextPainter(
      text: paragraph.text,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      locale: paragraph.locale,
      strutStyle: paragraph.strutStyle,
      textHeightBehavior: paragraph.textHeightBehavior,
    )..layout();
    expect(
      paragraph.size.height,
      moreOrLessEquals(oneLine.height, epsilon: 0.5),
      reason:
          '$reason: one line is ${oneLine.height} high, it is '
          '${paragraph.size.height} (one-line width ${oneLine.width} in '
          '${paragraph.size.width})',
    );
    oneLine.dispose();
  }

  testWidgets(
    'UX-1310: ES 1× on 360×800, Pro, the slow state: «Guardar como tarea» is on one line',
    (tester) async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      final hold = Completer<void>();
      await typeAndSend(
        tester,
        'es',
        'llamar al médico',
        size: const Size(360, 800),
        hold: hold,
      );
      await frames(tester);
      await tester.pump(const Duration(milliseconds: 8200));
      expect(find.text(es.captureSlow), findsOneWidget);
      final save = inSheet(
        find.widgetWithText(FilledButton, es.captureSaveAsWritten),
      );
      expect(save, findsOneWidget);
      final label = find.descendant(
        of: save,
        matching: find.text(es.captureSaveAsWritten),
      );
      expectOneLine(
        tester.renderObject<RenderParagraph>(
          find.descendant(of: label, matching: find.byType(RichText)),
        ),
        'Guardar como tarea',
      );
      expect(tester.takeException(), isNull);
      hold.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'UX-1313: ES 2× on 360×800, three typed lines: the first typed line is visible below the sheet’s top edge, and the field is about as tall as its text',
    (tester) async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _App.open(tester, pro: true, size: const Size(360, 800));
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      final type = find.byKey(const ValueKey('capture-type-instead'));
      await tester.ensureVisible(type);
      await tester.pumpAndSettle();
      await tester.tap(type);
      await tester.pumpAndSettle();
      await tester.enterText(
        words(),
        'Comprar pan\nLlamar a Ana\nRecoger el paquete',
      );
      await tester.pumpAndSettle();
      final sheet = tester.getRect(find.byType(BottomSheet));
      final editable = find.descendant(
        of: words(),
        matching: find.byType(EditableText),
      );
      final text = tester.getRect(editable);
      expect(
        text.top,
        greaterThanOrEqualTo(sheet.top),
        reason: 'the first line is not under the sheet’s top edge',
      );
      // The first line itself is what a tap there reaches.
      final firstLine = Offset(text.left + 12, text.top + 12);
      final hit = tester.hitTestOnBinding(firstLine);
      expect(
        hit.path.any((entry) => entry.target is RenderEditable),
        isTrue,
        reason: 'the first typed line is in view at $firstLine',
      );
      final field = tester.getRect(words());
      expect(
        field.height,
        lessThanOrEqualTo(text.height + 48),
        reason:
            'the field is about as tall as its text, not its hidden '
            'example (field ${field.height}, text ${text.height})',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Map<String, dynamic> _found(String title) => {
  'title': title,
  'due_date': null,
  'scheduled_date': null,
  'priority': 1,
  'notes': '',
  'questions': [],
};

var _entries = 0;

/// An entry from outside the app, as Android hands it over.
Map<String, Object> _entry(String kind, {String text = ''}) => {
  'id': '00000000-0000-4000-8000-${(++_entries).toString().padLeft(12, '0')}',
  'kind': kind,
  'text': text,
  'capturedAt': DateTime.now().millisecondsSinceEpoch,
};

/// The app in Spanish (or [language]) with a 24-hour clock, on Calendar,
/// with capture answered by [api], kept in [store], and entries from outside
/// the app in [entries].
class _App {
  _App(
    this.container,
    this.store,
    this.api,
    this.tasks,
    this.speech,
    this.entries,
  );
  final ProviderContainer container;
  final _Captures store;
  final _Api api;
  final _Tasks tasks;
  final _Speech speech;
  final _Entries entries;

  /// [freeLeft] gives the account this month's free dictations left, as the
  /// server counts them; without it the server sends no count.
  static Future<_App> open(
    WidgetTester tester, {
    required bool pro,
    bool billingLoading = false,
    int? freeLeft,
    DateTime? clock,
    String language = 'es',
    ClockFormat clockFormat = ClockFormat.twentyFour,
    List<TaskListInfo> projects = const [],
    List<Map<String, Object>> entries = const [],
    bool settle = true,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = _Captures();
    final api = _Api();
    final tasks = _Tasks();
    final speech = _Speech();
    final outside = _Entries(tester, [...entries]);
    final container = ProviderContainer(
      overrides: [
        invitationLinkProvider.overrideWith(
          (ref) => InvitationLinks(listen: false),
        ),
        hasProProvider.overrideWithValue(pro),
        billingLoadingProvider.overrideWithValue(billingLoading),
        authProvider.overrideWith(
          (ref) => freeLeft == null
              ? SignedInFixtureAuth(api)
              : _CountedAuth(api, freeLeft, clock: clock),
        ),
        attachmentEntriesProvider.overrideWith((ref, taskId) async => []),
        regionalStoreProvider.overrideWithValue(
          MemoryRegionalStore(
            RegionalPreferences(
              language: language,
              clock: clockFormat,
              weekStart: 1,
            ),
          ),
        ),
        taskListsProvider.overrideWith((ref) async => projects),
        apiClientProvider.overrideWithValue(api),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => tasks),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        captureStoreProvider.overrideWithValue(store),
        nativeSpeechProvider.overrideWithValue(speech),
        captureRecorderFactoryProvider.overrideWithValue(SilentRecorder.new),
        captureEntriesProvider.overrideWithValue(outside.entries),
        if (clock != null) calendarClockProvider.overrideWithValue(() => clock),
      ],
    );
    store.tasks = tasks;
    addTearDown(() {
      container.dispose();
      api.close();
      outside.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    Future<void> wait() async {
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
    }

    await wait();
    // The fixture's account is restored before the first frame, so the
    // entries waiting at launch are announced the way a new one is.
    if (entries.isNotEmpty) {
      outside.changed();
      await wait();
    }
    return _App(container, store, api, tasks, speech, outside);
  }
}

/// The fixture's account, with [left] free dictations this month: the month
/// of the app's [clock], so a test whose clock is days ahead never sees the
/// count reset to a whole new month.
class _CountedAuth extends AuthNotifier {
  _CountedAuth(super.api, this.left, {this.clock});
  final int left;
  final DateTime? clock;
  @override
  Future<void> restore() async {
    final now = (clock ?? DateTime.now()).toUtc();
    state = AuthState(
      account: Account.fromJson({
        'id': 1,
        'email': 'design@example.invalid',
        'timezone': 'Europe/Madrid',
        'free_voice': {
          'limit': 10,
          'left': left,
          'resets_at': DateTime.utc(now.year, now.month + 1).toIso8601String(),
        },
      }),
    );
  }
}

/// Android's queue of entries: the widget, the shortcuts and share.
class _Entries {
  _Entries(WidgetTester tester, this.queue) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'pending') return [...queue];
      if (call.method == 'acknowledge') {
        final id = (call.arguments as Map)['id'];
        acknowledged.add(id as String);
        queue.removeWhere((entry) => entry['id'] == id);
      }
      return null;
    });
    _messenger = messenger;
    entries = CaptureEntries(channel: channel);
  }
  static const channel = MethodChannel('test/capture-sheet-entries');
  final List<Map<String, Object>> queue;
  final acknowledged = <String>[];
  late final CaptureEntries entries;
  late final TestDefaultBinaryMessenger _messenger;

  /// Android says a new entry arrived.
  void changed() => _messenger.handlePlatformMessage(
    channel.name,
    channel.codec.encodeMethodCall(const MethodCall('changed')),
    (_) {},
  );

  void close() {
    _messenger.setMockMethodCallHandler(channel, null);
    entries.dispose();
  }
}

/// The assistant: returns [found], after [hold] if set, or fails with
/// [failure]. Counts what it was asked.
class _Api extends OfflineApiClient {
  List<Map<String, dynamic>> found = [];
  Completer<void>? hold;
  Object? failure;
  int requests = 0;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
    bool retry = true,
  }) async {
    if (!path.startsWith('ai/')) {
      throw ApiException(0, 'Offline. Retry when connected.');
    }
    requests++;
    final gate = hold;
    if (gate != null) await gate.future;
    final error = failure;
    if (error != null) throw error;
    return {'transcript': data?['text'] ?? '', 'tasks': found};
  }
}

/// Tasks in memory, numbered as they are added.
class _Tasks extends DesignTaskNotifier {
  int _next = 100;
  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = const AsyncData([]);
  }

  List<String> titles() => state.requireValue.map((t) => t.title).toList();

  int add(Task task) {
    final id = _next++;
    state = AsyncData([...state.requireValue, task.copyWith(id: id)]);
    return id;
  }
}

/// Every capture in memory, by id. The pending list is every one not saved
/// or discarded, empty or not, so nothing hides a record the sheet wrote.
class _Captures extends CaptureStore {
  _Captures() : super(TaskDatabase());
  final sessions = <String, CaptureSession>{};
  final accepted = <String>[];
  _Tasks? tasks;
  var _next = 0;

  @override
  Future<CaptureSession> create(
    String ownerKey,
    String timezone, {
    String text = '',
    DateTime? now,
    bool audio = false,
    String kind = 'task',
    String? projectId,
    String? source,
    DateTime? day,
    String? id,
    String? language,
  }) async {
    final session = CaptureSession(
      language: language,
      id: id ?? 'capture-${_next++}',
      ownerKey: ownerKey,
      timezone: timezone,
      capturedAt: (now ?? DateTime.now()).toUtc(),
      text: text,
      kind: kind,
      projectId: projectId,
      source: source,
      day: day,
    );
    return sessions[session.id] = session;
  }

  @override
  Future<CaptureSession?> acceptEntry(
    String id,
    String ownerKey,
    String timezone, {
    required String text,
    required DateTime capturedAt,
  }) async {
    accepted.add(id);
    return sessions[id] ??= CaptureSession(
      id: id,
      ownerKey: ownerKey,
      timezone: timezone,
      text: text,
      capturedAt: capturedAt.toUtc(),
      source: 'shared',
    );
  }

  @override
  Future<void> update(CaptureSession value) async {
    if (sessions[value.id]?.terminal ?? false) {
      throw StateError('This capture is no longer available.');
    }
    sessions[value.id] = value;
  }

  @override
  Future<CaptureSession?> read(String id, String ownerKey) async =>
      sessions[id];
  @override
  Future<List<CaptureSession>> pending(String ownerKey) async => [
    for (final session in sessions.values)
      if (!session.terminal) session,
  ];
  @override
  Future<void> cleanFinished(String ownerKey) async {}
  @override
  Future<void> discard(String id, String ownerKey) async {
    final session = sessions[id];
    if (session != null) sessions[id] = session.copyWith(status: 'discarded');
  }

  @override
  Future<CaptureSession> saveReady(
    String id,
    String ownerKey,
    Set<String> draftIds,
  ) async {
    final current = sessions[id]!;
    final drafts = [
      for (final draft in current.drafts)
        draftIds.contains(draft.id)
            ? draft.copyWith(savedTaskId: tasks!.add(draft.task))
            : draft,
    ];
    return sessions[id] = current.copyWith(
      status: drafts.any((d) => d.pending) ? 'ready' : 'saved',
      drafts: drafts,
    );
  }

  @override
  Future<CaptureSession?> undoSave(
    CaptureSession before,
    Map<String, int> savedIds,
  ) async {
    for (final id in savedIds.values) {
      await tasks!.deleteTask(id);
    }
    return sessions[before.id] = before;
  }
}

/// The phone's recognizer: listening until stopped; the test sends what it
/// hears.
class _Speech extends NativeSpeech {
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  int starts = 0;
  int? _run;
  @override
  Future<SpeechCapability> capability({String? language}) async =>
      const SpeechCapability(
        onDevice: true,
        language: 'es-ES',
        languageInstalled: true,
      );
  @override
  Stream<SpeechEvent> get events => _events.stream;
  @override
  Future<SpeechPermission> permission() async => SpeechPermission.granted;
  @override
  Future<void> start(
    int id,
    String language, {
    List<String> hints = const [],
  }) async {
    starts++;
    _run = id;
  }

  void send(String kind, {String? text, String? error}) =>
      _events.add(SpeechEvent(_run!, kind, text: text, error: error));
  @override
  Future<void> stop(int id) async {
    if (_run != null) send('ended');
  }

  @override
  Future<void> cancel(int id) async {}
}
