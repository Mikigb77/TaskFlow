import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:sqflite/sqflite.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/reminder_engine.dart';
import 'package:agenda/services/reminder_copy.dart';
import 'package:agenda/services/feedback_timeout.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';

@pragma('vm:entry-point')
void notificationActionBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await TaskReminders.initialize(background: true);
  await TaskReminders.respond(response);
}

@pragma('vm:entry-point')
void reminderWorker() {
  Workmanager().executeTask((name, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    try {
      await TaskReminders.initialize(background: true);
      final owner = await TaskReminders.engine.activeOwner();
      if (owner != null) await TaskReminders.engine.reconcile(owner);
      return true;
    } catch (_) {
      await TaskReminders.recordError('background_failed');
      return false;
    }
  });
}

/// How a reminder shows. Marked as a reminder, so Do Not Disturb lets it
/// through when its «Reminders» exception is allowed.
@visibleForTesting
NotificationDetails reminderNotificationDetails(PlannedReminder reminder,
    {bool silent = false}) {
  final l = lookupAppLocalizations(Locale(reminder.languageCode));
  return NotificationDetails(
      android: AndroidNotificationDetails(
          'taskflow_reminders', l.notificationChannel,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'app_notifications_icon',
          silent: silent,
          category: AndroidNotificationCategory.reminder,
          actions: reminder.taskId == null
              ? null
              : [
                  AndroidNotificationAction('complete', l.notificationComplete),
                  AndroidNotificationAction('snooze', l.notificationSnooze),
                ]),
      iOS: DarwinNotificationDetails(
          presentSound: silent ? false : null,
          categoryIdentifier: reminder.taskId == null
              ? null
              : 'task_${reminder.languageCode}'));
}

/// The silent «Completed» line with Undo: not a reminder, so no reminder
/// category.
@visibleForTesting
NotificationDetails undoNotificationDetails(
    String languageCode, Duration timeout) {
  final l = lookupAppLocalizations(Locale(languageCode));
  return NotificationDetails(
      android: AndroidNotificationDetails(
          'taskflow_reminders', l.notificationChannel,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'app_notifications_icon',
          silent: true,
          // Gone by itself once Undo is no longer likely.
          timeoutAfter: timeout.inMilliseconds,
          actions: [AndroidNotificationAction('undo', l.undo)]),
      iOS: DarwinNotificationDetails(
          presentSound: false, categoryIdentifier: 'undo_$languageCode'));
}

class _NotificationDriver implements ReminderDriver {
  final FlutterLocalNotificationsPlugin plugin;
  _NotificationDriver(this.plugin);
  @override
  Future<ReminderCapability> capability() async {
    if (Platform.isAndroid) {
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()!;
      return ReminderCapability(
          allowed: await android.areNotificationsEnabled() ?? false,
          exact: await android.canScheduleExactNotifications() ?? false);
    }
    final apple = plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return ReminderCapability(
        allowed: (await apple?.checkPermissions())?.isEnabled ?? false,
        exact: true);
  }

  @override
  Future<Set<int>> pendingIds() async =>
      (await plugin.pendingNotificationRequests()).map((n) => n.id).toSet();
  @override
  Future<void> cancel(int id) => plugin.cancel(id);
  @override
  Future<void> show(int id, PlannedReminder reminder,
          {required String token}) =>
      plugin.show(id, reminder.title, reminder.body,
          reminderNotificationDetails(reminder, silent: true),
          payload: jsonEncode({'id': id, 'token': token}));

  @override
  Future<void> showUndo(int id, String text,
      {required String languageCode, required String token}) async {
    final timeout = await TaskReminders.undoTimeout();
    return plugin.show(
        id, text, null, undoNotificationDetails(languageCode, timeout),
        payload: jsonEncode({'id': id, 'token': token}));
  }

  @override
  Future<void> schedule(int id, PlannedReminder reminder,
      {required bool exact, required String token}) async {
    await plugin.zonedSchedule(
        id,
        reminder.title,
        reminder.body,
        tz.TZDateTime.from(reminder.when, tz.local),
        reminderNotificationDetails(reminder),
        payload: jsonEncode({'id': id, 'token': token}),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents:
            reminder.daily ? DateTimeComponents.time : null);
  }
}

class ReminderReference {
  final int id;
  final String token;
  const ReminderReference(this.id, this.token);
}

