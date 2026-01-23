#!/bin/bash
# Integration tests for generate-nutrition-plan edge function
# Run: bash supabase/functions/generate-nutrition-plan/test-integration.sh

set -e

# Configuration
SUPABASE_URL="${SUPABASE_URL:-https://vlmtsdzpnjnavdgytcmi.supabase.co}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZsbXRzZHpwbmpuYXZkZ3l0Y21pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk4NTI3OTAsImV4cCI6MjA3NTQyODc5MH0._7t1pjG_1zk4xkfseu2ACqYXdwEJKcRUWyvY4ZXs35o}"
EDGE_FUNCTION_URL="${SUPABASE_URL}/functions/v1/generate-nutrition-plan"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0
WARNINGS=0

# Known fallback indicators
FALLBACK_PATTERNS="gels/chews|fluids + electrolytes|carbs + electrolytes|generic carbs|generic fuel|electrolyte drink|carbohydrate source"

# Helper function to call edge function
call_edge_function() {
    curl -s -X POST "$EDGE_FUNCTION_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
        -d "$1"
}

# Helper to check for fallback items
check_for_fallbacks() {
    local response="$1"
    local test_name="$2"

    if echo "$response" | grep -iE "$FALLBACK_PATTERNS" > /dev/null; then
        echo -e "${RED}FAIL${NC}: $test_name - Found fallback items (LP solver may have failed)"
        ((FAILED++))
        return 1
    fi
    return 0
}

# Test function
run_test() {
    local test_name="$1"
    local payload="$2"
    local expected_success="$3"

    echo -n "Testing: $test_name... "

    response=$(call_edge_function "$payload")
    success=$(echo "$response" | jq -r '.success // false')

    if [ "$success" = "$expected_success" ]; then
        # Check for fallback items
        if [ "$expected_success" = "true" ] && ! check_for_fallbacks "$response" "$test_name"; then
            return
        fi

        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))

        # Show food counts if successful
        if [ "$expected_success" = "true" ]; then
            before_count=$(echo "$response" | jq '.plan.before | length // 0' 2>/dev/null || echo "0")
            during_count=$(echo "$response" | jq '.plan.during | length // .plan.during_segments | length // 0' 2>/dev/null || echo "0")
            after_count=$(echo "$response" | jq '.plan.after | length // 0' 2>/dev/null || echo "0")

            if [ "$before_count" = "0" ] && [ "$after_count" = "0" ]; then
                echo -e "  ${YELLOW}WARNING${NC}: Empty before/after phases (no foods in database for those categories)"
                ((WARNINGS++))
            fi

            echo "  Foods: before=$before_count, during=$during_count, after=$after_count"
        fi
    else
        echo -e "${RED}FAIL${NC}: Expected success=$expected_success, got $success"
        ((FAILED++))
        echo "  Response: $(echo "$response" | jq -c '.')"
    fi
}

echo "=============================================="
echo "Generate Nutrition Plan Integration Tests"
echo "=============================================="
echo "Edge Function URL: $EDGE_FUNCTION_URL"
echo ""

# Test 1: Running workout
run_test "Running workout" '{
    "device_id": "test-device-running-001",
    "activity_type": "running",
    "macro_targets": {
        "pre_run": {"carbs_g": 50, "protein_g": 10, "sodium_mg": 300, "water_ml": 400},
        "during_run": {"carbs_g": 60, "sodium_mg": 500, "water_ml": 800},
        "post_run": {"carbs_g": 80, "protein_g": 25, "sodium_mg": 400, "water_ml": 600}
    }
}' "true"

# Test 2: Cycling workout
run_test "Cycling workout" '{
    "device_id": "test-device-cycling-001",
    "activity_type": "cycling",
    "macro_targets": {
        "pre_run": {"carbs_g": 60, "protein_g": 15, "sodium_mg": 350, "water_ml": 500},
        "during_run": {"carbs_g": 90, "sodium_mg": 700, "water_ml": 1200},
        "post_run": {"carbs_g": 100, "protein_g": 30, "sodium_mg": 500, "water_ml": 800}
    }
}' "true"

# Test 3: Swimming workout
run_test "Swimming workout" '{
    "device_id": "test-device-swimming-001",
    "activity_type": "swimming",
    "macro_targets": {
        "pre_run": {"carbs_g": 40, "protein_g": 10, "sodium_mg": 200, "water_ml": 300},
        "during_run": {"carbs_g": 30, "sodium_mg": 300, "water_ml": 500},
        "post_run": {"carbs_g": 60, "protein_g": 20, "sodium_mg": 300, "water_ml": 500}
    }
}' "true"

# Test 4: Brick workout (swim/run)
run_test "Brick workout (swim/run)" '{
    "device_id": "test-device-brick-001",
    "activity_type": "brick",
    "macro_targets": {
        "phases": {
            "before": {"carbs_g": 50, "protein_g": 10, "sodium_mg": 300, "water_ml": 400},
            "during_segments": [
                {"segment_order": 1, "sport": "swimming", "duration_minutes": 30, "carbs_g": 20, "sodium_mg": 200, "water_ml": 300},
                {"segment_order": 2, "sport": "running", "duration_minutes": 45, "carbs_g": 40, "sodium_mg": 400, "water_ml": 500}
            ],
            "transitions": [{"transition_name": "T1", "carbs_g": 15, "sodium_mg": 100, "water_ml": 150}],
            "after": {"carbs_g": 80, "protein_g": 25, "sodium_mg": 400, "water_ml": 600}
        }
    }
}' "true"

# Test 5: Brick workout (bike/run)
run_test "Brick workout (bike/run)" '{
    "device_id": "test-device-brick-002",
    "activity_type": "brick",
    "macro_targets": {
        "phases": {
            "before": {"carbs_g": 60, "protein_g": 12, "sodium_mg": 350, "water_ml": 450},
            "during_segments": [
                {"segment_order": 1, "sport": "cycling", "duration_minutes": 60, "carbs_g": 60, "sodium_mg": 500, "water_ml": 800},
                {"segment_order": 2, "sport": "running", "duration_minutes": 30, "carbs_g": 30, "sodium_mg": 300, "water_ml": 400}
            ],
            "transitions": [{"transition_name": "T1", "carbs_g": 15, "sodium_mg": 100, "water_ml": 150}],
            "after": {"carbs_g": 90, "protein_g": 30, "sodium_mg": 450, "water_ml": 700}
        }
    }
}' "true"

# Test 6: Error - Missing device_id
run_test "Error: Missing device_id" '{
    "activity_type": "running",
    "macro_targets": {
        "pre_run": {"carbs_g": 50},
        "during_run": {"carbs_g": 60},
        "post_run": {"carbs_g": 80}
    }
}' "false"

# Test 7: Error - Missing macro_targets
run_test "Error: Missing macro_targets" '{
    "device_id": "test-device-001",
    "activity_type": "running"
}' "false"

# Test 8: Error - Brick without phases
run_test "Error: Brick without phases" '{
    "device_id": "test-device-001",
    "activity_type": "brick",
    "macro_targets": {
        "pre_run": {"carbs_g": 50}
    }
}' "false"

echo ""
echo "=============================================="
echo "Test Results"
echo "=============================================="
echo -e "Passed:   ${GREEN}$PASSED${NC}"
echo -e "Failed:   ${RED}$FAILED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
