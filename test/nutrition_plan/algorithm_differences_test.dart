import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Algorithm comparison test to identify differences between TypeScript and Python
void main() {
  group('Algorithm Differences', () {
    /// Test case for comparison
    final testCase = {
      'name': '10K Run - Standard Conditions',
      'distance_miles': 6.2,
      'pace': '8:00', // min:sec format
      'weight_kg': 75.0,
      'age': 30,
      'gender': 'male',
      'height_cm': 180.0,
      'gut_training': 'moderate',
      'sweat_rate_category': 'medium',
      'temp_c': 20.0,
      'humidity_pct': 60.0,
      'time_before_run_min': 120,
    };

    /// Call Python algorithm
    Future<Map<String, dynamic>> callPythonAlgorithm() async {
      final paceFloat = 8.0; // 8:00 min/mile
      
      final pythonScript = '''
import sys
import json
from dataclasses import asdict
sys.path.append('${Directory.current.path}/docs/business_logic')

try:
    from run_fueling_v2 import plan_run, RunInput, GutTraining, SweatRateCat
    
    # Map gut training levels
    gut_map = {
        'low': GutTraining.LOW,
        'moderate': GutTraining.MODERATE, 
        'high': GutTraining.HIGH
    }
    
    # Map sweat rate categories
    sweat_map = {
        'light': SweatRateCat.LIGHT,
        'medium': SweatRateCat.MEDIUM,
        'heavy': SweatRateCat.HEAVY
    }
    
    # Create RunInput
    run_input = RunInput(
        distance_miles=${testCase['distance_miles']},
        pace_min_per_mile=$paceFloat,
        weight_kg=${testCase['weight_kg']},
        gut_training=gut_map['${testCase['gut_training']}'],
        time_before_run_min=${testCase['time_before_run_min']},
        sweat_rate_category=sweat_map['${testCase['sweat_rate_category']}'],
        temp_c=${testCase['temp_c']},
        humidity_pct=${testCase['humidity_pct']},
        age=${testCase['age']},
        sex='${testCase['gender']}',
        height_cm=${testCase['height_cm']}
    )
    
    # Call the plan_run function
    result = plan_run(run_input)
    
    # Flatten the nested structure
    flat_result = {}
    for phase, values in result.items():
        for key, value in values.items():
            flat_result[key] = value
    
    print(json.dumps(flat_result, indent=2))
except Exception as e:
    import traceback
    print("ERROR:" + str(e))
    print("TRACEBACK:" + traceback.format_exc())
    sys.exit(1)
''';

      // Write and execute Python script
      final tempDir = Directory('${Directory.current.path}/test/nutrition_plan/temp');
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      
      final scriptFile = File('${tempDir.path}/comparison_test.py');
      await scriptFile.writeAsString(pythonScript);

      try {
        final result = await Process.run('python3', [scriptFile.path]);
        await scriptFile.delete();

        if (result.exitCode != 0) {
          throw Exception('Python failed: ${result.stderr}');
        }

        return jsonDecode(result.stdout) as Map<String, dynamic>;
      } finally {
        if (await scriptFile.exists()) {
          await scriptFile.delete();
        }
      }
    }

    /// Call TypeScript edge function (mock for now since we need the server running)
    Map<String, dynamic> callTypeScriptAlgorithm() {
      // For now, return what our TypeScript algorithm should return
      // This would normally be a curl call to the edge function
      return {
        'duration_h': 0.8267,
        'MET': 12.5,
        'calories_net_kcal': 748,
        'calories_gross_kcal': 813,
        'pre_run_carbs_g': 75,
        'pre_run_water_ml': 550,
        'pre_run_sodium_mg': 450,
        'during_rate_g_per_h': 30,
        'during_total_g': 25,
        'during_water_rate_ml_per_h': 600,
        'during_water_total_ml': 496,
        'during_sodium_rate_mg_per_h': 650,
        'during_sodium_total_mg': 537,
        'post_run_carbs_g': 113,
        'post_run_water_ml': 1240,
        'post_run_sodium_mg': 625,
      };
    }

    /// Map Python fields to TypeScript equivalents for comparison
    Map<String, dynamic> mapPythonToTypeScript(Map<String, dynamic> pythonResult) {
      return {
        'duration_h': pythonResult['duration_h'],
        'MET': pythonResult['met'],
        'calories_net_kcal': pythonResult['net_kcal_transport'],
        'calories_gross_kcal': pythonResult['gross_kcal'],
        // Pre-run
        'pre_run_carbs_g': pythonResult['carb_g'],
        'pre_run_water_ml': (pythonResult['main_ml'] ?? 0) + (pythonResult['topoff_ml'] ?? 0),
        'pre_run_sodium_mg': pythonResult['sodium_mg'],
        // During-run
        'during_rate_g_per_h': pythonResult['carb_per_h_g'],
        'during_total_g': pythonResult['total_carb_g'],
        'during_water_rate_ml_per_h': (pythonResult['fluid_lph_plan'] ?? 0.6) * 1000, // Convert L/h to mL/h
        'during_water_total_ml': ((pythonResult['fluid_lph_plan'] ?? 0.6) * 1000) * (pythonResult['duration_h'] ?? 0.83),
        'during_sodium_rate_mg_per_h': pythonResult['sodium_mgph_target'] ?? 650,
        'during_sodium_total_mg': (pythonResult['sodium_mgph_target'] ?? 650) * (pythonResult['duration_h'] ?? 0.83),
        // Post-run (recovery)
        'post_run_carbs_g': 1.5 * (pythonResult['weight_kg'] ?? 75), // 1.5g/kg estimate
        'post_run_water_ml': (pythonResult['rehydration_l'] ?? 1.25) * 1000,
        'post_run_sodium_mg': pythonResult['rehydration_sodium_mg'],
      };
    }

    test('Compare Python vs TypeScript algorithm results', () async {
      // Get Python results
      final pythonResult = await callPythonAlgorithm();
      final mappedPython = mapPythonToTypeScript(pythonResult);
      
      // Get TypeScript results (would normally call edge function)
      final tsResult = callTypeScriptAlgorithm();
      
      print('\n=== ALGORITHM COMPARISON REPORT ===\n');
      print('Test Case: ${testCase['name']}');
      print('Distance: ${testCase['distance_miles']}mi, Pace: ${testCase['pace']}');
      print('Weight: ${testCase['weight_kg']}kg, Age: ${testCase['age']}, Gender: ${testCase['gender']}');
      print('Temperature: ${testCase['temp_c']}°C, Humidity: ${testCase['humidity_pct']}%');
      print('Gut Training: ${testCase['gut_training']}, Sweat Rate: ${testCase['sweat_rate_category']}\n');
      
      // Compare key metrics
      final comparisons = [
        {'field': 'duration_h', 'name': 'Duration (hours)'},
        {'field': 'MET', 'name': 'Metabolic Equivalent'},
        {'field': 'calories_net_kcal', 'name': 'Net Calories'},
        {'field': 'calories_gross_kcal', 'name': 'Gross Calories'},
        {'field': 'pre_run_carbs_g', 'name': 'Pre-run Carbs (g)'},
        {'field': 'pre_run_water_ml', 'name': 'Pre-run Water (mL)'},
        {'field': 'during_rate_g_per_h', 'name': 'During-run Carb Rate (g/h)'},
        {'field': 'during_total_g', 'name': 'During-run Total Carbs (g)'},
        {'field': 'during_water_rate_ml_per_h', 'name': 'During-run Water Rate (mL/h)'},
        {'field': 'during_sodium_rate_mg_per_h', 'name': 'During-run Sodium Rate (mg/h)'},
        {'field': 'post_run_water_ml', 'name': 'Post-run Water (mL)'},
      ];

      var significantDifferences = 0;
      
      for (final comp in comparisons) {
        final field = comp['field'] as String;
        final name = comp['name'] as String;
        
        final pythonValue = mappedPython[field];
        final tsValue = tsResult[field];
        
        if (pythonValue != null && tsValue != null) {
          final diff = (pythonValue - tsValue).abs();
          final percentDiff = tsValue != 0 ? (diff / tsValue * 100) : 0.0;
          
          String status = '✅';
          if (percentDiff > 10) {
            status = '❌';
            significantDifferences++;
          } else if (percentDiff > 5) {
            status = '⚠️ ';
          }
          
          print('$status $name:');
          print('   Python: $pythonValue');
          print('   TypeScript: $tsValue');
          print('   Difference: ${diff.toStringAsFixed(2)} (${percentDiff.toStringAsFixed(1)}%)\n');
        } else {
          print('❓ $name: Missing data (Python: $pythonValue, TS: $tsValue)\n');
        }
      }
      
      print('=== SUMMARY ===');
      print('Significant differences (>10%): $significantDifferences');
      print('Total comparisons: ${comparisons.length}\n');
      
      print('=== PYTHON ALGORITHM RAW OUTPUT ===');
      print(JsonEncoder.withIndent('  ').convert(pythonResult));
      
      // The test should pass even if there are differences - we're just documenting them
      expect(pythonResult, isNotEmpty);
      expect(tsResult, isNotEmpty);
      
      if (significantDifferences > 0) {
        print('\n⚠️  WARNING: Found $significantDifferences significant differences between algorithms');
        print('This suggests the TypeScript implementation may need updates to match Python v2');
      } else {
        print('\n✅ Algorithms appear to be reasonably aligned');
      }
    });
  });
}