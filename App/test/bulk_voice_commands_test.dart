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
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/providers/theme_provider.dart';
import 'package:agenda/screens/voice_task_screen.dart';
import 'package:agenda/services/bulk_plan.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/command_plan.dart';
import 'package:agenda/services/invitation_links.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/task_list_store.dart';
import 'package:agenda/services/task_matcher.dart';
import 'package:agenda/widgets/attachment_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:uuid/uuid.dart';

import 'support/capture_fixtures.dart';
import 'support/design_fixtures.dart';

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

({List<Task> tasks, int repeating, Task? viewOnly}) _set(
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
  }) async {
    tester.view.physicalSize = const Size(390, 844);
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
        taskRepositoryProvider.overrideWithValue(MemoryTasks()),
        taskProvider.overrideWith((ref) => memory),
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
  }) async {
    final session = CaptureSession(
      id: const Uuid().v4(),
      ownerKey: container.read(captureOwnerProvider),
      timezone: 'Europe/Madrid',
      capturedAt: DateTime.now().toUtc(),
      status: 'ready',
      source: 'speech',
      transcript: transcript,
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

/// The weekday and day of the month, as the heading names tomorrow.
String _short(DateTime date, String language) =>
    DateFormat('E d', language).format(date);

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
      // One line for what was left out.
      expect(find.text(es.commandBulkLeftRepeating(1, 'change')), findsOne);
      expect(
        es.commandBulkLeftRepeating(2, 'change'),
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
      expect(find.text(es.commandTasksMoved(2)), findsOneWidget);
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
      expect(find.text(es.commandTasksMoved(2)), findsOneWidget);
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
          '${es.commandBulkLeftRepeating(1, 'change')} · '
          '${es.commandBulkLeftUnassignable(2, 'Paul')}',
        ),
        findsOneWidget,
      );
      expect(_buttonLabel(tester), es.commandBulkAssign(1));
      await _confirm(tester);
      final report = app.tasks.byId(2)!;
      expect(report.assignment, 'member');
      expect(report.assigneeId, 3);
      expect(app.tasks.byId(1)!.assignment, 'personal');
      expect(find.text(es.commandTasksChanged(1)), findsOneWidget);
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
        'Son 230 tareas. Dilo con menos, por ejemplo un día o un proyecto.',
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
    testWidgets('«Marcar como hecha», then «Tarea completada» with Deshacer', (
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
      expect(find.text(es.commandTasksCompleted(1)), findsOneWidget);
      expect(es.commandTasksCompleted(1), es.taskCompleted);
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

    testWidgets('already done: «Ya está así», and nothing to tap', (
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
      expect(find.text(es.commandNothingToChange), findsOneWidget);
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
      expect(find.text(es.commandWontComplete), findsOneWidget);
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
      expect(find.text(es.commandBulkLeftNoDay(1)), findsOneWidget);
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
        'No hi ha tasques pendents d’ahir',
      );
      expect(
        en.commandBulkNone('open', en.commandBulkPeriod('yesterday', '', '')),
        'There are no unfinished tasks from yesterday',
      );
      expect(ca.commandTasksMoved(5), '5 tasques mogudes');
      expect(en.commandTasksMoved(1), 'Task moved');
      expect(
        ca.commandBulkLeftRepeating(2, 'change'),
        '2 tasques que es repeteixen no canvien',
      );
    });
  });
}
