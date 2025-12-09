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
APP_BUNDLE_ID="com.lee.endurance"

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

# Get simulator UUID from device name
get_simulator_uuid() {
    local device_name="$1"
    # Get the booted simulator's UUID
    local uuid=$(xcrun simctl list devices | grep -i "$device_name" | grep "Booted" | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
    if [ -z "$uuid" ]; then
        # Try to get any simulator with that name
        uuid=$(xcrun simctl list devices | grep -i "$device_name" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
    fi
    echo "$uuid"
}

# Grant iOS permissions for the app to avoid permission dialogs blocking tests
grant_ios_permissions() {
    local sim_uuid="$1"

    if [ -z "$sim_uuid" ]; then
        print_info "No simulator UUID found, skipping permission grants"
        return
    fi

    print_info "Granting iOS permissions to avoid dialogs during tests..."

    # Grant notification permission
    if xcrun simctl privacy "$sim_uuid" grant notifications "$APP_BUNDLE_ID" 2>/dev/null; then
        print_success "Granted notification permission"
    else
        print_info "Could not grant notification permission (may require app to be installed first)"
    fi

    # Grant location permission (always)
    if xcrun simctl privacy "$sim_uuid" grant location-always "$APP_BUNDLE_ID" 2>/dev/null; then
        print_success "Granted location permission"
    else
        print_info "Could not grant location permission (may require app to be installed first)"
    fi

    # Grant camera permission
    if xcrun simctl privacy "$sim_uuid" grant camera "$APP_BUNDLE_ID" 2>/dev/null; then
        print_success "Granted camera permission"
    else
        print_info "Could not grant camera permission"
    fi

    # Grant photo library permission
    if xcrun simctl privacy "$sim_uuid" grant photos "$APP_BUNDLE_ID" 2>/dev/null; then
        print_success "Granted photos permission"
    else
        print_info "Could not grant photos permission"
    fi
}

# Reset app state on simulator (uninstall app to clear all data and permissions)
reset_app_state() {
    local sim_uuid="$1"

    if [ -z "$sim_uuid" ]; then
        print_info "No simulator UUID found, skipping app reset"
        return
    fi

    print_info "Resetting app state on simulator..."

    # Uninstall the app if it exists
    if xcrun simctl uninstall "$sim_uuid" "$APP_BUNDLE_ID" 2>/dev/null; then
        print_success "Uninstalled existing app"
    else
        print_info "App was not installed"
    fi
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
    echo "Usage: $0 [test-name] [flags]"
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
    echo "Flags:"
    echo "  --no-reset        - Skip app uninstall (keep existing data)"
    echo "  --no-permissions  - Skip auto-granting iOS permissions"
    echo ""
    echo "Examples:"
    echo "  $0 quick            # Clean start: uninstall app, run all tests"
    echo "  $0 quick --no-reset # Keep app data, run all tests"
    echo "  $0 nutrition        # Debug: just nutrition plan test"
    echo "  $0 all              # Slow: all tests in separate sessions"
    echo ""
    echo "Note: By DEFAULT, the app is uninstalled before each test run for"
    echo "      clean, reproducible results. Use --no-reset to keep app data."
    echo ""
    echo "IMPORTANT: On first run after uninstall, iOS will show a notification"
    echo "           permission dialog. You must tap 'Allow' for tests to proceed."
    echo ""
}

# Main script
print_header "Mealvana Endurance Integration Tests"

# Parse flags
# NOTE: Reset is ON by default for clean, reproducible tests
RESET_APP=true
SKIP_PERMISSIONS=false
for arg in "$@"; do
    case "$arg" in
        --no-reset)
            RESET_APP=false
            ;;
        --no-permissions)
            SKIP_PERMISSIONS=true
            ;;
    esac
done

# Get non-flag argument
TEST_FILTER=""
for arg in "$@"; do
    if [[ "$arg" != --* ]]; then
        TEST_FILTER="$arg"
        break
    fi
done
TEST_FILTER="${TEST_FILTER:-quick}"

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

# Get simulator UUID for permission management
SIM_UUID=$(get_simulator_uuid "$DEVICE")
if [ -n "$SIM_UUID" ]; then
    print_info "Simulator UUID: $SIM_UUID"

    # Reset app if requested
    if [ "$RESET_APP" = true ]; then
        reset_app_state "$SIM_UUID"
    fi

    # Grant permissions (unless skipped)
    if [ "$SKIP_PERMISSIONS" = false ]; then
        grant_ios_permissions "$SIM_UUID"
    fi
else
    print_info "Could not determine simulator UUID - permissions will need manual approval"
fi

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
