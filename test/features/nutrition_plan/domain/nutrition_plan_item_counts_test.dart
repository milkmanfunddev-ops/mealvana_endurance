import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';

/// Cover for the per-phase food counts reported on
/// `nutrition_plan_created_from_adjusted_macros`.
///
/// Two ways this silently returns 0 if implemented naively, both of which are
/// the normal case in production:
///   - before-phase foods live under `subPhases`, not the section's own
///     `foodItems` (V2 format);
///   - section *titles* are sport-specific ("BEFORE BRICK", "DURING BIKE"), so
///     classifying on title instead of id zeroes every non-running plan.
void main() {
  FoodItemData food(String name) =>
      FoodItemData(id: name, name: name, quantity: '1');

  NutritionPlan planWith(List<PlanSection> sections) =>
      NutritionPlan(id: 'plan-1', name: 'Test Plan', sections: sections);

  group('NutritionPlanItemCounts', () {
    test('counts flat foodItems per phase', () {
      final plan = planWith([
        PlanSection(
          id: 'before_run',
          title: 'Before Run',
          foodItems: [food('banana'), food('bagel')],
        ),
        PlanSection(
          id: 'during_run',
          title: 'During Run',
          foodItems: [food('gel')],
        ),
        PlanSection(
          id: 'after_run',
          title: 'After Run',
          foodItems: [food('shake'), food('pretzels'), food('milk')],
        ),
      ]);

      expect(plan.beforeItemCount, 2);
      expect(plan.duringItemCount, 1);
      expect(plan.afterItemCount, 3);
    });

    test('includes before-phase sub-phase items (V2 format)', () {
      // The mapper builds this shape with foodItems deliberately empty.
      final plan = planWith([
        PlanSection(
          id: 'before_run',
          title: 'Before Run',
          foodItems: const [],
          subPhases: [
            BeforeSubPhase(subPhaseType: 'meal', foodItems: [food('oatmeal')]),
            BeforeSubPhase(
              subPhaseType: 'snack',
              foodItems: [food('granola'), food('water')],
            ),
          ],
        ),
      ]);

      expect(plan.beforeItemCount, 3);
    });

    test('sums a section\'s own foodItems together with its sub-phases', () {
      final plan = planWith([
        PlanSection(
          id: 'before_run',
          title: 'Before Run',
          foodItems: [food('water')],
          subPhases: [
            BeforeSubPhase(subPhaseType: 'meal', foodItems: [food('oatmeal')]),
          ],
        ),
      ]);

      expect(plan.beforeItemCount, 2);
    });

    test('classifies by id, not by sport-specific title', () {
      // A brick: titles say BRICK/BIKE/RUN, ids still carry the phase.
      final plan = planWith([
        PlanSection(
          id: 'before_run',
          title: 'BEFORE BRICK',
          foodItems: [food('banana')],
        ),
        PlanSection(
          id: 'during_run',
          title: 'DURING BIKE',
          foodItems: [food('bar'), food('drink')],
        ),
        PlanSection(
          id: 'after_run',
          title: 'AFTER BRICK',
          foodItems: [food('shake')],
        ),
      ]);

      expect(plan.beforeItemCount, 1);
      expect(plan.duringItemCount, 2);
      expect(plan.afterItemCount, 1);
    });

    test('an empty plan counts zero rather than throwing', () {
      final plan = planWith(const []);

      expect(plan.beforeItemCount, 0);
      expect(plan.duringItemCount, 0);
      expect(plan.afterItemCount, 0);
    });

    test('an unrecognised section id falls back to the before phase', () {
      // Matches the widgets' precedence: during, then after, else before.
      final plan = planWith([
        PlanSection(
          id: 'fallback-before-meal',
          title: 'Fallback',
          foodItems: [food('toast')],
        ),
      ]);

      expect(plan.beforeItemCount, 1);
      expect(plan.duringItemCount, 0);
    });
  });
}
