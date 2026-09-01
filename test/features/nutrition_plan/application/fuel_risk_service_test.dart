import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/fuel_risk_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/low_fuel_risk_badge.dart';

FoodItemData _food(String id, int carbs) => FoodItemData(
  id: id,
  name: 'Food $id',
  quantity: '1',
  nutritionalInfo: NutritionalInfo(carbs: carbs),
);

/// V2-shaped plan: BEFORE section stores foods + targets on sub-phases with
/// no section-level carbsTarget (matches nutrition_plan_mapper output).
NutritionPlan _v2Plan({required List<FoodItemData> beforeFoods}) {
  return NutritionPlan(
    id: 'plan-1',
    name: 'Test Plan',
    sections: [
      PlanSection(
        id: 'before_run',
        title: 'Before Run',
        foodItems: const [],
        subPhases: [
          BeforeSubPhase(
            subPhaseType: 'meal',
            foodItems: beforeFoods,
            carbsTarget: 75,
          ),
        ],
      ),
      PlanSection(
        id: 'during_run',
        title: 'During Run',
        carbsTarget: 90,
        foodItems: [_food('gel-1', 90)],
      ),
      PlanSection(
        id: 'after_run',
        title: 'After Run',
        carbsTarget: 80,
        foodItems: [_food('shake-1', 80)],
      ),
    ],
  );
}

void main() {
  group('FuelRiskService.evaluate', () {
    test('no warning when all sections meet their targets', () {
      final plan = _v2Plan(beforeFoods: [_food('oats-1', 75)]);

      final status = FuelRiskService.evaluate(plan);

      expect(status.isLowFuel, isFalse);
      expect(status.lowestSection, isNull);
    });

    test('BEFORE phase manually emptied to 0 g carbs fires low-fuel warning '
        'even when during/after remain fully fueled (bug 3b1e3fdb)', () {
      // Simulate the manual edit path: the controller's transform replaces
      // the sub-phase food list, here emptied to nothing.
      final edited = _v2Plan(beforeFoods: [_food('oats-1', 75)]);
      final emptiedSections = edited.sections.map((section) {
        if (!section.hasSubPhases) return section;
        return section.copyWith(
          subPhases: section.subPhases!
              .map((sp) => sp.copyWith(foodItems: const []))
              .toList(),
        );
      }).toList();
      final plan = edited.copyWith(sections: emptiedSections);

      final status = FuelRiskService.evaluate(plan);

      expect(status.isLowFuel, isTrue);
      expect(status.lowestSection, 'before');
      // BEFORE's sub-phase targets must count toward the totals even
      // though the section-level carbsTarget is null (V2 mapper shape).
      expect(status.targetCarbs, 75 + 90 + 80);
      expect(status.actualCarbs, 90 + 80);
    });

    test('single section far below target fires even when overall ratio '
        'is above threshold (flat V1 sections)', () {
      final plan = NutritionPlan(
        id: 'plan-2',
        name: 'V1 Plan',
        sections: [
          PlanSection(
            id: 'before_run',
            title: 'Before Run',
            carbsTarget: 60,
            foodItems: const [], // emptied to 0 g
          ),
          PlanSection(
            id: 'during_run',
            title: 'During Run',
            carbsTarget: 120,
            foodItems: [_food('gel-1', 120)],
          ),
          PlanSection(
            id: 'after_run',
            title: 'After Run',
            carbsTarget: 80,
            foodItems: [_food('shake-1', 80)],
          ),
        ],
      );
      // Overall 200/260 = 0.77 > 0.67, but BEFORE is at 0%.
      final status = FuelRiskService.evaluate(plan);

      expect(status.isLowFuel, isTrue);
      expect(status.lowestSection, 'before');
    });

    test('overall shortfall still fires (pre-existing behavior)', () {
      final plan = NutritionPlan(
        id: 'plan-3',
        name: 'Underfueled Plan',
        sections: [
          PlanSection(
            id: 'during_run',
            title: 'During Run',
            carbsTarget: 100,
            foodItems: [_food('gel-1', 50)],
          ),
        ],
      );

      final status = FuelRiskService.evaluate(plan);

      expect(status.isLowFuel, isTrue);
      expect(status.lowestSection, 'during');
    });
  });

  group('LowFuelRiskBadge', () {
    testWidgets('renders warning when BEFORE is emptied to 0 g carbs', (
      tester,
    ) async {
      final plan = _v2Plan(beforeFoods: const []);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LowFuelRiskBadge(nutritionPlan: plan),
            ),
          ),
        ),
      );

      expect(find.text('LOW FUEL RISK'), findsOneWidget);
    });

    testWidgets('renders nothing when fueling is adequate', (tester) async {
      final plan = _v2Plan(beforeFoods: [_food('oats-1', 75)]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LowFuelRiskBadge(nutritionPlan: plan),
            ),
          ),
        ),
      );

      expect(find.text('LOW FUEL RISK'), findsNothing);
    });
  });
}
