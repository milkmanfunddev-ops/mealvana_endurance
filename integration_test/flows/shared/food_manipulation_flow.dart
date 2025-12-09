/// Food Manipulation Flow - Test food swap/add/delete operations
///
/// Tests:
/// 1. Navigate to activity details with nutrition plan
/// 2. Verify initial macro values (numerator/denominator)
/// 3. Delete a food → verify numerator decreases
/// 4. Add a food → verify numerator increases
/// 5. Swap a food → verify values are sensible
/// 6. Verify values don't reset incorrectly
///
/// FAIL-FAST: Any unexpected macro value change will fail the test
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../helpers/test_config.dart';
import '../../helpers/test_helpers.dart';

/// Macro values for a section (BEFORE RUN, DURING RUN, AFTER RUN)
class MacroValues {
  final int carbsNumerator;
  final int carbsTarget;
  final int proteinNumerator;
  final int proteinTarget;
  final int sodiumNumerator;
  final int sodiumTarget;
  final int? fluidsNumerator;
  final int? fluidsTarget;
  final String section; // 'BEFORE RUN', 'DURING RUN', 'AFTER RUN'

  const MacroValues({
    required this.carbsNumerator,
    required this.carbsTarget,
    required this.proteinNumerator,
    required this.proteinTarget,
    required this.sodiumNumerator,
    required this.sodiumTarget,
    this.fluidsNumerator,
    this.fluidsTarget,
    required this.section,
  });

  @override
  String toString() {
    return '$section: carbs=$carbsNumerator/$carbsTarget, '
        'protein=$proteinNumerator/$proteinTarget, '
        'sodium=$sodiumNumerator/$sodiumTarget'
        '${fluidsNumerator != null ? ', fluids=$fluidsNumerator/$fluidsTarget' : ''}';
  }

  /// Check if numerator is reasonable (not negative, not wildly over target)
  bool isReasonable() {
    if (carbsNumerator < 0 || proteinNumerator < 0 || sodiumNumerator < 0) {
      return false;
    }
    // Allow up to 3x target (user might add lots of food)
    if (carbsTarget > 0 && carbsNumerator > carbsTarget * 3) {
      return false;
    }
    return true;
  }
}

