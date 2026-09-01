// QA conformance — pre-workout carbs.
// Lives in qa/; copied into app/test/ by run_dart.sh and run with
//   flutter test ... --dart-define=QA_VECTORS=<abs path to the vectors json>
// Asserts the app's REAL OfflineMacroCalculator matches the QA golden vectors (layer 1).
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/offline_macro_calculator.dart';

void main() {
  const vectorsPath = String.fromEnvironment('QA_VECTORS');

  if (vectorsPath.isEmpty) {
    test('QA_VECTORS is set', () {
      fail('pass --dart-define=QA_VECTORS=<path> (run via qa/conformance/run_dart.sh)');
    });
    return;
  }

  final doc = jsonDecode(File(vectorsPath).readAsStringSync()) as Map<String, dynamic>;
  final vectors = (doc['vectors'] as List).cast<Map<String, dynamic>>();

  group('pre-workout carbs conformance (${vectors.length} vectors)', () {
    for (final v in vectors) {
      final id = v['id'] as String;
      final status = (v['status'] as String?) ?? 'ratified';
      final inp = v['inputs'] as Map<String, dynamic>;
      final exp = v['expected'] as Map<String, dynamic>;

      test('[$status] $id', () {
        final out = OfflineMacroCalculator.calculatePreWorkoutTargets(
          weightKg: (inp['weightKg'] as num).toDouble(),
          hoursBefore: (inp['hoursBefore'] as num).toDouble(),
          isFasted: inp['isFasted'] as bool,
        );
        expect(out['carbs_g'], exp['carbs_g'], reason: '$id: carbs_g (${v['why']})');
        expect(out['carbs_low_g'], exp['carbs_low_g'], reason: '$id: carbs_low_g');
        expect(out['carbs_high_g'], exp['carbs_high_g'], reason: '$id: carbs_high_g');
      });
    }
  });
}
