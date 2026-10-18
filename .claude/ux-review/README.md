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

After user-facing work, the main session runs `/ux` by itself; CLAUDE.md asks it to.

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
3. **Review.** `frontend-ux-reviewer` (Opus, max effort) writes a report for each area into the run folder. It reviews against `GUIDELINES.md` and cites its rule IDs.
4. **Plan.** `ux-organizer` (Opus, max effort):
   - merges duplicates;
   - sends product decisions to you;
   - groups the fixes into work packages, each with an exact brief.
5. **Fix.** `ux-implementer` (Opus, high effort) works through the packages one at a time. Each one changes the code, the copy in all three languages, and the tests, then checks its own work and refreshes the previews of the screens it touched.
6. **Test.** `ux-tester` (Opus, high effort) runs once per round.
   - It writes a test for every acceptance check a test can prove, working from the plan rather than the code, so the fix and its proof come from different hands.
   - It then runs the analyzer, the whole suite, and the previews of the screens the round changed.
   - If a test fails because the app falls short, that finding counts as not fixed, whatever the reviewer says.
   - Every fix that passes stays protected by its test.
7. **Verify.** The reviewer checks only the findings just fixed and the files just changed.
8. **Re-plan.** Anything that failed goes back to the organizer, for at most 2 more rounds. A finding that fails twice comes to you instead.
9. **Record.** The issue log and the run report are updated, and the reviewer updates its memory. If the gate passed, the round is committed on `dev`. The snapshot then moves forward.

## Rules (your decisions, 2026-10-13)

- The loop fixes everything the reviewer finds **except product decisions**; those come to you.
- Only whole-app runs stop for your approval.
- Each verified round becomes one commit on `dev`. Nothing is ever pushed, and `main` is never touched.
- No agent touches a phone or an emulator. Anything that needs a device is listed for you to check.

## Files

| File | What it holds |
|---|---|
| `ISSUES.md` | Every issue and its current status. |
| `DECISIONS.md` | Your decisions. Every agent reads it first. |
| `GUIDELINES.md` | The research-backed guide the reviewer reviews against: checkable rules with IDs, evidence strength and sources. |
| `KNOWN_FAILURES.md` | Checks that were already failing before the loop started. |
| `runs/<run id>/` | One run: `review-*.md`, `plan.md`, `plan.json`, `verify-*.md`, `report.md`. |
| `ux.sh` | The snapshot helper (`refs/ux-review/last`). It never touches your branch or files. |
| `PHONE_CHECKS.md` | Everything fixed in code that still needs a real phone, with steps, by area. Generated from `ISSUES.md` by `phone_checks.py`; when a check passes, move its line in `ISSUES.md` to Verified and regenerate. |
| `pkg.py`, `phone_checks.py` | Helpers: print plan packages for the agents; rebuild `PHONE_CHECKS.md`. |
| `free-tier-plan.md`, `free-tier-backend-notes.md` | The free tier's design and the server's contract for the app. |
| `speed-review-brief.md` | The brief for the capture-speed review (run `2026-10-14-speed`). |

The other pieces:
- the agents: `.claude/agents/`;
- the workflows: `.claude/workflows/ux-review.js` and `ux-fix.js`;
- the command: `.claude/skills/ux/SKILL.md`;
- the previews: `App/test/ux_previews/`, rendered into `App/build/ux/` with `INDEX.md` and `AUDIT.md` (command in CLAUDE.md).

## Cost

- **Scoped run** (one area): about 7 agents.
- **Whole-app run:** 4 reviewers and an organizer, then one implementer per package you approve, plus, each round, one tester and one verifier per area.

To change a model or an effort level, edit the agent's frontmatter.
