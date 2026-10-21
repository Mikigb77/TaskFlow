# Report: run 2026-10-19-app, batch b7 (2026-10-21)

**Verdict:** All four findings in this batch are verified in code and protected by tests: UX-1608, UX-421, UX-1656, and UX-1657 (the regression found in round 2). None has been seen on a screen yet, so all four are listed as `device-check` until the emulator lane captures them. Nothing was escalated and nothing is still open.

Evidence is code, resource files, widget and unit tests, and one Flutter render (`settings/settings-tab.normal.ca.light.2x`). There are no emulator or physical-device results for this batch. The device captures in `App/build/ux/device/` were taken before these changes.

## Verified in code (ledger: device-check)

| ID | Sev | Title | Round, package | Verify note |
|---|---|---|---|---|
| UX-1608 | S2 | Launcher icon is a tiny «M» in a white disc | R1, P195 | verify-b7-r1-D |
| UX-421 | S1 | Catalan tab label «Configuració» overflows | R1, P196 | verify-b7-r1-D |
| UX-1656 | S2 | English launcher shortcuts cut at large text («Say a ta…») | R1 partly fixed; R2, P222 fixed | verify-b7-r1-D, verify-b7-r2-D |
| UX-1657 | S1 | English widget and voice shortcut use different names (regression R2D-1 from P222) | R3, P223 | verify-b7-r3-D |

