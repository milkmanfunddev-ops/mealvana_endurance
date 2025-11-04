/// Macro Target Validation Tests
/// 
/// These tests ensure that nutrition plans meet user macro targets within
/// acceptable tolerance levels. This validates the core value proposition
/// of the app - accurate, personalized nutrition recommendations.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/nutrition_plan/presentation/controllers/nutrition_plan_controller.dart';

import '../helpers/test_data.dart';
import '../helpers/mock_providers.dart';
import '../helpers/test_config.dart';

void main() {
  group('Macro Target Validation Tests', () {
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

    group('Macro Target Preservation', () {
      testWidgets('user-adjusted macro targets are preserved in response', (tester) async {
        // Arrange: Plan request with user-adjusted macro targets
        final planRequest = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        // Using adjusted targets from TestData (user increased from defaults)
        expect(planRequest['macro_targets'], isNotNull);
        
        final macroTargets = planRequest['macro_targets'] as Map<String, dynamic>;
        final preRunTargets = macroTargets['pre_run'] as Map<String, dynamic>;
        final duringRunTargets = macroTargets['during_run'] as Map<String, dynamic>;
        final postRunTargets = macroTargets['post_run'] as Map<String, dynamic>;

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate nutrition plan
        await controller.generatePlan(planRequest);

        final state = container.read(nutritionPlanControllerProvider);
        expect(state.hasValue, isTrue, reason: 'Plan generation should succeed');
        
        final plan = state.requireValue;
        expect(plan, contains('macro_targets'));

        // Assert: User-adjusted macro targets are preserved exactly
        final returnedMacros = plan['macro_targets'] as Map<String, dynamic>;
        
        // Pre-run macro preservation
        final returnedPreRun = returnedMacros['pre_run'] as Map<String, dynamic>;
        expect(returnedPreRun['carbs_g'], equals(preRunTargets['carbs_g']),
            reason: 'Pre-run carbs should match user-adjusted value of ${preRunTargets['carbs_g']}g');
        expect(returnedPreRun['protein_g'], equals(preRunTargets['protein_g']),
            reason: 'Pre-run protein should match user-adjusted value of ${preRunTargets['protein_g']}g');
        expect(returnedPreRun['water_ml'], equals(preRunTargets['water_ml']),
            reason: 'Pre-run water should match user-adjusted value of ${preRunTargets['water_ml']}ml');
        expect(returnedPreRun['sodium_mg'], equals(preRunTargets['sodium_mg']),
            reason: 'Pre-run sodium should match user-adjusted value of ${preRunTargets['sodium_mg']}mg');

        // During-run macro preservation
        final returnedDuringRun = returnedMacros['during_run'] as Map<String, dynamic>;
        expect(returnedDuringRun['carbs_total_g'], equals(duringRunTargets['carbs_total_g']),
            reason: 'During-run carbs should match user-adjusted value of ${duringRunTargets['carbs_total_g']}g');
        expect(returnedDuringRun['sodium_total_mg'], equals(duringRunTargets['sodium_total_mg']),
            reason: 'During-run sodium should match user-adjusted value of ${duringRunTargets['sodium_total_mg']}mg');
        expect(returnedDuringRun['water_total_ml'], equals(duringRunTargets['water_total_ml']),
            reason: 'During-run water should match user-adjusted value of ${duringRunTargets['water_total_ml']}ml');

        // Post-run macro preservation
        final returnedPostRun = returnedMacros['post_run'] as Map<String, dynamic>;
        expect(returnedPostRun['carbs_g'], equals(postRunTargets['carbs_g']),
            reason: 'Post-run carbs should match user-adjusted value of ${postRunTargets['carbs_g']}g');
        expect(returnedPostRun['protein_g'], equals(postRunTargets['protein_g']),
            reason: 'Post-run protein should match user-adjusted value of ${postRunTargets['protein_g']}g');
        expect(returnedPostRun['water_ml'], equals(postRunTargets['water_ml']),
            reason: 'Post-run water should match user-adjusted value of ${postRunTargets['water_ml']}ml');
        expect(returnedPostRun['sodium_mg'], equals(postRunTargets['sodium_mg']),
            reason: 'Post-run sodium should match user-adjusted value of ${postRunTargets['sodium_mg']}mg');
      });

      testWidgets('conservative targets for beginner athletes are respected', (tester) async {
        // Arrange: Beginner athlete with conservative targets
        final planRequest = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        planRequest['gut_training_level'] = 'beginner';
        planRequest['macro_targets'] = TestData.testMacroTargetsConservative;

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan
        await controller.generatePlan(planRequest);

        final state = container.read(nutritionPlanControllerProvider);
        final plan = state.requireValue;
        
        // Assert: Conservative targets are preserved
        final returnedMacros = plan['macro_targets'] as Map<String, dynamic>;
        final preRun = returnedMacros['pre_run'] as Map<String, dynamic>;
        
        expect(preRun['carbs_g'], equals(50.0),
            reason: 'Beginner should have lower carb targets');
        expect(preRun['protein_g'], equals(15.0),
            reason: 'Beginner should have conservative protein targets');
            
        final duringRun = returnedMacros['during_run'] as Map<String, dynamic>;
        expect(duringRun['carbs_total_g'], equals(25.0),
            reason: 'Beginner should have lower during-run carb targets');
      });
    });

    group('Food Recommendation Alignment', () {
      testWidgets('pre-run food recommendations align with macro targets', (tester) async {
        // Arrange: Standard plan request
        final planRequest = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        final macroTargets = planRequest['macro_targets'] as Map<String, dynamic>;
        final preRunTargets = macroTargets['pre_run'] as Map<String, dynamic>;
        final targetCarbs = preRunTargets['carbs_g'] as double; // 75.0g

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan
        await controller.generatePlan(planRequest);

        final state = container.read(nutritionPlanControllerProvider);
        final plan = state.requireValue;
        final planDetails = plan['plan'] as Map<String, dynamic>;
        
        expect(planDetails, contains('before'));
        final beforeItems = planDetails['before'] as List<dynamic>;
        expect(beforeItems, isNotEmpty, reason: 'Should have pre-run food recommendations');

        // Assert: Calculate actual carbs from food recommendations
        double actualPreRunCarbs = 0.0;
        double actualPreRunProtein = 0.0;

        for (final item in beforeItems) {
          final itemMap = item as Map<String, dynamic>;
          final servings = (itemMap['servings'] as num? ?? 1).toDouble();
          final carbsPerServing = (itemMap['carbs_per_serving'] as num? ?? 0).toDouble();
          final proteinPerServing = (itemMap['protein_per_serving'] as num? ?? 0).toDouble();
          
          actualPreRunCarbs += servings * carbsPerServing;
          actualPreRunProtein += servings * proteinPerServing;
        }

        // Verify carbs are within acceptable tolerance
        expect(actualPreRunCarbs, closeTo(targetCarbs, TestConfig.carbToleranceGrams),
            reason: 'Pre-run food carbs (${actualPreRunCarbs.toStringAsFixed(1)}g) should be close to target ($targetCarbs g)');

        // Verify protein is reasonable
        final targetProtein = preRunTargets['protein_g'] as double;
        expect(actualPreRunProtein, closeTo(targetProtein, TestConfig.proteinToleranceGrams),
            reason: 'Pre-run food protein (${actualPreRunProtein.toStringAsFixed(1)}g) should be close to target ($targetProtein g)');
      });

      testWidgets('during-run food recommendations align with macro targets', (tester) async {
        // Arrange: Plan requiring substantial during-run fueling
        final planRequest = TestData.testHalfMarathonRequest.cast<String, dynamic>();
        
        // Set explicit during-run targets
        final macroTargets = {
          'pre_run': {'carbs_g': 100.0, 'protein_g': 20.0, 'fat_g': 15.0, 'water_ml': 600.0, 'sodium_mg': 300.0},
          'during_run': {'carbs_total_g': 60.0, 'sodium_total_mg': 800.0, 'water_total_ml': 1000.0},
          'post_run': {'carbs_g': 80.0, 'protein_g': 30.0, 'fat_g': 10.0, 'water_ml': 600.0, 'sodium_mg': 400.0},
        };
        planRequest['macro_targets'] = macroTargets;

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan
        await controller.generatePlan(planRequest);

        final state = container.read(nutritionPlanControllerProvider);
        final plan = state.requireValue;
        final planDetails = plan['plan'] as Map<String, dynamic>;
        
        final duringItems = planDetails['during'] as List<dynamic>? ?? [];
        expect(duringItems, isNotEmpty, reason: 'Half marathon should have during-run fueling');

        // Assert: Calculate actual during-run macros
        double actualDuringCarbs = 0.0;
        double actualDuringSodium = 0.0;

        for (final item in duringItems) {
          final itemMap = item as Map<String, dynamic>;
          final servings = (itemMap['servings'] as num? ?? 1).toDouble();
          final carbsPerServing = (itemMap['carbs_per_serving'] as num? ?? 0).toDouble();
          final sodiumPerServing = (itemMap['sodium_per_serving'] as num? ?? 0).toDouble();
          
          actualDuringCarbs += servings * carbsPerServing;
          actualDuringSodium += servings * sodiumPerServing;
        }

        final targetDuringCarbs = macroTargets['during_run']!['carbs_total_g']!;
        final targetDuringSodium = macroTargets['during_run']!['sodium_total_mg']!;

        expect(actualDuringCarbs, closeTo(targetDuringCarbs, TestConfig.carbToleranceGrams),
            reason: 'During-run food carbs (${actualDuringCarbs.toStringAsFixed(1)}g) should be close to target ($targetDuringCarbs g)');

        expect(actualDuringSodium, closeTo(targetDuringSodium, TestConfig.sodiumToleranceMg),
            reason: 'During-run sodium (${actualDuringSodium.toStringAsFixed(1)}mg) should be close to target ($targetDuringSodium mg)');
      });

      testWidgets('post-run food recommendations support recovery targets', (tester) async {
        // Arrange: Plan with recovery-focused post-run targets
        final planRequest = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        final macroTargets = planRequest['macro_targets'] as Map<String, dynamic>;
        final postRunTargets = macroTargets['post_run'] as Map<String, dynamic>;
        
        final targetCarbs = postRunTargets['carbs_g'] as double; // 80.0g
        final targetProtein = postRunTargets['protein_g'] as double; // 30.0g

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan
        await controller.generatePlan(planRequest);

        final state = container.read(nutritionPlanControllerProvider);
        final plan = state.requireValue;
        final planDetails = plan['plan'] as Map<String, dynamic>;
        
        final afterItems = planDetails['after'] as List<dynamic>? ?? [];
        expect(afterItems, isNotEmpty, reason: 'Should have post-run recovery foods');

        // Assert: Calculate actual post-run macros
        double actualPostRunCarbs = 0.0;
        double actualPostRunProtein = 0.0;

        for (final item in afterItems) {
          final itemMap = item as Map<String, dynamic>;
          final servings = (itemMap['servings'] as num? ?? 1).toDouble();
          final carbsPerServing = (itemMap['carbs_per_serving'] as num? ?? 0).toDouble();
          final proteinPerServing = (itemMap['protein_per_serving'] as num? ?? 0).toDouble();
          
          actualPostRunCarbs += servings * carbsPerServing;
          actualPostRunProtein += servings * proteinPerServing;
        }

        expect(actualPostRunCarbs, closeTo(targetCarbs, TestConfig.carbToleranceGrams),
            reason: 'Post-run food carbs (${actualPostRunCarbs.toStringAsFixed(1)}g) should be close to target ($targetCarbs g)');

        expect(actualPostRunProtein, closeTo(targetProtein, TestConfig.proteinToleranceGrams),
            reason: 'Post-run food protein (${actualPostRunProtein.toStringAsFixed(1)}g) should be close to target ($targetProtein g)');

        // Recovery foods should have good protein content
        expect(actualPostRunProtein, greaterThan(20.0),
            reason: 'Post-run foods should provide substantial protein for recovery');
      });
    });

    group('Hydration and Electrolyte Validation', () {
      testWidgets('hydration recommendations meet fluid targets', (tester) async {
        // Arrange: Plan with specific hydration targets
        final planRequest = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        final macroTargets = planRequest['macro_targets'] as Map<String, dynamic>;
        
        final preRunWaterTarget = macroTargets['pre_run']!['water_ml']! as double;
        final duringRunWaterTarget = macroTargets['during_run']!['water_total_ml']! as double;
        final postRunWaterTarget = macroTargets['post_run']!['water_ml']! as double;

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan
        await controller.generatePlan(planRequest);

        final state = container.read(nutritionPlanControllerProvider);
        final plan = state.requireValue;
        final planDetails = plan['plan'] as Map<String, dynamic>;

        // Assert: Calculate hydration from all phases
        final phases = ['before', 'during', 'after'];
        final targets = [preRunWaterTarget, duringRunWaterTarget, postRunWaterTarget];
        
        for (int i = 0; i < phases.length; i++) {
          final phaseName = phases[i];
          final targetWater = targets[i];
          final items = planDetails[phaseName] as List<dynamic>? ?? [];
          
          double actualWater = 0.0;
          
          for (final item in items) {
            final itemMap = item as Map<String, dynamic>;
            final servings = (itemMap['servings'] as num? ?? 1).toDouble();
            final waterPerServing = (itemMap['water_ml_per_serving'] as num? ?? 0).toDouble();
            
            actualWater += servings * waterPerServing;
            
            // Also count fluid foods (sports drinks, coconut water, etc.)
            final foodName = itemMap['food_name'] as String;
            if (isFluidFood(foodName)) {
              final fluidVolume = estimateFluidVolume(foodName, servings);
              actualWater += fluidVolume;
            }
          }

          if (targetWater > 0) {
            expect(actualWater, greaterThan(targetWater * 0.7),
                reason: '$phaseName-run hydration (${actualWater.toStringAsFixed(0)}ml) should approach target ($targetWater ml)');
          }
        }
      });

      testWidgets('sodium recommendations meet electrolyte needs', (tester) async {
        // Arrange: Hot weather plan requiring higher sodium
        final planRequest = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        planRequest['temperature_fahrenheit'] = 85.0; // Hot conditions
        planRequest['distance_miles'] = 15.0; // Long run
        
        // Increase sodium targets for hot weather
        final macroTargets = planRequest['macro_targets'] as Map<String, dynamic>;
        macroTargets['during_run']['sodium_total_mg'] = 1000.0; // Higher for heat
        macroTargets['post_run']['sodium_mg'] = 600.0; // Recovery sodium

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan
        await controller.generatePlan(planRequest);

        final state = container.read(nutritionPlanControllerProvider);
        final plan = state.requireValue;
        final planDetails = plan['plan'] as Map<String, dynamic>;

        // Assert: Calculate sodium across all phases
        double totalSodium = 0.0;
        
        for (final phaseName in ['before', 'during', 'after']) {
          final items = planDetails[phaseName] as List<dynamic>? ?? [];
          
          for (final item in items) {
            final itemMap = item as Map<String, dynamic>;
            final servings = (itemMap['servings'] as num? ?? 1).toDouble();
            final sodiumPerServing = (itemMap['sodium_per_serving'] as num? ?? 0).toDouble();
            
            totalSodium += servings * sodiumPerServing;
          }
        }

        // For hot weather long runs, should have substantial sodium
        expect(totalSodium, greaterThan(800.0),
            reason: 'Hot weather long runs should provide substantial sodium (actual: ${totalSodium.toStringAsFixed(0)}mg)');

        // Should not exceed reasonable upper limits
        expect(totalSodium, lessThan(2000.0),
            reason: 'Total sodium should not exceed safe upper limits');
      });

      testWidgets('electrolyte balance is maintained across phases', (tester) async {
        // Arrange: Multi-phase plan
        final planRequest = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        planRequest['distance_miles'] = 12.0; // Requires all phases

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan
        await controller.generatePlan(planRequest);

        final state = container.read(nutritionPlanControllerProvider);
        final plan = state.requireValue;
        final planDetails = plan['plan'] as Map<String, dynamic>;

        // Assert: Verify electrolyte distribution makes sense
        final phases = ['before', 'during', 'after'];
        final phaseSodium = <String, double>{};
        
        for (final phaseName in phases) {
          final items = planDetails[phaseName] as List<dynamic>? ?? [];
          double sodium = 0.0;
          
          for (final item in items) {
            final itemMap = item as Map<String, dynamic>;
            final servings = (itemMap['servings'] as num? ?? 1).toDouble();
            final sodiumPerServing = (itemMap['sodium_per_serving'] as num? ?? 0).toDouble();
            sodium += servings * sodiumPerServing;
          }
          
          phaseSodium[phaseName] = sodium;
        }

        // During-run should have the highest sodium concentration for longer runs
        final duringRunSodium = phaseSodium['during'] ?? 0.0;
        if (duringRunSodium > 0) {
          // During-run sodium should be substantial for 12-mile runs
          expect(duringRunSodium, greaterThan(300.0),
              reason: 'During-run sodium should be substantial for longer runs');
        }

        // Post-run should have recovery-focused electrolytes
        final afterRunSodium = phaseSodium['after'] ?? 0.0;
        if (afterRunSodium > 0) {
          expect(afterRunSodium, greaterThan(100.0),
              reason: 'Post-run should include recovery electrolytes');
        }
      });
    });

    group('Edge Case Validation', () {
      testWidgets('handles zero carb targets appropriately', (tester) async {
        // Arrange: Very short run with minimal carb needs
        final planRequest = TestData.test5KRequest.cast<String, dynamic>();
        
        // Override with minimal targets
        final macroTargets = {
          'pre_run': {'carbs_g': 30.0, 'protein_g': 10.0, 'water_ml': 300.0, 'sodium_mg': 100.0},
          'during_run': {'carbs_total_g': 0.0, 'sodium_total_mg': 200.0, 'water_total_ml': 300.0},
          'post_run': {'carbs_g': 40.0, 'protein_g': 15.0, 'water_ml': 400.0, 'sodium_mg': 200.0},
        };
        planRequest['macro_targets'] = macroTargets;

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan
        await controller.generatePlan(planRequest);

        final state = container.read(nutritionPlanControllerProvider);
        final plan = state.requireValue;
        final planDetails = plan['plan'] as Map<String, dynamic>;

        // Assert: Should handle zero carb targets gracefully
        final duringItems = planDetails['during'] as List<dynamic>? ?? [];
        
        if (duringItems.isEmpty) {
          // Zero carb target results in no during-run fueling - acceptable for short runs
          expect(true, isTrue, reason: 'Short runs may not need during-run fueling');
        } else {
          // If there are during-run items, they should be hydration-focused
          double totalDuringCarbs = 0.0;
          bool hasHydration = false;
          
          for (final item in duringItems) {
            final itemMap = item as Map<String, dynamic>;
            final servings = (itemMap['servings'] as num? ?? 1).toDouble();
            final carbsPerServing = (itemMap['carbs_per_serving'] as num? ?? 0).toDouble();
            final foodName = itemMap['food_name'] as String;
            
            totalDuringCarbs += servings * carbsPerServing;
            if (isFluidFood(foodName)) {
              hasHydration = true;
            }
          }

          expect(totalDuringCarbs, lessThan(15.0),
              reason: 'Zero carb target should result in minimal carb recommendations');
          expect(hasHydration, isTrue,
              reason: 'Should still provide hydration even with zero carb targets');
        }
      });

      testWidgets('validates extreme macro targets safely', (tester) async {
        // Arrange: Unrealistically high targets (testing limits)
        final planRequest = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        
        final extremeTargets = {
          'pre_run': {'carbs_g': 300.0, 'protein_g': 100.0, 'water_ml': 2000.0, 'sodium_mg': 2000.0},
          'during_run': {'carbs_total_g': 150.0, 'sodium_total_mg': 3000.0, 'water_total_ml': 3000.0},
          'post_run': {'carbs_g': 200.0, 'protein_g': 80.0, 'water_ml': 1500.0, 'sodium_mg': 1500.0},
        };
        planRequest['macro_targets'] = extremeTargets;

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan (should handle gracefully)
        await controller.generatePlan(planRequest);

        final state = container.read(nutritionPlanControllerProvider);
        
        // Assert: Should generate plan without crashing
        expect(state.hasValue, isTrue, reason: 'Should handle extreme targets without crashing');
        
        final plan = state.requireValue;
        final planDetails = plan['plan'] as Map<String, dynamic>;
        
        // Should limit recommendations to safe levels
        for (final phaseName in ['before', 'during', 'after']) {
          final items = planDetails[phaseName] as List<dynamic>? ?? [];
          expect(items.length, lessThanOrEqualTo(TestConfig.maxFoodItemsPerPhase),
              reason: 'Should not recommend excessive number of foods even for extreme targets');
        }
      });

      testWidgets('maintains macro ratios within reasonable bounds', (tester) async {
        // Arrange: Plan with specific macro ratios
        final planRequest = TestData.testNutritionPlanRequest.cast<String, dynamic>();

        final controller = container.read(nutritionPlanControllerProvider.notifier);

        // Act: Generate plan
        await controller.generatePlan(planRequest);

        final state = container.read(nutritionPlanControllerProvider);
        final plan = state.requireValue;
        final planDetails = plan['plan'] as Map<String, dynamic>;

        // Assert: Verify macro ratios are reasonable across all phases
        for (final phaseName in ['before', 'after']) { // Skip 'during' as it's carb-focused
          final items = planDetails[phaseName] as List<dynamic>? ?? [];
          if (items.isEmpty) continue;
          
          double totalCarbs = 0.0;
          double totalProtein = 0.0;
          double totalFat = 0.0;
          
          for (final item in items) {
            final itemMap = item as Map<String, dynamic>;
            final servings = (itemMap['servings'] as num? ?? 1).toDouble();
            totalCarbs += servings * (itemMap['carbs_per_serving'] as num? ?? 0).toDouble();
            totalProtein += servings * (itemMap['protein_per_serving'] as num? ?? 0).toDouble();
            totalFat += servings * (itemMap['fat_per_serving'] as num? ?? 0).toDouble();
          }
          
          final totalCalories = (totalCarbs * 4) + (totalProtein * 4) + (totalFat * 9);
          
          if (totalCalories > 0) {
            final carbPercent = (totalCarbs * 4) / totalCalories;
            final proteinPercent = (totalProtein * 4) / totalCalories;
            final fatPercent = (totalFat * 9) / totalCalories;
            
            // Pre-run and post-run should have balanced macros
            if (phaseName == 'before') {
              expect(carbPercent, greaterThan(0.4), 
                  reason: 'Pre-run should be carb-focused (≥40% carbs)');
              expect(carbPercent, lessThan(0.8), 
                  reason: 'Pre-run should not be excessively carb-heavy (≤80% carbs)');
            }
            
            if (phaseName == 'after') {
              expect(proteinPercent, greaterThan(0.15), 
                  reason: 'Post-run should include adequate protein (≥15%)');
            }
            
            // All phases should have reasonable fat limits
            expect(fatPercent, lessThan(0.4), 
                reason: '$phaseName should not be excessively high-fat (≤40% fat)');
          }
        }
      });
    });
  });

  // Helper functions
  bool isFluidFood(String foodName) {
    return foodName.contains('drink') || 
           foodName.contains('water') || 
           foodName.contains('juice') || 
           foodName.toLowerCase().contains('coconut');
  }

  double estimateFluidVolume(String foodName, double servings) {
    // Rough estimates for common fluid foods
    if (foodName.contains('sports_drink')) {
      return servings * 240; // ~8 fl oz per serving
    } else if (foodName.contains('coconut_water')) {
      return servings * 240;
    } else if (foodName.contains('juice')) {
      return servings * 240;
    }
    return 0.0;
  }
}