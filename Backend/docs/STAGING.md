# TaskFlow staging

Deployed on 11 October 2026 from the `dev` working tree. Staging has its own
database, signing key, Android package, secrets and email outbox. The production
Neon branch and the marketing website deployment remain separate.

## Use the private Android build

- Build: the newest [GitHub release](https://github.com/Mikigb77/TaskFlow/releases/latest/download/taskflow-staging.apk),
  built from `main` by `.github/workflows/app-release.yml` and visible only to
  people with access to the repository. A local build lands in
  `App/build/releases/taskflow-staging.apk`.
- App label/package: **TaskFlow Staging**, `com.example.agenda.staging`.
- API: <https://taskflow-api-staging-177649734578.europe-west3.run.app>.
- Dependency health: `/api/health/`; process-only startup check: `/api/live/`.
- Invitation/coming-soon pages: `/invite/` and `/download/`. They provide **no
  public APK download**. App-store distribution is still pending.

Transfer the APK privately to an Android phone, allow installation from the
source you use, and install. It can coexist with the local development app.
No local Docker service, USB port forwarding, or computer connection is needed.
The release build contains public SDK/client IDs, never database, email, AI or
service-account credentials. The local developer-login shortcut is disabled.

Android build **1.0.1 (4003)** adds the native RevenueCat opt-in required for an
internal release APK using Test Store. The earlier 4002 build could display an
API-key warning and close on a physical phone. The new build keeps release
optimization and `android:debuggable=false`; it does not replace checkout with
a mock or remove subscription checks. See `App/docs/REVENUECAT_SETUP.md` for the
staging-only guards and the reproducible native checkout test.

The owner can create an account as `tech.garbar@gmail.com` or `mikigb77@gmail.com`,
or use Google. Other
new accounts must have a live group/list invitation; unrestricted public signup
is disabled in staging. Existing accounts can still sign in. Signing up alone
does not join a group: acceptance requires the recipient's session, the secret
email code, and an explicit confirmation.

Google OAuth is still in testing mode. This app uses basic Sign in with Google
only, which Google exempts from the test-user list requirement. If additional
OAuth scopes are introduced, revisit Google Auth Platform → Audience and
[Google's audience rules](https://support.google.com/cloud/answer/15549945).
The owner must complete the actual Google account chooser on the device; an
automated email/password test does not verify that last Google step.

RevenueCat uses Test Store, including in this specifically marked staging
release. No real charge occurs. With the owner's approval, **Sandbox testing
access → Anybody** is enabled as of 12 October so every invited tester can
complete a purchase and receive Pro without a separate billing-ID allowlist.
This is project-wide sandbox access; production backend enforcement still
rejects sandbox receipts. Authentication and staging invitation requirements
remain in place. Test subscriptions use accelerated renewals/expiry (monthly
renewals currently occur every five minutes), not a real month of access.

### Updates of the staging app

The staging app updates itself; the production app will update through Google
Play and has none of this. The two are separate builds of the same code:
`APP_ENV=staging` (from `App/config/staging.json`) makes the private
**TaskFlow Staging** package, and only that release build carries the updater
and Android's `REQUEST_INSTALL_PACKAGES` permission
(`App/android/app/src/staging/AndroidManifest.xml`).

- **Numbering.** Every build gets a higher versionCode: the build number in
  `pubspec.yaml` plus the number of commits to the build's commit
  (`App/scripts/ci-build-staging.sh`, and `build-staging.ps1` on the PC). The
  version name still comes from `pubspec.yaml`.
- **The check.** When it opens, and when it comes back to the front an hour
  later, a signed-in staging app asks `GET /api/app/update/` for the newest
  release. The API reads the newest GitHub release and its
  `staging-build.json` (`core/app_updates.py`, cached for five minutes) and
  answers its version, versionCode and SHA-256.
- **The download.** Off mobile data the app downloads a newer build at once;
  on mobile data, only when the person taps **Update**.
  `GET /api/app/update/download/` answers a short-lived link to the APK on
  GitHub's storage, so the APK never passes through Cloud Run and the token
  never reaches the phone. The app checks the SHA-256 before installing.
- **The install.** The app offers the build in a dialog, never while a meeting
  is recording. **Update** hands it to Android's installer: the first time,
  Android asks to let TaskFlow Staging install apps; on Android 12 and newer
  an app updating itself then needs no confirmation. Android closes the app to
  replace it, and the person opens it again.

The API needs a read-only GitHub token for the private repository,
`APP_UPDATE_GITHUB_TOKEN` in the `taskflow-api-staging-config` secret.
Without it the API answers that there is no update, as production does. To
set it up once:

1. On GitHub, **Settings → Developer settings → Fine-grained tokens →
   Generate new token**: resource owner Mikigb77, only the repository
   `Mikigb77/TaskFlow`, permission **Contents: Read-only**, nothing else.
2. In Git Bash from the repo root, or in Google Cloud Shell, run
   `bash Backend/scripts/set-staging-update-token.sh` and paste the token. It
   adds a new version of the secret, keeping every other value, and saves the
   token in `Backend/.credentials/` so `deploy-staging.ps1` keeps it.
3. Deploy the backend: **Actions → Deploy backend → Run workflow** on `main`.

When the token expires, repeat the three steps with a new one.

### Complimentary owner access

`mikigb77@gmail.com` has full Pro feature access without a purchase, renewal or
RevenueCat sandbox allowlisting. For a new staging account, use **Continue with
Google** with that address: the backend grants access after Google verifies
ownership. Merely registering a password account with that email cannot claim
Pro; link Google from Account if you already registered with a password.

The existing local development account is explicitly approved by its opaque
billing ID as well as its email, so it can keep using its existing password.
No accounts, passwords or task data were copied between environments.

Server settings `COMPLIMENTARY_PRO_EMAILS` and `COMPLIMENTARY_PRO_BILLING_IDS`
control these grants. Both default empty; the deploy script and local `.env`
configure the owner. The email must match, and either a linked, verified Google
identity or the explicit billing ID is required. Removing the email revokes
the complimentary grant immediately; ordinary store entitlement checks then apply.
Keep these settings when provisioning production if owner access should carry
over. Ordinary request/storage limits still apply.

`auth/me/` and login responses include the read-only `complimentary_pro` flag;
`billing/access/` verifies the same rule independently. Updated app builds show
complimentary access, hide purchase controls and refresh the profile on startup,
resume and subscription refresh. Logout/account switches clear the grant.

## Infrastructure

| Component | Staging configuration |
| --- | --- |
| Google project | `taskflow-511107`, personal account `tech.garbar@gmail.com` |
| API | `taskflow-api-staging`, Frankfurt `europe-west3`, request-based CPU, min 0 / max 2, 1 CPU / 1 GiB, concurrency 4 |
| Database | Neon `square-butterfly-45392108`, schema-only branch `br-spring-resonance-b2kff5pd`, database/role `taskflow_staging`, Frankfurt |
| Database idle behavior | 0.25 CU, Free-plan default five-minute autosuspend |
| Files | Neon private S3-compatible bucket `docs4taskflow` in the staging branch |
| Secrets | Secret Manager `taskflow-api-staging-config`, pinned version mounted read-only |
| Migrations | `taskflow-api-staging-migrate` Cloud Run job, direct DB connection |
| Email maintenance | `taskflow-api-staging-maintain` Cloud Run job |
| Retry delivery | Cloud Tasks `taskflow-staging-email`, one concurrent dispatch; scheduled after reserving an outbox message |
| Daily maintenance | Scheduler at 03:17 Europe/Madrid; cleans expired runtime/auth/outbox records, **not customer tasks or files** |

Database traffic uses full certificate/hostname verification. Psycopg's bundled
OpenSSL needs the explicit container trust bundle
`PGSSLROOTCERT=/etc/ssl/certs/ca-certificates.crt`. Runtime requests use Neon's
pooled URL with zero persistent Django connections and no server-side cursors;
migrations use the dedicated direct URL.

There is no always-on Redis or persistent container disk. Atomic PostgreSQL row
locks protect shared request/login/AI/email counters across API instances. The
startup HTTP probe supplies the expected Host and forwarded HTTPS headers and
does not wake Neon. Frequent `/api/health/` polling would prevent autosuspend.

Runtime, build and email-job invocation use distinct Google service accounts.
The runtime only receives the scoped secret, AI invocation and email-enqueue
permissions it needs. The container never runs migrations or seeds users when
it starts in staging.

## Email and invitation flow

Resend Free is configured for `garbar.tech`, region Ireland, with enforced TLS.
The only active TaskFlow sending key is **TaskFlow staging runtime**, restricted
to sending from this domain and stored privately plus in Secret Manager. The
unused **TaskFlow staging** key was revoked with the owner's approval.

DNS in Cloudflare: `resend._domainkey` TXT, `send` and `rsend` CNAME records,
with email CNAMEs unproxied. Existing website routing is unchanged. Click/open
tracking is not enabled. Sender: `TaskFlow <noreply@garbar.tech>`.

Creating a group or shared-list invitation now sends email to new or existing
accounts. The app reports whether submission succeeded or is queued. The
durable outbox retries transient failures with stable provider idempotency keys,
checks expiry/revocation, and clears the stored secret body after delivery or
terminal expiry/failure. A provider's accepted submission is not a guarantee
that a real mailbox will deliver into its inbox; use Resend's delivery status.

Invitation and reset secrets are URL fragments, not request query strings.
The invitation page strips its fragment from browser history, uses no analytics,
has a restrictive CSP and no-referrer policy, and requires a tap to open the
app. `taskflow-staging://invite` preserves the pending invitation through login
and app restart. The manual code path remains available. Opening a link never
automatically grants membership. Invites expire after seven days; reset tokens
after thirty minutes.

App limits are 80 emails/day, 2,700/month, 8/recipient/day, inside Resend's Free
100/day and 3,000/month allowances. Invitation creation is also throttled.
Uploads remain 6 MiB/file, 20/task and 1,000/account. Without Pro, an account or
list owner has 100 MiB in total, and Pro has no total cap. There is no newly
enabled automatic customer-data retention purge.
AI runs on Vertex AI only (the owner's decision of 2026-11-04), with the service's own identity and no API key; secrets
stay on the backend and paid access is verified independently of the phone.

## Rebuild and redeploy

**A merge into `main` deploys staging.** When a push to `main` changes what the
API's image is built from (`core/`, `config/`, `templates/`, `manage.py`, the
requirements, the Dockerfile or `scripts/start-server.sh`),
`.github/workflows/deploy-backend.yml` runs the tests, then
`Backend/scripts/deploy-staging-ci.sh`: it builds the image, pins the newest
version of the `taskflow-api-staging-config` secret, migrates, redeploys the
maintenance job, replaces the API service and checks `/api/health/`. To deploy
again without a change, use **Actions → Deploy backend → Run workflow** on `main`.
Pull requests that touch `Backend/` run the tests first
(`.github/workflows/backend-checks.yml`).

Google sign-in is keyless (Workload Identity Federation), and only `main` can
use it. The one-time setup is TaskFlowWeb's `scripts/dev/setup-github-deploy.sh`,
run once in Google Cloud Shell; its README, "Deploy from GitHub", has the steps.
The automatic deploy doesn't change the secret's values, the email queue, the
scheduler or any permission.

To change the runtime secret's values, or to set up new cloud resources, deploy
by hand from `Backend`, using PowerShell 7:

```powershell
./scripts/deploy-staging.ps1
# Reuse an already-built digest when only deployment configuration changed:
./scripts/deploy-staging.ps1 -SkipBuild -Image <taskflow-api-image-digest>
```

The script always passes the personal Google project/account explicitly. It
refuses `main`, packages an explicit source allowlist, builds an immutable image,
pins a Secret Manager version, completes migrations, configures background jobs
and replaces the API service, then checks the database-backed health endpoint.
It needs ignored `Backend/.credentials/staging.env`, `staging-resend-key`, the
existing local AI configuration, and an authenticated Google Cloud SDK. Do not
commit any `.credentials`, fixture JSON, signing keys or source archives.

From `App`:

```powershell
./scripts/build-staging.ps1
```

This uses `config/staging.json`, creates signing material only if absent, and
copies the APK plus SHA-256/build metadata to `build/releases/`. Keep an encrypted
backup of `.credentials/staging.jks` and `staging-signing.properties`: replacing
the key prevents updating an installed staging app and requires a new OAuth
certificate registration. On another machine, update the properties' absolute
keystore path. Production signing must be provisioned separately.

On Windows without Developer Mode, `scripts/repair-plugin-links.ps1` can repair
generated desktop plugin directory junctions after Pub resolves dependencies.
It does not change operating-system security settings.

## Cost and launch boundaries

No paid plan was activated. Neon is Free: 100 CU-hours/project/month, 1 GB
database, 5 GB object storage and 5 GB public egress under the currently displayed
allowances. Free-plan exhaustion can stop service or writes; this is suitable
for private staging, not the promised availability of a public launch.

Google Console showed a **trial account with 88 days and €263.99 remaining** on
11 October. The owner must activate normal billing before trial expiry or credit
exhaustion. This deployment does not silently accept that financial change.
Cloud Run min-zero reduces idle compute; it does not make builds, image storage,
network transfer, jobs, email or Vertex permanently free. A maximum instance
count is also not a hard monthly spending cap.

Before public rollout: activate appropriate Neon and Google billing, define
alerts/operational headroom, test backup/restore and load, publish privacy and
retention policies, finalize store signing and payment configuration, and
configure production independently. See [architecture](ARCHITECTURE.md),
[Neon pricing](https://neon.com/pricing),
[Cloud Run pricing](https://cloud.google.com/run/pricing), and
[Resend limits](https://resend.com/docs/knowledge-base/account-quotas-and-limits).

## Validation record

- PostgreSQL/Django: 175 tests passed, including concurrent counters/throttles,
  complimentary owner access, verified Google login, forged-grant rejection,
  and provider responses that return a bare task array. Array normalization
  retains strict task validation and the twelve-task limit.
- Flutter: 54 focused subscription, account/API, Google-auth and auth-gate tests
  passed on 12 October; static analysis passed. Complimentary grant/revocation,
  account switching and localized purchase-free screens are covered. The earlier
  invitation parsing/review and staging-only Test Store policy checks also passed.
- Real cloud HTTPS: login, rotating refresh rejection, invite-only registration,
  logout revocation, new-user email invitation, explicit acceptance/code and
  recipient isolation, shared task completion, private Neon attachment
  round-trip/deletion and password-reset email submission passed.
- Resend reported **delivered** for its official simulated test recipients;
  no real friend's inbox was used during automated checks.
- Real RevenueCat Test Store purchase, server entitlement verification and live
  AI task/assignee/date extraction passed. No entitlement response was mocked.
- Android emulator against the deployed Cloud Run API: real login, native
  entitlement, Neon synchronization, synthetic WAV upload and transcription,
  two-task member/group review, deadline preservation and explicit saving
  passed. Offline assignment synchronization, second-account isolation and
  notifications also passed. See `App/build/staging-android-cloud-attached.log`
  and `App/artifacts/design/projects-voice-review-dark.png` (11 October, 20:08).
- Signed universal Android release APK built, installed over the integration
  build without clearing data, and launched successfully on `emulator-5556`.
  Physical-phone microphone and Google account selection still require the
  owner's device check.

`scripts/seed_staging_check.py` refuses databases other than `taskflow_staging`;
run through Django shell with private `/fixtures` mounted to ignored App/build.
It creates two synthetic users without touching the owner's account.
`scripts/validate_staging.py` performs the real HTTPS workflow with that fixture.
Its first full run creates a member and project; use `--billing-only` to resume
the purchase/AI check, and `--skip-ai` to renew just the short sandbox purchase.
Tests use `delivered+...@resend.dev`, Resend's documented simulated recipients.
Private fixture credentials are never embedded in the distributable APK.

Logs and screenshots are ignored under `Backend/artifacts` and `App/artifacts`.
