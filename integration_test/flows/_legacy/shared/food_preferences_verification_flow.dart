/// Food Preferences Verification Flow
///
/// Tests that food preferences:
/// 1. Can be modified (slider from Avoid ↔ Love)
/// 2. Are saved correctly
/// 3. Persist after logout/login (sync verification)
/// 4. Don't reset to neutral (known bug test)
///
/// FAIL-FAST: Any preference reset to neutral will fail the test
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../helpers/test_config.dart';
import '../../helpers/test_helpers.dart';

/// Food preference state
enum FoodPreference {
  avoid, // Left side, red X
  neutral, // Middle
  love, // Right side, pink heart
}

/// Captured food preference
class CapturedPreference {
  final String foodName;
  final FoodPreference preference;

  const CapturedPreference({
    required this.foodName,
    required this.preference,
  });

  @override
  String toString() => '$foodName: ${preference.name}';
}

/// Collection of food preferences for comparison
class FoodPreferencesState {
  final List<CapturedPreference> preferences;
  final DateTime capturedAt;

  FoodPreferencesState({
    required this.preferences,
    DateTime? capturedAt,
  }) : capturedAt = capturedAt ?? DateTime.now();

  /// Find preference for a specific food
  CapturedPreference? getPreference(String foodName) {
    for (final pref in preferences) {
      if (pref.foodName.toLowerCase().contains(foodName.toLowerCase())) {
        return pref;
      }
    }
    return null;
  }

  /// Check if all preferences are neutral (potential bug)
  bool areAllNeutral() {
    return preferences.every((p) => p.preference == FoodPreference.neutral);
  }

  /// Count non-neutral preferences
  int get nonNeutralCount =>
      preferences.where((p) => p.preference != FoodPreference.neutral).length;

  @override
  String toString() {
    final buffer = StringBuffer('FoodPreferencesState:\n');
    for (final pref in preferences) {
      buffer.writeln('  - $pref');
    }
    buffer.writeln('  Non-neutral count: $nonNeutralCount');
    return buffer.toString();
  }
}

/// Run food preferences verification flow
///
/// This test verifies that food preferences persist correctly.
/// Should be run BEFORE sync test to capture initial state,
/// and AFTER sync test to verify preferences weren't reset.
Future<FoodPreferencesState> runFoodPreferencesVerificationFlow(
  WidgetTester tester, {
  FoodPreferencesState? expectedState,
  bool modifyPreferences = false,
}) async {
  TestLogger.logStep('Starting Food Preferences Verification Flow');

  // ============================================================
  // PHASE 1: Navigate to Food Preferences
  // ============================================================
  await _navigateToFoodPreferences(tester);

  // ============================================================
  // PHASE 2: Capture Current State
  // ============================================================
  TestLogger.logStep('Phase 2: Capturing Food Preferences State');

  final currentState = await _captureFoodPreferences(tester);

  TestLogger.logData('Current state', currentState.toString());
  await tester.screenshot('food_preferences_state');

  // ============================================================
  // PHASE 3: Verify Against Expected State (if provided)
  // ============================================================
  if (expectedState != null) {
    TestLogger.logStep('Phase 3: Verifying Against Expected State');

    // Check if preferences reset to neutral (the bug we're testing for)
    if (expectedState.nonNeutralCount > 0 && currentState.areAllNeutral()) {
      await tester.screenshot('FAIL_preferences_reset_to_neutral');
      throw TestFailure(
        'FAIL: Food preferences reset to neutral!\n'
        'Expected ${expectedState.nonNeutralCount} non-neutral preferences.\n'
        'Found: ${currentState.nonNeutralCount} non-neutral preferences.\n'
        'This is the known bug where preferences are lost after sync.',
      );
    }

    // Check specific preferences match
    for (final expected in expectedState.preferences) {
      if (expected.preference != FoodPreference.neutral) {
        final current = currentState.getPreference(expected.foodName);
        if (current == null) {
          TestLogger.logInfo(
            'Food "${expected.foodName}" not found in current state',
          );
          continue;
        }

        if (current.preference != expected.preference) {
          await tester.screenshot('FAIL_preference_changed_${expected.foodName}');
          throw TestFailure(
            'FAIL: Preference for "${expected.foodName}" changed!\n'
            'Expected: ${expected.preference.name}\n'
            'Found: ${current.preference.name}\n'
            'Preferences should persist after sync.',
          );
        }

        TestLogger.logSuccess(
          '${expected.foodName}: ${current.preference.name} (matches expected)',
        );
      }
    }

    TestLogger.logSuccess('All preferences match expected state');
  }

  // ============================================================
  // PHASE 4: Modify Preferences (if requested)
  // ============================================================
  if (modifyPreferences) {
    TestLogger.logStep('Phase 4: Modifying Preferences');

    // Find a food to modify
    await _modifyFirstAvailablePreference(tester);

    // Save changes
    final saveBtn = find.text('Save Changes');
    if (saveBtn.evaluate().isNotEmpty) {
      await tester.tap(saveBtn.first);
      await tester.pumpAndSettle();
      await tester.wait(TestConfig.networkDelay);
      TestLogger.logSuccess('Saved preference changes');
    }

    // Re-capture state after modification
    final modifiedState = await _captureFoodPreferences(tester);
    await tester.screenshot('food_preferences_modified');

    // Navigate back
    final backBtn = find.byIcon(Icons.arrow_back);
    if (backBtn.evaluate().isNotEmpty) {
      await tester.tap(backBtn.first);
      await tester.pumpAndSettle();
    }

    return modifiedState;
  }

  // ============================================================
  // PHASE 5: Navigate Back
  // ============================================================
  final backBtn = find.byIcon(Icons.arrow_back);
  if (backBtn.evaluate().isNotEmpty) {
    await tester.tap(backBtn.first);
    await tester.pumpAndSettle();
    await tester.wait(TestConfig.pageTransitionDelay);
  }

  TestLogger.logStep('Food Preferences Verification Complete');
  return currentState;
}

