import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/macro_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MacroRepository keyed cache', () {
    late MacroRepositoryImpl repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repository = MacroRepositoryImpl(sharedPreferences: prefs);
    });

    test('save/get by activityId does not bleed across activities', () async {
      final aTargets = _sampleMacroTargets(id: 'a-targets', carbRate: 30);
      final bTargets = _sampleMacroTargets(id: 'b-targets', carbRate: 45);

      await repository.saveMacroTargetsForActivity('activity-a', aTargets);
      await repository.saveMacroTargetsForActivity('activity-b', bTargets);

      final aCached = await repository.getCachedMacroTargetsForActivity(
        'activity-a',
      );
      final bCached = await repository.getCachedMacroTargetsForActivity(
        'activity-b',
      );

      expect(aCached?.id, 'a-targets');
      expect(bCached?.id, 'b-targets');
      expect(aCached?.duringRun.carbRateGPerH, 30);
      expect(bCached?.duringRun.carbRateGPerH, 45);
    });

    test('migrates legacy global cache once per activityId', () async {
      final legacyA = _sampleMacroTargets(id: 'legacy-a', carbRate: 30);
      await repository.saveMacroTargets(legacyA);

      // Sport guard (issue #18): migration is refused when expectedActivityType
      // is null to prevent silent cross-sport corruption.  Callers that know
      // the activity's sport must pass it to trigger the one-time migration.
      final migratedX1 = await repository.getCachedMacroTargetsForActivity(
        'activity-x',
        expectedActivityType: ActivityType.running,
      );
      expect(migratedX1?.id, 'legacy-a');

      final legacyB = _sampleMacroTargets(id: 'legacy-b', carbRate: 60);
      await repository.saveMacroTargets(legacyB);

      // activity-x remains pinned to the first migrated snapshot.
      final migratedX2 = await repository.getCachedMacroTargetsForActivity(
        'activity-x',
        expectedActivityType: ActivityType.running,
      );
      expect(migratedX2?.id, 'legacy-a');

      // New activity migrates the current legacy snapshot once.
      final migratedY1 = await repository.getCachedMacroTargetsForActivity(
        'activity-y',
        expectedActivityType: ActivityType.running,
      );
      expect(migratedY1?.id, 'legacy-b');

      final legacyC = _sampleMacroTargets(id: 'legacy-c', carbRate: 75);
      await repository.saveMacroTargets(legacyC);

      final migratedY2 = await repository.getCachedMacroTargetsForActivity(
        'activity-y',
        expectedActivityType: ActivityType.running,
      );
      expect(migratedY2?.id, 'legacy-b');
    });

    test('skips legacy migration when expectedActivityType is null', () async {
      final legacy = _sampleMacroTargets(id: 'legacy-a', carbRate: 30);
      await repository.saveMacroTargets(legacy);

      // No expectedActivityType → sport guard refuses the copy to prevent
      // silent cross-sport template corruption (issue #18).
      final result = await repository.getCachedMacroTargetsForActivity(
        'activity-x',
      );
      expect(result, isNull);
    });

    test('skips legacy migration when sport does not match', () async {
      final legacy = _sampleMacroTargets(id: 'legacy-a', carbRate: 30);
      // Saved as running, but caller expects cycling — guard must refuse.
      await repository.saveMacroTargets(legacy);

      final result = await repository.getCachedMacroTargetsForActivity(
        'activity-x',
        expectedActivityType: ActivityType.cycling,
      );
      expect(result, isNull);
    });
  });
}

MacroTargets _sampleMacroTargets({
  required String id,
  required double carbRate,
}) {
  const durationH = 2.0;
  return MacroTargets(
    id: id,
    activityType: ActivityType.running,
    preRun: const PreRunMacros(
      carbsG: 40,
      proteinG: 20,
      fatCapG: 10,
      fluidsMl: 300,
      sodiumMg: 400,
    ),
    duringRun: DuringRunMacros(
      carbRateGPerH: carbRate,
      carbTotalG: carbRate * durationH,
      fluidRateMlPerH: 500,
      fluidTotalMl: 1000,
      sodiumRateMgPerH: 600,
      sodiumTotalMg: 1200,
      massNormRateGPerH: 0.8,
      absClampRangeGPerH: const [30, 90],
    ),
    postRun: const PostRunMacros(
      carbsG: 60,
      proteinG: 25,
      fluidsMl: 400,
      sodiumMg: 500,
    ),
    metrics: const RunMetrics(
      distanceMi: 10,
      distanceKm: 16.09,
      durationH: durationH,
      durationMin: 120,
      paceMinPerMile: 12,
      speedMph: 5,
      caloriesGrossKcal: 1000,
      caloriesNetKcal: 900,
      met: 8,
    ),
    calculationRule: 'test',
    timestamp: DateTime.utc(2026, 1, 1),
    isUserModified: false,
  );
}
