#!/usr/bin/env bash
# Meal-planning SSOT conformance — DART arm. Copies dart_vectors_test.dart into <app>/test/ and runs it
# with flutter test against the REAL Flutter twin (PlanCoverageService, CookingStepTimers, MealIconClassifier).
# Read-only on the app except the ephemeral temp test file, always removed. Exit code is the gate.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
find_workspace() { local d="$1"; while [ "$d" != "/" ]; do [ -f "$d/workspace.env" ] && { echo "$d"; return; }; d="$(dirname "$d")"; done; }
MV_ROOT="$(find_workspace "$SCRIPT_DIR")"; [ -n "$MV_ROOT" ] || { echo "ABORT: workspace.env not found above $SCRIPT_DIR"; exit 1; }
# shellcheck disable=SC1091
source "$MV_ROOT/workspace.env"
[ -d "$APP_ROOT" ] || { echo "ABORT: app not found: $APP_ROOT"; exit 1; }
VECTORS="$SCRIPT_DIR/../vectors"
DEST="$APP_ROOT/test/_ssot_mealplanning_tmp_test.dart"
echo "== meal-planning SSOT conformance: dart arm =="; echo "   app:     $APP_ROOT"; echo "   vectors: $VECTORS"
cp "$SCRIPT_DIR/dart_vectors_test.dart" "$DEST"
trap 'rm -f "$DEST"' EXIT
cd "$APP_ROOT"
flutter test test/_ssot_mealplanning_tmp_test.dart --dart-define=SSOT_VECTORS="$VECTORS" "$@"
