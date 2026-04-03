import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/resolved_during_target_resolver.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_target_overrides.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  group('ResolvedDuringTargetResolver', () {
    test(
      'single sport: matching override uses snapshot value and is applied',
      () {
        final macroTargets = _sampleMacroTargets(
          activityType: ActivityType.running,
          durationMin: 180,
          carbRateGPerH: 30,
        );
        const overrides = NutritionTargetOverrides(
          duringRun: DuringActivityOverrides(carbRateGPerH: 30),
        );

        final resolved = ResolvedDuringTargetResolver.resolveForSingleSport(
          macroTargets: macroTargets,
          sport: ActivityType.running,
          settingsOverrides: overrides,
        );

        expect(resolved.rateGPerH, 30);
        expect(resolved.totalG, 90);
        expect(resolved.isOverrideApplied, isTrue);
        expect(resolved.isStaleVsSettings, isFalse);
      },
    );

    test('single sport: stale settings do not change snapshot target', () {
      final macroTargets = _sampleMacroTargets(
        activityType: ActivityType.running,
        durationMin: 180,
        carbRateGPerH: 30,
      );
      const overrides = NutritionTargetOverrides(
        duringRun: DuringActivityOverrides(carbRateGPerH: 45),
      );

      final resolved = ResolvedDuringTargetResolver.resolveForSingleSport(
        macroTargets: macroTargets,
        sport: ActivityType.running,
        settingsOverrides: overrides,
      );

      expect(resolved.rateGPerH, 30);
      expect(resolved.totalG, 90);
      expect(resolved.isOverrideApplied, isFalse);
      expect(resolved.isStaleVsSettings, isTrue);
    });

    test('brick segment resolver uses segment snapshot targets', () {
      final macroTargets = _sampleMacroTargets(
        activityType: ActivityType.brick,
        durationMin: 180,
        carbRateGPerH: 90,
        brickSegments: const [
          BrickSegmentMacroTarget(
            segmentOrder: 1,
            sport: 'running',
            durationMinutes: 120,
            carbsG: 60,
            carbsLowG: 50,
            carbsHighG: 70,
            sodiumMg: 800,
            waterMl: 1200,
            carbsRateGPerH: 30,
          ),
        ],
      );
      final segment = macroTargets.brickPhaseTargets!.duringSegments.first;
      const overrides = NutritionTargetOverrides(
        duringRun: DuringActivityOverrides(carbRateGPerH: 30),
      );

      final resolved = ResolvedDuringTargetResolver.resolveForBrickSegment(
        macroTargets: macroTargets,
        segment: segment,
        settingsOverrides: overrides,
      );

      expect(resolved.rateGPerH, 30);
      expect(resolved.totalG, 60);
      expect(resolved.rangeLowG, 50);
      expect(resolved.rangeHighG, 70);
      expect(resolved.isOverrideApplied, isTrue);
    });

    test('90 minute gate keeps stale flag off for short activities', () {
      final macroTargets = _sampleMacroTargets(
        activityType: ActivityType.running,
        durationMin: 60,
        carbRateGPerH: 30,
      );
      const overrides = NutritionTargetOverrides(
        duringRun: DuringActivityOverrides(carbRateGPerH: 45),
      );

      final resolved = ResolvedDuringTargetResolver.resolveForSingleSport(
        macroTargets: macroTargets,
        sport: ActivityType.running,
        settingsOverrides: overrides,
      );

      expect(resolved.isOverrideApplied, isFalse);
      expect(resolved.isStaleVsSettings, isFalse);
    });
  });
}

MacroTargets _sampleMacroTargets({
  required ActivityType activityType,
  required int durationMin,
  required double carbRateGPerH,
  List<BrickSegmentMacroTarget>? brickSegments,
}) {
  final durationH = durationMin / 60.0;
  return MacroTargets(
    id: 'sample',
    activityType: activityType,
    preRun: const PreRunMacros(
      carbsG: 40,
      proteinG: 20,
      fatCapG: 10,
      fluidsMl: 300,
      sodiumMg: 400,
    ),
    duringRun: DuringRunMacros(
      carbRateGPerH: carbRateGPerH,
      carbTotalG: carbRateGPerH * durationH,
      fluidRateMlPerH: 500,
      fluidTotalMl: 500 * durationH,
      sodiumRateMgPerH: 600,
      sodiumTotalMg: 600 * durationH,
      massNormRateGPerH: 0.8,
      absClampRangeGPerH: const [30, 90],
      carbsLowG: 80,
      carbsHighG: 100,
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
      durationMin: durationMin.toDouble(),
      paceMinPerMile: 9,
      speedMph: 6.6,
      caloriesGrossKcal: 1000,
      caloriesNetKcal: 900,
      met: 8,
    ),
    calculationRule: 'test',
    timestamp: DateTime.utc(2026, 1, 1),
    isUserModified: false,
    brickPhaseTargets: brickSegments != null
        ? BrickPhaseTargets(
            duringSegments: brickSegments,
            transitions: const [],
          )
        : null,
  );
}
