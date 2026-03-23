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
      "2b. generate-macros-v4 E2E" \
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
