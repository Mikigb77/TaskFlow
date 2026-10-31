# UX loop 2026-10-13-app — batch b6 report (2026-10-14)

**Verdict:** 18 of 19 findings are verified in code. 6 are fully verified, and 12 work in code but still need a phone or an iOS build. UX-493 (the Voz language for online transcription) is still open: the app half is done and the server half isn't. Round 3 left one new minor regression, UX-496 (S1), which isn't planned yet. Nothing was escalated. All three rounds' tests passed.

Evidence level: code reading, ux-tester's widget and unit tests, and the renders `App/build/capture-listening-es-2x.png` and `App/artifacts/auth/login-light.png`. Nothing ran on an emulator or a physical phone.

## Verified (reviewer: fixed, no phone needed)
- **UX-485** · Deleting an empty group closes it without a word. The message now shows on the screen underneath: "Grupo eliminado" / "Group deleted" / "Grup suprimit" (P78, round 1).
- **UX-486** · Time-zone search finds no Spanish or Catalan city names. 55 zones now have Spanish and Catalan names. Legacy `US/*`, `Canada/*` and `Etc/*` ids are hidden, and `regionalSettingsHelp` is removed (P79, round 1).
- **UX-489** · Alias search lists a different city's name. A match through an alias now shows the alias as the subtitle (Shanghai / Pekín), and `montreal` lists one row (P86, round 2; regression R1D-2).
- **UX-490** · Catalan said "Grup eliminat" where the app says "suprimit". It now reads "Grup suprimit" (P85, round 2; regression R1C-1).
- **UX-492** · Voz showed capture-only instructions and an unlabelled technical choice. It now has a heading, plain option names, and its own copy for set-up messages (P87, round 3; round 2 was partly fixed; regression R1A-2).
- **UX-495** · Two "Forgot password?" controls on the sign-in card. There is now one recovery control (P88, round 3; regression R2D-1).

## Verified in code, still needs a phone
- **U9** · Technical options on the capture screen (P34 partly in round 1 → P81 fixed in round 2; its last part, UX-491, was fixed in round 3).
- **UX-115** · The speech language ignored the app's language, forgot the user's choice, and showed a raw code (P34, round 1). Only the on-device path; the online path is UX-493.
- **UX-119** · Share error messages were English-only (P20, round 1).
- **UX-121** · Native labels and the stop button used inconsistent, technical names (P20, round 1).
- **UX-125** · Both launcher shortcuts used the app icon (P20, round 1).
- **UX-420** · The iOS microphone prompt mentioned a "task draft" (P20, round 1). Needs an iOS build.
- **UX-326** · The invitation didn't say who sent it. The card and the review now name the sender (P80, round 1; backend half in bc93848).
- **UX-484** · Sign-in demanded 12 characters, which hid the create-account button (P77, round 1).
- **UX-487** · "Ahora no" on an invitation reopened it at every cold start (P78, round 1).
- **UX-488** · The email-in-use and wrong-password buttons could loop (P83, round 2; regression R1D-1).
- **UX-494** · An empty share said "Share a shorter text" (P84, round 2; regression R1A-4).
- **UX-491** · The first-capture privacy note was a jargon paragraph shown mid-dictation. It is now one short line that fits at 2× in Spanish and Catalan (P87, round 3; round 2 was partly fixed; regression R1A-1).

## Still open
- **UX-493** · S2 · A · The Voz speech language doesn't reach online transcription. The app half is done (P82, round 2): spoken captures store `language` and send it with `ai/drafts/`. The reviewer judged it partly fixed. The cause of what's left is server-side: `Backend/core/serializers.py` (~:295) and `Backend/core/ai.py:88-112` don't use the language yet. This is for the main session. It has failed once, so it isn't escalated.
- **UX-496** (new; R3A-1) · S1 · A · After a failed set-up, Voz says the same thing twice. Both `onDeviceUnavailable` and the `voiceSetupUnavailable` banner end "…así que TaskFlow lo hace en línea.", and the `Configurar…` button stays live. The reviewer's fix: once set-up fails, hide the set-up row (`Configurar…`, `Comprobar de nuevo`) and the `onDeviceUnavailable` line, keeping only the banner, with no copy change (`App/lib/screens/voice_settings_screen.dart:162-190`). Not planned, because b6 ended after round 3.

## Escalations
None.

