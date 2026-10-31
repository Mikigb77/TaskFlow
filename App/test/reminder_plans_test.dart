// Reminder plans (Backend/docs/REMINDER_PLANS.md; DECISIONS.md «2026-10-22 —
// Reminder plans»): the field, its storage and sync, the plan logic and the
// plan in words. Unit tests; the notifications are in
// reminder_plan_engine_test.dart, the sheet in reminder_plan_sheet_test.dart.
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/l10n/reminder_plan_words.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/reminder_plan.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_archive.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/repositories/cloud_task_repository.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/capture_processor.dart';
import 'package:agenda/services/capture_store.dart';
import 'package:agenda/services/command_runner.dart';
import 'package:agenda/services/reminder_copy.dart';
import 'package:agenda/services/reminder_plans.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

AppLocalizations strings(String code) => lookupAppLocalizations(Locale(code));

/// Thursday 22 October 2026, 10:00: the day the owner decided plans.
final now = DateTime(2026, 10, 22, 10);

/// Friday 13 November, 22 days away.
final friday13 = DateTime(2026, 11, 13);

ReminderPlan custom(List<PlanPhase> phases, {String? time, String? said}) =>
    ReminderPlan.tryParse({
      'kind': 'custom',
      'phases': [for (final phase in phases) phase.toJson()],
      'time': time,
      'said': said,
    })!;

/// The owner's example: every 3 days the first two weeks, then daily.
final ownersPlan = custom(
  const [PlanPhase(21, 8, 3), PlanPhase(7, 0, 1)],
  time: '09:00',
  said: 'cada 3 días las dos primeras semanas y luego cada día',
);

Task dayTask({
  int? id = 1,
  DateTime? day,
  DateTime? deadline,
  ReminderPlan? plan,
  String recurrence = 'none',
  bool done = false,
  int? minutes,
}) => Task(
  id: id,
  title: 'Presentar el proyecto',
  priority: 1,
  dueDate: day,
  hasTime: false,
  deadline: deadline,
  reminderAnchor: day == null && deadline != null ? 'deadline' : 'planned',
  recurrence: recurrence,
  reminderPlan: plan,
  isCompleted: done,
  reminderMinutes: minutes,
);

