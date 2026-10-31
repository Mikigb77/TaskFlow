## UX verify — 2026-10-19-app b5 r3, area D (P218) — 2026-10-20

**Verdict:** UX-1653 is fixed in code and by test. No regressions. Three checks can only be done on a device and are left to the emulator lane.

### Results

| Finding | Result | Evidence |
|---|---|---|
| UX-1653 | fixed | `App/lib/main.dart:135-143` `didChangeLocales`: keeps `setState`, then `AppLanguageBridge.apply(ref.read(regionalProvider).language).then((_) => TaskReminders.refreshLanguage())`. The no-loop comment is there as briefed. `apply` (`App/lib/services/app_language.dart:34-61`) sets `phoneLocales`, which notifies `phone`, so `_phoneLocalesChanged` (`main.dart:130-132`) rebuilds `MaterialApp` with `locale: regional.localeFor(phone)` (`:437-449`). `apply` catches errors and returns at once off Android, so the reminder refresh still runs. The class doc (`app_language.dart:12-13`) now says the bridge is applied "when the phone's languages change". No comment saying "don't re-apply" remains in `App/lib`. `App/lib/services/reminder_copy.dart:12-27` `_phoneLocales(database, preferences)` uses this order: bridge, then `PlatformDispatcher` when Idioma is `AppLanguages.system`, then the saved row, then `PlatformDispatcher`. Both callers pass it (`:44`, `:53`) and keep their `deviceLocales` parameter. `AppLanguageBridge.kt:40` sets `applicationLocales` only when they differ, so the English-with-a-new-region case settles after one round trip. Tester: five widget tests in `App/test/phone_language_change_test.dart` and three unit tests in `reminder_engine_test.dart` pass, covering all six acceptance checks. Device only: whether the process survives an Android language change, a Catalan reminder after swipe-away, and no repeated configuration changes in logcat. |

### Regressions

None found.

### Not regressions (checked)
- **A reminder refresh on resume can run before the bridge answers.** On return from Android settings, `didChangeAppLifecycleState` (`main.dart:147-150`) queues `refreshLanguage()` at once, and under «Como el teléfono» that refresh can read the old `phoneLocales`. The `didChangeLocales` refresh joins the same serial `_queue` (`notification_service.dart:293-306`) only after `apply` answers, so it runs last and the reminders end up in the new language. The stale refresh lasts only a moment and is overwritten.
- **One frame in the old language.** `setState` in `didChangeLocales` rebuilds while `phoneLocales` is still old, so the language stays the same until the bridge answers. Because `locale:` is explicit, the app doesn't flash between languages: it changes once.
- **An extra `apply` when Idioma changes.** `language_selector.dart:65` → configuration change → one more `apply` with the same answer, plus a second reminder refresh. This was expected in the brief; it doesn't change what the user sees.
- **Below Android 13 and off Android.** The bridge answers null, or isn't called, so `phoneLocales` stays null and the app and reminders follow Flutter's live locales, as before P215.
- **Background isolate.** `phoneLocales` is null there. With «Como el teléfono» it uses `PlatformDispatcher`, which is live. With a named Idioma it uses the saved row, which keeps UX-1649.
- **A stale first frame on cold start.** `main()` seeds `phoneLocales` from the saved row (`main.dart:54-58`). If the phone's language changed while the app was closed, the first frame can use the previous language until `initState`'s `apply` answers. This comes from P215, which the brief told us not to touch, so it isn't a regression of this change. The emulator lane's cold-start check would show whether it's visible.

### Renders
This change has no visual, copy or layout changes, so no preview applies. Language switching while the app runs can't be seen in a render.
