import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/capture_command.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/occurrence_change.dart';
import 'package:agenda/models/occurrence_exception.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/calendar_screen.dart';
import 'package:agenda/screens/edit_task_screen.dart';
import 'package:agenda/screens/home_screen.dart';
import 'package:agenda/screens/task_detail_screen.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/native_speech.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/task_list_store.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/widgets/capture_command_cards.dart';
import 'package:agenda/widgets/capture_review_editor.dart';
import 'package:agenda/widgets/task_list_picker.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:uuid/uuid.dart';

import 'support/capture_fixtures.dart';
import 'support/design_fixtures.dart';

final es = lookupAppLocalizations(const Locale('es'));
final ca = lookupAppLocalizations(const Locale('ca'));

/// [days] from today, at [hour]:[minute].
DateTime day(int days, [int hour = 0, int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days, hour, minute);
}

String key(DateTime date) => Task.dateKey(date);

/// The app's own context, once it is open, in its language and region.
late BuildContext Function() appContext;

/// How the result names a day more than a day away: `mié, 21 oct`, in the
/// app's own language and region.
String weekday(DateTime date) => appContext().weekdayDate(date);

CaptureCommand command(Map<String, dynamic> json) =>
    CaptureCommand.fromServer({'issues': [], ...json})!;

/// A draft as the server sends it with the `commands` flag.
Map<String, dynamic> serverTask(
  String title, {
  DateTime? date,
  String? newProject,
  String? suggestion,
  List<String> issues = const [],
  Map<String, String?> hints = const {},
  String? listId,
}) => {
  'title': title,
  'due_date': null,
  'scheduled_date': date == null ? null : key(date),
  'priority': 1,
  'notes': '',
  'questions': [],
  'list_id': listId,
  'assignment': 'personal',
  'assignment_issues': issues,
  'assignment_hints': {'project': null, 'member': null, ...hints},
  'new_project': newProject,
  'project_suggestion': suggestion,
};

CaptureDraft draft(
  String title, {
  DateTime? date,
  String? newProject,
  String? suggestion,
  List<String> issues = const [],
  Map<String, String?> hints = const {},
  String? listId,
}) => CaptureDraft.fromAI(
  TaskDraft.fromJson({
    ...serverTask(
      title,
      date: date,
      newProject: newProject,
      suggestion: suggestion,
      issues: issues,
      hints: hints,
      listId: listId,
    ),
    'transcript': 'Lo que dije',
  }),
);

final physics = TaskListInfo(id: 'physics', name: 'Física', version: 2);
final maths = TaskListInfo(id: 'maths', name: 'Matemáticas', version: 2);
final team = TaskListInfo(
  id: 'team',
  name: 'Equipo',
  shared: true,
  version: 2,
  people: const [
    ProjectMember(id: 1, name: 'Yo', role: 'owner'),
    ProjectMember(id: 3, name: 'Paul', role: 'editor'),
  ],
);

Finder button(String label) => find.widgetWithText(FilledButton, label);

/// The result's confirming button.
FilledButton saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const ValueKey('save-drafts')));

void main() {
  setUp(() => SharedSpeech.reset());

  group('the cards of a result', () {
    testWidgets(
      'a project to create: «Nuevo proyecto: Física», the task in it shows '
      'its name, and one tap creates the project, then the task in it; one '
      'Deshacer takes both back',
      (tester) async {
        final app = await _App.open(tester);
        await app.showResult(
          tester,
          drafts: [
            draft('Estudiar el tema 2', date: day(4), newProject: 'Física'),
          ],
          commands: [
            command({'kind': 'project', 'name': 'Física'}),
          ],
        );
        // The project's card, and the task's project.
        expect(find.text(es.commandNewProject('Física')), findsOneWidget);
        expect(find.text(es.commandNewProjectChip('Física')), findsOneWidget);
        expect(find.text(es.captureThingsToAdd(2)), findsOneWidget);
        expect(find.text(es.captureAddToCalendar), findsOneWidget);
        expect(app.lists.created, isEmpty);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.lists.created, ['Física']);
        final project = app.lists.projects.single;
        final saved = app.tasks.named('Estudiar el tema 2')!;
        expect(saved.listId, project.id);
        expect(saved.assignment, 'personal');
        // The sheet closed, saying what happened.
        expect(find.byType(CaptureResult), findsNothing);
        expect(
          find.textContaining(es.commandProjectsCreated(1)),
          findsOneWidget,
        );
        await tester.tap(find.text(es.undo));
        await tester.pumpAndSettle();
        expect(app.tasks.named('Estudiar el tema 2'), isNull);
        expect(app.lists.takenBack, [project.id]);
        // The result is back, as it was.
        expect(find.text(es.commandNewProject('Física')), findsOneWidget);
        expect(find.text(es.commandNewProjectChip('Física')), findsOneWidget);
        expect(app.store.current!.status, 'ready');
        expect(app.store.current!.commands.single.pending, isTrue);
        expect(app.store.current!.drafts.single.newProject, 'Física');
      },
    );

    testWidgets(
      'a project already there: «Ya tienes «Matemáticas»», nothing is created '
      'and the task goes to it',
      (tester) async {
        final app = await _App.open(tester, projects: [maths]);
        await app.showResult(
          tester,
          drafts: [draft('Repasar fracciones', listId: 'maths')],
          commands: [
            command({
              'kind': 'project',
              'name': 'Matemáticas',
              'existing_list_id': 'maths',
            }),
          ],
        );
        expect(
          find.text(es.commandExistingProject('Matemáticas')),
          findsOneWidget,
        );
        expect(find.text(es.commandExistingProjectTasks(1)), findsOneWidget);
        // Not a list of things to add: nothing new is made for the project.
        expect(find.text(es.captureThingsToAdd(2)), findsNothing);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.lists.created, isEmpty);
        expect(app.tasks.named('Repasar fracciones')!.listId, 'maths');
      },
    );

    testWidgets(
      'two projects match: create it or take one, one tap each; it waits for '
      'that tap, and the tasks follow the choice',
      (tester) async {
        final mathsTwo = TaskListInfo(id: 'maths2', name: 'Matemáticas II');
        final app = await _App.open(tester, projects: [maths, mathsTwo]);
        await app.showResult(
          tester,
          drafts: [draft('Ejercicio 4', newProject: 'Mates')],
          commands: [
            command({
              'kind': 'project',
              'name': 'Mates',
              'issues': ['ambiguous_project'],
            }),
          ],
        );
        expect(
          find.text(es.commandCreateProjectQuestion('Mates')),
          findsOneWidget,
        );
        expect(saveButton(tester).onPressed, isNull);
        expect(find.text(es.captureCheckDetails), findsOneWidget);
        // Neither is like «Mates»: both are in the project sheet.
        await tester.tap(find.byKey(const ValueKey('project-choice-other')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Matemáticas').last);
        await tester.pumpAndSettle();
        expect(
          find.text(es.commandExistingProject('Matemáticas')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.lists.created, isEmpty);
        expect(app.tasks.named('Ejercicio 4')!.listId, 'maths');
      },
    );

    testWidgets(
      'a project said that doesn’t exist is never created silently: «Crear '
      '«Química»», an existing project or none, one tap each, for every task '
      'that said it',
      (tester) async {
        final app = await _App.open(tester, projects: [physics]);
        await app.showResult(
          tester,
          drafts: [
            draft(
              'Repasar el tema 3',
              suggestion: 'química',
              issues: ['project_not_available'],
              hints: {'project': 'química'},
            ),
            draft(
              'Repasar el tema 4',
              suggestion: 'Química',
              issues: ['project_not_available'],
              hints: {'project': 'Química'},
            ),
          ],
        );
        expect(find.text(es.commandWhichProject), findsNWidgets(2));
        expect(find.text(es.commandCreateNamed('Química')), findsNWidgets(2));
        // Física isn't like «Química»: it is in the project sheet.
        expect(find.text(es.commandOtherProject), findsNWidgets(2));
        expect(find.text(es.noList), findsNWidgets(2));
        // Nothing is added until it is chosen.
        expect(saveButton(tester).onPressed, isNull);
        await tester.tap(
          find.byKey(const ValueKey('project-choice-create')).first,
        );
        await tester.pumpAndSettle();
        // One choice for both.
        expect(find.text(es.commandWhichProject), findsNothing);
        expect(
          find.text(es.commandNewProjectChip('Química')),
          findsNWidgets(2),
        );
        expect(app.lists.created, isEmpty);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        // One project, with both tasks in it.
        expect(app.lists.created, ['Química']);
        final id = app.lists.projects.last.id;
        expect(app.tasks.named('Repasar el tema 3')!.listId, id);
        expect(app.tasks.named('Repasar el tema 4')!.listId, id);
      },
    );

    testWidgets(
      'picking an existing project for a project said creates nothing',
      (tester) async {
        final app = await _App.open(tester, projects: [physics]);
        await app.showResult(
          tester,
          drafts: [
            draft(
              'Repasar el tema 3',
              suggestion: 'química',
              issues: ['project_not_available'],
            ),
          ],
        );
        await tester.tap(find.byKey(const ValueKey('project-choice-other')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Física').last);
        await tester.pumpAndSettle();
        expect(find.text('Física'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.lists.created, isEmpty);
        expect(app.tasks.named('Repasar el tema 3')!.listId, 'physics');
      },
    );

    testWidgets(
      'a task for a new project with a person named says they aren’t in it '
      'yet, and doesn’t wait',
      (tester) async {
        final app = await _App.open(tester);
        await app.showResult(
          tester,
          drafts: [
            draft(
              'Hacer la introducción',
              newProject: 'Matemáticas',
              issues: ['member_not_available'],
              hints: {'project': 'Matemáticas', 'member': 'Paul'},
            ),
          ],
          commands: [
            command({'kind': 'project', 'name': 'Matemáticas'}),
          ],
        );
        await tester.tap(find.text('Hacer la introducción'));
        await tester.pumpAndSettle();
        expect(
          find.text(es.commandMemberNotInNew('Paul', 'Matemáticas')),
          findsOneWidget,
        );
        expect(saveButton(tester).onPressed, isNotNull);
      },
    );

    testWidgets(
      'a search: its results newest first, completed ones marked, each with '
      'its project; a tap opens the task; «Abrir «Física»»; no tap needed, '
      'only «Cerrar»',
      (tester) async {
        final app = await _App.open(
          tester,
          projects: [physics],
          tasks: [
            Task(
              id: 3,
              title: 'Hacer la introducción',
              priority: 1,
              listId: 'physics',
              isCompleted: true,
            ),
            Task(
              id: 4,
              title: 'Introducción al tema 3',
              priority: 1,
              listId: 'physics',
              dueDate: day(5),
              hasTime: false,
            ),
            Task(id: 5, title: 'Comprar pan', priority: 1),
          ],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'find',
              'words': ['introducción'],
              'list_id': 'physics',
            }),
          ],
        );
        expect(find.text(es.commandFindWords('introducción')), findsOneWidget);
        final newer = tester.getTopLeft(find.text('Introducción al tema 3')).dy;
        final older = tester.getTopLeft(find.text('Hacer la introducción')).dy;
        expect(newer, lessThan(older));
        expect(find.text('Comprar pan'), findsNothing);
        expect(
          find.text('${weekday(day(5))} · Física'),
          findsOneWidget,
        );
        expect(find.text('Física · ${es.commandCompleted}'), findsOneWidget);
        // No sentence, and nothing to confirm.
        expect(find.byKey(const ValueKey('save-drafts')), findsNothing);
        expect(find.text(es.captureClose), findsOneWidget);
        expect(find.text(es.commandOpenProject('Física')), findsOneWidget);
        await tester.tap(find.text('Introducción al tema 3'));
        await tester.pumpAndSettle();
        expect(find.byType(TaskDetailScreen), findsOneWidget);
        // Back: the results are still there, under it.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(TaskDetailScreen), findsNothing);
        await tester.tap(find.text(es.commandOpenProject('Física')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<HomeScreen>(find.byType(HomeScreen).last).listId,
          'physics',
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        // Closing asks nothing: a search keeps nothing.
        await tester.tap(find.text(es.captureClose));
        await tester.pumpAndSettle();
        expect(find.byType(CaptureResult), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        expect(app.store.current!.status, 'discarded');
      },
    );

    testWidgets(
      'a search that finds nothing says so plainly; a project or a person '
      'not found gets its line and no list',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [Task(id: 1, title: 'Ir al médico', priority: 1)],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'find',
              'words': ['dentista'],
            }),
            command({
              'kind': 'find',
              'words': ['médico'],
              'project_name': 'Geografía',
              'issues': ['project_not_available'],
            }),
            command({
              'kind': 'find',
              'words': [],
              'person_name': 'Pol',
              'issues': ['member_not_available'],
            }),
          ],
        );
        expect(find.text(es.commandFindNone('dentista')), findsOneWidget);
        expect(
          find.text(es.commandProjectNotFound('Geografía')),
          findsOneWidget,
        );
        expect(find.text(es.commandPersonNotFound('Pol')), findsOneWidget);
        // Not searched in everything instead.
        expect(find.text('Ir al médico'), findsNothing);
      },
    );

    testWidgets(
      'a change with one match: «Ir al médico» and its day before → after; '
      '«Aplicar» changes only that, keeping notes and steps; Deshacer puts it '
      'back',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [
            Task(
              id: 1,
              title: 'Ir al médico',
              priority: 1,
              dueDate: day(3, 10),
              notes: 'Llevar los análisis',
              checklist: [ChecklistItem(id: 's1', title: 'Volante')],
              reminderMinutes: 30,
            ),
          ],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['médico'],
                'date': key(day(3)),
              },
              'changes': {'date': key(day(7))},
            }),
          ],
        );
        expect(find.text('Ir al médico'), findsOneWidget);
        expect(
          find.text(
            '${weekday(day(3))} · 10:00 → ${weekday(day(7))} · 10:00',
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            es.commandChangeSemantics(
              es.reviewSchedule,
              '${weekday(day(3))} · 10:00',
              '${weekday(day(7))} · 10:00',
            ),
          ),
          findsOneWidget,
        );
        expect(find.text(es.reschedule), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        final moved = app.tasks.byId(1)!;
        expect(moved.dueDate, day(7, 10));
        expect(moved.notes, 'Llevar los análisis');
        expect(moved.checklist.single.title, 'Volante');
        expect(moved.reminderMinutes, 30);
        expect(
          find.text(es.movedOccurrenceDate(weekday(day(7)))),
          findsOneWidget,
        );
        await tester.tap(find.text(es.undo));
        await tester.pumpAndSettle();
        expect(app.tasks.byId(1)!.dueDate, day(3, 10));
        // The result is back to apply again.
        expect(find.text(es.reschedule), findsOneWidget);
      },
    );

    testWidgets(
      'several matches: a short list to tap one, then its before → after, '
      'with «Elegir otra»',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [
            Task(id: 7, title: 'Llamar a Ana', priority: 1, dueDate: day(2, 9)),
            Task(
              id: 8,
              title: 'Llamar a Ana por el viaje',
              priority: 1,
              dueDate: day(4, 9),
            ),
          ],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['llamar', 'ana'],
              },
              'changes': {'time': '18:00'},
            }),
          ],
        );
        expect(find.text(es.commandWhichToChange), findsOneWidget);
        final newer = tester.getTopLeft(find.text('Llamar a Ana por el viaje'));
        final older = tester.getTopLeft(find.text('Llamar a Ana'));
        expect(newer.dy, lessThan(older.dy));
        expect(saveButton(tester).onPressed, isNull);
        await tester.tap(find.text('Llamar a Ana'));
        await tester.pumpAndSettle();
        expect(find.text(es.commandWhichToChange), findsNothing);
        expect(
          find.text('${weekday(day(2))} · 09:00 → ${weekday(day(2))} · 18:00'),
          findsOneWidget,
        );
        expect(find.text(es.commandChooseAnother), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.tasks.byId(7)!.dueDate, day(2, 18));
        expect(app.tasks.byId(8)!.dueDate, day(4, 9));
      },
    );

    testWidgets(
      'no match: it says so with the words looked for, and nothing waits',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [Task(id: 1, title: 'Ir al médico', priority: 1)],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['dentista'],
              },
              'changes': {'priority': 3},
            }),
            command({
              'kind': 'delete',
              'target': {
                'words': ['gimnasio'],
              },
            }),
          ],
        );
        expect(find.text(es.commandTaskNotFound('dentista')), findsOneWidget);
        expect(find.text(es.commandTaskNotFound('gimnasio')), findsOneWidget);
        expect(find.byKey(const ValueKey('save-drafts')), findsNothing);
        await tester.tap(find.text(es.captureClose));
        await tester.pumpAndSettle();
        expect(find.byType(CaptureResult), findsNothing);
        expect(app.tasks.byId(1)!.priority, 1);
      },
    );

    testWidgets(
      'other changes before → after, and a person who isn’t in the project '
      'leaves the assignee as it is, saying so',
      (tester) async {
        final app = await _App.open(
          tester,
          projects: [team],
          tasks: [
            Task(
              id: 1,
              title: 'Informe',
              priority: 1,
              listId: 'team',
              assignment: 'group',
            ),
            Task(
              id: 2,
              title: 'Presupuesto',
              priority: 2,
              listId: 'team',
              assignment: 'group',
              notes: 'Revisar',
            ),
          ],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['informe'],
              },
              'changes': {
                'title': 'Informe final',
                'assignee_id': 3,
                'assignee_name': 'Paul',
              },
            }),
            command({
              'kind': 'update',
              'target': {
                'words': ['presupuesto'],
              },
              'changes': {
                'priority': 3,
                'notes_append': 'Con IVA',
                'assignee_name': 'Pol',
              },
              'issues': ['member_not_available'],
            }),
          ],
        );
        expect(find.text('Informe → Informe final'), findsOneWidget);
        expect(find.text('${es.assignedToGroup} → Paul'), findsOneWidget);
        expect(find.text('${es.medium} → ${es.high}'), findsOneWidget);
        expect(find.text(es.commandNotesAdd('Con IVA')), findsOneWidget);
        expect(find.text(es.commandMemberNotIn('Pol', 'Equipo')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        final report = app.tasks.byId(1)!;
        expect(report.title, 'Informe final');
        expect(report.assignment, 'member');
        expect(report.assigneeId, 3);
        final budget = app.tasks.byId(2)!;
        expect(budget.priority, 3);
        expect(budget.notes, 'Revisar\nCon IVA');
        expect(budget.assignment, 'group');
        expect(find.text(es.commandTasksChanged(2)), findsOneWidget);
      },
    );

    testWidgets(
      'nothing said to change opens the task to edit it',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [Task(id: 1, title: 'Ir al médico', priority: 1)],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['médico'],
              },
              'changes': {},
            }),
          ],
        );
        expect(find.byKey(const ValueKey('save-drafts')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('command-edit-task')));
        await tester.pumpAndSettle();
        expect(find.byType(EditTaskScreen), findsOneWidget);
        expect(app.tasks.byId(1)!.title, 'Ir al médico');
      },
    );

    testWidgets(
      'a time for a task with no day asks «¿Qué día?» first',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [Task(id: 1, title: 'Recoger las gafas', priority: 1)],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['gafas'],
              },
              'changes': {'time': '18:00'},
            }),
          ],
        );
        expect(find.text(es.commandWhichDay(18, '18:00')), findsOneWidget);
        expect(saveButton(tester).onPressed, isNull);
        await tester.tap(find.widgetWithText(ChoiceChip, es.tomorrow));
        await tester.pumpAndSettle();
        expect(
          find.text('${es.noDate} → ${es.tomorrow} · 18:00'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.tasks.byId(1)!.dueDate, day(1, 18));
        expect(app.tasks.byId(1)!.hasTime, isTrue);
      },
    );

    testWidgets(
      'a repeating task’s new day moves this repetition, or the whole series '
      'when chosen, as Cambiar fecha does',
      (tester) async {
        final start = day(1, 19);
        final weekly = Task(
          id: 9,
          title: 'Clase de yoga',
          priority: 1,
          dueDate: start,
          recurrence: 'weekly',
        );
        final next = DateTime(start.year, start.month, start.day + 7);
        final app = await _App.open(tester, tasks: [weekly]);
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['yoga'],
                'date': key(next),
              },
              'changes': {
                'date': key(DateTime(next.year, next.month, next.day + 1)),
              },
            }),
          ],
        );
        expect(find.text(es.thisOccurrence), findsOneWidget);
        expect(find.text(es.wholeSeries), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        final series = app.tasks.byId(9)!;
        // Only that repetition moved; the series starts where it did.
        expect(series.dueDate, start);
        expect(series.exceptions.single.originalDate, key(next));
        expect(
          series.exceptions.single.date,
          DateTime(next.year, next.month, next.day + 1, 19),
        );
        await tester.tap(find.text(es.undo));
        await tester.pumpAndSettle();
        expect(app.tasks.byId(9)!.exceptions, isEmpty);
        await tester.tap(find.byKey(const ValueKey('command-series-true')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(
          app.tasks.byId(9)!.dueDate,
          DateTime(next.year, next.month, next.day + 1, 19),
        );
        expect(app.tasks.byId(9)!.exceptions, isEmpty);
      },
    );

    testWidgets(
      'a deletion in the error colour: «Se eliminará: Ir al médico (…)»; '
      '«Eliminar» deletes it, then «Tarea eliminada · Deshacer»',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [
            Task(
              id: 1,
              title: 'Ir al médico',
              priority: 1,
              dueDate: day(3),
              hasTime: false,
              notes: 'Llevar los análisis',
            ),
          ],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'delete',
              'target': {
                'words': ['médico'],
              },
            }),
          ],
        );
        final line = es.commandWillDeleteOn('Ir al médico', weekday(day(3)));
        expect(find.text(line), findsOneWidget);
        final colors = Theme.of(tester.element(find.text(line))).colorScheme;
        expect(tester.widget<Text>(find.text(line)).style?.color, colors.error);
        expect(find.text(es.delete), findsOneWidget);
        // Nothing is deleted before the tap.
        expect(app.tasks.byId(1), isNotNull);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.tasks.byId(1), isNull);
        expect(find.text(es.commandTasksDeleted(1)), findsOneWidget);
        expect(es.commandTasksDeleted(1), es.taskDeleted);
        await tester.tap(find.text(es.undo));
        await tester.pumpAndSettle();
        expect(app.tasks.byId(1)!.notes, 'Llevar los análisis');
      },
    );

    testWidgets(
      'deleting a whole repeating series asks first, with «Conservar tarea» '
      'as the filled button (D11)',
      (tester) async {
        final weekly = Task(
          id: 9,
          title: 'Clase de yoga',
          priority: 1,
          dueDate: day(1, 19),
          recurrence: 'weekly',
        );
        final app = await _App.open(tester, tasks: [weekly]);
        final delete = command({
          'kind': 'delete',
          'target': {
            'words': ['yoga'],
          },
        });
        await app.showResult(tester, commands: [delete]);
        expect(
          find.text(es.commandWillDeleteOn('Clase de yoga', es.weekly)),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(find.text(es.deleteSeriesHelp('Clase de yoga')), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, es.keepTask),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(FilledButton, es.keepTask));
        await tester.pumpAndSettle();
        // Kept, and nothing else to do here.
        expect(app.tasks.byId(9), isNotNull);
        expect(find.byType(CaptureResult), findsNothing);

        await app.showResult(tester, commands: [delete]);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, es.delete));
        await tester.pumpAndSettle();
        expect(app.tasks.byId(9), isNull);
      },
    );

    testWidgets(
      'a mixed result: a task, a change and a deletion, all with one tap, '
      'and one Deshacer takes all of them back',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [
            Task(
              id: 1,
              title: 'Ir al médico',
              priority: 1,
              dueDate: day(3, 10),
            ),
            Task(id: 2, title: 'Dentista', priority: 1, dueDate: day(5, 9)),
          ],
        );
        await app.showResult(
          tester,
          drafts: [draft('Comprar pan', date: day(1))],
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['médico'],
              },
              'changes': {'date': key(day(7))},
            }),
            command({
              'kind': 'delete',
              'target': {
                'words': ['dentista'],
              },
            }),
          ],
        );
        // The task's card first, then the change and the deletion.
        final bread = tester.getTopLeft(find.text('Comprar pan')).dy;
        final change = tester.getTopLeft(find.text('Ir al médico')).dy;
        final deletion = tester
            .getTopLeft(
              find.text(
                es.commandWillDeleteOn('Dentista', weekday(day(5))),
              ),
            )
            .dy;
        expect(bread, lessThan(change));
        expect(change, lessThan(deletion));
        expect(find.text(es.commandAddChangeAndDelete), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.tasks.named('Comprar pan'), isNotNull);
        expect(app.tasks.byId(1)!.dueDate, day(7, 10));
        expect(app.tasks.byId(2), isNull);
        expect(
          find.text(
            [
              es.taskAddedOn(weekday(day(1))),
              es.movedOccurrenceDate(weekday(day(7))),
              es.commandTasksDeleted(1),
            ].join(' · '),
          ),
          findsOneWidget,
        );
        await tester.tap(find.text(es.undo));
        await tester.pumpAndSettle();
        expect(app.tasks.named('Comprar pan'), isNull);
        expect(app.tasks.byId(1)!.dueDate, day(3, 10));
        expect(app.tasks.byId(2), isNotNull);
        expect(find.byType(CaptureResult), findsOneWidget);
      },
    );

    testWidgets(
      'a card taken out (✕) does nothing; a new project taken out takes its '
      'task out of it',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [Task(id: 1, title: 'Dentista', priority: 1)],
        );
        await app.showResult(
          tester,
          drafts: [draft('Estudiar', newProject: 'Física')],
          commands: [
            command({'kind': 'project', 'name': 'Física'}),
            command({
              'kind': 'delete',
              'target': {
                'words': ['dentista'],
              },
            }),
          ],
        );
        // The deletion first: «No se eliminará» then floats over the cards'
        // end.
        await tester.tap(find.byTooltip(es.commandDontDelete('Dentista')));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(es.commandDontCreate('Física')));
        await tester.pumpAndSettle();
        expect(find.text(es.commandNewProject('Física')), findsNothing);
        expect(find.textContaining('Dentista'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.lists.created, isEmpty);
        expect(app.tasks.named('Estudiar')!.listId, isNull);
        expect(app.tasks.byId(1), isNotNull);
      },
    );
  });

  group('dictations', () {
    testWidgets(
      'a plain single-task dictation looks and saves exactly as before, '
      'with no new tap',
      (tester) async {
        final app = await _App.open(tester);
        app.api.answer = {
          'transcript': 'Comprar pan mañana',
          'tasks': [serverTask('Comprar pan', date: day(1))],
          'commands': [],
        };
        await app.speak(tester, 'Comprar pan mañana');
        expect(app.api.drafts.single['commands'], isTrue);
        expect(find.byType(CaptureResult), findsOneWidget);
        for (final type in [
          ProjectCommandCard,
          FindCommandCard,
          UpdateCommandCard,
          DeleteCommandCard,
        ]) {
          expect(find.byType(type), findsNothing);
        }
        expect(find.text(es.captureThingsToAdd(1)), findsNothing);
        expect(find.text(es.captureAddToCalendar), findsOneWidget);
        app.store.updates = 0;
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        // Saved straight away, as before: nothing written first.
        expect(app.store.updates, 0);
        expect(app.store.saves, 1);
        expect(app.tasks.named('Comprar pan')!.dueDate, day(1));
        expect(find.text(es.taskAddedOn(weekday(day(1)))), findsOneWidget);
        expect(app.api.drafts, hasLength(1));
      },
    );

    testWidgets(
      'a dictation that creates a project, adds a task to it and deletes '
      'another: one request, one tap, one Deshacer',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [Task(id: 1, title: 'Dentista', priority: 1)],
        );
        app.api.answer = {
          'transcript': 'Crea el proyecto Física…',
          'tasks': [
            serverTask('Estudiar el tema 2', date: day(4), newProject: 'Física'),
          ],
          'commands': [
            {'kind': 'project', 'name': 'Física', 'existing_list_id': null, 'issues': []},
            {
              'kind': 'delete',
              'target': {'words': ['dentista'], 'list_id': null, 'project_name': null, 'date': null},
              'issues': [],
            },
          ],
        };
        await app.speak(
          tester,
          'Crea el proyecto Física, añade estudiar el tema 2 y borra el dentista',
        );
        expect(app.api.drafts, hasLength(1));
        expect(find.text(es.commandNewProject('Física')), findsOneWidget);
        expect(find.text(es.commandNewProjectChip('Física')), findsOneWidget);
        expect(
          find.text(es.commandWillDelete('Dentista')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.lists.created, ['Física']);
        expect(
          app.tasks.named('Estudiar el tema 2')!.listId,
          app.lists.projects.single.id,
        );
        expect(app.tasks.byId(1), isNull);
        await tester.tap(find.text(es.undo));
        await tester.pumpAndSettle();
        expect(app.tasks.named('Estudiar el tema 2'), isNull);
        expect(app.tasks.byId(1), isNotNull);
        expect(app.lists.projects, isEmpty);
        expect(app.api.drafts, hasLength(1));
      },
    );

    testWidgets(
      'Pro typed words go to the assistant asking for commands',
      (tester) async {
        final app = await _App.open(tester);
        app.api.answer = {
          'transcript': 'Busca el informe',
          'tasks': [],
          'commands': [
            {'kind': 'find', 'words': ['informe'], 'status': 'any', 'issues': []},
          ],
        };
        await app.type(tester, 'Busca el informe');
        expect(app.api.drafts.single['text'], 'Busca el informe');
        expect(app.api.drafts.single['source'], 'typed');
        expect(app.api.drafts.single['commands'], isTrue);
        expect(find.text(es.commandFindWords('informe')), findsOneWidget);
      },
    );

    testWidgets(
      'without Pro, typed words never reach the assistant: «Escribir» '
      'opens the form, and a dictation still asks for commands',
      (tester) async {
        final app = await _App.open(tester, pro: false, freeLeft: 5);
        await tester.tap(find.text(es.addTask).hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('capture-fill-by-hand')));
        await tester.pumpAndSettle();
        expect(find.byType(NewTaskScreen), findsOneWidget);
        expect(app.api.drafts, isEmpty);
        // Back from the empty form just closes it.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(NewTaskScreen), findsNothing);
        app.api.answer = {
          'transcript': 'Borra la tarea del dentista',
          'tasks': [],
          'commands': [
            {
              'kind': 'delete',
              'target': {'words': ['dentista']},
              'issues': [],
            },
          ],
        };
        await app.speak(tester, 'Borra la tarea del dentista');
        expect(app.api.drafts.single['commands'], isTrue);
        expect(app.api.drafts.single['source'], 'speech');
        expect(
          find.text(es.commandTaskNotFound('dentista')),
          findsOneWidget,
        );
      },
    );
  });

  group('large text on a small phone', () {
    for (final (language, l) in [('es', es), ('ca', ca)]) {
      testWidgets(
        'every kind of card fits at 2× text on 320 dp ($language)',
        (tester) async {
          final app = await _App.open(
            tester,
            language: language,
            size: const Size(320, 640),
            textScale: 2,
            projects: [physics, team],
            tasks: [
              Task(
                id: 1,
                title: 'Ir al médico de cabecera para la revisión',
                priority: 1,
                dueDate: day(3, 10),
              ),
              Task(
                id: 2,
                title: 'Introducción al tema 3 de la asignatura',
                priority: 1,
                listId: 'physics',
                isCompleted: true,
              ),
              Task(id: 3, title: 'Dentista', priority: 1, dueDate: day(5)),
              Task(
                id: 4,
                title: 'Informe trimestral',
                priority: 1,
                listId: 'team',
                assignment: 'group',
              ),
            ],
          );
          await app.showResult(
            tester,
            drafts: [
              draft(
                'Estudiar el tema 2 con los apuntes nuevos',
                date: day(4),
                newProject: 'Física y Química',
                issues: ['member_not_available'],
                hints: {'member': 'Paul'},
              ),
              draft(
                'Repasar el tema 3',
                suggestion: 'geografía e historia',
                issues: ['project_not_available'],
              ),
            ],
            commands: [
              command({'kind': 'project', 'name': 'Física y Química'}),
              command({
                'kind': 'find',
                'words': ['introducción'],
                'list_id': 'physics',
              }),
              command({
                'kind': 'update',
                'target': {
                  'words': ['médico'],
                },
                'changes': {'date': key(day(7)), 'time': '18:30'},
              }),
              command({
                'kind': 'update',
                'target': {
                  'words': ['informe'],
                },
                'changes': {'assignee_name': 'Pol'},
                'issues': ['member_not_available'],
              }),
              command({
                'kind': 'delete',
                'target': {
                  'words': ['dentista'],
                },
              }),
            ],
          );
          expect(tester.takeException(), isNull);
          expect(
            find.text(l.commandWhichProject),
            findsWidgets,
          );
          // Every card can be scrolled to, and the button stays in view.
          for (final text in [
            l.commandFindWords('introducción'),
            l.commandMemberNotIn('Pol', 'Equipo'),
            l.commandWillDeleteOn('Dentista', weekday(day(5))),
          ]) {
            await tester.scrollUntilVisible(
              find.text(text),
              200,
              scrollable: find
                  .descendant(
                    of: find.byType(CaptureResult),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            expect(tester.takeException(), isNull);
          }
          expect(
            find.byKey(const ValueKey('save-drafts')).hitTestable(),
            findsOneWidget,
          );
          // The project said still waits for its choice; the rest can go.
          expect(find.text(l.commandAddChangeAndDelete), findsOneWidget);
          await tester.ensureVisible(
            find.byKey(const ValueKey('project-choice-none')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('project-choice-none')));
          await tester.pumpAndSettle();
          expect(find.text(l.commandAddChangeAndDelete), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final (language, l) in [('es', es), ('ca', ca)]) {
      testWidgets(
        'a search alone, and a deletion alone, fit at 2× text on 320 dp '
        '($language)',
        (tester) async {
          final app = await _App.open(
            tester,
            language: language,
            size: const Size(320, 640),
            textScale: 2,
            tasks: [
              Task(id: 1, title: 'Ir al médico', priority: 1, dueDate: day(3)),
            ],
          );
          await app.showResult(
            tester,
            commands: [
              command({
                'kind': 'find',
                'words': ['médico'],
              }),
            ],
          );
          expect(tester.takeException(), isNull);
          expect(find.text(l.captureClose).hitTestable(), findsOneWidget);
          await tester.tap(find.text(l.captureClose));
          await tester.pumpAndSettle();
          await app.showResult(
            tester,
            commands: [
              command({
                'kind': 'delete',
                'target': {
                  'words': ['médico'],
                },
              }),
            ],
          );
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('save-drafts')).hitTestable(),
            findsOneWidget,
          );
          expect(find.text(l.delete), findsOneWidget);
        },
      );
    }
  });

  // Run 2026-10-18-commands, round 1 (P127–P130): last, because its final
  // group loads Manrope for the tests after it.
  _commandsRound1();
  _commandsRound2();
  _commandsRound2b();
  _commandsRound3();
  _commandsRound3b();
  _commandsRound4();
  _commandsRound5();
}

/// The phone's recognizer, shared by the tests: it listens until stopped,
/// and the test says what it hears.
class SharedSpeech extends NativeSpeech {
  static SharedSpeech current = SharedSpeech();
  static void reset() => current = SharedSpeech();
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
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
  }) async => _run = id;
  void send(String kind, {String? text}) =>
      _events.add(SpeechEvent(_run!, kind, text: text));
  @override
  Future<void> stop(int id) async {
    if (_run != null) send('ended');
  }

  @override
  Future<void> cancel(int id) async {}
}

