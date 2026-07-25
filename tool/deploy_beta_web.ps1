# نشر تجريبي خاص — AcadeGate (لا يظهر في محركات البحث)
# Usage: .\tool\deploy_beta_web.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

Write-Host "==> Build web (beta)" -ForegroundColor Cyan
flutter build web --release --dart-define=BETA=true

Write-Host "==> Deploy Firebase Hosting (private link)" -ForegroundColor Cyan
firebase deploy --only hosting --project acadegate-new

Write-Host ""
Write-Host "Done. Open the hosting URL on iPhone/Android (Safari/Chrome)." -ForegroundColor Green
Write-Host "Add to Home Screen for app-like experience." -ForegroundColor Green
