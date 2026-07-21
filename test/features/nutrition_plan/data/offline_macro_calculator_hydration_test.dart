// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/offline_macro_calculator.dart';

/// Parity tests between the offline Dart calculator and the edge-function
/// algorithm defined in:
///   supabase/functions/_shared/nutrition/sweat-hydration.ts
///   supabase/functions/generate-macros-v4/single-sport.ts
///   supabase/functions/generate-macros-v4/pre-workout.ts
///   supabase/functions/generate-macros-v4/brick-workout.ts
///
/// Test spec source: docs/sodium_hydration/hydration_sodium_calc_tests.md
///
/// Tolerances:
///   ml/hr values  ±5%
///   sweat rate    ±0.01 L/hr
void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Assert [actual] is within [tolerancePct]% of [expected].
  void expectWithinPct(
    num actual,
    num expected, {
    double tolerancePct = 5.0,
    String? reason,
  }) {
    final tolerance = expected.abs() * tolerancePct / 100.0;
    expect(
      actual,
      closeTo(expected, tolerance == 0 ? 0.5 : tolerance),
      reason: reason,
    );
  }

  // ---------------------------------------------------------------------------
  // Base rate lookup
  // ---------------------------------------------------------------------------

  group('baseSweatRateFromCategory', () {
    test('MEDIUM sweater, 22°C, 50% outdoor → 1.28 L/hr', () {
      final rate = OfflineMacroCalculator.calculateActualSweatRate(
        baseCategory: 'medium',
        tempC: 22,
        humidityPct: 50,
        isIndoor: false,
      );
      expect(rate, closeTo(1.28, 0.01));
    });

    test('LIGHT base rate lookup', () {
      expect(OfflineMacroCalculator.baseSweatRateFromCategory('light'), 0.90);
    });

    test('HEAVY base rate lookup', () {
      expect(OfflineMacroCalculator.baseSweatRateFromCategory('heavy'), 1.66);
    });

    test('unknown category defaults to medium', () {
      expect(OfflineMacroCalculator.baseSweatRateFromCategory('unknown'), 1.28);
    });
  });

  // ---------------------------------------------------------------------------
  // Sodium concentration lookup
  // ---------------------------------------------------------------------------

  group('sodiumConcentrationFromCategory', () {
    test('LOW → 650', () {
      expect(
        OfflineMacroCalculator.sodiumConcentrationFromCategory('low'),
        650,
      );
    });
    test('AVERAGE → 825', () {
      expect(
        OfflineMacroCalculator.sodiumConcentrationFromCategory('average'),
        825,
      );
    });
    test('medium alias → 825', () {
      expect(
        OfflineMacroCalculator.sodiumConcentrationFromCategory('medium'),
        825,
      );
    });
    test('HIGH → 1000', () {
      expect(
        OfflineMacroCalculator.sodiumConcentrationFromCategory('high'),
        1000,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Combined clamps (calculateActualSweatRate)
  // ---------------------------------------------------------------------------

  group('calculateActualSweatRate', () {
    test('combined clamp: HEAVY 50°C 100% indoor → 3.00 L/hr', () {
      // 1.66 × 1.80 × 1.10 × 1.30 = 4.274 → clamped to 3.0
      final rate = OfflineMacroCalculator.calculateActualSweatRate(
        baseCategory: 'heavy',
        tempC: 50,
        humidityPct: 100,
        isIndoor: true,
      );
      expect(rate, closeTo(3.00, 0.01));
    });

    test(
      'known-rate override: 1300 ml/hr, 26°C, 55%, outdoor → ~1.52 L/hr',
      () {
        // base = 1300/1000 = 1.30
        // tempMult = 1.0 + (26-22)*0.04 = 1.16
        // humMult  = 1.0 + max(0,55-50)*0.002 = 1.01
        // indoor   = 1.0
        // raw = 1.30 * 1.16 * 1.01 = 1.5211...  → within [0.3, 3.0]
        final rate = OfflineMacroCalculator.calculateActualSweatRate(
          baseCategory: 'medium',
          tempC: 26,
          humidityPct: 55,
          isIndoor: false,
          knownSweatRateMlPerHour: 1300,
        );
        expect(rate, closeTo(1.52, 0.01));
      },
    );

    test('null temp / humidity defaults to baseline (22°C, 50%)', () {
      final rate = OfflineMacroCalculator.calculateActualSweatRate(
        baseCategory: 'medium',
      );
      expect(rate, closeTo(1.28, 0.01));
    });

    test(
      'temp clamp: LIGHT, −10°C — temp mult clamped to 0.50 → 0.45 L/hr',
      () {
        // raw temp mult = 1.0 + (-10-22)*0.04 = -0.28 → clamped to 0.50
        // effective = 0.90 * 0.50 * 1.0 * 1.0 = 0.45, above overall_min 0.30
        final rate = OfflineMacroCalculator.calculateActualSweatRate(
          baseCategory: 'light',
          tempC: -10,
          humidityPct: 50,
        );
        expect(rate, closeTo(0.45, 0.005));
      },
    );

    test(
      'overall floor clamp: known=0 ml/hr → clamped to 0.3 L/hr minimum',
      () {
        // base = 0/1000 = 0.0; product = 0 → clamped to 0.3
        final rate = OfflineMacroCalculator.calculateActualSweatRate(
          baseCategory: 'medium',
          tempC: 22,
          humidityPct: 50,
          knownSweatRateMlPerHour: 0,
        );
        expect(rate, closeTo(0.3, 0.005));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Replacement % lookup
  // ---------------------------------------------------------------------------

  group('replacementPctForDuration', () {
    test('59 min → 0.30', () {
      expect(OfflineMacroCalculator.replacementPctForDuration(59), 0.30);
    });
    test('89 min → 0.50', () {
      expect(OfflineMacroCalculator.replacementPctForDuration(89), 0.50);
    });
    test('90 min → 0.50 (inclusive boundary)', () {
      expect(OfflineMacroCalculator.replacementPctForDuration(90), 0.50);
    });
    test('140 min → 0.60', () {
      expect(OfflineMacroCalculator.replacementPctForDuration(140), 0.60);
    });
    test('180 min → 0.70', () {
      expect(OfflineMacroCalculator.replacementPctForDuration(180), 0.70);
    });
    test('600 min → 0.80', () {
      expect(OfflineMacroCalculator.replacementPctForDuration(600), 0.80);
    });
    test('240 min → 0.80', () {
      expect(OfflineMacroCalculator.replacementPctForDuration(240), 0.80);
    });
  });

  // ---------------------------------------------------------------------------
  // Single-sport integration tests
  // ---------------------------------------------------------------------------

  group('calculateDuringWorkoutHydration — single sport', () {
    // Example 1 / short-workout gate (45-min, 22°C)
    test(
      'Example 1 / short-workout gate: 45 min, 22°C — recommended=384, floor=0, ceiling=800',
      () {
        // Spec: 70 kg, MEDIUM, 22°C, 45% humidity, running, 45 min
        // Effective rate: 1.28 * 1.0 * (1 + 0.002*max(0,45-50))=1.0 * 1.0 = 1.28
        // Gate: 45 < 60 AND 22 < 30 → triggered
        // recommended = round(1280 * 0.30) = 384
        // floor = 0 (gate path)
        // ceiling = min(800, 1280) = 800
        final result = OfflineMacroCalculator.calculateDuringWorkoutHydration(
          durationMin: 45,
          weightKg: 70,
          sweatRateCategory: 'medium',
          sweatSodiumCat: 'average',
          tempC: 22,
          humidityPct: 45,
          isIndoor: false,
          sport: 'running',
        );

        expectWithinPct(
          result.hydrationRateMlph,
          384,
          reason: 'recommended ml/hr',
        );
        expect(result.floorMlHr, 0, reason: 'floor should be 0 (gate path)');
        expectWithinPct(result.ceilingMlHr, 800, reason: 'ceiling ml/hr');
        expect(
          result.safetyFlags,
          contains('No structured hydration plan needed.'),
          reason: 'gate flag set',
        );
      },
    );

    // Example 2: 90-min long run, cool morning
    test(
      'Example 2: 90-min run, LIGHT, 14°C — recommended=306, floor=0, ceiling=612',
      () {
        // 65 kg, LIGHT, 14°C, 50%, outdoor, running, 90 min
        // effective = 0.90 * clamp(1+(14-22)*0.04, 0.5, 1.8) * 1.0 * 1.0
        //           = 0.90 * clamp(0.68, 0.5, 1.8)
        //           = 0.90 * 0.68 = 0.612 L/hr
        // replacementPct = 0.50
        // pctBased = round(612 * 0.50) = 306
        // floor: total_loss=612*1.5=918; maxDeficit=65000*0.02=1300; raw=(918-1300)/1.5<0 → 0
        // ceiling = min(800, 612) = 612
        final result = OfflineMacroCalculator.calculateDuringWorkoutHydration(
          durationMin: 90,
          weightKg: 65,
          sweatRateCategory: 'light',
          sweatSodiumCat: 'average',
          tempC: 14,
          humidityPct: 50,
          isIndoor: false,
          sport: 'running',
        );

        expectWithinPct(
          result.hydrationRateMlph,
          306,
          reason: 'recommended ml/hr',
        );
        expect(result.floorMlHr, 0, reason: 'floor 0 (loss < 2% BW threshold)');
        expectWithinPct(result.ceilingMlHr, 612, reason: 'ceiling ml/hr');
      },
    );

    // Example 4: 60-min indoor trainer
    test(
      'Example 4: 60-min indoor cycling, MEDIUM — recommended=832, floor=164, ceiling=1200',
      () {
        // 75 kg, MEDIUM, 22°C, 50%, indoor, cycling, 60 min
        // effective = 1.28 * 1.0 * 1.0 * 1.30 = 1.664 L/hr
        // replacementPct = 0.50
        // pctBased = round(1664 * 0.50) = 832
        // floor: total_loss=1664; maxDeficit=75000*0.02=1500; raw=(1664-1500)/1.0=164 → 164
        // ceiling = min(1200, 1664) = 1200
        final result = OfflineMacroCalculator.calculateDuringWorkoutHydration(
          durationMin: 60,
          weightKg: 75,
          sweatRateCategory: 'medium',
          sweatSodiumCat: 'average',
          tempC: 22,
          humidityPct: 50,
          isIndoor: true,
          sport: 'cycling',
        );

        expectWithinPct(
          result.hydrationRateMlph,
          832,
          reason: 'recommended ml/hr',
        );
        expectWithinPct(
          result.floorMlHr,
          164,
          tolerancePct: 5,
          reason: 'floor ml/hr',
        );
        expectWithinPct(result.ceilingMlHr, 1200, reason: 'ceiling ml/hr');
      },
    );

    test('short-workout gate: 45 min, 31°C — gate NOT triggered', () {
      // temp >= 30 bypasses gate
      final result = OfflineMacroCalculator.calculateDuringWorkoutHydration(
        durationMin: 45,
        weightKg: 70,
        sweatRateCategory: 'medium',
        sweatSodiumCat: 'average',
        tempC: 31,
        humidityPct: 50,
        isIndoor: false,
        sport: 'running',
      );
      expect(
        result.safetyFlags,
        isNot(contains('No structured hydration plan needed.')),
        reason: 'gate should not fire at 31°C',
      );
    });

    test('swimming segment → recommended=0, floor=0, ceiling=0', () {
      final result = OfflineMacroCalculator.calculateDuringWorkoutHydration(
        durationMin: 30,
        weightKg: 70,
        sweatRateCategory: 'medium',
        sweatSodiumCat: 'average',
        tempC: 22,
        humidityPct: 50,
        sport: 'swimming',
      );
      expect(result.hydrationRateMlph, 0);
      expect(result.floorMlHr, 0);
      expect(result.ceilingMlHr, 0);
    });

    test('is_tested flag set when known sweat rate provided', () {
      final result = OfflineMacroCalculator.calculateDuringWorkoutHydration(
        durationMin: 90,
        weightKg: 70,
        sweatRateCategory: 'medium',
        sweatSodiumCat: 'average',
        tempC: 22,
        humidityPct: 50,
        sport: 'running',
        knownSweatRateMlPerHour: 1300,
      );
      expect(result.isTested, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Pre-workout hydration tests
  // ---------------------------------------------------------------------------

  group('calculatePreWorkoutHydration', () {
    // Pre-Test 2: Tier 1, 65 kg, 180 min before, 90-min workout, 14°C
    test('Tier 1 (BW 65, 180 min before): fluid=390, sodium=450', () {
      final result = OfflineMacroCalculator.calculatePreWorkoutHydration(
        bodyWeightKg: 65,
        workoutDurationMin: 90,
        timeBeforeWorkoutMin: 180,
        tempC: 14,
      );
      expect(result.gateTriggered, isFalse);
      expect(result.tier, 1);
      expect(result.fluidMl, 390); // 65 * 6
      expect(result.fluidLowMl, 325); // 65 * 5
      expect(result.fluidHighMl, 455); // 65 * 7
      expect(result.sodiumMg, 450);
      expect(result.sodiumLowMg, 300);
      expect(result.sodiumHighMg, 600);
      expect(result.message, isNull);
    });

    // Pre-Test 3: Tier 2, 80 kg, 90 min before, 180-min workout
    test('Tier 2 (BW 80, 90 min before): fluid=250, sodium=150', () {
      final result = OfflineMacroCalculator.calculatePreWorkoutHydration(
        bodyWeightKg: 80,
        workoutDurationMin: 180,
        timeBeforeWorkoutMin: 90,
        tempC: 31,
      );
      expect(result.gateTriggered, isFalse);
      expect(result.tier, 2);
      expect(result.fluidMl, 250);
      expect(result.fluidLowMl, 200);
      expect(result.fluidHighMl, 300);
      expect(result.sodiumMg, 150);
      expect(result.sodiumLowMg, 100);
      expect(result.sodiumHighMg, 200);
      expect(
        result.message,
        contains('consider hydrating well the evening before'),
      );
    });

    test('Gate triggered: 45-min workout, 22°C → all zeros', () {
      final result = OfflineMacroCalculator.calculatePreWorkoutHydration(
        bodyWeightKg: 70,
        workoutDurationMin: 45,
        timeBeforeWorkoutMin: 180,
        tempC: 22,
      );
      expect(result.gateTriggered, isTrue);
      expect(result.fluidMl, 0);
      expect(result.sodiumMg, 0);
      expect(result.message, contains('No structured pre-hydration needed'));
    });

    test('Gate bypassed: 45-min workout, 33°C (hot) → Tier 1', () {
      final result = OfflineMacroCalculator.calculatePreWorkoutHydration(
        bodyWeightKg: 72,
        workoutDurationMin: 45,
        timeBeforeWorkoutMin: 150,
        tempC: 33,
      );
      expect(result.gateTriggered, isFalse);
      expect(result.tier, 1);
      expect(result.fluidMl, 432); // 72 * 6
    });

    test('Tier 3: 5 min before → fluid=0, sodium=0, too-late message', () {
      final result = OfflineMacroCalculator.calculatePreWorkoutHydration(
        bodyWeightKg: 75,
        workoutDurationMin: 120,
        timeBeforeWorkoutMin: 5,
        tempC: 25,
      );
      expect(result.tier, 3);
      expect(result.fluidMl, 0);
      expect(result.sodiumMg, 0);
      expect(result.message, contains('Too late for structured pre-hydration'));
    });

    test('Boundary: exactly 120 min before → Tier 1', () {
      final result = OfflineMacroCalculator.calculatePreWorkoutHydration(
        bodyWeightKg: 70,
        workoutDurationMin: 90,
        timeBeforeWorkoutMin: 120,
        tempC: 20,
      );
      expect(result.tier, 1);
    });

    test('Boundary: exactly 10 min before → Tier 2', () {
      final result = OfflineMacroCalculator.calculatePreWorkoutHydration(
        bodyWeightKg: 70,
        workoutDurationMin: 90,
        timeBeforeWorkoutMin: 10,
        tempC: 20,
      );
      expect(result.tier, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // Brick hydration tests
  // ---------------------------------------------------------------------------

  group('calculateBrickHydration', () {
    // Example 6: bike 90 + run 45, 72 kg, MEDIUM, 27°C, 50%, outdoor
    test(
      'Example 6: bike 90min + run 45min, 72kg, MEDIUM, 27°C — bike=789, T2=300, run=789',
      () {
        // effective = 1.28 * clamp(1+(27-22)*0.04, 0.5, 1.8) * 1.0 * 1.0
        //           = 1.28 * 1.20 = 1.536 L/hr
        // total duration = 135 min → replacementPct = 0.60
        // losses: bike = 1536*1.5 = 2304; run = 1536*0.75 = 1152; total = 3456
        // required = 3456 * 0.60 = 2074; transitions (T2 only) = 300
        // remaining = 1774; drinkable = (90+45)/60 = 2.25 hr
        // recommended = round(1774/2.25) = 789
        // floor: (3456 - 72*1000*0.02)=3456-1440=2016; remaining=2016-300=1716; floor=round(1716/2.25)=763
        // 789 > 763 → no floor override
        // ceilings: bike=min(1200,1536)=1200; run=min(800,1536)=800. 789 < both → no cap.
        final result = OfflineMacroCalculator.calculateBrickHydration(
          weightKg: 72,
          segments: const [
            BrickSegmentInput(sport: 'cycling', order: 0, durationMin: 90),
            BrickSegmentInput(sport: 'running', order: 1, durationMin: 45),
          ],
          sweatRateCategory: 'medium',
          sweatSodiumCat: 'average',
          tempC: 27,
          humidityPct: 50,
          isIndoor: false,
        );

        expect(result.segments.length, 2);
        expect(result.transitions.length, 1);

        final bikeSegment = result.segments.firstWhere(
          (s) => s.sport == 'cycling',
        );
        final runSegment = result.segments.firstWhere(
          (s) => s.sport == 'running',
        );
        final t2 = result.transitions.first;

        expectWithinPct(
          bikeSegment.hydrationRateMlph,
          789,
          reason: 'bike segment rate ml/hr',
        );
        expectWithinPct(
          runSegment.hydrationRateMlph,
          789,
          reason: 'run segment rate ml/hr',
        );
        expect(t2.transitionName, 'T2');
        expect(t2.waterMl, 300);
        expect(result.safetyFlags, isEmpty, reason: 'no flags expected');
      },
    );

    // Redistribution test: HEAVY, 35°C, 70%, bike 60 + run 60, 60 kg
    test(
      'Redistribution: HEAVY 35°C 70% bike+run 60+60 min 60kg — bike=1200, run=800, flags set',
      () {
        // effective: 1.66 * clamp(1+(35-22)*0.04) * clamp(1+(70-50)*0.002) * 1.0
        //          = 1.66 * clamp(1.52,0.5,1.8) * clamp(1.04,1.0,1.1) * 1.0
        //          = 1.66 * 1.52 * 1.04 = 2.625 → within [0.3, 3.0]
        // total = 120 min → replacementPct = 0.60
        // losses: bike=2625*1=2625; run=2625*1=2625; total=5250
        // required=3150; remaining=3150-300=2850; drinkable=2hr
        // recommended=1425; floor: (5250-1200)=4050; remaining=4050-300=3750; floor=1875
        // floor overrides: 1875 > 1425
        // ceilings: bike=min(1200,2625)=1200; run=min(800,2625)=800
        // run floor=1875 > run ceiling=800 → redistribute
        // shortfall=(1875-800)*1hr=1075; bike absorbs 1075→2950 > 1200 → capped at 1200 → redistributionFailed
        final result = OfflineMacroCalculator.calculateBrickHydration(
          weightKg: 60,
          segments: const [
            BrickSegmentInput(sport: 'cycling', order: 0, durationMin: 60),
            BrickSegmentInput(sport: 'running', order: 1, durationMin: 60),
          ],
          sweatRateCategory: 'heavy',
          sweatSodiumCat: 'average',
          tempC: 35,
          humidityPct: 70,
          isIndoor: false,
        );

        final bikeSegment = result.segments.firstWhere(
          (s) => s.sport == 'cycling',
        );
        final runSegment = result.segments.firstWhere(
          (s) => s.sport == 'running',
        );

        expect(
          bikeSegment.hydrationRateMlph,
          1200,
          reason: 'bike capped at GI ceiling=1200',
        );
        expect(
          runSegment.hydrationRateMlph,
          800,
          reason: 'run capped at GI ceiling=800',
        );
        expect(
          result.safetyFlags,
          contains(
            'Even at maximum intake on all segments, you will exceed 2% BW loss.',
          ),
          reason: 'redistribution-failed flag',
        );
      },
    );

    test('T1+T2 transitions: swim→bike→run segments get correct names', () {
      final result = OfflineMacroCalculator.calculateBrickHydration(
        weightKg: 70,
        segments: const [
          BrickSegmentInput(sport: 'swimming', order: 0, durationMin: 25),
          BrickSegmentInput(sport: 'cycling', order: 1, durationMin: 65),
          BrickSegmentInput(sport: 'running', order: 2, durationMin: 50),
        ],
        sweatRateCategory: 'medium',
        sweatSodiumCat: 'average',
        tempC: 26,
        humidityPct: 55,
        knownSweatRateMlPerHour: 1300,
      );

      expect(result.transitions.length, 2);
      expect(result.transitions[0].transitionName, 'T1');
      expect(result.transitions[1].transitionName, 'T2');
      expect(result.transitions[0].waterMl, 300);
      expect(result.transitions[1].waterMl, 300);

      // Swim segment rate should be 0
      final swimSeg = result.segments.firstWhere((s) => s.sport == 'swimming');
      expect(swimSeg.hydrationRateMlph, 0);
    });

    test('is_tested false when no known sweat rate', () {
      final result = OfflineMacroCalculator.calculateBrickHydration(
        weightKg: 70,
        segments: const [
          BrickSegmentInput(sport: 'cycling', order: 0, durationMin: 60),
          BrickSegmentInput(sport: 'running', order: 1, durationMin: 30),
        ],
        sweatRateCategory: 'medium',
        sweatSodiumCat: 'average',
      );
      expect(result.isTested, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Backward-compatibility: existing calculateMacros API still works
  // ---------------------------------------------------------------------------

  group('calculateMacros backward-compat', () {
    test('returns expected map keys with numeric values', () {
      final result = OfflineMacroCalculator.calculateMacros(
        weight: 70,
        weightUnit: 'kg',
        height: 175,
        heightUnit: 'cm',
        runDistance: 10,
        distanceUnit: 'km',
        runPace: '10:00',
        paceUnit: 'min_per_mile',
        timeBeforeRunMin: 60,
        gutTraining: 'moderate',
        age: 35,
        gender: 'male',
      );
      expect(result['success'], isTrue);
      final macros = result['macros'] as Map<String, dynamic>;
      expect(macros['pre_run_carbs_g'], isA<num>());
      expect(macros['during_water_rate_ml_per_h'], isA<num>());
      expect(macros['post_run_protein_g'], isA<num>());
    });
  });

  // ---------------------------------------------------------------------------
  // G8 — Flutter parity for spec Examples 3 & 5 (previously Deno-only)
  // ---------------------------------------------------------------------------

  group('Example 3: 3-h hot bike — floor exceeds ceiling', () {
    test(
      '80 kg HEAVY, 31°C 65% outdoor, bike 180 min → rec=1200, floor>ceiling',
      () {
        final result = OfflineMacroCalculator.calculateDuringWorkoutHydration(
          durationMin: 180,
          weightKg: 80,
          sweatRateCategory: 'heavy',
          sweatSodiumCat: 'high',
          tempC: 31,
          humidityPct: 65,
          isIndoor: false,
          sport: 'cycling',
        );
        // Effective sweat rate: 1.66 × 1.36 × 1.03 ≈ 2.33 L/hr (per spec).
        // Total loss: 2.33 × 3 hr ≈ 6990 ml; max deficit 1600 ml →
        // floor = (6990 - 1600) / 3 ≈ 1797 ml/hr. Cycling GI ceiling
        // = min(1200, 2325) = 1200 ml/hr. floor > ceiling → ceiling wins.
        expectWithinPct(
          result.hydrationRateMlph,
          1200,
          reason: 'capped at cycling GI ceiling',
        );
        expect(result.ceilingMlHr, 1200);
        expect(
          result.floorMlHr,
          greaterThan(result.ceilingMlHr),
          reason: 'floor exceeds ceiling in hot 3-h bike',
        );
        expect(
          result.safetyFlags.any((f) => f.contains('Even at maximum intake')),
          isTrue,
          reason: 'ceiling < floor flag emitted',
        );
        expect(
          result.safetyFlags.any((f) => f.contains('Significant dehydration')),
          isTrue,
          reason: '>3% BW deficit flag emitted',
        );
      },
    );
  });

  group('Example 5: Olympic triathlon with known sweat rate', () {
    test('68 kg, known 1300 ml/hr, swim 25 / bike 65 / run 50 at 26°C → '
        'swim=0, T1=300, bike≈679, T2=300, run≈679', () {
      final result = OfflineMacroCalculator.calculateBrickHydration(
        weightKg: 68,
        segments: const [
          BrickSegmentInput(sport: 'swimming', order: 0, durationMin: 25),
          BrickSegmentInput(sport: 'cycling', order: 1, durationMin: 65),
          BrickSegmentInput(sport: 'running', order: 2, durationMin: 50),
        ],
        sweatRateCategory: 'medium',
        sweatSodiumCat: 'average',
        tempC: 26,
        humidityPct: 55,
        isIndoor: false,
        knownSweatRateMlPerHour: 1300,
      );

      final swim = result.segments.firstWhere(
        (s) => s.sport.toLowerCase() == 'swimming',
      );
      final bike = result.segments.firstWhere(
        (s) => s.sport.toLowerCase() == 'cycling',
      );
      final run = result.segments.firstWhere(
        (s) => s.sport.toLowerCase() == 'running',
      );

      expect(swim.hydrationRateMlph, 0, reason: 'no drinking during swim');
      expectWithinPct(
        bike.hydrationRateMlph,
        679,
        reason: 'bike rate per spec',
      );
      expectWithinPct(run.hydrationRateMlph, 679, reason: 'run rate per spec');

      // Two transitions with fixed 300 ml bolus each.
      expect(result.transitions.length, 2);
      for (final t in result.transitions) {
        expect(t.waterMl, 300, reason: 'T1 / T2 fixed 300 ml bolus per spec');
        // Sodium = 300 ml × 825 mg/L / 1000 = 247 mg (round).
        expectWithinPct(t.sodiumMg, 248, reason: 't sodium');
      }
      expect(result.isTested, isTrue, reason: 'known sweat rate sets isTested');
    });
  });
}
