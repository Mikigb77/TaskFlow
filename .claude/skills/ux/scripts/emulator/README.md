# The device-capture lane

The UX preview suite (`App/build/ux/`) renders the app's own screens in widget tests, but it can't draw what Android draws around the app: the launcher icon and its shortcuts, the home-screen widget, notifications, permission dialogs, the share chooser, and TalkBack. This lane captures those from a real Android, so the UX reviewers judge them from screenshots instead of from strings and code.

It runs on a **separate test emulator, `TaskFlow_Review`, that holds only test data**. The main session runs it; reviewers only read what it writes.

Evidence level: **emulator**. Not a physical phone, and no real voice.

## Safety rules (owner's request, 2026-10-18)

- **Never your phone or your own emulators.** The lane has its own emulator, `TaskFlow_Review`, on port 5590 (serial `emulator-5590`). `TaskFlow_API_36_1` and any physical phone are never touched.
  - Every adb call goes through one helper, `adb()` in `capture.py`, which always passes `-s emulator-5590`. Nothing runs adb without `-s`.
  - The script checks that `adb -s emulator-5590 emu avd name` answers `TaskFlow_Review` before it touches the device at all, before each section, and before each install, stop, kill, data clear, permission change or density change. If it doesn't, it stops and touches nothing more.
- **What it may change, on `TaskFlow_Review` only:**
  - app permissions: `pm revoke`, `pm grant`, `pm clear-permission-flags`, `appops`;
  - the app itself: `adb install -r -d` (`-d` because a build from another checkout can have a lower version code), stop and restart;
  - system settings: language, theme, text size, screen density, time zone, TalkBack.
  - It also sets these test conveniences:
    - Android's error dialogs hidden, so an "isn't responding" dialog can't block a run;
    - Gboard's stylus handwriting off, since the TalkBack touches look like a stylus to it;
    - TalkBack's own notification permission denied and not asked again;
    - TalkBack's "Mostrar salida de voz" on, so the TalkBack captures show what it says;
    - Android's "Tiempo para actuar" at 15 seconds for one save, so the save message is captured whole (it goes back to the default straight after);
    - Gboard's "Tamaño de fuente del teclado actualizado" banner closed with its own "Aceptar" before a capture at text 2.0.
  - Each time the `journey` section runs, it first clears TaskFlow's data (`pm clear`, then `appops reset`). That's the only way to show a genuine first run: the privacy line, the reminder question and the permission dialogs appear only once. `--keep-data` skips it.
  - It never uninstalls, and never clears data anywhere else.
- **Backend:** only the local Docker stack that's already running, from the main checkout's `Backend/`. The API is http://localhost:8088, which is http://10.0.2.2:8088 from the emulator; Mailpit is http://localhost:8026.
  - Never run `docker compose` from a worktree: its project name would clash with the running stack.
  - Never staging, never production, never a deploy.
- **The test account** is created once through the API, with a generated password, and confirmed with the 6-digit code from Mailpit's API.
  - Its email and password live only in `review.local.json`, which is gitignored. The script never prints them, and never writes them to a tracked file or to `INDEX.md`. The email does show where the app shows it, in Settings > Cuenta, in captures under the gitignored `App/build/`.
  - It never signs in with Google or any real account.
- **Configuration:** the lane never reads `Backend/.env` or `App/config/development.json`. It builds with its own gitignored `review.defines.local.json`, which holds:
  - `API_BASE_URL`;
  - the public development Google client ID from `Backend/docs/GOOGLE_SIGN_IN.md`, so the sign-in screen looks as it does in development builds. Google sign-in is never tapped.

## Setup (once)

1. The Android SDK, with `system-images;android-36.1;google_apis_playstore;x86_64` installed.
   - If `TaskFlow_Review` doesn't exist, the script creates it on the `pixel_4` profile (1080 × 2280 at 440 dpi, about 393 dp wide) with 4 GB of RAM.
   - To create it by hand: `avdmanager create avd -n TaskFlow_Review -k "system-images;android-36.1;google_apis_playstore;x86_64" -d pixel_4`.
2. The Docker stack running (`taskflow-api-1` and the rest).
3. Flutter on `PATH`, unless you pass `--apk`.

The script starts the emulator headless (`-no-window -no-audio -no-boot-anim -no-snapshot -port 5590`, software GPU `swiftshader_indirect`, time zone Europe/Madrid), always from a cold boot, and shuts it down at the end, unless it was already running or you pass `--keep-running`.

## Run

From the repo root, on Windows:

| Command | What it does |
|---|---|
| `python .claude/skills/ux/scripts/emulator/capture.py` | Builds the review APK from the working tree, installs it, captures everything. |
| `… --apk <path>` | Installs that APK instead of building one. |
| `… --no-build` | Installs the last debug APK as it is. |
| `… --only launcher,widget` | Runs only those sections. Captures from other sections stay. |
| `… --skip languages` | Leaves sections out. |
| `… --langs es,ca` | The languages for the `languages` pass. The rest runs in Spanish. |
| `… --keep-data` | Skips clearing TaskFlow's data, so there's no genuine first run. |
| `… --keep-running` | Leaves the emulator running when the script started it. |
| `python .claude/skills/ux/scripts/emulator/capture.py stop` | Shuts `TaskFlow_Review` down. |
| `… status`, `… ui`, `… shot <file>`, `… adb <args>` | Safety-checked helpers: the emulator's state, the screen's uiautomator outline, a screenshot, adb. |

