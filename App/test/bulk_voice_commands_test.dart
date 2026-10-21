// Bulk voice commands and marking a task done by voice: the app's half of
// Backend/docs/VOICE_COMMANDS.md («complete», «Bulk commands», decided by
// the owner on 2026-10-21). The answer's new shapes are parsed, the set is
// found on the phone's own copy, the card lists it before anything changes,
// and one Deshacer puts every task back.
import 'dart:async';
import 'dart:convert';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/main.dart';
import 'package:agenda/models/capture_command.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/occurrence_change.dart';
import 'package:agenda/models/occurrence_exception.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/models/task_schedule_change.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/repositories/task_repository.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/bulk_plan.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/command_plan.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/task_list_store.dart';
import 'package:agenda/services/task_matcher.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:agenda/widgets/task_schedule_label.dart';
import 'package:agenda/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:uuid/uuid.dart';

import 'support/capture_fixtures.dart';
import 'support/design_fixtures.dart';
import 'support/never_syncing_tasks.dart';

final es = lookupAppLocalizations(const Locale('es'));
final ca = lookupAppLocalizations(const Locale('ca'));
final en = lookupAppLocalizations(const Locale('en'));

/// [days] from today, at [hour]:[minute].
DateTime day(int days, [int hour = 0, int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days, hour, minute);
}

String key(DateTime date) => Task.dateKey(date);

CaptureCommand command(Map<String, dynamic> json) =>
    CaptureCommand.fromServer({'issues': [], ...json})!;

/// A set's target as the server sends it (`"all": true`): open tasks by
/// default; [from] alone is one day.
Map<String, dynamic> setTarget({
  DateTime? from,
  DateTime? to,
  String status = 'open',
  String? listId,
  int? personId,
  bool undated = false,
  List<String> words = const [],
}) => {
  'all': true,
  'words': words,
  'list_id': listId,
  'project_name': null,
  'person_id': personId,
  'person_name': null,
  'status': status,
  'from': from == null ? null : key(from),
  'to': from == null ? null : key(to ?? from),
  'undated': undated,
  'date': null,
};

/// Me (1), Paul who can edit (3) and Vera who only views (4).
final team = TaskListInfo(
  id: 'team',
  name: 'Equipo',
  shared: true,
  version: 2,
  people: const [
    ProjectMember(id: 1, name: 'Yo', role: 'owner'),
    ProjectMember(id: 3, name: 'Paul', role: 'editor'),
    ProjectMember(id: 4, name: 'Vera', role: 'viewer'),
  ],
);

/// A shared project the person can only view.
final club = TaskListInfo(
  id: 'club',
  name: 'Club',
  shared: true,
  role: 'viewer',
  version: 2,
  people: const [
    ProjectMember(id: 1, name: 'Yo', role: 'viewer'),
    ProjectMember(id: 3, name: 'Paul', role: 'owner'),
  ],
);

/// A project put away.
final old = TaskListInfo(id: 'old', name: 'Viejo', archived: true);

List<int?> ids(Iterable<Task> tasks) => tasks.map((task) => task.id).toList();

void main() {
  _parsing();
  _selection();
  _plans();
  _cards();
  _round20261021();
  _round20261021Second();
  _round20261021Third();
}

// ---------------------------------------------------------------- parsing

void _parsing() {
  group('the answer’s new shapes', () {
    test('«complete» is a command of its own, with a target as update’s', () {
      final done = command({
        'kind': 'complete',
        'target': {
          'words': ['médico'],
          'list_id': null,
          'project_name': null,
          'date': '2026-10-21',
        },
      });
      expect(done.kind, CommandKind.complete);
      expect(done.target.words, ['médico']);
      expect(done.target.date, DateTime(2026, 10, 21));
      expect(done.target.all, isFalse);
      expect(done.bulk, isFalse);
      expect(done.changes.isEmpty, isTrue);
      expect(done.pending, isTrue);
      // Kept with the capture as it came.
      final back = CaptureCommand.fromJson(
        jsonDecode(jsonEncode(done.toJson())),
      )!;
      expect(back.kind, CommandKind.complete);
      expect(back.target.words, ['médico']);
    });

    test('old answers parse exactly as before: no «all», no new keys', () {
      final update = command({
        'kind': 'update',
        'target': {
          'words': ['médico'],
          'list_id': null,
          'project_name': null,
          'date': '2026-10-21',
        },
        'changes': {'date': '2026-10-25'},
      });
      expect(update.target.all, isFalse);
      expect(update.bulk, isFalse);
      expect(update.target.toJson().keys, {
        'words',
        'list_id',
        'project_name',
        'date',
      });
      expect(update.changes.shiftDays, isNull);
      expect(update.changes.values.keys, ['date']);
      // A capture kept by this version writes no key for unticked tasks.
      expect(update.toJson().containsKey('excluded'), isFalse);
      final delete = command({
        'kind': 'delete',
        'target': {
          'words': ['dentista'],
        },
      });
      expect(delete.bulk, isFalse);
      expect(delete.target.status, 'open');
      // Kinds this app doesn't know are still left out.
      expect(CaptureCommand.fromServer({'kind': 'done', 'issues': []}), isNull);
    });

    test('a set: «all» with find’s filters, open by default, the period in '
        'order', () {
      final move = command({
        'kind': 'update',
        'target': {
          'all': true,
          'words': [],
          'list_id': 'team',
          'project_name': null,
          'person_id': 3,
          'person_name': null,
          'status': 'whatever',
          'from': '2026-10-25',
          'to': '2026-10-19',
          'undated': false,
          'date': null,
        },
        'changes': {'shift_days': 7},
      });
      final target = move.target;
      expect(move.bulk, isTrue);
      expect(target.all, isTrue);
      expect(target.listId, 'team');
      expect(target.personId, 3);
      expect(target.status, 'open');
      expect(target.from, DateTime(2026, 10, 19));
      expect(target.to, DateTime(2026, 10, 25));
      expect(move.changes.shiftDays, 7);
      for (final status in ['completed', 'any', 'open']) {
        expect(
          CommandTarget.fromJson({'all': true, 'status': status}).status,
          status,
        );
      }
      // Only tasks with no day: no period.
      final undated = CommandTarget.fromJson({
        'all': true,
        'undated': true,
        'from': '2026-10-19',
        'to': '2026-10-19',
      });
      expect(undated.undated, isTrue);
      expect(undated.from, isNull);
      // A day said for the set in the wrong place is its period.
      final day = CommandTarget.fromJson({'all': true, 'date': '2026-10-20'});
      expect(day.from, DateTime(2026, 10, 20));
      expect(day.to, DateTime(2026, 10, 20));
      expect(day.date, isNull);
      // An unresolved person searches nothing; the card says so.
      expect(
        CommandTarget.fromJson({'all': true, 'person_name': 'Pol'}).personName,
        'Pol',
      );
      // Kept with the capture, with the tasks unticked on its card.
      final kept = CaptureCommand.fromJson(
        jsonDecode(
          jsonEncode(move.copyWith(excluded: ['12', '7@2026-10-20']).toJson()),
        ),
      )!;
      expect(kept.bulk, isTrue);
      expect(kept.target.listId, 'team');
      expect(kept.target.personId, 3);
      expect(kept.target.from, DateTime(2026, 10, 19));
      expect(kept.target.to, DateTime(2026, 10, 25));
      expect(kept.changes.shiftDays, 7);
      expect(kept.excluded, ['12', '7@2026-10-20']);
      // Delete and complete take sets too; a set never takes a title or
      // notes.
      expect(command({'kind': 'delete', 'target': setTarget()}).bulk, isTrue);
      expect(command({'kind': 'complete', 'target': setTarget()}).bulk, isTrue);
      final titled = command({
        'kind': 'update',
        'target': setTarget(),
        'changes': {'title': 'Otra', 'notes_append': 'Más', 'priority': 3},
      });
      expect(titled.changes.values.keys, ['priority']);
      final single = command({
        'kind': 'update',
        'target': {
          'words': ['x'],
        },
        'changes': {'title': 'Otra', 'notes_append': 'Más'},
      });
      expect(single.changes.title, 'Otra');
      expect(single.changes.notesAppend, 'Más');
    });

    test('shift_days: a whole number of days either way, never 0, at most a '
        'year; a day said wins', () {
      int? shift(Map<String, dynamic> changes) =>
          TaskChanges.fromJson(changes).shiftDays;
      expect(shift({'shift_days': 7}), 7);
      expect(shift({'shift_days': -1}), -1);
      expect(shift({'shift_days': 366}), 366);
      expect(shift({'shift_days': 0}), isNull);
      expect(shift({'shift_days': 400}), isNull);
      expect(shift({'shift_days': '7'}), isNull);
      expect(shift({'shift_days': 7, 'date': '2026-10-25'}), isNull);
      expect(shift({'shift_days': 7, 'date': null}), isNull);
      final both = TaskChanges.fromJson({
        'shift_days': 7,
        'date': '2026-10-25',
      });
      expect(both.date, DateTime(2026, 10, 25));
      // Kept as it came.
      expect(
        TaskChanges.fromJson(
          jsonDecode(
            jsonEncode(TaskChanges.fromJson({'shift_days': -2}).toJson()),
          ),
        ).shiftDays,
        -2,
      );
    });
  });
}

// -------------------------------------------------------------- selection

/// The phone's tasks for the selection rules, around yesterday.
List<Task> _fixtures() => [
  Task(id: 1, title: 'Mía de ayer', priority: 1, dueDate: day(-1, 10)),
  Task(
    id: 2,
    title: 'Mía de ayer hecha',
    priority: 1,
    dueDate: day(-1, 9),
    isCompleted: true,
  ),
  Task(
    id: 3,
    title: 'Del equipo para mí',
    priority: 1,
    dueDate: day(-1, 12),
    listId: 'team',
    assignment: 'member',
    assigneeId: 1,
    assigneeName: 'Yo',
  ),
  Task(
    id: 4,
    title: 'Del equipo para Paul',
    priority: 1,
    dueDate: day(-1, 13),
    listId: 'team',
    assignment: 'member',
    assigneeId: 3,
    assigneeName: 'Paul',
  ),
  Task(
    id: 5,
    title: 'Del equipo para todos',
    priority: 1,
    dueDate: day(-1),
    hasTime: false,
    listId: 'team',
    assignment: 'group',
  ),
  Task(
    id: 6,
    title: 'Del club',
    priority: 1,
    dueDate: day(-1, 18),
    listId: 'club',
    assignment: 'member',
    assigneeId: 1,
    assigneeName: 'Yo',
  ),
  Task(
    id: 7,
    title: 'Solo con fecha límite',
    priority: 1,
    deadline: day(-1),
    reminderAnchor: 'deadline',
  ),
  Task(id: 8, title: 'Sin fecha', priority: 1),
  Task(
    id: 9,
    title: 'Cada día',
    priority: 1,
    dueDate: day(-10, 8),
    recurrence: 'daily',
  ),
  Task(id: 10, title: 'Una nota de ayer', kind: 'note', priority: 1),
  Task(
    id: 11,
    title: 'Del proyecto guardado',
    priority: 1,
    dueDate: day(-1, 11),
    listId: 'old',
  ),
  Task(id: 12, title: 'Mía de mañana', priority: 1, dueDate: day(1, 9)),
];

final _projects = [team, club, old];

({List<Task> tasks, int repeating, List<Task> repeatingTasks, Task? viewOnly})
_set(
  Map<String, dynamic> target, {
  bool completing = false,
  List<Task>? tasks,
}) => TaskMatcher.bulk(
  tasks ?? _fixtures(),
  CommandTarget.fromJson(target),
  accountId: 1,
  projects: _projects,
  completing: completing,
);

void _selection() {
  group('which tasks a set holds (the phone’s own copy)', () {
    test('by default: the person’s own and those assigned to them in shared '
        'projects; never notes; repeating tasks left out and counted', () {
      final found = _set(setTarget(from: day(-1)));
      expect(ids(found.tasks), [7, 1, 3]);
      expect(found.repeating, 1);
      // Assigned to them in a project they only view: not theirs to change.
      expect(ids(found.tasks), isNot(contains(6)));
      expect(found.viewOnly?.id, 6);
    });

    test('other people’s tasks only with their project or their name', () {
      expect(ids(_set(setTarget(from: day(-1), listId: 'team')).tasks), [
        5,
        3,
        4,
      ]);
      expect(ids(_set(setTarget(from: day(-1), personId: 3)).tasks), [4]);
      // «Las mías» is the person’s own set.
      expect(ids(_set(setTarget(from: day(-1), personId: 1)).tasks), [7, 1, 3]);
      expect(
        ids(_set(setTarget(from: day(-1), listId: 'team', personId: 3)).tasks),
        [4],
      );
    });

    test('only what the person can edit: a project they only view gives '
        'nothing, and says which task', () {
      final viewing = _set(setTarget(from: day(-1), listId: 'club'));
      expect(viewing.tasks, isEmpty);
      expect(viewing.viewOnly?.id, 6);
    });

    test('a project put away only when it is the one named', () {
      expect(ids(_set(setTarget(from: day(-1))).tasks), isNot(contains(11)));
      expect(ids(_set(setTarget(from: day(-1), listId: 'old')).tasks), [11]);
    });

    test('the status: open by default, or completed, or any', () {
      expect(ids(_set(setTarget(from: day(-1), status: 'completed')).tasks), [
        2,
      ]);
      expect(ids(_set(setTarget(from: day(-1), status: 'any')).tasks), [
        7,
        2,
        1,
        3,
      ]);
    });

    test('the period on the planned day, else the deadline’s; tasks with no '
        'day; no period at all', () {
      expect(ids(_set(setTarget(from: day(1))).tasks), [12]);
      expect(ids(_set(setTarget(from: day(-1), to: day(1))).tasks), [
        7,
        1,
        3,
        12,
      ]);
      expect(ids(_set(setTarget(undated: true)).tasks), [8]);
      // Soonest first, as Calendar lists the days; no day last.
      expect(ids(_set(setTarget()).tasks), [7, 1, 3, 12, 8]);
      // «Lo atrasado»: up to yesterday.
      expect(
        ids(_set({...setTarget(), 'from': null, 'to': key(day(-1))}).tasks),
        [7, 1, 3],
      );
    });

    test('marking done over one day takes each repeating task’s repetition '
        'that day; over longer, it is left out', () {
      final today = _set(setTarget(from: day(-1)), completing: true);
      expect(ids(today.tasks), [7, 9, 1, 3]);
      final repetition = today.tasks.firstWhere((task) => task.id == 9);
      expect(repetition.occurrenceId, key(day(-1)));
      expect(today.repeating, 0);
      final week = _set(
        setTarget(from: day(-2), to: day(-1)),
        completing: true,
      );
      expect(ids(week.tasks), isNot(contains(9)));
      expect(week.repeating, 1);
    });

    test('words as a search keeps them; a project or person not found holds '
        'nothing', () {
      expect(ids(_set(setTarget(from: day(-1), words: ['equipo'])).tasks), [3]);
      expect(
        _set({...setTarget(from: day(-1)), 'project_name': 'Geografía'}).tasks,
        isEmpty,
      );
      expect(
        _set({...setTarget(from: day(-1)), 'person_name': 'Pol'}).tasks,
        isEmpty,
      );
    });
  });
}

// ------------------------------------------------------------------ plans

BulkPlan _plan(Map<String, dynamic> json, {List<Task>? tasks}) => planBulk(
  command(json),
  tasks: tasks ?? _fixtures(),
  projects: _projects,
  accountId: 1,
);

