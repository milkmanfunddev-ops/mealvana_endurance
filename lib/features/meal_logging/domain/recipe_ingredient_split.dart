import '../../recipes/domain/recipe.dart';
import 'meal_component.dart';

/// Splits a [Recipe] into one editable [MealComponent] per ingredient line,
/// instead of a single opaque "recipe" line (used by [BuildMealScreen]'s
/// "+ Add food" flow so recipe ingredients are individually adjustable —
/// no nesting a whole recipe as one component).
///
/// Recipes only store **aggregate** (whole-recipe) macros — there's no
/// per-ingredient nutrition breakdown — so this distributes calories/carbs/
/// protein/fat/sodium **evenly** across [Recipe.ingredients]. The sum across
/// the resulting components matches the recipe's total macros at [servings]
/// exactly (any calorie rounding remainder is folded into the first line);
/// per-line values are therefore an even-split approximation, not a precise
/// per-ingredient value. Users can still edit any line's quantity/macros
/// afterward via `MealComponentEditor`.
///
/// Falls back to a single component named after the recipe when it has no
/// ingredient list (defensive — shouldn't happen for a real catalog recipe).
List<MealComponent> explodeRecipeComponents(Recipe recipe, double servings) {
  final ingredients = recipe.ingredients.isEmpty
      ? [recipe.name]
      : recipe.ingredients;
  final n = ingredients.length;
  final nutrition = recipe.nutrition;

  final totalCalories = (nutrition.calories * servings).round();
  final totalCarb = nutrition.carbohydratesGrams * servings;
  final totalProtein = nutrition.proteinGrams * servings;
  final totalFat = nutrition.fatGrams * servings;
  final totalSodium = nutrition.sodiumMilligrams * servings;

  final calShare = totalCalories ~/ n;
  final calRemainder = totalCalories - (calShare * n);

  return List<MealComponent>.generate(n, (i) {
    return MealComponent(
      name: ingredients[i],
      portion: '1 serving (from "${recipe.name}")',
      calories: calShare + (i == 0 ? calRemainder : 0),
      carbG: totalCarb / n,
      proteinG: totalProtein / n,
      fatG: totalFat / n,
      sodiumMg: totalSodium / n,
    );
  });
}
