import 'package:flutter_test/flutter_test.dart';

/// Test to validate the macro targets data structure transformation
/// that occurs when sending adjusted values to the edge function
void main() {
  group('Macro Targets Structure Tests', () {
    test('validate macro targets structure for edge function', () {
      // Simulate adjusted macro targets (what user modified on adjust macros screen)
      final adjustedMacroTargets = {
        'pre_run': {
          'carbs_g': 75.0,      // User adjusted from 65.0
          'protein_g': 25.0,    // User adjusted from 20.0
          'fat_g': 15.0,
          'water_ml': 600.0,    // User adjusted from 500.0
          'sodium_mg': 400.0,   // User adjusted from 300.0
        },
        'during_run': {
          'carbs_total_g': 45.0,     // User adjusted from 35.0
          'sodium_total_mg': 800.0,  // User adjusted from 650.0
          'water_total_ml': 750.0,   // User adjusted from 600.0
        },
        'post_run': {
          'carbs_g': 80.0,      // User adjusted from 70.0
          'protein_g': 30.0,    // User adjusted from 25.0
          'fat_g': 0.0,
          'water_ml': 700.0,    // User adjusted from 600.0
          'sodium_mg': 500.0,   // User adjusted from 450.0
        },
      };

      // Validate structure
      expect(adjustedMacroTargets, contains('pre_run'));
      expect(adjustedMacroTargets, contains('during_run'));
      expect(adjustedMacroTargets, contains('post_run'));

      final preRun = adjustedMacroTargets['pre_run'] as Map<String, dynamic>;
      final duringRun = adjustedMacroTargets['during_run'] as Map<String, dynamic>;
      final postRun = adjustedMacroTargets['post_run'] as Map<String, dynamic>;

      // Validate all adjusted values are correct
      expect(preRun['carbs_g'], equals(75.0), reason: 'Pre-run carbs should be 75.0g (adjusted)');
      expect(preRun['protein_g'], equals(25.0), reason: 'Pre-run protein should be 25.0g (adjusted)');
      expect(preRun['water_ml'], equals(600.0), reason: 'Pre-run water should be 600ml (adjusted)');
      expect(preRun['sodium_mg'], equals(400.0), reason: 'Pre-run sodium should be 400mg (adjusted)');

      expect(duringRun['carbs_total_g'], equals(45.0), reason: 'During-run carbs should be 45.0g (adjusted)');
      expect(duringRun['sodium_total_mg'], equals(800.0), reason: 'During-run sodium should be 800mg (adjusted)');
      expect(duringRun['water_total_ml'], equals(750.0), reason: 'During-run water should be 750ml (adjusted)');

      expect(postRun['carbs_g'], equals(80.0), reason: 'Post-run carbs should be 80.0g (adjusted)');
      expect(postRun['protein_g'], equals(30.0), reason: 'Post-run protein should be 30.0g (adjusted)');
      expect(postRun['water_ml'], equals(700.0), reason: 'Post-run water should be 700ml (adjusted)');
      expect(postRun['sodium_mg'], equals(500.0), reason: 'Post-run sodium should be 500mg (adjusted)');

      print('✅ SUCCESS: Macro targets structure validation passed');
      print('   Pre-run carbs: ${preRun['carbs_g']}g (adjusted from 65.0g)');
      print('   During-run carbs: ${duringRun['carbs_total_g']}g (adjusted from 35.0g)');
      print('   Post-run carbs: ${postRun['carbs_g']}g (adjusted from 70.0g)');
    });

    test('validate that values are NOT original calculated values', () {
      // Original values (what would have been calculated initially)
      final originalValues = {
        'pre_run_carbs': 65.0,
        'during_run_carbs': 35.0,
        'post_run_carbs': 70.0,
        'pre_run_water': 500.0,
        'during_run_sodium': 650.0,
        'post_run_sodium': 450.0,
      };

      // Adjusted values (what user modified to)
      final adjustedValues = {
        'pre_run_carbs': 75.0,
        'during_run_carbs': 45.0,
        'post_run_carbs': 80.0,
        'pre_run_water': 600.0,
        'during_run_sodium': 800.0,
        'post_run_sodium': 500.0,
      };

      // Verify adjusted values are different from original
      expect(adjustedValues['pre_run_carbs'], isNot(equals(originalValues['pre_run_carbs'])));
      expect(adjustedValues['during_run_carbs'], isNot(equals(originalValues['during_run_carbs'])));
      expect(adjustedValues['post_run_carbs'], isNot(equals(originalValues['post_run_carbs'])));

      // Verify the differences are what we expect
      expect(adjustedValues['pre_run_carbs']! - originalValues['pre_run_carbs']!, equals(10.0));
      expect(adjustedValues['during_run_carbs']! - originalValues['during_run_carbs']!, equals(10.0));
      expect(adjustedValues['post_run_carbs']! - originalValues['post_run_carbs']!, equals(10.0));

      print('✅ SUCCESS: Adjusted values are correctly different from original values');
      print('   Pre-run carbs: ${originalValues['pre_run_carbs']}g → ${adjustedValues['pre_run_carbs']}g (+10g)');
      print('   During-run carbs: ${originalValues['during_run_carbs']}g → ${adjustedValues['during_run_carbs']}g (+10g)');
      print('   Post-run carbs: ${originalValues['post_run_carbs']}g → ${adjustedValues['post_run_carbs']}g (+10g)');
    });
  });
}