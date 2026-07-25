#!/usr/bin/env bash
# AcadeGate — تشغيل على Mac (سطح المكتب أو iPhone متصل)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Flutter doctor (ملخص)"
flutter doctor -v | head -n 30

echo ""
echo "==> Dependencies"
flutter pub get

MODE="${1:-ios}"

if [[ "$MODE" == "macos" ]]; then
  echo ""
  echo "==> CocoaPods (macOS)"
  (cd macos && pod install)
  echo ""
  echo "==> تشغيل AcadeGate على macOS"
  flutter run -d macos \
    --dart-define=GOOGLE_WEB_CLIENT_ID="${GOOGLE_WEB_CLIENT_ID:-}"
elif [[ "$MODE" == "ios" ]]; then
  echo ""
  echo "==> CocoaPods (iOS)"
  (cd ios && pod install)
  echo ""
  echo "==> الأجهزة المتاحة:"
  flutter devices
  echo ""
  echo "==> تشغيل AcadeGate على iOS (وصّل iPhone 11 أو اختر المحاكي)"
  flutter run -d ios
else
  echo "Usage: ./tool/run_on_mac.sh [ios|macos]"
  exit 1
fi
