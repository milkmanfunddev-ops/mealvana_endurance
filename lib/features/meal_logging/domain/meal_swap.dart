import '../../nutrition_plan/domain/food.dart';
import 'meal_component.dart';

/// Maps a food picked in the swap sheet, eaten [qty] times, to the
/// [MealComponent] that replaces the swiped item (Review & Log and Edit Meal
/// both call this; testing-wave develop-2026-10 ticket 38).
///
/// The portion is one serving of the food ("1 cup", "1 serving"), the way the
/// AI writes a portion, and [qty] is kept beside it in `quantity`, so the row
/// reads "2 × 1 cup" through [MealComponent.portionLabel] and reopening the
/// item shows Quantity 2 over the base. The macros hold what was eaten
/// (per-serving value × [qty]), as every [MealComponent] does (02-005).
/// Unknown values stay unknown.
MealComponent swappedComponent(Food food, double qty) {
  // The eaten arithmetic for every number lives here, in one place.
  double? eaten(num? perServing) =>
      perServing == null ? null : perServing.toDouble() * qty;
  final calories = eaten(food.caloriesPerServing);

  return MealComponent(
    name: food.displayName ?? food.name,
    portion: '1 ${food.servingUnit ?? 'serving'}',
    calories: calories?.round(),
    carbG: eaten(food.carbsPerServing),
    proteinG: eaten(food.proteinPerServing),
    fatG: eaten(food.fatPerServing),
    sodiumMg: eaten(food.sodiumMg),
    quantity: qty,
  );
}
