import 'dart:async';

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
        expect(find.text(es.commandNewProject('Física')), findsNWidgets(2));
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
        expect(find.text(es.commandNewProject('Física')), findsNWidgets(2));
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
        expect(find.text(es.commandExistingProjectTasks), findsOneWidget);
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
        await tester.tap(find.byKey(const ValueKey('project-choice-maths')));
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
        expect(
          find.text(es.commandCreateProjectQuestion('Química')),
          findsNWidgets(2),
        );
        expect(find.text(es.commandCreateNamed('Química')), findsNWidgets(2));
        expect(find.text('Física'), findsNWidgets(2));
        expect(find.text(es.noList), findsNWidgets(2));
        // Nothing is added until it is chosen.
        expect(saveButton(tester).onPressed, isNull);
        await tester.tap(
          find.byKey(const ValueKey('project-choice-create')).first,
        );
        await tester.pumpAndSettle();
        // One choice for both.
        expect(
          find.text(es.commandCreateProjectQuestion('Química')),
          findsNothing,
        );
        expect(find.text(es.commandNewProject('Química')), findsNWidgets(2));
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
        await tester.tap(find.byKey(const ValueKey('project-choice-physics')));
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
          find.text(es.commandMemberNotIn('Paul', 'Matemáticas')),
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
        expect(find.text(es.commandWhichDay), findsOneWidget);
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
        expect(find.text(es.commandNewProject('Física')), findsNWidgets(2));
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
      'without Pro, typed words never reach the assistant: «Rellenar a mano» '
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
            find.text(l.commandCreateProjectQuestion('Geografía e historia')),
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
      'No encuentro…, a filled full-width «Guardar tal cual», and «Cerrar» '
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
        expect(es.captureSaveAsWritten, 'Guardar tal cual');
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
      'UX-901: «Guardar tal cual» sends nothing more to the assistant, saves '
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
      '«Guardar tal cual» above «Cerrar»; a search that finds two tasks shows '
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
      'así.») shows no «Guardar tal cual»',
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
        await tester.tap(
          find.descendant(
            of: find.byType(CaptureResult),
            matching: find.widgetWithText(TextButton, es.cancel),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(es.discard),
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
      'UX-901: a free account with 3 dictations left: «Guardar tal cual» makes '
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

    testWidgets('UX-903: Cancelar on a spoken result holding a deletion asks '
        '«¿Conservar lo que has dicho para más tarde?» with Descartar and '
        'Conservar', (tester) async {
      final app = await _App.open(
        tester,
        tasks: [Task(id: 1, title: 'Dentista', priority: 1)],
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
      'UX-903: Cancelar on a typed result asks «¿Conservar el texto para más '
      'tarde?»',
      (tester) async {
        final app = await _App.open(
          tester,
          tasks: [Task(id: 1, title: 'Dentista', priority: 1)],
        );
        app.api.answer = {
          'transcript': 'Borra el dentista',
          'tasks': [],
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
        await app.type(tester, 'Borra el dentista');
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
