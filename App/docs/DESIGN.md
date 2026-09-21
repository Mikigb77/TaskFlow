# TaskFlow visual system

The calendar remains the first screen. The design uses warm white or charcoal surfaces, restrained teal accents, and locally bundled Manrope typography. Color reinforces priority; every task also has a written priority label and a visible time.

## References

Reviewed the official interfaces and product material for [Things](https://culturedcode.com/things/), [Todoist](https://www.todoist.com/features), and [TickTick](https://ticktick.com/). The useful patterns were generous whitespace, clear hierarchy, subtle surfaces, quick capture, and accessible navigation. TaskFlow has its own palette and layout; no competitor assets are included.

Manrope is bundled from [Google Fonts](https://github.com/google/fonts/tree/main/ofl/manrope), with its SIL Open Font License in `assets/fonts/OFL.txt`. Fonts work offline.

## Behavior

- The sun/moon control changes appearance immediately and remembers it on this device. Settings also offers System mode. Restoring appearance finishes before the normal app renders.
- Calendar, Tasks, and Settings retain their state when switching tabs. The calendar supports month/week views, swiping, month navigation, Today, and pull-to-refresh.
- Capture controls have their own space below the list and never cover task cards.
- Search matches titles and notes. Today and High priority filters work together with search.
- Completion offers Undo. Task editing preserves completion and the chosen date/time.
- One shared editor handles new tasks, AI draft review, and edits. AI drafts still require review and explicit saving.
- Native pickers and dialogs follow the active theme. Controls have tooltips or labels, priorities do not rely on color alone, and layouts accommodate enlarged text and small screens.

## Verification

From `App/`, run `flutter test` and `flutter analyze`.

`integration_test/appearance_test.dart` exercises navigation and captures the calendar, agenda, editor, task list, settings, account, and voice screens in both themes. It uses synthetic in-memory tasks, with no account, AI, database, or notification writes. Screenshots are saved to the ignored `artifacts/design/` directory by the accompanying driver.

Run this on a disposable development emulator: Flutter drive can replace or uninstall the app as part of its test lifecycle. On a fresh test emulator:

```sh
flutter drive -d emulator-5554 --driver=test_driver/appearance_test.dart --target=integration_test/appearance_test.dart
```

This builds a test entry point. Reinstall the normal `lib/main.dart` app after testing. For the local backend, build debug APKs with `flutter build apk --debug --split-per-abi`; release builds require HTTPS.
