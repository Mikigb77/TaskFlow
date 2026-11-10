# TaskFlow

**[Download the newest TaskFlow Staging APK](https://github.com/Mikigb77/TaskFlow/releases/latest/download/taskflow-staging.apk)** · [all builds](https://github.com/Mikigb77/TaskFlow/releases)

The download works for people with access to this private repository. The app installs as **TaskFlow Staging** beside the normal app, and it talks to the staging API. To install it, open the file on an Android phone and allow installs from that source.

Once installed, TaskFlow Staging updates itself to each newer build: see [Updates of the staging app](Backend/docs/STAGING.md#updates-of-the-staging-app). The production app will update through Google Play.

TaskFlow is a calendar-first task app for Android, built in Flutter, with a Django backend. You say or type a thought, and the app turns it into tasks on your calendar and reminds you about them.

- [`App/`](App/README.md): the Flutter app.
- [`Backend/`](Backend/README.md): the Django API. Staging is described in [`Backend/docs/STAGING.md`](Backend/docs/STAGING.md).
- The marketing website lives in its own repository, `TaskFlowWeb`.
- Instructions for coding agents: [`AGENTS.md`](AGENTS.md).

## From pull request to release

Everything runs in GitHub Actions, so nothing needs your computer. There are two branches and two workflows:

- **`dev`** is the default branch. Every pull request goes into `dev`.
- **`main`** is production. A pull request from `dev` into `main` is a release, and merging it deploys.

| When | What runs | Workflow |
|---|---|---|
| A pull request into `dev` or `main` touches `App/` | `flutter analyze` and the whole test suite, split across four machines that run at once | **CI**, [`ci.yml`](.github/workflows/ci.yml) |
| A pull request into `dev` or `main` touches `Backend/` | The Django tests and the Docker image build | **CI**, [`ci.yml`](.github/workflows/ci.yml) |
| A merge into `main` changes the app | CI's app checks and the signed staging APK build, side by side; the APK is published as the newest [release](https://github.com/Mikigb77/TaskFlow/releases) | **Deploy**, [`deploy.yml`](.github/workflows/deploy.yml) |
| A merge into `main` changes the backend | CI's backend checks, then the staging API on Cloud Run: build, migrate, health check | **Deploy**, [`deploy.yml`](.github/workflows/deploy.yml) |

Both workflows can also be started by hand from **Actions → CI** or **Actions → Deploy → Run workflow** on `main`; Deploy asks which parts to deploy. The website has the same two branches and workflows in its own repository.

### One-time setup

1. **Google Cloud**, for the backend and the website. Run TaskFlowWeb's `scripts/dev/setup-github-deploy.sh` once, either in [Google Cloud Shell](https://shell.cloud.google.com/?project=taskflow-511107) or in Git Bash with `gcloud` signed in as the owner. It sets up keyless sign-in that only `main` of the two repositories can use. No key is stored in GitHub.
2. **The app's signing key and build config.** On the PC that holds `App/.credentials/` and `App/config/staging.json`, run `bash App/scripts/upload-ci-secrets.sh` in Git Bash, with `gh` signed in. It stores four Actions secrets: `APP_STAGING_CONFIG`, `STAGING_KEYSTORE_BASE64`, `STAGING_STORE_PASSWORD` and `STAGING_KEY_PASSWORD`. CI signs with the same staging key, so installed apps keep updating and Google sign-in keeps working. Run it again after changing either file.
3. **Cloudflare**, for the website's edge worker. Add an "Edit Cloudflare Workers" API token to TaskFlowWeb as the `CLOUDFLARE_API_TOKEN` secret.

## Dependabot

Dependabot watches the app's Dart packages, the backend's Python packages, the API image's Python, the local Docker Compose services and the workflows' actions. It is free, and stays free if the repository goes private.

- **Alerts** list each known vulnerability under the repository's Security tab.
- **Security updates** open a PR into `dev`, the default branch, as soon as an advisory affects a package and a fixed version exists. They never wait.
- **Version updates** ([`.github/dependabot.yml`](.github/dependabot.yml)) open PRs into `dev` once a week. The minor and patch updates of each ecosystem share one PR, and each major update gets its own; RevenueCat's two Flutter packages always move together. A release waits 7 days before it is offered, so a broken or hijacked release is usually pulled first.
- **Left out on purpose**, each with its reason in the file: `intl`, which the Flutter SDK pins; a newer Python for the API image (3.14 to 3.15 is a new Python, a PR of its own); Postgres and Redis majors; and the Android Gradle files, which follow Flutter.

Alerts and security updates are switched on in the repository's settings, not in the file (since 2026-11-10; `gh api repos/Mikigb77/TaskFlow/automated-security-fixes` shows whether they still are). The backend's exact versions are in `Backend/requirements-lock.txt`, which the image and CI install, so Dependabot updates and checks those too. CI's backend tests read their Python from `Backend/Dockerfile`, so an update of the image's Python is tested on the new one, and CI fails a PR if any Dependabot entry doesn't open its PRs into `dev`.

Dependabot checks early on Monday (04:00 Madrid time), and a scheduled Claude pass at 06:09 works through its PRs, security updates first (Miki, 2026-11-10):

- A green patch or minor update is squash-merged into `dev`.
- A major update needs a look at its release notes. It is merged if CI is green and nothing affects us; if it changes behavior, cost or licence, it waits for Miki.
- If CI fails, a small, clear fix goes on the Dependabot branch. Otherwise the PR is closed with the reason, and a version that can't work yet gets an ignore, with the reason, in the file.
- A merged security fix to code that ships (the app or the API) is released at once, by a pull request from `dev` into `main`; Deploy runs one release at a time. Anything else ships with the next release.
- The pass goes through every open alert, Dependabot's and secret scanning's (Miki, 2026-11-10). An alert whose security update is open is handled with the PRs, first; an alert with a fixed version but no PR gets the update by hand, through a PR into `dev`; an alert with no fix yet is checked against the code, to say whether we use what it affects. The GitHub tools in Claude's cloud sessions can't read alerts, so the pass reads them with `gh` on Miki's laptop; when the laptop is off, the report says the alerts weren't checked.

### The weekly report

By 07:55 Madrid time the pass files one GitHub issue in each repository that has something to report, labelled `dependabot-report` and assigned to Miki, so one search lists every open report: [label:dependabot-report assignee:Mikigb77](https://github.com/issues?q=is%3Aopen+is%3Aissue+label%3Adependabot-report+assignee%3AMikigb77). A week with no Dependabot PR to handle, no new or changed alert and nothing merged, closed or deployed files nothing. The title (`[high] Dependabot report, YYYY-MM-DD`) and an `urgency:` label say how soon it needs Miki:

- **high**, act today: something that ships is exposed or broken. An alert on a dependency that ships is still open after the pass, a release or rollback failed, or `dev` or `main` is red because of an update.
- **medium**, decide this week: something only Miki can decide is waiting, such as a major update that changes behavior, cost or licence, or a red update with no clear fix.
- **low**, for the record: updates were merged, closed or released, and nothing needs Miki.

The report's first line says what Miki needs to do, or "Nothing for you to do." Then it lists what needs Miki, every alert still open, what merged, closed (with the reason), was released or is still pending, and any new alert, with a link for each. An alert already reported and unchanged isn't repeated, and the report holds no secrets, IP addresses or users' data. Work still running at 07:55 is finished afterwards and added as a comment, with the urgency changed if it changed. The next week's report closes a low one; a high or medium report stays open until what it asks for is done.
