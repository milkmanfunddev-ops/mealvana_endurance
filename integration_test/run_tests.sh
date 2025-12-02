#!/bin/bash

# Integration Test Runner for Mealvana Endurance
#
# Usage:
#   ./integration_test/run_tests.sh              # Run all tests (individual files - slow)
#   ./integration_test/run_tests.sh quick        # Run all flows in ONE app session (FAST!)
#   ./integration_test/run_tests.sh nutrition    # Run nutrition plan test only
#   ./integration_test/run_tests.sh event        # Run event management test only
#   ./integration_test/run_tests.sh settings     # Run settings test only
#   ./integration_test/run_tests.sh food         # Run food management test only
#   ./integration_test/run_tests.sh onboarding   # Run onboarding test only
#
# Tips:
#   - Use 'quick' for fastest testing (builds once, onboards once, runs all flows)
#   - Use individual tests for debugging specific flows
#   - Add --no-build flag to skip rebuild if app hasn't changed

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_DEVICE="iphone 15 pro max"
TEST_DIR="integration_test"

# Print colored output
print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

print_tip() {
    echo -e "${CYAN}💡 $1${NC}"
}

# Find the best available iOS simulator
find_device() {
    # Check if the default device is available
    if flutter devices | grep -qi "$DEFAULT_DEVICE"; then
        echo "$DEFAULT_DEVICE"
        return
    fi

    # Try to find any iPhone simulator
    local device=$(flutter devices | grep -i "iphone.*simulator" | head -1 | awk -F'•' '{print $1}' | xargs)
    if [ -n "$device" ]; then
        echo "$device"
        return
    fi

    # Fall back to any iOS simulator
    local device=$(flutter devices | grep -i "simulator" | head -1 | awk -F'•' '{print $1}' | xargs)
    if [ -n "$device" ]; then
        echo "$device"
        return
    fi

    echo ""
}

# Run a single test file
run_test() {
    local test_file=$1
    local test_name=$2

    print_header "Running: $test_name"

    if flutter test "$test_file" -d "$DEVICE" --reporter expanded; then
        print_success "$test_name completed successfully"
        return 0
    else
        print_error "$test_name failed"
        return 1
    fi
}

# Show usage
show_usage() {
    echo ""
    echo "Usage: $0 [test-name]"
    echo ""
    echo "Available tests:"
    echo ""
    echo "  ${GREEN}quick${NC}        - Run ALL flows in ONE app session (RECOMMENDED - fastest!)"
    echo "                 Builds once, onboards once, runs all tests sequentially"
    echo ""
    echo "  ${YELLOW}Individual tests (each rebuilds app):${NC}"
    echo "  all          - Run all tests (separate sessions - slower)"
    echo "  nutrition    - Nutrition Plan Flow"
    echo "  event        - Event Management Flow"
    echo "  settings     - Settings Flow"
    echo "  food         - Food Management Flow"
    echo "  onboarding   - Onboarding & Auth Flow"
    echo ""
    echo "Examples:"
    echo "  $0 quick       # Fast: all tests in one session (~3 min)"
    echo "  $0 nutrition   # Debug: just nutrition plan test"
    echo "  $0 all         # Slow: all tests in separate sessions (~12 min)"
    echo ""
}

# Main script
print_header "Mealvana Endurance Integration Tests"

# Find device
DEVICE=$(find_device)

if [ -z "$DEVICE" ]; then
    print_error "No iOS simulator found!"
    echo "Please start an iOS simulator first:"
    echo "  open -a Simulator"
    echo "Or run:"
    echo "  flutter emulators --launch apple_ios_simulator"
    exit 1
fi

print_info "Using device: $DEVICE"

# Parse command line argument
TEST_FILTER="${1:-quick}"

case "$TEST_FILTER" in
    quick|fast|combined)
        print_header "Running All Flows in ONE Session (Fast Mode)"
        print_tip "This is the fastest way to run all tests!"
        print_tip "Build once → Onboard once → Run all flows"
        echo ""

        run_test "$TEST_DIR/flows/all_flows_test.dart" "All Flows (Combined)"
        ;;

    all|separate)
        print_info "Running all integration tests in separate sessions..."
        print_tip "For faster testing, use: $0 quick"
        echo ""

        FAILED_TESTS=()
        PASSED_TESTS=()

        # Run all tests sequentially
        if run_test "$TEST_DIR/flows/event_management_flow_test.dart" "Event Management Flow"; then
            PASSED_TESTS+=("Event Management")
        else
            FAILED_TESTS+=("Event Management")
        fi

        if run_test "$TEST_DIR/flows/nutrition_plan_flow_test.dart" "Nutrition Plan Flow"; then
            PASSED_TESTS+=("Nutrition Plan")
        else
            FAILED_TESTS+=("Nutrition Plan")
        fi

        if run_test "$TEST_DIR/flows/settings_flow_test.dart" "Settings Flow"; then
            PASSED_TESTS+=("Settings")
        else
            FAILED_TESTS+=("Settings")
        fi

        if run_test "$TEST_DIR/flows/food_management_flow_test.dart" "Food Management Flow"; then
            PASSED_TESTS+=("Food Management")
        else
            FAILED_TESTS+=("Food Management")
        fi

        # Summary
        print_header "Test Summary"

        if [ ${#PASSED_TESTS[@]} -gt 0 ]; then
            echo -e "${GREEN}Passed (${#PASSED_TESTS[@]}):${NC}"
            for test in "${PASSED_TESTS[@]}"; do
                echo -e "  ${GREEN}✓${NC} $test"
            done
        fi

        if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
            echo -e "\n${RED}Failed (${#FAILED_TESTS[@]}):${NC}"
            for test in "${FAILED_TESTS[@]}"; do
                echo -e "  ${RED}✗${NC} $test"
            done
            exit 1
        fi

        print_success "All tests passed!"
        ;;

    nutrition|nutrition-plan|plan)
        run_test "$TEST_DIR/flows/nutrition_plan_flow_test.dart" "Nutrition Plan Flow"
        ;;

    event|events|event-management)
        run_test "$TEST_DIR/flows/event_management_flow_test.dart" "Event Management Flow"
        ;;

    settings)
        run_test "$TEST_DIR/flows/settings_flow_test.dart" "Settings Flow"
        ;;

    food|food-management|food-preferences)
        run_test "$TEST_DIR/flows/food_management_flow_test.dart" "Food Management Flow"
        ;;

    onboarding|onboarding-auth)
        run_test "$TEST_DIR/flows/onboarding_auth_flow_test.dart" "Onboarding & Auth Flow"
        ;;

    login|email-login)
        run_test "$TEST_DIR/flows/email_login_flow_test.dart" "Email Login Flow"
        ;;

    help|-h|--help)
        show_usage
        ;;

    *)
        echo "Unknown test filter: $TEST_FILTER"
        show_usage
        exit 1
        ;;
esac
