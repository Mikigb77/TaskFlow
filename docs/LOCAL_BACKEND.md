# TaskFlow local backend

All development is on `dev`. The Flutter app still opens on Calendar. You can use it locally without an account, or create an account for task backup and voice creation.

## Start the backend

From the repository root, with Docker Desktop running:

```powershell
docker compose up -d --build
docker compose ps
```

- Local browser workspace: <http://localhost:8088/>
- Health check: <http://localhost:8088/api/health/>
- Password recovery test inbox: <http://localhost:8026/>

Compose runs Django/Gunicorn, PostgreSQL, Redis, and Mailpit. PostgreSQL and Redis have persistent volumes and no published database ports. The API uses port 8088 to avoid the other services already running on this computer. Mailpit is accessible only from localhost.

The root `.env` is intentionally tracked for this private prototype at the owner's request. It contains the Google key, model names, Django secret, and local database credentials. Docker injects these at runtime; the image build context and Flutter APK do not contain the key. `.env.example` documents the configuration without real credentials.

Stop services with `docker compose stop`. `docker compose down` also preserves the data volumes; adding `-v` deletes their data.

## Android emulator and phone

Tested toolchain: Flutter 3.44 / Dart 3.12, Android SDK, JDK 21. Android Gradle/Kotlin configuration was updated to support current Flutter and recording plugins.

```powershell
flutter pub get
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8088
```

`10.0.2.2` is the Android emulator's address for the host computer. Open the Account icon to register or log in. Calendar's microphone button opens voice creation once signed in. Type a description to test without a microphone. Recording requires Android microphone permission and is limited to 60 seconds.

On a physical Android phone:

1. Connect the phone and computer to the same Wi-Fi.
2. Find the computer's IPv4 address with `ipconfig`.
3. Add that exact IP to `DJANGO_ALLOWED_HOSTS` in `.env` if it is not already there, then run `docker compose up -d --force-recreate api`.
4. In Account → Connection settings, use `http://COMPUTER_IP:8088`. Use the debug APK for local HTTP. If Windows Firewall blocks the port, allow it on your private network.

You can also pass the address using `--dart-define=API_BASE_URL=...`. Runtime connection settings are stored on the device and take precedence. Sign out before changing servers. Release builds require HTTPS; local HTTP is enabled only in the Android debug manifest.

Build the local test APK:

```powershell
flutter build apk --debug
# Smaller packages for individual devices:
flutter build apk --debug --split-per-abi
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`.
The split build also creates `app-arm64-v8a-debug.apk` for most current phones and `app-x86_64-debug.apk` for this emulator. These fit more easily on devices with limited free space.

The real Android flow can also be checked with `flutter test integration_test/backend_flow_test.dart -d emulator-5554`. This creates a synthetic account, calls the configured text model, reviews and saves a draft, verifies the server backup, and signs out and back in. It does not record the microphone.

## Accounts and recovery

For repeat testing, use **Use test account** on the local browser page. In the Android app, sign in once with `test@taskflow.local` and `TaskFlow-Dev-2026!`; the app saves the session in secure storage. Both clients use the same account and tasks.

The local `.env` enables this with `LOCAL_TEST_ACCOUNT_ENABLED=1`. Docker startup runs `python manage.py seed_test_user`, which creates a regular user once and preserves its password and tasks on subsequent starts. The shortcut uses the normal JWT login endpoint. Test-account seeding and the browser shortcut are disabled by default in `.env.example`; their email and password are configured with `LOCAL_TEST_ACCOUNT_EMAIL` and `LOCAL_TEST_ACCOUNT_PASSWORD`.

Use an email address and a password of at least 12 characters. Passwords use Argon2 hashing and Django's common-password and similarity checks. Access tokens last 10 minutes; refresh tokens rotate and last 7 days. Tokens are stored in the phone's secure storage. Server session checks revoke both access and refresh tokens immediately on an online logout or password reset. Offline logout removes the device credentials; the server session expires normally.

Login has IP throttling and a 15-minute account lock after 5 failed attempts. Recovery responses do not reveal whether an email is registered. Recovery links last 30 minutes and are single-use. Resetting a password revokes existing sessions.

For local recovery, choose Forgot password in the app or browser, enter the account email, and open Mailpit on the computer. Follow the link there, or copy its recovery code into the app and choose a new password. Email is captured locally; nothing is sent to a real mailbox. A public deployment needs HTTPS and a real email service; email verification is not part of this local prototype.

## Task storage and sync

