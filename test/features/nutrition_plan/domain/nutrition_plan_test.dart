import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import '../../../helpers/utils/console_logging.dart';

void main() {
  group('NutritionPlan Domain Model', () {
    test('should create a NutritionPlan instance', () {
      logTestHeading('Test: Create NutritionPlan Instance');

      // Arrange
      final now = DateTime.now();
      final plan = NutritionPlan(
        id: 'test-plan-123',
        name: 'Marathon Nutrition Plan',
        sections: [
          PlanSection(
            id: 'section-1',
            title: 'Before Run',
            subtitle: '30-60 min pre-run',
            foodItems: [
              FoodItemData(
                id: 'food-1',
                name: 'Oatmeal',
                amount: 1.0,
                unit: 'cup',
                calories: 150,
                carbs: 27.0,
                protein: 5.0,
                fat: 3.0,
                sodium: 150.0,
                fluid: 0.0,
                fiber: 4.0,
                sugar: 1.0,
              ),
            ],
            carbsTarget: 150.0,
            proteinTarget: 20.0,
            fatTarget: 10.0,
            sodiumTarget: 500.0,
            fluidsTarget: 500.0,
          ),
          PlanSection(
            id: 'section-2',
            title: 'During Run',
            subtitle: 'Every 30-45 minutes',
            foodItems: [
              FoodItemData(
                id: 'food-2',
                name: 'Energy Gel',
                amount: 1.0,
                unit: 'packet',
                calories: 100,
                carbs: 25.0,
                protein: 0.0,
                fat: 0.0,
                sodium: 50.0,
                fluid: 0.0,
                fiber: 0.0,
                sugar: 10.0,
              ),
            ],
            carbsTarget: 60.0,
            proteinTarget: 0.0,
            fatTarget: 0.0,
            sodiumTarget: 300.0,
            fluidsTarget: 750.0,
          ),
        ],
        macroTargets: MacroTargets(
          calories: 2500,
          carbs: 400.0,
          protein: 100.0,
          fat: 70.0,
          sodium: 2000.0,
          hydration: 3000.0,
          fiber: 25.0,
          sugar: 60.0,
        ),
        totalCalories: 2500,
        notes: 'Pre-marathon nutrition plan',
        runDateTime: now.add(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      );

      // Act & Assert
      expect(plan.id, equals('test-plan-123'));
      expect(plan.name, equals('Marathon Nutrition Plan'));
      expect(plan.sections.length, equals(2));
      expect(plan.sections.first.title, equals('Before Run'));
      expect(plan.sections.first.foodItems.length, equals(1));
      expect(plan.sections.first.foodItems.first.name, equals('Oatmeal'));
      expect(plan.macroTargets?.calories, equals(2500));
      expect(plan.totalCalories, equals(2500));
      expect(plan.notes, equals('Pre-marathon nutrition plan'));

      logTestResult('NutritionPlan Created', {
        'id': plan.id,
        'name': plan.name,
        'sections': plan.sections.length,
        'totalFoods': plan.sections.fold(0, (sum, section) => sum + section.foodItems.length),
        'totalCalories': plan.totalCalories,
      });
    });

    test('should copy NutritionPlan with updated fields', () {
      logTestHeading('Test: Copy NutritionPlan with Updates');

      // Arrange
      final original = NutritionPlan(
        id: 'plan-1',
        name: 'Original Plan',
        sections: [],
      );

      // Act
      final updated = original.copyWith(
        name: 'Updated Plan',
        totalCalories: 3000,
        notes: 'Modified plan',
      );

      // Assert
      expect(updated.id, equals('plan-1')); // ID should remain the same
      expect(updated.name, equals('Updated Plan'));
      expect(updated.totalCalories, equals(3000));
      expect(updated.notes, equals('Modified plan'));
      expect(original.name, equals('Original Plan')); // Original unchanged

      logTestResult('Plan Copied', {
        'originalName': original.name,
        'updatedName': updated.name,
        'updatedCalories': updated.totalCalories,
      });
    });

    test('should convert NutritionPlan to JSON', () {
      logTestHeading('Test: Convert NutritionPlan to JSON');

      // Arrange
      final plan = NutritionPlan(
        id: 'json-test',
        name: 'JSON Test Plan',
        sections: [
          PlanSection(
            id: 'section-1',
            title: 'Before Run',
            foodItems: [],
          ),
        ],
      );

      // Act
      final json = plan.toJson();

      // Assert
      expect(json['id'], equals('json-test'));
      expect(json['name'], equals('JSON Test Plan'));
      expect(json['sections'], isA<List>());
      expect((json['sections'] as List).length, equals(1));

      logTestResult('JSON Conversion', {
        'id': json['id'],
        'name': json['name'],
        'hasSection': json['sections'] != null,
      });
    });

    test('should create NutritionPlan from JSON', () {
      logTestHeading('Test: Create NutritionPlan from JSON');

      // Arrange
      final json = {
        'id': 'from-json',
        'name': 'From JSON Plan',
        'sections': [
          {
            'id': 'section-1',
            'title': 'Before Run',
            'foodItems': [],
          },
        ],
      };

      // Act
      final plan = NutritionPlan.fromJson(json);

      // Assert
      expect(plan.id, equals('from-json'));
      expect(plan.name, equals('From JSON Plan'));
      expect(plan.sections.length, equals(1));
      expect(plan.sections.first.title, equals('Before Run'));

      logTestResult('From JSON', {
        'id': plan.id,
        'name': plan.name,
        'sections': plan.sections.length,
      });
    });
  });

  group('PlanSection Domain Model', () {
    test('should create a PlanSection with food items', () {
      logTestHeading('Test: Create PlanSection');

      // Arrange & Act
      final section = PlanSection(
        id: 'section-test',
        title: 'During Run',
        subtitle: 'Every 45 minutes',
        timing: '45min',
        foodItems: [
          FoodItemData(
            id: 'gel-1',
            name: 'Energy Gel',
            amount: 1.0,
            unit: 'packet',
            calories: 100,
            carbs: 25.0,
            protein: 0.0,
            fat: 0.0,
            sodium: 50.0,
            fluid: 0.0,
            fiber: 0.0,
            sugar: 10.0,
          ),
        ],
        carbsTarget: 60.0,
        proteinTarget: 0.0,
        fatTarget: 0.0,
        sodiumTarget: 300.0,
        fluidsTarget: 750.0,
      );

      // Assert
      expect(section.id, equals('section-test'));
      expect(section.title, equals('During Run'));
      expect(section.subtitle, equals('Every 45 minutes'));
      expect(section.timing, equals('45min'));
      expect(section.foodItems.length, equals(1));
      expect(section.carbsTarget, equals(60.0));
      expect(section.sodiumTarget, equals(300.0));
      expect(section.fluidsTarget, equals(750.0));

      logTestResult('PlanSection Created', {
        'id': section.id,
        'title': section.title,
        'foodItems': section.foodItems.length,
        'carbsTarget': section.carbsTarget,
      });
    });

    test('should calculate section totals', () {
      logTestHeading('Test: Calculate Section Totals');

      // Arrange
      final section = PlanSection(
        id: 'calc-test',
        title: 'Before Run',
        foodItems: [
          FoodItemData(
            id: 'food-1',
            name: 'Banana',
            amount: 1.0,
            unit: 'medium',
            calories: 105,
            carbs: 27.0,
            protein: 1.3,
            fat: 0.4,
            sodium: 1.0,
            fluid: 75.0,
            fiber: 3.1,
            sugar: 14.0,
          ),
          FoodItemData(
            id: 'food-2',
            name: 'Toast',
            amount: 2.0,
            unit: 'slices',
            calories: 140,
            carbs: 26.0,
            protein: 5.0,
            fat: 2.0,
            sodium: 150.0,
            fluid: 0.0,
            fiber: 2.0,
            sugar: 2.0,
          ),
        ],
      );

      // Act
      final totals = section.calculateTotals();

      // Assert
      expect(totals.calories, equals(245));
      expect(totals.carbs, equals(53.0));
      expect(totals.protein, equals(6.3));
      expect(totals.fat, equals(2.4));
      expect(totals.sodium, equals(151.0));
      expect(totals.fluid, equals(75.0));

      logTestResult('Section Totals', {
        'calories': totals.calories,
        'carbs': totals.carbs,
        'protein': totals.protein,
        'sodium': totals.sodium,
      });
    });
  });

  group('MacroTargets Domain Model', () {
    test('should create MacroTargets instance', () {
      logTestHeading('Test: Create MacroTargets');

      // Arrange & Act
      final macros = MacroTargets(
        calories: 2500,
        carbs: 400.0,
        protein: 100.0,
        fat: 70.0,
        sodium: 2000.0,
        hydration: 3000.0,
        fiber: 25.0,
        sugar: 60.0,
      );

      // Assert
      expect(macros.calories, equals(2500));
      expect(macros.carbs, equals(400.0));
      expect(macros.protein, equals(100.0));
      expect(macros.fat, equals(70.0));
      expect(macros.sodium, equals(2000.0));
      expect(macros.hydration, equals(3000.0));
      expect(macros.fiber, equals(25.0));
      expect(macros.sugar, equals(60.0));

      logTestResult('MacroTargets Created', {
        'calories': macros.calories,
        'carbs': macros.carbs,
        'protein': macros.protein,
        'fat': macros.fat,
      });
    });
  });
}