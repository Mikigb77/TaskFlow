"""The package check for the UX loop: run the tests and previews a change touches, and only those.

Every step of a package (its implementer, its tester, its fix, its integrator) runs this instead
of choosing tests by hand, so the run's final check is the only place the whole suite runs, once
per run. From anywhere in a package's worktree:

  python -I -X utf8 <main checkout>/.claude/skills/ux/scripts/check.py [--previews auto] [--slots N]

What counts as changed: the first time, everything the package changed since its seed (waves.py
seed); after that, what changed since the last check, plus what failed in it. Its state is kept in
the worktree's git folder, so it never reaches the main checkout. --all counts everything since
the seed again.

In the main checkout, once every package is merged (the run's repair and its re-check):

  python -I -X utf8 .claude/skills/ux/scripts/check.py --main --files <path> ... [--tests <test file> ...]

What it runs, from App/, holding one of the gate's slots from start to end (waves.py gate_slot):
  1. flutter gen-l10n, when an ARB file changed.
  2. flutter analyze --no-pub on the changed Dart files, the files that import them and the files
     that show a changed ARB key (the whole app when that is more than --max-analyze files). An
     analyzer error stops the check before the tests.
  3. flutter test --no-pub on the tests that cover the change, at most --max files (30):
     tests that failed last time; changed tests; a test named after a changed file; the tests
     that name a changed ARB key, and localization_catalog_test.dart when an ARB file changed;
     tests that import a changed file (re-exports and parts followed), or a file that shows a
     changed key; tests that name another changed file (Android resources, assets, iOS). Over
     --max, the rest are listed as left to the final check. --also <files> adds tests to run
     whatever the choice (the tests that failed before a repair).
  4. The UX previews of the screens the change shows (--previews auto: every screen whose Sources
     in App/build/ux/INDEX.md hold a changed file, a file importing one, or a file showing a
     changed key; a whole area when its preview flows changed), or of a --previews <regex> of
     preview names. None unless asked: the tester renders, and a fix renders again.
  5. flutter build apk --debug --no-pub --target-platform android-x64, as a compile check, when
     a file under App/android/ changed. Build only; it installs nothing.

--tests <files> runs exactly those test files (and analyzes them) instead of choosing. --list
prints what would run and why, and runs nothing. The summary gives each step's result and time,
and every failing test with the first lines of its error; the full logs are in App/build/ux-check/.
--json prints the summary as JSON. The exit status is 0 when everything that ran passed.
"""
import argparse
import hashlib
import json
import os
import posixpath
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True  # no __pycache__ in the repo's scripts folder
sys.path.insert(0, str(Path(__file__).resolve().parent))
import waves  # noqa: E402  (the seed, the changes since it, and the gate)

GENERATED = waves.GENERATED
STATE = "ux-check.json"
LOGS = "App/build/ux-check"
CATALOG = "App/test/localization_catalog_test.dart"
PREVIEW_TEST = "test/ux_previews/ux_previews_test.dart"
PREVIEWS = "App/test/ux_previews/"
INDEX = "App/build/ux/INDEX.md"
ARB = re.compile(r"^App/lib/l10n/app_\w+\.arb$")
DIRECTIVE = re.compile(r"""^\s*(import|export|part)\s+['"]([^'"]+)['"]""", re.M)
# How the app and its tests read a string: context.l10n.key, strings.key, l.key, es.key …
LIB_VARS = r"(?:l10n|strings|loc|s|t|l)"
TEST_VARS = r"(?:l10n|strings|loc|s|t|l|es|ca|en|copy|english|spanish|catalan)"
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
PROGRESS = re.compile(r"^\d+:\d+ \+(\d+)(?: ~(\d+))?(?: -(\d+))?: (.*)$")
ISSUE = re.compile(r"^\s*(error|warning|info)\s+[•-]\s+(.*?)\s+[•-]\s+(\S+?\.dart):(\d+):(\d+)\s+[•-]\s+(\S+)\s*$")
STEPS = ("gen", "analyze", "tests", "previews", "native")


def say(message):
    print(message, flush=True)


def sha(data):
    return hashlib.sha1(data).hexdigest()[:16]


# ---------------------------------------------------------------- the import graph

