# Projects, groups and responsible tasks

Accepted direction: keep Calendar as the starting point, evolve existing lists into
projects, add reusable groups and task responsibility, and extend reviewed voice
capture. All AI/voice processing requires a paid entitlement. Existing personal
data, offline queues, invitations and files must be preserved.

## Completion checklist

- [x] Personal/shared projects: create, rename, colour, pin, archive, search; no
      arbitrary project-count cap; preserve existing lists and Inbox.
- [x] Reusable groups: invitations, owner/admin/editor/viewer permissions, member
      management, leaving and ownership transfer across every group project.
- [x] Responsibility: personal, a member, the whole group, and explicit reassignment
      needed after a member leaves. Shared visibility is independent of assignee.
- [x] One completion per shared task, with existing recurring occurrence semantics.
- [x] Voice: project/member context, several independently assigned drafts, dates
      without invented times, clarification for ambiguous or inaccessible targets.
- [x] Review: editable project/responsibility/deadline, visible audience, explicit
      save before creating/sharing anything.
- [x] Interface: compact project selector, personal/team scope, unobtrusive task
      metadata, direct membership entry, existing navigation retained.
- [x] Collaboration updates: assignment/change activity, account-scoped inbox,
      per-project notification preference and no duplicate events on retries.
- [x] Reliability: backend authorization, version conflicts, account-scoped offline
      data, revoked-access cleanup, file authorization and transfer quota checks.
- [x] Paid access: backend RevenueCat verification, bounded usage, expired/revoked
      entitlement handling, production-safe development testing.
- [x] English, Spanish and Catalan; accessible controls and light/dark layouts.
- [x] Tests: backend permissions/lifecycle/concurrency, Flutter persistence/widgets,
      real Docker API and Android integration, rendered UI, regression suite.

## Decisions

- A group contains people; a project belongs to one group or is personal.
- Existing `TaskList` IDs and `/lists/` endpoints remain stable for sync. The user
  interface calls them projects. Legacy directly shared projects retain access.
- Group projects inherit group membership. Assignment never changes visibility.
- A task has one responsible member or the entire group. Per-person independent
  completion and nested projects are outside this release.
- A removed assignee leaves a visible unassigned task; their content is preserved.
- Invitations remain email-bound and require a separately shared code, because
  password account creation does not yet verify email ownership.
- Enterprise SSO, approval chains and organization hierarchies remain future work.
- Prices and new RevenueCat products have not been agreed; do not invent a public
  team price or publish new subscription products as part of implementation.

## Evidence and remaining work

Implemented on `dev`, with the updated Django API running in local Docker.
No production deployment or new subscription product/price was made.

### Data and authorization

- Django migrations 0015/0016 preserve existing project IDs and tasks. Android
  SQLite upgrades through schema 17 preserve offline edits, files and schedules.
- Groups provide owner/admin/editor/viewer roles, email-and-code invitations,
  revocation, leaving and ownership transfer. Group projects inherit membership.
- Assignment is `personal`, `member`, `group` or `unassigned`. A removed or
  downgraded assignee leaves an unassigned task; editing access and visibility
  are independently enforced by Django. Everyone sees the same completion.
- Lost membership clears cached shared data on successful sync. An invalid
  assignment or concurrent change preserves permitted unsent work privately.
- Archived groups keep content accessible in their project pages while removing
  it from the default daily scope, capture context and scheduled reminders.
- Activity is an in-app inbox plus task history, with actor, version and change
  metadata. Notification preference is per account/project (all/assigned/muted).
  This release does not add a remote push-delivery service.

### Interface and capture

- Calendar stays first. A compact selector groups pinned, personal and group
  projects, supports search, and opens project management directly.
- For me includes personal tasks, tasks assigned to me, group responsibilities,
  and unassigned tasks for project managers. Team shows other assignments too.
- Project and responsibility controls appear in creation, task details and voice
  review, with an explicit audience label. Selecting a responsible person does
  not make a shared task private. Viewers cannot receive responsibility.
- Group pages expose members, invitations, roles, new project creation and owner
  actions directly. All new UI is localized in English, Spanish and Catalan.
- Capture sends the chosen project as context. The model receives a bounded
  permitted directory; the server resolves names against authoritative access.
  Duplicate/unknown/inaccessible targets require explicit review. AI never
  creates or shares a task before the user saves the reviewed drafts.
- All recorder entry points and AI extraction require Pro. Manual tasks/notes
  remain available. Server verification uses the authenticated user's opaque
  RevenueCat billing ID, never a client entitlement claim. Production rejects
  Test Store keys and sandbox grants. Cache TTL is at most 30 seconds and never
  extends paid expiry; provider failures fail closed.

### Verified on 2026-10-11

- Full PostgreSQL core suite: **156 passed**, including permissions, ownership,
  attachments, isolation, paid access, actual database concurrency, group archive
  propagation and 18 AI routing/adapter checks.
- Full Flutter regression suite: **271 passed**. Includes migration, offline
  assignment recovery, reminders, ambiguity, paid recorder gating, sync,
  localization and widget tests. Small screens and large text checked in all
  three languages and both themes.
- `flutter analyze`: no issues.
- Local HTTP flow with three isolated accounts: invitation/code validation,
  member assignment, shared completion/reopening, actor history, outsider
  rejection, preferences, notifications and unpaid AI rejection passed.
- Real RevenueCat Test Store purchase and server verification passed. The new
  isolated test identity was added to the existing sandbox allowlist; existing
  entries and the restricted policy were preserved. No real payment occurred.
