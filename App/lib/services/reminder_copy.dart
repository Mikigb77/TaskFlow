import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:agenda/l10n/app_languages.dart';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/l10n/generated/app_localizations_en.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/services/app_language.dart';
import 'package:agenda/services/reminder_plans.dart';
import 'package:agenda/services/task_database.dart';

/// The phone's languages: the bridge's answer; else, with «Como el teléfono»,
/// Flutter's, because no per-app language is set, so they are the phone's and
/// live, also in a background isolate; else the copy the bridge saved, needed
/// only when Idioma names a language, because Flutter then reports the app's;
/// else Flutter's.
Future<List<Locale>> _phoneLocales(
  TaskDatabase database,
  RegionalPreferences preferences,
) async =>
    AppLanguageBridge.phoneLocales ??
    (preferences.language == AppLanguages.system
        ? PlatformDispatcher.instance.locales
        : null) ??
    await AppLanguageBridge.readSavedPhoneLocales(database) ??
    PlatformDispatcher.instance.locales;

Future<RegionalPreferences> _readRegional(TaskDatabase database) async {
  try {
    return await RegionalPreferenceStore(database).read();
  } catch (_) {
    // Match the UI's device fallback if a regional preference cannot be read.
    return const RegionalPreferences();
  }
}

/// Background workers and notification actions have no widget localization
/// context. Resolve the same persisted preference and device fallback as the UI.
Future<AppLocalizations> readReminderStrings(TaskDatabase database,
    {List<Locale>? deviceLocales}) async {
  final preferences = await _readRegional(database);
  final locale = preferences
      .localeFor(deviceLocales ?? await _phoneLocales(database, preferences));
  return lookupAppLocalizations(Locale(locale.languageCode));
}

/// The language and the clock a reminder is written in, resolved the way the
/// app resolves them, so a notification reads `17:00` where the app does.
Future<ReminderCopy> readReminderCopy(TaskDatabase database,
    {List<Locale>? deviceLocales, bool? system24Hour}) async {
  final preferences = await _readRegional(database);
  final devices = deviceLocales ?? await _phoneLocales(database, preferences);
  final locale = Locale(preferences.localeFor(devices).languageCode);
  // The same phone setting main.dart reads for the app's own clock.
  final system = system24Hour ??
      (!kIsWeb &&
              [TargetPlatform.android, TargetPlatform.iOS]
                  .contains(defaultTargetPlatform)
          ? PlatformDispatcher.instance.alwaysUse24HourFormat
          : null);
  final clock = await RegionalMaterialDelegate(
    preferences,
    devices.firstOrNull ?? const Locale('en'),
    system24Hour: system,
  ).load(locale);
  return ReminderCopy(
    lookupAppLocalizations(locale),
    clock,
    use24: switch (preferences.clock) {
      ClockFormat.system => system ?? false,
      ClockFormat.twelve => false,
      ClockFormat.twentyFour => true,
    },
  );
}

/// Reminder text leads with when, as a clock time, so it stays true however
/// late the phone delivers it.
class ReminderCopy {
  ReminderCopy(this.strings, this._formats, {required this.use24});

  /// English with a 12-hour clock, for planning without a stored preference.
  /// It needs no locale data, so plain unit tests can plan too.
  ReminderCopy.fallback()
      : strings = AppLocalizationsEn(),
        _formats = const DefaultMaterialLocalizations(),
        use24 = false;

  final AppLocalizations strings;
  final MaterialLocalizations _formats;

  /// Whether times read `17:00` rather than `5:00 PM`.
  final bool use24;

  String get languageCode => strings.localeName;

