// The two boundary collapses named in the pre-workout-macros@v2 handoff
// (§5.9 rule 2 — "the class the dashboard already fixed"):
//
//  1. macro_repository.dart — `fluidsMl: preHydration.fluidMl ?? 0`: hydration
//     v6's gate returns `null` ("no statement is made"); collapsing it to 0
//     made a gated plan render "0 oz" (drink nothing). Now `PreRunMacros.fluidsMl`
//     is nullable and the BEFORE card renders "No fluid target for this session".
//  2. macro_generation_service.dart — `weight ?? 70.0` on the offline plan
//     path: every offline plan for a weight-less athlete was a 70-kg plan.
//     Now absent weight throws MissingBodyWeightException (dashboard_assembler
//     precedent, 2026-08-20: "we do NOT invent a number").
//
// Plus the hydrationCheck threading through the repository's generate path so
// all three check values reach the engine (handoff §4).

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/macro_generation_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/pre_workout_before_card_assembler.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/macro_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/offline_macro_calculator.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_before_card_model.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<MacroTargets> _generate(
  MacroRepositoryImpl repo, {
  required double runDistance,
  required double timeBeforeRunMin,
  HydrationCheck hydrationCheck = HydrationCheck.unknown,
}) => repo.generateMacroTargets(
  weight: 63,
  weightUnit: 'kg',
  height: 170,
  heightUnit: 'cm',
  runDistance: runDistance,
  distanceUnit: 'mi',
  runPace: '10:00',
  paceUnit: 'min/mi',
  timeBeforeRunMin: timeBeforeRunMin,
  gutTraining: 'moderate',
  age: 30,
  gender: 'female',
  hydrationCheck: hydrationCheck,
);

