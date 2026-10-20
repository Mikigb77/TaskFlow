#!/usr/bin/env python3
"""TaskFlow's device-capture lane for the UX reviewers.

Captures what a Flutter widget test can't draw (the launcher, its shortcuts,
the home-screen widget, notifications, permission dialogs, the share sheet,
the capture flow on a real Android, TalkBack) from the separate
TaskFlow_Review emulator, which holds only test data.

    python .claude/ux-review/emulator/capture.py            # build, install, capture all
    python .claude/ux-review/emulator/capture.py --apk X.apk --only launcher,widget
    python .claude/ux-review/emulator/capture.py stop        # shut the emulator down

Output: App/build/ux/device/ (PNGs, a11y/*.xml, INDEX.md, index.json).
How it works and the safety rules: README.md next to this file.

Safety, enforced in code:
- every adb call goes through adb(), which always passes -s emulator-5590;
- verify() checks `emu avd name` == TaskFlow_Review before anything touches
  the device, before each section, and before each install, stop, kill,
  data clear, permission change or density change, and aborts otherwise;
- the review account's password never reaches the output or any log.
Stdlib only.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import secrets
import shutil
import socket
import string
import struct
import subprocess
import sys
import time
import traceback
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
import zlib
from pathlib import Path

AVD = "TaskFlow_Review"
PORT = 5590
SERIAL = f"emulator-{PORT}"
SYSTEM_IMAGE = "system-images;android-36.1;google_apis_playstore;x86_64"
DEVICE_PROFILE = "pixel_4"  # 1080 x 2280 at 440 dpi: about 393 dp wide
TIMEZONE = "Europe/Madrid"

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
APP = REPO / "App"


def android_ids() -> tuple[str, str, dict[str, str]]:
    """The debug build's package, MainActivity's package and the shortcuts'
    actions, read from the project so a package rename (App/docs/PACKAGE_ID.md)
    needs no change here."""
    android = APP / "android" / "app"
    package, namespace, actions = "com.example.agenda", "com.example.agenda", {}
    try:
        gradle = (android / "build.gradle").read_text(encoding="utf-8")
        found = re.search(r'applicationId\s*=?\s*"([^"]+)"', gradle)
        package = found.group(1) if found else package
        found = re.search(r'namespace\s*=?\s*"([^"]+)"', gradle)
        namespace = found.group(1) if found else package
        # The shortcuts are published from code (CaptureShortcuts.kt) with the actions
        # CaptureEntryBridge.kt declares.
        bridge = next((android / "src" / "main" / "kotlin").rglob("CaptureEntryBridge.kt")).read_text(encoding="utf-8")
        found = dict(re.findall(r'const val (VOICE|TEXT) = "([^"]+)"', bridge))
        actions = {key: found[name] for key, name in (("capture_voice", "VOICE"), ("capture_text", "TEXT")) if name in found}
    except (OSError, StopIteration):
        pass
    actions.setdefault("capture_voice", f"{namespace}.CAPTURE_VOICE")
    actions.setdefault("capture_text", f"{namespace}.CAPTURE_TEXT")
    return package, namespace, actions


PACKAGE, NAMESPACE, SHORTCUT_ACTIONS = android_ids()
ACTIVITY = f"{PACKAGE}/{NAMESPACE}.MainActivity"
OUT = APP / "build" / "ux" / "device"
A11Y = OUT / "a11y"
LOCAL = HERE / "review.local.json"
DEFINES = HERE / "review.defines.local.json"
APK_DEFAULT = APP / "build" / "app" / "outputs" / "flutter-apk" / "app-debug.apk"

API = "http://localhost:8088/api"
MAILPIT = "http://localhost:8026/api/v1"

LANG_TAGS = {"es": "es-ES", "en": "en-US", "ca": "ca-ES"}
FULL = [("light", "1.0"), ("dark", "1.0"), ("light", "2.0"), ("dark", "2.0")]
LIGHT = [("light", "1.0"), ("light", "2.0")]
SECTIONS = ["journey", "calendar-permission", "launcher", "widget", "share",
            "notifications", "screens", "narrow", "talkback", "languages"]

GBOARD = "com.google.android.inputmethod.latin"
# The app bar's back arrow, as Flutter names it in each language.
BACK_ARROW = r"^(Atrás|Back|Enrere)$"
TALKBACK_SETTINGS = ("com.google.android.marvin.talkback/"
                     "com.android.talkback.TalkBackPreferencesActivity")


class SafetyError(RuntimeError):
    """The emulator on our port isn't TaskFlow_Review: nothing may touch it."""


class Skip(RuntimeError):
    """A state that can't be reached on this run; recorded under Not captured."""


def log(message: str) -> None:
    stamp = dt.datetime.now().strftime("%H:%M:%S")
    print(f"[{stamp}] {message}", flush=True)


# --- adb: the only way this lane talks to a device ----------------------------

def sdk_root() -> Path:
    for name in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        value = os.environ.get(name)
        if value and Path(value).is_dir():
            return Path(value)
    return Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "Android" / "Sdk"


EXE = ".exe" if os.name == "nt" else ""
SDK = sdk_root()
ADB = SDK / "platform-tools" / f"adb{EXE}"
EMULATOR = SDK / "emulator" / f"emulator{EXE}"
AVDMANAGER = SDK / "cmdline-tools" / "latest" / "bin" / ("avdmanager.bat" if os.name == "nt" else "avdmanager")
# Emulator ports above 5585 are outside adb's default scan range. The emulator
# registers itself with a running adb server; an adb server this lane starts
# also scans up to our port. Nothing else changes for other devices.
ADB_ENV = {**os.environ, "ADB_LOCAL_TRANSPORT_MAX_PORT": str(PORT + 1)}


def adb(*args: str, check: bool = True, timeout: float = 60, binary: bool = False):
    """Runs adb on the review emulator: always `-s emulator-5590`."""
    command = [str(ADB), "-s", SERIAL, *args]
    result = subprocess.run(command, capture_output=True, timeout=timeout, env=ADB_ENV)
    if check and result.returncode != 0:
        raise RuntimeError(f"adb {' '.join(args[:3])} failed: "
                           f"{result.stderr.decode(errors='replace').strip()[:300]}")
    if binary:
        return result.stdout
    return result.stdout.decode("utf-8", errors="replace")


def sh(command: str, check: bool = False, timeout: float = 60) -> str:
    """One shell command on the review emulator."""
    return adb("shell", command, check=check, timeout=timeout)


def avd_name() -> str:
    try:
        answer = adb("emu", "avd", "name", check=False, timeout=15)
    except subprocess.TimeoutExpired:
        return ""
    return answer.strip().splitlines()[0].strip() if answer.strip() else ""


def verify() -> None:
    """Aborts unless emulator-5590 is the TaskFlow_Review test emulator."""
    name = avd_name()
    if not name:
        raise SafetyError(f"{SERIAL} isn't answering: {AVD} stopped, or adb lost it. "
                          "Nothing more was touched.")
    if name != AVD:
        raise SafetyError(f"{SERIAL} answers as {name}, not {AVD}. Nothing was touched.")


def online() -> bool:
    try:
        return adb("get-state", check=False, timeout=10).strip() == "device"
    except subprocess.TimeoutExpired:
        return False


def port_in_use(port: int) -> bool:
    with socket.socket() as probe:
        probe.settimeout(1)
        return probe.connect_ex(("127.0.0.1", port)) == 0


# --- The emulator --------------------------------------------------------------

def avd_exists() -> bool:
    found = subprocess.run([str(EMULATOR), "-list-avds"], capture_output=True, text=True)
    return AVD in found.stdout.split()


def create_avd() -> None:
    log(f"creating the {AVD} emulator ({DEVICE_PROFILE}, {SYSTEM_IMAGE})")
    subprocess.run([str(AVDMANAGER), "create", "avd", "-n", AVD, "-k", SYSTEM_IMAGE,
                    "-d", DEVICE_PROFILE], input="no\n", text=True, capture_output=True,
                   check=True)
    config = Path.home() / ".android" / "avd" / f"{AVD}.avd" / "config.ini"
    if config.exists():
        text = re.sub(r"(?m)^hw\.ramSize=.*$", "hw.ramSize=4096", config.read_text())
        config.write_text(text)


def launch_emulator() -> bool:
    """Starts TaskFlow_Review, or reuses it. Returns True if this run started
    it; wait_for_boot() then waits until it's usable."""
    if online():
        verify()
        log(f"reusing {AVD} on {SERIAL}")
        return False
    if port_in_use(PORT):
        raise SafetyError(f"Port {PORT} is busy but adb can't see {SERIAL}. If it's the review "
                          "emulator, the adb server lost it (its port is outside adb's scan range): "
                          f"close it, or restart adb with ADB_LOCAL_TRANSPORT_MAX_PORT={PORT + 1}.")
    if not avd_exists():
        create_avd()
    log(f"starting {AVD} headless on port {PORT}")
    adb("start-server", check=False)
    OUT.mkdir(parents=True, exist_ok=True)
    flags = 0
    if os.name == "nt":
        flags = subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS
    with open(OUT / "_emulator.log", "w") as out:
        subprocess.Popen([str(EMULATOR), "-avd", AVD, "-port", str(PORT), "-no-window",
                          "-no-audio", "-no-boot-anim", "-no-snapshot",
                          "-gpu", "swiftshader_indirect", "-timezone", TIMEZONE],
                         stdout=out, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                         creationflags=flags, env=ADB_ENV)
    return True


def wait_for_boot(started: bool) -> None:
    if not started:
        return
    deadline = time.time() + 240
    while not online():
        if time.time() > deadline:
            raise RuntimeError("The review emulator didn't come online in 4 minutes "
                               f"(see {OUT / '_emulator.log'}).")
        time.sleep(3)
    verify()
    deadline = time.time() + 420
    while sh("getprop sys.boot_completed").strip() != "1":
        if time.time() > deadline:
            raise RuntimeError("The review emulator didn't finish booting in 7 minutes.")
        time.sleep(3)
    log("  booted")
    # A software-rendered emulator is very busy for a while after a cold boot,
    # and input sent then makes System UI stop responding. Hide Android's error
    # dialogs on this test emulator, wait for the launcher, then let it settle.
    sh("settings put global hide_error_dialogs 1")
    deadline = time.time() + 180
    while "launcher" not in top_activity().lower() and time.time() < deadline:
        time.sleep(3)
    time.sleep(30)


def stop_emulator() -> None:
    if not online():
        return
    verify()
    log(f"shutting {AVD} down")
    adb("emu", "kill", check=False)
    deadline = time.time() + 60
    while online() and time.time() < deadline:
        time.sleep(2)


# --- Screen reading and touch --------------------------------------------------

BOUNDS = re.compile(r"\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]")


def ui_xml(attempts: int = 4) -> str:
    """The screen as uiautomator sees it: roughly what TalkBack reads."""
    for _ in range(attempts):
        out = sh("uiautomator dump /sdcard/taskflow_ui.xml", timeout=45)
        if "dumped" in out.lower():
            xml = adb("exec-out", "cat", "/sdcard/taskflow_ui.xml", check=False)
            if xml.strip().startswith("<?xml"):
                return xml
        time.sleep(1.2)
    raise RuntimeError("uiautomator couldn't read the screen (it never went idle)")


def ui() -> ET.Element:
    return ET.fromstring(ui_xml())


def words(node: ET.Element) -> str:
    return " | ".join(v for v in (node.get("text"), node.get("content-desc")) if v)


def find(root: ET.Element, pattern: str, *, clickable: bool | None = None,
         attrs: tuple[str, ...] = ("text", "content-desc")):
    rx = re.compile(pattern, re.I | re.S)
    for node in root.iter("node"):
        if clickable is not None and (node.get("clickable") == "true") != clickable:
            continue
        if any(rx.search(node.get(attr) or "") for attr in attrs):
            return node
    return None


