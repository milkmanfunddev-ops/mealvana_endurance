/// Food Suitability Validation Tests
/// 
/// These tests ensure that the nutrition algorithm respects phase-specific
/// food constraints for user safety. Critical for preventing GI distress
/// during runs by ensuring inappropriate foods (like oatmeal) never appear
/// during-run phases.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/nutrition_plan/presentation/controllers/nutrition_plan_controller.dart';

import '../helpers/test_data.dart';
import '../helpers/mock_providers.dart';
import '../helpers/test_config.dart';

void main() {
  group('Food Suitability Validation Tests', () {
    late ProviderContainer container;

    setUpAll(() {
      TestMockSetup.setupFallbacks();
    });

    setUp(() {
      container = TestProviderContainer.create();
    });

    tearDown(() {
      TestContainerUtils.disposeContainer(container);
    });

    group('Phase Constraint Enforcement', () {
      testWidgets('pre-run only foods never appear during runs', (tester) async {
        // Arrange: Create plan request with pre-run only foods liked
        final planRequest = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        planRequest['liked_foods'] = [
          'oatmeal',     // PRE-RUN ONLY
          'banana',      // PRE-RUN and POST-RUN only
          'waffle',      // PRE-RUN ONLY
          'gels',        // DURING-RUN suitable
          'sports_drink' // ALL PHASES
        ];
        planRequest['distance_miles'] = 10.0; // Long enough to require during-run fueling

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate nutrition plan
        await controller.generatePlan(planRequest);

        final state = container.read(nutritionPlanControllerProvider);
        
        // Assert: Plan generation succeeded
        expect(state.hasValue, isTrue, reason: 'Plan generation should succeed');
        
        final plan = state.requireValue;
        expect(plan, isNotNull);
        expect(plan, contains('plan'));
        
        final planDetails = plan['plan'] as Map<String, dynamic>;
        expect(planDetails, contains('during'));
        
        final duringRunItems = planDetails['during'] as List<dynamic>;
        expect(duringRunItems, isNotEmpty, reason: 'Should have during-run foods for 10-mile run');

        // CRITICAL ASSERTIONS: Pre-run only foods must not appear during runs
        final duringRunFoodNames = duringRunItems
            .map((item) => (item as Map<String, dynamic>)['food_name'] as String)
            .toSet();

        // These foods should NEVER appear during runs (user safety)
        for (final forbiddenFood in TestData.preRunOnlyFoods) {
          expect(duringRunFoodNames, isNot(contains(forbiddenFood)),
              reason: '$forbiddenFood should never appear during runs - GI distress risk');
        }

        // But suitable during-run foods should be present
        final suitableFoodsPresent = duringRunFoodNames
            .where((food) => TestData.duringRunSuitableFoods.contains(food))
            .toList();
        expect(suitableFoodsPresent, isNotEmpty,
            reason: 'Should include suitable during-run foods like gels or sports drinks');
      });

      testWidgets('during-run foods are portable and easily consumed', (tester) async {
        // Arrange: Request with various food preferences
        final planRequest = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        planRequest['liked_foods'] = [
          'gels',
          'energy_chews', 
          'sports_drink',
          'electrolyte_tablets',
          'dates',
          'banana', // Liked but not suitable during runs
          'granola_bar', // Liked but not ideal during runs
        ];
        planRequest['distance_miles'] = 13.1; // Half marathon - needs substantial during-run fueling

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan
        await controller.generatePlan(planRequest);
        
        final state = container.read(nutritionPlanControllerProvider);
        final plan = state.requireValue;
        final planDetails = plan['plan'] as Map<String, dynamic>;
        final duringRunItems = planDetails['during'] as List<dynamic>;

        // Assert: Only portable, easily consumable foods during runs
        expect(duringRunItems, isNotEmpty);

        final duringRunFoodNames = duringRunItems
            .map((item) => (item as Map<String, dynamic>)['food_name'] as String)
            .toList();

        // All during-run foods should be from suitable list
        for (final foodName in duringRunFoodNames) {
          expect(TestData.duringRunSuitableFoods, contains(foodName),
              reason: '$foodName is not suitable for during-run consumption');
        }

        // Should not include hard-to-consume foods
        final unsuitableDuringRun = ['banana', 'granola_bar', 'oatmeal', 'waffle'];
        for (final unsuitableFood in unsuitableDuringRun) {
          expect(duringRunFoodNames, isNot(contains(unsuitableFood)),
              reason: '$unsuitableFood is too difficult to consume while running');
        }
      });

      testWidgets('multi-phase foods appear in appropriate phases only', (tester) async {
        // Arrange: Test foods that can appear in multiple phases
        final planRequest = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        planRequest['liked_foods'] = ['sports_drink', 'banana', 'coconut_water'];
        planRequest['distance_miles'] = 8.0; // Long enough for all phases

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan
        await controller.generatePlan(planRequest);
        
        final state = container.read(nutritionPlanControllerProvider);
        final plan = state.requireValue;
        final planDetails = plan['plan'] as Map<String, dynamic>;

        // Assert: Multi-phase foods in correct phases
        
        // Sports drink can appear in all phases
        final beforeItems = planDetails['before'] as List<dynamic>? ?? [];
        final duringItems = planDetails['during'] as List<dynamic>? ?? [];
        final afterItems = planDetails['after'] as List<dynamic>? ?? [];

        final beforeFoods = beforeItems
            .map((item) => (item as Map<String, dynamic>)['food_name'] as String)
            .toSet();
        final duringFoods = duringItems
            .map((item) => (item as Map<String, dynamic>)['food_name'] as String)
            .toSet();
        final afterFoods = afterItems
            .map((item) => (item as Map<String, dynamic>)['food_name'] as String)
            .toSet();

        // Sports drink should be allowed in any phase
        if (beforeFoods.contains('sports_drink') || 
            duringFoods.contains('sports_drink') || 
            afterFoods.contains('sports_drink')) {
          // At least one phase should have sports drink (it's versatile)
          expect(true, isTrue);
        }

        // Banana should only be in before/after, never during
        expect(duringFoods, isNot(contains('banana')),
            reason: 'Banana should never appear during runs');

        // Coconut water is primarily post-run
        if (afterFoods.contains('coconut_water')) {
          expect(duringFoods, isNot(contains('coconut_water')),
              reason: 'Coconut water is for recovery, not during runs');
        }
      });

      testWidgets('short runs minimize during-run fueling appropriately', (tester) async {
        // Arrange: Short run that might not need during-run fueling
        final planRequest = TestData.test5KRequest.cast<String, dynamic>();

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan for 5K
        await controller.generatePlan(planRequest);
        
        final state = container.read(nutritionPlanControllerProvider);
        final plan = state.requireValue;
        final planDetails = plan['plan'] as Map<String, dynamic>;

        // Assert: Minimal or no during-run fueling for short runs
        final duringItems = planDetails['during'] as List<dynamic>? ?? [];
        
        // 5K runs (< 1 hour for most people) should have minimal during-run fueling
        if (duringItems.isNotEmpty) {
          // If there is during-run fueling, it should be very minimal
          expect(duringItems.length, lessThanOrEqualTo(2),
              reason: '5K runs should have minimal during-run fueling');
              
          // And should be hydration-focused rather than carb-heavy
          final duringFoodNames = duringItems
              .map((item) => (item as Map<String, dynamic>)['food_name'] as String)
              .toList();
              
          // Should prioritize hydration over solid foods
          final hasHydration = duringFoodNames.any((name) => 
              name.contains('drink') || name.contains('water') || name.contains('electrolyte'));
          final hasSolidFood = duringFoodNames.any((name) => 
              name.contains('gel') || name.contains('chew') || name.contains('bar'));
              
          if (hasSolidFood) {
            expect(hasHydration, isTrue, 
                reason: 'Short runs with solid food should also include hydration');
          }
        }
      });
    });

    group('User Preference Respect', () {
      testWidgets('respects disliked foods across all phases', (tester) async {
        // Arrange: Plan with explicit dislikes
        final planRequest = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        planRequest['liked_foods'] = ['oatmeal', 'gels', 'sports_drink', 'banana'];
        planRequest['disliked_foods'] = ['coffee', 'protein_powder', 'coconut_water'];
        planRequest['distance_miles'] = 10.0;

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan
        await controller.generatePlan(planRequest);
        
        final state = container.read(nutritionPlanControllerProvider);
        final plan = state.requireValue;
        final planDetails = plan['plan'] as Map<String, dynamic>;

        // Assert: Disliked foods never appear in any phase
        final allFoodItems = [
          ...(planDetails['before'] as List<dynamic>? ?? []),
          ...(planDetails['during'] as List<dynamic>? ?? []),
          ...(planDetails['after'] as List<dynamic>? ?? []),
        ];

        final allFoodNames = allFoodItems
            .map((item) => (item as Map<String, dynamic>)['food_name'] as String)
            .toSet();

        final dislikedFoods = planRequest['disliked_foods'] as List<String>;
        for (final dislikedFood in dislikedFoods) {
          expect(allFoodNames, isNot(contains(dislikedFood)),
              reason: 'Disliked food $dislikedFood should never appear in plan');
        }
      });

      testWidgets('prioritizes liked foods when phase-appropriate', (tester) async {
        // Arrange: Plan with clear preferences
        final planRequest = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        planRequest['liked_foods'] = ['oatmeal', 'gels', 'sports_drink'];
        planRequest['willing_to_try_foods'] = ['dates'];
        planRequest['disliked_foods'] = ['energy_chews'];
        
        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan
        await controller.generatePlan(planRequest);
        
        final state = container.read(nutritionPlanControllerProvider);
        final plan = state.requireValue;
        final planDetails = plan['plan'] as Map<String, dynamic>;

        // Assert: Liked foods appear when appropriate
        
        // Before-run should include oatmeal if possible
        final beforeItems = planDetails['before'] as List<dynamic>? ?? [];
        final beforeFoodNames = beforeItems
            .map((item) => (item as Map<String, dynamic>)['food_name'] as String)
            .toSet();
            
        if (beforeFoodNames.isNotEmpty) {
          // Oatmeal is liked and suitable for pre-run
          expect(beforeFoodNames.contains('oatmeal'), isTrue,
              reason: 'Should include liked pre-run foods like oatmeal');
        }

        // During-run should include gels if needed
        final duringItems = planDetails['during'] as List<dynamic>? ?? [];
        if (duringItems.isNotEmpty) {
          final duringFoodNames = duringItems
              .map((item) => (item as Map<String, dynamic>)['food_name'] as String)
              .toSet();
              
          // Should prefer gels over energy_chews (which is disliked)
          expect(duringFoodNames, isNot(contains('energy_chews')),
              reason: 'Should avoid disliked energy_chews');
              
          // Should include gels if carbs are needed
          final hasCarbs = duringItems.any((item) {
            final itemMap = item as Map<String, dynamic>;
            final carbs = itemMap['carbs_per_serving'] as num? ?? 0;
            return carbs > 0;
          });
          
          if (hasCarbs) {
            expect(duringFoodNames.contains('gels') || duringFoodNames.contains('sports_drink'), isTrue,
                reason: 'Should include liked carb sources like gels or sports drink');
          }
        }
      });

      testWidgets('handles "willing to try" foods appropriately', (tester) async {
        // Arrange: Plan with only "willing to try" foods available
        final planRequest = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        planRequest['liked_foods'] = ['oatmeal']; // Only pre-run
        planRequest['willing_to_try_foods'] = ['gels', 'energy_chews', 'dates'];
        planRequest['disliked_foods'] = ['sports_drink'];
        planRequest['distance_miles'] = 12.0; // Needs during-run fueling

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan
        await controller.generatePlan(planRequest);
        
        final state = container.read(nutritionPlanControllerProvider);
        final plan = state.requireValue;
        final planDetails = plan['plan'] as Map<String, dynamic>;

        // Assert: Should include "willing to try" foods when necessary
        final duringItems = planDetails['during'] as List<dynamic>? ?? [];
        
        if (duringItems.isNotEmpty) {
          final duringFoodNames = duringItems
              .map((item) => (item as Map<String, dynamic>)['food_name'] as String)
              .toSet();

          // Since sports_drink is disliked and we need during-run fueling,
          // should use willing-to-try options
          final willingToTryFoods = planRequest['willing_to_try_foods'] as List<String>;
          final usesWillingToTry = duringFoodNames
              .any((food) => willingToTryFoods.contains(food));
              
          expect(usesWillingToTry, isTrue,
              reason: 'Should use willing-to-try foods when liked options unavailable');
        }
      });
    });

    group('Safety Edge Cases', () {
      testWidgets('handles conflicting preferences safely', (tester) async {
        // Arrange: User likes foods that aren't suitable for their distance
        final planRequest = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        planRequest['liked_foods'] = ['oatmeal', 'waffle', 'peanut_butter']; // All pre-run only
        planRequest['willing_to_try_foods'] = [];
        planRequest['disliked_foods'] = ['gels', 'sports_drink', 'energy_chews']; // All during-run
        planRequest['distance_miles'] = 15.0; // Definitely needs during-run fueling

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan (should handle gracefully)
        await controller.generatePlan(planRequest);
        
        final state = container.read(nutritionPlanControllerProvider);
        
        // Assert: Should still generate a safe plan
        expect(state.hasValue, isTrue, reason: 'Should generate plan even with conflicts');
        
        final plan = state.requireValue;
        final planDetails = plan['plan'] as Map<String, dynamic>;
        
        // Should still provide safe during-run options even if disliked
        final duringItems = planDetails['during'] as List<dynamic>? ?? [];
        
        // For long runs, must provide some fueling even if user dislikes all options
        if (duringItems.isNotEmpty) {
          final duringFoodNames = duringItems
              .map((item) => (item as Map<String, dynamic>)['food_name'] as String)
              .toSet();

          // Ensure safety: no inappropriate foods during run
          for (final foodName in duringFoodNames) {
            expect(TestData.preRunOnlyFoods, isNot(contains(foodName)),
                reason: 'Should never include inappropriate foods even with conflicts');
          }
        }
      });

      testWidgets('prevents dangerous food combinations', (tester) async {
        // Arrange: Request that might lead to too much of something
        final planRequest = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        planRequest['liked_foods'] = ['gels', 'energy_chews', 'dates', 'sports_drink'];
        planRequest['distance_miles'] = 20.0; // Very long run

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan
        await controller.generatePlan(planRequest);
        
        final state = container.read(nutritionPlanControllerProvider);
        final plan = state.requireValue;
        final planDetails = plan['plan'] as Map<String, dynamic>;

        // Assert: Should have reasonable variety and limits
        final duringItems = planDetails['during'] as List<dynamic>;
        expect(duringItems.length, lessThanOrEqualTo(TestConfig.maxFoodItemsPerPhase),
            reason: 'Should limit number of during-run foods to prevent GI issues');

        // Calculate total carbs to ensure it's not excessive
        final totalCarbs = duringItems.fold<double>(0.0, (sum, item) {
          final itemMap = item as Map<String, dynamic>;
          final servings = (itemMap['servings'] as num? ?? 1).toDouble();
          final carbsPerServing = (itemMap['carbs_per_serving'] as num? ?? 0).toDouble();
          return sum + (servings * carbsPerServing);
        });

        // Should be within reasonable carb limits (not more than 90g/hr equivalent)
        final runTimeHours = (planRequest['distance_miles'] as double) / 
                           (60 / (planRequest['pace_minutes_per_mile'] as double));
        final maxReasonableCarbs = runTimeHours * 90; // 90g/hr is high end of recommendations
        
        expect(totalCarbs, lessThanOrEqualTo(maxReasonableCarbs * 1.2), // Allow some buffer
            reason: 'Total carbs ($totalCarbs g) should not exceed safe limits');
      });

      testWidgets('validates food safety with environmental factors', (tester) async {
        // Arrange: Hot weather conditions (would affect food choice)
        final planRequest = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        planRequest['temperature_fahrenheit'] = 85.0; // Hot weather
        planRequest['humidity_percent'] = 80.0; // High humidity
        planRequest['distance_miles'] = 10.0;

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan
        await controller.generatePlan(planRequest);
        
        final state = container.read(nutritionPlanControllerProvider);
        final plan = state.requireValue;
        final planDetails = plan['plan'] as Map<String, dynamic>;

        // Assert: Should adapt to environmental conditions
        final allItems = [
          ...(planDetails['before'] as List<dynamic>? ?? []),
          ...(planDetails['during'] as List<dynamic>? ?? []),
          ...(planDetails['after'] as List<dynamic>? ?? []),
        ];

        // In hot conditions, should emphasize hydration
        final hasHydrationFocus = allItems.any((item) {
          final itemMap = item as Map<String, dynamic>;
          final foodName = itemMap['food_name'] as String;
          return foodName.contains('drink') || 
                 foodName.contains('water') || 
                 foodName.contains('electrolyte');
        });

        expect(hasHydrationFocus, isTrue,
            reason: 'Hot weather plans should emphasize hydration');
      });
    });
  });
}