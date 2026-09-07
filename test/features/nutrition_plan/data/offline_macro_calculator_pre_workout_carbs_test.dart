// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/offline_macro_calculator.dart';

/// Calculator-level conformance tests for **pre-workout carbohydrate v2**.
///
/// SSOT: `docs/ssot/spec/fueling/pre-workout-carbs.md` (v2, 2026-08-04) and its
/// ratified vector set `docs/ssot/vectors/fueling/pre-workout-carbs.json`.
///
/// The engine never rounds; grams are exact doubles compared with an absolute
/// tolerance of 1e-3 g, the tolerance the vector file declares. The one place a
/// rounded figure is legitimate is the legacy `calculatePreWorkoutTargets` map
/// boundary, covered in its own group at the bottom.

/// Absolute tolerance for every gram comparison. From the vector file.
const double _tolG = 1e-3;

/// Tolerance for assertions the spec says are exact (shares, tier-window sums).
const double _exact = 1e-9;

/// A nudge that isolates a branch change rather than a value change.
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

PreWorkoutCarbResult _carbs(
  double bw,
  double t, {
  double dur = 90.0,
  bool isFasted = false,
}) {
  return OfflineMacroCalculator.calculatePreWorkoutCarbs(
    bodyWeightKg: bw,
    timeBeforeWorkoutMin: t,
    workoutDurationMin: dur,
    isFasted: isFasted,
  );
}

double _sumTiers(PreWorkoutCarbResult r) =>
    r.tiers.fold<double>(0.0, (sum, tier) => sum + tier.carbsG);

PreWorkoutCarbTier? _tier(PreWorkoutCarbResult r, String name) {
  for (final tier in r.tiers) {
    if (tier.tier == name) return tier;
  }
  return null;
}

/// One expected tier inside a ratified vector.
class _CTier {
  const _CTier(
    this.tier,
    this.carbsG,
    this.rangeLowG,
    this.rangeHighG,
    this.composition,
  );

  final String tier;
  final double carbsG;
  final double rangeLowG;
  final double rangeHighG;
  final String composition;
}

/// One ratified vector from `pre-workout-carbs.json`.
class _CVec {
  const _CVec({
    required this.id,
    required this.bw,
    required this.t,
    required this.dur,
    required this.fasted,
    required this.carbsG,
    required this.lowG,
    required this.highG,
    required this.basis,
    required this.tiers,
  });

  final String id;
  final double bw;
  final double t;
  final double dur;
  final bool fasted;
  final double carbsG;
  final double lowG;
  final double highG;
  final String basis;
  final List<_CTier> tiers;
}

