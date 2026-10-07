#!/usr/bin/env bash
# Empty the dev app's data on one wave simulator, keeping the installed build (IMPROVEMENTS #31).
# A wave simulator is a copy of the dev simulator, so it carries Lee's signed-in session, his
# Drift database and leftover onboarding answers. The wave lead runs this on each copy before
# spawning, unless the ticket tests that leftover data. The app opens signed out on Welcome.
#
# Usage: scripts/testing-wave/clear-app.sh <udid>
# Never run it on the dev simulator.
set -euo pipefail

udid="${1:?usage: clear-app.sh <udid>}"
bundle=com.milkman.mealvanaendurance.dev
name="$(xcrun simctl list devices | grep "$udid" | sed -E 's/^ *(.*) \([0-9A-F-]{36}\).*/\1/')"
case "$name" in
  wave-*) ;;
  *) echo "refusing: $udid is \"$name\", not a wave simulator" >&2; exit 2 ;;
esac

xcrun simctl terminate "$udid" "$bundle" 2>/dev/null || true
data="$(xcrun simctl get_app_container "$udid" "$bundle" data)"
for d in Documents Library tmp; do
  [ -d "$data/$d" ] && find "$data/$d" -mindepth 1 -delete
done
echo "cleared $bundle data on $name ($udid)"
