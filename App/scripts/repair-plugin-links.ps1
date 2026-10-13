#Requires -Version 7.2
# Windows directory junctions repair generated plugin links without changing OS settings.
$ErrorActionPreference = 'Stop'
$taskflowApp = Split-Path -Parent $PSScriptRoot
$taskflowPlugins = Get-Content -LiteralPath (Join-Path $taskflowApp '.flutter-plugins-dependencies') -Raw | ConvertFrom-Json
foreach ($platform in @('windows','linux')) {
    $taskflowLinks = Join-Path $taskflowApp "$platform/flutter/ephemeral/.plugin_symlinks"
    New-Item -ItemType Directory -Path $taskflowLinks -Force | Out-Null
    foreach ($plugin in $taskflowPlugins.plugins.$platform) {
        if ($plugin.name -notmatch '^[a-z][a-z0-9_]*$' -or -not (Test-Path -LiteralPath (Join-Path $plugin.path 'pubspec.yaml'))) { throw 'Invalid plugin metadata.' }
        $taskflowLink = Join-Path $taskflowLinks $plugin.name
        if (-not (Test-Path -LiteralPath $taskflowLink)) {
            New-Item -ItemType Junction -Path $taskflowLink -Target $plugin.path | Out-Null
        }
    }
}
Write-Output 'Generated Windows/Linux plugin links are ready.'
