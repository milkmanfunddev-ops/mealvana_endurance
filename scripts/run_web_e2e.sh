#!/usr/bin/env bash
#
# Web e2e runner: drives the REAL app in a REAL Chrome via `flutter drive` +
# the integration_test package. This is the supported way to e2e-test Flutter
# web (the UI is a <canvas>, so Playwright/Selenium can't see widgets, but
# flutter drive runs against the widget tree).
#
# One-time prerequisite — install chromedriver matching your Chrome version:
#   brew install chromedriver           # macOS
#   chromedriver --version              # then verify it matches Chrome
#   xattr -d com.apple.quarantine "$(which chromedriver)"   # macOS Gatekeeper
#
# Usage:
#   scripts/run_web_e2e.sh                       # uses .env.web.local (dev)
#   ENV_FILE=.env.web.prod.local scripts/run_web_e2e.sh
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-.env.web.local}"
DRIVER_PORT="${DRIVER_PORT:-4444}"
TARGET="${TARGET:-web_e2e/app_boot_test.dart}"

if ! command -v chromedriver >/dev/null 2>&1; then
  echo "ERROR: chromedriver not found on PATH. Install it (see header of this script)." >&2
  exit 1
fi
if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: env file '$ENV_FILE' not found." >&2
  exit 1
fi

echo "Starting chromedriver on :$DRIVER_PORT ..."
chromedriver --port="$DRIVER_PORT" >/tmp/chromedriver_web_e2e.log 2>&1 &
CD_PID=$!
trap 'kill "$CD_PID" 2>/dev/null || true' EXIT
sleep 2

echo "Running flutter drive against $TARGET ..."
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target="$TARGET" \
  -d web-server \
  --browser-name=chrome \
  --driver-port="$DRIVER_PORT" \
  --dart-define-from-file="$ENV_FILE"
