import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/nutrition_plan_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  group('NutritionPlanService.buildV2RequestPayload gut_training_level', () {
    test(
      'always sends gut_training_level=moderate when profile value is null',
      () {
        // Regression for bug 3a3e3fdb: a missing gut_training_level made the
        // V3 edge function skip its formula engine, so during-workout plans
        // missed carb targets. The payload must ALWAYS carry a valid value.
        final payload = NutritionPlanService.buildV2RequestPayload(
          macroTargets: _sampleMacroTargets(),
          hoursBefore: 2,
          weightKg: 70,
          gutTrainingLevel: null,
        );

        expect(payload.containsKey('gut_training_level'), isTrue);
        expect(payload['gut_training_level'], 'moderate');
      },
    );

    test('passes through an explicit gut training level unchanged', () {
      final payload = NutritionPlanService.buildV2RequestPayload(
        macroTargets: _sampleMacroTargets(),
        hoursBefore: 2,
        weightKg: 70,
        gutTrainingLevel: 'high',
      );

      expect(payload['gut_training_level'], 'high');
    });

    test('keeps duration_minutes conditional (absent when null)', () {
      final withoutDuration = NutritionPlanService.buildV2RequestPayload(
        macroTargets: _sampleMacroTargets(),
        hoursBefore: 2,
        weightKg: 70,
      );
      final withDuration = NutritionPlanService.buildV2RequestPayload(
        macroTargets: _sampleMacroTargets(),
        hoursBefore: 2,
        weightKg: 70,
        durationMinutes: 90,
      );

      expect(withoutDuration.containsKey('duration_minutes'), isFalse);
      expect(withDuration['duration_minutes'], 90);
    });
  });
}

MacroTargets _sampleMacroTargets() {
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
      carbTotalG: 105,
      fluidRateMlPerH: 500,
      fluidTotalMl: 750,
      sodiumRateMgPerH: 600,
      sodiumTotalMg: 900,
      massNormRateGPerH: 1.0,
    ),
    postRun: const PostRunMacros(
      carbsG: 60,
      proteinG: 25,
      fluidsMl: 400,
      sodiumMg: 500,
    ),
    metrics: const RunMetrics(
      distanceMi: 10,
      distanceKm: 16,
      durationH: 1.5,
      durationMin: 90,
      paceMinPerMile: 9,
      speedMph: 6.7,
      caloriesGrossKcal: 1000,
      caloriesNetKcal: 900,
      met: 8,
    ),
    calculationRule: 'test',
    timestamp: DateTime.utc(2026, 1, 1),
    isUserModified: false,
  );
}