- Guest tasks stay in the original SQLite database. The migration preserves existing tasks and attachments.
- Signed-in accounts have separate local caches, scoped by both backend address and user ID. Task titles, due dates, priorities, completion state, and notes sync to PostgreSQL.
- Existing guest tasks are imported only by choosing **Import local tasks** in Account. The import moves them once into the selected account.
- Files and images remain on the phone where they were attached. Attachment binaries and paths are not uploaded and cannot be restored onto another phone yet.
- Changes are saved locally first. Sync runs after changes, on app launch, when Calendar resumes, and when you press Sync. Offline changes wait in the local queue.
- UUIDs make retries idempotent. Version checks prevent overwriting another device's updates. Conflicting edits are kept as an **offline copy**, ready for the next sync. Conflicting deletions are cancelled so a newer remote edit is preserved. The Calendar/Account sync message explains conflicts or connection failures.
- Deletions are stored as server tombstones so other devices also remove the task. Task history records creation, updates, and deletion without copying task contents into logs.
- Reminder notifications are rebuilt for the current account. Old tasks are no longer silently purged at startup.

## Voice and AI

The bounded LangChain pipeline is:

```text
WAV recording → Gemini transcription → Gemma extraction → validation → editable draft → explicit save
Typed text ────────────────────────────┘
```

Defaults are `gemini-3.5-transcribe` for transcription and the requested `gemma-4-31b-it` for extraction. Both can be changed in `.env` and applied by recreating the API container. This uses Google's Gemini API directly through the official SDK inside LangChain runnable steps; no LangSmith account or tracing is enabled.

The request includes an IANA time zone and a reference time, so “Friday” is resolved in the user's calendar. The draft contains a short title, due date/time, priority, notes, and clarification questions. Medical appointments and treatment default to high priority; explicit user priorities take precedence. Missing or ambiguous times stay unset rather than becoming midnight. Daylight-saving gaps and repeated times are flagged for review.

Audio is accepted only as a validated 16-bit PCM WAV, up to 60 seconds and 6 MB. The phone's temporary recording is deleted after processing or cancellation. The backend does not keep recordings. Google processes the submitted audio/text under the selected API tier's terms.

There is no paid-model fallback. The backend limits AI drafts to 6 per minute, 50 per user per day (`AI_REQUESTS_PER_DAY`), and 200 total per day. A voice draft normally uses two provider calls; a text draft uses one. Transient extraction errors (HTTP 500/503) get at most one retry within the same 45-second budget; quota errors are not retried. These are application limits, not a guarantee of Google quota or pricing. Provider quota/errors are shown in the app, and manual creation stays available. Check the [current Google pricing](https://ai.google.dev/gemini-api/docs/pricing) and the project's AI Studio limits before estimating hosting or subscription margins.

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

Task writes accept `title`, offset-aware `due_date`, `priority` (1–3), `notes`, `is_completed`, `is_deleted`, and `version`. A new client-generated UUID uses version 0. Updates/deletes require the current version; HTTP 409 returns `current`. List with `?include_deleted=true` for synchronization; follow pagination until `next` is null.

## Verification

Verified locally on 2026-09-20: 25 backend tests, 15 Flutter tests, and the Android integration test pass. The live Docker smoke test also passes, including a synthetic English WAV transcribed into a Friday 25 September task at 17:00 Europe/Madrid, high priority, with the blood-test preparation note. Recovery email delivery, single-use reset, revoked sessions, and account isolation were checked against the running PostgreSQL-backed API. Physical-phone microphone input and iOS have not been tested.

Flutter analysis reports no errors or warnings, with 9 existing API deprecation notices. Android debug builds succeed; the existing `open_file` package still prints a macOS plugin metadata warning.

```powershell
docker compose exec -T api python manage.py test core --settings=config.test_settings
flutter test --no-pub
flutter analyze --no-pub --no-fatal-infos
```

Backend tests isolate their database and mock AI. They cover account isolation, password hashing/validation, throttling, rotating tokens, logout, recovery, optimistic concurrency, time zones, missing times, audio validation, and AI budgets. Flutter tests cover secure token storage/refresh, offline persistence, migration/import, retry idempotence, conflict copies, account isolation, and the original calendar time regression.

The explicit live smoke test uses synthetic accounts and calls the configured Google models:

```powershell
docker compose exec -T api python scripts/smoke_test.py
# Optional: copy a synthetic WAV and run both transcription and extraction.
docker compose cp artifacts/doctor.wav api:/tmp/doctor.wav
docker compose exec -T api python scripts/smoke_test.py --audio /tmp/doctor.wav
```

It checks a Friday 17:00 doctor appointment, notes, priority, ambiguous time, account recovery through Mailpit, and restoration in a new session. Synthetic test accounts remain in the development database. Do not run the live smoke test as a production monitoring job.
