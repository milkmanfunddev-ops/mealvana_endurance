import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';

void main() {
  group('NutritionPlan - Simple Tests', () {
    test('should create a basic NutritionPlan instance', () {
      // Arrange & Act
      final plan = NutritionPlan(
        id: 'test-123',
        name: 'Test Plan',
        sections: [],
      );

      // Assert
      expect(plan.id, equals('test-123'));
      expect(plan.name, equals('Test Plan'));
      expect(plan.sections, isEmpty);
      expect(plan.macroTargets, isNull);
      expect(plan.totalCalories, isNull);
    });

    test('should create NutritionPlan with sections', () {
      // Arrange & Act
      final plan = NutritionPlan(
        id: 'test-456',
        name: 'Run Plan',
        sections: [
          PlanSection(
            id: 'section-1',
            title: 'Before Run',
            foodItems: [],
          ),
          PlanSection(
            id: 'section-2',
            title: 'During Run',
            foodItems: [],
          ),
        ],
      );

      // Assert
      expect(plan.sections.length, equals(2));
      expect(plan.sections[0].title, equals('Before Run'));
      expect(plan.sections[1].title, equals('During Run'));
    });

    test('should create PlanSection with FoodItemData', () {
      // Arrange & Act
      final section = PlanSection(
        id: 'test-section',
        title: 'Pre-Run',
        foodItems: [
          FoodItemData(
            id: 'food-1',
            name: 'Banana',
            quantity: '1 medium',
            nutritionalInfo: NutritionalInfo(
              calories: 105,
              carbs: 27,
              protein: 1,
              fat: 0,
              sodium: 1,
              fluids: 75.0,
            ),
          ),
        ],
      );

      // Assert
      expect(section.id, equals('test-section'));
      expect(section.title, equals('Pre-Run'));
      expect(section.foodItems.length, equals(1));
      expect(section.foodItems.first.name, equals('Banana'));
      expect(section.foodItems.first.quantity, equals('1 medium'));
      expect(section.foodItems.first.nutritionalInfo?.calories, equals(105));
      expect(section.foodItems.first.nutritionalInfo?.carbs, equals(27));
    });

    test('should create MacroTargets', () {
      // Arrange & Act
      final macros = MacroTargets(
        calories: 2500,
        carbs: 400,
        protein: 100,
        fat: 70,
        sodium: 2000,
        fluids: 100,
      );

      // Assert
      expect(macros.calories, equals(2500));
      expect(macros.carbs, equals(400));
      expect(macros.protein, equals(100));
      expect(macros.fat, equals(70));
      expect(macros.sodium, equals(2000));
      expect(macros.fluids, equals(100));
    });

    test('should convert NutritionPlan to and from JSON', () {
      // Arrange
      final original = NutritionPlan(
        id: 'json-test',
        name: 'JSON Plan',
        sections: [
          PlanSection(
            id: 's1',
            title: 'Section 1',
            foodItems: [],
          ),
        ],
        macroTargets: MacroTargets(
          calories: 2000,
          carbs: 300,
          protein: 80,
          fat: 60,
        ),
      );

      // Act
      final json = original.toJson();
      final restored = NutritionPlan.fromJson(json);

      // Assert
      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.sections.length, equals(1));
      expect(restored.sections.first.title, equals('Section 1'));
      expect(restored.macroTargets?.calories, equals(2000));
      expect(restored.macroTargets?.carbs, equals(300));
    });

    test('should copy NutritionPlan with updates', () {
      // Arrange
      final original = NutritionPlan(
        id: 'copy-test',
        name: 'Original',
        sections: [],
        totalCalories: 2000,
      );

      // Act
      final updated = original.copyWith(
        name: 'Updated',
        totalCalories: 2500,
        notes: 'Test notes',
      );

      // Assert
      expect(updated.id, equals('copy-test')); // ID unchanged
      expect(updated.name, equals('Updated'));
      expect(updated.totalCalories, equals(2500));
      expect(updated.notes, equals('Test notes'));

      // Original unchanged
      expect(original.name, equals('Original'));
      expect(original.totalCalories, equals(2000));
      expect(original.notes, isNull);
    });

    test('should handle nutritional info in FoodItemData', () {
      // Arrange & Act
      final food = FoodItemData(
        id: 'test-food',
        name: 'Energy Gel',
        quantity: '1 packet',
        description: 'Quick energy boost',
        timing: 'Every 45 minutes',
        nutritionalInfo: NutritionalInfo(
          calories: 100,
          carbs: 25,
          protein: 0,
          fat: 0,
          sodium: 50,
          sugar: 10,
          fluids: 0.0,
        ),
      );

      // Assert
      expect(food.id, equals('test-food'));
      expect(food.name, equals('Energy Gel'));
      expect(food.quantity, equals('1 packet'));
      expect(food.description, equals('Quick energy boost'));
      expect(food.timing, equals('Every 45 minutes'));

      final nutrition = food.nutritionalInfo!;
      expect(nutrition.calories, equals(100));
      expect(nutrition.carbs, equals(25));
      expect(nutrition.sodium, equals(50));
      expect(nutrition.sugar, equals(10));
    });

    test('should handle plan sections with macro targets', () {
      // Arrange & Act
      final section = PlanSection(
        id: 'macro-section',
        title: 'Before Run',
        subtitle: '30-60 minutes before',
        foodItems: [],
        carbsTarget: 150.0,
        proteinTarget: 20.0,
        fatTarget: 10.0,
        sodiumTarget: 500.0,
        fluidsTarget: 500.0,
      );

      // Assert
      expect(section.carbsTarget, equals(150.0));
      expect(section.proteinTarget, equals(20.0));
      expect(section.fatTarget, equals(10.0));
      expect(section.sodiumTarget, equals(500.0));
      expect(section.fluidsTarget, equals(500.0));
    });
  });
}