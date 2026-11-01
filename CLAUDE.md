@AGENTS.md

# Claude Code

What only Claude needs; everything else is in `AGENTS.md`, above.

- **The UX loop is the `/ux` skill**, in `.claude/skills/ux/`: `SKILL.md`, its workflows in `workflows/` (run with the Workflow tool by `scriptPath`, never by `name`), its tools in `scripts/`, and how the loop works and the review guidelines in `references/`. Its agents are `.claude/agents/frontend-ux-reviewer.md`, `ux-organizer.md`, `ux-implementer.md` and `ux-tester.md`; their memory is in `.claude/agent-memory/`.
- **Keep the PC awake** before any long run (a review's renders and captures, a fix run): request keep-awake with `until: "session_idle"`. On 2026-10-28 a review lost about 15 hours to a sleeping PC.
- **A workflow runs at most min(16, CPUs − 2) agents at once.** A 4-CPU cloud session gets 2, which is why a 32-package fix took about 15 hours on 2026-10-31. There, run a big fix plan in lanes (`/ux` skill, §6), or on the PC.
- **The website's loop is `/ux-web`, in `../TaskFlowWeb`.** Its skill and agents load only when the session's folder is that repo: move this session there (`change_directory`), run it, and move back.
- **Agents and skills load when a session starts or changes folder.** After adding or editing them mid-session, change directory to this repo again to reload them.