/// Generated verbatim from `docs/ssot/vectors/fueling/pre-workout-carbs.json`.
const List<_CVec> _carbVectors = <_CVec>[
  _CVec(
    id: 'cited-cap-240-65',
    bw: 65.0,
    t: 240.0,
    dur: 90.0,
    fasted: false,
    carbsG: 260.0,
    lowG: 227.5,
    highG: 292.5,
    basis: 'evidenced_band',
    tiers: <_CTier>[
      _CTier('meal', 156.0, 136.5, 175.5, 'meal'),
      _CTier('snack', 78.0, 68.25, 87.75, 'snack'),
      _CTier('top_off', 26.0, 22.75, 29.25, 'top_off'),
    ],
  ),
  _CVec(
    id: 'cited-225-65',
    bw: 65.0,
    t: 225.0,
    dur: 90.0,
    fasted: false,
    carbsG: 243.75,
    lowG: 213.28125,
    highG: 274.21875,
    basis: 'evidenced_band',
    tiers: <_CTier>[
      _CTier('meal', 146.25, 127.96875, 164.53125, 'meal'),
      _CTier('snack', 73.125, 63.984375, 82.265625, 'snack'),
      _CTier('top_off', 24.375, 21.328125, 27.421875, 'top_off'),
    ],
  ),
  _CVec(
    id: 'cited-210-65',
    bw: 65.0,
    t: 210.0,
    dur: 90.0,
    fasted: false,
    carbsG: 227.5,
    lowG: 199.0625,
    highG: 255.9375,
    basis: 'evidenced_band',
    tiers: <_CTier>[
      _CTier('meal', 136.5, 119.4375, 153.5625, 'meal'),
      _CTier('snack', 68.25, 59.71875, 76.78125, 'snack'),
      _CTier('top_off', 22.75, 19.90625, 25.59375, 'top_off'),
    ],
  ),
  _CVec(
    id: 'cited-195-65',
    bw: 65.0,
    t: 195.0,
    dur: 90.0,
    fasted: false,
    carbsG: 211.25,
    lowG: 184.84375,
    highG: 237.65625,
    basis: 'evidenced_band',
    tiers: <_CTier>[
      _CTier('meal', 126.75, 110.90625, 142.59375, 'meal'),
      _CTier('snack', 63.375, 55.453125, 71.296875, 'snack'),
      _CTier('top_off', 21.125, 18.484375, 23.765625, 'top_off'),
    ],
  ),
  _CVec(
    id: 'cited-cap-240-100kg',
    bw: 100.0,
    t: 240.0,
    dur: 90.0,
    fasted: false,
    carbsG: 400.0,
    lowG: 350.0,
    highG: 450.0,
    basis: 'evidenced_band',
    tiers: <_CTier>[
      _CTier('meal', 240.0, 210.0, 270.0, 'meal'),
      _CTier('snack', 120.0, 105.0, 135.0, 'snack'),
      _CTier('top_off', 40.0, 35.0, 45.0, 'top_off'),
    ],
  ),
  _CVec(
    id: 'cited-180-65',
    bw: 65.0,
    t: 180.0,
    dur: 90.0,
    fasted: false,
    carbsG: 195.0,
    lowG: 170.625,
    highG: 219.375,
    basis: 'evidenced_band',
    tiers: <_CTier>[
      _CTier('meal', 117.0, 102.375, 131.625, 'meal'),
      _CTier('snack', 58.5, 51.1875, 65.8125, 'snack'),
      _CTier('top_off', 19.5, 17.0625, 21.9375, 'top_off'),
    ],
  ),
  _CVec(
    id: 'cited-boundary-120-65',
    bw: 65.0,
    t: 120.0,
    dur: 90.0,
    fasted: false,
    carbsG: 130.0,
    lowG: 113.75,
    highG: 146.25,
    basis: 'evidenced_band',
    tiers: <_CTier>[
      _CTier('meal', 78.0, 68.25, 87.75, 'meal'),
      _CTier('snack', 39.0, 34.125, 43.875, 'snack'),
      _CTier('top_off', 13.0, 11.375, 14.625, 'top_off'),
    ],
  ),
  _CVec(
    id: 'cited-105-nomeal-65',
    bw: 65.0,
    t: 105.0,
    dur: 90.0,
    fasted: false,
    carbsG: 113.75,
    lowG: 99.53125,
    highG: 127.96875,
    basis: 'evidenced_band',
    tiers: <_CTier>[
      _CTier('snack', 85.3125, 74.648438, 95.976562, 'snack'),
      _CTier('top_off', 28.4375, 24.882812, 31.992188, 'top_off'),
    ],
  ),
  _CVec(
    id: 'cited-lower-edge-60-65',
    bw: 65.0,
    t: 60.0,
    dur: 90.0,
    fasted: false,
    carbsG: 65.0,
    lowG: 56.875,
    highG: 73.125,
    basis: 'evidenced_band',
    tiers: <_CTier>[
      _CTier('snack', 48.75, 42.65625, 54.84375, 'snack'),
      _CTier('top_off', 16.25, 14.21875, 18.28125, 'top_off'),
    ],
  ),
  _CVec(
    id: 'design-45-65',
    bw: 65.0,
    t: 45.0,
    dur: 90.0,
    fasted: false,
    carbsG: 48.75,
    lowG: 42.65625,
    highG: 54.84375,
    basis: 'design_choice',
    tiers: <_CTier>[
      _CTier('snack', 36.5625, 31.992188, 41.132812, 'snack'),
      _CTier('top_off', 12.1875, 10.664062, 13.710938, 'top_off'),
    ],
  ),
  _CVec(
    id: 'design-snack-edge-30-65',
    bw: 65.0,
    t: 30.0,
    dur: 90.0,
    fasted: false,
    carbsG: 32.5,
    lowG: 28.4375,
    highG: 36.5625,
    basis: 'design_choice',
    tiers: <_CTier>[
      _CTier('snack', 24.375, 21.328125, 27.421875, 'snack'),
      _CTier('top_off', 8.125, 7.109375, 9.140625, 'top_off'),
    ],
  ),
  _CVec(
    id: 'design-topoff-only-15-65',
    bw: 65.0,
    t: 15.0,
    dur: 90.0,
    fasted: false,
    carbsG: 16.25,
    lowG: 14.21875,
    highG: 18.28125,
    basis: 'design_choice',
    tiers: <_CTier>[_CTier('top_off', 16.25, 14.21875, 18.28125, 'top_off')],
  ),
  _CVec(
    id: 'design-anchor-0-65',
    bw: 65.0,
    t: 0.0,
    dur: 90.0,
    fasted: false,
    carbsG: 0.0,
    lowG: 0.0,
    highG: 0.0,
    basis: 'design_choice',
    tiers: <_CTier>[_CTier('top_off', 0.0, 0.0, 0.0, 'top_off')],
  ),
  _CVec(
    id: 'fasted-180-65',
    bw: 65.0,
    t: 180.0,
    dur: 90.0,
    fasted: true,
    carbsG: 0.0,
    lowG: 0.0,
    highG: 0.0,
    basis: 'none',
    tiers: <_CTier>[],
  ),
  _CVec(
    id: 'dur-flip-short-180-65',
    bw: 65.0,
    t: 180.0,
    dur: 59.0,
    fasted: false,
    carbsG: 195.0,
    lowG: 170.625,
    highG: 219.375,
    basis: 'design_choice',
    tiers: <_CTier>[
      _CTier('meal', 117.0, 102.375, 131.625, 'meal'),
      _CTier('snack', 58.5, 51.1875, 65.8125, 'snack'),
      _CTier('top_off', 19.5, 17.0625, 21.9375, 'top_off'),
    ],
  ),
  _CVec(
    id: 'dur-boundary-60-180-65',
    bw: 65.0,
    t: 180.0,
    dur: 60.0,
    fasted: false,
    carbsG: 195.0,
    lowG: 170.625,
    highG: 219.375,
    basis: 'evidenced_band',
    tiers: <_CTier>[
      _CTier('meal', 117.0, 102.375, 131.625, 'meal'),
      _CTier('snack', 58.5, 51.1875, 65.8125, 'snack'),
      _CTier('top_off', 19.5, 17.0625, 21.9375, 'top_off'),
    ],
  ),
  _CVec(
    id: 'cited-180-90kg',
    bw: 90.0,
    t: 180.0,
    dur: 120.0,
    fasted: false,
    carbsG: 270.0,
    lowG: 236.25,
    highG: 303.75,
    basis: 'evidenced_band',
    tiers: <_CTier>[
      _CTier('meal', 162.0, 141.75, 182.25, 'meal'),
      _CTier('snack', 81.0, 70.875, 91.125, 'snack'),
      _CTier('top_off', 27.0, 23.625, 30.375, 'top_off'),
    ],
  ),
  _CVec(
    id: 'cited-120-100kg',
    bw: 100.0,
    t: 120.0,
    dur: 90.0,
    fasted: false,
    carbsG: 200.0,
    lowG: 175.0,
    highG: 225.0,
    basis: 'evidenced_band',
    tiers: <_CTier>[
      _CTier('meal', 120.0, 105.0, 135.0, 'meal'),
      _CTier('snack', 60.0, 52.5, 67.5, 'snack'),
      _CTier('top_off', 20.0, 17.5, 22.5, 'top_off'),
    ],
  ),
  _CVec(
    id: 'design-30-48kg',
    bw: 48.0,
    t: 30.0,
    dur: 90.0,
    fasted: false,
    carbsG: 24.0,
    lowG: 21.0,
    highG: 27.0,
    basis: 'design_choice',
    tiers: <_CTier>[
      _CTier('snack', 18.0, 15.75, 20.25, 'snack'),
      _CTier('top_off', 6.0, 5.25, 6.75, 'top_off'),
    ],
  ),
];

