# One-time setup for Flutter Windows builds (flutter_tts needs nuget.exe on PATH).
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$tools = Join-Path $root "tools"
$nuget = Join-Path $tools "nuget.exe"

New-Item -ItemType Directory -Force -Path $tools | Out-Null

if (-not (Test-Path $nuget)) {
    Write-Host "Downloading nuget.exe..."
    Invoke-WebRequest `
        -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" `
        -OutFile $nuget `
        -UseBasicParsing
    Write-Host "Saved: $nuget"
} else {
    Write-Host "nuget.exe already present: $nuget"
}

$env:PATH = "$tools;$env:PATH"
Write-Host ""
Write-Host "OK. For this terminal session, nuget is on PATH."
Write-Host "Run Flutter from Cursor using 'AcadeGate (Windows + AI)' or:"
Write-Host "  flutter run -d windows --dart-define-from-file=dart_defines.json"
