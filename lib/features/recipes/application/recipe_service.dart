import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/recipe_repository.dart';
import '../domain/recipe.dart';

/// Application-layer service for the recipe catalog.
///
/// Thin facade over [RecipeRepository] that adds sorting / filtering helpers
/// and drives on-demand cache hydration (ensureSynced) so the screen never
/// calls Supabase directly.
class RecipeService {
  const RecipeService(this._repository);

  final RecipeRepository _repository;

  // ========================================================================
  // Hydration
  // ========================================================================

  /// Ensure the local recipe cache is populated before first read.
  ///
  /// Call this once when the Recipes screen mounts. If the cache is fresh
  /// the call is a no-op; if stale (> 24 h or empty) it fetches from Supabase.
  /// Pass [force] (pull-to-refresh) to bypass the staleness window.
  Future<void> ensureSynced(String userId, {bool force = false}) async {
    await _repository.ensureSynced(userId, force: force);
  }

  // ========================================================================
  // Read Methods
  // ========================================================================

  Future<List<Recipe>> getAllRecipes() async {
    return _repository.getAllRecipes();
  }

  Future<List<Recipe>> getRecipesByType(RecipeType type) async {
    return _repository.getRecipesByType(type);
  }

  Future<Recipe?> getRecipeById(String id) async {
    return _repository.getRecipeById(id);
  }

  Future<List<Recipe>> getFavoriteRecipes() async {
    return _repository.getFavoriteRecipes();
  }

  Future<void> toggleFavorite(String recipeId) async {
    await _repository.toggleFavorite(recipeId);
  }

  Future<List<Recipe>> searchRecipes(String query) async {
    if (query.isEmpty) {
      return getAllRecipes();
    }
    return _repository.searchRecipes(query);
  }

  // ========================================================================
  // Pure helpers (no I/O)
  // ========================================================================

  List<Recipe> filterRecipesByTags(List<Recipe> recipes, List<String> tags) {
    if (tags.isEmpty) return recipes;
    return recipes.where((recipe) {
      if (recipe.tags == null) return false;
      return tags.every((tag) => recipe.tags!.contains(tag));
    }).toList();
  }

  List<Recipe> sortRecipes(List<Recipe> recipes, RecipeSortOption sortOption) {
    final sortedRecipes = List<Recipe>.from(recipes);
    switch (sortOption) {
      case RecipeSortOption.name:
        sortedRecipes.sort((a, b) => a.name.compareTo(b.name));
      case RecipeSortOption.prepTime:
        sortedRecipes.sort(
          (a, b) => a.prepTimeMinutes.compareTo(b.prepTimeMinutes),
        );
      case RecipeSortOption.calories:
        sortedRecipes.sort(
          (a, b) => a.nutrition.calories.compareTo(b.nutrition.calories),
        );
      case RecipeSortOption.newest:
        sortedRecipes.sort((a, b) {
          if (a.createdAt == null && b.createdAt == null) return 0;
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
        });
    }
    return sortedRecipes;
  }
}

enum RecipeSortOption { name, prepTime, calories, newest }

// ============================================================================
// Riverpod Provider
// ============================================================================

final recipeServiceProvider = Provider<RecipeService>((ref) {
  final repository = ref.watch(recipeRepositoryProvider);
  return RecipeService(repository);
});
