import 'dart:async';
import 'dart:convert';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/reminder_copy.dart';
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
  });
  String signature(bool exact) => jsonEncode([
    when.toUtc().toIso8601String(),
    title,
    body,
    languageCode,
    daily,
    exact,
    due?.toUtc().toIso8601String(),
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
  ReminderEngine(
    this.database,
    this.driver, {
    DateTime Function()? clock,
    this.capacity = 400,
    this.leaseWait = const Duration(seconds: 10),
    Future<ReminderCopy> Function()? readCopy,
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

  static List<PlannedReminder> plan(
    String owner,
    List<Task> tasks,
    ReminderPreferences preferences,
    DateTime now, {
    ReminderCopy? copy,
  }) {
    if (!preferences.enabled) return [];
    final c = copy ?? ReminderCopy.fallback();
    final l = c.strings;
    final result = <PlannedReminder>[];
    for (final task in upcoming(tasks, now)) {
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
      final preferences = await ReminderPreferenceStore(database).read(owner);
      final copy = await readCopy();
      final capabilities = await driver.capability();
      final pending = await driver.pendingIds();
      final planned = plan(owner, tasks, preferences, now, copy: copy);
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
        if (!preferences.enabled ||
            task == null ||
            task.reminderMinutes == -1 ||
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
            due: task.reminderDate,
            when: when,
            title: task.title,
            languageCode: copy.languageCode,
            body: copy.body(task, when.toLocal(), 0),
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
          final stillRelevant =
              row['owner_key'] == owner &&
              preferences.enabled &&
              _currentTask(tasks, row)?.reminderMinutes != -1 &&
              _currentTask(tasks, row) != null;
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
  /// and shows the alert again.
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
        final done = action == 'complete';
        final occurrence = task.occurrenceId;
        final dates = {...task.completedDates};
        if (occurrence != null) {
          done ? dates.add(occurrence) : dates.remove(occurrence);
        }
        final values = task.isRecurring
            ? {'completedDates': jsonEncode(dates.toList()..sort())}
            : {'isCompleted': done ? 1 : 0};
        await tx.update(
          'tasks',
          {
            ...values,
            'sync_pending': owner == 'local' ? 0 : 1,
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
