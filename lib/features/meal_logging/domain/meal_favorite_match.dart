import 'dart:convert';

import 'meal_component.dart';
import 'meal_log.dart';
import 'saved_meal.dart';

/// Builds a stable identity key from a meal's name + component list so a
/// [MealLog] can be matched against the user's [SavedMeal] favorites without
/// a dedicated back-link column.
///
/// `saved_meals` intentionally has no `source_log_id` column (out of scope
/// for the build-a-meal redesign — see item 23 in the task notes), so this
/// name + component signature match is the mechanism for the favorite star
/// toggle to know whether a given [MealLog] is already favorited, and for
/// un-favoriting to find the matching [SavedMeal] row to delete.
///
/// Two meals are considered "the same favorite" when their name and the
/// (name, portion) signature of every component match exactly, in order.
/// This is intentionally strict — a bare substring/fuzzy match would risk
/// false-positive un-favorites.
/// The key is JSON-encoded rather than joined with `|` and `,` separators.
/// Concatenating raw fields let a value that itself contained a separator forge
/// a boundary: a single component named "Oats" with the portion
/// "1 cup,Honey|1 tsp" produced exactly the same key as the two components
/// ("Oats", "1 cup") and ("Honey", "1 tsp"). Since [findFavoriteMatch] is what
/// un-favoriting uses to choose a row to *delete*, a collision there removes
/// the wrong SavedMeal. JSON escapes the delimiters, so the encoding is
/// unambiguous for any input.
///
/// This key is computed on both sides at comparison time and never persisted,
/// so its format is free to change.
String mealFavoriteMatchKey(String name, List<MealComponent> components) {
  return jsonEncode([
    name.trim().toLowerCase(),
    for (final c in components)
      [c.name.trim().toLowerCase(), c.portion.trim().toLowerCase()],
  ]);
}

/// Returns the [SavedMeal] in [favorites] that matches [log], if any.
SavedMeal? findFavoriteMatch(MealLog log, List<SavedMeal> favorites) {
  final key = mealFavoriteMatchKey(log.name, log.components);
  for (final meal in favorites) {
    if (mealFavoriteMatchKey(meal.name, meal.components) == key) return meal;
  }
  return null;
}
