import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/macro_explanation_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrient_transparency_data.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

/// Regression for milkmanfunddev-ops/mealvana_endurance#16:
///
/// For a low-bodyweight athlete (47.6 kg ≈ 105 lb) scheduled with a 4 h
/// pre-workout window, the edge function emits Tier 1 with `fluidsMl =
/// 286` (BW × 6 ml). Before the fix, the Flutter explanation service
/// inferred tier from the magnitude (`fluidsMl <= 300`) and rendered
/// "PRE-WORKOUT TIER 2" copy, mismatched against the Tier 1 numbers.
///
/// The fix threads `pre_run_hydration_tier` through `PreRunMacros` and
/// branches the explanation on the explicit tier. These tests pin the
/// boundary case so a regression to the old heuristic surfaces in CI.
void main() {
  group('PreWorkout fluid transparency — explicit hydrationTier wins', () {
    final service = MacroExplanationService();

    test(
      '47.6 kg, hydrationTier=1, fluidsMl=286 renders TIER 1 (not TIER 2)',
      () {
        final macroTargets = _sampleMacroTargetsWithPreRun(
          preRun: const PreRunMacros(
            carbsG: 190,
            proteinG: 10,
            fatCapG: 10,
            fluidsMl: 286,
            sodiumMg: 450,
            fluidsLowMl: 238,
            fluidsHighMl: 333,
            hydrationTier: 1,
          ),
        );

        final map = service.getFluidTransparencyData(
          phase: ExplanationPhase.before,
          macroTargets: macroTargets,
          bodyWeightKg: 47.6,
        );

        expect(map, isNotNull);
        final data = map![Scenario.singleSport]!;

        final headers =
            data.calculationSections.map((s) => s.header).toList();
        expect(
          headers,
          contains('PRE-WORKOUT TIER 1'),
          reason:
              'Explicit hydrationTier=1 must drive Tier 1 calculation copy '
              'even when fluidsMl ≤ 300 (the old fluid-magnitude heuristic).',
        );
        expect(
          headers,
          isNot(contains('PRE-WORKOUT TIER 2')),
          reason:
              'Tier 2 markup would mislabel a body-weight-scaled Tier 1 '
              'recommendation for low-bodyweight athletes.',
        );
      },
    );

    test(
      'hydrationTier=2 with fluidsMl=250 renders TIER 2',
      () {
        final macroTargets = _sampleMacroTargetsWithPreRun(
          preRun: const PreRunMacros(
            carbsG: 0,
            proteinG: 0,
            fatCapG: 0,
            fluidsMl: 250,
            sodiumMg: 150,
            fluidsLowMl: 200,
            fluidsHighMl: 300,
            hydrationTier: 2,
          ),
        );

        final map = service.getFluidTransparencyData(
          phase: ExplanationPhase.before,
          macroTargets: macroTargets,
          bodyWeightKg: 70,
        )!;

        final headers = map[Scenario.singleSport]!
            .calculationSections
            .map((s) => s.header)
            .toList();
        expect(headers, contains('PRE-WORKOUT TIER 2'));
      },
    );

    test(
      'legacy plan without hydrationTier still falls back to fluid heuristic',
      () {
        // Older cached plans have no hydrationTier — service must remain
        // backwards compatible (uses the fluid-magnitude heuristic).
        final macroTargets = _sampleMacroTargetsWithPreRun(
          preRun: const PreRunMacros(
            carbsG: 280,
            proteinG: 14,
            fatCapG: 14,
            fluidsMl: 420,
            sodiumMg: 450,
            fluidsLowMl: 350,
            fluidsHighMl: 490,
            // hydrationTier intentionally null
          ),
        );

        final map = service.getFluidTransparencyData(
          phase: ExplanationPhase.before,
          macroTargets: macroTargets,
          bodyWeightKg: 70,
        )!;

        final headers = map[Scenario.singleSport]!
            .calculationSections
            .map((s) => s.header)
            .toList();
        // 420 ml > 300 → legacy heuristic resolves to Tier 1.
        expect(headers, contains('PRE-WORKOUT TIER 1'));
      },
    );
  });
}

MacroTargets _sampleMacroTargetsWithPreRun({required PreRunMacros preRun}) {
  return MacroTargets(
    id: 'sample',
    activityType: ActivityType.running,
    preRun: preRun,
    duringRun: const DuringRunMacros(
      carbRateGPerH: 70,
      carbTotalG: 140,
      fluidRateMlPerH: 500,
      fluidTotalMl: 1000,
      sodiumRateMgPerH: 600,
      sodiumTotalMg: 1200,
      massNormRateGPerH: 1.0,
      absClampRangeGPerH: [60, 90],
      rawBandLowGPerH: 60,
      rawBandHighGPerH: 90,
      gutMultiplier: 1.0,
      sportCeilingGPerH: 70,
      isTested: false,
    ),
    postRun: const PostRunMacros(
      carbsG: 60,
      proteinG: 25,
      fluidsMl: 400,
      sodiumMg: 500,
    ),
    metrics: RunMetrics(
      distanceMi: 20,
      distanceKm: 32,
      durationH: 2.0,
      durationMin: 120,
      paceMinPerMile: 7.75,
      speedMph: 7.7,
      caloriesGrossKcal: 1000,
      caloriesNetKcal: 900,
      met: 8,
    ),
    calculationRule: 'test',
    timestamp: DateTime.utc(2026, 1, 1),
    isUserModified: false,
  );
}
