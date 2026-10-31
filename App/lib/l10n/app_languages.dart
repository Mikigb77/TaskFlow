import 'package:flutter/widgets.dart';
import 'generated/app_localizations.dart';

/// The generated ARB catalog is the source of truth for available languages.
abstract final class AppLanguages {
  static const system = 'system';
  static const fallback = Locale('en');
  static List<Locale> get supported => AppLocalizations.supportedLocales;

  // Display order is independent of the phone's preferred-language order.
  // Future catalog languages still appear automatically after these three.
  static List<String> get displayCodes => <String>{
        for (final code in const ['en', 'es', 'ca'])
          if (supports(code)) code,
        ...supported.map((locale) => locale.languageCode),
      }.toList(growable: false);

  static bool supports(String? code) =>
      supported.any((locale) => locale.languageCode == code);

  // Autonyms remain recognizable even when the current UI language is unfamiliar.
  static String nativeName(String code) => lookupAppLocalizations(
        Locale(supports(code) ? code : 'en'),
      ).languageNativeName;

  static Locale resolve(String preference, List<Locale>? devices) {
    final preferred = devices ?? const <Locale>[];
    final language = supports(preference)
        ? preference
        : preferred
                .where((locale) => supports(locale.languageCode))
                .firstOrNull
                ?.languageCode ??
            fallback.languageCode;
    // Keep the phone's region for formatting; language does not change its
    // clock, first weekday, timezone or any stored task schedules.
    return Locale(language, preferred.firstOrNull?.countryCode);
  }
}
