import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/models/task.dart';
import 'generated/app_localizations.dart';
import 'generated/app_localizations_en.dart';

extension TaskFlowLocale on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsEn();
  String get localeName => Localizations.localeOf(this).toString();
  String clockTime(DateTime date) => TimeOfDay.fromDateTime(date).format(this);
  String shortDate(DateTime date) => DateFormat.MMMd(localeName).format(date);
  String fullDate(DateTime date) =>
      DateFormat.yMMMMEEEEd(localeName).format(date);
  String priorityName(int priority) =>
      switch (priority) { 3 => l10n.high, 2 => l10n.medium, _ => l10n.low };
  String listRole(String role) => switch (role) {
        'owner' => l10n.roleOwner,
        'editor' => l10n.roleEditor,
        'viewer' => l10n.roleViewer,
        _ => role,
      };
  String listColorName(String color) => switch (color) {
        'teal' => l10n.colorTeal,
        'blue' => l10n.colorBlue,
        'violet' => l10n.colorViolet,
        'amber' => l10n.colorAmber,
        'rose' => l10n.colorRose,
        _ => color,
      };
  String reminderLead(int? minutes) => switch (minutes) {
        null => l10n.useDefault,
        -1 => l10n.off,
        0 => l10n.atScheduledTime,
        60 => l10n.hourBefore,
        1440 => l10n.dayBefore,
        _ => l10n.minutesBefore(minutes),
      };
  String repeatName(String repeat) => switch (repeat) {
        'daily' => l10n.daily,
        'weekly' => l10n.weekly,
        'monthly' => l10n.monthly,
        'yearly' => l10n.yearly,
        _ => l10n.neverRepeat
      };
  String repeatLabel(Task task) {
    if (task.repeatInterval == 1 && task.repeatWeekdays.isEmpty) {
      return repeatName(task.recurrence);
    }
    final unit = switch (task.recurrence) {
      'daily' => l10n.days,
      'weekly' => l10n.weeks,
      'monthly' => l10n.months,
      _ => l10n.years
    };
    final interval = l10n.repeatEvery(task.repeatInterval, unit);
    if (task.repeatWeekdays.isEmpty) return interval;
    final days = task.repeatWeekdays
        .map((day) => DateFormat.E(localeName).format(DateTime(2024, 1, day)))
        .join(', ');
    return '$interval · $days';
  }
}

/// Regional formats stay separate from UI language. Explicit clock and week
/// preferences apply to Material date/time pickers as well as task labels.
class RegionalMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const RegionalMaterialDelegate(this.preferences, this.deviceLocale,
      {this.system24Hour});
  final RegionalPreferences preferences;
  final Locale deviceLocale;
  final bool? system24Hour;
  @override
  bool isSupported(Locale locale) => ['en', 'es'].contains(locale.languageCode);
  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    const delegate = GlobalMaterialLocalizations.delegate;
    final display = await delegate.load(locale);
    final device = delegate.isSupported(deviceLocale)
        ? await delegate.load(deviceLocale)
        : display;
    final name = Intl.canonicalizedLocale(locale.toString());
    final formatLocale =
        DateFormat.localeExists(name) ? name : locale.languageCode;
    final clock = switch (preferences.clock) {
      ClockFormat.system => system24Hour == false
          ? TimeOfDayFormat.h_colon_mm_space_a
          : device.timeOfDayFormat(
              alwaysUse24HourFormat: system24Hour ?? false),
      ClockFormat.twelve => TimeOfDayFormat.h_colon_mm_space_a,
      ClockFormat.twentyFour => TimeOfDayFormat.HH_colon_mm,
    };
    final week = preferences.weekStart ?? device.firstDayOfWeekIndex;
    return locale.languageCode == 'es'
        ? _SpanishRegion(formatLocale, clock, week)
        : _EnglishRegion(formatLocale, clock, week);
  }

  @override
  bool shouldReload(RegionalMaterialDelegate old) =>
      preferences.clock != old.preferences.clock ||
      preferences.weekStart != old.preferences.weekStart ||
      deviceLocale != old.deviceLocale ||
      system24Hour != old.system24Hour;
}

class _EnglishRegion extends MaterialLocalizationEn {
  _EnglishRegion(String locale, this.clock, this.week)
      : super(
            localeName: locale,
            fullYearFormat: DateFormat.y(locale),
            compactDateFormat: DateFormat.yMd(locale),
            shortDateFormat: DateFormat.yMMMd(locale),
            mediumDateFormat: DateFormat.MMMEd(locale),
            longDateFormat: DateFormat.yMMMMEEEEd(locale),
            yearMonthFormat: DateFormat.yMMMM(locale),
            shortMonthDayFormat: DateFormat.MMMd(locale),
            decimalFormat: NumberFormat.decimalPattern(locale),
            twoDigitZeroPaddedFormat: NumberFormat('00', locale));
  final TimeOfDayFormat clock;
  final int week;
  @override
  TimeOfDayFormat get timeOfDayFormatRaw => clock;
  @override
  int get firstDayOfWeekIndex => week;
}

class _SpanishRegion extends MaterialLocalizationEs {
  _SpanishRegion(String locale, this.clock, this.week)
      : super(
            localeName: locale,
            fullYearFormat: DateFormat.y(locale),
            compactDateFormat: DateFormat.yMd(locale),
            shortDateFormat: DateFormat.yMMMd(locale),
            mediumDateFormat: DateFormat.MMMEd(locale),
            longDateFormat: DateFormat.yMMMMEEEEd(locale),
            yearMonthFormat: DateFormat.yMMMM(locale),
            shortMonthDayFormat: DateFormat.MMMd(locale),
            decimalFormat: NumberFormat.decimalPattern(locale),
            twoDigitZeroPaddedFormat: NumberFormat('00', locale));
  final TimeOfDayFormat clock;
  final int week;
  @override
  TimeOfDayFormat get timeOfDayFormatRaw => clock;
  @override
  int get firstDayOfWeekIndex => week;
}

Widget regionalMedia(
    RegionalPreferences preferences, BuildContext context, Widget? child,
    {bool? system24Hour}) {
  final media = MediaQuery.of(context);
  return MediaQuery(
      data: media.copyWith(
          alwaysUse24HourFormat: switch (preferences.clock) {
        ClockFormat.system => system24Hour ?? media.alwaysUse24HourFormat,
        ClockFormat.twelve => false,
        ClockFormat.twentyFour => true,
      }),
      child: child ?? const SizedBox.shrink());
}

// Imported schedules can predate 2000 or extend beyond 2101. Keep those valid
// dates editable rather than changing them merely to open a picker.
DateTime pickerFirstDate(DateTime? current) =>
    current != null && current.year < 2000
        ? DateTime(current.year)
        : DateTime(2000);
DateTime pickerLastDate(DateTime? current) =>
    current != null && current.year > 2100
        ? DateTime(current.year, 12, 31)
        : DateTime(2101);
