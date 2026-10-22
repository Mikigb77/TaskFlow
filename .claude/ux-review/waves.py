"""Parallel implementers for the UX loop: seed a worktree with the run so far, then merge it back.

ux-fix runs packages that share no file side by side, each ux-implementer in its own git
worktree (the workflow's `isolation: 'worktree'`). A worktree starts from HEAD, but a run's
changes are uncommitted until the round is verified, so:

  seed   (run by the implementer, from its worktree's root, before anything else)
         copies the run's changed files and its context (DECISIONS.md, ISSUES.md, the run
         folder) from the main checkout, records that state as the worktree's "seed" commit
         (git commit-tree: no ref moves, no hooks), and runs flutter pub get.
  merge  (run by the main session's merge step, from anywhere)
         takes each worktree's changes since its seed and applies them to the main checkout
         with a three-way merge: ARB files key by key, other text files with git merge-file.
         A package whose changes conflict is applied not at all, and keeps its worktree so an
         implementer can integrate it by hand (diff, then drop). Generated l10n files are never merged: gen-l10n runs once at the end.
         Then the worktrees and their worktree-agent-* branches are removed.
  gate   runs a heavy command (Flutter, a build) when one of N machine-wide slots is free,
         so many implementers can work at once while only N compile.

Usage:
  python -I -X utf8 .claude/ux-review/waves.py seed --run <runDir> [--files <path> ...] [--no-pub]
  python -I -X utf8 .claude/ux-review/waves.py merge --worktree <id>=<path> [...] [--no-gen] [--keep]
  python -I -X utf8 .claude/ux-review/waves.py gate [--pool app|web] [--slots N] -- <heavy command>
  python -I -X utf8 .claude/ux-review/waves.py add --repo <website> --name <copy>    (a website copy, seeded)
  python -I -X utf8 .claude/ux-review/waves.py diff --worktree <path>    (a conflicted package's patch)
  python -I -X utf8 .claude/ux-review/waves.py drop --worktree <path>    (remove it once integrated)
Paths are relative to the repo root. merge prints one JSON object.
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
from pathlib import Path

GENERATED = "App/lib/l10n/generated/"
CONTEXT = [".claude/ux-review/DECISIONS.md", ".claude/ux-review/ISSUES.md"]
# Never merged back: the loop's own records belong to the organizer, and build output is local.
NOT_MERGED = (".claude/", "App/build/", "App/.dart_tool/", "App/artifacts/")
SEED_FILE = "UX_WAVES_SEED"


def git(cwd, *args, check=True, binary=False):
    result = subprocess.run(["git", "-C", str(cwd), *args], capture_output=True)
    if check and result.returncode != 0:
        raise SystemExit(f"git {' '.join(args)} failed in {cwd}: {result.stderr.decode('utf-8', 'replace').strip()}")
    return result.stdout if binary else result.stdout.decode("utf-8", "replace").strip()


def main_root(cwd):
    common = Path(git(cwd, "rev-parse", "--path-format=absolute", "--git-common-dir"))
    return common.parent


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


def seed_worktree(wt, main, files=(), run=None, pub=False):
    """Copies the main checkout's uncommitted state into the worktree and records it as the seed."""
    if wt.resolve() == main.resolve():
        raise SystemExit("seed runs in a worktree, never in the main checkout.")
    # The workflow engine makes a worktree from the repo's default branch (main), not from the
    # branch the main checkout is on (dev): on 2026-10-22 that left a whole wave without the
    # code it was meant to change. Start from the main checkout's commit, before anything else.
    # A reset keeps the worktree's own throwaway branch, which drop removes afterwards.
    base = git(main, "rev-parse", "HEAD")
    if git(wt, "rev-parse", "HEAD") != base:
        git(wt, "reset", "--hard", "--quiet", base)
    copied, removed = [], []
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
    git(wt, "add", "-A")
    tree = git(wt, "write-tree")
    head = git(wt, "rev-parse", "HEAD")
    commit = git(wt, "commit-tree", tree, "-p", head, "-m", "UX loop seed: the run so far")
    gitdir = Path(git(wt, "rev-parse", "--path-format=absolute", "--git-dir"))
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
    copied, removed, commit, note = seed_worktree(wt, main, args.files, args.run, pub=not args.no_pub)
    print(f"Seeded {wt} from {main}: {len(copied)} copied, {len(removed)} removed; seed {commit[:10]}; pub get {note}.")
    print("Work here only. Your changes are measured from this seed; don't commit, stage or reset.")


COPIES = Path.home() / ".taskflow-tools" / "wt"


def wsl_path(path):
    text = str(path).replace("\\", "/")
    return re.sub(r"^([A-Za-z]):/", lambda m: f"/mnt/{m.group(1).lower()}/", text)


