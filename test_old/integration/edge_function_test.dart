/// Edge Function Integration Tests
/// 
/// These tests validate the AI nutrition plan generation edge functions
/// and error handling. Critical for ensuring the revenue-generating 
/// AI functionality works correctly and degrades gracefully.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/test_data.dart';
import '../helpers/test_config.dart';

void main() {
  group('Edge Function Integration Tests', () {
    late SupabaseClient supabase;

    setUpAll(() {
      // Validate test environment before running
      final configError = TestConfig.validateConfiguration();
      if (configError != null) {
        fail('Test configuration invalid: $configError');
      }

      supabase = SupabaseClient(
        TestConfig.supabaseUrl,
        TestConfig.supabaseAnonKey,
      );
    });

    group('Generate AI Nutrition Plan Function', () {
      testWidgets('successfully generates plan with adjusted macro targets', 
          (tester) async {
        // Skip if network tests disabled
        if (!TestConfig.enableNetworkTests) {
          return;
        }

        // Arrange: Create request with user-adjusted macro targets
        final requestData = TestData.testNutritionPlanRequest;

        // Act: Call the edge function
        final response = await supabase.functions.invoke(
          'generate-ai-nutrition-plan',
          body: requestData,
        ).timeout(TestConfig.networkTestTimeout);

        // Assert: Verify successful response
        expect(response.status, lessThan(400), 
            reason: 'Edge function should succeed. Status: ${response.status}, Response: ${response.data}');

        final responseData = response.data as Map<String, dynamic>;
        
        // Verify response structure
        expect(responseData, containsPair('success', true));
        expect(responseData, contains('plan'));
        expect(responseData, contains('macro_targets'));
        expect(responseData, contains('detailed_message'));

        // Extract and validate plan structure
        final plan = responseData['plan'] as Map<String, dynamic>;
        expect(plan, contains('before'));
        expect(plan, contains('during'));
        expect(plan, contains('after'));

        // Validate each phase has food items
        final beforeItems = plan['before'] as List<dynamic>;
        final duringItems = plan['during'] as List<dynamic>;
        final afterItems = plan['after'] as List<dynamic>;

        expect(beforeItems, isNotEmpty, reason: 'Should have before-run food items');
        expect(duringItems, isNotEmpty, reason: 'Should have during-run food items for 10K');
        expect(afterItems, isNotEmpty, reason: 'Should have after-run food items');

        // Validate food item structure
        for (final item in beforeItems) {
          final itemMap = item as Map<String, dynamic>;
          expect(itemMap, contains('food_name'));
          expect(itemMap, contains('servings'));
          expect(itemMap, contains('carbs_per_serving'));
          expect(itemMap['servings'], isA<num>());
          expect(itemMap['carbs_per_serving'], isA<num>());
        }

        // CRITICAL TEST: Verify adjusted macro targets are preserved
        final returnedMacros = responseData['macro_targets'] as Map<String, dynamic>;
        final returnedPreRun = returnedMacros['pre_run'] as Map<String, dynamic>;
        final returnedDuringRun = returnedMacros['during_run'] as Map<String, dynamic>;
        final returnedPostRun = returnedMacros['post_run'] as Map<String, dynamic>;

        final originalMacros = TestData.testMacroTargets;
        
        expect(returnedPreRun['carbs_g'], equals(originalMacros['pre_run']!['carbs_g']),
            reason: 'Pre-run carbs should match adjusted value');
        expect(returnedPreRun['protein_g'], equals(originalMacros['pre_run']!['protein_g']),
            reason: 'Pre-run protein should match adjusted value');
        expect(returnedDuringRun['carbs_total_g'], equals(originalMacros['during_run']!['carbs_total_g']),
            reason: 'During-run carbs should match adjusted value');
        expect(returnedPostRun['carbs_g'], equals(originalMacros['post_run']!['carbs_g']),
            reason: 'Post-run carbs should match adjusted value');
      });

      testWidgets('validates food recommendations align with macro targets', 
          (tester) async {
        if (!TestConfig.enableNetworkTests) return;

        // Arrange: Request with specific macro expectations
        final requestData = TestData.testNutritionPlanRequest;
        final expectedMacros = TestData.testMacroTargets;

        // Act: Generate plan
        final response = await supabase.functions.invoke(
          'generate-ai-nutrition-plan',
          body: requestData,
        ).timeout(TestConfig.networkTestTimeout);

        expect(response.status, lessThan(400));
        final responseData = response.data as Map<String, dynamic>;
        final plan = responseData['plan'] as Map<String, dynamic>;

        // Assert: Calculate actual macros from food recommendations
        final phases = ['before', 'during', 'after'];
        final phaseKeys = ['pre_run', 'during_run', 'post_run'];
        
        for (int i = 0; i < phases.length; i++) {
          final phaseName = phases[i];
          final phaseKey = phaseKeys[i];
          final items = plan[phaseName] as List<dynamic>;
          
          double totalCarbs = 0.0;
          double totalProtein = 0.0;
          
          for (final item in items) {
            final itemMap = item as Map<String, dynamic>;
            final servings = (itemMap['servings'] as num).toDouble();
            final carbsPerServing = (itemMap['carbs_per_serving'] as num? ?? 0).toDouble();
            final proteinPerServing = (itemMap['protein_per_serving'] as num? ?? 0).toDouble();
            
            totalCarbs += servings * carbsPerServing;
            totalProtein += servings * proteinPerServing;
          }

          // Validate carb targets (within tolerance)
          final expectedCarbs = phaseKey == 'during_run' 
              ? expectedMacros[phaseKey]!['carbs_total_g']!
              : expectedMacros[phaseKey]!['carbs_g']!;
              
          expect(totalCarbs, closeTo(expectedCarbs, TestConfig.carbToleranceGrams),
              reason: '$phaseName carbs (${totalCarbs.toStringAsFixed(1)}g) should be close to target ($expectedCarbs g)');

          // Validate protein targets for phases that have protein targets
          if (phaseKey != 'during_run') {
            final expectedProtein = expectedMacros[phaseKey]!['protein_g']!;
            expect(totalProtein, closeTo(expectedProtein, TestConfig.proteinToleranceGrams),
                reason: '$phaseName protein (${totalProtein.toStringAsFixed(1)}g) should be close to target ($expectedProtein g)');
          }
        }
      });

      testWidgets('meets tightened nutrient targets within tolerance', 
          (tester) async {
        if (!TestConfig.enableNetworkTests) return;

        // Arrange: Request with specific macro targets
        final requestData = TestData.testNutritionPlanRequest;
        final expectedMacros = TestData.testMacroTargets;

        // Act: Generate plan
        final response = await supabase.functions.invoke(
          'generate-ai-nutrition-plan',
          body: requestData,
        ).timeout(TestConfig.networkTestTimeout);

        expect(response.status, lessThan(400));
        final responseData = response.data as Map<String, dynamic>;
        final plan = responseData['plan'] as Map<String, dynamic>;

        // Assert: Verify improved tolerances for carbs, sodium, and fluids
        final phases = [
          {'name': 'before', 'key': 'pre_run'},
          {'name': 'during', 'key': 'during_run'},
          {'name': 'after', 'key': 'post_run'}
        ];
        
        for (final phase in phases) {
          final phaseName = phase['name'] as String;
          final phaseKey = phase['key'] as String;
          final items = plan[phaseName] as List<dynamic>;
          
          double totalCarbs = 0.0;
          double totalSodium = 0.0;
          double totalFluids = 0.0;
          
          for (final item in items) {
            final itemMap = item as Map<String, dynamic>;
            final servings = (itemMap['servings'] as num).toDouble();
            
            // Handle different property names across phases
            final carbsKey = phaseKey == 'during_run' ? 'carbs_grams' : 'carbs_grams';
            final sodiumKey = 'sodium_mg';
            final fluidsKey = 'fluids_ml';
            
            totalCarbs += (itemMap[carbsKey] as num? ?? 0).toDouble();
            totalSodium += (itemMap[sodiumKey] as num? ?? 0).toDouble();
            totalFluids += (itemMap[fluidsKey] as num? ?? 0).toDouble();
          }

          // Get expected targets
          final expectedCarbs = phaseKey == 'during_run' 
              ? expectedMacros[phaseKey]!['carbs_total_g']!
              : expectedMacros[phaseKey]!['carbs_g']!;
          final expectedSodium = phaseKey == 'during_run'
              ? expectedMacros[phaseKey]!['sodium_total_mg']!
              : expectedMacros[phaseKey]!['sodium_mg']!;
          final expectedFluids = phaseKey == 'during_run'
              ? expectedMacros[phaseKey]!['water_total_ml']!
              : expectedMacros[phaseKey]!['water_ml']!;

          // CRITICAL: Verify tightened tolerances
          expect(totalCarbs, closeTo(expectedCarbs, 10.0),
              reason: '$phaseName carbs (${totalCarbs.toStringAsFixed(1)}g) should be within ±10g of target (${expectedCarbs}g)');
              
          expect(totalSodium, closeTo(expectedSodium, 20.0),
              reason: '$phaseName sodium (${totalSodium.toStringAsFixed(0)}mg) should be within ±20mg of target (${expectedSodium}mg)');
              
          expect(totalFluids, closeTo(expectedFluids, 20.0),
              reason: '$phaseName fluids (${totalFluids.toStringAsFixed(0)}ml) should be within ±20ml of target (${expectedFluids}ml)');
        }
      });

      testWidgets('generates clean serving sizes in 0.5 increments', 
          (tester) async {
        if (!TestConfig.enableNetworkTests) return;

        // Arrange: Standard request
        final requestData = TestData.testNutritionPlanRequest;

        // Act: Generate plan
        final response = await supabase.functions.invoke(
          'generate-ai-nutrition-plan',
          body: requestData,
        ).timeout(TestConfig.networkTestTimeout);

        expect(response.status, lessThan(400));
        final responseData = response.data as Map<String, dynamic>;
        final plan = responseData['plan'] as Map<String, dynamic>;

        // Assert: All servings should be in 0.5 increments
        final allItems = [
          ...(plan['before'] as List<dynamic>),
          ...(plan['during'] as List<dynamic>),
          ...(plan['after'] as List<dynamic>),
        ];

        for (final item in allItems) {
          final itemMap = item as Map<String, dynamic>;
          final servings = (itemMap['servings'] as num).toDouble();
          final foodName = itemMap['food_name'] as String;
          
          // Check that servings are in 0.5 increments
          final remainder = (servings * 2) % 1;
          expect(remainder, closeTo(0.0, 0.01),
              reason: 'Food "$foodName" has servings of $servings - should be in 0.5 increments (0.5, 1.0, 1.5, 2.0, etc.)');
              
          // Ensure minimum serving of 0.5
          expect(servings, greaterThanOrEqualTo(0.5),
              reason: 'Food "$foodName" has servings of $servings - should be at least 0.5');
              
          // Verify description contains clean amounts (no decimals like 1.73)
          final description = itemMap['description'] as String;
          final match = RegExp(r'^(\d+(?:\.\d+)?)\s').firstMatch(description);
          if (match != null) {
            final amountStr = match.group(1)!;
            final amount = double.parse(amountStr);
            final amountRemainder = (amount * 2) % 1;
            expect(amountRemainder, closeTo(0.0, 0.01),
                reason: 'Food "$foodName" description "$description" contains non-standard amount $amount');
          }
        }
      });

      testWidgets('consolidates duplicate foods in plan', 
          (tester) async {
        if (!TestConfig.enableNetworkTests) return;

        // Arrange: Request that might generate duplicate foods
        final requestData = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        // Use preferences that might cause same food to be selected multiple times
        requestData['liked_foods'] = ['sports_drink', 'energy_gel', 'banana'];

        // Act: Generate plan
        final response = await supabase.functions.invoke(
          'generate-ai-nutrition-plan',
          body: requestData,
        ).timeout(TestConfig.networkTestTimeout);

        expect(response.status, lessThan(400));
        final responseData = response.data as Map<String, dynamic>;
        final plan = responseData['plan'] as Map<String, dynamic>;

        // Assert: No duplicate foods within each phase
        final phases = ['before', 'during', 'after'];
        
        for (final phaseName in phases) {
          final items = plan[phaseName] as List<dynamic>;
          final foodNames = <String>[];
          
          for (final item in items) {
            final itemMap = item as Map<String, dynamic>;
            final foodName = itemMap['food_name'] as String;
            
            // Remove any boost labels for comparison
            final baseName = foodName.replaceAll(RegExp(r' \((sodium|carb|hydration) boost\)$'), '');
            
            expect(foodNames, isNot(contains(baseName)),
                reason: 'Duplicate food found in $phaseName phase: $baseName. Foods: ${foodNames.join(', ')}');
                
            foodNames.add(baseName);
          }
        }
      });

      testWidgets('respects food preferences in AI-generated plan', 
          (tester) async {
        if (!TestConfig.enableNetworkTests) return;

        // Arrange: Request with specific food preferences
        final requestData = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        requestData['liked_foods'] = ['oatmeal', 'gels', 'protein_shake'];
        requestData['disliked_foods'] = ['coffee', 'banana', 'coconut_water'];

        // Act: Generate plan
        final response = await supabase.functions.invoke(
          'generate-ai-nutrition-plan',
          body: requestData,
        ).timeout(TestConfig.networkTestTimeout);

        expect(response.status, lessThan(400));
        final responseData = response.data as Map<String, dynamic>;
        final plan = responseData['plan'] as Map<String, dynamic>;

        // Assert: Check food preferences are respected
        final allItems = [
          ...(plan['before'] as List<dynamic>),
          ...(plan['during'] as List<dynamic>),
          ...(plan['after'] as List<dynamic>),
        ];

        final allFoodNames = allItems
            .map((item) => (item as Map<String, dynamic>)['food_name'] as String)
            .toSet();

        // Should not include disliked foods
        final dislikedFoods = requestData['disliked_foods'] as List<String>;
        for (final dislikedFood in dislikedFoods) {
          expect(allFoodNames, isNot(contains(dislikedFood)),
              reason: 'Should not include disliked food: $dislikedFood');
        }

        // Should prefer liked foods when phase-appropriate
        final likedFoods = requestData['liked_foods'] as List<String>;
        int likedFoodsUsed = 0;
        for (final likedFood in likedFoods) {
          if (allFoodNames.contains(likedFood)) {
            likedFoodsUsed++;
          }
        }

        expect(likedFoodsUsed, greaterThan(0),
            reason: 'Should include at least some liked foods when appropriate');
      });

      testWidgets('enforces food phase safety constraints', 
          (tester) async {
        if (!TestConfig.enableNetworkTests) return;

        // Arrange: Request with foods that have phase constraints
        final requestData = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        requestData['liked_foods'] = ['oatmeal', 'banana', 'gels', 'sports_drink'];
        requestData['distance_miles'] = 10.0; // Long enough to require during-run fueling

        // Act: Generate plan
        final response = await supabase.functions.invoke(
          'generate-ai-nutrition-plan',
          body: requestData,
        ).timeout(TestConfig.networkTestTimeout);

        expect(response.status, lessThan(400));
        final responseData = response.data as Map<String, dynamic>;
        final plan = responseData['plan'] as Map<String, dynamic>;

        // Assert: Verify phase constraints are enforced
        final duringItems = plan['during'] as List<dynamic>;
        final duringFoodNames = duringItems
            .map((item) => (item as Map<String, dynamic>)['food_name'] as String)
            .toSet();

        // CRITICAL: Pre-run only foods should never appear during runs
        expect(duringFoodNames, isNot(contains('oatmeal')),
            reason: 'Oatmeal should never appear during runs - safety constraint');
        expect(duringFoodNames, isNot(contains('banana')),
            reason: 'Banana should never appear during runs - safety constraint');

        // During-run suitable foods should be preferred
        final suitableDuringFoods = duringFoodNames
            .where((food) => ['gels', 'sports_drink', 'energy_chews', 'electrolyte_tablets']
                .any((suitable) => food.toLowerCase().contains(suitable.toLowerCase())))
            .toList();
            
        expect(suitableDuringFoods, isNotEmpty,
            reason: 'Should include suitable during-run foods');
      });
    });

    group('Error Handling and Fallback', () {
      testWidgets('handles missing macro_targets gracefully', 
          (tester) async {
        if (!TestConfig.enableNetworkTests) return;

        // Arrange: Request without macro_targets (old format)
        final requestData = {
          'device_id': 'test-user-fallback',
          'age': 25,
          'gender': 'female',
          'weight_kg': 65.0,
          'height_cm': 165.0,
          'gut_training_level': 'beginner',
          'distance_miles': 10.0,
          'pace_minutes_per_mile': 9.0,
          'time_before_run_hours': 2.0,
          'liked_foods': ['banana', 'oatmeal'],
          'willing_to_try_foods': ['energy_bar'],
          'disliked_foods': [],
        };

        // Act: Call function with old format
        final response = await supabase.functions.invoke(
          'generate-ai-nutrition-plan',
          body: requestData,
        ).timeout(TestConfig.networkTestTimeout);

        // Assert: Should either succeed or return graceful fallback
        if (response.status >= 400) {
          final responseData = response.data as Map<String, dynamic>?;
          expect(responseData?['fallback_to_algorithm'], equals(true),
              reason: 'Should indicate fallback when macro_targets missing');
          expect(responseData?['error'], isNotNull,
              reason: 'Should provide error explanation');
        } else {
          // If it succeeds, should have valid plan structure
          expect(response.status, lessThan(400));
          final responseData = response.data as Map<String, dynamic>;
          expect(responseData, containsPair('success', true));
          expect(responseData, contains('plan'));
        }
      });

      testWidgets('validates macro_targets structure', 
          (tester) async {
        if (!TestConfig.enableNetworkTests) return;

        // Arrange: Invalid macro_targets structure
        final requestData = TestData.testNutritionPlanRequest.cast<String, dynamic>();
        requestData['macro_targets'] = {
          'pre_run': {
            'carbs_g': 50.0,
            // Missing required fields
          },
          // Missing during_run and post_run sections
        };

        // Act: Call function with invalid structure
        final response = await supabase.functions.invoke(
          'generate-ai-nutrition-plan',
          body: requestData,
        ).timeout(TestConfig.networkTestTimeout);

        // Assert: Should return validation error
        expect(response.status, greaterThanOrEqualTo(400),
            reason: 'Should return error for invalid macro_targets structure');

        final responseData = response.data as Map<String, dynamic>?;
        if (responseData != null) {
          expect(responseData['success'], equals(false));
          expect(responseData['error'], isNotNull);
        }
      });

      testWidgets('handles network timeout gracefully', 
          (tester) async {
        if (!TestConfig.enableNetworkTests) return;

        // Arrange: Valid request but with very short timeout
        final requestData = TestData.testNutritionPlanRequest;

        // Act & Assert: Should handle timeout
        expect(
          () => supabase.functions.invoke(
            'generate-ai-nutrition-plan',
            body: requestData,
          ).timeout(const Duration(milliseconds: 1)), // Very short timeout
          throwsA(isA<Exception>()),
        );
      });

      testWidgets('provides meaningful error messages', 
          (tester) async {
        if (!TestConfig.enableNetworkTests) return;

        // Arrange: Request with invalid data types
        final invalidRequest = {
          'device_id': 123, // Should be string
          'age': 'thirty', // Should be number
          'weight_kg': 'heavy', // Should be number
          'liked_foods': 'oatmeal gels', // Should be array
        };

        // Act: Call function with invalid data
        final response = await supabase.functions.invoke(
          'generate-ai-nutrition-plan',
          body: invalidRequest,
        ).timeout(TestConfig.networkTestTimeout);

        // Assert: Should return meaningful error
        expect(response.status, greaterThanOrEqualTo(400));
        
        final responseData = response.data as Map<String, dynamic>?;
        if (responseData != null) {
          expect(responseData['success'], equals(false));
          expect(responseData['error'], isA<String>());
          expect(responseData['error'], isNot(isEmpty));
          
          // Should provide helpful error message
          final errorMessage = responseData['error'] as String;
          expect(errorMessage.toLowerCase(), anyOf([
            contains('invalid'),
            contains('required'),
            contains('type'),
            contains('format'),
          ]), reason: 'Error message should be descriptive');
        }
      });
    });

    group('Performance and Reliability', () {
      testWidgets('responds within acceptable time limits', 
          (tester) async {
        if (!TestConfig.enableNetworkTests || !TestConfig.enableSlowTests) return;

        // Arrange: Standard request
        final requestData = TestData.testNutritionPlanRequest;
        final stopwatch = Stopwatch()..start();

        // Act: Generate plan and measure time
        final response = await supabase.functions.invoke(
          'generate-ai-nutrition-plan',
          body: requestData,
        ).timeout(TestConfig.networkTestTimeout);

        stopwatch.stop();

        // Assert: Should respond within reasonable time
        expect(response.status, lessThan(400));
        expect(stopwatch.elapsed.inSeconds, lessThan(TestConfig.maxGenerationTimeSeconds),
            reason: 'AI nutrition plan generation took ${stopwatch.elapsed.inSeconds}s, should be under ${TestConfig.maxGenerationTimeSeconds}s');

        // Should still have valid response despite time constraint
        final responseData = response.data as Map<String, dynamic>;
        expect(responseData, containsPair('success', true));
      });

      testWidgets('handles concurrent requests without issues', 
          (tester) async {
        if (!TestConfig.enableNetworkTests || !TestConfig.enableSlowTests) return;

        // Arrange: Multiple different requests
        final requests = [
          TestData.testNutritionPlanRequest,
          TestData.testHalfMarathonRequest,
          TestData.test5KRequest,
        ];

        // Act: Send concurrent requests
        final futures = requests.map((requestData) => 
          supabase.functions.invoke(
            'generate-ai-nutrition-plan',
            body: requestData,
          ).timeout(TestConfig.networkTestTimeout)
        ).toList();

        final responses = await Future.wait(futures);

        // Assert: All requests should succeed
        for (int i = 0; i < responses.length; i++) {
          final response = responses[i];
          expect(response.status, lessThan(400),
              reason: 'Concurrent request $i should succeed');
              
          final responseData = response.data as Map<String, dynamic>;
          expect(responseData, containsPair('success', true));
          expect(responseData, contains('plan'));
        }

        // Verify responses are different (not cached incorrectly)
        final plans = responses.map((r) => 
          (r.data as Map<String, dynamic>)['plan']
        ).toList();
        
        // At minimum, different distance requests should have different during-run recommendations
        final duringRunItems = plans.map((plan) => 
          (plan as Map<String, dynamic>)['during'] as List<dynamic>
        ).toList();
        
        // 5K should have fewer during-run items than half marathon
        final fiveKDuringItems = duringRunItems[2]; // test5KRequest
        final halfMarathonDuringItems = duringRunItems[1]; // testHalfMarathonRequest
        
        expect(halfMarathonDuringItems.length, greaterThanOrEqualTo(fiveKDuringItems.length),
            reason: 'Longer runs should have more or equal during-run fueling');
      });

      testWidgets('maintains data consistency across multiple calls', 
          (tester) async {
        if (!TestConfig.enableNetworkTests) return;

        // Arrange: Same request called multiple times
        final requestData = TestData.testNutritionPlanRequest;

        // Act: Call function multiple times
        final response1 = await supabase.functions.invoke(
          'generate-ai-nutrition-plan',
          body: requestData,
        ).timeout(TestConfig.networkTestTimeout);

        final response2 = await supabase.functions.invoke(
          'generate-ai-nutrition-plan',
          body: requestData,
        ).timeout(TestConfig.networkTestTimeout);

        // Assert: Both should succeed
        expect(response1.status, lessThan(400));
        expect(response2.status, lessThan(400));

        final responseData1 = response1.data as Map<String, dynamic>;
        final responseData2 = response2.data as Map<String, dynamic>;

        // Macro targets should be identical (they're input-driven)
        expect(responseData1['macro_targets'], equals(responseData2['macro_targets']),
            reason: 'Macro targets should be consistent across calls');

        // Plans might vary slightly due to AI, but should meet same nutritional goals
        final plan1 = responseData1['plan'] as Map<String, dynamic>;
        final plan2 = responseData2['plan'] as Map<String, dynamic>;

        // Both should have all required phases
        for (final phase in ['before', 'during', 'after']) {
          expect(plan1, contains(phase));
          expect(plan2, contains(phase));
          expect(plan1[phase], isA<List<dynamic>>());
          expect(plan2[phase], isA<List<dynamic>>());
        }
      });
    });

    group('Additional Edge Functions', () {
      testWidgets('save-food-preferences function works correctly', 
          (tester) async {
        if (!TestConfig.enableNetworkTests) return;

        // Arrange: Food preferences to save
        final preferencesData = {
          'device_id': 'test-device-preferences',
          'preferences': {
            'oatmeal': 'like',
            'gels': 'like',
            'coffee': 'dislike',
            'energy_bar': 'willing_to_try',
          }
        };

        // Act: Call save preferences function
        final response = await supabase.functions.invoke(
          'save-food-preferences',
          body: preferencesData,
        ).timeout(TestConfig.networkTestTimeout);

        // Assert: Should save successfully
        expect(response.status, lessThan(400),
            reason: 'Save food preferences should succeed');

        final responseData = response.data as Map<String, dynamic>;
        expect(responseData, containsPair('success', true));
      });

      testWidgets('get-foods function returns food database', 
          (tester) async {
        if (!TestConfig.enableNetworkTests) return;

        // Act: Get foods database
        final response = await supabase.functions.invoke(
          'get-foods',
        ).timeout(TestConfig.networkTestTimeout);

        // Assert: Should return food database
        expect(response.status, lessThan(400));
        
        final responseData = response.data as Map<String, dynamic>;
        expect(responseData, containsPair('success', true));
        expect(responseData, contains('foods'));
        
        final foods = responseData['foods'] as List<dynamic>;
        expect(foods, isNotEmpty, reason: 'Should return food database');
        
        // Verify food structure
        final firstFood = foods.first as Map<String, dynamic>;
        expect(firstFood, contains('id'));
        expect(firstFood, contains('name'));
        expect(firstFood, contains('carbs_g'));
      });
    });
  });
}