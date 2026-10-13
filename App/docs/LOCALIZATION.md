# TaskFlow languages

TaskFlow ships English (`en`), Spanish (`es`) and Catalan (`ca`). New installations follow the phone's preferred-language list, choosing the first supported language. If none is supported, the app uses English. A manual choice in **Settings → Language** overrides the phone and persists locally; **Follow phone** restores automatic selection. There is also access from **Time & region**. Changes apply immediately, including open routes. Task titles, notes, dates and unfinished captures are not translated or rewritten.

## Standard for app text

Use Flutter's built-in `gen-l10n` with ARB catalogs. `lib/l10n/app_en.arb` is the template; `app_es.arb` and `app_ca.arb` contain every message. Read text with `context.l10n.messageName` (the extension in `region.dart`). Code without a widget context, such as reminder workers, resolves the same preference and uses the generated `AppLocalizations`. Do not edit `lib/l10n/generated/` manually.

For every new message:

1. Add a descriptive camelCase key to English and the equivalent text to every catalog. Include `@key.description` when meaning or placement is ambiguous.
2. Put variables in named ICU placeholders, with types under `@key.placeholders` in the English template. Translate whole sentences; do not concatenate translated fragments. Use ICU `plural` and `select` for grammatical variation.
3. Use `context.shortDate`, `context.fullDate`, `context.clockTime` or `intl` with the active locale for dates and numbers. Keep internal identifiers, serialized dates and API fields language-independent.
4. Run `flutter gen-l10n`, `flutter test test/localization_catalog_test.dart test/language_selector_test.dart test/regional_preferences_test.dart test/regional_ui_test.dart`, and `flutter analyze`. The catalog test rejects missing/extra keys and lost placeholders. Review the native UI in light/dark and at larger text sizes.

`lib/l10n/app_languages.dart` derives available languages and their native names from the generated catalog. The selector displays **Follow phone**, **English**, **Español**, **Català**, in that order. Future catalog languages appear after these automatically. Native language names help users recover from an unfamiliar language. This display order does not affect automatic phone-language detection. English fallback is explicit and does not depend on alphabetical locale order. Regional clock/week/timezone choices remain independent of UI language.

## Add a language

1. Create a complete `app_<code>.arb`, set `@@locale`, and translate `languageNativeName` to that language's own name. Regenerate; the generated supported locales, resolver and selector include it automatically.
2. Add the corresponding Material localization adapter in `region.dart` if explicit clock/week overrides need to work in its date/time pickers. Verify Flutter Material and Cupertino support for the locale. Existing adapters cover `en`, `es`, `ca`; an unadapted future language retains Flutter's default picker formatting.
3. Translate Android launcher shortcut/widget strings in `android/app/src/main/res/values-<code>/strings.xml`. These launcher surfaces follow the OS language. Add localized iOS permission text in `ios/Runner/<code>.lproj/InfoPlist.strings`, register it in Xcode, and update `CFBundleLocalizations` and `knownRegions`. Compile iOS on macOS.
4. Add the language to the RevenueCat paywall's **Localization** settings, review its product variables and publish. RevenueCat text lives separately from Flutter ARB files; validate delivery in the native app after a full restart. Store-owned purchase dialogs and Customer Center use the SDK/store's available translations.
5. Add a speech language option if the recognition provider supports it. UI language and spoken language are separate; device recognition model availability is checked before recording. AI extraction keeps the language of the user's input, regardless of UI language.

## Errors and external text

Use stable error codes or typed exceptions and map them at the UI boundary (`request_locale.dart`, `capture_problem.dart`, `archive_locale.dart`, `reminder_locale.dart`). Never render raw server exceptions as application copy. Unknown errors receive a localized, actionable fallback; diagnostics remain separate. User-entered content, calendar event titles and filenames stay in their original language.

References: [Flutter internationalization](https://docs.flutter.dev/ui/internationalization), [ARB/ICU messages](https://docs.flutter.dev/ui/internationalization#placeholders-plurals-and-selects).

## Validation — 2026-09-29

- All 795 messages are present in each catalog; catalog tests verify keys, non-empty translations and named placeholders. `flutter gen-l10n` completes without missing translations.
- Full Flutter suite: **232 tests passed**. After the final calendar/sharing error mapping changes, all **15 targeted catalog/sharing tests passed**, including invitations in all three languages at 2× text in both themes.
- `flutter analyze --no-pub`: **No issues found**. `flutter build apk --debug --no-pub`: **passed**. Existing Kotlin migration warnings are unrelated to localization.
- Automated coverage includes phone preference ordering, unsupported-language English fallback, manual overrides, live device-locale changes, SQLite persistence without modifying task/capture records, write-failure rollback, reminder language, Catalan plurals and small-screen/large-text layouts.
- Installed the normal debug APK on Android API 36 (`emulator-5554`) with `adb install -r`. Checked automatic English, Catalan settings/calendar/task editor/native time picker, Catalan persistence after a full restart, Spanish settings/calendar, and light/dark language sheets. Verified the published Catalan RevenueCat paywall and return to the translated app. Restored **Follow phone** and dark appearance, leaving the selector open for review. App data was retained.
- iOS localization resources are configured, but an iOS build/device check requires macOS. Store-owned purchase dialogs and Customer Center translations depend on the provider; no new purchase or speech-recognition recording was tested in this localization pass.

Local evidence (ignored build artifacts): `artifacts/localization-full-tests.log`, `localization-error-tests.log`, `localization-analyze.log`, `localization-build.log`, `localization-language-selector.png`, `localization-selector-ca-light.png`, `localization-calendar-ca.png`, `localization-calendar-es.png`, `localization-paywall-ca.png`, and `revenuecat-catalan-published.png`.
