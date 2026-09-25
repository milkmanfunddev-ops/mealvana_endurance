#!/usr/bin/env bash
# Offline for one app on one wave simulator, without touching the Mac's network (IMPROVEMENTS #36).
#
#   netcut.sh launch <udid> <scratch>   build the library into <scratch> if missing, then relaunch
#                                       the dev app with it injected (network stays on)
#   netcut.sh on <scratch>              cut: every non-loopback connect fails with ENETUNREACH
#   netcut.sh on <scratch> --relaunch <udid>
#                                       cut, then relaunch the app so no connection opened before the
#                                       cut survives it (a plain `on` blocks only new connects, #74)
#   netcut.sh off <scratch>             restore; no relaunch needed
#
# Only the app launched here loads the library; other simulators and the host are untouched.
# Blocked connects are logged to <scratch>/netcut.log. Limit: connectivity_plus still reads
# "online", so the app's own offline banner path needs a device (Finding 20-006).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
bundle=com.milkman.mealvanaendurance.dev

relaunch() {
  xcrun simctl terminate "$1" "$bundle" 2>/dev/null || true
  SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="$2/netcut.dylib" \
  SIMCTL_CHILD_NETCUT_FLAG="$2/offline.flag" \
  SIMCTL_CHILD_NETCUT_LOG="$2/netcut.log" \
    xcrun simctl launch "$1" "$bundle"
}

case "${1:-}" in
  launch)
    udid="${2:?usage: netcut.sh launch <udid> <scratch>}"; dir="${3:?scratch folder}"
    mkdir -p "$dir"; dir="$(cd "$dir" && pwd)"
    if [ ! -f "$dir/netcut.dylib" ]; then
      xcrun -sdk iphonesimulator clang -dynamiclib -arch arm64 -o "$dir/netcut.dylib" "$here/netcut.c"
    fi
    rm -f "$dir/offline.flag"
    relaunch "$udid" "$dir"
    echo "launched with netcut; network on. netcut.sh on $dir to cut it"
    ;;
  on)
    dir="${2:?scratch folder}"; touch "$dir/offline.flag"; echo "offline since $(date -u +%H:%M:%SZ)"
    if [ "${3:-}" = "--relaunch" ]; then
      relaunch "${4:?usage: netcut.sh on <scratch> --relaunch <udid>}" "$(cd "$dir" && pwd)"
      echo "relaunched offline: no connection from before the cut is left open"
    fi
    ;;
  off) dir="${2:?scratch folder}"; rm -f "$dir/offline.flag"; echo "online since $(date -u +%H:%M:%SZ)" ;;
  *) sed -n '2,15p' "$0"; exit 2 ;;
esac