/// Navigate to Food Preferences screen
Future<void> _navigateToFoodPreferences(WidgetTester tester) async {
  TestLogger.logStep('Phase 1: Navigate to Food Preferences');

  // First go to Settings
  final ellipsisIcon = find.byIcon(FontAwesomeIcons.ellipsis);
  if (ellipsisIcon.evaluate().isNotEmpty) {
    await tester.tap(ellipsisIcon.first);
    await tester.pumpAndSettle();
    await tester.wait(TestConfig.pageTransitionDelay);
  } else {
    await tester.screenshot('FAIL_settings_icon_not_found');
    throw TestFailure('FAIL: Could not find settings navigation icon');
  }

  // Verify we're on Settings
  final settingsTitle = find.text('Settings');
  final settingsFound = await tester.waitForWidget(
    settingsTitle,
    timeout: TestConfig.mediumTimeout,
  );

  if (!settingsFound) {
    await tester.screenshot('FAIL_not_on_settings');
    throw TestFailure('FAIL: Did not navigate to Settings screen');
  }

  // Find and tap "Food Preferences" row
  final foodPrefsRow = find.text('Food Preferences');
  if (foodPrefsRow.evaluate().isEmpty) {
    await tester.screenshot('FAIL_food_prefs_row_not_found');
    throw TestFailure('FAIL: "Food Preferences" row not found in Settings');
  }

  await tester.tap(foodPrefsRow.first);
  await tester.pumpAndSettle();
  await tester.wait(TestConfig.pageTransitionDelay);

  // Verify we're on Food Preferences screen
  // Look for search field - this confirms we're on the right screen
  final searchField = find.byWidgetPredicate((widget) {
    if (widget is TextField) {
      final hint = widget.decoration?.hintText ?? '';
      return hint.toLowerCase().contains('search');
    }
    return false;
  });

  // The title "Food Preferences" should be visible and there should be a search field
  if (searchField.evaluate().isEmpty) {
    await tester.screenshot('FAIL_food_prefs_screen_not_loaded');
    throw TestFailure('FAIL: Food Preferences screen did not load properly');
  }

  TestLogger.logSuccess('On Food Preferences screen');
  await tester.screenshot('food_preferences_screen');
}

/// Capture current food preferences state
Future<FoodPreferencesState> _captureFoodPreferences(WidgetTester tester) async {
  final preferences = <CapturedPreference>[];

  // Known food names to look for (from screenshots)
  final foodsToCheck = [
    'BAGEL (PLAIN)',
    'BANANAS',
    'ENERGY BAR',
    'ENERGY CHEWS',
    'GEL',
    'OATMEAL',
    'TOAST',
    'SPORTS DRINK',
  ];

  for (final foodName in foodsToCheck) {
    final preference = await _getPreferenceForFood(tester, foodName);
    if (preference != null) {
      preferences.add(CapturedPreference(
        foodName: foodName,
        preference: preference,
      ));
      TestLogger.logSubStep('$foodName: ${preference.name}');
    }
  }

  // If we didn't find specific foods, try to capture whatever is visible
  if (preferences.isEmpty) {
    TestLogger.logInfo('No specific foods found, capturing visible items');

    // Look for any slider widgets
    final sliders = find.byType(Slider);
    TestLogger.logData('Sliders found', sliders.evaluate().length);
  }

  return FoodPreferencesState(preferences: preferences);
}