  /// The notification body for [task], whose alert fires at [when] with
  /// [lead] minutes of warning. A snoozed alert passes lead 0, so it has no
  /// “in N min” tail.
  String body(Task task, DateTime when, int lead) {
    final deadline = task.reminderAnchor == 'deadline';
    if (!task.reminderHasTime) {
      // Date-only alerts fire on the day itself.
      return deadline
          ? strings.notificationDeadlineToday
          : strings.notificationToday;
    }
    final due = task.reminderDate!;
    final (:clock, :hour) = _clock(due);
    final whenDay = Task.day(when);
    final dueDay = Task.day(due);
    final day = dueDay == whenDay
        ? 'today'
        : dueDay == DateTime(whenDay.year, whenDay.month, whenDay.day + 1)
            ? 'tomorrow'
            : 'other';
    // The weekday date used across the app (`vie, 17 oct`): the regional
    // formats build it from DateFormat.MMMEd, like weekdayDate.
    final date = _formats.formatMediumDate(due);
    if (deadline) return strings.notificationDeadlineAt(day, date, clock, hour);
    var at = strings.notificationAt(day, date, clock, hour);
    // Two or more days ahead the line starts with the date, which Spanish and
    // Catalan write in lowercase (`vie, 25 sept`); a line starts capitalised.
    if (day == 'other' && at.isNotEmpty) {
      at = at[0].toUpperCase() + at.substring(1);
    }
    // A day or more ahead, the day already says how far it is.
    if (lead <= 0 || lead >= 1440) return at;
    return lead % 60 == 0
        ? strings.notificationInHours(at, lead ~/ 60)
        : strings.notificationInMinutes(at, lead);
  }

  /// [value]'s time as the app's clock writes it, and the hour as shown:
  /// Spanish and Catalan say `a la 1:00` but `a las 17:00`.
  ({String clock, int hour}) _clock(DateTime value) {
    final time = TimeOfDay.fromDateTime(value);
    final format = _formats.timeOfDayFormat(alwaysUse24HourFormat: use24);
    return (
      clock: _formats.formatTimeOfDay(time, alwaysUse24HourFormat: use24),
      hour: hourFormat(of: format) == HourFormat.h
          ? time.hourOfPeriod
          : time.hour,
    );
  }

  /// A plan's notification text for [task], [daysBefore] its plan's anchor
  /// (the deadline, else the task's day), with that day and its time if it
  /// has one, as the single reminder writes them: «Faltan 12 días · jue, 12
  /// nov», «Es mañana a las 17:00», «Fecha límite: jue, 12 nov · faltan 12
  /// días», «Fecha límite: hoy». The day after (-1), «Era para ayer», or
  /// «Venció ayer» for a task with a deadline.
  String planBody(Task task, int daysBefore) {
    final deadline = task.deadline != null;
    if (daysBefore < 0) {
      return deadline
          ? strings.reminderPlanNoticeDue
          : strings.reminderPlanNoticeWas;
    }
    final anchor = ReminderPlans.anchor(task)!;
    final timed = deadline ? task.deadlineHasTime : task.hasTime;
    final medium = _formats.formatMediumDate(anchor);
    if (!timed) {
      return switch ((deadline, daysBefore)) {
        (true, 0) => strings.notificationDeadlineToday,
        (true, 1) => strings.reminderPlanNoticeDeadlineTomorrow,
        (true, _) => strings.reminderPlanNoticeDeadlineDays(daysBefore, medium),
        (false, 0) => strings.reminderPlanNoticeToday,
        (false, 1) => strings.reminderPlanNoticeTomorrow,
        (false, _) => strings.reminderPlanNoticeDays(daysBefore, medium),
      };
    }
    final (:clock, :hour) = _clock(anchor);
    if (daysBefore >= 2) {
      final date = '$medium, $clock';
      return deadline
          ? strings.reminderPlanNoticeDeadlineDays(daysBefore, date)
          : strings.reminderPlanNoticeDays(daysBefore, date);
    }
    if (deadline) {
      return strings.notificationDeadlineAt(
        daysBefore == 0 ? 'today' : 'tomorrow',
        medium,
        clock,
        hour,
      );
    }
    return daysBefore == 0
        ? strings.reminderPlanNoticeTodayAt(hour, clock)
        : strings.reminderPlanNoticeTomorrowAt(hour, clock);
  }
}