def add(args):
    """A worktree of another repo (the website), outside both repos, seeded like seed does."""
    repo = Path(args.repo)
    main = main_root(repo)
    name = re.sub(r"[^A-Za-z0-9._-]", "", args.name)
    wt = COPIES / name
    if wt.exists():
        subprocess.run(["git", "-C", str(main), "worktree", "remove", "--force", str(wt)], capture_output=True)
        shutil.rmtree(wt, ignore_errors=True)
        git(main, "worktree", "prune")
    COPIES.mkdir(parents=True, exist_ok=True)
    git(main, "worktree", "add", "--detach", str(wt), "HEAD")
    copied, removed, commit, _ = seed_worktree(wt, main, args.files)
    print(json.dumps({"worktree": str(wt).replace("\\", "/"), "wsl": wsl_path(wt), "name": name,
                      "seeded": len(copied), "seed": commit[:10]}))


def remove_mirror(wt):
    """A website copy's build mirror on WSL's disk (webrun.py), best effort."""
    if COPIES not in Path(wt).resolve().parents:
        return
    webrun = Path(__file__).resolve().parents[1] / "ux-web" / "webrun.py"
    subprocess.run(["wsl", "-e", "python3", wsl_path(webrun), "--remove", Path(wt).name], capture_output=True)


# ---------------------------------------------------------------- merge

MISSING = object()


def merge_arb(base, ours, theirs):
    """Three-way merge of ARB files, key by key. Returns (bytes, conflicting keys)."""
    b = json.loads(base) if base else {}
    o = json.loads(ours) if ours else {}
    t = json.loads(theirs) if theirs else {}
    result = dict(o)
    conflicts = []
    for key in dict.fromkeys([*b, *t]):
        bk, tk, ok = b.get(key, MISSING), t.get(key, MISSING), o.get(key, MISSING)
        if tk == bk or ok == tk:
            continue
        if ok == bk:
            if tk is MISSING:
                result.pop(key, None)
            else:
                result[key] = tk
        else:
            conflicts.append(key)
    # Keys new to ours go next to their neighbour in theirs, as the implementer placed them,
    # after any keys another package of this wave already put there.
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


def merge_text(base, ours, theirs):
    """Three-way merge with git merge-file. Two insertions at the same place keep both, ours
    first. Returns (bytes or None, conflict note)."""
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
        if only_insertions(diff3):
            union = subprocess.run(["git", "merge-file", "-p", "--union", *paths], capture_output=True)
            if union.returncode == 0:
                return union.stdout, None
        return None, f"{result.returncode} conflicting hunk(s)"


# ---------------------------------------------------------------- gate