/// The app on Calendar, in [language], with tasks, projects and captures in
/// memory, and a server that answers dictations with [_Api.answer].
class _App {
  _App(this.container, this.store, this.tasks, this.lists, this.api);
  final ProviderContainer container;
  final _Captures store;
  final _Tasks tasks;
  final _Lists lists;
  final _Api api;

  static Future<_App> open(
    WidgetTester tester, {
    List<Task> tasks = const [],
    List<TaskListInfo> projects = const [],
    bool pro = true,
    int? freeLeft,
    String language = 'es',
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (textScale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    final messenger = tester.binding.defaultBinaryMessenger;
    const timezone = MethodChannel('flutter_timezone');
    messenger.setMockMethodCallHandler(timezone, (_) async => 'Europe/Madrid');
    addTearDown(() => messenger.setMockMethodCallHandler(timezone, null));
    // Messages read the phone's timeout; none is set here.
    const timeout = MethodChannel('taskflow/accessibility');
    messenger.setMockMethodCallHandler(timeout, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(timeout, null));
    appContext = () => tester.element(find.byType(Scaffold).first);
    final notes = _Tasks(tasks);
    final store = _Captures(notes);
    final lists = _Lists(projects);
    final api = _Api();
    final user = <String, dynamic>{
      'id': 1,
      'email': 'design@example.invalid',
      'timezone': 'Europe/Madrid',
      if (freeLeft != null)
        'free_voice': {
          'limit': 10,
          'left': freeLeft,
          'resets_at': DateTime.now()
              .add(const Duration(days: 20))
              .toUtc()
              .toIso8601String(),
        },
    };
    final container = ProviderContainer(
      overrides: [
        invitationLinkProvider.overrideWith(
          (ref) => InvitationLinks(listen: false),
        ),
        hasProProvider.overrideWithValue(pro),
        billingLoadingProvider.overrideWithValue(false),
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) => _Auth(api, user)),
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
        taskListsProvider.overrideWith((ref) async => [...lists.projects]),
        taskListStoreProvider.overrideWithValue(lists),
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => notes),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        captureStoreProvider.overrideWithValue(store),
        nativeSpeechProvider.overrideWithValue(SharedSpeech.current),
        captureRecorderFactoryProvider.overrideWithValue(SilentRecorder.new),
      ],
    );
    addTearDown(() {
      container.dispose();
      api.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    return _App(container, store, notes, lists, api);
  }

  /// Opens the capture sheet on a result, as resuming a capture does.
  Future<void> showResult(
    WidgetTester tester, {
    List<CaptureDraft> drafts = const [],
    List<CaptureCommand> commands = const [],
  }) async {
    final session = CaptureSession(
      id: const Uuid().v4(),
      ownerKey: container.read(captureOwnerProvider),
      timezone: 'Europe/Madrid',
      capturedAt: DateTime.now().toUtc(),
      status: 'ready',
      source: 'speech',
      transcript: 'Lo que dije',
      drafts: drafts,
      commands: commands,
    );
    store.sessions[session.id] = session;
    unawaited(
      showCaptureSheet(
        tester.element(find.byType(Scaffold).first),
        captureId: session.id,
        startListening: false,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// `Añadir tarea` listening, the recognizer hears [words], then `Listo`.
  Future<void> speak(WidgetTester tester, String words) async {
    await tester.tap(find.text(es.addTask).hitTestable());
    await tester.pumpAndSettle();
    SharedSpeech.current.send('ready');
    SharedSpeech.current.send('segment', text: words);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, es.done));
    await tester.pumpAndSettle();
  }

  /// `Añadir tarea`, `Escribir`, [words] and `Listo`.
  Future<void> type(WidgetTester tester, String words) async {
    await tester.tap(find.text(es.addTask).hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(es.captureTypeInstead));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('capture-words')), words);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, es.done));
    await tester.pumpAndSettle();
  }
}

/// A signed-in account from [user], at once.
class _Auth extends AuthNotifier {
  _Auth(super.api, this.user);
  final Map<String, dynamic> user;
  @override
  Future<void> restore() async {
    state = AuthState(account: Account.fromJson(user));
  }
}

/// The assistant: records each dictation's fields and answers [answer].
class _Api extends OfflineApiClient {
  final drafts = <Map<String, dynamic>>[];
  Map<String, dynamic> answer = const {'transcript': '', 'tasks': []};
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    if (method == 'POST' && path == 'ai/drafts/') {
      drafts.add({...?data});
      return answer;
    }
    throw ApiException(0, 'Offline. Retry when connected.');
  }
}

