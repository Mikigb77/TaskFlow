// Reminder plans' notifications (Backend/docs/REMINDER_PLANS.md, «The
// notifications»): only the next few of each plan are set; they are set again
// when the task changes and once one fires; done cancels them and undo brings
// them back; one last notice the day after, then nothing; reminders off in
// Settings silence them. With real SQLite and a stand-in for the phone.
import 'package:agenda/models/reminder_plan.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/regional_provider.dart';
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
    'only the next few reminders of a plan are set, each saying how far the day is; the single reminder is not',
    () async {
      await remindersOn();
      await add(presentation());
      await engine.reconcile('local');
      expect(ReminderPlans.window, 4);
      expect(pending(), [
        (DateTime(2026, 10, 24, 9), 'Faltan 20 días'),
        (DateTime(2026, 10, 27, 9), 'Faltan 17 días'),
        (DateTime(2026, 10, 30, 9), 'Faltan 14 días'),
        (DateTime(2026, 11, 2, 9), 'Faltan 11 días'),
      ]);
      expect(
        driver.pending.values.every(
          (reminder) => reminder.title == 'Presentar el proyecto',
        ),
        isTrue,
      );
      // Nothing on the day itself yet, and no single reminder.
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
      expect(pending().length, 4);
    },
  );

  test(
    'marking the task done cancels every reminder left, and undoing it brings them back',
    () async {
      await remindersOn();
      final task = await add(presentation());
      await engine.reconcile('local');
      expect(pending().length, 4);
      await update(task.copyWith(isCompleted: true));
      await engine.reconcile('local');
      expect(driver.pending, isEmpty);
      expect(wakes.last, isNull);
      await update(task.copyWith(isCompleted: false));
      await engine.reconcile('local');
      expect(pending().first.$1, DateTime(2026, 10, 24, 9));
      expect(pending().length, 4);
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
    ]);
    expect(pending().first.$2, 'Faltan 26 días');
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
        (DateTime(2026, 11, 13, 9), 'Es hoy'),
        (DateTime(2026, 11, 14, 9), 'Venció ayer'),
      ]);
      now = DateTime(2026, 11, 11, 10);
      await engine.reconcile('local');
      expect(pending().first, (DateTime(2026, 11, 12, 9), 'Es mañana'));
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
    expect(snoozed.body, 'Faltan 20 días');
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
  @override
  Future<ReminderCapability> capability() async =>
      const ReminderCapability(allowed: true, exact: true);
  @override
  Future<Set<int>> pendingIds() async => pending.keys.toSet();
  @override
  Future<void> cancel(int id) async {
    pending.remove(id);
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
