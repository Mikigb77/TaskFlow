#Requires -Version 7.2
[CmdletBinding()]
param([switch]$PrepareOnly)
$ErrorActionPreference = 'Stop'
$taskflowApp = Split-Path -Parent $PSScriptRoot
$taskflowPrivate = Join-Path $taskflowApp '.credentials'
$taskflowStore = Join-Path $taskflowPrivate 'staging.jks'
$taskflowProperties = Join-Path $taskflowPrivate 'staging-signing.properties'
New-Item -ItemType Directory -Path $taskflowPrivate -Force | Out-Null
if (-not (Test-Path -LiteralPath $taskflowProperties)) {
    if (Test-Path -LiteralPath $taskflowStore) { throw 'A staging keystore exists without its properties. Recover them before continuing.' }
    $env:TASKFLOW_STAGING_SIGNING_PASSWORD = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    try {
        & keytool -genkeypair -keystore $taskflowStore -storetype JKS -storepass:env TASKFLOW_STAGING_SIGNING_PASSWORD -keypass:env TASKFLOW_STAGING_SIGNING_PASSWORD -alias taskflow-staging -keyalg RSA -keysize 3072 -validity 3650 -dname 'CN=TaskFlow Staging, OU=Development, O=GarBar, C=ES' -noprompt
        if ($LASTEXITCODE -ne 0) { throw 'Staging signing key creation failed.' }
        @("storeFile=$($taskflowStore.Replace('\','/'))", "storePassword=$env:TASKFLOW_STAGING_SIGNING_PASSWORD", "keyPassword=$env:TASKFLOW_STAGING_SIGNING_PASSWORD", 'keyAlias=taskflow-staging') | Set-Content -LiteralPath $taskflowProperties
    } finally { Remove-Item Env:TASKFLOW_STAGING_SIGNING_PASSWORD -ErrorAction SilentlyContinue }
}
if ($PrepareOnly) { Write-Output 'Private staging signing is ready.'; return }
$taskflowConfig = Get-Content -LiteralPath (Join-Path $taskflowApp 'config/staging.json') -Raw | ConvertFrom-Json -AsHashtable
if ($taskflowConfig.APP_ENV -ne 'staging' -or $taskflowConfig.DEV_LOGIN_ENABLED -ne 'false' -or
    -not $taskflowConfig.REVENUECAT_TEST_API_KEY.StartsWith('test_') -or
    $taskflowConfig.API_BASE_URL -notlike 'https://*') {
    throw 'Staging requires HTTPS, an explicit Test Store key, and development login disabled.'
}
if (@($taskflowConfig.Keys | Where-Object { $_ -match 'E2E|PASSWORD|SECRET|TOKEN' }).Count) {
    throw 'Private test credentials must never be compiled into the distributable APK.'
}
Push-Location $taskflowApp
try {
    # The same build number as CI (ci-build-staging.sh): pubspec's plus the commits
    # to this one, so the staging app can update from one build to the next.
    $taskflowBase = [regex]::Match((Get-Content -LiteralPath 'pubspec.yaml' -Raw), '(?m)^version:\s*[^+\s]+\+(\d+)\s*$').Groups[1].Value
    if (-not $taskflowBase) { throw 'pubspec.yaml needs a version such as 1.0.5+4007.' }
    if ((& git rev-parse --is-shallow-repository).Trim() -ne 'false') { throw 'A shallow clone would number this build wrongly.' }
    $taskflowNumber = [int]$taskflowBase + [int](& git rev-list --count HEAD).Trim()
    & flutter build apk --release --target=lib/main.dart --dart-define-from-file=config/staging.json --build-number=$taskflowNumber
    if ($LASTEXITCODE -ne 0) { throw 'Staging APK build failed.' }
    $taskflowSdkLine = Get-Content -LiteralPath 'android/local.properties' | Where-Object { $_.StartsWith('sdk.dir=') } | Select-Object -First 1
    $taskflowSdk = $taskflowSdkLine.Substring(8).Replace('\\', '\').Replace('\:', ':')
    $taskflowAapt = Get-ChildItem -Path (Join-Path $taskflowSdk 'build-tools/*/aapt2.exe') | Sort-Object FullName -Descending | Select-Object -First 1
    if (-not $taskflowAapt) { throw 'Android aapt2 is required to verify the staging APK.' }
    $taskflowBadging = & $taskflowAapt.FullName dump badging 'build/app/outputs/flutter-apk/app-release.apk'
    if ($LASTEXITCODE -ne 0 -or
        -not ($taskflowBadging -match "^package: name='com.example.agenda.staging'") -or
        ($taskflowBadging -match '^application-debuggable')) {
        throw 'The staging APK must be the isolated package and must not be debuggable.'
    }
    $taskflowVersion = [regex]::Match(($taskflowBadging -match '^package:')[0], "versionName='([^']+)'").Groups[1].Value
    $taskflowCode = [regex]::Match(($taskflowBadging -match '^package:')[0], "versionCode='([^']+)'").Groups[1].Value
    $taskflowOutput = Join-Path $taskflowApp 'build/releases/taskflow-staging.apk'
    New-Item -ItemType Directory -Path (Split-Path -Parent $taskflowOutput) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $taskflowApp 'build/app/outputs/flutter-apk/app-release.apk') -Destination $taskflowOutput
    $taskflowHash = (Get-FileHash -LiteralPath $taskflowOutput -Algorithm SHA256).Hash
    @{file='taskflow-staging.apk'; sha256=$taskflowHash; applicationId='com.example.agenda.staging'; version=$taskflowVersion; versionCode=$taskflowCode; debuggable=$false; billing='revenuecat-test-store'; built=(Get-Date).ToUniversalTime().ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskflowApp 'build/releases/staging-build.json')
    Write-Output "Private staging APK: $taskflowOutput"
    Write-Output "SHA256: $taskflowHash"
} finally { Pop-Location }
