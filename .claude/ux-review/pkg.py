"""Print only the work packages an agent needs from a UX-loop run.

Agents use this instead of opening the whole plan.json, which is large.

Usage:
  python -I -X utf8 .claude/ux-review/pkg.py <runDir> P31 [P1 ...] [--conventions]

Looks in plan.json and in every plan-*.json of the run folder. When a package
appears in more than one file, the most recently written file wins.
"""
import glob
import json
import os
import sys


def main() -> None:
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    run_dir = sys.argv[1]
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
