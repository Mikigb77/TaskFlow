# TaskFlow local backend

All development is on `dev`. The Flutter app opens on Calendar. Manual tasks and a limited voice trial work without an account; an account adds task backup and a larger AI allowance.

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

`Backend/.env` is intentionally tracked for this private prototype at the owner's request. It contains the Google key, model names, Django secret, and local database credentials. Docker injects these at runtime; `.dockerignore` excludes the environment files from the image build context, and the Flutter APK does not contain the key. `Backend/.env.example` documents the configuration without real credentials.

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
4. In Account → Connection settings, use `http://COMPUTER_IP:8088`. Use the debug APK for local HTTP. If Windows Firewall blocks the port, allow it on your private network.

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

The real Android flow can also be checked from `App/` with `flutter test integration_test/backend_flow_test.dart -d emulator-5554`. This checks guest capture, creates a synthetic account, reviews and saves multiple tasks, verifies backup, and signs out and back in. It removes its own guest tasks afterward and preserves existing ones. It does not record the microphone.

## Accounts and recovery

For repeat testing, use **Use test account** on the local browser page. In the Android app, sign in once with `test@taskflow.local` and `TaskFlow-Dev-2026!`; the app saves the session in secure storage. Both clients use the same account and tasks.

The local `.env` enables this with `LOCAL_TEST_ACCOUNT_ENABLED=1`. Docker startup runs `python manage.py seed_test_user`, which creates a regular user once and preserves its password and tasks on subsequent starts. The shortcut uses the normal JWT login endpoint. Test-account seeding and the browser shortcut are disabled by default in `.env.example`; their email and password are configured with `LOCAL_TEST_ACCOUNT_EMAIL` and `LOCAL_TEST_ACCOUNT_PASSWORD`.

Use an email address and a password of at least 12 characters. Passwords use Argon2 hashing and Django's common-password and similarity checks. Access tokens last 10 minutes; refresh tokens rotate and last 7 days. Tokens are stored in the phone's secure storage. Server session checks revoke both access and refresh tokens immediately on an online logout or password reset. Offline logout removes the device credentials; the server session expires normally.

Login has IP throttling and a 15-minute account lock after 5 failed attempts. Recovery responses do not reveal whether an email is registered. Recovery links last 30 minutes and are single-use. Resetting a password revokes existing sessions.

For local recovery, choose Forgot password in the app or browser, enter the account email, and open Mailpit on the computer. Follow the link there, or copy its recovery code into the app and choose a new password. Email is captured locally; nothing is sent to a real mailbox. A public deployment needs HTTPS and a real email service; email verification is not part of this local prototype.

## Task storage and sync

- Guest tasks stay in the original SQLite database. The migration preserves existing tasks and attachments.
- Signed-in accounts have separate local caches, scoped by both backend address and user ID. Titles, schedules, repetition rules, per-occurrence completion, priorities and notes sync to PostgreSQL.
- Existing guest tasks are imported only by choosing **Import local tasks** in Account. The import moves them once into the selected account.
- Files and images remain on the phone where they were attached. Attachment binaries and paths are not uploaded and cannot be restored onto another phone yet.
- Changes are saved locally first. Sync runs after changes, on app launch, when Calendar resumes, and when you press Sync. Offline changes wait in the local queue.
- UUIDs make retries idempotent. Version checks prevent overwriting another device's updates. Conflicting edits are kept as an **offline copy**, ready for the next sync. Conflicting deletions are cancelled so a newer remote edit is preserved. The Calendar/Account sync message explains conflicts or connection failures.
- Deletions are stored as server tombstones so other devices also remove the task. Task history records creation, updates, and deletion without copying task contents into logs.
- Reminder notifications are rebuilt for the current account. Old tasks are no longer silently purged at startup.

## Voice and AI

Tasks can have no schedule (Inbox), a date without a time (Any time), or a date and time. Date-only schedules use `scheduled_date`, which does not shift with time zones. Timed tasks use `due_date`; these fields are mutually exclusive. Existing SQLite and PostgreSQL timestamps are preserved by the migrations.

Repetition supports daily, weekly, monthly and yearly schedules, with an optional inclusive end date. The calendar projects occurrences from one series; completion dates are stored separately, so completing/undoing an occurrence never moves the series start or creates duplicate successors. Monthly tasks anchored on the 31st use the last day of shorter months and return to the 31st afterward. Tasks shows the next open occurrence from today; previous occurrences remain in Calendar and completed ones in Completed tasks. Editing/deleting applies to the whole series. Custom intervals and individual occurrence rescheduling are not implemented.

