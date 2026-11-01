"""Parallel packages for the UX loop: seed a worktree with the run so far, then merge it back.

ux-fix runs every package in its own git worktree (the workflow's `isolation: 'worktree'`), as
many at once as the machine allows. A worktree starts from HEAD, but a run's changes are
uncommitted until the run is verified, so:

  seed   (run by the implementer, from its worktree's root, before anything else)
         copies the run's changed files and its context (DECISIONS.md, ISSUES.md, the run
         folder) from the main checkout, records that state as the worktree's "seed" commit
         (git commit-tree: no ref moves, no hooks), and runs flutter pub get. A worktree is
         seeded once: a second seed does nothing, so it can't wipe the package's work.
  merge  (run by the workflow's merge step, from anywhere)
         takes each worktree's changes since its seed and applies them to the main checkout
         with a three-way merge: ARB files key by key, other text files with git merge-file.
         A package whose changes conflict is applied not at all, and keeps its worktree so an
         implementer can carry it into a fresh worktree by hand (carry, then drop). Generated
         l10n files are never merged: gen-l10n runs once at the end. A package that fails in
         any other way is reported with its error; the others still merge. --shelve saves a
         package's patch to --patches and removes its worktree, without merging it.
         Then the merged worktrees and their branches are removed.
  carry  (run by an integrator, from a fresh worktree it has just seeded) brings a conflicted
         package's changes over from its old worktree, file by file, with three-way merges.
         Clean files are written; conflicting ones get conflict markers to resolve by hand.
  gate   runs a heavy command (Flutter, a build) when one of N machine-wide slots is free,
         so many implementers can work at once while only N compile.

Seeds and merges take one lock in the main repo's git folder, so a seed never copies a
half-merged main checkout.

The website's loop has its own copy, with the website's copies and build mirrors:
../TaskFlowWeb/.claude/skills/ux-web/scripts/waves.py.

Usage:
  python -I -X utf8 .claude/skills/ux/scripts/waves.py seed --run <runDir> [--files <path> ...] [--no-pub] [--force]
  python -I -X utf8 .claude/skills/ux/scripts/waves.py merge --worktree <id>=<path> [...] [--shelve <id>=<path> ...]
                    [--patches <dir>] [--log <file>] [--no-gen] [--keep]
  python -I -X utf8 .claude/skills/ux/scripts/waves.py carry --from <old worktree>
  python -I -X utf8 .claude/skills/ux/scripts/waves.py gate [--slots N] -- <heavy command>
  python -I -X utf8 .claude/skills/ux/scripts/waves.py diff --worktree <path>    (a package's patch since its seed)
  python -I -X utf8 .claude/skills/ux/scripts/waves.py drop --worktree <path> [--save <patch>]
Paths are relative to the repo root. merge and carry print one JSON object.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from contextlib import contextmanager
from pathlib import Path

GENERATED = "App/lib/l10n/generated/"
CONTEXT = [".claude/ux-review/DECISIONS.md", ".claude/ux-review/ISSUES.md"]
# Never merged back: the loop's own records belong to the organizer, and build output is local.
NOT_MERGED = (".claude/", "App/build/", "App/.dart_tool/", "App/artifacts/")
SEED_FILE = "UX_WAVES_SEED"
# An untracked file at a seeded worktree's root. It's part of the seed, so it's never merged,
# but it keeps the worktree from looking unchanged: the workflow engine removes an unchanged
# worktree when its agent ends, before the package's tester and reviewer can work there.
MARKER = ".ux-waves-seeded"


def git(cwd, *args, check=True, binary=False):
    result = subprocess.run(["git", "-C", str(cwd), *args], capture_output=True)
    if check and result.returncode != 0:
        raise SystemExit(f"git {' '.join(args)} failed in {cwd}: {result.stderr.decode('utf-8', 'replace').strip()}")
    return result.stdout if binary else result.stdout.decode("utf-8", "replace").strip()


def main_root(cwd):
    common = Path(git(cwd, "rev-parse", "--path-format=absolute", "--git-common-dir"))
    return common.parent


def try_lock(f):
    """Takes an exclusive lock on an open file without waiting. The OS releases it if the
    process dies."""
    try:
        if os.name == "nt":
            import msvcrt
            f.seek(0)
            msvcrt.locking(f.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(f.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        return True
    except OSError:
        return False


@contextmanager
def repo_lock(main, timeout=900):
    """One seed or merge at a time in the main checkout: merges write it, seeds copy it."""
    common = Path(git(main, "rev-parse", "--path-format=absolute", "--git-common-dir"))
    f = open(common / "ux-waves.lock", "a+b")
    waited = 0.0
    try:
        while not try_lock(f):
            if waited >= timeout:
                raise SystemExit(f"waited {timeout} s for {common / 'ux-waves.lock'}: another seed or merge is stuck")
            time.sleep(0.5)
            waited += 0.5
        yield
    finally:
        f.close()


def seed_of(wt):
    """The worktree's seed commit, or None if it was never seeded."""
    gitdir = Path(git(wt, "rev-parse", "--path-format=absolute", "--git-dir"))
    path = gitdir / SEED_FILE
    return path.read_text(encoding="utf-8").strip() if path.is_file() else None


