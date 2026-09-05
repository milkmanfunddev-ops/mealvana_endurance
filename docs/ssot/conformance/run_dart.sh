#!/usr/bin/env bash
# QA conformance runner — one slice per invocation, resolved from the bundle manifests.
#
#   ./conformance/run_dart.sh <slice>
#
# The slice is looked up in bundles/*.yaml (`- { slice: <name>, ..., vectors: <path>, ... }`);
# the `vectors:` path decides HOW it runs. Every arm runs locally and deterministically against
# the app checkout resolved through workspace.env — no network, no cloud. Exit code is the gate.
#
#   vectors/fueling/<slice>.json          → the pre-workout Dart harness: copies
#                                           conformance/<slice>_conformance_test.dart into the
#                                           app package (package: imports) and runs it against the
#                                           REAL OfflineMacroCalculator with the golden vectors.
#   vectors/daily-macros/<x>.json         → the app's Deno vectors runner over the SAME vector file
#                                           (the app keeps a verbatim mirror under docs/ssot; this
#                                           script first proves mirror == qa, byte for byte, then
#                                           runs `deno test --filter "vectors: <x>"`).
#   vectors/daily-macros/intraday-display → the display-consumer Dart suite (24 vectors).
#   conformance/design/<manifest>.yaml    → the design conformance suites in the app repo
#                                           (goldens + gesture tests), after proving the manifest
#                                           mirror is byte-identical.
#
# Adding a bundle = adding a row here (or reusing one), never editing land-bundle.
# Read-only on app except the ephemeral fueling temp test file, which is always removed.
set -euo pipefail