class TaskReminders {
  static final plugin = FlutterLocalNotificationsPlugin();
  static final openRequest = ValueNotifier<ReminderReference?>(null);
  static final changes = StreamController<void>.broadcast();
  static final actionChanges = StreamController<void>.broadcast();
  /// The shortest time Completed: … and its Undo stay; longer when the phone's accessibility timeout asks for it.
  static const undoWindow = Duration(seconds: 10);
  static const _undoTimeoutKey = 'undo_timeout_ms';
  static Future<void>? _initializing;
  static Future<void> _queue = Future.value();
  static bool get supported => Platform.isAndroid || Platform.isIOS;
  static final engine = ReminderEngine(
      TaskDatabase(), _NotificationDriver(plugin),
      capacity: Platform.isIOS ? 60 : 400);

  static List<Task> upcoming(List<Task> tasks, DateTime now) =>
      ReminderEngine.upcoming(tasks, now);

  static Future<void> initialize({bool background = false}) async {
    if (!supported) return;
    await (_initializing ??= _initialize(background).catchError((Object error) {
      _initializing = null;
      throw error;
    }));
  }

  static Future<void> _refreshTimezone() async {
    try {
      tz.setLocalLocation(tz
          .getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (_) {
      /* UTC fallback; visible scheduling uses the resulting zone. */
    }
  }

  static Future<void> _initialize(bool background) async {
    tzdata.initializeTimeZones();
    await _refreshTimezone();
    // Finish schema creation before registering work that can start immediately.
    await TaskDatabase().database;
    final strings = await readReminderStrings(TaskDatabase());
    await plugin.initialize(
        InitializationSettings(
            android: const AndroidInitializationSettings('app_notifications_icon'),
            iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false,
                notificationCategories: [
                  // Retain the legacy category for already delivered alerts.
                  _category('task', strings),
                  for (final locale in AppLocalizations.supportedLocales) ...[
                    _category('task_${locale.languageCode}',
                        lookupAppLocalizations(locale)),
                    DarwinNotificationCategory('undo_${locale.languageCode}',
                        actions: [
                          DarwinNotificationAction.plain(
                              'undo', lookupAppLocalizations(locale).undo),
                        ]),
                  ],
                ])),
        onDidReceiveNotificationResponse: respond,
        onDidReceiveBackgroundNotificationResponse:
            notificationActionBackground);
    await _updateChannel(strings);
    if (!background) {
      final launch = await plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true &&
          launch?.notificationResponse != null) {
        _launchResponse = launch!.notificationResponse;
      }
      try {
        await Workmanager().initialize(reminderWorker);
        if (Platform.isAndroid) {
          await Workmanager().registerPeriodicTask(
              'taskflow-reminders', 'refresh-reminders',
              frequency: const Duration(hours: 1),
              existingWorkPolicy: ExistingPeriodicWorkPolicy.keep);
        }
      } catch (_) {
        await recordError('background_unavailable');
      }
      unawaited(rememberUndoTimeout());
    }
  }