void _plans() {
  group('what a set’s change would do', () {
    test('assigning reaches only shared projects where the person can edit; '
        'the others are left as they are, and counted', () {
      final paul = _plan({
        'kind': 'update',
        'target': setTarget(from: day(-1)),
        'changes': {'assignee_id': 3, 'assignee_name': 'Paul'},
      });
      expect(paul.action, BulkAction.assign);
      expect(ids(paul.items.map((item) => item.stored)), [3]);
      expect(paul.items.single.plan!.assignee, (
        assignment: 'member',
        id: 3,
        name: 'Paul',
      ));
      expect(paul.unassignable, 2);
      expect(paul.repeating, 1);
      expect(paul.count, 1);
      // Vera only views the project: nobody can be given to her.
      final vera = _plan({
        'kind': 'update',
        'target': setTarget(from: day(-1)),
        'changes': {'assignee_id': 4, 'assignee_name': 'Vera'},
      });
      expect(vera.items, isEmpty);
      expect(vera.unassignable, 3);
      // A name not found is said once, on the card, not counted per task.
      final pol = _plan({
        'kind': 'update',
        'target': setTarget(from: day(-1)),
        'changes': {'assignee_name': 'Pol'},
        'issues': ['member_not_available'],
      });
      expect(pol.items, isEmpty);
      expect(pol.unassignable, 0);
    });

    test('moving by days keeps each time; a task with only a deadline moves '
        'its deadline; one with no day stays, and is counted', () {
      final week = _plan({
        'kind': 'update',
        'target': setTarget(),
        'changes': {'shift_days': 7},
      });
      expect(week.action, BulkAction.shift);
      final byId = {for (final item in week.items) item.stored.id: item};
      expect(byId[1]!.plan!.after().dueDate, day(6, 10));
      expect(byId[3]!.plan!.after().dueDate, day(6, 12));
      final due = byId[7]!.plan!.after();
      expect(due.deadline, day(6));
      expect(due.dueDate, isNull);
      expect(byId.containsKey(8), isFalse);
      expect(week.noDay, 1);
      expect(
        week.movesOnly(
          command({
            'kind': 'update',
            'target': setTarget(),
            'changes': {'shift_days': 7},
          }).changes,
        ),
        isTrue,
      );
    });

    test('a time for tasks with no day leaves them out, counted; what is '
        'already as asked isn’t listed', () {
      final evening = _plan({
        'kind': 'update',
        'target': setTarget(),
        'changes': {'time': '18:00'},
      });
      expect(evening.action, BulkAction.change);
      // No planned day: the one with nothing, and the one with only a
      // deadline, as a single change would ask which day.
      expect(ids(evening.items.map((item) => item.stored)), [1, 3, 12]);
      expect(evening.noDay, 2);
      expect(evening.items.first.plan!.after().dueDate, day(-1, 18));
      final urgent = _plan(
        {
          'kind': 'update',
          'target': setTarget(from: day(-1)),
          'changes': {'priority': 3},
        },
        tasks: [
          Task(id: 1, title: 'Ya urgente', priority: 3, dueDate: day(-1, 9)),
          Task(id: 2, title: 'Aún no', priority: 1, dueDate: day(-1, 10)),
        ],
      );
      expect(ids(urgent.items.map((item) => item.stored)), [2]);
      expect(urgent.matched, 2);
    });

    test('a day for the set moves each task there, keeping its time', () {
      final tomorrow = _plan({
        'kind': 'update',
        'target': setTarget(from: day(-1)),
        'changes': {'date': key(day(1))},
      });
      expect(tomorrow.action, BulkAction.move);
      final byId = {
        for (final item in tomorrow.items) item.stored.id: item.plan!.after(),
      };
      expect(byId[1]!.dueDate, day(1, 10));
      expect(byId[3]!.dueDate, day(1, 12));
      // As for one task: it gets that day, and keeps its deadline.
      expect(byId[7]!.dueDate, day(1));
      expect(byId[7]!.deadline, day(-1));
    });

    test('marking done lists only what is still to do; deleting lists all; '
        'unticked tasks are left out of the count', () {
      final done = _plan({
        'kind': 'complete',
        'target': setTarget(from: day(-1), status: 'any'),
      });
      expect(done.action, BulkAction.complete);
      expect(ids(done.items.map((item) => item.stored)), isNot(contains(2)));
      final gone = _plan({
        'kind': 'delete',
        'target': setTarget(from: day(-1), status: 'any'),
      });
      expect(gone.action, BulkAction.delete);
      expect(ids(gone.items.map((item) => item.stored)), [7, 2, 1, 3]);
      final unticked = _plan({
        'kind': 'delete',
        'target': setTarget(from: day(-1)),
        'excluded': ['1'],
      });
      // `excluded` is the card's own state, not the server's.
      expect(unticked.count, 3);
      final kept = planBulk(
        command({
          'kind': 'delete',
          'target': setTarget(from: day(-1)),
        }).copyWith(excluded: ['1']),
        tasks: _fixtures(),
        projects: _projects,
        accountId: 1,
      );
      expect(kept.count, 2);
      expect(ids(kept.selected.map((item) => item.stored)), [7, 3]);
    });

    test('nothing said to change: the set is only shown, as a search', () {
      final shown = _plan({
        'kind': 'update',
        'target': setTarget(from: day(-1)),
        'changes': {},
      });
      expect(shown.items, isEmpty);
      expect(shown.count, 0);
      expect(ids(shown.unasked), [7, 1, 3]);
    });

    test('more than 200: nothing listed', () {
      final many = [
        for (var i = 0; i < 201; i++)
          Task(id: i + 1, title: 'Tarea $i', priority: 1, dueDate: day(-1, 9)),
      ];
      final plan = _plan({
        'kind': 'delete',
        'target': setTarget(from: day(-1)),
      }, tasks: many);
      expect(plan.tooMany, isTrue);
      expect(plan.matched, 201);
      expect(plan.items, isEmpty);
      expect(plan.count, 0);
      final just = _plan({
        'kind': 'delete',
        'target': setTarget(from: day(-1)),
      }, tasks: many.take(200).toList());
      expect(just.tooMany, isFalse);
      expect(just.count, 200);
    });
  });

  group('shift_days on one task', () {
    TaskChanges shift(int days) => TaskChanges.fromJson({'shift_days': days});

    test('its day moves, keeping the time; before → after as for a day', () {
      final doctor = Task(
        id: 1,
        title: 'Ir al médico',
        priority: 1,
        dueDate: DateTime(2026, 10, 21, 10),
      );
      final plan = planUpdate(task: doctor, shown: doctor, changes: shift(2));
      expect(plan.schedule, (date: DateTime(2026, 10, 23, 10), hasTime: true));
      expect(plan.ready, isTrue);
      expect(
        planUpdate(task: doctor, shown: doctor, changes: shift(-1)).schedule,
        (date: DateTime(2026, 10, 20, 10), hasTime: true),
      );
    });

    test('a task with only a deadline moves its deadline; one with neither '
        'has nothing to move', () {
      final due = Task(
        id: 2,
        title: 'Entregar',
        priority: 1,
        deadline: DateTime(2026, 11, 8, 17),
        deadlineHasTime: true,
        reminderAnchor: 'deadline',
      );
      final plan = planUpdate(task: due, shown: due, changes: shift(1));
      expect(plan.schedule, isNull);
      expect(plan.deadline, (date: DateTime(2026, 11, 9, 17), hasTime: true));
      final undated = Task(id: 3, title: 'Gafas', priority: 1);
      final none = planUpdate(task: undated, shown: undated, changes: shift(1));
      expect(none.isEmpty, isTrue);
      expect(none.noDay, isTrue);
    });

    test('a repeating task’s repetition moves from its own day', () {
      final weekly = Task(
        id: 9,
        title: 'Yoga',
        priority: 1,
        dueDate: DateTime(2026, 10, 5, 19),
        recurrence: 'weekly',
      );
      final shown = weekly.occurrenceOn(DateTime(2026, 10, 26))!;
      final plan = planUpdate(task: weekly, shown: shown, changes: shift(2));
      expect(plan.schedule, (date: DateTime(2026, 10, 28, 19), hasTime: true));
      expect(plan.repeating, isTrue);
    });
  });
}

// ------------------------------------------------------------------ cards

/// The app on Calendar in [language], with tasks, projects and captures in
/// memory; account 1.
class _App {
  _App(this.container, this.store, this.tasks);
  final ProviderContainer container;
  final _Captures store;
  final _Tasks tasks;

  static Future<_App> open(
    WidgetTester tester, {
    List<Task> tasks = const [],
    List<TaskListInfo> projects = const [],
    String language = 'es',
    double textScale = 1,
    Size size = const Size(390, 844),
    // A signed-in account's tasks on the phone: the app's own notifier reads
    // and writes them, and syncs behind.
    TaskRepository? repository,
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
    const timeout = MethodChannel('taskflow/accessibility');
    messenger.setMockMethodCallHandler(timeout, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(timeout, null));
    final memory = _Tasks(tasks);
    final store = _Captures(memory);
    final lists = _Lists(projects);
    final api = OfflineApiClient();
    final container = ProviderContainer(
      overrides: [
        ...captureSheetOverrides(),
        invitationLinkProvider.overrideWith(
          (ref) => InvitationLinks(listen: false),
        ),
        hasProProvider.overrideWithValue(true),
        billingLoadingProvider.overrideWithValue(false),
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) => SignedInFixtureAuth(api)),
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
        taskRepositoryProvider.overrideWithValue(repository ?? MemoryTasks()),
        taskProvider.overrideWith(
          (ref) => repository == null ? memory : TaskNotifier(repository),
        ),
        themeStoreProvider.overrideWithValue(MemoryThemeStore()),
        captureStoreProvider.overrideWithValue(store),
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
    return _App(container, store, memory);
  }

  /// Opens the capture sheet on a result of [commands], as resuming one does.
  Future<void> showResult(
    WidgetTester tester,
    List<CaptureCommand> commands, {
    String transcript = 'Lo que dije',
    List<CaptureDraft> drafts = const [],
  }) async {
    final session = CaptureSession(
      id: const Uuid().v4(),
      ownerKey: container.read(captureOwnerProvider),
      timezone: 'Europe/Madrid',
      capturedAt: DateTime.now().toUtc(),
      status: 'ready',
      source: 'speech',
      transcript: transcript,
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
}

/// Tasks in memory; a repetition moves as the app's own does.
class _Tasks extends DesignTaskNotifier {
  _Tasks(this.initial);
  final List<Task> initial;
  int _next = 100;

  Task? byId(int id) =>
      state.requireValue.where((task) => task.id == id).firstOrNull;

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
}

class _Lists extends TaskListStore {
  _Lists(List<TaskListInfo> projects)
    : projects = [...projects],
      super(TaskDatabase(), 'test');
  final List<TaskListInfo> projects;

  @override
  Future<List<TaskListInfo>> all() async => [...projects];
}

/// Every capture in memory, by id, saved and undone as the real store does.
class _Captures extends CaptureStore {
  _Captures(this.tasks) : super(TaskDatabase());
  final _Tasks tasks;
  final sessions = <String, CaptureSession>{};
  CaptureSession? current;

  /// The capture's write fails, as a full disk would.
  bool failSave = false;

  @override
  Future<void> update(CaptureSession value) async {
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
    if (failSave) throw StateError('The capture could not be written.');
    final session = sessions[id]!;
    final completed = session.commands.every((c) => !c.pending);
    return sessions[id] = current = session.copyWith(
      status: completed ? 'saved' : 'ready',
      commands: completed ? const [] : session.commands,
    );
  }

  @override
  Future<CaptureSession?> undoSave(
    CaptureSession before,
    Map<String, int> savedIds,
  ) async => sessions[before.id] = current = before.copyWith(status: 'ready');
}

/// The confirming button.
FilledButton _button(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const ValueKey('save-drafts')));

String _buttonLabel(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('save-drafts')),
        matching: find.byType(Text),
      ),
    )
    .data!;

String _headline(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('command-headline')).first)
    .data!;

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('save-drafts')));
  await tester.pumpAndSettle();
}

/// The weekday and day of the month, as the heading names tomorrow: joined
/// by a no-break space.
String _short(DateTime date, String language) =>
    DateFormat('E\u00A0d', language).format(date);

/// A day weekday first, as the app's messages name it in the app's locale
/// (`jue, 22 de oct`).
String _weekdayDate(WidgetTester tester, DateTime date) => DateFormat.MMMEd(
  Localizations.localeOf(
    tester.element(find.byType(Scaffold).first),
  ).toString(),
).format(date);

/// [finder] in the result's sheet: Calendar behind it lists tasks too.
Finder _inResult(Finder finder) =>
    find.descendant(of: find.byType(CaptureResult), matching: finder);

/// Yesterday's tasks: three to do, one done, and a daily one.
List<Task> _yesterday() => [
  Task(id: 1, title: 'Llamar al fontanero', priority: 1, dueDate: day(-1, 9)),
  Task(
    id: 2,
    title: 'Enviar el informe',
    priority: 2,
    dueDate: day(-1, 12),
    listId: 'team',
    assignment: 'member',
    assigneeId: 1,
    assigneeName: 'Yo',
  ),
  Task(
    id: 3,
    title: 'Comprar el regalo',
    priority: 1,
    dueDate: day(-1),
    hasTime: false,
  ),
  Task(
    id: 4,
    title: 'Reservar mesa',
    priority: 1,
    dueDate: day(-1, 20),
    isCompleted: true,
  ),
  Task(
    id: 5,
    title: 'Pasear al perro',
    priority: 1,
    dueDate: day(-10, 8),
    recurrence: 'daily',
  ),
];

