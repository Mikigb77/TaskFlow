// Reminder plans' notifications (Backend/docs/REMINDER_PLANS.md, «The
// notifications»): only the next few of each plan are set; they are set again
// when the task changes and once one fires; done cancels them and undo brings
// them back; one last notice the day after, then nothing; reminders off in
// Settings silence them. With real SQLite and a stand-in for the phone.
import 'dart:ui';

import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/models/reminder_plan.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/services/notification_service.dart';
import 'package:agenda/services/reminder_engine.dart';
import 'package:agenda/services/reminder_plans.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late TaskDatabase database;
  late _Driver driver;
  late ReminderEngine engine;
  late DateTime now;
  final wakes = <DateTime?>[];

  Future<void> remindersOn({bool on = true, int? dateOnly = 540}) =>
      ReminderPreferenceStore(database).write(
        'local',
        ReminderPreferences(enabled: on, dateOnlyTime: dateOnly, asked: true),
      );

  Future<List<Map<String, Object?>>> rows() async =>
      (await database.database).query('reminder_state', orderBy: 'fire_at');

  /// The phone's pending alerts, earliest first.
  List<(DateTime, String)> pending() => [
    for (final reminder in driver.pending.values)
      (reminder.when, reminder.body),
  ]..sort((a, b) => a.$1.compareTo(b.$1));

  Future<Task> add(Task task) async {
    final id = await database.insertTask(task);
    return (await database.getTasks()).singleWhere((t) => t.id == id);
  }

  Future<void> update(Task task) async {
    await database.updateTask(task);
  }

  setUp(() async {
    final sql = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await sql.execute(
      'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, dueDate TEXT, priority INTEGER, isCompleted INTEGER, notes TEXT, filePaths TEXT, imagePaths TEXT)',
    );
    await TaskDatabase.upgrade(sql, 3, TaskDatabase.schemaVersion);
    database = TaskDatabase.forTesting(sql);
    // Thursday 22 October 2026, 10:00.
    now = DateTime(2026, 10, 22, 10);
    driver = _Driver();
    wakes.clear();
    engine = ReminderEngine(
      database,
      driver,
      clock: () => now,
      wake: (next) async => wakes.add(next),
    );
    await engine.activate('local');
    await RegionalPreferenceStore(
      database,
    ).write(const RegionalPreferences(language: 'es'));
  });
  tearDown(() => database.close());

  /// Friday 13 November, 22 days away, with Normal.
  Task presentation({
    ReminderPlan plan = const ReminderPlan.rhythm(ReminderPlan.normal),
    DateTime? deadline,
    int? minutes,
  }) => Task(
    title: 'Presentar el proyecto',
    priority: 1,
    dueDate: deadline == null ? DateTime(2026, 11, 13) : null,
    hasTime: false,
    deadline: deadline,
    reminderAnchor: deadline == null ? 'planned' : 'deadline',
    reminderPlan: plan,
    reminderMinutes: minutes,
  );

  test(
    'only the next few reminders of a plan are set, and its last days, each saying how far the day is; the single reminder is not',
    () async {
      await remindersOn();
      await add(presentation());
      await engine.reconcile('local');
      expect(ReminderPlans.window, 4);
      expect(pending(), [
        (DateTime(2026, 10, 24, 9), 'Faltan 20 días · vie, 13 nov'),
        (DateTime(2026, 10, 27, 9), 'Faltan 17 días · vie, 13 nov'),
        (DateTime(2026, 10, 30, 9), 'Faltan 14 días · vie, 13 nov'),
        (DateTime(2026, 11, 2, 9), 'Faltan 11 días · vie, 13 nov'),
        // The last days are always set, in case the phone defers the rest.
        (DateTime(2026, 11, 12, 9), 'Es mañana'),
        (DateTime(2026, 11, 13, 9), 'Es hoy'),
        (DateTime(2026, 11, 14, 9), 'Era para ayer'),
      ]);
      expect(
        driver.pending.values.every(
          (reminder) => reminder.title == 'Presentar el proyecto',
        ),
        isTrue,
      );
      // No single reminder.
      expect(
        (await rows())
            .map((row) => row['identity'])
            .every((identity) => '$identity'.contains('/plan/')),
        isTrue,
      );
      // The phone plans them again a minute after the first one rings.
      expect(wakes.last, DateTime(2026, 10, 24, 9));
    },
  );

  test('reminders off in Settings silence plans too', () async {
    await remindersOn(on: false);
    await add(presentation());
    await engine.reconcile('local');
    expect(driver.pending, isEmpty);
    expect(wakes.last, isNull);
  });

  test(
    'once one has fired the next is set; the one that rang still answers its buttons',
    () async {
      await remindersOn();
      final task = await add(presentation());
      await engine.reconcile('local');
      final first = (await rows()).first;
      now = DateTime(2026, 10, 24, 9, 30);
      await engine.reconcile('local');
      expect(pending().map((alert) => alert.$1), [
        DateTime(2026, 10, 27, 9),
        DateTime(2026, 10, 30, 9),
        DateTime(2026, 11, 2, 9),
        DateTime(2026, 11, 5, 9),
        DateTime(2026, 11, 12, 9),
        DateTime(2026, 11, 13, 9),
        DateTime(2026, 11, 14, 9),
      ]);
      expect(wakes.last, DateTime(2026, 10, 27, 9));
      final rang = (await rows()).singleWhere(
        (row) => row['id'] == first['id'],
      );
      expect(rang['status'], 'elapsed');
      // «Completar» on the notification that rang marks the task done.
      expect(
        await engine.action(
          rang['id'] as int,
          'complete',
          token: rang['token'] as String,
        ),
        isTrue,
      );
      expect(
        (await database.getTasks())
            .singleWhere((t) => t.id == task.id)
            .isCompleted,
        isTrue,
      );
      expect(
        driver.pending,
        isEmpty,
        reason: 'Done: every reminder left goes.',
      );
      // Its Undo brings the task and its reminders back.
      expect(
        await engine.action(
          rang['id'] as int,
          'undo',
          token: rang['token'] as String,
        ),
        isTrue,
      );
      expect(pending().length, 7);
    },
  );

  test(
    'marking the task done cancels every reminder left, and undoing it brings them back',
    () async {
      await remindersOn();
      final task = await add(presentation());
      await engine.reconcile('local');
      expect(pending().length, 7);
      await update(task.copyWith(isCompleted: true));
      await engine.reconcile('local');
      expect(driver.pending, isEmpty);
      expect(wakes.last, isNull);
      await update(task.copyWith(isCompleted: false));
      await engine.reconcile('local');
      expect(pending().first.$1, DateTime(2026, 10, 24, 9));
      expect(pending().length, 7);
    },
  );

  test('moving the day moves the whole plan', () async {
    await remindersOn();
    final task = await add(presentation());
    await engine.reconcile('local');
    await update(task.copyWith(dueDate: DateTime(2026, 11, 20)));
    await engine.reconcile('local');
    expect(pending().map((alert) => alert.$1), [
      DateTime(2026, 10, 25, 9),
      DateTime(2026, 10, 28, 9),
      DateTime(2026, 10, 31, 9),
      DateTime(2026, 11, 3, 9),
      DateTime(2026, 11, 19, 9),
      DateTime(2026, 11, 20, 9),
      DateTime(2026, 11, 21, 9),
    ]);
    expect(pending().first.$2, 'Faltan 26 días · vie, 20 nov');
  });

  test(
    'after the day, one last notice the next day if it isn’t done, then nothing',
    () async {
      await remindersOn();
      await add(presentation());
      now = DateTime(2026, 11, 13, 12);
      await engine.reconcile('local');
      expect(pending(), [(DateTime(2026, 11, 14, 9), 'Era para ayer')]);
      now = DateTime(2026, 11, 14, 10);
      await engine.reconcile('local');
      expect(driver.pending, isEmpty);
      expect(wakes.last, isNull);
    },
  );

  test(
    'with a deadline the plan counts back from it, and the last notice says it was due',
    () async {
      await remindersOn();
      await add(presentation(deadline: DateTime(2026, 11, 13, 18)));
      now = DateTime(2026, 11, 12, 10);
      await engine.reconcile('local');
      expect(pending(), [
        (DateTime(2026, 11, 13, 9), 'Fecha límite: hoy'),
        (DateTime(2026, 11, 14, 9), 'Venció ayer'),
      ]);
      now = DateTime(2026, 11, 11, 10);
      await engine.reconcile('local');
      expect(pending().first, (
        DateTime(2026, 11, 12, 9),
        'Fecha límite: mañana',
      ));
    },
  );

  test(
    'a plan rings at its own time, else Settings’ for all-day tasks, even with the single reminder off',
    () async {
      await remindersOn(dateOnly: 480);
      await add(presentation(minutes: -1));
      await engine.reconcile('local');
      expect(pending().first.$1, DateTime(2026, 10, 24, 8));
      final timed = await add(
        presentation(
          plan: ReminderPlan.tryParse({
            'kind': 'custom',
            'phases': [
              {'from_days': 1, 'to_days': 1, 'every_days': 1},
            ],
            'time': '07:30',
            'said': 'el día antes a las 7:30',
          })!,
        ).copyWith(title: 'Llevar el informe'),
      );
      await engine.reconcile('local');
      expect(
        driver.pending.values
            .where((reminder) => reminder.taskId == timed.id)
            .map((reminder) => (reminder.when, reminder.body)),
        [
          (DateTime(2026, 11, 12, 7, 30), 'Es mañana'),
          (DateTime(2026, 11, 14, 7, 30), 'Era para ayer'),
        ],
      );
    },
  );

  test(
    'a repeating task keeps its single reminder: plans are not for it',
    () async {
      await remindersOn();
      await add(
        Task(
          title: 'Regar las plantas',
          priority: 1,
          dueDate: DateTime(2026, 10, 23),
          hasTime: false,
          recurrence: 'weekly',
          reminderPlan: const ReminderPlan.rhythm(ReminderPlan.intense),
        ),
      );
      await engine.reconcile('local');
      expect(
        (await rows())
            .map((row) => '${row['identity']}')
            .any((identity) => identity.contains('/plan/')),
        isFalse,
      );
      expect(pending().first, (
        DateTime(2026, 10, 23, 9),
        'En tu lista para hoy.',
      ));
    },
  );

  test('a snoozed plan reminder keeps saying how far the day is', () async {
    await remindersOn();
    await add(presentation());
    await engine.reconcile('local');
    now = DateTime(2026, 10, 24, 9, 1);
    final first = (await rows()).first;
    expect(
      await engine.action(
        first['id'] as int,
        'snooze',
        token: first['token'] as String,
      ),
      isTrue,
    );
    final snoozed = driver.pending[first['id']]!;
    expect(snoozed.when.toLocal(), DateTime(2026, 10, 24, 9, 11));
    expect(snoozed.body, 'Faltan 20 días · vie, 13 nov');
  });

  test('the single reminder comes back once the plan is taken away', () async {
    await remindersOn();
    final task = await add(presentation());
    await engine.reconcile('local');
    await update(task.copyWith(reminderPlan: null));
    await engine.reconcile('local');
    expect(pending(), [(DateTime(2026, 11, 13, 9), 'En tu lista para hoy.')]);
    expect(wakes.last, isNull);
  });

  test(
    'UX-2010: a Normal plan 10 days away sets the next four, 8 to 5 days before, and the day before, the day and the day after, none twice',
    () async {
      await remindersOn();
      // Sunday 1 November, 10 days away.
      await add(
        presentation().copyWith(
          title: 'Entregar el informe',
          dueDate: DateTime(2026, 11, 1),
        ),
      );
      await engine.reconcile('local');
      expect(pending().map((alert) => alert.$1), [
        DateTime(2026, 10, 24, 9), // 8 days before
        DateTime(2026, 10, 25, 9), // 7
        DateTime(2026, 10, 26, 9), // 6
        DateTime(2026, 10, 27, 9), // 5
        DateTime(2026, 10, 31, 9), // the day before
        DateTime(2026, 11, 1, 9), // the day
        DateTime(2026, 11, 2, 9), // the day after
      ]);
      expect(pending().skip(4).map((alert) => alert.$2), [
        'Es mañana',
        'Es hoy',
        'Era para ayer',
      ]);
      final identities = driver.pending.values
          .map((reminder) => reminder.identity)
          .toList();
      expect(identities.toSet().length, identities.length);
      final stored = (await rows())
          .map((row) => row['identity'])
          .where(ReminderEngine.isPlanAlert)
          .toList();
      expect(stored.toSet().length, stored.length);
      expect(stored.length, 7);
    },
  );

  test(
    'UX-2010: once the next four have rung, the last days are still set, not twice',
    () async {
      await remindersOn();
      await add(
        presentation().copyWith(
          title: 'Entregar el informe',
          dueDate: DateTime(2026, 11, 1),
        ),
      );
      await engine.reconcile('local');
      // The phone defers background work: nothing refreshes until the 28th.
      now = DateTime(2026, 10, 28, 10);
      driver.ring(now);
      await engine.reconcile('local');
      expect(pending().map((alert) => alert.$1), [
        DateTime(2026, 10, 29, 9),
        DateTime(2026, 10, 30, 9),
        DateTime(2026, 10, 31, 9),
        DateTime(2026, 11, 1, 9),
        DateTime(2026, 11, 2, 9),
      ]);
      final stored = (await rows())
          .map((row) => row['identity'])
          .where(ReminderEngine.isPlanAlert)
          .toList();
      expect(stored.toSet().length, stored.length);
    },
  );

  test(
    'UX-2004: with a daily plan, once the next day’s notice rings, the earlier one leaves the shade; one per task; done leaves none',
    () async {
      await remindersOn();
      final daily = ReminderPlan.tryParse({
        'kind': 'custom',
        'phases': [
          {'from_days': 6, 'to_days': 0, 'every_days': 1},
        ],
        'said': 'cada día la última semana',
      })!;
      // Thursday 29 October and Friday 30 October, each with a daily plan.
      final task = await add(
        presentation(plan: daily).copyWith(dueDate: DateTime(2026, 10, 29)),
      );
      final other = await add(
        presentation(
          plan: daily,
        ).copyWith(title: 'Llamar al banco', dueDate: DateTime(2026, 10, 30)),
      );
      await engine.reconcile('local');
      int idOn(Task of, DateTime day) => driver.pending.entries
          .singleWhere(
            (entry) =>
                entry.value.taskId == of.id &&
                entry.value.when == DateTime(day.year, day.month, day.day, 9),
          )
          .key;
      final first = idOn(task, DateTime(2026, 10, 23));
      final second = idOn(task, DateTime(2026, 10, 24));
      final otherFirst = idOn(other, DateTime(2026, 10, 24));
      final otherSecond = idOn(other, DateTime(2026, 10, 25));

      // Friday 23 at 9:00 the task's first rings; the refresh a minute later
      // runs.
      now = DateTime(2026, 10, 23, 9);
      driver.ring(now);
      now = DateTime(2026, 10, 23, 9, 1);
      await engine.reconcile('local');
      expect(driver.shade.keys, [first]);

      // Saturday 24 at 9:00 the next rings, and the other task's first; the
      // refresh a minute later runs.
      now = DateTime(2026, 10, 24, 9);
      driver.ring(now);
      now = DateTime(2026, 10, 24, 9, 1);
      driver.cancelled.clear();
      await engine.reconcile('local');
      expect(driver.cancelled, contains(first));
      expect(driver.cancelled, isNot(contains(second)));
      expect(driver.cancelled, isNot(contains(otherFirst)));
      expect(
        driver.shade.keys,
        unorderedEquals([second, otherFirst]),
        reason: 'One plan notice per task: the newest.',
      );
      expect(driver.shade[second]!.body, 'Faltan 5 días · jue, 29 oct');
      final fired = (await rows()).where(
        (row) =>
            ReminderEngine.isPlanAlert(row['identity']) &&
            row['task_id'] == task.id &&
            row['status'] == 'elapsed',
      );
      expect(fired.map((row) => row['id']), [second]);

      // Another refresh doesn't cancel the earlier one again.
      driver.cancelled.clear();
      await engine.reconcile('local');
      expect(driver.cancelled, isNot(contains(first)));
      expect(driver.shade.keys, unorderedEquals([second, otherFirst]));

      // Sunday 25 both tasks' next ring: each one's earlier leaves.
      final third = idOn(task, DateTime(2026, 10, 25));
      now = DateTime(2026, 10, 25, 9);
      driver.ring(now);
      now = DateTime(2026, 10, 25, 9, 1);
      await engine.reconcile('local');
      expect(driver.shade.keys, unorderedEquals([third, otherSecond]));

      // Done: none of its notices are left; the other task keeps its own.
      await update(
        (await database.getTasks())
            .singleWhere((t) => t.id == task.id)
            .copyWith(isCompleted: true),
      );
      await engine.reconcile('local');
      expect(driver.shade.keys, [otherSecond]);
      expect(
        driver.pending.values.where((reminder) => reminder.taskId == task.id),
        isEmpty,
      );
    },
  );

  group('UX-2009: a plan notice offers only «Completar»', () {
    final es = lookupAppLocalizations(const Locale('es'));
    List<String?> actions(PlannedReminder reminder) => [
      for (final action in reminderNotificationDetails(
        reminder,
      ).android!.actions!)
        action.title,
    ];

    test(
      'before the day, on the day and the day after: one Android action, «Completar»',
      () async {
        await remindersOn();
        await add(presentation());
        await engine.reconcile('local');
        final notices = {
          for (final reminder in driver.pending.values) reminder.body: reminder,
        };
        for (final body in [
          'Faltan 20 días · vie, 13 nov',
          'Es hoy',
          'Era para ayer',
        ]) {
          final notice = notices[body]!;
          expect(ReminderEngine.isPlanAlert(notice.identity), isTrue);
          expect(actions(notice), [es.notificationComplete], reason: body);
          expect(
            reminderNotificationDetails(notice).iOS!.categoryIdentifier,
            'plan_es',
            reason: body,
          );
        }
      },
    );

    test('a single reminder keeps «Completar» and «Posponer 10 min»', () async {
      await remindersOn();
      await add(presentation().copyWith(reminderPlan: null));
      await engine.reconcile('local');
      final single = driver.pending.values.single;
      expect(ReminderEngine.isPlanAlert(single.identity), isFalse);
      expect(actions(single), [es.notificationComplete, es.notificationSnooze]);
      expect(
        reminderNotificationDetails(single).iOS!.categoryIdentifier,
        'task_es',
      );
    });
  });

  test('the reminder question’s check counts a plan’s reminders', () {
    const settings = ReminderPreferences(enabled: true);
    final task = presentation(minutes: -1);
    expect(ReminderEngine.alertAhead(task, settings, now), isTrue);
    expect(
      ReminderEngine.alertAhead(task, settings, DateTime(2026, 11, 14, 10)),
      isFalse,
    );
  });
}