def lf(data):
    return None if data is None else data.replace(b"\r\n", b"\n")


def read(path):
    return path.read_bytes() if path.is_file() else None


def write(path, data, like):
    """Writes data (LF) with the line endings of `like`, the file it replaces."""
    if data is None:
        if path.exists():
            path.unlink()
        return
    if like is not None and b"\r\n" in like:
        data = data.replace(b"\n", b"\r\n")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


# ---------------------------------------------------------------- seed

def run_changes(main):
    """The uncommitted files in the main checkout: what the run (and anyone else) changed since
    HEAD. In the app, App/config holds secrets and is never copied; in the website, .env files
    are ignored by git and never listed."""
    if (main / "App").is_dir():
        tracked = git(main, "diff", "--name-only", "HEAD", "--", "App").splitlines()
        untracked = git(main, "ls-files", "--others", "--exclude-standard", "--",
                        "App/lib", "App/test", "App/assets", "App/android/app/src", "App/ios/Runner").splitlines()
        return {p for p in tracked + untracked if p and not p.startswith(("App/config/", "App/build/", "App/.dart_tool/"))}
    tracked = git(main, "diff", "--name-only", "HEAD").splitlines()
    untracked = git(main, "ls-files", "--others", "--exclude-standard", "--", "src", "tests", "public", "scripts").splitlines()
    return {p for p in tracked + untracked if p}


def seed_worktree(wt, main, files=(), run=None, pub=False, force=False):
    """Copies the main checkout's uncommitted state into the worktree and records it as the seed.
    Returns None, changing nothing, if the worktree was seeded already (unless force)."""
    if wt.resolve() == main.resolve():
        raise SystemExit("seed runs in a worktree, never in the main checkout.")
    gitdir = Path(git(wt, "rev-parse", "--path-format=absolute", "--git-dir"))
    if (gitdir / SEED_FILE).is_file() and not force:
        return None
    copied, removed = [], []
    with repo_lock(main):
        # The workflow engine makes a worktree from the repo's default branch (main), not from the
        # branch the main checkout is on (dev): on 2026-10-22 that left a whole wave without the
        # code it was meant to change. Start from the main checkout's commit, before anything else.
        # A reset keeps the worktree's own throwaway branch, which drop removes afterwards.
        base = git(main, "rev-parse", "HEAD")
        if git(wt, "rev-parse", "HEAD") != base:
            git(wt, "reset", "--hard", "--quiet", base)
        context = set(CONTEXT) if (main / ".claude" / "ux-review").is_dir() else set()
        for rel in sorted(set(files or []) | run_changes(main) | context):
            src, dst = main / rel, wt / rel
            if src.is_file():
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(src, dst)
                copied.append(rel)
            elif dst.is_file():
                dst.unlink()  # deleted earlier in the run
                removed.append(rel)
        if run and (main / run).is_dir():
            shutil.copytree(main / run, wt / run, dirs_exist_ok=True)
            copied.append(run + "/")
    (wt / MARKER).write_text(f"Seeded from {main} at {base}.\n", encoding="utf-8")
    git(wt, "add", "-A")
    tree = git(wt, "write-tree")
    head = git(wt, "rev-parse", "HEAD")
    commit = git(wt, "commit-tree", tree, "-p", head, "-m", "UX loop seed: the run so far")
    (gitdir / SEED_FILE).write_text(commit, encoding="utf-8")
    note = "skipped"
    if pub and (wt / "App" / "pubspec.yaml").is_file():
        app = wt / "App"
        flutter = shutil.which("flutter") or "flutter"
        result = subprocess.run([flutter, "pub", "get", "--offline"], cwd=app, capture_output=True, shell=os.name == "nt")
        if result.returncode != 0:
            result = subprocess.run([flutter, "pub", "get"], cwd=app, capture_output=True, shell=os.name == "nt")
        note = "ok" if result.returncode == 0 else "failed: " + result.stderr.decode("utf-8", "replace")[-400:]
    return copied, removed, commit, note


