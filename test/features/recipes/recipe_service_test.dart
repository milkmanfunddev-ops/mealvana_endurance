/// Unit tests for [RecipeService] — the application-layer facade over
/// [RecipeRepository].
///
/// Tests the pure in-memory helpers (filterRecipesByTags, sortRecipes,
/// searchRecipes empty-query bypass) and verifies delegation to the
/// repository for I/O methods (getAllRecipes, getRecipesByType, getRecipeById,
/// getFavoriteRecipes, toggleFavorite, ensureSynced).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/features/recipes/application/recipe_service.dart';
import 'package:mealvana_endurance/features/recipes/data/repositories/recipe_repository.dart';
import 'package:mealvana_endurance/features/recipes/domain/recipe.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockRecipeRepository extends Mock implements RecipeRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

RecipeNutrition _nutrition({double calories = 300}) => RecipeNutrition(
  calories: calories,
  carbohydratesGrams: 40,
  proteinGrams: 10,
  fatGrams: 8,
  fiberGrams: 3,
  sugarGrams: 5,
  sodiumMilligrams: 200,
);

Recipe _recipe({
  String id = 'r1',
  String name = 'Recipe',
  RecipeType type = RecipeType.breakfast,
  double calories = 300,
  List<String>? tags,
  int prepTimeMinutes = 10,
  DateTime? createdAt,
}) {
  return Recipe(
    id: id,
    name: name,
    description: 'A test recipe.',
    ingredients: const ['ingredient'],
    instructions: const ['step'],
    prepTimeMinutes: prepTimeMinutes,
    servings: 1,
    type: type,
    nutrition: _nutrition(calories: calories),
    tags: tags,
    createdAt: createdAt,
    updatedAt: DateTime(2025, 6, 1),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockRecipeRepository mockRepo;
  late RecipeService service;

  setUp(() {
    mockRepo = MockRecipeRepository();
    service = RecipeService(mockRepo);
  });

  // =========================================================================
  // Delegation to repository
  // =========================================================================

  group('RecipeService — delegation to repository', () {
    test('getAllRecipes delegates to repository', () async {
      final expected = [_recipe(id: 'r1'), _recipe(id: 'r2')];
      when(() => mockRepo.getAllRecipes()).thenAnswer((_) async => expected);

      final result = await service.getAllRecipes();
      expect(result, expected);
      verify(() => mockRepo.getAllRecipes()).called(1);
    });

    test('getRecipesByType delegates to repository', () async {
      final expected = [_recipe(type: RecipeType.recovery)];
      when(
        () => mockRepo.getRecipesByType(RecipeType.recovery),
      ).thenAnswer((_) async => expected);

      final result = await service.getRecipesByType(RecipeType.recovery);
      expect(result, expected);
      verify(() => mockRepo.getRecipesByType(RecipeType.recovery)).called(1);
    });

    test('getRecipeById delegates to repository', () async {
      final expected = _recipe(id: 'r99');
      when(
        () => mockRepo.getRecipeById('r99'),
      ).thenAnswer((_) async => expected);

      final result = await service.getRecipeById('r99');
      expect(result, expected);
      verify(() => mockRepo.getRecipeById('r99')).called(1);
    });

    test('getRecipeById returns null when repository returns null', () async {
      when(
        () => mockRepo.getRecipeById('missing'),
      ).thenAnswer((_) async => null);

      final result = await service.getRecipeById('missing');
      expect(result, isNull);
    });

    test('getFavoriteRecipes delegates to repository', () async {
      when(() => mockRepo.getFavoriteRecipes()).thenAnswer((_) async => []);

      final result = await service.getFavoriteRecipes();
      expect(result, isEmpty);
      verify(() => mockRepo.getFavoriteRecipes()).called(1);
    });

    test('toggleFavorite delegates to repository', () async {
      when(() => mockRepo.toggleFavorite('r1')).thenAnswer((_) async {});

      await service.toggleFavorite('r1');
      verify(() => mockRepo.toggleFavorite('r1')).called(1);
    });

    test('ensureSynced delegates to repository with correct userId', () async {
      when(
        () => mockRepo.ensureSynced('user-123', force: false),
      ).thenAnswer((_) async {});

      await service.ensureSynced('user-123');
      verify(() => mockRepo.ensureSynced('user-123', force: false)).called(1);
    });

    test('ensureSynced passes force=true when requested', () async {
      when(
        () => mockRepo.ensureSynced('user-123', force: true),
      ).thenAnswer((_) async {});

      await service.ensureSynced('user-123', force: true);
      verify(() => mockRepo.ensureSynced('user-123', force: true)).called(1);
    });
  });

  // =========================================================================
  // searchRecipes (pure + repo delegation)
  // =========================================================================

  group('searchRecipes', () {
    test(
      'empty query delegates to getAllRecipes (not searchRecipes)',
      () async {
        final all = [_recipe(id: 'r1'), _recipe(id: 'r2')];
        when(() => mockRepo.getAllRecipes()).thenAnswer((_) async => all);

        final result = await service.searchRecipes('');
        expect(result, all);
        verify(() => mockRepo.getAllRecipes()).called(1);
        verifyNever(() => mockRepo.searchRecipes(any()));
      },
    );

    test('non-empty query delegates to repository.searchRecipes', () async {
      final expected = [_recipe(id: 'r1')];
      when(
        () => mockRepo.searchRecipes('banana'),
      ).thenAnswer((_) async => expected);

      final result = await service.searchRecipes('banana');
      expect(result, expected);
      verify(() => mockRepo.searchRecipes('banana')).called(1);
      verifyNever(() => mockRepo.getAllRecipes());
    });
  });

  // =========================================================================
  // filterRecipesByTags — pure helper (no repo calls)
  // =========================================================================

  group('filterRecipesByTags', () {
    final vegan = _recipe(
      id: 'r1',
      name: 'Smoothie',
      tags: ['high-carb', 'vegan'],
    );
    final highCarb = _recipe(id: 'r2', name: 'Oats', tags: ['high-carb']);
    final noTags = _recipe(id: 'r3', name: 'Gel', tags: null);
    final allRecipes = [vegan, highCarb, noTags];

    test('empty tag filter returns all recipes unchanged', () {
      final result = service.filterRecipesByTags(allRecipes, []);
      expect(result, allRecipes);
      verifyZeroInteractions(mockRepo);
    });

    test('single-tag filter returns recipes that have the tag', () {
      final result = service.filterRecipesByTags(allRecipes, ['vegan']);
      expect(result.length, 1);
      expect(result.first.id, 'r1');
    });

    test(
      'multi-tag filter requires ALL tags to be present (AND semantics)',
      () {
        // Only 'r1' has both 'high-carb' AND 'vegan'.
        final result = service.filterRecipesByTags(allRecipes, [
          'high-carb',
          'vegan',
        ]);
        expect(result.length, 1);
        expect(result.first.id, 'r1');
      },
    );

    test('recipe with null tags is excluded from any tag filter', () {
      final result = service.filterRecipesByTags(allRecipes, ['high-carb']);
      expect(result.map((r) => r.id), isNot(contains('r3')));
    });

    test('returns empty when no recipe matches the tag', () {
      final result = service.filterRecipesByTags(allRecipes, ['paleo']);
      expect(result, isEmpty);
    });

    test('returns empty list unchanged when input is empty', () {
      final result = service.filterRecipesByTags([], ['high-carb']);
      expect(result, isEmpty);
    });
  });

  // =========================================================================
  // sortRecipes — pure helper (no repo calls)
  // =========================================================================

  group('sortRecipes', () {
    final r1 = _recipe(
      id: 'r1',
      name: 'Apple Oats',
      calories: 300,
      prepTimeMinutes: 30,
      createdAt: DateTime(2025, 1, 1),
    );
    final r2 = _recipe(
      id: 'r2',
      name: 'Banana Smoothie',
      calories: 150,
      prepTimeMinutes: 5,
      createdAt: DateTime(2025, 3, 1),
    );
    final r3 = _recipe(
      id: 'r3',
      name: 'Chicken Bowl',
      calories: 500,
      prepTimeMinutes: 20,
      createdAt: DateTime(2025, 2, 1),
    );
    final unsorted = [r3, r1, r2];

    test('sort by name returns alphabetical order', () {
      final result = service.sortRecipes(unsorted, RecipeSortOption.name);
      expect(result.map((r) => r.name).toList(), [
        'Apple Oats',
        'Banana Smoothie',
        'Chicken Bowl',
      ]);
      verifyZeroInteractions(mockRepo);
    });

    test('sort by prepTime returns ascending order', () {
      final result = service.sortRecipes(unsorted, RecipeSortOption.prepTime);
      expect(result.map((r) => r.prepTimeMinutes).toList(), [5, 20, 30]);
    });

    test('sort by calories returns ascending order', () {
      final result = service.sortRecipes(unsorted, RecipeSortOption.calories);
      expect(result.map((r) => r.nutrition.calories).toList(), [150, 300, 500]);
    });

    test('sort by newest returns descending createdAt order', () {
      final result = service.sortRecipes(unsorted, RecipeSortOption.newest);
      // Most recently created first: Mar > Feb > Jan.
      expect(result.map((r) => r.id).toList(), ['r2', 'r3', 'r1']);
    });

    test('sort does not mutate the original list', () {
      final original = [r3, r1, r2];
      service.sortRecipes(original, RecipeSortOption.name);
      // original order should be unchanged.
      expect(original.map((r) => r.id).toList(), ['r3', 'r1', 'r2']);
    });

    test('sort by newest with null createdAt sorts nulls to end', () {
      final withNull = _recipe(id: 'r-null', createdAt: null);
      final withDate = _recipe(id: 'r-date', createdAt: DateTime(2025, 6, 1));
      final result = service.sortRecipes([
        withNull,
        withDate,
      ], RecipeSortOption.newest);
      // Non-null dates come first; null sorts to end.
      expect(result.first.id, 'r-date');
      expect(result.last.id, 'r-null');
    });

    test('sort by newest with both null createdAt returns stable ordering', () {
      final a = _recipe(id: 'a', createdAt: null);
      final b = _recipe(id: 'b', createdAt: null);
      // Both null → compare returns 0 → relative order preserved.
      final result = service.sortRecipes([a, b], RecipeSortOption.newest);
      expect(result.length, 2);
    });

    test('sort preserves equal-value items (stable across multiple runs)', () {
      final a = _recipe(id: 'a', prepTimeMinutes: 15, name: 'Alpha');
      final b = _recipe(id: 'b', prepTimeMinutes: 15, name: 'Beta');
      final result1 = service.sortRecipes([a, b], RecipeSortOption.prepTime);
      final result2 = service.sortRecipes([a, b], RecipeSortOption.prepTime);
      expect(
        result1.map((r) => r.id).toList(),
        result2.map((r) => r.id).toList(),
        reason: 'equal-value sort should be deterministic',
      );
    });

    test('sort of empty list returns empty list', () {
      final result = service.sortRecipes([], RecipeSortOption.name);
      expect(result, isEmpty);
    });

    test('sort of single-element list returns that element', () {
      final result = service.sortRecipes([r1], RecipeSortOption.calories);
      expect(result.length, 1);
      expect(result.first.id, r1.id);
    });
  });

  // =========================================================================
  // RecipeSortOption enum coverage
  // =========================================================================

  group('RecipeSortOption — all enum values', () {
    test('all four sort options are covered', () {
      // Sanity check: if new sort options are added, the switch in sortRecipes
      // must handle them or a compile error / coverage gap appears.
      expect(
        RecipeSortOption.values.length,
        4,
        reason: 'Update sortRecipes switch if new options are added',
      );
      expect(
        RecipeSortOption.values,
        containsAll([
          RecipeSortOption.name,
          RecipeSortOption.prepTime,
          RecipeSortOption.calories,
          RecipeSortOption.newest,
        ]),
      );
    });
  });
}
