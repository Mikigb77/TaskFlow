# Resume: run 2026-10-28-app, stopped mid-fix (2026-11-01)

The owner stopped the run here so it can be finished from any laptop, in a new conversation. Everything the run needs is on the branch **`ux-in-progress`** of both repos (TaskFlow and TaskFlowWeb). This file is the whole handoff: the earlier conversation is gone.

## What the owner has asked for, still standing

- «do everything» (2026-10-31): carry this run's whole plan through `ux fix` with **no stop for approval**; approve the website plan 2026-10-28-site with WD22–WD34 as recommended (recorded in TaskFlowWeb's `.claude/ux-web/DECISIONS.md`, ce0b2f9).
- «D1 and D2 both yes, as recommended» (2026-11-01; recorded in `.claude/ux-review/DECISIONS.md`, 8064257).
- «when it's done, make a pr to main» and «make a pr and merge it onto main»: when both loops are done, open a dev→main PR in each repo and merge it. There's no CI and merging deploys nothing. Never deploy.
- D7 (the RevenueCat paywall text) stays the owner's; build nothing for it.

## Where the app run is

Snapshot of the review: 27f5078. Plan: `plan.md` and `plan.json` here (packages P266–P295, in 3 batches).

Server work is all committed on this branch: D9 (bc80025, a reader chooses their own reminders), UX-2508 and UX-2617 (85d7408), D2's server half (8064257: `completed_at` / `completed_times`, migration 0026, contract `Backend/docs/COMPLETION_TIMES.md`). Docker suite: 507 OK. **Run `docker compose up -d --build` and `migrate` on the new laptop**: the API must have migration 0026.

### Batch b1 (P266–P277) was stopped in its first round

- **Merged into the code but never round-checked or verified** — committed on this branch as one "work in progress" commit: **P266, P267, P268, P269, P270, P271, P273, P276**. Each was implemented and locked by its own tests in its worktree, then merged. The analyzer was clean after the merge (2026-11-01); the full suite, the previews and the reviewer's verification have **not** run on them.
- **Half done, not merged:** P272 and P274 were being implemented when the run stopped. Their partial, unchecked edits are kept for reference only: `wip-b1-P272.patch`, `wip-b1-P274.patch`. The workflow will redo them; don't apply the patches by hand unless an implementer wants to borrow from them.
- **Not started:** P275, P277.
- `ISSUES.md` holds the ledger lines the review filed (status "open"); the organizer updates them when a batch closes.

### Next steps, in order

1. Check out `ux-in-progress` in TaskFlow (`git fetch` with gh's credentials, below). Request keep-awake (`until: "session_idle"`) before any long run.
2. **Rerun b1 with all 12 packages** (`.claude/skills/ux/workflows/ux-fix.js`, by scriptPath), so the round check and the verification cover the 8 merged ones too:
   ```json
   {"runId":"2026-10-28-app","runDir":".claude/ux-review/runs/2026-10-28-app","date":"<today>",
    "repoRoot":"<this laptop's TaskFlow path, forward slashes>","maxParallel":12,"heavySlots":3,
    "only":["P266","P267","P268","P269","P270","P271","P272","P273","P274","P275","P276","P277"],
    "batch":"b1","recordMemory":false,
    "notes":"<the notes below>"}
   ```
   Notes to pass: the owner approved the whole plan (no stop for approval); batch b1 of three; P266, P267, P268, P269, P270, P271, P273 and P276 are already in the code, committed on ux-in-progress from a stopped run — their implementers confirm the fix holds, add only what's missing, and don't redo it; P272 and P274 were half done (patches in the run folder, unchecked); D1 and D2 are decided but get their packages from the re-plan (step 4), so build nothing for them here; D9's server half (bc80025): a reader's PUT that changes only their own reminder fields answers 200 with the version unchanged, any other change is 403, a stale version still saves the reminders and answers 409; other sessions' uncommitted files are never staged, committed or reverted.
3. After each batch: save `result.close.report` to the run folder as `report-<batch>.md`; if tests passed, `git add -- <filesChanged> .claude/ux-review .claude/agent-memory`, commit «UX loop 2026-10-28-app: <n> fixes verified», then `bash .claude/skills/ux/scripts/ux.sh save`.
4. **Re-plan for D1 and D2** (`/ux plan 2026-10-28-app`: ux-review.js with reportPaths = this folder's review-*.md files). New packages take the next P numbers (P296 on):
   - D1 (a), UX-2612: «Guardar como tarea» shows its task as a normal result card, with «Añadir al calendario», before saving.
   - D2 (a), UX-2311's app half: send `completed_at` (one-off) or `completed_times` (repeating) when a task is ticked, keep them offline; Completadas lists newest first, untimed ones after. The server already sends both fields (`Backend/docs/COMPLETION_TIMES.md`).
5. b2 = P278–P289 (`recordMemory: false`). b3 = P290–P295 plus the re-plan's packages, `recordMemory: true`.
6. Main-session items from `plan.md` still open: D14 (Google invitees join without the code; decided 2026-10-13, not built), and item 5 (preview fixtures: render each area within one day, or have `dayLabel` read the clock seam). Do them if they fit, or report them.

## Then the website (TaskFlowWeb)

Its agents load only in a session whose folder is TaskFlowWeb: move there (`change_directory`), and the move takes effect when the turn ends. Don't move while an app workflow runs.

1. Check out `ux-in-progress` there too (it is TaskFlowWeb's dev plus ce0b2f9 and f418a7b).
2. `/ux-web plan 2026-10-28-site`, to add WD22, WD23, WD27, WD30, and WD28 into WP66.
3. `bash .claude/skills/ux-web/scripts/ux-web.sh base`, then `/ux-web fix` in batches of about 5 (maxParallel 12, heavySlots 2). After each batch: `ux-web.sh ran`, `ux-web.sh stage <files>` (only files in both `ran` and the batch's webFiles), commit the site files and the records, `ux-web.sh save`, `ux-web.sh base`.
4. Then a `/ux-web` changes run, since the app's copy and docs changed (its claims are checked against the app repo).

## Finally

- In each repo: fast-forward `dev` to `ux-in-progress` (`git checkout dev && git merge --ff-only ux-in-progress`), push `dev`, open the dev→main PR, merge it, and delete `ux-in-progress` (local and remote).
- Pushing: `git -c credential.helper= -c "credential.helper=!gh auth git-credential" push`.
- Report to the owner what stays theirs: D7 and the RevenueCat Pro benefits list; WD24 (the package ID); WD29 (a lawyer); WD31 (launch checklist); the phone checks the reports list; Catalan reads; the other session's English-only email footer.

## Rules that bite

- Other sessions' uncommitted work is never staged, committed or reverted: App/pubspec.yaml, App/scripts/build-staging.ps1, App/config/, Backend/.env.example, Backend/README.md, Backend/config/cloud/build-staging.yaml, Backend/config/settings.py, Backend/core/email_delivery.py, Backend/core/test_account_deletion.py, Backend/core/test_staging.py, Backend/core/test_task_creator.py, Backend/core/tests.py, Backend/core/test_email_delivery.py, Backend/docs/STAGING.md, Backend/scripts/deploy-staging.ps1, the root scripts/ and build/. (They are on the first laptop only, not on this branch.)
- Never print `Backend/.env`'s values. Only the TaskFlow_Review emulator; never the owner's emulator-5554 or phone. No agent stops WSL.
- Don't edit `ISSUES.md` or `plan.md` while a fix run is going.