def seed(args):
    wt = Path(git(Path.cwd(), "rev-parse", "--show-toplevel"))
    main = main_root(wt)
    done = seed_worktree(wt, main, args.files, args.run, pub=not args.no_pub, force=args.force)
    if done is None:
        print(f"{wt} was seeded already (seed {seed_of(wt)[:10]}); nothing changed. Keep working here.")
        return
    copied, removed, commit, note = done
    print(f"Seeded {wt} from {main}: {len(copied)} copied, {len(removed)} removed; seed {commit[:10]}; pub get {note}.")
    print("Work here only. Your changes are measured from this seed; don't commit, stage or reset.")


# ---------------------------------------------------------------- merge

MISSING = object()


def merge_arb(base, ours, theirs, prefer_theirs=False):
    """Three-way merge of ARB files, key by key. Returns (bytes, conflicting keys). With
    prefer_theirs, a key changed both ways takes theirs (the package's) and is still listed."""
    b = json.loads(base) if base else {}
    o = json.loads(ours) if ours else {}
    t = json.loads(theirs) if theirs else {}
    result = dict(o)
    conflicts = []
    for key in dict.fromkeys([*b, *t]):
        bk, tk, ok = b.get(key, MISSING), t.get(key, MISSING), o.get(key, MISSING)
        if tk == bk or ok == tk:
            continue
        if ok == bk or prefer_theirs:
            if tk is MISSING:
                result.pop(key, None)
            else:
                result[key] = tk
        if ok != bk:
            conflicts.append(key)
    # Keys new to ours go next to their neighbour in theirs, as the implementer placed them,
    # after any keys another package already put there.
    order = [k for k in o if k in result]
    theirs_order = list(t)
    for i, key in enumerate(theirs_order):
        if key in result and key not in order:
            before = next((k for k in reversed(theirs_order[:i]) if k in order), None)
            at = order.index(before) + 1 if before else len(order)
            while at < len(order) and order[at] not in b and order[at] not in t:
                at += 1
            order.insert(at, key)
    order += [k for k in result if k not in order]
    text = json.dumps({k: result[k] for k in order}, indent=2, ensure_ascii=False) + "\n"
    return text.encode("utf-8"), conflicts


def only_insertions(diff3):
    """True when every conflict in a --diff3 merge has an empty base: both sides only added
    lines at the same place, such as two test groups appended to one file."""
    state, base_lines, seen = None, 0, False
    for line in diff3.split(b"\n"):
        if line.startswith(b"<<<<<<< "):
            state, base_lines, seen = "ours", 0, True
        elif line.startswith(b"||||||| ") and state == "ours":
            state = "base"
        elif line.startswith(b"=======") and state == "base":
            if base_lines:
                return False
            state = "theirs"
        elif line.startswith(b">>>>>>> ") and state == "theirs":
            state = None
        elif state == "base":
            base_lines += 1
    return seen and state is None


