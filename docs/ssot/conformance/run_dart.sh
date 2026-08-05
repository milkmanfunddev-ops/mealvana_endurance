#!/usr/bin/env bash
# QA conformance runner (layer 1: engine vs spec).
#
#   ./run_dart.sh pre-workout-hydration
#   ./run_dart.sh pre-workout-carbs
#   ./run_dart.sh pre-workout-sodium
#   ./run_dart.sh                        # defaults to pre-workout-carbs
#
# Copies the conformance test into the app package (flutter test needs it inside the
# package for `package:` imports), runs it against the REAL OfflineMacroCalculator with
# the golden vectors, then cleans up. Read-only on the app except the ephemeral temp test
# file, which is always removed — including on failure or Ctrl-C.
#
# Layout (this repo): the QA root is `docs/ssot/` — this script's parent — and the app is
# the Flutter package at the repo root. Both are resolved from the script's own location;
# override with QA_ROOT= / APP_ROOT= if you relocate either.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# QA root = docs/ssot (parent of conformance/)
QA_ROOT="${QA_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# App root = nearest ancestor holding a pubspec.yaml (the Flutter package = repo root).
find_app_root() {
  local d="$1"
  while [ "$d" != "/" ]; do
    [ -f "$d/pubspec.yaml" ] && { echo "$d"; return; }
    d="$(dirname "$d")"
  done
}
APP_ROOT="${APP_ROOT:-$(find_app_root "$SCRIPT_DIR")}"
[ -n "${APP_ROOT:-}" ] || { echo "ABORT: no pubspec.yaml found above $SCRIPT_DIR (set APP_ROOT=)"; exit 1; }

# Slice to run. Dashes in the slice name map to underscores for the test filename:
#   pre-workout-carbs -> pre_workout_carbs_conformance_test.dart
SLICE="${1:-pre-workout-carbs}"
UNDER="${SLICE//-/_}"
VECTORS="$QA_ROOT/vectors/fueling/$SLICE.json"
TEST_SRC="$QA_ROOT/conformance/${UNDER}_conformance_test.dart"
DEST="$APP_ROOT/test/_qa_conformance_${UNDER}_tmp_test.dart"

[ -d "$APP_ROOT" ]  || { echo "ABORT: app not found: $APP_ROOT"; exit 1; }
[ -f "$VECTORS" ]   || { echo "ABORT: vectors missing: $VECTORS"; exit 1; }
[ -f "$TEST_SRC" ]  || { echo "ABORT: test missing: $TEST_SRC"; exit 1; }

cleanup() { rm -f "$DEST"; }
trap cleanup EXIT INT TERM

cp "$TEST_SRC" "$DEST"
echo "== QA conformance: $SLICE vs the real OfflineMacroCalculator =="
echo "   qa:      $QA_ROOT"
echo "   app:     $APP_ROOT"
echo "   vectors: $VECTORS"
echo "   harness: $TEST_SRC"
cd "$APP_ROOT"
flutter test "${DEST#"$APP_ROOT/"}" --dart-define=QA_VECTORS="$VECTORS"