void _cards() {
  group('the card of a set', () {
    testWidgets('moving to a day: the action and count, each task with its '
        'day, all ticked; unticking one changes the count; one tap moves '
        'them, keeping their times; Deshacer puts them back', (tester) async {
      final app = await _App.open(
        tester,
        tasks: _yesterday(),
        projects: [team],
      );
      await app.showResult(tester, [
        command({
          'kind': 'update',
          'target': setTarget(from: day(-1)),
          'changes': {'date': key(day(1))},
        }),
      ]);
      expect(
        _headline(tester),
        es.commandBulkMoveTo(3, 'tomorrow', _short(day(1), 'es')),
      );
      expect(
        es.commandBulkMoveTo(5, 'tomorrow', 'jue 22'),
        'Mover 5 tareas a mañana, jue 22',
      );
      for (final title in [
        'Llamar al fontanero',
        'Enviar el informe',
        'Comprar el regalo',
      ]) {
        expect(find.widgetWithText(CheckboxListTile, title), findsOneWidget);
      }
      // The one done, and the repeating one, aren't listed.
      expect(_inResult(find.text('Reservar mesa')), findsNothing);
      expect(_inResult(find.text('Pasear al perro')), findsNothing);
      expect(
        tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .every((tile) => tile.value == true),
        isTrue,
      );
      // One line for what was left out: a lone task by its title.
      expect(
        find.text(es.commandBulkLeftRepeating(1, 'change', 'Pasear al perro')),
        findsOne,
      );
      expect(
        es.commandBulkLeftRepeating(1, 'change', 'Pasear al perro'),
        'Pasear al perro se repite: no cambia',
      );
      expect(
        es.commandBulkLeftRepeating(2, 'change', ''),
        '2 tareas que se repiten no cambian',
      );
      expect(_buttonLabel(tester), es.commandBulkMove(3));
      // Nothing changes before the tap.
      expect(app.tasks.byId(1)!.dueDate, day(-1, 9));

      await tester.tap(_inResult(find.text('Comprar el regalo')));
      await tester.pumpAndSettle();
      expect(
        _headline(tester),
        es.commandBulkMoveTo(2, 'tomorrow', _short(day(1), 'es')),
      );
      expect(_buttonLabel(tester), 'Mover 2 tareas');
      expect(app.tasks.byId(3)!.dueDate, day(-1));

      await _confirm(tester);
      expect(app.tasks.byId(1)!.dueDate, day(1, 9));
      expect(app.tasks.byId(2)!.dueDate, day(1, 12));
      // Unticked: left as it was.
      expect(app.tasks.byId(3)!.dueDate, day(-1));
      expect(find.byType(CaptureResult), findsNothing);
      // All on one day: the message names it.
      expect(
        find.text(es.commandTasksMovedTo(2, _weekdayDate(tester, day(1)))),
        findsOneWidget,
      );
      expect(es.commandTasksMoved(5), '5 tareas movidas');

      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      expect(app.tasks.byId(1)!.dueDate, day(-1, 9));
      expect(app.tasks.byId(2)!.dueDate, day(-1, 12));
      // The result is back as it was, with the task still unticked.
      expect(_buttonLabel(tester), es.commandBulkMove(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('moving by days: «Mover 2 tareas una semana después»; each '
        'keeps its time, a task with only a deadline moves its deadline', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(id: 1, title: 'Gimnasio', priority: 1, dueDate: day(-1, 19)),
          Task(
            id: 2,
            title: 'Entregar el trabajo',
            priority: 1,
            deadline: day(-1),
            reminderAnchor: 'deadline',
          ),
        ],
      );
      await app.showResult(tester, [
        command({
          'kind': 'update',
          'target': setTarget(from: day(-1)),
          'changes': {'shift_days': 7},
        }),
      ]);
      expect(
        _headline(tester),
        es.commandBulkShift(2, es.commandBulkSpan(1, 'weeks'), 'later'),
      );
      expect(_headline(tester), 'Mover 2 tareas una semana después');
      expect(
        es.commandBulkShift(3, es.commandBulkSpan(2, 'days'), 'earlier'),
        'Mover 3 tareas 2 días antes',
      );
      await _confirm(tester);
      expect(app.tasks.byId(1)!.dueDate, day(6, 19));
      expect(app.tasks.byId(2)!.deadline, day(6));
      expect(app.tasks.byId(2)!.dueDate, isNull);
      // The deadline's new day is where that task lands: both on one day.
      expect(
        find.text(es.commandTasksMovedTo(2, _weekdayDate(tester, day(6)))),
        findsOneWidget,
      );
      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      expect(app.tasks.byId(1)!.dueDate, day(-1, 19));
      expect(app.tasks.byId(2)!.deadline, day(-1));
    });

    testWidgets('assigning: «Asignar 1 tarea a Paul», the tasks that can’t '
        'be his counted in one line; Deshacer gives them back', (tester) async {
      final app = await _App.open(
        tester,
        tasks: _yesterday(),
        projects: [team],
      );
      await app.showResult(tester, [
        command({
          'kind': 'update',
          'target': setTarget(from: day(-1)),
          'changes': {'assignee_id': 3, 'assignee_name': 'Paul'},
        }),
      ]);
      expect(_headline(tester), es.commandBulkAssignTo(1, 'Paul'));
      expect(_headline(tester), 'Asignar 1 tarea a Paul');
      expect(
        find.text(
          '${es.commandBulkLeftRepeating(1, 'change', 'Pasear al perro')} · '
          '${es.commandBulkLeftUnassignable(2, 'Paul', '')}',
        ),
        findsOneWidget,
      );
      expect(_buttonLabel(tester), es.commandBulkAssign(1));
      await _confirm(tester);
      final report = app.tasks.byId(2)!;
      expect(report.assignment, 'member');
      expect(report.assigneeId, 3);
      expect(app.tasks.byId(1)!.assignment, 'personal');
      expect(find.text(es.commandTasksAssignedTo(1, 'Paul')), findsOneWidget);
      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      expect(app.tasks.byId(2)!.assigneeId, 1);
    });

    testWidgets('another change: «Cambiar 2 tareas», with what it sets', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(id: 1, title: 'Gimnasio', priority: 1, dueDate: day(-1, 19)),
          Task(id: 2, title: 'Leer', priority: 1, dueDate: day(-1, 21)),
        ],
      );
      await app.showResult(tester, [
        command({
          'kind': 'update',
          'target': setTarget(from: day(-1)),
          'changes': {'priority': 3, 'time': '18:00'},
        }),
      ]);
      expect(_headline(tester), es.commandBulkChange(2));
      expect(
        find.text(
          '${es.commandBulkField(es.time, '18:00')} · '
          '${es.commandBulkField(es.priority, es.high)}',
        ),
        findsOneWidget,
      );
      await _confirm(tester);
      expect(app.tasks.byId(1)!.priority, 3);
      expect(app.tasks.byId(1)!.dueDate, day(-1, 18));
      expect(find.text(es.commandTasksChanged(2)), findsOneWidget);
    });

    testWidgets('marking done: «Marcar 3 tareas como hechas», a repeating '
        'task’s repetition that day among them; Deshacer reopens them', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: _yesterday(),
        projects: [team],
      );
      await app.showResult(tester, [
        command({'kind': 'complete', 'target': setTarget(from: day(-1))}),
      ]);
      expect(_headline(tester), es.commandBulkComplete(4));
      expect(_headline(tester), 'Marcar 4 tareas como hechas');
      expect(_inResult(find.text('Pasear al perro')), findsOneWidget);
      await tester.tap(_inResult(find.text('Enviar el informe')));
      await tester.pumpAndSettle();
      expect(_buttonLabel(tester), es.commandBulkComplete(3));
      await _confirm(tester);
      expect(app.tasks.byId(1)!.isCompleted, isTrue);
      expect(app.tasks.byId(3)!.isCompleted, isTrue);
      expect(app.tasks.byId(2)!.isCompleted, isFalse);
      // Only that day's repetition, as ticking it does.
      expect(app.tasks.byId(5)!.completedDates, [key(day(-1))]);
      expect(find.text(es.commandTasksCompleted(3)), findsOneWidget);
      expect(es.commandTasksCompleted(3), '3 tareas completadas');
      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      expect(app.tasks.byId(1)!.isCompleted, isFalse);
      expect(app.tasks.byId(3)!.isCompleted, isFalse);
      expect(app.tasks.byId(5)!.completedDates, isEmpty);
    });

    testWidgets('deleting: «Eliminar 2 tareas» in the delete style; nothing '
        'is deleted before the tap; Deshacer brings every one back', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(
            id: 1,
            title: 'Libros',
            priority: 1,
            dueDate: day(-8, 17),
            isCompleted: true,
            notes: 'En la mochila',
          ),
          Task(
            id: 2,
            title: 'Dentista',
            priority: 2,
            dueDate: day(-6),
            hasTime: false,
            isCompleted: true,
          ),
          Task(id: 3, title: 'Seguro', priority: 3, dueDate: day(-4, 11)),
        ],
      );
      await app.showResult(tester, [
        command({
          'kind': 'delete',
          'target': setTarget(from: day(-9), to: day(-3), status: 'completed'),
        }),
      ]);
      final colors = Theme.of(
        tester.element(find.byType(CaptureResult)),
      ).colorScheme;
      expect(_headline(tester), es.commandBulkDelete(2));
      expect(_headline(tester), 'Eliminar 2 tareas');
      expect(_buttonLabel(tester), 'Eliminar 2 tareas');
      expect(_button(tester).style?.backgroundColor?.resolve({}), colors.error);
      // The card has the delete edge, as one deletion's does.
      final frame = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('command-headline')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect((frame.shape! as RoundedRectangleBorder).side.color, colors.error);
      expect(app.tasks.byId(1), isNotNull);
      await _confirm(tester);
      expect(app.tasks.byId(1), isNull);
      expect(app.tasks.byId(2), isNull);
      // Not completed: not in the set.
      expect(app.tasks.byId(3), isNotNull);
      expect(find.text(es.commandTasksDeleted(2)), findsOneWidget);
      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      expect(app.tasks.byId(1)!.notes, 'En la mochila');
      expect(app.tasks.byId(2), isNotNull);
    });

    testWidgets('no match says what was looked for, with nothing to tap', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: [Task(id: 1, title: 'Mañana', priority: 1, dueDate: day(1, 9))],
        projects: [team],
      );
      await app.showResult(tester, [
        command({
          'kind': 'update',
          'target': setTarget(from: day(-1)),
          'changes': {'date': key(day(1))},
        }),
        command({
          'kind': 'delete',
          'target': setTarget(
            from: day(-1),
            listId: 'team',
            status: 'completed',
          ),
        }),
      ]);
      expect(
        find.text(
          es.commandBulkNone('open', es.commandBulkPeriod('yesterday', '', '')),
        ),
        findsOneWidget,
      );
      expect(find.text('No hay tareas pendientes de ayer'), findsOneWidget);
      expect(find.text('No hay tareas completadas de ayer'), findsOneWidget);
      expect(find.text(es.commandFindProject('Equipo')), findsOneWidget);
      expect(find.byKey(const ValueKey('save-drafts')), findsNothing);
      expect(find.text(es.captureClose), findsOneWidget);
      // Nothing to keep the words as a task for: it only closes.
      expect(
        find.byKey(const ValueKey('result-save-as-written')),
        findsNothing,
      );
      expect(app.tasks.byId(1)!.dueDate, day(1, 9));
    });

    testWidgets('more than 200: no list, say it with fewer', (tester) async {
      await _App.open(
        tester,
        tasks: [
          for (var i = 0; i < 230; i++)
            Task(
              id: i + 1,
              title: 'Tarea $i',
              priority: 1,
              dueDate: day(-1, 9),
            ),
        ],
      ).then(
        (app) => app.showResult(tester, [
          command({'kind': 'delete', 'target': setTarget(from: day(-1))}),
        ]),
      );
      expect(find.text(es.commandBulkTooMany(230)), findsOneWidget);
      expect(
        es.commandBulkTooMany(230),
        'Son 230 tareas, demasiadas. Vuelve a decirlo con un día o un proyecto.',
      );
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.byKey(const ValueKey('save-drafts')), findsNothing);
    });

    testWidgets('nothing said to change: the tasks as a search lists them, '
        'and only Cerrar', (tester) async {
      final app = await _App.open(tester, tasks: _yesterday());
      await app.showResult(tester, [
        command({
          'kind': 'update',
          'target': setTarget(from: day(-1)),
          'changes': {},
        }),
      ]);
      expect(_headline(tester), es.tasks);
      expect(find.byKey(const ValueKey('found-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('found-3')), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.byKey(const ValueKey('save-drafts')), findsNothing);
      expect(find.text(es.captureClose), findsOneWidget);
    });

    testWidgets('every task unticked: the button waits, with its count', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(id: 1, title: 'Gimnasio', priority: 1, dueDate: day(-1, 19)),
        ],
      );
      await app.showResult(tester, [
        command({'kind': 'delete', 'target': setTarget(from: day(-1))}),
      ]);
      await tester.tap(_inResult(find.text('Gimnasio')));
      await tester.pumpAndSettle();
      expect(_buttonLabel(tester), es.commandBulkDelete(0));
      expect(_button(tester).onPressed, isNull);
      await tester.tap(_inResult(find.text('Gimnasio')));
      await tester.pumpAndSettle();
      expect(_button(tester).onPressed, isNotNull);
    });

    for (final (language, strings) in [('es', es), ('ca', ca)]) {
      testWidgets('$language at 2× text: the card and its button fit', (
        tester,
      ) async {
        final app = await _App.open(
          tester,
          tasks: _yesterday(),
          projects: [team],
          language: language,
          textScale: 2,
        );
        await app.showResult(tester, [
          command({
            'kind': 'update',
            'target': setTarget(from: day(-1)),
            'changes': {'date': key(day(1))},
          }),
        ]);
        expect(
          _headline(tester),
          strings.commandBulkMoveTo(3, 'tomorrow', _short(day(1), language)),
        );
        expect(_buttonLabel(tester), strings.commandBulkMove(3));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('one task marked done', () {
    testWidgets('«Marcar como hecha», then «Completada: …» with Deshacer', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(id: 1, title: 'Ir al médico', priority: 1, dueDate: day(0, 10)),
          Task(id: 2, title: 'Comprar pan', priority: 1),
        ],
      );
      await app.showResult(tester, [
        command({
          'kind': 'complete',
          'target': {
            'words': ['médico'],
          },
        }),
      ]);
      expect(_headline(tester), 'Ir al médico');
      expect(_inResult(find.text('${es.today} · 10:00')), findsOneWidget);
      expect(_buttonLabel(tester), es.commandMarkDone);
      expect(es.commandMarkDone, 'Marcar como hecha');
      expect(app.tasks.byId(1)!.isCompleted, isFalse);
      await _confirm(tester);
      expect(app.tasks.byId(1)!.isCompleted, isTrue);
      expect(
        find.text(es.notificationCompleted('Ir al médico')),
        findsOneWidget,
      );
      expect(
        es.notificationCompleted('Ir al médico'),
        'Completada: Ir al médico',
      );
      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      expect(app.tasks.byId(1)!.isCompleted, isFalse);
    });

    testWidgets('a repeating task: today’s repetition, as ticking it does', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(
            id: 1,
            title: 'Clase de yoga',
            priority: 1,
            dueDate: day(-7, 19),
            recurrence: 'daily',
          ),
        ],
      );
      await app.showResult(tester, [
        command({
          'kind': 'complete',
          'target': {
            'words': ['yoga'],
          },
        }),
      ]);
      expect(_inResult(find.text('${es.today} · 19:00')), findsOneWidget);
      await _confirm(tester);
      expect(app.tasks.byId(1)!.completedDates, [key(day(0))]);
      expect(app.tasks.byId(1)!.isCompleted, isFalse);
      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      expect(app.tasks.byId(1)!.completedDates, isEmpty);
    });

    testWidgets('already done: «Ya estaba hecha», and nothing to tap', (
      tester,
    ) async {
      await _App.open(
        tester,
        tasks: [
          Task(
            id: 1,
            title: 'Ir al médico',
            priority: 1,
            dueDate: day(0, 10),
            isCompleted: true,
          ),
        ],
      ).then(
        (app) => app.showResult(tester, [
          command({
            'kind': 'complete',
            'target': {
              'words': ['médico'],
            },
          }),
        ]),
      );
      expect(find.text(es.commandAlreadyDone), findsOneWidget);
      expect(find.byKey(const ValueKey('save-drafts')), findsNothing);
    });

    testWidgets('✕ leaves it to do: «No se completará», with Deshacer', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(id: 1, title: 'Ir al médico', priority: 1, dueDate: day(0, 10)),
          Task(id: 2, title: 'Comprar pan', priority: 1, dueDate: day(0, 18)),
        ],
      );
      await app.showResult(tester, [
        command({
          'kind': 'complete',
          'target': {
            'words': ['médico'],
          },
        }),
        command({
          'kind': 'complete',
          'target': {
            'words': ['pan'],
          },
        }),
      ]);
      await tester.tap(find.byTooltip(es.commandDontComplete('Ir al médico')));
      await tester.pumpAndSettle();
      expect(find.text(es.commandWontComplete(1)), findsOneWidget);
      await _confirm(tester);
      expect(app.tasks.byId(1)!.isCompleted, isFalse);
      expect(app.tasks.byId(2)!.isCompleted, isTrue);
    });
  });

  group('one task moved by days', () {
    testWidgets('before → after, as for a day; one tap moves it', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(id: 1, title: 'Ir al médico', priority: 1, dueDate: day(3, 10)),
        ],
      );
      await app.showResult(tester, [
        command({
          'kind': 'update',
          'target': {
            'words': ['médico'],
          },
          'changes': {'shift_days': 2},
        }),
      ]);
      final context = tester.element(find.byType(CaptureResult));
      String weekday(DateTime date) => DateFormat.MMMEd(
        Localizations.localeOf(context).toString(),
      ).format(date);
      expect(
        find.text('${weekday(day(3))} · 10:00 → ${weekday(day(5))} · 10:00'),
        findsOneWidget,
      );
      expect(_buttonLabel(tester), es.reschedule);
      await _confirm(tester);
      expect(app.tasks.byId(1)!.dueDate, day(5, 10));
    });

    testWidgets('a task with no day: it says so, and nothing changes', (
      tester,
    ) async {
      await _App.open(
        tester,
        tasks: [Task(id: 1, title: 'Recoger las gafas', priority: 1)],
      ).then(
        (app) => app.showResult(tester, [
          command({
            'kind': 'update',
            'target': {
              'words': ['gafas'],
            },
            'changes': {'shift_days': 2},
          }),
        ]),
      );
      expect(find.text(es.commandNoDayStays), findsOneWidget);
      expect(find.text(es.commandNothingToChange), findsNothing);
      expect(find.byKey(const ValueKey('save-drafts')), findsNothing);
    });
  });

  group('the new words in all three languages', () {
    test('Catalan and English say the same', () {
      expect(
        ca.commandBulkMoveTo(5, 'tomorrow', 'dj. 22'),
        'Mou 5 tasques a demà, dj. 22',
      );
      expect(
        en.commandBulkMoveTo(5, 'tomorrow', 'Thu 22'),
        'Move 5 tasks to tomorrow, Thu 22',
      );
      expect(
        ca.commandBulkShift(3, ca.commandBulkSpan(1, 'weeks'), 'later'),
        'Mou 3 tasques una setmana més tard',
      );
      expect(
        en.commandBulkShift(3, en.commandBulkSpan(1, 'weeks'), 'later'),
        'Move 3 tasks a week later',
      );
      expect(ca.commandBulkDelete(6), 'Suprimeix 6 tasques');
      expect(en.commandBulkComplete(4), 'Mark 4 tasks as done');
      expect(
        ca.commandBulkNone('open', ca.commandBulkPeriod('yesterday', '', '')),
        'No hi ha tasques per fer d’ahir',
      );
      expect(
        en.commandBulkNone('open', en.commandBulkPeriod('yesterday', '', '')),
        'There are no tasks to do from yesterday',
      );
      expect(ca.commandTasksMoved(5), '5 tasques mogudes');
      expect(en.commandTasksMoved(1), 'Task moved');
      expect(
        ca.commandBulkLeftRepeating(2, 'change', ''),
        '2 tasques que es repeteixen no canvien',
      );
    });
  });
}

