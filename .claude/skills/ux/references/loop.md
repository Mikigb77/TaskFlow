# The UX loop

One command reviews the app's UX, fixes what it finds, and checks the fixes. By default it looks only at what changed since the last review, so a small change costs little.

## Commands

| Command | What it does |
|---|---|
| `/ux` | Reviews what changed since the last review, fixes it, re-checks, and commits. |
| `/ux app` | Reviews the whole app, then **stops at the plan** for your approval. |
| `/ux fix` | Carries out the approved plan. Add `skip P3` or `only P1 P2` to change what runs. |
| `/ux plan <run id>` | Plans again from that run's reports, without a new review. Use it after you answer decisions. |
| `/ux calendar, capture sheet` | Reviews only the screens you name. |

After user-facing work, the main session runs `/ux` by itself; AGENTS.md asks it to.

## What happens

1. **Scope.** `ux.sh` compares the user-facing files with a snapshot taken at the end of the last review.
   - If nothing changed, nothing runs.
   - Each area touched gets one reviewer:
     - **A** — voice capture;
     - **B** — calendar, home and tasks;
     - **C** — lists, notes, groups and sharing;
     - **D** — first run, sign-in, settings, notifications, native surfaces and theme.
2. **Render.** The UX preview suite (`App/test/ux_previews/`) renders every route and tab in its key states, in Spanish, Catalan and English, light and dark, at 1×, 1.3× and 2× text, into `App/build/ux/`. With the PNGs it writes:
   - `INDEX.md`: what each render shows, the code it covers and when it was rendered, and what no preview can show;
   - `AUDIT.md`: measured evidence for each one — Flutter's accessibility guidelines, what TalkBack would read, clipped text, and the size of every tap target and the gap to its neighbour.

   So the reviewer judges what a person sees, not only the code. It is still widget-test evidence, not a phone.

   For what previews can't draw, the main session also captures the app on the `TaskFlow_Review` test emulator, into `App/build/ux/device/` with its own `INDEX.md` (`scripts/emulator/README.md`). That's emulator evidence: closer, but still not your phone.
3. **Review.** `frontend-ux-reviewer` (Opus, max effort) writes a report for each area into the run folder. It reviews against `references/guidelines.md` and cites its rule IDs.
4. **Plan.** `ux-organizer` (Opus, max effort):
   - merges duplicates;
   - sends product decisions to you;
   - groups the fixes into work packages, each with an exact brief.
5. **Fix.** `ux-implementer` (Opus, high effort) changes the code, the copy in all three languages, and the tests, then checks its own work and refreshes the previews of the screens it touched.
   - **Waves (2026-10-21):** packages that share no file run side by side, up to 12 at once, even while the website loop runs too. Each gets its own git worktree, and its tester follows it there. The ARB catalogs and test files don't count as shared.
   - Afterwards `.claude/skills/ux/scripts/waves.py merge` brings each worktree back into the main checkout, like a pull request: ARB keys one by one, other files with a three-way merge. A package that conflicts goes to an implementer, who integrates it by hand.
   - Heavy commands (Flutter, builds) go through `waves.py gate`, so only 3 run at once and the machine doesn't swap.
   - A package that shares a file with another, or has no file list, runs alone in the main checkout.
6. **Test.** `ux-tester` (Opus, high effort).
   - It writes a test for every acceptance check a test can prove, working from the plan rather than the code, so the fix and its proof come from different hands. Packages done side by side get their own tester, in their worktree.
   - Once per round, after the merge, it runs the analyzer, the whole suite, and the previews of the screens the round changed.
   - If a test fails because the app falls short, that finding counts as not fixed, whatever the reviewer says.
   - Every fix that passes stays protected by its test.
7. **Verify.** The reviewer checks only the findings just fixed and the files just changed.
8. **Re-plan.** Anything that failed goes back to the organizer, for at most 2 more rounds. A finding that fails twice comes to you instead.
9. **Record.** The issue log and the run report are updated, and the reviewer updates its memory. If the gate passed, the round is committed on `dev`. The snapshot then moves forward.

## Rules (your decisions, 2026-10-13)

- The loop fixes everything the reviewer finds **except product decisions**; those come to you.
- Only whole-app runs stop for your approval.
- Each verified round becomes one commit on `dev`. Nothing is ever pushed, and `main` is never touched.
- No agent touches your phone or your own emulators. The main session captures what previews can't draw — the launcher, the widget, notifications, permission dialogs, sharing, TalkBack — from the separate `TaskFlow_Review` test emulator, which holds only test data (2026-10-18; `scripts/emulator/README.md`). Anything that needs a real phone is listed for you to check.

## Files

The skill, `.claude/skills/ux/`, holds everything the loop does:

