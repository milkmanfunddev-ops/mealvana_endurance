// ignore_for_file: avoid_relative_lib_imports
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/offline_macro_calculator.dart';

/// Calculator-level conformance tests for **pre-workout hydration v6**.
///
/// SSOT: `docs/ssot/spec/fueling/pre-workout-hydration.md` (v6, ratified
/// 2026-08-04) and its ratified vector set
/// `docs/ssot/vectors/fueling/pre-workout-hydration.json`.
///
/// The engine never rounds — every fluid figure below is an exact double and is
/// compared with an absolute tolerance of 1e-3 ml, the tolerance the vector file
/// itself declares. Rounding is a display concern and is tested elsewhere.
///
/// Sodium lives in `offline_macro_calculator_pre_workout_sodium_test.dart`.
/// Carbohydrate lives in `offline_macro_calculator_pre_workout_carbs_test.dart`.

/// Absolute tolerance for every fluid comparison (ml). From the vector file.
const double _tolMl = 1e-3;

/// A nudge small enough that the taper moves by far less than [_tolMl] across
/// it, so it isolates a *branch* change rather than a value change.
const double _eps = 1e-6;

/// The ratified input domain: 0..240 min in 15-minute steps (17 points).
const List<double> _tGrid = <double>[
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

/// Body weights swept by the property tests, 30..160 kg.
const List<double> _bwGrid = <double>[
  30,
  40,
  50,
  60,
  70,
  80,
  90,
  100,
  110,
  120,
  130,
  140,
  150,
  160,
];

/// A duration that never trips the gate, so the sweeps exercise the real math.
const double _unGatedDur = 90.0;

PreWorkoutHydrationResult _hyd(
  double bw,
  double t, {
  double dur = _unGatedDur,
  double? tempC = 22.0,
  HydrationCheck check = HydrationCheck.unknown,
}) {
  return OfflineMacroCalculator.calculatePreWorkoutHydration(
    bodyWeightKg: bw,
    workoutDurationMin: dur,
    timeBeforeWorkoutMin: t,
    tempC: tempC,
    hydrationCheck: check,
  );
}

/// The sub-`T_REF` taper, re-derived here rather than read off the engine, so a
/// change to the engine's `f` cannot silently agree with itself.
double _taper(double bw, double t) {
  final a0 = math.min(250.0, 7.5 * bw);
  return a0 + (7.5 * bw - a0) * math.min(t, 120.0) / 120.0;
}

double _sumTiers(PreWorkoutHydrationResult r) =>
    r.tiers.fold<double>(0.0, (sum, tier) => sum + tier.fluidMl);

void _expectMl(double? actual, double? expected, {String? reason}) {
  if (expected == null) {
    expect(actual, isNull, reason: reason);
  } else {
    expect(actual, isNotNull, reason: reason);
    expect(actual, closeTo(expected, _tolMl), reason: reason);
  }
}

/// One ratified vector from `pre-workout-hydration.json`.
class _HVec {
  const _HVec({
    required this.id,
    required this.bw,
    required this.dur,
    required this.t,
    required this.tempC,
    required this.check,
    required this.gated,
    required this.fluid,
    required this.low,
    required this.high,
    required this.regime,
    required this.basis,
    required this.checkUsed,
  });

  final String id;
  final double bw;
  final double dur;
  final double t;
  final double? tempC;
  final HydrationCheck check;
  final bool gated;
  final double? fluid;
  final double? low;
  final double? high;
  final String regime;
  final String basis;
  final String? checkUsed;
}

/// Generated verbatim from `docs/ssot/vectors/fueling/pre-workout-hydration.json`.
const List<_HVec> _hydrationVectors = <_HVec>[
  _HVec(
    id: 'cited-180-65-pale',
    bw: 65.0,
    dur: 90.0,
    t: 180.0,
    tempC: 22.0,
    check: HydrationCheck.pale,
    gated: false,
    fluid: 487.5,
    low: 325.0,
    high: 780.0,
    regime: 'cited',
    basis: 'evidenced_band',
    checkUsed: 'pale',
  ),
  _HVec(
    id: 'cited-180-65-dark',
    bw: 65.0,
    dur: 90.0,
    t: 180.0,
    tempC: 22.0,
    check: HydrationCheck.dark,
    gated: false,
    fluid: 747.5,
    low: 325.0,
    high: 780.0,
    regime: 'cited',
    basis: 'evidenced_band',
    checkUsed: 'dark',
  ),
  _HVec(
    id: 'cited-180-65-unknown',
    bw: 65.0,
    dur: 90.0,
    t: 180.0,
    tempC: 22.0,
    check: HydrationCheck.unknown,
    gated: false,
    fluid: 487.5,
    low: 325.0,
    high: 780.0,
    regime: 'cited',
    basis: 'evidenced_band',
    checkUsed: 'pale',
  ),
  _HVec(
    id: 'cited-boundary-120-65-pale',
    bw: 65.0,
    dur: 90.0,
    t: 120.0,
    tempC: 22.0,
    check: HydrationCheck.pale,
    gated: false,
    fluid: 487.5,
    low: 325.0,
    high: 780.0,
    regime: 'cited',
    basis: 'evidenced_band',
    checkUsed: 'pale',
  ),
  _HVec(
    id: 'cited-boundary-120-65-dark',
    bw: 65.0,
    dur: 90.0,
    t: 120.0,
    tempC: 22.0,
    check: HydrationCheck.dark,
    gated: false,
    fluid: 747.5,
    low: 325.0,
    high: 780.0,
    regime: 'cited',
    basis: 'evidenced_band',
    checkUsed: 'dark',
  ),
  _HVec(
    id: 'cited-135-65-pale',
    bw: 65.0,
    dur: 90.0,
    t: 135.0,
    tempC: 22.0,
    check: HydrationCheck.pale,
    gated: false,
    fluid: 487.5,
    low: 325.0,
    high: 780.0,
    regime: 'cited',
    basis: 'evidenced_band',
    checkUsed: 'pale',
  ),
  _HVec(
    id: 'cited-plan-cap-50-dark',
    bw: 50.0,
    dur: 90.0,
    t: 180.0,
    tempC: 22.0,
    check: HydrationCheck.dark,
    gated: false,
    fluid: 575.0,
    low: 250.0,
    high: 600.0,
    regime: 'cited',
    basis: 'evidenced_band',
    checkUsed: 'dark',
  ),
  _HVec(
    id: 'cited-plan-cap-100-dark',
    bw: 100.0,
    dur: 120.0,
    t: 240.0,
    tempC: 25.0,
    check: HydrationCheck.dark,
    gated: false,
    fluid: 1150.0,
    low: 500.0,
    high: 1200.0,
    regime: 'cited',
    basis: 'evidenced_band',
    checkUsed: 'dark',
  ),
  _HVec(
    id: 'cited-90kg-pale',
    bw: 90.0,
    dur: 120.0,
    t: 240.0,
    tempC: 25.0,
    check: HydrationCheck.pale,
    gated: false,
    fluid: 675.0,
    low: 450.0,
    high: 1080.0,
    regime: 'cited',
    basis: 'evidenced_band',
    checkUsed: 'pale',
  ),
  _HVec(
    id: 'cited-a0guard-30-pale',
    bw: 30.0,
    dur: 90.0,
    t: 180.0,
    tempC: 22.0,
    check: HydrationCheck.pale,
    gated: false,
    fluid: 225.0,
    low: 150.0,
    high: 360.0,
    regime: 'cited',
    basis: 'evidenced_band',
    checkUsed: 'pale',
  ),
  _HVec(
    id: 'taper-105-65',
    bw: 65.0,
    dur: 90.0,
    t: 105.0,
    tempC: 22.0,
    check: HydrationCheck.unknown,
    gated: false,
    fluid: 457.8125,
    low: 0.0,
    high: 650.0,
    regime: 'extrapolated',
    basis: 'design_choice',
    checkUsed: 'unknown',
  ),
  _HVec(
    id: 'taper-90-65',
    bw: 65.0,
    dur: 90.0,
    t: 90.0,
    tempC: 22.0,
    check: HydrationCheck.unknown,
    gated: false,
    fluid: 428.125,
    low: 0.0,
    high: 650.0,
    regime: 'extrapolated',
    basis: 'design_choice',
    checkUsed: 'unknown',
  ),
  _HVec(
    id: 'taper-boundary-30-65',
    bw: 65.0,
    dur: 90.0,
    t: 30.0,
    tempC: 22.0,
    check: HydrationCheck.unknown,
    gated: false,
    fluid: 309.375,
    low: 0.0,
    high: 650.0,
    regime: 'extrapolated',
    basis: 'design_choice',
    checkUsed: 'unknown',
  ),
  _HVec(
    id: 'topoff-boundary-29-65',
    bw: 65.0,
    dur: 90.0,
    t: 29.0,
    tempC: 22.0,
    check: HydrationCheck.unknown,
    gated: false,
    fluid: 307.3958,
    low: 0.0,
    high: 650.0,
    regime: 'extrapolated',
    basis: 'design_choice',
    checkUsed: 'unknown',
  ),
  _HVec(
    id: 'topoff-15-65',
    bw: 65.0,
    dur: 90.0,
    t: 15.0,
    tempC: 22.0,
    check: HydrationCheck.unknown,
    gated: false,
    fluid: 279.6875,
    low: 0.0,
    high: 650.0,
    regime: 'extrapolated',
    basis: 'design_choice',
    checkUsed: 'unknown',
  ),
  _HVec(
    id: 'topoff-anchor-0-65',
    bw: 65.0,
    dur: 90.0,
    t: 0.0,
    tempC: 22.0,
    check: HydrationCheck.unknown,
    gated: false,
    fluid: 250.0,
    low: 0.0,
    high: 400.0,
    regime: 'clearance_bound',
    basis: 'design_choice',
    checkUsed: 'unknown',
  ),
  _HVec(
    id: 'clearance-100-15',
    bw: 100.0,
    dur: 90.0,
    t: 15.0,
    tempC: 22.0,
    check: HydrationCheck.unknown,
    gated: false,
    fluid: 312.5,
    low: 0.0,
    high: 890.2164,
    regime: 'clearance_bound',
    basis: 'design_choice',
    checkUsed: 'unknown',
  ),
  _HVec(
    id: 'gate-fires-short-mild',
    bw: 65.0,
    dur: 45.0,
    t: 180.0,
    tempC: 22.0,
    check: HydrationCheck.pale,
    gated: true,
    fluid: null,
    low: null,
    high: null,
    regime: 'gated',
    basis: 'none',
    checkUsed: null,
  ),
  _HVec(
    id: 'gate-not-fired-hot',
    bw: 65.0,
    dur: 45.0,
    t: 180.0,
    tempC: 32.0,
    check: HydrationCheck.pale,
    gated: false,
    fluid: 487.5,
    low: 325.0,
    high: 780.0,
    regime: 'cited',
    basis: 'evidenced_band',
    checkUsed: 'pale',
  ),
  _HVec(
    id: 'gate-not-fired-dur60',
    bw: 65.0,
    dur: 60.0,
    t: 180.0,
    tempC: 22.0,
    check: HydrationCheck.pale,
    gated: false,
    fluid: 487.5,
    low: 325.0,
    high: 780.0,
    regime: 'cited',
    basis: 'evidenced_band',
    checkUsed: 'pale',
  ),
  _HVec(
    id: 'gate-tempnull-default',
    bw: 65.0,
    dur: 45.0,
    t: 180.0,
    tempC: null,
    check: HydrationCheck.pale,
    gated: true,
    fluid: null,
    low: null,
    high: null,
    regime: 'gated',
    basis: 'none',
    checkUsed: null,
  ),
];

void main() {
  // ===========================================================================
  // The 21 ratified vectors
  // ===========================================================================

  group('pre-workout-hydration.json — all ratified vectors', () {
    test('the whole ratified set is present (21 vectors)', () {
      expect(_hydrationVectors.length, 21);
    });

    for (final v in _hydrationVectors) {
      test('vector ${v.id}', () {
        final r = OfflineMacroCalculator.calculatePreWorkoutHydration(
          bodyWeightKg: v.bw,
          workoutDurationMin: v.dur,
          timeBeforeWorkoutMin: v.t,
          tempC: v.tempC,
          hydrationCheck: v.check,
        );

        expect(r.gateTriggered, v.gated, reason: '${v.id} gateTriggered');
        _expectMl(r.fluidMl, v.fluid, reason: '${v.id} fluidMl');
        _expectMl(r.fluidLowMl, v.low, reason: '${v.id} fluidLowMl');
        _expectMl(r.fluidHighMl, v.high, reason: '${v.id} fluidHighMl');
        expect(r.regime, v.regime, reason: '${v.id} regime');
        expect(r.targetBasis, v.basis, reason: '${v.id} targetBasis');
        expect(
          r.hydrationCheckUsed,
          v.checkUsed,
          reason: '${v.id} hydrationCheckUsed',
        );

        // Sodium v3 — null on every path, in every vector. 0 is a failure.
        expect(r.sodiumMg, isNull, reason: '${v.id} sodiumMg');
        expect(r.sodiumLowMg, isNull, reason: '${v.id} sodiumLowMg');
        expect(r.sodiumHighMg, isNull, reason: '${v.id} sodiumHighMg');

        if (v.gated) {
          expect(r.tiers, isEmpty, reason: '${v.id} gate path has no tiers');
        } else {
          expect(r.tiers, isNotEmpty, reason: '${v.id} tiers');
          expect(
            _sumTiers(r),
            closeTo(v.fluid!, _tolMl),
            reason: '${v.id} invariant 2: fluidMl == sum(tiers)',
          );
        }
      });
    }
  });

  // ===========================================================================
  // The gate — `dur < 60 AND temp < 30`, strict `<`, joined by AND
  // ===========================================================================

  group('gate', () {
    test('fires for a short, mild session and returns nulls, not zeros', () {
      final r = _hyd(65, 180, dur: 45, tempC: 22);
      expect(r.gateTriggered, isTrue);
      expect(r.fluidMl, isNull);
      expect(r.fluidLowMl, isNull);
      expect(r.fluidHighMl, isNull);
      expect(r.tiers, isEmpty);
      expect(r.regime, 'gated');
      expect(r.targetBasis, 'none');
      expect(r.hydrationCheckUsed, isNull);
    });

    test('does NOT fire at dur == 60 (threshold is strict <)', () {
      final r = _hyd(65, 180, dur: 60, tempC: 22);
      expect(r.gateTriggered, isFalse);
      expect(r.regime, 'cited');
      _expectMl(r.fluidMl, 487.5);
    });

    test('does NOT fire at temp == 30 (threshold is strict <)', () {
      final r = _hyd(65, 180, dur: 45, tempC: 30);
      expect(r.gateTriggered, isFalse);
      expect(r.regime, 'cited');
      _expectMl(r.fluidMl, 487.5);
    });

    test('does NOT fire at temp == 32 (above the threshold)', () {
      final r = _hyd(65, 180, dur: 45, tempC: 32);
      expect(r.gateTriggered, isFalse);
      _expectMl(r.fluidMl, 487.5);
    });

    test('fires via the tempC-null default of 22 degC', () {
      final r = _hyd(65, 180, dur: 45, tempC: null);
      expect(r.gateTriggered, isTrue);
      expect(r.regime, 'gated');
      // Same inputs, but a null temp defaulted to 22 -> identical to the
      // explicit-22 call. The default is applied BEFORE the gate.
      final explicit = _hyd(65, 180, dur: 45, tempC: 22);
      expect(r.gateTriggered, explicit.gateTriggered);
    });

    test('the two conditions are ANDed, not ORed', () {
      // Long and cool: no gate. Short and hot: no gate. Only short AND cool.
      expect(_hyd(65, 180, dur: 180, tempC: 5).gateTriggered, isFalse);
      expect(_hyd(65, 180, dur: 20, tempC: 35).gateTriggered, isFalse);
      expect(_hyd(65, 180, dur: 20, tempC: 5).gateTriggered, isTrue);
    });

    test('the gate ignores lead time, body weight and hydrationCheck', () {
      for (final bw in _bwGrid) {
        for (final t in _tGrid) {
          for (final check in HydrationCheck.values) {
            final r = _hyd(bw, t, dur: 30, tempC: 10, check: check);
            expect(
              r.gateTriggered,
              isTrue,
              reason: 'bw=$bw t=$t check=${check.wireValue}',
            );
            expect(r.fluidMl, isNull);
            expect(r.tiers, isEmpty);
          }
        }
      }
    });
  });

  // ===========================================================================
  // Branch boundaries — inclusive at the bottom
  // ===========================================================================

  group('branch boundaries', () {
    test('t == 120 takes the cited branch (inclusive at the bottom)', () {
      final r = _hyd(65, 120, check: HydrationCheck.pale);
      expect(r.regime, 'cited');
      expect(r.targetBasis, 'evidenced_band');
      _expectMl(r.fluidMl, 487.5);
      _expectMl(r.fluidLowMl, 325);
      _expectMl(r.fluidHighMl, 780);
      expect(r.tiers.map((e) => e.tier), <String>['meal', 'snack', 'top_off']);
    });

    test('just below 120 is the extrapolated branch', () {
      final r = _hyd(65, 120 - _eps, check: HydrationCheck.pale);
      expect(r.regime, 'extrapolated');
      expect(r.targetBasis, 'design_choice');
      _expectMl(r.fluidLowMl, 0);
      _expectMl(r.fluidHighMl, 650);
      _expectMl(r.fluidMl, _taper(65, 120 - _eps));
      expect(r.tiers.map((e) => e.tier), <String>['snack', 'top_off']);
    });

    test('t == 30 is inclusive of the snack window', () {
      final r = _hyd(65, 30);
      _expectMl(r.fluidMl, 309.375);
      expect(r.tiers.map((e) => e.tier), <String>['snack', 'top_off']);
      _expectMl(r.tiers[0].fluidMl, 309.375);
      _expectMl(r.tiers[1].fluidMl, 0);
    });

    test('just below 30 is top-off only', () {
      final r = _hyd(65, 30 - _eps);
      expect(r.tiers.map((e) => e.tier), <String>['top_off']);
      _expectMl(r.tiers.single.fluidMl, _taper(65, 30 - _eps));
    });

    test('t > 240 returns exactly what t == 240 returns', () {
      for (final check in HydrationCheck.values) {
        final at240 = _hyd(65, 240, check: check);
        for (final t in <double>[241, 300, 480, 100000]) {
          final beyond = _hyd(65, t, check: check);
          expect(beyond.fluidMl, at240.fluidMl, reason: 't=$t');
          expect(beyond.fluidLowMl, at240.fluidLowMl, reason: 't=$t');
          expect(beyond.fluidHighMl, at240.fluidHighMl, reason: 't=$t');
          expect(beyond.regime, at240.regime, reason: 't=$t');
          expect(beyond.hydrationCheckUsed, at240.hydrationCheckUsed);
        }
      }
    });

    test('negative lead time clamps to 0', () {
      for (final bw in <double>[30, 65, 100]) {
        final atZero = _hyd(bw, 0);
        for (final t in <double>[-0.5, -15, -240]) {
          final negative = _hyd(bw, t);
          expect(negative.fluidMl, atZero.fluidMl, reason: 'bw=$bw t=$t');
          expect(
            negative.fluidHighMl,
            atZero.fluidHighMl,
            reason: 'bw=$bw t=$t',
          );
          expect(negative.regime, atZero.regime, reason: 'bw=$bw t=$t');
          expect(negative.tiers.length, atZero.tiers.length);
        }
      }
    });
  });

  // ===========================================================================
  // The A0 guard and the clearance ceiling
  // ===========================================================================

  group('A0 guard and clearance ceiling', () {
    test(
      'A0 binds below 33.3 kg: the anchor never exceeds the cited target',
      () {
        // 7.5 * 30 = 225 < 250, so A0 = 225 and the taper is flat at 225.
        final r = _hyd(30, 0);
        _expectMl(r.fluidMl, 225);
        _expectMl(r.fluidHighMl, 300); // min(10*30, 400)
        expect(r.regime, 'extrapolated');
        // Flat: the same value at every sub-T_REF lead time.
        for (final t in _tGrid.where((t) => t < 120)) {
          _expectMl(_hyd(30, t).fluidMl, 225, reason: 't=$t');
        }
      },
    );

    test('A0 does not bind at 34 kg (7.5 kg/ml exceeds the 250 ml anchor)', () {
      _expectMl(_hyd(34, 0).fluidMl, 250);
      expect(_hyd(34, 60).fluidMl! > 250, isTrue);
    });

    test('BW = 40: the clearance ceiling never binds', () {
      for (final t in _tGrid) {
        final r = _hyd(40, t);
        if (t < 120) {
          expect(r.regime, 'extrapolated', reason: 't=$t');
          _expectMl(
            r.fluidHighMl,
            400,
            reason: 't=$t',
          ); // 10 * 40, not clearance
        } else {
          expect(r.regime, 'cited', reason: 't=$t');
        }
      }
    });

    test(
      'BW > 100: clearance binds near the start line and lets go by t=30',
      () {
        final atStart = _hyd(110, 0);
        expect(atStart.regime, 'clearance_bound');
        _expectMl(atStart.fluidHighMl, 400); // R_CEILING * exp(0)
        expect(_hyd(110, 15).regime, 'clearance_bound');
        // Invariant 9: the clearance-bound region is strictly inside the top-off
        // tier, so by t = 30 it has released even at 160 kg.
        expect(_hyd(110, 30).regime, 'extrapolated');
        expect(_hyd(160, 30).regime, 'extrapolated');
      },
    );
  });

  // ===========================================================================
  // Tier shape
  // ===========================================================================

  group('tiers', () {
    test('t >= 120 emits meal/snack/top_off, furthest-out first', () {
      final pale = _hyd(65, 180, check: HydrationCheck.pale);
      expect(pale.tiers.map((e) => e.tier), <String>[
        'meal',
        'snack',
        'top_off',
      ]);
      _expectMl(pale.tiers[0].fluidMl, 487.5);
      _expectMl(pale.tiers[1].fluidMl, 0);
      _expectMl(pale.tiers[2].fluidMl, 0);

      final dark = _hyd(65, 180, check: HydrationCheck.dark);
      _expectMl(dark.tiers[0].fluidMl, 487.5);
      _expectMl(
        dark.tiers[1].fluidMl,
        260,
      ); // 4 ml/kg lands in the snack window
      _expectMl(dark.tiers[2].fluidMl, 0);
    });

    test(
      '30 <= t < 120 emits snack/top_off with all the fluid in the snack',
      () {
        final r = _hyd(65, 90);
        expect(r.tiers.map((e) => e.tier), <String>['snack', 'top_off']);
        _expectMl(r.tiers[0].fluidMl, 428.125);
        _expectMl(r.tiers[1].fluidMl, 0);
      },
    );

    test('t < 30 emits top_off only, carrying the whole target', () {
      final r = _hyd(65, 15);
      expect(r.tiers.map((e) => e.tier), <String>['top_off']);
      _expectMl(r.tiers.single.fluidMl, 279.6875);
    });

    test(
      'fluid never splits: exactly one tier is non-zero off the gate path',
      () {
        for (final bw in _bwGrid) {
          for (final t in _tGrid) {
            for (final check in HydrationCheck.values) {
              final r = _hyd(bw, t, check: check);
              final nonZero = r.tiers.where((e) => e.fluidMl > 0).length;
              final expected = (t >= 120 && check == HydrationCheck.dark)
                  ? 2
                  : 1;
              expect(
                nonZero,
                expected,
                reason: 'bw=$bw t=$t check=${check.wireValue}',
              );
            }
          }
        }
      },
    );
  });

  // ===========================================================================
  // hydrationCheck — the only individualization in the slice
  // ===========================================================================

  group('hydrationCheck', () {
    test('at t >= T_REF the target moves but the band is byte-identical', () {
      for (final t in <double>[120, 180, 240]) {
        final pale = _hyd(65, t, check: HydrationCheck.pale);
        final dark = _hyd(65, t, check: HydrationCheck.dark);
        final unknown = _hyd(65, t, check: HydrationCheck.unknown);

        _expectMl(pale.fluidMl, 487.5, reason: 't=$t pale');
        _expectMl(dark.fluidMl, 747.5, reason: 't=$t dark');
        _expectMl(unknown.fluidMl, 487.5, reason: 't=$t unknown -> pale');

        // Invariant 8b — byte-identical, so exact equality, not closeTo.
        expect(dark.fluidLowMl, pale.fluidLowMl, reason: 't=$t low');
        expect(dark.fluidHighMl, pale.fluidHighMl, reason: 't=$t high');
        expect(unknown.fluidLowMl, pale.fluidLowMl, reason: 't=$t low');
        expect(unknown.fluidHighMl, pale.fluidHighMl, reason: 't=$t high');
      }
    });

    test('below T_REF all three checks produce identical output', () {
      for (final t in _tGrid.where((t) => t < 120)) {
        final pale = _hyd(65, t, check: HydrationCheck.pale);
        final dark = _hyd(65, t, check: HydrationCheck.dark);
        final unknown = _hyd(65, t, check: HydrationCheck.unknown);
        for (final other in <PreWorkoutHydrationResult>[dark, unknown]) {
          expect(other.fluidMl, pale.fluidMl, reason: 't=$t fluidMl');
          expect(other.fluidLowMl, pale.fluidLowMl, reason: 't=$t low');
          expect(other.fluidHighMl, pale.fluidHighMl, reason: 't=$t high');
          expect(other.regime, pale.regime, reason: 't=$t regime');
          expect(other.targetBasis, pale.targetBasis, reason: 't=$t basis');
          expect(other.tiers.length, pale.tiers.length, reason: 't=$t tiers');
          for (var i = 0; i < pale.tiers.length; i++) {
            expect(other.tiers[i].tier, pale.tiers[i].tier);
            expect(other.tiers[i].fluidMl, pale.tiers[i].fluidMl);
          }
        }
      }
    });

    test('the hydrationCheckUsed echo is asymmetric across T_REF', () {
      // `unknown` normalises to `pale` ONLY inside the t >= T_REF branch.
      expect(
        _hyd(65, 120, check: HydrationCheck.unknown).hydrationCheckUsed,
        'pale',
      );
      expect(
        _hyd(65, 240, check: HydrationCheck.unknown).hydrationCheckUsed,
        'pale',
      );
      // Below it the raw value passes straight through.
      expect(
        _hyd(65, 120 - _eps, check: HydrationCheck.unknown).hydrationCheckUsed,
        'unknown',
      );
      expect(
        _hyd(65, 0, check: HydrationCheck.unknown).hydrationCheckUsed,
        'unknown',
      );
      // pale and dark echo themselves on both sides.
      for (final t in <double>[0, 30, 119, 120, 240]) {
        expect(
          _hyd(65, t, check: HydrationCheck.pale).hydrationCheckUsed,
          'pale',
          reason: 't=$t',
        );
        expect(
          _hyd(65, t, check: HydrationCheck.dark).hydrationCheckUsed,
          'dark',
          reason: 't=$t',
        );
      }
    });

    test('the default hydrationCheck is unknown', () {
      final defaulted = OfflineMacroCalculator.calculatePreWorkoutHydration(
        bodyWeightKg: 65,
        workoutDurationMin: 90,
        timeBeforeWorkoutMin: 60,
      );
      expect(defaulted.hydrationCheckUsed, 'unknown');
    });
  });

  // ===========================================================================
  // Invariants, as property tests over the ratified grid
  // ===========================================================================

  group('invariants (property tests over the 15-min grid x 30..160 kg)', () {
    test('1: 0 <= low <= plan <= high wherever non-null', () {
      for (final bw in _bwGrid) {
        for (final t in _tGrid) {
          for (final check in HydrationCheck.values) {
            final r = _hyd(bw, t, check: check);
            final where = 'bw=$bw t=$t check=${check.wireValue}';
            expect(r.fluidLowMl! >= 0, isTrue, reason: where);
            expect(r.fluidLowMl! <= r.fluidMl! + _tolMl, isTrue, reason: where);
            expect(
              r.fluidMl! <= r.fluidHighMl! + _tolMl,
              isTrue,
              reason: where,
            );
          }
        }
      }
    });

    test('2: fluidMl == sum(tiers[].fluidMl)', () {
      for (final bw in _bwGrid) {
        for (final t in _tGrid) {
          for (final check in HydrationCheck.values) {
            final r = _hyd(bw, t, check: check);
            expect(
              _sumTiers(r),
              closeTo(r.fluidMl!, _tolMl),
              reason: 'bw=$bw t=$t check=${check.wireValue}',
            );
          }
        }
      }
    });

    test(
      '3: fluidMl is non-decreasing in t on both the pale and dark paths',
      () {
        for (final bw in _bwGrid) {
          for (final check in <HydrationCheck>[
            HydrationCheck.pale,
            HydrationCheck.dark,
          ]) {
            var previous = double.negativeInfinity;
            for (final t in _tGrid) {
              final value = _hyd(bw, t, check: check).fluidMl!;
              expect(
                value >= previous - _tolMl,
                isTrue,
                reason:
                    'bw=$bw t=$t check=${check.wireValue} '
                    '($value < $previous)',
              );
              previous = value;
            }
          }
        }
      },
    );

    test('4: the pale path is continuous at t = 120 and t = 30', () {
      for (final bw in _bwGrid) {
        for (final boundary in <double>[120, 30]) {
          final below = _hyd(
            bw,
            boundary - _eps,
            check: HydrationCheck.pale,
          ).fluidMl!;
          final above = _hyd(
            bw,
            boundary + _eps,
            check: HydrationCheck.pale,
          ).fluidMl!;
          expect(
            (above - below).abs() < 1e-6 * bw + _tolMl,
            isTrue,
            reason: 'bw=$bw boundary=$boundary: $below -> $above',
          );
        }
      }
    });

    test('5: the dark-path step at t = 120 is exactly 4 ml/kg', () {
      for (final bw in _bwGrid) {
        final below = _hyd(bw, 120 - _eps, check: HydrationCheck.dark).fluidMl!;
        final above = _hyd(bw, 120, check: HydrationCheck.dark).fluidMl!;
        expect(
          above - below,
          closeTo(4.0 * bw, _tolMl),
          reason: 'bw=$bw: $below -> $above',
        );
      }
    });

    test('8: high == 12 ml/kg above T_REF and <= 10 ml/kg below it', () {
      for (final bw in _bwGrid) {
        for (final check in HydrationCheck.values) {
          for (final t in _tGrid) {
            final high = _hyd(bw, t, check: check).fluidHighMl!;
            final where = 'bw=$bw t=$t check=${check.wireValue}';
            if (t >= 120) {
              expect(high, closeTo(12.0 * bw, _tolMl), reason: where);
            } else {
              expect(high <= 10.0 * bw + _tolMl, isTrue, reason: where);
            }
          }
        }
      }
    });

    test(
      '8a: the plan cap has teeth — plan <= 12 ml/kg, and it binds the band',
      () {
        for (final bw in _bwGrid) {
          for (final t in _tGrid) {
            for (final check in HydrationCheck.values) {
              final r = _hyd(bw, t, check: check);
              expect(
                r.fluidMl! <= 12.0 * bw + _tolMl,
                isTrue,
                reason: 'bw=$bw t=$t check=${check.wireValue}',
              );
            }
          }
          // min(7.5 + 5, 12) selected the cap, on the dark path too.
          expect(
            _hyd(bw, 180, check: HydrationCheck.dark).fluidHighMl,
            closeTo(12.0 * bw, _tolMl),
            reason: 'bw=$bw',
          );
        }
      },
    );

    test('8b: the band above T_REF is independent of hydrationCheck', () {
      for (final bw in _bwGrid) {
        for (final t in _tGrid.where((t) => t >= 120)) {
          final reference = _hyd(bw, t, check: HydrationCheck.pale);
          for (final check in HydrationCheck.values) {
            final r = _hyd(bw, t, check: check);
            // Byte-identical: exact equality, never a tolerance.
            expect(
              r.fluidLowMl,
              reference.fluidLowMl,
              reason: 'bw=$bw t=$t check=${check.wireValue}',
            );
            expect(
              r.fluidHighMl,
              reference.fluidHighMl,
              reason: 'bw=$bw t=$t check=${check.wireValue}',
            );
          }
        }
      }
    });

    test('9: the clearance-bound region is always inside the top-off tier', () {
      // Analytic form: ln(10*BW / R_CEILING) / K <= 30 for all BW <= 198.
      for (var bw = 40.0; bw <= 198.0; bw += 1.0) {
        final crossing =
            math.log(10.0 * bw / OfflineMacroCalculator.rCeiling) /
            OfflineMacroCalculator.k;
        expect(crossing <= 30.0, isTrue, reason: 'bw=$bw crossing=$crossing');
      }
      // Behavioural form: no swept athlete is clearance-bound at or above t=30.
      for (final bw in _bwGrid) {
        for (final t in _tGrid.where((t) => t >= 30)) {
          expect(
            _hyd(bw, t).regime,
            isNot('clearance_bound'),
            reason: 'bw=$bw t=$t',
          );
        }
      }
    });

    test(
      '11: the gate path returns null/null/null and empty tiers, never 0',
      () {
        for (final bw in _bwGrid) {
          for (final t in _tGrid) {
            final r = _hyd(bw, t, dur: 30, tempC: 12);
            final where = 'bw=$bw t=$t';
            expect(r.gateTriggered, isTrue, reason: where);
            expect(r.fluidMl, isNull, reason: where);
            expect(r.fluidLowMl, isNull, reason: where);
            expect(r.fluidHighMl, isNull, reason: where);
            expect(r.tiers, isEmpty, reason: where);
            expect(r.regime, 'gated', reason: where);
            expect(r.targetBasis, 'none', reason: where);
          }
        }
      },
    );

    test('below T_REF fluidLowMl is 0.0 — zero, not null', () {
      for (final t in _tGrid.where((t) => t < 120)) {
        final r = _hyd(65, t);
        expect(r.fluidLowMl, isNotNull, reason: 't=$t');
        expect(r.fluidLowMl, 0.0, reason: 't=$t');
      }
    });
  });

  // ===========================================================================
  // Cross-spec pin (hydration invariant 10 / carbs invariant 10)
  // ===========================================================================

  group('cross-spec pin', () {
    test('T_REF == TIER_MEAL_MIN', () {
      expect(
        OfflineMacroCalculator.tRef,
        OfflineMacroCalculator.tierMealMin,
        reason:
            'CROSS-SPEC PIN BROKEN: pre-workout-hydration.T_REF != '
            'pre-workout-carbs.TIER_MEAL_MIN. See invariant 10 in both specs.',
      );
    });

    test('the runtime pin assertion does not throw', () {
      expect(OfflineMacroCalculator.assertCrossSpecPin, returnsNormally);
    });

    test('K is computed as 3.2 / 60, not a truncated literal', () {
      expect(OfflineMacroCalculator.k, 3.2 / 60);
    });
  });
}