/// Tasks in memory, numbered as they are added; a repetition moves as the
/// app's own does.
class _Tasks extends DesignTaskNotifier {
  _Tasks(this.initial);
  final List<Task> initial;
  int _next = 100;

  Task? byId(int id) =>
      state.requireValue.where((task) => task.id == id).firstOrNull;
  Task? named(String title) =>
      state.requireValue.where((task) => task.title == title).firstOrNull;

  @override
  Future<void> loadTasks() async {
    if (!state.hasValue) state = AsyncData([...initial]);
  }

  @override
  Future<void> showLocal() async {}

  @override
  Future<int> addTask(Task task) async {
    final id = _next++;
    state = AsyncData([...state.requireValue, task.copyWith(id: id)]);
    return id;
  }

  @override
  Future<void> addTasks(List<Task> tasks) async {
    for (final task in tasks) {
      await addTask(task);
    }
  }

  @override
  Future<OccurrenceChange> changeOccurrence(
    Task occurrence,
    DateTime? date,
    bool hasTime, {
    bool skip = false,
    bool reset = false,
  }) async {
    final task = byId(occurrence.id!)!;
    final key = occurrence.occurrenceId!;
    final before = task.exceptions
        .where((change) => change.originalDate == key)
        .firstOrNull;
    final after = OccurrenceException(
      originalDate: key,
      date: hasTime ? date : Task.day(date!),
      hasTime: hasTime,
    );
    await updateTask(
      task.copyWith(
        exceptions: [
          ...task.exceptions.where((change) => change.originalDate != key),
          after,
        ],
      ),
    );
    return OccurrenceChange(task, key, before, after);
  }

  @override
  Future<bool> undoOccurrence(OccurrenceChange change) async {
    final task = byId(change.series.id!);
    if (task == null || !change.canUndo(task)) return false;
    await updateTask(change.restore(task));
    return true;
  }
}

/// Projects in memory: created ones are added, and taken back.
class _Lists extends TaskListStore {
  _Lists(List<TaskListInfo> projects)
    : projects = [...projects],
      super(TaskDatabase(), 'test');
  final List<TaskListInfo> projects;
  final created = <String>[];
  final takenBack = <String>[];

  @override
  Future<List<TaskListInfo>> all() async => [...projects];

  @override
  Future<void> create(TaskListInfo list) async {
    projects.add(list);
    created.add(list.name);
  }

  @override
  Future<bool> takeBack(String id, {ApiClient? api, int? accountId}) async {
    takenBack.add(id);
    projects.removeWhere((project) => project.id == id);
    return true;
  }
}

/// Every capture in memory, by id. Saving adds the drafts' tasks and is done
/// once no draft and no command waits, as the real store's transaction is;
/// Undo takes them out again.
class _Captures extends CaptureStore {
  _Captures(this.tasks) : super(TaskDatabase());
  final _Tasks tasks;
  final sessions = <String, CaptureSession>{};
  int updates = 0;
  int saves = 0;

  /// The capture last opened or written.
  CaptureSession? current;

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
      id: id ?? const Uuid().v4(),
      ownerKey: ownerKey,
      timezone: timezone,
      capturedAt: (now ?? DateTime.now()).toUtc(),
      text: text,
      kind: kind,
      projectId: projectId,
      source: source,
      day: day,
      language: language,
    );
    return sessions[session.id] = current = session;
  }

  @override
  Future<void> update(CaptureSession value) async {
    if (sessions[value.id]?.terminal ?? false) {
      throw StateError('This capture is no longer available.');
    }
    updates++;
    sessions[value.id] = current = value;
  }

  @override
  Future<CaptureSession?> read(String id, String ownerKey) async {
    final session = sessions[id];
    if (session != null) current = session;
    return session;
  }

  @override
  Future<List<CaptureSession>> pending(String ownerKey) async => [];

  @override
  Future<void> cleanFinished(String ownerKey) async {}

  @override
  Future<void> discard(String id, String ownerKey) async {
    final session = sessions[id];
    if (session != null && !session.terminal) {
      sessions[id] = current = session.copyWith(status: 'discarded');
    }
  }

  @override
  Future<CaptureSession> saveReady(
    String id,
    String ownerKey,
    Set<String> draftIds,
  ) async {
    saves++;
    final session = sessions[id]!;
    final drafts = [
      for (final draft in session.drafts)
        if (draftIds.contains(draft.id) && draft.pending)
          draft.copyWith(savedTaskId: await tasks.addTask(draft.task))
        else
          draft,
    ];
    final completed =
        (drafts.isNotEmpty || session.commands.isNotEmpty) &&
        drafts.every((d) => !d.pending) &&
        session.commands.every((c) => !c.pending);
    return sessions[id] = current = session.copyWith(
      drafts: drafts,
      status: completed ? 'saved' : 'ready',
      commands: completed ? const [] : session.commands,
    );
  }

  @override
  Future<CaptureSession?> undoSave(
    CaptureSession before,
    Map<String, int> savedIds,
  ) async {
    for (final id in savedIds.values) {
      await tasks.deleteTask(id);
    }
    return sessions[before.id] = current = before.copyWith(
      status: 'ready',
      drafts: [
        for (final draft in before.drafts)
          savedIds.containsKey(draft.id)
              ? draft.copyWith(clearSavedTaskId: true)
              : draft,
      ],
    );
  }
}

// ---- Run 2026-10-18-commands, round 1 ----------------------------------
//
// P127 (UX-901, UX-904): a result whose commands all found nothing still
// ends in a task. P128 (UX-903, UX-905): each tap says what it does. P129
// (UX-902, UX-906): deadline-only tasks show and land on their due day, and
// a project made by voice opens. P130 (UX-1001): a task for someone else
// lands in view.

/// The next Saturday as the phone's parser reads «el sábado»: today when
/// today is Saturday.
DateTime _saturday() {
  final today = day(0);
  return day((DateTime.saturday - today.weekday + 7) % 7);
}

/// A draft with only a deadline, [deadline], and no day.
CaptureDraft _dueDraft(
  String title,
  DateTime deadline, {
  String? newProject,
  String? listId,
}) => CaptureDraft.fromAI(
  TaskDraft.fromJson({
    ...serverTask(title, newProject: newProject, listId: listId),
    'deadline_date': key(deadline),
    'transcript': 'Lo que dije',
  }),
);

Finder _asWritten() => find.byKey(const ValueKey('result-save-as-written'));
Finder _close() => find.byKey(const ValueKey('capture-result-close'));
Finder _row(String title) => find.widgetWithText(TaskTile, title);
Color _lit(WidgetTester tester) => Theme.of(
  tester.element(find.byType(Scaffold).first),
).colorScheme.primaryContainer;

/// The confirming button's label, as shown.
String _buttonLabel(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('save-drafts')),
        matching: find.byType(Text),
      ),
    )
    .data!;

/// Every filled button in the result, of any kind (`FilledButton.icon` too).
Finder _filledInResult() => find.descendant(
  of: find.byType(CaptureResult),
  matching: find.byWidgetPredicate((widget) => widget is FilledButton),
);

