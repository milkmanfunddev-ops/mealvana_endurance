// §6(e) pick-time solvent feasibility — the S29 regression pair (Dart half).
//
// Twin test: supabase/functions/_shared/nutrition/during-rule-solver.solvent.test.ts
// runs the SAME fixture through the TS rule solver and pins the SAME
// invariant (§8 — one rule, both engines). Fixture = the run/run brick
// segment from Lee's 2026-09-03 screenshot (reproduced live on dev): 60-min
// run, carbs 53 / sodium 331 / fluid 401 [341, 461], real catalog numbers.
//
// Invariant: every plate the during solver emits leaves the §6(e) backstop
// FEASIBLE — declared solvent requirement ≤ plain water + remaining fluid
// headroom — and the pairing pass then finishes without a fluid-ceiling
// conflict, so a concentrated mix can never ship without the water to
// dissolve it. (The Dart weighted pick is deterministic, so one run per
// seedable arrangement suffices; the pool is also permuted to vary picks.)

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/client_plan/client_during_phase_solver.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/client_plan/electrolyte_water_pairing.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/solver_food.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/solver_types.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

SolverFood _food({
  required String id,
  required String productType,
  double carbs = 0,
  double sodium = 0,
  double fluid = 0,
  int calories = 0,
  double minServings = 0.5,
  int maxServings = 10,
  bool indivisible = false,
  bool liquid = false,
  double? solventMinMl,
}) {
  return SolverFood(
    id: id,
    name: id,
    displayName: id,
    carbsG: carbs,
    proteinG: 0,
    fatG: 0,
    sodiumMg: sodium,
    fluidMl: fluid,
    calories: calories,
    maxServings: maxServings,
    preferenceScore: 50,
    minServings: minServings,
    solventMinMl: solventMinMl,
    isIndivisible: indivisible,
    isLiquid: liquid,
    productType: productType,
  );
}

void main() {
  // Real catalog shapes (dev rows, 2026-09-03) — the TS twin's POOL.
  final pool = <SolverFood>[
    _food(
        id: 'carb_drink_mix',
        productType: 'drink_mix',
        carbs: 60,
        sodium: 160,
        calories: 240,
        liquid: true,
        solventMinMl: 475),
    _food(
        id: 'energy_gel',
        productType: 'gel',
        carbs: 25,
        sodium: 55,
        fluid: 20,
        calories: 100,
        minServings: 1,
        maxServings: 15,
        indivisible: true,
        solventMinMl: 150),
    _food(
        id: 'energy_chews',
        productType: 'chew',
        carbs: 25,
        sodium: 80,
        calories: 100,
        minServings: 1,
        indivisible: true),
    _food(
        id: 'sports_drink',
        productType: 'sports_drink',
        carbs: 15,
        sodium: 100,
        fluid: 240,
        calories: 60,
        maxServings: 20,
        liquid: true),
    _food(
        id: 'water',
        productType: 'beverage',
        fluid: 240,
        maxServings: 14,
        liquid: true),
    _food(
        id: 'electrolyte_capsule',
        productType: 'supplement',
        sodium: 190,
        minServings: 1,
        maxServings: 8,
        indivisible: true),
  ];

  const targets = SolverTargets(
    carbsG: 53,
    carbsLowG: 47.7,
    carbsHighG: 58.3,
    sodiumMg: 331,
    sodiumLowMg: 298,
    sodiumHighMg: 364,
    fluidMl: 401,
    fluidLowMl: 341,
    fluidHighMl: 461,
  );

  test('§6(e): every during-solver plate leaves the solvent backstop feasible',
      () {
    const solver = ClientDuringPhaseSolver();
    // Rotate the pool so the deterministic weighted pick lands on different
    // candidates (incl. the mix-first arrangement of the live defect).
    for (var rot = 0; rot < pool.length; rot++) {
      final rotated = [...pool.sublist(rot), ...pool.sublist(0, rot)];
      final selections = solver.solve(
        foods: rotated,
        targets: targets,
        activityType: ActivityType.running,
        gutTrainingLevel: 'moderate',
        durationMinutes: 60,
      );
      final byId = {for (final f in pool) f.id: f};
      final items = selections
          .map((s) => byId[s.foodId]!.toFoodItemData(s.quantity))
          .toList();

      final totalFluid =
          items.fold<double>(0, (t, i) => t + (i.nutritionalInfo?.fluids ?? 0));
      final headroom = (461 - totalFluid).clamp(0, double.infinity);
      final requirement = solventRequirementMl(items);
      final plain = plainWaterMl(items);
      expect(
        requirement,
        lessThanOrEqualTo(plain + headroom + 1e-6),
        reason:
            'rot $rot: requirement $requirement > plain $plain + headroom '
            '$headroom — plate: '
            '${selections.map((s) => '${s.foodId} x${s.quantity}').join(', ')}',
      );

      // And the backstop finishes the job: no ceiling conflict, and the
      // declared requirement is met (or the shortfall is below the
      // meaningful-pairing minimum next to plain water — the spec's solvent
      // lines are approximate, "gels chase ~150").
      final paired = ensureElectrolyteWaterPairing(
        items,
        [byId['water']!],
        fluidCeilingMl: 461,
      );
      expect(paired.conflict, isNull,
          reason: 'rot $rot: pairing conflict — plate: '
              '${selections.map((s) => '${s.foodId} x${s.quantity}').join(', ')}');
      final owed =
          solventRequirementMl(paired.items) - plainWaterMl(paired.items);
      expect(
        owed <= 1e-6 || (owed < 100 && plainWaterMl(paired.items) > 0),
        isTrue,
        reason: 'rot $rot: post-pairing plate owes ${owed}ml solvent water',
      );
    }
  });
}
