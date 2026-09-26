#!/usr/bin/env bash
# Offline or slow for one app on one wave simulator, without touching the Mac's network (IMPROVEMENTS #36, #92).
#
#   netcut.sh launch <udid> <scratch>   build the library into <scratch> if missing or older than
#                                       netcut.c, then relaunch the dev app with it injected (network on)
#   netcut.sh on <scratch>              cut: every non-loopback connect fails with ENETUNREACH, and
#                                       every socket the app already had open is shut down within
#                                       ~50 ms (111-004), so the first offline tap is offline too
#   netcut.sh on <scratch> --relaunch <udid>
#                                       cut, then relaunch the app with the cut in force (fallback)
#   netcut.sh slow <ms> <scratch> [--only <host>]... [--relaunch <udid>]
#                                       slow: the app's new TCP connects go through a host proxy
#                                       (slowproxy.mjs) that holds every reply chunk <ms>; it answers
#                                       late but succeeds. A connection open before `slow` stays fast,
#                                       so --relaunch when every request must be slow. Run it again
#                                       with another <ms> to change the delay (open proxied
#                                       connections take the new one at once). --only <host> holds
#                                       replies from that host alone (repeatable), e.g. --only
#                                       api.revenuecat.com to slow the entitlement read and not sign-in.
#   netcut.sh off <scratch>             restore (ends both on and slow); no relaunch needed
#
# Only the app launched here loads the library; other simulators and the host are untouched.
# Events go to <scratch>/netcut.log (blocked connects, sockets closed at a cut, slowed connects);
# the proxy logs each connection to <scratch>/slowproxy.log and exits 30 s after `off` once idle
# (its PID is in <scratch>/slowproxy.pid for runbook step 9). Limit: connectivity_plus still reads
# "online", so the app's own offline banner path needs a device (Finding 20-006).
#
# Proven on a wave simulator (iOS 26.2, dev build), 2026-09-26, ticket 142. Each trial: clear the
# app, `slow <ms> --only api.revenuecat.com --relaunch`, Log In as a non-admin lee+e2e-* account
# holding a seeded Pro grant. Times are from the app's console (RevenueCat's own request lines and
# GoRouter's, local time, UTC-5), so they are the app's, not the proxy's:
#   slow 3000: the gate's wait gave up at exactly 2.00 s (popping /welcome 08:03:11.778, going to
#     /main 08:03:13.782, redirected to /paywall 08:03:13.783); the paywall was on screen. RevenueCat's
#     identify took 3.14 s (08:03:16.963 -> 08:03:20.106), its push flipped the app to /main at
#     08:03:20.178. So: the read gives up, the fallback (locked) shows, then the late answer lands.
#   slow 500: identify took 0.59 s (08:02:35.879 -> 08:02:36.468); /main 0.21 s after popping
#     /welcome, no paywall.
#   Both native (RevenueCat SDK, URLSession) and Dart traffic go through the proxy; every host was
#     held when --only was left out, and sign-in then took over a minute (each reply +3 s).
#   An Admin (test@test.com) is let through when the read gives up (admin check), so a slow proof
#     of the gate needs a non-admin account.
#   on, then Redeem on the paywall 0.46 s later (lapsed lee+e2e-* account, code E2EEXPIRED): `on`
#     shut down 2 open sockets (Supabase auth host, RevenueCat), every connect after it was blocked
#     and logged, the sheet said "We couldn't redeem that code just now", and the dev edge logs held
#     no redeem-code request for that minute; the same tap online a few seconds later logged one.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
bundle=com.milkman.mealvanaendurance.dev

relaunch() {
  xcrun simctl terminate "$1" "$bundle" 2>/dev/null || true
  SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="$2/netcut.dylib" \
  SIMCTL_CHILD_NETCUT_FLAG="$2/offline.flag" \
  SIMCTL_CHILD_NETCUT_SLOW="$2/slow.flag" \
  SIMCTL_CHILD_NETCUT_MAP="$2/slow.map" \
  SIMCTL_CHILD_NETCUT_LOG="$2/netcut.log" \
    xcrun simctl launch "$1" "$bundle"
}