void _commandsRound1() {
  group('UX-901: a command that found nothing still becomes a task', () {
    Map<String, dynamic> oilChange() => {
      'transcript': 'Cambia el aceite del coche el sábado',
      'tasks': [],
      'commands': [
        {
          'kind': 'update',
          'target': {
            'words': ['aceite', 'coche'],
          },
          'changes': {'date': key(_saturday())},
          'issues': [],
        },
      ],
    };

    testWidgets(
      'UX-901: a dictation answered with one change that finds no task shows '
      'No encuentro…, a filled full-width «Guardar como tarea», and «Cerrar» '
      'under it',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [Task(id: 1, title: 'Ir al médico', priority: 1)],
        );
        app.api.answer = oilChange();
        await app.speak(tester, 'Cambia el aceite del coche el sábado');
        expect(
          find.text(es.commandTaskNotFound('aceite coche')),
          findsOneWidget,
        );
        expect(_asWritten(), findsOneWidget);
        expect(tester.widget(_asWritten()), isA<FilledButton>());
        expect(
          find.descendant(
            of: _asWritten(),
            matching: find.text(es.captureSaveAsWritten),
          ),
          findsOneWidget,
        );
        expect(es.captureSaveAsWritten, 'Guardar como tarea');
        // The only filled button: nothing else to confirm.
        expect(_filledInResult(), findsOneWidget);
        expect(find.byKey(const ValueKey('save-drafts')), findsNothing);
        expect(
          find.descendant(of: _close(), matching: find.text(es.captureClose)),
          findsOneWidget,
        );
        final button = tester.getRect(_asWritten());
        final close = tester.getRect(_close());
        expect(button.bottom, lessThanOrEqualTo(close.top));
        // Full width: the sheet's width less its 24 dp sides.
        final sheet = tester.getRect(find.byType(CaptureResult));
        expect(button.width, greaterThanOrEqualTo(sheet.width - 48 - 1));
        expect(_asWritten().hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-901: «Guardar como tarea» sends nothing more to the assistant, saves '
      '«Cambia el aceite del coche» on Saturday with no command applied, '
      'closes the sheet, and Calendar shows Saturday with the row lit and '
      '«Añadida al …» with Deshacer',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [Task(id: 1, title: 'Ir al médico', priority: 1)],
        );
        app.api.answer = oilChange();
        await app.speak(tester, 'Cambia el aceite del coche el sábado');
        expect(app.api.drafts, hasLength(1));
        await tester.tap(_asWritten());
        await tester.pumpAndSettle();
        expect(app.api.drafts, hasLength(1), reason: 'no second request');
        final saved = app.tasks.named('Cambia el aceite del coche');
        expect(saved, isNotNull);
        expect(Task.day(saved!.dueDate!), _saturday());
        // Nothing was changed by the command, and the capture keeps none.
        expect(app.tasks.byId(1)!.dueDate, isNull);
        expect(app.store.current!.commands, isEmpty);
        expect(find.byType(CaptureResult), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        final message = es.taskAddedOn(weekday(_saturday()));
        expect(find.text(message), findsOneWidget);
        expect(find.text(es.undo), findsOneWidget);
        final row = _row('Cambia el aceite del coche');
        expect(row.hitTestable(), findsOneWidget);
        expect(tester.widget<TaskTile>(row).color, _lit(tester));
        if (_saturday().difference(day(0)).inDays >= 2) {
          expect(
            find.text(DateFormat.MMMMEEEEd('es').format(_saturday())),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-901: a search that finds nothing («Busca piso en Valencia») shows '
      '«Guardar como tarea» above «Cerrar»; a search that finds two tasks shows '
      'no filled button, only «Cerrar»',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [
            Task(id: 1, title: 'Revisar el informe', priority: 1),
            Task(id: 2, title: 'Enviar el informe', priority: 1),
          ],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'find',
              'words': ['piso', 'valencia'],
            }),
          ],
        );
        expect(find.text(es.commandFindNone('piso valencia')), findsOneWidget);
        expect(_asWritten(), findsOneWidget);
        expect(
          tester.getRect(_asWritten()).bottom,
          lessThanOrEqualTo(tester.getRect(_close()).top),
        );
        await tester.tap(_close());
        await tester.pumpAndSettle();
        expect(find.byType(CaptureResult), findsNothing);

        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'find',
              'words': ['informe'],
            }),
          ],
        );
        expect(
          find.descendant(
            of: find.byType(CaptureResult),
            matching: find.text('Revisar el informe'),
          ),
          findsOneWidget,
        );
        expect(_asWritten(), findsNothing);
        expect(_filledInResult(), findsNothing);
        expect(_close(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-901: a change that found its task with nothing to change («Ya está '
      'así.») shows no «Guardar como tarea»',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [Task(id: 1, title: 'Ir al médico', priority: 1)],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['médico'],
              },
              'changes': {'priority': 1},
            }),
          ],
        );
        expect(find.text(es.commandNothingToChange), findsOneWidget);
        expect(es.commandNothingToChange, 'Ya está así.');
        expect(_asWritten(), findsNothing);
        expect(find.text(es.captureSaveAsWritten), findsNothing);
        expect(_filledInResult(), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-901: completed matches say «Completada»: under «Se eliminará: …» on '
      'a deletion card and under the title on a change card',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [
            Task(
              id: 1,
              title: 'Dentista',
              priority: 1,
              dueDate: day(-2),
              hasTime: false,
              isCompleted: true,
            ),
            Task(id: 2, title: 'Ir al médico', priority: 1, isCompleted: true),
          ],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'delete',
              'target': {
                'words': ['dentista'],
              },
            }),
            command({
              'kind': 'update',
              'target': {
                'words': ['médico'],
              },
              'changes': {'priority': 3},
            }),
          ],
        );
        final completed = find.text(es.commandCompleted);
        expect(completed, findsNWidgets(2));
        expect(es.commandCompleted, 'Completada');
        final deletion = find.byType(DeleteCommandCard);
        final deleteLine = find.descendant(
          of: deletion,
          matching: find.textContaining('Dentista'),
        );
        final deleteNote = find.descendant(of: deletion, matching: completed);
        expect(deleteNote, findsOneWidget);
        expect(
          tester.getRect(deleteNote).top,
          greaterThanOrEqualTo(tester.getRect(deleteLine.first).bottom - 1),
        );
        final change = find.byType(UpdateCommandCard);
        final title = find.descendant(
          of: change,
          matching: find.text('Ir al médico'),
        );
        final changeNote = find.descendant(of: change, matching: completed);
        expect(changeNote, findsOneWidget);
        expect(
          tester.getRect(changeNote).top,
          greaterThanOrEqualTo(tester.getRect(title).bottom - 1),
        );
        // Right under the first line: above the before → after line.
        final priority = find.descendant(
          of: change,
          matching: find.textContaining('→'),
        );
        expect(priority, findsWidgets);
        expect(
          tester.getRect(changeNote).top,
          lessThan(tester.getRect(priority.first).top),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-901: in a pick list, a completed match’s second line ends with '
      '« · Completada»; an open match’s doesn’t',
      (tester) async {
        // The matcher lists completed tasks only when no open one matches,
        // so a list holds completed matches, or open ones.
        final app = await _App.open(
          tester,
          tasks: [
            Task(
              id: 7,
              title: 'Llamar a Ana',
              priority: 1,
              dueDate: day(-2, 9),
              isCompleted: true,
            ),
            Task(
              id: 8,
              title: 'Llamar a Ana por el viaje',
              priority: 1,
              dueDate: day(-4, 9),
              isCompleted: true,
            ),
            Task(id: 9, title: 'Pagar el gas', priority: 1, dueDate: day(2, 9)),
            Task(
              id: 10,
              title: 'Pagar el gas del piso',
              priority: 1,
              dueDate: day(4, 9),
            ),
          ],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'delete',
              'target': {
                'words': ['llamar', 'ana'],
              },
            }),
          ],
        );
        expect(find.text(es.commandWhichToDelete), findsOneWidget);
        final suffix = ' · ${es.commandCompleted}';
        Finder ending() => find.byWidgetPredicate(
          (widget) =>
              widget is Text && (widget.data?.endsWith(suffix) ?? false),
        );
        expect(ending(), findsNWidgets(2));
        expect(find.text('${weekday(day(-2))} · 09:00$suffix'), findsOneWidget);
        expect(find.text('${weekday(day(-4))} · 09:00$suffix'), findsOneWidget);
        // Only a deletion, nothing to add: Cancelar just closes (UX-917).
        await tester.tap(
          find.descendant(
            of: find.byType(CaptureResult),
            matching: find.widgetWithText(TextButton, es.cancel),
          ),
        );
        await tester.pumpAndSettle();

        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'delete',
              'target': {
                'words': ['pagar', 'gas'],
              },
            }),
          ],
        );
        expect(find.text(es.commandWhichToDelete), findsOneWidget);
        expect(ending(), findsNothing, reason: 'open matches aren’t marked');
        expect(find.text('${weekday(day(2))} · 09:00'), findsOneWidget);
        expect(app.tasks.byId(7), isNotNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-901: a free account with 3 dictations left: «Guardar como tarea» makes '
      'no request to ai/drafts/ and «Te quedan 3 dictados gratis este mes» '
      'stays as it was',
      (tester) async {
        final app = await _App.open(tester, pro: false, freeLeft: 3);
        app.api.answer = oilChange();
        await app.speak(tester, 'Cambia el aceite del coche el sábado');
        expect(app.api.drafts, hasLength(1));
        expect(es.freeVoiceLeft(3), 'Te quedan 3 dictados gratis este mes');
        expect(find.text(es.freeVoiceLeft(3)), findsOneWidget);
        expect(_asWritten(), findsOneWidget);
        await tester.tap(_asWritten());
        // Before the sheet closes, it still says 3.
        await tester.pump();
        if (find.byType(CaptureResult).evaluate().isNotEmpty) {
          expect(find.text(es.freeVoiceLeft(3)), findsOneWidget);
          expect(find.text(es.freeVoiceLeft(2)), findsNothing);
        }
        await tester.pumpAndSettle();
        expect(app.api.drafts, hasLength(1), reason: 'no second dictation');
        expect(app.tasks.named('Cambia el aceite del coche'), isNotNull);
        expect(app.container.read(freeVoiceLeftProvider), 3);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('UX-903: a command card’s ✕ and its message say what it keeps', () {
    Future<_App> openAll(WidgetTester tester) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(id: 1, title: 'Dentista', priority: 1, dueDate: day(5, 9)),
          Task(id: 2, title: 'Ir al médico', priority: 1, dueDate: day(3, 10)),
        ],
      );
      await app.showResult(
        tester,
        drafts: [draft('Comprar pan', date: day(1))],
        commands: [
          command({'kind': 'project', 'name': 'Física'}),
          command({
            'kind': 'update',
            'target': {
              'words': ['médico'],
            },
            'changes': {'title': 'Ir al médico de cabecera'},
          }),
          command({
            'kind': 'delete',
            'target': {
              'words': ['dentista'],
            },
          }),
        ],
      );
      return app;
    }

    Future<void> remove(WidgetTester tester, String tooltip) async {
      // The message before has gone, so this one shows at once.
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      final button = find.byTooltip(tooltip);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
    }

    testWidgets(
      'UX-903: semantics: the deletion’s ✕ reads «No eliminar Dentista», the '
      'change’s «No cambiar Ir al médico», the new project’s «No crear '
      'Física», and a task card’s still «Quitar Comprar pan»',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await openAll(tester);
        for (final label in [
          es.commandDontDelete('Dentista'),
          es.commandDontChange('Ir al médico'),
          es.commandDontCreate('Física'),
          es.removeCaptureItem('Comprar pan'),
        ]) {
          expect(find.byTooltip(label), findsOneWidget, reason: label);
          // TalkBack reads the tooltip as the button's name.
          expect(
            find.semantics.byPredicate(
              (node) =>
                  (node.tooltip == label || node.label == label) &&
                  node.getSemanticsData().flagsCollection.isButton,
            ),
            findsOne,
            reason: label,
          );
        }
        expect(es.commandDontDelete('Dentista'), 'No eliminar Dentista');
        expect(es.commandDontChange('Ir al médico'), 'No cambiar Ir al médico');
        expect(es.commandDontCreate('Física'), 'No crear Física');
        expect(es.removeCaptureItem('Comprar pan'), 'Quitar Comprar pan');
        expect(find.byTooltip(es.removeCaptureItem('Dentista')), findsNothing);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    testWidgets(
      'UX-903: after ✕ on the deletion «No se eliminará» shows with Deshacer; '
      '✕ on the change says «No se cambiará», on the project «No se creará»; '
      'once confirmed, «Dentista» still exists and nothing else changed',
      (tester) async {
        final app = await openAll(tester);
        await remove(tester, es.commandDontDelete('Dentista'));
        expect(find.text(es.commandWontDelete), findsOneWidget);
        expect(es.commandWontDelete, 'No se eliminará');
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(es.undo),
          ),
          findsOneWidget,
        );
        expect(find.text(es.reviewRemoved), findsNothing);
        await tester.pumpAndSettle();

        await remove(tester, es.commandDontChange('Ir al médico'));
        expect(find.text(es.commandWontChange), findsOneWidget);
        expect(es.commandWontChange, 'No se cambiará');
        await tester.pumpAndSettle();

        await remove(tester, es.commandDontCreate('Física'));
        expect(find.text(es.commandWontCreate), findsOneWidget);
        expect(es.commandWontCreate, 'No se creará');
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.tasks.byId(1), isNotNull, reason: 'Dentista survives');
        expect(app.tasks.byId(2)!.title, 'Ir al médico');
        expect(app.lists.created, isEmpty);
        expect(app.tasks.named('Comprar pan'), isNotNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('UX-903: a task card’s ✕ still says «Quitada»', (tester) async {
      await openAll(tester);
      await remove(tester, es.removeCaptureItem('Comprar pan'));
      expect(find.text(es.reviewRemoved), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'UX-903: with every card removed the result says «No queda nada por '
      'revisar» and «No se hará ningún cambio.», the button reads «Terminar», '
      'and the deletion never happens',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [
            Task(id: 1, title: 'Dentista', priority: 1, dueDate: day(5, 9)),
          ],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'delete',
              'target': {
                'words': ['dentista'],
              },
            }),
          ],
        );
        await remove(tester, es.commandDontDelete('Dentista'));
        expect(find.text(es.commandWontDelete), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text(es.captureNothingToReview), findsOneWidget);
        expect(es.captureNothingToReview, 'No queda nada por revisar');
        expect(find.text(es.captureRemovedDraftsHelp), findsOneWidget);
        expect(es.captureRemovedDraftsHelp, 'No se hará ningún cambio.');
        expect(_buttonLabel(tester), es.captureFinish);
        expect(es.captureFinish, 'Terminar');
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(find.byType(CaptureResult), findsNothing);
        expect(app.tasks.byId(1), isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('UX-903: Cancelar names the words it would keep', () {
    Finder question(String text) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(text),
    );
    void expectButtons() {
      for (final label in [es.discard, es.keep]) {
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: label,
        );
      }
      expect(es.discard, 'Descartar');
      expect(es.keep, 'Conservar');
    }

    Finder cancelInResult() => find.descendant(
      of: find.byType(CaptureResult),
      matching: find.widgetWithText(TextButton, es.cancel),
    );

    // A task to add beside the deletion: with none, Cancelar just closes
    // (UX-917, D1).
    testWidgets('UX-903: Cancelar on a spoken result holding a task and a '
        'deletion asks «¿Conservar lo que has dicho para más tarde?» with '
        'Descartar and Conservar', (tester) async {
      final app = await _App.open(
        tester,
        tasks: [Task(id: 1, title: 'Dentista', priority: 1)],
      );
      await app.showResult(
        tester,
        drafts: [draft('Comprar pan', date: day(1))],
        commands: [
          command({
            'kind': 'delete',
            'target': {
              'words': ['dentista'],
            },
          }),
        ],
      );
      await tester.tap(cancelInResult());
      await tester.pumpAndSettle();
      expect(question(es.captureKeepQuestion), findsOneWidget);
      expect(
        es.captureKeepQuestion,
        '¿Conservar lo que has dicho para más tarde?',
      );
      expect(question(es.captureKeepTextQuestion), findsNothing);
      expectButtons();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'UX-903: Cancelar on a typed result with a task and a deletion asks '
      '«¿Conservar el texto para más tarde?»',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [Task(id: 1, title: 'Dentista', priority: 1)],
        );
        app.api.answer = {
          'transcript': 'Comprar pan mañana y borra el dentista',
          'tasks': [serverTask('Comprar pan', date: day(1))],
          'commands': [
            {
              'kind': 'delete',
              'target': {
                'words': ['dentista'],
              },
              'issues': [],
            },
          ],
        };
        await app.type(tester, 'Comprar pan mañana y borra el dentista');
        expect(find.byType(DeleteCommandCard), findsOneWidget);
        await tester.tap(cancelInResult());
        await tester.pumpAndSettle();
        expect(question(es.captureKeepTextQuestion), findsOneWidget);
        expect(
          es.captureKeepTextQuestion,
          '¿Conservar el texto para más tarde?',
        );
        expect(question(es.captureKeepQuestion), findsNothing);
        expectButtons();
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('UX-905: the confirming button names the outcome', () {
    List<Task> tasks() => [
      Task(id: 1, title: 'Ir al médico', priority: 1, dueDate: day(3, 10)),
      Task(id: 2, title: 'Dentista', priority: 1, dueDate: day(5, 9)),
      Task(id: 3, title: 'Informe', priority: 1),
    ];
    CaptureCommand move() => command({
      'kind': 'update',
      'target': {
        'words': ['médico'],
      },
      'changes': {'date': key(day(7))},
    });
    CaptureCommand rename() => command({
      'kind': 'update',
      'target': {
        'words': ['informe'],
      },
      'changes': {'title': 'Informe final'},
    });
    CaptureCommand removal() => command({
      'kind': 'delete',
      'target': {
        'words': ['dentista'],
      },
    });
    CaptureCommand project() => command({'kind': 'project', 'name': 'Física'});

    final cases =
        <
          (
            String,
            List<CaptureDraft> Function(),
            List<CaptureCommand> Function(),
            String,
          )
        >[
          (
            'one change of day only reads «Cambiar fecha»',
            () => [],
            () => [move()],
            es.reschedule,
          ),
          (
            'one change of title reads «Guardar cambios»',
            () => [],
            () => [rename()],
            es.saveChangesSentence,
          ),
          (
            'two changes read «Guardar cambios»',
            () => [],
            () => [move(), rename()],
            es.saveChangesSentence,
          ),
          (
            'a task and a change read «Añadir y cambiar»',
            () => [draft('Comprar pan', date: day(1))],
            () => [move()],
            es.commandAddAndChange,
          ),
          (
            'a task and a deletion read «Añadir y eliminar»',
            () => [draft('Comprar pan', date: day(1))],
            () => [removal()],
            es.commandAddAndDelete,
          ),
          (
            'a change and a deletion read «Cambiar y eliminar»',
            () => [],
            () => [rename(), removal()],
            es.commandChangeAndDelete,
          ),
          (
            'a task, a change and a deletion read «Añadir, cambiar y eliminar»',
            () => [draft('Comprar pan', date: day(1))],
            () => [move(), removal()],
            es.commandAddChangeAndDelete,
          ),
          (
            'a new project alone reads «Crear proyecto»',
            () => [],
            () => [project()],
            es.commandCreateProjects(1),
          ),
          (
            'a dated task into a new project reads «Añadir al calendario», '
                'as today',
            () => [
              draft('Estudiar el tema 2', date: day(4), newProject: 'Física'),
            ],
            () => [project()],
            es.captureAddToCalendar,
          ),
          (
            'an undated task into a new project reads «Añadir tarea», as today',
            () => [draft('Estudiar el tema 2', newProject: 'Física')],
            () => [project()],
            es.captureAddTask,
          ),
        ];

    for (final (name, drafts, commands, label) in cases) {
      testWidgets('UX-905: $name', (tester) async {
        final app = await _App.open(tester, tasks: tasks());
        await app.showResult(tester, drafts: drafts(), commands: commands());
        expect(_buttonLabel(tester), label);
        expect(saveButton(tester).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      });
    }

    test('UX-905: the Spanish labels read as the plan says', () {
      expect(es.reschedule, 'Cambiar fecha');
      expect(es.saveChangesSentence, 'Guardar cambios');
      expect(es.commandAddAndChange, 'Añadir y cambiar');
      expect(es.commandAddAndDelete, 'Añadir y eliminar');
      expect(es.commandChangeAndDelete, 'Cambiar y eliminar');
      expect(es.commandAddChangeAndDelete, 'Añadir, cambiar y eliminar');
      expect(es.commandCreateProjects(1), 'Crear proyecto');
      expect(es.delete, 'Eliminar');
    });

    for (final withProject in [false, true]) {
      testWidgets(
        'UX-905: a deletion alone${withProject ? ', even with a new project,' : ''} '
        'reads «Eliminar» on the error colour with the delete icon',
        (tester) async {
          final app = await _App.open(tester, tasks: tasks());
          await app.showResult(
            tester,
            commands: [if (withProject) project(), removal()],
          );
          expect(_buttonLabel(tester), es.delete);
          final colors = Theme.of(
            tester.element(find.byKey(const ValueKey('save-drafts'))),
          ).colorScheme;
          expect(
            saveButton(tester).style?.backgroundColor?.resolve(<WidgetState>{}),
            colors.error,
          );
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('save-drafts')),
              matching: find.byIcon(Icons.delete_outline_rounded),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group(
    'UX-902: a task with only a deadline shows and lands on its due day',
    () {
      testWidgets(
        'UX-902: a new project with a deadline-only task in it: the collapsed '
        'card says «Vence …» with the flag and no «Sin fecha»; opened, it says '
        '«Sin fecha» with the deadline row under it',
        (tester) async {
          final due = day(5);
          final app = await _App.open(tester);
          await app.showResult(
            tester,
            drafts: [
              _dueDraft(
                'Terminar la presentación',
                due,
                newProject: 'Matemáticas',
              ),
            ],
            commands: [
              command({'kind': 'project', 'name': 'Matemáticas'}),
            ],
          );
          final label = es.deadlineLabel(weekday(due));
          expect(label, startsWith('Vence '));
          final editor = find.byType(CaptureReviewEditor);
          final line = find.descendant(of: editor, matching: find.text(label));
          expect(line, findsOneWidget);
          expect(
            find.descendant(of: editor, matching: find.text(es.noDate)),
            findsNothing,
          );
          final tile = find
              .ancestor(of: line, matching: find.byType(ListTile))
              .first;
          expect(
            find.descendant(
              of: tile,
              matching: find.byIcon(Icons.flag_outlined),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: tile,
              matching: find.byIcon(Icons.calendar_today_outlined),
            ),
            findsNothing,
          );
          // Opened: Sin fecha first, the deadline under it.
          await tester.tap(
            find.descendant(
              of: editor,
              matching: find.text('Terminar la presentación'),
            ),
          );
          await tester.pumpAndSettle();
          final noDate = find.descendant(
            of: editor,
            matching: find.text(es.noDate),
          );
          expect(noDate, findsOneWidget);
          final deadline = find.descendant(
            of: editor,
            matching: find.text(label),
          );
          expect(deadline, findsOneWidget);
          expect(
            tester.getRect(deadline).top,
            greaterThan(tester.getRect(noDate).top),
          );
          expect(app.lists.created, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'UX-902: a found row and a pick-list row for a deadline-only task say '
        '«Vence …», not the bare date',
        (tester) async {
          final due = day(5);
          final app = await _App.open(
            tester,
            tasks: [
              Task(
                id: 1,
                title: 'Entregar el informe',
                priority: 1,
                deadline: due,
              ),
              Task(
                id: 2,
                title: 'Revisar el informe',
                priority: 1,
                dueDate: day(2, 9),
              ),
            ],
          );
          final label = es.deadlineLabel(weekday(due));
          await app.showResult(
            tester,
            commands: [
              command({
                'kind': 'find',
                'words': ['entregar'],
              }),
            ],
          );
          expect(
            find.descendant(
              of: find.byType(FindCommandCard),
              matching: find.text(label),
            ),
            findsOneWidget,
          );
          expect(find.text(weekday(due)), findsNothing);
          await tester.tap(_close());
          await tester.pumpAndSettle();

          await app.showResult(
            tester,
            commands: [
              command({
                'kind': 'update',
                'target': {
                  'words': ['informe'],
                },
                'changes': {'priority': 3},
              }),
            ],
          );
          expect(find.text(es.commandWhichToChange), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(UpdateCommandCard),
              matching: find.text(label),
            ),
            findsOneWidget,
          );
          expect(find.text(weekday(due)), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'UX-902: a plain dictation of one deadline-only task: after «Añadir '
        'tarea», Calendar selects the due day, lights the row, not the Sin '
        'fecha row, and says «Añadida · vence el …» with Deshacer',
        (tester) async {
          final due = day(3);
          final app = await _App.open(
            tester,
            tasks: [Task(id: 1, title: 'Llamar al banco', priority: 1)],
          );
          app.api.answer = {
            'transcript': 'Entregar el informe antes del jueves',
            'tasks': [
              {...serverTask('Entregar el informe'), 'deadline_date': key(due)},
            ],
            'commands': [],
          };
          await app.speak(tester, 'Entregar el informe antes del jueves');
          expect(_buttonLabel(tester), es.captureAddTask);
          await tester.tap(find.byKey(const ValueKey('save-drafts')));
          await tester.pumpAndSettle();
          expect(app.tasks.named('Entregar el informe')!.deadline, due);
          expect(
            find.text(DateFormat.MMMMEEEEd('es').format(due)),
            findsOneWidget,
          );
          final row = _row('Entregar el informe');
          expect(row.hitTestable(), findsOneWidget);
          expect(tester.widget<TaskTile>(row).color, _lit(tester));
          final inbox = find.byKey(const ValueKey('calendar-inbox'));
          expect(inbox, findsOneWidget);
          final box = tester.widget<DecoratedBox>(
            find.ancestor(of: inbox, matching: find.byType(DecoratedBox)).first,
          );
          expect(
            (box.decoration as BoxDecoration).color,
            isNot(_lit(tester)),
            reason: 'the Sin fecha row is not lit',
          );
          final message = es.taskAddedDue(weekday(due));
          expect(message, startsWith('Añadida · vence el '));
          expect(find.text(message), findsOneWidget);
          expect(find.text(es.taskSavedInbox), findsNothing);
          expect(find.text(es.undo), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'UX-902: two tasks, one tomorrow and one due in 3 days: Calendar lands '
        'on tomorrow with that row lit and names the other day',
        (tester) async {
          final due = day(3);
          final app = await _App.open(tester);
          app.api.answer = {
            'transcript': 'Comprar pan mañana y entregar el informe',
            'tasks': [
              serverTask('Comprar pan', date: day(1)),
              {...serverTask('Entregar el informe'), 'deadline_date': key(due)},
            ],
            'commands': [],
          };
          await app.speak(tester, 'Comprar pan mañana y entregar el informe');
          await tester.tap(find.byKey(const ValueKey('save-drafts')));
          await tester.pumpAndSettle();
          expect(app.tasks.named('Entregar el informe'), isNotNull);
          final row = _row('Comprar pan');
          expect(row.hitTestable(), findsOneWidget);
          expect(tester.widget<TaskTile>(row).color, _lit(tester));
          expect(_row('Entregar el informe'), findsNothing);
          expect(
            find.text(
              '${es.captureTasksAdded(2)} · ${es.captureAlsoOn(weekday(due))}',
            ),
            findsOneWidget,
          );
          expect(find.text(es.undo), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    },
  );

  group('UX-906: a project made by voice opens its page', () {
    Finder page(String id) => find.byWidgetPredicate(
      (widget) => widget is HomeScreen && widget.listId == id,
    );
    Finder appBarTitle(String id, String name) => find.descendant(
      of: find.descendant(of: page(id), matching: find.byType(AppBar)),
      matching: find.text(name),
    );

    testWidgets(
      'UX-906: «Nuevo proyecto: Física» alone: «Crear proyecto» opens the '
      'Física page with «Proyecto creado» and Deshacer; Deshacer takes the '
      'project back, closes its page and shows the result again',
      (tester) async {
        final app = await _App.open(tester);
        await app.showResult(
          tester,
          commands: [
            command({'kind': 'project', 'name': 'Física'}),
          ],
        );
        expect(_buttonLabel(tester), es.commandCreateProjects(1));
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.lists.created, ['Física']);
        final id = app.lists.projects.single.id;
        expect(page(id), findsOneWidget);
        expect(appBarTitle(id, 'Física'), findsOneWidget);
        expect(appBarTitle(id, 'Física').hitTestable(), findsOneWidget);
        expect(find.text(es.commandProjectsCreated(1)), findsOneWidget);
        expect(es.commandProjectsCreated(1), 'Proyecto creado');
        await tester.tap(find.text(es.undo));
        await tester.pumpAndSettle();
        expect(app.lists.takenBack, [id]);
        expect(app.lists.projects, isEmpty);
        expect(page(id), findsNothing);
        expect(find.byType(CaptureResult), findsOneWidget);
        expect(find.text(es.commandNewProject('Física')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-906: «Nuevo proyecto: Física» with «Estudiar el tema 2» in it: the '
      'Física page shows the task lit',
      (tester) async {
        final app = await _App.open(tester);
        await app.showResult(
          tester,
          drafts: [
            draft('Estudiar el tema 2', date: day(4), newProject: 'Física'),
          ],
          commands: [
            command({'kind': 'project', 'name': 'Física'}),
          ],
        );
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        final id = app.lists.projects.single.id;
        expect(page(id), findsOneWidget);
        final row = find.descendant(
          of: page(id),
          matching: _row('Estudiar el tema 2'),
        );
        expect(row.hitTestable(), findsOneWidget);
        expect(tester.widget<TaskTile>(row).color, _lit(tester));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1212: «Nuevo proyecto: Física» with «Estudiar el tema 2»: the lit '
      'row’s task screen opened from the Física page, then Deshacer: neither '
      'the task screen nor the page remains, and the result shows again with '
      'the draft, no Física and no task',
      (tester) async {
        final app = await _App.open(tester);
        await app.showResult(
          tester,
          drafts: [
            draft('Estudiar el tema 2', date: day(4), newProject: 'Física'),
          ],
          commands: [
            command({'kind': 'project', 'name': 'Física'}),
          ],
        );
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        final id = app.lists.projects.single.id;
        expect(page(id), findsOneWidget);
        final row = find.descendant(
          of: page(id),
          matching: _row('Estudiar el tema 2'),
        );
        expect(row.hitTestable(), findsOneWidget);
        expect(tester.widget<TaskTile>(row).color, _lit(tester));
        // The task's screen opens over the Física page while the message
        // still shows.
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.byType(TaskDetailScreen).hitTestable(), findsOneWidget);
        expect(find.text(es.undo), findsOneWidget);
        await tester.tap(find.text(es.undo));
        await tester.pumpAndSettle();
        expect(find.byType(TaskDetailScreen), findsNothing);
        expect(page(id), findsNothing);
        expect(find.byType(CaptureResult).hitTestable(), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(CaptureResult),
            matching: find.text('Estudiar el tema 2'),
          ),
          findsWidgets,
        );
        expect(
          app.store.current!.drafts.single.task.title,
          'Estudiar el tema 2',
        );
        expect(app.store.current!.drafts.single.newProject, 'Física');
        expect(app.lists.takenBack, [id]);
        expect(app.lists.projects, isEmpty);
        expect(app.tasks.named('Estudiar el tema 2'), isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-902 + UX-906: the plan’s example (project «Matemáticas», '
      '«Terminar la presentación» due in 5 days, in it) opens the Matemáticas '
      'page with the row lit and «Proyecto creado · Añadida · vence el …»',
      (tester) async {
        final due = day(5);
        final app = await _App.open(tester);
        await app.showResult(
          tester,
          drafts: [
            _dueDraft(
              'Terminar la presentación',
              due,
              newProject: 'Matemáticas',
            ),
          ],
          commands: [
            command({'kind': 'project', 'name': 'Matemáticas'}),
          ],
        );
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        final id = app.lists.projects.single.id;
        expect(page(id), findsOneWidget);
        expect(appBarTitle(id, 'Matemáticas'), findsOneWidget);
        final row = find.descendant(
          of: page(id),
          matching: _row('Terminar la presentación'),
        );
        expect(row.hitTestable(), findsOneWidget);
        expect(tester.widget<TaskTile>(row).color, _lit(tester));
        expect(
          find.text(
            '${es.commandProjectsCreated(1)} · '
            '${es.taskAddedDue(weekday(due))}',
          ),
          findsOneWidget,
        );
        expect(find.text(es.undo), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-906: a result that creates a project and also changes a task lands '
      'on Calendar on the changed task’s day, as today',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [
            Task(
              id: 1,
              title: 'Ir al médico',
              priority: 1,
              dueDate: day(3, 10),
            ),
          ],
        );
        await app.showResult(
          tester,
          commands: [
            command({'kind': 'project', 'name': 'Física'}),
            command({
              'kind': 'update',
              'target': {
                'words': ['médico'],
              },
              'changes': {'date': key(day(7))},
            }),
          ],
        );
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.lists.created, ['Física']);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is HomeScreen && widget.listId != null,
          ),
          findsNothing,
        );
        expect(
          find.text(DateFormat.MMMMEEEEd('es').format(day(7))),
          findsOneWidget,
        );
        final row = _row('Ir al médico');
        expect(row.hitTestable(), findsOneWidget);
        expect(tester.widget<TaskTile>(row).color, _lit(tester));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('UX-1001: a capture for someone else lands in view on Calendar', () {
    final familia = TaskListInfo(
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

    testWidgets(
      'UX-1001: Pro, a result assigned to Ana saved from Calendar under «Para '
      'mí»: «Todas» is selected and the row is lit',
      (tester) async {
        final app = await _App.open(tester, projects: [familia]);
        ChoiceChip chip(String label) =>
            tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));
        expect(chip(es.forMe).selected, isTrue);
        await app.showResult(
          tester,
          drafts: [
            CaptureDraft.fromAI(
              TaskDraft.fromJson({
                ...serverTask(
                  'Llamar al médico',
                  date: day(1),
                  listId: 'familia',
                ),
                'assignment': 'member',
                'assignee_id': 2,
                'assignee_name': 'Ana',
                'transcript': 'Ana tiene que llamar al médico mañana',
              }),
            ),
          ],
        );
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        final saved = app.tasks.named('Llamar al médico')!;
        expect(saved.assignment, 'member');
        expect(saved.assigneeId, 2);
        expect(chip(es.forTeam).selected, isTrue);
        expect(chip(es.forMe).selected, isFalse);
        expect(app.container.read(projectScopeProvider).team, isTrue);
        final row = _row('Llamar al médico');
        expect(row.hitTestable(), findsOneWidget);
        expect(tester.widget<TaskTile>(row).color, _lit(tester));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1213: Pro, a result with one draft for Ana saved from Calendar '
      'under «Para mí», then Deshacer: «Para mí» is selected again and the '
      'result shows again',
      (tester) async {
        final app = await _App.open(tester, projects: [familia]);
        ChoiceChip chip(String label) => tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, label).hitTestable(),
        );
        expect(chip(es.forMe).selected, isTrue);
        await app.showResult(
          tester,
          drafts: [
            CaptureDraft.fromAI(
              TaskDraft.fromJson({
                ...serverTask(
                  'Llamar al médico',
                  date: day(1),
                  listId: 'familia',
                ),
                'assignment': 'member',
                'assignee_id': 2,
                'assignee_name': 'Ana',
                'transcript': 'Ana tiene que llamar al médico mañana',
              }),
            ),
          ],
        );
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.tasks.named('Llamar al médico'), isNotNull);
        expect(chip(es.forTeam).selected, isTrue);
        await tester.tap(find.text(es.undo));
        await tester.pumpAndSettle();
        expect(app.tasks.named('Llamar al médico'), isNull);
        // The result is back, as it was.
        expect(find.byType(CaptureResult).hitTestable(), findsOneWidget);
        expect(app.store.current!.drafts.single.task.title, 'Llamar al médico');
        // Under the sheet, Calendar's own view is back.
        expect(app.container.read(projectScopeProvider).team, isFalse);
        final pair = find.descendant(
          of: find.byType(CalendarScreen),
          matching: find.byType(ChoiceChip),
        );
        ChoiceChip under(String label) => tester.widget<ChoiceChip>(
          find.ancestor(of: find.text(label), matching: pair).first,
        );
        expect(under(es.forMe).selected, isTrue);
        expect(under(es.forTeam).selected, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // Manrope from here on: the tests above measure with the test font.
  group('UX-905 at 2× text with Manrope', () {
    setUpAll(() async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });

    testWidgets(
      'UX-905: CA at 2× on 320×640: «Afegeix, canvia i suprimeix» takes at '
      'most 2 lines inside the button, and nothing overflows',
      (tester) async {
        expect(ca.commandAddChangeAndDelete, 'Afegeix, canvia i suprimeix');
        final app = await _App.open(
          tester,
          language: 'ca',
          size: const Size(320, 640),
          textScale: 2,
          tasks: [
            Task(
              id: 1,
              title: 'Ir al médico',
              priority: 1,
              dueDate: day(3, 10),
            ),
            Task(id: 2, title: 'Dentista', priority: 1, dueDate: day(5, 9)),
          ],
        );
        await app.showResult(
          tester,
          drafts: [draft('Comprar pan', date: day(1))],
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['médico'],
              },
              'changes': {'date': key(day(7))},
            }),
            command({
              'kind': 'delete',
              'target': {
                'words': ['dentista'],
              },
            }),
          ],
        );
        expect(tester.takeException(), isNull);
        final button = find.byKey(const ValueKey('save-drafts'));
        expect(button.hitTestable(), findsOneWidget);
        final text = find.descendant(
          of: button,
          matching: find.text(ca.commandAddChangeAndDelete),
        );
        expect(text, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: text, matching: find.byType(RichText)),
        );
        final oneLine = TextPainter(
          text: paragraph.text,
          textDirection: TextDirection.ltr,
          textScaler: paragraph.textScaler,
        )..layout();
        final lines = (paragraph.size.height / oneLine.height).round();
        oneLine.dispose();
        expect(lines, lessThanOrEqualTo(2));
        expect(paragraph.didExceedMaxLines, isFalse);
        final inside = tester.getRect(text);
        final outside = tester.getRect(button);
        expect(inside.left, greaterThanOrEqualTo(outside.left - 0.5));
        expect(inside.right, lessThanOrEqualTo(outside.right + 0.5));
        expect(inside.top, greaterThanOrEqualTo(outside.top - 0.5));
        expect(inside.bottom, lessThanOrEqualTo(outside.bottom + 0.5));
        expect(tester.takeException(), isNull);
      },
    );
  });
}

// ---- Run 2026-10-18-commands, round 2 ----------------------------------
//
// P135 (UX-908, UX-909, UX-915): command-card questions sit in the question
// box, ask the right question and offer few chips. P136 (UX-914): every
// change and deletion can be finished by tapping. P137 (UX-907, UX-913,
// UX-916): search cards say what they searched, found rows open, copy.

TaskListInfo _project(
  String id,
  String name, {
  String role = 'owner',
  bool shared = false,
  List<ProjectMember> people = const [],
}) => TaskListInfo(
  id: id,
  name: name,
  version: 2,
  role: role,
  shared: shared,
  people: people,
);

/// The question box holding [question].
Finder _boxOf(String question) =>
    find.ancestor(of: find.text(question), matching: find.byType(QuestionBox));

/// The labels of the chips under a question, in the order they read.
List<String> _chipLabels(WidgetTester tester, Finder box) => [
  for (final text in tester.widgetList<Text>(
    find.descendant(
      of: find.descendant(of: box, matching: find.byType(ActionChip)),
      matching: find.byType(Text),
    ),
  ))
    text.data!,
];

/// The question box is the result's tinted box: surfaceContainerHigh, 16 dp
/// corners, 14 dp padding.
void _expectQuestionBox(WidgetTester tester, Finder box) {
  expect(box, findsOneWidget);
  final decoration =
      tester
              .widget<DecoratedBox>(
                find
                    .descendant(of: box, matching: find.byType(DecoratedBox))
                    .first,
              )
              .decoration
          as BoxDecoration;
  expect(
    decoration.color,
    Theme.of(tester.element(box)).colorScheme.surfaceContainerHigh,
  );
  expect(decoration.borderRadius, BorderRadius.circular(16));
  expect(
    tester
        .widget<Padding>(
          find.descendant(of: box, matching: find.byType(Padding)).first,
        )
        .padding,
    const EdgeInsets.all(14),
  );
}

/// The card [text] is on: a command's frame in the result.
Finder _cardOf(Finder text) =>
    find.ancestor(of: text, matching: find.byType(Material)).first;

void _commandsRound2() {
  group('UX-908: a task’s missing project asks where it goes', () {
    final draftQuimica = draft(
      'Repasar el tema 3',
      suggestion: 'química',
      issues: ['project_not_available'],
      hints: {'project': 'química'},
    );

    testWidgets(
      'UX-908: with 10 editable projects, «química» asks «¿En qué proyecto la pongo?» inside the question box, with at most 6 chips: «Crear «Química»», up to 3 similar projects in their order, «Otro proyecto…», «Sin proyecto»',
      (tester) async {
        final projects = [
          _project('organica', 'Química orgánica'),
          _project('casa', 'Casa'),
          _project('fyq', 'Física y Química'),
          _project('bio', 'Bioquímica'),
          _project('q2', 'Química II'),
          _project('trabajo', 'Trabajo'),
          _project('gym', 'Gimnasio'),
          _project('viajes', 'Viajes'),
          _project('lectura', 'Lectura'),
          _project('musica', 'Música'),
        ];
        expect(projects, hasLength(10));
        final app = await _App.open(tester, projects: projects);
        await app.showResult(tester, drafts: [draftQuimica]);
        expect(es.commandWhichProject, '¿En qué proyecto la pongo?');
        expect(es.commandOtherProject, 'Otro proyecto…');
        final box = _boxOf(es.commandWhichProject);
        _expectQuestionBox(tester, box);
        final labels = _chipLabels(tester, box);
        expect(labels.length, lessThanOrEqualTo(6), reason: '$labels');
        expect(labels.first, es.commandCreateNamed('Química'));
        expect(es.commandCreateNamed('Química'), 'Crear «Química»');
        expect(labels.sublist(labels.length - 2), [
          es.commandOtherProject,
          es.noList,
        ]);
        final similar = labels.sublist(1, labels.length - 2);
        const like = [
          'Química orgánica',
          'Física y Química',
          'Bioquímica',
          'Química II',
        ];
        expect(similar, hasLength(3), reason: 'four are like it: three show');
        for (final name in similar) {
          expect(like, contains(name), reason: '$name isn’t like «Química»');
        }
        expect(similar, [
          ...like.where(similar.contains),
        ], reason: 'in their order');
        expect(labels, isNot(contains('Casa')));
        expect(saveButton(tester).onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-908: «Otro proyecto…» opens the project sheet; «Casa» there puts the task in Casa, its chip reads Casa, and the question goes',
      (tester) async {
        final app = await _App.open(
          tester,
          projects: [
            _project('organica', 'Química orgánica'),
            _project('casa', 'Casa'),
            _project('fyq', 'Física y Química'),
          ],
        );
        await app.showResult(tester, drafts: [draftQuimica]);
        expect(find.text('Casa'), findsNothing, reason: 'not like «Química»');
        await tester.tap(find.text(es.commandOtherProject));
        await tester.pumpAndSettle();
        expect(find.text('Casa'), findsOneWidget, reason: 'in the sheet');
        await tester.tap(find.text('Casa'));
        await tester.pumpAndSettle();
        expect(find.text(es.commandWhichProject), findsNothing);
        expect(find.text(es.commandOtherProject), findsNothing);
        expect(
          find.descendant(
            of: find.byType(CaptureResult),
            matching: find.text('Casa'),
          ),
          findsOneWidget,
          reason: 'the task’s project chip',
        );
        expect(saveButton(tester).onPressed, isNotNull);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.lists.created, isEmpty);
        expect(app.tasks.named('Repasar el tema 3')!.listId, 'casa');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-908: with one editable project, already a similar chip, there is no «Otro proyecto…» (a view-only project doesn’t count)',
      (tester) async {
        final app = await _App.open(
          tester,
          projects: [
            _project('fyq', 'Física y Química'),
            _project('ajena', 'Química de Ana', role: 'viewer', shared: true),
          ],
        );
        await app.showResult(tester, drafts: [draftQuimica]);
        final box = _boxOf(es.commandWhichProject);
        expect(_chipLabels(tester, box), [
          es.commandCreateNamed('Química'),
          'Física y Química',
          es.noList,
        ]);
        expect(find.text(es.commandOtherProject), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('UX-909: «Crea el proyecto Química» matched to another name asks', () {
    final fyq = _project('fyq', 'Física y Química');
    final quimica = command({
      'kind': 'project',
      'name': 'Química',
      'existing_list_id': 'fyq',
    });

    Future<_App> open(WidgetTester tester) async {
      final app = await _App.open(
        tester,
        projects: [fyq, _project('casa', 'Casa')],
      );
      await app.showResult(
        tester,
        drafts: [draft('Repasar el tema 3', listId: 'fyq')],
        commands: [quimica],
      );
      return app;
    }

    testWidgets(
      'UX-909: a project «Química» the server matched to «Física y Química» asks «¿Crear el proyecto «Química»?» with «Crear «Química»» and then «Física y Química», and the confirming button waits for a chip',
      (tester) async {
        await open(tester);
        final question = find.text(es.commandCreateProjectQuestion('Química'));
        expect(question, findsOneWidget);
        expect(
          es.commandCreateProjectQuestion('Química'),
          '¿Crear el proyecto «Química»?',
        );
        expect(
          find.text(es.commandExistingProject('Física y Química')),
          findsNothing,
        );
        final labels = _chipLabels(tester, _cardOf(question));
        expect(labels.take(2), [
          es.commandCreateNamed('Química'),
          'Física y Química',
        ]);
        expect(find.byTooltip(es.commandDontCreate('Química')), findsOneWidget);
        expect(saveButton(tester).onPressed, isNull, reason: 'it waits');
        await tester.tap(find.text(es.commandCreateNamed('Química')));
        await tester.pumpAndSettle();
        expect(saveButton(tester).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-909: after «Crear «Química»» and the confirming tap, a project «Química» exists and the dictation’s task is in it',
      (tester) async {
        final app = await open(tester);
        await tester.tap(find.text(es.commandCreateNamed('Química')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.lists.created, ['Química']);
        final created = app.lists.projects.firstWhere(
          (project) => project.name == 'Química',
        );
        expect(app.tasks.named('Repasar el tema 3')!.listId, created.id);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-909: «Física y Química» instead creates nothing, and the task stays in Física y Química',
      (tester) async {
        final app = await open(tester);
        final card = _cardOf(
          find.text(es.commandCreateProjectQuestion('Química')),
        );
        await tester.tap(
          find.descendant(
            of: find.descendant(of: card, matching: find.byType(ActionChip)),
            matching: find.text('Física y Química'),
          ),
        );
        await tester.pumpAndSettle();
        expect(saveButton(tester).onPressed, isNotNull);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.lists.created, isEmpty);
        expect(app.tasks.named('Repasar el tema 3')!.listId, 'fyq');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-909: «matematicas» matched to «Matemáticas» (the same name, ignoring case and accents) still shows «Ya tienes «Matemáticas»» and doesn’t wait',
      (tester) async {
        final app = await _App.open(tester, projects: [maths]);
        await app.showResult(
          tester,
          drafts: [draft('Repasar fracciones', listId: 'maths')],
          commands: [
            command({
              'kind': 'project',
              'name': 'matematicas',
              'existing_list_id': 'maths',
            }),
          ],
        );
        expect(
          find.text(es.commandExistingProject('Matemáticas')),
          findsOneWidget,
        );
        expect(
          find.text(es.commandCreateProjectQuestion('matematicas')),
          findsNothing,
        );
        expect(
          find.textContaining(
            es.commandCreateProjectQuestion('').split('«').first,
          ),
          findsNothing,
        );
        expect(saveButton(tester).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('UX-915: the change card’s day question', () {
    Future<_App> open(
      WidgetTester tester,
      String time, {
      String language = 'es',
    }) async {
      final app = await _App.open(
        tester,
        language: language,
        tasks: [Task(id: 1, title: 'Ir al médico', priority: 1)],
      );
      await app.showResult(
        tester,
        commands: [
          command({
            'kind': 'update',
            'target': {
              'words': ['médico'],
            },
            'changes': {'time': time},
          }),
        ],
      );
      return app;
    }

    testWidgets(
      'UX-915: «Pon el médico a las 5» on a task with no day asks «¿Qué día, a las 17:00?» inside the question box',
      (tester) async {
        await open(tester, '17:00');
        const question = '¿Qué día, a las 17:00?';
        expect(es.commandWhichDay(17, '17:00'), question);
        _expectQuestionBox(tester, _boxOf(question));
        expect(saveButton(tester).onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-915: at 1:00 it takes the singular article, «¿Qué día, a la 1:00?», with the time as the app writes times',
      (tester) async {
        expect(es.commandWhichDay(1, '1:00'), '¿Qué día, a la 1:00?');
        await open(tester, '01:00');
        // The time as the app shows times: 01:00 on this 24-hour phone.
        final time = appContext().clockTime(DateTime(2000, 1, 1, 1));
        final question = es.commandWhichDay(1, time);
        expect(question, '¿Qué día, a la $time?');
        expect(find.text(question), findsOneWidget);
        _expectQuestionBox(tester, _boxOf(question));
        expect(find.textContaining('a las'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('UX-915: in Catalan it reads «Quin dia, a les 17:00?»', (
      tester,
    ) async {
      await open(tester, '17:00', language: 'ca');
      expect(ca.commandWhichDay(17, '17:00'), 'Quin dia, a les 17:00?');
      expect(ca.commandWhichDay(1, '1:00'), 'Quin dia, a la 1:00?');
      _expectQuestionBox(tester, _boxOf('Quin dia, a les 17:00?'));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'UX-915: after «Elegir día» and a day 4 days ahead, the chip reads that day’s weekdayDate and is selected',
      (tester) async {
        final app = await open(tester, '17:00');
        final picked = day(4);
        final pick = find.byKey(const ValueKey('command-pick-day'));
        expect(
          find.descendant(of: pick, matching: find.text(es.pickDay)),
          findsOneWidget,
        );
        expect(tester.widget<ChoiceChip>(pick).selected, isFalse);
        await tester.tap(pick);
        await tester.pumpAndSettle();
        final calendar = find.byType(CalendarDatePicker);
        expect(calendar, findsOneWidget);
        if (picked.month != day(0).month) {
          await tester.tap(
            find.descendant(
              of: calendar,
              matching: find.byIcon(Icons.chevron_right),
            ),
          );
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.descendant(of: calendar, matching: find.text('${picked.day}')),
        );
        await tester.pumpAndSettle();
        final done = find.byKey(const ValueKey('schedule-done'));
        if (done.evaluate().isNotEmpty) {
          await tester.ensureVisible(done);
          await tester.pumpAndSettle();
          await tester.tap(done);
          await tester.pumpAndSettle();
        }
        expect(
          find.descendant(of: pick, matching: find.text(weekday(picked))),
          findsOneWidget,
        );
        expect(tester.widget<ChoiceChip>(pick).selected, isTrue);
        expect(
          find.text('${es.noDate} → ${weekday(picked)} · 17:00'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.tasks.byId(1)!.dueDate, day(4, 17));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('UX-914: every change and deletion can be finished by tapping', () {
    testWidgets(
      'UX-914: an update whose words match 8 tasks shows 5 and «Ver 3 más»; tapping it shows all 8; the 7th tapped is the one changed, with its before → after',
      (tester) async {
        const names = [
          'Ana',
          'Bea',
          'Carla',
          'Dani',
          'Eva',
          'Fran',
          'Gema',
          'Hugo',
        ];
        final app = await _App.open(
          tester,
          tasks: [
            for (var i = 0; i < names.length; i++)
              Task(
                id: i + 1,
                title: 'Llamar a ${names[i]}',
                priority: 1,
                dueDate: day(i + 2, 9),
              ),
          ],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['llamar'],
              },
              'changes': {'time': '18:00'},
            }),
          ],
        );
        List<String> shown() => [
          for (final name in names)
            if (find.text('Llamar a $name').evaluate().isNotEmpty)
              'Llamar a $name',
        ];
        expect(shown(), hasLength(5));
        expect(es.commandShowMore(3), 'Ver 3 más');
        final more = find.widgetWithText(TextButton, es.commandShowMore(3));
        expect(more, findsOneWidget);
        await tester.ensureVisible(more);
        await tester.pumpAndSettle();
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(shown(), hasLength(8));
        expect(find.text(es.commandShowMore(3)), findsNothing);
        final ordered = shown()
          ..sort(
            (a, b) => tester
                .getTopLeft(find.text(a))
                .dy
                .compareTo(tester.getTopLeft(find.text(b)).dy),
          );
        final seventh = ordered[6];
        final task = app.tasks.named(seventh)!;
        await tester.ensureVisible(find.text(seventh));
        await tester.pumpAndSettle();
        await tester.tap(find.text(seventh));
        await tester.pumpAndSettle();
        expect(find.text(es.commandWhichToChange), findsNothing);
        expect(find.text(seventh), findsOneWidget);
        final due = task.dueDate!;
        expect(
          find.text('${weekday(due)} · 09:00 → ${weekday(due)} · 18:00'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.tasks.byId(task.id!)!.dueDate!.hour, 18);
        for (final other in names.map((name) => 'Llamar a $name')) {
          if (other == seventh) continue;
          expect(app.tasks.named(other)!.dueDate!.hour, 9, reason: other);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-914: an update whose only matching task «Informe» is in a project the account can only view says ««Informe» es de un proyecto que solo puedes ver.», not «No encuentro…», with nothing to apply',
      (tester) async {
        final app = await _App.open(
          tester,
          projects: [
            _project('ajeno', 'Equipo de Ana', role: 'viewer', shared: true),
          ],
          tasks: [Task(id: 1, title: 'Informe', priority: 1, listId: 'ajeno')],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['informe'],
              },
              'changes': {'priority': 3},
            }),
          ],
        );
        expect(
          es.commandViewOnly('Informe'),
          '«Informe» es de un proyecto que solo puedes ver.',
        );
        expect(find.text(es.commandViewOnly('Informe')), findsOneWidget);
        expect(find.text(es.commandTaskNotFound('informe')), findsNothing);
        expect(find.byTooltip(es.commandDontChange('informe')), findsNothing);
        expect(find.byKey(const ValueKey('save-drafts')), findsNothing);
        expect(app.tasks.byId(1)!.priority, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-914: «Asigna el informe a Paul» with two editors called Paul shows «Hay varias personas que se llaman Paul.» and one chip each; «Paul Martí» makes it ready, «→ Paul Martí», and the task is assigned to him',
      (tester) async {
        final team2 = _project(
          'team2',
          'Equipo',
          shared: true,
          people: const [
            ProjectMember(id: 1, name: 'Yo', role: 'owner'),
            ProjectMember(id: 3, name: 'Paul García', role: 'editor'),
            ProjectMember(id: 4, name: 'Paul Martí', role: 'editor'),
            ProjectMember(id: 5, name: 'Paula Ruiz', role: 'viewer'),
            ProjectMember(id: 6, name: 'Pablo', role: 'editor'),
          ],
        );
        final app = await _App.open(
          tester,
          projects: [team2],
          tasks: [
            Task(
              id: 1,
              title: 'Informe',
              priority: 1,
              listId: 'team2',
              assignment: 'group',
            ),
          ],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['informe'],
              },
              'changes': {'assignee_name': 'Paul'},
              'issues': ['ambiguous_member'],
            }),
          ],
        );
        expect(
          es.commandAmbiguousMember('Paul'),
          'Hay varias personas que se llaman Paul.',
        );
        expect(find.text(es.commandAmbiguousMember('Paul')), findsOneWidget);
        final chips = find.descendant(
          of: find.byType(CaptureResult),
          matching: find.byType(ChoiceChip),
        );
        final names = [
          for (final chip in tester.widgetList<ChoiceChip>(chips))
            (chip.label as Text).data,
        ];
        expect(names, ['Paul García', 'Paul Martí']);
        expect(saveButton(tester).onPressed, isNull, reason: 'it waits');
        await tester.tap(find.widgetWithText(ChoiceChip, 'Paul Martí'));
        await tester.pumpAndSettle();
        expect(saveButton(tester).onPressed, isNotNull);
        expect(find.text('${es.assignedToGroup} → Paul Martí'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        final report = app.tasks.byId(1)!;
        expect(report.assignment, 'member');
        expect(report.assigneeId, 4);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-914: a search card with 25 results still shows «Y 5 más» as plain text',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [
            for (var i = 1; i <= 25; i++)
              Task(id: i, title: 'Nota $i', priority: 1),
          ],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'find',
              'words': ['nota'],
            }),
          ],
        );
        expect(es.commandMore(5), 'Y 5 más');
        final more = find.text(es.commandMore(5), skipOffstage: false);
        await tester.scrollUntilVisible(
          more,
          300,
          scrollable: find
              .descendant(
                of: find.byType(CaptureResult),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(more, findsOneWidget);
        for (final tappable in [TextButton, InkWell, ActionChip]) {
          expect(
            find.ancestor(of: more, matching: find.byType(tappable)),
            findsNothing,
            reason: '$tappable',
          );
        }
        expect(
          find.text(es.commandShowMore(5), skipOffstage: false),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('UX-907: a search card says for when and what it searched', () {
    Finder inCard(Finder finder) =>
        find.descendant(of: find.byType(FindCommandCard), matching: finder);

    Future<void> search(
      WidgetTester tester,
      Map<String, dynamic> json, {
      List<Task> tasks = const [],
      List<TaskListInfo> projects = const [],
    }) async {
      final app = await _App.open(tester, tasks: tasks, projects: projects);
      await app.showResult(
        tester,
        commands: [
          command({'kind': 'find', 'words': [], ...json}),
        ],
      );
    }

    /// The card's lines, top to bottom.
    List<String> lines(WidgetTester tester) {
      final texts = inCard(find.byType(Text));
      final found = [
        for (final element in texts.evaluate())
          (
            text: (element.widget as Text).data ?? '',
            top: tester
                .getTopLeft(find.byElementPredicate((e) => e == element))
                .dy,
          ),
      ]..sort((a, b) => a.top.compareTo(b.top));
      return [for (final line in found) line.text];
    }

    testWidgets(
      'UX-907: tomorrow to tomorrow, no words, no project: headed «Tareas» with «Mañana» under it; with status completed, «Mañana · Completadas»',
      (tester) async {
        await search(tester, {'from': key(day(1)), 'to': key(day(1))});
        expect(lines(tester).take(2), [es.tasks, es.tomorrow]);
        expect(es.tomorrow, 'Mañana');
        await tester.pumpWidget(const SizedBox());
        await search(tester, {
          'from': key(day(1)),
          'to': key(day(1)),
          'status': 'completed',
        });
        expect(es.commandFindDone, 'Completadas');
        expect(lines(tester).take(2), [es.tasks, 'Mañana · Completadas']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-907: next Monday to next Sunday with status open reads «Del {lunes} al {domingo} · Pendientes»',
      (tester) async {
        var monday = day(1);
        while (monday.weekday != DateTime.monday) {
          monday = DateTime(monday.year, monday.month, monday.day + 1);
        }
        final sunday = DateTime(monday.year, monday.month, monday.day + 6);
        await search(tester, {
          'from': key(monday),
          'to': key(sunday),
          'status': 'open',
        });
        final expected =
            'Del ${weekday(monday)} al ${weekday(sunday)} · Pendientes';
        expect(
          '${es.commandFindPeriod(weekday(monday), weekday(sunday))} · ${es.commandFindOpen}',
          expected,
        );
        expect(lines(tester).take(2), [es.tasks, expected]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-907: a search with no period and status any has no line under its heading',
      (tester) async {
        await search(
          tester,
          {
            'words': ['pan'],
          },
          tasks: [Task(id: 1, title: 'Comprar pan', priority: 1)],
        );
        expect(lines(tester).take(2), [
          es.commandFindWords('pan'),
          'Comprar pan',
        ]);
        expect(tester.takeException(), isNull);
      },
    );

    final mathsTeam = _project(
      'maths',
      'Matemáticas',
      shared: true,
      people: const [
        ProjectMember(id: 1, name: 'Yo', role: 'owner'),
        ProjectMember(id: 3, name: 'Paul', role: 'editor'),
      ],
    );

    testWidgets(
      'UX-907: a project and a person: «Tareas de «Matemáticas» para Paul»; the account itself: «Tus tareas de «Matemáticas»»; words still come first',
      (tester) async {
        await search(
          tester,
          {'list_id': 'maths', 'person_id': 3},
          projects: [mathsTeam],
        );
        expect(
          es.commandFindProjectPerson('Matemáticas', 'Paul'),
          'Tareas de «Matemáticas» para Paul',
        );
        expect(lines(tester).first, 'Tareas de «Matemáticas» para Paul');

        await tester.pumpWidget(const SizedBox());
        await search(
          tester,
          {'list_id': 'maths', 'person_id': 1},
          projects: [mathsTeam],
        );
        expect(
          es.commandFindProjectMine('Matemáticas'),
          'Tus tareas de «Matemáticas»',
        );
        expect(lines(tester).first, 'Tus tareas de «Matemáticas»');

        await tester.pumpWidget(const SizedBox());
        await search(
          tester,
          {
            'words': ['examen'],
            'list_id': 'maths',
            'person_id': 3,
          },
          projects: [mathsTeam],
        );
        expect(lines(tester).first, es.commandFindWords('examen'));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('UX-913: found rows open the task; they don’t look like ticks', () {
    testWidgets(
      'UX-913: found rows have no circle or tick in front and end with a chevron; a tap opens the task; a completed one is struck through and its details end with «Completada»',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [
            Task(
              id: 3,
              title: 'Hacer la introducción',
              priority: 1,
              isCompleted: true,
            ),
            Task(
              id: 4,
              title: 'Introducción al tema 3',
              priority: 1,
              dueDate: day(5),
              hasTime: false,
            ),
          ],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'find',
              'words': ['introducción'],
            }),
          ],
        );
        for (final title in [
          'Hacer la introducción',
          'Introducción al tema 3',
        ]) {
          final row = find
              .ancestor(of: find.text(title), matching: find.byType(InkWell))
              .first;
          for (final icon in [
            Icons.check_circle_rounded,
            Icons.radio_button_unchecked_rounded,
            Icons.check_circle_outline,
            Icons.circle_outlined,
            Icons.check_box_outlined,
            Icons.check_box_outline_blank,
          ]) {
            expect(
              find.descendant(of: row, matching: find.byIcon(icon)),
              findsNothing,
              reason: '$title: $icon',
            );
          }
          expect(
            find.descendant(of: row, matching: find.byType(Checkbox)),
            findsNothing,
          );
          final chevron = find.descendant(
            of: row,
            matching: find.byIcon(Icons.chevron_right_rounded),
          );
          expect(chevron, findsOneWidget, reason: title);
          expect(tester.widget<Icon>(chevron).size, 20);
          final rowBox = tester.getRect(row);
          final chevronBox = tester.getRect(chevron);
          final titleBox = tester.getRect(find.text(title));
          expect(chevronBox.left, greaterThan(titleBox.left));
          expect(
            rowBox.right - chevronBox.right,
            lessThan(24),
            reason: 'at the end',
          );
        }
        final done = tester.widget<Text>(find.text('Hacer la introducción'));
        expect(done.style?.decoration, TextDecoration.lineThrough);
        final details = find.descendant(
          of: find
              .ancestor(
                of: find.text('Hacer la introducción'),
                matching: find.byType(InkWell),
              )
              .first,
          matching: find.byType(Text),
        );
        expect(
          tester.widgetList<Text>(details).last.data,
          endsWith(es.commandCompleted),
        );
        expect(es.commandCompleted, 'Completada');
        await tester.tap(find.text('Introducción al tema 3'));
        await tester.pumpAndSettle();
        expect(find.byType(TaskDetailScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('UX-916: copy slips', () {
    testWidgets(
      'UX-916: an existing-project card with one task going there reads «La tarea va ahí.»; with two, «Las tareas van ahí.»',
      (tester) async {
        expect(es.commandExistingProjectTasks(1), 'La tarea va ahí.');
        expect(es.commandExistingProjectTasks(2), 'Las tareas van ahí.');
        var app = await _App.open(tester, projects: [maths]);
        await app.showResult(
          tester,
          drafts: [draft('Repasar fracciones', listId: 'maths')],
          commands: [
            command({
              'kind': 'project',
              'name': 'Matemáticas',
              'existing_list_id': 'maths',
            }),
          ],
        );
        expect(find.text('La tarea va ahí.'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        app = await _App.open(tester, projects: [maths]);
        await app.showResult(
          tester,
          drafts: [
            draft('Repasar fracciones', listId: 'maths'),
            draft('Repasar decimales', listId: 'maths'),
          ],
          commands: [
            command({
              'kind': 'project',
              'name': 'Matemáticas',
              'existing_list_id': 'maths',
            }),
          ],
        );
        expect(find.text('Las tareas van ahí.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-916: a change that raises a task’s priority shows the app’s priority flag on its line',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [Task(id: 2, title: 'Presupuesto', priority: 2)],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['presupuesto'],
              },
              'changes': {'priority': 3},
            }),
          ],
        );
        final line = find.text('${es.medium} → ${es.high}');
        expect(line, findsOneWidget);
        final row = find.ancestor(of: line, matching: find.byType(Row)).first;
        expect(
          find.descendant(of: row, matching: find.byIcon(Icons.flag_outlined)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}

// ---- Run 2026-10-18-commands, round 2 (b2) ----------------------------
//
// P148 (UX-909, UX-1219): a task the server filed in the matched project of
// a «¿Crear el proyecto …?» card waits for a chip, as the two-matches card's
// tasks do; «Otro proyecto…» opens the sheet with nothing chosen.

void _commandsRound2b() {
  group('P148 · UX-909: the matched project’s task waits for the question', () {
    final fyq = _project('fyq', 'Física y Química');
    final quimica = command({
      'kind': 'project',
      'name': 'Química',
      'existing_list_id': 'fyq',
    });

    Future<_App> open(
      WidgetTester tester, {
      List<CaptureDraft> more = const [],
    }) async {
      final app = await _App.open(
        tester,
        projects: [fyq, _project('casa', 'Casa')],
      );
      await app.showResult(
        tester,
        drafts: [draft('Repasar el tema 3', listId: 'fyq'), ...more],
        commands: [quimica],
      );
      return app;
    }

    String label(WidgetTester tester) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('save-drafts')),
            matching: find.byType(Text),
          ),
        )
        .data!;

    Finder chipIn(Finder card, String text) => find.descendant(
      of: find.descendant(of: card, matching: find.byType(ActionChip)),
      matching: find.text(text),
    );

    testWidgets(
      'UX-909: with only the task filed in «Física y Química», the confirming button reads «Revisa los detalles» and is off; a tap on it saves nothing; «Crear «Química»» turns it on',
      (tester) async {
        final app = await open(tester);
        expect(
          find.text(es.commandCreateProjectQuestion('Química')),
          findsOneWidget,
        );
        expect(label(tester), es.captureCheckDetails);
        expect(saveButton(tester).onPressed, isNull);
        await tester.tap(
          find.byKey(const ValueKey('save-drafts')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        expect(app.tasks.named('Repasar el tema 3'), isNull, reason: 'held');
        expect(app.lists.created, isEmpty);
        await tester.tap(find.text(es.commandCreateNamed('Química')));
        await tester.pumpAndSettle();
        expect(saveButton(tester).onPressed, isNotNull);
        expect(label(tester), isNot(es.captureCheckDetails));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-909: «Física y Química» on the card turns the button on; the tap creates no project and files «Repasar el tema 3» in Física y Química',
      (tester) async {
        final app = await open(tester);
        expect(saveButton(tester).onPressed, isNull);
        final card = _cardOf(
          find.text(es.commandCreateProjectQuestion('Química')),
        );
        await tester.tap(chipIn(card, 'Física y Química'));
        await tester.pumpAndSettle();
        expect(saveButton(tester).onPressed, isNotNull);
        expect(label(tester), isNot(es.captureCheckDetails));
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.lists.created, isEmpty);
        expect(app.tasks.named('Repasar el tema 3')!.listId, 'fyq');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-909: with «Comprar pan» (no project) too, the button is on and adds one task; the tap saves only «Comprar pan», and the «¿Crear el proyecto «Química»?» card still shows with its chips',
      (tester) async {
        final app = await open(tester, more: [draft('Comprar pan')]);
        expect(saveButton(tester).onPressed, isNotNull);
        // The plan says «Añadir tarea». With two tasks on screen the app
        // names the count, «Añadir 1 tarea»; either says one task is added.
        expect(label(tester), anyOf(es.captureAddTask, es.captureAddTasks(1)));
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.tasks.named('Comprar pan'), isNotNull);
        expect(app.tasks.named('Repasar el tema 3'), isNull);
        expect(app.lists.created, isEmpty);
        final question = find.text(es.commandCreateProjectQuestion('Química'));
        expect(question, findsOneWidget);
        final card = _cardOf(question);
        expect(chipIn(card, es.commandCreateNamed('Química')), findsOneWidget);
        expect(chipIn(card, 'Física y Química'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-909: «matematicas» whose project is «Matemáticas» shows «Ya tienes «Matemáticas»», and the first tap saves its task in Matemáticas',
      (tester) async {
        final app = await _App.open(tester, projects: [maths]);
        await app.showResult(
          tester,
          drafts: [draft('Repasar fracciones', listId: 'maths')],
          commands: [
            command({
              'kind': 'project',
              'name': 'matematicas',
              'existing_list_id': 'maths',
            }),
          ],
        );
        expect(
          find.text(es.commandExistingProject('Matemáticas')),
          findsOneWidget,
        );
        expect(saveButton(tester).onPressed, isNotNull);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.tasks.named('Repasar fracciones')!.listId, 'maths');
        expect(app.lists.created, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('P148 · UX-1219: «Otro proyecto…» opens the sheet with nothing chosen', () {
    testWidgets(
      'UX-1219: a task whose project «química» doesn’t exist: «Otro proyecto…» shows the sheet with no row selected, «Sin proyecto» included; «Sin proyecto» there puts the task in no project and the question goes',
      (tester) async {
        final app = await _App.open(
          tester,
          projects: [
            _project('organica', 'Química orgánica'),
            _project('casa', 'Casa'),
            _project('fyq', 'Física y Química'),
          ],
        );
        await app.showResult(
          tester,
          drafts: [
            draft(
              'Repasar el tema 3',
              suggestion: 'química',
              issues: ['project_not_available'],
              hints: {'project': 'química'},
            ),
          ],
        );
        expect(find.text(es.commandWhichProject), findsOneWidget);
        await tester.tap(find.text(es.commandOtherProject));
        await tester.pumpAndSettle();
        // The project sheet, over the capture sheet.
        final sheets = find.byType(BottomSheet).evaluate().length;
        expect(sheets, 2);
        final sheet = find.byType(BottomSheet).last;
        final none = find.descendant(
          of: sheet,
          matching: find.widgetWithText(ListTile, es.noList),
        );
        expect(none, findsOneWidget);
        expect(tester.widget<ListTile>(none).selected, isFalse);
        final selected = [
          for (final tile in tester.widgetList<ListTile>(
            find.descendant(of: sheet, matching: find.byType(ListTile)),
          ))
            if (tile.selected) (tile.title as Text?)?.data,
        ];
        expect(selected, isEmpty, reason: 'nothing is chosen yet: $selected');
        await tester.tap(none);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget, reason: 'closed');
        expect(find.text(es.commandWhichProject), findsNothing);
        expect(saveButton(tester).onPressed, isNotNull);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.lists.created, isEmpty);
        expect(app.tasks.named('Repasar el tema 3')!.listId, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

// ---- Run 2026-10-18-commands, b3 ---------------------------------------
//
// P139 (UX-1004): the capture result keeps the full date sheet. P141
// (UX-1103, UX-1104, UX-1105, UX-1106): a project the dictation creates
// shows its name first, can be renamed before the confirming tap, says what
// to do about a person not in it yet; the person chip shows ▾. P142
// (UX-1107): «Abrir» keeps the person the search was for.

/// A draft in project [listId] for person [assigneeId], as the server
/// sends it.
CaptureDraft _assignedDraft(
  String title, {
  required String listId,
  required int assigneeId,
  required String assigneeName,
}) => CaptureDraft.fromAI(
  TaskDraft.fromJson({
    ...serverTask(title, listId: listId),
    'assignment': 'member',
    'assignee_id': assigneeId,
    'assignee_name': assigneeName,
    'transcript': 'Lo que dije',
  }),
);

/// The x where the first [count] characters of [paragraph]'s text end, laid
/// out on one line as it draws them.
double _prefixRight(RenderParagraph paragraph, int count) {
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: TextDirection.ltr,
    textScaler: paragraph.textScaler,
  )..layout();
  final boxes = painter.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: count),
  );
  painter.dispose();
  return boxes.map((box) => box.right).reduce((a, b) => a > b ? a : b);
}

/// The width [paragraph]'s text needs on one line, and its ellipsis's.
({double full, double ellipsis}) _oneLine(RenderParagraph paragraph) {
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: TextDirection.ltr,
    textScaler: paragraph.textScaler,
  )..layout();
  final dots = TextPainter(
    text: TextSpan(text: '…', style: paragraph.text.style),
    textDirection: TextDirection.ltr,
    textScaler: paragraph.textScaler,
  )..layout();
  final widths = (full: painter.width, ellipsis: dots.width);
  painter.dispose();
  dots.dispose();
  return widths;
}

void _commandsRound3() {
  final en = lookupAppLocalizations(const Locale('en'));

  group('b3 with Manrope', () {
    setUpAll(() async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });

    // ---- P141 · UX-1104: the new project's chip, name first ----

    for (final (language, l) in [('es', es), ('ca', ca), ('en', en)]) {
      testWidgets(
        'UX-1104: at 2× on 320×640 ($language), the chip of a task going to the new project «Matemáticas» starts with «Matemáticas» and shows at least its first 8 characters; the sheet’s row still reads «${l.commandNewProject('Matemáticas')}»',
        (tester) async {
          final app = await _App.open(
            tester,
            language: language,
            size: const Size(320, 640),
            textScale: 2,
          );
          await app.showResult(
            tester,
            drafts: [
              draft(
                'Terminar la presentación',
                date: day(4),
                newProject: 'Matemáticas',
              ),
            ],
            commands: [
              command({'kind': 'project', 'name': 'Matemáticas'}),
            ],
          );
          final label = l.commandNewProjectChip('Matemáticas');
          expect(label, startsWith('Matemáticas'));
          final text = find.descendant(
            of: find.byType(ActionChip),
            matching: find.text(label),
          );
          expect(text, findsOneWidget);
          await tester.ensureVisible(text);
          await tester.pumpAndSettle();
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: text, matching: find.byType(RichText)),
          );
          final widths = _oneLine(paragraph);
          final shown = paragraph.size.width + 0.5;
          if (widths.full > shown) {
            // Cut: the first 8 characters and the … still fit.
            expect(
              _prefixRight(paragraph, 8) + widths.ellipsis,
              lessThanOrEqualTo(shown),
              reason: 'at least «${'Matemáticas'.substring(0, 8)}» shows',
            );
          }
          final chip = tester.getRect(
            find.ancestor(of: text, matching: find.byType(ActionChip)),
          );
          expect(chip.left, greaterThanOrEqualTo(0));
          expect(chip.right, lessThanOrEqualTo(320.5));
          expect(tester.takeException(), isNull, reason: 'no overflow');

          await tester.tap(text);
          await tester.pumpAndSettle();
          final sheet = find.byType(BottomSheet).last;
          expect(
            find.descendant(
              of: sheet,
              matching: find.text(l.commandNewProject('Matemáticas')),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    test('UX-1104: the chip reads {name} (new) / (nuevo) / (nou)', () {
      expect(en.commandNewProjectChip('Kiko'), 'Kiko (new)');
      expect(es.commandNewProjectChip('Kiko'), 'Kiko (nuevo)');
      expect(ca.commandNewProjectChip('Kiko'), 'Kiko (nou)');
    });

    // ---- P141 · UX-1105: a person named for a brand-new project ----

    testWidgets(
      'UX-1105: «Crea el proyecto Matemáticas» with a task for Paul says «Paul aún no está en «Matemáticas». Luego, comparte el proyecto con Paul.»; an update naming a non-member of the existing «Equipo» still says «Paul no está en «Equipo»»',
      (tester) async {
        expect(
          es.commandMemberNotInNew('Paul', 'Matemáticas'),
          'Paul aún no está en «Matemáticas». Luego, comparte el proyecto con Paul.',
        );
        expect(
          en.commandMemberNotInNew('Paul', 'Maths'),
          'Paul isn’t in “Maths” yet. Afterwards, share the project with Paul.',
        );
        expect(
          ca.commandMemberNotInNew('Paul', 'Matemàtiques'),
          'Paul encara no és a «Matemàtiques». Després, comparteix el projecte amb Paul.',
        );
        expect(
          es.commandMemberNotIn('Paul', 'Equipo'),
          'Paul no está en «Equipo»',
        );
        final app = await _App.open(tester);
        await app.showResult(
          tester,
          drafts: [
            draft(
              'Hacer la introducción',
              newProject: 'Matemáticas',
              issues: ['member_not_available'],
              hints: {'project': 'Matemáticas', 'member': 'Paul'},
            ),
          ],
          commands: [
            command({'kind': 'project', 'name': 'Matemáticas'}),
          ],
        );
        await tester.tap(find.text('Hacer la introducción'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Paul aún no está en «Matemáticas». Luego, comparte el proyecto con Paul.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(es.commandMemberNotIn('Paul', 'Matemáticas')),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox());

        final equipo = _project(
          'team',
          'Equipo',
          shared: true,
          people: const [
            ProjectMember(id: 1, name: 'Yo', role: 'owner'),
            ProjectMember(id: 2, name: 'Ana', role: 'editor'),
          ],
        );
        final again = await _App.open(
          tester,
          projects: [equipo],
          tasks: [
            Task(
              id: 4,
              title: 'Informe trimestral',
              priority: 1,
              listId: 'team',
              assignment: 'group',
            ),
          ],
        );
        await again.showResult(
          tester,
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['informe'],
              },
              'changes': {'assignee_name': 'Paul'},
              'issues': ['member_not_available'],
            }),
          ],
        );
        expect(find.text('Paul no está en «Equipo»'), findsOneWidget);
        expect(
          find.text(es.commandMemberNotInNew('Paul', 'Equipo')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    // ---- P141 · UX-1106: one way to fix a misheard project name ----

    testWidgets(
      'UX-1106: with no projects and «Quico» dictated as a new project, the task’s project sheet has one «Nuevo proyecto» row; tapping it, typing «Kiko» and «Usar este nombre» renames the card and the chip, nothing is created until the confirming tap, which creates only «Kiko» with the task in it',
      (tester) async {
        final app = await _App.open(tester);
        await app.showResult(
          tester,
          drafts: [
            draft('Repasar el tema 2', date: day(4), newProject: 'Quico'),
          ],
          commands: [
            command({'kind': 'project', 'name': 'Quico'}),
          ],
        );
        expect(find.text(es.commandNewProject('Quico')), findsOneWidget);
        final chip = find.text(es.commandNewProjectChip('Quico'));
        expect(chip, findsOneWidget);

        Future<Finder> openSheet(Finder on) async {
          await tester.ensureVisible(on);
          await tester.pumpAndSettle();
          await tester.tap(on);
          await tester.pumpAndSettle();
          return find.byType(BottomSheet).last;
        }

        var sheet = await openSheet(chip);
        final rows = [
          for (final text in tester.widgetList<Text>(
            find.descendant(of: sheet, matching: find.byType(Text)),
          ))
            if ((text.data ?? '').startsWith(es.newList)) text.data,
        ];
        expect(es.newList, 'Nuevo proyecto');
        expect(rows, [es.commandNewProject('Quico')], reason: '$rows');

        // Cancelar keeps the name.
        await tester.tap(
          find.descendant(
            of: sheet,
            matching: find.text(es.commandNewProject('Quico')),
          ),
        );
        await tester.pumpAndSettle();
        var dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget);
        await tester.tap(
          find.descendant(of: dialog, matching: find.text(es.cancel)),
        );
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(find.text(es.commandNewProjectChip('Quico')), findsOneWidget);

        sheet = await openSheet(find.text(es.commandNewProjectChip('Quico')));
        await tester.tap(
          find.descendant(
            of: sheet,
            matching: find.text(es.commandNewProject('Quico')),
          ),
        );
        await tester.pumpAndSettle();
        dialog = find.byType(AlertDialog);
        expect(
          find.descendant(of: dialog, matching: find.text(es.newList)),
          findsOneWidget,
          reason: 'titled Nuevo proyecto',
        );
        final field = find.descendant(
          of: dialog,
          matching: find.byType(TextField),
        );
        expect(field, findsOneWidget);
        final input = tester.widget<TextField>(field);
        expect(input.decoration!.labelText, es.listName);
        expect(es.listName, 'Nombre');
        expect(input.controller!.text, 'Quico');
        expect(
          input.controller!.selection,
          const TextSelection(baseOffset: 0, extentOffset: 5),
          reason: 'selected, so typing replaces it',
        );
        expect(input.maxLength, 80);
        expect(es.commandUseName, 'Usar este nombre');
        FilledButton use() => tester.widget<FilledButton>(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(FilledButton, es.commandUseName),
          ),
        );
        expect(use().onPressed, isNotNull);
        await tester.enterText(field, '   ');
        await tester.pumpAndSettle();
        expect(use().onPressed, isNull, reason: 'off while empty');
        await tester.enterText(field, 'Kiko');
        await tester.pumpAndSettle();
        expect(use().onPressed, isNotNull);
        await tester.tap(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(FilledButton, es.commandUseName),
          ),
        );
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);

        expect(find.text(es.commandNewProject('Kiko')), findsOneWidget);
        expect(find.text(es.commandNewProjectChip('Kiko')), findsOneWidget);
        expect(find.textContaining('Quico'), findsNothing);
        expect(app.lists.created, isEmpty, reason: 'nothing created yet');
        expect(app.store.current!.drafts.single.newProject, 'Kiko');
        expect(app.store.current!.commands.single.name, 'Kiko');

        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        expect(app.lists.created, ['Kiko']);
        final project = app.lists.projects.single;
        expect(project.name, 'Kiko');
        expect(app.tasks.named('Repasar el tema 2')!.listId, project.id);
        expect(tester.takeException(), isNull);
      },
    );

    // ---- P141 · UX-1103: the person chip's ▾ ----

    final familia = _project(
      'familia',
      'Familia',
      shared: true,
      people: const [
        ProjectMember(id: 1, name: 'Yo', role: 'owner'),
        ProjectMember(id: 2, name: 'Ana', role: 'editor'),
      ],
    );
    final viewOnly = _project(
      'club',
      'Club',
      role: 'viewer',
      shared: true,
      people: const [
        ProjectMember(id: 5, name: 'Jordi', role: 'owner'),
        ProjectMember(id: 1, name: 'Yo', role: 'viewer'),
        ProjectMember(id: 2, name: 'Ana', role: 'editor'),
      ],
    );

    /// The person chip showing «Ana» on the result.
    Finder personChip() => find.ancestor(
      of: find.descendant(
        of: find.byType(CaptureResult),
        matching: find.text('Ana'),
      ),
      matching: find.byType(ActionChip),
    );
    Finder arrowOf(Finder chip) => find.descendant(
      of: chip,
      matching: find.byIcon(Icons.arrow_drop_down_rounded),
    );

    testWidgets(
      'UX-1103: on a capture card in a shared project with Ana assigned, the person chip shows ▾ and a tap opens «¿Quién es responsable?»; in a view-only project it shows no ▾',
      (tester) async {
        final app = await _App.open(tester, projects: [familia]);
        await app.showResult(
          tester,
          drafts: [
            _assignedDraft(
              'Comprar pan',
              listId: 'familia',
              assigneeId: 2,
              assigneeName: 'Ana',
            ),
          ],
        );
        expect(personChip(), findsOneWidget);
        expect(arrowOf(personChip()), findsOneWidget);
        await tester.tap(personChip());
        await tester.pumpAndSettle();
        expect(es.assignmentChoose, '¿Quién es responsable?');
        expect(find.text(es.assignmentChoose), findsOneWidget);
        await tester.pumpWidget(const SizedBox());

        final again = await _App.open(tester, projects: [viewOnly]);
        await again.showResult(
          tester,
          drafts: [
            _assignedDraft(
              'Comprar pan',
              listId: 'club',
              assigneeId: 2,
              assigneeName: 'Ana',
            ),
          ],
        );
        expect(personChip(), findsOneWidget);
        expect(arrowOf(personChip()), findsNothing, reason: 'view-only');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1103: at 2× on 320 dp the person chip’s ▾ lies wholly inside the chip and the screen',
      (tester) async {
        final app = await _App.open(
          tester,
          projects: [familia],
          size: const Size(320, 640),
          textScale: 2,
        );
        await app.showResult(
          tester,
          drafts: [
            _assignedDraft(
              'Comprar pan',
              listId: 'familia',
              assigneeId: 2,
              assigneeName: 'Ana',
            ),
          ],
        );
        final arrow = arrowOf(personChip());
        expect(arrow, findsOneWidget);
        await tester.ensureVisible(arrow);
        await tester.pumpAndSettle();
        final inside = tester.getRect(arrow);
        final outside = tester.getRect(personChip());
        expect(inside.left, greaterThanOrEqualTo(outside.left - 0.5));
        expect(inside.right, lessThanOrEqualTo(outside.right + 0.5));
        expect(inside.top, greaterThanOrEqualTo(outside.top - 0.5));
        expect(inside.bottom, lessThanOrEqualTo(outside.bottom + 0.5));
        expect(inside.left, greaterThanOrEqualTo(0));
        expect(inside.right, lessThanOrEqualTo(320.5));
        expect(tester.takeException(), isNull, reason: 'no overflow');
      },
    );
  });

  // ---- P139 · UX-1004: the capture result keeps the full date sheet ----

  testWidgets(
    'UX-1004: the capture result’s date sheet still has «Añadir hora» and «Listo»',
    (tester) async {
      final app = await _App.open(tester);
      await app.showResult(
        tester,
        drafts: [draft('Comprar pan', date: day(4))],
      );
      final line = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'draft-schedule-',
            ),
      );
      expect(line, findsWidgets);
      await tester.tap(line.first);
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet).last;
      expect(
        find.descendant(of: sheet, matching: find.text(es.reviewSchedule)),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('schedule-has-time')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('schedule-has-time')),
          matching: find.text(es.addTime),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('schedule-done')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ---- P142 · UX-1107: «Abrir» keeps the person ----

  group('UX-1107: «Abrir «Matemáticas»» opens on the person searched for', () {
    final mathsTeam = _project(
      'maths',
      'Matemáticas',
      shared: true,
      people: const [
        ProjectMember(id: 1, name: 'Yo', role: 'owner'),
        ProjectMember(id: 3, name: 'Paul', role: 'editor'),
        ProjectMember(id: 6, name: 'Lucía', role: 'editor'),
        ProjectMember(id: 4, name: 'Vera', role: 'viewer'),
      ],
    );
    List<Task> tasks() => [
      Task(
        id: 1,
        title: 'Ejercicio 4',
        priority: 1,
        listId: 'maths',
        assignment: 'member',
        assigneeId: 3,
        assigneeName: 'Paul',
      ),
      Task(
        id: 2,
        title: 'Repasar fracciones',
        priority: 1,
        listId: 'maths',
        assignment: 'member',
        assigneeId: 1,
        assigneeName: 'Yo',
      ),
      Task(
        id: 3,
        title: 'Corregir el examen',
        priority: 1,
        listId: 'maths',
        assignment: 'member',
        assigneeId: 6,
        assigneeName: 'Lucía',
      ),
      Task(
        id: 4,
        title: 'Ejercicio 2',
        priority: 1,
        listId: 'maths',
        assignment: 'member',
        assigneeId: 3,
        assigneeName: 'Paul',
        isCompleted: true,
      ),
    ];

    /// A search for [person]'s tasks in Matemáticas, then «Abrir».
    Future<Finder> openFor(WidgetTester tester, int person) async {
      final app = await _App.open(
        tester,
        projects: [mathsTeam],
        tasks: tasks(),
      );
      await app.showResult(
        tester,
        commands: [
          command({
            'kind': 'find',
            'words': [],
            'list_id': 'maths',
            'person_id': person,
          }),
        ],
      );
      final open = find.text(es.commandOpenProject('Matemáticas'));
      expect(open, findsOneWidget);
      await tester.ensureVisible(open);
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();
      final page = find.byType(HomeScreen).last;
      expect(tester.widget<HomeScreen>(page).listId, 'maths');
      return page;
    }

    bool chosen(WidgetTester tester, Finder page, String key) => tester
        .widget<ChoiceChip>(
          find.descendant(of: page, matching: find.byKey(ValueKey(key))),
        )
        .selected;
    List<String> listed(WidgetTester tester, Finder page) => [
      for (final tile in tester.widgetList<TaskTile>(
        find.descendant(of: page, matching: find.byType(TaskTile)),
      ))
        tile.task.title,
    ];

    testWidgets(
      'UX-1107: a search for Paul (an editor) in Matemáticas, then «Abrir «Matemáticas»»: Paul’s chip is selected and only his open task is listed',
      (tester) async {
        final page = await openFor(tester, 3);
        expect(chosen(tester, page, 'people-3'), isTrue);
        expect(chosen(tester, page, 'people-all'), isFalse);
        expect(listed(tester, page), ['Ejercicio 4']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1107: with the account’s own id, «Para mí» is selected',
      (tester) async {
        final page = await openFor(tester, 1);
        expect(chosen(tester, page, 'people-me'), isTrue);
        expect(chosen(tester, page, 'people-all'), isFalse);
        expect(listed(tester, page), isNot(contains('Ejercicio 4')));
        expect(listed(tester, page), contains('Repasar fracciones'));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1107: with a viewer’s id (no chip there), the page opens on «Todas»',
      (tester) async {
        final page = await openFor(tester, 4);
        expect(chosen(tester, page, 'people-all'), isTrue);
        expect(chosen(tester, page, 'people-me'), isFalse);
        expect(listed(tester, page), hasLength(3));
        expect(tester.takeException(), isNull);
      },
    );
  });
}

// ---- Run 2026-10-18-commands, b3 round 2 · P161 (UX-1225, UX-1226) ------
//
// Renaming a dictated project to an existing project's name files the tasks
// there, as the screen says; the dictated row shows a pencil.

/// Every semantics label in [node] and under it.
List<String> _labelsUnder(SemanticsNode node) {
  final labels = <String>[node.label];
  node.visitChildren((child) {
    labels.addAll(_labelsUnder(child));
    return true;
  });
  return labels;
}

void _commandsRound3b() {
  group('P161: renaming a dictated project', () {
    setUpAll(() async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });

    const title = 'Repasar el tema 2';

    /// The project chip of the task going to the new project [name].
    Finder newChip(AppLocalizations l, String name) => find.descendant(
      of: find.byType(ActionChip),
      matching: find.text(l.commandNewProjectChip(name)),
    );

    /// The chip opened: the project sheet, last on screen.
    Future<Finder> openSheet(WidgetTester tester, Finder chip) async {
      expect(chip, findsOneWidget);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      return find.byType(BottomSheet).last;
    }

    /// The sheet's «Nuevo proyecto: [from]» row tapped, [to] typed, and
    /// «Usar este nombre».
    Future<void> rename(WidgetTester tester, String from, String to) async {
      final sheet = await openSheet(tester, newChip(es, from));
      await tester.tap(
        find.descendant(
          of: sheet,
          matching: find.text(es.commandNewProject(from)),
        ),
      );
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextField)),
        to,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(FilledButton, es.commandUseName),
        ),
      );
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
    }

    Future<void> confirm(WidgetTester tester) async {
      final save = find.byKey(const ValueKey('save-drafts'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
    }

    /// A result with one task going to the dictated new project «Fisica 2»,
    /// with its project card unless [card] is false.
    Future<void> showFisica2(
      _App app,
      WidgetTester tester, {
      bool card = true,
    }) => app.showResult(
      tester,
      drafts: [draft(title, date: day(4), newProject: 'Fisica 2')],
      commands: [
        if (card) command({'kind': 'project', 'name': 'Fisica 2'}),
      ],
    );

    /// The result says the task goes to the existing «Física»: nothing new
    /// anywhere on screen, and, the task opened, a plain «Física» chip.
    Future<void> expectFiledInPhysics(WidgetTester tester) async {
      for (final name in ['física', 'Física']) {
        expect(
          find.textContaining(es.commandNewProject(name)),
          findsNothing,
          reason: name,
        );
      }
      expect(find.textContaining('(nuevo)'), findsNothing);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(
        find.ancestor(
          of: find.text(physics.name),
          matching: find.byType(ActionChip),
        ),
        findsWidgets,
        reason: 'the task’s chip reads «Física»',
      );
      expect(find.textContaining('(nuevo)'), findsNothing);
      expect(
        find.textContaining(es.commandNewProject('física')),
        findsNothing,
      );
      expect(newChip(es, 'física'), findsNothing);
    }

    testWidgets(
      'UX-1225: with «Física» to hand, renaming the dictated «Fisica 2» to «física» files the task in «Física»: its chip reads «Física» with no «(nuevo)», the card says «Ya tienes «Física»», and the confirming tap creates nothing and saves the task in physics',
      (tester) async {
        final app = await _App.open(tester, projects: [physics]);
        await showFisica2(app, tester);
        expect(find.text(es.commandNewProject('Fisica 2')), findsWidgets);
        expect(newChip(es, 'Fisica 2'), findsOneWidget);

        await rename(tester, 'Fisica 2', 'física');
        await expectFiledInPhysics(tester);
        expect(es.commandExistingProject('Física'), 'Ya tienes «Física»');
        expect(
          find.text(es.commandExistingProject('Física')),
          findsOneWidget,
          reason: 'the card shows an existing project',
        );
        expect(find.text(es.commandExistingProjectTasks(1)), findsOneWidget);
        expect(app.lists.created, isEmpty, reason: 'nothing created yet');

        await confirm(tester);
        expect(app.lists.created, isEmpty, reason: 'no project created');
        expect(app.lists.projects.map((p) => p.id), ['physics']);
        expect(app.tasks.named(title)!.listId, 'physics');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1225: a task going to «Fisica 2» with no project card, renamed to «física», also goes to «Física» with no «(nuevo)», and nothing is created',
      (tester) async {
        final app = await _App.open(tester, projects: [physics]);
        await showFisica2(app, tester, card: false);
        await rename(tester, 'Fisica 2', 'física');
        await expectFiledInPhysics(tester);
        await confirm(tester);
        expect(app.lists.created, isEmpty);
        expect(app.tasks.named(title)!.listId, 'physics');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1225: renamed to «Química», a name no project has, the chip reads «Química (nuevo)» and the confirming tap creates one «Química» holding the task',
      (tester) async {
        final app = await _App.open(tester, projects: [physics]);
        await showFisica2(app, tester);
        await rename(tester, 'Fisica 2', 'Química');
        expect(newChip(es, 'Química'), findsOneWidget);
        expect(find.text(es.commandNewProject('Química')), findsWidgets);
        expect(app.lists.created, isEmpty, reason: 'nothing created yet');

        await confirm(tester);
        expect(app.lists.created, ['Química']);
        final made = app.lists.projects.singleWhere((p) => p.name == 'Química');
        expect(app.tasks.named(title)!.listId, made.id);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1225: with only a view-only «Física», renaming to «física» stays a new project: the chip still ends in «(nuevo)», and the confirming tap creates one new project for the task',
      (tester) async {
        final viewOnly = _project(
          'physics',
          'Física',
          role: 'viewer',
          shared: true,
          people: const [
            ProjectMember(id: 5, name: 'Jordi', role: 'owner'),
            ProjectMember(id: 1, name: 'Yo', role: 'viewer'),
          ],
        );
        expect(viewOnly.canEdit, isFalse);
        final app = await _App.open(tester, projects: [viewOnly]);
        await showFisica2(app, tester);
        await rename(tester, 'Fisica 2', 'física');
        // The typed name, capitalised as a dictated one is.
        final chip = newChip(es, 'Física');
        expect(chip, findsOneWidget);
        expect(tester.widget<Text>(chip).data, endsWith('(nuevo)'));
        expect(find.text(es.commandExistingProject('Física')), findsNothing);

        await confirm(tester);
        expect(app.lists.created, hasLength(1), reason: 'one new project');
        final made = app.lists.projects.singleWhere((p) => p.id != 'physics');
        expect(app.tasks.named(title)!.listId, made.id);
        expect(app.tasks.named(title)!.listId, isNot('physics'));
        expect(tester.takeException(), isNull);
      },
    );

    // ---- UX-1226: the pencil on the dictated row ----

    for (final (language, l) in [('es', es), ('ca', ca)]) {
      testWidgets(
        'UX-1226 ($language): the project sheet’s «${l.commandNewProject('Fisica 2')}» row ends in a pencil read as «${l.commandRenameProject}»',
        (tester) async {
          expect(
            l.commandRenameProject,
            language == 'es' ? 'Cambiar el nombre' : 'Canvia el nom',
          );
          final semantics = tester.ensureSemantics();
          final app = await _App.open(
            tester,
            language: language,
            projects: [physics],
          );
          await showFisica2(app, tester);
          final sheet = await openSheet(tester, newChip(l, 'Fisica 2'));
          final rowTitle = find.descendant(
            of: sheet,
            matching: find.text(l.commandNewProject('Fisica 2')),
          );
          final row = find.ancestor(
            of: rowTitle,
            matching: find.byType(ListTile),
          );
          expect(row, findsOneWidget);
          final pencil = find.descendant(
            of: row,
            matching: find.byIcon(Icons.edit_outlined),
          );
          expect(pencil, findsOneWidget);
          expect(
            tester.widget<ListTile>(row).trailing,
            isA<Icon>().having((i) => i.icon, 'icon', Icons.edit_outlined),
            reason: 'at the end of the row',
          );
          expect(
            tester.getRect(pencil).left,
            greaterThan(tester.getRect(rowTitle).left),
          );
          expect(
            tester.widget<Icon>(pencil).semanticLabel,
            l.commandRenameProject,
          );
          expect(
            _labelsUnder(tester.getSemantics(row)).join(' '),
            contains(l.commandRenameProject),
          );
          // Other rows carry no pencil.
          expect(
            find.descendant(
              of: sheet,
              matching: find.byIcon(Icons.edit_outlined),
            ),
            findsOneWidget,
          );
          semantics.dispose();
          expect(tester.takeException(), isNull);
        },
      );
    }

    /// The project sheet opened straight from [chooseTaskList] for the new
    /// project «Fisica 2», with or without [onRename].
    Future<void> openPicker(
      WidgetTester tester, {
      ValueChanged<String>? onRename,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskListsProvider.overrideWith((ref) async => [physics]),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  ref.watch(taskListsProvider);
                  return TextButton(
                    onPressed: () => chooseTaskList(
                      context,
                      ref,
                      newName: 'Fisica 2',
                      onRename: onRename,
                    ),
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text(es.commandNewProject('Fisica 2')), findsOneWidget);
    }

    testWidgets(
      'UX-1226: with the card disabled while saving (no onRename), the dictated row has no pencil; with onRename it has one',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await openPicker(tester);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.bySemanticsLabel(es.commandRenameProject), findsNothing);
        await tester.pumpWidget(const SizedBox());

        await openPicker(tester, onRename: (_) {});
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1226: at 2× on 320×640 with Manrope the pencil lies wholly inside the sheet and the screen, and the row’s title shows without overflow (render on request)',
      (tester) async {
        final app = await _App.open(
          tester,
          size: const Size(320, 640),
          textScale: 2,
          projects: [physics],
        );
        await showFisica2(app, tester);
        final sheet = await openSheet(tester, newChip(es, 'Fisica 2'));
        final rowTitle = find.descendant(
          of: sheet,
          matching: find.text(es.commandNewProject('Fisica 2')),
        );
        final row = find.ancestor(
          of: rowTitle,
          matching: find.byType(ListTile),
        );
        final pencil = find.descendant(
          of: row,
          matching: find.byIcon(Icons.edit_outlined),
        );
        expect(pencil, findsOneWidget);
        final box = tester.getRect(pencil);
        final sheetBox = tester.getRect(sheet);
        const screen = Rect.fromLTWH(0, 0, 320, 640);
        for (final (what, outer) in [('sheet', sheetBox), ('screen', screen)]) {
          expect(box.left, greaterThanOrEqualTo(outer.left - 0.5), reason: what);
          expect(
            box.right,
            lessThanOrEqualTo(outer.right + 0.5),
            reason: what,
          );
          expect(box.top, greaterThanOrEqualTo(outer.top - 0.5), reason: what);
          expect(
            box.bottom,
            lessThanOrEqualTo(outer.bottom + 0.5),
            reason: what,
          );
        }
        final titleBox = tester.getRect(rowTitle);
        expect(
          titleBox.right,
          lessThanOrEqualTo(box.left + 0.5),
          reason: 'the pencil doesn’t cover the name',
        );
        expect(titleBox.left, greaterThanOrEqualTo(0));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: rowTitle, matching: find.byType(RichText)),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: 'not cut');
        expect(tester.takeException(), isNull, reason: 'no overflow');

        if (const bool.fromEnvironment('WRITE_COMMAND_PREVIEWS')) {
          await tester.runAsync(() async {
            final layer =
                tester.binding.renderViews.first.debugLayer! as OffsetLayer;
            final image = await layer.toImage(screen, pixelRatio: 2);
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(
              'build/commands-project-sheet-rename-es-2x.png',
            ).writeAsBytes(bytes.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  });
}

// ---- Run 2026-10-18-commands, b4 · P152 (UX-917, UX-919; D1, D3) ----
//
// A result with nothing to add closes on Cancelar, Back or a tap above the
// sheet with no question; the phone-parser fallback reads «Guardar como
// tarea».

void _commandsRound4() {
  group('UX-917: Cancelar on a result with nothing to add just closes', () {
    CaptureCommand deletion() => command({
      'kind': 'delete',
      'target': {
        'words': ['dentista'],
      },
    });

    /// The one capture showResult wrote.
    CaptureSession only(_App app) => app.store.sessions.values.single;

    final exits = <(String, Future<void> Function(WidgetTester))>[
      (
        'Cancelar',
        (tester) => tester.tap(
          find.descendant(
            of: find.byType(CaptureResult),
            matching: find.widgetWithText(TextButton, es.cancel),
          ),
        ),
      ),
      ('Back', (tester) => tester.binding.handlePopRoute()),
      (
        'a tap above the sheet',
        (tester) async {
          final top = tester.getRect(find.byType(BottomSheet)).top;
          expect(top, greaterThan(40), reason: 'room above the sheet');
          await tester.tapAt(Offset(195, top / 2));
        },
      ),
    ];

    for (final (name, leave) in exits) {
      testWidgets(
        'UX-917: $name on a spoken result holding only the deletion of '
        '«Dentista» closes the sheet with no dialog; «Dentista» still exists '
        'and no capture is pending',
        (tester) async {
          final app = await _App.open(
            tester,
            tasks: [Task(id: 1, title: 'Dentista', priority: 1)],
          );
          await app.showResult(tester, commands: [deletion()]);
          expect(find.byType(DeleteCommandCard), findsOneWidget);
          expect(only(app).source, 'speech');
          await leave(tester);
          await tester.pump();
          expect(find.byType(AlertDialog), findsNothing, reason: 'no question');
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byType(CaptureResult), findsNothing);
          expect(find.byType(BottomSheet), findsNothing);
          expect(app.tasks.byId(1), isNotNull, reason: 'Dentista survives');
          expect(app.tasks.byId(1)!.title, 'Dentista');
          expect(
            only(app).status,
            'discarded',
            reason: 'nothing waits in «Sin guardar»',
          );
          expect(app.store.saves, 0, reason: 'nothing was applied');
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'UX-917: Cancelar on a result holding only a change closes with no '
      'dialog, and the task doesn’t change',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [
            Task(id: 2, title: 'Ir al médico', priority: 1, dueDate: day(3, 10)),
          ],
        );
        await app.showResult(
          tester,
          commands: [
            command({
              'kind': 'update',
              'target': {
                'words': ['médico'],
              },
              'changes': {'title': 'Ir al médico de cabecera'},
            }),
          ],
        );
        await tester.tap(
          find.descendant(
            of: find.byType(CaptureResult),
            matching: find.widgetWithText(TextButton, es.cancel),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(CaptureResult), findsNothing);
        expect(app.tasks.byId(2)!.title, 'Ir al médico');
        expect(Task.day(app.tasks.byId(2)!.dueDate!), day(3));
        expect(only(app).status, 'discarded');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-917: Cancelar on a result holding only a new project «Física» '
      'closes with no dialog, and no project is created',
      (tester) async {
        final app = await _App.open(tester);
        await app.showResult(
          tester,
          commands: [
            command({'kind': 'project', 'name': 'Física'}),
          ],
        );
        await tester.tap(
          find.descendant(
            of: find.byType(CaptureResult),
            matching: find.widgetWithText(TextButton, es.cancel),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(CaptureResult), findsNothing);
        expect(app.lists.created, isEmpty);
        expect(app.lists.projects, isEmpty);
        expect(only(app).status, 'discarded');
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('UX-919: the fallback reads «Guardar como tarea»', () {
    for (final language in ['es', 'en', 'ca']) {
      testWidgets(
        'UX-919 ($language): a change result that found nothing offers the '
        'filled «${lookupAppLocalizations(Locale(language)).captureSaveAsWritten}»',
        (tester) async {
          final l = lookupAppLocalizations(Locale(language));
          final app = await _App.open(
            tester,
            language: language,
            tasks: [Task(id: 1, title: 'Ir al médico', priority: 1)],
          );
          await app.showResult(
            tester,
            commands: [
              command({
                'kind': 'update',
                'target': {
                  'words': ['aceite', 'coche'],
                },
                'changes': {'date': key(_saturday())},
              }),
            ],
          );
          expect(
            find.text(l.commandTaskNotFound('aceite coche')),
            findsOneWidget,
          );
          expect(_asWritten(), findsOneWidget);
          expect(tester.widget(_asWritten()), isA<FilledButton>());
          expect(
            find.descendant(
              of: _asWritten(),
              matching: find.text(l.captureSaveAsWritten),
            ),
            findsOneWidget,
          );
          expect(
            l.captureSaveAsWritten,
            {
              'es': 'Guardar como tarea',
              'en': 'Save as a task',
              'ca': 'Desa-ho com a tasca',
            }[language],
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}

// ---- Run 2026-10-18-commands, b5 · P159 (UX-1111, D7) ---------------------
//
// With Pro, a dictation said on a shared project's page with a person's chip
// on gives that person the tasks whose words named nobody.

void _commandsRound5() {
  group('UX-1111: a dictation under a person’s chip is theirs', () {
    final familia = TaskListInfo(
      id: 'familia',
      name: 'Familia',
      version: 1,
      shared: true,
      role: 'owner',
      ownerId: 1,
      people: const [
        ProjectMember(id: 1, name: 'Yo', role: 'owner'),
        ProjectMember(id: 2, name: 'Ana', role: 'editor'),
        ProjectMember(id: 3, name: 'Paul', role: 'editor'),
      ],
    );

    /// Familia's page, from Tareas, with the chip [chip] on.
    Future<_App> openFamilia(WidgetTester tester, String chip) async {
      final app = await _App.open(tester, projects: [familia]);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(es.tasks),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        Navigator.of(tester.element(find.byType(HomeScreen).first)).push(
          MaterialPageRoute<void>(
            builder: (_) => const HomeScreen(isRoot: false, listId: 'familia'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(chip)).last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChoiceChip>(find.byKey(ValueKey(chip)).last).selected,
        isTrue,
      );
      return app;
    }

    Map<String, dynamic> breadFor({
      String assignment = 'group',
      int? assigneeId,
      String? assigneeName,
      Map<String, String?> hints = const {},
    }) => {
      'transcript': 'Comprar pan',
      'tasks': [
        {
          ...serverTask('Comprar pan', listId: 'familia', hints: hints),
          'assignment': assignment,
          'assignee_id': assigneeId,
          'assignee_name': assigneeName,
        },
      ],
      'commands': [],
    };

    /// The person chip on the result's card reading [name].
    Finder personChip(String name) => find.descendant(
      of: find.byType(CaptureResult),
      matching: find.widgetWithText(ActionChip, name),
    );

    testWidgets(
      'UX-1111: Pro, on Familia with Ana’s chip on, «Comprar pan» (a draft in Familia for everyone, no hints) shows the person chip «Ana»; one tap adds it as Ana’s, and Deshacer brings the card back as shown',
      (tester) async {
        final app = await openFamilia(tester, 'people-2');
        app.api.answer = breadFor();
        await app.speak(tester, 'Comprar pan');
        expect(find.byType(CaptureResult), findsOneWidget);
        expect(personChip('Ana'), findsOneWidget);
        expect(personChip(es.assignedToGroup), findsNothing);
        // Kept with the capture, as a card's edit is.
        final kept = app.store.current!.drafts.single.task;
        expect(kept.assignment, 'member');
        expect(kept.assigneeId, 2);

        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        final saved = app.tasks.named('Comprar pan')!;
        expect(saved.listId, 'familia');
        expect(saved.assignment, 'member');
        expect(saved.assigneeId, 2);
        expect(saved.assigneeName, 'Ana');
        expect(find.byType(CaptureResult), findsNothing);

        await tester.tap(find.text(es.undo));
        await tester.pumpAndSettle();
        expect(app.tasks.named('Comprar pan'), isNull);
        expect(find.byType(CaptureResult), findsOneWidget);
        expect(personChip('Ana'), findsOneWidget);
        expect(app.store.current!.drafts.single.task.assigneeId, 2);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1111: Pro, on Ana’s chip, «Paul tiene que comprar pan» (a draft assigned to Paul) stays Paul’s',
      (tester) async {
        final app = await openFamilia(tester, 'people-2');
        app.api.answer = breadFor(
          assignment: 'member',
          assigneeId: 3,
          assigneeName: 'Paul',
          hints: {'member': 'Paul'},
        );
        await app.speak(tester, 'Paul tiene que comprar pan');
        expect(personChip('Paul'), findsOneWidget);
        expect(personChip('Ana'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('save-drafts')));
        await tester.pumpAndSettle();
        final saved = app.tasks.named('Comprar pan')!;
        expect(saved.assignment, 'member');
        expect(saved.assigneeId, 3);
        expect(saved.assigneeName, 'Paul');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UX-1111: Pro, on Ana’s chip, a draft whose words named Paul without matching him (a hint, no assignee) is not given to Ana',
      (tester) async {
        final app = await openFamilia(tester, 'people-2');
        app.api.answer = breadFor(hints: {'member': 'Paul'});
        await app.speak(tester, 'Paul tiene que comprar pan');
        expect(personChip('Ana'), findsNothing);
        expect(app.store.current!.drafts.single.task.assigneeId, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    for (final (chip, name) in [('people-all', 'Todas'), ('people-me', 'Para mí')]) {
      testWidgets(
        'UX-1111: Pro, on Familia with $name on, «Comprar pan» stays as the assistant said it: for everyone',
        (tester) async {
          final app = await openFamilia(tester, chip);
          app.api.answer = breadFor();
          await app.speak(tester, 'Comprar pan');
          expect(find.byType(CaptureResult), findsOneWidget);
          expect(personChip('Ana'), findsNothing);
          await tester.tap(find.byKey(const ValueKey('save-drafts')));
          await tester.pumpAndSettle();
          final saved = app.tasks.named('Comprar pan')!;
          expect(saved.assignment, 'group');
          expect(saved.assigneeId, isNull);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
