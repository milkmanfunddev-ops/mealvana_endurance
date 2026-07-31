import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/nutrition_plan_generation_audit.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_shortfall.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';

FoodItemData _food({
  int carbs = 0,
  int protein = 0,
  int sodium = 0,
  double fluids = 0,
}) {
  return FoodItemData(
    id: 'food',
    name: 'Fuel',
    quantity: '1',
    nutritionalInfo: NutritionalInfo(
      carbs: carbs,
      protein: protein,
      sodium: sodium,
      fluids: fluids,
    ),
  );
}

NutritionPlan _plan(List<PlanSection> sections) {
  return NutritionPlan(id: 'plan', name: 'Plan', sections: sections);
}

void main() {
  group('NutritionPlanGenerationAudit', () {
    test('reports every unexplained non-green nutrient in one result', () {
      final plan = _plan([
        PlanSection(
          id: 'during_run',
          title: 'During Run',
          foodItems: [_food(carbs: 120, sodium: 300, fluids: 700)],
          carbsTarget: 186,
          sodiumTarget: 700,
          fluidsTarget: 700,
        ),
      ]);

      final misses = NutritionPlanGenerationAudit.findUnexplainedMisses(plan);

      expect(misses, hasLength(2));
      expect(
        misses.map((miss) => miss.nutrient),
        containsAll([AuditedNutrient.carbs, AuditedNutrient.sodium]),
      );
    });

    test('ignores misses explained by preferences or constraints', () {
      final plan = _plan([
        PlanSection(
          id: 'during_run',
          title: 'During Run',
          foodItems: [_food(carbs: 40)],
          carbsTarget: 100,
          shortfalls: const [
            MacroShortfall(
              macro: ShortfallMacro.carbs,
              delivered: 40,
              target: 100,
              unit: 'g',
              reason: ShortfallReason.templateConstraint,
            ),
          ],
        ),
      ]);

      expect(NutritionPlanGenerationAudit.findUnexplainedMisses(plan), isEmpty);
    });

    test('ignores post-workout misses', () {
      final plan = _plan([
        PlanSection(
          id: 'after_run',
          title: 'After Run',
          foodItems: [_food(carbs: 10, sodium: 50)],
          carbsTarget: 100,
          sodiumTarget: 500,
        ),
      ]);

      expect(NutritionPlanGenerationAudit.findUnexplainedMisses(plan), isEmpty);
    });

    test('aggregates before sub-phases the same way as Activity Details', () {
      final plan = _plan([
        PlanSection(
          id: 'before_run',
          title: 'Before Run',
          foodItems: const [],
          subPhases: [
            BeforeSubPhase(
              subPhaseType: 'meal',
              foodItems: [_food(carbs: 50)],
              carbsTarget: 60,
            ),
            BeforeSubPhase(
              subPhaseType: 'snack',
              foodItems: [_food(carbs: 20)],
              carbsTarget: 40,
            ),
          ],
        ),
      ]);

      final misses = NutritionPlanGenerationAudit.findUnexplainedMisses(plan);

      expect(misses, hasLength(1));
      expect(misses.single.actual, 70);
      expect(misses.single.target, 100);
      expect(misses.single.nutrient, AuditedNutrient.carbs);
    });
  });
}