If `flutter build` fails with "Building with plugins requires symlink support", the shell's sandbox can't create the plugin links. Run the command from PowerShell, or build there and pass `--apk`.

## What it captures

Output: `App/build/ux/device/`. The UX preview suite writes the rest of `App/build/ux/`, with its own `INDEX.md` and `AUDIT.md`; this lane writes only inside `device/`, which the suite leaves alone.
- `<surface>.<state>.<lang>.<theme>.<scale>.png`, for example `launcher.shortcuts.es.dark.2.0.png`.
- `a11y/<same name>.xml`: the uiautomator tree for screens. It's roughly what TalkBack reads: labels, roles, states and bounds.
- `INDEX.md`: each file, what it shows, its time, the APK's commit, and "Not captured" with the reasons. `index.json` is the same, for the script.

Spanish states come in light and dark, at text size 1.0 and 2.0. English and Catalan come in light, at 1.0 and 2.0, wherever the text runs long. A few states are also captured at 360 dp wide.

| Section | What it captures |
|---|---|
| `journey` | A new user's first run, in order: sign-in, the empty calendar, the microphone dialog (denied, denied twice, then allowed), listening and its 60-second limit, typing, saving and where the task lands, the reminder question, the notifications dialog (denied, then allowed from Settings), and "Alarmas y recordatorios". |
| `calendar-permission` | The app's explanation, the system dialog, denied, allowed. |
| `launcher` | The icon on the home screen, the long-press menu with both shortcuts, what tapping each shortcut does, and where each is meant to land. |
| `widget` | The app's "add to home screen" request (the launcher's dialog), the widget on the home screen, and a tap with the app warm and cold. |
| `share` | Android's chooser, what TaskFlow shows after a share (on the current build, the task form, prefilled), Back out of it, and the empty and too-long toasts. |
| `notifications` | Three reminders through the local API: the heads-up, the shade in each theme and size, expanded and collapsed, and what Completar, Posponer 10 min and a tap on the reminder do. |
| `screens` | The four tabs and a task's detail screen with a few tasks, with uiautomator trees. |
| `narrow` | 360 dp wide at text 2.0: the calendar, Settings, the capture sheet, the shortcuts menu. |
| `talkback` | TalkBack on, with its spoken-text captions ("Mostrar salida de voz"): where focus starts and what it says for key controls. |
| `languages` | English and Catalan: shortcuts, the widget, sharing, the microphone states and screens. Catalan also gets a reminder in the shade. |

## Not captured, and why

- **Real speech recognition.** The emulator has no voice: listening shows, but recognised words never appear. That stays a physical-phone check.
- **The capture's AI result.** The review account is on the free tier, and the lane neither grants Pro nor spends AI calls. The UX preview suite renders the review screen (`App/build/ux/INDEX.md`).
- **The widget's "with tasks" state.** The widget is a single dictate button with no task content.
- **Android's grid Sharesheet.** `am start -a SEND` opens Android's list chooser. The grid comes from apps that open the Sharesheet themselves, such as WhatsApp or Chrome, and they'd need their own first-run terms.
- **Sign-up and the email-code screen.** The lane signs in with one fixed account. The UX preview suite renders those screens.
- **A reminder in English.** Each reminder costs about 5 minutes of waiting, so the lane shows Spanish and Catalan, whose text runs longest.

Anything else a run misses is listed, with its reason, at the end of `INDEX.md`.

## How long it takes

Measured on 2026-10-19 over three full runs, on the owner's Windows PC with the software-rendered emulator:

| What runs | Minutes |
|---|---|
| Everything (`capture.py`): about 230 captures | 59, 61, and 67 with the owner's own emulator running alongside |
| Starting: the emulator's cold boot, the install and the app's first start (the build runs alongside) | 2–4 |
| `journey` | 8–10 |
| `calendar-permission` | 2–3 |
| `launcher` | 4–5 |
| `widget` | 4–4.5 |
| `share` | 2–3 |
| `notifications`, 5 of them waiting for the reminders | 8–10 |
| `screens` | 2–4 |
| `narrow` | 1–2 |
| `talkback` | 1.5–2 |
| `languages`: English 7–9, Catalan 14–17 with its reminder | 21–25 |

A scoped run costs the start plus its sections: from a stopped emulator, `--only share` took 6 minutes and `--only notifications` 13.

## Gotchas

- **adb and port 5590.** Port 5590 is above adb's default scan range (5555–5585). The emulator registers itself with a running adb server. An adb server the script starts also scans up to 5591 (`ADB_LOCAL_TRANSPORT_MAX_PORT`). If the adb server restarts while the emulator runs, adb loses it: stop the emulator and run again.
- **Right after a cold boot** the software-rendered emulator is very busy. Input sent then made System UI stop responding.
  - The script waits for the launcher and 30 more seconds before touching anything.
  - It then opens the app once and waits for its first screen, up to 4 minutes.
