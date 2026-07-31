#!/usr/bin/env bash
# Run Mealvana Endurance with the dev flavor + dev entry point.
#
# Why this script exists:
#   `flutter run --flavor dev` alone uses the iOS dev xcconfig (dev bundle ID,
#   "Endurance Dev" display name) BUT defaults to lib/main.dart, which loads
#   .env.prod.local — so analytics events end up in the PRODUCTION Mixpanel
#   project even though the bundle says "dev". Passing --target lib/main_dev.dart
#   forces the dev entry point, which loads .env.dev.local (dev Mixpanel token,
#   dev Sentry env, etc.). VSCode's launch.json already wires this correctly;
#   this script gives the terminal the same treatment.
#
# Usage:
#   ./scripts/run_dev.sh                  # interactive device picker
#   ./scripts/run_dev.sh -d "iPhone 17"   # pin to a specific device
#   ./scripts/run_dev.sh -d all           # all attached devices
set -euo pipefail

cd "$(dirname "$0")/.."

exec flutter run \
  --flavor dev \
  --target lib/main_dev.dart \
  --dart-define=IS_INTERNAL=true \
  "$@"
