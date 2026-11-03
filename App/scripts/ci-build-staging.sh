#!/usr/bin/env bash
# Builds the signed staging APK in GitHub Actions (.github/workflows/app-release.yml).
# The same checks as build-staging.ps1, which stays the way to build it on the PC.
#
# Needs, from the repository's Actions secrets (App/scripts/upload-ci-secrets.sh):
#   APP_STAGING_CONFIG        the contents of App/config/staging.json
#   STAGING_KEYSTORE_BASE64   App/.credentials/staging.jks, base64
#   STAGING_STORE_PASSWORD    its storePassword
#   STAGING_KEY_PASSWORD      its keyPassword
# The same staging key keeps installed apps updatable and Google sign-in working.
# Run from App/. Writes build/releases/taskflow-staging.apk and staging-build.json.
set -euo pipefail

for name in APP_STAGING_CONFIG STAGING_KEYSTORE_BASE64 STAGING_STORE_PASSWORD STAGING_KEY_PASSWORD; do
  if [ -z "${!name:-}" ]; then
    echo "Missing the $name secret. See App/scripts/upload-ci-secrets.sh." >&2
    exit 1
  fi
done

umask 077
mkdir -p config .credentials build/releases
printf '%s' "$APP_STAGING_CONFIG" > config/staging.json
printf '%s' "$STAGING_KEYSTORE_BASE64" | base64 -d > .credentials/staging.jks
cat > .credentials/staging-signing.properties <<EOF
storeFile=$PWD/.credentials/staging.jks
storePassword=$STAGING_STORE_PASSWORD
keyPassword=$STAGING_KEY_PASSWORD
keyAlias=taskflow-staging
EOF

# The same guards as build-staging.ps1.
python3 - <<'PY'
import json, re, sys
c = json.load(open("config/staging.json"))
if (c.get("APP_ENV") != "staging" or c.get("DEV_LOGIN_ENABLED") != "false"
        or not str(c.get("REVENUECAT_TEST_API_KEY", "")).startswith("test_")
        or not str(c.get("API_BASE_URL", "")).startswith("https://")):
    sys.exit("Staging requires HTTPS, an explicit Test Store key, and development login disabled.")
if any(re.search("E2E|PASSWORD|SECRET|TOKEN", k) for k in c):
    sys.exit("Private test credentials must never be compiled into the distributable APK.")
PY

# Without --no-pub: only a build that runs pub regenerates the plugin registrant
# for release, without dev-only plugins such as integration_test. With it, the
# debug registrant from `flutter pub get` stays and the release compile fails.
flutter build apk --release --target=lib/main.dart --dart-define-from-file=config/staging.json

apk=build/app/outputs/flutter-apk/app-release.apk
aapt2=$(ls -d "$ANDROID_HOME"/build-tools/*/aapt2 | sort -V | tail -1)
badging=$("$aapt2" dump badging "$apk")
if ! grep -q "^package: name='com.example.agenda.staging'" <<<"$badging" || grep -q '^application-debuggable' <<<"$badging"; then
  echo 'The staging APK must be the isolated package and must not be debuggable.' >&2
  exit 1
fi
version=$(sed -n "s/^package: .*versionName='\([^']*\)'.*/\1/p" <<<"$badging")
code=$(sed -n "s/^package: .*versionCode='\([^']*\)'.*/\1/p" <<<"$badging")

cp "$apk" build/releases/taskflow-staging.apk
sha=$(sha256sum build/releases/taskflow-staging.apk | cut -d' ' -f1)
cat > build/releases/staging-build.json <<EOF
{"file": "taskflow-staging.apk", "sha256": "$sha", "applicationId": "com.example.agenda.staging", "version": "$version", "versionCode": "$code", "debuggable": false, "billing": "revenuecat-test-store", "commit": "${GITHUB_SHA:-}", "built": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
echo "version=$version" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "code=$code" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "sha256=$sha" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "Staging APK $version ($code): build/releases/taskflow-staging.apk, SHA-256 $sha"
