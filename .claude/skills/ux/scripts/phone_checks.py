"""Build .claude/ux-review/PHONE_CHECKS.md from the ledger's Device check section. Run from the repo root: python -I -X utf8 .claude/skills/ux/scripts/phone_checks.py"""
import glob
import re
from pathlib import Path

ledger = Path(".claude/ux-review/ISSUES.md").read_text(encoding="utf-8").split("\n")
rows, on = [], False
for line in ledger:
    if line.startswith("## "):
        on = line.strip() == "## Device check"
        continue
    if on and line.startswith("- **"):
        rows.append(line)

# Phone steps written in the batch reports, keyed by ID.
report_steps = {}
for path in sorted(glob.glob(".claude/ux-review/runs/*/report-*.md")):
    text = Path(path).read_text(encoding="utf-8")
    m = re.search(r"#+ Checks for the owner's phone\s*\n(.*?)(?=\n#+ |\Z)", text, re.S)
    if not m:
        continue
    for item in re.split(r"\n(?=\d+\. )", m.group(1).strip()):
        item = re.sub(r"^\d+\.\s*", "", item.strip())
        for found in re.findall(r"\b(UX-\d+|U\d+)\b", item[:60]):
            report_steps.setdefault(found, " ".join(item.split()))

# Device checks written in the plans' packages, keyed by finding (the newest plan file wins).
import json
import os
plan_steps = {}
for path in sorted(glob.glob(".claude/ux-review/runs/*/plan*.json"), key=os.path.getmtime):
    for pkg in json.loads(Path(path).read_text(encoding="utf-8")).get("packages", []):
        checks = [c for c in pkg.get("deviceChecks", []) if c]
        if checks:
            for fid in pkg.get("findings", []):
                plan_steps[fid] = " ".join(checks)

AREAS = {"A": "Capture (voice and typing)", "B": "Calendar, Tareas and the task form",
         "C": "Projects, sharing, groups and invitations", "D": "Sign-in, settings, notifications and the rest"}
SEV_ORDER = {"P0": 0, "S4": 1, "S3": 2, "P1": 3, "S2": 4, "P2": 5, "S1": 6}
items = {k: [] for k in AREAS}
missing = []
for row in rows:
    m = re.match(r"- \*\*(\S+)\*\* · (\S+) · (\S) · device-check · (.*?) · `", row)
    if not m:
        m = re.match(r"- \*\*(\S+)\*\* · (\S+) · (\S) · device-check · (.*?) · ", row)
    if not m:
        missing.append(row[:80])
        continue
    fid, sev, area, title = m.groups()
    step = None
    p = row.rfind("Phone:")
    if p >= 0:
        step = row[p + len("Phone:"):].strip()
    if not step:
        step = report_steps.get(fid)
        if step:
            step = re.sub(r"^\*\*[^*]+\*\*:?\s*", "", step)
    if not step:
        step = plan_steps.get(fid)
    if not step:
        step = "(No phone step was written; check the finding's line in ISSUES.md.)"
    needs = []
    low = (row + " " + step).lower()
    if "two accounts" in low or "second account" in low or "dos cuentas" in low:
        needs.append("two accounts")
    if "talkback" in low:
        needs.append("TalkBack")
    if "ios" in low and ("ios build" in low or "iphone" in low):
        needs.append("iOS")
    if "real server" in low or "against the real" in low:
        needs.append("real server")
    items.setdefault(area, []).append((SEV_ORDER.get(sev, 9), fid, sev, title, step, needs))

out = ["# Phone checks", "",
       "Everything here is fixed in code and covered by widget or unit tests, but only a real phone can confirm it. "
       "Generated from the `Device check` section of `ISSUES.md`; when a check passes, move its line there to "
       "Verified. Most urgent first within each area.", ""]
total = 0
for key, name in AREAS.items():
    group = sorted(items.get(key, []))
    if not group:
        continue
    out.append(f"## {key} · {name} ({len(group)})")
    out.append("")
    for _, fid, sev, title, step, needs in group:
        tag = f" _(needs: {', '.join(needs)})_" if needs else ""
        out.append(f"- [ ] **{fid}** ({sev}) {title}.{tag}")
        out.append(f"  - {step}")
        total += 1
    out.append("")
Path(".claude/ux-review/PHONE_CHECKS.md").write_text("\n".join(out), encoding="utf-8")
print("checks:", total, "unparsed rows:", len(missing))
for m in missing:
    print("  ", m)
