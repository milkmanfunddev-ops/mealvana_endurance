#!/bin/bash
# =============================================================================
# Meal planning (Vana) — test runner
# =============================================================================
#
# Every meal-planning test in one place, runnable as one suite or one layer at
# a time. Nothing here is a new test harness: each layer is the plain command
# you would type by hand, so a layer that passes here passes in CI, and CI's
# bare `flutter test` still runs all of it (the Flutter layers all live under
# `test/`, which is the CI gate — see docs/test/README.md).
#
# Usage:
#   ./scripts/run-meal-planning-tests.sh                 # every layer except patrol
#   ./scripts/run-meal-planning-tests.sh unit widget     # just those layers
#   ./scripts/run-meal-planning-tests.sh --list          # what the layers are
#   ./scripts/run-meal-planning-tests.sh --update-goldens
#   ./scripts/run-meal-planning-tests.sh patrol          # simulator, dev flavor
#
# Layers:
#   domain     test/features/meal_planning/domain           parsers, fixtures, coverage, icons
#   data       test/features/meal_planning/data             repositories, transport, action client
#   app        test/features/meal_planning/application      controllers through the real notifiers
#   widget     test/features/meal_planning/presentation     widgets + goldens
#   content    the meal_planning.* ContentKeys ↔ defaults parity test
#   migration  the Drift v20 schema-verifier test
#   edge       supabase/functions/tests/vana (Deno, via the auto-discovery runner)
#   patrol     integration_test/flows — the Pro gate flow. NOT in the default
#              run: it needs a booted simulator and dev credentials.
#
# `unit` is shorthand for domain+data+app; `all` is every layer except patrol.
#
# The plan-build Patrol flow (meal_plan_build_flow_test.dart) is deliberately
# NOT wired in here or into CI: every turn of it calls vana-chat / vana-action
# and bills real model spend, the same reason ai_coach_chat_flow_test is kept
# out of the target lists. Run it by hand when you mean to. Same for the
# persona eval (`deno run -A scripts/vana-eval/run.ts`, dev-only): it replays
# ~10 canned planning conversations against the deployed dev functions and
# asserts the voice contract — real model spend, never in CI.
# =============================================================================

set -o pipefail
cd "$(dirname "$0")/.."

GREEN='\033[0;32m'; RED='\033[0;31m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'

FLUTTER_ARGS=()
LAYERS=()

for arg in "$@"; do
  case "$arg" in
    --list)
      sed -n '/^# Layers:/,/^# `unit`/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --update-goldens) FLUTTER_ARGS+=(--update-goldens) ;;
    -*)               FLUTTER_ARGS+=("$arg") ;;
    *)                LAYERS+=("$arg") ;;
  esac
done

[ ${#LAYERS[@]} -eq 0 ] && LAYERS=(all)

# Expand the shorthands.
EXPANDED=()
for layer in "${LAYERS[@]}"; do
  case "$layer" in
    all)  EXPANDED+=(domain data app widget content migration edge) ;;
    unit) EXPANDED+=(domain data app) ;;
    *)    EXPANDED+=("$layer") ;;
  esac
done

path_for() {
  case "$1" in
    domain)    echo "test/features/meal_planning/domain" ;;
    data)      echo "test/features/meal_planning/data" ;;
    app)       echo "test/features/meal_planning/application" ;;
    widget)    echo "test/features/meal_planning/presentation" ;;
    content)   echo "test/features/content/meal_planning_content_keys_parity_test.dart" ;;
    migration) echo "test/migrations/meal_planning_v20_migration_test.dart" ;;
    *)         echo "" ;;
  esac
}

FAILED=()
PASSED=()

run_flutter_layer() {
  local layer="$1" path
  path="$(path_for "$layer")"
  if [ -z "$path" ]; then
    echo -e "${RED}unknown layer: $layer${NC} (try --list)"
    FAILED+=("$layer")
    return
  fi
  if [ ! -e "$path" ]; then
    echo -e "${RED}missing path for $layer: $path${NC}"
    FAILED+=("$layer")
    return
  fi
  echo ""
  echo -e "${BLUE}━━━ $layer — flutter test $path ━━━${NC}"
  if flutter test "${FLUTTER_ARGS[@]}" "$path"; then
    PASSED+=("$layer")
  else
    FAILED+=("$layer")
  fi
}

run_edge_layer() {
  echo ""
  echo -e "${BLUE}━━━ edge — deno test supabase/functions/tests/vana ━━━${NC}"
  if ! command -v deno >/dev/null 2>&1; then
    echo -e "${YELLOW}deno not installed — edge layer skipped${NC}"
    return
  fi
  # Same flags the repo-wide runner uses for local (fetch-stubbed) tests.
  if deno test --allow-read --allow-write --allow-env --node-modules-dir=none \
       supabase/functions/tests/vana; then
    PASSED+=(edge)
  else
    FAILED+=(edge)
  fi
}

run_patrol_layer() {
  echo ""
  echo -e "${BLUE}━━━ patrol — pro_gate_flow_test (dev flavor, booted simulator) ━━━${NC}"
  if ! command -v patrol >/dev/null 2>&1; then
    echo -e "${YELLOW}patrol_cli not installed — patrol layer skipped${NC}"
    echo "  dart pub global activate patrol_cli 4.4.0"
    return
  fi
  if patrol test \
       --target integration_test/flows/pro_gate_flow_test.dart \
       --flavor dev \
       --dart-define-from-file=.env.dev.local \
       --dart-define-from-file=secrets/integration_test.env \
       --device "${PATROL_DEVICE:-iPhone 17 Pro}"; then
    PASSED+=(patrol)
  else
    FAILED+=(patrol)
  fi
}

for layer in "${EXPANDED[@]}"; do
  case "$layer" in
    edge)   run_edge_layer ;;
    patrol) run_patrol_layer ;;
    *)      run_flutter_layer "$layer" ;;
  esac
done

echo ""
echo -e "${BLUE}════════════════ SUMMARY ════════════════${NC}"
for l in "${PASSED[@]:-}"; do [ -n "$l" ] && echo -e "  ${GREEN}PASS${NC} $l"; done
for l in "${FAILED[@]:-}"; do [ -n "$l" ] && echo -e "  ${RED}FAIL${NC} $l"; done

if [ ${#FAILED[@]} -gt 0 ]; then
  echo -e "${RED}${#FAILED[@]} layer(s) failed.${NC}"
  exit 1
fi
echo -e "${GREEN}All requested layers passed.${NC}"