def find_id(root: ET.Element, suffix: str):
    return find(root, re.escape(suffix) + "$", attrs=("resource-id",))


def box(node: ET.Element) -> tuple[int, int, int, int]:
    return tuple(map(int, BOUNDS.match(node.get("bounds")).groups()))  # type: ignore


def center(node: ET.Element) -> tuple[int, int]:
    x1, y1, x2, y2 = box(node)
    return (x1 + x2) // 2, (y1 + y2) // 2


def tap(x: int, y: int, wait: float = 1.2) -> None:
    sh(f"input tap {x} {y}", check=True)
    time.sleep(wait)


def long_press(x: int, y: int, wait: float = 1.2) -> None:
    sh(f"input swipe {x} {y} {x} {y} 1100", check=True)
    time.sleep(wait)


def key(name: str, wait: float = 0.8) -> None:
    sh(f"input keyevent {name}", check=True)
    time.sleep(wait)


def wait_for(pattern: str, timeout: float = 20, **kw):
    deadline = time.time() + timeout
    while True:
        try:
            node = find(ui(), pattern, **kw)
        except RuntimeError:
            node = None
        if node is not None or time.time() > deadline:
            return node
        time.sleep(0.8)


def wait_for_id(suffix: str, timeout: float = 20):
    return wait_for(re.escape(suffix) + "$", timeout, attrs=("resource-id",))


def tap_on(pattern: str, timeout: float = 20, wait: float = 1.5, **kw) -> bool:
    node = wait_for(pattern, timeout, **kw)
    if node is None:
        return False
    tap(*center(node), wait=wait)
    return True


def must_tap(pattern: str, what: str, timeout: float = 20, wait: float = 1.5, **kw) -> None:
    if not tap_on(pattern, timeout, wait, **kw):
        raise Skip(f"couldn't find {what} on screen")


def tap_id(*suffixes: str, wait: float = 1.5) -> None:
    """Taps the first of these resource ids on screen (system dialogs' buttons)."""
    root = ui()
    for suffix in suffixes:
        node = find_id(root, suffix)
        if node is not None:
            tap(*center(node), wait=wait)
            return
    raise Skip(f"couldn't find {' or '.join(suffixes)} on screen")


def type_text(value: str) -> None:
    """Types ASCII into the focused field, as the keyboard does, a few
    characters at a time: on a busy emulator a long burst drops or doubles
    keys. `input text` can't type accents, so typed phrases avoid them."""
    for start in range(0, len(value), 6):
        chunk = value[start:start + 6]
        escaped = chunk.replace("\\", "\\\\").replace("'", "'\\''").replace(" ", "%s")
        sh(f"input text '{escaped}'", check=True)
        time.sleep(0.25)
    time.sleep(0.6)


def fill_field(index: int, value: str, secret: bool = False) -> None:
    """Puts [value] in the screen's [index]th text field, and checks it took
    (a busy emulator can drop or double keys). A secret field can't be read
    back, so only its length is checked when the field shows one."""
    for _ in range(3):
        fields = [n for n in ui().iter("node") if n.get("class") == "android.widget.EditText"]
        if len(fields) <= index:
            raise Skip(f"no text field number {index + 1} on screen")
        tap(*center(fields[index]), wait=0.8)
        sh("input keyevent KEYCODE_MOVE_END")
        sh("input keyevent " + " ".join(["KEYCODE_DEL"] * (len(value) + 20)))
        type_text(value)
        fields = [n for n in ui().iter("node") if n.get("class") == "android.widget.EditText"]
        shown = fields[index].get("text") or "" if len(fields) > index else ""
        if shown == value or (secret and (not shown or len(shown) == len(value))):
            return
        log("  a typed field came out wrong; typing it again")
    raise Skip("couldn't type into a text field reliably")


def dismiss_anr() -> bool:
    """Taps 'Wait' on an "isn't responding" dialog, if one is showing."""
    try:
        node = find_id(ui(), "aerr_wait")
    except RuntimeError:
        return False
    if node is None:
        return False
    log("  Android said something isn't responding: tapping Wait")
    tap(*center(node), wait=3)
    return True


def keyboard_notice_off() -> None:
    """Closes Gboard's 'Tamaño de fuente del teclado actualizado' banner, which
    covers the app after the text size grows. It's the keyboard's, not
    TaskFlow's. Only a dump of every window shows the keyboard."""
    time.sleep(1)  # it appears a moment after the keyboard redraws
    out = sh("uiautomator dump --windows /sdcard/taskflow_windows.xml", timeout=45)
    if "dumped" not in out.lower():
        return
    try:
        root = ET.fromstring(adb("exec-out", "cat", "/sdcard/taskflow_windows.xml", check=False))
    except ET.ParseError:
        return
    # Its 'Aceptar' is the keyboard's only button with a text label.
    for node in root.iter("node"):
        if (node.get("package") == GBOARD and node.get("class") == "android.widget.Button"
                and node.get("text")):
            tap(*center(node), wait=1)
            return


def top_activity() -> str:
    out = sh("dumpsys activity activities | grep -m1 topResumedActivity")
    match = re.search(r"u0 (\S+)", out)
    return match.group(1) if match else ""


def outline(root: ET.Element) -> str:
    lines = []
    for node in root.iter("node"):
        text = words(node)
        flags = "".join(flag for flag, attr in (("C", "clickable"), ("F", "focused"),
                                                 ("L", "long-clickable"), ("S", "scrollable"))
                        if node.get(attr) == "true")
        if text or flags:
            rid = (node.get("resource-id") or "").split("/")[-1]
            lines.append(f"{node.get('bounds')} {flags:4} {node.get('class', '').split('.')[-1]:14} "
                         f"{rid[:24]:24} {text[:110]!r}")
    return "\n".join(lines)


def console_touch(x: int, y: int) -> None:
    """A touch through the emulator's own touchscreen, which TalkBack's touch
    exploration sees like a finger; `input tap` bypasses it."""
    adb("emu", "event", "mouse", str(x), str(y), "0", "1", check=False)
    adb("emu", "event", "mouse", str(x), str(y), "0", "0", check=False)


# --- Frames --------------------------------------------------------------------

def raw_frame() -> tuple[int, int, bytes]:
    data = adb("exec-out", "screencap", binary=True, timeout=30)
    width, height = struct.unpack("<II", data[:8])
    header = 16 if len(data) >= 16 + width * height * 4 else 12
    return width, height, data[header:header + width * height * 4]


def _first_diff(a: bytes, b: bytes) -> int:
    lo, hi = 0, len(a)
    while hi - lo > 64:
        mid = (lo + hi) // 2
        if a[lo:mid] != b[lo:mid]:
            hi = mid
        else:
            lo = mid
    for i in range(lo, hi):
        if a[i] != b[i]:
            return i
    return hi


def frame_diff(one, two) -> tuple[int, int, int, int, int]:
    """Rows that differ, and the box (x1, y1, x2, y2) around the change."""
    w, h, a = one
    w2, h2, b = two
    if (w, h) != (w2, h2):
        return h, 0, 0, w, h
    stride = w * 4
    rows, x1, y1, x2, y2 = 0, w, h, -1, -1
    for y in range(h):
        ra, rb = a[y * stride:(y + 1) * stride], b[y * stride:(y + 1) * stride]
        if ra != rb:
            rows += 1
            left = _first_diff(ra, rb) // 4
            right = w - 1 - _first_diff(ra[::-1], rb[::-1]) // 4
            x1, x2 = min(x1, left), max(x2, right)
            y1, y2 = min(y1, y), max(y2, y)
    return rows, x1, y1, x2, y2


def settle(timeout: float = 6.0) -> bool:
    """Waits until the screen stops changing, ignoring a blinking caret and the
    status-bar clock."""
    time.sleep(0.5)
    previous = raw_frame()
    deadline = time.time() + timeout
    while time.time() < deadline:
        time.sleep(0.25)
        current = raw_frame()
        rows, x1, y1, x2, y2 = frame_diff(previous, current)
        if rows == 0 or (x2 - x1) <= 40 or y2 < 75:
            return True
        previous = current
    return False


def png_from_raw(frame) -> bytes:
    width, height, pixels = frame
    stride = width * 4
    rows = b"".join(b"\x00" + pixels[y * stride:(y + 1) * stride] for y in range(height))

    def chunk(kind: bytes, body: bytes) -> bytes:
        return (struct.pack(">I", len(body)) + kind + body
                + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF))

    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows, 6)) + chunk(b"IEND", b""))


# --- Device settings -----------------------------------------------------------

class Device:
    def __init__(self) -> None:
        self.theme = None
        self.scale = None

    def prepare(self) -> None:
        verify()
        # An ANR dialog would block every capture; this emulator hides them.
        sh("settings put global hide_error_dialogs 1")
        dismiss_anr()
        key("KEYCODE_WAKEUP", 0.3)
        sh("wm dismiss-keyguard")
        sh("svc power stayon true")
        sh("settings put system screen_off_timeout 1800000")
        # The console touches TalkBack needs look like a stylus to Gboard, which
        # then covers text fields with its handwriting tutorial.
        sh("settings put secure stylus_handwriting_enabled 0")
        sh(f"cmd time_zone_detector set_time_zone_state_for_tests --zone_id {TIMEZONE} "
           "--user_should_confirm_id false")
        sh("wm density reset")
        self.message_time(None)
        self.talkback(False)
        self.locale("es")
        self.apply("light", "1.0", force=True)

    def apply(self, theme: str, scale: str, force: bool = False) -> None:
        changed = False
        if force or theme != self.theme:
            sh(f"cmd uimode night {'yes' if theme == 'dark' else 'no'}")
            self.theme, changed = theme, True
        if force or scale != self.scale:
            sh(f"settings put system font_scale {scale}")
            self.scale, changed = scale, True
        if changed:
            time.sleep(1.6)

    def locale(self, lang: str) -> None:
        tag = LANG_TAGS[lang]
        if sh("cmd locale get-device-locale").strip() != tag:
            sh(f"cmd locale set-device-locale {tag}", check=True)
            time.sleep(3)

    def talkback(self, on: bool) -> None:
        if on:
            sh("settings put secure enabled_accessibility_services "
               "com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService")
            sh("settings put secure accessibility_enabled 1")
        else:
            sh("settings delete secure enabled_accessibility_services")
            sh("settings put secure accessibility_enabled 0")
        time.sleep(2)

    def message_time(self, seconds: int | None) -> None:
        """Android's 'Tiempo para actuar'. The app keeps its messages with an
        action (Deshacer) on screen at least this long; None is the default."""
        if seconds is None:
            sh("settings delete secure accessibility_interactive_ui_timeout_ms")
        else:
            sh(f"settings put secure accessibility_interactive_ui_timeout_ms {seconds * 1000}")

    def restore(self) -> None:
        try:
            verify()
            self.talkback(False)
            self.message_time(None)
            sh("wm density reset")
            sh("cmd statusbar collapse")
            self.locale("es")
            self.apply("light", "1.0", force=True)
        except Exception as error:  # noqa: BLE001 - best effort on the way out
            log(f"  couldn't restore every setting: {error}")


# --- Copy: the app's own strings, so labels follow the ARB files ---------------

class Strings:
    def __init__(self, lang: str) -> None:
        self.lang = lang
        self.arb = json.loads((APP / "lib" / "l10n" / f"app_{lang}.arb").read_text(encoding="utf-8"))
        folder = "values" if lang == "en" else f"values-{lang}"
        xml = (APP / "android" / "app" / "src" / "main" / "res" / folder / "strings.xml").read_text(encoding="utf-8")
        self.native = {name: value.replace("\\'", "'") for name, value in
                       re.findall(r'<string name="([^"]+)">([^<]*)</string>', xml)}

    def __getitem__(self, name: str) -> str:
        try:
            return self.arb[name]
        except KeyError:
            raise Skip(f"the app has no '{name}' string any more; capture.py needs "
                       "updating") from None

    def rx(self, *names: str) -> str:
        """Matches a node whose label starts with one of these strings."""
        return "^(?:" + "|".join(re.escape(self[n]) for n in names) + r")(?:$|\n|,)"

    def nrx(self, name: str) -> str:
        return "^" + re.escape(self.native[name]) + "$"


