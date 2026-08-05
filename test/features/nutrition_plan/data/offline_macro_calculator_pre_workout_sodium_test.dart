// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/offline_macro_calculator.dart';

/// Calculator-level conformance tests for **pre-workout sodium v3**.
///
/// SSOT: `docs/ssot/spec/fueling/pre-workout-sodium.md` (v3, ratified
/// 2026-08-03) and `docs/ssot/vectors/fueling/pre-workout-sodium.json`.
///
/// The entire algorithm is `sodiumMg = sodiumLowMg = sodiumHighMg = null`, in
/// every tier and on the gate path. **`null`, never `0`** — zero is the
/// recommendation "consume no sodium", which is not what is meant. Every
/// assertion here is `isNull`; an assertion that would also pass on `0` is a
/// broken test, so none of them compare against a number.
///
/// The v1 targets (450 mg [300-600] in tier 1, 150 mg [100-200] in tier 2, 0 in
/// tier 3) were removed rather than re-derived — see D-007 in the spec.

/// The ratified input domain: 0..240 min in 15-minute steps.
const List<double> _tGrid = <double>[
  0, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180, 195, 210, 225, 240,
];

const List<double> _bwGrid = <double>[30, 50, 65, 90, 100, 130, 160];

/// One ratified vector from `pre-workout-sodium.json`.
class _SVec {
  const _SVec({
    required this.id,
    required this.bw,
    required this.dur,
    required this.t,
    required this.tempC,
    required this.check,
  });

  final String id;
  final double bw;
  final double dur;
  final double t;
  final double? tempC;
  final HydrationCheck check;
}

/// Generated verbatim from `docs/ssot/vectors/fueling/pre-workout-sodium.json`.
/// Every vector expects null/null/null, so the expectation is not carried per
/// row — it is the whole slice.
const List<_SVec> _sodiumVectors = <_SVec>[
  _SVec(
    id: 'meal-tier-65-pale',
    bw: 65.0,
    dur: 90.0,
    t: 180.0,
    tempC: 22.0,
    check: HydrationCheck.pale,
  ),
  _SVec(
    id: 'meal-tier-65-dark',
    bw: 65.0,
    dur: 90.0,
    t: 180.0,
    tempC: 22.0,
    check: HydrationCheck.dark,
  ),
  _SVec(
    id: 'snack-tier-65',
    bw: 65.0,
    dur: 90.0,
    t: 60.0,
    tempC: 22.0,
    check: HydrationCheck.unknown,
  ),
  _SVec(
    id: 'topoff-tier-65',
    bw: 65.0,
    dur: 90.0,
    t: 15.0,
    tempC: 22.0,
    check: HydrationCheck.unknown,
  ),
  _SVec(
    id: 'gate-path-45min',
    bw: 65.0,
    dur: 45.0,
    t: 180.0,
    tempC: 22.0,
    check: HydrationCheck.pale,
  ),
  _SVec(
    id: 'heavy-100kg',
    bw: 100.0,
    dur: 120.0,
    t: 240.0,
    tempC: 25.0,
    check: HydrationCheck.pale,
  ),
  _SVec(
    id: 'hot-32c',
    bw: 65.0,
    dur: 90.0,
    t: 120.0,
    tempC: 32.0,
    check: HydrationCheck.pale,
  ),
  _SVec(
    id: 'light-50kg-90min',
    bw: 50.0,
    dur: 90.0,
    t: 90.0,
    tempC: 22.0,
    check: HydrationCheck.dark,
  ),
];

void _expectNoSodium(PreWorkoutHydrationResult r, String where) {
  expect(r.sodiumMg, isNull, reason: '$where sodiumMg');
  expect(r.sodiumLowMg, isNull, reason: '$where sodiumLowMg');
  expect(r.sodiumHighMg, isNull, reason: '$where sodiumHighMg');
}

