# Deploy AcadeGate Flutter web to Firebase Hosting.
# Usage: .\scripts\deploy-web.ps1

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "==> flutter build web --release" -ForegroundColor Cyan
flutter build web --release
if ($LASTEXITCODE -ne 0) { throw "flutter build web failed" }

# Ensure static legal pages are present after build (Flutter copies web/**).
$legalSrc = Join-Path $PWD "web\legal"
$legalDst = Join-Path $PWD "build\web\legal"
if (Test-Path $legalSrc) {
  New-Item -ItemType Directory -Force -Path $legalDst | Out-Null
  Copy-Item -Path (Join-Path $legalSrc "*") -Destination $legalDst -Force
  Write-Host "==> copied web/legal -> build/web/legal" -ForegroundColor Cyan
}

Write-Host "==> firebase deploy --only hosting" -ForegroundColor Cyan
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { throw "firebase deploy hosting failed" }

Write-Host ""
Write-Host "Done. Share:" -ForegroundColor Green
Write-Host "  App:      https://acadegate-new.web.app"
Write-Host "  Privacy:  https://acadegate-new.web.app/privacy"
Write-Host "  Terms:    https://acadegate-new.web.app/terms"
Write-Host "  Register: https://acadegate-new.web.app/register"
Write-Host "  Login:    https://acadegate-new.web.app/login"
Write-Host ""
Write-Host "Guide: docs/WEB_HOSTING_AR.md"