// ---- UX loop 2026-10-21-changes, round 1 ---------------------------------
//
// P224 (UX-1701, UX-1704, UX-1706, UX-1712, UX-1713): the set card's rows,
// what it leaves out, its heading's day, a deletion opening at its heading.
// P225 (UX-1708): two similar projects become chips. P226 (UX-1703, UX-1710,
// UX-1711): the message after the tap and where a completion lands. P227
// (UX-1707, UX-1714): Deshacer doesn't wait, and the result holds still
// while it closes. P228 (UX-1709): words that fit how many tasks.

/// [days] from today to the next [weekday] at least [min] days away.
int _ahead(int weekday, {int min = 2}) {
  final today = day(0);
  var days = (weekday - today.weekday + 7) % 7;
  while (days < min) {
    days += 7;
  }
  return days;
}

/// The app's own context, in its language and region.
BuildContext _appContext(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first);

/// A set row, by its task's title.
Finder _setRow(String title) =>
    _inResult(find.widgetWithText(CheckboxListTile, title));

/// The style a set row's title is drawn with.
TextStyle? _titleStyle(WidgetTester tester, String title) => tester
    .widget<RichText>(
      find.descendant(
        of: _setRow(title),
        matching: find.byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText() == title,
        ),
      ),
    )
    .text
    .style;

/// The set row of [title] says [line] under it.
void _expectRowLine(String title, String line) => expect(
  find.descendant(of: _setRow(title), matching: find.text(line)),
  findsOneWidget,
  reason: '«$title» reads «$line» under its title',
);

/// Calendar's row of [title], once the sheet is gone.
Finder _calendarRow(String title) => find.widgetWithText(TaskTile, title);

Color _litColor(WidgetTester tester) =>
    Theme.of(_appContext(tester)).colorScheme.primaryContainer;

/// The day Calendar shows, as its heading names it.
String _dayHeading(DateTime date, [String language = 'es']) =>
    DateFormat.MMMMEEEEd(language).format(date);

/// The result's own scroll view: the visible part of the sheet's cards.
Rect _resultView(WidgetTester tester) =>
    tester.getRect(_inResult(find.byType(SingleChildScrollView)).first);

void _expectInside(Rect outer, Rect inner, String what) {
  expect(
    inner.top,
    greaterThanOrEqualTo(outer.top - 0.5),
    reason: '$what $inner inside $outer',
  );
  expect(
    inner.bottom,
    lessThanOrEqualTo(outer.bottom + 0.5),
    reason: '$what $inner inside $outer',
  );
}

/// Lines [text] takes as the paragraph lays it out.
int _lines(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)).first,
  );
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    locale: paragraph.locale,
    strutStyle: paragraph.strutStyle,
    textWidthBasis: paragraph.textWidthBasis,
    textHeightBehavior: paragraph.textHeightBehavior,
  )..layout(maxWidth: paragraph.constraints.maxWidth);
  addTearDown(painter.dispose);
  return painter.computeLineMetrics().length;
}

/// Four open tasks yesterday, one in a personal project, and one done.
final _casa = TaskListInfo(id: 'casa', name: 'Casa', version: 2);
List<Task> _fourYesterday() => [
  Task(id: 1, title: 'Llamar al fontanero', priority: 1, dueDate: day(-1, 9)),
  Task(
    id: 2,
    title: 'Pintar la valla',
    priority: 2,
    dueDate: day(-1, 12),
    listId: 'casa',
  ),
  Task(
    id: 3,
    title: 'Comprar el regalo',
    priority: 1,
    dueDate: day(-1),
    hasTime: false,
  ),
  Task(
    id: 4,
    title: 'Pagar la factura del gas',
    priority: 2,
    dueDate: day(-1, 18),
  ),
  Task(
    id: 5,
    title: 'Reservar mesa',
    priority: 1,
    dueDate: day(-1, 20),
    isCompleted: true,
  ),
];

CaptureCommand _moveYesterdayToTomorrow() => command({
  'kind': 'update',
  'target': setTarget(from: day(-1)),
  'changes': {'date': key(day(1))},
});

/// Three tasks done last week (cards.bulk-delete).
List<Task> _doneLastWeek() => [
  Task(
    id: 80,
    title: 'Devolver los libros a la biblioteca',
    priority: 1,
    dueDate: day(-8, 17),
    isCompleted: true,
  ),
  Task(
    id: 81,
    title: 'Pedir cita en el dentista',
    priority: 2,
    dueDate: day(-6),
    hasTime: false,
    isCompleted: true,
  ),
  Task(
    id: 82,
    title: 'Renovar el seguro del coche',
    priority: 3,
    dueDate: day(-4, 11),
    isCompleted: true,
  ),
];

CaptureCommand _deleteDoneLastWeek() => command({
  'kind': 'delete',
  'target': setTarget(from: day(-9), to: day(-3), status: 'completed'),
});

/// Matemáticas, shared: the person (1) owns it, Paul (3) edits.
final _mathsShared = TaskListInfo(
  id: 'maths',
  name: 'Matemáticas',
  shared: true,
  version: 2,
  people: const [
    ProjectMember(id: 1, name: 'Yo', role: 'owner'),
    ProjectMember(id: 3, name: 'Paul', role: 'editor'),
  ],
);

/// «Asigna a Paul todo lo del viernes» (cards.bulk-left-out): two tasks in
/// the shared Matemáticas, assigned to the person; [personal] tasks of
/// their own that day; and the weekly «Natación».
List<Task> _friday({List<String> personal = const ['Llamar a la gestoría']}) {
  final friday = day(_ahead(DateTime.friday));
  DateTime at(int hour) =>
      DateTime(friday.year, friday.month, friday.day, hour);
  return [
    Task(
      id: 70,
      title: 'Preparar el examen del tema 6',
      priority: 2,
      dueDate: at(10),
      listId: 'maths',
      assignment: 'member',
      assigneeId: 1,
      assigneeName: 'Yo',
    ),
    Task(
      id: 71,
      title: 'Corregir las redacciones',
      priority: 1,
      dueDate: at(16),
      listId: 'maths',
      assignment: 'member',
      assigneeId: 1,
      assigneeName: 'Yo',
    ),
    for (final (index, title) in personal.indexed)
      Task(id: 72 + index, title: title, priority: 1, dueDate: at(9 + index)),
    Task(
      id: 79,
      title: 'Natación',
      priority: 1,
      dueDate: DateTime(friday.year, friday.month, friday.day - 7, 18),
      recurrence: 'weekly',
    ),
  ];
}

CaptureCommand _assignFridayToPaul() => command({
  'kind': 'update',
  'target': setTarget(from: day(_ahead(DateTime.friday))),
  'changes': {'assignee_id': 3, 'assignee_name': 'Paul'},
});

/// Matemáticas and Matemáticas II, both matched by «mates».
final _maths = TaskListInfo(id: 'maths', name: 'Matemáticas', version: 2);
final _mathsTwo = TaskListInfo(
  id: 'maths2',
  name: 'Matemáticas II',
  version: 2,
);
const _mathsCandidates = [
  {'id': 'maths', 'name': 'Matemáticas'},
  {'id': 'maths2', 'name': 'Matemáticas II'},
];

/// The chips under «¿Qué proyecto?», in the order shown.
List<ChoiceChip> _projectChips(WidgetTester tester) =>
    tester.widgetList<ChoiceChip>(_inResult(find.byType(ChoiceChip))).toList();

