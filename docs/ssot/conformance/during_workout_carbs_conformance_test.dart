// QA conformance — during-workout carbs (single-sport core).
// Copied into app/test/ by run_dart.sh; run with --dart-define=QA_VECTORS=<path>.
// Asserts OfflineMacroCalculator.calculateDuringWorkoutCarbRate vs the golden vectors.
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

  group('during-workout carbs conformance (${vectors.length} vectors)', () {
    for (final v in vectors) {
      final id = v['id'] as String;
      final status = (v['status'] as String?) ?? 'ratified';
      final i = v['inputs'] as Map<String, dynamic>;
      final e = v['expected'] as Map<String, dynamic>;

      test('[$status] $id', () {
        final out = OfflineMacroCalculator.calculateDuringWorkoutCarbRate(
          durationMin: (i['durationMin'] as num).toDouble(),
          activityType: i['activityType'] as String,
          gutTraining: i['gutTraining'] as String,
        );
        void chkInt(String k) {
          if (e.containsKey(k)) expect(out[k], e[k], reason: '$id: $k (${v['why']})');
        }
        void chkNum(String k) {
          if (e.containsKey(k)) {
            expect((out[k] as num).toDouble(), closeTo((e[k] as num).toDouble(), 0.05),
                reason: '$id: $k (${v['why']})');
          }
        }
        chkNum('rate_gph');
        chkInt('band_low');
        chkInt('band_high');
        chkInt('sport_ceiling');
        chkNum('gut_multiplier');
      });
    }
  });
}
