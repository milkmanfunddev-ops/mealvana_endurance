#!/usr/bin/env bash
# qa-login.sh <athlete-name-or-email> — switch the sim dev-login to a seeded QA athlete.
#
#   YOU run this (it authenticates):   ! qa-login.sh priya
#
# All 20 seeded athletes share the same test password (Avery's INTEGRATION_TEST_PASSWORD),
# differing only by email. This points the Keychain entry `mealvana-dev-login` at
# <name>@test.com with that shared password, then runs the app's sim-dev-login.sh to
# type it into the simulator.
#
# The password is read from the gitignored app/secrets/integration_test.env and is NEVER
# printed. (Same brief `ps`-visibility caveat as sim-dev-login.sh — fine for a dedicated
# dev-only account.) Requires: a booted simulator with the app ON ITS LOGIN SCREEN
# (log out the current account first), and idb installed.
set -euo pipefail

NAME="${1:?usage: qa-login.sh <athlete-name-or-email>   e.g.  qa-login.sh priya}"
case "$NAME" in
  *@*) EMAIL="$NAME" ;;
  *)   EMAIL="$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]')@test.com" ;;
esac

# Resolve app repo via the workspace registry.
find_workspace() { local d="$1"; while [ "$d" != "/" ]; do
  [ -f "$d/workspace.env" ] && { echo "$d"; return; }; d="$(dirname "$d")"; done; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MV_ROOT="$(find_workspace "$SCRIPT_DIR")"
[ -n "$MV_ROOT" ] || { echo "✗ workspace.env not found above $SCRIPT_DIR"; exit 1; }
# shellcheck disable=SC1091
source "$MV_ROOT/workspace.env"

ENVFILE="$APP_ROOT/secrets/integration_test.env"
LOGIN="$APP_ROOT/scripts/sim-dev-login.sh"
[ -f "$ENVFILE" ] || { echo "✗ missing $ENVFILE"; exit 1; }
[ -x "$LOGIN" ] || { echo "✗ missing/none-exec $LOGIN"; exit 1; }

PW="$(grep -E '^INTEGRATION_TEST_PASSWORD=' "$ENVFILE" | head -1 | cut -d= -f2- | tr -d '"'\''' )"
[ -n "$PW" ] || { echo "✗ INTEGRATION_TEST_PASSWORD not set in $ENVFILE"; exit 1; }

# Friendly guardrail: warn if this email isn't one of the seeded athletes.
if [ -f "$MV_ROOT/qa/profiles/athletes.json" ] && ! grep -q "\"$EMAIL\"" "$MV_ROOT/qa/profiles/athletes.json"; then
  echo "⚠ $EMAIL is not in qa/profiles/athletes.json — continuing anyway."
fi

echo "→ pointing dev-login Keychain at $EMAIL"
# The Keychain keys generic passwords on service+account, so `-U` with a new email would
# ADD a second entry rather than replace — and sim-dev-login.sh looks up by service only,
# so it could then read the wrong account. Delete every mealvana-dev-login entry first,
# then add exactly one. (NOTE: this replaces whatever single dev-login entry was there.)
while security delete-generic-password -s mealvana-dev-login >/dev/null 2>&1; do :; done
security add-generic-password -s mealvana-dev-login -a "$EMAIL" -w "$PW"

echo "→ signing the simulator in as $EMAIL …"
exec "$LOGIN"