void _round20261021() {
  group('UX loop 2026-10-21-changes, round 1', () {
    setUpAll(() async {
      // Lines are counted with the app's own font.
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    });

    // ---------------------------------------------------- P224 · UX-1701
    testWidgets('UX-1701: a set of completed tasks to delete: each row reads '
        'its day and «Completada», its title struck through', (tester) async {
      final app = await _App.open(tester, tasks: _doneLastWeek());
      await app.showResult(tester, [
        _deleteDoneLastWeek(),
      ], transcript: 'Borra todas las completadas de la semana pasada');
      expect(_headline(tester), es.commandBulkDelete(3));
      final context = tester.element(find.byType(CaptureResult));
      for (final task in _doneLastWeek()) {
        _expectRowLine(
          task.title,
          '${taskDayLine(context, task)} · ${es.commandCompleted}',
        );
        expect(
          _titleStyle(tester, task.title)?.decoration,
          TextDecoration.lineThrough,
          reason: '«${task.title}» is struck through',
        );
      }
      // The library books: its day, 17:00, «Completada».
      final books = _doneLastWeek().first;
      expect(
        taskDayLine(context, books),
        endsWith(' · 17:00'),
        reason: 'the books’ day line has its time',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('UX-1701: assigning a shared project’s tasks: the row reads '
        'its day, «Matemáticas» and «Yo», with no «Completada» and no strike', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: _friday(personal: ['Llamar a la gestoría', 'Comprar fruta']),
        projects: [_mathsShared],
      );
      await app.showResult(tester, [
        _assignFridayToPaul(),
      ], transcript: 'Asigna a Paul todo lo del viernes');
      expect(_headline(tester), es.commandBulkAssignTo(2, 'Paul'));
      final context = tester.element(find.byType(CaptureResult));
      final exam = _friday().first;
      _expectRowLine(
        exam.title,
        '${taskDayLine(context, exam)} · Matemáticas · ${es.assignedToMe}',
      );
      expect(es.assignedToMe, 'Yo');
      expect(taskDayLine(context, exam), endsWith(' · 10:00'));
      expect(_inResult(find.textContaining(es.commandCompleted)), findsNothing);
      expect(
        _titleStyle(tester, exam.title)?.decoration,
        isNot(TextDecoration.lineThrough),
      );
    });

    testWidgets('UX-1701: a pending move set: no «Completada», no strike; a '
        'personal project’s task shows its project and no person; a task '
        'with no project only its day', (tester) async {
      final app = await _App.open(
        tester,
        tasks: _fourYesterday(),
        projects: [_casa],
      );
      await app.showResult(tester, [_moveYesterdayToTomorrow()]);
      expect(
        _headline(tester),
        es.commandBulkMoveTo(4, 'tomorrow', _short(day(1), 'es')),
      );
      final context = tester.element(find.byType(CaptureResult));
      final tasks = {for (final task in _fourYesterday()) task.title: task};
      _expectRowLine(
        'Pintar la valla',
        '${taskDayLine(context, tasks['Pintar la valla']!)} · Casa',
      );
      _expectRowLine(
        'Llamar al fontanero',
        taskDayLine(context, tasks['Llamar al fontanero']!),
      );
      _expectRowLine(
        'Comprar el regalo',
        taskDayLine(context, tasks['Comprar el regalo']!),
      );
      expect(_inResult(find.textContaining(es.commandCompleted)), findsNothing);
      for (final title in [
        'Llamar al fontanero',
        'Pintar la valla',
        'Comprar el regalo',
        'Pagar la factura del gas',
      ]) {
        expect(
          _titleStyle(tester, title)?.decoration,
          isNot(TextDecoration.lineThrough),
          reason: title,
        );
      }
    });

    for (final language in ['es', 'ca']) {
      testWidgets('UX-1701: $language at 2× on 360 dp, the assigning set’s '
          'rows show every title and second line in full', (tester) async {
        final app = await _App.open(
          tester,
          tasks: _friday(personal: ['Llamar a la gestoría', 'Comprar fruta']),
          projects: [_mathsShared],
          language: language,
          textScale: 2,
          size: const Size(360, 800),
        );
        await app.showResult(tester, [
          _assignFridayToPaul(),
        ], transcript: 'Asigna a Paul todo lo del viernes');
        expect(tester.takeException(), isNull);
        final rows = _inResult(find.byType(CheckboxListTile));
        expect(rows, findsNWidgets(2));
        for (final row in rows.evaluate()) {
          final texts = find.descendant(
            of: find.byElementPredicate((e) => e == row),
            matching: find.byType(RichText),
          );
          // The title and its line under it.
          final drawn = [
            for (final element in texts.evaluate())
              if ((element.widget as RichText).text.toPlainText().trim()
                  case final text when text.isNotEmpty)
                text,
          ];
          expect(drawn.length, greaterThanOrEqualTo(2), reason: '$drawn');
          expect(drawn.any((text) => text.contains('Matemáticas')), isTrue);
          for (final element in texts.evaluate()) {
            final rich = element.widget as RichText;
            final text = rich.text.toPlainText();
            expect(rich.maxLines, isNull, reason: '«$text» isn’t cut');
            expect(
              rich.overflow,
              isNot(TextOverflow.ellipsis),
              reason: '«$text» isn’t ellipsized',
            );
            expect(
              (element.renderObject! as RenderParagraph).didExceedMaxLines,
              isFalse,
              reason: '«$text» shows in full',
            );
          }
        }
      });
    }

    // ---------------------------------------------------- P224 · UX-1704
    testWidgets('UX-1704: at 2× on 360 dp a set deletion opens at its heading: '
        '«Eliminar 3 tareas» and its ✕ in view', (tester) async {
      final app = await _App.open(
        tester,
        tasks: _doneLastWeek(),
        textScale: 2,
        size: const Size(360, 800),
      );
      await app.showResult(tester, [
        _deleteDoneLastWeek(),
      ], transcript: 'Borra todas las completadas de la semana pasada');
      expect(_headline(tester), es.commandBulkDelete(3));
      expect(es.commandDontDeleteAny, 'No eliminar ninguna');
      final view = _resultView(tester);
      // The case at hand: the red card is taller than the view.
      final card = tester.getRect(
        find
            .ancestor(
              of: _inResult(find.byKey(const ValueKey('command-headline'))),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(card.height, greaterThan(view.height), reason: '$card in $view');
      _expectInside(
        view,
        tester.getRect(
          _inResult(find.byKey(const ValueKey('command-headline'))).first,
        ),
        'the heading',
      );
      _expectInside(
        view,
        tester.getRect(_inResult(find.byTooltip(es.commandDontDeleteAny))),
        'the ✕',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('UX-1704: a one-task deletion at 2× still brings its card '
        'fully into view above the buttons', (tester) async {
      final app = await _App.open(
        tester,
        tasks: [
          ..._fourYesterday(),
          Task(id: 9, title: 'Dentista', priority: 1, dueDate: day(2, 9)),
        ],
        textScale: 2,
        size: const Size(360, 800),
      );
      await app.showResult(tester, [
        command({
          'kind': 'delete',
          'target': {
            'words': ['dentista'],
          },
        }),
      ], transcript: 'Borra el dentista');
      final card = tester.getRect(
        find
            .ancestor(
              of: _inResult(find.byKey(const ValueKey('command-headline'))),
              matching: find.byType(Material),
            )
            .first,
      );
      final view = _resultView(tester);
      _expectInside(view, card, 'the deletion’s card');
      expect(
        card.bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const ValueKey('save-drafts'))).top,
        ),
      );
    });

    // ---------------------------------------------------- P224 · UX-1706
    for (final weekly in [1, 2]) {
      testWidgets('UX-1706: yesterday’s tasks to tomorrow with $weekly weekly '
          'task(s) left out: ${weekly == 1 ? 'named' : 'counted'}', (
        tester,
      ) async {
        final app = await _App.open(
          tester,
          tasks: [
            ..._fourYesterday(),
            Task(
              id: 20,
              title: 'Natación',
              priority: 1,
              dueDate: day(-8, 18),
              recurrence: 'weekly',
            ),
            if (weekly == 2)
              Task(
                id: 21,
                title: 'Clase de inglés',
                priority: 1,
                dueDate: day(-15, 17),
                recurrence: 'weekly',
              ),
          ],
          projects: [_casa],
        );
        await app.showResult(tester, [
          _moveYesterdayToTomorrow(),
        ], transcript: 'Pasa todas las tareas de ayer a mañana');
        final line = weekly == 1
            ? 'Natación se repite: no cambia'
            : '2 tareas que se repiten no cambian';
        expect(_inResult(find.text(line)), findsOneWidget);
        expect(
          weekly == 1
              ? es.commandBulkLeftRepeating(1, 'change', 'Natación')
              : es.commandBulkLeftRepeating(2, 'change', ''),
          line,
        );
      });
    }

    testWidgets('UX-1706: assigning Friday to Paul names the lone repeating '
        'task, counts two that can’t be his, and names a lone one', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: _friday(personal: ['Llamar a la gestoría', 'Comprar fruta']),
        projects: [_mathsShared],
      );
      await app.showResult(tester, [
        _assignFridayToPaul(),
      ], transcript: 'Asigna a Paul todo lo del viernes');
      expect(
        _inResult(
          find.text(
            'Natación se repite: no cambia · '
            '2 tareas no se pueden asignar a Paul',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('UX-1706: with exactly one task that can’t be assigned, the '
        'line names it', (tester) async {
      final app = await _App.open(
        tester,
        tasks: _friday(),
        projects: [_mathsShared],
      );
      await app.showResult(tester, [
        _assignFridayToPaul(),
      ], transcript: 'Asigna a Paul todo lo del viernes');
      expect(
        _inResult(
          find.text(
            'Natación se repite: no cambia · '
            'Llamar a la gestoría no se puede asignar a Paul',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('UX-1706: «Retrasa un día todo lo de Casa» with one task with '
        'no day and no deadline: «<title> no tiene fecha: no cambia»', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(
            id: 1,
            title: 'Pintar la valla',
            priority: 1,
            dueDate: day(2, 10),
            listId: 'casa',
          ),
          Task(
            id: 2,
            title: 'Cambiar las bombillas',
            priority: 1,
            listId: 'casa',
          ),
          Task(id: 3, title: 'Fuera de Casa', priority: 1, dueDate: day(2)),
        ],
        projects: [_casa],
      );
      await app.showResult(tester, [
        command({
          'kind': 'update',
          'target': setTarget(listId: 'casa'),
          'changes': {'shift_days': 1},
        }),
      ], transcript: 'Retrasa un día todo lo de Casa');
      expect(
        _inResult(find.text('Cambiar las bombillas no tiene fecha: no cambia')),
        findsOneWidget,
      );
    });

    test('UX-1706: the left-out lines read the brief’s copy, a lone task '
        'named, two counted', () {
      expect(
        [
          for (final action in ['delete', 'complete', 'change'])
            for (final strings in [en, es, ca])
              strings.commandBulkLeftRepeating(1, action, 'Natación'),
        ],
        [
          'Natación repeats: it won’t be deleted',
          'Natación se repite: no se elimina',
          'Natación es repeteix: no se suprimeix',
          'Natación repeats: it won’t be completed',
          'Natación se repite: no se completa',
          'Natación es repeteix: no es completa',
          'Natación repeats: it won’t change',
          'Natación se repite: no cambia',
          'Natación es repeteix: no canvia',
        ],
      );
      expect(
        [
          for (final action in ['delete', 'complete', 'change'])
            for (final strings in [en, es, ca])
              strings.commandBulkLeftRepeating(2, action, 'Natación'),
        ],
        [
          '2 repeating tasks won’t be deleted',
          '2 tareas que se repiten no se eliminan',
          '2 tasques que es repeteixen no se suprimeixen',
          '2 repeating tasks won’t be completed',
          '2 tareas que se repiten no se completan',
          '2 tasques que es repeteixen no es completen',
          '2 repeating tasks won’t change',
          '2 tareas que se repiten no cambian',
          '2 tasques que es repeteixen no canvien',
        ],
      );
      expect(
        [
          for (final strings in [en, es, ca])
            for (final count in [1, 2])
              strings.commandBulkLeftUnassignable(count, 'Paul', 'Leer'),
        ],
        [
          'Leer can’t be assigned to Paul',
          '2 tasks can’t be assigned to Paul',
          'Leer no se puede asignar a Paul',
          '2 tareas no se pueden asignar a Paul',
          'Leer no es pot assignar a Paul',
          '2 tasques no es poden assignar a Paul',
        ],
      );
      expect(
        [
          for (final strings in [en, es, ca])
            for (final count in [1, 2])
              strings.commandBulkLeftNoDay(count, 'Leer'),
        ],
        [
          'Leer has no date: it won’t change',
          '2 tasks with no date won’t change',
          'Leer no tiene fecha: no cambia',
          '2 tareas sin fecha no cambian',
          'Leer no té data: no canvia',
          '2 tasques sense data no canvien',
        ],
      );
    });

    // ---------------------------------------------------- P224 · UX-1712
    for (final (language, strings) in [('es', es), ('ca', ca), ('en', en)]) {
      testWidgets('UX-1712: $language, a move to tomorrow joins the weekday '
          'and its number with a no-break space', (tester) async {
        final app = await _App.open(
          tester,
          tasks: _fourYesterday(),
          projects: [_casa],
          language: language,
        );
        await app.showResult(tester, [_moveYesterdayToTomorrow()]);
        final tomorrow = day(1);
        final joined = DateFormat('E d', language).format(tomorrow);
        final split = DateFormat('E d', language).format(tomorrow);
        expect(joined, isNot(split));
        expect(_headline(tester), contains(joined));
        expect(_headline(tester), isNot(contains(split)));
        expect(
          _headline(tester),
          strings.commandBulkMoveTo(4, 'tomorrow', joined),
        );
      });
    }

    // ---------------------------------------------------- P224 · UX-1713
    test('UX-1713: too many reads the brief’s copy in all three', () {
      expect(
        es.commandBulkTooMany(230),
        'Son 230 tareas, demasiadas. Vuelve a decirlo con un día o un '
        'proyecto.',
      );
      expect(
        en.commandBulkTooMany(230),
        'That’s 230 tasks, too many. Say it again with one day or one '
        'project.',
      );
      expect(
        ca.commandBulkTooMany(230),
        'Són 230 tasques, massa. Torna-ho a dir amb un dia o un projecte.',
      );
    });

    testWidgets('UX-1713: over 200 matches the card’s first line is the '
        'too-many line, with no list', (tester) async {
      final app = await _App.open(
        tester,
        tasks: [
          for (var i = 0; i < 230; i++)
            Task(
              id: i + 1,
              title: 'Tarea $i',
              priority: 1,
              dueDate: day(-1, 9),
            ),
        ],
      );
      await app.showResult(tester, [_moveYesterdayToTomorrow()]);
      expect(_headline(tester), es.commandBulkTooMany(230));
      expect(_inResult(find.byType(CheckboxListTile)), findsNothing);
    });

    // ---------------------------------------------------- P225 · UX-1708
    test('UX-1708: project candidates are kept, in order, at most 3, for a '
        'set, one task’s deletion and completion, and a search', () {
      final set = command({
        'kind': 'update',
        'issues': ['ambiguous_project'],
        'target': {
          ...setTarget(),
          'project_name': 'mates',
          'project_candidates': _mathsCandidates,
        },
        'changes': {'date': key(day(1))},
      });
      expect(set.bulk, isTrue);
      expect(set.target.projectCandidates, ['maths', 'maths2']);
      for (final kind in ['delete', 'complete']) {
        final one = command({
          'kind': kind,
          'issues': ['ambiguous_project'],
          'target': {
            'words': ['examen'],
            'project_name': 'mates',
            'project_candidates': _mathsCandidates,
          },
        });
        expect(one.bulk, isFalse);
        expect(one.target.projectCandidates, ['maths', 'maths2'], reason: kind);
      }
      final search = command({
        'kind': 'find',
        'issues': ['ambiguous_project'],
        'words': <String>[],
        'project_name': 'mates',
        'project_candidates': _mathsCandidates,
      });
      expect(search.projectCandidates, ['maths', 'maths2']);
      // At most three.
      final many = command({
        'kind': 'delete',
        'issues': ['ambiguous_project'],
        'target': {
          'words': ['examen'],
          'project_name': 'mates',
          'project_candidates': [
            for (final id in ['a', 'b', 'c', 'd']) {'id': id, 'name': id},
          ],
        },
      });
      expect(many.target.projectCandidates, ['a', 'b', 'c']);
      // Kept with the capture.
      for (final kept in [set, search]) {
        final back = CaptureCommand.fromJson(
          jsonDecode(jsonEncode(kept.toJson())),
        )!;
        expect(
          back.kind == CommandKind.find
              ? back.projectCandidates
              : back.target.projectCandidates,
          ['maths', 'maths2'],
        );
      }
      // Without the key: none, as before.
      final plain = command({
        'kind': 'complete',
        'target': {
          'words': ['examen'],
        },
      });
      expect(plain.target.projectCandidates, isEmpty);
      expect(
        command({
          'kind': 'find',
          'words': ['examen'],
        }).projectCandidates,
        isEmpty,
      );
    });

    test('UX-1708: the new question reads the brief’s copy', () {
      expect(en.commandWhichProjectOfTasks, 'Which project?');
      expect(es.commandWhichProjectOfTasks, '¿Qué proyecto?');
      expect(ca.commandWhichProjectOfTasks, 'Quin projecte?');
    });

    testWidgets('UX-1708: «Pasa todo lo de mates a mañana» with two matching '
        'projects asks which, waits, and a tap makes it the set’s', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(
            id: 1,
            title: 'Corregir los ejercicios',
            priority: 1,
            dueDate: day(-1, 17),
            listId: 'maths',
          ),
          Task(
            id: 2,
            title: 'Preparar el examen del tema 6',
            priority: 2,
            dueDate: day(-1),
            hasTime: false,
            listId: 'maths',
          ),
          Task(
            id: 3,
            title: 'Leer el tema 2',
            priority: 1,
            dueDate: day(-1, 10),
            listId: 'maths2',
          ),
        ],
        projects: [_maths, _mathsTwo],
      );
      await app.showResult(tester, [
        command({
          'kind': 'update',
          'issues': ['ambiguous_project'],
          'target': {
            ...setTarget(),
            'project_name': 'mates',
            'project_candidates': _mathsCandidates,
          },
          'changes': {'date': key(day(1))},
        }),
      ], transcript: 'Pasa todo lo de mates a mañana');
      expect(_headline(tester), es.commandFindProject('mates'));
      expect(_headline(tester), 'Tareas de «mates»');
      expect(_inResult(find.text('¿Qué proyecto?')), findsOneWidget);
      expect(
        [for (final chip in _projectChips(tester)) chip.key],
        [
          const ValueKey('command-project-maths'),
          const ValueKey('command-project-maths2'),
        ],
      );
      for (final name in ['Matemáticas', 'Matemáticas II']) {
        expect(
          find.descendant(
            of: _inResult(find.byType(ChoiceChip)),
            matching: find.text(name),
          ),
          findsOneWidget,
        );
      }
      expect(find.text(es.commandProjectNotFound('mates')), findsNothing);
      expect(_button(tester).onPressed, isNull);
      expect(_buttonLabel(tester), es.captureCheckDetails);
      expect(_buttonLabel(tester), 'Revisa los datos de arriba');

      await tester.tap(find.byKey(const ValueKey('command-project-maths')));
      await tester.pumpAndSettle();
      expect(
        _headline(tester),
        es.commandBulkMoveTo(2, 'tomorrow', _short(day(1), 'es')),
      );
      expect(_headline(tester), startsWith('Mover 2 tareas a mañana, '));
      expect(_inResult(find.byType(CheckboxListTile)), findsNWidgets(2));
      expect(
        tester
            .widgetList<CheckboxListTile>(
              _inResult(find.byType(CheckboxListTile)),
            )
            .every((tile) => tile.value == true),
        isTrue,
      );
      expect(_setRow('Corregir los ejercicios'), findsOneWidget);
      expect(_setRow('Preparar el examen del tema 6'), findsOneWidget);
      expect(_buttonLabel(tester), 'Mover 2 tareas');
      expect(_button(tester).onPressed, isNotNull);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('command-project-maths')),
            )
            .selected,
        isTrue,
      );
      // The chips stay, to tap another.
      expect(_projectChips(tester), hasLength(2));
    });

    testWidgets('UX-1708: one task to mark done, with two matching projects: '
        '«Tareas con «examen»», the chips, and a tap finds it', (tester) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(
            id: 1,
            title: 'Preparar el examen del tema 6',
            priority: 2,
            dueDate: day(2, 10),
            listId: 'maths',
          ),
          Task(
            id: 2,
            title: 'Leer el tema 2',
            priority: 1,
            dueDate: day(2, 12),
            listId: 'maths2',
          ),
        ],
        projects: [_maths, _mathsTwo],
      );
      await app.showResult(tester, [
        command({
          'kind': 'complete',
          'issues': ['ambiguous_project'],
          'target': {
            'words': ['examen'],
            'project_name': 'mates',
            'project_candidates': _mathsCandidates,
          },
        }),
      ], transcript: 'Ya he preparado el examen de mates');
      expect(_headline(tester), es.commandFindWords('examen'));
      expect(_headline(tester), 'Tareas con «examen»');
      expect(_inResult(find.text(es.commandWhichProjectOfTasks)), findsOne);
      expect(_projectChips(tester), hasLength(2));
      expect(
        find.byKey(const ValueKey('result-save-as-written')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('command-project-maths')));
      await tester.pumpAndSettle();
      expect(_headline(tester), 'Preparar el examen del tema 6');
      expect(_buttonLabel(tester), es.commandMarkDone);
      expect(_buttonLabel(tester), 'Marcar como hecha');
      expect(_button(tester).onPressed, isNotNull);
    });

    testWidgets('UX-1708: a search with two matching projects: a tap lists '
        'that project’s tasks and «Abrir «Matemáticas»»', (tester) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(
            id: 1,
            title: 'Preparar el examen del tema 6',
            priority: 2,
            dueDate: day(2, 10),
            listId: 'maths',
          ),
          Task(
            id: 2,
            title: 'Leer el tema 2',
            priority: 1,
            dueDate: day(2, 12),
            listId: 'maths2',
          ),
        ],
        projects: [_maths, _mathsTwo],
      );
      await app.showResult(tester, [
        command({
          'kind': 'find',
          'issues': ['ambiguous_project'],
          'words': <String>[],
          'project_name': 'mates',
          'project_candidates': _mathsCandidates,
        }),
      ], transcript: '¿Qué tengo de mates?');
      expect(_headline(tester), 'Tareas de «mates»');
      expect(_projectChips(tester), hasLength(2));
      await tester.tap(find.byKey(const ValueKey('command-project-maths')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('found-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('found-2')), findsNothing);
      expect(
        _inResult(find.text(es.commandOpenProject('Matemáticas'))),
        findsOneWidget,
      );
      expect(es.commandOpenProject('Matemáticas'), 'Abrir «Matemáticas»');
    });

    testWidgets('UX-1708: candidates the phone doesn’t have: still «No '
        'encuentro el proyecto «mates»»', (tester) async {
      final app = await _App.open(
        tester,
        tasks: _fourYesterday(),
        projects: [_casa],
      );
      await app.showResult(tester, [
        command({
          'kind': 'update',
          'issues': ['ambiguous_project'],
          'target': {
            ...setTarget(),
            'project_name': 'mates',
            'project_candidates': _mathsCandidates,
          },
          'changes': {'date': key(day(1))},
        }),
      ], transcript: 'Pasa todo lo de mates a mañana');
      expect(_headline(tester), es.commandProjectNotFound('mates'));
      expect(_inResult(find.byType(ChoiceChip)), findsNothing);
    });

    // ---------------------------------------------------- P226 · UX-1703
    testWidgets('UX-1703: four of yesterday’s tasks moved to tomorrow: '
        '«4 tareas movidas al <tomorrow>», Calendar on tomorrow, all 4 lit', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: _fourYesterday(),
        projects: [_casa],
      );
      expect(find.text(es.todayAgenda), findsOneWidget);
      await app.showResult(tester, [
        _moveYesterdayToTomorrow(),
      ], transcript: 'Pasa todas las tareas de ayer a mañana');
      await _confirm(tester);
      expect(find.byType(CaptureResult), findsNothing);
      final message = es.commandTasksMovedTo(4, _weekdayDate(tester, day(1)));
      expect(message, startsWith('4 tareas movidas al '));
      expect(find.text(message), findsOneWidget);
      expect(find.text(es.undo), findsOneWidget);
      expect(find.text(_dayHeading(day(1))), findsOneWidget);
      for (final title in [
        'Llamar al fontanero',
        'Pintar la valla',
        'Comprar el regalo',
        'Pagar la factura del gas',
      ]) {
        expect(_calendarRow(title), findsOneWidget, reason: title);
        expect(
          tester.widget<TaskTile>(_calendarRow(title)).color,
          _litColor(tester),
          reason: '$title is lit',
        );
      }
    });

    testWidgets('UX-1703: five tasks on five days moved by a week: Calendar '
        'on the earliest new day; «5 tareas movidas · también en otros 4 '
        'días»', (tester) async {
      final app = await _App.open(
        tester,
        tasks: [
          for (var i = 0; i < 5; i++)
            Task(
              id: i + 1,
              title: 'Tarea del día $i',
              priority: 1,
              dueDate: day(i - 1, 9),
            ),
        ],
      );
      await app.showResult(tester, [
        command({
          'kind': 'update',
          'target': setTarget(from: day(-1), to: day(3)),
          'changes': {'shift_days': 7},
        }),
      ]);
      await _confirm(tester);
      expect(app.tasks.byId(1)!.dueDate, day(6, 9));
      expect(find.text(_dayHeading(day(6))), findsOneWidget);
      expect(
        find.text('5 tareas movidas · también en otros 4 días'),
        findsOneWidget,
      );
      expect(
        '${es.commandTasksMoved(5)} · ${es.captureAlsoOnDays(4)}',
        '5 tareas movidas · también en otros 4 días',
      );
      expect(
        tester.widget<TaskTile>(_calendarRow('Tarea del día 0')).color,
        _litColor(tester),
      );
    });

    testWidgets('UX-1703: two tasks on two days moved by a week: «2 tareas '
        'movidas · también el <the later day>»', (tester) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(id: 1, title: 'Gimnasio', priority: 1, dueDate: day(-1, 19)),
          Task(id: 2, title: 'Leer', priority: 1, dueDate: day(1, 21)),
        ],
      );
      await app.showResult(tester, [
        command({
          'kind': 'update',
          'target': setTarget(from: day(-1), to: day(1)),
          'changes': {'shift_days': 7},
        }),
      ]);
      await _confirm(tester);
      expect(app.tasks.byId(2)!.dueDate, day(8, 21));
      expect(find.text(_dayHeading(day(6))), findsOneWidget);
      expect(
        find.text(
          '${es.commandTasksMoved(2)} · '
          '${es.captureAlsoOn(_weekdayDate(tester, day(8)))}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('UX-1703: a task with only a deadline lands on its moved '
        'deadline’s day; «también el …» names the other; the no-date row '
        'isn’t lit', (tester) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(
            id: 1,
            title: 'Entregar el trabajo',
            priority: 1,
            deadline: day(2),
            reminderAnchor: 'deadline',
          ),
          Task(id: 2, title: 'Ir al médico', priority: 1, dueDate: day(4, 10)),
          Task(id: 3, title: 'Sin día', priority: 1),
        ],
      );
      await app.showResult(tester, [
        command({
          'kind': 'update',
          'target': setTarget(from: day(2), to: day(4)),
          'changes': {'shift_days': 1},
        }),
      ]);
      await _confirm(tester);
      expect(app.tasks.byId(1)!.deadline, day(3));
      expect(app.tasks.byId(2)!.dueDate, day(5, 10));
      expect(find.text(_dayHeading(day(3))), findsOneWidget);
      expect(
        find.text(
          '${es.commandTasksMoved(2)} · '
          '${es.captureAlsoOn(_weekdayDate(tester, day(5)))}',
        ),
        findsOneWidget,
      );
      final inbox = find.byKey(const ValueKey('calendar-inbox'));
      expect(inbox, findsOneWidget);
      final box = tester.widget<DecoratedBox>(
        find.ancestor(of: inbox, matching: find.byType(DecoratedBox)).first,
      );
      expect(
        (box.decoration as BoxDecoration).color,
        isNot(_litColor(tester)),
        reason: 'the no-date row is not lit',
      );
    });

    testWidgets('UX-1703: Catalan at 2× on 360 dp: the message of a 4-task '
        'move to tomorrow takes at most 3 lines', (tester) async {
      final app = await _App.open(
        tester,
        tasks: _fourYesterday(),
        projects: [_casa],
        language: 'ca',
        textScale: 2,
        size: const Size(360, 800),
      );
      await app.showResult(tester, [_moveYesterdayToTomorrow()]);
      await _confirm(tester);
      final message = ca.commandTasksMovedTo(4, _weekdayDate(tester, day(1)));
      final shown = find.text(message);
      expect(shown, findsOneWidget);
      expect(_lines(tester, shown), lessThanOrEqualTo(3), reason: message);
      expect(tester.takeException(), isNull);
    });

    test('UX-1703, UX-1710: moved to a day and assigned to someone read the '
        'brief’s copy', () {
      expect(
        es.commandTasksMovedTo(1, 'jue, 22 oct'),
        'Tarea movida al jue, 22 oct',
      );
      expect(
        es.commandTasksMovedTo(4, 'jue, 22 oct'),
        '4 tareas movidas al jue, 22 oct',
      );
      expect(es.commandTasksAssignedTo(1, 'Paul'), 'Tarea asignada a Paul');
      expect(es.commandTasksAssignedTo(4, 'Paul'), '4 tareas asignadas a Paul');
      expect(
        en.commandTasksMovedTo(1, 'Thu, Oct 22'),
        'Task moved to Thu, Oct 22',
      );
      expect(
        en.commandTasksMovedTo(4, 'Thu, Oct 22'),
        '4 tasks moved to Thu, Oct 22',
      );
      expect(en.commandTasksAssignedTo(1, 'Paul'), 'Task assigned to Paul');
      expect(en.commandTasksAssignedTo(4, 'Paul'), '4 tasks assigned to Paul');
      expect(
        ca.commandTasksMovedTo(1, 'dj., 22 d’oct.'),
        'Tasca moguda al dj., 22 d’oct.',
      );
      expect(
        ca.commandTasksMovedTo(4, 'dj., 22 d’oct.'),
        '4 tasques mogudes al dj., 22 d’oct.',
      );
      expect(ca.commandTasksAssignedTo(1, 'Paul'), 'Tasca assignada a Paul');
      expect(
        ca.commandTasksAssignedTo(4, 'Paul'),
        '4 tasques assignades a Paul',
      );
    });

    // ---------------------------------------------------- P226 · UX-1710
    testWidgets('UX-1710: «Asignar 2 tareas» tapped: «2 tareas asignadas a '
        'Paul», with Deshacer', (tester) async {
      final app = await _App.open(
        tester,
        tasks: _friday(personal: ['Llamar a la gestoría', 'Comprar fruta']),
        projects: [_mathsShared],
      );
      await app.showResult(tester, [
        _assignFridayToPaul(),
      ], transcript: 'Asigna a Paul todo lo del viernes');
      expect(_buttonLabel(tester), es.commandBulkAssign(2));
      await _confirm(tester);
      expect(app.tasks.byId(70)!.assigneeId, 3);
      expect(find.text('2 tareas asignadas a Paul'), findsOneWidget);
      expect(find.text(es.undo), findsOneWidget);
    });

    testWidgets('UX-1710: two one-task completions: «Marcar 2 tareas como '
        'hechas»; tapped, both done, «2 tareas completadas»', (tester) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(id: 1, title: 'Ir al médico', priority: 1, dueDate: day(0, 10)),
          Task(id: 2, title: 'Comprar pan', priority: 1, dueDate: day(0, 18)),
        ],
      );
      await app.showResult(tester, [
        command({
          'kind': 'complete',
          'target': {
            'words': ['médico'],
          },
        }),
        command({
          'kind': 'complete',
          'target': {
            'words': ['pan'],
          },
        }),
      ]);
      expect(_buttonLabel(tester), 'Marcar 2 tareas como hechas');
      expect(_buttonLabel(tester), es.commandBulkComplete(2));
      await _confirm(tester);
      expect(app.tasks.byId(1)!.isCompleted, isTrue);
      expect(app.tasks.byId(2)!.isCompleted, isTrue);
      expect(find.text('2 tareas completadas'), findsOneWidget);
      expect(find.text(es.undo), findsOneWidget);
    });

    test('UX-1710: «per fer» and “to do” for the tasks still to do; '
        'Spanish unchanged', () {
      expect(
        ca.commandBulkNone('open', ca.commandBulkPeriod('yesterday', '', '')),
        'No hi ha tasques per fer d’ahir',
      );
      expect(
        en.commandBulkNone('open', en.commandBulkPeriod('yesterday', '', '')),
        'There are no tasks to do from yesterday',
      );
      expect(
        en.commandBulkNone('open', en.commandBulkPeriod('today', '', '')),
        'There are no tasks to do for today',
      );
      expect(
        es.commandBulkNone('open', es.commandBulkPeriod('yesterday', '', '')),
        'No hay tareas pendientes de ayer',
      );
    });

    // ---------------------------------------------------- P226 · UX-1711
    testWidgets('UX-1711: «Ya he ido a la peluquería» marked done: Calendar '
        'on its Saturday, the row ticked and lit, «Completada: Ir a la '
        'peluquería»; Deshacer reopens the result, the task open', (
      tester,
    ) async {
      final saturday = day(_ahead(DateTime.saturday), 10);
      final app = await _App.open(
        tester,
        tasks: [
          Task(id: 1, title: 'Comprar pan', priority: 1, dueDate: day(0, 9)),
          Task(
            id: 40,
            title: 'Ir a la peluquería',
            priority: 1,
            dueDate: saturday,
          ),
        ],
      );
      expect(find.text(es.todayAgenda), findsOneWidget);
      await app.showResult(tester, [
        command({
          'kind': 'complete',
          'target': {
            'words': ['peluquería'],
          },
        }),
      ], transcript: 'Ya he ido a la peluquería');
      await _confirm(tester);
      expect(app.tasks.byId(40)!.isCompleted, isTrue);
      expect(find.text(_dayHeading(saturday)), findsOneWidget);
      final row = _calendarRow('Ir a la peluquería');
      expect(row, findsOneWidget);
      expect(tester.widget<TaskTile>(row).task.isCompleted, isTrue);
      expect(tester.widget<TaskTile>(row).color, _litColor(tester));
      expect(find.text('Completada: Ir a la peluquería'), findsOneWidget);
      expect(find.text(es.undo), findsOneWidget);

      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(app.tasks.byId(40)!.isCompleted, isFalse);
    });

    testWidgets('UX-1711: «Marca como hechas todas las de hoy»: Calendar '
        'stays on today, the 4 rows ticked and lit, «4 tareas completadas»', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(id: 1, title: 'Comprar pan', priority: 1, dueDate: day(0, 9)),
          Task(id: 2, title: 'Ir al médico', priority: 1, dueDate: day(0, 11)),
          Task(id: 3, title: 'Llamar a mamá', priority: 1, dueDate: day(0, 13)),
          Task(
            id: 4,
            title: 'Clase de yoga',
            priority: 1,
            dueDate: day(-7, 19),
            recurrence: 'daily',
          ),
        ],
      );
      await app.showResult(tester, [
        command({'kind': 'complete', 'target': setTarget(from: day(0))}),
      ], transcript: 'Marca como hechas todas las de hoy');
      expect(_headline(tester), es.commandBulkComplete(4));
      await _confirm(tester);
      expect(find.text(es.todayAgenda), findsOneWidget);
      for (final title in [
        'Comprar pan',
        'Ir al médico',
        'Llamar a mamá',
        'Clase de yoga',
      ]) {
        // Today's row: a daily task also shows its next repetition.
        final row = find.byWidgetPredicate(
          (widget) =>
              widget is TaskTile &&
              widget.task.title == title &&
              widget.task.displayDate != null &&
              Task.day(widget.task.displayDate!) == day(0),
        );
        expect(row, findsOneWidget, reason: title);
        expect(
          tester.widget<TaskTile>(row).task.isCompleted,
          isTrue,
          reason: '$title is ticked',
        );
        expect(
          tester.widget<TaskTile>(row).color,
          _litColor(tester),
          reason: '$title is lit',
        );
      }
      expect(find.text('4 tareas completadas'), findsOneWidget);
    });

    // ---------------------------------------------------- P227 · UX-1707
    group('UX-1707: undoing on the phone doesn’t wait for the cloud', () {
      Future<T> soon<T>(Future<T> future) =>
          future.timeout(const Duration(seconds: 2));

      test('UX-1707: restoreTasks completes, the task shown, while the sync '
          'runs', () async {
        final cloud = NeverSyncingTasks();
        final notifier = TaskNotifier(cloud);
        addTearDown(notifier.dispose);
        final task = Task(id: 7, title: 'Dentista', priority: 1);
        expect(await soon(notifier.restoreTasks([task])), isTrue);
        expect(cloud.finished, 0);
        expect(
          notifier.state.requireValue.map((task) => task.title),
          contains('Dentista'),
        );
      });

      test('UX-1707: undoSchedule completes, the task back on its day, while '
          'the sync runs', () async {
        final before = Task(
          id: 7,
          title: 'Dentista',
          priority: 1,
          dueDate: day(1, 9),
        );
        final after = TaskScheduleChange.apply(before, day(3, 9), true);
        final cloud = NeverSyncingTasks([after]);
        final notifier = TaskNotifier(cloud);
        addTearDown(notifier.dispose);
        expect(
          await soon(notifier.undoSchedule(TaskScheduleChange(before, after))),
          isTrue,
        );
        expect(cloud.finished, 0);
        expect(
          notifier.state.requireValue.singleWhere((t) => t.id == 7).dueDate,
          day(1, 9),
        );
      });

      test('UX-1707: undoOccurrence completes, the repetition back, while '
          'the sync runs', () async {
        final series = Task(
          id: 8,
          title: 'Natación',
          priority: 1,
          dueDate: day(-7, 18),
          recurrence: 'weekly',
        );
        final moved = OccurrenceException(
          originalDate: key(day(0)),
          date: day(1, 18),
          hasTime: true,
        );
        final cloud = NeverSyncingTasks([
          series.copyWith(exceptions: [moved]),
        ]);
        final notifier = TaskNotifier(cloud);
        addTearDown(notifier.dispose);
        expect(
          await soon(
            notifier.undoOccurrence(
              OccurrenceChange(series, key(day(0)), null, moved),
            ),
          ),
          isTrue,
        );
        expect(cloud.finished, 0);
        expect(
          notifier.state.requireValue.singleWhere((t) => t.id == 8).exceptions,
          isEmpty,
        );
      });

      Future<bool> reopensWithin(WidgetTester tester, String headline) async {
        for (var step = 0; step < 10; step++) {
          await tester.pump(const Duration(milliseconds: 100));
          final head = _inResult(
            find.byKey(const ValueKey('command-headline')),
          );
          if (head.evaluate().isNotEmpty && _headline(tester) == headline) {
            return true;
          }
        }
        return false;
      }

      List<String> listed(_App app) => [
        for (final task
            in app.container.read(taskProvider).valueOrNull ?? <Task>[])
          task.title,
      ];

      testWidgets('UX-1707: a set deletion’s Deshacer, with a sync that never '
          'completes: within 1 s the tasks are back and the result reopens '
          'at «Eliminar 3 tareas»', (tester) async {
        final cloud = NeverSyncingTasks(_doneLastWeek());
        final app = await _App.open(tester, repository: cloud);
        await app.showResult(tester, [
          _deleteDoneLastWeek(),
        ], transcript: 'Borra todas las completadas de la semana pasada');
        expect(_headline(tester), es.commandBulkDelete(3));
        await _confirm(tester);
        expect(cloud.rows, isEmpty, reason: 'deleted on the phone');
        expect(find.byType(CaptureResult), findsNothing);
        await tester.tap(find.text(es.undo));
        expect(
          await reopensWithin(tester, es.commandBulkDelete(3)),
          isTrue,
          reason: 'the result is open again within 1 s',
        );
        expect(cloud.finished, 0, reason: 'the sync is still running');
        expect(
          listed(app),
          containsAll([for (final task in _doneLastWeek()) task.title]),
        );
        expect(cloud.rows, hasLength(3));
      });

      testWidgets('UX-1707: a one-task deletion’s Deshacer reopens the result '
          'at once, while the sync runs', (tester) async {
        final cloud = NeverSyncingTasks([
          Task(id: 9, title: 'Dentista', priority: 1, dueDate: day(2, 9)),
        ]);
        final app = await _App.open(tester, repository: cloud);
        await app.showResult(tester, [
          command({
            'kind': 'delete',
            'target': {
              'words': ['dentista'],
            },
          }),
        ], transcript: 'Borra el dentista');
        final headline = _headline(tester);
        await _confirm(tester);
        expect(cloud.rows, isEmpty);
        await tester.tap(find.text(es.undo));
        expect(
          await reopensWithin(tester, headline),
          isTrue,
          reason: 'the result is open again within 1 s',
        );
        expect(cloud.finished, 0);
        expect(listed(app), contains('Dentista'));
      });
    });

    // ---------------------------------------------------- P227 · UX-1714
    testWidgets('UX-1714: while «Mover 4 tareas» applies and the sheet '
        'closes, the card never recounts and the result never empties', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: _fourYesterday(),
        projects: [_casa],
      );
      await app.showResult(tester, [_moveYesterdayToTomorrow()]);
      final heading = es.commandBulkMoveTo(4, 'tomorrow', _short(day(1), 'es'));
      expect(_headline(tester), heading);
      await tester.tap(find.byKey(const ValueKey('save-drafts')));
      var frames = 0;
      var withCard = 0;
      while (find.byType(CaptureResult).evaluate().isNotEmpty && frames < 400) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
        expect(
          find.text(es.captureNothingToReview),
          findsNothing,
          reason: 'frame $frames',
        );
        expect(
          find.text(es.captureRemovedDraftsHelp),
          findsNothing,
          reason: 'frame $frames',
        );
        final head = _inResult(find.byKey(const ValueKey('command-headline')));
        if (head.evaluate().isEmpty) continue;
        withCard++;
        expect(_headline(tester), heading, reason: 'frame $frames');
        expect(
          _inResult(find.byType(CheckboxListTile)),
          findsNWidgets(4),
          reason: 'frame $frames',
        );
      }
      expect(find.byType(CaptureResult), findsNothing, reason: 'it closed');
      expect(withCard, greaterThan(0));
      expect(app.tasks.byId(1)!.dueDate, day(1, 9));
      await tester.pumpAndSettle();
    });

    testWidgets('UX-1714: when the apply fails the result stays with its '
        'cards and the error, worked out live again', (tester) async {
      final app = await _App.open(
        tester,
        tasks: _fourYesterday(),
        projects: [_casa],
      );
      app.store.failSave = true;
      await app.showResult(tester, [_moveYesterdayToTomorrow()]);
      await _confirm(tester);
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(_inResult(find.text(es.captureSaveFailed)), findsOneWidget);
      expect(
        _headline(tester),
        es.commandBulkMoveTo(4, 'tomorrow', _short(day(1), 'es')),
      );
      expect(app.tasks.byId(1)!.dueDate, day(-1, 9));
      await tester.tap(_setRow('Comprar el regalo'));
      await tester.pumpAndSettle();
      expect(
        _headline(tester),
        es.commandBulkMoveTo(3, 'tomorrow', _short(day(1), 'es')),
      );
      expect(_buttonLabel(tester), es.commandBulkMove(3));
    });

    testWidgets('UX-1714: after Deshacer the set is back, and unticking a '
        'task changes the heading’s and the button’s count', (tester) async {
      final app = await _App.open(
        tester,
        tasks: _fourYesterday(),
        projects: [_casa],
      );
      await app.showResult(tester, [_moveYesterdayToTomorrow()]);
      await _confirm(tester);
      expect(find.byType(CaptureResult), findsNothing);
      await tester.tap(find.text(es.undo));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureResult), findsOneWidget);
      expect(
        _headline(tester),
        es.commandBulkMoveTo(4, 'tomorrow', _short(day(1), 'es')),
      );
      await tester.tap(_setRow('Comprar el regalo'));
      await tester.pumpAndSettle();
      expect(
        _headline(tester),
        es.commandBulkMoveTo(3, 'tomorrow', _short(day(1), 'es')),
      );
      expect(_buttonLabel(tester), es.commandBulkMove(3));
    });

    // ---------------------------------------------------- P228 · UX-1709
    for (final count in [3, 1]) {
      testWidgets('UX-1709 (1): $count of tomorrow’s tasks already at 18:00: '
          '«${count == 1 ? 'Ya está así.' : 'Ya están así.'}»', (tester) async {
        final app = await _App.open(
          tester,
          tasks: [
            for (var i = 0; i < count; i++)
              Task(
                id: i + 1,
                title: 'Tarea $i',
                priority: 1,
                dueDate: day(1, 18),
              ),
          ],
        );
        await app.showResult(tester, [
          command({
            'kind': 'update',
            'target': setTarget(from: day(1)),
            'changes': {'time': '18:00'},
          }),
        ], transcript: 'Pon todas las de mañana a las 18:00');
        expect(
          _headline(tester),
          count == 1 ? 'Ya está así.' : 'Ya están así.',
        );
        expect(_headline(tester), es.commandBulkNothingToChange(count));
      });
    }

    for (final kind in ['delete', 'update', 'complete']) {
      for (final (language, strings) in [('es', es), ('ca', ca)]) {
        testWidgets('UX-1709 (2): $language, ✕ on a 4-task $kind set: the '
            'plural, with Deshacer', (tester) async {
          final app = await _App.open(
            tester,
            tasks: _fourYesterday(),
            projects: [_casa],
            language: language,
          );
          await app.showResult(tester, [
            command({
              'kind': kind,
              'target': setTarget(from: day(-1)),
              if (kind == 'update') 'changes': {'date': key(day(1))},
            }),
          ]);
          final (tooltip, message) = switch (kind) {
            'delete' => (
              strings.commandDontDeleteAny,
              strings.commandWontDelete(4),
            ),
            'update' => (
              strings.commandDontChangeAny,
              strings.commandWontChange(4),
            ),
            _ => (
              strings.commandDontCompleteAny,
              strings.commandWontComplete(4),
            ),
          };
          expect(message, switch ((language, kind)) {
            ('es', 'delete') => 'No se eliminarán',
            ('es', 'update') => 'No se cambiarán',
            ('es', _) => 'No se completarán',
            (_, 'delete') => 'No se suprimiran',
            (_, 'update') => 'No es canviaran',
            _ => 'No es completaran',
          });
          await tester.tap(_inResult(find.byTooltip(tooltip)));
          await tester.pumpAndSettle();
          expect(find.text(message), findsOneWidget);
          expect(find.text(strings.undo), findsOneWidget);
        });
      }

      testWidgets('UX-1709 (2): es, ✕ on a one-task $kind card: the singular', (
        tester,
      ) async {
        final app = await _App.open(
          tester,
          tasks: [
            Task(id: 9, title: 'Dentista', priority: 1, dueDate: day(2, 9)),
          ],
        );
        await app.showResult(tester, [
          command({
            'kind': kind,
            'target': {
              'words': ['dentista'],
            },
            if (kind == 'update') 'changes': {'date': key(day(4))},
          }),
        ]);
        final (tooltip, message) = switch (kind) {
          'delete' => (
            es.commandDontDelete('Dentista'),
            es.commandWontDelete(1),
          ),
          'update' => (
            es.commandDontChange('Dentista'),
            es.commandWontChange(1),
          ),
          _ => (es.commandDontComplete('Dentista'), es.commandWontComplete(1)),
        };
        expect(message, switch (kind) {
          'delete' => 'No se eliminará',
          'update' => 'No se cambiará',
          _ => 'No se completará',
        });
        await tester.tap(_inResult(find.byTooltip(tooltip)));
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
        expect(find.text(es.undo), findsOneWidget);
      });
    }

    testWidgets('UX-1709 (3): a move set whose only matches are in a project '
        'the person can only view names the project', (tester) async {
      final viewOnly = TaskListInfo(
        id: 'maths',
        name: 'Matemáticas',
        shared: true,
        role: 'viewer',
        version: 2,
        people: const [
          ProjectMember(id: 1, name: 'Yo', role: 'viewer'),
          ProjectMember(id: 4, name: 'Ana', role: 'owner'),
        ],
      );
      final app = await _App.open(
        tester,
        tasks: [
          Task(
            id: 1,
            title: 'Preparar el examen del tema 6',
            priority: 2,
            dueDate: day(0, 17),
            listId: 'maths',
          ),
          Task(
            id: 2,
            title: 'Corregir los ejercicios',
            priority: 1,
            dueDate: day(0),
            hasTime: false,
            listId: 'maths',
          ),
        ],
        projects: [viewOnly],
      );
      await app.showResult(tester, [
        command({
          'kind': 'update',
          'target': setTarget(from: day(0), listId: 'maths'),
          'changes': {'date': key(day(1))},
        }),
      ], transcript: 'Pasa las de Matemáticas de hoy a mañana');
      expect(
        _headline(tester),
        'Solo puedes ver «Matemáticas»: sus tareas no cambian.',
      );
      expect(find.byKey(const ValueKey('save-drafts')), findsNothing);
    });

    testWidgets('UX-1709 (4): one task with no day moved by days: «No tiene '
        'fecha: no se mueve.», and no line counts tasks «sin fecha»', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: [Task(id: 1, title: 'Llamar al banco', priority: 1)],
      );
      await app.showResult(tester, [
        command({
          'kind': 'update',
          'target': {
            'words': ['banco'],
          },
          'changes': {'shift_days': 2},
        }),
      ], transcript: 'Retrasa dos días lo del banco');
      expect(_inResult(find.text('No tiene fecha: no se mueve.')), findsOne);
      expect(es.commandNoDayStays, 'No tiene fecha: no se mueve.');
      expect(
        _inResult(find.textContaining(RegExp(r'tareas? sin fecha'))),
        findsNothing,
      );
      expect(
        _inResult(find.textContaining('no tiene fecha: no cambia')),
        findsNothing,
      );
    });

    testWidgets('UX-1709 (6): «Ya he ido a la peluquería» already done: «Ya '
        'estaba hecha.», and no «Marcar como hecha»', (tester) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(
            id: 40,
            title: 'Ir a la peluquería',
            priority: 1,
            dueDate: day(-1, 10),
            isCompleted: true,
          ),
        ],
      );
      await app.showResult(tester, [
        command({
          'kind': 'complete',
          'target': {
            'words': ['peluquería'],
          },
        }),
      ], transcript: 'Ya he ido a la peluquería');
      expect(_inResult(find.text('Ya estaba hecha.')), findsOneWidget);
      expect(find.text(es.commandMarkDone), findsNothing);
      expect(find.byKey(const ValueKey('save-drafts')), findsNothing);
    });

    test('UX-1709: the new and changed words read the brief’s copy, at 1 '
        'and 4', () {
      String all(String Function(AppLocalizations l) read) => [
        for (final l in [en, es, ca]) read(l),
      ].join(' / ');
      expect(
        all((l) => l.commandBulkNothingToChange(1)),
        'It’s already like that. / Ya está así. / Ja és així.',
      );
      expect(
        all((l) => l.commandBulkNothingToChange(4)),
        'They’re already like that. / Ya están así. / Ja són així.',
      );
      expect(
        all((l) => l.commandWontChange(1)),
        'Won’t be changed / No se cambiará / No es canviarà',
      );
      expect(
        all((l) => l.commandWontChange(4)),
        'Won’t be changed / No se cambiarán / No es canviaran',
      );
      expect(
        all((l) => l.commandWontDelete(1)),
        'Won’t be deleted / No se eliminará / No se suprimirà',
      );
      expect(
        all((l) => l.commandWontDelete(4)),
        'Won’t be deleted / No se eliminarán / No se suprimiran',
      );
      expect(
        all((l) => l.commandWontComplete(1)),
        'Won’t be completed / No se completará / No es completarà',
      );
      expect(
        all((l) => l.commandWontComplete(4)),
        'Won’t be completed / No se completarán / No es completaran',
      );
      expect(
        all((l) => l.commandBulkViewOnly('Matemáticas')),
        'You can only view “Matemáticas”: its tasks stay as they are. / '
        'Solo puedes ver «Matemáticas»: sus tareas no cambian. / '
        'Només pots veure «Matemáticas»: les seves tasques no canvien.',
      );
      expect(
        all((l) => l.commandNoDayStays),
        'It has no date, so it stays. / No tiene fecha: no se mueve. / '
        'No té data: no es mou.',
      );
      expect(
        all((l) => l.commandAlreadyDone),
        'It was already done. / Ya estaba hecha. / Ja estava feta.',
      );
    });
  });
}