void main() {
  late MacroRepositoryImpl repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = MacroRepositoryImpl(
      sharedPreferences: await SharedPreferences.getInstance(),
    );
  });

  group('collapse 1 — gated fluid is null, never 0', () {
    test(
      'a short, cool session (gate path) yields fluidsMl == null through the repository',
      () async {
        // 3 mi at 10:00/mi = 30 min < 60, tempC null → 22 < 30 → gated.
        final targets = await _generate(
          repo,
          runDistance: 3,
          timeBeforeRunMin: 180,
        );
        final pre = targets.preRun;
        expect(targets.metrics.durationMin, lessThan(60));
        expect(pre.hydrationRegime, 'gated');
        expect(pre.fluidsMl, isNull, reason: 'null ≠ 0: no statement is made');
        expect(pre.fluidsLowMl, isNull);
        expect(pre.fluidsHighMl, isNull);
        expect(pre.fluidTiers, isEmpty);
        expect(pre.isHydrationGated, isTrue);
        expect(pre.fluidsFlOz, isNull);

        // The legacy map's water_ml (6.5 ml/kg) must NOT leak through.
        expect(pre.fluidsMl, isNot(closeTo(6.5 * 63, 1)));
      },
    );

    test(
      'the BEFORE card renders "No fluid target for this session" for it — never 0 oz',
      () async {
        final targets = await _generate(
          repo,
          runDistance: 3,
          timeBeforeRunMin: 180,
        );
        final data = PreWorkoutBeforeCardAssembler.assemble(
          preRun: targets.preRun,
          subPhases: const [],
          timeBeforeWorkoutMin: 180,
          bodyWeightKg: 63,
          hydrationCheck: null,
        );
        expect(data.fluids.mode, FuelStatMode.noTarget);
        expect(data.fluids.absentLine, 'No fluid target for this session');
        expect(data.fluids.showFigure, isFalse);
        expect(data.fluids.target, isNull);
        expect(
          data.hydrationCheck,
          isNull,
          reason: 'P1: the check is suppressed',
        );
      },
    );

    test(
      'null survives the cache round-trip (toJson/fromJson) and legacy cached plans still load',
      () async {
        final targets = await _generate(
          repo,
          runDistance: 3,
          timeBeforeRunMin: 180,
        );
        final back = MacroTargets.fromJson(targets.toJson());
        expect(back.preRun.fluidsMl, isNull);
        expect(back.preRun.isHydrationGated, isTrue);

        // A pre-fix cached plan still carries a number: it parses unchanged.
        final legacy = PreRunMacros.fromJson({
          'carbsG': 60.0,
          'proteinG': 10.0,
          'fatCapG': 10.0,
          'fluidsMl': 450.0,
        });
        expect(legacy.fluidsMl, 450.0);
        expect(legacy.isHydrationGated, isFalse);
      },
    );

    test('an ungated session keeps a real target', () async {
      // 9 mi at 10:00/mi = 90 min → cited regime, 7.5 ml/kg.
      final targets = await _generate(
        repo,
        runDistance: 9,
        timeBeforeRunMin: 180,
      );
      expect(targets.preRun.fluidsMl, closeTo(7.5 * 63, 1e-6));
      expect(targets.preRun.hydrationRegime, 'cited');
    });
  });

  group('collapse 2 — absent weight ⇒ absent numbers (no 70-kg stand-in)', () {
    test('requireBodyWeightKg throws on null / non-numeric / non-positive', () {
      expect(
        () => requireBodyWeightKg(null),
        throwsA(isA<MissingBodyWeightException>()),
      );
      expect(
        () => requireBodyWeightKg('70'),
        throwsA(isA<MissingBodyWeightException>()),
      );
      expect(
        () => requireBodyWeightKg(0),
        throwsA(isA<MissingBodyWeightException>()),
      );
      expect(
        () => requireBodyWeightKg(-5.0),
        throwsA(isA<MissingBodyWeightException>()),
      );
      expect(
        () => requireBodyWeightKg(double.nan),
        throwsA(isA<MissingBodyWeightException>()),
      );
    });

    test('a real weight passes through unchanged', () {
      expect(requireBodyWeightKg(63), 63.0);
      expect(requireBodyWeightKg(49.9), 49.9);
    });

    test('the exception names the defect', () {
      expect(
        const MissingBodyWeightException().toString(),
        contains('no 70-kg stand-in'),
      );
    });
  });

  group('hydrationCheck threads through the repository generate path', () {
    test(
      'pale / dark / unknown all reach the engine; only fluidMl moves',
      () async {
        final unknown = await _generate(
          repo,
          runDistance: 9,
          timeBeforeRunMin: 180,
        );
        final pale = await _generate(
          repo,
          runDistance: 9,
          timeBeforeRunMin: 180,
          hydrationCheck: HydrationCheck.pale,
        );
        final dark = await _generate(
          repo,
          runDistance: 9,
          timeBeforeRunMin: 180,
          hydrationCheck: HydrationCheck.dark,
        );
        expect(unknown.preRun.hydrationCheckUsed, 'pale');
        expect(pale.preRun.hydrationCheckUsed, 'pale');
        expect(dark.preRun.hydrationCheckUsed, 'dark');
        expect(
          dark.preRun.fluidsMl,
          closeTo(unknown.preRun.fluidsMl! + 4 * 63, 1e-6),
        );
        expect(pale.preRun.fluidsMl, unknown.preRun.fluidsMl);
        // inv. 8b: band identical across all three.
        for (final t in [pale, dark]) {
          expect(t.preRun.fluidsLowMl, unknown.preRun.fluidsLowMl);
          expect(t.preRun.fluidsHighMl, unknown.preRun.fluidsHighMl);
          expect(t.preRun.carbsG, unknown.preRun.carbsG);
        }
        expect(
          dark.preRun.fluidTiers!.firstWhere((x) => x.tier == 'snack').fluidMl,
          closeTo(4 * 63, 1e-6),
        );
      },
    );

    test('below T_REF the check changes nothing', () async {
      final unknown = await _generate(
        repo,
        runDistance: 9,
        timeBeforeRunMin: 90,
      );
      final dark = await _generate(
        repo,
        runDistance: 9,
        timeBeforeRunMin: 90,
        hydrationCheck: HydrationCheck.dark,
      );
      expect(dark.preRun.fluidsMl, unknown.preRun.fluidsMl);
      expect(dark.preRun.hydrationCheckUsed, 'dark'); // echoed raw below T_REF
    });
  });

  group(
    'the offline-FALLBACK plan path never carries the legacy water / sodium',
    () {
      // MacroGenerationService._computeOfflineMacros → legacy calculateRunningMacros
      // (6.5 ml/kg water, 300/450/600 mg sodium) → overlayPreWorkoutSpecs.
      Map<String, dynamic> legacy({required double distanceMiles}) =>
          OfflineMacroCalculator.calculateRunningMacros(
            weightKg: 63,
            distanceMiles: distanceMiles,
            paceMinPerMile: 10,
            hoursBefore: 3,
            gutTraining: 'moderate',
          );

      test(
        'hydration v6 replaces the legacy water fields; gate → null, never 0',
        () {
          final map = legacy(distanceMiles: 3); // 30 min, cool → gated
          expect(
            map['pre_run_water_ml'],
            isNotNull,
            reason: 'legacy map emits water',
          );
          final overlaid = MacroGenerationService.overlayPreWorkoutSpecs(
            map,
            weightKg: 63,
            hoursBefore: 3,
            tempC: 22,
          );
          expect(overlaid['pre_run_water_ml'], isNull);
          expect(overlaid['pre_run_water_low_ml'], isNull);
          expect(overlaid['pre_run_water_high_ml'], isNull);
          expect(overlaid['pre_run_hydration_regime'], 'gated');
          expect(overlaid['pre_run_fluid_target_basis'], 'none');
          expect(overlaid['pre_run_fluid_tiers'], isEmpty);
          expect(overlaid['pre_run_sodium_mg'], isNull);
          expect(overlaid['pre_run_sodium_low_mg'], isNull);
          expect(overlaid['pre_run_sodium_high_mg'], isNull);
          // Carb figures untouched (no engine number moves), tiers added.
          expect(overlaid['pre_run_carbs_g'], map['pre_run_carbs_g']);
          expect(overlaid['pre_run_carb_tiers'], isA<List>());
          expect(
            (overlaid['pre_run_carb_tiers'] as List).map((t) => t['tier']),
            ['meal', 'snack', 'top_off'],
          );
          expect(overlaid['pre_run_carb_target_basis'], isNotNull);
        },
      );

      test('ungated: v6 7.5 ml/kg, not the legacy 6.5 ml/kg', () {
        final map = legacy(distanceMiles: 9); // 90 min
        final overlaid = MacroGenerationService.overlayPreWorkoutSpecs(
          map,
          weightKg: 63,
          hoursBefore: 3,
          tempC: 22,
        );
        expect(overlaid['pre_run_water_ml'], closeTo(7.5 * 63, 1e-6));
        expect(overlaid['pre_run_water_ml'], isNot(closeTo(6.5 * 63, 1)));
        expect(overlaid['pre_run_hydration_regime'], 'cited');
        expect((overlaid['pre_run_fluid_tiers'] as List).first, {
          'tier': 'meal',
          'fluid_ml': closeTo(7.5 * 63, 1e-6),
        });
        expect(overlaid['pre_run_hydration_check_used'], 'pale');
        expect(overlaid['pre_run_sodium_mg'], isNull);
      });

      test('the overlaid map parses into PreRunMacros with the v6 fields', () {
        final overlaid = MacroGenerationService.overlayPreWorkoutSpecs(
          legacy(distanceMiles: 9),
          weightKg: 63,
          hoursBefore: 3,
          tempC: 22,
          hydrationCheck: HydrationCheck.dark,
        );
        // The same wire reader the server path uses.
        final regime = overlaid['pre_run_hydration_regime'] as String?;
        expect(regime, 'cited');
        expect(overlaid['pre_run_water_ml'], closeTo(7.5 * 63 + 4 * 63, 1e-6));
        expect(ActivityType.running, isNotNull);
      });
    },
  );
}
