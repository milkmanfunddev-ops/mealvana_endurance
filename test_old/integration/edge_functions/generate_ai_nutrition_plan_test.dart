/// Generate AI Nutrition Plan Edge Function Tests
/// 
/// These tests validate the AI nutrition plan generation edge function
/// and its ability to meet macro targets within tight tolerances.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/test_data.dart';
import '../../helpers/test_config.dart';

void main() {
  group('Generate AI Nutrition Plan Function', () {
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
}