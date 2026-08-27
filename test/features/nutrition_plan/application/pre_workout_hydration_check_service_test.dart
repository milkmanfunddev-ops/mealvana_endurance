// The hydration check's write path — the answer→effect map, the recompute
// through the engine seam, the tagged water row, and the exact revert.
//
// Contract: docs/ssot/spec/design/components/hydration-check.md v1 (state
// table, H-2..H-5), surfaces/pre-workout-before-card.md B-3, over
// pre-workout-hydration.md v6 *The urine check* (+PW-021, inv. 8b).
// Interim defaults: deferred-ledger P1 (gated → no write), P2 (client-side
// recompute), P3 (an edited tagged row is still removed on revert).

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/pre_workout_before_card_assembler.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/pre_workout_hydration_check_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/macro_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/offline_macro_calculator.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_before_card_model.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_hydration_check.dart';

import '../pre_workout_before_card_fixtures.dart';

HydrationCheckWrite _answer(
  HydrationCheckAnswer answer, {
  double t = 180,
  double mealWaterCups = 2,
  bool gated = false,
}) => PreWorkoutHydrationCheckService.answer(
  plan: mockPlan(mockSubPhases(t, mealWaterCups: mealWaterCups)),
  targets: mockMacroTargets(
    mockPreRun(t: t, gated: gated),
    gated: gated,
  ),
  answer: answer,
  bodyWeightKg: kMockBodyWeightKg,
  workoutDurationMin: gated ? 45 : kMockDurationMin,
  timeBeforeWorkoutMin: t,
  tempC: 22,
  newFoodId: () => 'hwat-1',
);

List<FoodItemData> _snackRows(HydrationCheckWrite w) => w
    .plan
    .sections
    .first
    .subPhases!
    .firstWhere((sp) => sp.subPhaseType == 'snack')
    .foodItems;

