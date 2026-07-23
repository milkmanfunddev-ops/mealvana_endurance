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
String mealFavoriteMatchKey(String name, List<MealComponent> components) {
  final normalizedName = name.trim().toLowerCase();
  final parts = components
      .map(
        (c) =>
            '${c.name.trim().toLowerCase()}|${c.portion.trim().toLowerCase()}',
      )
      .toList();
  return '$normalizedName::${parts.join(',')}';
}

/// Returns the [SavedMeal] in [favorites] that matches [log], if any.
SavedMeal? findFavoriteMatch(MealLog log, List<SavedMeal> favorites) {
  final key = mealFavoriteMatchKey(log.name, log.components);
  for (final meal in favorites) {
    if (mealFavoriteMatchKey(meal.name, meal.components) == key) return meal;
  }
  return null;
}