void main() {
  sqfliteFfiInit();
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('ca');
    await initializeDateFormatting('en');
  });

  group('the field: reminder_plan', () {
    test('a strength reads and writes the contract’s shape', () {
      const plan = ReminderPlan.rhythm(ReminderPlan.normal);
      expect(plan.toJson(), {
        'kind': 'rhythm',
        'strength': 'normal',
        'time': null,
      });
      expect(ReminderPlan.tryParse(plan.toJson()), plan);
      expect(
        ReminderPlan.tryParse({
          'kind': 'rhythm',
          'strength': 'intense',
          'time': '07:30',
        })!.time,
        450,
      );
    });

    test('a plan of one’s own keeps its phases, time and words', () {
      expect(ownersPlan.toJson(), {
        'kind': 'custom',
        'phases': [
          {'from_days': 21, 'to_days': 8, 'every_days': 3},
          {'from_days': 7, 'to_days': 0, 'every_days': 1},
        ],
        'time': '09:00',
        'said': 'cada 3 días las dos primeras semanas y luego cada día',
      });
      expect(ReminderPlan.decode(ownersPlan.encode()), ownersPlan);
      // Keys in another order, as Postgres may send them, read the same.
      expect(
        ReminderPlan.tryParse({
          'said': ownersPlan.said,
          'time': '09:00',
          'phases': [
            {'every_days': 3, 'to_days': 8, 'from_days': 21},
            {'to_days': 0, 'every_days': 1, 'from_days': 7},
          ],
          'kind': 'custom',
        }),
        ownersPlan,
      );
    });

    test('anything but the contract’s shape is no plan', () {
      for (final bad in <Object?>[
        null,
        'normal',
        {'kind': 'rhythm', 'strength': 'strong', 'time': null},
        {'kind': 'weekly', 'strength': 'normal', 'time': null},
        {'kind': 'rhythm', 'strength': 'normal', 'time': '9:00'},
        {'kind': 'rhythm', 'strength': 'normal', 'time': '24:00'},
        {'kind': 'custom', 'phases': [], 'time': null},
        {
          'kind': 'custom',
          'phases': List.filled(5, {
            'from_days': 3,
            'to_days': 0,
            'every_days': 1,
          }),
          'time': null,
        },
        {
          'kind': 'custom',
          'phases': [
            {'from_days': 2, 'to_days': 3, 'every_days': 1},
          ],
          'time': null,
        },
        {
          'kind': 'custom',
          'phases': [
            {'from_days': 367, 'to_days': 0, 'every_days': 1},
          ],
          'time': null,
        },
        {
          'kind': 'custom',
          'phases': [
            {'from_days': 10, 'to_days': 0, 'every_days': 31},
          ],
          'time': null,
        },
        {
          'kind': 'custom',
          'phases': [
            {'from_days': 10.0, 'to_days': 0, 'every_days': 1},
          ],
          'time': null,
        },
      ]) {
        expect(ReminderPlan.tryParse(bad), isNull, reason: '$bad');
      }
      expect(ReminderPlan.decode('{not json'), isNull);
    });

    test(
      'copyWith keeps the plan, and every way a task is copied carries it',
      () {
        final task = dayTask(day: friday13, plan: ownersPlan);
        expect(task.copyWith(title: 'Otro').reminderPlan, ownersPlan);
        expect(task.copyWith(reminderPlan: null).reminderPlan, isNull);
        expect(Task.fromMap(task.toMap()).reminderPlan, ownersPlan);
        expect(Task.fromApi(task.toApi()).reminderPlan, ownersPlan);
        expect(
          task.toApi()['reminder_plan'],
          ownersPlan.toJson(),
          reason: 'The API field is the JSON itself.',
        );
        expect(
          task.toMap()['reminderPlan'],
          ownersPlan.encode(),
          reason: 'The local column keeps the JSON as text.',
        );
        // A voice command's undo puts back the fields it wrote.
        final written = task.copyWith(reminderPlan: null);
        final current = written.copyWith(notes: 'Llevar el portátil');
        final restored = restoreFields(current, task, written);
        expect(restored.reminderPlan, ownersPlan);
        expect(restored.notes, 'Llevar el portátil');
      },
    );

    test('a note never has a plan', () {
      expect(
        () => Task(
          title: 'Nota',
          kind: 'note',
          priority: 1,
          reminderPlan: const ReminderPlan.rhythm(ReminderPlan.normal),
        ),
        throwsArgumentError,
      );
      final note = Task(title: 'Nota', kind: 'note', priority: 1);
      expect(
        Task.fromApi({
          ...note.toApi(),
          'reminder_plan': ownersPlan.toJson(),
        }).reminderPlan,
        isNull,
      );
    });

    test('a task copied out and back in by the archive keeps its plan', () {
      final task = dayTask(id: 5, day: friday13, plan: ownersPlan);
      final text = TaskArchive.encode([
        {...task.toMap(), 'sync_id': '6f1c2a40-8a8f-4f53-9d8b-1df7c35f1e01'},
      ], const []);
      final archive = TaskArchive.parse(text);
      expect(archive.tasks.single.warnings, isEmpty);
      expect(archive.tasks.single.task!.reminderPlan, ownersPlan);
    });
  });

  group('stored and synced', () {
    late TaskDatabase database;
    setUp(() async {
      final sql = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await sql.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
      );
      await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
      database = TaskDatabase.forTesting(sql);
    });
    tearDown(() => database.close());

    test(
      'schema 18 upgrades add the plan’s column and keep every task with its single reminder',
      () async {
        final old = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(singleInstance: false),
        );
        addTearDown(old.close);
        await old.execute(
          'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
        );
        await TaskDatabase.upgrade(old, 3, 18);
        final row = dayTask(day: friday13, minutes: 60).toMap()
          ..remove('id')
          ..remove('reminderPlan');
        await old.insert('tasks', {...row, 'sync_id': 'kept', 'revision': 4});
        await TaskDatabase.upgrade(old, 18, TaskDatabase.schemaVersion);
        expect(TaskDatabase.schemaVersion, 19);
        final columns = (await old.rawQuery(
          'PRAGMA table_info(tasks)',
        )).map((row) => row['name']).toSet();
        expect(columns, contains('reminderPlan'));
        final upgraded = TaskDatabase.forTesting(old);
        final task = (await upgraded.getTasks()).single;
        expect(task.title, 'Presentar el proyecto');
        expect(task.reminderMinutes, 60);
        expect(task.reminderPlan, isNull);
        final rows = await old.query('tasks');
        expect(rows.single['revision'], 4);
        expect(rows.single['sync_id'], 'kept');
      },
    );

    test(
      'a plan is saved, updated and restored with its task on this phone',
      () async {
        final id = await database.insertTask(
          dayTask(id: null, day: friday13, plan: ownersPlan),
        );
        var task = (await database.getTasks()).single;
        expect(task.reminderPlan, ownersPlan);
        await database.updateTask(
          task.copyWith(
            reminderPlan: const ReminderPlan.rhythm(ReminderPlan.gentle),
          ),
        );
        task = (await database.getTasks()).single;
        expect(task.reminderPlan!.strength, ReminderPlan.gentle);
        await database.deleteTask(id);
        expect(await database.getTasks(), isEmpty);
        await database.restoreTask(task);
        expect(
          (await database.getTasks()).single.reminderPlan!.strength,
          ReminderPlan.gentle,
        );
      },
    );

    test(
      'sync sends reminder_plan, reads it back, and a server without plans leaves the phone’s',
      () async {
        const owner = 'http://localhost:8088/users/1';
        final api = _Api();
        addTearDown(api.close);
        final repository = CloudTaskRepository(database, api, 1);
        await repository.addTask(
          dayTask(id: null, day: friday13, plan: ownersPlan),
        );
        await repository.sync();
        expect(api.uploads.single['reminder_plan'], ownersPlan.toJson());
        // Always sent: null clears it on the server.
        final id = (await repository.getAllTasks()).single.id;
        await repository.updateTask(
          (await repository.getAllTasks()).single.copyWith(reminderPlan: null),
        );
        await repository.sync();
        expect(api.uploads.last.containsKey('reminder_plan'), isTrue);
        expect(api.uploads.last['reminder_plan'], isNull);
        // Another phone set a strength: it arrives.
        api.remote[0] = {
          ...api.remote.single,
          'reminder_plan': {
            'time': null,
            'strength': 'intense',
            'kind': 'rhythm',
          },
          'version': (api.remote.single['version'] as int) + 1,
        };
        await repository.sync();
        expect(
          (await repository.getAllTasks()).single.reminderPlan,
          const ReminderPlan.rhythm(ReminderPlan.intense),
        );
        // A server that doesn't know plans yet sends none: kept.
        api.remote[0] = {...api.remote.single}..remove('reminder_plan');
        api.remote[0]['version'] = (api.remote.single['version'] as int) + 1;
        await repository.sync();
        final kept = (await repository.getAllTasks()).single;
        expect(kept.id, id);
        expect(
          kept.reminderPlan,
          const ReminderPlan.rhythm(ReminderPlan.intense),
        );
        expect(owner, repository.ownerKey);
      },
    );

    test(
      'a conflict whose only difference is the plan’s key order is no conflict',
      () async {
        final api = _Api();
        addTearDown(api.close);
        final repository = CloudTaskRepository(database, api, 1);
        await repository.addTask(
          dayTask(id: null, day: friday13, plan: ownersPlan),
        );
        await repository.sync();
        // The server has the same plan, keys in another order, at a newer
        // version: the phone's edit is the same, so no offline copy.
        final reordered = Map<String, dynamic>.fromEntries(
          (ownersPlan.toJson().entries.toList()).reversed,
        );
        api.remote[0] = {
          ...api.remote.single,
          'reminder_plan': reordered,
          'version': (api.remote.single['version'] as int) + 1,
        };
        final task = (await repository.getAllTasks()).single;
        await database.updateTask(task, ownerKey: repository.ownerKey);
        await repository.sync();
        final tasks = await repository.getAllTasks();
        expect(tasks.length, 1, reason: 'No offline copy.');
        expect(tasks.single.reminderPlan, ownersPlan);
      },
    );

    test(
      'a dictated draft puts reminder_plan and reminder_minutes on the drafted task',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'taskflow-plan-test-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final store = CaptureStore(database, directory: directory);
        final session = await store.create(
          'local',
          'Europe/Madrid',
          now: now.toUtc(),
          text: 'Presentar el proyecto el 13 de noviembre, recuérdamelo…',
        );
        final api = _DraftsApi({
          'transcript': session.text,
          'tasks': [
            {
              'title': 'Presentar el proyecto',
              'scheduled_date': '2026-11-13',
              'priority': 1,
              'notes': '',
              'questions': [],
              'reminder_plan': ownersPlan.toJson(),
              'reminder_minutes': null,
            },
            {
              'title': 'Llamar al dentista',
              'due_date': DateTime(2026, 10, 27, 10).toUtc().toIso8601String(),
              'priority': 1,
              'notes': '',
              'questions': [],
              'reminder_plan': null,
              'reminder_minutes': 60,
            },
            {
              'title': 'Comprar pan',
              'priority': 1,
              'notes': '',
              'questions': [],
            },
          ],
        });
        addTearDown(api.close);
        final result = await CaptureProcessor(
          store,
          api,
        ).process(session, now: now);
        final tasks = result.drafts.map((draft) => draft.task).toList();
        expect(tasks[0].reminderPlan, ownersPlan);
        expect(tasks[0].reminderMinutes, isNull);
        expect(tasks[1].reminderPlan, isNull);
        expect(tasks[1].reminderMinutes, 60);
        // An older server sends neither: no plan, the single default.
        expect(tasks[2].reminderPlan, isNull);
        expect(tasks[2].reminderMinutes, isNull);
        // Kept with the capture until it's saved.
        final reread = (await store.read(session.id, 'local'))!;
        expect(reread.drafts.first.task.reminderPlan, ownersPlan);
      },
    );
  });

  test(
    'minutes said for a task with only a day are left out, and a note takes no reminder',
    () {
      Task drafted(Map<String, dynamic> extra) => CaptureDraft.fromAI(
        TaskDraft.fromJson({
          'title': 'Algo',
          'priority': 1,
          'notes': '',
          'questions': [],
          'transcript': 'Algo',
          ...extra,
        }),
      ).task;
      expect(
        drafted({
          'scheduled_date': '2026-11-13',
          'reminder_minutes': 60,
        }).reminderMinutes,
        isNull,
      );
      expect(
        drafted({
          'deadline_at': DateTime(2026, 11, 13, 18).toUtc().toIso8601String(),
          'reminder_minutes': 30,
        }).reminderMinutes,
        30,
      );
      final note = drafted({
        'kind': 'note',
        'reminder_minutes': 30,
        'reminder_plan': ownersPlan.toJson(),
      });
      expect(note.reminderMinutes, isNull);
      expect(note.reminderPlan, isNull);
    },
  );

  group('the plan logic', () {
    test('the three strengths as phases, each with the day itself', () {
      List<int> near(String strength) =>
          ReminderPlan.rhythm(strength).days.where((day) => day <= 21).toList();
      expect(near(ReminderPlan.gentle), [0, 1, 2, 3, 4, 11, 18]);
      expect(near(ReminderPlan.normal), [
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        11,
        14,
        17,
        20,
      ]);
      expect(near(ReminderPlan.intense), [
        for (var day = 0; day <= 15; day++) day,
        17,
        19,
        21,
      ]);
      // The strengths start at most 4 weeks before the day (D2).
      expect(const ReminderPlan.rhythm(ReminderPlan.normal).days.last, 26);
    });

    test(
      'the anchor: the deadline, else the task’s own day; none, or a repeating task, has no plan',
      () {
        final both = dayTask(day: DateTime(2026, 11, 2), deadline: friday13);
        expect(ReminderPlans.anchor(both), friday13);
        expect(ReminderPlans.anchor(dayTask(day: friday13)), friday13);
        expect(ReminderPlans.plannable(dayTask()), isFalse);
        final repeating = dayTask(
          day: friday13,
          recurrence: 'weekly',
          plan: const ReminderPlan.rhythm(ReminderPlan.normal),
        );
        expect(ReminderPlans.plannable(repeating), isFalse);
        expect(ReminderPlans.active(repeating), isNull);
        expect(
          ReminderPlans.active(dayTask(day: friday13, plan: ownersPlan)),
          ownersPlan,
        );
      },
    );

    test(
      'the reminders still to come, the next one, the count, then one last notice the day after',
      () {
        const normal = ReminderPlan.rhythm(ReminderPlan.normal);
        final alerts = ReminderPlans.alerts(normal, friday13, 540, now);
        expect(alerts.first.when, DateTime(2026, 10, 24, 9));
        expect(alerts.first.daysBefore, 20);
        expect(alerts.where((alert) => !alert.late).length, 13);
        expect(alerts.last.late, isTrue);
        expect(alerts.last.when, DateTime(2026, 11, 14, 9));
        // Moving the day moves the whole plan.
        final later = ReminderPlans.alerts(
          normal,
          DateTime(2026, 11, 20),
          540,
          now,
        );
        expect(later.first.when, DateTime(2026, 10, 25, 9));
        expect(later.last.when, DateTime(2026, 11, 21, 9));
        // On the day, after its reminder: only the last notice is left.
        final onTheDay = ReminderPlans.alerts(
          normal,
          friday13,
          540,
          DateTime(2026, 11, 13, 12),
        );
        expect(onTheDay.single.late, isTrue);
        // Two days after: nothing more.
        expect(
          ReminderPlans.alerts(normal, friday13, 540, DateTime(2026, 11, 15)),
          isEmpty,
        );
      },
    );

    test(
      'the time: the plan’s, else Settings’ for all-day tasks, else 9:00',
      () {
        expect(ReminderPlans.minute(ownersPlan, 480), 540);
        const normal = ReminderPlan.rhythm(ReminderPlan.normal);
        expect(ReminderPlans.minute(normal, 480), 480);
        expect(ReminderPlans.minute(normal, null), 540);
        expect(
          ReminderPlans.taskAlerts(
            dayTask(day: friday13, plan: normal),
            480,
            now,
            defaultLead: 10,
          ).first.when,
          DateTime(2026, 10, 24, 8),
        );
        expect(
          ReminderPlans.taskAlerts(
            dayTask(day: friday13, plan: normal, done: true),
            480,
            now,
            defaultLead: 10,
          ),
          isEmpty,
          reason: 'Done: nothing more.',
        );
      },
    );

    test(
      'the offer: 14 days or more away, no plan, not repeating, not off',
      () {
        expect(
          ReminderPlans.offerable(dayTask(day: DateTime(2026, 11, 5)), now),
          isTrue,
        );
        expect(
          ReminderPlans.offerable(dayTask(day: DateTime(2026, 11, 4)), now),
          isFalse,
        );
        expect(
          ReminderPlans.offerable(
            dayTask(day: friday13, plan: ownersPlan),
            now,
          ),
          isFalse,
        );
        expect(
          ReminderPlans.offerable(
            dayTask(day: friday13, recurrence: 'monthly'),
            now,
          ),
          isFalse,
        );
        expect(
          ReminderPlans.offerable(dayTask(day: friday13, minutes: -1), now),
          isFalse,
        );
        expect(
          ReminderPlans.offerable(dayTask(day: friday13, done: true), now),
          isFalse,
        );
        expect(
          ReminderPlans.offerable(dayTask(deadline: friday13), now),
          isTrue,
        );
      },
    );
  });

  group('the plan in words', () {
    String rhythm(String code, ReminderPlan plan, {DateTime? anchor}) =>
        planRhythm(
          strings(code),
          plan,
          anchor: anchor ?? friday13,
          now: now,
          minute: 540,
        );

    test(
      'as the spec words it: «Cada 3 días, y a diario la última semana»',
      () {
        expect(
          rhythm('es', ownersPlan, anchor: DateTime(2026, 11, 12)),
          'Cada 3 días, y a diario la última semana',
        );
        expect(
          rhythm('ca', ownersPlan, anchor: DateTime(2026, 11, 12)),
          'Cada 3 dies, i cada dia l’última setmana',
        );
        expect(
          rhythm('en', ownersPlan, anchor: DateTime(2026, 11, 12)),
          'Every 3 days, and daily for the last week',
        );
        const normal = ReminderPlan.rhythm(ReminderPlan.normal);
        expect(
          rhythm('es', normal),
          'Cada 3 días, y a diario la última semana',
        );
        expect(
          rhythm('es', const ReminderPlan.rhythm(ReminderPlan.gentle)),
          'Cada semana, y a diario los últimos 3 días',
        );
        expect(
          rhythm('es', const ReminderPlan.rhythm(ReminderPlan.intense)),
          'Cada 2 días, y a diario las últimas 2 semanas',
        );
      },
    );

    test(
      'a phase says when it starts only when that’s further than its rhythm',
      () {
        // Starting tomorrow, as said three weeks ahead: no need to say it.
        expect(
          rhythm('es', ownersPlan),
          'Cada 3 días, y a diario la última semana',
        );
        // Starting in nine days: said.
        expect(
          rhythm('es', ownersPlan, anchor: DateTime(2026, 11, 21)),
          'Cada 3 días desde 3 semanas antes, y a diario la última semana',
        );
        expect(
          rhythm('en', ownersPlan, anchor: DateTime(2026, 11, 21)),
          'Every 3 days from 3 weeks before, and daily for the last week',
        );
      },
    );

    test('only what is still to come is said', () {
      const normal = ReminderPlan.rhythm(ReminderPlan.normal);
      // Five days away: only the daily part is left.
      expect(rhythm('es', normal, anchor: DateTime(2026, 10, 27)), 'A diario');
      expect(rhythm('ca', normal, anchor: DateTime(2026, 10, 27)), 'Cada dia');
      expect(rhythm('en', normal, anchor: DateTime(2026, 10, 27)), 'Daily');
    });

    test('single reminders, windows and three parts', () {
      expect(
        rhythm('es', custom(const [PlanPhase(1, 1, 1)], time: '09:00')),
        'El día antes',
      );
      expect(
        rhythm('es', custom(const [PlanPhase(7, 7, 1), PlanPhase(1, 1, 1)])),
        'Una semana antes, y el día antes',
      );
      expect(
        rhythm('en', custom(const [PlanPhase(1, 1, 1), PlanPhase(0, 0, 1)])),
        'The day before, and on the day',
      );
      expect(
        rhythm('es', custom(const [PlanPhase(10, 0, 2)])),
        'Cada 2 días los últimos 10 días',
      );
      expect(
        rhythm(
          'es',
          custom(const [
            PlanPhase(30, 15, 5),
            PlanPhase(14, 8, 2),
            PlanPhase(7, 0, 1),
          ]),
          anchor: DateTime(2026, 11, 21),
        ),
        'Cada 5 días, cada 2 días desde 2 semanas antes, y a diario la última semana',
      );
      expect(
        rhythm('ca', custom(const [PlanPhase(14, 8, 2)])),
        'Cada 2 dies des de 2 setmanes abans fins a 8 dies abans',
      );
    });

    test(
      'on the task: «Recordatorios normales hasta el vie 13 · próximo: sáb 24, 9:00»',
      () {
        const normal = ReminderPlan.rhythm(ReminderPlan.normal);
        String clock(DateTime time) =>
            '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
        String line(
          String code,
          ReminderPlan plan, {
          DateTime? anchor,
          bool done = false,
          bool bare = false,
        }) => planLine(
          strings(code),
          plan,
          anchor: anchor ?? friday13,
          now: now,
          minute: 540,
          locale: code,
          clock: clock,
          done: done,
          bare: bare,
        );
        expect(
          line('es', normal),
          'Recordatorios normales hasta el vie\u00a013 · próximo: sáb\u00a024, 9:00',
        );
        expect(
          line('ca', normal),
          'Recordatoris normals fins al dv.\u00a013 · proper: ds.\u00a024, 9:00',
        );
        expect(
          line('en', normal),
          'Normal reminders until Fri\u00a013 · next: Sat\u00a024, 9:00',
        );
        expect(
          line('es', const ReminderPlan.rhythm(ReminderPlan.intense)),
          startsWith('Recordatorios intensos hasta el vie\u00a013 · próximo: '),
        );
        expect(
          line('es', const ReminderPlan.rhythm(ReminderPlan.gentle)),
          startsWith('Recordatorios suaves hasta el vie\u00a013 · próximo: '),
        );
        expect(
          line('es', ownersPlan, anchor: DateTime(2026, 11, 12)),
          'Recordatorios: cada 3 días, y a diario la última semana · próximo: mañana, 9:00',
        );
        // After a person's name: the plan alone, lowercase.
        expect(
          line('es', ownersPlan, anchor: DateTime(2026, 11, 12), bare: true),
          'cada 3 días, y a diario la última semana · próximo: mañana, 9:00',
        );
        expect(
          line('es', normal, bare: true),
          'cada vez más a menudo hasta el vie\u00a013 · próximo: sáb\u00a024, 9:00',
        );
        // A task that's done reads as its plan alone.
        expect(
          line('es', normal, done: true),
          'Recordatorios normales hasta el vie\u00a013',
        );
        // Tomorrow and today read as words.
        expect(
          line('es', normal, anchor: DateTime(2026, 10, 23)),
          'Recordatorios normales hasta mañana · próximo: mañana, 9:00',
        );
        // Far days carry their month.
        expect(
          planDay(DateTime(2027, 1, 14), now, 'es'),
          'jue,\u00a014\u00a0ene',
        );
      },
    );

    test('the preview’s count: «13 avisos · próximo: sáb 24, 9:00»', () {
      String count(String code, {DateTime? at}) => planCount(
        strings(code),
        const ReminderPlan.rhythm(ReminderPlan.normal),
        anchor: friday13,
        now: at ?? now,
        minute: 540,
        locale: code,
        clock: (time) =>
            '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
      );
      expect(count('es'), '13 avisos · próximo: sáb\u00a024, 9:00');
      expect(count('ca'), '13 avisos · proper: ds.\u00a024, 9:00');
      expect(count('en'), '13 reminders · next: Sat\u00a024, 9:00');
      expect(
        count('es', at: DateTime(2026, 11, 12, 10)),
        '1 aviso: mañana, 9:00',
      );
      expect(
        count('es', at: DateTime(2026, 11, 13, 10)),
        'Ya no quedan avisos',
      );
    });

    test(
      'the notices: «faltan 12 días · jue, 12 nov», «es mañana», «es hoy», then «era para ayer» or «venció ayer»',
      () async {
        Future<ReminderCopy> copy(String code) async => ReminderCopy(
          strings(code),
          await RegionalMaterialDelegate(
            const RegionalPreferences(),
            Locale(code),
            system24Hour: true,
          ).load(Locale(code)),
          use24: true,
        );
        // Thursday 12 November, without a time.
        final task = Task(
          title: 'Presentar el proyecto',
          priority: 1,
          dueDate: DateTime(2026, 11, 12),
          hasTime: false,
        );
        final deadline = task.copyWith(deadline: DateTime(2026, 11, 12));
        final es = await copy('es');
        expect(es.planBody(task, 12), 'Faltan 12 días · jue, 12 nov');
        expect(es.planBody(task, 1), 'Es mañana');
        expect(es.planBody(task, 0), 'Es hoy');
        expect(es.planBody(task, -1), 'Era para ayer');
        expect(es.planBody(deadline, -1), 'Venció ayer');
        final ca = await copy('ca');
        expect(ca.planBody(task, 12), 'Falten 12 dies · dj., 12 de nov.');
        expect(ca.planBody(task, 1), 'És demà');
        expect(ca.planBody(task, 0), 'És avui');
        expect(ca.planBody(task, -1), 'Era per a ahir');
        expect(ca.planBody(deadline, -1), 'Va vèncer ahir');
        final en = await copy('en');
        expect(en.planBody(task, 12), '12 days left · Thu, Nov 12');
        expect(en.planBody(task, -1), 'It was planned for yesterday');
        expect(en.planBody(deadline, -1), 'It was due yesterday');
      },
    );

    group('UX-2005, UX-2012: a plan notice says the day and its time', () {
      /// The copy a notification is written in, with a 24-hour or a 12-hour
      /// clock, as `readReminderCopy` builds it.
      Future<ReminderCopy> copy(String code, {bool use24 = true}) async =>
          ReminderCopy(
            strings(code),
            await RegionalMaterialDelegate(
              RegionalPreferences(
                clock: use24 ? ClockFormat.twentyFour : ClockFormat.twelve,
              ),
              Locale(code),
            ).load(Locale(code)),
            use24: use24,
          );

      // «Presentar el proyecto» on Thursday 12 November 2026.
      Task day({int? hour}) => Task(
        title: 'Presentar el proyecto',
        priority: 1,
        dueDate: DateTime(2026, 11, 12, hour ?? 0),
        hasTime: hour != null,
      );
      Task due({int? hour}) => Task(
        title: 'Presentar el proyecto',
        priority: 1,
        deadline: DateTime(2026, 11, 12, hour ?? 0),
        deadlineHasTime: hour != null,
        reminderAnchor: 'deadline',
      );

      test(
        'UX-2005: a day without a time, 12 days before, gives the date in es, en and ca',
        () async {
          expect(
            (await copy('es')).planBody(day(), 12),
            'Faltan 12 días · jue, 12 nov',
          );
          expect(
            (await copy('en')).planBody(day(), 12),
            '12 days left · Thu, Nov 12',
          );
          expect(
            (await copy('ca')).planBody(day(), 12),
            'Falten 12 dies · dj., 12 de nov.',
          );
        },
      );

      test(
        'UX-2005: a day at 17:00, 12 days before, adds the time; 12-hour English “5:00 PM”',
        () async {
          expect(
            (await copy('es')).planBody(day(hour: 17), 12),
            'Faltan 12 días · jue, 12 nov, 17:00',
          );
          expect(
            (await copy('en', use24: false)).planBody(day(hour: 17), 12),
            '12 days left · Thu, Nov 12, 5:00 PM',
          );
        },
      );

      test(
        'UX-2005: a day at 17:00 reads «Es mañana a las 17:00» and «Es hoy a las 17:00»',
        () async {
          final es = await copy('es');
          expect(es.planBody(day(hour: 17), 1), 'Es mañana a las 17:00');
          expect(es.planBody(day(hour: 17), 0), 'Es hoy a las 17:00');
          expect(
            (await copy('ca')).planBody(day(hour: 17), 1),
            'És demà a les 17:00',
          );
          expect(
            (await copy('en', use24: false)).planBody(day(hour: 17), 1),
            'It’s tomorrow at 5:00 PM',
          );
        },
      );

      test(
        'UX-2005: at 13:00 on a 12-hour clock Spanish says «a la 1:00»',
        () async {
          final es = await copy('es', use24: false);
          expect(
            es.planBody(day(hour: 13), 1),
            startsWith('Es mañana a la 1:00'),
          );
          expect(es.planBody(day(hour: 13), 0), startsWith('Es hoy a la 1:00'));
          expect(es.planBody(day(hour: 13), 0), isNot(contains('a las')));
        },
      );

      test(
        'UX-2005, UX-2012: without a time, «Es mañana» and «Es hoy»; the day after, «Era para ayer» and “It was planned for yesterday”',
        () async {
          final es = await copy('es');
          expect(es.planBody(day(), 1), 'Es mañana');
          expect(es.planBody(day(), 0), 'Es hoy');
          expect(es.planBody(day(), -1), 'Era para ayer');
          expect(es.planBody(day(hour: 17), -1), 'Era para ayer');
          expect(
            (await copy('en')).planBody(day(), -1),
            'It was planned for yesterday',
          );
          expect(
            strings('en').reminderPlanNoticeWas,
            'It was planned for yesterday',
          );
          // Spanish and Catalan keep the owner's words.
          expect(strings('es').reminderPlanNoticeWas, 'Era para ayer');
          expect(strings('ca').reminderPlanNoticeWas, 'Era per a ahir');
        },
      );

      test(
        'UX-2005: a deadline 12 days ahead reads «Fecha límite: jue, 12 nov · faltan 12 días» in es, en and ca',
        () async {
          expect(
            (await copy('es')).planBody(due(), 12),
            'Fecha límite: jue, 12 nov · faltan 12 días',
          );
          expect(
            (await copy('en')).planBody(due(), 12),
            'Deadline: Thu, Nov 12 · 12 days left',
          );
          expect(
            (await copy('ca')).planBody(due(), 12),
            'Termini: dj., 12 de nov. · falten 12 dies',
          );
          expect(
            (await copy('es')).planBody(due(hour: 17), 12),
            'Fecha límite: jue, 12 nov, 17:00 · faltan 12 días',
          );
        },
      );

      test(
        'UX-2005: a deadline tomorrow and today: «Fecha límite: mañana», «Fecha límite: hoy», «… mañana a las 17:00»; the day after, «Venció ayer»',
        () async {
          final es = await copy('es');
          expect(es.planBody(due(), 1), 'Fecha límite: mañana');
          expect((await copy('en')).planBody(due(), 1), 'Deadline: tomorrow');
          expect((await copy('ca')).planBody(due(), 1), 'Termini: demà');
          expect(es.planBody(due(), 0), 'Fecha límite: hoy');
          expect(
            es.planBody(due(hour: 17), 1),
            'Fecha límite: mañana a las 17:00',
          );
          expect(es.planBody(due(), -1), 'Venció ayer');
          expect(es.planBody(due(hour: 17), -1), 'Venció ayer');
        },
      );
    });

    test('the offer: «Faltan 3 semanas. ¿Te aviso cada 3 días, …?»', () {
      const es = 'cada 3 días, y a diario la última semana';
      expect(
        planOffer(strings('es'), 21, es),
        'Faltan 3 semanas. ¿Te aviso cada 3 días, y a diario la última '
        'semana?',
      );
      expect(
        planOffer(strings('es'), 14, es),
        'Faltan 2 semanas. ¿Te aviso cada 3 días, y a diario la última '
        'semana?',
      );
      expect(
        planOffer(strings('es'), 90, es),
        'Faltan 3 meses. ¿Te aviso cada 3 días, y a diario la última semana?',
      );
      expect(
        planOffer(
          strings('ca'),
          21,
          'cada 3 dies, i cada dia l’última setmana',
        ),
        'Falten 3 setmanes. T’aviso cada 3 dies, i cada dia l’última '
        'setmana?',
      );
      expect(
        planOffer(
          strings('en'),
          21,
          'every 3 days, and daily for the last week',
        ),
        '3 weeks to go. Shall I remind you every 3 days, and daily for the '
        'last week?',
      );
    });
  });

  // P253 (UX-1912, the owner's D2): the strengths start at most 4 weeks
  // before the day; a rhythm said or typed keeps its reach.
  group('P253 · UX-1912', () {
    const gentle = ReminderPlan.rhythm(ReminderPlan.gentle);
    const normal = ReminderPlan.rhythm(ReminderPlan.normal);
    const intense = ReminderPlan.rhythm(ReminderPlan.intense);

    /// Monday 21 December 2026, 60 days away.
    final monday21 = DateTime(2026, 12, 21);

    /// Thursday 12 November, 21 days away: the owner's 3-week example.
    final thursday12 = DateTime(2026, 11, 12);

    List<PlanAlert> ahead(ReminderPlan plan, DateTime anchor) =>
        ReminderPlans.alerts(plan, anchor, 540, now, late: false);

    test('UX-1912: each strength starts at most 28 days before the day: '
        'Suave 8 days, Normal 15, Intenso 22', () {
      expect(normal.days, [
        for (var day = 0; day <= 7; day++) day,
        8,
        11,
        14,
        17,
        20,
        23,
        26,
      ]);
      expect(normal.days, hasLength(15));
      expect(gentle.days, [0, 1, 2, 3, 4, 11, 18, 25]);
      expect(intense.days, [
        for (var day = 0; day <= 14; day++) day,
        15,
        17,
        19,
        21,
        23,
        25,
        27,
      ]);
      expect(intense.days, hasLength(22));
      for (final plan in [gentle, normal, intense]) {
        expect(
          plan.days.every((day) => day <= 28),
          isTrue,
          reason: plan.strength,
        );
      }
    });

    test('UX-1912: Normal counts 13 at 3 weeks, and 15 at 60 days and at 6 '
        'months; Suave 8 and Intenso 22 on Mon 21 Dec', () {
      // The owner's example, unchanged.
      expect(ahead(normal, thursday12), hasLength(13));
      final far = ahead(normal, monday21);
      expect(far, hasLength(15));
      expect(far.first.when, DateTime(2026, 11, 25, 9));
      expect(far.first.daysBefore, 26);
      expect(ahead(normal, DateTime(2027, 4, 22)), hasLength(15));
      expect(ahead(gentle, monday21), hasLength(8));
      expect(ahead(intense, monday21), hasLength(22));
    });

    test('UX-1912: a rhythm of one’s own keeps its reach, and one said '
        'without a start runs from now on', () {
      final said = custom(const [PlanPhase(60, 8, 3), PlanPhase(7, 0, 1)]);
      final alerts = ahead(said, monday21);
      expect(alerts, hasLength(26));
      expect(alerts.first.when, DateTime(2026, 10, 23, 9));
      final daily = custom(const [PlanPhase(PlanPhase.longest, 0, 1)]);
      final everyDay = ahead(daily, monday21);
      expect(everyDay, hasLength(60));
      expect(everyDay.first.when, DateTime(2026, 10, 23, 9));
      expect(everyDay.last.when, DateTime(2026, 12, 21, 9));
    });

    test('UX-1912: Normal 60 days away says it starts 4 weeks before; 3 '
        'weeks away it doesn’t', () {
      String words(String code, DateTime anchor) => planRhythm(
        strings(code),
        normal,
        anchor: anchor,
        now: now,
        minute: 540,
      );
      expect(
        words('es', monday21),
        'Cada 3 días desde 4 semanas antes, y a diario la última semana',
      );
      expect(
        words('ca', monday21),
        'Cada 3 dies des de 4 setmanes abans, i cada dia l’última setmana',
      );
      expect(
        words('en', monday21),
        'Every 3 days from 4 weeks before, and daily for the last week',
      );
      expect(
        words('es', thursday12),
        'Cada 3 días, y a diario la última semana',
      );
    });
  });
}

