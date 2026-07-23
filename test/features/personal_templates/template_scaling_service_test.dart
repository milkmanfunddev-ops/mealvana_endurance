import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/plan_section.dart';
import 'package:mealvana_endurance/features/personal_templates/application/template_scaling_service.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

// ============================================================
// Unit tests for TemplateScalingService
// ============================================================
//
// Covers:
//  - Basic ratio scaling for before/during/after sections
//  - Ratio clamping (0.5x floor, 2.0x ceiling)
//  - Indivisible food rounding (whole numbers only)
//  - Divisible food rounding (nearest 0.5)
//  - No-op when section carbs are zero or target is zero/null
//  - Sub-phase foods are scaled alongside top-level foods
//  - Quantity suffix preservation ("2 gels" → "3 gels")
//  - Unit suffix extraction (non-numeric suffix kept)
//  - NutritionalInfo scaling (proportional to actual quantity ratio)
//  - Sections without matching id prefix pass through unchanged
//  - Minimum quantity floors (never below 1 for indivisible, 0.5 for divisible)

// Helper: minimal MacroTargets with specified per-phase carb targets.
MacroTargets _targets({
  double preCarbs = 60,
  double duringCarbs = 120,
  double postCarbs = 40,
}) {
  final now = DateTime.now();
  final metrics = RunMetrics(
    distanceMi: 10,
    distanceKm: 16,
    durationH: 2,
    durationMin: 120,
    speedMph: 5,
    caloriesGrossKcal: 800,
    caloriesNetKcal: 600,
    met: 7,
  );
  return MacroTargets(
    id: 'tgt-1',
    activityType: ActivityType.running,
    preRun: PreRunMacros(
      carbsG: preCarbs,
      proteinG: 20,
      fatCapG: 15,
      fluidsMl: 500,
      sodiumMg: 300,
    ),
    duringRun: DuringRunMacros(
      carbRateGPerH: 60,
      carbTotalG: duringCarbs,
      fluidRateMlPerH: 600,
      fluidTotalMl: 1200,
      sodiumRateMgPerH: 400,
      sodiumTotalMg: 800,
      massNormRateGPerH: 0.8,
    ),
    postRun: PostRunMacros(
      carbsG: postCarbs,
      proteinG: 25,
      fluidsMl: 400,
      sodiumMg: 200,
    ),
    metrics: metrics,
    calculationRule: 'standard',
    timestamp: now,
    isUserModified: false,
  );
}

/// Build a minimal NutritionPlan with a single section containing food items.
NutritionPlan _plan({required List<PlanSection> sections}) {
  return NutritionPlan(id: 'plan-1', name: 'Test Plan', sections: sections);
}

/// Build a FoodItemData with a numeric quantity string.
FoodItemData _food({
  String id = 'food-1',
  String name = 'Gel',
  String quantity = '2',
  int carbs = 22,
  int calories = 100,
  bool isIndivisible = false,
}) {
  return FoodItemData(
    id: id,
    name: name,
    quantity: quantity,
    isIndivisible: isIndivisible,
    nutritionalInfo: NutritionalInfo(
      carbs: carbs,
      calories: calories,
      protein: 0,
      fat: 0,
      sodium: 50,
    ),
  );
}

/// Convenience: build a PlanSection with a given id prefix.
PlanSection _section({
  required String id,
  required List<FoodItemData> foodItems,
  List<BeforeSubPhase>? subPhases,
}) {
  return PlanSection(
    id: id,
    title: id,
    foodItems: foodItems,
    subPhases: subPhases,
  );
}

