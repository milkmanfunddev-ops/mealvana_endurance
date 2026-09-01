// QA conformance — during-workout hydration (single-sport).
// Copied into app/test/ by run_dart.sh; run with --dart-define=QA_VECTORS=<path>.
// Asserts the real OfflineMacroCalculator.calculateDuringWorkoutHydration vs the golden
// vectors. Each vector asserts only the fields present in its "expected" object.
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

  group('during-workout hydration conformance (${vectors.length} vectors)', () {
    for (final v in vectors) {
      final id = v['id'] as String;
      final status = (v['status'] as String?) ?? 'ratified';
      final i = v['inputs'] as Map<String, dynamic>;
      final e = v['expected'] as Map<String, dynamic>;

      test('[$status] $id', () {
        final out = OfflineMacroCalculator.calculateDuringWorkoutHydration(
          durationMin: (i['durationMin'] as num).toDouble(),
          weightKg: (i['weightKg'] as num).toDouble(),
          sweatRateCategory: i['sweatRateCategory'] as String,
          sweatSodiumCat: i['sweatSodiumCat'] as String,
          tempC: (i['tempC'] as num?)?.toDouble(),
          humidityPct: (i['humidityPct'] as num?)?.toDouble(),
          isIndoor: (i['isIndoor'] as bool?) ?? false,
          sport: (i['sport'] as String?) ?? 'running',
          knownSweatRateMlPerHour: (i['knownSweatRateMlPerHour'] as num?)?.toDouble(),
          knownSodiumConcMgPerL: (i['knownSodiumConcMgPerL'] as num?)?.toDouble(),
        );
        void chkInt(String k, int actual) {
          if (e.containsKey(k)) expect(actual, e[k], reason: '$id: $k (${v['why']})');
        }
        void chkNum(String k, num actual) {
          if (e.containsKey(k)) {
            expect(actual, closeTo((e[k] as num).toDouble(), 0.0015), reason: '$id: $k');
          }
        }
        chkInt('hydrationRateMlph', out.hydrationRateMlph);
        chkInt('floorMlHr', out.floorMlHr);
        chkInt('ceilingMlHr', out.ceilingMlHr);
        chkInt('hydrationTotalMl', out.hydrationTotalMl);
        chkNum('replacementPct', out.replacementPct);
        chkNum('effectiveSweatRateLph', out.effectiveSweatRateLph);
      });
    }
  });
}
