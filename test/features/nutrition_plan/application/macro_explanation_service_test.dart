import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/macro_explanation_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/resolved_during_target.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
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

MacroTargets _sampleMacroTargets({required double durationH}) {
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
    duringRun: const DuringRunMacros(
      carbRateGPerH: 70,
      carbTotalG: 181,
      fluidRateMlPerH: 500,
      fluidTotalMl: 1290,
      sodiumRateMgPerH: 600,
      sodiumTotalMg: 1548,
      massNormRateGPerH: 1.0,
      absClampRangeGPerH: [60, 90],
      carbsLowG: 155,
      carbsHighG: 232,
      rawBandLowGPerH: 60,
      rawBandHighGPerH: 90,
      gutMultiplier: 1.0,
      sportCeilingGPerH: 70,
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
