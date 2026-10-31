## UX verify — 2026-10-19-app, batch b7, round 1, area D — 2026-10-21

**Scope:** P195 (UX-1608), P196 (UX-421), P221 (UX-1656). Changed files read with `git diff HEAD`; new resources read in full. Render read: `App/build/ux/settings/settings-tab.normal.ca.light.2x.png` (04:39, newer than `main_shell.dart` 04:24; no app file newer than it). Legacy icon read: `res/mipmap-xxxhdpi/ic_launcher.png`. No device evidence for this batch yet.

### UX-1608 · fixed (code level; launcher, themed icon, shade and splash need the emulator lane)
- `AndroidManifest.xml:15` now `android:icon="@mipmap/ic_launcher"`.
- `res/mipmap-anydpi-v26/ic_launcher.xml`: `<adaptive-icon>` with background `@color/ic_launcher_background` (#146C5C, `values/ic_launcher_background.xml`), foreground and monochrome vectors.
- `drawable/ic_launcher_foreground.xml` / `ic_launcher_monochrome.xml`: 108 × 108 dp, white `done_all_rounded` glyph from Flutter's font at 2×; path bounds about x 31.5–76.7, y 41.8–67.4, centred at (54.1, 54.6): inside the 21–87 dp safe zone, and inside the splash's 72 dp circle (farthest corner ≈ 26.4 dp from centre). The glyph's 48 dp box on the 72 dp visible icon matches the in-app mark's two-thirds proportion.
- Legacy PNG (xxxhdpi read): teal rounded square with the white double tick — the in-app mark, not Flutter's logo.
- `drawable/app_notifications_icon.xml`: white 24 dp vector of the same tick; `notification_service.dart:57`, `:84` and `:202` (the default, was `'app_icon'`) all name it. No file names `app_icon`; `app_icon.png` and the nested `drawable-*dpi` folders are gone.
- ux-tester: 5 tests pass; the debug APK links.
- Device-only, left open: home icon light/dark at 1.0/2.0 (no white disc), themed icons on 13+, status bar and shade, Android 12 splash, API 24–25 legacy.

### UX-421 · fixed (Flutter level; emulator re-capture pending)
- `main_shell.dart:23-63` `_fittingLabelScale` measures the four labels in both bar styles (bodyMedium merged, as the bar draws them) against `(width − horizontal padding) / 4`, and steps the label scale down to the largest that fits, never below 1.0×; caps kept (1.3× Flutter, 1.2× below 360 dp, `:126-128`). Only the label's font size changes (`:133-138`); tooltips untouched. Comment names U13 (`:93-100`).
- Render `settings-tab.normal.ca.light.2x` (360 dp): «Calendari · Tasques · Notes · Configuració», all on one line, «Configuració» whole (was «Configurac / ió»).
- AUDIT `settings/settings-tab · normal`: the only cut text is the ES email row (pre-existing); none in the tab bar.
- ux-tester: CA one-line at 360/393 × 1.3/2.0; 320×640 2.0× drawn at 12.36 px (79.6 of 80 dp); UX-427 (14.4 / 12.0 / 15.6 px) and UX-432 (28 px tooltip) unchanged and passing.
- Observation, not a regression: the fit has no margin. At 360 dp/2× the bold «Configuració» takes ≈ 89 of 90 dp and ends about 1 dp from the screen's right edge. The emulator re-capture (393 and 360 dp, CA, 2.0) should confirm that the device's shaping doesn't wrap it («Configuraci / ó»). If it does, measure against the tab width minus a few dp.

### UX-1656 · partly fixed
- `values/strings.xml:7` `capture_text` "Type a new task" (15 characters, natural): the text shortcut should now fall back to "Type" at 2.0 as ES/CA do (emulator to confirm).
- `values/strings.xml:3` `capture_voice` still "Say a task" (10 characters): at Android's 2.0 the voice shortcut is still cut «Say a ta…». The length test fails on this half.
- Side effect while half done: at 1.0 the English pair reads "Say a task" / "Type a new task", two wordings for one idea. Option A clears it.
- The implementer's conflict is real: `capture_voice` is also the widget's label and TalkBack name (`layout/capture_widget.xml:6`, `:10`), its 13+ label (`CaptureWidget.kt:25`) and its picker name (`AndroidManifest.xml:58`). `homeCaptureInstructions` (`app_en.arb:404`) names the widget "Say a task".
- Recommendation: option A. Add `capture_widget_label` in values/values-es/values-ca with today's text ("Say a task" / «Dictar una tarea» / «Dicta una tasca») and a translator comment. Point the layout's text and contentDescription, `CaptureWidget.kt:25` and the receiver's label at it. Then set `capture_voice` to "Dictate a new task", which matches "Type a new task" and the short label "Dictate". The widget, its picker entry and the Settings line then read exactly as today. Update test 'UX-121: the shortcuts read …'.
- The brief's scope needs widening for this. It isn't a product decision.

### Regressions
None in the changed files and the flows they touch (launcher, status bar, notifications' default icon, the tab bar in every locale, the launcher shortcuts).
