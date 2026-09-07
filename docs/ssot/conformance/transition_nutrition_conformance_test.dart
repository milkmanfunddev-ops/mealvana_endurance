// QA conformance — transition nutrition, SSOT v1 (ratified 2026-09-01).
//
// Lives in qa/conformance/; copied into <app>/test/ by run_dart.sh and run with
//   flutter test ... --dart-define=QA_VECTORS=<abs path to the vectors json>
//
// Sweeps every golden vector in vectors/fueling/transition-nutrition.json
// against the app's REAL published entry point
// (OfflineMacroCalculator.calculateTransitionCarbDose), plus the spec
// invariants the vectors' coverage note flags as unpinned:
//   - band is [0, 30] on EVERY transition (T-1)
//   - doseG is a whole number of grams (T-4)
//   - a transition into a swim doses 0 (T-2, ceiling 0)
//
// Contract notes:
//   - inputs.segments[] carry {sport, durationMin}; sport values are the
//     engine's ('cycling' | 'running' | 'swimming')
//   - inputs.transitionMin is OPTIONAL — absent means the engine's ratified
//     default 3 must apply (constants table; Q-TN3 open)
//   - expected.doseG is an integer (T-4); toleranceG kept for harness
//     uniformity with the other fueling slices
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/offline_macro_calculator.dart';

void main() {
  const vectorsPath = String.fromEnvironment('QA_VECTORS');

  final file = File(vectorsPath);
  if (vectorsPath.isEmpty || !file.existsSync()) {
    throw StateError(
      'QA_VECTORS not provided or missing: "$vectorsPath" — run via '
      'qa/conformance/run_dart.sh transition-nutrition',
    );
  }

  final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final tolerance = (doc['toleranceG'] as num?)?.toDouble() ?? 0.001;
  final vectors = (doc['vectors'] as List).cast<Map<String, dynamic>>();

  group('vectors: transition-nutrition (${vectors.length})', () {
    test('vector count sanity', () {
      expect(vectors.length, greaterThanOrEqualTo(10),
          reason: 'vector file unexpectedly small — wrong file?');
    });

    for (final vector in vectors) {
      final id = vector['id'] as String;
      final status = vector['status'] as String? ?? 'ratified';
      final inputs = vector['inputs'] as Map<String, dynamic>;
      final expected = vector['expected'] as Map<String, dynamic>;

      test('[$status] $id', () {
        final segments = (inputs['segments'] as List)
            .cast<Map<String, dynamic>>()
            .map(
              (s) => TransitionDoseSegment(
                sport: s['sport'] as String,
                durationMin: (s['durationMin'] as num).toDouble(),
              ),
            )
            .toList();

        final result = OfflineMacroCalculator.calculateTransitionCarbDose(
          segments: segments,
          transitionIndex: inputs['transitionIndex'] as int,
          gutTraining: inputs['gutTolerance'] as String? ?? 'moderate',
          transitionMin: (inputs['transitionMin'] as num?)?.toDouble(),
        );

        expect(
          (result.doseG - (expected['doseG'] as num)).abs(),
          lessThanOrEqualTo(tolerance),
          reason: '$id: doseG ${result.doseG} != ${expected['doseG']} '
              '(${vector['why']})',
        );
        expect(result.bandLowG, expected['bandLowG'],
            reason: '$id: bandLowG');
        expect(result.bandHighG, expected['bandHighG'],
            reason: '$id: bandHighG');
        // T-4: whole grams — doseG is typed int, assert non-negative too.
        expect(result.doseG, greaterThanOrEqualTo(0), reason: '$id: T-1 floor');
        expect(result.doseG, lessThanOrEqualTo(30), reason: '$id: T-1 clamp');
      });
    }
  });

  group('spec invariants (independent of the vector file)', () {
    test('T-2: any transition INTO a swim doses 0 (ceiling 0)', () {
      for (final gut in const ['low', 'moderate', 'high']) {
        final result = OfflineMacroCalculator.calculateTransitionCarbDose(
          segments: const [
            TransitionDoseSegment(sport: 'running', durationMin: 240),
            TransitionDoseSegment(sport: 'swimming', durationMin: 60),
          ],
          transitionIndex: 0,
          gutTraining: gut,
          transitionMin: 10,
        );
        expect(result.doseG, 0, reason: 'gut=$gut');
      }
    });

    test('T-1: band is [0,30] and dose clamped across a duration sweep', () {
      for (double bike = 10; bike <= 360; bike += 25) {
        for (double run = 10; run <= 180; run += 35) {
          final result = OfflineMacroCalculator.calculateTransitionCarbDose(
            segments: [
              TransitionDoseSegment(sport: 'cycling', durationMin: bike),
              TransitionDoseSegment(sport: 'running', durationMin: run),
            ],
            transitionIndex: 0,
            gutTraining: 'high',
          );
          expect(result.bandLowG, 0);
          expect(result.bandHighG, 30);
          expect(result.doseG, inInclusiveRange(0, 30),
              reason: 'bike=$bike run=$run');
        }
      }
    });
  });
}