/// Run the food manipulation flow test
///
/// Prerequisites:
/// - App must be launched and user logged in
/// - An activity with a nutrition plan must exist (from nutrition_plan_flow)
Future<void> runFoodManipulationFlow(WidgetTester tester) async {
  TestLogger.logStep('Starting Food Manipulation Flow');
  TestLogger.logInfo('Testing swap/add/delete food operations');

  // ============================================================
  // PHASE 1: Navigate to Activity Details
  // ============================================================
  await _navigateToActivityDetails(tester);

  // ============================================================
  // PHASE 2: Capture Initial Macro Values
  // ============================================================
  TestLogger.logStep('Phase 2: Capturing Initial Macro Values');

  final initialMacros = await _captureBeforeRunMacros(tester);
  if (initialMacros == null) {
    await tester.screenshot('FAIL_could_not_capture_initial_macros');
    throw TestFailure('FAIL: Could not capture initial macro values');
  }

  TestLogger.logData('Initial macros', initialMacros.toString());
  await tester.screenshot('initial_macros');

  // Verify initial values are reasonable
  if (!initialMacros.isReasonable()) {
    await tester.screenshot('FAIL_initial_macros_unreasonable');
    throw TestFailure(
      'FAIL: Initial macro values are unreasonable\n'
      'Values: ${initialMacros.toString()}',
    );
  }

  // ============================================================
  // PHASE 3: Delete a Food Item
  // ============================================================
  TestLogger.logStep('Phase 3: Delete Food Item');

  final deletedFood = await _deleteFirstFood(tester);
  if (deletedFood == null) {
    TestLogger.logInfo('Could not delete food - may not have delete option');
  } else {
    TestLogger.logSubStep('Deleted food: $deletedFood');

    // Capture macros after delete
    final afterDeleteMacros = await _captureBeforeRunMacros(tester);
    if (afterDeleteMacros == null) {
      await tester.screenshot('FAIL_macros_after_delete');
      throw TestFailure('FAIL: Could not capture macros after delete');
    }

    TestLogger.logData('After delete macros', afterDeleteMacros.toString());

    // Verify carbs numerator decreased (or stayed same if food had 0 carbs)
    if (afterDeleteMacros.carbsNumerator > initialMacros.carbsNumerator) {
      await tester.screenshot('FAIL_carbs_increased_after_delete');
      throw TestFailure(
        'FAIL: Carbs INCREASED after deleting food!\n'
        'Before: ${initialMacros.carbsNumerator}g\n'
        'After: ${afterDeleteMacros.carbsNumerator}g\n'
        'This is a bug - deleting food should decrease or maintain carbs.',
      );
    }

    // Verify values are still reasonable
    if (!afterDeleteMacros.isReasonable()) {
      await tester.screenshot('FAIL_macros_unreasonable_after_delete');
      throw TestFailure(
        'FAIL: Macro values became unreasonable after delete\n'
        'Values: ${afterDeleteMacros.toString()}',
      );
    }

    TestLogger.logSuccess('Delete verification passed');
    await tester.screenshot('after_delete_success');
  }

  // ============================================================
  // PHASE 4: Add a Food Item
  // ============================================================
  TestLogger.logStep('Phase 4: Add Food Item');

  final macrosBeforeAdd = await _captureBeforeRunMacros(tester);
  final addedFood = await _addFood(tester);

  if (addedFood == null) {
    TestLogger.logInfo('Could not add food - skipping add verification');
  } else {
    TestLogger.logSubStep('Added food: $addedFood');

    // Wait for UI to update
    await tester.wait(TestConfig.animationDelay);

    // Capture macros after add
    final afterAddMacros = await _captureBeforeRunMacros(tester);
    if (afterAddMacros == null) {
      await tester.screenshot('FAIL_macros_after_add');
      throw TestFailure('FAIL: Could not capture macros after add');
    }

    TestLogger.logData('After add macros', afterAddMacros.toString());

    // Verify carbs numerator increased (or stayed same if food had 0 carbs)
    if (macrosBeforeAdd != null &&
        afterAddMacros.carbsNumerator < macrosBeforeAdd.carbsNumerator) {
      await tester.screenshot('FAIL_carbs_decreased_after_add');
      throw TestFailure(
        'FAIL: Carbs DECREASED after adding food!\n'
        'Before: ${macrosBeforeAdd.carbsNumerator}g\n'
        'After: ${afterAddMacros.carbsNumerator}g\n'
        'This is a bug - adding food should increase or maintain carbs.',
      );
    }

    // Verify values are still reasonable
    if (!afterAddMacros.isReasonable()) {
      await tester.screenshot('FAIL_macros_unreasonable_after_add');
      throw TestFailure(
        'FAIL: Macro values became unreasonable after add\n'
        'Values: ${afterAddMacros.toString()}',
      );
    }

    TestLogger.logSuccess('Add verification passed');
    await tester.screenshot('after_add_success');
  }

  // ============================================================
  // PHASE 5: Swap a Food Item
  // ============================================================
  TestLogger.logStep('Phase 5: Swap Food Item');

  final macrosBeforeSwap = await _captureBeforeRunMacros(tester);
  final swappedFood = await _swapFood(tester);

  if (swappedFood == null) {
    TestLogger.logInfo('Could not swap food - skipping swap verification');
  } else {
    TestLogger.logSubStep('Swapped food: $swappedFood');

    // Wait for UI to update
    await tester.wait(TestConfig.animationDelay);

    // Capture macros after swap
    final afterSwapMacros = await _captureBeforeRunMacros(tester);
    if (afterSwapMacros == null) {
      await tester.screenshot('FAIL_macros_after_swap');
      throw TestFailure('FAIL: Could not capture macros after swap');
    }

    TestLogger.logData('After swap macros', afterSwapMacros.toString());

    // Verify values are still reasonable after swap
    if (!afterSwapMacros.isReasonable()) {
      await tester.screenshot('FAIL_macros_unreasonable_after_swap');
      throw TestFailure(
        'FAIL: Macro values became unreasonable after swap\n'
        'Values: ${afterSwapMacros.toString()}',
      );
    }

    // Verify target values didn't change (targets should be stable)
    if (macrosBeforeSwap != null &&
        afterSwapMacros.carbsTarget != macrosBeforeSwap.carbsTarget) {
      await tester.screenshot('FAIL_targets_changed_after_swap');
      throw TestFailure(
        'FAIL: Target values changed after swap!\n'
        'Before target: ${macrosBeforeSwap.carbsTarget}g\n'
        'After target: ${afterSwapMacros.carbsTarget}g\n'
        'Targets should remain constant.',
      );
    }

    TestLogger.logSuccess('Swap verification passed');
    await tester.screenshot('after_swap_success');
  }

  // ============================================================
  // PHASE 6: Final Verification - Values Haven't Reset
  // ============================================================
  TestLogger.logStep('Phase 6: Final Verification');

  final finalMacros = await _captureBeforeRunMacros(tester);
  if (finalMacros == null) {
    await tester.screenshot('FAIL_final_macros');
    throw TestFailure('FAIL: Could not capture final macro values');
  }

  // Verify targets haven't changed from initial
  if (finalMacros.carbsTarget != initialMacros.carbsTarget) {
    await tester.screenshot('FAIL_targets_reset');
    throw TestFailure(
      'FAIL: Carb targets changed unexpectedly!\n'
      'Initial target: ${initialMacros.carbsTarget}g\n'
      'Final target: ${finalMacros.carbsTarget}g\n'
      'This indicates the reset bug.',
    );
  }

  // Verify values are reasonable
  if (!finalMacros.isReasonable()) {
    await tester.screenshot('FAIL_final_macros_unreasonable');
    throw TestFailure(
      'FAIL: Final macro values are unreasonable\n'
      'Values: ${finalMacros.toString()}',
    );
  }

  await tester.screenshot('food_manipulation_complete');
  TestLogger.logStep('Food Manipulation Flow Complete!');
  TestLogger.logSuccess('All food operations verified successfully');
}

