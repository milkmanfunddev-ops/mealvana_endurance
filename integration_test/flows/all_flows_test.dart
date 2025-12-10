/// All Flows Integration Test
///
/// Runs ALL test flows in a single app session for maximum efficiency.
/// This avoids rebuilding the app and re-onboarding for each test.
///
/// TEST PHASES:
/// 1. Settings Flow - Update profile, preferences
/// 2. Event Management Flow - Create, edit, delete events
/// 3. Food Management Flow - Search and manage food preferences
/// 4. Nutrition Plan Flow - Create activities and generate plans
/// 5. Food Manipulation Flow - Swap/add/delete foods, verify macro values
/// 6. Food Preferences Capture - Capture state before sync
/// 7. SYNC PERSISTENCE FLOW - Logout/login cycles to verify data sync
/// 8. Food Preferences Verification - Verify preferences weren't reset
///
/// FAIL-FAST BEHAVIOR:
/// - Any flow failure will capture a screenshot and stop the test
/// - Screenshots are saved to the test output directory
/// - Use TestLogger output to identify failure point
///
/// KNOWN BUGS TESTED:
/// - Macro numerator/denominator reset after food manipulation
/// - Food preferences reset to neutral after sync
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
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/test_config.dart';
import '../helpers/test_helpers.dart';
import '../helpers/onboarding_helper.dart';

// Import reusable flow modules
import 'shared/settings_flow.dart';
import 'shared/event_management_flow.dart';
import 'shared/nutrition_plan_flow.dart';
import 'shared/food_management_flow.dart';
import 'shared/food_manipulation_flow.dart';
import 'shared/food_preferences_verification_flow.dart';
import 'shared/sync_flow.dart';