/// Get preference state for a specific food
Future<FoodPreference?> _getPreferenceForFood(
  WidgetTester tester,
  String foodName,
) async {
  // Find the food name text
  final foodText = find.textContaining(foodName);
  if (foodText.evaluate().isEmpty) {
    return null;
  }

  // Look for Slider widget near this food item
  // The slider value indicates the preference:
  // - 0.0 (left) = Avoid
  // - 0.5 (middle) = Neutral
  // - 1.0 (right) = Love
  //
  // From screenshot: slider has visual indicators at the thumb position
  // The "Avoid" text turns red when selected, "Love" text turns pink
  //
  // We'll check the Slider widget value directly
  final sliders = find.byType(Slider);

  // Find all slider elements and their positions relative to the food text
  for (final sliderElement in sliders.evaluate()) {
    final sliderWidget = sliderElement.widget as Slider;
    final sliderValue = sliderWidget.value;

    // Get positions to match slider with food item
    final sliderBox = sliderElement.renderObject as RenderBox?;
    final foodBox = foodText.evaluate().first.renderObject as RenderBox?;

    if (sliderBox != null && foodBox != null) {
      // Check if slider is below this food item (within reasonable distance)
      final sliderPos = sliderBox.localToGlobal(Offset.zero);
      final foodPos = foodBox.localToGlobal(Offset.zero);

      // Slider should be directly below its food label (within ~100 pixels)
      final isNearFood = (sliderPos.dy - foodPos.dy).abs() < 150 &&
                        (sliderPos.dx - foodPos.dx).abs() < 200;

      if (isNearFood) {
        // Interpret slider value
        // Values near 0 = Avoid, near 0.5 = Neutral, near 1 = Love
        if (sliderValue < 0.25) {
          return FoodPreference.avoid;
        } else if (sliderValue > 0.75) {
          return FoodPreference.love;
        } else {
          return FoodPreference.neutral;
        }
      }
    }
  }

  // Fallback: Look at the text colors near this food
  // If "Love" text is magenta/pink colored, it's love
  // If "Avoid" text is red/coral colored, it's avoid
  // Otherwise it's neutral

  // Find all Text widgets and look for colored "Love" or "Avoid" near this food
  final allText = find.byType(Text);

  for (final textElement in allText.evaluate()) {
    final textWidget = textElement.widget as Text;
    final textData = textWidget.data ?? '';
    final textStyle = textWidget.style;

    // Check if this is the "Love" or "Avoid" label
    if (textData == 'Love' || textData == 'Avoid') {
      // Check if it has a color (indicating it's selected)
      final color = textStyle?.color;

      if (color != null) {
        // Pink/magenta indicates Love is selected
        // Red/coral indicates Avoid is selected
        // White/gray indicates neutral

        // Convert color channels to 0-255 range
        final red = (color.r * 255).round();
        final green = (color.g * 255).round();
        final blue = (color.b * 255).round();

        final isRedish = red > 200 && green < 150 && blue < 150;
        final isPinkish = red > 200 && green < 150 && blue > 150;

        if (textData == 'Love' && isPinkish) {
          return FoodPreference.love;
        } else if (textData == 'Avoid' && isRedish) {
          return FoodPreference.avoid;
        }
      }
    }
  }

  // Default to neutral if we can't determine
  return FoodPreference.neutral;
}

/// Modify the first available preference
Future<void> _modifyFirstAvailablePreference(WidgetTester tester) async {
  TestLogger.logSubStep('Looking for preference to modify...');

  // Find a slider to drag
  final sliders = find.byType(Slider);

  if (sliders.evaluate().isEmpty) {
    TestLogger.logInfo('No sliders found');
    return;
  }

  // Drag the first slider to the right (towards Love)
  TestLogger.logSubStep('Dragging first slider towards Love...');
  await tester.drag(sliders.first, const Offset(100, 0));
  await tester.pumpAndSettle();

  TestLogger.logSuccess('Modified preference slider');
}

/// Verify food preferences after sync
///
/// This is the main test for the "preferences reset to neutral" bug.
/// Call this after a sync operation with the pre-sync state.
Future<void> verifyPreferencesAfterSync(
  WidgetTester tester,
  FoodPreferencesState preSyncState,
) async {
  TestLogger.logStep('Verifying Food Preferences After Sync');

  // Navigate to food preferences and capture current state
  final postSyncState = await runFoodPreferencesVerificationFlow(
    tester,
    expectedState: preSyncState,
  );

  // Additional verification: count non-neutral preferences
  if (preSyncState.nonNeutralCount > 0) {
    final countDiff = preSyncState.nonNeutralCount - postSyncState.nonNeutralCount;

    if (countDiff > 0) {
      await tester.screenshot('FAIL_preferences_lost');
      throw TestFailure(
        'FAIL: Lost $countDiff non-neutral preferences after sync!\n'
        'Pre-sync: ${preSyncState.nonNeutralCount} non-neutral\n'
        'Post-sync: ${postSyncState.nonNeutralCount} non-neutral\n'
        'This indicates the preference reset bug.',
      );
    }
  }

  TestLogger.logSuccess('Food preferences verified after sync');
}
