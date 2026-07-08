#!/bin/bash
# =============================================================================
# Nutrition Algorithm Test Runner
# =============================================================================
#
# Runs all nutrition algorithm tests in sequence with clear section headers.
#
# Usage:
#   ./supabase/functions/run-algorithm-tests.sh              # Local tests only
#   ./supabase/functions/run-algorithm-tests.sh --e2e         # Local + E2E tests
#
# E2E tests require environment variables:
#   export SUPABASE_URL=https://wvmvsodrvbkxfydabqed.supabase.co
#   export SUPABASE_ANON_KEY=<your-anon-key>
#
# =============================================================================

set -e

DENO="${DENO:-deno}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_DIR="$SCRIPT_DIR/_shared/nutrition"
E2E_DIR="$SCRIPT_DIR/generate-nutrition-plan-v3"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0
SKIPPED=0

run_test() {
  local label="$1"
  local file="$2"
  shift 2
  local flags=("$@")

  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  $label${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  if [ ! -f "$file" ]; then
    echo -e "${YELLOW}  SKIPPED: File not found: $file${NC}"
    SKIPPED=$((SKIPPED + 1))
    return
  fi

  if $DENO test "${flags[@]}" "$file" 2>&1; then
    echo -e "${GREEN}  PASSED${NC}"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}  FAILED${NC}"
    FAILED=$((FAILED + 1))
  fi
}

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Mealvana Endurance — Nutrition Algorithm Tests      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"

# ─── Section 1: Local Algorithm Tests ───────────────────────────────────────

echo ""
echo -e "${YELLOW}▶ SECTION 1: Local Algorithm Tests${NC}"

run_test \
  "1a. During Rule Solver (unit tests)" \
  "$SHARED_DIR/during-rule-solver.test.ts" \
  --allow-write

run_test \
  "1b. Algorithm Audit (comprehensive local tests)" \
  "$SHARED_DIR/algorithm-audit.test.ts" \
  --allow-write

run_test \
  "1c. LP Solver (unit tests)" \
  "$SHARED_DIR/lp-solver.test.ts" \
  --allow-write

run_test \
  "1d. Before-Phase Filtering (unit tests)" \
  "$SCRIPT_DIR/generate-nutrition-plan-v3/before-phase-filtering.test.ts" \
  --allow-write

run_test \
  "1e. Pre-Workout Algorithm C (unit tests)" \
  "$SCRIPT_DIR/generate-macros-v4/pre-workout-invariants.test.ts" \
  --allow-write --node-modules-dir=none

run_test \
  "1f. During Template Solver (unit tests)" \
  "$SHARED_DIR/during-template-solver.test.ts" \
  --allow-write

run_test \
  "1f2. During Template — Pin-Override Shortfall (Bug 395e3fdb)" \
  "$SHARED_DIR/during-template-pinoverride.test.ts" \
  --allow-write --node-modules-dir=none

# 1g (During Template Migration Catalog) removed 2026-06-09: it asserted the
# contents of supabase/migrations/20260406320000_during_workout_templates_complete.sql,
# which was deleted in the Formula Kit DB cleanup (b2f86b4). Catalog now lives in the DB.

run_test \
  "1g. Corpus-Driven Parity Harness (scenario × plan-solver)" \
  "$SCRIPT_DIR/tests/parity/parity.test.ts" \
  --allow-read --allow-write --node-modules-dir=none

run_test \
  "1h. During Phase — Empty Pool Failure Modes (P1 bug tracking)" \
  "$E2E_DIR/during-phase-empty-pool.test.ts" \
  --allow-write --node-modules-dir=none

run_test \
  "1i. During Template — Missing Component Food Failure Modes (P6)" \
  "$SHARED_DIR/during-template-missing-component.test.ts" \
  --allow-write --node-modules-dir=none

run_test \
  "1j. Macro-Target Adherence — during-phase rule solver + shortfall asymmetry (P3)" \
  "$E2E_DIR/macro-adherence.test.ts" \
  --allow-read --allow-write --node-modules-dir=none

run_test \
  "1k. After-Phase Adherence — canonical portioning mismatch detection (P4)" \
  "$E2E_DIR/after-phase-adherence.test.ts" \
  --allow-write --node-modules-dir=none

run_test \
  "1l. Diet & Allergy Filtering — allergen exclusion, gluten/dairy/peanut-free, vegan/vegetarian known-failure, dislike scoring, pin bypass (P2)" \
  "$E2E_DIR/diet-allergy-filtering.test.ts" \
  --allow-write --node-modules-dir=none

run_test \
  "1m. LP Solver — infeasibility & empty-pool fallback (P5)" \
  "$SHARED_DIR/lp-infeasibility.test.ts" \
  --allow-read --allow-write --node-modules-dir=none

run_test \
  "1n. Macro Engine — duration bands, sport ceilings, gut multipliers" \
  "$SCRIPT_DIR/generate-macros-v4/macro-bands.test.ts" \
  --allow-read --allow-write --allow-env --node-modules-dir=none

run_test \
  "1o. Pre-Workout Template DB Failure — throws → HTTP 500 (P7)" \
  "$SCRIPT_DIR/generate-macros-v4/pre-workout-db-failure.test.ts" \
  --allow-read --allow-write --allow-env --node-modules-dir=none