class Graph:
    """The Dart import graph of App/lib and App/test: who imports, exports or includes whom."""

    def __init__(self, root):
        self.root = root
        pkg = f"package:{package_name(root)}/"
        self.text, self.deps, self.exports, self.parts, self.rev = {}, {}, {}, {}, {}
        for base in ("App/lib", "App/test"):
            folder = root / base
            if not folder.is_dir():
                continue
            for path in folder.rglob("*.dart"):
                rel = path.relative_to(root).as_posix()
                try:
                    text = path.read_text(encoding="utf-8", errors="replace")
                except OSError:
                    text = ""
                self.text[rel] = text
                deps, exports = set(), set()
                for kind, uri in DIRECTIVE.findall(text):
                    target = resolve(rel, uri, pkg)
                    if not target:
                        continue
                    deps.add(target)
                    if kind == "export":
                        exports.add(target)
                    elif kind == "part":
                        self.parts[target] = rel
                self.deps[rel], self.exports[rel] = deps, exports
                for target in deps:
                    self.rev.setdefault(target, set()).add(rel)

    def library(self, rel):
        """A part file's library; any other file is its own."""
        seen = set()
        while rel in self.parts and rel not in seen:
            seen.add(rel)
            rel = self.parts[rel]
        return rel

    def importers(self, target):
        """The files that import, export or include target, directly or through a file that
        re-exports it."""
        out, stack, seen = set(), [target], set()
        while stack:
            t = stack.pop()
            if t in seen:
                continue
            seen.add(t)
            for f in self.rev.get(t, ()):
                out.add(f)
                if t in self.exports.get(f, ()):
                    stack.append(f)
        out.discard(target)
        return out


def package_name(root):
    try:
        found = re.search(r"^name:\s*(\S+)", (root / "App" / "pubspec.yaml").read_text(encoding="utf-8"), re.M)
        return found.group(1) if found else "agenda"
    except OSError:
        return "agenda"


def resolve(src, uri, pkg):
    if uri.startswith(pkg):
        return "App/lib/" + uri[len(pkg):]
    if uri.startswith(("package:", "dart:")):
        return None
    return posixpath.normpath(posixpath.join(posixpath.dirname(src), uri))


def regular_test(rel, root):
    return (rel.startswith("App/test/") and rel.endswith("_test.dart") and not rel.startswith(PREVIEWS)
            and (root / rel).is_file())


# ---------------------------------------------------------------- what changed

def prints(root, paths):
    out = {}
    for rel in paths:
        p = root / rel
        out[rel] = sha(p.read_bytes()) if p.is_file() else "gone"
    return out


def arb_keys(data):
    """{key: hash of its value} for an ARB file's bytes; @metadata counts for its key."""
    if not data:
        return {}
    try:
        catalog = json.loads(data.decode("utf-8"))
    except ValueError:
        return {}
    out = {}
    for key, value in catalog.items():
        if key.startswith("@@"):
            continue
        name = key[1:] if key.startswith("@") else key
        out[name] = sha((out.get(name, "") + json.dumps(value, sort_keys=True, ensure_ascii=False)).encode("utf-8"))
    return out


def base_bytes(root, rev, rel):
    shown = subprocess.run(["git", "-C", str(root), "show", f"{rev}:{rel}"], capture_output=True)
    return shown.stdout if shown.returncode == 0 else None


def changed_keys(root, base_rev, arbs, before):
    """The ARB keys whose value changed, was added or was removed, in the given ARB files, since
    `before` ({file: {key: hash}}) or, for a file it doesn't hold, since base_rev."""
    keys = set()
    now = {}
    for rel in arbs:
        p = root / rel
        cur = arb_keys(p.read_bytes() if p.is_file() else None)
        now[rel] = cur
        old = before.get(rel)
        if old is None:
            old = arb_keys(base_bytes(root, base_rev, rel)) if base_rev else {}
        keys |= {k for k in set(cur) | set(old) if cur.get(k) != old.get(k)}
    return keys, now


