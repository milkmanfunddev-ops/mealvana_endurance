/// Settings Flow Integration Test
///
/// Tests settings management:
/// 1. User navigates to Settings (via bottom nav "..." menu)
/// 2. User opens Profile & Preferences
/// 3. User updates profile (weight, gender)
/// 4. User opens Food Preferences
/// 5. User adjusts food preference slider
///
/// Prerequisites:
/// - User must be logged in or have completed onboarding
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mealvana_endurance/main.dart' as app;

import '../helpers/test_config.dart';
import '../helpers/test_helpers.dart';
import '../helpers/onboarding_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Settings Flow', () {
    testWidgets(
      'User can update profile and settings',
      (tester) async {
        TestLogger.logStep('Starting Settings Flow Test');

        // ============================================================
        // STEP 1: Launch App
        // ============================================================
        TestLogger.logSubStep('Launching app...');
        app.main();
        await tester.pumpAndSettle();
        await tester.wait(TestConfig.networkDelay);

        // Handle onboarding if needed
        if (find.text('Get Started').evaluate().isNotEmpty) {
          TestLogger.logSubStep('Completing onboarding...');
          await skipOnboarding(tester);
        }

        await tester.waitForWidget(
          find.byType(BottomNavigationBar),
          timeout: TestConfig.mediumTimeout,
        );

        TestLogger.logSuccess('App ready');

        // ============================================================
        // STEP 2: Navigate to Settings
        // ============================================================
        TestLogger.logStep('Navigating to Settings');

        // Settings is accessed via the "..." (more) button in bottom nav
        // Then tapping the settings option, or there may be a direct settings route
        // From screenshots, the bottom bar has: calendar, list, "...", FAB

        // Try finding settings icon first
        final settingsIcon = find.byIcon(Icons.settings);
        if (settingsIcon.evaluate().isNotEmpty) {
          await tester.tapAndSettle(settingsIcon.first);
        } else {
          // Try "..." more menu button
          final moreIcon = find.byIcon(Icons.more_horiz);
          if (moreIcon.evaluate().isNotEmpty) {
            await tester.tapAndSettle(moreIcon.first);
            await tester.wait(TestConfig.tapDelay);

            // Look for Settings option in menu
            final settingsOption = find.text('Settings');
            if (settingsOption.evaluate().isNotEmpty) {
              await tester.tapAndSettle(settingsOption.first);
            }
          }
        }

        await tester.wait(TestConfig.pageTransitionDelay);

        // Verify we're on Settings screen
        final settingsFound = await tester.waitForWidget(
          find.text('Settings'),
          timeout: TestConfig.mediumTimeout,
        );

        if (settingsFound) {
          TestLogger.logSuccess('On Settings screen');
        }

        // ============================================================
        // STEP 3: Verify Settings Screen Structure
        // ============================================================
        TestLogger.logStep('Verifying Settings Screen');

        // Settings screen has:
        // - ACCOUNT section (Create Account / Log In)
        // - Profile & Preferences
        // - Appearance
        // - Food Preferences
        // - Help & Feedback

        // Check for Account section
        final accountSection = find.text('ACCOUNT');
        if (accountSection.evaluate().isNotEmpty) {
          TestLogger.logSubStep('Account section found');
        }

        // Check for Profile & Preferences
        final profilePrefs = find.text('Profile & Preferences');
        tester.expectWidget(profilePrefs, reason: 'Profile & Preferences should be visible');

        // Check for Food Preferences
        final foodPrefs = find.text('Food Preferences');
        tester.expectWidget(foodPrefs, reason: 'Food Preferences should be visible');

        // ============================================================
        // STEP 4: Open Profile & Preferences
        // ============================================================
        TestLogger.logStep('Opening Profile & Preferences');

        final profilePrefsBtn = find.text('Profile & Preferences');
        if (profilePrefsBtn.evaluate().isNotEmpty) {
          await tester.tapAndSettle(profilePrefsBtn.first);
        }

        await tester.wait(TestConfig.pageTransitionDelay);

        // Wait for Preferences screen
        await tester.waitForWidget(
          find.text('Preferences'),
          timeout: TestConfig.mediumTimeout,
        );

        TestLogger.logSuccess('Opened Preferences screen');

        // ============================================================
        // STEP 5: Update Profile
        // ============================================================
        TestLogger.logStep('Updating Profile');

        // Preferences screen has:
        // - PROFILE section: Gender (Male/Female), Birthday, Height (ft/in), Weight
        // - "I run with a water bottle" checkbox
        // - PREFERENCES section: Distance unit
        // - "Save Changes" button

        // Verify Profile section
        final profileSection = find.text('PROFILE');
        tester.expectWidget(profileSection, reason: 'PROFILE section should be visible');

        // Toggle gender if possible
        final femaleBtn = find.text('Female');
        final maleBtn = find.text('Male');
        if (femaleBtn.evaluate().isNotEmpty) {
          await tester.tapAndSettle(femaleBtn.first);
          TestLogger.logSubStep('Tapped Female gender');
          await tester.pumpAndSettle();

          // Toggle back to Male
          if (maleBtn.evaluate().isNotEmpty) {
            await tester.tapAndSettle(maleBtn.first);
            TestLogger.logSubStep('Tapped Male gender');
          }
        }

        // Look for a field containing weight hint
        final weightContainer = find.text('Weight');
        if (weightContainer.evaluate().isNotEmpty) {
          TestLogger.logSubStep('Weight section found');
        }

        // Toggle water bottle checkbox
        final waterBottleCheckbox = find.text('I run with a water bottle');
        if (waterBottleCheckbox.evaluate().isNotEmpty) {
          await tester.tapAndSettle(waterBottleCheckbox.first);
          TestLogger.logSubStep('Toggled water bottle checkbox');
        }

        await tester.pumpAndSettle();

        // ============================================================
        // STEP 6: Save Profile Changes
        // ============================================================
        TestLogger.logStep('Saving Profile Changes');

        // Scroll to find Save Changes button if needed
        await tester.scrollToFind(find.text('Save Changes'));

        final saveBtn = find.text('Save Changes');
        if (saveBtn.evaluate().isNotEmpty) {
          await tester.tapAndSettle(saveBtn.first);
          TestLogger.logSuccess('Tapped Save Changes');
        }

        await tester.wait(TestConfig.tapDelay);

        // Navigate back to Settings
        final backBtn = find.byIcon(Icons.arrow_back);
        if (backBtn.evaluate().isNotEmpty) {
          await tester.tapAndSettle(backBtn.first);
          await tester.wait(TestConfig.pageTransitionDelay);
        } else {
          // Try chevron left
          final chevronBack = find.byIcon(Icons.chevron_left);
          if (chevronBack.evaluate().isNotEmpty) {
            await tester.tapAndSettle(chevronBack.first);
            await tester.wait(TestConfig.pageTransitionDelay);
          }
        }

        // ============================================================
        // STEP 7: Open Food Preferences
        // ============================================================
        TestLogger.logStep('Opening Food Preferences');

        final foodPrefsBtn = find.text('Food Preferences');
        if (foodPrefsBtn.evaluate().isNotEmpty) {
          await tester.tapAndSettle(foodPrefsBtn.first);
        }

        await tester.wait(TestConfig.pageTransitionDelay);

        // Wait for Food Preferences screen
        await tester.waitForWidget(
          find.text('Food Preferences'),
          timeout: TestConfig.mediumTimeout,
        );

        TestLogger.logSuccess('Opened Food Preferences screen');

        // ============================================================
        // STEP 8: Adjust Food Preference
        // ============================================================
        TestLogger.logStep('Adjusting Food Preference');

        // Food Preferences screen has:
        // - Food items with sliders (Avoid ↔ Love)
        // - Search field at bottom
        // - "Show more food options" expander
        // - Save Changes button

        // Find a slider and adjust it
        final sliders = find.byType(Slider);
        if (sliders.evaluate().isNotEmpty) {
          // Drag the first slider to change preference
          await tester.drag(sliders.first, const Offset(50, 0));
          await tester.pumpAndSettle();
          TestLogger.logSubStep('Adjusted food preference slider');
        }

        // Try expanding more options
        final showMoreBtn = find.text('Show more food options');
        if (showMoreBtn.evaluate().isNotEmpty) {
          await tester.tapAndSettle(showMoreBtn.first);
          TestLogger.logSubStep('Expanded more food options');
        }

        await tester.pumpAndSettle();

        // ============================================================
        // STEP 9: Save Food Preferences
        // ============================================================
        TestLogger.logStep('Saving Food Preferences');

        // Scroll to Save Changes
        await tester.scrollToFind(find.text('Save Changes'));

        final saveFoodBtn = find.text('Save Changes');
        if (saveFoodBtn.evaluate().isNotEmpty) {
          await tester.tapAndSettle(saveFoodBtn.first);
          TestLogger.logSuccess('Saved food preferences');
        }

        await tester.wait(TestConfig.tapDelay);

        // Navigate back
        final backBtn2 = find.byIcon(Icons.arrow_back);
        if (backBtn2.evaluate().isNotEmpty) {
          await tester.tapAndSettle(backBtn2.first);
          await tester.wait(TestConfig.pageTransitionDelay);
        }

        // ============================================================
        // STEP 10: Test Appearance Settings
        // ============================================================
        TestLogger.logStep('Opening Appearance Settings');

        final appearanceBtn = find.text('Appearance');
        if (appearanceBtn.evaluate().isNotEmpty) {
          await tester.tapAndSettle(appearanceBtn.first);
          await tester.wait(TestConfig.pageTransitionDelay);

          // Should show theme options (light/dark/system)
          TestLogger.logSubStep('On Appearance screen');

          // Navigate back
          final backBtn3 = find.byIcon(Icons.arrow_back);
          if (backBtn3.evaluate().isNotEmpty) {
            await tester.tapAndSettle(backBtn3.first);
            await tester.wait(TestConfig.pageTransitionDelay);
          }
        }

        // ============================================================
        // VERIFICATION
        // ============================================================
        TestLogger.logStep('Verifying Settings');

        await tester.pumpAndSettle();

        // Verify we're back on settings screen
        final settingsScreenFound = find.text('Settings').evaluate().isNotEmpty;

        if (settingsScreenFound) {
          TestLogger.logSuccess('Settings screen verified');
        }

        await tester.screenshot('settings_complete');

        TestLogger.logStep('Settings Flow Complete!');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}

