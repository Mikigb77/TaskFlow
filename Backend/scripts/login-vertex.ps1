param(
    [string]$Project = 'taskflow-511107',
    [string]$Account = 'tech.garbar@gmail.com',
    [switch]$NoLaunchBrowser
)
$ErrorActionPreference = 'Stop'
$taskflowBackend = Split-Path -Parent $PSScriptRoot
$taskflowConfig = Join-Path $taskflowBackend '.credentials/gcloud'
$taskflowPreviousConfig = $env:CLOUDSDK_CONFIG
New-Item -ItemType Directory -Path $taskflowConfig -Force | Out-Null
try {
    # Isolate TaskFlow ADC from the developer's other projects and accounts.
    $env:CLOUDSDK_CONFIG = $taskflowConfig
    # A positional ACCOUNT triggers gcloud ID-token validation, but impersonation
    # requests only cloud-platform scope (no ID token). Use the global flag.
    Write-Output "Select $Account in Google's account chooser."
    $taskflowArguments = @('auth', 'application-default', 'login', "--account=$Account",
        "--project=$Project", "--billing-project=$Project",
        "--impersonate-service-account=taskflow-ai-staging@$Project.iam.gserviceaccount.com")
    if ($NoLaunchBrowser) { $taskflowArguments += '--no-launch-browser' }
    & gcloud @taskflowArguments
    if ($LASTEXITCODE -ne 0) { throw 'TaskFlow Google authorization did not complete.' }
    # gcloud's set-quota-project supports user ADC only. The Python client sets
    # the quota project explicitly when loading this impersonated identity.
} finally {
    $env:CLOUDSDK_CONFIG = $taskflowPreviousConfig
}
Write-Output 'TaskFlow credentials are ready in the ignored .credentials directory.'
