// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/offline_macro_calculator.dart';

/// Parity tests: offline Dart calculator vs generate-macros-v4 edge function.
///
/// Reference:
///   supabase/functions/generate-macros-v4/single-sport.ts
///   supabase/functions/generate-macros-v4/pre-workout.ts
void main() {
  // =========================================================================
  // getDurationCarbBand
  // =========================================================================
  group('getDurationCarbBand', () {
    test('<60 min → [0, 30]', () {
      expect(OfflineMacroCalculator.getDurationCarbBand(45), [0, 30]);
    });
    test('60–89 min → [30, 60]', () {
      expect(OfflineMacroCalculator.getDurationCarbBand(75), [30, 60]);
    });
    test('90–149 min → [45, 60]', () {
      expect(OfflineMacroCalculator.getDurationCarbBand(102), [45, 60]);
    });
    test('150–239 min → [60, 90]', () {
      expect(OfflineMacroCalculator.getDurationCarbBand(180), [60, 90]);
    });
    test('≥240 min → [80, 100]', () {
      expect(OfflineMacroCalculator.getDurationCarbBand(240), [80, 100]);
    });
  });

  // =========================================================================
  // calculateDuringWorkoutCarbRate — cycling 25 mi / 14.7 mph → ~102 min
  // =========================================================================
  group('calculateDuringWorkoutCarbRate — cycling 25mi/14.7mph', () {
    // 25 mi / 14.7 mph = 1.701 h = 102.04 min
    // 90 ≤ 102.04 < 150 → band [45,60], gut=moderate→1.0
    // scaledLow=45, scaledHigh=60 → rate=(45+60)/2=52.5; ceiling=120 → 52.5
    const durationMin = 102.04;

    test('rate is 52.5 g/hr (in [45–60] band, gut=moderate, ceiling=120)', () {
      final result = OfflineMacroCalculator.calculateDuringWorkoutCarbRate(
        durationMin: durationMin,
        activityType: 'cycling',
        gutTraining: 'moderate',
      );
      expect(result['rate_gph'], 52.5);
    });

    test('band_low=45, band_high=60 after gut multiplier', () {
      final result = OfflineMacroCalculator.calculateDuringWorkoutCarbRate(
        durationMin: durationMin,
        activityType: 'cycling',
        gutTraining: 'moderate',
      );
      expect(result['band_low'], 45);
      expect(result['band_high'], 60);
    });

    test('sport_ceiling=120 for cycling', () {
      final result = OfflineMacroCalculator.calculateDuringWorkoutCarbRate(
        durationMin: durationMin,
        activityType: 'cycling',
        gutTraining: 'moderate',
      );
      expect(result['sport_ceiling'], 120);
    });

    test('gut_multiplier=0.7 for low gut training reduces rate', () {
      // band=[45,60], gut=0.7 → scaledLow=31.5→32, scaledHigh=42 → rate=36.75→36.8
      final result = OfflineMacroCalculator.calculateDuringWorkoutCarbRate(
        durationMin: durationMin,
        activityType: 'cycling',
        gutTraining: 'low',
      );
      expect(result['gut_multiplier'], 0.7);
      expect(result['rate_gph'], closeTo(36.8, 0.1));
    });
  });

  // =========================================================================
  // calculateDuringWorkoutCarbRate — cycling long ride 180 min → band [60,90]
  // =========================================================================
  group('calculateDuringWorkoutCarbRate — cycling 180min', () {
    // 150 ≤ 180 < 240 → band [60,90], gut=moderate→1.0 → rate=75
    const durationMin = 180.0;

    test('rate is 75 g/hr (in [60–90] band, gut=moderate)', () {
      final result = OfflineMacroCalculator.calculateDuringWorkoutCarbRate(
        durationMin: durationMin,
        activityType: 'cycling',
        gutTraining: 'moderate',
      );
      expect(result['rate_gph'], 75.0);
    });

    test('band_low=60, band_high=90 after gut multiplier', () {
      final result = OfflineMacroCalculator.calculateDuringWorkoutCarbRate(
        durationMin: durationMin,
        activityType: 'cycling',
        gutTraining: 'moderate',
      );
      expect(result['band_low'], 60);
      expect(result['band_high'], 90);
    });
  });

  // =========================================================================
  // calculateDuringWorkoutCarbRate — running sport ceiling clamp
  // =========================================================================
  group('calculateDuringWorkoutCarbRate — running ceiling clamp', () {
    // ≥240 min band [80,100], gut=high→1.2 → scaledLow=96, scaledHigh=120 → avg=108
    // running ceiling=70 → clamped to 70
    test('running ceiling clamps to 70 g/hr even for high gut 4h+ workout', () {
      final result = OfflineMacroCalculator.calculateDuringWorkoutCarbRate(
        durationMin: 250,
        activityType: 'running',
        gutTraining: 'high',
      );
      expect(result['rate_gph'], 70.0);
      expect(result['sport_ceiling'], 70);
    });

    // Regression (2026-07-22): the band must obey the ceiling like the rate
    // does. Unclamped, a high-gut runner got band 72-108 g/h with the rate
    // capped at 70 — the target sat below its own displayed range and the
    // plan's adherence UI rendered red at 196g vs "202-302g".
    test('band is ceiling-clamped; fully-bound band widens low by 12.5%', () {
      // 168 min running → raw band [60,90], ×1.2 = [72,108]; both ends above
      // the 70 ceiling → clamp to [70,70], then low widens to 70×0.875 = 61.
      final result = OfflineMacroCalculator.calculateDuringWorkoutCarbRate(
        durationMin: 168,
        activityType: 'running',
        gutTraining: 'high',
      );
      expect(result['band_low'], 61);
      expect(result['band_high'], 70);
      final rate = result['rate_gph'] as double;
      expect(rate, 70.0);
      expect(rate >= (result['band_low'] as int), isTrue);
      expect(rate <= (result['band_high'] as int), isTrue);
    });

    test('partially-bound band keeps its real low, clamps only the high', () {
      // 168 min running, moderate gut → scaled band [60,90]; ceiling 70 binds
      // only the top → [60,70]; rate = min(75, 70) = 70, inside the band.
      final result = OfflineMacroCalculator.calculateDuringWorkoutCarbRate(
        durationMin: 168,
        activityType: 'running',
        gutTraining: 'moderate',
      );
      expect(result['band_low'], 60);
      expect(result['band_high'], 70);
      expect(result['rate_gph'], 70.0);
    });

    test('swimming band collapses to [0,0], no widening below zero', () {
      final result = OfflineMacroCalculator.calculateDuringWorkoutCarbRate(
        durationMin: 168,
        activityType: 'swimming',
        gutTraining: 'high',
      );
      expect(result['band_low'], 0);
      expect(result['band_high'], 0);
      expect(result['rate_gph'], 0.0);
    });
  });

  // =========================================================================
  // pre-workout lives in its own dedicated files:
  //   offline_macro_calculator_pre_workout_carbs_test.dart     (carbs v2 +
  //     the calculatePreWorkoutTargets map boundary that delegates to it)
  //   offline_macro_calculator_pre_workout_hydration_test.dart (fluid v6)
  //   offline_macro_calculator_pre_workout_sodium_test.dart    (sodium v3)
  // =========================================================================

  // =========================================================================
  // post-workout carbs
  // =========================================================================
  group('calculatePostWorkoutCarbs', () {
    test('1.5h, 70kg, not fasted → 70g', () {
      expect(
        OfflineMacroCalculator.calculatePostWorkoutCarbs(
          weightKg: 70.0,
          durationH: 1.5,
          isFasted: false,
        ),
        70,
      );
    });

    test('>2h multiplier → ×1.2 → 84g', () {
      expect(
        OfflineMacroCalculator.calculatePostWorkoutCarbs(
          weightKg: 70.0,
          durationH: 2.5,
          isFasted: false,
        ),
        (70 * 1.2).round(),
      );
    });

    test('fasted multiplier → ×1.2 → 84g (for 1.5h)', () {
      expect(
        OfflineMacroCalculator.calculatePostWorkoutCarbs(
          weightKg: 70.0,
          durationH: 1.5,
          isFasted: true,
        ),
        (70 * 1.2).round(),
      );
    });

    test('fasted + >2h → ×1.44 → 101g', () {
      expect(
        OfflineMacroCalculator.calculatePostWorkoutCarbs(
          weightKg: 70.0,
          durationH: 2.5,
          isFasted: true,
        ),
        (70 * 1.2 * 1.2).round(),
      );
    });
  });

  // =========================================================================
  // post-workout protein — fasted adds 0.05/kg
  // =========================================================================
  group('calculatePostWorkoutProtein', () {
    test('1.5h, 70kg, not fasted → 0.30×70=21', () {
      expect(
        OfflineMacroCalculator.calculatePostWorkoutProtein(
          weightKg: 70.0,
          durationH: 1.5,
          isFasted: false,
        ),
        21,
      );
    });

    test('fasted adds 0.05/kg → 0.35×70=24', () {
      expect(
        OfflineMacroCalculator.calculatePostWorkoutProtein(
          weightKg: 70.0,
          durationH: 1.5,
          isFasted: true,
        ),
        (70 * 0.35).round(),
      );
    });

    test('3h not fasted → 0.40×80kg=32', () {
      expect(
        OfflineMacroCalculator.calculatePostWorkoutProtein(
          weightKg: 80.0,
          durationH: 3.0,
          isFasted: false,
        ),
        (80 * 0.40).round(),
      );
    });
  });

  // =========================================================================
  // running MET — conditional formula
  // =========================================================================
  group('runningMETFromPace', () {
    test('10 min/mile (6 mph) → uses high-speed branch (≥4 mph)', () {
      // speedMph=6, speedMPerMin=6×26.8224=160.9344
      // vo2 = 0.2×160.9344+3.5 = 35.687; MET=35.687/3.5 ≈ 10.196
      final met = OfflineMacroCalculator.runningMETFromPace(10.0);
      expect(met, closeTo(10.19, 0.05));
    });

    test('slow walk 20 min/mile (3 mph) → uses low-speed branch (<4 mph)', () {
      // speedMph=3, speedMPerMin=3×26.8224=80.4672
      // vo2 = 0.1×80.4672+3.5 = 11.547; MET=11.547/3.5 ≈ 3.3
      final met = OfflineMacroCalculator.runningMETFromPace(20.0);
      expect(met, closeTo(3.3, 0.1));
    });
  });

  // =========================================================================
  // cycling MET — speed tiers + terrain multiplier
  // =========================================================================
  group('cyclingMETFromSpeed', () {
    // TS: <=16→6, <=19→8, <=22→10, <=25→12, <=30→14, else→16
    test('16 kph flat → 6.0', () {
      expect(OfflineMacroCalculator.cyclingMETFromSpeed(16, 'flat'), 6.0);
    });
    test('19 kph flat → 8.0', () {
      expect(OfflineMacroCalculator.cyclingMETFromSpeed(19, 'flat'), 8.0);
    });
    test('20 kph flat → 10.0 (>19, ≤22 tier)', () {
      expect(OfflineMacroCalculator.cyclingMETFromSpeed(20, 'flat'), 10.0);
    });
    test('20 kph rolling → 10.0×1.1=11.0', () {
      expect(
        OfflineMacroCalculator.cyclingMETFromSpeed(20, 'rolling'),
        closeTo(11.0, 0.01),
      );
    });
    test('25 kph hilly → 12.0×1.25=15.0', () {
      expect(
        OfflineMacroCalculator.cyclingMETFromSpeed(25, 'hilly'),
        closeTo(15.0, 0.01),
      );
    });
    test('31 kph flat → 16.0', () {
      expect(OfflineMacroCalculator.cyclingMETFromSpeed(31, 'flat'), 16.0);
    });
  });

  // =========================================================================
  // swimming MET
  // =========================================================================
  group('swimmingMETFromPace', () {
    test('120 s/100m pool 26°C → 10.0', () {
      expect(
        OfflineMacroCalculator.swimmingMETFromPace(
          pacePer100m: 120,
          poolOrOpenWater: 'pool',
          waterTempC: 26,
        ),
        10.0,
      );
    });
    test('open water adds 1.15×', () {
      expect(
        OfflineMacroCalculator.swimmingMETFromPace(
          pacePer100m: 120,
          poolOrOpenWater: 'open_water',
          waterTempC: 26,
        ),
        closeTo(10.0 * 1.15, 0.01),
      );
    });
    test('cold water (<20°C) adds 1.1×', () {
      expect(
        OfflineMacroCalculator.swimmingMETFromPace(
          pacePer100m: 120,
          poolOrOpenWater: 'pool',
          waterTempC: 18,
        ),
        closeTo(10.0 * 1.1, 0.01),
      );
    });
  });

  // =========================================================================
  // calculateGrossCalories
  // =========================================================================
  test(
    'calculateGrossCalories: MET=10, 70kg, 90min → round(10×3.5×70/200×90)',
    () {
      final expected = (10 * 3.5 * 70 / 200.0 * 90).round();
      expect(
        OfflineMacroCalculator.calculateGrossCalories(
          weightKg: 70,
          durationMin: 90,
          met: 10,
        ),
        expected,
      );
    },
  );

  // =========================================================================
  // calculateNetCalories
  // =========================================================================
  group('calculateNetCalories', () {
    test('running: 1×70×40.234=2816 kcal', () {
      expect(
        OfflineMacroCalculator.calculateNetCalories(
          activityType: 'running',
          weightKg: 70,
          distanceKm: 40.234,
        ),
        (70 * 40.234).round(),
      );
    });

    test('cycling 25 kph → cost=0.35/kg/km', () {
      expect(
        OfflineMacroCalculator.calculateNetCalories(
          activityType: 'cycling',
          weightKg: 70,
          distanceKm: 40.234,
          speedKph: 25,
        ),
        (70 * 40.234 * 0.35).round(),
      );
    });

    test('swimming: 3.5×70×distanceKm', () {
      expect(
        OfflineMacroCalculator.calculateNetCalories(
          activityType: 'swimming',
          weightKg: 70,
          distanceKm: 2.0,
        ),
        (3.5 * 70 * 2.0).round(),
      );
    });
  });

  // =========================================================================
  // Full calculateCyclingMacros integration — 25mi/14.7mph flat
  // =========================================================================
  group('calculateCyclingMacros integration — 25mi/14.7mph flat', () {
    // 25 mi / 14.7 mph ≈ 1.701 h = 102.04 min
    // 90 ≤ 102.04 < 150 → band [45,60], gut=moderate→1.0 → rate=52.5; ceiling=120
    late Map<String, dynamic> result;
    setUp(() {
      result = OfflineMacroCalculator.calculateCyclingMacros(
        weightKg: 70.0,
        distanceMiles: 25.0,
        speedMph: 14.7,
        terrain: 'flat',
        hoursBefore: 2.0,
        isFasted: false,
        gutTraining: 'moderate',
      );
    });

    test('during_rate_g_per_h is 52.5', () {
      expect(result['during_rate_g_per_h'], 52.5);
    });

    test('during_band_low_g_per_h = 45', () {
      expect(result['during_band_low_g_per_h'], 45);
    });

    test('during_band_high_g_per_h = 60', () {
      expect(result['during_band_high_g_per_h'], 60);
    });

    test('pre_run_carbs_g = 140 (2h before, 70kg)', () {
      expect(result['pre_run_carbs_g'], 140);
    });

    test('activity_type = cycling', () {
      expect(result['activity_type'], 'cycling');
    });
  });

  group(
    'calculateCyclingMacros integration — 25mi/14.7mph flat (180-min ride)',
    () {
      // Use 37 miles at same speed to get ~150 min → band [60,90], rate=75
      // 37 / 14.7 * 60 = 151.0 min → band [60,90]
      late Map<String, dynamic> result;
      setUp(() {
        result = OfflineMacroCalculator.calculateCyclingMacros(
          weightKg: 70.0,
          distanceMiles: 37.0,
          speedMph: 14.7,
          terrain: 'flat',
          hoursBefore: 3.0,
          isFasted: false,
          gutTraining: 'moderate',
        );
      });

      test('during_rate_g_per_h is 75.0 for 151min ride', () {
        expect(result['during_rate_g_per_h'], 75.0);
      });

      test('during_band_low_g_per_h = 60', () {
        expect(result['during_band_low_g_per_h'], 60);
      });

      test('during_band_high_g_per_h = 90', () {
        expect(result['during_band_high_g_per_h'], 90);
      });
    },
  );

  // =========================================================================
  // Full calculateRunningMacros integration — fasted
  // =========================================================================
  group('calculateRunningMacros — fasted', () {
    late Map<String, dynamic> result;
    setUp(() {
      result = OfflineMacroCalculator.calculateRunningMacros(
        weightKg: 70.0,
        distanceMiles: 6.0,
        paceMinPerMile: 9.0,
        hoursBefore: 0.5,
        isFasted: true,
        gutTraining: 'moderate',
      );
    });

    test('pre_run_carbs_g = 0 (fasted)', () {
      expect(result['pre_run_carbs_g'], 0);
    });

    test('pre_run_protein_g = 0 (fasted)', () {
      expect(result['pre_run_protein_g'], 0);
    });

    test('pre_run_meal_type = fasted', () {
      expect(result['pre_run_meal_type'], 'fasted');
    });

    test('post_run_carbs_g has fasted multiplier applied', () {
      // 6mi×9min = 54min → not >2h, fasted multiplier ×1.2 → 70×1.0×1.2=84
      expect(result['post_run_carbs_g'], (70 * 1.2).round());
    });
  });
}