def gate(args):
    """Runs a heavy command (Flutter, a build) once one of the machine's slots is free, so many
    implementers can think and edit in parallel while only a few compile at a time. A slot is
    a lock on a file in the main repo's git folder; the OS releases it if the process dies."""
    command = args.argv
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        raise SystemExit("gate needs a command after --")
    slots = max(1, int(args.slots or os.environ.get("UX_GATE_SLOTS") or 3))
    # One pool per loop: the app's Flutter runs on Windows, the website's builds in WSL.
    pool = re.sub(r"[^a-z0-9-]", "", (args.pool or "app").lower()) or "app"
    lock_dir = Path(__file__).resolve().parents[2] / ".git" / f"ux-gate-{pool}"
    lock_dir.mkdir(parents=True, exist_ok=True)
    handle, waited, said = None, 0.0, False
    while handle is None:
        for i in range(slots):
            f = open(lock_dir / f"slot-{i}.lock", "a+b")
            try:
                if os.name == "nt":
                    import msvcrt
                    f.seek(0)
                    msvcrt.locking(f.fileno(), msvcrt.LK_NBLCK, 1)
                else:
                    import fcntl
                    fcntl.flock(f.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                handle = f
                break
            except OSError:
                f.close()
        if handle is None:
            if not said:
                print(f"[gate] all {slots} slots busy; waiting", file=sys.stderr, flush=True)
                said = True
            time.sleep(2)
            waited += 2
    if waited:
        print(f"[gate] waited {waited:.0f} s for a slot", file=sys.stderr, flush=True)
    try:
        if len(command) == 1:  # one command line, for the shell
            return subprocess.run(command[0], shell=True).returncode
        exe = shutil.which(command[0]) or command[0]
        return subprocess.run([exe, *command[1:]]).returncode
    finally:
        handle.close()


def changes(wt):
    gitdir = Path(git(wt, "rev-parse", "--path-format=absolute", "--git-dir"))
    seed_path = gitdir / SEED_FILE
    if not seed_path.is_file():
        raise SystemExit(f"{wt} was never seeded (no {SEED_FILE}).")
    seed_commit = seed_path.read_text(encoding="utf-8").strip()
    git(wt, "add", "-A")
    listed = git(wt, "diff", "--cached", "--name-only", "--no-renames", seed_commit)
    return seed_commit, [p for p in listed.splitlines() if p]


def merge(args):
    pairs = []
    for item in args.worktree:
        pid, _, path = item.partition("=")
        if not path:
            raise SystemExit(f"--worktree takes <id>=<path>, not {item!r}")
        pairs.append((pid, Path(path)))
    main = main_root(pairs[0][1])
    report = {"main": str(main), "packages": [], "arbChanged": False, "genL10n": "not needed", "removed": []}
    for pid, wt in pairs:
        entry = {"id": pid, "worktree": str(wt), "applied": [], "conflicts": [], "ignored": []}
        report["packages"].append(entry)
        if not wt.is_dir():
            entry["conflicts"].append({"path": str(wt), "why": "the worktree is gone"})
            continue
        seed_commit, paths = changes(wt)
        planned = []
        for rel in paths:
            if rel.startswith(NOT_MERGED) or rel.startswith(GENERATED):
                entry["ignored"].append(rel)
                continue
            shown = subprocess.run(["git", "-C", str(wt), "show", f"{seed_commit}:{rel}"], capture_output=True)
            base = lf(shown.stdout) if shown.returncode == 0 else None
            theirs = lf(read(wt / rel))
            ours_raw = read(main / rel)
            ours = lf(ours_raw)
            if ours == base:
                planned.append((rel, theirs, ours_raw))
            elif ours == theirs:
                continue
            elif rel.endswith(".arb") and base is not None and theirs is not None and ours is not None:
                merged, keys = merge_arb(base, ours, theirs)
                if keys:
                    entry["conflicts"].append({"path": rel, "why": "keys changed both ways: " + ", ".join(keys[:8])})
                else:
                    planned.append((rel, merged, ours_raw))
            elif base is None or theirs is None or ours is None:
                entry["conflicts"].append({"path": rel, "why": "added or deleted on both sides"})
            else:
                merged, why = merge_text(base, ours, theirs)
                if why:
                    entry["conflicts"].append({"path": rel, "why": why})
                else:
                    planned.append((rel, merged, ours_raw))
        if entry["conflicts"]:
            continue  # all or nothing: the package is redone in the main checkout
        for rel, data, like in planned:
            write(main / rel, data, like)
            entry["applied"].append(rel)
            if rel.endswith(".arb"):
                report["arbChanged"] = True
    if report["arbChanged"] and not args.no_gen:
        flutter = shutil.which("flutter") or "flutter"
        result = subprocess.run([flutter, "gen-l10n"], cwd=main / "App", capture_output=True, shell=os.name == "nt")
        report["genL10n"] = "ok" if result.returncode == 0 else "failed: " + result.stderr.decode("utf-8", "replace")[-400:]
    # A package that conflicted keeps its worktree, so an implementer can integrate it by hand.
    if not args.keep:
        for (pid, wt), entry in zip(pairs, report["packages"]):
            if wt.is_dir() and not entry["conflicts"] and drop_worktree(main, wt):
                report["removed"].append(str(wt))
    print(json.dumps(report, ensure_ascii=False, indent=1))


def drop_worktree(main, wt):
    branch = git(wt, "symbolic-ref", "-q", "--short", "HEAD", check=False)
    removed = subprocess.run(["git", "-C", str(main), "worktree", "remove", "--force", str(wt)], capture_output=True)
    if removed.returncode != 0:
        return False
    # The engine's throwaway branches: worktree-agent-* (Agent tool) and worktree-wf_* (workflows).
    if branch.startswith(("worktree-agent-", "worktree-wf_")):
        git(main, "branch", "-D", branch, check=False)
    remove_mirror(wt)
    return True


def show_diff(args):
    """The package's own changes since its seed, as one patch: what an integrator applies by hand."""
    wt = Path(args.worktree)
    seed_commit, paths = changes(wt)
    keep = [p for p in paths if not p.startswith(NOT_MERGED) and not p.startswith(GENERATED)]
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
    print(f"Removed {wt}." if drop_worktree(main, wt) else f"Could not remove {wt}.")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="action", required=True)
    s = sub.add_parser("seed")
    s.add_argument("--run", help="the run folder, relative to the repo root")
    s.add_argument("--files", nargs="*", default=[], help="files the run has changed so far")
    s.add_argument("--no-pub", action="store_true")
    m = sub.add_parser("merge")
    m.add_argument("--worktree", action="append", required=True, help="<package id>=<worktree path>")
    m.add_argument("--no-gen", action="store_true")
    m.add_argument("--keep", action="store_true", help="keep the worktrees")
    g = sub.add_parser("gate")
    g.add_argument("--slots", type=int, help="heavy commands at once (default UX_GATE_SLOTS, else 3)")
    g.add_argument("--pool", default="app", help="app (Flutter on Windows) or web (builds in WSL)")
    g.add_argument("argv", nargs=argparse.REMAINDER, help="-- <command>, or one quoted command line")
    w = sub.add_parser("add", help="a seeded worktree of another repo, such as the website")
    w.add_argument("--repo", required=True)
    w.add_argument("--name", required=True)
    w.add_argument("--files", nargs="*", default=[])
    d = sub.add_parser("diff", help="a conflicted package's changes since its seed")
    d.add_argument("--worktree", required=True)
    r = sub.add_parser("drop", help="remove a worktree and its worktree-agent-* branch")
    r.add_argument("--worktree", required=True)
    args = parser.parse_args()
    if args.action == "gate":
        return gate(args)
    {"seed": seed, "add": add, "merge": merge, "diff": show_diff, "drop": drop}[args.action](args)


if __name__ == "__main__":
    sys.exit(main())
