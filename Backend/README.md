# TaskFlow backend

Private Cloud Run + Neon staging is deployed. See [staging access, rebuild,
email, secrets and cost boundaries](docs/STAGING.md). Local Docker remains
available for development as described below.

All development is on `dev`. The Flutter app requires an account and opens on Calendar. Manual tasks and notes are always available. Without a verified `taskflow_pro` entitlement, an account gets 10 free AI dictations per UTC calendar month and 100 MiB of file storage in total; Pro removes both limits. Projects can be personal or shared through reusable groups. See the [implementation and validation record](../App/docs/PROJECTS_IMPLEMENTATION.md).

The repository has two project directories: `App/` contains Flutter, and `Backend/` contains Django, Docker Compose, environment files, and this guide. Git metadata remains at the repository root.

## Start the backend

From `Backend/` (`cd Backend` at the repository root), with Docker Desktop running:

```powershell
docker compose up -d --build
docker compose ps
```

- Local browser workspace: <http://localhost:8088/>
- Health check: <http://localhost:8088/api/health/>
- Password recovery test inbox: <http://localhost:8026/>

Compose runs Django/Gunicorn, PostgreSQL, Redis, and Mailpit. PostgreSQL and Redis have persistent volumes and no published database ports. The API uses port 8088 to avoid the other services already running on this computer. Mailpit is accessible only from localhost.

### Development AI: free first, Vertex fallback

From `Backend`, the configured development flow is:

```powershell
# One-time, with the personal TaskFlow Google account:
./scripts/setup-vertex.ps1
./scripts/login-vertex.ps1
# Start/restart the backend with free-first routing:
./scripts/start-ai-dev.ps1 -Mode auto
```

The scripts target `taskflow-511107` explicitly without changing global gcloud
account/project settings. `setup-vertex.ps1` is idempotent: it creates the staging
service account and a custom role limited to model prediction and API usage.
The selected developer can impersonate that account. `login-vertex.ps1` writes
isolated Application Default Credentials under ignored `.credentials/gcloud`.
Choose `tech.garbar@gmail.com` in Google's browser chooser. Re-run login if its
source authorization expires. No service-account key or GPU endpoint is created.

`compose.vertex.yaml` mounts just the ADC file read-only into the API container;
Git and Docker both exclude `.credentials`. The ADC contains a sensitive local
source refresh credential: do not share it or use it in a deployed image. For
Cloud Run, attach a dedicated runtime service account instead of mounting local
ADC. Flutter only talks to the authenticated Django API.

| Mode | Behaviour |
| --- | --- |
| `auto` | AI Studio first; bounded retries, then paid Vertex on quota/temporary failures. |
| `vertex` | Direct Vertex for predictable development demonstrations. |
| `ai_studio` | AI Studio only; never makes a Vertex call. |

Switch with `scripts/start-ai-dev.ps1 -Mode vertex` (or another mode).
Plain `docker compose up` uses the base configuration and free-only default;
use the script whenever the ADC-mounted Vertex route is wanted. Existing volumes
and accounts are preserved. The optional overlay does not deploy a public API.

`Backend/.env` holds the local secrets (the Google key, the Django secret and the local database credentials) and is never committed: `.gitignore` excludes every `.env` file except `.env.example` and `.env.ci`. On a new machine, copy `Backend/.env.example` to `Backend/.env` and fill it in. Docker injects these at runtime; `.dockerignore` excludes the environment files from the image build context, and the Flutter APK does not contain the key. GitHub Actions runs the tests with the committed `Backend/.env.ci`, which has no real keys, and deploys staging with keyless Google sign-in and the runtime config in Google Secret Manager, so no workflow needs a file from the PC.

The Compose project name stays `taskflow`, so moving the files does not replace the existing PostgreSQL or Redis data volumes. You can also run Compose from the repository root with `docker compose -f Backend/compose.yaml up -d --build`.

Stop services with `docker compose stop`. `docker compose down` also preserves the data volumes; adding `-v` deletes their data.

