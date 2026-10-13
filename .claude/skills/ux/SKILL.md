---
name: ux
description: Run TaskFlow's UX loop. frontend-ux-reviewer reviews what changed since the last review (or the whole app, or named screens), ux-organizer plans the fixes, ux-implementer makes them one package at a time, and the reviewer re-checks until they hold. Use when the owner types /ux, asks for a UX review of recent changes or of the app, or when CLAUDE.md's UX review step applies after user-facing work.
argument-hint: "[app | fix [skip P3 | only P1 P2] | <screens or flows>]"
---

# /ux — TaskFlow's UX loop

Invoking this skill is the owner's opt-in to running the `ux-review` and `ux-fix` workflows (decided 2026-10-13; see `.claude/ux-review/DECISIONS.md`). How the loop works: `.claude/ux-review/README.md`.

## 1. Read the argument

| Argument | Mode | What happens |
|---|---|---|
| (none) | **changes** | Review what changed since the last UX review, then fix and verify without stopping. |
| `app` | **app** | Review the whole app. Stop after the plan for the owner's approval. |
| `fix`, optionally followed by `skip P3 P7` or `only P1 P2` | — | Carry out the latest plan waiting for approval (§6). |
| `plan <run id>` | the run's mode | Plan again from the reports already in that run folder, without a new review. Use it after the owner answers decisions, or when the reviews ran outside the loop. Call `ux-review` with `reportPaths` set to the folder's `review-*.md` files, then continue as in §5. |
| anything else | **screens** | Review only the named screens or flows, then fix and verify without stopping. |

## 2. Before starting

- Check that `git branch --show-current` is `dev`. If it isn't, stop and ask.
- Check that no merge, rebase or cherry-pick is in progress.
- Name the run `<today>-<mode>`, adding `-2`, `-3` and so on if that folder already exists. The run folder is `.claude/ux-review/runs/<run id>/`.
- Handle owner decisions from this conversation:
  - add the lasting ones to `.claude/ux-review/DECISIONS.md`, dated and in the owner's words;
  - pass everything else the agents should know as `notes`. They can't see the conversation.

## 3. Work out the scope

### changes
1. Run `bash .claude/ux-review/ux.sh changed`.
   - It prints `NO_SNAPSHOT`: tell the owner there's no baseline yet, suggest `/ux app`, and stop.
   - It prints nothing: say "Nothing user-facing changed since the last UX review" (the date comes from `ux.sh status`), and stop.
2. Run `bash .claude/ux-review/ux.sh keys` to get the changed ARB keys.
   - Find where each key is shown: `grep -rln "l10n.<key>\b" App/lib`.
   - Add those files' areas.
3. Map every file to an area using the table below. Each area touched gets one reviewer. Its scope is its changed files, "and the flows and states they touch".

### screens
Map the named screens or flows to areas with the table. The scope is those screens and flows, in every state.

### app
Use all four areas, with the full scope from the table.

### Areas

| Area | Name | Files | Flows to walk (app mode) |
|---|---|---|---|
| A | Voice capture | `App/lib/widgets/task_actions.dart` (creation controls), `App/lib/screens/voice_task_screen.dart`, `review_tasks_screen.dart`, `captures_screen.dart`, `capture_diagnostics_screen.dart`, `App/lib/widgets/capture_review_editor.dart`, `App/lib/services/capture_problem.dart`, `feedback_timeout.dart`, `App/lib/l10n/capture_messages.dart`; Android `NativeSpeechBridge.kt`, `CaptureEntryBridge.kt`, `CaptureWidget.kt`, `MainActivity.kt`, `res/xml/capture_*.xml` | every way in (buttons, widget, launcher shortcuts, share), mic permission, listening, waiting (slow or failed AI, offline), clarifications, single and batch review, voice notes, save, undo, where the user lands, interrupted and unfinished captures |
| B | Calendar, home and tasks | `App/lib/screens/main_shell.dart`, `home_screen.dart`, `calendar_screen.dart`, `day_timeline_screen.dart`, `completed_tasks_screen.dart`, `task_detail_screen.dart`, `edit_task_screen.dart`, `create_task_screen.dart`; widgets `task_tile`, `task_list`, `task_schedule_label`, `task_interactions`, `device_calendar_events`, `task_editor`, `schedule_editor`, `reminder_control`, `repeat_rule_control`, `task_planning_control`, `checklist_editor`, `attachment_panel` | understand today, find a task, complete and undo, move, edit, reminder, repeat, checklist, attachment, delete and undo, typed creation, completed tasks, overdue and undated tasks, phone-calendar events |
| C | Lists, notes, groups and sharing | `App/lib/screens/task_lists_screen.dart`, `notes_screen.dart`, `list_sharing_screen.dart`, `invitation_review_screen.dart`, `groups_screen.dart`, `activity_screen.dart`; widgets `note_text`, `task_list_picker`, `task_assignment_picker`, `project_scope_control`, `project_preferences` | the Tasks tab compared with Calendar, projects, notes, sharing and invitations, groups, activity, archiving |
| D | First run, sign-in, settings, notifications, native surfaces and theme | `App/lib/screens/login_screen.dart`, `settings_screen.dart`, `account_screen.dart`, `regional_settings_screen.dart`, `notification_settings_screen.dart`, `device_calendars_screen.dart`, `data_transfer_screen.dart`, `subscription_screen.dart`; widgets `google_login_button`, `language_selector`, `app_components`, `custom_app_bar`; `App/lib/theme/`; `App/lib/services/reminder_copy.dart`, `notification_service.dart`; `App/android/app/src/main/res/values*/strings.xml`; `App/ios/Runner/Info.plist` and `*.lproj/`; `App/assets/` | install to first screen, sign-in, sign-up and recovery, settings, reminders and notifications, native strings and permissions, theme contrast and type at 2× |

