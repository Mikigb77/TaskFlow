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
import 'package:agenda/providers/project_scope_provider.dart';
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
import 'package:agenda/widgets/project_scope_control.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/widgets/task_actions.dart';
import 'package:agenda/widgets/task_assignment_picker.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

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
    'Elegir día opens the day sheet, titled Elegir día; its Mañana applies at once, and the form shows Mañana chosen',
    (tester) async {
      await _App.open(tester);
      await openForm(tester);
      await tester.tap(chip('new-task-pick-day'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text(es.pickDay)),
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
    'D12, D6: Back with a title saves it, says the day it was added to with Deshacer and lands it lit; Deshacer removes it',
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
      final calendar = tester.element(find.byType(CalendarScreen));
      expect(
        find.text(es.taskAddedOn(calendar.weekdayDate(tomorrow))),
        findsOneWidget,
      );
      expect(find.text(es.changesSaved), findsNothing);
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

  // ---- Run 2026-10-18-commands, b4 · P153 (UX-1010, D6): Back on a new
  // task says what the button says ----

  testWidgets(
    'UX-1010: on Monday 19 October, Back on a new task «Comprar pan» with Mañana says «Añadida al mar, 20 oct» with Deshacer, never Cambios guardados; Deshacer removes the task',
    (tester) async {
      final monday = DateTime(2026, 10, 19, 10);
      final tuesday = DateTime(2026, 10, 20);
      final app = await _App.open(tester, clock: monday);
      await openForm(tester);
      await typeTitle(tester, 'Comprar pan');
      await tester.tap(chip('new-task-tomorrow'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsNothing);
      final saved = app.tasks.state.requireValue.single;
      expect(saved.title, 'Comprar pan');
      expect(Task.day(saved.dueDate!), tuesday);
      final calendar = tester.element(find.byType(CalendarScreen));
      final message = find.byType(SnackBar);
      expect(
        find.descendant(
          of: message,
          matching: find.text(es.taskAddedOn(calendar.weekdayDate(tuesday))),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: message, matching: find.text(es.undo)),
        findsOneWidget,
      );
      expect(find.text(es.changesSaved), findsNothing);
      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      expect(app.tasks.state.requireValue, isEmpty, reason: 'Deshacer');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1010: Back on a new task with no day says «Añadida sin fecha» with Deshacer, never Cambios guardados',
    (tester) async {
      final app = await _App.open(tester, clock: DateTime(2026, 10, 19, 10));
      await openForm(tester);
      await typeTitle(tester, 'Comprar pan');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsNothing);
      final saved = app.tasks.state.requireValue.single;
      expect(saved.dueDate, isNull);
      final message = find.byType(SnackBar);
      expect(
        find.descendant(of: message, matching: find.text(es.taskSavedInbox)),
        findsOneWidget,
      );
      expect(es.taskSavedInbox, 'Añadida sin fecha');
      expect(
        find.descendant(of: message, matching: find.text(es.undo)),
        findsOneWidget,
      );
      expect(find.text(es.changesSaved), findsNothing);
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
    'from Tareas filtered to Prioridad alta, the new task lands there: the filter cleared and its row lit, with Añadida sin fecha',
    (tester) async {
      await _App.open(
        tester,
        tasks: [Task(id: 1, title: 'Renovar el pasaporte', priority: 3)],
      );
      await openTasksTab(tester);
      FilterChip filter(String label) =>
          tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));
      // The chips scroll sideways when they don't fit.
      final high = find.widgetWithText(FilterChip, es.highPriority);
      await tester.ensureVisible(high);
      await tester.pumpAndSettle();
      await tester.tap(high);
      await tester.pumpAndSettle();
      expect(filter(es.highPriority).selected, isTrue);
      await openForm(tester);
      await typeTitle(tester, 'Comprar bombillas');
      await tapSave(tester);
      expect(find.byType(HomeScreen).hitTestable(), findsWidgets);
      expect(filter(es.highPriority).selected, isFalse);
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
    'UX-1639: at 2x on 360×800, a date-only task saved from Thursday’s Día view, below another «Sin hora» row, lights whole inside «Sin hora», on screen, with Thursday’s 08:30 task still showing',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final start = monday();
      final thursday = plus(start, 3);
      await _App.open(
        tester,
        clock: start,
        size: const Size(360, 800),
        tasks: [
          Task(
            id: 1,
            title: 'Paseo por el parque',
            dueDate: DateTime(thursday.year, thursday.month, thursday.day, 8, 30),
            priority: 1,
          ),
          Task(
            id: 2,
            title: 'Pagar la factura de la luz',
            dueDate: thursday,
            hasTime: false,
            priority: 2,
          ),
        ],
      );
      unawaited(
        Navigator.of(
          tester.element(find.byType(CalendarScreen)),
        ).pushNamed('/timeline', arguments: thursday),
      );
      await tester.pumpAndSettle();
      final timeline = find.byType(DayTimelineScreen);
      expect(timeline, findsOneWidget);
      await openForm(tester);
      expect(selected(tester, 'new-task-pick-day'), isTrue);
      await typeTitle(tester, 'Regar las plantas');
      await tapSave(tester);

      expect(timeline.hitTestable(), findsWidgets);
      final untimed = find.byKey(const ValueKey('timeline-untimed'));
      final saved = find.descendant(
        of: untimed,
        matching: row('Regar las plantas'),
      );
      expect(saved, findsOneWidget, reason: 'listed under «Sin hora»');
      expect(tester.widget<TaskTile>(saved).color, lit(tester));
      final area = tester.getRect(untimed);
      final rect = tester.getRect(saved);
      expect(
        rect.top >= area.top - 0.5 && rect.bottom <= area.bottom + 0.5,
        isTrue,
        reason: 'the whole lit row inside «Sin hora»: row $rect, area $area',
      );
      final actions = tester.getRect(
        find.descendant(of: timeline, matching: find.byType(TaskActions)),
      );
      expect(rect.bottom, lessThanOrEqualTo(actions.top + 0.5),
          reason: 'above the add button');
      final walk = find.byTooltip('Paseo por el parque, 08:30');
      expect(walk, findsOneWidget);
      final hours = tester.getRect(find.byKey(const ValueKey('timeline-scroll')));
      final block = tester.getRect(walk);
      expect(block.top >= hours.top - 0.5 && block.bottom <= hours.bottom + 0.5,
          isTrue,
          reason: 'the 08:30 task still shows: block $block, hours $hours');
      expect(tester.takeException(), isNull);
    },
  );

  // D7: a task added under a person's chip is theirs, and stays under it.
  Future<_App> openFamiliaOnAna(WidgetTester tester) async {
    final app = await _App.open(
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
    return app;
  }

  Finder familiaRow(String title) => find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is HomeScreen && widget.listId == 'familia',
    ),
    matching: row(title),
  );

  testWidgets(
    'from a shared project’s page filtered to Ana, a new task is Ana’s, lands with Ana still chosen and its row lit',
    (tester) async {
      final app = await openFamiliaOnAna(tester);
      await openForm(tester);
      final chip = find.widgetWithText(ActionChip, 'Ana');
      expect(chip, findsOneWidget);
      await typeTitle(tester, 'Comprar pan');
      await tapSave(tester);
      final saved = app.tasks.state.requireValue.last;
      expect(saved.title, 'Comprar pan');
      expect(saved.assignment, 'member');
      expect(saved.assigneeId, 2);
      expect(selected(tester, 'people-2'), isTrue);
      expect(selected(tester, 'people-all'), isFalse);
      final newRow = familiaRow('Comprar pan');
      expect(newRow.hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(newRow).color, lit(tester));
      expect(familiaRow('Recoger a los niños'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'from a shared project’s page filtered to Ana, a new task changed to Todos is for everyone and lands with Todas chosen again and its row lit',
    (tester) async {
      final app = await openFamiliaOnAna(tester);
      await openForm(tester);
      await tester.tap(find.widgetWithText(ActionChip, 'Ana'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Todos'));
      await tester.pumpAndSettle();
      await typeTitle(tester, 'Comprar pan');
      await tapSave(tester);
      final saved = app.tasks.state.requireValue.last;
      expect(saved.title, 'Comprar pan');
      expect(saved.assignment, 'group');
      expect(saved.assigneeId, isNull);
      expect(selected(tester, 'people-all'), isTrue);
      expect(selected(tester, 'people-2'), isFalse);
      final newRow = familiaRow('Comprar pan');
      expect(newRow.hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(newRow).color, lit(tester));
      expect(familiaRow('Recoger a los niños'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1111: on Familia with Ana’s chip on, Nueva tarea opens the form with the person chip Ana beside Familia; one tap asks ¿Quién es responsable?, and the saved task is Ana’s by id and name',
    (tester) async {
      final app = await openFamiliaOnAna(tester);
      await openForm(tester);
      final picker = find.descendant(
        of: find.byType(TaskEditor),
        matching: find.byType(TaskAssignmentPicker),
      );
      expect(picker, findsOneWidget);
      final person = find.descendant(
        of: picker,
        matching: find.widgetWithText(ActionChip, 'Ana'),
      );
      final project = find.descendant(of: picker, matching: find.text('Familia'));
      expect(person, findsOneWidget);
      expect(project, findsOneWidget);
      // With it: the form's project row is a full-width row, and the person
      // chip comes right after it, as the shared project's «Todos» chip did.
      final projectRow = find.ancestor(
        of: project,
        matching: find.byType(ListTile),
      );
      final personRect = tester.getRect(person);
      final rowRect = tester.getRect(projectRow.first);
      expect(personRect.top, greaterThanOrEqualTo(rowRect.bottom - 0.5));
      expect(personRect.top - rowRect.bottom, lessThan(16));
      expect(person.hitTestable(), findsOneWidget);

      await tester.tap(person);
      await tester.pumpAndSettle();
      expect(find.text(es.assignmentChoose), findsOneWidget);
      // Keep Ana.
      await tester.tap(find.widgetWithText(ListTile, 'Ana'));
      await tester.pumpAndSettle();
      expect(find.text(es.assignmentChoose), findsNothing);
      expect(
        find.descendant(
          of: picker,
          matching: find.widgetWithText(ActionChip, 'Ana'),
        ),
        findsOneWidget,
      );
      await typeTitle(tester, 'Comprar pan');
      await tapSave(tester);
      final saved = app.tasks.state.requireValue.last;
      expect(saved.title, 'Comprar pan');
      expect(saved.listId, 'familia');
      expect(saved.assignment, 'member');
      expect(saved.assigneeId, 2);
      expect(saved.assigneeName, 'Ana');
      expect(selected(tester, 'people-2'), isTrue);
      expect(tester.widget<TaskTile>(familiaRow('Comprar pan')).color, lit(tester));
      expect(tester.takeException(), isNull);
    },
  );

  for (final (key, name) in [('people-all', 'Todas'), ('people-me', 'Para mí')]) {
    testWidgets(
      'UX-1111: on Familia with $name on, a new task is for everyone, as before, with no person chip in the form',
      (tester) async {
        final app = await openFamiliaOnAna(tester);
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(selected(tester, key), isTrue);
        await openForm(tester);
        expect(
          find.descendant(
            of: find.byType(TaskEditor),
            matching: find.widgetWithText(ActionChip, 'Ana'),
          ),
          findsNothing,
        );
        await typeTitle(tester, 'Comprar pan');
        await tapSave(tester);
        final saved = app.tasks.state.requireValue.last;
        expect(saved.title, 'Comprar pan');
        expect(saved.listId, 'familia');
        expect(saved.assignment, isNot('member'));
        expect(saved.assigneeId, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

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
    'files can be added before the first save: Añadir adjunto offers a photo or a file, with no paragraph about older files (UX-1006)',
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
      expect(find.text(es.fileUploadHelp), findsNothing);
      expect(find.text(es.fileLocalHelp), findsNothing);
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
    'Pro: Añadir tarea still opens the capture sheet on the mic, with the keyboard for typing to the assistant and no way to the form',
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
      expect(
        find.byKey(const ValueKey('capture-type-instead')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('capture-fill-by-hand')), findsNothing);
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

  // ---- Run 2026-10-18-commands, P130 (UX-1001): a task for someone else
  // lands in view, under Calendar's and Tareas' «Para mí» ----

  TaskListInfo familia() => TaskListInfo(
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
  );
  final casa = TaskListInfo(id: 'casa', name: 'Casa', version: 1);

  /// The scope chip [label] (`Todas`, `Para mí`) on the screen in front.
  ChoiceChip scopeChip(WidgetTester tester, String label) => tester
      .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label).hitTestable());

  /// Nueva tarea: [title], Mañana, and under Más detalles the project
  /// [project] and, when given, the person [person].
  Future<void> addTomorrow(
    WidgetTester tester,
    String title, {
    String? project,
    String? person,
  }) async {
    await openForm(tester);
    await typeTitle(tester, title);
    await tester.tap(chip('new-task-tomorrow'));
    await tester.pumpAndSettle();
    if (project != null) {
      await showDetails(tester);
      final picker = find.byType(TaskAssignmentPicker);
      final row = find.descendant(of: picker, matching: find.byType(ListTile));
      await tester.ensureVisible(row.first);
      await tester.pumpAndSettle();
      await tester.tap(row.first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(project),
        ),
      );
      await tester.pumpAndSettle();
      if (person != null) {
        final who = find.descendant(
          of: picker,
          matching: find.widgetWithText(ActionChip, es.assignedToGroup),
        );
        await tester.ensureVisible(who);
        await tester.pumpAndSettle();
        await tester.tap(who);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(person),
          ),
        );
        await tester.pumpAndSettle();
      }
    }
    await tapSave(tester);
  }

  testWidgets(
    'UX-1001: a free account on Calendar’s default «Para mí» adds «Llamar al médico» for Ana in Familia tomorrow: Mañana is selected, «Todas» is selected, the row is lit, and «Añadida al …» shows with Deshacer',
    (tester) async {
      final app = await _App.open(tester, projects: [familia()]);
      expect(scopeChip(tester, es.forMe).selected, isTrue);
      await addTomorrow(
        tester,
        'Llamar al médico',
        project: 'Familia',
        person: 'Ana',
      );
      final saved = app.tasks.state.requireValue.single;
      expect(saved.listId, 'familia');
      expect(saved.assignment, 'member');
      expect(saved.assigneeId, 2);
      expect(find.byType(CalendarScreen).hitTestable(), findsOneWidget);
      expect(
        find.text(DateFormat.MMMMEEEEd('es').format(tomorrow)),
        findsOneWidget,
      );
      expect(scopeChip(tester, es.forTeam).selected, isTrue);
      expect(scopeChip(tester, es.forMe).selected, isFalse);
      final saved0 = row('Llamar al médico');
      expect(saved0.hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(saved0).color, lit(tester));
      final calendar = tester.element(find.byType(CalendarScreen));
      expect(
        find.text(es.taskAddedOn(calendar.weekdayDate(tomorrow))),
        findsOneWidget,
      );
      expect(find.text(es.undo), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1001: the same task for Ana saved from the Tareas root, on its default «Para mí»: afterwards «Todas» is selected and the row is lit',
    (tester) async {
      await _App.open(tester, projects: [familia()]);
      await openTasksTab(tester);
      expect(scopeChip(tester, es.forMe).selected, isTrue);
      await addTomorrow(
        tester,
        'Llamar al médico',
        project: 'Familia',
        person: 'Ana',
      );
      expect(find.byType(HomeScreen).hitTestable(), findsWidgets);
      expect(scopeChip(tester, es.forTeam).selected, isTrue);
      expect(scopeChip(tester, es.forMe).selected, isFalse);
      final saved = row('Llamar al médico');
      expect(saved.hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(saved).color, lit(tester));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1001: Calendar filtered to «Casa», a task for the account itself saved into Familia: the project filter shows «Todos los proyectos» and the row is lit',
    (tester) async {
      final app = await _App.open(tester, projects: [casa, familia()]);
      app.container.read(projectScopeProvider.notifier).state =
          const ProjectScope(projectId: 'casa');
      await tester.pumpAndSettle();
      final filter = find.descendant(
        of: find.byType(ProjectScopeControl),
        matching: find.byType(ActionChip),
      );
      expect(
        find.descendant(of: filter, matching: find.text('Casa')),
        findsOneWidget,
      );
      await addTomorrow(tester, 'Comprar pan', project: 'Familia');
      final saved = app.tasks.state.requireValue.single;
      expect(saved.listId, 'familia');
      expect(saved.isForAccount(1), isTrue);
      expect(
        find.descendant(of: filter, matching: find.text(es.projectsAll)),
        findsOneWidget,
      );
      expect(es.projectsAll, 'Todos los proyectos');
      expect(app.container.read(projectScopeProvider).projectId, isNull);
      final shown = row('Comprar pan');
      expect(shown.hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(shown).color, lit(tester));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1001: a task for the account itself saved under «Para mí» leaves «Para mí» selected',
    (tester) async {
      final app = await _App.open(tester, projects: [familia()]);
      expect(scopeChip(tester, es.forMe).selected, isTrue);
      await addTomorrow(tester, 'Regar las plantas');
      expect(app.tasks.state.requireValue.single.listId, isNull);
      expect(scopeChip(tester, es.forMe).selected, isTrue);
      expect(scopeChip(tester, es.forTeam).selected, isFalse);
      final shown = row('Regar las plantas');
      expect(shown.hitTestable(), findsOneWidget);
      expect(tester.widget<TaskTile>(shown).color, lit(tester));
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Run 2026-10-18-commands, round 2, P147 (UX-1213): Deshacer puts
  // back the filter a landing widened ----

  Future<void> undo(WidgetTester tester) async {
    expect(find.text(es.undo), findsOneWidget);
    await tester.tap(find.text(es.undo));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'UX-1213: Calendar on «Para mí», «Llamar al médico» saved for Ana in Familia for Mañana: «Todas» is selected; after «Deshacer» the task is gone and «Para mí» is selected again',
    (tester) async {
      final app = await _App.open(tester, projects: [familia()]);
      expect(scopeChip(tester, es.forMe).selected, isTrue);
      await addTomorrow(
        tester,
        'Llamar al médico',
        project: 'Familia',
        person: 'Ana',
      );
      expect(app.tasks.state.requireValue, hasLength(1));
      expect(scopeChip(tester, es.forTeam).selected, isTrue);
      await undo(tester);
      expect(app.tasks.state.requireValue, isEmpty);
      expect(row('Llamar al médico'), findsNothing);
      expect(find.byType(CalendarScreen).hitTestable(), findsOneWidget);
      expect(scopeChip(tester, es.forMe).selected, isTrue);
      expect(scopeChip(tester, es.forTeam).selected, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1213: the same task for Ana saved from the Tareas root on its default «Para mí»: after «Deshacer» «Para mí» is selected again',
    (tester) async {
      final app = await _App.open(tester, projects: [familia()]);
      await openTasksTab(tester);
      expect(scopeChip(tester, es.forMe).selected, isTrue);
      await addTomorrow(
        tester,
        'Llamar al médico',
        project: 'Familia',
        person: 'Ana',
      );
      expect(scopeChip(tester, es.forTeam).selected, isTrue);
      await undo(tester);
      expect(app.tasks.state.requireValue, isEmpty);
      expect(row('Llamar al médico'), findsNothing);
      expect(find.byType(HomeScreen).hitTestable(), findsWidgets);
      expect(scopeChip(tester, es.forMe).selected, isTrue);
      expect(scopeChip(tester, es.forTeam).selected, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1213: Calendar filtered to «Casa», a task for the account itself saved into Familia: «Todos los proyectos» shows; after «Deshacer» the filter shows «Casa» again',
    (tester) async {
      final app = await _App.open(tester, projects: [casa, familia()]);
      app.container.read(projectScopeProvider.notifier).state =
          const ProjectScope(projectId: 'casa');
      await tester.pumpAndSettle();
      final filter = find.descendant(
        of: find.byType(ProjectScopeControl),
        matching: find.byType(ActionChip),
      );
      await addTomorrow(tester, 'Comprar pan', project: 'Familia');
      expect(
        find.descendant(of: filter, matching: find.text(es.projectsAll)),
        findsOneWidget,
      );
      await undo(tester);
      expect(app.tasks.state.requireValue, isEmpty);
      expect(
        find.descendant(of: filter, matching: find.text('Casa')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: filter, matching: find.text(es.projectsAll)),
        findsNothing,
      );
      expect(app.container.read(projectScopeProvider).projectId, 'casa');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1213: after the landing switches Calendar to «Todas», the person taps «Para mí» and then «Todas»; «Deshacer» takes the task away and «Todas» stays selected',
    (tester) async {
      final app = await _App.open(tester, projects: [familia()]);
      await addTomorrow(
        tester,
        'Llamar al médico',
        project: 'Familia',
        person: 'Ana',
      );
      expect(scopeChip(tester, es.forTeam).selected, isTrue);
      await tester.tap(find.widgetWithText(ChoiceChip, es.forMe).hitTestable());
      await tester.pumpAndSettle();
      expect(scopeChip(tester, es.forMe).selected, isTrue);
      await tester.tap(
        find.widgetWithText(ChoiceChip, es.forTeam).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(scopeChip(tester, es.forTeam).selected, isTrue);
      await undo(tester);
      expect(app.tasks.state.requireValue, isEmpty);
      expect(scopeChip(tester, es.forTeam).selected, isTrue);
      expect(scopeChip(tester, es.forMe).selected, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1213: a task for the account itself saved under «Para mí», then «Deshacer»: «Para mí» stays selected and the filter is unchanged',
    (tester) async {
      final app = await _App.open(tester, projects: [familia()]);
      final scope = app.container.read(projectScopeProvider);
      expect(scopeChip(tester, es.forMe).selected, isTrue);
      await addTomorrow(tester, 'Regar las plantas');
      expect(app.tasks.state.requireValue, hasLength(1));
      expect(
        identical(app.container.read(projectScopeProvider), scope),
        isTrue,
      );
      await undo(tester);
      expect(app.tasks.state.requireValue, isEmpty);
      expect(scopeChip(tester, es.forMe).selected, isTrue);
      expect(scopeChip(tester, es.forTeam).selected, isFalse);
      expect(
        identical(app.container.read(projectScopeProvider), scope),
        isTrue,
        reason: 'nothing else changes',
      );
      expect(find.byType(CalendarScreen).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Run 2026-10-18-commands, b3 · P139 (UX-1002, UX-1003, UX-1004) and
  // P140 (UX-1006, UX-1007): the form at large text, and its details ----
  // With Manrope, as the phone measures; after every other test but the
  // renders, which load it too.

  group('b3: the form at large text, and its details', () {
    setUpAll(() async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });

    /// Whether any text field on screen holds the primary focus.
    bool anyFieldFocused(WidgetTester tester) => tester
        .widgetList<EditableText>(find.byType(EditableText))
        .any((field) => field.focusNode.hasPrimaryFocus);

    /// The title's lines as laid out, and whether all of it shows.
    ({int lines, bool whole, AxisDirection axis}) titleLayout(
      WidgetTester tester,
    ) {
      final editable = find.descendant(
        of: title(),
        matching: find.byType(EditableText),
      );
      final render = tester.state<EditableTextState>(editable).renderEditable;
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: editable, matching: find.byType(Scrollable)),
      );
      return (
        lines: (render.size.height / render.preferredLineHeight).round(),
        whole: scroll.position.maxScrollExtent == 0,
        axis: scroll.axisDirection,
      );
    }

    /// Nueva tarea at 2× text on 320×640, with a 300 dp keyboard up and
    /// «Llamar al médico» typed.
    Future<void> largeForm(WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _App.open(tester, size: const Size(320, 640));
      await openForm(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await typeTitle(tester, 'Llamar al médico');
      expect(focused(tester), isTrue);
      expect(tester.testTextInput.isVisible, isTrue, reason: 'keyboard up');
    }

    /// Mañana tapped where it shows above the keyboard; once the keyboard
    /// is asked down, the phone gives its space back.
    Future<void> tapTomorrowOverKeyboard(WidgetTester tester) async {
      await tester.ensureVisible(chip('new-task-tomorrow'));
      await tester.pumpAndSettle();
      await tester.tap(chip('new-task-tomorrow'));
      await tester.pumpAndSettle();
      if (!tester.testTextInput.isVisible) tester.view.resetViewInsets();
      await tester.pumpAndSettle();
    }

    testWidgets(
      'UX-1002: at 2× on 320×640 with the keyboard, a title then Mañana puts the keyboard away: no field has the focus, and «Añadir hora» and «Más detalles» can be tapped without scrolling',
      (tester) async {
        await largeForm(tester);
        await tapTomorrowOverKeyboard(tester);
        expect(selected(tester, 'new-task-tomorrow'), isTrue);
        expect(tester.testTextInput.isVisible, isFalse, reason: 'keyboard down');
        expect(focused(tester), isFalse);
        expect(anyFieldFocused(tester), isFalse);
        expect(
          find.widgetWithText(ActionChip, es.addTime).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('task-more-details')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1002: then «Añadir hora» and 17:00 confirmed: the title still isn’t focused, the keyboard stays down, and the «17:00» chip can be tapped',
      (tester) async {
        await largeForm(tester);
        await tapTomorrowOverKeyboard(tester);
        await tester.tap(find.widgetWithText(ActionChip, es.addTime));
        await tester.pumpAndSettle();
        final dialog = find.byType(TimePickerDialog);
        expect(dialog, findsOneWidget);
        final boxes = find.descendant(
          of: dialog,
          matching: find.byType(TextField),
        );
        expect(boxes, findsNWidgets(2), reason: 'hour and minutes');
        await tester.enterText(boxes.at(0), '17');
        await tester.enterText(boxes.at(1), '00');
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(MaterialLocalizations.of(tester.element(dialog)).okButtonLabel),
        );
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        // The picker's own keyboard went with it; the form's stays down.
        if (!tester.testTextInput.isVisible) tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        expect(focused(tester), isFalse, reason: 'no focus given back');
        expect(anyFieldFocused(tester), isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        final form = tester.element(find.byType(TaskEditor));
        final at = form.clockTime(
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 17),
        );
        expect(at, '17:00');
        expect(find.widgetWithText(InputChip, at).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1003: at 2× on 320 dp with the keyboard a 40-character title wraps down to at most 3 lines and the done action adds no line break; once Mañana puts the keyboard away it shows whole on 4 lines from «Llamar»',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _App.open(tester, size: const Size(320, 640));
        await openForm(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        // The father's own example (UX_REVIEW §7), 40 characters.
        const words = 'Llamar al médico el viernes por la tarde';
        expect(words.length, 40);
        await typeTitle(tester, words);
        expect(focused(tester), isTrue);
        var layout = titleLayout(tester);
        expect(layout.lines, greaterThan(1), reason: 'it wraps');
        expect(layout.lines, lessThanOrEqualTo(3), reason: 'while typing');
        expect(layout.axis, AxisDirection.down, reason: 'no sideways scroll');
        EditableText field() => tester.widget<EditableText>(
          find.descendant(of: title(), matching: find.byType(EditableText)),
        );
        expect(field().maxLines, 3);
        expect(field().textInputAction, TextInputAction.done);
        expect(field().keyboardType, isNot(TextInputType.multiline));

        await tapTomorrowOverKeyboard(tester);
        expect(focused(tester), isFalse);
        expect(field().maxLines, isNull, reason: 'no cap without the focus');
        layout = titleLayout(tester);
        expect(layout.lines, 4);
        expect(layout.whole, isTrue, reason: 'all of it shows');
        final first = tester.getRect(title());
        expect(first.top, greaterThanOrEqualTo(0), reason: '«Llamar» shows');

        await tester.showKeyboard(title());
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        final typed = tester.widget<TextFormField>(title()).controller!.text;
        expect(typed, words);
        expect(typed, isNot(contains('\n')));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1003: at 1× on 390 dp a 20-character title stays on one line',
      (tester) async {
        await _App.open(tester);
        await openForm(tester);
        const words = 'Llamar al médico hoy';
        expect(words.length, 20);
        await typeTitle(tester, words);
        final layout = titleLayout(tester);
        expect(layout.lines, 1);
        expect(layout.whole, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1003: at 2× on 320 dp, once Mañana puts the keyboard away, the 40-character title has no scroll left and its first word «Llamar» lies inside the field and the screen',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _App.open(tester, size: const Size(320, 640));
        await openForm(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        const words = 'Llamar al médico el viernes por la tarde';
        await typeTitle(tester, words);
        final editable = find.descendant(
          of: title(),
          matching: find.byType(EditableText),
        );
        final scroll = tester.state<ScrollableState>(
          find.descendant(of: editable, matching: find.byType(Scrollable)),
        );
        // While typing, the cap holds: the field scrolls, downwards only.
        expect(scroll.axisDirection, AxisDirection.down);
        expect(titleLayout(tester).lines, lessThanOrEqualTo(3));

        await tapTomorrowOverKeyboard(tester);
        expect(focused(tester), isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        final position = tester
            .state<ScrollableState>(
              find.descendant(of: editable, matching: find.byType(Scrollable)),
            )
            .position;
        expect(position.maxScrollExtent, 0, reason: 'nothing hidden');
        expect(position.pixels, 0);
        expect(titleLayout(tester).lines, 4);
        // «Llamar» is the first word: the text's first glyph sits inside the
        // field's box, and the field inside the screen.
        final render = tester.state<EditableTextState>(editable).renderEditable;
        final firstGlyph = render.localToGlobal(
          render.getLocalRectForCaret(const TextPosition(offset: 0)).center,
        );
        final field = tester.getRect(editable);
        expect(field.contains(firstGlyph), isTrue, reason: '«Llamar» shows');
        final screen = Offset.zero & tester.view.physicalSize;
        expect(screen.contains(firstGlyph), isTrue);
        final lastGlyph = render.localToGlobal(
          render
              .getLocalRectForCaret(const TextPosition(offset: words.length))
              .center,
        );
        expect(field.contains(lastGlyph), isTrue, reason: '«tarde» shows');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1003: at 2× on 360×740 the edit form shows the whole unfocused title «Pedir cita en el ayuntamiento para renovar el DNI», «DNI» included, with no scroll left',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        const words = 'Pedir cita en el ayuntamiento para renovar el DNI';
        await _App.open(
          tester,
          size: const Size(360, 740),
          tasks: [Task(id: 1, title: words, priority: 1, dueDate: tomorrow)],
        );
        unawaited(
          Navigator.of(
            tester.element(find.byType(CalendarScreen)),
          ).pushNamed('/editTask', arguments: 1),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditor), findsOneWidget);
        expect(focused(tester), isFalse, reason: 'the edit form doesn’t focus');
        final editable = find.descendant(
          of: title(),
          matching: find.byType(EditableText),
        );
        expect(tester.widget<EditableText>(editable).controller.text, words);
        final position = tester
            .state<ScrollableState>(
              find.descendant(of: editable, matching: find.byType(Scrollable)),
            )
            .position;
        expect(position.maxScrollExtent, 0, reason: 'all of it shows');
        final layout = titleLayout(tester);
        expect(layout.whole, isTrue);
        expect(layout.lines, greaterThan(3), reason: 'longer than the cap');
        final render = tester.state<EditableTextState>(editable).renderEditable;
        final field = tester.getRect(editable);
        final dni = render.localToGlobal(
          render
              .getLocalRectForCaret(const TextPosition(offset: words.length - 1))
              .center,
        );
        expect(field.contains(dni), isTrue, reason: '«DNI» shows');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1004: «Elegir día» opens a sheet titled «Elegir día» with no time switch and no «Listo»; a date 9 days ahead tapped closes it, the third chip shows that date, and the time set before is kept',
      (tester) async {
        final app = await _App.open(tester);
        await openForm(tester);
        await typeTitle(tester, 'Renovar el DNI');
        await tester.tap(chip('new-task-today'));
        await tester.pumpAndSettle();
        await tester.tap(chip('new-task-time'));
        await tester.pumpAndSettle();
        final dialog = find.byType(TimePickerDialog);
        await tester.tap(
          find.text(MaterialLocalizations.of(tester.element(dialog)).okButtonLabel),
        );
        await tester.pumpAndSettle();
        final hour = (TimeOfDay.now().hour + 1) % 24;
        final form = tester.element(find.byType(TaskEditor));
        final time = form.clockTime(DateTime(2030, 1, 1, hour));
        expect(find.widgetWithText(InputChip, time), findsOneWidget);

        await tester.tap(chip('new-task-pick-day'));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        expect(es.pickDay, 'Elegir día');
        expect(
          find.descendant(of: sheet, matching: find.text(es.pickDay)),
          findsOneWidget,
        );
        expect(find.text(es.reviewSchedule), findsNothing);
        expect(find.byKey(const ValueKey('schedule-has-time')), findsNothing);
        expect(find.byKey(const ValueKey('schedule-hour')), findsNothing);
        expect(find.byKey(const ValueKey('schedule-minute')), findsNothing);
        expect(find.byKey(const ValueKey('schedule-done')), findsNothing);

        final later = plus(today, 9);
        final calendar = find.descendant(
          of: sheet,
          matching: find.byType(CalendarDatePicker),
        );
        expect(calendar, findsOneWidget);
        if (later.month != today.month) {
          await tester.tap(
            find.descendant(
              of: calendar,
              matching: find.byTooltip(
                MaterialLocalizations.of(
                  tester.element(calendar),
                ).nextMonthTooltip,
              ),
            ),
          );
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.descendant(of: calendar, matching: find.text('${later.day}')),
        );
        await tester.pumpAndSettle();
        expect(sheet, findsNothing, reason: 'the day applied at once');
        expect(selected(tester, 'new-task-pick-day'), isTrue);
        expect(
          find.descendant(
            of: chip('new-task-pick-day'),
            matching: find.text(form.weekdayDate(later)),
          ),
          findsOneWidget,
        );
        expect(selected(tester, 'new-task-today'), isFalse);
        expect(
          find.widgetWithText(InputChip, time),
          findsOneWidget,
          reason: 'the time stays on the new day',
        );
        await tapSave(tester);
        final saved = app.tasks.state.requireValue.single;
        expect(
          saved.dueDate,
          DateTime(later.year, later.month, later.day, hour),
        );
        expect(saved.hasTime, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1004: «Añadir hora» and the time chip open the time picker on its number boxes (TimePickerEntryMode.input)',
      (tester) async {
        await _App.open(tester);
        await openForm(tester);
        await tester.tap(chip('new-task-tomorrow'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ActionChip, es.addTime));
        await tester.pumpAndSettle();
        final dialog = find.byType(TimePickerDialog);
        expect(
          tester.widget<TimePickerDialog>(dialog).initialEntryMode,
          TimePickerEntryMode.input,
        );
        await tester.tap(
          find.text(MaterialLocalizations.of(tester.element(dialog)).okButtonLabel),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(InputChip));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TimePickerDialog>(dialog).initialEntryMode,
          TimePickerEntryMode.input,
          reason: 'the time chip too',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1004: the edit form’s date sheet keeps «Fecha y hora», its time switch and «Listo»',
      (tester) async {
        await _App.open(
          tester,
          tasks: [Task(id: 1, title: 'Médico', priority: 1, dueDate: tomorrow)],
        );
        unawaited(
          Navigator.of(
            tester.element(find.byType(CalendarScreen)),
          ).pushNamed('/editTask', arguments: 1),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditor), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('task-date')));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(
          find.descendant(of: sheet, matching: find.text(es.reviewSchedule)),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('schedule-has-time')), findsOneWidget);
        expect(find.byKey(const ValueKey('schedule-done')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    /// The calendar in the open date sheet.
    Finder sheetCalendar() => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(CalendarDatePicker),
    );

    /// The calendar's month header («octubre de 2026 ▾») tapped: the year
    /// grid opens.
    Future<void> openYearGrid(WidgetTester tester, DateTime shown) async {
      final calendar = sheetCalendar();
      final header = MaterialLocalizations.of(
        tester.element(calendar),
      ).formatMonthYear(DateTime(shown.year, shown.month));
      await tester.tap(
        find.descendant(of: calendar, matching: find.text(header)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(YearPicker), findsOneWidget, reason: 'year grid');
    }

    Future<void> tapYear(WidgetTester tester, int year) async {
      final cell = find.descendant(
        of: find.byType(YearPicker),
        matching: find.text('$year'),
      );
      await tester.ensureVisible(cell);
      await tester.pumpAndSettle();
      await tester.tap(cell);
      await tester.pumpAndSettle();
    }

    /// The form's third chip still reads «Elegir día»: no day applied.
    void pickDayUnapplied(WidgetTester tester) {
      expect(
        find.descendant(
          of: chip('new-task-pick-day'),
          matching: find.text(es.pickDay),
        ),
        findsOneWidget,
      );
      expect(selected(tester, 'new-task-pick-day'), isFalse);
    }

    testWidgets(
      'UX-1224: «Elegir día», the month header, then next year: the sheet stays open on that year’s month and nothing is applied; day 15 then closes it, the third chip shows that date, and the time set before is kept',
      (tester) async {
        final app = await _App.open(tester);
        await openForm(tester);
        await typeTitle(tester, 'Renovar el DNI');
        await tester.tap(chip('new-task-today'));
        await tester.pumpAndSettle();
        await tester.tap(chip('new-task-time'));
        await tester.pumpAndSettle();
        final dialog = find.byType(TimePickerDialog);
        await tester.tap(
          find.text(MaterialLocalizations.of(tester.element(dialog)).okButtonLabel),
        );
        await tester.pumpAndSettle();
        final hour = (TimeOfDay.now().hour + 1) % 24;
        final form = tester.element(find.byType(TaskEditor));
        final time = form.clockTime(DateTime(2030, 1, 1, hour));
        expect(find.widgetWithText(InputChip, time), findsOneWidget);

        await tester.tap(chip('new-task-pick-day'));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        await openYearGrid(tester, today);
        final next = today.year + 1;
        await tapYear(tester, next);

        expect(sheet, findsOneWidget, reason: 'a year pick doesn’t close it');
        expect(find.byType(YearPicker), findsNothing, reason: 'day grid back');
        final calendar = sheetCalendar();
        final material = MaterialLocalizations.of(tester.element(calendar));
        expect(
          find.descendant(
            of: calendar,
            matching: find.text(
              material.formatMonthYear(DateTime(next, today.month)),
            ),
          ),
          findsOneWidget,
          reason: 'a month of $next shows',
        );
        pickDayUnapplied(tester);
        expect(selected(tester, 'new-task-today'), isTrue, reason: 'Hoy stays');

        await tester.tap(
          find.descendant(of: calendar, matching: find.text('15')),
        );
        await tester.pumpAndSettle();
        expect(sheet, findsNothing, reason: 'a tapped day applies');
        final picked = DateTime(next, today.month, 15);
        expect(selected(tester, 'new-task-pick-day'), isTrue);
        expect(
          find.descendant(
            of: chip('new-task-pick-day'),
            matching: find.text(form.weekdayDate(picked)),
          ),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(InputChip, time),
          findsOneWidget,
          reason: 'the time stays',
        );
        await tapSave(tester);
        final saved = app.tasks.state.requireValue.single;
        expect(saved.dueDate, DateTime(next, today.month, 15, hour));
        expect(saved.hasTime, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1224: «Elegir día», the month header, then the year already shown: the sheet stays open and nothing is applied',
      (tester) async {
        await _App.open(tester);
        await openForm(tester);
        await typeTitle(tester, 'Renovar el DNI');
        await tester.tap(chip('new-task-pick-day'));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        await openYearGrid(tester, today);
        await tapYear(tester, today.year);
        expect(sheet, findsOneWidget, reason: 'still open');
        expect(find.byType(YearPicker), findsNothing);
        pickDayUnapplied(tester);
        for (final key in ['new-task-today', 'new-task-tomorrow']) {
          expect(selected(tester, key), isFalse, reason: key);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1224: in the edit form’s full date sheet a year pick still only selects: the sheet stays open with «Añadir hora» and «Listo»',
      (tester) async {
        await _App.open(
          tester,
          tasks: [Task(id: 1, title: 'Médico', priority: 1, dueDate: tomorrow)],
        );
        unawaited(
          Navigator.of(
            tester.element(find.byType(CalendarScreen)),
          ).pushNamed('/editTask', arguments: 1),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('task-date')));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        await openYearGrid(tester, tomorrow);
        await tapYear(tester, tomorrow.year + 1);
        expect(sheet, findsOneWidget, reason: 'only selects');
        expect(find.byKey(const ValueKey('schedule-has-time')), findsOneWidget);
        expect(
          find.descendant(of: sheet, matching: find.text(es.addTime)),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('schedule-done')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1006: an existing task’s «Añadir adjunto» sheet still explains its files in a paragraph',
      (tester) async {
        await _App.open(
          tester,
          tasks: [Task(id: 1, title: 'Médico', priority: 1, dueDate: tomorrow)],
        );
        unawaited(
          Navigator.of(
            tester.element(find.byType(CalendarScreen)),
          ).pushNamed('/editTask', arguments: 1),
        );
        await tester.pumpAndSettle();
        await showDetails(tester);
        final add = find.text(es.addAttachment);
        await tester.ensureVisible(add);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        final paragraphs =
            find
                .descendant(of: sheet, matching: find.text(es.fileLocalHelp))
                .evaluate()
                .length +
            find
                .descendant(of: sheet, matching: find.text(es.fileUploadHelp))
                .evaluate()
                .length;
        expect(paragraphs, 1);
        expect(
          find.descendant(of: sheet, matching: find.text(es.attachFile)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1007: notes typed, a file added and a project chosen under Más detalles stay on screen after «Menos detalles»; Recordatorio and Repetir at their defaults don’t, and nothing shows twice',
      (tester) async {
        // The phone's files: a folder of the test's own, and a picker that
        // hands back one PDF from it.
        final folder = Directory.systemTemp.createTempSync('taskflow-form-');
        addTearDown(() {
          try {
            folder.deleteSync(recursive: true);
          } catch (_) {}
        });
        final pdf = File(p.join(folder.path, 'analisis.pdf'))
          ..writeAsStringSync('resultados');
        const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
        platform.setMockMethodCallHandler(
          pathProvider,
          (_) async => p.join(folder.path, 'support'),
        );
        addTearDown(() => platform.setMockMethodCallHandler(pathProvider, null));
        FilePicker.platform = _OnePicked(pdf.path);

        await _App.open(
          tester,
          projects: [TaskListInfo(id: 'casa', name: 'Casa')],
        );
        await openForm(tester);
        await typeTitle(tester, 'Médico');
        await showDetails(tester);
        expect(find.text(es.fewerDetails), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('task-notes')),
          'Llevar los análisis',
        );
        await tester.pumpAndSettle();

        final add = find.text(es.addAttachment);
        await tester.ensureVisible(add);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pumpAndSettle();
        await tester.tap(find.text(es.attachFile));
        await tester.pump();
        for (var i = 0; i < 50 && find.text('analisis.pdf').evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.text('analisis.pdf'), findsOneWidget, reason: 'file added');

        final picker = find.byType(TaskAssignmentPicker);
        final projectRow = find.descendant(
          of: picker,
          matching: find.byType(ListTile),
        );
        await tester.ensureVisible(projectRow.first);
        await tester.pumpAndSettle();
        await tester.tap(projectRow.first);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: find.byType(BottomSheet), matching: find.text('Casa')),
        );
        await tester.pumpAndSettle();

        // «Menos detalles».
        final toggle = find.byKey(const ValueKey('task-more-details'));
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text(es.moreDetails), findsOneWidget, reason: 'closed');

        for (final (what, finder) in [
          ('notes', find.text('Llevar los análisis')),
          ('file', find.text('analisis.pdf')),
          ('project', find.descendant(of: picker, matching: find.text('Casa'))),
        ]) {
          expect(finder, findsOneWidget, reason: what);
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          expect(finder.hitTestable(), findsOneWidget, reason: what);
        }
        expect(find.byKey(const ValueKey('task-notes')), findsOneWidget);
        expect(picker, findsOneWidget);
        expect(find.byType(ReminderControl), findsNothing);
        expect(find.byKey(const ValueKey('task-repeat')), findsNothing);
        expect(find.text(es.addAttachment), findsNothing, reason: 'empty rows wait');
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- Renders, on request: --dart-define=WRITE_FORM_PREVIEWS=true ----
  // Last in the file: they load the app's fonts, which every later test
  // would then use.

  testWidgets(
    'previews of the form, its details, 2× text in ES and CA, the sheet’s Escribir, the people filter and Creada por (written to build/ on request)',
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
        // A day chip puts the keyboard away; tapping the title brings it
        // back.
        await tester.tap(title());
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await shoot('new-task-form-2x-$language');
        tester.view.resetViewInsets();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      }

      // The sheet with dictations left: Escribir opens the form.
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

/// The phone's file picker, handing back [path].
class _OnePicked extends FilePicker {
  _OnePicked(this.path);
  final String path;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(
      path: path,
      name: p.basename(path),
      size: File(path).lengthSync(),
    ),
  ]);
}