What each fix does:
- **UX-1608: launcher and notification icon.**
  - The launcher icon is now an adaptive icon: a teal (#146C5C) background with the white double tick from the in-app mark in front. It also has a monochrome layer for themed icons. The tick sits inside the 21–87 dp safe zone and inside the 72 dp circle of the Android 12 splash screen.
  - The older PNG launcher icons now show the teal mark too, not Flutter's logo.
  - The notification icon is the same white tick, 24 dp. `notification_service.dart:57`, `:84` and `:202` all use it, including as the default.
  - `app_icon.png` and the nested `drawable-*dpi` folders are deleted.
- **UX-421: tab labels.**
  - `main_shell.dart:23-63` measures the four tab labels and shrinks their text to the largest size that fits, never below normal size. The existing size caps stay, and tooltips are untouched.
  - The render at 360 dp and 2× text shows «Configuració» whole on one line.
  - This is the stopgap the owner approved in D9 until U13's two tabs.
- **UX-1656: English launcher shortcuts.**
  - The English shortcuts now read "Dictate a new task" and "Type a new task". At large text the launcher should fall back to the short labels "Dictate" and "Type", as it already does in Spanish and Catalan.
  - The widget now has its own label string, `capture_widget_label`, in English, Spanish and Catalan. The widget's text, its TalkBack name, its Android 13+ label and its name in the widget picker all use it.
  - Spanish and Catalan are unchanged.
- **UX-1657: one name for the voice entries in English.**
  - The English widget now reads "Dictate a task", and its picker line reads "Tap to dictate a task."
  - The Settings › Other help text (`homeCaptureInstructions`) now says "…the Dictate a task widget…".
  - The voice shortcut, its short label and the widget all start with "Dictate", which matches the app's own wording. Spanish and Catalan are untouched.

## Verified findings protected by tests
- **UX-1608:** `App/test/native_resources_test.dart:546`, `:599`, `:649`, `:675`, `:739`
- **UX-421:** `App/test/main_shell_test.dart:335` (Catalan, one line, at 360 and 393 dp, 1.3× and 2.0× text) and `:361` (320×640, 2.0× text, drawn at 12.36 px). The UX-427 and UX-432 tests still pass.
- **UX-1656:** `App/test/native_resources_test.dart:787`, `:817`, `:872`, `:889`, `:918`; `App/test/capture_sheet_test.dart:706`
- **UX-1657:** `App/test/native_resources_test.dart:980`, `:1002`, `:1025`, `:1063`, `:1098`; `App/test/settings_screen_test.dart:145` (English help sheet at 2× text on 320 dp)

## Still open
None.

## Escalations
None.

## Checks for the emulator lane or the owner's phone
- **UX-1608, launcher icon.**
  - Light and dark mode, at Android text 1.0 and 2.0: a teal square with a white tick, and no white disc.
  - Themed icons on Android 13+.
  - The status-bar icon and the notification shade.
  - The Android 12 splash screen.
  - The older icon on API 24–25.
- **UX-421, Catalan tab bar.**
  - Android text 2.0, at 393 and 360 dp: «Configuració» on one line, not «Configuraci / ó».
  - The fit has no margin: about 89 of 90 dp at 360 dp and 2×. If the device wraps it, the next step is to measure against the tab width minus a few dp.
- **UX-1656, English launcher shortcuts.**
  - At Android text 2.0: «Dictate» and «Type».
  - At 1.0: «Dictate a new task» and «Type a new task», whole.
- **UX-1657, English widget.**
  - «Dictate a task» whole at Android text 1.0 and 2.0, on two lines at most.
  - TalkBack name and widget-picker entry: «Dictate a task» / «Tap to dictate a task.»
  - Android 13+ per-app English on a Spanish phone, including a widget that was already on the home screen.
  - The Spanish and Catalan widgets unchanged at 2.0.

## Noted, outside this batch (no ledger line added)
- **iOS wording.** iOS `Info.plist:8` and `en.lproj/InfoPlist.strings:1` still say "so you can say a task". The app is Android-only (decisions of 2026-10-18), so nothing was changed.
- **Widget named by its icon.** The English row title `homeCapture` ("Mic button on your home screen") and the Spanish help text («…el widget de micrófono…», `app_es.arb:228`) describe the widget by its icon, not by its label. Spanish was kept as it is on purpose.
- **UX-910's open question** about the voice wording is untouched, because the fixes keep a voice wording.

## Files changed
- **Launcher and notification icon (P195):**
  - `App/android/app/src/main/AndroidManifest.xml`
  - `App/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
  - `App/android/app/src/main/res/drawable/ic_launcher_foreground.xml`
  - `App/android/app/src/main/res/drawable/ic_launcher_monochrome.xml`
  - `App/android/app/src/main/res/values/ic_launcher_background.xml`
  - `App/android/app/src/main/res/drawable/app_notifications_icon.xml`
  - `App/android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`
  - Deleted: `res/drawable/app_icon.png`, `res/drawable/app_notifications_icon.png`, and `res/drawable/drawable-{m,h,xh,xxh,xxxh}dpi/app_notifications_icon.png` (the folders are gone)
  - `App/lib/services/notification_service.dart`
- **Tab labels (P196):** `App/lib/screens/main_shell.dart`
- **Shortcut and widget wording (P221, P222, P223):**
  - `App/android/app/src/main/res/values/strings.xml`, `values-es/strings.xml`, `values-ca/strings.xml`
  - `App/android/app/src/main/res/layout/capture_widget.xml`
  - `App/android/app/src/main/kotlin/com/example/agenda/CaptureWidget.kt`
  - `App/android/app/src/main/AndroidManifest.xml`
  - `App/lib/l10n/app_en.arb`
  - `App/lib/l10n/generated/` (regenerated by `flutter gen-l10n`)
- **Tests:**
  - `App/test/native_resources_test.dart`
  - `App/test/main_shell_test.dart`
  - `App/test/capture_sheet_test.dart`
  - `App/test/settings_screen_test.dart`
- **Ledger:** `.claude/ux-review/ISSUES.md`

## Rounds
- **Round 1** (`plan.json`): P195 done, P196 done, P221 partly done.
  - Tests failed: the English shortcut length test failed on `capture_voice`, which stayed "Say a task".
  - Review: UX-1608 and UX-421 fixed; UX-1656 not yet.
  - Regressions: none.
- **Round 2** (`plan-b7-r2.json`): P222 done.
  - Tests passed.
  - Review: UX-1656 fixed.
  - Regression R2D-1, S1 polish: the English widget still said "Say a task" while the shortcut said "Dictate a new task". It became UX-1657.
- **Round 3** (`plan-b7-r3.json`): P223 done.
  - Tests passed.
  - Review: UX-1657 fixed.
  - Regressions: none.

## Ledger changes
UX-1608, UX-421, UX-1656 and UX-1657 moved from **Open** to **Device check**. Each line now has a dated "verified in code" note naming its round, package, tests and remaining device checks. The Open section is now empty.