// Screen smoke suite — food add/swap screens.
//
// These are the add-food and swap-food pages. They render their search/empty
// UI from providers; the actual catalog/OpenFoodFacts calls happen in event
// handlers (button taps), not in build, so the initial render is widget-testable
// with the default mocked external deps.

import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/barcode_scanning/presentation/screens/add_food_screen.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/screens/swap_food_screen.dart';

import '../helpers/widget_test_harness.dart';

void main() {
  group('Food add/swap screen smoke tests', () {
    testWidgets('AddFoodScreen renders without overflow', (tester) async {
      await smokeScreen(tester, const AddFoodScreen());
    });

    // SwapFoodScreen loads its food list in initState, so it shows a perpetual
    // loading indicator in-test (the data provider never resolves without
    // seeding). settle:false lets the loading state lay out and verifies the
    // screen builds without throwing. A fuller test that seeds the catalog
    // provider + asserts results is a follow-up (Patrol covers the live flow).
    testWidgets('SwapFoodScreen builds (loading state)', (tester) async {
      await smokeScreen(
        tester,
        const SwapFoodScreen(
          category: 'during',
          activityId: 'test-activity-id',
          isNewActivity: true,
        ),
        settle: false,
      );
    });
  });
}
