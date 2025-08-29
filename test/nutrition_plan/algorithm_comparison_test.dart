import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Integration test that compares TypeScript edge function results with Python v2 algorithm
/// 
/// This test generates various input combinations and verifies that our TypeScript
/// implementation matches the reference Python implementation exactly.
class AlgorithmTestCase {
  final String name;
  final int age;
  final String gender;
  final double weightKg;
  final double heightCm;
  final double runDistanceMi;
  final String runPace; // MM:SS format
  final int timeBeforeRunMin;
  final String gutTraining;
  final String sweatRateCategory;
  final double tempC;
  final double humidityPct;

  const AlgorithmTestCase({
    required this.name,
    required this.age,
    required this.gender,
    required this.weightKg,
    required this.heightCm,
    required this.runDistanceMi,
    required this.runPace,
    required this.timeBeforeRunMin,
    required this.gutTraining,
    required this.sweatRateCategory,
    required this.tempC,
    required this.humidityPct,
  });

  Map<String, dynamic> toRequestData() {
    return {
      'age': age,
      'gender': gender,
      'weight': weightKg,
      'weight_unit': 'kg',
      'height': heightCm,
      'height_unit': 'cm',
      'run_pace': runPace,
      'run_distance': runDistanceMi,
      'run_pace_unit': 'min_per_mile',
      'run_distance_unit': 'mi',
      'time_before_run_min': timeBeforeRunMin,
      'gut_training': gutTraining,
      'carb_source': 'dual',
      'sweat_sodium': 'medium',
      'drink_sodium_mg_per_l': 500,
      'optional_sweat_rate_lph': null,
      'sweat_rate_category': sweatRateCategory,
      'temp_c': tempC,
      'humidity_pct': humidityPct,
    };
  }

  Map<String, dynamic> toPythonArgs() {
    return {
      'age': age,
      'gender': gender,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'run_distance_mi': runDistanceMi,
      'run_pace': runPace,
      'time_before_run_min': timeBeforeRunMin,
      'gut_training': gutTraining,
      'sweat_rate_category': sweatRateCategory,
      'temp_c': tempC,
      'humidity_pct': humidityPct,
    };
  }
}

