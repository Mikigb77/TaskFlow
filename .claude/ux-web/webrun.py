#!/usr/bin/env python3
"""Runs a website command (npm, npx, Playwright) on WSL's own disk instead of /mnt/c.

The website's checkout lives on the Windows drive, where Node is slow (in the loop's first runs a
type check took 71 s, a build 143 s and one Playwright spec file 175 s). Each call:
1. syncs the checkout, or a worktree of it, into ~/twb/<name>: the source only, by size and
   modification time, removing what was removed. node_modules, .next, artifacts and test results
   stay on the Linux side;
2. puts node_modules in place: installed once per package-lock.json with npm ci, in
   ~/twb/_deps/<hash>, then hard-linked into each mirror, so a new mirror costs seconds;
3. gives the mirror its own port: its package.json start script and its Playwright config say
   <port> instead of 3000, and a server left on that port is stopped first, so Playwright never
   tests a stale build. The loop uses 3100 and up; 3000 stays free for people;
4. runs the command in the mirror, with nvm's Node;
5. copies artifacts/ and test-results/ back to the checkout, where agents read them.

Usage, from Windows (the main checkout, then a package's worktree):
  wsl -e python3 /mnt/c/.../TaskFlow/.claude/ux-web/webrun.py --src /mnt/c/.../TaskFlowWeb --name main --port 3100 -- 'npm run build'
  wsl -e python3 /mnt/c/.../TaskFlow/.claude/ux-web/webrun.py --src /mnt/c/Users/mikig/.taskflow-tools/web-wt/<copy> --name <copy> --port 3101 -- 'npx playwright test tests/home.spec.ts --reporter=dot'
  wsl -e python3 /mnt/c/.../TaskFlow/.claude/ux-web/webrun.py --remove <name>
"""
import argparse
import fcntl
import hashlib
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home() / "twb"
# Never synced either way: built or installed on each side, or not the site's.
SKIP = {"node_modules", ".next", "artifacts", "test-results", "test-results-renders", "playwright-report", ".git",
        "out", "dist", ".turbo", ".wrangler", ".astro", ".deps", ".env", ".dev.vars"}
# test-results-renders: a second Playwright run's output folder, when the suite and the renders run
# side by side (each run empties its own output folder when it starts).
BACK = ["artifacts", "test-results", "test-results-renders"]


def say(message):
    print(f"[webrun] {message}", flush=True)


def files_under(root):
    """Relative paths of the regular files under root, skipping SKIP names at any depth."""
    found = {}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP]
        for name in filenames:
            if name in SKIP or name.startswith(".env") or name.endswith(".tsbuildinfo"):
                continue
            path = Path(dirpath) / name
            if path.is_symlink():
                continue
            st = path.stat()
            found[str(path.relative_to(root))] = (st.st_size, int(st.st_mtime))
    return found


def rsync(src, dst, skip=True):
    """rsync when installed (owner, 2026-10-21): times and sizes, removals, no permissions, which
    the Windows drive doesn't keep. Returns (copied, removed), or None without rsync."""
    if not shutil.which("rsync"):
        return None
    dst.mkdir(parents=True, exist_ok=True)
    excludes = [f"--exclude={name}" for name in sorted(SKIP)] + ["--exclude=.env*", "--exclude=*.tsbuildinfo"] if skip else []
    out = subprocess.run(["rsync", "-rlt", "--delete", "--out-format=%o %n", *excludes, f"{src}/", f"{dst}/"],
                         capture_output=True, text=True)
    if out.returncode not in (0, 24):  # 24: a file vanished while copying, which is fine here
        raise SystemExit(f"rsync failed: {out.stderr.strip()[-400:]}")
    lines = [line for line in out.stdout.splitlines() if line and not line.endswith("/")]
    removed = sum(1 for line in lines if line.startswith("del."))
    return len(lines) - removed, removed


def sync(src, dst, skip_top=()):
    """Makes dst's files match src's; returns how many were copied and removed."""
    done = rsync(src, dst)
    if done is not None:
        return done
    dst.mkdir(parents=True, exist_ok=True)
    want = files_under(src)
    have = files_under(dst)
    copied = removed = 0
    for rel, sig in want.items():
        if rel.split("/")[0] in skip_top:
            continue
        if have.get(rel) != sig:
            target = dst / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src / rel, target)
            copied += 1
    for rel in have:
        if rel not in want and rel.split("/")[0] not in skip_top:
            (dst / rel).unlink(missing_ok=True)
            removed += 1
    return copied, removed


