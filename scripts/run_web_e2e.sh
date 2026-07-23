#!/usr/bin/env bash
#
# Web e2e runner: drives the REAL app in a REAL Chrome via `flutter drive` +
# the integration_test package. This is the supported way to e2e-test Flutter
# web (the UI is a <canvas>, so Playwright/Selenium can't see widgets, but
# flutter drive runs against the widget tree).
#
# chromedriver is auto-provisioned to MATCH the installed Chrome version
# (ChromeDriver enforces a matching major version), downloading from Chrome for
# Testing if a matching one is not already on PATH. Works locally and in CI.
# Override with CHROMEDRIVER=/path/to/chromedriver to force a specific binary.
#
# Usage:
#   scripts/run_web_e2e.sh                       # uses .env.web.local (dev)
#   ENV_FILE=.env.web.prod.local scripts/run_web_e2e.sh
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-.env.web.local}"
DRIVER_PORT="${DRIVER_PORT:-4444}"
TARGET="${TARGET:-web_e2e/app_boot_test.dart}"
CACHE_DIR=".dart_tool/chromedriver"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: env file '$ENV_FILE' not found." >&2
  exit 1
fi

# --- resolve the Chrome-for-Testing platform slug -----------------------------
case "$(uname -s)" in
  Darwin) [ "$(uname -m)" = "arm64" ] && CFT_PLATFORM=mac-arm64 || CFT_PLATFORM=mac-x64 ;;
  Linux)  CFT_PLATFORM=linux64 ;;
  *) echo "ERROR: unsupported OS $(uname -s)" >&2; exit 1 ;;
esac

# --- detect installed Chrome version ------------------------------------------
detect_chrome_version() {
  local c
  for c in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing" \
    google-chrome google-chrome-stable chromium chromium-browser; do
    if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then
      "$c" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 && return 0
    fi
  done
  return 1
}
CHROME_VERSION="$(detect_chrome_version || true)"
CHROME_MAJOR="${CHROME_VERSION%%.*}"

major_of() { "$1" --version 2>/dev/null | grep -oE '[0-9]+' | head -1; }

# --- pick / provision a matching chromedriver ---------------------------------
CHROMEDRIVER="${CHROMEDRIVER:-}"
if [ -z "$CHROMEDRIVER" ] && command -v chromedriver >/dev/null 2>&1; then
  if [ -z "$CHROME_MAJOR" ] || [ "$(major_of chromedriver)" = "$CHROME_MAJOR" ]; then
    CHROMEDRIVER="$(command -v chromedriver)"
  fi
fi

if [ -z "$CHROMEDRIVER" ]; then
  if [ -z "$CHROME_VERSION" ]; then
    echo "ERROR: could not detect Chrome, and no matching chromedriver on PATH." >&2
    echo "Install Chrome, or set CHROMEDRIVER=/path/to/chromedriver." >&2
    exit 1
  fi
  echo "Provisioning chromedriver to match Chrome $CHROME_VERSION ($CFT_PLATFORM)..."
  URL="$(curl -s 'https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json' \
    | CFT_PLATFORM="$CFT_PLATFORM" CHROME_MAJOR="$CHROME_MAJOR" CHROME_VERSION="$CHROME_VERSION" python3 -c '
import sys, os, json
d = json.load(sys.stdin)
plat, major, full = os.environ["CFT_PLATFORM"], os.environ["CHROME_MAJOR"], os.environ["CHROME_VERSION"]
def url(v):
    for dl in v.get("downloads", {}).get("chromedriver", []):
        if dl["platform"] == plat:
            return dl["url"]
    return None
# prefer exact version, else highest build within the same major
exact = [v for v in d["versions"] if v["version"] == full and url(v)]
same  = [v for v in d["versions"] if v["version"].split(".")[0] == major and url(v)]
same.sort(key=lambda v: [int(x) for x in v["version"].split(".")])
pick = (exact or same[-1:] or [None])[0]
print(url(pick) if pick else "")
')"
  if [ -z "$URL" ]; then
    echo "ERROR: no Chrome-for-Testing chromedriver found for Chrome major $CHROME_MAJOR / $CFT_PLATFORM." >&2
    exit 1
  fi
  DEST="$CACHE_DIR/$CHROME_MAJOR"
  mkdir -p "$DEST"
  if [ ! -x "$DEST/chromedriver" ]; then
    curl -sL -o "$DEST/cd.zip" "$URL"
    (cd "$DEST" && unzip -oq cd.zip && cp chromedriver-*/chromedriver ./chromedriver && chmod +x chromedriver)
    xattr -cr "$DEST/chromedriver" 2>/dev/null || true
  fi
  CHROMEDRIVER="$DEST/chromedriver"
fi

echo "Using chromedriver: $CHROMEDRIVER ($("$CHROMEDRIVER" --version 2>&1 | head -1))"

echo "Starting chromedriver on :$DRIVER_PORT ..."
"$CHROMEDRIVER" --port="$DRIVER_PORT" >/tmp/chromedriver_web_e2e.log 2>&1 &
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
