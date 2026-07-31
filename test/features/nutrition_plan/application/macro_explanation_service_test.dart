import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/macro_explanation_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrient_transparency_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/resolved_during_target.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  group('MacroExplanationService fluid transparency — scenario map', () {
    final service = MacroExplanationService();

    test(
      'non-tested single-sport run returns map containing Scenario.singleSport',
      () {
        final macroTargets = _sampleMacroTargets(
          durationH: 2.0,
          isTested: false,
        );

        final map = service.getFluidTransparencyData(
          phase: ExplanationPhase.during,
          macroTargets: macroTargets,
          bodyWeightKg: 70,
        );

        expect(map, isNotNull);
        expect(map!.containsKey(Scenario.singleSport), isTrue);
        expect(
          map.containsKey(Scenario.knownRate),
          isFalse,
          reason: 'knownRate should only appear when isTested = true',
        );
      },
    );

    test(
      'tested single-sport run returns map containing both singleSport and knownRate',
      () {
        final macroTargets = _sampleMacroTargets(
          durationH: 2.0,
          isTested: true,
        );

        final map = service.getFluidTransparencyData(
          phase: ExplanationPhase.during,
          macroTargets: macroTargets,
          bodyWeightKg: 70,
        );

        expect(map, isNotNull);
        expect(map!.containsKey(Scenario.singleSport), isTrue);
        expect(
          map.containsKey(Scenario.knownRate),
          isTrue,
          reason: 'knownRate must appear when isTested = true',
        );
        // Each scenario's transparency data must be distinct objects
        expect(map[Scenario.singleSport] != map[Scenario.knownRate], isTrue);
      },
    );

    test(
      'singleSport scenario has different tldrBody from knownRate scenario',
      () {
        final macroTargets = _sampleMacroTargets(
          durationH: 2.0,
          isTested: true,
        );

        final map = service.getFluidTransparencyData(
          phase: ExplanationPhase.during,
          macroTargets: macroTargets,
          bodyWeightKg: 70,
        )!;

        final singleSportBlurb = map[Scenario.singleSport]!.tldrBody;
        final knownRateBlurb = map[Scenario.knownRate]!.tldrBody;

        expect(singleSportBlurb, isNotNull);
        expect(knownRateBlurb, isNotNull);
        expect(
          singleSportBlurb,
          isNot(equals(knownRateBlurb)),
          reason:
              'Each scenario must have distinct explanatory copy so tabs show '
              'different content',
        );
        // Known-rate blurb must mention the test
        expect(knownRateBlurb, contains('sweat test'));
      },
    );

    test(
      'short-workout gate adds Scenario.shortWorkout when duration < 60 and no high temp',
      () {
        final macroTargets = _sampleMacroTargets(
          durationH: 0.75, // 45 min
          isTested: false,
          // tempC = null → treated as mild
        );

        final map = service.getFluidTransparencyData(
          phase: ExplanationPhase.during,
          macroTargets: macroTargets,
          bodyWeightKg: 70,
        );

        expect(map, isNotNull);
        expect(map!.containsKey(Scenario.shortWorkout), isTrue);
        // shortWorkout blurb must mention thirst
        expect(map[Scenario.shortWorkout]!.tldrBody, contains('thirst'));
      },
    );
  });

  group('MacroExplanationService carb transparency', () {
    final service = MacroExplanationService();

    test('uses snapshot recommended range when override is applied', () {
      const durationH = 2.58;
      final macroTargets = _sampleMacroTargets(durationH: durationH);
      const resolved = ResolvedDuringTarget(
        sport: ActivityType.running,
        rateGPerH: 30,
        totalG: 78,
        rangeLowG: 155,
        rangeHighG: 232,
        source: ResolvedDuringTargetSource.snapshotOverrideApplied,
        isOverrideApplied: true,
        isStaleVsSettings: false,
        settingsOverrideRateGPerH: 30,
      );

      final data = service.getCarbTransparencyData(
        phase: ExplanationPhase.during,
        macroTargets: macroTargets,
        bodyWeightKg: 70,
        gutTrainingLabel: 'moderate',
        gutMultiplier: 1.0,
        personalCarbTargetGPerH: 30,
        personalTargetSport: 'running',
        sportLabel: 'Run',
        resolvedDuringTarget: resolved,
      );

      expect(data.targetGrams?.round(), 78);
      expect(data.isOverrideApplied, isTrue);
      expect(data.rangeLow?.round(), 155);
      expect(data.rangeHigh?.round(), 232);
    });

    test('uses snapshot range when override is not applied', () {
      final macroTargets = _sampleMacroTargets(durationH: 2.58);
      const resolved = ResolvedDuringTarget(
        sport: ActivityType.running,
        rateGPerH: 70,
        totalG: 181,
        rangeLowG: 155,
        rangeHighG: 232,
        source: ResolvedDuringTargetSource.snapshot,
        isOverrideApplied: false,
        isStaleVsSettings: true,
        settingsOverrideRateGPerH: 30,
      );

      final data = service.getCarbTransparencyData(
        phase: ExplanationPhase.during,
        macroTargets: macroTargets,
        bodyWeightKg: 70,
        gutTrainingLabel: 'moderate',
        gutMultiplier: 1.0,
        personalCarbTargetGPerH: 30,
        personalTargetSport: 'running',
        sportLabel: 'Run',
        resolvedDuringTarget: resolved,
      );

      expect(data.isOverrideApplied, isFalse);
      expect(data.rangeLow?.round(), 155);
      expect(data.rangeHigh?.round(), 232);
    });
  });
}

MacroTargets _sampleMacroTargets({
  required double durationH,
  bool isTested = false,
  double? tempC,
}) {
  final durationMin = durationH * 60;
  return MacroTargets(
    id: 'sample',
    activityType: ActivityType.running,
    preRun: const PreRunMacros(
      carbsG: 40,
      proteinG: 20,
      fatCapG: 10,
      fluidsMl: 300,
      sodiumMg: 400,
    ),
    duringRun: DuringRunMacros(
      carbRateGPerH: 70,
      carbTotalG: 181,
      fluidRateMlPerH: 500,
      fluidTotalMl: (500 * durationH).round().toDouble(),
      sodiumRateMgPerH: 600,
      sodiumTotalMg: (600 * durationH).round().toDouble(),
      massNormRateGPerH: 1.0,
      absClampRangeGPerH: const [60, 90],
      carbsLowG: 155,
      carbsHighG: 232,
      rawBandLowGPerH: 60,
      rawBandHighGPerH: 90,
      gutMultiplier: 1.0,
      sportCeilingGPerH: 70,
      isTested: isTested,
      tempC: tempC,
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
      durationH: durationH,
      durationMin: durationMin,
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