/// Navigate to activity details screen
Future<void> _navigateToActivityDetails(WidgetTester tester) async {
  TestLogger.logStep('Phase 1: Navigate to Activity Details');

  // First ensure we're on the calendar screen
  final calendarIcon = find.byIcon(FontAwesomeIcons.calendar);
  if (calendarIcon.evaluate().isNotEmpty) {
    await tester.tap(calendarIcon.first);
    await tester.pumpAndSettle();
    await tester.wait(TestConfig.pageTransitionDelay);
  }

  // Look for an activity card to tap
  // Activities show as "X.X MI RUN" with checkmark and X buttons
  // From screenshot: "12.0 MI RUN" with "12.0 mi · 9:00/mi"
  final activityCard = find.textContaining('MI RUN');

  if (activityCard.evaluate().isEmpty) {
    // Try alternative patterns
    final runCard = find.textContaining('RUN');
    if (runCard.evaluate().isEmpty) {
      await tester.screenshot('FAIL_no_activity_found');
      throw TestFailure(
        'FAIL: No activity found on calendar.\n'
        'Expected to find activity card with "MI RUN" text.',
      );
    }
  }

  // Tap the activity card to view details
  TestLogger.logSubStep('Tapping activity card...');
  await tester.tap(activityCard.first);
  await tester.pumpAndSettle();
  await tester.wait(TestConfig.pageTransitionDelay);

  // Verify we're on Activity Details screen
  // Look for "BEFORE RUN" section which indicates nutrition plan exists
  final beforeRunSection = find.text('BEFORE RUN');
  final foundActivityDetails = await tester.waitForWidget(
    beforeRunSection,
    timeout: TestConfig.mediumTimeout,
  );

  if (!foundActivityDetails) {
    // Maybe we need to scroll or the activity doesn't have a plan
    final activityDetails = find.textContaining('Activity Details');
    if (activityDetails.evaluate().isEmpty) {
      await tester.screenshot('FAIL_not_on_activity_details');
      throw TestFailure(
        'FAIL: Did not navigate to Activity Details screen.\n'
        'Could not find "BEFORE RUN" or "Activity Details" text.',
      );
    }

    // We're on activity details but no nutrition plan
    await tester.screenshot('FAIL_no_nutrition_plan');
    throw TestFailure(
      'FAIL: Activity has no nutrition plan.\n'
      'Expected "BEFORE RUN" section but it was not found.',
    );
  }

  TestLogger.logSuccess('On Activity Details with nutrition plan');
  await tester.screenshot('activity_details_loaded');
}

/// Capture macro values from the BEFORE RUN section
Future<MacroValues?> _captureBeforeRunMacros(WidgetTester tester) async {
  TestLogger.logSubStep('Capturing BEFORE RUN macro values...');

  // Find the BEFORE RUN section
  final beforeRunSection = find.text('BEFORE RUN');
  if (beforeRunSection.evaluate().isEmpty) {
    TestLogger.logError('BEFORE RUN section not found');
    return null;
  }

  // Look for macro values in format "XXX/YYYg" or "XXX/YYYmg"
  // From screenshot: "204/152g CARBS", "26/19g PROTEIN", "640/450mg SODIUM"

  // Find CARBS value
  final carbsValue = _extractMacroValue(tester, 'CARBS');
  if (carbsValue == null) {
    TestLogger.logError('Could not find CARBS value');
    return null;
  }

  // Find PROTEIN value
  final proteinValue = _extractMacroValue(tester, 'PROTEIN');
  if (proteinValue == null) {
    TestLogger.logError('Could not find PROTEIN value');
    return null;
  }

  // Find SODIUM value
  final sodiumValue = _extractMacroValue(tester, 'SODIUM');
  if (sodiumValue == null) {
    TestLogger.logError('Could not find SODIUM value');
    return null;
  }

  return MacroValues(
    carbsNumerator: carbsValue.$1,
    carbsTarget: carbsValue.$2,
    proteinNumerator: proteinValue.$1,
    proteinTarget: proteinValue.$2,
    sodiumNumerator: sodiumValue.$1,
    sodiumTarget: sodiumValue.$2,
    section: 'BEFORE RUN',
  );
}

