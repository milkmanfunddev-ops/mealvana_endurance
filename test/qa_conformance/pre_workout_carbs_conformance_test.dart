// QA conformance — pre-workout carbohydrate, SSOT v2 (ratified 2026-08-04).
//
// Lives in docs/ssot/conformance/; copied into <app>/test/ by run_dart.sh and run with
//   flutter test ... --dart-define=QA_VECTORS=<abs path to the vectors json>
//
// Two layers:
//   1. VECTORS  — every golden vector in vectors/fueling/pre-workout-carbs.json, including a
//      full ordered walk of the `tiers` array (tier / carbsG / rangeLowG / rangeHighG /
//      composition), the tier count, and `targetBasis` exactly.
//   2. PROPERTY — spec invariants 1..9 and 11 swept over the app's real input domain: the
//      17-point 15-minute lead-time grid 0..240 and body weights 30..160 kg.
//
// Contract notes this harness enforces (see scratchpad API_CONTRACT.md + the spec):
//   - `calculatePreWorkoutCarbs` takes bodyWeightKg / timeBeforeWorkoutMin /
//     workoutDurationMin / isFasted — NOT v1's weightKg + hoursBefore
//   - fields are camelCase doubles (carbsG, not carbs_g) and the engine NEVER rounds
//   - `composition` values are owned by pre-workout-food-composition.md; only PRESENCE
//     (and its mirroring of `tier`) is checked here
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/offline_macro_calculator.dart';

// ---------------------------------------------------------------------------
// Spec constants, mirrored here deliberately — the harness must be an INDEPENDENT
// checker. Importing the engine's own constants would let a wrong constant agree
// with itself and go green.
// ---------------------------------------------------------------------------
const double kTierMealMin = 120.0;
const double kTierTopoffMax = 30.0;
const double kWindowMax = 240.0;
const double kShareMeal = 0.60;
const double kShareSnack = 0.30;
const double kShareTopoff = 0.10;
const double kShareSnackNm = 0.75;
const double kShareTopoffNm = 0.25;
const double kTierTol = 0.125;

/// Spec invariant 5 demands exactness "to 1e-9, not approximately".
const double kExact = 1e-9;

const List<double> kLeadGrid = <double>[
  0,
  15,
  30,
  45,
  60,
  75,
  90,
  105,
  120,
  135,
  150,
  165,
  180,
  195,
  210,
  225,
  240,
];

Iterable<double> get kBodyWeights sync* {
  for (var bw = 30.0; bw <= 160.0; bw += 5.0) {
    yield bw;
  }
}

PreWorkoutCarbResult calc(
  double bw,
  double t, {
  double durationMin = 90,
  bool isFasted = false,
}) {
  return OfflineMacroCalculator.calculatePreWorkoutCarbs(
    bodyWeightKg: bw,
    timeBeforeWorkoutMin: t,
    workoutDurationMin: durationMin,
    isFasted: isFasted,
  );
}

PreWorkoutCarbTier? tierNamed(PreWorkoutCarbResult r, String name) {
  for (final t in r.tiers) {
    if (t.tier == name) return t;
  }
  return null;
}

