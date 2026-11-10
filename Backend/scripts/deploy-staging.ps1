#Requires -Version 7.2
[CmdletBinding()]
param(
    [string]$Project = 'taskflow-511107',
    [string]$Account = 'tech.garbar@gmail.com',
    [string]$Region = 'europe-west3',
    [switch]$SkipBuild,
    [string]$Image
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$taskflowBackend = Split-Path -Parent $PSScriptRoot
$taskflowService = 'taskflow-api-staging'
$taskflowRuntime = "$taskflowService@$Project.iam.gserviceaccount.com"
$taskflowBuilder = "taskflow-api-builder@$Project.iam.gserviceaccount.com"
$taskflowMailInvoker = "taskflow-mail-invoker@$Project.iam.gserviceaccount.com"
$taskflowMaintenance = 'taskflow-api-staging-maintain'
$taskflowQueue = 'taskflow-staging-email'
$taskflowBucket = "$Project-api-staging-builds"
$taskflowSecret = 'taskflow-api-staging-config'
function Cloud([string[]]$Arguments) {
    $result = & gcloud @Arguments "--project=$Project" "--account=$Account" --quiet
    if ($LASTEXITCODE -ne 0) { throw "Google Cloud command failed: $($Arguments[0..1] -join ' ')" }
    return $result
}
function Read-TaskFlowEnv([string]$Path) {
    $result = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^([A-Z_][A-Z_0-9]*)=(.*)$') {
            $value = $Matches[2].Trim()
            if ($value.StartsWith('"') -and $value.EndsWith('"')) { $value = $value | ConvertFrom-Json }
            elseif ($value.StartsWith("'") -and $value.EndsWith("'")) { $value = $value.Substring(1, $value.Length - 2) }
            $result[$Matches[1]] = $value
        }
    }
    return $result
}
$taskflowBranch = (& git -C $taskflowBackend branch --show-current).Trim()
if ($taskflowBranch -eq 'main') { throw 'Deploy staging from dev or another development branch.' }
$taskflowNeon = Read-TaskFlowEnv (Join-Path $taskflowBackend '.credentials/staging.env')
foreach ($required in @('DATABASE_URL','DATABASE_URL_UNPOOLED','AWS_ACCESS_KEY_ID','AWS_SECRET_ACCESS_KEY','AWS_ENDPOINT_URL_S3','AWS_REGION')) {
    if (-not $taskflowNeon[$required]) { throw "Missing private staging configuration: $required" }
}
if ($taskflowNeon.DATABASE_URL -notmatch '/taskflow_staging\?' -or $taskflowNeon.DATABASE_URL -notmatch 'sslmode=verify-full') {
    throw 'Expected the dedicated staging database with verified TLS.'
}
$taskflowProject = (Cloud @('projects','describe',$Project,'--format=json')) | ConvertFrom-Json
$taskflowUrl = "https://$taskflowService-$($taskflowProject.projectNumber).$Region.run.app"
$taskflowKeyFile = Join-Path $taskflowBackend '.credentials/staging-django-key'
if (-not (Test-Path -LiteralPath $taskflowKeyFile)) {
    [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(64)) | Set-Content -LiteralPath $taskflowKeyFile -NoNewline
}
$taskflowValues = @{
    DJANGO_SECRET_KEY = (Get-Content -LiteralPath $taskflowKeyFile -Raw).Trim()
    REVENUECAT_API_KEY = 'test_EklrUiqxOvqXwTyiioVgnTwnBif'
}
foreach ($key in @('DATABASE_URL','DATABASE_URL_UNPOOLED','AWS_ACCESS_KEY_ID','AWS_SECRET_ACCESS_KEY','AWS_ENDPOINT_URL_S3','AWS_REGION')) {
    $taskflowValues[$key] = $taskflowNeon[$key]
}
$taskflowResendPath = Join-Path $taskflowBackend '.credentials/staging-resend-key'
if (-not (Test-Path -LiteralPath $taskflowResendPath)) { throw 'Configure the private Resend sending key before deploying.' }
$taskflowValues.RESEND_API_KEY = (Get-Content -LiteralPath $taskflowResendPath -Raw).Trim()
# The staging app's updater: a read-only GitHub token for the app repo's releases
# (core/app_updates.py, Backend/docs/STAGING.md "Updates of the staging app").
$taskflowUpdateTokenPath = Join-Path $taskflowBackend '.credentials/staging-github-token'
if (Test-Path -LiteralPath $taskflowUpdateTokenPath) {
    $taskflowValues.APP_UPDATE_GITHUB_TOKEN = (Get-Content -LiteralPath $taskflowUpdateTokenPath -Raw).Trim()
}
$taskflowPrivateJson = Join-Path $taskflowBackend '.credentials/staging-runtime.json'
$taskflowValues | ConvertTo-Json | Set-Content -LiteralPath $taskflowPrivateJson
Cloud @('services','enable','run.googleapis.com','cloudbuild.googleapis.com','artifactregistry.googleapis.com','secretmanager.googleapis.com','aiplatform.googleapis.com','cloudtasks.googleapis.com','cloudscheduler.googleapis.com','cloudresourcemanager.googleapis.com') | Out-Null
$taskflowAccounts = @(Cloud @('iam','service-accounts','list','--format=value(email)'))
foreach ($id in @($taskflowService,'taskflow-api-builder','taskflow-mail-invoker')) {
    if ("$id@$Project.iam.gserviceaccount.com" -notin $taskflowAccounts) {
        Cloud @('iam','service-accounts','create',$id,"--display-name=TaskFlow $id") | Out-Null
    }
}
Cloud @('projects','add-iam-policy-binding',$Project,"--member=serviceAccount:$taskflowRuntime","--role=projects/$Project/roles/taskflowAiInvoker",'--condition=None','--format=none') | Out-Null
$taskflowQueues = @(Cloud @('tasks','queues','list',"--location=$Region",'--format=value(name)'))
if (-not ($taskflowQueues -match "(^|/)$taskflowQueue$")) {
    Cloud @('tasks','queues','create',$taskflowQueue,"--location=$Region",'--max-dispatches-per-second=1','--max-concurrent-dispatches=1','--max-attempts=5','--min-backoff=30s') | Out-Null
}
Cloud @('tasks','queues','add-iam-policy-binding',$taskflowQueue,"--location=$Region","--member=serviceAccount:$taskflowRuntime",'--role=roles/cloudtasks.enqueuer','--format=none') | Out-Null
Cloud @('iam','service-accounts','add-iam-policy-binding',$taskflowMailInvoker,"--member=serviceAccount:$taskflowRuntime",'--role=roles/iam.serviceAccountUser','--format=none') | Out-Null
$taskflowSecrets = @(Cloud @('secrets','list','--format=value(name)'))
if (-not ($taskflowSecrets -match "(^|/)$taskflowSecret$")) { Cloud @('secrets','create',$taskflowSecret,'--replication-policy=automatic') | Out-Null }
$taskflowSecretVersion = (Cloud @('secrets','versions','add',$taskflowSecret,"--data-file=$taskflowPrivateJson",'--format=value(name)')).Trim().Split('/')[-1]
Cloud @('secrets','add-iam-policy-binding',$taskflowSecret,"--member=serviceAccount:$taskflowRuntime",'--role=roles/secretmanager.secretAccessor','--format=none') | Out-Null
$taskflowRepositories = @(Cloud @('artifacts','repositories','list',"--location=$Region",'--format=value(name)'))
if (-not ($taskflowRepositories -match '(^|/)taskflow-api$')) {
    Cloud @('artifacts','repositories','create','taskflow-api',"--location=$Region",'--repository-format=docker') | Out-Null
}
Cloud @('artifacts','repositories','add-iam-policy-binding','taskflow-api',"--location=$Region","--member=serviceAccount:$taskflowBuilder",'--role=roles/artifactregistry.writer','--format=none') | Out-Null
$taskflowBuckets = @(Cloud @('storage','buckets','list','--format=value(name)'))
if (-not ($taskflowBuckets -match [regex]::Escape($taskflowBucket))) {
    Cloud @('storage','buckets','create',"gs://$taskflowBucket","--location=$Region",'--uniform-bucket-level-access','--public-access-prevention') | Out-Null
}
Cloud @('storage','buckets','add-iam-policy-binding',"gs://$taskflowBucket","--member=serviceAccount:$taskflowBuilder",'--role=roles/storage.objectViewer','--format=none') | Out-Null
Cloud @('projects','add-iam-policy-binding',$Project,"--member=serviceAccount:$taskflowBuilder",'--role=roles/logging.logWriter','--condition=None','--format=none') | Out-Null
if (-not $SkipBuild) {
    $taskflowTag = 'staging-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    $Image = "$Region-docker.pkg.dev/$Project/taskflow-api/backend:$taskflowTag"
    $taskflowSource = Join-Path $taskflowBackend "artifacts/source-$taskflowTag"
    New-Item -ItemType Directory -Path $taskflowSource -Force | Out-Null
    # Explicit allowlist: no .env, signing keys, ADC, media, or database dumps.
    foreach ($name in @('core','config','templates','manage.py','requirements.txt','requirements-lock.txt','Dockerfile','.dockerignore')) {
        Copy-Item -LiteralPath (Join-Path $taskflowBackend $name) -Destination $taskflowSource -Recurse
    }
    New-Item -ItemType Directory -Path (Join-Path $taskflowSource 'scripts') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'start-server.sh') -Destination (Join-Path $taskflowSource 'scripts/start-server.sh')
    Cloud @('builds','submit',$taskflowSource,"--region=$Region","--config=$taskflowSource/config/cloud/build-staging.yaml","--service-account=projects/$Project/serviceAccounts/$taskflowBuilder","--gcs-source-staging-dir=gs://$taskflowBucket/source","--substitutions=_IMAGE=$Image") | Out-Null
}
if (-not $Image -or -not $Image.StartsWith("$Region-docker.pkg.dev/$Project/taskflow-api/")) { throw 'Use a TaskFlow API staging image.' }
$taskflowImageData = (Cloud @('artifacts','docker','images','describe',$Image,'--format=json')) | ConvertFrom-Json
$taskflowDigest = $taskflowImageData.image_summary.fully_qualified_digest
$taskflowEnvironment = @{
    TASKFLOW_CONFIG_FILE='/secrets/taskflow/config.json'; DEPLOYMENT_ENVIRONMENT='staging'
    DJANGO_DEBUG='0'; DJANGO_ALLOWED_HOSTS=([Uri]$taskflowUrl).Host
    STATE_BACKEND='postgres'; REQUIRE_HTTPS='1'; CLOUD_RUN_PROXY='1'; TRUSTED_PROXY_COUNT='1'
    PGSSLROOTCERT='/etc/ssl/certs/ca-certificates.crt'
    REVENUECAT_ALLOW_SANDBOX='1'; LOCAL_TEST_ACCOUNT_ENABLED='0'
    GOOGLE_OAUTH_CLIENT_IDS='177649734578-cr3scnkukf14a1bbl7bpcj49t9aorft0.apps.googleusercontent.com'
    STAGING_ALLOWED_EMAILS='tech.garbar@gmail.com,mikigb77@gmail.com'; DEFAULT_TIME_ZONE='Europe/Madrid'
    COMPLIMENTARY_PRO_EMAILS='mikigb77@gmail.com'
    COMPLIMENTARY_PRO_BILLING_IDS='b5684da7-3f9f-4a26-99bd-a3d218c3e6c3'
    EMAIL_BACKEND='core.email_delivery.ResendBackend'; DEFAULT_FROM_EMAIL='TaskFlow <noreply@garbar.tech>'
    PASSWORD_RESET_BASE_URL="$taskflowUrl/reset-password/"; INVITATION_BASE_URL="$taskflowUrl/invite/"
    EMAIL_RETRY_QUEUE="projects/$Project/locations/$Region/queues/$taskflowQueue"
    EMAIL_RETRY_JOB="https://run.googleapis.com/v2/projects/$Project/locations/$Region/jobs/${taskflowMaintenance}:run"
    EMAIL_RETRY_IDENTITY=$taskflowMailInvoker
    AI_VERTEX_PROJECT=$Project; AI_VERTEX_LOCATION='global'
    AI_VERTEX_TEXT_MODEL='gemini-3.1-flash-lite'; AI_VERTEX_AUDIO_MODEL='gemini-3.1-flash-lite'
    AI_REQUESTS_PER_DAY='30'; ATTACHMENT_BUCKET='docs4taskflow'
}
$taskflowEnvFile = Join-Path $taskflowBackend 'artifacts/staging-environment.json'
$taskflowEnvironment | ConvertTo-Json | Set-Content -LiteralPath $taskflowEnvFile
$taskflowSecretsFlag = "--set-secrets=/secrets/taskflow/config.json=${taskflowSecret}:$taskflowSecretVersion"
Cloud @('run','jobs','deploy','taskflow-api-staging-migrate',"--region=$Region","--image=$taskflowDigest","--service-account=$taskflowRuntime",'--command=python','--args=manage.py,migrate,--noinput',"--env-vars-file=$taskflowEnvFile",$taskflowSecretsFlag,'--tasks=1','--max-retries=0','--task-timeout=300s','--memory=512Mi','--cpu=1') | Out-Null
Cloud @('run','jobs','update','taskflow-api-staging-migrate',"--region=$Region",'--update-env-vars=MIGRATION_DATABASE_DIRECT=1') | Out-Null
Cloud @('run','jobs','execute','taskflow-api-staging-migrate',"--region=$Region",'--wait') | Out-Null
Cloud @('run','jobs','deploy',$taskflowMaintenance,"--region=$Region","--image=$taskflowDigest","--service-account=$taskflowRuntime",'--command=python','--args=manage.py,maintain_staging',"--env-vars-file=$taskflowEnvFile",$taskflowSecretsFlag,'--tasks=1','--max-retries=0','--task-timeout=600s','--memory=512Mi','--cpu=1') | Out-Null
Cloud @('run','jobs','add-iam-policy-binding',$taskflowMaintenance,"--region=$Region","--member=serviceAccount:$taskflowMailInvoker",'--role=roles/run.invoker','--format=none') | Out-Null
$taskflowSchedules = @(Cloud @('scheduler','jobs','list',"--location=$Region",'--format=value(name)'))
$taskflowScheduleAction = if ($taskflowSchedules -match "(^|/)$taskflowMaintenance$") { 'update' } else { 'create' }
Cloud @('scheduler','jobs',$taskflowScheduleAction,'http',$taskflowMaintenance,"--location=$Region",'--schedule=17 3 * * *','--time-zone=Europe/Madrid',"--uri=$($taskflowEnvironment.EMAIL_RETRY_JOB)",'--http-method=POST',"--oauth-service-account-email=$taskflowMailInvoker",'--message-body={}','--attempt-deadline=60s','--max-retry-attempts=2') | Out-Null
# The CLI's --startup-probe flag cannot set HTTP headers. A manifest lets the
# internal probe pass Django's strict host and HTTPS checks without relaxing them.
$taskflowManifest = @{
    apiVersion='serving.knative.dev/v1'; kind='Service'
    metadata=@{name=$taskflowService; namespace=[string]$taskflowProject.projectNumber
        labels=@{app='taskflow'; environment='staging'}
        annotations=@{'run.googleapis.com/ingress'='all'; 'run.googleapis.com/maxScale'='2'}}
    spec=@{
        template=@{
            metadata=@{annotations=@{'run.googleapis.com/cpu-throttling'='true'; 'run.googleapis.com/startup-cpu-boost'='false'}}
            spec=@{
                serviceAccountName=$taskflowRuntime; containerConcurrency=4; timeoutSeconds=120
                containers=@(@{
                    image=$taskflowDigest; ports=@(@{containerPort=8080; name='http1'})
                    resources=@{limits=@{cpu='1'; memory='1Gi'}}
                    env=@($taskflowEnvironment.GetEnumerator() | Sort-Object Key | ForEach-Object { @{name=$_.Key; value=[string]$_.Value} })
                    volumeMounts=@(@{name='runtime-config'; mountPath='/secrets/taskflow'})
                    startupProbe=@{timeoutSeconds=5; periodSeconds=10; failureThreshold=12
                        httpGet=@{path='/api/live/'; port=8080; httpHeaders=@(
                            @{name='Host'; value=([Uri]$taskflowUrl).Host},
                            @{name='X-Forwarded-Proto'; value='https'})}}
                })
                volumes=@(@{name='runtime-config'; secret=@{secretName=$taskflowSecret
                    items=@(@{key=[string]$taskflowSecretVersion; path='config.json'})}})
            }
        }
        traffic=@(@{latestRevision=$true; percent=100})
    }
}
$taskflowManifestFile = Join-Path $taskflowBackend 'artifacts/staging-service.json'
$taskflowManifest | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $taskflowManifestFile
Cloud @('run','services','replace',$taskflowManifestFile,"--region=$Region") | Out-Null
Cloud @('run','services','add-iam-policy-binding',$taskflowService,"--region=$Region",'--member=allUsers','--role=roles/run.invoker','--format=none') | Out-Null
$taskflowHealth = Invoke-RestMethod "$taskflowUrl/api/health/" -TimeoutSec 90
if ($taskflowHealth.status -ne 'ok') { throw 'Staging dependency health check failed.' }
@{url=$taskflowUrl; image=$taskflowDigest; secretVersion=$taskflowSecretVersion; region=$Region; deployed=(Get-Date).ToUniversalTime().ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskflowBackend 'artifacts/staging-deployment.json')
Write-Output "Staging deployed and healthy: $taskflowUrl"