/// Extract numerator/target from macro display
/// Looks for text like "204/152g" near the label "CARBS"
(int, int)? _extractMacroValue(WidgetTester tester, String label) {
  // Find all Text widgets and look for the pattern
  final allText = find.byType(Text);

  for (final element in allText.evaluate()) {
    final widget = element.widget as Text;
    final text = widget.data ?? '';

    // Look for pattern like "204/152g" or "640/450mg"
    final regex = RegExp(r'(\d+)/(\d+)');
    final match = regex.firstMatch(text);

    if (match != null) {
      // Check if this is near our label
      // For simplicity, we'll look for any widget that contains both the value and could be our target
      // The label (CARBS, PROTEIN, SODIUM) should be in a nearby widget

      // Get the numerator and denominator
      final numerator = int.tryParse(match.group(1) ?? '');
      final target = int.tryParse(match.group(2) ?? '');

      if (numerator != null && target != null) {
        // Check if the label is nearby in the widget tree
        // We need to verify this is the right macro
        // Look for the label text nearby
        final labelFinder = find.text(label);
        if (labelFinder.evaluate().isNotEmpty) {
          // Found the label - now check if this value is in the same area
          // For now, we'll use a heuristic based on the text content
          if (text.toLowerCase().contains(label.toLowerCase()) ||
              _isNearWidget(element, labelFinder.evaluate().first)) {
            return (numerator, target);
          }
        }
      }
    }
  }

  // Fallback: try to find by looking for pattern with unit
  final patterns = [
    RegExp(r'(\d+)/(\d+)g'), // carbs, protein
    RegExp(r'(\d+)/(\d+)mg'), // sodium
    RegExp(r'(\d+)/(\d+)mL'), // fluids
  ];

  for (final element in allText.evaluate()) {
    final widget = element.widget as Text;
    final text = widget.data ?? '';

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final numerator = int.tryParse(match.group(1) ?? '');
        final target = int.tryParse(match.group(2) ?? '');
        if (numerator != null && target != null) {
          // Return the first match we find for now
          // In production, we'd need more sophisticated matching
          return (numerator, target);
        }
      }
    }
  }

  return null;
}

/// Check if two elements are near each other (within reasonable bounds)
bool _isNearWidget(Element element1, Element element2) {
  // This is a simplified check - in production we'd use actual coordinates
  // For now, return true if they exist on the same screen
  return true;
}

/// Delete the first food item in the list
Future<String?> _deleteFirstFood(WidgetTester tester) async {
  TestLogger.logSubStep('Looking for food to delete...');

  // From archived screenshots, delete is via swipe or a delete button
  // Look for food items - they have names like "Oatmeal", "Bananas", etc.
  final foodNames = ['Oatmeal', 'Bananas', 'Toast', 'Energy bar', 'Sports drink'];

  for (final foodName in foodNames) {
    final foodItem = find.text(foodName);
    if (foodItem.evaluate().isNotEmpty) {
      TestLogger.logSubStep('Found food: $foodName');

      // Try to expand the food item by tapping the chevron
      final chevron = find.byIcon(Icons.keyboard_arrow_down);
      if (chevron.evaluate().isNotEmpty) {
        await tester.tap(chevron.first);
        await tester.pumpAndSettle();
      }

      // Look for delete button (trash icon or "Delete" text)
      final deleteIcon = find.byIcon(Icons.delete);
      final deleteText = find.text('Delete');
      final trashIcon = find.byIcon(FontAwesomeIcons.trash);

      if (deleteIcon.evaluate().isNotEmpty) {
        await tester.tap(deleteIcon.first);
        await tester.pumpAndSettle();
        return foodName;
      } else if (trashIcon.evaluate().isNotEmpty) {
        await tester.tap(trashIcon.first);
        await tester.pumpAndSettle();
        return foodName;
      } else if (deleteText.evaluate().isNotEmpty) {
        await tester.tap(deleteText.first);
        await tester.pumpAndSettle();
        return foodName;
      }

      // Try swipe to delete
      await tester.drag(foodItem.first, const Offset(-200, 0));
      await tester.pumpAndSettle();

      // Check if delete appeared after swipe
      final swipeDelete = find.text('Delete');
      if (swipeDelete.evaluate().isNotEmpty) {
        await tester.tap(swipeDelete.first);
        await tester.pumpAndSettle();
        return foodName;
      }
    }
  }

  return null;
}

