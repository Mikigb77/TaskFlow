param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$cases = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'cases.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$output = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $output -Force | Out-Null
$format = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(16000, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
    foreach ($case in $cases) {
        $synth.SelectVoice($case.voice)
        for ($part = 0; $part -lt $case.segments.Count; $part++) {
            $path = Join-Path $output ($case.id + '-' + $part + '.wav')
            $synth.SetOutputToWaveFile($path, $format)
            $synth.Speak($case.segments[$part])
            $synth.SetOutputToNull()
        }
    }
} finally { $synth.Dispose() }
Write-Output ('Generated synthetic WAV segments for ' + $cases.Count + ' cases.')