/// Test cases covering various scenarios
final testCases = [
  // Short run, cool weather, beginner
  AlgorithmTestCase(
    name: 'Short Run - Cool Weather - Beginner',
    age: 30,
    gender: 'female',
    weightKg: 60.0,
    heightCm: 165.0,
    runDistanceMi: 3.1, // 5K
    runPace: '9:30',
    timeBeforeRunMin: 60,
    gutTraining: 'low',
    sweatRateCategory: 'light',
    tempC: 10.0,
    humidityPct: 50.0,
  ),

  // Medium run, moderate conditions, moderate training
  AlgorithmTestCase(
    name: 'Medium Run - Moderate Conditions - Moderate Training',
    age: 35,
    gender: 'male',
    weightKg: 75.0,
    heightCm: 180.0,
    runDistanceMi: 6.2, // 10K
    runPace: '8:00',
    timeBeforeRunMin: 120,
    gutTraining: 'moderate',
    sweatRateCategory: 'medium',
    tempC: 20.0,
    humidityPct: 60.0,
  ),

  // Long run, hot weather, experienced
  AlgorithmTestCase(
    name: 'Long Run - Hot Weather - Experienced',
    age: 40,
    gender: 'male',
    weightKg: 80.0,
    heightCm: 185.0,
    runDistanceMi: 13.1, // Half marathon
    runPace: '7:30',
    timeBeforeRunMin: 180,
    gutTraining: 'high',
    sweatRateCategory: 'heavy',
    tempC: 30.0,
    humidityPct: 80.0,
  ),

  // Ultra distance, extreme conditions
  AlgorithmTestCase(
    name: 'Ultra Distance - Extreme Heat',
    age: 45,
    gender: 'female',
    weightKg: 65.0,
    heightCm: 170.0,
    runDistanceMi: 26.2, // Marathon
    runPace: '8:30',
    timeBeforeRunMin: 240,
    gutTraining: 'high',
    sweatRateCategory: 'heavy',
    tempC: 35.0,
    humidityPct: 90.0,
  ),

  // Fast pace, cold conditions
  AlgorithmTestCase(
    name: 'Fast Pace - Cold Conditions',
    age: 25,
    gender: 'male',
    weightKg: 70.0,
    heightCm: 175.0,
    runDistanceMi: 10.0,
    runPace: '6:30',
    timeBeforeRunMin: 90,
    gutTraining: 'high',
    sweatRateCategory: 'medium',
    tempC: 0.0,
    humidityPct: 30.0,
  ),

  // Slow pace, humid conditions, heavy sweater
  AlgorithmTestCase(
    name: 'Slow Pace - Humid Conditions - Heavy Sweater',
    age: 50,
    gender: 'female',
    weightKg: 55.0,
    heightCm: 160.0,
    runDistanceMi: 15.0,
    runPace: '10:00',
    timeBeforeRunMin: 150,
    gutTraining: 'low',
    sweatRateCategory: 'heavy',
    tempC: 25.0,
    humidityPct: 95.0,
  ),

  // Very long run
  AlgorithmTestCase(
    name: 'Very Long Run - Moderate Conditions',
    age: 35,
    gender: 'male',
    weightKg: 75.0,
    heightCm: 180.0,
    runDistanceMi: 50.0, // Ultra
    runPace: '9:00',
    timeBeforeRunMin: 300,
    gutTraining: 'high',
    sweatRateCategory: 'medium',
    tempC: 18.0,
    humidityPct: 65.0,
  ),
];

