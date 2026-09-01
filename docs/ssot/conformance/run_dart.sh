#!/usr/bin/env bash
# QA conformance runner — pre-workout carbs (layer 1: engine vs spec).
# Resolves app + qa via the workspace registry, copies the conformance test into the app
# package (flutter test needs it inside the package for package: imports), runs it against
# the REAL OfflineMacroCalculator with the golden vectors, then cleans up. Read-only on app
# except the ephemeral temp test file, which is always removed.
set -euo pipefail

find_workspace() { local d="$1"; while [ "$d" != "/" ]; do
  [ -f "$d/workspace.env" ] && { echo "$d"; return; }; d="$(dirname "$d")"; done; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MV_ROOT="$(find_workspace "$SCRIPT_DIR")"
[ -n "$MV_ROOT" ] || { echo "ABORT: workspace.env not found above $SCRIPT_DIR"; exit 1; }
# shellcheck disable=SC1091
source "$MV_ROOT/workspace.env"

# Slice to run (default the carbs pilot). Dashes in the slice name map to underscores
# for the test filename: pre-workout-carbs -> pre_workout_carbs_conformance_test.dart
SLICE="${1:-pre-workout-carbs}"
UNDER="${SLICE//-/_}"
VECTORS="$QA_ROOT/vectors/fueling/$SLICE.json"
TEST_SRC="$QA_ROOT/conformance/${UNDER}_conformance_test.dart"
DEST="$APP_ROOT/test/_qa_conformance_tmp_test.dart"

[ -f "$VECTORS" ]  || { echo "ABORT: vectors missing: $VECTORS"; exit 1; }
[ -f "$TEST_SRC" ] || { echo "ABORT: test missing: $TEST_SRC"; exit 1; }
[ -d "$APP_ROOT" ] || { echo "ABORT: app not found: $APP_ROOT"; exit 1; }

cleanup() { rm -f "$DEST"; }
trap cleanup EXIT

cp "$TEST_SRC" "$DEST"
echo "== QA conformance: $SLICE vs real OfflineMacroCalculator =="
echo "   app:     $APP_ROOT"
echo "   vectors: $VECTORS"
cd "$APP_ROOT"
flutter test "test/_qa_conformance_tmp_test.dart" --dart-define=QA_VECTORS="$VECTORS"