// ---- UX loop 2026-10-21-changes, round 2 ---------------------------------
//
// P229 (UX-1717, UX-1718): ✕ on a set still asking its project says it in
// the plural, and a set deletion after another card is brought into view at
// its heading, while a lone set stays where it opens.

/// A new task as the server sends it: ready, nothing to answer.
CaptureDraft _newTask(String title, DateTime date) => CaptureDraft.fromAI(
  TaskDraft.fromJson({
    'title': title,
    'due_date': null,
    'scheduled_date': key(date),
    'priority': 1,
    'notes': '',
    'questions': [],
    'list_id': null,
    'assignment': 'personal',
    'assignment_issues': [],
    'assignment_hints': {'project': null, 'member': null},
    'new_project': null,
    'project_suggestion': null,
    'transcript': 'Lo que dije',
  }),
);

/// Two tasks in Matemáticas and one in Matemáticas II, yesterday.
List<Task> _mathsYesterday({bool done = false}) => [
  Task(
    id: 1,
    title: 'Corregir los ejercicios',
    priority: 1,
    dueDate: day(-1, 17),
    listId: 'maths',
    isCompleted: done,
  ),
  Task(
    id: 2,
    title: 'Preparar el examen del tema 6',
    priority: 2,
    dueDate: day(-1),
    hasTime: false,
    listId: 'maths',
    isCompleted: done,
  ),
  Task(
    id: 3,
    title: 'Leer el tema 2',
    priority: 1,
    dueDate: day(-1, 10),
    listId: 'maths2',
    isCompleted: done,
  ),
];

