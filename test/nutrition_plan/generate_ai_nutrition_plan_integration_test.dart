import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Integration test for generate-ai-nutrition-plan edge function
/// Tests that adjusted macros from the adjust macros screen are properly
/// sent to and processed by the edge function
void main() {
  group('Generate AI Nutrition Plan Integration Tests', () {
    late SupabaseClient supabase;

    setUpAll(() async {
      // Initialize Supabase client with environment variables
      const supabaseUrl = String.fromEnvironment('SUPABASE_URL', 
        defaultValue: 'https://your-project.supabase.co');
      const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY',
        defaultValue: 'your-anon-key');

      supabase = SupabaseClient(supabaseUrl, supabaseKey);
    });

    testWidgets('adjusted macros are correctly sent to edge function', (WidgetTester tester) async {
      // Arrange: Create test data with adjusted macro targets
      final testMacroTargets = {
        'pre_run': {
          'carbs_g': 75.0,      // User adjusted from original 65.0
          'protein_g': 25.0,    // User adjusted from original 20.0
          'fat_g': 15.0,
          'water_ml': 600.0,    // User adjusted from original 500.0
          'sodium_mg': 400.0,   // User adjusted from original 300.0
        },
        'during_run': {
          'carbs_total_g': 45.0,     // User adjusted from original 35.0
          'sodium_total_mg': 800.0,  // User adjusted from original 650.0
          'water_total_ml': 750.0,   // User adjusted from original 600.0
        },
        'post_run': {
          'carbs_g': 80.0,      // User adjusted from original 70.0
          'protein_g': 30.0,    // User adjusted from original 25.0
          'fat_g': 12.0,
          'water_ml': 700.0,    // User adjusted from original 600.0
          'sodium_mg': 500.0,   // User adjusted from original 450.0
        },
      };

      final requestData = {
        'device_id': 'test-user-123',
        'age': 30,
        'gender': 'male',
        'weight_kg': 75.0,
        'height_cm': 180.0,
        'gut_training_level': 'moderate',
        'liked_foods': ['banana', 'oatmeal', 'sports_drink', 'energy_bar'],
        'willing_to_try_foods': ['dates', 'gels'],
        'disliked_foods': ['protein_powder'],
        'macro_targets': testMacroTargets,
      };

      print('🧪 Testing adjusted macros integration...');
      print('📊 Sending adjusted macro targets:');
      print('   Pre-run: ${testMacroTargets['pre_run']}');
      print('   During-run: ${testMacroTargets['during_run']}');
      print('   Post-run: ${testMacroTargets['post_run']}');

      // Act: Call the edge function
      final response = await supabase.functions.invoke(
        'generate-ai-nutrition-plan',
        body: requestData,
      );

      // Assert: Verify the response
      expect(response.status, lessThan(400), 
        reason: 'Edge function should succeed. Response: ${response.data}');

      final responseData = response.data as Map<String, dynamic>;
      
      // Verify response structure
      expect(responseData, containsPair('success', true));
      expect(responseData, contains('plan'));
      expect(responseData, contains('macro_targets'));
      expect(responseData, contains('detailed_message'));

      // Extract returned macro targets from response
      final returnedMacros = responseData['macro_targets'] as Map<String, dynamic>;
      
      print('✅ Edge function response received');
      print('📊 Returned macro targets:');
      print('   Pre-run: ${returnedMacros['pre_run']}');
      print('   During-run: ${returnedMacros['during_run']}');
      print('   Post-run: ${returnedMacros['post_run']}');

      // CRITICAL TEST: Verify that adjusted macros are preserved
      final returnedPreRun = returnedMacros['pre_run'] as Map<String, dynamic>;
      final returnedDuringRun = returnedMacros['during_run'] as Map<String, dynamic>;
      final returnedPostRun = returnedMacros['post_run'] as Map<String, dynamic>;

      // Test that our adjusted values are preserved in the response
      expect(returnedPreRun['carbs_g'], equals(75.0), 
        reason: 'Pre-run carbs should match adjusted value of 75.0g');
      expect(returnedPreRun['protein_g'], equals(25.0),
        reason: 'Pre-run protein should match adjusted value of 25.0g');
      expect(returnedPreRun['water_ml'], equals(600.0),
        reason: 'Pre-run water should match adjusted value of 600ml');
      expect(returnedPreRun['sodium_mg'], equals(400.0),
        reason: 'Pre-run sodium should match adjusted value of 400mg');

      expect(returnedDuringRun['carbs_total_g'], equals(45.0),
        reason: 'During-run carbs should match adjusted value of 45.0g');
      expect(returnedDuringRun['sodium_total_mg'], equals(800.0),
        reason: 'During-run sodium should match adjusted value of 800mg');
      expect(returnedDuringRun['water_total_ml'], equals(750.0),
        reason: 'During-run water should match adjusted value of 750ml');

      expect(returnedPostRun['carbs_g'], equals(80.0),
        reason: 'Post-run carbs should match adjusted value of 80.0g');
      expect(returnedPostRun['protein_g'], equals(30.0),
        reason: 'Post-run protein should match adjusted value of 30.0g');
      expect(returnedPostRun['water_ml'], equals(700.0),
        reason: 'Post-run water should match adjusted value of 700ml');
      expect(returnedPostRun['sodium_mg'], equals(500.0),
        reason: 'Post-run sodium should match adjusted value of 500mg');

      // Verify the nutrition plan structure
      final plan = responseData['plan'] as Map<String, dynamic>;
      expect(plan, contains('before'));
      expect(plan, contains('during'));
      expect(plan, contains('after'));

      // Test that the food recommendations align with macro targets
      final beforeItems = plan['before'] as List<dynamic>;
      final duringItems = plan['during'] as List<dynamic>;
      final afterItems = plan['after'] as List<dynamic>;

      expect(beforeItems, isNotEmpty, reason: 'Should have before-run food items');
      expect(duringItems, isNotEmpty, reason: 'Should have during-run food items');
      expect(afterItems, isNotEmpty, reason: 'Should have after-run food items');

      // Calculate total macros from recommended foods to verify they align
      double totalPreRunCarbs = 0.0;
      double totalDuringRunCarbs = 0.0;
      double totalPostRunCarbs = 0.0;

      for (final item in beforeItems) {
        final itemMap = item as Map<String, dynamic>;
        final servings = itemMap['servings'] as num? ?? 1;
        final carbsPerServing = itemMap['carbs_per_serving'] as num? ?? 0;
        totalPreRunCarbs += servings * carbsPerServing;
      }

      for (final item in duringItems) {
        final itemMap = item as Map<String, dynamic>;
        final servings = itemMap['servings'] as num? ?? 1;
        final carbsPerServing = itemMap['carbs_per_serving'] as num? ?? 0;
        totalDuringRunCarbs += servings * carbsPerServing;
      }

      for (final item in afterItems) {
        final itemMap = item as Map<String, dynamic>;
        final servings = itemMap['servings'] as num? ?? 1;
        final carbsPerServing = itemMap['carbs_per_serving'] as num? ?? 0;
        totalPostRunCarbs += servings * carbsPerServing;
      }

      print('🔍 Food recommendation analysis:');
      print('   Pre-run foods total carbs: ${totalPreRunCarbs.toStringAsFixed(1)}g (target: 75.0g)');
      print('   During-run foods total carbs: ${totalDuringRunCarbs.toStringAsFixed(1)}g (target: 45.0g)');
      print('   Post-run foods total carbs: ${totalPostRunCarbs.toStringAsFixed(1)}g (target: 80.0g)');

      // Allow for reasonable tolerance in food recommendations (±10g)
      const tolerance = 10.0;
      expect(totalPreRunCarbs, closeTo(75.0, tolerance),
        reason: 'Pre-run food carbs should be close to adjusted target of 75.0g');
      expect(totalDuringRunCarbs, closeTo(45.0, tolerance),
        reason: 'During-run food carbs should be close to adjusted target of 45.0g');
      expect(totalPostRunCarbs, closeTo(80.0, tolerance),
        reason: 'Post-run food carbs should be close to adjusted target of 80.0g');

      print('✅ All tests passed! Adjusted macros are properly processed.');
    });

    testWidgets('edge function handles missing macro_targets gracefully', (WidgetTester tester) async {
      // Test the old format (without macro_targets) for backwards compatibility
      final requestData = {
        'device_id': 'test-user-456',
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

      print('🧪 Testing backwards compatibility (without macro_targets)...');

      final response = await supabase.functions.invoke(
        'generate-ai-nutrition-plan',
        body: requestData,
      );

      // Should either succeed or return fallback_to_algorithm
      if (response.status >= 400) {
        final responseData = response.data as Map<String, dynamic>?;
        expect(responseData?['fallback_to_algorithm'], equals(true),
          reason: 'Should indicate fallback when macro_targets missing');
      } else {
        expect(response.status, lessThan(400));
        final responseData = response.data as Map<String, dynamic>;
        expect(responseData, containsPair('success', true));
      }

      print('✅ Backwards compatibility test passed');
    });

    testWidgets('edge function validates macro_targets structure', (WidgetTester tester) async {
      // Test with invalid macro_targets structure
      final requestData = {
        'device_id': 'test-user-789',
        'age': 35,
        'gender': 'male',
        'weight_kg': 80.0,
        'height_cm': 175.0,
        'gut_training_level': 'advanced',
        'liked_foods': ['banana'],
        'willing_to_try_foods': [],
        'disliked_foods': [],
        'macro_targets': {
          'pre_run': {
            // Missing required fields
            'carbs_g': 50.0,
          },
          // Missing during_run and post_run sections
        },
      };

      print('🧪 Testing macro_targets validation...');

      final response = await supabase.functions.invoke(
        'generate-ai-nutrition-plan',
        body: requestData,
      );

      // Should return an error or fallback
      expect(response.status, greaterThanOrEqualTo(400),
        reason: 'Should return error for invalid macro_targets structure');

      print('✅ Validation test passed');
    });
  });
}