/// Integration Test Runner for Mealvana Endurance
///
/// This is the main entry point for running all integration tests.
/// These tests run on a real device/simulator with actual UI interactions.
///
/// Running tests:
/// ```bash
/// # Run all integration tests on iOS simulator
/// flutter test integration_test/test_runner.dart -d "iPhone 15"
///
/// # Run with verbose output
/// flutter test integration_test/test_runner.dart -d "iPhone 15" --reporter expanded
/// ```
///
/// Test Coverage:
/// 1. Onboarding + Auth Flow - New user signup through email registration
/// 2. Email Login Flow - Existing user login with test@test.com
/// 3. Nutrition Plan Flow - Create activity, generate plan, swap/edit/delete foods
/// 4. Food Management Flow - Search OpenFoodFacts, add food to preferences
/// 5. Settings Flow - Update profile, change gut training level
/// 6. Event Management Flow - Create, edit, delete events
library;

import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';

// Import all flow tests
import 'flows/onboarding_auth_flow_test.dart' as onboarding_auth;
import 'flows/email_login_flow_test.dart' as email_login;
import 'flows/nutrition_plan_flow_test.dart' as nutrition_plan;
import 'flows/food_management_flow_test.dart' as food_management;
import 'flows/settings_flow_test.dart' as settings;
import 'flows/event_management_flow_test.dart' as event_management;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Mealvana Endurance - Full Integration Test Suite', () {
    // Run each flow's tests
    onboarding_auth.main();
    email_login.main();
    nutrition_plan.main();
    food_management.main();
    settings.main();
    event_management.main();
  });
}
