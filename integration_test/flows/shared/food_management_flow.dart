/// Food Management Flow - Reusable Test Module
///
/// Can be run standalone or as part of all_flows_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../helpers/test_config.dart';
import '../../helpers/test_helpers.dart';

/// Run the food management flow test
///
/// Assumes app is already launched and user is on main screen.
Future<void> runFoodManagementFlow(WidgetTester tester) async {
  TestLogger.logStep('Starting Food Management Flow');

  // ============================================================
  // STEP 1: Navigate to Settings
  // ============================================================
  TestLogger.logStep('Navigating to Settings');

  // Settings is accessed via the "..." (ellipsis) button in bottom nav
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
      final settingsIcon = find.byIcon(Icons.settings);
      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tapAndSettle(settingsIcon.first);
      }
    }
  }

  await tester.pumpAndSettle();
  TestLogger.logSuccess('On Settings screen');

  // ============================================================
  // STEP 2: Navigate to Food Preferences
  // ============================================================
  TestLogger.logStep('Opening Food Preferences');

  final foodPrefsBtn = find.text('Food Preferences');
  if (foodPrefsBtn.evaluate().isNotEmpty) {
    await tester.tapAndSettle(foodPrefsBtn.first);
  }

  await tester.wait(TestConfig.pageTransitionDelay);

  await tester.waitForWidget(
    find.text('Food Preferences'),
    timeout: TestConfig.mediumTimeout,
  );

  TestLogger.logSuccess('On Food Preferences screen');

  // ============================================================
  // STEP 3: Verify Food Preferences Screen Structure
  // ============================================================
  TestLogger.logStep('Verifying Food Preferences Screen');

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
  // STEP 4: Adjust Food Preference Sliders
  // ============================================================
  TestLogger.logStep('Adjusting Food Preferences');

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
  // STEP 5: Expand More Food Options
  // ============================================================
  TestLogger.logStep('Expanding More Food Options');

  final showMoreBtn = find.textContaining('Show more food options');
  if (showMoreBtn.evaluate().isNotEmpty) {
    await tester.tapAndSettle(showMoreBtn.first);
    TestLogger.logSubStep('Expanded more food options');

    await tester.pumpAndSettle();

    final moreSliders = find.byType(Slider);
    TestLogger.logSubStep('Now showing ${moreSliders.evaluate().length} food preferences');
  }

  // ============================================================
  // STEP 6: Use Search Field
  // ============================================================
  TestLogger.logStep('Searching for Food');

  final searchField = find.byWidgetPredicate((widget) {
    if (widget is TextField) {
      final hint = widget.decoration?.hintText ?? '';
      return hint.toLowerCase().contains('search');
    }
    return false;
  });

  if (searchField.evaluate().isNotEmpty) {
    await tester.enterText(searchField.first, 'banana');
    await tester.pumpAndSettle();
    TestLogger.logSubStep('Entered search: banana');

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
  // STEP 7: Save Food Preferences
  // ============================================================
  TestLogger.logStep('Saving Food Preferences');

  await tester.scrollToFind(find.text('Save Changes'));

  final saveBtn = find.text('Save Changes');
  if (saveBtn.evaluate().isNotEmpty) {
    await tester.tapAndSettle(saveBtn.first);
    TestLogger.logSuccess('Saved food preferences');
  }

  await tester.wait(TestConfig.tapDelay);

  // ============================================================
  // STEP 8: Navigate Back to Main Screen
  // ============================================================
  TestLogger.logStep('Navigating Back');

  // Back to Settings
  var backBtn = find.byIcon(Icons.arrow_back);
  if (backBtn.evaluate().isNotEmpty) {
    await tester.tapAndSettle(backBtn.first);
    await tester.wait(TestConfig.pageTransitionDelay);
  }

  // Back to Main
  backBtn = find.byIcon(Icons.arrow_back);
  if (backBtn.evaluate().isNotEmpty) {
    await tester.tapAndSettle(backBtn.first);
    await tester.wait(TestConfig.pageTransitionDelay);
  }

  await tester.screenshot('food_management_complete');
  TestLogger.logStep('Food Management Flow Complete!');
}
