import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agenda/models/capture_command.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_problem.dart';
import 'package:agenda/services/capture_processor.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/command_plan.dart';
import 'package:agenda/services/command_runner.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/task_list_store.dart';
import 'package:agenda/services/task_matcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A command as the server sends it (Backend/docs/VOICE_COMMANDS.md).
CaptureCommand command(Map<String, dynamic> json) =>
    CaptureCommand.fromServer(json)!;

/// The shape of a whole draft from the server, with the two fields the
/// `commands` flag adds.
Map<String, dynamic> serverTask(
  String title, {
  String? newProject,
  String? suggestion,
  List<String> issues = const [],
  Map<String, String?> hints = const {},
  String? listId,
}) => {
  'title': title,
  'date': null,
  'time': null,
  'due_date': null,
  'scheduled_date': null,
  'deadline_date': '2026-11-12',
  'deadline_at': null,
  'priority': 2,
  'notes': '',
  'checklist': [],
  'questions': [],
  'clarifications': [],
  'recurrence': 'none',
  'repeat_interval': 1,
  'repeat_weekdays': [],
  'repeat_until': null,
  'duration_minutes': null,
  'timezone': 'Europe/Madrid',
  'transcript': '…',
  'list_id': listId,
  'assignment': 'personal',
  'assignee_id': null,
  'assignee_name': null,
  'assignment_issues': issues,
  'assignment_hints': {'project': null, 'group': null, 'member': null, ...hints},
  'new_project': newProject,
  'project_suggestion': suggestion,
};

