param([ValidateSet('auto', 'vertex', 'ai_studio')][string]$Mode = 'auto')
$ErrorActionPreference = 'Stop'
$taskflowBackend = Split-Path -Parent $PSScriptRoot
$taskflowCredentials = Join-Path $taskflowBackend '.credentials/gcloud/application_default_credentials.json'
if (-not (Test-Path -LiteralPath $taskflowCredentials)) {
    throw 'Run scripts/setup-vertex.ps1 and scripts/login-vertex.ps1 first.'
}
$taskflowIdentity = Get-Content -LiteralPath $taskflowCredentials -Raw | ConvertFrom-Json
if ($taskflowIdentity.type -ne 'impersonated_service_account' -or
    $taskflowIdentity.service_account_impersonation_url -ne
        'https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/taskflow-ai-staging@taskflow-511107.iam.gserviceaccount.com:generateAccessToken') {
    throw 'Expected the dedicated TaskFlow staging identity, not general account credentials.'
}
$taskflowPreviousMode = $env:TASKFLOW_AI_ROUTE
Push-Location -LiteralPath $taskflowBackend
try {
    $env:TASKFLOW_AI_ROUTE = $Mode
    & docker compose -f compose.yaml -f compose.vertex.yaml up -d --build --wait
    if ($LASTEXITCODE -ne 0) { throw 'The local backend did not become healthy.' }
} finally {
    $env:TASKFLOW_AI_ROUTE = $taskflowPreviousMode
    Pop-Location
}
Write-Output "Local backend is using AI route: $Mode."
