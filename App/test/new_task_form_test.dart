// 2026-10-18 (later), DECISIONS.md: free accounts create tasks with a form.
// The task form in create mode (`/newTask`): title first with the keyboard
// up, then the day (Hoy, Mañana, Elegir día) and an optional time, the
// rest under Más detalles. Saving lands as a capture does; Back with a title
// saves (D12); it works offline; Pro keeps the capture sheet.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/day_timeline_screen.dart';
import 'package:agenda/screens/edit_task_screen.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/widgets/checklist_editor.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/widgets/task_actions.dart';
import 'package:agenda/widgets/task_assignment_picker.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'support/capture_fixtures.dart'
    show ListeningSpeech, MemoryCaptures, QuietSpeech, SilentRecorder;
import 'support/design_fixtures.dart';
import 'support/reminder_fixtures.dart';

final en = lookupAppLocalizations(const Locale('en'));
final es = lookupAppLocalizations(const Locale('es'));
final ca = lookupAppLocalizations(const Locale('ca'));
AppLocalizations strings(String language) =>
    lookupAppLocalizations(Locale(language));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  const timezone = MethodChannel('flutter_timezone');
  setUp(() {
    // Messages stay for 10 s, the phone's accessibility timeout.
    platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
    platform.setMockMethodCallHandler(timezone, (_) async => 'Europe/Madrid');
  });
  tearDown(() {
    platform.setMockMethodCallHandler(timeoutChannel, null);
    platform.setMockMethodCallHandler(timezone, null);
  });

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);

  /// A Monday at 09:00, a week or more ahead: its Thursday is never Hoy or
  /// Mañana on the phone's own clock.
  DateTime monday() {
    var day = DateTime(now.year, now.month, now.day + 7);
    while (day.weekday != DateTime.monday) {
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return DateTime(day.year, day.month, day.day, 9);
  }

  DateTime plus(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

  Finder title() => find.byKey(const ValueKey('task-title'));
  Finder save() => find.byKey(const ValueKey('task-save'));
  Finder chip(String key) => find.byKey(ValueKey(key));
  Finder row(String title) => find.widgetWithText(TaskTile, title);

  /// The highlight a just-saved row is drawn with.
  Color lit(WidgetTester tester) => Theme.of(
    tester.element(find.byType(Scaffold).hitTestable().first),
  ).colorScheme.primaryContainer;
  bool focused(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(of: title(), matching: find.byType(EditableText)),
      )
      .focusNode
      .hasFocus;
  bool selected(WidgetTester tester, String key) =>
      tester.widget<ChoiceChip>(chip(key)).selected;
  String buttonLabel(WidgetTester tester) =>
      (tester
                  .widget<Text>(
                    find.descendant(of: save(), matching: find.byType(Text)),
                  )
                  .data ??
              '')
          .trim();

  /// `Nueva tarea` on the screen in front: the form opens.
  Future<void> openForm(WidgetTester tester, [AppLocalizations? l]) async {
    await tester.tap(find.text((l ?? es).newTask).hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditor), findsOneWidget);
  }

  Future<void> typeTitle(WidgetTester tester, String words) async {
    await tester.enterText(title(), words);
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(save());
    await tester.tap(save());
    await tester.pumpAndSettle();
  }

  Future<void> showDetails(WidgetTester tester) async {
    final more = find.byKey(const ValueKey('task-more-details'));
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
  }

  Future<void> openTasksTab(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(es.tasks),
      ),
    );
    await tester.pumpAndSettle();
  }

  // ---- The form ----

  testWidgets(
    'a free account’s Nueva tarea opens the form: Nueva tarea above, the title first and focused, then Hoy · Mañana · Elegir día with none chosen, no time until a day, Más detalles closed, and Añadir tarea',
    (tester) async {
      final app = await _App.open(tester);
      expect(
        find.descendant(
          of: find.widgetWithText(FilledButton, es.newTask),
          matching: find.byIcon(Icons.add_rounded),
        ),
        findsOneWidget,
      );
      await openForm(tester);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(es.newTask),
        ),
        findsOneWidget,
      );
      expect(focused(tester), isTrue, reason: 'the keyboard comes up');
      // The title first: nothing of the form sits above it.
      final top = tester.getRect(title()).top;
      for (final key in [
        'new-task-today',
        'new-task-tomorrow',
        'new-task-pick-day',
        'task-more-details',
      ]) {
        expect(tester.getRect(chip(key)).top, greaterThan(top), reason: key);
      }
      expect(find.widgetWithText(ChoiceChip, es.today), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, es.tomorrow), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, es.pickDay), findsOneWidget);
      expect(es.pickDay, 'Elegir día');
      for (final key in [
        'new-task-today',
        'new-task-tomorrow',
        'new-task-pick-day',
      ]) {
        expect(selected(tester, key), isFalse, reason: key);
      }
      expect(chip('new-task-time'), findsNothing, reason: 'no day yet');
      // Más detalles holds everything else.
      expect(find.byKey(const ValueKey('task-notes')), findsNothing);
      expect(find.byType(ReminderControl), findsNothing);
      expect(find.byKey(const ValueKey('task-repeat')), findsNothing);
      expect(find.text(es.addAttachment), findsNothing);
      expect(find.byKey(const ValueKey('task-date')), findsNothing);
      expect(find.text(es.moreDetails), findsOneWidget);
      expect(buttonLabel(tester), es.captureAddTask);
      expect(app.speech.starts, 0, reason: 'nothing listens');
      expect(find.byType(VoiceTaskScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Mañana and a time: Añadir al calendario saves it on the phone, closes the form, selects Mañana on Calendar, lights the row and says Añadida al … with Deshacer; Deshacer removes it',
    (tester) async {
      final app = await _App.open(tester);
      await openForm(tester);
      await typeTitle(tester, 'Llamar al médico');
      await tester.tap(chip('new-task-tomorrow'));
      await tester.pumpAndSettle();
      expect(selected(tester, 'new-task-tomorrow'), isTrue);
      expect(buttonLabel(tester), es.captureAddToCalendar);
      // The time, once there is a day: the phone's time picker.
      expect(find.widgetWithText(ActionChip, es.addTime), findsOneWidget);
      await tester.tap(chip('new-task-time'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      final ok = MaterialLocalizations.of(
        tester.element(find.byType(TimePickerDialog)),
      ).okButtonLabel;
      await tester.tap(find.text(ok));
      await tester.pumpAndSettle();
      final hour = (TimeOfDay.now().hour + 1) % 24;
      final at = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour);
      final form = tester.element(find.byType(TaskEditor));
      expect(
        find.widgetWithText(InputChip, form.clockTime(at)),
        findsOneWidget,
      );
      await tapSave(tester);

      expect(find.byType(TaskEditor), findsNothing);
      final saved = app.tasks.state.requireValue.single;
      expect(saved.title, 'Llamar al médico');
      expect(saved.dueDate, at);
      expect(saved.hasTime, isTrue);
      expect(saved.kind, 'task');
      expect(
        find.text(DateFormat.MMMMEEEEd('es').format(tomorrow)),
        findsOneWidget,
        reason: 'Calendar shows Mañana',
      );
      expect(row('Llamar al médico').hitTestable(), findsOneWidget);
      expect(
        tester.widget<TaskTile>(row('Llamar al médico')).color,
        lit(tester),
      );
      final calendar = tester.element(find.byType(CalendarScreen));
      expect(
        find.text(es.taskAddedOn(calendar.weekdayDate(tomorrow))),
        findsOneWidget,
      );
      expect(find.text(es.undo), findsOneWidget);
      expect(app.api.drafts, 0, reason: 'nothing went to the assistant');

      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      expect(app.tasks.state.requireValue, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'with no day chosen it is added with no date: Añadida sin fecha, and Calendar lights the Sin fecha row; the words are only a title, never read for a date',
    (tester) async {
      final app = await _App.open(tester);
      await openForm(tester);
      await typeTitle(tester, 'Comprar pan mañana a las 5');
      await tapSave(tester);
      final saved = app.tasks.state.requireValue.single;
      expect(saved.title, 'Comprar pan mañana a las 5');
      expect(saved.dueDate, isNull);
      expect(saved.deadline, isNull);
      expect(find.text(es.taskSavedInbox), findsOneWidget);
      final inbox = find.byKey(const ValueKey('calendar-inbox'));
      expect(inbox, findsOneWidget);
      final box = tester.widget<DecoratedBox>(
        find.ancestor(of: inbox, matching: find.byType(DecoratedBox)).first,
      );
      expect((box.decoration as BoxDecoration).color, lit(tester));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Hoy, then Hoy again, takes the day away; a time stays with the day when Mañana replaces Hoy, and its ✕ (Quitar hora) takes the time away',
    (tester) async {
      await _App.open(tester);
      await openForm(tester);
      await tester.tap(chip('new-task-today'));
      await tester.pumpAndSettle();
      expect(selected(tester, 'new-task-today'), isTrue);
      await tester.tap(chip('new-task-today'));
      await tester.pumpAndSettle();
      expect(selected(tester, 'new-task-today'), isFalse);
      expect(chip('new-task-time'), findsNothing);
      expect(buttonLabel(tester), es.captureAddTask);

      await tester.tap(chip('new-task-today'));
      await tester.pumpAndSettle();
      await tester.tap(chip('new-task-time'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          MaterialLocalizations.of(
            tester.element(find.byType(TimePickerDialog)),
          ).okButtonLabel,
        ),
      );
      await tester.pumpAndSettle();
      final hour = (TimeOfDay.now().hour + 1) % 24;
      final form = tester.element(find.byType(TaskEditor));
      final time = form.clockTime(DateTime(2030, 1, 1, hour));
      expect(find.widgetWithText(InputChip, time), findsOneWidget);
      await tester.tap(chip('new-task-tomorrow'));
      await tester.pumpAndSettle();
      expect(selected(tester, 'new-task-tomorrow'), isTrue);
      expect(find.widgetWithText(InputChip, time), findsOneWidget);
      expect(es.removeTime, 'Quitar hora');
      await tester.tap(find.byTooltip(es.removeTime));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ActionChip, es.addTime), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Elegir día opens the date sheet; its Mañana applies at once, and the form shows Mañana chosen',
    (tester) async {
      await _App.open(tester);
      await openForm(tester);
      await tester.tap(chip('new-task-pick-day'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text(es.reviewSchedule)),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: sheet,
          matching: find.widgetWithText(ChoiceChip, es.tomorrow),
        ),
      );
      await tester.pumpAndSettle();
      expect(sheet, findsNothing, reason: 'it applied at once');
      expect(selected(tester, 'new-task-tomorrow'), isTrue);
      expect(selected(tester, 'new-task-pick-day'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Añadir tarea with no title says Introduce un título para la tarea and saves nothing',
    (tester) async {
      final app = await _App.open(tester);
      await openForm(tester);
      await tester.tap(chip('new-task-today'));
      await tester.pumpAndSettle();
      await tapSave(tester);
      expect(find.byType(TaskEditor), findsOneWidget);
      expect(find.text(es.titleRequiredField), findsOneWidget);
      expect(app.tasks.state.requireValue, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- D12: Back ----

  testWidgets(
    'D12: Back with a title saves it, says Cambios guardados with Deshacer and lands it lit; Deshacer removes it',
    (tester) async {
      final app = await _App.open(tester);
      await openForm(tester);
      await typeTitle(tester, 'Regar las plantas');
      await tester.tap(chip('new-task-tomorrow'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsNothing);
      final saved = app.tasks.state.requireValue.single;
      expect(saved.title, 'Regar las plantas');
      expect(Task.day(saved.dueDate!), tomorrow);
      expect(es.changesSaved, 'Cambios guardados');
      expect(find.text(es.changesSaved), findsOneWidget);
      expect(find.text(es.undo), findsOneWidget);
      expect(row('Regar las plantas').hitTestable(), findsOneWidget);
      expect(
        tester.widget<TaskTile>(row('Regar las plantas')).color,
        lit(tester),
      );
      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      expect(app.tasks.state.requireValue, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'D12: Back on an empty form just closes: nothing is saved and no message shows, even with a day chosen',
    (tester) async {
      final app = await _App.open(tester);
      await openForm(tester);
      await tester.tap(chip('new-task-today'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsNothing);
      expect(find.byType(CalendarScreen).hitTestable(), findsWidgets);
      expect(app.tasks.state.requireValue, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
      // A title of spaces is no title.
      await openForm(tester);
      await typeTitle(tester, '   ');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsNothing);
      expect(app.tasks.state.requireValue, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Offline ----

  testWidgets(
    'offline: with a sync that never answers, the task is saved on the phone, the form closes at once and Calendar lights it, while the sync still waits',
    (tester) async {
      final phone = _Phone();
      final app = await _App.open(tester, phone: phone);
      expect(phone.syncs, greaterThan(0), reason: 'a sync is under way');
      await openForm(tester);
      await typeTitle(tester, 'Pagar la luz');
      await tester.tap(chip('new-task-today'));
      await tester.pumpAndSettle();
      await tapSave(tester);
      expect(find.byType(TaskEditor), findsNothing);
      expect(find.text(es.saving), findsNothing);
      expect(phone.rows.map((task) => task.title), ['Pagar la luz']);
      expect(phone.finished, 0, reason: 'the sync never finished');
      expect(
        app.container.read(taskProvider).requireValue.map((t) => t.title),
        ['Pagar la luz'],
      );
      expect(row('Pagar la luz').hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(row('Pagar la luz')).color, lit(tester));
      final calendar = tester.element(find.byType(CalendarScreen));
      expect(
        find.text(es.taskAddedOn(calendar.weekdayDate(today))),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Landing ----

  testWidgets(
    'from Tareas filtered to Prioridad alta, the new task lands there: Todas chosen again and its row lit, with Añadida sin fecha',
    (tester) async {
      await _App.open(
        tester,
        tasks: [Task(id: 1, title: 'Renovar el pasaporte', priority: 3)],
      );
      await openTasksTab(tester);
      ChoiceChip filter(String label) =>
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));
      await tester.tap(find.widgetWithText(ChoiceChip, es.highPriority));
      await tester.pumpAndSettle();
      expect(filter(es.highPriority).selected, isTrue);
      await openForm(tester);
      await typeTitle(tester, 'Comprar bombillas');
      await tapSave(tester);
      expect(find.byType(HomeScreen).hitTestable(), findsWidgets);
      expect(filter(es.allTasks).selected, isTrue);
      expect(row('Comprar bombillas').hitTestable(), findsOneWidget);
      expect(
        tester.widget<TaskTile>(row('Comprar bombillas')).color,
        lit(tester),
      );
      expect(find.text(es.taskSavedInbox), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'from a project page, the form shows its project by the day, saves the task in it and lands there lit',
    (tester) async {
      final app = await _App.open(
        tester,
        projects: [TaskListInfo(id: 'casa', name: 'Casa')],
      );
      await openTasksTab(tester);
      unawaited(
        Navigator.of(tester.element(find.byType(HomeScreen))).push(
          MaterialPageRoute<void>(
            builder: (_) => const HomeScreen(isRoot: false, listId: 'casa'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openForm(tester);
      final picker = find.byType(TaskAssignmentPicker);
      expect(picker, findsOneWidget, reason: 'its project, up front');
      expect(
        find.descendant(of: picker, matching: find.text('Casa')),
        findsOneWidget,
      );
      expect(
        tester.getRect(picker).top,
        lessThan(
          tester.getRect(find.byKey(const ValueKey('task-more-details'))).top,
        ),
      );
      await typeTitle(tester, 'Cambiar la bombilla');
      await tapSave(tester);
      final saved = app.tasks.state.requireValue.single;
      expect(saved.listId, 'casa');
      expect(saved.assignment, 'personal');
      final page = find.byWidgetPredicate(
        (widget) => widget is HomeScreen && widget.listId == 'casa',
      );
      expect(page.hitTestable(), findsOneWidget, reason: 'still on Casa');
      final lightRow = find.descendant(
        of: page,
        matching: row('Cambiar la bombilla'),
      );
      expect(lightRow.hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(lightRow).color, lit(tester));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'from a shared project’s page, the new task is for everyone (Todos) unless a person is chosen',
    (tester) async {
      final app = await _App.open(
        tester,
        projects: [
          TaskListInfo(
            id: 'familia',
            name: 'Familia',
            shared: true,
            role: 'owner',
            ownerId: 1,
            people: const [
              ProjectMember(id: 1, name: 'Yo', role: 'owner'),
              ProjectMember(id: 2, name: 'Ana', role: 'editor'),
            ],
          ),
        ],
      );
      await openTasksTab(tester);
      unawaited(
        Navigator.of(tester.element(find.byType(HomeScreen))).push(
          MaterialPageRoute<void>(
            builder: (_) => const HomeScreen(isRoot: false, listId: 'familia'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openForm(tester);
      final picker = find.byType(TaskAssignmentPicker);
      expect(
        find.descendant(of: picker, matching: find.text(es.assignedToGroup)),
        findsOneWidget,
      );
      await typeTitle(tester, 'Comprar pan');
      await tapSave(tester);
      final saved = app.tasks.state.requireValue.single;
      expect(saved.listId, 'familia');
      expect(saved.assignment, 'group');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'D9: from Calendar with a later Thursday picked, the form starts on Thursday; with today picked it starts with no day',
    (tester) async {
      final start = monday();
      final thursday = plus(start, 3);
      final app = await _App.open(tester, clock: start);
      await tester.tap(
        find
            .descendant(
              of: find.byType(CalendarScreen),
              matching: find.text('${thursday.day}'),
            )
            .hitTestable()
            .first,
      );
      await tester.pumpAndSettle();
      await openForm(tester);
      final form = tester.element(find.byType(TaskEditor));
      expect(
        find.widgetWithText(ChoiceChip, form.weekdayDate(thursday)),
        findsOneWidget,
      );
      expect(selected(tester, 'new-task-pick-day'), isTrue);
      await typeTitle(tester, 'Comprar pan');
      await tapSave(tester);
      expect(Task.day(app.tasks.state.requireValue.single.dueDate!), thursday);
      expect(
        find.text(DateFormat.MMMMEEEEd('es').format(thursday)),
        findsOneWidget,
      );

      await tester.tap(
        find
            .descendant(
              of: find.byType(CalendarScreen),
              matching: find.text('${start.day}'),
            )
            .hitTestable()
            .first,
      );
      await tester.pumpAndSettle();
      await openForm(tester);
      for (final key in [
        'new-task-today',
        'new-task-tomorrow',
        'new-task-pick-day',
      ]) {
        expect(selected(tester, key), isFalse, reason: key);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'from today’s timeline, a task with no day returns to Calendar with the Sin fecha row lit; from Thursday’s, the form starts on Thursday and the timeline lights the new row',
    (tester) async {
      final start = monday();
      final thursday = plus(start, 3);
      final app = await _App.open(tester, clock: start);
      Future<void> openTimeline(DateTime day) async {
        unawaited(
          Navigator.of(
            tester.element(find.byType(CalendarScreen)),
          ).pushNamed('/timeline', arguments: day),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DayTimelineScreen), findsOneWidget);
      }

      await openTimeline(start);
      await openForm(tester);
      await typeTitle(tester, 'Comprar pan');
      await tapSave(tester);
      expect(app.tasks.state.requireValue.single.dueDate, isNull);
      expect(find.byType(DayTimelineScreen), findsNothing);
      final inbox = find.byKey(const ValueKey('calendar-inbox'));
      final box = tester.widget<DecoratedBox>(
        find.ancestor(of: inbox, matching: find.byType(DecoratedBox)).first,
      );
      expect((box.decoration as BoxDecoration).color, lit(tester));

      await openTimeline(thursday);
      await openForm(tester);
      expect(selected(tester, 'new-task-pick-day'), isTrue);
      await typeTitle(tester, 'Regar las plantas');
      await tapSave(tester);
      final saved = app.tasks.state.requireValue.last;
      expect(Task.day(saved.dueDate!), thursday);
      expect(find.byType(DayTimelineScreen).hitTestable(), findsWidgets);
      final timelineRow = find.descendant(
        of: find.byType(DayTimelineScreen),
        matching: row('Regar las plantas'),
      );
      expect(timelineRow.hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(timelineRow).color, lit(tester));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'from a shared project’s page filtered to Ana, a new task for everyone lands with Todas chosen again and its row lit',
    (tester) async {
      await _App.open(
        tester,
        projects: [
          TaskListInfo(
            id: 'familia',
            name: 'Familia',
            version: 1,
            shared: true,
            role: 'owner',
            ownerId: 1,
            people: const [
              ProjectMember(id: 1, name: 'Yo', role: 'owner'),
              ProjectMember(id: 2, name: 'Ana', role: 'editor'),
            ],
          ),
        ],
        tasks: [
          Task(
            id: 1,
            title: 'Recoger a los niños',
            priority: 1,
            listId: 'familia',
            assignment: 'member',
            assigneeId: 2,
            assigneeName: 'Ana',
          ),
        ],
      );
      await openTasksTab(tester);
      unawaited(
        Navigator.of(tester.element(find.byType(HomeScreen))).push(
          MaterialPageRoute<void>(
            builder: (_) => const HomeScreen(isRoot: false, listId: 'familia'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('people-2')));
      await tester.pumpAndSettle();
      expect(selected(tester, 'people-2'), isTrue);
      await openForm(tester);
      await typeTitle(tester, 'Comprar pan');
      await tapSave(tester);
      expect(selected(tester, 'people-all'), isTrue);
      expect(selected(tester, 'people-2'), isFalse);
      final page = find.byWidgetPredicate(
        (widget) => widget is HomeScreen && widget.listId == 'familia',
      );
      final newRow = find.descendant(of: page, matching: row('Comprar pan'));
      expect(newRow.hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(newRow).color, lit(tester));
      expect(
        find.descendant(of: page, matching: row('Recoger a los niños')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'words carried over from the capture sheet: the first sentence is the title and the rest shows at once as the notes, saved with it',
    (tester) async {
      final app = await _App.open(tester);
      unawaited(
        Navigator.of(tester.element(find.byType(CalendarScreen))).pushNamed(
          '/newTask',
          arguments: const NewTaskArguments(
            words: 'llamar al dentista. Pedir cita para revisar la muela',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsOneWidget);
      expect(
        tester.widget<TextFormField>(title()).controller!.text,
        'Llamar al dentista',
      );
      final notes = find.byKey(const ValueKey('task-notes'));
      expect(notes, findsOneWidget, reason: 'up front, not in Más detalles');
      expect(
        tester.widget<TextFormField>(notes).controller!.text,
        'Pedir cita para revisar la muela',
      );
      expect(find.text(es.fewerDetails), findsNothing);
      await tapSave(tester);
      final saved = app.tasks.state.requireValue.single;
      expect(saved.title, 'Llamar al dentista');
      expect(saved.notes, 'Pedir cita para revisar la muela');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'files can be added before the first save: Añadir adjunto offers a photo or a file, and says files go up when the task is saved',
    (tester) async {
      // A signed-in account's phone copy.
      await _App.open(tester, phone: _Phone());
      await openForm(tester);
      await typeTitle(tester, 'Renovar el DNI');
      await showDetails(tester);
      final add = find.text(es.addAttachment);
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text(es.fileUploadHelp)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text(es.choosePhoto)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text(es.attachFile)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Más detalles ----

  testWidgets(
    'Más detalles holds Notas, then the files, Recordatorio, Repetir, Pasos and, with projects, Proyecto; notes and steps are saved with the task',
    (tester) async {
      final app = await _App.open(
        tester,
        projects: [TaskListInfo(id: 'casa', name: 'Casa')],
      );
      await openForm(tester);
      // No project yet: it waits in Más detalles.
      expect(find.byType(TaskAssignmentPicker), findsNothing);
      await typeTitle(tester, 'Médico');
      await tester.tap(chip('new-task-tomorrow'));
      await tester.pumpAndSettle();
      await showDetails(tester);
      final order = <(String, Finder)>[
        ('Notas', find.byKey(const ValueKey('task-notes'))),
        ('Archivos', find.text(es.addAttachment)),
        ('Recordatorio', find.byType(ReminderControl)),
        ('Repetir', find.byKey(const ValueKey('task-repeat'))),
        ('Pasos', find.byKey(const ValueKey('add-checklist-item'))),
        ('Proyecto', find.byType(TaskAssignmentPicker)),
      ];
      double? last;
      for (final (name, finder) in order) {
        expect(finder, findsOneWidget, reason: name);
        final top = tester.getRect(finder).top;
        if (last != null) expect(top, greaterThan(last), reason: name);
        last = top;
      }
      // What waits for editing the task later.
      expect(find.byKey(const ValueKey('task-labels')), findsNothing);
      expect(find.byKey(const ValueKey('task-deadline')), findsNothing);
      expect(find.byKey(const ValueKey('task-duration')), findsNothing);
      expect(find.text(es.priority.toUpperCase()), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('task-notes')),
        'Llevar los análisis',
      );
      final step = find.descendant(
        of: find.byType(ChecklistEditor),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(step.first);
      await tester.enterText(step.first, 'Pedir cita');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tapSave(tester);
      final saved = app.tasks.state.requireValue.single;
      expect(saved.notes, 'Llevar los análisis');
      expect(saved.checklist.map((item) => item.title), ['Pedir cita']);
      expect(saved.listId, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Pro, and billing not known yet: unchanged ----

  testWidgets(
    'Pro: Añadir tarea still opens the capture sheet on the mic, with the keyboard for typing to the assistant and no Rellenar a mano',
    (tester) async {
      final app = await _App.open(tester, pro: true);
      expect(find.text(es.newTask), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TaskActions),
          matching: find.byIcon(Icons.mic_none_rounded),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(VoiceTaskScreen), findsOneWidget);
      expect(find.byType(TaskEditor), findsNothing);
      expect(find.byTooltip(es.captureTypeInstead), findsOneWidget);
      expect(find.text(es.captureFillByHand), findsNothing);
      expect(app.speech.starts, 0, reason: 'this phone has no recognizer');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'billing not known yet: Añadir tarea keeps today’s behaviour and opens the sheet, not the form',
    (tester) async {
      await _App.open(tester, billingLoading: true, settle: false);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text(es.newTask), findsNothing);
      await tester.tap(find.text(es.addTask).hitTestable());
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(VoiceTaskScreen), findsOneWidget);
      expect(find.byType(TaskEditor), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Copy ----

  test(
    'the form’s words in EN, ES and CA: New task / Nueva tarea / Tasca nova, Remove time / Quitar hora / Treu l’hora',
    () {
      expect(en.newTask, 'New task');
      expect(es.newTask, 'Nueva tarea');
      expect(ca.newTask, 'Tasca nova');
      expect(en.removeTime, 'Remove time');
      expect(ca.removeTime, 'Treu l’hora');
      for (final l in [en, es, ca]) {
        // The button that opens the form is named as the form is.
        expect(l.newTask, isNot(l.addTask), reason: l.localeName);
      }
    },
  );

  // ---- Layout: 2× text on 320 dp ----

  for (final language in ['es', 'ca']) {
    testWidgets(
      'at 2× text on 320 dp ($language), the form reads in full with no overflow: Nueva tarea, the title, the day chips, the time and Más detalles; with a 300 dp keyboard the button stays above it',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final l = strings(language);
        const size = Size(320, 640);
        await _App.open(tester, language: language, size: size);
        final button = find.widgetWithText(FilledButton, l.newTask);
        expect(button, findsOneWidget);
        final rect = tester.getRect(button);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320.5));
        await openForm(tester, l);
        await tester.tap(chip('new-task-tomorrow'));
        await tester.pumpAndSettle();
        for (final finder in [
          title(),
          chip('new-task-today'),
          chip('new-task-tomorrow'),
          chip('new-task-pick-day'),
          chip('new-task-time'),
          find.byKey(const ValueKey('task-more-details')),
        ]) {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          final box = tester.getRect(finder);
          expect(box.left, greaterThanOrEqualTo(0), reason: '$finder');
          expect(box.right, lessThanOrEqualTo(320.5), reason: '$finder');
          expect(finder.hitTestable(), findsOneWidget, reason: '$finder');
        }
        for (final label in [l.today, l.tomorrow, l.pickDay, l.addTime]) {
          final text = find.text(label);
          expect(text, findsOneWidget, reason: label);
          expect(
            tester
                .renderObject<RenderParagraph>(
                  find.descendant(of: text, matching: find.byType(RichText)),
                )
                .didExceedMaxLines,
            isFalse,
            reason: label,
          );
        }
        await showDetails(tester);
        expect(tester.takeException(), isNull, reason: 'Más detalles fits');

        // The keyboard comes up: the button stays in view above it.
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        final add = tester.getRect(save());
        expect(add.bottom, lessThanOrEqualTo(size.height - 300 + 0.5));
        expect(add.top, greaterThanOrEqualTo(0));
        expect(save().hitTestable(), findsOneWidget);
        expect(add.right, lessThanOrEqualTo(320.5));
        expect(tester.takeException(), isNull, reason: 'no overflow');
      },
    );
  }

  // ---- Renders, on request: --dart-define=WRITE_FORM_PREVIEWS=true ----
  // Last in the file: they load the app's fonts, which every later test
  // would then use.

  testWidgets(
    'previews of the form, its details, 2× text in ES and CA, the sheet’s Rellenar a mano, the people filter and Creada por (written to build/ on request)',
    (tester) async {
      if (!const bool.fromEnvironment('WRITE_FORM_PREVIEWS')) return;
      await tester.runAsync(() async {
        await (FontLoader(
          'Manrope',
        )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      final preview = GlobalKey();
      Future<void> shoot(String name) async {
        await tester.pumpAndSettle();
        final boundary =
            preview.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File(
            'build/$name.png',
          ).writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }

      final familia = TaskListInfo(
        id: 'familia',
        name: 'Familia',
        version: 1,
        shared: true,
        role: 'owner',
        ownerId: 1,
        people: const [
          ProjectMember(id: 1, name: 'Miki', role: 'owner'),
          ProjectMember(id: 2, name: 'Ana', role: 'editor'),
          ProjectMember(id: 3, name: 'Paul', role: 'editor'),
        ],
      );

      // The form, with a day and a time.
      await _App.open(tester, preview: preview);
      await openForm(tester);
      await typeTitle(tester, 'Llamar al médico');
      await tester.tap(chip('new-task-tomorrow'));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await shoot('new-task-form-es');
      await showDetails(tester);
      await shoot('new-task-form-details-es');

      // 2× text on 320 dp, with the keyboard up.
      for (final language in ['es', 'ca']) {
        await tester.pumpWidget(const SizedBox());
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        await _App.open(
          tester,
          language: language,
          size: const Size(320, 640),
          preview: preview,
        );
        await openForm(tester, strings(language));
        await tester.tap(chip('new-task-today'));
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await shoot('new-task-form-2x-$language');
        tester.view.resetViewInsets();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      }

      // The sheet with dictations left: Rellenar a mano.
      await tester.pumpWidget(const SizedBox());
      await _App.open(tester, freeLeft: 5, listening: true, preview: preview);
      await tester.tap(find.text(es.addTask).hitTestable());
      await tester.pumpAndSettle();
      await shoot('capture-fill-by-hand-es');

      // The people filter on a shared project's page, and Creada por.
      await tester.pumpWidget(const SizedBox());
      final app = await _App.open(
        tester,
        projects: [familia],
        tasks: [
          Task(
            id: 1,
            title: 'Comprar pan',
            priority: 1,
            listId: 'familia',
            assignment: 'group',
            createdBy: 2,
            createdByName: 'Ana',
          ),
          Task(
            id: 2,
            title: 'Recoger a los niños',
            priority: 1,
            listId: 'familia',
            assignment: 'member',
            assigneeId: 2,
            assigneeName: 'Ana',
          ),
        ],
        preview: preview,
      );
      await openTasksTab(tester);
      unawaited(
        Navigator.of(tester.element(find.byType(HomeScreen))).push(
          MaterialPageRoute<void>(
            builder: (_) => const HomeScreen(isRoot: false, listId: 'familia'),
          ),
        ),
      );
      await shoot('project-people-filter-es');
      unawaited(
        Navigator.of(
          tester.element(find.byType(HomeScreen).last),
        ).pushNamed('/taskDetails', arguments: 1),
      );
      await shoot('task-created-by-es');
      expect(app.tasks.state.requireValue, hasLength(2));
    },
  );
}

/// The app in Spanish (or [language]) on Calendar, signed in. Without
/// [pro], the account has no Pro and its server sends no free count, so the
/// add button opens the form; [freeLeft] gives it free dictations, and
/// [listening] a phone that listens. [preview] wraps the app to render it.
class _App {
  _App(this.container, this.tasks, this.api, this.speech);
  final ProviderContainer container;
  final _Tasks tasks;
  final _Api api;
  final _Speech speech;

  static Future<_App> open(
    WidgetTester tester, {
    bool pro = false,
    bool billingLoading = false,
    String language = 'es',
    Size size = const Size(390, 844),
    List<Task> tasks = const [],
    List<TaskListInfo> projects = const [],
    DateTime? clock,
    _Phone? phone,
    bool settle = true,
    int? freeLeft,
    bool listening = false,
    GlobalKey? preview,
  }) async {
    final reminders = preview == null
        ? const <Override>[]
        : reminderOverrides(MemoryReminderStore(), FakeReminderAccess());
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _Api();
    final memory = _Tasks(tasks);
    final speech = _Speech();
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
              : _CountedAuth(api, freeLeft),
        ),
        attachmentEntriesProvider.overrideWith((ref, taskId) async => []),
        regionalStoreProvider.overrideWithValue(
          MemoryRegionalStore(
            RegionalPreferences(
              language: language,
              clock: ClockFormat.twentyFour,
              weekStart: 1,
            ),
          ),
        ),
        taskListsProvider.overrideWith((ref) async => projects),
        apiClientProvider.overrideWithValue(api),
        taskRepositoryProvider.overrideWithValue(phone ?? MemoryTasks()),
        taskProvider.overrideWith(
          (ref) => phone == null ? memory : TaskNotifier(phone),
        ),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        pendingCapturesProvider.overrideWith((ref) async => []),
        nativeSpeechProvider.overrideWithValue(
          listening ? ListeningSpeech() : speech,
        ),
        captureRecorderFactoryProvider.overrideWithValue(SilentRecorder.new),
        captureStoreProvider.overrideWithValue(MemoryCaptures()),
        if (clock != null) calendarClockProvider.overrideWithValue(() => clock),
        // Renders show the reminder row as a phone does.
        ...reminders,
      ],
    );
    addTearDown(() {
      container.dispose();
      api.close();
    });
    const app = MyApp();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: preview == null
            ? app
            : RepaintBoundary(key: preview, child: app),
      ),
    );
    if (settle) await tester.pumpAndSettle();
    return _App(container, memory, api, speech);
  }
}

/// No network: every request fails as offline; [drafts] counts those that
/// would have gone to the assistant.
class _Api extends OfflineApiClient {
  int drafts = 0;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    if (path.startsWith('ai/')) drafts++;
    throw ApiException(0, 'Offline. Retry when connected.');
  }
}

/// Tasks in memory, numbered as they are added.
class _Tasks extends DesignTaskNotifier {
  _Tasks(this.initial);
  final List<Task> initial;
  int _next = 100;
  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = AsyncData([...initial]);
  }

  @override
  Future<int> addTask(Task task) async {
    final id = _next++;
    state = AsyncData([...state.requireValue, task.copyWith(id: id)]);
    return id;
  }

  // The list above is the phone's copy.
  @override
  Future<void> showLocal() async {}
}

/// The fixture's account, with [left] free dictations this month.
class _CountedAuth extends AuthNotifier {
  _CountedAuth(super.api, this.left);
  final int left;
  @override
  Future<void> restore() async {
    final now = DateTime.now().toUtc();
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

/// A phone with no recognizer: it never listens.
class _Speech extends QuietSpeech {
  int starts = 0;
  @override
  Future<void> start(
    int id,
    String language, {
    List<String> hints = const [],
  }) async {
    starts++;
  }
}

/// A signed-in account's tasks on the phone, with a cloud sync that never
/// answers: offline.
class _Phone extends TaskRepository {
  _Phone() : super(TaskDatabase());
  final rows = <Task>[];
  var _next = 200;
  final _gate = Completer<void>();
  int syncs = 0;
  int finished = 0;

  @override
  String get ownerKey => 'account:1';

  @override
  Future<void> sync() async {
    syncs++;
    await _gate.future;
    finished++;
  }

  @override
  Future<List<Task>> getAllTasks() async => [...rows];

  @override
  Future<int> addTask(Task task) async {
    final id = _next++;
    rows.add(task.copyWith(id: id));
    return id;
  }

  @override
  Future<int> updateTask(Task task) async {
    final index = rows.indexWhere((row) => row.id == task.id);
    if (index >= 0) rows[index] = task;
    return index >= 0 ? 1 : 0;
  }

  @override
  Future<int> deleteTask(int id) async {
    final before = rows.length;
    rows.removeWhere((task) => task.id == id);
    return before - rows.length;
  }
}