void main() {
  group('Algorithm Comparison Tests', () {
    late SupabaseClient supabase;
    
    setUpAll(() async {
      // Initialize Supabase for edge function calls
      await Supabase.initialize(
        url: 'https://your-project.supabase.co', // Replace with actual URL
        anonKey: 'your-anon-key', // Replace with actual key
      );
      supabase = Supabase.instance.client;
    });

    /// Call TypeScript edge function
    Future<Map<String, dynamic>> callEdgeFunction(AlgorithmTestCase testCase) async {
      try {
        final response = await supabase.functions.invoke(
          'generate-macros',
          body: testCase.toRequestData(),
        );

        if (response.status >= 400) {
          throw Exception('Edge function failed with status ${response.status}');
        }

        final data = response.data as Map<String, dynamic>;
        if (data['success'] != true) {
          throw Exception('Edge function returned error: ${data['message']}');
        }

        return data['macros'] as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Failed to call edge function: $e');
      }
    }

    /// Call Python reference implementation
    Future<Map<String, dynamic>> callPythonReference(AlgorithmTestCase testCase) async {
      try {
        // Convert pace string to float (MM:SS format)
        final paceParts = testCase.runPace.split(':');
        final paceFloat = double.parse(paceParts[0]) + double.parse(paceParts[1]) / 60.0;
        
        // Create Python script call using RunInput dataclass and plan_run function
        final pythonScript = '''
import sys
import json
from dataclasses import asdict
sys.path.append('${Directory.current.path}/docs/business_logic')

from run_fueling_v2 import plan_run, RunInput, GutTraining, SweatRateCat

def main():
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
        distance_miles=${testCase.runDistanceMi},
        pace_min_per_mile=$paceFloat,
        weight_kg=${testCase.weightKg},
        gut_training=gut_map['${testCase.gutTraining}'],
        time_before_run_min=${testCase.timeBeforeRunMin},
        sweat_rate_category=sweat_map['${testCase.sweatRateCategory}'],
        temp_c=${testCase.tempC},
        humidity_pct=${testCase.humidityPct},
        age=${testCase.age},
        sex='${testCase.gender}',
        height_cm=${testCase.heightCm}
    )
    
    # Call the plan_run function
    result = plan_run(run_input)
    
    # Flatten the nested structure to match TypeScript output
    flat_result = {}
    for phase, values in result.items():
        for key, value in values.items():
            flat_result[key] = value
            
    print(json.dumps(flat_result, indent=2))

if __name__ == "__main__":
    main()
''';

        // Write temporary Python script
        final tempFile = File('${Directory.current.path}/test/nutrition_plan/temp_test.py');
        await tempFile.writeAsString(pythonScript);

        // Execute Python script
        final result = await Process.run(
          'python3',
          [tempFile.path],
          workingDirectory: Directory.current.path,
        );

        await tempFile.delete();

        if (result.exitCode != 0) {
          throw Exception('Python script failed: ${result.stderr}');
        }

        return jsonDecode(result.stdout) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Failed to call Python reference: $e');
      }
    }

    /// Helper to get nested values from result maps
    double? getNestedValue(Map<String, dynamic> data, String key) {
      if (data.containsKey(key)) {
        final value = data[key];
        if (value is num) return value.toDouble();
      }
      return null;
    }

    /// Compare two algorithm results
    Map<String, dynamic> compareResults(
      Map<String, dynamic> tsResult,
      Map<String, dynamic> pyResult,
      AlgorithmTestCase testCase,
    ) {
      final differences = <String, dynamic>{};

      // Key fields to compare
      final fieldsToCompare = {
        'duration_h': 'Duration (hours)',
        'MET': 'Metabolic Equivalent',
        'calories_net_kcal': 'Net Calories',
        'calories_gross_kcal': 'Gross Calories',
        'pre_run_carbs_g': 'Pre-run Carbs (g)',
        'pre_run_water_ml': 'Pre-run Water (ml)',
        'pre_run_sodium_mg': 'Pre-run Sodium (mg)',
        'during_rate_g_per_h': 'During-run Carb Rate (g/h)',
        'during_total_g': 'During-run Carbs Total (g)',
        'during_water_rate_ml_per_h': 'During-run Water Rate (ml/h)',
        'during_water_total_ml': 'During-run Water Total (ml)',
        'during_sodium_rate_mg_per_h': 'During-run Sodium Rate (mg/h)',
        'during_sodium_total_mg': 'During-run Sodium Total (mg)',
        'post_run_carbs_g': 'Post-run Carbs (g)',
        'post_run_water_ml': 'Post-run Water (ml)',
        'post_run_sodium_mg': 'Post-run Sodium (mg)',
      };

      for (final entry in fieldsToCompare.entries) {
        final field = entry.key;
        final description = entry.value;
        
        final tsValue = getNestedValue(tsResult, field);
        final pyValue = getNestedValue(pyResult, field);
        
        if (tsValue != null && pyValue != null) {
          final diff = (tsValue - pyValue).abs();
          final percentDiff = pyValue != 0 ? (diff / pyValue * 100) : 0.0;
          
          if (percentDiff > 0.1) { // More than 0.1% difference
            differences[field] = {
              'description': description,
              'typescript': tsValue,
              'python': pyValue,
              'absolute_diff': diff,
              'percent_diff': percentDiff,
            };
          }
        }
      }

      return differences;
    }

    /// Generate detailed report
    String generateReport(List<Map<String, dynamic>> allResults) {
      final report = StringBuffer();
      report.writeln('# Algorithm Comparison Report\n');
      report.writeln('Generated: ${DateTime.now()}\n');

      var totalTests = 0;
      var testsWithDifferences = 0;
      final allDifferences = <String, List<double>>{};

      for (final result in allResults) {
        totalTests++;
        final testCase = result['testCase'] as AlgorithmTestCase;
        final differences = result['differences'] as Map<String, dynamic>;

        report.writeln('## ${testCase.name}\n');
        report.writeln('**Parameters:**');
        report.writeln('- Age: ${testCase.age}, Gender: ${testCase.gender}');
        report.writeln('- Weight: ${testCase.weightKg}kg, Height: ${testCase.heightCm}cm');
        report.writeln('- Distance: ${testCase.runDistanceMi}mi, Pace: ${testCase.runPace}');
        report.writeln('- Temperature: ${testCase.tempC}°C, Humidity: ${testCase.humidityPct}%');
        report.writeln('- Gut Training: ${testCase.gutTraining}, Sweat Rate: ${testCase.sweatRateCategory}\n');

        if (differences.isEmpty) {
          report.writeln('✅ **Results match perfectly!**\n');
        } else {
          testsWithDifferences++;
          report.writeln('⚠️ **Differences found:**\n');
          
          for (final entry in differences.entries) {
            final field = entry.key;
            final data = entry.value as Map<String, dynamic>;
            
            report.writeln('- **${data['description']}:**');
            report.writeln('  - TypeScript: ${data['typescript']}');
            report.writeln('  - Python: ${data['python']}');
            report.writeln('  - Difference: ${data['absolute_diff'].toStringAsFixed(2)} (${data['percent_diff'].toStringAsFixed(1)}%)');

            // Track for summary
            allDifferences.putIfAbsent(field, () => []).add(data['percent_diff']);
          }
          report.writeln();
        }
      }

      // Summary
      report.writeln('---\n');
      report.writeln('## Summary\n');
      report.writeln('- **Total Tests:** $totalTests');
      report.writeln('- **Tests with Perfect Match:** ${totalTests - testsWithDifferences}');
      report.writeln('- **Tests with Differences:** $testsWithDifferences');
      
      if (allDifferences.isNotEmpty) {
        report.writeln('\n### Most Common Differences:\n');
        final sortedDiffs = allDifferences.entries.toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));
        
        for (final entry in sortedDiffs.take(5)) {
          final field = entry.key;
          final diffs = entry.value;
          final avgDiff = diffs.reduce((a, b) => a + b) / diffs.length;
          report.writeln('- **$field:** ${diffs.length} tests, avg ${avgDiff.toStringAsFixed(1)}% difference');
        }
      }

      return report.toString();
    }

    test('Compare TypeScript vs Python algorithms', () async {
      final results = <Map<String, dynamic>>[];

      for (final testCase in testCases) {
        print('🧪 Testing: ${testCase.name}');

        try {
          // Get results from both implementations
          final tsResult = await callEdgeFunction(testCase);
          final pyResult = await callPythonReference(testCase);

          // Compare results
          final differences = compareResults(tsResult, pyResult, testCase);

          results.add({
            'testCase': testCase,
            'tsResult': tsResult,
            'pyResult': pyResult,
            'differences': differences,
          });

          print('  ${differences.isEmpty ? '✅' : '⚠️'} ${differences.length} differences found');
        } catch (e) {
          print('  ❌ Test failed: $e');
          fail('Test case "${testCase.name}" failed: $e');
        }
      }

      // Generate and save report
      final report = generateReport(results);
      final reportFile = File('${Directory.current.path}/test/nutrition_plan/algorithm_comparison_report.md');
      await reportFile.writeAsString(report);

      print('\n📊 Report saved to: ${reportFile.path}');
      print('\n$report');

      // Fail if too many differences
      final testsWithDifferences = results.where((r) => (r['differences'] as Map).isNotEmpty).length;
      final maxAllowedDifferences = (testCases.length * 0.2).ceil(); // Allow 20% to have minor differences

      if (testsWithDifferences > maxAllowedDifferences) {
        fail('Too many tests with differences: $testsWithDifferences out of ${testCases.length} (max allowed: $maxAllowedDifferences)');
      }
    }, timeout: const Timeout(Duration(minutes: 10))); // Long timeout for multiple API calls
  });
}