PHRASES = {
    # Typed with `input text`, so no accents.
    "es": {"typed": "Llamar a Marta", "share": "Comprar pan y leche el viernes",
           "tasks": ["Llamar al dentista", "Recoger el coche", "Pagar la luz"],
           "decor": ["Reunión con Laura", "Comprar fruta", "Revisar el presupuesto"]},
    "en": {"typed": "Call Marta", "share": "Buy bread and milk on Friday",
           "tasks": ["Call the dentist", "Pick up the car", "Pay the electricity bill"],
           "decor": ["Meeting with Laura", "Buy fruit", "Review the budget"]},
    "ca": {"typed": "Trucar a la Marta", "share": "Comprar pa i llet divendres",
           "tasks": ["Trucar al dentista", "Recollir el cotxe", "Pagar la llum"],
           "decor": ["Reunió amb la Laura", "Comprar fruita", "Revisar el pressupost"]},
}


# --- The local backend and the review account ----------------------------------

class ApiError(RuntimeError):
    def __init__(self, status: int, body: object):
        super().__init__(f"HTTP {status}")
        self.status = status
        self.body = body


def http(method: str, url: str, data: object = None, token: str | None = None,
         timeout: float = 20) -> object:
    body = None if data is None else json.dumps(data).encode()
    request = urllib.request.Request(url, data=body, method=method)
    request.add_header("Accept", "application/json")
    if body is not None:
        request.add_header("Content-Type", "application/json")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read()
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            parsed = json.loads(raw or b"null")
        except ValueError:
            parsed = raw[:200].decode(errors="replace")
        raise ApiError(error.code, parsed) from None
    return json.loads(raw) if raw else None


def new_password() -> str:
    alphabet = string.ascii_letters + string.digits
    while True:
        value = "".join(secrets.choice(alphabet) for _ in range(24))
        if (any(c.islower() for c in value) and any(c.isupper() for c in value)
                and any(c.isdigit() for c in value)):
            return value


