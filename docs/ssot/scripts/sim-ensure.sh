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
echo "✓ simulator ready"
echo "$UDID"
