// Unit tests for explodeRecipeComponents — BuildMealScreen's "+ Add food"
// flow splits a recipe into one editable MealComponent per ingredient line
// (rather than nesting it as one opaque line), since recipes only carry
// aggregate (whole-recipe) macros.

import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/meal_logging/domain/recipe_ingredient_split.dart';
import 'package:mealvana_endurance/features/recipes/domain/recipe.dart';

Recipe _recipe({
  List<String> ingredients = const ['Rolled oats', 'Milk', 'Chia seeds'],
  double calories = 300,
  double carbs = 40,
  double protein = 15,
  double fat = 10,
  double sodium = 120,
}) {
  return Recipe(
    id: 'recipe-1',
    name: 'Overnight Oats',
    description: 'desc',
    ingredients: ingredients,
    instructions: const ['Mix.', 'Chill.'],
    prepTimeMinutes: 5,
    servings: 1,
    type: RecipeType.breakfast,
    nutrition: RecipeNutrition(
      calories: calories,
      carbohydratesGrams: carbs,
      proteinGrams: protein,
      fatGrams: fat,
      fiberGrams: 4,
      sugarGrams: 8,
      sodiumMilligrams: sodium,
    ),
  );
}

void main() {
  group('explodeRecipeComponents', () {
    test('produces one component per ingredient', () {
      final recipe = _recipe();
      final components = explodeRecipeComponents(recipe, 1.0);
      expect(components.length, 3);
      expect(components.map((c) => c.name), [
        'Rolled oats',
        'Milk',
        'Chia seeds',
      ]);
    });

    test('sum of exploded macros matches the recipe total at 1 serving', () {
      final recipe = _recipe();
      final components = explodeRecipeComponents(recipe, 1.0);

      final totalCal = components.fold<int>(0, (a, c) => a + (c.calories ?? 0));
      final totalCarb = components.fold<double>(
        0,
        (a, c) => a + (c.carbG ?? 0),
      );
      final totalProt = components.fold<double>(
        0,
        (a, c) => a + (c.proteinG ?? 0),
      );
      final totalFat = components.fold<double>(0, (a, c) => a + (c.fatG ?? 0));
      final totalSodium = components.fold<double>(
        0,
        (a, c) => a + (c.sodiumMg ?? 0),
      );

      expect(totalCal, 300);
      expect(totalCarb, closeTo(40, 0.001));
      expect(totalProt, closeTo(15, 0.001));
      expect(totalFat, closeTo(10, 0.001));
      expect(totalSodium, closeTo(120, 0.001));
    });

    test('scales by servings before splitting', () {
      final recipe = _recipe();
      final components = explodeRecipeComponents(recipe, 2.0);
      final totalCal = components.fold<int>(0, (a, c) => a + (c.calories ?? 0));
      expect(totalCal, 600);
    });

    test('falls back to a single component when there are no ingredients', () {
      final recipe = _recipe(ingredients: const []);
      final components = explodeRecipeComponents(recipe, 1.0);
      expect(components.length, 1);
      expect(components.first.name, 'Overnight Oats');
    });
  });
}
