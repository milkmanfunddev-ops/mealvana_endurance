// QA conformance — pre-workout hydration, SSOT v6 (ratified 2026-08-04).
//
// Lives in docs/ssot/conformance/; copied into <app>/test/ by run_dart.sh and run with
//   flutter test ... --dart-define=QA_VECTORS=<abs path to the vectors json>
//
// Two layers:
//   1. VECTORS  — every golden vector in vectors/fueling/pre-workout-hydration.json.
//   2. PROPERTY — spec invariants 1,2,3,4,5,8,8a,8b,9,11 swept over the app's real input
//      domain: the 17-point 15-minute lead-time grid 0..240 and body weights 30..160 kg.
//
// Contract notes this harness enforces (see scratchpad API_CONTRACT.md + the spec):
//   - the engine NEVER rounds; fluid is compared with closeTo(expected, doc.toleranceMl)
//   - the comparison is NULL-AWARE: a 0.0 where null is expected FAILS, and vice versa
//   - the integer `tier` field is RETIRED and is never read here
//   - sodium lives in pre_workout_sodium_conformance_test.dart, not here
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/offline_macro_calculator.dart';

// ---------------------------------------------------------------------------
// Spec constants, mirrored here deliberately.
// The harness must be an INDEPENDENT checker: if it imported the engine's own
// constants, a wrong constant would agree with itself and the suite would be green.
// ---------------------------------------------------------------------------
const double kA0Ml = 250.0;
const double kRCeiling = 400.0;
const double kK = 3.2 / 60; // MUST be computed, not the literal 0.0533333
const double kTRef = 120.0;
const double kTopUpMlKg = 4.0;
const double kTopUpHighMlKg = 5.0;
const double kPlanCapMlKg = 12.0;

/// The app collects lead time in 15-minute steps from 0 to 240 — 17 values, the
/// entire input domain at a given body weight.
const List<double> kLeadGrid = <double>[
  0, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180, 195, 210, 225, 240,
];

/// Body weights swept by the property tests (spec: 30–160 kg).
Iterable<double> get kBodyWeights sync* {
  for (var bw = 30.0; bw <= 160.0; bw += 5.0) {
    yield bw;
  }
}

const List<HydrationCheck> kAllChecks = <HydrationCheck>[
  HydrationCheck.pale,
  HydrationCheck.dark,
  HydrationCheck.unknown,
];

HydrationCheck parseCheck(Object? raw) {
  switch (raw as String?) {
    case 'pale':
      return HydrationCheck.pale;
    case 'dark':
      return HydrationCheck.dark;
    case 'unknown':
    case null:
      return HydrationCheck.unknown;
    default:
      throw ArgumentError('unknown hydrationCheck in vectors: $raw');
  }
}

/// Non-gated call helper: 90-minute session at 22 °C never trips the gate
/// (`workoutDurationMin < 60 AND tempC < 30`).
PreWorkoutHydrationResult calc(
  double bw,
  double t, {
  HydrationCheck check = HydrationCheck.unknown,
  double durationMin = 90,
  double? tempC = 22,
}) {
  return OfflineMacroCalculator.calculatePreWorkoutHydration(
    bodyWeightKg: bw,
    workoutDurationMin: durationMin,
    timeBeforeWorkoutMin: t,
    tempC: tempC,
    hydrationCheck: check,
  );
}

