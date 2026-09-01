#!/usr/bin/env bash
# sim-ensure.sh — make sure the QA iOS simulator is booted and the dev app is running.
# Prints the booted device UDID on the last line. Safe to re-run (idempotent).
#
#   qa/scripts/sim-ensure.sh ["iPhone 17"]
#
# No credentials involved — just boot + launch. Claude may run this.
set -euo pipefail

DEVICE_NAME="${1:-iPhone 17}"
BUNDLE="com.milkman.mealvanaendurance.dev"

# Prefer an already-booted device; else resolve the named one.
UDID="$(xcrun simctl list devices booted -j 2>/dev/null \
        | python3 -c 'import sys,json;d=json.load(sys.stdin);u=[x["udid"] for v in d["devices"].values() for x in v if x["state"]=="Booted"];print(u[0] if u else "")')"

if [ -z "$UDID" ]; then
  UDID="$(xcrun simctl list devices -j \
          | python3 -c "import sys,json;n='$DEVICE_NAME';d=json.load(sys.stdin);u=[x['udid'] for v in d['devices'].values() for x in v if x['name']==n];print(u[0] if u else '')")"
  [ -n "$UDID" ] || { echo "✗ no simulator named '$DEVICE_NAME' and none booted"; exit 1; }
  echo "→ booting $DEVICE_NAME ($UDID) …"
  xcrun simctl boot "$UDID"
  open -a Simulator || true
  # wait for boot to finish
  xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || sleep 8
fi

echo "→ launching $BUNDLE on $UDID"
xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null 2>&1 || true

# Best-effort staleness check: warn when the installed bundle predates app HEAD.
# (Can NOT detect a leftover integration-test build — same bundle id, so the caller
# must still verify via screenshot that the real app UI renders. See qa-smoke SKILL.md.)
find_workspace() { local d="$1"; while [ "$d" != "/" ]; do
  [ -f "$d/workspace.env" ] && { echo "$d"; return; }; d="$(dirname "$d")"; done; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MV_ROOT="$(find_workspace "$SCRIPT_DIR")"
if [ -n "$MV_ROOT" ]; then
  # shellcheck disable=SC1091
  source "$MV_ROOT/workspace.env" 2>/dev/null || true
  APP_PATH="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" app 2>/dev/null || true)"
  if [ -n "${APP_ROOT:-}" ] && [ -n "$APP_PATH" ] && [ -d "$APP_ROOT/.git" ]; then
    INSTALLED_EPOCH="$(stat -f %m "$APP_PATH/Runner" 2>/dev/null || stat -f %m "$APP_PATH" 2>/dev/null || echo 0)"
    HEAD_EPOCH="$(git -C "$APP_ROOT" log -1 --format=%ct 2>/dev/null || echo 0)"
    if [ "$INSTALLED_EPOCH" -gt 0 ] && [ "$HEAD_EPOCH" -gt 0 ] && [ "$INSTALLED_EPOCH" -lt "$HEAD_EPOCH" ]; then
      echo "⚠ installed app ($(date -r "$INSTALLED_EPOCH" '+%Y-%m-%d %H:%M')) is OLDER than app HEAD" \
           "($(git -C "$APP_ROOT" log -1 --format='%h %cd' --date=format:'%Y-%m-%d %H:%M')) —" \
           "rebuild with \$APP_ROOT/scripts/run_dev.sh -d $UDID for the latest dev version"
    fi
  fi
fi

echo "✓ simulator ready"
echo "$UDID"