/// A set of [kind] on «mates», asking «¿Qué proyecto?».
CaptureCommand _askingSet(String kind, {String status = 'open'}) => command({
  'kind': kind,
  'issues': ['ambiguous_project'],
  'target': {
    ...setTarget(status: status),
    'project_name': 'mates',
    'project_candidates': _mathsCandidates,
  },
  if (kind == 'update') 'changes': {'date': key(day(1))},
});

/// The result's scroll offset.
double _resultOffset(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: _inResult(find.byType(SingleChildScrollView)).first,
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position
    .pixels;

void _round20261021Second() {
  group('UX loop 2026-10-21-changes, round 2', () {
    setUpAll(() async {
      // Positions are measured with the app's own font.
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    });

    // ---------------------------------------------------- P229 · UX-1717
    testWidgets('UX-1717: «Pasa todo lo de mates a mañana» still asking '
        '«¿Qué proyecto?»: ✕ says «No se cambiarán», with Deshacer', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: _mathsYesterday(),
        projects: [_maths, _mathsTwo],
      );
      await app.showResult(tester, [
        _askingSet('update'),
      ], transcript: 'Pasa todo lo de mates a mañana');
      expect(_inResult(find.text(es.commandWhichProjectOfTasks)), findsOne);
      expect(_projectChips(tester), hasLength(2));
      expect(_projectChips(tester).any((chip) => chip.selected), isFalse);
      expect(es.commandWontChange(2), 'No se cambiarán');
      await tester.tap(_inResult(find.byTooltip(es.commandDontChangeAny)));
      await tester.pumpAndSettle();
      expect(find.text(es.commandWontChange(2)), findsOneWidget);
      expect(find.text(es.commandWontChange(1)), findsNothing);
      expect(find.text(es.undo), findsOneWidget);
    });

    for (final (language, kind) in [
      ('es', 'delete'),
      ('es', 'complete'),
      ('ca', 'delete'),
    ]) {
      final strings = language == 'es' ? es : ca;
      testWidgets('UX-1717: $language, ✕ on a $kind set still asking '
          '«¿Qué proyecto?»: the plural', (tester) async {
        final app = await _App.open(
          tester,
          tasks: _mathsYesterday(done: kind == 'delete'),
          projects: [_maths, _mathsTwo],
          language: language,
        );
        await app.showResult(tester, [
          _askingSet(kind, status: kind == 'delete' ? 'completed' : 'open'),
        ]);
        expect(
          _inResult(find.text(strings.commandWhichProjectOfTasks)),
          findsOne,
        );
        final (tooltip, message) = kind == 'delete'
            ? (strings.commandDontDeleteAny, strings.commandWontDelete(2))
            : (strings.commandDontCompleteAny, strings.commandWontComplete(2));
        expect(message, switch ((language, kind)) {
          ('es', 'delete') => 'No se eliminarán',
          ('es', _) => 'No se completarán',
          _ => 'No se suprimiran',
        });
        await tester.tap(_inResult(find.byTooltip(tooltip)));
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
        expect(find.text(strings.undo), findsOneWidget);
      });
    }

    testWidgets('UX-1717: ✕ on a one-task deletion still says «No se '
        'eliminará»', (tester) async {
      final app = await _App.open(
        tester,
        tasks: [
          Task(id: 9, title: 'Dentista', priority: 1, dueDate: day(2, 9)),
        ],
      );
      await app.showResult(tester, [
        command({
          'kind': 'delete',
          'target': {
            'words': ['dentista'],
          },
        }),
      ], transcript: 'Borra el dentista');
      expect(es.commandWontDelete(1), 'No se eliminará');
      await tester.tap(
        _inResult(find.byTooltip(es.commandDontDelete('Dentista'))),
      );
      await tester.pumpAndSettle();
      expect(find.text(es.commandWontDelete(1)), findsOneWidget);
      expect(find.text(es.undo), findsOneWidget);
    });

    testWidgets('UX-1717: ✕ on a counted 4-task deletion set still says '
        '«No se eliminarán»', (tester) async {
      final app = await _App.open(
        tester,
        tasks: _fourYesterday(),
        projects: [_casa],
      );
      await app.showResult(tester, [
        command({'kind': 'delete', 'target': setTarget(from: day(-1))}),
      ], transcript: 'Borra todas las de ayer');
      expect(_headline(tester), es.commandBulkDelete(4));
      expect(es.commandWontDelete(4), 'No se eliminarán');
      await tester.tap(_inResult(find.byTooltip(es.commandDontDeleteAny)));
      await tester.pumpAndSettle();
      expect(find.text(es.commandWontDelete(4)), findsOneWidget);
      expect(find.text(es.undo), findsOneWidget);
    });

    // ---------------------------------------------------- P229 · UX-1718
    testWidgets('UX-1718: at 2× on 360 dp, «Comprar pan» and a 3-task '
        'deletion: «Eliminar 3 tareas» and its ✕ in view, «Añadir y '
        'eliminar» below', (tester) async {
      final app = await _App.open(
        tester,
        tasks: _doneLastWeek(),
        textScale: 2,
        size: const Size(360, 800),
      );
      await app.showResult(
        tester,
        [_deleteDoneLastWeek()],
        drafts: [_newTask('Comprar pan', day(0))],
        transcript:
            'Apunta comprar pan y borra todas las completadas de la semana '
            'pasada',
      );
      expect(_inResult(find.text('Comprar pan')), findsWidgets);
      expect(_headline(tester), es.commandBulkDelete(3));
      expect(_headline(tester), 'Eliminar 3 tareas');
      expect(es.commandDontDeleteAny, 'No eliminar ninguna');
      expect(_buttonLabel(tester), es.commandAddAndDelete);
      expect(_buttonLabel(tester), 'Añadir y eliminar');
      expect(_button(tester).onPressed, isNotNull);
      // The set started below the fold: the sheet scrolled to its heading.
      expect(_resultOffset(tester), greaterThan(0));
      final view = _resultView(tester);
      _expectInside(
        view,
        tester.getRect(
          _inResult(find.byKey(const ValueKey('command-headline'))).first,
        ),
        'the set’s heading',
      );
      _expectInside(
        view,
        tester.getRect(_inResult(find.byTooltip(es.commandDontDeleteAny))),
        'the set’s ✕',
      );
      // The button sits below the cards.
      expect(
        tester.getRect(find.byKey(const ValueKey('save-drafts'))).top,
        greaterThanOrEqualTo(view.bottom - 0.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('UX-1718: the lone 3-task deletion at 2× on 360 dp still '
        'opens at offset 0, its heading and ✕ in view (UX-1704)', (
      tester,
    ) async {
      final app = await _App.open(
        tester,
        tasks: _doneLastWeek(),
        textScale: 2,
        size: const Size(360, 800),
      );
      await app.showResult(tester, [
        _deleteDoneLastWeek(),
      ], transcript: 'Borra todas las completadas de la semana pasada');
      expect(_headline(tester), es.commandBulkDelete(3));
      expect(_resultOffset(tester), 0);
      final view = _resultView(tester);
      _expectInside(
        view,
        tester.getRect(
          _inResult(find.byKey(const ValueKey('command-headline'))).first,
        ),
        'the heading',
      );
      _expectInside(
        view,
        tester.getRect(_inResult(find.byTooltip(es.commandDontDeleteAny))),
        'the ✕',
      );
    });

    for (final title in [
      'Comprar pan',
      // Long enough that the deletion starts below the fold.
      'Comprar pan, leche, huevos, fruta y verdura para toda la semana en el '
          'mercado del barrio antes de que cierre',
    ]) {
      testWidgets(
        'UX-1718: at 2× on 360 dp, «${title.length > 20 ? 'a long new task' : title}» and «Borra el '
        'dentista»: the deletion card’s bottom edge just above the buttons',
        (tester) async {
          final app = await _App.open(
            tester,
            tasks: [
              Task(id: 9, title: 'Dentista', priority: 1, dueDate: day(2, 9)),
            ],
            textScale: 2,
            size: const Size(360, 800),
          );
          await app.showResult(
            tester,
            [
              command({
                'kind': 'delete',
                'target': {
                  'words': ['dentista'],
                },
              }),
            ],
            drafts: [_newTask(title, day(0))],
            transcript: 'Apunta comprar pan y borra el dentista',
          );
          expect(_buttonLabel(tester), es.commandAddAndDelete);
          final card = tester.getRect(
            find
                .ancestor(
                  of: _inResult(find.byKey(const ValueKey('command-headline'))),
                  matching: find.byType(Material),
                )
                .first,
          );
          final view = _resultView(tester);
          _expectInside(view, card, 'the deletion’s card');
          expect(
            card.bottom,
            lessThanOrEqualTo(
              tester.getRect(find.byKey(const ValueKey('save-drafts'))).top,
            ),
          );
          // It started below the fold, so the sheet scrolled to it: its bottom
          // edge sits at the bottom of the view, above the list's own end
          // padding, as before round 1.
          if (title.length > 20) {
            expect(_resultOffset(tester), greaterThan(0));
            expect(
              card.bottom,
              closeTo(view.bottom, 16),
              reason: '$card in $view',
            );
          }
        },
      );
    }
  });
}

// ---- UX loop 2026-10-21-changes, round 3 ---------------------------------
//
// P230 (UX-1719): answering a deletion set's «¿Qué proyecto?» keeps its
// heading and ✕ in view, even when the answered card is taller than the view.

/// Five completed tasks in Matemáticas and one in Matemáticas II, yesterday:
/// enough that the answered set's card is taller than the view at 2×.
List<Task> _fiveMathsDone() => [
  for (final (id, title) in [
    (1, 'Corregir los ejercicios'),
    (2, 'Preparar el examen del tema 6'),
    (3, 'Repasar las derivadas'),
    (4, 'Hacer la hoja de integrales'),
    (5, 'Entregar el trabajo de estadística'),
  ])
    Task(
      id: id,
      title: title,
      priority: 1,
      dueDate: day(-1, 8 + id),
      listId: 'maths',
      isCompleted: true,
    ),
  Task(
    id: 6,
    title: 'Leer el tema 2',
    priority: 1,
    dueDate: day(-1, 16),
    listId: 'maths2',
    isCompleted: true,
  ),
];

Rect _setCard(WidgetTester tester) => tester.getRect(
  find
      .ancestor(
        of: _inResult(find.byKey(const ValueKey('command-headline'))),
        matching: find.byType(Material),
      )
      .first,
);

void _round20261021Third() {
  group('UX loop 2026-10-21-changes, round 3', () {
    setUpAll(() async {
      // Positions are measured with the app's own font.
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    });

    Future<void> openAskingDeletion(WidgetTester tester) async {
      final app = await _App.open(
        tester,
        tasks: _fiveMathsDone(),
        projects: [_maths, _mathsTwo],
        textScale: 2,
        size: const Size(360, 800),
      );
      await app.showResult(tester, [
        _askingSet('delete', status: 'completed'),
      ], transcript: 'Borra todas las completadas de mates');
    }

    // ---------------------------------------------------- P230 · UX-1719
    testWidgets('UX-1719: at 2× on 360 dp, before any chip is tapped, '
        '«¿Qué proyecto?» and both chips are in view and the button is '
        'disabled', (tester) async {
      await openAskingDeletion(tester);
      final view = _resultView(tester);
      _expectInside(
        view,
        tester.getRect(_inResult(find.text(es.commandWhichProjectOfTasks))),
        '«¿Qué proyecto?»',
      );
      expect(_projectChips(tester), hasLength(2));
      for (final id in ['maths', 'maths2']) {
        _expectInside(
          view,
          tester.getRect(find.byKey(ValueKey('command-project-$id'))),
          'the $id chip',
        );
      }
      for (final name in ['Matemáticas', 'Matemáticas II']) {
        expect(
          find.descendant(
            of: _inResult(find.byType(ChoiceChip)),
            matching: find.text(name),
          ),
          findsOneWidget,
        );
      }
      expect(_button(tester).onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('UX-1719: at 2× on 360 dp, tapping «Matemáticas» on a '
        'deletion set keeps «Eliminar 5 tareas» and its ✕ in view', (
      tester,
    ) async {
      await openAskingDeletion(tester);
      final chip = find.byKey(const ValueKey('command-project-maths'));
      _expectInside(_resultView(tester), tester.getRect(chip), 'the chip');
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(_headline(tester), es.commandBulkDelete(5));
      expect(es.commandDontDeleteAny, 'No eliminar ninguna');
      expect(_button(tester).onPressed, isNotNull);
      // The case at hand: the answered card is taller than the view.
      final view = _resultView(tester);
      final card = _setCard(tester);
      expect(card.height, greaterThan(view.height), reason: '$card in $view');
      // The question box stays after the tap (P225), below the heading: had
      // the sheet scrolled it to the top, the heading would sit above view.
      expect(_inResult(find.text(es.commandWhichProjectOfTasks)), findsOne);
      expect(
        tester.getRect(_inResult(find.text(es.commandWhichProjectOfTasks))).top,
        greaterThan(
          tester
              .getRect(
                _inResult(find.byKey(const ValueKey('command-headline'))).first,
              )
              .bottom,
        ),
      );
      _expectInside(
        view,
        tester.getRect(
          _inResult(find.byKey(const ValueKey('command-headline'))).first,
        ),
        'the set’s heading',
      );
      _expectInside(
        view,
        tester.getRect(_inResult(find.byTooltip(es.commandDontDeleteAny))),
        'the set’s ✕',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
