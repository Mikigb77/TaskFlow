// UX loop 2026-10-13-app, round 1: a task's detail.
// P10 (UX-213, UX-214): only what's set, and a tap on a line changes it.
// P42 (UX-208, UX-211): deleting has Undo instead of a question, and Back in
// the edit form keeps the work.
// Round 2, P70 (UX-471, UX-472, UX-473): every row answers, taps are spoken,
// Save offers Undo.
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/task_assignment_picker.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/widgets/reminder_control.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:agenda/widgets/task_actions.dart';
import 'package:agenda/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:agenda/repositories/cloud_task_repository.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/button_label.dart';
import 'support/icon_button_label.dart';
import 'support/design_fixtures.dart';
import 'support/never_syncing_tasks.dart';
import 'support/reminder_fixtures.dart';

final es = lookupAppLocalizations(const Locale('es'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const timeoutChannel = MethodChannel('taskflow/accessibility');
  setUp(() {
    // Messages stay for 10 s, the phone's accessibility timeout.
    platform.setMockMethodCallHandler(timeoutChannel, (_) async => 10000);
  });
  tearDown(() => platform.setMockMethodCallHandler(timeoutChannel, null));

  final now = DateTime.now();
  final friday = () {
    var day = DateTime(now.year, now.month, now.day + 2);
    while (day.weekday != DateTime.friday) {
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return DateTime(day.year, day.month, day.day, 10);
  }();

  /// A plain task: no notes, attachments or project, default priority.
  Task plain({int id = 1, bool completed = false}) => Task(
    id: id,
    title: 'Pedir cita',
    priority: 1,
    dueDate: friday,
    isCompleted: completed,
  );

  /// Any text on screen, in any case, containing [part].
  Finder anyText(String part) => find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        (widget.data ?? widget.textSpan?.toPlainText() ?? '')
            .toLowerCase()
            .contains(part.toLowerCase()),
  );

  testWidgets(
    'UX-213: a plain task shows no TU PRÓXIMO PASO, no priority, no Notas or Adjuntos section and no project chip',
    (tester) async {
      await _App.open(tester, [plain()]);
      await _App.detail(tester, 1);
      expect(find.text('Pedir cita'), findsOneWidget);
      expect(anyText('próximo paso'), findsNothing);
      expect(anyText(es.priority), findsNothing);
      expect(anyText('Baja'), findsNothing);
      expect(anyText(es.notes), findsNothing);
      expect(anyText('Sin texto añadido'), findsNothing);
      expect(anyText(es.attachments), findsNothing);
      expect(anyText('No hay archivos adjuntos'), findsNothing);
      expect(find.byType(TaskAssignmentPicker), findsNothing);
      expect(find.text(es.audiencePersonal), findsNothing);
      // What it has: its day and time, in one row (P280, UX-2410).
      expect(find.text(es.plannedFor), findsOneWidget);
      expect(find.text(es.time), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-213: what is set still shows: a high priority, notes, and the project chip once a project exists',
    (tester) async {
      await _App.open(
        tester,
        [plain().copyWith(priority: 3, notes: 'Llevar la tarjeta sanitaria')],
        projects: [TaskListInfo(id: 'casa', name: 'Casa')],
      );
      await _App.detail(tester, 1);
      expect(find.text(es.priority), findsOneWidget);
      expect(find.text('Llevar la tarjeta sanitaria'), findsOneWidget);
      expect(find.byType(TaskAssignmentPicker), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-213: a completed task shows Tarea completada, not COMPLETADAS',
    (tester) async {
      await _App.open(tester, [plain(completed: true)]);
      await _App.detail(tester, 1);
      expect(es.taskCompleted, 'Tarea completada');
      expect(anyText(es.taskCompleted), findsOneWidget);
      expect(anyText('Completadas'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-214: tapping the date row opens the schedule sheet, as Cambiar fecha does',
    (tester) async {
      await _App.open(tester, [plain()]);
      await _App.detail(tester, 1);
      await tester.tap(find.text(es.plannedFor));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-done')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('UX-214: tapping the title opens the edit form', (tester) async {
    await _App.open(tester, [plain()]);
    await _App.detail(tester, 1);
    await tester.tap(find.text('Pedir cita'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditor), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('task-title')))
          .controller!
          .text,
      'Pedir cita',
    );
    expect(tester.takeException(), isNull);
  });

  // ---- P42 · UX-208: delete with Undo ----

  testWidgets(
    'UX-208: deleting a plain task from its detail asks nothing, closes the detail and says Tarea eliminada with Deshacer; Deshacer brings it back with its date, reminder and steps',
    (tester) async {
      final task = plain().copyWith(
        reminderMinutes: 30,
        checklist: [
          ChecklistItem(id: 'a', title: 'Llamar al centro'),
          ChecklistItem(id: 'b', title: 'Apuntar la hora'),
        ],
      );
      final app = await _App.open(tester, [task]);
      await _App.detail(tester, 1);
      await tester.tap(find.byTooltip(es.deleteTask));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TaskDetailScreen), findsNothing);
      expect(es.taskDeleted, 'Tarea eliminada');
      expect(find.text(es.taskDeleted), findsOneWidget);
      expect(find.text(es.undo), findsOneWidget);
      expect(app.repository.rows, isEmpty);
      expect(app.tasks(), isEmpty);

      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      final back = app.tasks().single;
      expect(back.title, 'Pedir cita');
      expect(back.dueDate, friday);
      expect(back.reminderMinutes, 30);
      expect(back.checklist.map((step) => step.title), [
        'Llamar al centro',
        'Apuntar la hora',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-208: deleting a repeating task asks first, with Conservar tarea as the filled button and Eliminar as a text button in the error colour',
    (tester) async {
      final app = await _App.open(tester, [
        plain().copyWith(recurrence: 'weekly', title: 'Regar las plantas'),
      ]);
      await _App.detail(tester, 1);
      await tester.tap(find.byTooltip(es.deleteTask));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(
          of: dialog,
          matching: find.text(es.deleteSeriesHelp('Regar las plantas')),
        ),
        findsOneWidget,
      );
      final keep = find.descendant(
        of: dialog,
        matching: find.widgetWithText(FilledButton, es.keepTask),
      );
      expect(keep, findsOneWidget);
      expect(es.keepTask, 'Conservar tarea');
      final delete = find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextButton, es.delete),
      );
      expect(delete, findsOneWidget);
      expect(
        tester.widget<TextButton>(delete).style?.foregroundColor?.resolve({}),
        Theme.of(tester.element(dialog)).colorScheme.error,
      );
      await tester.tap(keep);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TaskDetailScreen), findsOneWidget);
      expect(app.tasks(), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-208: a note deletes the same way, with Nota eliminada and Deshacer',
    (tester) async {
      final app = await _App.open(tester, [
        Task(
          id: 1,
          kind: 'note',
          title: 'Horario del médico',
          priority: 1,
          notes: 'De 9 a 14',
        ),
      ]);
      await _App.detail(tester, 1);
      await tester.tap(find.byTooltip(es.deleteNote));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TaskDetailScreen), findsNothing);
      expect(es.noteDeleted, 'Nota eliminada');
      expect(find.text(es.noteDeleted), findsOneWidget);
      expect(app.tasks(), isEmpty);
      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      final back = app.tasks().single;
      expect(back.isNote, isTrue);
      expect(back.notes, 'De 9 a 14');
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P42 · UX-211: Back in the edit form keeps the work ----

  Future<void> openEditor(WidgetTester tester) async {
    await _App.detail(tester, 1);
    await tester.tap(find.byTooltip(es.editTask));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditor), findsOneWidget);
  }

  Finder title() => find.byKey(const ValueKey('task-title'));

  testWidgets(
    'UX-211: change the title and press Back → saved, with Cambios guardados · Deshacer; Deshacer restores the old title',
    (tester) async {
      final app = await _App.open(tester, [plain()]);
      await openEditor(tester);
      await tester.enterText(title(), 'Pedir cita al dentista');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsNothing);
      expect(app.tasks().single.title, 'Pedir cita al dentista');
      expect(es.changesSaved, 'Cambios guardados');
      final message = find.byType(SnackBar);
      expect(message, findsOneWidget);
      expect(
        find.descendant(of: message, matching: find.text(es.changesSaved)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: message, matching: find.text(es.undo)),
        findsOneWidget,
      );
      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      expect(app.tasks().single.title, 'Pedir cita');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-211: with no change, Back just closes the form, with no message',
    (tester) async {
      final app = await _App.open(tester, [plain()]);
      await openEditor(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsNothing);
      expect(find.byType(TaskDetailScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(app.repository.updates, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-211: with the title emptied, Back shows the field’s error and stays',
    (tester) async {
      final app = await _App.open(tester, [plain()]);
      await openEditor(tester);
      await tester.enterText(title(), '');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsOneWidget);
      expect(find.text(es.titleRequiredField), findsOneWidget);
      expect(app.tasks().single.title, 'Pedir cita');
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Round 2 · P70 · UX-471: every row in the card answers ----

  /// A task with everything the card can show: a duration, a deadline, a
  /// weekly repeat and priority Alta.
  Task full({String? listId}) => plain().copyWith(
    durationMinutes: 45,
    deadline: DateTime(friday.year, friday.month, friday.day + 3, 18),
    deadlineHasTime: true,
    recurrence: 'weekly',
    priority: 3,
    listId: listId,
  );

  for (final row in ['duration', 'deadline', 'repeat', 'priority']) {
    testWidgets('UX-471: tapping the $row row opens the edit form', (
      tester,
    ) async {
      final label = switch (row) {
        'duration' => es.duration,
        'deadline' => es.deadline,
        'repeat' => es.repeat,
        _ => es.priority,
      };
      expect(label, switch (row) {
        'duration' => 'Duración',
        'deadline' => 'Fecha límite',
        'repeat' => 'Repetir',
        _ => 'Prioridad',
      });
      await _App.open(tester, [full()]);
      await _App.detail(tester, 1);
      final target = find.text(label);
      expect(target, findsOneWidget);
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('task-title')))
            .controller!
            .text,
        'Pedir cita',
      );
      expect(find.byKey(const ValueKey('schedule-done')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('UX-471: for a view-only task, tapping Repetir opens nothing', (
    tester,
  ) async {
    await _App.open(
      tester,
      [full(listId: 'familia')],
      projects: [
        TaskListInfo(
          id: 'familia',
          name: 'Familia',
          role: 'viewer',
          shared: true,
        ),
      ],
    );
    await _App.detail(tester, 1);
    final repeat = find.text(es.repeat);
    await tester.ensureVisible(repeat);
    await tester.pumpAndSettle();
    await tester.tap(repeat, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditor), findsNothing);
    expect(find.byKey(const ValueKey('schedule-done')), findsNothing);
    expect(find.byType(TaskDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ---- Round 2 · P70 · UX-472: TalkBack says what a tap does ----

  /// The tap hint of the node that handles a tap on [finder].
  String? tapHint(WidgetTester tester, Finder finder) {
    SemanticsNode? node = tester.getSemantics(finder);
    while (node != null &&
        !node.getSemanticsData().hasAction(SemanticsAction.tap)) {
      node = node.parent;
    }
    expect(node, isNotNull, reason: 'something handles a tap on $finder');
    final data = node!.getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue, reason: '$finder');
    for (final id in data.customSemanticsActionIds ?? const <int>[]) {
      final action = CustomSemanticsAction.getAction(id);
      if (action?.action == SemanticsAction.tap) return action!.hint;
    }
    return null;
  }

  testWidgets(
    'UX-472: Planificado para says Cambiar fecha; Repetir and the title say Editar tarea; a note’s title says Editar nota',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _App.open(tester, [
        full(),
        Task(
          id: 2,
          kind: 'note',
          title: 'Horario del médico',
          priority: 1,
          notes: 'De 9 a 14',
        ),
      ]);
      await _App.detail(tester, 1);
      expect(es.reschedule, 'Cambiar fecha');
      expect(es.editTask, 'Editar tarea');
      expect(es.editNote, 'Editar nota');
      expect(tapHint(tester, find.text(es.plannedFor)), es.reschedule);
      expect(tapHint(tester, find.text('Pedir cita')), es.editTask);
      await tester.ensureVisible(find.text(es.repeat));
      await tester.pumpAndSettle();
      expect(tapHint(tester, find.text(es.repeat)), es.editTask);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _App.detail(tester, 2);
      expect(tapHint(tester, find.text('Horario del médico')), es.editNote);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Round 2 · P70 · UX-473: Save offers Undo too ----

  testWidgets(
    'UX-473: change the title and tap Guardar cambios → Cambios guardados · Deshacer; Deshacer restores the old title',
    (tester) async {
      final app = await _App.open(tester, [plain()]);
      await openEditor(tester);
      await tester.enterText(title(), 'Pedir cita al dentista');
      await tester.pumpAndSettle();
      await tester.tap(find.text(es.saveChangesSentence));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsNothing);
      expect(app.tasks().single.title, 'Pedir cita al dentista');
      final message = find.byType(SnackBar);
      expect(message, findsOneWidget);
      expect(
        find.descendant(of: message, matching: find.text(es.changesSaved)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: message, matching: find.text(es.undo)),
        findsOneWidget,
      );
      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      expect(app.tasks().single.title, 'Pedir cita');
      expect(tester.takeException(), isNull);
    },
  );

  // ---- Round 3 · P71 · UX-474: Save on an untouched form just closes ----

  testWidgets(
    'UX-474: with no change, Guardar cambios just closes the form, with no message and no write',
    (tester) async {
      final app = await _App.open(tester, [plain()]);
      await openEditor(tester);
      expect(es.saveChangesSentence, 'Guardar cambios');
      await tester.tap(find.text(es.saveChangesSentence));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsNothing);
      expect(find.byType(TaskDetailScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(es.changesSaved), findsNothing);
      expect(find.text(es.undo), findsNothing);
      expect(app.repository.updates, 0);
      expect(app.tasks().single.title, 'Pedir cita');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-474: a title typed and put back counts as unchanged; Guardar cambios just closes',
    (tester) async {
      final app = await _App.open(tester, [plain()]);
      await openEditor(tester);
      await tester.enterText(title(), 'Pedir cita al dentista');
      await tester.pumpAndSettle();
      await tester.enterText(title(), 'Pedir cita');
      await tester.pumpAndSettle();
      await tester.tap(find.text(es.saveChangesSentence));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(app.repository.updates, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-474: with the title emptied, Guardar cambios shows the field’s error and stays, with no message and no write',
    (tester) async {
      final app = await _App.open(tester, [plain()]);
      await openEditor(tester);
      await tester.enterText(title(), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text(es.saveChangesSentence));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsOneWidget);
      expect(find.text(es.titleRequiredField), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(app.repository.updates, 0);
      expect(app.tasks().single.title, 'Pedir cita');
      expect(tester.takeException(), isNull);
    },
  );

  // ---- 2026-10-18 (later): «Creada por» on a shared task ----

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
    ],
  );

  /// A task in [listId] as the server sends it, with its creator's name.
  Task fromServer({String? listId = 'familia', Object? name = 'Ana'}) =>
      Task.fromApi({
        ...Task(
          title: 'Comprar pan',
          priority: 1,
          dueDate: friday,
          listId: listId,
          assignment: listId == 'familia' ? 'group' : 'personal',
        ).toApi(),
        'created_by': 2,
        'created_by_name': name,
      }).copyWith(id: 1);

  Finder createdBy() => find.byKey(const ValueKey('task-created-by'));

  testWidgets(
    '«Creada por Ana» on a task in a shared project, from the server’s created_by_name, under the project and who it’s for',
    (tester) async {
      await _App.open(tester, [fromServer()], projects: [familia]);
      await _App.detail(tester, 1);
      expect(es.createdBy('Ana'), 'Creada por Ana');
      expect(createdBy(), findsOneWidget);
      expect(tester.widget<Text>(createdBy()).data, 'Creada por Ana');
      final picker = find.byType(TaskAssignmentPicker);
      expect(picker, findsOneWidget);
      expect(
        find.descendant(of: picker, matching: find.text(es.assignedToGroup)),
        findsOneWidget,
      );
      expect(
        tester.getRect(createdBy()).top,
        greaterThanOrEqualTo(tester.getRect(picker).bottom - 0.5),
        reason: 'right under who it’s for',
      );
      expect(
        tester.getRect(createdBy()).top,
        lessThan(tester.getRect(find.text(es.plannedFor)).top),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final (what, task, projects) in [
    (
      'the server sends no name (the account left or was deleted)',
      () => fromServer(name: null),
      () => [familia],
    ),
    (
      'the project is personal',
      () => fromServer(listId: 'casa'),
      () => [TaskListInfo(id: 'casa', name: 'Casa', version: 1)],
    ),
    (
      'the task has no project',
      () => fromServer(listId: null),
      () => [familia],
    ),
  ]) {
    testWidgets('no «Creada por» when $what', (tester) async {
      await _App.open(tester, [task()], projects: projects());
      await _App.detail(tester, 1);
      expect(createdBy(), findsNothing);
      expect(find.textContaining('Creada por'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('editing a shared task keeps «Creada por Ana»', (tester) async {
    final app = await _App.open(tester, [fromServer()], projects: [familia]);
    await openEditor(tester);
    await tester.enterText(title(), 'Comprar pan y leche');
    await tester.pumpAndSettle();
    await tester.tap(find.text(es.saveChangesSentence));
    await tester.pumpAndSettle();
    expect(app.tasks().single.title, 'Comprar pan y leche');
    expect(app.tasks().single.createdByName, 'Ana');
    await _App.detail(tester, 1);
    expect(createdBy(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('«Creada por» reads Created by / Creada por / Creada per', () {
    expect(
      lookupAppLocalizations(const Locale('en')).createdBy('Ana'),
      'Created by Ana',
    );
    expect(es.createdBy('Ana'), 'Creada por Ana');
    expect(
      lookupAppLocalizations(const Locale('ca')).createdBy('Ana'),
      'Creada per Ana',
    );
  });

  // ---- Run 2026-10-18-commands, b3 · P140 (UX-1008): the signed-in
  // account is «ti», as who it's for calls it «Yo» ----

  /// A shared task as the server sends it, created by account [by].
  Task createdByAccount(int by, String name) => Task.fromApi({
    ...Task(
      title: 'Comprar pan',
      priority: 1,
      dueDate: friday,
      listId: 'familia',
      assignment: 'group',
    ).toApi(),
    'created_by': by,
    'created_by_name': name,
  }).copyWith(id: 1);

  for (final (language, you) in [
    ('es', 'Creada por ti'),
    ('en', 'Created by you'),
    ('ca', 'Creada per tu'),
  ]) {
    testWidgets(
      'UX-1008: a shared task the signed-in account created reads «$you» ($language); Ana’s still reads her name',
      (tester) async {
        final l = lookupAppLocalizations(Locale(language));
        expect(l.createdByYou, you);
        // The fixture's signed-in account is 1, Miki.
        await _App.open(
          tester,
          [createdByAccount(1, 'Miki')],
          projects: [familia],
          language: language,
        );
        await _App.detail(tester, 1);
        expect(createdBy(), findsOneWidget);
        expect(tester.widget<Text>(createdBy()).data, you);
        expect(find.text(l.createdBy('Miki')), findsNothing);
        await tester.pumpWidget(const SizedBox());

        await _App.open(
          tester,
          [createdByAccount(2, 'Ana')],
          projects: [familia],
          language: language,
        );
        await _App.detail(tester, 1);
        expect(tester.widget<Text>(createdBy()).data, l.createdBy('Ana'));
        expect(find.text(you), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['es', 'ca']) {
    testWidgets(
      'at 2× text on 320 dp ($language), «Creada por» with a long name reads in full with no overflow',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _App.open(
          tester,
          [fromServer(name: 'Maria Antònia Ferrer i Puigdollers')],
          projects: [familia],
          language: language,
          size: const Size(320, 640),
        );
        await _App.detail(tester, 1);
        // At 2× text it sits below the first screenful: scrolled to.
        await tester.ensureVisible(
          find.byKey(const ValueKey('task-created-by'), skipOffstage: false),
        );
        await tester.pumpAndSettle();
        final line = createdBy();
        expect(line, findsOneWidget);
        expect(line.hitTestable(), findsOneWidget);
        final rect = tester.getRect(line);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320.5));
        expect(
          tester.widget<Text>(line).data,
          lookupAppLocalizations(
            Locale(language),
          ).createdBy('Maria Antònia Ferrer i Puigdollers'),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- Run 2026-10-19-app, round 1 · P179 (UX-1415, UX-1417) ----

  Task withNotesAndSteps() => Task(
    id: 76,
    title: 'Ir al médico',
    dueDate: friday,
    priority: 1,
    reminderMinutes: 60,
    notes: 'Ir en ayunas. Llevar la tarjeta sanitaria y el volante.',
    checklist: [
      ChecklistItem(id: 's1', title: 'Pedir el volante'),
      ChecklistItem(id: 's2', title: 'Cenar ligero la noche antes'),
      ChecklistItem(id: 's3', title: 'Recoger los resultados'),
    ],
  );

  /// The detail of [task], with one file attached.
  Future<void> openWithFile(
    WidgetTester tester,
    Task task, {
    Size size = const Size(390, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = designContainer(
      regionalStore: MemoryRegionalStore(
        const RegionalPreferences(language: 'es'),
      ),
      tasks: () => TaskNotifier(_Repository([task])),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ProviderScope(
          overrides: [
            attachmentEntriesProvider.overrideWith(
              (ref, id) async => [
                const AttachmentEntry(
                  'Volante.pdf',
                  '/local/volante.pdf',
                  true,
                ),
              ],
            ),
          ],
          child: const MyApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _App.detail(tester, task.id!);
  }

  testWidgets(
    'UX-1415: the detail reads title, date card, Notas, reminder, Pasos, Archivos, with no «Marcar todos los pasos…» line',
    (tester) async {
      final task = withNotesAndSteps();
      await openWithFile(tester, task);
      final detail = find.byType(TaskDetailScreen);
      Finder inDetail(Finder finder) =>
          find.descendant(of: detail, matching: finder);
      double top(Finder finder) {
        expect(finder, findsWidgets);
        return tester.getRect(finder.first).top;
      }

      final order = [
        ('title', top(inDetail(find.text('Ir al médico')))),
        ('date card', top(inDetail(find.text(es.plannedFor)))),
        ('Notas', top(inDetail(find.text(es.notes.toUpperCase())))),
        ('reminder', top(inDetail(find.byType(ReminderChip)))),
        (
          'Pasos',
          top(inDetail(find.text(es.checklistCount(0, 3).toUpperCase()))),
        ),
        ('Archivos', top(inDetail(find.text(es.attachments.toUpperCase())))),
      ];
      for (var i = 1; i < order.length; i++) {
        expect(
          order[i].$2,
          greaterThan(order[i - 1].$2),
          reason: '${order[i].$1} comes after ${order[i - 1].$1}',
        );
      }
      expect(anyText('Marcar todos los pasos'), findsNothing);
      expect(anyText('Mark all steps'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UX-1415: at 1.3× on 360×800 (tasks/detail.notes-steps) a task’s notes show above the fold',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _App.open(tester, [
        withNotesAndSteps(),
      ], size: const Size(360, 800));
      await _App.detail(tester, 76);
      final detail = find.byType(TaskDetailScreen);
      final scaffold = tester.widget<Scaffold>(
        find.descendant(of: detail, matching: find.byType(Scaffold)).first,
      );
      final fold = scaffold.bottomNavigationBar == null
          ? 800.0
          : tester.getRect(find.byWidget(scaffold.bottomNavigationBar!)).top;
      final notes = find.descendant(
        of: detail,
        matching: find.textContaining('Ir en ayunas', findRichText: true),
      );
      expect(notes, findsWidgets);
      expect(
        tester.getRect(notes.first).top,
        lessThan(fold - 16),
        reason: 'the notes start above the Completar bar',
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('UX-1417: the task page’s title reads Task / Tarea / Tasca', () {
    expect(lookupAppLocalizations(const Locale('en')).taskScreenTitle, 'Task');
    expect(es.taskScreenTitle, 'Tarea');
    expect(lookupAppLocalizations(const Locale('ca')).taskScreenTitle, 'Tasca');
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'UX-1417: at ${scale}x on 360×800 a task’s app bar reads «Tarea», not cut; a note’s reads «Nota»; ✏ and 🗑 are at least 8 dp apart',
      (tester) async {
        if (scale != 1) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        }
        await _App.open(tester, [
          plain(),
          Task(
            id: 2,
            title: 'Recetas',
            kind: 'note',
            priority: 1,
            notes: 'Tarta de queso',
          ),
        ], size: const Size(360, 800));
        await _App.detail(tester, 1);
        final bar = find.byType(AppBar);
        final title = find.descendant(
          of: bar,
          matching: find.text(es.taskScreenTitle),
        );
        expect(title, findsOneWidget);
        expect(anyText('Detalles de la tarea'), findsNothing);
        final paragraph = tester.renderObject<RenderParagraph>(title);
        expect(paragraph.didExceedMaxLines, isFalse);
        final whole = TextPainter(
          text: paragraph.text,
          textDirection: paragraph.textDirection,
          textScaler: paragraph.textScaler,
        )..layout();
        expect(
          paragraph.size.width,
          greaterThanOrEqualTo(whole.width - 0.5),
          reason: '«Tarea» shows whole',
        );
        whole.dispose();
        final edit = tester.getRect(
          find.widgetWithIcon(IconButton, Icons.edit_outlined),
        );
        final delete = tester.getRect(
          find.widgetWithIcon(IconButton, Icons.delete_outline_rounded),
        );
        expect(delete.left - edit.right, greaterThanOrEqualTo(8 - 0.5));
        expect(tester.takeException(), isNull);

        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
        await _App.detail(tester, 2);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text(es.note),
          ),
          findsOneWidget,
        );
        expect(es.note, 'Nota');
        expect(tester.takeException(), isNull);
      },
    );
  }
  // ---- 2026-10-28-app · P268 (UX-2301): a step's tick never waits on the
  // server; the sync runs behind ----

  group('P268 · steps show at once', () {
    testWidgets(
      'UX-2301: on a task’s page with a sync that never completes, a ticked step checks at once, and a second step ticked 300 ms later checks too',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final cloud = NeverSyncingTasks([
          plain().copyWith(
            checklist: [
              ChecklistItem(id: 'card', title: 'Llevar la tarjeta sanitaria'),
              ChecklistItem(id: 'note', title: 'Pedir el justificante'),
            ],
          ),
        ]);
        final container = designContainer(
          regionalStore: MemoryRegionalStore(
            const RegionalPreferences(language: 'es'),
          ),
          tasks: () => TaskNotifier(cloud),
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const MyApp()),
        );
        await tester.pumpAndSettle();
        expect(cloud.syncs, greaterThan(0), reason: 'a sync is under way');
        expect(cloud.finished, 0, reason: 'and it never finishes');
        await _App.detail(tester, 1);

        Finder step(String id) => find.byKey(ValueKey('check-step-$id'));
        bool? done(String id) =>
            tester.widget<CheckboxListTile>(step(id)).value;
        await tester.ensureVisible(step('note'));
        await tester.pumpAndSettle();
        expect(step('card').hitTestable(), findsOneWidget);
        expect(done('card'), isFalse);
        expect(done('note'), isFalse);

        await tester.tap(step('card'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(done('card'), isTrue, reason: 'the first step checks at once');
        expect(done('note'), isFalse);

        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(step('note'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(done('card'), isTrue);
        expect(done('note'), isTrue, reason: 'the second checks at once too');
        expect(
          cloud.byId(1)!.checklist.map((item) => item.completed),
          [true, true],
          reason: 'both are written on the phone',
        );
        expect(cloud.finished, 0);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- 2026-10-28-app · P271 (UX-2032, D9): a reader chooses their own
  // reminders, and nothing else opens ----

  group('P271 · a reader’s own reminders', () {
    final ca = lookupAppLocalizations(const Locale('ca'));
    final en = lookupAppLocalizations(const Locale('en'));
    final rehearsal = DateTime(friday.year, friday.month, friday.day, 19);

    /// «Ensayo del coro», a timed task in «Coro», where this account is
    /// «lector»: for «Todos» by default, or given to Marta.
    Map<String, dynamic> choirTask({bool forMarta = false}) => {
      ...Task(
        title: 'Ensayo del coro',
        priority: 1,
        dueDate: rehearsal,
        hasTime: true,
        reminderMinutes: 10,
        listId: _choir,
        assignment: forMarta ? 'member' : 'group',
        assigneeId: forMarta ? 2 : null,
        assigneeName: forMarta ? 'Marta' : null,
        checklist: [
          ChecklistItem(id: 'partitura', title: 'Llevar la partitura'),
        ],
      ).toApi(),
      'id': _choirTaskId,
      'version': 3,
      // As the server sends it: the name of whoever it's given to.
      'assignee_name': forMarta ? 'Marta' : null,
    };

    Finder actionChip() => find.descendant(
      of: find.byType(ReminderChip),
      matching: find.byType(ActionChip),
    );
    Finder chipReads(String text) => find.descendant(
      of: find.byType(ReminderChip),
      matching: find.text(text),
    );

    testWidgets(
      'UX-2032: on a «Todos» task in «Coro» (lector), ES 1× at 360×800, the banner says «… y elegir tus recordatorios», the chip is an enabled button that opens «solo para ti», and «1 hora antes» shows at once',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final phone = await _ReaderPhone.open(tester, choirTask());
        await phone.detail();
        expect(find.text(es.viewOnlyTaskReminders), findsOneWidget);
        expect(find.text(es.viewOnlyTask), findsNothing);

        final chip = actionChip();
        expect(chip, findsOneWidget, reason: 'the reminder line is a chip');
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(chip),
          isSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        expect(
          chipReads(es.reminderValue(es.minutesBefore(10))),
          findsOneWidget,
        );

        await tester.tap(chip);
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        final justYou = find.byKey(const ValueKey('reminder-plan-just-you'));
        expect(find.descendant(of: sheet, matching: justYou), findsOneWidget);
        expect(tester.widget<Text>(justYou).data, es.reminderPlanJustYou);
        final title = find.descendant(
          of: sheet,
          matching: find.text(es.reminder),
        );
        expect(title, findsOneWidget);
        expect(
          tester.getRect(justYou).top,
          greaterThanOrEqualTo(tester.getRect(title).bottom - 0.5),
          reason: 'under the sheet’s title',
        );

        final hour = find.descendant(
          of: sheet,
          matching: find.text(es.hourBefore),
        );
        await tester.ensureVisible(hour.first);
        await tester.pumpAndSettle();
        await tester.tap(hour.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          chipReads(es.reminderValue(es.hourBefore)),
          findsOneWidget,
          reason: 'the choice shows in the chip at once',
        );
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing, reason: 'it closes');
        expect(find.text(es.updateReminderError), findsNothing);

        // Only the reminders changed, kept on the phone to send.
        final row = await phone.row();
        expect(row['reminderMinutes'], 60);
        expect(row['title'], 'Ensayo del coro');
        expect(row['isCompleted'], 0);
        expect(row['sync_pending'], 1);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    for (final (l, language) in [(en, 'en'), (ca, 'ca')]) {
      testWidgets('UX-2032: the reader’s banner in $language', (tester) async {
        final phone = await _ReaderPhone.open(
          tester,
          choirTask(),
          language: language,
        );
        await phone.detail();
        expect(find.text(l.viewOnlyTaskReminders), findsOneWidget);
        expect(find.text(l.viewOnlyTask), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    test('UX-2032: the reader’s banner in the three catalogs', () {
      expect(
        es.viewOnlyTaskReminders,
        'Solo puedes ver esta tarea y elegir tus recordatorios.',
      );
      expect(
        en.viewOnlyTaskReminders,
        'You can only view this task and choose your reminders.',
      );
      expect(
        ca.viewOnlyTaskReminders,
        'Només pots veure aquesta tasca i triar els teus recordatoris.',
      );
      expect(es.viewOnlyTask, 'Solo puedes ver esta tarea.');
    });

    testWidgets(
      'UX-2032: on the reader’s «Todos» task there is no ✏, no 🗑, no bottom bar and no circle, and the title and its step open nothing',
      (tester) async {
        final phone = await _ReaderPhone.open(tester, choirTask());
        await phone.detail();
        expect(find.byTooltip(es.editTask), findsNothing);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.byTooltip(es.deleteTask), findsNothing);
        expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
        expect(find.text(es.complete), findsNothing);
        expect(find.text(es.reschedule), findsNothing);
        expect(
          find.bySemanticsLabel(es.completeNamedTask('Ensayo del coro')),
          findsNothing,
        );
        final scaffold = tester.widget<Scaffold>(
          find
              .descendant(
                of: find.byType(TaskDetailScreen),
                matching: find.byType(Scaffold),
              )
              .first,
        );
        expect(scaffold.bottomNavigationBar, isNull);

        await tester.tap(find.text('Ensayo del coro'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditor), findsNothing);
        expect(find.byType(TaskDetailScreen), findsOneWidget);

        final step = find.byKey(const ValueKey('check-step-partitura'));
        await tester.ensureVisible(step);
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(step).onChanged, isNull);
        await tester.tap(step, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(step).value, isFalse);
        expect(find.byType(TaskEditor), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);

        expect((await phone.row())['sync_pending'], 0, reason: 'no write');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2032: a reader on a «Coro» task given to Marta sees «Recordatorio para Marta» with no tap, and «Solo puedes ver esta tarea.»',
      (tester) async {
        final phone = await _ReaderPhone.open(
          tester,
          choirTask(forMarta: true),
        );
        await phone.detail();
        expect(find.text(es.viewOnlyTask), findsOneWidget);
        expect(find.text(es.viewOnlyTaskReminders), findsNothing);
        final line = chipReads(es.reminderForPersonOnly('Marta'));
        expect(line, findsOneWidget);
        expect(actionChip(), findsNothing, reason: 'information, no control');
        await tester.ensureVisible(line);
        await tester.pumpAndSettle();
        await tester.tap(line, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect((await phone.row())['sync_pending'], 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2032: after the choice, a new app on the same database shows «Recordatorio: 1 hora antes» before any sync',
      (tester) async {
        final phone = await _ReaderPhone.open(tester, choirTask());
        await phone.detail();
        await tester.ensureVisible(actionChip());
        await tester.pumpAndSettle();
        await tester.tap(actionChip());
        await tester.pumpAndSettle();
        final hour = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(es.hourBefore),
        );
        await tester.ensureVisible(hour.first);
        await tester.pumpAndSettle();
        await tester.tap(hour.first);
        await tester.pumpAndSettle();

        // The app closes; another starts on the same file, still offline.
        final again = await phone.restart();
        await again.detail();
        expect(chipReads(es.reminderValue(es.hourBefore)), findsOneWidget);
        expect(
          phone.api.requests.followedBy(again.api.requests),
          everyElement(isNot(startsWith('PUT'))),
          reason: 'nothing reached a server',
        );
        expect((await again.row())['reminderMinutes'], 60);
        expect((await again.row())['sync_pending'], 1, reason: 'still to send');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2032: a file on the reader’s «Todos» task can be opened but not removed or sent, and tapping it opens no editor',
      (tester) async {
        final phone = await _ReaderPhone.open(
          tester,
          choirTask(),
          files: const [
            AttachmentEntry('Partitura.pdf', '/local/partitura.pdf', true),
          ],
        );
        await phone.detail();
        final file = find.text('Partitura.pdf');
        await tester.ensureVisible(file);
        await tester.pumpAndSettle();
        expect(file, findsOneWidget);
        expect(find.text(es.fileOpen), findsOneWidget);
        expect(find.text(es.fileRemove), findsNothing);
        expect(find.text(es.fileUpload), findsNothing);

        await tester.tap(file, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditor), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(TaskDetailScreen), findsOneWidget);
        expect((await phone.row())['sync_pending'], 0, reason: 'no write');
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- Run 2026-10-28-app, round 1 · P280 (UX-2404, UX-2409, UX-2410,
  // UX-2416): Completar returns to the list, the date reads once, notes and
  // labels read as what they are ----

  group('P280 · a task’s page', () {
    final ca = lookupAppLocalizations(const Locale('ca'));
    final today = DateTime(now.year, now.month, now.day);

    /// The page's filled main button: Completar or Reabrir.
    Finder mainButton(String label) => find.descendant(
      of: find.byType(TaskDetailScreen),
      matching: find.widgetWithText(FilledButton, label),
    );

    Future<void> tapMain(WidgetTester tester, String label) async {
      final button = mainButton(label);
      expect(button, findsOneWidget, reason: '«$label» on the page');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
    }

    // ---- UX-2404 ----

    testWidgets(
      'UX-2404: Calendar row → task page → Completar shows Calendar again, the row ticked, with Tarea completada · Deshacer; Deshacer reopens it',
      (tester) async {
        final app = await _App.open(tester, [
          Task(
            id: 1,
            title: 'Pedir cita',
            priority: 1,
            dueDate: today,
            hasTime: false,
          ),
        ]);
        final row = find.widgetWithText(TaskTile, 'Pedir cita');
        expect(row, findsOneWidget, reason: 'today’s row on Calendar');
        await tester.tap(
          find.descendant(of: row, matching: find.text('Pedir cita')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TaskDetailScreen), findsOneWidget);

        await tapMain(tester, es.complete);
        await tester.pumpAndSettle();
        expect(find.byType(TaskDetailScreen), findsNothing, reason: 'closed');
        expect(find.byType(CalendarScreen), findsOneWidget);
        expect(app.tasks().single.isCompleted, isTrue);
        final ticked = find.descendant(
          of: find.widgetWithText(TaskTile, 'Pedir cita'),
          matching: find.byType(Checkbox),
        );
        expect(tester.widget<Checkbox>(ticked).value, isTrue);
        final message = find.byType(SnackBar);
        expect(message, findsOneWidget);
        expect(
          find.descendant(of: message, matching: find.text(es.taskCompleted)),
          findsOneWidget,
        );
        expect(find.text(es.undo), findsOneWidget, reason: 'one Deshacer');
        expect(find.text(es.reopen), findsNothing);

        await tester.tap(find.text(es.undo));
        await tester.pumpAndSettle();
        expect(app.tasks().single.isCompleted, isFalse);
        expect(tester.widget<Checkbox>(ticked).value, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2404: Reabrir on a task completed before it was opened keeps the page, which then offers Completar',
      (tester) async {
        final app = await _App.open(tester, [plain(completed: true)]);
        await _App.detail(tester, 1);
        await tapMain(tester, es.reopen);
        await tester.pumpAndSettle();
        expect(find.byType(TaskDetailScreen), findsOneWidget, reason: 'stays');
        expect(app.tasks().single.isCompleted, isFalse);
        expect(mainButton(es.complete), findsOneWidget);
        expect(mainButton(es.reopen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    /// The app on Calendar with a daily task that started three days ago,
    /// its page opened as Activity opens it: by id alone, no occurrence.
    Future<_App> openDailyAsActivity(WidgetTester tester) async {
      final app = await _App.open(tester, [
        Task(
          id: 1,
          title: 'Regar las plantas',
          priority: 1,
          dueDate: DateTime(today.year, today.month, today.day - 3),
          hasTime: false,
          recurrence: 'daily',
        ),
      ]);
      unawaited(
        Navigator.of(tester.element(find.byType(CalendarScreen))).push(
          MaterialPageRoute<void>(
            builder: (_) => const TaskDetailScreen(taskId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailScreen), findsOneWidget);
      return app;
    }

    final tomorrow = DateTime(today.year, today.month, today.day + 1);

    /// Pumps frame by frame while the page leaves, checking at each frame
    /// that it never shows tomorrow's day; [onFrame] runs at each one.
    Future<void> watchLeaving(
      WidgetTester tester, {
      Future<void> Function(int frame)? onFrame,
    }) async {
      final page = find.byType(TaskDetailScreen);
      final tomorrowLine = tester
          .element(page)
          .dayHeading(tomorrow, DateTime.now());
      var frames = 0;
      while (page.evaluate().isNotEmpty && frames < 120) {
        expect(
          find.descendant(
            of: page,
            matching: find.textContaining(tomorrowLine),
          ),
          findsNothing,
          reason: 'tomorrow’s day on the page at frame $frames',
        );
        await onFrame?.call(frames);
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }
      await tester.pumpAndSettle();
      expect(page, findsNothing, reason: 'the page closed');
    }

    testWidgets(
      'UX-2404: opened as Activity opens it, a daily task’s Completar closes the page with Tarea completada; tomorrow’s occurrence is never shown on it, nor completed',
      (tester) async {
        final app = await openDailyAsActivity(tester);
        final page = find.byType(TaskDetailScreen);
        final todayLine = tester
            .element(page)
            .dayHeading(today, DateTime.now());
        expect(
          find.descendant(of: page, matching: find.text(todayLine)),
          findsOneWidget,
          reason: 'today’s occurrence',
        );
        await tapMain(tester, es.complete);
        await watchLeaving(tester);
        final series = app.tasks().single;
        expect(series.completedDates, [Task.dateKey(today)]);
        expect(find.text(es.taskCompleted), findsOneWidget);
        expect(find.text(es.undo), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2404: a hesitant second tap on Completar while the page leaves doesn’t complete tomorrow’s occurrence',
      (tester) async {
        final app = await openDailyAsActivity(tester);
        await tapMain(tester, es.complete);
        final spot = tester.getCenter(mainButton(es.complete));
        await watchLeaving(
          tester,
          onFrame: (frame) async {
            // About 50, 200 and 400 ms after the first tap.
            if (frame != 3 && frame != 12 && frame != 25) return;
            await tester.tapAt(spot);
          },
        );
        final series = app.tasks().single;
        expect(series.completedDates, [Task.dateKey(today)]);
        expect(series.completedDates, isNot(contains(Task.dateKey(tomorrow))));
        // The taps land on the page's dead button, then on «Añadir tarea»
        // while the page leaves (P302): nothing opens.
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing, reason: 'no capture');
        expect(
          Navigator.of(tester.element(find.byType(CalendarScreen))).canPop(),
          isFalse,
          reason: 'nothing pushed over Calendar',
        );
        expect(tester.takeException(), isNull);
      },
    );

    // ---- UX-2409 ----

    /// The one node that reads [label] with [value].
    SemanticsFinder readNode(String label, String value) =>
        find.semantics.byPredicate(
          (node) =>
              node.getSemanticsData().label == label &&
              node.getSemanticsData().value == value,
        );

    SemanticsFinder textFields() => find.semantics.byPredicate(
      (node) => node.getSemanticsData().flagsCollection.isTextField,
    );

    testWidgets(
      'UX-2409: a task’s notes read as one node, «Notas» with the notes as value, not a button, and no unlabeled text field',
      (tester) async {
        final handle = tester.ensureSemantics();
        const notes = 'Llevar la tarjeta sanitaria';
        await _App.open(tester, [plain().copyWith(notes: notes)]);
        await _App.detail(tester, 1);
        final body = readNode(es.notes, notes);
        expect(body, findsOne);
        final data = body.evaluate().single.getSemanticsData();
        expect(data.flagsCollection.isButton, isFalse);
        expect(data.hasAction(SemanticsAction.tap), isFalse);
        expect(
          textFields(),
          findsNothing,
          reason: 'no «text field (no label)»',
        );
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    testWidgets(
      'UX-2409: notes with a link still read «Notas» with the notes as value, and the link is its own button',
      (tester) async {
        final handle = tester.ensureSemantics();
        const notes = 'Llevar la tarjeta sanitaria. https://example.com/cita';
        await _App.open(tester, [plain().copyWith(notes: notes)]);
        await _App.detail(tester, 1);
        expect(
          textFields(),
          findsNothing,
          reason: 'no «text field (no label)»',
        );
        final link = find.semantics.byPredicate(
          (node) =>
              node.getSemanticsData().flagsCollection.isButton &&
              node.getSemanticsData().label.contains(
                'https://example.com/cita',
              ),
        );
        expect(link, findsOne, reason: 'the link is its own button');
        expect(
          link.evaluate().single.getSemanticsData().hasAction(
            SemanticsAction.tap,
          ),
          isTrue,
        );
        final withValue = find.semantics.byPredicate(
          (node) => node.getSemanticsData().value == notes,
        );
        expect(withValue, findsOne);
        expect(
          withValue.evaluate().single.getSemanticsData().label,
          es.notes,
          reason: 'the node reads «Notas», then the notes',
        );
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    testWidgets('UX-2409: a long press on a task’s notes still selects them', (
      tester,
    ) async {
      await _App.open(tester, [
        plain().copyWith(notes: 'Llevar la tarjeta sanitaria'),
      ]);
      await _App.detail(tester, 1);
      final words = find.textContaining('Llevar la tarjeta');
      await tester.ensureVisible(words);
      await tester.pumpAndSettle();
      await tester.longPressAt(tester.getTopLeft(words) + const Offset(12, 10));
      await tester.pumpAndSettle();
      final selectable = tester.state<EditableTextState>(
        find.descendant(
          of: find.byType(SelectableText),
          matching: find.byType(EditableText),
        ),
      );
      expect(
        selectable.textEditingValue.selection.isCollapsed,
        isFalse,
        reason: 'a word is selected',
      );
      expect(find.byType(TaskEditor), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'UX-2409: a note in a project the account only views reads «Tu nota» with its text as value, not a button and no unlabeled text field',
      (tester) async {
        final handle = tester.ensureSemantics();
        const words = 'Ensayo general el sábado';
        await _App.open(
          tester,
          [
            Task(
              id: 1,
              kind: 'note',
              title: 'Concierto',
              priority: 1,
              notes: words,
              listId: 'coro',
            ),
          ],
          projects: [
            TaskListInfo(
              id: 'coro',
              name: 'Coro',
              role: 'viewer',
              shared: true,
            ),
          ],
        );
        await _App.detail(tester, 1);
        final body = readNode(es.noteBody, words);
        expect(body, findsOne);
        final data = body.evaluate().single.getSemanticsData();
        expect(data.flagsCollection.isButton, isFalse);
        expect(data.hasAction(SemanticsAction.tap), isFalse);
        expect(
          textFields(),
          findsNothing,
          reason: 'no «text field (no label)»',
        );
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    // ---- UX-2410 ----

    const esDays = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    const caDays = [
      'dilluns',
      'dimarts',
      'dimecres',
      'dijous',
      'divendres',
      'dissabte',
      'diumenge',
    ];

    /// 29 October of this year (Thursday in 2026), as the plan writes it.
    final october29 = DateTime(now.year, 10, 29, 12);
    String day29(String language) {
      final weekday = october29.weekday - 1;
      return language == 'es'
          ? '${esDays[weekday]}, 29 de octubre'
          : '${caDays[weekday]}, 29 d’octubre';
    }

    /// The value line of the row labelled [label] on the page.
    Finder rowWith(String label) =>
        find.ancestor(of: find.text(label), matching: find.byType(Column));

    for (final language in ['es', 'ca']) {
      final l = language == 'es' ? es : ca;
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'UX-2410: in $language at ${scale.toStringAsFixed(0)}× on 360×800, a timed task shows one row, «${l.plannedFor}» over «${day29(language)} · 12:00», and no «${l.time}» row',
          (tester) async {
            await loadManrope();
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            // A phone on the 24-hour clock, as most are in Spain.
            tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
            addTearDown(
              tester.platformDispatcher.clearAlwaysUse24HourTestValue,
            );
            await _App.open(
              tester,
              [
                Task(
                  id: 1,
                  title: 'Pedir cita',
                  priority: 1,
                  dueDate: october29,
                ),
              ],
              language: language,
              size: const Size(360, 800),
            );
            await _App.detail(tester, 1);
            expect(tester.takeException(), isNull, reason: 'no overflow');
            expect(find.text(l.plannedFor), findsOneWidget);
            // A no-break space keeps «· 12:00» together (P302).
            final value = find.text('${day29(language)} ·\u00A012:00');
            expect(value, findsOneWidget);
            expect(
              find.descendant(of: rowWith(l.plannedFor).first, matching: value),
              findsOneWidget,
              reason: 'under «${l.plannedFor}»',
            );
            expect(
              tester.getTopLeft(value).dy,
              greaterThan(tester.getTopLeft(find.text(l.plannedFor)).dy),
            );
            expect(tester.getRect(value).right, lessThanOrEqualTo(360));
            expect(find.text(l.time), findsNothing);
            expect(find.text(l.anyTime), findsNothing);
            expect(find.textContaining('${now.year}'), findsNothing);
          },
        );

        testWidgets(
          'UX-2410: in $language at ${scale.toStringAsFixed(0)}× on 360×800, an untimed task shows «${day29(language)}» and no «${l.anyTime}»',
          (tester) async {
            await loadManrope();
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await _App.open(
              tester,
              [
                Task(
                  id: 1,
                  title: 'Pedir cita',
                  priority: 1,
                  dueDate: DateTime(now.year, 10, 29),
                  hasTime: false,
                ),
              ],
              language: language,
              size: const Size(360, 800),
            );
            await _App.detail(tester, 1);
            expect(tester.takeException(), isNull, reason: 'no overflow');
            expect(find.text(l.plannedFor), findsOneWidget);
            expect(find.text(day29(language)), findsOneWidget);
            expect(find.text(l.anyTime), findsNothing);
            expect(find.text(l.time), findsNothing);
          },
        );

        testWidgets(
          'UX-2410: in $language at ${scale.toStringAsFixed(0)}× on 360×800, a deadline-only task shows no «${l.plannedFor} · ${l.noDate}» row and no end-of-day line',
          (tester) async {
            await loadManrope();
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await _App.open(
              tester,
              [
                Task(
                  id: 1,
                  title: 'Pagar el seguro',
                  priority: 1,
                  deadline: DateTime(friday.year, friday.month, friday.day + 3),
                ),
              ],
              language: language,
              size: const Size(360, 800),
            );
            await _App.detail(tester, 1);
            expect(tester.takeException(), isNull, reason: 'no overflow');
            expect(find.text(l.deadline), findsOneWidget);
            expect(find.text(l.plannedFor), findsNothing);
            expect(find.text(l.noDate), findsNothing);
            expect(find.text(l.time), findsNothing);
            expect(find.text(l.anyTime), findsNothing);
            // The removed «deadlineEndDay» line, in either language.
            expect(anyText('Antes de que termine el día'), findsNothing);
            expect(anyText('Abans que acabi el dia'), findsNothing);
            expect(
              anyText(l.reschedule),
              findsWidgets,
              reason: 'still adds a day',
            );
          },
        );
      }
    }

    testWidgets('UX-2410: a task next year shows its year', (tester) async {
      final next = DateTime(now.year + 1, 3, 4, 9);
      await _App.open(tester, [
        Task(id: 1, title: 'Renovar el DNI', priority: 1, dueDate: next),
      ], size: const Size(360, 800));
      await _App.detail(tester, 1);
      expect(find.text(es.plannedFor), findsOneWidget);
      expect(find.textContaining('${now.year + 1}'), findsOneWidget);
      expect(find.textContaining(' ·\u00A0'), findsWidgets, reason: 'its time');
      expect(tester.takeException(), isNull);
    });

    // ---- UX-2416 ----

    testWidgets(
      'UX-2416: labels show as one line, «#casa · #recados», in onSurfaceVariant, with no outline and no tappable node',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _App.open(tester, [
          plain().copyWith(labels: ['casa', 'recados']),
        ], size: const Size(360, 800));
        await _App.detail(tester, 1);
        final line = find.text('#casa · #recados');
        expect(line, findsOneWidget);
        expect(find.byType(Chip), findsNothing, reason: 'no outline');
        expect(find.text('#casa'), findsNothing);
        final colors = Theme.of(tester.element(line)).colorScheme;
        expect(tester.widget<Text>(line).style?.color, colors.onSurfaceVariant);
        // One line: as tall as a single line of its own text.
        final height = tester.getSize(line).height;
        final style = DefaultTextStyle.of(
          tester.element(line),
        ).style.merge(tester.widget<Text>(line).style);
        expect(
          height,
          lessThan(style.fontSize! * (style.height ?? 1.5) * 1.9),
          reason: 'one line',
        );
        // No tap anywhere on it.
        expect(
          find.ancestor(of: line, matching: find.byType(InkWell)),
          findsNothing,
        );
        final data = tester.getSemantics(line).getSemanticsData();
        expect(data.label, contains('#casa · #recados'));
        expect(data.hasAction(SemanticsAction.tap), isFalse);
        expect(data.flagsCollection.isButton, isFalse);
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );
  });

  // ---- UX loop 2026-10-28-app, round 2, P302 (UX-2623, UX-2624): a second
  // tap on Completar lands on nothing, and the time wraps with its dot ----

  group('P302 · Completar holds, the time keeps its dot', () {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    const phone = Size(360, 800);

    /// The page's filled main button with [label]: Completar or Reabrir.
    Finder mainButton(String label) => find.descendant(
      of: find.byType(TaskDetailScreen),
      matching: find.widgetWithText(FilledButton, label),
    );

    /// Calendar's «Añadir tarea».
    Finder addButton() => find.descendant(
      of: find.byType(TaskActions),
      matching: find.widgetWithText(FilledButton, es.addTask),
    );

    /// Whether something was pushed over Calendar: a capture sheet, the
    /// task form or a page.
    bool overCalendar(WidgetTester tester) =>
        Navigator.of(tester.element(find.byType(CalendarScreen))).canPop();

    /// The app at 360×800 on Calendar with «Pedir cita» today, untimed, and
    /// its page opened by a tap on its row.
    Future<_App> openFromCalendar(
      WidgetTester tester, {
      bool completed = false,
      void Function()? onCalendar,
    }) async {
      final app = await _App.open(tester, [
        Task(
          id: 1,
          title: 'Pedir cita',
          priority: 1,
          dueDate: today,
          hasTime: false,
          isCompleted: completed,
        ),
      ], size: phone);
      onCalendar?.call();
      final row = find.widgetWithText(TaskTile, 'Pedir cita');
      expect(row, findsOneWidget, reason: 'today’s row on Calendar');
      await tester.tap(
        find.descendant(of: row, matching: find.text('Pedir cita')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailScreen), findsOneWidget);
      return app;
    }

    /// Taps «[label]» on the page and draws the frame of that tap.
    Future<void> tapMain(WidgetTester tester, String label) async {
      final button = mainButton(label);
      expect(button, findsOneWidget, reason: '«$label» on the page');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
    }

    // ---- UX-2623 ----

    testWidgets(
      'UX-2623: Calendar row → task page → Completar, ES 1× on 360×800: taps on the same spot at 50, 200 and 400 ms open no capture sheet and no form, complete nothing more and reopen nothing; Calendar then shows the row ticked with one Tarea completada · Deshacer',
      (tester) async {
        // Where «Añadir tarea» sits on Calendar, before the page covers it.
        late Rect add;
        final app = await openFromCalendar(
          tester,
          onCalendar: () => add = tester.getRect(addButton()),
        );
        final complete = tester.getRect(mainButton(es.complete));
        // The spot where the page's Completar sits over Calendar's «Añadir
        // tarea», the one the finding describes.
        final overlap = complete.intersect(add);
        expect(
          overlap.width > 0 && overlap.height > 0,
          isTrue,
          reason:
              'Completar ($complete) over «Añadir tarea» ($add) at 360×800 1×',
        );
        final spot = overlap.center;

        await tapMain(tester, es.complete);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(spot);
        await tester.pump(const Duration(milliseconds: 150));
        await tester.tapAt(spot);
        await tester.pump(const Duration(milliseconds: 200));
        // 400 ms: the page has popped and is still leaving over Calendar.
        expect(
          ModalRoute.of(
            tester.element(find.byType(CalendarScreen)),
          )!.secondaryAnimation!.status,
          AnimationStatus.reverse,
          reason: 'the page is leaving at 400 ms',
        );
        await tester.tapAt(spot);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(TaskDetailScreen), findsNothing, reason: 'closed');
        expect(find.byType(BottomSheet), findsNothing, reason: 'no capture');
        expect(find.byType(TaskEditor), findsNothing, reason: 'no form');
        expect(overCalendar(tester), isFalse, reason: 'nothing opened');
        expect(app.tasks().single.isCompleted, isTrue, reason: 'not reopened');
        final ticked = find.descendant(
          of: find.widgetWithText(TaskTile, 'Pedir cita'),
          matching: find.byType(Checkbox),
        );
        expect(tester.widget<Checkbox>(ticked).value, isTrue);
        final message = find.byType(SnackBar);
        expect(message, findsOneWidget, reason: 'one message');
        expect(
          find.descendant(of: message, matching: find.text(es.taskCompleted)),
          findsOneWidget,
        );
        expect(find.text(es.undo), findsOneWidget, reason: 'one Deshacer');
        expect(find.text(es.reopen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2623: a tap on Calendar’s «Añadir tarea» while the task page above it is still leaving opens nothing',
      (tester) async {
        await openFromCalendar(tester);
        await tapMain(tester, es.complete);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(
          find.byType(TaskDetailScreen),
          findsOneWidget,
          reason: 'still on screen, leaving',
        );
        final add = addButton();
        expect(add, findsOneWidget);
        await tester.tapAt(tester.getCenter(add));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(tester.getCenter(add));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(TaskDetailScreen), findsNothing);
        expect(find.byType(BottomSheet), findsNothing, reason: 'no capture');
        expect(find.byType(TaskEditor), findsNothing, reason: 'no form');
        expect(overCalendar(tester), isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2623: during the 300 ms after Completar the page’s main button reads «Completar» with a check, disabled for TalkBack, never «Reabrir»; «Cambiar fecha» is off too',
      (tester) async {
        final handle = tester.ensureSemantics();
        await openFromCalendar(tester);
        await tapMain(tester, es.complete);
        var elapsed = 0;
        for (final at in [0, 16, 100, 200, 290]) {
          await tester.pump(Duration(milliseconds: at - elapsed));
          elapsed = at;
          final page = find.byType(TaskDetailScreen);
          expect(page, findsOneWidget, reason: 'held at $at ms');
          expect(
            find.descendant(of: page, matching: find.text(es.reopen)),
            findsNothing,
            reason: 'never Reabrir, at $at ms',
          );
          final main = mainButton(es.complete);
          expect(main, findsOneWidget, reason: 'Completar at $at ms');
          expect(
            tester.widget<ButtonStyleButton>(main).onPressed,
            isNull,
            reason: 'a dead button at $at ms',
          );
          expect(
            find.descendant(
              of: main,
              matching: find.byIcon(Icons.check_rounded),
            ),
            findsOneWidget,
            reason: 'its check at $at ms',
          );
          final data = tester.getSemantics(main).getSemanticsData();
          expect(data.label, contains(es.complete));
          expect(data.label, isNot(contains(es.reopen)));
          expect(data.flagsCollection.isButton, isTrue);
          expect(
            data.flagsCollection.isEnabled,
            Tristate.isFalse,
            reason: 'TalkBack reads it disabled at $at ms',
          );
          expect(data.hasAction(SemanticsAction.tap), isFalse);
          final move = find.descendant(
            of: page,
            matching: find.widgetWithText(OutlinedButton, es.reschedule),
          );
          expect(move, findsOneWidget);
          expect(
            tester.widget<ButtonStyleButton>(move).onPressed,
            isNull,
            reason: '«${es.reschedule}» off at $at ms',
          );
        }
        await tester.pumpAndSettle();
        expect(find.byType(TaskDetailScreen), findsNothing, reason: 'closed');
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    testWidgets(
      'UX-2623: Activity → a daily task → Completar, then a second tap at 200 ms: only today’s occurrence is completed and nothing opens',
      (tester) async {
        final app = await _App.open(tester, [
          Task(
            id: 1,
            title: 'Regar las plantas',
            priority: 1,
            dueDate: DateTime(today.year, today.month, today.day - 3),
            hasTime: false,
            recurrence: 'daily',
          ),
        ], size: phone);
        // As Activity opens it: by id alone, no occurrence.
        unawaited(
          Navigator.of(tester.element(find.byType(CalendarScreen))).push(
            MaterialPageRoute<void>(
              builder: (_) => const TaskDetailScreen(taskId: 1),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final spot = tester.getCenter(mainButton(es.complete));
        await tapMain(tester, es.complete);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tapAt(spot);
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(TaskDetailScreen), findsNothing, reason: 'closed');
        final series = app.tasks().single;
        expect(series.completedDates, [Task.dateKey(today)]);
        expect(series.completedDates, isNot(contains(Task.dateKey(tomorrow))));
        expect(find.byType(BottomSheet), findsNothing, reason: 'no capture');
        expect(overCalendar(tester), isFalse, reason: 'nothing opened');
        expect(find.text(es.taskCompleted), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2623: Reabrir on an already-completed task keeps the page at once, now offering «Completar», with no hold',
      (tester) async {
        final app = await openFromCalendar(tester, completed: true);
        await tapMain(tester, es.reopen);
        await tester.pump();
        expect(find.byType(TaskDetailScreen), findsOneWidget);
        expect(app.tasks().single.isCompleted, isFalse);
        final main = mainButton(es.complete);
        expect(main, findsOneWidget, reason: 'Completar at once');
        expect(
          tester.widget<ButtonStyleButton>(main).onPressed,
          isNotNull,
          reason: 'live at once, no hold',
        );
        expect(mainButton(es.reopen), findsNothing);
        // And it stays: no close after the hold Completar has.
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(find.byType(TaskDetailScreen), findsOneWidget, reason: 'stays');
        expect(
          tester.widget<ButtonStyleButton>(mainButton(es.complete)).onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2623: once the page has closed and its exit has finished, Calendar’s «Añadir tarea» opens the capture sheet as before',
      (tester) async {
        await openFromCalendar(tester);
        await tapMain(tester, es.complete);
        await tester.pumpAndSettle();
        expect(find.byType(TaskDetailScreen), findsNothing, reason: 'closed');
        expect(overCalendar(tester), isFalse);
        await tester.tap(addButton());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(BottomSheet), findsOneWidget, reason: 'capture');
        expect(overCalendar(tester), isTrue);
        // Let what the sheet started finish its timers.
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    // ---- UX-2624 ----

    /// The lines [text] is drawn in, as the screen breaks it.
    List<String> drawnLines(WidgetTester tester, Finder text) {
      final paragraph = tester.renderObject<RenderParagraph>(text);
      final plain = paragraph.text.toPlainText();
      final lines = <String>[];
      double? top;
      final line = StringBuffer();
      for (var i = 0; i < plain.length; i++) {
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: i, extentOffset: i + 1),
        );
        final at = boxes.isEmpty ? top : boxes.first.top;
        if (top != null && at != null && (at - top).abs() > 1) {
          lines.add(line.toString());
          line.clear();
        }
        top = at ?? top;
        line.write(plain[i]);
      }
      lines.add(line.toString());
      return lines;
    }

    final ca = lookupAppLocalizations(const Locale('ca'));
    final dates = [
      DateTime(now.year, 11, 1, 21),
      DateTime(now.year, 11, 2, 9),
      DateTime(now.year, 9, 30, 21),
      DateTime(now.year, 12, 23, 18),
    ];

    for (final language in ['es', 'ca']) {
      final l = language == 'es' ? es : ca;
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'UX-2624: in $language at ${scale.toStringAsFixed(0)}× on 360×800, no line of «${l.plannedFor}»’s date ends in «·», and the time keeps its dot',
          (tester) async {
            await loadManrope();
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
            addTearDown(
              tester.platformDispatcher.clearAlwaysUse24HourTestValue,
            );
            await _App.open(
              tester,
              [
                for (var i = 0; i < dates.length; i++)
                  Task(
                    id: i + 1,
                    title: 'Pedir cita',
                    priority: 1,
                    dueDate: dates[i],
                  ),
              ],
              language: language,
              size: phone,
            );
            var wrapped = 0;
            for (var i = 0; i < dates.length; i++) {
              await _App.detail(tester, i + 1);
              final page = find.byType(TaskDetailScreen);
              final context = tester.element(page);
              final day = context.dayHeading(dates[i], DateTime.now());
              final time = context.clockTime(dates[i]);
              final value = find.descendant(
                of: page,
                matching: find.textContaining(day),
              );
              expect(value, findsOneWidget, reason: '$day on the page');
              final lines = drawnLines(tester, value);
              expect(
                lines.join(),
                allOf(contains(day), contains(time)),
                reason: 'the day and its time',
              );
              for (final line in lines) {
                expect(
                  line.trimRight().endsWith('·'),
                  isFalse,
                  reason: 'a line ends in «·»: $lines',
                );
              }
              final timeLine = lines.lastWhere((line) => line.contains(time));
              expect(
                timeLine.contains('·') || timeLine.contains(day),
                isTrue,
                reason: '«$time» wraps alone: $lines',
              );
              if (lines.length > 1) wrapped++;
              expect(tester.takeException(), isNull, reason: 'no overflow');
              Navigator.of(context).pop();
              await tester.pumpAndSettle();
            }
            if (scale == 2.0) {
              expect(
                wrapped,
                greaterThan(0),
                reason:
                    'at 2× some date line wraps, so the check means something',
              );
            }
          },
        );
      }
    }
  });

  // ---- UX loop 2026-10-28-app, round 2 · P304 (UX-2631, UX-2108) ----
  group('P304 · outlined buttons stay 52 dp at one line', () {
    testWidgets(
      'UX-2631 / UX-2108: es 1× on 360×800, a task’s one-line «Cambiar fecha» is 52 dp tall and «Completar» 60 dp',
      (tester) async {
        await loadManrope();
        await _App.open(tester, [plain()], size: const Size(360, 800));
        await _App.detail(tester, 1);
        final reschedule = outlinedButtonWithText(es.reschedule);
        expect(reschedule, findsOneWidget);
        expect(labelLines(tester, reschedule, es.reschedule), hasLength(1));
        expect(
          tester.getRect(visibleButton(reschedule)).height,
          closeTo(52, 0.5),
          reason: 'the visible outline',
        );
        final complete = filledButtonWithText(es.complete);
        expect(complete, findsOneWidget);
        expect(tester.getRect(visibleButton(complete)).height, closeTo(60, 0.5));
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- UX loop 2026-10-28-app, round 3 · P307 (UX-2633) ----
  group('P307 · the page is inert while Completar closes it', () {
    final today = DateTime(now.year, now.month, now.day);
    const phone = Size(360, 800);

    /// The page's filled main button with [label]: Completar or Reabrir.
    Finder mainButton(String label) => find.descendant(
      of: find.byType(TaskDetailScreen),
      matching: find.widgetWithText(FilledButton, label),
    );

    /// The page's «Cambiar fecha».
    Finder moveButton() => find.descendant(
      of: find.byType(TaskDetailScreen),
      matching: find.widgetWithText(OutlinedButton, es.reschedule),
    );

    /// The page's ✏ in its app bar.
    Finder editButton() => find.descendant(
      of: find.byType(TaskDetailScreen),
      matching: find.widgetWithIcon(IconButton, Icons.edit_outlined),
    );

    /// Whether something was pushed over Calendar: a sheet, the form or a
    /// page.
    bool overCalendar(WidgetTester tester) =>
        Navigator.of(tester.element(find.byType(CalendarScreen))).canPop();

    /// Whether the task page is the top route: nothing opened over it.
    bool pageOnTop(WidgetTester tester) =>
        ModalRoute.of(tester.element(find.byType(TaskDetailScreen)))!.isCurrent;

    /// «Pedir cita» today, untimed, with a reminder and two steps.
    Task appointment() => Task(
      id: 1,
      title: 'Pedir cita',
      priority: 1,
      dueDate: today,
      hasTime: false,
      reminderMinutes: 60,
      checklist: [
        ChecklistItem(id: 'a', title: 'Llamar al centro'),
        ChecklistItem(id: 'b', title: 'Apuntar la hora'),
      ],
    );

    /// The app at 360×800 on Calendar, with the task's page opened by a tap
    /// on its row.
    Future<_App> openFromCalendar(WidgetTester tester) async {
      final app = await _App.open(tester, [appointment()], size: phone);
      final row = find.widgetWithText(TaskTile, 'Pedir cita');
      expect(row, findsOneWidget, reason: 'today’s row on Calendar');
      await tester.tap(
        find.descendant(of: row, matching: find.text('Pedir cita')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailScreen), findsOneWidget);
      return app;
    }

    /// Taps Completar on the page and draws the frame of that tap.
    Future<void> complete(WidgetTester tester) async {
      final button = mainButton(es.complete);
      expect(button, findsOneWidget, reason: 'Completar on the page');
      await tester.tap(button);
      await tester.pump();
    }

    /// After the page closed: Calendar on top, nothing over it, the row
    /// ticked and one «Tarea completada · Deshacer».
    void expectBackOnCalendar(WidgetTester tester, _App app) {
      expect(find.byType(TaskDetailScreen), findsNothing, reason: 'closed');
      expect(find.byType(CalendarScreen), findsOneWidget, reason: 'Calendar');
      expect(
        ModalRoute.of(tester.element(find.byType(CalendarScreen)))!.isCurrent,
        isTrue,
        reason: 'Calendar is the top route, not popped',
      );
      expect(overCalendar(tester), isFalse, reason: 'nothing opened');
      expect(find.byType(TaskEditor), findsNothing, reason: 'no form');
      expect(find.byType(BottomSheet), findsNothing, reason: 'no sheet');
      expect(find.byType(Dialog), findsNothing, reason: 'no dialog');
      final task = app.tasks().single;
      expect(task.isCompleted, isTrue, reason: 'completed, once');
      expect(task.checklist.map((step) => step.done()), [
        false,
        false,
      ], reason: 'no step changed');
      final ticked = find.descendant(
        of: find.widgetWithText(TaskTile, 'Pedir cita'),
        matching: find.byType(Checkbox),
      );
      expect(tester.widget<Checkbox>(ticked).value, isTrue, reason: 'ticked');
      final message = find.byType(SnackBar);
      expect(message, findsOneWidget, reason: 'one message');
      expect(
        find.descendant(of: message, matching: find.text(es.taskCompleted)),
        findsOneWidget,
      );
      expect(find.text(es.undo), findsOneWidget, reason: 'one Deshacer');
    }

    testWidgets(
      'UX-2633: Calendar row → task page → Completar, ES 1× on 360×800, then taps on ✏ at 100 and 400 ms: no form opens, the page closes once, and Calendar shows the row ticked with one Tarea completada · Deshacer',
      (tester) async {
        final app = await openFromCalendar(tester);
        final edit = editButton();
        expect(edit, findsOneWidget, reason: '✏ on the page');
        final spot = tester.getCenter(edit);

        await complete(tester);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tapAt(spot);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(TaskEditor), findsNothing, reason: 'no form');
        expect(pageOnTop(tester), isTrue, reason: 'nothing over the page');
        await tester.pump(const Duration(milliseconds: 200));
        // 400 ms: the page has popped and is leaving.
        await tester.tapAt(spot);
        await tester.pump();
        await tester.pumpAndSettle();

        expectBackOnCalendar(tester, app);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2633: during the hold after Completar, TalkBack can’t open ✏ either: it offers no tap until the page closes',
      (tester) async {
        final handle = tester.ensureSemantics();
        await openFromCalendar(tester);
        final before = tester.getSemantics(editButton()).getSemanticsData();
        expect(before.hasAction(SemanticsAction.tap), isTrue, reason: 'live');
        await complete(tester);
        await tester.pump(const Duration(milliseconds: 100));
        final during = tester.getSemantics(editButton()).getSemanticsData();
        expect(
          during.hasAction(SemanticsAction.tap),
          isFalse,
          reason: '✏ offers no tap in the hold',
        );
        await tester.pumpAndSettle();
        expect(find.byType(TaskDetailScreen), findsNothing, reason: 'closed');
        expect(find.byType(TaskEditor), findsNothing, reason: 'no form');
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    for (final (target, finder) in <(String, Finder Function())>[
      ('the «Planificado para» row', () => find.text(es.plannedFor)),
      (
        'the reminder chip',
        () => find.descendant(
          of: find.byType(ReminderChip),
          matching: find.byType(ActionChip),
        ),
      ),
      ('a step', () => find.byKey(const ValueKey('check-step-a'))),
    ]) {
      testWidgets(
        'UX-2633: Calendar row → task page → Completar, ES 1× on 360×800, then a tap on $target at 100 ms: no sheet and no route opens, no step changes, and the page closes once',
        (tester) async {
          final app = await openFromCalendar(tester);
          final control = finder();
          expect(control, findsOneWidget, reason: '$target on the page');
          await tester.ensureVisible(control);
          await tester.pumpAndSettle();
          final spot = tester.getCenter(control);
          expect(
            tester.getRect(find.byType(TaskDetailScreen)).contains(spot),
            isTrue,
            reason: '$target inside the view at $spot',
          );

          await complete(tester);
          await tester.pump(const Duration(milliseconds: 100));
          await tester.tapAt(spot);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          // 200 ms, still holding: nothing opened over the page.
          expect(find.byType(TaskDetailScreen), findsOneWidget);
          expect(pageOnTop(tester), isTrue, reason: 'nothing over the page');
          expect(find.byType(BottomSheet), findsNothing, reason: 'no sheet');
          expect(
            find.byKey(const ValueKey('schedule-done')),
            findsNothing,
            reason: 'no schedule sheet',
          );
          expect(find.byType(TaskEditor), findsNothing, reason: 'no form');
          final step = find.descendant(
            of: find.byKey(const ValueKey('check-step-a')),
            matching: find.byType(Checkbox),
          );
          expect(
            tester.widget<Checkbox>(step).value,
            isFalse,
            reason: 'the step stays unticked',
          );
          await tester.pumpAndSettle();

          expectBackOnCalendar(tester, app);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final (over, open) in <(String, void Function(BuildContext))>[
      (
        'a page',
        (context) => unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Encima')),
            ),
          ),
        ),
      ),
      (
        'a sheet',
        (context) => unawaited(
          showModalBottomSheet<void>(
            context: context,
            builder: (_) => const SizedBox(height: 200, child: Text('Encima')),
          ),
        ),
      ),
    ]) {
      testWidgets(
        'UX-2633: Completar, then $over pushed over the task page at 100 ms, 400 ms and Back: the page stays, shows «Reabrir» and «Cambiar fecha» enabled, no «Completar», doesn’t pop by itself, and takes taps again',
        (tester) async {
          final app = await openFromCalendar(tester);
          await complete(tester);
          await tester.pump(const Duration(milliseconds: 100));
          open(tester.element(find.byType(TaskDetailScreen)));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
          expect(find.text('Encima'), findsOneWidget, reason: '$over on top');
          expect(app.tasks().single.isCompleted, isTrue, reason: 'ticked');

          // System Back closes what was opened over the page.
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('Encima'), findsNothing);
          expect(
            find.byType(TaskDetailScreen),
            findsOneWidget,
            reason: 'the page is still there',
          );
          expect(pageOnTop(tester), isTrue);
          final reopen = mainButton(es.reopen);
          expect(reopen, findsOneWidget, reason: '«${es.reopen}»');
          expect(
            tester.widget<ButtonStyleButton>(reopen).onPressed,
            isNotNull,
            reason: '«${es.reopen}» enabled',
          );
          expect(mainButton(es.complete), findsNothing, reason: 'no Completar');
          expect(moveButton(), findsOneWidget);
          expect(
            tester.widget<ButtonStyleButton>(moveButton()).onPressed,
            isNotNull,
            reason: '«${es.reschedule}» enabled',
          );

          // It doesn't pop by itself.
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          expect(
            find.byType(TaskDetailScreen),
            findsOneWidget,
            reason: 'stays',
          );
          expect(pageOnTop(tester), isTrue);

          // And it isn't frozen: «Cambiar fecha» opens the schedule sheet.
          await tester.tap(moveButton());
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('schedule-done')),
            findsOneWidget,
            reason: 'the page takes taps again',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-2633: Completar, then system Back at 100 ms: the page closes once, Calendar is not popped, and after 400 ms more nothing else changes',
      (tester) async {
        final app = await openFromCalendar(tester);
        await complete(tester);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expectBackOnCalendar(tester, app);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expectBackOnCalendar(tester, app);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---- UX loop 2026-10-28-app, round 1 · P294 (UX-2510, UX-2614): a note
  // is called a note; the task page's chips sit 8 dp apart ----
  group('P294 · a note is called a note; chips 8 dp apart', () {
    final mates = TaskListInfo(
      id: 'mates',
      name: 'Matemáticas',
      version: 1,
      shared: true,
      role: 'owner',
      ownerId: 1,
      people: const [
        ProjectMember(id: 1, name: 'Miki', role: 'owner'),
        ProjectMember(id: 2, name: 'Ana', role: 'editor'),
      ],
    );
    final casa = TaskListInfo(id: 'casa', name: 'Casa', version: 1);

    Task item({required bool note, String? listId}) => Task(
      id: 1,
      title: note ? 'Ideas para la reunión' : 'Pedir cita',
      priority: 1,
      kind: note ? 'note' : 'task',
      dueDate: note ? null : friday,
      listId: listId,
      assignment: listId == 'mates' ? 'group' : 'personal',
    );

    test('UX-2510: the note strings read as planned in ES, EN and CA', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final ca = lookupAppLocalizations(const Locale('ca'));
      expect(
        es.shareNoteConfirm('Matemáticas'),
        '¿Compartir con Matemáticas? Todos verán esta nota y no podrás volver a hacerla privada.',
      );
      expect(
        en.shareNoteConfirm('Matemáticas'),
        'Share with Matemáticas? Everyone there will see this note. It can’t be made private again.',
      );
      expect(
        ca.shareNoteConfirm('Matemáticas'),
        ca.shareTaskConfirm('Matemáticas'),
      );
      expect(es.sharedNoteStays, 'Las notas compartidas se quedan en su proyecto.');
      expect(en.sharedNoteStays, 'Shared notes stay in their project.');
      expect(ca.sharedNoteStays, 'Les notes compartides es queden al seu projecte.');
      expect(es.moveNoteError, 'No se pudo mover esta nota. Inténtalo de nuevo.');
      expect(en.moveNoteError, 'Could not move this note. Please retry.');
      expect(ca.moveNoteError, 'No s’ha pogut moure aquesta nota. Torna-ho a provar.');
      expect(es.deleteNote, 'Eliminar nota');
      expect(en.deleteNote, 'Delete note');
      expect(ca.deleteNote, 'Suprimeix la nota');
    });

    for (final note in [true, false]) {
      final what = note ? 'note' : 'task';
      testWidgets(
        'UX-2510: a personal $what moved into «Matemáticas» asks «${note ? es.shareNoteConfirm('Matemáticas') : es.shareTaskConfirm('Matemáticas')}»',
        (tester) async {
          await _App.open(tester, [item(note: note)], projects: [mates, casa]);
          await _App.detail(tester, 1);
          final chip = find.widgetWithText(ActionChip, es.noList);
          await tester.ensureVisible(chip);
          await tester.pumpAndSettle();
          await tester.tap(chip);
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byType(BottomSheet),
              matching: find.widgetWithText(ListTile, 'Matemáticas'),
            ),
          );
          await tester.pumpAndSettle();
          final dialog = find.byType(AlertDialog);
          expect(dialog, findsOneWidget);
          final expected = note
              ? es.shareNoteConfirm('Matemáticas')
              : es.shareTaskConfirm('Matemáticas');
          expect(
            find.descendant(of: dialog, matching: find.text(expected)),
            findsOneWidget,
          );
          await tester.tap(find.widgetWithText(TextButton, es.cancel));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final language in ['es', 'en', 'ca']) {
      for (final note in [true, false]) {
        final l = lookupAppLocalizations(Locale(language));
        final what = note ? 'note' : 'task';
        testWidgets(
          'UX-2510: a shared $what’s locked project chip says «${note ? l.sharedNoteStays : l.sharedTaskStays}», and its delete button’s tooltip reads «${note ? l.deleteNote : l.deleteTask}» ($language)',
          (tester) async {
            await _App.open(
              tester,
              [item(note: note, listId: 'mates')],
              projects: [mates],
              language: language,
            );
            await _App.detail(tester, 1);
            expect(
              find.byTooltip(note ? l.deleteNote : l.deleteTask),
              findsOneWidget,
            );
            expect(find.byTooltip(l.delete), findsNothing);
            if (note) expect(find.byTooltip(l.deleteTask), findsNothing);
            final chip = find.widgetWithText(ActionChip, 'Matemáticas');
            await tester.ensureVisible(chip);
            await tester.pumpAndSettle();
            await tester.tap(chip);
            await tester.pump();
            expect(
              find.text(note ? l.sharedNoteStays : l.sharedTaskStays),
              findsOneWidget,
            );
            expect(
              find.text(note ? l.sharedTaskStays : l.sharedNoteStays),
              findsNothing,
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    for (final note in [true, false]) {
      final what = note ? 'note' : 'task';
      testWidgets(
        'UX-2510: a $what whose move fails says «${note ? es.moveNoteError : es.moveError}»',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final container = designContainer(
            regionalStore: MemoryRegionalStore(
              const RegionalPreferences(language: 'es'),
            ),
            projects: [casa],
            tasks: () => TaskNotifier(_FailingMoves([item(note: note)])),
          );
          addTearDown(container.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MyApp(),
            ),
          );
          await tester.pumpAndSettle();
          await _App.detail(tester, 1);
          final chip = find.widgetWithText(ActionChip, es.noList);
          await tester.ensureVisible(chip);
          await tester.pumpAndSettle();
          await tester.tap(chip);
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byType(BottomSheet),
              matching: find.widgetWithText(ListTile, 'Casa'),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            find.text(note ? es.moveNoteError : es.moveError),
            findsOneWidget,
          );
          expect(
            find.text(note ? es.moveError : es.moveNoteError),
            findsNothing,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final language in ['es', 'ca']) {
      testWidgets(
        'UX-2614: tasks/detail.created-by, $language at 2× on 360×800: the project and person chips, wrapped, are 8 dp apart or more',
        (tester) async {
          await loadManrope();
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _App.open(
            tester,
            [fromServer()],
            projects: [familia],
            language: language,
            size: const Size(360, 800),
          );
          await _App.detail(tester, 1);
          final picker = find.byType(TaskAssignmentPicker);
          final wrap = find
              .descendant(of: picker, matching: find.byType(Wrap))
              .first;
          expect(tester.widget<Wrap>(wrap).runSpacing, 8);
          final chips = tester
              .widgetList(find.descendant(of: wrap, matching: find.byType(ActionChip)))
              .map((chip) => tester.getRect(find.byWidget(chip)))
              .toList()
            ..sort((a, b) => a.top.compareTo(b.top));
          expect(chips, hasLength(2), reason: 'the project and who it’s for');
          final (first, second) = (chips[0], chips[1]);
          expect(
            second.top,
            greaterThanOrEqualTo(first.bottom - 0.5),
            reason: 'at 2× the chips wrap, as in the render',
          );
          expect(
            second.top - first.bottom,
            greaterThanOrEqualTo(8 - 0.5),
            reason: 'wrapped chips 8 dp apart',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  // ---- UX loop 2026-11-01-screens, round 1 · P317 (UX-2635) ----
  group('P317 · wrapped labels centre beside their icon', () {
    setUpAll(() async {
      await loadManrope();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });

    final today = DateTime(now.year, now.month, now.day);
    // 09:41 today, with reminders on at 9:00 for tasks with no time.
    final at = DateTime(now.year, now.month, now.day, 9, 41);
    final reminders = reminderOverrides(
      MemoryReminderStore(
        const ReminderPreferences(
          enabled: true,
          dateOnlyTime: 540,
          asked: true,
        ),
      ),
      FakeReminderAccess(allowed: true),
    );
    Task marta() => Task(
      id: 1,
      title: 'Llamar a Marta',
      dueDate: today,
      hasTime: false,
      priority: 1,
    );

    /// «Llamar a Marta»'s page (tasks/detail.alert-passed): today, no time,
    /// opened at 09:41, so its 9:00 alert has passed.
    Future<void> openPassed(
      WidgetTester tester,
      String language,
      double scale,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _Repository([marta()]);
      final container = designContainer(
        regionalStore: MemoryRegionalStore(
          RegionalPreferences(language: language),
        ),
        tasks: () => TaskNotifier(repository),
        overrides: [
          ...reminders,
          calendarClockProvider.overrideWithValue(() => at),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      await _App.detail(tester, 1);
      final chip = find.byType(ReminderChip);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
    }

    /// The reminder chip's [text], line by line, and its paragraph's box.
    ({List<Rect> lines, Rect box, double longest}) chipText(
      WidgetTester tester,
      String text,
    ) {
      final chip = find.byType(ReminderChip);
      final paragraph = labelParagraph(tester, chip, text);
      expect(paragraph.didExceedMaxLines, isFalse, reason: '«$text» whole');
      final lines = labelLines(tester, chip, text);
      return (
        lines: lines,
        box: paragraph.localToGlobal(Offset.zero) & paragraph.size,
        longest: lines.map((line) => line.width).reduce(math.max),
      );
    }

    /// The chip hugs [text]'s longest line: its label box is no wider than
    /// that line, the bell sits beside it, and the chip ends no further from
    /// the text than its own padding.
    void expectHugs(WidgetTester tester, String text, Finder shape) {
      final t = chipText(tester, text);
      expect(t.box.width - t.longest, lessThanOrEqualTo(1),
          reason: '«$text»: the label ${t.box} hugs its longest line '
              '(${t.longest} dp)');
      final bell = tester.getRect(
        find.descendant(
          of: find.byType(ReminderChip),
          matching: find.byType(Icon),
        ),
      );
      final chip = tester.getRect(shape);
      final textLeft = t.lines.map((line) => line.left).reduce(math.min);
      final textRight = t.lines.map((line) => line.right).reduce(math.max);
      expect(textLeft - bell.right, inInclusiveRange(0, 12),
          reason: 'the bell $bell beside the text (from $textLeft)');
      // A chip pads its label by 8 dp and itself by 8 dp, plus its outline.
      expect(chip.right - textRight, lessThanOrEqualTo(17.5),
          reason: '«$text»: no empty band after the text in the chip $chip '
              '(${chip.right - textRight} dp)');
    }

    for (final (language, lines) in [('ca', 4), ('es', 3)]) {
      testWidgets(
        'UX-2635: $language 2× on 360×800 (tasks/detail.alert-passed.$language.light.2x), the chip «${lookupAppLocalizations(Locale(language)).noReminderTimePassed}» wraps with each line centred on the longest, hugs it with the bell beside it, stays at the page’s left, and a tap still opens the reminder choices',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          await openPassed(tester, language, 2);
          final action = find.descendant(
            of: find.byType(ReminderChip),
            matching: find.byType(ActionChip),
          );
          expect(action, findsOneWidget, reason: 'the chip has a tap');
          final t = chipText(tester, l.noReminderTimePassed);
          expect(t.lines.length, greaterThanOrEqualTo(2),
              reason: 'it wraps at 2×, as the render shows (about $lines)');
          for (final line in t.lines) {
            expect((line.center.dx - t.box.center.dx).abs(),
                lessThanOrEqualTo(1),
                reason: 'the line $line centred on the longest, in ${t.box}');
          }
          expectHugs(tester, l.noReminderTimePassed, action);
          // The chip stays left on the page, in line with the title.
          final title = tester.getRect(
            find
                .descendant(
                  of: find.byType(TaskDetailScreen),
                  matching: find.text('Llamar a Marta'),
                )
                .first,
          );
          expect(tester.getRect(action).left, closeTo(title.left, 1),
              reason: 'the chip at the page’s left, as the title');
          expect(tester.takeException(), isNull, reason: 'no overflow');
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget,
              reason: 'a tap opens the reminder choices');
        },
      );
    }

    // The plan expected one line here; at 360 dp the chip's label has
    // 232 dp (the page's width less 80), so it took two lines before P317
    // as well (render tasks/detail.alert-passed.es.light.1x). What this
    // locks is «as before»: the same lines a start-aligned label had.
    testWidgets(
      'UX-2635: es 1× on 360×800, the chip «Sin recordatorio: ya ha pasado la hora del aviso» wraps as before, its lines centred, hugging the longest, with the bell beside it',
      (tester) async {
        await openPassed(tester, 'es', 1);
        final t = chipText(tester, es.noReminderTimePassed);
        final paragraph = labelParagraph(
          tester,
          find.byType(ReminderChip),
          es.noReminderTimePassed,
        );
        final before = TextPainter(
          text: paragraph.text,
          textDirection: TextDirection.ltr,
          textScaler: paragraph.textScaler,
          maxLines: 10,
        )..layout(maxWidth: paragraph.constraints.maxWidth);
        addTearDown(before.dispose);
        expect(t.lines, hasLength(before.computeLineMetrics().length),
            reason: 'the same lines as a start-aligned label in its room');
        expect(t.lines.length, lessThanOrEqualTo(2));
        for (final line in t.lines) {
          expect((line.center.dx - t.box.center.dx).abs(),
              lessThanOrEqualTo(1),
              reason: 'the line $line centred on the longest, in ${t.box}');
        }
        expectHugs(
          tester,
          es.noReminderTimePassed,
          find.descendant(
            of: find.byType(ReminderChip),
            matching: find.byType(ActionChip),
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-2635: a reminder line with no tap (onChanged null, nothing blocking) at es 2× keeps its lines start-aligned and hugs its longest line',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final container = designContainer(
          overrides: [
            ...reminders,
            calendarClockProvider.overrideWithValue(() => at),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('es'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ReminderChip(task: marta()),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final plain = find.descendant(
          of: find.byType(ReminderChip),
          matching: find.byType(Chip),
        );
        expect(plain, findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ReminderChip),
            matching: find.byType(ActionChip),
          ),
          findsNothing,
          reason: 'a line with no tap is no control',
        );
        final t = chipText(tester, es.noReminderTimePassed);
        expect(t.lines.length, greaterThanOrEqualTo(2), reason: 'it wraps');
        for (final line in t.lines) {
          expect((line.left - t.box.left).abs(), lessThanOrEqualTo(1),
              reason: 'the line $line starts at the label’s start, ${t.box}');
        }
        expect(
          t.lines.any((line) => t.longest - line.width > 4),
          isTrue,
          reason: 'a shorter line shows the alignment: ${t.lines}',
        );
        expectHugs(tester, es.noReminderTimePassed, plain);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

/// The app in Spanish, signed in, on Calendar, with the real task list over
/// tasks kept in memory.
class _App {
  _App(this.container, this.repository);
  final ProviderContainer container;
  final _Repository repository;

  List<Task> tasks() => container.read(taskProvider).requireValue;

  static Future<_App> open(
    WidgetTester tester,
    List<Task> tasks, {
    List<TaskListInfo> projects = const [],
    String language = 'es',
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _Repository(tasks);
    final container = designContainer(
      regionalStore: MemoryRegionalStore(
        RegionalPreferences(language: language),
      ),
      projects: projects,
      tasks: () => TaskNotifier(repository),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    return _App(container, repository);
  }

  /// Opens the detail of task [id].
  static Future<void> detail(WidgetTester tester, int id) async {
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pushNamed('/taskDetails', arguments: id);
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailScreen), findsOneWidget);
  }
}

/// Tasks kept in memory, the way the local database keeps them: deleting
/// removes the row, and restoring puts it back as it was.
class _Repository extends TaskRepository {
  _Repository(List<Task> tasks) : super(TaskDatabase()) {
    for (final task in tasks) {
      rows[task.id!] = task.toMap();
    }
  }
  final rows = <int, Map<String, dynamic>>{};
  int updates = 0;

  @override
  Future<List<Task>> getAllTasks() async =>
      rows.values.map(Task.fromMap).toList();

  @override
  Future<int> addTask(Task task) async {
    final id =
        (rows.keys.isEmpty ? 0 : rows.keys.reduce((a, b) => a > b ? a : b)) + 1;
    rows[id] = task.copyWith(id: id).toMap();
    return id;
  }

  @override
  Future<int> updateTask(Task task) async {
    updates++;
    rows[task.id!] = task.toMap();
    return 1;
  }

  @override
  Future<int> deleteTask(int id) async => rows.remove(id) == null ? 0 : 1;

  @override
  Future<int> restoreTask(Task task) async {
    rows[task.id!] = task.toMap();
    return task.id!;
  }
}
// ---- P271: a reader's phone over a real database ----

const _choir = '91111111-1111-4111-8111-111111111111';
const _choirTaskId = '92222222-2222-4222-8222-222222222222';

/// A server this phone can't reach: every request fails as offline.
class _Unreachable extends OfflineApiClient {
  final requests = <String>[];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    requests.add('$method $path');
    throw ApiException(0, 'Offline');
  }
}

/// The app at 360×800, signed in as account 1, over a real task database in
/// a file, where «Coro» is a project this account can only view.
class _ReaderPhone {
  _ReaderPhone(
    this.tester,
    this.path,
    this.sql,
    this.repository,
    this.api, {
    this.files = const [],
  });
  final WidgetTester tester;

  /// The task's files, as the attachment list shows them.
  final List<AttachmentEntry> files;
  final String path;
  final Database sql;
  final CloudTaskRepository repository;
  final _Unreachable api;
  late int id;

  static Future<_ReaderPhone> open(
    WidgetTester tester,
    Map<String, dynamic> task, {
    String language = 'es',
    List<AttachmentEntry> files = const [],
  }) async {
    final directory = Directory.systemTemp.createTempSync('taskflow-reader-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = p.join(directory.path, 'data.db');
    // The file is made with real I/O; the app then reads it in the test's time.
    final (sql, repository, api) = (await tester.runAsync(() async {
      final sql = await databaseFactoryFfiNoIsolate.openDatabase(path);
      await sql.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
      );
      await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
      final database = TaskDatabase.forTesting(sql);
      final api = _Unreachable();
      final repository = CloudTaskRepository(database, api, 1);
      await sql.insert('task_lists', {
        'id': _choir,
        'name': 'Coro',
        'owner_key': repository.ownerKey,
        'role': 'viewer',
        'shared': 1,
      });
      await database.mergeRemote(repository.ownerKey, task);
      return (sql, repository, api);
    }))!;
    addTearDown(() => tester.runAsync(sql.close));
    final phone = _ReaderPhone(
      tester,
      path,
      sql,
      repository,
      api,
      files: files,
    );
    await phone._start(language);
    return phone;
  }

  Future<void> _start(String language) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = designContainer(
      regionalStore: MemoryRegionalStore(
        RegionalPreferences(language: language),
      ),
      projects: [
        TaskListInfo(id: _choir, name: 'Coro', role: 'viewer', shared: true),
      ],
      tasks: () => TaskNotifier(repository),
      overrides: [
        ...reminderOverrides(
          MemoryReminderStore(
            const ReminderPreferences(
              enabled: true,
              dateOnlyTime: 540,
              asked: true,
            ),
          ),
          FakeReminderAccess(allowed: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // The design fixtures list no files; this phone's own win here.
        child: ProviderScope(
          overrides: [
            attachmentEntriesProvider.overrideWith((ref, id) async => files),
          ],
          child: const MyApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    id = (await sql.query('tasks', columns: ['id'])).single['id'] as int;
  }

  /// This task's row on the phone.
  Future<Map<String, Object?>> row() async =>
      (await sql.query('tasks', where: 'id = ?', whereArgs: [id])).single;

  Future<void> detail() => _App.detail(tester, id);

  /// Closes this app and its database, then opens a new app on the same file.
  Future<_ReaderPhone> restart() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    final reopened = (await tester.runAsync(() async {
      await sql.close();
      return databaseFactoryFfiNoIsolate.openDatabase(path);
    }))!;
    addTearDown(() => tester.runAsync(reopened.close));
    final api = _Unreachable();
    final repository = CloudTaskRepository(
      TaskDatabase.forTesting(reopened),
      api,
      1,
    );
    final phone = _ReaderPhone(tester, path, reopened, repository, api);
    await phone._start('es');
    return phone;
  }
}

/// P294: tasks whose every save fails, as a move can.
class _FailingMoves extends _Repository {
  _FailingMoves(super.tasks);
  @override
  Future<int> updateTask(Task task) async =>
      throw StateError('The move could not be saved.');
}
