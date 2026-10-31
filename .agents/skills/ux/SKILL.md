---
name: ux
description: Review and improve TaskFlow's Flutter app UX using the existing guidelines and review history. Use for $ux, app UX reviews, named screen reviews, approved UX plans, and the post-UI-change review required by AGENTS.md. Support changes, app, fix, plan and screen-scoped modes. Do not execute the workflow when the user only requests setup or explanation, or says not to run it yet.
---

# TaskFlow app UX loop for Codex

Read `AGENTS.md` and `.codex/ux-workflow.md`. Follow that protocol using the four
configured Codex roles; do not invoke Claude's Workflow runtime. This skill
authorizes those agent roles only when the current request permits execution.

## Modes

| Request | Action |
| --- | --- |
| `$ux` | Review changes since the shared baseline, fix non-product findings, test and verify. |
| `$ux app` | Review the whole app; present the plan and stop for approval. |
| `$ux <screens or areas>` | Review and fix only the named journeys and their affected states. |
| `$ux fix [skip P3 | only P1 P2]` | Execute the selected approved plan. Use a stated run ID, or the unambiguous latest pending plan; ask if ambiguous. |
| `$ux plan <run-id>` | Re-plan that run's existing reports only; no review, tests or fixes. |

Current authorization can remove an already-satisfied approval stop. It never
permits treating a missing product decision as approval. A later `fix` must use
the plan the user actually approved, not whichever run happens to sort last.

## Shared sources and scope

- `.claude/skills/ux/references/loop.md`: loop, helpers and record formats.
- `.claude/skills/ux/references/guidelines.md`, and the records
  `.claude/ux-review/{DECISIONS,ISSUES,KNOWN_FAILURES,PHONE_CHECKS}.md`:
  current rules, decisions and prior outcomes. Read relevant sections.
- `.claude/agent-memory/frontend-ux-reviewer/MEMORY.md`: index to past findings;
  follow only relevant notes and verify them against current code.
- `.claude/agents/frontend-ux-reviewer.md`: domain audit criteria and report format.
- `.claude/skills/ux/SKILL.md` sections on areas, renders and device captures:
  reference tables only; use the Codex protocol for delegation and permissions.

Use Windows Git Bash from the app repo (PowerShell syntax):

```powershell
& 'C:\Program Files\Git\bin\bash.exe' .claude/skills/ux/scripts/ux.sh changed
& 'C:\Program Files\Git\bin\bash.exe' .claude/skills/ux/scripts/ux.sh keys
```

These determine changes and localized keys since `refs/ux-review/last`.
`NO_SNAPSHOT` means stop and propose `$ux app`; don't manufacture a baseline.
An empty change list means no review is needed. Don't call `save` during setup
or to acknowledge unverified work.

Map scope to **A** capture/voice, **B** calendar/tasks/planning, **C** lists/notes/
groups/sharing, **D** authentication/settings/native surfaces/theme. Use the
existing skill's area table for exact files and shared-file rules. Assign each
reviewer a new UX range using its existing formula:
`(floor(highestExistingUX / 100) + 1 + reviewerIndex) * 100 + 1`.
Check unresolved plans as well as `ISSUES.md` before reserving IDs.

## Evidence and checks

Run Flutter on Windows from `App/`. Read the shared README and known failures
before choosing commands. The main evidence suite is:

```powershell
flutter test --no-pub --dart-define=WRITE_UX_PREVIEWS=true test/ux_previews/ux_previews_test.dart
```

Read `App/build/ux/INDEX.md` and `AUDIT.md`, then view the relevant PNGs. Use
the shared skill's supplemental calendar/review/auth/form previews when they
cover the changed flow. Scope refreshes to affected previews; don't mistake
old images retained after a failing preview for fresh evidence.

Whole-app reviews and changes involving voice/native surfaces, reminders,
permissions, sharing or widgets require the separate emulator evidence lane
when available. The orchestrator first reads
`.claude/skills/ux/scripts/emulator/README.md`, then owns captures on **TaskFlow_Review**
only. Workers never operate devices. Missing emulator evidence is reported and
device-only checks stay pending; it cannot establish a pass. A personal phone
test still requires the owner. Never uninstall or clear personal app data.

The independent tester runs meaningful acceptance tests, `flutter analyze
--no-pub`, the app suite (`flutter test --no-pub`) once per round, and refreshes
the affected previews. Generate localization after ARB changes; do not hand-edit
generated Dart. Compile native changes when needed. Match known failures exactly
and report new ones. Do not start backend services or make paid AI calls as an
incidental consequence of a UI review.

Use `.claude/skills/ux/scripts/pkg.py` to retrieve packages. Only the orchestrator writes
run records, the shared issue ledger and verified memory updates, regenerates
phone checks with `phone_checks.py`, and calls `ux.sh save` after the protocol's
completion gate. Preserve the existing phone-check/issue format. Report actual
evidence type and unresolved work before claiming the round complete.
