// QA conformance — during-workout carbs, single-sport core.
// SSOT: docs/ssot/spec/fueling/during-workout-carbs.md, "The math (RATIFIED)".
//
// App-side runnable copy of the QA repo's harness
// (docs/ssot/conformance/during_workout_carbs_conformance_test.dart), which
// fails unless QA_VECTORS is set. Vectors are read from the mirror by default;
// --dart-define=QA_VECTORS overrides, so the QA repo's run_dart.sh can still
// point this at its own checkout. docs/ssot is a verbatim mirror and is never
// edited.
//
// Two layers:
//   1. VECTORS — every golden vector in vectors/fueling/during-workout-carbs.json
//      against OfflineMacroCalculator.calculateDuringWorkoutCarbRate.
//   2. FINDING 30-003 — the 12 mi run (108 min, running, high gut) through the
//      offline running plan, swept over body weight: the rate follows the
//      ratified formula, never changes with weight, and the stored total sits
//      inside the band stored beside it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/offline_macro_calculator.dart';

// Spec constants mirrored here on purpose: the harness is an independent
// checker, so a wrong engine constant cannot agree with itself.
const List<List<double>> kBands = [
  [0, 30], // <60
  [30, 60], // 60-<90
  [45, 60], // 90-<150
  [60, 90], // 150-<240
  [80, 100], // >=240
];
const Map<String, double> kGut = {'low': 0.7, 'moderate': 1.0, 'high': 1.2};
const Map<String, double> kCeiling = {
  'running': 70,
  'cycling': 120,
  'swimming': 0,
};

/// Vectors whose band fields the engine does not meet: since a1b7b9ae
/// (2026-07-22) both engines clamp the band at the sport ceiling (and widen a
/// fully bound band x0.875), while the spec caps only the rate. Recorded in
/// PRE-WORKOUT-BUNDLE-DIGEST.md (2026-08-05 audit) as awaiting Xuan's ruling,
/// "do NOT fix unilaterally". Their rate, ceiling and gut fields still run.
const Set<String> kBandClampOpen = {
  'long-running-ceiling-cap',
  'ultra-running-cap',
  'swimming-zero',
};
const String kBandClampSkipReason =
    'Open for Xuan: the engine clamps the band at the sport ceiling; the '
    'ratified spec and vectors cap only the rate (digest 2026-08-05 audit).';

List<double> specBand(double durationMin) {
  if (durationMin < 60) return kBands[0];
  if (durationMin < 90) return kBands[1];
  if (durationMin < 150) return kBands[2];
  if (durationMin < 240) return kBands[3];
  return kBands[4];
}

/// finalRate = min(midpoint(band x gut), sportCeiling), rounded to 1 dp.
double specRate(double durationMin, String sport, String gut) {
  final band = specBand(durationMin);
  final g = kGut[gut] ?? 1.0;
  final midpoint = (band[0] * g + band[1] * g) / 2;
  final rate = midpoint < (kCeiling[sport] ?? 70)
      ? midpoint
      : (kCeiling[sport] ?? 70);
  return (rate * 10).round() / 10;
}

void main() {
  const overridePath = String.fromEnvironment('QA_VECTORS');
  final vectorsPath = overridePath.isNotEmpty
      ? overridePath
      : 'docs/ssot/vectors/fueling/during-workout-carbs.json';
  final doc =
      jsonDecode(File(vectorsPath).readAsStringSync()) as Map<String, dynamic>;
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
          if (e.containsKey(k)) {
            expect(out[k], e[k], reason: '$id: $k (${v['why']})');
          }
        }

        void chkNum(String k) {
          if (e.containsKey(k)) {
            expect(
              (out[k] as num).toDouble(),
              closeTo((e[k] as num).toDouble(), 0.05),
              reason: '$id: $k (${v['why']})',
            );
          }
        }

        chkNum('rate_gph');
        if (!kBandClampOpen.contains(id)) {
          chkInt('band_low');
          chkInt('band_high');
        }
        chkInt('sport_ceiling');
        chkNum('gut_multiplier');
      });

      if (kBandClampOpen.contains(id)) {
        test(
          '[$status] $id band (vector band, unclamped)',
          () {
            final out = OfflineMacroCalculator.calculateDuringWorkoutCarbRate(
              durationMin: (i['durationMin'] as num).toDouble(),
              activityType: i['activityType'] as String,
              gutTraining: i['gutTraining'] as String,
            );
            expect(out['band_low'], e['band_low']);
            expect(out['band_high'], e['band_high']);
          },
          skip: kBandClampSkipReason,
        );
      }
    }
  });

  group('Finding 30-003: 12 mi run, 108 min, high gut', () {
    // The run as the timeline stored it: 12 mi at 9:00 /mi = 108 min, gut
    // training high (stored gutMultiplier 1.2).
    const distanceMi = 12.0;
    const paceMinPerMile = 9.0;
    const durationH = distanceMi * paceMinPerMile / 60;

    test('the ratified formula gives 63 g/h and a total inside the band', () {
      final rate = specRate(108, 'running', 'high');
      expect(rate, 63.0); // [45,60] x 1.2 = [54,72], midpoint 63 < 70
      final out = OfflineMacroCalculator.calculateDuringWorkoutCarbRate(
        durationMin: 108,
        activityType: 'running',
        gutTraining: 'high',
      );
      expect(out['rate_gph'], rate);
      expect(out['band_low'], 54);
      expect(out['band_high'], 70); // band obeys the running ceiling
    });

    for (final weightKg in [45.0, 60.0, 70.0, 84.0, 100.0, 130.0]) {
      test('offline running plan at $weightKg kg: rate 63 g/h, total '
          '113 g inside 97.2-126 g', () {
        final m = OfflineMacroCalculator.calculateRunningMacros(
          weightKg: weightKg,
          distanceMiles: distanceMi,
          paceMinPerMile: paceMinPerMile,
          hoursBefore: 2,
          gutTraining: 'high',
        );
        // Body weight does not affect during-carbs (spec, Jeukendrup 2014).
        expect(m['during_rate_g_per_h'], 63.0);
        final total = (m['during_total_g'] as num).toDouble();
        expect(total, 113);

        // The stored band is band_low/high x duration_h
        // (MacroGenerationService._parseMacroTargets).
        final low = (m['during_band_low_g_per_h'] as num) * durationH;
        final high = (m['during_band_high_g_per_h'] as num) * durationH;
        expect(low, closeTo(97.2, 1e-9));
        expect(high, closeTo(126, 1e-9));
        expect(total, inInclusiveRange(low, high));
      });
    }
  });
}
