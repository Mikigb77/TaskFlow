param(
    [string]$Project = 'taskflow-511107',
    [string]$Account = 'tech.garbar@gmail.com'
)
$ErrorActionPreference = 'Stop'
$taskflowBackend = Split-Path -Parent $PSScriptRoot
$taskflowService = "taskflow-ai-staging@$Project.iam.gserviceaccount.com"
function Cloud([string[]]$Arguments) {
    $result = & gcloud @Arguments "--project=$Project" "--account=$Account" --quiet
    if ($LASTEXITCODE -ne 0) { throw "Google Cloud command failed: $($Arguments[0..1] -join ' ')" }
    return $result
}
Cloud @('services', 'enable', 'aiplatform.googleapis.com', 'iamcredentials.googleapis.com')
$taskflowAccounts = @(Cloud @('iam', 'service-accounts', 'list', '--format=value(email)'))
if ($taskflowService -notin $taskflowAccounts) {
    Cloud @('iam', 'service-accounts', 'create', 'taskflow-ai-staging', '--display-name=TaskFlow staging AI')
}
$taskflowRole = "projects/$Project/roles/taskflowAiInvoker"
$taskflowRoles = @(Cloud @('iam', 'roles', 'list', '--format=value(name)'))
$taskflowRoleAction = if ($taskflowRole -in $taskflowRoles) { 'update' } else { 'create' }
Cloud @('iam', 'roles', $taskflowRoleAction, 'taskflowAiInvoker',
    "--file=$taskflowBackend/config/cloud/ai-invoker-role.yaml")
Cloud @('projects', 'add-iam-policy-binding', $Project,
    "--member=serviceAccount:$taskflowService", "--role=$taskflowRole", '--condition=None', '--format=none')
Cloud @('iam', 'service-accounts', 'add-iam-policy-binding', $taskflowService,
    "--member=user:$Account", '--role=roles/iam.serviceAccountTokenCreator', '--condition=None', '--format=none')
Write-Output "Ready: $taskflowService. No service-account key or compute endpoint was created."
