"""Print only the work packages an agent needs from a UX-loop run.

Agents use this instead of opening the whole plan.json, which is large.

Usage:
  python -I -X utf8 .claude/skills/ux/scripts/pkg.py <runDir> P31 [P1 ...] [--conventions]
  python -I -X utf8 .claude/skills/ux/scripts/pkg.py <runDir> --headers [--plan <file>]
  python -I -X utf8 .claude/skills/ux/scripts/pkg.py <runDir> --lanes N [--plan <file>] [--only P1 P2 ...] [--skip P3 ...]

Looks in plan.json and in every plan-*.json of the run folder. When a package
appears in more than one file, the most recently written file wins.

--headers prints one JSON object for the fix workflow's load step: every package's
header (id, title, area, size, findings, dependsOn, files) from one plan file (plan.json
unless --plan names another), and the machine it runs on: its CPU count, and the git
top level and common folder of the current directory, which tell the workflow whether its
worktrees work.

--lanes N splits the plan's packages into N lanes for N fix runs at once (a small machine
caps each workflow's agents at its CPUs minus 2). Packages joined by dependsOn share a lane;
the lanes balance by size (S 1, M 2, L 3) and keep packages that change the same file
together where that keeps them balanced. Prints JSON: {"lanes": [[ids], ...], "weights": [...]}.
"""
import glob
import json
import os
import re
import subprocess
import sys

# Files every package may touch without keeping packages apart: the ARB catalogs merge key by
# key, generated l10n is rebuilt, and tests merge line by line. Keep in step with ux-fix.js.
MERGEABLE = re.compile(r"^App/(lib/l10n/(app_\w+\.arb|generated/)|test/)")
WEIGHT = {"S": 1, "M": 2, "L": 3}


def option(name, default=None):
    if name in sys.argv:
        i = sys.argv.index(name)
        if i + 1 < len(sys.argv):
            return sys.argv[i + 1]
    return default


def listed(name):
    """The ids after a flag, up to the next flag."""
    if name not in sys.argv:
        return []
    out = []
    for item in sys.argv[sys.argv.index(name) + 1:]:
        if item.startswith("--"):
            break
        out.append(item)
    return out


def load_plan(run_dir):
    plan = option("--plan") or os.path.join(run_dir, "plan.json")
    if not os.path.isabs(plan) and not os.path.isfile(plan):
        plan = os.path.join(run_dir, os.path.basename(plan))
    with open(plan, encoding="utf-8") as fh:
        return plan, json.load(fh)


def files_of(package):
    out = []
    for f in package.get("files") or []:
        f = str(f).replace("\\", "/")
        f = re.sub(r"^\./", "", f)
        f = re.split(r"[\s:#(]", f)[0]
        if f:
            out.append(f)
    return out


def git(*args):
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else ""


def headers(run_dir):
    plan, data = load_plan(run_dir)
    keys = ("id", "title", "area", "size", "findings", "dependsOn", "files")
    packages = []
    for p in data.get("packages", []):
        h = {k: p.get(k) for k in keys if p.get(k) is not None}
        h.setdefault("findings", [])
        h["files"] = files_of(p)
        packages.append(h)
    print(json.dumps({
        "planFile": plan.replace("\\", "/"),
        "cpus": os.cpu_count() or 1,
        "toplevel": git("rev-parse", "--show-toplevel"),
        "commonDir": git("rev-parse", "--path-format=absolute", "--git-common-dir"),
        "packages": packages,
    }, ensure_ascii=False))


def lanes(run_dir, n):
    _, data = load_plan(run_dir)
    only, skip = set(listed("--only")), set(listed("--skip"))
    plan = [p for p in data.get("packages", []) if p.get("id") not in skip and (not only or p.get("id") in only)]
    ids = [p["id"] for p in plan]
    parent = {i: i for i in ids}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for p in plan:
        for d in p.get("dependsOn") or []:
            if d in parent:
                parent[find(p["id"])] = find(d)
    groups = {}
    for p in plan:
        groups.setdefault(find(p["id"]), []).append(p)
    weight = lambda p: WEIGHT.get(str(p.get("size") or "M").strip().upper()[:1], 2)
    comps = [{"ps": ps, "w": sum(weight(p) for p in ps),
              "files": {f for p in ps for f in files_of(p) if not MERGEABLE.match(f)}} for ps in groups.values()]
    comps.sort(key=lambda c: -c["w"])  # heaviest first; stable, so plan order breaks ties
    n = max(1, min(n, len(comps)))
    target = sum(c["w"] for c in comps) / n
    load, files, lane_of = [0] * n, [set() for _ in range(n)], {}
    for c in comps:
        best, score = 0, None
        for k in range(n):
            shared = len(c["files"] & files[k])
            fits = load[k] + c["w"] <= target + 2
            s = (1000 if fits else 0) + 2 * min(shared, 3) - load[k]
            if score is None or s > score:
                best, score = k, s
        load[best] += c["w"]
        files[best] |= c["files"]
        for p in c["ps"]:
            lane_of[p["id"]] = best
    out = [[i for i in ids if lane_of[i] == k] for k in range(n)]
    print(json.dumps({"lanes": out, "weights": load}, ensure_ascii=False))


def main() -> None:
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    run_dir = sys.argv[1]
    if "--headers" in sys.argv:
        headers(run_dir)
        return
    if "--lanes" in sys.argv:
        lanes(run_dir, int(option("--lanes", "1")))
        return
    wanted = [a for a in sys.argv[2:] if not a.startswith("--")]
    files = [os.path.join(run_dir, "plan.json")]
    files += sorted(glob.glob(os.path.join(run_dir, "plan-*.json")), key=os.path.getmtime)

    found = {}
    conventions = None
    for path in files:
        try:
            with open(path, encoding="utf-8") as fh:
                data = json.load(fh)
        except (OSError, ValueError):
            continue
        if conventions is None and isinstance(data.get("conventions"), list):
            conventions = data["conventions"]
        for package in data.get("packages", []):
            if package.get("id") in wanted:
                found[package["id"]] = (package, os.path.basename(path))

    if "--conventions" in sys.argv and conventions:
        print("CONVENTIONS (apply to every package)")
        for item in conventions:
            print(f"- {item}")
        print()
    for package_id in wanted:
        if package_id not in found:
            print(f"===== {package_id}: not found =====")
            continue
        package, source = found[package_id]
        print(f"===== {package_id} (from {source}) =====")
        print(json.dumps(package, ensure_ascii=False, indent=1))
        print()


if __name__ == "__main__":
    main()