The existing ten-minute advance reminders apply only to timed, high-priority tasks. Date-only tasks appear in summaries without midnight alarms. Recurring reminders use a rolling 60-day window, capped at 50 upcoming alarms across tasks, refreshed on launch/resume/changes. Summaries are scheduled once to avoid repeating stale dates indefinitely.

The bounded LangChain pipeline is:

```text
WAV recording → Gemini transcription → Gemma extraction → validation → review/edit/remove drafts → save together
Typed text ────────────────────────────┘
```

Defaults are `gemini-3.5-transcribe` for transcription and the requested `gemma-4-31b-it` for extraction. Both can be changed in `.env` and applied by recreating the API container. This uses Google's Gemini API directly through the official SDK inside LangChain runnable steps; no LangSmith account or tracing is enabled.

The request includes an IANA time zone and a reference time, so “Friday” is resolved in the user's calendar. Drafts contain titles, optional dates/times, recurrence, priorities, notes and clarification questions. Omitted dates mean Inbox; omitted times mean Any time. Ambiguous times and daylight-saving gaps/overlaps require editing or explicit confirmation. Medical appointments and treatment default to high priority; explicit user priorities take precedence. Preparation notes remain with their appointment. Unsupported recurrence patterns are flagged rather than silently approximated. Drafts are not automatically saved: the app lets you edit/remove each one, then saves all remaining tasks in one SQLite transaction. A failed batch saves none. Signed-in batches enter the existing per-task sync queue.

Audio is accepted only as a validated 16-bit PCM WAV, up to 60 seconds and 6 MB. The phone keeps unfinished recordings, source text and drafts in account-scoped local storage so failures and interruptions can be recovered from Unfinished captures. Raw input is removed after every draft is saved/removed, or the user explicitly discards the capture. Retrying uses its original reference time and timezone. The backend does not keep recordings. Google processes submitted audio/text under the selected API tier's terms. Capture diagnostics contain only bounded local counters and stage timings, never words or audio.

There is no paid-model fallback. Limits are 6 requests/minute, 5 successful guest captures/day per connection (`AI_GUEST_REQUESTS_PER_DAY`), 50 successful captures/day per account (`AI_REQUESTS_PER_DAY`), and 200 attempts/day globally. A batch counts as one capture. Failed captures release the personal/guest reservation; global attempt counts remain. Voice normally uses two provider calls, text one. Transient extraction errors (HTTP 500/503) get at most one retry within 45 seconds; quota errors are not retried. These are application limits, not guarantees of Google quota/pricing. Guest IPs use server-secret HMAC cache keys; forwarding headers cannot bypass limits. The local deployment trusts the direct peer (`NUM_PROXIES=0`); configure a trusted proxy boundary before public deployment. Task storage, accounts and sync remain authenticated. Provider errors leave manual creation available. Check [Google pricing](https://ai.google.dev/gemini-api/docs/pricing) and AI Studio limits before estimating margins.

## API outline

All paths below have the `/api/` prefix. Task and AI endpoints require `Authorization: Bearer <access>`.

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `auth/register/` | Email, password, optional first_name and timezone |
| POST | `auth/login/` | Email/password sign-in |
| POST | `auth/refresh/` | Rotate refresh token |
| POST | `auth/logout/` | Revoke current session |
| GET | `auth/me/` | Current account |
| POST | `auth/password-reset/` | Request recovery email |
| POST | `auth/password-reset/confirm/` | Code + new password |
| GET, POST | `tasks/` | Paginated list or create task |
| GET, PUT, DELETE | `tasks/<uuid>/` | Read, idempotent upsert, soft delete |
| GET | `tasks/<uuid>/history/` | Task event history |
| POST | `ai/draft/` | JSON text or multipart WAV + timezone |
| POST | `ai/drafts/` | Guest or signed-in text/WAV capture; returns up to 12 reviewed drafts |

Task writes accept `title`, nullable offset-aware `due_date`, nullable `scheduled_date` (YYYY-MM-DD), `recurrence` (none/daily/weekly/monthly/yearly), nullable `repeat_until`, `completed_dates` (ISO calendar dates), `priority` (1–3), `notes`, `is_completed`, `is_deleted`, and `version`. Recurrence requires a start date; `is_completed` applies to one-off tasks and `completed_dates` to repeating tasks. A new client-generated UUID uses version 0. Updates/deletes require the current version; HTTP 409 returns `current`. List with `?include_deleted=true` for synchronization; follow pagination until `next` is null. The legacy single-draft endpoint rejects multi-task output instead of discarding tasks.

## Verification

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
flutter drive --no-pub --driver=test_driver/appearance_test.dart --target=integration_test/backend_flow_test.dart --dart-define=FIXTURE_AI=true -d emulator-5554
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
