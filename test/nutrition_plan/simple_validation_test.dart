import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Simple validation test to check Python algorithm is working
void main() {
  group('Simple Python Validation', () {
    test('Validate Python algorithm with basic test case', () async {
      // Simple test case - 10K run
      final pythonScript = '''
import sys
import json
from dataclasses import asdict
sys.path.append('${Directory.current.path}/docs/business_logic')

try:
    from run_fueling_v2 import plan_run, RunInput, GutTraining, SweatRateCat
    
    # Create simple RunInput
    run_input = RunInput(
        distance_miles=6.2,  # 10K
        pace_min_per_mile=8.0,  # 8:00 min/mile
        weight_kg=75.0,
        gut_training=GutTraining.MODERATE,
        time_before_run_min=120,
        sweat_rate_category=SweatRateCat.MEDIUM,
        temp_c=20.0,
        humidity_pct=60.0,
        age=30,
        sex='male',
        height_cm=180.0
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
    import traceback
    print("ERROR:" + str(e))
    print("TRACEBACK:" + traceback.format_exc())
    sys.exit(1)
''';

      // Write temporary Python script
      final tempDir = Directory('${Directory.current.path}/test/nutrition_plan/temp');
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      
      final scriptFile = File('${tempDir.path}/simple_test.py');
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
          print('Python stderr: ${result.stderr}');
          print('Python stdout: ${result.stdout}');
          fail('Python execution failed: ${result.stderr}');
        }

        final stdout = result.stdout.toString();
        print('Python output: $stdout');
        
        if (stdout.startsWith('SUCCESS:')) {
          final jsonStr = stdout.substring(8); // Remove "SUCCESS:" prefix
          final pythonResult = jsonDecode(jsonStr) as Map<String, dynamic>;
          
          // Basic validation - ensure we get reasonable values
          // Check the actual field names from Python output
          expect(pythonResult['duration_h'], isA<num>());
          expect(pythonResult['duration_h'], greaterThan(0.0));
          expect(pythonResult['met'], isA<num>());
          expect(pythonResult['met'], greaterThan(1.0));
          expect(pythonResult['net_kcal_transport'], isA<num>());
          expect(pythonResult['net_kcal_transport'], greaterThan(0.0));
          
          print('✅ Python algorithm working correctly');
          print('   Duration: ${pythonResult['duration_h']}h');
          print('   MET: ${pythonResult['met']}');
          print('   Net calories: ${pythonResult['net_kcal_transport']}');
          print('   During carbs: ${pythonResult['carb_per_h_g']}g/h');
          
        } else if (stdout.contains('ERROR:')) {
          fail('Python algorithm error: $stdout');
        } else {
          fail('Unexpected Python output: $stdout');
        }
      } catch (e) {
        // Clean up on error
        if (await scriptFile.exists()) {
          await scriptFile.delete();
        }
        rethrow;
      }
    });
  });
}