void main() {
  // App-side adaptation of the QA conformance harness (2026-08-07). The QA
  // repo's checked-in harness is stale against its own regenerated vectors and
  // the implemented engine API, so the runnable copy lives here; docs/ssot is
  // a VERBATIM mirror of the QA repo and is never edited. Vectors are read
  // from the mirror by default; --dart-define=QA_VECTORS overrides (so the QA
  // repo's run_dart.sh can still point this at its own checkout).
  const overridePath = String.fromEnvironment('QA_VECTORS');
  final vectorsPath = overridePath.isNotEmpty
      ? overridePath
      : 'docs/ssot/vectors/fueling/pre-workout-carbs.json';

  final doc =
      jsonDecode(File(vectorsPath).readAsStringSync()) as Map<String, dynamic>;
  final vectors = (doc['vectors'] as List).cast<Map<String, dynamic>>();
  final tolG = ((doc['toleranceG'] as num?) ?? 0.001).toDouble();

  // =========================================================================
  // Layer 1 — golden vectors
  // =========================================================================
  group('pre-workout carbs conformance (${vectors.length} vectors)', () {
    for (final v in vectors) {
      final id = v['id'] as String;
      final status = (v['status'] as String?) ?? 'ratified';
      final inp = v['inputs'] as Map<String, dynamic>;
      final exp = v['expected'] as Map<String, dynamic>;
      final why = v['why'];

      test('[$status] $id', () {
        final out = OfflineMacroCalculator.calculatePreWorkoutCarbs(
          bodyWeightKg: (inp['bodyWeightKg'] as num).toDouble(),
          timeBeforeWorkoutMin: (inp['timeBeforeWorkoutMin'] as num).toDouble(),
          workoutDurationMin: (inp['workoutDurationMin'] as num).toDouble(),
          isFasted: (inp['isFasted'] as bool?) ?? false,
        );

        void chkG(String key, double actual) {
          if (!exp.containsKey(key)) return;
          expect(
            actual,
            closeTo((exp[key] as num).toDouble(), tolG),
            reason: '$id: $key (abs tol $tolG g). $why',
          );
        }

        chkG('carbsG', out.carbsG);
        chkG('carbsLowG', out.carbsLowG);
        chkG('carbsHighG', out.carbsHighG);

        expect(
          out.targetBasis,
          exp['targetBasis'],
          reason: '$id: targetBasis. $why',
        );

        // --- the tiers array, walked in order -------------------------------
        final expTiers = (exp['tiers'] as List).cast<Map<String, dynamic>>();
        expect(
          out.tiers,
          isNotNull,
          reason: '$id: tiers is never null (empty when fasted)',
        );
        expect(
          out.tiers.length,
          expTiers.length,
          reason:
              '$id: tier COUNT — expected ${expTiers.map((t) => t['tier']).toList()}, '
              'got ${out.tiers.map((t) => t.tier).toList()}. $why',
        );
        expect(
          out.tiers.map((t) => t.tier).toList(),
          expTiers.map((t) => t['tier']).toList(),
          reason: '$id: tier MEMBERSHIP and ORDER (furthest-out first). $why',
        );

        for (var k = 0; k < expTiers.length; k++) {
          final et = expTiers[k];
          final at = out.tiers[k];
          final w = '$id: tiers[$k] (${et['tier']})';
          expect(at.tier, et['tier'], reason: '$w: tier');
          expect(
            at.carbsG,
            closeTo((et['carbsG'] as num).toDouble(), tolG),
            reason: '$w: carbsG',
          );
          expect(
            at.rangeLowG,
            closeTo((et['rangeLowG'] as num).toDouble(), tolG),
            reason: '$w: rangeLowG',
          );
          expect(
            at.rangeHighG,
            closeTo((et['rangeHighG'] as num).toDouble(), tolG),
            reason: '$w: rangeHighG',
          );
          expect(at.composition, et['composition'], reason: '$w: composition');
        }

        // Invariant 1 — the plan total is the tiers, not a separate number.
        final sum = out.tiers.fold<double>(0, (a, t) => a + t.carbsG);
        expect(
          sum,
          closeTo(out.carbsG, tolG),
          reason:
              '$id: sum(tiers[].carbsG)=$sum must equal carbsG=${out.carbsG} (inv 1)',
        );
      });
    }
  });

  // =========================================================================
  // Layer 2 — spec invariants as property tests
  // =========================================================================
  group('pre-workout carbs invariants (property, grid 0..240 x BW 30..160)', () {
    test('inv 1 — carbsG == sum(tiers[].carbsG) everywhere', () {
      for (final bw in kBodyWeights) {
        for (final t in kLeadGrid) {
          for (final dur in <double>[45, 60, 90]) {
            final o = calc(bw, t, durationMin: dur);
            final sum = o.tiers.fold<double>(0, (a, x) => a + x.carbsG);
            expect(
              sum,
              closeTo(o.carbsG, kExact),
              reason:
                  'BW=$bw t=$t dur=$dur: tiers sum $sum != carbsG ${o.carbsG}',
            );
          }
        }
      }
    });

    test('inv 2 — carbsLowG <= carbsG <= carbsHighG', () {
      for (final bw in kBodyWeights) {
        for (final t in kLeadGrid) {
          for (final dur in <double>[45, 60, 90]) {
            final o = calc(bw, t, durationMin: dur);
            expect(
              o.carbsLowG <= o.carbsG + kExact,
              isTrue,
              reason: 'BW=$bw t=$t dur=$dur: low ${o.carbsLowG} > ${o.carbsG}',
            );
            expect(
              o.carbsG <= o.carbsHighG + kExact,
              isTrue,
              reason:
                  'BW=$bw t=$t dur=$dur: ${o.carbsG} > high ${o.carbsHighG}',
            );
          }
        }
      }
    });

    test('inv 3 — carbsG is non-decreasing in t', () {
      for (final bw in kBodyWeights) {
        var prev = double.negativeInfinity;
        for (final t in kLeadGrid) {
          final cur = calc(bw, t).carbsG;
          expect(
            cur >= prev - kExact,
            isTrue,
            reason: 'BW=$bw: carbsG dropped from $prev to $cur at t=$t',
          );
          prev = cur;
        }
      }
    });

    test(
      'inv 4 — containment in the cited box: 1.0 <= carbsG/BW <= 4.0 for 60 <= t <= 240',
      () {
        for (final bw in kBodyWeights) {
          for (final t in kLeadGrid.where((t) => t >= 60 && t <= kWindowMax)) {
            final perKg = calc(bw, t).carbsG / bw;
            expect(
              perKg >= 1.0 - kExact,
              isTrue,
              reason:
                  'BW=$bw t=$t: $perKg g/kg is under Thomas 2016\'s 1 g/kg floor',
            );
            expect(
              perKg <= 4.0 + kExact,
              isTrue,
              reason:
                  'BW=$bw t=$t: $perKg g/kg breaches Thomas 2016\'s 4 g/kg ceiling',
            );
          }
        }
      },
    );

    test(
      'inv 5 — shares are EXACT (1e-9): 60/30/10 above 120, 75/25 above 30, 100 below',
      () {
        for (final bw in kBodyWeights) {
          for (final t in kLeadGrid) {
            final o = calc(bw, t);
            final total = o.carbsG;
            final where = 'BW=$bw t=$t';
            if (t >= kTierMealMin) {
              expect(
                tierNamed(o, 'meal')!.carbsG,
                closeTo(kShareMeal * total, kExact),
                reason: '$where: meal share != 0.60',
              );
              expect(
                tierNamed(o, 'snack')!.carbsG,
                closeTo(kShareSnack * total, kExact),
                reason: '$where: snack share != 0.30',
              );
              expect(
                tierNamed(o, 'top_off')!.carbsG,
                closeTo(kShareTopoff * total, kExact),
                reason: '$where: top_off share != 0.10',
              );
            } else if (t >= kTierTopoffMax) {
              expect(
                tierNamed(o, 'snack')!.carbsG,
                closeTo(kShareSnackNm * total, kExact),
                reason: '$where: no-meal snack share != 0.75',
              );
              expect(
                tierNamed(o, 'top_off')!.carbsG,
                closeTo(kShareTopoffNm * total, kExact),
                reason: '$where: no-meal top_off share != 0.25',
              );
            } else {
              expect(
                tierNamed(o, 'top_off')!.carbsG,
                closeTo(total, kExact),
                reason:
                    '$where: the top-off must carry 100% below TIER_TOPOFF_MAX',
              );
            }
          }
        }
      },
    );

    test(
      'inv 6 — tier membership is exactly: meal iff t>=120, snack iff t>=30, top_off always',
      () {
        for (final bw in kBodyWeights) {
          for (final t in kLeadGrid) {
            final o = calc(bw, t);
            final names = o.tiers.map((x) => x.tier).toList();
            final where = 'BW=$bw t=$t -> $names';
            expect(
              names.contains('meal'),
              t >= kTierMealMin,
              reason: '$where: meal membership',
            );
            expect(
              names.contains('snack'),
              t >= kTierTopoffMax,
              reason: '$where: snack membership',
            );
            expect(
              names.contains('top_off'),
              isTrue,
              reason:
                  '$where: the top-off tier is ALWAYS emitted (zero-valued at t=0)',
            );
            // Ordered furthest-out first, no duplicates.
            expect(
              names.toSet().length,
              names.length,
              reason: '$where: duplicate tier',
            );
            final rank = <String, int>{'meal': 0, 'snack': 1, 'top_off': 2};
            for (var k = 1; k < names.length; k++) {
              expect(
                rank[names[k]]! > rank[names[k - 1]]!,
                isTrue,
                reason: '$where: tiers must be ordered furthest-out first',
              );
            }
          }
        }
      },
    );

    test(
      'inv 7 — boundary steps at t=120 and t=30 are pinned; carbsG itself is continuous',
      () {
        const eps = 1e-5;
        for (final bw in kBodyWeights) {
          // --- t = 120: the meal's share transfers to the snack, total unchanged.
          final above120 = calc(bw, kTierMealMin);
          final below120 = calc(bw, kTierMealMin - eps);
          expect(
            (above120.carbsG - below120.carbsG).abs() < 1e-4 * bw,
            isTrue,
            reason:
                'BW=$bw: carbsG is discontinuous at t=120 '
                '(${below120.carbsG} -> ${above120.carbsG})',
          );
          expect(
            tierNamed(above120, 'meal'),
            isNotNull,
            reason: 'BW=$bw: meal opens at t=120',
          );
          expect(
            tierNamed(below120, 'meal'),
            isNull,
            reason: 'BW=$bw: no meal below t=120',
          );
          expect(
            tierNamed(above120, 'snack')!.carbsG,
            closeTo(kShareSnack * above120.carbsG, kExact),
            reason: 'BW=$bw: snack is 0.30 at t=120',
          );
          expect(
            tierNamed(below120, 'snack')!.carbsG,
            closeTo(kShareSnackNm * below120.carbsG, kExact),
            reason:
                'BW=$bw: snack STEPS to 0.75 just below t=120 — pin it, do not smooth it',
          );

          // --- t = 30: the snack's share transfers to the top-off, total unchanged.
          final above30 = calc(bw, kTierTopoffMax);
          final below30 = calc(bw, kTierTopoffMax - eps);
          expect(
            (above30.carbsG - below30.carbsG).abs() < 1e-4 * bw,
            isTrue,
            reason:
                'BW=$bw: carbsG is discontinuous at t=30 '
                '(${below30.carbsG} -> ${above30.carbsG})',
          );
          expect(
            tierNamed(above30, 'snack'),
            isNotNull,
            reason: 'BW=$bw: snack opens at t=30',
          );
          expect(
            tierNamed(below30, 'snack'),
            isNull,
            reason: 'BW=$bw: no snack below t=30',
          );
          expect(
            tierNamed(above30, 'top_off')!.carbsG,
            closeTo(kShareTopoffNm * above30.carbsG, kExact),
            reason: 'BW=$bw: top-off is 0.25 at t=30',
          );
          expect(
            tierNamed(below30, 'top_off')!.carbsG,
            closeTo(below30.carbsG, kExact),
            reason: 'BW=$bw: top-off STEPS to 100% just below t=30 — pin it',
          );
        }
      },
    );

    test(
      'inv 8 — isFasted returns zeros and an EMPTY tiers array, never null',
      () {
        for (final bw in kBodyWeights) {
          for (final t in kLeadGrid) {
            for (final dur in <double>[45, 90]) {
              final o = calc(bw, t, durationMin: dur, isFasted: true);
              final where = 'BW=$bw t=$t dur=$dur isFasted';
              expect(o.carbsG, 0.0, reason: '$where: carbsG');
              expect(o.carbsLowG, 0.0, reason: '$where: carbsLowG');
              expect(o.carbsHighG, 0.0, reason: '$where: carbsHighG');
              expect(
                o.tiers,
                isEmpty,
                reason: '$where: tiers must be EMPTY (distinct from t=0)',
              );
              expect(o.targetBasis, 'none', reason: '$where: targetBasis');
            }
          }
        }
        // t=0 is a DIFFERENT statement: zero with the top_off tier present carrying 0.
        final zero = calc(65, 0);
        expect(zero.carbsG, 0.0);
        expect(
          zero.tiers.length,
          1,
          reason: 't=0 emits the top_off tier carrying 0, not []',
        );
        expect(zero.tiers.single.tier, 'top_off');
        expect(
          zero.targetBasis,
          'design_choice',
          reason: 't=0 is design_choice; only isFasted is "none"',
        );
      },
    );

    test('inv 9 — composition is present on every tier and mirrors `tier`', () {
      for (final bw in kBodyWeights) {
        for (final t in kLeadGrid) {
          for (final x in calc(bw, t).tiers) {
            expect(
              x.composition,
              isNotEmpty,
              reason: 'BW=$bw t=$t: tier ${x.tier} has no composition tag',
            );
            expect(
              x.composition,
              x.tier,
              reason:
                  'BW=$bw t=$t: composition must mirror tier (VALUES are owned by '
                  'pre-workout-food-composition.md; only presence + mirroring is asserted here)',
            );
          }
        }
      }
    });

    test(
      'inv 11 (amended) + inv 12 — tier windows are +/-12.5% and sum to the plan band, unconditionally',
      () {
        for (final bw in kBodyWeights) {
          for (final t in kLeadGrid) {
            for (final dur in <double>[59, 90]) {
              final o = calc(bw, t, durationMin: dur);
              final where = 'BW=$bw t=$t dur=$dur';
              for (final x in o.tiers) {
                expect(
                  x.rangeLowG,
                  closeTo(x.carbsG * (1 - kTierTol), kExact),
                  reason: '$where: ${x.tier} rangeLowG != carbsG*0.875',
                );
                expect(
                  x.rangeHighG,
                  closeTo(x.carbsG * (1 + kTierTol), kExact),
                  reason: '$where: ${x.tier} rangeHighG != carbsG*1.125',
                );
                expect(
                  x.rangeLowG <= x.carbsG + kExact,
                  isTrue,
                  reason: '$where: ${x.tier} low',
                );
                expect(
                  x.carbsG <= x.rangeHighG + kExact,
                  isTrue,
                  reason: '$where: ${x.tier} high',
                );
              }
              // Invariant 12 (RULED Xuan, 2026-09-04, post-ratification
              // amendment): the plan band is target ± 12.5% in ALL cases —
              // the tier-window sum equals the plan band unconditionally.
              // (The cited-regime [1*BW, 4*BW] branch that lived here is
              // SUPERSEDED; targetBasis still describes the TARGET's
              // derivation, never the band.)
              final sumLow = o.tiers.fold<double>(
                0,
                (a, x) => a + x.rangeLowG,
              );
              final sumHigh = o.tiers.fold<double>(
                0,
                (a, x) => a + x.rangeHighG,
              );
              expect(
                sumLow,
                closeTo(o.carbsLowG, kExact),
                reason:
                    '$where: sum(rangeLowG)=$sumLow != carbsLowG=${o.carbsLowG}',
              );
              expect(
                sumHigh,
                closeTo(o.carbsHighG, kExact),
                reason:
                    '$where: sum(rangeHighG)=$sumHigh != carbsHighG=${o.carbsHighG}',
              );
            }
          }
        }
      },
    );

    test(
      'targetBasis flips on BOTH legs: workoutDurationMin at 59.999/60 and t at 59.999/60',
      () {
        for (final bw in kBodyWeights) {
          expect(
            calc(bw, 180, durationMin: 59.999).targetBasis,
            'design_choice',
            reason: 'BW=$bw: a sub-60-min workout leaves Thomas 2016\'s scope',
          );
          expect(
            calc(bw, 180, durationMin: 60).targetBasis,
            'evidenced_band',
            reason: 'BW=$bw: 60 min is INCLUSIVE',
          );
          expect(
            calc(bw, 59.999, durationMin: 90).targetBasis,
            'design_choice',
            reason: 'BW=$bw: a sub-1h lead time leaves the cited window',
          );
          expect(
            calc(bw, 60, durationMin: 90).targetBasis,
            'evidenced_band',
            reason: 'BW=$bw: t=60 is INCLUSIVE',
          );
        }
      },
    );
  });

  // =========================================================================
  // Cross-spec pin (carbs inv 10 / hydration inv 10)
  // =========================================================================
  group('cross-spec pin', () {
    test('TIER_MEAL_MIN == pre-workout-hydration.T_REF (both 120.0)', () {
      // Asserted BEHAVIOURALLY so the pin holds without either spec's constants
      // being exported: TIER_MEAL_MIN is the lowest grid lead time at which a
      // `meal` tier appears; T_REF is the lowest at which hydration is `cited`.
      final mealMinObserved = kLeadGrid.firstWhere(
        (t) => calc(65, t).tiers.any((x) => x.tier == 'meal'),
        orElse: () => double.nan,
      );
      final tRefObserved = kLeadGrid.firstWhere(
        (t) =>
            OfflineMacroCalculator.calculatePreWorkoutHydration(
              bodyWeightKg: 65,
              workoutDurationMin: 90,
              timeBeforeWorkoutMin: t,
              tempC: 22,
            ).regime ==
            'cited',
        orElse: () => double.nan,
      );
      expect(
        mealMinObserved,
        kTierMealMin,
        reason: 'carbs TIER_MEAL_MIN drifted off 120.0',
      );
      expect(
        tRefObserved,
        kTierMealMin,
        reason:
            'hydration T_REF ($tRefObserved) diverged from carbs TIER_MEAL_MIN '
            '($mealMinObserved). Pinned equal by assertion, NOT shared code — they are equal '
            'for unrelated reasons (epistemic vs physiological). Fail loudly, do not derive.',
      );
    });
  });
}