class Changes:
    """What a check compares against: the worktree since its seed and since each step's last
    run, or the given files in the main checkout."""

    def __init__(self, args):
        self.main = args.main
        if args.main:
            self.root = waves.main_root(Path(__file__).resolve().parent)
            self.base = "HEAD"
            self.paths = sorted({norm_rel(f, self.root) for f in args.files or []})
            self.state_file = None
            self.state = {"steps": {}}
            return
        top = waves.git(Path.cwd(), "rev-parse", "--show-toplevel")
        self.root = Path(top)
        main = waves.main_root(self.root)
        if self.root.resolve() == main.resolve():
            raise SystemExit("This is the main checkout. In a package's worktree, run check.py from there; "
                             "in the main checkout, pass --main and the changed files with --files.")
        try:
            seed, paths = waves.changes(self.root)
        except waves.NotSeeded as e:
            raise SystemExit(f"{e} Run waves.py seed first.")
        self.base = seed
        self.paths = sorted(p for p in paths if p.startswith("App/") and not p.startswith(waves.NOT_MERGED)
                            and not p.startswith(GENERATED))
        if args.files:
            self.paths = sorted(set(self.paths) | {norm_rel(f, self.root) for f in args.files})
        gitdir = Path(waves.git(self.root, "rev-parse", "--path-format=absolute", "--git-dir"))
        self.state_file = gitdir / STATE
        self.state = {"steps": {}}
        if self.state_file.is_file():
            try:
                self.state = json.loads(self.state_file.read_text(encoding="utf-8"))
            except ValueError:
                pass
        if self.state.get("seed") != seed:
            self.state = {"seed": seed, "steps": {}}
        if args.all:
            self.state["steps"] = {}
        self.now = prints(self.root, self.paths)

    def since(self, step):
        """(changed paths, changed ARB keys, ARB key prints now) since the step's last run."""
        if self.main:
            arbs = [p for p in self.paths if ARB.match(p)]
            keys, now = changed_keys(self.root, self.base, arbs, {})
            return list(self.paths), keys, now
        last = self.state["steps"].get(step) or {}
        before = last.get("prints")
        if before is None:
            paths = list(self.paths)
        else:
            paths = sorted(p for p in set(self.now) | set(before) if self.now.get(p, "seed") != before.get(p, "seed"))
        arbs = [p for p in paths if ARB.match(p)]
        keys, now = changed_keys(self.root, self.base, arbs, last.get("keys") or {})
        return paths, keys, now

    def failed(self, step):
        return list((self.state["steps"].get(step) or {}).get("failed") or [])

    def ran(self, step, failed, keys_now, advance=True, covered=()):
        """Records a step's run: what it saw (unless advance is False, for an explicit run of
        given tests) and what failed. An explicit run clears only the failures it covered."""
        if self.main:
            return
        last = self.state["steps"].get(step) or {}
        if not advance:
            failed = (set(last.get("failed") or []) - set(covered)) | set(failed)
        entry = {"failed": sorted(set(failed)), "at": time.strftime("%Y-%m-%dT%H:%M:%S")}
        if advance:
            entry["prints"] = self.now
            entry["keys"] = {**(last.get("keys") or {}), **keys_now}
        else:
            entry["prints"] = last.get("prints")
            entry["keys"] = last.get("keys") or {}
            if entry["prints"] is None:
                entry.pop("prints")
        self.state["steps"][step] = entry

    def save(self):
        if self.state_file:
            self.state_file.write_text(json.dumps(self.state, ensure_ascii=False), encoding="utf-8")


def norm_rel(path, root):
    p = str(path).replace("\\", "/")
    r = str(root).replace("\\", "/").rstrip("/")
    if p.lower().startswith(r.lower() + "/"):
        p = p[len(r) + 1:]
    p = re.sub(r"^\./", "", p)
    if p.startswith(("lib/", "test/", "android/", "ios/", "assets/")):
        p = "App/" + p
    return p


# ---------------------------------------------------------------- choosing

LIB_USE = re.compile(rf"\b{LIB_VARS}!?\.\s*([A-Za-z_]\w*)")
TEST_USE = re.compile(rf"\b{TEST_VARS}!?\.\s*([A-Za-z_]\w*)|['\"]([A-Za-z_]\w*)['\"]")