void main() {
  // Initialize binding for screenshot capture
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('All Integration Flows', () {
    testWidgets(
      'Complete app test suite - all flows in one session',
      (tester) async {
        // Initialize screenshot helper with binding
        ScreenshotHelper.initBinding(binding);

        TestLogger.logStep('Starting Complete Integration Test Suite');
        TestLogger.logInfo('This runs ALL flows in a single app session');
        TestLogger.logInfo('Build once, onboard once, test everything!');
        TestLogger.logInfo('FAIL-FAST: Any failure will stop the test with screenshot');

        // ============================================================
        // APP LAUNCH & ONBOARDING (done once for all tests)
        // ============================================================
        TestLogger.logStep('Launching App');
        app.main();
        await tester.pumpAndSettle();
        await tester.wait(TestConfig.networkDelay);

        // Wait for initial screen with timeout - FAIL FAST if it takes too long
        TestLogger.logSubStep('Waiting for initial screen (max 60s)...');
        final startTime = DateTime.now();
        const maxWaitTime = Duration(seconds: 60);
        bool initialScreenFound = false;

        while (DateTime.now().difference(startTime) < maxWaitTime) {
          await tester.pump(const Duration(milliseconds: 500));

          // Check for any of these indicators that app has loaded:
          // 1. Welcome screen (needs onboarding)
          // 2. FloatingActionButtonsBar icons (already logged in) - calendar, ellipsis, plus
          // 3. Fallback: BottomNavigationBar (legacy)
          final hasGetStarted = find.text('Get Started').evaluate().isNotEmpty;
          final hasCalendarIcon =
              find.byIcon(FontAwesomeIcons.calendar).evaluate().isNotEmpty;
          final hasEllipsisIcon =
              find.byIcon(FontAwesomeIcons.ellipsis).evaluate().isNotEmpty;
          final hasPlusIcon =
              find.byIcon(FontAwesomeIcons.plus).evaluate().isNotEmpty;
          final hasBottomNav =
              find.byType(BottomNavigationBar).evaluate().isNotEmpty;

          if (hasGetStarted || hasCalendarIcon || hasEllipsisIcon || hasPlusIcon || hasBottomNav) {
            initialScreenFound = true;
            TestLogger.logSubStep(
              'Initial screen found: '
              'GetStarted=$hasGetStarted, Calendar=$hasCalendarIcon, '
              'Ellipsis=$hasEllipsisIcon, Plus=$hasPlusIcon, BottomNav=$hasBottomNav',
            );
            break;
          }

          // Log progress every 10 seconds
          if (DateTime.now().difference(startTime).inSeconds % 10 == 0 &&
              DateTime.now().difference(startTime).inSeconds > 0) {
            TestLogger.logSubStep(
              'Still waiting for app to load... '
              '(${DateTime.now().difference(startTime).inSeconds}s elapsed)',
            );
          }
        }

        // FAIL FAST if initial screen not found
        if (!initialScreenFound) {
          await tester.screenshot('FAIL_initial_screen_timeout');
          throw TestFailure(
            'TIMEOUT: App did not load initial screen within ${maxWaitTime.inSeconds} seconds. '
            'This may be due to:\n'
            '- iOS notification permission dialog blocking the app\n'
            '- App crash during startup\n'
            '- Network connectivity issues\n'
            'Please check the simulator for any system dialogs.',
          );
        }

        await tester.pumpAndSettle();

        // Check if we're already logged in (no onboarding needed)
        // The app uses FloatingActionButtonsBar (custom), not BottomNavigationBar
        final isAlreadyLoggedIn =
            find.byIcon(FontAwesomeIcons.calendar).evaluate().isNotEmpty ||
            find.byIcon(FontAwesomeIcons.ellipsis).evaluate().isNotEmpty ||
            find.byIcon(FontAwesomeIcons.plus).evaluate().isNotEmpty ||
            find.byType(BottomNavigationBar).evaluate().isNotEmpty;

        if (isAlreadyLoggedIn) {
          TestLogger.logSubStep('Already logged in - signing out for clean test state...');
          await _signOutFromApp(tester);

          // After sign out, we should see the welcome screen
          final welcomeScreenFound = await tester.waitForWidget(
            find.text('Get Started'),
            timeout: TestConfig.mediumTimeout,
          );

          if (!welcomeScreenFound) {
            await tester.screenshot('FAIL_sign_out_not_showing_welcome');
            throw TestFailure(
              'After signing out, expected to see Get Started button but did not. '
              'The app may not have returned to the welcome screen.',
            );
          }
        }

        // Handle onboarding
        if (find.text('Get Started').evaluate().isNotEmpty) {
          TestLogger.logSubStep('Completing onboarding (one time)...');
          await skipOnboarding(tester);
        }

        // Wait for main app - look for navigation elements
        // The app uses a custom bottom navigation, not BottomNavigationBar
        // Look for: calendar icon, settings icon, or the orange FAB (plus button)
        TestLogger.logSubStep('Waiting for main app navigation...');
        await tester.pumpAndSettle();
        await tester.wait(TestConfig.networkDelay);

        bool mainAppReady = false;
        final endTime = DateTime.now().add(TestConfig.longTimeout);

        while (DateTime.now().isBefore(endTime) && !mainAppReady) {
          await tester.pump(const Duration(milliseconds: 500));

          // Check for various main app indicators
          // The app uses FloatingActionButtonsBar with these FontAwesome icons:
          // - calendar: Activities tab
          // - clipboardList: Survey tab
          // - ellipsis: Settings/Menu tab
          // - plus: Add new activity (orange button)
          final hasCalendarIcon =
              find.byIcon(FontAwesomeIcons.calendar).evaluate().isNotEmpty;
          final hasEllipsisIcon =
              find.byIcon(FontAwesomeIcons.ellipsis).evaluate().isNotEmpty;
          final hasPlusIcon =
              find.byIcon(FontAwesomeIcons.plus).evaluate().isNotEmpty;
          final hasClipboardIcon =
              find.byIcon(FontAwesomeIcons.clipboardList).evaluate().isNotEmpty;
          final hasUpcomingEvents =
              find.text('Upcoming Events').evaluate().isNotEmpty;
          final hasByWeek = find.text('BY WEEK').evaluate().isNotEmpty;
          final hasBottomNav =
              find.byType(BottomNavigationBar).evaluate().isNotEmpty;

          mainAppReady = hasCalendarIcon ||
              hasEllipsisIcon ||
              hasPlusIcon ||
              hasClipboardIcon ||
              hasUpcomingEvents ||
              hasByWeek ||
              hasBottomNav;

          if (mainAppReady) {
            TestLogger.logSubStep(
              'Main app detected: Calendar=$hasCalendarIcon, Ellipsis=$hasEllipsisIcon, '
              'Plus=$hasPlusIcon, Clipboard=$hasClipboardIcon, Events=$hasUpcomingEvents, Week=$hasByWeek',
            );
          }
        }

        if (!mainAppReady) {
          await tester.screenshot('FAIL_main_app_not_ready');
          throw TestFailure(
            'Main app did not load within ${TestConfig.longTimeout.inSeconds} seconds. '
            'Could not find calendar icon, settings, FAB, or main screen text.',
          );
        }

        await tester.pumpAndSettle();

        TestLogger.logSuccess('App ready - starting test flows');
        await tester.screenshot('app_ready');

        // ============================================================
        // FLOW 1: Settings (FAIL-FAST)
        // ============================================================
        await ScreenshotHelper.withScreenshotOnFailure(
          tester,
          'settings_flow',
          () async {
            await runSettingsFlow(tester);
            TestLogger.logSuccess('Settings Flow: PASSED');
          },
        );

        // Return to main screen (ensure clean state for next flow)
        await _ensureOnMainScreen(tester);

        // ============================================================
        // FLOW 2: Event Management (FAIL-FAST)
        // ============================================================
        await ScreenshotHelper.withScreenshotOnFailure(
          tester,
          'event_management_flow',
          () async {
            await runEventManagementFlow(tester);
            TestLogger.logSuccess('Event Management Flow: PASSED');
          },
        );

        await _ensureOnMainScreen(tester);

        // ============================================================
        // FLOW 3: Food Management (FAIL-FAST)
        // ============================================================
        await ScreenshotHelper.withScreenshotOnFailure(
          tester,
          'food_management_flow',
          () async {
            await runFoodManagementFlow(tester);
            TestLogger.logSuccess('Food Management Flow: PASSED');
          },
        );

        await _ensureOnMainScreen(tester);

        // ============================================================
        // FLOW 4: Nutrition Plan (FAIL-FAST)
        // ============================================================
        await ScreenshotHelper.withScreenshotOnFailure(
          tester,
          'nutrition_plan_flow',
          () async {
            await runNutritionPlanFlow(tester);
            TestLogger.logSuccess('Nutrition Plan Flow: PASSED');
          },
        );

        await _ensureOnMainScreen(tester);

        // ============================================================
        // FLOW 5: Food Manipulation (FAIL-FAST)
        // Tests swap/add/delete food and verifies macro values
        // This tests the known bug where numerator/denominator reset
        // ============================================================
        await ScreenshotHelper.withScreenshotOnFailure(
          tester,
          'food_manipulation_flow',
          () async {
            await runFoodManipulationFlow(tester);
            TestLogger.logSuccess('Food Manipulation Flow: PASSED');
          },
        );

        await _ensureOnMainScreen(tester);

        // ============================================================
        // FLOW 6: Capture Food Preferences State (Before Sync)
        // Store the current preference state to verify after sync
        // ============================================================
        FoodPreferencesState? preSyncPreferences;
        await ScreenshotHelper.withScreenshotOnFailure(
          tester,
          'food_preferences_capture',
          () async {
            preSyncPreferences = await runFoodPreferencesVerificationFlow(
              tester,
              modifyPreferences: true, // Modify at least one to test persistence
            );
            TestLogger.logSuccess('Food Preferences Capture: PASSED');
            TestLogger.logData(
              'Pre-sync non-neutral preferences',
              preSyncPreferences?.nonNeutralCount ?? 0,
            );
          },
        );

        await _ensureOnMainScreen(tester);

        // ============================================================
        // FLOW 7: SYNC PERSISTENCE (FAIL-FAST)
        // This is the critical test that verifies data persists
        // across logout/login cycles
        // ============================================================
        await ScreenshotHelper.withScreenshotOnFailure(
          tester,
          'sync_persistence_flow',
          () async {
            await runSyncPersistenceFlow(tester);
            TestLogger.logSuccess('Sync Persistence Flow: PASSED');
          },
        );

        await _ensureOnMainScreen(tester);

        // ============================================================
        // FLOW 8: Verify Food Preferences After Sync (FAIL-FAST)
        // This tests the known bug where preferences reset to neutral
        // ============================================================
        await ScreenshotHelper.withScreenshotOnFailure(
          tester,
          'food_preferences_verification',
          () async {
            if (preSyncPreferences != null) {
              await verifyPreferencesAfterSync(tester, preSyncPreferences!);
              TestLogger.logSuccess('Food Preferences Verification: PASSED');
            } else {
              TestLogger.logInfo(
                'Skipping preferences verification - no pre-sync state captured',
              );
            }
          },
        );

        // ============================================================
        // SUMMARY
        // ============================================================
        TestLogger.logStep('All Integration Tests Complete!');
        TestLogger.logSuccess('All 8 flows passed successfully:');
        TestLogger.logSuccess('  1. Settings Flow');
        TestLogger.logSuccess('  2. Event Management Flow');
        TestLogger.logSuccess('  3. Food Management Flow');
        TestLogger.logSuccess('  4. Nutrition Plan Flow');
        TestLogger.logSuccess('  5. Food Manipulation Flow (macro verification)');
        TestLogger.logSuccess('  6. Food Preferences Capture');
        TestLogger.logSuccess('  7. Sync Persistence Flow');
        TestLogger.logSuccess('  8. Food Preferences Verification');
        await tester.screenshot('all_flows_complete');
      },
      // Increased timeout to accommodate all flows including sync
      timeout: const Timeout(Duration(minutes: 35)),
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

/// Helper to sign out from the app when already logged in
/// This ensures a clean test state by starting from the welcome screen
Future<void> _signOutFromApp(WidgetTester tester) async {
  TestLogger.logSubStep('Navigating to settings to sign out...');

  // The app uses FloatingActionButtonsBar with FontAwesomeIcons.ellipsis for settings/menu
  // Try to find and tap the ellipsis (menu) icon which goes to Settings
  final menuIcon = find.byIcon(FontAwesomeIcons.ellipsis);
  if (menuIcon.evaluate().isNotEmpty) {
    TestLogger.logSubStep('Found menu icon (ellipsis), tapping...');
    await tester.tapAndSettle(menuIcon.first);
    await tester.wait(TestConfig.pageTransitionDelay);
  } else {
    // Fallback: try Icons.settings or the legacy BottomNavigationBar
    final settingsIcon = find.byIcon(Icons.settings);
    if (settingsIcon.evaluate().isNotEmpty) {
      await tester.tapAndSettle(settingsIcon.first);
      await tester.wait(TestConfig.pageTransitionDelay);
    }
  }

  // Look for Sign Out button on settings screen
  final signOutButton = find.text('Sign Out');
  if (signOutButton.evaluate().isEmpty) {
    // May need to scroll to find it
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      // Scroll down to find sign out button
      for (var i = 0; i < 5; i++) {
        await tester.drag(scrollable.first, const Offset(0, -200));
        await tester.pumpAndSettle();
        if (find.text('Sign Out').evaluate().isNotEmpty) break;
      }
    }
  }

  // Tap Sign Out
  final signOutFinal = find.text('Sign Out');
  if (signOutFinal.evaluate().isNotEmpty) {
    TestLogger.logSubStep('Tapping Sign Out...');
    await tester.tapAndSettle(signOutFinal.first);
    await tester.wait(TestConfig.pageTransitionDelay);

    // Handle confirmation dialog if present
    final confirmButton = find.text('Sign Out');
    if (confirmButton.evaluate().length > 1) {
      // There's a confirmation dialog
      await tester.tapAndSettle(confirmButton.last);
      await tester.wait(TestConfig.pageTransitionDelay);
    }
  } else {
    TestLogger.logInfo('Sign Out button not found - may already be signed out');
    // Try signing out via Supabase directly as fallback
    try {
      await Supabase.instance.client.auth.signOut();
      TestLogger.logSubStep('Signed out via Supabase client');
    } catch (e) {
      TestLogger.logInfo('Supabase signout failed: $e');
    }
  }

  // Wait for welcome screen to appear
  await tester.wait(TestConfig.networkDelay);
  TestLogger.logSubStep('Sign out complete');
}