| Path | What it holds |
|---|---|
| `SKILL.md` | The `/ux` command: modes, scope, renders, the review and the fix runs. |
| `workflows/ux-review.js`, `workflows/ux-fix.js` | The two workflows, run with the Workflow tool by `scriptPath`. |
| `scripts/ux.sh` | The snapshot helper (`refs/ux-review/last`). It never touches your branch or files. |
| `scripts/waves.py` | Side-by-side packages: seeds each worktree, merges it back, and gates heavy commands. |
| `scripts/pkg.py`, `scripts/phone_checks.py` | Print plan packages for the agents; rebuild `PHONE_CHECKS.md`. |
| `scripts/workflow_timing.py` | Where a fix run's time went, from the session's agent transcripts. |
| `scripts/stage_hunk.py` | Stages only your own change to a file another session also edited, leaving theirs unstaged. |
| `scripts/emulator/` | The device-capture lane. `capture.py` captures Android's own surfaces from the `TaskFlow_Review` test emulator into `App/build/ux/device/`, with its own `INDEX.md`. Its test account, `review.local.json`, is gitignored. |
| `references/loop.md` | This guide. |
| `references/guidelines.md` | The research-backed guide the reviewer reviews against: checkable rules with IDs, evidence strength and sources. |

The records, `.claude/ux-review/`, hold what the loop decided and found:

| File | What it holds |
|---|---|
| `DECISIONS.md` | Your decisions. Every agent reads it first. |
| `ISSUES.md` | Every issue and its current status. |
| `KNOWN_FAILURES.md` | Checks that were already failing before the loop started. |
| `PHONE_CHECKS.md` | Everything fixed in code that still needs a real phone, with steps, by area. Generated from `ISSUES.md` by `phone_checks.py`; when a check passes, move its line in `ISSUES.md` to Verified and regenerate. |
| `runs/<run id>/` | One run: `review-*.md`, `plan.md`, `plan.json`, `verify-*.md`, `report.md`. |
| `emulator/SEEN-2026-10-19.md` | What the first device captures showed. |
| `free-tier-plan.md`, `free-tier-backend-notes.md`, `voice-commands-plan.md` | Approved designs, and the server's contracts for the app. |
| `speed-review-brief.md` | The brief for the capture-speed review (run `2026-10-14-speed`). |

The other pieces:
- the agents: `.claude/agents/`, and their memory in `.claude/agent-memory/`;
- Codex's version of the skill: `.agents/skills/ux/`, with `.codex/`; it shares the records above;
- the previews: `App/test/ux_previews/`, rendered into `App/build/ux/` with `INDEX.md` and `AUDIT.md` (command in `AGENTS.md`).

## Gotchas

Learned the hard way; each cost a run, or hours.
- **Keep the PC awake** before a long step (the renders, the device captures, a fix run). On 2026-10-28 the renders took 15 hours because the PC slept.
- **Worktrees start from `main`, not `dev`.** The workflow engine's and the Agent tool's worktrees are made from the repo's default branch. `waves.py seed` resets a worktree to the main checkout's commit before anything else (2026-10-22, when a whole wave got old code); an Agent-tool agent must `git merge --ff-only dev` first.
- **Resuming:** `Workflow({scriptPath, resumeFromRunId, args})` replays every finished agent from cache, even after a restart, but only with exactly the same args. Save a run's args when you launch it. Agents that were stopped run again.
- **Results:** a workflow's result is the JSON in its task's output file; the report is in `result.close.report`, for the main session to save.
- **A parse check is free:** a workflow called with no args throws at once, so it shows as failed; that's expected.
- **Don't edit `ISSUES.md` or `plan.md` while a fix run is going:** the organizer writes them. `plan.json` and `DECISIONS.md` are safe.
- **Number new IDs right before you queue anything:** re-plans take new P and UX numbers during a run.
- **Shell and files on Windows:** run Python with `-X utf8`. Don't put backslashes in a Python heredoc through Bash: they're mangled; write the script to a file instead. Most files here are checked out with CRLF, so a multi-line replacement must use the file's own line endings.
- **The review emulator fills up:** Google Play keeps updating the image's own apps into its storage. `capture.py` frees it when an install fails for lack of space (2026-10-29); a run that hangs for about 8 minutes is stopped and its missing sections rerun with `--only`.
- **Date-dependent tests:** a test that finds a day by its number breaks when the month grid shows that number twice (2026-10-29): use `dayCell` in `App/test/calendar_feedback_test.dart`.
- **The server's tests:** run them in Docker (`AGENTS.md`). Natively on Windows, three local-test-account tests and one or two file-lock tests fail even at HEAD, and the parallel runner crashes on a failure's traceback: run it serially.
- **Research agents** share one turn's budget of web searches (about 200); refused searches come back as ordinary results. Give each research agent an allowance.

## Cost

- **Scoped run** (one area): about 7 agents.
- **Whole-app run:** 4 reviewers and an organizer, then one implementer per package you approve, plus, each round, one tester and one verifier per area.

To change a model or an effort level, edit the agent's frontmatter.
