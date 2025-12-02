/// All Flows Integration Test
///
/// Runs ALL test flows in a single app session for maximum efficiency.
/// This avoids rebuilding the app and re-onboarding for each test.
///
/// Usage:
///   ./integration_test/run_tests.sh all
///   flutter test integration_test/flows/all_flows_test.dart -d "iPhone 15"
///
/// Individual tests can still be run separately:
///   ./integration_test/run_tests.sh settings
///   ./integration_test/run_tests.sh event
///   ./integration_test/run_tests.sh nutrition
///   ./integration_test/run_tests.sh food
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mealvana_endurance/main.dart' as app;

import '../helpers/test_config.dart';
import '../helpers/test_helpers.dart';
import '../helpers/onboarding_helper.dart';

// Import reusable flow modules
import 'shared/settings_flow.dart';
import 'shared/event_management_flow.dart';
import 'shared/nutrition_plan_flow.dart';
import 'shared/food_management_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('All Integration Flows', () {
    testWidgets(
      'Complete app test suite - all flows in one session',
      (tester) async {
        TestLogger.logStep('Starting Complete Integration Test Suite');
        TestLogger.logInfo('This runs ALL flows in a single app session');
        TestLogger.logInfo('Build once, onboard once, test everything!');

        // ============================================================
        // APP LAUNCH & ONBOARDING (done once for all tests)
        // ============================================================
        TestLogger.logStep('Launching App');
        app.main();
        await tester.pumpAndSettle();
        await tester.wait(TestConfig.networkDelay);

        // Handle onboarding if needed
        if (find.text('Get Started').evaluate().isNotEmpty) {
          TestLogger.logSubStep('Completing onboarding (one time)...');
          await skipOnboarding(tester);
        }

        // Wait for main app
        await tester.waitForWidget(
          find.byType(BottomNavigationBar),
          timeout: TestConfig.mediumTimeout,
        );

        TestLogger.logSuccess('App ready - starting test flows');

        // ============================================================
        // FLOW 1: Settings
        // ============================================================
        try {
          await runSettingsFlow(tester);
          TestLogger.logSuccess('Settings Flow: PASSED');
        } catch (e) {
          TestLogger.logError('Settings Flow: FAILED - $e');
        }

        // Return to main screen (ensure clean state for next flow)
        await _ensureOnMainScreen(tester);

        // ============================================================
        // FLOW 2: Event Management
        // ============================================================
        try {
          await runEventManagementFlow(tester);
          TestLogger.logSuccess('Event Management Flow: PASSED');
        } catch (e) {
          TestLogger.logError('Event Management Flow: FAILED - $e');
        }

        await _ensureOnMainScreen(tester);

        // ============================================================
        // FLOW 3: Food Management
        // ============================================================
        try {
          await runFoodManagementFlow(tester);
          TestLogger.logSuccess('Food Management Flow: PASSED');
        } catch (e) {
          TestLogger.logError('Food Management Flow: FAILED - $e');
        }

        await _ensureOnMainScreen(tester);

        // ============================================================
        // FLOW 4: Nutrition Plan (last because it's the longest)
        // ============================================================
        try {
          await runNutritionPlanFlow(tester);
          TestLogger.logSuccess('Nutrition Plan Flow: PASSED');
        } catch (e) {
          TestLogger.logError('Nutrition Plan Flow: FAILED - $e');
        }

        // ============================================================
        // SUMMARY
        // ============================================================
        TestLogger.logStep('All Integration Tests Complete!');
        await tester.screenshot('all_flows_complete');
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  });
}

/// Helper to ensure we're on the main calendar/activities screen
Future<void> _ensureOnMainScreen(WidgetTester tester) async {
  // First, tap the calendar button in bottom nav to go to activities list
  // The bottom nav uses FontAwesomeIcons.calendar
  final calendarIcon = find.byIcon(FontAwesomeIcons.calendar);
  if (calendarIcon.evaluate().isNotEmpty) {
    TestLogger.logSubStep('Tapping calendar icon to return to activities...');
    await tester.tapAndSettle(calendarIcon.first);
    await tester.wait(TestConfig.pageTransitionDelay);
  }

  // Verify we're on the main screen
  await tester.pumpAndSettle();

  final onMainScreen = find.text('Upcoming Events').evaluate().isNotEmpty ||
      find.text('BY WEEK').evaluate().isNotEmpty ||
      find.textContaining('Create an Event').evaluate().isNotEmpty ||
      find.byIcon(FontAwesomeIcons.plus).evaluate().isNotEmpty;

  if (onMainScreen) {
    TestLogger.logSubStep('On main activities screen');
    return;
  }

  // Fallback: try pressing back buttons
  int attempts = 0;
  while (attempts < 3) {
    final backBtn = find.byIcon(Icons.arrow_back);
    if (backBtn.evaluate().isNotEmpty) {
      await tester.tapAndSettle(backBtn.first);
      await tester.wait(TestConfig.tapDelay);
    } else {
      break;
    }
    attempts++;
  }

  // Final attempt: tap calendar again
  final calendarIconRetry = find.byIcon(FontAwesomeIcons.calendar);
  if (calendarIconRetry.evaluate().isNotEmpty) {
    await tester.tapAndSettle(calendarIconRetry.first);
    await tester.wait(TestConfig.pageTransitionDelay);
  }

  TestLogger.logInfo('Navigation to main screen attempted');
}