## Android emulator and phone

Android toolchain: Flutter 3.44 / Dart 3.12, JDK 26, Gradle 9.7.1, Android Gradle Plugin 9.4.1 and Kotlin 2.4.20. The Gradle JVM criteria pin Java 26 for consistent editor and Flutter builds. See [the app setup guide](../App/README.md#getting-started) for JDK and VS Code settings.

Run Flutter commands from `App/` (`cd App` at the repository root):

```powershell
flutter pub get
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8088
```

`10.0.2.2` is the Android emulator's address for the host computer. Calendar's microphone button starts capture without requiring sign-in. Grant microphone permission to record, or type a description on the capture screen. Recordings are limited to 60 seconds; each capture can create up to 12 drafts, reviewed together before saving.

On a physical Android phone:

1. Connect the phone and computer to the same Wi-Fi.
2. Find the computer's IPv4 address with `ipconfig`.
3. Add that exact IP to `DJANGO_ALLOWED_HOSTS` in `Backend/.env` if it is not already there, then run `docker compose up -d --force-recreate api` from `Backend/`.
4. On the debug login screen → Connection settings, use `http://COMPUTER_IP:8088`. Use the debug APK for local HTTP. If Windows Firewall blocks the port, allow it on your private network.

You can also pass the address using `--dart-define=API_BASE_URL=...`. Runtime connection settings are stored on the device and take precedence. Sign out before changing servers. Release builds require HTTPS; local HTTP is enabled only in the Android debug manifest.

Build the local test APK from `App/`:

```powershell
flutter build apk --debug
# Smaller package for most current phones:
flutter build apk --debug --target-platform=android-arm64
# Smaller package for this emulator:
flutter build apk --debug --target-platform=android-x64
```

Output relative to the repository root: `App/build/app/outputs/flutter-apk/app-debug.apk`.
Each command writes `app-debug.apk`, so copy the phone build before building for the emulator. Selecting one target platform keeps packages smaller without changing their version code. Avoid `--split-per-abi` for local test installations: Flutter adds an ABI-specific version offset, and a subsequent normal test build can trigger a downgrade/uninstall that clears local data. The current development version is `1.0.0+4002`.

The real Android flow can also be checked from `App/` with `flutter test integration_test/backend_flow_test.dart -d emulator-5554`. This checks the login gate, creates a synthetic account, resumes unfinished account captures, reviews and saves multiple tasks, verifies backup, and signs out and back in. It removes its temporary Inbox tasks afterward. It does not record the microphone.

## Accounts and recovery

For repeat testing, use **Use test account** on the local browser page. In the Android development build, tap **Use test account** on the login screen. The shortcut uses `app-test@taskflow.local` and the password from `App/config/development.json`, which must match `LOCAL_TEST_ACCOUNT_PASSWORD` in `Backend/.env`; the app saves the normal session in secure storage. The shortcut is absent from profile/release builds and debug builds without the opt-in. Both clients use the same account and tasks. This account starts empty; later tasks are preserved. The earlier `test@taskflow.local` account and its data have been left intact.

The local `.env` enables this with `LOCAL_TEST_ACCOUNT_ENABLED=1`. Docker startup runs `python manage.py seed_test_user`, which creates a regular user once and preserves its password and tasks on subsequent starts. The shortcut uses the normal JWT login endpoint. Test-account seeding and the browser shortcut are disabled by default in `.env.example`; their email and password are configured with `LOCAL_TEST_ACCOUNT_EMAIL` and `LOCAL_TEST_ACCOUNT_PASSWORD`.

Use an email address and a password of at least 12 characters. Passwords use Argon2 hashing and Django's common-password and similarity checks. Access tokens last 10 minutes; refresh tokens rotate and last 7 days. Tokens are stored in the phone's secure storage. Server session checks revoke both access and refresh tokens immediately on an online logout or password reset. Offline logout removes the device credentials; the server session expires normally.

Login has IP throttling and a 15-minute account lock after 5 failed attempts. Recovery responses do not reveal whether an email is registered. Recovery codes have 6 digits, last 30 minutes, are single-use and lock after 5 wrong tries ([password recovery](docs/PASSWORD_RECOVERY.md)). Resetting a password revokes existing sessions.

The Flutter app requires login before Calendar, tasks, notes, voice capture or subscription screens. A saved account can reopen its cached data offline. Sign-out clears the protected navigation stack and credentials without deleting account caches; a server-rejected refresh token also returns to login. Connection failures do not sign the user out. Google sign-in verifies email ownership; password registration does not yet verify email, so requiring an account is only one layer of abuse protection.

For local recovery, choose Forgot password in the app, or type the email and a new password on the browser page and choose Recover account. Open Mailpit on the computer and type the 6-digit code from the email. Email is captured locally; nothing is sent to a real mailbox. A public deployment needs HTTPS and a real email service; email verification is not part of this local prototype.

## Task storage and sync

- Guest tasks stay in the original SQLite database. The migration preserves existing tasks and attachments.
- Signed-in accounts have separate local caches, scoped by both backend address and user ID. Titles, schedules, repetition rules, per-occurrence completion, priorities and notes sync to PostgreSQL.
- Existing guest tasks are imported only by choosing **Import local tasks** in Account. The import moves them once into the selected account.
- Newly attached files in signed-in tasks queue for upload after the task is saved. Task details show local, queued, backed-up, downloadable and removal-pending states. Guest files and older device-only files remain local until explicitly uploaded from task details; importing guest tasks does not upload their files automatically.
- Each file is limited to 6 MiB, each task to 20 uploaded files, and each account to 1,000 active files. Without Pro, an account or list owner also has 100 MiB in total (`FREE_ATTACHMENT_MB`). Over it, files stay readable and removable; new uploads get HTTP 400 `storage_full`, with `shared` and, for the uploader's own storage, a `storage` block. Transfers use stable UUIDs and SHA-256 checks; interrupted uploads retry without duplicating files. Downloads are explicit and verified before they become available locally. An upload error does not undo the saved task.
- Files are private to the task's account or current shared-list members, stored in the `taskflow_media` Docker volume at `/app/private_media`, and served only through authenticated endpoints. Original filenames are metadata; no public storage URL is exposed. Shared-list files use the list owner's storage quota. Removing an attachment/task or revoking membership removes download access. This local volume is persistence across container recreation, not an off-host backup service.
- Changes are saved locally first. Sync runs after changes, on app launch, when Calendar resumes, and when you press Sync. Offline changes wait in the local queue.
- UUIDs make retries idempotent. Version checks prevent overwriting another device's updates. Conflicting edits are kept as an **offline copy**, ready for the next sync. Conflicting deletions are cancelled so a newer remote edit is preserved. The Calendar/Account sync message explains conflicts or connection failures.
- Deletions are stored as server tombstones so other devices also remove the task. Task history records creation, updates, and deletion without copying task contents into logs.
- Reminder notifications are rebuilt for the current account. Old tasks are no longer silently purged at startup.

Shared lists support owner, editor and viewer roles. Owners issue email-bound invitations with a single-display code that must be shared separately; recipients enter it in Lists to accept within seven days. No invitation email is sent. Owners manage membership and deletion; editors modify tasks/files; viewers read. A complete access snapshot is fetched before queued writes. Downgraded edits and conflicts become personal copies; removal/leave purges group caches and downloaded copies at the next successful refresh. Prior exports and offline devices cannot be remotely erased. See [sharing validation](../App/docs/SHARING_VALIDATION.md) for scope and the real two-account checks.

Standalone notes use the same UUID/version, list membership and attachment protections. `kind` is `task` by default for older clients and `note` for explicitly captured reference material. A saved item's type cannot be changed silently. Notes have title/body, optional checklist/labels/list/files, without task dates, duration, recurrence, priority changes, reminders or whole-note completion. The phone checks server support before uploading notes. Version 2 TaskFlow exports preserve both types; version 1 task exports remain importable.

## Voice and AI

Tasks can have no schedule (Inbox), a date without a time (Any time), or a date and time. Date-only schedules use `scheduled_date`, which does not shift with time zones. Timed tasks use `due_date`; these fields are mutually exclusive. Existing SQLite and PostgreSQL timestamps are preserved by the migrations.

Repetition supports daily, weekly, monthly and yearly schedules, intervals from 1 to 99, selected weekdays, and an optional inclusive end date. Individual occurrences can be moved, skipped or reset; their original date retains checklist/completion/reminder identity. The calendar projects one series without duplicate successors. Monthly tasks anchored on the 31st clamp to shorter months and return to the 31st afterward. Tasks shows the next open occurrence; previous occurrences remain in Calendar and completed ones in Completed tasks. Whole-series changes remain explicit. Ordinal rules such as the first Monday and holiday calendars remain unsupported.

Settings includes versioned TaskFlow JSON export/import, conservative Todoist CSV import with preview, and English/Spanish core UI with device-aware clock/week preferences. Archives include attachment filenames but not file bytes or private paths. Imported task copies require their own attachments. See the validation documents in `App/docs` for feature scope and remaining device/provider checks.

Reminders are independent of priority. Each task can follow an editable device default, choose an explicit lead time, or turn alerts off. Date-only tasks need an explicit alert time or a configured date-only default; Inbox tasks have no alert. Notifications are opt-in from Settings, where permission, precise-alarm access, upcoming alerts, failures and the scheduling window are visible. Device preferences are account-scoped; task choices sync.

The scheduler keeps stable alert identities, preserves snoozes, rejects stale notification actions after schedule changes, and completes the notified recurring occurrence only. Optional daily check-ins use generic wording rather than stale task-title summaries. A rolling year of recurrence is projected, with the earliest 400 alerts on Android / 60 on iOS queued (including check-ins). Android WorkManager requests an hourly replenishment; app launch, resume and edits also refresh the window. Background scheduling is subject to OS battery and force-stop restrictions. iOS background configuration is included but requires validation on Apple hardware. Accepted schedules are not proof of notification delivery.

The bounded LangChain pipeline is:

```text
WAV recording → Gemini transcription → Gemma extraction → validation → review/edit/remove drafts → save together
Typed text ────────────────────────────┘
```

AI Studio defaults are `gemini-3.5-transcribe` for transcription and `gemma-4-26b-a4b-it` for extraction. The 26B model replaces the intermittent 31B model with the user's approval. Vertex uses `gemini-3.1-flash-lite` for either stage. Environment settings select each model and route; recreate the API container to apply them. LangChain core composes prompt construction, generation and Pydantic validation. Google's official Gen AI SDK handles each provider call underneath that pipeline. LangGraph, agent loops, model tools and LangSmith tracing are not needed or enabled.

Vertex receives a supported generation schema with explicit assignment enums;
Pydantic still checks the complete response on both routes. This prevents a
model response from bypassing task, date, membership or assignment validation.
Models propose drafts only; database writes require explicit app review/save.

The request includes an IANA time zone and a reference time, so “Friday” is resolved in the user's calendar. Drafts contain titles, optional dates/times, recurrence, priorities, notes and clarification questions. Omitted dates mean Inbox; omitted times mean Any time. Ambiguous times and daylight-saving gaps/overlaps require editing or explicit confirmation. Medical appointments and treatment default to high priority; explicit user priorities take precedence. Preparation notes remain with their appointment. Unsupported recurrence patterns are flagged rather than silently approximated. Drafts are not automatically saved: the app lets you edit/remove each one, then saves all remaining tasks in one SQLite transaction. A failed batch saves none. Signed-in batches enter the existing per-task sync queue.

Audio is accepted only as a validated 16-bit PCM WAV, up to 60 seconds and 6 MB. The phone keeps unfinished recordings, source text and drafts in account-scoped local storage so failures and interruptions can be recovered from Unfinished captures. Raw input is removed after every draft is saved/removed, or the user explicitly discards the capture. Retrying uses its original reference time and timezone. The backend does not keep recordings. Google processes submitted audio/text under the selected API tier's terms. Capture diagnostics contain only bounded local counters and stage timings, never words or audio.

Explicit Note capture sends `capture_type=note`. A recording is transcribed once and returned as one note with its wording retained, without a task-extraction call. Typed/on-device-transcribed notes are prepared locally by the phone without an AI request. These processing timings are recorded separately from task extraction. The live synthetic note-recording test passed in 1.807 seconds; that single measurement is not a microphone-quality or task-extraction speed claim.

Both AI endpoints require a valid account token; anonymous requests return HTTP 401. Accounts without server-verified `taskflow_pro` get `FREE_VOICE_CAPTURES_PER_MONTH` (default 10) dictations per UTC calendar month. One request is one dictation, whatever the number of tasks, and it counts only once the AI answers: failed, throttled and cancelled dictations don't count, nor does an answer with no task and no command, and resending the same `capture_id` with the same words is free. At the limit the answer is HTTP 402 `free_voice_used_up` with a `free_voice` block (`limit`, `left`, `resets_at`), before any budget or provider call; if Pro can't be checked at that point, it is HTTP 503 `billing_unavailable` instead. A duplicate still in flight gets HTTP 409 `capture_in_progress`. `DELETE ai/drafts/<capture_id>/` cancels a dictation that is still being understood; its request then gets HTTP 409 `capture_cancelled` and no result. A spoken capture may send `language`, the speech language chosen in the app (BCP-47, such as `ca-ES`); transcription uses it as a hint, and a model that refuses the hint transcribes without it. A cancel that arrives before its own request is remembered for 5 minutes, so that request gets the same answer without reaching the AI; a new attempt needs a new `capture_id`. Successful responses carry the updated `free_voice` block, and so do `auth/me/` and the login and registration responses, together with `storage` (`used_bytes`, `limit_bytes`). Configure `REVENUECAT_API_KEY`; without it, only complimentary grants are Pro. Test Store grants additionally require `DEPLOYMENT_ENVIRONMENT=development` and `REVENUECAT_ALLOW_SANDBOX=1`. Production rejects sandbox access. Limits remain 6 requests/minute, 50 successful captures/day per account (`AI_REQUESTS_PER_DAY`), and 200 attempts/day globally (`AI_GLOBAL_REQUESTS_PER_DAY`). Both daily limits start again at 00:00 UTC, and their HTTP 429 says how many seconds remain in `Retry-After`. A batch counts as one capture, including provider fallback. Failed captures release the account reservation; global attempt counts remain. Sign-in, registration and recovery retain their existing burst throttles. The local deployment trusts the direct peer (`NUM_PROXIES=0`); configure a trusted proxy boundary before public deployment. Task storage, accounts and sync remain authenticated. Provider errors leave manual creation available.

In `auto`, each stage makes at most two free attempts, each with a default 10-second
inference timeout, followed by at most one Vertex attempt. An HTTP 429 skips the
second free attempt. HTTP 500/502/503/504 and transport timeouts qualify for retry;
input/authentication/permission and validation errors do not cause paid fallback.
Each stage shares a 45-second inference/retry budget. Credential refresh and
network setup can add overhead; a recording has two stages. SDK retries are
disabled, so they cannot silently multiply these calls. Redis stores a shared
60-second quota cooldown or 30-second overload cooldown, honoring numeric
`Retry-After` up to five minutes. During cooldown, `auto` goes straight to Vertex.
Audio and extraction cooldowns are independent. Logs contain provider, stage,
status and elapsed time, without recordings, prompts or credentials.

Vertex is pay-as-you-go; there is no reserved GPU or idle model instance. These
request limits are not a monetary billing cap. AI Studio free availability and
quota depend on the selected model/project; do not assume unlimited free use.
Check [AI Studio pricing](https://ai.google.dev/gemini-api/docs/pricing) and
[Vertex pricing](https://cloud.google.com/gemini-enterprise-agent-platform/generative-ai/pricing)
before setting public allowances. [Model lifecycle](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/model-versions)
was checked on 2026-10-11: 3.1 Flash-Lite remains supported; 2.5 Flash-Lite is
near retirement and was not selected for this new integration.

Automated routing/adapter tests mock both providers. For a separate, small paid
live probe, run:

```powershell
docker compose -f compose.yaml -f compose.vertex.yaml run --rm --no-deps api python scripts/validate_vertex.py
```

It simulates only the free 429
and actually calls Vertex with synthetic project/member context. `--audio PATH`
also verifies real Vertex transcription of an explicitly supplied synthetic WAV.
The probe writes no tasks and uses its own cooldown cache.

## API outline

All paths below have the `/api/` prefix. Task and AI endpoints require `Authorization: Bearer <access>`.

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `auth/register/` | Email, password, optional first_name and timezone |
| POST | `auth/login/` | Email/password sign-in |
| POST | `auth/refresh/` | Rotate refresh token |
| POST | `auth/logout/` | Revoke current session |
| GET | `auth/me/` | Current account, with its `free_voice` and `storage` limits |
| GET, POST | `auth/delete-account/` | Preview of what deletion removes, keeps in shared projects and hands over, with its `plan`; POST `password` or `google_id_token` plus that `plan` deletes the account (204), or 409 `plan_changed` if the handovers changed |
| POST | `auth/password-reset/` | Email a 6-digit recovery code, in the request's `language` |
| POST | `auth/password-reset/confirm/` | Email, code + new password |
| GET, POST | `tasks/` | Paginated list or create task |
| GET, PUT, DELETE | `tasks/<uuid>/` | Read, idempotent upsert, soft delete |
| GET | `tasks/<uuid>/history/` | Task event history |
| GET | `attachments/` | Accessible task metadata; optional task_id / include_deleted=true |
| GET, PUT, DELETE | `attachments/<uuid>/` | Metadata, immutable multipart upload (task_id/name/file), removal |
| GET | `attachments/<uuid>/content/` | Authenticated private download; no public file URL |
| GET | `lists/access/` | Complete current list membership snapshot |
| GET | `lists/<uuid>/sharing/` | Roles and owner-only membership/invitation details |
| POST | `lists/<uuid>/invite/`, `revoke_invite/`, `member/`, `leave/` | Explicit invitation and membership changes |
| GET, POST | `invitations/`, `invitations/<uuid>/respond/` | Pending invites, each with `invited_by_name`; accept with code or decline |
| POST | `ai/draft/` | JSON text or multipart WAV + timezone |
| POST | `ai/drafts/` | Text/WAV capture with Pro or a free dictation left, plus optional `capture_id`; returns up to 12 reviewed drafts with project and responsibility, and `free_voice` |
| DELETE | `ai/drafts/<uuid>/` | Cancel a free dictation still being understood; idempotent, 204 |
| PUT | `meetings/<uuid>/pieces/<int>/` | Pro: one numbered piece of a recorded meeting (multipart `audio`, `offset_seconds`, `duration_seconds`, optional `language`), transcribed on Vertex and saved once; see `docs/MEETINGS.md` |
| POST | `meetings/<uuid>/finish/` | Pro: `last_index`; 200 with the final notes, or 202 with the pieces still `missing` |
| GET, DELETE | `meetings/<uuid>/` | Pro: the meeting's status or notes; delete it and its text (204, idempotent) |

Task writes accept `title`, nullable offset-aware `due_date`, nullable `scheduled_date` (YYYY-MM-DD), `recurrence` (none/daily/weekly/monthly/yearly), nullable `repeat_until`, `completed_dates` (ISO calendar dates), `priority` (1–3), `reminder_minutes` (null follows device default, -1 off, 0–10080 lead minutes), `reminder_time` (null default or 0–1439 local minute of day for date-only tasks), `notes`, `is_completed`, `is_deleted`, and `version`. Recurrence requires a start date; `is_completed` applies to one-off tasks and `completed_dates` to repeating tasks. A new client-generated UUID uses version 0. Updates/deletes require the current version; HTTP 409 returns `current`. List with `?include_deleted=true` for synchronization; follow pagination until `next` is null. The legacy single-draft endpoint rejects multi-task output instead of discarding tasks.

## Verification

Current checkpoint, 2026-09-22: all 79 backend tests pass on PostgreSQL, including file-quota concurrency checks; all 184 Flutter tests pass and analysis is clean. Shared-list and standalone-note Android integration runs use real SQLite, JWT and this Docker backend. Actual Android process-termination and simulated-call capture recovery, browser/PDF handoffs and Spanish regional/list/reminder/import persistence checks also have runtime evidence. The feature validation documents under `App/docs` record coverage and limitations; `VALIDATION_REMAINING.md` lists outstanding evidence. The full live task-extraction corpus is not yet passing because of provider failures and slow responses. The earlier baseline below remains historical evidence.

Verified locally on 2026-09-21: 32 backend tests and 41 Flutter tests pass. Android integration passed with the real Google model: guest Inbox/date-only capture, signed-in multi-task capture, saving, sync and restoration after login. The live synthetic WAV test produced a timed doctor appointment with preparation notes, an unscheduled coffee task, and weekly Sunday watering from one recording. Google returned intermittent 503/timeouts, including during the requested emulator rerun. The rerun passed with controlled AI responses and real Android persistence, Django accounts, sync and restoration. Physical-phone microphone input and iOS have not been tested.

Flutter analysis reports no issues. Android debug builds succeed; the existing `open_file` package still prints a macOS plugin metadata warning.

```powershell
# From Backend/
docker compose exec -T api python manage.py test core --settings=config.test_settings
```

```powershell
# From App/
flutter test --no-pub
flutter analyze --no-pub --no-fatal-infos
# Live AI + local Django + Android:
flutter test --no-pub integration_test/backend_flow_test.dart -d emulator-5554
# Stable UI/auth/sync verification when Google is unavailable (only AI is substituted):
flutter drive --keep-app-running --no-pub --driver=test_driver/appearance_test.dart --target=integration_test/backend_flow_test.dart --dart-define=FIXTURE_AI=true -d emulator-5554
```

Backend tests isolate their database and mock AI. They cover account isolation, password hashing/validation, throttling, rotating tokens, logout, recovery, optimistic concurrency, time zones, missing times, audio validation, and AI budgets. Flutter tests cover secure token storage/refresh, offline persistence, migration/import, retry idempotence, conflict copies, account isolation, and the original calendar time regression.

The explicit live smoke test runs from `Backend/`, uses synthetic accounts, and calls the configured Google models:

```powershell
docker compose exec -T api python scripts/smoke_test.py
# Optional: copy a synthetic WAV and run both transcription and extraction.
docker compose cp artifacts/doctor.wav api:/tmp/doctor.wav
docker compose exec -T api python scripts/smoke_test.py --audio /tmp/doctor.wav
# Multi-task text or an equivalent synthetic WAV:
docker compose exec -T api python scripts/flexible_smoke_test.py
docker compose exec -T api python scripts/flexible_smoke_test.py --audio /tmp/taskflow-batch.wav
```

It checks a Friday 17:00 doctor appointment, notes, priority, ambiguous time, account recovery through Mailpit, and restoration in a new session. Synthetic test accounts remain in the development database. Do not run the live smoke test as a production monitoring job.

## Architecture and Google login

The [architecture and rollout checklist](docs/ARCHITECTURE.md) records the Cloud Run and Neon deployment design, availability strategy, pricing assumptions, and proposed storage/retention policy. Retention deletion is not enabled.

[Google sign-in setup](docs/GOOGLE_SIGN_IN.md) describes the native Flutter login, development OAuth configuration, safe linking to existing accounts, and production prerequisites.