def key_users(graph, keys):
    """(lib files that show a changed key, tests that name one), each with the key."""
    shown, named = {}, {}
    if not keys:
        return shown, named
    for rel, text in graph.text.items():
        if rel.startswith(GENERATED):
            continue
        if rel.startswith("App/lib/"):
            hit = sorted(keys & set(LIB_USE.findall(text)))
            if hit:
                shown[rel] = hit[0]
        elif rel.startswith("App/test/"):
            used = set()
            for a, b in TEST_USE.findall(text):
                used.add(a or b)
            hit = sorted(keys & used)
            if hit:
                named[rel] = hit[0]
    return shown, named


def namesakes(rel, root):
    """Tests named after a changed file: foo.dart -> foo_test.dart; foo_screen.dart -> foo_test.dart."""
    stem = posixpath.basename(rel)[:-5]
    out = []
    for name in {stem, re.sub(r"_(screen|sheet|widget|page|dialog|service|provider)$", "", stem)}:
        cand = f"App/test/{name}_test.dart"
        if regular_test(cand, root):
            out.append(cand)
    return out


def choose_tests(graph, root, paths, keys, failed, limit):
    """The tests that cover these changes, most specific first: [(test, why)], and those over
    the limit."""
    score = {}

    def take(test, rank, why):
        if not regular_test(test, root):
            return
        if test in score:
            r, hits, reason = score[test]
            score[test] = (min(r, rank), hits + 1, reason if r <= rank else why)
        else:
            score[test] = (rank, 1, why)

    for t in failed:
        take(t, 0, "failed before")
    dart = [p for p in paths if p.endswith(".dart") and not p.startswith(GENERATED)]
    for rel in dart:
        if regular_test(rel, root):
            take(rel, 0, "changed")
    if any(ARB.match(p) for p in paths):
        take(CATALOG, 1, "an ARB file changed")
    shown, named = key_users(graph, keys)
    for test, key in named.items():
        take(test, 1, f"names the changed key {key}")
    for rel in dart:
        if rel.startswith(PREVIEWS):
            continue
        for t in namesakes(rel, root):
            take(t, 1, f"named after {short(rel)}")
        lib = graph.library(rel)
        for t in graph.importers(lib):
            take(t, 2, f"imports {short(rel)}")
    for rel, key in shown.items():
        if rel in dart:
            continue
        for t in namesakes(rel, root):
            take(t, 2, f"named after {short(rel)}, which shows {key}")
        for t in graph.importers(graph.library(rel)):
            take(t, 3, f"imports {short(rel)}, which shows {key}")
    others = [p for p in paths if not p.endswith(".dart") and not ARB.match(p)]
    for rel in others:
        name = posixpath.basename(rel)
        needles = {rel[len("App/"):]}
        if len(name) >= 6 and "." in name:
            needles.add(name)
        for test, text in graph.text.items():
            if test.startswith("App/test/") and any(n in text for n in needles):
                take(test, 3, f"names {name}")

    def size(t):
        try:
            return (root / t).stat().st_size
        except OSError:
            return 0

    ordered = sorted(score, key=lambda t: (score[t][0], -score[t][1], size(t), t))
    chosen = [(t, score[t][2]) for t in ordered[:limit]]
    rest = [(t, score[t][2]) for t in ordered[limit:]]
    return chosen, rest, shown


def choose_analyze(graph, paths, shown, failed, limit):
    files = set(failed)
    for rel in paths:
        if not rel.endswith(".dart") or rel.startswith(GENERATED):
            continue
        if rel in graph.text:
            files.add(rel)
        if rel.startswith("App/lib/"):
            files |= {f for f in graph.importers(graph.library(rel)) if f in graph.text}
    files |= {f for f in shown if f in graph.text}
    files = sorted(f for f in files if not f.startswith(GENERATED))
    return (files, False) if len(files) <= limit else ([], True)


def preview_index(root, main):
    """{"<area>/<screen>": [repo-relative sources]} from INDEX.md: the main checkout's, then this one's."""
    screens = {}
    for base in dict.fromkeys([main, root]):
        path = base / INDEX
        if not path.is_file():
            continue
        area, screen = None, None
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            m = re.match(r"^## .*`build/ux/([^/`]+)/`\s*$", line)
            if m:
                area, screen = m.group(1), None
                continue
            m = re.match(r"^### .*\(`([^`]+)`\)\s*$", line)
            if m and area:
                screen = f"{area}/{m.group(1)}"
                continue
            if line.startswith("Sources:") and screen:
                screens.setdefault(screen, set()).update(re.findall(r"`(App/[^`]+)`", line))
    return screens