## Checks for the owner's phone
1. **U9 / UX-491:** fresh install, Spanish, largest text. The first dictation shows "Tus palabras van por internet. Más en Ajustes." once, in whole lines, and the newest words stay visible.
2. **UX-115:** app in Catalan, with a Catalan speaker. Dictating on the phone gives Catalan words, and the Voz choice survives a restart.
3. **UX-119:** in Spanish, share more than 4,000 characters to TaskFlow. The message is in Spanish.
4. **UX-494:** share an empty text to TaskFlow. The message reads "No hay texto que añadir. Comparte un texto con TaskFlow."
5. **UX-121:** in Spanish, the widget picker shows "Toca para dictar una tarea." and the shortcuts read "Dictar una tarea" / "Escribir una tarea".
6. **UX-125:** long-press the launcher icon. The two shortcuts show different icons (a mic and a pencil), and the launcher's mask doesn't clip them.
7. **UX-420 (iOS build):** the Spanish microphone prompt shows the new text.
8. **UX-326:** a real second account sends you an invitation. The Calendar card and the review both name the sender.
9. **UX-487:** on an invitation, tap "Ahora no", force-stop the app and reopen it. You land on Calendar with the card, and the review screen doesn't open.
10. **UX-484 (real server):** sign in with a 6-character wrong password. It reaches the server, and the error offers "Crear una cuenta con este correo".
11. **UX-488 (real server):** with an account made through Google, the recovery path sends an email even though the account has no password.
12. **UX-493 (after the server half):** set Voz to Català and `En línia, en acabar`. Catalan words come back.

## Files changed
- Screens: `App/lib/screens/login_screen.dart`, `invitation_review_screen.dart`, `groups_screen.dart`, `regional_settings_screen.dart`, `other_settings_screen.dart`, `voice_task_screen.dart`, and the new `voice_settings_screen.dart`
- Widgets: `App/lib/widgets/invitation_cards.dart`
- Routes: `App/lib/main.dart` (the `/voiceSettings` route; invitation postpone)
- Logic:
  - `App/lib/providers/invitations_provider.dart`, `regional_provider.dart`
  - `App/lib/services/invitation_links.dart`, `native_speech.dart`, `capture_store.dart`, `capture_processor.dart`
  - `App/lib/models/capture_session.dart`
- Copy: `App/lib/l10n/app_en.arb`, `app_es.arb` and `app_ca.arb`, plus `App/lib/l10n/generated/` (regenerated by `flutter gen-l10n`, not edited by hand)
- Android:
  - `App/android/app/src/main/res/values{,-es,-ca}/strings.xml`
  - `res/xml/capture_shortcuts.xml`
  - `res/drawable/capture_shortcut_voice.xml` and `capture_shortcut_text.xml` (new)
  - `kotlin/com/example/agenda/CaptureEntryBridge.kt`
- iOS: `App/ios/Runner/Info.plist`, plus `en.lproj`, `es.lproj` and `ca.lproj/InfoPlist.strings`
- Tests:
  - `auth_gate_test.dart`, `invitation_review_test.dart`, `groups_screen_test.dart`
  - `regional_ui_test.dart`, `settings_screen_test.dart`
  - `native_resources_test.dart` and `voice_settings_test.dart` (both new)
  - `native_speech_test.dart`, `review_tasks_test.dart`
  - `capture_landing_test.dart`, `capture_result_exits_test.dart`, `capture_sheet_test.dart`, `capture_recovery_test.dart`
  - `support/capture_fixtures.dart`

## Findings that a test now protects
Every finding verified in this batch is covered by a passing test:
- **auth_gate_test.dart:** UX-484 (`:593`, `:638`, `:660`), UX-488, UX-495 (`:936-1018`)
- **invitation_review_test.dart:** UX-326 (`:754-848`), UX-487 (`:849-955`)
- **groups_screen_test.dart:** UX-485 (`:111-162`), UX-490
- **regional_ui_test.dart:** UX-486 (`:446`, `:467`), UX-489
- **voice_settings_test.dart:** U9, UX-115, UX-491 (`:939-1012`), UX-492 (`:736-835`)
- **native_resources_test.dart:** UX-119, UX-121, UX-125, UX-420, UX-494. These tests check the resource strings and the bridge; how things look on a launcher or a phone still needs the device checks above.
- **UX-493:** the app half is covered by `capture_recovery_test.dart` and `voice_settings_test.dart`, but the finding stays open.

## Rounds
- **Round 1:** P77, P80, P78, P79, P20 and P34. Tests passed.
  - Fixed: UX-484, UX-326, UX-485, UX-487, UX-486, UX-121, UX-119, UX-125, UX-420, UX-115.
  - Partly fixed: U9.
  - Regressions: R1D-1 → UX-488, R1D-2 → UX-489, R1C-1 → UX-490, R1A-1 → UX-491, R1A-2 → UX-492, R1A-3 → UX-493, R1A-4 → UX-494.
- **Round 2:** P81–P86. Tests passed.
  - Fixed: U9, UX-488, UX-489, UX-490, UX-494.
  - Partly fixed: UX-491, UX-492, UX-493.
  - Regression: R2D-1 → UX-495.
- **Round 3:** P87 and P88. Tests passed.
  - Fixed: UX-491, UX-492, UX-495.
  - Regression: R3A-1 → UX-496.

## Ledger
`.claude/ux-review/ISSUES.md`:
- 6 lines moved to Verified (UX-485, UX-486, UX-489, UX-490, UX-492, UX-495).
- 12 lines moved to Device check (U9, UX-115, UX-119, UX-121, UX-125, UX-420, UX-326, UX-484, UX-487, UX-488, UX-494, UX-491).
- UX-493 updated in place and still open.
- UX-496 added under Open.
