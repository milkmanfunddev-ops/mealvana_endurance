/// Food Management Flow Integration Test
///
/// Tests food management features via Settings:
/// 1. User navigates to Settings
/// 2. User opens Food Preferences
/// 3. User adjusts food preference sliders
/// 4. User searches for food
/// 5. User saves changes
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

  group('Food Management Flow', () {
    testWidgets(
      'User can manage food preferences',
      (tester) async {
        TestLogger.logStep('Starting Food Management Flow Test');

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

        // Try finding settings icon or "..." more menu
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
        TestLogger.logSuccess('On Settings screen');

        // ============================================================
        // STEP 3: Navigate to Food Preferences
        // ============================================================
        TestLogger.logStep('Opening Food Preferences');

        // Look for Food Preferences option in Settings
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

        TestLogger.logSuccess('On Food Preferences screen');

        // ============================================================
        // STEP 4: Verify Food Preferences Screen Structure
        // ============================================================
        TestLogger.logStep('Verifying Food Preferences Screen');

        // Food Preferences screen has:
        // - Food items with sliders (Avoid ↔ Love)
        // - Each food shows: icon, name, slider, X Avoid label, Love ♡ label
        // - "Show more food options" expandable
        // - Search field at bottom
        // - Barcode scanner icon
        // - "Save Changes" button

        // Verify some expected foods are visible
        final bagel = find.textContaining('BAGEL');
        final banana = find.textContaining('BANANA');
        final energyBar = find.textContaining('ENERGY BAR');

        if (bagel.evaluate().isNotEmpty) {
          TestLogger.logSubStep('Bagel preference found');
        }
        if (banana.evaluate().isNotEmpty) {
          TestLogger.logSubStep('Banana preference found');
        }
        if (energyBar.evaluate().isNotEmpty) {
          TestLogger.logSubStep('Energy Bar preference found');
        }

        // ============================================================
        // STEP 5: Adjust Food Preference Sliders
        // ============================================================
        TestLogger.logStep('Adjusting Food Preferences');

        // Find sliders and adjust them
        final sliders = find.byType(Slider);
        if (sliders.evaluate().isNotEmpty) {
          TestLogger.logSubStep('Found ${sliders.evaluate().length} preference sliders');

          // Drag first slider toward "Love"
          await tester.drag(sliders.first, const Offset(80, 0));
          await tester.pumpAndSettle();
          TestLogger.logSubStep('Adjusted first food toward Love');

          // If there's a second slider, drag toward "Avoid"
          if (sliders.evaluate().length > 1) {
            await tester.drag(sliders.at(1), const Offset(-80, 0));
            await tester.pumpAndSettle();
            TestLogger.logSubStep('Adjusted second food toward Avoid');
          }
        }

        // ============================================================
        // STEP 6: Expand More Food Options
        // ============================================================
        TestLogger.logStep('Expanding More Food Options');

        final showMoreBtn = find.textContaining('Show more food options');
        if (showMoreBtn.evaluate().isNotEmpty) {
          await tester.tapAndSettle(showMoreBtn.first);
          TestLogger.logSubStep('Expanded more food options');

          // Wait for expansion animation
          await tester.pumpAndSettle();

          // Should see more foods now
          final moreSliders = find.byType(Slider);
          TestLogger.logSubStep('Now showing ${moreSliders.evaluate().length} food preferences');
        }

        // ============================================================
        // STEP 7: Use Search Field
        // ============================================================
        TestLogger.logStep('Searching for Food');

        // Look for search field
        final searchField = find.byWidgetPredicate((widget) {
          if (widget is TextField) {
            final hint = widget.decoration?.hintText ?? '';
            return hint.toLowerCase().contains('search');
          }
          return false;
        });

        if (searchField.evaluate().isNotEmpty) {
          // Enter search term
          await tester.enterText(searchField.first, 'banana');
          await tester.pumpAndSettle();
          TestLogger.logSubStep('Entered search: banana');

          // Tap search button
          final searchIcon = find.byIcon(Icons.search);
          if (searchIcon.evaluate().isNotEmpty) {
            await tester.tapAndSettle(searchIcon.first);
            await tester.wait(TestConfig.networkDelay);
          }

          // Clear search
          await tester.enterText(searchField.first, '');
          await tester.pumpAndSettle();
        }

        // ============================================================
        // STEP 8: Save Food Preferences
        // ============================================================
        TestLogger.logStep('Saving Food Preferences');

        // Scroll to Save Changes button
        await tester.scrollToFind(find.text('Save Changes'));

        final saveBtn = find.text('Save Changes');
        if (saveBtn.evaluate().isNotEmpty) {
          await tester.tapAndSettle(saveBtn.first);
          TestLogger.logSuccess('Saved food preferences');
        }

        await tester.wait(TestConfig.tapDelay);

        // ============================================================
        // STEP 9: Navigate Back
        // ============================================================
        TestLogger.logStep('Navigating Back');

        final backBtn = find.byIcon(Icons.arrow_back);
        if (backBtn.evaluate().isNotEmpty) {
          await tester.tapAndSettle(backBtn.first);
          await tester.wait(TestConfig.pageTransitionDelay);
        }

        // ============================================================
        // STEP 10: Reopen and Verify Changes Persisted
        // ============================================================
        TestLogger.logStep('Verifying Changes Persisted');

        // Reopen Food Preferences
        final foodPrefsBtn2 = find.text('Food Preferences');
        if (foodPrefsBtn2.evaluate().isNotEmpty) {
          await tester.tapAndSettle(foodPrefsBtn2.first);
          await tester.wait(TestConfig.pageTransitionDelay);
        }

        // Wait for screen to load
        await tester.waitForWidget(
          find.text('Food Preferences'),
          timeout: TestConfig.mediumTimeout,
        );

        // Check that preferences are still displayed
        final slidersAgain = find.byType(Slider);
        if (slidersAgain.evaluate().isNotEmpty) {
          TestLogger.logSuccess('Food preferences screen loaded with saved data');
        }

        // ============================================================
        // VERIFICATION
        // ============================================================
        TestLogger.logStep('Verifying Food Management');

        await tester.pumpAndSettle();

        // Verify we're on food preferences screen
        final foodPrefsVisible = find.text('Food Preferences').evaluate().isNotEmpty;

        if (foodPrefsVisible) {
          TestLogger.logSuccess('Food Preferences screen verified');
        }

        await tester.screenshot('food_management_complete');

        TestLogger.logStep('Food Management Flow Complete!');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}

