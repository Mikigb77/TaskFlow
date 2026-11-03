import 'dart:async';
import 'dart:convert';
import 'package:agenda/models/reminder_plan.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/reminder_copy.dart';
import 'package:agenda/services/reminder_plans.dart';
import 'package:agenda/services/reminder_preferences.dart';
import 'package:agenda/services/task_database.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class ReminderCapability {
  final bool allowed;
  final bool exact;
  const ReminderCapability({required this.allowed, required this.exact});
}

class PlannedReminder {
  final String identity;
  final int? taskId;
  final String? occurrence;
  final DateTime? due;
  final DateTime when;
  final String title;
  final String body;
  final String languageCode;
  final bool daily;

  /// For a task in a project where this account is «lector»: its notice
  /// offers no «Completar», which a reader can't do (D9).
  final bool readOnly;
  const PlannedReminder({
    required this.identity,
    this.taskId,
    this.occurrence,
    this.due,
    required this.when,
    required this.title,
    required this.body,
    this.languageCode = 'en',
    this.daily = false,
    this.readOnly = false,
  });
  String signature(bool exact) => jsonEncode([
    when.toUtc().toIso8601String(),
    title,
    body,
    languageCode,
    daily,
    exact,
    due?.toUtc().toIso8601String(),
    // A notice whose buttons change is set again.
    if (readOnly) 'read-only',
  ]);
  Map<String, Object?> row(String owner, DateTime now) => {
    'owner_key': owner,
    'identity': identity,
    'task_id': taskId,
    'occurrence': occurrence,
    'due_at': due?.toIso8601String(),
    'fire_at': when.toUtc().toIso8601String(),
    'title': title,
    'body': body,
    'daily': daily ? 1 : 0,
    'updated_at': now.toUtc().toIso8601String(),
  };
}

abstract class ReminderDriver {
  Future<ReminderCapability> capability();
  Future<Set<int>> pendingIds();
  Future<void> cancel(int id);
  Future<void> schedule(
    int id,
    PlannedReminder reminder, {
    required bool exact,
    required String token,
  });

  /// Shows [reminder] again at once, quietly: Undo brings back what the user
  /// had on screen.
  Future<void> show(int id, PlannedReminder reminder, {required String token});

  /// Replaces alert [id] for a few seconds with [text] and an Undo action.
  Future<void> showUndo(
    int id,
    String text, {
    required String languageCode,
    required String token,
  });
}

/// Planning and persistence are separate from the OS, so denied permissions,
/// retries, account changes and occurrence actions can be tested with real SQLite.
class ReminderEngine {
  final TaskDatabase database;
  final ReminderDriver driver;
  final DateTime Function() clock;
  final int capacity;
  final Duration leaseWait;
  final Future<ReminderCopy> Function() readCopy;

  /// After each refresh: when the earliest plan reminder set rings, or null
  /// when none is set. A plan's reminders are set only a few at a time, so
  /// the phone plans them again once one has fired.
  final Future<void> Function(DateTime? next)? wake;
  ReminderEngine(
    this.database,
    this.driver, {
    DateTime Function()? clock,
    this.capacity = 400,
    this.leaseWait = const Duration(seconds: 10),
    Future<ReminderCopy> Function()? readCopy,
    this.wake,
  }) : clock = clock ?? DateTime.now,
       readCopy = readCopy ?? (() => readReminderCopy(database));

