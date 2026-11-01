# Codex UX execution protocol

This is the Codex adapter for TaskFlow's app loop; the website's loop has its own,
in `../TaskFlowWeb/.codex/`. Product rules are in `AGENTS.md`; the skill, its
guidelines and the loop's history are in `.claude/`. Do not execute
Claude's `Workflow` JavaScript or copy its history into a second store.

## Activation and roles

An actual `$ux` / `$ux-web` request, or the shared post-UI-change policy, activates
this protocol. A setup, explanation or plan-only request never activates fixes
or tests. Follow the current user's narrower limits over historical instructions.

The primary session reads the selected skill and delegates to
`taskflow_ux_orchestrator`, with the user's request, scope, working directory,
constraints and relevant decisions. This role also organizes the plan. It uses
`taskflow_ux_reviewer`, `taskflow_ux_implementer` and `taskflow_ux_tester` for the
remaining stages. Agent files set Sol 6.1 with `max` for orchestration/review and
`xhigh` for implementation/testing; they do not change the main chat's model.

Prefer the client's custom-agent selection. If its spawn API exposes only model
and reasoning fields, read the matching `.codex/agents/<role>.toml` and pass its
`developer_instructions` with the brief, explicitly setting `gpt-6.1-sol` and
the file's effort. For the collaboration API use `fork_turns="none"` with explicit
model/effort and a self-contained brief. Do not silently inherit another model.
If the client cannot honor these settings, report that limitation before running.

Respect the runtime's available slots. The project caps spawned threads at three;
with a dedicated orchestrator, that leaves at most two parallel workers. Queue
remaining areas and close/reuse finished workers. If the client cannot spawn
nested agents, the primary session dispatches the orchestrator's worker briefs
and relays results. Workers do not delegate or invoke the loop again. Run app
and web loops sequentially, with only one source writer or test runner active.

## Shared inputs and preflight

1. Verify `dev`, working-tree status and absence of a merge/rebase/cherry-pick.
   For web work check both repositories. Don't switch branches with someone's
   work in progress. Record the initial staged/unstaged/untracked paths and
   the starting HEADs so ownership can be proved later.
2. Inspect available active-agent/task state and current shared run records for
   another review/fix run. Do not share a write lane with Claude, another Codex
   run, a render suite or an emulator capture. If an active lane is ambiguous,
   coordinate before writing; never kill another session's process or overwrite
   its snapshot, evidence or plan.
3. Read the domain README, decisions, relevant guideline sections, known failures,
   existing issues and applicable agent-memory notes. Search large documents by
   area/rule/issue; do not dump `.claude/worktrees/` or all historical runs into
   context. Old findings and memory are evidence to re-check, not proof.
4. Resolve scope with the existing helpers and the domain skill. A missing
   baseline is not permission to review everything. No changes means no workers.
5. Only after execution is authorized, create a unique
   `<client-date>-codex-<mode>[-N]` directory under the domain's existing `runs/`.
   Save `run.json` with engine `codex`, mode, scope, starting HEADs, baseline refs,
   constraints, role models/efforts and evidence times. Never overwrite a run.
   For `fix`/`plan`, use the selected existing run and append a Codex attempt
   record; retain its original metadata and reports.
6. For website edits, use the existing `ux-web.sh base` **before** editing, once
   the shared lane is free. It records other sessions' work for safe staging.

## Review, plan and execution

1. **Evidence.** Produce the domain's previews/audits before reviewing. Record
   failures and uncovered surfaces. Check `INDEX.md` timestamps: an earlier
   screenshot left by a failed render is stale. Continue investigation if useful,
   but don't certify an unobserved visual or device behavior.
2. **Review.** Assign independent areas and non-overlapping new issue-ID ranges.
   Workers return reports; the orchestrator saves `review-<area>.md`. Each finding
   needs its ID, severity, guideline rule, user impact, source/evidence locations,
   reproduction and acceptance criteria. Reuse a matching existing issue ID.
   Reviewers never write shared ledgers or generate evidence concurrently.
3. **Plan.** Merge duplicates and group small, ordered work packages (normally
   no more than six findings in one coherent change). Keep the shared severity
   scale: S4 is most severe, S1 least; fix defects at every severity. Respect
   dependencies, then prioritize severity and area. Separate defects from product
   decisions. Preserve the existing `plan.md` / `plan.json`
   format below. Send unresolved product decisions to the owner via the primary
   session; unrelated approved packages may continue. Full `app` / `site` runs
   stop at this plan unless the current request already authorizes the fixes.
   `plan <run>` stops after planning and uses existing reports, without rendering.