- Android API 36.1 emulator: real login, native RevenueCat entitlement, SQLite
  sync, For me/Team filtering, group screens, new group project creation,
  synthetic recorded audio upload, real transcription/extraction, member/group
  review, explicit save, persisted offline reassignment, second-account isolation
  and notification retrieval **passed**. Light/dark screenshots were captured
  and inspected. The full run uses live AI, with no substituted provider result.
- A generated 16 kHz PCM WAV passed both the direct task API and the Android
  upload/review/save flow. Both tasks resolve to Physics, with Ana responsible
  for exercise three and the whole group responsible for the presentation;
  deadlines are 15/16 October with no invented times. A separate live text
  request also passes these exact assertions. No user microphone was recorded.
- Real Vertex fallback probes pass for text and audio. Only the free-provider
  429 is simulated; ADC impersonation, Vertex transcription/extraction and
  validation are real. Each stage makes exactly one paid attempt. These probes
  create no tasks; Android checks explicit saving separately.

Logs under ignored `App/build/`:

- `projects-regression-final.log`
- `projects-postgres-final.log`
- `projects-android-final.log`
- `projects-live-api.log`, `projects-live-billing.log`
- `projects-live-transcription.log`, `projects-analyze-final.log`
- `projects-vertex-postgres.log`, `projects-vertex-analyze.log`
- `projects-vertex-live.log`, `projects-vertex-audio.log`
- `projects-vertex-fallback.log`, `projects-vertex-fallback-audio.log`
- `projects-android-vertex-audio.log`

Rendered Android evidence under ignored `App/artifacts/design/`:

- `projects-calendar-light.png`
- `projects-team-light.png`
- `projects-task-responsibility.png`
- `projects-members-light.png`, `projects-members-dark.png`
- `projects-voice-review-dark.png`

### Provider reliability

With the user's approval, development now uses AI Studio `gemma-4-26b-a4b-it`
first and Vertex `gemini-3.1-flash-lite` on quota or temporary failures. The older
31B outage logs remain historical failures, not successful evidence. The new
free-first live tests and real paid fallback probes pass. See the
[backend guide](../../Backend/README.md) for bounded retries, cooldowns, IAM,
free-only/direct-Vertex modes and setup scripts. LangChain remains the pipeline.

These checks establish the synthetic collaboration workflow, not universal
recognition accuracy or a provider availability guarantee. Ambiguous targets
still require review; authorization and schema validation remain mandatory.
Physical-device microphone quality and broader language/accuracy evaluations
are distinct from this emulator and synthetic-WAV check.

### Reproducing the isolated live test

From the repository root (Python 3, local Docker API running):

```powershell
python Backend/scripts/validate_projects.py --test-key <public-test-store-sdk-key>
```

This creates synthetic accounts and a reusable fixture at
`App/build/project-e2e.json`. The fixture contains test passwords; it is ignored
by Git. RevenueCat must allow that account's opaque billing ID before it can
receive sandbox entitlements. The script never accepts real store keys.

After allowlisting, retry the same account with `--billing-only`. Add `--skip-ai`
only when refreshing a test subscription without claiming extraction coverage.
Each billing run simulates a new Test Store purchase; it does not charge money.
The API scripts supply a fixed Sunday reference and check the exact Thursday
and Friday deadlines, including the absence of invented times.

From `App`, `scripts/test-projects.ps1` supplies the data-preserving driver flags
(`-SkipAI` is available for collaboration-only checks). The equivalent command
with an available Android emulator is:

```powershell
flutter drive --keep-app-running --driver=test_driver/appearance_test.dart --target=integration_test/projects_flow_test.dart -d emulator-5556 --dart-define-from-file=config/development.json --dart-define-from-file=build/project-e2e.json
```

For the audio version, serve **only a synthetic WAV** from an isolated directory
on a local HTTP/1.1 server, then pass
`scripts/test-projects.ps1 -AudioUrl http://10.0.2.2:8099/projects-synthetic.wav`.
Never serve the fixture directory containing test passwords. The test copies
that WAV into Android's private capture storage and uses the actual upload,
processing, review and saving flow. Its fixture replaces microphone input only.

`--dart-define=PROJECT_E2E_AI=false` runs collaboration without AI; the default
requires a real provider response. The test isolates session preferences in
memory, uses real Android SQLite/API/RevenueCat, and restores the earlier
RevenueCat identity and reminder owner. Always use `--keep-app-running`: Flutter
drive otherwise uninstalls the app and clears that installation’s data. The first
two project driver runs omitted this flag and reset emulator-5556’s installation;
server data was retained and a normal debug build was reinstalled. No user
microphone recording was taken.

### Server configuration

Use `REVENUECAT_API_KEY` with the platform's public SDK key.
`DEPLOYMENT_ENVIRONMENT=development` **and** `REVENUECAT_ALLOW_SANDBOX=1` are both
required for local Test Store grants. Production defaults reject them.
`GET /api/billing/access/` reads access; `POST` forces a fresh provider check
after a purchase. `/api/ai/draft/` and `/api/ai/drafts/` require the entitlement
before reserving AI budget or calling a model.

References:

- https://www.revenuecat.com/docs/api-v1/customers
- https://www.revenuecat.com/docs/api-v1/customer-info-model
- https://www.revenuecat.com/docs/projects/sandbox-access
- https://github.com/RevenueCat/cli (official Test Store receipt flow)