void main() {
  group('pre-workout-sodium.json — all ratified vectors', () {
    test('the whole ratified set is present (8 vectors)', () {
      expect(_sodiumVectors.length, 8);
    });

    for (final v in _sodiumVectors) {
      test('vector ${v.id} sets no sodium target', () {
        final r = OfflineMacroCalculator.calculatePreWorkoutHydration(
          bodyWeightKg: v.bw,
          workoutDurationMin: v.dur,
          timeBeforeWorkoutMin: v.t,
          tempC: v.tempC,
          hydrationCheck: v.check,
        );
        _expectNoSodium(r, v.id);
      });
    }
  });

  group('no input introduces a sodium number', () {
    test('not lead time, body weight or hydrationCheck', () {
      for (final bw in _bwGrid) {
        for (final t in _tGrid) {
          for (final check in HydrationCheck.values) {
            final r = OfflineMacroCalculator.calculatePreWorkoutHydration(
              bodyWeightKg: bw,
              workoutDurationMin: 90,
              timeBeforeWorkoutMin: t,
              tempC: 22,
              hydrationCheck: check,
            );
            _expectNoSodium(r, 'bw=$bw t=$t check=${check.wireValue}');
          }
        }
      }
    });

    test('not temperature, including the tempC-null default', () {
      for (final tempC in <double?>[null, -10, 0, 22, 29, 30, 32, 45]) {
        final r = OfflineMacroCalculator.calculatePreWorkoutHydration(
          bodyWeightKg: 65,
          workoutDurationMin: 90,
          timeBeforeWorkoutMin: 120,
          tempC: tempC,
        );
        _expectNoSodium(r, 'tempC=$tempC');
      }
    });

    test('not workout duration, on either side of the gate', () {
      for (final dur in <double>[10, 45, 59, 60, 90, 240, 600]) {
        final r = OfflineMacroCalculator.calculatePreWorkoutHydration(
          bodyWeightKg: 65,
          workoutDurationMin: dur,
          timeBeforeWorkoutMin: 180,
          tempC: 22,
        );
        _expectNoSodium(r, 'dur=$dur');
      }
    });
  });

  group('every tier and the gate path', () {
    test('meal tier (t >= 120)', () {
      _expectNoSodium(
        OfflineMacroCalculator.calculatePreWorkoutHydration(
          bodyWeightKg: 65,
          workoutDurationMin: 90,
          timeBeforeWorkoutMin: 180,
          tempC: 22,
          hydrationCheck: HydrationCheck.dark,
        ),
        'meal tier',
      );
    });

    test('snack tier (30 <= t < 120)', () {
      _expectNoSodium(
        OfflineMacroCalculator.calculatePreWorkoutHydration(
          bodyWeightKg: 65,
          workoutDurationMin: 90,
          timeBeforeWorkoutMin: 60,
          tempC: 22,
        ),
        'snack tier',
      );
    });

    test('top-off tier (t < 30)', () {
      _expectNoSodium(
        OfflineMacroCalculator.calculatePreWorkoutHydration(
          bodyWeightKg: 65,
          workoutDurationMin: 90,
          timeBeforeWorkoutMin: 15,
          tempC: 22,
        ),
        'top-off tier',
      );
    });

    test('gate path returns null sodium, not 0', () {
      final r = OfflineMacroCalculator.calculatePreWorkoutHydration(
        bodyWeightKg: 65,
        workoutDurationMin: 45,
        timeBeforeWorkoutMin: 180,
        tempC: 22,
      );
      expect(r.gateTriggered, isTrue);
      _expectNoSodium(r, 'gate path');
    });
  });

  test('the fields are nullable ints — a 0 could never be mistaken for absent', () {
    final r = OfflineMacroCalculator.calculatePreWorkoutHydration(
      bodyWeightKg: 65,
      workoutDurationMin: 90,
      timeBeforeWorkoutMin: 180,
      tempC: 22,
    );
    // Typed as int?, so `0` is representable and distinct from null. This
    // asserts the widening from v1's non-nullable int actually happened.
    final int? sodium = r.sodiumMg;
    expect(sodium, isNull);
    expect(sodium == 0, isFalse);
  });
}
