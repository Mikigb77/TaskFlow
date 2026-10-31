# Run 2026-10-19-app: batch b7 and the final capture on the review emulator (2026-10-21)

**Evidence level: emulator.** TaskFlow_Review: Android 16, Pixel 4 profile at about 393 dp, Pixel Launcher. There's no real voice, and it isn't a physical phone.

**What was captured:**
- **The final set:** every section from 3a35a0d, the finished code of run 2026-10-19-app. That's 238 captures in 54 minutes, with nothing missing.
- **The English pass again,** from c4b9209, the English voice shortcut's fix.
- **By hand, with the lane's safety-checked helpers:** the launch splash, and the Catalan tab bar at 360 dp.
- **The backend:** the local Docker API at cf39f6e.
- **Where:** everything is in `App/build/ux/device/`.

## Confirmed on the emulator
| Finding | What the capture shows | Capture |
|---|---|---|
| UX-1608 (D8, P195) | The launcher icon is the in-app mark: a teal icon with the white double tick, on the home screen, in the dock and in the shortcuts menu. There's no white disc and no «M». The notifications carry the same tick. Android's launch splash shows the teal circle with the tick. | `launcher.shortcuts.es.light.1.0`, `notification.shade.es.light.1.0`, `launch.splash-150ms.es.light.1.0` |
| UX-421 (D9, P196) | «Configuració» stays whole on one line in the tab bar at Android's 2.0. That holds at 360 dp, regular weight, and at 393 dp, bold and selected. The fit is tight. | `screen-settings.tabbar-360dp.ca.light.2.0`, `screen-settings.list.ca.light.2.0` |
| UX-1656 (P221, P222) | At 2.0 the English shortcuts fall back to «Dictate» and «Type», whole. | `launcher.shortcuts.en.light.2.0` (c4b9209) |
| UX-1658 (main session) | At 1.0 the English shortcuts read «Dictate a task» and «Type a new task», whole. | `launcher.shortcuts.en.light.1.0` (c4b9209) |
| UX-1657 (P223), in part | The English widget reads «Dictate a task» on one line at 2.0. | `widget.home.en.light.2.0` |

## Found on the way, and fixed: UX-1658
- **What the final capture showed:** P222's «Dictate a new task» (18 characters) was cut at 1.0, to «Dictate a new ta…».
- **Why:** the Pixel Launcher keeps a long label it thinks fits, but it doesn't count the pin button beside it.
- **What the emulator showed works:** an English long label of 13–16 characters. It's whole at 1.0 and falls back to the short label at 2.0, as «Type a new task» (15) does.
- **The fix:** the voice label is now «Dictate a task» (14), the widget's own name (c4b9209). The test's rule now checks this window.

## Still for a phone
- **UX-1608:** Android 13's themed icons. The review emulator didn't take the launcher's themed-icon switch from adb, so there's no themed capture. Also the icon on Android 7 (API 24–25).
- **UX-1657:** the widget's TalkBack name and widget-picker entry, and English as the app's own language on a Spanish phone, including a widget already on the home screen.

## Noticed, for the next review
- At 360 dp and 2.0, Calendar's «2 esdeveniments…» line sits partly under «Sense desar · 4» until the list is scrolled (`screen-settings.tabbar-360dp.ca.light.2.0`).
- The review emulator's storage was 92% full (Play Store app updates), so an install failed. Clearing TaskFlow's data, which the journey does on every run anyway, made room. A future lane run may want `pm trim-caches` first.