  /// Notification actions run in a background isolate that cannot ask the
  /// phone for its accessibility timeout, so the app saves it while open.
  static Future<void> rememberUndoTimeout() async {
    if (!supported) return;
    try {
      final timeout = await FeedbackTimeout.forAction(original: undoWindow);
      await (await TaskDatabase().database).insert('reminder_meta',
          {'key': _undoTimeoutKey, 'value': '${timeout.inMilliseconds}'},
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {/* Undo then stays for undoWindow. */}
  }

  /// How long `Completed: …` and its Undo stay: the saved accessibility
  /// timeout when it is longer than [undoWindow].
  static Future<Duration> undoTimeout() async {
    try {
      final rows = await (await TaskDatabase().database).query('reminder_meta',
          columns: ['value'], where: 'key = ?', whereArgs: [_undoTimeoutKey]);
      final saved = rows.isEmpty
          ? null
          : int.tryParse('${rows.single['value']}');
      if (saved != null && saved > undoWindow.inMilliseconds) {
        return Duration(milliseconds: saved);
      }
    } catch (_) {/* Fall back to the shortest window. */}
    return undoWindow;
  }

  static DarwinNotificationCategory _category(String id, AppLocalizations l) =>
      DarwinNotificationCategory(id, actions: [
        DarwinNotificationAction.plain('complete', l.notificationComplete),
        DarwinNotificationAction.plain('snooze', l.notificationSnooze),
      ]);

  static Future<void> _updateChannel(AppLocalizations strings) async {
    if (!Platform.isAndroid) return;
    // Keep the same channel ID. Android preserves the user's sound/importance
    // choices while allowing its visible name to follow the app language.
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()!
        .createNotificationChannel(AndroidNotificationChannel(
            'taskflow_reminders', strings.notificationChannel,
            importance: Importance.high));
  }

  /// Called after a saved preference, a system language change, or app resume.
  /// This also works without an open widget tree in a notification worker.
  static Future<void> refreshLanguage() {
    if (!supported) return Future.value();
    return _queue = _queue.catchError((_) {}).then((_) async {
      try {
        await initialize();
        await _refreshTimezone();
        await _updateChannel(await readReminderStrings(TaskDatabase()));
        final owner = await engine.activeOwner();
        if (owner != null) await engine.reconcile(owner);
        changes.add(null);
      } catch (_) {
        await recordError('refresh_failed');
      }
    });
  }

  static NotificationResponse? _launchResponse;
  static Future<void> handleLaunch() async {
    final response = _launchResponse;
    _launchResponse = null;
    if (response != null) await respond(response);
  }

  static Future<void> respond(NotificationResponse response) async {
    final Map data;
    try {
      data = jsonDecode(response.payload ?? '') as Map;
    } catch (_) {
      return;
    }
    final id = data['id'];
    final token = data['token'];
    if (id is! int || token is! String) return;
    if (const {'complete', 'snooze', 'undo'}.contains(response.actionId)) {
      try {
        await engine.action(id, response.actionId!, token: token);
        changes.add(null);
        actionChanges.add(null);
      } catch (_) {
        await recordError('action_failed');
      }
    } else {
      openRequest.value = ReminderReference(id, token);
    }
  }

  static Future<void> recordError(String message) async {
    try {
      await (await TaskDatabase().database).insert(
          'reminder_meta', {'key': 'error', 'value': message},
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {/* The task database remains the source of truth. */}
  }

  static Future<void> activate(String owner) async {
    if (!supported) return;
    try {
      await initialize();
    } catch (_) {
      await recordError('setup_failed');
    }
    try {
      // Persist ownership even if notification initialization failed.
      await engine.activate(owner);
      await engine.reconcile(owner);
    } catch (_) {
      await recordError('account_refresh_failed');
    }
  }

  static Future<void> sync(List<Task> tasks, {String ownerKey = 'local'}) {
    if (!supported) return Future.value();
    _queue = _queue.catchError((_) {}).then((_) async {
      try {
        await initialize();
        await _refreshTimezone();
        await engine.reconcile(ownerKey);
        changes.add(null);
      } catch (_) {
        await recordError('refresh_failed');
      }
    });
    return _queue;
  }

  static Future<bool> requestPermission() async {
    if (!supported) return false;
    await initialize();
    if (Platform.isAndroid) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()!
              .requestNotificationsPermission() ??
          false;
    }
    return await plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()!
            .requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  static Future<void> requestExactAccess() async {
    if (Platform.isAndroid) {
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()!
          .requestExactAlarmsPermission();
    }
  }

  static Future<void> retrySetup() async {
    if (!supported) return;
    await (await TaskDatabase().database)
        .delete('reminder_meta', where: 'key = ?', whereArgs: ['error']);
    _initializing = null;
    await initialize();
  }
}

/// The phone's side of reminders: support, permission and exact alarms.
/// Screens go through this so widget tests can stand in for the phone.
class ReminderAccess {
  const ReminderAccess();
  bool get supported => TaskReminders.supported;

  /// Off the phone there is nothing to allow, so nothing is reported missing.
  Future<ReminderCapability> capability() async {
    if (!supported) return const ReminderCapability(allowed: true, exact: true);
    await TaskReminders.initialize();
    return TaskReminders.engine.driver.capability();
  }

  Future<bool> requestPermission() => TaskReminders.requestPermission();
  Future<void> requestExactAccess() => TaskReminders.requestExactAccess();

  /// TaskFlow's own notifications page in the phone's settings, where one
  /// switch allows them; App info when the phone has no such page.
  Future<void> openNotificationSettings() async {
    try {
      await _appSettings.invokeMethod<void>('openNotificationSettings');
    } catch (_) {
      try {
        await openAppSettings();
      } catch (_) {/* Nothing more to open on this phone. */}
    }
  }

  static const _appSettings = MethodChannel('taskflow/app-settings');
  Future<void> reconcile(String owner) async {
    if (!supported) return;
    await TaskReminders.initialize();
    await TaskReminders.engine.reconcile(owner);
  }
}
