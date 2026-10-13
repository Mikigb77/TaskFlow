param(
    [string]$Device = 'emulator-5556',
    [string]$AudioUrl = '',
    [switch]$SkipAI,
    [switch]$ExpectProviderUnavailable
)

$ErrorActionPreference = 'Stop'
$taskflowApp = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $taskflowApp
try {
    if ($SkipAI -and $ExpectProviderUnavailable) {
        throw 'Choose collaboration-only checks or the live provider outage check, not both.'
    }
    if (-not (Test-Path -LiteralPath 'build/project-e2e.json')) {
        throw 'Create the isolated fixture with Backend/scripts/validate_projects.py first.'
    }
    $taskflowArguments = @(
        'drive', '--keep-app-running',
        '--driver=test_driver/appearance_test.dart',
        '--target=integration_test/projects_flow_test.dart',
        '-d', $Device,
        '--dart-define-from-file=config/development.json',
        '--dart-define-from-file=build/project-e2e.json'
    )
    if ($SkipAI) { $taskflowArguments += '--dart-define=PROJECT_E2E_AI=false' }
    if ($AudioUrl) { $taskflowArguments += "--dart-define=PROJECT_E2E_AUDIO_URL=$AudioUrl" }
    if ($ExpectProviderUnavailable) {
        $taskflowArguments += '--dart-define=PROJECT_E2E_EXPECT_UNAVAILABLE=true'
    }
    & flutter @taskflowArguments
    $taskflowResult = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $taskflowResult
