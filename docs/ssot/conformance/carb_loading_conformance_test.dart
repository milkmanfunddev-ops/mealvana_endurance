// QA conformance — carb-loading protocol + pace ramp, SSOT v1 (ratified
// 2026-09-24; Q-CL11 anchor addendum same day; bundle carb-loading@v1 @
// f809f54).
//
// Lives in qa/conformance/; copied into <app>/test/ by run_dart.sh and run:
//   flutter test ... --dart-define=QA_VECTORS=<abs path to carb-loading.json>
//
// Two layers:
//   1. VECTORS — every golden vector in vectors/fueling/carb-loading.json,
//      dispatched on its expected keys: day targets (CL-1..3 + Q-CL3a), slot
//      targets (CL-4), ramp anchors/owed (CL-6/Q-CL11 Option-R + the 22:00
//      clamp), full pace evaluations (CL-8..11), and the day variants (null
//      fields are asserted NULL — coercing null to 0 is the bug).
//   2. PROPERTY — independent invariants swept over targets 300..900 g:
//      anchor monotonicity, the forced close anchor, owed continuity at every
//      anchor, and the band floor/5% crossover at owed == 200.
//
// The harness is an INDEPENDENT checker: tolerances and the property-layer
// constants are mirrored from the spec deliberately, never imported from the
// engine.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/carb_loading_pace_engine.dart';

const String kVectorsPath = String.fromEnvironment('QA_VECTORS');

// Spec-mirrored constants (independent of the engine's own).
const double kToleranceG = 0.001;
const double kToleranceFrac = 0.0001;
const List<int> kSlotTimes = <int>[360, 540, 720, 900, 1080, 1260];
const int kCloseMin = 1320;

void expectNum(Object? actual, Object? expected, double tol, String ctx) {
  if (expected == null) {
    expect(actual, isNull, reason: '$ctx: expected null (no value, not 0)');
    return;
  }
  expect(actual, isNotNull, reason: '$ctx: engine returned null');
  expect(
    (actual! as num).toDouble(),
    closeTo((expected as num).toDouble(), tol),
    reason: ctx,
  );
}

void main() {
  final file = File(kVectorsPath);
  if (!file.existsSync()) {
    throw StateError('QA_VECTORS not found: "$kVectorsPath"');
  }
  final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final vectors = (doc['vectors'] as List).cast<Map<String, dynamic>>();

  group('vectors: carb-loading', () {
    for (final v in vectors) {
      test(v['id'] as String, () {
        final inputs = v['inputs'] as Map<String, dynamic>;
        final expected = v['expected'] as Map<String, dynamic>;

        if (expected.containsKey('dayTargetG') && expected.length == 1) {
          final got = CarbLoadingPaceEngine.dayTargetG(
            bodyWeightLb: (inputs['bodyWeightLb'] as num).toDouble(),
            protocolDays: inputs['protocolDays'] as int,
            daysBeforeRace: inputs['daysBeforeRace'] as int,
          );
          expect(got, expected['dayTargetG']);
          return;
        }

        if (expected.containsKey('slotTargetsG') && expected.length == 1) {
          final got = CarbLoadingPaceEngine.slotTargetsG(
            inputs['dayTargetG'] as int,
          );
          expect(got, (expected['slotTargetsG'] as List).cast<int>());
          return;
        }

        if (expected.containsKey('owedG') && expected.length == 1) {
          final got = CarbLoadingPaceEngine.owedG(
            dayTargetG: inputs['dayTargetG'] as int,
            tMin: inputs['tMin'] as int,
          );
          expectNum(got, expected['owedG'], kToleranceG, 'owedG');
          return;
        }

        // Full pace evaluation, incl. day variants.
        final dayRel = switch (inputs['dayRel'] as String?) {
          'future' => CarbDayRel.future,
          'past' => CarbDayRel.past,
          _ => CarbDayRel.today,
        };
        final result = CarbLoadingPaceEngine.evaluate(
          dayTargetG: inputs['dayTargetG'] as int,
          eatenG: (inputs['eatenG'] as num).toDouble(),
          tMin: inputs['tMin'] as int,
          dayRel: dayRel,
        );
        final wire = result.toWire();
        for (final entry in expected.entries) {
          final key = entry.key;
          final want = entry.value;
          switch (key) {
            case 'owedG' || 'bandG' || 'deltaG':
              expectNum(wire[key], want, kToleranceG, key);
            case 'fillFrac' || 'tickFrac':
              expectNum(wire[key], want, kToleranceFrac, key);
            case 'paceState':
              expect(wire[key], want, reason: 'paceState (null stays null)');
            case 'paceN':
              expect(wire[key], want, reason: 'paceN');
            case 'loaded' || 'tickHidden':
              expect(wire[key], want, reason: key);
            case 'slotTargetsG':
              expect(
                CarbLoadingPaceEngine.slotTargetsG(inputs['dayTargetG'] as int),
                (want as List).cast<int>(),
                reason: 'slotTargetsG (day-variant targets still render)',
              );
            default:
              fail('vector ${v['id']} carries unknown expected key: $key');
          }
        }
      });
    }
  });

  group('properties', () {
    test('anchors are monotone and close is FORCED to the day target', () {
      for (var target = 300; target <= 900; target += 7) {
        final anchors = CarbLoadingPaceEngine.rampAnchors(target);
        expect(anchors.first, [kSlotTimes.first, 0]);
        expect(anchors.last[0], kCloseMin);
        expect(
          anchors.last[1],
          target,
          reason: 'Q-CL11 companion: 22:00 anchor == stored target ($target)',
        );
        for (var i = 1; i < anchors.length; i++) {
          expect(
            anchors[i][1].toDouble(),
            greaterThanOrEqualTo(anchors[i - 1][1].toDouble() - kToleranceG),
            reason: 'anchor grams must not decrease ($target)',
          );
        }
      }
    });

    test('owed(t) is continuous at every anchor clock', () {
      for (var target = 300; target <= 900; target += 13) {
        for (final t in [...kSlotTimes, kCloseMin]) {
          final at = CarbLoadingPaceEngine.owedG(dayTargetG: target, tMin: t);
          final before = CarbLoadingPaceEngine.owedG(
            dayTargetG: target,
            tMin: t - 1,
          );
          final slope = target.toDouble(); // generous bound, g per minute
          expect(
            (at - before).abs(),
            lessThan(slope),
            reason: 'no jump at t=$t ($target)',
          );
        }
      }
    });

    test('band floor and 5% crossover', () {
      // owed 200 is the crossover: 5% of 200 == 10.
      final low = CarbLoadingPaceEngine.evaluate(
        dayTargetG: 544,
        eatenG: 0,
        tMin: 480, // owed ~90.67 → floor region
      );
      expect(low.bandG, closeTo(10.0, kToleranceG));
      final high = CarbLoadingPaceEngine.evaluate(
        dayTargetG: 544,
        eatenG: 0,
        tMin: 1260, // owed 517 → relative region
      );
      expect(high.bandG, closeTo(25.85, kToleranceG));
    });
  });
}