4. **Implement.** Follow dependency order, one package at a time. A worker owns
   only its named files; overlapping work is sequential. Validate package IDs
   before dispatch (`pkg.py` can exit successfully even when an ID is absent).
   Supply the package, relevant findings/rules, acceptance criteria and allowed
   paths. Do not broaden an app/web UX fix into backend or infrastructure work.
5. **Test.** A separate tester receives the plan's acceptance criteria and changed
   paths. It may edit tests, not product code. Every step of a package runs the
   domain's package check (`.claude/skills/ux/scripts/check.py`), which runs only the checks and
   tests its change touches (`--list` shows what and why); the domain's whole
   suite runs once per run, after the last package, and what fails there is
   repaired once and re-checked with the package check. Preserve true exit codes: for WSL
   pipelines use `set -o pipefail`; truncating output must not hide a failed test.
   Update affected previews after edits. Do not repeat green suites without a
   new change or unresolved concern.
6. **Verify.** A reviewer checks only the round's fixes and their regressions
   against the refreshed evidence. Independent failing acceptance tests override
   an optimistic review. Missing worker output, stale evidence or infrastructure
   failure leaves the affected check pending/blocked, never passed.
7. **Retry.** Fix a package that falls short once, right after its check, and
   check it again. A finding still short after that has failed twice: escalate
   it. Re-plan only what the run's final check finds and its repair can't clear,
   re-checked afterwards with the package check, in at
   most one follow-up round (2026-11-01: the owner asked for runs as fast as the
   machine allows). Stop retrying unavailable infrastructure; report what would
   unblock it.
8. **Record.** Only the orchestrator updates issue status, the run's `report.md`,
   verified review memory and applicable phone checks. Retain the shared ledger
   schema, chronology and IDs. Distinguish automated proof, preview, emulator and
   physical-phone evidence. Capture an actual owner's new lasting decision in
   `DECISIONS.md`; never label an agent assumption as an owner decision.
9. **Commit and snapshot.** The shared policy allows committing verified rounds
   on `dev` unless the current user limits it. Stage only owned, verified changes;
   never `git add .` or commit unrelated pre-staged work. Inspect the staged diff
   and ensure only this round is included. Use the web helper's ownership-aware
   `stage` operation for website hunks; do not bypass an ownership refusal. If
   work can't be separated safely, leave it uncommitted and explain. Never push,
   merge into `main` or deploy as part of a UX loop.

The snapshot helpers save all their candidate paths. Advance a domain's baseline
only when every change it would acknowledge has been reviewed and verified.
Do not advance it for a partial review, pending plan, failed verification or
unreviewed concurrent changes. Report unresolved work without hiding it behind a
fresh snapshot. Full reviews and scoped reviews can have findings even if tests
pass; “green tests” alone do not close an issue.

## Compatible plans and worker handoffs

Keep plans compatible with `.claude/skills/ux/scripts/pkg.py` and existing Claude agents:

```json
{
  "runId": "<existing run directory name>",
  "mode": "changes",
  "conventions": [],
  "packages": [{
    "id": "P1",
    "title": "<specific outcome>",
    "area": "B",
    "size": "S",
    "findings": ["UX-<reserved id>"],
    "files": ["App/lib/<owned file>"],
    "brief": "<bounded implementation instructions>",
    "acceptance": ["<observable expected behavior>"],
    "deviceChecks": [],
    "dependsOn": []
  }],
  "decisions": [],
  "skipped": []
}
```

Package sizes are `S`, `M` or `L`. Use `WP` packages, `WEB` issues and `WD` decisions
for the web; preserve additional
domain fields such as `created` and `severity` from the existing plan format.
New IDs must not collide with the ledger or unresolved plans. When replanning,
retain IDs; save `plan-<attempt>.json` and the matching Markdown rather than erase
the original plan. Decision entries contain question, findings and recommendation;
skipped findings contain ID and reason.

Every worker brief includes: domain, stage, repo paths, run/attempt, assigned area
or packages, permitted files, current user constraints, relevant decisions,
evidence paths/times and expected output. Return explicit status plus changed
paths, findings/acceptance mapping, commands with exit codes, pending checks and
suggested record updates. Workers return text to their parent; they do not message
other user chats or services. The final user report links the plan/report, gives
verification limits and commit IDs if any, and lists remaining owner decisions.
