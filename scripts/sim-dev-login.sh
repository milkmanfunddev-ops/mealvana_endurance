#!/usr/bin/env bash
#
# sim-dev-login.sh — sign the Mealvana Endurance **dev** app into the booted iOS
# simulator, using credentials stored in the macOS Keychain.
#
# ─── SECURITY MODEL ──────────────────────────────────────────────────────────
#   • The password lives ONLY in the login Keychain, under service
#     "mealvana-dev-login". You created it once (step 1) with:
#         security add-generic-password -U -s mealvana-dev-login -a <email> -w
#     (the -w with no value prompts you hidden — nothing echoed, no shell history).
#   • This script reads it and feeds it straight to the simulator. The password is
#     never printed, echoed, written to disk, or committed — it never reaches the
#     Claude chat transcript or git.
#   • Minor local caveat: idb types the password via a subprocess argument, so the
#     value is briefly visible to local `ps` on THIS machine. Use a DEDICATED
#     test / coach-demo account (not your personal login) so the blast radius is nil.
#
# ─── HOW TO RUN ──────────────────────────────────────────────────────────────
#   You:    ! scripts/sim-dev-login.sh            (user-initiated — no prompt)
#   Claude: needs a permission rule → Bash(scripts/sim-dev-login.sh:*)
#           (Claude Code's classifier blocks unauthorized Keychain reads by default.)
#
#   scripts/sim-dev-login.sh [UDID]   # defaults to the currently booted simulator
#
set -euo pipefail

SERVICE="mealvana-dev-login"
BUNDLE="com.milkman.mealvanaendurance.dev"

UDID="${1:-$(xcrun simctl list devices booted | grep -Eo '[0-9A-Fa-f]{8}-[0-9A-Fa-f-]{27}' | head -n1)}"
[ -n "${UDID:-}" ] || { echo "✗ No booted simulator found. Boot one and retry."; exit 1; }
export IDB_UDID="$UDID"

# Email is the Keychain account label (not secret) — read the metadata, not -w.
# The trailing `|| true` matters: when the Keychain item is missing, `security`
# exits 44, and under `set -euo pipefail` a failing pipeline inside an
# assignment's command substitution kills the script BEFORE the friendly
# error below can print. Swallow the status here; the [ -n ] guard is the
# real check.
EMAIL="$(security find-generic-password -s "$SERVICE" 2>/dev/null \
          | sed -n 's/.*"acct"<blob>="\(.*\)"$/\1/p' || true)"
[ -n "${EMAIL:-}" ] || {
  echo "✗ No Keychain entry '$SERVICE'. Create it first (see the header of this"
  echo "  script — SECURITY MODEL, step 1):"
  echo "    security add-generic-password -U -s $SERVICE -a <your-dev-email> -w"
  echo "  (-w with no value prompts for the password hidden — nothing echoed.)"
  exit 1
}

describe() { idb ui describe-all --json 2>/dev/null; }

# Print "x y" center of the first element whose AXLabel contains $1 (case-insensitive),
# optionally constrained to type $2 (e.g. TextField, Button). Empty if not found.
find_xy() {
  describe | python3 -c '
import sys, json
sub = sys.argv[1].lower()
typ = sys.argv[2] if len(sys.argv) > 2 else ""
try:
    els = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for e in els:
    lab = (e.get("AXLabel") or "")
    if sub in lab.lower() and (not typ or e.get("type") == typ):
        f = e["frame"]
        print(int(f["x"] + f["width"] / 2), int(f["y"] + f["height"] / 2))
        break
' "$1" "${2:-}"
}

present() { [ -n "$(find_xy "$1" "${2:-}")" ]; }
tap()     { local xy; xy="$(find_xy "$1" "${2:-}")"; [ -n "$xy" ] || return 1; idb ui tap $xy; sleep 0.6; }

# Bring the app to the foreground (idempotent) and let the splash settle.
xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
sleep 3

# If we're already past auth, there's nothing to do.
if ! present "Get Started" && ! present "Log In" Button && ! present "Email Address" TextField; then
  echo "✓ App appears already signed in (no login screen present). Nothing to do."
  exit 0
fi

# Walk Welcome → Log In → Log in with Email, only as far as needed.
if ! present "Email Address" TextField; then
  if present "Log In" Button && ! present "Log in with Email" Button; then
    tap "Log In" Button                      # Welcome screen → login landing
  fi
  present "Log in with Email" Button && tap "Log in with Email" Button
fi

present "Email Address" TextField || { echo "✗ Could not reach the email login form."; exit 1; }

echo "→ Signing in as $EMAIL on $UDID …"
tap "Email Address" TextField
idb ui text "$EMAIL"

tap "Password" TextField
# Password read + typed here, in one pipeline-free step; value never stored or printed.
idb ui text "$(security find-generic-password -s "$SERVICE" -w)"

tap "Log In" Button
echo "✓ Login submitted. Give it a moment, then verify the app is on the home screen."