find_workspace() { local d="$1"; while [ "$d" != "/" ]; do
  [ -f "$d/workspace.env" ] && { echo "$d"; return; }; d="$(dirname "$d")"; done; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MV_ROOT="$(find_workspace "$SCRIPT_DIR")"
[ -n "$MV_ROOT" ] || { echo "ABORT: workspace.env not found above $SCRIPT_DIR"; exit 1; }
# shellcheck disable=SC1091
source "$MV_ROOT/workspace.env"

SLICE="${1:-pre-workout-carbs}"
[ -d "$APP_ROOT" ] || { echo "ABORT: app not found: $APP_ROOT"; exit 1; }

# ---- resolve the slice's `vectors:` path from the manifests ---------------------------------
# Two manifest styles exist: single-line flow mappings (`- { slice: X, ..., vectors: P, ... }`,
# daily-macros era) and block mappings (`- slice: X` / indented `vectors: P`, brick-transition
# era). Take the LAST match so a superseding manifest wins if a slice name is reused. No yq
# dependency. A design slice's `vectors:` is prose starting "none" — resolve it to its
# conformance/design/<slice>.yaml manifest instead.
VEC_PATH="$(grep -h -E "^\s*-\s*\{\s*slice:\s*${SLICE}\s*," "$QA_ROOT"/bundles/*.yaml 2>/dev/null \
  | grep -E 'vectors:' \
  | sed -E 's/.*vectors:[[:space:]]*([^,[:space:]]+).*/\1/' | tail -1 || true)"
if [ -z "$VEC_PATH" ]; then
  VEC_PATH="$(awk -v slice="$SLICE" '
    /^[[:space:]]*-[[:space:]]*slice:[[:space:]]*/ {
      cur = $0; sub(/^[[:space:]]*-[[:space:]]*slice:[[:space:]]*/, "", cur);
      sub(/[[:space:]]*(#.*)?$/, "", cur); inslice = (cur == slice); next
    }
    inslice && /^[[:space:]]*vectors:[[:space:]]*/ {
      v = $0; sub(/^[[:space:]]*vectors:[[:space:]]*/, "", v);
      sub(/[[:space:]]*#.*$/, "", v); sub(/[[:space:]].*$/, "", v);
      print v; inslice = 0
    }
  ' "$QA_ROOT"/bundles/*.yaml 2>/dev/null | tail -1 || true)"
fi
case "$VEC_PATH" in
  none*|"")
    if [ -f "$QA_ROOT/conformance/design/$SLICE.yaml" ]; then
      VEC_PATH="conformance/design/$SLICE.yaml"
    elif [ -z "$VEC_PATH" ]; then
      # Not in any manifest — fall back to the legacy fueling layout so the pilot keeps working.
      VEC_PATH="vectors/fueling/$SLICE.json"
    fi
    ;;
esac

# ---- mirror check: the app's docs/ssot copy must be byte-identical to qa's ratified artifact ----
require_mirror() {
  local rel="$1"                       # qa-relative path
  local mirror="$APP_ROOT/docs/ssot/$rel"
  [ -f "$QA_ROOT/$rel" ] || { echo "ABORT: qa artifact missing: $rel"; exit 1; }
  [ -f "$mirror" ]       || { echo "ABORT: app mirror missing: docs/ssot/$rel (re-sync docs/ssot)"; exit 1; }
  if ! cmp -s "$QA_ROOT/$rel" "$mirror"; then
    echo "ABORT: app mirror of $rel differs from qa — the contract the app was tested against is"
    echo "       not the ratified one. Re-sync docs/ssot (never edit either side to make this pass)."
    exit 1
  fi
  echo "   mirror:  docs/ssot/$rel == qa (byte-identical)"
}

echo "== QA conformance: $SLICE =="
echo "   app:     $APP_ROOT"
echo "   vectors: $VEC_PATH"

# ---- food-recommendation: the two-engine twin arm (§8) --------------------
# The selection contract binds the TS engine and its Dart mirror; the slice is
# green only when BOTH engines pass every vector AND their canonical
# selection-result outputs are byte-equal (bundle done_when). Three steps:
# the Dart copy-in harness, the Deno runner, then cmp.
if [ "$SLICE" = "food-recommendation" ]; then
  VECTORS="$QA_ROOT/$VEC_PATH"
  TEST_SRC="$QA_ROOT/conformance/food_recommendation_conformance_test.dart"
  DEST="$APP_ROOT/test/_qa_conformance_tmp_test.dart"
  DIFF_DIR="$APP_ROOT/build"
  DART_OUT="$DIFF_DIR/qa_food_recommendation_dart.out"
  TS_OUT="$DIFF_DIR/qa_food_recommendation_ts.out"
  [ -f "$VECTORS" ]  || { echo "ABORT: vectors missing: $VECTORS"; exit 1; }
  [ -f "$TEST_SRC" ] || { echo "ABORT: test missing: $TEST_SRC"; exit 1; }
  command -v deno >/dev/null || { echo "ABORT: deno not installed — twin differential unrunnable"; exit 1; }
  mkdir -p "$DIFF_DIR"; rm -f "$DART_OUT" "$TS_OUT"
  cleanup() { rm -f "$DEST"; }
  trap cleanup EXIT
  cp "$TEST_SRC" "$DEST"
  echo "   arm:     twin harness — Dart engine (real selection kernels)"
  cd "$APP_ROOT"
  flutter test "test/_qa_conformance_tmp_test.dart" \
    --dart-define=QA_VECTORS="$VECTORS" --dart-define=QA_DIFF_OUT="$DART_OUT"
  echo "   arm:     twin harness — TS engine (Deno, same vectors)"
  QA_VECTORS="$VECTORS" QA_DIFF_OUT="$TS_OUT" \
    deno test --allow-read --allow-env --allow-write \
    supabase/functions/tests/food_recommendation_vectors.test.ts
  [ -s "$DART_OUT" ] || { echo "ABORT: Dart differential output missing"; exit 1; }
  [ -s "$TS_OUT" ]   || { echo "ABORT: TS differential output missing"; exit 1; }
  if ! cmp -s "$DART_OUT" "$TS_OUT"; then
    echo "ABORT: §8 twin differential FAILED — the two engines disagree:"
    diff "$DART_OUT" "$TS_OUT" | head -20
    exit 1
  fi
  echo "   twin differential: byte-equal on $(wc -l < "$DART_OUT" | tr -d ' ') vectors ✓"
  exit 0
fi

case "$VEC_PATH" in
  vectors/fueling/*.json)
    UNDER="${SLICE//-/_}"
    VECTORS="$QA_ROOT/$VEC_PATH"
    TEST_SRC="$QA_ROOT/conformance/${UNDER}_conformance_test.dart"
    DEST="$APP_ROOT/test/_qa_conformance_tmp_test.dart"
    [ -f "$VECTORS" ]  || { echo "ABORT: vectors missing: $VECTORS"; exit 1; }
    [ -f "$TEST_SRC" ] || { echo "ABORT: test missing: $TEST_SRC"; exit 1; }
    cleanup() { rm -f "$DEST"; }
    trap cleanup EXIT
    cp "$TEST_SRC" "$DEST"
    echo "   arm:     Dart harness vs real OfflineMacroCalculator"
    cd "$APP_ROOT"
    flutter test "test/_qa_conformance_tmp_test.dart" --dart-define=QA_VECTORS="$VECTORS"
    ;;

  vectors/domain/*.json)
    # Domain family (first slice: brick-eligibility). Same copy-in harness
    # pattern as fueling, but the vectors are mirror-checked (the family
    # postdates the pilot's mirror exemption).
    require_mirror "$VEC_PATH"
    UNDER="${SLICE//-/_}"
    VECTORS="$QA_ROOT/$VEC_PATH"
    TEST_SRC="$QA_ROOT/conformance/${UNDER}_conformance_test.dart"
    DEST="$APP_ROOT/test/_qa_conformance_tmp_test.dart"
    [ -f "$VECTORS" ]  || { echo "ABORT: vectors missing: $VECTORS"; exit 1; }
    [ -f "$TEST_SRC" ] || { echo "ABORT: test missing: $TEST_SRC"; exit 1; }
    cleanup() { rm -f "$DEST"; }
    trap cleanup EXIT
    cp "$TEST_SRC" "$DEST"
    echo "   arm:     Dart harness vs the published domain predicate"
    cd "$APP_ROOT"
    flutter test "test/_qa_conformance_tmp_test.dart" --dart-define=QA_VECTORS="$VECTORS"
    ;;

  vectors/daily-macros/intraday-display.json)
    require_mirror "$VEC_PATH"
    echo "   arm:     Dart display-consumer suite (intraday_display_vectors_test.dart)"
    cd "$APP_ROOT"
    flutter test test/features/daily_macros/intraday_display_vectors_test.dart
    ;;

  vectors/daily-macros/*.json)
    require_mirror "$VEC_PATH"
    SECTION="$(basename "$VEC_PATH" .json)"
    RUNNER="supabase/functions/calculate-daily-macros-v6/vectors.conformance.test.ts"
    [ -f "$APP_ROOT/$RUNNER" ] || { echo "ABORT: app Deno runner missing: $RUNNER"; exit 1; }
    command -v deno >/dev/null || { echo "ABORT: deno not installed — gate unrunnable"; exit 1; }
    echo "   arm:     Deno vectors runner, --filter \"vectors: $SECTION\""
    cd "$APP_ROOT"
    OUT="$(deno test --allow-read --allow-env "$RUNNER" --filter "vectors: $SECTION" 2>&1)" || {
      echo "$OUT"; exit 1; }
    echo "$OUT" | grep -E "^\s+.*\.\.\. |passed|failed" | sed 's/\x1b\[[0-9;]*m//g'
    # A filter that matches nothing is "0 passed" — that is NOT green.
    if echo "$OUT" | sed 's/\x1b\[[0-9;]*m//g' | grep -qE "^ok \| 0 passed"; then
      echo "ABORT: no describe block matched 'vectors: $SECTION' — a missing harness is RED"; exit 1
    fi
    ;;

  conformance/design/*.yaml)
    require_mirror "$VEC_PATH"
    # The manifest may name its own app-side suite (`suite: <path under app>`);
    # default to the macro-dashboard suites for the pilot-era manifests.
    SUITE="$(grep -E '^suite:' "$QA_ROOT/$VEC_PATH" | sed -E 's/^suite:[[:space:]]*//; s/[[:space:]]*#.*$//' | tail -1 || true)"
    [ -n "$SUITE" ] || SUITE="test/features/macro_dashboard/"
    echo "   arm:     design conformance suite: $SUITE"
    cd "$APP_ROOT"
    flutter test "$SUITE"
    ;;

  *)
    echo "ABORT: no runner arm for '$VEC_PATH' (slice '$SLICE') — add one to conformance/run_dart.sh"
    exit 1
    ;;
esac