need_lib() {
  # Without the library the app was never launched through netcut, so a flag changes nothing (125-005).
  if [ ! -f "$1/netcut.dylib" ]; then
    echo "netcut.sh: no $1/netcut.dylib; run netcut.sh launch <udid> $1 first. Network unchanged." >&2; exit 1
  fi
}

proxy_alive() { [ -f "$1/slowproxy.pid" ] && kill -0 "$(cat "$1/slowproxy.pid")" 2>/dev/null; }

case "${1:-}" in
  launch)
    udid="${2:?usage: netcut.sh launch <udid> <scratch>}"; dir="${3:?scratch folder}"
    mkdir -p "$dir"; dir="$(cd "$dir" && pwd)"
    if [ ! -f "$dir/netcut.dylib" ] || [ "$here/netcut.c" -nt "$dir/netcut.dylib" ]; then
      xcrun -sdk iphonesimulator clang -dynamiclib -arch arm64 -o "$dir/netcut.dylib" "$here/netcut.c"
    fi
    rm -f "$dir/offline.flag" "$dir/slow.flag"
    relaunch "$udid" "$dir"
    echo "launched with netcut; network on. netcut.sh on|slow <ms> $dir to change it"
    ;;
  on)
    dir="${2:?scratch folder}"; need_lib "$dir"
    before=$(grep -c ' closed fd ' "$dir/netcut.log" 2>/dev/null || true)
    touch "$dir/offline.flag"; echo "offline since $(date -u +%H:%M:%SZ)"
    if [ "${3:-}" = "--relaunch" ]; then
      relaunch "${4:?usage: netcut.sh on <scratch> --relaunch <udid>}" "$(cd "$dir" && pwd)"
      echo "relaunched offline: no connection from before the cut is left open"
    else
      sleep 0.2   # the library's watcher looks every 50 ms
      after=$(grep -c ' closed fd ' "$dir/netcut.log" 2>/dev/null || true)
      echo "open sockets shut down: $(( ${after:-0} - ${before:-0} )) (netcut.log)"
    fi
    ;;
  slow)
    ms="${2:?usage: netcut.sh slow <ms> <scratch>}"; dir="${3:?scratch folder}"
    [[ "$ms" =~ ^[0-9]+$ ]] || { echo "netcut.sh: <ms> must be a whole number of milliseconds" >&2; exit 64; }
    need_lib "$dir"; dir="$(cd "$dir" && pwd)"
    if ! proxy_alive "$dir"; then
      rm -f "$dir/slowproxy.port"
      nohup node "$here/slowproxy.mjs" "$dir" >>"$dir/slowproxy.log" 2>&1 &
      echo $! > "$dir/slowproxy.pid"
      for _ in $(seq 50); do [ -s "$dir/slowproxy.port" ] && break; sleep 0.1; done
      [ -s "$dir/slowproxy.port" ] || { echo "netcut.sh: the slow proxy did not start (slowproxy.log)" >&2; exit 1; }
    fi
    shift 3; hosts=""; udid=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --only) hosts="$hosts ${2:?--only <host>}"; shift 2 ;;
        --relaunch) udid="${2:?--relaunch <udid>}"; shift 2 ;;
        *) echo "netcut.sh: unknown option $1" >&2; exit 64 ;;
      esac
    done
    echo "$ms $(cat "$dir/slowproxy.port")$hosts" > "$dir/slow.flag"
    echo "slow ($ms ms per reply${hosts:+ from$hosts only}) since $(date -u +%H:%M:%SZ): new connects go through the proxy"
    if [ -n "$udid" ]; then
      relaunch "$udid" "$dir"
      echo "relaunched slow: every connection the app opens goes through the proxy"
    fi
    ;;
  off)
    dir="${2:?scratch folder}"; rm -f "$dir/offline.flag" "$dir/slow.flag"
    echo "online since $(date -u +%H:%M:%SZ)"
    ;;
  *) sed -n '2,26p' "$0"; exit 2 ;;
esac
