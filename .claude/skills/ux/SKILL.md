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
3. Map every file to an area using the table below. Each area touched gets one reviewer. Its scope is its changed files, "and the flows and states they touch". An area with more than about 10 changed files gets two reviewers instead (keys `A1` and `A2`, and so on), each with half its files, grouped by screen.

### screens
Map the named screens or flows to areas with the table. The scope is those screens and flows, in every state.

### app
Use all four areas, with the full scope from the table. The two largest get two reviewers each (owner, 2026-10-21), so the review takes about half as long. That makes six reviewers side by side:
- **A1 · Ways in and listening:** every way in (buttons, widget, launcher shortcuts, share), mic permission, listening, waiting (slow or failed AI, offline), interrupted and unfinished captures.
- **A2 · The result:** clarifications, single and batch review, voice notes, voice commands, save, undo, where the user lands.
- **B1 · Today and the calendar:** understand today, the calendar and the day timeline, overdue and undated tasks, phone-calendar events, completed tasks.
- **B2 · One task:** find a task, complete and undo, move, edit, reminder, repeat, checklist, attachment, delete and undo, typed creation.
- **C** and **D** as in the table.

Each half reads the files of its flows. Packages still take the area's letter; the workflow tells the organizer.

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
flutter test --no-pub --dart-define=WRITE_UX_PREVIEWS=true test/ux_previews/ux_previews_test.dart
flutter test --no-pub --dart-define=WRITE_CALENDAR_PREVIEWS=true test/calendar_feedback_test.dart
flutter test --no-pub --dart-define=WRITE_REVIEW_PREVIEWS=true test/review_tasks_test.dart
flutter test --no-pub --dart-define=WRITE_AUTH_PREVIEWS=true test/auth_gate_test.dart
```

The first is the UX preview suite. It renders every route and tab in its key states to `App/build/ux/<area>/`, and writes `App/build/ux/INDEX.md` (what each PNG shows, its sources and when it was rendered) and `App/build/ux/AUDIT.md` (measured accessibility, clipping and tap-target evidence for each one). It takes about two and a half minutes for about 300 PNGs. A preview whose flow fails keeps its earlier render, and INDEX.md shows that render's older time.

The fourth command fails after writing its PNGs; that's expected (see `KNOWN_FAILURES.md`). If a preview fails in any other way, mention it, but keep going: previews are evidence, not a gate.

### Device captures

Previews can't draw what Android draws around the app. Capture it from the separate `TaskFlow_Review` test emulator, never from the owner's phone or his own emulators. How the lane works, and its safety rules: `.claude/ux-review/emulator/README.md`.

- **When:**
  - always in **app** mode;
  - otherwise, whenever the scope includes native surfaces, notifications or reminders, permissions, the home-screen widget, launcher shortcuts or sharing. In practice that's area A or D, or any file under `App/android/` or `App/ios/`.
- **How:** after the previews, run from the repo root:

  ```
  python .claude/ux-review/emulator/capture.py
  ```

  - It builds the review APK from the working tree, installs it on `TaskFlow_Review` and writes `App/build/ux/device/`, with its own `INDEX.md`. The preview suite leaves that folder alone.
  - For a scoped run, pass only the sections in scope: for example `--only journey,launcher,widget,share` for area A, or `--only journey,calendar-permission,notifications` for area D. Add `languages` when English or Catalan copy on those surfaces changed.
  - `--apk <path>` installs an APK that's already built. If the build fails with "requires symlink support", run the command from PowerShell, or build there and pass `--apk`.
- **Time:** a full run takes about an hour, longer when the machine is busy, so start it in the background and keep working. A scoped run takes 2–4 minutes to boot the emulator and install, plus its sections: 1–10 minutes each, and 21–25 for `languages`. Per-section times are in the lane's README.
  - Check on it with short commands, such as the last lines of its output; never wait on it in one long blocking call.
  - If its output hasn't moved for about 8 minutes, stop it, run `python .claude/ux-review/emulator/capture.py stop`, and report what wasn't captured. (The notifications section says "waiting" and then waits about 5 minutes for its reminders.)
- **If the emulator can't start or the run fails,** carry on without it.
  - Say so in `notes`, for example "No device captures this run: <reason>", and in the report to the owner.
  - Device-only checks stay on the phone list.
- **Tell the reviewers** in `notes` which sections were captured, and when. Their evidence level is "emulator", not "physical phone".

## 5. Review and plan — workflow `ux-review`

Call the Workflow tool with `scriptPath` set to the absolute path of `.claude/workflows/ux-review.js` (the repo root comes from `git rev-parse --show-toplevel`). Don't use `name`: saved workflows are only looked up by name if they existed when the session started. Pass these args:

```
{ runId, runDir, date, mode,
  slices: [{ key, name, scope, idStart }],
  changedKeys,
  notes }
