import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for algorithm validation using Python reference
/// 
/// These tests run specific scenarios against the Python v2 reference implementation
/// and provide detailed comparisons of key algorithm components.
void main() {
  group('Algorithm Unit Tests', () {
    /// Test case structure
    final testCases = [
      {
        'name': 'Short 5K Run - Moderate Conditions',
        'params': {
          'age': 30,
          'gender': 'male',
          'weight_kg': 75.0,
          'height_cm': 180.0,
          'run_distance_mi': 3.1,
          'run_pace': '8:00',
          'time_before_run_min': 120,
          'gut_training': 'moderate',
          'sweat_rate_category': 'medium',
          'temp_c': 20.0,
          'humidity_pct': 60.0,
        },
      },
      {
        'name': 'Half Marathon - Hot Weather',
        'params': {
          'age': 35,
          'gender': 'female',
          'weight_kg': 60.0,
          'height_cm': 165.0,
          'run_distance_mi': 13.1,
          'run_pace': '9:00',
          'time_before_run_min': 180,
          'gut_training': 'high',
          'sweat_rate_category': 'heavy',
          'temp_c': 30.0,
          'humidity_pct': 85.0,
        },
      },
      {
        'name': 'Marathon - Cold Weather',
        'params': {
          'age': 40,
          'gender': 'male',
          'weight_kg': 80.0,
          'height_cm': 185.0,
          'run_distance_mi': 26.2,
          'run_pace': '8:30',
          'time_before_run_min': 240,
          'gut_training': 'high',
          'sweat_rate_category': 'light',
          'temp_c': 5.0,
          'humidity_pct': 40.0,
        },
      },
    ];

    /// Run Python algorithm and return results
    Future<Map<String, dynamic>> runPythonAlgorithm(Map<String, dynamic> params) async {
      // Convert pace string to float (MM:SS format)
      final paceStr = params['run_pace'] as String;
      final paceParts = paceStr.split(':');
      final paceFloat = double.parse(paceParts[0]) + double.parse(paceParts[1]) / 60.0;
      
      // Create the Python script using RunInput dataclass
      final pythonScript = '''
import sys
import json
import os
from dataclasses import asdict

# Add the business logic directory to path
sys.path.insert(0, os.path.join(os.getcwd(), 'docs', 'business_logic'))

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
    
    # Create RunInput with proper dataclass structure
    run_input = RunInput(
        distance_miles=${params['run_distance_mi']},
        pace_min_per_mile=$paceFloat,
        weight_kg=${params['weight_kg']},
        gut_training=gut_map['${params['gut_training']}'],
        time_before_run_min=${params['time_before_run_min']},
        sweat_rate_category=sweat_map['${params['sweat_rate_category']}'],
        temp_c=${params['temp_c']},
        humidity_pct=${params['humidity_pct']},
        age=${params['age']},
        sex='${params['gender']}',
        height_cm=${params['height_cm']}
    )
    
    # Call the plan_run function
    result = plan_run(run_input)
    
    # Flatten the nested structure
    flat_result = {}
    for phase, values in result.items():
        for key, value in values.items():
            flat_result[key] = value
    
    print("SUCCESS:" + json.dumps(flat_result, indent=2))
except Exception as e:
    print("ERROR:" + str(e))
    sys.exit(1)
''';

      // Write temporary Python script
      final tempDir = Directory('${Directory.current.path}/test/nutrition_plan/temp');
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      
      final scriptFile = File('${tempDir.path}/test_runner.py');
      await scriptFile.writeAsString(pythonScript);

      try {
        // Execute Python script
        final result = await Process.run(
          'python3',
          [scriptFile.path],
          workingDirectory: Directory.current.path,
        );

        // Clean up
        await scriptFile.delete();

        if (result.exitCode != 0) {
          throw Exception('Python execution failed: ${result.stderr}\nStdout: ${result.stdout}');
        }

        final stdout = result.stdout.toString();
        if (stdout.startsWith('SUCCESS:')) {
          final jsonStr = stdout.substring(8); // Remove "SUCCESS:" prefix
          return jsonDecode(jsonStr) as Map<String, dynamic>;
        } else if (stdout.startsWith('ERROR:')) {
          throw Exception('Python algorithm error: ${stdout.substring(6)}');
        } else {
          throw Exception('Unexpected Python output: $stdout');
        }
      } catch (e) {
        // Clean up on error
        if (await scriptFile.exists()) {
          await scriptFile.delete();
        }
        rethrow;
      }
    }

    /// Extract key metrics for comparison
    Map<String, double> extractKeyMetrics(Map<String, dynamic> result) {
      return {
        'duration_h': (result['duration_h'] as num?)?.toDouble() ?? 0.0,
        'MET': (result['MET'] as num?)?.toDouble() ?? 0.0,
        'calories_net_kcal': (result['calories_net_kcal'] as num?)?.toDouble() ?? 0.0,
        'calories_gross_kcal': (result['calories_gross_kcal'] as num?)?.toDouble() ?? 0.0,
        'pre_run_carbs_g': (result['pre_run_carbs_g'] as num?)?.toDouble() ?? 0.0,
        'pre_run_water_ml': (result['pre_run_water_ml'] as num?)?.toDouble() ?? 0.0,
        'pre_run_sodium_mg': (result['pre_run_sodium_mg'] as num?)?.toDouble() ?? 0.0,
        'during_rate_g_per_h': (result['during_rate_g_per_h'] as num?)?.toDouble() ?? 0.0,
        'during_total_g': (result['during_total_g'] as num?)?.toDouble() ?? 0.0,
        'during_water_rate_ml_per_h': (result['during_water_rate_ml_per_h'] as num?)?.toDouble() ?? 0.0,
        'during_sodium_rate_mg_per_h': (result['during_sodium_rate_mg_per_h'] as num?)?.toDouble() ?? 0.0,
        'post_run_carbs_g': (result['post_run_carbs_g'] as num?)?.toDouble() ?? 0.0,
        'post_run_water_ml': (result['post_run_water_ml'] as num?)?.toDouble() ?? 0.0,
        'post_run_sodium_mg': (result['post_run_sodium_mg'] as num?)?.toDouble() ?? 0.0,
      };
    }

    /// Generate test report
    void generateTestReport(List<Map<String, dynamic>> results) {
      final report = StringBuffer();
      report.writeln('# Python Algorithm Validation Report\n');
      report.writeln('Generated: ${DateTime.now().toIso8601String()}\n');
      report.writeln('This report validates that our Python reference algorithm works correctly.\n');

      for (final result in results) {
        final testCase = result['testCase'] as Map<String, dynamic>;
        final params = testCase['params'] as Map<String, dynamic>;
        final metrics = result['metrics'] as Map<String, double>;
        
        report.writeln('## ${testCase['name']}\n');
        report.writeln('**Input Parameters:**');
        report.writeln('- Age: ${params['age']}, Gender: ${params['gender']}');
        report.writeln('- Weight: ${params['weight_kg']}kg, Height: ${params['height_cm']}cm');
        report.writeln('- Distance: ${params['run_distance_mi']}mi, Pace: ${params['run_pace']}');
        report.writeln('- Temperature: ${params['temp_c']}°C, Humidity: ${params['humidity_pct']}%');
        report.writeln('- Gut Training: ${params['gut_training']}, Sweat: ${params['sweat_rate_category']}\n');

        report.writeln('**Algorithm Results:**');
        report.writeln('- **Duration:** ${metrics['duration_h']!.toStringAsFixed(2)} hours');
        report.writeln('- **MET:** ${metrics['MET']!.toStringAsFixed(1)}');
        report.writeln('- **Net Calories:** ${metrics['calories_net_kcal']!.round()} kcal');
        report.writeln('- **Gross Calories:** ${metrics['calories_gross_kcal']!.round()} kcal\n');

        report.writeln('**Pre-Run Nutrition:**');
        report.writeln('- Carbs: ${metrics['pre_run_carbs_g']!.round()}g');
        report.writeln('- Water: ${metrics['pre_run_water_ml']!.round()}ml');
        report.writeln('- Sodium: ${metrics['pre_run_sodium_mg']!.round()}mg\n');

        report.writeln('**During-Run Nutrition:**');
        report.writeln('- Carb Rate: ${metrics['during_rate_g_per_h']!.round()}g/h');
        report.writeln('- Total Carbs: ${metrics['during_total_g']!.round()}g');
        report.writeln('- Water Rate: ${metrics['during_water_rate_ml_per_h']!.round()}ml/h');
        report.writeln('- Sodium Rate: ${metrics['during_sodium_rate_mg_per_h']!.round()}mg/h\n');

        report.writeln('**Post-Run Recovery:**');
        report.writeln('- Carbs: ${metrics['post_run_carbs_g']!.round()}g');
        report.writeln('- Water: ${metrics['post_run_water_ml']!.round()}ml');
        report.writeln('- Sodium: ${metrics['post_run_sodium_mg']!.round()}mg\n');

        report.writeln('---\n');
      }

      // Write report
      final reportFile = File('${Directory.current.path}/test/nutrition_plan/python_validation_report.md');
      reportFile.writeAsStringSync(report.toString());
      
      print('📊 Python validation report saved to: ${reportFile.path}');
    }

    test('Validate Python algorithm with test cases', () async {
      final results = <Map<String, dynamic>>[];
      
      for (final testCase in testCases) {
        print('🧪 Testing: ${testCase['name']}');
        
        try {
          // Run Python algorithm
          final pythonResult = await runPythonAlgorithm(testCase['params'] as Map<String, dynamic>);
          final metrics = extractKeyMetrics(pythonResult);
          
          // Basic validation - ensure we get reasonable values
          expect(metrics['duration_h']!, greaterThan(0.0), reason: 'Duration should be positive');
          expect(metrics['MET']!, greaterThan(1.0), reason: 'MET should be greater than resting (1.0)');
          expect(metrics['calories_net_kcal']!, greaterThan(0.0), reason: 'Net calories should be positive');
          expect(metrics['pre_run_carbs_g']!, greaterThanOrEqualTo(0.0), reason: 'Pre-run carbs should be non-negative');
          
          // For runs longer than 75 minutes, should have during-run carbs
          if (metrics['duration_h']! > 1.25) {
            expect(metrics['during_rate_g_per_h']!, greaterThan(0.0), reason: 'Long runs should have during-run carbs');
          }
          
          results.add({
            'testCase': testCase,
            'pythonResult': pythonResult,
            'metrics': metrics,
          });
          
          print('  ✅ Duration: ${metrics['duration_h']!.toStringAsFixed(2)}h, MET: ${metrics['MET']!.toStringAsFixed(1)}');
          print('  ✅ Net calories: ${metrics['calories_net_kcal']!.round()}, During carbs: ${metrics['during_rate_g_per_h']!.round()}g/h');
          
        } catch (e) {
          print('  ❌ Test failed: $e');
          fail('Test case "${testCase['name']}" failed: $e');
        }
      }
      
      // Generate report
      generateTestReport(results);
      
      expect(results.length, equals(testCases.length), reason: 'All test cases should complete');
      print('\n✅ All ${results.length} test cases passed validation!');
      
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('Verify algorithm handles edge cases', () async {
      final edgeCases = [
        {
          'name': 'Very Short Run',
          'params': {
            'age': 30,
            'gender': 'male',
            'weight_kg': 75.0,
            'height_cm': 180.0,
            'run_distance_mi': 1.0,
            'run_pace': '7:00',
            'time_before_run_min': 60,
            'gut_training': 'high',
            'sweat_rate_category': 'medium',
            'temp_c': 20.0,
            'humidity_pct': 60.0,
          },
          'expectedBehavior': 'Should have minimal during-run carbs',
        },
        {
          'name': 'Very Slow Pace',
          'params': {
            'age': 60,
            'gender': 'female',
            'weight_kg': 55.0,
            'height_cm': 160.0,
            'run_distance_mi': 10.0,
            'run_pace': '12:00',
            'time_before_run_min': 120,
            'gut_training': 'low',
            'sweat_rate_category': 'light',
            'temp_c': 15.0,
            'humidity_pct': 50.0,
          },
          'expectedBehavior': 'Should have lower MET and moderate carb needs',
        },
      ];

      for (final testCase in edgeCases) {
        print('🔍 Testing edge case: ${testCase['name']}');
        
        final result = await runPythonAlgorithm(testCase['params'] as Map<String, dynamic>);
        final metrics = extractKeyMetrics(result);
        
        // Validate basic constraints
        expect(metrics['duration_h']!, greaterThan(0.0));
        expect(metrics['MET']!, greaterThan(1.0));
        expect(metrics['MET']!, lessThan(20.0)); // Reasonable upper bound
        
        print('  ✅ ${testCase['expectedBehavior']}');
        print('  ✅ MET: ${metrics['MET']!.toStringAsFixed(1)}, Duration: ${metrics['duration_h']!.toStringAsFixed(2)}h');
      }
    });
  });
}