void main() {
  const vectorsPath = String.fromEnvironment('QA_VECTORS');
  if (vectorsPath.isEmpty) {
    test('QA_VECTORS is set', () {
      fail('pass --dart-define=QA_VECTORS=<path> (run via docs/ssot/conformance/run_dart.sh)');
    });
    return;
  }

  final doc = jsonDecode(File(vectorsPath).readAsStringSync()) as Map<String, dynamic>;
  final vectors = (doc['vectors'] as List).cast<Map<String, dynamic>>();
  final tolMl = ((doc['toleranceMl'] as num?) ?? 0.001).toDouble();

  // =========================================================================
  // Layer 1 — golden vectors
  // =========================================================================
  group('pre-workout hydration conformance (${vectors.length} vectors)', () {
    for (final v in vectors) {
      final id = v['id'] as String;
      final status = (v['status'] as String?) ?? 'ratified';
      final i = v['inputs'] as Map<String, dynamic>;
      final e = v['expected'] as Map<String, dynamic>;
      final why = v['why'];

      test('[$status] $id', () {
        final out = OfflineMacroCalculator.calculatePreWorkoutHydration(
          bodyWeightKg: (i['bodyWeightKg'] as num).toDouble(),
          workoutDurationMin: (i['workoutDurationMin'] as num).toDouble(),
          timeBeforeWorkoutMin: (i['timeBeforeWorkoutMin'] as num).toDouble(),
          tempC: (i['tempC'] as num?)?.toDouble(),
          hydrationCheck: parseCheck(i['hydrationCheck']),
        );

        // NULL-AWARE numeric comparison. `null` (no statement is made) and `0.0`
        // (nothing is required) are DIFFERENT answers — conflating them is the
        // exact failure mode the gate path has to be protected against.
        void chkFluid(String key, double? actual) {
          if (!e.containsKey(key)) return;
          final expected = e[key];
          if (expected == null) {
            expect(actual, isNull,
                reason: '$id: $key must be null, not $actual (gate path states nothing). $why');
          } else {
            expect(actual, isNotNull, reason: '$id: $key must be $expected, got null. $why');
            expect(actual!, closeTo((expected as num).toDouble(), tolMl),
                reason: '$id: $key (tol $tolMl ml). $why');
          }
        }

        void chkString(String key, String? actual) {
          if (!e.containsKey(key)) return;
          expect(actual, e[key], reason: '$id: $key. $why');
        }

        expect(out.gateTriggered, e['gateTriggered'], reason: '$id: gateTriggered. $why');

        chkFluid('fluidMl', out.fluidMl);
        chkFluid('fluidLowMl', out.fluidLowMl);
        chkFluid('fluidHighMl', out.fluidHighMl);

        chkString('regime', out.regime);
        chkString('targetBasis', out.targetBasis);
        chkString('hydrationCheckUsed', out.hydrationCheckUsed);
        // On the gate path the vectors omit hydrationCheckUsed; the contract says null.
        if (!e.containsKey('hydrationCheckUsed') && e['gateTriggered'] == true) {
          expect(out.hydrationCheckUsed, isNull,
              reason: '$id: hydrationCheckUsed must be null on the gate path');
        }

        // Invariant 11 — gate path: empty tiers, never a zero-valued tier.
        // Invariant 2 — otherwise tiers sum to the plan total.
        expect(out.tiers, isNotNull, reason: '$id: tiers is never null');
        if (out.gateTriggered) {
          expect(out.tiers, isEmpty, reason: '$id: gate path emits an empty tiers array (inv 11)');
        } else {
          final sum = out.tiers.fold<double>(0, (a, t) => a + t.fluidMl);
          expect(sum, closeTo(out.fluidMl!, tolMl),
              reason: '$id: sum(tiers[].fluidMl)=$sum must equal fluidMl=${out.fluidMl} (inv 2)');
          for (final t in out.tiers) {
            expect(const <String>{'meal', 'snack', 'top_off'}, contains(t.tier),
                reason: '$id: unexpected tier name "${t.tier}"');
          }
        }
      });
    }
  });

  // =========================================================================
  // Layer 2 — spec invariants as property tests
  // =========================================================================
  group('pre-workout hydration invariants (property, grid 0..240 x BW 30..160)', () {
    test('inv 1 — 0 <= fluidLowMl <= fluidMl <= fluidHighMl wherever non-null', () {
      for (final bw in kBodyWeights) {
        for (final t in kLeadGrid) {
          for (final c in kAllChecks) {
            final o = calc(bw, t, check: c);
            final where = 'BW=$bw t=$t check=$c';
            expect(o.gateTriggered, isFalse, reason: '$where: 90 min @ 22 C must not gate');
            expect(o.fluidLowMl, isNotNull, reason: '$where: low');
            expect(o.fluidMl, isNotNull, reason: '$where: plan');
            expect(o.fluidHighMl, isNotNull, reason: '$where: high');
            expect(o.fluidLowMl! >= 0, isTrue, reason: '$where: low ${o.fluidLowMl} < 0');
            expect(o.fluidLowMl! <= o.fluidMl! + 1e-9, isTrue,
                reason: '$where: low ${o.fluidLowMl} > plan ${o.fluidMl}');
            expect(o.fluidMl! <= o.fluidHighMl! + 1e-9, isTrue,
                reason: '$where: plan ${o.fluidMl} > high ${o.fluidHighMl}');
          }
        }
      }
    });

    test('inv 2 — fluidMl == sum(tiers[].fluidMl) everywhere', () {
      for (final bw in kBodyWeights) {
        for (final t in kLeadGrid) {
          for (final c in kAllChecks) {
            final o = calc(bw, t, check: c);
            final sum = o.tiers.fold<double>(0, (a, x) => a + x.fluidMl);
            expect(sum, closeTo(o.fluidMl!, 1e-9),
                reason: 'BW=$bw t=$t check=$c: tiers sum $sum != fluidMl ${o.fluidMl}');
          }
        }
      }
    });

    test('inv 3 — fluidMl is non-decreasing in t on BOTH the pale and dark paths', () {
      for (final bw in kBodyWeights) {
        for (final c in <HydrationCheck>[HydrationCheck.pale, HydrationCheck.dark]) {
          var prev = double.negativeInfinity;
          for (final t in kLeadGrid) {
            final cur = calc(bw, t, check: c).fluidMl!;
            expect(cur >= prev - 1e-9, isTrue,
                reason: 'BW=$bw check=$c: fluidMl dropped from $prev to $cur at t=$t');
            prev = cur;
          }
        }
      }
    });

    test('inv 4 — pale-path continuity at t=120 and t=30 (|delta| < 1e-6 * BW)', () {
      const eps = 1e-5; // small enough that the linear taper's own slope stays under 1e-6*BW
      for (final bw in kBodyWeights) {
        for (final b in <double>[kTRef, 30.0]) {
          final above = calc(bw, b + eps, check: HydrationCheck.pale).fluidMl!;
          final below = calc(bw, b - eps, check: HydrationCheck.pale).fluidMl!;
          expect((above - below).abs() < 1e-6 * bw, isTrue,
              reason: 'BW=$bw: pale path is discontinuous at t=$b '
                  '($below -> $above, delta ${(above - below).abs()})');
        }
      }
    });

    test('inv 5 — the dark-path step at T_REF is intentional: plan(120+) - plan(120-) == 4*BW', () {
      const eps = 1e-5;
      for (final bw in kBodyWeights) {
        final above = calc(bw, kTRef + eps, check: HydrationCheck.dark).fluidMl!;
        final below = calc(bw, kTRef - eps, check: HydrationCheck.dark).fluidMl!;
        expect(above - below, closeTo(kTopUpMlKg * bw, 1e-5 * bw),
            reason: 'BW=$bw: dark step at T_REF is ${above - below}, expected ${kTopUpMlKg * bw}');
      }
    });

    test('inv 8 — fluidHighMl == 12*BW for t >= 120; fluidHighMl <= 10*BW for t < 120', () {
      for (final bw in kBodyWeights) {
        for (final t in kLeadGrid) {
          for (final c in kAllChecks) {
            final high = calc(bw, t, check: c).fluidHighMl!;
            if (t >= kTRef) {
              expect(high, closeTo(kPlanCapMlKg * bw, 1e-9),
                  reason: 'BW=$bw t=$t check=$c: high $high != 12*BW ${kPlanCapMlKg * bw}');
            } else {
              expect(high <= 10.0 * bw + 1e-9, isTrue,
                  reason: 'BW=$bw t=$t check=$c: high $high exceeds 10*BW ${10 * bw}');
            }
          }
        }
      }
    });

    test('inv 8a — the plan cap has teeth: fluidMl <= 12*BW, and dark high == 12*BW', () {
      for (final bw in kBodyWeights) {
        for (final t in kLeadGrid) {
          for (final c in kAllChecks) {
            final o = calc(bw, t, check: c);
            expect(o.fluidMl! <= kPlanCapMlKg * bw + 1e-9, isTrue,
                reason: 'BW=$bw t=$t check=$c: plan ${o.fluidMl} exceeds PLAN_CAP ${kPlanCapMlKg * bw}. '
                    'Raising TOPUP_ML_KG past 4.5 must fail HERE, not silently exceed ACSM 2007.');
          }
          if (t >= kTRef) {
            // min(7.5+5, 12)*BW must select the cap, not the sum.
            final darkHigh = calc(bw, t, check: HydrationCheck.dark).fluidHighMl!;
            expect(darkHigh, closeTo(kPlanCapMlKg * bw, 1e-9),
                reason: 'BW=$bw t=$t: dark high $darkHigh != min(12.5,12)*BW');
            expect(darkHigh < (7.5 + kTopUpHighMlKg) * bw - 1e-9, isTrue,
                reason: 'BW=$bw t=$t: the cap did not bind — high equals the uncapped sum');
          }
        }
      }
    });

    test('inv 8b — above T_REF the band is byte-identical across all three hydrationCheck values',
        () {
      for (final bw in kBodyWeights) {
        for (final t in kLeadGrid.where((t) => t >= kTRef)) {
          final pale = calc(bw, t, check: HydrationCheck.pale);
          final dark = calc(bw, t, check: HydrationCheck.dark);
          final unk = calc(bw, t, check: HydrationCheck.unknown);
          for (final o in <PreWorkoutHydrationResult>[dark, unk]) {
            expect(o.fluidLowMl, pale.fluidLowMl,
                reason: 'BW=$bw t=$t: fluidLowMl moved with hydrationCheck (inv 8b)');
            expect(o.fluidHighMl, pale.fluidHighMl,
                reason: 'BW=$bw t=$t: fluidHighMl moved with hydrationCheck (inv 8b)');
            expect(o.regime, pale.regime, reason: 'BW=$bw t=$t: regime moved with hydrationCheck');
            expect(o.targetBasis, pale.targetBasis,
                reason: 'BW=$bw t=$t: targetBasis moved with hydrationCheck');
          }
          // ...and the target DOES differ on dark, else the check is a no-op.
          expect(dark.fluidMl! - pale.fluidMl!, closeTo(kTopUpMlKg * bw, 1e-9),
              reason: 'BW=$bw t=$t: dark must add exactly 4 ml/kg to the target');
          // `unknown` normalises to `pale` inside this branch, and echoes the NORMALISED value.
          expect(unk.fluidMl, pale.fluidMl,
              reason: 'BW=$bw t=$t: unknown must be treated as pale above T_REF');
          expect(unk.hydrationCheckUsed, 'pale',
              reason: 'BW=$bw t=$t: hydrationCheckUsed echoes the NORMALISED value above T_REF');
          expect(pale.hydrationCheckUsed, 'pale');
          expect(dark.hydrationCheckUsed, 'dark');
        }
      }
    });

    test('inv 8b (below T_REF) — all three checks produce identical output, and the RAW echo', () {
      for (final bw in kBodyWeights) {
        for (final t in kLeadGrid.where((t) => t < kTRef)) {
          final pale = calc(bw, t, check: HydrationCheck.pale);
          final dark = calc(bw, t, check: HydrationCheck.dark);
          final unk = calc(bw, t, check: HydrationCheck.unknown);
          for (final o in <PreWorkoutHydrationResult>[dark, unk]) {
            expect(o.fluidMl, pale.fluidMl, reason: 'BW=$bw t=$t: check changed the sub-2h target');
            expect(o.fluidLowMl, pale.fluidLowMl, reason: 'BW=$bw t=$t: low');
            expect(o.fluidHighMl, pale.fluidHighMl, reason: 'BW=$bw t=$t: high');
            expect(o.regime, pale.regime, reason: 'BW=$bw t=$t: regime');
            expect(o.targetBasis, pale.targetBasis, reason: 'BW=$bw t=$t: targetBasis');
            expect(o.tiers.length, pale.tiers.length, reason: 'BW=$bw t=$t: tier count');
          }
          // Below T_REF the echo is the RAW value — no normalisation.
          expect(pale.hydrationCheckUsed, 'pale', reason: 'BW=$bw t=$t: raw echo');
          expect(dark.hydrationCheckUsed, 'dark', reason: 'BW=$bw t=$t: raw echo');
          expect(unk.hydrationCheckUsed, 'unknown',
              reason: 'BW=$bw t=$t: below T_REF `unknown` is echoed RAW, never normalised to pale');
          // fluidLowMl is 0.0 here — zero, NOT null.
          expect(pale.fluidLowMl, isNotNull,
              reason: 'BW=$bw t=$t: fluidLowMl below T_REF is 0.0, not null');
          expect(pale.fluidLowMl, closeTo(0.0, 1e-12), reason: 'BW=$bw t=$t: fluidLowMl == 0');
        }
      }
    });

    test('inv 9 — clearance containment: the clearance-bound region sits inside the top-off tier',
        () {
      // Pure-spec arithmetic: ln(10*BW / R_CEILING) / K <= 30 for all BW <= 198.
      for (var bw = 30.0; bw <= 198.0; bw += 1.0) {
        final crossover = math.log(10.0 * bw / kRCeiling) / kK;
        expect(crossover <= 30.0 + 1e-9, isTrue,
            reason: 'BW=$bw: clearance crosses at t=$crossover, outside the top-off tier (<30)');
      }
      // ...and the engine agrees: no grid point at or above t=30 may be clearance_bound.
      for (final bw in kBodyWeights) {
        for (final t in kLeadGrid.where((t) => t >= 30)) {
          expect(calc(bw, t).regime, isNot('clearance_bound'),
              reason: 'BW=$bw t=$t: clearance bound outside the top-off tier');
        }
      }
    });

    test('inv 11 — gate path is null/null/null with an empty tiers array, never 0', () {
      for (final bw in kBodyWeights) {
        for (final t in kLeadGrid) {
          for (final c in kAllChecks) {
            // gate: workoutDurationMin < 60 AND tempC < 30. tempC null defaults to 22.
            for (final temp in <double?>[22.0, null, 29.999]) {
              final o = calc(bw, t, check: c, durationMin: 45, tempC: temp);
              final where = 'BW=$bw t=$t check=$c temp=$temp';
              expect(o.gateTriggered, isTrue, reason: '$where: gate must fire');
              expect(o.fluidMl, isNull, reason: '$where: fluidMl must be null, not 0');
              expect(o.fluidLowMl, isNull, reason: '$where: fluidLowMl must be null, not 0');
              expect(o.fluidHighMl, isNull, reason: '$where: fluidHighMl must be null, not 0');
              expect(o.tiers, isEmpty, reason: '$where: tiers must be empty');
              expect(o.regime, 'gated', reason: '$where: regime');
              expect(o.targetBasis, 'none', reason: '$where: targetBasis');
              expect(o.hydrationCheckUsed, isNull, reason: '$where: hydrationCheckUsed');
            }
            // ...and it must NOT fire once either leg of the AND is false.
            expect(calc(bw, t, check: c, durationMin: 60, tempC: 22).gateTriggered, isFalse,
                reason: 'BW=$bw t=$t: duration 60 is inclusive — must not gate');
            expect(calc(bw, t, check: c, durationMin: 45, tempC: 30).gateTriggered, isFalse,
                reason: 'BW=$bw t=$t: 30 C is inclusive — must not gate');
          }
        }
      }
    });
  });

  // =========================================================================
  // Cross-spec pin (hydration inv 10 / carbs inv 10)
  // =========================================================================
  group('cross-spec pin', () {
    test('T_REF == pre-workout-carbs.TIER_MEAL_MIN (both 120.0)', () {
      // Asserted BEHAVIOURALLY so the pin holds without either spec's constants
      // being exported: T_REF is the lowest grid lead time at which hydration is
      // `cited`; TIER_MEAL_MIN is the lowest at which carbs emit a `meal` tier.
      final tRefObserved = kLeadGrid.firstWhere(
        (t) => calc(65, t).regime == 'cited',
        orElse: () => double.nan,
      );
      final mealMinObserved = kLeadGrid.firstWhere(
        (t) => OfflineMacroCalculator.calculatePreWorkoutCarbs(
              bodyWeightKg: 65,
              timeBeforeWorkoutMin: t,
              workoutDurationMin: 90,
            ).tiers.any((x) => x.tier == 'meal'),
        orElse: () => double.nan,
      );
      expect(tRefObserved, kTRef, reason: 'hydration T_REF drifted off 120.0');
      expect(mealMinObserved, kTRef,
          reason: 'carbs TIER_MEAL_MIN ($mealMinObserved) diverged from hydration T_REF '
              '($tRefObserved). These are pinned equal by assertion, NOT shared code — '
              'if one moved deliberately, move this pin deliberately too.');
    });
  });
}
