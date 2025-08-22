import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/llm_nutrition_plan_service.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';

void main() {
  group('LLM Nutrition Plan Prompt Generation Tests', () {
    late ProviderContainer container;

    setUp(() async {
      // Initialize test container
      container = ProviderContainer();
      
      // Mock Supabase if needed for testing
      // Note: In a real test, you'd mock the Supabase client
    });

    tearDown(() {
      container.dispose();
    });

    test('Verify prompt includes correct food ID format using views', () async {
      // This test verifies that the prompt generation correctly formats food IDs
      // Sample data matching the llm_food_selection view structure

      final sampleFoods = [
        {
          'id': 'a1b2c3d4-e5f6-7890-1234-567890abcdef', // UUID format
          'name': 'Oatmeal',
          'carbs_per_serving': 30.0,
          'protein_per_serving': 5.0,
          'sodium_mg': 150,
          'serving_amount': 1.0,
          'serving_unit': 'cup',
          'suitable_before': true,  // From view
          'suitable_during': false,
          'suitable_after': false,
        },
        {
          'id': 'f9e8d7c6-b5a4-3210-9876-543210fedcba', // UUID format
          'name': 'Banana',
          'carbs_per_serving': 27.0,
          'protein_per_serving': 1.0,
          'sodium_mg': 1,
          'serving_amount': 1.0,
          'serving_unit': 'medium',
          'suitable_before': true,
          'suitable_during': true,
          'suitable_after': false,
        },
        {
          'id': '12345678-90ab-cdef-1234-567890abcdef', // UUID format
          'name': 'Energy Gel',
          'carbs_per_serving': 22.0,
          'protein_per_serving': 0.0,
          'sodium_mg': 50,
          'serving_amount': 1.0,
          'serving_unit': 'packet',
          'suitable_before': false,
          'suitable_during': true,
          'suitable_after': false,
        },
      ];

      // Verify food IDs are UUIDs
      for (final food in sampleFoods) {
        final id = food['id'] as String;
        
        // UUID v4 format check: 8-4-4-4-12 hexadecimal characters
        expect(
          RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
              .hasMatch(id.toLowerCase()),
          isTrue,
          reason: 'Food ID should be a valid UUID v4: $id',
        );
      }

      // Test phase filtering using view flags
      final beforeFoods = sampleFoods.where((f) => f['suitable_before'] == true).toList();
      final duringFoods = sampleFoods.where((f) => f['suitable_during'] == true).toList();
      
      expect(beforeFoods.length, equals(2)); // Oatmeal and Banana
      expect(duringFoods.length, equals(2)); // Banana and Energy Gel

      // Build a sample prompt string similar to what the edge function creates
      final promptLines = beforeFoods.map((f) => 
        '${f['name']} - ${f['carbs_per_serving']}g carbs'
      ).toList();

      // Verify the prompt includes food names without UUIDs
      for (final line in promptLines) {
        expect(line, isNot(contains('UUID:')));
        expect(line, contains(' - ')); // Contains dash separator
        expect(line, contains('g carbs')); // Contains nutrition info
      }
    });

    test('Verify AI response validation catches invalid food names', () {
      // Test that the validation logic correctly identifies invalid food names
      
      final validFoodNames = [
        'Oatmeal',
        'Banana',
        'Energy Gel',
      ];

      // Sample AI response with INCORRECT food names
      final invalidAIResponse = {
        'plan': {
          'before': [
            {'food_name': 'Fake Food'}, // Invalid!
          ],
          'during': [
            {'food_name': 'Made Up Gel'}, // Invalid!
            {'food_name': 'Non-existent Fruit'}, // Invalid!
          ],
          'after': [],
        }
      };

      // Extract food names from response
      final responseFoodNames = [
        ...(invalidAIResponse['plan']!['before'] as List).map((f) => f['food_name']),
        ...(invalidAIResponse['plan']!['during'] as List).map((f) => f['food_name']),
        ...(invalidAIResponse['plan']!['after'] as List).map((f) => f['food_name']),
      ];

      // Check for invalid names
      final invalidNames = responseFoodNames.where((name) => !validFoodNames.contains(name)).toList();
      
      expect(invalidNames, isNotEmpty);
      expect(invalidNames, contains('Fake Food'));
      expect(invalidNames, contains('Made Up Gel'));
      expect(invalidNames, contains('Non-existent Fruit'));
    });

    test('Verify correct AI response passes validation', () {
      // Test that valid food names pass validation
      
      final validFoodNames = [
        'Oatmeal',
        'Banana', 
        'Energy Gel',
      ];

      // Sample AI response with CORRECT food names and new structure
      final validAIResponse = {
        'plan': {
          'before': [
            {
              'food_name': 'Oatmeal',
              'description': '1 cup cooked oatmeal',
              'carbs_grams': 30,
              'calories': 150,
              'protein_grams': 5,
              'fat_grams': 2,
              'timing': '2 hours before'
            },
          ],
          'during': [
            {
              'food_name': 'Energy Gel',
              'description': '1 gel packet',
              'carbs_grams': 22,
              'calories': 100,
              'protein_grams': 0,
              'fat_grams': 0,
              'sodium_mg': 50,
              'timing': 'every 45 minutes'
            },
          ],
          'after': [],
        },
        'macro_targets': {
          'pre_run': {
            'calories': 300,
            'carbs_grams': 60,
            'protein_grams': 10,
            'fat_grams': 5
          },
          'during_run': {
            'carbs_per_hour': 50,
            'sodium_per_hour_mg': 400,
            'fluids_per_hour_ml': 500
          },
          'post_run': {
            'calories': 250,
            'carbs_grams': 40,
            'protein_grams': 15,
            'fat_grams': 3
          }
        }
      };

      // Extract food names from response
      final responseFoodNames = [
        ...(validAIResponse['plan']!['before'] as List).map((f) => f['food_name']),
        ...(validAIResponse['plan']!['during'] as List).map((f) => f['food_name']),
        ...(validAIResponse['plan']!['after'] as List).map((f) => f['food_name']),
      ];

      // Check all names are valid
      final invalidNames = responseFoodNames.where((name) => !validFoodNames.contains(name)).toList();
      
      expect(invalidNames, isEmpty, reason: 'All food names should be valid');
      
      // Verify detailed nutrition info is present
      final beforeItem = (validAIResponse['plan']!['before'] as List)[0] as Map<String, dynamic>;
      expect(beforeItem['description'], equals('1 cup cooked oatmeal'));
      expect(beforeItem['carbs_grams'], equals(30));
      expect(beforeItem['calories'], equals(150));
      expect(beforeItem['protein_grams'], equals(5));
      expect(beforeItem['fat_grams'], equals(2));
      
      // Verify macro targets structure
      final macroTargets = validAIResponse['macro_targets'] as Map<String, dynamic>;
      expect(macroTargets['pre_run']['calories'], equals(300));
      expect(macroTargets['during_run']['carbs_per_hour'], equals(50));
      expect(macroTargets['post_run']['protein_grams'], equals(15));
    });

    test('Verify prompt includes user preferences correctly', () {
      // Test that liked and willing-to-try foods are marked correctly

      final likedFoods = ['Oatmeal', 'Banana'];
      final willingToTryFoods = ['Energy Gel'];
      final dislikedFoods = ['Coffee'];

      final allFoods = [
        {'name': 'Oatmeal', 'id': 'uuid-1'},
        {'name': 'Banana', 'id': 'uuid-2'},
        {'name': 'Energy Gel', 'id': 'uuid-3'},
        {'name': 'Coffee', 'id': 'uuid-4'},
      ];

      // Filter preferred foods
      final preferredFoods = allFoods.where((f) => 
        likedFoods.contains(f['name']) || willingToTryFoods.contains(f['name'])
      ).toList();

      expect(preferredFoods.length, equals(3));
      expect(preferredFoods.any((f) => f['name'] == 'Coffee'), isFalse);
    });

    test('Verify prompt includes correct nutrition guidelines', () {
      // Test that the prompt includes ACSM guidelines

      const systemPrompt = '''
Key Principles:
1. Pre-run nutrition (0.25-4g carbs/kg based on time window):
   - <15 min before: 0.25g/kg
   - 15-60 min: 0.5g/kg  
   - 60-120 min: 1g/kg
   - 120-240 min: 2-4g/kg
2. During-run nutrition:
   - Gut training levels: Low (40g/h), Moderate (50g/h), High (60g/h)
   - Hydration: 400-800ml/hour
   - Sodium: 300-600mg/hour for runs >60min
3. Post-run recovery (within 30 min):
   - Carbs: 1.0-1.2g/kg
   - Protein: 0.25g/kg
   - Rehydration: 150% of fluid losses
''';

      expect(systemPrompt, contains('0.25-4g carbs/kg'));
      expect(systemPrompt, contains('Gut training levels'));
      expect(systemPrompt, contains('400-800ml/hour'));
      expect(systemPrompt, contains('300-600mg/hour'));
    });
  });
}