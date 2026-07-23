import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

/// Round-trip tests for Phase 2 hydration/sodium derivation fields on
/// [DuringRunMacros], [BrickSegmentMacroTarget], and [BrickTransitionMacroTarget].
///
/// Verifies that `toJson()` → `fromJson()` preserves all new fields so that
/// the values returned by generate-macros-v4 survive JSON storage in
/// `nutritionPlanData` and are correctly read back on plan load.
void main() {
  group('DuringRunMacros hydration derivation round-trip', () {
    test('all derivation fields survive toJson/fromJson', () {
      const original = DuringRunMacros(
        carbRateGPerH: 60.0,
        carbTotalG: 120.0,
        fluidRateMlPerH: 700.0,
        fluidTotalMl: 1400.0,
        sodiumRateMgPerH: 550.0,
        sodiumTotalMg: 1100.0,
        massNormRateGPerH: 0.8,
        // Derivation fields returned by edge function
        effectiveSweatRateLPerH: 1.28,
        sodiumConcMgPerL: 825,
        replacementPercent: 0.60,
        floorMlPerH: 560,
        ceilingMlPerH: 800,
        safetyFlags: ['bw_deficit_2pct'],
        isTested: true,
        // Environment echo fields
        tempC: 28.0,
        humidityPct: 65.0,
        isIndoor: false,
      );

      final json = original.toJson();
      final restored = DuringRunMacros.fromJson(json);

      expect(restored.effectiveSweatRateLPerH, closeTo(1.28, 0.001));
      expect(restored.sodiumConcMgPerL, 825);
      expect(restored.replacementPercent, closeTo(0.60, 0.001));
      expect(restored.floorMlPerH, 560);
      expect(restored.ceilingMlPerH, 800);
      expect(restored.safetyFlags, ['bw_deficit_2pct']);
      expect(restored.isTested, isTrue);
      expect(restored.tempC, closeTo(28.0, 0.001));
      expect(restored.humidityPct, closeTo(65.0, 0.001));
      expect(restored.isIndoor, isFalse);
    });

    test(
      'null derivation fields are handled gracefully (legacy JSON safe)',
      () {
        // Simulate a legacy JSON payload that has no derivation fields.
        final legacyJson = {
          'carbRateGPerH': 50.0,
          'carbTotalG': 100.0,
          'fluidRateMlPerH': 500.0,
          'fluidTotalMl': 1000.0,
          'sodiumRateMgPerH': 400.0,
          'sodiumTotalMg': 800.0,
          'massNormRateGPerH': 0.7,
          'absClampRangeGPerH': [30.0, 60.0],
        };

        final restored = DuringRunMacros.fromJson(legacyJson);

        expect(restored.effectiveSweatRateLPerH, isNull);
        expect(restored.sodiumConcMgPerL, isNull);
        expect(restored.replacementPercent, isNull);
        expect(restored.floorMlPerH, isNull);
        expect(restored.ceilingMlPerH, isNull);
        expect(restored.safetyFlags, isEmpty);
        expect(restored.isTested, isFalse);
        expect(restored.tempC, isNull);
        expect(restored.humidityPct, isNull);
        expect(restored.isIndoor, isNull);
      },
    );

    test('isTested=false is omitted from toJson but restored correctly', () {
      const notTested = DuringRunMacros(
        carbRateGPerH: 50.0,
        carbTotalG: 100.0,
        fluidRateMlPerH: 500.0,
        fluidTotalMl: 1000.0,
        sodiumRateMgPerH: 400.0,
        sodiumTotalMg: 800.0,
        massNormRateGPerH: 0.7,
        isTested: false,
      );

      final json = notTested.toJson();
      // isTested=false should be omitted (conditional include)
      expect(json.containsKey('isTested'), isFalse);

      final restored = DuringRunMacros.fromJson(json);
      expect(restored.isTested, isFalse);
    });
  });

  group('BrickSegmentMacroTarget hydration derivation round-trip', () {
    test('all derivation fields survive toJson/fromJson', () {
      const original = BrickSegmentMacroTarget(
        segmentOrder: 2,
        sport: 'cycling',
        durationMinutes: 60,
        carbsG: 60.0,
        sodiumMg: 600.0,
        waterMl: 800.0,
        // Derivation fields
        effectiveSweatRateLPerH: 1.66,
        sodiumConcMgPerL: 1000,
        replacementPercent: 0.70,
        floorMlPerH: 640,
        ceilingMlPerH: 1200,
        safetyFlags: ['bw_deficit_3pct'],
        isTested: true,
      );

      final json = original.toJson();
      final restored = BrickSegmentMacroTarget.fromJson(json);

      expect(restored.effectiveSweatRateLPerH, closeTo(1.66, 0.001));
      expect(restored.sodiumConcMgPerL, 1000);
      expect(restored.replacementPercent, closeTo(0.70, 0.001));
      expect(restored.floorMlPerH, 640);
      expect(restored.ceilingMlPerH, 1200);
      expect(restored.safetyFlags, ['bw_deficit_3pct']);
      expect(restored.isTested, isTrue);
    });

    test('legacy JSON with no derivation fields loads with safe defaults', () {
      final legacyJson = {
        'segmentOrder': 1,
        'sport': 'running',
        'durationMinutes': 30,
        'carbsG': 30.0,
        'sodiumMg': 300.0,
        'waterMl': 400.0,
      };

      final restored = BrickSegmentMacroTarget.fromJson(legacyJson);

      expect(restored.effectiveSweatRateLPerH, isNull);
      expect(restored.sodiumConcMgPerL, isNull);
      expect(restored.safetyFlags, isEmpty);
      expect(restored.isTested, isFalse);
    });
  });

  group('BrickTransitionMacroTarget hydration derivation round-trip', () {
    test('all derivation fields survive toJson/fromJson', () {
      const original = BrickTransitionMacroTarget(
        transitionName: 'T1',
        carbsG: 0.0,
        sodiumMg: 248.0,
        waterMl: 300.0,
        // Derivation fields
        effectiveSweatRateLPerH: 1.28,
        sodiumConcMgPerL: 825,
        replacementPercent: 0.30,
        floorMlPerH: 0,
        ceilingMlPerH: 800,
        safetyFlags: [],
        isTested: false,
      );

      final json = original.toJson();
      final restored = BrickTransitionMacroTarget.fromJson(json);

      expect(restored.effectiveSweatRateLPerH, closeTo(1.28, 0.001));
      expect(restored.sodiumConcMgPerL, 825);
      expect(restored.replacementPercent, closeTo(0.30, 0.001));
      // floorMlPerH=0 is non-null so it survives
      expect(restored.floorMlPerH, 0);
      expect(restored.ceilingMlPerH, 800);
      expect(restored.safetyFlags, isEmpty);
      expect(restored.isTested, isFalse);
    });
  });

  group('Full MacroTargets JSON round-trip with derivation fields', () {
    test(
      'brickPhaseTargets with derivation fields survive full round-trip',
      () {
        final macroTargets = MacroTargets(
          id: 'test-id-123',
          activityType: ActivityType.brick,
          preRun: const PreRunMacros(
            carbsG: 60.0,
            proteinG: 20.0,
            fatCapG: 10.0,
            fluidsMl: 500.0,
            sodiumMg: 500.0,
          ),
          duringRun: const DuringRunMacros(
            carbRateGPerH: 60.0,
            carbTotalG: 150.0,
            fluidRateMlPerH: 700.0,
            fluidTotalMl: 1750.0,
            sodiumRateMgPerH: 560.0,
            sodiumTotalMg: 1400.0,
            massNormRateGPerH: 0.8,
            effectiveSweatRateLPerH: 1.28,
            sodiumConcMgPerL: 825,
            replacementPercent: 0.60,
            safetyFlags: [],
            isTested: false,
            tempC: 22.0,
            humidityPct: 50.0,
            isIndoor: false,
          ),
          postRun: const PostRunMacros(
            carbsG: 80.0,
            proteinG: 25.0,
            fluidsMl: 600.0,
            sodiumMg: 500.0,
          ),
          metrics: const RunMetrics(
            distanceMi: 31.2,
            distanceKm: 50.2,
            durationH: 2.5,
            durationMin: 150.0,
            speedMph: 12.5,
            caloriesGrossKcal: 1800.0,
            caloriesNetKcal: 1600.0,
            met: 8.0,
          ),
          calculationRule: 'brick-test',
          timestamp: DateTime(2026, 4, 20),
          isUserModified: false,
          brickPhaseTargets: const BrickPhaseTargets(
            duringSegments: [
              BrickSegmentMacroTarget(
                segmentOrder: 1,
                sport: 'cycling',
                durationMinutes: 90,
                carbsG: 90.0,
                sodiumMg: 825.0,
                waterMl: 1050.0,
                effectiveSweatRateLPerH: 1.28,
                sodiumConcMgPerL: 825,
                replacementPercent: 0.60,
                floorMlPerH: 560,
                ceilingMlPerH: 1200,
                safetyFlags: [],
                isTested: false,
              ),
            ],
            transitions: [
              BrickTransitionMacroTarget(
                transitionName: 'T2',
                carbsG: 0.0,
                sodiumMg: 248.0,
                waterMl: 300.0,
                effectiveSweatRateLPerH: 1.28,
                sodiumConcMgPerL: 825,
                replacementPercent: 0.30,
                safetyFlags: [],
                isTested: false,
              ),
            ],
          ),
        );

        final json = macroTargets.toJson();
        final restored = MacroTargets.fromJson(json);

        // DuringRunMacros derivation fields
        expect(
          restored.duringRun.effectiveSweatRateLPerH,
          closeTo(1.28, 0.001),
        );
        expect(restored.duringRun.sodiumConcMgPerL, 825);
        expect(restored.duringRun.tempC, closeTo(22.0, 0.001));
        expect(restored.duringRun.isIndoor, isFalse);

        // BrickSegmentMacroTarget derivation fields
        final segment = restored.brickPhaseTargets!.duringSegments.first;
        expect(segment.effectiveSweatRateLPerH, closeTo(1.28, 0.001));
        expect(segment.sodiumConcMgPerL, 825);
        expect(segment.floorMlPerH, 560);
        expect(segment.ceilingMlPerH, 1200);

        // BrickTransitionMacroTarget derivation fields
        final transition = restored.brickPhaseTargets!.transitions.first;
        expect(transition.effectiveSweatRateLPerH, closeTo(1.28, 0.001));
        expect(transition.sodiumConcMgPerL, 825);
        expect(transition.isTested, isFalse);
      },
    );
  });
}
