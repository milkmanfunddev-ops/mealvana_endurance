/// Settings Flow - Reusable Test Module
///
/// Can be run standalone or as part of all_flows_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../helpers/test_config.dart';
import '../../helpers/test_helpers.dart';

/// Run the settings flow test
///
/// Assumes app is already launched and user is on main screen.
Future<void> runSettingsFlow(WidgetTester tester) async {
  TestLogger.logStep('Starting Settings Flow');

  // ============================================================
  // STEP 1: Navigate to Settings
  // ============================================================
  TestLogger.logStep('Navigating to Settings');

  // Settings is accessed via the "..." (ellipsis) button in bottom nav
  // The FloatingActionButtonsBar uses FontAwesomeIcons.ellipsis
  final ellipsisIcon = find.byIcon(FontAwesomeIcons.ellipsis);
  if (ellipsisIcon.evaluate().isNotEmpty) {
    TestLogger.logSubStep('Found ellipsis icon, tapping to go to Settings...');
    await tester.tapAndSettle(ellipsisIcon.first);
  } else {
    // Fallback: try Material Icons
    final moreIcon = find.byIcon(Icons.more_horiz);
    if (moreIcon.evaluate().isNotEmpty) {
      await tester.tapAndSettle(moreIcon.first);
    } else {
      // Try direct settings icon
      final settingsIcon = find.byIcon(Icons.settings);
      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tapAndSettle(settingsIcon.first);
      }
    }
  }

  await tester.pumpAndSettle();

  // Verify we're on Settings screen
  final settingsFound = await tester.waitForWidget(
    find.text('Settings'),
    timeout: TestConfig.mediumTimeout,
  );

  if (settingsFound) {
    TestLogger.logSuccess('On Settings screen');
  }

  // ============================================================
  // STEP 2: Verify Settings Screen Structure
  // ============================================================
  TestLogger.logStep('Verifying Settings Screen');

  final accountSection = find.text('ACCOUNT');
  if (accountSection.evaluate().isNotEmpty) {
    TestLogger.logSubStep('Account section found');
  }

  final profilePrefs = find.text('Profile & Preferences');
  if (profilePrefs.evaluate().isNotEmpty) {
    TestLogger.logSubStep('Profile & Preferences found');
  }

  final foodPrefs = find.text('Food Preferences');
  if (foodPrefs.evaluate().isNotEmpty) {
    TestLogger.logSubStep('Food Preferences found');
  }

  // ============================================================
  // STEP 3: Open Profile & Preferences
  // ============================================================
  TestLogger.logStep('Opening Profile & Preferences');

  final profilePrefsBtn = find.text('Profile & Preferences');
  if (profilePrefsBtn.evaluate().isNotEmpty) {
    await tester.tapAndSettle(profilePrefsBtn.first);
  }

  await tester.wait(TestConfig.pageTransitionDelay);

  await tester.waitForWidget(
    find.text('Preferences'),
    timeout: TestConfig.mediumTimeout,
  );

  TestLogger.logSuccess('Opened Preferences screen');

  // ============================================================
  // STEP 4: Update Profile
  // ============================================================
  TestLogger.logStep('Updating Profile');

  // Toggle gender
  final femaleBtn = find.text('Female');
  if (femaleBtn.evaluate().isNotEmpty) {
    await tester.tapAndSettle(femaleBtn.first);
    TestLogger.logSubStep('Tapped Female gender');
    await tester.pumpAndSettle();

    final maleBtn = find.text('Male');
    if (maleBtn.evaluate().isNotEmpty) {
      await tester.tapAndSettle(maleBtn.first);
      TestLogger.logSubStep('Tapped Male gender');
    }
  }

  // Toggle water bottle checkbox
  final waterBottleCheckbox = find.text('I run with a water bottle');
  if (waterBottleCheckbox.evaluate().isNotEmpty) {
    await tester.tapAndSettle(waterBottleCheckbox.first);
    TestLogger.logSubStep('Toggled water bottle checkbox');
  }

  await tester.pumpAndSettle();

  // ============================================================
  // STEP 5: Save Profile Changes
  // ============================================================
  TestLogger.logStep('Saving Profile Changes');

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
  }

  // ============================================================
  // STEP 6: Return to Main Screen
  // ============================================================
  TestLogger.logStep('Returning to Main Screen');

  // Navigate back from settings to main screen
  final backBtn2 = find.byIcon(Icons.arrow_back);
  if (backBtn2.evaluate().isNotEmpty) {
    await tester.tapAndSettle(backBtn2.first);
    await tester.wait(TestConfig.pageTransitionDelay);
  }

  await tester.screenshot('settings_complete');
  TestLogger.logStep('Settings Flow Complete!');
}