def merge_text(base, ours, theirs, marked=False, union=True):
    """Three-way merge with git merge-file. Two insertions at the same place keep both, ours
    first (unless union is False). Returns (bytes or None, conflict note). With marked, a
    conflict returns the text with diff3 conflict markers instead of None."""
    with tempfile.TemporaryDirectory() as tmp:
        paths = []
        for name, data in (("ours", ours), ("base", base), ("theirs", theirs)):
            p = Path(tmp) / name
            p.write_bytes(data or b"")
            paths.append(str(p))
        result = subprocess.run(["git", "merge-file", "-p", *paths], capture_output=True)
        if result.returncode == 0:
            return result.stdout, None
        if result.returncode < 0:
            return None, "merge-file failed"
        diff3 = subprocess.run(["git", "merge-file", "-p", "--diff3", *paths], capture_output=True).stdout
        if union and only_insertions(diff3):
            both = subprocess.run(["git", "merge-file", "-p", "--union", *paths], capture_output=True)
            if both.returncode == 0:
                return both.stdout, None
        if marked:
            labels = ["-L", "main checkout now", "-L", "the package's seed", "-L", "the package"]
            text = subprocess.run(["git", "merge-file", "-p", "--diff3", *labels, *paths], capture_output=True).stdout
            return text, f"{result.returncode} conflicting hunk(s), marked"
        return None, f"{result.returncode} conflicting hunk(s)"


# ---------------------------------------------------------------- gate

@contextmanager
def gate_slot(slots=None, pool="app"):
    """Holds one of the machine's slots for heavy commands (Flutter, a build) while the block
    runs, so many implementers can think and edit in parallel while only a few compile at a
    time. A slot is a lock on a file in the main repo's git folder; the OS releases it if the
    process dies. A process the gate started (UX_GATE_HELD names its pool) holds a slot already."""
    slots = max(1, int(slots or os.environ.get("UX_GATE_SLOTS") or 3))
    # One pool per loop and repo; the website's loop keeps its own, in its own repo.
    pool = re.sub(r"[^a-z0-9-]", "", (pool or "app").lower()) or "app"
    if os.environ.get("UX_GATE_HELD") == pool:
        yield 0.0
        return
    common = git(Path(__file__).resolve().parent, "rev-parse", "--path-format=absolute", "--git-common-dir")
    lock_dir = Path(common) / f"ux-gate-{pool}"  # the main repo's .git, from any of its worktrees
    lock_dir.mkdir(parents=True, exist_ok=True)
    handle, waited, said = None, 0.0, False
    while handle is None:
        for i in range(slots):
            f = open(lock_dir / f"slot-{i}.lock", "a+b")
            if try_lock(f):
                handle = f
                break
            f.close()
        if handle is None:
            if not said:
                print(f"[gate] all {slots} slots busy; waiting", file=sys.stderr, flush=True)
                said = True
            time.sleep(2)
            waited += 2
    if waited:
        print(f"[gate] waited {waited:.0f} s for a slot", file=sys.stderr, flush=True)
    previous = os.environ.get("UX_GATE_HELD")
    os.environ["UX_GATE_HELD"] = pool
    try:
        yield waited
    finally:
        if previous is None:
            os.environ.pop("UX_GATE_HELD", None)
        else:
            os.environ["UX_GATE_HELD"] = previous
        handle.close()


def gate(args):
    """Runs a heavy command once one of the machine's slots is free (gate_slot)."""
    command = args.argv
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        raise SystemExit("gate needs a command after --")
    with gate_slot(args.slots, args.pool):
        if len(command) == 1:  # one command line, for the shell
            return subprocess.run(command[0], shell=True).returncode
        exe = shutil.which(command[0]) or command[0]
        return subprocess.run([exe, *command[1:]]).returncode


class NotSeeded(Exception):
    pass


def changes(wt):
    """The worktree's seed and the paths it changed since, after staging them in its own index."""
    seed_commit = seed_of(wt)
    if not seed_commit:
        raise NotSeeded(f"{wt} was never seeded (no {SEED_FILE}): its changes have no known base.")
    git(wt, "add", "-A")
    listed = git(wt, "diff", "--cached", "--name-only", "--no-renames", seed_commit)
    return seed_commit, [p for p in listed.splitlines() if p]