/// The server's task API, in memory: what was sent, and what it holds.
class _Api extends ApiClient {
  _Api() : super(url: 'http://localhost:8088');
  final List<Map<String, dynamic>> remote = [];
  final uploads = <Map<String, dynamic>>[];

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async {
    if (path == 'lists/access/') return {'lists': []};
    if (path.startsWith('attachments/')) return {'results': [], 'next': null};
    if (method == 'GET' && path.startsWith('lists/')) {
      return {'results': [], 'next': null};
    }
    if (method == 'GET') return {'results': remote, 'next': null};
    uploads.add(jsonDecode(jsonEncode(data)) as Map<String, dynamic>);
    final id = path.split('/')[1];
    final index = remote.indexWhere((task) => task['id'] == id);
    if (index >= 0 && remote[index]['version'] != data!['version']) {
      throw ApiException(409, 'Conflict', {'current': remote[index]});
    }
    final next = {...data!, 'id': id, 'version': (data['version'] as int) + 1};
    if (index < 0) {
      remote.add(next);
    } else {
      remote[index] = next;
    }
    return next;
  }
}

/// The drafts endpoint, answering [answer].
class _DraftsApi extends ApiClient {
  _DraftsApi(this.answer);
  final Map<String, dynamic> answer;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    String? audioPath,
    bool authenticated = true,
    int? accountId,
  }) async => answer;
}
