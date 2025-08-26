import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/recipe.dart';

part 'recipe_repository.g.dart';

@riverpod
RecipeRepository recipeRepository(RecipeRepositoryRef ref) {
  return RecipeRepository();
}

class RecipeRepository {
  // Mock data for initial implementation
  final List<Recipe> _mockRecipes = [
    Recipe(
      id: '1',
      name: 'Pre-Run Energy Smoothie',
      description: 'High-carb smoothie perfect for pre-run fueling',
      ingredients: [
        '1 banana',
        '1 cup oat milk',
        '2 tbsp maple syrup',
        '1/2 cup oats',
        'Pinch of salt',
      ],
      instructions: [
        'Add all ingredients to blender',
        'Blend until smooth',
        'Serve immediately',
      ],
      prepTimeMinutes: 5,
      servings: 1,
      type: RecipeType.preRun,
      nutrition: const RecipeNutrition(
        calories: 320,
        carbohydratesGrams: 68,
        proteinGrams: 8,
        fatGrams: 4,
        fiberGrams: 6,
        sugarGrams: 28,
        sodiumMilligrams: 150,
      ),
      tags: ['smoothie', 'quick', 'high-carb'],
      createdAt: DateTime.now(),
    ),
    Recipe(
      id: '2',
      name: 'Post-Run Recovery Bowl',
      description: 'Protein-rich bowl for optimal post-run recovery',
      ingredients: [
        '1 cup Greek yogurt',
        '1/2 cup berries',
        '1 tbsp honey',
        '1/4 cup granola',
        '1 tbsp almond butter',
      ],
      instructions: [
        'Place yogurt in bowl',
        'Top with berries and granola',
        'Drizzle with honey and almond butter',
        'Mix and enjoy',
      ],
      prepTimeMinutes: 3,
      servings: 1,
      type: RecipeType.postRun,
      nutrition: const RecipeNutrition(
        calories: 380,
        carbohydratesGrams: 45,
        proteinGrams: 22,
        fatGrams: 12,
        fiberGrams: 8,
        sugarGrams: 35,
        sodiumMilligrams: 80,
      ),
      tags: ['recovery', 'protein', 'quick'],
      createdAt: DateTime.now(),
    ),
  ];

  Future<List<Recipe>> getAllRecipes() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    return List.from(_mockRecipes);
  }

  Future<List<Recipe>> getRecipesByType(RecipeType type) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockRecipes.where((recipe) => recipe.type == type).toList();
  }

  Future<Recipe?> getRecipeById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return _mockRecipes.firstWhere((recipe) => recipe.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<List<Recipe>> getFavoriteRecipes() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockRecipes.where((recipe) => recipe.isFavorite).toList();
  }

  Future<void> toggleFavorite(String recipeId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _mockRecipes.indexWhere((recipe) => recipe.id == recipeId);
    if (index != -1) {
      _mockRecipes[index] = _mockRecipes[index].copyWith(
        isFavorite: !_mockRecipes[index].isFavorite,
      );
    }
  }

  Future<List<Recipe>> searchRecipes(String query) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final lowerQuery = query.toLowerCase();
    return _mockRecipes.where((recipe) {
      return recipe.name.toLowerCase().contains(lowerQuery) ||
          recipe.description.toLowerCase().contains(lowerQuery) ||
          recipe.ingredients.any((ingredient) => 
              ingredient.toLowerCase().contains(lowerQuery)) ||
          (recipe.tags?.any((tag) => 
              tag.toLowerCase().contains(lowerQuery)) ?? false);
    }).toList();
  }
}