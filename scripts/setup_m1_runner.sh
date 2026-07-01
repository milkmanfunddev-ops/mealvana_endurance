#!/usr/bin/env bash
#
# One-shot bootstrap for the Mac mini M1 as a GitHub Actions self-hosted runner
# that runs the Mealvana test suites (see .github/workflows/tests-selfhosted.yml).
#
# RUN THIS ON THE M1 (not the MacBook). Idempotent-ish; safe to re-run.
#
# Prereqs on the M1: macOS, internet, an admin user. You need a short-lived
# runner registration token (valid ~1h). Get one from the MacBook (which has gh
# admin) with:
#   gh api -X POST /repos/milkmanfunddev-ops/mealvana_endurance/actions/runners/registration-token --jq .token
#
# Usage (on the M1):
#   RUNNER_TOKEN=<token> bash setup_m1_runner.sh
#
# Covers the device-less job (unit + web e2e + Deno). iOS/Android Patrol needs
# Xcode + Android SDK/emulator installed separately (see NOTES at the bottom).
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/milkmanfunddev-ops/mealvana_endurance}"
RUNNER_LABELS="${RUNNER_LABELS:-mealvana-m1}"   # self-hosted/macOS/ARM64 are auto-added
RUNNER_DIR="${RUNNER_DIR:-$HOME/actions-runner}"
RUNNER_NAME="${RUNNER_NAME:-$(scutil --get LocalHostName 2>/dev/null || hostname -s)}"
RUNNER_TOKEN="${RUNNER_TOKEN:-${1:-}}"
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

[ "$(uname -s)" = "Darwin" ] || { echo "This must run on macOS (the M1)."; exit 1; }
[ -n "$RUNNER_TOKEN" ] || { echo "ERROR: RUNNER_TOKEN is required (see header)."; exit 1; }

# --- 1. Homebrew --------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"

# --- 2. Toolchain -------------------------------------------------------------
log "Installing toolchain (git, deno, chrome, cocoapods, unzip)"
brew install git deno cocoapods >/dev/null || true
brew install --cask google-chrome >/dev/null 2>&1 || true   # web e2e drives real Chrome

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  log "Installing Flutter (stable) into $FLUTTER_DIR"
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"
flutter --version | head -1
flutter precache >/dev/null 2>&1 || true

# --- 3. Download + configure the GitHub Actions runner ------------------------
mkdir -p "$RUNNER_DIR"; cd "$RUNNER_DIR"
if [ ! -x ./run.sh ]; then
  log "Downloading the latest GitHub Actions runner (osx-arm64)"
  URL=$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest \
        | grep -oE 'https://[^"]*osx-arm64-[0-9.]+\.tar\.gz' | head -1)
  curl -fsSL -o runner.tar.gz "$URL"
  tar xzf runner.tar.gz && rm -f runner.tar.gz
fi

# PATH the launchd service will see (it does NOT source your shell profile).
{
  echo "$FLUTTER_DIR/bin"
  echo "$HOME/.pub-cache/bin"
  echo "$(brew --prefix)/bin"
  echo "/usr/bin"; echo "/bin"; echo "/usr/sbin"; echo "/sbin"
} > "$RUNNER_DIR/.path"

log "Registering runner '$RUNNER_NAME' with $REPO_URL"
./config.sh --unattended --replace \
  --url "$REPO_URL" \
  --token "$RUNNER_TOKEN" \
  --name "$RUNNER_NAME" \
  --labels "$RUNNER_LABELS" \
  --work _work

# --- 4. Install as a launchd service (auto-start, survives reboot) ------------
log "Installing + starting the runner service"
./svc.sh install || true
./svc.sh start
./svc.sh status || true

log "DONE. The runner should now show as 'Idle' at:"
echo "  $REPO_URL/settings/actions/runners"
echo
echo "It will pick up the 'unit-web-deno' job in tests-selfhosted.yml on the next PR/push."
cat <<'NOTES'

--- NOTES: enabling the iOS/Android (Patrol) job later ---
The device-less job works with the above. For the Patrol job you additionally need:
  * Xcode (from the App Store or `xcodes`), then: sudo xcodebuild -license accept
      and `xcrun simctl list runtimes` should show an iOS runtime.
  * CocoaPods (installed above).
  * Android: `brew install --cask android-commandlinetools temurin`, then
      sdkmanager platform-tools + an emulator system image, and create an AVD.
Then set `if: false` -> `if: true` on the integration-patrol job.
NOTES