class _Driver implements ReminderDriver {
  final Map<int, PlannedReminder> pending = {};
  final Map<int, Object> shown = {};

  /// What the phone's shade holds: alarms that have rung and not been
  /// cancelled since. [cancelled] lists every id cancelled, in order.
  final Map<int, PlannedReminder> shade = {};
  final List<int> cancelled = [];

  /// The phone rings every alarm due by [now]: it leaves the pending list
  /// and shows in the shade.
  void ring(DateTime now) {
    final due = [
      for (final entry in pending.entries)
        if (!entry.value.when.isAfter(now)) entry.key,
    ];
    for (final id in due) {
      shade[id] = pending.remove(id)!;
    }
  }

  @override
  Future<ReminderCapability> capability() async =>
      const ReminderCapability(allowed: true, exact: true);
  @override
  Future<Set<int>> pendingIds() async => pending.keys.toSet();
  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    pending.remove(id);
    shade.remove(id);
  }

  @override
  Future<void> schedule(
    int id,
    PlannedReminder reminder, {
    required bool exact,
    required String token,
  }) async {
    pending[id] = reminder;
  }

  @override
  Future<void> show(
    int id,
    PlannedReminder reminder, {
    required String token,
  }) async {
    shown[id] = reminder;
  }

  @override
  Future<void> showUndo(
    int id,
    String text, {
    required String languageCode,
    required String token,
  }) async {
    shown[id] = text;
  }
}
