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
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/widgets/task_assignment_picker.dart';
import 'package:agenda/widgets/task_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_fixtures.dart';

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
      // What it has: its date and time.
      expect(find.text(es.plannedFor), findsOneWidget);
      expect(find.text(es.time), findsOneWidget);
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

  for (final line in ['date', 'time']) {
    testWidgets(
      'UX-214: tapping the $line row opens the schedule sheet, as Cambiar fecha does',
      (tester) async {
        await _App.open(tester, [plain()]);
        await _App.detail(tester, 1);
        await tester.tap(find.text(line == 'date' ? es.plannedFor : es.time));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('schedule-done')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

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
      await tester.tap(find.byTooltip(es.delete));
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
    'UX-472: Planificado para and Hora say Cambiar fecha; Repetir and the title say Editar tarea; a note’s title says Editar nota',
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
      expect(tapHint(tester, find.text(es.time)), es.reschedule);
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
