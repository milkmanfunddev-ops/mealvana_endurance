import '../../meal_logging/domain/saved_meal.dart';
import '../domain/meal_icon_classifier.dart';
import '../domain/meal_ref.dart';
import '../domain/meal_source.dart';
import '../domain/meal_type.dart';
import '../domain/plan_meal.dart';

/// Local-row → [MealRef] projections for the catalog rails when the server
/// is not reachable. The `why` / `attribution` strings mirror what the
/// server's `recentMeals` emits for saved meals so the two paths render the
/// same card.
class MealRefMapping {
  const MealRefMapping._();

  /// A `saved_meals` row as the picker/catalog sees it.
  static MealRef fromSavedMeal(SavedMeal meal) {
    final ingredients = meal.components
        .map((c) => c.name)
        .where((n) => n.isNotEmpty)
        .join(', ');
    return MealRef(
      source: MealSource.saved,
      id: meal.id,
      name: meal.name,
      mealType:
          MealType.fromWire(meal.mealTypes.firstOrNull) ?? MealType.dinner,
      batch: meal.batch ?? false,
      kcal: meal.calories,
      carbsG: meal.carbsG,
      proteinG: meal.proteinG,
      fatG: meal.fatG,
      ingredients: ingredients,
      why: 'one of your meals',
      attribution: 'your saved meal',
      attributionShort: 'your saved meal',
      libraryMealId: meal.libraryMealId,
      score: 1,
      kind: MealKind.assembly,
      frequency: 'staple',
      icon: MealIconClassifier.resolve(
        meal.icon,
        name: meal.name,
        ingredients: ingredients,
      ),
      myVote: 0,
    );
  }

  /// A plan meal as a catalog reference (source id resolved from the row's
  /// `saved_meal_id` / `library_meal_id`). Null when the row has no source
  /// id to point at.
  static MealRef? fromPlanMeal(PlanMeal meal) {
    final id = switch (meal.source) {
      MealSource.saved => meal.savedMealId,
      MealSource.library => meal.libraryMealId,
    };
    if (id == null) return null;
    return MealRef(
      source: meal.source,
      id: id,
      name: meal.name,
      mealType: meal.mealType,
      batch: meal.session != null,
      kcal: meal.kcal,
      carbsG: meal.carbsG,
      proteinG: meal.proteinG,
      fatG: meal.fatG,
      why: meal.source == MealSource.saved ? 'one of your meals' : '',
      attribution: meal.source == MealSource.saved ? 'your saved meal' : '',
      attributionShort: meal.source == MealSource.saved
          ? 'your saved meal'
          : '',
      libraryMealId: meal.libraryMealId,
      score: 1,
      icon: meal.icon ?? MealIconClassifier.classify(name: meal.name),
      myVote: 0,
    );
  }

  /// Stable dedupe key for Recents (`saved:<uuid>` / `library:<id>`).
  static String key(MealRef ref) => '${ref.source.wire}:${ref.id}';
}