  Future<String?> activeOwner() async {
    final rows = await (await database.database).query(
      'reminder_meta',
      where: 'key = ?',
      whereArgs: ['owner'],
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  Future<void> activate(String owner) async {
    await (await database.database).insert('reminder_meta', {
      'key': 'owner',
      'value': owner,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    // Account switches cancel old alerts before the new account is exposed.
    final old = await (await database.database).query(
      'reminder_state',
      where: 'owner_key != ? AND status != ?',
      whereArgs: [owner, 'inactive'],
    );
    for (final row in old) {
      await driver.cancel(row['id'] as int);
      await (await database.database).update(
        'reminder_state',
        {'status': 'inactive'},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  static String identity(String owner, Task task) =>
      '$owner/task/${task.id}/${task.occurrenceId ?? 'once'}';

  /// One reminder of [task]'s plan, by the day it rings. [onTime] marks the
  /// day's own one ringing at the task's usual reminder ([isPlanDayAlert]).
  static String planIdentity(
    String owner,
    Task task,
    PlanAlert alert, {
    bool onTime = false,
  }) =>
      '$owner/task/${task.id}/plan/${Task.dateKey(alert.when)}'
      '${onTime ? '/time' : ''}';

  static bool isPlanAlert(Object? identity) =>
      identity is String && identity.contains('/plan/');

  /// A plan's notice on its timed anchor's own day, at the task's usual
  /// reminder (D1, for a plan without a time of its own; one with its own
  /// keeps that time on the day too, D8): it reads as the task's reminder
  /// and offers its snooze; in every other way it's a plan alert.
  static bool isPlanDayAlert(Object? identity) =>
      isPlanAlert(identity) && (identity as String).endsWith('/time');

  /// The days before its task's day that plan alert [row] rings.
  static int _planDaysBefore(Map<String, Object?> row, Task task) {
    final key = (row['identity'] as String)
        .split('/plan/')
        .last
        .split('/')
        .first;
    final day = DateTime.tryParse(key);
    final anchor = ReminderPlans.anchor(task);
    if (day == null || anchor == null) return 0;
    return ReminderPlans.daysUntil(anchor, day);
  }

  /// The next few reminders of [task]'s [plan], never the whole plan, and
  /// always its last days still ahead (the day before, the day itself and
  /// the day after), so a phone that defers background work still rings
  /// them. On a timed anchor's own day, the day's one of a plan without a
  /// time of its own rings at the task's usual reminder, in its words (D1);
  /// a plan with a time of its own, said or typed, keeps that time on the
  /// day too, as a plain plan notice (D8).
  static List<PlannedReminder> planReminders(
    String owner,
    Task task,
    ReminderPlan plan,
    ReminderPreferences preferences,
    DateTime now,
    ReminderCopy copy, {
    bool readOnly = false,
  }) {
    final anchor = ReminderPlans.anchor(task)!;
    final lead = ReminderPlans.dayLead(task, preferences.leadMinutes);
    final alerts = ReminderPlans.alerts(
      plan,
      anchor,
      ReminderPlans.minute(plan, preferences.dateOnlyTime),
      now,
      dayLead: lead,
    );
    return [
      for (final (index, alert) in alerts.indexed)
        if (index < ReminderPlans.window || alert.daysBefore <= 1)
          PlannedReminder(
            identity: planIdentity(
              owner,
              task,
              alert,
              onTime: lead != null && alert.daysBefore == 0,
            ),
            taskId: task.id,
            due: anchor,
            when: alert.when,
            title: task.title,
            languageCode: copy.languageCode,
            body: lead != null && alert.daysBefore == 0
                ? copy.planDayBody(task, alert.when, lead)
                : copy.planBody(task, alert.daysBefore),
            readOnly: readOnly,
          ),
    ];
  }

  static List<Task> upcoming(List<Task> tasks, DateTime now, {int days = 365}) {
    final result = <Task>[];
    for (final task in tasks) {
      if (task.isRecurring) {
        for (var offset = 0; offset <= days; offset++) {
          final day = DateTime(now.year, now.month, now.day + offset);
          for (final occurrence
              in task.reminderAnchor == 'deadline'
                  ? task.deadlinesOn(day)
                  : task.occurrencesOn(day)) {
            if (!occurrence.isCompleted &&
                occurrence.reminderDate != null &&
                (!occurrence.reminderHasTime ||
                    occurrence.reminderDate!.isAfter(now))) {
              result.add(occurrence);
            }
          }
        }
      } else if (!task.isCompleted &&
          task.reminderDate != null &&
          (task.reminderHasTime
              ? task.reminderDate!.isAfter(now)
              : !Task.day(task.reminderDate!).isBefore(Task.day(now)))) {
        result.add(task);
      }
    }
    return result..sort(Task.compareBySchedule);
  }

  /// When [task]'s alert fires, and how many minutes ahead of the task.
  static ({DateTime when, int lead})? _firing(
    Task task,
    ReminderPreferences preferences,
  ) {
    final date = task.reminderDate!;
    final lead = task.reminderMinutes ?? preferences.leadMinutes;
    final minute = task.reminderTime ?? preferences.dateOnlyTime;
    if (task.reminderHasTime ? lead < 0 : minute == null) return null;
    return (
      when: task.reminderHasTime
          ? date.subtract(Duration(minutes: lead))
          : DateTime(
              date.year,
              date.month,
              date.day,
              minute! ~/ 60,
              minute % 60,
            ),
      lead: lead,
    );
  }

  /// Whether [task]'s next alert would still ring after [now] were reminders
  /// on, by the steps [plan] takes: [preferences] taken as enabled, and a
  /// task without a time reminding at the default 9:00 when no time was
  /// chosen. False for a task whose reminder is off. A plan's last notice,
  /// the day after, isn't a reminder before the task.
  static bool alertAhead(
    Task task,
    ReminderPreferences preferences,
    DateTime now,
  ) {
    // A plan rings by its own days, whatever the single reminder says.
    if (ReminderPlans.active(task) != null) {
      return ReminderPlans.taskAlerts(
        task,
        preferences.dateOnlyTime,
        now,
        defaultLead: preferences.leadMinutes,
        late: false,
      ).isNotEmpty;
    }
    if (task.reminderMinutes == -1) return false;
    final on = ReminderPreferences(
      enabled: true,
      leadMinutes: preferences.leadMinutes,
      dateOnlyTime: preferences.dateOnlyTime ?? 540,
    );
    return upcoming([task], now).any((next) {
      if (next.reminderMinutes == -1) return false;
      final firing = _firing(next, on);
      return firing != null && firing.when.isAfter(now);
    });
  }

  /// The alerts this phone keeps for task [taskId], for the active account:
  /// its `reminder_state` rows, each with `snooze_at`, its snooze's time,
  /// when one was asked for. [lastAlert] reads them.
  Future<List<Map<String, Object?>>> alertsOf(int taskId) async {
    final owner = await activeOwner();
    if (owner == null) return const [];
    return (await database.database).rawQuery(
      '''SELECT r.*, s.fire_at AS snooze_at
      FROM reminder_state r LEFT JOIN reminder_snoozes s
        ON s.identity = r.identity AND s.owner_key = r.owner_key
      WHERE r.owner_key = ? AND r.task_id = ?''',
      [owner, taskId],
    );
  }

  /// When [task]'s reminder last rang, by [alerts] ([alertsOf]), or when it
  /// rings again after a snooze still to come ([snoozed]); null when it was
  /// never set to ring by now: blocked, cancelled before its time, or saved
  /// after it (D1). A single reminder counts only while its alert is still
  /// the task's: the same day and time, and the same lead; a plan's, while
  /// it counts from the same day. Unlike [alertAhead], it's about what rang.
  static ({DateTime when, bool snoozed})? lastAlert(
    Task task,
    List<Map<String, Object?>> alerts,
    ReminderPreferences preferences,
    DateTime now,
  ) {
    final planned = ReminderPlans.active(task) != null;
    final anchor = planned ? ReminderPlans.anchor(task) : task.reminderDate;
    if (anchor == null || (!planned && task.reminderMinutes == -1)) {
      return null;
    }
    final firing = planned ? null : _firing(task, preferences);
    if (!planned && firing == null) return null;
    DateTime? last;
    DateTime? snooze;
    for (final row in alerts) {
      final fired = DateTime.tryParse(row['fire_at'] as String? ?? '');
      final snoozedAt = DateTime.tryParse(row['snooze_at'] as String? ?? '');
      if (fired == null ||
          isPlanAlert(row['identity']) != planned ||
          row['due_at'] != anchor.toIso8601String() ||
          row['error'] != null ||
          !const {
            'scheduled',
            'approximate',
            'elapsed',
          }.contains(row['status'])) {
        continue;
      }
      // A snooze sets the alert again at its own time.
      if (!planned &&
          !fired.isAtSameMomentAs(firing!.when) &&
          (snoozedAt == null || !fired.isAtSameMomentAs(snoozedAt))) {
        continue;
      }
      if (!planned && row['occurrence'] != task.occurrenceId) continue;
      if (snoozedAt != null && snoozedAt.isAfter(now)) {
        if (snooze == null || snoozedAt.isAfter(snooze)) snooze = snoozedAt;
      }
      for (final moment in [fired, ?snoozedAt]) {
        if (!moment.isAfter(now) && (last == null || moment.isAfter(last))) {
          last = moment;
        }
      }
    }
    if (snooze != null) return (when: snooze.toLocal(), snoozed: true);
    if (last != null) return (when: last.toLocal(), snoozed: false);
    return null;
  }

  /// The reminders to set for [tasks]. Those in [readOnly], the projects where
  /// this account is «lector» ([TaskDatabase.readOnlyProjects]), are planned
  /// without «Completar».
  static List<PlannedReminder> plan(
    String owner,
    List<Task> tasks,
    ReminderPreferences preferences,
    DateTime now, {
    ReminderCopy? copy,
    Set<String> readOnly = const {},
  }) {
    if (!preferences.enabled) return [];
    final c = copy ?? ReminderCopy.fallback();
    final l = c.strings;
    final result = <PlannedReminder>[];
    bool reader(Task task) => readOnly.contains(task.listId);
    // A plan replaces its task's single reminder while it's set: on a timed
    // anchor's own day, its notice rings at that reminder's moment instead.
    final single = <Task>[];
    for (final task in tasks) {
      final plan = ReminderPlans.active(task);
      if (plan == null) {
        single.add(task);
      } else if (task.id != null && !task.isCompleted) {
        result.addAll(
          planReminders(
            owner,
            task,
            plan,
            preferences,
            now,
            c,
            readOnly: reader(task),
          ),
        );
      }
    }
    for (final task in upcoming(single, now)) {
      if (task.id == null || task.reminderMinutes == -1) continue;
      final firing = _firing(task, preferences);
      if (firing == null || !firing.when.isAfter(now)) continue;
      result.add(
        PlannedReminder(
          identity: identity(owner, task),
          taskId: task.id,
          occurrence: task.occurrenceId,
          due: task.reminderDate,
          when: firing.when,
          title: task.title,
          languageCode: c.languageCode,
          body: c.body(task, firing.when, firing.lead),
          readOnly: reader(task),
        ),
      );
    }
    for (final entry in {
      'morning': preferences.morning,
      'evening': preferences.evening,
    }.entries) {
      final minute = entry.value;
      if (minute == null) continue;
      var when = DateTime(
        now.year,
        now.month,
        now.day,
        minute ~/ 60,
        minute % 60,
      );
      if (!when.isAfter(now)) {
        when = DateTime(
          now.year,
          now.month,
          now.day + 1,
          minute ~/ 60,
          minute % 60,
        );
      }
      result.add(
        PlannedReminder(
          identity: '$owner/${entry.key}',
          when: when,
          languageCode: l.localeName,
          title: entry.key == 'morning'
              ? l.notificationMorning
              : l.notificationEvening,
          body: l.notificationCheckIn,
          daily: true,
        ),
      );
    }
    return result..sort((a, b) => a.when.compareTo(b.when));
  }

  Future<bool> _lease(String token, DateTime now) async {
    return (await database.database).transaction((tx) async {
      final rows = await tx.query(
        'reminder_meta',
        where: 'key = ?',
        whereArgs: ['lease'],
      );
      if (rows.isNotEmpty) {
        final lease = jsonDecode(rows.single['value'] as String) as Map;
        if (DateTime.parse(lease['until']).isAfter(now.toUtc())) return false;
      }
      await tx.insert('reminder_meta', {
        'key': 'lease',
        'value': jsonEncode({
          'token': token,
          'until': now
              .toUtc()
              .add(const Duration(minutes: 2))
              .toIso8601String(),
        }),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
  }

  Future<void> reconcile(String owner) async {
    final token = const Uuid().v4();
    final waiting = Stopwatch()..start();
    while (true) {
      if (await activeOwner() != owner) return;
      if (await _lease(token, clock())) break;
      // Another worker may have read its task snapshot before our latest edit.
      // Do not silently drop this refresh: acquire the lease, then read again.
      if (waiting.elapsed >= leaseWait) {
        throw TimeoutException('Another reminder refresh is still running.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final now = clock();
    try {
      final tasks = await TaskDatabase.reminderTasks(
        await database.database,
        owner,
        await database.getTasks(ownerKey: owner),
      );
      final readOnly = await TaskDatabase.readOnlyProjects(
        await database.database,
        owner,
      );
      final preferences = await ReminderPreferenceStore(database).read(owner);
      final copy = await readCopy();
      final capabilities = await driver.capability();
      final pending = await driver.pendingIds();
      final planned = plan(
        owner,
        tasks,
        preferences,
        now,
        copy: copy,
        readOnly: readOnly,
      );
      final db = await database.database;
      // A snooze is a separate durable choice. Unrelated edits must not reset it.
      final snoozes = await db.rawQuery(
        '''SELECT s.fire_at AS snooze_at, r.*
        FROM reminder_snoozes s JOIN reminder_state r ON r.identity = s.identity
        WHERE s.owner_key = ?''',
        [owner],
      );
      for (final row in snoozes) {
        final when = DateTime.parse(row['snooze_at'] as String);
        final task = _currentTask(tasks, row);
        final ofPlan = isPlanAlert(row['identity']);
        if (!preferences.enabled ||
            task == null ||
            (!ofPlan && task.reminderMinutes == -1) ||
            !when.isAfter(now)) {
          continue;
        }
        planned.removeWhere((p) => p.identity == row['identity']);
        // A snoozed alert says when the task is, without “in N min”: the snooze has used that time up.
        planned.add(
          PlannedReminder(
            identity: row['identity'] as String,
            taskId: task.id,
            occurrence: row['occurrence'] as String?,
            due: ofPlan ? ReminderPlans.anchor(task) : task.reminderDate,
            when: when,
            title: task.title,
            languageCode: copy.languageCode,
            body: !ofPlan
                ? copy.body(task, when.toLocal(), 0)
                : isPlanDayAlert(row['identity'])
                ? copy.planDayBody(task, when.toLocal(), 0)
                : copy.planBody(task, _planDaysBefore(row, task)),
            readOnly: readOnly.contains(task.listId),
          ),
        );
      }
      planned.sort((a, b) => a.when.compareTo(b.when));
      // Reserve room for continuing check-ins even when the task window is full.
      final checkins = planned.where((p) => p.daily).toList();
      final window = [
        ...planned.where((p) => !p.daily).take(capacity - checkins.length),
        ...checkins,
      ];
      final keys = window.map((p) => p.identity).toSet();
      final old = await db.query('reminder_state');
      for (final row in old) {
        if (!keys.contains(row['identity']) || row['owner_key'] != owner) {
          final current = _currentTask(tasks, row);
          // A plan's alerts ring whatever the single reminder says.
          final stillRelevant =
              row['owner_key'] == owner &&
              preferences.enabled &&
              current != null &&
              (isPlanAlert(row['identity']) || current.reminderMinutes != -1);
          if (pending.contains(row['id']) ||
              (!stillRelevant && row['status'] != 'inactive')) {
            await driver.cancel(row['id'] as int);
          }
          await db.update(
            'reminder_state',
            {'status': stillRelevant ? 'elapsed' : 'inactive'},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
      // One plan notice per task in the shade: each is true only on its day,
      // so once a newer one has rung, the older ones go. One already gone
      // isn't cancelled again.
      final gone = {
        for (final row in old)
          if (row['status'] == 'inactive') row['id'],
      };
      final rang = <Object?, List<Map<String, Object?>>>{};
      for (final row in await db.query(
        'reminder_state',
        where: 'owner_key = ? AND status = ?',
        whereArgs: [owner, 'elapsed'],
      )) {
        if (!isPlanAlert(row['identity'])) continue;
        final fired = DateTime.tryParse(row['fire_at'] as String? ?? '');
        if (fired == null || fired.isAfter(now)) continue;
        (rang[row['task_id']] ??= []).add(row);
      }
      for (final rows in rang.values) {
        rows.sort(
          (a, b) => (b['fire_at'] as String).compareTo(a['fire_at'] as String),
        );
        for (final row in rows.skip(1)) {
          if (!gone.contains(row['id'])) await driver.cancel(row['id'] as int);
          await db.update(
            'reminder_state',
            {'status': 'inactive'},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
      // Cancel legacy/untracked schedules once; subsequent refreshes only diff.
      final tracked = old.map((r) => r['id']).toSet();
      for (final id in pending.where((id) => !tracked.contains(id))) {
        await driver.cancel(id);
      }
      for (final reminder in window) {
        if (await activeOwner() != owner) return;
        final rows = await db.query(
          'reminder_state',
          where: 'identity = ?',
          whereArgs: [reminder.identity],
        );
        final existing = rows.firstOrNull;
        final id =
            existing?['id'] as int? ??
            await db.insert('reminder_state', {
              ...reminder.row(owner, now),
              'status': 'pending',
            });
        final signature = reminder.signature(capabilities.exact);
        final alertToken =
            existing?['signature'] == signature && existing?['token'] != null
            ? existing!['token'] as String
            : const Uuid().v4();
        String status;
        String? error;
        if (!capabilities.allowed) {
          await driver.cancel(id);
          status = 'blocked';
          error = 'permission_denied';
        } else {
          status = capabilities.exact ? 'scheduled' : 'approximate';
          if (existing?['signature'] != signature ||
              !pending.contains(id) ||
              existing?['status'] != status) {
            try {
              if (existing != null &&
                  existing['status'] != 'inactive' &&
                  existing['signature'] != signature) {
                await driver.cancel(id);
              }
              await driver.schedule(
                id,
                reminder,
                exact: capabilities.exact,
                token: alertToken,
              );
              if (await activeOwner() != owner) {
                await driver.cancel(id);
                return;
              }
            } catch (_) {
              // A previously scheduled version must not survive a failed edit.
              await driver.cancel(id);
              status = 'failed';
              error = 'schedule_failed';
            }
          }
        }
        await db.update(
          'reminder_state',
          {
            ...reminder.row(owner, now),
            'status': status,
            'error': error,
            'signature': signature,
            'token': alertToken,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      await db.insert('reminder_meta', {
        'key': 'window',
        'value': jsonEncode({
          'owner': owner,
          'deferred': planned.length - window.length,
          'refreshed': now.toUtc().toIso8601String(),
        }),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.delete(
        'reminder_state',
        where: 'status = ? AND fire_at < ?',
        whereArgs: [
          'inactive',
          now.toUtc().subtract(const Duration(days: 30)).toIso8601String(),
        ],
      );
      // Once the earliest plan reminder has fired, the next ones are set.
      DateTime? next;
      if (capabilities.allowed) {
        for (final reminder in window) {
          if (isPlanAlert(reminder.identity) &&
              (next == null || reminder.when.isBefore(next))) {
            next = reminder.when;
          }
        }
      }
      try {
        await wake?.call(next);
      } catch (_) {
        // The hourly refresh plans them again all the same.
      }
    } finally {
      final db = await database.database;
      await db.transaction((tx) async {
        final rows = await tx.query(
          'reminder_meta',
          where: 'key = ?',
          whereArgs: ['lease'],
        );
        if (rows.isNotEmpty &&
            jsonDecode(rows.single['value'] as String)['token'] == token) {
          await tx.delete(
            'reminder_meta',
            where: 'key = ?',
            whereArgs: ['lease'],
          );
        }
      });
    }
  }

  /// The task, or occurrence, that alert [row] is about while the alert still
  /// matches it. Undo looks for the [completed] one.
  Task? _currentTask(
    List<Task> tasks,
    Map<String, Object?> row, {
    bool completed = false,
  }) {
    var task = tasks.where((t) => t.id == row['task_id']).firstOrNull;
    if (task == null) return null;
    // A plan's alert holds while the plan is set and counts from the same
    // day: moving the day moves the whole plan.
    if (isPlanAlert(row['identity'])) {
      final anchor = ReminderPlans.anchor(task);
      return ReminderPlans.active(task) == null ||
              task.isCompleted != completed ||
              anchor == null ||
              anchor.toIso8601String() != row['due_at']
          ? null
          : task;
    }
    if (task.isRecurring) {
      final date = DateTime.tryParse(row['occurrence'] as String? ?? '');
      if (date == null) return null;
      task = task.occurrenceByKey(Task.dateKey(date));
    }
    if (task == null ||
        task.isCompleted != completed ||
        task.reminderDate == null ||
        task.reminderDate!.toIso8601String() != row['due_at']) {
      return null;
    }
    return task;
  }

  Future<Task?> taskForAlert(int id, {String? token}) async {
    final rows = await (await database.database).query(
      'reminder_state',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty ||
        rows.single['owner_key'] != await activeOwner() ||
        (token != null && rows.single['token'] != token)) {
      return null;
    }
    return _currentTask(
      await TaskDatabase.reminderTasks(
        await database.database,
        rows.single['owner_key'] as String,
        await database.getTasks(ownerKey: rows.single['owner_key'] as String),
      ),
      rows.single,
    );
  }

  /// `complete`, `snooze`, or `undo`, which reopens what `complete` closed
  /// and shows the alert again. False when it did nothing, as for `complete`
  /// on a task in a project where this account is «lector».
  Future<bool> action(int id, String action, {String? token}) async {
    if (!const {'complete', 'snooze', 'undo'}.contains(action)) return false;
    final db = await database.database;
    final result = await db.transaction((tx) async {
      final active = await tx.query(
        'reminder_meta',
        where: 'key = ?',
        whereArgs: ['owner'],
      );
      final alerts = await tx.query(
        'reminder_state',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (active.isEmpty ||
          alerts.isEmpty ||
          alerts.single['owner_key'] != active.single['value'] ||
          (token != null && alerts.single['token'] != token)) {
        return null;
      }
      final alert = alerts.single;
      final owner = alert['owner_key'] as String;
      final rows = await tx.query(
        'tasks',
        where: 'id = ? AND owner_key = ? AND is_deleted = 0',
        whereArgs: [alert['task_id'], owner],
      );
      final task = _currentTask(
        await TaskDatabase.reminderTasks(tx, owner, rows.map(Task.fromMap)),
        alert,
        completed: action == 'undo',
      );
      if (task == null) return null;
      if (action == 'complete' || action == 'undo') {
        // A reader can't complete a task (D9): a notice still in the shade
        // from before writes nothing, so nothing becomes a copy at sync.
        if ((await TaskDatabase.readOnlyProjects(
          tx,
          owner,
        )).contains(task.listId)) {
          return null;
        }
        final done = action == 'complete';
        final occurrence = task.occurrenceId;
        final dates = {...task.completedDates};
        if (occurrence != null) {
          done ? dates.add(occurrence) : dates.remove(occurrence);
        }
        final written =
            (task.isRecurring
                    ? task.copyWith(completedDates: dates.toList()..sort())
                    : task.copyWith(isCompleted: done))
                .withCompletionTimes(Task.fromMap(rows.single), clock())
                .toMap();
        // `complete` stamps the tick's time; `undo` clears it.
        final values = {
          if (task.isRecurring)
            'completedDates': written['completedDates']
          else
            'isCompleted': written['isCompleted'],
          'completedAt': written['completedAt'],
          'completedTimes': written['completedTimes'],
        };
        await tx.update(
          'tasks',
          {
            ...values,
            'sync_pending': owner == 'local' ? 0 : 1,
            'own_reminders_pending': 0,
            'revision': (rows.single['revision'] as int) + 1,
          },
          where: 'id = ? AND owner_key = ?',
          whereArgs: [task.id, owner],
        );
        await tx.delete(
          'reminder_snoozes',
          where: 'identity = ?',
          whereArgs: [alert['identity']],
        );
      } else {
        await tx.insert('reminder_snoozes', {
          'identity': alert['identity'],
          'owner_key': owner,
          'fire_at': clock()
              .toUtc()
              .add(const Duration(minutes: 10))
              .toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return (owner: owner, title: task.title, alert: alert);
    });
    if (result == null) return false;
    await reconcile(result.owner);
    final alert = result.alert;
    // The alert keeps its token, so Undo and the restored alert stay valid.
    final alertToken = alert['token'] as String;
    if (action == 'complete') {
      final copy = await readCopy();
      await driver.showUndo(
        id,
        copy.strings.notificationCompleted(result.title),
        languageCode: copy.languageCode,
        token: alertToken,
      );
    } else if (action == 'undo') {
      await driver.show(
        id,
        PlannedReminder(
          identity: alert['identity'] as String,
          taskId: alert['task_id'] as int?,
          occurrence: alert['occurrence'] as String?,
          due: DateTime.tryParse(alert['due_at'] as String? ?? ''),
          when: DateTime.parse(alert['fire_at'] as String).toLocal(),
          title: alert['title'] as String,
          body: alert['body'] as String,
          languageCode: (await readCopy()).languageCode,
        ),
        token: alertToken,
      );
    }
    return true;
  }
}