def three_way(target, wt, seed_commit, paths, marked=False):
    """Plans bringing the package in `wt` (changed `paths` since `seed_commit`) onto `target`.
    Returns (writes, conflicts, ignored, arb keys taken from the package). With marked, a
    conflicting text file is still written, with conflict markers, and ARB keys changed both
    ways take the package's value."""
    writes, conflicts, ignored, keys_taken = [], [], [], []
    for rel in paths:
        if rel.startswith(NOT_MERGED) or rel.startswith(GENERATED) or rel == MARKER:
            ignored.append(rel)
            continue
        shown = subprocess.run(["git", "-C", str(wt), "show", f"{seed_commit}:{rel}"], capture_output=True)
        base = lf(shown.stdout) if shown.returncode == 0 else None
        theirs = lf(read(wt / rel))
        ours_raw = read(target / rel)
        ours = lf(ours_raw)
        if ours == base:
            writes.append((rel, theirs, ours_raw))
        elif ours == theirs:
            continue
        elif rel.endswith(".arb") and base is not None and theirs is not None and ours is not None:
            merged, keys = merge_arb(base, ours, theirs, prefer_theirs=marked)
            if keys and not marked:
                conflicts.append({"path": rel, "why": "keys changed both ways: " + ", ".join(keys[:8])})
            else:
                writes.append((rel, merged, ours_raw))
                keys_taken += keys
        elif base is None or theirs is None or ours is None:
            if marked and theirs is not None:
                # Added on both sides, or deleted in the main checkout: never a silent union.
                merged, why = merge_text(base or b"", ours or b"", theirs, marked=True, union=False)
                writes.append((rel, merged, ours_raw))
                if why:
                    conflicts.append({"path": rel, "why": ("added on both sides: " if base is None else "deleted in the main checkout: ") + why})
            else:
                conflicts.append({"path": rel, "why": "added or deleted on both sides"})
        else:
            merged, why = merge_text(base, ours, theirs, marked=marked)
            if merged is not None and (marked or not why):
                writes.append((rel, merged, ours_raw))
            if why:
                conflicts.append({"path": rel, "why": why})
    return writes, conflicts, ignored, keys_taken


def pairs_of(items, flag):
    out = []
    for item in items or []:
        pid, _, path = item.partition("=")
        if not path:
            raise SystemExit(f"{flag} takes <id>=<path>, not {item!r}")
        out.append((pid, Path(path)))
    return out


def save_patch(wt, path):
    """Writes the package's changes since its seed to `path`. Returns a note."""
    seed_commit, paths = changes(wt)
    keep = [p for p in paths if not p.startswith(NOT_MERGED) and not p.startswith(GENERATED) and p != MARKER]
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    patch = git(wt, "diff", "--cached", "--no-renames", "--binary", seed_commit, "--", *keep) if keep else ""
    path.write_text(patch + ("\n" if patch else ""), encoding="utf-8")
    return f"{len(keep)} file(s)"


