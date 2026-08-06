// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/offline_macro_calculator.dart';

/// **CHARACTERIZATION TESTS — NOT SPEC TRUTH.**
///
/// Everything in this file pins the *non-carbohydrate* fields of the legacy
/// `OfflineMacroCalculator.calculatePreWorkoutTargets` map:
/// `protein_g` / `protein_low_g` / `protein_high_g` / `fat_g` /
/// `water_ml` / `water_low_ml` / `water_high_ml` /
/// `sodium_mg` / `sodium_low_mg` / `sodium_high_mg` / `meal_type`.
///
/// **No ratified SSOT governs any of those formulas** — with one exception, the
/// occasion boundaries, which are pinned rather than observed (see below). The
/// `pre-workout-macros@v1` bundle covers fluid (hydration v6), carbohydrate
/// (carbs v2) and sodium (v3) as emitted by the *typed* entry points —
/// `calculatePreWorkoutHydration` and `calculatePreWorkoutCarbs`. This map is a
/// separate, older surface that still feeds food selection, so its behaviour is
/// still shipping and still worth locking down; but the numbers below are
/// **observed**, not ratified. They are here so that a change to them is a
/// *decision*, not an accident.
///
/// A future ruling is expected to change several of them. When it does, update
/// these tests — do not treat a failure here as proof the engine is wrong.
///
/// Two things this file deliberately does NOT do:
///   * It does not assert the carbohydrate fields. Those delegate to carbs v2
///     and are covered in
///     `offline_macro_calculator_pre_workout_carbs_test.dart`.
///   * It does not assert the sodium *engine* position. The map's `sodium_mg`
///     is legacy and non-null; the ratified v3 position (always `null`) applies
///     to `calculatePreWorkoutHydration` and is covered in
///     `offline_macro_calculator_pre_workout_sodium_test.dart`. **These two
///     coexist on purpose and must not be reconciled by editing a test.**
///
/// ---
///
/// ## The occasion boundaries ARE governed — the formulas inside them are not
///
/// One thing in this file is not characterization: **where one occasion ends
/// and the next begins.** The map picks its occasion from `tierMealMin` (120)
/// and `tierTopOffMax` (30) — the same named constants the tier split uses — so
/// at a 120-minute lead the map says `full_meal` exactly when the typed engine
/// opens the `meal` tier, and at a 30-minute lead it says `snack` exactly when
/// the engine opens the `snack` tier.
///
/// It has not always. The map used to branch on `hoursBefore >= 2.5` / `>= 1.0`
/// (150 / 60 min), which put it a full 30 minutes out of step with the tiers it
/// is built from, and out of step with the edge-function mirror. The
/// `occasion boundaries` group below asserts the map and the engine **agree**
/// at both boundaries. Those are the assertions that stop the drift coming
/// back; read them as a pin, not as a record.
///
/// Everything else — the per-kg coefficients, the flat fallbacks, the water
/// multipliers, the sodium bases and bumps — is still purely observed.

/// Every figure here is at 70 kg with the default `sweatSodiumCat: 'average'`
/// and `envLabel: 'normal'`, unless the test says otherwise.
const double _bw = 70.0;

Map<String, dynamic> _map({
  double weightKg = _bw,
  required double hoursBefore,
  bool isFasted = false,
  String sweatSodiumCat = 'average',
  String envLabel = 'normal',
}) {
  return OfflineMacroCalculator.calculatePreWorkoutTargets(
    weightKg: weightKg,
    hoursBefore: hoursBefore,
    isFasted: isFasted,
    sweatSodiumCat: sweatSodiumCat,
    envLabel: envLabel,
  );
}