void main() {
  group('the answer’s commands', () {
    test('a project, with or without an existing one, and its issues', () {
      final created = command({
        'kind': 'project',
        'name': 'Matemáticas',
        'existing_list_id': null,
        'issues': [],
      });
      expect(created.kind, CommandKind.project);
      expect(created.name, 'Matemáticas');
      expect(created.existingListId, isNull);
      expect(created.existing, isFalse);
      expect(created.pending, isTrue);
      final existing = command({
        'kind': 'project',
        'name': 'Matemáticas',
        'existing_list_id': '7d1c0a52-3c1e-4b8e-9f1a-1f6b2b8f0c11',
        'issues': [],
      });
      expect(existing.existing, isTrue);
      // Nothing to create: it never waits.
      expect(existing.pending, isFalse);
      final ambiguous = command({
        'kind': 'project',
        'name': 'Mates',
        'existing_list_id': null,
        'issues': ['ambiguous_project'],
      });
      expect(ambiguous.ambiguous, isTrue);
      expect(ambiguous.copyWith(choice: 'list-2').existing, isTrue);
      expect(ambiguous.copyWith(choice: CaptureCommand.createChoice).existing,
          isFalse);
      // A project with no name isn't a command.
      expect(
        CaptureCommand.fromServer({'kind': 'project', 'name': ' ', 'issues': []}),
        isNull,
      );
    });

    test('a search keeps its words, filters and status; a period is in order',
        () {
      final find = command({
        'kind': 'find',
        'words': ['introducción', ' ', 'tema'],
        'list_id': '7d1c0a52-3c1e-4b8e-9f1a-1f6b2b8f0c11',
        'project_name': null,
        'person_id': 3,
        'person_name': null,
        'status': 'open',
        'from': '2026-11-30',
        'to': '2026-11-01',
        'issues': [],
      });
      expect(find.kind, CommandKind.find);
      expect(find.words, ['introducción', 'tema']);
      expect(find.listId, '7d1c0a52-3c1e-4b8e-9f1a-1f6b2b8f0c11');
      expect(find.personId, 3);
      expect(find.status, 'open');
      expect(find.from, DateTime(2026, 11, 1));
      expect(find.to, DateTime(2026, 11, 30));
      // A search never waits for the confirming tap.
      expect(find.pending, isFalse);
      final plain = command({'kind': 'find', 'words': [], 'issues': []});
      expect(plain.status, 'any');
      expect(plain.from, isNull);
      final unknownStatus =
          command({'kind': 'find', 'status': 'whatever', 'issues': []});
      expect(unknownStatus.status, 'any');
      final unresolved = command({
        'kind': 'find',
        'words': [],
        'project_name': 'Geografía',
        'person_name': 'Pol',
        'issues': ['project_not_available', 'member_not_available'],
      });
      expect(unresolved.projectName, 'Geografía');
      expect(unresolved.personName, 'Pol');
    });

    test('an update keeps only what was asked, and a day taken away takes the '
        'time with it', () {
      final update = command({
        'kind': 'update',
        'target': {
          'words': ['médico'],
          'list_id': null,
          'project_name': null,
          'date': '2026-10-21',
        },
        'changes': {'date': '2026-10-25'},
        'issues': [],
      });
      expect(update.target.words, ['médico']);
      expect(update.target.date, DateTime(2026, 10, 21));
      expect(update.changes.date, DateTime(2026, 10, 25));
      expect(update.changes.has('time'), isFalse);
      expect(update.changes.has('title'), isFalse);

      final cleared = command({
        'kind': 'update',
        'target': {'words': ['médico']},
        'changes': {'date': null, 'time': '10:00', 'deadline_date': null},
        'issues': [],
      }).changes;
      expect(cleared.has('date'), isTrue);
      expect(cleared.date, isNull);
      expect(cleared.has('time'), isTrue);
      expect(cleared.time, isNull);
      expect(cleared.has('deadline_time'), isTrue);

      final full = command({
        'kind': 'update',
        'target': {'words': ['informe']},
        'changes': {
          'title': '  Informe final ',
          'time': '18:30',
          'deadline_date': '2026-10-30',
          'deadline_time': '09:05',
          'priority': 3,
          'notes_append': 'Con los gráficos',
          'assignee_id': 3,
          'assignee_name': 'Paul',
        },
        'issues': [],
      }).changes;
      expect(full.title, 'Informe final');
      expect(full.time, (hour: 18, minute: 30));
      expect(full.deadlineDate, DateTime(2026, 10, 30));
      expect(full.deadlineTime, (hour: 9, minute: 5));
      expect(full.priority, 3);
      expect(full.notesAppend, 'Con los gráficos');
      expect(full.assigneeId, 3);
      expect(full.assigneeName, 'Paul');
      expect(full.assignsNobody, isFalse);
      expect(full.hasUnresolved, isFalse);

      // Values that don't fit the contract change nothing.
      final wrong = command({
        'kind': 'update',
        'target': {'words': ['informe']},
        'changes': {
          'date': '2026-02-31',
          'time': '25:00',
          'priority': 7,
          'title': '',
          'notes_append': 42,
        },
        'issues': [],
      }).changes;
      expect(wrong.isEmpty, isTrue);

      final nobody = command({
        'kind': 'update',
        'target': {'words': ['informe']},
        'changes': {'assignee_id': null, 'assignee_name': null},
        'issues': [],
      }).changes;
      expect(nobody.assignsNobody, isTrue);
      final unresolved = command({
        'kind': 'update',
        'target': {'words': ['informe']},
        'changes': {'assignee_name': 'Pol'},
        'issues': ['member_not_available'],
      });
      expect(unresolved.changes.hasUnresolved, isTrue);
      expect(unresolved.changes.assigneeId, isNull);
      expect(unresolved.issues, ['member_not_available']);
    });

    test('a deletion keeps its target', () {
      final delete = command({
        'kind': 'delete',
        'target': {
          'words': ['dentista'],
          'list_id': null,
          'project_name': null,
          'date': null,
        },
        'issues': [],
      });
      expect(delete.kind, CommandKind.delete);
      expect(delete.target.words, ['dentista']);
      expect(delete.changes.isEmpty, isTrue);
      expect(delete.pending, isTrue);
    });

    test('kinds this app doesn’t know, and things that aren’t commands, are '
        'left out', () {
      for (final item in [
        {'kind': 'invite', 'email': 'ana@example.invalid'},
        {'kind': 'search', 'words': ['pan']},
        {'kind': null},
        'delete everything',
        42,
        null,
      ]) {
        expect(CaptureCommand.fromServer(item), isNull, reason: '$item');
      }
    });

    test('a capture keeps its commands and the choices on their cards', () {
      final session = CaptureSession(
        id: 'kept',
        ownerKey: 'local',
        capturedAt: DateTime.utc(2026, 10, 18, 10),
        timezone: 'Europe/Madrid',
        status: 'ready',
        commands: [
          command({
            'kind': 'update',
            'target': {'words': ['médico'], 'date': '2026-10-21'},
            'changes': {'date': '2026-10-25', 'assignee_name': 'Pol'},
            'issues': ['member_not_available'],
          }).copyWith(taskId: 7, series: true, day: DateTime(2026, 10, 22)),
          command({
            'kind': 'project',
            'name': 'Mates',
            'issues': ['ambiguous_project'],
          }).copyWith(choice: 'list-2', removed: true),
        ],
      );
      final back = CaptureSession.fromJson(
        jsonDecode(jsonEncode(session.toJson())),
      );
      expect(back.hasResult, isTrue);
      final update = back.commands.first;
      expect(update.kind, CommandKind.update);
      expect(update.target.date, DateTime(2026, 10, 21));
      expect(update.changes.date, DateTime(2026, 10, 25));
      expect(update.changes.hasUnresolved, isTrue);
      expect(update.taskId, 7);
      expect(update.series, isTrue);
      expect(update.day, DateTime(2026, 10, 22));
      expect(update.id, session.commands.first.id);
      final project = back.commands.last;
      expect(project.choice, 'list-2');
      expect(project.removed, isTrue);
      // A capture kept by an older version has no commands.
      final old = CaptureSession.fromJson({
        'id': 'old',
        'ownerKey': 'local',
        'capturedAt': '2026-10-18T10:00:00.000Z',
        'timezone': 'Europe/Madrid',
        'status': 'ready',
        'drafts': [],
      });
      expect(old.commands, isEmpty);
      expect(old.hasResult, isFalse);
      // A plain capture is written as before: no `commands` key.
      expect(old.toJson().containsKey('commands'), isFalse);
    });
  });

  group('the answer’s tasks', () {
    test('a task for a new project waits for nothing; a person named for it '
        'leaves only a line', () {
      final draft = CaptureDraft.fromAI(
        TaskDraft.fromJson(serverTask('Terminar la presentación',
            newProject: 'Matemáticas')),
      );
      expect(draft.newProject, 'Matemáticas');
      expect(draft.projectSuggestion, isNull);
      expect(draft.ready, isTrue);
      final paul = CaptureDraft.fromAI(
        TaskDraft.fromJson(serverTask(
          'Hacer la introducción',
          newProject: 'Matemáticas',
          issues: ['member_not_available'],
          hints: {'project': 'Matemáticas', 'member': 'Paul'},
        )),
      );
      expect(paul.assignmentReviewed, isTrue);
      expect(paul.ready, isTrue);
      expect(paul.task.assignment, 'personal');
    });

    test('a project said that doesn’t exist waits for a choice', () {
      final draft = CaptureDraft.fromAI(
        TaskDraft.fromJson(serverTask(
          'Repasar el tema 3',
          suggestion: 'química',
          issues: ['project_not_available'],
          hints: {'project': 'química'},
        )),
      );
      expect(draft.projectSuggestion, 'química');
      expect(draft.ready, isFalse);
      // Kept with the capture.
      final back = CaptureDraft.fromJson(
        jsonDecode(jsonEncode(draft.toJson())),
      );
      expect(back.projectSuggestion, 'química');
      expect(back.ready, isFalse);
      final created = back.copyWith(
        newProject: 'Química',
        clearProjectSuggestion: true,
        assignmentReviewed: true,
      );
      expect(created.newProject, 'Química');
      expect(created.projectSuggestion, isNull);
      expect(created.ready, isTrue);
      expect(created.copyWith(clearNewProject: true).newProject, isNull);
    });

    test('an older server’s draft has neither field and is as before', () {
      final draft = CaptureDraft.fromAI(
        TaskDraft.fromJson({
          'title': 'Comprar pan',
          'due_date': null,
          'scheduled_date': null,
          'priority': 1,
          'notes': '',
          'transcript': 'Comprar pan',
          'questions': [],
        }),
      );
      expect(draft.newProject, isNull);
      expect(draft.projectSuggestion, isNull);
      expect(draft.ready, isTrue);
      expect(draft.toJson().containsKey('newProject'), isFalse);
    });

    test('a project’s name as said reads as a name', () {
      expect(spokenProjectName('química'), 'Química');
      expect(spokenProjectName('el proyecto de química'), 'Química');
      expect(spokenProjectName('«Física»'), 'Física');
      expect(spokenProjectName('iPhone app'), 'iPhone app');
      expect(spokenProjectName('La Caixa'), 'La Caixa');
      expect(spokenProjectName('lista de la compra'), 'Lista de la compra');
      expect(spokenProjectName('projecte d’història'), 'Història');
    });
  });

  group('finding tasks on the phone', () {
    final physics = TaskListInfo(id: 'physics', name: 'Física');
    final tasks = [
      Task(
        id: 1,
        title: 'Ir al médico',
        priority: 1,
        dueDate: DateTime(2026, 10, 21, 10),
        notes: 'Llevar los análisis',
      ),
      Task(
        id: 2,
        title: 'Recoger las gafas',
        priority: 1,
        notes: 'Pasar por el Médico de cabecera',
      ),
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
        deadline: DateTime(2026, 11, 8),
        reminderAnchor: 'deadline',
      ),
      Task(
        id: 5,
        title: 'Comprar pan',
        priority: 1,
        dueDate: DateTime(2026, 10, 19),
      ),
      Task(id: 6, title: 'Nota del médico', kind: 'note', priority: 1),
      Task(
        id: 7,
        title: 'Llamar a Ana',
        priority: 1,
        listId: 'team',
        assignment: 'member',
        assigneeId: 2,
        assigneeName: 'Ana',
      ),
      Task(
        id: 8,
        title: 'Llamar a Ana por el viaje',
        priority: 1,
        listId: 'team',
        assignment: 'member',
        assigneeId: 1,
        assigneeName: 'Yo',
      ),
    ];
    List<int?> ids(List<Task> found) => found.map((t) => t.id).toList();
    CaptureCommand find(Map<String, dynamic> fields) =>
        command({'kind': 'find', 'issues': [], ...fields});

    test('words match the title first, then the notes, ignoring case and '
        'accents; a word may start a longer one; notes are never found', () {
      for (final words in [
        ['médico'],
        ['MEDICO'],
        ['medic'],
      ]) {
        expect(
          ids(TaskMatcher.find(tasks, find({'words': words}))),
          [1, 2],
          reason: '$words',
        );
      }
      // Inside a word is not the start of it.
      expect(TaskMatcher.find(tasks, find({'words': ['edico']})), isEmpty);
      expect(TaskMatcher.find(tasks, find({'words': ['dentista']})), isEmpty);
    });

    test('every word if any task has them all, otherwise the most', () {
      expect(
        ids(TaskMatcher.find(tasks, find({'words': ['llamar', 'viaje']}))),
        [8],
      );
      // Nobody has «Paris»: those with the most words are kept.
      expect(
        ids(TaskMatcher.find(tasks, find({'words': ['llamar', 'paris']}))),
        [8, 7],
      );
    });

    test('completed tasks are found unless the status says otherwise; a '
        'project limits the search; newest first', () {
      final everything = find({
        'words': ['introducción'],
        'list_id': 'physics',
      });
      expect(ids(TaskMatcher.find(tasks, everything)), [4, 3]);
      expect(
        ids(TaskMatcher.find(tasks, find({
          'words': ['introduccion'],
          'status': 'open',
        }))),
        [4],
      );
      expect(
        ids(TaskMatcher.find(tasks, find({
          'words': ['introduccion'],
          'status': 'completed',
        }))),
        [3],
      );
      // No words: all of the project's tasks.
      expect(
        ids(TaskMatcher.find(tasks, find({'list_id': 'physics'}))),
        [4, 3],
      );
    });

    test('a person: someone else’s are those assigned to them; one’s own are '
        'what Para mí shows', () {
      expect(ids(TaskMatcher.find(tasks, find({'person_id': 2}))), [7]);
      final mine = ids(
        TaskMatcher.find(
          tasks,
          find({'person_id': 1}),
          accountId: 1,
          projects: [physics],
        ),
      );
      expect(mine, containsAll([8, 5, 4, 3, 2, 1]));
      expect(mine, isNot(contains(7)));
    });

    test('a period compares the planned day, or the deadline’s without one',
        () {
      expect(
        ids(TaskMatcher.find(tasks, find({
          'from': '2026-11-01',
          'to': '2026-11-30',
        }))),
        [4],
      );
      expect(
        ids(TaskMatcher.find(tasks, find({
          'from': '2026-10-21',
          'to': '2026-10-21',
        }))),
        [1],
      );
      final weekly = Task(
        id: 9,
        title: 'Yoga',
        priority: 1,
        dueDate: DateTime(2026, 10, 5, 19),
        recurrence: 'weekly',
      );
      // A repetition falls on Monday 26 October.
      expect(
        ids(TaskMatcher.find([weekly], find({
          'from': '2026-10-24',
          'to': '2026-10-27',
        }))),
        [9],
      );
      expect(
        TaskMatcher.find([weekly], find({
          'from': '2026-10-27',
          'to': '2026-10-31',
        })),
        isEmpty,
      );
    });

    // Run 2026-10-18-commands, b4 · P152 (UX-920, D4): a search with a
    // period lists soonest first, as Calendar lists the days.
    test('UX-920: a period from Monday 19 to Sunday 25 October lists soonest '
        'first: by day, then untimed before timed, then by time; a weekly '
        'task by its first repetition in the period, a deadline-only task by '
        'its deadline', () {
      // Added in this order: ids grow as the phone numbers them.
      final week = [
        Task(id: 1, title: 'Miércoles', priority: 1,
            dueDate: DateTime(2026, 10, 21)),
        Task(id: 2, title: 'Lunes a las 9', priority: 1,
            dueDate: DateTime(2026, 10, 19, 9), hasTime: true),
        Task(id: 3, title: 'Martes a las 10', priority: 1,
            dueDate: DateTime(2026, 10, 20, 10), hasTime: true),
        Task(id: 4, title: 'Lunes', priority: 1,
            dueDate: DateTime(2026, 10, 19)),
        Task(id: 5, title: 'Entrega', priority: 1,
            deadline: DateTime(2026, 10, 22), reminderAnchor: 'deadline'),
        Task(id: 6, title: 'Yoga', priority: 1,
            dueDate: DateTime(2026, 10, 5, 19), hasTime: true,
            recurrence: 'weekly'),
      ];
      final thisWeek = find({'from': '2026-10-19', 'to': '2026-10-25'});
      expect(ids(TaskMatcher.find(week, thisWeek)), [4, 2, 6, 3, 1, 5]);
      // Without a period: newest first, as before.
      expect(ids(TaskMatcher.find(week, find({}))), [6, 5, 4, 3, 2, 1]);
    });

    test('UX-920: with words and a period, a task holding the words in its '
        'title comes before one holding them only in its notes, even when '
        'the latter is sooner', () {
      final found = TaskMatcher.find(
        [
          Task(id: 1, title: 'Recoger las gafas', priority: 1,
              notes: 'Pasar por el dentista',
              dueDate: DateTime(2026, 10, 19, 9), hasTime: true),
          Task(id: 2, title: 'Llamar al dentista', priority: 1,
              dueDate: DateTime(2026, 10, 23, 17), hasTime: true),
        ],
        find({
          'words': ['dentista'],
          'from': '2026-10-19',
          'to': '2026-10-25',
        }),
      );
      expect(ids(found), [2, 1]);
    });

    test('a project or person that wasn’t found searches nothing', () {
      expect(
        TaskMatcher.find(tasks, find({
          'words': ['médico'],
          'project_name': 'Geografía',
        })),
        isEmpty,
      );
      expect(
        TaskMatcher.find(tasks, find({
          'words': ['médico'],
          'person_name': 'Pol',
        })),
        isEmpty,
      );
    });

    test('a task to change: its title wins over notes, open ones over '
        'completed, and only what the person can edit', () {
      bool all(String? _) => true;
      CommandTarget target(Map<String, dynamic> json) =>
          CommandTarget.fromJson(json);
      expect(
        ids(TaskMatcher.targets(tasks, target({'words': ['médico']}),
            canEdit: all)),
        [1],
      );
      expect(
        ids(TaskMatcher.targets(
          tasks,
          target({'words': ['introducción'], 'list_id': 'physics'}),
          canEdit: all,
        )),
        [4],
      );
      // Only completed ones match: those, then.
      expect(
        ids(TaskMatcher.targets(
          tasks,
          target({'words': ['hacer', 'introducción']}),
          canEdit: all,
        )),
        [3],
      );
      // A project the person only views.
      expect(
        TaskMatcher.targets(
          tasks,
          target({'words': ['introducción']}),
          canEdit: (id) => id != 'physics',
        ),
        isEmpty,
      );
      // Ties: both hold every word in the title, newest first.
      expect(
        ids(TaskMatcher.targets(tasks, target({'words': ['llamar', 'ana']}),
            canEdit: all)),
        [8, 7],
      );
      // Nothing to go on finds nothing, rather than every task.
      expect(TaskMatcher.targets(tasks, target({'words': []}), canEdit: all),
          isEmpty);
      expect(
        TaskMatcher.targets(
          tasks,
          target({'words': ['médico'], 'project_name': 'Geografía'}),
          canEdit: all,
        ),
        isEmpty,
      );
    });

    test('a day said keeps the tasks planned or due that day; a repeating '
        'task comes as that repetition', () {
      bool all(String? _) => true;
      expect(
        ids(TaskMatcher.targets(
          tasks,
          CommandTarget(date: DateTime(2026, 10, 21)),
          canEdit: all,
        )),
        [1],
      );
      expect(
        ids(TaskMatcher.targets(
          tasks,
          CommandTarget(
            words: const ['introducción'],
            date: DateTime(2026, 11, 8),
          ),
          canEdit: all,
        )),
        [4],
      );
      expect(
        TaskMatcher.targets(
          tasks,
          CommandTarget(words: const ['médico'], date: DateTime(2026, 10, 22)),
          canEdit: all,
        ),
        isEmpty,
      );
      final weekly = Task(
        id: 9,
        title: 'Clase de yoga',
        priority: 1,
        dueDate: DateTime(2026, 10, 5, 19),
        recurrence: 'weekly',
      );
      final found = TaskMatcher.targets(
        [weekly],
        CommandTarget(words: const ['yoga'], date: DateTime(2026, 10, 26)),
        canEdit: all,
      );
      expect(found.single.id, 9);
      expect(found.single.occurrenceDate, DateTime(2026, 10, 26, 19));
      expect(found.single.occurrenceId, '2026-10-26');
    });
  });

  group('what a change does', () {
    final doctor = Task(
      id: 1,
      title: 'Ir al médico',
      priority: 1,
      dueDate: DateTime(2026, 10, 21, 10),
      notes: 'Llevar los análisis',
      checklist: [ChecklistItem(id: 's1', title: 'Volante')],
      filePaths: ['/files/volante.pdf'],
      reminderMinutes: 30,
    );
    final undated = Task(id: 2, title: 'Recoger las gafas', priority: 1);
    TaskChanges changes(Map<String, dynamic> json) =>
        TaskChanges.fromJson(json);
    UpdatePlan plan(
      Task task,
      Map<String, dynamic> json, {
      TaskListInfo? project,
      int? accountId,
      DateTime? day,
      List<String> issues = const [],
    }) => planUpdate(
      task: task,
      shown: task,
      changes: changes(json),
      project: project,
      accountId: accountId,
      day: day,
      issues: issues,
    );

    test('a new day keeps the time; a time said too, or alone, sets it', () {
      expect(plan(doctor, {'date': '2026-10-25'}).schedule, (
        date: DateTime(2026, 10, 25, 10),
        hasTime: true,
      ));
      expect(plan(doctor, {'date': '2026-10-25', 'time': '18:30'}).schedule, (
        date: DateTime(2026, 10, 25, 18, 30),
        hasTime: true,
      ));
      expect(plan(doctor, {'time': '18:00'}).schedule, (
        date: DateTime(2026, 10, 21, 18),
        hasTime: true,
      ));
      expect(plan(doctor, {'time': null}).schedule, (
        date: DateTime(2026, 10, 21),
        hasTime: false,
      ));
      expect(plan(doctor, {'date': null}).schedule, (date: null, hasTime: false));
    });

    test('a time for a task with no day asks for one first', () {
      final asking = plan(undated, {'time': '18:00'});
      expect(asking.needsDay, isTrue);
      expect(asking.ready, isFalse);
      final chosen = plan(undated, {'time': '18:00'}, day: DateTime(2026, 10, 22));
      expect(chosen.needsDay, isFalse);
      expect(chosen.schedule, (date: DateTime(2026, 10, 22, 18), hasTime: true));
      expect(chosen.ready, isTrue);
    });

    test('what is already so changes nothing', () {
      final same = plan(doctor, {
        'date': '2026-10-21',
        'title': 'Ir al médico',
        'priority': 1,
      });
      expect(same.isEmpty, isTrue);
      expect(same.asked, isTrue);
      expect(same.ready, isFalse);
      final nothing = plan(doctor, {});
      expect(nothing.isEmpty, isTrue);
      expect(nothing.asked, isFalse);
    });

    test('only the fields asked change: notes, steps, files and reminders '
        'stay; notes get the new text on a new line', () {
      final after = plan(doctor, {
        'date': '2026-10-25',
        'title': 'Cita con la doctora',
        'priority': 3,
        'notes_append': 'Preguntar por la vacuna',
      }).after();
      expect(after.id, 1);
      expect(after.title, 'Cita con la doctora');
      expect(after.dueDate, DateTime(2026, 10, 25, 10));
      expect(after.priority, 3);
      expect(after.notes, 'Llevar los análisis\nPreguntar por la vacuna');
      expect(after.checklist.single.title, 'Volante');
      expect(after.filePaths, ['/files/volante.pdf']);
      expect(after.reminderMinutes, 30);
      expect(appendToNotes(null, 'Hola'), 'Hola');
      expect(appendToNotes('a' * 7999, 'bcd').length, 8000);
    });

    test('a deadline set or taken away, and the reminder follows it', () {
      final due = plan(undated, {'deadline_date': '2026-10-30'}).after();
      expect(due.deadline, DateTime(2026, 10, 30));
      expect(due.deadlineHasTime, isFalse);
      expect(due.reminderAnchor, 'deadline');
      final timed = Task(
        id: 3,
        title: 'Entregar',
        priority: 1,
        deadline: DateTime(2026, 11, 8, 17),
        deadlineHasTime: true,
        reminderAnchor: 'deadline',
      );
      final moved = plan(timed, {'deadline_date': '2026-11-10'});
      expect(moved.deadline, (date: DateTime(2026, 11, 10, 17), hasTime: true));
      final gone = plan(timed, {'deadline_date': null}).after();
      expect(gone.deadline, isNull);
      expect(gone.reminderAnchor, 'planned');
    });

    test('an assignee only in a shared project, among those who can edit it',
        () {
      final team = TaskListInfo(
        id: 'team',
        name: 'Matemáticas',
        shared: true,
        people: const [
          ProjectMember(id: 1, name: 'Yo', role: 'owner'),
          ProjectMember(id: 3, name: 'Paul', role: 'editor'),
          ProjectMember(id: 4, name: 'Vera', role: 'viewer'),
        ],
      );
      final shared = Task(
        id: 5,
        title: 'Informe',
        priority: 1,
        listId: 'team',
        assignment: 'group',
      );
      final paul = plan(shared, {
        'assignee_id': 3,
        'assignee_name': 'Paul',
      }, project: team, accountId: 1);
      expect(paul.assignee, (assignment: 'member', id: 3, name: 'Paul'));
      expect(paul.problem, isNull);
      final vera = plan(shared, {
        'assignee_id': 4,
        'assignee_name': 'Vera',
      }, project: team, accountId: 1);
      expect(vera.assignee, isNull);
      expect(vera.problem, AssigneeProblem.notInProject);
      expect(vera.problemName, 'Vera');
      final personal = plan(undated, {
        'assignee_id': 3,
        'assignee_name': 'Paul',
      }, accountId: 1);
      expect(personal.assignee, isNull);
      expect(personal.problem, AssigneeProblem.needsShared);
      // «Asígnamela» on one's own task: nothing to change or to say.
      final mine = plan(undated, {
        'assignee_id': 1,
        'assignee_name': 'Yo',
      }, accountId: 1);
      expect(mine.assignee, isNull);
      expect(mine.problem, isNull);
      final assigned = shared.copyWith(
        assignment: 'member',
        assigneeId: 3,
        assigneeName: 'Paul',
      );
      expect(
        plan(assigned, {'assignee_id': null, 'assignee_name': null},
                project: team)
            .assignee,
        (assignment: 'group', id: null, name: null),
      );
      final ambiguous = plan(shared, {'assignee_name': 'Pau'},
          project: team, issues: ['ambiguous_member']);
      expect(ambiguous.problem, AssigneeProblem.ambiguous);
      expect(ambiguous.problemName, 'Pau');
      expect(
        plan(shared, {'assignee_name': 'Pol'},
                project: team, issues: ['member_not_available'])
            .problem,
        AssigneeProblem.notInProject,
      );
    });

    test('a repeating task’s day taken away is the whole series’', () {
      final weekly = Task(
        id: 9,
        title: 'Yoga',
        priority: 1,
        dueDate: DateTime(2026, 10, 5, 19),
        recurrence: 'weekly',
      );
      final shown = weekly.occurrenceOn(DateTime(2026, 10, 26))!;
      final moved = planUpdate(
        task: weekly,
        shown: shown,
        changes: changes({'date': '2026-10-27'}),
      );
      expect(moved.repeating, isTrue);
      expect(moved.seriesOnly, isFalse);
      expect(moved.schedule, (date: DateTime(2026, 10, 27, 19), hasTime: true));
      final undated = planUpdate(
        task: weekly,
        shown: shown,
        changes: changes({'date': null}),
      );
      expect(undated.seriesOnly, isTrue);
    });

    test('undo puts back only the fields a change wrote', () {
      final written = doctor.copyWith(title: 'Cita', priority: 3);
      // Edited since, elsewhere: the notes stay as they are now.
      final now = written.copyWith(notes: 'Notas nuevas');
      final restored = restoreFields(now, doctor, written);
      expect(restored.title, 'Ir al médico');
      expect(restored.priority, 1);
      expect(restored.notes, 'Notas nuevas');
      expect(restored.dueDate, doctor.dueDate);
      expect(restored.checklist.single.id, 's1');
    });
  });

  group('the capture and its projects on the phone', () {
    sqfliteFfiInit();
    late Directory directory;
    late TaskDatabase database;
    late CaptureStore store;
    const owner = 'http://phone.test/users/1';

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('taskflow-commands-');
      final sql = await databaseFactoryFfi.openDatabase(
        p.join(directory.path, 'test.db'),
      );
      await sql.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
      );
      await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
      database = TaskDatabase.forTesting(sql);
      store = CaptureStore(database, directory: directory);
    });

    tearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    test('a result is finished once no task and no command waits; one of '
        'only commands finishes with an empty set, and Undo brings its '
        'commands back', () async {
      final session = await store.create(owner, 'Europe/Madrid', text: 'Borra');
      final delete = command({
        'kind': 'delete',
        'target': {'words': ['dentista']},
        'issues': [],
      });
      final draft = CaptureDraft(
        id: 'd1',
        task: Task(title: 'Comprar pan', priority: 1),
      );
      final ready = session.copyWith(
        status: 'ready',
        transcript: 'Compra pan y borra el dentista',
        drafts: [draft],
        commands: [delete],
      );
      await store.update(ready);
      // The deletion still waits: the capture stays.
      final first = await store.saveReady(session.id, owner, {'d1'});
      expect(first.status, 'ready');
      expect(first.commands.single.pending, isTrue);
      await store.update(
        first.copyWith(commands: [delete.copyWith(done: true)]),
      );
      final done = await store.saveReady(session.id, owner, {});
      expect(done.status, 'saved');
      expect(done.terminal, isTrue);
      // Kept without the words, as any finished capture.
      expect(done.commands, isEmpty);

      final only = await store.create(owner, 'Europe/Madrid', text: 'Borra');
      final before = only.copyWith(
        status: 'ready',
        transcript: 'Borra la tarea del dentista',
        commands: [delete],
      );
      await store.update(before.copyWith(commands: [delete.copyWith(done: true)]));
      final finished = await store.saveReady(only.id, owner, {});
      expect(finished.status, 'saved');
      final back = await store.undoSave(before, {});
      expect(back, isNotNull);
      expect(back!.status, 'ready');
      expect(back.commands.single.pending, isTrue);
      expect(back.transcript, 'Borra la tarea del dentista');
      expect((await store.read(only.id, owner))!.commands.single.pending, isTrue);
      expect(
        CaptureStore.isEmpty(
          CaptureSession(
            id: 'x',
            ownerKey: owner,
            capturedAt: DateTime.utc(2026),
            timezone: 'UTC',
            commands: [delete],
          ),
        ),
        isFalse,
      );
    });

    test('a project made moments ago is taken back from the phone, or from '
        'the server once it has it, and only while it holds no task',
        () async {
      final api = _ListsApi();
      addTearDown(api.close);
      final lists = TaskListStore(database, owner);
      final fresh = TaskListInfo(name: 'Física');
      await lists.create(fresh);
      final id = await database.insertTask(
        Task(title: 'Estudiar', priority: 1, listId: fresh.id),
        ownerKey: owner,
      );
      // It holds a task: it stays.
      expect(await lists.takeBack(fresh.id, api: api, accountId: 1), isFalse);
      await database.deleteTask(id, ownerKey: owner);
      expect(await lists.takeBack(fresh.id, api: api, accountId: 1), isTrue);
      expect((await lists.all()).where((l) => l.id == fresh.id), isEmpty);
      expect(api.deletes, isEmpty);
      // The undone task went with it.
      final rows = await (await database.database).query(
        'tasks',
        where: 'listId = ?',
        whereArgs: [fresh.id],
      );
      expect(rows, isEmpty);

      final synced = TaskListInfo(name: 'Química');
      await lists.create(synced);
      await (await database.database).update(
        'task_lists',
        {'remote_version': 3, 'sync_pending': 0},
        where: 'id = ?',
        whereArgs: [synced.id],
      );
      // Without a way to tell the server, it stays.
      expect(await lists.takeBack(synced.id), isFalse);
      expect(await lists.takeBack(synced.id, api: api, accountId: 1), isTrue);
      expect(api.deletes, [('lists/${synced.id}/', 3)]);
      expect((await lists.all()).where((l) => l.id == synced.id), isEmpty);
    });
  });

  group('asking the server', () {
    sqfliteFfiInit();
    late Directory directory;
    late TaskDatabase database;
    late CaptureStore store;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('taskflow-ask-');
      final sql = await databaseFactoryFfi.openDatabase(
        p.join(directory.path, 'test.db'),
      );
      await sql.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
      );
      await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
      database = TaskDatabase.forTesting(sql);
      store = CaptureStore(database, directory: directory);
    });

    tearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    /// The server, answering every request with [answer].
    ({ApiClient api, List<http.Request> sent}) server(
      Map<String, dynamic> answer,
    ) {
      final sent = <http.Request>[];
      final api = ApiClient(
        url: 'http://phone.test',
        transport: MockClient((request) async {
          sent.add(request);
          return http.Response.bytes(utf8.encode(jsonEncode(answer)), 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      addTearDown(api.close);
      return (api: api, sent: sent);
    }

    test('typed words ask for commands, and an answer of only commands is a '
        'result', () async {
      final (:api, :sent) = server({
        'transcript': 'Borra la tarea del dentista',
        'tasks': [],
        'commands': [
          {
            'kind': 'delete',
            'target': {'words': ['dentista']},
            'issues': [],
          },
          {'kind': 'invite', 'email': 'ana@example.invalid'},
        ],
      });
      final session = await store.create(
        'local',
        'Europe/Madrid',
        text: 'Borra la tarea del dentista',
        source: 'typed',
      );
      final result = await CaptureProcessor(store, api).process(session);
      expect(sent.single.url.path, '/api/ai/drafts/');
      expect(jsonDecode(sent.single.body)['commands'], isTrue);
      expect(result.status, 'ready');
      expect(result.drafts, isEmpty);
      // The kind this app doesn't know is left out.
      expect(result.commands.single.kind, CommandKind.delete);
      expect(result.hasResult, isTrue);
      final kept = (await store.read(session.id, 'local'))!;
      expect(kept.commands.single.target.words, ['dentista']);
      // Opened again, the result shows without asking the server again.
      final again = await CaptureProcessor(store, api).process(kept);
      expect(again.commands, hasLength(1));
      expect(sent, hasLength(1));
    });

    test('a recording asks for commands as a form field', () async {
      final (:api, :sent) = server({
        'transcript': 'Comprar pan',
        'tasks': [serverTask('Comprar pan')],
        'commands': [],
      });
      final session = await store.create(
        'local',
        'Europe/Madrid',
        audio: true,
        source: 'speech',
      );
      await File(session.audioPath!).writeAsBytes(_wav());
      final result = await CaptureProcessor(store, api).process(session);
      final body = utf8.decode(sent.single.bodyBytes, allowMalformed: true);
      expect(
        RegExp(r'name="commands"\r\n\r\ntrue\r\n').hasMatch(body),
        isTrue,
      );
      expect(result.drafts.single.task.title, 'Comprar pan');
      expect(result.commands, isEmpty);
    });

    test('an older server’s answer, without commands, is today’s', () async {
      final (:api, sent: _) = server({
        'transcript': 'Comprar pan',
        'tasks': [
          {
            'title': 'Comprar pan',
            'due_date': null,
            'scheduled_date': '2026-10-19',
            'priority': 1,
            'notes': '',
            'questions': [],
          },
        ],
      });
      final session = await store.create(
        'local',
        'Europe/Madrid',
        text: 'Comprar pan mañana',
        source: 'typed',
      );
      final result = await CaptureProcessor(store, api).process(session);
      expect(result.commands, isEmpty);
      expect(result.drafts.single.task.dueDate, DateTime(2026, 10, 19));
      expect(result.drafts.single.newProject, isNull);
      expect(result.toJson().containsKey('commands'), isFalse);
    });

    test('an answer with neither a task nor a command keeps the words',
        () async {
      final (:api, sent: _) = server({
        'transcript': 'Hmm',
        'tasks': [],
        'commands': [],
      });
      final session = await store.create(
        'local',
        'Europe/Madrid',
        text: 'Hmm',
        source: 'typed',
      );
      await expectLater(
        CaptureProcessor(store, api).process(session),
        throwsA(
          predicate((error) => CaptureProblem.from(error!) == CaptureProblem.noTasks),
        ),
      );
      final kept = (await store.read(session.id, 'local'))!;
      expect(kept.status, 'failed');
      expect(kept.text, 'Hmm');
    });
  });
}

/// The server's project deletion, recorded.
class _ListsApi extends ApiClient {
  _ListsApi() : super(url: 'http://phone.test');
  final deletes = <(String, int?)>[];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    if (method == 'DELETE') {
      deletes.add((path, data?['version'] as int?));
      return null;
    }
    throw ApiException(0, 'Offline.');
  }
}

/// A short silent PCM WAV, as the recorder writes it.
Uint8List _wav() {
  final bytes = Uint8List(44 + 3200);
  final data = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, ascii.encode('RIFF'));
  data.setUint32(4, bytes.length - 8, Endian.little);
  bytes.setRange(8, 12, ascii.encode('WAVE'));
  bytes.setRange(12, 16, ascii.encode('fmt '));
  data
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, 16000, Endian.little)
    ..setUint32(28, 32000, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, ascii.encode('data'));
  data.setUint32(40, bytes.length - 44, Endian.little);
  return bytes;
}
