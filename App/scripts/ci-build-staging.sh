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

# Every build gets its own, higher versionCode, so the staging app can tell a
# newer build and update to it (lib/services/app_update.dart): pubspec's build
# number plus the number of commits to this one. Needs the whole history.
if [ "$(git rev-parse --is-shallow-repository)" != false ]; then
  echo 'A shallow clone would number this build wrongly: check out with fetch-depth: 0.' >&2
  exit 1
fi
base=$(sed -n 's/^version: *[^+]*+\([0-9][0-9]*\) *$/\1/p' pubspec.yaml)
[[ "$base" =~ ^[0-9]+$ ]] || { echo 'pubspec.yaml needs a version such as 1.0.5+4007.' >&2; exit 1; }
number=$((base + $(git rev-list --count HEAD)))

# Without --no-pub: only a build that runs pub regenerates the plugin registrant
# for release, without dev-only plugins such as integration_test. With it, the
# debug registrant from `flutter pub get` stays and the release compile fails.
flutter build apk --release --target=lib/main.dart --dart-define-from-file=config/staging.json \
  --build-number="$number"

apk=build/app/outputs/flutter-apk/app-release.apk
aapt2=$(ls -d "$ANDROID_HOME"/build-tools/*/aapt2 | sort -V | tail -1)
badging=$("$aapt2" dump badging "$apk")
if ! grep -q "^package: name='com.example.agenda.staging'" <<<"$badging" || grep -q '^application-debuggable' <<<"$badging"; then
  echo 'The staging APK must be the isolated package and must not be debuggable.' >&2
  exit 1
fi
# Its own updater (AppUpdateBridge) needs the staging-only install permission.
if ! grep -q "^uses-permission: name='android.permission.REQUEST_INSTALL_PACKAGES'" <<<"$badging"; then
  echo 'The staging APK must be able to install its own updates (src/staging/AndroidManifest.xml).' >&2
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
