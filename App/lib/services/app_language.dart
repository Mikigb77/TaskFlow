import 'dart:convert';
import 'package:agenda/l10n/app_languages.dart';
import 'package:agenda/services/task_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:sqflite/sqflite.dart';

/// Idioma's choice as Android's per-app language (Android 13+), so the widget,
/// the launcher shortcuts and the share messages speak the app's language, as
/// the app and its reminders do. «Como el teléfono» sends an empty list.
/// Applied at start, whenever Idioma changes and when the phone's languages
/// change; off Android nothing is called.
abstract final class AppLanguageBridge {
  static const channel = MethodChannel('taskflow/app-language');

  /// The `app_preferences` row holding the phone's last reported languages,
  /// for the first frame and for background reminders. Kept on the phone only.
  static const _savedScope = 'phone-locales';

  /// The phone's own languages, as a listenable so the app rebuilds when they
  /// arrive. Null where Android doesn't report them (below Android 13, off
  /// Android).
  static final phone = ValueNotifier<List<Locale>?>(null);

  /// The phone's own languages. Under a per-app language Flutter's locales are
  /// the app's, so whatever means "the phone" reads them from here.
  static List<Locale>? get phoneLocales => phone.value;
  static set phoneLocales(List<Locale>? value) => phone.value = value;

  /// The phone's languages, or [flutter]'s where Android doesn't report them.
  static List<Locale> phoneOr(List<Locale> flutter) => phoneLocales ?? flutter;

  static Future<void> apply(String language, {TaskDatabase? database}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    List<String>? tags;
    try {
      tags = await channel.invokeListMethod<String>('apply', {
        'languages': [
          if (language != AppLanguages.system &&
              AppLanguages.supports(language))
            language,
        ],
      });
      phoneLocales = tags == null || tags.isEmpty
          ? null
          : tags.map(_locale).toList(growable: false);
    } catch (_) {
      // The app keeps its language; only the entries outside it stay the phone's.
      return;
    }
    if (tags == null || tags.isEmpty) return;
    try {
      await (await (database ?? TaskDatabase()).database).insert(
          'app_preferences',
          {'scope': _savedScope, 'data': jsonEncode(tags)},
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {
      // The next start asks Android again; only the first frame may differ.
    }
  }

  /// The phone's languages as last reported by [apply], or null when none
  /// were saved or the row can't be read.
  static Future<List<Locale>?> readSavedPhoneLocales([
    TaskDatabase? database,
  ]) async {
    try {
      final rows = await (await (database ?? TaskDatabase()).database).query(
        'app_preferences',
        where: 'scope = ?',
        whereArgs: [_savedScope],
      );
      if (rows.isEmpty) return null;
      final tags = (jsonDecode(rows.single['data'] as String) as List)
          .cast<String>();
      return tags.isEmpty ? null : tags.map(_locale).toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  /// A BCP 47 tag («es-ES», «zh-Hant-TW», «en-US-u-fw-mon») as a [Locale].
  static Locale _locale(String tag) {
    final parts = tag.split('-');
    String? script;
    String? country;
    for (final part in parts.skip(1)) {
      if (part.length == 1) break; // An extension: the rest isn't a subtag.
      if (part.length == 4) {
        script ??= part;
      } else if (part.length == 2 || part.length == 3) {
        country ??= part.toUpperCase();
      }
    }
    return Locale.fromSubtags(
      languageCode: parts.first,
      scriptCode: script,
      countryCode: country,
    );
  }
}