void main() {
  group('TemplateScalingService.scalePlanWithTargets', () {
    // ----------------------------------------------------------
    // Basic scaling — before / during / after
    // ----------------------------------------------------------

    test('scales before section by carb ratio', () {
      // Plan has 30g carbs in before section; target is 60g → ratio 2.0.
      final plan = _plan(
        sections: [
          _section(
            id: 'before1',
            foodItems: [_food(quantity: '2', carbs: 15)],
          ),
        ],
      );

      final scaled = TemplateScalingService.scalePlanWithTargets(
        plan: plan,
        targets: _targets(preCarbs: 60),
      );

      final scaledQty = int.parse(
        scaled.sections.first.foodItems.first.quantity,
      );
      // 2 * (60/30) = 4; ratio=2.0 which is at the ceiling so result = 4.
      expect(scaledQty, 4);
    });

    test('scales during section by carb ratio', () {
      // Plan has 60g carbs in during; target is 120g → ratio 2.0.
      final plan = _plan(
        sections: [
          _section(
            id: 'during1',
            foodItems: [_food(quantity: '3', carbs: 20)],
          ),
        ],
      );

      final scaled = TemplateScalingService.scalePlanWithTargets(
        plan: plan,
        targets: _targets(duringCarbs: 120),
      );

      // 3 * (120/60) = 6, rounded to nearest 0.5 = 6.
      final qty = scaled.sections.first.foodItems.first.quantity;
      expect(qty, '6');
    });

    test('scales after section by carb ratio', () {
      // Plan has 20g carbs in after; target is 40g → ratio 2.0.
      final plan = _plan(
        sections: [
          _section(
            id: 'after1',
            foodItems: [_food(quantity: '1', carbs: 20)],
          ),
        ],
      );

      final scaled = TemplateScalingService.scalePlanWithTargets(
        plan: plan,
        targets: _targets(postCarbs: 40),
      );

      // 1 * (40/20) = 2, rounded = 2.
      final qty = scaled.sections.first.foodItems.first.quantity;
      expect(qty, '2');
    });

    // ----------------------------------------------------------
    // Ratio clamping
    // ----------------------------------------------------------

    test('ratio is clamped at 2.0x ceiling (does not over-scale)', () {
      // 10g carbs in plan, 100g target → raw ratio 10, clamped to 2.
      final plan = _plan(
        sections: [
          _section(
            id: 'during1',
            foodItems: [_food(quantity: '1', carbs: 10)],
          ),
        ],
      );

      final scaled = TemplateScalingService.scalePlanWithTargets(
        plan: plan,
        targets: _targets(duringCarbs: 100),
      );

      // Ratio clamped to 2.0 → quantity = 1 * 2 = 2.
      final qty = scaled.sections.first.foodItems.first.quantity;
      expect(qty, '2');
    });

    test('ratio is clamped at 0.5x floor (does not under-scale too far)', () {
      // 100g carbs in plan, 1g target → raw ratio 0.01, clamped to 0.5.
      final plan = _plan(
        sections: [
          _section(
            id: 'during1',
            foodItems: [_food(quantity: '4', carbs: 100)],
          ),
        ],
      );

      final scaled = TemplateScalingService.scalePlanWithTargets(
        plan: plan,
        targets: _targets(duringCarbs: 1),
      );

      // 4 * 0.5 = 2 (clamped ratio floor).
      final qty = scaled.sections.first.foodItems.first.quantity;
      expect(qty, '2');
    });

    // ----------------------------------------------------------
    // Indivisible rounding
    // ----------------------------------------------------------

    test('indivisible food rounds quantity to whole number', () {
      // 2 packets × ratio 1.3 = 2.6 → rounds to 3.
      final plan = _plan(
        sections: [
          _section(
            id: 'during1',
            foodItems: [_food(quantity: '2', carbs: 40, isIndivisible: true)],
          ),
        ],
      );

      // 40g carbs, target 52g → ratio 1.3.
      final scaled = TemplateScalingService.scalePlanWithTargets(
        plan: plan,
        targets: _targets(duringCarbs: 52),
      );

      final qty = scaled.sections.first.foodItems.first.quantity;
      // 2 * 1.3 = 2.6 → rounds to 3 for indivisible.
      expect(int.parse(qty), 3);
    });

    test('indivisible food floors to 1 (never below 1)', () {
      // 3 packets × clamped ratio 0.5 = 1.5 → rounds to 2 (normal case).
      // But at 3 * 0.5 = 1.5 → rounds to 2, not below 1. Let's test near-zero.
      final plan = _plan(
        sections: [
          _section(
            id: 'during1',
            foodItems: [_food(quantity: '1', carbs: 20, isIndivisible: true)],
          ),
        ],
      );

      // ratio clamped to 0.5 → 1 * 0.5 = 0.5, rounds to 1 (can't go below 1).
      final scaled = TemplateScalingService.scalePlanWithTargets(
        plan: plan,
        targets: _targets(duringCarbs: 1), // raw ratio 0.05, clamped to 0.5
      );

      final qty = int.parse(scaled.sections.first.foodItems.first.quantity);
      expect(qty, greaterThanOrEqualTo(1));
    });

    // ----------------------------------------------------------
    // Divisible rounding (nearest 0.5)
    // ----------------------------------------------------------

    test('divisible food rounds to nearest 0.5', () {
      // 2 cups × ratio 0.8 = 1.6 → nearest 0.5 = 1.5.
      final plan = _plan(
        sections: [
          _section(
            id: 'before1',
            foodItems: [_food(quantity: '2', carbs: 30, isIndivisible: false)],
          ),
        ],
      );

      // 30g carbs, target 24g → ratio 0.8.
      final scaled = TemplateScalingService.scalePlanWithTargets(
        plan: plan,
        targets: _targets(preCarbs: 24),
      );

      final qty = scaled.sections.first.foodItems.first.quantity;
      expect(qty, '1.5');
    });

    test('divisible food floors to 0.5 (never below 0.5)', () {
      final plan = _plan(
        sections: [
          _section(
            id: 'before1',
            foodItems: [_food(quantity: '1', carbs: 20, isIndivisible: false)],
          ),
        ],
      );

      // clamped ratio 0.5 → 1 * 0.5 = 0.5 (exactly at floor).
      final scaled = TemplateScalingService.scalePlanWithTargets(
        plan: plan,
        targets: _targets(preCarbs: 1), // raw 0.05 → clamped 0.5
      );

      final qty = scaled.sections.first.foodItems.first.quantity;
      expect(double.parse(qty), greaterThanOrEqualTo(0.5));
    });

    // ----------------------------------------------------------
    // Unit suffix preservation
    // ----------------------------------------------------------

    test('unit suffix in quantity string is preserved after scaling', () {
      // quantity "2ml" → after scaling should still have "ml" suffix.
      // NOTE: _parseQuantity captures leading numeric portion only.
      final food = FoodItemData(
        id: 'f1',
        name: 'Sports Drink',
        quantity: '500ml',
        isIndivisible: false,
        nutritionalInfo: const NutritionalInfo(carbs: 30),
      );

      final plan = _plan(
        sections: [
          _section(id: 'during1', foodItems: [food]),
        ],
      );

      final scaled = TemplateScalingService.scalePlanWithTargets(
        plan: plan,
        targets: _targets(duringCarbs: 60), // ratio 2.0
      );

      final qty = scaled.sections.first.foodItems.first.quantity;
      expect(qty, endsWith('ml'));
    });

    // ----------------------------------------------------------
    // NutritionalInfo scaling
    // ----------------------------------------------------------

    test(
      'scaled food nutritionalInfo is proportional to actual quantity ratio',
      () {
        // 2 gels @ 22g carbs each = 44g total; target 88g → ratio 2.0 → 4 gels
        // Expected: calories 100 * 2.0 = 200, carbs 22 * 2.0 = 44.
        final plan = _plan(
          sections: [
            _section(
              id: 'during1',
              foodItems: [
                _food(
                  quantity: '2',
                  carbs: 22,
                  calories: 100,
                  isIndivisible: true, // indivisible so ratio is exact integer
                ),
              ],
            ),
          ],
        );

        final scaled = TemplateScalingService.scalePlanWithTargets(
          plan: plan,
          targets: _targets(duringCarbs: 88), // 44g → ratio 2.0 → 4 gels
        );

        final info = scaled.sections.first.foodItems.first.nutritionalInfo!;
        expect(info.calories, 200);
        expect(info.carbs, 44);
      },
    );

    test('food without nutritionalInfo passes through unchanged', () {
      final food = const FoodItemData(
        id: 'f1',
        name: 'Water',
        quantity: '1',
        // nutritionalInfo is null
      );

      final plan = _plan(
        sections: [
          _section(id: 'during1', foodItems: [food]),
        ],
      );

      final scaled = TemplateScalingService.scalePlanWithTargets(
        plan: plan,
        targets: _targets(duringCarbs: 120),
      );

      // Quantity string can't be parsed for scaling → food passes through.
      // Wait — quantity '1' IS parseable but carbs is null so sectionCarbTotal=0 → skip.
      expect(scaled.sections.first.foodItems.first.nutritionalInfo, isNull);
    });

    // ----------------------------------------------------------
    // Sub-phase scaling
    // ----------------------------------------------------------

    test('sub-phase foods are scaled when section has subPhases', () {
      // Before section uses sub-phases; carbs in sub-phase should be scaled.
      final subPhase = BeforeSubPhase(
        subPhaseType: 'meal',
        foodItems: [_food(quantity: '1', carbs: 30, isIndivisible: false)],
        carbsTarget: 30,
      );

      final section = PlanSection(
        id: 'before1',
        title: 'Before',
        foodItems: const [],
        subPhases: [subPhase],
      );

      final plan = _plan(sections: [section]);

      // target 60g → ratio 2.0.
      final scaled = TemplateScalingService.scalePlanWithTargets(
        plan: plan,
        targets: _targets(preCarbs: 60),
      );

      final scaledSubPhases = scaled.sections.first.subPhases!;
      expect(scaledSubPhases.length, 1);
      final scaledQty = scaledSubPhases.first.foodItems.first.quantity;
      expect(scaledQty, '2');
    });

    // ----------------------------------------------------------
    // Zero carb / missing target edge cases
    // ----------------------------------------------------------

    test('section with zero carbs passes through unchanged', () {
      // All foods have 0 carbs → sectionCarbTotal = 0 → skip scaling.
      final food = _food(quantity: '2', carbs: 0);
      final plan = _plan(
        sections: [
          _section(id: 'during1', foodItems: [food]),
        ],
      );

      final scaled = TemplateScalingService.scalePlanWithTargets(
        plan: plan,
        targets: _targets(duringCarbs: 120),
      );

      expect(scaled.sections.first.foodItems.first.quantity, '2');
    });

    test('section with zero target carbs passes through unchanged', () {
      final plan = _plan(
        sections: [
          _section(
            id: 'during1',
            foodItems: [_food(quantity: '2', carbs: 30)],
          ),
        ],
      );

      final scaled = TemplateScalingService.scalePlanWithTargets(
        plan: plan,
        targets: _targets(duringCarbs: 0),
      );

      expect(scaled.sections.first.foodItems.first.quantity, '2');
    });

    test('section id without known prefix passes through unchanged', () {
      // 'recovery1' doesn't start with 'before', 'during', or 'after'.
      final plan = _plan(
        sections: [
          _section(
            id: 'recovery1',
            foodItems: [_food(quantity: '2', carbs: 30)],
          ),
        ],
      );

      final scaled = TemplateScalingService.scalePlanWithTargets(
        plan: plan,
        targets: _targets(),
      );

      expect(scaled.sections.first.foodItems.first.quantity, '2');
    });

    // ----------------------------------------------------------
    // Quantity string parsing edge cases
    // ----------------------------------------------------------

    test('food with non-numeric quantity passes through unchanged', () {
      final food = const FoodItemData(
        id: 'f1',
        name: 'Drink',
        quantity: 'As needed',
        nutritionalInfo: NutritionalInfo(carbs: 30),
      );

      final plan = _plan(
        sections: [
          _section(id: 'during1', foodItems: [food]),
        ],
      );

      final scaled = TemplateScalingService.scalePlanWithTargets(
        plan: plan,
        targets: _targets(duringCarbs: 90),
      );

      // Can't parse quantity → food unchanged.
      expect(scaled.sections.first.foodItems.first.quantity, 'As needed');
    });

    test('scaleMultiplier is set on the returned food', () {
      // 2 gels × ratio 2.0 → 4 gels; scaleMultiplier should reflect actual ratio.
      final plan = _plan(
        sections: [
          _section(
            id: 'during1',
            foodItems: [_food(quantity: '2', carbs: 22, isIndivisible: true)],
          ),
        ],
      );

      final scaled = TemplateScalingService.scalePlanWithTargets(
        plan: plan,
        targets: _targets(duringCarbs: 88), // ratio 2.0
      );

      final food = scaled.sections.first.foodItems.first;
      expect(food.scaleMultiplier, isNotNull);
      expect(food.scaleMultiplier!, closeTo(2.0, 0.01));
    });

    // ----------------------------------------------------------
    // Multi-section plan
    // ----------------------------------------------------------

    test('each section is scaled independently', () {
      // NutritionalInfo.carbs is the total carbs for the food entry at its
      // listed quantity — NOT per-unit. The during food has carbs: 60 so
      // sectionCarbTotal = 60, matching the target → ratio 1.0 → qty unchanged.
      final plan = _plan(
        sections: [
          _section(
            id: 'before1',
            foodItems: [_food(id: 'b1', quantity: '1', carbs: 30)],
          ),
          _section(
            id: 'during1',
            foodItems: [_food(id: 'd1', quantity: '2', carbs: 60)],
          ),
          _section(
            id: 'after1',
            foodItems: [_food(id: 'a1', quantity: '1', carbs: 20)],
          ),
        ],
      );

      final scaled = TemplateScalingService.scalePlanWithTargets(
        plan: plan,
        targets: _targets(
          preCarbs: 60, // ratio 2.0 for before (60/30)
          duringCarbs: 60, // ratio 1.0 for during (60/60) → unchanged
          postCarbs: 20, // ratio 1.0 for after (20/20) → unchanged
        ),
      );

      expect(scaled.sections.length, 3);
      // before: 1 * 2.0 = 2.
      expect(scaled.sections[0].foodItems.first.quantity, '2');
      // during: 2 * (60/60) = 2 (unchanged).
      expect(scaled.sections[1].foodItems.first.quantity, '2');
      // after: 1 * (20/20) = 1 (unchanged).
      expect(scaled.sections[2].foodItems.first.quantity, '1');
    });
  });
}
