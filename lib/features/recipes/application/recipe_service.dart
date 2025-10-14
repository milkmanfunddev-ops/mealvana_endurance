import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/recipe.dart';
import '../data/repositories/recipe_repository.dart';

part 'recipe_service.g.dart';

@riverpod
RecipeService recipeService(Ref ref) {
  final repository = ref.read(recipeRepositoryProvider);
  return RecipeService(repository);
}

class RecipeService {
  const RecipeService(this._repository);

  final RecipeRepository _repository;

  Future<List<Recipe>> getAllRecipes() async {
    return await _repository.getAllRecipes();
  }

  Future<List<Recipe>> getRecipesByType(RecipeType type) async {
    return await _repository.getRecipesByType(type);
  }

  Future<Recipe?> getRecipeById(String id) async {
    return await _repository.getRecipeById(id);
  }

  Future<List<Recipe>> getFavoriteRecipes() async {
    return await _repository.getFavoriteRecipes();
  }

  Future<void> toggleFavorite(String recipeId) async {
    await _repository.toggleFavorite(recipeId);
  }

  Future<List<Recipe>> searchRecipes(String query) async {
    if (query.isEmpty) {
      return await getAllRecipes();
    }
    return await _repository.searchRecipes(query);
  }

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
        break;
      case RecipeSortOption.prepTime:
        sortedRecipes.sort((a, b) => a.prepTimeMinutes.compareTo(b.prepTimeMinutes));
        break;
      case RecipeSortOption.calories:
        sortedRecipes.sort((a, b) => a.nutrition.calories.compareTo(b.nutrition.calories));
        break;
      case RecipeSortOption.newest:
        sortedRecipes.sort((a, b) {
          if (a.createdAt == null && b.createdAt == null) return 0;
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
        });
        break;
    }
    
    return sortedRecipes;
  }
}

enum RecipeSortOption {
  name,
  prepTime,
  calories,
  newest,
}