```

When it returns:
- **`inlineReports` isn't empty:** a reviewer wasn't allowed to save its report. Write each `text` to its `path`.
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
2. **Run the workflow.** First:
   - Keep the PC awake while it runs. In the desktop app, call `mcp__ccd_host__request_keep_awake` with `until: "session_idle"`. The longest runs so far each lost 2–4 hours to a sleeping or restarting laptop.
   - Packages that share no file run side by side, each in its own worktree: up to 12 at once, even while a `ux-web-fix` run is going (owner, 2026-10-21). The machine is protected by the gate, not by the agent count: heavy commands run 3 at a time. How waves work: `.claude/ux-review/README.md`, step 5.

   Then call the Workflow tool with `scriptPath` set to the absolute path of `.claude/workflows/ux-fix.js`, and args `{ runId, runDir, date, repoRoot, maxParallel, heavySlots, skip, only, batch, notes }`:
   - `repoRoot` is `git rev-parse --show-toplevel`, with forward slashes. Without it, every package runs in the main checkout, one at a time.
   - `maxParallel` is 12. `heavySlots` is 3.
   - Set `batch` (for example `trial`, then `main`) when a plan runs in several batches, so each batch keeps its own report and verify files. For `/ux fix`, the run folder is the newest one under `runs/` that has a `plan.json` but no `report.md`.
3. **When it returns:**
   - **Save the report.** Write `close.report` to `<runDir>/<reportName>`. Subagents may not write report files, so the organizer returns the text.
   - **`testsPassed` is true:** commit the round.
     - Stage it: `git add -- <filesChanged> .claude/ux-review .claude/agent-memory`.
     - Subject: `UX loop <run id>: <n> fixes verified`.
     - Body: the verified IDs, then the IDs still open, each with a short reason.
     - End with the attribution line.
   - **`testsPassed` is false:** don't commit. Tell the owner which checks fail, and that the changes are left uncommitted for them to look at.
   - Either way, run `bash .claude/ux-review/ux.sh save` afterwards.

Never push. Never commit on `main`. Never skip hooks.

### Big plans run in batches

A plan with more than about 16 packages runs in batches of about 12, in plan order. Waves make a batch's width, not its length, the cost, so batches are bigger than before 2026-10-21 (they were 5).
- Each batch is one `ux-fix` run, with `only` set to the batch's packages and `batch` set to `b1`, `b2`, and so on.
- Set `recordMemory: false` on every batch except the last, so the reviewer updates its memory once per plan.
- After each batch: save its report, commit, run `ux.sh save`, then start the next batch.
- Don't wait for the owner between batches.
- Stop and tell the owner if a batch's tests fail, or if it escalates more than two findings.

Batching catches regressions while they're still small, and it gives one commit per batch. Testers and verifiers stay focused anyway: packages done side by side get a tester each, and a verifier checks at most 4 packages.

The first real `ux-fix` run (2026-10-13, 2 small packages, 3 rounds) took about 110 minutes and 1.9M tokens. Expect a batch of 5 to take a few hours.

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
