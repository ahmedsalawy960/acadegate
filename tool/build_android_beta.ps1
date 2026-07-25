# بناء APK تجريبي لأندرويد — شارك الملف يدوياً أو عبر Firebase App Distribution
# Usage: .\tool\build_android_beta.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

Write-Host "==> Build Android APK (beta)" -ForegroundColor Cyan
flutter build apk --release --dart-define=BETA=true

$apk = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apk) {
  Write-Host ""
  Write-Host "APK ready: $apk" -ForegroundColor Green
  Write-Host "Install on Android: copy file + enable 'Unknown sources' OR use Firebase App Distribution." -ForegroundColor Yellow
} else {
  Write-Host "Build failed — APK not found." -ForegroundColor Red
  exit 1
}
