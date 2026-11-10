# TaskFlow

Calendar-first task app for Android, built in Flutter, with a Django backend. You say or type a thought; the app turns it into tasks on your calendar and reminds you about them.

This repo holds the app (`App/`) and its backend (`Backend/`). The marketing website is its own repo, `../TaskFlowWeb`, with its own instructions.

These instructions are for every coding agent. Claude Code reads them through `CLAUDE.md`, which adds what only Claude needs.

## Product rules — read before changing anything user-facing

- **North star:** tap one button, say it, confirm, done. A first-time, non-technical user must be able to add something to their day without help. In October 2026 the owner's father couldn't work out how to create a task; that person is the bar.
- **Subtract before adding.** Don't add features, settings or screens unless the owner asks. Prefer removing a control, a concept, a step or a word from the default path.
- **Show advanced things only when relevant:** projects, deadlines, durations, assignees, checklists and the like.
- **Current direction and open decisions:** `../UX_REVIEW.md` (plan items U1–U14). Earlier critique: `../CRITIQUE.md`. Both files sit one folder above this repo.

## Owner decisions

Record lasting owner decisions about the app in `.claude/ux-review/DECISIONS.md`, newest first.

## The website

`../TaskFlowWeb` has its own `AGENTS.md` and `CLAUDE.md`. When an app change affects what the site should say — a new feature, a limit, a price, or what happens to people's data — update the site there too before you report the work as done.

## Layout

**`App/`** — the Flutter app (Dart package `agenda`; app label TaskFlow). Run Flutter commands from here.
- `lib/screens/`, `lib/widgets/`, `lib/theme/` — UI.
- `lib/services/`, `lib/repositories/`, `lib/providers/` — logic and state (Riverpod).
- `lib/l10n/` — ARB catalogs: `app_en.arb` is the template, plus `app_es.arb` and `app_ca.arb`. `lib/l10n/generated/` is generated — never edit it by hand.
- `android/app/src/main/kotlin/com/example/agenda/` — native bridges: speech, device calendar, widget, capture entries.
- `docs/` — design notes and validation records.

**`Backend/`** — Django API, Docker Compose (PostgreSQL, Redis, Mailpit), and the AI pipeline in `core/ai.py`. The contracts with the app are in `Backend/docs/`.

**Agent records** — `.claude/ux-review/DECISIONS.md`, the owner's decisions about the app.

## Commands

App (from `App/`):

```powershell
flutter pub get
flutter analyze --no-pub
flutter test --no-pub                                # whole suite
flutter test --no-pub test/<name>_test.dart          # one file
flutter gen-l10n                                     # after editing ARB files
flutter build apk --debug --no-pub --target-platform android-x64   # emulator APK
```

Rendered screen previews, no device needed. The UX preview suite renders every route and tab in its key states to `App/build/ux/<area>/`, and writes `App/build/ux/INDEX.md` (what each PNG shows, its sources, size, text scale and render time, and what no preview covers) and `App/build/ux/AUDIT.md` (measured accessibility, clipping and tap-target evidence for each render). To render one area or screen, add `--plain-name "capture/"` or `--plain-name "capture/sheet."`. The older previews: the calendar and review ones write PNGs to `App/build/`, and the sign-in ones write them to `App/artifacts/auth/`:

```powershell
flutter test --no-pub --dart-define=WRITE_UX_PREVIEWS=true test/ux_previews/ux_previews_test.dart
flutter test --no-pub --dart-define=WRITE_CALENDAR_PREVIEWS=true test/calendar_feedback_test.dart
flutter test --no-pub --dart-define=WRITE_REVIEW_PREVIEWS=true test/review_tasks_test.dart
flutter test --no-pub --dart-define=WRITE_AUTH_PREVIEWS=true test/auth_gate_test.dart
flutter test --no-pub --dart-define=WRITE_FORM_PREVIEWS=true test/new_task_form_test.dart
```

