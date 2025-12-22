#!/bin/bash
# v1 → v2 Migration Testing Script
# Usage: ./test_migration.sh

set -e  # Exit on error

echo "🧪 Mealvana v1 → v2 Migration Test"
echo "=================================="

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Create v1 database
echo -e "\n${BLUE}Step 1: Setting up v1 database (App Store state)${NC}"
git stash
git checkout main
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs

echo -e "${GREEN}✓ v1 environment ready${NC}"
echo ""
echo "⚠️  MANUAL STEP REQUIRED:"
echo "   1. Run: flutter run --flavor prod --dart-define-from-file=.env.prod.local"
echo "   2. In the app, create test data:"
echo "      - Complete onboarding"
echo "      - Add food preferences"
echo "      - Create 2-3 nutrition plans"
echo "      - Add activities and events"
echo "   3. Stop the app (Ctrl+C)"
echo "   4. Press ENTER to continue with migration test"
read -p ""

# Step 2: Test migration
echo -e "\n${BLUE}Step 2: Testing v1 → v2 migration${NC}"
git checkout develop
git stash pop
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs

echo -e "${GREEN}✓ v2 environment ready${NC}"
echo ""
echo "⚠️  MANUAL STEP REQUIRED:"
echo "   1. Run: flutter run --flavor prod --dart-define-from-file=.env.prod.local"
echo "   2. Verify migration succeeded (check console for errors)"
echo "   3. Test the verification checklist (see above)"
echo "   4. Check Flutter DevTools → Database Inspector for schema"
echo ""
echo -e "${GREEN}✓ Migration test setup complete!${NC}"
