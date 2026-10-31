#Requires -Version 7.2
[CmdletBinding()]
param([string]$Device = 'emulator-5556')
$ErrorActionPreference = 'Stop'
$taskflowApp = Split-Path -Parent $PSScriptRoot
$taskflowFixture = Join-Path $taskflowApp 'build/staging-e2e.json'
$taskflowNormalApk = Join-Path $taskflowApp 'build/releases/taskflow-staging.apk'
if (-not (Test-Path -LiteralPath $taskflowFixture) -or -not (Test-Path -LiteralPath $taskflowNormalApk)) {
    throw 'Prepare the private staging fixture and run build-staging.ps1 first.'
}
$taskflowDefines = Get-Content -LiteralPath (Join-Path $taskflowApp 'config/staging.json') -Raw | ConvertFrom-Json -AsHashtable
$taskflowPrivateDefines = Get-Content -LiteralPath $taskflowFixture -Raw | ConvertFrom-Json -AsHashtable
if ($taskflowPrivateDefines.PROJECT_E2E_EMAIL -notlike 'delivered+tf-owner-*@resend.dev' -or
    $taskflowPrivateDefines.API_BASE_URL -ne $taskflowDefines.API_BASE_URL) {
    throw 'Use only the isolated synthetic staging fixture.'
}
foreach ($taskflowKey in $taskflowPrivateDefines.Keys) { $taskflowDefines[$taskflowKey] = $taskflowPrivateDefines[$taskflowKey] }
if ($taskflowDefines.APP_ENV -ne 'staging' -or -not $taskflowDefines.REVENUECAT_TEST_API_KEY.StartsWith('test_')) {
    throw 'This test refuses production or real store keys.'
}
$taskflowEncoded = ($taskflowDefines.GetEnumerator() | ForEach-Object {
    [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($_.Key)=$($_.Value)"))
}) -join ','
$taskflowInstalledTest = $false
Push-Location $taskflowApp
try {
    & flutter build apk --release --target=integration_test/staging_billing_release_test.dart --dart-define-from-file=config/staging.json --dart-define-from-file=build/staging-e2e.json
    if ($LASTEXITCODE -ne 0) { throw 'Release integration APK build failed.' }
    # Gradle reads this property from the process environment; test credentials
    # do not appear in the command line, logs or normal distributable APK.
    Set-Item -LiteralPath 'Env:ORG_GRADLE_PROJECT_dart-defines' -Value $taskflowEncoded
    Push-Location 'android'
    try {
        # Request assembleRelease too: Flutter's task filter otherwise omits
        # compileFlutterBuildRelease for an AndroidTest-only task invocation.
        $taskflowIntegrationTarget = Join-Path $taskflowApp 'integration_test/staging_billing_release_test.dart'
        & ./gradlew.bat app:assembleRelease app:assembleReleaseAndroidTest "-Ptarget=$taskflowIntegrationTarget" -Pbuild-mode=release --console=plain
        if ($LASTEXITCODE -ne 0) { throw 'Android instrumentation APK build failed.' }
    } finally {
        Pop-Location
        Remove-Item -LiteralPath 'Env:ORG_GRADLE_PROJECT_dart-defines' -ErrorAction SilentlyContinue
    }
    & adb -s $Device install -r 'build/app/outputs/flutter-apk/app-release.apk'
    if ($LASTEXITCODE -ne 0) { throw 'Release integration APK install failed.' }
    $taskflowInstalledTest = $true
    & adb -s $Device install -r -t 'build/app/outputs/apk/androidTest/release/app-release-androidTest.apk'
    if ($LASTEXITCODE -ne 0) { throw 'Android instrumentation install failed.' }
    $taskflowResult = & adb -s $Device shell am instrument -w -r -e class com.example.agenda.StagingBillingReleaseTest com.example.agenda.staging.test/androidx.test.runner.AndroidJUnitRunner
    $taskflowResult | Tee-Object -FilePath 'build/staging-release-native-test.log'
    if ($LASTEXITCODE -ne 0 -or -not ($taskflowResult -match 'OK \(1 test\)')) { throw 'Native release checkout verification failed.' }
} finally {
    if ($taskflowInstalledTest) {
        # Keep all existing app data and leave a normal, launchable app installed.
        & adb -s $Device install -r $taskflowNormalApk
        if ($LASTEXITCODE -eq 0) {
            & flutter run --release --no-resident --no-pub --use-application-binary=$taskflowNormalApk -d $Device
        }
    }
    Pop-Location
}
