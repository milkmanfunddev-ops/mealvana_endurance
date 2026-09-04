import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_coverage.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_meal.dart';

PlanMeal meal(
  String id,
  MealType type,
  int servings, {
  int? kcal,
  double? carbsG,
  double? proteinG,
}) => PlanMeal(
  id: id,
  planId: 'p1',
  source: MealSource.library,
  name: id,
  mealType: type,
  servings: servings,
  servingsLeft: servings,
  kcal: kcal,
  carbsG: carbsG,
  proteinG: proteinG,
);

void main() {
  group('PlanCoverageService.compute (port of plan.ts coverageOf)', () {
    test('empty plan', () {
      final c = PlanCoverageService.compute(const []);
      expect(c.lunchDinnerSlots, 14);
      expect(c.covered, 0);
      expect(
        c.perDay,
        const PlanCoveragePerDay(kcal: 0, carbsG: 0, proteinG: 0),
      );
      expect(c.isComplete, isFalse);
    });

    test('sums lunch + dinner servings; other types count for macros only', () {
      final c = PlanCoverageService.compute([
        meal('l', MealType.lunch, 4, kcal: 500, carbsG: 50, proteinG: 30),
        meal('d', MealType.dinner, 6, kcal: 600, carbsG: 60, proteinG: 40),
        meal('b', MealType.breakfast, 2, kcal: 300, carbsG: 30, proteinG: 10),
      ]);
      expect(c.covered, 10);
      // (2000 + 3600 + 600) / 7 = 885.7 → 886
      expect(c.perDay.kcal, 886);
      // (200 + 360 + 60) / 7 = 88.6 → 89
      expect(c.perDay.carbsG, 89);
      // (120 + 240 + 20) / 7 = 54.3 → 54
      expect(c.perDay.proteinG, 54);
    });

    test('covered is capped at 14', () {
      final c = PlanCoverageService.compute([
        meal('l', MealType.lunch, 10),
        meal('d', MealType.dinner, 10),
      ]);
      expect(c.covered, 14);
      expect(c.isComplete, isTrue);
    });

    test('snacks never count toward slots', () {
      final c = PlanCoverageService.compute([meal('s', MealType.snack, 20)]);
      expect(c.covered, 0);
    });

    test('null macros are treated as 0', () {
      final c = PlanCoverageService.compute([
        meal('d', MealType.dinner, 7, kcal: null, carbsG: null, proteinG: 70),
      ]);
      expect(c.perDay.kcal, 0);
      expect(c.perDay.carbsG, 0);
      expect(c.perDay.proteinG, 70);
    });

    test('macros are weighted by servings', () {
      final c = PlanCoverageService.compute([
        meal('d', MealType.dinner, 14, kcal: 100, carbsG: 10, proteinG: 5),
      ]);
      expect(c.perDay.kcal, 200);
      expect(c.perDay.carbsG, 20);
      expect(c.perDay.proteinG, 10);
    });

    test('halves round up like Math.round', () {
      // 7 servings × 0.5 = 3.5 / 7 = 0.5 → 1
      final c = PlanCoverageService.compute([
        meal('d', MealType.dinner, 7, carbsG: 0.5),
      ]);
      expect(c.perDay.carbsG, 1);
    });
  });

  group('PlanCoverageService.compute — dinners-only scope (7 slots)', () {
    test('counts dinner servings only, lunches count for macros alone', () {
      final c = PlanCoverageService.compute([
        meal('l', MealType.lunch, 4, kcal: 700),
        meal('d', MealType.dinner, 3, kcal: 700),
      ], lunchDinnerSlots: 7);
      expect(c.lunchDinnerSlots, 7);
      expect(c.covered, 3);
      expect(c.isComplete, isFalse);
      // Macros still weight every meal: (2800 + 2100) / 7 = 700.
      expect(c.perDay.kcal, 700);
    });

    test('covered is capped at 7 and completes there', () {
      final c = PlanCoverageService.compute([
        meal('d1', MealType.dinner, 4),
        meal('d2', MealType.dinner, 4),
      ], lunchDinnerSlots: 7);
      expect(c.covered, 7);
      expect(c.isComplete, isTrue);
    });

    test('the same meals read 14-slot by default', () {
      final meals = [
        meal('l', MealType.lunch, 4),
        meal('d', MealType.dinner, 3),
      ];
      expect(PlanCoverageService.compute(meals).covered, 7);
      expect(PlanCoverageService.compute(meals).lunchDinnerSlots, 14);
      expect(
        PlanCoverageService.compute(meals, lunchDinnerSlots: 7).covered,
        3,
      );
    });

    test('an explicit 14 behaves exactly like the default', () {
      final meals = [
        meal('l', MealType.lunch, 10),
        meal('d', MealType.dinner, 10),
      ];
      expect(
        PlanCoverageService.compute(meals, lunchDinnerSlots: 14),
        PlanCoverageService.compute(meals),
      );
    });
  });

  group('PlanCoverage JSON', () {
    test('round-trips', () {
      const c = PlanCoverage(
        lunchDinnerSlots: 14,
        covered: 3,
        perDay: PlanCoveragePerDay(kcal: 1, carbsG: 2, proteinG: 3),
      );
      expect(PlanCoverage.fromJson(c.toJson()), c);
    });
  });
}
