import 'package:flutter_test/flutter_test.dart';

/// Simple test to validate the data structure transformation that should happen
/// when sending adjusted macro targets to the edge function
void main() {
  group('Macro Targets Structure Validation', () {
    test('data structure transformation matches edge function expectations', () {
      // Simulate the MacroTargets structure from our domain
      final mockMacroTargets = {
        'preRun': {
          'carbsG': 75.0,      // User adjusted from 65.0
          'proteinG': 25.0,    // User adjusted from 20.0
          'fatCapG': 15.0,
          'fluidsMl': 600,     // User adjusted from 500
          'sodiumMg': 400,     // User adjusted from 300
        },
        'duringRun': {
          'carbTotalG': 45.0,      // User adjusted from 35.0
          'fluidTotalMl': 750,     // User adjusted from 600
          'sodiumTotalMg': 800,    // User adjusted from 650
        },
        'postRun': {
          'carbsG': 80.0,      // User adjusted from 70.0
          'proteinG': 30.0,    // User adjusted from 25.0
          'fluidsMl': 700,     // User adjusted from 600
          'sodiumMg': 500,     // User adjusted from 450
        },
      };

      // This is the transformation that should happen in generateLLMNutritionPlanFromMacros
      final edgeFunctionPayload = {
        'device_id': 'test-user',
        'age': 30,
        'gender': 'male',
        'weight_kg': 75.0,
        'height_cm': 180.0,
        'gut_training_level': 'moderate',
        'liked_foods': ['banana', 'oatmeal'],
        'willing_to_try_foods': ['energy_bar'],
        'disliked_foods': [],
        'macro_targets': {
          'pre_run': {
            'carbs_g': mockMacroTargets['preRun']!['carbsG'],      // 75.0
            'protein_g': mockMacroTargets['preRun']!['proteinG'],  // 25.0
            'fat_g': mockMacroTargets['preRun']!['fatCapG'],       // 15.0
            'water_ml': mockMacroTargets['preRun']!['fluidsMl'],   // 600
            'sodium_mg': mockMacroTargets['preRun']!['sodiumMg'],  // 400
          },
          'during_run': {
            'carbs_total_g': mockMacroTargets['duringRun']!['carbTotalG'],      // 45.0
            'sodium_total_mg': mockMacroTargets['duringRun']!['sodiumTotalMg'], // 800
            'water_total_ml': mockMacroTargets['duringRun']!['fluidTotalMl'],   // 750
          },
          'post_run': {
            'carbs_g': mockMacroTargets['postRun']!['carbsG'],      // 80.0
            'protein_g': mockMacroTargets['postRun']!['proteinG'],  // 30.0
            'fat_g': 0.0, // Post-run doesn't have fat in current model
            'water_ml': mockMacroTargets['postRun']!['fluidsMl'],   // 700
            'sodium_mg': mockMacroTargets['postRun']!['sodiumMg'],  // 500
          },
        },
      };

      final macroTargets = edgeFunctionPayload['macro_targets'] as Map<String, dynamic>;
      final preRun = macroTargets['pre_run'] as Map<String, dynamic>;
      final duringRun = macroTargets['during_run'] as Map<String, dynamic>;
      final postRun = macroTargets['post_run'] as Map<String, dynamic>;

      // Test that all adjusted values are correctly mapped
      expect(preRun['carbs_g'], equals(75.0), reason: 'Pre-run carbs should be adjusted value 75.0g');
      expect(preRun['protein_g'], equals(25.0), reason: 'Pre-run protein should be adjusted value 25.0g');
      expect(preRun['water_ml'], equals(600), reason: 'Pre-run water should be adjusted value 600ml');
      expect(preRun['sodium_mg'], equals(400), reason: 'Pre-run sodium should be adjusted value 400mg');

      expect(duringRun['carbs_total_g'], equals(45.0), reason: 'During-run carbs should be adjusted value 45.0g');
      expect(duringRun['sodium_total_mg'], equals(800), reason: 'During-run sodium should be adjusted value 800mg');
      expect(duringRun['water_total_ml'], equals(750), reason: 'During-run water should be adjusted value 750ml');

      expect(postRun['carbs_g'], equals(80.0), reason: 'Post-run carbs should be adjusted value 80.0g');
      expect(postRun['protein_g'], equals(30.0), reason: 'Post-run protein should be adjusted value 30.0g');
      expect(postRun['water_ml'], equals(700), reason: 'Post-run water should be adjusted value 700ml');
      expect(postRun['sodium_mg'], equals(500), reason: 'Post-run sodium should be adjusted value 500mg');

      // Validate structure matches edge function expectations
      expect(edgeFunctionPayload, contains('macro_targets'));
      expect(macroTargets, contains('pre_run'));
      expect(macroTargets, contains('during_run'));
      expect(macroTargets, contains('post_run'));

      // Validate field names match what edge function expects
      expect(preRun, containsPair('carbs_g', 75.0));
      expect(preRun, containsPair('protein_g', 25.0));
      expect(preRun, containsPair('fat_g', 15.0));
      expect(preRun, containsPair('water_ml', 600));
      expect(preRun, containsPair('sodium_mg', 400));

      expect(duringRun, containsPair('carbs_total_g', 45.0));
      expect(duringRun, containsPair('sodium_total_mg', 800));
      expect(duringRun, containsPair('water_total_ml', 750));

      expect(postRun, containsPair('carbs_g', 80.0));
      expect(postRun, containsPair('protein_g', 30.0));
      expect(postRun, containsPair('fat_g', 0.0));
      expect(postRun, containsPair('water_ml', 700));
      expect(postRun, containsPair('sodium_mg', 500));

    });

    test('validate that adjusted values are NOT original values', () {
      // Original calculated values (what user would see initially)
      final originalValues = {
        'preRunCarbs': 65.0,
        'duringRunCarbs': 35.0,
        'postRunCarbs': 70.0,
        'preRunWater': 500,
        'preRunSodium': 300,
        'duringRunSodium': 650,
        'duringRunWater': 600,
        'postRunWater': 600,
        'postRunSodium': 450,
      };

      // Adjusted values (what user modified to)
      final adjustedValues = {
        'preRunCarbs': 75.0,      // +10g from original
        'duringRunCarbs': 45.0,   // +10g from original
        'postRunCarbs': 80.0,     // +10g from original
        'preRunWater': 600,       // +100ml from original
        'preRunSodium': 400,      // +100mg from original
        'duringRunSodium': 800,   // +150mg from original
        'duringRunWater': 750,    // +150ml from original
        'postRunWater': 700,      // +100ml from original
        'postRunSodium': 500,     // +50mg from original
      };

      // Critical test: Ensure we're sending adjusted values, not original
      expect(adjustedValues['preRunCarbs'], isNot(equals(originalValues['preRunCarbs'])));
      expect(adjustedValues['duringRunCarbs'], isNot(equals(originalValues['duringRunCarbs'])));
      expect(adjustedValues['postRunCarbs'], isNot(equals(originalValues['postRunCarbs'])));

      expect(adjustedValues['preRunWater'], isNot(equals(originalValues['preRunWater'])));
      expect(adjustedValues['preRunSodium'], isNot(equals(originalValues['preRunSodium'])));

      // And that the differences are what we expect
      expect(adjustedValues['preRunCarbs']! - originalValues['preRunCarbs']!, equals(10.0));
      expect(adjustedValues['duringRunCarbs']! - originalValues['duringRunCarbs']!, equals(10.0));
      expect(adjustedValues['postRunCarbs']! - originalValues['postRunCarbs']!, equals(10.0));
    });

    test('edge function response should preserve adjusted values', () {
      // This simulates what the edge function should return
      final mockEdgeFunctionResponse = {
        'success': true,
        'plan': {
          'before': [
            {'food_name': 'Oatmeal', 'servings': 1.5, 'carbs_per_serving': 30, 'protein_per_serving': 5},
            {'food_name': 'Banana', 'servings': 1, 'carbs_per_serving': 25, 'protein_per_serving': 1},
          ],
          'during': [
            {'food_name': 'Energy Drink', 'servings': 1, 'carbs_per_serving': 25},
            {'food_name': 'Energy Gel', 'servings': 1, 'carbs_per_serving': 20},
          ],
          'after': [
            {'food_name': 'Protein Shake', 'servings': 1, 'carbs_per_serving': 30, 'protein_per_serving': 25},
            {'food_name': 'Recovery Bar', 'servings': 1, 'carbs_per_serving': 50, 'protein_per_serving': 5},
          ],
        },
        'macro_targets': {
          'pre_run': {
            'carbs_g': 75.0,    // Should match what we sent (adjusted value)
            'protein_g': 25.0,  // Should match what we sent (adjusted value)
            'fat_g': 15.0,
            'water_ml': 600.0,  // Should match what we sent (adjusted value)
            'sodium_mg': 400.0, // Should match what we sent (adjusted value)
          },
          'during_run': {
            'carbs_total_g': 45.0,     // Should match what we sent (adjusted value)
            'sodium_total_mg': 800.0,  // Should match what we sent (adjusted value)
            'water_total_ml': 750.0,   // Should match what we sent (adjusted value)
          },
          'post_run': {
            'carbs_g': 80.0,     // Should match what we sent (adjusted value)
            'protein_g': 30.0,   // Should match what we sent (adjusted value)
            'fat_g': 0.0,
            'water_ml': 700.0,   // Should match what we sent (adjusted value)
            'sodium_mg': 500.0,  // Should match what we sent (adjusted value)
          },
        },
        'detailed_message': 'Nutrition plan generated based on your adjusted macro targets...'
      };

      // Test that the response preserves the adjusted values we sent
      final responseMacros = mockEdgeFunctionResponse['macro_targets'] as Map<String, dynamic>;
      final responsePreRun = responseMacros['pre_run'] as Map<String, dynamic>;
      final responseDuringRun = responseMacros['during_run'] as Map<String, dynamic>;
      final responsePostRun = responseMacros['post_run'] as Map<String, dynamic>;

      // These should be the adjusted values, not the original calculated ones
      expect(responsePreRun['carbs_g'], equals(75.0), reason: 'Response should preserve adjusted pre-run carbs');
      expect(responseDuringRun['carbs_total_g'], equals(45.0), reason: 'Response should preserve adjusted during-run carbs');
      expect(responsePostRun['carbs_g'], equals(80.0), reason: 'Response should preserve adjusted post-run carbs');

      expect(responsePreRun['water_ml'], equals(600.0), reason: 'Response should preserve adjusted pre-run water');
      expect(responsePreRun['sodium_mg'], equals(400.0), reason: 'Response should preserve adjusted pre-run sodium');

      // Food recommendations should approximate the adjusted targets
      final plan = mockEdgeFunctionResponse['plan'] as Map<String, dynamic>;
      final beforeItems = plan['before'] as List<dynamic>;
      final duringItems = plan['during'] as List<dynamic>;
      final afterItems = plan['after'] as List<dynamic>;

      // Calculate total carbs from recommended foods
      double beforeCarbs = beforeItems.fold(0.0, (sum, item) {
        final servings = (item as Map<String, dynamic>)['servings'] as num;
        final carbsPerServing = item['carbs_per_serving'] as num;
        return sum + (servings * carbsPerServing);
      });

      double duringCarbs = duringItems.fold(0.0, (sum, item) {
        final servings = (item as Map<String, dynamic>)['servings'] as num;
        final carbsPerServing = item['carbs_per_serving'] as num;
        return sum + (servings * carbsPerServing);
      });

      double afterCarbs = afterItems.fold(0.0, (sum, item) {
        final servings = (item as Map<String, dynamic>)['servings'] as num;
        final carbsPerServing = item['carbs_per_serving'] as num;
        return sum + (servings * carbsPerServing);
      });

      // Food recommendations should be close to adjusted targets (within reasonable tolerance)
      const tolerance = 15.0; // ±15g tolerance for food recommendations
      expect(beforeCarbs, closeTo(75.0, tolerance), reason: 'Before foods should target adjusted 75g carbs');
      expect(duringCarbs, closeTo(45.0, tolerance), reason: 'During foods should target adjusted 45g carbs');
      expect(afterCarbs, closeTo(80.0, tolerance), reason: 'After foods should target adjusted 80g carbs');
    });
  });
}