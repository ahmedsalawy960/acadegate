# Deploy AcadeGate Flutter web to Firebase Hosting.
# Usage: .\scripts\deploy-web.ps1

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "==> flutter build web --release" -ForegroundColor Cyan
flutter build web --release
if ($LASTEXITCODE -ne 0) { throw "flutter build web failed" }

Write-Host "==> firebase deploy --only hosting" -ForegroundColor Cyan
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { throw "firebase deploy hosting failed" }

Write-Host ""
Write-Host "Done. Share:" -ForegroundColor Green
Write-Host "  https://acadegate-new.web.app"
Write-Host "  https://acadegate-new.firebaseapp.com"
Write-Host ""
Write-Host "Guide: docs/WEB_HOSTING_AR.md"