void main() {
  group('answer → hydrationCheck map (four labels, three engine values)', () {
    test('PALE → pale, DARK → dark, NOT_YET → dark, NOT_SURE → unknown', () {
      expect(HydrationCheckAnswer.pale.toEngineCheck(), HydrationCheck.pale);
      expect(HydrationCheckAnswer.dark.toEngineCheck(), HydrationCheck.dark);
      expect(HydrationCheckAnswer.notYet.toEngineCheck(), HydrationCheck.dark);
      expect(
        HydrationCheckAnswer.notSure.toEngineCheck(),
        HydrationCheck.unknown,
      );
      expect(HydrationCheckAnswer.pale.raisesTarget, isFalse);
      expect(HydrationCheckAnswer.notSure.raisesTarget, isFalse);
      expect(HydrationCheckAnswer.dark.raisesTarget, isTrue);
      expect(HydrationCheckAnswer.notYet.raisesTarget, isTrue);
    });

    test(
      'all three engine values reach calculatePreWorkoutHydration through the repository seam',
      () {
        // The seam the offline plan path (macro_repository) and the recompute
        // share — assert each value is applied, not defaulted to `unknown`.
        final base = MacroRepositoryImpl.preWorkoutHydrationFor(
          bodyWeightKg: 63,
          workoutDurationMin: 90,
          timeBeforeWorkoutMin: 180,
          tempC: 22,
        );
        final pale = MacroRepositoryImpl.preWorkoutHydrationFor(
          bodyWeightKg: 63,
          workoutDurationMin: 90,
          timeBeforeWorkoutMin: 180,
          tempC: 22,
          hydrationCheck: HydrationCheck.pale,
        );
        final dark = MacroRepositoryImpl.preWorkoutHydrationFor(
          bodyWeightKg: 63,
          workoutDurationMin: 90,
          timeBeforeWorkoutMin: 180,
          tempC: 22,
          hydrationCheck: HydrationCheck.dark,
        );
        expect(base.hydrationCheckUsed, 'pale'); // unknown → pale above T_REF
        expect(pale.hydrationCheckUsed, 'pale');
        expect(dark.hydrationCheckUsed, 'dark');
        expect(base.fluidMl, closeTo(7.5 * 63, 1e-9));
        expect(pale.fluidMl, base.fluidMl);
        expect(dark.fluidMl, closeTo(7.5 * 63 + 4 * 63, 1e-9));
        // inv. 8b at the seam.
        expect(dark.fluidLowMl, base.fluidLowMl);
        expect(dark.fluidHighMl, base.fluidHighMl);
      },
    );
  });

  group('answer()', () {
    test(
      'DARK: target += 4·BW, snack tier carries the top-up, band untouched, tagged row added',
      () {
        final w = _answer(HydrationCheckAnswer.dark);
        final pre = w.targets.preRun;
        expect(pre.fluidsMl, closeTo(472.5 + 252, 1e-9));
        expect(pre.fluidsLowMl, closeTo(315, 1e-9));
        expect(pre.fluidsHighMl, closeTo(756, 1e-9));
        expect(pre.hydrationCheckUsed, 'dark');
        final snackTier = pre.fluidTiers!.firstWhere((t) => t.tier == 'snack');
        expect(snackTier.fluidMl, closeTo(252, 1e-9));
        // Carbs/sodium untouched.
        expect(pre.carbsG, mockPreRun(t: 180).carbsG);
        expect(pre.carbTiers, mockPreRun(t: 180).carbTiers);
        expect(pre.sodiumMg, isNull);

        final rows = _snackRows(w);
        expect(rows.length, 2);
        final added = rows.last;
        expect(added.id, 'hwat-1');
        expect(added.origin, kHydrationCheckRowOrigin);
        expect(added.name, 'Water (cups)');
        expect(added.nutritionalInfo!.fluids, closeTo(236.588, 1e-6));
        expect(added.nutritionalInfo!.carbs, 0);

        final record = w.plan.preWorkoutHydrationCheck!;
        expect(record.answer, HydrationCheckAnswer.dark);
        expect(record.baselineFluidMl, closeTo(472.5, 1e-9));
        expect(record.addedWaterFoodId, 'hwat-1');
        expect(record.alreadyCovered, isFalse);
      },
    );

    test('NOT_YET has the identical effect to DARK', () {
      final dark = _answer(HydrationCheckAnswer.dark);
      final notYet = _answer(HydrationCheckAnswer.notYet);
      expect(notYet.targets.preRun.fluidsMl, dark.targets.preRun.fluidsMl);
      expect(_snackRows(notYet).length, _snackRows(dark).length);
      expect(
        notYet.plan.preWorkoutHydrationCheck!.answer,
        HydrationCheckAnswer.notYet,
      );
    });

    test('PALE and NOT_SURE: target unchanged, no row, answer recorded', () {
      for (final a in [
        HydrationCheckAnswer.pale,
        HydrationCheckAnswer.notSure,
      ]) {
        final w = _answer(a);
        expect(w.targets.preRun.fluidsMl, closeTo(472.5, 1e-9));
        expect(_snackRows(w).length, 1);
        expect(w.plan.preWorkoutHydrationCheck!.answer, a);
        expect(w.plan.preWorkoutHydrationCheck!.addedWaterFoodId, isNull);
        expect(w.targets.preRun.hydrationCheckUsed, 'pale');
      }
    });

    test(
      'already covered: delivered >= raised target → target rises, NO row',
      () {
        // 6 cups = 1419.5 ml >= 724.5 ml.
        final w = _answer(HydrationCheckAnswer.dark, mealWaterCups: 6);
        expect(w.targets.preRun.fluidsMl, closeTo(724.5, 1e-9));
        expect(_snackRows(w).length, 1);
        expect(w.plan.preWorkoutHydrationCheck!.addedWaterFoodId, isNull);
        expect(w.plan.preWorkoutHydrationCheck!.alreadyCovered, isTrue);
      },
    );

    test('sub-2 h plan: no write at all (the check does not exist)', () {
      final w = _answer(HydrationCheckAnswer.dark, t: 90);
      expect(w.plan.preWorkoutHydrationCheck, isNull);
      expect(w.targets.preRun.fluidsMl, mockPreRun(t: 90).fluidsMl);
    });

    test('gated plan (P1): no write at all', () {
      final w = _answer(HydrationCheckAnswer.dark, gated: true);
      expect(w.plan.preWorkoutHydrationCheck, isNull);
      expect(w.targets.preRun.fluidsMl, isNull);
    });

    test(
      'a second answer without revert is ignored (one record at a time)',
      () {
        final first = _answer(HydrationCheckAnswer.dark);
        final second = PreWorkoutHydrationCheckService.answer(
          plan: first.plan,
          targets: first.targets,
          answer: HydrationCheckAnswer.pale,
          bodyWeightKg: 63,
          workoutDurationMin: 90,
          timeBeforeWorkoutMin: 180,
          tempC: 22,
          newFoodId: () => 'hwat-2',
        );
        expect(
          second.plan.preWorkoutHydrationCheck!.answer,
          HydrationCheckAnswer.dark,
        );
        expect(second.targets.preRun.fluidsMl, first.targets.preRun.fluidsMl);
      },
    );
  });

  group('revert() — H-3 / H-4', () {
    test(
      'target back to baseline, tiers back, tagged row gone, record cleared',
      () {
        final w = _answer(HydrationCheckAnswer.dark);
        final r = PreWorkoutHydrationCheckService.revert(
          plan: w.plan,
          targets: w.targets,
        );
        expect(r.plan.preWorkoutHydrationCheck, isNull);
        expect(r.targets.preRun.fluidsMl, closeTo(472.5, 1e-9));
        expect(r.targets.preRun.hydrationCheckUsed, 'pale');
        expect(
          r.targets.preRun.fluidTiers!
              .firstWhere((t) => t.tier == 'snack')
              .fluidMl,
          0,
        );
        expect(_snackRows(r).map((f) => f.id), ['rx']);
        // Everything else byte-identical to the original targets.
        final original = mockPreRun(t: 180);
        expect(r.targets.preRun.carbsG, original.carbsG);
        expect(r.targets.preRun.fluidsLowMl, original.fluidsLowMl);
        expect(r.targets.preRun.fluidsHighMl, original.fluidsHighMl);
      },
    );

    test('P3: an EDITED tagged row is still removed on revert', () {
      final w = _answer(HydrationCheckAnswer.dark);
      // Athlete steps the water row to 3 cups.
      final edited = w.plan.copyWith(
        sections: w.plan.sections.map((s) {
          if (!s.hasSubPhases) return s;
          return s.copyWith(
            subPhases: s.subPhases!
                .map(
                  (sp) => sp.copyWith(
                    foodItems: sp.foodItems
                        .map(
                          (f) => f.id == 'hwat-1'
                              ? FoodItemData(
                                  id: f.id,
                                  name: f.name,
                                  quantity: '3 cups Water',
                                  origin: f.origin,
                                  nutritionalInfo: const NutritionalInfo(
                                    fluids: 236.588 * 3,
                                  ),
                                )
                              : f,
                        )
                        .toList(),
                  ),
                )
                .toList(),
          );
        }).toList(),
      );
      final r = PreWorkoutHydrationCheckService.revert(
        plan: edited,
        targets: w.targets,
      );
      expect(_snackRows(r).map((f) => f.id), ['rx']);
    });

    test('revert with no record is a no-op', () {
      final plan = mockPlan(mockSubPhases(180));
      final targets = mockMacroTargets(mockPreRun(t: 180));
      final r = PreWorkoutHydrationCheckService.revert(
        plan: plan,
        targets: targets,
      );
      expect(identical(r.plan, plan), isTrue);
      expect(identical(r.targets, targets), isTrue);
    });
  });

  group('assembler — the surface arithmetic (B-1, B-2, B-5, F-1)', () {
    PreWorkoutBeforeCardData data(
      double t, {
      bool gated = false,
      bool fasted = false,
    }) => PreWorkoutBeforeCardAssembler.assemble(
      preRun: mockPreRun(t: t, gated: gated, fasted: fasted),
      subPhases: mockSubPhases(t),
      timeBeforeWorkoutMin: t,
      bodyWeightKg: 63,
      hydrationCheck: null,
    );

    test(
      'B-2 membership: ≥2h meal·snack·top-off; 30–2h snack·top-off; <30 top-off',
      () {
        expect(data(180).feedings.map((f) => f.tier.engineName), [
          'meal',
          'snack',
          'top_off',
        ]);
        expect(data(120).feedings.map((f) => f.tier.engineName), [
          'meal',
          'snack',
          'top_off',
        ]);
        expect(data(90).feedings.map((f) => f.tier.engineName), [
          'snack',
          'top_off',
        ]);
        expect(data(30).feedings.map((f) => f.tier.engineName), [
          'snack',
          'top_off',
        ]);
        expect(data(20).feedings.map((f) => f.tier.engineName), ['top_off']);
        expect(data(0).feedings.map((f) => f.tier.engineName), ['top_off']);
      },
    );

    test('B-5 traceability: figures are engine fields in display units', () {
      final d = data(180);
      final pre = mockPreRun(t: 180);
      expect(d.carbs.target, pre.carbsG.round());
      expect(d.carbs.bandLow, pre.carbsLowG!.round());
      expect(d.carbs.bandHigh, pre.carbsHighG!.round());
      expect(d.fluids.target, 16); // round(472.5 / 29.5735)
      expect(d.fluids.bandLow, 10); // floor(315 / 29.5735)
      expect(d.fluids.bandHigh, 26); // ceil(756 / 29.5735)
      expect(d.feedings.first.fluidOz, 16); // meal tier fluid
      expect(d.feedings[1].fluidOz, isNull); // snack carries none (pale)
      expect(d.feedings[2].fluidOz, isNull);
    });

    test(
      'B-1 delivered = Σ rows; sodium is the sum of rows, never a target',
      () {
        final d = data(180);
        expect(d.carbs.delivered, 89);
        expect(d.fluids.delivered, 16);
        expect(d.sodium.delivered, 310);
        expect(d.sodium.target, isNull);
        expect(d.sodium.showBand, isFalse);
        expect(d.feedings.first.carbsDelivered, 52);
        expect(d.feedings[1].carbsDelivered, 24);
        expect(d.feedings[2].carbsDelivered, 13);
      },
    );

    test(
      'F-1: gated → NO_TARGET fluids; fasted → NONE carbs; t = 0 → real 0 g, band suppressed',
      () {
        final g = data(180, gated: true);
        expect(g.fluids.mode, FuelStatMode.noTarget);
        expect(g.fluids.absentLine, 'No fluid target for this session');
        expect(g.fluids.showFigure, isFalse);
        expect(g.fluids.showBand, isFalse);
        expect(g.carbs.mode, FuelStatMode.targeted);
        expect(g.hydrationCheck, isNull, reason: 'P1');
        expect(g.feedings.every((f) => f.fluidOz == null), isTrue);

        final f = data(180, fasted: true);
        expect(f.carbs.mode, FuelStatMode.none);
        expect(f.carbs.absentLine, 'No carbs this session');
        expect(f.carbs.showBand, isFalse);
        expect(f.fluids.mode, FuelStatMode.targeted);
        expect(f.feedings.every((c) => c.carbsDelivered == null), isTrue);

        final z = data(0);
        expect(z.carbs.mode, FuelStatMode.targeted);
        expect(z.carbs.delivered, 0);
        expect(z.carbs.bandLow, 0);
        expect(z.carbs.bandHigh, 0);
        expect(z.carbs.showBand, isFalse);
        expect(z.carbs.absentLine, isNull);
        expect(z.feedings.single.fluidOz, 8); // f(0) = 250 ml → 8 oz
      },
    );

    test(
      'the check exists iff t >= T_REF and not gated; hosted by the SNACK card',
      () {
        expect(data(180).hydrationCheck, isNotNull);
        expect(data(120).hydrationCheck, isNotNull);
        expect(data(119).hydrationCheck, isNull);
        expect(data(90).hydrationCheck, isNull);
        expect(data(180, gated: true).hydrationCheck, isNull);
        expect(data(180).feedings[1].hostsHydrationCheck, isTrue);
        expect(data(180).feedings[0].hostsHydrationCheck, isFalse);
        expect(data(180).hydrationCheck!.targetOz, 16);
        expect(data(180).hydrationCheck!.answer, HydrationCheckAnswer.none);
      },
    );

    test(
      'a sub-phase carrying foods outside the engine tiers is still shown',
      () {
        // Never hide the athlete's food.
        final d = PreWorkoutBeforeCardAssembler.assemble(
          preRun: mockPreRun(t: 90),
          subPhases: mockSubPhases(180),
          timeBeforeWorkoutMin: 90,
          bodyWeightKg: 63,
          hydrationCheck: null,
        );
        expect(d.feedings.map((f) => f.tier.engineName), [
          'meal',
          'snack',
          'top_off',
        ]);
      },
    );

    test(
      'no targets at all (legacy plan): feedings from sub-phases, no bands',
      () {
        final d = PreWorkoutBeforeCardAssembler.assemble(
          preRun: null,
          subPhases: mockSubPhases(180),
          timeBeforeWorkoutMin: 180,
          bodyWeightKg: null,
          hydrationCheck: null,
        );
        expect(d.feedings.length, 3);
        expect(d.carbs.showBand, isFalse);
        expect(d.fluids.showBand, isFalse);
        expect(d.fluids.mode, FuelStatMode.targeted);
        expect(d.hydrationCheck, isNull);
        expect(d.feedings[1].title, 'Pre-Workout Snack');
      },
    );
  });

  group('regression — a server-computed band at a different lb→kg factor', () {
    test(
      'still writes (2026-08-26: a hard inv-8b assert swallowed the first real answer)',
      () {
        // 161 lb: server used 0.453592 (73.028 kg), the device recomputes at
        // 0.45359237 (73.028 kg) — the bands differ by ~0.1 ml; the old
        // 1e-3 assert threw inside the tap and nothing was written.
        final serverPre = serverPreRun(t: 135, weightLb: 161, durationMin: 168);
        final w = PreWorkoutHydrationCheckService.answer(
          plan: mockPlan(mockSubPhases(135)),
          targets: mockMacroTargets(serverPre),
          answer: HydrationCheckAnswer.dark,
          bodyWeightKg: 161 * kDeviceKgPerLb,
          workoutDurationMin: 168,
          timeBeforeWorkoutMin: 135,
          tempC: null,
          newFoodId: () => 'hwat-1',
        );
        expect(
          w.plan.preWorkoutHydrationCheck?.answer,
          HydrationCheckAnswer.dark,
        );
        expect(
          w.targets.preRun.fluidsMl,
          closeTo(serverPre.fluidsMl! + 4 * 161 * kDeviceKgPerLb, 0.05),
        );
        // The STORED band is what survives, byte for byte.
        expect(w.targets.preRun.fluidsLowMl, serverPre.fluidsLowMl);
        expect(w.targets.preRun.fluidsHighMl, serverPre.fluidsHighMl);
      },
    );
  });
}
