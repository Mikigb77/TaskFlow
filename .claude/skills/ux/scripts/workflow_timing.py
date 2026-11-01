"""Where the UX workflows' time goes: per workflow, per agent, per tool and per kind of command.

Reads every workflow run's agent transcripts (each line has a timestamp) and their meta files, from
this project's Claude Code session folders. First used on 2026-10-21, when 50 runs showed agents
working one at a time, implementers running the whole suite, and runs stalled by a sleeping laptop.
On 2026-11-01 it showed a 19-hour run never above 2 agents at once: the runtime caps a workflow at
min(16, CPUs - 2), and the cloud session had 4 CPUs. Each run's peak and average concurrency is
printed below for that reason.

Usage: python -X utf8 .claude/skills/ux/scripts/workflow_timing.py <projects dir> <out json>
  <projects dir>: ~/.claude/projects/<this repo's folder>, e.g.
  C:/Users/mikig/.claude/projects/C--Users-mikig-Desktop-Custom-MikiHacks-TaskFlow-TaskFlow
"""
import json
import re
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

root = Path(sys.argv[1])
out = Path(sys.argv[2])


def ts(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00")) if value else None


def category(name, tool_input):
    if name != "Bash" and name != "PowerShell":
        return name
    command = (tool_input or {}).get("command", "")
    c = command.lower()
    if "playwright" in c:
        if "ux-renders" in c:
            return "web: renders + audit (playwright)"
        return "web: playwright tests"
    if "npm run build" in c or "next build" in c:
        return "web: build"
    if "tsc" in c or "typecheck" in c or "check-legal" in c:
        return "web: type/legal check"
    if "webkit_renders" in c:
        return "web: webkit renders"
    if "flutter test" in c:
        if "write_ux_previews" in c:
            return "app: previews (ux suite)" if "--plain-name" not in c and "--name" not in c else "app: previews (some screens)"
        if re.search(r"write_(calendar|review|auth|form|web)_", c):
            return "app: other previews"
        # A whole-suite run names no test file.
        if not re.search(r"test/[\w/]+_test\.dart", command):
            return "app: whole suite"
        return "app: targeted tests"
    if "flutter analyze" in c or "dart analyze" in c:
        return "app: analyze"
    if "gen-l10n" in c:
        return "app: gen-l10n"
    if "flutter build" in c or "gradlew" in c:
        return "app: build apk"
    if "capture.py" in c:
        return "emulator lane"
    if c.startswith("git") or " git " in c or "git -c" in c or "git diff" in c or "git status" in c:
        return "git"
    if "sleep" in c or "timeout" in c and "flutter" not in c:
        return "bash: waiting"
    if "wsl" in c:
        return "web: other wsl"
    return "bash: other"


workflows = []
for folder in sorted(root.glob("*/subagents/workflows/wf_*")):
    agents = []
    for transcript in folder.glob("agent-*.jsonl"):
        meta_path = transcript.with_name(transcript.name.replace(".jsonl", ".meta.json"))
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        except Exception:
            meta = {}
        first = last = None
        pending = {}
        tools = defaultdict(lambda: [0, 0.0])  # category -> [calls, seconds]
        turns = 0
        tool_seconds = 0.0
        longest = []
        model = None
        for line in transcript.open(encoding="utf-8"):
            try:
                d = json.loads(line)
            except Exception:
                continue
            t = ts(d.get("timestamp"))
            if t is None:
                continue
            first = first or t
            last = t
            message = d.get("message") or {}
            content = message.get("content")
            if d.get("type") == "assistant":
                turns += 1
                model = model or message.get("model")
                if isinstance(content, list):
                    for block in content:
                        if block.get("type") == "tool_use":
                            pending[block.get("id")] = (t, block.get("name"), block.get("input"))
            elif d.get("type") == "user" and isinstance(content, list):
                for block in content:
                    if block.get("type") == "tool_result" and block.get("tool_use_id") in pending:
                        start, name, tool_input = pending.pop(block["tool_use_id"])
                        seconds = (t - start).total_seconds()
                        cat = category(name, tool_input)
                        tools[cat][0] += 1
                        tools[cat][1] += seconds
                        tool_seconds += seconds
                        if seconds > 120:
                            longest.append((round(seconds), cat, str((tool_input or {}).get("command", ""))[:160]))
        if first is None:
            continue
        duration = (last - first).total_seconds()
        agents.append({
            "agent": transcript.stem,
            "type": meta.get("agentType"),
            "label": meta.get("description"),
            "phase": meta.get("workflowPhase"),
            "start": first.isoformat(),
            "end": last.isoformat(),
            "seconds": duration,
            "tool_seconds": tool_seconds,
            "turns": turns,
            "model": model,
            "tools": {k: v for k, v in tools.items()},
            "longest": sorted(longest, reverse=True)[:8],
        })
    if not agents:
        continue
    start = min(a["start"] for a in agents)
    end = max(a["end"] for a in agents)
    labels = " ".join((a["label"] or "") for a in agents)
    types = {a["type"] for a in agents}
    if "web-ux-tester" in types or "web-ux-implementer" in types:
        kind = "ux-web-fix"
    elif "web-ux-reviewer" in types or "web-ux-organizer" in types:
        kind = "ux-web-review"
    elif "ux-tester" in types or "ux-implementer" in types:
        kind = "ux-fix"
    elif "frontend-ux-reviewer" in types or "ux-organizer" in types:
        kind = "ux-review"
    else:
        kind = "other"
    edges = sorted([(ts(a["start"]), 1) for a in agents] + [(ts(a["end"]), -1) for a in agents], key=lambda e: (e[0], e[1]))
    live = peak = 0
    for _, step in edges:
        live += step
        peak = max(peak, live)
    workflows.append({
        "id": folder.name,
        "kind": kind,
        "start": start,
        "end": end,
        "wall_seconds": (ts(end) - ts(start)).total_seconds(),
        "agent_seconds": sum(a["seconds"] for a in agents),
        "max_concurrent_agents": peak,
        "agents": agents,
    })

out.write_text(json.dumps(workflows, indent=1, default=str), encoding="utf-8")

# ---- Summaries
H = 3600


def fmt(seconds):
    return f"{seconds / 60:6.1f} min"


print(f"{len(workflows)} workflows")
by_kind = defaultdict(list)
for w in workflows:
    by_kind[w["kind"]].append(w)
for kind, items in sorted(by_kind.items()):
    walls = sorted(w["wall_seconds"] for w in items)
    print(f"\n== {kind}: {len(items)} runs, wall total {sum(walls) / H:.1f} h, median {fmt(walls[len(walls) // 2])}, max {fmt(walls[-1])}")
    for w in sorted(items, key=lambda x: x["start"])[-8:]:
        busy = w["agent_seconds"] / w["wall_seconds"] if w["wall_seconds"] else 0
        print(f"   {w['start'][:16]}  wall {fmt(w['wall_seconds'])}  agents at once: peak {w['max_concurrent_agents']}, average {busy:.1f}")

print("\n== Per step (the first word of each agent's label: implement, test, verify, fix, merge, ...)")
steps = defaultdict(lambda: [0, 0.0])
for w in workflows:
    for a in w["agents"]:
        step = (a["label"] or "?").split(" ")[0]
        steps[step][0] += 1
        steps[step][1] += a["seconds"]
for step, (n, s) in sorted(steps.items(), key=lambda kv: -kv[1][1])[:15]:
    print(f"{step:14} n={n:4}  total {s / H:5.1f} h  avg {fmt(s / n)}")

print("\n== Per agent type (all runs)")
per_type = defaultdict(lambda: [0, 0.0, 0.0, 0])
for w in workflows:
    for a in w["agents"]:
        p = per_type[a["type"]]
        p[0] += 1
        p[1] += a["seconds"]
        p[2] += a["tool_seconds"]
        p[3] += a["turns"]
for t, (n, s, tool, turns) in sorted(per_type.items(), key=lambda kv: -kv[1][1]):
    print(f"{str(t):22} n={n:3}  total {s / H:5.1f} h  avg {fmt(s / n)}  tools {100 * tool / s if s else 0:4.0f}%  model {100 * (s - tool) / s if s else 0:4.0f}%  avg turns {turns / n:5.0f}")

print("\n== Tool time by category (all runs)")
cats = defaultdict(lambda: [0, 0.0])
for w in workflows:
    for a in w["agents"]:
        for c, (n, s) in a["tools"].items():
            cats[c][0] += n
            cats[c][1] += s
total_agent = sum(w["agent_seconds"] for w in workflows)
for c, (n, s) in sorted(cats.items(), key=lambda kv: -kv[1][1])[:30]:
    print(f"{c:36} calls {n:5}  total {s / H:5.1f} h  avg {s / n:6.0f} s  share {100 * s / total_agent:4.1f}%")
print(f"\nAll agent time: {total_agent / H:.1f} h; all wall time: {sum(w['wall_seconds'] for w in workflows) / H:.1f} h")
