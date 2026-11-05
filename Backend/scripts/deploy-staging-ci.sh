#!/usr/bin/env bash
# Deploys the staging API from GitHub Actions (.github/workflows/deploy-backend.yml).
#
# The same release steps as deploy-staging.ps1, without its one-time setup
# (service accounts, queue, bucket, scheduler, IAM) and without writing a new
# config secret: it pins the newest version already in Secret Manager. To change
# the secret's values, or to set up new cloud resources, run deploy-staging.ps1
# from the PC. Keep the environment below in step with that script.
#
# Needs gcloud signed in as the GitHub deployer (setup: TaskFlowWeb
# scripts/dev/setup-github-deploy.sh). Run from the repo root.
set -euo pipefail

PROJECT=taskflow-511107
NUMBER=177649734578
REGION=europe-west3
SERVICE=taskflow-api-staging
RUNTIME="$SERVICE@$PROJECT.iam.gserviceaccount.com"
BUILDER="taskflow-api-builder@$PROJECT.iam.gserviceaccount.com"
MAIL_INVOKER="taskflow-mail-invoker@$PROJECT.iam.gserviceaccount.com"
MAINTENANCE=taskflow-api-staging-maintain
QUEUE=taskflow-staging-email
BUCKET="$PROJECT-api-staging-builds"
SECRET=taskflow-api-staging-config
URL="https://$SERVICE-$NUMBER.$REGION.run.app"
HOST="${URL#https://}"
COMMIT="${GITHUB_SHA:-$(git rev-parse HEAD)}"
g() { gcloud "$@" --project="$PROJECT" --quiet; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# 1. Build an image from an explicit allowlist: no .env, keys, media or dumps.
tag="main-${COMMIT:0:12}"
image="$REGION-docker.pkg.dev/$PROJECT/taskflow-api/backend:$tag"
source="$work/source"
mkdir -p "$source/scripts"
for name in core config templates manage.py requirements.txt requirements.lock Dockerfile .dockerignore; do
  cp -R "Backend/$name" "$source/"
done
cp Backend/scripts/start-server.sh "$source/scripts/start-server.sh"
find "$source" -name '__pycache__' -prune -exec rm -rf {} +
g builds submit "$source" --region="$REGION" --config="$source/config/cloud/build-staging.yaml" \
  --service-account="projects/$PROJECT/serviceAccounts/$BUILDER" \
  --gcs-source-staging-dir="gs://$BUCKET/source" --substitutions="_IMAGE=$image"
digest=$(g artifacts docker images describe "$image" --format='value(image_summary.fully_qualified_digest)')
test -n "$digest"

# 2. Pin the newest enabled version of the runtime config secret.
version=$(g secrets versions list "$SECRET" --filter='state=ENABLED' --sort-by='~createTime' --limit=1 --format='value(name)')
version="${version##*/}"
[[ "$version" =~ ^[0-9]+$ ]] || { echo "No enabled version of $SECRET"; exit 1; }
secrets_flag="--set-secrets=/secrets/taskflow/config.json=$SECRET:$version"

# 3. The service's environment, the same as deploy-staging.ps1.
export PROJECT REGION QUEUE MAINTENANCE MAIL_INVOKER URL HOST
python3 - "$work" <<'PY'
import json, os, sys
e = os.environ
work = sys.argv[1]
job = f"https://run.googleapis.com/v2/projects/{e['PROJECT']}/locations/{e['REGION']}/jobs/{e['MAINTENANCE']}:run"
env = {
    "TASKFLOW_CONFIG_FILE": "/secrets/taskflow/config.json", "DEPLOYMENT_ENVIRONMENT": "staging",
    "DJANGO_DEBUG": "0", "DJANGO_ALLOWED_HOSTS": e["HOST"],
    "STATE_BACKEND": "postgres", "REQUIRE_HTTPS": "1", "CLOUD_RUN_PROXY": "1", "TRUSTED_PROXY_COUNT": "1",
    "PGSSLROOTCERT": "/etc/ssl/certs/ca-certificates.crt",
    "REVENUECAT_ALLOW_SANDBOX": "1", "LOCAL_TEST_ACCOUNT_ENABLED": "0",
    "GOOGLE_OAUTH_CLIENT_IDS": "177649734578-cr3scnkukf14a1bbl7bpcj49t9aorft0.apps.googleusercontent.com",
    "STAGING_ALLOWED_EMAILS": "tech.garbar@gmail.com,mikigb77@gmail.com", "DEFAULT_TIME_ZONE": "Europe/Madrid",
    "COMPLIMENTARY_PRO_EMAILS": "mikigb77@gmail.com",
    "COMPLIMENTARY_PRO_BILLING_IDS": "b5684da7-3f9f-4a26-99bd-a3d218c3e6c3",
    "EMAIL_BACKEND": "core.email_delivery.ResendBackend", "DEFAULT_FROM_EMAIL": "TaskFlow <noreply@garbar.tech>",
    "PASSWORD_RESET_BASE_URL": f"{e['URL']}/reset-password/", "INVITATION_BASE_URL": f"{e['URL']}/invite/",
    "EMAIL_RETRY_QUEUE": f"projects/{e['PROJECT']}/locations/{e['REGION']}/queues/{e['QUEUE']}",
    "EMAIL_RETRY_JOB": job, "EMAIL_RETRY_IDENTITY": e["MAIL_INVOKER"],
    "AI_VERTEX_PROJECT": e["PROJECT"], "AI_VERTEX_LOCATION": "global",
    "AI_VERTEX_TEXT_MODEL": "gemini-3.1-flash-lite", "AI_VERTEX_AUDIO_MODEL": "gemini-3.1-flash-lite",
    "AI_REQUESTS_PER_DAY": "30", "ATTACHMENT_BUCKET": "docs4taskflow",
}
with open(f"{work}/environment.json", "w") as f:
    json.dump(env, f)
# deploy-staging.ps1 adds this to the migration job after deploying it.
with open(f"{work}/migrate-environment.json", "w") as f:
    json.dump({**env, "MIGRATION_DATABASE_DIRECT": "1"}, f)
PY

# 4. Migrate first, with the direct database connection, then the maintenance job.
g run jobs deploy taskflow-api-staging-migrate --region="$REGION" --image="$digest" \
  --service-account="$RUNTIME" --command=python --args=manage.py,migrate,--noinput \
  --env-vars-file="$work/migrate-environment.json" "$secrets_flag" \
  --tasks=1 --max-retries=0 --task-timeout=300s --memory=512Mi --cpu=1
g run jobs execute taskflow-api-staging-migrate --region="$REGION" --wait
g run jobs deploy "$MAINTENANCE" --region="$REGION" --image="$digest" \
  --service-account="$RUNTIME" --command=python --args=manage.py,maintain_staging \
  --env-vars-file="$work/environment.json" "$secrets_flag" \
  --tasks=1 --max-retries=0 --task-timeout=600s --memory=512Mi --cpu=1

# 5. Replace the API service. A manifest lets the startup probe send the Host
# and HTTPS headers Django's strict checks need (the CLI flag can't).
export DIGEST="$digest" RUNTIME NUMBER SECRET VERSION="$version" SERVICE
python3 - "$work" <<'PY'
import json, os, sys
e = os.environ
work = sys.argv[1]
env = json.load(open(f"{work}/environment.json"))
manifest = {
    "apiVersion": "serving.knative.dev/v1", "kind": "Service",
    "metadata": {
        "name": e["SERVICE"], "namespace": e["NUMBER"],
        "labels": {"app": "taskflow", "environment": "staging"},
        "annotations": {"run.googleapis.com/ingress": "all", "run.googleapis.com/maxScale": "2"},
    },
    "spec": {
        "template": {
            "metadata": {"annotations": {
                "run.googleapis.com/cpu-throttling": "true", "run.googleapis.com/startup-cpu-boost": "false"}},
            "spec": {
                "serviceAccountName": e["RUNTIME"], "containerConcurrency": 4, "timeoutSeconds": 120,
                "containers": [{
                    "image": e["DIGEST"], "ports": [{"containerPort": 8080, "name": "http1"}],
                    "resources": {"limits": {"cpu": "1", "memory": "1Gi"}},
                    "env": [{"name": k, "value": v} for k, v in sorted(env.items())],
                    "volumeMounts": [{"name": "runtime-config", "mountPath": "/secrets/taskflow"}],
                    "startupProbe": {
                        "timeoutSeconds": 5, "periodSeconds": 10, "failureThreshold": 12,
                        "httpGet": {"path": "/api/live/", "port": 8080, "httpHeaders": [
                            {"name": "Host", "value": e["HOST"]},
                            {"name": "X-Forwarded-Proto", "value": "https"}]},
                    },
                }],
                "volumes": [{"name": "runtime-config", "secret": {
                    "secretName": e["SECRET"], "items": [{"key": e["VERSION"], "path": "config.json"}]}}],
            },
        },
        "traffic": [{"latestRevision": True, "percent": 100}],
    },
}
with open(f"{work}/service.json", "w") as f:
    json.dump(manifest, f)
PY
g run services replace "$work/service.json" --region="$REGION"

# 6. The database-backed health check.
for attempt in 1 2 3 4 5 6; do
  if curl -fsS --max-time 90 "$URL/api/health/" | python3 -c 'import json,sys; sys.exit(json.load(sys.stdin).get("status") != "ok")'; then
    echo "Staging deployed and healthy: $URL ($digest, config version $version)"
    exit 0
  fi
  sleep 10
done
echo "Staging dependency health check failed: $URL/api/health/"
exit 1
