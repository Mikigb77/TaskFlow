import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:sqflite/sqflite.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/services/task_database.dart';
import 'package:agenda/services/reminder_engine.dart';
import 'package:agenda/services/reminder_copy.dart';
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
  Future<void> schedule(int id, PlannedReminder reminder,
      {required bool exact, required String token}) async {
    final l = lookupAppLocalizations(Locale(reminder.languageCode));
    await plugin.zonedSchedule(
        id,
        reminder.title,
        reminder.body,
        tz.TZDateTime.from(reminder.when, tz.local),
        NotificationDetails(
            android: AndroidNotificationDetails(
                'taskflow_reminders', l.notificationChannel,
                importance: Importance.high,
                priority: Priority.high,
                icon: 'app_notifications_icon',
                actions: reminder.taskId == null
                    ? null
                    : [
                        AndroidNotificationAction(
                            'complete', l.notificationComplete),
                        AndroidNotificationAction(
                            'snooze', l.notificationSnooze),
                      ]),
            iOS: DarwinNotificationDetails(
                categoryIdentifier: reminder.taskId == null
                    ? null
                    : 'task_${reminder.languageCode}')),
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
            android: const AndroidInitializationSettings('app_icon'),
            iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false,
                notificationCategories: [
                  // Retain the legacy category for already delivered alerts.
                  _category('task', strings),
                  for (final locale in AppLocalizations.supportedLocales)
                    _category('task_${locale.languageCode}',
                        lookupAppLocalizations(locale)),
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
    }
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
    if (response.actionId == 'complete' || response.actionId == 'snooze') {
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
