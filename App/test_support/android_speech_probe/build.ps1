param(
    [Parameter(Mandatory=$true)][string]$JavaHome,
    [Parameter(Mandatory=$true)][string]$Python,
    [string]$AndroidSdk = "$env:LOCALAPPDATA\Android\sdk"
)
$ErrorActionPreference = 'Stop'
$build = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\artifacts\android-speech-probe'))
$sdkTools = Join-Path $AndroidSdk 'build-tools\36.1.0'
$androidJar = Join-Path $AndroidSdk 'platforms\android-36.1\android.jar'
$env:JAVA_HOME = $JavaHome
foreach ($directory in @($build, (Join-Path $build 'classes'), (Join-Path $build 'dex'))) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}
function Assert-Exit([string]$Step) { if ($LASTEXITCODE -ne 0) { throw "$Step failed ($LASTEXITCODE)" } }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'generate_audio.ps1') -OutputDirectory $build
Assert-Exit 'Synthetic audio generation'
& $Python (Join-Path $PSScriptRoot 'prepare_assets.py') $build
Assert-Exit 'PCM conversion'
& (Join-Path $JavaHome 'bin\javac.exe') --release 17 -classpath $androidJar -d (Join-Path $build 'classes') (Join-Path $PSScriptRoot 'ProbeActivity.java')
Assert-Exit 'Java compilation'
$classes = @(Get-ChildItem -LiteralPath (Join-Path $build 'classes') -Filter '*.class' -Recurse | ForEach-Object { $_.FullName })
& (Join-Path $sdkTools 'd8.bat') --lib $androidJar --min-api 33 --output (Join-Path $build 'dex') @classes
Assert-Exit 'DEX compilation'
$unsigned = Join-Path $build 'unsigned.apk'
& (Join-Path $sdkTools 'aapt2.exe') link -I $androidJar --manifest (Join-Path $PSScriptRoot 'AndroidManifest.xml') -A (Join-Path $build 'assets') --min-sdk-version 33 --target-sdk-version 36 -o $unsigned
Assert-Exit 'Resource packaging'
& (Join-Path $JavaHome 'bin\jar.exe') uf $unsigned -C (Join-Path $build 'dex') classes.dex
Assert-Exit 'DEX packaging'
$aligned = Join-Path $build 'aligned.apk'
& (Join-Path $sdkTools 'zipalign.exe') -f 4 $unsigned $aligned
Assert-Exit 'Alignment'
$apk = Join-Path $build 'speech-probe.apk'
& (Join-Path $sdkTools 'apksigner.bat') sign --ks (Join-Path $env:USERPROFILE '.android\debug.keystore') --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android --out $apk $aligned
Assert-Exit 'Debug signing'
Write-Output $apk
