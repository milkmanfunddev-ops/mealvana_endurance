// QA conformance — pre-workout sodium (sodium fields of calculatePreWorkoutHydration).
// Copied into app/test/ by run_dart.sh; run with --dart-define=QA_VECTORS=<path>.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/offline_macro_calculator.dart';

void main() {
  const vectorsPath = String.fromEnvironment('QA_VECTORS');
  if (vectorsPath.isEmpty) {
    test('QA_VECTORS is set', () => fail('run via qa/conformance/run_dart.sh'));
    return;
  }
  final doc = jsonDecode(File(vectorsPath).readAsStringSync()) as Map<String, dynamic>;
  final vectors = (doc['vectors'] as List).cast<Map<String, dynamic>>();

  group('pre-workout sodium conformance (${vectors.length} vectors)', () {
    for (final v in vectors) {
      final id = v['id'] as String;
      final status = (v['status'] as String?) ?? 'ratified';
      final i = v['inputs'] as Map<String, dynamic>;
      final e = v['expected'] as Map<String, dynamic>;

      test('[$status] $id', () {
        final out = OfflineMacroCalculator.calculatePreWorkoutHydration(
          bodyWeightKg: (i['bodyWeightKg'] as num).toDouble(),
          workoutDurationMin: (i['workoutDurationMin'] as num).toDouble(),
          timeBeforeWorkoutMin: (i['timeBeforeWorkoutMin'] as num).toDouble(),
          tempC: (i['tempC'] as num?)?.toDouble(),
        );
        void chkInt(String k, int actual) {
          if (e.containsKey(k)) expect(actual, e[k], reason: '$id: $k (${v['why']})');
        }
        if (e.containsKey('gateTriggered')) {
          expect(out.gateTriggered, e['gateTriggered'], reason: '$id: gateTriggered');
        }
        chkInt('tier', out.tier);
        chkInt('sodiumMg', out.sodiumMg);
        chkInt('sodiumLowMg', out.sodiumLowMg);
        chkInt('sodiumHighMg', out.sodiumHighMg);
      });
    }
  });
}
