#!/usr/bin/env bash
# probe-live.sh — keychain wrapper for probe-live.mjs (same security model as
# app/scripts/sim-dev-login.sh: the password lives ONLY in the login keychain
# under service "mealvana-dev-login"; it is read here and passed via env,
# never printed or written to disk).
#
#   qa/scripts/probe-live.sh [--read-only]
set -euo pipefail
SERVICE="mealvana-dev-login"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMAIL="$(security find-generic-password -s "$SERVICE" 2>/dev/null | sed -n 's/.*"acct"<blob>="\(.*\)"/\1/p' || true)"
PW="$(security find-generic-password -s "$SERVICE" -w 2>/dev/null || true)"
if [[ -z "$EMAIL" || -z "$PW" ]]; then
  echo "warn: keychain item '$SERVICE' missing — running read-only checks" >&2
  exec node "$SCRIPT_DIR/probe-live.mjs" --read-only "$@"
fi
PROBE_EMAIL="$EMAIL" PROBE_PASSWORD="$PW" exec node "$SCRIPT_DIR/probe-live.mjs" "$@"
