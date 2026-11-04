#!/usr/bin/env bash
# Uploads, once, what GitHub Actions needs to build the signed staging APK
# (.github/workflows/app-release.yml) as Actions secrets of Mikigb77/TaskFlow.
# Run it on the PC that holds the staging key, from App/ in Git Bash, with the
# GitHub CLI signed in (gh auth status). Values go through stdin and are never
# printed. Run it again after changing config/staging.json or the key.
set -euo pipefail
cd "$(dirname "$0")/.."
repo=Mikigb77/TaskFlow
config=config/staging.json
properties=.credentials/staging-signing.properties

for file in "$config" "$properties"; do
  [ -f "$file" ] || { echo "Missing $file. Build staging once with scripts/build-staging.ps1." >&2; exit 1; }
done
prop() { sed -n "s/^$1=//p" "$properties" | tr -d '\r'; }
store=$(prop storeFile)
store=${store//\\//}
[ -f "$store" ] || store=.credentials/staging.jks
[ -f "$store" ] || { echo "Missing the staging keystore ($store)." >&2; exit 1; }
[ "$(prop keyAlias)" = taskflow-staging ] || { echo "Expected the key alias taskflow-staging." >&2; exit 1; }

gh secret set APP_STAGING_CONFIG --repo "$repo" < "$config"
base64 -w0 "$store" | gh secret set STAGING_KEYSTORE_BASE64 --repo "$repo"
prop storePassword | gh secret set STAGING_STORE_PASSWORD --repo "$repo"
prop keyPassword | gh secret set STAGING_KEY_PASSWORD --repo "$repo"
echo "Uploaded APP_STAGING_CONFIG, STAGING_KEYSTORE_BASE64, STAGING_STORE_PASSWORD and STAGING_KEY_PASSWORD to $repo."