def choose_previews(graph, root, main, paths, shown):
    """The preview names to render ('<area>/<screen>.' or '<area>/'), or None for all of them.
    A changed file that is a Source of a screen picks that screen; one that is no screen's
    Source (a service, a helper) picks the screens of the files that import it."""
    screens = preview_index(root, main)
    sources = set().union(*screens.values()) if screens else set()
    touched = set(shown)
    for rel in paths:
        if rel.startswith("App/lib/") and rel.endswith(".dart") and not rel.startswith(GENERATED):
            lib = graph.library(rel)
            if rel in sources or lib in sources:
                touched |= {rel, lib}
            else:
                touched |= {f for f in graph.importers(lib) if f.startswith("App/lib/")}
    names = {s + "." for s, src in screens.items() if src & touched}
    for rel in paths:
        if not rel.startswith(PREVIEWS) or not rel.endswith(".dart"):
            continue
        m = re.match(r"^App/test/ux_previews/(\w+)_previews\.dart$", rel)
        if m:
            names.add(m.group(1).replace("_", "-") + "/")
        else:
            return None  # the preview support or the suite itself changed: render everything
    if screens and len([n for n in names if n.endswith(".")]) > 0.6 * len(screens):
        return None
    return sorted(names)


def preview_regex(names):
    return "(?:" + "|".join(n.replace(".", r"\.") for n in names) + ")"


def short(rel):
    return rel[len("App/"):] if rel.startswith("App/") else rel


# ---------------------------------------------------------------- running

def quote_win(arg):
    if arg and not re.search(r'[\s|&<>^()%!"]', arg):
        return arg
    return '"' + arg.replace('"', '""') + '"'


def flutter(root, args, log_name):
    """Runs flutter in App/, its output to a log. Returns (exit status, seconds, log text)."""
    app = root / "App"
    logs = root / LOGS
    logs.mkdir(parents=True, exist_ok=True)
    log = logs / log_name
    exe = shutil.which("flutter") or "flutter"
    start = time.time()
    if not shutil.which("flutter"):
        log.write_text("flutter is not on PATH", encoding="utf-8")
        return 127, 0.0, "flutter is not on PATH: this check needs the Flutter SDK."
    with open(log, "wb") as out:
        if os.name == "nt":
            line = " ".join(quote_win(a) for a in [exe, *args])
            code = subprocess.run(line, cwd=app, stdout=out, stderr=subprocess.STDOUT, shell=True).returncode
        else:
            code = subprocess.run([exe, *args], cwd=app, stdout=out, stderr=subprocess.STDOUT).returncode
    text = ANSI.sub("", log.read_bytes().decode("utf-8", "replace")).replace("\r", "")
    return code, time.time() - start, text


def test_failures(text, root):
    """The failing tests in an expanded-reporter log, each with the first lines of its error."""
    app = str(root / "App").replace("\\", "/")
    found, cur, totals = [], None, (0, 0, 0)

    def tidy(desc):
        desc = desc.replace("\\", "/")
        if app and app in desc:
            desc = desc.replace(app + "/", "")
        return re.sub(r"^.*?/App/(test/)", r"\1", desc)

    for raw in text.splitlines():
        m = PROGRESS.match(raw)
        if m:
            totals = (int(m.group(1)), int(m.group(3) or 0), int(m.group(2) or 0))
            if cur:
                found.append(cur)
                cur = None
            desc = m.group(4)
            if desc.endswith(" [E]"):
                cur = {"test": tidy(desc[:-4]), "error": []}
            continue
        line = raw.strip()
        if cur is None or not line or len(cur["error"]) >= 10:
            continue
        if re.match(r"^(#\d+|package:|dart:|===|\^|<asynchronous suspension>|When the exception was thrown)", line):
            continue
        cur["error"].append(line[:300])
    if cur:
        found.append(cur)
    seen, out = set(), []
    for f in found:
        if f["test"] in seen:
            continue
        seen.add(f["test"])
        out.append({"test": f["test"], "error": "\n".join(f["error"][:8])})
    return out, totals


