# TaskFlow

**[Download the newest TaskFlow Staging APK](https://github.com/Mikigb77/TaskFlow/releases/latest/download/taskflow-staging.apk)** · [all builds](https://github.com/Mikigb77/TaskFlow/releases)

The download works for people with access to this private repository. The app installs as **TaskFlow Staging** beside the normal app, and it talks to the staging API. To install it, open the file on an Android phone and allow installs from that source.

TaskFlow is a calendar-first task app for Android, built in Flutter, with a Django backend. You say or type a thought, and the app turns it into tasks on your calendar and reminds you about them.

- [`App/`](App/README.md): the Flutter app.
- [`Backend/`](Backend/README.md): the Django API. Staging is described in [`Backend/docs/STAGING.md`](Backend/docs/STAGING.md).
- The marketing website lives in its own repository, `TaskFlowWeb`.
- Instructions for coding agents: [`AGENTS.md`](AGENTS.md).

## From pull request to release

Everything runs in GitHub Actions, so nothing needs your computer.

| When | What runs | Workflow |
|---|---|---|
| A pull request into `main` or `dev` touches `App/` | `flutter analyze` and the whole test suite, split across four machines that run at once | [`app-checks.yml`](.github/workflows/app-checks.yml) |
| A pull request into `main` or `dev` touches `Backend/` | The Django tests | [`backend-checks.yml`](.github/workflows/backend-checks.yml) |
| A merge into `main` changes the app | The same checks and the signed staging APK build, side by side; the APK is published as the newest [release](https://github.com/Mikigb77/TaskFlow/releases) | [`app-release.yml`](.github/workflows/app-release.yml) |
| A merge into `main` changes the backend | Tests, then the staging API on Cloud Run: build, migrate, health check | [`deploy-backend.yml`](.github/workflows/deploy-backend.yml) |

Every workflow can also be started by hand from **Actions → (workflow) → Run workflow** on `main`. The website deploys from its own repository the same way.

### One-time setup

1. **Google Cloud**, for the backend and the website. Run TaskFlowWeb's `scripts/dev/setup-github-deploy.sh` once, either in [Google Cloud Shell](https://shell.cloud.google.com/?project=taskflow-511107) or in Git Bash with `gcloud` signed in as the owner. It sets up keyless sign-in that only `main` of the two repositories can use. No key is stored in GitHub.
2. **The app's signing key and build config.** On the PC that holds `App/.credentials/` and `App/config/staging.json`, run `bash App/scripts/upload-ci-secrets.sh` in Git Bash, with `gh` signed in. It stores four Actions secrets: `APP_STAGING_CONFIG`, `STAGING_KEYSTORE_BASE64`, `STAGING_STORE_PASSWORD` and `STAGING_KEY_PASSWORD`. CI signs with the same staging key, so installed apps keep updating and Google sign-in keeps working. Run it again after changing either file.
3. **Cloudflare**, for the website's edge worker. Add an "Edit Cloudflare Workers" API token to TaskFlowWeb as the `CLOUDFLARE_API_TOKEN` secret.
