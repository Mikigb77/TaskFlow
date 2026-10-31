param(
    [ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$Avd = 'TaskFlow_API_36_1',
    [ValidateRange(5554, 5682)][int]$Port = 5556
)

$ErrorActionPreference = 'Stop'
if ($Port % 2 -ne 0) { throw 'Android emulator console ports must be even.' }
$taskflowAdb = (Get-Command adb -ErrorAction Stop).Source
$taskflowSdk = Split-Path -Parent (Split-Path -Parent $taskflowAdb)
$taskflowEmulator = Join-Path $taskflowSdk 'emulator/emulator.exe'
$taskflowSerial = "emulator-$Port"
$taskflowApp = Split-Path -Parent $PSScriptRoot
$taskflowBuild = Join-Path $taskflowApp 'build'
New-Item -ItemType Directory -Path $taskflowBuild -Force | Out-Null

$taskflowDevices = & $taskflowAdb devices
if ($LASTEXITCODE -ne 0) { throw 'ADB could not list devices.' }
# Dart Code's emulatorId also finds an already running AVD on any port.
# Reuse that same instance instead of launching a duplicate after a restart.
foreach ($taskflowDevice in $taskflowDevices) {
    if ($taskflowDevice -match '^(emulator-\d+)\s+device\b') {
        $taskflowCandidate = $Matches[1]
        $taskflowName = @(& $taskflowAdb -s $taskflowCandidate emu avd name)[0]
        if ($taskflowName -and $taskflowName.Trim() -eq $Avd) {
            $taskflowSerial = $taskflowCandidate
            break
        }
    }
}
if (-not ($taskflowDevices -match "^$taskflowSerial\s")) {
    $taskflowAvds = & $taskflowEmulator -list-avds
    if ($LASTEXITCODE -ne 0 -or $Avd -notin $taskflowAvds) {
        throw "The dedicated $Avd emulator is missing. Create it in Android Device Manager with at least 12 GB internal storage."
    }
    Write-Output "Starting $Avd on $taskflowSerial..."
    Start-Process -FilePath $taskflowEmulator -WindowStyle Hidden -ArgumentList @(
        '-avd', $Avd, '-port', "$Port", '-no-snapshot-load'
    ) -RedirectStandardOutput (Join-Path $taskflowBuild 'emulator-start.log') `
      -RedirectStandardError (Join-Path $taskflowBuild 'emulator-start-error.log') | Out-Null
}

$taskflowDeadline = [DateTime]::UtcNow.AddMinutes(3)
$taskflowReady = $false
while ([DateTime]::UtcNow -lt $taskflowDeadline) {
    $taskflowDevices = & $taskflowAdb devices
    if ($taskflowDevices -match "^$taskflowSerial\s+device\b") {
        $taskflowActualAvd = @(& $taskflowAdb -s $taskflowSerial emu avd name)[0]
        if (-not $taskflowActualAvd) {
            Start-Sleep -Seconds 2
            continue
        }
        if ($taskflowActualAvd.Trim() -ne $Avd) {
            throw "$taskflowSerial belongs to $taskflowActualAvd, not $Avd. Close that emulator or select a different development device; it has been left running."
        }
        $taskflowBooted = & $taskflowAdb -s $taskflowSerial shell getprop sys.boot_completed
        if ($LASTEXITCODE -eq 0 -and ($taskflowBooted -join '').Trim() -eq '1') {
            $taskflowReady = $true
            break
        }
    }
    Start-Sleep -Seconds 2
}
if (-not $taskflowReady) {
    throw "The emulator did not finish booting. Check $taskflowBuild/emulator-start-error.log."
}

function Get-TaskFlowFreeSpace {
    $taskflowDisk = @(& $taskflowAdb -s $taskflowSerial shell df -k /data)
    if ($LASTEXITCODE -ne 0 -or $taskflowDisk.Count -lt 2) {
        throw 'Could not verify emulator storage; refusing to risk an uninstall/reinstall.'
    }
    return [long](($taskflowDisk[-1].Trim() -split '\s+')[3]) * 1024
}
$taskflowFree = Get-TaskFlowFreeSpace
if ($taskflowFree -lt 1GB) {
    # Android cache is disposable. Never use pm clear, uninstall or -wipe-data.
    & $taskflowAdb -s $taskflowSerial shell pm trim-caches 2G internal
    $taskflowFree = Get-TaskFlowFreeSpace
}
if ($taskflowFree -lt 1GB) {
    throw 'Less than 1 GB is available. Free emulator storage before running again; Flutter may otherwise uninstall the app after a failed update.'
}
Write-Output ("Ready: {0} ({1}), {2:N1} GB free." -f $Avd, $taskflowSerial, ($taskflowFree / 1GB))