void main() {
  // ===========================================================================
  // Occasion boundaries — PINNED to the shared tier constants, not observed
  // ===========================================================================

  group('occasion boundaries (pinned to the shared tier constants)', () {
    test('full_meal starts at TIER_MEAL_MIN (120 min), inclusive', () {
      expect(_map(hoursBefore: 2.0)['meal_type'], 'full_meal');
      // 119 minutes: one minute short of the meal window.
      expect(_map(hoursBefore: 119 / 60)['meal_type'], 'snack');
    });

    test('at the 120-min boundary the map and the engine agree on the meal '
        'window', () {
      expect(_map(hoursBefore: 2.0)['meal_type'], 'full_meal');

      // The typed engine at the same lead time: the meal tier is open.
      final engine = OfflineMacroCalculator.calculatePreWorkoutCarbs(
        bodyWeightKg: _bw,
        timeBeforeWorkoutMin: 120,
        workoutDurationMin: 90,
      );
      expect(engine.tiers.first.tier, 'meal');
    });

    test('snack starts at TIER_TOPOFF_MAX (30 min), inclusive', () {
      expect(_map(hoursBefore: 0.5)['meal_type'], 'snack');
      // 29 minutes: only the top-off window is left.
      expect(_map(hoursBefore: 29 / 60)['meal_type'], 'top_up');
    });

    test('at the 30-min boundary the map and the engine agree on the snack '
        'window', () {
      expect(_map(hoursBefore: 0.5)['meal_type'], 'snack');

      final engine = OfflineMacroCalculator.calculatePreWorkoutCarbs(
        bodyWeightKg: _bw,
        timeBeforeWorkoutMin: 30,
        workoutDurationMin: 90,
      );
      expect(engine.tiers.first.tier, 'snack');
    });

    test('the boundaries are the constants themselves, not copies of their '
        'current values', () {
      // Read the constants rather than the literals 120/30, so moving a tier
      // boundary moves this test with it instead of leaving it stale.
      final mealMinHours = OfflineMacroCalculator.tierMealMin / 60.0;
      final snackMinHours = OfflineMacroCalculator.tierTopOffMax / 60.0;

      expect(_map(hoursBefore: mealMinHours)['meal_type'], 'full_meal');
      expect(_map(hoursBefore: mealMinHours - 1 / 60)['meal_type'], 'snack');
      expect(_map(hoursBefore: snackMinHours)['meal_type'], 'snack');
      expect(_map(hoursBefore: snackMinHours - 1 / 60)['meal_type'], 'top_up');
    });

    test('the map agrees with the engine across the whole ratified grid', () {
      // The strongest form of the pin: for every ratified lead time, the map's
      // occasion names the same window as the engine's furthest-out tier.
      const tierForOccasion = <String, String>{
        'full_meal': 'meal',
        'snack': 'snack',
        'top_up': 'top_off',
      };
      for (var t = 0.0; t <= 240.0; t += 15.0) {
        final occasion = _map(hoursBefore: t / 60.0)['meal_type'] as String;
        final engine = OfflineMacroCalculator.calculatePreWorkoutCarbs(
          bodyWeightKg: _bw,
          timeBeforeWorkoutMin: t,
          workoutDurationMin: 90,
        );
        expect(
          tierForOccasion[occasion],
          engine.tiers.first.tier,
          reason: 't=$t: map said $occasion',
        );
      }
    });

    test('the three occasions are exhaustive and ordered', () {
      expect(_map(hoursBefore: 4)['meal_type'], 'full_meal');
      expect(_map(hoursBefore: 2)['meal_type'], 'full_meal');
      expect(_map(hoursBefore: 1)['meal_type'], 'snack');
      expect(_map(hoursBefore: 0.25)['meal_type'], 'top_up');
      expect(_map(hoursBefore: 0)['meal_type'], 'top_up');
    });
  });

  // ===========================================================================
  // Protein and fat, per occasion — CHARACTERIZATION
  // ===========================================================================

  group('protein and fat per occasion (CHARACTERIZATION)', () {
    test('full_meal (>= 120 min): 0.25 g/kg [0.15-0.35], fat 0.4 g/kg', () {
      final m = _map(hoursBefore: 3);
      expect(m['protein_g'], 18); // (70 * 0.25 = 17.5).round()
      expect(m['protein_low_g'], 11); // (70 * 0.15 = 10.5).round()
      expect(m['protein_high_g'], 25); // (70 * 0.35 = 24.5).round()
      expect(m['fat_g'], 28); // (70 * 0.4).round()
    });

    test('snack (30-120 min): 0.15 g/kg [0-0.25], fat a flat 5 g', () {
      final m = _map(hoursBefore: 1);
      expect(m['protein_g'], 11); // (70 * 0.15 = 10.5).round()
      expect(m['protein_low_g'], 0);
      expect(m['protein_high_g'], 18); // (70 * 0.25 = 17.5).round()
      expect(m['fat_g'], 5); // flat, not per-kg
    });

    test(
      'top_up (< 30 min): no protein target, a flat 10 g ceiling, no fat',
      () {
        final m = _map(hoursBefore: 0.25);
        expect(m['protein_g'], 0);
        expect(m['protein_low_g'], 0);
        expect(m['protein_high_g'], 10); // flat, not per-kg
        expect(m['fat_g'], 0);
      },
    );

    test('protein scales with body weight in the two per-kg occasions', () {
      expect(_map(weightKg: 50, hoursBefore: 3)['protein_g'], 13); // 12.5 -> 13
      expect(_map(weightKg: 100, hoursBefore: 3)['protein_g'], 25);
      expect(_map(weightKg: 50, hoursBefore: 1)['protein_g'], 8); // 7.5 -> 8
      expect(_map(weightKg: 100, hoursBefore: 1)['protein_g'], 15);
      // ...and does not in the top-up occasion, which is flat.
      expect(_map(weightKg: 50, hoursBefore: 0.25)['protein_high_g'], 10);
      expect(_map(weightKg: 100, hoursBefore: 0.25)['protein_high_g'], 10);
    });

    test('low <= target <= high for protein in every occasion', () {
      for (final hours in <double>[0, 0.25, 0.5, 1, 1.9, 2, 2.5, 3, 5]) {
        final m = _map(hoursBefore: hours);
        expect(
          m['protein_low_g'] as int,
          lessThanOrEqualTo(m['protein_g'] as int),
          reason: 'hours=$hours',
        );
        expect(
          m['protein_g'] as int,
          lessThanOrEqualTo(m['protein_high_g'] as int),
          reason: 'hours=$hours',
        );
      }
    });
  });

  // ===========================================================================
  // water_* — CHARACTERIZATION
  // ===========================================================================
  //
  // NOTE: this is the LEGACY map's water, not hydration v6. The ratified fluid
  // figures come from `calculatePreWorkoutHydration` and are 7.5 ml/kg with a
  // [5, 12] ml/kg band above T_REF — nothing like the 6.5 / 5.5 / flat-250
  // below. The two surfaces disagree; that disagreement is not this file's to
  // resolve, only to record.

  group('water_* (CHARACTERIZATION — legacy, not hydration v6)', () {
    test('full_meal: 6.5 ml/kg with a [50 %, 150 %] band and floors', () {
      final m = _map(hoursBefore: 3);
      expect(m['water_ml'], 455); // (70 * 6.5).round()
      expect(m['water_low_ml'], 228); // max(200, (455 * 0.5 = 227.5).round())
      expect(m['water_high_ml'], 683); // max(600, (455 * 1.5 = 682.5).round())
    });

    test('snack: 5.5 ml/kg with a [50 %, 150 %] band and floors', () {
      final m = _map(hoursBefore: 1);
      expect(m['water_ml'], 385); // (70 * 5.5).round()
      expect(m['water_low_ml'], 193); // max(150, (192.5).round())
      expect(m['water_high_ml'], 578); // max(500, (577.5).round())
    });

    test('top_up: a flat 250 ml, [0, 500], independent of body weight', () {
      for (final weightKg in <double>[45, 70, 120]) {
        final m = _map(weightKg: weightKg, hoursBefore: 0.25);
        expect(m['water_ml'], 250, reason: 'weightKg=$weightKg');
        expect(m['water_low_ml'], 0, reason: 'weightKg=$weightKg');
        expect(m['water_high_ml'], 500, reason: 'weightKg=$weightKg');
      }
    });

    test('the absolute floors bind for a light athlete', () {
      // 40 kg full_meal: 260 ml, so 0.5x = 130 -> floored to 200, and
      // 1.5x = 390 -> floored to 600.
      final m = _map(weightKg: 40, hoursBefore: 3);
      expect(m['water_ml'], 260);
      expect(m['water_low_ml'], 200);
      expect(m['water_high_ml'], 600);
    });

    test('low <= target <= high for water in every occasion', () {
      for (final hours in <double>[0, 0.25, 0.5, 1, 1.9, 2, 2.5, 3, 5]) {
        final m = _map(hoursBefore: hours);
        expect(
          m['water_low_ml'] as int,
          lessThanOrEqualTo(m['water_ml'] as int),
          reason: 'hours=$hours',
        );
        expect(
          m['water_ml'] as int,
          lessThanOrEqualTo(m['water_high_ml'] as int),
          reason: 'hours=$hours',
        );
      }
    });
  });

  // ===========================================================================
  // sodium_* — CHARACTERIZATION
  // ===========================================================================
  //
  // NOTE: sodium v3 sets NO pre-workout sodium target — but that ruling governs
  // `calculatePreWorkoutHydration`, whose three sodium fields are always null.
  // This legacy map still emits non-null milligrams and still feeds food
  // selection with them. Recorded, not endorsed; a prime candidate for the next
  // ruling.

  group('sodium_* (CHARACTERIZATION — legacy, contradicts sodium v3)', () {
    test('full_meal sums all three occasions: 600 + 300 + 100 = 1000', () {
      final m = _map(hoursBefore: 3);
      expect(m['sodium_mg'], 1000);
      expect(m['sodium_low_mg'], 200);
      expect(m['sodium_high_mg'], 2000);
    });

    test('snack sums the remaining two: 300 + 100 = 400', () {
      final m = _map(hoursBefore: 1);
      expect(m['sodium_mg'], 400);
      expect(m['sodium_low_mg'], 100);
      expect(m['sodium_high_mg'], 1000);
    });

    test('top_up carries the top-up figure alone: 100', () {
      final m = _map(hoursBefore: 0.25);
      expect(m['sodium_mg'], 100);
      expect(m['sodium_low_mg'], 0);
      expect(m['sodium_high_mg'], 400);
    });

    test('sweatSodiumCat moves the base: low 300, medium 450, average 600', () {
      expect(_map(hoursBefore: 3, sweatSodiumCat: 'low')['sodium_mg'], 550);
      expect(_map(hoursBefore: 3, sweatSodiumCat: 'medium')['sodium_mg'], 775);
      expect(
        _map(hoursBefore: 3, sweatSodiumCat: 'average')['sodium_mg'],
        1000,
      );
      // Anything unrecognised falls through to the 'average' base.
      expect(
        _map(hoursBefore: 3, sweatSodiumCat: 'very_high')['sodium_mg'],
        1000,
      );
    });

    test('a hot envLabel adds 100 mg per occasion', () {
      // meal 700 + snack 350 + top-up 200 = 1250.
      expect(_map(hoursBefore: 3, envLabel: 'hot')['sodium_mg'], 1250);
      expect(_map(hoursBefore: 3, envLabel: 'very_hot')['sodium_mg'], 1250);
      expect(_map(hoursBefore: 1, envLabel: 'hot')['sodium_mg'], 550);
      expect(_map(hoursBefore: 0.25, envLabel: 'hot')['sodium_mg'], 200);
      // Anything else is treated as normal.
      expect(_map(hoursBefore: 3, envLabel: 'cold')['sodium_mg'], 1000);
    });

    test('sodium does not scale with body weight', () {
      for (final weightKg in <double>[45, 70, 120]) {
        expect(
          _map(weightKg: weightKg, hoursBefore: 3)['sodium_mg'],
          1000,
          reason: 'weightKg=$weightKg',
        );
      }
    });

    test('the legacy map emits sodium where the typed engine emits null', () {
      // Both surfaces, same athlete, same lead time. This contradiction is the
      // point of the test: it is load-bearing that only ONE of them is ratified.
      expect(_map(hoursBefore: 3)['sodium_mg'], isNotNull);
      final engine = OfflineMacroCalculator.calculatePreWorkoutHydration(
        bodyWeightKg: _bw,
        workoutDurationMin: 90,
        timeBeforeWorkoutMin: 180,
        tempC: 22,
      );
      expect(engine.sodiumMg, isNull);
    });
  });

  // ===========================================================================
  // The fasted map — CHARACTERIZATION
  // ===========================================================================

  group('fasted map (CHARACTERIZATION)', () {
    test('every non-carb field is zero and the occasion is fasted', () {
      final m = _map(hoursBefore: 2, isFasted: true);
      expect(m['protein_g'], 0);
      expect(m['protein_low_g'], 0);
      expect(m['protein_high_g'], 0);
      expect(m['fat_g'], 0);
      expect(m['water_ml'], 0);
      expect(m['water_low_ml'], 0);
      expect(m['water_high_ml'], 0);
      expect(m['sodium_mg'], 0);
      expect(m['sodium_low_mg'], 0);
      expect(m['sodium_high_mg'], 0);
      expect(m['meal_type'], 'fasted');
    });

    test('fasted short-circuits every other input', () {
      for (final hours in <double>[0, 1, 2.5, 5]) {
        for (final env in <String>['normal', 'hot']) {
          final m = _map(hoursBefore: hours, isFasted: true, envLabel: env);
          expect(m['sodium_mg'], 0, reason: 'hours=$hours env=$env');
          expect(m['water_ml'], 0, reason: 'hours=$hours env=$env');
          expect(m['meal_type'], 'fasted', reason: 'hours=$hours env=$env');
        }
      }
    });

    test('the fasted map zeroes sodium — it does NOT make it null', () {
      // Worth pinning explicitly: `0` here is legacy behaviour, and it is the
      // exact conflation sodium v3 rejects for the typed engine. Recorded so a
      // future ruling has something concrete to change.
      final m = _map(hoursBefore: 2, isFasted: true);
      expect(m['sodium_mg'], 0);
      expect(m['sodium_mg'], isNotNull);
    });
  });

  // ===========================================================================
  // Shape — every documented key is present on every path
  // ===========================================================================

  test('the map always carries all 14 keys (CHARACTERIZATION)', () {
    const keys = <String>[
      'carbs_g',
      'carbs_low_g',
      'carbs_high_g',
      'protein_g',
      'protein_low_g',
      'protein_high_g',
      'fat_g',
      'sodium_mg',
      'sodium_low_mg',
      'sodium_high_mg',
      'water_ml',
      'water_low_ml',
      'water_high_ml',
      'meal_type',
    ];
    for (final fasted in <bool>[false, true]) {
      for (final hours in <double>[0, 0.25, 0.5, 1, 1.9, 2, 2.5, 3, 5]) {
        final m = _map(hoursBefore: hours, isFasted: fasted);
        expect(
          m.keys,
          unorderedEquals(keys),
          reason: 'hours=$hours fasted=$fasted',
        );
      }
    }
  });
}