def failing_files(failures, chosen):
    files = set()
    for f in failures:
        m = re.search(r"(test/\S+?_test\.dart)", f["test"])
        if m:
            files.add("App/" + m.group(1))
    return sorted(files) if files else sorted(chosen)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--main", action="store_true", help="check the main checkout, for the files given with --files")
    parser.add_argument("--files", nargs="*", default=[], help="changed files, repo-relative (with --main), or extra ones")
    parser.add_argument("--tests", nargs="*", help="run exactly these test files instead of choosing")
    parser.add_argument("--also", nargs="*", default=[], help="test files to run as well as the ones chosen (the tests that failed before a repair)")
    parser.add_argument("--previews", help="'auto' for the screens the change shows, or a regex of preview names")
    parser.add_argument("--all", action="store_true", help="count everything since the seed, not since the last check")
    parser.add_argument("--max", type=int, default=30, help="test files at most (default 30); the rest are left to the final check")
    parser.add_argument("--max-analyze", type=int, default=80, help="files to analyze before analyzing the whole app")
    parser.add_argument("--no-analyze", action="store_true")
    parser.add_argument("--slots", type=int, help="the gate's slots (default UX_GATE_SLOTS, else 3)")
    parser.add_argument("--list", action="store_true", help="print what would run and why; run nothing")
    parser.add_argument("--json", action="store_true", help="print the summary as JSON")
    args = parser.parse_args()
    if args.main and not args.files and not args.tests and not args.also:
        raise SystemExit("--main needs the changed files (--files) or the tests to run (--tests, --also).")

    ch = Changes(args)
    root = ch.root
    main_checkout = waves.main_root(Path(__file__).resolve().parent)
    graph = Graph(root)
    summary = {"root": str(root), "mode": "main checkout" if ch.main else "worktree", "steps": [], "failures": [],
               "deferred": [], "passed": True, "logs": f"{root.as_posix()}/{LOGS}/"}
    plan = []

    # 1. gen-l10n
    g_paths, _, _ = ch.since("gen")
    if any(ARB.match(p) for p in g_paths) or ch.failed("gen"):
        plan.append(("gen", ["gen-l10n"], {}))

    # 2. the analyzer
    t_paths, t_keys, t_now = ch.since("tests")
    a_paths, a_keys, _ = ch.since("analyze")
    if args.tests is not None:
        tests = [(norm_rel(t, root), "asked for") for t in args.tests]
        rest, shown = [], {}
        analyze = sorted({t for t, _ in tests if t in graph.text} | set(ch.failed("analyze")))
        whole = False
    else:
        also = [norm_rel(t, root) for t in args.also]
        tests, rest, shown = choose_tests(graph, root, t_paths, t_keys, ch.failed("tests") + also, args.max + len(also))
        a_shown, _ = key_users(graph, a_keys)
        analyze, whole = choose_analyze(graph, a_paths, a_shown, ch.failed("analyze"), args.max_analyze)
    if not args.no_analyze and (analyze or whole):
        plan.append(("analyze", ["analyze", "--no-pub", *[short(f) for f in analyze]], {"files": analyze, "whole": whole}))

    # 3. the tests
    if tests:
        plan.append(("tests", ["test", "--no-pub", "--reporter", "expanded", *[short(t) for t, _ in tests]],
                     {"chosen": tests}))
    summary["deferred"] = [{"test": short(t), "why": w} for t, w in rest]
    summary["changed"] = [short(p) for p in t_paths]
    summary["since"] = "the given files" if ch.main else ("the seed" if "prints" not in (ch.state["steps"].get("tests") or {}) else "the last check")
    if t_keys:
        summary["keys"] = sorted(t_keys)[:40]

    # 4. the previews
    if args.previews:
        p_paths, p_keys, p_now = ch.since("previews")
        if args.previews == "auto":
            p_shown, _ = key_users(graph, p_keys)
            names = choose_previews(graph, root, main_checkout, p_paths, p_shown)
            failed_names = ch.failed("previews")
            if names is not None and failed_names:
                names = sorted(set(names) | set(failed_names))
            if names is None:
                plan.append(("previews", ["test", "--no-pub", "--reporter", "expanded", "--dart-define=WRITE_UX_PREVIEWS=true", PREVIEW_TEST],
                             {"names": ["all"], "keys": p_now}))
            elif names:
                plan.append(("previews", ["test", "--no-pub", "--reporter", "expanded", "--dart-define=WRITE_UX_PREVIEWS=true", PREVIEW_TEST,
                                          "--name", preview_regex(names)], {"names": names, "keys": p_now}))
            else:
                plan.append(("previews", None, {"note": "no preview shows what changed (by the Sources in INDEX.md)"}))
        else:
            plan.append(("previews", ["test", "--no-pub", "--reporter", "expanded", "--dart-define=WRITE_UX_PREVIEWS=true", PREVIEW_TEST,
                                      "--name", args.previews], {"names": [args.previews], "keys": p_now}))

    # 5. the native compile check
    n_paths, _, _ = ch.since("native")
    if any(p.startswith("App/android/") for p in n_paths) or ch.failed("native"):
        plan.append(("native", ["build", "apk", "--debug", "--no-pub", "--target-platform", "android-x64"], {}))

    if args.list:
        out = {"root": str(root), "changedSinceSeed" if not ch.main else "files": ch.paths,
               "plan": [{"step": s, "command": "flutter " + " ".join(quote_win(a) for a in cmd) if cmd else extra["note"],
                         **({"tests": [{"test": short(t), "why": w} for t, w in extra["chosen"]]} if s == "tests" else {}),
                         **({"files": len(extra["files"]), "whole": extra["whole"]} if s == "analyze" else {}),
                         **({"previews": extra["names"]} if s == "previews" else {})}
                        for s, cmd, extra in plan],
               "since": "the given files" if ch.main else ("the seed" if "prints" not in (ch.state["steps"].get("tests") or {}) else "the last check"),
               "deferred": summary["deferred"]}
        print(json.dumps(out, ensure_ascii=False, indent=1))
        return 0

    if not [x for x in plan if x[1] is not None]:
        summary["steps"] = [{"step": step, "ran": False, "passed": True, "note": extra["note"]} for step, cmd, extra in plan]
        summary["note"] = "Nothing to run: no change since the last check, and nothing failed in it."
    else:
        with waves.gate_slot(args.slots, "app") as waited:
            summary["gateWaitSeconds"] = round(waited)
            stop = False
            for step, cmd, extra in plan:
                if cmd is None:
                    summary["steps"].append({"step": step, "ran": False, "passed": True, "note": extra["note"]})
                    continue
                if stop:
                    summary["steps"].append({"step": step, "ran": False, "passed": False, "note": "skipped: an earlier step failed"})
                    continue
                code, secs, text = flutter(root, cmd, f"{step}.log")
                entry = {"step": step, "ran": True, "passed": code == 0, "seconds": round(secs), "command": "flutter " + " ".join(quote_win(a) for a in cmd)}
                if step == "gen":
                    if code:
                        entry["error"] = "\n".join(text.strip().splitlines()[-8:])
                        stop = True
                    ch.ran("gen", ["gen"] if code else [], {})
                elif step == "analyze":
                    mine = set(ch.paths)
                    issues = []
                    for line in text.splitlines():
                        m = ISSUE.match(line)
                        if m:
                            sev, msg, path, ln, _, rule = m.groups()
                            rel = "App/" + re.sub(r"^\./", "", path.replace("\\", "/"))
                            issues.append((sev, msg, rel, ln, rule))
                    counted = [i for i in issues if i[0] in ("error", "warning") or i[2] in mine]
                    entry["issues"] = [f"{sev} {short(rel)}:{ln} {msg} ({rule})" for sev, msg, rel, ln, rule in counted][:25]
                    others = len(issues) - len(counted)
                    if others:
                        entry["note"] = f"{others} info(s) in files this change didn't make, not counted"
                    entry["files"] = "the whole app" if extra["whole"] else len(extra["files"])
                    crashed = bool(code) and not issues
                    if crashed:
                        entry["error"] = "\n".join(text.strip().splitlines()[-8:])
                    entry["passed"] = not counted and not crashed
                    if crashed or any(i[0] == "error" for i in issues):
                        stop = True
                    ch.ran("analyze", sorted({i[2] for i in counted}), {})
                elif step == "tests":
                    failures, totals = test_failures(text, root)
                    entry.update({"files": len(extra["chosen"]), "passedTests": totals[0], "failedTests": totals[1], "skipped": totals[2]})
                    entry["chosen"] = [f"{short(t)} ({w})" for t, w in extra["chosen"]]
                    if code and not failures:
                        failures = [{"test": "the test run", "error": "\n".join(text.strip().splitlines()[-10:])}]
                    summary["failures"] += [{"step": "tests", **f} for f in failures]
                    ran_files = [t for t, _ in extra["chosen"]]
                    ch.ran("tests", failing_files(failures, ran_files) if code else [], t_now,
                           advance=args.tests is None, covered=ran_files)
                elif step == "previews":
                    failures, totals = test_failures(text, root)
                    entry.update({"previews": extra["names"], "rendered": totals[0], "failedFlows": totals[1]})
                    if code and not failures and re.search(r"No tests (match|ran|were found)", text):
                        code, entry["passed"] = 0, True
                        entry["note"] = "no preview is named like that: check the names in INDEX.md"
                    if code and not failures:
                        failures = [{"test": "the preview run", "error": "\n".join(text.strip().splitlines()[-10:])}]
                    summary["failures"] += [{"step": "previews", **f} for f in failures]
                    ch.ran("previews", extra["names"] if code and extra["names"] != ["all"] else [], extra["keys"])
                    entry["renders"] = f"{root.as_posix()}/App/build/ux/ (INDEX.md lists them)"
                elif step == "native":
                    if code:
                        entry["error"] = "\n".join(text.strip().splitlines()[-12:])
                    ch.ran("native", ["native"] if code else [], {})
                summary["steps"].append(entry)
        ch.save()
    summary["passed"] = all(s.get("passed", True) for s in summary["steps"])
    if args.json:
        print(json.dumps(summary, ensure_ascii=False, indent=1))
    else:
        report(summary, ch)
    return 0 if summary["passed"] else 1


