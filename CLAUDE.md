# TaskFlow

Calendar-first task app for Android, built in Flutter, with a Django backend. You say or type a thought; the app turns it into tasks on your calendar and reminds you about them.

This repo holds the app (`App/`) and its backend (`Backend/`). The marketing website is a separate repo (`../TaskFlowWeb`).

## Product rules — read before changing anything user-facing

- **North star:** tap one button, say it, confirm, done. A first-time, non-technical user must be able to add something to their day without help. In October 2026 the owner's father couldn't work out how to create a task; that person is the bar.
- **Subtract before adding.** Don't add features, settings or screens unless the owner asks. Prefer removing a control, a concept, a step or a word from the default path.
- **Show advanced things only when relevant:** projects, deadlines, durations, assignees, checklists and the like.
- **Current direction and open decisions:** `../UX_REVIEW.md` (plan items U1–U14). Earlier critique: `../CRITIQUE.md`. Both files sit one folder above this repo.

## UX review loop

This section is for the main session.

When user-facing app work is finished, run **`/ux`** once on the whole change, before you report it as done — not after every edit. This is the owner's standing opt-in to the UX workflows (2026-10-13).
- `/ux` reviews what changed since the last UX review, fixes the findings, re-checks them, and commits the verified round on `dev`.
- `/ux app` reviews the whole app and stops for the owner's approval. `/ux fix` then carries out the approved plan.
- `/ux <screens>` reviews only the screens named.

Owner policy (2026-10-13):
- fix everything the reviewer finds, except product decisions;
- stop for approval only on whole-app runs;
- commit each verified round on `dev`. Never push, and never touch `main`.

The agents can't see the conversation. Before running `/ux`, record lasting owner decisions in `.claude/ux-review/DECISIONS.md`, and pass anything else they need to know as notes. How the loop works: `.claude/ux-review/README.md`. Issues and their status: `.claude/ux-review/ISSUES.md`.

**User-facing** means:
- `App/lib/screens/`, `App/lib/widgets/`, `App/lib/theme/`, and routes in `App/lib/main.dart`;
- the ARB files in `App/lib/l10n/`;
- `App/assets/`;
- notification and reminder text;
- Android and iOS strings, launcher shortcuts, the home-screen widget, and permission text;
- native behaviour the user feels directly, such as when speech listening starts and stops.

## Layout

**`App/`** — the Flutter app (Dart package `agenda`; app label TaskFlow). Run Flutter commands from here.
- `lib/screens/`, `lib/widgets/`, `lib/theme/` — UI.
- `lib/services/`, `lib/repositories/`, `lib/providers/` — logic and state (Riverpod).
- `lib/l10n/` — ARB catalogs: `app_en.arb` is the template, plus `app_es.arb` and `app_ca.arb`. `lib/l10n/generated/` is generated — never edit it by hand.
- `android/app/src/main/kotlin/com/example/agenda/` — native bridges: speech, device calendar, widget, capture entries.
- `docs/` — design notes and validation records.

**`Backend/`** — Django API, Docker Compose (PostgreSQL, Redis, Mailpit), and the AI pipeline in `core/ai.py`.

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

Rendered screen previews, no device needed. The calendar and review previews write PNGs to `App/build/`; the sign-in previews write them to `App/artifacts/auth/`, and that command then fails on an unrelated plugin error (see `.claude/ux-review/KNOWN_FAILURES.md`):

```powershell
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

- **Branches.** Work on `dev`. Never merge into or push `main`, and never deploy, unless the owner asks.
- **Text.** Every user-facing string goes in all three ARB files — English, Spanish and Catalan. Follow `App/docs/LOCALIZATION.md`. Spanish and Catalan usually run longer than English, so check layouts at 2× text size.
- **Device data.** Emulators and phones hold real data.
  - With `flutter drive`, always pass `--keep-app-running`; without it the app is uninstalled and its data lost.
  - Never uninstall the app or clear its data.
  - Don't use `--split-per-abi` for test installs.
  - After an integration-test build, reinstall the normal app with `adb install -r`.
- **Evidence.** Say what kind of evidence you have: unit or widget test, emulator, or physical device. Don't present an emulator run as a physical-phone or real-microphone result.
- **Secrets.** `Backend/.env` is tracked on purpose — this is a private prototype — and it holds real keys. Never print, copy or log its values. Don't add secrets anywhere else.