def merge(args):
    pairs = pairs_of(args.worktree, "--worktree")
    shelves = pairs_of(args.shelve, "--shelve")
    if not pairs and not shelves:
        raise SystemExit("merge needs --worktree <id>=<path> or --shelve <id>=<path>")
    # The main checkout is the one this script belongs to, never a worktree's: a worktree that
    # is gone, or was never seeded, can't tell us where it came from.
    main = main_root(Path(__file__).resolve().parent)
    report = {"main": str(main), "packages": [], "shelved": [], "arbChanged": False, "genL10n": "not needed", "removed": []}
    with repo_lock(main):
        for pid, wt in pairs:
            entry = {"id": pid, "worktree": str(wt), "applied": [], "conflicts": [], "ignored": []}
            report["packages"].append(entry)
            try:
                if not wt.is_dir():
                    entry["gone"] = True
                    done = merged_before(main, wt)
                    if done is not None:
                        # Merged by an earlier merge (a resumed run asks again): the same answer.
                        entry["alreadyMerged"] = True
                        entry["applied"] = done.get("applied", [])
                    # Otherwise the engine removed a worktree its agent left unchanged: nothing to merge.
                    continue
                seed_commit, paths = changes(wt)
                writes, conflicts, ignored, _ = three_way(main, wt, seed_commit, paths)
                entry["ignored"] = ignored
                if conflicts:
                    entry["conflicts"] = conflicts
                    continue  # all or nothing: the package is carried over by hand
                for rel, data, like in writes:
                    write(main / rel, data, like)
                    entry["applied"].append(rel)
                    if rel.endswith(".arb"):
                        report["arbChanged"] = True
            except NotSeeded as e:
                entry["error"] = str(e)
            except (SystemExit, Exception) as e:  # git failures raise SystemExit
                entry["error"] = f"{type(e).__name__}: {e}"
        if report["arbChanged"] and not args.no_gen:
            flutter = shutil.which("flutter") or "flutter"
            result = subprocess.run([flutter, "gen-l10n"], cwd=main / "App", capture_output=True, shell=os.name == "nt")
            report["genL10n"] = "ok" if result.returncode == 0 else "failed: " + result.stderr.decode("utf-8", "replace")[-400:]
    for pid, wt in shelves:
        entry = {"id": pid, "worktree": str(wt), "patch": "", "removed": False}
        report["shelved"].append(entry)
        try:
            if wt.is_dir():
                if args.patches:
                    patch = Path(args.patches) / f"unmerged-{pid}.patch"
                    try:
                        entry["note"] = save_patch(wt, patch)
                        entry["patch"] = str(patch)
                    except NotSeeded as e:
                        entry["note"] = f"no patch: {e}"
                entry["removed"] = drop_worktree(main, wt)
        except (SystemExit, Exception) as e:
            entry["error"] = f"{type(e).__name__}: {e}"
    # A package that conflicted or failed keeps its worktree, so it can be carried over by hand.
    for (pid, wt), entry in zip(pairs, report["packages"]):
        if wt.is_dir() and not entry["conflicts"] and "error" not in entry:
            remember_merge(main, wt, pid, entry["applied"])
            if not args.keep and drop_worktree(main, wt):
                report["removed"].append(str(wt))
    if args.log:
        try:
            Path(args.log).parent.mkdir(parents=True, exist_ok=True)
            with open(args.log, "a", encoding="utf-8") as fh:
                fh.write(json.dumps({"at": time.strftime("%Y-%m-%dT%H:%M:%S"), **report}, ensure_ascii=False) + "\n")
        except OSError as e:
            report["log"] = f"not written: {e}"
    print(json.dumps(report, ensure_ascii=False, indent=1))


def tombstone(main, wt):
    common = Path(git(main, "rev-parse", "--path-format=absolute", "--git-common-dir"))
    return common / "ux-waves-merged" / (Path(wt).name + ".json")


def remember_merge(main, wt, pid, applied):
    """Leaves a note that this worktree was merged, so merging it again, once it's gone, gives
    the same answer instead of "nothing to merge"."""
    path = tombstone(main, wt)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"id": pid, "worktree": str(wt), "applied": applied,
                                "at": time.strftime("%Y-%m-%dT%H:%M:%S")}, ensure_ascii=False), encoding="utf-8")


def merged_before(main, wt):
    path = tombstone(main, wt)
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except ValueError:
        return {}


def carry(args):
    """Brings a conflicted package over from its old worktree into this fresh, seeded one."""
    wt = Path(git(Path.cwd(), "rev-parse", "--show-toplevel"))
    old = Path(args.source)
    if not seed_of(wt):
        raise SystemExit("Seed this worktree first (waves.py seed), then carry.")
    if wt.resolve() == old.resolve():
        raise SystemExit("carry brings a package from its old worktree into a new one, not into itself.")
    seed_commit, paths = changes(old)
    writes, conflicts, ignored, keys = three_way(wt, old, seed_commit, paths, marked=True)
    for rel, data, like in writes:
        write(wt / rel, data, like)
    report = {
        "from": str(old),
        "into": str(wt),
        "applied": [rel for rel, _, _ in writes if rel not in {c["path"] for c in conflicts}],
        "conflicts": conflicts,
        "arbKeysTakenFromPackage": keys,
        "ignored": ignored,
        "next": "Resolve every conflict marker in the files under conflicts (keep both packages' intent), then run gen-l10n if an ARB changed, the analyzer and the tests.",
    }
    print(json.dumps(report, ensure_ascii=False, indent=1))


