import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/client_plan/client_greedy_solver.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/solver_food.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/solver_types.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/sport_config.dart';

/// Target-seeking tests for the offline greedy solver (2026-07-29).
///
/// Policy: "aim at the TARGET, pass iff inside the range." The solver used to
/// break out of its item loop at fixed fractions of target (90% carbs, 70%
/// protein, 70% fluid, 90% sodium) and size servings from the carb deficit
/// alone — so an offline during-phase plan could ship at 70% of the fluid
/// target and call that success.
///
/// These assertions are about DISTANCE TO TARGET, never range membership, and
/// they mirror `supabase/functions/_shared/nutrition/target-seeking.test.ts`
/// so the Dart and Deno fallbacks stay in lockstep.
void main() {
  const solver = ClientGreedySolver();
  // maxFoods 5, maxServingsPerFood 3 — the real running "during" config shape.
  const duringConfig = SportPhaseConfig(maxFoods: 5, maxServingsPerFood: 3);

  SolverFood food({
    required String id,
    required String name,
    double carbsG = 0,
    double proteinG = 0,
    double sodiumMg = 0,
    double fluidMl = 0,
    int maxServings = 4,
    int preferenceScore = 100,
    bool isIndivisible = false,
  }) {
    return SolverFood(
      id: id,
      name: name,
      carbsG: carbsG,
      proteinG: proteinG,
      fatG: 0,
      sodiumMg: sodiumMg,
      fluidMl: fluidMl,
      calories: 0,
      maxServings: maxServings,
      preferenceScore: preferenceScore,
      isIndivisible: isIndivisible,
    );
  }

  ({double carbsG, double sodiumMg, double fluidMl}) totals(
    List<SolverSelection> selections,
  ) {
    var carbs = 0.0, sodium = 0.0, fluid = 0.0;
    for (final s in selections) {
      carbs += s.carbsG;
      sodium += s.sodiumMg;
      fluid += s.fluidMl;
    }
    return (carbsG: carbs, sodiumMg: sodium, fluidMl: fluid);
  }

  group('ClientGreedySolver target-seeking', () {
    test('during: fills fluid to the TARGET, not 70% of it', () {
      // The old code sized every before/during serving from the carb deficit
      // alone, so once carbs were met the hydration foods resolved to zero
      // servings and fluid was abandoned wherever it happened to land.
      // Two 250ml sources are needed because maxServingsPerFood is 3.
      final foods = [
        food(id: 'gel', name: 'Gel', carbsG: 25, preferenceScore: 200),
        food(id: 'bottle', name: 'Bottle', fluidMl: 250),
        food(id: 'flask', name: 'Flask', fluidMl: 250),
      ];
      const targets = SolverTargets(
        carbsG: 50,
        sodiumMg: 0,
        fluidMl: 1000,
        fluidHighMl: 1200,
      );

      final result = solver.solve(
        foods: foods,
        targets: targets,
        phase: 'during',
        config: duringConfig,
      );
      final t = totals(result);

      expect(
        t.fluidMl,
        1000,
        reason: 'fluid must reach the 1000ml target, got ${t.fluidMl}ml',
      );
      expect(t.carbsG, greaterThanOrEqualTo(50));
    });

    test('during: does not stop carbs at 90% when target is reachable', () {
      // Gel A caps at 3 servings x 15g = 45g, exactly 90% of the 50g target —
      // precisely where the old stop condition broke out. A 5g chew closes it.
      final foods = [
        food(id: 'gel-a', name: 'Gel A', carbsG: 15, preferenceScore: 200),
        food(id: 'chew', name: 'Chew', carbsG: 5, preferenceScore: 100),
      ];
      const targets = SolverTargets(carbsG: 50, sodiumMg: 0, fluidMl: 0);

      final t = totals(
        solver.solve(
          foods: foods,
          targets: targets,
          phase: 'during',
          config: duringConfig,
        ),
      );
      expect(t.carbsG, 50, reason: 'carbs must reach target, not 90% of it');
    });

    test('during: fills sodium toward target once carbs are met', () {
      final foods = [
        food(id: 'gel', name: 'Gel', carbsG: 25, preferenceScore: 200),
        food(
          id: 'tab',
          name: 'Salt Tab',
          sodiumMg: 200,
          isIndivisible: true,
          preferenceScore: 100,
        ),
      ];
      const targets = SolverTargets(
        carbsG: 50,
        sodiumMg: 600,
        sodiumHighMg: 700,
        fluidMl: 0,
      );

      final t = totals(
        solver.solve(
          foods: foods,
          targets: targets,
          phase: 'during',
          config: duringConfig,
        ),
      );
      expect(
        t.sodiumMg,
        600,
        reason: 'sodium must be pursued to target, got ${t.sodiumMg}mg',
      );
      expect(
        t.sodiumMg,
        lessThanOrEqualTo(700),
        reason: 'never past the ceiling',
      );
    });

    test('during: target-seeking never breaches the band ceiling', () {
      // Only a 400ml indivisible bottle against a 1000ml target with an
      // 1100ml ceiling. 2 bottles = 800ml (short but in range); 3 = 1200ml,
      // over the ceiling. Prefer the in-range shortfall over a silent
      // overshoot — the `max(1.0, ...)` serving floor used to force the latter.
      final foods = [
        food(
          id: 'bottle',
          name: 'Big Bottle',
          fluidMl: 400,
          isIndivisible: true,
          maxServings: 4,
          preferenceScore: 200,
        ),
      ];
      const targets = SolverTargets(
        carbsG: 0,
        sodiumMg: 0,
        fluidMl: 1000,
        fluidHighMl: 1100,
      );

      final t = totals(
        solver.solve(
          foods: foods,
          targets: targets,
          phase: 'during',
          config: duringConfig,
        ),
      );
      expect(
        t.fluidMl,
        lessThanOrEqualTo(1100),
        reason: 'must not breach fluid_high, got ${t.fluidMl}ml',
      );
    });

    test('after: pursues protein to target, not 70% of it', () {
      // Shake A caps at 3 x 15g = 45g protein, 75% of a 60g target — above
      // the old 70% stop line. A 15g bar should still be added.
      final foods = [
        food(
          id: 'shake',
          name: 'Shake',
          carbsG: 10,
          proteinG: 15,
          preferenceScore: 200,
        ),
        food(
          id: 'bar',
          name: 'Recovery Bar',
          carbsG: 10,
          proteinG: 15,
          preferenceScore: 100,
        ),
      ];
      const targets = SolverTargets(
        carbsG: 80,
        proteinG: 60,
        sodiumMg: 0,
        fluidMl: 0,
      );

      final result = solver.solve(
        foods: foods,
        targets: targets,
        phase: 'after',
        config: const SportPhaseConfig(maxFoods: 5, maxServingsPerFood: 3),
      );
      var protein = 0.0;
      for (final s in result) {
        protein += s.proteinG;
      }
      expect(
        protein,
        greaterThan(45),
        reason: 'protein must be pursued past the old 70%/75% stop line',
      );
    });
  });
}