Backend (from `Backend/`, with Docker Desktop running; API on http://localhost:8088):

```powershell
docker compose up -d --build
docker compose exec -T api python manage.py test core --settings=config.test_settings
```

After a change to the AI prompts, check dictations against the real model, through the real views (it makes real, paid Vertex calls with your ADC from `Backend/scripts/login-vertex.ps1`; the model is noisy, so run a case a few times):

```powershell
.venv/Scripts/python.exe -X utf8 scripts/check_dictations.py --times 3 project-es until-es noday-es
```

Where commands run: Flutter, Python and Git on Windows; the website's Node, npm and Playwright in WSL. Use Windows Git Bash, not WSL's, for shell scripts.

## Email

These addresses are public and listed on the website's privacy page. All three reach the company mailbox.

| Address | Used for | Setting |
|---|---|---|
| `taskflow.noreply@garbar.tech` | The sender of every automatic email: invitations, password recovery, and next the account-deletion confirmation. Not monitored. | `DEFAULT_FROM_EMAIL` (`TaskFlow <taskflow.noreply@garbar.tech>`) |
| `taskflow.support@garbar.tech` | Support, privacy rights and account-deletion requests. Automatic emails set it as Reply-To. | `EMAIL_SUPPORT_ADDRESS` |
| `taskflow@garbar.tech` | General inquiries, on the website only. The app never sends from it. | — |

How email is sent:
- `Backend/core/email_delivery.py` queues each email, applies the sending limits and delivers it.
- Staging and production send through Resend (`EMAIL_BACKEND=core.email_delivery.ResendBackend`). The key lives in the environment, never in code.
- Local Docker sends to Mailpit, readable at http://localhost:8026.
- `Backend/docs/STAGING.md` (Email and invitation flow) covers DNS, Reply-To and the footer.
- A new automatic email sends from `DEFAULT_FROM_EMAIL` with Reply-To `EMAIL_SUPPORT_ADDRESS`, like the invitation and recovery emails.

## Rules

- **Branches.** Work on `dev`, the default branch; every pull request goes into `dev`. `main` is production. Never merge into or push `main`, and never deploy, unless the owner asks. Releases go from `dev` to `main` by pull request, and **a merge into `main` releases**: the **Deploy** workflow (`.github/workflows/deploy.yml`) deploys the staging API when the backend changed (`Backend/docs/STAGING.md`), and builds the signed staging APK and publishes it as the newest GitHub release when the app changed. Pull requests run the **CI** workflow (`.github/workflows/ci.yml`): the tests of whichever of `App/` and `Backend/` they touch. The workflows and their one-time setup: `README.md`. Git's own credentials don't reach these private repos, so a push or fetch the owner asks for passes `gh`'s: `git -c credential.helper= -c "credential.helper=!gh auth git-credential" push`.
- **Other sessions' work.** Preserve other sessions' uncommitted edits, untracked files and staging. Never commit, stage or revert them; commit only your own hunks.
- **The request decides.** A request to configure, explain, plan or inspect a workflow isn't a request to run it. Honor "don't run it yet". Permission given once, for example while the owner was away, isn't standing permission.
- **Tooling.** Install, download and set up the tools a task needs, then say what you did; don't ask first. Product decisions still go to the owner.
- **Text.** Every user-facing string goes in all three ARB files — English, Spanish and Catalan. Follow `App/docs/LOCALIZATION.md`. Spanish and Catalan usually run longer than English, so check layouts at 2× text size.
- **Device data.** Emulators and phones hold real data.
  - With `flutter drive`, always pass `--keep-app-running`; without it the app is uninstalled and its data lost.
  - Never uninstall the app or clear its data.
  - Don't use `--split-per-abi` for test installs.
  - After an integration-test build, reinstall the normal app with `adb install -r`.
- **Evidence.** Say what kind of evidence you have: unit or widget test, emulator, or physical device. Don't present an emulator run as a physical-phone or real-microphone result.
- **Secrets.** Never commit a secret: the repo may be made public to run GitHub Actions. Secrets live in three places only: `Backend/.env`, `Backend/.credentials/` and `App/config/` on the PC (all ignored by Git; never print, copy or log their values); GitHub Actions secrets for CI (`App/scripts/upload-ci-secrets.sh`); and Google Secret Manager for the staging API. CI must never need the PC: the backend tests use the committed, key-free `Backend/.env.ci`, and deploys sign in to Google without a key. A new setting goes in `Backend/.env.example` with a placeholder, and in `.env.ci` if the tests need it.
- **Scripts.** Root `scripts/` is for the essential deployment entry points.