- **The emulator's life.** The script starts the emulator as its own child. If the command running the script is killed (a timeout, a stopped task), the emulator usually goes with it. The next run starts it again.
- **Under heavy load** (the owner's emulator running too, test suites in other sessions), the software-rendered emulator slows down a lot, and it has crashed after about an hour, its log (`_emulator.log`) full of "bad color buffer handle". The run then stops at its next name check, and `INDEX.md` lists what it missed. Run again, or rerun only those sections with `--only`.
- **Other sessions' adb.** An `adb` command without `-s`, such as `adb emu kill`, reaches `TaskFlow_Review` when it's the only device connected. On 2026-10-19 the emulator shut down in the middle of a run without the script asking, while other sessions were running Flutter; the script stopped at its next name check and touched nothing more. If that happens, run it again.
- **Typing.** `adb shell input text` can't type accents, so the phrases the script types avoid them. Texts sent through the API or a share can have accents.
- **TalkBack.**
  - Taps from `input tap` bypass TalkBack's touch exploration and activate controls directly. To move TalkBack's focus the way a finger does, the script touches through the emulator's own touchscreen (`adb emu event mouse`). Gboard takes those touches for a stylus, hence stylus handwriting off.
  - A `uiautomator dump` switches TalkBack off while it reads the screen. So the section reads every position first, and only takes screenshots while TalkBack is on.
- **Stopping the app.** `am force-stop` greys the widget out until the app runs again, so the script always reopens the app straight away. `am kill` stands in for Android closing the app in the background.
- **Reminders and stopping the app.** The app refreshes its reminders under a 2-minute lock. If the app is stopped in the middle of a refresh, every refresh for the next 2 minutes gives up, so new reminders aren't scheduled.
  - The notifications section never stops the app. It schedules reminders about 5 minutes ahead and checks Android's alarm list (`dumpsys alarm`).
  - Until the reminders appear in that list, it opens the app again; the third time, it starts the app afresh, which loads the tasks from the server. If they still aren't there after about 3 minutes, it tries once more with new reminders, after the lock has run out.
  - On 2026-10-19, on a busy machine, the reminders sometimes stayed out of the list for 7 minutes and more, through every resume and a fresh start. The section then stops and `INDEX.md` says so; rerun it with `--only notifications`, which then worked.
- **Heads-up.** It arrives a few seconds after the notification is posted and stays about 5 seconds. The script watches the screen for it.
- **The share chooser remembers.** After a first "Solo una vez", Android offers TaskFlow on top ("Compartir con TaskFlow") instead of in the list. Both are what people see.
- **Gboard's banner at text 2.0.** Each time the system text size grows, Gboard covers the bottom of the app with "Tamaño de fuente del teclado actualizado". Only `uiautomator dump --windows` shows the keyboard's window, so the script dumps every window before a keyboard capture at 2.0 and taps the banner's "Aceptar".
- **Short-lived messages.** The app's messages with an action, such as "Añadida al …" with Deshacer, stay 4 seconds, about as long as finding them on screen takes. The app honours Android's "Tiempo para actuar", so the script stretches it for that one capture.
- **Leaving a capture.** When the app asks whether to keep what was said or typed for later, the script discards it. Its captures are tests, and kept ones would pile up under "Sin guardar" in later screens.
- **Live recognition or a recording.** When the capture sheet opens, the app asks the phone whether it can recognise the language on the device, and waits 4 seconds for the answer. Without one, it records audio for the server instead, and the sheet changes: the main button is active from the start, there's no button to type instead, and a second denial of the microphone shows no way to Settings.
  - Catalan always records here: this emulator has no on-device recognition for Catalan. A phone with it shows the same sheet as Spanish.
  - Spanish can record too, when the busy emulator answers late. The journey waits for a still screen before its first tap on "Añadir tarea" to make that rare.
  - The captures' notes say when a sheet recorded, and the journey then reaches the form another way, which its note names.
- **Labels come from the app.** The script finds controls by the app's own strings, read from the ARB files and `strings.xml` at run time. If a string it uses is renamed or removed, the affected section stops and `INDEX.md` lists it under "Not captured", naming the string, so the script needs a small update.
- **A cold start is slow here.** After `am kill`, the app can take 10 seconds or more to draw its first frame, and the screen stays black until then. The script waits for the screen it expects instead of a fixed time.
- **Getting back to the tabs.** Before each step that needs the app's main screen, the script signs in if asked, discards a capture left open, presses Back over other screens, and opens the app again if a Back left it. If the tabs still don't show within 2 minutes, that section stops, and `_stuck-<section>-<lang>.png` keeps what the screen showed.
- **Generated files.** `flutter pub get` rewrites `App/{linux,macos,windows}` plugin registrants with LF line endings. Git shows them as modified with no content change. Restore them with `git checkout -- App/linux App/macos App/windows`.
