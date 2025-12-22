import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'food_selections_cache_provider.g.dart';

/// Cache for food selections during onboarding
///
/// This provider maintains the state of food selections while the user
/// navigates back and forth through the onboarding flow. The cache is
/// cleared when onboarding is completed or reset.
@riverpod
class FoodSelectionsCache extends _$FoodSelectionsCache {
  @override
  Set<String> build() {
    // Prevent auto-dispose during onboarding navigation
    ref.keepAlive();

    // Initialize with empty set
    return {};
  }

  /// Update the cached food selections
  void updateSelections(Set<String> selections) {
    state = Set.from(selections);
  }

  /// Add a food to the cache
  void addFood(String foodId) {
    state = {...state, foodId};
  }

  /// Remove a food from the cache
  void removeFood(String foodId) {
    state = state.where((id) => id != foodId).toSet();
  }

  /// Toggle a food in the cache
  void toggleFood(String foodId) {
    if (state.contains(foodId)) {
      removeFood(foodId);
    } else {
      addFood(foodId);
    }
  }

  /// Clear the cache (call when onboarding is completed)
  void clear() {
    state = {};
  }

  /// Check if a food is selected
  bool isSelected(String foodId) {
    return state.contains(foodId);
  }
}