run_test \
  "1p. AI Coach — validation, prompt wiring, guardrails, model env override" \
  "$SCRIPT_DIR/ai-coach/index.test.ts" \
  --allow-env --allow-read --allow-net

run_test \
  "1q. Analyze Meal Photo — schema, auth authz, MIME inference, base64, not_food" \
  "$SCRIPT_DIR/analyze-meal-photo/index.test.ts" \
  --allow-env --allow-read --allow-net

run_test \
  "1r. Describe Meal — validation, schema, prompt embedding, credit cost" \
  "$SCRIPT_DIR/describe-meal/index.test.ts" \
  --allow-env --allow-read --allow-net

run_test \
  "1s. Jade Chat — NDJSON envelope, validation, opener mode, system prompt, CORS, date math" \
  "$SCRIPT_DIR/jade-chat/index.test.ts" \
  --allow-env --allow-read --allow-net

run_test \
  "1t. lookup-product — detectProductType (3-stage: taxonomy, brand, keyword), sodium ×1000, catalog mapping" \
  "$SCRIPT_DIR/lookup-product/index.test.ts" \
  --allow-env --node-modules-dir=none

run_test \
  "1u. get-foods — deduplication, column rename mapping, suitability flags, null-safety" \
  "$SCRIPT_DIR/get-foods/index.test.ts" \
  --allow-env --node-modules-dir=none

run_test \
  "1v. search-catalog — query validation, limit clamping, has_nutrition derived field, response shape" \
  "$SCRIPT_DIR/search-catalog/index.test.ts" \
  --allow-env --node-modules-dir=none

run_test \
  --allow-env --node-modules-dir=none

run_test \
  "1x. search-public-events — query validation (≥2 chars), response assembly, match flags, RPC arg wiring" \
  "$SCRIPT_DIR/search-public-events/index.test.ts" \
  --allow-env --node-modules-dir=none

run_test \
  "1y. create-user — validation, default fields, onboarding_completed, food-prefs side-effect, duplicate 409" \
  "$SCRIPT_DIR/create-user/index.test.ts" \
  --allow-env --node-modules-dir=none

run_test \
  "1z. delete-user — auth enforcement, cascade order, idempotency, auth admin error propagation" \
  "$SCRIPT_DIR/delete-user/index.test.ts" \
  --allow-env --node-modules-dir=none

run_test \
  "1aa. upsert-user-profile — partial update merge, enum validation, food-pref upsert, RLS intent" \
  "$SCRIPT_DIR/upsert-user-profile/index.test.ts" \
  --allow-env --node-modules-dir=none

run_test \
  "1ab. get-weather-forecast — date routing, Open-Meteo shape, WMO conditions, fallback defaults, hydration contract" \
  "$SCRIPT_DIR/get-weather-forecast/index.test.ts" \
  --allow-env --node-modules-dir=none

run_test \
  "1ac. send-nutrition-plan-email — validation, Resend call assembly, HTML template, error handling" \
  "$SCRIPT_DIR/send-nutrition-plan-email/index.test.ts" \
  --allow-env --node-modules-dir=none

# ─── Section 2: E2E Tests (optional) ───────────────────────────────────────

if [ "$1" = "--e2e" ]; then
  echo ""
  echo -e "${YELLOW}▶ SECTION 2: E2E Integration Tests${NC}"

  if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
    echo -e "${RED}  ERROR: SUPABASE_URL and SUPABASE_ANON_KEY must be set for E2E tests${NC}"
    echo "  Run:"
    echo "    export SUPABASE_URL=https://wvmvsodrvbkxfydabqed.supabase.co"
    echo "    export SUPABASE_ANON_KEY=<your-anon-key>"
    SKIPPED=$((SKIPPED + 1))
  else
    run_test \
      "2a. generate-nutrition-plan-v3 E2E" \
      "$E2E_DIR/index.test.ts" \
      --allow-net --allow-env

    run_test \
      "2b. generate-nutrition-plan-v3 strict macro E2E" \
      "$E2E_DIR/strict-macro-e2e.test.ts" \
      --allow-net --allow-env

    run_test \
      "2c. generate-macros-v4 E2E" \
      "$SCRIPT_DIR/generate-macros-v4/index.test.ts" \
      --allow-net --allow-env
  fi
else
  echo ""
  echo -e "${YELLOW}▶ SECTION 2: E2E Tests — SKIPPED (use --e2e flag)${NC}"
  SKIPPED=$((SKIPPED + 1))
fi

# ─── Summary ────────────────────────────────────────────────────────────────

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    TEST SUMMARY                        ║${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════════════════════╣${NC}"
printf "${BLUE}║${NC}  ${GREEN}Passed:  %-3d${NC}                                        ${BLUE}║${NC}\n" "$PASSED"
printf "${BLUE}║${NC}  ${RED}Failed:  %-3d${NC}                                        ${BLUE}║${NC}\n" "$FAILED"
printf "${BLUE}║${NC}  ${YELLOW}Skipped: %-3d${NC}                                        ${BLUE}║${NC}\n" "$SKIPPED"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$FAILED" -gt 0 ]; then
  echo -e "${RED}Some tests FAILED!${NC}"
  exit 1
else
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
