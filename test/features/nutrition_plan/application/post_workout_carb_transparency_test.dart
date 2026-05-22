import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/macro_explanation_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

/// Regression for milkmanfunddev-ops/mealvana_endurance#17:
///
/// Before the fix, `getCarbTransparencyData(phase: after)` had no `after`
/// branch and fell through to `_duringSingleSportTransparency`. The After
/// carb card on a long brick (e.g. 48 kg / 4.8 h) therefore rendered the
/// during-workout per-hour formula (60 g/hr × 4.8 h = 288 g) instead of
/// the post-workout recovery formula
/// (`weight × durationMultiplier ≈ 58 g`).
///
/// These tests pin the after-phase routing so the same fallthrough
/// surfaces in CI if it regresses.
void main() {
  group('getCarbTransparencyData phase=after — post-workout formula', () {
    final service = MacroExplanationService();

    test(
      '4.8 h brick at 48 kg renders post-workout target (~58 g), not during total (~288 g)',
      () {
        final macroTargets = _bricklikeTargets(
          weightKg: 48,
          durationH: 4.8,
          // Post-workout: 48 × 1.2 (duration > 2h) × 1.0 (fed) = 57.6 ≈ 58 g
          postCarbsG: 58,
          // During total at 60 g/hr × 4.8 h = 288 g — what the buggy
          // fallthrough would have shown.
          duringCarbTotalG: 288,
        );

        final data = service.getCarbTransparencyData(
          phase: ExplanationPhase.after,
          macroTargets: macroTargets,
          bodyWeightKg: 48,
          gutTrainingLabel: 'standard',
          gutMultiplier: 1.0,
          sportLabel: 'Brick',
        );

        expect(data.phase, 'after',
            reason: 'After card must render with phase="after".');
        expect(data.targetGrams, closeTo(58, 1),
            reason:
                'Post-workout carb target should be ~58 g (48 × 1.2), '
                'not 288 g (during total).');
        expect(data.targetGrams, isNot(closeTo(288, 1)),
            reason:
                'A targetGrams near 288 indicates the old during-fallthrough.');
        expect(data.nutrientLabel, 'Carbs');
        expect(data.sportLabel, 'Post-Workout');
      },
    );

    test(
      'short workout (≤2 h) uses 1.0× duration multiplier',
      () {
        final macroTargets = _bricklikeTargets(
          weightKg: 70,
          durationH: 1.5,
          // 70 × 1.0 × 1.0 = 70 g
          postCarbsG: 70,
          duringCarbTotalG: 90,
        );

        final data = service.getCarbTransparencyData(
          phase: ExplanationPhase.after,
          macroTargets: macroTargets,
          bodyWeightKg: 70,
          gutTrainingLabel: 'standard',
          gutMultiplier: 1.0,
          sportLabel: 'Run',
        );

        expect(data.targetGrams, closeTo(70, 1));
        // tldrBody should reference 1.0 g per kg (not 1.2)
        expect(
          data.tldrBody?.contains('1.0 g of carbs per kg') ?? false,
          isTrue,
          reason:
              'For workouts ≤2 h the standard 1.0× multiplier should appear '
              'in the explanation copy.',
        );
      },
    );
  });
}

MacroTargets _bricklikeTargets({
  required double weightKg,
  required double durationH,
  required double postCarbsG,
  required double duringCarbTotalG,
}) {
  return MacroTargets(
    id: 'sample-after-carb',
    activityType: ActivityType.brick,
    preRun: const PreRunMacros(
      carbsG: 70,
      proteinG: 10,
      fatCapG: 10,
      fluidsMl: 400,
      sodiumMg: 450,
    ),
    duringRun: DuringRunMacros(
      carbRateGPerH: 60,
      carbTotalG: duringCarbTotalG,
      fluidRateMlPerH: 600,
      fluidTotalMl: (600 * durationH).round().toDouble(),
      sodiumRateMgPerH: 700,
      sodiumTotalMg: (700 * durationH).round().toDouble(),
      massNormRateGPerH: 1.0,
      absClampRangeGPerH: const [60, 90],
      rawBandLowGPerH: 60,
      rawBandHighGPerH: 90,
      gutMultiplier: 1.0,
      sportCeilingGPerH: 70,
      isTested: false,
    ),
    postRun: PostRunMacros(
      carbsG: postCarbsG,
      proteinG: weightKg * 0.4,
      fluidsMl: 500,
      sodiumMg: 500,
      carbsLowG: postCarbsG * 0.8,
      carbsHighG: postCarbsG * 1.2,
    ),
    metrics: RunMetrics(
      distanceMi: 45,
      distanceKm: 72,
      durationH: durationH,
      durationMin: durationH * 60,
      paceMinPerMile: 0,
      speedMph: 15,
      caloriesGrossKcal: 2000,
      caloriesNetKcal: 1800,
      met: 8,
    ),
    calculationRule: 'test',
    timestamp: DateTime.utc(2026, 5, 5),
    isUserModified: false,
  );
}