Shared files:
- `App/lib/main.dart` belongs to the area whose routes or entry points the diff touches; if unclear, B.
- ARB files belong to the areas of the screens that show the changed keys.
- `App/lib/l10n/*.dart` (not `generated/`) belongs to the areas that use it.
- A new file belongs to the area it fits by what it shows.

### ID ranges
- Let H be the highest UX number in `.claude/ux-review/ISSUES.md`. Find it with `grep -oE 'UX-[0-9]+' .claude/ux-review/ISSUES.md | sort -t- -k2 -n | tail -1`.
- Reviewer k (0-based) gets `idStart = (floor(H / 100) + 1 + k) * 100 + 1`.

## 4. Render the previews

Run these from `App/`, one after another, before any reviewer starts:

```
flutter test --no-pub --dart-define=WRITE_CALENDAR_PREVIEWS=true test/calendar_feedback_test.dart
flutter test --no-pub --dart-define=WRITE_REVIEW_PREVIEWS=true test/review_tasks_test.dart
flutter test --no-pub --dart-define=WRITE_AUTH_PREVIEWS=true test/auth_gate_test.dart
```

The third command fails after writing its PNGs; that's expected (see `KNOWN_FAILURES.md`). If a preview fails in any other way, mention it, but keep going: previews are evidence, not a gate.

## 5. Review and plan — workflow `ux-review`

Call the Workflow tool with `scriptPath` set to the absolute path of `.claude/workflows/ux-review.js` (the repo root comes from `git rev-parse --show-toplevel`). Don't use `name`: saved workflows are only looked up by name if they existed when the session started. Pass these args:

```
{ runId, runDir, date, mode,
  slices: [{ key, name, scope, idStart }],
  changedKeys,
  notes }
```

When it returns:
- **`plan` is null** (no findings): run `bash .claude/ux-review/ux.sh save`, tell the owner, and stop.
- **app mode:**
  1. Run `bash .claude/ux-review/ux.sh save`.
  2. Show the owner:
     - each area's verdict;
     - the counts;
     - the decisions, with the organizer's recommendations;
     - the packages, one line each;
     - a link to `plan.md`.
  3. Stop. The owner approves ("go"), strikes packages, or answers decisions.
  4. Record their answers in `DECISIONS.md`. If an answer unblocks findings, run `/ux plan <run id>`, so those findings become packages.
  5. Then go to §6.
- **changes or screens mode:** go straight on to §6.

## 6. Fix and verify — workflow `ux-fix`

1. **Make the starting point.** If `git status --porcelain` shows uncommitted user-facing changes, commit exactly those files first, so the round's own commit can be reverted on its own. Message: `Changes reviewed by the UX loop (<run id>)`, plus the attribution line.
2. **Run the workflow.** Call the Workflow tool with `scriptPath` set to the absolute path of `.claude/workflows/ux-fix.js`, and args `{ runId, runDir, date, skip, only, batch, notes }`. Set `batch` (for example `trial`, then `main`) when a plan runs in several batches, so each batch keeps its own report and verify files. For `/ux fix`, the run folder is the newest one under `runs/` that has a `plan.json` but no `report.md`.
3. **When it returns:**
   - **`testsPassed` is true:** commit the round.
     - Stage it: `git add -- <filesChanged> .claude/ux-review .claude/agent-memory`.
     - Subject: `UX loop <run id>: <n> fixes verified`.
     - Body: the verified IDs, then the IDs still open, each with a short reason.
     - End with the attribution line.
   - **`testsPassed` is false:** don't commit. Tell the owner which checks fail, and that the changes are left uncommitted for them to look at.
   - Either way, run `bash .claude/ux-review/ux.sh save` afterwards.

Never push. Never commit on `main`. Never skip hooks.

## 7. Tell the owner

Keep it short; the details live in `report.md`.
- The verdict, in one line.
- What was fixed and verified: up to five IDs with titles, then "and N more".
- What's still open, what was escalated, and the decisions needed, each with its question.
- Checks to do on a phone.
- Links to `report.md`, `ISSUES.md` and the commit.

## Size and cost

- **Scoped run, one area:** 1 reviewer, 1 organizer, 1–3 implementers, 1 tester, 1 verifier, 2 recording steps. That's about 7–8 agents.
- **Whole app:** 4 reviewers and 1 organizer, then one implementer per approved package, one tester per round, and one verifier per area touched. A large plan can take hours.

Models and effort are set in each agent's frontmatter in `.claude/agents/`.
