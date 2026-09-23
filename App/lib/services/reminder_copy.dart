import 'dart:ui';
import 'package:agenda/l10n/generated/app_localizations.dart';
import 'package:agenda/providers/regional_provider.dart';
import 'package:agenda/services/task_database.dart';

/// Background workers and notification actions have no widget localization
/// context. Resolve the same persisted preference and device fallback as the UI.
Future<AppLocalizations> readReminderStrings(TaskDatabase database,
    {List<Locale>? deviceLocales}) async {
  var preferences = const RegionalPreferences();
  try {
    preferences = await RegionalPreferenceStore(database).read();
  } catch (_) {
    // Match the UI's device fallback if a regional preference cannot be read.
  }
  final locale = preferences
      .localeFor(deviceLocales ?? PlatformDispatcher.instance.locales);
  return lookupAppLocalizations(Locale(locale.languageCode));
}
