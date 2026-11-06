#!/usr/bin/env bash
# Gives the staging API the read-only GitHub token its app updater needs
# (core/app_updates.py; Backend/docs/STAGING.md, "Updates of the staging app").
#
# Adds APP_UPDATE_GITHUB_TOKEN to a new version of the staging config secret,
# keeping every other value, and saves the token in Backend/.credentials/ so a
# by-hand deploy-staging.ps1 keeps it too. Nothing is printed. The next backend
# deploy (a merge into main, or Actions -> Deploy backend -> Run workflow) uses it.
#
# Run from the repo root in Git Bash or Google Cloud Shell, with gcloud signed
# in as the owner. The token: a fine-grained GitHub token for Mikigb77/TaskFlow
# only, with "Contents: Read-only" and nothing else.
set -euo pipefail

PROJECT=taskflow-511107
SECRET=taskflow-api-staging-config
python=$(command -v python3 || command -v python)

read -rsp 'Read-only GitHub token: ' token
echo
if [[ ! "$token" =~ ^(github_pat_|ghp_)[A-Za-z0-9_]+$ ]]; then
  echo "That doesn't look like a GitHub token." >&2
  exit 1
fi

umask 077
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
gcloud secrets versions access latest --secret="$SECRET" --project="$PROJECT" --quiet > "$work/config.json"
TOKEN="$token" "$python" - "$work/config.json" <<'PY'
import json, os, sys
path = sys.argv[1]
with open(path) as file:
    config = json.load(file)
config["APP_UPDATE_GITHUB_TOKEN"] = os.environ["TOKEN"]
with open(path, "w") as file:
    json.dump(config, file)
PY
gcloud secrets versions add "$SECRET" --project="$PROJECT" --data-file="$work/config.json" --quiet >/dev/null

if [ -d Backend ]; then
  mkdir -p Backend/.credentials
  printf '%s' "$token" > Backend/.credentials/staging-github-token
fi
echo "Saved. The next backend deploy gives the staging app its updates."