def report(summary, ch):
    where = "the main checkout" if ch.main else "this worktree"
    say(f"UX check of {where}: {'passed' if summary['passed'] else 'FAILED'}")
    say(f"Changed since {summary['since']}: {', '.join(summary['changed']) or 'nothing'}"
        + (f"; ARB keys {', '.join(summary['keys'])}" if summary.get("keys") else ""))
    if summary.get("note"):
        say(summary["note"])
    if summary.get("gateWaitSeconds"):
        say(f"(waited {summary['gateWaitSeconds']} s for a gate slot)")
    for s in summary["steps"]:
        if not s.get("ran"):
            say(f"- {s['step']}: not run. {s.get('note', '')}")
            continue
        head = f"- {s['step']}: {'ok' if s['passed'] else 'FAILED'} ({s['seconds']} s)"
        if s.get("note"):
            head += f" [{s['note']}]"
        if s["step"] == "analyze":
            head += f", {s['files']} file(s)" if isinstance(s["files"], int) else ", the whole app"
        if s["step"] == "tests":
            head += f", {s['files']} test file(s): {s['passedTests']} passed, {s['failedTests']} failed"
        if s["step"] == "previews":
            head += f": {', '.join(s['previews'])}; {s['rendered']} rendered, {s['failedFlows']} flow(s) failed. Renders: {s['renders']}"
        say(head)
        if s["step"] == "tests":
            for line in s["chosen"]:
                say(f"    {line}")
        for issue in s.get("issues", []):
            say(f"    {issue}")
        if s.get("error"):
            say("    " + s["error"].replace("\n", "\n    "))
    for f in summary["failures"]:
        say(f"FAILED ({f['step']}): {f['test']}")
        if f.get("error"):
            say("    " + f["error"].replace("\n", "\n    "))
    if summary["deferred"]:
        say(f"Left to the run's final check ({len(summary['deferred'])} more test file(s) cover this change): "
            + ", ".join(d["test"] for d in summary["deferred"]))
    say(f"Full logs: {summary['logs']}")


if __name__ == "__main__":
    sys.exit(main())