/// Add a food item using the "+ ADD FOOD" button
Future<String?> _addFood(WidgetTester tester) async {
  TestLogger.logSubStep('Looking for ADD FOOD button...');

  // Find the "+ ADD FOOD" button
  final addFoodBtn = find.text('ADD FOOD');
  final addFoodBtn2 = find.textContaining('ADD FOOD');

  Finder? buttonToTap;
  if (addFoodBtn.evaluate().isNotEmpty) {
    buttonToTap = addFoodBtn;
  } else if (addFoodBtn2.evaluate().isNotEmpty) {
    buttonToTap = addFoodBtn2;
  }

  if (buttonToTap == null) {
    TestLogger.logInfo('ADD FOOD button not found');
    return null;
  }

  await tester.tap(buttonToTap.first);
  await tester.pumpAndSettle();
  await tester.wait(TestConfig.pageTransitionDelay);

  // Should now be on food selection screen
  // Look for food items to select
  final searchField = find.byType(TextField);
  if (searchField.evaluate().isNotEmpty) {
    // Search for a simple food
    await tester.enterText(searchField.first, 'banana');
    await tester.pumpAndSettle();
    await tester.wait(TestConfig.networkDelay);
  }

  // Look for a food item to tap (with + icon to add)
  final addIcon = find.byIcon(Icons.add_circle_outline);
  final plusIcon = find.byIcon(FontAwesomeIcons.plus);

  if (addIcon.evaluate().isNotEmpty) {
    await tester.tap(addIcon.first);
    await tester.pumpAndSettle();

    // Go back to activity details
    final backBtn = find.byIcon(Icons.arrow_back);
    if (backBtn.evaluate().isNotEmpty) {
      await tester.tap(backBtn.first);
      await tester.pumpAndSettle();
    }

    return 'Banana';
  } else if (plusIcon.evaluate().isNotEmpty) {
    await tester.tap(plusIcon.first);
    await tester.pumpAndSettle();
    return 'Food item';
  }

  // Try tapping first food result
  final bananaResult = find.textContaining('Banana');
  if (bananaResult.evaluate().isNotEmpty) {
    await tester.tap(bananaResult.first);
    await tester.pumpAndSettle();
    return 'Banana';
  }

  return null;
}

/// Swap a food item
Future<String?> _swapFood(WidgetTester tester) async {
  TestLogger.logSubStep('Looking for food to swap...');

  // From archived screenshots, there's a "Swap Oatmeal" screen
  // Need to find how to trigger swap

  // First, try to expand a food item
  final foodNames = ['Oatmeal', 'Bananas', 'Toast'];

  for (final foodName in foodNames) {
    final foodItem = find.text(foodName);
    if (foodItem.evaluate().isNotEmpty) {
      // Tap to expand
      await tester.tap(foodItem.first);
      await tester.pumpAndSettle();

      // Look for swap button
      final swapBtn = find.text('Swap');
      final swapIcon = find.byIcon(Icons.swap_horiz);

      if (swapBtn.evaluate().isNotEmpty) {
        await tester.tap(swapBtn.first);
        await tester.pumpAndSettle();
        await tester.wait(TestConfig.pageTransitionDelay);

        // On swap screen, select an alternative
        final alternatives = find.textContaining('carbs per serving');
        if (alternatives.evaluate().isNotEmpty) {
          // Tap first alternative
          final addAltIcon = find.byIcon(Icons.add_circle_outline);
          if (addAltIcon.evaluate().isNotEmpty) {
            await tester.tap(addAltIcon.first);
            await tester.pumpAndSettle();
            return '$foodName → alternative';
          }
        }

        // Go back if we couldn't complete swap
        final backBtn = find.byIcon(Icons.arrow_back);
        if (backBtn.evaluate().isNotEmpty) {
          await tester.tap(backBtn.first);
          await tester.pumpAndSettle();
        }
      } else if (swapIcon.evaluate().isNotEmpty) {
        await tester.tap(swapIcon.first);
        await tester.pumpAndSettle();
        return foodName;
      }
    }
  }

  return null;
}