def read_account() -> dict | None:
    try:
        data = json.loads(LOCAL.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    return data if data.get("email") and data.get("password") else None


def mailpit_code(email: str, since: float, timeout: float = 90) -> str:
    """The newest 6-digit code Mailpit holds for [email]: its subject carries it."""
    query = urllib.parse.urlencode({"query": f'to:"{email}"'})
    deadline = time.time() + timeout
    while time.time() < deadline:
        found = http("GET", f"{MAILPIT}/search?{query}") or {}
        for message in found.get("messages") or []:
            try:
                stamp = dt.datetime.fromisoformat(message.get("Created", "").replace("Z", "+00:00")).timestamp()
            except ValueError:
                stamp = since
            match = re.search(r"\b(\d{6})\b", message.get("Subject", ""))
            if match and stamp >= since - 5:
                return match.group(1)
        time.sleep(2)
    raise RuntimeError("No verification code reached Mailpit for the review account.")


def login(account: dict) -> dict:
    return http("POST", f"{API}/auth/login/", {
        "email": account["email"], "password": account["password"], "timezone": TIMEZONE})


def ensure_account() -> tuple[dict, dict]:
    """The review account and a fresh session: created once, then reused.

    It lives only on the local Docker backend. Its password is generated here,
    kept in review.local.json (gitignored) and never printed."""
    account = read_account()
    if account:
        try:
            return account, login(account)
        except ApiError as error:
            if error.status not in (401, 403):
                raise
            log(f"  the saved review account can't sign in (HTTP {error.status}); creating a new one")
    email = f"ux-review-{secrets.token_hex(3)}@taskflow-review.test"
    account = {"email": email, "password": new_password()}
    started = time.time()
    created = http("POST", f"{API}/auth/register/", {
        "email": email, "password": account["password"], "timezone": TIMEZONE, "language": "es"})
    if isinstance(created, dict) and created.get("verification_required"):
        code = mailpit_code(email, started)
        session = http("POST", f"{API}/auth/verify-email/", {
            "email": email, "code": code, "password": account["password"]})
    else:
        session = created
    account.update({
        "created": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
        "backend": API.removesuffix("/api"),
        "note": "TaskFlow_Review emulator only. Local Docker backend. Never commit or print.",
    })
    LOCAL.write_text(json.dumps(account, indent=2) + "\n", encoding="utf-8")
    log("  created the review account (saved in review.local.json)")
    return account, session


class Backend:
    def __init__(self, account: dict) -> None:
        self.account = account

    def token(self) -> str:
        return login(self.account)["access"]

    def tasks(self) -> list[dict]:
        found = http("GET", f"{API}/tasks/", token=self.token())
        return found.get("results", []) if isinstance(found, dict) else found

    def clear(self) -> int:
        """Deletes every task of the review account (the API soft-deletes)."""
        token = self.token()
        items = http("GET", f"{API}/tasks/", token=token)
        items = items.get("results", []) if isinstance(items, dict) else items
        for task in items:
            http("DELETE", f"{API}/tasks/{task['id']}/", {"version": task["version"]}, token=token)
        return len(items)

    def create(self, title: str, **fields) -> dict:
        return http("POST", f"{API}/tasks/", {"title": title, **fields}, token=self.token())

    def delete(self, task_id: str) -> None:
        token = self.token()
        try:
            task = http("GET", f"{API}/tasks/{task_id}/", token=token)
            http("DELETE", f"{API}/tasks/{task_id}/", {"version": task["version"]}, token=token)
        except ApiError:
            pass  # already gone


# --- Build and install ---------------------------------------------------------

def git(*args: str) -> str:
    result = subprocess.run(["git", "-C", str(REPO), *args], capture_output=True, text=True)
    return result.stdout.strip()


def google_client_id() -> str | None:
    """The public development client ID (Backend/docs/GOOGLE_SIGN_IN.md), so the
    sign-in screen looks as it does in development builds. Never tapped."""
    doc = REPO / "Backend" / "docs" / "GOOGLE_SIGN_IN.md"
    try:
        match = re.search(r"Web audience client: .*?ID `([^`]+)`", doc.read_text(encoding="utf-8"))
    except OSError:
        return None
    return match.group(1) if match else None


def write_defines() -> None:
    defines = {"API_BASE_URL": "http://10.0.2.2:8088"}
    client = google_client_id()
    if client:
        defines["GOOGLE_SERVER_CLIENT_ID"] = client
    DEFINES.write_text(json.dumps(defines, indent=2) + "\n", encoding="utf-8")


def build_apk() -> Path:
    write_defines()
    flutter = shutil.which("flutter")
    if not flutter:
        raise RuntimeError("flutter isn't on PATH; pass --apk with a built debug APK instead.")
    # The plugin registrant is part of pub get's output too: a pub get that failed half way
    # (no symlink support) leaves package_config.json but no registrant, and the APK then
    # starts with no plugins at all, so sign-in fails with a generic error.
    registrant = APP / "android" / "app" / "src" / "main" / "java" / "io" / "flutter" / "plugins" / \
        "GeneratedPluginRegistrant.java"
    if not (APP / ".dart_tool" / "package_config.json").exists() or not registrant.exists():
        log("running flutter pub get (first build in this checkout)")
        subprocess.run([flutter, "pub", "get"], cwd=APP, check=True)
    log("building the review APK (debug, android-x64)")
    started = time.time()
    result = subprocess.run([flutter, "build", "apk", "--debug", "--no-pub",
                             "--target-platform", "android-x64",
                             f"--dart-define-from-file={DEFINES}"],
                            cwd=APP, capture_output=True, text=True, errors="replace")
    if result.returncode != 0:
        tail = "\n".join((result.stdout + result.stderr).strip().splitlines()[-12:])
        hint = ("\nThe sandboxed shell can't create the plugin junctions: run the build from "
                "PowerShell, or pass --apk." if "symlink" in tail.lower() else "")
        raise RuntimeError(f"flutter build failed:\n{tail}{hint}")
    log(f"  built in {time.time() - started:.0f} s")
    return APK_DEFAULT


def apk_facts(apk: Path, source: str) -> dict:
    """What the captures were made from. [source]: built, given or reused."""
    digest = hashlib.sha256(apk.read_bytes()).hexdigest()[:12]
    head = git("rev-parse", "--short", "HEAD")
    dirty = bool(git("status", "--porcelain", "--", "App"))
    built = dt.datetime.fromtimestamp(apk.stat().st_mtime).astimezone()
    changes = " + uncommitted changes in App/" if dirty else ""
    if source == "built":
        commit = f"{head}{changes}"
    else:
        how = "given with --apk" if source == "given" else "the last build, reused with --no-build"
        commit = f"not recorded ({how}); the checkout is at {head}{changes}"
    short = f"{'' if source == 'built' else '?'}{head}{'*' if dirty else ''}"
    return {"apk": str(apk), "sha256": digest, "built": built.isoformat(timespec="seconds"),
            "commit": commit, "short": short}


def install(apk: Path) -> None:
    verify()
    log("installing the APK (adb install -r -d)")
    # -d: a build from another checkout or worktree can carry a lower version code (the
    # pubspec's build number), which Android refuses as a downgrade. It's allowed for debug
    # builds, and the data stays, as with -r.
    out = adb("install", "-r", "-d", str(apk), timeout=300)
    if "Success" not in out:
        raise RuntimeError(f"install failed: {out.strip()[-300:]}")


# --- The capture lane ----------------------------------------------------------

class Lane:
    def __init__(self, args, device: Device, backend: Backend, account: dict, facts: dict) -> None:
        self.args = args
        self.device = device
        self.backend = backend
        self.account = account
        self.facts = facts
        self.lang = "es"
        self.L = Strings("es")
        self.entries: list[dict] = []
        self.missing: list[dict] = []
        self.section = ""
        self.top = ""  # the top-level section running, as named in SECTIONS

    # Capturing ---------------------------------------------------------------

    def name(self, surface: str, state: str) -> str:
        return f"{surface}.{state}.{self.lang}.{self.device.theme}.{self.device.scale}"

    def snap(self, surface: str, state: str, shows: str, *, dump: bool = True,
             quick: bool = False, frame=None) -> str:
        base = self.name(surface, state)
        OUT.mkdir(parents=True, exist_ok=True)
        if frame is not None:
            png = png_from_raw(frame)
        else:
            if not quick:
                settle()
            png = adb("exec-out", "screencap", "-p", binary=True, timeout=30)
        (OUT / f"{base}.png").write_bytes(png)
        a11y = None
        if dump:
            try:
                A11Y.mkdir(parents=True, exist_ok=True)
                (A11Y / f"{base}.xml").write_text(ui_xml(attempts=2), encoding="utf-8")
                a11y = f"a11y/{base}.xml"
            except RuntimeError:
                a11y = "(not readable: the screen never went idle)"
        self.entries.append({
            "file": f"{base}.png", "surface": surface, "state": state, "lang": self.lang,
            "theme": self.device.theme, "scale": self.device.scale, "shows": shows,
            "a11y": a11y, "time": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
            "commit": self.facts["short"],
        })
        log(f"  captured {base}.png")
        return base

    def variants(self, surface: str, state: str, shows: str, *, combos=None,
                 prepare=None, dump: bool = True, quick: bool = False) -> None:
        """Captures one state in each theme and text size: es gets light and dark
        at 1.0 and 2.0; English and Catalan get light at both sizes. [quick]
        skips the wait for a still screen, for states with a running clock."""
        combos = combos or (FULL if self.lang == "es" else LIGHT)
        for index, (theme, scale) in enumerate(combos):
            self.device.apply(theme, scale)
            if prepare:
                prepare()
            if quick:
                time.sleep(0.4)
            self.snap(surface, state, shows, dump=dump and index == 0, quick=quick)
        self.device.apply("light", "1.0")

    def miss(self, what: str, why: str) -> None:
        self.missing.append({"what": what, "lang": self.lang, "why": why, "section": self.top,
                             "time": dt.datetime.now().astimezone().isoformat(timespec="seconds")})
        log(f"  not captured: {what} ({why})")

    def run_section(self, name: str, function) -> None:
        self.section = name
        # English and Catalan run only inside the languages pass.
        self.top = name if self.lang == "es" else "languages"
        log(f"section {name} ({self.lang})")
        verify()
        try:
            function()
        except SafetyError:
            raise
        except Skip as reason:
            self.miss(f"{name}: the rest of the section", str(reason))
        except Exception as error:  # noqa: BLE001 - one failed section never stops the run
            self.miss(f"{name}: the rest of the section", f"{type(error).__name__}: {error}")
            traceback.print_exc()
        finally:
            self.recover()

    def recover(self) -> None:
        try:
            sh("cmd statusbar collapse")
            self.device.apply("light", "1.0")
            sh("wm density reset")
        except Exception:  # noqa: BLE001
            pass

    # App control -----------------------------------------------------------

    def warm_up(self) -> None:
        """Right after a boot or an install, a debug build can take minutes to
        draw its first screen on a busy emulator. Open it once and wait."""
        verify()
        sh(f"am start -n {ACTIVITY}", check=True)
        deadline = time.time() + 240
        while time.time() < deadline:
            try:
                root = ui()
            except RuntimeError:
                time.sleep(2)
                continue
            # Any labelled node of the app's: the calendar, sign-in, or a
            # capture sheet the app reopened by itself.
            if any(n.get("package") == PACKAGE and words(n) for n in root.iter("node")):
                log("  the app is up")
                return
            if find_id(root, "aerr_wait") is not None:
                dismiss_anr()
            time.sleep(2)
        log("  the app took more than 4 minutes to show its first screen")

    def restart_app(self) -> None:
        """A fresh start on the calendar: stop the app and open it again."""
        verify()
        sh(f"am force-stop {PACKAGE}")
        self.open_app()

    def open_app(self) -> None:
        sh(f"am start -n {ACTIVITY}", check=True)
        self.ensure_signed_in()

    def ensure_signed_in(self, timeout: float = 120) -> None:
        """Gets the app to its tabs: signs in, and closes whatever a share, a
        shortcut or an earlier section left open on top."""
        deadline = time.time() + timeout
        backs = reopened = 0
        while time.time() < deadline:
            try:
                root = ui()
            except RuntimeError:
                time.sleep(1)
                continue
            if find(root, self.L.rx("calendar", "tasks", "settings")) is not None:
                return
            if reopened < 3 and not any(n.get("package") == PACKAGE for n in root.iter("node")):
                # The app isn't on screen (a Back can leave it): open it again.
                sh(f"am start -n {ACTIVITY}")
                reopened += 1
                time.sleep(3)
                continue
            discard = find(root, self.L.rx("discard"))
            if discard is not None:
                # "Keep it for later?" after leaving a capture: the lane's are tests.
                tap(*center(discard), wait=1.5)
                continue
            if find(root, self.L.rx("cancel")) is not None:
                # A capture sheet opened by itself (a pending share or shortcut).
                self.cancel_capture()
                continue
            fields = [n for n in root.iter("node") if n.get("class") == "android.widget.EditText"]
            if len(fields) >= 2 and find(root, self.L.rx("signIn")) is not None:
                self.sign_in()
                continue
            if find_id(root, "aerr_wait") is not None:
                dismiss_anr()
                continue
            arrow = find(root, BACK_ARROW, attrs=("content-desc",))
            if backs < 4 and arrow is not None and arrow.get("package") == PACKAGE:
                # Another of the app's screens on top, with its back arrow, such
                # as the form a share opened. A screen still loading has none,
                # and Back there would close the app: wait for it instead.
                key("KEYCODE_BACK", 1.5)
                backs += 1
                continue
            time.sleep(1.2)
        # Keep what the screen showed, for whoever looks into it.
        stuck = f"_stuck-{self.section or 'start'}-{self.lang}.png"
        try:
            (OUT / stuck).write_bytes(adb("exec-out", "screencap", "-p", binary=True, timeout=30))
        except (RuntimeError, OSError, subprocess.TimeoutExpired):
            stuck = "none"
        raise Skip(f"the app didn't reach its main screen in {timeout:.0f} s (the screen then: "
                   f"{stuck})")

    def sign_in(self) -> None:
        fill_field(0, self.account["email"])
        fill_field(1, self.account["password"], secret=True)
        key("KEYCODE_ENTER", 4)

    def tab(self, name: str) -> None:
        must_tap(self.L.rx(name), f"the {self.L[name]} tab", wait=1.5)

    def open_other_settings(self) -> None:
        self.tab("settings")
        must_tap(self.L.rx("otherSettings"), "Other settings")

    def grant(self, permission: str) -> None:
        verify()
        sh(f"pm grant {PACKAGE} android.permission.{permission}")

    def reset_permission(self, permission: str) -> None:
        verify()
        sh(f"pm revoke {PACKAGE} android.permission.{permission}")
        sh(f"pm clear-permission-flags {PACKAGE} android.permission.{permission} user-set user-fixed")

    def dialog(self, timeout: float = 12):
        return wait_for_id("permission_message", timeout)

    def cancel_capture(self) -> None:
        """Leaves the capture sheet. When it asks whether to keep what was said
        or typed, the lane discards it: its captures are only tests."""
        if not tap_on(self.L.rx("cancel"), timeout=4):
            key("KEYCODE_BACK")
        tap_on(self.L.rx("discard"), timeout=1, wait=1)

    def keyboard_clear(self) -> None:
        """Before a capture with the keyboard open: Gboard covers the app with a
        banner of its own when the text size grows."""
        if self.device.scale != "1.0":
            keyboard_notice_off()

    # Sections ----------------------------------------------------------------

    def journey(self) -> None:
        """A new user's first run, in the order they meet things: sign-in, the
        empty calendar, the microphone, listening, typing, the result, the
        reminder question, notifications and exact alarms."""
        L = self.L
        if not self.args.keep_data:
            verify()
            log("  clearing TaskFlow's data on TaskFlow_Review for a genuine first run")
            sh(f"pm clear {PACKAGE}", check=True)
            sh(f"appops reset {PACKAGE}")
        removed = self.backend.clear()
        log(f"  cleared {removed} task(s) from the review account")
        sh(f"am start -n {ACTIVITY}", check=True)
        if wait_for(L.rx("signIn"), timeout=150) is None:
            raise Skip("the sign-in screen didn't appear (already signed in? use without --keep-data)")
        self.variants("first-run", "sign-in", "The first screen after installing: sign-in. Debug build: "
                      "the 'Ajustes de conexión' link at the bottom is debug-only and absent in release.")
        fill_field(0, self.account["email"])
        self.snap("first-run", "sign-in-typing", "Typing the email: the keyboard covers the lower half.",
                  dump=False)
        fill_field(1, self.account["password"], secret=True)
        key("KEYCODE_ENTER", 3)
        if wait_for(L.rx("addTask"), timeout=40) is None:
            raise Skip("sign-in didn't land on the calendar")
        self.variants("first-run", "calendar-empty", "Where sign-in lands: the calendar's first-run "
                      "empty state, with its single primary button.")

        # The microphone, from the first tap on Añadir tarea. The sheet asks the
        # phone whether it can recognise speech itself and waits 4 s for the
        # answer; a quiet moment first keeps the busy emulator from missing it.
        settle(timeout=8)
        time.sleep(4)
        must_tap(L.rx("addTask"), "Añadir tarea", wait=0.5)
        if self.dialog() is None:
            raise Skip("the microphone dialog didn't appear")
        self.variants("permission-mic", "dialog", "The system microphone dialog, straight after the "
                      "first tap on Añadir tarea, with the capture sheet behind it.")
        tap_id("permission_deny_button", wait=2)
        self.variants("permission-mic", "denied", "After 'No permitir': the capture sheet's banner.")
        must_tap(L.rx("captureStartTalking"), "Empezar a hablar", wait=0.5)
        if self.dialog() is not None:
            self.snap("permission-mic", "dialog-again", "Asking again: Android's second dialog; "
                      "this 'No permitir' also stops Android asking.", dump=False)
            tap_id("permission_deny_and_dont_ask_again_button", "permission_deny_button", wait=2)
            settings = find(ui(), L.rx("captureOpenSettings")) is not None
            self.variants("permission-mic", "blocked", "Denied twice: Android won't ask again" + (
                ", so the sheet points to Settings." if settings else ". The sheet still shows "
                "the first denial's banner, with no way to Settings."))
            if tap_on(L.rx("captureOpenSettings"), timeout=5, wait=2.5):
                self.snap("permission-mic", "open-settings-landing", "Where 'Abrir Ajustes' lands: "
                          "Android's App info page, not the microphone switch.", dump=False)
                key("KEYCODE_BACK", 1.5)
            else:
                self.miss("permission-mic: open-settings-landing", "the sheet had no "
                          f"'{L['captureOpenSettings']}' after the second denial")
        else:
            self.miss("permission-mic: second dialog and blocked state", "no second dialog appeared")

        # Allow, then listen. The emulator has no voice: this is what a person sees.
        self.reset_permission("RECORD_AUDIO")
        # While blocked, the sheet offers only «Abrir Ajustes» (UX-1303), and it can't tell that
        # the permission was reset from outside: close it, and the next Añadir tarea asks again.
        if find(ui(), L.rx("captureStartTalking")) is None:
            self.cancel_capture()
            must_tap(L.rx("addTask"), "Añadir tarea", wait=0.5)
        else:
            must_tap(L.rx("captureStartTalking"), "Empezar a hablar", wait=0.5)
        if self.dialog() is None:
            raise Skip("the microphone dialog didn't come back after resetting the permission")
        tap_id("permission_allow_foreground_only_button", wait=0.3)
        started = time.time()
        if wait_for(re.escape(L["captureListening"]), timeout=10) is None:
            raise Skip("listening didn't start")
        first = len(self.entries)
        self.variants("capture", "listening", "Listening, right after allowing the microphone "
                      "(emulator: no voice, so no words appear). First use shows the privacy line; "
                      "a hint joins it after a few seconds of silence.", dump=False, quick=True)
        # Live recognition shows the typing button while listening; the
        # recording the app falls back to doesn't.
        live = find(ui(), L.rx("captureTypeInstead")) is not None
        mode = "" if live else (
            " This run the phone's speech check didn't answer in time on the busy emulator, so "
            "the app recorded audio for the server instead: its other layout, with the main "
            f"button active and no '{L['captureTypeInstead']}'.")
        for entry in self.entries[first:]:
            entry["shows"] += mode
        self.wait_until(started + 14)
        self.snap("capture", "listening-hint", "About 14 s of silence: the hint under the clock."
                  + mode, quick=True, dump=False)
        self.wait_until(started + 51)
        self.snap("capture", "listening-countdown", "About 51 s: the warning before the "
                  "listening limit." + mode, quick=True, dump=False)
        self.wait_until(started + 57)
        self.snap("capture", "listening-countdown-late", "About 57 s: does the warning count "
                  "down?" + mode, quick=True, dump=False)
        self.wait_until(started + 68)
        self.variants("capture", "listening-ended", "After the listening limit with nothing heard: "
                      "what the sheet says." + mode)

        # Typing instead, and the result. The recording layout has no typing
        # button: a new capture usually listens live, else the text shortcut's
        # intent opens the form.
        route = f"'{L['captureTypeInstead']}'"
        if not tap_on(L.rx("captureTypeInstead"), timeout=5, wait=2):
            self.cancel_capture()
            route = f"a second {L['addTask']}, then '{L['captureTypeInstead']}'"
            if not (tap_on(L.rx("addTask"), timeout=8, wait=3)
                    and tap_on(L.rx("captureTypeInstead"), timeout=8, wait=2)):
                self.cancel_capture()
                route = "the text shortcut's intent (the sheet had no typing button)"
                sh(f"am start -a {SHORTCUT_ACTIONS['capture_text']} -n {ACTIVITY}", check=True)
        if wait_for(L.rx("newTask"), timeout=15) is None:
            raise Skip("couldn't reach the task form")
        self.variants("capture", "typing", f"The task form, keyboard open, reached with {route}.",
                      prepare=self.keyboard_clear)
        fill_field(0, PHRASES[self.lang]["typed"])
        must_tap(L.rx("tomorrow"), "Mañana", wait=1.2)
        self.snap("capture", "typing-filled", "Title typed and Mañana picked: the button now says "
                  "where it goes.")
        # The save message stays 4 s, about as long as finding it on screen takes.
        # The app honours Android's 'Tiempo para actuar', so a longer one keeps the
        # message whole for the capture; the setting goes back at once.
        self.device.message_time(15)
        try:
            must_tap(L.rx("captureAddToCalendar"), "Añadir al calendario", wait=0.3)
            self.snap("capture", "saving", "Straight after tapping 'Añadir al calendario': the "
                      "form as it closes, keyboard going down.", quick=True, dump=False)
            if wait_for(L.rx("undo"), timeout=15) is None:
                self.miss("capture: result", "no save message with Deshacer after saving")
            else:
                self.snap("capture", "result", "Where the task went: the calendar on its day, with "
                          "the save message and Deshacer. On a phone the message stays 4 s.")
        finally:
            self.device.message_time(None)

        # The reminder question, then notifications. It waits for the save
        # message to go, which this time stays 15 s.
        if wait_for(re.escape(L["reminderAskQuestion"]), timeout=30) is None:
            raise Skip("the reminder question didn't appear after the first dated task")
        self.variants("reminder-ask", "sheet", "Asked once, after the first dated task's save "
                      "message has gone.")
        must_tap(L.rx("reminderAskYes"), "Sí, recuérdamelo", wait=0.5)
        if self.dialog() is None:
            raise Skip("the notifications dialog didn't appear")
        self.variants("permission-notifications", "dialog", "The system notifications dialog, after "
                      "'Sí, recuérdamelo'.")
        tap_id("permission_deny_button", wait=0.3)
        self.snap("permission-notifications", "denied", "Right after 'No permitir': the app's "
                  "message with its action.", quick=True, dump=False)
        time.sleep(3.5)
        self.snap("permission-notifications", "denied-after-4s", "The same screen 4 s later: is "
                  "the message and its action still there?", quick=True, dump=True)

        # A second chance from Settings, allowing this time.
        self.reset_permission("POST_NOTIFICATIONS")
        self.tab("settings")
        must_tap(L.rx("reminders"), "Recordatorios")
        self.variants("permission-notifications", "settings-off", "Settings > Recordatorios with the "
                      "permission off.")
        must_tap(L.rx("enableReminders"), "Activar recordatorios", wait=0.5)
        if self.dialog() is None:
            raise Skip("the notifications dialog didn't appear from Settings")
        tap_id("permission_allow_button", wait=1.5)
        if wait_for(re.escape(L["exactAlarmsNeeded"]), timeout=10) is not None:
            self.variants("permission-alarms", "app-sheet", "The app's own explanation before "
                          "Android's 'Alarmas y recordatorios' page.")
            must_tap(L.rx("allowPreciseAlarms"), "Permitir Alarmas y recordatorios", wait=2.5)
            self.variants("permission-alarms", "system-page", "Android's 'Alarmas y recordatorios' "
                          "page for TaskFlow, before switching it on.")
            # The switch row sits below the page's title bar.
            rows = [n for n in ui().iter("node")
                    if re.search("alarm", words(n), re.I) and box(n)[1] > 400]
            if not rows:
                raise Skip("couldn't find the alarms switch")
            tap(*center(rows[0]), wait=1)
            key("KEYCODE_BACK", 0.6)
            self.snap("permission-alarms", "allowed", "Back in the app 0.6 s after allowing: "
                      "what shows while the page re-checks. The settled page is "
                      "permission-notifications.settings-on.", quick=True, dump=False)
        else:
            self.miss("permission-alarms", "the exact-alarms sheet didn't appear (already allowed?)")
        self.variants("permission-notifications", "settings-on", "Settings > Recordatorios with "
                      "everything allowed.")

    def calendar_permission(self) -> None:
        L = self.L
        self.reset_permission("READ_CALENDAR")
        self.restart_app()
        self.open_other_settings()
        must_tap(L.rx("deviceCalendars"), "Calendarios del teléfono")
        self.variants("permission-calendar", "explanation", "The app's explanation before asking: "
                      "Settings > Otros ajustes > Calendarios del teléfono.")
        must_tap(L.rx("calendarEnable"), "Conectar calendarios del teléfono", wait=0.5)
        if self.dialog() is None:
            raise Skip("the calendar dialog didn't appear")
        self.variants("permission-calendar", "dialog", "The system calendar dialog.")
        tap_id("permission_deny_button", wait=2)
        self.variants("permission-calendar", "denied", "After 'No permitir'.")
        must_tap(L.rx("calendarEnable"), "Conectar calendarios del teléfono", wait=0.5)
        if self.dialog() is None:
            raise Skip("the calendar dialog didn't come back")
        tap_id("permission_allow_button", wait=2.5)
        self.variants("permission-calendar", "allowed", "After 'Permitir' (the emulator has no "
                      "calendar accounts).")

    # The launcher ------------------------------------------------------------

    def home_page_one(self) -> None:
        key("KEYCODE_HOME", 0.8)
        key("KEYCODE_HOME", 1.2)

    def home_icon(self):
        self.home_page_one()
        root = ui()
        for node in root.iter("node"):
            if (node.get("text") == "TaskFlow" and node.get("long-clickable") == "true"
                    and "nexuslauncher" in (node.get("package") or "")):
                return node
        return None

    def ensure_home_icon(self):
        icon = self.home_icon()
        if icon is not None:
            return icon
        log("  placing the TaskFlow icon on the home screen")
        key("KEYCODE_ALL_APPS", 1.5)
        key("KEYCODE_BACK", 1)  # the drawer opens with its search keyboard
        drawn = wait_for("^TaskFlow$", timeout=8, attrs=("text",))
        if drawn is None:
            raise Skip("TaskFlow isn't in the app drawer")
        long_press(*center(drawn))
        if not tap_on(r"pantalla de inicio|home screen|pantalla d.inici", timeout=5):
            raise Skip("the launcher didn't offer 'Add to home screen'")
        return self.home_icon()

    def shortcuts_popup(self) -> None:
        icon = self.ensure_home_icon()
        if icon is None:
            raise Skip("no TaskFlow icon on the home screen")
        long_press(*center(icon))
        wait_for(self.L.nrx("capture_voice"), timeout=5)

    def launcher(self) -> None:
        L = self.L
        self.grant("RECORD_AUDIO")
        self.restart_app()
        self.ensure_home_icon()
        self.variants("launcher", "home-icon", "The home screen with TaskFlow's icon and label "
                      "(Pixel Launcher, API 36).", prepare=self.home_page_one)
        self.variants("launcher", "shortcuts", "Long-press on the icon: Android's menu and "
                      "TaskFlow's two shortcuts.", prepare=self.shortcuts_popup)
        # Each shortcut's record lists its intent about 11 lines down.
        registered = sh(f"dumpsys shortcut | grep -A16 'ShortcutInfo {{id=capture_' "
                        f"| grep -o 'cmp=[^ ]*' | sort -u")
        for kind, name in (("voice", "capture_voice"), ("text", "capture_text")):
            action = SHORTCUT_ACTIONS[name]
            self.shortcuts_popup()
            sh("logcat -c")
            node = wait_for(L.nrx(name), timeout=5)
            if node is None:
                self.miss(f"shortcut-{kind}: after tap", "the shortcut isn't in the menu")
                continue
            tap(*center(node), wait=2)
            again = find(ui(), L.nrx(name))
            if again is not None and "nexuslauncher" in (again.get("package") or ""):
                tap(*center(again), wait=2.5)  # the first tap after a long-press can be swallowed
            failed = "Shortcut could not be started" in sh("logcat -d -t 400")
            landed = top_activity()
            components = ", ".join(sorted(set(registered.split())))
            where = (f" Android registered the shortcut for {components}." if components else "")
            self.snap(f"shortcut-{kind}", "after-tap", (
                f"Tapping '{L.native[name]}' in the menu. " + (
                    "Nothing opens: the launcher logged 'ActivityNotFoundException: Shortcut "
                    f"could not be started'.{where}" if failed else f"Top activity: {landed}.")),
                dump=False)
            key("KEYCODE_BACK", 0.6)
            # Where the shortcut is meant to land, sent the way the app expects it.
            self.restart_app()
            sh(f"am start -a {action} -n {ACTIVITY}", check=True)
            time.sleep(3)
            self.snap(f"shortcut-{kind}", "intended-landing", (
                f"Where '{L.native[name]}' is meant to land, opened with am start "
                f"(action {action.rsplit('.', 1)[-1]}) because the launcher shortcut didn't open."
                if failed else f"Where '{L.native[name]}' lands, opened with am start."))
            if kind == "voice":
                self.cancel_capture()
            else:
                key("KEYCODE_BACK", 1)
        # The launcher's own flags while the app is open (NEW_TASK | CLEAR_TASK).
        self.restart_app()
        sh(f"am start -a {SHORTCUT_ACTIONS['capture_text']} -n {ACTIVITY} -f 0x1000c000", check=True)
        time.sleep(7)
        self.snap("shortcut-text", "intended-landing-launcher-flags", "The same intent with the "
                  "flags Android gives shortcut launches (NEW_TASK | CLEAR_TASK), sent while the "
                  "app is open: does the form open?")

    # The home-screen widget --------------------------------------------------

    def widget_node(self):
        for attempt in range(3):
            node = find_id(ui(), "capture_widget_button")
            if node is not None:
                return node
            sh("input swipe 900 1100 150 1100 300")
            time.sleep(1.2)
        return None

    def go_to_widget(self):
        self.home_page_one()
        node = self.widget_node()
        if node is None:
            self.home_page_one()
        return node

    def widget_or(self, fallback):
        """The widget, freshly found on the home screen, else where it was."""
        node = self.go_to_widget()
        return node if node is not None else fallback

    def pin_request(self) -> None:
        self.restart_app()
        self.open_other_settings()
        must_tap(self.L.rx("homeCapture"), "Botón de dictar en la pantalla de inicio", wait=2)
        if wait_for_id("widget_cell", timeout=8) is None:
            raise Skip("the launcher's add-widget dialog didn't appear")

    def widget(self, tasks_note: str) -> None:
        self.grant("RECORD_AUDIO")
        exists = self.go_to_widget() is not None
        self.pin_request()
        self.variants("widget", "pin-dialog", "The app's 'add to home screen' request: the "
                      "launcher's dialog with the widget's preview.", prepare=self.pin_dialog_again)
        self.pin_dialog_again()
        if exists:
            must_tap(r"^(Cancelar|Cancel|Cancel·la)$", "Cancel", timeout=5, wait=2)
            after = "after cancelling (the widget was already on the home screen)"
        else:
            must_tap(r"pantalla de inicio|home screen|pantalla d.inici", "Add", timeout=5, wait=2.5)
            after = "after adding it"
        self.snap("widget", "after-pin-request", f"Back in TaskFlow {after}: what the app says.")
        time.sleep(2)  # the launcher redraws the widget once the app runs again
        node = self.go_to_widget()
        if node is None:
            raise Skip("the widget isn't on the home screen")
        self.variants("widget", "home", f"The widget on the home screen. {tasks_note}",
                      prepare=self.go_to_widget)
        tap(*center(self.widget_or(node)), wait=4)
        self.snap("widget", "tap-landing", "Tapping the widget with the app open in the background.",
                  quick=True)
        self.cancel_capture()
        self.go_to_widget()
        verify()
        sh(f"am kill {PACKAGE}")
        time.sleep(1)
        # A cold start on this software-rendered emulator can take 10 s or more
        # before the app draws anything, and the calendar can show before the
        # sheet does, so wait for the sheet itself.
        tapped = time.time()
        tap(*center(self.widget_or(node)), wait=2)
        listening = wait_for(re.escape(self.L["captureListening"]), timeout=45)
        took = time.time() - tapped
        if listening is not None:
            time.sleep(1)  # the sheet slides up
            self.snap("widget", "tap-landing-cold", "Tapping the widget when Android had closed "
                      f"the app (cold start): listening. The emulator took about {took:.0f} s "
                      "to get there; a phone is faster.", quick=True)
        else:
            self.snap("widget", "tap-landing-cold", "Tapping the widget when Android had closed "
                      "the app (cold start): no listening sheet 45 s after the tap. This is "
                      "what showed.", quick=True)
        self.cancel_capture()

    def pin_dialog_again(self) -> None:
        if wait_for_id("widget_cell", timeout=2) is None:
            self.pin_request()

    # Sharing -----------------------------------------------------------------

    def share_intent(self, text: str, direct: bool = False) -> None:
        quoted = text.replace("'", "'\\''")
        target = f"-n {ACTIVITY} " if direct else ""
        sh(f"am start -a android.intent.action.SEND -t text/plain {target}"
           f"--es android.intent.extra.TEXT '{quoted}'", check=True)

    def chooser(self) -> None:
        sh(f"am start -a android.intent.action.MAIN -c android.intent.category.HOME")
        time.sleep(1)
        self.share_intent(PHRASES[self.lang]["share"])
        if wait_for_id("button_once", timeout=8) is None:
            raise Skip("no chooser appeared for the share")

    def share(self, full: bool = True) -> None:
        L = self.L
        self.restart_app()
        if full:
            self.chooser()
            self.variants("share", "chooser", "Sharing text from another app (am start SEND): "
                          "Android's list chooser. After a first 'Solo una vez' it offers TaskFlow "
                          "on top. Apps that open the system Sharesheet show a grid instead.",
                          prepare=self.chooser_again)
            self.chooser_again()
            # The first time, TaskFlow is in the list; after a "Just once", Android
            # offers it on top ("Compartir con TaskFlow") with the two buttons.
            if find(ui(), "^TaskFlow$", attrs=("text",)) is not None:
                must_tap("^TaskFlow$", "TaskFlow in the chooser", timeout=5, wait=0.8, attrs=("text",))
            must_tap("button_once$", "Just once", timeout=5, wait=3, attrs=("resource-id",))
        else:
            sh("input keyevent KEYCODE_HOME")
            self.share_intent(PHRASES[self.lang]["share"], direct=True)
            time.sleep(4)
        if wait_for(re.escape(PHRASES[self.lang]["share"]), timeout=12) is None:
            raise Skip("the shared text didn't arrive in TaskFlow")
        root = ui()
        in_form = find(root, L.rx("newTask")) is not None
        self.variants("share", "landing", "What TaskFlow shows after the share, with the shared "
                      "words: " + ("the task form itself." if in_form else "the capture sheet."),
                      prepare=self.keyboard_clear)
        if full:
            if not in_form:
                # The sheet's way to the task form: its typing button, or, for
                # an account without Pro, the main button.
                to_form = next((name for name in ("captureTypeInstead", "done")
                                if find(root, L.rx(name)) is not None), None)
                if to_form is None:
                    raise Skip("the sheet after the share has no way to the form")
                must_tap(L.rx(to_form), L[to_form], wait=2)
                self.snap("share", "form", f"'{L[to_form]}' after a share: the form, prefilled.")
            key("KEYCODE_BACK", 1.5)
            key("KEYCODE_BACK", 2)
            self.snap("share", "after-back", "Pressing Back twice from the prefilled form: what "
                      "is kept, and where the user is.")
        self.restart_app()
        key("KEYCODE_HOME", 1)
        self.share_intent(" ", direct=True)
        time.sleep(1.2)
        self.snap("share", "empty-toast", "Sharing empty text: Android's toast.", quick=True,
                  dump=False)
        time.sleep(3)
        key("KEYCODE_HOME", 1)
        self.share_intent(("Comprar pan. " if self.lang == "es" else "Buy bread. ") * 320, direct=True)
        time.sleep(1.2)
        self.snap("share", "too-long-toast", "Sharing more than 4,000 characters: Android's toast.",
                  quick=True, dump=False)
        time.sleep(3)

    def chooser_again(self) -> None:
        if wait_for_id("button_once", timeout=2) is None:
            self.chooser()

    # Notifications -----------------------------------------------------------

    def ensure_reminders(self) -> None:
        """Reminders on, notifications allowed and exact alarms allowed, as the
        journey leaves them, for runs that skip it. It doesn't stop the app: a
        stop during a reminder refresh locks refreshes for 2 minutes."""
        verify()
        self.grant("POST_NOTIFICATIONS")
        sh(f"appops set {PACKAGE} SCHEDULE_EXACT_ALARM allow")
        self.open_app()
        key("KEYCODE_BACK", 0.8)  # off any screen a section left open
        self.open_app()
        self.tab("settings")
        must_tap(self.L.rx("reminders"), "Recordatorios")
        switch = find(ui(), self.L.rx("enableReminders"))
        if switch is not None and switch.get("checked") != "true":
            tap(*center(switch), wait=2)
            if find(ui(), re.escape(self.L["exactAlarmsNeeded"])) is not None:
                key("KEYCODE_BACK", 1)
        key("KEYCODE_BACK", 1)
        # Back on the calendar: it reloads the tasks, and so their reminders,
        # each time the app resumes.
        self.tab("calendar")

    def clear_silent(self) -> None:
        sh("cmd statusbar expand-notifications")
        time.sleep(1.5)
        node = find_id(ui(), "btn_clear_all")
        if node is not None:
            tap(*center(node), wait=1)
        sh("cmd statusbar collapse")
        time.sleep(1)

    def schedule(self, titles: list[str], lead_from_now: int = 4) -> tuple[list[str], dt.datetime]:
        """Tasks whose default reminder (10 min before) fires in about
        [lead_from_now] minutes. The app schedules them when it resumes; this
        checks Android's alarm list and resumes it again until they're there.
        A second try, with new tasks, outlasts the app's 2-minute refresh lock."""
        for attempt in range(2):
            now = dt.datetime.now().astimezone()
            due = (now + dt.timedelta(minutes=10 + lead_from_now, seconds=59)).replace(
                second=0, microsecond=0)
            fires = due - dt.timedelta(minutes=10)
            ids = [self.backend.create(title, due_date=due.isoformat())["id"] for title in titles]
            target = fires.strftime("%Y-%m-%d %H:%M")
            deadline = min(time.time() + 170, fires.timestamp() - 30)
            tries = 0
            while True:
                if tries == 2:
                    # Resuming hasn't brought them in: a fresh start loads the
                    # tasks from the server.
                    self.restart_app()
                    time.sleep(5)
                    key("KEYCODE_HOME", 1)
                else:
                    key("KEYCODE_HOME", 0.8)
                    sh(f"am start -n {ACTIVITY}", check=True)
                    time.sleep(7)
                    key("KEYCODE_HOME", 1)
                tries += 1
                if target in self.our_alarms():
                    return ids, fires
                if time.time() > deadline:
                    break
                log("  the reminders aren't scheduled yet; opening the app again")
                time.sleep(20)
            for task_id in ids:
                self.backend.delete(task_id)
            if attempt == 0:
                log("  still not scheduled: trying once more with new reminders")
        raise Skip("the app didn't schedule the reminders within about 3 minutes, twice, though "
                   "it was opened again and restarted; rerun with --only notifications")

    def our_alarms(self) -> str:
        """The times of TaskFlow's alarms in Android's alarm list."""
        return sh(f"dumpsys alarm | grep -A3 'Alarm{{.* {PACKAGE}}}' | grep -o 'origWhen=[0-9-]* [0-9:]*'")

    def our_notifications(self) -> str:
        return sh(f"dumpsys notification --noredact | grep -E 'NotificationRecord.*pkg={PACKAGE}'")

    def heads_up(self, fires: dt.datetime) -> None:
        settle()
        baseline = raw_frame()
        deadline = fires.timestamp() + 120
        while PACKAGE not in self.our_notifications():
            if time.time() > deadline:
                raise Skip("no reminder notification arrived within 2 minutes of its time")
            time.sleep(0.5)
        best = None
        until = time.time() + 14
        while time.time() < until:
            frame = raw_frame()
            rows, _, y1, _, y2 = frame_diff(baseline, frame)
            if y2 > 200 and y1 < 450 and rows > 120:
                best = frame
                break
            time.sleep(0.2)
        if best is None:
            self.miss("notification: heads-up", "no heads-up appeared within 14 s of the notification")
        else:
            time.sleep(0.4)
            self.snap("notification", "heads-up", "The reminder arriving: Android's heads-up over "
                      "the home screen.", frame=raw_frame(), dump=False)
        time.sleep(6)

    def shade(self) -> None:
        sh("cmd statusbar collapse")
        time.sleep(0.8)
        sh("cmd statusbar expand-notifications")
        time.sleep(1.5)

    def rows_with(self, title: str) -> list:
        """The shade's rows that hold the reminder titled [title], innermost
        first: the reminder's own row, then the group Android bundles it in."""
        rows = [row for row in ui().iter("node")
                if (row.get("resource-id") or "").endswith("expandableNotificationRow")
                and find(row, "^" + re.escape(title) + "$", attrs=("text",)) is not None]

        def area(row) -> int:
            x1, y1, x2, y2 = box(row)
            return (x2 - x1) * (y2 - y1)
        return sorted(rows, key=area)

    def notification_row(self, title: str):
        rows = self.rows_with(title)
        return rows[0] if rows else None

    def expand_step(self, title: str) -> bool:
        """Taps the innermost arrow around [title]: the reminder's own, or its
        group's when the group is closed. False when there's none."""
        for row in self.rows_with(title):
            button = find_id(row, "expand_button")
            if button is not None:
                tap(*center(button), wait=1.3)
                return True
        return False

    def reveal_actions(self, title: str):
        """Opens the group and the reminder until its action buttons show."""
        for _ in range(3):
            row = self.notification_row(title)
            if row is None:
                return None
            if find(row, "action0$", attrs=("resource-id",)) is not None:
                return row
            if not self.expand_step(title):
                return None
        row = self.notification_row(title)
        return row if row is not None and find(row, "action0$", attrs=("resource-id",)) is not None else None

    def notifications(self, full: bool = True) -> None:
        titles = PHRASES[self.lang]["tasks"] if full else PHRASES[self.lang]["tasks"][:1]
        self.ensure_reminders()
        self.clear_silent()
        ids, fires = self.schedule(titles)
        log(f"  reminders scheduled for {fires.strftime('%H:%M')}; waiting")
        try:
            self.notifications_shown(titles, fires, full)
        finally:
            self.cleanup_reminders(ids)

    def notifications_shown(self, titles: list[str], fires: dt.datetime, full: bool) -> None:
        L = self.L
        self.heads_up(fires)
        self.variants("notification", "shade", ("The notification shade with TaskFlow's three "
                      "reminders, as Android first shows them (it groups them)." if full else
                      "The notification shade with a TaskFlow reminder."), prepare=self.shade)
        self.shade()
        if self.notification_row(titles[0]) is None:
            raise Skip("couldn't find TaskFlow's reminder in the shade")
        if full:
            # Open the group, then one reminder, as a person would.
            if self.expand_step(titles[0]):
                self.snap("notification", "group-open", "After tapping the group's arrow: "
                          "each reminder on its own line.")
            if self.reveal_actions(titles[0]) is not None:
                self.snap("notification", "reminder-open", "After tapping one reminder's arrow: "
                          "its two actions.")
        else:
            row = self.reveal_actions(titles[0])
            if row is not None:
                self.snap("notification", "reminder-open", "The reminder opened, with its actions.")
                if self.expand_step(titles[0]):
                    self.snap("notification", "reminder-closed", "The same reminder closed "
                              "with its arrow.", dump=False)
            else:
                self.miss("notification: reminder-open", "the reminder's actions didn't show")
            return
        # Complete, snooze and tap, one reminder each.
        actions = [(titles[0], "notificationComplete", "after-complete",
                    "After 'Completar': what replaces the reminder."),
                   (titles[1], "notificationSnooze", "after-snooze",
                    "After 'Posponer 10 min': what the shade shows.")]
        for title, label, state, shows in actions:
            self.shade()
            row = self.reveal_actions(title)
            button = (find(row, "^" + re.escape(L[label]), attrs=("text", "content-desc"))
                      if row is not None else None)
            if button is None:
                self.miss(f"notification: {state}", f"'{title}' showed no '{L[label]}' button")
                continue
            tap(*center(button), wait=2)
            self.snap("notification", state, shows)
        self.shade()
        self.reveal_actions(titles[2])  # its own row, out of the group
        row = self.notification_row(titles[2])
        title_node = (find(row, "^" + re.escape(titles[2]) + "$", attrs=("text",))
                      if row is not None else None)
        if title_node is not None:
            tap(*center(title_node), wait=5)
            self.snap("notification", "tap-landing", "Tapping the reminder itself: where the app opens.")
        else:
            self.miss("notification: tap-landing", f"'{titles[2]}' isn't in the shade")

    def alarms_soon(self, minutes: int = 30) -> list[str]:
        """TaskFlow's alarms due within [minutes]."""
        now = dt.datetime.now()
        soon = []
        for stamp in re.findall(r"origWhen=(\d{4}-\d\d-\d\d \d\d:\d\d)", self.our_alarms()):
            when = dt.datetime.strptime(stamp, "%Y-%m-%d %H:%M")
            if now - dt.timedelta(minutes=1) <= when <= now + dt.timedelta(minutes=minutes):
                soon.append(stamp)
        return soon

    def cleanup_reminders(self, ids: list[str]) -> None:
        """Deletes this section's tasks, and makes sure the app has dropped their
        alarms, so a snoozed reminder can't pop up over later captures."""
        for task_id in ids:
            self.backend.delete(task_id)
        sh("cmd statusbar collapse")
        deadline = time.time() + 170
        while True:
            key("KEYCODE_HOME", 0.8)
            sh(f"am start -n {ACTIVITY}", check=True)
            time.sleep(7)
            if not self.alarms_soon() or time.time() > deadline:
                break
            log("  a test reminder is still scheduled; resuming the app again")
            time.sleep(20)
        if self.alarms_soon():
            self.miss("notification: cleanup", "a test reminder stayed scheduled; a later capture "
                      "may show it")

    # Screens and their accessibility trees ----------------------------------

    def decorate(self) -> list[str]:
        """A few quiet tasks so the screens aren't empty; reminders off."""
        today = dt.datetime.now().astimezone()
        later = today.replace(hour=min(today.hour + 3, 22), minute=0, second=0, microsecond=0)
        decor = PHRASES[self.lang]["decor"]
        made = [self.backend.create(decor[0], due_date=later.isoformat(), reminder_minutes=-1),
                self.backend.create(decor[1], scheduled_date=today.date().isoformat(), reminder_minutes=-1),
                self.backend.create(decor[2])]
        return [task["id"] for task in made]

    def screens(self, combos=None) -> None:
        L = self.L
        ids = self.decorate()
        try:
            self.restart_app()
            for tab, state in (("calendar", "today"), ("tasks", "list"), ("notes", "list"),
                               ("settings", "list")):
                self.tab(tab)
                self.variants(f"screen-{tab}", state, f"The {L[tab]} tab with a few tasks. "
                              "Its counts, such as undated or unsaved captures, include what "
                              "earlier sections of this run left behind.", combos=combos)
            self.tab("calendar")
            row = wait_for("^" + re.escape(PHRASES[self.lang]["decor"][0]), timeout=8)
            if row is not None:
                tap(*center(row), wait=2.5)
                self.variants("screen-task-detail", "timed-task", "A task's detail screen.",
                              combos=combos)
                key("KEYCODE_BACK", 1.5)
        finally:
            for task_id in ids:
                self.backend.delete(task_id)

    def narrow(self) -> None:
        """360 dp wide at 2x text: the hardest common case."""
        L = self.L
        self.grant("RECORD_AUDIO")
        ids = self.decorate()
        try:
            verify()
            sh("wm density 480")
            time.sleep(2)
            self.device.apply("light", "2.0")
            self.restart_app()
            self.snap("screen-calendar", "today-360dp", "Calendar at 360 dp and 2x text.")
            self.tab("settings")
            self.snap("screen-settings", "list-360dp", "Settings at 360 dp and 2x text.")
            self.tab("calendar")
            must_tap(L.rx("addTask"), "Añadir tarea", wait=3)
            self.snap("capture", "listening-360dp", "The capture sheet at 360 dp and 2x text.",
                      dump=False, quick=True)
            self.cancel_capture()
            self.shortcuts_popup()
            self.snap("launcher", "shortcuts-360dp", "The shortcuts menu at 360 dp and 2x text.",
                      dump=False)
            key("KEYCODE_BACK", 0.8)
        finally:
            sh("wm density reset")
            self.device.apply("light", "1.0")
            for task_id in ids:
                self.backend.delete(task_id)

    # TalkBack ----------------------------------------------------------------

    def speech_captions(self) -> bool:
        """Turns on TalkBack's 'Display speech output' (developer settings), so
        captures show what TalkBack says. Idempotent: True once the switch reads
        on. Tries twice, from the top of TalkBack's settings each time."""
        for _ in range(2):
            try:
                if self.speech_captions_once():
                    return True
            finally:
                key("KEYCODE_HOME")
            verify()
            sh("am force-stop com.google.android.marvin.talkback")
        return False

    def speech_captions_once(self) -> bool:
        verify()
        # A fresh task, so the settings open at the top, not where they were left.
        sh(f"am start -W -f 0x10008000 -n {TALKBACK_SETTINGS}", timeout=90)
        if wait_for(r"^(Ajustes de TalkBack|TalkBack settings)$", timeout=30) is None:
            return False
        for page in (r"^(Ajustes avanzados|Advanced settings)$",
                     r"^(Ajustes para desarrolladores|Developer settings)$"):
            for _ in range(6):
                if tap_on(page, timeout=3, wait=2, attrs=("text",)):
                    break
                sh("input swipe 540 1700 540 900 400")
                time.sleep(0.8)
            else:
                return False
        switch = self.caption_switch()
        for _ in range(3):
            if switch is not None:
                break
            sh("input swipe 540 1700 540 900 400")
            time.sleep(0.8)
            switch = self.caption_switch()
        if switch is not None and switch.get("checked") != "true":
            tap(*center(switch), wait=1.5)
            switch = self.caption_switch()
        return switch is not None and switch.get("checked") == "true"

    @staticmethod
    def caption_switch():
        """The switch on the 'Display speech output' row, when it's on screen."""
        root = ui()
        label = find(root, r"^(Mostrar salida de voz|Display speech output)$", attrs=("text",))
        if label is None:
            return None
        y = center(label)[1]
        switches = [n for n in root.iter("node") if n.get("class") == "android.widget.Switch"]
        return min(switches, key=lambda n: abs(center(n)[1] - y), default=None)

    def positions(self, names: list[str]) -> dict[str, tuple[int, int]]:
        """Where these controls are on the current screen, by their labels."""
        root = ui()
        found = {}
        for name in names:
            node = find(root, self.L.rx(name))
            if node is not None:
                found[name] = center(node)
            else:
                self.miss(f"talkback: {name}", "the control isn't on screen")
        return found

    def talkback_ready(self, timeout: float = 30) -> bool:
        """TalkBack bound and exploring by touch."""
        deadline = time.time() + timeout
        while time.time() < deadline:
            bound = sh("dumpsys accessibility | grep -m1 'Bound services'")
            if "TalkBack" in bound and sh("settings get secure touch_exploration_enabled").strip() == "1":
                time.sleep(4)  # it reads the screen once when it starts
                return True
            time.sleep(1)
        return False

    def talkback(self) -> None:
        """TalkBack on, its focus and spoken text on key controls. A uiautomator
        dump switches TalkBack off while it reads the screen, so every position
        is read first and nothing reads the screen while TalkBack is on."""
        L = self.L
        self.grant("RECORD_AUDIO")
        if not self.speech_captions():
            self.miss("talkback: spoken-text captions", "couldn't switch on TalkBack's 'Mostrar "
                      "salida de voz'; the captures show the focus frame, and the spoken text "
                      "only if it was already on")
        # Positions, with TalkBack off.
        self.restart_app()
        calendar = self.positions(["addTask", "calendar", "settings"])
        if not {"addTask", "calendar", "settings"} <= calendar.keys():
            raise Skip("the calendar's controls weren't all on screen")
        tap(*calendar["settings"], wait=2)
        settings = self.positions(["reminders", "language", "otherSettings"])
        tap(*calendar["calendar"], wait=1.5)
        tap(*calendar["addTask"], wait=3)
        sheet = self.positions(["done", "cancel", "captureTypeInstead"])
        self.cancel_capture()
        # TalkBack asks for its own notifications when it starts, over the app.
        # Answer it once and for all: denied, and not asked again.
        verify()
        talkback = "com.google.android.marvin.talkback"
        sh(f"pm revoke {talkback} android.permission.POST_NOTIFICATIONS")
        sh(f"pm set-permission-flags {talkback} android.permission.POST_NOTIFICATIONS user-set user-fixed")
        self.device.talkback(True)
        try:
            if not self.talkback_ready():
                raise Skip("TalkBack didn't start within 30 s")
            plan = [("calendar", calendar, None), ("settings", settings, calendar["settings"])]
            for screen, targets, way_in in plan:
                if way_in:
                    tap(*way_in, wait=2.5)  # `input tap` acts directly, even with TalkBack on
                self.snap("talkback", f"{screen}-start", f"TalkBack on: the {screen} screen as it "
                          "opens, and where focus starts.", quick=True, dump=False)
                for name, (x, y) in targets.items():
                    console_touch(x, y)
                    time.sleep(0.35)
                    self.snap("talkback", f"{screen}-{name}", f"TalkBack focus on '{L[name]}'; the "
                              "dark caption at the bottom is the part being spoken.",
                              quick=True, dump=False)
            tap(*calendar["calendar"], wait=2)
            tap(*calendar["addTask"], wait=3)
            self.snap("talkback", "capture-sheet", "TalkBack on, the capture sheet open and "
                      "listening: where focus lands.", quick=True, dump=False)
            for name, (x, y) in sheet.items():
                console_touch(x, y)
                time.sleep(0.35)
                self.snap("talkback", f"capture-{name}", f"TalkBack focus on '{L[name]}' in the "
                          "capture sheet.", quick=True, dump=False)
            if "cancel" in sheet:
                tap(*sheet["cancel"], wait=1.5)
        finally:
            self.device.talkback(False)

    # Other languages -----------------------------------------------------------

    def language_pass(self, lang: str) -> None:
        self.top = "languages"
        self.lang = lang
        self.L = Strings(lang)
        self.device.locale(lang)
        self.run_section("launcher", self.launcher_lite)
        self.run_section("widget", lambda: self.widget("(Same widget in every state.)"))
        self.run_section("share", lambda: self.share(full=False))
        self.run_section("microphone", self.microphone_lite)
        self.run_section("screens", lambda: self.screens(combos=LIGHT))
        # A reminder costs about 5 minutes of waiting. Catalan's text runs
        # longest; English runs shorter than Spanish.
        if lang == "ca":
            self.run_section("notifications", lambda: self.notifications(full=False))

    def launcher_lite(self) -> None:
        self.restart_app()
        self.variants("launcher", "shortcuts", "Long-press on the icon: TaskFlow's two shortcuts.",
                      prepare=self.shortcuts_popup)
        key("KEYCODE_BACK", 0.6)

    def microphone_lite(self) -> None:
        L = self.L
        self.reset_permission("RECORD_AUDIO")
        self.restart_app()
        must_tap(L.rx("addTask"), L["addTask"], wait=0.5)
        if self.dialog() is None:
            raise Skip("the microphone dialog didn't appear")
        self.snap("permission-mic", "dialog", "The system microphone dialog.", dump=False)
        tap_id("permission_deny_button", wait=2)
        self.variants("permission-mic", "denied", "After 'Don't allow': the capture sheet's banner.")
        must_tap(L.rx("captureStartTalking"), L["captureStartTalking"], wait=0.5)
        if self.dialog() is not None:
            tap_id("permission_deny_and_dont_ask_again_button", "permission_deny_button", wait=2)
            settings = find(ui(), L.rx("captureOpenSettings")) is not None
            self.variants("permission-mic", "blocked", "Denied twice: " + (
                "the sheet points to Settings." if settings else "the sheet still shows the first "
                "denial's banner, with no way to Settings."))
        self.cancel_capture()
        self.grant("RECORD_AUDIO")
        must_tap(L.rx("addTask"), L["addTask"], wait=3)
        # Without on-device recognition for the language, the app records audio
        # for the server instead, and the sheet looks different.
        try:
            live = find(ui(), L.rx("captureTypeInstead")) is not None
        except RuntimeError:
            live = True
        self.variants("capture", "listening", "Listening (emulator: no voice)." + (
            "" if live else " This emulator can't recognise the language on the device, so the "
            "app records audio for the server instead: its sheet has the main button active "
            f"from the start and no '{L['captureTypeInstead']}'."), dump=False, quick=True)
        self.cancel_capture()

    # Helpers -----------------------------------------------------------------

    @staticmethod
    def wait_until(moment: float) -> None:
        remaining = moment - time.time()
        if remaining > 0:
            time.sleep(remaining)


# --- INDEX.md ------------------------------------------------------------------

INTRO = """# Device captures — TaskFlow_Review emulator

Evidence level: **emulator** (Android 16 / API 36, Pixel 4 profile, Pixel Launcher,
headless, no microphone audio). Not a physical phone, not a real voice.
Generated by `.claude/ux-review/emulator/capture.py`; how to read and rerun it:
`.claude/ux-review/emulator/README.md`.

File names: `<surface>.<state>.<lang>.<theme>.<text scale>.png`. Next to most
screens, `a11y/<same name>.xml` is the uiautomator tree: roughly what TalkBack
reads (labels, roles, states, bounds).

A debug build: "Ajustes de conexión" under sign-in and "Diagnóstico de captura"
in Otros ajustes appear only in debug builds. Android's own error dialogs are
hidden on this emulator, so a frozen app shows as a still screen, not a dialog.
"""


def write_index(lane: Lane, run: dict) -> None:
    store = OUT / "index.json"
    previous = {}
    if lane.args.only and store.exists():
        try:
            previous = json.loads(store.read_text(encoding="utf-8"))
        except ValueError:
            previous = {}
    entries = {e["file"]: e for e in previous.get("entries", [])}
    for entry in lane.entries:
        entries[entry["file"]] = entry
    entries = {f: e for f, e in entries.items() if (OUT / f).exists()}
    ran = set(run["sections"])
    missing = [m for m in previous.get("missing", []) if m.get("section") not in ran] + lane.missing
    runs = (previous.get("runs", []) + [run])[-5:]
    store.write_text(json.dumps({"entries": list(entries.values()), "missing": missing,
                                 "runs": runs}, indent=1, ensure_ascii=False), encoding="utf-8")

    lines = [INTRO]
    # A scoped run keeps the captures of the runs before it: list them all,
    # newest first. A full run starts the list again.
    lines.append("## Runs\n" if len(runs) > 1 else "## Run\n")
    for past in reversed(runs):
        lines.append(f"- {past['started']} to {past['finished']} ({past['minutes']} min): sections "
                     f"{', '.join(past['sections'])}; languages {', '.join(past['langs'])}. APK "
                     f"`{Path(past['apk']).name}`, sha256 {past['sha256']}…, built {past['built']}, "
                     f"commit {past['commit']}.")
    lines.append("- Each capture's own time and APK commit are in its row. `*` means uncommitted "
                 "changes in App/, and `?` that the APK's commit wasn't recorded.")
    lines.append("- Account: the review test account on the local Docker backend (free tier, "
                 "credentials in `review.local.json`, never shown here).")
    lines.append(f"- {len(entries)} PNGs. Variants: Spanish in light and dark at text 1.0 and 2.0; "
                 "English and Catalan in light at 1.0 and 2.0; a few at 360 dp.\n")
    order: list[str] = []
    for entry in entries.values():
        if entry["surface"] not in order:
            order.append(entry["surface"])
    for surface in order:
        lines.append(f"## {surface}\n")
        lines.append("| File | Shows | a11y | Time · commit |")
        lines.append("|---|---|---|---|")
        for entry in entries.values():
            if entry["surface"] != surface:
                continue
            a11y = entry.get("a11y") or ""
            if a11y.startswith("a11y/"):
                a11y = f"[xml]({a11y})"
            stamp = f"{entry['time'][:10]} {entry['time'][11:19]} · {entry.get('commit', '?')}"
            shows = entry["shows"].replace("|", "\\|")
            lines.append(f"| [{entry['file']}]({entry['file']}) | {shows} | {a11y} | {stamp} |")
        lines.append("")
    lines.append("## Not captured\n")
    standing = [
        ("Real speech recognition", "the emulator has no voice; listening is shown, recognised "
         "words never appear. Physical-phone check."),
        ("The capture's AI result (review screen)", "the review account is on the free tier, and the "
         "lane doesn't grant Pro or spend AI calls; the UX preview suite renders it "
         "(`App/build/ux/INDEX.md`)."),
        ("The widget's 'with tasks' state", "the widget is a single dictate button with no task "
         "content: it looks the same with or without tasks."),
        ("Android's grid Sharesheet", "`am start -a SEND` opens the list chooser; the grid comes from "
         "apps that call the Sharesheet (WhatsApp, Chrome), which would need their own first-run terms."),
        ("Sign-up and the email code screen", "the lane signs in with one fixed account rather than "
         "creating one per run; the UX preview suite renders them (`App/build/ux/INDEX.md`)."),
        ("A reminder in English", "each reminder costs about 5 minutes of waiting, so the lane "
         "shows Spanish and Catalan, whose text runs longest."),
    ]
    for what, why in standing:
        lines.append(f"- **{what}:** {why}")
    for item in missing:
        lines.append(f"- **{item['what']}** ({item['lang']}, {item['time'][11:16]}): {item['why']}")
    (OUT / "INDEX.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


# --- Main ----------------------------------------------------------------------

def run(args) -> int:
    started = time.time()
    began = dt.datetime.now().astimezone()
    only = [s.strip() for s in args.only.split(",")] if args.only else SECTIONS
    skip = {s.strip() for s in args.skip.split(",")} if args.skip else set()
    unknown = [s for s in only + list(skip) if s not in SECTIONS]
    if unknown:
        raise SystemExit(f"Unknown section(s): {', '.join(unknown)}. Choose from: {', '.join(SECTIONS)}")
    sections = [s for s in SECTIONS if s in only and s not in skip]
    langs = [l.strip() for l in args.langs.split(",")]

    account, _ = ensure_account()
    # The emulator boots while the APK builds.
    started_emulator = launch_emulator()
    try:
        if args.apk:
            apk, source = Path(args.apk).resolve(), "given"
        elif args.no_build:
            apk, source = APK_DEFAULT, "reused"
        else:
            apk, source = build_apk(), "built"
        if not apk.exists():
            raise SystemExit(f"No APK at {apk}")
        facts = apk_facts(apk, source)
        wait_for_boot(started_emulator)
    except BaseException:
        if started_emulator and not args.keep_running and online():
            stop_emulator()
        raise
    device = Device()
    if not args.only:
        for old in list(OUT.glob("*.png")) + list(A11Y.glob("*.xml")):
            old.unlink()
    lane = Lane(args, device, Backend(account), account, facts)
    try:
        device.prepare()
        install(apk)
        lane.warm_up()
        if "journey" in sections:
            lane.run_section("journey", lane.journey)
        if "calendar-permission" in sections:
            lane.run_section("calendar-permission", lane.calendar_permission)
        if "launcher" in sections:
            lane.run_section("launcher", lane.launcher)
        if "widget" in sections:
            lane.run_section("widget", lambda: lane.widget(
                "The widget has no task content, so it looks the same with or without tasks."))
        if "share" in sections:
            lane.run_section("share", lane.share)
        if "notifications" in sections:
            lane.run_section("notifications", lane.notifications)
        if "screens" in sections:
            lane.run_section("screens", lane.screens)
        if "narrow" in sections:
            lane.run_section("narrow", lane.narrow)
        if "talkback" in sections:
            lane.run_section("talkback", lane.talkback)
        if "languages" in sections:
            for lang in langs:
                if lang != "es":
                    lane.language_pass(lang)
            lane.lang, lane.L = "es", Strings("es")
    finally:
        device.restore()
        finished = dt.datetime.now().astimezone()
        write_index(lane, {
            "started": began.isoformat(timespec="seconds"), "finished": finished.isoformat(timespec="seconds"),
            "minutes": round((time.time() - started) / 60, 1), "sections": sections,
            "langs": langs if "languages" in sections else ["es"], **facts})
        if started_emulator and not args.keep_running:
            stop_emulator()
    log(f"done: {len(lane.entries)} captures, {len(lane.missing)} not captured, "
        f"{(time.time() - started) / 60:.1f} min. Index: {OUT / 'INDEX.md'}")
    return 0


def main(argv: list[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    tools = {"account", "stop", "adb", "ui", "shot", "status"}
    if argv and argv[0] in tools:
        command, rest = argv[0], argv[1:]
        if command == "account":
            _, session = ensure_account()
            print(f"review account ready (id {session.get('user', {}).get('id')})")
            return 0
        if command == "stop":
            stop_emulator()
            return 0
        if command == "status":
            print(f"{SERIAL}: {'online as ' + avd_name() if online() else 'offline'}")
            return 0
        verify()
        if command == "adb":
            sys.stdout.write(adb(*rest, check=False, timeout=120))
        elif command == "shot":
            Path(rest[0]).write_bytes(adb("exec-out", "screencap", "-p", binary=True))
            print(rest[0])
        elif command == "ui":
            print(outline(ui()))
        return 0
    parser = argparse.ArgumentParser(description="Capture TaskFlow's native surfaces from the "
                                     "TaskFlow_Review emulator.")
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--apk", help="install this APK instead of building one")
    source.add_argument("--no-build", action="store_true", help="install the last debug APK as is")
    parser.add_argument("--only", help=f"comma-separated sections: {', '.join(SECTIONS)}")
    parser.add_argument("--skip", help="comma-separated sections to leave out")
    parser.add_argument("--langs", default="es,en,ca", help="languages for the 'languages' pass")
    parser.add_argument("--keep-data", action="store_true",
                        help="don't clear TaskFlow's data first (skips the genuine first run)")
    parser.add_argument("--keep-running", action="store_true",
                        help="leave the emulator running if this run started it")
    args = parser.parse_args(argv)
    try:
        return run(args)
    except SafetyError as error:
        log(f"STOPPED for safety: {error}")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