def deps(src, mirror):
    """node_modules for this package-lock.json, hard-linked into the mirror."""
    digest = hashlib.sha256((src / "package.json").read_bytes() + (src / "package-lock.json").read_bytes()).hexdigest()[:16]
    store = HOME / "_deps" / digest
    store.mkdir(parents=True, exist_ok=True)
    note = "ready"
    with open(HOME / "_deps" / ".lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)  # one install at a time, however many mirrors ask
        if not (store / ".ok").exists():
            shutil.copy2(src / "package.json", store / "package.json")
            shutil.copy2(src / "package-lock.json", store / "package-lock.json")
            say(f"installing node_modules for lock {digest} (once per lock)")
            done = subprocess.run(["bash", "-lc", f"source ~/.nvm/nvm.sh && cd {shlex.quote(str(store))} && npm ci --prefer-offline --no-audit --no-fund"])
            if done.returncode:
                raise SystemExit(f"npm ci failed in {store}")
            (store / ".ok").touch()
            note = "installed"
    marker = mirror / ".deps"
    if not (mirror / "node_modules").is_dir() or not marker.exists() or marker.read_text().strip() != digest:
        shutil.rmtree(mirror / "node_modules", ignore_errors=True)
        subprocess.run(["cp", "-al", str(store / "node_modules"), str(mirror / "node_modules")], check=True)
        marker.write_text(digest)
        note = "linked" if note == "ready" else note
    return digest, note


def own_port(mirror, port):
    if port == 3000:
        return
    pkg = mirror / "package.json"
    pkg.write_text(re.sub(r"--port 3000\b", f"--port {port}", pkg.read_text()))
    cfg = mirror / "playwright.config.ts"
    if cfg.exists():
        cfg.write_text(cfg.read_text().replace("127.0.0.1:3000", f"127.0.0.1:{port}"))


def free_port(port):
    out = subprocess.run(["ss", "-ltnpH", f"sport = :{port}"], capture_output=True, text=True).stdout
    for pid in set(re.findall(r"pid=(\d+)", out)):
        try:
            os.kill(int(pid), 15)
            say(f"stopped an old server on :{port} (pid {pid})")
        except OSError:
            pass
    if out.strip() and not re.search(r"pid=", out):
        say(f"warning: something else listens on :{port}")
    time.sleep(0.5 if out.strip() else 0)


def serve(mirror, port, env):
    """Starts the mirror's last build on its port and waits until it answers, so several Playwright
    runs in one command share it (the config reuses a server that already answers)."""
    import urllib.request
    server = subprocess.Popen(["bash", "-lc", f"source ~/.nvm/nvm.sh && cd {shlex.quote(str(mirror))} && exec npm run start"],
                              env=env, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
    for _ in range(120):
        try:
            urllib.request.urlopen(f"http://127.0.0.1:{port}/", timeout=2)
            say(f"serving the build on :{port}")
            return server
        except Exception:
            if server.poll() is not None:
                raise SystemExit("the server stopped before answering: build first (npm run build)")
            time.sleep(0.5)
    os.killpg(server.pid, 15)
    raise SystemExit(f"the server on :{port} didn't answer within 60 s")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--src", help="the checkout or worktree, as a WSL path (/mnt/c/...)")
    parser.add_argument("--name", help="the mirror's name under ~/twb: main, or the worktree's name")
    parser.add_argument("--port", type=int, default=3100)
    parser.add_argument("--no-back", action="store_true", help="don't copy artifacts and test results back")
    parser.add_argument("--serve", action="store_true",
                        help="serve the last build while the command runs, so Playwright runs side by side share it")
    parser.add_argument("--remove", metavar="NAME", help="delete the mirror ~/twb/NAME and stop")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.remove:
        name = re.sub(r"[^A-Za-z0-9._-]", "", args.remove)
        if name and name != "_deps":
            shutil.rmtree(HOME / name, ignore_errors=True)
            say(f"removed ~/twb/{name}")
        return 0
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not (args.src and args.name and command):
        parser.error("--src, --name and a command after -- are required")
    # A Windows path (C:/... or C:\...) works too.
    src = Path(re.sub(r"^([A-Za-z]):[\\/]", lambda m: f"/mnt/{m.group(1).lower()}/", args.src).replace("\\", "/"))
    mirror = HOME / re.sub(r"[^A-Za-z0-9._-]", "", args.name)
    started = time.monotonic()
    copied, removed = sync(src, mirror)
    digest, note = deps(src, mirror)
    own_port(mirror, args.port)
    free_port(args.port)
    say(f"{mirror.name} on :{args.port}: {copied} file(s) synced, {removed} removed, node_modules {note}, {time.monotonic() - started:.1f} s")
    line = command[0] if len(command) == 1 else shlex.join(command)
    env = dict(os.environ, PORT=str(args.port))
    server = serve(mirror, args.port, env) if args.serve else None
    try:
        code = subprocess.run(["bash", "-lc", f"source ~/.nvm/nvm.sh && cd {shlex.quote(str(mirror))} && {line}"], env=env).returncode
    finally:
        if server:
            os.killpg(server.pid, 15)
            say(f"stopped the server on :{args.port}")
    if not args.no_back:
        back = 0
        for folder in BACK:
            if (mirror / folder).is_dir():
                c, r = sync_back(mirror / folder, src / folder)
                back += c + r
        if back:
            say(f"{back} artifact file(s) copied back to {src}")
    return code


def sync_back(src, dst):
    """Results back to the checkout: every file, including PNGs and traces."""
    done = rsync(src, dst, skip=False)
    if done is not None:
        return done
    dst.mkdir(parents=True, exist_ok=True)
    want, have = {}, {}
    for root, store in ((src, want), (dst, have)):
        for dirpath, _, filenames in os.walk(root):
            for name in filenames:
                path = Path(dirpath) / name
                st = path.stat()
                store[str(path.relative_to(root))] = (st.st_size, int(st.st_mtime))
    copied = removed = 0
    for rel, sig in want.items():
        if have.get(rel) != sig:
            target = dst / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src / rel, target)
            copied += 1
    for rel in have:
        if rel not in want:
            (dst / rel).unlink(missing_ok=True)
            removed += 1
    return copied, removed


if __name__ == "__main__":
    sys.exit(main())