def drop_worktree(main, wt):
    branch = git(wt, "symbolic-ref", "-q", "--short", "HEAD", check=False)
    removed = subprocess.run(["git", "-C", str(main), "worktree", "remove", "--force", str(wt)], capture_output=True)
    if removed.returncode != 0:
        return False
    # The engine's throwaway branches: worktree-agent-* (Agent tool) and worktree-wf_* (workflows).
    if branch.startswith(("worktree-agent-", "worktree-wf_")):
        git(main, "branch", "-D", branch, check=False)
    return True


def show_diff(args):
    """The package's own changes since its seed, as one patch."""
    wt = Path(args.worktree)
    try:
        seed_commit, paths = changes(wt)
    except NotSeeded as e:
        raise SystemExit(str(e))
    keep = [p for p in paths if not p.startswith(NOT_MERGED) and not p.startswith(GENERATED) and p != MARKER]
    if not keep:
        print("(no changes)")
        return
    sys.stdout.write(git(wt, "diff", "--cached", "--no-renames", seed_commit, "--", *keep))
    print()


def drop(args):
    wt = Path(args.worktree)
    if not wt.is_dir():
        print(f"{wt} is already gone.")
        return
    main = main_root(wt)
    if args.save:
        try:
            print(f"Saved {save_patch(wt, args.save)} to {args.save}.")
        except (NotSeeded, SystemExit) as e:
            print(f"Could not save the patch: {e}")
    print(f"Removed {wt}." if drop_worktree(main, wt) else f"Could not remove {wt}.")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="action", required=True)
    s = sub.add_parser("seed")
    s.add_argument("--run", help="the run folder, relative to the repo root")
    s.add_argument("--files", nargs="*", default=[], help="files the run has changed so far")
    s.add_argument("--no-pub", action="store_true")
    s.add_argument("--force", action="store_true", help="seed again, discarding the worktree's changes")
    m = sub.add_parser("merge")
    m.add_argument("--worktree", action="append", default=[], help="<package id>=<worktree path>, to merge")
    m.add_argument("--shelve", action="append", default=[], help="<package id>=<worktree path>, to save and remove unmerged")
    m.add_argument("--patches", help="where --shelve saves unmerged-<id>.patch (the run folder)")
    m.add_argument("--log", help="a JSON-lines file to append this merge's report to")
    m.add_argument("--no-gen", action="store_true")
    m.add_argument("--keep", action="store_true", help="keep the worktrees")
    c = sub.add_parser("carry", help="bring a conflicted package's changes into this fresh, seeded worktree")
    c.add_argument("--from", dest="source", required=True, help="the package's old worktree")
    g = sub.add_parser("gate")
    g.add_argument("--slots", type=int, help="heavy commands at once (default UX_GATE_SLOTS, else 3)")
    g.add_argument("--pool", default="app", help="the slots' pool (default app: Flutter on Windows)")
    g.add_argument("argv", nargs=argparse.REMAINDER, help="-- <command>, or one quoted command line")
    d = sub.add_parser("diff", help="a package's changes since its seed")
    d.add_argument("--worktree", required=True)
    r = sub.add_parser("drop", help="remove a worktree and its worktree-agent-* branch")
    r.add_argument("--worktree", required=True)
    r.add_argument("--save", help="first save its changes since the seed to this patch file")
    args = parser.parse_args()
    if args.action == "gate":
        return gate(args)
    {"seed": seed, "merge": merge, "carry": carry, "diff": show_diff, "drop": drop}[args.action](args)


if __name__ == "__main__":
    sys.exit(main())
