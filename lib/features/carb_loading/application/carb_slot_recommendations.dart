import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/carb_loading_food_repository.dart';
import '../domain/carb_loading_food.dart';
import '../domain/meal_type.dart';

part 'carb_slot_recommendations.g.dart';

/// One row of the slot page's "Recommended for {slot}" section (G21-B,
/// Xuan 2026-09-25): release-1 reads the EXISTING `carb_loading_foods`
/// store — its `meal_types` are the per-slot suitability — via the shipping
/// sync path. The S9 one-store unification is D-022, deliberately deferred.
class CarbSlotRecommendation {
  const CarbSlotRecommendation({
    required this.id,
    required this.name,
    required this.subStr,
    required this.query,
  });

  /// Store row id — the row key.
  final String id;

  /// Display line, serving included: 'Cereal (1/2 cup dry)'.
  final String name;

  /// 'N g carbs per serving' — prototype-verbatim sub line.
  final String subStr;

  /// What the shipping Log-a-Meal search gets seeded with on tap: the
  /// display name without its serving parenthetical ('Cereal').
  final String query;
}

/// Curation-order + copy assembly, pure. The store has no order column, so
/// the FIXED order (ruled: deterministic, never DB-arbitrary) is the store's
/// internal curation key `name` ascending, id as the total-order tiebreak —
/// identical on every device regardless of sync arrival order.
List<CarbSlotRecommendation> assembleSlotRecommendations(
  List<CarbLoadingFood> foods,
) {
  final sorted = List<CarbLoadingFood>.of(foods)
    ..sort((a, b) {
      final byName = a.name.compareTo(b.name);
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });
  return [
    for (final f in sorted)
      CarbSlotRecommendation(
        id: f.id,
        name: f.displayName,
        subStr: '${f.carbsPerServing.round()} g carbs per serving',
        query: _stripServing(f.displayName),
      ),
  ];
}

String _stripServing(String displayName) {
  final cut = displayName.indexOf('(');
  return (cut > 0 ? displayName.substring(0, cut) : displayName).trim();
}

/// The slot page's recommendation rows for one slot: the old store filtered
/// by `meal_types` suitability (getFoodsByMealType), fixed curation order.
/// Empty store or no suitable rows → empty list; the section renders its
/// empty state, never crashes (the G21-B empty-state red).
@riverpod
Future<List<CarbSlotRecommendation>> carbSlotRecommendations(
  Ref ref,
  MealType slot,
) async {
  final repository = ref.watch(carbLoadingFoodRepositoryProvider);
  final foods = await repository.getFoodsByMealType(slot.id);
  return assembleSlotRecommendations(foods);
}