void main() {
  // ===========================================================================
  // The 19 ratified vectors
  // ===========================================================================

  group('pre-workout-carbs.json — all ratified vectors', () {
    test('the whole ratified set is present (19 vectors)', () {
      expect(_carbVectors.length, 19);
    });

    for (final v in _carbVectors) {
      test('vector ${v.id}', () {
        final r = OfflineMacroCalculator.calculatePreWorkoutCarbs(
          bodyWeightKg: v.bw,
          timeBeforeWorkoutMin: v.t,
          workoutDurationMin: v.dur,
          isFasted: v.fasted,
        );

        expect(r.carbsG, closeTo(v.carbsG, _tolG), reason: '${v.id} carbsG');
        expect(
          r.carbsLowG,
          closeTo(v.lowG, _tolG),
          reason: '${v.id} carbsLowG',
        );
        expect(
          r.carbsHighG,
          closeTo(v.highG, _tolG),
          reason: '${v.id} carbsHighG',
        );
        expect(r.targetBasis, v.basis, reason: '${v.id} targetBasis');

        expect(
          r.tiers.map((e) => e.tier).toList(),
          v.tiers.map((e) => e.tier).toList(),
          reason: '${v.id} tier names and order',
        );
        for (var i = 0; i < v.tiers.length; i++) {
          final actual = r.tiers[i];
          final expected = v.tiers[i];
          final where = '${v.id} tier ${expected.tier}';
          expect(actual.carbsG, closeTo(expected.carbsG, _tolG), reason: where);
          expect(
            actual.rangeLowG,
            closeTo(expected.rangeLowG, _tolG),
            reason: '$where rangeLowG',
          );
          expect(
            actual.rangeHighG,
            closeTo(expected.rangeHighG, _tolG),
            reason: '$where rangeHighG',
          );
          expect(
            actual.composition,
            expected.composition,
            reason: '$where composition',
          );
        }
      });
    }
  });

  // ===========================================================================
  // The two semantically distinct zeros
  // ===========================================================================

  group('the two distinct zeros', () {
    test('t = 0 means "no time to eat": zero, with a top_off tier present', () {
      final r = _carbs(65, 0);
      expect(r.carbsG, closeTo(0, _tolG));
      expect(r.carbsLowG, closeTo(0, _tolG));
      expect(r.carbsHighG, closeTo(0, _tolG));
      expect(r.targetBasis, 'design_choice');
      expect(r.tiers, hasLength(1));
      expect(r.tiers.single.tier, 'top_off');
      expect(r.tiers.single.carbsG, closeTo(0, _tolG));
      expect(r.tiers.single.composition, 'top_off');
    });

    test('isFasted means "no recommendation": zero, with EMPTY tiers', () {
      final r = _carbs(65, 180, isFasted: true);
      expect(r.carbsG, closeTo(0, _tolG));
      expect(r.carbsLowG, closeTo(0, _tolG));
      expect(r.carbsHighG, closeTo(0, _tolG));
      expect(r.targetBasis, 'none');
      expect(r.tiers, isEmpty);
    });

    test('the two are distinguishable without reading carbsG', () {
      final atZero = _carbs(65, 0);
      final fasted = _carbs(65, 0, isFasted: true);
      expect(atZero.carbsG, fasted.carbsG); // identical number...
      expect(
        atZero.tiers.length,
        isNot(fasted.tiers.length),
      ); // ...different shape
      expect(atZero.targetBasis, isNot(fasted.targetBasis));
    });

    test('isFasted short-circuits at every lead time and body weight', () {
      for (final bw in _bwGrid) {
        for (final t in _tGrid) {
          final r = _carbs(bw, t, isFasted: true);
          expect(r.carbsG, 0.0, reason: 'bw=$bw t=$t');
          expect(r.tiers, isEmpty, reason: 'bw=$bw t=$t');
          expect(r.targetBasis, 'none', reason: 'bw=$bw t=$t');
        }
      }
    });
  });

  // ===========================================================================
  // Tier membership at the boundaries
  // ===========================================================================

  group('tier membership at the boundaries', () {
    test('t == 120 admits the meal tier (inclusive at the bottom)', () {
      expect(_carbs(65, 120).tiers.map((e) => e.tier), <String>[
        'meal',
        'snack',
        'top_off',
      ]);
    });

    test('just below 120 drops the meal and re-weights 75/25', () {
      final r = _carbs(65, 120 - _eps);
      expect(r.tiers.map((e) => e.tier), <String>['snack', 'top_off']);
      expect(_tier(r, 'snack')!.carbsG, closeTo(0.75 * r.carbsG, _exact));
      expect(_tier(r, 'top_off')!.carbsG, closeTo(0.25 * r.carbsG, _exact));
    });

    test('t == 30 admits the snack tier (inclusive at the bottom)', () {
      expect(_carbs(65, 30).tiers.map((e) => e.tier), <String>[
        'snack',
        'top_off',
      ]);
    });

    test('just below 30 leaves the top-off carrying everything', () {
      final r = _carbs(65, 30 - _eps);
      expect(r.tiers.map((e) => e.tier), <String>['top_off']);
      expect(r.tiers.single.carbsG, closeTo(r.carbsG, _exact));
    });

    test('top_off is always present off the fasted path', () {
      for (final bw in _bwGrid) {
        for (final t in _tGrid) {
          expect(
            _tier(_carbs(bw, t), 'top_off'),
            isNotNull,
            reason: 'bw=$bw t=$t',
          );
        }
      }
    });

    test('negative lead time clamps to 0', () {
      for (final t in <double>[-0.5, -30, -240]) {
        final r = _carbs(65, t);
        expect(r.carbsG, closeTo(0, _tolG), reason: 't=$t');
        expect(r.tiers.map((e) => e.tier), <String>['top_off'], reason: 't=$t');
        expect(r.targetBasis, 'design_choice', reason: 't=$t');
      }
    });
  });

  // ===========================================================================
  // Duration only flips the band and the basis — never a gram
  // ===========================================================================

  group('the duration flip', () {
    test('dur = 59 at t = 180 is design_choice with a +/-12.5 % band', () {
      final r = _carbs(65, 180, dur: 59);
      expect(r.targetBasis, 'design_choice');
      expect(r.carbsG, closeTo(195, _tolG));
      expect(r.carbsLowG, closeTo(170.625, _tolG));
      expect(r.carbsHighG, closeTo(219.375, _tolG));
    });

    test(
      'dur = 60 at t = 180 flips targetBasis only — the band stays ±12.5%',
      () {
        // Invariant 11 (AMENDED Xuan, 2026-09-04): the flip moves targetBasis,
        // never the band. The superseded [1·BW, 4·BW] in-window band is gone
        // (invariant 12: target ± TIER_TOL in all cases).
        final r = _carbs(65, 180, dur: 60);
        expect(r.targetBasis, 'evidenced_band');
        expect(r.carbsG, closeTo(195, _tolG));
        expect(r.carbsLowG, closeTo(170.625, _tolG));
        expect(r.carbsHighG, closeTo(219.375, _tolG));
      },
    );

    test('duration never moves a gram, only the band', () {
      for (final t in _tGrid) {
        for (final bw in _bwGrid) {
          expect(
            _carbs(bw, t, dur: 59).carbsG,
            _carbs(bw, t, dur: 600).carbsG,
            reason: 'bw=$bw t=$t',
          );
        }
      }
    });

    test(
      'carbohydrate has no gate: a 20-min session at t-10 still gets a number',
      () {
        final r = _carbs(65, 10, dur: 20);
        expect(r.carbsG, closeTo(65 * 10 / 60, _tolG));
        expect(r.targetBasis, 'design_choice');
        expect(r.tiers, hasLength(1));
      },
    );
  });

  // ===========================================================================
  // The 4 g/kg cap and the WINDOW_MAX mirror guard
  // ===========================================================================

  group('the 4 g/kg cap', () {
    test('binds at t = 240 for 65 kg — 260 g, at the band CENTRE', () {
      // Invariant 12: the band is target ± 12.5% everywhere, so the capped
      // 260 g target sits at the band's centre (high = 260 × 1.125), not on
      // its ceiling as under the superseded in-window band.
      final r = _carbs(65, 240);
      expect(r.carbsG, closeTo(260, _tolG));
      expect(r.carbsHighG, closeTo(292.50, _tolG));
      expect(r.targetBasis, 'evidenced_band');
    });

    test('is per-kg, not an absolute gram ceiling (100 kg -> 400 g)', () {
      final r = _carbs(100, 240);
      expect(r.carbsG, closeTo(400, _tolG));
      expect(r.carbsHighG, closeTo(450.0, _tolG)); // 400 × 1.125 (inv 12)
      // A 260 g absolute cap would show up here; a 4 g/kg cap scales.
      expect(r.carbsG, closeTo(4.0 * 100, _tolG));
    });

    test('scales across the whole weight sweep at t = 240', () {
      for (final bw in _bwGrid) {
        expect(
          _carbs(bw, 240).carbsG,
          closeTo(4.0 * bw, _tolG),
          reason: 'bw=$bw',
        );
      }
    });

    test(
      'WINDOW_MAX is the mirror guard: past 240 the band leaves the window',
      () {
        final r = _carbs(65, 300);
        expect(r.carbsG, closeTo(260, _tolG)); // still capped at 4 g/kg
        expect(r.targetBasis, 'design_choice'); // but no longer Thomas's window
      },
    );
  });

  // ===========================================================================
  // Invariants, as property tests over the ratified grid
  // ===========================================================================

  group('invariants (property tests over the 15-min grid x 30..160 kg)', () {
    test('1: carbsG == sum(tiers[].carbsG)', () {
      for (final bw in _bwGrid) {
        for (final t in _tGrid) {
          final r = _carbs(bw, t);
          expect(_sumTiers(r), closeTo(r.carbsG, _tolG), reason: 'bw=$bw t=$t');
        }
      }
    });

    test('2: carbsLowG <= carbsG <= carbsHighG', () {
      for (final bw in _bwGrid) {
        for (final t in _tGrid) {
          for (final dur in <double>[30, 90]) {
            final r = _carbs(bw, t, dur: dur);
            final where = 'bw=$bw t=$t dur=$dur';
            expect(r.carbsLowG <= r.carbsG + _tolG, isTrue, reason: where);
            expect(r.carbsG <= r.carbsHighG + _tolG, isTrue, reason: where);
          }
        }
      }
    });

    test('3: carbsG is non-decreasing in t', () {
      for (final bw in _bwGrid) {
        var previous = double.negativeInfinity;
        for (final t in _tGrid) {
          final value = _carbs(bw, t).carbsG;
          expect(
            value >= previous - _tolG,
            isTrue,
            reason: 'bw=$bw t=$t ($value < $previous)',
          );
          previous = value;
        }
      }
    });

    test(
      '4: containment in the cited box — 1 <= carbsG/BW <= 4 for 60 <= t <= 240',
      () {
        for (final bw in _bwGrid) {
          for (final t in _tGrid.where((t) => t >= 60 && t <= 240)) {
            final perKg = _carbs(bw, t).carbsG / bw;
            expect(
              perKg >= 1.0 - _tolG,
              isTrue,
              reason: 'bw=$bw t=$t -> $perKg',
            );
            expect(
              perKg <= 4.0 + _tolG,
              isTrue,
              reason: 'bw=$bw t=$t -> $perKg',
            );
          }
        }
      },
    );

    test('5: shares are exact to 1e-9', () {
      for (final bw in _bwGrid) {
        for (final t in _tGrid) {
          final r = _carbs(bw, t);
          final where = 'bw=$bw t=$t';
          if (t >= 120) {
            expect(
              _tier(r, 'meal')!.carbsG,
              closeTo(0.60 * r.carbsG, _exact),
              reason: '$where meal',
            );
            expect(
              _tier(r, 'snack')!.carbsG,
              closeTo(0.30 * r.carbsG, _exact),
              reason: '$where snack',
            );
            expect(
              _tier(r, 'top_off')!.carbsG,
              closeTo(0.10 * r.carbsG, _exact),
              reason: '$where top_off',
            );
          } else if (t >= 30) {
            expect(
              _tier(r, 'snack')!.carbsG,
              closeTo(0.75 * r.carbsG, _exact),
              reason: '$where snack',
            );
            expect(
              _tier(r, 'top_off')!.carbsG,
              closeTo(0.25 * r.carbsG, _exact),
              reason: '$where top_off',
            );
          } else {
            expect(
              _tier(r, 'top_off')!.carbsG,
              closeTo(r.carbsG, _exact),
              reason: '$where top_off',
            );
          }
        }
      }
    });

    test(
      '6: membership is exactly meal iff t>=120, snack iff t>=30, top_off always',
      () {
        for (final bw in _bwGrid) {
          for (final t in _tGrid) {
            final r = _carbs(bw, t);
            final where = 'bw=$bw t=$t';
            expect(_tier(r, 'meal') != null, t >= 120, reason: '$where meal');
            expect(_tier(r, 'snack') != null, t >= 30, reason: '$where snack');
            expect(_tier(r, 'top_off'), isNotNull, reason: '$where top_off');
          }
        }
      },
    );

    test(
      '7: the boundary steps are intentional; carbsG itself is continuous',
      () {
        for (final bw in _bwGrid) {
          // t = 120: the meal's share transfers to the snack.
          final below120 = _carbs(bw, 120 - _eps);
          final at120 = _carbs(bw, 120);
          expect(
            below120.carbsG,
            closeTo(at120.carbsG, _tolG),
            reason: 'bw=$bw total continuous at 120',
          );
          expect(
            _tier(below120, 'snack')!.carbsG,
            closeTo(0.75 * below120.carbsG, _exact),
            reason: 'bw=$bw snack below 120',
          );
          expect(
            _tier(at120, 'snack')!.carbsG,
            closeTo(0.30 * at120.carbsG, _exact),
            reason: 'bw=$bw snack at 120',
          );

          // t = 30: the snack's share transfers to the top-off.
          final below30 = _carbs(bw, 30 - _eps);
          final at30 = _carbs(bw, 30);
          expect(
            below30.carbsG,
            closeTo(at30.carbsG, _tolG),
            reason: 'bw=$bw total continuous at 30',
          );
          expect(
            _tier(below30, 'top_off')!.carbsG,
            closeTo(below30.carbsG, _exact),
            reason: 'bw=$bw top_off below 30',
          );
          expect(
            _tier(at30, 'top_off')!.carbsG,
            closeTo(0.25 * at30.carbsG, _exact),
            reason: 'bw=$bw top_off at 30',
          );
        }

        // The worked 65 kg figures the spec pins by name.
        expect(
          _tier(_carbs(65, 120 - _eps), 'snack')!.carbsG,
          closeTo(97.5, _tolG),
        );
        expect(_tier(_carbs(65, 120), 'snack')!.carbsG, closeTo(39.0, _tolG));
        expect(
          _tier(_carbs(65, 30 - _eps), 'top_off')!.carbsG,
          closeTo(32.5, _tolG),
        );
        expect(_tier(_carbs(65, 30), 'top_off')!.carbsG, closeTo(8.125, _tolG));
      },
    );

    test(
      '11 (amended) + 12: tier windows are +/-12.5 % and sum to the plan band on the whole grid',
      () {
        for (final bw in _bwGrid) {
          for (final t in _tGrid) {
            // Invariant 12 (RULED Xuan, 2026-09-04): the sum identity holds
            // unconditionally — the dur = 30 design_choice restriction that
            // used to pin this test is obsolete.
            final r = _carbs(bw, t);
            final where = 'bw=$bw t=$t';
            var sumLow = 0.0;
            var sumHigh = 0.0;
            for (final tier in r.tiers) {
              expect(
                tier.rangeLowG,
                closeTo(tier.carbsG * 0.875, _exact),
                reason: '$where ${tier.tier} low',
              );
              expect(
                tier.rangeHighG,
                closeTo(tier.carbsG * 1.125, _exact),
                reason: '$where ${tier.tier} high',
              );
              expect(
                tier.rangeLowG <= tier.carbsG + _exact,
                isTrue,
                reason: where,
              );
              expect(
                tier.carbsG <= tier.rangeHighG + _exact,
                isTrue,
                reason: where,
              );
              sumLow += tier.rangeLowG;
              sumHigh += tier.rangeHighG;
            }
            expect(
              sumLow,
              closeTo(r.carbsLowG, _exact),
              reason: '$where sum low',
            );
            expect(
              sumHigh,
              closeTo(r.carbsHighG, _exact),
              reason: '$where sum high',
            );
          }
        }
      },
    );

    test(
      '9: composition is present on every tier and mirrors the tier name',
      () {
        for (final bw in _bwGrid) {
          for (final t in _tGrid) {
            for (final tier in _carbs(bw, t).tiers) {
              expect(tier.composition, tier.tier, reason: 'bw=$bw t=$t');
            }
          }
        }
      },
    );
  });

  // ===========================================================================
  // The legacy map boundary — out of the v2 bundle's scope except for carbs,
  // which must be the v2 engine's numbers rounded exactly once, here.
  //
  // The map's NON-carb fields (protein / fat / water / sodium / meal_type) are
  // covered as characterization tests in
  // `offline_macro_calculator_pre_workout_legacy_map_test.dart`.
  // ===========================================================================

  group('calculatePreWorkoutTargets — legacy map delegates carbs to v2', () {
    test(
      'carbs_g / carbs_low_g / carbs_high_g are the engine values, rounded',
      () {
        for (final hours in <double>[0, 0.5, 1, 1.75, 2, 3, 4, 5]) {
          for (final dur in <double?>[null, 90]) {
            final map = OfflineMacroCalculator.calculatePreWorkoutTargets(
              weightKg: 70,
              hoursBefore: hours,
              isFasted: false,
              workoutDurationMin: dur,
            );
            final engine = OfflineMacroCalculator.calculatePreWorkoutCarbs(
              bodyWeightKg: 70,
              timeBeforeWorkoutMin: hours * 60,
              workoutDurationMin: dur ?? 0.0,
              isFasted: false,
            );
            final where = 'hours=$hours dur=$dur';
            expect(map['carbs_g'], engine.carbsG.round(), reason: where);
            expect(map['carbs_low_g'], engine.carbsLowG.round(), reason: where);
            expect(
              map['carbs_high_g'],
              engine.carbsHighG.round(),
              reason: where,
            );
          }
        }
      },
    );

    test('the 4 g/kg cap survives the map boundary (5 h, 70 kg -> 280 g)', () {
      final map = OfflineMacroCalculator.calculatePreWorkoutTargets(
        weightKg: 70,
        hoursBefore: 5,
        isFasted: false,
      );
      expect(map['carbs_g'], 280);
    });

    test('the v1 0.5 g/kg floor is gone: 0 h before yields 0 g, not 35 g', () {
      final map = OfflineMacroCalculator.calculatePreWorkoutTargets(
        weightKg: 70,
        hoursBefore: 0,
        isFasted: false,
      );
      expect(map['carbs_g'], 0);
    });

    test('fasted zeroes the carb fields and tags the map fasted', () {
      final map = OfflineMacroCalculator.calculatePreWorkoutTargets(
        weightKg: 70,
        hoursBefore: 2,
        isFasted: true,
      );
      expect(map['carbs_g'], 0);
      expect(map['carbs_low_g'], 0);
      expect(map['carbs_high_g'], 0);
      expect(map['meal_type'], 'fasted');
    });
  });

  // ===========================================================================
  // Cross-spec pin (carbs invariant 10 / hydration invariant 10)
  // ===========================================================================

  test('cross-spec pin: TIER_MEAL_MIN == T_REF', () {
    expect(
      OfflineMacroCalculator.tierMealMin,
      OfflineMacroCalculator.tRef,
      reason:
          'CROSS-SPEC PIN BROKEN: pre-workout-carbs.TIER_MEAL_MIN != '
          'pre-workout-hydration.T_REF. See invariant 10 in both specs.',
    );
  });
}
